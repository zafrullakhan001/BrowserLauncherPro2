# Elevate to admin privileges if not already running as admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as Administrator! Attempting to elevate..."
    try {
        $arguments = "& '" + $myinvocation.mycommand.definition + "'"
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
        exit
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "Failed to elevate privileges: $($_.Exception.Message)"
        Write-ColorOutput -ForegroundColor Yellow -Message "Please run this script as Administrator manually."
        exit
    }
}

function Write-ColorOutput {
    param (
        [Parameter(Mandatory=$true)]
        [ConsoleColor]$ForegroundColor,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    try {
        $fc = $host.UI.RawUI.ForegroundColor
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
        Write-Output $Message
        $host.UI.RawUI.ForegroundColor = $fc
    }
    catch {
        Write-Output $Message  # Fallback to normal output if color change fails
    }
}

function Test-RegistryPermissions {
    param (
        [Parameter(Mandatory=$true)]
        [string]$RegistryPath
    )
    try {
        $null = Get-Item -LiteralPath $RegistryPath -ErrorAction Stop
        return $true
    }
    catch {
        Write-ColorOutput -ForegroundColor Yellow -Message "Registry path access failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-PythonInstallation {
    Write-Host "`n=== Checking Python Installation ===" -ForegroundColor Cyan
    try {
        $pythonVersion = python -c "import sys; print(sys.version)" 2>$null
        if ($pythonVersion) {
            Write-ColorOutput -ForegroundColor Green -Message "✓ Python is installed: $pythonVersion"
            
            # Check pip installation
            $pipVersion = python -m pip --version 2>$null
            if ($pipVersion) {
                Write-ColorOutput -ForegroundColor Green -Message "✓ Pip is installed: $pipVersion"
                
                # Check required modules
                $requiredModules = @("ujson", "psutil", "configparser")
                foreach ($module in $requiredModules) {
                    $null = python -c "import $module" 2>$null
                    if ($?) {
                        Write-ColorOutput -ForegroundColor Green -Message "✓ Module $module is installed"
                    } 
                    else {
                        Write-ColorOutput -ForegroundColor Red -Message "✗ Module $module is missing"
                    }
                }
            } 
            else {
                Write-ColorOutput -ForegroundColor Red -Message "✗ Pip is not installed"
            }
        } 
        else {
            Write-ColorOutput -ForegroundColor Red -Message "✗ Python installation appears to be corrupted"
        }
    } 
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Python is not installed or not in PATH"
    }
}

function Test-BrowserInstallations {
    Write-Host "`n=== Checking Browser Installations ===" -ForegroundColor Cyan
    try {
        $browsers = @{
            "Edge Stable"   = @{
                "Path" = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
                "Version" = $null
            }
            "Chrome Stable" = @{
                "Path" = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
                "Version" = $null
            }
            "Firefox" = @{
                "Path" = "${env:ProgramFiles}\Mozilla Firefox\firefox.exe"
                "Version" = $null
            }
        }

        foreach ($browser in $browsers.GetEnumerator()) {
            Write-Host "`nChecking $($browser.Key):" -ForegroundColor Yellow
            if (Test-Path -Path $browser.Value.Path -ErrorAction SilentlyContinue) {
                Write-ColorOutput -ForegroundColor Green -Message "✓ Found: $($browser.Value.Path)"
                
                # Try to get version information
                try {
                    $version = (Get-Item $browser.Value.Path).VersionInfo.FileVersion
                    Write-ColorOutput -ForegroundColor Green -Message "  Version: $version"
                }
                catch {
                    Write-ColorOutput -ForegroundColor Yellow -Message "  Could not determine version"
                }
            } 
            else {
                Write-ColorOutput -ForegroundColor Red -Message "✗ Not found: $($browser.Value.Path)"
            }
        }
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Error checking browser installations: $($_.Exception.Message)"
    }
}

function Test-WSLSupport {
    Write-Host "`n=== Checking WSL Support ===" -ForegroundColor Cyan
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction Stop
        if ($wslFeature.State -eq "Enabled") {
            Write-ColorOutput -ForegroundColor Green -Message "✓ WSL is enabled"
        } 
        else {
            Write-ColorOutput -ForegroundColor Red -Message "✗ WSL is not enabled"
        }
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Error checking WSL: $($_.Exception.Message)"
    }
}

function Test-WindowsSandbox {
    Write-Host "`n=== Checking Windows Sandbox Support ===" -ForegroundColor Cyan
    try {
        # Check both possible feature names for Windows Sandbox
        $sandboxFeatures = @(
            "Containers-DisposableClientVM",
            "Microsoft-Windows-Sandbox"
        )
        
        $sandboxEnabled = $false
        foreach ($feature in $sandboxFeatures) {
            $sandboxFeature = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
            if ($sandboxFeature -and $sandboxFeature.State -eq "Enabled") {
                $sandboxEnabled = $true
                break
            }
        }
        
        if ($sandboxEnabled) {
            Write-ColorOutput -ForegroundColor Green -Message "✓ Windows Sandbox is enabled"
        } 
        else {
            Write-ColorOutput -ForegroundColor Red -Message "✗ Windows Sandbox is not enabled"
        }
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Error checking Windows Sandbox support: $($_.Exception.Message)"
    }
}

