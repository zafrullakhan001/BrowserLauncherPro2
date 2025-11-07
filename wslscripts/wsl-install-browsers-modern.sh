#!/bin/bash

# Set strict error handling
set -euo pipefail

# Configuration
LOG_FILE="/tmp/browser_install.log"
PARALLEL_JOBS=2  # Reduced from 4 to prevent too many simultaneous connections
TIMEOUT=15       # Reduced connection timeout to prevent long hangs
DEBUG=true       # Set to true to enable debug output

# Log setup
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Installation started at $(date)"

# Colors for terminal output
GREEN="\e[32m"
BLUE="\e[34m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Function to print colored messages
print_msg() {
  local color="$1"
  local msg="$2"
  echo -e "${color}${msg}${RESET}"
}

# Function to print debug info
debug_msg() {
  if [[ "$DEBUG" == "true" ]]; then
    local msg="$1"
    echo -e "${YELLOW}[DEBUG] ${msg}${RESET}"
  fi
}

# Function to retry command on failure
retry() {
  local n=1
  local max=5
  local delay=5
  local cmd="$*"
  
  while true; do
    if eval "$cmd"; then
      return 0
    else
      if [[ $n -lt $max ]]; then
        ((n++))
        print_msg "$BLUE" "Command failed. Attempt $n/$max (waiting ${delay}s)..."
        sleep $delay
      else
        print_msg "$RED" "The command has failed after $n attempts."
        return 1
      fi
    fi
  done
}

# Function to check internet connection (with timeout)
check_internet() {
  print_msg "$BLUE" "Checking internet connection..."
  debug_msg "Testing connection to google.com with timeout $TIMEOUT seconds..."
  if timeout $TIMEOUT wget -q --spider http://google.com; then
    print_msg "$GREEN" "Internet connection is active."
  else
    print_msg "$RED" "No internet connection detected or timeout reached. Please check your connection and try again."
    exit 1
  fi
}

# Function to check and create a lock file to prevent concurrent apt operations
check_apt_lock() {
  local lock_file="/var/lib/apt/lists/lock"
  local dpkg_lock="/var/lib/dpkg/lock-frontend"
  
  # Wait for locks to be released
  while fuser "$lock_file" >/dev/null 2>&1 || fuser "$dpkg_lock" >/dev/null 2>&1; do
    print_msg "$BLUE" "Waiting for apt/dpkg locks to be released..."
    sleep 2
  done
}

# Function to uninstall a package if it's installed
uninstall_if_installed() {
  if dpkg -l | grep -q "^ii.*$1 "; then
    print_msg "$BLUE" "Uninstalling $1..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "$1" >/dev/null 2>&1
    print_msg "$GREEN" "$1 uninstalled."
  else
    print_msg "$BLUE" "$1 is not installed, skipping uninstallation."
  fi
}

# Function to add repository without repeated apt updates
add_repository() {
  local name="$1"
  local key_url="$2"
  local repo_entry="$3"
  local key_file="$4"
  
  print_msg "$BLUE" "Adding repository for $name..."
  
  # Remove any existing repo file to prevent duplicates
  sudo rm -f /etc/apt/sources.list.d/"$name".list
  
  if [[ -n "$key_file" ]]; then
    # Modern method using signed-by with timeout
    print_msg "$BLUE" "Downloading key for $name..."
    if ! timeout 30 curl -fsSL "$key_url" | sudo gpg --dearmor -o "$key_file" 2>/dev/null; then
      print_msg "$RED" "Failed to download or process key for $name, skipping..."
      return 1
    fi
    echo "$repo_entry" | sudo tee /etc/apt/sources.list.d/"$name".list >/dev/null
  else
    # Legacy method (for compatibility) with timeout
    print_msg "$BLUE" "Downloading key for $name using legacy method..."
    if ! timeout 30 curl -fsSL "$key_url" | sudo apt-key add - >/dev/null 2>&1; then
      print_msg "$RED" "Failed to download or add key for $name, skipping..."
      return 1
    fi
    echo "$repo_entry" | sudo tee /etc/apt/sources.list.d/"$name".list >/dev/null
  fi
  
  print_msg "$GREEN" "Repository for $name added successfully."
}

# Function to install a package or packages
install_package() {
  local name="$1"
  shift
  local packages=("$@")
  
  print_msg "$BLUE" "Installing $name..."
  check_apt_lock
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" -qq
  print_msg "$GREEN" "$name installed."
}

# Optimize apt settings for faster downloads
optimize_apt() {
  print_msg "$BLUE" "Optimizing apt for faster downloads..."
  
  # Create apt.conf.d file for parallel downloads
  echo "Acquire::Queue-Mode \"host\";
Acquire::http::Pipeline-Depth 10;
Acquire::http::Timeout \"$TIMEOUT\";
Acquire::https::Timeout \"$TIMEOUT\";
Acquire::Retries 3;
Acquire::ForceIPv4 \"true\";
APT::Install-Recommends \"false\";
APT::Install-Suggests \"false\";
Acquire::Languages \"none\";
Acquire::GzipIndexes \"true\";
Acquire::CompressionTypes::Order:: \"gz\";
Acquire::Parallel-Downloading-Items $PARALLEL_JOBS;" | sudo tee /etc/apt/apt.conf.d/99custom >/dev/null
}

