#Requires -Version 5.0
<#
.SYNOPSIS
    License Key Generator for Browser Launcher Pro
.DESCRIPTION
    Generates license keys with embedded encrypted metadata that are locked to specific hardware IDs.
    Features:
    - Hardware ID binding to prevent license sharing
    - Embedded metadata (name, email, dates, etc.)
    - Support for subscription or lifetime licenses
.EXAMPLE
    Generate a lifetime license:
    .\LicenseGenerator.ps1 -HardwareId f86774665722036dd -Name "John Doe" -Email "john@example.com"
.EXAMPLE
    Generate a subscription license:
    .\LicenseGenerator.ps1 -HardwareId f86774665722036dd -Name "Jane Doe" -Email "jane@example.com" -Type subscription -Expiry "2023-12-31"
#>

# Parse command line arguments
param(
    [Parameter(Mandatory=$true)]
    [string]$HardwareId,
    
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$true)]
    [string]$Email,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('lifetime', 'subscription')]
    [string]$Type = 'lifetime',
    
    [Parameter(Mandatory=$false)]
    [string]$PurchaseDate = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Expiry = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Output = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Salt = ""
)

# Required modules for this script
$requiredModules = @()  # Add module names if needed

# Check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check and install required modules
function Install-RequiredModules {
    param (
        [string[]]$ModuleNames
    )
    
    if (-not $ModuleNames -or $ModuleNames.Count -eq 0) {
        return $true
    }
    
    $needsAdmin = $false
    $missingModules = @()
    
    foreach ($module in $ModuleNames) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            $missingModules += $module
            $needsAdmin = $true
        }
    }
    
    if ($missingModules.Count -eq 0) {
        return $true
    }
    
    # Need to install modules, check if we're admin
    if ($needsAdmin -and -not (Test-Admin)) {
        Write-Warning "Missing required modules: $($missingModules -join ', '). Need to install with admin privileges."
        
        # Restart script with admin privileges
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            $arguments += " -$($param.Key) `"$($param.Value)`""
        }
        
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    }
    
    # Install missing modules
    foreach ($module in $missingModules) {
        Write-Host "Installing module: $module"
        Install-Module -Name $module -Force -Scope CurrentUser
        Import-Module $module -Force
    }
    
    return $true
}

# Check if administrative rights are needed based on output path
function Test-AdminRequired {
    param (
        [string]$OutputPath
    )
    
    if (-not $OutputPath) { 
        return $false 
    }
    
    # Check if output path is in a protected location
    $protectedPaths = @(
        "$env:SystemDrive\Program Files",
        "$env:SystemDrive\Program Files (x86)",
        "$env:SystemDrive\Windows"
    )
    
    foreach ($path in $protectedPaths) {
        if ($OutputPath.StartsWith($path)) {
            return $true
        }
    }
    
    return $false
}

# Check and install required modules
Install-RequiredModules -ModuleNames $requiredModules

# If admin rights required, restart with elevation
if (Test-AdminRequired -OutputPath $Output) {
    if (-not (Test-Admin)) {
        Write-Warning "Writing to the specified output path requires administrative privileges. Restarting with elevation..."
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            $arguments += " -$($param.Key) `"$($param.Value)`""
        }
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    }
}

class LicenseGenerator {
    # Generate a random salt string of specified length
    [string] GenerateSalt([int]$length = 5) {
        $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        $random = New-Object System.Random
        $result = ""
        
        for ($i = 0; $i -lt $length; $i++) {
            $result += $chars[$random.Next(0, $chars.Length)]
        }
        
        return $result
    }
    
    # Generate the key part based on hardware ID and salt
    [string] GenerateKeyPart([string]$hardwareId, [string]$salt = "") {
        # Create salt if not provided
        if (-not $salt) {
            $salt = $this.GenerateSalt(5)
        }
        
        # Take first 8 chars of hardware ID
        $hwPrefix = $hardwareId.Substring(0, [Math]::Min(8, $hardwareId.Length))
        
        # Generate a key using salt and hardware ID (20 chars total)
        $key = "$salt$hwPrefix"
        $key = $key.PadRight(20, '0').Substring(0, 20)
        
        # Format with dashes for readability
        $formattedKey = @()
        for ($i = 0; $i -lt $key.Length; $i += 4) {
            $formattedKey += $key.Substring($i, [Math]::Min(4, $key.Length - $i))
        }
        
        return $formattedKey -join '-'
    }
    
