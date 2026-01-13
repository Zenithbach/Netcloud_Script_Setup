#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Cron Fix Module
# Diagnose and fix cron/background jobs issues
#==============================================================================

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Diagnostic Functions
#------------------------------------------------------------------------------

check_cron_status() {
    print_section "Cron Status Check"
    
    echo ""
    echo -e "${BOLD}1. Nextcloud Background Job Setting:${NC}"
    local bg_mode=$(occ config:system:get backgroundjobs_mode 2>/dev/null)
    if [ "$bg_mode" = "cron" ]; then
        print_success "Background jobs mode: cron"
    else
        print_warning "Background jobs mode: $bg_mode (should be 'cron')"
    fi
    
    echo ""
    echo -e "${BOLD}2. Last Cron Execution:${NC}"
    local last_cron=$(occ config:app:get core lastcron 2>/dev/null)
    if [ -n "$last_cron" ]; then
        local last_date=$(date -d "@$last_cron" 2>/dev/null || echo "Invalid timestamp")
        local now=$(date +%s)
        local diff=$((now - last_cron))
        local diff_mins=$((diff / 60))
        
        echo "  Last run: $last_date"
        echo "  Minutes ago: $diff_mins"
        
        if [ $diff_mins -lt 10 ]; then
            print_success "Cron ran within last 10 minutes"
        elif [ $diff_mins -lt 60 ]; then
            print_warning "Cron ran $diff_mins minutes ago (should be every 5 min)"
        else
            print_error "Cron hasn't run in over an hour!"
        fi
    else
        print_error "No cron execution recorded"
    fi
    
    echo ""
    echo -e "${BOLD}3. Systemd Timer Status:${NC}"
    if systemctl is-active --quiet nextcloud-cron.timer 2>/dev/null; then
        print_success "Timer is active"
        systemctl status nextcloud-cron.timer --no-pager 2>/dev/null | head -5
    else
        print_error "Timer is NOT active"
    fi
    
    echo ""
    echo -e "${BOLD}4. Timer Schedule:${NC}"
    systemctl list-timers nextcloud-cron.timer --no-pager 2>/dev/null || print_warning "Timer not found"
    
    echo ""
    echo -e "${BOLD}5. Last Service Run:${NC}"
    journalctl -u nextcloud-cron.service -n 5 --no-pager 2>/dev/null || print_warning "No journal entries"
    
    echo ""
    echo -e "${BOLD}6. Container Cron Test:${NC}"
    echo "  Testing if cron.php can execute..."
    if podman exec -u www-data "$NEXTCLOUD_CONTAINER" php -f /var/www/html/cron.php 2>&1; then
        print_success "cron.php executed successfully"
    else
        print_error "cron.php execution failed"
    fi
}

#------------------------------------------------------------------------------
# Fix Functions
#------------------------------------------------------------------------------

fix_cron_mode() {
    print_section "Setting Background Jobs Mode to Cron"
    
    occ background:cron
    if [ $? -eq 0 ]; then
        print_success "Background jobs mode set to cron"
    else
        print_error "Failed to set background jobs mode"
        return 1
    fi
}

create_systemd_service() {
    print_section "Creating Systemd Service"
    
    # Create the service file
    cat > /etc/systemd/system/nextcloud-cron.service << 'EOF'
[Unit]
Description=Nextcloud cron.php job
After=network.target
Requires=network.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/podman exec -u www-data nextcloud php -f /var/www/html/cron.php
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Service file created: /etc/systemd/system/nextcloud-cron.service"
    else
        print_error "Failed to create service file"
        return 1
    fi
}

create_systemd_timer() {
    print_section "Creating Systemd Timer"
    
    # Create the timer file
    cat > /etc/systemd/system/nextcloud-cron.timer << 'EOF'
[Unit]
Description=Run Nextcloud cron every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=nextcloud-cron.service

[Install]
WantedBy=timers.target
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Timer file created: /etc/systemd/system/nextcloud-cron.timer"
    else
        print_error "Failed to create timer file"
        return 1
    fi
}

enable_timer() {
    print_section "Enabling and Starting Timer"
    
    # Reload systemd
    systemctl daemon-reload
    print_success "Systemd daemon reloaded"
    
    # Enable timer
    systemctl enable nextcloud-cron.timer
    if [ $? -eq 0 ]; then
        print_success "Timer enabled"
    else
        print_error "Failed to enable timer"
        return 1
    fi
    
    # Start timer
    systemctl start nextcloud-cron.timer
    if [ $? -eq 0 ]; then
        print_success "Timer started"
    else
        print_error "Failed to start timer"
        return 1
    fi
    
    # Verify
    if systemctl is-active --quiet nextcloud-cron.timer; then
        print_success "Timer is now active"
    else
        print_error "Timer failed to start"
        return 1
    fi
}

run_cron_now() {
    print_section "Running Cron Manually"
    
    echo "Executing cron.php..."
    podman exec -u www-data "$NEXTCLOUD_CONTAINER" php -f /var/www/html/cron.php
    
    if [ $? -eq 0 ]; then
        print_success "Cron executed successfully"
        
        # Check the timestamp updated
        local last_cron=$(occ config:app:get core lastcron 2>/dev/null)
        if [ -n "$last_cron" ]; then
            local last_date=$(date -d "@$last_cron" 2>/dev/null)
            echo "  Last cron timestamp: $last_date"
        fi
    else
        print_error "Cron execution failed"
        return 1
    fi
}

