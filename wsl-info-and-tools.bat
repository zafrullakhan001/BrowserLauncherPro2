@echo off
setlocal enabledelayedexpansion

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :MAIN_MENU
) else (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -Verb RunAs -FilePath '%0' -ArgumentList 'restarted'"
    exit /b
)

:MAIN_MENU
cls
echo WSL INFORMATION AND MANAGEMENT TOOL
echo ===================================
echo.
echo INFORMATION:
echo 1. WSL System Status
echo 2. List WSL Distributions
echo 3. WSL Resource Usage
echo 4. WSL Network Information
echo 5. Test WSL Connectivity
echo.
echo NETWORKING:
echo 6. Manage WSL Networking
echo.
echo MANAGEMENT:
echo 7. Create New WSL Instance
echo 8. Delete WSL Instance
echo 9. Rename WSL Instance
echo 10. Update WSL Instance
echo.
echo MAINTENANCE:
echo 11. Optimize WSL Performance
echo 12. WSL Repair Tools
echo 13. Backup and Restore
echo 14. Performance Monitoring
echo 15. Configuration Profiles
echo 16. Package Management
echo 17. System Health Check
echo 18. Exit
echo.
set /p choice="Select an option (1-18): "

if "%choice%"=="1" call :WSL_STATUS
if "%choice%"=="2" call :LIST_DISTRIBUTIONS
if "%choice%"=="3" call :RESOURCE_USAGE
if "%choice%"=="4" call :NETWORK_INFO
if "%choice%"=="5" call :TEST_CONNECTIVITY
if "%choice%"=="6" call :MANAGE_NETWORKING
if "%choice%"=="7" call :NEW_INSTANCE
if "%choice%"=="8" call :DELETE_INSTANCE
if "%choice%"=="9" call :RENAME_INSTANCE
if "%choice%"=="10" call :UPDATE_INSTANCE
if "%choice%"=="11" call :OPTIMIZE_WSL
if "%choice%"=="12" call :REPAIR_WSL
if "%choice%"=="13" call :BACKUP_RESTORE
if "%choice%"=="14" call :PERFORMANCE_MONITOR
if "%choice%"=="15" call :CONFIG_PROFILES
if "%choice%"=="16" call :PACKAGE_MANAGEMENT
if "%choice%"=="17" call :HEALTH_CHECK
if "%choice%"=="18" exit /b

goto MAIN_MENU

:WSL_STATUS
cls
echo WSL SYSTEM STATUS
echo ================
echo.
wsl --status
echo.
echo Windows Features Status:
dism /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism /online /get-featureinfo /featurename:VirtualMachinePlatform
echo.
echo Installed Distributions:
wsl --list --verbose
echo.
pause
goto MAIN_MENU

:LIST_DISTRIBUTIONS
cls
echo WSL DISTRIBUTIONS
echo ================
echo.
wsl --list --verbose
echo.
pause
goto MAIN_MENU

:RESOURCE_USAGE
cls
echo WSL RESOURCE USAGE
echo ================
echo.
for /f "tokens=2 delims= " %%i in ('wsl --list --quiet ^| findstr /v "Windows"') do (
    echo Distribution: %%i
    echo Memory Usage:
    wsl -d %%i free -h 2>nul
    if errorlevel 1 (
        echo Failed to get memory usage for this distribution
    )
    echo.
    echo Disk Usage:
    wsl -d %%i df -h 2>nul
    if errorlevel 1 (
        echo Failed to get disk usage for this distribution
    )
    echo.
    echo ----------------------------------------
    echo.
)
pause
goto MAIN_MENU

:NETWORK_INFO
cls
echo WSL NETWORK INFORMATION
echo ======================
echo.
for /f "tokens=2 delims= " %%i in ('wsl --list --quiet ^| findstr /v "Windows"') do (
    echo Distribution: %%i
    echo IP Addresses:
    wsl -d %%i ip -4 addr show eth0 2>nul
    if errorlevel 1 (
        echo No network interface found for this distribution
    )
    echo.
    echo ----------------------------------------
    echo.
)
pause
goto MAIN_MENU

