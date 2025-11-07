#!/bin/bash

# Enhanced WSL Installation Script
# Author: Your Name
# Version: 2.1
# Description: Installs browsers, networking tools, and development packages in WSL

# Configuration
LOG_FILE="/tmp/wsl_install_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="/tmp/wsl_install_report_$(date +%Y%m%d_%H%M%S).txt"
PACKAGE_LIST=(
    # Browsers
    "google-chrome-stable" "google-chrome-beta" "google-chrome-unstable"
    "microsoft-edge-stable" "microsoft-edge-beta" "microsoft-edge-dev"
    "opera-stable" "brave-browser" "firefox"
    
    # Networking Tools
    "net-tools" "dnsutils" "iputils-ping" "traceroute" "nmap"
    "tcpdump" "curl" "wget" "netcat" "iftop" "htop" "iptraf" "mtr" "whois" "telnet"
    
    # Development Tools
    "code" "tree" "htop" "tmux"
    "zsh" "powerline" "fonts-powerline" "neofetch"
)

# Initialize logging
exec > >(tee -a "$LOG_FILE") 2>&1

# ANSI Color Codes and Styles
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'
HIDDEN='\033[8m'

# Regular Colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Bold Colors
BOLD_BLACK='\033[1;30m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_PURPLE='\033[1;35m'
BOLD_CYAN='\033[1;36m'
BOLD_WHITE='\033[1;37m'

# Background Colors
BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_PURPLE='\033[45m'
BG_CYAN='\033[46m'
BG_WHITE='\033[47m'

# Reset
NC='\033[0m'

# Function to print header
print_header() {
    local title=$1
    local color=$2
    local width=80
    local padding=$(( (width - ${#title} - 2) / 2 ))
    local header=$(printf "%${padding}s%s%${padding}s" "" "$title" "")
    if [ $(( (width - ${#title} - 2) % 2 )) -ne 0 ]; then
        header="${header} "
    fi
    echo -e "${color}${BOLD}${UNDERLINE}${header}${NC}"
}

# Function to print section
print_section() {
    local title=$1
    local color=$2
    echo -e "\n${color}${BOLD}${title}${NC}"
    echo -e "${color}${DIM}$(printf '%*s' ${#title} | tr ' ' '-')${NC}"
}

# Function to print message with status
print_status() {
    local message=$1
    local status=$2
    local color=$3
    local width=80
    local padding=$(( width - ${#message} - ${#status} - 3 ))
    printf "${BOLD}%-${padding}s${color}[%s]${NC}\n" "$message" "$status"
}

# Function to print progress bar
print_progress() {
    local current=$1
    local total=$2
    local width=50
    local progress=$(( (current * width) / total ))
    local percentage=$(( (current * 100) / total ))
    printf "\r${BOLD_BLUE}[${BOLD_GREEN}%-${width}s${BOLD_BLUE}] ${BOLD_WHITE}%3d%%${NC}" \
        "$(printf '#%.0s' $(seq 1 $progress))" "$percentage"
}

# Function to check internet connection with retry
check_internet() {
    local retries=3
    local delay=5
    
    print_section "Checking Internet Connection" "$BOLD_CYAN"
    
    for ((i=1; i<=retries; i++)); do
        print_status "Attempt $i/$retries" "PENDING" "$BOLD_YELLOW"
        if wget -q --spider http://google.com; then
            print_status "Internet Connection" "OK" "$BOLD_GREEN"
            return 0
        else
            print_status "Internet Connection" "FAILED" "$BOLD_RED"
            if [ $i -lt $retries ]; then
                print_status "Retrying in $delay seconds..." "WAIT" "$BOLD_YELLOW"
                sleep $delay
            fi
        fi
    done
    
    print_status "Internet Connection" "FATAL" "$BOLD_RED"
    return 1
}

# Function to check if package is installed
is_package_installed() {
    dpkg -l | grep -q "^ii  $1 "
    return $?
}

# Function to install or update package
install_or_update_package() {
    local package=$1
    local total=${#PACKAGE_LIST[@]}
    local current=$((current_package + 1))
    
    if is_package_installed "$package"; then
        print_status "Updating $package" "UPDATE" "$BOLD_YELLOW"
        sudo apt-get install --only-upgrade -y "$package" >/dev/null 2>&1
    else
        print_status "Installing $package" "INSTALL" "$BOLD_BLUE"
        sudo apt-get install -y "$package" >/dev/null 2>&1
    fi
    
    print_progress $current $total
}

# Function to generate installation report
generate_report() {
    print_section "Generating Installation Report" "$BOLD_PURPLE"
    
    {
        print_header "WSL Installation Report" "$BOLD_WHITE"
        echo -e "\n${BOLD_CYAN}System Information:${NC}"
        echo -e "${DIM}OS:${NC} $(lsb_release -ds)"
        echo -e "${DIM}Kernel:${NC} $(uname -r)"
        
        echo -e "\n${BOLD_CYAN}Installed/Updated Packages:${NC}"
        for package in "${PACKAGE_LIST[@]}"; do
            if is_package_installed "$package"; then
                version=$(dpkg -s "$package" | grep Version | cut -d' ' -f2)
                echo -e "${DIM}$package:${NC} $version"
            fi
        done
        
        echo -e "\n${BOLD_CYAN}Network Configuration:${NC}"
        echo -e "${DIM}IP Address:${NC} $(hostname -I | awk '{print $1}')"
        echo -e "${DIM}Hostname:${NC} $(hostname)"
        
        echo -e "\n${BOLD_CYAN}System Resources:${NC}"
        echo -e "${DIM}CPU:${NC} $(lscpu | grep "Model name" | cut -d':' -f2 | xargs)"
        echo -e "${DIM}Memory:${NC} $(free -h | grep Mem | awk '{print $2}')"
        echo -e "${DIM}Disk Usage:${NC} $(df -h / | tail -1 | awk '{print $5}')"
    } > "$REPORT_FILE"
    
    print_status "Report Generated" "DONE" "$BOLD_GREEN"
}

# Main installation process
main() {
    print_header "WSL Installation Script" "$BOLD_WHITE"
    echo -e "${BOLD_CYAN}Version 2.1${NC}\n"
    
    # Check internet connection
    check_internet || exit 1

    # Update system
    print_section "System Update" "$BOLD_CYAN"
    print_status "Updating package lists" "START" "$BOLD_BLUE"
    sudo apt-get update -qq
    print_status "Upgrading system packages" "START" "$BOLD_BLUE"
    sudo apt-get upgrade -y -qq
    print_status "System Update" "COMPLETE" "$BOLD_GREEN"

    # Install/Update packages
    print_section "Package Installation" "$BOLD_CYAN"
    local current_package=0
    for package in "${PACKAGE_LIST[@]}"; do
        install_or_update_package "$package"
        ((current_package++))
    done
    echo -e "\n"  # New line after progress bar

    # Configure networking
    print_section "Network Configuration" "$BOLD_CYAN"
    print_status "Enabling SSH Server" "START" "$BOLD_BLUE"
    sudo systemctl enable ssh
    sudo systemctl start ssh
    print_status "SSH Server" "ENABLED" "$BOLD_GREEN"

    # Generate report
    generate_report
    
    print_section "Installation Summary" "$BOLD_GREEN"
    print_status "Installation" "COMPLETED" "$BOLD_GREEN"
    print_status "Report Location" "$REPORT_FILE" "$BOLD_CYAN"
    print_status "Log Location" "$LOG_FILE" "$BOLD_CYAN"
}

# Error handling
trap 'print_status "Error occurred on line $LINENO" "ERROR" "$BOLD_RED"; exit 1' ERR

# Execute main function
main

# Cleanup
print_section "Cleanup" "$BOLD_CYAN"
print_status "Cleaning package cache" "START" "$BOLD_BLUE"
sudo apt-get clean
print_status "Removing unused packages" "START" "$BOLD_BLUE"
sudo apt-get autoremove -y
print_status "Cleanup" "COMPLETE" "$BOLD_GREEN"

print_header "Installation Completed" "$BOLD_GREEN"