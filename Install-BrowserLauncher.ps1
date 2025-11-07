#Requires -Version 5.1

<#
.SYNOPSIS
    Installs the Browser Launcher native messaging host for Chrome and Edge.

.DESCRIPTION
    This script installs the Browser Launcher native messaging host for Chrome and Edge browsers.
    It creates the necessary registry entries and manifest file required for the extension to
    communicate with the native messaging host.

.NOTES
    Author: Browser Launcher Team
    Version: 1.0
#>

# Self-elevate if not already running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Self-elevate the script if not running as administrator
if (-not (Test-Admin)) {
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

# Script constants
$CHROME_EXTENSION_ID = "ifllnbjkoabnnbcodbocddplnhmbobim"
$HOST_NAME = "com.example.browserlauncher"

# Get script directory
$SCRIPT_DIR = $PSScriptRoot
if (-not (Test-Path $SCRIPT_DIR)) {
    Write-Error "Error: Script directory does not exist."
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

# Set paths
$SCRIPT_PATH = Join-Path $SCRIPT_DIR "native_messaging.py"
$MANIFEST_PATH = Join-Path $SCRIPT_DIR "$HOST_NAME.json"
$EXTENSION_MANIFEST_PATH = Join-Path $SCRIPT_DIR "manifest.json"
$LOG_PATH = Join-Path $SCRIPT_DIR "install_log.txt"
$DEPENDENCIES_CHECK_SCRIPT = Join-Path $SCRIPT_DIR "CheckDependencies.ps1"

# Create or clear log file
"Install started at $(Get-Date)" | Out-File -FilePath $LOG_PATH

function Write-LogMessage {
    param([string]$Message)
    
    Write-Host $Message
    "$(Get-Date): $Message" | Out-File -FilePath $LOG_PATH -Append
}

# Run dependency check script first
if (Test-Path $DEPENDENCIES_CHECK_SCRIPT) {
    Write-Host "`n=== Running dependency checks before installation ===" -ForegroundColor Cyan
    Write-LogMessage "Running dependency checks using CheckDependencies.ps1"
    
    try {
        # Run the dependencies check script
        $dependencyCheckResult = & $DEPENDENCIES_CHECK_SCRIPT -ReturnResults
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nDependency checks failed. Please fix the issues before continuing with installation." -ForegroundColor Red
            Write-LogMessage "Dependency checks failed with exit code $LASTEXITCODE"
            Read-Host -Prompt "Press Enter to exit"
            exit 1
        }
        
        Write-Host "`nDependency checks completed successfully. Proceeding with installation." -ForegroundColor Green
        Write-LogMessage "Dependency checks completed successfully"
    }
    catch {
        Write-Host "`nError running dependency checks: $_" -ForegroundColor Red
        Write-LogMessage "Error running dependency checks: $_"
        $continueAnyway = Read-Host -Prompt "Do you want to continue with installation anyway? (Y/N)"
        
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-Host "Installation aborted by user after dependency check failure." -ForegroundColor Yellow
            Write-LogMessage "Installation aborted by user after dependency check failure"
            exit 1
        }
        
        Write-Host "Continuing with installation despite dependency check failure..." -ForegroundColor Yellow
        Write-LogMessage "Continuing with installation despite dependency check failure"
    }
} else {
    Write-Host "Dependency check script not found at $DEPENDENCIES_CHECK_SCRIPT" -ForegroundColor Yellow
    Write-LogMessage "Dependency check script not found at $DEPENDENCIES_CHECK_SCRIPT"
    $continueAnyway = Read-Host -Prompt "Dependency check script not found. Continue anyway? (Y/N)"
    
    if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
        Write-Host "Installation aborted by user." -ForegroundColor Yellow
        Write-LogMessage "Installation aborted by user due to missing dependency check script"
        exit 1
    }
}

