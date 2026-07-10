@echo off
rem Thin launcher: starts the real setup HIDDEN (no lingering console window).
rem All feedback happens in the browser setup page or small popups.
set "BOOT=%~dp0app\Setup-Bootstrap.ps1"
if not exist "%BOOT%" set "BOOT=%~dp0Setup-Bootstrap.ps1"
rem strip the trailing backslash so -Source isn't corrupted by \" quoting
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
set "URLARG="
if not "%~1"=="" set "URLARG=-Url "%~1""
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%BOOT%" -Source "%HERE%" %URLARG%
exit
