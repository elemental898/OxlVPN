#!/bin/bash

# Traffic monitoring and statistics

get_vpn_interface_stats() {
    # Get the numbers from tun interfaces
    local total_rx=0
    local total_tx=0
    
    # Extract tun interface stats
    while IFS= read -r line; do
        if [[ "$line" =~ tun[0-9]+ ]]; then
            # Get all numbers from the line
            local numbers=($(echo "$line" | grep -o '[0-9][0-9]*'))
            
            # Based on /proc/net/dev format: RX bytes is 2nd number, TX bytes is 10th number
            local rx="${numbers[1]:-0}"  # 2nd number (index 1)
            local tx="${numbers[9]:-0}"  # 10th number (index 9)
            
            total_rx=$((total_rx + rx))
            total_tx=$((total_tx + tx))
        fi
    done < /proc/net/dev
    
    echo "$total_rx|$total_tx|tun"
}

start_traffic_monitoring() {
    # Update stats every few seconds
    while [[ -n "$CURRENT_VPN" ]]; do
        local stats=$(get_vpn_interface_stats)
        DOWNLOAD_BYTES=$(echo "$stats" | cut -d'|' -f1)
        UPLOAD_BYTES=$(echo "$stats" | cut -d'|' -f2)
        VPN_INTERFACE=$(echo "$stats" | cut -d'|' -f3)
        
        sleep 3
    done
}

show_detailed_stats() {
    clear
    show_ascii_art "logo"
    
    local session_duration=$(($(date +%s) - SESSION_START))
    local hours=$((session_duration / 3600))
    local minutes=$(((session_duration % 3600) / 60))
    local seconds=$((session_duration % 60))
    
    echo -e "${WHITE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                    Detailed Stats                         ║${NC}"
    echo -e "${WHITE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${WHITE} ${NC} Session Duration: ${CYAN}${hours}h ${minutes}m ${seconds}s${NC}"
    echo -e "${WHITE} ${NC}"
    echo -e "${WHITE} ${NC} ${GREEN}📥 Downloaded:${NC}"
    echo -e "${WHITE} ${NC}   Total: ${GREEN}$(format_bytes $DOWNLOAD_BYTES)${NC}"
    echo -e "${WHITE} ${NC}   Rate:  ${GREEN}$(calculate_rate $DOWNLOAD_BYTES $session_duration)/s${NC}"
    echo -e "${WHITE} ${NC}"
    echo -e "${WHITE} ${NC} ${RED}📤 Uploaded:${NC}"
    echo -e "${WHITE} ${NC}   Total: ${RED}$(format_bytes $UPLOAD_BYTES)${NC}"
    echo -e "${WHITE} ${NC}   Rate:  ${RED}$(calculate_rate $UPLOAD_BYTES $session_duration)/s${NC}"
    echo -e "${WHITE} ${NC}"
    echo -e "${WHITE} ${NC} ${YELLOW}🔗 Connections:${NC}"
    if [[ ${#ACTIVE_CONNECTIONS[@]} -gt 0 ]]; then
        for conn in "${ACTIVE_CONNECTIONS[@]}"; do
            echo -e "${WHITE} ${NC}   → ${YELLOW}$conn${NC}"
        done
    else
        echo -e "${WHITE} ${NC}   ${RED}None${NC}"
    fi
    echo -e "${WHITE} ${NC}"
    echo -e "${WHITE} ${NC} ${BLUE}🌐 Current IP:${NC} ${CYAN}$(get_current_ip)${NC}"
    if [[ -n "$VPN_INTERFACE" ]]; then
        echo -e "${WHITE} ${NC} ${PURPLE}🔌 Interface:${NC} ${CYAN}$VPN_INTERFACE${NC}"
    fi
    echo -e "${WHITE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Press Enter to continue..."
}

format_bytes() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(bc <<< "scale=1; $bytes/1024")KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(bc <<< "scale=1; $bytes/1048576")MB"
    else
        echo "$(bc <<< "scale=1; $bytes/1073741824")GB"
    fi
}

calculate_rate() {
    local total_bytes=$1
    local duration=$2
    
    if [[ $duration -eq 0 ]]; then
        echo "0B"
        return
    fi
    
    local rate=$((total_bytes / duration))
    format_bytes $rate
}