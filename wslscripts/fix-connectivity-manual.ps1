# Manual WSL Connectivity Test
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  WSL CONNECTIVITY TEST" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

# Test ubuntu-7
Write-Host "`nTesting connectivity for ubuntu-7:" -ForegroundColor Green
$pingResult = wsl -d ubuntu-7 -e ping -c 2 8.8.8.8
if ($pingResult -match "bytes from") {
    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
} else {
    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
}

$dnsResult = wsl -d ubuntu-7 -e ping -c 1 google.com
if ($dnsResult -match "bytes from") {
    Write-Host "- DNS resolution: OK" -ForegroundColor Green
} else {
    Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
}

# Test Ubuntu-24.04
Write-Host "`nTesting connectivity for Ubuntu-24.04:" -ForegroundColor Green
$pingResult = wsl -d Ubuntu-24.04 -e ping -c 2 8.8.8.8
if ($pingResult -match "bytes from") {
    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
} else {
    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
}

$dnsResult = wsl -d Ubuntu-24.04 -e ping -c 1 google.com
if ($dnsResult -match "bytes from") {
    Write-Host "- DNS resolution: OK" -ForegroundColor Green
} else {
    Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
}

# Test ubuntu-8
Write-Host "`nTesting connectivity for ubuntu-8:" -ForegroundColor Green
$pingResult = wsl -d ubuntu-8 -e ping -c 2 8.8.8.8
if ($pingResult -match "bytes from") {
    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
} else {
    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
}

$dnsResult = wsl -d ubuntu-8 -e ping -c 1 google.com
if ($dnsResult -match "bytes from") {
    Write-Host "- DNS resolution: OK" -ForegroundColor Green
} else {
    Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
}

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 