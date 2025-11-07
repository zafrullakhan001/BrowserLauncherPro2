#!/usr/bin/env python3

# Disable creation of __pycache__ directories
import sys
sys.dont_write_bytecode = True

import struct
import subprocess
import logging
from logging.handlers import RotatingFileHandler
from typing import Dict, Any, Optional
import ujson
import time
import signal
import configparser
import psutil
import os
import re
import platform
import winreg
import socket
import uuid
import json

# Function to check and install required modules
def check_and_install_modules(modules):
    import importlib

    for module in modules:
        try:
            importlib.import_module(module)
        except ImportError:
            subprocess.check_call([sys.executable, "-m", "pip", "install", module])
            importlib.invalidate_caches()  # Ensure the newly installed module is found

# List of required modules
required_modules = ["ujson", "psutil", "configparser", "psutil", "os"]

# Check and install required modules only once
if not hasattr(sys, "_modules_checked"):
    check_and_install_modules(required_modules)
    sys._modules_checked = True
    logging.info("Module check and installation completed. This check will not be performed again.")

# Try importing ujson after ensuring it is installed
try:
    import ujson
except ImportError:
    logging.error("Failed to import ujson even after installation attempt.")
    sys.exit(1)

# Constants for logging
LOG_FILENAME = "BrowserLauncher.log"
LOG_MAX_SIZE = 5 * 1024 * 1024  # 5 MB
LOG_BACKUP_COUNT = 1

# Constants for browser path detection logging
BROWSER_PATH_LOG_FILENAME = "BrowserPathDetection.log"
BROWSER_PATH_LOG_MAX_SIZE = 5 * 1024 * 1024  # 5 MB
BROWSER_PATH_LOG_BACKUP_COUNT = 1

# Set up the main logger
def setup_logger():
    logger = logging.getLogger('BrowserLauncher')
    logger.setLevel(logging.DEBUG)
    
    # Remove any existing handlers to avoid duplicates
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Create a rotating file handler
    file_handler = RotatingFileHandler(
        LOG_FILENAME,
        maxBytes=LOG_MAX_SIZE,
        backupCount=LOG_BACKUP_COUNT
    )
    file_handler.setLevel(logging.DEBUG)
    
    # Create a formatter
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    
    # Add the handler to the logger
    logger.addHandler(file_handler)
    
    return logger

# Set up the browser path detection logger
def setup_browser_path_logger():
    logger = logging.getLogger('BrowserPathDetection')
    logger.setLevel(logging.DEBUG)
    
    # Remove any existing handlers to avoid duplicates
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Create a rotating file handler
    file_handler = RotatingFileHandler(
        BROWSER_PATH_LOG_FILENAME,
        maxBytes=BROWSER_PATH_LOG_MAX_SIZE,
        backupCount=BROWSER_PATH_LOG_BACKUP_COUNT
    )
    file_handler.setLevel(logging.DEBUG)
    
    # Create a formatter
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    
    # Add the handler to the logger
    logger.addHandler(file_handler)
    
    return logger

# Initialize loggers
logger = setup_logger()
browser_path_logger = setup_browser_path_logger()

def get_message() -> Optional[Dict[str, Any]]:
    """Reads a message from the input stream (stdin) and returns it as a dictionary."""
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) == 0:
        logging.info("No raw_length received")
        return None
    message_length = struct.unpack("@I", raw_length)[0]
    message = sys.stdin.buffer.read(message_length).decode("utf-8")
    logging.debug(f"Received message: {message}")
    return ujson.loads(message)

def send_message(message: Dict[str, Any]) -> None:
    """Sends a message to the output stream (stdout)."""
    message_json = ujson.dumps(message).encode("utf-8")
    packed_message = struct.pack("@I", len(message_json)) + message_json
    sys.stdout.buffer.write(packed_message)
    sys.stdout.buffer.flush()
    logging.debug(f'Sent message: {message_json.decode("utf-8")}')

