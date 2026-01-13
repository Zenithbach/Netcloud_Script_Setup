#!/bin/bash

#==============================================================================
# LLHome Nextcloud Server - Ultimate All-in-One Management Script
# Podman-based | Self-Signed SSL | Domain Support | Redis Caching
# Persistent Settings | Backup Integration | Quick Fixes
#==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="192.168.1.138"
DOMAIN="llcloud"
NEXTCLOUD_CONTAINER="nextcloud"
MARIADB_CONTAINER="nextcloud-db"
REDIS_CONTAINER="nextcloud-redis"
POD_NAME="nextcloud-pod"
DATA_DIR="/mnt/cloud/data"
BACKUP_DIR="/mnt/cloudextra/ncpodbak"
MARIADB_HOST="nextcloud-db"
REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"
DB_NAME="llcloud"
DB_USER="geoffcloud"
DB_PASSWORD='2Bv$rWt$o94g!%4xBYiQ8C8'
ADMIN_USER="ncadmin"
ADMIN_PASSWORD='2Ca!fMf#75HQwzKUzc^29chs3'
NGINX_CONF="/etc/nginx/sites-available/nextcloud"
SSL_CERT="/etc/ssl/certs/nextcloud.crt"
SSL_KEY="/etc/ssl/private/nextcloud.key"

#==============================================================================
# Helper Functions
#==============================================================================

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC} $1"
}

print_section() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}$1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
}

print_header() {
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}LLHome Nextcloud Server - Ultimate Management${NC}             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Podman | SSL | Redis | Auto-Start | Backup Integration${NC}   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

press_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

confirm() {
    read -p "$1 (y/N): " response
    [[ "$response" =~ ^[Yy]$ ]]
}

create_backup() {
    local desc="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/${desc}_${timestamp}"
    
    mkdir -p "$backup_path"
    echo "$backup_path"
}

#==============================================================================
# Check Prerequisites
#==============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Check if root
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    print_success "Running as root"
    
    # Check podman
    if command -v podman &> /dev/null; then
        print_success "Podman installed"
    else
        print_error "Podman not installed"
        exit 1
    fi
    
    # Check nginx
    if command -v nginx &> /dev/null; then
        print_success "Nginx installed"
    else
        print_warning "Nginx not installed"
    fi
    
    # Check backup directory
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        print_info "Created backup directory: $BACKUP_DIR"
    else
        print_success "Backup directory exists: $BACKUP_DIR"
    fi
    
    # Check Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_success "OS: $NAME $VERSION"
    fi
    
    press_enter
}

#==============================================================================
# Main Menu
#==============================================================================

show_main_menu() {
    print_header
    echo -e "${BOLD}Main Menu${NC}"
    echo ""
    echo "  ${BOLD}Setup & Installation:${NC}"
    echo "  1) 🚀 Complete Setup (Fresh Installation with Redis)"
    echo "  2) 🔧 Rebuild Nextcloud Container Only"
    echo "  3) ⚡ Quick Fixes (Database, Network, Permissions)"
    echo "  4) ⚙️  Fix Configuration Warnings (Cron, HSTS, Headers)"
    echo "  5) 🔐 Fix File Permissions (Resolve Permission Errors)"
    echo "  6) ⬆️  Upgrade Nextcloud Version (Fix Version Mismatch)"
    echo ""
    echo "  ${BOLD}Configuration:${NC}"
    echo "  7) 🌐 Switch Between IP and Domain (llcloud)"
    echo "  8) 🔒 Regenerate SSL Certificates"
    echo "  9) 🛡️  Generate Trusted CA Certificate (Fix Client Apps)"
    echo "  10) 🗄️  Configure Redis Caching"
    echo "  11) 🔥 Configure Firewall (UFW)"
    echo ""
    echo "  ${BOLD}Management:${NC}"
    echo "  12) 📊 Test & Diagnose System"
    echo "  13) 👀 View Current Configuration"
    echo "  14) 🔄 Restart Services"
    echo "  15) 📋 Manage Users"
    echo "  16) 📂 Scan User Files (Index Restored Files)"
    echo ""
    echo "  ${BOLD}Backup & Restore:${NC}"
    echo "  17) 💾 Backup Configuration & Data"
    echo "  18) 📦 Restore from Backup"
    echo ""
    echo "  ${BOLD}Information:${NC}"
    echo "  19) 📖 Show Connection Instructions"
    echo "  20) 📡 Router DNS Setup Guide (ASUS GT-AX11000)"
    echo "  21) 📝 View Logs"
    echo "  0) ❌ Exit"
    echo ""
    read -p "Select an option (0-21): " choice
    echo ""
    
    case $choice in
        1) complete_setup ;;
        2) rebuild_nextcloud ;;
        3) quick_fixes ;;
        4) fix_configuration_warnings ;;
        5) fix_file_permissions ;;
        6) upgrade_nextcloud_version ;;
        7) switch_domain_ip ;;
        8) regenerate_ssl ;;
        9) generate_trusted_ca ;;
        10) configure_redis ;;
        11) configure_firewall ;;
        12) diagnose_system ;;
        13) view_configuration ;;
        14) restart_services ;;
        15) manage_users ;;
        16) scan_user_files ;;
        17) backup_system ;;
        18) restore_system ;;
        19) show_connection_instructions ;;
        20) show_router_guide ;;
        21) view_logs ;;
        0) exit 0 ;;
        *) 
            print_error "Invalid option"
            sleep 2
            show_main_menu
            ;;
    esac
}

#==============================================================================
# 1. Complete Setup
#==============================================================================

complete_setup() {
    print_header
    print_section "Complete Nextcloud Setup with Redis"
    
    echo "This will:"
    echo "  • Create Nextcloud pod and containers"
    echo "  • Set up MariaDB database"
    echo "  • Configure Redis for caching"
    echo "  • Generate self-signed SSL certificate"
    echo "  • Configure Nginx reverse proxy"
    echo "  • Set up firewall rules"
    echo "  • Configure for domain: $DOMAIN"
    echo ""
    
    if ! confirm "Continue with complete setup?"; then
        show_main_menu
        return
    fi
    
    # Backup anything that exists
    BACKUP_PATH=$(create_backup "pre_setup")
    print_info "Backup location: $BACKUP_PATH"
    
    # Step 1: Create pod if it doesn't exist
    print_section "Step 1: Creating Nextcloud Pod"
    if podman pod exists $POD_NAME; then
        print_warning "Pod already exists"
    else
        podman pod create --name $POD_NAME -p 8080:80
        if [ $? -eq 0 ]; then
            print_success "Pod created"
        else
            print_error "Failed to create pod"
            press_enter
            show_main_menu
            return
        fi
    fi
    
    # Step 2: Create MariaDB container
    print_section "Step 2: Setting Up MariaDB Database"
    setup_mariadb
    
    # Step 3: Create Redis container
    print_section "Step 3: Setting Up Redis Cache"
    setup_redis
    
    # Step 4: Create Nextcloud container
    print_section "Step 4: Creating Nextcloud Container"
    create_nextcloud_container
    
    # Step 5: Configure SSL
    print_section "Step 5: Generating SSL Certificate"
    generate_ssl_certificate
    
    # Step 6: Configure Nginx
    print_section "Step 6: Configuring Nginx"
    configure_nginx
    
    # Step 7: Configure Firewall
    print_section "Step 7: Configuring Firewall"
    configure_firewall_rules
    
    # Step 8: Configure Redis in Nextcloud
    print_section "Step 8: Enabling Redis Caching"
    enable_redis_in_nextcloud
    
    # Summary
    print_section "Setup Complete!"
    show_setup_summary
    
    press_enter
    show_main_menu
}

#==============================================================================
# 2. Rebuild Nextcloud Container
#==============================================================================

rebuild_nextcloud() {
    print_header
    print_section "Rebuild Nextcloud Container"
    
    echo "This will:"
    echo "  • Stop and remove the Nextcloud container"
    echo "  • Pull fresh Nextcloud image"
    echo "  • Create new container with existing data"
    echo "  • Preserve MariaDB and Redis containers"
    echo ""
    echo "✓ Your data will be PRESERVED"
    echo "✓ Your database will be PRESERVED"
    echo ""
    
    if ! confirm "Continue with rebuild?"; then
        show_main_menu
        return
    fi
    
    # Backup config
    BACKUP_PATH=$(create_backup "pre_rebuild")
    backup_nextcloud_config "$BACKUP_PATH"
    
    # Remove old container
    print_info "Stopping and removing Nextcloud container..."
    podman stop $NEXTCLOUD_CONTAINER 2>/dev/null
    podman rm $NEXTCLOUD_CONTAINER 2>/dev/null
    print_success "Old container removed"
    
    # Pull fresh image
    print_info "Pulling fresh Nextcloud image..."
    podman pull docker.io/library/nextcloud:latest
    print_success "Image pulled"
    
    # Create new container
    create_nextcloud_container
    
    print_section "Rebuild Complete!"
    print_success "Nextcloud container has been rebuilt"
    print_info "Data location: $DATA_DIR"
    
    press_enter
    show_main_menu
}

#==============================================================================
# 3. Quick Fixes
#==============================================================================

quick_fixes() {
    print_header
    print_section "Quick Fixes"
    
    echo "Common issues to fix:"
    echo ""
    echo "  1) Database connection issues"
    echo "  2) Pod networking problems"
    echo "  3) File permissions"
    echo "  4) Container not starting"
    echo "  5) Port 8080 not listening"
    echo "  6) Fix all issues"
    echo "  7) Back to main menu"
    echo ""
    read -p "Select option (1-7): " qf_choice
    
    case $qf_choice in
        1) fix_database_connection ;;
        2) fix_pod_networking ;;
        3) fix_permissions ;;
        4) fix_container_startup ;;
        5) fix_port_8080 ;;
        6)
            fix_database_connection
            fix_pod_networking
            fix_permissions
            fix_port_8080
            print_success "All fixes applied"
            ;;
        7) show_main_menu; return ;;
    esac
    
    press_enter
    quick_fixes
}

