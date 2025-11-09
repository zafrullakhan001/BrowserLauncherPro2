@echo off
setlocal enabledelayedexpansion

echo Starting Enhanced WSL Instance Manager...

:: Set up logging
set "LOG_FILE=%~dp0wsl-manager-enhanced-%random%.log"
echo [%date% %time%] Enhanced WSL Instance Manager started > "%LOG_FILE%"

:: Process parameters
set CREATE_INSTANCE=0
set SELECTED_DISTRO=
set CUSTOM_NAME=
set WSL_USERNAME=
set WSL_PASSWORD=
set LIST_INSTALLED=0
set LIST_ONLINE=0
set SHOW_HELP=0

:param_loop
if "%1"=="" goto param_done
if /i "%1"=="-CreateInstance" set CREATE_INSTANCE=1
if /i "%1"=="-ListInstalled" set LIST_INSTALLED=1
if /i "%1"=="-ListOnline" set LIST_ONLINE=1
if /i "%1"=="-Help" set SHOW_HELP=1

:: Handle parameters with values
if /i "%1"=="-SelectedDistro" (
    set SELECTED_DISTRO=%~2
    shift
)
if /i "%1"=="-CustomName" (
    set CUSTOM_NAME=%~2
    shift
)
if /i "%1"=="-Username" (
    set WSL_USERNAME=%~2
    shift
)
if /i "%1"=="-Password" (
    set WSL_PASSWORD=%~2
    shift
)

shift
goto param_loop
:param_done

:: Log parameters
echo [%date% %time%] Parameters processed >> "%LOG_FILE%"
echo [%date% %time%] - CreateInstance: %CREATE_INSTANCE% >> "%LOG_FILE%"
echo [%date% %time%] - ListInstalled: %LIST_INSTALLED% >> "%LOG_FILE%"
echo [%date% %time%] - ListOnline: %LIST_ONLINE% >> "%LOG_FILE%"
echo [%date% %time%] - Help: %SHOW_HELP% >> "%LOG_FILE%"

:: Check for Admin rights for installation operations
if %CREATE_INSTANCE%==1 (
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
    if '!errorlevel!' NEQ '0' (
        echo Administrative privileges required for WSL installation...
        echo [%date% %time%] Requesting administrative privileges >> "%LOG_FILE%"
        
        :: Try to launch PowerShell directly with elevation
        echo Launching elevated PowerShell session...
        echo Please approve the UAC prompt that appears.
        echo.
        
        :: Build PowerShell command with parameters
        set "PS_ELEVATED_COMMAND=powershell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0Manage-WSLInstance-Fixed.ps1\" -CreateInstance"
        
        if not "!SELECTED_DISTRO!"=="" set PS_ELEVATED_COMMAND=!PS_ELEVATED_COMMAND! -SelectedDistro "!SELECTED_DISTRO!"
        if not "!CUSTOM_NAME!"=="" set PS_ELEVATED_COMMAND=!PS_ELEVATED_COMMAND! -CustomName "!CUSTOM_NAME!"
        if not "!WSL_USERNAME!"=="" set PS_ELEVATED_COMMAND=!PS_ELEVATED_COMMAND! -Username "!WSL_USERNAME!"
        if not "!WSL_PASSWORD!"=="" set PS_ELEVATED_COMMAND=!PS_ELEVATED_COMMAND! -Password "!WSL_PASSWORD!"
        
        echo [%date% %time%] Elevated command: !PS_ELEVATED_COMMAND! >> "%LOG_FILE%"
        
        :: Use PowerShell to request elevation directly
        powershell -Command "Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '%~dp0Manage-WSLInstance-Fixed.ps1', '-CreateInstance' -Verb RunAs -Wait"
        
        echo.
        echo Elevated process completed. Check the elevated window for results.
        pause
        goto :EOF
    )
    
    :: Load saved parameters if running elevated
    if exist "%temp%\wsl_enhanced_params.txt" (
        echo Loading saved parameters...
        echo [%date% %time%] Loading saved parameters >> "%LOG_FILE%"
        
        for /f "tokens=1,2 delims==" %%a in (%temp%\wsl_enhanced_params.txt) do (
            if "%%a"=="CREATE_INSTANCE" set CREATE_INSTANCE=%%b
            if "%%a"=="SELECTED_DISTRO" set SELECTED_DISTRO=%%b
            if "%%a"=="CUSTOM_NAME" set CUSTOM_NAME=%%b
            if "%%a"=="WSL_USERNAME" set WSL_USERNAME=%%b
            if "%%a"=="WSL_PASSWORD" set WSL_PASSWORD=%%b
        )
        del "%temp%\wsl_enhanced_params.txt"
    )
)

