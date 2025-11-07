#!/bin/bash

# Add terminal initialization properties from old script
LOG_FILE="/tmp/browser_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Installation started at $(date)"

# Function to retry command on failure
retry() {
  local n=1
  local max=5
  local delay=5
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max:"
        sleep $delay
      else
        echo "The command has failed after $n attempts."
        return 1
      fi
    }
  done
}

# Suppress shell level warnings
export SHLVL=1

# Suppress Qt and VS Code prompts
export QT_LOGGING_RULES="*.debug=false"
export DONT_PROMPT_WSL_INSTALL=1
export QT_DEBUG_PLUGINS=0
export QT_LOGGING_TO_CONSOLE=0
export QT_MESSAGE_PATTERN=""

# Enhanced browser installation script with parallel processing and better reporting
LOG_FILE="/tmp/browser_install_enhanced.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Redirect Qt and VS Code messages to /dev/null
exec 2> >(grep -v "QStandardPaths\|Visual Studio Code" >&2)

# Default values for command line parameters
UPGRADE_ONLY=false
JUST_REPORTING=false
FORCE_INSTALL=true
UNINSTALL_ONLY=false
UPGRADE_OS_PACKAGES=false

# Function to print usage
print_usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --upgrade-only      Only upgrade existing packages, no uninstall/install"
  echo "  --just-reporting    Only generate installation report, no changes"
  echo "  --uninstall         Force uninstall all packages and generate report"
  echo "  --upgrade-os-packages  Upgrade all OS packages before installation"
  echo "  --help              Show this help message"
  echo ""
  echo "Note: If no options are provided, --force-install is used by default"
  exit 1
}

# Parse command line arguments
if [ $# -eq 0 ]; then
  print_blue "No options provided, using --force-install by default"
else
  while [[ $# -gt 0 ]]; do
    case $1 in
      --upgrade-only)
        UPGRADE_ONLY=true
        FORCE_INSTALL=false
        shift
        ;;
      --just-reporting)
        JUST_REPORTING=true
        FORCE_INSTALL=false
        shift
        ;;
      --uninstall)
        UNINSTALL_ONLY=true
        FORCE_INSTALL=false
        shift
        ;;
      --upgrade-os-packages)
        UPGRADE_OS_PACKAGES=true
        shift
        ;;
      --help)
        print_usage
        ;;
      *)
        echo "Unknown option: $1"
        print_usage
        ;;
    esac
  done
fi

# Function to print messages with colors
print_green() { echo -e "\e[32m$1\e[0m"; }
print_blue() { echo -e "\e[34m$1\e[0m"; }
print_red() { echo -e "\e[31m$1\e[0m"; }
print_yellow() { echo -e "\e[33m$1\e[0m"; }

# Function to create table borders
create_table_border() {
  local width=$1
  local char=$2
  printf "+%${width}s+\n" | tr " " "$char"
}

# Function to create table row
create_table_row() {
  local width=$1
  local content=$2
  printf "| %-${width}s |\n" "$content"
}

# Function to show progress spinner
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Function to check internet connection
check_internet() {
  print_blue "Checking internet connection..."
  if wget -q --spider http://google.com; then
    print_green "✓ Internet connection is active"
    return 0
  else
    print_red "✗ No internet connection detected"
    return 1
  fi
}

# Function to print colored table borders
print_table_border() {
  local width=$1
  local char=$2
  local color=$3
  printf "${color}+%${width}s+\e[0m\n" | tr " " "$char"
}

# Function to print colored table row
print_table_row() {
  local width=$1
  local content=$2
  local color=$3
  printf "${color}| %-${width}s |\e[0m\n" "$content"
}

# Function to print colored table header
print_table_header() {
  local width=$1
  local content=$2
  local color=$3
  printf "${color}| %-${width}s |\e[0m\n" "$content"
}