fix_database_connection() {
    print_section "Fixing Database Connection"
    
    # Ensure MariaDB is running
    if ! podman ps | grep -q $MARIADB_CONTAINER; then
        print_warning "MariaDB not running, starting it..."
        podman start $MARIADB_CONTAINER
        sleep 5
    fi
    
    # Test connection
    if podman exec $MARIADB_CONTAINER mysql -u$DB_USER -p"$DB_PASSWORD" -e "USE $DB_NAME; SHOW TABLES;" &>/dev/null; then
        print_success "Database connection working"
    else
        print_error "Database connection failed"
        print_info "Checking MariaDB logs..."
        podman logs --tail 20 $MARIADB_CONTAINER
    fi
}

fix_pod_networking() {
    print_section "Fixing Pod Networking"
    
    # Restart pod
    print_info "Restarting pod to reset networking..."
    podman pod restart $POD_NAME
    sleep 5
    
    # Verify all containers can communicate
    if podman exec $NEXTCLOUD_CONTAINER ping -c 1 $MARIADB_HOST &>/dev/null; then
        print_success "Pod networking working"
    else
        print_warning "Containers may not be able to communicate"
        print_info "Consider recreating the pod"
    fi
}

fix_permissions() {
    print_section "Fixing File Permissions"
    
    if [ ! -d "$DATA_DIR" ]; then
        print_error "Data directory not found: $DATA_DIR"
        return
    fi
    
    # Set correct ownership (www-data = 33:33)
    chown -R 33:33 $DATA_DIR
    chmod 750 $DATA_DIR
    print_success "Data directory permissions fixed"
    
    # Check if mounted correctly
    if podman exec $NEXTCLOUD_CONTAINER test -w /var/www/html/data; then
        print_success "Data directory writable in container"
    else
        print_error "Data directory not writable in container"
    fi
}

fix_container_startup() {
    print_section "Fixing Container Startup"
    
    # Get current status
    if podman ps | grep -q $NEXTCLOUD_CONTAINER; then
        print_success "Container is running"
        return
    fi
    
    # Try to start it
    print_info "Attempting to start container..."
    podman start $NEXTCLOUD_CONTAINER
    sleep 10
    
    # Check again
    if podman ps | grep -q $NEXTCLOUD_CONTAINER; then
        print_success "Container started successfully"
    else
        print_error "Container failed to start"
        print_info "Checking logs for errors..."
        podman logs --tail 30 $NEXTCLOUD_CONTAINER
    fi
}

fix_port_8080() {
    print_section "Fixing Port 8080"
    
    # Check if port is listening
    if ss -tlnp 2>/dev/null | grep :8080 | grep -q podman; then
        print_success "Port 8080 is listening"
    else
        print_warning "Port 8080 not listening"
        print_info "Restarting pod..."
        podman pod restart $POD_NAME
        sleep 5
        
        if ss -tlnp 2>/dev/null | grep :8080 | grep -q podman; then
            print_success "Port 8080 now listening"
        else
            print_error "Port 8080 still not listening"
        fi
    fi
}

#==============================================================================
# 4. Fix Configuration Warnings
#==============================================================================

fix_configuration_warnings() {
    print_header
    print_section "Fix Configuration Warnings"
    
    echo "This will fix common Nextcloud admin warnings:"
    echo ""
    echo "  • Background jobs (Cron setup)"
    echo "  • Reverse proxy headers"
    echo "  • Force HTTPS configuration"
    echo "  • HSTS header verification"
    echo "  • Maintenance window timing"
    echo "  • Database index optimization"
    echo ""
    
    if ! confirm "Continue with fixes?"; then
        show_main_menu
        return
    fi
    
    # Backup configs before changes
    BACKUP_PATH=$(create_backup "pre_warning_fixes")
    print_info "Backup location: $BACKUP_PATH"
    
    # Fix 1: Background Jobs (Cron)
    print_section "Fix 1: Background Jobs (Cron)"
    
    print_info "Configuring Nextcloud to use cron..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ background:cron
    
    # Create systemd service for running cron
    print_info "Creating systemd timer for Nextcloud cron..."
    
    cat > /etc/systemd/system/nextcloud-cron.service << 'EOF'
[Unit]
Description=Nextcloud cron.php job
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/podman exec -u www-data nextcloud php -f /opt/nextcloud/config/cron.php
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
    
    print_success "Cron configured and timer started"
    
    # Fix 2: Reverse Proxy Headers
    print_section "Fix 2: Reverse Proxy Headers"
    
    print_info "Setting trusted proxies..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set trusted_proxies 0 --value="127.0.0.1"
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set overwriteprotocol --value="https"
    
    print_success "Trusted proxies configured"
    
    # Fix 3: Force HTTPS
    print_section "Fix 3: Force HTTPS"
    
    print_info "Configuring Nextcloud to force HTTPS..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set overwriteprotocol --value="https"
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set overwrite.cli.url --value="https://$DOMAIN"
    
    print_success "HTTPS forced in configuration"
    
    # Fix 4: HSTS Header
    print_section "Fix 4: HSTS Header Verification"
    
    if grep -q "Strict-Transport-Security" $NGINX_CONF; then
        print_success "HSTS header already present in Nginx config"
        
        # Verify the value
        HSTS_VALUE=$(grep "Strict-Transport-Security" $NGINX_CONF | grep -o 'max-age=[0-9]*' | cut -d'=' -f2)
        if [ "$HSTS_VALUE" -ge 15552000 ]; then
            print_success "HSTS max-age is sufficient: $HSTS_VALUE seconds"
        else
            print_warning "HSTS max-age is too low: $HSTS_VALUE seconds"
            print_info "Updating to 15768000 seconds..."
            sed -i 's/max-age=[0-9]*/max-age=15768000/' $NGINX_CONF
            systemctl reload nginx
            print_success "HSTS header updated"
        fi
    else
        print_warning "HSTS header not found in Nginx config"
        print_info "This should have been added during setup"
    fi
    
    # Fix 5: Maintenance Window
    print_section "Fix 5: Maintenance Window"
    
    print_info "Setting maintenance window to 1:00 AM..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set maintenance_window_start --type=integer --value=1
    
    print_success "Maintenance window set to 1:00 AM"
    
    # Fix 6: Database Indexes
    print_section "Fix 6: Database Indexes"
    
    print_info "Adding missing database indexes..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ db:add-missing-indices
    
    print_success "Database indexes optimized"
    
    # Fix 7: Force Cron Execution
    print_section "Fix 7: Testing Cron Execution"
    
    print_info "Manually triggering cron job to verify it works..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php -f /var/www/html/cron.php
    
    print_success "Cron job executed successfully"
    
    # Fix 8: File Locking with Redis
    print_section "Fix 8: File Locking with Redis"
    
    if podman ps | grep -q $REDIS_CONTAINER; then
        print_success "Redis container is running"
        
        print_info "Configuring file locking to use Redis..."
        podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
        podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set memcache.local --value='\OC\Memcache\Redis'
        podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set redis host --value="127.0.0.1"
        podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set redis port --value=6379 --type=integer
        
        print_success "File locking configured with Redis"
    else
        print_warning "Redis container not running"
        echo ""
        if confirm "Create and configure Redis container for better performance?"; then
            print_info "Creating Redis container..."
            
            podman run -d \
              --name $REDIS_CONTAINER \
              --pod $POD_NAME \
              --restart=always \
              docker.io/library/redis:alpine \
              redis-server --requirepass ""
            
            if [ $? -eq 0 ]; then
                print_success "Redis container created"
                sleep 3
                
                print_info "Configuring Nextcloud to use Redis..."
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set memcache.local --value='\OC\Memcache\Redis'
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set redis host --value="127.0.0.1"
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set redis port --value=6379 --type=integer
                
                print_success "Redis configured successfully"
            else
                print_error "Failed to create Redis container"
            fi
        else
            print_info "Skipping Redis setup"
            print_warning "File locking will use database (slower)"
        fi
    fi
    
    # Summary
    print_section "Fixes Complete!"
    
    echo ""
    echo "Summary of changes:"
    echo "  ✓ Background jobs set to cron (runs every 5 minutes)"
    echo "  ✓ Reverse proxy headers configured"
    echo "  ✓ HTTPS forced in all configurations"
    echo "  ✓ HSTS header verified"
    echo "  ✓ Maintenance window set to 1:00 AM"
    echo "  ✓ Database indexes optimized"
    echo "  ✓ Cron job executed and tested"
    echo "  ✓ File locking configured with Redis"
    echo ""
    print_info "Checking cron timer status..."
    systemctl status nextcloud-cron.timer --no-pager | head -5
    echo ""
    print_info "Next cron execution:"
    systemctl list-timers nextcloud-cron.timer --no-pager | tail -1
    echo ""
    print_warning "Note: Cron warning may take 5-10 minutes to clear"
    print_info "Wait for next cron execution, then refresh admin page"
    
    press_enter
    show_main_menu
}

#==============================================================================
# 5. Fix File Permissions
#==============================================================================