def run_command(command: str) -> str:
    """Runs a shell command with improved error handling and timeout."""
    try:
        logging.debug(f"Running command: {command}")
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True,
            text=True,
            encoding='utf-8',
            errors='replace'
        )
        
        try:
            stdout, stderr = process.communicate(timeout=10)  # 10 second timeout
            if process.returncode != 0:
                error_message = f'Command failed with return code {process.returncode}: {stderr}'
                logging.error(error_message)
                return error_message
            
            result = stdout.strip()
            logging.debug(f"Command result: {result}")
            return result
            
        except subprocess.TimeoutExpired:
            process.kill()
            logging.error("Command timed out")
            return "Error: Command timed out"
            
    except Exception as e:
        error_message = f"Error running command: {str(e)}"
        logging.error(error_message)
        return error_message

def run_command_with_retry(command: str, url: Optional[str], max_retries: int = 3, retry_delay: float = 1.0) -> str:
    """Runs a command with retry logic, handling 'runas' if required."""
    for attempt in range(max_retries):
        try:
            result = run_command_with_url(command, url)
            if "Error" not in result:
                return result
            logging.warning(f"Command failed (attempt {attempt + 1}/{max_retries}): {result}")
            time.sleep(retry_delay)
        except Exception as e:
            logging.error(f"Exception occurred (attempt {attempt + 1}/{max_retries}): {e}")
            time.sleep(retry_delay)
    return f"Command failed after {max_retries} attempts"

import psutil

def is_sandbox_running():
    """Check if Windows Sandbox is already running."""
    for proc in psutil.process_iter(['name']):
        if proc.info['name'] and proc.info['name'].lower() == 'windowssandbox.exe':
            return True
    return False

def open_url_in_sandbox_edge(url):
    """
    Opens a URL in an already running Windows Sandbox instance
    using a direct URL approach.
    """
    try:
        import os
        import time
        
        # Create files in the Documents folder (mapped to Sandbox)
        user_profile = os.path.expandvars("%USERPROFILE%")
        docs_path = os.path.join(user_profile, "Documents")
        
        # Create a unique filename with timestamp
        timestamp = int(time.time())
        
        # Escape quotes in the URL to prevent batch file issues
        escaped_url = url.replace('"', '""')
        
        # Create a batch file to launch Edge with the URL directly
        batch_filename = f"open_url_{timestamp}.bat"
        batch_path = os.path.join(docs_path, batch_filename)
        
        # Create batch file that directly launches Edge with the URL
        batch_content = f'@echo off\r\nstart "" "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe" "{escaped_url}"\r\n'
        
        # Write the batch file
        with open(batch_path, 'w', encoding='utf-8') as f:
            f.write(batch_content)
        
        # Log action
        logging.info(f"Created URL launcher batch file at {batch_path}")
        
        # Return success message
        return f"URL launcher created for already running Windows Sandbox. The URL should open in a new tab."
    except Exception as e:
        error_msg = f"Error creating URL launcher: {str(e)}"
        logging.error(error_msg)
        return error_msg

def open_in_sandbox(url):
    """Open a URL in Windows Sandbox with direct URL embedding."""
    try:
        # Check if Windows Sandbox is already running
        if is_sandbox_running():
            return open_url_in_sandbox_edge(url)
        
        import os
        import subprocess
        import time
        
        # Full path to Windows Sandbox executable
        sandbox_path = os.path.expandvars(r"%windir%\system32\WindowsSandbox.exe")
        
        # Make sure the sandbox executable exists
        if not os.path.exists(sandbox_path):
            return f"Error: Windows Sandbox executable not found at {sandbox_path}"
        
        # Create a configuration file in the user's Documents folder
        user_profile = os.path.expandvars("%USERPROFILE%")
        docs_path = os.path.join(user_profile, "Documents")
        
        # Create a unique filename with timestamp
        timestamp = int(time.time())
        wsb_filename = f"sandbox_config_{timestamp}.wsb"
        wsb_path = os.path.join(docs_path, wsb_filename)
        
        # Escape quotes in the URL to prevent HTML/JavaScript injection
        escaped_url = url.replace('"', '&quot;')
        
        # Create a simpler HTML file that directly uses meta refresh
        html_filename = f"redirect_{timestamp}.html"
        html_path = os.path.join(docs_path, html_filename)
        
        # Use meta refresh tag for immediate redirect
        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Redirecting...</title>
    <meta http-equiv="refresh" content="0;URL='{escaped_url}'">
    <script>
        window.location.href = "{escaped_url}";
    </script>
