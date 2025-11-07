# WSL Update Test Script
# This script tests distribution name handling and update functionality

# Display header
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  WSL UPDATE TEST SCRIPT" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

# Get exact distribution names from WSL
Write-Host "Retrieving WSL distributions..." -ForegroundColor Yellow
$wslOutput = wsl --list --verbose
Write-Host "Raw WSL Output:" -ForegroundColor Yellow
$wslOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

# Parse distribution names more carefully
$wslDistros = @()
$defaultDistro = ""

# Direct approach - manually parse the lines
$lines = $wslOutput -split "`n"
foreach ($line in $lines) {
    $line = $line.Trim()
    
    # Skip empty lines and the header
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Contains("NAME") -or $line.Contains("VERSION")) {
        continue
    }
    
    # Check if this is the default distribution (starts with *)
    $isDefault = $false
    if ($line.StartsWith("*")) {
        $isDefault = $true
        $line = $line.Substring(1).Trim()
    }
    
    # Now parse the remaining line for the distribution name
    # Format: NAME STATE VERSION
    if ($line -match "^(\S+)") {
        $distroName = $matches[1]
        $wslDistros += $distroName
        
        if ($isDefault) {
            $defaultDistro = $distroName
        }
        
        Write-Host "Found distribution: $distroName $(if ($isDefault) { '(Default)' } else { '' })" -ForegroundColor Yellow
    }
}

# Display parsed distributions
Write-Host "`nParsed distribution names:" -ForegroundColor Green
if ($wslDistros.Count -eq 0) {
    Write-Host "  No distributions found!" -ForegroundColor Red
} else {
    for ($i = 0; $i -lt $wslDistros.Count; $i++) {
        $defaultMark = if ($wslDistros[$i] -eq $defaultDistro) { " (Default)" } else { "" }
        Write-Host "  $($i+1). $($wslDistros[$i])$defaultMark" -ForegroundColor Cyan
    }
}

