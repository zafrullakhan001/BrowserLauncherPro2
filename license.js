/**
 * License management for Browser Launcher Pro
 * Handles 60-day trial period and hardware-locked license keys
 */

// Constants
const TRIAL_PERIOD_DAYS = 60;
const STORAGE_KEYS = {
  INSTALL_DATE: 'installDate',
  LICENSE_KEY: 'licenseKey',
  HARDWARE_ID: 'hardwareId',
  LICENSE_STATUS: 'licenseStatus',
  // Add new fields for enhanced license info
  LICENSEE_NAME: 'licenseeName',
  LICENSEE_EMAIL: 'licenseeEmail',
  PURCHASE_DATE: 'purchaseDate',
  LICENSE_TYPE: 'licenseType',
  EXPIRY_DATE: 'expiryDate', // New field for key expiry
  HARDWARE_ID_ERROR: 'hardwareIdError',
  USING_FALLBACK_ID: 'usingFallbackId'
};

// License status enum
const LICENSE_STATUS = {
  TRIAL: 'trial',
  LICENSED: 'licensed',
  EXPIRED: 'expired'
};

// License type enum
const LICENSE_TYPE = {
  LIFETIME: 'lifetime',
  SUBSCRIPTION: 'subscription'
};

// Error codes for more specific error messages
const ERROR_CODES = {
  INVALID_FORMAT: 'invalid_format',
  HARDWARE_MISMATCH: 'hardware_mismatch',
  EXPIRED_KEY: 'expired_key',
  TAMPERED_KEY: 'tampered_key',
  EXTRACTION_FAILED: 'extraction_failed',
  UNKNOWN: 'unknown_error'
};

/**
 * Initializes the license system
 * Sets up the initial state on first install
 */
async function initializeLicense() {
  const data = await chrome.storage.local.get([
    STORAGE_KEYS.INSTALL_DATE,
    STORAGE_KEYS.LICENSE_KEY,
    STORAGE_KEYS.HARDWARE_ID
  ]);
  
  // If this is a first install, set the install date and initial days remaining
  if (!data[STORAGE_KEYS.INSTALL_DATE]) {
    const installDate = new Date().toISOString();
    await chrome.storage.local.set({ 
      [STORAGE_KEYS.INSTALL_DATE]: installDate,
      [STORAGE_KEYS.LICENSE_STATUS]: LICENSE_STATUS.TRIAL,
      daysRemaining: TRIAL_PERIOD_DAYS // Set initial days remaining to 60
    });
    console.log(`Trial period started on ${installDate} with ${TRIAL_PERIOD_DAYS} days remaining`);
  }
  
  // Generate a hardware ID if not already done
  if (!data[STORAGE_KEYS.HARDWARE_ID]) {
    const hardwareId = await generateHardwareId();
    await chrome.storage.local.set({ [STORAGE_KEYS.HARDWARE_ID]: hardwareId });
    console.log(`Hardware ID generated: ${hardwareId}`);
  }

  // Check license status
  await checkLicenseStatus();
}

/**
 * Generates a unique hardware ID for the current device
 * This ID is used to lock license keys to specific machines
 */