function Test-PythonInstallation {
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match 'Python (\d+)\.(\d+)\.(\d+)') {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            
            if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 7)) {
                Write-LogMessage "Python 3.7+ is required. Found: $pythonVersion"
                return $false
            }
            
            Write-LogMessage "Python version check passed: $pythonVersion"
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Install-PythonIfNeeded {
    if (-not (Test-PythonInstallation)) {
        Write-LogMessage "Python 3.7+ is not installed. Installing Python..."
        
        try {
            # Download Python installer
            $pythonUrl = "https://www.python.org/ftp/python/3.11.4/python-3.11.4-amd64.exe"
            $installerPath = Join-Path $env:TEMP "python-installer.exe"
            
            Write-LogMessage "Downloading Python installer from $pythonUrl"
            Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath
            
            # Install Python
            Write-LogMessage "Running Python installer..."
            Start-Process -FilePath $installerPath -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
            
            # Verify installation
            if (Test-PythonInstallation) {
                Write-LogMessage "Python installed successfully."
            } else {
                Write-LogMessage "Failed to install Python automatically."
                Write-LogMessage "Please install Python 3.7+ manually from https://www.python.org and run this script again."
                Read-Host -Prompt "Press Enter to exit"
                exit 1
            }
        }
        catch {
            Write-LogMessage "Error during Python installation: $_"
            Write-LogMessage "Please install Python 3.7+ manually from https://www.python.org and run this script again."
            Read-Host -Prompt "Press Enter to exit"
            exit 1
        }
    }
}

function Install-PythonDependencies {
    Write-LogMessage "Installing required Python modules..."
    
    try {
        python -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage "Failed to upgrade pip. Error code: $LASTEXITCODE"
            return $false
        }
        
        python -m pip install --upgrade ujson psutil configparser
        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage "Failed to install required Python modules. Error code: $LASTEXITCODE"
            return $false
        }
        
        Write-LogMessage "Python dependencies installed successfully."
        return $true
    }
    catch {
        Write-LogMessage "Error during dependency installation: $_"
        return $false
    }
}

function Get-ExtensionManifestInfo {
    Write-LogMessage "Reading extension manifest file..."
    
    # Check if manifest exists, if not try to create it
    if (-not (Test-Path $EXTENSION_MANIFEST_PATH)) {
        Write-LogMessage "Extension manifest file not found. Creating a new one..."
        if (-not (New-ExtensionManifest)) {
            Write-LogMessage "Failed to create extension manifest. Using default values."
        }
    }
    
    try {
        if (Test-Path $EXTENSION_MANIFEST_PATH) {
            # Read the extension manifest.json
            $extensionManifestContent = Get-Content -Path $EXTENSION_MANIFEST_PATH -Raw
            
            # Convert to object for easier property access
            $extensionManifestObj = $extensionManifestContent | ConvertFrom-Json
            
            # Extract key information
            $extensionInfo = @{
                Name = $extensionManifestObj.name
                Description = $extensionManifestObj.description
                Version = $extensionManifestObj.version
                Key = $extensionManifestObj.key
                RawContent = $extensionManifestContent
            }
            
            Write-LogMessage "Extension manifest read successfully"
            if ($extensionInfo.Key) {
                Write-LogMessage "Found extension key in manifest.json"
            }
            return $extensionInfo
        } else {
            Write-LogMessage "Warning: Extension manifest file not found at $EXTENSION_MANIFEST_PATH"
            return @{
                Name = "Browser Launcher Pro"
                Description = "Browser Launcher Native Messaging Host"
                Version = "1.0"
                Key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmzDTNZRajd5KPfP0DVmZGpeVW6CkkpWs2dyAWgyu9/oNFeJlzo492M0xwxkFISYHrSF0lWzENsoMs2yI/N7Qdk6eCLAc5pMSKfniERdVU3aUw+1o6U5fdxJuW5EZeujQRigwE+Ij86LLQuspk8XU2bK35QVOYZrg6ABUFDE023mSJh8Jvw9Sg7eWscS8vH7mwbT5n3MKMyRgHTecZLYeYRr+uEK8zmJeOCq8/LxncPXYqVeNQRBQj/0Oz/qttVXDv0JnGa68xVB4HBbvDT2wVMH3SERALA7C+6EhuFKAd1QNw+7qmkNF91I8/nkuUW2+3/dDG4mRnHOKmfcmo9WF3wIDAQAB"
                RawContent = $null
            }
        }
    }
    catch {
        Write-LogMessage "Error reading extension manifest: $_"
        return @{
            Name = "Browser Launcher Pro"
            Description = "Browser Launcher Native Messaging Host"
            Version = "1.0"
            Key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmzDTNZRajd5KPfP0DVmZGpeVW6CkkpWs2dyAWgyu9/oNFeJlzo492M0xwxkFISYHrSF0lWzENsoMs2yI/N7Qdk6eCLAc5pMSKfniERdVU3aUw+1o6U5fdxJuW5EZeujQRigwE+Ij86LLQuspk8XU2bK35QVOYZrg6ABUFDE023mSJh8Jvw9Sg7eWscS8vH7mwbT5n3MKMyRgHTecZLYeYRr+uEK8zmJeOCq8/LxncPXYqVeNQRBQj/0Oz/qttVXDv0JnGa68xVB4HBbvDT2wVMH3SERALA7C+6EhuFKAd1QNw+7qmkNF91I8/nkuUW2+3/dDG4mRnHOKmfcmo9WF3wIDAQAB"
            RawContent = $null
        }
    }
}

