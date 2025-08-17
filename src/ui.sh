#!/bin/bash

# UI and display functions

# Colors, very cool colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

show_ascii_art() {
    case $1 in
        "logo")
            echo -e "${CYAN}"
            cat << 'EOF'
 ██████╗ ██╗  ██╗██╗     ██╗   ██╗██████╗ ███╗   ██╗
██╔═══██╗╚██╗██╔╝██║     ██║   ██║██╔══██╗████╗  ██║
██║   ██║ ╚███╔╝ ██║     ██║   ██║██████╔╝██╔██╗ ██║
██║   ██║ ██╔██╗ ██║     ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║
╚██████╔╝██╔╝ ██╗███████╗ ╚████╔╝ ██║     ██║ ╚████║
 ╚═════╝ ╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚═╝     ╚═╝  ╚═══╝
                 ꜰʀᴇᴇ ᴠᴘɴ ꜰᴏʀ ᴛʜᴇ ᴘᴇᴏᴘʟᴇ, ʙʏ ᴛʜᴇ ᴘᴇᴏᴘʟᴇ
EOF
            echo -e "${NC}"
            ;;
        "connection")
            echo -e "${GREEN}"
            cat << 'EOF'
    🌐 ──────────────── 🔒
     Connected & Secure
EOF
            echo -e "${NC}"
            ;;
        "scanning")
            echo -e "${YELLOW}"
            cat << 'EOF'
    🔍 Scanning for VPNs...
EOF
            echo -e "${NC}"
            ;;
        "goodbye")
            echo -e "${PURPLE}"
            cat << 'EOF'
    👋 Until next time!
    Stay anonymous, stay free
EOF
            echo -e "${NC}"
            ;;
    esac
}

show_menu() {
    echo -e "${WHITE}╔══════════════════════════════════╗${NC}"
    echo -e "${WHITE}║            Main Menu             ║${NC}"
    echo -e "${WHITE}╠══════════════════════════════════╣${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}1.${NC} 🔍 Scan for VPNs              ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}2.${NC} 🌐 Connect to VPN             ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}3.${NC} 🔗 Multi-hop Connection       ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}4.${NC} 📊 Detailed Stats             ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}5.${NC} ⚡ Speed Test                 ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}6.${NC} ❌ Disconnect                 ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}7.${NC} ❓ Help                       ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}0.${NC} 🚪 Exit                       ${WHITE}║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════╝${NC}"
    echo
}

show_stats() {
    local current_ip=$(get_current_ip)
    local status_color="${RED}"
    local status_text="Disconnected"

    # Get stats
    if [[ -n "$CURRENT_VPN" ]]; then
        local stats=$(get_vpn_interface_stats)
        DOWNLOAD_BYTES=$(echo "$stats" | cut -d'|' -f1)
        UPLOAD_BYTES=$(echo "$stats" | cut -d'|' -f2)
        VPN_INTERFACE=$(echo "$stats" | cut -d'|' -f3)
        
        status_color="${GREEN}"
        local iface_info=""
        if [[ -n "$VPN_INTERFACE" ]]; then
            iface_info=" ($VPN_INTERFACE)"
        fi
        status_text="Connected via $CURRENT_VPN$iface_info"
    fi
    
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                       Status                             ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${WHITE} ${NC} IP: ${CYAN}$current_ip${NC}"
    echo -e "${WHITE} ${NC} Status: ${status_color}$status_text${NC}"
    echo -e "${WHITE} ${NC} Session: ${GREEN}$(format_bytes $DOWNLOAD_BYTES)${NC} ↓ ${RED}$(format_bytes $UPLOAD_BYTES)${NC} ↑"
    echo -e "${WHITE} ${NC} Active: ${YELLOW}${#ACTIVE_CONNECTIONS[@]}${NC} connections"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

show_help() {
    clear
    show_ascii_art "logo"
    echo -e "${WHITE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                  Help                      ║${NC}"
    echo -e "${WHITE}╠════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE}║${NC} OxlVPN is a simple, free VPN tool for      ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} developers and cybersec enthusiasts.       ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC}                                            ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}Features:${NC}                                  ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} • Free VPN servers worldwide               ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} • Multi-hop connections for extra privacy  ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} • Real-time traffic monitoring             ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} • Plug-n-play setup                        ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC}                                            ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} ${YELLOW}Note:${NC} These are free VPNs - great for      ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} P2P and general use, but not guaranteed    ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC} to be private. Use responsibly!            ${WHITE}║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════╝${NC}"
    echo
    read -p "Press Enter to continue..."
}