# Elevate to admin privileges if not already running as admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrative privileges. Attempting to elevate..." -ForegroundColor Yellow
    try {
        $arguments = "& '" + $myinvocation.mycommand.definition + "'"
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command", $arguments
        exit
    }
    catch {
        Write-Host "Failed to elevate privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please run this script as Administrator manually." -ForegroundColor Yellow
        exit
    }
}

Write-Host "=== Native Messaging Host Registration Repair Tool ===" -ForegroundColor Cyan
Write-Host "This script will fix the native messaging host registration for browser launcher." -ForegroundColor White

# Get the current directory of the script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

# Get the extension ID
$extensionId = "com.example.browserlauncher"

# Path to the manifest file
$manifestPath = Join-Path -Path $rootDir -ChildPath "$extensionId.json"

# Check if manifest exists
if (-not (Test-Path $manifestPath)) {
    Write-Host "Error: Native messaging host manifest not found at: $manifestPath" -ForegroundColor Red
    Write-Host "Checking in root directory instead..." -ForegroundColor Yellow
    
    $manifestPath = Join-Path -Path $rootDir -ChildPath "$extensionId.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Host "Error: Native messaging host manifest not found in any expected location." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Found manifest at: $manifestPath" -ForegroundColor Green

# Create or update registry entries for Chrome and Edge
$browsers = @(
    @{
        Name = "Chrome"
        RegistryPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$extensionId"
    },
    @{
        Name = "Edge"
        RegistryPath = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$extensionId"
    }
)

foreach ($browser in $browsers) {
    Write-Host "Registering for $($browser.Name)..." -ForegroundColor Yellow
    
    # Check if registry path exists
    if (-not (Test-Path $browser.RegistryPath)) {
        # Create the registry key
        try {
            New-Item -Path $browser.RegistryPath -Force | Out-Null
            Write-Host "✓ Created registry key: $($browser.RegistryPath)" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to create registry key: $($browser.RegistryPath)" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }
    
    # Set the manifest path
    try {
        Set-ItemProperty -Path $browser.RegistryPath -Name "(Default)" -Value $manifestPath
        Write-Host "✓ Updated registry value for $($browser.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to set registry value for $($browser.Name)" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Fix permissions on Python script
$pythonScript = Join-Path -Path $rootDir -ChildPath "native_messaging.py"

if (Test-Path $pythonScript) {
    try {
        # Ensure the script is executable
        $acl = Get-Acl $pythonScript
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl $pythonScript $acl
        
        Write-Host "✓ Permissions set correctly for: $pythonScript" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to set permissions on Python script" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "✗ Python script not found at: $pythonScript" -ForegroundColor Red
}

# Check Python installation
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python is installed: $pythonVersion" -ForegroundColor Green
    
    # Try to install required modules
    Write-Host "Installing required Python modules..." -ForegroundColor Yellow
    python -m pip install --upgrade pip
    python -m pip install ujson psutil configparser
    
    Write-Host "✓ Python modules installed/updated" -ForegroundColor Green
}
catch {
    Write-Host "✗ Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.6 or higher and make sure it's in your PATH" -ForegroundColor Yellow
}

Write-Host "`n=== Registration Repairs Completed ===" -ForegroundColor Cyan
Write-Host "Please restart your browser and try the extension again." -ForegroundColor Yellow

# Wait for user input before closing
Write-Host "`nPress any key to exit..." -ForegroundColor White
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 