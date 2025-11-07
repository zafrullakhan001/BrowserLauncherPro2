#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Diagnoses and reports on browsers installed in Windows and WSL.
.DESCRIPTION
    This script detects all browsers installed on the Windows host and in WSL
    distributions, reporting versions, installation paths, and status.
.NOTES
    Requires administrative privileges for complete information.
#>

$Host.UI.RawUI.WindowTitle = "Browser Diagnostics Tool"
Clear-Host
Write-Host "====== Browser Diagnostics Tool ======" -ForegroundColor Cyan
Write-Host "Detecting browsers in Windows and WSL..." -ForegroundColor Yellow
Write-Host ""

# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Define browser registry paths for Windows
$windowsBrowsers = @(
    @{
        Name = "Google Chrome"
        RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
        )
        InstallPaths = @(
            "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "${env:LocalAppData}\Google\Chrome\Application\chrome.exe"
        )
        VersionRegKey = "HKCU:\Software\Google\Chrome\BLBeacon"
        VersionRegValue = "version"
    },
    @{
        Name = "Google Chrome Beta"
        InstallPaths = @(
            "${env:ProgramFiles}\Google\Chrome Beta\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome Beta\Application\chrome.exe"
        )
        VersionRegKey = "HKCU:\Software\Google\Chrome Beta\BLBeacon"
        VersionRegValue = "version"
    },
    @{
        Name = "Google Chrome Dev"
        InstallPaths = @(
            "${env:ProgramFiles}\Google\Chrome Dev\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome Dev\Application\chrome.exe"
        )
        VersionRegKey = "HKCU:\Software\Google\Chrome Dev\BLBeacon"
        VersionRegValue = "version"
    },
    @{
        Name = "Google Chrome Canary"
        InstallPaths = @(
            "${env:LocalAppData}\Google\Chrome SxS\Application\chrome.exe"
        )
        VersionRegKey = "HKCU:\Software\Google\Chrome\BLBeacon"
        VersionRegValue = "version"
    },
    @{
        Name = "Microsoft Edge"
        RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe"
        )
        InstallPaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
        )
        VersionRegKey = "HKCU:\Software\Microsoft\Edge\BLBeacon"
        VersionRegValue = "version"
    },
    @{
        Name = "Microsoft Edge Beta"
        InstallPaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge Beta\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge Beta\Application\msedge.exe"
        )
        VersionRegKey = "HKCU:\Software\Microsoft\Edge Beta\BLBeacon"
        VersionRegValue = "version"
    },
    @{
        Name = "Microsoft Edge Dev"
        InstallPaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge Dev\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge Dev\Application\msedge.exe"
        )
        VersionRegKey = "HKCU:\Software\Microsoft\Edge Dev\BLBeacon"
        VersionRegValue = "version"
    },
    @{
        Name = "Microsoft Edge Canary"
        InstallPaths = @(
            "${env:LocalAppData}\Microsoft\Edge SxS\Application\msedge.exe"
        )
    },
    @{
        Name = "Firefox"
        RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe"
        )
        InstallPaths = @(
            "${env:ProgramFiles}\Mozilla Firefox\firefox.exe",
            "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
        )
    },
    @{
        Name = "Opera"
        RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\opera.exe",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\opera.exe"
        )
        InstallPaths = @(
            "${env:ProgramFiles}\Opera\launcher.exe",
            "${env:ProgramFiles(x86)}\Opera\launcher.exe"
        )
    },
    @{
        Name = "Brave"
        RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\brave.exe",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\brave.exe"
        )
        InstallPaths = @(
            "${env:ProgramFiles}\BraveSoftware\Brave-Browser\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
            "${env:LocalAppData}\BraveSoftware\Brave-Browser\Application\brave.exe"
        )
    }
)