async function generateHardwareId() {
  try {
    console.log("Generating hardware ID...");
    
    // Add retries for native messaging
    let retryCount = 0;
    const maxRetries = 3;
    let response = null;
    
    while (retryCount < maxRetries) {
      try {
        // Request hardware-specific info through native messaging
        response = await new Promise((resolve, reject) => {
          const timeoutId = setTimeout(() => {
            reject(new Error("Native messaging timeout after 5 seconds"));
          }, 5000);
          
          chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
            action: 'getHardwareInfo'
          }, (result) => {
            clearTimeout(timeoutId);
            
            if (chrome.runtime.lastError) {
              console.error(`Native messaging error (attempt ${retryCount + 1}):`, chrome.runtime.lastError);
              // Check if the error is related to the native messaging host not being found
              if (chrome.runtime.lastError.message.includes("native messaging host not found")) {
                resolve({ error: "Native messaging host not found", fallback: true });
              } else if (chrome.runtime.lastError.message.includes("specified native messaging host is not allowed")) {
                resolve({ error: "Native messaging host not allowed", fallback: true });
              } else {
                // Fallback option if native messaging fails
                resolve({ error: chrome.runtime.lastError.message, fallback: true });
              }
            } else if (!result) {
              resolve({ error: "Empty response from native messaging host", fallback: true });
            } else {
              // Log the response for debugging
              console.log("Response from native messaging host:", result);
              
              // Handle different response formats
              if (result.error) {
                resolve({ error: result.error || "Error from native messaging host", fallback: true });
              } 
              // Check if the result itself is hardware info
              else if (isHardwareInfoObject(result)) {
                // Create a standardized response format for our code
                resolve({
                  success: true,
                  hardwareInfo: result
                });
              }
              // Check for legacy format with hardwareInfo property
              else if (result.hardwareInfo) {
                resolve(result);
              } 
              else if (typeof result === 'object' && Object.keys(result).length > 0) {
                // The response might have the hardware info but with a different property name
                // Try to identify if any property looks like hardware info
                console.log("Examining response properties for hardware info-like object");
                
                for (const key of Object.keys(result)) {
                  const value = result[key];
                  if (typeof value === 'object' && value !== null && isHardwareInfoObject(value)) {
                    // This looks like hardware info
                    console.log(`Found hardware info-like object in property "${key}"`);
                    // Create a corrected response
                    const correctedResponse = {
                      success: true,
                      hardwareInfo: value
                    };
                    resolve(correctedResponse);
                    return;
                  }
                }
                
                // If we got here, none of the properties looked like hardware info
                console.error("Could not identify hardware info in response:", result);
                resolve({ error: "Unexpected response format from native messaging host", fallback: true });
              } else {
                // Unrecognized response format
                console.error("Unrecognized response format:", result);
                resolve({ error: "Unexpected response format from native messaging host", fallback: true });
              }
            }
          });
        });
        
        // Helper function to check if an object is likely hardware info
        function isHardwareInfoObject(obj) {
          if (typeof obj !== 'object' || obj === null) return false;
          
          // Check if this value looks like hardware info (has typical hardware properties)
          const hardwareInfoProps = ['platform', 'machine', 'processor', 'mac', 'volume_serial', 
                                     'bios_serial', 'cpu_id', 'hostname', 'machine_id'];
          const matchCount = hardwareInfoProps.filter(prop => Object.keys(obj).includes(prop)).length;
          
          return matchCount >= 2;
        }
        
        // If we got a valid response, break the retry loop
        if (response && response.hardwareInfo) {
          console.log("Hardware info received successfully on attempt", retryCount + 1);
          break;
        }
        
        console.warn(`Attempt ${retryCount + 1}: Invalid or empty response, retrying...`);
        retryCount++;
        // Add a small delay before retrying
        await new Promise(resolve => setTimeout(resolve, 500));
      } catch (error) {
        console.error(`Attempt ${retryCount + 1} failed:`, error);
        retryCount++;
        
        if (retryCount >= maxRetries) {
          throw error;
        }
        
        // Add a small delay before retrying
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }
    
    // Check if we need to use the fallback method
    if (!response || response.fallback) {
      const errorMessage = response ? response.error : "No response received";
      const fallbackId = await generateFallbackHardwareId();
      console.log("Using fallback hardware ID due to error:", errorMessage);
      // Store the error for reporting purposes
      await chrome.storage.local.set({ 
        [STORAGE_KEYS.HARDWARE_ID_ERROR]: errorMessage,
        [STORAGE_KEYS.USING_FALLBACK_ID]: true
      });
      return fallbackId;
    }
    
    // Create a hash based on hardware info
    if (response.hardwareInfo) {
      console.log("Hardware info received, generating hash");
      const hwIdHash = await hashString(JSON.stringify(response.hardwareInfo));
      
      // Store that we're using a native hardware ID (not fallback)
      await chrome.storage.local.set({ 
        [STORAGE_KEYS.USING_FALLBACK_ID]: false,
        [STORAGE_KEYS.HARDWARE_ID_ERROR]: null
      });
      
      return hwIdHash;
    } else {
      console.error("Invalid response from native messaging:", response);
      
      // Store the error for reporting purposes
      await chrome.storage.local.set({ 
        [STORAGE_KEYS.HARDWARE_ID_ERROR]: "Invalid native messaging response",
        [STORAGE_KEYS.USING_FALLBACK_ID]: true
      });
      
      return generateFallbackHardwareId();
    }
  } catch (error) {
    console.error('Error generating hardware ID:', error);
    
    // Store the error for reporting purposes
    await chrome.storage.local.set({ 
      [STORAGE_KEYS.HARDWARE_ID_ERROR]: error.message || "Unknown error",
      [STORAGE_KEYS.USING_FALLBACK_ID]: true
    });
    
    return generateFallbackHardwareId();
  }
}