function New-ManifestFile {
    Write-LogMessage "Creating native messaging host manifest file..."
    
    # Get information from extension manifest
    $extensionInfo = Get-ExtensionManifestInfo
    
    # Ensure script path has double backslashes for JSON
    $escapedScriptPath = $SCRIPT_PATH -replace '\\', '\\'
    
    # Create the base manifest content
    $manifestObj = [ordered]@{
        name = $HOST_NAME
        description = $extensionInfo.Description
        path = $escapedScriptPath
        type = "stdio"
        allowed_origins = @(
            "chrome-extension://$CHROME_EXTENSION_ID/"
        )
    }
    
    # Add key if available in the extension manifest (preserving exact format)
    if ($extensionInfo.Key) {
        Write-LogMessage "Adding extension key to native messaging host manifest"
        $manifestObj["key"] = $extensionInfo.Key
    }
    
    # Convert to pretty JSON (depth of 10 ensures all nested objects are included)
    $manifestJson = $manifestObj | ConvertTo-Json -Depth 10
    
    try {
        $manifestJson | Out-File -FilePath $MANIFEST_PATH -Encoding utf8
        if (Test-Path $MANIFEST_PATH) {
            Write-LogMessage "Manifest file created successfully at $MANIFEST_PATH"
            # Verify the key was preserved correctly
            if ($extensionInfo.Key) {
                $createdManifest = Get-Content -Path $MANIFEST_PATH -Raw | ConvertFrom-Json
                if ($createdManifest.key -eq $extensionInfo.Key) {
                    Write-LogMessage "Extension key was correctly preserved in the native messaging host manifest"
                } else {
                    Write-LogMessage "Warning: Extension key may not have been preserved correctly"
                }
            }
            return $true
        } else {
            Write-LogMessage "Failed to create manifest file at $MANIFEST_PATH"
            return $false
        }
    }
    catch {
        Write-LogMessage "Error creating manifest file: $_"
        return $false
    }
}