# Test each distribution
Write-Host "`nTesting distributions:" -ForegroundColor Green
foreach ($distro in $wslDistros) {
    if ([string]::IsNullOrWhiteSpace($distro)) {
        Write-Host "Skipping empty distribution name" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`nTesting $distro..." -ForegroundColor Yellow
    
    # Test echo command with properly quoted distribution name
    $testCmd = "wsl --distribution `"$distro`" --exec echo 'Testing connection'"
    Write-Host "Command: $testCmd" -ForegroundColor Gray
    
    try {
        $testResult = Invoke-Expression $testCmd
        Write-Host "Result: $testResult" -ForegroundColor Green
        
        # Get OS release information
        $osReleaseCmd = "wsl --distribution `"$distro`" --exec cat /etc/os-release"
        Write-Host "Command: $osReleaseCmd" -ForegroundColor Gray
        
        $osRelease = Invoke-Expression $osReleaseCmd
        
        # Extract distribution type from OS release
        $distroType = "Unknown"
        if ($osRelease -match "ID=(\w+)") {
            $distroType = $matches[1]
        }
        
        Write-Host "Distribution type: $distroType" -ForegroundColor Green
        
        # Determine update command
        $updateCmd = ""
        switch -regex ($distroType) {
            "ubuntu|debian" {
                $updateCmd = "wsl --distribution `"$distro`" --exec echo 'Would run: sudo apt update and upgrade'"
            }
            "fedora|rhel" {
                $updateCmd = "wsl --distribution `"$distro`" --exec echo 'Would run: sudo dnf update'"
            }
            "arch" {
                $updateCmd = "wsl --distribution `"$distro`" --exec echo 'Would run: sudo pacman -Syu'"
            }
            default {
                # Fall back to distribution name
                if ($distro -match "ubuntu|Ubuntu") {
                    $updateCmd = "wsl --distribution `"$distro`" --exec echo 'Would run: sudo apt update and upgrade'"
                }
                else {
                    Write-Host "Could not determine package manager for $distro" -ForegroundColor Red
                    continue
                }
            }
        }
        
        # Execute the update command (just echo in this test)
        Write-Host "Command: $updateCmd" -ForegroundColor Gray
        $updateResult = Invoke-Expression $updateCmd
        Write-Host "Result: $updateResult" -ForegroundColor Green
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

# Wait for user input
Write-Host "`nTest completed. Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Generate fixed code for main script
$fixedFunction = @'
function Update-WSLInstance {
    Show-Header "UPDATE WSL INSTANCE"
    
    # Get list of installed distributions with proper parsing
    Write-Host "Retrieving WSL distributions..." -ForegroundColor Yellow
    $wslOutput = wsl --list --verbose
    $wslDistros = @()
    $defaultDistro = ""
    
    # Direct approach - manually parse the lines
    $lines = $wslOutput -split "`n"
    foreach ($line in $lines) {
        $line = $line.Trim()
        
        # Skip empty lines and the header
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Contains("NAME") -or $line.Contains("VERSION")) {
            continue
        }
        
        # Check if this is the default distribution (starts with *)
        $isDefault = $false
        if ($line.StartsWith("*")) {
            $isDefault = $true
            $line = $line.Substring(1).Trim()
        }
        
        # Now parse the remaining line for the distribution name
        # Format: NAME STATE VERSION
        if ($line -match "^(\S+)") {
            $distroName = $matches[1]
            $wslDistros += $distroName
            
            if ($isDefault) {
                $defaultDistro = $distroName
            }
        }
    }
    
    if ($wslDistros.Count -eq 0) {
        Write-Host "No WSL distributions found to update." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Update options:" -ForegroundColor Green
    Write-Host "1. Update WSL kernel" -ForegroundColor Cyan
    Write-Host "2. Update a specific distribution" -ForegroundColor Cyan
    Write-Host "3. Update all distributions" -ForegroundColor Cyan
    Write-Host "4. Back to main menu" -ForegroundColor Cyan
    
    $updateOption = Read-Host "`nSelect an option (1-4)"
    
    switch ($updateOption) {
        "1" {
            # Update the WSL kernel
            Write-Host "`nUpdating WSL kernel..." -ForegroundColor Yellow
            wsl --update
            Write-Host "WSL kernel updated successfully." -ForegroundColor Green
        }
        "2" {
            # Update a specific distribution
            # Display distributions
            Write-Host "`nInstalled WSL distributions:" -ForegroundColor Green
            for ($i = 0; $i -lt $wslDistros.Count; $i++) {
                $defaultMark = if ($wslDistros[$i] -eq $defaultDistro) { " (Default)" } else { "" }
                Write-Host "  $($i+1). $($wslDistros[$i])$defaultMark" -ForegroundColor Cyan
            }
            
            $distroIndex = Read-Host "`nSelect a distribution to update (1-$($wslDistros.Count)), or 0 to cancel"
            if ($distroIndex -eq "0" -or [string]::IsNullOrEmpty($distroIndex)) {
                return
            }
            
            # Validate user input
            try {
                $index = [int]$distroIndex - 1
                if ($index -lt 0 -or $index -ge $wslDistros.Count) {
                    Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                    return
                }
                $selectedDistro = $wslDistros[$index]
            } catch {
                Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
                return
            }
            
            try {
                Write-Host "`nUpdating $selectedDistro..." -ForegroundColor Yellow
                
                # Check if the distribution is accessible
                $testCmd = "wsl --distribution `"$selectedDistro`" --exec echo 'Testing connection'"
                Write-Host "Testing connection to distribution..." -ForegroundColor Yellow
                $testResult = Invoke-Expression $testCmd
                
                if (-not $testResult) {
                    Write-Host "Could not connect to distribution $selectedDistro. Make sure it exists and is running." -ForegroundColor Red
                    return
                }
                
                # Get distribution info
                Write-Host "Checking distribution type..." -ForegroundColor Yellow
                $osReleaseCmd = "wsl --distribution `"$selectedDistro`" --exec cat /etc/os-release"
                $distroInfo = Invoke-Expression $osReleaseCmd
                
                # Extract distribution type from OS release
                $distroType = "Unknown"
                if ($distroInfo -match "ID=(\w+)") {
                    $distroType = $matches[1]
                }
                
                Write-Host "Distribution type: $distroType" -ForegroundColor Green
                
                # Determine update command based on distribution type
                switch -regex ($distroType) {
                    "ubuntu|debian" {
                        Write-Host "Detected Ubuntu/Debian-based distribution." -ForegroundColor Cyan
                        $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                        Invoke-Expression $updateCmd
                    }
                    "fedora|rhel" {
                        Write-Host "Detected Fedora/RHEL-based distribution." -ForegroundColor Cyan
                        $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo dnf update -y'"
                        Invoke-Expression $updateCmd
                    }
                    "arch" {
                        Write-Host "Detected Arch-based distribution." -ForegroundColor Cyan
                        $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo pacman -Syu --noconfirm'"
                        Invoke-Expression $updateCmd
                    }
                    default {
                        # Check distribution name if type not recognized
                        if ($selectedDistro -match "ubuntu|Ubuntu") {
                            Write-Host "Distribution name suggests Ubuntu. Using apt package manager." -ForegroundColor Cyan
                            $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                            Invoke-Expression $updateCmd
                        } else {
                            # Manual selection if we can't determine automatically
                            Write-Host "Could not determine distribution type. Please select package manager:" -ForegroundColor Yellow
                            Write-Host "1. apt (Ubuntu/Debian)" -ForegroundColor White
                            Write-Host "2. dnf (Fedora/RHEL)" -ForegroundColor White
                            Write-Host "3. pacman (Arch)" -ForegroundColor White
                            Write-Host "4. Cancel update" -ForegroundColor White
                            
                            $pkgManager = Read-Host "Select an option (1-4)"
                            
                            switch ($pkgManager) {
                                "1" {
                                    $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                                    Invoke-Expression $updateCmd
                                }
                                "2" {
                                    $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo dnf update -y'"
                                    Invoke-Expression $updateCmd
                                }
                                "3" {
                                    $updateCmd = "wsl --distribution `"$selectedDistro`" --exec bash -c 'sudo pacman -Syu --noconfirm'"
                                    Invoke-Expression $updateCmd
                                }
                                "4" {
                                    Write-Host "Update canceled." -ForegroundColor Yellow
                                    return
                                }
                                default {
                                    Write-Host "Invalid option. Update canceled." -ForegroundColor Red
                                    return
                                }
                            }
                        }
                    }
                }
                
                Write-Host "Update completed for $selectedDistro." -ForegroundColor Green
            } catch {
                Write-Host ("Error updating " + $selectedDistro + ": " + $_) -ForegroundColor Red
            }
        }
        "3" {
            # Update all distributions
            Write-Host "`nUpdating all WSL distributions... This may take a while." -ForegroundColor Yellow
            
            foreach ($distro in $wslDistros) {
                if ([string]::IsNullOrWhiteSpace($distro)) {
                    continue
                }
                
                try {
                    Write-Host "`nUpdating $distro..." -ForegroundColor Cyan
                    
                    # Test connection to the distribution
                    $testCmd = "wsl --distribution `"$distro`" --exec echo 'Testing connection'"
                    $testResult = Invoke-Expression $testCmd
                    
                    if (-not $testResult) {
                        Write-Host "  Could not connect to distribution $distro. Skipping." -ForegroundColor Yellow
                        continue
                    }
                    
                    # Get distribution info
                    $osReleaseCmd = "wsl --distribution `"$distro`" --exec cat /etc/os-release"
                    $distroInfo = Invoke-Expression $osReleaseCmd
                    
                    # Extract distribution type from OS release
                    $distroType = "Unknown"
                    if ($distroInfo -match "ID=(\w+)") {
                        $distroType = $matches[1]
                    }
                    
                    # Determine update command based on distribution type
                    switch -regex ($distroType) {
                        "ubuntu|debian" {
                            Write-Host "  Detected Ubuntu/Debian-based distribution." -ForegroundColor Cyan
                            $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                            Invoke-Expression $updateCmd
                        }
                        "fedora|rhel" {
                            Write-Host "  Detected Fedora/RHEL-based distribution." -ForegroundColor Cyan
                            $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo dnf update -y'"
                            Invoke-Expression $updateCmd
                        }
                        "arch" {
                            Write-Host "  Detected Arch-based distribution." -ForegroundColor Cyan
                            $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo pacman -Syu --noconfirm'"
                            Invoke-Expression $updateCmd
                        }
                        default {
                            if ($distro -match "ubuntu|Ubuntu") {
                                Write-Host "  Distribution name suggests Ubuntu. Using apt package manager." -ForegroundColor Cyan
                                $updateCmd = "wsl --distribution `"$distro`" --exec bash -c 'sudo apt update && sudo apt upgrade -y'"
                                Invoke-Expression $updateCmd
                            } else {
                                Write-Host "  Skipping update for $distro - unable to determine package manager." -ForegroundColor Yellow
                                continue
                            }
                        }
                    }
                    
                    Write-Host "  $distro updated successfully." -ForegroundColor Green
                } catch {
                    Write-Host ("  Error updating " + $distro + ": " + $_) -ForegroundColor Red
                }
            }
            
            Write-Host "`nAll distributions update process completed." -ForegroundColor Green
        }
        "4" {
            # Return to main menu
            return
        }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
        }
    }
}
'@

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  FIXED FUNCTION FOR MAIN SCRIPT" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan
Write-Host $fixedFunction -ForegroundColor Green 