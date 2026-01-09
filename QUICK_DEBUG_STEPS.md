# Quick Debug Steps for Comet Browser

## Step 1: Reload the Extension
1. Go to `chrome://extensions/`
2. Find **Browser Launcher Pro**
3. Click the **🔄 Reload** button

## Step 2: Open Settings and Test
1. **Click** the Browser Launcher Pro extension icon
2. Go to the **Settings** tab
3. Scroll to **Custom Browsers** section
4. Click the **🐛 Test & Debug** button

This will:
- Show you all custom browsers in storage
- Display them in the console
- Refresh the context menus
- Give you a summary popup

## Step 3: View Console Logs

### For Popup Logs:
1. With the popup open, press **F12** or **Right-click → Inspect**
2. Go to **Console** tab
3. You'll see the `[TEST]` logs

### For Background Logs (Context Menu):
1. Go to `chrome://extensions/`
2. Enable **Developer mode** (top right toggle)
3. Find **Browser Launcher Pro**
4. Click **"service worker"** or **"Inspect views: service worker"**
5. A new DevTools window opens - go to **Console** tab
6. Now right-click on any link and select your Comet browser
7. Watch the `[Custom Browser]` logs appear in real-time

## Step 4: Check Python Logs
1. Open File Explorer
2. Navigate to: `C:\BrowserLauncherPro`
3. Open `BrowserLauncher.log` with Notepad
4. Scroll to the bottom
5. Look for lines with `[Custom Browser Debug]`

## What You Should See

### In Popup Console (after clicking Test & Debug):
```
================================================================================
[TEST] Custom Browsers Debug Test Started
================================================================================
[TEST] Custom browsers in storage: [{...}]
[TEST] Number of custom browsers: 1

[TEST] Browser 1:
  Name: Comet
  Platform: windows
  Path: C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe
  Icon: 🌐
  Enabled: true
  ID: custom-comet-windows

[TEST] Checking context menu integration...
[TEST] ✅ Context menus refreshed successfully
[TEST] Test completed successfully
================================================================================
```

### In Background Console (when clicking context menu):
```
[Custom Browser] All custom browsers: [{...}]
[Custom Browser] Menu item clicked: custom-comet-windows-normal
[Custom Browser] Found matching browser: {...}
[Custom Browser] URL to open: https://example.com
[Custom Browser] Final command to execute: "C:\Users\zafru\...\comet.exe" "https://example.com"
```

### In BrowserLauncher.log:
```
[Custom Browser Debug] Input command: "C:\Users\zafru\...\comet.exe" "https://example.com"
[Custom Browser Debug] URL in command: True
[Custom Browser Debug] Final command: "C:\Users\zafru\...\comet.exe" "https://example.com"
[Custom Browser Debug] Process completed with return code: 0
```

## If No Logs Appear

### Problem: Test button shows "No custom browsers found"
**Solution**: 
1. Add your Comet browser in Settings
2. Fill in all fields
3. Click **"Save Custom Browsers"** (NOT just Test & Debug)
4. Then click **"Test & Debug"** again

### Problem: No logs in background console
**Solution**:
1. Make sure you're looking at the **service worker** console, not the popup console
2. The dropdown at the top should show the background context
3. Try clearing the console and testing again

### Problem: Logs show but browser doesn't open
**Solution**:
1. Check the return code in logs
2. If return code is not 0, there's an error
3. Try running the command manually in Command Prompt:
   ```cmd
   "C:\Users\zafru\AppData\Local\Perplexity\Comet\Application\comet.exe" "https://google.com"
   ```

## Quick Test Checklist

- [ ] Extension reloaded
- [ ] Custom browser added and saved
- [ ] Test & Debug button clicked - shows browser info
- [ ] Popup console shows [TEST] logs
- [ ] Background console open (service worker)
- [ ] Right-clicked on a link
- [ ] Selected Comet from context menu
- [ ] Background console shows [Custom Browser] logs
- [ ] BrowserLauncher.log shows [Custom Browser Debug] logs

---

**If you're still not seeing logs, share a screenshot of:**
1. The Settings > Custom Browsers section (showing your Comet browser)
2. The popup console after clicking Test & Debug
3. The background service worker console