# Function to find a browser's path
function Find-BrowserPath($browser) {
    # Check registry paths first
    if ($browser.RegPaths) {
        foreach ($regPath in $browser.RegPaths) {
            if (Test-Path $regPath) {
                try {
                    $path = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).'(Default)'
                    if ($path -and (Test-Path $path)) {
                        return $path
                    }
                } catch {}
            }
        }
    }
    
    # Check install paths
    foreach ($path in $browser.InstallPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Function to get browser version from registry
function Get-BrowserVersionFromRegistry($key, $valueName) {
    if (-not $key -or -not $valueName) { return $null }
    try {
        if (Test-Path $key) {
            $version = (Get-ItemProperty -Path $key -Name $valueName -ErrorAction SilentlyContinue).$valueName
            return $version
        }
    } catch {}
    return $null
}

# Function to get file version information
function Get-FileVersion($path) {
    try {
        $versionInfo = (Get-Item $path -ErrorAction SilentlyContinue).VersionInfo
        $version = $versionInfo.ProductVersion
        if (-not $version) { $version = $versionInfo.FileVersion }
        return $version
    } catch {}
    return $null
}

# Function to check if WSL is installed
function Test-WSLInstalled {
    try {
        $wslOutput = wsl --status 2>&1
        return $true
    } catch {
        return $false
    }
}

# Function to get WSL distributions
function Get-WSLDistributions {
    try {
        $output = wsl --list --verbose 2>&1
        $lines = $output -split "\r?\n" | Where-Object { $_ -match "\S" }
        $result = @()
        
        # Skip the header line if it exists
        $startIndex = if ($lines[0] -match "NAME|STATE|VERSION") { 1 } else { 0 }
        
        for ($i = $startIndex; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*(?:\*\s*)?([^\s]+)\s+([^\s]+)\s+(\d+)') {
                $name = $Matches[1]
                $state = $Matches[2]
                $version = $Matches[3]
                
                $result += [PSCustomObject]@{
                    Name = $name
                    State = $state
                    Version = $version
                }
            }
        }
        
        return $result
    } catch {
        return @()
    }
}

# Function to check browsers in a WSL distribution
function Get-WSLBrowsers($distro) {
    $wslBrowsers = @()
    
    # Create a script to check for browser installations
    $checkScript = @'
#!/bin/bash
echo "Checking installed browsers..."
browsers=(
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

for browser in "${browsers[@]}"; do
  # Define command name based on package name
  command_name=""
  case "$browser" in
    "microsoft-edge-stable") command_name="microsoft-edge" ;;
    "google-chrome-stable") command_name="google-chrome" ;;
    "opera-stable") command_name="opera" ;;
    *) command_name="$browser" ;;
  esac
  
  # Check if package is installed
  if dpkg -l | grep -q "^ii.*$browser "; then
    version=$(dpkg -l | grep "^ii.*$browser " | awk '{print $3}')
    path=$(which "$command_name" 2>/dev/null || echo "N/A")
    echo "$browser|Installed|$version|$path"
  # Check if command exists even if package isn't found
  elif which "$command_name" > /dev/null 2>&1; then
    path=$(which "$command_name")
    version=$("$command_name" --version 2>/dev/null | head -n 1 || echo "Unknown")
    echo "$browser|Available*|$version|$path"
  fi
done
'@
    
    # Create a temporary file for the script
    $tempScript = [System.IO.Path]::GetTempFileName()
    $checkScript | Set-Content -Path $tempScript -Encoding ASCII
    
    try {
        # Run the script in the WSL distribution
        $output = Get-Content -Path $tempScript -Raw | wsl -d $distro.Name -e bash -c "cat > /tmp/check_browsers.sh && chmod +x /tmp/check_browsers.sh && /tmp/check_browsers.sh" 2>&1
        
        # Parse the output
        foreach ($line in $output) {
            if ($line -match '([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)') {
                $wslBrowsers += [PSCustomObject]@{
                    Environment = "WSL-$($distro.Name)"
                    Browser = $Matches[1]
                    Status = $Matches[2]
                    Version = $Matches[3]
                    Path = $Matches[4]
                }
            }
        }
    } catch {
        Write-Host "Error checking browsers in $($distro.Name): $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        # Clean up the temporary file
        if (Test-Path $tempScript) {
            Remove-Item -Path $tempScript -Force
        }
    }
    
    return $wslBrowsers
}