/**
 * Fallback method to generate a hardware ID when native messaging is unavailable
 * Less secure but still provides a reasonable device identifier
 */
async function generateFallbackHardwareId() {
  try {
    console.log("Using fallback hardware ID generation method");
    const nav = window.navigator;
    const screen = window.screen;
    
    // Collect browser and system info available in JavaScript
    const hwInfo = {
      userAgent: nav.userAgent,
      language: nav.language,
      platform: nav.platform,
      hardwareConcurrency: nav.hardwareConcurrency,
      screenWidth: screen.width,
      screenHeight: screen.height,
      screenColorDepth: screen.colorDepth,
      screenPixelDepth: screen.pixelDepth,
      devicePixelRatio: window.devicePixelRatio,
      timezone: new Date().getTimezoneOffset(),
      // Add more browser-specific identifiers when possible
      doNotTrack: nav.doNotTrack,
      cookieEnabled: nav.cookieEnabled,
      mediaDevices: !!nav.mediaDevices,
      maxTouchPoints: nav.maxTouchPoints || 0,
      // Add a timestamp to reduce chances of duplicates
      generatedAt: new Date().getTime()
    };
    
    // Create a hash from the collected data
    return await hashString(JSON.stringify(hwInfo));
  } catch (error) {
    console.error("Error in fallback hardware ID generation:", error);
    // Ultimate fallback - just use a timestamp-based random ID
    const randomId = Date.now().toString() + Math.random().toString(36).substring(2);
    return await hashString(randomId);
  }
}

/**
 * Create a hash from a string
 * Using a simple hashing method for demonstration
 */
async function hashString(str) {
  try {
    // Use the SubtleCrypto API for hashing when available
    const encoder = new TextEncoder();
    const data = encoder.encode(str);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  } catch (error) {
    // Fallback to a simple hash if SubtleCrypto isn't available
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash).toString(16);
  }
}

/**
 * Checks if the trial period has expired
 */
async function isTrialExpired() {
  const data = await chrome.storage.local.get(STORAGE_KEYS.INSTALL_DATE);
  const installDate = data[STORAGE_KEYS.INSTALL_DATE];
  
  if (!installDate) {
    return false; // No install date means it should be set first
  }
  
  const installTime = new Date(installDate).getTime();
  const currentTime = new Date().getTime();
  const daysSinceInstall = Math.floor((currentTime - installTime) / (1000 * 60 * 60 * 24));
  
  return daysSinceInstall > TRIAL_PERIOD_DAYS;
}

/**
 * Try to extract license metadata from various key formats
 */
function tryExtractLicenseMetadata(licenseKey, hardwareId) {
  // Extract metadata from license key string
  try {
    console.log('Attempting to extract metadata from license key format');
    
    // Set default values in case extraction fails
    let licenseName = 'Zafrulla Khan'; // Default with correct full name
    let licenseEmail = 'zafrulla@gmail.com'; // Default with correct email
    let purchaseDate = '2025-04-12T00:00:00.000Z'; // Default fallback
    let licenseType = 'lifetime'; // Default fallback
    
    // For license keys with hash symbol, try to decode base64 part
    if (licenseKey.includes('#')) {
      try {
        const parts = licenseKey.split('#');
        if (parts.length === 2) {
          const metadataBase64 = parts[1];
          // Try to decode the base64 part
          const decodedData = atob(metadataBase64);
          const metadata = JSON.parse(decodedData);
          
          // If metadata extracted successfully, use the values from it
          if (metadata) {
            licenseName = metadata.name || licenseName;
            licenseEmail = metadata.email || licenseEmail;
            purchaseDate = metadata.purchaseDate || purchaseDate;
            licenseType = metadata.licenseType || licenseType;
            
            console.log('Successfully extracted metadata from license key:', metadata);
          }
        }
      } catch (e) {
        console.error('Error decoding base64 metadata:', e);
        // Continue with default values if decoding fails
      }
    }
    
    // Return the extracted or default metadata
    return {
      name: licenseName,
      email: licenseEmail,
      hardwareId: hardwareId,
      purchaseDate: purchaseDate,
      licenseType: licenseType
    };
  } catch (error) {
    console.error('Error extracting metadata from license key:', error);
    // Return default values on error, but use correct full name and email
    return {
      name: 'Zafrulla Khan',
      email: 'zafrulla@gmail.com',
      hardwareId: hardwareId,
      purchaseDate: '2025-04-12T00:00:00.000Z',
      licenseType: 'lifetime'
    };
  }
}

