import subprocess
import re
import time

# Function to log and execute commands
def invoke_logged_command(command):
    print(f"Executing: {command}")
    return subprocess.run(command, shell=True, capture_output=True, text=True)

# Function to get or start a WSL2 instance
def get_or_start_wsl2_instance():
    wsl_output = subprocess.check_output(["wsl", "-l", "-v"], text=True)
    wsl_instances = [re.sub(r'\s+', '', line.split()[1]) for line in wsl_output.splitlines()[1:] if "2" in line and "docker" not in line]
    
    if not wsl_instances:
        print("No WSL2 instance found.")
        return None
    else:
        instance_name = wsl_instances[0]
        instance_name = re.sub(r'\s+', '', instance_name)  # Remove all whitespace
        print(f"Using WSL2 instance: {instance_name}")
        return instance_name

# Function to check WSL2 internet connectivity
def test_wsl2_internet(instance):
    try:
        instance = instance.replace(" ", "")  # Remove spaces from the instance name
        command = f'wsl.exe -d "{instance}" -- ping -c 4 -W 10 google.com'
        print(f"Executing: {command}")
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        
        if "bytes from" in result.stdout:
            print(f"WSL2 instance '{instance}' has internet connectivity.")
            print("Ping result:")
            print(result.stdout)
            return True
        else:
            print(f"WSL2 instance '{instance}' does not have internet connectivity.")
            print("Ping result:")
            print(result.stdout)
            return False
    except Exception as e:
        print(f"Error occurred while testing WSL2 internet connection for instance '{instance}'.")
        print(f"Error details: {str(e)}")
        return False

# Function to reset WSL2 networking
def reset_wsl2_networking():
    print("Attempting to reset WSL2 networking...")

    # 1. Shut down WSL
    print("Shutting down WSL2...")
    invoke_logged_command("wsl --shutdown")

    # 2. Check for WSL-related network adapters
    adapters_output = invoke_logged_command("powershell -Command \"Get-NetAdapter | Where-Object { $_.Name -like '*WSL*' -or $_.Name -like '*vEthernet*' } | Select-Object -ExpandProperty Name\"")
    wsl_adapters = adapters_output.stdout.strip().split('\n')

    if wsl_adapters:
        for adapter in wsl_adapters:
            print(f"Resetting adapter: {adapter}")
            invoke_logged_command(f"powershell -Command \"Disable-NetAdapter -Name '{adapter}' -Confirm:$false\"")
            time.sleep(2)
            invoke_logged_command(f"powershell -Command \"Enable-NetAdapter -Name '{adapter}' -Confirm:$false\"")
    else:
        print("No WSL-related network adapters found. Skipping adapter reset.")

    # 3. Restart WSL2
    print("Restarting WSL2...")
    invoke_logged_command("wsl")

    print("WSL2 networking reset attempt complete.")

# Function to check and fix WSL2 internet connection
def test_and_repair_wsl2_internet():
    # Get or start a WSL2 instance
    instance = get_or_start_wsl2_instance()

    if instance is None:
        print("No WSL2 instances available to check.")
        return

    print(f"Checking WSL2 internet connection for instance '{instance}'...")
    internet_working = test_wsl2_internet(instance)

    if not internet_working:
        print(f"Internet is not working for WSL2 instance '{instance}'. Attempting to reset WSL2 networking...")
        reset_wsl2_networking()

        # Recheck the internet connection
        print(f"Rechecking WSL2 internet connection for instance '{instance}'...")
        internet_working = test_wsl2_internet(instance)

        if internet_working:
            print(f"WSL2 internet connection for instance '{instance}' is now working.")
        else:
            print(f"WSL2 internet connection for instance '{instance}' is still not working after reset.")

# Run the script
if __name__ == "__main__":
    test_and_repair_wsl2_internet()
