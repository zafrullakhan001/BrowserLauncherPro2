#!/usr/bin/env python3

import sys
import json
import struct
import subprocess
import time
import os

def send_message(message):
    """Sends a message to the native messaging host."""
    # Convert message to JSON and encode
    encoded_message = json.dumps(message).encode('utf-8')
    # Write message length
    sys.stdout.buffer.write(struct.pack('@I', len(encoded_message)))
    # Write the message itself
    sys.stdout.buffer.write(encoded_message)
    sys.stdout.buffer.flush()

def read_message():
    """Reads a message from the native messaging host."""
    # Read the message length (first 4 bytes)
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length:
        return None
    message_length = struct.unpack('@I', raw_length)[0]
    # Read the message itself
    message = sys.stdin.buffer.read(message_length).decode('utf-8')
    return json.loads(message)

def test_registry_keys():
    """Test if registry keys exist"""
    registry_keys = [
        "HKEY_CURRENT_USER\\Software\\Microsoft\\Edge\\BLBeacon",
        "HKEY_CURRENT_USER\\Software\\Google\\Chrome\\BLBeacon",
        "HKEY_CURRENT_USER\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.example.browserlauncher",
        "HKEY_CURRENT_USER\\Software\\Microsoft\\Edge\\NativeMessagingHosts\\com.example.browserlauncher"
    ]
    
    print("\nTesting Registry Keys:")
    for key in registry_keys:
        result = subprocess.run(['reg', 'query', key], capture_output=True, text=True)
        print(f"\nKey: {key}")
        print(f"Exists: {result.returncode == 0}")
        if result.returncode == 0:
            print(f"Content:\n{result.stdout}")
        else:
            print(f"Error: {result.stderr}")

def test_native_messaging():
    """Test different native messaging commands with enhanced error handling."""
    # Check if native_messaging.py exists
    if not os.path.exists('native_messaging.py'):
        print("Error: native_messaging.py not found in current directory")
        return

    # Check if manifest file exists
    manifest_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'com.example.browserlauncher.json')
    if not os.path.exists(manifest_path):
        print(f"Warning: Manifest file not found at {manifest_path}")
    else:
        with open(manifest_path, 'r') as f:
            print(f"\nManifest content:\n{json.dumps(json.load(f), indent=2)}")

    test_cases = [
        {
            "action": "getBrowserVersion",
            "registryKey": "HKEY_CURRENT_USER\\Software\\Microsoft\\Edge\\BLBeacon"
        },
        {
            "action": "getBrowserVersion",
            "registryKey": "HKEY_CURRENT_USER\\Software\\Google\\Chrome\\BLBeacon"
        }
    ]

    print("\nStarting native messaging process...")
    process = subprocess.Popen(
        ['python', 'native_messaging.py'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    try:
        for test_case in test_cases:
            print(f"\nTesting: {test_case['action']}")
            print(f"Input: {json.dumps(test_case, indent=2)}")
            
            try:
                # Send message to the process
                encoded_message = json.dumps(test_case).encode('utf-8')
                process.stdin.write(struct.pack('@I', len(encoded_message)))
                process.stdin.write(encoded_message)
                process.stdin.flush()

                # Read response with timeout
                raw_length = process.stdout.read(4)
                if raw_length:
                    message_length = struct.unpack('@I', raw_length)[0]
                    message = process.stdout.read(message_length).decode('utf-8')
                    print(f"Response: {json.dumps(json.loads(message), indent=2)}")
                else:
                    print("Error: No response received")
                    
                # Check for any stderr output
                stderr_output = process.stderr.read1().decode('utf-8')
                if stderr_output:
                    print(f"stderr output: {stderr_output}")
                    
            except Exception as e:
                print(f"Error during test case: {e}")
            
            time.sleep(1)

    except Exception as e:
        print(f"Error during testing: {e}")
    finally:
        process.terminate()
        stdout, stderr = process.communicate()
        if stderr:
            print(f"\nFinal stderr output: {stderr.decode('utf-8')}")

def main():
    print("=== Native Messaging Test Suite ===")
    print("\nStep 1: Testing Registry Keys")
    test_registry_keys()
    
    print("\nStep 2: Testing Native Messaging")
    test_native_messaging()
    
    print("\nStep 3: Checking Log File")
    log_file = "BrowserLauncher.log"
    if os.path.exists(log_file):
        print(f"\nLast 10 lines of {log_file}:")
        with open(log_file, 'r') as f:
            lines = f.readlines()
            for line in lines[-10:]:
                print(line.strip())
    else:
        print(f"\nLog file {log_file} not found")

if __name__ == "__main__":
    main() 