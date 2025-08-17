#!/bin/bash

# Main OxlVPN application logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui.sh"
source "$SCRIPT_DIR/vpn.sh"
source "$SCRIPT_DIR/stats.sh"
source "$SCRIPT_DIR/utils.sh"

# Global state
CURRENT_VPN=""
SESSION_START=$(date +%s)
DOWNLOAD_BYTES=0
UPLOAD_BYTES=0
ACTIVE_CONNECTIONS=()
VPN_INTERFACE=""

cleanup() {
    echo
    log_info "Cleaning up VPN connections..."
    disconnect_all_vpns
    show_ascii_art "goodbye"
    echo -e "${CYAN}Thanks for using OxlVPN! Stay safe out there.${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

main() {
    check_dependencies
    show_ascii_art "logo"
    
    while true; do
        clear
        show_ascii_art "logo"
        show_stats
        show_menu
        
        # Auto-refresh menu every 60 seconds if idle
        if read -t 60 -p "Choose your move: " choice; then
            echo
            
            case $choice in
                1|scan) scan_and_show_vpns ;;
                2|c|connect) connect_to_vpn ;;
                3|m|multi-hop) setup_multi_hop ;;
                4|s|stats) show_detailed_stats ;;
                5|speed|speedtest) run_speed_test ;;
                6|d|disconnect) disconnect_current ;;
                7|h|help) show_help ;;
                0|q|quit|exit) cleanup ;;
                *) 
                    log_error "Invalid choice. Try again!"
                    sleep 1
                    ;;
            esac
        else
            # Timeout reached, refresh the menu
            continue
        fi
    done
}