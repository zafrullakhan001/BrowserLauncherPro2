document.addEventListener('DOMContentLoaded', function () {
  // ===== Initialize Internationalization =====
  if (window.i18n) {
    // Initialize i18n system first
    window.i18n.initialize();

    // Set up additional language selector in settings
    // Settings language selector removed; header selector remains
  }

  // ===== Theme Toggle Control =====
  (function initThemeToggle() {
    const themeToggle = document.getElementById('theme-toggle');
    const themeIcon = document.getElementById('theme-icon');

    if (!themeToggle || !themeIcon) return;

    // Load saved theme or default to light
    chrome.storage.local.get(['theme'], (result) => {
      const theme = result.theme || 'light';
      applyTheme(theme, false);
    });

    function applyTheme(theme, persist = true) {
      if (theme === 'dark') {
        document.documentElement.setAttribute('data-theme', 'dark');
        themeIcon.className = 'fas fa-sun';
      } else {
        document.documentElement.setAttribute('data-theme', 'light');
        themeIcon.className = 'fas fa-moon';
      }

      if (persist) {
        chrome.storage.local.set({ theme });
      }
    }

    themeToggle.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme');
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      applyTheme(newTheme, true);
    });
  })();

  // ===== Memory Usage Monitor =====
  (function initMemoryUsage() {
    const statusEl = document.getElementById('memory-status');
    const statusTextEl = document.getElementById('memory-status-text');
    const memoryUsageEl = document.getElementById('memory-usage');

    if (!statusEl || !statusTextEl || !memoryUsageEl) return;

    function setMemoryStatus(kind, text, usage) {
      // kind: 'normal' | 'warning' | 'critical' | 'info'
      statusEl.classList.remove('status-online', 'status-info', 'status-error', 'status-warning');
      if (kind === 'normal') statusEl.classList.add('status-online');
      else if (kind === 'warning') statusEl.classList.add('status-warning');
      else if (kind === 'critical') statusEl.classList.add('status-error');
      else statusEl.classList.add('status-info');

      statusTextEl.textContent = text;
      memoryUsageEl.textContent = usage || '';
    }

    async function updateMemoryUsage() {
      try {
        setMemoryStatus('info', 'Loading…', '');

        // Use performance.memory to show extension's actual memory usage
        if (performance?.memory) {
          const usedJSHeapMB = Math.round(performance.memory.usedJSHeapSize / (1024 * 1024));
          const totalJSHeapMB = Math.round(performance.memory.totalJSHeapSize / (1024 * 1024));
          const limitJSHeapMB = Math.round(performance.memory.jsHeapSizeLimit / (1024 * 1024));
          const usagePercent = Math.round((usedJSHeapMB / limitJSHeapMB) * 100);

          let kind = 'normal';
          if (usagePercent >= 90) {
            kind = 'critical';
          } else if (usagePercent >= 75) {
            kind = 'warning';
          }

          setMemoryStatus(
            kind,
            `${usedJSHeapMB} MB`,
            `/ ${limitJSHeapMB} MB (${usagePercent}%)`
          );
          statusEl.title = `Extension Memory: ${usedJSHeapMB} MB used of ${limitJSHeapMB} MB limit (${usagePercent}% used)`;
        } else {
          setMemoryStatus('info', 'N/A', '');
          statusEl.title = 'Memory information not available';
        }
      } catch (err) {
        setMemoryStatus('error', 'Memory: Error', '');
        console.error('Memory check error:', err);
      }
    }

    // Expose for other parts if needed
    window.updateMemoryUsage = updateMemoryUsage;

    // Initial check on open
    updateMemoryUsage();

    // Update memory every 5 seconds
    setInterval(updateMemoryUsage, 5000);
  })();

  // ===== Native Messaging Health Check =====
  (function initNativeMessagingHealth() {
    const statusEl = document.getElementById('native-status');
    const statusTextEl = document.getElementById('native-status-text');
    const latencyEl = document.getElementById('native-latency');
    const btn = document.getElementById('footer-healthcheck-btn');

    if (!statusEl || !statusTextEl || !latencyEl) return;

    function setStatus(kind, text, latencyMs) {
      // kind: 'checking' | 'online' | 'error'
      statusEl.classList.remove('status-online', 'status-error', 'status-info');
      if (kind === 'online') statusEl.classList.add('status-online');
      else if (kind === 'error') statusEl.classList.add('status-error');
      else statusEl.classList.add('status-info');

      statusTextEl.textContent = text;
      latencyEl.textContent = typeof latencyMs === 'number' ? `(${latencyMs} ms)` : '';
    }

    async function checkHealth() {
      try {
        setStatus('checking', 'Checking…');
        const start = performance.now();

        const result = await new Promise((resolve) => {
          let settled = false;
          const timeoutMs = 4000;
          const timeoutId = setTimeout(() => {
            if (settled) return; settled = true; resolve({ timeout: true });
          }, timeoutMs);

          try {
            chrome.runtime.sendNativeMessage('com.example.browserlauncher', { action: 'ping' }, (response) => {
              if (settled) return; settled = true; clearTimeout(timeoutId);
              if (chrome.runtime.lastError) {
                resolve({ error: chrome.runtime.lastError.message });
              } else {
                resolve({ response });
              }
            });
          } catch (e) {
            if (settled) return; settled = true; clearTimeout(timeoutId);
            resolve({ error: e?.message || 'Unknown error' });
          }
        });

        const latency = Math.round(performance.now() - start);

        if (result.timeout) {
          setStatus('error', 'Timeout');
          chrome.storage.local.set({ nativeMessagingLastStatus: 'timeout', nativeMessagingLastLatency: latency, nativeMessagingLastChecked: Date.now() });
          return;
        }
        if (result.error) {
          setStatus('error', 'Error');
          statusEl.title = `Native Messaging Error: ${result.error}`;
          chrome.storage.local.set({ nativeMessagingLastStatus: 'error', nativeMessagingLastLatency: latency, nativeMessagingLastChecked: Date.now(), nativeMessagingLastError: result.error });
          return;
        }

        const ok = !!(result.response && (result.response.pong === true));
        if (ok) {
          setStatus('online', 'Active', latency);
          statusEl.title = 'Native messaging host responded successfully';
          chrome.storage.local.set({ nativeMessagingLastStatus: 'online', nativeMessagingLastLatency: latency, nativeMessagingLastChecked: Date.now(), nativeMessagingSystemInfo: result.response.system_info || null });
        } else {
          setStatus('error', 'Unavailable');
          statusEl.title = 'Unexpected response from native messaging host';
          chrome.storage.local.set({ nativeMessagingLastStatus: 'bad-response', nativeMessagingLastLatency: latency, nativeMessagingLastChecked: Date.now(), nativeMessagingLastRaw: result.response || null });
        }
      } catch (err) {
        setStatus('error', 'Error');
        statusEl.title = `Native Messaging Error: ${err?.message || err}`;
        chrome.storage.local.set({ nativeMessagingLastStatus: 'exception', nativeMessagingLastLatency: null, nativeMessagingLastChecked: Date.now(), nativeMessagingLastError: err?.message || String(err) });
      }
    }

    // Expose for other parts if needed
    window.checkNativeMessagingHealth = checkHealth;

    // Restore last known state quickly
    try {
      chrome.storage.local.get(['nativeMessagingLastStatus', 'nativeMessagingLastLatency'], (res) => {
        const st = res.nativeMessagingLastStatus;
        const lat = res.nativeMessagingLastLatency;
        if (st === 'online') setStatus('online', 'Active', lat);
        else if (st) setStatus('error', 'Unavailable', lat);
        else setStatus('checking', 'Checking…');
      });
    } catch { /* ignore */ }

    // Wire button
    if (btn) btn.addEventListener('click', () => { btn.disabled = true; const prev = btn.innerHTML; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>'; checkHealth().finally(() => { btn.disabled = false; btn.innerHTML = '<i class="fas fa-heartbeat"></i>'; }); });

    // Initial check on open
    checkHealth();
  })();

  // ===== WSL Instance Badge (inside WSL tab content) =====
  function updateWSLInstanceBadge() {
    const badge = document.getElementById('wsl-instance-badge');
    if (!badge || !chrome?.storage?.local) return;
    try {
      chrome.storage.local.get(['wslInstance'], (res) => {
        const name = (res?.wslInstance || '').trim();
        if (name) {
          badge.textContent = name;
          badge.style.display = '';
        } else {
          badge.textContent = '';
          badge.style.display = 'none';
        }
      });
    } catch (e) {
      // silent failure if storage unavailable
    }
  }

  // ===== UI Zoom Control =====
  (function initUiZoomControl() {
    const slider = document.getElementById('ui-zoom-slider');
    const valueEl = document.getElementById('ui-zoom-value');
    const minusBtn = document.getElementById('ui-zoom-minus');
    const plusBtn = document.getElementById('ui-zoom-plus');
    const resetBtn = document.getElementById('ui-zoom-reset');

    if (!slider || !valueEl) return; // control not present

    const MIN = parseInt(slider.min || '70', 10);
    const MAX = parseInt(slider.max || '150', 10);
    const STEP = parseInt(slider.step || '5', 10);

    const clamp = (n) => Math.min(MAX, Math.max(MIN, n));

    function applyZoom(percent, persist = true) {
      const p = clamp(parseInt(percent, 10) || 100);
      document.body.style.zoom = p + '%';
      valueEl.textContent = p + '%';
      slider.value = p;
      if (persist && chrome?.storage?.local) {
        chrome.storage.local.set({ uiZoomPercent: p });
      }
    }

    // Load stored zoom or default to 100%
    try {
      chrome.storage.local.get(['uiZoomPercent'], (res) => {
        const initial = parseInt(res.uiZoomPercent, 10);
        applyZoom(!isNaN(initial) ? initial : 100, false);
      });
    } catch (e) {
      // Fallback if storage not available
      applyZoom(100, false);
    }

    slider.addEventListener('input', () => applyZoom(slider.value));
    if (minusBtn) minusBtn.addEventListener('click', () => applyZoom(parseInt(slider.value, 10) - STEP));
    if (plusBtn) plusBtn.addEventListener('click', () => applyZoom(parseInt(slider.value, 10) + STEP));
    if (resetBtn) resetBtn.addEventListener('click', () => applyZoom(100));
  })();

  // Global variables for password protection
  // window.isPasswordVerifiedForSession = false;

  // Helper function to check password modal elements
  // Removed debugPasswordModal since we now use system alert dialog

  // Password button initialization is now handled in initializeWSLPasswordProtection
  let passwordButtonInitialized = false;

  // Check license status immediately when popup opens
  chrome.storage.local.get(['licenseStatus'], function (result) {
    if (result.licenseStatus === 'expired') {
      console.log("License expired - applying UI restrictions");
      restrictUIForExpiredLicense();
    }
  });

  const defaultSettings = {
    chromeBetaPath: 'C:\\Program Files\\Google\\Chrome Beta\\Application\\chrome.exe',
    chromeDevPath: 'C:\\Program Files\\Google\\Chrome Dev\\Application\\chrome.exe',
    chromeStablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    edgeBetaPath: 'C:\\Program Files (x86)\\Microsoft\\Edge Beta\\Application\\msedge.exe',
    edgeDevPath: 'C:\\Program Files (x86)\\Microsoft\\Edge Dev\\Application\\msedge.exe',
    edgeStablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    versionCheckbox: true,
    wslBravePath: '/snap/bin/brave',
    wslChromeBetaPath: 'google-chrome-beta',
    wslChromeDevPath: '/usr/bin/google-chrome-unstable',
    wslChromeStablePath: 'google-chrome-stable',
    wslEdgeBetaPath: 'microsoft-edge-beta',
    wslEdgeDevPath: 'microsoft-edge-dev',
    wslEdgeStablePath: 'microsoft-edge-stable',
    wslFirefoxPath: '/usr/bin/firefox',
    wslInstance: 'ubuntu',
    wslOperaPath: '/snap/bin/opera',
    wslScriptsPath: '', // Add default empty path for WSL scripts
    checkInterval: 60 // Adding default for check interval
  };

  // Define settings for paths, checkboxes, and check interval
  // Define settings for paths, checkboxes, and check interval
  const settings = [
    { id: 'chromeBetaPath', elementId: 'chrome-beta-path', naCheckboxId: 'chrome-beta-na-checkbox' },
    { id: 'chromeDevPath', elementId: 'chrome-dev-path', naCheckboxId: 'chrome-dev-na-checkbox' },
    { id: 'chromeStablePath', elementId: 'chrome-stable-path', naCheckboxId: 'chrome-stable-na-checkbox' },
    { id: 'edgeBetaPath', elementId: 'edge-beta-path', naCheckboxId: 'edge-beta-na-checkbox' },
    { id: 'edgeDevPath', elementId: 'edge-dev-path', naCheckboxId: 'edge-dev-na-checkbox' },
    { id: 'edgeStablePath', elementId: 'edge-stable-path', naCheckboxId: 'edge-stable-na-checkbox' },
    { id: 'wslBravePath', elementId: 'wsl-brave-path' },
    { id: 'wslChromeBetaPath', elementId: 'wsl-chrome-beta-path' },
    { id: 'wslChromeDevPath', elementId: 'wsl-chrome-dev-path' },
    { id: 'wslChromeStablePath', elementId: 'wsl-chrome-stable-path' },
    { id: 'wslEdgeBetaPath', elementId: 'wsl-edge-beta-path' },
    { id: 'wslEdgeDevPath', elementId: 'wsl-edge-dev-path' },
    { id: 'wslEdgeStablePath', elementId: 'wsl-edge-stable-path' },
    { id: 'wslFirefoxPath', elementId: 'wsl-firefox-path' },
    { id: 'wslInstance', elementId: 'wsl-instance' },
    { id: 'wslOperaPath', elementId: 'wsl-opera-path' },
    { id: 'wslScriptsPath', elementId: 'wsl-scripts-path' },
    { id: 'checkInterval', elementId: 'check-interval' } // Adding check interval to the settings list
  ];

  const checkboxSettings = [
    { id: 'edgeStableCheckbox', elementId: 'edge-stable-checkbox' },
    { id: 'edgeBetaCheckbox', elementId: 'edge-beta-checkbox' },
    { id: 'edgeDevCheckbox', elementId: 'edge-dev-checkbox' },
    { id: 'chromeStableCheckbox', elementId: 'chrome-stable-checkbox' },
    { id: 'chromeBetaCheckbox', elementId: 'chrome-beta-checkbox' },
    { id: 'chromeDevCheckbox', elementId: 'chrome-dev-checkbox' }
  ];

  // Settings tab language selector removed; header language selector remains handled by i18n module

  // Initialize versionCheckbox element
  const versionCheckbox = document.getElementById('version-checkbox');

  const loadCheckboxStates = () => {
    chrome.storage.local.get({
      'edge-stable-checkbox': false,
      'edge-beta-checkbox': false,
      'edge-dev-checkbox': false,
      'chrome-stable-checkbox': false,
      'chrome-beta-checkbox': false,
      'chrome-dev-checkbox': false,
      'contextMenuEnabled': true,  // Changed from 'context-menu-toggle' to 'contextMenuEnabled'
      'sandboxContextEnabled': true
    }, function (items) {
      document.getElementById('edge-stable-checkbox').checked = items['edge-stable-checkbox'];
      document.getElementById('edge-beta-checkbox').checked = items['edge-beta-checkbox'];
      document.getElementById('edge-dev-checkbox').checked = items['edge-dev-checkbox'];
      document.getElementById('chrome-stable-checkbox').checked = items['chrome-stable-checkbox'];
      document.getElementById('chrome-beta-checkbox').checked = items['chrome-beta-checkbox'];
      document.getElementById('chrome-dev-checkbox').checked = items['chrome-dev-checkbox'];
      document.getElementById('context-menu-toggle').checked = items['contextMenuEnabled'];
      document.getElementById('sandbox-context-toggle').checked = items['sandboxContextEnabled'];
    });
  };

  const saveCheckboxStates = () => {
    const edgeStableCheckbox = document.getElementById('edge-stable-checkbox').checked;
    const edgeBetaCheckbox = document.getElementById('edge-beta-checkbox').checked;
    const edgeDevCheckbox = document.getElementById('edge-dev-checkbox').checked;
    const chromeStableCheckbox = document.getElementById('chrome-stable-checkbox').checked;
    const chromeBetaCheckbox = document.getElementById('chrome-beta-checkbox').checked;
    const chromeDevCheckbox = document.getElementById('chrome-dev-checkbox').checked;
    const contextMenuToggle = document.getElementById('context-menu-toggle').checked;
    const sandboxContextToggle = document.getElementById('sandbox-context-toggle').checked;

    chrome.storage.local.set({
      'edge-stable-checkbox': edgeStableCheckbox,
      'edge-beta-checkbox': edgeBetaCheckbox,
      'edge-dev-checkbox': edgeDevCheckbox,
      'chrome-stable-checkbox': chromeStableCheckbox,
      'chrome-beta-checkbox': chromeBetaCheckbox,
      'chrome-dev-checkbox': chromeDevCheckbox,
      'contextMenuEnabled': contextMenuToggle,  // Changed from 'context-menu-toggle' to 'contextMenuEnabled'
      'sandboxContextEnabled': sandboxContextToggle
    }, function () {
      // Update context menu state
      chrome.runtime.sendMessage({ action: 'updateContextMenu', enabled: contextMenuToggle });
      // Update sandbox context menu state
      chrome.runtime.sendMessage({ action: 'updateSandboxContextMenu', enabled: sandboxContextToggle });
    });
  };

  checkboxSettings.forEach(setting => {
    const checkbox = document.getElementById(setting.elementId);
    if (checkbox) {
      checkbox.addEventListener('change', saveCheckboxStates);
    }
  });

  loadCheckboxStates();

  const loadSettings = () => {
    chrome.storage.local.get([...settings.map(setting => setting.id), 'powershellUser', 'usePowershellUser'], function (result) {
      settings.forEach(setting => {
        const element = document.getElementById(setting.elementId);
        const naCheckbox = document.getElementById(setting.naCheckboxId);

        if (element) {
          const value = result[setting.id] || defaultSettings[setting.id];
          element.value = value;
          if (naCheckbox) {
            const isNA = value === 'NA';
            naCheckbox.checked = isNA;
            element.disabled = isNA;

            // Event listener to handle checkbox changes
            naCheckbox.addEventListener('change', function () {
              if (this.checked) {
                element.value = 'NA';
                element.disabled = true;
              } else {
                element.value = result[setting.id] || defaultSettings[setting.id];
                element.disabled = false;
              }
            });
          }
        }
      });

      // Load PowerShell user settings
      const powershellUserElement = document.getElementById('powershell-user');
      const usePowershellUserCheckbox = document.getElementById('use-powershell-user-checkbox');

      if (powershellUserElement) {
        powershellUserElement.value = result.powershellUser || '';
      }

      if (usePowershellUserCheckbox) {
        usePowershellUserCheckbox.checked = result.usePowershellUser || false;
      }
    });
  };


  const saveSettings = () => {
    let allFieldsFilled = true;
    const data = {};

    settings.forEach(setting => {
      const element = document.getElementById(setting.elementId);
      const naCheckbox = document.getElementById(setting.naCheckboxId);

      if (element) {
        if (naCheckbox && naCheckbox.checked) {
          data[setting.id] = 'NA';
        } else {
          if (element.value.trim() === '') {
            allFieldsFilled = false;
            alert(`Please fill out the field: ${element.id}`);
          } else {
            data[setting.id] = element.value.trim();
          }
        }
      }
    });

    // Save PowerShell user settings
    const powershellUser = document.getElementById('powershell-user').value.trim();
    const usePowershellUser = document.getElementById('use-powershell-user-checkbox').checked;
    data['powershellUser'] = powershellUser;
    data['usePowershellUser'] = usePowershellUser;

    if (allFieldsFilled) {
      chrome.storage.local.set(data, function () {
        console.log('Settings saved successfully!');
        const message = window.i18n ? window.i18n.t('messages.settings.saved') : 'Settings saved successfully!';
        alert(message);
        // WSL instance names no longer need updating since we use static badges
      });
    } else {
      console.log('Some fields are empty.');
      const message = window.i18n ? window.i18n.t('messages.fill.all.fields') : 'Please fill out all required fields.';
      alert(message);
    }
  };


  document.getElementById('save-paths').addEventListener('click', function () {
    saveSettings();

    const checkInterval = parseInt(document.getElementById('check-interval').value, 10);

    if (!isNaN(checkInterval) && checkInterval >= 1 && checkInterval <= 61) {
      chrome.storage.local.set({ checkInterval: checkInterval }, function () {
        chrome.alarms.clear('checkBrowserVersions', () => {
          chrome.alarms.create('checkBrowserVersions', { periodInMinutes: checkInterval });
          console.log('Check interval updated to ' + checkInterval + ' minutes.');
          // alert('Settings and interval saved successfully!');
        });
      });
    } else {
      alert('Please enter a valid number between 1 and 60 minutes.');
    }
  });

  // Add event listener for Update All Local Browsers button
  document.getElementById('update-browsers').addEventListener('click', function () {
    updateAllLocalBrowsers();
  });

  // Add event listener for Update All WSL Browsers button
  document.getElementById('update-wsl-browsers').addEventListener('click', function () {
    updateAllWSLBrowsers();
  });

  const exportSettings = () => {
    chrome.storage.local.get([
      ...settings.map(setting => setting.id),
      ...checkboxSettings.map(setting => setting.id),
      'powershellUser',
      'usePowershellUser',
      'contextMenuEnabled',
      'sandboxContextEnabled',
      'versionCheckbox',
      'checkInterval',
      'showWSL'
    ], function (result) {
      const blob = new Blob([JSON.stringify(result, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'browser_launcher_settings.json';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    });
  };

  document.getElementById('export-paths').addEventListener('click', exportSettings);

  const importSettings = (event) => {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = function (e) {
        try {
          const importedData = JSON.parse(e.target.result);
          chrome.storage.local.set(importedData, function () {
            console.log('Settings imported successfully!');
            const message = window.i18n ? window.i18n.t('messages.settings.imported') : 'Settings imported successfully!';
            alert(message);

            // Reload all settings
            loadSettings();
            loadCheckboxStates();
            loadShowWSLSetting();
            loadVersionCheckboxState();

            // Update checkbox states based on imported data
            if (importedData.contextMenuEnabled !== undefined) {
              document.getElementById('context-menu-toggle').checked = importedData.contextMenuEnabled;
            }

            if (importedData.sandboxContextEnabled !== undefined) {
              document.getElementById('sandbox-context-toggle').checked = importedData.sandboxContextEnabled;
            }

            if (importedData.versionCheckbox !== undefined) {
              document.getElementById('version-checkbox').checked = importedData.versionCheckbox;
            }

            if (importedData.checkInterval !== undefined) {
              document.getElementById('check-interval').value = importedData.checkInterval;
            }

            // Update PowerShell user fields
            const powershellUserElement = document.getElementById('powershell-user');
            const usePowershellUserCheckbox = document.getElementById('use-powershell-user-checkbox');

            if (powershellUserElement && importedData.powershellUser !== undefined) {
              powershellUserElement.value = importedData.powershellUser;
            }

            if (usePowershellUserCheckbox && importedData.usePowershellUser !== undefined) {
              usePowershellUserCheckbox.checked = importedData.usePowershellUser;
            }

            // Update WSL tabs visibility
            if (importedData.showWSL !== undefined) {
              toggleWSLTabVisibility(importedData.showWSL);
            }

            // Update context menus with the imported settings
            chrome.runtime.sendMessage({ action: 'refreshContextMenus' });
          });
        } catch (error) {
          console.error('Error parsing imported file:', error);
          const message = window.i18n ? window.i18n.t('messages.error.importing') : 'Error importing settings: Invalid JSON format.';
          alert(message);
        }
      };
      reader.readAsText(file);
    }
  };

  // Set up import file input event listener
  const importFile = document.getElementById('import-file');
  if (importFile) {
    importFile.addEventListener('change', importSettings);
  }

  // Import button click handler
  document.getElementById('import-paths').addEventListener('click', function () {
    document.getElementById('import-file').click();
  });

  loadSettings();

  // This array and its event handlers are causing duplicate browser launches
  // Keeping it commented for reference - using localBrowsers and wslBrowsers instead
  /*
  const browsers = [
    { id: "edge-stable-local", command: "edgeStablePath", versionElement: 'edge-stable-version' },
    { id: "edge-beta-local", command: "edgeBetaPath", versionElement: 'edge-beta-version' },
    { id: "edge-dev-local", command: "edgeDevPath", versionElement: 'edge-dev-version' },
    { id: "chrome-stable-local", command: "chromeStablePath", versionElement: 'chrome-stable-version' },
    { id: "chrome-beta-local", command: "chromeBetaPath", versionElement: 'chrome-beta-version' },
    { id: "chrome-dev-local", command: "chromeDevPath", versionElement: 'chrome-dev-version' },
    { id: "edge-stable", command: "wslEdgeStablePath" },
    { id: "edge-beta", command: "wslEdgeBetaPath" },
    { id: "edge-dev", command: "wslEdgeDevPath" },
    { id: "chrome-stable", command: "wslChromeStablePath" },
    { id: "chrome-beta", command: "wslChromeBetaPath" },
    { id: "chrome-dev", command: "wslChromeDevPath" },
    { id: "firefox", command: "wslFirefoxPath" },
    { id: "opera", command: "wslOperaPath" },
    { id: "brave", command: "wslBravePath" },
    { id: "launch-xterm", command: "xterm" },
    { id: "launch-powershell", command: "cmd /c start powershell.exe" },
    { id: "launch-sandbox", command: "WindowsSandbox" }
  ];
  */

  const isWSLCommand = (command) => {
    return command.startsWith('/usr/bin/') || command.startsWith('/snap/bin/') || command.includes('google-chrome') || command.includes('microsoft-edge');
  };

  const showWSLCheckbox = document.getElementById('show-wsl-checkbox');

  const loadShowWSLSetting = () => {
    chrome.storage.local.get('showWSL', function (result) {
      showWSLCheckbox.checked = result.showWSL !== undefined ? result.showWSL : false;
      toggleWSLTabVisibility(showWSLCheckbox.checked);
    });
  };

  const saveShowWSLSetting = () => {
    const showWSL = showWSLCheckbox.checked;
    chrome.storage.local.set({ showWSL: showWSL }, function () {
      console.log('Show WSL setting saved:', showWSL);
      toggleWSLTabVisibility(showWSL);
    });
  };

  const toggleWSLTabVisibility = (show) => {
    const wslTab = document.getElementById('wsl-tab');
    const wslManagerTab = document.getElementById('wsl-manager-tab');
    const updateWslBrowsersButton = document.getElementById('update-wsl-browsers');
    if (show) {
      wslTab.style.display = '';
      wslManagerTab.style.display = '';
      updateWslBrowsersButton.style.display = '';
    } else {
      wslTab.style.display = 'none';
      wslManagerTab.style.display = 'none';
      updateWslBrowsersButton.style.display = 'none';
    }
  };

  showWSLCheckbox.addEventListener('change', saveShowWSLSetting);

  loadShowWSLSetting();
  // Initialize the WSL instance name badge in the tab header
  updateWSLInstanceBadge();
  // React to storage changes for default instance selection
  try {
    chrome.storage.onChanged.addListener((changes, area) => {
      if (area === 'local' && changes.wslInstance) {
        updateWSLInstanceBadge();
      }
    });
  } catch (e) { /* ignore */ }

  // Removing the event handlers from the browsers array since they cause browsers to launch twice
  // The localBrowsers and wslBrowsers arrays handle this functionality now (around line 2646)
  /*
  browsers.forEach(browser => {
    const button = document.getElementById(browser.id);
    if (button) {
      button.addEventListener('click', async () => {
        let command = browser.command;

        if (command.endsWith('Path')) {
          command = await new Promise((resolve) => {
            chrome.storage.local.get([command], function (result) {
              console.log(`Fetched ${command}:`, result);
              resolve(result[command] || defaultSettings[command]);
            });
          });

          if (!command) {
            alert(`Error: Please set the path for ${browser.id.replace(/-/g, ' ')} in the Settings tab.`);
            return;
          }
        }

        if (isWSLCommand(command)) {
          const { wslInstance, wslUsername } = await new Promise((resolve) => {
            chrome.storage.local.get(['wslInstance', 'wslUsername'], function (result) {
              resolve({
                wslInstance: result['wslInstance'] || defaultSettings['wslInstance'],
                wslUsername: result['wslUsername'] || ''
              });
            });
          });

          const userParam = wslUsername ? `-u ${wslUsername}` : '';
          const sandboxParam = wslUsername ? '' : '--no-sandbox';
          
          // Special handling for Firefox in WSL
          if (browser.id === 'firefox') {
            command = `wsl -d ${wslInstance} ${userParam} DISPLAY=:0 ${command} ${sandboxParam}`.trim();
          } else {
            command = `wsl -d ${wslInstance} ${userParam} ${command} ${sandboxParam}`.trim();
          }
        }

        console.log('Sending command:', command);
        chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
          command: command,
          url: browser.id === 'launch-xterm' ? '' : 'https://www.google.com'
        }, (response) => {
          if (chrome.runtime.lastError || (response && response.result && response.result.startsWith("Error:"))) {
            const errorMessage = chrome.runtime.lastError ? chrome.runtime.lastError.message : (response && response.result ? response.result : "Unknown error");
            alert(`Error: ${errorMessage}`);
          } else {
            console.log('Received response:', response);
          }
        });
      });
    } else {
      console.log(`Button with id ${browser.id} not found`);
    }
  });
  */

  // Activate the first tab by default
  document.querySelector('.nav-tabs .nav-item:first-child .nav-link').classList.add('active');
  document.querySelector('.tab-content .tab-pane:first-child').classList.add('show', 'active');

  document.querySelectorAll('.nav-link').forEach(tab => {
    tab.addEventListener('click', function (event) {
      event.preventDefault();
      const targetId = this.getAttribute('href').substring(1);

      document.querySelectorAll('.tab-pane').forEach(pane => {
        pane.classList.remove('show', 'active');
      });
      document.getElementById(targetId).classList.add('show', 'active');

      document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
      });
      this.classList.add('active');
    });
  });

  document.getElementById('settings-tab').addEventListener('click', function () {
    console.log('Settings tab clicked. Loading settings...');
    loadSettings();
  });

  const getBrowserVersion = async (registryKey) => {
    return new Promise((resolve) => {
      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        action: 'getBrowserVersion',
        registryKey: registryKey
      }, (response) => {
        if (chrome.runtime.lastError || (response && response.version && response.version.startsWith("Error:"))) {
          // Suppress errors for registry entries not found (happens for non-installed browsers)
          // const errorMessage = chrome.runtime.lastError ? chrome.runtime.lastError.message : (response && response.version ? response.version : "Unknown error");
          // console.error(`Error fetching version: ${errorMessage}`);
          resolve(null);
        } else {
          resolve(response && response.version ? response.version : null);
        }
      });
    });
  };

  // Helper function to calculate days since a date
  const getDaysAgo = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now - date);
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    return diffDays;
  };

  // Modify the updateBrowserVersions function
  const updateBrowserVersions = async () => {
    const versionCommands = {
      'edge-stable-version': 'HKEY_CURRENT_USER\\Software\\Microsoft\\edge\\BLBeacon',
      'edge-beta-version': 'HKEY_CURRENT_USER\\Software\\Microsoft\\edge beta\\BLBeacon',
      'edge-dev-version': 'HKEY_CURRENT_USER\\Software\\Microsoft\\edge dev\\BLBeacon',
      'chrome-stable-version': 'HKEY_CURRENT_USER\\Software\\Google\\Chrome\\BLBeacon',
      'chrome-beta-version': 'HKEY_CURRENT_USER\\Software\\Google\\Chrome Beta\\BLBeacon',
      'chrome-dev-version': 'HKEY_CURRENT_USER\\Software\\Google\\Chrome Dev\\BLBeacon'
    };

    // Get the version update log to find the last update date for each version
    chrome.storage.local.get('versionUpdateLog', async (result) => {
      const versionLog = result.versionUpdateLog || [];

      for (const [elementId, registryKey] of Object.entries(versionCommands)) {
        const version = await getBrowserVersion(registryKey);
        if (version) {
          // Find the most recent log entry for this version
          const browserName = elementId.replace('-version', '').split('-').map(word =>
            word.charAt(0).toUpperCase() + word.slice(1)
          ).join(' ');

          const lastUpdate = versionLog
            .filter(log => log.browserName.toLowerCase().includes(browserName.toLowerCase()) &&
              log.newVersion === version)
            .sort((a, b) => new Date(b.dateTime) - new Date(a.dateTime))[0];

          const element = document.getElementById(elementId);
          if (lastUpdate) {
            const daysAgo = getDaysAgo(lastUpdate.dateTime);
            element.textContent = `${version} (${daysAgo}d)`;
          } else {
            element.textContent = version;
          }
        } else {
          const notFoundText = window.i18n ? window.i18n.t('browsers.notFound') : 'Not Found';
          const element = document.getElementById(elementId);
          if (element) {
            element.textContent = notFoundText;
          }
        }
      }
    });
  };

  const checkAndUpdateBrowserVersion = () => {
    chrome.storage.local.get('browserVersions', async (result) => {
      const browserVersions = result.browserVersions || {};
      let updateRequired = false;

      for (const [key, version] of Object.entries(browserVersions)) {
        const element = document.getElementById(key);
        if (element) {
          element.textContent = version;
        }
        if (version === '0.0.0.0') {
          updateRequired = true;
        }
      }

      if (updateRequired) {
        await updateBrowserVersions();
      }
    });
  };

  checkAndUpdateBrowserVersion();

  const loadVersionCheckboxState = () => {
    chrome.storage.local.get('versionCheckbox', function (result) {
      versionCheckbox.checked = result.versionCheckbox !== undefined ? result.versionCheckbox : true;
      if (versionCheckbox.checked) {
        updateBrowserVersions();
      }
    });
  };

  const saveVersionCheckboxState = () => {
    const checkVersion = versionCheckbox.checked;
    chrome.storage.local.set({ versionCheckbox: checkVersion }, function () {
      console.log('Version checkbox state saved:', checkVersion);
      if (checkVersion) {
        const resetVersion = '0.0.0.0';
        const browserVersions = {};
        document.querySelectorAll('.browser-version').forEach(span => {
          span.textContent = resetVersion;
          browserVersions[span.id] = resetVersion;
        });
        chrome.storage.local.set({ browserVersions }, () => {
          console.log('Browser versions reset to:', resetVersion);
        });
      } else {
        updateBrowserVersions().then(() => {
          const browserVersions = {};
          document.querySelectorAll('.browser-version').forEach(span => {
            browserVersions[span.id] = span.textContent;
          });
          chrome.storage.local.set({ browserVersions });
        });
      }
    });
  };

  versionCheckbox.addEventListener('change', saveVersionCheckboxState);

  loadVersionCheckboxState();

  document.getElementById('view-eula').addEventListener('click', function () {
    chrome.tabs.create({ url: 'eula.html' });
  });

  // Footer EULA link handler
  document.getElementById('view-eula-footer').addEventListener('click', function (e) {
    e.preventDefault();
    chrome.tabs.create({ url: 'eula.html' });
  });

  const testNotificationButton = document.getElementById('test-notification');
  if (testNotificationButton) {
    testNotificationButton.addEventListener('click', function () {
      triggerTestNotification();
    });
  }

  async function triggerTestNotification() {
    // First check if Edge Stable checkbox is checked
    chrome.storage.local.get(['edgeStableCheckbox'], function (result) {
      if (result.edgeStableCheckbox === true) {
        getBrowserVersion('HKEY_CURRENT_USER\\Software\\Microsoft\\edge\\BLBeacon')
          .then(edgeVersion => {
            if (edgeVersion) {
              showEdgeNotification(edgeVersion, edgeVersion);
            } else {
              alert('Failed to fetch Edge version.');
            }
          });
      } else {
        alert('Edge Stable notifications are disabled. Enable the checkbox to receive notifications.');
      }
    });
  }

  const showEdgeNotification = (oldVersion, newVersion) => {
    const detailsUrl = "https://learn.microsoft.com/en-us/deployedge/microsoft-edge-relnote-stable-channel";
    chrome.notifications.create({
      type: 'basic',
      iconUrl: 'icon.png',
      title: 'Detected Edge browser update',
      message: `Edge browser updated from version ${oldVersion} to ${newVersion}.`,
      priority: 2,
      buttons: [
        { title: 'OK' },
        { title: 'More Details' }
      ]
    }, (notificationId) => {
      chrome.notifications.onButtonClicked.addListener((notifId, buttonIndex) => {
        if (notifId === notificationId) {
          if (buttonIndex === 0) {
            chrome.notifications.clear(notificationId);
          } else if (buttonIndex === 1) {
            chrome.tabs.create({ url: detailsUrl });
          }
        }
      });
    });
  };


  document.getElementById('import-paths').addEventListener('click', function () {
    document.getElementById('import-file').click();
  });

  document.getElementById('import-file').addEventListener('change', function (event) {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = function (e) {
        try {
          const importedData = JSON.parse(e.target.result);
          chrome.storage.local.set(importedData, function () {
            console.log('Settings imported successfully!');
            alert('Settings imported successfully!');
            loadSettings(); // Reload settings to reflect the imported data
          });
        } catch (error) {
          console.error('Error parsing imported file:', error);
          alert('Error importing settings: Invalid JSON format.');
        }
      };
      reader.readAsText(file);
    }
  });

  document.getElementById('version-log-tab').addEventListener('click', function () {
    chrome.storage.local.get('versionUpdateLog', function (result) {
      const logs = result.versionUpdateLog || [];
      const logTableBody = document.getElementById('version-log-table-body');
      logTableBody.innerHTML = ''; // Clear existing content

      logs.forEach(log => {
        const daysAgo = getDaysAgo(log.dateTime);
        const row = document.createElement('tr');
        row.innerHTML = `
          <td>${log.browserName}</td>
          <td>${log.oldVersion}</td>
          <td>${log.newVersion} (${daysAgo}d)</td>
          <td>${log.dateTime}</td>
        `;
        logTableBody.appendChild(row);
      });
    });
  });

  const loadVersionUpdateLog = () => {
    const logTableBody = document.getElementById('version-log-table-body');

    // Clear the table and show a loading message
    logTableBody.innerHTML = `
      <tr>
        <td colspan="4" class="text-center">Refreshing data, please wait...</td>
      </tr>
    `;

    // Introduce a 2-second delay before loading the version update log
    setTimeout(() => {
      chrome.storage.local.get('versionUpdateLog', function (result) {
        const logs = result.versionUpdateLog || [];

        // Clear the table again to remove the loading message
        logTableBody.innerHTML = '';

        // Populate the table with the new data
        logs.forEach(log => {
          const daysAgo = getDaysAgo(log.dateTime);
          const row = document.createElement('tr');
          row.innerHTML = `
            <td>${log.browserName}</td>
            <td>${log.oldVersion}</td>
            <td>${log.newVersion} (${daysAgo}d)</td>
            <td>${log.dateTime}</td>
          `;
          logTableBody.appendChild(row);
        });

        // If there are no logs, show a "no data" message
        if (logs.length === 0) {
          logTableBody.innerHTML = `
            <tr>
              <td colspan="4" class="text-center">No version update logs available.</td>
            </tr>
          `;
        }
      });
    }, 2000); // 2000 milliseconds = 2 seconds
  };

  const exportTableToCSV = () => {
    chrome.storage.local.get('versionUpdateLog', function (result) {
      const logs = result.versionUpdateLog || [];
      let csvContent = "data:text/csv;charset=utf-8,";

      // Add CSV header
      csvContent += "Browser Name,Old Version,New Version,Date/Time\n";

      // Add rows to CSV content
      logs.forEach(log => {
        const row = `${log.browserName},${log.oldVersion},${log.newVersion},${log.dateTime}`;
        csvContent += row + "\n";
      });

      // Create a link to download the CSV file
      const encodedUri = encodeURI(csvContent);
      const link = document.createElement("a");
      link.setAttribute("href", encodedUri);
      link.setAttribute("download", "version_update_log.csv");
      document.body.appendChild(link); // Required for Firefox

      link.click();

      // Cleanup by removing the link after the download starts
      document.body.removeChild(link);
    });
  };


  // Load version update logs when the Version Update Log tab is clicked
  document.getElementById('version-log-tab').addEventListener('click', loadVersionUpdateLog);

  // Refresh button click event
  document.getElementById('refresh-version-log').addEventListener('click', loadVersionUpdateLog);

  // Add event listener for the export link
  document.getElementById('export-csv').addEventListener('click', (event) => {
    event.preventDefault(); // Prevent default link behavior
    exportTableToCSV();
  });

  const prepareWSLCommand = async (command) => {
    const wslInstance = await new Promise((resolve) => {
      chrome.storage.local.get(['wslInstance', 'wslUsername'], function (result) {
        const instance = result['wslInstance'] || 'ubuntu';
        const username = result['wslUsername'] || '';
        resolve({ instance, username });
      });
    });

    const isTerminalCommand = command.includes('konsole') || command.includes('xterm');
    const userParam = wslInstance.username && !isTerminalCommand ? `-u ${wslInstance.username}` : '';
    const sandboxParam = !isTerminalCommand && !wslInstance.username ? '--no-sandbox' : '';
    return `wsl -d ${wslInstance.instance} ${userParam} ${command} ${sandboxParam}`.trim();
  };

  document.getElementById('launch-xterm').addEventListener('click', async () => {
    const konsoleCommand = 'DISPLAY=:0 konsole';
    const xtermCommand = 'DISPLAY=:0 xterm';

    const launchTerminal = async (command) => {
      const { wslInstance, wslUsername } = await new Promise((resolve) => {
        chrome.storage.local.get(['wslInstance', 'wslUsername'], function (result) {
          resolve({
            wslInstance: result['wslInstance'] || 'ubuntu',
            wslUsername: result['wslUsername'] || ''
          });
        });
      });

      const userParam = wslUsername ? `-u ${wslUsername}` : '';
      const wslCommand = `wsl -d ${wslInstance} ${userParam} ${command}`.trim();

      return new Promise((resolve) => {
        chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
          command: wslCommand,
          url: ''
        }, (response) => {
          if (chrome.runtime.lastError || (response && response.result.startsWith("Error:"))) {
            const errorMessage = chrome.runtime.lastError ? chrome.runtime.lastError.message : response.result;
            console.error(`Error launching terminal: ${errorMessage}`);
          } else {
            console.log('Received response:', response);
          }
          resolve();
        });
      });
    };

    Promise.all([
      launchTerminal(konsoleCommand),
      launchTerminal(xtermCommand)
    ]).then(() => {
      console.log('Attempted to launch both Konsole and XTerm');
    }).catch((error) => {
      console.error('Error launching terminals:', error);
      alert('An error occurred while launching terminals. Please check the console for more details.');
    });
  });

  document.getElementById('launch-powershell').addEventListener('click', () => {
    chrome.storage.local.get(['powershellUser', 'usePowershellUser'], function (result) {
      let command;
      if (result.powershellUser && result.usePowershellUser) {
        // command = `runas.exe /savecred /user:${result.powershellUser} "cmd /c powershell"`;
        command = `runas.exe /savecred /user:${result.powershellUser} "powershell Start-Process cmd -Verb RunAs"`;
      } else {
        command = 'cmd /c start powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList \'-NoProfile\'"';
      }

      console.log('Executing command:', command);

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ''
      }, (response) => {
        if (chrome.runtime.lastError || (response && response.result.startsWith("Error:"))) {
          const errorMessage = chrome.runtime.lastError ? chrome.runtime.lastError.message : response.result;
          console.error('Error:', errorMessage);
          alert(`Error: ${errorMessage}`);
        } else {
          console.log('Received response:', response);
        }
      });
    });
  });



  function getWSLInstances() {
    const select = document.getElementById('wsl-instances');
    select.innerHTML = ''; // Clear existing options

    chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
      action: 'getWSLInstances'
    }, (response) => {
      if (chrome.runtime.lastError) {
        console.error(chrome.runtime.lastError);
        return;
      }
      const uniqueInstances = [...new Set(response.instances)]; // Remove duplicates
      updateWSLInstancesList(uniqueInstances);
    });
  }

  function updateWSLInstancesList(instances) {
    const select = document.getElementById('wsl-instances');
    select.innerHTML = ''; // Clear existing options

    // Get the default WSL instance from Chrome storage
    chrome.storage.local.get('wslInstance', function (result) {
      const defaultInstance = result.wslInstance || 'ubuntu';

      // Create a Set to store unique instances and filter out empty strings
      const uniqueInstances = new Set(instances.filter(instance =>
        instance && instance.trim() !== '' && instance !== 'Ubuntu (Default)'
      ));

      uniqueInstances.forEach(instance => {
        const option = document.createElement('option');
        option.value = instance;
        option.textContent = instance;

        // Highlight the default instance in green
        if (instance === defaultInstance) {
          option.style.backgroundColor = '#90EE90'; // Light green color
        } else {
          option.style.backgroundColor = 'white'; // Set white background for non-default
        }

        select.appendChild(option);
      });
    });
  }

  function makeDefaultWSLInstance() {
    const select = document.getElementById('wsl-instances');
    const selectedInstance = select.value;
    if (!selectedInstance) {
      alert('Please select an instance to make default.');
      return;
    }

    // First, try to set the default instance in WSL using native messaging
    chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
      command: `wsl --set-default ${selectedInstance}`,
      url: ''
    }, (response) => {
      if (chrome.runtime.lastError) {
        console.error('Error setting default WSL instance:', chrome.runtime.lastError);
        alert('Error setting default WSL instance: ' + chrome.runtime.lastError.message);
        return;
      }

      if (response && response.result && response.result.startsWith("Error:")) {
        console.error('Error from native messaging:', response.result);
        alert('Error setting default WSL instance: ' + response.result);
        return;
      }

      // If successful, update the extension's storage
      chrome.storage.local.set({ wslInstance: selectedInstance }, function () {
        if (chrome.runtime.lastError) {
          console.error(chrome.runtime.lastError);
          alert('Error saving WSL instance setting: ' + chrome.runtime.lastError.message);
        } else {
          alert(`WSL instance "${selectedInstance}" has been set as default.`);
          // Update the value in the settings tab
          document.getElementById('wsl-instance').value = selectedInstance;
          // Refresh the WSL instances list to update the highlighting
          getWSLInstances();
          // Update the badge in the tab header
          updateWSLInstanceBadge();
        }
      });
    });
  }

  document.getElementById('wsl-manager-tab').addEventListener('click', function () {
    // getWSLInstances();
    loadWSLSettings();
  });
  document.getElementById('refresh-wsl-instances').addEventListener('click', function (event) {
    event.preventDefault(); // Prevent the default link behavior
    // getWSLInstances();
  });
  document.getElementById('create-wsl-instance').addEventListener('click', createWSLInstance);
  document.getElementById('delete-wsl-instance').addEventListener('click', deleteWSLInstance);
  document.getElementById('reinstate-wsl-instance').addEventListener('click', reinstateWSLInstance);
  document.getElementById('rename-wsl-instance').addEventListener('click', renameWSLInstance);
  document.getElementById('clone-wsl-instance').addEventListener('click', cloneWSLInstance);
  document.getElementById('make-default-wsl-instance').addEventListener('click', makeDefaultWSLInstance);
  document.getElementById('save-wsl-settings').addEventListener('click', saveWSLSettings);

  // Add event listener for the new Manage WSL Instance button
  document.getElementById('manage-wsl-instance').addEventListener('click', function () {
    // If password is already verified for this session, proceed directly
    // if (isPasswordVerifiedForSession) {
    //   executeWSLManager();
    //   return;
    // }

    // Otherwise, verify password first
    chrome.storage.local.get(['wslPasswordProtectionEnabled', 'wslPassword'], function (result) {
      if (result.wslPasswordProtectionEnabled && result.wslPassword) {
        // Replace verifyPassword().then with verifyWSLPassword callback
        verifyWSLPassword(function (isValid) {
          if (isValid) {
            // Set the session flag
            // window.isPasswordVerifiedForSession = true;
            executeWSLManager();
          } else {
            alert("Password verification failed. Cannot perform this operation.");
          }
        });
      } else {
        executeWSLManager();
      }
    });
  });

  // Separate function to execute the WSL manager
  function executeWSLManager() {
    chrome.storage.local.get(['wslScriptsPath'], function (result) {
      let scriptPath = result.wslScriptsPath;

      if (!scriptPath) {
        alert('WSL scripts path not set. Please set it in the Settings tab first.');
        return;
      }

      const command = `cmd /c start powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "` +
        `$scriptPath = Join-Path -Path '${scriptPath}' -ChildPath 'Manage-WSLInstance.bat'; ` +
        `if (Test-Path $scriptPath) { ` +
        `  Write-Host 'Found script at:' $scriptPath; ` +
        `  cd '${scriptPath}'; ` +
        `  Write-Host 'Current directory:' (Get-Location); ` +
        `  & $scriptPath; ` +
        `} else { ` +
        `  Write-Host 'Error: Script not found at' $scriptPath; ` +
        `}"`;

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        if (chrome.runtime.lastError) {
          console.error(chrome.runtime.lastError);
          alert('Error launching WSL Instance Manager: ' + chrome.runtime.lastError.message);
        } else {
          console.log('WSL Instance Manager launched successfully');
        }
      });
    });
  }

  function saveWSLSettings() {
    const wslDir = document.getElementById('wsl-dir').value;
    const wslTarPath = document.getElementById('wsl-tar-path').value;
    const wslUsername = document.getElementById('wsl-username').value;

    chrome.storage.local.set({ wslDir, wslTarPath, wslUsername }, function () {
      if (chrome.runtime.lastError) {
        alert('Error saving WSL settings: ' + chrome.runtime.lastError.message);
      } else {
        alert('WSL settings saved successfully!');
      }
    });
  }

  function loadWSLSettings() {
    chrome.storage.local.get(['wslDir', 'wslTarPath', 'wslUsername'], function (result) {
      document.getElementById('wsl-dir').value = result.wslDir || '';
      document.getElementById('wsl-tar-path').value = result.wslTarPath || '';
      document.getElementById('wsl-username').value = result.wslUsername || '';
    });
  }

  function createWSLInstance() {
    chrome.storage.local.get(['wslDir', 'wslTarPath'], function (result) {
      const wslDir = result.wslDir;
      const wslTarPath = result.wslTarPath;

      if (!wslDir || !wslTarPath) {
        alert('Please specify the WSL Instance Folder and WSL tar Image Path File in the fields above and save before creating a new instance.');
        return;
      }

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        action: 'getWSLInstances'
      }, (response) => {
        if (chrome.runtime.lastError) {
          console.error(chrome.runtime.lastError);
          alert('Error getting WSL instances: ' + chrome.runtime.lastError.message);
          return;
        }

        const existingInstances = response.instances;
        const nextInstance = getNextAvailableInstanceName(existingInstances);
        const instanceDir = `${wslDir}\\${nextInstance}`;
        const command = `cmd /c start powershell.exe -NoProfile -Command "` +
          `Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-Command','` +
          `Write-Host ''Creating new WSL instance: ${nextInstance}...''; ` +
          `New-Item -Path ''${instanceDir}'' -ItemType Directory -Force; ` +
          `wsl --import ${nextInstance} ''${instanceDir}'' ''${wslTarPath}''; ` +
          `if ($LASTEXITCODE -eq 0) { ` +
          `  Write-Host ''WSL instance ${nextInstance} created successfully.'' ` +
          `} else { ` +
          `  Write-Host ''Failed to create WSL instance ${nextInstance}.'' ` +
          `}; ` +
          `Read-Host ''Press Enter to close this window''; ` +
          `exit'"`;  // Added exit command after Read-Host



        chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
          command: command,
          url: ''
        }, (response) => {
          if (chrome.runtime.lastError) {
            console.error(chrome.runtime.lastError);
            alert('Error creating WSL instance: ' + chrome.runtime.lastError.message);
            return;
          }
          alert(`Attempted to create new WSL instance: ${nextInstance}. \nPlease check the PowerShell window for details.`);
          getWSLInstances();
        });
      });
    });
  }

  function getNextAvailableInstanceName(existingInstances) {
    const ubuntuInstances = existingInstances.filter(instance =>
      instance.startsWith('Ubuntu-') && instance !== 'Ubuntu (Default)'
    );
    const numbers = ubuntuInstances.map(instance => {
      const match = instance.match(/Ubuntu-(\d+)/);
      return match ? parseInt(match[1]) : 0;
    });
    const maxNumber = Math.max(0, ...numbers);
    return `Ubuntu-${maxNumber + 1}`;
  }

  function deleteWSLInstance() {
    const select = document.getElementById('wsl-instances');
    const selectedInstance = select.value;
    if (!selectedInstance) {
      alert('Please select an instance to delete.');
      return;
    }

    const command = `cmd /c start powershell.exe -NoProfile -Command "` +
      `Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-Command','` +
      `Write-Host ''Unregistering WSL instance: ${selectedInstance}...''; ` +
      `wsl --unregister ${selectedInstance}; ` +
      `if ($LASTEXITCODE -eq 0) { ` +
      `  Write-Host ''WSL instance ${selectedInstance} unregistered successfully.'' ` +
      `} else { ` +
      `  Write-Host ''Failed to unregister WSL instance ${selectedInstance}.'' ` +
      `}; ` +
      `Read-Host ''Press Enter to close this window''; ` +
      `exit'"`;  // Added exit command after Read-Host

    chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
      command: command,
      url: ""
    }, (response) => {
      if (chrome.runtime.lastError) {
        console.error(chrome.runtime.lastError);
        return;
      }
      alert(`Attempted to unregister WSL instance: ${selectedInstance}. \nPlease check the PowerShell window for details.`);
      getWSLInstances();
    });
  }

  function reinstateWSLInstance() {
    const select = document.getElementById('wsl-instances');
    const selectedInstance = select.value;
    if (!selectedInstance) {
      alert('Please select an instance to reset.');
      return;
    }

    chrome.storage.local.get(['wslTarPath', 'wslDir'], function (result) {
      const wslTarPath = result.wslTarPath || 'c:\\ubuntu-export.tar';
      const wslDir = result.wslDir || 'c:\\WSL';

      const command = `cmd /c start powershell.exe -NoProfile -Command "` +
        `Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-Command','` +
        `Write-Host ''Resetting WSL instance: ${selectedInstance}...''; ` +
        `wsl --unregister ${selectedInstance}; ` +
        `Write-Host ''WSL instance ${selectedInstance} unregistered.''; ` +
        `New-Item -Path ''${wslDir}\\${selectedInstance}'' -ItemType Directory -Force; ` +
        `wsl --import ${selectedInstance} ''${wslDir}\\${selectedInstance}'' ''${wslTarPath}''; ` +
        `if ($LASTEXITCODE -eq 0) { ` +
        `  Write-Host ''WSL instance ${selectedInstance} reset successful.'' ` +
        `} else { ` +
        `  Write-Host ''Failed to reset WSL instance ${selectedInstance}.'' ` +
        `}; ` +
        `Read-Host ''Press Enter to close this window''; ` +
        `exit'"`;

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        if (chrome.runtime.lastError) {
          console.error(chrome.runtime.lastError);
          return;
        }
        alert(`Attempted to reset WSL instance: ${selectedInstance}. \nPlease check the PowerShell window for details.`);
        getWSLInstances();
      });
    });
  }

  document.getElementById('wsl-manager-tab').addEventListener('click', getWSLInstances);
  document.getElementById('refresh-wsl-instances').addEventListener('click', function (event) {
    event.preventDefault(); // Prevent the default link behavior
    getWSLInstances();
  });
  document.getElementById('create-wsl-instance').addEventListener('click', createWSLInstance);
  document.getElementById('delete-wsl-instance').addEventListener('click', deleteWSLInstance);
  document.getElementById('reinstate-wsl-instance').addEventListener('click', reinstateWSLInstance);
  document.getElementById('rename-wsl-instance').addEventListener('click', renameWSLInstance);
  document.getElementById('clone-wsl-instance').addEventListener('click', cloneWSLInstance);



  function exportWSLInstance() {
    const select = document.getElementById('wsl-instances');
    const selectedInstance = select.value;
    if (!selectedInstance) {
      alert('Please select an instance to export.');
      return;
    }

    chrome.storage.local.get(['wslDir'], function (result) {
      const wslDir = result.wslDir || 'C:\\WSL';
      const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
      const exportPath = `${wslDir}\\${selectedInstance}-export-${timestamp}.tar`;

      const command = `cmd /c start powershell.exe -NoProfile -Command "` +
        `Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-Command','` +
        `Write-Host ''Exporting WSL instance: ${selectedInstance}. This may take a few minutes...''; ` +
        `if (!(Test-Path -Path ''${wslDir}'')) { ` +
        `  New-Item -ItemType Directory -Force -Path ''${wslDir}''; ` +
        `  Write-Host ''Created directory: ${wslDir}''; ` +
        `} ` +
        `wsl --export ${selectedInstance} ''${exportPath}''; ` +
        `if ($LASTEXITCODE -eq 0) { ` +
        `  $fileSize = (Get-Item ''${exportPath}'').Length / 1MB; ` +
        `  Write-Host ''Export in progress, this may take a few minutes.''; ` +
        `  Write-Host ''The operation completed successfully.''; ` +
        `  Write-Host ''WSL instance ${selectedInstance} exported successfully to ${exportPath}''; ` +
        `  Write-Host (''Exported file size: {0:F2} MB'' -f $fileSize); ` +
        `} else { ` +
        `  Write-Host ''Failed to export WSL instance ${selectedInstance}.''; ` +
        `  Write-Host ''Error code: $LASTEXITCODE''; ` +
        `}; ` +
        `Read-Host ''Press Enter to close this window''; ` +
        `exit'"`;

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        if (chrome.runtime.lastError) {
          console.error(chrome.runtime.lastError);
          return;
        }
        alert(`Attempted to export WSL instance: ${selectedInstance}. \nPlease check the PowerShell window for details.`);
      });
    });
  }

  // Add this line with the other event listeners section
  document.getElementById('export-wsl-instance').addEventListener('click', exportWSLInstance);

  // REMOVING DUPLICATE EVENT LISTENERS - these were already registered earlier around line 900
  // document.getElementById('create-wsl-instance').addEventListener('click', createWSLInstance);
  // document.getElementById('delete-wsl-instance').addEventListener('click', deleteWSLInstance);
  // document.getElementById('reinstate-wsl-instance').addEventListener('click', reinstateWSLInstance);
  // document.getElementById('rename-wsl-instance').addEventListener('click', renameWSLInstance);
  // document.getElementById('clone-wsl-instance').addEventListener('click', cloneWSLInstance);

  document.getElementById('create-wsl-instance-scratch').addEventListener('click', createWSLInstanceFromScratch);

  // WSL instance name functionality removed since we now use badges instead of dynamic instance names
  // The WSL sections now show "WSL" badges instead of dynamic instance names

  // Add this to the existing event listeners section
  document.getElementById('launch-sandbox').addEventListener('click', launchWindowsSandbox);

  // Add this function to handle launching Windows Sandbox
  function launchWindowsSandbox() {
    const command = 'WindowsSandbox';

    chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
      command: command,
      url: ''
    }, (response) => {
      if (chrome.runtime.lastError || (response && response.result.startsWith("Error:"))) {
        const errorMessage = chrome.runtime.lastError ? chrome.runtime.lastError.message : response.result;
        console.error('Error launching Windows Sandbox:', errorMessage);
        // Instead of showing an alert, we'll log the error silently
        console.log(`Error launching Windows Sandbox: ${errorMessage}`);
      } else {
        console.log('Windows Sandbox launched successfully');
      }
    });
  }

  // Load search settings tab functionality
  document.getElementById('search-settings-tab').addEventListener('click', function () {
    loadSearchSettings();
  });

  // Function to load search settings
  function loadSearchSettings() {
    chrome.storage.local.get('searchConfig', function (result) {
      const searchConfig = result.searchConfig || {
        youtube: true,
        google: true,
        duckduckgo: true,
        perplexity: true,
        chatgpt: true,
        amazon: true,
        sandbox: true,
        googlemaps: true
      };

      // Set toggle states
      document.getElementById('youtube-toggle').checked = searchConfig.youtube;
      document.getElementById('google-toggle').checked = searchConfig.google;
      document.getElementById('duckduckgo-toggle').checked = searchConfig.duckduckgo;
      document.getElementById('perplexity-toggle').checked = searchConfig.perplexity;
      document.getElementById('chatgpt-toggle').checked = searchConfig.chatgpt;
      document.getElementById('amazon-toggle').checked = searchConfig.amazon;
      document.getElementById('sandbox-toggle').checked = searchConfig.sandbox !== false;
      document.getElementById('googlemaps-toggle').checked = searchConfig.googlemaps;
    });
  }

  // Add event listeners for all search toggles
  document.querySelectorAll('.search-toggle').forEach(toggle => {
    toggle.addEventListener('change', function () {
      const engine = this.dataset.engine;
      const isEnabled = this.checked;

      chrome.storage.local.get('searchConfig', function (result) {
        const searchConfig = result.searchConfig || {};
        searchConfig[engine] = isEnabled;

        chrome.storage.local.set({ searchConfig }, function () {
          console.log(`${engine} search ${isEnabled ? 'enabled' : 'disabled'}`);
          // Refresh context menus when settings change
          chrome.runtime.sendMessage({ action: 'refreshContextMenus' });
        });
      });
    });
  });

  // Context menu toggle functionality
  const contextMenuToggle = document.getElementById('context-menu-toggle');

  // Load initial state
  chrome.storage.local.get('contextMenuEnabled', function (result) {
    if (contextMenuToggle) {
      contextMenuToggle.checked = result.contextMenuEnabled !== false;
    }
  });

  // Add change listener
  if (contextMenuToggle) {
    contextMenuToggle.addEventListener('change', function () {
      const enabled = this.checked;
      chrome.storage.local.set({ contextMenuEnabled: enabled }, function () {
        console.log(`Context menu ${enabled ? 'enabled' : 'disabled'}`);
        // Refresh context menus
        chrome.runtime.sendMessage({ action: 'refreshContextMenus' });
      });
    });
  }

  // Add event listener for the context menu toggle
  document.getElementById('context-menu-toggle').addEventListener('change', function () {
    const enabled = this.checked;
    chrome.storage.local.set({ contextMenuEnabled: enabled }, function () {
      // Send message to update the context menu
      chrome.runtime.sendMessage({ action: 'updateContextMenu', enabled: enabled });
    });
  });

  // Load search settings
  loadSearchSettings();

  // ===== Language Change Listener =====
  document.addEventListener('languageChanged', function (e) {
    const newLanguage = e.detail.language;
    console.log('Language changed to:', newLanguage);

    // Update any dynamic content that needs re-translation
    updateDynamicTranslations(newLanguage);

    // Save language preference
    chrome.storage.local.set({ selectedLanguage: newLanguage });
  });

  function updateDynamicTranslations(langCode) {
    // Update version log "No data" message if visible
    const logTableBody = document.getElementById('version-log-table-body');
    if (logTableBody && logTableBody.children.length === 1) {
      const firstRow = logTableBody.children[0];
      if (firstRow.children.length === 1 && firstRow.children[0].colSpan === 4) {
        const noDataMessage = window.i18n ? window.i18n.t('version.log.no.data') : 'No version update logs available.';
        firstRow.children[0].textContent = noDataMessage;
      }
    }

    // Update any alerts or messages that might be visible
    updateVisibleMessages(langCode);
  }

  function updateVisibleMessages(langCode) {
    // This function can be extended to update any dynamic messages
    // that are not covered by the standard data-i18n attributes
    console.log('Updating visible messages for language:', langCode);
  }

  function renameWSLInstance() {
    const select = document.getElementById('wsl-instances');
    const selectedInstance = select.value;
    if (!selectedInstance) {
      alert('Please select an instance to rename.');
      return;
    }

    const newName = prompt('Enter new name for the WSL instance:', selectedInstance);
    if (!newName || newName === selectedInstance) {
      return;
    }

    chrome.storage.local.get(['wslDir'], function (result) {
      const wslDir = result.wslDir || 'C:\\WSL';
      const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
      const tempExportPath = `${wslDir}\\${selectedInstance}-temp-${timestamp}.tar`;

      const command = `cmd /c start powershell.exe -NoProfile -Command "` +
        `Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-Command','` +
        `Write-Host ''Renaming WSL instance from ${selectedInstance} to ${newName}...''; ` +
        `wsl --export ${selectedInstance} ''${tempExportPath}''; ` +
        `if ($LASTEXITCODE -eq 0) { ` +
        `  Write-Host ''Instance exported successfully.''; ` +
        `  wsl --unregister ${selectedInstance}; ` +
        `  if ($LASTEXITCODE -eq 0) { ` +
        `    Write-Host ''Old instance unregistered successfully.''; ` +
        `    wsl --import ${newName} ''${wslDir}\\${newName}'' ''${tempExportPath}''; ` +
        `    if ($LASTEXITCODE -eq 0) { ` +
        `      Write-Host ''New instance created successfully.''; ` +
        `      Remove-Item ''${tempExportPath}''; ` +
        `      Write-Host ''Temporary export file removed.''; ` +
        `    } else { ` +
        `      Write-Host ''Failed to create new instance.''; ` +
        `    } ` +
        `  } else { ` +
        `    Write-Host ''Failed to unregister old instance.''; ` +
        `  } ` +
        `} else { ` +
        `  Write-Host ''Failed to export instance.''; ` +
        `}; ` +
        `Read-Host ''Press Enter to close this window''; ` +
        `exit'"`;

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        if (chrome.runtime.lastError) {
          console.error(chrome.runtime.lastError);
          return;
        }
        alert(`Attempted to rename WSL instance from ${selectedInstance} to ${newName}. \nPlease check the PowerShell window for details.`);
        getWSLInstances();
      });
    });
  }

  function cloneWSLInstance() {
    const select = document.getElementById('wsl-instances');
    const selectedInstance = select.value;
    if (!selectedInstance) {
      alert('Please select an instance to clone.');
      return;
    }

    // No need to ask for a name here - this will happen after password verification
    // The actual clone operation is now done in the handler that's called
    // after password verification in setupSecureButtons

    // Get name and perform clone
    const getNameAndClone = () => {
      const newName = prompt('Enter new name for the cloned WSL instance:', selectedInstance + '-clone');
      if (!newName) {
        return; // User cancelled
      }

      // Validate the new name according to the rules
      const nameRegex = /^[a-zA-Z][a-zA-Z0-9-]{2,14}$/;
      if (!nameRegex.test(newName)) {
        alert('Invalid name format. Name must:\n' +
          '- Start with a letter\n' +
          '- Be 3-15 characters long\n' +
          '- Contain only letters, numbers, and hyphens\n' +
          '- Not contain special characters');
        return;
      }

      chrome.storage.local.get(['wslDir'], function (result) {
        const wslDir = result.wslDir || 'C:\\WSL';
        const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
        const tempExportPath = `${wslDir}\\${selectedInstance}-temp-${timestamp}.tar`;

        const command = `cmd /c start powershell.exe -NoProfile -Command "` +
          `Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-Command','` +
          `Write-Host ''Cloning WSL instance from ${selectedInstance} to ${newName}...''; ` +
          `wsl --export ${selectedInstance} ''${tempExportPath}''; ` +
          `if ($LASTEXITCODE -eq 0) { ` +
          `  Write-Host ''Instance exported successfully.''; ` +
          `  wsl --import ${newName} ''${wslDir}\\${newName}'' ''${tempExportPath}''; ` +
          `  if ($LASTEXITCODE -eq 0) { ` +
          `    Write-Host ''New instance created successfully.''; ` +
          `    Remove-Item ''${tempExportPath}''; ` +
          `    Write-Host ''Temporary export file removed.''; ` +
          `  } else { ` +
          `    Write-Host ''Failed to create new instance.''; ` +
          `  } ` +
          `} else { ` +
          `  Write-Host ''Failed to export instance.''; ` +
          `}; ` +
          `Read-Host ''Press Enter to close this window''; ` +
          `exit'"`;

        chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
          command: command,
          url: ""
        }, (response) => {
          if (chrome.runtime.lastError) {
            console.error(chrome.runtime.lastError);
            return;
          }
          alert(`Attempted to clone WSL instance from ${selectedInstance} to ${newName}. \nPlease check the PowerShell window for details.`);
          getWSLInstances();
        });
      });
    };

    // If we're called directly (not through the secure button handler),
    // execute the clone operation right away
    if (window.bypassPasswordProtection) {
      getNameAndClone();
    } else {
      // Otherwise, this is the actual operation that will be performed
      // after password verification in the secure button handler
      getNameAndClone();
    }
  }

  // WSL Password Protection section
  function initializeWSLPasswordProtection() {
    console.log('Initializing WSL password protection');

    // Password protection is always enabled
    chrome.storage.local.set({ wslPasswordProtectionEnabled: true }, function () {
      console.log('WSL password protection is always enabled');
    });

    // Check if a password is set, if not, prompt to set one
    chrome.storage.local.get('wslPassword', function (result) {
      if (!result.wslPassword) {
        setTimeout(() => {
          alert('Password protection is required for WSL operations. Please set a password now.');
          showSimplePasswordPrompt(
            'Please set a password for WSL operations (minimum 8 characters with at least one number):',
            setNewWSLPassword
          );
        }, 1000);
      }
    });

    // Function to handle password change with completion callback
    function handleChangePasswordWithCompletion(completionCallback) {
      console.log('Handling password change with completion callback');

      chrome.storage.local.get('wslPassword', function (result) {
        if (!result.wslPassword) {
          // No password set yet, just set a new one
          showSimplePasswordPrompt(
            'Please set a password for WSL operations (minimum 8 characters with at least one number):',
            function (password) {
              setNewWSLPassword(password);
              // Re-enable button regardless of outcome
              if (completionCallback) completionCallback();
            }
          );
          return;
        }

        // Use the new change password dialog
        showChangePasswordDialog(function (result) {
          if (!result) {
            console.log('Password change cancelled');
          } else if (result.success) {
            alert(result.message);
          } else {
            alert(result.message || 'Password change failed');
          }

          // Re-enable button regardless of outcome
          if (completionCallback) completionCallback();
        });
      });
    }

    // Set up change password button only if not already initialized
    if (!passwordButtonInitialized) {
      const changePasswordButton = document.getElementById('change-wsl-password');
      if (changePasswordButton) {
        console.log('Setting up change password button');
        const newButton = changePasswordButton.cloneNode(true);
        changePasswordButton.parentNode.replaceChild(newButton, changePasswordButton);

        // Add a single event listener to the button
        newButton.addEventListener('click', function (e) {
          e.preventDefault();
          // Prevent double-clicks
          if (this.disabled) return;
          this.disabled = true;

          console.log('Change password button clicked');

          // Store reference to button for re-enabling
          const button = this;

          // Call handleChangePassword and handle completion
          handleChangePasswordWithCompletion(function () {
            button.disabled = false;
          });
        });

        passwordButtonInitialized = true;
      } else {
        console.error('Change password button not found');
      }
    }

    // Set up protected button handlers
    setupSecureButtons();
  }

  function setupSecureButtons() {
    console.log('Setting up secure buttons for WSL operations');

    // Define the buttons that need password protection
    const protectedButtons = [
      { id: 'create-wsl-instance', handler: createWSLInstance },
      { id: 'delete-wsl-instance', handler: deleteWSLInstance },
      { id: 'rename-wsl-instance', handler: renameWSLInstance },
      { id: 'clone-wsl-instance', handler: cloneWSLInstance },
      { id: 'reinstate-wsl-instance', handler: reinstateWSLInstance },
      { id: 'export-wsl-instance', handler: exportWSLInstance },
      { id: 'make-default-wsl-instance', handler: makeDefaultWSLInstance },
      { id: 'create-wsl-instance-scratch', handler: createWSLInstanceFromScratch }
    ];

    // For each button, replace its click handler with a protected version
    protectedButtons.forEach(btn => {
      const button = document.getElementById(btn.id);
      if (button) {
        console.log(`Setting up secure handler for: ${btn.id}`);

        // First, remove all existing click listeners by cloning the element
        const clone = button.cloneNode(true);
        button.parentNode.replaceChild(clone, button);

        // Then, add our protected click handler
        clone.addEventListener('click', function (event) {
          event.preventDefault();
          console.log(`Protected button clicked: ${btn.id}`);

          // Always verify password before executing handler
          verifyWSLPassword(function (isValid) {
            if (isValid) {
              console.log(`Password verified, executing handler for: ${btn.id}`);
              btn.handler();
            } else {
              console.log(`Password verification failed for: ${btn.id}`);
            }
          });
        });

        console.log(`Secured button: ${btn.id}`);
      } else {
        console.warn(`Button not found: ${btn.id}`);
      }
    });
  }

  // A much simpler password modal
  function showSimplePasswordPrompt(message, callback) {
    console.log('Showing custom password prompt:', message);

    const modal = document.getElementById('password-modal');
    const passwordInput = document.getElementById('password-input');
    const passwordLabel = document.getElementById('password-label');
    const passwordMessage = document.getElementById('password-message');
    const singleMode = document.getElementById('single-password-mode');
    const changeMode = document.getElementById('change-password-mode');
    const modalTitle = document.getElementById('passwordModalLabel');
    const okBtn = document.getElementById('password-modal-ok');
    const cancelBtn = document.getElementById('password-modal-cancel');
    const closeBtn = document.getElementById('password-modal-close');

    // Show single password mode
    singleMode.style.display = 'block';
    changeMode.style.display = 'none';
    modalTitle.textContent = 'Password Required';

    // Set the label message
    passwordLabel.textContent = message;

    // Clear previous input and messages
    passwordInput.value = '';
    passwordMessage.style.display = 'none';

    // Store callback for later use
    modal._passwordCallback = callback;
    modal._isChangePasswordMode = false;

    // Show modal using the same approach as license modal
    showPasswordModal(modal);

    // Focus on password input
    setTimeout(() => {
      passwordInput.focus();
    }, 300);

    // Handle Enter key in password input
    passwordInput.onkeydown = function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        handleSinglePasswordOk();
      }
      if (event.key === 'Escape') {
        event.preventDefault();
        handlePasswordCancel();
      }
    };

    // Handle OK button
    okBtn.onclick = handleSinglePasswordOk;

    // Handle Cancel and Close buttons
    cancelBtn.onclick = handlePasswordCancel;
    closeBtn.onclick = handlePasswordCancel;

    function handleSinglePasswordOk() {
      const password = passwordInput.value;

      if (!password || password.trim() === '') {
        showPasswordMessage('Password cannot be empty.', false);
        passwordInput.focus();
        return;
      }

      // Check length and numbers for new passwords (not for verification)
      if (message.includes('set a password') && (password.length < 8 || !/\d/.test(password))) {
        showPasswordMessage('Password must be at least 8 characters long and contain at least one number.', false);
        passwordInput.focus();
        return;
      }

      hidePasswordModal(modal);

      // Call the callback with the password
      setTimeout(() => {
        if (modal._passwordCallback) {
          modal._passwordCallback(password);
          modal._passwordCallback = null;
        }
      }, 100);
    }

    function handlePasswordCancel() {
      hidePasswordModal(modal);

      // Call the callback with null (cancelled)
      setTimeout(() => {
        if (modal._passwordCallback) {
          modal._passwordCallback(null);
          modal._passwordCallback = null;
        }
      }, 100);
    }
  }

  // New function for change password dialog with all fields
  function showChangePasswordDialog(callback) {
    console.log('Showing change password dialog');

    const modal = document.getElementById('password-modal');
    const currentPasswordInput = document.getElementById('current-password-input');
    const newPasswordInput = document.getElementById('new-password-input');
    const confirmPasswordInput = document.getElementById('confirm-password-input');
    const passwordMessage = document.getElementById('password-message');
    const singleMode = document.getElementById('single-password-mode');
    const changeMode = document.getElementById('change-password-mode');
    const modalTitle = document.getElementById('passwordModalLabel');
    const okBtn = document.getElementById('password-modal-ok');
    const cancelBtn = document.getElementById('password-modal-cancel');
    const closeBtn = document.getElementById('password-modal-close');
    const verifyBtn = document.getElementById('verify-current-password-btn');
    const currentPasswordStatus = document.getElementById('current-password-status');

    // Show change password mode
    singleMode.style.display = 'none';
    changeMode.style.display = 'block';
    modalTitle.textContent = 'Change Password';

    // Clear previous inputs and messages
    currentPasswordInput.value = '';
    newPasswordInput.value = '';
    confirmPasswordInput.value = '';
    passwordMessage.style.display = 'none';
    currentPasswordStatus.style.display = 'none';

    // Reset field states
    newPasswordInput.disabled = true;
    confirmPasswordInput.disabled = true;
    verifyBtn.disabled = false;
    okBtn.disabled = true;

    // Store callback and verification state
    modal._passwordCallback = callback;
    modal._isChangePasswordMode = true;
    modal._currentPasswordVerified = false;

    // Show modal
    showPasswordModal(modal);

    // Focus on current password input
    setTimeout(() => {
      currentPasswordInput.focus();
    }, 300);

    // Handle current password input changes
    currentPasswordInput.oninput = function () {
      // Reset verification state when password changes
      modal._currentPasswordVerified = false;
      newPasswordInput.disabled = true;
      confirmPasswordInput.disabled = true;
      okBtn.disabled = true;
      currentPasswordStatus.style.display = 'none';

      // Enable/disable verify button based on input
      verifyBtn.disabled = !this.value.trim();
    };

    // Handle Enter key navigation
    currentPasswordInput.onkeydown = function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        if (!verifyBtn.disabled) {
          handleVerifyCurrentPassword();
        }
      }
      if (event.key === 'Escape') {
        event.preventDefault();
        handlePasswordCancel();
      }
    };

    newPasswordInput.onkeydown = function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        if (!this.disabled) {
          confirmPasswordInput.focus();
        }
      }
      if (event.key === 'Escape') {
        event.preventDefault();
        handlePasswordCancel();
      }
    };

    // Handle new password input changes for validation
    newPasswordInput.oninput = function () {
      validateNewPasswordFields();
    };

    confirmPasswordInput.onkeydown = function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        if (!okBtn.disabled) {
          handleChangePasswordOk();
        }
      }
      if (event.key === 'Escape') {
        event.preventDefault();
        handlePasswordCancel();
      }
    };

    // Handle confirm password input changes for validation
    confirmPasswordInput.oninput = function () {
      validateNewPasswordFields();
    };

    // Handle Verify button
    verifyBtn.onclick = handleVerifyCurrentPassword;

    // Handle OK button
    okBtn.onclick = handleChangePasswordOk;

    // Handle Cancel and Close buttons
    cancelBtn.onclick = handlePasswordCancel;
    closeBtn.onclick = handlePasswordCancel;

    // Function to verify current password
    function handleVerifyCurrentPassword() {
      const currentPassword = currentPasswordInput.value.trim();

      if (!currentPassword) {
        showCurrentPasswordStatus('Please enter your current password.', 'error');
        return;
      }

      // Show verifying status
      showCurrentPasswordStatus('Verifying password...', 'verifying');
      verifyBtn.disabled = true;

      // Get stored password and verify
      chrome.storage.local.get('wslPassword', function (result) {
        digestPassword(currentPassword).then(hashedCurrentPassword => {
          if (hashedCurrentPassword !== result.wslPassword) {
            showCurrentPasswordStatus('Current password is incorrect.', 'error');
            verifyBtn.disabled = false;
            modal._currentPasswordVerified = false;
          } else {
            showCurrentPasswordStatus('Password verified successfully!', 'success');
            modal._currentPasswordVerified = true;

            // Enable new password fields
            newPasswordInput.disabled = false;
            confirmPasswordInput.disabled = false;

            // Focus on new password field
            setTimeout(() => {
              newPasswordInput.focus();
            }, 500);

            // Validate new password fields
            validateNewPasswordFields();
          }
        }).catch(error => {
          console.error('Error verifying password:', error);
          showCurrentPasswordStatus('Error verifying password. Please try again.', 'error');
          verifyBtn.disabled = false;
          modal._currentPasswordVerified = false;
        });
      });
    }

    // Function to show current password status
    function showCurrentPasswordStatus(message, type) {
      currentPasswordStatus.textContent = message;
      currentPasswordStatus.className = `status-${type}`;
      currentPasswordStatus.style.display = 'block';
    }

    // Function to validate new password fields and enable/disable OK button
    function validateNewPasswordFields() {
      const newPassword = newPasswordInput.value;
      const confirmPassword = confirmPasswordInput.value;

      let isValid = modal._currentPasswordVerified &&
        newPassword &&
        newPassword.length >= 8 &&
        /\d/.test(newPassword) &&
        confirmPassword &&
        newPassword === confirmPassword;

      okBtn.disabled = !isValid;

      // Show inline validation for new password
      if (newPassword && (newPassword.length < 8 || !/\d/.test(newPassword))) {
        showPasswordMessage('Password must be at least 8 characters with at least one number.', false);
      } else if (newPassword && confirmPassword && newPassword !== confirmPassword) {
        showPasswordMessage('Passwords do not match.', false);
      } else if (isValid) {
        passwordMessage.style.display = 'none';
      }
    }

    function handleChangePasswordOk() {
      // At this point, current password is already verified and validation is done
      const currentPassword = currentPasswordInput.value;
      const newPassword = newPasswordInput.value;

      // Check if new password is different from current
      if (currentPassword === newPassword) {
        showPasswordMessage('New password must be different from current password.', false);
        newPasswordInput.focus();
        return;
      }

      // Save the new password
      showPasswordMessage('Saving new password...', true);
      okBtn.disabled = true;

      digestPassword(newPassword).then(hashedNewPassword => {
        chrome.storage.local.set({
          wslPassword: hashedNewPassword,
          failedAttempts: 0,
          lockoutTime: null
        }, function () {
          hidePasswordModal(modal);

          // Call the callback with success
          setTimeout(() => {
            if (modal._passwordCallback) {
              modal._passwordCallback({
                success: true,
                message: 'Password changed successfully!'
              });
              modal._passwordCallback = null;
            }
          }, 100);
        });
      }).catch(error => {
        console.error('Error hashing new password:', error);
        showPasswordMessage('Error saving new password. Please try again.', false);
        okBtn.disabled = false;
      });
    }

    function handlePasswordCancel() {
      hidePasswordModal(modal);

      // Call the callback with null (cancelled)
      setTimeout(() => {
        if (modal._passwordCallback) {
          modal._passwordCallback(null);
          modal._passwordCallback = null;
        }
      }, 100);
    }
  }

  // Show password modal
  function showPasswordModal(modal) {
    modal.style.zIndex = '2147483647';
    modal.style.display = 'block';
    modal.style.backgroundColor = 'transparent';
    modal.style.pointerEvents = 'none';

    // Make dialog clickable
    const dialog = modal.querySelector('.modal-dialog');
    if (dialog) {
      dialog.style.pointerEvents = 'auto';
    }

    // Remove inert attribute
    modal.removeAttribute('inert');

    // Add global ESC key handler for this modal
    const escKeyHandler = function (event) {
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        // Trigger cancel action
        const cancelBtn = modal.querySelector('#password-modal-cancel');
        if (cancelBtn && cancelBtn.onclick) {
          cancelBtn.onclick();
        }
        // Remove this specific handler
        document.removeEventListener('keydown', escKeyHandler, true);
      }
    };

    // Store the handler reference on the modal for cleanup
    modal._escKeyHandler = escKeyHandler;

    // Add the keydown listener with capture to ensure it gets called first
    document.addEventListener('keydown', escKeyHandler, true);

    if (typeof jQuery !== 'undefined') {
      // Use jQuery if available
      $(modal).modal({
        show: true,
        backdrop: false, // Disable backdrop
        keyboard: true
      });

      // Remove any backdrop that jQuery might create
      setTimeout(() => {
        const jqueryBackdrop = document.querySelector('.modal-backdrop');
        if (jqueryBackdrop) {
          jqueryBackdrop.remove();
        }
      }, 100);
    } else {
      // Vanilla JS fallback
      modal.classList.add('show');
    }
  }

  // Hide password modal
  function hidePasswordModal(modal) {
    // Clean up the ESC key handler
    if (modal._escKeyHandler) {
      document.removeEventListener('keydown', modal._escKeyHandler, true);
      modal._escKeyHandler = null;
    }

    if (typeof jQuery !== 'undefined') {
      $(modal).modal('hide');
      setTimeout(() => {
        modal.setAttribute('inert', '');
        modal.style.zIndex = '';
        modal.style.backgroundColor = '';
        modal.style.pointerEvents = '';
      }, 300);
    } else {
      modal.classList.remove('show');
      modal.style.display = 'none';
      modal.style.zIndex = '';
      modal.style.backgroundColor = '';
      modal.style.pointerEvents = '';
      modal.setAttribute('inert', '');
    }
  }

  // Show message in password modal
  function showPasswordMessage(message, isSuccess) {
    const passwordMessage = document.getElementById('password-message');
    passwordMessage.textContent = message;
    passwordMessage.className = isSuccess ? 'alert alert-info' : 'alert alert-danger';
    passwordMessage.style.display = 'block';

    // Hide message after 3 seconds
    setTimeout(() => {
      passwordMessage.style.display = 'none';
    }, 3000);
  }

  // Simple function to set a new WSL password
  async function setNewWSLPassword(password) {
    console.log('Setting new WSL password');

    if (!password) {
      alert('Password setting was cancelled. WSL operations require a password.');
      return;
    }

    try {
      const hashedPassword = await digestPassword(password);

      chrome.storage.local.set({
        wslPassword: hashedPassword,
        failedAttempts: 0,
        lockoutTime: null,
        wslPasswordProtectionEnabled: true
      }, function () {
        console.log('Password saved successfully');
        alert('Password set successfully!');
        // Set session flag to avoid asking for password again
        // window.isPasswordVerifiedForSession = true;
      });
    } catch (error) {
      console.error('Error saving password:', error);
      alert('Error saving password. Please try again.');
    }
  }

  // Function to handle changing password with verification
  function handleChangePassword() {
    console.log('Handling password change');

    chrome.storage.local.get('wslPassword', function (result) {
      if (!result.wslPassword) {
        // No password set yet, just set a new one
        showSimplePasswordPrompt(
          'Please set a password for WSL operations (minimum 8 characters with at least one number):',
          setNewWSLPassword
        );
        return;
      }

      // Use the new change password dialog
      showChangePasswordDialog(function (result) {
        if (!result) {
          console.log('Password change cancelled');
          return;
        }

        if (result.success) {
          alert(result.message);
        } else {
          alert(result.message || 'Password change failed');
        }
      });
    });
  }



  // Function to verify a password against stored hash for secure buttons
  async function verifyWSLPassword(callback) {
    console.log('Verifying WSL password');

    chrome.storage.local.get(['wslPassword', 'wslPasswordProtectionEnabled'], function (result) {
      // If no password set or protection disabled, auto-pass
      if (!result.wslPassword || result.wslPasswordProtectionEnabled === false) {
        console.log('No password set or protection disabled');
        callback(true);
        return;
      }

      // Always prompt for password, regardless of session state
      showSimplePasswordPrompt('Please enter your WSL operations password:', async function (password) {
        if (!password) {
          console.log('Password verification cancelled');
          callback(false);
          return;
        }

        try {
          // Verify password
          const hashedPassword = await digestPassword(password);
          const isValid = hashedPassword === result.wslPassword;

          console.log('Password verification result:', isValid);

          if (isValid) {
            // Reset failed attempts
            chrome.storage.local.set({ failedAttempts: 0, lockoutTime: null });

            // Ensure modal is fully closed before running callback
            setTimeout(() => {
              callback(true);
            }, 200);
          } else {
            // Track failed attempts
            chrome.storage.local.get(['failedAttempts', 'lockoutTime'], function (attemptsResult) {
              const now = Date.now();

              // Check for existing lockout
              if (attemptsResult.lockoutTime && attemptsResult.lockoutTime > now) {
                const remainingTime = Math.ceil((attemptsResult.lockoutTime - now) / 60000);
                setTimeout(() => {
                  alert(`Too many failed attempts. Please try again in ${remainingTime} minutes.`);
                  callback(false);
                }, 200);
                return;
              }

              // Increment failed attempts
              const failedAttempts = (attemptsResult.failedAttempts || 0) + 1;

              if (failedAttempts >= 3) {
                // Lock for 10 minutes
                const lockoutTime = now + (10 * 60 * 1000);
                chrome.storage.local.set({ failedAttempts: 0, lockoutTime: lockoutTime });
                setTimeout(() => {
                  alert('Too many failed attempts. Your access has been locked for 10 minutes.');
                  callback(false);
                }, 200);
              } else {
                chrome.storage.local.set({ failedAttempts: failedAttempts });
                setTimeout(() => {
                  alert(`Incorrect password. You have ${3 - failedAttempts} attempts remaining.`);
                  callback(false);
                }, 200);
              }
            });
          }
        } catch (error) {
          console.error('Error verifying password:', error);
          setTimeout(() => {
            alert('Error verifying password. Please try again.');
            callback(false);
          }, 200);
        }
      });
    });
  }

  // Initialize password protection at startup
  setTimeout(initializeWSLPasswordProtection, 500);

  // Function to update all local browsers using PowerShell script
  async function updateAllLocalBrowsers() {
    try {
      // Show a confirmation dialog
      if (!confirm('This will update all installed browsers on your system. Continue?')) {
        return;
      }

      // Show loading message
      const statusMessage = document.createElement('div');
      statusMessage.id = 'update-status-message';
      statusMessage.className = 'alert alert-info';
      statusMessage.textContent = 'Updating browsers... This may take several minutes.';

      // Insert the message before the button
      const button = document.getElementById('update-browsers');
      button.parentNode.insertBefore(statusMessage, button.nextSibling);

      // Disable the button during update
      button.disabled = true;

      // Create command to run the PowerShell script with admin privileges
      const batchPath = 'RunUpdateBrowsers.bat';

      // Command to launch the batch file
      const command = `cmd /c start ${batchPath}`;

      // Send message to native messaging host to run the command
      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        // Enable the button
        button.disabled = false;

        // Remove loading message
        const statusMessage = document.getElementById('update-status-message');
        if (statusMessage) {
          statusMessage.remove();
        }

        if (response && !response.result.startsWith("Error")) {
          // Show success message
          const successMessage = document.createElement('div');
          successMessage.className = 'alert alert-success';
          successMessage.textContent = 'Browser update process started successfully. Check the PowerShell window for details.';
          button.parentNode.insertBefore(successMessage, button.nextSibling);

          // Remove success message after 5 seconds
          setTimeout(() => {
            if (successMessage.parentNode) {
              successMessage.remove();
            }
          }, 5000);

          // Update browser versions displayed in the UI after a delay
          setTimeout(() => {
            updateBrowserVersions();
          }, 10000); // Give browsers some time to update

        } else {
          // Show error message
          const errorMessage = document.createElement('div');
          errorMessage.className = 'alert alert-danger';
          errorMessage.textContent = response && response.result ?
            `Error launching updater: ${response.result}` :
            'Error launching updater. See logs for details.';
          button.parentNode.insertBefore(errorMessage, button.nextSibling);

          // Remove error message after 8 seconds
          setTimeout(() => {
            if (errorMessage.parentNode) {
              errorMessage.remove();
            }
          }, 8000);

          console.error('Error launching browser updater:', response ? response.result : 'Unknown error');
        }
      });
    } catch (error) {
      console.error('Error in updateAllLocalBrowsers:', error);
      alert('Error updating browsers: ' + error.message);
    }
  }

  async function updateAllWSLBrowsers() {
    try {
      // Show a confirmation dialog
      if (!confirm('This will update all installed browsers in your WSL instance. Continue?')) {
        return;
      }

      // Get the WSL instance name from settings
      const wslInstance = await new Promise((resolve) => {
        chrome.storage.local.get(['wslInstance'], function (result) {
          resolve(result.wslInstance || '');
        });
      });

      if (!wslInstance) {
        alert('No WSL instance configured. Please set a WSL instance in the Settings tab first.');
        return;
      }

      // Show loading message
      const statusMessage = document.createElement('div');
      statusMessage.id = 'update-wsl-status-message';
      statusMessage.className = 'alert alert-info';
      statusMessage.textContent = `Updating browsers in WSL instance "${wslInstance}"... This may take several minutes.`;

      // Insert the message before the button
      const button = document.getElementById('update-wsl-browsers');
      button.parentNode.insertBefore(statusMessage, button.nextSibling);

      // Disable the button during update
      button.disabled = true;

      // Create command to run the PowerShell script with admin privileges
      const batchPath = 'RunUpdateWSLBrowsers.bat';

      // Command to launch the batch file with WSL instance
      const command = `cmd /c start ${batchPath}`;

      // Send message to native messaging host to run the command
      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        // Enable the button
        button.disabled = false;

        // Remove loading message
        const statusMessage = document.getElementById('update-wsl-status-message');
        if (statusMessage) {
          statusMessage.remove();
        }

        if (response && !response.result.startsWith("Error")) {
          // Show success message
          const successMessage = document.createElement('div');
          successMessage.className = 'alert alert-success';
          successMessage.textContent = `WSL browser update process started successfully for instance "${wslInstance}". Check the PowerShell window for details.`;
          button.parentNode.insertBefore(successMessage, button.nextSibling);

          // Remove success message after 5 seconds
          setTimeout(() => {
            if (successMessage.parentNode) {
              successMessage.remove();
            }
          }, 5000);

        } else {
          // Show error message
          const errorMessage = document.createElement('div');
          errorMessage.className = 'alert alert-danger';
          errorMessage.textContent = response && response.result ?
            `Error launching WSL updater: ${response.result}` :
            'Error launching WSL updater. See logs for details.';
          button.parentNode.insertBefore(errorMessage, button.nextSibling);

          // Remove error message after 8 seconds
          setTimeout(() => {
            if (errorMessage.parentNode) {
              errorMessage.remove();
            }
          }, 8000);

          console.error('Error launching WSL browser updater:', response ? response.result : 'Unknown error');
        }
      });
    } catch (error) {
      console.error('Error in updateAllWSLBrowsers:', error);
      alert('Error updating WSL browsers: ' + error.message);
    }
  }

  // Add license-related code
  function updateLicenseStatus() {
    const licenseStatusEl = document.getElementById('license-status');
    const donationCard = document.getElementById('donation-options-card');
    const trialFooter = document.getElementById('trial-footer');
    const trialDaysRemaining = document.getElementById('trial-days-remaining');

    if (licenseStatusEl) {
      chrome.storage.local.get([
        'licenseStatus',
        'licenseKey',
        'licenseeName',
        'daysRemaining',
        'installDate'
      ], (data) => {
        if (data.licenseStatus === 'licensed' && data.licenseKey) {
          // Remove trial ended banner if it exists
          const trialBanner = document.getElementById('trial-ended-banner');
          if (trialBanner) {
            trialBanner.remove();
          }

          // Hide trial footer for licensed version
          if (trialFooter) {
            trialFooter.style.display = 'none';
          }

          licenseStatusEl.innerHTML = `<div class="alert alert-success text-center">Licensed Version</div>`;

          // Make sure UI is enabled
          const tabs = document.querySelectorAll('#settings-tabs .nav-link');
          tabs.forEach(tab => {
            tab.classList.remove('disabled');
            tab.removeAttribute('tabindex');
            tab.removeAttribute('aria-disabled');
            tab.style.opacity = '';
            tab.style.pointerEvents = '';
          });

          // Enable elements that might have been disabled
          document.querySelectorAll('.button-container button').forEach(button => {
            button.disabled = false;
            button.style.opacity = '';
            button.style.pointerEvents = '';
          });

          document.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
            checkbox.disabled = false;
          });

          document.querySelectorAll('.browser-version').forEach(version => {
            version.style.display = '';
          });

          // Enable deactivate button in modal
          const deactivateBtn = document.getElementById('deactivate-license-btn');
          if (deactivateBtn) {
            deactivateBtn.disabled = false;
          }

          // Hide donation options when licensed
          if (donationCard) {
            donationCard.style.display = 'none';
          }
        } else if (data.licenseStatus === 'trial') {
          // Show trial footer and update days remaining
          if (trialFooter && trialDaysRemaining) {
            trialFooter.style.display = 'block';
            trialDaysRemaining.textContent = data.daysRemaining || '60';
          }

          licenseStatusEl.innerHTML = `<div class="alert alert-info text-center">Trial Mode - ${data.daysRemaining || '60'} days remaining</div>`;

          // Show donation options in trial mode
          if (donationCard) {
            donationCard.style.display = 'block';
          }
        } else if (data.licenseStatus === 'expired') {
          // Show expired message in footer
          if (trialFooter) {
            trialFooter.style.display = 'block';
            trialFooter.innerHTML = '<span style="color: #dc3545; font-weight: bold;">TRIAL EXPIRED - PLEASE PURCHASE A LICENSE</span>';
          }

          licenseStatusEl.innerHTML = '<div class="alert alert-danger text-center">Trial Expired</div>';
          restrictUIForExpiredLicense(); // Call our UI restriction function

          // Show donation options when not licensed
          if (donationCard) {
            donationCard.style.display = 'block';
          }
        }
      });
    }
  }

  // Initialize and handle the license modal
  function initializeLicenseModal() {
    // Get modal elements
    const modal = document.getElementById('license-modal');
    const closeBtn = document.getElementById('license-modal-close');
    const cancelBtn = document.getElementById('license-modal-cancel');
    const activateBtn = document.getElementById('activate-license-btn');
    const deactivateBtn = document.getElementById('deactivate-license-btn');
    const licenseKeyInput = document.getElementById('modal-license-key');
    const hardwareIdEl = document.getElementById('modal-hardware-id');
    const modalLicenseStatus = document.getElementById('modal-license-status');
    const licenseMessage = document.getElementById('modal-license-message');
    const copyHardwareIdBtn = document.getElementById('copy-hardware-id');
    const manageBtn = document.getElementById('manage-license-btn');

    // Elements for enhanced license info
    const licenseeNameInput = document.getElementById('modal-licensee-name');
    const licenseeEmailInput = document.getElementById('modal-licensee-email');
    const licenseTypeSelect = document.getElementById('modal-license-type');

    // Initialize modal with inert attribute when hidden
    modal.setAttribute('inert', '');

    // Add copy hardware ID functionality
    if (copyHardwareIdBtn) {
      copyHardwareIdBtn.addEventListener('click', function () {
        const hardwareId = hardwareIdEl.textContent;

        if (hardwareId && hardwareId !== 'Loading...' &&
          hardwareId !== 'Generating hardware ID...' &&
          !hardwareId.includes('Error')) {

          // Copy to clipboard
          navigator.clipboard.writeText(hardwareId)
            .then(() => {
              // Show success feedback
              copyHardwareIdBtn.classList.add('copy-success');

              // Change button appearance temporarily
              const originalHTML = copyHardwareIdBtn.innerHTML;
              copyHardwareIdBtn.innerHTML = '<i class="fas fa-check"></i>';
              copyHardwareIdBtn.setAttribute('title', 'Copied!');

              // Reset button after animation
              setTimeout(() => {
                copyHardwareIdBtn.classList.remove('copy-success');
                copyHardwareIdBtn.innerHTML = originalHTML;
                copyHardwareIdBtn.setAttribute('title', 'Copy to clipboard');
              }, 1500);
            })
            .catch(err => {
              console.error('Could not copy hardware ID: ', err);
              alert('Failed to copy hardware ID. Please try selecting and copying manually.');
            });
        } else {
          alert('Hardware ID is not available yet. Please wait...');
        }
      });
    }

    // Check if jQuery is available
    function isJQueryAvailable() {
      return typeof jQuery !== 'undefined';
    }

    // Create backdrop for vanilla JS fallback - disabled for license modal
    function createBackdrop() {
      // Don't create backdrop for license modal to avoid overlay issues
      console.log('Backdrop creation skipped for license modal');
      return null;
    }

    // Remove backdrop
    function removeBackdrop() {
      const backdrop = document.querySelector('.modal-backdrop, .license-modal-backdrop');
      if (backdrop) {
        backdrop.remove();
      }
    }

    // Show modal
    function showModal() {
      // Force the modal to be visible and on top
      modal.style.zIndex = '2147483647';
      modal.style.display = 'block';
      modal.style.backgroundColor = 'transparent';
      modal.style.pointerEvents = 'none';

      // Make dialog clickable
      const dialog = modal.querySelector('.modal-dialog');
      if (dialog) {
        dialog.style.pointerEvents = 'auto';
      }

      if (isJQueryAvailable()) {
        // Remove inert attribute before showing modal
        modal.removeAttribute('inert');
        // Show modal without backdrop
        $(modal).modal({
          show: true,
          backdrop: false, // Disable backdrop
          keyboard: true
        });

        // Remove any backdrop that jQuery might create
        setTimeout(() => {
          const jqueryBackdrop = document.querySelector('.modal-backdrop');
          if (jqueryBackdrop) {
            jqueryBackdrop.remove();
          }
        }, 100);
      } else {
        // Vanilla JS fallback without backdrop
        modal.removeAttribute('inert');
        modal.classList.add('show');
        // Don't add modal-open class to prevent backdrop styling
        // createBackdrop(); // Disabled - no backdrop needed
      }

      // Update license information when modal is shown
      updateModalLicenseUI();
    }

    // Hide modal
    function hideModal() {
      if (isJQueryAvailable()) {
        $(modal).modal('hide');
        // Clean up any backdrops and add inert attribute after hiding the modal
        setTimeout(() => {
          removeBackdrop();
          modal.setAttribute('inert', '');
          modal.style.zIndex = ''; // Reset z-index
          modal.style.backgroundColor = ''; // Reset background
          modal.style.pointerEvents = ''; // Reset pointer events
        }, 300); // Allow time for the modal hide animation
      } else {
        // Vanilla JS fallback
        modal.classList.remove('show');
        modal.style.display = 'none';
        modal.style.zIndex = ''; // Reset z-index
        modal.style.backgroundColor = ''; // Reset background
        modal.style.pointerEvents = ''; // Reset pointer events
        document.body.classList.remove('modal-open');
        removeBackdrop();
        modal.setAttribute('inert', '');
      }
    }

    // Event listeners for opening/closing modal
    if (manageBtn) {
      manageBtn.addEventListener('click', showModal);
    }

    if (closeBtn) {
      closeBtn.addEventListener('click', hideModal);
    }

    if (cancelBtn) {
      cancelBtn.addEventListener('click', hideModal);
    }

    // Show message in modal
    function showModalMessage(message, isSuccess) {
      licenseMessage.textContent = message;
      licenseMessage.className = isSuccess ? 'alert alert-success' : 'alert alert-danger';
      licenseMessage.style.display = 'block';

      // Hide message after 5 seconds
      setTimeout(() => {
        licenseMessage.style.display = 'none';
      }, 5000);
    }

    // Update license UI in modal
    async function updateModalLicenseUI() {
      try {
        const data = await chrome.storage.local.get([
          'hardwareId',
          'hardwareIdError',
          'usingFallbackId',
          'licenseStatus',
          'licenseKey',
          'licenseeName',
          'licenseeEmail',
          'purchaseDate',
          'licenseType',
          'daysRemaining'
        ]);

        // Display hardware ID
        const hardwareIdEl = document.getElementById('modal-hardware-id');
        if (hardwareIdEl) {
          if (data.hardwareId) {
            hardwareIdEl.textContent = data.hardwareId;

            // Add warning if using fallback ID
            if (data.usingFallbackId) {
              // Create warning message in a separate element instead of modifying hardwareIdEl's parent
              const warningContainer = document.createElement('div');
              warningContainer.classList.add('text-warning', 'small', 'mt-1');
              warningContainer.innerHTML = '<i class="fas fa-exclamation-triangle"></i> Using fallback ID due to: ' +
                (data.hardwareIdError || 'Native messaging issue');

              // Insert after the hardware ID container
              const hardwareContainer = hardwareIdEl.closest('.hardware-id-container').parentNode;
              hardwareContainer.appendChild(warningContainer);
            }
          } else {
            // If hardware ID is missing, try to generate it
            hardwareIdEl.textContent = 'Generating hardware ID...';

            try {
              // Request hardware ID generation from background script
              const response = await chrome.runtime.sendMessage({ action: 'regenerateHardwareId' });

              if (response && response.hardwareId) {
                hardwareIdEl.textContent = response.hardwareId;
              } else {
                hardwareIdEl.textContent = 'Failed to generate hardware ID';
                console.error('Failed to generate hardware ID:', response?.error || 'unknown error');
              }
            } catch (error) {
              console.error('Error generating hardware ID:', error);
              hardwareIdEl.textContent = 'Error generating hardware ID';
            }
          }
        }

        // Set license key if available
        const licenseKeyInput = document.getElementById('modal-license-key');
        if (licenseKeyInput && data.licenseKey) {
          licenseKeyInput.value = data.licenseKey;
        }

        // Set enhanced license info fields if available
        const licenseeNameInput = document.getElementById('modal-licensee-name');
        const licenseeEmailInput = document.getElementById('modal-licensee-email');
        const licenseTypeSelect = document.getElementById('modal-license-type');

        if (licenseeNameInput && data.licenseeName) {
          licenseeNameInput.value = data.licenseeName;
          licenseeNameInput.readOnly = data.licenseStatus === 'licensed';
        }

        if (licenseeEmailInput && data.licenseeEmail) {
          licenseeEmailInput.value = data.licenseeEmail;
          licenseeEmailInput.readOnly = data.licenseStatus === 'licensed';
        }

        if (licenseTypeSelect && data.licenseType) {
          licenseTypeSelect.value = data.licenseType;
          licenseTypeSelect.disabled = data.licenseStatus === 'licensed';
        }

        // Update status display
        const modalLicenseStatus = document.getElementById('modal-license-status');
        if (modalLicenseStatus) {
          let statusHtml = '';

          switch (data.licenseStatus) {
            case 'trial':
              modalLicenseStatus.className = 'license-status status-trial';
              statusHtml = `
                <div class="alert alert-info">
                  <h5>Trial Mode</h5>
                  <p>You are currently using Browser Launcher Pro in trial mode.</p>
                  <p><strong>${data.daysRemaining || '?'} days remaining</strong> in your trial period.</p>
                  <p>Purchase a license to continue using all features after your trial expires.</p>
                </div>
              `;
              break;
            case 'licensed':
              modalLicenseStatus.className = 'license-status status-licensed';
              statusHtml = `
                <div class="alert alert-success">
                  <h5>Licensed Version</h5>
                  <p>Thank you for purchasing Browser Launcher Pro!</p>
                  <p>Licensed to: <strong>${data.licenseeName || 'Unknown User'}</strong></p>
                  <p>License type: <strong>${data.licenseType === 'subscription' ? 'Subscription' : 'Lifetime'}</strong></p>
                </div>
              `;
              break;
            case 'expired':
              modalLicenseStatus.className = 'license-status status-expired';
              statusHtml = `
                <div class="alert alert-danger">
                  <h5>Trial Expired</h5>
                  <p>Your trial period has expired.</p>
                  <p>Please purchase a license to continue using all features.</p>
                </div>
              `;
              break;
            default:
              modalLicenseStatus.className = 'license-status status-unknown';
              statusHtml = `
                <div class="alert alert-warning">
                  <h5>License Status Unknown</h5>
                  <p>Unable to determine license status. Please try refreshing the page.</p>
                </div>
              `;
          }

          modalLicenseStatus.innerHTML = statusHtml;
        }
      } catch (error) {
        console.error('Error updating modal license UI:', error);

        // Show error in the modal
        const modalLicenseStatus = document.getElementById('modal-license-status');
        if (modalLicenseStatus) {
          modalLicenseStatus.innerHTML = `
            <div class="alert alert-danger">
              <h5>Error Loading License Information</h5>
              <p>An error occurred while loading license information: ${error.message}</p>
            </div>
          `;
        }
      }
    }

    // Handle license activation
    if (activateBtn) {
      activateBtn.addEventListener('click', async () => {
        const licenseKey = licenseKeyInput.value.trim();

        if (!licenseKey) {
          showModalMessage('Please enter a valid license key', false);
          return;
        }

        activateBtn.disabled = true;

        // The license key now contains all the necessary metadata
        try {
          // Use chrome.runtime to communicate with background script
          chrome.runtime.sendMessage({
            action: 'validateLicense',
            licenseKey: licenseKey
          }, (response) => {
            if (chrome.runtime.lastError) {
              console.error('Error validating license:', chrome.runtime.lastError);
              showModalMessage('Error validating license. Please try again.', false);
              activateBtn.disabled = false;
              return;
            }

            if (response && response.valid) {
              showModalMessage(response.message || 'License activated successfully', true);

              // If metadata was extracted, auto-populate the fields
              if (response.metadata) {
                if (licenseeNameInput) licenseeNameInput.value = response.metadata.name || '';
                if (licenseeEmailInput) licenseeEmailInput.value = response.metadata.email || '';
                if (licenseTypeSelect) licenseTypeSelect.value = response.metadata.licenseType || 'lifetime';
              }

              // Directly update button visibility
              activateBtn.style.display = 'none';
              const deactivateBtn = document.getElementById('deactivate-license-btn');
              if (deactivateBtn) {
                deactivateBtn.style.display = 'inline-block';
                deactivateBtn.disabled = false;
              }

              // Update the UI to show the license information
              updateModalLicenseUI();

              // Update the main popup
              updateLicenseStatus();

              // Remove trial ended banner if it exists
              const trialBanner = document.getElementById('trial-ended-banner');
              if (trialBanner) {
                trialBanner.remove();
              }

              // Re-enable all tabs
              const tabs = document.querySelectorAll('#settings-tabs .nav-link');
              tabs.forEach(tab => {
                tab.classList.remove('disabled');
                tab.removeAttribute('tabindex');
                tab.removeAttribute('aria-disabled');
                tab.style.opacity = '';
                tab.style.pointerEvents = '';
              });

              // Show browser version displays
              const browserVersions = document.querySelectorAll('.browser-version');
              browserVersions.forEach(version => {
                version.style.display = '';
              });

              // Enable all browser buttons
              const buttons = document.querySelectorAll('.button-container button');
              buttons.forEach(button => {
                button.disabled = false;
                button.style.opacity = '';
                button.style.pointerEvents = '';
              });

              // Enable checkbox controls
              const checkboxes = document.querySelectorAll('input[type="checkbox"]');
              checkboxes.forEach(checkbox => {
                checkbox.disabled = false;
              });
            } else {
              showModalMessage(response?.message || 'Invalid license key', false);
            }

            activateBtn.disabled = false;
          });
        } catch (error) {
          console.error('License activation error:', error);
          showModalMessage('Error activating license', false);
          activateBtn.disabled = false;
        }
      });
    }

    // Handle license deactivation
    if (deactivateBtn) {
      deactivateBtn.addEventListener('click', () => {
        if (confirm('Are you sure you want to deactivate your license on this device?')) {
          chrome.runtime.sendMessage({ action: 'deactivateLicense' }, (response) => {
            if (response && response.success) {
              showModalMessage('License deactivated successfully', true);

              // Clear license fields
              if (licenseKeyInput) licenseKeyInput.value = '';
              if (licenseeNameInput) licenseeNameInput.value = '';
              if (licenseeEmailInput) licenseeEmailInput.value = '';
              if (licenseTypeSelect) licenseTypeSelect.value = 'lifetime';

              // Disable deactivate button
              deactivateBtn.disabled = true;

              // Update UI
              updateModalLicenseUI();
              updateLicenseStatus();
            } else {
              showModalMessage('Error deactivating license', false);
            }
          });
        }
      });
    }
  }

  // ... existing code ...

  document.getElementById('view-eula').addEventListener('click', function () {
    chrome.tabs.create({ url: 'eula.html' });
  });

  // ... existing code ...

  // Helper function to check if license allows certain actions
  function isLicenseActiveForFeature(callback) {
    chrome.storage.local.get(['licenseStatus', 'installDate'], function (result) {
      const licenseStatus = result.licenseStatus;

      // If fully licensed, always allow
      if (licenseStatus === 'licensed') {
        callback(true);
        return;
      }

      // If expired, never allow
      if (licenseStatus === 'expired') {
        showLicenseExpiredMessage();
        callback(false);
        return;
      }

      // If in trial, check days remaining
      const installDate = result.installDate;
      if (installDate) {
        const installTime = new Date(installDate).getTime();
        const currentTime = new Date().getTime();
        const daysSinceInstall = Math.floor((currentTime - installTime) / (1000 * 60 * 60 * 24));

        if (daysSinceInstall > 60) {
          // Trial has expired but status wasn't updated
          chrome.storage.local.set({ licenseStatus: 'expired' });
          showLicenseExpiredMessage();
          restrictUIForExpiredLicense(); // Add the call to restrict UI
          callback(false);
        } else {
          callback(true);
        }
      } else {
        // No install date, allow feature but set install date
        const now = new Date().toISOString();
        chrome.storage.local.set({
          installDate: now,
          licenseStatus: 'trial'
        });
        callback(true);
      }
    });
  }

  // Function to restrict UI when license is expired
  function restrictUIForExpiredLicense() {
    console.log("Restricting UI for expired license");

    // Add a prominent trial ended banner at the top
    const container = document.querySelector('.container');
    if (container) {
      // Check if banner already exists
      if (!document.getElementById('trial-ended-banner')) {
        const banner = document.createElement('div');
        banner.id = 'trial-ended-banner';
        banner.className = 'alert alert-danger text-center mb-3';
        banner.style.fontWeight = 'bold';
        banner.style.fontSize = '16px';
        banner.style.padding = '15px';
        banner.innerHTML = 'TRIAL ENDED - PLEASE PURCHASE A LICENSE KEY';

        // Insert banner at the top, right after the header
        const header = container.querySelector('header');
        if (header && header.nextSibling) {
          container.insertBefore(banner, header.nextSibling);
        } else {
          container.prepend(banner);
        }
      }
    }

    // Disable all tabs except for License Management and Help/Support
    const tabs = document.querySelectorAll('#settings-tabs .nav-link');
    tabs.forEach(tab => {
      if (tab.id !== 'help-support-tab') {
        tab.classList.add('disabled');
        tab.setAttribute('tabindex', '-1');
        tab.setAttribute('aria-disabled', 'true');
        tab.style.opacity = '0.5';
        tab.style.pointerEvents = 'none';

        // Hide the tab content
        const tabContentId = tab.getAttribute('href').substring(1);
        const tabContent = document.getElementById(tabContentId);
        if (tabContent) {
          tabContent.classList.remove('show', 'active');
        }
      }
    });

    // Hide all browser version displays and disable buttons
    const browserVersions = document.querySelectorAll('.browser-version');
    browserVersions.forEach(version => {
      version.style.display = 'none';
    });

    // Disable all browser buttons
    const buttons = document.querySelectorAll('.button-container button');
    buttons.forEach(button => {
      button.disabled = true;
      button.style.opacity = '0.5';
      button.style.pointerEvents = 'none';
    });

    // Disable checkbox controls
    const checkboxes = document.querySelectorAll('input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
      checkbox.disabled = true;
    });

    // Make the Help/Support tab active
    const helpSupportTab = document.getElementById('help-support-tab');
    const helpSupportContent = document.getElementById('help-support');

    if (helpSupportTab && helpSupportContent) {
      // Remove active class from all tabs and content
      document.querySelectorAll('#settings-tabs .nav-link').forEach(tab => {
        tab.classList.remove('active');
      });
      document.querySelectorAll('.tab-pane').forEach(pane => {
        pane.classList.remove('show', 'active');
      });

      // Make Help/Support tab active
      helpSupportTab.classList.add('active');
      helpSupportContent.classList.add('show', 'active');
    }
  }

  function showLicenseExpiredMessage() {
    // Don't show the alert as we're already showing a banner
    // Instead, let's open the license management modal
    const manageBtn = document.getElementById('manage-license-btn');
    if (manageBtn) {
      manageBtn.click();
    } else {
      // Fallback if button not found
      alert('Your trial period has expired. Please purchase a license to continue using all features.');
      chrome.tabs.create({ url: chrome.runtime.getURL('license.html') });
    }
  }

  // ... existing code ...

  // Wrap functions that need license check
  const originalUpdateAllLocalBrowsers = updateAllLocalBrowsers;
  updateAllLocalBrowsers = function () {
    isLicenseActiveForFeature(function (isActive) {
      if (isActive) {
        originalUpdateAllLocalBrowsers();
      }
    });
  };

  const originalUpdateAllWSLBrowsers = updateAllWSLBrowsers;
  updateAllWSLBrowsers = function () {
    isLicenseActiveForFeature(function (isActive) {
      if (isActive) {
        originalUpdateAllWSLBrowsers();
      }
    });
  };

  // ... rest of the existing code ...

  // Initialize license functionality
  updateLicenseStatus();
  initializeLicenseModal();

  // Initialize password modal
  function initializePasswordModal() {
    const passwordModal = document.getElementById('password-modal');
    if (passwordModal) {
      // Initialize modal with inert attribute when hidden
      passwordModal.setAttribute('inert', '');
    }
  }

  initializePasswordModal();

  // Direct event handler for the manage license button
  const manageBtn = document.getElementById('manage-license-btn');
  if (manageBtn) {
    manageBtn.onclick = function () {
      const modal = document.getElementById('license-modal');
      // Remove inert attribute before showing the modal
      modal.removeAttribute('inert');

      if (typeof jQuery !== 'undefined' && jQuery.fn.modal) {
        $(modal).modal('show');
      } else {
        // Pure JavaScript fallback
        modal.style.display = 'block';
        modal.classList.add('show');
        document.body.classList.add('modal-open');

        // Create backdrop
        const backdrop = document.createElement('div');
        backdrop.className = 'modal-backdrop fade show';
        document.body.appendChild(backdrop);
      }

      // Update license information
      updateModalLicenseUI();
    };
  }

  // Helper function to update modal license UI
  function updateModalLicenseUI() {
    chrome.storage.local.get([
      'hardwareId',
      'licenseStatus',
      'licenseKey',
      'licenseeName',
      'licenseeEmail',
      'purchaseDate',
      'licenseType',
      'daysRemaining'
    ], function (data) {
      // Update hardware ID
      const hardwareIdEl = document.getElementById('modal-hardware-id');
      if (hardwareIdEl) {
        hardwareIdEl.textContent = data.hardwareId || 'Loading...';
      }

      // Get button references
      const activateBtn = document.getElementById('activate-license-btn');
      const deactivateBtn = document.getElementById('deactivate-license-btn');

      // Update license status display
      const modalLicenseStatus = document.getElementById('modal-license-status');
      if (modalLicenseStatus) {
        let statusHtml = '';

        switch (data.licenseStatus) {
          case 'trial':
            modalLicenseStatus.className = 'license-status status-trial';
            statusHtml = `
              <div class="alert alert-info">
                <h5>Trial Mode</h5>
                <p>You are currently using Browser Launcher Pro in trial mode.</p>
                <p><strong>${data.daysRemaining || '?'} days remaining</strong> in your trial period.</p>
                <p>Purchase a license to continue using all features after your trial expires.</p>
              </div>
            `;
            break;

          case 'licensed':
            modalLicenseStatus.className = 'license-status status-licensed';

            // Format license info with yellow highlighting for licensee name
            statusHtml = `
              <div class="alert alert-success">
                <h5>Licensed</h5>
                <p>Browser Launcher Pro is fully licensed for this device.</p>
                <p>Licensed to: <span style=" padding: 0 5px; font-weight: bold;">${data.licenseeName || 'Unknown User'}</span></p>
                <p>Thank you for your purchase!</p>
              </div>
            `;
            break;

          case 'expired':
            modalLicenseStatus.className = 'license-status status-expired';
            statusHtml = `
              <div class="alert alert-danger">
                <h5>Trial Expired</h5>
                <p>Your trial period has expired.</p>
                <p><strong>All features have been disabled.</strong></p>
                <p>Please enter a valid license key below to continue using Browser Launcher Pro.</p>
                <div class="text-center mt-3">
                  <a href="https://browserlauncherpro.com/purchase" target="_blank" class="btn btn-warning">
                    <i class="fas fa-shopping-cart"></i> Purchase License
                  </a>
                </div>
              </div>
            `;
            break;

          default:
            modalLicenseStatus.className = 'license-status status-unknown';
            statusHtml = `
              <div class="alert alert-warning">
                <h5>License Status Unknown</h5>
                <p>Unable to determine license status. Please try refreshing the page.</p>
              </div>
            `;
        }

        modalLicenseStatus.innerHTML = statusHtml;
      }

      // Set current license key if available
      const licenseKeyInput = document.getElementById('modal-license-key');
      if (licenseKeyInput && data.licenseKey) {
        licenseKeyInput.value = data.licenseKey;
      }

      // Manage button visibility and state
      if (activateBtn && deactivateBtn) {
        if (data.licenseStatus === 'licensed') {
          // When licensed: show deactivate, hide activate
          activateBtn.style.display = 'none';
          deactivateBtn.style.display = 'inline-block';
          deactivateBtn.disabled = false;
        } else {
          // When not licensed: hide deactivate, show activate
          activateBtn.style.display = 'inline-block';
          deactivateBtn.style.display = 'none';

          // Extra styling for expired mode
          if (data.licenseStatus === 'expired') {
            activateBtn.classList.add('btn-warning');
          } else {
            activateBtn.classList.remove('btn-warning');
          }

          activateBtn.innerHTML = '<i class="fas fa-key"></i> Activate License';
        }
      }

      // Show/hide donation options based on license status
      const donationCard = document.getElementById('donation-options-card');
      if (donationCard) {
        donationCard.style.display = data.licenseStatus === 'licensed' ? 'none' : 'block';
      }
    });
  }

  // Event handlers for modal buttons
  const activateBtn = document.getElementById('activate-license-btn');
  if (activateBtn) {
    activateBtn.addEventListener('click', function () {
      const licenseKeyInput = document.getElementById('modal-license-key');
      const licenseKey = licenseKeyInput.value.trim();

      if (!licenseKey) {
        showModalMessage('Please enter a valid license key', false);
        return;
      }

      activateBtn.disabled = true;

      // Call the license validation function
      window.BrowserLauncherLicense.validate(licenseKey)
        .then(result => {
          if (result.valid) {
            showModalMessage('License activated successfully!', true);

            // Directly update button visibility
            activateBtn.style.display = 'none';
            const deactivateBtn = document.getElementById('deactivate-license-btn');
            if (deactivateBtn) {
              deactivateBtn.style.display = 'inline-block';
              deactivateBtn.disabled = false;
            }

            // Update the UI to show the license information
            updateModalLicenseUI();

            // Update the main popup
            updateLicenseStatus();

            // Remove trial ended banner if it exists
            const trialBanner = document.getElementById('trial-ended-banner');
            if (trialBanner) {
              trialBanner.remove();
            }

            // Re-enable all tabs
            const tabs = document.querySelectorAll('#settings-tabs .nav-link');
            tabs.forEach(tab => {
              tab.classList.remove('disabled');
              tab.removeAttribute('tabindex');
              tab.removeAttribute('aria-disabled');
              tab.style.opacity = '';
              tab.style.pointerEvents = '';
            });

            // Show browser version displays
            const browserVersions = document.querySelectorAll('.browser-version');
            browserVersions.forEach(version => {
              version.style.display = '';
            });

            // Enable all browser buttons
            const buttons = document.querySelectorAll('.button-container button');
            buttons.forEach(button => {
              button.disabled = false;
              button.style.opacity = '';
              button.style.pointerEvents = '';
            });

            // Enable checkbox controls
            const checkboxes = document.querySelectorAll('input[type="checkbox"]');
            checkboxes.forEach(checkbox => {
              checkbox.disabled = false;
            });
          } else {
            // Show error message
            showModalMessage(result.message || 'Invalid license key', false);
          }

          activateBtn.disabled = false;
        })
        .catch(error => {
          console.error('Error validating license:', error);
          showModalMessage('Error validating license: ' + error.message, false);
          activateBtn.disabled = false;
        });
    });
  }

  // Event handler for deactivate license button
  const deactivateBtn = document.getElementById('deactivate-license-btn');
  if (deactivateBtn) {
    deactivateBtn.addEventListener('click', function () {
      if (confirm('Are you sure you want to deactivate your license on this device?')) {
        deactivateBtn.disabled = true;

        // Call the deactivate function
        window.BrowserLauncherLicense.deactivate()
          .then(result => {
            if (result.success) {
              showModalMessage('License deactivated successfully', true);

              // Clear license key field
              const licenseKeyInput = document.getElementById('modal-license-key');
              if (licenseKeyInput) {
                licenseKeyInput.value = '';
              }

              // Update the UI
              updateModalLicenseUI();
              updateLicenseStatus();
            } else {
              showModalMessage(result.message || 'Error deactivating license', false);
              deactivateBtn.disabled = false;
            }
          })
          .catch(error => {
            console.error('Error deactivating license:', error);
            showModalMessage('Error deactivating license: ' + error.message, false);
            deactivateBtn.disabled = false;
          });
      }
    });
  }

  // Close buttons for the modal
  const closeBtn = document.getElementById('license-modal-close');
  const cancelBtn = document.getElementById('license-modal-cancel');

  function closeModal() {
    const modal = document.getElementById('license-modal');
    if (typeof jQuery !== 'undefined' && jQuery.fn.modal) {
      $(modal).modal('hide');
      // Add inert attribute after modal is hidden
      setTimeout(() => {
        modal.setAttribute('inert', '');
      }, 300); // Allow time for the modal hide animation
    } else {
      // Pure JavaScript fallback
      modal.style.display = 'none';
      modal.classList.remove('show');
      document.body.classList.remove('modal-open');

      // Remove backdrop
      const backdrop = document.querySelector('.modal-backdrop');
      if (backdrop) {
        backdrop.remove();
      }

      // Add inert attribute
      modal.setAttribute('inert', '');
    }
  }

  if (closeBtn) {
    closeBtn.addEventListener('click', closeModal);
  }

  if (cancelBtn) {
    cancelBtn.addEventListener('click', closeModal);
  }

  // Helper function to show messages in the modal
  function showModalMessage(message, isSuccess) {
    const licenseMessage = document.getElementById('modal-license-message');
    if (licenseMessage) {
      licenseMessage.textContent = message;
      licenseMessage.className = isSuccess ? 'alert alert-success' : 'alert alert-danger';
      licenseMessage.style.display = 'block';

      // Hide message after 5 seconds
      setTimeout(() => {
        licenseMessage.style.display = 'none';
      }, 5000);
    }
  }

  // ... rest of existing code ...

  loadSettings();

  // ... rest of existing code ...

  // Initialize browser launch buttons for Windows Local tab
  const localBrowsers = [
    { id: 'edge-stable-local', setting: 'edgeStablePath' },
    { id: 'edge-beta-local', setting: 'edgeBetaPath' },
    { id: 'edge-dev-local', setting: 'edgeDevPath' },
    { id: 'chrome-stable-local', setting: 'chromeStablePath' },
    { id: 'chrome-beta-local', setting: 'chromeBetaPath' },
    { id: 'chrome-dev-local', setting: 'chromeDevPath' }
  ];

  // Initialize browser launch buttons for WSL tab
  const wslBrowsers = [
    { id: 'edge-stable', setting: 'wslEdgeStablePath' },
    { id: 'edge-beta', setting: 'wslEdgeBetaPath' },
    { id: 'edge-dev', setting: 'wslEdgeDevPath' },
    { id: 'chrome-stable', setting: 'wslChromeStablePath' },
    { id: 'chrome-beta', setting: 'wslChromeBetaPath' },
    { id: 'chrome-dev', setting: 'wslChromeDevPath' },
    { id: 'firefox', setting: 'wslFirefoxPath' },
    { id: 'opera', setting: 'wslOperaPath' },
    { id: 'brave', setting: 'wslBravePath' }
  ];

  // Function to check if a command is for WSL
  const checkIfWSLCommand = (command) => {
    return command.startsWith('/usr/bin/') || command.startsWith('/snap/bin/') || command.includes('google-chrome') || command.includes('microsoft-edge');
  };

  // Function to prepare WSL command
  const prepareWSLCommandForBrowser = async (command) => {
    const { wslInstance, wslUsername } = await new Promise((resolve) => {
      chrome.storage.local.get(['wslInstance', 'wslUsername'], function (result) {
        resolve({
          wslInstance: result['wslInstance'] || 'ubuntu',
          wslUsername: result['wslUsername'] || ''
        });
      });
    });

    const userParam = wslUsername ? `-u ${wslUsername}` : '';
    const sandboxParam = command.includes('chrome') ? '--no-sandbox' : '';
    return `wsl -d ${wslInstance} ${userParam} ${command} ${sandboxParam}`.trim();
  };

  // Function to launch browser
  const launchBrowser = async (browserSetting) => {
    try {
      chrome.storage.local.get([browserSetting], async function (result) {
        const command = result[browserSetting];

        if (!command || command === 'NA') {
          alert(`Error: Browser path not set or marked as N/A. Please check your settings.`);
          return;
        }

        let finalCommand = command;
        if (checkIfWSLCommand(command)) {
          finalCommand = await prepareWSLCommandForBrowser(command);
        }

        console.log(`Launching browser with command: ${finalCommand}`);

        chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
          command: finalCommand,
          url: ''
        }, (response) => {
          if (chrome.runtime.lastError) {
            console.error(`Error launching browser: ${chrome.runtime.lastError.message}`);
            alert(`Error launching browser: ${chrome.runtime.lastError.message}`);
          } else if (response && response.result && response.result.startsWith("Error:")) {
            console.error(`Error from native messaging: ${response.result}`);
            alert(`Error launching browser: ${response.result}`);
          } else {
            console.log('Browser launched successfully:', response);
          }
        });
      });
    } catch (error) {
      console.error(`Error launching browser: ${error.message}`);
      alert(`Error launching browser: ${error.message}`);
    }
  };

  // Add click event listeners to local browser buttons
  localBrowsers.forEach(browser => {
    const button = document.getElementById(browser.id);
    if (button) {
      button.addEventListener('click', () => {
        console.log(`Clicked ${browser.id} button`);
        launchBrowser(browser.setting);
      });
    }
  });

  // Add click event listeners to WSL browser buttons
  wslBrowsers.forEach(browser => {
    const button = document.getElementById(browser.id);
    if (button) {
      button.addEventListener('click', () => {
        console.log(`Clicked ${browser.id} button`);
        launchBrowser(browser.setting);
      });
    }
  });

  // ===== Custom Browsers in Main Tabs =====
  // Function to populate custom browser buttons in Windows and WSL tabs
  function populateCustomBrowserButtons() {
    chrome.storage.local.get(['customBrowsers'], function (result) {
      const customBrowsers = result.customBrowsers || [];

      // Separate browsers by platform
      const windowsBrowsers = customBrowsers.filter(b => b.platform === 'windows' && b.enabled);
      const wslBrowsers = customBrowsers.filter(b => b.platform === 'wsl' && b.enabled);

      // Populate Windows custom browsers
      const windowsContainer = document.getElementById('custom-browsers-windows-container');
      const windowsGroup = document.getElementById('custom-browsers-windows-group');

      if (windowsContainer) {
        windowsContainer.innerHTML = ''; // Clear existing

        if (windowsBrowsers.length > 0) {
          windowsGroup.style.display = 'block';

          windowsBrowsers.forEach(browser => {
            const buttonWrapper = document.createElement('div');
            buttonWrapper.className = 'button-with-version';

            const button = document.createElement('button');
            button.className = 'btn';
            button.id = `custom-${browser.id}`;
            button.style.background = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
            button.style.color = 'white';

            button.innerHTML = `
              <span style="font-size: 1.2em; margin-right: 5px;">${browser.icon}</span>
              <span class="browser-label">${browser.name}</span>
            `;

            // Add click event listener
            button.addEventListener('click', async () => {
              console.log(`Launching custom browser: ${browser.name}`);

              let command = browser.path;

              // For Windows browsers, wrap path in quotes
              command = `"${command}"`;

              console.log(`Executing command: ${command}`);

              chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
                command: command,
                url: ''
              }, (response) => {
                if (chrome.runtime.lastError) {
                  console.error(`Error launching browser: ${chrome.runtime.lastError.message}`);
                  alert(`Error launching ${browser.name}: ${chrome.runtime.lastError.message}`);
                } else if (response && response.result && response.result.startsWith("Error:")) {
                  console.error(`Error from native messaging: ${response.result}`);
                  alert(`Error launching ${browser.name}: ${response.result}`);
                } else {
                  console.log(`${browser.name} launched successfully:`, response);
                }
              });
            });

            buttonWrapper.appendChild(button);
            windowsContainer.appendChild(buttonWrapper);
          });
        } else {
          windowsGroup.style.display = 'none';
        }
      }

      // Populate WSL custom browsers
      const wslContainer = document.getElementById('custom-browsers-wsl-container');
      const wslGroup = document.getElementById('custom-browsers-wsl-group');

      if (wslContainer) {
        wslContainer.innerHTML = ''; // Clear existing

        if (wslBrowsers.length > 0) {
          wslGroup.style.display = 'block';

          wslBrowsers.forEach(browser => {
            const buttonWrapper = document.createElement('div');
            buttonWrapper.className = 'button-with-version';

            // Add WSL penguin indicator
            const penguinIndicator = document.createElement('span');
            penguinIndicator.className = 'wsl-penguin-indicator';
            buttonWrapper.appendChild(penguinIndicator);

            const button = document.createElement('button');
            button.className = 'btn';
            button.id = `custom-${browser.id}`;
            button.style.background = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
            button.style.color = 'white';

            button.innerHTML = `
              <span style="font-size: 1.2em; margin-right: 5px;">${browser.icon}</span>
              <span class="browser-label">${browser.name}</span>
            `;

            // Add click event listener
            button.addEventListener('click', async () => {
              console.log(`Launching custom WSL browser: ${browser.name}`);

              let command = browser.path;

              // Prepare WSL command
              command = await prepareWSLCommandForBrowser(command);

              console.log(`Executing command: ${command}`);

              chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
                command: command,
                url: ''
              }, (response) => {
                if (chrome.runtime.lastError) {
                  console.error(`Error launching browser: ${chrome.runtime.lastError.message}`);
                  alert(`Error launching ${browser.name}: ${chrome.runtime.lastError.message}`);
                } else if (response && response.result && response.result.startsWith("Error:")) {
                  console.error(`Error from native messaging: ${response.result}`);
                  alert(`Error launching ${browser.name}: ${response.result}`);
                } else {
                  console.log(`${browser.name} launched successfully:`, response);
                }
              });
            });

            buttonWrapper.appendChild(button);
            wslContainer.appendChild(buttonWrapper);
          });
        } else {
          wslGroup.style.display = 'none';
        }
      }
    });
  }

  // Call on page load
  populateCustomBrowserButtons();

  // Also call when switching to Windows or WSL tabs
  document.getElementById('windows-tab').addEventListener('click', populateCustomBrowserButtons);
  document.getElementById('wsl-tab').addEventListener('click', populateCustomBrowserButtons);

  // ... rest of existing code ...


  // Add event listener for repair browser launching button
  document.getElementById('repair-browser-launching').addEventListener('click', function () {
    console.log('Running browser launcher repair script');

    // Show a message to the user
    alert('The browser launcher repair script will now run. This may take a moment and will require administrative privileges.');

    // Run the repair script with PowerShell
    const scriptPath = 'scripts/FixNativeMessagingHost.ps1';
    const command = `powershell.exe -ExecutionPolicy Bypass -NoProfile -File "${scriptPath}"`;

    chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
      command: command,
      url: ''
    }, (response) => {
      if (chrome.runtime.lastError) {
        console.error(`Error running repair script: ${chrome.runtime.lastError.message}`);
        alert(`Error: ${chrome.runtime.lastError.message}\n\nPlease run the repair script manually from the extension folder.`);
      } else if (response && response.result && response.result.startsWith("Error:")) {
        console.error(`Error from native messaging: ${response.result}`);
        alert(`Error: ${response.result}\n\nPlease run the repair script manually from the extension folder.`);
      } else {
        console.log('Repair script executed successfully:', response);
        alert('Browser launcher repair completed. Please restart your browser and try launching browsers again.');
      }
    });
  });

  // ... rest of existing code ...

  function createWSLInstanceFromScratch() {
    console.log("createWSLInstanceFromScratch called");
    // Handle the verification directly here and ensure runManageWSLInstanceScript gets called
    chrome.storage.local.get(['wslPasswordProtectionEnabled', 'wslPassword'], function (result) {
      if (result.wslPasswordProtectionEnabled && result.wslPassword) {
        console.log("Password protection enabled, verifying password");
        // Replace verifyPassword().then with verifyWSLPassword callback
        verifyWSLPassword(function (isValid) {
          console.log("Password verification result:", isValid);
          if (isValid) {
            console.log("Password verified, running script");
            runManageWSLInstanceScript();
          } else {
            console.log("Password verification failed");
            alert("Password verification failed. Cannot perform this operation.");
          }
        });
      } else {
        console.log("No password protection, running script directly");
        runManageWSLInstanceScript();
      }
    });
  }

  function runManageWSLInstanceScript() {
    console.log("runManageWSLInstanceScript called");

    try {
      // Ultra-simple approach: just run a direct CMD command to search for and run the script
      const command = `cmd /c start cmd.exe /k "echo Searching for WSL script... & ` +
        `echo Checking current user's profile... & ` +
        `echo Will run script when found... & ` +
        `for /f "tokens=*" %f in ('where /r "%USERPROFILE%" Manage-WSLInstance.bat') do (` +
        `echo Found script at: %f & ` +
        `cd /d "%~dpf" & ` +
        `echo Current directory: %CD% & ` +
        `echo Running script... & ` +
        `call "%f" & ` +
        `echo Script execution completed. & ` +
        `echo Press any key to close this window... & ` +
        `pause > nul` +
        `)"`;

      console.log("Sending command to native messaging host:", command);

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        console.log("Response from native messaging host:", response);
        if (chrome.runtime.lastError) {
          console.error('Error running WSL script:', chrome.runtime.lastError);
          alert('Failed to launch WSL script: ' + chrome.runtime.lastError.message);
        } else {
          console.log("Command sent successfully");
        }

        // Refresh the instances list regardless of the result
        setTimeout(() => {
          console.log("Refreshing WSL instances list");
          getWSLInstances();
        }, 5000);
      });
    } catch (error) {
      console.error("Exception in runManageWSLInstanceScript:", error);
      alert("Error running WSL script: " + error.message);
    }
  }

  // ... existing code ...

  // Add this to your document ready or initialization section
  document.getElementById('create-wsl-instance-scratch').addEventListener('click', createWSLInstanceFromScratch);

  // ... existing code ...

  // Initialize bootstrap modals
  try {
    // Try using jQuery if available (for Bootstrap 4)
    if (typeof $ !== 'undefined') {
      $('#password-modal').modal({
        backdrop: 'static',
        keyboard: false,
        show: false
      });
    }
  } catch (e) {
    console.error('Error initializing bootstrap modals:', e);
  }

  // Add auto-discovery function
  async function autoDiscoverWSLScripts() {
    // Use PowerShell to get the user profile and check for the script
    const command = `powershell.exe -NoProfile -Command "` +
      `$workspacePath = Join-Path $env:USERPROFILE 'Desktop\\MyGIT\\PS7333\\wslscripts'; ` +
      `if (Test-Path (Join-Path $workspacePath 'Manage-WSLInstance.bat')) { ` +
      `  Write-Output $workspacePath; ` +
      `} else { ` +
      `  Write-Output 'NOT_FOUND'; ` +
      `}"`;

    return new Promise((resolve) => {
      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        if (chrome.runtime.lastError) {
          console.error('Auto-discovery error:', chrome.runtime.lastError);
          resolve(null);
        } else if (response && response.result && response.result !== 'NOT_FOUND') {
          resolve(response.result.trim());
        } else {
          resolve(null);
        }
      });
    });
  }

  // Add event listener for auto-discover button
  document.getElementById('auto-discover-wsl-scripts').addEventListener('click', async function () {
    this.disabled = true;
    this.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Searching...';

    const path = await autoDiscoverWSLScripts();

    this.disabled = false;
    this.innerHTML = '<i class="fas fa-search"></i> Auto Discover';

    if (path) {
      document.getElementById('wsl-scripts-path').value = path;
      chrome.storage.local.set({ wslScriptsPath: path }, function () {
        console.log('WSL scripts path saved:', path);
      });
      alert('WSL scripts folder found at: ' + path);
    } else {
      alert('Could not find WSL scripts folder automatically. Please set the path manually.');
    }
  });

  // ... existing code ...

  // Add this near the top of the file with other global variables
  // let isPasswordVerifiedForSession = false;

  // Separate function to execute the WSL manager
  function executeWSLManager() {
    chrome.storage.local.get(['wslScriptsPath'], function (result) {
      let scriptPath = result.wslScriptsPath;

      if (!scriptPath) {
        alert('WSL scripts path not set. Please set it in the Settings tab first.');
        return;
      }

      const command = `cmd /c start powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "` +
        `$scriptPath = Join-Path -Path '${scriptPath}' -ChildPath 'Manage-WSLInstance.bat'; ` +
        `if (Test-Path $scriptPath) { ` +
        `  Write-Host 'Found script at:' $scriptPath; ` +
        `  cd '${scriptPath}'; ` +
        `  Write-Host 'Current directory:' (Get-Location); ` +
        `  & $scriptPath; ` +
        `} else { ` +
        `  Write-Host 'Error: Script not found at' $scriptPath; ` +
        `}"`;

      chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
        command: command,
        url: ""
      }, (response) => {
        if (chrome.runtime.lastError) {
          console.error(chrome.runtime.lastError);
          alert('Error launching WSL Instance Manager: ' + chrome.runtime.lastError.message);
        } else {
          console.log('WSL Instance Manager launched successfully');
        }
      });
    });
  }

  // Update CSS styling for the license modal
  const licenseModalStyle = document.createElement('style');
  licenseModalStyle.textContent = `
    #license-modal.modal {
      top: 0 !important;
      transform: none !important;
      position: fixed;
      height: auto !important;
      max-height: none !important;
      overflow: visible !important;
    }

    #license-modal .modal-dialog {
      max-width: 380px;
      margin: 5px auto;
      position: relative;
      transform: none !important;
    }

    #license-modal .modal-content {
      border-radius: 6px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      overflow: visible !important;
    }

    #license-modal .modal-body {
      padding: 6px 10px;
      font-size: 0.85rem;
      overflow: visible !important;
      max-height: none !important;
    }

    #license-modal .modal-header {
      padding: 6px 10px;
      background-color: #f8f9fa;
      border-bottom: 1px solid #dee2e6;
      border-radius: 6px 6px 0 0;
    }

    #license-modal .modal-header h5 {
      font-size: 1rem;
      margin: 0;
      line-height: 1.2;
    }

    #license-modal .modal-footer {
      padding: 6px 10px;
      background-color: #f8f9fa;
      border-top: 1px solid #dee2e6;
    }

    #license-modal .form-group {
      margin-bottom: 6px;
    }

    #license-modal .alert {
      padding: 6px 8px;
      margin-bottom: 6px;
      font-size: 0.85rem;
      line-height: 1.3;
    }

    #license-modal .license-status {
      margin-bottom: 8px;
      padding: 6px;
    }

    #license-modal .close {
      padding: 2px 6px;
      font-size: 1.1rem;
      line-height: 1;
    }

    #license-modal input,
    #license-modal select {
      font-size: 0.85rem;
      padding: 3px 6px;
      height: auto;
      line-height: 1.2;
    }

    #license-modal .btn {
      padding: 3px 10px;
      font-size: 0.85rem;
      line-height: 1.2;
    }

    /* Remove scrolling and ensure visibility */
    #license-modal .modal-dialog,
    #license-modal .modal-content,
    #license-modal .modal-body {
      overflow: visible !important;
    }

    /* Ensure modal appears on top */
    #license-modal {
      z-index: 1050;
    }
    .modal-backdrop {
      z-index: 1040;
    }

    /* Optimize line heights for better vertical compression */
    #license-modal p {
      margin-bottom: 4px;
      line-height: 1.3;
    }

    /* Make text more compact but still readable */
    #license-modal .license-status p {
      margin: 3px 0;
    }
  `;
  document.head.appendChild(licenseModalStyle);

  // Add additional CSS for copy/paste buttons
  licenseModalStyle.textContent += `
    .key-field-container {
      position: relative;
      display: flex;
      align-items: center;
      gap: 5px;
    }

    .key-field-container input {
      flex: 1;
    }

    .key-action-btn {
      padding: 3px 6px;
      background: #f8f9fa;
      border: 1px solid #dee2e6;
      border-radius: 4px;
      cursor: pointer;
      font-size: 0.85rem;
      color: #495057;
      transition: all 0.2s;
    }

    .key-action-btn:hover {
      background: #e9ecef;
      color: #212529;
    }

    .key-action-btn.copy-success {
      background: #28a745;
      color: white;
      border-color: #28a745;
    }

    .tooltip {
      position: absolute;
      background: rgba(0,0,0,0.8);
      color: white;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 0.75rem;
      z-index: 1060;
      display: none;
    }
  `;

  // Function to wrap license key input with copy button
  function enhanceLicenseKeyField() {
    const licenseKeyInput = document.getElementById('modal-license-key');
    if (!licenseKeyInput) return;

    // Check if already enhanced
    if (licenseKeyInput.parentNode.className === 'key-field-container') {
      return; // Already enhanced, don't add more buttons
    }

    // Remove any existing containers if they exist
    const existingContainer = document.querySelector('.key-field-container');
    if (existingContainer) {
      // Move the input back to its original position
      existingContainer.parentNode.insertBefore(licenseKeyInput, existingContainer);
      existingContainer.remove();
    }

    // Create container
    const container = document.createElement('div');
    container.className = 'key-field-container';

    // Wrap input in container
    licenseKeyInput.parentNode.insertBefore(container, licenseKeyInput);
    container.appendChild(licenseKeyInput);

    // Add copy button
    const copyBtn = document.createElement('button');
    copyBtn.className = 'key-action-btn';
    copyBtn.innerHTML = '<i class="fas fa-copy"></i>';
    copyBtn.title = 'Copy license key';
    copyBtn.type = 'button'; // Prevent form submission

    // Add button to container
    container.appendChild(copyBtn);

    // Copy functionality
    copyBtn.addEventListener('click', async () => {
      const licenseKey = licenseKeyInput.value.trim();
      if (licenseKey) {
        try {
          await navigator.clipboard.writeText(licenseKey);
          copyBtn.classList.add('copy-success');
          const originalHtml = copyBtn.innerHTML;
          copyBtn.innerHTML = '<i class="fas fa-check"></i>';
          setTimeout(() => {
            copyBtn.classList.remove('copy-success');
            copyBtn.innerHTML = originalHtml;
          }, 1500);
        } catch (err) {
          console.error('Failed to copy:', err);
          alert('Failed to copy license key. Please try selecting and copying manually.');
        }
      }
    });
  }

  // Clean up function for when modal is hidden
  function cleanupLicenseKeyField() {
    const container = document.querySelector('.key-field-container');
    if (container) {
      const licenseKeyInput = container.querySelector('#modal-license-key');
      if (licenseKeyInput) {
        // Move the input back to its original position
        container.parentNode.insertBefore(licenseKeyInput, container);
        container.remove();
      }
    }
  }

  // Call the enhancement function when the modal is shown and cleanup when hidden
  document.getElementById('manage-license-btn').addEventListener('click', function () {
    // Wait for modal to be fully shown
    setTimeout(enhanceLicenseKeyField, 100);
  });

  // Add cleanup when modal is hidden
  const licenseModal = document.getElementById('license-modal');
  if (licenseModal) {
    licenseModal.addEventListener('hidden.bs.modal', cleanupLicenseKeyField);
  }

  // Add this after the existing search settings code

  // Custom Search Engines Management
  const customSearchTemplate = document.getElementById('custom-search-template');
  const customSearchList = document.getElementById('custom-search-engines-list');
  const addCustomSearchBtn = document.getElementById('add-custom-search');

  // Load custom search engines
  function loadCustomSearchEngines() {
    chrome.storage.local.get('customSearchEngines', function (result) {
      const customEngines = result.customSearchEngines || [];
      customSearchList.innerHTML = ''; // Clear existing entries

      customEngines.forEach((engine, index) => {
        const engineElement = createCustomSearchElement(engine);
        customSearchList.appendChild(engineElement);
      });
    });
  }

  // Create custom search engine element
  function createCustomSearchElement(engine = {}) {
    const template = customSearchTemplate.cloneNode(true);
    const engineElement = template.querySelector('.custom-search-engine');
    engineElement.classList.remove('d-none');

    // Set values if provided
    engineElement.querySelector('.custom-name').value = engine.name || '';
    engineElement.querySelector('.custom-url').value = engine.url || '';
    engineElement.querySelector('.custom-icon').value = engine.icon || '';
    engineElement.querySelector('.custom-enabled').checked = engine.enabled !== false;

    // Add event listeners
    engineElement.querySelector('.remove-custom-search').addEventListener('click', function () {
      if (confirm('Are you sure you want to remove this search engine?')) {
        engineElement.remove();
        saveCustomSearchEngines(); // Keep saving on removal
      }
    });

    // Remove automatic saving on input changes
    // const inputs = engineElement.querySelectorAll('input');
    // inputs.forEach(input => {
    //   input.addEventListener('change', saveCustomSearchEngines);
    //   input.addEventListener('input', saveCustomSearchEngines);
    // });

    return engineElement;
  }

  // Save custom search engines
  function saveCustomSearchEngines() {
    const engines = [];
    const engineElements = customSearchList.querySelectorAll('.custom-search-engine');

    engineElements.forEach(element => {
      const engine = {
        name: element.querySelector('.custom-name').value.trim(),
        url: element.querySelector('.custom-url').value.trim(),
        icon: element.querySelector('.custom-icon').value.trim(),
        enabled: element.querySelector('.custom-enabled').checked
      };

      // Only save if name and URL are provided
      if (engine.name && engine.url) {
        engines.push(engine);
      }
    });

    chrome.storage.local.set({ customSearchEngines: engines }, function () {
      // Notify background script to update context menus
      chrome.runtime.sendMessage({ action: 'refreshContextMenus' });
    });
  }

  // Add new custom search engine
  if (addCustomSearchBtn) {
    addCustomSearchBtn.addEventListener('click', function () {
      const engineElement = createCustomSearchElement();
      customSearchList.appendChild(engineElement);
    });
  }

  // Load custom search engines when the search settings tab is clicked
  document.getElementById('search-settings-tab').addEventListener('click', function () {
    loadCustomSearchEngines();
    loadSearchSettings();
  });

  // Add event listener for the new save button
  const saveCustomEnginesBtn = document.getElementById('save-custom-search-engines');
  if (saveCustomEnginesBtn) {
    saveCustomEnginesBtn.addEventListener('click', function () {
      saveCustomSearchEngines();
      // Optional: Add visual feedback like a success message
      alert('Custom search engines saved!');
    });
  }

  // Add event listener for the context menu toggle
  document.getElementById('context-menu-toggle').addEventListener('change', function () {
    const enabled = this.checked;
    chrome.storage.local.set({ 'contextMenuEnabled': enabled }, function () {
      // Send message to update the context menu
      chrome.runtime.sendMessage({ action: 'updateContextMenu', enabled: enabled });
    });
  });

  loadSettings();

  loadCheckboxStates();
  loadSettings();
  loadShowWSLSetting();
  loadVersionCheckboxState();
  loadSearchSettings();

  // Make sure all event listeners are properly set up
  const sandboxToggle = document.getElementById('sandbox-context-toggle');
  if (sandboxToggle) {
    // Load current value
    chrome.storage.local.get({ 'sandboxContextEnabled': true }, function (items) {
      sandboxToggle.checked = items.sandboxContextEnabled;
    });

    // Make sure event listener is attached only once
    sandboxToggle.addEventListener('change', function () {
      const isEnabled = this.checked;
      chrome.storage.local.set({ sandboxContextEnabled: isEnabled }, function () {
        console.log(`Sandbox context menu ${isEnabled ? 'enabled' : 'disabled'}`);
        // Refresh context menus
        chrome.runtime.sendMessage({ action: 'refreshContextMenus' });
      });
    });
  }

  // Remove the duplicate DOMContentLoaded event listener below

  // Export search settings functionality
  document.getElementById('export-search-settings').addEventListener('click', function () {
    chrome.storage.local.get(['searchConfig', 'customSearchEngines'], function (result) {
      const searchSettings = {
        searchConfig: result.searchConfig || {},
        customSearchEngines: result.customSearchEngines || []
      };

      const blob = new Blob([JSON.stringify(searchSettings, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'search_settings.json';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    });
  });

  // Import search settings functionality
  document.getElementById('import-search-settings').addEventListener('click', function () {
    document.getElementById('import-search-file').click();
  });

  document.getElementById('import-search-file').addEventListener('change', function (event) {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = function (e) {
        try {
          const importedData = JSON.parse(e.target.result);

          // Validate imported data structure
          if (!importedData.searchConfig || typeof importedData.searchConfig !== 'object') {
            throw new Error('Invalid search configuration format');
          }

          // Save the imported settings
          chrome.storage.local.set({
            searchConfig: importedData.searchConfig,
            customSearchEngines: importedData.customSearchEngines || []
          }, function () {
            // Update UI to reflect imported settings
            loadSearchSettings();
            loadCustomSearchEngines();

            // Refresh context menus with new settings
            chrome.runtime.sendMessage({ action: 'refreshContextMenus' });

            alert('Search settings imported successfully!');
          });
        } catch (error) {
          console.error('Error importing search settings:', error);
          alert('Error importing search settings: Invalid format');
        }
      };
      reader.readAsText(file);
    }
  });

  // ===== Custom Browsers Management =====
  const customBrowsersList = document.getElementById('custom-browsers-list');
  const customBrowserTemplate = document.getElementById('custom-browser-template');
  const addCustomBrowserBtn = document.getElementById('add-custom-browser');
  const saveCustomBrowsersBtn = document.getElementById('save-custom-browsers');

  // Function to create a custom browser element from template
  function createCustomBrowserElement(browserData = {}) {
    const template = customBrowserTemplate.cloneNode(true);
    template.removeAttribute('id');
    template.classList.remove('d-none');

    const browserItem = template.querySelector('.custom-browser-item');
    const nameInput = template.querySelector('.custom-browser-name');
    const platformSelect = template.querySelector('.custom-browser-platform');
    const pathInput = template.querySelector('.custom-browser-path');
    const iconInput = template.querySelector('.custom-browser-icon');
    const enabledCheckbox = template.querySelector('.custom-browser-enabled');
    const removeBtn = template.querySelector('.remove-custom-browser');

    // Populate with data if provided
    if (browserData.name) nameInput.value = browserData.name;
    if (browserData.platform) platformSelect.value = browserData.platform;
    if (browserData.path) pathInput.value = browserData.path;
    if (browserData.icon) iconInput.value = browserData.icon;
    if (browserData.hasOwnProperty('enabled')) enabledCheckbox.checked = browserData.enabled;

    // Add remove button event listener
    removeBtn.addEventListener('click', function () {
      if (confirm('Are you sure you want to remove this custom browser?')) {
        template.remove();
      }
    });

    return template;
  }

  // Function to load custom browsers from storage
  function loadCustomBrowsers() {
    chrome.storage.local.get(['customBrowsers'], function (result) {
      const customBrowsers = result.customBrowsers || [];
      customBrowsersList.innerHTML = ''; // Clear existing list

      if (customBrowsers.length === 0) {
        customBrowsersList.innerHTML = '<p class="text-muted text-center" style="font-size: 0.85rem;">No custom browsers added yet. Click "Add Browser" to get started.</p>';
      } else {
        customBrowsers.forEach(browser => {
          const browserElement = createCustomBrowserElement(browser);
          customBrowsersList.appendChild(browserElement);
        });
      }
    });
  }


  // Function to save custom browsers to storage
  function saveCustomBrowsers() {
    console.log('[SAVE] saveCustomBrowsers function called');
    console.log('[SAVE] customBrowsersList element:', customBrowsersList);

    const browserElements = customBrowsersList.querySelectorAll('.custom-browser-item');
    console.log('[SAVE] Found browser elements:', browserElements.length);

    const customBrowsers = [];

    browserElements.forEach((element, index) => {
      console.log(`[SAVE] Processing browser element ${index + 1}`);

      const name = element.querySelector('.custom-browser-name').value.trim();
      const platform = element.querySelector('.custom-browser-platform').value;
      const path = element.querySelector('.custom-browser-path').value.trim();
      const icon = element.querySelector('.custom-browser-icon').value.trim();
      const enabled = element.querySelector('.custom-browser-enabled').checked;

      console.log(`[SAVE] Browser ${index + 1} data:`, { name, platform, path, icon, enabled });

      // Validate required fields
      if (name && path) {
        const browser = {
          name: name,
          platform: platform,
          path: path,
          icon: icon || '🌐', // Default icon if not provided
          enabled: enabled,
          id: `custom-${name.toLowerCase().replace(/[^a-z0-9]/g, '-')}-${platform}`
        };
        customBrowsers.push(browser);
        console.log(`[SAVE] ✅ Browser ${index + 1} added:`, browser);
      } else {
        console.warn(`[SAVE] ❌ Browser ${index + 1} skipped - missing name or path`);
      }
    });

    console.log('[SAVE] Total browsers to save:', customBrowsers.length);
    console.log('[SAVE] Browsers array:', customBrowsers);

    // Save to storage
    chrome.storage.local.set({ customBrowsers: customBrowsers }, function () {
      console.log('[SAVE] chrome.storage.local.set callback executed');
      console.log('[SAVE] Custom browsers saved:', customBrowsers);
      alert('Custom browsers saved successfully!');

      // Refresh context menus to include new custom browsers
      console.log('[SAVE] Sending refreshContextMenus message...');
      chrome.runtime.sendMessage({ action: 'refreshContextMenus' }, function (response) {
        console.log('[SAVE] refreshContextMenus response:', response);
        if (chrome.runtime.lastError) {
          console.error('[SAVE] Error refreshing menus:', chrome.runtime.lastError);
        }
      });

      // Reload the list to show saved data
      console.log('[SAVE] Reloading custom browsers list...');
      loadCustomBrowsers();
    });
  }

  // Add new custom browser
  if (addCustomBrowserBtn) {
    addCustomBrowserBtn.addEventListener('click', function () {
      const browserElement = createCustomBrowserElement();
      customBrowsersList.appendChild(browserElement);

      // Remove the "no browsers" message if it exists
      const noDataMsg = customBrowsersList.querySelector('p.text-muted');
      if (noDataMsg) {
        noDataMsg.remove();
      }
    });
  }

  // Save custom browsers
  if (saveCustomBrowsersBtn) {
    saveCustomBrowsersBtn.addEventListener('click', function () {
      saveCustomBrowsers();
    });
  }

  // Test custom browsers - Debug button
  const testCustomBrowsersBtn = document.getElementById('test-custom-browsers');
  if (testCustomBrowsersBtn) {
    testCustomBrowsersBtn.addEventListener('click', function () {
      console.log('='.repeat(80));
      console.log('[TEST] Custom Browsers Debug Test Started');
      console.log('='.repeat(80));

      chrome.storage.local.get(['customBrowsers'], function (result) {
        const customBrowsers = result.customBrowsers || [];

        console.log('[TEST] Custom browsers in storage:', customBrowsers);
        console.log('[TEST] Number of custom browsers:', customBrowsers.length);

        if (customBrowsers.length === 0) {
          alert('❌ No custom browsers found!\n\nPlease add a custom browser and click "Save Custom Browsers" first.');
          console.log('[TEST] ❌ No custom browsers found in storage');
          return;
        }

        // Display each browser
        customBrowsers.forEach((browser, index) => {
          console.log(`\n[TEST] Browser ${index + 1}:`);
          console.log(`  Name: ${browser.name}`);
          console.log(`  Platform: ${browser.platform}`);
          console.log(`  Path: ${browser.path}`);
          console.log(`  Icon: ${browser.icon}`);
          console.log(`  Enabled: ${browser.enabled}`);
          console.log(`  ID: ${browser.id}`);
        });

        // Test context menu
        console.log('\n[TEST] Checking context menu integration...');
        chrome.runtime.sendMessage({ action: 'refreshContextMenus' }, function (response) {
          if (chrome.runtime.lastError) {
            console.error('[TEST] Error refreshing context menus:', chrome.runtime.lastError);
          } else {
            console.log('[TEST] ✅ Context menus refreshed successfully');
          }
        });

        // Create summary message
        const enabledBrowsers = customBrowsers.filter(b => b.enabled);
        const summary = `
✅ Custom Browsers Test Results:

Total browsers: ${customBrowsers.length}
Enabled browsers: ${enabledBrowsers.length}

${enabledBrowsers.map((b, i) => `${i + 1}. ${b.icon} ${b.name} (${b.platform})`).join('\n')}

📋 Check the console for detailed information.

Next steps:
1. Right-click on any link
2. Look for your custom browser in the context menu
3. Click "Open in Normal Window"
4. Check console logs (F12) for debugging info
        `.trim();

        alert(summary);
        console.log('[TEST] Test completed successfully');
        console.log('='.repeat(80));
      });
    });
  }

  // Load custom browsers when settings tab is clicked
  document.getElementById('settings-tab').addEventListener('click', function () {
    loadCustomBrowsers();
  });

  // Load custom browsers on initial page load
  loadCustomBrowsers();



  // Password validation function (used by multiple places)
  function isValidPassword(password) {
    return password &&
      password.length >= 8 &&
      /\d/.test(password);
  }

  // Password hashing function 
  async function digestPassword(password) {
    // Convert the string to an ArrayBuffer
    const encoder = new TextEncoder();
    const data = encoder.encode(password);

    // Generate the hash
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);

    // Convert the hash to a hex string
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

    return hashHex;
  }

  // ===== Footer Functionality =====
  (function initFooterFunctionality() {
    // Footer refresh button
    const footerRefreshBtn = document.getElementById('footer-refresh-btn');
    if (footerRefreshBtn) {
      footerRefreshBtn.addEventListener('click', function () {
        // Refresh all browser versions
        updateBrowserVersions();

        // Provide visual feedback
        this.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
        setTimeout(() => {
          this.innerHTML = '<i class="fas fa-sync-alt"></i>';
        }, 1500);
      });
    }

    // Footer settings button - quick access to settings tab
    const footerSettingsBtn = document.getElementById('footer-settings-btn');
    if (footerSettingsBtn) {
      footerSettingsBtn.addEventListener('click', function () {
        // Switch to settings tab
        const settingsTab = document.getElementById('settings-tab');
        if (settingsTab) {
          settingsTab.click();
        }
      });
    }



    // Update build info with current date if not already set
    function updateBuildInfo() {
      const buildInfoEl = document.querySelector('.build-info');
      if (buildInfoEl && buildInfoEl.textContent === 'Build 2025.11.08') {
        const today = new Date();
        const buildDate = today.getFullYear() + '.' +
          String(today.getMonth() + 1).padStart(2, '0') + '.' +
          String(today.getDate()).padStart(2, '0');
        buildInfoEl.textContent = `Build ${buildDate}`;
      }
    }

    updateBuildInfo();
  })();

  // Add event listener for the sandbox context menu toggle (which was accidentally removed)
  document.addEventListener('DOMContentLoaded', function () {
    const sandboxToggle = document.getElementById('sandbox-context-toggle');
    if (sandboxToggle) {
      sandboxToggle.addEventListener('change', function () {
        const enabled = this.checked;
        chrome.storage.local.set({ 'sandboxContextEnabled': enabled }, function () {
          // Send message to update the sandbox context menu
          chrome.runtime.sendMessage({ action: 'updateSandboxContextMenu', enabled: enabled });
        });
      });
    }
  });
});


