@echo off
if exist "%~dp0EchoType.exe" (
  start "" "%~dp0EchoType.exe"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0EchoType.ps1"
)
