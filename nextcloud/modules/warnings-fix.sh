#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Admin Warnings Fix Module
# Fix common warnings shown in Nextcloud admin panel
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Check Current Warnings
#------------------------------------------------------------------------------

check_warnings() {
    print_section "Checking Current Status"
    
    echo -e "${BOLD}Background Jobs:${NC}"
    local bg_mode=$(occ config:system:get backgroundjobs_mode 2>/dev/null)
    if [ "$bg_mode" = "cron" ]; then
        print_success "Mode: cron"
    else
        print_warning "Mode: $bg_mode (should be 'cron')"
    fi
    
    local last_cron=$(occ config:app:get core lastcron 2>/dev/null)
    if [ -n "$last_cron" ]; then
        local now=$(date +%s)
        local diff_mins=$(( (now - last_cron) / 60 ))
        if [ $diff_mins -lt 10 ]; then
            print_success "Last run: $diff_mins minutes ago"
        else
            print_warning "Last run: $diff_mins minutes ago"
        fi
    else
        print_error "Never run"
    fi
    
    echo ""
    echo -e "${BOLD}Trusted Proxies:${NC}"
    local proxies=$(occ config:system:get trusted_proxies 2>/dev/null)
    if [ -n "$proxies" ]; then
        print_success "Configured"
    else
        print_warning "Not configured"
    fi
    
    echo ""
    echo -e "${BOLD}HTTPS Configuration:${NC}"
    local protocol=$(occ config:system:get overwriteprotocol 2>/dev/null)
    if [ "$protocol" = "https" ]; then
        print_success "Force HTTPS: enabled"
    else
        print_warning "Force HTTPS: not set"
    fi
    
    echo ""
    echo -e "${BOLD}Maintenance Window:${NC}"
    local maint_window=$(occ config:system:get maintenance_window_start 2>/dev/null)
    if [ -n "$maint_window" ]; then
        print_success "Set to: ${maint_window}:00 UTC"
    else
        print_warning "Not configured"
    fi
    
    echo ""
    echo -e "${BOLD}Memory Cache:${NC}"
    local cache=$(occ config:system:get memcache.local 2>/dev/null)
    if [ -n "$cache" ]; then
        print_success "Local cache: configured"
    else
        print_warning "Local cache: not configured"
    fi
    
    local locking=$(occ config:system:get memcache.locking 2>/dev/null)
    if [ -n "$locking" ]; then
        print_success "File locking: configured"
    else
        print_warning "File locking: not configured"
    fi
    
    echo ""
    echo -e "${BOLD}Database:${NC}"
    print_info "Checking for missing indexes..."
    occ db:add-missing-indices --dry-run 2>/dev/null | grep -E "Adding|Missing" || print_success "All indexes present"
}

#------------------------------------------------------------------------------
# Individual Fixes
#------------------------------------------------------------------------------

fix_background_jobs() {
    print_section "Fixing Background Jobs"
    
    # Set to cron mode
    occ background:cron
    print_success "Set background jobs mode to cron"
    
    # Check/create systemd timer
    if ! systemctl is-active --quiet nextcloud-cron.timer 2>/dev/null; then
        print_info "Creating systemd timer..."
        
        cat > /etc/systemd/system/nextcloud-cron.service << 'EOF'
[Unit]
Description=Nextcloud cron.php job
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/podman exec -u www-data nextcloud php -f /var/www/html/cron.php
StandardOutput=journal
StandardError=journal
EOF

        cat > /etc/systemd/system/nextcloud-cron.timer << 'EOF'
[Unit]
Description=Run Nextcloud cron every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

        systemctl daemon-reload
        systemctl enable nextcloud-cron.timer
        systemctl start nextcloud-cron.timer
        print_success "Systemd timer created and started"
    else
        print_success "Systemd timer already active"
    fi
    
    # Run cron now
    print_info "Running cron manually..."
    podman exec -u www-data "$NEXTCLOUD_CONTAINER" php -f /var/www/html/cron.php
    print_success "Cron executed"
}

fix_trusted_proxies() {
    print_section "Fixing Trusted Proxies"
    
    occ config:system:set trusted_proxies 0 --value="127.0.0.1"
    print_success "Added 127.0.0.1 to trusted proxies"
}

fix_https() {
    print_section "Fixing HTTPS Configuration"
    
    occ config:system:set overwriteprotocol --value="https"
    occ config:system:set overwrite.cli.url --value="https://$DOMAIN"
    occ config:system:set overwritehost --value="$DOMAIN"
    
    print_success "HTTPS configuration updated"
}

fix_maintenance_window() {
    print_section "Fixing Maintenance Window"
    
    # Set to 1 AM UTC
    occ config:system:set maintenance_window_start --type=integer --value=1
    
    print_success "Maintenance window set to 1:00 AM UTC"
}

