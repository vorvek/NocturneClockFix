@echo off
rem Removes the Nocturne Clock Fix from nocturne.exe in this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0NocturneClockFix.ps1" -Undo %*
pause
