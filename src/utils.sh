#!/bin/bash

# Utils functions

check_dependencies() {
    local missing_deps=()
    local optional_deps=()
    
    # Check for required tools
    local required_tools=("curl" "ping" "bc" "base64")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    # Check for OpenVPN (its actually quite important)
    if ! command -v "openvpn" &> /dev/null; then
        optional_deps+=("openvpn")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install them with: sudo apt install ${missing_deps[*]}"
        exit 1
    fi
    
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        log_warning "Optional dependencies missing: ${optional_deps[*]}"
        log_info "For full VPN functionality, install: sudo apt install ${optional_deps[*]}"
        log_info "You can still browse available VPNs without OpenVPN"
        echo
    fi
}

get_current_ip() {
    # Try some services to get public IP
    local ip=""
    
    for service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com"; do
        ip=$(curl -s --max-time 5 "$service" 2>/dev/null | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return
        fi
    done
    
    # Fallback
    ip=$(hostname -I | awk '{print $1}')
    echo "${ip:-Unknown}"
}

test_ping() {
    local host="$1"
    local result

    # Use 3 second timeout to check connectivity
    result=$(ping -c 1 -W 3 "$host" 2>/dev/null | grep 'time=' | grep -oE 'time=[0-9.]+' | cut -d'=' -f2)
    
    if [[ -n "$result" ]]; then
        echo "${result}ms"
    else
        echo "timeout"
    fi
}

generate_config() {
    local server="$1"
    local protocol="$2"
    
    # This would generate actual VPN config files
    # For now, just create a placeholder
    local config_dir="/tmp/oxlvpn"
    mkdir -p "$config_dir"
    
    cat > "$config_dir/${server}.conf" << EOF
# OxlVPN Configuration for $server
# Protocol: $protocol
# Generated: $(date)

# This is a placeholder config
# In a real implementation, this would contain
# actual VPN configuration parameters
EOF
    
    echo "$config_dir/${server}.conf"
}

is_root() {
    [[ $EUID -eq 0 ]]
}

require_root() {
    if ! is_root; then
        log_error "This operation requires root privileges"
        log_info "Run with: sudo $0"
        exit 1
    fi
}

# Simple speedtest implementation (not rlly accurate tho)
run_speed_test() {
    clear
    show_ascii_art "logo"
    
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                     Speed Test                           ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${WHITE} ${NC} Current IP: ${CYAN}$(get_current_ip)${NC}"
    if [[ -n "$CURRENT_VPN" ]]; then
        echo -e "${WHITE} ${NC} VPN: ${GREEN}Connected via $CURRENT_VPN${NC}"
    else
        echo -e "${WHITE} ${NC} VPN: ${RED}Not connected${NC}"
    fi
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    
    log_info "Choose test size:"
    echo -e "${WHITE} ${NC} ${CYAN}1.${NC} Small test (2MB) - Quick test"
    echo -e "${WHITE} ${NC} ${CYAN}2.${NC} Large test (10MB) - More accurate"
    echo
    read -p "Select test size (1 or 2): " test_choice
    echo
    
    local file_url=""
    local file_size=""
    local file_name=""
    
    case $test_choice in
        1)
            file_url="https://freetestdata.com/wp-content/uploads/2022/02/Free_Test_Data_2MB_MP4.mp4"
            file_size="2MB"
            file_name="2MB_test.mp4"
            ;;
        2)
            file_url="https://freetestdata.com/wp-content/uploads/2022/02/Free_Test_Data_10MB_MP4.mp4"
            file_size="10MB"
            file_name="10MB_test.mp4"
            ;;
        *)
            log_error "Invalid choice. Using 2MB test."
            file_url="https://freetestdata.com/wp-content/uploads/2022/02/Free_Test_Data_2MB_MP4.mp4"
            file_size="2MB"
            file_name="2MB_test.mp4"
            ;;
    esac
    
    log_info "Starting ${file_size} speed test..."
    echo -e "${YELLOW}⏳ Downloading test file...${NC}"
    echo
    
    # Create temp dir for test files
    local temp_dir="/tmp/oxlvpn_speedtest"
    mkdir -p "$temp_dir"
    local test_file="$temp_dir/$file_name"
    
    # Cleanup existing test files in case of previous interruption
    rm -f "$test_file"
    
    # Start timer and download
    local start_time=$(date +%s.%N)
    
    # Download with progress bar and capture result
    if curl -L --progress-bar -o "$test_file" "$file_url" 2>/dev/null; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        # Get actual file size
        local actual_size=$(stat -c%s "$test_file" 2>/dev/null || echo 0)
        
        if [[ $actual_size -gt 0 ]]; then
            # Calculate speed in various units
            local speed_bps=$(echo "scale=2; $actual_size / $duration" | bc -l)
            local speed_kbps=$(echo "scale=2; $speed_bps / 1024" | bc -l)
            local speed_mbps=$(echo "scale=2; $speed_bps * 8 / 1000000" | bc -l)
            
            # Clean up test file
            rm -f "$test_file"
            
            # Show results with nice UI
            echo -e "${WHITE}╔══════════════════════════════════════════════════════════╗${NC}"
            echo -e "${WHITE}║                    Speed Test Results                    ║${NC}"
            echo -e "${WHITE}╚══════════════════════════════════════════════════════════╝${NC}"
            echo -e "${WHITE} ${NC} Test File: ${CYAN}${file_size}${NC}"
            echo -e "${WHITE} ${NC} Downloaded: ${GREEN}$(format_bytes $actual_size)${NC}"
            echo -e "${WHITE} ${NC} Duration: ${YELLOW}${duration}s${NC}"
            echo -e "${WHITE} ${NC}"
            echo -e "${WHITE} ${NC} ${GREEN}📊 Download Speed:${NC}"
            
            # Color code speed based on speed
            local speed_color="${GREEN}"
            local speed_rating="Excellent"
            
            if (( $(echo "$speed_mbps < 1" | bc -l) )); then
                speed_color="${RED}"
                speed_rating="Slow"
            elif (( $(echo "$speed_mbps < 5" | bc -l) )); then
                speed_color="${YELLOW}"
                speed_rating="Fair"
            elif (( $(echo "$speed_mbps < 25" | bc -l) )); then
                speed_color="${GREEN}"
                speed_rating="Good"
            else
                speed_color="${CYAN}"
                speed_rating="Excellent"
            fi
            
            echo -e "${WHITE} ${NC}   ${speed_color}${speed_mbps} Mbps${NC} (${speed_rating})"
            echo -e "${WHITE} ${NC}   ${speed_kbps} KB/s"
            echo -e "${WHITE} ${NC}   $(echo "scale=0; $speed_bps / 1" | bc) bytes/s"
            echo -e "${WHITE} ${NC}"
            
            # Calculate 1GB download time (extra feature :p)
            local gb_bytes=1073741824  # 1GB in bytes
            local gb_time_seconds=$(echo "scale=1; $gb_bytes / $speed_bps" | bc -l)
            local gb_hours=$(echo "scale=0; $gb_time_seconds / 3600" | bc -l)
            local gb_minutes=$(echo "scale=0; ($gb_time_seconds % 3600) / 60" | bc -l)
            local gb_seconds_remaining=$(echo "scale=0; $gb_time_seconds % 60" | bc -l)
            
            echo -e "${WHITE} ${NC} ${PURPLE}⏱️  1GB Download Time:${NC}"
            if [[ $(echo "$gb_time_seconds < 60" | bc -l) -eq 1 ]]; then
                echo -e "${WHITE} ${NC}   ${CYAN}${gb_seconds_remaining}s${NC}"
            elif [[ $(echo "$gb_time_seconds < 3600" | bc -l) -eq 1 ]]; then
                echo -e "${WHITE} ${NC}   ${CYAN}${gb_minutes}m ${gb_seconds_remaining}s${NC}"
            else
                echo -e "${WHITE} ${NC}   ${CYAN}${gb_hours}h ${gb_minutes}m ${gb_seconds_remaining}s${NC}"
            fi
            
            echo -e "${WHITE}╚══════════════════════════════════════════════════════════╝${NC}"
            
            log_success "Speed test completed successfully!"
        else
            log_error "Downloaded file is empty or corrupted"
        fi
    else
        log_error "Failed to download test file"
        log_info "Check your internet connection"
    fi
    
    # Cleanup
    rm -rf "$temp_dir" 2>/dev/null || true
    
    echo
    read -p "Press Enter to return to menu..."
}