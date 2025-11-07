#!/bin/bash

# Modern script header with version and description
# Version: 1.1.0
# Description: WSL Browser Installation Script
# Author: System Administrator
# Last Modified: $(date +%Y-%m-%d)

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# Constants and configuration
readonly LOG_FILE="/tmp/browser_install.log"
readonly MAX_RETRIES=5
readonly RETRY_DELAY=5
readonly REQUIRED_PACKAGES=("wget" "gnupg" "apt-transport-https" "curl")

# ANSI color codes for better output
readonly GREEN='\e[32m'
readonly RED='\e[31m'
readonly YELLOW='\e[33m'
readonly NC='\e[0m' # No Color

# Setup logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Installation started at $(date) ==="

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print success messages
print_success() {
    print_message "$GREEN" "$1"
}

# Function to print error messages
print_error() {
    print_message "$RED" "$1"
}

# Function to print warning messages
print_warning() {
    print_message "$YELLOW" "$1"
}

# Function to retry command on failure with improved logging
retry() {
    local n=1
    local max=$MAX_RETRIES
    local delay=$RETRY_DELAY
    local command="$*"
    
    while true; do
        if "$@"; then
            return 0
        else
            if [[ $n -lt $max ]]; then
                print_warning "Command failed: $command"
                print_warning "Attempt $n/$max. Retrying in $delay seconds..."
                ((n++))
                sleep $delay
            else
                print_error "Command failed after $n attempts: $command"
                return 1
            fi
        fi
    done
}

# Function to check internet connection with timeout
check_internet() {
    print_message "$YELLOW" "Checking internet connection..."
    if timeout 5 wget -q --spider http://google.com; then
        print_success "Internet connection is active."
    else
        print_error "No internet connection detected. Please check your connection and try again."
        exit 1
    fi
}

# Function to uninstall a package if it's installed
uninstall_if_installed() {
    local package=$1
    if dpkg -l | grep -q "$package"; then
        print_message "$YELLOW" "Uninstalling $package..."
        if sudo apt-get remove -y "$package" >/dev/null 2>&1; then
            print_success "$package uninstalled successfully."
        else
            print_error "Failed to uninstall $package"
        fi
    else
        print_message "$YELLOW" "$package is not installed, skipping uninstallation."
    fi
}

# Function to install dependencies
install_dependencies() {
    print_message "$YELLOW" "Installing dependencies..."
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            retry sudo apt-get install -y "$package" >/dev/null 2>&1
        fi
    done
    print_success "Dependencies installed successfully."
}

# Function to clean up system
cleanup() {
    print_message "$YELLOW" "Cleaning up system..."
    sudo apt-get clean
    sudo apt-get autoremove -y
    print_success "Cleanup completed."
}

