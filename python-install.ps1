$pythonInstallerUrl = "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
$installerPath = "$env:TEMP\python-installer.exe"

# Download Python installer
Write-Output "Downloading Python installer..."
Invoke-WebRequest -Uri $pythonInstallerUrl -OutFile $installerPath

# Install Python
Write-Output "Installing Python..."
Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=0" -Wait

# Clean up
Remove-Item $installerPath

# Verify installation paths
$pythonPath = "C:\Program Files\Python312\"
$pythonScriptsPath = "C:\Program Files\Python312\Scripts\"

if (Test-Path "$pythonPath\python.exe" -and Test-Path "$pythonScriptsPath\pip.exe") {
    Write-Output "Python installed at $pythonPath and $pythonScriptsPath."
} else {
    Write-Output "Failed to verify Python installation paths. Please check the paths manually."
    # Exit 1
}

# Add Python to the PATH
$env:PATH = "$pythonPath;$pythonScriptsPath;$env:PATH"
[System.Environment]::SetEnvironmentVariable("PATH", $env:PATH, [System.EnvironmentVariableTarget]::Machine)

# Verify if Python is accessible
$pythonVersion = & "$pythonPath\python.exe" --version
if ($LASTEXITCODE -ne 0) {
    Write-Output "Python is not accessible. Please check the installation and PATH settings."
    # Exit 1
} else {
    Write-Output "Python version: $pythonVersion"
}

# Ensure pip is up-to-date and install required Python modules
Write-Output "Installing required Python modules..."
& "$pythonPath\python.exe" -m pip install --upgrade pip
& "$pythonPath\python.exe" -m pip install ujson

if ($LASTEXITCODE -ne 0) {
    Write-Output "Failed to install required Python modules."
    # pause
    # exit
}

# Create the manifest file with the correct path
$manifestContent = @"
{
    "name": "com.example.browserlauncher",
    "description": "Browser Launcher",
    "path": "$env:SCRIPT_PATH",
    "type": "stdio",
    "allowed_origins": [
        "chrome-extension://$env:CHROME_EXTENSION_ID/"
    ]
}
"@
$manifestContent | Out-File -FilePath $env:MANIFEST_PATH -Encoding utf8

# Create registry entries for Chrome
$regKey = $env:REG_KEY
New-Item -Path $regKey -Force | Out-Null
Set-ItemProperty -Path $regKey -Name "(default)" -Value $env:MANIFEST_PATH -Force

if ($?) {
    Write-Output "Created registry entry for Chrome at $regKey"
} else {
    Write-Output "Failed to create registry entry for Chrome."
}

# Create registry entries for Edge
$regKeyEdge = $env:REG_KEY_EDGE
New-Item -Path $regKeyEdge -Force | Out-Null
Set-ItemProperty -Path $regKeyEdge -Name "(default)" -Value $env:MANIFEST_PATH -Force

if ($?) {
    Write-Output "Created registry entry for Edge at $regKeyEdge"
} else {
    Write-Output "Failed to create registry entry for Edge."
}

Write-Output "Native messaging host setup completed."
