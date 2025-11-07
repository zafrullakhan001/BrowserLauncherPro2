#!/bin/bash

# Simple script to install Firefox and essential utilities directly
echo "Installing Firefox and essential utilities..."

# Update package database
sudo apt-get update -q

# Install Firefox and essential utilities
sudo apt-get install -y firefox konsole pulseaudio dos2unix

# Set up Firefox wrapper script
echo "Setting up Firefox wrapper script..."
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

echo "Firefox installed and configured for WSL."
echo "You can now run Firefox by typing 'firefox' in the terminal." 