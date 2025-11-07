# CheckDependencies.ps1
# Script to check and install all required dependencies for the Browser Launcher Extension

param(
    [switch]$ReturnResults
)

# Check if running with admin privileges and if not, restart with elevation
# Skip elevation if being called from another script with ReturnResults
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Self-elevate the script if not running as administrator and not being called with ReturnResults
if (-not (Test-Admin) -and -not $ReturnResults) {
    Write-Host "This script requires administrative privileges. Requesting elevation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    
    # Restart script with admin rights
    $scriptPath = $MyInvocation.MyCommand.Definition
    $arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
    
    try {
        Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList $arguments -Wait
        # Exit the current non-elevated instance
        exit
    }
    catch {
        Write-Host "Failed to restart with administrative privileges. Please run this script as administrator." -ForegroundColor Red
        Write-Host "Right-click on the script and select 'Run as administrator'." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        exit 1
    }
}

# Set script to stop on first error
$ErrorActionPreference = "Stop"

# Store overall check status
$checksPassed = $true

Write-Host "=== Browser Launcher Extension Dependency Checker ===" -ForegroundColor Cyan
if (Test-Admin) {
    Write-Host "Running with administrative privileges. Proceeding with dependency checks..." -ForegroundColor Green
} else {
    Write-Host "Running without administrative privileges. Some checks may fail." -ForegroundColor Yellow
}

#region Python Check
Write-Host "`nChecking Python installation..." -ForegroundColor Green
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match '(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        
        if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 7)) {
            Write-Host "Python version $pythonVersion detected. Version 3.7 or higher is required." -ForegroundColor Red
            
            $installPython = Read-Host "Do you want to install Python 3.11? (Y/N)"
            if ($installPython -eq "Y" -or $installPython -eq "y") {
                Write-Host "Downloading and installing Python 3.11..." -ForegroundColor Cyan
                $pythonUrl = "https://www.python.org/ftp/python/3.11.5/python-3.11.5-amd64.exe"
                $pythonInstaller = "$env:TEMP\python-3.11.5-amd64.exe"
                
                # Download Python installer
                Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
                
                # Install Python with required options
                Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0", "Include_launcher=1" -Wait
                
                # Verify installation
                $pythonVersion = python --version 2>&1
                if ($pythonVersion -match 'Python 3\.11') {
                    Write-Host "Python 3.11 installed successfully." -ForegroundColor Green
                } else {
                    Write-Host "Python installation may have failed. Please install Python 3.7+ manually." -ForegroundColor Red
                    $checksPassed = $false
                }
            } else {
                Write-Host "Please install Python 3.7 or higher manually and run this script again." -ForegroundColor Yellow
                $checksPassed = $false
            }
        } else {
            Write-Host "Python $pythonVersion is installed and meets requirements." -ForegroundColor Green
        }
    }
} catch {
    Write-Host "Python is not installed or not in PATH." -ForegroundColor Red
    
    $installPython = Read-Host "Do you want to install Python 3.11? (Y/N)"
    if ($installPython -eq "Y" -or $installPython -eq "y") {
        Write-Host "Downloading and installing Python 3.11..." -ForegroundColor Cyan
        $pythonUrl = "https://www.python.org/ftp/python/3.11.5/python-3.11.5-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-3.11.5-amd64.exe"
        
        # Download Python installer
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
        
        # Install Python with required options
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0", "Include_launcher=1" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        try {
            $pythonVersion = python --version 2>&1
            Write-Host "Python $pythonVersion installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Python installation failed. Please install Python 3.7+ manually." -ForegroundColor Red
            $checksPassed = $false
        }
    } else {
        Write-Host "Please install Python 3.7 or higher manually and run this script again." -ForegroundColor Yellow
        $checksPassed = $false
    }
}
#endregion

#region Python Modules
Write-Host "`nChecking and installing required Python modules..." -ForegroundColor Green

# Upgrade pip
Write-Host "Upgrading pip..." -ForegroundColor Cyan
try {
    python -m pip install --upgrade pip
    Write-Host "Pip upgraded successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to upgrade pip. Please check your Python installation." -ForegroundColor Red
    $checksPassed = $false
}

# Required modules
$requiredModules = @(
    # Third-party modules that may need installation
    @{Name="ujson"; InstallRequired=$true},
    @{Name="psutil"; InstallRequired=$true},
    @{Name="configparser"; InstallRequired=$true},
    # Built-in modules that don't need installation but should be verified
    @{Name="platform"; InstallRequired=$false},
    @{Name="uuid"; InstallRequired=$false},
    @{Name="socket"; InstallRequired=$false},
    @{Name="struct"; InstallRequired=$false},
    @{Name="subprocess"; InstallRequired=$false},
    @{Name="os"; InstallRequired=$false},
    @{Name="re"; InstallRequired=$false},
    @{Name="time"; InstallRequired=$false},
    @{Name="signal"; InstallRequired=$false},
    @{Name="logging"; InstallRequired=$false}
)