:: Set PowerShell execution policy
echo Setting PowerShell execution policy...
echo [%date% %time%] Setting PowerShell execution policy >> "%LOG_FILE%"
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force" 2>>"%LOG_FILE%"

:: Check if the enhanced PowerShell script exists
set "PS_SCRIPT=%~dp0Manage-WSLInstance-Fixed.ps1"
if not exist "%PS_SCRIPT%" (
    echo Error: Enhanced PowerShell script not found at "%PS_SCRIPT%"
    echo [%date% %time%] Enhanced PowerShell script not found >> "%LOG_FILE%"
    echo.
    echo Please make sure the Manage-WSLInstance-Fixed.ps1 file exists in the same directory.
    pause
    goto :error
)

:: Build PowerShell command
set PS_COMMAND=powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

:: Add parameters based on what was requested
if %CREATE_INSTANCE%==1 (
    set PS_COMMAND=!PS_COMMAND! -CreateInstance
    if not "!SELECTED_DISTRO!"=="" set PS_COMMAND=!PS_COMMAND! -SelectedDistro "!SELECTED_DISTRO!"
    if not "!CUSTOM_NAME!"=="" set PS_COMMAND=!PS_COMMAND! -CustomName "!CUSTOM_NAME!"
    if not "!WSL_USERNAME!"=="" set PS_COMMAND=!PS_COMMAND! -Username "!WSL_USERNAME!"
    if not "!WSL_PASSWORD!"=="" set PS_COMMAND=!PS_COMMAND! -Password "!WSL_PASSWORD!"
)

if %LIST_INSTALLED%==1 set PS_COMMAND=!PS_COMMAND! -ListInstalled
if %LIST_ONLINE%==1 set PS_COMMAND=!PS_COMMAND! -ListOnline
if %SHOW_HELP%==1 set PS_COMMAND=!PS_COMMAND! -Help

:: Add logging parameter
set PS_COMMAND=!PS_COMMAND! -LogFile "%LOG_FILE%"

echo Executing Enhanced WSL Instance Manager...
echo [%date% %time%] Executing: !PS_COMMAND! >> "%LOG_FILE%"

:: Execute the PowerShell script
!PS_COMMAND!

set SCRIPT_EXIT_CODE=%errorlevel%
echo [%date% %time%] PowerShell script completed with exit code: %SCRIPT_EXIT_CODE% >> "%LOG_FILE%"

if %SCRIPT_EXIT_CODE% NEQ 0 (
    echo [%date% %time%] Script execution completed with errors >> "%LOG_FILE%"
    goto :error
)

echo [%date% %time%] Script execution completed successfully >> "%LOG_FILE%"
echo.
echo Enhanced WSL Instance Manager completed successfully.
echo Log file: %LOG_FILE%

:: Clean up temporary files
if exist "%temp%\wsl_enhanced_params.txt" del /f /q "%temp%\wsl_enhanced_params.txt" 2>nul
if exist "%temp%\wsl_enhanced_elevate_*.bat" del /f /q "%temp%\wsl_enhanced_elevate_*.bat" 2>nul

goto :end

:error
echo.
echo [%date% %time%] An error occurred during script execution >> "%LOG_FILE%"
echo An error occurred. Please check the log file for details:
echo %LOG_FILE%
echo.
pause
goto :end

:end
echo [%date% %time%] Enhanced WSL Instance Manager ended >> "%LOG_FILE%"
endlocal