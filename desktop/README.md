# EchoType Desktop MVP

This is the Windows desktop MVP for EchoType.

## What it does

- Runs as a small Windows app
- Registers a global hotkey and lets you change it
- Triggers Windows voice typing in the active app
- Works outside the browser because it uses the system voice typing layer
- Fits the real high-frequency use case: chat apps, AI tools, notes, and web forms
- Can hide to the system tray and keep running in the background

## How to run

1. Open [EchoTypeSetup.exe](C:\Users\Administrator\Documents\网站运营\desktop\EchoTypeSetup.exe:1)
2. Install EchoType into your user profile
3. Launch EchoType from the installer, desktop shortcut, or Start menu shortcut
4. Leave the EchoType window running
5. Click into any target input field
6. Press your chosen global hotkey
7. Windows voice typing opens in that target app
8. Speak directly into that input field

## Files

- Installer: [EchoTypeSetup.exe](C:\Users\Administrator\Documents\网站运营\desktop\EchoTypeSetup.exe:1)
- Main app: [EchoType.exe](C:\Users\Administrator\Documents\网站运营\desktop\EchoType.exe:1)
- Source: [EchoTypeLauncher.cs](C:\Users\Administrator\Documents\网站运营\desktop\EchoTypeLauncher.cs:1)
- Installer source: [EchoTypeInstaller.cs](C:\Users\Administrator\Documents\网站运营\desktop\EchoTypeInstaller.cs:1)
- Fallback script version: [EchoType.ps1](C:\Users\Administrator\Documents\网站运营\desktop\EchoType.ps1:1)
- Smart launcher: [Run-EchoType.bat](C:\Users\Administrator\Documents\网站运营\desktop\Run-EchoType.bat:1)

## New in this version

- Real single-file installer `.exe`
- Real compiled `.exe` launcher
- `Hide to tray` button
- Tray icon with `Open EchoType`, `Trigger voice typing`, and `Exit`
- Custom hotkey controls with saved settings in `desktop/config.json`

## Current language support

The desktop MVP follows Windows voice typing and your current Windows input language.

That means:

- switch the Windows input language to change dictation language
- install more Windows language packs to unlock more languages
- the app itself does not hard-limit you to a tiny dropdown

## Notes

- The web page is still a demo and landing page.
- The desktop app is the actual route to system-wide input.
- This MVP intentionally uses Windows' native voice typing because that is the fastest stable way to get cross-app input working.
- If another app already uses your chosen hotkey, EchoType will warn you and you should pick another one.
