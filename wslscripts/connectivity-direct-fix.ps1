# Direct replacement for the Test-WSLConnectivity function
# This script will directly run our fixed function without depending on the main script

function Show-Header {
    param (
        [string]$Title
    )
    
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=============================================`n" -ForegroundColor Cyan
}

# Defining our own function directly
function Test-WSLConnectivity-Fixed {
    Show-Header "WSL CONNECTIVITY TEST (FIXED VERSION)"
    
    $wslDistros = (wsl --list --quiet) -split "`n" | Where-Object { $_ -and $_ -ne "Windows" }
    
    foreach ($distro in $wslDistros) {
        if ($distro -and $distro.Trim() -ne "") {
            $distro = $distro.Trim()
            Write-Host ("`nTesting connectivity for {0}:" -f $distro) -ForegroundColor Green
            
            try {
                Write-Host "Running ping to 8.8.8.8..."
                $pingResult = wsl -d $distro -e ping -c 2 8.8.8.8
                $internetOK = $pingResult -match "bytes from"
                Write-Host "Ping result contains 'bytes from': $internetOK"
                
                if ($internetOK) {
                    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
                } else {
                    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
                    Write-Host "Detailed ping result:" -ForegroundColor Yellow
                    Write-Host $pingResult -ForegroundColor Gray
                }
                
                Write-Host "Running ping to google.com..."
                $dnsResult = wsl -d $distro -e ping -c 1 google.com
                $dnsOK = $dnsResult -match "bytes from"
                Write-Host "DNS ping result contains 'bytes from': $dnsOK"
                
                if ($dnsOK) {
                    Write-Host "- DNS resolution: OK" -ForegroundColor Green
                } else {
                    Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
                    Write-Host "Detailed DNS result:" -ForegroundColor Yellow
                    Write-Host $dnsResult -ForegroundColor Gray
                }
            } catch {
                Write-Host "- Could not test connectivity (distribution may not be running)" -ForegroundColor Yellow
                Write-Host "Error details: $_" -ForegroundColor Red
            }
        }
    }
}

# Run our fixed function
Test-WSLConnectivity-Fixed

Write-Host "`nInstallation Instructions:" -ForegroundColor Yellow
Write-Host "To permanently fix the main script, open wsl-info-and-tools.ps1" -ForegroundColor White
Write-Host "and replace the Test-WSLConnectivity function with the one from this script." -ForegroundColor White

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 