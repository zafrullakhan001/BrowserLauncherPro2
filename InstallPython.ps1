$pythonInstallerUrl = "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
$installerPath = "$env:TEMP\python-installer.exe"

# Download Python installer
Write-Output "Downloading Python installer..."
Invoke-WebRequest -Uri $pythonInstallerUrl -OutFile $installerPath

# Install Python
Write-Output "Installing Python..."
Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

# Clean up
Remove-Item $installerPath

# Verify installation
$pythonPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)
if ($pythonPath -contains "Python") {
    Write-Output "Python installed and added to PATH."
} else {
    Write-Output "Failed to add Python to PATH. Please add it manually."
    Exit 1
}
