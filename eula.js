document.addEventListener('DOMContentLoaded', function() {
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
  
  