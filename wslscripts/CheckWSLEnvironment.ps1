<#
.SYNOPSIS
    Checks the WSL environment and settings for the browser updater.
.DESCRIPTION
    This script verifies that WSL is installed and properly configured,
    and that the browser_settings.json file contains a valid WSL instance.
.NOTES
    This is a diagnostic tool to help troubleshoot WSL browser update issues.
#>

# Check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check if WSL is installed and print version info
function Test-WSLInstallation {
    Write-Host "Checking WSL installation..." -ForegroundColor Yellow
    
    # Try wsl --status
    try {
        $statusOutput = wsl --status 2>&1
        Write-Host "`nWSL Status Output:" -ForegroundColor Cyan
        Write-Host $statusOutput -ForegroundColor Gray
    }
    catch {
        Write-Host "Error running wsl --status: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Try wsl --version
    try {
        $versionOutput = wsl --version 2>&1
        Write-Host "`nWSL Version Output:" -ForegroundColor Cyan
        Write-Host $versionOutput -ForegroundColor Gray
    }
    catch {
        Write-Host "Error running wsl --version: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Check WSL Windows feature
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux 2>$null
        Write-Host "`nWSL Windows Feature:" -ForegroundColor Cyan
        Write-Host "State: $($wslFeature.State)" -ForegroundColor Gray
    }
    catch {
        Write-Host "Error checking WSL Windows feature: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to check WSL distributions
function Get-WSLDistributions {
    Write-Host "`nChecking WSL distributions..." -ForegroundColor Yellow
    
    try {
        $listOutput = wsl --list --verbose 2>&1
        Write-Host "`nWSL Distributions:" -ForegroundColor Cyan
        Write-Host $listOutput -ForegroundColor Gray
        
        # Parse and show each distribution
        $lines = $listOutput -split "`n" | Where-Object { $_ -match "\S" }
        $startIndex = if ($lines[0] -match "NAME|STATE|VERSION") { 1 } else { 0 }
        
        $distributions = @()
        for ($i = $startIndex; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            
            if ($line -match '^\*?\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                $name = $Matches[1]
                $state = $Matches[2]
                $version = $Matches[3]
                
                $name = $name -replace '^\*', ''
                
                if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne "*") {
                    $distributions += [PSCustomObject]@{
                        Name = $name
                        State = $state
                        Version = $version
                    }
                }
            }
        }
        
        if ($distributions.Count -gt 0) {
            Write-Host "`nParsed Distributions:" -ForegroundColor Cyan
            foreach ($dist in $distributions) {
                Write-Host "  - $($dist.Name) (State: $($dist.State), Version: $($dist.Version))" -ForegroundColor Green
            }
        } else {
            Write-Host "`nNo valid distributions found." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error getting WSL distributions: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to find and check browser_settings.json
function Check-SettingsFile {
    Write-Host "`nChecking for browser_settings.json..." -ForegroundColor Yellow
    
    # Try different locations for the settings file
    $possiblePaths = @(
        (Join-Path -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSCommandPath)) -ChildPath "browser_settings.json"),
        (Join-Path -Path (Get-Location) -ChildPath "browser_settings.json"),
        (Join-Path -Path (Split-Path -Parent -Path $PSCommandPath) -ChildPath "browser_settings.json"),
        (Join-Path -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSCommandPath)) -ChildPath "browser_settings.json")
    )
    
    $settingsFound = $false
    
    foreach ($path in $possiblePaths) {
        Write-Host "Checking path: $path" -ForegroundColor Gray
        
        if (Test-Path $path) {
            $settingsFound = $true
            Write-Host "Found settings file at: $path" -ForegroundColor Green
            
            try {
                $content = Get-Content -Path $path -Raw
                Write-Host "`nSettings file content:" -ForegroundColor Cyan
                Write-Host $content -ForegroundColor Gray
                
                try {
                    $settings = ConvertFrom-Json -InputObject $content -ErrorAction Stop
                    
                    Write-Host "`nParsed settings:" -ForegroundColor Cyan
                    Get-Member -InputObject $settings -MemberType Properties | ForEach-Object {
                        Write-Host "  - $($_.Name): $($settings.$($_.Name))" -ForegroundColor Gray
                    }
                    
                    # Specifically check for wslInstance
                    if (Get-Member -InputObject $settings -Name "wslInstance" -MemberType Properties -ErrorAction SilentlyContinue) {
                        $wslInstance = $settings.wslInstance
                        if (-not [string]::IsNullOrWhiteSpace($wslInstance)) {
                            Write-Host "  - WSL Instance: $wslInstance" -ForegroundColor Green
                        } else {
                            Write-Host "  - WSL Instance: [empty]" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "  - WSL Instance: [not found]" -ForegroundColor Red
                    }
                }
                catch {
                    Write-Host "Error parsing settings file: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "Error reading settings file: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Only check the first file found
            break
        }
    }
    
    if (-not $settingsFound) {
        Write-Host "Settings file not found in any of the checked locations." -ForegroundColor Red
    }
}

# Function to verify WSL browser installation
function Check-WSLBrowsers {
    Write-Host "`nChecking for browsers in WSL..." -ForegroundColor Yellow
    
    try {
        $listOutput = wsl --list --verbose 2>&1
        $lines = $listOutput -split "`n" | Where-Object { $_ -match "\S" }
        $startIndex = if ($lines[0] -match "NAME|STATE|VERSION") { 1 } else { 0 }
        
        $distributions = @()
        for ($i = $startIndex; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            
            if ($line -match '^\*?\s*([^\s]+)') {
                $name = $Matches[1] -replace '^\*', ''
                
                if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne "*") {
                    $distributions += $name
                }
            }
        }
        
        if ($distributions.Count -gt 0) {
            foreach ($dist in $distributions) {
                Write-Host "`nChecking browsers in WSL distribution: $dist" -ForegroundColor Cyan
                
                # Create a simple script to check browser installations
                $checkScript = @'
#!/bin/bash
echo "Checking installed browsers..."
browsers=("microsoft-edge-stable" "google-chrome-stable" "brave-browser" "firefox" "opera-stable")
for browser in "${browsers[@]}"; do
  if dpkg -l | grep -q "^ii.*$browser"; then
    version=$(dpkg -l | grep "^ii.*$browser" | awk '{print $3}')
    echo "  - $browser: Installed (version: $version)"
  else
    echo "  - $browser: Not installed"
  fi
done
'@
                
                # Create a temporary file with the bash script
                $tempScript = [System.IO.Path]::GetTempFileName()
                $checkScript | Set-Content -Path $tempScript -Encoding ASCII
                
                try {
                    # Execute the script within the WSL instance
                    $result = Get-Content -Path $tempScript -Raw | wsl -d $dist -e bash -c "cat > /tmp/check_browsers.sh && chmod +x /tmp/check_browsers.sh && /tmp/check_browsers.sh" 2>&1
                    Write-Host $result -ForegroundColor Gray
                }
                catch {
                    Write-Host "Error checking browsers in $dist : $($_.Exception.Message)" -ForegroundColor Red
                }
                finally {
                    # Clean up the temporary file
                    if (Test-Path $tempScript) {
                        Remove-Item -Path $tempScript -Force
                    }
                }
            }
        } else {
            Write-Host "No valid WSL distributions found to check browsers." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error checking WSL browsers: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main script
Write-Host "===== WSL Environment Diagnostics =====" -ForegroundColor Cyan
Write-Host "Running from: $PSCommandPath" -ForegroundColor Gray
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray

if (Test-Admin) {
    Write-Host "Running with administrator privileges." -ForegroundColor Green
} else {
    Write-Host "Not running with administrator privileges!" -ForegroundColor Red
    Write-Host "Some diagnostics may fail. Consider rerunning as Administrator." -ForegroundColor Red
}

Test-WSLInstallation
Get-WSLDistributions
Check-SettingsFile
Check-WSLBrowsers

Write-Host "`n===== Diagnostics Complete =====" -ForegroundColor Cyan
Write-Host "Press Enter to exit..." -ForegroundColor Yellow
Read-Host 