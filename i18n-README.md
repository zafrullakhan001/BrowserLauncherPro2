# Browser Launcher Pro - Internationalization (i18n)

## Overview

Browser Launcher Pro now supports multiple languages popular in the USA, Canada, Europe, Middle East, and China. The extension automatically detects your browser's language preference and applies the appropriate translation.

## Supported Languages

### Americas
- 🇺🇸 **English** - Default language
- 🇪🇸 **Spanish (Español)** - Popular in USA and Europe
- 🇫🇷 **French (Français)** - Canada and Europe
- 🇵🇹 **Portuguese (Português)** - Europe and Americas

### Europe
- 🇩🇪 **German (Deutsch)** - Germany, Austria, Switzerland
- 🇮🇹 **Italian (Italiano)** - Italy, Switzerland
- 🇳🇱 **Dutch (Nederlands)** - Netherlands, Belgium
- 🇵🇱 **Polish (Polski)** - Poland
- 🇷🇺 **Russian (Русский)** - Russia, Eastern Europe

### Middle East
- 🇸🇦 **Arabic (العربية)** - Middle East and North Africa
- 🇮🇱 **Hebrew (עברית)** - Israel
- 🇮🇷 **Persian/Farsi (فارسی)** - Iran, Afghanistan
- 🇹🇷 **Turkish (Türkçe)** - Turkey

### Asia-Pacific
- 🇨🇳 **Chinese Simplified (简体中文)** - Mainland China
- 🇹🇼 **Chinese Traditional (繁體中文)** - Taiwan, Hong Kong
- 🇯🇵 **Japanese (日本語)** - Japan
- 🇰🇷 **Korean (한국어)** - South Korea

## Features

### Automatic Language Detection
- The extension automatically detects your browser's language preference
- Falls back to English if your language is not supported
- Saves your language preference for future use

### Real-time Language Switching
- Change languages instantly from the header dropdown or settings
- All UI elements update immediately
- No need to restart the extension

### RTL Language Support
- Full support for right-to-left languages (Arabic, Hebrew, Persian)
- Automatic text direction and layout adjustments
- Proper icon and button alignment for RTL languages

### Comprehensive Translation Coverage
- All user interface elements are translated
- Browser names, settings, error messages, and help text
- Context menus and notifications in your selected language

## How to Use

### Changing Language
1. **Header Dropdown**: Click the language selector in the extension header
2. **Settings Tab**: Go to Settings → General Settings → Language
3. **Auto-Detection**: The extension will automatically use your browser's language

### Language Selection Options
Languages are organized by region for easy selection:
- **Global**: English (default)
- **Europe**: German, French, Italian, Dutch, Polish, Russian, etc.
- **Middle East**: Arabic, Hebrew, Persian, Turkish
- **China**: Simplified and Traditional Chinese
- **Asia**: Japanese, Korean

## Technical Implementation

### File Structure
```
Browser Launcher Pro/
├── js/
│   └── i18n.js              # Internationalization engine
├── popup.html               # Main UI with i18n attributes
├── popup.js                 # Updated with i18n integration
├── custom.css               # RTL and language-specific styles
└── language-demo.html       # Demo page showing all languages
```

### Translation Keys
All UI elements use translation keys in the format:
```html
<span data-i18n="section.element">Default English Text</span>
```

Examples:
- `header.title` → "Browser Launcher Pro"
- `settings.language` → "Language" / "Idioma" / "Langue" / etc.
- `browsers.stable` → "Stable" / "Estable" / "Stable" / etc.

### Adding New Languages

To add a new language:

1. **Add Language Info** in `js/i18n.js`:
```javascript
'xx': { 
  name: 'Language Name', 
  nativeName: 'Native Name', 
  region: 'Region', 
  flag: '🏴' 
}
```

2. **Add Translations**:
```javascript
'xx': {
  'header.title': 'Translated Title',
  'settings.language': 'Translated Language',
  // ... more translations
}
```

3. **Test RTL Support** (if applicable):
Update RTL language list in `isRTLLanguage()` function.

## Browser Compatibility

### Supported Browsers
- ✅ Google Chrome (all versions)
- ✅ Microsoft Edge (all versions)
- ✅ Firefox (with WebExtensions API)
- ✅ Opera (Chromium-based)
- ✅ Brave Browser

### Language Detection
The extension uses the browser's `navigator.language` property to detect:
- Primary language preference
- Region-specific variants (e.g., en-US, en-GB)
- Fallback language chains

## Accessibility Features

### Screen Reader Support
- All translated text maintains semantic meaning
- ARIA labels are properly translated
- Language changes are announced to screen readers

### Keyboard Navigation
- Language selector is fully keyboard accessible
- Tab order is maintained in all languages
- Shortcuts work consistently across languages

### High Contrast Support
- All languages work with high contrast themes
- Font rendering optimized for each script
- Icon alignment preserved in RTL languages

## Performance

### Optimization Features
- Translation strings are loaded only once
- Minimal memory footprint per language
- Fast language switching (< 100ms)
- No external translation services required

### Storage Usage
- Language preference: ~10 bytes
- Translation data: ~50KB for all languages
- Cached in browser's local storage

## Troubleshooting

### Common Issues

**Language not applying:**
- Clear extension data and restart
- Check if browser language is supported
- Manually select language from settings

**RTL layout issues:**
- Refresh the extension popup
- Check browser's CSS support for RTL
- Try switching themes (dark/light)

**Missing translations:**
- Some text might fallback to English
- Report missing translations on GitHub
- Partial translations are normal for new languages

### Debug Mode
Enable debug logging in browser console:
```javascript
// In browser console
localStorage.setItem('i18n-debug', 'true');
```

## Contributing Translations

We welcome contributions for new languages or improvements to existing translations:

1. **Fork the repository**
2. **Add your language** to `js/i18n.js`
3. **Translate all keys** in the TRANSLATIONS object
4. **Test your translations** using the demo page
5. **Submit a pull request**

### Translation Guidelines
- Keep translations concise and clear
- Maintain the same tone as English version
- Test with actual users if possible
- Consider cultural context and conventions
- Preserve technical terms where appropriate

### Quality Assurance
- Native speaker review preferred
- Technical accuracy verification
- UI layout testing in target language
- Cross-platform compatibility check

## Future Enhancements

### Planned Features
- **Automatic Updates**: Pull latest translations from server
- **Community Translations**: User-contributed translation platform
- **Voice Commands**: Language-specific voice control
- **Localized Help**: Language-specific documentation
- **Cultural Adaptations**: Region-specific browser preferences

### Version History
- **v3.0**: Initial i18n implementation with 17 languages
- **v3.1**: Planned RTL improvements and additional languages
- **v3.2**: Planned community translation platform

## Contact & Support

For language-related issues or translation requests:
- **GitHub Issues**: Report bugs or request languages
- **Email**: support@browserlauncherpro.com
- **Community**: GitHub Discussions for translation help

---

*Browser Launcher Pro supports developers worldwide with native language interfaces. We believe technology should speak your language.* 🌍