# Manage-WSLInstance-Fixed.ps1
# Enhanced WSL Instance Management Script with Better Progress and User Interaction

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

# Enhanced logging and progress tracking
if ([string]::IsNullOrEmpty($LogFile)) {
    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "wsl-manager-debug.log"
} else {
    $logFile = $LogFile
}

$ErrorActionPreference = "Continue"

# Progress tracking function
function Show-Progress {
    param (
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = -1
    )
    
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Activity - $Status" -ForegroundColor Cyan
    Write-Log "$Activity - $Status" "PROGRESS"
    
    if ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    }
}

# Enhanced logging function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "PROGRESS" { Write-Host $logMessage -ForegroundColor Cyan }
        "INFO" { if (-not $QuietMode) { Write-Host $logMessage -ForegroundColor White } }
        "DEBUG" { if ($DebugPreference -eq "Continue") { Write-Host $logMessage -ForegroundColor Gray } }
    }
    
    # Always log to file
    try {
        Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {
        # Silently continue if can't write to log file
    }
}

# Check admin privileges
function Test-AdminPrivileges {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Get secure password input with confirmation
function Get-SecurePassword {
    param (
        [string]$Username
    )
    
    $attempts = 0
    $maxAttempts = 3
    
    while ($attempts -lt $maxAttempts) {
        Write-Host "`nPassword Setup for User: $Username" -ForegroundColor Green
        Write-Host "=====================================" -ForegroundColor DarkCyan
        
        try {
            $password1 = Read-Host "Enter password" -AsSecureString
            $password2 = Read-Host "Confirm password" -AsSecureString
            
            # Convert to plain text for comparison
            $bstr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
            $pwd1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
            
            $bstr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
            $pwd2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
            
            if ($pwd1 -eq $pwd2) {
                if ([string]::IsNullOrEmpty($pwd1)) {
                    Write-Host "Password cannot be empty. Please try again." -ForegroundColor Red
                    $attempts++
                    continue
                }
                Write-Host "Password confirmed successfully!" -ForegroundColor Green
                return $pwd1
            }
            else {
                Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
                $attempts++
            }
        }
        catch {
            Write-Host "Error reading password: $_" -ForegroundColor Red
            $attempts++
        }
    }
    
    Write-Host "Too many failed attempts. Using default password 'ubuntu123'" -ForegroundColor Yellow
    Write-Log "Using default password due to failed attempts" "WARNING"
    return "ubuntu123"
}

# Enhanced WSL installation with better progress tracking
function Install-WSLDistribution {
    param (
        [string]$DistroName,
        [string]$CustomName
    )
    
    Show-Progress "WSL Installation" "Starting installation of $DistroName" 10
    
    try {
        # Check if already installed
        $existingDistros = wsl --list --quiet 2>$null
        if ($existingDistros -contains $DistroName) {
            Write-Host "Distribution $DistroName is already installed." -ForegroundColor Yellow
            
            $action = ""
            while ($action -notin @('R', 'U', 'S')) {
                $action = (Read-Host "Choose action: (R)einstall, (U)se existing, (S)kip [R/U/S]").ToUpper()
            }
            
            switch ($action) {
                'R' {
                    Show-Progress "WSL Installation" "Unregistering existing distribution" 15
                    wsl --unregister $DistroName
                    Start-Sleep -Seconds 3
                }
                'U' {
                    Show-Progress "WSL Installation" "Using existing distribution" 100
                    return $true
                }
                'S' {
                    return $false
                }
            }
        }
        
        # Install the distribution using Microsoft Store method for better user interaction
        Show-Progress "WSL Installation" "Installing $DistroName via Windows Store method" 20
        Write-Host "`n" + "="*60 -ForegroundColor DarkCyan
        Write-Host "  WSL DISTRIBUTION INSTALLATION" -ForegroundColor Cyan -BackgroundColor Black
        Write-Host "="*60 -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "The system will now install $DistroName." -ForegroundColor White
        Write-Host "This process involves:" -ForegroundColor Yellow
        Write-Host "  1. Downloading the distribution" -ForegroundColor Yellow
        Write-Host "  2. Installing and configuring" -ForegroundColor Yellow
        Write-Host "  3. Initial setup (you'll be prompted for username/password)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please be patient as this can take several minutes." -ForegroundColor Cyan
        Write-Host ""
        
        # Try the direct installation method
        Show-Progress "WSL Installation" "Running: wsl --install -d $DistroName" 25
        
        $installJob = Start-Job -ScriptBlock {
            param($distro)
            $process = Start-Process -FilePath "wsl" -ArgumentList "--install", "-d", $distro -PassThru -Wait -NoNewWindow
            return $process.ExitCode
        } -ArgumentList $DistroName
        
        # Monitor installation progress
        $progressCounter = 30
        while ($installJob.State -eq "Running") {
            Show-Progress "WSL Installation" "Installing $DistroName (this may take 5-15 minutes)" $progressCounter
            Start-Sleep -Seconds 30
            $progressCounter = [Math]::Min(90, $progressCounter + 5)
        }
        
        $exitCode = Receive-Job $installJob
        Remove-Job $installJob
        
        if ($exitCode -eq 0) {
            Show-Progress "WSL Installation" "Installation completed successfully" 95
            
            # Verify installation
            Start-Sleep -Seconds 5
            $verifyDistros = wsl --list --quiet 2>$null
            if ($verifyDistros -contains $DistroName) {
                Show-Progress "WSL Installation" "Verification successful" 100
                Write-Host "`nDistribution $DistroName has been installed successfully!" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "Installation appeared to succeed but distribution not found in list." -ForegroundColor Yellow
                return $false
            }
        }
        else {
            throw "Installation failed with exit code: $exitCode"
        }
    }
    catch {
        Write-Log "Installation error: $_" "ERROR"
        
        # Fallback: Try launching the distribution directly which triggers first-time setup
        Write-Host "`nTrying alternative installation method..." -ForegroundColor Yellow
        Show-Progress "WSL Installation" "Attempting alternative installation" 50
        
        try {
            # This launches the distribution and triggers the Microsoft Store download if needed
            Write-Host "Launching $DistroName for first-time setup..." -ForegroundColor Cyan
            Write-Host "A new window will open for initial configuration." -ForegroundColor Yellow
            Write-Host "Please complete the setup in that window." -ForegroundColor Yellow
            
            $process = Start-Process -FilePath "wsl" -ArgumentList "-d", $DistroName -PassThru
            
            # Wait for process to start properly
            Start-Sleep -Seconds 5
            
            # Monitor for completion
            $timeout = 600 # 10 minutes
            $elapsed = 0
            
            while (!$process.HasExited -and $elapsed -lt $timeout) {
                Show-Progress "WSL Installation" "Waiting for initial setup to complete ($elapsed seconds)" (50 + ($elapsed * 40 / $timeout))
                Start-Sleep -Seconds 10
                $elapsed += 10
            }
            
            Show-Progress "WSL Installation" "Setup window completed" 100
            return $true
        }
        catch {
            Write-Log "Alternative installation also failed: $_" "ERROR"
            Write-Host "Automatic installation failed. Please install manually:" -ForegroundColor Red
            Write-Host "1. Open Microsoft Store" -ForegroundColor Yellow
            Write-Host "2. Search for '$DistroName'" -ForegroundColor Yellow
            Write-Host "3. Install the distribution" -ForegroundColor Yellow
            Write-Host "4. Run the script again" -ForegroundColor Yellow
            return $false
        }
    }
}

# Enhanced user setup function
function Initialize-WSLUser {
    param (
        [string]$DistroName,
        [string]$Username = "",
        [string]$Password = ""
    )
    
    Show-Progress "User Setup" "Setting up user account for $DistroName" 10
    
    # Get username if not provided
    if ([string]::IsNullOrWhiteSpace($Username)) {
        Write-Host "`n" + "="*50 -ForegroundColor DarkCyan
        Write-Host "  USER ACCOUNT SETUP" -ForegroundColor Cyan -BackgroundColor Black
        Write-Host "="*50 -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "Setting up your user account for WSL distribution: $DistroName" -ForegroundColor White
        Write-Host ""
        
        do {
            $Username = Read-Host "Enter username (no spaces, lowercase recommended)"
            if ([string]::IsNullOrWhiteSpace($Username)) {
                Write-Host "Username cannot be empty. Please try again." -ForegroundColor Red
            }
            elseif ($Username -match '\s') {
                Write-Host "Username cannot contain spaces. Please try again." -ForegroundColor Red
                $Username = ""
            }
        } while ([string]::IsNullOrWhiteSpace($Username))
    }
    
    # Get password if not provided
    if ([string]::IsNullOrWhiteSpace($Password)) {
        $Password = Get-SecurePassword -Username $Username
    }
    
    Show-Progress "User Setup" "Creating user $Username in $DistroName" 30
    
    try {
        # Create user with home directory and bash shell
        $createUserCmd = @"
useradd -m -s /bin/bash $Username
echo '${Username}:${Password}' | chpasswd
usermod -aG sudo $Username
echo 'User $Username created successfully'
"@
        
        Show-Progress "User Setup" "Executing user creation commands" 50
        
        wsl -d $DistroName -u root -e bash -c $createUserCmd | Out-Host
        
        Show-Progress "User Setup" "Setting default user in wsl.conf" 70
        
        # Set as default user
        $wslConfCmd = @"
mkdir -p /etc
echo '[user]' > /etc/wsl.conf
echo 'default=$Username' >> /etc/wsl.conf
echo 'Default user configuration updated'
"@
        
        wsl -d $DistroName -u root -e bash -c $wslConfCmd | Out-Host
        
        Show-Progress "User Setup" "Restarting WSL instance to apply changes" 90
        
        # Restart WSL instance
        wsl --terminate $DistroName
        Start-Sleep -Seconds 3
        
        Show-Progress "User Setup" "User setup completed successfully" 100
        
        Write-Host "`nUser account setup completed!" -ForegroundColor Green
        Write-Host "Username: $Username" -ForegroundColor Cyan
        Write-Host "The user has been added to the sudo group." -ForegroundColor Cyan
        
        return $true
    }
    catch {
        Write-Log "Error setting up user: $_" "ERROR"
        Write-Host "Error setting up user account. You may need to configure this manually." -ForegroundColor Red
        return $false
    }
}

# Enhanced instance creation function
function New-WSLInstance {
    param (
        [string]$PreSelectedDistro = "",
        [string]$PreCustomName = "",
        [string]$PreUsername = "",
        [string]$PrePassword = ""
    )
    
    try {
        Write-Host "`n" + "="*60 -ForegroundColor DarkCyan
        Write-Host "  WSL INSTANCE CREATION WIZARD" -ForegroundColor Cyan -BackgroundColor Black
        Write-Host "="*60 -ForegroundColor DarkCyan
        Write-Host ""
        
        # Step 1: Select Distribution
        $selectedDistro = $PreSelectedDistro
        if ([string]::IsNullOrWhiteSpace($selectedDistro)) {
            Write-Host "Step 1: Select Ubuntu Distribution" -ForegroundColor Yellow
            Write-Host "====================================" -ForegroundColor DarkYellow
            
            $ubuntuDistros = @(
                "Ubuntu",
                "Ubuntu-20.04",
                "Ubuntu-22.04", 
                "Ubuntu-24.04"
            )
            
            for ($i = 0; $i -lt $ubuntuDistros.Count; $i++) {
                Write-Host "[$i] $($ubuntuDistros[$i])" -ForegroundColor White
            }
            
            do {
                $selection = Read-Host "`nSelect distribution number [0-$($ubuntuDistros.Count-1)]"
                if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -lt $ubuntuDistros.Count) {
                    $selectedDistro = $ubuntuDistros[[int]$selection]
                    break
                }
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            } while ($true)
        }
        
        Write-Host "`nSelected Distribution: $selectedDistro" -ForegroundColor Green
        
        # Step 2: Get Custom Name
        $customName = $PreCustomName
        if ([string]::IsNullOrWhiteSpace($customName)) {
            Write-Host "`nStep 2: Instance Name" -ForegroundColor Yellow
            Write-Host "======================" -ForegroundColor DarkYellow
            $customName = Read-Host "Enter custom name for instance (or press Enter for default: $selectedDistro)"
        }
        
        if ([string]::IsNullOrWhiteSpace($customName)) {
            $customName = $selectedDistro
        }
        
        Write-Host "Instance Name: $customName" -ForegroundColor Green
        
        # Step 3: Install Distribution
        Write-Host "`nStep 3: Installing Distribution" -ForegroundColor Yellow
        Write-Host "===============================" -ForegroundColor DarkYellow
        
        $installSuccess = Install-WSLDistribution -DistroName $selectedDistro -CustomName $customName
        
        if (-not $installSuccess) {
            Write-Host "Installation failed or was cancelled." -ForegroundColor Red
            return
        }
        
        # Step 4: Handle Custom Naming (if needed)
        if ($customName -ne $selectedDistro) {
            Write-Host "`nStep 4: Creating Custom Named Instance" -ForegroundColor Yellow
            Write-Host "======================================" -ForegroundColor DarkYellow
            
            Show-Progress "Instance Creation" "Exporting $selectedDistro" 10
            
            # Create export directory
            $exportDir = Join-Path $env:TEMP "WSLExport"
            if (!(Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            $tarFile = Join-Path $exportDir "$selectedDistro.tar"
            
            # Export
            Show-Progress "Instance Creation" "Exporting distribution to $tarFile" 25
            wsl --export $selectedDistro $tarFile
            
            # Create import directory
            $wslDir = Join-Path $env:USERPROFILE "WSL"
            $customDir = Join-Path $wslDir $customName
            if (!(Test-Path $customDir)) {
                New-Item -ItemType Directory -Path $customDir -Force | Out-Null
            }
            
            # Import with custom name
            Show-Progress "Instance Creation" "Importing as $customName" 50
            wsl --import $customName $customDir $tarFile --version 2
            
            # Clean up
            Show-Progress "Instance Creation" "Cleaning up temporary files" 75
            Remove-Item $tarFile -Force -ErrorAction SilentlyContinue
            
            # Unregister original
            Show-Progress "Instance Creation" "Removing original distribution" 90
            wsl --unregister $selectedDistro
            
            Show-Progress "Instance Creation" "Custom instance created successfully" 100
            $finalDistroName = $customName
        }
        else {
            $finalDistroName = $selectedDistro
        }
        
        # Step 5: User Account Setup
        Write-Host "`nStep 5: User Account Setup" -ForegroundColor Yellow
        Write-Host "==========================" -ForegroundColor DarkYellow
        
        Initialize-WSLUser -DistroName $finalDistroName -Username $PreUsername -Password $PrePassword | Out-Null
        
        # Step 6: Final Setup
        Write-Host "`nStep 6: Final Configuration" -ForegroundColor Yellow
        Write-Host "===========================" -ForegroundColor DarkYellow
        
        # Offer browser installation
        $installBrowsers = Read-Host "Would you like to install browsers? [Y/N]"
        if ($installBrowsers.ToLower() -eq 'y') {
            Install-Browsers -DistroName $finalDistroName
        }
        
        # Success message
        Write-Host "`n" + "="*60 -ForegroundColor Green
        Write-Host "  WSL INSTANCE CREATION COMPLETED!" -ForegroundColor Green -BackgroundColor Black
        Write-Host "="*60 -ForegroundColor Green
        Write-Host ""
        Write-Host "Instance Name: $finalDistroName" -ForegroundColor Cyan
        Write-Host "Status: Ready to use" -ForegroundColor Green
        Write-Host ""
        Write-Host "To start your instance:" -ForegroundColor Yellow
        Write-Host "  wsl -d $finalDistroName" -ForegroundColor White
        Write-Host ""
        
        $launch = Read-Host "Launch instance now? [Y/N]"
        if ($launch.ToLower() -eq 'y') {
            Write-Host "Launching $finalDistroName..." -ForegroundColor Cyan
            Start-Process -FilePath "wsl" -ArgumentList "-d", $finalDistroName
        }
    }
    catch {
        Write-Log "Error in New-WSLInstance: $_" "ERROR"
        Write-Host "An error occurred during instance creation: $_" -ForegroundColor Red
    }
}

# Browser installation function
function Install-Browsers {
    param (
        [string]$DistroName
    )
    
    Write-Host "Installing browsers in $DistroName..." -ForegroundColor Cyan
    
    # Check if the browser installation script exists
    $browserScript = Join-Path $PSScriptRoot "wsl-install-browsers.sh"
    
    if (Test-Path $browserScript) {
        try {
            # Copy and execute the browser installation script
            $wslPath = "/tmp/wsl-install-browsers.sh"
            wsl -d $DistroName -- cp $(($browserScript -replace '\\', '/').Replace('C:', '/mnt/c')) $wslPath
            wsl -d $DistroName -- chmod +x $wslPath
            wsl -d $DistroName -- $wslPath
            
            Write-Host "Browser installation completed!" -ForegroundColor Green
        }
        catch {
            Write-Host "Error installing browsers: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Browser installation script not found at: $browserScript" -ForegroundColor Yellow
    }
}

# Main execution
Write-Log "WSL Instance Manager started" "INFO"

# Check admin privileges for installation operations
if ($CreateInstance) {
    $isAdmin = Test-AdminPrivileges
    
    Write-Host "`n" + "="*60 -ForegroundColor DarkCyan
    Write-Host "  ADMINISTRATIVE PRIVILEGES CHECK" -ForegroundColor Cyan -BackgroundColor Black  
    Write-Host "="*60 -ForegroundColor DarkCyan
    
    if ($isAdmin) {
        Write-Host "✓ Running with administrative privileges" -ForegroundColor Green
        Write-Host "WSL installation can proceed normally." -ForegroundColor Green
    } else {
        Write-Host "✗ NOT running with administrative privileges" -ForegroundColor Red
        Write-Host "WSL installation requires administrator rights." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "1. Close this window and restart as administrator" -ForegroundColor White
        Write-Host "2. Continue anyway (may fail during installation)" -ForegroundColor White
        Write-Host "3. Exit" -ForegroundColor White
        Write-Host ""
        
        $choice = ""
        while ($choice -notin @('1', '2', '3')) {
            $choice = Read-Host "Select option [1-3]"
        }
        
        switch ($choice) {
            '1' {
                Write-Host "Please restart this script as administrator." -ForegroundColor Yellow
                Read-Host "Press Enter to exit"
                exit
            }
            '2' {
                Write-Host "Continuing without admin privileges. Installation may fail." -ForegroundColor Yellow
            }
            '3' {
                Write-Host "Exiting..." -ForegroundColor Cyan
                exit
            }
        }
    }
    Write-Host ""
}

# Handle command line parameters
if ($Help) {
    Write-Host "WSL Instance Manager - Enhanced Edition" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "Usage: .\Manage-WSLInstance-Fixed.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -CreateInstance     Create a new WSL instance with guided setup"
    Write-Host "  -ListInstalled      List all installed WSL distributions" 
    Write-Host "  -ListOnline         List available online distributions"
    Write-Host "  -SelectedDistro     Pre-select distribution (use with -CreateInstance)"
    Write-Host "  -CustomName         Pre-set custom name (use with -CreateInstance)"
    Write-Host "  -Username           Pre-set username (use with -CreateInstance)"
    Write-Host "  -Password           Pre-set password (use with -CreateInstance)"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    exit 0
}

if ($ListInstalled) {
    Write-Host "Installed WSL Distributions:" -ForegroundColor Green
    Write-Host "============================" -ForegroundColor DarkGreen
    wsl --list --verbose
    exit 0
}

if ($ListOnline) {
    Write-Host "Available Online WSL Distributions:" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor DarkGreen
    wsl --list --online
    exit 0
}

if ($CreateInstance) {
    New-WSLInstance -PreSelectedDistro $SelectedDistro -PreCustomName $CustomName -PreUsername $Username -PrePassword $Password
    exit 0
}

# Interactive menu if no parameters
Write-Host "WSL Instance Manager - Enhanced Edition" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "[1] Create new WSL instance (guided setup)" -ForegroundColor White
Write-Host "[2] List installed distributions" -ForegroundColor White
Write-Host "[3] List available online distributions" -ForegroundColor White
Write-Host "[4] Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Select option [1-4]"

switch ($choice) {
    "1" { New-WSLInstance }
    "2" { 
        Write-Host "`nInstalled WSL Distributions:" -ForegroundColor Green
        wsl --list --verbose
        Read-Host "`nPress Enter to exit"
    }
    "3" { 
        Write-Host "`nAvailable Online WSL Distributions:" -ForegroundColor Green
        wsl --list --online
        Read-Host "`nPress Enter to exit"
    }
    "4" { Write-Host "Goodbye!" -ForegroundColor Cyan }
    default { Write-Host "Invalid selection." -ForegroundColor Red }
}

Write-Log "WSL Instance Manager completed" "INFO"