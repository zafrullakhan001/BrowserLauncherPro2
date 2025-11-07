@echo off
setlocal EnableDelayedExpansion

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please run this script as Administrator! Attempting to elevate...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Enable color support
for /f "tokens=3" %%a in ('reg query "HKCU\Console" /v "VirtualTerminalLevel" 2^>nul') do set /a "VTLevel=%%a"
if not defined VTLevel (
    reg add "HKCU\Console" /v "VirtualTerminalLevel" /t REG_DWORD /d 1 /f >nul
)

:: Set console code page to UTF-8
chcp 65001 >nul

:: Color definitions using native Windows commands
set "PASS_MARK=√"
set "FAIL_MARK=×"

cls
color 0B
echo === Browser Launcher Extension Pre-Check Tool ===
color 07
echo Running comprehensive system checks...
echo.

:: Check Python Installation
color 0B
echo === Checking Python Installation ===
color 07
python --version >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do (
        color 0A
        echo %PASS_MARK% Python is installed: %%i
        color 07
    )
    
    :: Check pip installation
    python -m pip --version >nul 2>&1
    if %errorLevel% equ 0 (
        for /f "tokens=*" %%i in ('python -m pip --version') do (
            color 0A
            echo %PASS_MARK% Pip is installed: %%i
            color 07
        )
        
        :: Check required modules
        for %%m in (ujson psutil configparser) do (
            python -c "import %%m" >nul 2>&1
            if !errorLevel! equ 0 (
                color 0A
                echo %PASS_MARK% Module %%m is installed
                color 07
            ) else (
                color 0C
                echo %FAIL_MARK% Module %%m is missing
                color 07
            )
        )
    ) else (
        color 0C
        echo %FAIL_MARK% Pip is not installed
        color 07
    )
) else (
    color 0C
    echo %FAIL_MARK% Python is not installed or not in PATH
    color 07
)

echo.
:: Check Browser Installations
color 0B
echo === Checking Browser Installations ===
color 07

:: Check Edge
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    color 0A
    echo %PASS_MARK% Found: Microsoft Edge
    color 07
) else (
    color 0C
    echo %FAIL_MARK% Microsoft Edge not found
    color 07
)

:: Check Chrome
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    color 0A
    echo %PASS_MARK% Found: Google Chrome
    color 07
) else (
    color 0C
    echo %FAIL_MARK% Google Chrome not found
    color 07
)

echo.
:: Check WSL Support
color 0B
echo === Checking WSL Support ===
color 07
wsl --status >nul 2>&1
if %errorLevel% equ 0 (
    color 0A
    echo %PASS_MARK% WSL is enabled
    color 07
) else (
    color 0C
    echo %FAIL_MARK% WSL is not enabled
    color 07
)

echo.
:: Check Windows Sandbox
color 0B
echo === Checking Windows Sandbox Support ===
color 07
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Containers\CombinedVolume" >nul 2>&1
if %errorLevel% equ 0 (
    color 0A
    echo %PASS_MARK% Windows Sandbox is enabled
    color 07
) else (
    color 0C
    echo %FAIL_MARK% Windows Sandbox is not enabled
    color 07
)

echo.
:: Check Extension Prerequisites
color 0B
echo === Checking Extension Prerequisites ===
color 07

:: Check Registry Permissions
for %%r in (
    "HKCU\Software\Google\Chrome\NativeMessagingHosts"
    "HKCU\Software\Microsoft\Edge\NativeMessagingHosts"
) do (
    reg query "%%~r" >nul 2>&1
    if !errorLevel! equ 0 (
        color 0A
        echo %PASS_MARK% Registry permissions OK for: %%~r
        color 07
    ) else (
        color 0C
        echo %FAIL_MARK% Missing registry permissions for: %%~r
        color 07
    )
)

:: Check Required Files
for %%f in (native_messaging.py com.example.browserlauncher.json manifest.json) do (
    if exist "%%~f" (
        color 0A
        echo %PASS_MARK% Required file exists: %%~f
        color 07
    ) else (
        color 0C
        echo %FAIL_MARK% Missing required file: %%~f
        color 07
    )
)

echo.
:: System Summary
color 0B
echo === System Requirements Summary ===
color 07
echo CPU Architecture: %PROCESSOR_ARCHITECTURE%
ver
echo PowerShell Version:
powershell "$PSVersionTable.PSVersion.ToString()"

:: Get RAM info
for /f "tokens=2 delims==" %%a in ('wmic ComputerSystem get TotalPhysicalMemory /value') do set "RAM=%%a"
set /a "RAM_GB=%RAM:~0,-1%/1024/1024/1024"
echo Total RAM: %RAM_GB% GB

:: Get Disk Space
for /f "tokens=2 delims==" %%a in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value') do set "SPACE=%%a"
set /a "SPACE_GB=%SPACE%/1024/1024/1024"
echo Available Disk Space: %SPACE_GB% GB

echo.
color 0E
echo Pre-check completed. Please review any items marked with %FAIL_MARK% before proceeding.
color 07

:: Pause at the end
echo.
pause
endlocal 