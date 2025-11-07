# Browser Launcher Pro - License System

This document describes the licensing system for Browser Launcher Pro.

## Overview

Browser Launcher Pro uses a hardware-locked license system with encrypted metadata embedded within each license key. This provides several benefits:

1. **Hardware-Specific Activation**: Each license key is bound to a specific hardware fingerprint, preventing unauthorized sharing
2. **Embedded Metadata**: All registration information is contained within the key itself
3. **Simplified User Experience**: No manual data entry required during activation
4. **Security**: License keys cannot be tampered with or modified

## License Key Format

License keys have the following format:
```
XXXX-XXXX-XXXX-XXXX#base64EncodedMetadata
```

The first part (before the `#`) is a formatted key that includes a salt and hardware ID information. The second part contains encrypted user data including:

- Licensee name
- Email address
- Purchase date
- License type (lifetime/subscription)
- Expiry date (for subscription licenses)

## Trial Period

Browser Launcher Pro offers a 60-day trial period. After this period expires, users must activate a valid license to continue using all features.

## License Key Generation

License keys are generated using the `license_generator.py` script. This script takes a hardware ID, licensee information, and creates a license key that is bound to that specific hardware.

### Usage

```bash
python license_generator.py --hardware-id <HARDWARE_ID> --name "Customer Name" --email "customer@example.com" --type lifetime
```

For subscription licenses:

```bash
python license_generator.py --hardware-id <HARDWARE_ID> --name "Customer Name" --email "customer@example.com" --type subscription --expiry 2024-12-31
```

### Parameters

- `--hardware-id`: The hardware ID of the target device (required)
- `--name`: The name of the licensee (required)
- `--email`: The email address of the licensee (required)
- `--type`: License type - "lifetime" or "subscription" (default: lifetime)
- `--purchase-date`: Date of purchase (default: current date)
- `--expiry`: Expiry date for subscription licenses (default: 1 year from purchase for subscription)
- `--output`: Optional file to save the license key to

## License Validation

When a user enters a license key, the extension:

1. Validates the key format
2. Decodes the embedded metadata
3. Verifies the hardware ID matches the current device
4. Checks for key expiration (for subscription licenses)
5. Auto-populates all user information from the extracted metadata

## Error Handling

The system provides clear error messages for different validation failures:

- Invalid key format
- Hardware ID mismatch (key is for another device)
- Expired license
- Tampered key
- Data extraction failure

## Security Considerations

While this implementation uses simplified encryption for demonstration purposes, a production version should:

1. Use asymmetric encryption (RSA) for key signing
2. Implement server-side validation for critical license checks
3. Store encryption keys securely
4. Include advanced anti-tampering measures

## License Files

- `license.js`: Core license management functions
- `license-ui.js`: UI for license activation and display
- `license_generator.py`: Python script for generating license keys
- `background.js`: Background script with license validation handlers 