# Main installation function
main() {
    # Check internet connection
    check_internet

    # Update and upgrade system
    print_message "$YELLOW" "Updating and upgrading system..."
    retry sudo apt-get update -qq
    retry sudo apt-get upgrade -y -qq

    # Uninstall existing browsers and Visual Studio Code
    local packages_to_uninstall=(
        "google-chrome-stable"
        "google-chrome-beta"
        "google-chrome-unstable"
        "microsoft-edge-stable"
        "microsoft-edge-beta"
        "microsoft-edge-dev"
        "opera-stable"
        "brave-browser"
        "firefox"
        "code"
    )

    for package in "${packages_to_uninstall[@]}"; do
        uninstall_if_installed "$package"
    done

    # Remove leftover sources and keyrings
    print_message "$YELLOW" "Cleaning up leftover sources and keyrings..."
    local files_to_remove=(
        "/etc/apt/sources.list.d/google-chrome.list"
        "/etc/apt/sources.list.d/microsoft-edge.list"
        "/etc/apt/sources.list.d/microsoft-edge-beta.list"
        "/etc/apt/sources.list.d/opera.list"
        "/etc/apt/sources.list.d/brave-browser-release.list"
        "/etc/apt/sources.list.d/vscode.list"
        "/usr/share/keyrings/brave-browser-archive-keyring.gpg"
    )

    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            sudo rm -f "$file"
        fi
    done

    retry sudo apt-get autoremove -y -qq

    # Install dependencies
    install_dependencies

    # Install Google Chrome (Stable, Beta, Dev)
    print_message "$YELLOW" "Installing Google Chrome..."
    {
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - >/dev/null 2>&1
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ beta main" | sudo tee -a /etc/apt/sources.list.d/google-chrome.list >/dev/null
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ unstable main" | sudo tee -a /etc/apt/sources.list.d/google-chrome.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y google-chrome-stable google-chrome-beta google-chrome-unstable -qq
    } && print_success "Google Chrome installed."

    # Install Microsoft Edge (Stable, Beta, Dev)
    print_message "$YELLOW" "Installing Microsoft Edge..."
    {
        wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - >/dev/null 2>&1
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge beta main" | sudo tee /etc/apt/sources.list.d/microsoft-edge-beta.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev -qq
    } && print_success "Microsoft Edge installed."

    # Install Opera Browser without interruptions
    print_message "$YELLOW" "Installing Opera Browser..."
    {
        sudo apt-get install curl -y -qq
        curl -s https://deb.opera.com/archive.key | sudo apt-key add - >/dev/null 2>&1
        echo deb https://deb.opera.com/opera-stable/ stable non-free | sudo tee /etc/apt/sources.list.d/opera.list >/dev/null
        sudo apt-get update -qq
        # Pre-configure Opera package to avoid prompts
        echo "opera-stable opera-stable/add-deb-source boolean true" | sudo debconf-set-selections
        # Install Opera with DEBIAN_FRONTEND=noninteractive
        DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y opera-stable -qq
    } && print_success "Opera Browser installed."

    # Install Brave Browser with preferred method
    print_message "$YELLOW" "Installing Brave Browser..."
    {
        sudo apt-get install curl -y -qq
        sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >/dev/null
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y brave-browser -qq
    } && print_success "Brave Browser installed."

    # Install Firefox
    print_message "$YELLOW" "Installing Firefox..."
    {
        sudo apt-get install -y firefox -qq
        
        # Create a wrapper script for Firefox to ensure proper X11 forwarding
        sudo tee /usr/local/bin/firefox-wrapper > /dev/null << 'EOF'
#!/bin/bash
# Set environment variables for Firefox
export DISPLAY=:0
export MOZ_DBUS_REMOTE=1
export MOZ_ENABLE_WAYLAND=0

# Check if -new-tab flag is present
if [[ "$*" == *"-new-tab"* ]]; then
  # Extract the URL from the arguments
  URL=$(echo "$*" | grep -o '".*"' | sed 's/"//g')
  # Use Firefox's remote protocol to open a new tab
  firefox --new-tab "$URL"
else
  # Run Firefox normally with all arguments
  firefox "$@"
fi
EOF
        
        # Make the wrapper script executable
        sudo chmod +x /usr/local/bin/firefox-wrapper
        
        # Create a symbolic link to the wrapper script
        sudo ln -sf /usr/local/bin/firefox-wrapper /usr/bin/firefox
        
        print_success "Firefox installed and configured for WSL."
    } && print_success "Firefox installed."

    # Install Konsole
    print_message "$YELLOW" "Installing Konsole..."
    {
        sudo apt-get install -y konsole -qq
    } && print_success "Konsole installed."

    # Install PulseAudio
    print_message "$YELLOW" "Installing PulseAudio..."
    {
        sudo apt-get install -y pulseaudio -qq
    } && print_success "PulseAudio installed."

    # Install dos2unix
    print_message "$YELLOW" "Installing dos2unix..."
    {
        sudo apt-get install -y dos2unix -qq
    } && print_success "dos2unix installed."

    # Install Visual Studio Code
    print_message "$YELLOW" "Installing Visual Studio Code..."
    {
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y code -qq
    } && print_success "Visual Studio Code installed."

    # Confirm installations and show paths
    print_message "$YELLOW" "Confirming installations and showing paths..."
    local apps=(
        "google-chrome-stable"
        "google-chrome-beta"
        "google-chrome-unstable"
        "microsoft-edge-stable"
        "microsoft-edge-beta"
        "microsoft-edge-dev"
        "opera"
        "brave-browser"
        "firefox"
        "konsole"
        "pulseaudio"
        "dos2unix"
        "code"
    )

    for app in "${apps[@]}"; do
        if command -v "$app" &>/dev/null; then
            print_success "$app installed successfully."
            echo "$app path: $(command -v "$app")"
        else
            print_error "$app is not installed."
        fi
    done

    # Cleanup
    cleanup

    print_success "=== Installation completed at $(date) ==="
}

# Execute main function
main "$@"