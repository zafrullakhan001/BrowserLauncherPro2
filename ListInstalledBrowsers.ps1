# ListInstalledBrowsers.ps1
# Script to detect and list all installed browsers on Windows

$Host.UI.RawUI.WindowTitle = "Browser Detection Tool"
Clear-Host
Write-Host "====== Browser Detection Tool ======" -ForegroundColor Cyan
Write-Host "Detecting installed browsers on your system..." -ForegroundColor Yellow
Write-Host ""

# Define browser registry paths
$browsers = @(
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
        VersionArgs = "--version"
        VersionPattern = "Google Chrome (\d+\.\d+\.\d+\.\d+)"
    },
    @{
        Name = "Google Chrome Beta"
        RegPaths = @()
        InstallPaths = @(
            "${env:ProgramFiles}\Google\Chrome Beta\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome Beta\Application\chrome.exe"
        )
        VersionRegKey = "HKCU:\Software\Google\Chrome Beta\BLBeacon"
        VersionRegValue = "version"
        VersionArgs = "--version"
        VersionPattern = "Google Chrome (\d+\.\d+\.\d+\.\d+)"
    },
    @{
        Name = "Google Chrome Dev"
        RegPaths = @()
        InstallPaths = @(
            "${env:ProgramFiles}\Google\Chrome Dev\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome Dev\Application\chrome.exe"
        )
        VersionRegKey = "HKCU:\Software\Google\Chrome Dev\BLBeacon"
        VersionRegValue = "version"
        VersionArgs = "--version"
        VersionPattern = "Google Chrome (\d+\.\d+\.\d+\.\d+)"
    },
    @{
        Name = "Google Chrome Canary"
        RegPaths = @()
        InstallPaths = @(
            "${env:LocalAppData}\Google\Chrome SxS\Application\chrome.exe"
        )
        VersionRegKey = "HKCU:\Software\Google\Chrome\BLBeacon"
        VersionRegValue = "version"
        VersionArgs = "--version"
        VersionPattern = "Google Chrome (\d+\.\d+\.\d+\.\d+)"
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
        VersionArgs = "--version"
        VersionPattern = "Microsoft Edge (\d+\.\d+\.\d+\.\d+)"
    },
    @{
        Name = "Microsoft Edge Beta"
        RegPaths = @()
        InstallPaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge Beta\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge Beta\Application\msedge.exe"
        )
        VersionRegKey = "HKCU:\Software\Microsoft\Edge Beta\BLBeacon"
        VersionRegValue = "version"
        VersionArgs = "--version"
        VersionPattern = "Microsoft Edge (\d+\.\d+\.\d+\.\d+)"
    },
    @{
        Name = "Microsoft Edge Dev"
        RegPaths = @()
        InstallPaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge Dev\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge Dev\Application\msedge.exe"
        )
        VersionRegKey = "HKCU:\Software\Microsoft\Edge Dev\BLBeacon"
        VersionRegValue = "version"
        VersionArgs = "--version"
        VersionPattern = "Microsoft Edge (\d+\.\d+\.\d+\.\d+)"
    },
    @{
        Name = "Microsoft Edge Canary"
        RegPaths = @()
        InstallPaths = @(
            "${env:LocalAppData}\Microsoft\Edge SxS\Application\msedge.exe"
        )
        VersionRegKey = ""
        VersionRegValue = ""
        VersionArgs = "--version"
        VersionPattern = "Microsoft Edge (\d+\.\d+\.\d+\.\d+)"
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
        VersionRegKey = ""
        VersionRegValue = ""
        VersionArgs = "--version"
        VersionPattern = "Mozilla Firefox (\d+\.\d+)"
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
        VersionRegKey = ""
        VersionRegValue = ""
        VersionArgs = "--version"
        VersionPattern = "(\d+\.\d+\.\d+\.\d+)"
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
        VersionRegKey = ""
        VersionRegValue = ""
        VersionArgs = "--version"
        VersionPattern = "Brave Chrome (\d+\.\d+\.\d+\.\d+)"
    }
)

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

# Function to get browser version by running the executable
function Get-BrowserVersionFromExe($path, $args, $pattern) {
    try {
        $output = & $path $args 2>&1
        if ($output -match $pattern) {
            return $matches[1]
        }
    } catch {}
    return $null
}

# Function to get file version information
function Get-FileVersion($path) {
    try {
        return (Get-Item $path -ErrorAction SilentlyContinue).VersionInfo.FileVersion
    } catch {}
    return $null
}

# Function to find a browser's path
function Find-BrowserPath($browser) {
    # Check registry paths first
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
    
    # Check install paths
    foreach ($path in $browser.InstallPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Results array
$results = @()

# Check each browser
foreach ($browser in $browsers) {
    $path = Find-BrowserPath $browser
    
    if ($path) {
        # Try different methods to get version
        $version = $null
        
        # Method 1: Registry
        $version = Get-BrowserVersionFromRegistry $browser.VersionRegKey $browser.VersionRegValue
        
        # Method 2: File version
        if (-not $version) {
            $version = Get-FileVersion $path
        }
        
        # Method 3: Run with --version (only if safe to do)
        <# Commented out for safety
        if (-not $version -and $browser.VersionArgs) {
            $version = Get-BrowserVersionFromExe $path $browser.VersionArgs $browser.VersionPattern
        }
        #>
        
        $results += [PSCustomObject]@{
            Browser = $browser.Name
            Status = "Installed"
            Version = $version
            Path = $path
        }
    }
}

# Check PATH environment variable for browsers
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
                
                $version = Get-FileVersion $fullPath
                
                $results += [PSCustomObject]@{
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

# Output results as a table
Write-Host "Installed Browsers:" -ForegroundColor Green
$results | Format-Table -AutoSize -Property Browser, Version, Path

# Save results to a file
$resultsFile = Join-Path $env:TEMP "BrowserDetectionResults.csv"
$results | Export-Csv -Path $resultsFile -NoTypeInformation

Write-Host ""
Write-Host "Results saved to: $resultsFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "====== Detection Complete ======" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 