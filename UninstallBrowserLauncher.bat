@echo off
SETLOCAL

REM Set the constant Chrome extension ID
SET CHROME_EXTENSION_ID=ifllnbjkoabnnbcoddplnhmbobim

REM Get the current directory path
SET CURRENT_DIR=%~dp0
REM Remove trailing backslash if it exists
SET CURRENT_DIR=%CURRENT_DIR:~0,-1%

REM Path to the native messaging host manifest file
SET MANIFEST_PATH=%CURRENT_DIR%\com.example.browserlauncher.json

REM Registry keys
SET REG_KEY=HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.example.browserlauncher
SET REG_KEY_EDGE=HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\com.example.browserlauncher

echo Uninstalling Browser Launcher...

REM Remove registry entries for Chrome
reg delete "%REG_KEY%" /f
if %ERRORLEVEL% equ 0 (
    echo Removed registry entry for Chrome at %REG_KEY%
) else (
    echo Registry entry for Chrome not found or could not be removed.
)

REM Remove registry entries for Edge
reg delete "%REG_KEY_EDGE%" /f
if %ERRORLEVEL% equ 0 (
    echo Removed registry entry for Edge at %REG_KEY_EDGE%
) else (
    echo Registry entry for Edge not found or could not be removed.
)

REM Remove the manifest file if it exists
if exist "%MANIFEST_PATH%" (
    del /f "%MANIFEST_PATH%"
    echo Removed manifest file: %MANIFEST_PATH%
) else (
    echo Manifest file not found.
)

REM Note about Python and modules
echo.
echo Note: Python and installed modules (ujson, psutil, configparser) were not removed.
echo If you want to remove them, please use Windows Add/Remove Programs or pip uninstall.
echo.

echo Uninstallation completed.
pause
ENDLOCAL 