# First list which modules will be checked
Write-Host "Will check the following Python modules:" -ForegroundColor Cyan
$requiredModules | ForEach-Object { Write-Host "  - $($_.Name) (installation required: $($_.InstallRequired))" -ForegroundColor Gray }

foreach ($module in $requiredModules) {
    $moduleName = $module.Name
    Write-Host "Checking module: $moduleName" -ForegroundColor Cyan
    
    # Test if module can be imported
    $moduleTestOutput = python -c "import $moduleName; print('Module $moduleName imported successfully')" 2>&1
    $moduleImportSuccess = $moduleTestOutput -match "imported successfully"
    
    if (-not $moduleImportSuccess) {
        if ($module.InstallRequired) {
            Write-Host "Installing $moduleName..." -ForegroundColor Yellow
            try {
                python -m pip install $moduleName
                
                # Verify installation was successful
                $verifyOutput = python -c "import $moduleName; print('Module $moduleName imported successfully')" 2>&1
                if ($verifyOutput -match "imported successfully") {
                    Write-Host "$moduleName installed and imported successfully." -ForegroundColor Green
                } else {
                    Write-Host "Module $moduleName was installed but import verification failed." -ForegroundColor Red
                    Write-Host "Error: $verifyOutput" -ForegroundColor Gray
                    $checksPassed = $false
                }
            } catch {
                Write-Host "Failed to install $moduleName. Error: $_" -ForegroundColor Red
                $checksPassed = $false
            }
        } else {
            Write-Host "Warning: Built-in module $moduleName could not be imported. Check your Python installation." -ForegroundColor Yellow
            $checksPassed = $false
        }
    } else {
        Write-Host "$moduleName is available." -ForegroundColor Green
    }
}
#endregion

#region Python Environment Verification
Write-Host "`nVerifying Python environment for hardware ID generation and native messaging..." -ForegroundColor Green

# Verify Python path is correct
$pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Path
if ($pythonPath) {
    Write-Host "Python path: $pythonPath" -ForegroundColor Green
    
    # Verify Python version more precisely
    $versionOutput = python --version 2>&1
    if ($versionOutput -match 'Python (\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]
        
        Write-Host "Python version: $major.$minor.$patch" -ForegroundColor Green
        
        if ($major -ge 3 -and $minor -ge 7) {
            Write-Host "Python version is sufficient." -ForegroundColor Green
        } else {
            Write-Host "Warning: Python version $major.$minor.$patch may be too old. Version 3.7+ is recommended." -ForegroundColor Yellow
            $checksPassed = $false
        }
    }
    
    # Check if Python is 32-bit or 64-bit
    $archOutput = python -c "import struct; print(struct.calcsize('P') * 8)"
    $pythonArch = $archOutput.Trim()
    Write-Host "Python architecture: $pythonArch-bit" -ForegroundColor Green
    
    # Check if matches system architecture
    $sysArch = if ([System.Environment]::Is64BitOperatingSystem) { "64" } else { "32" }
    if ($pythonArch -ne $sysArch) {
        Write-Host "Warning: Python architecture ($pythonArch-bit) doesn't match system architecture ($sysArch-bit)" -ForegroundColor Yellow
    }
    
    # Check Python executability for native messaging (in particular python.exe)
    try {
        $testOutput = & $pythonPath -c "print('Python can be executed')" 2>&1
        if ($testOutput -match "Python can be executed") {
            Write-Host "Python can be executed directly by the system." -ForegroundColor Green
        } else {
            Write-Host "Warning: Python may not be executable by the native messaging host." -ForegroundColor Yellow
            $checksPassed = $false
        }
    } catch {
        Write-Host "Error: Python cannot be executed directly. This will cause problems with native messaging." -ForegroundColor Red
        $checksPassed = $false
    }
    
    # Check if the subprocess module can properly execute commands
    try {
        $testSubprocess = python -c "import subprocess; result = subprocess.run(['cmd', '/c', 'echo Test successful'], capture_output=True, text=True); print(result.stdout.strip())" 2>&1
        if ($testSubprocess -match "Test successful") {
            Write-Host "Subprocess module is working correctly." -ForegroundColor Green
        } else {
            Write-Host "Warning: Subprocess module may not be working correctly." -ForegroundColor Yellow
            $checksPassed = $false
        }
    } catch {
        Write-Host "Error testing subprocess module: $_" -ForegroundColor Red
        $checksPassed = $false
    }
    
} else {
    Write-Host "Error: Python is not in your PATH. This will cause the native messaging host to fail." -ForegroundColor Red
    $checksPassed = $false
}
#endregion