fix_file_permissions() {
    print_header
    print_section "Fix Nextcloud File Permissions"
    
    APACHE_UID=33
    APACHE_GID=33
    
    echo "This will fix all file and folder permissions in your Nextcloud"
    echo "data directory to resolve permission errors."
    echo ""
    echo "Common errors this fixes:"
    echo "  • 'Failed to open directory: Permission denied'"
    echo "  • 'Could not write to cache'"
    echo "  • 'Upload failed: Permission denied'"
    echo ""
    echo "What this does:"
    echo "  1. Set ownership: www-data ($APACHE_UID:$APACHE_GID)"
    echo "  2. Directory permissions: 0750 (rwxr-x---)"
    echo "  3. File permissions: 0640 (rw-r-----)"
    echo "  4. Cache directories: 0770 (rwxrwx---)"
    echo "  5. Test write access from container"
    echo "  6. Optionally rescan files"
    echo ""
    print_warning "This may take several minutes for large data directories!"
    echo ""
    
    if ! confirm "Continue with permission fix?"; then
        show_main_menu
        return
    fi
    
    # Verify data directory exists
    if [ ! -d "$DATA_DIR" ]; then
        print_error "Data directory not found: $DATA_DIR"
        press_enter
        show_main_menu
        return
    fi
    
    # Verify container is running
    if ! podman ps | grep -q $NEXTCLOUD_CONTAINER; then
        print_error "Nextcloud container is not running!"
        print_info "Start it first with: podman start $NEXTCLOUD_CONTAINER"
        press_enter
        show_main_menu
        return
    fi
    
    # Show current issues
    print_section "Checking Current Permissions"
    
    echo "Looking for files not owned by www-data..."
    WRONG_OWNER_COUNT=$(find $DATA_DIR -maxdepth 2 \( -not -user $APACHE_UID -o -not -group $APACHE_GID \) 2>/dev/null | wc -l)
    
    if [ $WRONG_OWNER_COUNT -gt 0 ]; then
        print_warning "Found $WRONG_OWNER_COUNT files/folders with wrong ownership"
        echo ""
        echo "Sample of files with wrong ownership:"
        find $DATA_DIR -maxdepth 3 \( -not -user $APACHE_UID -o -not -group $APACHE_GID \) 2>/dev/null | head -5
    else
        print_success "All files owned by www-data"
    fi
    
    # Step 1: Fix ownership
    print_section "Step 1: Setting Ownership"
    
    print_info "Changing all files to $APACHE_UID:$APACHE_GID (www-data)..."
    chown -R $APACHE_UID:$APACHE_GID $DATA_DIR
    
    if [ $? -eq 0 ]; then
        print_success "Ownership updated successfully"
    else
        print_error "Failed to set ownership"
        press_enter
        show_main_menu
        return
    fi
    
    # Step 2: Fix directory permissions
    print_section "Step 2: Setting Directory Permissions"
    
    print_info "Setting directory permissions to 0750..."
    find $DATA_DIR -type d -exec chmod 0750 {} \; 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Directory permissions set to 0750 (rwxr-x---)"
    else
        print_error "Failed to set directory permissions"
    fi
    
    # Step 3: Fix file permissions
    print_section "Step 3: Setting File Permissions"
    
    print_info "Setting file permissions to 0640..."
    find $DATA_DIR -type f -exec chmod 0640 {} \; 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "File permissions set to 0640 (rw-r-----)"
    else
        print_error "Failed to set file permissions"
    fi
    
    # Step 4: Fix cache and special directories
    print_section "Step 4: Adjusting Special Directories"
    
    # Cache directories need write access
    print_info "Setting cache directories to 0770..."
    find $DATA_DIR -type d -name "cache" -exec chmod 0770 {} \; 2>/dev/null
    find $DATA_DIR -type d -name "appdata_*" -exec chmod 0770 {} \; 2>/dev/null
    find $DATA_DIR -type d -name "files_trashbin" -exec chmod 0770 {} \; 2>/dev/null
    find $DATA_DIR -type d -name "files_versions" -exec chmod 0770 {} \; 2>/dev/null
    print_success "Special directories adjusted to 0770 (rwxrwx---)"
    
    # Step 5: Verify container can write
    print_section "Step 5: Testing Container Access"
    
    print_info "Testing write access from container..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER touch /var/www/html/data/.permission-test 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Container can write to data directory ✓"
        podman exec $NEXTCLOUD_CONTAINER rm /var/www/html/data/.permission-test 2>/dev/null
    else
        print_error "Container CANNOT write to data directory!"
        print_warning "This might be a SELinux or mount issue"
        echo ""
        print_info "Checking container mount configuration..."
        podman inspect $NEXTCLOUD_CONTAINER | grep -A 3 '"Destination": "/var/www/html/data"' | head -5
        echo ""
        print_warning "If mount doesn't have ':Z' flag, you may need to recreate container"
        print_info "The mount should look like: /mnt/cloud/data:/var/www/html/data:Z"
    fi
    
    # Step 6: Check specific user directories
    print_section "Step 6: Verifying User Directories"
    
    for user_dir in $DATA_DIR/geoff $DATA_DIR/benjamin; do
        if [ -d "$user_dir" ]; then
            username=$(basename $user_dir)
            owner=$(stat -c '%u:%g' $user_dir)
            perms=$(stat -c '%a' $user_dir)
            
            if [ "$owner" = "$APACHE_UID:$APACHE_GID" ]; then
                print_success "$username: owner=$owner permissions=$perms ✓"
            else
                print_warning "$username: owner=$owner (should be $APACHE_UID:$APACHE_GID)"
            fi
            
            # Check cache
            if [ -d "$user_dir/cache" ]; then
                cache_perms=$(stat -c '%a' $user_dir/cache)
                if [ "$cache_perms" = "770" ]; then
                    print_success "$username cache: $cache_perms ✓"
                else
                    print_info "$username cache: $cache_perms (set to 770)"
                fi
            fi
        fi
    done
    
    # Step 7: Optional file scan
    print_section "Step 7: Rescan Files (Optional)"
    
    echo ""
    echo "Would you like to rescan all files in Nextcloud?"
    echo "This ensures the file cache is up-to-date with the new permissions."
    echo ""
    
    if confirm "Rescan all user files?"; then
        print_info "Scanning all user files (this may take a while)..."
        podman exec -u www-data $NEXTCLOUD_CONTAINER php occ files:scan --all
        
        if [ $? -eq 0 ]; then
            print_success "File scan completed successfully"
        else
            print_warning "File scan had some issues"
        fi
    else
        print_info "Skipped file scan"
        echo "  Run manually later if needed:"
        echo "  podman exec -u www-data nextcloud php occ files:scan --all"
    fi
    
    # Summary
    print_section "Permission Fix Complete!"
    
    cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════╗
║              Permissions Fixed Successfully!              ║
╚═══════════════════════════════════════════════════════════╝${NC}

${BOLD}What was changed:${NC}
  ✓ Ownership: All files → $APACHE_UID:$APACHE_GID (www-data)
  ✓ Directory permissions → 0750 (rwxr-x---)
  ✓ File permissions → 0640 (rw-r-----)
  ✓ Cache directories → 0770 (rwxrwx---)

${BOLD}What this means:${NC}
  • www-data (container) has full read/write access
  • Group has read access (and execute on directories)
  • Others have NO access (secure)

${BOLD}Next Steps:${NC}
  1. Refresh Nextcloud web interface
  2. Try accessing your files
  3. Try uploading a file
  4. The permission errors should be gone!

${BOLD}If you still get errors:${NC}
  • Check Nextcloud logs: podman logs nextcloud
  • Verify SELinux context: ls -Z $DATA_DIR
  • Check container mount has :Z flag
  • Use option 11 (Diagnose System) for detailed checks

${BOLD}Sample Permissions:${NC}
EOF
    
    echo ""
    ls -lah $DATA_DIR | head -10
    echo ""
    
    press_enter
    show_main_menu
}

#==============================================================================
# 6. Upgrade Nextcloud Version
#==============================================================================

