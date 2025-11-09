# Manage-WSLInstance.ps1
# Script to help manage WSL instances with functionality to create, delete, export, and import distros

param (
    [Parameter()]
    [switch]$CreateInstance,
    
    [Parameter()]
    [switch]$ListInstalled,
    
    [Parameter()]
    [switch]$ListOnline,
    
    [Parameter()]
    [switch]$Help,
    
    [Parameter()]
    [switch]$NoDebug,
    
    [Parameter()]
    [switch]$QuietMode,
    
    [Parameter()]
    [switch]$NoInfo,
    
    [Parameter()]
    [string]$SelectedDistro,
    
    [Parameter()]
    [string]$CustomName,
    
    [Parameter()]
    [string]$Username,
    
    [Parameter()]
    [string]$Password,
    
    [Parameter()]
    [string]$LogFile,
    
    [Parameter()]
    [switch]$InstallBrowsers
)

# Enable debug output to track script execution (unless NoDebug is specified)
if ($NoDebug) {
    $DebugPreference = "SilentlyContinue"
} else {
    $DebugPreference = "Continue"
}
Write-Debug "Script starting: Manage-WSLInstance.ps1"

# Set error action preference
$ErrorActionPreference = "Continue"  # Changed from "Stop" to prevent script from terminating on errors

# Create log file for debugging
if ([string]::IsNullOrEmpty($LogFile)) {
    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "wsl-manager-debug.log"
} else {
    $logFile = $LogFile  # Use the log file provided via parameter
}
Write-Debug "Log file will be: $logFile"

# Set default values for debug, quiet, and info modes
if (-not $NoDebug) {
    $script:DebugPreference = "SilentlyContinue"
}
if (-not $QuietMode) {
    $script:QuietMode = $false
}
if (-not $NoInfo) {
    $script:NoInfo = $true  # Set to true by default to disable info messages
}

# Log function for debugging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console with appropriate color based on level and settings
    if (-not $QuietMode -or $Level -eq "ERROR") {
        if ($Level -eq "INFO" -and -not $NoInfo) {
            Write-Host $logMessage
        } elseif ($Level -eq "ERROR") {
            Write-Host $logMessage -ForegroundColor Red
        } elseif ($Level -eq "WARNING" -and -not $QuietMode) {
            Write-Host $logMessage -ForegroundColor Yellow
        } elseif ($Level -eq "DEBUG" -and $DebugPreference -eq "Continue") {
            Write-Debug $logMessage
        }
    }
    
    # Always write to the provided log file with timestamp to show progress
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $fileMessage = "[$timestamp] [$Level] $Message"
        Add-Content -Path $logFile -Value $fileMessage -ErrorAction SilentlyContinue
    } catch {
        # Silently continue if can't write to log file
    }
}

Write-Log "Script execution started" "DEBUG"

