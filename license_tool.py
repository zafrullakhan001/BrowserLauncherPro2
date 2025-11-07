#!/usr/bin/env python
"""
Browser Launcher Pro - License Key Generator Tool
For development and testing use only.
"""

import argparse
import random
import string
import hashlib
import datetime
import sys

def generate_license_key(hardware_id, expires=None):
    """
    Generate a license key for a given hardware ID.
    The license key will be valid for the given hardware ID.
    """
    # Use first 8 characters of hardware ID
    hw_prefix = hardware_id[:8] if len(hardware_id) >= 8 else hardware_id
    
    # Create random parts
    random_part = ''.join(random.choices(string.ascii_uppercase + string.digits, k=16))
    
    # Add timestamp part
    timestamp = datetime.datetime.now().strftime("%y%m%d")
    
    # Combine parts (timestamp + random + hardware)
    license_key = f"{timestamp}-{random_part}-{hw_prefix}"
    
    return license_key

def main():
    parser = argparse.ArgumentParser(description='Browser Launcher Pro License Key Generator')
    parser.add_argument('hardware_id', help='Hardware ID to generate license key for')
    parser.add_argument('--expires', help='Expiration date (YYYY-MM-DD)', default=None)
    
    args = parser.parse_args()
    
    license_key = generate_license_key(args.hardware_id, args.expires)
    
    print("\nBrowser Launcher Pro - License Key Generator")
    print("--------------------------------------------")
    print(f"Hardware ID: {args.hardware_id}")
    if args.expires:
        print(f"Expires: {args.expires}")
    print(f"\nLicense Key: {license_key}\n")
    print("Note: This key is for development and testing purposes only.")
    
if __name__ == "__main__":
    main() 