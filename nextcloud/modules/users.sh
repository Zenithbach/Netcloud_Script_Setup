#!/bin/bash
#==============================================================================
# LLHome Nextcloud - User Management Module
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

list_users() {
    print_section "Nextcloud Users"
    occ user:list
}

create_user() {
    print_section "Create New User"
    
    read -p "Username: " username
    read -sp "Password: " password
    echo ""
    read -p "Display name (optional): " displayname
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        print_error "Username and password are required"
        return 1
    fi
    
    if [ -n "$displayname" ]; then
        echo "$password" | occ user:add --password-from-env --display-name="$displayname" "$username"
    else
        echo "$password" | occ user:add --password-from-env "$username"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "User '$username' created"
    else
        print_error "Failed to create user"
    fi
}

delete_user() {
    print_section "Delete User"
    
    list_users
    echo ""
    read -p "Username to delete: " username
    
    if [ -z "$username" ]; then
        print_error "No username provided"
        return 1
    fi
    
    if confirm "Delete user '$username'? This cannot be undone!"; then
        occ user:delete "$username"
        if [ $? -eq 0 ]; then
            print_success "User '$username' deleted"
        else
            print_error "Failed to delete user"
        fi
    fi
}

reset_password() {
    print_section "Reset User Password"
    
    list_users
    echo ""
    read -p "Username: " username
    read -sp "New password: " password
    echo ""
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        print_error "Username and password are required"
        return 1
    fi
    
    echo "$password" | occ user:resetpassword --password-from-env "$username"
    if [ $? -eq 0 ]; then
        print_success "Password reset for '$username'"
    else
        print_error "Failed to reset password"
    fi
}

user_info() {
    print_section "User Information"
    
    list_users
    echo ""
    read -p "Username: " username
    
    if [ -z "$username" ]; then
        print_error "No username provided"
        return 1
    fi
    
    occ user:info "$username"
}

scan_user_files() {
    print_section "Scan User Files"
    
    list_users
    echo ""
    read -p "Username (leave empty for all): " username
    
    if [ -z "$username" ]; then
        print_info "Scanning all users..."
        occ files:scan --all
    else
        print_info "Scanning files for $username..."
        occ files:scan "$username"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Scan complete"
    else
        print_error "Scan failed"
    fi
}

#------------------------------------------------------------------------------
# Menu
#------------------------------------------------------------------------------

show_menu() {
    print_header
    echo -e "${BOLD}User Management${NC}"
    echo ""
    echo "  1) List all users"
    echo "  2) Create new user"
    echo "  3) Delete user"
    echo "  4) Reset password"
    echo "  5) User information"
    echo "  6) Scan user files"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) list_users ;;
        2) create_user ;;
        3) delete_user ;;
        4) reset_password ;;
        5) user_info ;;
        6) scan_user_files ;;
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
    list) list_users ;;
    create|add) create_user ;;
    delete|remove) delete_user ;;
    password|reset) reset_password ;;
    info) user_info ;;
    scan) scan_user_files ;;
    *) show_menu ;;
esac
