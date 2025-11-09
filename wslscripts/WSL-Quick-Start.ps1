# WSL-Quick-Start.ps1
# Ultra-simple WSL launcher without complex elevation logic

Write-Host ""
Write-Host "="*50 -ForegroundColor Cyan
Write-Host " WSL Instance Manager - Quick Start" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

# Check if we're admin
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ""
if ($isAdmin) {
    Write-Host "✓ Running as Administrator - Good!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Starting WSL Instance Creation..." -ForegroundColor Cyan
    
    # Run the main script
    $mainScript = Join-Path $PSScriptRoot "Manage-WSLInstance-Fixed.ps1"
    if (Test-Path $mainScript) {
        & $mainScript -CreateInstance
    } else {
        Write-Host "Error: Main script not found at $mainScript" -ForegroundColor Red
    }
} else {
    Write-Host "✗ NOT running as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "To create WSL instances, you need to run as Administrator:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Close this window" -ForegroundColor White
    Write-Host "2. Right-click on PowerShell" -ForegroundColor White  
    Write-Host "3. Select 'Run as Administrator'" -ForegroundColor White
    Write-Host "4. Navigate to: $PSScriptRoot" -ForegroundColor White
    Write-Host "5. Run: .\WSL-Quick-Start.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "OR try automatic elevation (may not work on all systems):" -ForegroundColor Yellow
    $elevate = Read-Host "Try automatic elevation? [Y/N]"
    
    if ($elevate.ToLower() -eq 'y') {
        try {
            $scriptPath = Join-Path $PSScriptRoot "Manage-WSLInstance-Fixed.ps1"
            Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath, "-CreateInstance" -Verb RunAs
            Write-Host "Elevation requested. Check for UAC prompt." -ForegroundColor Green
        } catch {
            Write-Host "Elevation failed: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Read-Host "Press Enter to exit"