# Custom Browsers - Quick Reference

## Quick Start (3 Steps)

1. **Settings Tab** → Scroll to "Custom Browsers" → Click "Add Browser"
2. **Fill in Details**:
   - Name: Your browser name
   - Platform: Windows or WSL Linux
   - Path: Full path to browser executable
   - Icon: Emoji (optional)
3. **Click "Save Custom Browsers"** → Done!

## Common Browser Paths

### Windows
```
Vivaldi:  C:\Users\[Username]\AppData\Local\Vivaldi\Application\vivaldi.exe
Brave:    C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe
Opera:    C:\Users\[Username]\AppData\Local\Programs\Opera\opera.exe
Arc:      C:\Users\[Username]\AppData\Local\Arc\Application\arc.exe
```

### WSL Linux
```
Vivaldi:   /usr/bin/vivaldi
Brave:     /usr/bin/brave-browser
Chromium:  /usr/bin/chromium-browser
Opera:     /usr/bin/opera
```

## Where Custom Browsers Appear

✅ **Windows Local Tab** - Custom Windows browsers section
✅ **WSL Ubuntu Linux Tab** - Custom WSL browsers section  
✅ **Right-Click Menu** - On any link or page
✅ **Context Menu Options**:
   - Open in Normal Window
   - Open in InPrivate Window

## Tips

💡 **Finding Browser Path (Windows)**:
   - Right-click browser shortcut → Properties → Target

💡 **Finding Browser Path (WSL)**:
   - Run: `which browser-name` (e.g., `which brave-browser`)

💡 **Icons**: Use emojis! 🔴 🦁 🌐 🔥 ⚡ 🎯 🚀

💡 **Testing**: Launch from main tab first before using in context menu

## Troubleshooting

❌ **Browser won't launch?**
   → Check path is correct
   → Test path in Command Prompt/Terminal

❌ **Not showing in menu?**
   → Make sure "Enabled" is checked
   → Click "Save Custom Browsers"

❌ **Wrong platform?**
   → Windows browsers need .exe paths
   → WSL browsers need Linux paths (/usr/bin/...)

## Example Configurations

### Vivaldi (Windows)
```
Name: Vivaldi
Platform: Windows
Path: C:\Users\YourName\AppData\Local\Vivaldi\Application\vivaldi.exe
Icon: 🔴
```

### Brave (WSL)
```
Name: Brave
Platform: WSL Linux
Path: /usr/bin/brave-browser
Icon: 🦁
```

---
**Need more help?** See CUSTOM_BROWSERS_GUIDE.md for detailed documentation.
