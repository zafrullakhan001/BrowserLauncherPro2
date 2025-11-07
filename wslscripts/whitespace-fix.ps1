# WSL Connectivity Test with proper whitespace handling
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  WSL CONNECTIVITY TEST" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

# Get distributions with proper whitespace handling
$rawOutput = (wsl --list)
$wslDistros = @()
foreach ($line in $rawOutput | Select-Object -Skip 1) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        if ($line -match "(\S+)") {
            $distroName = $matches[1]
            $wslDistros += $distroName
        }
    }
}

Write-Host "Detected distributions:"
$wslDistros | ForEach-Object { Write-Host "- $_" }

foreach ($distro in $wslDistros) {
    Write-Host ("`nTesting connectivity for " + $distro + ":") -ForegroundColor Green
    
    # Check internet connectivity
    $cmd = "wsl -d `"$distro`" -e ping -c 2 8.8.8.8"
    Write-Host "Running: $cmd" -ForegroundColor Gray
    
    try {
        $pingResult = Invoke-Expression $cmd
        $internetOK = $pingResult -match "bytes from"
        
        if ($internetOK) {
            Write-Host "- Internet connectivity: OK" -ForegroundColor Green
        } else {
            Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
            Write-Host "Result: $pingResult" -ForegroundColor Yellow
        }
        
        # Check DNS resolution
        $cmd = "wsl -d `"$distro`" -e ping -c 1 google.com"
        Write-Host "Running: $cmd" -ForegroundColor Gray
        
        $dnsResult = Invoke-Expression $cmd
        $dnsOK = $dnsResult -match "bytes from"
        
        if ($dnsOK) {
            Write-Host "- DNS resolution: OK" -ForegroundColor Green
        } else {
            Write-Host "- DNS resolution: FAILED" -ForegroundColor Red
            Write-Host "Result: $dnsResult" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error executing command: $_" -ForegroundColor Red
    }
}

Write-Host "`nFinished testing all distributions."

# Create a fixed Test-WSLConnectivity function for the main script
$fixedFunction = @'
function Test-WSLConnectivity {
    Show-Header "WSL CONNECTIVITY TEST"
    
    # Get distributions with proper whitespace handling
    $rawOutput = (wsl --list)
    $wslDistros = @()
    foreach ($line in $rawOutput | Select-Object -Skip 1) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            if ($line -match "(\S+)") {
                $distroName = $matches[1]
                $wslDistros += $distroName
            }
        }
    }
    
    foreach ($distro in $wslDistros) {
        Write-Host ("`nTesting connectivity for " + $distro + ":") -ForegroundColor Green
        
        try {
            # Check internet connectivity with proper pattern matching
            $cmd = "wsl -d `"" + $distro + "`" -e ping -c 2 8.8.8.8 2>`$null"
            $pingResult = Invoke-Expression $cmd
            
            if ($pingResult -match "bytes from") {
                Write-Host "- Internet connectivity: OK" -ForegroundColor Green
            } else {
                Write-Host "- Internet connectivity: FAILED" -ForegroundColor Red
            }
            
            # Check DNS resolution using ping
            $cmd = "wsl -d `"" + $distro + "`" -e ping -c 1 google.com 2>`$null"
            $dnsResult = Invoke-Expression $cmd
            
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

Write-Host "`nTo fix the main script, replace the Test-WSLConnectivity function with this code:" -ForegroundColor Yellow
Write-Host $fixedFunction -ForegroundColor White

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 