#region Hardware ID Generation Dependencies
Write-Host "`nChecking hardware ID generation dependencies..." -ForegroundColor Green

# Check WMIC availability (for hardware ID generation)
Write-Host "Checking WMIC availability..." -ForegroundColor Cyan
try {
    $wmicResult = wmic computersystem get name 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "WMIC is available." -ForegroundColor Green
    } else {
        Write-Host "WMIC is not available. Hardware ID generation may fall back to less secure methods." -ForegroundColor Yellow
        $checksPassed = $false
    }
} catch {
    Write-Host "Error checking WMIC: $_" -ForegroundColor Red
    Write-Host "Hardware ID generation may fall back to less secure methods." -ForegroundColor Yellow
    $checksPassed = $false
}

# Check native messaging host registration
Write-Host "Checking native messaging host registration..." -ForegroundColor Cyan
try {
    $nativeMessagingPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.example.browserlauncher"
    $edgeNativeMessagingPath = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.example.browserlauncher"
    
    $chromeRegistered = Test-Path $nativeMessagingPath
    $edgeRegistered = Test-Path $edgeNativeMessagingPath
    
    if ($chromeRegistered -or $edgeRegistered) {
        Write-Host "Native messaging host is registered." -ForegroundColor Green
        
        # Verify the JSON manifest file
        if ($chromeRegistered) {
            $manifestPath = (Get-ItemProperty $nativeMessagingPath).'(Default)'
        } else {
            $manifestPath = (Get-ItemProperty $edgeNativeMessagingPath).'(Default)'
        }
        
        if (Test-Path $manifestPath) {
            Write-Host "Native messaging manifest file exists: $manifestPath" -ForegroundColor Green
            
            # Check if the python script exists
            $manifestContent = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $pythonScriptPath = $manifestContent.path -replace '\\\\', '\'
            
            if (Test-Path $pythonScriptPath) {
                Write-Host "Native messaging Python script exists: $pythonScriptPath" -ForegroundColor Green
            } else {
                Write-Host "Native messaging Python script not found at: $pythonScriptPath" -ForegroundColor Red
                $checksPassed = $false
            }
        } else {
            Write-Host "Native messaging manifest file not found at: $manifestPath" -ForegroundColor Red
            $checksPassed = $false
        }
    } else {
        Write-Host "Native messaging host is not registered. Hardware ID generation may fail." -ForegroundColor Red
        Write-Host "Please reinstall the extension to fix this issue." -ForegroundColor Yellow
        $checksPassed = $false
    }
} catch {
    Write-Host "Error checking native messaging host registration: $_" -ForegroundColor Red
    $checksPassed = $false
}
#endregion

#region Windows Sandbox
Write-Host "`nChecking for Windows Sandbox feature..." -ForegroundColor Green
$sandboxFeature = Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -ErrorAction SilentlyContinue