:TEST_CONNECTIVITY
cls
echo WSL CONNECTIVITY TEST
echo ====================
echo.
for /f "tokens=2 delims= " %%i in ('wsl --list --quiet ^| findstr /v "Windows"') do (
    echo Testing distribution: %%i
    echo Testing internet connectivity...
    wsl -d %%i ping -c 2 8.8.8.8 2>nul
    if errorlevel 1 (
        echo Failed to test connectivity for this distribution
    )
    echo.
    echo Testing DNS resolution...
    wsl -d %%i nslookup google.com 2>nul
    if errorlevel 1 (
        echo Failed to test DNS resolution for this distribution
    )
    echo.
    echo Checking network interfaces...
    wsl -d %%i ip addr show 2>nul
    if errorlevel 1 (
        echo Failed to check network interfaces for this distribution
    )
    echo.
    echo ----------------------------------------
    echo.
)
pause
goto MAIN_MENU

:MANAGE_NETWORKING
cls
echo WSL NETWORKING MANAGEMENT
echo ========================
echo.
echo 1. Configure Port Forwarding
echo 2. Manage Network Interfaces
echo 3. Configure DNS Settings
echo 4. Network Troubleshooting
echo 5. Back to Main Menu
echo.
set /p net_choice="Select an option (1-5): "

if "%net_choice%"=="1" call :PORT_FORWARDING
if "%net_choice%"=="2" call :NETWORK_INTERFACES
if "%net_choice%"=="3" call :DNS_SETTINGS
if "%net_choice%"=="4" call :NETWORK_TROUBLESHOOT
if "%net_choice%"=="5" goto MAIN_MENU

goto MANAGE_NETWORKING

:PORT_FORWARDING
cls
echo PORT FORWARDING MANAGEMENT
echo ========================
echo.
echo 1. Add Port Forward
echo 2. List Port Forwards
echo 3. Remove Port Forward
echo 4. Back
echo.
set /p port_choice="Select an option (1-4): "

if "%port_choice%"=="1" call :ADD_PORT_FORWARD
if "%port_choice%"=="2" call :LIST_PORT_FORWARDS
if "%port_choice%"=="3" call :REMOVE_PORT_FORWARD
if "%port_choice%"=="4" goto MANAGE_NETWORKING

goto PORT_FORWARDING

:ADD_PORT_FORWARD
cls
echo ADD PORT FORWARD
echo ==============
echo.
wsl --list --verbose
echo.
set /p distro="Enter distribution name: "
set /p local_port="Enter local port: "
set /p remote_port="Enter remote port: "
for /f "tokens=2" %%a in ('wsl -d %distro% ip -4 addr show eth0 ^| findstr "inet"') do set wsl_ip=%%a
set wsl_ip=!wsl_ip:/=!
netsh interface portproxy add v4tov4 listenport=%local_port% listenaddress=0.0.0.0 connectport=%remote_port% connectaddress=%wsl_ip%
echo Port forward added successfully.
pause
goto PORT_FORWARDING

:LIST_PORT_FORWARDS
cls
echo CURRENT PORT FORWARDS
echo ====================
echo.
netsh interface portproxy show all
echo.
pause
goto PORT_FORWARDING

:REMOVE_PORT_FORWARD
cls
echo REMOVE PORT FORWARD
echo =================
echo.
netsh interface portproxy show all
echo.
set /p port="Enter port to remove: "
netsh interface portproxy delete v4tov4 listenport=%port% listenaddress=0.0.0.0
echo Port forward removed successfully.
pause
goto PORT_FORWARDING

:NETWORK_INTERFACES
cls
echo NETWORK INTERFACES
echo ================
echo.
wsl --list --verbose
echo.
set /p distro="Enter distribution name: "
wsl -d %distro% ip addr show
echo.
pause
goto MANAGE_NETWORKING

