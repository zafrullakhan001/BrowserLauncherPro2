# Check if the script is running with administrative privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# If not running as admin, relaunch the script with admin rights
if (-not (Test-Admin)) {
    Write-Host "This script requires administrative privileges. Restarting with elevated rights..."
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    Exit
}

# Set the execution policy to RemoteSigned for the current user
try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
} catch {
    Write-Host "Warning: Could not set execution policy. Continuing with current policy..."
}

# Function to check if WSL is enabled
function Check-WSLInstalled {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    return $wslFeature.State -eq "Enabled"
}

# Function to check if the Virtual Machine Platform is enabled
function Check-VirtualMachinePlatformInstalled {
    try {
        $process = Start-Process -FilePath "dism.exe" -ArgumentList "/online /get-featureinfo /featurename:VirtualMachinePlatform" -NoNewWindow -Wait -PassThru -RedirectStandardOutput "dism_check.txt"
        
        if (Test-Path "dism_check.txt") {
            $output = Get-Content "dism_check.txt"
            Remove-Item "dism_check.txt" -Force
            
            if ($output -match "State : Enabled") {
                return $true
            }
        }
        return $false
    } catch {
        Write-Host "Warning: Could not check Virtual Machine Platform status."
        return $false
    }
}

# Function to enable Virtual Machine Platform
function Enable-VirtualMachinePlatform {
    try {
        $process = Start-Process -FilePath "dism.exe" -ArgumentList "/online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -NoNewWindow -Wait -PassThru -RedirectStandardOutput "dism_output.txt"
        
        if (Test-Path "dism_output.txt") {
            $output = Get-Content "dism_output.txt"
            Remove-Item "dism_output.txt" -Force
            
            if ($output -match "Error: 50") {
                Write-Host "Virtual Machine Platform is already enabled."
                return $false
            }
            
            if ($output -match "The operation completed successfully") {
                return $true
            }
        }
        
        Write-Host "Virtual Machine Platform status could not be determined."
        return $false
    } catch {
        Write-Host "Warning: Could not enable Virtual Machine Platform. It may already be enabled."
        return $false
    }
}

# Function to check if the system is running Windows 11 or the latest Windows 10
function Check-WindowsVersion {
    $windowsVersion = [System.Environment]::OSVersion.Version
    if ($windowsVersion.Major -ge 10 -and $windowsVersion.Build -ge 19041) {
        return $true
    } else {
        return $false
    }
}

# Function to install WSL and Ubuntu
function Install-WSL {
    Write-Host "Installing WSL with Ubuntu 24.04 LTS..."
    
    # Set WSL 2 as the default version
    wsl --set-default-version 2
    
    # Install Ubuntu 24.04 LTS
    wsl --install -d Ubuntu-24.04
    
    Write-Host "WSL with Ubuntu 24.04 LTS has been successfully installed."
    wsl --shutdown
}

# Function to uninstall WSL
function Uninstall-WSL {
    Write-Host "Uninstalling WSL..."
    wsl --unregister Ubuntu-24.04
    dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
    dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
    Write-Host "WSL has been uninstalled. A system restart is required."
    $restart = Read-Host "Would you like to restart now? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Restart-Computer -Force
    }
}

# Function to update WSL
function Update-WSL {
    Write-Host "Updating WSL..."
    wsl --update
    Write-Host "WSL has been updated."
}

# Function to list installed WSL distributions
function List-WSLDistributions {
    Write-Host "Installed WSL Distributions:"
    wsl --list --verbose
}

# Main menu function
function Show-Menu {
    Clear-Host
    Write-Host "WSL Management Menu"
    Write-Host "=================="
    Write-Host "1. Install WSL with Ubuntu 24.04"
    Write-Host "2. Uninstall WSL"
    Write-Host "3. Update WSL"
    Write-Host "4. List Installed Distributions"
    Write-Host "5. Exit"
    Write-Host "=================="
}

# Main script logic
while ($true) {
    Show-Menu
    $choice = Read-Host "Please select an option (1-5)"
    
    switch ($choice) {
        "1" {
            $restartRequired = $false
            
            if (-not (Check-WindowsVersion)) {
                Write-Host "This script requires Windows 10 version 2004 (build 19041) or higher. Please update your system."
                break
            }
            
            if (-not (Check-WSLInstalled)) {
                Write-Host "Enabling WSL..."
                dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
                $restartRequired = $true
            }
            
            if (-not (Check-VirtualMachinePlatformInstalled)) {
                Write-Host "Checking Virtual Machine Platform..."
                if (Enable-VirtualMachinePlatform) {
                    $restartRequired = $true
                }
            }
            
            if ($restartRequired) {
                Write-Host "A system restart is required to apply changes. Would you like to restart now? (Y/N)"
                $restart = Read-Host
                if ($restart -eq "Y" -or $restart -eq "y") {
                    Restart-Computer -Force
                } else {
                    Write-Host "Please restart your computer manually to complete the installation."
                    break
                }
            } else {
                Install-WSL
            }
        }
        "2" { Uninstall-WSL }
        "3" { Update-WSL }
        "4" { List-WSLDistributions }
        "5" { Exit }
        default { Write-Host "Invalid option. Please try again." }
    }
    
    if ($choice -ne "5") {
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
