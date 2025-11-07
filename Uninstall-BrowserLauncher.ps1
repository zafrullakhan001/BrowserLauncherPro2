#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Uninstalls the Browser Launcher native messaging host for Chrome and Edge.

.DESCRIPTION
    This script removes the Browser Launcher native messaging host installation for Chrome and Edge browsers.
    It deletes registry entries and the manifest file created during installation.

.NOTES
    Author: Browser Launcher Team
    Version: 1.0
#>

# Script constants
$HOST_NAME = "com.example.browserlauncher"

# Get script directory
$SCRIPT_DIR = $PSScriptRoot
if (-not (Test-Path $SCRIPT_DIR)) {
    Write-Error "Error: Script directory does not exist."
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

# Set paths
$MANIFEST_PATH = Join-Path $SCRIPT_DIR "$HOST_NAME.json"
$EXTENSION_MANIFEST_PATH = Join-Path $SCRIPT_DIR "manifest.json"
$LOG_PATH = Join-Path $SCRIPT_DIR "uninstall_log.txt"

# Create or clear log file
"Uninstall started at $(Get-Date)" | Out-File -FilePath $LOG_PATH

function Write-LogMessage {
    param([string]$Message)
    
    Write-Host $Message
    "$(Get-Date): $Message" | Out-File -FilePath $LOG_PATH -Append
}

function Get-ExtensionInfo {
    # Try to get info from extension manifest
    if (Test-Path $EXTENSION_MANIFEST_PATH) {
        try {
            $manifestContent = Get-Content -Path $EXTENSION_MANIFEST_PATH -Raw | ConvertFrom-Json
            return $manifestContent.name
        }
        catch {
            Write-LogMessage "Error reading extension manifest: $_"
            return "Browser Launcher Pro"
        }
    }
    
    # If we can't read the extension manifest, try the native messaging manifest
    if (Test-Path $MANIFEST_PATH) {
        try {
            $nativeManifestContent = Get-Content -Path $MANIFEST_PATH -Raw | ConvertFrom-Json
            return $nativeManifestContent.description
        }
        catch {
            Write-LogMessage "Error reading native manifest: $_"
            return "Browser Launcher Pro"
        }
    }
    
    return "Browser Launcher Pro"
}

function Remove-RegistryEntries {
    Write-LogMessage "Removing registry entries for Chrome and Edge..."
    
    $chromeKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HOST_NAME"
    $edgeKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME"
    $success = $true
    
    try {
        # Remove Chrome registry entry
        if (Test-Path $chromeKey) {
            try {
                # Check if we have access to the key
                $accessTest = Get-ItemProperty -Path $chromeKey -ErrorAction Stop
                
                # Try to remove the registry key
                Remove-Item -Path $chromeKey -Force -ErrorAction Stop
                Write-LogMessage "Chrome registry entry removed: $chromeKey"
            }
            catch [System.UnauthorizedAccessException] {
                Write-LogMessage "Access denied when removing Chrome registry key. Attempting to set permissions..."
                
                try {
                    # Try to remove using .NET Registry class
                    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree("Software\Google\Chrome\NativeMessagingHosts\$HOST_NAME", $false)
                    Write-LogMessage "Chrome registry entry removed using alternate method"
                }
                catch {
                    Write-LogMessage "Error removing Chrome registry entry: Access denied. You may need to run this script as administrator."
                    $success = $false
                }
            }
            catch {
                Write-LogMessage "Error removing Chrome registry entry: $_"
                $success = $false
            }
        } else {
            Write-LogMessage "Chrome registry entry not found: $chromeKey"
        }
        
        # Remove Edge registry entry
        if (Test-Path $edgeKey) {
            try {
                # Check if we have access to the key
                $accessTest = Get-ItemProperty -Path $edgeKey -ErrorAction Stop
                
                # Try to remove the registry key
                Remove-Item -Path $edgeKey -Force -ErrorAction Stop
                Write-LogMessage "Edge registry entry removed: $edgeKey"
            }
            catch [System.UnauthorizedAccessException] {
                Write-LogMessage "Access denied when removing Edge registry key. Attempting to set permissions..."
                
                try {
                    # Try to remove using .NET Registry class
                    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree("Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME", $false)
                    Write-LogMessage "Edge registry entry removed using alternate method"
                }
                catch {
                    Write-LogMessage "Error removing Edge registry entry: Access denied. You may need to run this script as administrator."
                    $success = $false
                }
            }
            catch {
                Write-LogMessage "Error removing Edge registry entry: $_"
                $success = $false
            }
        } else {
            Write-LogMessage "Edge registry entry not found: $edgeKey"
        }
    }
    catch {
        Write-LogMessage "Unexpected error during registry operations: $_"
        $success = $false
    }
    
    return $success
}

function Remove-ManifestFile {
    Write-LogMessage "Removing manifest file..."
    
    if (Test-Path $MANIFEST_PATH) {
        try {
            Remove-Item -Path $MANIFEST_PATH -Force -ErrorAction Stop
            Write-LogMessage "Manifest file removed: $MANIFEST_PATH"
            return $true
        }
        catch {
            Write-LogMessage "Error removing manifest file: $_"
            return $false
        }
    } else {
        Write-LogMessage "Manifest file not found: $MANIFEST_PATH"
        return $true
    }
}

function Test-Uninstallation {
    $success = $true
    
    # Check manifest file
    if (Test-Path $MANIFEST_PATH) {
        Write-LogMessage "Verification failed: Manifest file still exists at $MANIFEST_PATH"
        $success = $false
    }
    
    # Check Chrome registry
    $chromeKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HOST_NAME"
    if (Test-Path $chromeKey) {
        Write-LogMessage "Verification failed: Chrome registry key still exists"
        $success = $false
    }
    
    # Check Edge registry
    $edgeKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HOST_NAME"
    if (Test-Path $edgeKey) {
        Write-LogMessage "Verification failed: Edge registry key still exists"
        $success = $false
    }
    
    if ($success) {
        Write-LogMessage "Uninstallation verification passed!"
    }
    
    return $success
}

# Main uninstallation process
try {
    # Initialize removal flag to avoid undefined variable error
    $removeUninstallLog = $false
    
    # Get extension name for better user experience
    $extensionName = Get-ExtensionInfo
    
    Write-Host "=== $extensionName Native Messaging Host Uninstaller ===" -ForegroundColor Green
    Write-LogMessage "Starting uninstallation process for $extensionName..."
    
    # Ask for confirmation
    $confirmation = Read-Host "Are you sure you want to uninstall the $extensionName native messaging host? (Y/N)"
    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
        Write-LogMessage "Uninstallation cancelled by user."
        exit 0
    }
    
    # Remove registry entries
    $registrySuccess = Remove-RegistryEntries
    
    # Remove manifest file
    $manifestSuccess = Remove-ManifestFile
    
    # Ask if user wants to keep the extension manifest file
    if (Test-Path $EXTENSION_MANIFEST_PATH) {
        $keepExtensionManifest = Read-Host "Do you want to keep the extension manifest.json file? (Y/N)"
        if ($keepExtensionManifest -ne 'Y' -and $keepExtensionManifest -ne 'y') {
            try {
                Remove-Item -Path $EXTENSION_MANIFEST_PATH -Force -ErrorAction Stop
                Write-LogMessage "Extension manifest.json file removed: $EXTENSION_MANIFEST_PATH"
            }
            catch {
                Write-LogMessage "Error removing extension manifest.json file: $_"
            }
        } else {
            Write-LogMessage "Extension manifest.json file preserved as requested"
        }
    }
    
    # Verify uninstallation
    if (Test-Uninstallation) {
        Write-Host "`nUninstallation completed successfully!" -ForegroundColor Green
        Write-LogMessage "Uninstallation completed successfully."
    } else {
        Write-Host "`nUninstallation completed with issues. Please check the log file: $LOG_PATH" -ForegroundColor Yellow
        Write-LogMessage "Uninstallation completed with issues."
    }
    
    # Ask if user wants to remove Python packages
    $removePythonPackages = Read-Host "Do you want to remove the Python packages installed for $extensionName? (Y/N)"
    if ($removePythonPackages -eq 'Y' -or $removePythonPackages -eq 'y') {
        try {
            Write-LogMessage "Removing Python packages..."
            python -m pip uninstall -y ujson psutil configparser
            Write-LogMessage "Python packages removed."
        }
        catch {
            Write-LogMessage "Error removing Python packages: $_"
        }
    }
    
    # Ask if user wants to keep log files
    $keepLogs = Read-Host "Do you want to keep the installation and uninstallation log files? (Y/N)"
    if ($keepLogs -ne 'Y' -and $keepLogs -ne 'y') {
        $installLogPath = Join-Path $SCRIPT_DIR "install_log.txt"
        $uninstallLogPath = $LOG_PATH
        
        try {
            if (Test-Path $installLogPath) {
                Remove-Item -Path $installLogPath -Force -ErrorAction SilentlyContinue
                Write-LogMessage "Installation log file removed"
            }
            
            # Mark the uninstall log for removal after we finish using it
            if (Test-Path $uninstallLogPath) {
                $removeUninstallLog = $true
                Write-LogMessage "Uninstallation log file will be removed after script completion"
            }
        }
        catch {
            Write-LogMessage "Error removing log files: $_"
        }
    }
}
catch {
    Write-Host "An error occurred during uninstallation: $_" -ForegroundColor Red
    Write-LogMessage "Uninstallation failed with error: $_"
    exit 1
}
finally {
    Write-LogMessage "Uninstallation process finished at $(Get-Date)"
    
    # Remove the uninstall log if requested
    if ($removeUninstallLog -eq $true) {
        Write-LogMessage "Removing uninstallation log file as requested"
        Start-Sleep -Seconds 1
        
        # Store the log path in a temporary variable since we'll be removing the log file
        $logFilePath = $LOG_PATH
        
        try {
            # Close any open file handles
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            
            # Remove the file
            Remove-Item -Path $logFilePath -Force -ErrorAction SilentlyContinue
        }
        catch {
            # We can't log the error since we're trying to delete the log file itself
            Write-Host "Note: Could not remove log file. It may be in use." -ForegroundColor Yellow
        }
    }
}

Write-Host "`nThank you for using Browser Launcher!" -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to exit" 