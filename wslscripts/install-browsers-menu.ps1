# PowerShell menu script for browser installation
function Show-Menu {
    Clear-Host
    Write-Host "=== WSL Browser Installation Menu ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Get available WSL instances
    $instances = wsl --list --quiet
    
    Write-Host "Available WSL Instances:"
    Write-Host "========================="
    Write-Host ""
    foreach ($instance in $instances) {
        Write-Host $instance
    }
    Write-Host ""
    
    $wslInstance = Read-Host "Enter the name of the WSL instance to install browsers on"
    $username = Read-Host "Enter the username to use for the instance (default: root)"
    
    if ([string]::IsNullOrWhiteSpace($username)) {
        $username = "root"
    }
    
    $confirm = Read-Host "Would you like to install browsers in the WSL instance? (Y/N)"
    
    if ($confirm -eq "Y" -or $confirm -eq "y") {
        Write-Host "Installing browsers in the WSL instance..." -ForegroundColor Cyan
        Write-Host "Launching interactive terminal for browser installation..." -ForegroundColor Yellow
        Write-Host "Please respond to any prompts in the terminal window." -ForegroundColor Yellow
        
        # Execute the installation script
        & "$PSScriptRoot\install-browsers.ps1" -WslInstance $wslInstance -Username $username
        
        Write-Host "Browser installation process completed for instance: $wslInstance" -ForegroundColor Green
    }
    else {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Read-Host "Press Enter to return to the main menu..."
    Show-Menu
}

# Start the menu
Show-Menu 