function Set-RegistryEntries {
    Write-LogMessage "Setting registry entries for Chrome and Edge..."
    
    $chromeKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HOST_NAME"
    $edgeKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME"
    $edgeKeyMachine = "HKLM:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME"
    
    # Extension ID from manifest
    $extensionInfo = Get-ExtensionManifestInfo
    $edgeExtensionKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    $edgeExtensionsKey = "HKLM:\SOFTWARE\Microsoft\Edge\Extensions\$CHROME_EXTENSION_ID"
    
    try {
        # Create Chrome registry entry
        if (!(Test-Path (Split-Path $chromeKey -Parent))) {
            New-Item -Path (Split-Path $chromeKey -Parent) -Force | Out-Null
        }
        if (!(Test-Path $chromeKey)) {
            New-Item -Path $chromeKey -Force | Out-Null
        }
        Set-ItemProperty -Path $chromeKey -Name "(Default)" -Value $MANIFEST_PATH
        Write-LogMessage "Chrome registry entry created at $chromeKey"
        
        # Create Edge registry entry (User level)
        if (!(Test-Path (Split-Path $edgeKey -Parent))) {
            New-Item -Path (Split-Path $edgeKey -Parent) -Force | Out-Null
        }
        if (!(Test-Path $edgeKey)) {
            New-Item -Path $edgeKey -Force | Out-Null
        }
        Set-ItemProperty -Path $edgeKey -Name "(Default)" -Value $MANIFEST_PATH
        Write-LogMessage "Edge registry entry created at $edgeKey (user level)"
        
        # Create Edge registry entry (Machine level)
        try {
            if (!(Test-Path (Split-Path $edgeKeyMachine -Parent))) {
                New-Item -Path (Split-Path $edgeKeyMachine -Parent) -Force | Out-Null
            }
            if (!(Test-Path $edgeKeyMachine)) {
                New-Item -Path $edgeKeyMachine -Force | Out-Null
            }
            Set-ItemProperty -Path $edgeKeyMachine -Name "(Default)" -Value $MANIFEST_PATH
            Write-LogMessage "Edge registry entry created at $edgeKeyMachine (machine level)"
        }
        catch {
            Write-LogMessage "Error setting machine-level Edge registry: $_. This requires administrator privileges."
        }
        
        # Create direct Edge extension entry (more reliable than policies)
        try {
            if (!(Test-Path (Split-Path $edgeExtensionsKey -Parent))) {
                New-Item -Path (Split-Path $edgeExtensionsKey -Parent) -Force | Out-Null
            }
            if (!(Test-Path $edgeExtensionsKey)) {
                New-Item -Path $edgeExtensionsKey -Force | Out-Null
            }
            
            # Add extension metadata
            Set-ItemProperty -Path $edgeExtensionsKey -Name "path" -Value $SCRIPT_DIR -Type String
            Set-ItemProperty -Path $edgeExtensionsKey -Name "version" -Value $extensionInfo.Version -Type String
            Set-ItemProperty -Path $edgeExtensionsKey -Name "manifest" -Value $extensionInfo.RawContent -Type String
            
            Write-LogMessage "Edge extension direct registry entry created at $edgeExtensionsKey"
        }
        catch {
            Write-LogMessage "Error setting Edge extension registry: $_. This requires administrator privileges."
        }
        
        # Create Edge extension persistence policy via Group Policy
        try {
            if (!(Test-Path (Split-Path $edgeExtensionKey -Parent))) {
                New-Item -Path (Split-Path $edgeExtensionKey -Parent) -Force | Out-Null
            }
            if (!(Test-Path $edgeExtensionKey)) {
                New-Item -Path $edgeExtensionKey -Force | Out-Null
            }
            
            # Add Edge extension to force install list with update URL format
            $extensionValue = "1:$CHROME_EXTENSION_ID;https://edge.microsoft.com/extensionwebstorebase/v1/crx"
            Set-ItemProperty -Path $edgeExtensionKey -Name "1" -Value $extensionValue -Type String
            
            # Also create user-level policy (as fallback)
            $userPolicyKey = "HKCU:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
            if (!(Test-Path (Split-Path $userPolicyKey -Parent))) {
                New-Item -Path (Split-Path $userPolicyKey -Parent) -Force | Out-Null
            }
            if (!(Test-Path $userPolicyKey)) {
                New-Item -Path $userPolicyKey -Force | Out-Null
            }
            Set-ItemProperty -Path $userPolicyKey -Name "1" -Value $extensionValue -Type String
            
            Write-LogMessage "Edge extension persistence policies created"
        }
        catch {
            Write-LogMessage "Error setting Edge extension persistence policy: $_. This requires administrator privileges."
            Write-LogMessage "The extension may be removed when Edge restarts. Try running this script as administrator."
        }
        
        return $true
    }
    catch {
        Write-LogMessage "Error setting registry entries: $_"
        return $false
    }
}

function Test-ScriptExists {
    # Check for native_messaging.py
    if (-not (Test-Path $SCRIPT_PATH)) {
        Write-LogMessage "Error: Python script not found at $SCRIPT_PATH"
        return $false
    }
    Write-LogMessage "Python script found at $SCRIPT_PATH"
    return $true
}

function Test-Prerequisites {
    # Check if running on Windows 10 or 11
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $osVersion = [System.Environment]::OSVersion.Version
    
    if ($osVersion.Major -lt 10) {
        Write-LogMessage "Warning: This script is designed for Windows 10/11. It may not work correctly on your system (Version: $($osInfo.Caption))."
    } else {
        Write-LogMessage "OS Version check passed: $($osInfo.Caption) (Version: $($osVersion.Major).$($osVersion.Build))"
    }
    
    return $true
}