    # Simple obfuscation of license metadata using base64 encoding
    [string] ObfuscateMetadata([hashtable]$metadata) {
        # Convert metadata to JSON
        $jsonData = $metadata | ConvertTo-Json -Compress
        
        # Simple obfuscation - just use base64 encoding
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
        return [Convert]::ToBase64String($bytes)
    }
    
    # Generate a complete license key with embedded metadata
    [string] GenerateLicenseKey(
        [string]$hardwareId,
        [string]$licenseeName,
        [string]$licenseeEmail,
        [string]$licenseType = 'lifetime',
        [string]$purchaseDate = "",
        [string]$expiryDate = "",
        [string]$salt = ""
    ) {
        # Set default dates if not provided
        if (-not $purchaseDate) {
            $purchaseDate = (Get-Date).ToString("yyyy-MM-dd")
        }
        
        # Generate a salt if not provided
        if (-not $salt) {
            $salt = $this.GenerateSalt(5)
        }
        
        # Prepare metadata
        $metadata = @{
            name = $licenseeName
            email = $licenseeEmail
            hardwareId = $hardwareId
            licenseType = $licenseType
            purchaseDate = $purchaseDate
            salt = $salt
        }
        
        # Add expiry date for subscription licenses
        if ($licenseType -eq 'subscription' -and $expiryDate) {
            $metadata.expiryDate = $expiryDate
        }
        
        # Obfuscate the metadata
        $obfuscatedMetadata = $this.ObfuscateMetadata($metadata)
        
        # Generate the key part
        $keyPart = $this.GenerateKeyPart($hardwareId, $salt)
        
        # Combine to form the complete license key
        return "$keyPart#$obfuscatedMetadata"
    }
}

function Test-HardwareId {
    param (
        [string]$hardwareId
    )
    
    if (-not $hardwareId -or $hardwareId.Length -lt 8) {
        return $false
    }
    return $true
}

# Main script execution
# Validate hardware ID
if (-not (Test-HardwareId -hardwareId $HardwareId)) {
    Write-Error "Error: Hardware ID must be at least 8 characters long"
    exit 1
}

# Set dates
if (-not $PurchaseDate) {
    $PurchaseDate = (Get-Date).ToString("yyyy-MM-dd")
}

# Check that expiry date is provided for subscription licenses
if ($Type -eq 'subscription' -and -not $Expiry) {
    # Set default expiry to one year from purchase
    $purchaseDt = [datetime]::ParseExact($PurchaseDate, "yyyy-MM-dd", $null)
    $expiryDt = $purchaseDt.AddYears(1)
    $Expiry = $expiryDt.ToString("yyyy-MM-dd")
    Write-Host "No expiry date provided for subscription license. Using default: $Expiry"
}

# Generate license key
$generator = [LicenseGenerator]::new()
$licenseKey = $generator.GenerateLicenseKey(
    $HardwareId,
    $Name,
    $Email,
    $Type,
    $PurchaseDate,
    $Expiry,
    $Salt
)

# Extract metadata from the key for display
$metadataBase64 = $licenseKey.Split('#')[1]
$metadataBytes = [Convert]::FromBase64String($metadataBase64)
$metadataJson = [System.Text.Encoding]::UTF8.GetString($metadataBytes)
$metadata = $metadataJson | ConvertFrom-Json

# Output the key
if ($Output) {
    $licenseKey | Out-File -FilePath $Output -Encoding utf8
    Write-Host "License key written to $Output"
}
else {
    Write-Host "`n============ GENERATED LICENSE KEY ============"
    Write-Host $licenseKey
    Write-Host "`n============ LICENSE INFORMATION ============="
    Write-Host "Hardware ID: $HardwareId"
    Write-Host "Licensed to: $Name"
    Write-Host "Email: $Email"
    Write-Host "License type: $Type"
    Write-Host "Purchase date: $PurchaseDate"
    if ($Expiry) {
        Write-Host "Expiry date: $Expiry"
    }
    Write-Host "Salt used: $($metadata.salt)"
    Write-Host "`nIMPORTANT: This license key is bound to the specified hardware ID and cannot be used on other devices."
} 