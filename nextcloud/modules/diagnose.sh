#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Diagnostics Module
# System health checks and status reporting
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Quick Status
#------------------------------------------------------------------------------

quick_status() {
    print_section "Quick Status"
    
    # Containers
    echo -e "${BOLD}Containers:${NC}"
    for container in "$NEXTCLOUD_CONTAINER" "$MARIADB_CONTAINER" "$REDIS_CONTAINER"; do
        if is_container_running "$container"; then
            print_success "$container: running"
        elif is_container_exists "$container"; then
            print_warning "$container: stopped"
        else
            print_error "$container: not found"
        fi
    done
    
    # Pod
    echo ""
    echo -e "${BOLD}Pod:${NC}"
    if podman pod exists "$POD_NAME" 2>/dev/null; then
        print_success "$POD_NAME: exists"
    else
        print_error "$POD_NAME: not found"
    fi
    
    # Ports
    echo ""
    echo -e "${BOLD}Ports:${NC}"
    if ss -tlnp 2>/dev/null | grep -q ":8080"; then
        print_success "Port 8080: listening"
    else
        print_error "Port 8080: NOT listening"
    fi
    
    if ss -tlnp 2>/dev/null | grep -q ":443"; then
        print_success "Port 443: listening"
    else
        print_warning "Port 443: not listening (Nginx)"
    fi
    
    # Nginx
    echo ""
    echo -e "${BOLD}Nginx:${NC}"
    if systemctl is-active --quiet nginx; then
        print_success "Nginx: running"
    else
        print_error "Nginx: NOT running"
    fi
}

#------------------------------------------------------------------------------
# Detailed Diagnostics
#------------------------------------------------------------------------------

full_diagnostics() {
    print_section "Full System Diagnostics"
    
    # System Capabilities
    echo ""
    echo -e "${BOLD}=== System Capabilities ===${NC}"
    
    # Check PHP Memory
    local php_mem=$(podman exec "$NEXTCLOUD_CONTAINER" php -i 2>/dev/null | grep "memory_limit" | cut -d'>' -f2 | xargs)
    if [ "$php_mem" = "1G" ]; then
        print_success "PHP Memory Limit: $php_mem"
    else
        print_warning "PHP Memory Limit: $php_mem (Target: 1G)"
    fi
    
    # Check FFmpeg
    if podman exec "$NEXTCLOUD_CONTAINER" which ffmpeg >/dev/null 2>&1; then
        print_success "FFmpeg: Installed"
        podman exec "$NEXTCLOUD_CONTAINER" ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f3
    else
        print_error "FFmpeg: NOT installed"
    fi
    
    # Container details
    echo ""
    echo -e "${BOLD}=== Container Status ===${NC}"
    podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "NAMES|nextcloud|mariadb|redis"
    
    # Pod details
    echo ""
    echo -e "${BOLD}=== Pod Status ===${NC}"
    podman pod ps 2>/dev/null | grep -E "POD|$POD_NAME"
    
    # Network
    echo ""
    echo -e "${BOLD}=== Network ===${NC}"
    echo "Listening ports:"
    ss -tlnp 2>/dev/null | grep -E "8080|443|80|3306|6379" || echo "  No relevant ports found"
    
    # Database connection
    echo ""
    echo -e "${BOLD}=== Database Connection ===${NC}"
    if podman exec "$MARIADB_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        print_success "Database connection: OK"
        
        # Table count
        local tables=$(podman exec "$MARIADB_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | wc -l)
        echo "  Tables in $DB_NAME: $((tables - 1))"
    else
        print_error "Database connection: FAILED"
    fi
    
    # Redis connection
    echo ""
    echo -e "${BOLD}=== Redis Connection ===${NC}"
    if is_container_running "$REDIS_CONTAINER"; then
        if podman exec "$REDIS_CONTAINER" redis-cli ping 2>/dev/null | grep -q "PONG"; then
            print_success "Redis: responding"
        else
            print_warning "Redis: container running but not responding"
        fi
    else
        print_warning "Redis: not running"
    fi
    
    # Nextcloud status
    echo ""
    echo -e "${BOLD}=== Nextcloud Status ===${NC}"
    if is_container_running "$NEXTCLOUD_CONTAINER"; then
        occ status 2>/dev/null || print_warning "Could not get Nextcloud status"
    else
        print_error "Nextcloud container not running"
    fi
    
    # Data directory
    echo ""
    echo -e "${BOLD}=== Data Directory ===${NC}"
    if [ -d "$DATA_DIR" ]; then
        print_success "Path: $DATA_DIR"
        echo "  Size: $(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)"
        echo "  Owner: $(stat -c '%U:%G' "$DATA_DIR" 2>/dev/null)"
        echo "  Permissions: $(stat -c '%a' "$DATA_DIR" 2>/dev/null)"
        
        # Check writability from container
        if podman exec "$NEXTCLOUD_CONTAINER" test -w /var/www/html/data 2>/dev/null; then
            print_success "Writable from container: yes"
        else
            print_error "Writable from container: NO"
        fi
    else
        print_error "Data directory not found: $DATA_DIR"
    fi
    
    # SSL Certificate
    echo ""
    echo -e "${BOLD}=== SSL Certificate ===${NC}"
    if [ -f "$SSL_CERT" ]; then
        print_success "Certificate exists: $SSL_CERT"
        openssl x509 -in "$SSL_CERT" -noout -dates 2>/dev/null | sed 's/^/  /'
        
        # Check if expired
        if openssl x509 -in "$SSL_CERT" -noout -checkend 0 2>/dev/null; then
            print_success "Certificate: valid"
        else
            print_error "Certificate: EXPIRED"
        fi
    else
        print_error "Certificate not found: $SSL_CERT"
    fi
    
    # Disk space
    echo ""
    echo -e "${BOLD}=== Disk Space ===${NC}"
    df -h /mnt/cloud 2>/dev/null || df -h / | tail -1
    
    # Memory
    echo ""
    echo -e "${BOLD}=== Memory Usage ===${NC}"
    free -h | head -2
    
    # Cron status
    echo ""
    echo -e "${BOLD}=== Cron Status ===${NC}"
    if systemctl is-active --quiet nextcloud-cron.timer 2>/dev/null; then
        print_success "Cron timer: active"
        local last_cron=$(occ config:app:get core lastcron 2>/dev/null)
        if [ -n "$last_cron" ]; then
            local now=$(date +%s)
            local diff_mins=$(( (now - last_cron) / 60 ))
            echo "  Last run: $diff_mins minutes ago"
        fi
    else
        print_warning "Cron timer: not active"
    fi
    
    # Nextcloud admin warnings
    echo ""
    echo -e "${BOLD}=== Nextcloud Warnings ===${NC}"
    echo "Checking for common issues..."
    
    # Check trusted domains
    local trusted=$(occ config:system:get trusted_domains 0 2>/dev/null)
    if [ -n "$trusted" ]; then
        print_success "Trusted domain: $trusted"
    else
        print_warning "No trusted domains configured"
    fi
    
    # Check maintenance mode
    local maint=$(occ config:system:get maintenance 2>/dev/null)
    if [ "$maint" = "true" ]; then
        print_warning "Maintenance mode: ENABLED"
    else
        print_success "Maintenance mode: disabled"
    fi
}

#------------------------------------------------------------------------------
# Test Connectivity
#------------------------------------------------------------------------------

test_connectivity() {
    print_section "Connectivity Tests"
    
    echo -e "${BOLD}Testing HTTP (port 8080):${NC}"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null)
    if [ "$http_code" = "200" ] || [ "$http_code" = "302" ]; then
        print_success "HTTP response: $http_code"
    else
        print_error "HTTP response: $http_code (expected 200 or 302)"
    fi
    
    echo ""
    echo -e "${BOLD}Testing HTTPS (port 443):${NC}"
    local https_code=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost 2>/dev/null)
    if [ "$https_code" = "200" ] || [ "$https_code" = "302" ]; then
        print_success "HTTPS response: $https_code"
    else
        print_warning "HTTPS response: $https_code"
    fi
    
    echo ""
    echo -e "${BOLD}Testing domain ($DOMAIN):${NC}"
    if ping -c 1 "$DOMAIN" &>/dev/null; then
        print_success "Domain resolves"
        local domain_code=$(curl -sk -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null)
        echo "  HTTPS response: $domain_code"
    else
        print_warning "Domain does not resolve (check /etc/hosts or router DNS)"
    fi
    
    echo ""
    echo -e "${BOLD}Testing IP ($SERVER_IP):${NC}"
    local ip_code=$(curl -sk -o /dev/null -w "%{http_code}" "https://$SERVER_IP" 2>/dev/null)
    if [ "$ip_code" = "200" ] || [ "$ip_code" = "302" ]; then
        print_success "IP HTTPS response: $ip_code"
    else
        print_warning "IP HTTPS response: $ip_code"
    fi
}

