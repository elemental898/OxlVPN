#!/bin/bash

# VPN data storage
VPN_DATA_DIR="/tmp/oxlvpn"
VPN_CONFIGS_DIR="$VPN_DATA_DIR/configs"
VPN_SERVERS_FILE="$VPN_DATA_DIR/servers.csv"
VPN_CACHE_FILE="$VPN_DATA_DIR/cache.json"
CACHE_EXPIRE_TIME=3600  # 1 hour

# Ensure directories exist
mkdir -p "$VPN_DATA_DIR" "$VPN_CONFIGS_DIR"

fetch_vpngate_servers() {
    log_info "Fetching VPN servers from VPNGate..."
    
    # Check if cache exists and is still valid
    if [[ -f "$VPN_CACHE_FILE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$VPN_CACHE_FILE" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt $CACHE_EXPIRE_TIME ]]; then
            log_info "Using cached server data (${cache_age}s old)"
            return 0
        fi
    fi
    
    # Fetch fresh data from VPNGate API
    local api_url="https://www.vpngate.net/api/iphone/"
    local temp_file="$VPN_DATA_DIR/temp_servers.csv"
    
    if curl -s --max-time 60 "$api_url" > "$temp_file"; then
        grep -v '^#' "$temp_file" | grep -v '^*' > "$VPN_SERVERS_FILE"
        
        # Create cache timestamp
        touch "$VPN_CACHE_FILE"
        
        log_success "Successfully fetched $(wc -l < "$VPN_SERVERS_FILE") VPN servers"
        rm -f "$temp_file"
        return 0
    else
        log_error "Failed to fetch VPN servers from VPNGate API"
        return 1
    fi
}

parse_vpn_server() {
    local line="$1"
    
    # Handle CSV parsing more robustly since message field CAN be empty
    local IFS=','
    local fields=()
    local current_field=""
    local in_quotes=false
    local i=0
    
    # Split the line into fields manually to handle empty fields properly
    while IFS=',' read -ra ADDR; do
        fields=("${ADDR[@]}")
        break
    done <<< "$line"
    
    # Extract the specific fields we need (0-indexed)
    local hostname="${fields[0]}"
    local ip="${fields[1]}"
    local score="${fields[2]}"
    local ping="${fields[3]}"
    local speed="${fields[4]}"
    local country_long="${fields[5]}"
    local country_short="${fields[6]}"
    local sessions="${fields[7]}"
    local config_b64="${fields[14]}"
    
    # Return only non-empty parsed data
    if [[ -n "$hostname" && -n "$ip" && -n "$config_b64" ]]; then
        echo "$hostname|$ip|$ping|$speed|$country_long|$country_short|$sessions|$config_b64"
    fi
}

get_country_flag() {
    case "$1" in
        "US") echo "🇺🇸" ;;
        "JP") echo "🇯🇵" ;;
        "DE") echo "🇩🇪" ;;
        "UK"|"GB") echo "🇬🇧" ;;
        "CA") echo "🇨🇦" ;;
        "FR") echo "🇫🇷" ;;
        "AU") echo "🇦🇺" ;;
        "NL") echo "🇳🇱" ;;
        "KR") echo "🇰🇷" ;;
        "IT") echo "🇮🇹" ;;
        "ES") echo "🇪🇸" ;;
        "BR") echo "🇧🇷" ;;
        "IN") echo "🇮🇳" ;;
        "RU") echo "🇷🇺" ;;
        "CN") echo "🇨🇳" ;;
        "SG") echo "🇸🇬" ;;
        "TH") echo "🇹🇭" ;;
        "VN") echo "🇻🇳" ;;
        "MY") echo "🇲🇾" ;;
        "ID") echo "🇮🇩" ;;
        *) echo "🌍" ;;
    esac
}

