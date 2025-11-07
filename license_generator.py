#!/usr/bin/env python3
"""
License Key Generator for Browser Launcher Pro

This script generates license keys with embedded encrypted metadata 
that are locked to specific hardware IDs.

Features:
- Hardware ID binding to prevent license sharing
- Embedded metadata (name, email, dates, etc.)
- Support for subscription or lifetime licenses
"""

import argparse
import base64
import datetime
import hashlib
import json
import os
import random
import string
import sys

# Simple obfuscation key (not secure, but good enough for demo)
OBFUSCATION_KEY = "PGdYL2f8RQzcBm4KsX9JtEwU3vN7V6h5"

class LicenseGenerator:
    def __init__(self):
        """Initialize the license generator."""
        pass
    
    def generate_salt(self, length: int = 5) -> str:
        """Generate a random salt string of specified length."""
        chars = string.ascii_uppercase + string.digits
        return ''.join(random.choice(chars) for _ in range(length))
    
    def generate_key_part(self, hardware_id: str, salt=None) -> str:
        """
        Generate the key part based on hardware ID and salt.
        
        Args:
            hardware_id: The hardware ID to bind the license to
            salt: Optional salt to use (generates random salt if not provided)
            
        Returns:
            A formatted key part (before the # separator)
        """
        # Create salt if not provided
        if not salt:
            salt = self.generate_salt(5)
        
        # Take first 8 chars of hardware ID
        hw_prefix = hardware_id[:8]
        
        # Generate a key using salt and hardware ID (20 chars total)
        key = f"{salt}{hw_prefix}"
        key = key.ljust(20, '0')[:20]
        
        # Format with dashes for readability
        return '-'.join([key[i:i+4] for i in range(0, len(key), 4)])
    
    def obfuscate_metadata(self, metadata):
        """
        Simple obfuscation of license metadata using base64 encoding.
        
        Args:
            metadata: Dictionary containing license metadata
            
        Returns:
            Base64 encoded data
        """
        # Convert metadata to JSON
        json_data = json.dumps(metadata)
        
        # Simple obfuscation - just use base64 encoding
        return base64.b64encode(json_data.encode('utf-8')).decode('utf-8')
    
    def generate_license_key(self, 
                           hardware_id: str, 
                           licensee_name: str, 
                           licensee_email: str,
                           license_type: str = 'lifetime',
                           purchase_date=None,
                           expiry_date=None,
                           salt=None) -> str:
        """
        Generate a complete license key with embedded metadata.
        
        Args:
            hardware_id: Hardware ID to bind the license to
            licensee_name: Name of the person or organization
            licensee_email: Email address of the licensee
            license_type: 'lifetime' or 'subscription'
            purchase_date: Date of purchase (ISO format)
            expiry_date: Expiration date for subscription licenses (ISO format)
            salt: Optional salt to use in key generation
            
        Returns:
            Complete license key with embedded metadata
        """
        # Set default dates if not provided
        if not purchase_date:
            purchase_date = datetime.datetime.now().strftime('%Y-%m-%d')
            
        # Generate a salt if not provided
        if not salt:
            salt = self.generate_salt()
            
        # Prepare metadata
        metadata = {
            "name": licensee_name,
            "email": licensee_email,
            "hardwareId": hardware_id,
            "licenseType": license_type,
            "purchaseDate": purchase_date,
            "salt": salt
        }
        
        # Add expiry date for subscription licenses
        if license_type == 'subscription' and expiry_date:
            metadata["expiryDate"] = expiry_date
            
        # Obfuscate the metadata
        obfuscated_metadata = self.obfuscate_metadata(metadata)
        
        # Generate the key part
        key_part = self.generate_key_part(hardware_id, salt)
        
        # Combine to form the complete license key
        return f"{key_part}#{obfuscated_metadata}"

def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Generate license keys for Browser Launcher Pro',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  Generate a lifetime license:
    python license_generator.py --hardware-id f86774665722036dd --name "John Doe" --email "john@example.com"
    
  Generate a subscription license:
    python license_generator.py --hardware-id f86774665722036dd --name "Jane Doe" --email "jane@example.com" --type subscription --expiry 2023-12-31
        '''
    )
    
    parser.add_argument('--hardware-id', required=True, 
                        help='Hardware ID of the target device')
    parser.add_argument('--name', required=True, 
                        help='Licensee name (person or organization)')
    parser.add_argument('--email', required=True, 
                        help='Licensee email')
    parser.add_argument('--type', choices=['lifetime', 'subscription'], 
                        default='lifetime', 
                        help='License type (lifetime or subscription)')
    parser.add_argument('--purchase-date', 
                        help='Purchase date (YYYY-MM-DD), defaults to today')
    parser.add_argument('--expiry', 
                        help='Expiry date for subscription licenses (YYYY-MM-DD)')
    parser.add_argument('--output', 
                        help='Output file path, if not specified print to stdout')
    parser.add_argument('--salt', 
                        help='Custom salt for key generation (optional)')
    
    return parser.parse_args()

def validate_hardware_id(hardware_id: str) -> bool:
    """Validate that the hardware ID has the correct format."""
    if not hardware_id or len(hardware_id) < 8:
        return False
    return True

def main():
    """Main entry point for the script."""
    args = parse_arguments()
    
    # Validate hardware ID
    if not validate_hardware_id(args.hardware_id):
        print("Error: Hardware ID must be at least 8 characters long")
        sys.exit(1)
    
    # Set dates
    purchase_date = args.purchase_date if args.purchase_date else datetime.datetime.now().strftime('%Y-%m-%d')
    expiry_date = args.expiry if args.expiry else None
    
    # Check that expiry date is provided for subscription licenses
    if args.type == 'subscription' and not expiry_date:
        # Set default expiry to one year from purchase
        purchase_dt = datetime.datetime.strptime(purchase_date, '%Y-%m-%d')
        expiry_dt = purchase_dt.replace(year=purchase_dt.year + 1)
        expiry_date = expiry_dt.strftime('%Y-%m-%d')
        print(f"No expiry date provided for subscription license. Using default: {expiry_date}")
    
    # Generate license key
    generator = LicenseGenerator()
    license_key = generator.generate_license_key(
        hardware_id=args.hardware_id,
        licensee_name=args.name,
        licensee_email=args.email,
        license_type=args.type,
        purchase_date=purchase_date,
        expiry_date=expiry_date,
        salt=args.salt
    )
    
    # Extract metadata from the key for display
    metadata_base64 = license_key.split('#')[1]
    metadata_json = base64.b64decode(metadata_base64).decode('utf-8')
    metadata = json.loads(metadata_json)
    
    # Output the key
    if args.output:
        with open(args.output, 'w') as f:
            f.write(license_key)
        print(f"License key written to {args.output}")
    else:
        print("\n============ GENERATED LICENSE KEY ============")
        print(license_key)
        print("\n============ LICENSE INFORMATION =============")
        print(f"Hardware ID: {args.hardware_id}")
        print(f"Licensed to: {args.name}")
        print(f"Email: {args.email}")
        print(f"License type: {args.type}")
        print(f"Purchase date: {purchase_date}")
        if expiry_date:
            print(f"Expiry date: {expiry_date}")
        print(f"Salt used: {metadata.get('salt', 'N/A')}")
        print("\nIMPORTANT: This license key is bound to the specified hardware ID and cannot be used on other devices.")

if __name__ == "__main__":
    main() 