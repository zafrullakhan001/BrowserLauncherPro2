// DIRECT SAVE SCRIPT - Run this in browser console to save Comet browser
// This bypasses the UI and saves directly to storage

chrome.storage.local.set({
    customBrowsers: [
        {
            name: "Comet",
            platform: "windows",
            path: "C:\\Users\\zafru\\AppData\\Local\\Perplexity\\Comet\\Application\\comet.exe",
            icon: "🌐",
            enabled: true,
            id: "custom-comet-windows"
        }
    ]
}, function () {
    console.log('✅ Comet browser saved directly to storage!');
    console.log('Now refresh context menus...');

    // Refresh context menus
    chrome.runtime.sendMessage({ action: 'refreshContextMenus' }, function (response) {
        if (chrome.runtime.lastError) {
            console.error('Error refreshing menus:', chrome.runtime.lastError);
        } else {
            console.log('✅ Context menus refreshed!');
            console.log('Now right-click on any link and look for "🌐 Comet (Windows)"');
        }
    });
});