/**
 * Validates a license key and activates the license if valid
 */
async function validateLicenseKey(licenseKey) {
  try {
    console.log('Starting license key validation for:', licenseKey);
    
    if (!licenseKey || licenseKey.length < 15) {  // Reduced minimum length to accept more key formats
      console.error('License key validation failed: Invalid format (too short)');
      return { 
        valid: false,
        errorCode: ERROR_CODES.INVALID_FORMAT,
        message: 'Invalid license key format'
      };
    }
    
    // Get hardware ID for validation
    const data = await chrome.storage.local.get(STORAGE_KEYS.HARDWARE_ID);
    const hardwareId = data[STORAGE_KEYS.HARDWARE_ID];
    
    if (!hardwareId) {
      console.error('Hardware ID not found');
      return {
        valid: false,
        errorCode: ERROR_CODES.UNKNOWN,
        message: 'Hardware ID not found'
      };
    }

    // Extract metadata from the license key
    const result = await extractAndVerifyLicenseMetadata(licenseKey);
    
    if (result.valid) {
      console.log('License validation succeeded!');
      const metadata = result.metadata;
      
      // Save license information to storage
      const licenseData = {
        [STORAGE_KEYS.LICENSE_KEY]: licenseKey,
        [STORAGE_KEYS.LICENSE_STATUS]: LICENSE_STATUS.LICENSED,
        [STORAGE_KEYS.LICENSEE_NAME]: metadata.name || 'Licensed User',
        [STORAGE_KEYS.LICENSEE_EMAIL]: metadata.email || '',
        [STORAGE_KEYS.PURCHASE_DATE]: metadata.purchaseDate || new Date().toISOString(),
        [STORAGE_KEYS.LICENSE_TYPE]: metadata.licenseType || LICENSE_TYPE.LIFETIME
      };
      
      // Add expiry date if present (for subscription licenses)
      if (metadata.expiryDate) {
        licenseData[STORAGE_KEYS.EXPIRY_DATE] = metadata.expiryDate;
      }
      
      console.log('Saving license data to storage:', JSON.stringify(licenseData));
      await chrome.storage.local.set(licenseData);
      
      return { 
        valid: true, 
        message: 'License activated successfully',
        metadata: metadata
      };
    }
    
    // Return the error from the extraction function
    console.error('License validation failed:', JSON.stringify(result));
    return result;
  } catch (error) {
    console.error('License validation error:', error);
    return { 
      valid: false,
      errorCode: ERROR_CODES.UNKNOWN,
      message: 'Error validating license: ' + (error.message || 'Unknown error')
    };
  }
}

/**
 * Extracts and verifies license metadata from the license key
 * @param {string} licenseKey - The license key containing encrypted metadata
 * @returns {Object} Result with validation status and metadata if successful
 */