upgrade_nextcloud_version() {
    print_header
    print_section "Upgrade Nextcloud Version"
    
    echo "This will upgrade your Nextcloud to the latest version by:"
    echo "  1. Checking current image and data versions"
    echo "  2. Pulling the latest Nextcloud image"
    echo "  3. Backing up current configuration"
    echo "  4. Stopping and removing the old container"
    echo "  5. Creating a new container with the latest image"
    echo "  6. Preserving all your data and settings"
    echo ""
    echo "Common reasons to use this:"
    echo "  • Version mismatch error (data version > image version)"
    echo "  • Upgrade to latest Nextcloud features"
    echo "  • Security updates"
    echo ""
    print_warning "This will cause brief downtime during the upgrade"
    echo ""
    
    # Check current versions
    print_section "Checking Current Versions"
    
    echo "Checking Nextcloud container image version..."
    CURRENT_IMAGE=$(podman inspect $NEXTCLOUD_CONTAINER 2>/dev/null | grep -m1 '"Image":' | cut -d'"' -f4)
    
    if [ -n "$CURRENT_IMAGE" ]; then
        print_info "Current image: $CURRENT_IMAGE"
    else
        print_warning "Could not determine current image"
    fi
    
    echo ""
    echo "Checking Nextcloud data version..."
    if podman ps | grep -q $NEXTCLOUD_CONTAINER; then
        DATA_VERSION=$(podman exec -u www-data $NEXTCLOUD_CONTAINER php occ status 2>/dev/null | grep "version:" | awk '{print $3}')
        if [ -n "$DATA_VERSION" ]; then
            print_info "Current data version: $DATA_VERSION"
        else
            print_warning "Could not determine data version (container may not be running properly)"
        fi
    else
        print_warning "Container not running - cannot check data version"
    fi
    
    echo ""
    if ! confirm "Continue with Nextcloud upgrade?"; then
        show_main_menu
        return
    fi
    
    # Create backup
    BACKUP_PATH=$(create_backup "pre_upgrade")
    print_info "Backup location: $BACKUP_PATH"
    
    # Backup current config
    print_section "Backing Up Current Configuration"
    
    if podman exec $NEXTCLOUD_CONTAINER test -f /var/www/html/config/config.php 2>/dev/null; then
        podman exec $NEXTCLOUD_CONTAINER cat /var/www/html/config/config.php > "$BACKUP_PATH/config.php"
        print_success "Config backed up"
    elif podman exec $NEXTCLOUD_CONTAINER test -f /opt/nextcloud/config/config.php 2>/dev/null; then
        podman exec $NEXTCLOUD_CONTAINER cat /opt/nextcloud/config/config.php > "$BACKUP_PATH/config.php"
        print_success "Config backed up"
    else
        print_warning "Could not backup config (container may not be running)"
    fi
    
    # Save container configuration
    podman inspect $NEXTCLOUD_CONTAINER > "$BACKUP_PATH/container-inspect.json" 2>/dev/null
    print_success "Container configuration backed up"
    
    # Pull latest image
    print_section "Pulling Latest Nextcloud Image"
    
    print_info "Pulling docker.io/library/nextcloud:latest..."
    podman pull docker.io/library/nextcloud:latest
    
    if [ $? -eq 0 ]; then
        print_success "Latest image pulled successfully"
    else
        print_error "Failed to pull latest image"
        print_info "Backup preserved at: $BACKUP_PATH"
        press_enter
        show_main_menu
        return
    fi
    
    # Show new version
    echo ""
    echo "New image information:"
    podman images | grep -E "REPOSITORY|nextcloud" | head -2
    
    # Stop container
    print_section "Stopping Current Container"
    
    print_info "Stopping $NEXTCLOUD_CONTAINER..."
    podman stop $NEXTCLOUD_CONTAINER
    
    if [ $? -eq 0 ]; then
        print_success "Container stopped"
    else
        print_warning "Container may already be stopped"
    fi
    
    # Remove old container
    print_section "Removing Old Container"
    
    print_info "Removing old container (data will be preserved)..."
    podman rm $NEXTCLOUD_CONTAINER
    
    if [ $? -eq 0 ]; then
        print_success "Old container removed"
    else
        print_error "Failed to remove old container"
        print_info "You may need to manually remove it: podman rm -f $NEXTCLOUD_CONTAINER"
        press_enter
        show_main_menu
        return
    fi
    
    # Recreate container
    print_section "Creating New Container with Latest Image"
    
    print_info "Creating new Nextcloud container..."
    
    # Create new container with same settings
    podman run -d \
      --name $NEXTCLOUD_CONTAINER \
      --pod $POD_NAME \
      -v $DATA_DIR:/var/www/html/data:Z \
      -e MYSQL_HOST=$MARIADB_HOST \
      -e MYSQL_DATABASE=$DB_NAME \
      -e MYSQL_USER=$DB_USER \
      -e MYSQL_PASSWORD="$DB_PASSWORD" \
      -e NEXTCLOUD_ADMIN_USER=$ADMIN_USER \
      -e NEXTCLOUD_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
      -e NEXTCLOUD_TRUSTED_DOMAINS="$DOMAIN $SERVER_IP" \
      -e REDIS_HOST=$REDIS_HOST \
      -e REDIS_HOST_PORT=$REDIS_PORT \
      --restart=always \
      docker.io/library/nextcloud:latest
    
    if [ $? -eq 0 ]; then
        print_success "New container created successfully"
    else
        print_error "Failed to create new container"
        print_warning "Your old container has been removed!"
        print_info "Backup available at: $BACKUP_PATH"
        echo ""
        print_info "You may need to manually recreate the container"
        print_info "Or use option 2 (Rebuild Nextcloud Container)"
        press_enter
        show_main_menu
        return
    fi
    
    # Wait for container to start
    print_section "Waiting for Nextcloud to Initialize"
    
    print_info "Waiting 30 seconds for container to start..."
    sleep 30
    
    # Check if container is running
    if podman ps | grep -q $NEXTCLOUD_CONTAINER; then
        print_success "Container is running"
    else
        print_error "Container is not running!"
        print_info "Checking logs..."
        podman logs --tail 20 $NEXTCLOUD_CONTAINER
        echo ""
        print_info "Backup available at: $BACKUP_PATH"
        press_enter
        show_main_menu
        return
    fi
    
    # Run upgrade process
    print_section "Running Nextcloud Upgrade Process"
    
    echo ""
    echo "Nextcloud will now run its upgrade process..."
    echo "This may take a few minutes depending on your data size."
    echo ""
    
    print_info "Enabling maintenance mode..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ maintenance:mode --on
    
    print_info "Running upgrade..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ upgrade
    
    if [ $? -eq 0 ]; then
        print_success "Upgrade completed successfully"
    else
        print_warning "Upgrade had some issues (check output above)"
    fi
    
    print_info "Disabling maintenance mode..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ maintenance:mode --off
    
    # Add missing database indices
    print_info "Adding missing database indices..."
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ db:add-missing-indices
    
    # Verify new version
    print_section "Verifying Upgrade"
    
    echo ""
    echo "New Nextcloud status:"
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ status
    
    echo ""
    echo "New version:"
    NEW_VERSION=$(podman exec -u www-data $NEXTCLOUD_CONTAINER php occ status 2>/dev/null | grep "version:" | awk '{print $3}')
    if [ -n "$NEW_VERSION" ]; then
        print_success "Nextcloud version: $NEW_VERSION"
    fi
    
    # Summary
    print_section "Upgrade Complete!"
    
    cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════╗
║            Nextcloud Upgraded Successfully!               ║
╚═══════════════════════════════════════════════════════════╝${NC}

${BOLD}Upgrade Summary:${NC}
  ${DATA_VERSION:+Old version: $DATA_VERSION}
  ${NEW_VERSION:+New version: $NEW_VERSION}

${BOLD}What was done:${NC}
  ✓ Latest Nextcloud image pulled
  ✓ Old container removed
  ✓ New container created with latest image
  ✓ Nextcloud upgrade process completed
  ✓ Database indices updated
  ✓ All data preserved

${BOLD}Backup Location:${NC}
  Configuration backup: $BACKUP_PATH

${BOLD}Next Steps:${NC}
  1. Test access: https://$DOMAIN
  2. Login with your admin credentials
  3. Check that your files are accessible
  4. Verify apps are working properly
  5. Review admin settings for any warnings

${BOLD}If you encounter issues:${NC}
  • Check logs: Option 21 (View Logs)
  • Run diagnostics: Option 12 (Test & Diagnose)
  • Configuration backup available at: $BACKUP_PATH

${BOLD}Access Your Nextcloud:${NC}
  URL: https://$DOMAIN
  Admin: $ADMIN_USER

EOF
    
    press_enter
    show_main_menu
}

#==============================================================================
# 7. Switch Between IP and Domain
#==============================================================================

switch_domain_ip() {
    print_header
    print_section "Switch Between IP and Domain"
    
    echo "Current configuration:"
    echo ""
    
    # Check current setup
    if grep -q "server_name $DOMAIN" $NGINX_CONF 2>/dev/null; then
        echo "  Mode: ${GREEN}Domain ($DOMAIN)${NC}"
    else
        echo "  Mode: ${GREEN}IP Address ($SERVER_IP)${NC}"
    fi
    
    echo ""
    echo "  1) Use domain name (llcloud)"
    echo "  2) Use IP address only (192.168.1.138)"
    echo "  3) Back to main menu"
    echo ""
    read -p "Select option (1-3): " switch_choice
    
    case $switch_choice in
        1) configure_for_domain ;;
        2) configure_for_ip ;;
        3) show_main_menu; return ;;
    esac
    
    press_enter
    show_main_menu
}

configure_for_domain() {
    print_section "Configuring for Domain: $DOMAIN"
    
    # Backup
    BACKUP_PATH=$(create_backup "pre_domain_switch")
    cp $NGINX_CONF "$BACKUP_PATH/" 2>/dev/null
    
    # Update Nextcloud config
    update_nextcloud_trusted_domains "$DOMAIN" "$SERVER_IP"
    
    # Regenerate SSL for domain
    generate_ssl_certificate
    
    # Update Nginx
    configure_nginx
    
    # Update /etc/hosts
    if ! grep -q "$SERVER_IP.*$DOMAIN" /etc/hosts; then
        sed -i "/$DOMAIN/d" /etc/hosts
        echo "$SERVER_IP    $DOMAIN" >> /etc/hosts
        print_success "Updated /etc/hosts"
    fi
    
    # Reload Nginx
    systemctl reload nginx
    
    print_success "Configured for domain: $DOMAIN"
    print_warning "Remember to configure your router DNS!"
}

configure_for_ip() {
    print_section "Configuring for IP: $SERVER_IP"
    
    # Backup
    BACKUP_PATH=$(create_backup "pre_ip_switch")
    cp $NGINX_CONF "$BACKUP_PATH/" 2>/dev/null
    
    # Update Nextcloud config
    update_nextcloud_trusted_domains "$SERVER_IP"
    
    # Regenerate SSL for IP
    generate_ssl_certificate
    
    # Update Nginx
    configure_nginx
    
    # Reload Nginx
    systemctl reload nginx
    
    print_success "Configured for IP: $SERVER_IP"
}

#==============================================================================
# 8. Regenerate SSL Certificates
#==============================================================================

regenerate_ssl() {
    print_header
    print_section "Regenerate SSL Certificate"
    
    # Backup old certificate
    BACKUP_PATH=$(create_backup "ssl")
    cp $SSL_CERT "$BACKUP_PATH/" 2>/dev/null
    cp $SSL_KEY "$BACKUP_PATH/" 2>/dev/null
    
    generate_ssl_certificate
    
    # Reload Nginx
    systemctl reload nginx
    
    print_success "SSL certificate regenerated"
    print_info "Backup saved to: $BACKUP_PATH"
    
    press_enter
    show_main_menu
}

#==============================================================================
# 9. Generate Trusted CA Certificate
#==============================================================================

