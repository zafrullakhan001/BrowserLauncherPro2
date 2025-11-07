# Direct test of WSL connectivity with debug info
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  DIRECT WSL CONNECTIVITY TEST" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

$distro = "ubuntu-7"
Write-Host "`nDirect command:" -ForegroundColor Yellow
$command = "wsl -d $distro -e ping -c 2 8.8.8.8"
Write-Host $command -ForegroundColor Cyan
Invoke-Expression $command

Write-Host "`nCaptured in script variable:" -ForegroundColor Yellow
$pingResult = wsl -d $distro -e ping -c 2 8.8.8.8
Write-Host "Result:" -ForegroundColor Cyan
Write-Host $pingResult -ForegroundColor Gray

Write-Host "`nChecking patterns:" -ForegroundColor Yellow
Write-Host "Contains 'bytes from'? $($pingResult -match 'bytes from')" -ForegroundColor Cyan
Write-Host "Contains '64 bytes from'? $($pingResult -match '64 bytes from')" -ForegroundColor Cyan
Write-Host "Contains '2 received'? $($pingResult -match '2 received')" -ForegroundColor Cyan

# Print in the format we'd see in the script
Write-Host "`nSimple Test Output:" -ForegroundColor Yellow
if ($pingResult -match "bytes from") {
    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
} else {
    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
}

Write-Host "`nFIX:" -ForegroundColor Yellow
Write-Host "In your main script (wsl-info-and-tools.ps1), find the Test-WSLConnectivity function:" -ForegroundColor Cyan
Write-Host "  - Change line checking for '2 received' to check for 'bytes from'" -ForegroundColor Cyan
Write-Host "  - Replace nslookup with ping -c 1 google.com and check for 'bytes from'" -ForegroundColor Cyan

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 