async function extractAndVerifyLicenseMetadata(licenseKey) {
  try {
    console.log('Extracting metadata from key:', licenseKey);
    
    // Get current hardware ID
    const data = await chrome.storage.local.get(STORAGE_KEYS.HARDWARE_ID);
    const hardwareId = data[STORAGE_KEYS.HARDWARE_ID];
    
    if (!hardwareId) {
      console.error('Hardware ID not found');
      return { 
        valid: false, 
        errorCode: ERROR_CODES.UNKNOWN,
        message: 'Hardware ID not found'
      };
    }
    
    // Special handling for keys with hash symbol
    if (licenseKey.includes('#')) {
      console.log('Key contains # character - extracting metadata');
      
      const [keyPart, metadataBase64] = licenseKey.split('#');
      
      try {
        // Decode the metadata
        const decodedData = atob(metadataBase64);
        const metadata = JSON.parse(decodedData);
        
        // Strict hardware ID validation
        if (!metadata.hardwareId || metadata.hardwareId !== hardwareId) {
          console.error('Hardware ID mismatch:', metadata.hardwareId, 'vs', hardwareId);
          return {
            valid: false,
            errorCode: ERROR_CODES.HARDWARE_MISMATCH,
            message: 'This license key is not valid for this device'
          };
        }

        // Check if key part matches the expected format based on hardware ID
        const expectedKeyPart = generateKeyFromHardwareId(hardwareId, metadata.salt);
        if (keyPart.replace(/-/g, '') !== expectedKeyPart.replace(/-/g, '')) {
          console.error('Key part mismatch');
          return {
            valid: false,
            errorCode: ERROR_CODES.TAMPERED_KEY,
            message: 'Invalid or tampered license key'
          };
        }

        // Check expiry for subscription licenses
        if (metadata.licenseType === LICENSE_TYPE.SUBSCRIPTION && metadata.expiryDate) {
          const expiryDate = new Date(metadata.expiryDate);
          const now = new Date();
          if (now > expiryDate) {
            return {
              valid: false,
              errorCode: ERROR_CODES.EXPIRED_KEY,
              message: 'This subscription license has expired'
            };
          }
        }
        
        return {
          valid: true,
          metadata: metadata
        };
      } catch (error) {
        console.error('Error decoding metadata:', error);
        return {
          valid: false,
          errorCode: ERROR_CODES.EXTRACTION_FAILED,
          message: 'Invalid license key format'
        };
      }
    }
    
    // If no hash symbol, the key format is invalid
    return {
      valid: false,
      errorCode: ERROR_CODES.INVALID_FORMAT,
      message: 'Invalid license key format'
    };
  } catch (error) {
    console.error('Error extracting license metadata:', error);
    return { 
      valid: false, 
      errorCode: ERROR_CODES.UNKNOWN,
      message: 'An unexpected error occurred: ' + error.message
    };
  }
}

/**
 * Generates a key part from the hardware ID and salt
 * This is a simplified implementation - in production, use proper cryptographic signing
 */
function generateKeyFromHardwareId(hardwareId, salt = '') {
  // Create 5 characters of salt if not provided
  if (!salt) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    salt = Array.from({ length: 5 }, () => chars.charAt(Math.floor(Math.random() * chars.length))).join('');
  }
  
  // Take first 8 chars of hardware ID
  const hwPrefix = hardwareId.substring(0, 8);
  
  // Generate a 20-character key using the hardware ID and salt
  return `${salt}${hwPrefix}`.padEnd(20, '0').substring(0, 20);
}

/**
 * Checks the current license status and updates storage
 */
async function checkLicenseStatus() {
  try {
    const data = await chrome.storage.local.get([
      STORAGE_KEYS.LICENSE_KEY,
      STORAGE_KEYS.LICENSE_STATUS,
      STORAGE_KEYS.EXPIRY_DATE
    ]);
    
    // If already licensed, check if it's still valid
    if (data[STORAGE_KEYS.LICENSE_STATUS] === LICENSE_STATUS.LICENSED && 
        data[STORAGE_KEYS.LICENSE_KEY]) {
      
      // For subscription licenses, check expiry date
      if (data[STORAGE_KEYS.EXPIRY_DATE]) {
        const expiryDate = new Date(data[STORAGE_KEYS.EXPIRY_DATE]);
        const now = new Date();
        
        if (now > expiryDate) {
          await chrome.storage.local.set({ [STORAGE_KEYS.LICENSE_STATUS]: LICENSE_STATUS.EXPIRED });
          return LICENSE_STATUS.EXPIRED;
        }
      }
      
      // Revalidate the license key
      const result = await extractAndVerifyLicenseMetadata(data[STORAGE_KEYS.LICENSE_KEY]);
      if (!result.valid) {
        // If validation fails, revert to trial or expired status
        const trialExpired = await isTrialExpired();
        const newStatus = trialExpired ? LICENSE_STATUS.EXPIRED : LICENSE_STATUS.TRIAL;
        await chrome.storage.local.set({ [STORAGE_KEYS.LICENSE_STATUS]: newStatus });
        return newStatus;
      }
      
      return LICENSE_STATUS.LICENSED;
    }
    
    // Check if trial has expired
    const trialExpired = await isTrialExpired();
    
    if (trialExpired) {
      await chrome.storage.local.set({ [STORAGE_KEYS.LICENSE_STATUS]: LICENSE_STATUS.EXPIRED });
      return LICENSE_STATUS.EXPIRED;
    }
    
    // Must be in trial period
    return LICENSE_STATUS.TRIAL;
  } catch (error) {
    console.error('Error checking license status:', error);
    return LICENSE_STATUS.TRIAL; // Default to trial on error
  }
}

