#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Common Library
# Shared variables, colors, and helper functions
#==============================================================================

# Prevent multiple sourcing
[[ -n "$_COMMON_LOADED" ]] && return 0
_COMMON_LOADED=1

#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

#------------------------------------------------------------------------------
# Configuration - Edit these values for your setup
#------------------------------------------------------------------------------
SERVER_IP="192.168.1.138"
DOMAIN="llcloud"

# Container names
NEXTCLOUD_CONTAINER="nextcloud"
MARIADB_CONTAINER="nextcloud-db"
REDIS_CONTAINER="nextcloud-redis"
POD_NAME="nextcloud-pod"

# Paths
DATA_DIR="/mnt/cloud/data"
BACKUP_DIR="/mnt/cloudextra/ncpodbak"
MARIADB_DATA="/mnt/cloud/mariadb"

# Database
MARIADB_HOST="nextcloud-db"
DB_NAME="llcloud"
DB_USER="geoffcloud"
DB_PASSWORD='2Bv$rWt$o94g!%4xBYiQ8C8'
DB_ROOT_PASSWORD='8K8dU8%3D#4#ZS%gLQZFfG!'

# Admin
ADMIN_USER="ncadmin"
ADMIN_PASSWORD='2Ca!fMf#75HQwzKUzc^29chs3'

# Redis
REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"

# Nginx/SSL
NGINX_CONF="/etc/nginx/sites-available/nextcloud"
SSL_CERT="/etc/ssl/certs/nextcloud.crt"
SSL_KEY="/etc/ssl/private/nextcloud.key"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

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
    echo -e "${YELLOW}⚠${NC} $1"
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
    echo -e "${BLUE}║${NC}  ${BOLD}LLHome Nextcloud Server${NC}                                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Modular Management System${NC}                                   ${BLUE}║${NC}"
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

#------------------------------------------------------------------------------
# Root Check
#------------------------------------------------------------------------------
require_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# Container Checks
#------------------------------------------------------------------------------
is_container_running() {
    local container="$1"
    podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container}$"
}

is_container_exists() {
    local container="$1"
    podman ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${container}$"
}

wait_for_container() {
    local container="$1"
    local timeout="${2:-30}"
    local count=0
    
    while [ $count -lt $timeout ]; do
        if is_container_running "$container"; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    return 1
}

#------------------------------------------------------------------------------
# Nextcloud OCC wrapper
#------------------------------------------------------------------------------
occ() {
    podman exec -u www-data "$NEXTCLOUD_CONTAINER" php occ "$@"
}

#------------------------------------------------------------------------------
# Backup helper
#------------------------------------------------------------------------------
create_backup_dir() {
    local desc="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/${desc}_${timestamp}"
    
    mkdir -p "$backup_path"
    echo "$backup_path"
}

#------------------------------------------------------------------------------
# Get script directory (for sourcing other scripts)
#------------------------------------------------------------------------------
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    echo "$(cd -P "$(dirname "$source")" && pwd)"
}

# Export the base directory
SCRIPT_DIR="$(get_script_dir)"
NC_BASE_DIR="$(dirname "$SCRIPT_DIR")"