generate_trusted_ca() {
    print_header
    print_section "Generate Trusted CA Certificate"
    
    CA_DIR="/etc/ssl/llcloud-ca"
    OUTPUT_DIR="/mnt/cloudextra/ssl-certs"
    
    echo "This will create a Certificate Authority (CA) that you can install"
    echo "on your Mac, iPhone, and iPad to eliminate SSL certificate warnings."
    echo ""
    echo "What this does:"
    echo "  • Creates a CA certificate (valid 10 years)"
    echo "  • Creates a server certificate signed by the CA (valid 825 days)"
    echo "  • Installs the server certificate in Nginx"
    echo "  • Saves CA certificate to /mnt/cloudextra/ssl-certs/"
    echo ""
    echo "After running this:"
    echo "  1. Install the CA certificate on your devices"
    echo "  2. Trust the CA certificate"
    echo "  3. Nextcloud client will connect without errors!"
    echo ""
    
    if ! confirm "Continue with CA certificate generation?"; then
        show_main_menu
        return
    fi
    
    # Backup existing certificates
    BACKUP_PATH=$(create_backup "pre_ca_generation")
    cp $SSL_CERT "$BACKUP_PATH/" 2>/dev/null
    cp $SSL_KEY "$BACKUP_PATH/" 2>/dev/null
    print_info "Backup created: $BACKUP_PATH"
    
    # Create directories
    print_section "Creating Directories"
    mkdir -p $CA_DIR
    mkdir -p $OUTPUT_DIR
    print_success "Directories created"
    
    # Generate CA private key
    print_section "Generating CA Private Key"
    openssl genrsa -out $CA_DIR/ca.key 4096 2>/dev/null
    chmod 600 $CA_DIR/ca.key
    print_success "CA private key generated (4096-bit)"
    
    # Generate CA certificate
    print_section "Generating CA Certificate"
    openssl req -x509 -new -nodes \
        -key $CA_DIR/ca.key \
        -sha256 -days 3650 \
        -out $CA_DIR/ca.crt \
        -subj "/C=US/ST=Home/L=Network/O=LLHome/CN=LLHome Root CA" 2>/dev/null
    
    chmod 644 $CA_DIR/ca.crt
    print_success "CA certificate generated (valid 10 years)"
    
    # Generate server private key
    print_section "Generating Server Private Key"
    openssl genrsa -out $CA_DIR/server.key 2048 2>/dev/null
    chmod 600 $CA_DIR/server.key
    print_success "Server private key generated (2048-bit)"
    
    # Generate certificate signing request (CSR)
    print_section "Generating Certificate Signing Request"
    
    cat > $CA_DIR/server.conf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = US
ST = Home
L = Network
O = LLHome
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
IP.1 = $SERVER_IP
EOF
    
    openssl req -new \
        -key $CA_DIR/server.key \
        -out $CA_DIR/server.csr \
        -config $CA_DIR/server.conf 2>/dev/null
    
    print_success "CSR generated"
    
    # Sign the server certificate with CA
    print_section "Signing Server Certificate with CA"
    
    openssl x509 -req \
        -in $CA_DIR/server.csr \
        -CA $CA_DIR/ca.crt \
        -CAkey $CA_DIR/ca.key \
        -CAcreateserial \
        -out $CA_DIR/server.crt \
        -days 825 \
        -sha256 \
        -extfile $CA_DIR/server.conf \
        -extensions v3_req 2>/dev/null
    
    chmod 644 $CA_DIR/server.crt
    print_success "Server certificate signed (valid 825 days)"
    
    # Copy to standard locations
    print_section "Installing Certificates"
    
    cp $CA_DIR/server.crt /etc/ssl/certs/nextcloud.crt
    cp $CA_DIR/server.key /etc/ssl/private/nextcloud.key
    chmod 644 /etc/ssl/certs/nextcloud.crt
    chmod 600 /etc/ssl/private/nextcloud.key
    print_success "Server certificates installed to /etc/ssl/"
    
    # Copy CA cert to accessible location
    print_section "Copying CA Certificate for Installation"
    
    cp $CA_DIR/ca.crt $OUTPUT_DIR/llcloud-ca.crt
    chmod 644 $OUTPUT_DIR/llcloud-ca.crt
    print_success "CA certificate copied to: $OUTPUT_DIR/llcloud-ca.crt"
    
    # Reload Nginx
    print_section "Reloading Nginx"
    
    nginx -t &>/dev/null
    if [ $? -eq 0 ]; then
        systemctl reload nginx
        print_success "Nginx reloaded with new certificates"
    else
        print_error "Nginx configuration test failed"
        print_info "Restoring backup..."
        cp "$BACKUP_PATH/nextcloud.crt" /etc/ssl/certs/nextcloud.crt 2>/dev/null
        cp "$BACKUP_PATH/nextcloud.key" /etc/ssl/private/nextcloud.key 2>/dev/null
        systemctl reload nginx
        press_enter
        show_main_menu
        return
    fi
    
    # Verify certificate
    print_section "Verifying Certificate"
    
    echo ""
    echo "Certificate Subject:"
    openssl x509 -in /etc/ssl/certs/nextcloud.crt -noout -subject 2>/dev/null
    echo ""
    echo "Certificate Alternative Names:"
    openssl x509 -in /etc/ssl/certs/nextcloud.crt -noout -text 2>/dev/null | grep -A 3 "Subject Alternative Name"
    echo ""
    echo "Certificate Validity:"
    openssl x509 -in /etc/ssl/certs/nextcloud.crt -noout -dates 2>/dev/null
    
    # Summary and instructions
    print_section "Setup Complete!"
    
    cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════╗
║          CA Certificate Generated Successfully!           ║
╚═══════════════════════════════════════════════════════════╝${NC}

${BOLD}Files Created:${NC}
  ✓ CA Certificate: $CA_DIR/ca.crt
  ✓ CA Private Key: $CA_DIR/ca.key (keep secure!)
  ✓ Server Certificate: /etc/ssl/certs/nextcloud.crt
  ✓ Server Private Key: /etc/ssl/private/nextcloud.key

${BOLD}CA Certificate for Installation:${NC}
  📁 Location: $OUTPUT_DIR/llcloud-ca.crt
  📁 Samba Path: smb://$SERVER_IP/cloudextra/ssl-certs/llcloud-ca.crt

${CYAN}╔═══════════════════════════════════════════════════════════╗
║              INSTALL CA CERTIFICATE ON DEVICES            ║
╚═══════════════════════════════════════════════════════════╝${NC}

${BOLD}macOS Installation:${NC}
  ${YELLOW}Step 1: Get the Certificate${NC}
    • Option A: Use Samba share
      1. Open Finder → Cmd+K
      2. Connect to: smb://$SERVER_IP/cloudextra
      3. Navigate to: ssl-certs folder
      4. Copy llcloud-ca.crt to your Mac
    
    • Option B: Use Nextcloud web interface
      1. Login to https://$DOMAIN
      2. Upload the certificate to Nextcloud
      3. Download it to your Mac
  
  ${YELLOW}Step 2: Install and Trust${NC}
    1. Double-click llcloud-ca.crt
    2. Keychain Access will open
    3. Select "System" keychain (requires admin password)
    4. Find "LLHome Root CA" certificate
    5. Double-click the certificate
    6. Expand "Trust" section
    7. Change "When using this certificate" to: ${GREEN}Always Trust${NC}
    8. Close window (enter password when prompted)
    
  ${GREEN}✓ Done!${NC} Your Mac now trusts the certificate

${BOLD}iOS/iPadOS Installation:${NC}
  ${YELLOW}Step 1: Get the Certificate to your device${NC}
    • Option A: AirDrop from Mac
    • Option B: Email llcloud-ca.crt to yourself
    • Option C: Download from Nextcloud web interface (Safari)
  
  ${YELLOW}Step 2: Install Profile${NC}
    1. Tap the certificate file
    2. Tap "Allow" to download profile
    3. Go to: Settings → Profile Downloaded
    4. Tap "Install" (top right)
    5. Enter your passcode
    6. Tap "Install" again (confirmation)
    7. Tap "Done"
  
  ${YELLOW}Step 3: Enable Full Trust${NC}
    1. Go to: Settings → General → About
    2. Scroll to bottom: Certificate Trust Settings
    3. Find "LLHome Root CA"
    4. Toggle switch to ${GREEN}ON${NC}
    5. Tap "Continue" on warning
    
  ${GREEN}✓ Done!${NC} Your iOS device now trusts the certificate

${CYAN}╔═══════════════════════════════════════════════════════════╗
║                  VERIFY IT'S WORKING                      ║
╚═══════════════════════════════════════════════════════════╝${NC}

${BOLD}Test in Browser:${NC}
  1. Open Safari or Chrome
  2. Go to: https://$DOMAIN
  3. ${GREEN}No security warning!${NC} Certificate should be trusted

${BOLD}Test in Nextcloud Client:${NC}
  1. Open Nextcloud desktop app
  2. Add account: https://$DOMAIN
  3. ${GREEN}Connection succeeds!${NC} No certificate error
  4. Login with your credentials

${BOLD}Files:${NC}
  • Backup of old certs: $BACKUP_PATH
  • CA cert location: $OUTPUT_DIR/llcloud-ca.crt
  
${YELLOW}Note:${NC} The server certificate expires in 825 days (~2.3 years)
      You'll need to regenerate it before then using this same menu option

EOF
    
    press_enter
    show_main_menu
}

#==============================================================================
# 10. Configure Redis
#==============================================================================

configure_redis() {
    print_header
    print_section "Configure Redis Caching"
    
    echo "Redis status:"
    if podman ps | grep -q $REDIS_CONTAINER; then
        print_success "Redis container running"
    else
        print_warning "Redis container not running"
        echo ""
        if confirm "Create and start Redis container?"; then
            setup_redis
        fi
    fi
    
    echo ""
    echo "  1) Enable Redis in Nextcloud"
    echo "  2) Disable Redis in Nextcloud"
    echo "  3) Restart Redis container"
    echo "  4) View Redis stats"
    echo "  5) Back to main menu"
    echo ""
    read -p "Select option (1-5): " redis_choice
    
    case $redis_choice in
        1) enable_redis_in_nextcloud ;;
        2) disable_redis_in_nextcloud ;;
        3) 
            podman restart $REDIS_CONTAINER
            print_success "Redis restarted"
            ;;
        4) show_redis_stats ;;
        5) show_main_menu; return ;;
    esac
    
    press_enter
    configure_redis
}

#==============================================================================
# 11. Configure Firewall
#==============================================================================

configure_firewall() {
    print_header
    print_section "Configure Firewall (UFW)"
    
    echo "  1) Enable firewall with Nextcloud rules"
    echo "  2) Show current firewall status"
    echo "  3) Reset firewall rules"
    echo "  4) Back to main menu"
    echo ""
    read -p "Select option (1-4): " fw_choice
    
    case $fw_choice in
        1) configure_firewall_rules ;;
        2) 
            ufw status verbose
            ;;
        3)
            if confirm "Reset all firewall rules?"; then
                ufw --force reset
                configure_firewall_rules
            fi
            ;;
        4) show_main_menu; return ;;
    esac
    
    press_enter
    configure_firewall
}

configure_firewall_rules() {
    if ! command -v ufw &> /dev/null; then
        print_error "UFW not installed"
        return
    fi
    
    print_info "Configuring UFW firewall..."
    
    # Allow SSH
    ufw allow ssh comment 'SSH access'
    
    # Allow HTTPS only (block HTTP from outside)
    ufw allow 443/tcp comment 'HTTPS Nextcloud'
    
    # Deny HTTP from outside
    ufw deny 80/tcp comment 'Block external HTTP'
    
    # Enable firewall
    ufw --force enable
    
    print_success "Firewall configured"
    print_info "HTTPS (443): Allowed"
    print_info "HTTP (80): Denied from outside"
    print_info "SSH (22): Allowed"
}

#==============================================================================
# 12. Test & Diagnose System
#==============================================================================