# Function to get version of a package
get_version() {
  local package=$1
  local version
  
  if command -v "$package" &>/dev/null; then
    case "$package" in
      google-chrome*)
        version=$("$package" --version | cut -d' ' -f3)
        ;;
      microsoft-edge*)
        version=$("$package" --version | cut -d' ' -f3)
        ;;
      opera)
        # Check if opera command exists
        if command -v opera &>/dev/null; then
          version=$(opera -version 2>/dev/null || echo "Installed")
        else
          version="Not installed"
        fi
        ;;
      brave-browser)
        version=$(brave-browser --version | cut -d' ' -f3)
        ;;
      firefox)
        # Skip version check for Firefox
        version="Installed"
        ;;
      konsole)
        version=$(konsole --version | head -n1 | cut -d' ' -f2)
        ;;
      pulseaudio)
        version=$(pulseaudio --version | cut -d' ' -f2)
        ;;
      dos2unix)
        version=$(dos2unix --version | head -n1 | cut -d' ' -f2)
        ;;
      code)
        version=$(code --version | head -n1)
        ;;
      *)
        version="Unknown"
        ;;
    esac
  else
    version="Not installed"
  fi
  echo "$version"
}

# Function to check if a package is installed
is_package_installed() {
  local package=$1
  dpkg -l | grep -q "^ii  $package "
  return $?
}

# Function to force remove a package
force_remove_package() {
  local package=$1
  print_blue "Force removing $package..."
  sudo dpkg --remove --force-remove-reinstreq "$package" 2>/dev/null
  sudo apt-get purge -y "$package" 2>/dev/null
  sudo apt-get autoremove -y 2>/dev/null
}

# Function to uninstall packages
uninstall_packages() {
  print_blue "Uninstalling existing packages..."
  local packages=(
    google-chrome-stable google-chrome-beta google-chrome-unstable
    microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev
    opera brave-browser firefox
    konsole pulseaudio dos2unix code
  )
  
  for pkg in "${packages[@]}"; do
    print_blue "Removing $pkg..."
    if is_package_installed "$pkg"; then
      if [[ "$pkg" == "opera" ]]; then
        force_remove_package "$pkg"
      else
        sudo apt-get remove -y "$pkg" 2>/dev/null
        sudo apt-get purge -y "$pkg" 2>/dev/null
      fi
    fi
  done
  
  # Remove repository files
  sudo rm -f /etc/apt/sources.list.d/google-chrome.list
  sudo rm -f /etc/apt/sources.list.d/microsoft-edge.list
  sudo rm -f /etc/apt/sources.list.d/opera.list
  sudo rm -f /etc/apt/sources.list.d/brave-browser-release.list
  sudo rm -f /etc/apt/sources.list.d/vscode.list
  
  # Clean up
  sudo apt-get autoremove -y
  sudo apt-get clean
  print_green "✓ Packages uninstalled successfully"
}

# Function to upgrade OS packages
upgrade_os_packages() {
  print_blue "Upgrading OS packages..."
  
  # List of packages to exclude from upgrade
  local exclude_packages=(
    google-chrome-stable google-chrome-beta google-chrome-unstable
    microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev
    opera brave-browser firefox
    konsole pulseaudio dos2unix code
  )
  
  # Create exclude string for apt-get
  local exclude_string=""
  for pkg in "${exclude_packages[@]}"; do
    exclude_string+="$pkg,"
  done
  exclude_string=${exclude_string%,}  # Remove trailing comma
  
  # Update package lists
  print_blue "Updating package lists..."
  sudo apt-get update -qq
  
  # Upgrade all packages except excluded ones
  print_blue "Upgrading packages (excluding browsers and tools)..."
  sudo apt-get upgrade -y -qq --exclude="$exclude_string"
  
  # Clean up
  print_blue "Cleaning up..."
  sudo apt-get autoremove -y -qq
  sudo apt-get clean -qq
  
  print_green "✓ OS packages upgraded successfully"
}

