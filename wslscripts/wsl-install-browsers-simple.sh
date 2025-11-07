#!/bin/bash

# Set strict error handling
set -euo pipefail

# Configuration
LOG_FILE="/tmp/browser_install_simple.log"
TIMEOUT=15

# Log setup
echo "Installation started at $(date)"

# Colors for terminal output
GREEN="\e[32m"
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

# Function to print colored messages
print_msg() {
  local color="$1"
  local msg="$2"
  echo -e "${color}${msg}${RESET}"
}

# Function to check internet connection (with timeout)
check_internet() {
  print_msg "$BLUE" "Checking internet connection..."
  if timeout $TIMEOUT wget -q --spider http://google.com; then
    print_msg "$GREEN" "Internet connection is active."
  else
    print_msg "$RED" "No internet connection detected. Please check your connection and try again."
    exit 1
  fi
}

# Function to install a package or packages
install_package() {
  local name="$1"
  shift
  local packages=("$@")
  
  print_msg "$BLUE" "Installing $name..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" -qq
  print_msg "$GREEN" "$name installed."
}

# Main function
main() {
  # Check internet connection
  check_internet
  
  # Update system
  print_msg "$BLUE" "Updating system package lists..."
  sudo apt-get update -qq
  
  # Install Firefox and essential packages
  install_package "Firefox" firefox
  install_package "Konsole" konsole
  install_package "PulseAudio" pulseaudio
  install_package "dos2unix" dos2unix
  
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
  
  print_msg "$GREEN" "Firefox installed and configured for WSL."
  
  # Confirm installations and show paths
  print_msg "$BLUE" "Confirming installations and showing paths..."
  local apps=(
    firefox konsole pulseaudio dos2unix
  )
  
  for app in "${apps[@]}"; do
    if command -v "$app" &>/dev/null; then
      print_msg "$GREEN" "$app installed successfully."
      echo "$app path: $(command -v "$app")"
    else
      print_msg "$RED" "$app installation failed or not found in PATH."
    fi
  done
  
  # Cleanup
  print_msg "$BLUE" "Cleaning up..."
  sudo apt-get clean
  sudo apt-get autoremove -y -qq
  
  print_msg "$GREEN" "Installation completed at $(date)"
}

# Run the main function
main 