function Test-ExtensionPrerequisites {
    Write-Host "`n=== Checking Extension Prerequisites ===" -ForegroundColor Cyan
    try {
        $registryPaths = @(
            "HKCU:\Software\Google\Chrome\NativeMessagingHosts",
            "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts",
            "HKCU:\Software\Mozilla\NativeMessagingHosts"
        )

        foreach ($path in $registryPaths) {
            if (Test-RegistryPermissions $path) {
                Write-ColorOutput -ForegroundColor Green -Message "✓ Registry permissions OK for: $path"
            } 
            else {
                Write-ColorOutput -ForegroundColor Red -Message "✗ Missing registry permissions for: $path"
            }
        }

        # Check required files with more detailed error messages
        $currentDir = Get-Location
        Write-Host "`nChecking files in directory: $currentDir" -ForegroundColor Yellow
        
        $requiredFiles = @(
            @{
                "Name" = "native_messaging.py"
                "Description" = "Native messaging host script"
            },
            @{
                "Name" = "com.example.browserlauncher.json"
                "Description" = "Native messaging manifest"
            },
            @{
                "Name" = "manifest.json"
                "Description" = "Browser extension manifest"
            }
        )

        foreach ($file in $requiredFiles) {
            $filePath = Join-Path -Path $currentDir -ChildPath $file.Name
            Write-Host "Checking file: $filePath" -ForegroundColor Gray
            
            # Try multiple path variations
            $found = $false
            $searchPaths = @(
                $filePath,
                (Join-Path -Path $currentDir -ChildPath "src\$($file.Name)"),
                (Join-Path -Path $currentDir -ChildPath "extension\$($file.Name)")
            )
            
            foreach ($searchPath in $searchPaths) {
                if (Test-Path -Path $searchPath -ErrorAction SilentlyContinue) {
                    Write-ColorOutput -ForegroundColor Green -Message "✓ Required file exists: $($file.Name) ($($file.Description))"
                    Write-ColorOutput -ForegroundColor Green -Message "  Location: $searchPath"
                    $found = $true
                    break
                }
            }
            
            if (-not $found) {
                Write-ColorOutput -ForegroundColor Red -Message "✗ Missing required file: $($file.Name) ($($file.Description))"
                Write-ColorOutput -ForegroundColor Yellow -Message "  Searched in:"
                foreach ($searchPath in $searchPaths) {
                    Write-ColorOutput -ForegroundColor Yellow -Message "    - $searchPath"
                }
            }
        }
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Error checking extension prerequisites: $($_.Exception.Message)"
        Write-ColorOutput -ForegroundColor Red -Message "Stack trace: $($_.ScriptStackTrace)"
    }
}

function Show-Summary {
    Write-Host "`n=== System Requirements Summary ===" -ForegroundColor Cyan
    try {
        Write-Host "CPU Architecture: $([System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE'))"
        Write-Host "OS Version: $([System.Environment]::OSVersion.Version)"
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion.ToString())"
        
        # Get RAM information with better error handling
        try {
            $ram = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            if ($ram.TotalPhysicalMemory) {
                # Convert to GB using a different method to avoid 32-bit precision issues
                $ramBytes = [decimal]$ram.TotalPhysicalMemory
                $ramGB = [math]::Round($ramBytes / 1073741824, 2)  # 1024^3
                Write-Host "Total RAM: $ramGB GB"
            } else {
                Write-Host "Total RAM: Unable to determine"
            }
        }
        catch {
            Write-Host "Total RAM: Unable to determine"
        }
        
        # Get disk space with better error handling
        try {
            $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
            if ($disk.FreeSpace) {
                # Convert to GB using a different method to avoid 32-bit precision issues
                $freeSpaceBytes = [decimal]$disk.FreeSpace
                $freeSpaceGB = [math]::Round($freeSpaceBytes / 1073741824, 2)  # 1024^3
                Write-Host "Available Disk Space: $freeSpaceGB GB"
            } else {
                Write-Host "Available Disk Space: Unable to determine"
            }
        }
        catch {
            Write-Host "Available Disk Space: Unable to determine"
        }
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Error getting system info: $($_.Exception.Message)"
    }
}

# Run all checks
Clear-Host
Write-Host "=== Browser Launcher Extension Pre-Check Tool ===" -ForegroundColor Yellow
Write-Host "Running comprehensive system checks...`n"

try {
    $checks = @(
        @{ Name = "Python Installation"; Function = ${function:Test-PythonInstallation} },
        @{ Name = "Browser Installations"; Function = ${function:Test-BrowserInstallations} },
        @{ Name = "WSL Support"; Function = ${function:Test-WSLSupport} },
        @{ Name = "Windows Sandbox"; Function = ${function:Test-WindowsSandbox} },
        @{ Name = "Extension Prerequisites"; Function = ${function:Test-ExtensionPrerequisites} },
        @{ Name = "System Summary"; Function = ${function:Show-Summary} }
    )

    foreach ($check in $checks) {
        Write-Host "`nRunning $($check.Name) check..." -ForegroundColor Cyan
        & $check.Function
    }

    Write-Host "`nPre-check completed. Please review any items marked with ✗ before proceeding." -ForegroundColor Yellow
}
catch {
    Write-ColorOutput -ForegroundColor Red -Message "✗ Critical error during checks: $($_.Exception.Message)"
    Write-ColorOutput -ForegroundColor Red -Message "Stack trace: $($_.ScriptStackTrace)"
}

