// Function to import settings from the JSON file
async function importBrowserSettings() {
    try {
        console.log('Starting to import browser settings from browser_settings.json');
        // Read the settings file
        const response = await fetch('browser_settings.json');
        if (!response.ok) {
            const errorMsg = `Failed to load settings: ${response.statusText}`;
            console.error(errorMsg);
            showNotification('error', errorMsg);
            throw new Error(errorMsg);
        }
        
        const settings = await response.json();
        console.log('Successfully loaded browser settings from JSON file');
        
        // Store settings in Chrome's local storage
        chrome.storage.local.set(settings, () => {
            if (chrome.runtime.lastError) {
                const errorMsg = `Error saving settings: ${chrome.runtime.lastError.message}`;
                console.error(errorMsg);
                showNotification('error', 'Failed to save settings');
            } else {
                console.log('Settings imported successfully to Chrome storage');
                showNotification('success', 'Settings imported successfully');
                
                // Refresh context menus to apply new settings
                chrome.runtime.sendMessage({ action: 'refreshContextMenus' });
                console.log('Sent message to refresh context menus');
                
                // Update UI if we're on the settings page
                updateSettingsUI(settings);
                console.log('Updated settings UI with imported settings');
            }
        });
    } catch (error) {
        console.error('Error importing settings:', error);
        showNotification('error', `Failed to import settings: ${error.message}`);
    }
}

// Function to execute the PowerShell script to find browser paths
function executeFindBrowserPathsScript() {
    console.log('Starting browser path detection script execution');
    showNotification('info', 'Executing browser path detection script...');
    
    // Get the absolute path to the script
    const scriptPath = chrome.runtime.getURL('FindBrowserPaths.ps1');
    console.log(`Script path: ${scriptPath}`);
    
    // Send message to background script to execute PowerShell
    chrome.runtime.sendMessage({ 
        action: 'executePowerShellScript',
        scriptPath: scriptPath
    }, (response) => {
        if (chrome.runtime.lastError) {
            const errorMsg = `Error sending message: ${chrome.runtime.lastError.message}`;
            console.error(errorMsg);
            showNotification('error', errorMsg);
            return;
        }
        
        if (response && response.success) {
            console.log('Browser paths detected successfully');
            showNotification('success', 'Browser paths detected successfully!');
            // Import the settings after the script has run
            importBrowserSettings();
        } else {
            const errorMsg = response ? response.error : 'Unknown error occurred';
            console.error(`Failed to execute browser path detection script: ${errorMsg}`);
            showNotification('error', `Failed to execute browser path detection script: ${errorMsg}`);
        }
    });
}

// Function to show notification
function showNotification(type, message) {
    const notificationDiv = document.createElement('div');
    notificationDiv.className = `notification ${type}`;
    notificationDiv.textContent = message;
    
    document.body.appendChild(notificationDiv);
    
    // Remove notification after 5 seconds
    setTimeout(() => {
        notificationDiv.remove();
    }, 5000);
}