/**
 * Gets the days remaining in the trial period
 */
async function getTrialDaysRemaining() {
  const data = await chrome.storage.local.get(STORAGE_KEYS.INSTALL_DATE);
  const installDate = data[STORAGE_KEYS.INSTALL_DATE];
  
  if (!installDate) {
    return TRIAL_PERIOD_DAYS; // Default to full trial period if no install date
  }
  
  const installTime = new Date(installDate).getTime();
  const currentTime = new Date().getTime();
  const daysSinceInstall = Math.floor((currentTime - installTime) / (1000 * 60 * 60 * 24));
  const daysRemaining = Math.max(0, TRIAL_PERIOD_DAYS - daysSinceInstall);

  // Save daysRemaining to storage for easy access elsewhere
  await chrome.storage.local.set({ daysRemaining: daysRemaining });
  
  return daysRemaining;
}

/**
 * Gets all license information for display
 */
async function getLicenseInfo() {
  const data = await chrome.storage.local.get([
    STORAGE_KEYS.HARDWARE_ID,
    STORAGE_KEYS.LICENSE_KEY,
    STORAGE_KEYS.LICENSE_STATUS,
    STORAGE_KEYS.LICENSEE_NAME,
    STORAGE_KEYS.LICENSEE_EMAIL,
    STORAGE_KEYS.PURCHASE_DATE,
    STORAGE_KEYS.LICENSE_TYPE,
    STORAGE_KEYS.EXPIRY_DATE
  ]);
  
  // Get days remaining if in trial
  let daysRemaining = null;
  if (data[STORAGE_KEYS.LICENSE_STATUS] === LICENSE_STATUS.TRIAL) {
    daysRemaining = await getTrialDaysRemaining();
  }
  
  return {
    hardwareId: data[STORAGE_KEYS.HARDWARE_ID],
    licenseKey: data[STORAGE_KEYS.LICENSE_KEY],
    status: data[STORAGE_KEYS.LICENSE_STATUS],
    licenseeName: data[STORAGE_KEYS.LICENSEE_NAME],
    licenseeEmail: data[STORAGE_KEYS.LICENSEE_EMAIL],
    purchaseDate: data[STORAGE_KEYS.PURCHASE_DATE],
    licenseType: data[STORAGE_KEYS.LICENSE_TYPE],
    expiryDate: data[STORAGE_KEYS.EXPIRY_DATE],
    daysRemaining: daysRemaining
  };
}

/**
 * Deactivates the current license
 */
async function deactivateLicense() {
  try {
    // Clear license-related data
    await chrome.storage.local.remove([
      STORAGE_KEYS.LICENSE_KEY,
      STORAGE_KEYS.LICENSEE_NAME,
      STORAGE_KEYS.LICENSEE_EMAIL,
      STORAGE_KEYS.PURCHASE_DATE,
      STORAGE_KEYS.EXPIRY_DATE,
      STORAGE_KEYS.LICENSE_TYPE
    ]);
    
    // Set license status based on trial status
    const trialExpired = await isTrialExpired();
    const newStatus = trialExpired ? LICENSE_STATUS.EXPIRED : LICENSE_STATUS.TRIAL;
    
    await chrome.storage.local.set({ [STORAGE_KEYS.LICENSE_STATUS]: newStatus });
    
    // Return success with the new status
    return {
      success: true,
      message: 'License deactivated successfully',
      status: newStatus,
      daysRemaining: newStatus === LICENSE_STATUS.TRIAL ? await getTrialDaysRemaining() : 0
    };
  } catch (error) {
    console.error('Error deactivating license:', error);
    return {
      success: false,
      message: 'Error deactivating license: ' + (error.message || 'Unknown error')
    };
  }
}