# Function to get package upgrade information
get_package_upgrade_info() {
  local info=()
  
  # Add basic system information only
  info+=("Total Installed OS Packages: $(dpkg -l | grep '^ii' | wc -l)")
  info+=("Total Available OS Packages: $(apt-cache pkgnames | wc -l)")
  
  # Print all information
  for line in "${info[@]}"; do
    echo "$line"
  done
}

# Function to get system information
get_system_info() {
  local info=()
  
  # WSL Information
  info+=("WSL Version: $(uname -r)")
  info+=("WSL Name: $(hostname)")
  info+=("WSL ID: $(lsb_release -si)")
  info+=("WSL Release: $(lsb_release -sr)")
  info+=("WSL Codename: $(lsb_release -sc)")
  
  # CPU Information
  info+=("CPU Model: $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^[ \t]*//')")
  info+=("CPU Cores: $(grep -c 'processor' /proc/cpuinfo)")
  info+=("CPU Threads: $(grep 'siblings' /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^[ \t]*//')")
  
  # Memory Information
  info+=("Total Memory: $(free -h | grep Mem | awk '{print $2}')")
  info+=("Available Memory: $(free -h | grep Mem | awk '{print $7}')")
  
  # Disk Information
  info+=("Root Disk Size: $(df -h / | tail -1 | awk '{print $2}')")
  info+=("Root Disk Used: $(df -h / | tail -1 | awk '{print $3}')")
  info+=("Root Disk Available: $(df -h / | tail -1 | awk '{print $4}')")
  
  # Network Information
  info+=("Hostname: $(hostname)")
  info+=("IP Address: $(hostname -I | awk '{print $1}')")
  info+=("DNS Servers: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')")
  
  # System Uptime
  info+=("System Uptime: $(uptime -p | sed 's/up //')")
  
  # WSL Specific Information
  if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    info+=("WSL Interop: Enabled")
  else
    info+=("WSL Interop: Disabled")
  fi
  
  # Display Information
  if [ -n "$DISPLAY" ]; then
    info+=("Display Server: $DISPLAY")
  else
    info+=("Display Server: Not configured")
  fi
  
  # GPU Information
  if command -v nvidia-smi &>/dev/null; then
    info+=("GPU: $(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | head -n1)")
  fi
  
  # Add basic package information
  while IFS= read -r line; do
    info+=("$line")
  done < <(get_package_upgrade_info)
  
  # Print all information
  for line in "${info[@]}"; do
    echo "$line"
  done
}