:DNS_SETTINGS
cls
echo DNS SETTINGS
echo ===========
echo.
wsl --list --verbose
echo.
set /p distro="Enter distribution name: "
wsl -d %distro% cat /etc/resolv.conf
echo.
set /p change_dns="Do you want to configure custom DNS servers? (Y/N): "
if /i "%change_dns%"=="Y" (
    set /p primary_dns="Enter primary DNS server: "
    set /p secondary_dns="Enter secondary DNS server: "
    wsl -d %distro% bash -c "echo 'nameserver %primary_dns%' | sudo tee /etc/resolv.conf"
    wsl -d %distro% bash -c "echo 'nameserver %secondary_dns%' | sudo tee -a /etc/resolv.conf"
    echo DNS settings updated successfully.
)
pause
goto MANAGE_NETWORKING

:NETWORK_TROUBLESHOOT
cls
echo NETWORK TROUBLESHOOTING
echo =====================
echo.
wsl --list --verbose
echo.
set /p distro="Enter distribution name: "
echo.
echo Testing internet connectivity...
wsl -d %distro% ping -c 4 8.8.8.8
echo.
echo Testing DNS resolution...
wsl -d %distro% nslookup google.com
echo.
echo Checking network interfaces...
wsl -d %distro% ip addr show
echo.
pause
goto MANAGE_NETWORKING

:NEW_INSTANCE
cls
echo CREATE NEW WSL INSTANCE
echo =====================
echo.
wsl --list --online
echo.
set /p distro="Enter the name of the distribution to install: "
wsl --install -d %distro%
echo.
pause
goto MAIN_MENU

:DELETE_INSTANCE
cls
echo DELETE WSL INSTANCE
echo =================
echo.
wsl --list --verbose
echo.
set /p distro="Enter the name of the distribution to delete: "
wsl --unregister %distro%
echo.
pause
goto MAIN_MENU

:RENAME_INSTANCE
cls
echo RENAME WSL INSTANCE
echo =================
echo.
wsl --list --verbose
echo.
set /p old_name="Enter current distribution name: "
set /p new_name="Enter new distribution name: "
wsl --export %old_name% %temp%\%old_name%.tar
wsl --import %new_name% %temp%\%new_name% %temp%\%old_name%.tar
wsl --unregister %old_name%
del %temp%\%old_name%.tar
echo.
pause
goto MAIN_MENU

:UPDATE_INSTANCE
cls
echo UPDATE WSL INSTANCE
echo =================
echo.
wsl --list --verbose
echo.
set /p distro="Enter distribution name to update: "
wsl -d %distro% bash -c "sudo apt update && sudo apt upgrade -y"
echo.
pause
goto MAIN_MENU

:OPTIMIZE_WSL
cls
echo OPTIMIZE WSL PERFORMANCE
echo ======================
echo.
set /p memory="Enter memory limit in GB: "
set /p processors="Enter number of processors: "
set /p swap="Enter swap size in GB: "
echo [wsl2] > %USERPROFILE%\.wslconfig
echo memory=%memory%GB >> %USERPROFILE%\.wslconfig
echo processors=%processors% >> %USERPROFILE%\.wslconfig
echo swap=%swap%GB >> %USERPROFILE%\.wslconfig
echo localhostForwarding=true >> %USERPROFILE%\.wslconfig
echo kernelCommandLine=quiet >> %USERPROFILE%\.wslconfig
echo.
echo WSL configuration updated. Please restart WSL for changes to take effect.
echo Run 'wsl --shutdown' to restart WSL
echo.
pause
goto MAIN_MENU

:REPAIR_WSL
cls
echo WSL REPAIR TOOLS
echo ==============
echo.
echo 1. Reset WSL Network
echo 2. Repair WSL Registration
echo 3. Reset WSL Instance
echo 4. Reinstall WSL Components
echo 5. Back to Main Menu
echo.
set /p repair_choice="Select an option (1-5): "

