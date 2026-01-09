# Custom Browsers Feature - Browser Launcher Pro

## Overview
The Custom Browsers feature allows you to add and manage your own custom browsers for both Windows and WSL Linux platforms. This extends Browser Launcher Pro beyond the built-in Edge and Chrome browsers to support any browser you want to use.

## Features Added

### 1. **Settings Tab - Custom Browsers Management**
- New "Custom Browsers" card in the Settings tab
- Add unlimited custom browsers
- Configure for Windows or WSL platforms
- Set browser name, path, and custom icon (emoji)
- Enable/disable individual browsers
- Remove browsers you no longer need

### 2. **Main Tab Integration**
- Custom browsers appear in both Windows Local and WSL tabs
- Dedicated "CUSTOM BROWSERS" sections with purple gradient styling
- One-click launch from the main interface
- Automatically hidden when no custom browsers are configured

### 3. **Context Menu Integration**
- Custom browsers appear in right-click context menus
- Support for opening links in:
  - Normal window
  - InPrivate/Incognito window
- Automatic detection of browser type for correct private mode flags
- Platform indicator (Windows/WSL) in menu items

## How to Use

### Adding a Custom Browser

1. **Open Settings Tab**
   - Click on the "Settings" tab in Browser Launcher Pro

2. **Navigate to Custom Browsers Section**
   - Scroll down to the "Custom Browsers" card
   - Click the "Add Browser" button

3. **Configure Your Browser**
   - **Browser Name**: Enter a friendly name (e.g., "Vivaldi", "Arc", "Waterfox")
   - **Platform**: Select "Windows" or "WSL Linux"
   - **Browser Path**: 
     - Windows: Full path with .exe (e.g., `C:\Program Files\Vivaldi\Application\vivaldi.exe`)
     - WSL: Linux path (e.g., `/usr/bin/vivaldi`)
   - **Icon** (optional): Add an emoji or leave blank for default 🌐
   - **Enabled**: Check to make the browser available

4. **Save Your Configuration**
   - Click "Save Custom Browsers" button
   - Your custom browsers will now appear in all tabs and context menus

### Launching Custom Browsers

#### From Main Tabs
1. Go to "Windows Local" or "WSL Ubuntu Linux" tab
2. Find the "CUSTOM BROWSERS" section
3. Click on your custom browser button to launch it

#### From Context Menu
1. Right-click on any link or page
2. Find your custom browser in the menu (with platform indicator)
3. Choose:
   - "Open in Normal Window" - Opens in regular mode
   - "Open in InPrivate Window" - Opens in private/incognito mode

### Managing Custom Browsers

#### Edit a Browser
1. Go to Settings > Custom Browsers
2. Modify the browser's details
3. Click "Save Custom Browsers"

#### Remove a Browser
1. Go to Settings > Custom Browsers
2. Click the "Remove" button on the browser you want to delete
3. Confirm the removal
4. Click "Save Custom Browsers"

#### Disable Temporarily
1. Go to Settings > Custom Browsers
2. Uncheck the "Enabled" checkbox
3. Click "Save Custom Browsers"
4. The browser will be hidden but settings are preserved

## Supported Browsers

This feature works with ANY browser that can be launched from command line:

### Popular Windows Browsers
- **Vivaldi**: `C:\Users\[Username]\AppData\Local\Vivaldi\Application\vivaldi.exe`
- **Brave**: `C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe`
- **Arc**: `C:\Users\[Username]\AppData\Local\Arc\Application\arc.exe`
- **Waterfox**: `C:\Program Files\Waterfox\waterfox.exe`
- **Opera**: `C:\Users\[Username]\AppData\Local\Programs\Opera\opera.exe`
- **Tor Browser**: `C:\...\Tor Browser\Browser\firefox.exe`

### Popular WSL Browsers
- **Vivaldi**: `/usr/bin/vivaldi`
- **Brave**: `/usr/bin/brave-browser`
- **Chromium**: `/usr/bin/chromium-browser`
- **Waterfox**: `/usr/bin/waterfox`
- **Opera**: `/usr/bin/opera`

## Private Mode Support

The extension automatically detects browser types and uses the correct private mode flag:

- **Chrome-based** (Chrome, Vivaldi, Brave, Arc): `--incognito`
- **Edge-based**: `--inprivate`
- **Firefox-based** (Firefox, Waterfox, Tor): `--private-window` or `-private-window`
- **Generic/Unknown**: `--incognito` (fallback)

## Technical Details

### Storage
- Custom browsers are stored in `chrome.storage.local` under the key `customBrowsers`
- Each browser has a unique ID generated from its name and platform
- Settings persist across browser sessions

### Data Structure
```javascript
{
  name: "Browser Name",
  platform: "windows" | "wsl",
  path: "Full path to browser executable",
  icon: "🌐", // Emoji or default
  enabled: true | false,
  id: "custom-browser-name-platform"
}
```

### Context Menu Refresh
- Context menus automatically refresh when you save custom browsers
- Changes appear immediately without needing to reload the extension

## Troubleshooting

### Browser Won't Launch
1. **Check the path**: Make sure the browser path is correct
   - Windows: Use full path with `.exe`
   - WSL: Use Linux-style paths starting with `/`
2. **Test manually**: Try running the path in Command Prompt (Windows) or Terminal (WSL)
3. **Check permissions**: Ensure the browser executable has execute permissions

### Browser Not Appearing in Menus
1. Make sure the browser is **Enabled** in settings
2. Click "Save Custom Browsers" after making changes
3. Check that you selected the correct platform (Windows vs WSL)

### Private Mode Not Working
- Some browsers may use different flags for private mode
- Check your browser's documentation for the correct command-line flag
- You can manually test: `"C:\path\to\browser.exe" --incognito https://example.com`

## Examples

### Example 1: Adding Vivaldi on Windows
```
Browser Name: Vivaldi
Platform: Windows
Browser Path: C:\Users\YourName\AppData\Local\Vivaldi\Application\vivaldi.exe
Icon: 🔴
Enabled: ✓
```

### Example 2: Adding Brave on WSL
```
Browser Name: Brave
Platform: WSL Linux
Browser Path: /usr/bin/brave-browser
Icon: 🦁
Enabled: ✓
```

### Example 3: Adding Tor Browser on Windows
```
Browser Name: Tor Browser
Platform: Windows
Browser Path: C:\Users\YourName\Desktop\Tor Browser\Browser\firefox.exe
Icon: 🧅
Enabled: ✓
```

## Benefits

✅ **Flexibility**: Use any browser you want, not just Edge and Chrome
✅ **Cross-Platform**: Support for both Windows and WSL browsers
✅ **Convenience**: Quick access from main tabs and context menus
✅ **Privacy**: Built-in support for private/incognito modes
✅ **Customization**: Add custom icons and names for easy identification
✅ **Persistence**: All settings are saved and persist across sessions

## Version
Feature added in Browser Launcher Pro v3.0+

## Support
For issues or questions about custom browsers, please refer to the main Browser Launcher Pro documentation or support channels.