function Test-Installation {
    $success = $true
    
    # Check manifest file
    if (-not (Test-Path $MANIFEST_PATH)) {
        Write-LogMessage "Verification failed: Manifest file not found at $MANIFEST_PATH"
        $success = $false
    }
    
    # Check Chrome registry
    $chromeKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HOST_NAME"
    if (-not (Test-Path $chromeKey)) {
        Write-LogMessage "Verification failed: Chrome registry key not found"
        $success = $false
    } else {
        $value = (Get-ItemProperty -Path $chromeKey).'(Default)'
        if ($value -ne $MANIFEST_PATH) {
            Write-LogMessage "Verification failed: Chrome registry value incorrect. Expected: $MANIFEST_PATH, Actual: $value"
            $success = $false
        }
    }
    
    # Check Edge registry (user level)
    $edgeKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME"
    if (-not (Test-Path $edgeKey)) {
        Write-LogMessage "Verification failed: Edge user-level registry key not found"
        $success = $false
    } else {
        $value = (Get-ItemProperty -Path $edgeKey).'(Default)'
        if ($value -ne $MANIFEST_PATH) {
            Write-LogMessage "Verification failed: Edge registry value incorrect. Expected: $MANIFEST_PATH, Actual: $value"
            $success = $false
        }
    }
    
    # Check Edge registry (machine level)
    $edgeKeyMachine = "HKLM:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME"
    if (Test-Path $edgeKeyMachine) {
        $value = (Get-ItemProperty -Path $edgeKeyMachine).'(Default)'
        if ($value -ne $MANIFEST_PATH) {
            Write-LogMessage "Warning: Edge machine-level registry value incorrect. Expected: $MANIFEST_PATH, Actual: $value"
        } else {
            Write-LogMessage "Edge machine-level registry verified."
        }
    } else {
        Write-LogMessage "Info: Edge machine-level registry key not found. This is optional but recommended."
    }
    
    # Check Edge direct extension registry
    $edgeExtensionsKey = "HKLM:\SOFTWARE\Microsoft\Edge\Extensions\$CHROME_EXTENSION_ID"
    if (Test-Path $edgeExtensionsKey) {
        $path = (Get-ItemProperty -Path $edgeExtensionsKey -Name "path" -ErrorAction SilentlyContinue)."path"
        if ($path -ne $SCRIPT_DIR) {
            Write-LogMessage "Warning: Edge extension registry path incorrect. Expected: $SCRIPT_DIR, Actual: $path"
        } else {
            Write-LogMessage "Edge extension direct registry verified."
        }
    } else {
        Write-LogMessage "Info: Edge extension direct registry key not found. This requires admin privileges."
    }
    
    # Check Edge extension persistence policy
    $edgeExtensionKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    if (Test-Path $edgeExtensionKey) {
        $extensionValue = "1:$CHROME_EXTENSION_ID;https://edge.microsoft.com/extensionwebstorebase/v1/crx"
        $value = (Get-ItemProperty -Path $edgeExtensionKey -Name "1" -ErrorAction SilentlyContinue)."1"
        if ($value -ne $extensionValue) {
            Write-LogMessage "Warning: Edge extension persistence policy not set correctly. This requires admin privileges."
            Write-LogMessage "The extension may be removed when Edge restarts. Try running this script as administrator."
        } else {
            Write-LogMessage "Edge extension persistence policy verified."
        }
    } else {
        Write-LogMessage "Warning: Edge extension persistence policy not found. This requires admin privileges."
        Write-LogMessage "The extension may be removed when Edge restarts. Try running this script as administrator."
    }
    
    if ($success) {
        Write-LogMessage "Installation verification passed!"
    }
    
    return $success
}