if "%repair_choice%"=="1" (
    wsl --shutdown
    netsh interface set interface "vEthernet (WSL)" admin=disable
    timeout /t 2
    netsh interface set interface "vEthernet (WSL)" admin=enable
    echo WSL network reset complete.
)
if "%repair_choice%"=="2" (
    wsl --shutdown
    dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    echo WSL features repaired.
)
if "%repair_choice%"=="3" (
    wsl --list --verbose
    echo.
    set /p distro="Enter distribution name to reset: "
    wsl --unregister %distro%
    wsl --install -d %distro%
    echo Distribution reset complete.
)
if "%repair_choice%"=="4" (
    wsl --shutdown
    dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    echo WSL components reinstalled. A system restart is recommended.
)
if "%repair_choice%"=="5" goto MAIN_MENU

pause
goto REPAIR_WSL

:BACKUP_RESTORE
cls
echo WSL BACKUP AND RESTORE
echo ====================
echo.
echo 1. Backup WSL Distribution
echo 2. Restore WSL Distribution
echo 3. List Backups
echo 4. Back to Main Menu
echo.
set /p backup_choice="Select an option (1-4): "

if "%backup_choice%"=="1" call :BACKUP_DISTRO
if "%backup_choice%"=="2" call :RESTORE_DISTRO
if "%backup_choice%"=="3" call :LIST_BACKUPS
if "%backup_choice%"=="4" goto MAIN_MENU

goto BACKUP_RESTORE

:BACKUP_DISTRO
cls
echo BACKUP WSL DISTRIBUTION
echo =====================
echo.
wsl --list --verbose
echo.
set /p distro="Enter distribution name to backup: "
set /p backup_path="Enter backup path (default: %USERPROFILE%\WSL-Backups): "
if "%backup_path%"=="" set backup_path=%USERPROFILE%\WSL-Backups
if not exist "%backup_path%" mkdir "%backup_path%"
set timestamp=%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%
wsl --export %distro% "%backup_path%\%distro%_%timestamp%.tar"
echo Backup created successfully.
pause
goto BACKUP_RESTORE

:RESTORE_DISTRO
cls
echo RESTORE WSL DISTRIBUTION
echo ======================
echo.
set /p backup_path="Enter backup directory path (default: %USERPROFILE%\WSL-Backups): "
if "%backup_path%"=="" set backup_path=%USERPROFILE%\WSL-Backups
if not exist "%backup_path%" (
    echo Backup directory not found.
    pause
    goto BACKUP_RESTORE
)
dir /b "%backup_path%\*.tar"
echo.
set /p backup_file="Enter backup file name: "
set /p new_name="Enter name for the restored distribution: "
wsl --import %new_name% "%USERPROFILE%\WSL\%new_name%" "%backup_path%\%backup_file%"
echo Distribution restored successfully.
pause
goto BACKUP_RESTORE

:LIST_BACKUPS
cls
echo LIST BACKUPS
echo ===========
echo.
set /p backup_path="Enter backup directory path (default: %USERPROFILE%\WSL-Backups): "
if "%backup_path%"=="" set backup_path=%USERPROFILE%\WSL-Backups
if not exist "%backup_path%" (
    echo Backup directory not found.
    pause
    goto BACKUP_RESTORE
)
dir /b "%backup_path%\*.tar"
echo.
pause
goto BACKUP_RESTORE

:PERFORMANCE_MONITOR
cls
echo WSL PERFORMANCE MONITORING
echo ========================
echo.
echo 1. Start Performance Monitoring
echo 2. View Performance Logs
echo 3. Configure Monitoring
echo 4. Back to Main Menu
echo.
set /p monitor_choice="Select an option (1-4): "

if "%monitor_choice%"=="1" call :START_MONITORING
if "%monitor_choice%"=="2" call :VIEW_LOGS
if "%monitor_choice%"=="3" call :CONFIGURE_MONITORING
if "%monitor_choice%"=="4" goto MAIN_MENU

goto PERFORMANCE_MONITOR

