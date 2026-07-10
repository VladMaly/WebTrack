@echo off
rem Thin launcher: runs the uninstall HIDDEN (no console window). It removes the
rem background task, Start Menu entries, registry keys and installed files, then
rem shows a "WebTrack is uninstalled" notification.
set "Q=%~dp0Uninstall-Quiet.ps1"
if not exist "%Q%" set "Q=%~dp0app\Uninstall-Quiet.ps1"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%Q%"
exit