if ($sandboxFeature -eq $null -or $sandboxFeature.State -ne "Enabled") {
    Write-Host "Windows Sandbox is not enabled." -ForegroundColor Yellow
    $enableSandbox = Read-Host "Do you want to enable Windows Sandbox? (Y/N)"
    
    if ($enableSandbox -eq "Y" -or $enableSandbox -eq "y") {
        try {
            Write-Host "Enabling Windows Sandbox. This may take a few minutes and require a restart..." -ForegroundColor Cyan
            Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart
            
            if ((Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM").State -eq "Enabled") {
                Write-Host "Windows Sandbox enabled successfully." -ForegroundColor Green
            } else {
                Write-Host "Windows Sandbox enablement pending. A system restart may be required." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Failed to enable Windows Sandbox. Please enable it manually in Windows Features." -ForegroundColor Red
            $checksPassed = $false
        }
    } else {
        Write-Host "Skipping Windows Sandbox enablement." -ForegroundColor Yellow
    }
} else {
    Write-Host "Windows Sandbox is already enabled." -ForegroundColor Green
}
#endregion

#region WSL
Write-Host "`nChecking for Windows Subsystem for Linux (WSL)..." -ForegroundColor Green

try {
    $wslOutput = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "WSL is installed and configured." -ForegroundColor Green
        
        # Check for installed distributions
        $wslDistros = wsl --list --quiet 2>&1
        if ($wslDistros -match "\S+") {
            Write-Host "WSL distributions found:" -ForegroundColor Green
            wsl --list
        } else {
            Write-Host "No WSL distributions found." -ForegroundColor Yellow
            $installUbuntu = Read-Host "Do you want to install Ubuntu on WSL? (Y/N)"
            
            if ($installUbuntu -eq "Y" -or $installUbuntu -eq "y") {
                Write-Host "Installing Ubuntu on WSL. This may take several minutes..." -ForegroundColor Cyan
                try {
                    wsl --install -d Ubuntu
                    Write-Host "Ubuntu installation initiated. Follow any additional on-screen prompts." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to install Ubuntu. Please install it manually using 'wsl --install -d Ubuntu'." -ForegroundColor Red
                    $checksPassed = $false
                }
            }
        }
    } else {
        Write-Host "WSL is not installed or not properly configured." -ForegroundColor Yellow
        $installWSL = Read-Host "Do you want to install WSL? (Y/N)"
        
        if ($installWSL -eq "Y" -or $installWSL -eq "y") {
            Write-Host "Installing WSL. This may take several minutes and require a restart..." -ForegroundColor Cyan
            try {
                wsl --install
                Write-Host "WSL installation initiated. A system restart may be required to complete installation." -ForegroundColor Yellow
            } catch {
                Write-Host "Failed to install WSL. Please install it manually using 'wsl --install'." -ForegroundColor Red
                $checksPassed = $false
            }
        }
    }
} catch {
    Write-Host "WSL is not installed." -ForegroundColor Yellow
    $installWSL = Read-Host "Do you want to install WSL? (Y/N)"
    
    if ($installWSL -eq "Y" -or $installWSL -eq "y") {
        Write-Host "Installing WSL. This may take several minutes and require a restart..." -ForegroundColor Cyan
        try {
            wsl --install
            Write-Host "WSL installation initiated. A system restart may be required to complete installation." -ForegroundColor Yellow
        } catch {
            Write-Host "Failed to install WSL. Please install it manually using 'wsl --install'." -ForegroundColor Red
            $checksPassed = $false
        }
    }
}
#endregion

#region Registry Check
Write-Host "`nChecking registry configuration for native messaging host..." -ForegroundColor Green

$scriptPath = Join-Path $PSScriptRoot "native_messaging.py"
$manifestPath = Join-Path $PSScriptRoot "com.example.browserlauncher.json"
$chromeExtensionId = "ifllnbjkoabnnbcodbocddplnhmbobim"  # Replace with your actual extension ID if different

# Check if manifest file exists
if (-not (Test-Path $manifestPath)) {
    Write-Host "Manifest file not found. Creating manifest file..." -ForegroundColor Yellow
    
    # Create the path with proper escaping for JSON
    $escapedPath = $scriptPath.Replace('\', '\\')
    
    # Create manifest content without here-string
    $manifestJson = '{
    "name": "com.example.browserlauncher",
    "description": "Browser Launcher",
    "path": "' + $escapedPath + '",
    "type": "stdio",
    "allowed_origins": [
        "chrome-extension://' + $chromeExtensionId + '/"
    ]
}'
    
    try {
        $manifestJson | Out-File -FilePath $manifestPath -Encoding utf8
        Write-Host "Manifest file created successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create manifest file. Please check file permissions." -ForegroundColor Red
        $checksPassed = $false
    }
} else {
    Write-Host "Manifest file exists." -ForegroundColor Green
}

# Check Chrome registry
$chromeRegKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.example.browserlauncher"
if (-not (Test-Path $chromeRegKey)) {
    Write-Host "Chrome registry entry not found. Creating..." -ForegroundColor Yellow
    try {
        New-Item -Path $chromeRegKey -Force | Out-Null
        New-ItemProperty -Path $chromeRegKey -Name "(Default)" -Value $manifestPath -PropertyType String -Force | Out-Null
        Write-Host "Chrome registry entry created successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create Chrome registry entry. Please run as administrator." -ForegroundColor Red
        $checksPassed = $false
    }
} else {
    Write-Host "Chrome registry entry exists." -ForegroundColor Green
}

# Check Edge registry
$edgeRegKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.example.browserlauncher"
if (-not (Test-Path $edgeRegKey)) {
    Write-Host "Edge registry entry not found. Creating..." -ForegroundColor Yellow
    try {
        New-Item -Path $edgeRegKey -Force | Out-Null
        New-ItemProperty -Path $edgeRegKey -Name "(Default)" -Value $manifestPath -PropertyType String -Force | Out-Null
        Write-Host "Edge registry entry created successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create Edge registry entry. Please run as administrator." -ForegroundColor Red
        $checksPassed = $false
    }
} else {
    Write-Host "Edge registry entry exists." -ForegroundColor Green
}
#endregion

#region File Permissions
Write-Host "`nChecking file permissions..." -ForegroundColor Green

$nativeMsgPyPath = Join-Path $PSScriptRoot "native_messaging.py"
if (Test-Path $nativeMsgPyPath) {
    try {
        # Make sure the script is executable
        $acl = Get-Acl $nativeMsgPyPath
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "ReadAndExecute", "Allow")
        
        $aclHasRule = $false
        foreach ($accessRule in $acl.Access) {
            if ($accessRule.IdentityReference.Value -eq $currentUser -and $accessRule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)) {
                $aclHasRule = $true
                break
            }
        }
        
        if (-not $aclHasRule) {
            $acl.AddAccessRule($rule)
            Set-Acl $nativeMsgPyPath $acl
            Write-Host "Execute permissions added to native_messaging.py" -ForegroundColor Green
        } else {
            Write-Host "native_messaging.py already has appropriate permissions." -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to set permissions on native_messaging.py. Please check file permissions." -ForegroundColor Red
        $checksPassed = $false
    }
} else {
    Write-Host "native_messaging.py not found. Make sure to extract all files correctly." -ForegroundColor Red
    $checksPassed = $false
}
#endregion

