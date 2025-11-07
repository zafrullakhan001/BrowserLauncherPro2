# WSL Connectivity Test Fix
# This script provides a more reliable way to test WSL connectivity

function Show-Header {
    param (
        [string]$Title
    )
    
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=============================================`n" -ForegroundColor Cyan
}

function Test-ImprovedWSLConnectivity {
    Show-Header "WSL CONNECTIVITY TEST"
    
    $wslDistros = (wsl --list --quiet) -split "`n" | Where-Object { $_ -and $_ -ne "Windows" }
    
    foreach ($distro in $wslDistros) {
        if ($distro -and $distro.Trim() -ne "") {
            $distro = $distro.Trim()
            Write-Host ("`nTesting connectivity for {0}:" -f $distro) -ForegroundColor Green
            
            try {
                # Check internet connectivity
                $pingResult = wsl -d $distro -e ping -c 2 8.8.8.8 2>$null
                Write-Host "Ping result: $pingResult" -ForegroundColor Yellow
                
                # Look for patterns that indicate successful ping response
                if ($pingResult -match "bytes from 8.8.8.8" -or $pingResult -match "64 bytes from") {
                    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
                } else {
                    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
                }
                
                # Check DNS resolution using ping instead of nslookup
                $dnsResult = wsl -d $distro -e ping -c 1 google.com 2>$null
                Write-Host "DNS ping result: $dnsResult" -ForegroundColor Yellow
                
                if ($dnsResult -match "bytes from" -or $dnsResult -match "64 bytes from") {
                    Write-Host "- DNS resolution: OK" -ForegroundColor Green
                } else {
                    Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
                }
            } catch {
                Write-Host "- Could not test connectivity (distribution may not be running)" -ForegroundColor Yellow
                Write-Host "  Error: $_" -ForegroundColor Yellow
            }
        }
    }
}

# Run the improved connectivity test
Test-ImprovedWSLConnectivity

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
