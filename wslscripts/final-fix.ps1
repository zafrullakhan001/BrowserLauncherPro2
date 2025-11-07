# Final WSL Connectivity Test Fix
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  WSL CONNECTIVITY TEST" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

# Directly test specific distributions
$distributions = @("ubuntu-7", "Ubuntu-24.04", "ubuntu-8")

foreach ($distro in $distributions) {
    Write-Host ("`nTesting connectivity for " + $distro) -ForegroundColor Green
    
    # Check internet connectivity
    Write-Host "Running: wsl -d `"$distro`" -e ping -c 2 8.8.8.8" -ForegroundColor Gray
    $pingResult = wsl -d $distro -e ping -c 2 8.8.8.8
    
    if ($pingResult -match "bytes from") {
        Write-Host "- Internet connectivity: OK" -ForegroundColor Green
    } else {
        Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
    }
    
    # Check DNS resolution
    Write-Host "Running: wsl -d `"$distro`" -e ping -c 1 google.com" -ForegroundColor Gray
    $dnsResult = wsl -d $distro -e ping -c 1 google.com
    
    if ($dnsResult -match "bytes from") {
        Write-Host "- DNS resolution: OK" -ForegroundColor Green
    } else {
        Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
    }
}

# Create fixed function code for the main script
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  FINAL FIX FOR MAIN SCRIPT" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

Write-Host "To fix the connectivity test in the main script, replace the Test-WSLConnectivity function with this code:" -ForegroundColor Yellow

$fixedFunction = @'
function Test-WSLConnectivity {
    Show-Header "WSL CONNECTIVITY TEST"
    
    # Hard-code the distribution names to avoid parsing issues
    $distributions = @("ubuntu-7", "Ubuntu-24.04", "ubuntu-8")
    
    foreach ($distro in $distributions) {
        Write-Host ("`nTesting connectivity for " + $distro) -ForegroundColor Green
        
        try {
            # Check internet connectivity
            $pingResult = wsl -d $distro -e ping -c 2 8.8.8.8 2>$null
            
            if ($pingResult -match "bytes from") {
                Write-Host "- Internet connectivity: OK" -ForegroundColor Green
            } else {
                Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
            }
            
            # Check DNS resolution
            $dnsResult = wsl -d $distro -e ping -c 1 google.com 2>$null
            
            if ($dnsResult -match "bytes from") {
                Write-Host "- DNS resolution: OK" -ForegroundColor Green
            } else {
                Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
            }
        } catch {
            Write-Host "- Could not test connectivity (distribution may not be running)" -ForegroundColor Yellow
        }
    }
}
'@

Write-Host $fixedFunction -ForegroundColor White

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 