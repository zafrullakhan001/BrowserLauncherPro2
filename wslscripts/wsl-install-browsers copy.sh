#!/bin/bash

# Add at the beginning of the script
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

# Function to print messages in green
print_green() {
  echo -e "\e[32m$1\e[0m"
}

# Function to check internet connection
check_internet() {
  echo "Checking internet connection..."
  wget -q --spider http://google.com
  if [ $? -eq 0 ]; then
    print_green "Internet connection is active."
  else
    echo "No internet connection detected. Please check your connection and try again."
    exit 1
  fi
}

# Function to uninstall a package if it's installed
uninstall_if_installed() {
  if dpkg -l | grep -q "$1"; then
    echo "Uninstalling $1..."
    sudo apt-get remove -y "$1" >/dev/null 2>&1
    print_green "$1 uninstalled."
  else
    echo "$1 is not installed, skipping uninstallation."
  fi
}

# Check internet connection
check_internet

# Update and upgrade system
echo "Updating and upgrading system..."
sudo apt-get update -qq && sudo apt-get upgrade -y -qq

# Uninstall existing browsers and Visual Studio Code
uninstall_if_installed google-chrome-stable
uninstall_if_installed google-chrome-beta
uninstall_if_installed google-chrome-unstable
uninstall_if_installed microsoft-edge-stable
uninstall_if_installed microsoft-edge-beta
uninstall_if_installed microsoft-edge-dev
uninstall_if_installed opera-stable
uninstall_if_installed brave-browser
uninstall_if_installed firefox
uninstall_if_installed code

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
} && print_green "Google Chrome installed."

# Install Microsoft Edge (Stable, Beta, Dev)
echo "Installing Microsoft Edge..."
{
  wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - >/dev/null 2>&1
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge beta main" | sudo tee /etc/apt/sources.list.d/microsoft-edge-beta.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev -qq
} && print_green "Microsoft Edge installed."

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
} && print_green "Opera Browser installed."

# Install Brave Browser with preferred method
echo "Installing Brave Browser..."
{
  sudo apt-get install curl -y -qq
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y brave-browser -qq
} && print_green "Brave Browser installed."

# Install Firefox
echo "Installing Firefox..."
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
  
  print_green "Firefox installed and configured for WSL."
} && print_green "Firefox installed."

# Install Konsole
echo "Installing Konsole..."
{
  sudo apt-get install -y konsole -qq
} && print_green "Konsole installed."

# Install PulseAudio
echo "Installing PulseAudio..."
{
  sudo apt-get install -y pulseaudio -qq
} && print_green "PulseAudio installed."

# Install dos2unix
echo "Installing dos2unix..."
{
  sudo apt-get install -y dos2unix -qq
} && print_green "dos2unix installed."

# Install Visual Studio Code
echo "Installing Visual Studio Code..."
{
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y code -qq
} && print_green "Visual Studio Code installed."

# Confirm installations and show paths
echo "Confirming installations and showing paths..."
for app in google-chrome-stable google-chrome-beta google-chrome-unstable microsoft-edge-stable microsoft-edge-beta microsoft-edge-dev opera brave-browser firefox konsole pulseaudio dos2unix code; do
  if command -v $app &>/dev/null; then
    print_green "$app installed successfully."
    echo "$app path: $(command -v $app)"
  else
    echo "$app is not installed."
  fi
done

# Add near the end of the script
cleanup() {
  echo "Cleaning up..."
  sudo apt-get clean
  sudo apt-get autoremove -y
}

# Call the function at the end
cleanup

# Add at the end of the script
echo "Installation completed at $(date)"