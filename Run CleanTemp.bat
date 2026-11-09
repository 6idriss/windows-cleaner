@echo off
:: Double-click to run 007 Clean Temp once without installing.
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0CleanTemp.ps1"
