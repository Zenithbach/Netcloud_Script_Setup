#!/bin/bash
#==============================================================================
# LLHome Nextcloud - Main Entry Point
# Lightweight menu that calls modular scripts
#==============================================================================

# Get the directory where this script lives
NC_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$NC_BASE/lib/common.sh"

require_root

#------------------------------------------------------------------------------
# Main Menu
#------------------------------------------------------------------------------

show_main_menu() {
    print_header
    echo -e "${BOLD}Main Menu${NC}"
    echo ""
    echo "  ${BOLD}Diagnostics:${NC}"
    echo "  1) Quick status check"
    echo "  2) Full diagnostics"
    echo "  3) View logs"
    echo ""
    echo "  ${BOLD}Fixes:${NC}"
    echo "  4) Quick fixes menu"
    echo "  5) Fix cron/background jobs"
    echo "  6) Fix all admin warnings"
    echo ""
    echo "  ${BOLD}Management:${NC}"
    echo "  7) User management"
    echo "  8) Backup & restore"
    echo ""
    echo "  ${BOLD}Help:${NC}"
    echo "  9) Connection instructions"
    echo "  10) Router DNS guide"
    echo "  11) View troubleshooting doc"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option (0-11): " choice
    echo ""
    
    case $choice in
        1)
            "$NC_BASE/modules/diagnose.sh" quick
            ;;
        2)
            "$NC_BASE/modules/diagnose.sh" full
            ;;
        3)
            "$NC_BASE/modules/diagnose.sh"
            ;;
        4)
            "$NC_BASE/modules/quick-fixes.sh"
            ;;
        5)
            "$NC_BASE/modules/cron-fix.sh"
            ;;
        6)
            "$NC_BASE/modules/warnings-fix.sh"
            ;;
        7)
            "$NC_BASE/modules/users.sh"
            ;;
        8)
            "$NC_BASE/modules/backup.sh"
            ;;
        9)
            show_connection_instructions
            ;;
        10)
            show_router_guide
            ;;
        11)
            less "$NC_BASE/docs/TROUBLESHOOTING.md" 2>/dev/null || cat "$NC_BASE/docs/TROUBLESHOOTING.md"
            ;;
        0)
            exit 0
            ;;
        *)
            print_error "Invalid option"
            sleep 1
            ;;
    esac
    
    press_enter
    show_main_menu
}

#------------------------------------------------------------------------------
# Quick Reference Information
#------------------------------------------------------------------------------

show_connection_instructions() {
    print_section "Connection Instructions"
    
    cat << EOF

Web Access:
  Primary:  https://$DOMAIN
  Fallback: https://$SERVER_IP
  
  Note: Accept the self-signed certificate warning

Admin Login:
  Username: $ADMIN_USER

Mobile/Desktop Apps:
  Server: https://$DOMAIN
  Accept self-signed certificate when prompted

WebDAV:
  URL: https://$DOMAIN/remote.php/dav

EOF
}

show_router_guide() {
    print_section "Router DNS Setup"
    
    cat << EOF

ASUS GT-AX11000 Quick Setup:

1. Login: http://192.168.1.1 or http://router.asus.com
2. Go to: LAN -> DHCP Server
3. Find: "DNS and WINS Server Setting"
4. Add: llcloud -> 192.168.1.138
5. Apply and reboot router

Per-Device Alternative (Mac):
  sudo nano /etc/hosts
  Add: 192.168.1.138    llcloud

Test:
  ping llcloud
  Should reply from 192.168.1.138

EOF
}

#------------------------------------------------------------------------------
# Command Line Interface
#------------------------------------------------------------------------------

show_help() {
    cat << EOF
LLHome Nextcloud Management

Usage: $0 [command] [options]

Commands:
  (none)        Show interactive menu
  status        Quick status check
  diagnose      Full diagnostics
  fix           Run quick fixes menu
  cron          Fix cron/background jobs
  warnings      Fix admin warnings
  users         User management
  backup        Backup & restore
  logs [n]      Show last n lines of logs (default: 50)
  help          Show this help

Module Scripts (can be run directly):
  modules/diagnose.sh       System diagnostics
  modules/cron-fix.sh       Cron troubleshooting
  modules/quick-fixes.sh    Common fixes
  modules/warnings-fix.sh   Admin panel warnings
  modules/users.sh          User management
  modules/backup.sh         Backup & restore

Examples:
  sudo ./nc.sh                    # Interactive menu
  sudo ./nc.sh status             # Quick status
  sudo ./nc.sh cron fix           # Fix cron issues
  sudo ./nc.sh warnings check     # Check warning status
  
  # Run module directly:
  sudo ./modules/cron-fix.sh status
  sudo ./modules/warnings-fix.sh all

EOF
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

case "${1:-}" in
    status)
        "$NC_BASE/modules/diagnose.sh" quick
        ;;
    diagnose|diag)
        "$NC_BASE/modules/diagnose.sh" full
        ;;
    fix|fixes)
        "$NC_BASE/modules/quick-fixes.sh"
        ;;
    cron)
        shift
        "$NC_BASE/modules/cron-fix.sh" "$@"
        ;;
    warnings|warn)
        shift
        "$NC_BASE/modules/warnings-fix.sh" "$@"
        ;;
    users|user)
        shift
        "$NC_BASE/modules/users.sh" "$@"
        ;;
    backup)
        shift
        "$NC_BASE/modules/backup.sh" "$@"
        ;;
    logs)
        "$NC_BASE/modules/diagnose.sh" logs "$NEXTCLOUD_CONTAINER" "${2:-50}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_main_menu
        ;;
esac
