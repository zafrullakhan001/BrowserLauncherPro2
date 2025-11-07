@echo off
setlocal enabledelayedexpansion

echo Starting WSL Instance Manager...

:: Set up logging
set "LOG_FILE=%~dp0wsl-manager-run-%random%.log"
echo [%date% %time%] WSL Instance Manager started > "%LOG_FILE%"

:: Check if creating a new instance
set CREATE_INSTANCE=0
set QUIET_MODE=0
set DEBUG_MODE=0
set PARAMS_PROVIDED=0
set SELECTED_DISTRO=
set CUSTOM_NAME=
set WSL_USERNAME=
set WSL_PASSWORD=
set ADVANCED_MODE=0

:: Process parameters
:param_loop
if "%1"=="" goto param_done
if /i "%1"=="-CreateInstance" set CREATE_INSTANCE=1
if /i "%1"=="-QuietMode" set QUIET_MODE=1
if /i "%1"=="-NoDebug" set DEBUG_MODE=1
if /i "%1"=="-AdvancedMode" set ADVANCED_MODE=1

:: Check for specific parameters that indicate non-interactive mode
if /i "%1"=="-SelectedDistro" (
    set PARAMS_PROVIDED=1
    set SELECTED_DISTRO=%~2
    shift
)
if /i "%1"=="-CustomName" (
    set PARAMS_PROVIDED=1
    set CUSTOM_NAME=%~2
    shift
)
if /i "%1"=="-Username" (
    set PARAMS_PROVIDED=1
    set WSL_USERNAME=%~2
    shift
)
if /i "%1"=="-Password" (
    set PARAMS_PROVIDED=1
    set WSL_PASSWORD=%~2
    shift
)

shift
goto param_loop
:param_done

:: If advanced mode is requested, launch the PowerShell script directly
if %ADVANCED_MODE%==1 (
    echo Launching Advanced WSL Management Tool...
    echo [%date% %time%] Launching Advanced WSL Management Tool >> "%LOG_FILE%"
    
    :: Check if the PowerShell script exists
    if not exist "%~dp0wsl-info-and-tools.ps1" (
        echo Error: Advanced WSL Management Tool script not found.
        echo [%date% %time%] Advanced WSL Management Tool script not found >> "%LOG_FILE%"
        goto :error
    )
    
    :: Launch the PowerShell script with admin rights
    powershell -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0wsl-info-and-tools.ps1\"' -Verb RunAs"
    goto :end
)

:: Log the parameters
echo [%date% %time%] Parameters processed: >> "%LOG_FILE%"
if %CREATE_INSTANCE%==1 (
    echo [%date% %time%] - CreateInstance: Yes >> "%LOG_FILE%"
    if %PARAMS_PROVIDED%==1 (
        echo [%date% %time%] - SelectedDistro: %SELECTED_DISTRO% >> "%LOG_FILE%"
        echo [%date% %time%] - CustomName: %CUSTOM_NAME% >> "%LOG_FILE%"
        echo [%date% %time%] - Username: %WSL_USERNAME% >> "%LOG_FILE%"
        echo [%date% %time%] - Password: [HIDDEN] >> "%LOG_FILE%"
    )
)