</head>
<body>
    <h2>Redirecting to: {escaped_url}</h2>
    <p>If you are not redirected automatically, click <a href="{escaped_url}">here</a>.</p>
</body>
</html>"""
        
        # Write the HTML file
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        # Create a batch file to launch Edge with the local HTML file
        batch_filename = f"launch_url_{timestamp}.bat"
        batch_path = os.path.join(docs_path, batch_filename)
        
        # Use direct URL to avoid file:// protocol
        batch_content = f'@echo off\r\nstart "" "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe" "{escaped_url}"\r\n'
        
        # Write the batch file
        with open(batch_path, 'w', encoding='utf-8') as f:
            f.write(batch_content)
        
        # Create the WSB configuration with ReadOnly set to false
        folder_name = docs_path.split('\\')[-1]
        wsb_config = f"""<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>{docs_path}</HostFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>C:\\Users\\WDAGUtilityAccount\\Desktop\\{folder_name}\\{batch_filename}</Command>
  </LogonCommand>
</Configuration>"""
        
        # Write the configuration file
        with open(wsb_path, 'w', encoding='utf-8') as f:
            f.write(wsb_config)
        
        # Make sure files were created
        if not os.path.exists(wsb_path) or not os.path.exists(batch_path):
            return f"Error: Failed to create required files in {docs_path}"
        
        # Log file locations for debugging
        logging.info(f"Created config at {wsb_path} and batch at {batch_path}")
        
        # Launch sandbox with the configuration
        cmd = f'"{sandbox_path}" "{wsb_path}"'
        logging.info(f"Executing command: {cmd}")
        
        # Use subprocess.Popen to launch the sandbox
        subprocess.Popen(cmd, shell=True)
        
        # Allow some time for Windows Sandbox to launch before returning
        time.sleep(2)
        
        return f"Opening {url} in Windows Sandbox"
    except Exception as e:
        error_msg = f"Error: Failed to open Windows Sandbox: {str(e)}"
        logging.error(error_msg)
        return error_msg

def get_browser_version(registry_key: str) -> str:
    """Gets the browser version from the Windows registry with improved error handling and architecture support."""
    try:
        # First try the direct registry key
        command = f'reg query "{registry_key}" /v version'
        logging.debug(f"Running registry command: {command}")
        result = run_command(command)
        
        if "ERROR" in result or "The system was unable to find" in result:
            # If direct key fails, try WOW6432Node path if not already trying it
            if "WOW6432Node" not in registry_key:
                wow64_key = registry_key.replace("Software\\", "Software\\WOW6432Node\\")
                command = f'reg query "{wow64_key}" /v version'
                logging.debug(f"Trying WOW6432Node registry command: {command}")
                result = run_command(command)

        logging.debug(f"Registry query result: {result}")
        
        # Process the result
        if "ERROR" not in result and "The system was unable to find" not in result:
            for line in result.split("\n"):
                if "version" in line.lower():
                    version = line.split()[-1]
                    # Validate version format (should be like xx.x.xxx.xx)
                    if re.match(r'^\d+\.\d+\.\d+\.\d+$', version):
                        logging.debug(f"Extracted valid browser version: {version}")
                        return version
                    else:
                        logging.warning(f"Invalid version format found: {version}")
                        return f"Error: Invalid version format: {version}"
            
            logging.warning("Version not found in registry output")
            return "Error: Version not found in registry output"
        else:
            logging.warning(f"Registry key not found: {registry_key}")
            return f"Error: Registry key not found: {registry_key}"
            
    except Exception as e:
        error_message = f"Error getting browser version: {str(e)}"
        logging.error(error_message)
        return error_message

def get_wsl_instances():
    """Gets a list of installed WSL instances."""
    try:
        result = run_command("wsl --list --quiet")
        instances = result.split("\n")
        # Remove empty strings and strip whitespace
        instances = [instance.strip() for instance in instances if instance.strip()]
        # Remove null characters and decode properly
        instances = [
            instance.replace("\x00", "").encode("utf-16-le").decode("utf-16-le")
            for instance in instances
        ]
        logging.debug(f"WSL instances: {instances}")
        return instances
    except Exception as e:
        logging.error(f"Error getting WSL instances: {e}")
        return []

def create_wsl_instance():
    """Creates a new WSL instance (handled by the extension)."""
    return "WSL instance creation is handled by the extension. Please check the PowerShell window for details."

def delete_wsl_instance(instance):
    """Deletes a specified WSL instance."""
    try:
        result = run_command(f"wsl --unregister {instance}")
        logging.info(f"Deleted WSL instance: {instance}")
        return f"Deleted WSL instance: {instance}"
    except Exception as e:
        logging.error(f"Error deleting WSL instance: {e}")
        return f"Error deleting WSL instance: {e}"

def reinstate_wsl_instance(instance):
    """Reinstates a WSL instance by unregistering, reinstalling, and setting up browsers."""
    try:
        run_command(f"wsl --unregister {instance}")
        run_command(f"wsl --install -d {instance}")
        run_command(f'wsl -d {instance} bash -c "./wslscripts/wsl-install-browsers.sh"')
        logging.info(f"Reinstated WSL instance: {instance}")
        return f"Reinstated WSL instance: {instance}"
    except Exception as e:
        logging.error(f"Error reinstating WSL instance: {e}")
        return f"Error reinstating WSL instance: {e}"

def check_wsl_instance_folder(instance):
    """Checks if a folder for a WSL instance exists."""
    try:
        wsl_dir = f"c:\\WSL\\{instance}"
        result = run_command(
            f'if exist "{wsl_dir}" (echo exists) else (echo available)'
        )
        return result.strip()
    except Exception as e:
        logging.error(f"Error checking WSL instance folder: {e}")
        return f"Error checking WSL instance folder: {e}"

def validate_input(message: Dict[str, Any]) -> bool:
    """Validates the input message to ensure it contains the required fields."""
    # Log the received message for debugging
    try:
        logging.debug(f"Validating message: {str(message)[:200]}...")
    except Exception as e:
        logging.error(f"Error logging message: {e}")
    
    if not isinstance(message, dict):
        logging.error("Message is not a dictionary")
        return False

    if "action" in message:
        action = message["action"]
        logging.debug(f"Validating action: {action}")
        
        if not isinstance(action, str):
            logging.error("'action' is not a string")
            return False
        if action == "getBrowserVersion":
            if "registryKey" not in message or not isinstance(
                message["registryKey"], str
            ):
                logging.error(
                    "Missing or invalid 'registryKey' for 'getBrowserVersion' action"
                )
                return False
        elif action == "runCommand":
            if "command" not in message or not isinstance(message["command"], str):
                logging.error("Missing or invalid 'command' for 'runCommand' action")
                return False
        elif action == "openInSandbox":
            if "url" not in message or not isinstance(message["url"], str):
                logging.error("Missing or invalid 'url' for 'openInSandbox' action")
                return False
        elif action == "executePowerShellScript":
            if "scriptPath" not in message or not isinstance(message["scriptPath"], str):
                logging.error("Missing or invalid 'scriptPath' for 'executePowerShellScript' action")
                return False
        elif action in [
            "getWSLInstances",
            "createWSLInstance",
            "checkWSLInstanceFolder",
            "getHardwareInfo",  
            "ping"              
        ]:
            if action == "checkWSLInstanceFolder":
                if "instance" not in message or not isinstance(
                    message["instance"], str
                ):
                    logging.error(
                        "Missing or invalid 'instance' for 'checkWSLInstanceFolder' action"
                    )
                    return False
            return True
        elif action in ["deleteWSLInstance", "reinstateWSLInstance"]:
            if "instance" not in message or not isinstance(message["instance"], str):
                logging.error(
                    f"Missing or invalid 'instance' for '{action}' action"
                )
                return False
        else:
            logging.error(f"Unknown action: {action}")
            return False
    elif "command" in message:
        if not isinstance(message["command"], str):
            logging.error("'command' is not a string")
            return False
        return True
    else:
        logging.error("Message does not contain 'action' or 'command'")
        return False

    return True

def signal_handler(signum, frame):
    """Handles system signals for graceful shutdown."""
    logging.info(f"Received signal {signum}. Shutting down...")
    sys.exit(0)

def load_config(config_file: str = "config.ini") -> configparser.ConfigParser:
    """Loads configuration from a file."""
    config = configparser.ConfigParser()
    config.read(config_file)
    return config

def run_command_with_url(command: str, url: Optional[str], timeout: int = 30) -> str:
    """Runs a shell command with a URL and handles 'runas' for privilege elevation."""
    try:
        # Check if the command requires `runas.exe`
        if command.startswith("runas"):
            full_command = command  # runas command should be passed as-is
        else:
            if command.startswith("cmd /c start powershell.exe"):
                full_command = command  # Don't add URL for PowerShell
            elif "wsl" in command.lower():
                # Special handling for browsers in WSL
                if "firefox" in command.lower():
                    # Firefox needs special handling with DISPLAY environment variable
                    # Use -new-tab to ensure the URL opens in a new tab if Firefox is already running
                    full_command = f'{command} -new-tab "{url}"' if url else command
                elif "chrome" in command.lower() or "edge" in command.lower():
                    # Add --no-sandbox for Chrome and Edge in WSL
                    full_command = f'{command} --no-sandbox "{url}"' if url else f'{command} --no-sandbox'
                else:
                    full_command = f'{command} "{url}"' if url else command
            elif command.strip().lower() == "windowssandbox":
                # Always use the open_in_sandbox function which now handles already running instances
                if url:
                    return open_in_sandbox(url)
                else:
                    # Just launch Sandbox without a URL if none provided
                    sandbox_path = os.path.expandvars(r"%windir%\system32\WindowsSandbox.exe")
                    full_command = f'"{sandbox_path}"'
            else:
                # For Windows local browsers, ensure proper quoting
                if command.endswith('.exe') or command.endswith('.EXE'):
                    full_command = f'"{command}" "{url}"' if url else f'"{command}"'
                else:
                    full_command = f'{command} "{url}"' if url else command

        logging.debug(f"Running command: {full_command}")
        
        # Use subprocess.Popen with shell=True for Windows
        if os.name == 'nt':
            process = subprocess.Popen(
                full_command, 
                stdout=subprocess.PIPE, 
                stderr=subprocess.PIPE, 
                shell=True,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
        else:
            # For non-Windows systems
            process = subprocess.Popen(
                full_command, 
                stdout=subprocess.PIPE, 
                stderr=subprocess.PIPE, 
                shell=True
            )
            
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            stdout, stderr = process.communicate()
            return f"Command timed out after {timeout} seconds"

        if process.returncode != 0 and stderr:
            error_text = stderr.decode("utf-8", errors="replace").strip()
            logging.error(f"Command failed with exit code {process.returncode}: {error_text}")
            return f"Error: Command failed with exit code {process.returncode}: {error_text}"
            
        result = stdout.decode("utf-8", errors="replace").strip()
        logging.debug(f"Command result: {result}")
        return result
    except Exception as e:
        error_message = f"Error running command: {str(e)}"
        logging.error(error_message, exc_info=True)
        return error_message

def execute_powershell_script(script_path: str) -> str:
    """Execute a PowerShell script and return its output."""
    browser_path_logger.info(f"Executing PowerShell script: {script_path}")
    
    try:
        # Handle chrome-extension:// URLs
        if script_path.startswith('chrome-extension://'):
            # Get the path to the FindBrowserPaths.ps1 in the current working directory
            # since Chrome extension resources can't be directly accessed by native messaging host
            script_path = os.path.join(os.getcwd(), "FindBrowserPaths.ps1")
            browser_path_logger.info(f"Using local script path instead of extension URL: {script_path}")
    except Exception as e:
        error_msg = f"Error converting extension URL to path: {str(e)}"
        browser_path_logger.error(error_msg)
        return error_msg
    
    # Convert to absolute path
    full_script_path = os.path.abspath(script_path)
    browser_path_logger.info(f"Full script path: {full_script_path}")
    
    # Check if script exists
    if not os.path.exists(full_script_path):
        error_msg = f"Script not found: {full_script_path}"
        browser_path_logger.error(error_msg)
        return error_msg
    
    try:
        browser_path_logger.info("Starting script execution")
        # Use a more robust approach to execute PowerShell
        cmd = ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", full_script_path]
        browser_path_logger.info(f"Executing command: {' '.join(cmd)}")
        
        # Run with a timeout to prevent hanging
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            timeout=60  # 60 second timeout
        )
        
        browser_path_logger.info("Script execution completed successfully")
        browser_path_logger.debug(f"Script output: {result.stdout[:200]}...")  # Log first 200 chars
        return result.stdout
    except subprocess.CalledProcessError as e:
        error_msg = f"Script execution failed with exit code {e.returncode}: {e.stderr}"
        browser_path_logger.error(error_msg)
        return error_msg
    except subprocess.TimeoutExpired:
        error_msg = "Script execution timed out after 60 seconds"
        browser_path_logger.error(error_msg)
        return error_msg
    except Exception as e:
        error_msg = f"Unexpected error during script execution: {str(e)}"
        browser_path_logger.error(error_msg)
        return error_msg

# Add a function to get hardware information for licensing
def get_hardware_info():
    """
    Collect hardware-specific information for license validation
    Returns a hardware fingerprint that can be used for license key validation
    """
    hardware_info = {}
    
    try:
        # Get system information
        hardware_info['platform'] = str(platform.system())
        hardware_info['processor'] = str(platform.processor())
        hardware_info['machine'] = str(platform.machine())
        hardware_info['node'] = str(platform.node())
        
        logging.info("Collecting hardware information for license validation")
        
        # Get MAC address (more unique than other identifiers)
        mac = get_mac_address()
        if mac:
            hardware_info['mac'] = str(mac)
            logging.info("MAC address collected successfully")
        else:
            logging.warning("Failed to collect MAC address")
            
        # Get volume serial number
        volume_serial = get_volume_serial()
        if volume_serial:
            hardware_info['volume_serial'] = str(volume_serial)
            logging.info("Volume serial collected successfully")
        else:
            logging.warning("Failed to collect volume serial number")
            
        # Get BIOS serial
        bios_serial = get_bios_serial()
        if bios_serial:
            hardware_info['bios_serial'] = str(bios_serial)
            logging.info("BIOS serial collected successfully")
        else:
            logging.warning("Failed to collect BIOS serial")
            
        # Get CPU ID
        cpu_id = get_cpu_id()
        if cpu_id:
            hardware_info['cpu_id'] = str(cpu_id)
            logging.info("CPU ID collected successfully")
        else:
            logging.warning("Failed to collect CPU ID")
            
        # Fallback to more generic methods if needed
        if len(hardware_info) < 3:
            logging.warning("Less than 3 hardware identifiers collected, falling back to generic methods")
            # Add hostname
            hardware_info['hostname'] = str(socket.gethostname())
            
            # Add Python-based UUID
            hardware_info['machine_id'] = str(uuid.getnode())
            
        logging.info(f"Hardware info collection complete. Collected {len(hardware_info)} data points")
        
        # Ensure all values are strings to prevent JSON serialization issues
        for key in hardware_info:
            if not isinstance(hardware_info[key], str):
                hardware_info[key] = str(hardware_info[key])
                
        # Debug the hardware info object
        logging.info(f"Final hardware_info content: {str(hardware_info)[:200]}...")
        
    except Exception as e:
        logging.error(f"Error getting hardware info: {str(e)}", exc_info=True)
        # Return minimal system info if we fail to get more specific hardware data
        fallback_info = {
            'platform': str(platform.system()),
            'hostname': str(socket.gethostname()),
            'machine_id': str(uuid.getnode()),
            'error': str(e)
        }
        logging.info(f"Returning fallback hardware info: {fallback_info}")
        return fallback_info
        
    return hardware_info

def get_mac_address():
    """Get the MAC address of the system"""
    try:
        mac = ':'.join(['{:02x}'.format((uuid.getnode() >> elements) & 0xff) 
                       for elements in range(0, 8*6, 8)][::-1])
        return mac
    except Exception as e:
        logging.error(f"Error getting MAC address: {str(e)}", exc_info=True)
        return None

def get_volume_serial():
    """Get the system drive's volume serial number"""
    try:
        if platform.system() == 'Windows':
            # Method 1: Use fsutil (recommended)
            result = subprocess.run(['fsutil', 'fsinfo', 'volumeinfo', 'C:'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                match = re.search(r'Volume Serial Number\s*:\s*([A-Z0-9\-]+)', result.stdout)
                if match:
                    return match.group(1)
                
            # Method 2: Try wmic as a backup method  
            result = subprocess.run(['wmic', 'volume', 'where', 'DriveLetter="C:"', 'get', 'SerialNumber'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    return lines[1].strip()
            
            # Method 3: Try vol as a fallback method (less reliable)
            result = subprocess.run(['cmd', '/c', 'vol', 'C:'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                match = re.search(r'Volume Serial Number is ([A-Z0-9\-]+)', result.stdout)
                if match:
                    return match.group(1)
                    
            logging.warning("All volume serial number collection methods failed")
        return None
    except Exception as e:
        logging.error(f"Error getting volume serial: {str(e)}", exc_info=True)
        return None

def get_bios_serial():
    """Get the BIOS serial number"""
    try:
        if platform.system() == 'Windows':
            result = subprocess.run(['wmic', 'bios', 'get', 'serialnumber'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    return lines[1].strip()
            else:
                logging.error(f"BIOS serial command failed with return code: {result.returncode}")
                logging.error(f"Error output: {result.stderr}")
        return None
    except Exception as e:
        logging.error(f"Error getting BIOS serial: {str(e)}", exc_info=True)
        return None

def get_cpu_id():
    """Get the CPU ID"""
    try:
        if platform.system() == 'Windows':
            result = subprocess.run(['wmic', 'cpu', 'get', 'processorid'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    return lines[1].strip()
            else:
                logging.error(f"CPU ID command failed with return code: {result.returncode}")
                logging.error(f"Error output: {result.stderr}")
        return None
    except Exception as e:
        logging.error(f"Error getting CPU ID: {str(e)}", exc_info=True)
        return None

def handle_message(message):
    """Handle incoming messages from the browser extension"""
    try:
        # Extract action from message
        action = message.get("action")
        
        # Handle hardware info request for license validation
        if action == 'getHardwareInfo':
            logging.info("Received getHardwareInfo request in handle_message function")
            try:
                hardware_info = get_hardware_info()
                logging.info(f"Hardware info collected in handle_message: {len(hardware_info)} data points")
                # Return hardware info directly, without wrapping it in another object
                return hardware_info
            except Exception as e:
                logging.error(f"Error collecting hardware info in handle_message: {str(e)}", exc_info=True)
                return {"error": f"Failed to collect hardware info: {str(e)}"}
        elif action == 'ping':
            system_info = {
                "platform": platform.system(),
                "version": platform.version(),
                "processor": platform.processor(),
                "timestamp": time.time()
            }
            return {'pong': True, 'system_info': system_info}
            
        # Handle other actions
        return {'success': False, 'error': 'Unknown action'}
        
    except Exception as e:
        logging.error(f"Error handling message: {str(e)}")
        return {'error': str(e)}

def main() -> None:
    """Main function to read messages and run commands."""
    logging.info("Native messaging host started")
    browser_path_logger.info("Native messaging host started - Browser path detection ready")
    while True:
        try:
            received_message = get_message()
            if received_message is None:
                logging.info("Received None message, exiting main loop")
                browser_path_logger.info("Received None message, exiting main loop")
                break

            if not validate_input(received_message):
                send_message({"error": "Invalid input"})
                continue

            if "action" in received_message:
                action = received_message["action"]
                logging.info(f"Received action: {action}")
                
                # Handle hardware info request for license validation
                if action == "getHardwareInfo":
                    try:
                        logging.info("Processing getHardwareInfo request in main function")
                        hardware_info = get_hardware_info()
                        
                        # Debug what get_hardware_info returns
                        logging.info(f"Hardware info collected: {str(hardware_info)[:100]}...")
                        
                        # DO NOT wrap the hardware info in a response object - just return it directly
                        # This fixes the client-side issue where it expects the hardware info directly
                        logging.info("Sending hardware info response directly without wrapping")
                        
                        # Ensure the response is JSON serializable
                        json_response = json.dumps(hardware_info)
                        logging.info(f"JSON serialized response length: {len(json_response)}")
                        
                        send_message(hardware_info)
                        logging.info("Hardware info response sent successfully")
                    except Exception as e:
                        error_msg = f"Error processing hardware info request: {str(e)}"
                        logging.error(error_msg, exc_info=True)
                        send_message({"error": error_msg})
                    continue
                # Handle ping request
                elif action == "ping":
                    system_info = {
                        "platform": platform.system(),
                        "version": platform.version(),
                        "processor": platform.processor(),
                        "timestamp": time.time()
                    }
                    send_message({"pong": True, "system_info": system_info})
                    continue
                # Get browser version from registry
                elif action == "getBrowserVersion":
                    registry_key = received_message.get("registryKey")
                    if registry_key:
                        version = get_browser_version(registry_key)
                        send_message({"version": version})
                    else:
                        send_message({"error": "No registry key provided"})
                    continue
                elif action == "openInSandbox":
                    url = received_message.get("url", "")
                    result = open_in_sandbox(url)
                    send_message({"result": result})
                elif action == "runCommand":
                    command = received_message["command"]
                    url = received_message.get("url", "")
                    result = run_command_with_retry(command, url)
                    send_message({"result": result})
                elif action == "executePowerShellScript":
                    script_path = received_message["scriptPath"]
                    browser_path_logger.info(f"Received request to execute PowerShell script: {script_path}")
                    result = execute_powershell_script(script_path)
                    browser_path_logger.info(f"PowerShell script execution completed with result: {result[:100]}...")
                    send_message({"result": result})
                elif action == "getWSLInstances":
                    instances = get_wsl_instances()
                    send_message({"instances": instances})
                elif action == "createWSLInstance":
                    result = "WSL instance creation is handled by the extension. Please check the PowerShell window for details."
                    send_message({"result": result})
                elif action == "deleteWSLInstance":
                    instance = received_message["instance"]
                    result = delete_wsl_instance(instance)
                    send_message({"result": result})
                elif action == "reinstateWSLInstance":
                    instance = received_message["instance"]
                    result = reinstate_wsl_instance(instance)
                    send_message({"result": result})
                elif action == "checkWSLInstanceFolder":
                    instance = received_message["instance"]
                    result = check_wsl_instance_folder(instance)
                    send_message({"result": result})
                else:
                    logging.error("Invalid message received: unknown action")
                    send_message({"error": "Unknown action"})
            elif "command" in received_message:
                command = received_message["command"]
                url = received_message.get("url", "")
                result = run_command_with_retry(command, url)
                send_message({"result": result})
            else:
                logging.error("Invalid message received: missing action or command")
                send_message({"error": "Missing action or command"})
        except Exception as e:
            logging.error(f"Error in main loop: {e}")
            browser_path_logger.error(f"Error in main loop: {e}")
            send_message({"error": str(e)})

if __name__ == "__main__":
    # Load configuration
    config = load_config()
    LOG_FILENAME = config.get("Logging", "filename", fallback="BrowserLauncher.log")
    LOG_MAX_SIZE = config.getint("Logging", "max_size", fallback=10 * 1024 * 1024)
    LOG_BACKUP_COUNT = config.getint("Logging", "backup_count", fallback=1)

    # Set up logging
    setup_logger()

    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Start the main loop
    main()