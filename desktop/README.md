# EchoType Desktop MVP

This is the Windows desktop MVP for EchoType.

## What it does

- Runs as a small Windows app
- Registers a global hotkey: `Ctrl + Shift + Space`
- Triggers Windows voice typing in the active app
- Works outside the browser because it uses the system voice typing layer
- Fits the real high-frequency use case: chat apps, AI tools, notes, and web forms

## How to run

1. Open [Run-EchoType.bat](C:\Users\Administrator\Documents\网站运营\desktop\Run-EchoType.bat:1)
2. Leave the EchoType window running
3. Click into any target input field
4. Press `Ctrl + Shift + Space`
5. Windows voice typing opens in that target app
6. Speak directly into that input field

## Current language support

The desktop MVP follows Windows voice typing and your current Windows input language.

That means:

- switch the Windows input language to change dictation language
- install more Windows language packs to unlock more languages
- the app itself does not hard-limit you to a tiny dropdown

## Notes

- The web page is still a demo and landing page.
- The desktop script is the actual route to system-wide input.
- This MVP intentionally uses Windows' native voice typing because that is the fastest stable way to get cross-app input working.
- If another app already uses `Ctrl + Shift + Space`, the hotkey registration will fail until you close or remap that app.