# Function to generate installation report
generate_report() {
  # Suppress Qt messages during report generation
  local QT_LOGGING_RULES_SAVE=$QT_LOGGING_RULES
  export QT_LOGGING_RULES="*.debug=false"
  
  local report_file="/tmp/installation_report_$(date +%Y%m%d_%H%M%S).txt"
  local install_date=$(date)
  
  {
    echo -e "\e[1;34m=== Installation Report ===\e[0m"
    echo -e "\e[1;34mGenerated on: $install_date\e[0m"
    echo -e "\e[1;34m==========================\e[0m"
    echo ""
    
    # System Information
    echo -e "\e[1;34m=== System Information ===\e[0m"
    print_table_border 150 "-" "\e[1;34m"
    printf "| %-30s | %-115s |\n" "Property" "Value"
    print_table_border 150 "-" "\e[1;34m"
    
    # Get and display system information
    while IFS= read -r line; do
      local property=$(echo "$line" | cut -d':' -f1)
      local value=$(echo "$line" | cut -d':' -f2- | sed 's/^[ \t]*//')
      printf "| %-30s | %-115s |\n" "$property" "$value"
    done < <(get_system_info)
    
    print_table_border 150 "-" "\e[1;34m"
    echo ""
    
    # Browsers table
    echo -e "\e[1;34m=== Browsers ===\e[0m"
    print_table_border 150 "-" "\e[1;34m"
    printf "| %-25s | %-10s | %-15s | %-50s | %-20s |\n" "Browser" "Status" "Version" "Path" "Installation Date"
    print_table_border 150 "-" "\e[1;34m"
    
    for browser in google-chrome-stable google-chrome-beta google-chrome-unstable \
                  microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev \
                  opera brave-browser firefox; do
      local status="✗"
      local path="Not installed"
      local version="Not installed"
      local install_date="N/A"
      local status_color="\e[31m"  # Red for failed
      
      if command -v "$browser" &>/dev/null; then
        status="✓"
        status_color="\e[32m"  # Green for success
        path=$(command -v "$browser")
        version=$(get_version "$browser")
        install_date=$(stat -c %y "$path" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
      fi
      
      printf "| %-25s | ${status_color}%-10s\e[0m | %-15s | %-50s | %-20s |\n" "$browser" "$status" "$version" "$path" "$install_date"
    done
    print_table_border 150 "-" "\e[1;34m"
    
    # Tools table
    echo -e "\n\e[1;34m=== Tools ===\e[0m"
    print_table_border 150 "-" "\e[1;34m"
    printf "| %-25s | %-10s | %-15s | %-50s | %-20s |\n" "Tool" "Status" "Version" "Path" "Installation Date"
    print_table_border 150 "-" "\e[1;34m"
    
    for tool in konsole pulseaudio dos2unix code; do
      local status="✗"
      local path="Not installed"
      local version="Not installed"
      local install_date="N/A"
      local status_color="\e[31m"  # Red for failed
      
      if command -v "$tool" &>/dev/null; then
        status="✓"
        status_color="\e[32m"  # Green for success
        path=$(command -v "$tool")
        version=$(get_version "$tool")
        install_date=$(stat -c %y "$path" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
      fi
      
      printf "| %-25s | ${status_color}%-10s\e[0m | %-15s | %-50s | %-20s |\n" "$tool" "$status" "$version" "$path" "$install_date"
    done
    print_table_border 150 "-" "\e[1;34m"
    
    # Installation summary
    echo -e "\n\e[1;34m=== Installation Summary ===\e[0m"
    local total_browsers=9
    local total_tools=4
    local installed_browsers=0
    local installed_tools=0
    
    for browser in google-chrome-stable google-chrome-beta google-chrome-unstable \
                  microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev \
                  opera brave-browser firefox; do
      if command -v "$browser" &>/dev/null; then
        ((installed_browsers++))
      fi
    done
    
    for tool in konsole pulseaudio dos2unix code; do
      if command -v "$tool" &>/dev/null; then
        ((installed_tools++))
      fi
    done
    
    print_table_border 50 "-" "\e[1;34m"
    printf "| %-25s | %-20s |\n" "Category" "Installed/Total"
    print_table_border 50 "-" "\e[1;34m"
    printf "| %-25s | %-20s |\n" "Browsers" "$installed_browsers/$total_browsers"
    printf "| %-25s | %-20s |\n" "Tools" "$installed_tools/$total_tools"
    print_table_border 50 "-" "\e[1;34m"
    
    # Add installation status
    echo -e "\n\e[1;34m=== Installation Status ===\e[0m"
    print_table_border 80 "-" "\e[1;34m"
    printf "| %-25s | %-50s |\n" "Status" "Value"
    print_table_border 80 "-" "\e[1;34m"
    
    local overall_status="Partial"
    local overall_color="\e[33m"  # Yellow for partial
    if [ $installed_browsers -eq $total_browsers ] && [ $installed_tools -eq $total_tools ]; then
      overall_status="Complete"
      overall_color="\e[32m"  # Green for complete
    fi
    
    local browsers_status="Incomplete"
    local browsers_color="\e[31m"  # Red for incomplete
    if [ $installed_browsers -eq $total_browsers ]; then
      browsers_status="Complete"
      browsers_color="\e[32m"  # Green for complete
    fi
    
    local tools_status="Incomplete"
    local tools_color="\e[31m"  # Red for incomplete
    if [ $installed_tools -eq $total_tools ]; then
      tools_status="Complete"
      tools_color="\e[32m"  # Green for complete
    fi
    
    printf "| %-25s | ${overall_color}%-50s\e[0m |\n" "Overall Status" "$overall_status"
    printf "| %-25s | ${browsers_color}%-50s\e[0m |\n" "Browsers Status" "$browsers_status"
    printf "| %-25s | ${tools_color}%-50s\e[0m |\n" "Tools Status" "$tools_status"
    print_table_border 80 "-" "\e[1;34m"
    
  } > "$report_file" 2>/dev/null
  
  # Restore original logging rules
  export QT_LOGGING_RULES=$QT_LOGGING_RULES_SAVE
  
  print_green "Installation report generated: $report_file"
  cat "$report_file"
}

# Function to kill Firefox processes
kill_firefox_processes() {
  print_blue "Killing Firefox processes..."
  # Kill all Firefox processes and their children
  pkill -9 firefox 2>/dev/null
  pkill -9 firefox-bin 2>/dev/null
  # Kill any remaining Firefox-related processes
  ps aux | grep -i firefox | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
  print_green "✓ Firefox processes terminated"
}

# Function to install packages with timeout
install_packages() {
  local packages=("$@")
  local total=${#packages[@]}
  local current=0
  local success=0
  local failed=0
  local timeout_seconds=120  # 2 minutes timeout
  
  for pkg in "${packages[@]}"; do
    ((current++))
    print_blue "Installing $pkg ($current/$total)..."
    
    # Start installation in background with timeout and retry
    (
      if [[ "$pkg" == "opera" ]]; then
        # Special handling for Opera
        # Pre-configure Opera package to avoid prompts
        echo "opera-stable opera-stable/add-deb-source boolean true" | sudo debconf-set-selections
        # Install Opera with DEBIAN_FRONTEND=noninteractive and retry
        retry DEBIAN_FRONTEND=noninteractive sudo apt-get install -y opera-stable >/dev/null 2>&1
      else
        # Use retry for other packages
        retry sudo apt-get install -y "$pkg" >/dev/null 2>&1
      fi
    ) &
    local pid=$!
    
    # Show spinner while installation is in progress
    spinner $pid
    
    # Check installation result
    if wait $pid; then
      print_green "✓ $pkg installed successfully"
      ((success++))
    else
      if [[ "$pkg" == "opera" ]]; then
        print_red "✗ Opera installation failed"
        # Force kill any remaining Opera processes
        pkill -9 opera 2>/dev/null
        pkill -9 opera-stable 2>/dev/null
        # Force remove Opera package
        force_remove_package opera-stable
      else
        print_red "✗ Failed to install $pkg"
      fi
      ((failed++))
    fi
  done
  
  # Print summary
  print_yellow "\nInstallation Summary:"
  print_green "Successfully installed: $success packages"
  if [ $failed -gt 0 ]; then
    print_red "Failed to install: $failed packages"
  fi
  echo ""
}

# Function to upgrade packages
upgrade_packages() {
  print_blue "Upgrading packages..."
  local packages=(
    google-chrome-stable google-chrome-beta google-chrome-unstable
    microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev
    opera brave-browser firefox
    konsole pulseaudio dos2unix code
  )
  
  for pkg in "${packages[@]}"; do
    if is_package_installed "$pkg"; then
      print_blue "Upgrading $pkg..."
      sudo apt-get install --only-upgrade -y "$pkg" >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        print_green "✓ $pkg upgraded successfully"
      else
        print_red "✗ Failed to upgrade $pkg"
      fi
    fi
  done
}

# Function to install VS Code with suppressed prompts
install_vscode() {
  print_blue "Installing Visual Studio Code..."
  # Set environment variables to suppress all prompts
  export DONT_PROMPT_WSL_INSTALL=1
  export DEBIAN_FRONTEND=noninteractive
  
  # Install VS Code with suppressed output
  {
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y code >/dev/null 2>&1
  } 2>/dev/null
  
  if [ $? -eq 0 ]; then
    print_green "✓ Visual Studio Code installed successfully"
  else
    print_red "✗ Failed to install Visual Studio Code"
  fi
}

# Function to force uninstall packages
force_uninstall_packages() {
  print_blue "Force uninstalling all packages..."
  local packages=(
    google-chrome-stable google-chrome-beta google-chrome-unstable
    microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev
    opera brave-browser firefox
    konsole pulseaudio dos2unix code
  )
  
  # Kill any running processes first
  for pkg in "${packages[@]}"; do
    case "$pkg" in
      firefox*)
        pkill -9 firefox 2>/dev/null
        pkill -9 firefox-bin 2>/dev/null
        ;;
      opera*)
        pkill -9 opera 2>/dev/null
        pkill -9 opera-stable 2>/dev/null
        ;;
      google-chrome*)
        pkill -9 chrome 2>/dev/null
        pkill -9 google-chrome 2>/dev/null
        ;;
      microsoft-edge*)
        pkill -9 msedge 2>/dev/null
        pkill -9 microsoft-edge 2>/dev/null
        ;;
      brave*)
        pkill -9 brave 2>/dev/null
        pkill -9 brave-browser 2>/dev/null
        ;;
    esac
  done
  
  # Force remove packages
  for pkg in "${packages[@]}"; do
    print_blue "Force removing $pkg..."
    # Remove package and its configuration
    sudo dpkg --remove --force-remove-reinstreq "$pkg" 2>/dev/null
    sudo apt-get purge -y "$pkg" 2>/dev/null
    # Remove any remaining files
    sudo rm -rf /opt/"$pkg" 2>/dev/null
    sudo rm -rf /usr/share/"$pkg" 2>/dev/null
    sudo rm -rf /usr/lib/"$pkg" 2>/dev/null
    sudo rm -rf /usr/bin/"$pkg" 2>/dev/null
  done
  
  # Remove repository files
  print_blue "Removing repository files..."
  sudo rm -f /etc/apt/sources.list.d/google-chrome.list
  sudo rm -f /etc/apt/sources.list.d/microsoft-edge.list
  sudo rm -f /etc/apt/sources.list.d/opera.list
  sudo rm -f /etc/apt/sources.list.d/brave-browser-release.list
  sudo rm -f /etc/apt/sources.list.d/vscode.list
  
  # Remove keyrings
  sudo rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
  sudo rm -f /usr/share/keyrings/packages.microsoft.gpg
  
  # Clean up
  print_blue "Cleaning up..."
  sudo apt-get autoremove -y
  sudo apt-get clean
  sudo apt-get autoclean
  
  print_green "✓ All packages force uninstalled successfully"
}

