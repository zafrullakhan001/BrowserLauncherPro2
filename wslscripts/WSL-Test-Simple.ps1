# WSL-Test-Simple.ps1
# Simple test script to validate WSL functionality

param(
    [switch]$TestInstall,
    [switch]$TestList,
    [switch]$Help
)

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Test-WSLAvailability {
    Write-TestLog "Testing WSL availability..." "INFO"
    
    try {
        $wslVersion = wsl --version 2>&1
        if ($wslVersion -match "WSL version" -or $wslVersion -match "Windows Subsystem for Linux") {
            Write-TestLog "WSL is available" "SUCCESS"
            Write-Host $wslVersion
            return $true
        }
        else {
            Write-TestLog "WSL version check returned unexpected output" "WARNING"
            Write-Host $wslVersion
            return $false
        }
    }
    catch {
        Write-TestLog "WSL not available: $_" "ERROR"
        return $false
    }
}

function Test-WSLList {
    Write-TestLog "Testing WSL list functionality..." "INFO"
    
    try {
        Write-TestLog "Installed distributions:" "INFO"
        $installed = wsl --list --verbose 2>&1
        Write-Host $installed
        
        Write-TestLog "Available online distributions:" "INFO" 
        $online = wsl --list --online 2>&1
        Write-Host $online
        
        return $true
    }
    catch {
        Write-TestLog "Error listing WSL distributions: $_" "ERROR"
        return $false
    }
}

function Test-AdminRights {
    Write-TestLog "Testing administrative privileges..." "INFO"
    
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            Write-TestLog "Running with administrative privileges" "SUCCESS"
        }
        else {
            Write-TestLog "NOT running with administrative privileges" "WARNING"
            Write-TestLog "Some WSL operations may require elevation" "WARNING"
        }
        
        return $isAdmin
    }
    catch {
        Write-TestLog "Error checking admin rights: $_" "ERROR"
        return $false
    }
}

function Test-WSLInstallation {
    Write-TestLog "Testing WSL installation process..." "INFO"
    
    # Check if Ubuntu is already installed
    $existingDistros = wsl --list --quiet 2>$null
    if ($existingDistros -match "Ubuntu") {
        Write-TestLog "Ubuntu is already installed, skipping installation test" "WARNING"
        return $true
    }
    
    Write-TestLog "This would normally install Ubuntu, but skipping for safety" "INFO"
    Write-TestLog "To test installation, run: wsl --install -d Ubuntu" "INFO"
    
    return $true
}

# Main execution
Write-Host ""
Write-Host "="*50 -ForegroundColor Cyan
Write-Host "WSL Testing Script" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan
Write-Host ""

if ($Help) {
    Write-Host "WSL Test Script Usage:" -ForegroundColor Yellow
    Write-Host "  -TestList     Test WSL listing functionality"
    Write-Host "  -TestInstall  Test WSL installation process (safe)"
    Write-Host "  -Help         Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\WSL-Test-Simple.ps1 -TestList"
    Write-Host "  .\WSL-Test-Simple.ps1 -TestInstall"
    exit 0
}

# Run basic tests
$wslAvailable = Test-WSLAvailability
$adminRights = Test-AdminRights

if (-not $wslAvailable) {
    Write-TestLog "WSL is not available. Please install WSL first." "ERROR"
    Write-TestLog "Run: wsl --install" "INFO"
    exit 1
}

if ($TestList) {
    Test-WSLList
}

if ($TestInstall) {
    if (-not $adminRights) {
        Write-TestLog "Administrative privileges recommended for installation testing" "WARNING"
    }
    Test-WSLInstallation
}

if (-not $TestList -and -not $TestInstall) {
    Write-TestLog "Running basic tests only. Use -TestList or -TestInstall for more tests." "INFO"
    Test-WSLList
}

Write-Host ""
Write-TestLog "Testing completed" "SUCCESS"