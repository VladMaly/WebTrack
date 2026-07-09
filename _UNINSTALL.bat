@echo off
setlocal
title WebTrack - Uninstall
echo.
echo  Removing the WebTrack background watcher...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Unregister-ScheduledTask -TaskName 'WebTrack Stock Watcher' -Confirm:$false -ErrorAction Stop; Write-Host '  Background task removed.' } catch { Write-Host '  No watcher task found - nothing to remove.' }"

rd /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\WebTrack" 2>nul

set "DEST=%LOCALAPPDATA%\WebTrack"
if /i not "%~dp0"=="%DEST%\" (
    if exist "%DEST%" (
        rd /s /q "%DEST%"
        echo  Installed files deleted.
    )
) else (
    echo  You can also delete this folder if you want:
    echo  %DEST%
)
echo.
echo  WebTrack is uninstalled. No more checks, no more alerts.
echo.
pause
