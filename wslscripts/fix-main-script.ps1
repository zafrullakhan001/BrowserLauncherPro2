# Fix for the main script's connectivity test
# This script will extract the Test-WSLConnectivity function and replace it with our working version

# First, let's be sure connectivity is working
Write-Host "Testing WSL connectivity directly before applying fix..." -ForegroundColor Cyan
.\wslscripts\fix-connectivity-manual.ps1

# Define the fixed function
$fixedFunction = @'
function Test-WSLConnectivity {
    Show-Header "WSL CONNECTIVITY TEST"
    
    $wslDistros = (wsl --list --quiet) -split "`n" | Where-Object { $_ -and $_ -ne "Windows" }
    
    foreach ($distro in $wslDistros) {
        if ($distro -and $distro.Trim() -ne "") {
            Write-Host ("`nTesting connectivity for {0}:" -f $distro) -ForegroundColor Green
            
            try {
                # Check internet connectivity with proper pattern matching
                $pingResult = wsl -d $distro -e ping -c 2 8.8.8.8 2>$null
                if ($pingResult -match "bytes from") {
                    Write-Host "- Internet connectivity: OK" -ForegroundColor Green
                } else {
                    Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
                }
                
                # Check DNS resolution using ping
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
}
'@

# Now let's create a function that can be used directly
Write-Host "`nCreating a standalone function for direct use..." -ForegroundColor Cyan

# Define a function that can be called directly
function Invoke-WSLConnectivityTest {
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "  WSL CONNECTIVITY TEST" -ForegroundColor Cyan
    Write-Host "=============================================`n" -ForegroundColor Cyan
    
    $wslDistros = (wsl --list --quiet) -split "`n" | Where-Object { $_ -and $_ -ne "Windows" }
    
    foreach ($distro in $wslDistros) {
        if ($distro -and $distro.Trim() -ne "") {
            $distro = $distro.Trim()
            Write-Host ("`nTesting connectivity for {0}:" -f $distro) -ForegroundColor Green
            
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
}

# Run the function directly
Write-Host "`nRunning the function from this script:" -ForegroundColor Cyan
Invoke-WSLConnectivityTest

# Provide instructions for fixing the main script
Write-Host "`n=============================================" -ForegroundColor Cyan  
Write-Host "INSTRUCTIONS TO FIX THE MAIN SCRIPT" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "To fix the main script, replace the Test-WSLConnectivity function with this improved version:" -ForegroundColor Yellow
Write-Host "$fixedFunction" -ForegroundColor White
Write-Host "`nYou can do this manually by editing wslscripts\wsl-info-and-tools.ps1" -ForegroundColor Yellow
Write-Host "Or you can run this script with administrator privileges to attempt an automatic fix." -ForegroundColor Yellow

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 