# Check and fix native messaging host registration in registry
function Fix-NativeMessagingHostRegistration {
    Write-Host "`n=== Checking Native Messaging Host Registration ===" -ForegroundColor Cyan
    
    $extensionId = "com.example.browserlauncher"
    $currentDir = Get-Location
    $manifestPath = Join-Path -Path $currentDir -ChildPath "$extensionId.json"
    
    # Check if manifest exists
    if (-not (Test-Path $manifestPath)) {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Native messaging host manifest not found at: $manifestPath"
        return
    }
    
    # Create or update registry entries for Chrome and Edge
    $browsers = @(
        @{
            Name = "Chrome"
            RegistryPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$extensionId"
        },
        @{
            Name = "Edge"
            RegistryPath = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$extensionId"
        }
    )
    
    foreach ($browser in $browsers) {
        Write-Host "Checking registration for $($browser.Name)..." -ForegroundColor Yellow
        
        # Check if registry path exists
        if (-not (Test-Path $browser.RegistryPath)) {
            # Create the registry key
            try {
                New-Item -Path $browser.RegistryPath -Force | Out-Null
                Write-ColorOutput -ForegroundColor Green -Message "✓ Created registry key: $($browser.RegistryPath)"
            }
            catch {
                Write-ColorOutput -ForegroundColor Red -Message "✗ Failed to create registry key: $($browser.RegistryPath)"
                Write-ColorOutput -ForegroundColor Red -Message "Error: $($_.Exception.Message)"
                continue
            }
        }
        
        # Set the manifest path
        try {
            Set-ItemProperty -Path $browser.RegistryPath -Name "(Default)" -Value $manifestPath
            Write-ColorOutput -ForegroundColor Green -Message "✓ Updated registry value for $($browser.Name)"
        }
        catch {
            Write-ColorOutput -ForegroundColor Red -Message "✗ Failed to set registry value for $($browser.Name)"
            Write-ColorOutput -ForegroundColor Red -Message "Error: $($_.Exception.Message)"
        }
    }
}

# Check and set executable permissions for Python script
function Fix-PythonScriptPermissions {
    Write-Host "`n=== Checking Python Script Permissions ===" -ForegroundColor Cyan
    
    $pythonScript = Join-Path -Path (Get-Location) -ChildPath "native_messaging.py"
    
    if (-not (Test-Path $pythonScript)) {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Python script not found at: $pythonScript"
        return
    }
    
    try {
        # Ensure the script is executable
        $acl = Get-Acl $pythonScript
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl $pythonScript $acl
        
        Write-ColorOutput -ForegroundColor Green -Message "✓ Permissions set correctly for: $pythonScript"
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Failed to set permissions on Python script"
        Write-ColorOutput -ForegroundColor Red -Message "Error: $($_.Exception.Message)"
    }
}

# Test launching the native messaging host directly
function Test-NativeMessagingHost {
    Write-Host "`n=== Testing Native Messaging Host ===" -ForegroundColor Cyan
    
    $pythonScript = Join-Path -Path (Get-Location) -ChildPath "native_messaging.py"
    
    if (-not (Test-Path $pythonScript)) {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Python script not found at: $pythonScript"
        return
    }
    
    try {
        # Test running the Python script
        $result = & python $pythonScript 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput -ForegroundColor Green -Message "✓ Native messaging host script executed successfully"
        }
        else {
            Write-ColorOutput -ForegroundColor Red -Message "✗ Failed to execute native messaging host script"
            Write-ColorOutput -ForegroundColor Red -Message "Error: $result"
        }
    }
    catch {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Exception occurred while testing native messaging host"
        Write-ColorOutput -ForegroundColor Red -Message "Error: $($_.Exception.Message)"
    }
}

# Main function to fix all issues
function Fix-AllBrowserLauncherIssues {
    Write-Host "=== Browser Launcher Diagnostic and Repair Tool ===" -ForegroundColor Cyan
    Write-Host "This script will diagnose and attempt to fix common issues with the Browser Launcher extension." -ForegroundColor White
    
    # Check if the script is running as Administrator
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ColorOutput -ForegroundColor Red -Message "✗ Script is not running with Administrative privileges."
        return
    }
    
    # Fix native messaging host registration
    Fix-NativeMessagingHostRegistration
    
    # Fix Python script permissions
    Fix-PythonScriptPermissions
    
    # Test native messaging host
    Test-NativeMessagingHost
    
    Write-Host "`n=== Diagnostics and Repairs Completed ===" -ForegroundColor Cyan
    Write-Host "Please restart your browser and try the extension again." -ForegroundColor Yellow
}

# Run the fix all function
Fix-AllBrowserLauncherIssues
