// Quick test script to check custom browsers in storage
// Run this in the browser console (F12) on any page

chrome.storage.local.get(['customBrowsers'], function (result) {
    console.log('=== CUSTOM BROWSERS IN STORAGE ===');
    console.log('Custom browsers:', result.customBrowsers);

    if (result.customBrowsers && result.customBrowsers.length > 0) {
        console.log(`Found ${result.customBrowsers.length} custom browser(s):`);
        result.customBrowsers.forEach((browser, index) => {
            console.log(`\n${index + 1}. ${browser.name}`);
            console.log(`   Platform: ${browser.platform}`);
            console.log(`   Path: ${browser.path}`);
            console.log(`   Icon: ${browser.icon}`);
            console.log(`   Enabled: ${browser.enabled}`);
            console.log(`   ID: ${browser.id}`);
        });
    } else {
        console.log('❌ No custom browsers found in storage!');
        console.log('Please add a custom browser in Settings and click "Save Custom Browsers"');
    }
});
