@echo off
echo Running WSL Environment Diagnostics...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0wslscripts\CheckWSLEnvironment.ps1"
pause 