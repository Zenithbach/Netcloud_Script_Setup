#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Backup & Restore Module
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Backup Functions
#------------------------------------------------------------------------------

backup_config() {
    local backup_path="$1"
    
    print_section "Backing Up Configuration"
    
    # Nextcloud config
    if podman exec "$NEXTCLOUD_CONTAINER" test -f /var/www/html/config/config.php; then
        podman exec "$NEXTCLOUD_CONTAINER" cat /var/www/html/config/config.php > "$backup_path/config.php"
        print_success "Nextcloud config.php"
    fi
    
    # Nginx config
    if [ -f "$NGINX_CONF" ]; then
        cp "$NGINX_CONF" "$backup_path/nginx.conf"
        print_success "Nginx configuration"
    fi
    
    # SSL certificates
    if [ -f "$SSL_CERT" ]; then
        cp "$SSL_CERT" "$backup_path/nextcloud.crt"
        cp "$SSL_KEY" "$backup_path/nextcloud.key"
        print_success "SSL certificates"
    fi
    
    # Container configs
    podman inspect "$NEXTCLOUD_CONTAINER" > "$backup_path/nextcloud-container.json" 2>/dev/null
    podman inspect "$MARIADB_CONTAINER" > "$backup_path/mariadb-container.json" 2>/dev/null
    podman pod inspect "$POD_NAME" > "$backup_path/pod.json" 2>/dev/null
    print_success "Container configurations"
}

backup_database() {
    local backup_path="$1"
    
    print_section "Backing Up Database"
    
    print_info "Exporting database (this may take a while)..."
    
    if podman exec "$MARIADB_CONTAINER" mysqldump -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$backup_path/database.sql" 2>/dev/null; then
        local size=$(du -h "$backup_path/database.sql" | cut -f1)
        print_success "Database exported ($size)"
    else
        print_error "Database export failed"
        return 1
    fi
}

create_full_backup() {
    print_section "Creating Full Backup"
    
    local backup_path=$(create_backup_dir "full")
    
    echo "Backup location: $backup_path"
    echo ""
    
    backup_config "$backup_path"
    backup_database "$backup_path"
    
    # Create backup info
    cat > "$backup_path/backup-info.txt" << EOF
Backup Type: Full Configuration + Database
Created: $(date)
Server: $SERVER_IP
Domain: $DOMAIN

Contents:
- config.php (Nextcloud configuration)
- nginx.conf (Nginx configuration)
- nextcloud.crt/key (SSL certificates)
- database.sql (MariaDB dump)
- Container JSON files

NOTE: User data in $DATA_DIR is NOT included.
Backup user data separately with rsync.
EOF
    
    print_section "Backup Complete"
    echo ""
    print_success "Backup saved to: $backup_path"
    echo ""
    print_warning "User data NOT included - backup separately:"
    echo "  rsync -av $DATA_DIR /path/to/backup/data/"
}

list_backups() {
    print_section "Available Backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "Backup directory not found: $BACKUP_DIR"
        return
    fi
    
    echo ""
    ls -lht "$BACKUP_DIR" 2>/dev/null | head -20
    echo ""
    
    local count=$(find "$BACKUP_DIR" -maxdepth 1 -type d | wc -l)
    echo "Total backups: $((count - 1))"
}

#------------------------------------------------------------------------------
# Restore Functions
#------------------------------------------------------------------------------

restore_config() {
    local backup_path="$1"
    
    print_section "Restoring Configuration"
    
    # Nextcloud config
    if [ -f "$backup_path/config.php" ]; then
        podman cp "$backup_path/config.php" "$NEXTCLOUD_CONTAINER:/var/www/html/config/config.php"
        podman exec "$NEXTCLOUD_CONTAINER" chown www-data:www-data /var/www/html/config/config.php
        print_success "Nextcloud config.php restored"
    fi
    
    # Nginx config
    if [ -f "$backup_path/nginx.conf" ]; then
        cp "$backup_path/nginx.conf" "$NGINX_CONF"
        print_success "Nginx configuration restored"
    fi
    
    # SSL certificates
    if [ -f "$backup_path/nextcloud.crt" ]; then
        cp "$backup_path/nextcloud.crt" "$SSL_CERT"
        cp "$backup_path/nextcloud.key" "$SSL_KEY"
        chmod 644 "$SSL_CERT"
        chmod 600 "$SSL_KEY"
        print_success "SSL certificates restored"
    fi
}

