#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Updates web browsers (Edge, Chrome, Brave, Firefox, Opera) in WSL instances.
.DESCRIPTION
    This script automates the update process for web browsers installed in WSL instances.
    It executes the appropriate update commands within each WSL distribution.
.NOTES
    Requires administrative privileges and WSL to be installed.
#>

# Wrap everything in try/catch to ensure we always show the summary
try {
    # Function to check if running as administrator
    function Test-Admin {
        $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Function to check if WSL is installed
    function Test-WSLInstalled {
        try {
            # Try multiple methods to verify WSL installation
            Write-Host "Checking if WSL is installed..." -ForegroundColor Yellow
            
            # Method 1: Check using wsl --status
            $wslStatusOutput = wsl --status 2>&1
            $statusResult = -not ($wslStatusOutput -match "not found" -or $wslStatusOutput -match "not recognized")
            Write-Host "  WSL status check result: $statusResult" -ForegroundColor Gray
            
            # Method 2: Check using wsl --version
            $wslVersionOutput = wsl --version 2>&1
            $versionResult = -not ($wslVersionOutput -match "not found" -or $wslVersionOutput -match "not recognized")
            Write-Host "  WSL version check result: $versionResult" -ForegroundColor Gray
            
            # Method 3: Check if WSL feature is enabled
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux 2>$null
            $featureResult = $wslFeature -and $wslFeature.State -eq "Enabled"
            Write-Host "  WSL Windows feature check result: $featureResult" -ForegroundColor Gray
            
            # Return true if any method succeeds
            $isInstalled = $statusResult -or $versionResult -or $featureResult
            if ($isInstalled) {
                Write-Host "WSL installation check result: $isInstalled" -ForegroundColor Green
            } else {
                Write-Host "WSL installation check result: $isInstalled" -ForegroundColor Red
            }
            return $isInstalled
        }
        catch {
            Write-Host "Error checking WSL installation: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    # Function to get all installed WSL instances
    function Get-WSLInstances {
        try {
            # Try different methods to get WSL instances
            Write-Host "Attempting to get WSL instances..." -ForegroundColor Yellow
            
            # Method 1: Use wsl --list --verbose
            Write-Host "Method 1: Using 'wsl --list --verbose'" -ForegroundColor Gray
            $wslOutput = wsl --list --verbose 2>&1
            Write-Host "  Raw output from wsl --list --verbose:" -ForegroundColor Gray
            $wslOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            
            # Better parsing of the WSL list output
            $instances = @()
            $lines = $wslOutput -split "`n" | Where-Object { $_ -match "\S" }
            
            # Skip the header line if present
            $startIndex = if ($lines[0] -match "NAME|STATE|VERSION") { 1 } else { 0 }
            
            for ($i = $startIndex; $i -lt $lines.Count; $i++) {
                $line = $lines[$i].Trim()
                Write-Host "  Processing line: $line" -ForegroundColor Gray
                
                # Different regex patterns to handle various formats
                if ($line -match '^\*?\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                    # Standard format: NAME STATE VERSION
                    $name = $Matches[1]
                    $state = $Matches[2]
                    $version = $Matches[3]
                    Write-Host "    Standard format match: Name=$name, State=$state, Version=$version" -ForegroundColor Gray
                }
                elseif ($line -match '^\*?\s*([^\s]+)') {
                    # Simplified format: just NAME (assume Running and Version 2)
                    $name = $Matches[1]
                    $state = "Running"
                    $version = "2"
                    Write-Host "    Simple format match: Name=$name (assuming State=Running, Version=2)" -ForegroundColor Gray
                }
                else {
                    # Skip lines we can't parse
                    Write-Host "    Could not parse line, skipping" -ForegroundColor Yellow
                    continue
                }
                
                # Skip default entry indicated by a * and clean up the name
                $name = $name -replace '^\*', ''
                
                if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne "*") {
                    $instances += [PSCustomObject]@{
                        Name = $name
                        State = $state
                        Version = $version
                    }
                    Write-Host "    Added instance: $name" -ForegroundColor Green
                }
                else {
                    Write-Host "    Skipped invalid instance name: $name" -ForegroundColor Yellow
                }
            }
            
            # Method 2: Alternative approach if no instances found
            if ($instances.Count -eq 0) {
                Write-Host "Method 2: Trying alternative approach with 'wsl -l'" -ForegroundColor Gray
                $wslSimpleList = wsl -l 2>&1
                Write-Host "  Raw output from wsl -l:" -ForegroundColor Gray
                $wslSimpleList | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                
                $simpleLines = $wslSimpleList -split "`n" | Where-Object { $_ -match "\S" }
                $startIdx = if ($simpleLines[0] -match "NAME|DISTRO") { 1 } else { 0 }
                
                for ($i = $startIdx; $i -lt $simpleLines.Count; $i++) {
                    $line = $simpleLines[$i].Trim()
                    Write-Host "  Processing simple line: $line" -ForegroundColor Gray
                    
                    if ($line -match '^\*?\s*([^\s]+)') {
                        $name = $Matches[1] -replace '^\*', ''
                        
                        if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne "*") {
                            $instances += [PSCustomObject]@{
                                Name = $name
                                State = "Unknown"
                                Version = "Unknown"
                            }
                            Write-Host "    Added instance (simple method): $name" -ForegroundColor Green
                        }
                    }
                }
            }
            
            # Method 3: Try to detect Ubuntu directly as a last resort
            if ($instances.Count -eq 0) {
                Write-Host "Method 3: Checking for Ubuntu directly" -ForegroundColor Gray
                $ubuntuDistros = @("Ubuntu", "Ubuntu-20.04", "Ubuntu-22.04", "Ubuntu-18.04")
                
                foreach ($distro in $ubuntuDistros) {
                    try {
                        $testOutput = wsl -d $distro -e echo "Testing $distro" 2>&1
                        $testSuccess = $testOutput -match "Testing $distro"
                        
                        if ($testSuccess) {
                            Write-Host "    Found working Ubuntu distribution: $distro" -ForegroundColor Green
                            $instances += [PSCustomObject]@{
                                Name = $distro
                                State = "Running"
                                Version = "Unknown"
                            }
                        }
                    }
                    catch {
                        Write-Host "    Failed to detect $distro: $($_.Exception.Message)" -ForegroundColor Gray
                    }
                }
            }
            
            # Final validation and debugging output
            Write-Host "Found WSL instances:" -ForegroundColor Cyan
            if ($instances.Count -eq 0) {
                Write-Host "  No valid WSL instances found." -ForegroundColor Yellow
                Write-Host "  Please verify your WSL installation by running 'wsl --list' in a command prompt." -ForegroundColor Yellow
            } else {
                foreach ($instance in $instances) {
                    Write-Host "  - $($instance.Name) (State: $($instance.State), Version: $($instance.Version))" -ForegroundColor Green
                }
            }
            
            return $instances
        }
        catch {
            Write-Host "Error getting WSL instances: $($_.Exception.Message)" -ForegroundColor Red
            return @()
        }
    }

    # Function to update browsers in a specific WSL instance
    function Update-BrowsersInWSL {
        param (
            [string]$InstanceName
        )
        
        # Validate the instance name
        if ([string]::IsNullOrWhiteSpace($InstanceName) -or $InstanceName -eq "*") {
            Write-Host "Invalid WSL instance name: '$InstanceName'" -ForegroundColor Red
            return $false
        }
        
        Write-Host "`nUpdating browsers in WSL instance: $InstanceName" -ForegroundColor Yellow
        
        # Check if the instance is running
        $instances = Get-WSLInstances
        $instance = $instances | Where-Object { $_.Name -eq $InstanceName }
        
        if (-not $instance) {
            Write-Host "WSL instance '$InstanceName' not found." -ForegroundColor Red
            return $false
        }
        
        # Start the instance if it's not running
        if ($instance.State -ne "Running") {
            Write-Host "Starting WSL instance '$InstanceName'..." -ForegroundColor Yellow
            try {
                wsl -d $InstanceName -e echo "Starting WSL..." > $null
            }
            catch {
                Write-Host "Error starting WSL instance '$InstanceName': $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
        
        # Create the update script content
        $updateScript = @'
#!/bin/bash
# Browser Update Script for WSL

# Set up colors
GREEN="\033[32m"
BLUE="\033[34m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# Function to print colored messages
print_msg() {
  local color="$1"
  local msg="$2"
  echo -e "${color}${msg}${RESET}"
}

# Function to update apt repositories
update_repos() {
  print_msg "$BLUE" "Updating package repositories..."
  sudo apt-get update -qq
  print_msg "$GREEN" "Package repositories updated."
}

# Function to upgrade a package if it's installed
upgrade_if_installed() {
  if dpkg -l | grep -q "^ii.*$1 "; then
    print_msg "$BLUE" "Updating $1..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "$1"
    print_msg "$GREEN" "$1 updated."
    return 0
  else
    print_msg "$YELLOW" "$1 is not installed, skipping."
    return 1
  fi
}

print_msg "$BLUE" "Starting browser updates in WSL..."

# Update package repositories
update_repos

# Array of browser packages to update
browsers=("google-chrome-stable" "microsoft-edge-stable" "brave-browser" "firefox" "opera-stable")

# Track successful updates
updated_browsers=()
failed_browsers=()

# Update each browser
for browser in "${browsers[@]}"; do
  if upgrade_if_installed "$browser"; then
    updated_browsers+=("$browser")
  else
    failed_browsers+=("$browser")
  fi
done

# Summary
print_msg "$BLUE" "\n====== BROWSER UPDATE SUMMARY ======" 
print_msg "$BLUE" "Updated browsers:" 
if [ ${#updated_browsers[@]} -eq 0 ]; then
  print_msg "$YELLOW" "  No browsers were updated"
else
  for browser in "${updated_browsers[@]}"; do
    print_msg "$GREEN" "  $browser"
  done
fi

print_msg "$BLUE" "Browsers not installed:" 
if [ ${#failed_browsers[@]} -eq 0 ]; then
  print_msg "$YELLOW" "  All browsers are installed"
else
  for browser in "${failed_browsers[@]}"; do
    print_msg "$YELLOW" "  $browser"
  done
fi

print_msg "$BLUE" "====== END OF SUMMARY ======" 
'@
        
        # Execute the update script in the WSL instance
        try {
            # First check if sudo requires a password
            Write-Host "Checking if sudo requires a password in WSL instance '$InstanceName'..." -ForegroundColor Yellow
            $sudoCheck = wsl -d $InstanceName -e bash -c "sudo -n true 2>/dev/null && echo 'sudo_ok' || echo 'sudo_password_required'"
            
            if ($sudoCheck -eq "sudo_password_required") {
                Write-Host "Sudo requires a password in the WSL instance. Please provide your password when prompted." -ForegroundColor Yellow
                Write-Host "Note: The password prompt may appear in a separate console window." -ForegroundColor Yellow
                
                # Create a simple script to request the password and then run the update script
                $passwordScript = @'
#!/bin/bash
echo "Enter your sudo password for the WSL instance:"
sudo echo "Password accepted. Starting browser updates..."
'@
                $tempPasswordScript = [System.IO.Path]::GetTempFileName()
                $passwordScript | Set-Content -Path $tempPasswordScript -Encoding ASCII
                
                # Execute the password script
                $passwordCheck = Get-Content -Path $tempPasswordScript -Raw | wsl -d $InstanceName -e bash -c "cat > /tmp/password_check.sh && chmod +x /tmp/password_check.sh && /tmp/password_check.sh"
                
                if (Test-Path $tempPasswordScript) {
                    Remove-Item -Path $tempPasswordScript -Force
                }
            }
            
            # Now run the actual update script
            # Create a temporary file with the bash script
            $tempScript = [System.IO.Path]::GetTempFileName()
            $updateScript | Set-Content -Path $tempScript -Encoding ASCII
            
            Write-Host "Executing update script in WSL instance '$InstanceName'..." -ForegroundColor Yellow
            # Execute the script within the WSL instance
            $result = Get-Content -Path $tempScript -Raw | wsl -d $InstanceName -e bash -c "cat > /tmp/update_browsers.sh && chmod +x /tmp/update_browsers.sh && sudo -E /tmp/update_browsers.sh"
            
            # Clean up the temporary file
            if (Test-Path $tempScript) {
                Remove-Item -Path $tempScript -Force
            }
            
            # Display the results
            if ($null -eq $result -or $result.Count -eq 0) {
                Write-Host "No output received from the update script. This may indicate an error." -ForegroundColor Yellow
                return $false
            }
            
            foreach ($line in $result) {
                # Remove ANSI color codes for clean output
                $cleanLine = $line -replace '\033\[[0-9;]*m', ''
                
                # Add appropriate color based on the content
                if ($cleanLine -match "updated\.$") {
                    Write-Host $cleanLine -ForegroundColor Green
                }
                elseif ($cleanLine -match "skipping\.$") {
                    Write-Host $cleanLine -ForegroundColor Yellow
                }
                elseif ($cleanLine -match "======") {
                    Write-Host $cleanLine -ForegroundColor Cyan
                }
                else {
                    Write-Host $cleanLine
                }
            }
            
            return $true
        }
        catch {
            Write-Host "Error updating browsers in WSL instance '$InstanceName': $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            return $false
        }
    }

    # Function to create a summary report
    function Create-SummaryReport {
        param (
            [array]$InstanceResults
        )
        
        Write-Host "`n====== WSL BROWSER UPDATE SUMMARY ======" -ForegroundColor Cyan
        
        # Instance update summary
        Write-Host "`nWSL Instance Updates:" -ForegroundColor Yellow
        if ($InstanceResults.Count -eq 0) {
            Write-Host "  No WSL instances were updated" -ForegroundColor Gray
        }
        else {
            foreach ($result in $InstanceResults) {
                $status = if ($result.Success) { "Successfully updated" } else { "Update attempt failed" }
                $color = if ($result.Success) { "Green" } else { "Red" }
                Write-Host "  $($result.Name): $status" -ForegroundColor $color
            }
        }
        
        Write-Host "`nNote: Some browsers may continue updating in the background." -ForegroundColor Yellow
        Write-Host "====== END OF SUMMARY ======`n" -ForegroundColor Cyan
    }

    # Main execution
    
    # Elevate privileges if not running as admin
    if (-not (Test-Admin)) {
        Write-Host "Requesting administrative privileges..." -ForegroundColor Yellow
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    Write-Host "====== WSL Browser Update Script - Started ======" -ForegroundColor Cyan
    Write-Host "Script is running with Administrator privileges" -ForegroundColor Green

    # Check if WSL is installed
    if (-not (Test-WSLInstalled)) {
        Write-Host "WSL is not installed on this system. Please install WSL before running this script." -ForegroundColor Red
        exit 1
    }

    # Get all WSL instances
    $wslInstances = Get-WSLInstances
    
    if ($wslInstances.Count -eq 0) {
        Write-Host "No valid WSL instances found. Please install at least one WSL distribution." -ForegroundColor Red
        Write-Host "`nTo install WSL, run the following commands in an administrator PowerShell window:" -ForegroundColor Yellow
        Write-Host "  1. Enable WSL feature: wsl --install" -ForegroundColor Yellow
        Write-Host "  2. Install Ubuntu: wsl --install -d Ubuntu" -ForegroundColor Yellow
        Write-Host "  3. After installation completes, restart your computer" -ForegroundColor Yellow
        Write-Host "  4. Once WSL is set up, install browsers using the WSL tab in the extension" -ForegroundColor Yellow
        exit 1
    }

    # Read the WSL instance from the settings file
    Write-Host "Checking for WSL instance in settings..." -ForegroundColor Yellow
    
    # Try different locations for the settings file
    $possibleSettingsPaths = @(
        # Main project directory
        (Join-Path -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSCommandPath)) -ChildPath "browser_settings.json"),
        # Current directory
        (Join-Path -Path (Get-Location) -ChildPath "browser_settings.json"),
        # Script directory
        (Join-Path -Path (Split-Path -Parent -Path $PSCommandPath) -ChildPath "browser_settings.json"),
        # One level up from script directory
        (Join-Path -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSCommandPath)) -ChildPath "browser_settings.json")
    )
    
    $settingsFound = $false
    $settingsPath = $null
    
    foreach ($path in $possibleSettingsPaths) {
        Write-Host "Checking for settings at: $path" -ForegroundColor Gray
        if (Test-Path $path) {
            $settingsPath = $path
            $settingsFound = $true
            Write-Host "Found settings file at: $settingsPath" -ForegroundColor Green
            break
        }
    }
    
    if ($settingsFound) {
        try {
            $settingsContent = Get-Content -Path $settingsPath -Raw
            Write-Host "Settings file content:" -ForegroundColor Gray
            Write-Host $settingsContent -ForegroundColor Gray
            
            # More resilient JSON parsing
            try {
                # First try normal conversion
                $settings = $null
                try {
                    $settings = ConvertFrom-Json -InputObject $settingsContent -ErrorAction Stop
                } catch {
                    # If that fails, try to clean the JSON before parsing
                    Write-Host "Initial JSON parsing failed, trying to clean content..." -ForegroundColor Yellow
                    $cleanContent = $settingsContent -replace '[\r\n]', '' -replace '\s+', ' '
                    $settings = ConvertFrom-Json -InputObject $cleanContent -ErrorAction Stop
                }
                
                if ($settings) {
                    Write-Host "Successfully parsed settings JSON" -ForegroundColor Green
                    
                    # Check if wslInstance property exists
                    if (Get-Member -InputObject $settings -Name "wslInstance" -MemberType Properties -ErrorAction SilentlyContinue) {
                        $configuredInstance = $settings.wslInstance
                        
                        if (-not [string]::IsNullOrWhiteSpace($configuredInstance)) {
                            Write-Host "Found configured WSL instance in settings: $configuredInstance" -ForegroundColor Green
                            
                            # Check if the configured instance exists
                            $instanceExists = $wslInstances | Where-Object { $_.Name -eq $configuredInstance }
                            
                            if ($instanceExists) {
                                Write-Host "Configured WSL instance '$configuredInstance' found and will be used." -ForegroundColor Green
                                
                                # Update only the configured WSL instance
                                $instanceResults = @()
                                $success = Update-BrowsersInWSL -InstanceName $configuredInstance
                                $instanceResults += @{
                                    Name = $configuredInstance
                                    Success = $success
                                }
                                
                                # Create and display summary report
                                Create-SummaryReport -InstanceResults $instanceResults
                                
                                Write-Host "WSL browser update process completed." -ForegroundColor Cyan
                                
                                # Keep window open
                                Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
                                Read-Host
                                exit 0
                            } else {
                                Write-Host "Configured WSL instance '$configuredInstance' not found in available instances." -ForegroundColor Red
                                Write-Host "Available instances:" -ForegroundColor Yellow
                                foreach ($instance in $wslInstances) {
                                    Write-Host "  - $($instance.Name)" -ForegroundColor Yellow
                                }
                            }
                        } else {
                            Write-Host "WSL instance property is empty in settings." -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "wslInstance property not found in settings object. Available properties:" -ForegroundColor Yellow
                        Get-Member -InputObject $settings -MemberType Properties | ForEach-Object {
                            Write-Host "  - $($_.Name)" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Host "Failed to parse settings JSON" -ForegroundColor Red
                }
            } catch {
                Write-Host "Error parsing JSON settings: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            }
        } catch {
            Write-Host "Error reading settings file: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        }
    } else {
        Write-Host "Settings file not found in any of the expected locations." -ForegroundColor Yellow
        Write-Host "Checked paths:" -ForegroundColor Gray
        $possibleSettingsPaths | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Gray
        }
    }
    
    # As a fallback, ask the user which instance to update
    Write-Host "`nPlease select a WSL instance to update:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $wslInstances.Count; $i++) {
        Write-Host "  $($i+1). $($wslInstances[$i].Name)" -ForegroundColor Green
    }
    
    Write-Host "  0. Update all instances" -ForegroundColor Yellow
    
    $choice = Read-Host "Enter your choice (0-$($wslInstances.Count))"
    
    # Initialize results tracking array
    $instanceResults = @()
    
    if ($choice -eq "0") {
        # Update all instances
        foreach ($instance in $wslInstances) {
            $success = Update-BrowsersInWSL -InstanceName $instance.Name
            $instanceResults += @{
                Name = $instance.Name
                Success = $success
            }
        }
    } elseif ([int]$choice -ge 1 -and [int]$choice -le $wslInstances.Count) {
        # Update the selected instance
        $selectedInstance = $wslInstances[[int]$choice - 1]
        $success = Update-BrowsersInWSL -InstanceName $selectedInstance.Name
        $instanceResults += @{
            Name = $selectedInstance.Name
            Success = $success
        }
    } else {
        Write-Host "Invalid choice. Exiting." -ForegroundColor Red
        exit 1
    }

    # Create and display summary report
    Create-SummaryReport -InstanceResults $instanceResults

    Write-Host "WSL browser update process completed." -ForegroundColor Cyan
}
catch {
    # If any error occurs, capture it and display it
    Write-Host "`n====== ERROR OCCURRED ======" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    Write-Host "======= END OF ERROR =======" -ForegroundColor Red
}
finally {
    # Always make sure this executes, even on error
    Write-Host "`nPress Enter to close this window..." -ForegroundColor Yellow
    Read-Host
} 