:START_MONITORING
cls
echo START PERFORMANCE MONITORING
echo =========================
echo.
set /p log_path="Enter log directory path (default: %USERPROFILE%\WSL-Logs): "
if "%log_path%"=="" set log_path=%USERPROFILE%\WSL-Logs
if not exist "%log_path%" mkdir "%log_path%"
set timestamp=%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%
echo Timestamp,Distribution,CPU%%,Memory(MB),DiskIO(MB/s) > "%log_path%\performance_%timestamp%.csv"
echo.
echo Monitoring started. Press Ctrl+C to stop.
:monitor_loop
for /f "tokens=2 delims= " %%i in ('wsl --list --quiet ^| findstr /v "Windows"') do (
    set timestamp=%date:~-4,4%-%date:~-10,2%-%date:~-7,2% %time:~0,2%:%time:~3,2%:%time:~6,2%
    for /f "tokens=*" %%j in ('wsl -d %%i top -bn1 ^| findstr "Cpu(s)"') do set cpu=%%j
    for /f "tokens=*" %%j in ('wsl -d %%i free -m ^| findstr "Mem:"') do set memory=%%j
    for /f "tokens=*" %%j in ('wsl -d %%i iostat -d ^| findstr "sda"') do set diskio=%%j
    echo %timestamp%,%%i,!cpu!,!memory!,!diskio! >> "%log_path%\performance_%timestamp%.csv"
)
timeout /t 5
goto monitor_loop

:VIEW_LOGS
cls
echo VIEW PERFORMANCE LOGS
echo ===================
echo.
set /p log_path="Enter log directory path (default: %USERPROFILE%\WSL-Logs): "
if "%log_path%"=="" set log_path=%USERPROFILE%\WSL-Logs
if not exist "%log_path%" (
    echo Log directory not found.
    pause
    goto PERFORMANCE_MONITOR
)
dir /b "%log_path%\performance_*.csv"
echo.
set /p log_file="Enter log file name: "
type "%log_path%\%log_file%"
echo.
pause
goto PERFORMANCE_MONITOR

:CONFIGURE_MONITORING
cls
echo CONFIGURE MONITORING
echo ==================
echo.
set /p interval="Enter monitoring interval in seconds (default: 5): "
if "%interval%"=="" set interval=5
set /p retention="Enter log retention period in days (default: 7): "
if "%retention%"=="" set retention=7
echo {"interval":%interval%,"retention":%retention%} > "%USERPROFILE%\WSL-Logs\monitor_config.json"
echo Configuration saved successfully.
pause
goto PERFORMANCE_MONITOR

:CONFIG_PROFILES
cls
echo WSL CONFIGURATION PROFILES
echo ========================
echo.
echo 1. Create New Profile
echo 2. Apply Profile
echo 3. List Profiles
echo 4. Delete Profile
echo 5. Back to Main Menu
echo.
set /p profile_choice="Select an option (1-5): "

if "%profile_choice%"=="1" call :CREATE_PROFILE
if "%profile_choice%"=="2" call :APPLY_PROFILE
if "%profile_choice%"=="3" call :LIST_PROFILES
if "%profile_choice%"=="4" call :DELETE_PROFILE
if "%profile_choice%"=="5" goto MAIN_MENU

goto CONFIG_PROFILES

:CREATE_PROFILE
cls
echo CREATE NEW PROFILE
echo ================
echo.
set /p profile_name="Enter profile name: "
set /p memory="Enter memory limit in GB: "
set /p processors="Enter number of processors: "
set /p swap="Enter swap size in GB: "
set /p forwarding="Enable localhost forwarding? (Y/N): "
set /p kernel="Enter kernel command line options (optional): "
if not exist "%USERPROFILE%\WSL-Profiles" mkdir "%USERPROFILE%\WSL-Profiles"
echo {"name":"%profile_name%","memory":%memory%,"processors":%processors%,"swap":%swap%,"localhostForwarding":"%forwarding%","kernelCommandLine":"%kernel%"} > "%USERPROFILE%\WSL-Profiles\%profile_name%.json"
echo Profile created successfully.
pause
goto CONFIG_PROFILES