:: If creating a new instance and parameters weren't provided, collect information interactively
if %CREATE_INSTANCE%==1 (
    if %PARAMS_PROVIDED%==0 (
        echo WSL Instance Creation Wizard
        echo ===========================
        echo.
        
        :: Show available Ubuntu distros
        echo Available Ubuntu distributions:
        echo [0] Ubuntu
        echo [1] Ubuntu-18.04
        echo [2] Ubuntu-20.04
        echo [3] Ubuntu-22.04
        echo [4] Ubuntu-24.04
        
        :: Get distribution selection
        Write-Host "Enter the number of the distribution you want to install:" -ForegroundColor Cyan
        set /p DISTRO_CHOICE
        
        :: Set the selected distro
        if "%DISTRO_CHOICE%"=="0" set SELECTED_DISTRO=Ubuntu
        if "%DISTRO_CHOICE%"=="1" set SELECTED_DISTRO=Ubuntu-18.04
        if "%DISTRO_CHOICE%"=="2" set SELECTED_DISTRO=Ubuntu-20.04
        if "%DISTRO_CHOICE%"=="3" set SELECTED_DISTRO=Ubuntu-22.04
        if "%DISTRO_CHOICE%"=="4" set SELECTED_DISTRO=Ubuntu-24.04
        
        echo You selected: !SELECTED_DISTRO!
        echo.
        
        :: Get custom name
        set /p CUSTOM_NAME="Enter a custom name for the new instance (or press Enter to use the default name): "
        if "!CUSTOM_NAME!"=="" set CUSTOM_NAME=!SELECTED_DISTRO!
        echo.
        
        :: Get username
        set /p WSL_USERNAME="Enter a username for the WSL instance: "
        if "!WSL_USERNAME!"=="" set WSL_USERNAME=wsluser
        echo.
        
        :: Get password with confirmation
        :password_entry
        set /p WSL_PASSWORD="Enter a password for the WSL instance: "
        set /p WSL_PASSWORD_CONFIRM="Confirm password: "
        
        if not "!WSL_PASSWORD!"=="!WSL_PASSWORD_CONFIRM!" (
            echo Passwords do not match. Please try again.
            echo.
            goto password_entry
        )
        
        if "!WSL_PASSWORD!"=="" (
            echo Using default password...
            set WSL_PASSWORD=password123
        )
        
        echo.
        echo Summary:
        echo - Distribution: !SELECTED_DISTRO!
        echo - Custom Name: !CUSTOM_NAME!
        echo - Username: !WSL_USERNAME!
        echo - Password: [Hidden]
        echo.
        
        set /p CONFIRM="Proceed with these settings? [Y/N] "
        if /i not "!CONFIRM!"=="Y" (
            echo Installation cancelled.
            goto :EOF
        )
    ) else (
        echo Using provided parameters:
        echo - Distribution: !SELECTED_DISTRO!
        echo - Custom Name: !CUSTOM_NAME!
        echo - Username: !WSL_USERNAME!
        echo - Password: [Hidden]
    )
)

:: Check for Admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

if '%errorlevel%' NEQ '0' (
    echo Administrative privileges required...
    echo [%date% %time%] Requesting administrative privileges >> "%LOG_FILE%"
    
    :: Save parameters for elevated process
    if %CREATE_INSTANCE%==1 (
        echo SELECTED_DISTRO=!SELECTED_DISTRO!> "%temp%\wsl_params.txt"
        echo CUSTOM_NAME=!CUSTOM_NAME!>> "%temp%\wsl_params.txt"
        echo WSL_USERNAME=!WSL_USERNAME!>> "%temp%\wsl_params.txt"
        echo WSL_PASSWORD=!WSL_PASSWORD!>> "%temp%\wsl_params.txt"
    )
    
    :: Use a simple random name for the elevation script
    set "ELEVATE_SCRIPT=%temp%\wsl_elevate_%random%.bat"
    
    :: Make sure the script doesn't exist
    if exist "!ELEVATE_SCRIPT!" del /f /q "!ELEVATE_SCRIPT!" 2>nul
    
    :: Create a clean batch file that will run with elevated privileges
    echo @echo off > "!ELEVATE_SCRIPT!"
    echo cd /d "%~dp0" >> "!ELEVATE_SCRIPT!"
    echo call "%~dpnx0" >> "!ELEVATE_SCRIPT!"
    
    :: Add parameters one by one to avoid issues with spaces
    for %%i in (%*) do (
        echo %%i >> "!ELEVATE_SCRIPT!"
    )
    
    :: Debug output
    echo Elevation script created at: !ELEVATE_SCRIPT!
    echo [%date% %time%] Elevation script created at: !ELEVATE_SCRIPT! >> "%LOG_FILE%"
    
    :: Create a new window to show progress
    echo [%date% %time%] Creating progress window >> "%LOG_FILE%"

    :: Create a simpler progress window that just shows the console output
    echo @echo off > "%temp%\wsl_progress.bat"
    echo title WSL Installation Progress >> "%temp%\wsl_progress.bat"
    echo echo WSL Installation Progress >> "%temp%\wsl_progress.bat"
    echo echo. >> "%temp%\wsl_progress.bat"
    echo echo The installation is running with elevated privileges. >> "%temp%\wsl_progress.bat"
    echo echo. >> "%temp%\wsl_progress.bat"
    echo echo Progress log: %LOG_FILE% >> "%temp%\wsl_progress.bat"
    echo echo. >> "%temp%\wsl_progress.bat"
    echo echo Installation in progress. Please wait... >> "%temp%\wsl_progress.bat"
    echo echo This window will close automatically when complete. >> "%temp%\wsl_progress.bat"
    echo echo. >> "%temp%\wsl_progress.bat"
    echo echo You can check the log file for detailed progress. >> "%temp%\wsl_progress.bat"

    :: Launch progress window
    start "WSL Installation Progress" /min "%temp%\wsl_progress.bat"

    :: Wait for progress window to start
    ping -n 2 127.0.0.1 > nul
    
    :: Attempt to elevate using PowerShell
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"!ELEVATE_SCRIPT!\"' -Verb RunAs"
    
    :: Exit the non-elevated script
    goto :EOF
)