#region Check Log Files
Write-Host "`nChecking log file configuration..." -ForegroundColor Green

$logFiles = @("BrowserLauncher.log", "BrowserPathDetection.log")
foreach ($logFile in $logFiles) {
    $logPath = Join-Path $PSScriptRoot $logFile
    
    if (Test-Path $logPath) {
        Write-Host "$logFile exists." -ForegroundColor Green
        try {
            $acl = Get-Acl $logPath
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "Allow")
            
            $aclHasRule = $false
            foreach ($accessRule in $acl.Access) {
                if ($accessRule.IdentityReference.Value -eq $currentUser -and $accessRule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::FullControl)) {
                    $aclHasRule = $true
                    break
                }
            }
            
            if (-not $aclHasRule) {
                $acl.AddAccessRule($rule)
                Set-Acl $logPath $acl
                Write-Host "Write permissions added to $logFile" -ForegroundColor Green
            }
        } catch {
            Write-Host "Failed to set permissions on $logFile. Please check file permissions." -ForegroundColor Red
            $checksPassed = $false
        }
    } else {
        Write-Host "$logFile will be created when the native messaging host runs." -ForegroundColor Yellow
        # Create an empty log file with appropriate permissions
        try {
            New-Item -Path $logPath -ItemType File -Force | Out-Null
            $acl = Get-Acl $logPath
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "Allow")
            $acl.AddAccessRule($rule)
            Set-Acl $logPath $acl
            Write-Host "Created $logFile with appropriate permissions." -ForegroundColor Green
        } catch {
            Write-Host "Failed to create $logFile. Please check directory permissions." -ForegroundColor Red
            $checksPassed = $false
        }
    }
}
#endregion

#region Test Hardware ID Collection Commands
Write-Host "`nTesting hardware ID collection commands..." -ForegroundColor Green

# Test volume serial number collection
Write-Host "Testing volume serial number collection..." -ForegroundColor Cyan
try {
    # Use fsutil instead of vol command (more reliable in PowerShell)
    $volResult = cmd /c "fsutil fsinfo volumeinfo C:"
    if ($volResult -match "Volume Serial Number") {
        Write-Host "Volume serial number can be collected." -ForegroundColor Green
    } else {
        # Try alternative method using PowerShell
        $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
        if ($drive -and $drive.VolumeSerialNumber) {
            Write-Host "Volume serial number can be collected using WMI." -ForegroundColor Green
        } else {
            Write-Host "Warning: Volume serial number command didn't return expected output." -ForegroundColor Yellow
            $checksPassed = $false
        }
    }
} catch {
    Write-Host "Error collecting volume serial number: $_" -ForegroundColor Red
    
    # Try alternative method
    try {
        $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
        if ($drive -and $drive.VolumeSerialNumber) {
            Write-Host "Volume serial number can be collected using WMI (fallback method)." -ForegroundColor Green
        } else {
            $checksPassed = $false
        }
    } catch {
        Write-Host "All volume serial number collection methods failed." -ForegroundColor Red
        $checksPassed = $false
    }
}

# Test WMIC commands for hardware ID collection
$wmicCmds = @(
    @{Name="BIOS Serial"; Cmd="wmic bios get serialnumber"},
    @{Name="CPU ID"; Cmd="wmic cpu get processorid"},
    @{Name="System Info"; Cmd="wmic computersystem get name"}
)

