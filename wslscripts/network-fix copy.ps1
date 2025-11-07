# File: Check-WSL2-Network.ps1
# Description: This script checks if WSL2 has internet connectivity for any one running instance. 
# If not, it resets the WSL2 network and rechecks the connection.

# Function to log and execute commands
function Invoke-LoggedCommand {
    param(
        [string]$Command
    )
    Write-Host "Executing: $Command" -ForegroundColor Cyan
    Invoke-Expression $Command
}

# Function to get or start a WSL2 instance
function Get-OrStartWSL2Instance {
    $wslOutput = wsl -l -v
    $wslInstances = $wslOutput | Select-Object -Skip 1 | Where-Object { $_ -match "2" -and $_ -notmatch "docker" } | ForEach-Object { ($_ -split "\s+")[1].Trim() }
    
    if ($wslInstances.Count -eq 0) {
        Write-Host "No WSL2 instance found." -ForegroundColor Red
        return $null
    } else {
        $instanceName = $wslInstances | Select-Object -First 1
        Write-Host "Using WSL2 instance: $instanceName" -ForegroundColor Green
        return $instanceName
    }
}

# Function to check WSL2 internet connectivity
function Test-WSL2Internet {
    param(
        [string]$instance
    )
    
    try {
        $command = "wsl.exe -d `"$instance`" -- ping -c 4 -W 10 google.com"
        Write-Host "Executing: $command" -ForegroundColor Cyan
        $result = Invoke-Expression $command 2>&1
        
        # Check if any successful pings were received
        if ($result -match "bytes from") {
            Write-Host "WSL2 instance '$instance' has internet connectivity." -ForegroundColor Green
            Write-Host "Ping result:" -ForegroundColor Green
            $result | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            return $true
        } else {
            Write-Host "WSL2 instance '$instance' does not have internet connectivity." -ForegroundColor Red
            Write-Host "Ping result:" -ForegroundColor Yellow
            $result | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            return $false
        }
    } catch {
        Write-Host "Error occurred while testing WSL2 internet connection for instance '$instance'." -ForegroundColor Red
        Write-Host "Error details: $_" -ForegroundColor Yellow
        return $false
    }
}

# Function to reset WSL2 networking
function Reset-WSL2Networking {
    Write-Host "Attempting to reset WSL2 networking..." -ForegroundColor Yellow

    # 1. Shut down WSL
    Write-Host "Shutting down WSL2..."
    Invoke-LoggedCommand "wsl --shutdown"

    # 2. Check for WSL-related network adapters
    Invoke-LoggedCommand "Get-NetAdapter | Where-Object { `$_.Name -like '*WSL*' -or `$_.Name -like '*vEthernet*' }"
    $wslAdapters = Get-NetAdapter | Where-Object { $_.Name -like "*WSL*" -or $_.Name -like "*vEthernet*" }
    if ($wslAdapters) {
        foreach ($adapter in $wslAdapters) {
            Write-Host "Resetting adapter: $($adapter.Name)"
            Invoke-LoggedCommand "Disable-NetAdapter -Name `"$($adapter.Name)`" -Confirm:`$false"
            Start-Sleep -Seconds 2
            Invoke-LoggedCommand "Enable-NetAdapter -Name `"$($adapter.Name)`" -Confirm:`$false"
        }
    } else {
        Write-Host "No WSL-related network adapters found. Skipping adapter reset." -ForegroundColor Yellow
    }

    # 3. Restart WSL2
    Write-Host "Restarting WSL2..."
    Invoke-LoggedCommand "wsl"

    Write-Host "WSL2 networking reset attempt complete."
}

# Function to check and fix WSL2 internet connection
function Test-AndRepairWSL2Internet {
    # Get or start a WSL2 instance
    $instance = Get-OrStartWSL2Instance

    if ($null -eq $instance) {
        Write-Host "No WSL2 instances available to check." -ForegroundColor Red
        return
    }

    Write-Host "Checking WSL2 internet connection for instance '$instance'..."
    $internetWorking = Test-WSL2Internet -instance $instance

    if (-not $internetWorking) {
        Write-Host "Internet is not working for WSL2 instance '$instance'. Attempting to reset WSL2 networking..."
        Reset-WSL2Networking

        # Recheck the internet connection
        Write-Host "Rechecking WSL2 internet connection for instance '$instance'..."
        $internetWorking = Test-WSL2Internet -instance $instance

        if ($internetWorking) {
            Write-Host "WSL2 internet connection for instance '$instance' is now working." -ForegroundColor Green
        } else {
            Write-Host "WSL2 internet connection for instance '$instance' is still not working after reset." -ForegroundColor Red
        }
    }
}

# Run the script
Test-AndRepairWSL2Internet