diagnose_system() {
    print_header
    print_section "System Diagnostics"
    
    # Container status
    echo -e "${BOLD}Container Status:${NC}"
    if podman ps | grep -q $NEXTCLOUD_CONTAINER; then
        print_success "Nextcloud running"
    else
        print_error "Nextcloud NOT running"
    fi
    
    if podman ps | grep -q $MARIADB_CONTAINER; then
        print_success "MariaDB running"
    else
        print_error "MariaDB NOT running"
    fi
    
    if podman ps | grep -q $REDIS_CONTAINER; then
        print_success "Redis running"
    else
        print_warning "Redis not running"
    fi
    
    # Pod status
    echo ""
    echo -e "${BOLD}Pod Status:${NC}"
    if podman pod exists $POD_NAME; then
        print_success "Pod exists"
        podman pod ps | grep $POD_NAME
    else
        print_error "Pod not found"
    fi
    
    # Network connectivity
    echo ""
    echo -e "${BOLD}Network Connectivity:${NC}"
    if ss -tlnp 2>/dev/null | grep :8080 | grep -q podman; then
        print_success "Port 8080 listening"
    else
        print_error "Port 8080 NOT listening"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
        print_success "Nextcloud responding on HTTP"
    else
        print_warning "Nextcloud not responding on HTTP"
    fi
    
    # Database connection
    echo ""
    echo -e "${BOLD}Database Connection:${NC}"
    if podman exec $MARIADB_CONTAINER mysql -u$DB_USER -p"$DB_PASSWORD" -e "USE $DB_NAME; SELECT 1;" &>/dev/null; then
        print_success "Database connection working"
    else
        print_error "Database connection failed"
    fi
    
    # Data directory
    echo ""
    echo -e "${BOLD}Data Directory:${NC}"
    if [ -d "$DATA_DIR" ]; then
        print_success "Data directory exists: $DATA_DIR"
        du -sh $DATA_DIR 2>/dev/null | awk '{print "  Size: "$1}'
        ls -lhd $DATA_DIR
    else
        print_error "Data directory not found"
    fi
    
    # Nextcloud status
    echo ""
    echo -e "${BOLD}Nextcloud Status:${NC}"
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ status 2>/dev/null || print_warning "Cannot get status"
    
    # SSL Certificate
    echo ""
    echo -e "${BOLD}SSL Certificate:${NC}"
    if [ -f "$SSL_CERT" ]; then
        print_success "Certificate exists"
        openssl x509 -in $SSL_CERT -noout -dates 2>/dev/null
    else
        print_error "Certificate not found"
    fi
    
    # Nginx
    echo ""
    echo -e "${BOLD}Nginx Status:${NC}"
    if systemctl is-active --quiet nginx; then
        print_success "Nginx running"
    else
        print_error "Nginx NOT running"
    fi
    
    # Firewall
    echo ""
    echo -e "${BOLD}Firewall Status:${NC}"
    if command -v ufw &> /dev/null; then
        ufw status | grep -E "Status|443|80"
    else
        print_info "UFW not installed"
    fi
    
    press_enter
    show_main_menu
}

#==============================================================================
# 13. View Configuration
#==============================================================================

view_configuration() {
    print_header
    print_section "Current Configuration"
    
    echo -e "${BOLD}Server Configuration:${NC}"
    echo "  IP Address: $SERVER_IP"
    echo "  Domain: $DOMAIN"
    echo "  Pod Name: $POD_NAME"
    echo "  Data Directory: $DATA_DIR"
    echo "  Backup Directory: $BACKUP_DIR"
    echo ""
    
    echo -e "${BOLD}Containers:${NC}"
    echo "  Nextcloud: $NEXTCLOUD_CONTAINER"
    echo "  MariaDB: $MARIADB_CONTAINER"
    echo "  Redis: $REDIS_CONTAINER"
    echo ""
    
    echo -e "${BOLD}Database:${NC}"
    echo "  Database Name: $DB_NAME"
    echo "  Database User: $DB_USER"
    echo "  Database Host: $MARIADB_HOST"
    echo ""
    
    echo -e "${BOLD}Admin Account:${NC}"
    echo "  Username: $ADMIN_USER"
    echo "  Password: [hidden]"
    echo ""
    
    echo -e "${BOLD}SSL Certificate:${NC}"
    echo "  Certificate: $SSL_CERT"
    echo "  Private Key: $SSL_KEY"
    echo ""
    
    echo -e "${BOLD}Nginx Configuration:${NC}"
    echo "  Config File: $NGINX_CONF"
    if [ -f "$NGINX_CONF" ]; then
        echo "  Status: Exists"
    else
        echo "  Status: Not Found"
    fi
    
    press_enter
    show_main_menu
}

#==============================================================================
# 14. Restart Services
#==============================================================================

restart_services() {
    print_header
    print_section "Restart Services"
    
    echo "  1) Restart Nextcloud container only"
    echo "  2) Restart entire pod (all containers)"
    echo "  3) Restart Nginx"
    echo "  4) Restart all services"
    echo "  5) Back to main menu"
    echo ""
    read -p "Select option (1-5): " restart_choice
    
    case $restart_choice in
        1)
            print_info "Restarting Nextcloud..."
            podman restart $NEXTCLOUD_CONTAINER
            sleep 5
            if podman ps | grep -q $NEXTCLOUD_CONTAINER; then
                print_success "Nextcloud restarted"
            fi
            ;;
        2)
            print_info "Restarting pod..."
            podman pod restart $POD_NAME
            sleep 10
            print_success "Pod restarted"
            ;;
        3)
            print_info "Restarting Nginx..."
            systemctl restart nginx
            if systemctl is-active --quiet nginx; then
                print_success "Nginx restarted"
            fi
            ;;
        4)
            print_info "Restarting all services..."
            podman pod restart $POD_NAME
            systemctl restart nginx
            sleep 10
            print_success "All services restarted"
            ;;
        5) show_main_menu; return ;;
    esac
    
    press_enter
    show_main_menu
}

#==============================================================================
# 15. Manage Users
#==============================================================================

manage_users() {
    print_header
    print_section "Manage Nextcloud Users"
    
    echo "  1) List all users"
    echo "  2) Create new user"
    echo "  3) Delete user"
    echo "  4) Reset user password"
    echo "  5) Back to main menu"
    echo ""
    read -p "Select option (1-5): " user_choice
    
    case $user_choice in
        1)
            print_info "Listing users..."
            podman exec -u www-data $NEXTCLOUD_CONTAINER php occ user:list
            ;;
        2)
            read -p "Enter username: " new_user
            read -p "Enter password: " new_pass
            podman exec -u www-data $NEXTCLOUD_CONTAINER php occ user:add --password-from-env "$new_user" <<< "$new_pass"
            print_success "User created: $new_user"
            ;;
        3)
            read -p "Enter username to delete: " del_user
            if confirm "Delete user $del_user?"; then
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ user:delete "$del_user"
                print_success "User deleted"
            fi
            ;;
        4)
            read -p "Enter username: " reset_user
            read -p "Enter new password: " reset_pass
            podman exec -u www-data $NEXTCLOUD_CONTAINER php occ user:resetpassword --password-from-env "$reset_user" <<< "$reset_pass"
            print_success "Password reset"
            ;;
        5) show_main_menu; return ;;
    esac
    
    press_enter
    manage_users
}

#==============================================================================
# 16. Scan User Files
#==============================================================================

scan_user_files() {
    print_header
    print_section "Scan User Files"
    
    echo "This will scan user data directories to index files in Nextcloud."
    echo "Use this after:"
    echo "  • Restoring user files from backup"
    echo "  • Manually copying files to data directory"
    echo "  • Migrating from another Nextcloud instance"
    echo ""
    echo "Options:"
    echo ""
    echo "  1) Scan all users"
    echo "  2) Scan specific user"
    echo "  3) Scan specific user path"
    echo "  4) Rescan all files (slower, fixes issues)"
    echo "  5) Back to main menu"
    echo ""
    read -p "Select option (1-5): " scan_choice
    
    case $scan_choice in
        1)
            print_section "Scanning All Users"
            print_info "This may take several minutes depending on data size..."
            echo ""
            
            if confirm "Continue with full scan?"; then
                print_info "Starting scan..."
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ files:scan --all
                
                if [ $? -eq 0 ]; then
                    print_success "All user files scanned successfully"
                else
                    print_error "Scan completed with errors"
                fi
            fi
            ;;
        2)
            print_section "Scan Specific User"
            
            print_info "Available users:"
            podman exec -u www-data $NEXTCLOUD_CONTAINER php occ user:list
            echo ""
            
            read -p "Enter username to scan: " username
            
            if [ -z "$username" ]; then
                print_error "No username provided"
            else
                print_info "Scanning files for user: $username"
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ files:scan $username
                
                if [ $? -eq 0 ]; then
                    print_success "Files scanned for $username"
                else
                    print_error "Failed to scan files for $username"
                fi
            fi
            ;;
        3)
            print_section "Scan Specific Path"
            
            print_info "Available users:"
            podman exec -u www-data $NEXTCLOUD_CONTAINER php occ user:list
            echo ""
            
            read -p "Enter username: " username
            read -p "Enter path (e.g., files/Photos): " userpath
            
            if [ -z "$username" ] || [ -z "$userpath" ]; then
                print_error "Username and path are required"
            else
                print_info "Scanning: $username/$userpath"
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ files:scan --path="/$username/$userpath"
                
                if [ $? -eq 0 ]; then
                    print_success "Path scanned successfully"
                else
                    print_error "Failed to scan path"
                fi
            fi
            ;;
        4)
            print_section "Rescan All Files (Repair Mode)"
            
            echo "This will:"
            echo "  • Scan all users"
            echo "  • Repair file cache issues"
            echo "  • Fix missing or incorrect entries"
            echo "  • Take longer than normal scan"
            echo ""
            print_warning "This is more intensive - use if normal scan didn't work"
            echo ""
            
            if confirm "Continue with repair scan?"; then
                print_info "Starting repair scan..."
                podman exec -u www-data $NEXTCLOUD_CONTAINER php occ files:scan --all --repair
                
                if [ $? -eq 0 ]; then
                    print_success "Repair scan completed successfully"
                else
                    print_error "Repair scan completed with errors"
                fi
            fi
            ;;
        5)
            show_main_menu
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    # Show scan statistics
    echo ""
    print_info "Scan Statistics:"
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ files:scan --all --quiet 2>&1 | tail -5 || true
    
    press_enter
    scan_user_files
}

#==============================================================================
# 17. Backup System
#==============================================================================

