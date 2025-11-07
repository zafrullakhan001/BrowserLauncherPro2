@echo off
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \""%~dp0CheckDependencies.ps1\"\"' -Verb RunAs" 