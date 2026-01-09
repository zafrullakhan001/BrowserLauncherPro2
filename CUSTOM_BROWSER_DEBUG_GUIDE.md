# Custom Browser Debugging Guide

## How to View Logs for Comet Browser Issue

### Step 1: Open Browser Console (JavaScript Logs)

1. **Open the extension popup** (click the Browser Launcher Pro icon)
2. **Right-click anywhere** in the popup
3. Select **"Inspect"** or **"Inspect Element"**
4. Click on the **"Console"** tab
5. **Clear the console** (click the 🚫 icon or press Ctrl+L)

### Step 2: Test the Custom Browser

1. **Go to any webpage** (e.g., google.com)
2. **Right-click on any link**
3. **Select your Comet browser** from the context menu:
   - Look for: `🌐 Comet (Windows)` or similar
   - Click on: `📑 Open in Normal Window`

### Step 3: Check Console Logs

In the console, you should see logs like:
```
[Custom Browser] All custom browsers: [...]
[Custom Browser] Menu item clicked: custom-comet-windows
[Custom Browser] Found matching browser: {...}
[Custom Browser] Initial command: C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe
[Custom Browser] Is InPrivate mode: false
[Custom Browser] Platform: windows
[Custom Browser] URL to open: https://example.com
[Custom Browser] Processing Windows browser
[Custom Browser] Normal mode, added URL to command
[Custom Browser] Final command to execute: "C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" "https://example.com"
[Custom Browser] Sending message to native host...
[Custom Browser] Received response from native host: {...}
```

### Step 4: Check Python Logs (Native Messaging)

1. **Navigate to** the Browser Launcher Pro folder:
   ```
   C:\BrowserLauncherPro
   ```

2. **Open the log file**:
   ```
   BrowserLauncher.log
   ```

3. **Look for** the custom browser debug logs (they'll be at the end):
   ```
   ================================================================================
   [Custom Browser Debug] run_command_with_url called
   [Custom Browser Debug] Input command: "C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" "https://example.com"
   [Custom Browser Debug] Input URL: None
   [Custom Browser Debug] Command length: 95
   [Custom Browser Debug] URL in command: True
   [Custom Browser Debug] Processing Windows/generic command
   [Custom Browser Debug] URL already present in command, using command as-is
   [Custom Browser Debug] URL found at position: 68
   [Custom Browser Debug] Final command: "C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" "https://example.com"
   [Custom Browser Debug] Starting subprocess execution...
   [Custom Browser Debug] Process completed with return code: 0
   [Custom Browser Debug] Command executed successfully
   ================================================================================
   ```

## What to Look For

### ✅ **Success Indicators**:
- `[Custom Browser] Found matching browser`
- `[Custom Browser] Final command to execute: ...` (shows the full command)
- `[Custom Browser Debug] Process completed with return code: 0`
- `[Custom Browser Debug] Command executed successfully`

### ❌ **Error Indicators**:
- `[Custom Browser] No matching custom browser found`
- `[Custom Browser] Chrome runtime error`
- `[Custom Browser Debug] Command failed with exit code`
- `[Custom Browser Debug] Exception occurred`

## Common Issues and Solutions

### Issue 1: Browser Not Found in Menu
**Log shows**: `[Custom Browser] No matching custom browser found`

**Solution**:
- Make sure the browser is **Enabled** in Settings
- Click **"Save Custom Browsers"** after adding
- Reload the extension (chrome://extensions → Reload)

### Issue 2: URL Not Being Passed
**Log shows**: Command without URL or URL is empty

**Check**:
- Look at `[Custom Browser] URL to open:` in console
- Look at `[Custom Browser Debug] Input URL:` in log file
- Verify you're right-clicking on a **link**, not just the page

### Issue 3: Browser Launches But No URL
**Log shows**: Return code 0 but browser opens without URL

**Possible causes**:
1. **Comet browser doesn't accept URL as command-line argument**
   - Some browsers have different command-line syntax
   - Try testing manually in Command Prompt:
     ```cmd
     "C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" "https://google.com"
     ```

2. **Browser needs special flags**
   - Some browsers need `--new-window` or other flags
   - Check Comet's documentation for command-line options

### Issue 4: Permission or Path Error
**Log shows**: Error about file not found or access denied

**Solution**:
- Verify the path is correct
- Check if Comet is actually installed at that location
- Try running as administrator

## Testing Comet Manually

Open Command Prompt and test:

```cmd
cd C:\Users\zafru\AppData\Local\Perplexity\Comet\Application
comet.exe --help
```

This will show you what command-line options Comet supports.

Then test with a URL:
```cmd
"C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" "https://google.com"
```

If this doesn't work, Comet might need different syntax like:
```cmd
"C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" --url "https://google.com"
```
or
```cmd
"C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" --new-tab "https://google.com"
```

## Sending Logs for Support

If you need help, copy:
1. **Console logs** from the browser console
2. **Last 50 lines** from `BrowserLauncher.log`
3. **Your Comet browser configuration** from Settings

---

**Note**: The logs are now very detailed and will help identify exactly where the issue is occurring!
