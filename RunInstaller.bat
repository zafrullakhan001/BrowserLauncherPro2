@echo off
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \""%~dp0Install-BrowserLauncher.ps1\"\"' -Verb RunAs" 