// Function to update the settings UI
function updateSettingsUI(settings) {
    // Update path inputs
    const pathInputs = [
        'edge-stable-path',
        'edge-beta-path',
        'edge-dev-path',
        'chrome-stable-path',
        'chrome-beta-path',
        'chrome-dev-path',
        'wsl-edge-stable-path',
        'wsl-edge-beta-path',
        'wsl-edge-dev-path',
        'wsl-chrome-stable-path',
        'wsl-chrome-beta-path',
        'wsl-chrome-dev-path',
        'wsl-firefox-path',
        'wsl-opera-path',
        'wsl-brave-path'
    ];
    
    const settingsMap = {
        'edge-stable-path': 'edgeStablePath',
        'edge-beta-path': 'edgeBetaPath',
        'edge-dev-path': 'edgeDevPath',
        'chrome-stable-path': 'chromeStablePath',
        'chrome-beta-path': 'chromeBetaPath',
        'chrome-dev-path': 'chromeDevPath',
        'wsl-edge-stable-path': 'wslEdgeStablePath',
        'wsl-edge-beta-path': 'wslEdgeBetaPath',
        'wsl-edge-dev-path': 'wslEdgeDevPath',
        'wsl-chrome-stable-path': 'wslChromeStablePath',
        'wsl-chrome-beta-path': 'wslChromeBetaPath',
        'wsl-chrome-dev-path': 'wslChromeDevPath',
        'wsl-firefox-path': 'wslFirefoxPath',
        'wsl-opera-path': 'wslOperaPath',
        'wsl-brave-path': 'wslBravePath'
    };
    
    pathInputs.forEach(inputId => {
        const input = document.getElementById(inputId);
        if (input) {
            const settingKey = settingsMap[inputId];
            input.value = settings[settingKey] || '';
            
            // Update NA checkbox if exists
            const naCheckbox = document.getElementById(`${inputId.replace('-path', '')}-na-checkbox`);
            if (naCheckbox) {
                naCheckbox.checked = settings[settingKey] === 'NA';
            }
        }
    });
    
    // Update checkboxes
    const checkboxes = [
        'version-checkbox',
        'edge-stable-checkbox',
        'edge-beta-checkbox',
        'edge-dev-checkbox',
        'chrome-stable-checkbox',
        'chrome-beta-checkbox',
        'chrome-dev-checkbox',
        'wsl-firefox-checkbox',
        'wsl-opera-checkbox',
        'wsl-brave-checkbox'
    ];
    
    const checkboxMap = {
        'version-checkbox': 'versionCheckbox',
        'edge-stable-checkbox': 'edgeStableCheckbox',
        'edge-beta-checkbox': 'edgeBetaCheckbox',
        'edge-dev-checkbox': 'edgeDevCheckbox',
        'chrome-stable-checkbox': 'chromeStableCheckbox',
        'chrome-beta-checkbox': 'chromeBetaCheckbox',
        'chrome-dev-checkbox': 'chromeDevCheckbox',
        'wsl-firefox-checkbox': 'wslFirefoxCheckbox',
        'wsl-opera-checkbox': 'wslOperaCheckbox',
        'wsl-brave-checkbox': 'wslBraveCheckbox'
    };
    
    checkboxes.forEach(checkboxId => {
        const checkbox = document.getElementById(checkboxId);
        if (checkbox) {
            const settingKey = checkboxMap[checkboxId];
            checkbox.checked = settings[settingKey] !== undefined ? settings[settingKey] : true;
        }
    });
    
    // Update check interval
    const checkIntervalInput = document.getElementById('check-interval');
    if (checkIntervalInput) {
        checkIntervalInput.value = settings.checkInterval || 60;
    }
}

// Add import button to settings page
function addImportButton() {
    const settingsForm = document.querySelector('form');
    if (settingsForm) {
        // Create button container for better layout
        const buttonContainer = document.createElement('div');
        buttonContainer.className = 'd-flex justify-content-between mt-3';
        
        // Create Find Browser Paths button
        const findPathsButton = document.createElement('button');
        findPathsButton.type = 'button';
        findPathsButton.className = 'btn btn-success';
        findPathsButton.textContent = 'Find Browser Paths';
        findPathsButton.onclick = executeFindBrowserPathsScript;
        
        // Create Import Settings button
        const importButton = document.createElement('button');
        importButton.type = 'button';
        importButton.className = 'btn btn-primary';
        importButton.textContent = 'Import Detected Settings';
        importButton.onclick = importBrowserSettings;
        
        // Add spacing element between buttons
        const spacer = document.createElement('div');
        spacer.style.width = '50px'; // Add 10px space between buttons
        
        // Add buttons and spacer to container
        buttonContainer.appendChild(findPathsButton);
        buttonContainer.appendChild(spacer);
        buttonContainer.appendChild(importButton);
        
        // Add container to form
        settingsForm.appendChild(buttonContainer);
    }
}

// Initialize when the document is loaded
document.addEventListener('DOMContentLoaded', () => {
    addImportButton();
}); 