function New-ExtensionManifest {
    Write-LogMessage "Creating or overwriting extension manifest.json file..."
    
    # Define the extension manifest content
    $extensionManifestObj = [ordered]@{
        manifest_version = 3
        name = "Browser Launcher Pro"
        description = "Launch the apps in the multiple browsers with ease. Features include browser update tracking, WSL Linux integration, and quick search across multiple searchengines."
        version = "2.0"
        author = "Browser Launcher"
        homepage_url = "https://browserlauncher.pro"
        permissions = @(
            "contextMenus",
            "nativeMessaging",
            "activeTab",
            "scripting",
            "storage",
            "notifications",
            "alarms"
        )
        background = @{
            service_worker = "background.js"
        }
        action = @{
            default_popup = "popup.html"
            default_title = "Browser Launcher Pro"
            default_icon = @{
                "16" = "icons/icon16.png"
                "32" = "icons/icon32.png"
                "48" = "icons/icon48.png"
                "128" = "icons/icon128.png"
            }
        }
        content_security_policy = @{
            extension_pages = "script-src 'self'; object-src 'self'"
        }
        icons = @{
            "16" = "icons/icon16.png"
            "32" = "icons/icon32.png"
            "48" = "icons/icon48.png"
            "128" = "icons/icon128.png"
        }
        key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmzDTNZRajd5KPfP0DVmZGpeVW6CkkpWs2dyAWgyu9/oNFeJlzo492M0xwxkFISYHrSF0lWzENsoMs2yI/N7Qdk6eCLAc5pMSKfniERdVU3aUw+1o6U5fdxJuW5EZeujQRigwE+Ij86LLQuspk8XU2bK35QVOYZrg6ABUFDE023mSJh8Jvw9Sg7eWscS8vH7mwbT5n3MKMyRgHTecZLYeYRr+uEK8zmJeOCq8/LxncPXYqVeNQRBQj/0Oz/qttVXDv0JnGa68xVB4HBbvDT2wVMH3SERALA7C+6EhuFKAd1QNw+7qmkNF91I8/nkuUW2+3/dDG4mRnHOKmfcmo9WF3wIDAQAB"
        content_scripts = @(
            @{
                matches = @("<all_urls>")
                js = @("content.js")
            }
        )
        commands = @{
            "open-youtube-search" = @{
                suggested_key = @{
                    default = "Ctrl+Y"
                }
                description = "Open YouTube search for the selected text"
            }
            "open-youtube-incognito" = @{
                suggested_key = @{
                    default = "Ctrl+Shift+Z"
                }
                description = "Open YouTube search in incognito mode for the selected text"
            }
        }
    }
    
    # Convert to pretty JSON with proper formatting
    $extensionManifestJson = $extensionManifestObj | ConvertTo-Json -Depth 10
    
    try {
        # Write the manifest file
        $extensionManifestJson | Out-File -FilePath $EXTENSION_MANIFEST_PATH -Encoding utf8 -Force
        
        if (Test-Path $EXTENSION_MANIFEST_PATH) {
            Write-LogMessage "Extension manifest.json created/updated successfully at $EXTENSION_MANIFEST_PATH"
            return $true
        } else {
            Write-LogMessage "Failed to create extension manifest.json at $EXTENSION_MANIFEST_PATH"
            return $false
        }
    }
    catch {
        Write-LogMessage "Error creating extension manifest.json: $_"
        return $false
    }
}

function Reset-EdgeRegistry {
    Write-LogMessage "Resetting Edge registry entries before installation..."
    
    # Define keys to reset
    $edgeKeys = @(
        "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME",
        "HKLM:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME",
        "HKLM:\SOFTWARE\Microsoft\Edge\Extensions\$CHROME_EXTENSION_ID",
        "HKCU:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist",
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    )
    
    # Try to remove each key
    foreach ($key in $edgeKeys) {
        try {
            if (Test-Path $key) {
                Remove-Item -Path $key -Recurse -Force
                Write-LogMessage "Successfully removed registry key: $key"
            }
        }
        catch {
            Write-LogMessage "Failed to remove registry key: $key. Error: $_"
        }
    }
    
    # Also try to clean Edge Extensions management area to force refresh
    try {
        $edgeExtensionsRoot = "HKCU:\Software\Microsoft\Edge\Extensions"
        if (Test-Path $edgeExtensionsRoot) {
            # Look for our extension ID
            $extensionKey = Join-Path $edgeExtensionsRoot $CHROME_EXTENSION_ID
            if (Test-Path $extensionKey) {
                Remove-Item -Path $extensionKey -Recurse -Force
                Write-LogMessage "Cleared Edge extension from user profile: $extensionKey"
            }
        }
    }
    catch {
        Write-LogMessage "Failed to clean Edge user extensions. Error: $_"
    }
    
    Write-LogMessage "Edge registry reset completed"
}