restore_database() {
    local backup_path="$1"
    
    print_section "Restoring Database"
    
    if [ ! -f "$backup_path/database.sql" ]; then
        print_error "Database backup not found"
        return 1
    fi
    
    print_warning "This will OVERWRITE the current database!"
    if ! confirm "Continue?"; then
        return 0
    fi
    
    print_info "Restoring database..."
    
    if podman exec -i "$MARIADB_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$backup_path/database.sql"; then
        print_success "Database restored"
    else
        print_error "Database restore failed"
        return 1
    fi
}

restore_from_backup() {
    print_section "Restore from Backup"
    
    list_backups
    echo ""
    read -p "Enter backup directory name: " backup_name
    
    local restore_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$restore_path" ]; then
        print_error "Backup not found: $restore_path"
        return 1
    fi
    
    # Show backup info
    if [ -f "$restore_path/backup-info.txt" ]; then
        echo ""
        cat "$restore_path/backup-info.txt"
        echo ""
    fi
    
    echo "What to restore:"
    echo "  1) Configuration only"
    echo "  2) Database only"
    echo "  3) Both configuration and database"
    echo "  0) Cancel"
    echo ""
    read -p "Select option: " choice
    
    # Create pre-restore backup
    local pre_backup=$(create_backup_dir "pre_restore")
    backup_config "$pre_backup"
    print_info "Created pre-restore backup: $pre_backup"
    
    case $choice in
        1)
            restore_config "$restore_path"
            systemctl reload nginx
            podman restart "$NEXTCLOUD_CONTAINER"
            ;;
        2)
            restore_database "$restore_path"
            ;;
        3)
            restore_config "$restore_path"
            restore_database "$restore_path"
            systemctl reload nginx
            podman restart "$NEXTCLOUD_CONTAINER"
            ;;
        0)
            print_info "Restore cancelled"
            return 0
            ;;
    esac
    
    print_success "Restore complete"
}

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

cleanup_old_backups() {
    print_section "Cleanup Old Backups"
    
    list_backups
    echo ""
    
    read -p "Keep how many recent backups? [5]: " keep
    keep=${keep:-5}
    
    if ! confirm "Delete all but the $keep most recent backups?"; then
        return 0
    fi
    
    # Get directories sorted by time, skip the newest $keep
    local to_delete=$(ls -t "$BACKUP_DIR" | tail -n +$((keep + 1)))
    
    if [ -z "$to_delete" ]; then
        print_info "No backups to delete"
        return 0
    fi
    
    for dir in $to_delete; do
        rm -rf "$BACKUP_DIR/$dir"
        print_info "Deleted: $dir"
    done
    
    print_success "Cleanup complete"
}

#------------------------------------------------------------------------------
# Menu
#------------------------------------------------------------------------------

show_menu() {
    print_header
    echo -e "${BOLD}Backup & Restore${NC}"
    echo ""
    echo "  ${BOLD}Backup:${NC}"
    echo "  1) Create full backup (config + database)"
    echo "  2) List existing backups"
    echo ""
    echo "  ${BOLD}Restore:${NC}"
    echo "  3) Restore from backup"
    echo ""
    echo "  ${BOLD}Maintenance:${NC}"
    echo "  4) Cleanup old backups"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) create_full_backup ;;
        2) list_backups ;;
        3) restore_from_backup ;;
        4) cleanup_old_backups ;;
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
    backup|create) create_full_backup ;;
    list) list_backups ;;
    restore) restore_from_backup ;;
    cleanup) cleanup_old_backups ;;
    *) show_menu ;;
esac
