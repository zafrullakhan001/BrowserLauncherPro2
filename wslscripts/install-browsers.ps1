# PowerShell script to install browsers in WSL
param(
    [Parameter(Mandatory=$true)]
    [string]$WslInstance,
    
    [Parameter(Mandatory=$true)]
    [string]$Username
)

# Function to check if WSL instance exists
function Test-WslInstance {
    param([string]$InstanceName)
    $instances = wsl --list --quiet
    return $instances -contains $InstanceName
}

# Function to check if user exists in WSL
function Test-WslUser {
    param(
        [string]$InstanceName,
        [string]$Username
    )
    $result = wsl -d $InstanceName --user $Username whoami 2>&1
    return $result -eq $Username
}

# Main script
try {
    # Check if WSL instance exists
    if (-not (Test-WslInstance $WslInstance)) {
        Write-Host "Error: WSL instance '$WslInstance' does not exist." -ForegroundColor Red
        exit 1
    }

    # Check if user exists
    if (-not (Test-WslUser $WslInstance $Username)) {
        Write-Host "Error: User '$Username' does not exist in WSL instance '$WslInstance'." -ForegroundColor Red
        exit 1
    }

    # Copy the installation script to WSL
    $scriptPath = Join-Path $PSScriptRoot "wsl-install-browsers.sh"
    $wslScriptPath = "/tmp/wsl-install-browsers.sh"
    
    # Copy script to WSL
    wsl -d $WslInstance --user $Username cp $scriptPath $wslScriptPath
    
    # Make script executable
    wsl -d $WslInstance --user $Username chmod +x $wslScriptPath
    
    # Execute the script in WSL
    Write-Host "Starting browser installation in WSL instance '$WslInstance'..." -ForegroundColor Cyan
    wsl -d $WslInstance --user $Username $wslScriptPath
    
    # Clean up
    wsl -d $WslInstance --user $Username rm $wslScriptPath
    
    Write-Host "Browser installation completed for instance: $WslInstance" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    exit 1
} 