function Configure-EdgeToKeepExtensions {
    Write-LogMessage "Configuring Edge to keep extensions after restart..."
    
    # Path to Edge settings file
    $edgeLocalAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $edgeUserDataDir = Join-Path $edgeLocalAppData "Microsoft\Edge\User Data\Default"
    
    try {
        # Check if Edge is running
        $edgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
        $edgeWasRunning = $edgeProcesses -and $edgeProcesses.Count -gt 0
        
        if ($edgeWasRunning) {
            Write-LogMessage "Edge is currently running. Some settings may require a browser restart to take effect."
        }
        
        # Configure browser preferences
        $prefsFile = Join-Path $edgeUserDataDir "Preferences"
        if (Test-Path $prefsFile) {
            Write-LogMessage "Editing Edge preferences file at $prefsFile"
            
            try {
                # Read the preferences file
                $prefs = Get-Content -Path $prefsFile -Raw | ConvertFrom-Json
                
                # Configure extension settings
                if (-not $prefs.extensions) {
                    $prefs | Add-Member -NotePropertyName "extensions" -NotePropertyValue (New-Object PSObject)
                }
                
                # Set development flags to false (so Edge doesn't treat it as a dev extension)
                if (-not $prefs.extensions.settings) {
                    $prefs.extensions | Add-Member -NotePropertyName "settings" -NotePropertyValue (New-Object PSObject)
                }
                
                # Add our extension to the settings
                $extSettings = $prefs.extensions.settings
                
                # Define our extension settings
                if (-not ($extSettings | Get-Member -Name $CHROME_EXTENSION_ID)) {
                    $extSettings | Add-Member -NotePropertyName $CHROME_EXTENSION_ID -NotePropertyValue (New-Object PSObject)
                }
                
                # Configure specific settings for our extension
                $ourExt = $extSettings.$CHROME_EXTENSION_ID
                $ourExt | Add-Member -NotePropertyName "installation_mode" -NotePropertyValue "normal_installed" -Force
                $ourExt | Add-Member -NotePropertyName "path" -NotePropertyValue $SCRIPT_DIR -Force
                $ourExt | Add-Member -NotePropertyName "state" -NotePropertyValue 1 -Force
                $ourExt | Add-Member -NotePropertyName "was_installed_by_default" -NotePropertyValue $true -Force
                $ourExt | Add-Member -NotePropertyName "was_installed_by_oem" -NotePropertyValue $true -Force
                $ourExt | Add-Member -NotePropertyName "was_installed_by_policy" -NotePropertyValue $true -Force
                
                # Also disable developer mode globally
                if (-not ($prefs.extensions | Get-Member -Name "ui")) {
                    $prefs.extensions | Add-Member -NotePropertyName "ui" -NotePropertyValue (New-Object PSObject)
                }
                if (-not ($prefs.extensions.ui | Get-Member -Name "developer_mode")) {
                    $prefs.extensions.ui | Add-Member -NotePropertyName "developer_mode" -NotePropertyValue $false
                } else {
                    $prefs.extensions.ui.developer_mode = $false
                }
                
                # Save the preferences file
                $prefsJson = $prefs | ConvertTo-Json -Depth 10
                $prefsJson | Out-File -FilePath $prefsFile -Encoding utf8 -Force
                
                Write-LogMessage "Edge preferences successfully updated"
            }
            catch {
                Write-LogMessage "Error updating Edge preferences: $_"
            }
        } else {
            Write-LogMessage "Edge preferences file not found at $prefsFile"
        }
        
        # Create a secure preferences file specifically for managing extensions
        $securePrefsFile = Join-Path $edgeUserDataDir "Secure Preferences"
        if (Test-Path $securePrefsFile) {
            Write-LogMessage "Editing Edge secure preferences file"
            
            try {
                # Read the secure preferences file
                $securePrefs = Get-Content -Path $securePrefsFile -Raw | ConvertFrom-Json
                
                # Ensure the extensions section exists
                if (-not $securePrefs.extensions) {
                    $securePrefs | Add-Member -NotePropertyName "extensions" -NotePropertyValue (New-Object PSObject)
                }
                
                # Update the settings
                if (-not $securePrefs.extensions.settings) {
                    $securePrefs.extensions | Add-Member -NotePropertyName "settings" -NotePropertyValue (New-Object PSObject)
                }
                
                # Configure our extension
                $secureExtSettings = $securePrefs.extensions.settings
                if (-not ($secureExtSettings | Get-Member -Name $CHROME_EXTENSION_ID)) {
                    $secureExtSettings | Add-Member -NotePropertyName $CHROME_EXTENSION_ID -NotePropertyValue (New-Object PSObject)
                }
                
                # Set persistent installation flags
                $secureExt = $secureExtSettings.$CHROME_EXTENSION_ID
                $secureExt | Add-Member -NotePropertyName "active_permissions" -NotePropertyValue @{"api" = @("nativeMessaging")} -Force
                $secureExt | Add-Member -NotePropertyName "installation_mode" -NotePropertyValue "normal_installed" -Force
                $secureExt | Add-Member -NotePropertyName "state" -NotePropertyValue 1 -Force
                $secureExt | Add-Member -NotePropertyName "was_installed_by_default" -NotePropertyValue $true -Force
                
                # Write the secure preferences file
                $securePrefsJson = $securePrefs | ConvertTo-Json -Depth 10
                $securePrefsJson | Out-File -FilePath $securePrefsFile -Encoding utf8 -Force
                
                Write-LogMessage "Edge secure preferences successfully updated"
            }
            catch {
                Write-LogMessage "Error updating Edge secure preferences: $_"
            }
        }
        
        Write-LogMessage "Edge configuration completed"
    }
    catch {
        Write-LogMessage "Error configuring Edge to keep extensions: $_"
    }
}

