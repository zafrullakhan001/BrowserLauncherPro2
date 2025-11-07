# Browser Launcher Pro - License Generator

This tool generates license keys for Browser Launcher Pro with embedded encrypted metadata. The keys are hardware-locked to specific devices and contain all the registration information needed for automatic activation.

## Features

- Generates secure license keys bound to specific hardware IDs
- Embeds encrypted registration data within the key itself:
  - Licensee name (person or organization)
  - Email address
  - Purchase date
  - License type (lifetime or subscription)
- No manual data entry required during activation
- Keys are unique to each device and cannot be shared

## Usage

### Prerequisites

- Python 3.6 or higher

### Generating a License Key

```bash
python license_generator.py --hardware-id <HARDWARE_ID> --name "Customer Name" --email "customer@example.com" --type lifetime
```

### Parameters

- `--hardware-id`: The hardware ID of the target device (required)
- `--name`: Full name of the licensee or organization (required)
- `--email`: Email address of the licensee (required)
- `--type`: License type, either "lifetime" or "subscription" (default: lifetime)
- `--date`: Purchase date in YYYY-MM-DD format (default: current date)
- `--output`: Path to save the license key to a file (optional)

## How it Works

1. The customer provides their hardware ID (shown in the license modal)
2. You generate a license key with their information embedded
3. When the customer enters the key, the extension:
   - Validates that the key matches their hardware ID
   - Automatically extracts and displays their license details
   - No manual data entry required

## Security Features

- Keys are tied to hardware IDs, preventing unauthorized sharing
- Registration data is encoded to prevent tampering
- Keys use a format that makes them difficult to reverse-engineer
- In a production environment, you would add server-side validation

## Example

```
python license_generator.py --hardware-id 5f4dcc3b5aa765d61d8327deb882cf99 --name "Acme Corporation" --email "admin@acme.com" --type lifetime --date 2023-06-15
```

This produces a license key that contains all the information above, which can be sent directly to the customer.

## License Information Display

When a customer activates their license, their name will be prominently displayed with a yellow highlight in the license modal, clearly showing who owns the license.

## Notes for Production Use

In a production environment, you would want to enhance this system with:

1. Stronger encryption for the embedded metadata
2. Server-side validation of license keys
3. Periodic online verification
4. Ability to revoke compromised keys 