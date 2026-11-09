@echo off
:: Double-click to remove CleanTemp and its shortcuts.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
pause
