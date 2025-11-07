#!/bin/bash

# Add at the beginning of the script
LOG_FILE="/tmp/browser_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Installation started at $(date)"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to print colored messages
print_message() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to print progress bar
progress_bar() {
  local width=50
  local percent=$1
  local filled=$((width * percent / 100))
  local empty=$((width - filled))
  printf "\r["
  printf "%${filled}s" | tr " " "="
  printf "%${empty}s" | tr " " " "
  printf "] %3d%%" $percent
}

# Function to check internet connection with detailed diagnostics
check_internet() {
  print_message "${BLUE}" "Checking internet connection..."
  
  # Check DNS resolution
  if ! nslookup google.com &>/dev/null; then
    print_message "${RED}" "DNS resolution failed"
    return 1
  fi
  
  # Check HTTP connectivity
  if ! curl -s -I https://www.google.com &>/dev/null; then
    print_message "${RED}" "HTTP connectivity failed"
    return 1
  fi
  
  # Check network speed
  print_message "${BLUE}" "Testing network speed..."
  speed=$(curl -s -w "%{speed_download}" -o /dev/null https://speed.hetzner.de/100MB.bin)
  speed_mbps=$(echo "scale=2; $speed / 125000" | bc)
  print_message "${GREEN}" "Network speed: ${speed_mbps} Mbps"
  
  print_message "${GREEN}" "Internet connection is active and stable."
  return 0
}

# Function to display package information in table format
display_package_info() {
  local package=$1
  local status=$2
  local version=$3
  
  printf "%-20s | %-15s | %-20s\n" "$package" "$status" "$version"
}

# Function to retry command on failure with progress indicator
retry() {
  local n=1
  local max=5
  local delay=5
  local command="$*"
  
  while true; do
    print_message "${YELLOW}" "Attempt $n/$max: $command"
    progress_bar $((n * 20))
    
    if $command; then
      echo -e "\n"
      return 0
    else
      if [[ $n -lt $max ]]; then
        ((n++))
        print_message "${YELLOW}" "Retrying in $delay seconds..."
        sleep $delay
      else
        print_message "${RED}" "Command failed after $max attempts"
        return 1
      fi
    fi
  done
}

# Function to uninstall a package if it's installed
uninstall_if_installed() {
  if dpkg -l | grep -q "$1"; then
    print_message "${YELLOW}" "Uninstalling $1..."
    sudo apt-get remove -y "$1" >/dev/null 2>&1
    print_message "${GREEN}" "$1 uninstalled successfully"
  else
    print_message "${BLUE}" "$1 is not installed, skipping uninstallation"
  fi
}

# Function to kill Firefox processes
kill_firefox() {
  print_message "${YELLOW}" "Killing any existing Firefox processes..."
  pkill -f firefox || true
  sleep 2  # Give processes time to terminate
  # Double check and force kill if needed
  pkill -9 -f firefox || true
}

# Function to get package version
get_package_version() {
  local package=$1
  dpkg -l | grep "^ii  $package" | awk '{print $3}'
}

# Function to compare versions
version_compare() {
  local current=$1
  local available=$2
  if [ "$current" = "$available" ]; then
    echo "same"
  elif [ "$(printf '%s\n' "$current" "$available" | sort -V | head -n1)" = "$current" ]; then
    echo "older"
  else
    echo "newer"
  fi
}

# Function to get package update date
get_package_update_date() {
  local package=$1
  stat -c %y /var/lib/dpkg/info/${package}.list 2>/dev/null | cut -d' ' -f1 || echo "Unknown"
}

# Function to display detailed package report
display_detailed_report() {
  local category=$1
  shift
  local packages=("$@")
  
  echo -e "\n${BOLD}${BLUE}$category Packages Report:${NC}"
  echo "====================================================================================="
  printf "%-25s | %-15s | %-15s | %-10s | %-10s\n" "Package" "Current Version" "Status" "Last Update" "Action"
  echo "-------------------------------------------------------------------------------------"
  
  for package in "${packages[@]}"; do
    local current_version=$(get_package_version "$package")
    local update_date=$(get_package_update_date "$package")
    local status="Not Installed"
    local action="Install"
    
    if [ -n "$current_version" ]; then
      status="Installed"
      # Check if update is available
      sudo apt-get update -qq
      local available_version=$(apt-cache policy "$package" | grep "Candidate:" | awk '{print $2}')
      if [ -n "$available_version" ]; then
        local comparison=$(version_compare "$current_version" "$available_version")
        if [ "$comparison" = "older" ]; then
          action="Update"
        else
          action="Keep"
        fi
      fi
    fi
    
    printf "%-25s | %-15s | %-15s | %-10s | %-10s\n" \
      "$package" \
      "${current_version:-N/A}" \
      "$status" \
      "$update_date" \
      "$action"
  done
  echo "====================================================================================="
}

# Print header
echo -e "${BOLD}${BLUE}"
echo "============================================="
echo "        WSL Browser Installation Script      "
echo "============================================="
echo -e "${NC}"

# Check internet connection
check_internet || exit 1

# Update and upgrade system with progress indicator
print_message "${BLUE}" "Updating and upgrading system..."
{
  sudo apt-get update -qq
  progress_bar 50
  sudo apt-get upgrade -y -qq
  progress_bar 100
  echo -e "\n"
} || { print_message "${RED}" "System update failed"; exit 1; }

# Display package information table header
echo -e "${BOLD}${BLUE}"
printf "%-20s | %-15s | %-20s\n" "Package" "Status" "Version"
echo "--------------------------------------------------------"
echo -e "${NC}"

# Kill Firefox processes before uninstallation
kill_firefox

# Uninstall existing browsers and Visual Studio Code
for package in google-chrome-stable google-chrome-beta google-chrome-unstable \
              microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev \
              opera-stable brave-browser firefox code; do
  uninstall_if_installed "$package"
  version=$(dpkg -l | grep "^ii  $package" | awk '{print $3}')
  display_package_info "$package" "Uninstalled" "$version"
done

# Remove leftover sources and keyrings
echo "Cleaning up leftover sources and keyrings..."
sudo rm -f /etc/apt/sources.list.d/google-chrome.list
sudo rm -f /etc/apt/sources.list.d/microsoft-edge.list
sudo rm -f /etc/apt/sources.list.d/microsoft-edge-beta.list
sudo rm -f /etc/apt/sources.list.d/opera.list
sudo rm -f /etc/apt/sources.list.d/brave-browser-release.list
sudo rm -f /etc/apt/sources.list.d/vscode.list
sudo rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
sudo apt-get autoremove -y -qq

# Install dependencies
echo "Installing dependencies..."
sudo apt-get install -y wget gnupg apt-transport-https curl >/dev/null 2>&1

# Install Google Chrome (Stable, Beta, Dev)
echo "Installing Google Chrome..."
{
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - >/dev/null 2>&1
  echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ beta main" | sudo tee -a /etc/apt/sources.list.d/google-chrome.list >/dev/null
  echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ unstable main" | sudo tee -a /etc/apt/sources.list.d/google-chrome.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y google-chrome-stable google-chrome-beta google-chrome-unstable -qq
} && print_message "${GREEN}" "Google Chrome installed."

# Install Microsoft Edge (Stable, Beta, Dev)
echo "Installing Microsoft Edge..."
{
  wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - >/dev/null 2>&1
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge beta main" | sudo tee /etc/apt/sources.list.d/microsoft-edge-beta.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev -qq
} && print_message "${GREEN}" "Microsoft Edge installed."

# Install Opera Browser without interruptions
echo "Installing Opera Browser..."
{
  sudo apt-get install curl -y -qq
  curl -s https://deb.opera.com/archive.key | sudo apt-key add - >/dev/null 2>&1
  echo deb https://deb.opera.com/opera-stable/ stable non-free | sudo tee /etc/apt/sources.list.d/opera.list >/dev/null
  sudo apt-get update -qq
  # Pre-configure Opera package to avoid prompts
  echo "opera-stable opera-stable/add-deb-source boolean true" | sudo debconf-set-selections
  # Install Opera with DEBIAN_FRONTEND=noninteractive
  DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y opera-stable -qq
} && print_message "${GREEN}" "Opera Browser installed."

# Install Brave Browser with preferred method
echo "Installing Brave Browser..."
{
  sudo apt-get install curl -y -qq
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y brave-browser -qq
} && print_message "${GREEN}" "Brave Browser installed."

# Install Firefox
print_message "${BLUE}" "Installing Firefox..."
{
  kill_firefox  # Kill any Firefox processes before installation
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
  
  kill_firefox  # Kill any Firefox processes after installation
  print_message "${GREEN}" "Firefox installed and configured for WSL."
} && print_message "${GREEN}" "Firefox installed."

# Install Konsole
echo "Installing Konsole..."
{
  sudo apt-get install -y konsole -qq
} && print_message "${GREEN}" "Konsole installed."

# Install PulseAudio
echo "Installing PulseAudio..."
{
  sudo apt-get install -y pulseaudio -qq
} && print_message "${GREEN}" "PulseAudio installed."

# Install dos2unix
echo "Installing dos2unix..."
{
  sudo apt-get install -y dos2unix -qq
} && print_message "${GREEN}" "dos2unix installed."

# Install Visual Studio Code
echo "Installing Visual Studio Code..."
{
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y code -qq
} && print_message "${GREEN}" "Visual Studio Code installed."

# Install networking tools
print_message "${BLUE}" "Installing networking tools..."
{
  sudo apt-get install -y net-tools dnsutils traceroute nmap tcpdump -qq
  print_message "${GREEN}" "Networking tools installed successfully"
} || print_message "${RED}" "Failed to install networking tools"

# After system update, display detailed reports
print_message "${BLUE}" "Generating detailed package reports..."

# Browser packages
browser_packages=(
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

# Networking packages
networking_packages=(
  "net-tools"
  "dnsutils"
  "traceroute"
  "nmap"
  "tcpdump"
  "curl"
  "wget"
  "openssh-client"
  "openssh-server"
  "netcat"
  "iputils-ping"
  "iproute2"
)

# System packages
system_packages=(
  "konsole"
  "pulseaudio"
  "dos2unix"
)

# Display reports
display_detailed_report "Browser" "${browser_packages[@]}"
display_detailed_report "Networking" "${networking_packages[@]}"
display_detailed_report "System" "${system_packages[@]}"

# Function to install or update package if needed
install_or_update_package() {
  local package=$1
  local current_version=$(get_package_version "$package")
  local action="install"
  
  if [ -n "$current_version" ]; then
    sudo apt-get update -qq
    local available_version=$(apt-cache policy "$package" | grep "Candidate:" | awk '{print $2}')
    if [ -n "$available_version" ]; then
      local comparison=$(version_compare "$current_version" "$available_version")
      if [ "$comparison" = "older" ]; then
        action="upgrade"
      else
        return 0  # Skip if version is same or newer
      fi
    fi
  fi
  
  print_message "${YELLOW}" "Performing $action for $package..."
  if [ "$action" = "install" ]; then
    sudo apt-get install -y "$package" -qq
  else
    sudo apt-get upgrade -y "$package" -qq
  fi
  return $?
}

# Install/update packages based on report
print_message "${BLUE}" "Processing package installations and updates..."

# Process browser packages
for package in "${browser_packages[@]}"; do
  install_or_update_package "$package"
done

# Process networking packages
for package in "${networking_packages[@]}"; do
  install_or_update_package "$package"
done

# Process system packages
for package in "${system_packages[@]}"; do
  install_or_update_package "$package"
done

# Display final report
print_message "${BLUE}" "Generating final installation report..."
display_detailed_report "Final Status" "${browser_packages[@]}" "${networking_packages[@]}" "${system_packages[@]}"

# Cleanup with progress indicator
print_message "${BLUE}" "Cleaning up..."
{
  sudo apt-get clean
  progress_bar 50
  sudo apt-get autoremove -y
  progress_bar 100
  echo -e "\n"
} || print_message "${RED}" "Cleanup failed"

# Print footer
echo -e "${BOLD}${GREEN}"
echo "============================================="
echo "    Installation completed successfully!     "
echo "============================================="
echo -e "${NC}"

# Add at the end of the script
echo "Installation completed at $(date)"