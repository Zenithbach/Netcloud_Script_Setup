#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Setup & Install Module
# Deploys containers with correct settings and fixes
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Install Functions
#------------------------------------------------------------------------------

create_directories() {
    print_section "Creating Directories"
    
    # Create data directories if they don't exist
    for dir in "$DATA_DIR" "$MARIADB_DATA" "$BACKUP_DIR"; do
        if [ ! -d "$dir" ]; then
            print_info "Creating $dir..."
            mkdir -p "$dir"
            chown -R 33:33 "$dir" # www-data
            chmod 750 "$dir"
        else
            print_success "Directory exists: $dir"
        fi
    done
}

generate_ssl() {
    print_section "Generating Self-Signed SSL"
    
    if [ -f "$SSL_CERT" ] && [ -f "$SSL_KEY" ]; then
        print_success "SSL Certificates already exist"
        return 0
    fi
    
    print_info "Generating new certificates..."
    mkdir -p "$(dirname "$SSL_CERT")"
    mkdir -p "$(dirname "$SSL_KEY")"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_KEY" \
        -out "$SSL_CERT" \
        -subj "/C=US/ST=Home/L=Network/O=LLHome/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN,IP:$SERVER_IP"
        
    if [ $? -eq 0 ]; then
        print_success "Certificates generated at $SSL_CERT"
        # Ensure Nginx can read them
        chmod 644 "$SSL_CERT"
        chmod 600 "$SSL_KEY"
    else
        print_error "Failed to generate certificates"
        exit 1
    fi
}

deploy_containers() {
    print_section "Deploying Containers"
    
    # 1. Stop and remove existing containers (Fixes 'Container not present' mismatch)
    print_info "Cleaning up old containers..."
    podman pod rm -f "$POD_NAME" 2>/dev/null
    podman rm -f "$NEXTCLOUD_CONTAINER" "$MARIADB_CONTAINER" "$REDIS_CONTAINER" 2>/dev/null
    
    # 2. Create Pod
    print_info "Creating Pod '$POD_NAME'..."
    podman pod create --name "$POD_NAME" -p 8080:80
    
    # 3. Start MariaDB
    print_info "Starting MariaDB..."
    podman run -d \
        --name "$MARIADB_CONTAINER" \
        --pod "$POD_NAME" \
        -v "$MARIADB_DATA:/var/lib/mysql:Z" \
        -e MYSQL_DATABASE="$DB_NAME" \
        -e MYSQL_USER="$DB_USER" \
        -e MYSQL_PASSWORD="$DB_PASSWORD" \
        -e MYSQL_ROOT_PASSWORD="$DB_ROOT_PASSWORD" \
        --restart=always \
        docker.io/library/mariadb:10.6

    # 4. Start Redis
    print_info "Starting Redis..."
    podman run -d \
        --name "$REDIS_CONTAINER" \
        --pod "$POD_NAME" \
        --restart=always \
        docker.io/library/redis:alpine

    # 5. Start Nextcloud
    print_info "Starting Nextcloud (1G RAM limit)..."
    podman run -d \
        --name "$NEXTCLOUD_CONTAINER" \
        --pod "$POD_NAME" \
        -v "$DATA_DIR:/var/www/html/data:Z" \
        -e MYSQL_HOST="$MARIADB_HOST" \
        -e MYSQL_DATABASE="$DB_NAME" \
        -e MYSQL_USER="$DB_USER" \
        -e MYSQL_PASSWORD="$DB_PASSWORD" \
        -e PHP_MEMORY_LIMIT=1G \
        --restart=always \
        docker.io/library/nextcloud:latest
        
    print_success "Containers deployed successfully"
}

install_extras() {
    print_section "Installing Extras (FFmpeg)"
    
    print_info "Waiting for Nextcloud to initialize (10s)..."
    sleep 10
    
    print_info "Updating container sources..."
    podman exec -u 0 "$NEXTCLOUD_CONTAINER" apt-get update
    
    print_info "Installing FFmpeg..."
    podman exec -u 0 "$NEXTCLOUD_CONTAINER" apt-get install -y ffmpeg
    
    if podman exec "$NEXTCLOUD_CONTAINER" which ffmpeg >/dev/null; then
        print_success "FFmpeg installed successfully"
    else
        print_error "Failed to install FFmpeg"
    fi
}

# ... inside modules/setup.sh ...

install_all() {
    print_header
    echo -e "${RED}${BOLD}WARNING: This will delete the existing '$POD_NAME' and containers!${NC}"
    # ... existing warning text ...
    
    if ! confirm "Are you sure you want to proceed?"; then
        exit 0
    fi
    
    create_directories
    generate_ssl
    deploy_containers
    install_extras
    
    # --- ADD THIS SECTION ---
    print_section "Configuring Nginx"
    "$SCRIPT_DIR/nginx.sh" install
    # ------------------------

    post_install_config
    
    print_section "Installation Complete"
    # ...
}

post_install_config() {
    print_section "Applying Configurations"
    
    # Run the existing quick fixes
    "$SCRIPT_DIR/quick-fixes.sh" all
    
    # Run the existing warning fixes
    "$SCRIPT_DIR/warnings-fix.sh" all
    
    print_success "Configurations applied"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

install_all() {
    print_header
    echo -e "${RED}${BOLD}WARNING: This will delete the existing '$POD_NAME' and containers!${NC}"
    echo "Data in mapped directories will be preserved."
    echo ""
    if ! confirm "Are you sure you want to proceed?"; then
        exit 0
    fi
    
    create_directories
    generate_ssl
    deploy_containers
    install_extras
    post_install_config
    
    print_section "Installation Complete"
    echo "You can now access Nextcloud at https://$SERVER_IP"
    echo "Note: If using Nginx proxy, ensure it is running: systemctl restart nginx"
}

case "${1:-}" in
    run|install) install_all ;;
    ffmpeg) install_extras ;;
    ssl) generate_ssl ;;
    *) 
        echo "Usage: $0 [install|ffmpeg|ssl]" 
        install_all
        ;;
esac