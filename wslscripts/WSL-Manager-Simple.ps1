# WSL-Manager-Simple.ps1
# Simple PowerShell launcher that handles elevation properly

param(
    [switch]$CreateInstance,
    [switch]$Test,
    [switch]$Help
)

function Test-AdminPrivileges {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Elevation {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    
    $scriptPath = $MyInvocation.MyCommand.Definition
    $scriptDir = Split-Path -Parent $scriptPath
    $targetScript = Join-Path $scriptDir "Manage-WSLInstance-Fixed.ps1"
    
    if (Test-Path $targetScript) {
        try {
            Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$targetScript`"", "-CreateInstance" -Verb RunAs
            Write-Host "Elevated PowerShell window should have opened." -ForegroundColor Green
            Write-Host "If no window appeared, check your UAC settings." -ForegroundColor Yellow
        }
        catch {
            Write-Host "Failed to start elevated process: $_" -ForegroundColor Red
            Write-Host "Please try running as administrator manually." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Target script not found: $targetScript" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "  WSL Instance Manager - Simple Launcher" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
Write-Host ""

if ($Help) {
    Write-Host "WSL Manager Simple Launcher" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\WSL-Manager-Simple.ps1 -CreateInstance    # Create new WSL instance"
    Write-Host "  .\WSL-Manager-Simple.ps1 -Test             # Test WSL functionality"
    Write-Host "  .\WSL-Manager-Simple.ps1 -Help             # Show this help"
    Write-Host ""
    Write-Host "Note: WSL installation requires administrator privileges." -ForegroundColor Yellow
    exit 0
}

if ($Test) {
    Write-Host "Running WSL functionality tests..." -ForegroundColor Cyan
    $testScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "WSL-Test-Simple.ps1"
    
    if (Test-Path $testScript) {
        & $testScript -TestList
    }
    else {
        Write-Host "Test script not found: $testScript" -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

if ($CreateInstance -or $args.Count -eq 0) {
    $isAdmin = Test-AdminPrivileges
    
    Write-Host "Administrative Privileges Check:" -ForegroundColor Yellow
    if ($isAdmin) {
        Write-Host "✓ Running as Administrator" -ForegroundColor Green
        Write-Host ""
        Write-Host "Starting WSL Instance Creation..." -ForegroundColor Cyan
        
        # Run the main script directly
        $mainScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "Manage-WSLInstance-Fixed.ps1"
        if (Test-Path $mainScript) {
            & $mainScript -CreateInstance
        }
        else {
            Write-Host "Main script not found: $mainScript" -ForegroundColor Red
        }
    }
    else {
        Write-Host "✗ NOT running as Administrator" -ForegroundColor Red
        Write-Host ""
        Write-Host "WSL installation requires administrator privileges." -ForegroundColor Yellow
        Write-Host ""
        
        $choice = ""
        while ($choice -notin @('Y', 'N')) {
            $choice = (Read-Host "Request elevation to administrator? [Y/N]").ToUpper()
        }
        
        if ($choice -eq 'Y') {
            Request-Elevation
        }
        else {
            Write-Host "Cannot proceed without administrator privileges." -ForegroundColor Red
        }
    }
}

Write-Host ""
Read-Host "Press Enter to exit"