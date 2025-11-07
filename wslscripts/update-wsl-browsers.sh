#!/bin/bash
# Update browsers in WSL
# This script updates all installed browsers in a WSL environment

# Function to print messages
print_message() {
  local message="$1"
  echo "$message"
}

# Function to get system information
get_system_info() {
  echo "System Information:"
  echo "------------------"
  if [ -f /etc/os-release ]; then
    echo "Distribution: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \")"
  else
    echo "Distribution: Unknown"
  fi
  echo "Kernel: $(uname -r)"
  echo "CPU: $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')"
  echo "CPU Cores: $(nproc)"
  echo "Memory: $(free -h | grep Mem | awk '{print $2}') total, $(free -h | grep Mem | awk '{print $3}') used"
  echo "Uptime: $(uptime -p)"
  echo
}

# Function to get disk information
get_disk_info() {
  echo "Disk Information:"
  echo "----------------"
  df -h / | awk 'NR==2 {print "Root FS: " $2 " total, " $3 " used, " $4 " free (" $5 " used)"}'
  echo
}

# Function to create a formatted table
create_table() {
  local data=("$@")
  local max_app=25 max_status=12 max_version=20 max_path=40
  
  # Calculate maximum lengths
  for row in "${data[@]}"; do
    IFS='|' read -r app status version path <<< "$row"
    ((${#app} > max_app)) && max_app=${#app}
    ((${#status} > max_status)) && max_status=${#status}
    ((${#version} > max_version)) && max_version=${#version}
    ((${#path} > max_path)) && max_path=${#path}
  done
  
  # Create separator line
  local total_width=$((max_app + max_status + max_version + max_path + 13))
  local separator=$(printf '%*s' "$total_width" | tr ' ' '-')
  
  # Print header
  echo "+"$separator"+"
  printf "| %-*s | %-*s | %-*s | %-*s |\n" "$max_app" "Application" "$max_status" "Status" "$max_version" "Version" "$max_path" "Path"
  echo "+"$separator"+"
  
  # Print data rows
  for row in "${data[@]}"; do
    IFS='|' read -r app status version path <<< "$row"
    printf "| %-*s | %-*s | %-*s | %-*s |\n" "$max_app" "$app" "$max_status" "$status" "$max_version" "$version" "$max_path" "$path"
  done
  
  # Print footer
  echo "+"$separator"+"
}

# Function to format time
format_time() {
  local seconds=$1
  local hours=$((seconds/3600))
  local minutes=$(( (seconds%3600)/60 ))
  local secs=$((seconds%60))
  printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Function to check for OS updates
check_os_updates() {
  echo "Checking for OS updates..."
  echo "-------------------------"
  
  # Check for available updates
  UPDATE_INFO=$(apt list --upgradable 2>/dev/null)
  if [ -n "$UPDATE_INFO" ]; then
    # Count the number of updates (excluding the header line)
    UPDATE_COUNT=$(echo "$UPDATE_INFO" | grep -c "upgradable" -)
    
    echo "Found $UPDATE_COUNT packages that can be updated:"
    echo "$UPDATE_INFO" | grep "upgradable" | head -5
    if [ $UPDATE_COUNT -gt 5 ]; then
      echo "... and $((UPDATE_COUNT - 5)) more packages"
    fi
    
    # Calculate total size of updates
    TOTAL_SIZE=$(apt-get -s upgrade | grep "upgraded" | awk '{print $1}')
    echo "Total size of updates: $TOTAL_SIZE"
    
    return 0
  else
    echo "No OS updates available."
    return 1
  fi
}

# Function to perform OS updates
perform_os_updates() {
  echo "Starting OS updates..."
  echo "---------------------"
  
  # Record start time
  UPDATE_START_TIME=$(date +%s)
  
  # Perform the update
  if sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; then
    UPDATE_END_TIME=$(date +%s)
    UPDATE_TIME=$((UPDATE_END_TIME - UPDATE_START_TIME))
    echo "OS updates completed successfully in $(format_time $UPDATE_TIME)"
    return 0
  else
    echo "Failed to complete OS updates"
    return 1
  fi
}

clear
echo "================================================================"
echo "  WSL Browser Update Script"
echo "================================================================"
echo

# Record start time
START_TIME=$(date +%s)

# Display initial system information
echo "Initial System Status:"
echo "====================="
get_system_info
get_disk_info

# Clean up duplicate repository entries
echo "Cleaning up repository configuration..."
# Back up sources.list.d
mkdir -p /tmp/sources-backup
sudo cp -r /etc/apt/sources.list.d/* /tmp/sources-backup/ 2>/dev/null || true

# Update package repositories with error handling
echo "Updating package lists..."
(sudo apt-get update -y >/dev/null 2>/tmp/apt-error.log) || {
  # If update fails, check if it's just warnings
  if grep -q "^E:" /tmp/apt-error.log; then
    echo "Error updating package lists:"
    grep "^E:" /tmp/apt-error.log
    echo
    echo "Continuing anyway..."
  else
    echo "There were some warnings, but we can continue:"
    grep "^W:" /tmp/apt-error.log | head -3
    echo "(More warnings omitted)"
  fi
}
echo "Package lists updated."
echo

# Define ALL browser packages to check and update
BROWSERS=(
  "google-chrome-stable"
  "google-chrome-beta"
  "google-chrome-unstable"
  "microsoft-edge-stable"
  "microsoft-edge-beta"
  "microsoft-edge-dev"
  "brave-browser"
  "firefox"
  "opera-stable"
  "opera"
)

# Define additional utility packages
UTILITIES=(
  "code"
  "konsole"
  "pulseaudio"
  "dos2unix"
)

# Check which browsers are installed and update them
echo "Checking installed browsers..."
UPDATED=0
BROWSER_TABLE=()

# Process browsers
for browser in "${BROWSERS[@]}"; do
  # Handle special cases for package/command name differences
  COMMAND_NAME=""
  PACKAGE_NAME=""
  
  case "$browser" in
    "microsoft-edge-stable") 
      COMMAND_NAME="microsoft-edge"
      PACKAGE_NAME="microsoft-edge-stable"
      ;;
    "google-chrome-stable") 
      COMMAND_NAME="google-chrome"
      PACKAGE_NAME="google-chrome-stable"
      ;;
    "opera-stable") 
      COMMAND_NAME="opera"
      PACKAGE_NAME="opera-stable"
      ;;
    *)
      COMMAND_NAME="$browser"
      PACKAGE_NAME="$browser"
      ;;
  esac
  
  # Check if command exists (binary is installed)
  if which "$COMMAND_NAME" > /dev/null 2>&1; then
    # Check if package is actually installed (for proper version and update checks)
    if dpkg -l | grep -q "^ii.*$PACKAGE_NAME "; then
      CURRENT_VERSION=$(dpkg -l | grep "^ii.*$PACKAGE_NAME " | awk '{print $3}')
      echo "- $browser (current version: $CURRENT_VERSION)"
      
      echo "Updating $browser..."
      PACKAGE_START_TIME=$(date +%s)
      if sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "$PACKAGE_NAME"; then
        PACKAGE_END_TIME=$(date +%s)
        PACKAGE_TIME=$((PACKAGE_END_TIME - PACKAGE_START_TIME))
        NEW_VERSION=$(dpkg -l | grep "^ii.*$PACKAGE_NAME " | awk '{print $3}')
        if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
          echo "$browser updated from $CURRENT_VERSION to $NEW_VERSION (took $(format_time $PACKAGE_TIME))"
          # Update stats
          STATUS="Updated"
        else
          echo "$browser is already at the latest version: $CURRENT_VERSION (checked in $(format_time $PACKAGE_TIME))"
          # Update stats
          STATUS="Up-to-date"
        fi
        
        # Add to report table
        PATH_INFO=$(which "$COMMAND_NAME" 2>/dev/null || echo "N/A")
        BROWSER_TABLE+=("$browser|$STATUS|$NEW_VERSION|$PATH_INFO")
        UPDATED=$((UPDATED+1))
      else
        echo "Failed to update $browser"
        # Add to report table
        PATH_INFO=$(which "$COMMAND_NAME" 2>/dev/null || echo "N/A")
        BROWSER_TABLE+=("$browser|Failed|$CURRENT_VERSION|$PATH_INFO")
      fi
      echo
    else
      # Command exists but package not found - likely installed via other means
      echo "$browser package not found in dpkg, but command exists at: $(which $COMMAND_NAME)"
      
      # Try alternative method to get version
      CURRENT_VERSION=$($COMMAND_NAME --version 2>/dev/null | head -n 1)
      if [ -z "$CURRENT_VERSION" ]; then
        CURRENT_VERSION="Unknown"
      fi
      
      echo "Current version: $CURRENT_VERSION (Cannot update without package manager entry)"
      BROWSER_TABLE+=("$browser|Not Managed|$CURRENT_VERSION|$(which $COMMAND_NAME)")
    fi
  elif dpkg -l | grep -q "^ii.*$PACKAGE_NAME "; then
    # Package installed but command not found (unusual situation)
    CURRENT_VERSION=$(dpkg -l | grep "^ii.*$PACKAGE_NAME " | awk '{print $3}')
    echo "- $browser package installed (version: $CURRENT_VERSION) but command not found"
    
    echo "Updating $browser..."
    PACKAGE_START_TIME=$(date +%s)
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "$PACKAGE_NAME"; then
      PACKAGE_END_TIME=$(date +%s)
      PACKAGE_TIME=$((PACKAGE_END_TIME - PACKAGE_START_TIME))
      NEW_VERSION=$(dpkg -l | grep "^ii.*$PACKAGE_NAME " | awk '{print $3}')
      if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
        echo "$browser updated from $CURRENT_VERSION to $NEW_VERSION (took $(format_time $PACKAGE_TIME))"
        STATUS="Updated"
      else
        echo "$browser is already at the latest version: $CURRENT_VERSION (checked in $(format_time $PACKAGE_TIME))"
        STATUS="Up-to-date"
      fi
      
      BROWSER_TABLE+=("$browser|$STATUS|$NEW_VERSION|Not in PATH")
      UPDATED=$((UPDATED+1))
    else
      echo "Failed to update $browser"
      BROWSER_TABLE+=("$browser|Failed|$CURRENT_VERSION|Not in PATH")
    fi
    echo
  else
    # Check if the command exists even if the package isn't found (direct binary check)
    PATH_INFO=$(which "$COMMAND_NAME" 2>/dev/null || echo "")
    if [ -n "$PATH_INFO" ]; then
      echo "$browser package not found, but command exists at: $PATH_INFO"
      
      # Try to get version information
      VERSION_INFO=$($COMMAND_NAME --version 2>/dev/null | head -n 1 || echo "Unknown")
      BROWSER_TABLE+=("$browser|Installed*|$VERSION_INFO|$PATH_INFO")
    else
      echo "$browser is not installed"
      BROWSER_TABLE+=("$browser|Not Installed|N/A|N/A")
    fi
  fi
done

# Update utilities with detailed output
echo "Checking and updating utility packages..."
for util in "${UTILITIES[@]}"; do
  if dpkg -l | grep -q "^ii.*$util "; then
    CURRENT_VERSION=$(dpkg -l | grep "^ii.*$util " | awk '{print $3}')
    echo "Updating $util..."
    
    PACKAGE_START_TIME=$(date +%s)
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "$util"; then
      PACKAGE_END_TIME=$(date +%s)
      PACKAGE_TIME=$((PACKAGE_END_TIME - PACKAGE_START_TIME))
      NEW_VERSION=$(dpkg -l | grep "^ii.*$util " | awk '{print $3}')
      PATH_INFO=$(which "$util" 2>/dev/null || echo "N/A")
      
      if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
        echo "$util updated from $CURRENT_VERSION to $NEW_VERSION (took $(format_time $PACKAGE_TIME))"
        STATUS="Updated"
      else
        echo "$util is already at the latest version: $CURRENT_VERSION (checked in $(format_time $PACKAGE_TIME))"
        STATUS="Up-to-date"
      fi
      
      BROWSER_TABLE+=("$util|$STATUS|$NEW_VERSION|$PATH_INFO")
    else
      echo "Failed to update $util"
      BROWSER_TABLE+=("$util|Failed|$CURRENT_VERSION|$PATH_INFO")
    fi
    echo
  elif which "$util" > /dev/null 2>&1; then
    # Command exists but package not found - likely installed via other means
    echo "$util package not found in dpkg, but command exists at: $(which $util)"
    CURRENT_VERSION=$($util --version 2>/dev/null | head -n 1 || echo "Unknown")
    BROWSER_TABLE+=("$util|Not Managed|$CURRENT_VERSION|$(which $util)")
  else
    echo "$util is not installed"
    BROWSER_TABLE+=("$util|Not Installed|N/A|N/A")
  fi
done

# Record end time and calculate total duration
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

# Check if any browsers were updated
if [ $UPDATED -eq 0 ]; then
  echo "No browsers were found or updated."
  echo "You may need to install browsers first using:"
  echo "sudo apt-get install google-chrome-stable microsoft-edge-stable brave-browser firefox opera-stable"
else
  echo "Browser update process completed. Updated $UPDATED browser(s)."
fi

echo
echo "Final System Status:"
echo "==================="
get_system_info
get_disk_info

echo "Browser Status Report"
echo "===================="
echo

# Generate the table
create_table "${BROWSER_TABLE[@]}"

echo
echo "Update Summary:"
echo "--------------"
echo "Total time taken: $(format_time $TOTAL_TIME)"
echo "Total packages checked: ${#BROWSERS[@]} browsers + ${#UTILITIES[@]} utilities"
echo "Packages updated: $UPDATED"
echo

# Check for OS updates
if check_os_updates; then
  echo "Would you like to update the OS packages? (y/n)"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    if perform_os_updates; then
      echo
      echo "Final System Status After OS Updates:"
      echo "==================================="
      get_system_info
      get_disk_info
    fi
  else
    echo "Skipping OS updates."
  fi
fi

echo
echo "Done!"
echo "Press Enter to exit..."
read dummy || true 