function Remove-PycacheDirectories {
    Write-LogMessage "Cleaning up any __pycache__ directories..."
    
    try {
        # Find and remove __pycache__ directories in the extension folder
        $pycacheDirs = Get-ChildItem -Path $SCRIPT_DIR -Filter "__pycache__" -Directory -Recurse
        
        foreach ($dir in $pycacheDirs) {
            Write-LogMessage "Removing $($dir.FullName)"
            Remove-Item -Path $dir.FullName -Recurse -Force
        }
        
        # Also look for .pyc files
        $pycFiles = Get-ChildItem -Path $SCRIPT_DIR -Filter "*.pyc" -File -Recurse
        
        foreach ($file in $pycFiles) {
            Write-LogMessage "Removing $($file.FullName)"
            Remove-Item -Path $file.FullName -Force
        }
        
        Write-LogMessage "Cleanup of cached Python bytecode files completed"
    }
    catch {
        Write-LogMessage "Error cleaning up __pycache__ directories: $_"
    }
}

# Main installation process
try {
    Write-Host "=== Browser Launcher Native Messaging Host Setup ===" -ForegroundColor Green
    Write-LogMessage "Starting installation process..."
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-LogMessage "Failed prerequisite check."
        exit 1
    }
    
    # Check if script exists
    if (-not (Test-ScriptExists)) {
        Write-LogMessage "Required files not found."
        exit 1
    }
    
    # Reset Edge registry settings to ensure clean installation
    Reset-EdgeRegistry
    
    # Install or check for Python
    Install-PythonIfNeeded
    
    # Install Python dependencies
    if (-not (Install-PythonDependencies)) {
        Write-LogMessage "Failed to install Python dependencies."
        exit 1
    }
    
    # Create or overwrite extension manifest file
    Write-LogMessage "Setting up extension manifest file..."
    if (-not (Test-Path $EXTENSION_MANIFEST_PATH) -or $true) {  # Always create/overwrite
        if (New-ExtensionManifest) {
            Write-LogMessage "Extension manifest file created/updated successfully."
        } else {
            Write-LogMessage "Warning: Failed to create extension manifest file. Continuing with installation..."
        }
    }
    
    # Create native messaging host manifest file
    if (-not (New-ManifestFile)) {
        Write-LogMessage "Failed to create native messaging host manifest file."
        exit 1
    }
    
    # Set registry entries
    if (-not (Set-RegistryEntries)) {
        Write-LogMessage "Failed to set registry entries."
        exit 1
    }
    
    # Configure Edge browser settings directly
    Configure-EdgeToKeepExtensions
    
    # Remove __pycache__ directories
    Remove-PycacheDirectories
    
    # Verify installation
    if (Test-Installation) {
        Write-Host "`nInstallation completed successfully!" -ForegroundColor Green
        Write-Host "The Browser Launcher native messaging host has been installed." -ForegroundColor Green
        Write-LogMessage "Installation completed successfully."
    } else {
        Write-Host "`nInstallation completed with issues. Please check the log file: $LOG_PATH" -ForegroundColor Yellow
        Write-LogMessage "Installation completed with issues."
    }
}
catch {
    Write-Host "An error occurred during installation: $_" -ForegroundColor Red
    Write-LogMessage "Installation failed with error: $_"
    exit 1
}
finally {
    Write-LogMessage "Installation process finished at $(Get-Date)"
}

Read-Host -Prompt "Press Enter to exit" 