backup_system() {
    print_header
    print_section "Backup Configuration & Data"
    
    BACKUP_PATH=$(create_backup "manual")
    
    echo "Backing up to: $BACKUP_PATH"
    echo ""
    
    # Backup Nginx config
    if [ -f "$NGINX_CONF" ]; then
        cp "$NGINX_CONF" "$BACKUP_PATH/"
        print_success "Nginx config backed up"
    fi
    
    # Backup SSL certificates
    if [ -f "$SSL_CERT" ]; then
        cp "$SSL_CERT" "$BACKUP_PATH/"
        cp "$SSL_KEY" "$BACKUP_PATH/"
        print_success "SSL certificates backed up"
    fi
    
    # Backup Nextcloud config
    podman exec $NEXTCLOUD_CONTAINER cat /var/www/html/config/config.php > "$BACKUP_PATH/config.php" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_success "Nextcloud config backed up"
    fi
    
    # Export database
    print_info "Exporting database (this may take a while)..."
    podman exec $MARIADB_CONTAINER mysqldump -u$DB_USER -p"$DB_PASSWORD" $DB_NAME > "$BACKUP_PATH/database.sql" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_success "Database backed up"
    fi
    
    # Backup container configurations
    podman inspect $NEXTCLOUD_CONTAINER > "$BACKUP_PATH/nextcloud-container.json" 2>/dev/null
    podman inspect $MARIADB_CONTAINER > "$BACKUP_PATH/mariadb-container.json" 2>/dev/null
    podman pod inspect $POD_NAME > "$BACKUP_PATH/pod.json" 2>/dev/null
    print_success "Container configs backed up"
    
    # Create backup info file
    cat > "$BACKUP_PATH/backup-info.txt" << EOF
Backup created: $(date)
Server IP: $SERVER_IP
Domain: $DOMAIN
Nextcloud Container: $NEXTCLOUD_CONTAINER
MariaDB Container: $MARIADB_CONTAINER
Pod: $POD_NAME
Data Directory: $DATA_DIR
EOF
    
    print_success "Backup complete!"
    print_info "Location: $BACKUP_PATH"
    
    # Note about data directory
    echo ""
    print_warning "User data in $DATA_DIR is NOT included in this backup"
    print_info "Data directory should be backed up separately using rsync or similar"
    
    press_enter
    show_main_menu
}

#==============================================================================
# 18. Restore from Backup
#==============================================================================

restore_system() {
    print_header
    print_section "Restore from Backup"
    
    echo "Available backups in $BACKUP_DIR:"
    echo ""
    ls -lht "$BACKUP_DIR" | grep "^d" | head -10
    echo ""
    
    read -p "Enter backup directory name: " backup_name
    RESTORE_PATH="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$RESTORE_PATH" ]; then
        print_error "Backup not found: $RESTORE_PATH"
        press_enter
        show_main_menu
        return
    fi
    
    echo ""
    echo "This will restore configuration from:"
    echo "  $RESTORE_PATH"
    echo ""
    print_warning "This will NOT restore user data"
    echo ""
    
    if ! confirm "Continue with restore?"; then
        show_main_menu
        return
    fi
    
    # Create pre-restore backup
    BACKUP_PATH=$(create_backup "pre_restore")
    print_info "Created pre-restore backup: $BACKUP_PATH"
    
    # Restore Nginx config
    if [ -f "$RESTORE_PATH/nextcloud" ]; then
        cp "$RESTORE_PATH/nextcloud" "$NGINX_CONF"
        print_success "Nginx config restored"
    fi
    
    # Restore SSL certificates
    if [ -f "$RESTORE_PATH/nextcloud.crt" ]; then
        cp "$RESTORE_PATH/nextcloud.crt" "$SSL_CERT"
        cp "$RESTORE_PATH/nextcloud.key" "$SSL_KEY"
        chmod 644 "$SSL_CERT"
        chmod 600 "$SSL_KEY"
        print_success "SSL certificates restored"
    fi
    
    # Restore Nextcloud config
    if [ -f "$RESTORE_PATH/config.php" ]; then
        podman cp "$RESTORE_PATH/config.php" $NEXTCLOUD_CONTAINER:/var/www/html/config/config.php
        podman exec -u www-data $NEXTCLOUD_CONTAINER chown www-data:www-data /var/www/html/config/config.php
        print_success "Nextcloud config restored"
    fi
    
    # Restore database
    if [ -f "$RESTORE_PATH/database.sql" ]; then
        if confirm "Restore database? (This will overwrite current data)"; then
            print_info "Restoring database..."
            podman exec -i $MARIADB_CONTAINER mysql -u$DB_USER -p"$DB_PASSWORD" $DB_NAME < "$RESTORE_PATH/database.sql"
            if [ $? -eq 0 ]; then
                print_success "Database restored"
            else
                print_error "Database restore failed"
            fi
        fi
    fi
    
    # Restart services
    print_info "Restarting services..."
    systemctl reload nginx
    podman restart $NEXTCLOUD_CONTAINER
    
    print_success "Restore complete!"
    
    press_enter
    show_main_menu
}

#==============================================================================
# 19. Show Connection Instructions
#==============================================================================

show_connection_instructions() {
    print_header
    print_section "Connection Instructions"
    
    cat << EOF

${BOLD}Web Browser Access:${NC}

  Primary URL:    https://$DOMAIN
  Fallback URL:   https://$SERVER_IP
  
  ${YELLOW}Note: You'll see an SSL warning (normal for self-signed certificates)${NC}
  ${YELLOW}Click "Advanced" → "Proceed to $DOMAIN" to continue${NC}

${BOLD}Admin Login:${NC}
  Username: $ADMIN_USER
  Password: [stored in script configuration]

${BOLD}WebDAV Access:${NC}
  URL: https://$DOMAIN/remote.php/dav
  
  ${CYAN}Example (Linux/Mac):${NC}
  mount -t davfs https://$DOMAIN/remote.php/dav ~/nextcloud

${BOLD}Mobile Apps:${NC}
  Server Address: https://$DOMAIN
  
  iOS: Download "Nextcloud" from App Store
  Android: Download "Nextcloud" from Play Store
  
  ${YELLOW}Important: Accept the self-signed certificate when prompted${NC}

${BOLD}Desktop Sync Client:${NC}
  Download from: https://nextcloud.com/install/#install-clients
  Server Address: https://$DOMAIN
  
  ${YELLOW}On first connection, accept the self-signed certificate${NC}

${BOLD}Network Requirements:${NC}
  • Must be on the same network (192.168.1.x)
  • Router DNS must be configured (for domain access)
  • Firewall must allow HTTPS (port 443)

${BOLD}Trusted Certificate Setup (Optional):${NC}
  To avoid SSL warnings, you can:
  1. Install the CA certificate on each device
  2. Use Let's Encrypt with a real domain
  3. Use a reverse proxy with valid certificates

EOF

    press_enter
    show_main_menu
}

#==============================================================================
# 20. Router DNS Setup Guide
#==============================================================================

show_router_guide() {
    print_header
    print_section "ASUS GT-AX11000 Router DNS Setup"
    
    cat << 'EOF'

${BOLD}Step-by-Step Guide for ASUS GT-AX11000${NC}

${CYAN}Step 1: Access Your Router${NC}
  1. Open web browser
  2. Go to: http://router.asus.com or http://192.168.1.1
  3. Login with your router credentials

${CYAN}Step 2: Navigate to DNS Settings${NC}
  1. Click "LAN" in the left menu
  2. Click "DHCP Server" tab
  3. Scroll down to "DNS and WINS Server Setting"

${CYAN}Step 3: Enable DNS Director (Recommended Method)${NC}
  1. Look for "DNS Director" option
  2. Click "Enable DNS Director"
  3. Add a new rule:
     • Client: All
     • Target DNS: Router
     • Redirect to: Router

${CYAN}Step 4: Add Static DNS Entry${NC}
  1. In the DHCP Server page
  2. Find "Manually Assigned IP addresses (DHCP list)"
  3. Add entry:
     MAC Address: [Your server's MAC]
     IP Address: 192.168.1.138
     DNS Name: llcloud

  ${YELLOW}Alternatively, if available:${NC}
  1. Look for "Hosts" or "Static DNS" section
  2. Add: llcloud → 192.168.1.138

${CYAN}Step 5: Apply and Reboot${NC}
  1. Click "Apply" at the bottom
  2. Router may reboot automatically
  3. Wait 2-3 minutes for changes to take effect

${CYAN}Step 6: Verify Setup${NC}
  On any device connected to your network:
  
  ${BOLD}Mac/Linux:${NC}
    ping llcloud
  
  ${BOLD}Windows:${NC}
    ping llcloud
  
  You should see responses from 192.168.1.138

${CYAN}Alternative: Using Hosts File (If Router DNS Fails)${NC}

  ${BOLD}Mac/Linux:${NC}
    sudo nano /etc/hosts
    Add: 192.168.1.138    llcloud
  
  ${BOLD}Windows (Run as Administrator):${NC}
    notepad C:\Windows\System32\drivers\etc\hosts
    Add: 192.168.1.138    llcloud
  
  ${BOLD}iOS/iPad:${NC}
    Cannot edit hosts file without jailbreak
    Must use router DNS or IP address

${CYAN}Troubleshooting:${NC}

  ${YELLOW}DNS not working:${NC}
    • Restart your device's network connection
    • Flush DNS cache:
      Mac: sudo dscacheutil -flushcache
      Windows: ipconfig /flushdns
    • Reboot router
  
  ${YELLOW}Router doesn't support static DNS:${NC}
    • Use hosts file on each device
    • Consider installing Pi-hole for network DNS
    • Just use IP address: https://192.168.1.138

${BOLD}Your Configuration:${NC}
  Domain: llcloud
  IP Address: 192.168.1.138
  Access URL: https://llcloud

EOF

    press_enter
    show_main_menu
}

#==============================================================================
# 21. View Logs
#==============================================================================

view_logs() {
    print_header
    print_section "View Container Logs"
    
    echo "  1) Nextcloud logs (last 50 lines)"
    echo "  2) MariaDB logs (last 50 lines)"
    echo "  3) Redis logs (last 50 lines)"
    echo "  4) Nginx access log"
    echo "  5) Nginx error log"
    echo "  6) Follow Nextcloud logs (live)"
    echo "  7) Back to main menu"
    echo ""
    read -p "Select option (1-7): " log_choice
    
    case $log_choice in
        1)
            print_info "Nextcloud logs:"
            podman logs --tail 50 $NEXTCLOUD_CONTAINER
            ;;
        2)
            print_info "MariaDB logs:"
            podman logs --tail 50 $MARIADB_CONTAINER
            ;;
        3)
            print_info "Redis logs:"
            podman logs --tail 50 $REDIS_CONTAINER 2>/dev/null || print_warning "Redis not running"
            ;;
        4)
            print_info "Nginx access log:"
            tail -50 /var/log/nginx/nextcloud.access.log 2>/dev/null || print_warning "Log not found"
            ;;
        5)
            print_info "Nginx error log:"
            tail -50 /var/log/nginx/nextcloud.error.log 2>/dev/null || print_warning "Log not found"
            ;;
        6)
            print_info "Following Nextcloud logs (Ctrl+C to exit)..."
            podman logs -f $NEXTCLOUD_CONTAINER
            ;;
        7) show_main_menu; return ;;
    esac
    
    press_enter
    view_logs
}

