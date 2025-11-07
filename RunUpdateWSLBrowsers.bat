@echo off
echo WSL Browser Updater
echo =================
echo.
echo This tool will update all browser variants (stable, beta, dev, unstable) in your WSL distributions.

:: Check for administrative rights and elevate if needed
powershell.exe -Command "if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Start-Process -FilePath '%~dpnx0' -Verb RunAs; exit }" 

:: Only continue if we have admin rights
powershell.exe -Command "if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 exit /b

:: Check if WSL is installed
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo WSL is not installed on this system.
    echo.
    echo To install WSL, run the following commands in an administrator PowerShell window:
    echo   1. Enable WSL feature: wsl --install
    echo   2. Install Ubuntu: wsl --install -d Ubuntu
    echo   3. After installation completes, restart your computer
    echo   4. Once WSL is set up, install browsers using the WSL tab in the extension
    echo.
    pause
    exit /b
)

:: List available WSL distributions
echo Available WSL distributions:
wsl --list

echo.
:: Prompt for WSL distribution name
set /p wsl_distro=Enter the name of your WSL distribution (e.g., Ubuntu): 

:: Verify the distribution exists
wsl -d %wsl_distro% -e echo "Testing connection..." >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Could not connect to WSL distribution '%wsl_distro%'.
    echo Please check the name and try again.
    pause
    exit /b 1
)

echo.
echo Updating browsers in %wsl_distro%...
echo This will update all browser variants (stable, beta, dev, unstable) if installed.
echo.
echo Note: The script will attempt to fix common repository issues automatically.
echo If you encounter persistent errors, you might need to manually fix repository issues.
echo.

:: Create a temporary directory in the WSL distribution
wsl -d %wsl_distro% -e mkdir -p /tmp/browser-updater

:: Copy the update script directly to WSL
echo Copying update script to WSL...
powershell.exe -Command "Get-Content -Path '%~dp0wslscripts\update-wsl-browsers.sh' -Raw | ForEach-Object { $_ -replace \"`r`n\", \"`n\" } | Set-Content -Path '%TEMP%\update-wsl-browsers.sh' -Encoding ASCII -NoNewline"

:: Create the script in WSL and make it executable
wsl -d %wsl_distro% -e cp /mnt/c/Users/%USERNAME%/AppData/Local/Temp/update-wsl-browsers.sh /tmp/browser-updater/update-wsl-browsers.sh
wsl -d %wsl_distro% -e chmod +x /tmp/browser-updater/update-wsl-browsers.sh
wsl -d %wsl_distro% -e dos2unix /tmp/browser-updater/update-wsl-browsers.sh 2>/dev/null || echo "Note: dos2unix not installed. If you experience line ending issues, please install it with: sudo apt-get install dos2unix"

:: Run the update script
echo Running browser update script...
wsl -d %wsl_distro% -e /tmp/browser-updater/update-wsl-browsers.sh

:: Clean up
wsl -d %wsl_distro% -e rm -f /tmp/browser-updater/update-wsl-browsers.sh
del /q "%TEMP%\update-wsl-browsers.sh" >nul 2>&1

echo.
echo WSL Browser update process finished.
echo.
echo If you encountered repository errors, you may need to manually fix them:
echo 1. Open WSL terminal for %wsl_distro%: wsl -d %wsl_distro%
echo 2. Run the following commands:
echo    sudo rm -f /etc/apt/sources.list.d/google-chrome-beta.list
echo    sudo rm -f /etc/apt/sources.list.d/google-chrome-unstable.list
echo    sudo rm -f /etc/apt/sources.list.d/microsoft-edge-beta.list
echo    sudo rm -f /etc/apt/sources.list.d/microsoft-edge-dev.list
echo    sudo rm -f /etc/apt/sources.list.d/opera.list
echo    sudo apt-get update
echo.
pause 