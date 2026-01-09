# Custom Browser API Documentation

## Overview
Custom browsers can now be launched via the Browser Launcher Pro API, just like built-in browsers.

## API Usage

### Method: `openLinkInBrowser`

Send a message to the extension to open a URL in a custom browser.

### Syntax

```javascript
chrome.runtime.sendMessage(
  'extension-id', // Browser Launcher Pro extension ID
  {
    action: 'openLinkInBrowser',
    url: 'https://example.com',
    browserId: 'custom-comet-windows' // Your custom browser ID
  },
  (response) => {
    if (response.success) {
      console.log('Browser launched:', response.browser);
    } else {
      console.error('Error:', response.error);
    }
  }
);
```

## Custom Browser IDs

Custom browser IDs follow the format: `custom-{name}-{platform}`

Where:
- `{name}` is the browser name in lowercase with special characters replaced by hyphens
- `{platform}` is either `windows` or `wsl`

### Examples:
- **Comet (Windows)**: `custom-comet-windows`
- **Vivaldi (Windows)**: `custom-vivaldi-windows`
- **Brave (WSL)**: `custom-brave-wsl`
- **Arc Browser (Windows)**: `custom-arc-browser-windows`

## Finding Your Custom Browser ID

### Method 1: Check Storage
```javascript
chrome.storage.local.get(['customBrowsers'], (result) => {
  result.customBrowsers.forEach(browser => {
    console.log(`${browser.name}: ${browser.id}`);
  });
});
```

### Method 2: Check Settings
1. Open Browser Launcher Pro
2. Go to Settings → Custom Browsers
3. Click "Test & Debug"
4. Check the console for browser IDs

## Complete Examples

### Example 1: Open URL in Comet Browser

```javascript
// Get the extension ID first
const EXTENSION_ID = 'your-extension-id-here';

// Open a URL in Comet
chrome.runtime.sendMessage(
  EXTENSION_ID,
  {
    action: 'openLinkInBrowser',
    url: 'https://www.google.com',
    browserId: 'custom-comet-windows'
  },
  (response) => {
    if (response.success) {
      console.log('✅ Opened in', response.browser);
      console.log('Message:', response.message);
    } else {
      console.error('❌ Error:', response.error);
    }
  }
);
```

### Example 2: Open URL in Vivaldi (WSL)

```javascript
chrome.runtime.sendMessage(
  EXTENSION_ID,
  {
    action: 'openLinkInBrowser',
    url: 'https://github.com',
    browserId: 'custom-vivaldi-wsl'
  },
  (response) => {
    console.log(response.success ? '✅ Success' : '❌ Failed');
  }
);
```

### Example 3: Dynamic Browser Selection

```javascript
function openInCustomBrowser(url, browserName, platform = 'windows') {
  // Generate browser ID
  const browserId = `custom-${browserName.toLowerCase().replace(/[^a-z0-9]/g, '-')}-${platform}`;
  
  chrome.runtime.sendMessage(
    EXTENSION_ID,
    {
      action: 'openLinkInBrowser',
      url: url,
      browserId: browserId
    },
    (response) => {
      if (response.success) {
        console.log(`Opened ${url} in ${response.browser}`);
      } else {
        console.error(`Failed to open in ${browserName}:`, response.error);
      }
    }
  );
}

// Usage
openInCustomBrowser('https://example.com', 'Comet', 'windows');
openInCustomBrowser('https://example.com', 'Brave', 'wsl');
```

### Example 4: List All Available Custom Browsers

```javascript
function getAvailableCustomBrowsers(callback) {
  chrome.storage.local.get(['customBrowsers'], (result) => {
    const browsers = result.customBrowsers || [];
    const enabled = browsers.filter(b => b.enabled);
    callback(enabled);
  });
}

// Usage
getAvailableCustomBrowsers((browsers) => {
  console.log('Available custom browsers:');
  browsers.forEach(browser => {
    console.log(`- ${browser.icon} ${browser.name} (${browser.platform})`);
    console.log(`  ID: ${browser.id}`);
    console.log(`  Path: ${browser.path}`);
  });
});
```

### Example 5: Open Link with Error Handling

```javascript
async function openLinkSafely(url, browserId) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendMessage(
      EXTENSION_ID,
      {
        action: 'openLinkInBrowser',
        url: url,
        browserId: browserId
      },
      (response) => {
        if (chrome.runtime.lastError) {
          reject(new Error(chrome.runtime.lastError.message));
        } else if (response.success) {
          resolve(response);
        } else {
          reject(new Error(response.error));
        }
      }
    );
  });
}

// Usage with async/await
try {
  const result = await openLinkSafely('https://example.com', 'custom-comet-windows');
  console.log('✅ Success:', result.message);
} catch (error) {
  console.error('❌ Error:', error.message);
}
```

## Response Format

### Success Response
```javascript
{
  success: true,
  message: 'Custom browser launch initiated',
  browser: 'Comet' // Browser name
}
```

### Error Responses

**Browser Not Found:**
```javascript
{
  success: false,
  error: 'Custom browser not found: custom-invalid-windows'
}
```

**Browser Disabled:**
```javascript
{
  success: false,
  error: 'Custom browser is disabled: custom-comet-windows'
}
```

**Invalid Browser ID:**
```javascript
{
  success: false,
  error: 'Invalid browser ID: invalid-id'
}
```

## Built-in Browser IDs (for reference)

You can also use these built-in browser IDs:

### Windows Browsers:
- `edge-stable-local`
- `edge-beta-local`
- `edge-dev-local`
- `chrome-stable-local`
- `chrome-beta-local`
- `chrome-dev-local`

### WSL Browsers:
- `edge-stable`
- `edge-beta`
- `edge-dev`
- `chrome-stable`
- `chrome-beta`
- `chrome-dev`
- `firefox`
- `opera`
- `brave`

## Notes

1. **Extension ID**: Replace `'your-extension-id-here'` with the actual Browser Launcher Pro extension ID
2. **Async Response**: The API responds immediately, but browser launch happens asynchronously
3. **Enabled Check**: Only enabled custom browsers can be launched via API
4. **Platform Support**: Both Windows and WSL custom browsers are supported
5. **URL Encoding**: URLs are automatically quoted and escaped

## Testing

Test the API from the browser console:

```javascript
// Test opening Google in Comet
chrome.runtime.sendMessage(
  chrome.runtime.id, // Use current extension ID if testing from extension context
  {
    action: 'openLinkInBrowser',
    url: 'https://www.google.com',
    browserId: 'custom-comet-windows'
  },
  console.log
);
```

## Troubleshooting

### Browser doesn't launch
1. Check if the browser is enabled in Settings
2. Verify the browser ID is correct
3. Check the browser path is valid
4. Look at console logs for detailed error messages

### How to get console logs
1. Open extension background console (chrome://extensions → service worker)
2. Look for `[API]` prefixed logs
3. Check for error messages

---

**API Version**: 1.0  
**Last Updated**: 2026-01-09
