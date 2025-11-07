@echo off
SETLOCAL EnableDelayedExpansion

REM Set the constant Chrome extension ID
SET CHROME_EXTENSION_ID=ifllnbjkoabnnbcodbocddplnhmbobim

REM Get the current directory path and ensure it exists
SET "CURRENT_DIR=%~dp0"
IF NOT EXIST "%CURRENT_DIR%" (
    echo Error: Current directory does not exist.
    pause
    exit /b 1
)

REM Remove trailing backslash if it exists
IF "%CURRENT_DIR:~-1%"=="\" SET "CURRENT_DIR=%CURRENT_DIR:~0,-1%"

REM Set paths with proper escaping
SET "SCRIPT_PATH=%CURRENT_DIR%\native_messaging.py"
SET "MANIFEST_PATH=%CURRENT_DIR%\com.example.browserlauncher.json"

REM Registry keys
SET "REG_KEY=HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.example.browserlauncher"
SET "REG_KEY_EDGE=HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\com.example.browserlauncher"

REM Check Windows version
VER | FINDSTR /I "10\." > NUL
IF %ERRORLEVEL% NEQ 0 (
    VER | FINDSTR /I "11\." > NUL
    IF %ERRORLEVEL% NEQ 0 (
        echo Warning: This script is designed for Windows 10/11. It may not work correctly on your system.
        pause
    )
)

REM Check for Python installation
echo Checking Python installation...
python --version > NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Python is not installed. Installing Python...
    powershell -Command "Start-Process 'powershell' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0python-install.ps1\"\"' -Verb RunAs -Wait"
    python --version > NUL 2>&1
    IF %ERRORLEVEL% NEQ 0 (
        echo Failed to install Python. Please install Python manually from https://www.python.org and run this script again.
        pause
        exit /b 1
    )
)

REM Check Python version (minimum 3.7 required)
FOR /F "tokens=2" %%I IN ('python --version 2^>^&1') DO SET PYTHON_VERSION=%%I
FOR /F "tokens=1,2 delims=." %%A IN ("%PYTHON_VERSION%") DO (
    IF %%A LSS 3 (
        echo Error: Python 3.7 or higher is required. Found version %%A.%%B
        pause
        exit /b 1
    ) ELSE IF %%A EQU 3 IF %%B LSS 7 (
        echo Error: Python 3.7 or higher is required. Found version %%A.%%B
        pause
        exit /b 1
    )
)

REM Ensure pip is up-to-date and install required Python modules
echo Installing required Python modules...
python -m pip install --upgrade pip
IF %ERRORLEVEL% NEQ 0 (
    echo Failed to upgrade pip.
    pause
    exit /b 1
)

python -m pip install --upgrade ujson psutil configparser
IF %ERRORLEVEL% NEQ 0 (
    echo Failed to install required Python modules.
    pause
    exit /b 1
)

REM Create the manifest file with the correct path
(
echo {
echo     "name": "com.example.browserlauncher",
echo     "description": "Browser Launcher",
echo     "path": "%SCRIPT_PATH:\=\\%",
echo     "type": "stdio",
echo     "allowed_origins": [
echo         "chrome-extension://%CHROME_EXTENSION_ID%/"
echo     ]
echo }
) > "%MANIFEST_PATH%"

IF NOT EXIST "%MANIFEST_PATH%" (
    echo Failed to create manifest file.
    pause
    exit /b 1
)

REM Create registry entries for Chrome
reg add "%REG_KEY%" /ve /t REG_SZ /d "%MANIFEST_PATH%" /f
IF %ERRORLEVEL% NEQ 0 (
    echo Failed to create registry entry for Chrome.
    pause
    exit /b 1
) ELSE (
    echo Created registry entry for Chrome at %REG_KEY%
)

REM Create registry entries for Edge
reg add "%REG_KEY_EDGE%" /ve /t REG_SZ /d "%MANIFEST_PATH%" /f
IF %ERRORLEVEL% NEQ 0 (
    echo Failed to create registry entry for Edge.
    pause
    exit /b 1
) ELSE (
    echo Created registry entry for Edge at %REG_KEY_EDGE%
)

echo Native messaging host setup completed successfully.
pause
ENDLOCAL
