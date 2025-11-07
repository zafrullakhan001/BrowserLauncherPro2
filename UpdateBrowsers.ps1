#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Updates web browsers (Edge, Chrome, and variants) on Windows.
.DESCRIPTION
    This script checks for and installs updates for Microsoft Edge, Google Chrome and their variants.
    It uses both Windows Update and direct browser update methods.
.NOTES
    Requires administrative privileges and the PSWindowsUpdate module.
#>

# Wrap everything in try/catch to ensure we always show the summary
try {
    # Function to check if running as administrator
    function Test-Admin {
        $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Function to check if a browser is installed
    function Test-BrowserInstalled {
        param (
            [string]$BrowserName,
            $Paths
        )
        
        # Handle string or array of paths
        if ($Paths -is [string]) {
            $pathsToCheck = @($Paths)
        } else {
            $pathsToCheck = $Paths
        }
        
        foreach ($path in $pathsToCheck) {
            if (Test-Path -Path $path) {
                return $path
            }
        }
        
        # If not found in explicit paths, check registry
        if ($BrowserName -like "*Chrome*") {
            # Check registry keys for Chrome installations
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
            )
            foreach ($regPath in $regPaths) {
                if (Test-Path $regPath) {
                    try {
                        $chromePath = (Get-ItemProperty -Path $regPath).'(Default)'
                        if (Test-Path $chromePath) {
                            return $chromePath
                        }
                    } catch {
                        # Continue on error
                    }
                }
            }
        }
        
        return $false
    }

    # Function to create a summary report with a table format
    function Create-SummaryReport {
        param (
            [array]$BrowserUpdates,
            [array]$WindowsUpdates
        )
        
        Write-Host "`n====== BROWSER UPDATE SUMMARY ======" -ForegroundColor Cyan
        
        # Collect browser information for report
        $browserReport = @()
        
        # Check each browser path and get detailed information
        foreach ($browser in $browserPaths.GetEnumerator()) {
            $browserPath = Test-BrowserInstalled -BrowserName $browser.Key -Paths $browser.Value
            
            if ($browserPath) {
                $version = "Unknown"
                $status = "Installed"
                
                # Try to get version
                try {
                    $versionInfo = (Get-Item $browserPath -ErrorAction SilentlyContinue).VersionInfo
                    $version = $versionInfo.ProductVersion
                    if (-not $version) { $version = $versionInfo.FileVersion }
                } catch {}
                
                # Set status based on whether it was updated
                if ($updatedBrowsers -contains $browser.Key) {
                    $status = "Updated"
                }
                
                $browserReport += [PSCustomObject]@{
                    Browser = $browser.Key
                    Status = $status
                    Version = $version
                    Path = $browserPath
                }
            }
        }
        
        # Add browsers found via PATH if they're not already in the report
        $chromePath = (where.exe chrome 2>$null | Select-Object -First 1)
        if ($chromePath -and (Test-Path $chromePath)) {
            $alreadyReported = $false
            foreach ($report in $browserReport) {
                if ($report.Path -eq $chromePath) {
                    $alreadyReported = $true
                    break
                }
            }
            
            if (-not $alreadyReported) {
                try {
                    $version = (Get-Item $chromePath -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
                    if (-not $version) { $version = (Get-Item $chromePath).VersionInfo.FileVersion }
                    $status = if ($updatedBrowsers -contains "Google Chrome") { "Updated" } else { "Installed" }
                    
                    $browserReport += [PSCustomObject]@{
                        Browser = "Google Chrome (PATH)"
                        Status = $status
                        Version = $version
                        Path = $chromePath
                    }
                } catch {}
            }
        }
        
        # Display the report in a nice table format
        if ($browserReport.Count -gt 0) {
            Write-Host "`nInstalled Browsers:" -ForegroundColor Green
            $browserReport | Format-Table -AutoSize -Property Browser, Status, Version, Path
        }
        
        # Display Windows Update information
        Write-Host "`nWindows Update Browser Components:" -ForegroundColor Yellow
        if ($null -eq $WindowsUpdates -or $WindowsUpdates.Count -eq 0) {
            Write-Host "  No browser-related Windows updates were found" -ForegroundColor Gray
        } else {
            foreach ($update in $WindowsUpdates) {
                Write-Host "  $($update.Title)" -ForegroundColor Green
            }
        }
        
        Write-Host "`nNote: Some browsers may continue updating in the background." -ForegroundColor Yellow
        Write-Host "====== END OF SUMMARY ======`n" -ForegroundColor Cyan
        
        # Export results to a CSV file for reference
        try {
            $csvPath = Join-Path $env:TEMP "BrowserUpdateResults.csv"
            $browserReport | Export-Csv -Path $csvPath -NoTypeInformation -ErrorAction SilentlyContinue
            Write-Host "Report saved to: $csvPath" -ForegroundColor Yellow
        } catch {}
    }

    # Elevate privileges if not running as admin
    if (-not (Test-Admin)) {
        Write-Host "Requesting administrative privileges..." -ForegroundColor Yellow
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    Write-Host "====== Browser Update Script - Started ======" -ForegroundColor Cyan
    Write-Host "Script is running with Administrator privileges" -ForegroundColor Green

    # Initialize update tracking arrays
    $browserUpdates = @()
    $windowsUpdates = @()

    # Check and install PSWindowsUpdate module if not already installed
    Write-Host "`nStep 1: Checking for PSWindowsUpdate module..." -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Yellow
        try {
            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
            Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Error "Failed to install PSWindowsUpdate module: $errorMessage"
            exit 1
        }
    } else {
        Write-Host "PSWindowsUpdate module is already installed." -ForegroundColor Green
    }

    # Import the module
    try {
        Write-Host "Importing PSWindowsUpdate module..." -ForegroundColor Yellow
        Import-Module PSWindowsUpdate
        Write-Host "PSWindowsUpdate module imported successfully." -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to import PSWindowsUpdate module: $errorMessage"
        exit 1
    }

    # Define browser paths for checking installation
    $browserPaths = @{
        "Microsoft Edge" = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        "Microsoft Edge Dev" = "${env:ProgramFiles(x86)}\Microsoft\Edge Dev\Application\msedge.exe"
        "Microsoft Edge Beta" = "${env:ProgramFiles(x86)}\Microsoft\Edge Beta\Application\msedge.exe"
        "Microsoft Edge Canary" = "${env:LocalAppData}\Microsoft\Edge SxS\Application\msedge.exe"
        "Google Chrome" = @(
            "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "${env:LocalAppData}\Google\Chrome\Application\chrome.exe"
        )
        "Google Chrome Dev" = @(
            "${env:ProgramFiles}\Google\Chrome Dev\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome Dev\Application\chrome.exe",
            "${env:LocalAppData}\Google\Chrome Dev\Application\chrome.exe"
        )
        "Google Chrome Beta" = @(
            "${env:ProgramFiles}\Google\Chrome Beta\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome Beta\Application\chrome.exe",
            "${env:LocalAppData}\Google\Chrome Beta\Application\chrome.exe"
        )
        "Google Chrome Canary" = "${env:LocalAppData}\Google\Chrome SxS\Application\chrome.exe"
    }

    # Function to get browser-specific update flags
    function Get-BrowserUpdateFlags {
        param (
            [string]$BrowserName
        )
        
        # Default flags
        $flags = "--check-for-update-interval=1"
        
        # Add browser-specific silent flags
        if ($BrowserName -like "*Chrome*") {
            # Chrome-specific silent flags
            $flags = "$flags --headless --silent --hide-crash-restore-bubble"
        }
        elseif ($BrowserName -like "*Edge*") {
            # Edge-specific silent flags
            $flags = "$flags --headless --silent --inprivate"
        }
        
        return $flags
    }

    # Function to update browser
    function Update-Browser {
        param (
            [string]$BrowserName,
            [string]$BrowserPath
        )
        
        try {
            Write-Host "Checking for $BrowserName updates..." -ForegroundColor Yellow
            
            # Get browser-specific update flags
            $updateFlags = Get-BrowserUpdateFlags -BrowserName $BrowserName
            
            # Start the browser with update flags
            Write-Host "  Starting silent update check for $BrowserName" -ForegroundColor Gray
            
            # Create a process with minimized window
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $BrowserPath
            $psi.Arguments = $updateFlags
            $psi.UseShellExecute = $true
            $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
            
            $process = [System.Diagnostics.Process]::Start($psi)
            Write-Host "  Update process started with PID: $($process.Id)" -ForegroundColor Gray
            
            # Keep track of the process ID for later cleanup
            $script:updateProcessIds += $process.Id
            
            # Minimize the browser window to avoid disruption
            Write-Host "  Minimizing browser window..." -ForegroundColor Gray
            Start-Sleep -Seconds 1
            
            # Wait a short time for the update to initialize
            Write-Host "  Waiting for update check to complete (max 30 seconds)..." -ForegroundColor Gray
            Start-Sleep -Seconds 30
            
            # Don't wait for the browser to exit, as update might continue in background
            if ($process -and -not $process.HasExited) {
                Write-Host "  Update is continuing in the background." -ForegroundColor Gray
            }
            
            Write-Host "Update check initiated for $BrowserName." -ForegroundColor Green
            return $true
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Warning "Error updating $($BrowserName): $errorMessage"
            return $false
        }
    }

    # Function to check for Windows updates related to browsers
    function Update-BrowsersViaWindowsUpdate {
        Write-Host "`nStep 3: Checking for browser-related Windows updates..." -ForegroundColor Yellow
        
        try {
            Write-Host "  Searching for browser-related Windows updates..." -ForegroundColor Gray
            
            # Get all available updates
            $allUpdates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction SilentlyContinue
            
            # Filter updates specifically for browsers with more precise criteria
            $browserUpdates = $allUpdates | Where-Object {
                $_.Title -match "Microsoft Edge|Edge WebView|Google Chrome|Firefox|Opera|Brave|Safari" -or
                ($_.Title -match "Browser" -and $_.Title -match "Security") -or
                ($_.KB -match "KB[0-9]+" -and $_.Title -match "Web|Browser|Internet")
            }
            
            if ($browserUpdates.Count -gt 0) {
                Write-Host "Found $($browserUpdates.Count) browser-related updates:" -ForegroundColor Green
                $browserUpdates | ForEach-Object { Write-Host "  - $($_.Title)" -ForegroundColor Green }
                
                Write-Host "`nInstalling browser-related updates..." -ForegroundColor Yellow
                $browserUpdates | Install-WindowsUpdate -AcceptAll -IgnoreReboot
                Write-Host "Browser updates installed via Windows Update." -ForegroundColor Green
                return $browserUpdates
            }
            else {
                Write-Host "No browser-related Windows updates found." -ForegroundColor Green
                return @()
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Error "Error checking for Windows updates: $errorMessage"
            return $null
        }
    }

    # Main execution
    Write-Host "`nStep 2: Checking and updating installed browsers directly..." -ForegroundColor Yellow
    
    # Track updated browsers
    $updatedBrowsers = @()
    
    # Check and update each browser
    foreach ($browser in $browserPaths.GetEnumerator()) {
        $browserPath = Test-BrowserInstalled -BrowserName $browser.Key -Paths $browser.Value
        
        if ($browserPath) {
            Write-Host "Found installed browser: $($browser.Key)" -ForegroundColor Green
            $success = Update-Browser -BrowserName $browser.Key -BrowserPath $browserPath
            
            if ($success) {
                $updatedBrowsers += $browser.Key
            }
        } else {
            Write-Host "$($browser.Key) is not installed." -ForegroundColor Gray
        }
    }

    # Check for Chrome variants using where.exe if not found by regular means
    if ($updatedBrowsers -notcontains "Google Chrome") {
        $chromePath = (where.exe chrome 2>$null | Select-Object -First 1)
        if ($chromePath -and (Test-Path $chromePath)) {
            Write-Host "Found Google Chrome using PATH: $chromePath" -ForegroundColor Green
            $success = Update-Browser -BrowserName "Google Chrome" -BrowserPath $chromePath
            if ($success) {
                $updatedBrowsers += "Google Chrome"
            }
        }
    }

    # Check and install browser updates via Windows Update
    $windowsUpdates = Update-BrowsersViaWindowsUpdate

    # Create and display summary report
    Create-SummaryReport -BrowserUpdates $browserUpdates -WindowsUpdates $windowsUpdates

    # Cleanup any lingering browser processes that were started for updates
    function Cleanup-UpdateProcesses {
        Write-Host "`nCleaning up any lingering update processes..." -ForegroundColor Yellow
        
        # Create a list of browser processes we may have started with specific command line patterns
        $browserProcessNames = @(
            "msedge",  # Microsoft Edge
            "chrome",  # Google Chrome
            "edge"     # Another Edge process name variant
        )
        
        # Use WMI to get process information including command lines
        try {
            $updateProcesses = Get-WmiObject Win32_Process | Where-Object {
                # Check if it's a browser process
                $browserProcessNames -contains $_.Name.Replace(".exe", "") -and
                # Check if its command line contains update flags
                ($_.CommandLine -match "--check-for-update-interval" -or
                 $_.CommandLine -match "--headless" -or
                 $_.CommandLine -match "--silent")
            }
            
            if ($updateProcesses.Count -gt 0) {
                Write-Host "  Found $($updateProcesses.Count) lingering update processes" -ForegroundColor Gray
                
                # Attempt to terminate each process - suppress individual error messages
                $terminatedCount = 0
                foreach ($process in $updateProcesses) {
                    try {
                        $process.Terminate() | Out-Null
                        $terminatedCount++
                    }
                    catch {
                        # Silently continue on error
                    }
                }
                
                # Just report the summary
                Write-Host "  $terminatedCount of $($updateProcesses.Count) processes terminated successfully." -ForegroundColor Green
            }
            else {
                Write-Host "  No lingering update processes found." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  Error cleaning up processes: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Call the cleanup function
    Cleanup-UpdateProcesses

    Write-Host "Browser update process completed." -ForegroundColor Cyan
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
    Write-Host "`nPress any key to close this window..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} 