#------------------------------------------------------------------------------
# Container Logs
#------------------------------------------------------------------------------

show_logs() {
    local container="${1:-$NEXTCLOUD_CONTAINER}"
    local lines="${2:-50}"
    
    print_section "Logs: $container (last $lines lines)"
    
    if is_container_exists "$container"; then
        podman logs --tail "$lines" "$container" 2>&1
    else
        print_error "Container not found: $container"
    fi
}

#------------------------------------------------------------------------------
# Menu
#------------------------------------------------------------------------------

show_menu() {
    print_header
    echo -e "${BOLD}Diagnostics${NC}"
    echo ""
    echo "  1) Quick status"
    echo "  2) Full diagnostics"
    echo "  3) Test connectivity"
    echo ""
    echo "  Logs:"
    echo "  4) Nextcloud logs"
    echo "  5) MariaDB logs"
    echo "  6) Redis logs"
    echo "  7) Nginx access log"
    echo "  8) Nginx error log"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) quick_status ;;
        2) full_diagnostics ;;
        3) test_connectivity ;;
        4) show_logs "$NEXTCLOUD_CONTAINER" ;;
        5) show_logs "$MARIADB_CONTAINER" ;;
        6) show_logs "$REDIS_CONTAINER" ;;
        7) tail -50 /var/log/nginx/nextcloud.access.log 2>/dev/null || print_warning "Log not found" ;;
        8) tail -50 /var/log/nginx/nextcloud.error.log 2>/dev/null || print_warning "Log not found" ;;
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
    quick|status)
        quick_status
        ;;
    full)
        full_diagnostics
        ;;
    test)
        test_connectivity
        ;;
    logs)
        show_logs "${2:-$NEXTCLOUD_CONTAINER}" "${3:-50}"
        ;;
    *)
        show_menu
        ;;
esac
