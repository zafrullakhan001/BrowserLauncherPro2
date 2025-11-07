Browser Launcher Extension
Overview
Browser Launcher is a powerful browser extension designed to launch web applications in different browser versions. It's built for Chrome and Edge browsers using Manifest V3 and includes native messaging capabilities for enhanced system integration.
Key Features
Multi-Browser Support: Ability to launch web applications in different browser versions
Native Integration: Uses native messaging to communicate with the system, allowing for deeper OS-level interactions
Context Menu Integration: Provides right-click menu options for quick access to features
Keyboard Shortcuts:
Ctrl+Y: Quick YouTube search for selected text
Ctrl+Shift+Z: Open YouTube search in incognito mode
Technical Capabilities
Native Messaging: Integrates with a Python-based native messaging host for system-level operations
Storage Management: Can store and manage user preferences and settings
Notifications: Ability to send system notifications
Active Tab Control: Can interact with and manipulate the active browser tab
Background Processing: Includes a service worker for background operations
Security: Implements strict content security policies for enhanced safety
System Requirements
Windows operating system
Chrome or Edge browser
Python installation (handled by setup scripts)
Administrator privileges for installation
Architecture
The extension consists of several key components:
popup.html/js/css: User interface and frontend logic
background.js: Background service worker for event handling
native_messaging.py: Python-based native messaging host
Various setup and installation scripts for system integration
Installation
The extension requires a proper setup process that includes:
Extension installation in the browser
Native messaging host setup
System configuration via provided setup scripts
Security Features
Uses native messaging for secure system-level operations
Implements strict content security policies
Requires explicit permissions for various operations
Includes EULA and user agreement functionality
This extension appears to be a sophisticated tool that bridges the gap between web browsers and system-level operations, particularly focused on managing and launching web applications across different browser versions. Its architecture suggests it's designed for enterprise or power-user scenarios where precise control over browser instances is required.

Browser Launcher installation  Guide
======================================

Follow these steps to install and set up the Browser Launcher extension:

1. Download and extract the "Browser Launcher" extension to a folder on your computer.

2. Open your Chrome or Edge browser and navigate to the Extensions page:
   - For Chrome: `chrome://extensions/`
   - For Edge: `edge://extensions/`

3. Enable Developer mode:
   - Toggle the "Developer mode" switch located at the top-right corner of the Extensions page.

4. Run the setup script from the extracted folder
   - Right-click on `setup_native_messaging.bat`.
   - Select “Run as administrator”.

5. Load the extension:
   - Click on the "Load unpacked" button.
   - Select the folder where you extracted the "Browser Launcher" extension in Step 1.
   
Once these steps are completed, the Browser Launcher extension should be fully set up and ready to use.