# Clean up existing repository files
cleanup_existing_repos() {
  print_msg "$BLUE" "Cleaning up existing repository configurations..."
  
  # Remove all existing browser repository files one by one to ensure they're gone
  sudo rm -f /etc/apt/sources.list.d/google-chrome.list
  sudo rm -f /etc/apt/sources.list.d/google-chrome-beta.list
  sudo rm -f /etc/apt/sources.list.d/google-chrome-unstable.list
  sudo rm -f /etc/apt/sources.list.d/microsoft-edge.list
  sudo rm -f /etc/apt/sources.list.d/microsoft-edge-beta.list
  sudo rm -f /etc/apt/sources.list.d/microsoft-edge-dev.list
  sudo rm -f /etc/apt/sources.list.d/opera.list
  sudo rm -f /etc/apt/sources.list.d/opera-stable.list
  sudo rm -f /etc/apt/sources.list.d/brave-browser-release.list
  sudo rm -f /etc/apt/sources.list.d/vscode.list
  sudo rm -f /etc/apt/sources.list.d/brave-browser.list

  # Remove keyrings
  sudo rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
  sudo rm -f /usr/share/keyrings/packages.microsoft.gpg
  sudo rm -f /usr/share/keyrings/microsoft-edge.gpg
  
  # Force dpkg to fix any interrupted installations
  sudo dpkg --configure -a
  
  # Force cleanup of apt lists
  sudo rm -rf /var/lib/apt/lists/*
}

# Firefox wrapper script setup
setup_firefox_wrapper() {
  print_msg "$BLUE" "Setting up Firefox wrapper script..."
  
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
  
  print_msg "$GREEN" "Firefox wrapper configured for WSL."
}

# Main function for browser installation
main() {
  # Check internet connection
  check_internet
  
  # Optimize apt settings
  optimize_apt
  
  # Clean up existing repos BEFORE initial update
  cleanup_existing_repos
  
  # Update system
  print_msg "$BLUE" "Updating system package lists..."
  check_apt_lock
  sudo apt-get update -qq
  
  # Uninstall existing browsers and Visual Studio Code
  local packages_to_uninstall=(
    "google-chrome-stable" "google-chrome-beta" "google-chrome-unstable" 
    "microsoft-edge-stable" "microsoft-edge-beta" "microsoft-edge-dev"
    "opera-stable" "brave-browser" "firefox" "code"
  )
  
  for pkg in "${packages_to_uninstall[@]}"; do
    uninstall_if_installed "$pkg"
  done
  
  # Run a final cleanup to ensure everything is clean before adding new repos
  cleanup_existing_repos
  check_apt_lock
  sudo apt-get autoremove -y -qq
  
  # Install dependencies
  install_package "dependencies" wget gnupg apt-transport-https curl ca-certificates lsb-release
  
  # Create an array of repositories to add - only with stable versions to avoid errors
  declare -A repositories=(
    ["google-chrome"]="https://dl.google.com/linux/linux_signing_key.pub|deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main|"
    ["microsoft-edge"]="https://packages.microsoft.com/keys/microsoft.asc|deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main|/usr/share/keyrings/microsoft-edge.gpg"
    ["opera-stable"]="https://deb.opera.com/archive.key|deb https://deb.opera.com/opera-stable/ stable non-free|"
    ["brave-browser"]="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg|deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main|/usr/share/keyrings/brave-browser-archive-keyring.gpg"
    ["vscode"]="https://packages.microsoft.com/keys/microsoft.asc|deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main|/usr/share/keyrings/packages.microsoft.gpg"
  )
  
  # Add repositories sequentially instead of in parallel
  for repo in "${!repositories[@]}"; do
    debug_msg "Processing repository: $repo"
    IFS='|' read -r key_url repo_entry key_file <<< "${repositories[$repo]}"
    
    # Try to add repository with timeout protection
    if add_repository "$repo" "$key_url" "$repo_entry" "$key_file"; then
      debug_msg "Successfully added repository: $repo"
    else
      print_msg "$RED" "Failed to add repository: $repo - continuing with others"
    fi
    
    # Brief pause between repositories to avoid overwhelming servers
    sleep 2
  done
  
  # Wait for any possible background processes
  wait
  
  # Update package lists after adding all repositories
  print_msg "$BLUE" "Updating package lists after adding repositories..."
  debug_msg "Running apt-get update with timeout of 60 seconds"
  echo "This might take a few moments... "

  # Add verbose output for apt-get update and use a timeout
  if ! timeout 60 sudo apt-get update -q; then
    print_msg "$RED" "Full apt-get update timed out or failed. Trying simplified update..."
    # Try with less features enabled
    debug_msg "Attempting update with Acquire::GzipIndexes=false"
    if ! timeout 60 sudo apt-get update -o Acquire::GzipIndexes=false -o Acquire::ForceIPv4=true -q; then
      print_msg "$RED" "Update still failing. Installing only Firefox and essential utilities."
      # Fall back to installing just Firefox and essentials
      sudo apt-get update --allow-releaseinfo-change -o Acquire::Languages=none -q || true
      print_msg "$BLUE" "Installing Firefox and essential utilities only..."
      install_package "Firefox" firefox
      install_package "Konsole" konsole
      install_package "PulseAudio" pulseaudio
      install_package "dos2unix" dos2unix
      
      # Skip to Firefox setup
      goto_firefox_setup=true
    fi
  fi

  # Variable to control flow
  goto_firefox_setup=${goto_firefox_setup:-false}

  if [ "$goto_firefox_setup" = false ]; then
    # Install browsers - only stable versions to ensure availability
    debug_msg "Starting browser installations"
    print_msg "$BLUE" "Installing Google Chrome (Stable)..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable; then
      print_msg "$RED" "Failed to install Google Chrome. Continuing with other browsers."
    else
      print_msg "$GREEN" "Google Chrome (Stable) installed."
    fi
    
    # Install Microsoft Edge (Stable only to avoid repository conflicts)
    print_msg "$BLUE" "Installing Microsoft Edge (Stable)..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y microsoft-edge-stable; then
      print_msg "$RED" "Failed to install Microsoft Edge. Continuing with other browsers."
    else
      print_msg "$GREEN" "Microsoft Edge (Stable) installed."
    fi
    
    # Install Opera Browser without interruptions
    print_msg "$BLUE" "Installing Opera Browser..."
    echo "opera-stable opera-stable/add-deb-source boolean true" | sudo debconf-set-selections
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y opera-stable; then
      print_msg "$RED" "Failed to install Opera. Continuing with other browsers."
    else
      print_msg "$GREEN" "Opera Browser installed."
    fi
    
    # Install Brave Browser
    print_msg "$BLUE" "Installing Brave Browser..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser; then
      print_msg "$RED" "Failed to install Brave Browser. Continuing with other browsers."
    else
      print_msg "$GREEN" "Brave Browser installed."
    fi
    
    # Install Firefox
    print_msg "$BLUE" "Installing Firefox..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y firefox; then
      print_msg "$RED" "Failed to install Firefox. This is a critical failure."
      exit 1
    else
      print_msg "$GREEN" "Firefox installed."
    fi
    
    # Install additional utilities
    print_msg "$BLUE" "Installing Konsole..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y konsole; then
      print_msg "$RED" "Failed to install Konsole. Continuing with other utilities."
    else
      print_msg "$GREEN" "Konsole installed."
    fi
    
    print_msg "$BLUE" "Installing PulseAudio..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pulseaudio; then
      print_msg "$RED" "Failed to install PulseAudio. Continuing with other utilities."
    else
      print_msg "$GREEN" "PulseAudio installed."
    fi
    
    print_msg "$BLUE" "Installing dos2unix..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dos2unix; then
      print_msg "$RED" "Failed to install dos2unix. Continuing with other utilities."
    else
      print_msg "$GREEN" "dos2unix installed."
    fi
    
    print_msg "$BLUE" "Installing Visual Studio Code..."
    if ! timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y code; then
      print_msg "$RED" "Failed to install Visual Studio Code. Continuing with setup."
    else
      print_msg "$GREEN" "Visual Studio Code installed."
    fi
  fi
  
  # Confirm installations and show paths
  print_msg "$BLUE" "Confirming installations and showing paths..."
  local apps=(
    google-chrome-stable microsoft-edge-stable opera brave-browser firefox konsole pulseaudio dos2unix code
  )
  
  # Set up Firefox wrapper regardless of installation method
  setup_firefox_wrapper
  
  # Verify installations
  local installation_success=false
  for app in "${apps[@]}"; do
    if command -v "$app" &>/dev/null; then
      print_msg "$GREEN" "$app installed successfully."
      echo "$app path: $(command -v "$app")"
      installation_success=true
    else
      print_msg "$RED" "$app installation failed or not found in PATH."
    fi
  done
  
  # At minimum, ensure Firefox is installed
  if ! command -v firefox &>/dev/null; then
    print_msg "$RED" "WARNING: Firefox installation could not be verified. Attempting emergency installation..."
    sudo apt-get update -q || true
    sudo apt-get install -y firefox || true
    
    if command -v firefox &>/dev/null; then
      print_msg "$GREEN" "Emergency Firefox installation succeeded."
      installation_success=true
    else
      print_msg "$RED" "Emergency Firefox installation failed. Please install manually with: sudo apt-get install firefox"
    fi
  fi
  
  # Cleanup
  print_msg "$BLUE" "Cleaning up..."
  sudo apt-get clean
  sudo apt-get autoremove -y -qq
  
  # Remove optimizations to not interfere with system
  sudo rm -f /etc/apt/apt.conf.d/99custom
  
  if [ "$installation_success" = true ]; then
    print_msg "$GREEN" "Installation completed at $(date)"
  else
    print_msg "$RED" "Installation completed with errors at $(date)"
    print_msg "$RED" "Please try installing browsers manually using: sudo apt-get install firefox"
  fi
}

# Run the main function
main 