try {
    Write-Log "Loading functions..." "DEBUG"
    
    # Check if running as administrator and self-elevate if needed
    function Test-AdminPrivileges {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Request-AdminPrivileges {
        $scriptPath = $MyInvocation.MyCommand.Definition
        $scriptArgs = $MyInvocation.BoundParameters.Keys | ForEach-Object { 
            if ($MyInvocation.BoundParameters[$_] -is [switch]) {
                "-$_"
            } else {
                "-$_ `"$($MyInvocation.BoundParameters[$_])`""
            }
        }
        $argString = $scriptArgs -join ' '
        
        Write-Host "Requesting administrative privileges..."
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $argString" -Verb RunAs
        exit
    }

    # Function to display help information
    function Show-Help {
        Write-Host "Manage-WSLInstance.ps1 - WSL Management Script"
        Write-Host "================================================"
        Write-Host ""
        Write-Host "Parameters:"
        Write-Host "  -CreateInstance  : Start the process to create a new WSL instance"
        Write-Host "  -ListInstalled   : List all installed WSL distributions"
        Write-Host "  -ListOnline      : List all available online WSL distributions"
        Write-Host "  -NoDebug         : Disable debug output messages"
        Write-Host "  -QuietMode       : Suppress warning and informational messages"
        Write-Host "  -NoInfo          : Disable info messages"
        Write-Host "  -SelectedDistro  : Specify the distribution to install (when used with -CreateInstance)"
        Write-Host "  -CustomName      : Specify a custom name for the WSL instance (when used with -CreateInstance)"
        Write-Host "  -Username        : Specify the username to create (when used with -CreateInstance)"
        Write-Host "  -Password        : Specify the password for the user (when used with -CreateInstance)"
        Write-Host "  -Help            : Show this help message"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\Manage-WSLInstance.ps1 -ListInstalled"
        Write-Host "  .\Manage-WSLInstance.ps1 -ListOnline"
        Write-Host "  .\Manage-WSLInstance.ps1 -CreateInstance"
        Write-Host "  .\Manage-WSLInstance.ps1 -CreateInstance -NoDebug"
        Write-Host "  .\Manage-WSLInstance.ps1 -CreateInstance -QuietMode"
        Write-Host "  .\Manage-WSLInstance.ps1 -CreateInstance -SelectedDistro 'Ubuntu-22.04' -CustomName 'MyUbuntu'"
        Write-Host ""
    }

    # Check if WSL is installed
    function Test-WSLInstalled {
        try {
            Write-Log "Checking if WSL is installed..." "DEBUG"
            $wslCheck = wsl --version 2>&1
            if ($wslCheck -match "Windows Subsystem for Linux") {
                Write-Log "WSL is installed" "DEBUG"
                return $true
            }
            else {
                Write-Log "WSL version check didn't return expected output" "DEBUG"
                return $true  # Always return true to bypass the check
            }
        }
        catch {
            Write-Log "Exception checking WSL: $_" "DEBUG"
            return $true  # Always return true to bypass the check
        }
    }

    # Function to get installed WSL distributions
    function Get-InstalledDistributions {
        param (
            [string]$Filter = ""
        )
        
        Write-Log "Getting installed distributions with filter: '$Filter'" "DEBUG"
        
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-WSLNames.ps1"
        if (Test-Path $scriptPath) {
            Write-Log "Using Get-WSLNames.ps1 script at: $scriptPath" "DEBUG"
            
            try {
                Write-Log "Running Get-WSLNames.ps1 with -installed parameter" "DEBUG"
                # Execute and capture output
                $output = & $scriptPath -installed
                
                # Display the results directly to console
                if ($output -and $output.Count -gt 0) {
                    Write-Host "`nInstalled WSL Distributions:"
                    Write-Host "============================"
                    foreach ($item in $output) {
                        Write-Host $item
                    }
                } else {
                    Write-Host "No distributions found." -ForegroundColor Yellow
                }
            }
            catch {
                Write-Log "Error running Get-WSLNames.ps1: $_" "ERROR"
                Write-Host "Error using script. Falling back to direct WSL command..." -ForegroundColor Yellow
                
                # Fallback to direct WSL command
                $output = wsl --list --verbose
                if ($output) {
                    # Parse the output
                    $distributions = @()
                    $lines = $output -split "`n" | Where-Object { $_ -match "\S" }
                    $startIndex = if ($lines[0] -match "NAME|STATE|VERSION") { 1 } else { 0 }
                    
                    for ($i = $startIndex; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i].Trim()
                        if ($line -match '^\*?\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                            $name = $Matches[1]
                            $state = $Matches[2]
                            $version = $Matches[3]
                            
                            # Remove the asterisk if present
                            $name = $name -replace '^\*', ''
                            
                            if (-not [string]::IsNullOrWhiteSpace($name)) {
                                $distributions += [PSCustomObject]@{
                                    Name = $name
                                    State = $state
                                    Version = $version
                                    IsDefault = $line.StartsWith('*')
                                }
                            }
                        }
                    }
                    
                    # Filter if needed
                    if ($Filter) {
                        $distributions = $distributions | Where-Object { $_.Name -like "*$Filter*" }
                    }
                    
                    # Display the results
                    if ($distributions.Count -gt 0) {
                        Write-Host "`nInstalled WSL Distributions:"
                        Write-Host "============================"
                        foreach ($distro in $distributions) {
                            $defaultMark = if ($distro.IsDefault) { "* " } else { "  " }
                            Write-Host "$defaultMark$($distro.Name) (State: $($distro.State), Version: $($distro.Version))"
                        }
                    } else {
                        Write-Host "No distributions found." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "No distributions found." -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Log "Required script not found: $scriptPath" "WARNING"
            Write-Log "Attempting to list WSL distributions directly..." "DEBUG"
            Write-Host "Script not found. Using direct WSL command..." -ForegroundColor Yellow
            
            # Fallback method using wsl.exe directly
            try {
                $output = wsl --list --verbose
                if ($output) {
                    # Parse the output
                    $distributions = @()
                    $lines = $output -split "`n" | Where-Object { $_ -match "\S" }
                    $startIndex = if ($lines[0] -match "NAME|STATE|VERSION") { 1 } else { 0 }
                    
                    for ($i = $startIndex; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i].Trim()
                        if ($line -match '^\*?\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                            $name = $Matches[1]
                            $state = $Matches[2]
                            $version = $Matches[3]
                            
                            # Remove the asterisk if present
                            $name = $name -replace '^\*', ''
                            
                            if (-not [string]::IsNullOrWhiteSpace($name)) {
                                $distributions += [PSCustomObject]@{
                                    Name = $name
                                    State = $state
                                    Version = $version
                                    IsDefault = $line.StartsWith('*')
                                }
                            }
                        }
                    }
                    
                    # Filter if needed
                    if ($Filter) {
                        $distributions = $distributions | Where-Object { $_.Name -like "*$Filter*" }
                    }
                    
                    # Display the results
                    if ($distributions.Count -gt 0) {
                        Write-Host "`nInstalled WSL Distributions:"
                        Write-Host "============================"
                        foreach ($distro in $distributions) {
                            $defaultMark = if ($distro.IsDefault) { "* " } else { "  " }
                            Write-Host "$defaultMark$($distro.Name) (State: $($distro.State), Version: $($distro.Version))"
                        }
                    } else {
                        Write-Host "No distributions found." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "No distributions found." -ForegroundColor Yellow
                }
            }
            catch {
                Write-Log "Could not list WSL distributions: $_" "ERROR"
                Write-Host "Error listing WSL distributions." -ForegroundColor Red
            }
        }
    }

    # Function to get online WSL distributions
    function Get-OnlineDistributions {
        param (
            [string]$Filter = ""
        )
        
        Write-Log "Getting online distributions with filter: '$Filter'" "DEBUG"
        
        try {
            # First try to get the list directly from wsl.exe
            Write-Log "Attempting to get online distributions from wsl.exe" "DEBUG"
            $output = cmd.exe /c "wsl.exe --list --online 2>nul"
            
            if ($output) {
                # Convert to array if it's a string
                if ($output -is [string]) {
                    $output = $output -split "`n"
                }
                
                # Clean up the output - remove empty lines, trim whitespace, and remove duplicates
                $cleanOutput = $output | 
                    Where-Object { $_ -and $_.Trim() } | 
                    ForEach-Object { $_.Trim() } | 
                    Where-Object { $_ -notmatch '^\s*$' } |  # Remove empty lines
                    Where-Object { $_ -notmatch '^\s*NAME\s*' } |  # Remove header
                    Where-Object { $_ -notmatch '^\s*-\s*$' } |  # Remove separator lines
                    Where-Object { $_ -notmatch '^The following' } |  # Remove instruction lines
                    Where-Object { $_ -notmatch '^Install using' } |  # Remove instruction lines
                    Where-Object { $_ -match '^Ubuntu' } |  # Only keep Ubuntu distributions
                    ForEach-Object { 
                        # Extract just the distribution name (first part before spaces)
                        ($_ -split '\s+')[0]
                    } |
                    Select-Object -Unique | 
                    Sort-Object
                
                if ($cleanOutput -and $cleanOutput.Count -gt 0) {
                    return $cleanOutput
                }
            }
            
            # If direct wsl.exe command fails, try the script
            $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-WSLNames.ps1"
            if (Test-Path $scriptPath) {
                Write-Log "Using Get-WSLNames.ps1 script at: $scriptPath" "DEBUG"
                $params = @("-Online")
                if ($Filter) {
                    $params += "-Filter", $Filter
                }
                
                $output = & $scriptPath @params
                
                if ($output -and $output.Count -gt 0) {
                    # Clean up the output and filter for Ubuntu only
                    $cleanOutput = $output | 
                        Where-Object { $_ -and $_.Trim() } | 
                        ForEach-Object { $_.Trim() } | 
                        Where-Object { $_ -match '^Ubuntu' } |  # Only keep Ubuntu distributions
                        Select-Object -Unique | 
                        Sort-Object
                    
                    if ($cleanOutput -and $cleanOutput.Count -gt 0) {
                        return $cleanOutput
                    }
                }
            }
            
            # Return fallback list with only Ubuntu distributions
            return @(
                "Ubuntu",
                "Ubuntu-18.04",
                "Ubuntu-20.04",
                "Ubuntu-22.04",
                "Ubuntu-24.04"
            )
        }
        catch {
            # Return fallback list with only Ubuntu distributions
            return @(
                "Ubuntu",
                "Ubuntu-18.04",
                "Ubuntu-20.04",
                "Ubuntu-22.04",
                "Ubuntu-24.04"
            )
        }
    }

    # Function to create a new WSL instance
    function New-WSLInstance {
        param (
            [string]$PreSelectedDistro = "",
            [string]$PreCustomName = "",
            [string]$PreUsername = "",
            [string]$PrePassword = ""
        )
        
        try {
            # Use provided distro or prompt user to select one
            $selectedDistro = $PreSelectedDistro
            
            if ([string]::IsNullOrWhiteSpace($selectedDistro)) {
                # Show available distributions
                Write-Host "`nAvailable Ubuntu distributions:"
                
                try {
                    # Try to get online distributions, but use a fallback list if it fails
                    $ubuntuDistros = Get-OnlineDistributions
                    
                    if ($null -eq $ubuntuDistros -or $ubuntuDistros.Count -eq 0) {
                        $ubuntuDistros = @(
                            "Ubuntu",
                            "Ubuntu-18.04",
                            "Ubuntu-20.04",
                            "Ubuntu-22.04",
                            "Ubuntu-24.04"
                        )
                    }
                }
                catch {
                    $ubuntuDistros = @(
                        "Ubuntu",
                        "Ubuntu-18.04",
                        "Ubuntu-20.04",
                        "Ubuntu-22.04",
                        "Ubuntu-24.04"
                    )
                }
                
                for ($i = 0; $i -lt $ubuntuDistros.Count; $i++) {
                    Write-Host "[$i] $($ubuntuDistros[$i])"
                }
                
                # Get distribution selection from user
                $selectedIndex = -1
                do {
                    $selection = Read-Host "Enter the number of the distribution you want to install"
                    if ([int]::TryParse($selection, [ref]$selectedIndex) -and $selectedIndex -ge 0 -and $selectedIndex -lt $ubuntuDistros.Count) {
                        break
                    }
                    Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                } while ($true)
                
                $selectedDistro = $ubuntuDistros[$selectedIndex]
                Write-Host "You selected: $selectedDistro" -ForegroundColor Green
            }
            else {
                Write-Host "Using pre-selected distribution: $selectedDistro" -ForegroundColor Green
            }
            
            # Get custom name for the new instance, using pre-provided value if available
            $customName = $PreCustomName
            if ([string]::IsNullOrWhiteSpace($customName)) {
                $customName = Read-Host "Enter a custom name for the new instance (or press Enter to use the default name)"
            }
            
            # If no custom name provided, use the distribution name
            if ([string]::IsNullOrWhiteSpace($customName)) {
                $customName = $selectedDistro
            }
            
            Write-Host "Using custom name: $customName" -ForegroundColor Green
            
            # Default to installing the distribution
            $shouldInstall = $true
            
            # Check if selected distribution already exists
            try {
                Write-Log "Checking if distribution '$selectedDistro' already exists..." "INFO"
                $existingDistros = cmd.exe /c "wsl.exe --list --quiet 2>nul"
                
                # Clean up the output and convert to proper array if it's not
                if ($existingDistros -is [string]) {
                    $existingDistros = $existingDistros -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                }
                
                Write-Log "Existing distributions: $($existingDistros -join ', ')" "DEBUG"
                
                # Check for exact match of the selected distro
                $distroExists = $false
                foreach ($distro in $existingDistros) {
                    if ($distro -eq $selectedDistro) {
                        $distroExists = $true
                        break
                    }
                }
                
                Write-Log "Selected distribution '$selectedDistro' exists: $distroExists" "INFO"
                
                # Check for exact match of the custom name
                $customExists = $false
                foreach ($distro in $existingDistros) {
                    if ($distro -eq $customName) {
                        $customExists = $true
                        break
                    }
                }
                
                Write-Log "Custom name '$customName' exists: $customExists" "INFO"
                
                # Handle existing distributions
                if ($distroExists) {
                    Write-Host "The distribution '$selectedDistro' already exists on your system." -ForegroundColor Yellow
                    Write-Log "Distribution '$selectedDistro' already exists" "WARNING"
                    $action = Read-Host "Do you want to (D)elete it before reinstalling, or (S)kip installation and just rename? [D/S]"
                    
                    if ($action -eq "D" -or $action -eq "d") {
                        Write-Host "Unregistering existing distribution '$selectedDistro'..." -ForegroundColor Yellow
                        Write-Log "Unregistering existing distribution '$selectedDistro'..." "INFO"
                        try {
                            $unregisterOutput = wsl --unregister $selectedDistro 2>&1
                            Write-Host "Distribution '$selectedDistro' has been unregistered." -ForegroundColor Green
                            Write-Log "Unregistered ${selectedDistro}: ${unregisterOutput}" "INFO"
                            # Continue with fresh installation
                            $shouldInstall = $true
                        }
                        catch {
                            Write-Host "Error unregistering distribution: $_" -ForegroundColor Red
                            Write-Log "Error unregistering distribution: $_" "ERROR"
                            Write-Host "Installation will likely fail. Proceeding anyway..." -ForegroundColor Yellow
                            $shouldInstall = $false
                        }
                    }
                    else {
                        # Skip installation, proceed with export/import only
                        Write-Host "Skipping installation, proceeding with export/import..." -ForegroundColor Cyan
                        Write-Log "Skipping installation, proceeding with export/import" "INFO"
                        $shouldInstall = $false
                    }
                }
                
                if ($customExists) {
                    Write-Host "A distribution with the custom name '$customName' already exists." -ForegroundColor Yellow
                    Write-Log "Custom name '$customName' already exists" "WARNING"
                    $deleteCustom = Read-Host "Do you want to delete the existing '$customName' instance before continuing? [Y/N]"
                    
                    if ($deleteCustom -eq "Y" -or $deleteCustom -eq "y") {
                        Write-Host "Unregistering existing distribution '$customName'..." -ForegroundColor Yellow
                        Write-Log "Unregistering existing distribution '$customName'..." "INFO"
                        try {
                            $unregisterCustomOutput = wsl --unregister $customName 2>&1
                            Write-Host "Distribution '$customName' has been unregistered." -ForegroundColor Green
                            Write-Log "Unregistered custom name ${customName}: ${unregisterCustomOutput}" "INFO"
                        }
                        catch {
                            Write-Host "Error unregistering distribution: $_" -ForegroundColor Red
                            Write-Log "Error unregistering distribution: $_" "ERROR"
                            Write-Host "Export/import may fail if the distribution still exists." -ForegroundColor Yellow
                        }
                    }
                    else {
                        Write-Host "Creation aborted. Please use a different name or manage the existing distribution." -ForegroundColor Yellow
                        Write-Log "Creation aborted. User chose not to delete existing custom name." "INFO"
                        return
                    }
                }
            }
            catch {
                Write-Host "Error checking existing distributions: $_" -ForegroundColor Red
                Write-Log "Error checking existing distributions: $_" "ERROR"
                Write-Host "Continuing with installation. This may fail if the distribution already exists." -ForegroundColor Yellow
                $shouldInstall = $true
            }
            
            # Install the selected distribution if needed
            if ($shouldInstall) {
                # Provide installation instructions
                Write-Host "`nTo install $selectedDistro, you need to run the following command in an elevated command prompt:" -ForegroundColor Cyan
                Write-Host "wsl --install -d $selectedDistro" -ForegroundColor White -BackgroundColor DarkBlue
                
                $proceedInstall = Read-Host "`nDo you want to attempt automatic installation? (Y/N)"
                
                if ($proceedInstall -eq "Y" -or $proceedInstall -eq "y") {
                    # Install the selected distribution
                    Write-Host "Installing $selectedDistro..." -ForegroundColor Cyan
                    Write-Log "Installing $selectedDistro... This may take several minutes" "INFO"
                    
                    try {
                        # Try the installation
                        Write-Log "Running WSL installation: wsl --install -d $selectedDistro" "INFO"
                        $installProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "--install -d $selectedDistro" -PassThru -NoNewWindow

                        if (-not $installProcess) {
                            throw "Failed to start the WSL installation process."
                        }

                        $maxWaitMinutes = 30
                        $checkIntervalSeconds = 5
                        $elapsedSeconds = 0
                        Write-Host "Provisioning $selectedDistro. This can take several minutes." -ForegroundColor Cyan
                        Write-Log "Waiting on WSL provisioning (max ${maxWaitMinutes} minutes, ${checkIntervalSeconds}s interval)" "INFO"

                        while (-not $installProcess.HasExited) {
                            Start-Sleep -Seconds $checkIntervalSeconds
                            $elapsedSeconds += $checkIntervalSeconds

                            if (($elapsedSeconds % 60) -eq 0) {
                                $elapsedMinutes = [math]::Round($elapsedSeconds / 60, 2)
                                Write-Host "Still waiting for provisioning to finish... (${elapsedMinutes} minutes elapsed)" -ForegroundColor DarkCyan
                                Write-Log "Provisioning still running after ${elapsedMinutes} minutes" "INFO"
                            }

                            if ($elapsedSeconds -ge ($maxWaitMinutes * 60)) {
                                Write-Host "Provisioning is taking longer than expected." -ForegroundColor Yellow
                                Write-Log "Provisioning exceeded ${maxWaitMinutes} minutes" "WARNING"
                                $userChoice = Read-Host "Press Enter to keep waiting or type 'C' to cancel the installation"
                                if ($userChoice -and $userChoice.ToUpper() -eq 'C') {
                                    Write-Log "User requested cancellation after timeout" "WARNING"
                                    try {
                                        $installProcess.CloseMainWindow() | Out-Null
                                        Start-Sleep -Seconds 2
                                    } catch {
                                        Write-Log "CloseMainWindow failed: $_" "DEBUG"
                                    }

                                    if (-not $installProcess.HasExited) {
                                        Write-Log "Forcing installation process to stop" "WARNING"
                                        Stop-Process -Id $installProcess.Id -Force -ErrorAction SilentlyContinue
                                    }

                                    throw "WSL installation cancelled by user after waiting ${maxWaitMinutes} minutes."
                                }

                                Write-Host "Continuing to wait for provisioning..." -ForegroundColor Cyan
                                Write-Log "User opted to continue waiting" "INFO"
                                $elapsedSeconds = 0
                            }
                        }

                        $installProcess.WaitForExit()
                        $exitCode = $installProcess.ExitCode

                        if ($exitCode -ne 0) {
                            $errorMsg = "WSL installation process exited with code $exitCode"
                            Write-Log $errorMsg "ERROR"
                            throw $errorMsg
                        }

                        Write-Host "Distribution $selectedDistro installation initiated successfully." -ForegroundColor Green
                        Write-Log "Distribution $selectedDistro installation initiated successfully" "INFO"
                        
                        # Allow time for installation telemetry to settle
                        Write-Host "Verifying that installation completed..." -ForegroundColor Cyan
                        Write-Log "Waiting briefly before verification (5 seconds)..." "INFO"
                        Start-Sleep -Seconds 5
                        
                        # Verify the installation
                        Write-Log "Verifying installation..." "INFO"
                        $verifyDistro = cmd.exe /c "wsl.exe --list --quiet 2>nul"
                        $distroInstalled = $false
                        
                        if ($verifyDistro -is [string]) {
                            $verifyDistro = $verifyDistro -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                        }
                        
                        foreach ($distro in $verifyDistro) {
                            if ($distro -eq $selectedDistro) {
                                $distroInstalled = $true
                                break
                            }
                        }
                        
                        if (-not $distroInstalled) {
                            Write-Host "The distribution was not found after installation. Installation may still be in progress." -ForegroundColor Yellow
                            Write-Log "Distribution not found after installation wait period. Installation may still be in progress." "WARNING"
                            Write-Host "Please wait for the installation to complete and then try again." -ForegroundColor Yellow
                            return
                        }
                        
                        Write-Log "Installation verification successful. Distribution is installed." "INFO"
                    }
                    catch {
                        Write-Host "Error during installation: $_" -ForegroundColor Red
                        Write-Log "Error during installation: $_" "ERROR"
                        Write-Host "`nIf the automatic installation failed, please try manual installation:" -ForegroundColor Yellow
                        Write-Host "1. Open a Command Prompt as Administrator" -ForegroundColor Yellow
                        Write-Host "2. Run: wsl --install -d $selectedDistro" -ForegroundColor Yellow
                        Write-Host "3. Restart your computer if prompted" -ForegroundColor Yellow
                        
                        $continueCustomName = Read-Host "`nDo you want to continue with custom name setup anyway? (Y/N)"
                        if ($continueCustomName -ne "Y" -and $continueCustomName -ne "y") {
                            Write-Log "User chose not to continue after installation error" "INFO"
                            return
                        }
                    }
                }
                else {
                    Write-Host "Skipping installation. You'll need to install the distribution manually." -ForegroundColor Yellow
                    Write-Log "User chose to skip automatic installation" "INFO"
                    return
                }
            }
            
            # Check if the distribution exists before attempting export/import
            $distroExistsForExport = $false
            try {
                Write-Log "Checking if distribution exists before export/import..." "INFO"
                $checkDistros = cmd.exe /c "wsl.exe --list --quiet 2>nul"
                
                # Clean up the output and convert to proper array if it's not
                if ($checkDistros -is [string]) {
                    $checkDistros = $checkDistros -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                }
                
                foreach ($distro in $checkDistros) {
                    if ($distro -eq $selectedDistro) {
                        $distroExistsForExport = $true
                        break
                    }
                }
                
                if (-not $distroExistsForExport) {
                    Write-Host "Error: The distribution '$selectedDistro' does not exist. Cannot proceed with export/import." -ForegroundColor Red
                    Write-Log "Error: The distribution '$selectedDistro' does not exist. Cannot proceed with export/import." "ERROR"
                    Write-Host "Please make sure the distribution is installed first." -ForegroundColor Yellow
                    return
                }
                
                Write-Log "Distribution '$selectedDistro' exists. Proceeding with export/import." "INFO"
            }
            catch {
                Write-Host "Error checking if distribution exists: $_" -ForegroundColor Red
                Write-Log "Error checking if distribution exists: $_" "ERROR"
                return
            }
            
            # If a custom name was specified, export and reimport with the new name
            if ($customName -ne $selectedDistro) {
                Write-Host "`nRenaming '$selectedDistro' to '$customName'..." -ForegroundColor Cyan
                Write-Log "Renaming '$selectedDistro' to '$customName'..." "INFO"
                Write-Host "This will export the distribution and reimport it with a new name." -ForegroundColor Cyan
                
                # CRITICAL: Double-check if custom name exists right before export/import
                # This ensures we catch any distributions created during the installation process
                Write-Host "Final check: Verifying if '$customName' already exists..." -ForegroundColor Yellow
                Write-Log "Final check: Verifying if '$customName' already exists..." "INFO"
                $finalCheckExists = $false
                
                try {
                    # Direct check using WSL command for maximum reliability
                    $existingDistros = cmd.exe /c "wsl.exe --list --quiet 2>nul"
                    if ($existingDistros -is [string]) {
                        $existingDistros = $existingDistros -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    }
                    
                    foreach ($distro in $existingDistros) {
                        if ($distro -eq $customName) {
                            $finalCheckExists = $true
                            break
                        }
                    }
                    
                    if ($finalCheckExists) {
                        Write-Host "CRITICAL: The custom name '$customName' already exists on your system." -ForegroundColor Red
                        Write-Log "CRITICAL: The custom name '$customName' already exists on the system." "ERROR"
                        Write-Host "This will cause the import operation to fail." -ForegroundColor Red
                        $finalDelete = Read-Host "Do you want to delete the existing '$customName' before continuing? [Y/N]"
                        
                        if ($finalDelete -eq "Y" -or $finalDelete -eq "y") {
                            Write-Host "Unregistering existing distribution '$customName'..." -ForegroundColor Yellow
                            Write-Log "Unregistering existing distribution '$customName'..." "INFO"
                            try {
                                $unregisterCustomOutput = wsl --unregister $customName 2>&1
                                Write-Host "Distribution '$customName' has been unregistered." -ForegroundColor Green
                                Write-Log "Unregistered custom name ${customName}: ${unregisterCustomOutput}" "INFO"
                                # Small delay to ensure the unregistration completes
                                Start-Sleep -Seconds 2
                            }
                            catch {
                                Write-Host "Error unregistering distribution: $_" -ForegroundColor Red
                                Write-Log "Error unregistering distribution: $_" "ERROR"
                                Write-Host "Export/import will likely fail. Aborting operation." -ForegroundColor Red
                                return
                            }
                        }
                        else {
                            Write-Host "Operation aborted. The export/import would fail with the existing name." -ForegroundColor Yellow
                            Write-Log "Operation aborted. User chose not to delete existing custom name." "INFO"
                            return
                        }
                    }
                }
                catch {
                    Write-Host "Error during final custom name check: $_" -ForegroundColor Red
                    Write-Log "Error during final custom name check: $_" "ERROR"
                    Write-Host "Proceeding anyway, but this may fail if the custom name is already in use." -ForegroundColor Yellow
                }
                
                try {
                    # Create a temp directory for the export file
                    $tempDir = Join-Path $env:TEMP "WSLExport"
                    if (-not (Test-Path $tempDir)) {
                        Write-Log "Creating temp directory: $tempDir" "INFO"
                        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                    }
                    
                    $tarFile = Join-Path $tempDir "$selectedDistro.tar"
                    Write-Log "Export tar file will be: $tarFile" "INFO"
                    
                    # Export the distribution
                    Write-Host "Exporting $selectedDistro..." -ForegroundColor Cyan
                    Write-Log "Exporting $selectedDistro... This may take several minutes" "INFO"
                    $exportProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "--export $selectedDistro $tarFile" -Wait -PassThru -NoNewWindow
                    
                    if ($exportProcess.ExitCode -ne 0) {
                        $errorMsg = "Export process exited with code $($exportProcess.ExitCode)"
                        Write-Log $errorMsg "ERROR"
                        throw $errorMsg
                    }
                    
                    Write-Log "Export completed successfully" "INFO"
                    
                    # Create a directory for the custom distribution
                    $wslDir = Join-Path $env:USERPROFILE "WSL"
                    $customDir = Join-Path $wslDir $customName
                    Write-Log "Creating directory for import: $customDir" "INFO"
                    if (-not (Test-Path $customDir)) {
                        New-Item -ItemType Directory -Path $customDir -Force | Out-Null
                    }
                    
                    # Import with the custom name
                    Write-Host "Importing as $customName..." -ForegroundColor Cyan
                    Write-Log "Importing as $customName... This may take several minutes" "INFO"
                    $importProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "--import $customName $customDir $tarFile --version 2" -Wait -PassThru -NoNewWindow
                    
                    if ($importProcess.ExitCode -ne 0) {
                        $errorMsg = "Import process exited with code $($importProcess.ExitCode)"
                        Write-Log $errorMsg "ERROR"
                        throw $errorMsg
                    }
                    
                    Write-Log "Import completed successfully" "INFO"
                    
                    # Unregister the original distribution if requested
                    if ($shouldInstall) {
                        Write-Host "Cleaning up original distribution..." -ForegroundColor Cyan
                        Write-Log "Cleaning up original distribution '$selectedDistro'..." "INFO"
                        $unregisterProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "--unregister $selectedDistro" -Wait -PassThru -NoNewWindow
                        Write-Log "Original distribution unregistered" "INFO"
                    }
                    
                    # Clean up the tar file
                    Write-Log "Cleaning up tar file: $tarFile" "INFO"
                    Remove-Item $tarFile -Force -ErrorAction SilentlyContinue
                    
                    # Use provided username or prompt user
                    $wslUsername = $PreUsername
                    if ([string]::IsNullOrWhiteSpace($wslUsername)) {
                        Write-Host "`nSetting up user account for your WSL instance." -ForegroundColor Green
                        Write-Host "This will be the default user for your distribution." -ForegroundColor Cyan
                        $wslUsername = Read-Host "Enter a username"
                    }
                    
                    # Default to a simple username if none provided
                    if ([string]::IsNullOrWhiteSpace($wslUsername)) {
                        $wslUsername = "wsluser"
                        Write-Host "Using default username: $wslUsername" -ForegroundColor Yellow
                        Write-Log "Using default username: $wslUsername" "INFO"
                    } else {
                        Write-Log "Using username: $wslUsername" "INFO"
                    }
                    
                    # Get the password if not provided
                    $plainPassword = $PrePassword
                    if ([string]::IsNullOrWhiteSpace($plainPassword)) {
                        $passwordMatch = $false
                        Write-Log "Prompting for password" "INFO"
                        
                        while (-not $passwordMatch) {
                            $wslPassword = Read-Host "Enter a password" -AsSecureString
                            $confirmPassword = Read-Host "Confirm password" -AsSecureString
                            
                            $bstr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($wslPassword)
                            $pwd1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
                            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
                            
                            $bstr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword)
                            $pwd2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
                            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
                            
                            if ($pwd1 -eq $pwd2) {
                                $plainPassword = $pwd1
                                $passwordMatch = $true
                                Write-Log "Password confirmed" "INFO"
                            }
                            else {
                                Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
                                Write-Log "Passwords did not match, prompting again" "WARNING"
                            }
                        }
                    } else {
                        Write-Log "Using provided password" "INFO"
                    }
                    
                    # If no password was provided, use a simple default
                    if ([string]::IsNullOrWhiteSpace($plainPassword)) {
                        $plainPassword = "password123"  # Default password
                        Write-Host "Using a default password. You should change this later!" -ForegroundColor Yellow
                        Write-Log "Using default password" "WARNING"
                    }
                    
                    # Create the user in the WSL instance
                    Write-Host "Creating user $wslUsername in the WSL instance..." -ForegroundColor Cyan
                    Write-Log "Creating user $wslUsername in the WSL instance..." "INFO"
                    try {
                        $userCreateCmd = "useradd -m -s /bin/bash ${wslUsername} && echo '${wslUsername}:${plainPassword}' | chpasswd && usermod -aG sudo ${wslUsername}"
                        Write-Log "Running user creation command" "INFO"
                        $userResult = wsl -d $customName -u root -- bash -c $userCreateCmd 2>&1
                        Write-Host "User created successfully." -ForegroundColor Green
                        Write-Log "User created successfully" "INFO"
                    }
                    catch {
                        Write-Host "Error creating user: $_" -ForegroundColor Red
                        Write-Log "Error creating user: $_" "ERROR"
                        Write-Host "You may need to create a user manually using: wsl -d $customName -u root" -ForegroundColor Yellow
                    }
                    
                    # Update wsl.conf to set the default user
                    Write-Host "Setting $wslUsername as the default user..." -ForegroundColor Cyan
                    Write-Log "Setting $wslUsername as the default user..." "INFO"
                    try {
                        $wslConfCmd = "echo -e '[user]\ndefault=${wslUsername}' > /etc/wsl.conf"
                        Write-Log "Updating wsl.conf" "INFO"
                        $wslConfResult = wsl -d $customName -u root -- bash -c $wslConfCmd 2>&1
                        Write-Host "Default user set successfully." -ForegroundColor Green
                        Write-Log "Default user set successfully" "INFO"
                    }
                    catch {
                        Write-Host "Error setting default user: $_" -ForegroundColor Red
                        Write-Log "Error setting default user: $_" "ERROR"
                        Write-Host "You may need to update /etc/wsl.conf manually." -ForegroundColor Yellow
                    }
                    
                    # Restart the WSL instance to apply the user change
                    Write-Host "Restarting WSL instance to apply user changes..." -ForegroundColor Cyan
                    Write-Log "Restarting WSL instance to apply user changes..." "INFO"
                    try {
                        wsl --terminate $customName
                        Write-Log "WSL instance terminated" "INFO"
                        Start-Sleep -Seconds 2
                    }
                    catch {
                        Write-Host "Warning: Could not restart WSL instance: $_" -ForegroundColor Yellow
                        Write-Log "Warning: Could not restart WSL instance: $_" "WARNING"
                    }
                    
                    # Start the distribution with the user account
                    Write-Host "`nSetup complete! Starting $customName..." -ForegroundColor Green
                    Write-Log "Setup complete! Starting $customName with user $wslUsername..." "INFO"
                    Write-Host "Launching with user: $wslUsername" -ForegroundColor Cyan
                    
                    # Always offer browser installation
                    Write-Log "Offering browser installation" "INFO"
                    Install-Browsers -DistroName $customName -WslUsername $wslUsername

                    Read-Host "Press Enter to continue"
                    
                    # Launch the distribution with the user account (not as root)
                    try {
                        Write-Log "Launching WSL with command: wsl -d $customName -u $wslUsername" "INFO"
                        Start-Process -FilePath "wsl.exe" -ArgumentList "-d $customName -u $wslUsername"
                        Write-Log "WSL process started successfully" "INFO"
                    }
                    catch {
                        Write-Host "Error launching distribution: $_" -ForegroundColor Red
                        Write-Log "Error launching distribution: $_" "ERROR"
                        Write-Host "Try launching manually with: wsl -d $customName -u $wslUsername" -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "Error creating custom-named instance: $_" -ForegroundColor Red
                    Write-Log "Error creating custom-named instance: $_" "ERROR"
                    Write-Host "`nManual steps to create a custom-named instance:" -ForegroundColor Yellow
                    Write-Host "1. Export the distribution: wsl --export $selectedDistro C:\path\to\export.tar" -ForegroundColor Yellow
                    Write-Host "2. Import with custom name: wsl --import $customName C:\path\to\install\location C:\path\to\export.tar --version 2" -ForegroundColor Yellow
                    Write-Host "3. Unregister original: wsl --unregister $selectedDistro" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "Distribution $selectedDistro has been installed successfully." -ForegroundColor Green
                Write-Log "Distribution $selectedDistro has been installed successfully" "INFO"
                Write-Host "You can start it with: wsl -d $selectedDistro" -ForegroundColor Cyan
                
                # Always offer browser installation
                Write-Log "Offering browser installation" "INFO"
                Install-Browsers -DistroName $selectedDistro -WslUsername "root"
                
                try {
                    Read-Host "Press Enter to launch the distribution"
                    Write-Log "Launching WSL with command: wsl -d $selectedDistro" "INFO"
                    Start-Process -FilePath "wsl.exe" -ArgumentList "-d $selectedDistro"
                    Write-Log "WSL process started successfully" "INFO"
                }
                catch {
                    Write-Host "Error launching distribution: $_" -ForegroundColor Red
                    Write-Log "Error launching distribution: $_" "ERROR"
                    Write-Host "Try launching manually with: wsl -d $selectedDistro" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Log "Error in New-WSLInstance: $_" "ERROR"
            Write-Host "Error creating WSL instance: $_" -ForegroundColor Red
        }
    }

    # Function to install browsers in the WSL instance
    function Install-Browsers {
        param (
            [string]$DistroName,
            [string]$WslUsername
        )
        
        try {
            Write-Host "`nWould you like to install browsers in the WSL instance? (Y/N)" -ForegroundColor Cyan
            Write-Log "Asking user if they want to install browsers" "INFO"
            $installBrowsers = Read-Host
            
            if ($installBrowsers.ToLower() -eq "y") {
                Write-Host "Installing browsers in the WSL instance..." -ForegroundColor Cyan
                Write-Log "User confirmed browser installation" "INFO"
                
                # Get the script path exactly as user requested
                $scriptDir = Get-Location
                $winPath = "$scriptDir\wsl-install-browsers.sh"
                
                # Convert Windows path to WSL path
                $wslPath = $winPath.Replace('C:', '/mnt/c').Replace('\', '/')
                
                Write-Log "Windows path: $winPath" "INFO"
                Write-Log "WSL path: $wslPath" "INFO"
                
                # Execute in WSL using exact command provided by user
                $command = "cp '$wslPath' ~/ && chmod +x ~/wsl-install-browsers.sh && ~/wsl-install-browsers.sh"
                Write-Log "Browser installation command: $command" "INFO"
                
                Write-Host "Launching interactive terminal for browser installation..." -ForegroundColor Cyan
                Write-Host "Please respond to any prompts in the terminal window." -ForegroundColor Yellow
                try {
                    # Launch interactive terminal window
                    Start-Process -FilePath "wsl.exe" -ArgumentList "-d $DistroName bash -c `"$command`"" -NoNewWindow:$false -Wait
                    Write-Host "Browser installation complete. Terminal window closed." -ForegroundColor Green
                    Write-Log "Browser installation process completed" "INFO"
                }
                catch {
                    Write-Host "Error installing browsers: $_" -ForegroundColor Red
                    Write-Log "Error installing browsers: $_" "ERROR"
                }
            }
            else {
                Write-Host "Browser installation skipped." -ForegroundColor Yellow
                Write-Log "User skipped browser installation" "INFO"
            }
        }
        catch {
            Write-Host "Error during browser installation: $_" -ForegroundColor Red
            Write-Log "Error during browser installation: $_" "ERROR"
        }
    }

    # Helper function for user-friendly WSL instance selection
    function Select-WSLInstance {
        param (
            [string]$Purpose = "select"
        )
        $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
        $instances = @(& $scriptPath -installed)
        $instances = $instances | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($instances.Count -eq 0) {
            Write-Host "No WSL instances found." -ForegroundColor Yellow
            return $null
        }
        Write-Host ""
        Write-Host "Available WSL Instances:" -ForegroundColor Green
        Write-Host "=========================" -ForegroundColor DarkCyan
        for ($i = 0; $i -lt $instances.Count; $i++) {
            Write-Host ("[{0}] {1}" -f ($i+1), $instances[$i]) -ForegroundColor White
        }
        Write-Host "[q] Return to main menu" -ForegroundColor Yellow
        $attempts = 0
        do {
            Write-Host ""
            Write-Host "Enter the number of the WSL instance to $Purpose (or 'q' to return):" -ForegroundColor Cyan
            $input = Read-Host
            if ($input -eq 'q' -or $input -eq 'exit') { return $null }
            if ($input -match '^[0-9]+$') {
                $ix = [int]$input
                if ($ix -ge 1 -and $ix -le $instances.Count) {
                    return $instances[$ix-1]
                }
            }
            Write-Host "Invalid selection. Please enter a valid number or 'q'." -ForegroundColor Red
            $attempts++
        } while ($attempts -lt 3)
        Write-Host "Too many invalid attempts. Returning to main menu." -ForegroundColor Yellow
        return $null
    }

    # Function to install browsers on existing WSL instance
    function Install-BrowsersOnExistingInstance {
        try {
            Write-Host "`nInstalling browsers on existing WSL instance" -ForegroundColor Cyan
            Write-Log "Starting browser installation on existing instance" "INFO"

            $instanceName = Select-WSLInstance -Purpose "install browsers on"
            if (-not $instanceName) {
                Write-Host "Returning to main menu..." -ForegroundColor Yellow
                return
            }

            # Get username for the instance with validation
            $username = ""
            $attempts = 0
            do {
                Write-Host "Enter the username to use for the instance (default: root, or 'q' to return):" -ForegroundColor Cyan
                $username = Read-Host
                if ($username -eq 'q' -or $username -eq 'exit') {
                    Write-Host "Returning to main menu..." -ForegroundColor Yellow
                    return
                }
                if ([string]::IsNullOrWhiteSpace($username)) {
                    $username = "root"
                }
                # Verify username exists in the instance
                try {
                    $userCheck = wsl -d $instanceName -u root -- bash -c "id -u $username 2>/dev/null"
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Error: Username '$username' does not exist in the instance. Please try again." -ForegroundColor Red
                        Write-Log "Error: Username '$username' does not exist in the instance" "ERROR"
                        $username = ""
                    }
                }
                catch {
                    Write-Host "Error checking username: $_" -ForegroundColor Red
                    Write-Log "Error checking username: $_" "ERROR"
                    $username = ""
                }
                $attempts++
            } while ([string]::IsNullOrWhiteSpace($username) -and $attempts -lt 3)
            if ([string]::IsNullOrWhiteSpace($username)) {
                Write-Host "Too many invalid attempts. Returning to main menu." -ForegroundColor Yellow
                return
            }

            # Install browsers
            Install-Browsers -DistroName $instanceName -WslUsername $username

            Write-Host "`nBrowser installation process completed for instance: $instanceName" -ForegroundColor Green
            Write-Log "Browser installation process completed for instance: $instanceName" "INFO"
        }
        catch {
            Write-Host "Error installing browsers on existing instance: $_" -ForegroundColor Red
            Write-Log "Error installing browsers on existing instance: $_" "ERROR"
        }
    }

    # Function to set username and password for an existing WSL instance
    function Set-WSLUserCredentials {
        try {
            Write-Host "`nSetting username and password for existing WSL instance" -ForegroundColor Cyan
            Write-Log "Starting user credential setup for existing instance" "INFO"
            
            $instanceName = Select-WSLInstance -Purpose "set credentials for"
            if (-not $instanceName) {
                Write-Host "Returning to main menu..." -ForegroundColor Yellow
                return
            }

            # Get username for the instance
            $username = ""
            do {
                Write-Host "Enter the new username for the instance (or 'q' to return):" -ForegroundColor Cyan
                $username = Read-Host
                if ($username -eq 'q' -or $username -eq 'exit') {
                    Write-Host "Returning to main menu..." -ForegroundColor Yellow
                    return
                }
                if ([string]::IsNullOrWhiteSpace($username)) {
                    Write-Host "Username cannot be blank. Please try again." -ForegroundColor Red
                    continue
                }
            } while ([string]::IsNullOrWhiteSpace($username))

            # Get password with confirmation
            $passwordMatch = $false
            $plainPassword = ""
            Write-Log "Prompting for password" "INFO"
            while (-not $passwordMatch) {
                $wslPassword = Read-Host "Enter a password" -AsSecureString
                $confirmPassword = Read-Host "Confirm password" -AsSecureString
                $bstr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($wslPassword)
                $pwd1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
                $bstr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword)
                $pwd2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
                if ($pwd1 -eq $pwd2) {
                    $plainPassword = $pwd1
                    $passwordMatch = $true
                    Write-Log "Password confirmed" "INFO"
                } else {
                    Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
                    Write-Log "Passwords did not match, prompting again" "WARNING"
                }
            }

            # Create the user in the WSL instance
            Write-Host "Creating user $username in the WSL instance..." -ForegroundColor Cyan
            Write-Log "Creating user $username in the WSL instance..." "INFO"
            try {
                $userCreateCmd = "useradd -m -s /bin/bash ${username} && echo '${username}:${plainPassword}' | chpasswd && usermod -aG sudo ${username}"
                Write-Log "Running user creation command" "INFO"
                $userResult = wsl -d $instanceName -u root -- bash -c $userCreateCmd 2>&1
                Write-Host "User created successfully." -ForegroundColor Green
                Write-Log "User created successfully" "INFO"
            } catch {
                Write-Host "Error creating user: $_" -ForegroundColor Red
                Write-Log "Error creating user: $_" "ERROR"
                Write-Host "You may need to create a user manually using: wsl -d $instanceName -u root" -ForegroundColor Yellow
                return
            }
            
            # Update wsl.conf to set the default user
            Write-Host "Setting $username as the default user..." -ForegroundColor Cyan
            Write-Log "Setting $username as the default user..." "INFO"
            try {
                $wslConfCmd = "echo -e '[user]\ndefault=${username}' > /etc/wsl.conf"
                Write-Log "Updating wsl.conf" "INFO"
                $wslConfResult = wsl -d $instanceName -u root -- bash -c $wslConfCmd 2>&1
                Write-Host "Default user set successfully." -ForegroundColor Green
                Write-Log "Default user set successfully" "INFO"
            } catch {
                Write-Host "Error setting default user: $_" -ForegroundColor Red
                Write-Log "Error setting default user: $_" "ERROR"
                Write-Host "You may need to update /etc/wsl.conf manually." -ForegroundColor Yellow
                return
            }
            
            # Restart the WSL instance to apply the user change
            Write-Host "Restarting WSL instance to apply user changes..." -ForegroundColor Cyan
            Write-Log "Restarting WSL instance to apply user changes..." "INFO"
            try {
                wsl --terminate $instanceName
                Write-Log "WSL instance terminated" "INFO"
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "Warning: Could not restart WSL instance: $_" -ForegroundColor Yellow
                Write-Log "Warning: Could not restart WSL instance: $_" "WARNING"
            }
            
            Write-Host "`nUser credentials have been set successfully for instance: $instanceName" -ForegroundColor Green
            Write-Log "User credentials have been set successfully for instance: $instanceName" "INFO"
            Write-Host "You can now use the instance with: wsl -d $instanceName -u $username" -ForegroundColor Cyan
            
            # Launch the WSL instance with the new user
            Write-Host "`nLaunching WSL instance with user: $username..." -ForegroundColor Cyan
            Write-Log "Launching WSL instance with user: $username" "INFO"
            try {
                Start-Process -FilePath "wsl.exe" -ArgumentList "-d $instanceName -u $username"
                Write-Log "WSL process started successfully" "INFO"
            } catch {
                Write-Host "Error launching distribution: $_" -ForegroundColor Red
                Write-Log "Error launching distribution: $_" "ERROR"
                Write-Host "Try launching manually with: wsl -d $instanceName -u $username" -ForegroundColor Yellow
            }
            
            Write-Host "`nPress Enter to return to the main menu..."
            Read-Host
        } catch {
            Write-Host "Error setting user credentials: $_" -ForegroundColor Red
            Write-Log "Error setting user credentials: $_" "ERROR"
            Write-Host "`nPress Enter to return to the main menu..."
            Read-Host
        }
    }

    # Check for admin rights at the beginning of the script
    if (-not (Test-AdminPrivileges)) {
        # Don't require admin for simple listing operations
        if (-not ($ListInstalled -or $ListOnline -or $Help)) {
            Request-AdminPrivileges
        }
    }

    # If no parameters provided, show interactive menu
    function Show-Menu {
        param (
            [switch]$ClearScreen,
            [bool]$DebugEnabled = $true,
            [bool]$Quiet = $false,
            [bool]$InfoEnabled = $false
        )
        
        if (-not $DebugEnabled) {
            $script:DebugPreference = "SilentlyContinue"
        }
        
        $script:QuietMode = $Quiet
        $script:NoInfo = -not $InfoEnabled
        
        Write-Log "Showing menu" "DEBUG"
        
        if ($ClearScreen) {
            Clear-Host
        }
        
        $options = @(
            "List installed WSL distributions",
            "List available online WSL distributions",
            "Create a new WSL instance",
            "Install browsers on existing instance",
            "Set user credentials for existing instance",
            "Open terminal for selected instance",
            "Toggle debug output (currently: $($script:DebugPreference -eq 'Continue'))",
            "Toggle quiet mode (currently: $($script:QuietMode))",
            "Toggle info messages (currently: $(-not $script:NoInfo))",
            "Exit"
        )

        Write-Host ""  # Blank line
        Write-Host "====================" -ForegroundColor DarkCyan
        Write-Host " WSL Instance Manager" -ForegroundColor Cyan -BackgroundColor Black
        Write-Host "====================" -ForegroundColor DarkCyan
        Write-Host ""  # Blank line

        for ($i = 0; $i -lt $options.Count; $i++) {
            Write-Host -NoNewline "[" -ForegroundColor DarkGray
            Write-Host -NoNewline "$($i+1)" -ForegroundColor Yellow
            Write-Host -NoNewline "] " -ForegroundColor DarkGray
            Write-Host $options[$i] -ForegroundColor White
        }

        Write-Host ""  # Blank line
        Write-Host "Enter your choice" -ForegroundColor Cyan
        $choice = Read-Host
        return $choice
    }

    # Main script execution
    Write-Log "Starting main execution" "DEBUG"
    if ($Help) {
        Show-Help
        exit 0
    }

    # Check if WSL is installed
    if (-not (Test-WSLInstalled)) {
        # Commented out to bypass this check as requested
        #Write-Host "WSL does not appear to be installed on this system." -ForegroundColor Red
        #Write-Host "Please install WSL first using: wsl --install" -ForegroundColor Yellow
        #exit 1
        
        # Instead, just show a warning but continue
        Write-Host "Warning: WSL may not be properly installed, but proceeding anyway." -ForegroundColor Yellow
    }

    # Handle parameters
    if ($ListInstalled) {
        Write-Log "Listing installed distributions" "DEBUG"
        Write-Host "Installed WSL Distributions:"
        Write-Host "============================"
        Get-InstalledDistributions
        exit 0
    }

    if ($ListOnline) {
        Write-Log "Listing online distributions" "DEBUG"
        Write-Host "Available Online WSL Distributions:"
        Write-Host "=================================="
        $distros = Get-OnlineDistributions
        
        # Display the distributions
        foreach ($distro in $distros) {
            Write-Host $distro
        }
        
        exit 0
    }

    if ($CreateInstance) {
        Write-Log "Creating new WSL instance" "DEBUG"
        New-WSLInstance -PreSelectedDistro $SelectedDistro -PreCustomName $CustomName -PreUsername $Username -PrePassword $Password
        exit 0
    }

    # Main menu loop
    $exitRequested = $false
    $menuDebugEnabled = (-not $NoDebug)
    $menuQuietMode = $QuietMode
    $menuInfoEnabled = (-not $NoInfo)
    while (-not $exitRequested) {
        try {
            $choice = Show-Menu -ClearScreen:($exitRequested -eq $false) -DebugEnabled $menuDebugEnabled -Quiet $menuQuietMode -InfoEnabled $menuInfoEnabled
            
            Write-Log "User selected menu option: $choice" "DEBUG"
            
            switch ($choice) {
                "1" {
                    # List installed WSL distributions with a clean, numbered list
                    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
                    $distros = @(& $scriptPath -installed)
                    $distros = $distros | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    if ($distros.Count -gt 0) {
                        Write-Host "`nInstalled WSL Distributions:" -ForegroundColor Green
                        Write-Host "============================" -ForegroundColor DarkCyan
                        for ($i = 0; $i -lt $distros.Count; $i++) {
                            Write-Host ("[{0}] {1}" -f ($i+1), $distros[$i]) -ForegroundColor White
                        }
                    } else {
                        Write-Host "No distributions found." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress Enter to return to the main menu..."
                    Read-Host
                    Show-Menu
                }
                "2" {
                    # List available online WSL distributions with a clean, numbered list
                    $scriptPath = Join-Path $PSScriptRoot "Get-WSLNames.ps1"
                    $distros = @(& $scriptPath -online)
                    $distros = $distros | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    if ($distros.Count -gt 0) {
                        Write-Host "`nAvailable Online WSL Distributions:" -ForegroundColor Green
                        Write-Host "==================================" -ForegroundColor DarkCyan
                        for ($i = 0; $i -lt $distros.Count; $i++) {
                            Write-Host ("[{0}] {1}" -f ($i+1), $distros[$i]) -ForegroundColor White
                        }
                    } else {
                        Write-Host "No online distributions found." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress Enter to return to the main menu..."
                    Read-Host
                    Show-Menu
                }
                "3" {
                    New-WSLInstance
                    Write-Host "`nPress Enter to return to the main menu..."
                    Read-Host
                    Show-Menu
                }
                "4" {
                    Install-BrowsersOnExistingInstance
                    Write-Host "`nPress Enter to return to the main menu..."
                    Read-Host
                    Show-Menu
                }
                "5" {
                    Set-WSLUserCredentials
                    Write-Host "`nPress Enter to return to the main menu..."
                    Read-Host
                    Show-Menu
                }
                "6" {
                    # Open terminal for selected instance
                    $instanceName = Select-WSLInstance -Purpose "open a terminal for"
                    if (-not $instanceName) {
                        Write-Host "Returning to main menu..." -ForegroundColor Yellow
                        Show-Menu
                        return
                    }
                    $username = ""
                    do {
                        Write-Host "Enter the username to use for the instance (default: root, or 'q' to return):" -ForegroundColor Cyan
                        $username = Read-Host
                        if ($username -eq 'q' -or $username -eq 'exit') {
                            Write-Host "Returning to main menu..." -ForegroundColor Yellow
                            Show-Menu
                            return
                        }
                        if ([string]::IsNullOrWhiteSpace($username)) {
                            $username = "root"
                        }
                        # Verify username exists in the instance
                        try {
                            $userCheck = wsl -d $instanceName -u root -- bash -c "id -u $username 2>/dev/null"
                            if ($LASTEXITCODE -ne 0) {
                                Write-Host "Error: Username '$username' does not exist in the instance. Please try again." -ForegroundColor Red
                                $username = ""
                            }
                        } catch {
                            Write-Host "Error checking username: $_" -ForegroundColor Red
                            $username = ""
                        }
                    } while ([string]::IsNullOrWhiteSpace($username))
                    Write-Host "Opening terminal for instance: $instanceName with user: $username" -ForegroundColor Cyan
                    try {
                        Start-Process -FilePath "wsl.exe" -ArgumentList "-d $instanceName -u $username"
                        Write-Host "Terminal launched successfully." -ForegroundColor Green
                    } catch {
                        Write-Host "Error launching terminal: $_" -ForegroundColor Red
                    }
                    Write-Host "`nPress Enter to return to the main menu..."
                    Read-Host
                    Show-Menu
                }
                "7" {
                    $script:DebugPreference = if ($script:DebugPreference -eq "Continue") { "SilentlyContinue" } else { "Continue" }
                    Write-Host "Debug output is now $(if ($script:DebugPreference -eq "Continue") { "enabled" } else { "disabled" })" -ForegroundColor Cyan
                    Show-Menu
                }
                "8" {
                    $script:QuietMode = -not $script:QuietMode
                    Write-Host "Quiet mode is now $(if ($script:QuietMode) { "enabled" } else { "disabled" })" -ForegroundColor Cyan
                    Show-Menu
                }
                "9" {
                    $script:NoInfo = -not $script:NoInfo
                    Write-Host "Info messages are now $(if (-not $script:NoInfo) { "enabled" } else { "disabled" })" -ForegroundColor Cyan
                    Show-Menu
                }
                "10" {
                    Write-Host "Exiting..." -ForegroundColor Cyan
                    exit 0
                }
                default {
                    Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                    Show-Menu
                }
            }
        }
        catch {
            Write-Log "Error in menu loop: $_" "ERROR"
            Write-Host "An error occurred: $_" -ForegroundColor Red
            Write-Host "Press Enter to continue..."
            Read-Host
        }
    }

    # Final goodbye message
    Write-Host "`nThank you for using WSL Instance Manager." -ForegroundColor Cyan
    Write-Host "Script execution completed." -ForegroundColor Cyan
    Write-Host "Press Enter to exit..."
    Read-Host
}
catch {
    Write-Log "Unhandled exception in script: $_" "ERROR"
    Write-Host "A critical error occurred:" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "`nPress Enter to exit..."
    Read-Host
} 