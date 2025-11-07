# PowerShell Script to Fix Edge Developer Extensions Retention Issue
# Run as Administrator

# Stop Microsoft Edge forcefully
Write-Host "Stopping Microsoft Edge..." -ForegroundColor Cyan
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue

# Create/Modify Registry Keys to Enable Developer Mode and Allow Extensions
$registryPath = "HKCU:\Software\Policies\Microsoft\Edge"
$policyKeys = @(
    @{
        Path  = "$registryPath"
        Name  = "ExtensionDeveloperMode"
        Type  = "DWord"
        Value = 1
    },
    @{
        Path  = "$registryPath\ExtensionInstallAllowList"
        Name  = "1"
        Type  = "String"
        Value = "*"
    },
    @{
        Path  = "$registryPath\ExtensionInstallSources"
        Name  = "1"
        Type  = "String"
        Value = "file:///*"
    },
    @{
        Path  = "$registryPath\ExtensionInstallSources"
        Name  = "2"
        Type  = "String"
        Value = "http://*/*"
    },
    @{
        Path  = "$registryPath\ExtensionInstallSources"
        Name  = "3"
        Type  = "String"
        Value = "https://*/*"
    }
)

foreach ($key in $policyKeys) {
    if (-not (Test-Path $key.Path)) {
        New-Item -Path $key.Path -Force | Out-Null
    }
    New-ItemProperty -Path $key.Path -Name $key.Name -PropertyType $key.Type -Value $key.Value -Force | Out-Null
}

# Clear Edge Extensions Cache
$edgeExtensionsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
if (Test-Path $edgeExtensionsPath) {
    Write-Host "Clearing Edge extensions cache..." -ForegroundColor Cyan
    Remove-Item -Path $edgeExtensionsPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Restart Edge
Write-Host "Restarting Microsoft Edge..." -ForegroundColor Cyan
Start-Process "msedge"

# Verify Changes
Write-Host "`nDone! Check Edge settings:" -ForegroundColor Green
Write-Host "1. Go to edge://extensions and ensure Developer Mode is ON."
Write-Host "2. Visit edge://policy to confirm policies are applied."