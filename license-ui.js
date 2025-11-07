document.addEventListener('DOMContentLoaded', async function() {
  // Initialize the license system
  await window.BrowserLauncherLicense.initialize();
  
  // Elements
  const licenseStatusEl = document.getElementById('licenseStatus');
  const hardwareIdEl = document.getElementById('hardwareId');
  const licenseKeyInput = document.getElementById('licenseKey');
  const activateBtn = document.getElementById('activateBtn');
  const licenseMessageEl = document.getElementById('licenseMessage');
  const diagnosticsButton = document.getElementById('diagnosticsButton');
  const regenerateButton = document.getElementById('regenerateButton');
  const hardwareIdDiagnosticsEl = document.getElementById('hardwareIdDiagnostics');
  
  // Hardware ID diagnostics elements
  const diagnosticsHardwareIdEl = document.getElementById('diagnosticsHardwareId');
  const diagnosticsUsingFallbackEl = document.getElementById('diagnosticsUsingFallback');
  const diagnosticsNativeMessagingEl = document.getElementById('diagnosticsNativeMessaging');
  const diagnosticsErrorEl = document.getElementById('diagnosticsError');
  const diagnosticsPlatformEl = document.getElementById('diagnosticsPlatform');
  
  // Toggle hardware ID diagnostics
  if (diagnosticsButton) {
    diagnosticsButton.addEventListener('click', async function() {
      if (hardwareIdDiagnosticsEl.style.display === 'none') {
        hardwareIdDiagnosticsEl.style.display = 'block';
        diagnosticsButton.textContent = 'Hide Diagnostics';
        await updateDiagnosticsInfo();
      } else {
        hardwareIdDiagnosticsEl.style.display = 'none';
        diagnosticsButton.textContent = 'Show Diagnostics';
      }
    });
  }
  
  // Regenerate hardware ID
  if (regenerateButton) {
    regenerateButton.addEventListener('click', async function() {
      if (confirm('Are you sure you want to regenerate your hardware ID? This may invalidate any existing license.')) {
        regenerateButton.disabled = true;
        regenerateButton.textContent = 'Regenerating...';
        
        try {
          const diagnostics = await window.BrowserLauncherLicense.regenerateHardwareId();
          showMessage('Hardware ID regenerated successfully', true);
          
          // Update the UI
          hardwareIdEl.textContent = diagnostics.hardwareId;
          
          // Update diagnostics if visible
          if (hardwareIdDiagnosticsEl.style.display !== 'none') {
            updateDiagnosticsDisplay(diagnostics);
          }
        } catch (error) {
          showMessage('Error regenerating hardware ID: ' + error.message, false);
        } finally {
          regenerateButton.disabled = false;
          regenerateButton.textContent = 'Regenerate ID';
        }
      }
    });
  }
  
  // Update hardware ID diagnostics information
  async function updateDiagnosticsInfo() {
    try {
      const diagnostics = await window.BrowserLauncherLicense.getHardwareIdDiagnostics();
      updateDiagnosticsDisplay(diagnostics);
    } catch (error) {
      console.error('Error getting hardware ID diagnostics:', error);
      showMessage('Error retrieving hardware ID diagnostics', false);
    }
  }
  
  // Update the diagnostics display with the retrieved information
  function updateDiagnosticsDisplay(diagnostics) {
    diagnosticsHardwareIdEl.textContent = diagnostics.hardwareId || 'Not generated';
    diagnosticsUsingFallbackEl.textContent = diagnostics.usingFallback ? 'Yes (less secure)' : 'No';
    diagnosticsUsingFallbackEl.style.color = diagnostics.usingFallback ? '#c62828' : '#2e7d32';
    
    diagnosticsNativeMessagingEl.textContent = diagnostics.nativeMessagingStatus || 'Unknown';
    diagnosticsNativeMessagingEl.style.color = 
      diagnostics.nativeMessagingStatus === 'Connected' ? '#2e7d32' : 
      diagnostics.nativeMessagingStatus.includes('Error') ? '#c62828' : '#000000';
    
    diagnosticsErrorEl.textContent = diagnostics.error || 'None';
    diagnosticsErrorEl.style.color = diagnostics.error ? '#c62828' : '#2e7d32';
    
    diagnosticsPlatformEl.textContent = diagnostics.browserPlatform || 'Unknown';
  }
  
  // Update UI with license info
  async function updateLicenseUI() {
    const licenseInfo = await window.BrowserLauncherLicense.getLicenseInfo();
    
    // Display hardware ID
    if (hardwareIdEl) {
      hardwareIdEl.textContent = licenseInfo.hardwareId || 'Error loading hardware ID';
    }
    
    // Set license key if available
    if (licenseKeyInput && licenseInfo.licenseKey) {
      licenseKeyInput.value = licenseInfo.licenseKey;
      licenseKeyInput.readOnly = licenseInfo.status === 'licensed';
    }
    
    // Hide or show activate button based on license status
    if (activateBtn) {
      if (licenseInfo.status === 'licensed') {
        activateBtn.style.display = 'none'; // Hide button when already licensed
        
        // Add deactivate button if it doesn't exist
        if (!document.getElementById('deactivateBtn')) {
          const deactivateBtn = document.createElement('button');
          deactivateBtn.id = 'deactivateBtn';
          deactivateBtn.className = 'submit-btn';
          deactivateBtn.style.backgroundColor = '#f44336';
          deactivateBtn.style.marginRight = '10px';
          deactivateBtn.style.padding = '8px 20px';
          deactivateBtn.textContent = 'Deactivate License';
          
          // Add event listener for deactivation
          deactivateBtn.addEventListener('click', async function() {
            // Create custom confirmation dialog
            const confirmDialog = document.createElement('div');
            confirmDialog.style.position = 'fixed';
            confirmDialog.style.top = '0';
            confirmDialog.style.left = '0';
            confirmDialog.style.width = '100%';
            confirmDialog.style.height = '100%';
            confirmDialog.style.backgroundColor = 'rgba(0, 0, 0, 0.5)';
            confirmDialog.style.display = 'flex';
            confirmDialog.style.justifyContent = 'center';
            confirmDialog.style.alignItems = 'center';
            confirmDialog.style.zIndex = '9999';
            
            const dialogContent = document.createElement('div');
            dialogContent.style.backgroundColor = 'white';
            dialogContent.style.padding = '20px';
            dialogContent.style.borderRadius = '8px';
            dialogContent.style.maxWidth = '400px';
            dialogContent.style.boxShadow = '0 4px 8px rgba(0, 0, 0, 0.2)';
            
            dialogContent.innerHTML = `
              <h3 style="margin-top: 0; color: #f44336;">Deactivate License</h3>
              <p>Are you sure you want to deactivate this license?</p>
              <p>This will:</p>
              <ul>
                <li>Return the extension to trial mode</li>
                <li>Disable premium features if your trial has expired</li>
                <li>Allow you to activate a different license</li>
              </ul>
              <div style="text-align: right; margin-top: 20px;">
                <button id="cancelDeactivateBtn" style="background-color: #757575; color: white; border: none; padding: 8px 15px; border-radius: 4px; margin-right: 10px; cursor: pointer;">Cancel</button>
                <button id="confirmDeactivateBtn" style="background-color: #f44336; color: white; border: none; padding: 8px 15px; border-radius: 4px; cursor: pointer;">Deactivate</button>
              </div>
            `;
            
            confirmDialog.appendChild(dialogContent);
            document.body.appendChild(confirmDialog);
            
            // Handle cancel button
            document.getElementById('cancelDeactivateBtn').addEventListener('click', function() {
              document.body.removeChild(confirmDialog);
            });
            
            // Handle confirm button
            document.getElementById('confirmDeactivateBtn').addEventListener('click', async function() {
              try {
                document.getElementById('confirmDeactivateBtn').disabled = true;
                document.getElementById('confirmDeactivateBtn').textContent = 'Deactivating...';
                
                // Call deactivate function
                const result = await window.BrowserLauncherLicense.deactivate();
                
                document.body.removeChild(confirmDialog);
                
                if (result && result.success) {
                  showMessage('License deactivated successfully', true);
                  
                  // Reload after a short delay
                  setTimeout(() => {
                    window.location.reload();
                  }, 1500);
                } else {
                  showMessage('Failed to deactivate license: ' + (result?.message || 'Unknown error'), false);
                }
              } catch (error) {
                console.error('Error deactivating license:', error);
                document.body.removeChild(confirmDialog);
                showMessage('Error deactivating license: ' + (error.message || 'Unknown error'), false);
              }
            });
          });
          
          // Add to the page next to activate button
          activateBtn.parentNode.insertBefore(deactivateBtn, activateBtn);
        }
      } else {
        activateBtn.style.display = 'block'; // Show button for trial or expired
        
        // Remove deactivate button if it exists
        const deactivateBtn = document.getElementById('deactivateBtn');
        if (deactivateBtn) {
          deactivateBtn.remove();
        }
      }
    }
    
    // Add close button if it doesn't exist
    if (!document.getElementById('closeBtn')) {
      // Create a container for buttons at the bottom
      const buttonContainer = document.createElement('div');
      buttonContainer.style.textAlign = 'center';
      buttonContainer.style.marginTop = '20px';
      buttonContainer.style.paddingTop = '15px';
      buttonContainer.style.borderTop = '1px solid #e0e0e0';
      
      const closeBtn = document.createElement('button');
      closeBtn.id = 'closeBtn';
      closeBtn.className = 'submit-btn';
      closeBtn.style.backgroundColor = '#757575';
      closeBtn.style.padding = '8px 20px';
      closeBtn.style.margin = '5px';
      closeBtn.textContent = 'Close';
      
      // Add event listener to close the window
      closeBtn.addEventListener('click', function() {
        window.close();
      });
      
      // Add button to container
      buttonContainer.appendChild(closeBtn);
      
      // Add to the page after the license form or at the bottom of the container
      const licenseForm = document.getElementById('licenseForm');
      if (licenseForm) {
        licenseForm.after(buttonContainer);
      } else {
        // If form not found, add to the bottom of the container
        const container = document.querySelector('.license-container');
        if (container) {
          container.appendChild(buttonContainer);
        }
      }
    }
    
    // Update status display
    if (licenseStatusEl) {
      licenseStatusEl.className = 'license-status';
      let statusHtml = '';
      
      switch(licenseInfo.status) {
        case 'trial':
          licenseStatusEl.classList.add('status-trial');
          statusHtml = `
            <h3>Trial Mode</h3>
            <p>You are currently using Browser Launcher Pro in trial mode.</p>
            <p><strong>${licenseInfo.daysRemaining} days remaining</strong> in your trial period.</p>
            <p>Purchase a license to continue using all features after your trial expires.</p>
          `;
          break;
          
        case 'licensed':
          licenseStatusEl.classList.add('status-licensed');
          
          // Format purchase date if available
          let purchaseDateFormatted = '';
          if (licenseInfo.purchaseDate) {
            try {
              const date = new Date(licenseInfo.purchaseDate);
              // Format date as MM/DD/YYYY to match the UI design
              const month = (date.getMonth() + 1).toString().padStart(2, '0');
              const day = date.getDate().toString().padStart(2, '0');
              const year = date.getFullYear();
              purchaseDateFormatted = `${month}/${day}/${year}`;
            } catch (e) {
              console.error('Error formatting purchase date:', e);
              purchaseDateFormatted = licenseInfo.purchaseDate;
            }
          }
          
          // Format expiry date if available
          let expiryDateFormatted = '';
          if (licenseInfo.expiryDate) {
            try {
              const date = new Date(licenseInfo.expiryDate);
              expiryDateFormatted = date.toLocaleDateString();
            } catch (e) {
              expiryDateFormatted = licenseInfo.expiryDate;
            }
          }
          
          // Format license type display
          const licenseType = licenseInfo.licenseType === 'lifetime' ? 
                            'Lifetime License' : 
                            'Subscription License';
          
          statusHtml = `
            <h3>Licensed</h3>
            <p>Browser Launcher Pro is fully licensed for this device.</p>
            ${createLicenseInfoHTML(licenseInfo, purchaseDateFormatted)}
            <p>Thank you for your purchase!</p>
          `;
          break;
          
        case 'expired':
          licenseStatusEl.classList.add('status-expired');
          statusHtml = `
            <h3>Trial Expired</h3>
            <p>Your trial period has expired.</p>
            <p>Please enter a valid license key below to continue using Browser Launcher Pro.</p>
          `;
          break;
      }
      
      licenseStatusEl.innerHTML = statusHtml;
    }
  }
  
  // Handle license activation
  if (activateBtn) {
    activateBtn.addEventListener('click', async function() {
      const licenseKey = licenseKeyInput.value.trim();
      
      if (!licenseKey) {
        showMessage('Please enter a valid license key', false);
        return;
      }
      
      activateBtn.disabled = true;
      
      try {
        // Log for debugging
        console.log('Attempting to validate license key:', licenseKey);
        
        // Display message to user
        licenseMessageEl.textContent = 'Validating license key...';
        licenseMessageEl.className = 'license-message';
        licenseMessageEl.style.display = 'block';
        
        // Validate the license key (all metadata is extracted from the key itself)
        const result = await window.BrowserLauncherLicense.validate(licenseKey);
        
        console.log('License validation result:', result);
        
        if (result && result.valid) {
          // Hide the activation button immediately
          activateBtn.style.display = 'none';
          
          // Update the UI first after successful activation
          await updateLicenseUI();
          
          // Get the license info again to display in the message
          const licenseInfo = await window.BrowserLauncherLicense.getLicenseInfo();
          
          // Format the purchase date for display
          let purchaseDateFormatted = '';
          if (licenseInfo.purchaseDate) {
            try {
              const date = new Date(licenseInfo.purchaseDate);
              const month = (date.getMonth() + 1).toString().padStart(2, '0');
              const day = date.getDate().toString().padStart(2, '0');
              const year = date.getFullYear();
              purchaseDateFormatted = `${month}/${day}/${year}`;
            } catch (e) {
              purchaseDateFormatted = licenseInfo.purchaseDate;
            }
          }
          
          // Replace automatic reload with a confirmation dialog
          licenseMessageEl.innerHTML = `
            <div style="text-align: center; padding: 15px 0; background-color: #e8f5e9; border-radius: 6px; border: 1px solid #66bb6a;">
              <h3 style="color: #2e7d32; margin-top: 0;">License Activation Successful!</h3>
              ${createLicenseInfoHTML(licenseInfo, purchaseDateFormatted)}
              <p style="font-weight: bold;">Please click "Continue" to apply the changes.</p>
              <button id="confirmReloadBtn" style="
                background-color: #4285f4;
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 4px;
                cursor: pointer;
                margin-top: 15px;
                font-weight: bold;
                font-size: 14px;">
                Continue
              </button>
            </div>
          `;
          licenseMessageEl.className = 'license-message message-success';
          licenseMessageEl.style.display = 'block';
          
          // Add event listener to the confirm button
          document.getElementById('confirmReloadBtn').addEventListener('click', function() {
            // Reload the extension and page when user confirms
            if (chrome.runtime) {
              chrome.runtime.sendMessage({ action: 'licenseUpdated' });
              chrome.runtime.reload();
            }
            window.location.reload();
          });
        } else {
          // Show detailed error message based on error code
          let errorMessage = 'License validation failed';
          
          // Get specific error message from result if available
          if (result && result.message) {
            errorMessage = result.message;
          } else if (result && result.errorCode) {
            // Map error codes to user-friendly messages
            const errorMessages = {
              'invalid_format': 'Invalid license key format',
              'hardware_mismatch': 'This license key is not valid for this device',
              'expired_key': 'This license key has expired',
              'tampered_key': 'Invalid license key for this device',
              'extraction_failed': 'Could not read license key data',
              'unknown_error': 'An unknown error occurred'
            };
            errorMessage = errorMessages[result.errorCode] || 'License validation failed';
          } else if (!result) {
            errorMessage = 'License validation failed: No response from validation function';
          }
          
          showMessage(errorMessage, false);
          
          // Log the error for debugging
          console.error('License validation failed:', result ? JSON.stringify(result, null, 2) : 'No result');
        }
      } catch (error) {
        console.error('Error during license activation:', error);
        showMessage('An error occurred during activation: ' + (error.message || 'Unknown error'), false);
      } finally {
        activateBtn.disabled = false;
      }
    });
  }
  
  // Helper to show messages
  function showMessage(message, isSuccess) {
    if (licenseMessageEl) {
      licenseMessageEl.textContent = message;
      licenseMessageEl.className = 'license-message';
      licenseMessageEl.classList.add(isSuccess ? 'message-success' : 'message-error');
      licenseMessageEl.style.display = 'block';
      
      // Only auto-hide error messages, not success messages with confirmation buttons
      if (!isSuccess) {
        // Hide message after 5 seconds
        setTimeout(() => {
          licenseMessageEl.style.display = 'none';
        }, 5000);
      }
    }
  }
  
  // Helper function to create a formatted license info HTML
  function createLicenseInfoHTML(licenseInfo, purchaseDateFormatted) {
    return `
      <div style="text-align: left; margin: 15px auto; max-width: 90%; padding: 12px; background-color: #ffffff; border-radius: 4px; border: 1px solid #e0e0e0;">
        <p style="margin: 5px 0;"><strong>Licensed to:</strong> <span style="background-color: #FFFF00; padding: 0 5px; font-weight: bold; word-break: normal; overflow-wrap: break-word;">${licenseInfo.licenseeName || 'Unknown User'}</span></p>
        <p style="margin: 5px 0;"><strong>Email:</strong> ${licenseInfo.licenseeEmail || 'Not provided'}</p>
        <p style="margin: 5px 0;"><strong>Purchase date:</strong> ${purchaseDateFormatted || 'Not available'}</p>
        <p style="margin: 5px 0;"><strong>License type:</strong> ${licenseInfo.licenseType === 'lifetime' ? 'Lifetime License' : 'Subscription License'}</p>
      </div>
    `;
  }
  
  // Initialize UI
  await updateLicenseUI();
}); 