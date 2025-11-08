## Browser Launcher Pro — Copilot instructions

This file gives succinct, actionable context for an AI coding agent to be productive in this repo.

Overview
- This project is a browser extension (Manifest V3) + native messaging host. Extension UI & logic live in `manifest.json`, `background.js`, `content.js`, `popup.*` and `license.*` files. The native host is `native_messaging.py` (packaged with `native_messaging.spec`). Installers and helpers are PowerShell scripts under the repo root and `scripts/` / `wslscripts/`.

Big-picture data flows
- The extension calls chrome.runtime.sendNativeMessage with host id `com.example.browserlauncher`. Example messages observed in `background.js`:
  - Get browser version: {"action":"getBrowserVersion","registryKey":"HKEY_CURRENT_USER\\Software\\Google\\Chrome\\BLBeacon"}
  - Open in sandbox: {"action":"openInSandbox","url":"https://example.com"}
  - Execute PowerShell: {"action":"executePowerShellScript","scriptPath":"<path>"}
- The native host reads/writes a 4-byte length then JSON (see `native_messaging.py` / `test_native_messaging.py`). When responding, it returns JSON objects (examples: {"version":"xx.x.x.x"}, {"result":"..."} or direct hardware info objects for `getHardwareInfo`).

Key integration points & files
- `manifest.json` — extension permissions (nativeMessaging, contextMenus, storage, alarms). Use this to understand required permissions.
- `background.js` — core extension logic, context menu creation, license/trial flow, sends messages to the native host. Refer to this file for expected message shapes and actions.
- `content.js` — small content-script used to return selected text to the background worker.
- `native_messaging.py` — native host. Implements actions: `getBrowserVersion`, `openInSandbox`, `runCommand`, `executePowerShellScript`, `getWSLInstances`, `getHardwareInfo`, `ping`. It logs to `BrowserLauncher.log` and `BrowserPathDetection.log`.
- `native_messaging.spec` — PyInstaller spec to build the native host executable.
- `com.example.browserlauncher.json` — native host manifest (register with registry). Tests/scripts reference this when installing the host.
- `test_native_messaging.py` — simple integration test harness used to exercise native host (run locally during development).
- `scripts/` and `wslscripts/` — many PowerShell & shell helpers (FixNativeMessagingHost.ps1, FindBrowserPaths.ps1, WSL helpers). Use these to register host manifests and install dependencies.

Developer workflows (how to run/build/test)
- Run tests / exercise native host locally (Windows):
  - Ensure Python 3 is in PATH.
  - Run: `python test_native_messaging.py` — this runs registry checks and spins up `native_messaging.py`.
- Build native host executable (Windows):
  - Install PyInstaller in the active Python environment.
  - Run: `pyinstaller native_messaging.spec` (the repo provides `native_messaging.spec`). The result is an executable that can be registered via the manifest.
- Register native messaging host & extension for local dev:
  - Use `scripts/FixNativeMessagingHost.ps1` or `Install-BrowserLauncher.ps1` to register the `com.example.browserlauncher` host in the registry (HKCU/HKLM as appropriate).
  - Load the unpacked extension in Edge/Chrome from the repo folder (Extensions → Load unpacked). The extension expects the native host to be registered.

Project-specific conventions and patterns
- Messaging: two modes accepted by native host: messages with an `action` key (strings listed above) or a `command` string. Validate shapes per `native_messaging.py::validate_input`.
- Logging: native host uses rotating file logs in repo working directory. Tests read `BrowserLauncher.log` (see `test_native_messaging.py`). Keep log output stable for test assertions.
- PowerShell-first tooling: installers, registry fixes and environment setup are implemented as `.ps1` scripts in the repo root and `scripts/`. When adding tooling prefer PowerShell on Windows.
- WSL handling: WSL commands are passed as `wsl -d <distro> ...` by `background.js`; native host has special handling for `wsl` in `run_command_with_url` and returns lists via `getWSLInstances`.
- License format: license keys are split on `#` and the second part is base64 JSON metadata (see `background.js` and `license_generator.py`). Do not change the split/metadata semantics without updating both generator and validator.

Small examples (copy/paste-ready)
- Example getBrowserVersion message:
  {"action":"getBrowserVersion","registryKey":"HKEY_CURRENT_USER\\Software\\Microsoft\\Edge\\BLBeacon"}
- Example runCommand message (invoked from background.js):
  {"command":"\"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe\" \"https://example.com\""}

When editing code
- If you change message shapes, update `background.js`, `native_messaging.py::validate_input`, and `test_native_messaging.py` together. Search for the action string in both places.
- Preserve the native host name `com.example.browserlauncher` unless intentionally changing the host registration flow; many scripts/tests assume it.

Where to look first if you need more context
- `background.js` — extension behavior and action names.
- `native_messaging.py` — authoritative list of actions, validation, and command/WSL/sandbox handling.
- `test_native_messaging.py` — example harness and how messages are packed/unpacked.
- `scripts/FixNativeMessagingHost.ps1`, `Install-BrowserLauncher.ps1` — registration and install flows.

If something's unclear
- Tell me which area you want more detail on (message shape, packaging native host, test failure logs, or installer behaviour) and I will expand this file with examples or add a short checklist for reproducing failures locally.

---
Please review for missing integration details or other files you want included.