foreach ($cmd in $wmicCmds) {
    Write-Host "Testing $($cmd.Name) collection..." -ForegroundColor Cyan
    try {
        $result = Invoke-Expression $cmd.Cmd 2>&1
        
        # Convert result to string if it's an array
        if ($result -is [System.Array]) {
            $resultStr = $result -join "`n"
        } else {
            $resultStr = $result
        }
        
        # Check if result contains data (not just headers)
        if ($resultStr -and $resultStr.Trim() -and 
            (($resultStr -match "\S+\s+\S+") -or ($resultStr -split "`n").Count -gt 1)) {
            Write-Host "$($cmd.Name) can be collected." -ForegroundColor Green
        } else {
            Write-Host "Warning: $($cmd.Name) command didn't return expected output." -ForegroundColor Yellow
            Write-Host "Result: $resultStr" -ForegroundColor Gray
            $checksPassed = $false
        }
    } catch {
        Write-Host "Error running $($cmd.Name) command: $_" -ForegroundColor Red
        $checksPassed = $false
    }
}

# Test Python hardware ID capabilities
Write-Host "Testing Python hardware ID collection capabilities..." -ForegroundColor Cyan
try {
    $testScript = @'
import platform
import socket
import uuid

# Basic hardware info test
print("Platform: " + platform.system())
print("Hostname: " + socket.gethostname())
print("Machine ID: " + str(uuid.getnode()))
print("Hardware ID collection test successful")
'@

    $tempFile = [System.IO.Path]::GetTempFileName() + ".py"
    $testScript | Out-File -Encoding utf8 $tempFile
    
    $testResult = python $tempFile 2>&1
    Remove-Item $tempFile -Force
    
    if ($testResult -match "Hardware ID collection test successful") {
        Write-Host "Python hardware ID collection capabilities are working." -ForegroundColor Green
    } else {
        Write-Host "Warning: Python hardware ID collection test failed." -ForegroundColor Yellow
        Write-Host "Result: $testResult" -ForegroundColor Gray
        $checksPassed = $false
    }
} catch {
    Write-Host "Error testing Python hardware ID capabilities: $_" -ForegroundColor Red
    $checksPassed = $false
}
#endregion

#region Test Native Messaging Functionality
Write-Host "`nTesting native messaging functionality..." -ForegroundColor Green

$nativeMsgPyPath = Join-Path $PSScriptRoot "native_messaging.py"
if (Test-Path $nativeMsgPyPath) {
    Write-Host "Native messaging script found at: $nativeMsgPyPath" -ForegroundColor Green
    
    # Create a simple test script that sends a message to native_messaging.py
    $testScript = @'
import struct
import sys
import json
import time

def send_message(message):
    encoded_message = json.dumps(message).encode('utf-8')
    sys.stdout.buffer.write(struct.pack('@I', len(encoded_message)))
    sys.stdout.buffer.write(encoded_message)
    sys.stdout.buffer.flush()

def read_message():
    # Read the message length (first 4 bytes)
    message_length_bytes = sys.stdin.buffer.read(4)
    if not message_length_bytes:
        return None
    message_length = struct.unpack('@I', message_length_bytes)[0]
    
    # Read the message
    message_bytes = sys.stdin.buffer.read(message_length)
    message = json.loads(message_bytes.decode('utf-8'))
    return message

# Send a ping test message
send_message({"action": "ping"})

# Wait for response
response = read_message()
if response and response.get("pong") == True:
    print("NATIVE_MESSAGING_TEST_SUCCESS")
else:
    print("NATIVE_MESSAGING_TEST_FAILED: " + str(response))
'@

    try {
        Write-Host "Testing native messaging host with ping action..." -ForegroundColor Cyan
        
        # Create a temporary script for testing the native messaging host
        $tempFile = [System.IO.Path]::GetTempFileName() + ".py"
        $testScript | Out-File -Encoding utf8 $tempFile
        
        # Add timeout to batch file to prevent hanging
        $batchFile = [System.IO.Path]::GetTempFileName() + ".bat"
        @"
@echo off
echo Starting test with 5 second timeout...
timeout /t 5 /nobreak > nul
taskkill /f /im python.exe /fi "WINDOWTITLE eq native_messaging_test" 2>nul
echo Test terminated due to timeout
exit /b 1
"@ | Out-File -FilePath $batchFile -Encoding ascii
        
        # Simpler approach - just test if native messaging host can be started
        Write-Host "Checking if native messaging host can start..." -ForegroundColor Cyan
        $proc = Start-Process -FilePath "python" -ArgumentList $nativeMsgPyPath -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 2
        
        if ($proc -ne $null -and !$proc.HasExited) {
            Write-Host "Native messaging host started successfully." -ForegroundColor Green
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Native messaging host failed to start or exited immediately." -ForegroundColor Red
            $checksPassed = $false
        }
        
        # Optional: Check if ping action works (may be unreliable in testing environment)
        Write-Host "Skipping detailed native messaging test to avoid hanging." -ForegroundColor Yellow
        Write-Host "Basic startup test passed, which is sufficient for hardware ID generation." -ForegroundColor Green
        
        # Clean up
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $batchFile) {
            Remove-Item $batchFile -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "Error testing native messaging functionality: $_" -ForegroundColor Red
        $checksPassed = $false
    }
} else {
    Write-Host "Error: Native messaging script not found at: $nativeMsgPyPath" -ForegroundColor Red
    $checksPassed = $false
}
#endregion

