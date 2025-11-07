# Function to check if a path exists and return its status
function Test-BrowserPath {
    param (
        [string]$BrowserName,
        [string]$Path
    )
    
    $exists = Test-Path -Path $Path -ErrorAction SilentlyContinue
    $status = if ($exists) { "Found" } else { "Not Found" }
    $color = if ($exists) { "Green" } else { "Red" }
    
    Write-Host "$BrowserName`:" -ForegroundColor Yellow
    Write-Host "$(if ($exists) { "[+]" } else { "[-]" }) $status`:$Path" -ForegroundColor $color
    Write-Host ""
    
    # Return object with path info
    return @{
        exists = $exists
        path = $Path
    }
}

# Create settings object to store paths
$settings = @{}

# Define browser paths
$browserPaths = @{
    # Edge paths
    "Edge Stable" = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    "Edge Beta" = "${env:ProgramFiles(x86)}\Microsoft\Edge Beta\Application\msedge.exe"
    "Edge Dev" = "${env:ProgramFiles(x86)}\Microsoft\Edge Dev\Application\msedge.exe"
    
    # Chrome paths
    "Chrome Stable" = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    "Chrome Beta" = "${env:ProgramFiles}\Google\Chrome Beta\Application\chrome.exe"
    "Chrome Dev" = "${env:ProgramFiles}\Google\Chrome Dev\Application\chrome.exe"
}

# Print header
Write-Host "=== Browser Path Checker ===" -ForegroundColor Cyan
Write-Host ""

# Check each browser path and store in settings
foreach ($browser in $browserPaths.GetEnumerator()) {
    $result = Test-BrowserPath -BrowserName $browser.Key -Path $browser.Value
    
    # Map browser names to settings keys
    $settingKey = switch ($browser.Key) {
        "Edge Stable" { "edgeStablePath" }
        "Edge Beta" { "edgeBetaPath" }
        "Edge Dev" { "edgeDevPath" }
        "Chrome Stable" { "chromeStablePath" }
        "Chrome Beta" { "chromeBetaPath" }
        "Chrome Dev" { "chromeDevPath" }
    }
    
    if ($result.exists) {
        $settings[$settingKey] = $result.path
    } else {
        $settings[$settingKey] = "NA"
    }
}

# Additional check for WSL paths if WSL is installed
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    Write-Host "=== WSL Browser Paths ===" -ForegroundColor Cyan
    Write-Host ""
    
    $wslPaths = @{
        "Edge Stable (WSL)" = "microsoft-edge-stable"
        "Edge Beta (WSL)" = "microsoft-edge-beta"
        "Edge Dev (WSL)" = "microsoft-edge-dev"
        "Chrome Stable (WSL)" = "google-chrome-stable"
        "Chrome Beta (WSL)" = "google-chrome-beta"
        "Chrome Dev (WSL)" = "google-chrome-unstable"
        "Firefox (WSL)" = "firefox"
        "Opera (WSL)" = "opera"
        "Brave (WSL)" = "brave-browser"
    }
    
    foreach ($browser in $wslPaths.GetEnumerator()) {
        Write-Host "$($browser.Key)`:" -ForegroundColor Yellow
        $wslPath = $null
        try {
            $wslPath = wsl which $browser.Value 2>$null
        } catch {
            $wslPath = $null
        }
        
        # Map WSL browser names to settings keys
        $settingKey = switch ($browser.Key) {
            "Edge Stable (WSL)" { "wslEdgeStablePath" }
            "Edge Beta (WSL)" { "wslEdgeBetaPath" }
            "Edge Dev (WSL)" { "wslEdgeDevPath" }
            "Chrome Stable (WSL)" { "wslChromeStablePath" }
            "Chrome Beta (WSL)" { "wslChromeBetaPath" }
            "Chrome Dev (WSL)" { "wslChromeDevPath" }
            "Firefox (WSL)" { "wslFirefoxPath" }
            "Opera (WSL)" { "wslOperaPath" }
            "Brave (WSL)" { "wslBravePath" }
        }
        
        if ($wslPath) {
            Write-Host "[+] Found`:$wslPath" -ForegroundColor Green
            $settings[$settingKey] = $wslPath.Trim()
        } else {
            Write-Host "[-] Not Found" -ForegroundColor Red
            $settings[$settingKey] = "NA"
        }
        Write-Host ""
    }
}

Write-Host "=== Registry Version Information ===" -ForegroundColor Cyan
Write-Host ""

# Check registry for version information
$registryPaths = @{
    "Edge Stable" = "HKEY_CURRENT_USER\Software\Microsoft\Edge\BLBeacon"
    "Edge Beta" = "HKEY_CURRENT_USER\Software\Microsoft\Edge Beta\BLBeacon"
    "Edge Dev" = "HKEY_CURRENT_USER\Software\Microsoft\Edge Dev\BLBeacon"
    "Chrome Stable" = "HKEY_CURRENT_USER\Software\Google\Chrome\BLBeacon"
    "Chrome Beta" = "HKEY_CURRENT_USER\Software\Google\Chrome Beta\BLBeacon"
    "Chrome Dev" = "HKEY_CURRENT_USER\Software\Google\Chrome Dev\BLBeacon"
}

# Store versions in settings
foreach ($browser in $registryPaths.GetEnumerator()) {
    Write-Host "$($browser.Key) Version`:" -ForegroundColor Yellow
    $version = (Get-ItemProperty -Path "Registry::$($browser.Value)" -ErrorAction SilentlyContinue).version
    
    # Map browser names to version settings keys
    $settingKey = switch ($browser.Key) {
        "Edge Stable" { "edgeStableVersion" }
        "Edge Beta" { "edgeBetaVersion" }
        "Edge Dev" { "edgeDevVersion" }
        "Chrome Stable" { "chromeStableVersion" }
        "Chrome Beta" { "chromeBetaVersion" }
        "Chrome Dev" { "chromeDevVersion" }
    }
    
    if ($version) {
        Write-Host "[+] Version`:$version" -ForegroundColor Green
        $settings[$settingKey] = $version
    } else {
        Write-Host "[-] Version information not found" -ForegroundColor Red
        $settings[$settingKey] = "0.0.0.0"
    }
    Write-Host ""
}

# Add default settings
$settings["versionCheckbox"] = $true
$settings["checkInterval"] = 60
$settings["edgeStableCheckbox"] = $true
$settings["chromeStableCheckbox"] = $true

# Convert settings to JSON and save to file
$settingsJson = $settings | ConvertTo-Json
$settingsPath = Join-Path $PSScriptRoot "browser_settings.json"
$settingsJson | Out-File -FilePath $settingsPath -Encoding UTF8

Write-Host "=== Settings Export ===" -ForegroundColor Cyan
Write-Host "Settings have been exported to: $settingsPath" -ForegroundColor Green
Write-Host "You can now import these settings into the extension." -ForegroundColor Yellow 