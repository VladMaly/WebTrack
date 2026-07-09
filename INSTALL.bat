@echo off
setlocal
title WebTrack - Install
echo.
echo  Setting up WebTrack... follow the popup window.
echo.

if not exist "%~dp0Watch-Stock.ps1" (
    echo  ERROR: Setup files were not found next to this installer.
    echo.
    echo  If you are looking at this inside a ZIP file, please
    echo  EXTRACT the whole ZIP first: right-click the ZIP,
    echo  choose "Extract All", then double-click INSTALL.bat
    echo  inside the extracted folder.
    echo.
    pause
    exit /b 1
)

set "DEST=%LOCALAPPDATA%\WebTrack"
if not exist "%DEST%" mkdir "%DEST%"
copy /y "%~dp0Watch-Stock.ps1"    "%DEST%" >nul
copy /y "%~dp0Setup-Wizard.ps1"   "%DEST%" >nul
copy /y "%~dp0Install-Task.ps1"   "%DEST%" >nul
copy /y "%~dp0Uninstall-Task.ps1" "%DEST%" >nul
copy /y "%~dp0run-hidden.vbs"     "%DEST%" >nul
copy /y "%~dp0INSTALL.bat"        "%DEST%" >nul
copy /y "%~dp0UNINSTALL.bat"      "%DEST%" >nul

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%DEST%\Setup-Wizard.ps1"
if errorlevel 1 (
    echo.
    echo  Setup did not finish. Please send a photo of this window
    echo  to whoever gave you WebTrack.
    echo.
    pause
    exit /b 1
)
exit /b 0