fix_database_indexes() {
    print_section "Fixing Database Indexes"
    
    occ db:add-missing-indices
    
    print_success "Database indexes updated"
}

fix_redis_caching() {
    print_section "Fixing Redis Caching"
    
    # Check if Redis is running
    if ! is_container_running "$REDIS_CONTAINER"; then
        print_warning "Redis container not running"
        
        if is_container_exists "$REDIS_CONTAINER"; then
            print_info "Starting Redis..."
            podman start "$REDIS_CONTAINER"
        else
            print_info "Creating Redis container..."
            podman run -d \
                --name "$REDIS_CONTAINER" \
                --pod "$POD_NAME" \
                --restart=always \
                docker.io/library/redis:alpine
        fi
        sleep 3
    fi
    
    # Configure in Nextcloud
    occ config:system:set memcache.local --value='\OC\Memcache\Redis'
    occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
    occ config:system:set redis host --value="$REDIS_HOST"
    occ config:system:set redis port --value="$REDIS_PORT" --type=integer
    
    print_success "Redis caching configured"
}

fix_default_phone_region() {
    print_section "Fixing Default Phone Region"
    
    occ config:system:set default_phone_region --value="US"
    
    print_success "Default phone region set to US"
}

fix_hsts() {
    print_section "Fixing HSTS Header"
    
    if [ ! -f "$NGINX_CONF" ]; then
        print_error "Nginx config not found: $NGINX_CONF"
        return 1
    fi
    
    # Check current HSTS setting
    if grep -q "Strict-Transport-Security" "$NGINX_CONF"; then
        local current=$(grep "Strict-Transport-Security" "$NGINX_CONF" | grep -o 'max-age=[0-9]*' | cut -d'=' -f2)
        
        if [ "$current" -ge 15552000 ]; then
            print_success "HSTS already configured correctly (max-age=$current)"
            return 0
        fi
        
        # Update the value
        sed -i 's/max-age=[0-9]*/max-age=15768000/' "$NGINX_CONF"
        print_success "HSTS max-age updated to 15768000"
    else
        print_warning "HSTS header not found in Nginx config"
        print_info "You may need to regenerate the Nginx configuration"
    fi
    
    systemctl reload nginx 2>/dev/null
}

#------------------------------------------------------------------------------
# Fix All
#------------------------------------------------------------------------------

fix_all_warnings() {
    print_section "Fixing All Admin Warnings"
    
    echo "This will fix:"
    echo "  • Background jobs (cron)"
    echo "  • Trusted proxies"
    echo "  • HTTPS configuration"
    echo "  • Maintenance window"
    echo "  • Database indexes"
    echo "  • Redis caching"
    echo "  • Default phone region"
    echo "  • HSTS header"
    echo ""
    
    if ! confirm "Continue?"; then
        return 0
    fi
    
    fix_background_jobs
    fix_trusted_proxies
    fix_https
    fix_maintenance_window
    fix_database_indexes
    fix_redis_caching
    fix_default_phone_region
    fix_hsts
    
    print_section "All Fixes Applied"
    echo ""
    print_warning "Some warnings may take 5-10 minutes to clear"
    print_info "Refresh the admin page after waiting"
}

#------------------------------------------------------------------------------
# Menu
#------------------------------------------------------------------------------

show_menu() {
    print_header
    echo -e "${BOLD}Fix Admin Warnings${NC}"
    echo ""
    echo "  1) Check current status"
    echo "  2) Fix ALL warnings (recommended)"
    echo ""
    echo "  Individual fixes:"
    echo "  3) Background jobs (cron)"
    echo "  4) Trusted proxies"
    echo "  5) HTTPS configuration"
    echo "  6) Maintenance window"
    echo "  7) Database indexes"
    echo "  8) Redis caching"
    echo "  9) Default phone region"
    echo "  10) HSTS header"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) check_warnings ;;
        2) fix_all_warnings ;;
        3) fix_background_jobs ;;
        4) fix_trusted_proxies ;;
        5) fix_https ;;
        6) fix_maintenance_window ;;
        7) fix_database_indexes ;;
        8) fix_redis_caching ;;
        9) fix_default_phone_region ;;
        10) fix_hsts ;;
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
    check|status) check_warnings ;;
    all|fix) fix_all_warnings ;;
    cron) fix_background_jobs ;;
    proxy|proxies) fix_trusted_proxies ;;
    https|ssl) fix_https ;;
    maintenance) fix_maintenance_window ;;
    db|database|indexes) fix_database_indexes ;;
    redis|cache) fix_redis_caching ;;
    phone) fix_default_phone_region ;;
    hsts) fix_hsts ;;
    *) show_menu ;;
esac
