// Ensure error messages are properly displayed
window.addEventListener('error', function(event) {
  console.error('Error caught:', event.error);
  const licenseMessageEl = document.getElementById('licenseMessage');
  if (licenseMessageEl) {
    licenseMessageEl.textContent = 'Error: ' + (event.error?.message || 'Unknown error');
    licenseMessageEl.className = 'license-message message-error';
    licenseMessageEl.style.display = 'block';
  }
}); 