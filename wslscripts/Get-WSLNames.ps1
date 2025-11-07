param (
    [switch]$Installed,
    [switch]$Online,
    [string]$Filter = ''
)

# Default to Installed if neither is specified
if (-not ($Installed -or $Online)) {
    $Installed = $true
}

$names = @()

# Process installed distros
if ($Installed) {
    $output = cmd.exe /c "wsl.exe --list --quiet 2>nul"
    foreach ($line in $output) {
        $line = $line.Trim()
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            # Clean up any strange encodings
            $cleanName = $line -replace '[\x00-\x1F\x7F]', ''
            if (-not [string]::IsNullOrWhiteSpace($cleanName)) {
                $names += $cleanName
            }
        }
    }
}

# Process online distros
if ($Online) {
    # Try using the Store API method
    $uri = "https://store.rg-adguard.net/api/GetFiles"
    $body = @{
        type = 'ProductId'
        url  = '9NBLGGH4MSV6' # The Microsoft Store ID for WSL
        ring = 'RP'
        lang = 'en-US'
    }

    try {
        # Alternative method - use the predefined list of known distributions
        $knownDistros = @(
            'Ubuntu',
            'Ubuntu-18.04',
            'Ubuntu-20.04',
            'Ubuntu-22.04',
            'Ubuntu-24.04',
            'Ubuntu-25',
            'Debian',
            'kali-linux',
            'openSUSE-Leap-15.5',
            'openSUSE-Leap-15.6',
            'openSUSE-Tumbleweed',
            'SUSE-Linux-Enterprise-15-SP5',
            'SUSE-Linux-Enterprise-15-SP6',
            'OracleLinux_7_9',
            'OracleLinux_8_7',
            'OracleLinux_9_1',
            'AlmaLinux-8',
            'AlmaLinux-9',
            'AlmaLinux-Kitten-10',
            'fedoraremix',
            'centos',
            'Alpine'
        )
        
        foreach ($distro in $knownDistros) {
            $names += $distro
        }
    }
    catch {
        Write-Warning "Could not retrieve online distributions: $_"
    }
}

# Filter if needed (use case-insensitive regex match)
if (-not [string]::IsNullOrWhiteSpace($Filter)) {
    $pattern = "(?i:" + [regex]::Escape($Filter) + ")"
    $names = $names | Where-Object { $_ -match $pattern }
}

# Get unique values and sort
$uniqueNames = $names | Sort-Object -Unique

# Return the array instead of writing to host
return $uniqueNames 