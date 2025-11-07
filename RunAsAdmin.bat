@echo off
echo Running Browser Launcher Installer with Administrator privileges...
powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File \".\Install-BrowserLauncher.ps1\"' -Verb RunAs"
echo If a UAC prompt appears, please click 'Yes' to continue.
pause 