# Function to cleanup after installation
cleanup() {
  echo "Cleaning up..."
  sudo apt-get clean
  sudo apt-get autoremove -y
}

# Main installation process
main() {
  echo "Installation started at $(date)"
  
  if [ "$JUST_REPORTING" = true ]; then
    print_blue "Generating installation report only..."
    generate_report
    exit 0
  fi
  
  if [ "$UNINSTALL_ONLY" = true ]; then
    print_blue "Running in uninstall-only mode..."
    force_uninstall_packages
    generate_report
    exit 0
  fi
  
  # Kill Firefox processes before starting
  kill_firefox_processes
  
  # Upgrade OS packages if requested
  if [ "$UPGRADE_OS_PACKAGES" = true ]; then
    upgrade_os_packages
  fi
  
  if [ "$UPGRADE_ONLY" = true ]; then
    print_blue "Running in upgrade-only mode..."
    upgrade_packages
  else
    # Uninstall existing packages
    uninstall_packages
    
    # Check internet connection
    check_internet || exit 1
    
    # Update system
    print_blue "Updating system packages..."
    (sudo apt-get update -qq && sudo apt-get upgrade -y -qq) &
    local update_pid=$!
    spinner $update_pid
    if wait $update_pid; then
      print_green "✓ System updated successfully"
    else
      print_red "✗ System update failed"
    fi
    
    # Install dependencies
    print_blue "\nInstalling dependencies..."
    install_packages wget gnupg apt-transport-https curl
    
    # Add repositories and install browsers
    print_blue "\nSetting up repositories..."
    
    # Google Chrome
    print_blue "Setting up Google Chrome repository..."
    (wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - >/dev/null 2>&1 && \
     echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null) &
    local chrome_pid=$!
    spinner $chrome_pid
    if wait $chrome_pid; then
      print_green "✓ Google Chrome repository added"
    else
      print_red "✗ Failed to add Google Chrome repository"
    fi
    
    # Microsoft Edge
    print_blue "Setting up Microsoft Edge repository..."
    (wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - >/dev/null 2>&1 && \
     echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null) &
    local edge_pid=$!
    spinner $edge_pid
    if wait $edge_pid; then
      print_green "✓ Microsoft Edge repository added"
    else
      print_red "✗ Failed to add Microsoft Edge repository"
    fi
    
    # Opera
    print_blue "Setting up Opera repository..."
    (curl -s https://deb.opera.com/archive.key | sudo apt-key add - >/dev/null 2>&1 && \
     echo deb https://deb.opera.com/opera-stable/ stable non-free | sudo tee /etc/apt/sources.list.d/opera.list >/dev/null) &
    local opera_pid=$!
    spinner $opera_pid
    if wait $opera_pid; then
      print_green "✓ Opera repository added"
    else
      print_red "✗ Failed to add Opera repository"
    fi
    
    # Brave
    print_blue "Setting up Brave repository..."
    (sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >/dev/null && \
     echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null) &
    local brave_pid=$!
    spinner $brave_pid
    if wait $brave_pid; then
      print_green "✓ Brave repository added"
    else
      print_red "✗ Failed to add Brave repository"
    fi
    
    # VS Code
    print_blue "Setting up VS Code repository..."
    (wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null && \
     echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null) &
    local vscode_pid=$!
    spinner $vscode_pid
    if wait $vscode_pid; then
      print_green "✓ VS Code repository added"
    else
      print_red "✗ Failed to add VS Code repository"
    fi
    
    # Update package lists
    print_blue "\nUpdating package lists..."
    (sudo apt-get update -qq) &
    local update_pid=$!
    spinner $update_pid
    if wait $update_pid; then
      print_green "✓ Package lists updated"
    else
      print_red "✗ Failed to update package lists"
    fi
    
    # Install all packages
    print_blue "\nInstalling all packages..."
    install_packages google-chrome-stable google-chrome-beta google-chrome-unstable \
                    microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev \
                    opera brave-browser firefox konsole pulseaudio dos2unix code
    
    # Create Firefox wrapper
    print_blue "\nConfiguring Firefox..."
    (sudo tee /usr/local/bin/firefox-wrapper > /dev/null << 'EOF'
#!/bin/bash
export DISPLAY=:0
export MOZ_DBUS_REMOTE=1
export MOZ_ENABLE_WAYLAND=0

# Kill any existing Firefox processes before starting
pkill -9 firefox 2>/dev/null
pkill -9 firefox-bin 2>/dev/null

if [[ "$*" == *"-new-tab"* ]]; then
  URL=$(echo "$*" | grep -o '".*"' | sed 's/"//g')
  firefox --new-tab "$URL"
else
  firefox "$@"
fi
EOF
    ) &
    local firefox_pid=$!
    spinner $firefox_pid
    if wait $firefox_pid; then
      sudo chmod +x /usr/local/bin/firefox-wrapper
      sudo ln -sf /usr/local/bin/firefox-wrapper /usr/bin/firefox
      print_green "✓ Firefox configured successfully"
    else
      print_red "✗ Failed to configure Firefox"
    fi
    
    # Install VS Code with suppressed prompts
    install_vscode
    
    # Kill Firefox processes after installation
    kill_firefox_processes
    
    # Cleanup
    print_blue "\nCleaning up..."
    cleanup
  fi
  
  # Generate report
  generate_report
  
  print_green "\nInstallation completed at $(date)"
}

# Run main function
main 