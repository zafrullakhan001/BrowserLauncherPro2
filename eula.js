document.addEventListener('DOMContentLoaded', function() {
    // Initialize i18n system first
    if (window.i18n) {
      window.i18n.initialize();
      
      // Initialize language selector
      initializeEulaLanguageSelector();
    }
    
    const eulaCheckbox = document.getElementById('eula-checkbox');
    const acceptEulaButton = document.getElementById('accept-eula');
  
    eulaCheckbox.addEventListener('change', function() {
      acceptEulaButton.disabled = !this.checked;
    });
  
    acceptEulaButton.addEventListener('click', function() {
      chrome.storage.local.set({ eulaAccepted: true }, function() {
        alert('Thank you for accepting the EULA.');
        window.close();
      });
    });
});

// Initialize language selector for EULA page
function initializeEulaLanguageSelector() {
  // Wait a bit for i18n to be fully loaded
  setTimeout(function() {
    if (window.i18n) {
      const eulaLanguageSelect = document.getElementById('eula-language-select');
      
      if (eulaLanguageSelect) {
        // Clear and populate manually
        eulaLanguageSelect.innerHTML = '';
        
        const languages = {
          'en': '[US] English',
          'fr': '[FR] French',
          'es': '[ES] Spanish',
          'de': '[DE] German',
          'it': '[IT] Italian',
          'pt': '[PT] Portuguese',
          'ru': '[RU] Russian',
          'zh': '[CN] Chinese',
          'ja': '[JP] Japanese',
          'ko': '[KR] Korean',
          'ar': '[SA] Arabic',
          'hi': '[IN] Hindi',
          'tr': '[TR] Turkish',
          'nl': '[NL] Dutch'
        };
        
        // Add options
        Object.entries(languages).forEach(([code, name]) => {
          const option = document.createElement('option');
          option.value = code;
          option.textContent = name;
          eulaLanguageSelect.appendChild(option);
        });
        
        // Set current language
        try {
          const currentLang = window.i18n.getCurrentLanguage();
          eulaLanguageSelect.value = currentLang;
        } catch (e) {
          eulaLanguageSelect.value = 'en';
        }
        
        // Handle language change
        eulaLanguageSelect.addEventListener('change', function() {
          if (window.i18n && window.i18n.setLanguage) {
            window.i18n.setLanguage(this.value);
          }
        });
      }
    }
  }, 100); // Small delay to ensure i18n is loaded
}
  
  