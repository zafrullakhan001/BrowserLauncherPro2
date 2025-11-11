Browser Launcher Extension
Overview
Browser Launcher is a powerful browser extension designed to launch web applications in different browser versions. It's built for Chrome and Edge browsers using Manifest V3 and includes native messaging capabilities for enhanced system integration.
Availability & Disclaimer
-------------------------
This is a custom-developed extension and is NOT listed on the Chrome Web Store or Microsoft Edge Add-ons store. You may download and use it freely at your own discretion by loading it as an unpacked extension. The software is provided "AS IS" without any warranty; the developer assumes no liability for damages, data loss, or other issues arising from its use.
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
Installation (Load Unpacked)
Because it is not available in the Chrome or Edge stores, install manually:
1. Download or clone the repository and extract it to a folder.
2. Open the extensions page:
   Chrome: chrome://extensions/
   Edge: edge://extensions/
3. Enable Developer Mode (toggle top-right).
4. Run the native messaging setup script (e.g., setup_native_messaging.bat) as Administrator if system integration is required.
5. Click "Load unpacked" and select the extracted folder.
Security Features
Uses native messaging for secure system-level operations
Implements strict content security policies
Requires explicit permissions for various operations
Includes EULA and user agreement functionality
This extension appears to be a sophisticated tool that bridges the gap between web browsers and system-level operations, particularly focused on managing and launching web applications across different browser versions. Its architecture suggests it's designed for enterprise or power-user scenarios where precise control over browser instances is required.

Browser Launcher Installation Guide (Summary)
============================================
1. Clone or download and extract the repository.
2. Open Chrome or Edge extensions page and enable Developer Mode.
3. (Optional) Run native messaging setup script as Administrator.
4. Click "Load unpacked" and select the extracted folder.
5. Extension is ready for use. Use at your own risk; no warranties.