fix_all_cron() {
    print_section "Complete Cron Fix"
    
    echo "This will:"
    echo "  1. Set Nextcloud to use cron mode"
    echo "  2. Create systemd service file"
    echo "  3. Create systemd timer file"
    echo "  4. Enable and start the timer"
    echo "  5. Run cron once to verify"
    echo ""
    
    if ! confirm "Continue?"; then
        return 0
    fi
    
    fix_cron_mode || return 1
    create_systemd_service || return 1
    create_systemd_timer || return 1
    enable_timer || return 1
    
    echo ""
    print_info "Waiting 5 seconds before test run..."
    sleep 5
    
    run_cron_now || return 1
    
    print_section "Cron Fix Complete"
    echo ""
    print_success "Cron should now run every 5 minutes"
    print_info "The warning in Nextcloud admin may take 5-10 minutes to clear"
    print_info "Run this script with 'status' to check anytime"
}

#------------------------------------------------------------------------------
# Alternative: Use Container's Built-in Cron
#------------------------------------------------------------------------------

setup_container_cron() {
    print_section "Alternative: Container Built-in Cron"
    
    echo "This sets up cron INSIDE the Nextcloud container."
    echo "This is an alternative to systemd timers."
    echo ""
    
    if ! confirm "Use container cron instead of systemd?"; then
        return 0
    fi
    
    # Install cron in container
    print_info "Installing cron in container..."
    podman exec "$NEXTCLOUD_CONTAINER" apt-get update
    podman exec "$NEXTCLOUD_CONTAINER" apt-get install -y cron
    
    # Create cron entry
    print_info "Creating cron entry..."
    podman exec "$NEXTCLOUD_CONTAINER" bash -c 'echo "*/5 * * * * www-data php -f /var/www/html/cron.php" > /etc/cron.d/nextcloud'
    podman exec "$NEXTCLOUD_CONTAINER" chmod 644 /etc/cron.d/nextcloud
    
    # Start cron service
    print_info "Starting cron service..."
    podman exec "$NEXTCLOUD_CONTAINER" service cron start
    
    # Disable systemd timer if it exists
    if systemctl is-active --quiet nextcloud-cron.timer 2>/dev/null; then
        print_info "Disabling systemd timer..."
        systemctl stop nextcloud-cron.timer
        systemctl disable nextcloud-cron.timer
    fi
    
    print_success "Container cron configured"
    print_warning "Note: This will reset if you rebuild the container"
}

#------------------------------------------------------------------------------
# Troubleshooting
#------------------------------------------------------------------------------

troubleshoot_cron() {
    print_section "Cron Troubleshooting Guide"
    
    cat << 'EOF'

COMMON ISSUES AND SOLUTIONS:

1. Timer not starting
   - Check: systemctl status nextcloud-cron.timer
   - Fix: systemctl daemon-reload && systemctl restart nextcloud-cron.timer

2. Service fails to run
   - Check: journalctl -u nextcloud-cron.service -n 20
   - Common cause: Container name mismatch
   - Fix: Verify container name with: podman ps

3. Cron runs but Nextcloud doesn't recognize it
   - Check: occ config:app:get core lastcron
   - Common cause: Wrong user (should be www-data)
   - Fix: Ensure ExecStart uses "-u www-data"

4. Permission errors
   - Check: podman exec nextcloud ls -la /var/www/html/cron.php
   - Fix: podman exec nextcloud chown www-data:www-data /var/www/html/cron.php

5. Container not found
   - Check: podman ps
   - Common cause: Container restarted with different name
   - Fix: Update service file with correct container name

DEBUG COMMANDS:

# Check if cron.php exists and is readable
podman exec nextcloud ls -la /var/www/html/cron.php

# Run cron manually with verbose output
podman exec -u www-data nextcloud php -f /var/www/html/cron.php

# Check Nextcloud logs for cron errors
podman exec nextcloud tail -50 /var/www/html/data/nextcloud.log | grep -i cron

# View all systemd timers
systemctl list-timers --all

# Check timer configuration
systemctl cat nextcloud-cron.timer

# Check service configuration
systemctl cat nextcloud-cron.service

EOF
}

#------------------------------------------------------------------------------
# Menu
#------------------------------------------------------------------------------

show_menu() {
    print_header
    echo -e "${BOLD}Cron/Background Jobs Management${NC}"
    echo ""
    echo "  1) Check cron status (diagnose)"
    echo "  2) Fix all cron issues (recommended)"
    echo "  3) Run cron manually now"
    echo "  4) View troubleshooting guide"
    echo ""
    echo "  Individual fixes:"
    echo "  5) Set Nextcloud to cron mode"
    echo "  6) Create/update systemd service"
    echo "  7) Create/update systemd timer"
    echo "  8) Enable and start timer"
    echo ""
    echo "  Alternative:"
    echo "  9) Use container built-in cron"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) check_cron_status ;;
        2) fix_all_cron ;;
        3) run_cron_now ;;
        4) troubleshoot_cron ;;
        5) fix_cron_mode ;;
        6) create_systemd_service ;;
        7) create_systemd_timer ;;
        8) enable_timer ;;
        9) setup_container_cron ;;
        0) exit 0 ;;
        *) print_error "Invalid option" ;;
    esac
    
    press_enter
    show_menu
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

case "${1:-}" in
    status|check)
        check_cron_status
        ;;
    fix)
        fix_all_cron
        ;;
    run)
        run_cron_now
        ;;
    help|--help|-h)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  status    Check cron status"
        echo "  fix       Fix all cron issues"
        echo "  run       Run cron manually"
        echo "  (none)    Show interactive menu"
        ;;
    *)
        show_menu
        ;;
esac