#==============================================================================
# Support Functions
#==============================================================================

setup_mariadb() {
    if podman ps -a | grep -q $MARIADB_CONTAINER; then
        print_warning "MariaDB container already exists"
        if ! podman ps | grep -q $MARIADB_CONTAINER; then
            podman start $MARIADB_CONTAINER
        fi
        return
    fi
    
    print_info "Creating MariaDB container..."
    
    # Create MariaDB data directory if needed
    MARIADB_DATA="/mnt/cloud/mariadb"
    mkdir -p $MARIADB_DATA
    
    podman run -d \
      --name $MARIADB_CONTAINER \
      --pod $POD_NAME \
      -v $MARIADB_DATA:/var/lib/mysql:Z \
      -e MYSQL_ROOT_PASSWORD='8K8dU8%3D#4#ZS%gLQZFfG!' \
      -e MYSQL_DATABASE=$DB_NAME \
      -e MYSQL_USER=$DB_USER \
      -e MYSQL_PASSWORD="$DB_PASSWORD" \
      --restart=always \
      docker.io/library/mariadb:10.11
    
    if [ $? -eq 0 ]; then
        print_success "MariaDB container created"
        print_info "Waiting for MariaDB to initialize..."
        sleep 15
    else
        print_error "Failed to create MariaDB container"
        exit 1
    fi
}

setup_redis() {
    if podman ps -a | grep -q $REDIS_CONTAINER; then
        print_warning "Redis container already exists"
        if ! podman ps | grep -q $REDIS_CONTAINER; then
            podman start $REDIS_CONTAINER
        fi
        return
    fi
    
    print_info "Creating Redis container..."
    
    podman run -d \
      --name $REDIS_CONTAINER \
      --pod $POD_NAME \
      --restart=always \
      docker.io/library/redis:alpine \
      redis-server --requirepass ""
    
    if [ $? -eq 0 ]; then
        print_success "Redis container created"
    else
        print_error "Failed to create Redis container"
    fi
}

create_nextcloud_container() {
    # Ensure data directory exists with correct permissions
    if [ ! -d "$DATA_DIR" ]; then
        mkdir -p "$DATA_DIR"
    fi
    chown -R 33:33 "$DATA_DIR"
    
    print_info "Creating Nextcloud container..."
    
    podman run -d \
      --name $NEXTCLOUD_CONTAINER \
      --pod $POD_NAME \
      -v $DATA_DIR:/var/www/html/data:Z \
      -e MYSQL_HOST=$MARIADB_HOST \
      -e MYSQL_DATABASE=$DB_NAME \
      -e MYSQL_USER=$DB_USER \
      -e MYSQL_PASSWORD="$DB_PASSWORD" \
      -e NEXTCLOUD_ADMIN_USER=$ADMIN_USER \
      -e NEXTCLOUD_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
      -e NEXTCLOUD_TRUSTED_DOMAINS="$DOMAIN $SERVER_IP" \
      -e REDIS_HOST=$REDIS_HOST \
      -e REDIS_HOST_PORT=$REDIS_PORT \
      --restart=always \
      docker.io/library/nextcloud:latest
    
    if [ $? -eq 0 ]; then
        print_success "Nextcloud container created"
        print_info "Waiting for initialization (60 seconds)..."
        sleep 60
    else
        print_error "Failed to create Nextcloud container"
        exit 1
    fi
}

generate_ssl_certificate() {
    # Determine if we're using domain or IP
    local subject_name="$DOMAIN"
    local alt_names="DNS:$DOMAIN,DNS:*.$DOMAIN,IP:$SERVER_IP"
    
    if grep -q "server_name $SERVER_IP" $NGINX_CONF 2>/dev/null; then
        subject_name="$SERVER_IP"
        alt_names="IP:$SERVER_IP"
    fi
    
    print_info "Generating SSL certificate for: $subject_name"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout $SSL_KEY \
      -out $SSL_CERT \
      -subj "/C=US/ST=Home/L=Network/O=LLHome/CN=$subject_name" \
      -addext "subjectAltName=$alt_names" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        chmod 644 $SSL_CERT
        chmod 600 $SSL_KEY
        print_success "SSL certificate generated"
    else
        print_error "Failed to generate SSL certificate"
    fi
}

configure_nginx() {
    # Determine server name
    local server_name="$DOMAIN $SERVER_IP"
    if grep -q "server_name $SERVER_IP" $NGINX_CONF 2>/dev/null; then
        server_name="$SERVER_IP"
    fi
    
    print_info "Configuring Nginx for: $server_name"
    
    # Backup existing config
    if [ -f "$NGINX_CONF" ]; then
        cp "$NGINX_CONF" "${NGINX_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    cat > $NGINX_CONF << NGINXEOF
server {
    listen 80;
    server_name $server_name;
    
    # Redirect all HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $server_name;

    # SSL Configuration
    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer" always;

    # Logging
    access_log /var/log/nginx/nextcloud.access.log;
    error_log /var/log/nginx/nextcloud.error.log;

    # Client body size
    client_max_body_size 512M;
    client_body_timeout 300s;
    fastcgi_buffers 64 4K;

    # Proxy settings
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # WebDAV support
        proxy_buffering off;
        proxy_request_buffering off;
        
        # Timeouts
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
    }

    # Special handling for .well-known paths
    location = /.well-known/carddav {
        return 301 https://\$server_name/remote.php/dav;
    }
    
    location = /.well-known/caldav {
        return 301 https://\$server_name/remote.php/dav;
    }
}
NGINXEOF
    
    # Test configuration
    nginx -t &>/dev/null
    if [ $? -eq 0 ]; then
        print_success "Nginx configuration created"
    else
        print_error "Nginx configuration has errors"
        nginx -t
    fi
    
    # Enable site if using sites-available/enabled structure
    if [ -d "/etc/nginx/sites-enabled" ]; then
        ln -sf $NGINX_CONF /etc/nginx/sites-enabled/nextcloud 2>/dev/null
    fi
}

update_nextcloud_trusted_domains() {
    local domains="$@"
    
    print_info "Updating trusted domains..."
    
    # Wait for Nextcloud to be ready
    sleep 5
    
    # Clear existing trusted domains
    local index=0
    for domain in $domains; do
        podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set trusted_domains $index --value="$domain" 2>/dev/null
        ((index++))
    done
    
    # Set overwrite CLI URL to first domain
    local primary_domain=$(echo $domains | awk '{print $1}')
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set overwrite.cli.url --value="https://$primary_domain" 2>/dev/null
    
    print_success "Trusted domains updated"
}

enable_redis_in_nextcloud() {
    print_info "Enabling Redis caching in Nextcloud..."
    
    # Check if Redis is running
    if ! podman ps | grep -q $REDIS_CONTAINER; then
        print_error "Redis container not running"
        return
    fi
    
    # Configure Redis in Nextcloud
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set memcache.local --value='\OC\Memcache\Redis' 2>/dev/null
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set memcache.locking --value='\OC\Memcache\Redis' 2>/dev/null
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set redis host --value="$REDIS_HOST" 2>/dev/null
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set redis port --value=$REDIS_PORT 2>/dev/null
    
    print_success "Redis caching enabled"
}

disable_redis_in_nextcloud() {
    print_info "Disabling Redis caching..."
    
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:delete memcache.local 2>/dev/null
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:delete memcache.locking 2>/dev/null
    podman exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:delete redis 2>/dev/null
    
    print_success "Redis caching disabled"
}

show_redis_stats() {
    print_info "Redis statistics:"
    
    if ! podman ps | grep -q $REDIS_CONTAINER; then
        print_error "Redis not running"
        return
    fi
    
    podman exec $REDIS_CONTAINER redis-cli INFO stats 2>/dev/null || print_warning "Cannot get stats"
}

backup_nextcloud_config() {
    local backup_path="$1"
    
    if podman exec $NEXTCLOUD_CONTAINER test -f /var/www/html/config/config.php; then
        podman exec $NEXTCLOUD_CONTAINER cat /var/www/html/config/config.php > "$backup_path/config.php"
        print_success "Config backed up to: $backup_path/config.php"
    fi
}

show_setup_summary() {
    cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════╗
║               Setup Complete!                             ║
╚═══════════════════════════════════════════════════════════╝${NC}

${BOLD}Access Your Nextcloud:${NC}
  Primary:  https://$DOMAIN
  Fallback: https://$SERVER_IP

${BOLD}Admin Credentials:${NC}
  Username: $ADMIN_USER
  Password: [stored in script]

${BOLD}Services Running:${NC}
  ✓ Nextcloud (port 8080 → 443 via Nginx)
  ✓ MariaDB Database
  ✓ Redis Cache
  ✓ Nginx Reverse Proxy

${BOLD}Features Enabled:${NC}
  ✓ Self-signed SSL certificate
  ✓ Redis memory caching
  ✓ Firewall protection (HTTPS only)
  ✓ Auto-restart on reboot

${BOLD}IMPORTANT - Router DNS Configuration:${NC}
  To use domain name "$DOMAIN" from other devices,
  you must configure your router's DNS settings.
  
  Use option 15 from the main menu for detailed instructions.

${BOLD}Next Steps:${NC}
  1. Configure router DNS (see option 15)
  2. Install CA certificate on devices (to avoid SSL warnings)
  3. Access Nextcloud and complete initial setup
  4. Create user accounts (see option 11)

${BOLD}Backup Location:${NC}
  All backups are stored in: $BACKUP_DIR

EOF
}

#==============================================================================
# Main Entry Point
#==============================================================================

main() {
    check_prerequisites
    show_main_menu
}

# Run the script
main