scan_and_show_vpns() {
    clear
    show_ascii_art "scanning"
    
    log_info "Scanning for available free VPNs..."
    echo
    
    # Fetch real VPN server data
    if ! fetch_vpngate_servers; then
        log_error "Failed to fetch VPN servers. Using offline mode."
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Read and parse ALL available server data
    local vpns=()
    local count=0
    
    if [[ -f "$VPN_SERVERS_FILE" ]]; then
        while IFS= read -r line; do
            if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*$ ]]; then
                local parsed_data=$(parse_vpn_server "$line")
                if [[ -n "$parsed_data" ]]; then
                    vpns+=("$parsed_data")
                    ((count++))
                fi
            fi
        done < "$VPN_SERVERS_FILE"
    fi
    
    if [[ ${#vpns[@]} -eq 0 ]]; then
        log_error "No VPN servers available - too bad to sad.. guess johnny wont be anonymous today.. :("
        read -p "Press Enter to continue..."
        return 1
    fi
    
    log_success "Parsed ${#vpns[@]} VPN servers successfully"
    echo
    log_info "Testing ${#vpns[@]} servers in parallel (5 second timeout)..."
    echo
    
    # Create temp directory for parallel ping results
    local temp_results_dir="/tmp/oxlvpn_ping_results"
    mkdir -p "$temp_results_dir"
    rm -f "$temp_results_dir"/* 2>/dev/null || true
    
    # Start all ping tests in parallel
    local pids=()
    local test_count=0
    
    for vpn in "${vpns[@]}"; do
        IFS='|' read -r hostname ip ping speed country_long country_short sessions config_b64 <<< "$vpn"
        
        ((test_count++))
        
        # Start each ping test in background and save result to temp file
        (
            local real_ping=$(test_ping "$ip")
            if [[ "$real_ping" != "timeout" ]]; then
                local ping_num=$(echo "$real_ping" | grep -o '[0-9]*' | head -1)
                local speed_num="${speed:-0}"
                local users_num="${sessions:-1}"
                
                # EXCLUDE single-user servers they are a big SCAM
                if [[ $users_num -eq 1 ]]; then
                    return
                fi
                
                # Calculate smart score: lower is better, PING IS KING!
                # Use same speed calculation as display (convert to Mbps)
                local speed_per_user_mbps=0
                if [[ $users_num -gt 0 && $speed_num -gt 0 ]]; then
                    speed_per_user_mbps=$(echo "scale=1; $speed_num / $users_num / 1000000" | bc -l)
                fi
                
                # User penalty for low activity or high congestion
                local user_penalty=0
                if [[ $users_num -lt 5 ]]; then
                    user_penalty=15  # Moderate penalty for very low users (2-4 users)
                elif [[ $users_num -gt 50 ]]; then
                    user_penalty=$(echo "scale=2; ($users_num - 50) / 5" | bc -l)  # Growing penalty for congestion
                fi
                
                # Smart score = ping + user_penalty - (speed_bonus)
                # Ping dominates completely, small speed bonus to break ties
                local smart_score=$(echo "scale=2; $ping_num + $user_penalty - ($speed_per_user_mbps / 10)" | bc -l)
                
                echo "${smart_score}|${ping_num}|${speed_num}|${users_num}|${vpn}|${real_ping}" > "$temp_results_dir/${test_count}.result"
            fi
        ) &
        
        pids+=($!)
    done
    
    # Simple progress message
    echo "${YELLOW}⚡ Testing ${#vpns[@]} servers in parallel...${NC}"
    
    # Wait for all background processes with 5 second timeout
    local wait_count=0
    while [[ $wait_count -lt 50 ]] && [[ $(jobs -r | wc -l) -gt 0 ]]; do
        sleep 0.1
        ((wait_count++))
    done
    
    # Kill any remaining processes after 5 seconds
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
    
    # Collect all results
    local all_tested_vpns=()
    for result_file in "$temp_results_dir"/*.result; do
        if [[ -f "$result_file" ]]; then
            all_tested_vpns+=("$(cat "$result_file")")
        fi
    done
    
    # Clean up temp results
    rm -rf "$temp_results_dir" 2>/dev/null || true
    
    echo "${GREEN}✓ Testing completed${NC}"
    
    # Sort by smart score (lower is better) and take best 10
    local sorted_vpns=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            sorted_vpns+=("$line")
        fi
    done < <(printf '%s\n' "${all_tested_vpns[@]}" | sort -t'|' -k1,1n | head -10)
    
    # Show the table header
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                        Top 10 Best VPNs                             ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${WHITE} ${NC} ${CYAN}No.${NC}   ${BLUE}Country     Hostname       ${NC} ${GREEN}Ping   ${NC} ${PURPLE}Speed/User${NC} ${YELLOW}Users${NC}"
    echo -e "${WHITE}════════════════════════════════════════════════════════════════════════${NC}"
    
    # Display the best VPNs
    local working_vpns=()
    local display_count=1
    
    for sorted_vpn in "${sorted_vpns[@]}"; do
        # Parse: smart_score|ping_num|speed_num|users_num|original_vpn_data|real_ping
        IFS='|' read -r smart_score ping_num speed_num users_num hostname ip ping speed country_long country_short sessions config_b64 real_ping <<< "$sorted_vpn"
        
        # Color code by ping
        local ping_color="${GREEN}"
        if [[ $ping_num -gt 200 ]]; then
            ping_color="${RED}"
        elif [[ $ping_num -gt 100 ]]; then
            ping_color="${YELLOW}"
        fi
        
        # Calculate and format speed per user
        local speed_per_user_mb=""
        if [[ -n "$speed_num" && "$speed_num" != "0" && -n "$users_num" && "$users_num" != "0" ]]; then
            local speed_per_user=$(echo "scale=1; $speed_num / $users_num / 1000000" | bc -l)
            speed_per_user_mb="${speed_per_user}Mbps"
        else
            speed_per_user_mb="N/A"
        fi
        
        # Color code users: green for low, yellow for medium, red for high
        local users_color="${GREEN}"
        if [[ $users_num -gt 200 ]]; then
            users_color="${RED}"
        elif [[ $users_num -gt 100 ]]; then
            users_color="${YELLOW}"
        fi
        
        local flag=$(get_country_flag "$country_short")
        
        # Display the VPN
        printf "${WHITE} ${NC} ${CYAN}%2d.${NC} %s %-12s ${BLUE}%-15s${NC} ${ping_color}%8s${NC} ${PURPLE}%10s${NC} ${users_color}%5s${NC}\n" \
               "$display_count" "$flag" "$country_short" "$hostname" "$real_ping" "$speed_per_user_mb" "$users_num"
        
        # Store for selection (reconstruct original format)
        working_vpns+=("$hostname|$ip|$ping|$speed|$country_long|$country_short|$sessions|$config_b64")
        ((display_count++))
    done
    
    # Show final status
    echo -e "${WHITE}════════════════════════════════════════════════════════════════════════${NC}"
    if [[ ${#working_vpns[@]} -eq 0 ]]; then
        echo -e "${WHITE} ${NC} ${RED}❌ No VPN servers responded within 3 seconds${NC}"
    else
        echo -e "${WHITE} ${NC} ${GREEN}✅ Selected ${#working_vpns[@]} best VPNs (smart sorted: users + ping + speed/user)${NC}"
    fi
    echo -e "${WHITE}════════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    if [[ ${#working_vpns[@]} -eq 0 ]]; then
        log_warning "No VPN servers responded within 3 seconds"
        log_info "Try again later or check your internet connection"
        echo
        read -p "Press Enter to return to menu..."
        return 1
    else
        log_success "Found ${#working_vpns[@]} working VPN servers ready for connection"
        echo
        read -p "Enter VPN number to connect (or Enter to return to menu): " vpn_choice
        
        if [[ -n "$vpn_choice" && "$vpn_choice" =~ ^[1-9][0-9]*$ && "$vpn_choice" -le ${#working_vpns[@]} ]]; then
            local selected_vpn="${working_vpns[$((vpn_choice-1))]}"
            IFS='|' read -r hostname ip ping speed country_long country_short sessions config_b64 <<< "$selected_vpn"
            # Check if this is a multi-hop connection
            local is_multihop="false"
            if [[ "$MULTIHOP_MODE" == "true" ]]; then
                is_multihop="true"
                unset MULTIHOP_MODE  # Reset flag
            fi
            connect_to_server "$hostname" "$ip" "$country_long" "$config_b64" "$is_multihop"
        fi
    fi
}

connect_to_vpn() {
    if [[ -n "$CURRENT_VPN" ]]; then
        log_warning "Already connected to $CURRENT_VPN"
        log_info "Disconnect first or use multi-hop for chaining"
        echo
        read -p "Press Enter to return to menu..."
        return
    fi
    
    scan_and_show_vpns
}

decode_openvpn_config() {
    local config_b64="$1"
    local hostname="$2"
    local config_file="$VPN_CONFIGS_DIR/${hostname}.ovpn"
    
    if [[ -n "$config_b64" ]]; then
        echo "$config_b64" | base64 -d > "$config_file" 2>/dev/null
        if [[ -s "$config_file" ]]; then
            echo "$config_file"
            return 0
        fi
    fi
    
    log_error "Failed to decode OpenVPN config for $hostname"
    return 1
}

connect_to_server() {
    local hostname="$1"
    local ip="$2"
    local location="$3"
    local config_b64="$4"
    local is_multihop="${5:-false}"
    
    log_info "Connecting to $hostname in $location..."
    
    # Check if OpenVPN is available
    if ! command -v openvpn &> /dev/null; then
        log_error "OpenVPN client not found. Install it with: sudo apt install openvpn"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Decode and save OpenVPN config
    local config_file
    if ! config_file=$(decode_openvpn_config "$config_b64" "$hostname"); then
        read -p "Press Enter to continue..."
        return 1
    fi
    
    log_info "OpenVPN config saved to $config_file"
    
    # Modify config for multi-hop if needed
    if [[ "$is_multihop" == "true" && ${#ACTIVE_CONNECTIONS[@]} -gt 0 ]]; then
        setup_multihop_routing "$config_file" "$hostname"
    fi
    
    log_info "Authenticating with OpenVPN..."
    
    # Start OpenVPN connection in background
    local log_file="$VPN_DATA_DIR/${hostname}_connection.log"
    local pid_file="$VPN_DATA_DIR/${hostname}.pid"
    
    sudo openvpn --config "$config_file" \
                 --daemon \
                 --log "$log_file" \
                 --writepid "$pid_file" \
                 --auth-nocache \
                 --verb 3
    
    if [[ $? -eq 0 ]]; then
        # Wait a bit for connection to establish
        log_info "Starting VPN connection..."
        sleep 3
        
        # Check if process is still running
        if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
            CURRENT_VPN="$hostname"
            ACTIVE_CONNECTIONS+=("$hostname")
            
            show_ascii_art "connection"
            log_success "Connected to $hostname ($location)"
            log_info "Your traffic is now routed through $location"
            log_info "PID: $(cat "$pid_file")"
            
            # Start traffic monitoring in background
            start_traffic_monitoring &
            
            echo
            read -p "Press Enter to return to menu..."
        else
            log_error "VPN connection failed to establish"
            log_info "Check log file: $log_file"
            read -p "Press Enter to continue..."
        fi
    else
        log_error "Failed to start OpenVPN connection"
        read -p "Press Enter to continue..."
    fi
}

setup_multihop_routing() {
    local config_file="$1"
    local hostname="$2"
    
    log_info "Configuring multi-hop routing for $hostname..."
    
    # Get the current VPN interface
    local current_tun=$(ip route | grep -o 'tun[0-9]*' | head -1)
    if [[ -n "$current_tun" ]]; then
        # Create a backup of the original config
        cp "$config_file" "${config_file}.orig"
        
        # Add minimal multi-hop configuration that won't break connectivity
        cat >> "$config_file" << EOF

# Multi-hop configuration
# Let OpenVPN handle routing but don't override everything
script-security 2
up /bin/true
down /bin/true
EOF
        
        log_info "Multi-hop routing configured - will work alongside $current_tun"
    else
        log_warning "No existing VPN interface found for multi-hop routing"
    fi
}

setup_multi_hop() {
    if [[ ${#ACTIVE_CONNECTIONS[@]} -eq 0 ]]; then
        log_warning "Connect to a VPN first before setting up multi-hop"
        echo
        read -p "Press Enter to return to menu..."
        return
    fi
    
    log_info "Setting up multi-hop connection..."
    log_info "This will chain VPNs: Your traffic → VPN1 → VPN2 → Internet"
    echo
    
    # Show current chain
    echo -e "${CYAN}Current connection chain:${NC}"
    local hop_num=1
    for conn in "${ACTIVE_CONNECTIONS[@]}"; do
        echo -e "  ${hop_num}. ${YELLOW}$conn${NC}"
        ((hop_num++))
    done
    echo -e "  ${hop_num}. ${GREEN}→ Internet${NC}"
    echo
    
    log_warning "Note: Adding another hop will route through existing VPN(s)"
    read -p "Add another hop? (y/n): " add_hop
    if [[ "$add_hop" =~ ^[Yy]$ ]]; then
        # Set flag for multi-hop connection
        export MULTIHOP_MODE=true
        scan_and_show_vpns
    fi
}

disconnect_current() {
    if [[ ${#ACTIVE_CONNECTIONS[@]} -eq 0 ]]; then
        log_warning "No active VPN connections"
        echo
        read -p "Press Enter to return to menu..."
        return
    fi
    
    log_info "Disconnecting ALL VPN connections..."
    
    # Kill ALL OpenVPN processes from active connections
    for conn in "${ACTIVE_CONNECTIONS[@]}"; do
        log_info "Stopping $conn..."
        local pid_file="$VPN_DATA_DIR/${conn}.pid"
        
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                log_info "Killing OpenVPN process (PID: $pid)..."
                sudo kill "$pid" 2>/dev/null || true
                sleep 1
                
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    log_warning "Force killing process $pid..."
                    sudo kill -9 "$pid" 2>/dev/null || true
                fi
            fi
            rm -f "$pid_file"
        fi
    done
    
    # Kill any remaining OpenVPN processes
    log_info "Cleaning up any remaining OpenVPN processes..."
    sudo pkill -f "openvpn.*${VPN_DATA_DIR}" 2>/dev/null || true
    
    log_info "Flushing routes and DNS..."
    sudo ip route flush cache 2>/dev/null || true
    
    # Clear all state
    CURRENT_VPN=""
    ACTIVE_CONNECTIONS=()
    VPN_INTERFACE=""
    
    log_success "All VPN connections disconnected"
    log_info "Back to your original IP: $(get_current_ip)"
    echo
    read -p "Press Enter to return to menu..."
}

disconnect_all_vpns() {
    # AGGRESSIVE CLEANUP - Kill everything VPN related
    log_info "Performing aggressive VPN cleanup..."
    
    # Kill all OpenVPN processes from our app
    if [[ ${#ACTIVE_CONNECTIONS[@]} -gt 0 ]]; then
        for conn in "${ACTIVE_CONNECTIONS[@]}"; do
            local pid_file="$VPN_DATA_DIR/${conn}.pid"
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    sudo kill -9 "$pid" 2>/dev/null || true
                fi
                rm -f "$pid_file"
            fi
        done
    fi
    
    # Kill ANY OpenVPN process that might be related to our configs
    sudo pkill -f "openvpn.*${VPN_DATA_DIR}" 2>/dev/null || true
    sudo pkill -f "openvpn.*oxlvpn" 2>/dev/null || true
    
    # Clean up routes aggressively
    sudo ip route flush cache 2>/dev/null || true
    
    # Clear all state
    ACTIVE_CONNECTIONS=()
    CURRENT_VPN=""
    VPN_INTERFACE=""
}