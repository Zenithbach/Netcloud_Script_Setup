#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Nginx Proxy Module
# Installs and configures Nginx as a reverse proxy
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Install Nginx
#------------------------------------------------------------------------------

install_nginx() {
    print_section "Installing Nginx"
    
    if ! command -v nginx &> /dev/null; then
        print_info "Installing Nginx package..."
        apt-get update
        apt-get install -y nginx
        print_success "Nginx installed"
    else
        print_success "Nginx is already installed"
    fi
}

#------------------------------------------------------------------------------
# Generate Configuration
#------------------------------------------------------------------------------

configure_nginx() {
    print_section "Generating Nginx Configuration"
    
    # Ensure SSL exists before writing config (or Nginx will fail)
    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
        print_error "SSL Certificates not found at $SSL_CERT"
        print_info "Please run: ./modules/setup.sh ssl"
        return 1
    fi

    print_info "Writing configuration to $NGINX_CONF..."

    # Create the directory if it's missing (rare)
    mkdir -p $(dirname "$NGINX_CONF")

    cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN $SERVER_IP;

    # Enforce HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN $SERVER_IP;

    # SSL Configuration
    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS (Strict-Transport-Security)
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;

    # Security Headers
    add_header Referrer-Policy "no-referrer" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Download-Options "noopen" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "none" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Max upload size (must match PHP limit)
    client_max_body_size 10G;
    client_body_timeout 300s;
    fastcgi_buffers 64 4K;

    # Nextcloud root (proxied)
    location / {
        proxy_pass http://127.0.0.1:8080;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;

        add_header Front-End-Https on;
        
        # Proxy timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Redirects for CalDAV/CardDAV (Crucial for iOS/macOS)
    location = /.well-known/carddav {
        return 301 \$scheme://\$host/remote.php/dav;
    }
    location = /.well-known/caldav {
        return 301 \$scheme://\$host/remote.php/dav;
    }
}
EOF

    print_success "Configuration file created"
}

#------------------------------------------------------------------------------
# Enable and Reload
#------------------------------------------------------------------------------

enable_site() {
    print_section "Enabling Site"
    
    # Link to sites-enabled
    if [ ! -L "/etc/nginx/sites-enabled/nextcloud" ]; then
        print_info "Linking site..."
        ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/
    fi
    
    # Remove default site if it exists to prevent conflicts
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        print_info "Removing default Nginx site..."
        rm /etc/nginx/sites-enabled/default
    fi
    
    # Test configuration
    print_info "Testing Nginx configuration..."
    if nginx -t; then
        print_success "Configuration test passed"
        systemctl reload nginx
        print_success "Nginx reloaded"
    else
        print_error "Configuration test failed! Check the output above."
        return 1
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

case "${1:-}" in
    install)
        install_nginx
        configure_nginx
        enable_site
        ;;
    config)
        configure_nginx
        ;;
    reload)
        enable_site
        ;;
    *)
        echo "Usage: $0 [install|config|reload]"
        install_nginx
        configure_nginx
        enable_site
        ;;
esac