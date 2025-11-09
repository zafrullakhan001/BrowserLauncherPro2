@echo off
echo.
echo ================================================================
echo   WSL Instance Manager - Enhanced Edition
echo ================================================================
echo.
echo This enhanced version fixes the issues with:
echo   - Progress visibility during installation
echo   - Username and password prompting
echo   - WSL installation process hanging
echo   - Error handling and user feedback
echo.
echo Choose an option:
echo   [1] Create new WSL instance (Enhanced - Recommended)
echo   [2] Test WSL functionality first
echo   [3] Show help for enhanced version
echo   [4] List installed WSL distributions
echo   [5] List available online distributions
echo   [6] Exit
echo.

set /p choice="Enter your choice [1-6]: "

if "%choice%"=="1" (
    echo.
    echo Starting Enhanced WSL Instance Creation...
    call "%~dp0Manage-WSLInstance-Enhanced.bat" -CreateInstance
) else if "%choice%"=="2" (
    echo.
    echo Testing WSL functionality...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WSL-Test-Simple.ps1" -TestList
    pause
) else if "%choice%"=="3" (
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-WSLInstance-Fixed.ps1" -Help
    pause
) else if "%choice%"=="4" (
    echo.
    echo Installed WSL Distributions:
    echo ============================
    wsl --list --verbose
    pause
) else if "%choice%"=="5" (
    echo.
    echo Available Online WSL Distributions:
    echo ===================================
    wsl --list --online
    pause
) else if "%choice%"=="6" (
    echo.
    echo Goodbye!
    exit /b 0
) else (
    echo.
    echo Invalid choice. Please try again.
    pause
)

goto :EOF