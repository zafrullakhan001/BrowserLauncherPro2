# Clean-PythonCache.ps1
# This script cleans up Python cache files that can cause issues with Chrome/Edge extensions

Write-Host "=== Browser Launcher Cache Cleanup Tool ===" -ForegroundColor Cyan
Write-Host "This tool will remove Python bytecode cache directories (__pycache__) that may cause"
Write-Host "errors when loading the Browser Launcher extension in Chrome or Edge." -ForegroundColor Yellow
Write-Host

# Get script directory
$SCRIPT_DIR = $PSScriptRoot
if (-not (Test-Path $SCRIPT_DIR)) {
    Write-Error "Error: Script directory does not exist."
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

Write-Host "Searching for Python cache directories in: $SCRIPT_DIR" -ForegroundColor Green

# Find and remove __pycache__ directories
$pycacheDirs = Get-ChildItem -Path $SCRIPT_DIR -Filter "__pycache__" -Directory -Recurse
$pycacheCount = $pycacheDirs.Count

if ($pycacheCount -gt 0) {
    Write-Host "Found $pycacheCount __pycache__ directories to remove:" -ForegroundColor Yellow
    
    foreach ($dir in $pycacheDirs) {
        Write-Host "  Removing $($dir.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $dir.FullName -Recurse -Force
    }
} else {
    Write-Host "No __pycache__ directories found." -ForegroundColor Green
}

# Also look for .pyc files
$pycFiles = Get-ChildItem -Path $SCRIPT_DIR -Filter "*.pyc" -File -Recurse
$pycCount = $pycFiles.Count

if ($pycCount -gt 0) {
    Write-Host "Found $pycCount .pyc files to remove:" -ForegroundColor Yellow
    
    foreach ($file in $pycFiles) {
        Write-Host "  Removing $($file.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $file.FullName -Force
    }
} else {
    Write-Host "No .pyc files found." -ForegroundColor Green
}

# Modify native_messaging.py to prevent future __pycache__ creation if needed
$nativeMsgPyPath = Join-Path $SCRIPT_DIR "native_messaging.py"
if (Test-Path $nativeMsgPyPath) {
    $content = Get-Content -Path $nativeMsgPyPath -Raw
    
    if (-not $content.Contains("sys.dont_write_bytecode = True")) {
        Write-Host "Modifying native_messaging.py to prevent __pycache__ creation..." -ForegroundColor Yellow
        
        $newContent = $content -replace "import sys", "import sys`nsys.dont_write_bytecode = True"
        
        # Check if we actually made a change (import sys might be on a different line)
        if ($newContent -eq $content) {
            # Try a different approach - add after shebang line
            $newContent = $content -replace "#!/usr/bin/env python3", "#!/usr/bin/env python3`n`n# Disable creation of __pycache__ directories`nimport sys`nsys.dont_write_bytecode = True"
        }
        
        # Write the modified content back
        Set-Content -Path $nativeMsgPyPath -Value $newContent
        Write-Host "Successfully updated native_messaging.py" -ForegroundColor Green
    } else {
        Write-Host "native_messaging.py already configured to prevent __pycache__ creation." -ForegroundColor Green
    }
} else {
    Write-Host "Warning: native_messaging.py not found at $nativeMsgPyPath" -ForegroundColor Red
}

Write-Host "`nCleanup completed!" -ForegroundColor Green
Write-Host "To fix the extension error:" -ForegroundColor Cyan
Write-Host "1. Go to your browser's extension page (chrome://extensions or edge://extensions)"
Write-Host "2. Disable and then re-enable the Browser Launcher extension"
Write-Host "3. If problems persist, uninstall and reinstall the extension"
Write-Host "4. Make sure to run the Install-BrowserLauncher.ps1 script after reinstalling"

Read-Host -Prompt "`nPress Enter to exit" 