# Results array for all browsers
$results = @()

# Check if running as administrator
$isAdmin = Test-Admin
if (-not $isAdmin) {
    Write-Host "Warning: Not running as administrator. Some information may be incomplete." -ForegroundColor Yellow
    Write-Host ""
}

# Detect Windows browsers
Write-Host "Checking for browsers in Windows..." -ForegroundColor Yellow
foreach ($browser in $windowsBrowsers) {
    $path = Find-BrowserPath -browser $browser
    
    if ($path) {
        # Try different methods to get version
        $version = $null
        
        # Method 1: Registry
        if ($browser.VersionRegKey -and $browser.VersionRegValue) {
            $version = Get-BrowserVersionFromRegistry -key $browser.VersionRegKey -valueName $browser.VersionRegValue
        }
        
        # Method 2: File version
        if (-not $version) {
            $version = Get-FileVersion -path $path
        }
        
        $results += [PSCustomObject]@{
            Environment = "Windows"
            Browser = $browser.Name
            Status = "Installed"
            Version = $version
            Path = $path
        }
    }
}

# Check PATH environment variable for additional browsers
$envPaths = $env:PATH -split ';'
$checkedExecutables = @("chrome.exe", "msedge.exe", "firefox.exe", "opera.exe", "brave.exe")

foreach ($exe in $checkedExecutables) {
    $found = $false
    foreach ($dir in $envPaths) {
        $fullPath = Join-Path $dir $exe
        if (Test-Path $fullPath) {
            # Check if this path is already in our results
            $alreadyFound = $false
            foreach ($result in $results) {
                if ($result.Path -eq $fullPath) {
                    $alreadyFound = $true
                    break
                }
            }
            
            if (-not $alreadyFound) {
                $browserName = switch ($exe) {
                    "chrome.exe" { "Google Chrome (PATH)" }
                    "msedge.exe" { "Microsoft Edge (PATH)" }
                    "firefox.exe" { "Firefox (PATH)" }
                    "opera.exe" { "Opera (PATH)" }
                    "brave.exe" { "Brave (PATH)" }
                    default { "Unknown Browser" }
                }
                
                $version = Get-FileVersion -path $fullPath
                
                $results += [PSCustomObject]@{
                    Environment = "Windows"
                    Browser = $browserName
                    Status = "Installed"
                    Version = $version
                    Path = $fullPath
                }
            }
            
            $found = $true
            break
        }
    }
}

# Check WSL browsers if WSL is installed
$wslInstalled = Test-WSLInstalled
if ($wslInstalled) {
    Write-Host "Checking for browsers in WSL..." -ForegroundColor Yellow
    
    $distributions = Get-WSLDistributions
    if ($distributions.Count -gt 0) {
        foreach ($distro in $distributions) {
            Write-Host "  Checking browsers in $($distro.Name)..." -ForegroundColor Gray
            $wslBrowsers = Get-WSLBrowsers -distro $distro
            $results += $wslBrowsers
        }
    } else {
        Write-Host "  No WSL distributions found." -ForegroundColor Yellow
    }
} else {
    Write-Host "WSL is not installed on this system." -ForegroundColor Yellow
}

# Output results as a table
Write-Host "`nBrowser Detection Results:" -ForegroundColor Green
$results | Sort-Object -Property Environment, Browser | Format-Table -GroupBy Environment -Property Browser, Status, Version, Path -AutoSize

# Save results to a file
$resultsFile = Join-Path $env:TEMP "BrowserDetectionResults.csv"
$results | Export-Csv -Path $resultsFile -NoTypeInformation

Write-Host ""
Write-Host "Results saved to: $resultsFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "====== Browser Detection Complete ======" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 