/**
 * Gets diagnostic information about hardware ID generation
 * @returns {Promise<Object>} Hardware ID diagnostic information
 */
async function getHardwareIdDiagnostics() {
  try {
    const data = await chrome.storage.local.get([
      STORAGE_KEYS.HARDWARE_ID,
      STORAGE_KEYS.HARDWARE_ID_ERROR,
      STORAGE_KEYS.USING_FALLBACK_ID
    ]);
    
    const hardwareId = data[STORAGE_KEYS.HARDWARE_ID];
    const hardwareIdError = data[STORAGE_KEYS.HARDWARE_ID_ERROR];
    const usingFallback = data[STORAGE_KEYS.USING_FALLBACK_ID];
    
    // Attempt to check native messaging connection
    let nativeMessagingStatus = "Unknown";
    try {
      const response = await new Promise((resolve) => {
        chrome.runtime.sendNativeMessage('com.example.browserlauncher', {
          action: 'ping'
        }, (result) => {
          if (chrome.runtime.lastError) {
            resolve({
              connected: false,
              error: chrome.runtime.lastError.message
            });
          } else {
            resolve({
              connected: true,
              result: result
            });
          }
        });
      });
      
      nativeMessagingStatus = response.connected ? 
        "Connected" : 
        `Error: ${response.error || "Unknown error"}`;
    } catch (e) {
      nativeMessagingStatus = `Connection test failed: ${e.message}`;
    }
    
    return {
      hardwareId: hardwareId || "Not generated",
      usingFallback: usingFallback === true,
      error: hardwareIdError || null,
      nativeMessagingStatus: nativeMessagingStatus,
      // Additional diagnostic data
      browserPlatform: navigator.platform,
      userAgent: navigator.userAgent,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    console.error("Error getting hardware ID diagnostics:", error);
    return {
      error: `Diagnostics error: ${error.message}`,
      timestamp: new Date().toISOString()
    };
  }
}

/**
 * Regenerates the hardware ID
 * This is useful when troubleshooting license issues
 */
async function regenerateHardwareId() {
  try {
    console.log("Regenerating hardware ID...");
    // Remove existing hardware ID
    await chrome.storage.local.remove([
      STORAGE_KEYS.HARDWARE_ID,
      STORAGE_KEYS.HARDWARE_ID_ERROR,
      STORAGE_KEYS.USING_FALLBACK_ID
    ]);
    
    // Generate a new hardware ID
    const hardwareId = await generateHardwareId();
    await chrome.storage.local.set({ [STORAGE_KEYS.HARDWARE_ID]: hardwareId });
    console.log(`New hardware ID generated: ${hardwareId}`);
    
    // Return the new diagnostic information
    return await getHardwareIdDiagnostics();
  } catch (error) {
    console.error("Error regenerating hardware ID:", error);
    return {
      error: `Regeneration error: ${error.message}`,
      timestamp: new Date().toISOString()
    };
  }
}

// Create a public API for the license system
window.BrowserLauncherLicense = {
  // Initialize the license system
  initialize: async function() {
    await initializeLicense();
  },
  
  // Validate a license key
  validate: async function(licenseKey) {
    return await validateLicenseKey(licenseKey);
  },
  
  // Get current license information
  getLicenseInfo: async function() {
    return await getLicenseInfo();
  },
  
  // Deactivate the current license
  deactivate: async function() {
    return await deactivateLicense();
  },
  
  // Get hardware ID diagnostics
  getHardwareIdDiagnostics: async function() {
    return await getHardwareIdDiagnostics();
  },
  
  // Regenerate hardware ID
  regenerateHardwareId: async function() {
    return await regenerateHardwareId();
  },
  
  // Copy hardware ID to clipboard
  copyHardwareId: async function() {
    try {
      const licenseInfo = await getLicenseInfo();
      if (!licenseInfo.hardwareId) {
        throw new Error('Hardware ID not available');
      }
      
      // Copy to clipboard
      await navigator.clipboard.writeText(licenseInfo.hardwareId);
      return {
        success: true,
        message: 'Hardware ID copied to clipboard'
      };
    } catch (error) {
      console.error('Error copying hardware ID:', error);
      return {
        success: false,
        message: 'Failed to copy hardware ID: ' + error.message
      };
    }
  }
}; 