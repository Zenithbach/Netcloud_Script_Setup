#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Quick Fixes Module
# Common fixes for frequent issues
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Fix: Permissions
#------------------------------------------------------------------------------

fix_permissions() {
    print_section "Fixing File Permissions"
    
    if [ ! -d "$DATA_DIR" ]; then
        print_error "Data directory not found: $DATA_DIR"
        return 1
    fi
    
    print_info "Setting ownership to www-data (33:33)..."
    chown -R 33:33 "$DATA_DIR"
    
    print_info "Setting directory permissions to 750..."
    chmod 750 "$DATA_DIR"
    
    # Check result
    if podman exec "$NEXTCLOUD_CONTAINER" test -w /var/www/html/data 2>/dev/null; then
        print_success "Data directory is now writable from container"
    else
        print_error "Data directory still not writable from container"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Fix: Database Connection
#------------------------------------------------------------------------------

fix_database() {
    print_section "Fixing Database Connection"
    
    # Check if MariaDB is running
    if ! is_container_running "$MARIADB_CONTAINER"; then
        print_warning "MariaDB not running, starting..."
        podman start "$MARIADB_CONTAINER"
        sleep 5
    fi
    
    # Test connection
    if podman exec "$MARIADB_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME; SELECT 1;" &>/dev/null; then
        print_success "Database connection working"
    else
        print_error "Database connection failed"
        print_info "Checking MariaDB logs..."
        podman logs --tail 20 "$MARIADB_CONTAINER" 2>&1
        return 1
    fi
}

#------------------------------------------------------------------------------
# Fix: Pod Networking
#------------------------------------------------------------------------------

fix_networking() {
    print_section "Fixing Pod Networking"
    
    print_info "Restarting pod to reset networking..."
    podman pod restart "$POD_NAME"
    sleep 5
    
    # Verify containers can communicate
    if podman exec "$NEXTCLOUD_CONTAINER" ping -c 1 "$MARIADB_HOST" &>/dev/null; then
        print_success "Pod networking working"
    else
        print_warning "Containers may not be able to communicate"
        print_info "Consider recreating the pod"
    fi
}

#------------------------------------------------------------------------------
# Fix: Port 8080
#------------------------------------------------------------------------------

fix_port_8080() {
    print_section "Fixing Port 8080"
    
    if ss -tlnp 2>/dev/null | grep -q ":8080"; then
        print_success "Port 8080 is already listening"
        return 0
    fi
    
    print_warning "Port 8080 not listening"
    print_info "Restarting pod..."
    
    podman pod restart "$POD_NAME"
    sleep 10
    
    if ss -tlnp 2>/dev/null | grep -q ":8080"; then
        print_success "Port 8080 now listening"
    else
        print_error "Port 8080 still not listening"
        print_info "Check container logs: podman logs $NEXTCLOUD_CONTAINER"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Fix: Container Not Starting
#------------------------------------------------------------------------------

fix_container_startup() {
    print_section "Fixing Container Startup"
    
    if is_container_running "$NEXTCLOUD_CONTAINER"; then
        print_success "Container is already running"
        return 0
    fi
    
    print_info "Attempting to start container..."
    podman start "$NEXTCLOUD_CONTAINER"
    sleep 10
    
    if is_container_running "$NEXTCLOUD_CONTAINER"; then
        print_success "Container started successfully"
    else
        print_error "Container failed to start"
        print_info "Checking logs..."
        podman logs --tail 30 "$NEXTCLOUD_CONTAINER" 2>&1
        return 1
    fi
}

#------------------------------------------------------------------------------
# Fix: Redis
#------------------------------------------------------------------------------

fix_redis() {
    print_section "Fixing Redis"
    
    if ! is_container_running "$REDIS_CONTAINER"; then
        if is_container_exists "$REDIS_CONTAINER"; then
            print_info "Starting Redis container..."
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
    
    # Test connection
    if podman exec "$REDIS_CONTAINER" redis-cli ping 2>/dev/null | grep -q "PONG"; then
        print_success "Redis is responding"
        
        # Configure in Nextcloud
        print_info "Configuring Redis in Nextcloud..."
        occ config:system:set memcache.local --value='\OC\Memcache\Redis'
        occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
        occ config:system:set redis host --value="$REDIS_HOST"
        occ config:system:set redis port --value="$REDIS_PORT" --type=integer
        
        print_success "Redis configured in Nextcloud"
    else
        print_error "Redis not responding"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Fix: Database Indexes
#------------------------------------------------------------------------------

fix_db_indexes() {
    print_section "Fixing Database Indexes"
    
    print_info "Adding missing database indexes..."
    occ db:add-missing-indices
    
    if [ $? -eq 0 ]; then
        print_success "Database indexes optimized"
    else
        print_error "Failed to add indexes"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Fix: Trusted Proxies
#------------------------------------------------------------------------------

fix_trusted_proxies() {
    print_section "Fixing Trusted Proxies"
    
    print_info "Setting trusted proxies..."
    occ config:system:set trusted_proxies 0 --value="127.0.0.1"
    occ config:system:set overwriteprotocol --value="https"
    occ config:system:set overwrite.cli.url --value="https://$DOMAIN"
    
    print_success "Trusted proxies configured"
}

#------------------------------------------------------------------------------
# Fix: Maintenance Window
#------------------------------------------------------------------------------

fix_maintenance_window() {
    print_section "Fixing Maintenance Window"
    
    print_info "Setting maintenance window to 1:00 AM UTC..."
    occ config:system:set maintenance_window_start --type=integer --value=1
    
    print_success "Maintenance window configured"
}

#------------------------------------------------------------------------------
# Fix All
#------------------------------------------------------------------------------

fix_all() {
    print_section "Running All Fixes"
    
    local errors=0
    
    fix_database || ((errors++))
    fix_networking || ((errors++))
    fix_permissions || ((errors++))
    fix_port_8080 || ((errors++))
    fix_redis || ((errors++))
    fix_db_indexes || ((errors++))
    fix_trusted_proxies || ((errors++))
    fix_maintenance_window || ((errors++))
    
    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All fixes applied successfully"
    else
        print_warning "$errors fix(es) had issues"
    fi
}

#------------------------------------------------------------------------------
# Menu
#------------------------------------------------------------------------------

show_menu() {
    print_header
    echo -e "${BOLD}Quick Fixes${NC}"
    echo ""
    echo "  1) Fix file permissions"
    echo "  2) Fix database connection"
    echo "  3) Fix pod networking"
    echo "  4) Fix port 8080"
    echo "  5) Fix container startup"
    echo "  6) Fix Redis caching"
    echo "  7) Fix database indexes"
    echo "  8) Fix trusted proxies"
    echo "  9) Fix maintenance window"
    echo ""
    echo "  A) Fix ALL issues"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) fix_permissions ;;
        2) fix_database ;;
        3) fix_networking ;;
        4) fix_port_8080 ;;
        5) fix_container_startup ;;
        6) fix_redis ;;
        7) fix_db_indexes ;;
        8) fix_trusted_proxies ;;
        9) fix_maintenance_window ;;
        [Aa]) fix_all ;;
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
    permissions) fix_permissions ;;
    database|db) fix_database ;;
    networking|network) fix_networking ;;
    port) fix_port_8080 ;;
    container) fix_container_startup ;;
    redis) fix_redis ;;
    indexes) fix_db_indexes ;;
    proxies) fix_trusted_proxies ;;
    maintenance) fix_maintenance_window ;;
    all) fix_all ;;
    *) show_menu ;;
esac
