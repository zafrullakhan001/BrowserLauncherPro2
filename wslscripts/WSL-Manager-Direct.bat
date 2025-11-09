@echo off
echo.
echo ================================================================
echo   WSL Instance Manager - Enhanced Edition (Direct Launch)
echo ================================================================
echo.
echo IMPORTANT: For WSL installation, this script needs to run as Administrator.
echo.
echo If you're not running as Administrator:
echo   1. Right-click on this batch file
echo   2. Select "Run as administrator"
echo   3. Approve the UAC prompt
echo.
echo Current status checking...

:: Check if running as admin
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [NOT ADMIN] You are NOT running as administrator
    echo.
    echo Please close this window and:
    echo   1. Right-click on WSL-Manager-Direct.bat
    echo   2. Select "Run as administrator" 
    echo   3. Approve the UAC prompt when it appears
    echo.
    pause
    exit /b 1
) else (
    echo [ADMIN OK] You are running as administrator - ready to proceed!
)

echo.
echo Starting WSL Instance Manager...
echo.

:: Set execution policy and run the PowerShell script directly
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force"

:: Run the enhanced PowerShell script directly
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-WSLInstance-Fixed.ps1" -CreateInstance

echo.
echo WSL Instance Manager completed.
echo.
pause