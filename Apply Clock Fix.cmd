@echo off
rem Applies the Nocturne Clock Fix to nocturne.exe in this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0NocturneClockFix.ps1" %*
pause