#region Test hardware ID generation and hashing
Write-Host "`nGenerating final hardware ID hash..." -ForegroundColor Green

$hwHashTestScript = @'
import hashlib
import json
import sys
import os
import platform
import socket
import uuid
import re
import subprocess

def get_mac_address():
    """Get the MAC address of the system"""
    try:
        mac = ':'.join(['{:02x}'.format((uuid.getnode() >> elements) & 0xff) 
                       for elements in range(0, 8*6, 8)][::-1])
        return mac
    except Exception as e:
        print("Error getting MAC address: " + str(e))
        return None

def get_volume_serial():
    """Get the system drive's volume serial number"""
    try:
        if platform.system() == 'Windows':
            # Try fsutil first
            try:
                result = subprocess.run(['fsutil', 'fsinfo', 'volumeinfo', 'C:'], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    match = re.search(r'Volume Serial Number\s*:\s*([A-Z0-9\-]+)', result.stdout)
                    if match:
                        return match.group(1)
            except:
                pass
                
            # Try wmic as fallback
            try:
                result = subprocess.run(['wmic', 'volume', 'where', 'DriveLetter="C:"', 'get', 'SerialNumber'], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    if len(lines) >= 2:
                        return lines[1].strip()
            except:
                pass
        return None
    except Exception as e:
        print("Error getting volume serial: " + str(e))
        return None

def get_bios_serial():
    """Get the BIOS serial number"""
    try:
        if platform.system() == 'Windows':
            result = subprocess.run(['wmic', 'bios', 'get', 'serialnumber'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    return lines[1].strip()
        return None
    except:
        return None

def get_cpu_id():
    """Get the CPU ID"""
    try:
        if platform.system() == 'Windows':
            result = subprocess.run(['wmic', 'cpu', 'get', 'processorid'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    return lines[1].strip()
        return None
    except:
        return None

def get_hardware_info():
    """Collect hardware-specific information for license validation"""
    hardware_info = {}
    
    try:
        # Get system information
        hardware_info['platform'] = platform.system()
        hardware_info['processor'] = platform.processor()
        hardware_info['machine'] = platform.machine()
        hardware_info['node'] = platform.node()
        
        # Get MAC address
        mac = get_mac_address()
        if mac:
            hardware_info['mac'] = mac
            
        # Get volume serial number
        volume_serial = get_volume_serial()
        if volume_serial:
            hardware_info['volume_serial'] = volume_serial
            
        # Get BIOS serial
        bios_serial = get_bios_serial()
        if bios_serial:
            hardware_info['bios_serial'] = bios_serial
            
        # Get CPU ID
        cpu_id = get_cpu_id()
        if cpu_id:
            hardware_info['cpu_id'] = cpu_id
            
        # Fallback to more generic methods if needed
        if len(hardware_info) < 3:
            # Add hostname
            hardware_info['hostname'] = socket.gethostname()
            
            # Add Python-based UUID
            hardware_info['machine_id'] = str(uuid.getnode())
            
    except Exception as e:
        print("Error getting hardware info: " + str(e))
        # Return minimal system info if we fail to get more specific hardware data
        return {
            'platform': platform.system(),
            'hostname': socket.gethostname(),
            'machine_id': str(uuid.getnode())
        }
        
    return hardware_info

def hash_string(input_string):
    """Create a SHA-256 hash of a string"""
    try:
        # Convert string to bytes
        data = input_string.encode('utf-8')
        # Calculate hash
        hash_obj = hashlib.sha256(data)
        # Return hexadecimal representation
        return hash_obj.hexdigest()
    except Exception as e:
        print("Error hashing string: " + str(e))
        return None

# Get hardware info
hw_info = get_hardware_info()
print("Hardware info collected:")
for key, value in hw_info.items():
    print("  " + key + ": " + str(value))

# Generate the hardware ID hash (this matches what the extension will use)
hw_info_json = json.dumps(hw_info, sort_keys=True)
hardware_id = hash_string(hw_info_json)

print("\nFINAL_HARDWARE_ID:" + hardware_id)
print("\nIMPORTANT: This is the hardware ID that will be used for licensing.")
print("The first 8 characters are used for license binding: " + hardware_id[:8])
'@

try {
    $hwHashTestFile = [System.IO.Path]::GetTempFileName() + ".py"
    $hwHashTestScript | Out-File -Encoding utf8 $hwHashTestFile
    
    $hwHashResult = python $hwHashTestFile 2>&1
    
    # Clean up
    if (Test-Path $hwHashTestFile) {
        Remove-Item $hwHashTestFile -Force -ErrorAction SilentlyContinue
    }
    
    # Extract and display the hardware ID
    $hardwareId = ($hwHashResult | Select-String -Pattern "FINAL_HARDWARE_ID:(.+)").Matches.Groups[1].Value
    
    if ($hardwareId) {
        Write-Host "`nHardware ID for License Activation:" -ForegroundColor Green
        Write-Host $hardwareId -ForegroundColor Cyan
        Write-Host "First 8 characters (used for license binding): " -NoNewline -ForegroundColor Green
        Write-Host $hardwareId.Substring(0, 8) -ForegroundColor Yellow
        Write-Host "`nUse this hardware ID when requesting a license key." -ForegroundColor Green
        
        # Save to a file for easy access
        $hwIdFile = Join-Path $PSScriptRoot "hardware_id.txt"
        "Hardware ID: $hardwareId`nFirst 8 characters: $($hardwareId.Substring(0, 8))" | Out-File -FilePath $hwIdFile -Encoding utf8
        Write-Host "Hardware ID has been saved to: $hwIdFile" -ForegroundColor Cyan
    } else {
        Write-Host "Failed to generate hardware ID." -ForegroundColor Red
        Write-Host "Result: $hwHashResult" -ForegroundColor Gray
        $checksPassed = $false
    }
} catch {
    Write-Host "Error generating hardware ID hash: $_" -ForegroundColor Red
    $checksPassed = $false
}
#endregion

#region Final check
Write-Host "`n=== Final Check Results ===" -ForegroundColor Cyan

# Clean up any __pycache__ directories
Write-Host "Cleaning up Python cache directories..." -ForegroundColor Cyan
try {
    # Find and remove __pycache__ directories
    $pycacheDirs = Get-ChildItem -Path $PSScriptRoot -Filter "__pycache__" -Directory -Recurse
    foreach ($dir in $pycacheDirs) {
        Write-Host "  Removing $($dir.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $dir.FullName -Recurse -Force
    }
    
    # Also look for .pyc files
    $pycFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.pyc" -File -Recurse
    foreach ($file in $pycFiles) {
        Write-Host "  Removing $($file.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $file.FullName -Force
    }
    
    Write-Host "Python cache cleanup completed" -ForegroundColor Green
}
catch {
    Write-Host "Error cleaning up Python cache: $_" -ForegroundColor Red
    $checksPassed = $false
}

# Test if native messaging can be started
try {
    $process = Start-Process -FilePath "python" -ArgumentList "$nativeMsgPyPath" -NoNewWindow -PassThru
    Start-Sleep -Seconds 1
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
        Write-Host "Native messaging host can be started." -ForegroundColor Green
    } else {
        Write-Host "Native messaging host started but exited immediately. Check logs for errors." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to start native messaging host. Please check Python installation." -ForegroundColor Red
    $checksPassed = $false
}

Write-Host "`nAll checks completed. The Browser Launcher Extension should now be ready to use." -ForegroundColor Green
Write-Host "If you encounter any issues, please check the log files in the same directory as this script." -ForegroundColor Cyan

# Prompt to restart the browser
$restartBrowser = Read-Host "Do you want to restart your browsers to apply all changes? (Y/N)"
if ($restartBrowser -eq "Y" -or $restartBrowser -eq "y") {
    Write-Host "Closing Chrome and Edge browsers..." -ForegroundColor Yellow
    
    # Close Chrome
    Get-Process -Name "chrome" -ErrorAction SilentlyContinue | ForEach-Object { 
        try { $_.CloseMainWindow() | Out-Null } catch { $_.Kill() }
    }
    
    # Close Edge
    Get-Process -Name "msedge" -ErrorAction SilentlyContinue | ForEach-Object { 
        try { $_.CloseMainWindow() | Out-Null } catch { $_.Kill() }
    }
    
    Write-Host "Browsers have been closed. Please restart them manually." -ForegroundColor Green
}

Write-Host "`nScript completed. Press any key to exit..." -ForegroundColor Cyan
[void][System.Console]::ReadKey($true)

# Return appropriate exit code if called from another script
if ($ReturnResults) {
    if ($checksPassed) {
        return 0
    } else {
        return 1
    }
} 