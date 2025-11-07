# WSL Information and Management Tool
# This script provides detailed information about WSL instances and offers additional
# functionality for managing, troubleshooting, and optimizing WSL environments.

# Check if script is running with administrative privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# If not running as admin, relaunch the script with admin rights
if (-not (Test-Admin)) {
    Write-Host "This script requires administrative privileges. Relaunching with elevated rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Set console colors
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

function Show-Header {
    param (
        [string]$Title
    )
    
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=============================================`n" -ForegroundColor Cyan
}

function Get-WSLStatus {
    Show-Header "WSL SYSTEM STATUS"
    
    # Check WSL Version
    $wslInfo = wsl --status
    Write-Host $wslInfo
    
    # Check if WSL is enabled in Windows features
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
    
    Write-Host "`nWindows Features Status:" -ForegroundColor Green
    Write-Host "- WSL Feature: $($wslFeature.State)" -ForegroundColor $(if ($wslFeature.State -eq "Enabled") { "Green" } else { "Red" })
    Write-Host "- VM Platform: $($vmFeature.State)" -ForegroundColor $(if ($vmFeature.State -eq "Enabled") { "Green" } else { "Red" })
    
    # Get installed distributions using Get-WSLNames.ps1
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "`nNo WSL distributions found." -ForegroundColor Yellow
        return
    }
    
    # Get default distribution
    $defaultDistro = wsl -l --quiet | Where-Object { $_ -match '\S' } | Select-Object -First 1
    
    Write-Host "`nInstalled Distributions:" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    
    foreach ($distro in $distributions) {
        if (-not [string]::IsNullOrWhiteSpace($distro)) {
            Write-Host "`nChecking $distro..." -ForegroundColor Green
            
            try {
                # Get kernel version
                $kernelVersion = wsl -d $distro -e uname -r 2>$null
                if ($kernelVersion) {
                    Write-Host "- Kernel Version: $kernelVersion" -ForegroundColor Cyan
                }
                
                # Get OS version
                $osVersion = wsl -d $distro -e cat /etc/os-release 2>$null
                if ($osVersion -match "PRETTY_NAME=") {
                    $prettyName = ($osVersion | Select-String -Pattern "PRETTY_NAME=").Line -replace 'PRETTY_NAME="(.*)"', '$1'
                    Write-Host "- OS Version: $prettyName" -ForegroundColor Cyan
                }
                
                # Get state
                $wslInfo = wsl --list --verbose | Where-Object { $_ -match $distro }
                $state = if ($wslInfo -match "Running") { "Running" } else { "Stopped" }
                Write-Host "- State: $state" -ForegroundColor $(if ($state -eq "Running") { "Green" } else { "Yellow" })
                
                # Check if default
                $isDefault = ($distro -eq $defaultDistro)
                if ($isDefault) {
                    Write-Host "- Default: Yes" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "- Error retrieving information: $_" -ForegroundColor Red
            }
        }
    }
}

function Get-WSLDistributions {
    Show-Header "WSL DISTRIBUTIONS"
    
    # Get installed distributions using Get-WSLNames.ps1
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "`nNo WSL distributions found." -ForegroundColor Yellow
        return
    }
    
    # Get default distribution
    $defaultDistro = wsl -l --quiet | Where-Object { $_ -match '\S' } | Select-Object -First 1
    
    # Get state information for each distribution
    $distributionInfo = @()
    foreach ($distro in $distributions) {
        $state = "Stopped"
        $version = "2"
        
        # Get state and version information
        $wslInfo = wsl --list --verbose | Where-Object { $_ -match $distro }
        if ($wslInfo -match "Running") {
            $state = "Running"
        }
        if ($wslInfo -match "1$") {
            $version = "1"
        }
        
        $distributionInfo += [PSCustomObject]@{
            Name = $distro
            State = $state
            Version = $version
            IsDefault = ($distro -eq $defaultDistro)
        }
    }
    
    # Create a more attractive header
    Write-Host "`nNAME                  STATE           VERSION    DEFAULT" -ForegroundColor Green
    Write-Host "=====================================================" -ForegroundColor Green
    
    # Display distribution information with proper formatting
    foreach ($info in $distributionInfo) {
        $defaultMark = if ($info.IsDefault) { "*" } else { " " }
        $nameCol = "{0,-20}" -f $info.Name
        $stateCol = "{0,-15}" -f $info.State
        $versionCol = "{0,-10}" -f $info.Version
        $defaultText = if ($info.IsDefault) { "Yes" } else { "No" }
        
        # Color based on state
        $color = switch ($info.State) {
            "Running" { "Green" }
            "Stopped" { "Yellow" }
            default { "White" }
        }
        
        Write-Host "$defaultMark$nameCol$stateCol$versionCol$defaultText" -ForegroundColor $color
    }
    
    # Show total count
    Write-Host "`nTotal WSL Distributions: $($distributionInfo.Count)" -ForegroundColor Green
    
    # Additional actions
    Write-Host "`nAdditional Options:" -ForegroundColor Cyan
    Write-Host "1. Start a distribution" -ForegroundColor White
    Write-Host "2. Stop a distribution" -ForegroundColor White
    Write-Host "3. Set default distribution" -ForegroundColor White
    Write-Host "4. Show detailed distribution info" -ForegroundColor White
    Write-Host "5. Return to main menu" -ForegroundColor White
    
    $action = Read-Host "`nSelect an option (1-5)"
    
    switch ($action) {
        "1" {
            # Start a distribution
            $stoppedDistros = $distributionInfo | Where-Object { $_.State -eq "Stopped" }
            
            if ($stoppedDistros.Count -eq 0) {
                Write-Host "No stopped distributions found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nStopped Distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $stoppedDistros.Count; $i++) {
                Write-Host "  $($i+1). $($stoppedDistros[$i].Name)" -ForegroundColor White
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to start (1-$($stoppedDistros.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            try {
                $selectedDistro = $stoppedDistros[$distroIndex-1].Name
                Write-Host "Starting $selectedDistro..." -ForegroundColor Yellow
                wsl -d $selectedDistro
                Write-Host "$selectedDistro has been started." -ForegroundColor Green
            } catch {
                Write-Host "Error starting distribution: $_" -ForegroundColor Red
            }
        }
        "2" {
            # Stop a distribution
            $runningDistros = $distributionInfo | Where-Object { $_.State -eq "Running" }
            
            if ($runningDistros.Count -eq 0) {
                Write-Host "No running distributions found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nRunning Distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $runningDistros.Count; $i++) {
                Write-Host "  $($i+1). $($runningDistros[$i].Name)" -ForegroundColor White
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to stop (1-$($runningDistros.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            try {
                $selectedDistro = $runningDistros[$distroIndex-1].Name
                Write-Host "Stopping $selectedDistro..." -ForegroundColor Yellow
                wsl --terminate $selectedDistro
                Write-Host "$selectedDistro has been stopped." -ForegroundColor Green
            } catch {
                Write-Host "Error stopping distribution: $_" -ForegroundColor Red
            }
        }
        "3" {
            # Set default distribution
            Write-Host "`nAvailable Distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $distributionInfo.Count; $i++) {
                $defaultMark = if ($distributionInfo[$i].IsDefault) { " (current default)" } else { "" }
                Write-Host "  $($i+1). $($distributionInfo[$i].Name)$defaultMark" -ForegroundColor White
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to set as default (1-$($distributionInfo.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            try {
                $selectedDistro = $distributionInfo[$distroIndex-1].Name
                Write-Host "Setting $selectedDistro as default..." -ForegroundColor Yellow
                wsl --set-default $selectedDistro
                Write-Host "$selectedDistro is now the default distribution." -ForegroundColor Green
            } catch {
                Write-Host "Error setting default distribution: $_" -ForegroundColor Red
            }
        }
        "4" {
            # Show detailed info for a specific distribution
            Write-Host "`nAvailable Distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $distributionInfo.Count; $i++) {
                Write-Host "  $($i+1). $($distributionInfo[$i].Name)" -ForegroundColor White
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to show details (1-$($distributionInfo.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            try {
                $selectedDistro = $distributionInfo[$distroIndex-1].Name
                Write-Host "`nFetching details for $selectedDistro..." -ForegroundColor Yellow
                
                # Get distribution information
                $versionInfo = wsl -d $selectedDistro -e cat /etc/os-release 2>$null
                $kernelInfo = wsl -d $selectedDistro -e uname -a 2>$null
                $diskInfo = wsl -d $selectedDistro -e df -h / 2>$null | Select-Object -Skip 1
                $memoryInfo = wsl -d $selectedDistro -e free -h 2>$null | Select-Object -Skip 1 | Select-Object -First 1
                
                # Format the header
                Write-Host "`nDistribution Details for $selectedDistro" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                
                # Format and display kernel information
                Write-Host "`nKernel Information:" -ForegroundColor Cyan
                foreach ($line in $kernelInfo) {
                    Write-Host "  $line" -ForegroundColor White
                }
                
                # Extract and display OS information
                $prettyName = ($versionInfo | Select-String -Pattern "PRETTY_NAME=").Line -replace 'PRETTY_NAME="(.*)"', '$1'
                if ($prettyName) {
                    Write-Host "`nOS Version:" -ForegroundColor Cyan
                    Write-Host "  $prettyName" -ForegroundColor White
                }
                
                # Format and display disk usage
                Write-Host "`nDisk Usage:" -ForegroundColor Cyan
                Write-Host "  Filesystem      Size    Used    Avail   Use%   Mounted on" -ForegroundColor White
                Write-Host "  --------------------------------------------------------" -ForegroundColor White
                
                # Parse and format disk info
                foreach ($line in $diskInfo) {
                    if ($line -match '(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)') {
                        $fs = $matches[1]
                        $size = $matches[2]
                        $used = $matches[3]
                        $avail = $matches[4]
                        $usePercent = $matches[5]
                        $mountPoint = $matches[6]
                        
                        $diskLine = "  {0,-14} {1,-8} {2,-8} {3,-8} {4,-7} {5}" -f $fs, $size, $used, $avail, $usePercent, $mountPoint
                        Write-Host $diskLine -ForegroundColor White
                    }
                }
                
                # Format and display memory information
                Write-Host "`nMemory Information:" -ForegroundColor Cyan
                Write-Host "  Type     Total    Used     Free     Shared   Buffers  Available" -ForegroundColor White
                Write-Host "  ----------------------------------------------------------------" -ForegroundColor White
                
                # Parse and format memory info
                foreach ($line in $memoryInfo) {
                    if ($line -match '(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)') {
                        $type = $matches[1]
                        $total = $matches[2]
                        $used = $matches[3]
                        $free = $matches[4]
                        $shared = $matches[5]
                        $buffers = $matches[6]
                        $available = $matches[7]
                        
                        $memLine = "  {0,-8} {1,-8} {2,-8} {3,-8} {4,-8} {5,-8} {6,-8}" -f $type, $total, $used, $free, $shared, $buffers, $available
                        Write-Host $memLine -ForegroundColor White
                    }
                }
                
                # Reset console after displaying all information
                $Host.UI.RawUI.BackgroundColor = "Black"
                $Host.UI.RawUI.ForegroundColor = "White"
                [Console]::ResetColor()
                
            } catch {
                Write-Host "Error retrieving distribution details: $_" -ForegroundColor Red
            }
        }
        "5" {
            # Return to main menu
            return
        }
        default {
            Write-Host "Invalid option. Returning to main menu." -ForegroundColor Red
        }
    }
}

function Get-WSLResourceUsage {
    Show-Header "WSL RESOURCE USAGE"
    
    # Get installed distributions using Get-WSLNames.ps1
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "No WSL distributions found." -ForegroundColor Yellow
        return
    }
    
    # Start distributions if they're not running
    foreach ($distro in $distributions) {
        $isRunning = wsl --list --verbose | Where-Object { $_ -match $distro -and $_ -match "Running" }
        if (-not $isRunning) {
            Write-Host "Starting $distro..." -ForegroundColor Yellow
            wsl -d $distro -e echo "Starting distribution" 2>$null
            Start-Sleep -Seconds 2  # Give it a moment to start
        }
    }
    
    # Global WSL memory usage
    $wslMemory = Get-Process -Name "wslhost" -ErrorAction SilentlyContinue | Measure-Object WorkingSet -Sum
    if ($wslMemory.Sum -gt 0) {
        $memoryInMB = [math]::Round($wslMemory.Sum / 1MB, 2)
        Write-Host "Total WSL Memory Usage: $memoryInMB MB" -ForegroundColor Green
    }
    else {
        Write-Host "No running WSL instances detected." -ForegroundColor Yellow
        return
    }
    
    # CPU usage
    $wslCPU = Get-Process -Name "wslhost" -ErrorAction SilentlyContinue | Measure-Object CPU -Sum
    if ($wslCPU.Sum -gt 0) {
        $cpuUsage = [math]::Round($wslCPU.Sum, 2)
        Write-Host "Total WSL CPU Usage: $cpuUsage%" -ForegroundColor Green
    }
    
    # Disk space for each distribution
    Write-Host "`nDisk Space Usage:" -ForegroundColor Green
    foreach ($distro in $distributions) {
        if (-not [string]::IsNullOrWhiteSpace($distro)) {
            try {
                $diskUsage = wsl -d $distro -e df -h /  2>$null | Select-Object -Skip 1
                if ($diskUsage) {
                    Write-Host "- $($distro) Disk Usage:" -ForegroundColor Cyan
                    foreach ($line in $diskUsage) {
                        Write-Host "  $line" -ForegroundColor White
                    }
                }
            }
            catch {
                Write-Host "- $($distro): Unable to get disk usage" -ForegroundColor Yellow
            }
        }
    }
    
    # Memory usage for each distribution
    Write-Host "`nMemory Usage per Distribution:" -ForegroundColor Green
    foreach ($distro in $distributions) {
        if (-not [string]::IsNullOrWhiteSpace($distro)) {
            try {
                $memoryInfo = wsl -d $distro -e free -h 2>$null
                if ($memoryInfo) {
                    Write-Host "`n$($distro) Memory Usage:" -ForegroundColor Cyan
                    foreach ($line in $memoryInfo) {
                        Write-Host "  $line" -ForegroundColor White
                    }
                }
            }
            catch {
                Write-Host ("Error retrieving information for {0}: {1}" -f $distro, $_) -ForegroundColor Red
            }
        }
    }
    
    # Reset console after displaying all information
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    [Console]::ResetColor()
}

function Get-WSLNetworkInfo {
    Show-Header "WSL NETWORK INFORMATION"
    
    # Display WSL IP addresses
    $wslDistros = (wsl --list --quiet) -split "`n" | Where-Object { $_ -and $_ -ne "Windows" }
    
    Write-Host "WSL IP Addresses:" -ForegroundColor Green
    foreach ($distro in $wslDistros) {
        if ($distro -and $distro.Trim() -ne "") {
            try {
                $ipInfo = wsl -d $distro -e ip -4 addr show eth0 2>$null | Select-String -Pattern "inet "
                if ($ipInfo) {
                    $ip = $ipInfo -replace ".*inet\s+([0-9.]+)\/.*", '$1'
                    Write-Host "- $($distro): $ip" -ForegroundColor Cyan
                }
                else {
                    Write-Host "- $($distro): No IP found" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "- $($distro): Unable to get IP address" -ForegroundColor Yellow
            }
        }
    }
    
    # Check WSL network adapter
    Write-Host "`nWSL Network Adapter:" -ForegroundColor Green
    $wslAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" }
    if ($wslAdapter) {
        Write-Host "- Name: $($wslAdapter.Name)" -ForegroundColor Cyan
        Write-Host "- Status: $($wslAdapter.Status)" -ForegroundColor Cyan
        Write-Host "- MAC Address: $($wslAdapter.MacAddress)" -ForegroundColor Cyan
    }
    else {
        Write-Host "- No WSL network adapter found" -ForegroundColor Yellow
    }
}

function Test-WSLConnectivity {
    Show-Header "WSL CONNECTIVITY TEST"
    
    # Get installed distributions using Get-WSLNames.ps1
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "`nNo WSL distributions found." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nTesting connectivity for installed WSL distributions:" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    
    foreach ($distro in $distributions) {
        if (-not [string]::IsNullOrWhiteSpace($distro)) {
            Write-Host "`nTesting $distro..." -ForegroundColor Green
            
            try {
                # Check internet connectivity
                $pingResult = wsl -d $distro -e ping -c 2 8.8.8.8 2>$null
                
                if ($pingResult -match "bytes from") {
                    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
                }
                else {
                    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
                }
                
                # Check DNS resolution
                $dnsResult = wsl -d $distro -e ping -c 1 google.com 2>$null
                
                if ($dnsResult -match "bytes from") {
                    Write-Host "- DNS resolution: OK" -ForegroundColor Green
                }
                else {
                    Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "- Could not test connectivity (distribution may not be running)" -ForegroundColor Yellow
            }
        }
    }
}

function Optimize-WSL {
    Show-Header "WSL OPTIMIZATION"
    
    # Create or update .wslconfig file
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    
    $currentMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $recommendedMemory = [Math]::Floor($currentMemory / 2)
    $recommendedProcessors = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors / 2
    
    if ($recommendedMemory -lt 2) { $recommendedMemory = 2 }
    if ($recommendedProcessors -lt 2) { $recommendedProcessors = 2 }
    
    Write-Host "System has $([Math]::Floor($currentMemory))GB RAM and $((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors) logical processors" -ForegroundColor Cyan
    
    if (Test-Path $wslConfigPath) {
        Write-Host "Found existing .wslconfig file. Current settings:" -ForegroundColor Yellow
        Get-Content $wslConfigPath | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        $updateConfig = Read-Host "`nDo you want to update the configuration? (Y/N)"
        if ($updateConfig -ne "Y" -and $updateConfig -ne "y") {
            return
        }
    }
    
    Write-Host "`nRecommended settings:" -ForegroundColor Green
    Write-Host "- Memory: ${recommendedMemory}GB" -ForegroundColor Cyan
    Write-Host "- Processors: $recommendedProcessors" -ForegroundColor Cyan
    
    $configMemory = Read-Host "Enter memory limit in GB (default: $recommendedMemory)"
    if (-not $configMemory) { $configMemory = $recommendedMemory }
    
    $configProcessors = Read-Host "Enter number of processors (default: $recommendedProcessors)"
    if (-not $configProcessors) { $configProcessors = $recommendedProcessors }
    
    $configSwap = Read-Host "Enter swap size in GB (default: 4)"
    if (-not $configSwap) { $configSwap = 4 }
    
    $wslConfig = @"
[wsl2]
memory=$($configMemory)GB
processors=$configProcessors
swap=$($configSwap)GB
localhostForwarding=true
kernelCommandLine=quiet
"@
    
    try {
        $wslConfig | Out-File -FilePath $wslConfigPath -Encoding ascii -Force
        Write-Host "`nWSL configuration updated successfully. Please restart WSL for changes to take effect." -ForegroundColor Green
        Write-Host "Run 'wsl --shutdown' to restart WSL" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Failed to update WSL configuration: $_" -ForegroundColor Red
    }
}

function Repair-WSL {
    Show-Header "WSL REPAIR TOOLS"
    
    Write-Host "1. Reset WSL Network" -ForegroundColor Cyan
    Write-Host "2. Repair WSL Registration" -ForegroundColor Cyan
    Write-Host "3. Reset WSL Instance" -ForegroundColor Cyan
    Write-Host "4. Reinstall WSL Components" -ForegroundColor Cyan
    Write-Host "5. Back to Main Menu" -ForegroundColor Cyan
    
    $repairOption = Read-Host "`nSelect an option (1-5)"
    
    switch ($repairOption) {
        "1" {
            Write-Host "`nResetting WSL network..." -ForegroundColor Yellow
            
            # Get installed distributions using Get-WSLNames.ps1
            $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
            $distributions = @(& $scriptPath -Installed)
            
            if ($null -eq $distributions -or $distributions.Count -eq 0) {
                Write-Host "No WSL distributions found." -ForegroundColor Yellow
                return
            }
            
            # Shutdown WSL
            wsl --shutdown
            
            # Disable and enable WSL network adapter
            Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" } | Disable-NetAdapter -Confirm:$false
            Start-Sleep -Seconds 2
            Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" } | Enable-NetAdapter -Confirm:$false
            
            Write-Host "WSL network reset complete. Restarting WSL..." -ForegroundColor Green
            
            # Start the first available distribution
            if ($distributions.Count -gt 0) {
                $firstDistro = $distributions[0]
                wsl -d $firstDistro -e echo "WSL Restarted" 2>$null
            }
        }
        "2" {
            Write-Host "`nRepairing WSL registrations..." -ForegroundColor Yellow
            
            # Get installed distributions using Get-WSLNames.ps1
            $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
            $distributions = @(& $scriptPath -Installed)
            
            if ($null -eq $distributions -or $distributions.Count -eq 0) {
                Write-Host "No WSL distributions found to repair." -ForegroundColor Yellow
                return
            }
            
            foreach ($distro in $distributions) {
                if ($distro -and $distro.Trim() -ne "") {
                    try {
                        Write-Host "Reregistering $distro..." -ForegroundColor Cyan
                        
                        # Check if distribution is running and terminate it if needed
                        $wslInfo = wsl --list --verbose | Where-Object { $_ -match $distro }
                        if ($wslInfo -match "Running") {
                            wsl --terminate $distro
                            Start-Sleep -Seconds 2
                        }
                        
                        # Shutdown WSL to ensure clean state
                        wsl --shutdown
                        Start-Sleep -Seconds 2
                        
                        # Verify the distribution
                        $testResult = wsl -d $distro -e echo "WSL distribution check" 2>$null
                        if ($testResult) {
                            Write-Host "$distro registration verified." -ForegroundColor Green
                        } else {
                            Write-Host "Could not verify $distro. It may need manual repair." -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host ("Error processing {0}: {1}" -f $distro, $_) -ForegroundColor Red
                    }
                }
            }
            
            Write-Host "`nWSL registration repair completed." -ForegroundColor Green
        }
        "3" {
            # Get installed distributions using Get-WSLNames.ps1
            $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
            $distributions = @(& $scriptPath -Installed)
            
            if ($null -eq $distributions -or $distributions.Count -eq 0) {
                Write-Host "`nNo WSL distributions found to reset." -ForegroundColor Yellow
                return
            }
            
            # Get all available Ubuntu distributions from online list
            $onlineDistros = @(& $scriptPath -Online)
            $ubuntuDistros = $onlineDistros | Where-Object { $_ -match "^Ubuntu" }
            
            Write-Host "`nAvailable WSL instances:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $distributions.Count; $i++) {
                Write-Host "$($i+1). $($distributions[$i])" -ForegroundColor Cyan
            }
            
            Write-Host "`nAvailable Ubuntu distributions online:" -ForegroundColor Green
            for ($i = 0; $i -lt $ubuntuDistros.Count; $i++) {
                Write-Host "$($i+1). $($ubuntuDistros[$i])" -ForegroundColor White
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to reset (1-$($distributions.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            $selectedDistro = $distributions[$distroIndex - 1]
            $confirmation = Read-Host "Are you sure you want to reset $selectedDistro? This will unregister and re-register the distribution. (Y/N)"
            
            if ($confirmation -eq "Y" -or $confirmation -eq "y") {
                Write-Host "Resetting $selectedDistro..." -ForegroundColor Yellow
                
                try {
                    # Terminate the distribution if it's running
                    wsl --terminate $selectedDistro 2>$null
                    
                    # Unregister the distribution
                    Write-Host "Unregistering $selectedDistro..." -ForegroundColor Cyan
                    wsl --unregister $selectedDistro
                    
                    # Get the correct online distribution name
                    $baseName = $selectedDistro -replace '-\d+$'  # Remove version number if present
                    $baseName = $baseName -replace '-g$'  # Remove -g suffix if present
                    $onlineName = $ubuntuDistros | Where-Object { $_ -match "^$baseName" } | Select-Object -First 1
                    
                    if (-not $onlineName) {
                        Write-Host "`nCould not find exact matching online distribution for $selectedDistro" -ForegroundColor Red
                        Write-Host "`nAvailable Ubuntu distributions:" -ForegroundColor Yellow
                        for ($i = 0; $i -lt $ubuntuDistros.Count; $i++) {
                            Write-Host "$($i+1). $($ubuntuDistros[$i])" -ForegroundColor White
                        }
                        
                        $onlineIndex = Read-Host "`nSelect an online distribution to install (1-$($ubuntuDistros.Count)), or 0 to cancel"
                        if ($onlineIndex -eq "0" -or [string]::IsNullOrEmpty($onlineIndex)) {
                            return
                        }
                        
                        $onlineName = $ubuntuDistros[$onlineIndex - 1]
                    }
                    
                    # Reinstall the distribution
                    Write-Host "Reinstalling $selectedDistro using $onlineName..." -ForegroundColor Cyan
                    wsl --install -d $onlineName
                    
                    Write-Host "$selectedDistro has been reset. You may need to set up a new user account." -ForegroundColor Green
                }
                catch {
                    Write-Host "Error resetting WSL instance: $_" -ForegroundColor Red
                }
            }
        }
        "4" {
            $confirmation = Read-Host "`nThis will reinstall WSL components. Continue? (Y/N)"
            
            if ($confirmation -eq "Y" -or $confirmation -eq "y") {
                Write-Host "Reinstalling WSL components..." -ForegroundColor Yellow
                wsl --shutdown
                
                # Enable WSL features
                dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
                dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
                
                Write-Host "WSL components reinstalled. A system restart is recommended." -ForegroundColor Green
                $restartNow = Read-Host "Do you want to restart now? (Y/N)"
                
                if ($restartNow -eq "Y" -or $restartNow -eq "y") {
                    Restart-Computer -Force
                }
            }
        }
        "5" {
            # Return to main menu
            return
        }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
        }
    }
}

function New-WSLInstance {
    Show-Header "CREATE NEW WSL INSTANCE"
    
    # List available distributions
    Write-Host "Fetching available WSL distributions..." -ForegroundColor Yellow
    $availableDistros = wsl --list --online | Select-Object -Skip 1
    
    Write-Host "`nAvailable distributions:" -ForegroundColor Green
    $availableDistros | ForEach-Object {
        $distroLine = $_ -replace '^\s+', ''
        Write-Host "- $distroLine" -ForegroundColor Cyan
    }
    
    $distroName = Read-Host "`nEnter the name of the distribution to install (e.g., Ubuntu-20.04)"
    if (-not $distroName) {
        Write-Host "Installation canceled." -ForegroundColor Yellow
        return
    }
    
    # Installation confirmation
    $confirmation = Read-Host "Do you want to install $distroName? (Y/N)"
    if ($confirmation -ne "Y" -and $confirmation -ne "y") {
        return
    }
    
    # Install the distribution
    Write-Host "`nInstalling $distroName. This may take several minutes..." -ForegroundColor Yellow
    try {
        wsl --install -d $distroName
        Write-Host "`nInstallation completed. Launching distribution for first-time setup..." -ForegroundColor Green
        Write-Host "Note: You'll need to create a username and password in the terminal that opens." -ForegroundColor Yellow
        
        # Wait a moment for the installation to complete
        Start-Sleep -Seconds 5
        
        # Launch the distribution
        wsl -d $distroName
    }
    catch {
        Write-Host "Error installing distribution: $_" -ForegroundColor Red
    }
}

function Remove-WSLInstance {
    Show-Header "DELETE WSL INSTANCE"
    
    # Get installed distributions using Get-WSLNames.ps1
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "No WSL distributions found to delete." -ForegroundColor Yellow
        return
    }
    
    # Format and display distributions
    Write-Host "Installed WSL distributions:" -ForegroundColor Green
    for ($i = 0; $i -lt $distributions.Count; $i++) {
        Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
    }
    
    $distroIndex = Read-Host "`nSelect a distribution to delete (1-$($distributions.Count)), or 0 to cancel"
    if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
        return
    }
    
    try {
        $selectedDistro = $distributions[$distroIndex - 1]
        
        Write-Host "`nWARNING: This will permanently delete the $selectedDistro distribution and all its data!" -ForegroundColor Red
        $finalConfirmation = Read-Host "Type 'DELETE' to confirm deletion of $selectedDistro"
        
        if ($finalConfirmation -eq "DELETE") {
            Write-Host "Unregistering $selectedDistro..." -ForegroundColor Yellow
            wsl --unregister $selectedDistro
            Write-Host "Successfully deleted $selectedDistro." -ForegroundColor Green
        }
        else {
            Write-Host "Deletion canceled." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error during deletion: $_" -ForegroundColor Red
    }
}

function Rename-WSLInstance {
    Show-Header "RENAME WSL INSTANCE"
    
    Write-Host "Note: Renaming requires exporting and importing the distribution, which may take time." -ForegroundColor Yellow
    
    # Get installed distributions using Get-WSLNames.ps1
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "No WSL distributions found to rename." -ForegroundColor Yellow
        return
    }
    
    # Format and display distributions
    Write-Host "`nInstalled WSL distributions:" -ForegroundColor Green
    for ($i = 0; $i -lt $distributions.Count; $i++) {
        Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
    }
    
    $distroIndex = Read-Host "`nSelect a distribution to rename (1-$($distributions.Count)), or 0 to cancel"
    if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
        return
    }
    
    try {
        $selectedDistro = $distributions[$distroIndex - 1]
        $newName = Read-Host "Enter new name for $selectedDistro"
        
        if ([string]::IsNullOrEmpty($newName)) {
            Write-Host "Rename canceled. New name cannot be empty." -ForegroundColor Yellow
            return
        }
        
        # Check if the new name already exists
        $existingDistros = @(& $scriptPath -Installed)
        if ($existingDistros -contains $newName) {
            Write-Host "A distribution with the name '$newName' already exists. Choose a different name." -ForegroundColor Red
            return
        }
        
        $confirmation = Read-Host "Rename $selectedDistro to $newName? (Y/N)"
        if ($confirmation -ne "Y" -and $confirmation -ne "y") {
            return
        }
        
        # Create temp directory
        $tempDir = "$env:TEMP\WSL-Rename"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir | Out-Null
        }
        
        $exportPath = "$tempDir\$selectedDistro.tar"
        
        # Export the distribution
        Write-Host "`nExporting $selectedDistro... This may take several minutes." -ForegroundColor Yellow
        wsl --export $selectedDistro $exportPath
        
        if (-not (Test-Path $exportPath)) {
            Write-Host "Export failed. Rename operation canceled." -ForegroundColor Red
            return
        }
        
        # Import with the new name
        Write-Host "Importing as $newName... This may take several minutes." -ForegroundColor Yellow
        wsl --import $newName $tempDir\$newName $exportPath
        
        # Verify the import was successful
        $newDistroExists = @(& $scriptPath -Installed) -contains $newName
        
        if ($newDistroExists) {
            # Unregister the old distribution
            Write-Host "Removing old distribution $selectedDistro..." -ForegroundColor Yellow
            wsl --unregister $selectedDistro
            
            # Cleanup
            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            Remove-Item $exportPath -Force
            Remove-Item $tempDir -Recurse -Force
            
            Write-Host "`nRenamed $selectedDistro to $newName successfully." -ForegroundColor Green
            Write-Host "Note: You may need to set up a default user for the renamed distribution." -ForegroundColor Yellow
        }
        else {
            Write-Host "Import failed. The original distribution is still available." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error during rename: $_" -ForegroundColor Red
    }
}

function Update-WSLInstance {
    Show-Header "UPDATE WSL INSTANCE"
    
    # Get installed distributions using Get-WSLNames.ps1
    Write-Host "Retrieving WSL distributions..." -ForegroundColor Yellow
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "`nNo WSL distributions found." -ForegroundColor Yellow
        return
    }
    
    # Get default distribution
    $defaultDistro = wsl -l --quiet | Where-Object { $_ -match '\S' } | Select-Object -First 1
    
    Write-Host "`nInstalled distributions:" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    
    for ($i = 0; $i -lt $distributions.Count; $i++) {
        $defaultMark = if ($distributions[$i] -eq $defaultDistro) { " (Default)" } else { "" }
        Write-Host "  $($i+1). $($distributions[$i])$defaultMark" -ForegroundColor Cyan
    }
    
    Write-Host "`nUpdate options:" -ForegroundColor Green
    Write-Host "1. Update WSL kernel" -ForegroundColor Cyan
    Write-Host "2. Update a specific distribution" -ForegroundColor Cyan
    Write-Host "3. Update all distributions" -ForegroundColor Cyan
    Write-Host "4. Back to main menu" -ForegroundColor Cyan
    
    $updateOption = Read-Host "`nSelect an option (1-4)"
    
    switch ($updateOption) {
        "1" {
            # Update the WSL kernel
            Write-Host "`nUpdating WSL kernel..." -ForegroundColor Yellow
            wsl --update
            Write-Host "WSL kernel updated successfully." -ForegroundColor Green
        }
        "2" {
            # Update a specific distribution
            Write-Host "`nSelect a distribution to update:" -ForegroundColor Green
            for ($i = 0; $i -lt $distributions.Count; $i++) {
                $defaultMark = if ($distributions[$i] -eq $defaultDistro) { " (Default)" } else { "" }
                Write-Host "  $($i+1). $($distributions[$i])$defaultMark" -ForegroundColor Cyan
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to update (1-$($distributions.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            # Validate user input
            try {
                $index = [int]$distroIndex - 1
                if ($index -lt 0 -or $index -ge $distributions.Count) {
                    Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                    return
                }
                $selectedDistro = $distributions[$index]
            } catch {
                Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
                return
            }
            
            try {
                Write-Host "`nUpdating $selectedDistro..." -ForegroundColor Yellow
                
                # Check if the distribution is accessible
                $testCmd = "wsl --distribution `"$selectedDistro`" --exec echo 'Testing connection'"
                Write-Host "Testing connection to distribution..." -ForegroundColor Yellow
                $testResult = Invoke-Expression $testCmd
                
                if (-not $testResult) {
                    Write-Host "Could not connect to distribution $selectedDistro. Make sure it exists and is running." -ForegroundColor Red
                    return
                }
                
                # Get distribution info
                Write-Host "Checking distribution type..." -ForegroundColor Yellow
                $osReleaseCmd = "wsl --distribution `"$selectedDistro`" --exec cat /etc/os-release"
                $distroInfo = Invoke-Expression $osReleaseCmd
                
                # Extract distribution type from OS release
                $distroType = "Unknown"
                if ($distroInfo -match "ID=(\w+)") {
                    $distroType = $matches[1]
                }
                
                Write-Host "Distribution type: $distroType" -ForegroundColor Green
                
                # Determine update command based on distribution type
                switch -regex ($distroType) {
                    "ubuntu|debian" {
                        Write-Host "Detected Ubuntu/Debian-based distribution." -ForegroundColor Cyan
                        $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                        Invoke-Expression $updateCmd
                    }
                    "fedora|rhel" {
                        Write-Host "Detected Fedora/RHEL-based distribution." -ForegroundColor Cyan
                        $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo dnf update -y'"
                        Invoke-Expression $updateCmd
                    }
                    "arch" {
                        Write-Host "Detected Arch-based distribution." -ForegroundColor Cyan
                        $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo pacman -Syu --noconfirm'"
                        Invoke-Expression $updateCmd
                    }
                    default {
                        if ($selectedDistro -match "ubuntu|Ubuntu") {
                            Write-Host "Distribution name suggests Ubuntu. Using apt package manager." -ForegroundColor Cyan
                            $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                            Invoke-Expression $updateCmd
                        } else {
                            Write-Host "Could not determine distribution type. Please select package manager:" -ForegroundColor Yellow
                            Write-Host "1. apt (Ubuntu/Debian)" -ForegroundColor White
                            Write-Host "2. dnf (Fedora/RHEL)" -ForegroundColor White
                            Write-Host "3. pacman (Arch)" -ForegroundColor White
                            Write-Host "4. Cancel update" -ForegroundColor White
                            
                            $pkgManager = Read-Host "Select an option (1-4)"
                            
                            switch ($pkgManager) {
                                "1" {
                                    $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                                    Invoke-Expression $updateCmd
                                }
                                "2" {
                                    $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo dnf update -y'"
                                    Invoke-Expression $updateCmd
                                }
                                "3" {
                                    $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo pacman -Syu --noconfirm'"
                                    Invoke-Expression $updateCmd
                                }
                                "4" {
                                    Write-Host "Update canceled." -ForegroundColor Yellow
                                    return
                                }
                                default {
                                    Write-Host "Invalid option. Update canceled." -ForegroundColor Red
                                    return
                                }
                            }
                        }
                    }
                }
                
                Write-Host "Update completed for $selectedDistro." -ForegroundColor Green
            } catch {
                Write-Host ("Error updating " + $selectedDistro + ": " + $_) -ForegroundColor Red
            }
        }
        "3" {
            # Update all distributions
            Write-Host "`nUpdating all WSL distributions... This may take a while." -ForegroundColor Yellow
            
            foreach ($distro in $distributions) {
                if (-not [string]::IsNullOrWhiteSpace($distro)) {
                    try {
                        Write-Host "`nUpdating $distro..." -ForegroundColor Cyan
                        
                        # Test connection to the distribution
                        $testCmd = "wsl --distribution `"$distro`" --exec echo 'Testing connection'"
                        $testResult = Invoke-Expression $testCmd
                        
                        if (-not $testResult) {
                            Write-Host "  Could not connect to distribution $distro. Skipping." -ForegroundColor Yellow
                            continue
                        }
                        
                        # Get distribution info
                        $osReleaseCmd = "wsl --distribution `"$distro`" --exec cat /etc/os-release"
                        $distroInfo = Invoke-Expression $osReleaseCmd
                        
                        # Extract distribution type from OS release
                        $distroType = "Unknown"
                        if ($distroInfo -match "ID=(\w+)") {
                            $distroType = $matches[1]
                        }
                        
                        # Determine update command based on distribution type
                        switch -regex ($distroType) {
                            "ubuntu|debian" {
                                Write-Host "  Detected Ubuntu/Debian-based distribution." -ForegroundColor Cyan
                                $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                                Invoke-Expression $updateCmd
                            }
                            "fedora|rhel" {
                                Write-Host "  Detected Fedora/RHEL-based distribution." -ForegroundColor Cyan
                                $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo dnf update -y'"
                                Invoke-Expression $updateCmd
                            }
                            "arch" {
                                Write-Host "  Detected Arch-based distribution." -ForegroundColor Cyan
                                $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo pacman -Syu --noconfirm'"
                                Invoke-Expression $updateCmd
                            }
                            default {
                                if ($distro -match "ubuntu|Ubuntu") {
                                    Write-Host "  Distribution name suggests Ubuntu. Using apt package manager." -ForegroundColor Cyan
                                    $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                                    Invoke-Expression $updateCmd
                                } else {
                                    Write-Host "  Skipping update for $distro - unable to determine package manager." -ForegroundColor Yellow
                                    continue
                                }
                            }
                        }
                        
                        Write-Host "  $distro updated successfully." -ForegroundColor Green
                    } catch {
                        Write-Host ("  Error updating " + $distro + ": " + $_) -ForegroundColor Red
                    }
                }
            }
            
            Write-Host "`nAll distributions update process completed." -ForegroundColor Green
        }
        "4" {
            # Return to main menu
            return
        }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
        }
    }
}

function Manage-WSLNetworking {
    Show-Header "WSL NETWORKING MANAGEMENT"
    
    Write-Host "1. Configure Port Forwarding" -ForegroundColor Cyan
    Write-Host "2. Manage Network Interfaces" -ForegroundColor Cyan
    Write-Host "3. Configure DNS Settings" -ForegroundColor Cyan
    Write-Host "4. Network Troubleshooting" -ForegroundColor Cyan
    Write-Host "5. Back to Main Menu" -ForegroundColor Cyan
    
    $netOption = Read-Host "`nSelect an option (1-5)"
    
    switch ($netOption) {
        "1" {
            Write-Host "`nPort Forwarding Management" -ForegroundColor Green
            Write-Host "1. Add Port Forward" -ForegroundColor Cyan
            Write-Host "2. List Port Forwards" -ForegroundColor Cyan
            Write-Host "3. Remove Port Forward" -ForegroundColor Cyan
            Write-Host "4. Back" -ForegroundColor Cyan
            
            $portOption = Read-Host "`nSelect an option (1-4)"
            
            switch ($portOption) {
                "1" {
                    # Get installed distributions
                    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
                    $distributions = @(& $scriptPath -Installed)
                    
                    if ($null -eq $distributions -or $distributions.Count -eq 0) {
                        Write-Host "`nNo WSL distributions found." -ForegroundColor Yellow
                        return
                    }
                    
                    Write-Host "`nAvailable distributions:" -ForegroundColor Green
                    for ($i = 0; $i -lt $distributions.Count; $i++) {
                        Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
                    }
                    
                    $distroIndex = Read-Host "`nSelect a distribution (1-$($distributions.Count)), or 0 to cancel"
                    if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                        return
                    }
                    
                    $selectedDistro = $distributions[$distroIndex - 1]
                    $localPort = Read-Host "Enter local port number"
                    $remotePort = Read-Host "Enter remote port number"
                    
                    try {
                        $wslIP = wsl -d $selectedDistro -e hostname -I
                        if (-not $wslIP) {
                            Write-Host "Could not get IP address for $selectedDistro. Make sure it's running." -ForegroundColor Red
                            return
                        }
                        
                        netsh interface portproxy add v4tov4 listenport=$localPort listenaddress=0.0.0.0 connectport=$remotePort connectaddress=$wslIP
                        Write-Host "Port forward added successfully:" -ForegroundColor Green
                        Write-Host ("Local: 0.0.0.0:{0} -> Remote: {1}:{2}" -f $localPort, $wslIP, $remotePort) -ForegroundColor Cyan
                    }
                    catch {
                        Write-Host "Error adding port forward: $_" -ForegroundColor Red
                    }
                }
                "2" {
                    Write-Host "`nCurrent Port Forwards:" -ForegroundColor Green
                    
                    # Get all port forwards
                    $portForwards = netsh interface portproxy show all
                    
                    # Get WSL distributions and their IPs
                    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
                    $distributions = @(& $scriptPath -Installed)
                    $wslIPs = @{}
                    
                    foreach ($distro in $distributions) {
                        try {
                            $ip = wsl -d $distro -e hostname -I
                            if ($ip) {
                                $wslIPs[$ip.Trim()] = $distro
                            }
                        }
                        catch {
                            # Silently continue if we can't get the IP
                        }
                    }
                    
                    # Display port forwards with WSL instance names
                    Write-Host "`nListen on ipv4:             Connect to ipv4:"
                    Write-Host "--------------- ----------  --------------- ----------  WSL Instance"
                    Write-Host "Address         Port        Address         Port"
                    Write-Host "--------------- ----------  --------------- ----------  ------------"
                    
                    $portForwards | ForEach-Object {
                        if ($_ -match '0\.0\.0\.0\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)') {
                            $localPort = $matches[1]
                            $remoteIP = $matches[2]
                            $remotePort = $matches[3]
                            $wslInstance = if ($wslIPs.ContainsKey($remoteIP)) { $wslIPs[$remoteIP] } else { "Unknown" }
                            Write-Host ("{0,-15} {1,-10}  {2,-15} {3,-10}  {4}" -f "0.0.0.0", $localPort, $remoteIP, $remotePort, $wslInstance)
                        }
                    }
                }
                "3" {
                    # Get all port forwards
                    $portForwards = netsh interface portproxy show all
                    
                    # Get WSL distributions and their IPs
                    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
                    $distributions = @(& $scriptPath -Installed)
                    $wslIPs = @{}
                    
                    foreach ($distro in $distributions) {
                        try {
                            $ip = wsl -d $distro -e hostname -I
                            if ($ip) {
                                $wslIPs[$ip.Trim()] = $distro
                            }
                        }
                        catch {
                            # Silently continue if we can't get the IP
                        }
                    }
                    
                    # Display port forwards with WSL instance names
                    Write-Host "`nCurrent Port Forwards:" -ForegroundColor Green
                    Write-Host "`nListen on ipv4:             Connect to ipv4:            WSL Instance"
                    Write-Host "--------------- ----------  --------------- ----------  ------------"
                    Write-Host "Address         Port        Address         Port"
                    Write-Host "--------------- ----------  --------------- ----------  ------------"
                    
                    $portList = @()
                    $portForwards | ForEach-Object {
                        if ($_ -match '0\.0\.0\.0\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)') {
                            $localPort = $matches[1]
                            $remoteIP = $matches[2]
                            $remotePort = $matches[3]
                            $wslInstance = if ($wslIPs.ContainsKey($remoteIP)) { $wslIPs[$remoteIP] } else { "Unknown" }
                            $portList += [PSCustomObject]@{
                                LocalPort = $localPort
                                RemoteIP = $remoteIP
                                RemotePort = $remotePort
                                WSLInstance = $wslInstance
                            }
                            Write-Host ("{0,-15} {1,-10}  {2,-15} {3,-10}  {4}" -f "0.0.0.0", $localPort, $remoteIP, $remotePort, $wslInstance)
                        }
                    }
                    
                    if ($portList.Count -eq 0) {
                        Write-Host "`nNo port forwards found." -ForegroundColor Yellow
                        return
                    }
                    
                    Write-Host "`nSelect a port forward to remove:" -ForegroundColor Green
                    for ($i = 0; $i -lt $portList.Count; $i++) {
                        Write-Host "$($i+1). Port $($portList[$i].LocalPort) -> $($portList[$i].RemoteIP):$($portList[$i].RemotePort) ($($portList[$i].WSLInstance))" -ForegroundColor Cyan
                    }
                    
                    $portIndex = Read-Host "`nEnter the number of the port forward to remove (1-$($portList.Count)), or 0 to cancel"
                    if ($portIndex -eq "0" -or [string]::IsNullOrEmpty($portIndex)) {
                        return
                    }
                    
                    try {
                        $selectedPort = $portList[$portIndex - 1].LocalPort
                        netsh interface portproxy delete v4tov4 listenport=$selectedPort listenaddress=0.0.0.0
                        Write-Host "Port forward for port $selectedPort removed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error removing port forward: $_" -ForegroundColor Red
                    }
                }
                "4" {
                    Write-Host "`nNetwork Troubleshooting" -ForegroundColor Green
                    
                    # Get installed distributions
                    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
                    $distributions = @(& $scriptPath -Installed)
                    
                    if ($null -eq $distributions -or $distributions.Count -eq 0) {
                        Write-Host "No WSL distributions found." -ForegroundColor Yellow
                        return
                    }
                    
                    Write-Host "`nAvailable distributions:" -ForegroundColor Green
                    for ($i = 0; $i -lt $distributions.Count; $i++) {
                        Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
                    }
                    
                    $distroIndex = Read-Host "`nSelect a distribution (1-$($distributions.Count)), or 0 to cancel"
                    if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                        return
                    }
                    
                    $selectedDistro = $distributions[$distroIndex - 1]
                    
                    try {
                        # Check if distribution is running
                        $isRunning = wsl --list --verbose | Where-Object { $_ -match $selectedDistro -and $_ -match "Running" }
                        
                        if (-not $isRunning) {
                            Write-Host "Starting $selectedDistro..." -ForegroundColor Yellow
                            wsl -d $selectedDistro -e echo "Starting distribution" 2>$null
                            Start-Sleep -Seconds 2  # Give it a moment to start
                        }
                        
                        Write-Host "`n=============================================" -ForegroundColor Cyan
                        Write-Host ("Testing network for {0}:" -f $selectedDistro) -ForegroundColor Cyan
                        Write-Host "=============================================" -ForegroundColor Cyan
                        
                        # Test internet connectivity
                        Write-Host "`nTesting internet connectivity..." -ForegroundColor Yellow
                        $pingResult = wsl -d $selectedDistro -e ping -c 4 8.8.8.8 2>$null
                        if ($pingResult -match "bytes from") {
                            Write-Host "Internet connectivity: OK" -ForegroundColor Green
                        } else {
                            Write-Host "Internet connectivity: FAILED" -ForegroundColor Red
                        }
                        
                        # Test DNS resolution
                        Write-Host "`nTesting DNS resolution..." -ForegroundColor Yellow
                        $dnsResult = wsl -d $selectedDistro -e ping -c 1 google.com 2>$null
                        if ($dnsResult -match "bytes from") {
                            Write-Host "DNS resolution: OK" -ForegroundColor Green
                        } else {
                            # Try alternative DNS test if ping fails
                            $dnsResult = wsl -d $selectedDistro -e host google.com 2>$null
                            if ($dnsResult -match "has address") {
                                Write-Host "DNS resolution: OK" -ForegroundColor Green
                            } else {
                                Write-Host "DNS resolution: FAILED" -ForegroundColor Red
                                Write-Host "Trying to fix DNS configuration..." -ForegroundColor Yellow
                                
                                # Create a temporary script to update DNS settings
                                $tempScript = "$env:TEMP\fix_dns.sh"
                                @"
#!/bin/bash
sudo rm -f /etc/resolv.conf
sudo ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
sudo resolvconf -u
"@ | Out-File -FilePath $tempScript -Encoding ascii -Force
                                
                                # Make the script executable and run it
                                wsl -d $selectedDistro -e bash -c "chmod +x '$tempScript' && sudo '$tempScript'"
                                Remove-Item $tempScript -Force
                                
                                # Test DNS again after fix attempt
                                $dnsResult = wsl -d $selectedDistro -e ping -c 1 google.com 2>$null
                                if ($dnsResult -match "bytes from") {
                                    Write-Host "DNS resolution: FIXED" -ForegroundColor Green
                                } else {
                                    Write-Host "DNS resolution: STILL FAILED" -ForegroundColor Red
                                    Write-Host "Please check your WSL network configuration" -ForegroundColor Yellow
                                }
                            }
                        }
                        
                        # Check network interfaces
                        Write-Host "`nChecking network interfaces..." -ForegroundColor Yellow
                        $interfaces = wsl -d $selectedDistro -e ip addr show 2>$null
                        if ($interfaces) {
                            Write-Host "Network interfaces:" -ForegroundColor Green
                            $interfaceLines = $interfaces -split "`n"
                            $currentInterface = $null
                            
                            foreach ($line in $interfaceLines) {
                                if ($line -match '^\d+:') {
                                    if ($currentInterface) {
                                        Write-Host ""
                                    }
                                    $currentInterface = $line.Trim()
                                    Write-Host "Interface: $currentInterface" -ForegroundColor Green
                                } elseif ($line -match 'link/') {
                                    $mac = $line -replace '.*link/(\S+).*', '$1'
                                    Write-Host "  MAC Address: $mac" -ForegroundColor White
                                } elseif ($line -match 'inet ') {
                                    $ip = $line -replace '.*inet\s+(\S+).*', '$1'
                                    Write-Host "  IP Address: $ip" -ForegroundColor White
                                } elseif ($line -match 'inet6 ') {
                                    $ipv6 = $line -replace '.*inet6\s+(\S+).*', '$1'
                                    Write-Host "  IPv6 Address: $ipv6" -ForegroundColor White
                                } elseif ($line -match 'mtu') {
                                    $mtu = $line -replace '.*mtu\s+(\d+).*', '$1'
                                    Write-Host "  MTU: $mtu" -ForegroundColor White
                                }
                            }
                        } else {
                            Write-Host "Could not retrieve network interfaces." -ForegroundColor Red
                        }
                        
                        # Check routing table
                        Write-Host "`nChecking routing table..." -ForegroundColor Yellow
                        $routes = wsl -d $selectedDistro -e ip route 2>$null
                        if ($routes) {
                            Write-Host "Routing table:" -ForegroundColor Green
                            $routeLines = $routes -split "`n"
                            
                            foreach ($line in $routeLines) {
                                if ($line -match 'default via') {
                                    $gateway = $line -replace 'default via (\S+).*', '$1'
                                    Write-Host "  Default Gateway: $gateway" -ForegroundColor White
                                } elseif ($line -match 'dev') {
                                    $network = $line -replace '(\S+)\s+dev.*', '$1'
                                    $interface = $line -replace '.*dev\s+(\S+).*', '$1'
                                    Write-Host "  Network: $network via $interface" -ForegroundColor White
                                }
                            }
                        } else {
                            Write-Host "Could not retrieve routing table." -ForegroundColor Red
                        }
                        
                        # Check WSL Network Adapter
                        Write-Host "`n=============================================" -ForegroundColor Cyan
                        Write-Host "WSL Network Adapter Status:" -ForegroundColor Green
                        Write-Host "=============================================" -ForegroundColor Cyan
                        
                        $wslAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" }
                        if ($wslAdapter) {
                            $wslAdapter | Format-Table Name, Status, LinkSpeed, MacAddress -AutoSize
                        } else {
                            Write-Host "No WSL network adapter found" -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host ("Error during network troubleshooting: {0}" -f $_) -ForegroundColor Red
                    }
                }
                "5" {
                    Write-Host "`nNetwork Troubleshooting" -ForegroundColor Green
                    
                    # Get installed distributions
                    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
                    $distributions = @(& $scriptPath -Installed)
                    
                    if ($null -eq $distributions -or $distributions.Count -eq 0) {
                        Write-Host "No WSL distributions found." -ForegroundColor Yellow
                        return
                    }
                    
                    Write-Host "`nAvailable distributions:" -ForegroundColor Green
                    for ($i = 0; $i -lt $distributions.Count; $i++) {
                        Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
                    }
                    
                    $distroIndex = Read-Host "`nSelect a distribution (1-$($distributions.Count)), or 0 to cancel"
                    if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                        return
                    }
                    
                    $selectedDistro = $distributions[$distroIndex - 1]
                    
                    try {
                        # Check if distribution is running
                        $isRunning = wsl --list --verbose | Where-Object { $_ -match $selectedDistro -and $_ -match "Running" }
                        
                        if (-not $isRunning) {
                            Write-Host "Starting $selectedDistro..." -ForegroundColor Yellow
                            wsl -d $selectedDistro -e echo "Starting distribution" 2>$null
                            Start-Sleep -Seconds 2  # Give it a moment to start
                        }
                        
                        Write-Host "`n=============================================" -ForegroundColor Cyan
                        Write-Host ("Testing network for {0}:" -f $selectedDistro) -ForegroundColor Cyan
                        Write-Host "=============================================" -ForegroundColor Cyan
                        
                        # Test internet connectivity
                        Write-Host "`nTesting internet connectivity..." -ForegroundColor Yellow
                        $pingResult = wsl -d $selectedDistro -e ping -c 4 8.8.8.8 2>$null
                        if ($pingResult -match "bytes from") {
                            Write-Host "Internet connectivity: OK" -ForegroundColor Green
                        } else {
                            Write-Host "Internet connectivity: FAILED" -ForegroundColor Red
                        }
                        
                        # Test DNS resolution
                        Write-Host "`nTesting DNS resolution..." -ForegroundColor Yellow
                        $dnsResult = wsl -d $selectedDistro -e ping -c 1 google.com 2>$null
                        if ($dnsResult -match "bytes from") {
                            Write-Host "DNS resolution: OK" -ForegroundColor Green
                        } else {
                            # Try alternative DNS test if ping fails
                            $dnsResult = wsl -d $selectedDistro -e host google.com 2>$null
                            if ($dnsResult -match "has address") {
                                Write-Host "DNS resolution: OK" -ForegroundColor Green
                            } else {
                                Write-Host "DNS resolution: FAILED" -ForegroundColor Red
                                Write-Host "Trying to fix DNS configuration..." -ForegroundColor Yellow
                                
                                # Create a temporary script to update DNS settings
                                $tempScript = "$env:TEMP\fix_dns.sh"
                                @"
#!/bin/bash
sudo rm -f /etc/resolv.conf
sudo ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
sudo resolvconf -u
"@ | Out-File -FilePath $tempScript -Encoding ascii -Force
                                
                                # Make the script executable and run it
                                wsl -d $selectedDistro -e bash -c "chmod +x '$tempScript' && sudo '$tempScript'"
                                Remove-Item $tempScript -Force
                                
                                # Test DNS again after fix attempt
                                $dnsResult = wsl -d $selectedDistro -e ping -c 1 google.com 2>$null
                                if ($dnsResult -match "bytes from") {
                                    Write-Host "DNS resolution: FIXED" -ForegroundColor Green
                                } else {
                                    Write-Host "DNS resolution: STILL FAILED" -ForegroundColor Red
                                    Write-Host "Please check your WSL network configuration" -ForegroundColor Yellow
                                }
                            }
                        }
                        
                        # Check network interfaces
                        Write-Host "`nChecking network interfaces..." -ForegroundColor Yellow
                        $interfaces = wsl -d $selectedDistro -e ip addr show 2>$null
                        if ($interfaces) {
                            Write-Host "Network interfaces:" -ForegroundColor Green
                            $interfaceLines = $interfaces -split "`n"
                            $currentInterface = $null
                            
                            foreach ($line in $interfaceLines) {
                                if ($line -match '^\d+:') {
                                    if ($currentInterface) {
                                        Write-Host ""
                                    }
                                    $currentInterface = $line.Trim()
                                    Write-Host "Interface: $currentInterface" -ForegroundColor Green
                                } elseif ($line -match 'link/') {
                                    $mac = $line -replace '.*link/(\S+).*', '$1'
                                    Write-Host "  MAC Address: $mac" -ForegroundColor White
                                } elseif ($line -match 'inet ') {
                                    $ip = $line -replace '.*inet\s+(\S+).*', '$1'
                                    Write-Host "  IP Address: $ip" -ForegroundColor White
                                } elseif ($line -match 'inet6 ') {
                                    $ipv6 = $line -replace '.*inet6\s+(\S+).*', '$1'
                                    Write-Host "  IPv6 Address: $ipv6" -ForegroundColor White
                                } elseif ($line -match 'mtu') {
                                    $mtu = $line -replace '.*mtu\s+(\d+).*', '$1'
                                    Write-Host "  MTU: $mtu" -ForegroundColor White
                                }
                            }
                        } else {
                            Write-Host "Could not retrieve network interfaces." -ForegroundColor Red
                        }
                        
                        # Check routing table
                        Write-Host "`nChecking routing table..." -ForegroundColor Yellow
                        $routes = wsl -d $selectedDistro -e ip route 2>$null
                        if ($routes) {
                            Write-Host "Routing table:" -ForegroundColor Green
                            $routeLines = $routes -split "`n"
                            
                            foreach ($line in $routeLines) {
                                if ($line -match 'default via') {
                                    $gateway = $line -replace 'default via (\S+).*', '$1'
                                    Write-Host "  Default Gateway: $gateway" -ForegroundColor White
                                } elseif ($line -match 'dev') {
                                    $network = $line -replace '(\S+)\s+dev.*', '$1'
                                    $interface = $line -replace '.*dev\s+(\S+).*', '$1'
                                    Write-Host "  Network: $network via $interface" -ForegroundColor White
                                }
                            }
                        } else {
                            Write-Host "Could not retrieve routing table." -ForegroundColor Red
                        }
                        
                        # Check WSL Network Adapter
                        Write-Host "`n=============================================" -ForegroundColor Cyan
                        Write-Host "WSL Network Adapter Status:" -ForegroundColor Green
                        Write-Host "=============================================" -ForegroundColor Cyan
                        
                        $wslAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" }
                        if ($wslAdapter) {
                            $wslAdapter | Format-Table Name, Status, LinkSpeed, MacAddress -AutoSize
                        } else {
                            Write-Host "No WSL network adapter found" -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host ("Error during network troubleshooting: {0}" -f $_) -ForegroundColor Red
                    }
                }
            }
        }
        "2" {
            Write-Host "`nNetwork Interface Management" -ForegroundColor Green
            
            # Get installed distributions
            $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
            $distributions = @(& $scriptPath -Installed)
            
            if ($null -eq $distributions -or $distributions.Count -eq 0) {
                Write-Host "No WSL distributions found." -ForegroundColor Yellow
                return
            }
            
            foreach ($distro in $distributions) {
                if (-not [string]::IsNullOrWhiteSpace($distro)) {
                    Write-Host "`n=============================================" -ForegroundColor Cyan
                    Write-Host ("Network interfaces for {0}:" -f $distro) -ForegroundColor Cyan
                    Write-Host "=============================================" -ForegroundColor Cyan
                    
                    try {
                        # Check if distribution is running
                        $isRunning = wsl --list --verbose | Where-Object { $_ -match $distro -and $_ -match "Running" }
                        
                        if (-not $isRunning) {
                            Write-Host "Starting $distro..." -ForegroundColor Yellow
                            wsl -d $distro -e echo "Starting distribution" 2>$null
                            Start-Sleep -Seconds 2  # Give it a moment to start
                        }
                        
                        # Get network interfaces
                        $interfaces = wsl -d $distro -e ip addr show 2>$null
                        if ($interfaces) {
                            $interfaceLines = $interfaces -split "`n"
                            $currentInterface = $null
                            
                            foreach ($line in $interfaceLines) {
                                if ($line -match '^\d+:') {
                                    if ($currentInterface) {
                                        Write-Host ""
                                    }
                                    $currentInterface = $line.Trim()
                                    Write-Host "Interface: $currentInterface" -ForegroundColor Green
                                } elseif ($line -match 'link/') {
                                    $mac = $line -replace '.*link/(\S+).*', '$1'
                                    Write-Host "  MAC Address: $mac" -ForegroundColor White
                                } elseif ($line -match 'inet ') {
                                    $ip = $line -replace '.*inet\s+(\S+).*', '$1'
                                    Write-Host "  IP Address: $ip" -ForegroundColor White
                                } elseif ($line -match 'inet6 ') {
                                    $ipv6 = $line -replace '.*inet6\s+(\S+).*', '$1'
                                    Write-Host "  IPv6 Address: $ipv6" -ForegroundColor White
                                } elseif ($line -match 'mtu') {
                                    $mtu = $line -replace '.*mtu\s+(\d+).*', '$1'
                                    Write-Host "  MTU: $mtu" -ForegroundColor White
                                }
                            }
                        } else {
                            Write-Host "No network interfaces found or could not access them." -ForegroundColor Yellow
                        }
                        
                        # Get IP address
                        $ip = wsl -d $distro -e hostname -I 2>$null
                        if ($ip) {
                            Write-Host "`nCurrent IP Address: $ip" -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Host ("Error accessing network interfaces: {0}" -f $_) -ForegroundColor Red
                    }
                }
            }
            
            # Show WSL Network Adapter Status
            Write-Host "`n=============================================" -ForegroundColor Cyan
            Write-Host "WSL Network Adapter Status:" -ForegroundColor Green
            Write-Host "=============================================" -ForegroundColor Cyan
            
            $wslAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" }
            if ($wslAdapter) {
                $wslAdapter | Format-Table Name, Status, LinkSpeed, MacAddress -AutoSize
            } else {
                Write-Host "No WSL network adapter found" -ForegroundColor Yellow
            }
        }
        "3" {
            Write-Host "`nDNS Configuration" -ForegroundColor Green
            
            # Get installed distributions
            $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
            $distributions = @(& $scriptPath -Installed)
            
            if ($null -eq $distributions -or $distributions.Count -eq 0) {
                Write-Host "No WSL distributions found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $distributions.Count; $i++) {
                Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
            }
            
            $distroIndex = Read-Host "`nSelect a distribution (1-$($distributions.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            $selectedDistro = $distributions[$distroIndex - 1]
            
            try {
                # Check if distribution is running
                $isRunning = wsl --list --verbose | Where-Object { $_ -match $selectedDistro -and $_ -match "Running" }
                
                if (-not $isRunning) {
                    Write-Host "Starting $selectedDistro..." -ForegroundColor Yellow
                    wsl -d $selectedDistro -e echo "Starting distribution" 2>$null
                    Start-Sleep -Seconds 2  # Give it a moment to start
                }
                
                Write-Host ("`nCurrent DNS settings for {0}:" -f $selectedDistro) -ForegroundColor Cyan
                $currentDNS = wsl -d $selectedDistro -e cat /etc/resolv.conf 2>$null
                if ($currentDNS) {
                    Write-Host $currentDNS -ForegroundColor White
                } else {
                    Write-Host "Could not retrieve current DNS settings." -ForegroundColor Yellow
                }
                
                $changeDNS = Read-Host "`nDo you want to configure custom DNS servers for $selectedDistro? (Y/N)"
                if ($changeDNS -eq "Y" -or $changeDNS -eq "y") {
                    $primaryDNS = Read-Host "Enter primary DNS server (e.g., 8.8.8.8)"
                    $secondaryDNS = Read-Host "Enter secondary DNS server (e.g., 8.8.4.4)"
                    
                    try {
                        # Create a temporary script to update DNS settings
                        $tempScript = "$env:TEMP\update_dns.sh"
                        @"
#!/bin/bash
echo 'nameserver $primaryDNS' | sudo tee /etc/resolv.conf
echo 'nameserver $secondaryDNS' | sudo tee -a /etc/resolv.conf
"@ | Out-File -FilePath $tempScript -Encoding ascii -Force
                        
                        # Make the script executable and run it
                        wsl -d $selectedDistro -e bash -c "chmod +x '$tempScript' && sudo '$tempScript'"
                        Remove-Item $tempScript -Force
                        
                        Write-Host "DNS settings updated successfully." -ForegroundColor Green
                        Write-Host "`nNew DNS settings:" -ForegroundColor Cyan
                        wsl -d $selectedDistro -e cat /etc/resolv.conf
                    }
                    catch {
                        Write-Host ("Error updating {0}: {1}" -f $selectedDistro, $_) -ForegroundColor Red
                    }
                }
            }
            catch {
                Write-Host ("Error accessing DNS settings: {0}" -f $_) -ForegroundColor Red
            }
        }
        "4" {
            Write-Host "`nNetwork Troubleshooting" -ForegroundColor Green
            
            # Get installed distributions
            $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
            $distributions = @(& $scriptPath -Installed)
            
            if ($null -eq $distributions -or $distributions.Count -eq 0) {
                Write-Host "No WSL distributions found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $distributions.Count; $i++) {
                Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
            }
            
            $distroIndex = Read-Host "`nSelect a distribution (1-$($distributions.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            $selectedDistro = $distributions[$distroIndex - 1]
            
            try {
                # Check if distribution is running
                $isRunning = wsl --list --verbose | Where-Object { $_ -match $selectedDistro -and $_ -match "Running" }
                
                if (-not $isRunning) {
                    Write-Host "Starting $selectedDistro..." -ForegroundColor Yellow
                    wsl -d $selectedDistro -e echo "Starting distribution" 2>$null
                    Start-Sleep -Seconds 2  # Give it a moment to start
                }
                
                Write-Host "`n=============================================" -ForegroundColor Cyan
                Write-Host ("Testing network for {0}:" -f $selectedDistro) -ForegroundColor Cyan
                Write-Host "=============================================" -ForegroundColor Cyan
                
                # Test internet connectivity
                Write-Host "`nTesting internet connectivity..." -ForegroundColor Yellow
                $pingResult = wsl -d $selectedDistro -e ping -c 4 8.8.8.8 2>$null
                if ($pingResult -match "bytes from") {
                    Write-Host "Internet connectivity: OK" -ForegroundColor Green
                } else {
                    Write-Host "Internet connectivity: FAILED" -ForegroundColor Red
                }
                
                # Test DNS resolution
                Write-Host "`nTesting DNS resolution..." -ForegroundColor Yellow
                $dnsResult = wsl -d $selectedDistro -e ping -c 1 google.com 2>$null
                if ($dnsResult -match "bytes from") {
                    Write-Host "DNS resolution: OK" -ForegroundColor Green
                } else {
                    # Try alternative DNS test if ping fails
                    $dnsResult = wsl -d $selectedDistro -e host google.com 2>$null
                    if ($dnsResult -match "has address") {
                        Write-Host "DNS resolution: OK" -ForegroundColor Green
                    } else {
                        Write-Host "DNS resolution: FAILED" -ForegroundColor Red
                        Write-Host "Trying to fix DNS configuration..." -ForegroundColor Yellow
                        
                        # Create a temporary script to update DNS settings
                        $tempScript = "$env:TEMP\fix_dns.sh"
                        @"
#!/bin/bash
sudo rm -f /etc/resolv.conf
sudo ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
sudo resolvconf -u
"@ | Out-File -FilePath $tempScript -Encoding ascii -Force
                        
                        # Make the script executable and run it
                        wsl -d $selectedDistro -e bash -c "chmod +x '$tempScript' && sudo '$tempScript'"
                        Remove-Item $tempScript -Force
                        
                        # Test DNS again after fix attempt
                        $dnsResult = wsl -d $selectedDistro -e ping -c 1 google.com 2>$null
                        if ($dnsResult -match "bytes from") {
                            Write-Host "DNS resolution: FIXED" -ForegroundColor Green
                        } else {
                            Write-Host "DNS resolution: STILL FAILED" -ForegroundColor Red
                            Write-Host "Please check your WSL network configuration" -ForegroundColor Yellow
                        }
                    }
                }
                
                # Check network interfaces
                Write-Host "`nChecking network interfaces..." -ForegroundColor Yellow
                $interfaces = wsl -d $selectedDistro -e ip addr show 2>$null
                if ($interfaces) {
                    Write-Host "Network interfaces:" -ForegroundColor Green
                    $interfaceLines = $interfaces -split "`n"
                    $currentInterface = $null
                    
                    foreach ($line in $interfaceLines) {
                        if ($line -match '^\d+:') {
                            if ($currentInterface) {
                                Write-Host ""
                            }
                            $currentInterface = $line.Trim()
                            Write-Host "Interface: $currentInterface" -ForegroundColor Green
                        } elseif ($line -match 'link/') {
                            $mac = $line -replace '.*link/(\S+).*', '$1'
                            Write-Host "  MAC Address: $mac" -ForegroundColor White
                        } elseif ($line -match 'inet ') {
                            $ip = $line -replace '.*inet\s+(\S+).*', '$1'
                            Write-Host "  IP Address: $ip" -ForegroundColor White
                        } elseif ($line -match 'inet6 ') {
                            $ipv6 = $line -replace '.*inet6\s+(\S+).*', '$1'
                            Write-Host "  IPv6 Address: $ipv6" -ForegroundColor White
                        } elseif ($line -match 'mtu') {
                            $mtu = $line -replace '.*mtu\s+(\d+).*', '$1'
                            Write-Host "  MTU: $mtu" -ForegroundColor White
                        }
                    }
                } else {
                    Write-Host "Could not retrieve network interfaces." -ForegroundColor Red
                }
                
                # Check routing table
                Write-Host "`nChecking routing table..." -ForegroundColor Yellow
                $routes = wsl -d $selectedDistro -e ip route 2>$null
                if ($routes) {
                    Write-Host "Routing table:" -ForegroundColor Green
                    $routeLines = $routes -split "`n"
                    
                    foreach ($line in $routeLines) {
                        if ($line -match 'default via') {
                            $gateway = $line -replace 'default via (\S+).*', '$1'
                            Write-Host "  Default Gateway: $gateway" -ForegroundColor White
                        } elseif ($line -match 'dev') {
                            $network = $line -replace '(\S+)\s+dev.*', '$1'
                            $interface = $line -replace '.*dev\s+(\S+).*', '$1'
                            Write-Host "  Network: $network via $interface" -ForegroundColor White
                        }
                    }
                } else {
                    Write-Host "Could not retrieve routing table." -ForegroundColor Red
                }
                
                # Check WSL Network Adapter
                Write-Host "`n=============================================" -ForegroundColor Cyan
                Write-Host "WSL Network Adapter Status:" -ForegroundColor Green
                Write-Host "=============================================" -ForegroundColor Cyan
                
                $wslAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" }
                if ($wslAdapter) {
                    $wslAdapter | Format-Table Name, Status, LinkSpeed, MacAddress -AutoSize
                } else {
                    Write-Host "No WSL network adapter found" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host ("Error during network troubleshooting: {0}" -f $_) -ForegroundColor Red
            }
        }
        "5" {
            # Return to main menu
            return
        }
    }
}

function Backup-Restore-WSL {
    Show-Header "WSL BACKUP AND RESTORE"
    
    Write-Host "1. Backup WSL Distribution" -ForegroundColor Cyan
    Write-Host "2. Restore WSL Distribution" -ForegroundColor Cyan
    Write-Host "3. List Backups" -ForegroundColor Cyan
    Write-Host "4. Back to Main Menu" -ForegroundColor Cyan
    
    $backupOption = Read-Host "`nSelect an option (1-4)"
    
    switch ($backupOption) {
        "1" {
            # Get installed distributions using Get-WSLNames.ps1
            $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
            $distributions = @(& $scriptPath -Installed)
            
            if ($null -eq $distributions -or $distributions.Count -eq 0) {
                Write-Host "No WSL distributions found to backup." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $distributions.Count; $i++) {
                Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to backup (1-$($distributions.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            $selectedDistro = $distributions[$distroIndex - 1]
            $backupPath = Read-Host "Enter backup path (default: $env:USERPROFILE\WSL-Backups)"
            if (-not $backupPath) { $backupPath = "$env:USERPROFILE\WSL-Backups" }
            
            if (-not (Test-Path $backupPath)) {
                New-Item -ItemType Directory -Path $backupPath | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupFile = "$backupPath\${selectedDistro}_${timestamp}.tar"
            
            Write-Host "`nCreating backup of $selectedDistro..." -ForegroundColor Yellow
            try {
                wsl --export $selectedDistro $backupFile
                Write-Host "Backup created successfully at: $backupFile" -ForegroundColor Green
            }
            catch {
                Write-Host "Error creating backup: $_" -ForegroundColor Red
            }
        }
        "2" {
            $backupPath = Read-Host "Enter backup directory path (default: $env:USERPROFILE\WSL-Backups)"
            if (-not $backupPath) { $backupPath = "$env:USERPROFILE\WSL-Backups" }
            
            if (-not (Test-Path $backupPath)) {
                Write-Host "Backup directory not found." -ForegroundColor Red
                return
            }
            
            $backups = Get-ChildItem -Path $backupPath -Filter "*.tar"
            if ($backups.Count -eq 0) {
                Write-Host "No backup files found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable backups:" -ForegroundColor Green
            for ($i = 0; $i -lt $backups.Count; $i++) {
                Write-Host "  $($i+1). $($backups[$i].Name)" -ForegroundColor Cyan
            }
            
            $backupIndex = Read-Host "`nSelect a backup to restore (1-$($backups.Count)), or 0 to cancel"
            if ($backupIndex -eq "0" -or [string]::IsNullOrEmpty($backupIndex)) {
                return
            }
            
            $selectedBackup = $backups[$backupIndex - 1]
            $newDistroName = Read-Host "Enter name for the restored distribution"
            
            if ([string]::IsNullOrEmpty($newDistroName)) {
                Write-Host "Distribution name cannot be empty." -ForegroundColor Red
                return
            }
            
            Write-Host "`nRestoring from backup..." -ForegroundColor Yellow
            try {
                wsl --import $newDistroName $env:USERPROFILE\WSL\$newDistroName $selectedBackup.FullName
                Write-Host "Distribution restored successfully as $newDistroName" -ForegroundColor Green
            }
            catch {
                Write-Host "Error restoring backup: $_" -ForegroundColor Red
            }
        }
        "3" {
            $backupPath = Read-Host "Enter backup directory path (default: $env:USERPROFILE\WSL-Backups)"
            if (-not $backupPath) { $backupPath = "$env:USERPROFILE\WSL-Backups" }
            
            if (-not (Test-Path $backupPath)) {
                Write-Host "Backup directory not found." -ForegroundColor Red
                return
            }
            
            $backups = Get-ChildItem -Path $backupPath -Filter "*.tar"
            if ($backups.Count -eq 0) {
                Write-Host "No backup files found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable backups:" -ForegroundColor Green
            $backups | Format-Table Name, Length, LastWriteTime
        }
    }
}

function Monitor-WSLPerformance {
    Show-Header "WSL PERFORMANCE MONITORING"
    
    Write-Host "1. Start Performance Monitoring" -ForegroundColor Cyan
    Write-Host "2. View Performance Logs" -ForegroundColor Cyan
    Write-Host "3. Configure Monitoring" -ForegroundColor Cyan
    Write-Host "4. Back to Main Menu" -ForegroundColor Cyan
    
    $monitorOption = Read-Host "`nSelect an option (1-4)"
    
    switch ($monitorOption) {
        "1" {
            $logPath = "$env:USERPROFILE\WSL-Logs"
            if (-not (Test-Path $logPath)) {
                New-Item -ItemType Directory -Path $logPath | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $logFile = "$logPath\performance_$timestamp.csv"
            
            Write-Host "`nStarting performance monitoring..." -ForegroundColor Yellow
            Write-Host "Log file: $logFile" -ForegroundColor Cyan
            Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
            
            try {
                # Create CSV header
                "Timestamp,Distribution,CPU%,Memory(MB),DiskIO(MB/s)" | Out-File -FilePath $logFile
                
                while ($true) {
                    $wslDistros = (wsl --list --quiet) -split "`n" | Where-Object { $_ -and $_ -ne "Windows" }
                    
                    foreach ($distro in $wslDistros) {
                        if ($distro -and $distro.Trim() -ne "") {
                            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            $cpu = wsl -d $distro -e top -bn1 | Select-String "Cpu(s)" | ForEach-Object { ($_ -split '\s+')[1] }
                            $memory = wsl -d $distro -e free -m | Select-Object -Skip 1 | Select-Object -First 1 | ForEach-Object { ($_ -split '\s+')[2] }
                            $diskIO = wsl -d $distro -e iostat -d | Select-Object -Skip 3 | Select-Object -First 1 | ForEach-Object { ($_ -split '\s+')[3] }
                            
                            "$timestamp,$distro,$cpu,$memory,$diskIO" | Out-File -FilePath $logFile -Append
                        }
                    }
                    
                    Start-Sleep -Seconds 5
                }
            }
            catch {
                Write-Host "`nMonitoring stopped." -ForegroundColor Yellow
            }
        }
        "2" {
            $logPath = "$env:USERPROFILE\WSL-Logs"
            if (-not (Test-Path $logPath)) {
                Write-Host "No performance logs found." -ForegroundColor Yellow
                return
            }
            
            $logFiles = Get-ChildItem -Path $logPath -Filter "performance_*.csv"
            if ($logFiles.Count -eq 0) {
                Write-Host "No performance logs found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable log files:" -ForegroundColor Green
            for ($i = 0; $i -lt $logFiles.Count; $i++) {
                Write-Host "  $($i+1). $($logFiles[$i].Name)" -ForegroundColor Cyan
            }
            
            $logIndex = Read-Host "`nSelect a log file to view (1-$($logFiles.Count)), or 0 to cancel"
            if ($logIndex -eq "0" -or [string]::IsNullOrEmpty($logIndex)) {
                return
            }
            
            $selectedLog = $logFiles[$logIndex - 1]
            Import-Csv $selectedLog.FullName | Format-Table -AutoSize
        }
        "3" {
            Write-Host "`nPerformance Monitoring Configuration" -ForegroundColor Green
            $configPath = "$env:USERPROFILE\WSL-Logs\monitor_config.json"
            
            if (Test-Path $configPath) {
                $config = Get-Content $configPath | ConvertFrom-Json
                Write-Host "Current configuration:" -ForegroundColor Cyan
                Write-Host "Monitoring interval: $($config.interval) seconds"
                Write-Host "Log retention: $($config.retention) days"
            }
            else {
                $config = @{
                    interval  = 5
                    retention = 7
                }
            }
            
            $newInterval = Read-Host "Enter monitoring interval in seconds (default: $($config.interval))"
            if ($newInterval) { $config.interval = [int]$newInterval }
            
            $newRetention = Read-Host "Enter log retention period in days (default: $($config.retention))"
            if ($newRetention) { $config.retention = [int]$newRetention }
            
            $config | ConvertTo-Json | Out-File -FilePath $configPath
            Write-Host "Configuration saved successfully." -ForegroundColor Green
        }
    }
}

function Manage-WSLProfiles {
    Show-Header "WSL CONFIGURATION PROFILES"
    
    Write-Host "1. Create New Profile" -ForegroundColor Cyan
    Write-Host "2. Apply Profile" -ForegroundColor Cyan
    Write-Host "3. List Profiles" -ForegroundColor Cyan
    Write-Host "4. Delete Profile" -ForegroundColor Cyan
    Write-Host "5. Back to Main Menu" -ForegroundColor Cyan
    
    $profileOption = Read-Host "`nSelect an option (1-5)"
    
    $profilesPath = "$env:USERPROFILE\WSL-Profiles"
    if (-not (Test-Path $profilesPath)) {
        New-Item -ItemType Directory -Path $profilesPath | Out-Null
    }
    
    switch ($profileOption) {
        "1" {
            $profileName = Read-Host "Enter profile name"
            if ([string]::IsNullOrEmpty($profileName)) {
                Write-Host "Profile name cannot be empty." -ForegroundColor Red
                return
            }
            
            $profilePath = "$profilesPath\$profileName.json"
            
            $profile = @{
                name                = $profileName
                memory              = Read-Host "Enter memory limit in GB"
                processors          = Read-Host "Enter number of processors"
                swap                = Read-Host "Enter swap size in GB"
                localhostForwarding = Read-Host "Enable localhost forwarding? (Y/N)"
                kernelCommandLine   = Read-Host "Enter kernel command line options (optional)"
            }
            
            $profile | ConvertTo-Json | Out-File -FilePath $profilePath
            Write-Host "Profile created successfully." -ForegroundColor Green
        }
        "2" {
            $profiles = Get-ChildItem -Path $profilesPath -Filter "*.json"
            if ($profiles.Count -eq 0) {
                Write-Host "No profiles found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable profiles:" -ForegroundColor Green
            for ($i = 0; $i -lt $profiles.Count; $i++) {
                Write-Host "  $($i+1). $($profiles[$i].BaseName)" -ForegroundColor Cyan
            }
            
            $profileIndex = Read-Host "`nSelect a profile to apply (1-$($profiles.Count)), or 0 to cancel"
            if ($profileIndex -eq "0" -or [string]::IsNullOrEmpty($profileIndex)) {
                return
            }
            
            $selectedProfile = $profiles[$profileIndex - 1]
            $profile = Get-Content $selectedProfile.FullName | ConvertFrom-Json
            
            $wslConfig = @"
[wsl2]
memory=$($profile.memory)GB
processors=$($profile.processors)
swap=$($profile.swap)GB
localhostForwarding=$($profile.localhostForwarding -eq "Y")
kernelCommandLine=$($profile.kernelCommandLine)
"@
            
            $wslConfigPath = "$env:USERPROFILE\.wslconfig"
            $wslConfig | Out-File -FilePath $wslConfigPath -Encoding ascii -Force
            
            Write-Host "Profile applied successfully. Please restart WSL for changes to take effect." -ForegroundColor Green
            Write-Host "Run 'wsl --shutdown' to restart WSL" -ForegroundColor Cyan
        }
        "3" {
            $profiles = Get-ChildItem -Path $profilesPath -Filter "*.json"
            if ($profiles.Count -eq 0) {
                Write-Host "No profiles found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable profiles:" -ForegroundColor Green
            foreach ($profile in $profiles) {
                $profileData = Get-Content $profile.FullName | ConvertFrom-Json
                Write-Host "`nProfile: $($profileData.name)" -ForegroundColor Cyan
                Write-Host "Memory: $($profileData.memory)GB"
                Write-Host "Processors: $($profileData.processors)"
                Write-Host "Swap: $($profileData.swap)GB"
                Write-Host "Localhost Forwarding: $($profileData.localhostForwarding)"
                if ($profileData.kernelCommandLine) {
                    Write-Host "Kernel Command Line: $($profileData.kernelCommandLine)"
                }
            }
        }
        "4" {
            $profiles = Get-ChildItem -Path $profilesPath -Filter "*.json"
            if ($profiles.Count -eq 0) {
                Write-Host "No profiles found." -ForegroundColor Yellow
                return
            }
            
            Write-Host "`nAvailable profiles:" -ForegroundColor Green
            for ($i = 0; $i -lt $profiles.Count; $i++) {
                Write-Host "  $($i+1). $($profiles[$i].BaseName)" -ForegroundColor Cyan
            }
            
            $profileIndex = Read-Host "`nSelect a profile to delete (1-$($profiles.Count)), or 0 to cancel"
            if ($profileIndex -eq "0" -or [string]::IsNullOrEmpty($profileIndex)) {
                return
            }
            
            $selectedProfile = $profiles[$profileIndex - 1]
            Remove-Item $selectedProfile.FullName -Force
            Write-Host "Profile deleted successfully." -ForegroundColor Green
        }
    }
}

function Manage-WSLPackages {
    Show-Header "WSL PACKAGE MANAGEMENT"
    
    # Get installed distributions using Get-WSLNames.ps1
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "No WSL distributions found." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nAvailable distributions:" -ForegroundColor Green
    for ($i = 0; $i -lt $distributions.Count; $i++) {
        Write-Host "  $($i+1). $($distributions[$i])" -ForegroundColor Cyan
    }
    
    $distroIndex = Read-Host "`nSelect a distribution (1-$($distributions.Count)), or 0 to cancel"
    if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
        return
    }
    
    $selectedDistro = $distributions[$distroIndex - 1]
    
    Write-Host "`nPackage Management Options:" -ForegroundColor Green
    Write-Host "1. Update Package List" -ForegroundColor Cyan
    Write-Host "2. Upgrade Packages" -ForegroundColor Cyan
    Write-Host "3. Install Package" -ForegroundColor Cyan
    Write-Host "4. Remove Package" -ForegroundColor Cyan
    Write-Host "5. List Installed Packages" -ForegroundColor Cyan
    Write-Host "6. Back to Main Menu" -ForegroundColor Cyan
    
    $packageOption = Read-Host "`nSelect an option (1-6)"
    
    switch ($packageOption) {
        "1" {
            Write-Host "`nUpdating package list for $selectedDistro..." -ForegroundColor Yellow
            wsl -d $selectedDistro -e bash -c "sudo apt update"
        }
        "2" {
            Write-Host "`nUpgrading packages for $selectedDistro..." -ForegroundColor Yellow
            wsl -d $selectedDistro -e bash -c "sudo apt upgrade -y"
        }
        "3" {
            $packageName = Read-Host "Enter package name to install"
            Write-Host "`nInstalling $packageName..." -ForegroundColor Yellow
            wsl -d $selectedDistro -e bash -c "sudo apt install -y $packageName"
        }
        "4" {
            $packageName = Read-Host "Enter package name to remove"
            Write-Host "`nRemoving $packageName..." -ForegroundColor Yellow
            wsl -d $selectedDistro -e bash -c "sudo apt remove -y $packageName"
        }
        "5" {
            Write-Host ("`nInstalled packages in {0}:" -f $selectedDistro) -ForegroundColor Yellow
            wsl -d $selectedDistro -e bash -c "dpkg -l | grep '^ii'"
        }
        "6" {
            return
        }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
        }
    }
}

function Test-WSLHealth {
    Show-Header "WSL HEALTH CHECK"
    
    Write-Host "Running comprehensive health check..." -ForegroundColor Yellow
    
    # Check WSL version and status
    Write-Host "`n1. WSL Version and Status:" -ForegroundColor Green
    wsl --status
    
    # Check Windows features
    Write-Host "`n2. Windows Features:" -ForegroundColor Green
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
    
    Write-Host "WSL Feature: $($wslFeature.State)" -ForegroundColor $(if ($wslFeature.State -eq "Enabled") { "Green" } else { "Red" })
    Write-Host "VM Platform: $($vmFeature.State)" -ForegroundColor $(if ($vmFeature.State -eq "Enabled") { "Green" } else { "Red" })
    
    # Check distributions using Get-WSLNames.ps1
    Write-Host "`n3. WSL Distributions:" -ForegroundColor Green
    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
    $distributions = @(& $scriptPath -Installed)
    
    if ($null -eq $distributions -or $distributions.Count -eq 0) {
        Write-Host "No WSL distributions found." -ForegroundColor Yellow
    } else {
        foreach ($distro in $distributions) {
            if (-not [string]::IsNullOrWhiteSpace($distro)) {
                Write-Host ("`nChecking {0}:" -f $distro) -ForegroundColor Cyan
                
                # Check if distribution is running
                $wslInfo = wsl --list --verbose | Where-Object { $_ -match $distro }
                $isRunning = $wslInfo -match "Running"
                Write-Host "Status: $(if ($isRunning) { 'Running' } else { 'Stopped' })" -ForegroundColor $(if ($isRunning) { "Green" } else { "Yellow" })
                
                if ($isRunning) {
                    try {
                        # Check disk space
                        Write-Host "Disk Space:" -ForegroundColor Cyan
                        wsl -d $distro -e df -h / 2>$null
                        
                        # Check memory usage
                        Write-Host "Memory Usage:" -ForegroundColor Cyan
                        wsl -d $distro -e free -h 2>$null
                        
                        # Check network connectivity
                        Write-Host "Network Connectivity:" -ForegroundColor Cyan
                        wsl -d $distro -e ping -c 2 8.8.8.8 2>$null
                        
                        # Check system load
                        Write-Host "System Load:" -ForegroundColor Cyan
                        wsl -d $distro -e uptime 2>$null
                    } catch {
                        Write-Host ("Error retrieving information for {0}: {1}" -f $distro, $_) -ForegroundColor Red
                    }
                }
            }
        }
    }
    
    # Check WSL network adapter
    Write-Host "`n4. WSL Network Adapter:" -ForegroundColor Green
    $wslAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" }
    if ($wslAdapter) {
        Write-Host "Status: $($wslAdapter.Status)" -ForegroundColor $(if ($wslAdapter.Status -eq "Up") { "Green" } else { "Red" })
        Write-Host "Speed: $($wslAdapter.LinkSpeed)" -ForegroundColor Cyan
    }
    else {
        Write-Host "No WSL network adapter found" -ForegroundColor Red
    }
    
    # Check for common issues
    Write-Host "`n5. Common Issues Check:" -ForegroundColor Green
    
    # Check if .wslconfig exists
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    if (Test-Path $wslConfigPath) {
        Write-Host "WSL configuration file exists" -ForegroundColor Green
    }
    else {
        Write-Host "No WSL configuration file found" -ForegroundColor Yellow
    }
    
    # Check for port conflicts
    $wslPorts = Get-NetTCPConnection | Where-Object { $_.OwningProcess -eq (Get-Process -Name "wslhost" -ErrorAction SilentlyContinue).Id }
    if ($wslPorts) {
        Write-Host "Active WSL ports:" -ForegroundColor Cyan
        $wslPorts | Format-Table LocalPort, RemotePort, State
    }
    
    Write-Host "`nHealth check completed." -ForegroundColor Green
}

function Reset-Console {
    # Reset console colors
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    # Clear the screen
    Clear-Host
}

function Show-Menu {
    Reset-Console
    
    # Create menu sections
    $menuSections = @(
        @{
            Title = "INFORMATION:"
            Options = @(
                "1. WSL System Status",
                "2. List WSL Distributions",
                "3. WSL Resource Usage",
                "4. WSL Network Information",
                "5. Test WSL Connectivity"
            )
        },
        @{
            Title = "NETWORKING:"
            Options = @(
                "6. Manage WSL Networking"
            )
        },
        @{
            Title = "MANAGEMENT:"
            Options = @(
                "7. Create New WSL Instance",
                "8. Delete WSL Instance",
                "9. Rename WSL Instance",
                "10. Update WSL Instance"
            )
        },
        @{
            Title = "MAINTENANCE:"
            Options = @(
                "11. Optimize WSL Performance",
                "12. WSL Repair Tools",
                "13. Backup and Restore",
                "14. Performance Monitoring",
                "15. Configuration Profiles",
                "16. Package Management",
                "17. System Health Check",
                "18. Exit"
            )
        }
    )
    
    # Display header
    $header = "WSL INFORMATION AND MANAGEMENT TOOL"
    $headerLine = "=" * ($header.Length + 4)
    Write-Host "`n$headerLine" -ForegroundColor Cyan
    Write-Host "  $header" -ForegroundColor Cyan
    Write-Host "$headerLine`n" -ForegroundColor Cyan
    
    # Display menu sections
    foreach ($section in $menuSections) {
        Write-Host $section.Title -ForegroundColor Green
        foreach ($option in $section.Options) {
            Write-Host "  $option" -ForegroundColor Cyan
        }
        Write-Host ""
    }
    
    $option = Read-Host "`nSelect an option (1-18)"
    
    switch ($option) {
        "1" { Get-WSLStatus; Wait-Script }
        "2" { Get-WSLDistributions; Wait-Script }
        "3" { Get-WSLResourceUsage; Wait-Script }
        "4" { Get-WSLNetworkInfo; Wait-Script }
        "5" { Test-WSLConnectivity; Wait-Script }
        "6" { Manage-WSLNetworking; Wait-Script }
        "7" { New-WSLInstance; Wait-Script }
        "8" { Remove-WSLInstance; Wait-Script }
        "9" { Rename-WSLInstance; Wait-Script }
        "10" { Update-WSLInstance; Wait-Script }
        "11" { Optimize-WSL; Wait-Script }
        "12" { Repair-WSL; Wait-Script }
        "13" { Backup-Restore-WSL; Wait-Script }
        "14" { Monitor-WSLPerformance; Wait-Script }
        "15" { Manage-WSLProfiles; Wait-Script }
        "16" { Manage-WSLPackages; Wait-Script }
        "17" { Test-WSLHealth; Wait-Script }
        "18" { Exit }
        default { Write-Host "Invalid option. Please try again." -ForegroundColor Red; Start-Sleep -Seconds 2 }
    }
}

function Wait-Script {
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Reset-Console
}

# Main execution
while ($true) {
    Show-Menu
} 