:: At this point we should have admin rights
echo Running with administrative privileges.
echo [%date% %time%] Running with administrative privileges >> "%LOG_FILE%"

:: Read saved parameters if they exist
if %CREATE_INSTANCE%==1 (
    if exist "%temp%\wsl_params.txt" (
        for /f "tokens=1,2 delims==" %%a in (%temp%\wsl_params.txt) do (
            if "%%a"=="SELECTED_DISTRO" set SELECTED_DISTRO=%%b
            if "%%a"=="CUSTOM_NAME" set CUSTOM_NAME=%%b
            if "%%a"=="WSL_USERNAME" set WSL_USERNAME=%%b
            if "%%a"=="WSL_PASSWORD" set WSL_PASSWORD=%%b
        )
        del "%temp%\wsl_params.txt"
        set PARAMS_PROVIDED=1
        
        echo [%date% %time%] Parameters loaded from file: >> "%LOG_FILE%"
        echo [%date% %time%] - SelectedDistro: %SELECTED_DISTRO% >> "%LOG_FILE%"
        echo [%date% %time%] - CustomName: %CUSTOM_NAME% >> "%LOG_FILE%"
        echo [%date% %time%] - Username: %WSL_USERNAME% >> "%LOG_FILE%"
        echo [%date% %time%] - Password: [HIDDEN] >> "%LOG_FILE%"
    )
)

:: Set execution policy with error handling
echo Setting PowerShell execution policy...
echo [%date% %time%] Setting PowerShell execution policy >> "%LOG_FILE%"

powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force" 2>>"%LOG_FILE%"
if %errorlevel% NEQ 0 (
    echo Warning: Failed to set PowerShell execution policy. Attempting to continue anyway.
    echo [%date% %time%] PowerShell execution policy error: %errorlevel% >> "%LOG_FILE%"
)

:: Check if PowerShell script exists
if not exist "%~dp0Manage-WSLInstance.ps1" (
    echo Error: PowerShell script not found at "%~dp0Manage-WSLInstance.ps1"
    echo [%date% %time%] PowerShell script not found >> "%LOG_FILE%"
    goto :error
)

echo Executing main PowerShell script...
echo [%date% %time%] Executing main PowerShell script >> "%LOG_FILE%"

:: Build the command with parameters
set PS_COMMAND=powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-WSLInstance.ps1"

if %CREATE_INSTANCE%==1 (
    set PS_COMMAND=!PS_COMMAND! -CreateInstance -SelectedDistro "!SELECTED_DISTRO!" -CustomName "!CUSTOM_NAME!" -Username "!WSL_USERNAME!" -Password "!WSL_PASSWORD!"
    
    :: Check if browser installation script exists
    if exist "%~dp0wsl-install-browsers.sh" (
        set PS_COMMAND=!PS_COMMAND! -InstallBrowsers
    )
) else (
    set PS_COMMAND=!PS_COMMAND! %*
)

if %QUIET_MODE%==1 set PS_COMMAND=!PS_COMMAND! -QuietMode
if %DEBUG_MODE%==1 set PS_COMMAND=!PS_COMMAND! -NoDebug

:: Add verbose logging parameter
set PS_COMMAND=!PS_COMMAND! -LogFile "%LOG_FILE%"

echo [%date% %time%] Executing: !PS_COMMAND! >> "%LOG_FILE%"

:: Execute PowerShell script with error handling
!PS_COMMAND! 2>>"%LOG_FILE%"
if %errorlevel% NEQ 0 (
    echo [%date% %time%] PowerShell script returned error: %errorlevel% >> "%LOG_FILE%"
    goto :error
)

echo [%date% %time%] Execution completed successfully. >> "%LOG_FILE%"
echo Execution completed successfully.

:: Clean up temporary files
if exist "%temp%\wsl_progress.bat" del /f /q "%temp%\wsl_progress.bat" 2>nul

goto :end

:error
echo.
echo [%date% %time%] An error occurred while running the script. >> "%LOG_FILE%"
echo An error occurred while running the script. Please check the log file:
echo %LOG_FILE%
echo.

:: Clean up temporary files
if exist "%temp%\wsl_progress.bat" del /f /q "%temp%\wsl_progress.bat" 2>nul

pause
goto :end

:end
echo [%date% %time%] Script execution ended. >> "%LOG_FILE%"
endlocal 