:APPLY_PROFILE
cls
echo APPLY PROFILE
echo ===========
echo.
if not exist "%USERPROFILE%\WSL-Profiles" (
    echo No profiles found.
    pause
    goto CONFIG_PROFILES
)
dir /b "%USERPROFILE%\WSL-Profiles\*.json"
echo.
set /p profile="Enter profile name: "
if not exist "%USERPROFILE%\WSL-Profiles\%profile%.json" (
    echo Profile not found.
    pause
    goto CONFIG_PROFILES
)
for /f "tokens=*" %%i in ('type "%USERPROFILE%\WSL-Profiles\%profile%.json"') do set profile_data=%%i
echo [wsl2] > %USERPROFILE%\.wslconfig
echo memory=!profile_data:memory=!GB >> %USERPROFILE%\.wslconfig
echo processors=!profile_data:processors=! >> %USERPROFILE%\.wslconfig
echo swap=!profile_data:swap=!GB >> %USERPROFILE%\.wslconfig
echo localhostForwarding=!profile_data:localhostForwarding=! >> %USERPROFILE%\.wslconfig
echo kernelCommandLine=!profile_data:kernelCommandLine=! >> %USERPROFILE%\.wslconfig
echo Profile applied successfully. Please restart WSL for changes to take effect.
echo Run 'wsl --shutdown' to restart WSL
pause
goto CONFIG_PROFILES

:LIST_PROFILES
cls
echo LIST PROFILES
echo ============
echo.
if not exist "%USERPROFILE%\WSL-Profiles" (
    echo No profiles found.
    pause
    goto CONFIG_PROFILES
)
dir /b "%USERPROFILE%\WSL-Profiles\*.json"
echo.
for %%i in ("%USERPROFILE%\WSL-Profiles\*.json") do (
    echo Profile: %%~ni
    type "%%i"
    echo.
)
pause
goto CONFIG_PROFILES

:DELETE_PROFILE
cls
echo DELETE PROFILE
echo ============
echo.
if not exist "%USERPROFILE%\WSL-Profiles" (
    echo No profiles found.
    pause
    goto CONFIG_PROFILES
)
dir /b "%USERPROFILE%\WSL-Profiles\*.json"
echo.
set /p profile="Enter profile name to delete: "
if not exist "%USERPROFILE%\WSL-Profiles\%profile%.json" (
    echo Profile not found.
    pause
    goto CONFIG_PROFILES
)
del "%USERPROFILE%\WSL-Profiles\%profile%.json"
echo Profile deleted successfully.
pause
goto CONFIG_PROFILES

:PACKAGE_MANAGEMENT
cls
echo WSL PACKAGE MANAGEMENT
echo ====================
echo.
wsl --list --verbose
echo.
set /p distro="Enter distribution name: "
echo.
echo 1. Update Package List
echo 2. Upgrade Packages
echo 3. Install Package
echo 4. Remove Package
echo 5. List Installed Packages
echo 6. Back to Main Menu
echo.
set /p package_choice="Select an option (1-6): "

if "%package_choice%"=="1" wsl -d %distro% bash -c "sudo apt update"
if "%package_choice%"=="2" wsl -d %distro% bash -c "sudo apt upgrade -y"
if "%package_choice%"=="3" (
    set /p package="Enter package name to install: "
    wsl -d %distro% bash -c "sudo apt install -y %package%"
)
if "%package_choice%"=="4" (
    set /p package="Enter package name to remove: "
    wsl -d %distro% bash -c "sudo apt remove -y %package%"
)
if "%package_choice%"=="5" wsl -d %distro% bash -c "dpkg -l | grep '^ii'"
if "%package_choice%"=="6" goto MAIN_MENU

pause
goto PACKAGE_MANAGEMENT

:HEALTH_CHECK
cls
echo WSL HEALTH CHECK
echo ==============
echo.
echo Checking WSL version and status...
wsl --status
echo.
echo Checking Windows features...
dism /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism /online /get-featureinfo /featurename:VirtualMachinePlatform
echo.
echo Checking distributions...
wsl --list --verbose
echo.
echo Checking network adapter...
netsh interface show interface | findstr "WSL"
echo.
echo Checking for common issues...
if exist "%USERPROFILE%\.wslconfig" (
    echo WSL configuration file exists
) else (
    echo No WSL configuration file found
)
echo.
echo Health check completed.
pause
goto MAIN_MENU 