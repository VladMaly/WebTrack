@echo off
setlocal
title WebTrack - Install
echo.
echo  Setting up WebTrack... follow the popup window.
echo.

rem program files live in app\ next to this installer, or flat when this
rem copy of _INSTALL.bat is already the installed one in %LOCALAPPDATA%
set "SRC=%~dp0app"
if not exist "%SRC%\Watch-Stock.ps1" set "SRC=%~dp0"
if not exist "%SRC%\Watch-Stock.ps1" (
    echo  ERROR: Setup files were not found next to this installer.
    echo.
    echo  If you are looking at this inside a ZIP file, please
    echo  EXTRACT the whole ZIP first: right-click the ZIP,
    echo  choose "Extract All", then double-click _INSTALL.bat
    echo  inside the extracted folder.
    echo.
    pause
    exit /b 1
)

set "DEST=%LOCALAPPDATA%\WebTrack"
if not exist "%DEST%" mkdir "%DEST%"
if /i "%~dp0"=="%DEST%\" goto :wizard

copy /y "%SRC%\Watch-Stock.ps1"    "%DEST%" >nul
copy /y "%SRC%\Setup-Wizard.ps1"   "%DEST%" >nul
copy /y "%SRC%\Install-Task.ps1"   "%DEST%" >nul
copy /y "%SRC%\Uninstall-Task.ps1" "%DEST%" >nul
copy /y "%SRC%\Uninstall-Quiet.ps1" "%DEST%" >nul
copy /y "%SRC%\run-hidden.vbs"     "%DEST%" >nul
copy /y "%~dp0_INSTALL.bat"        "%DEST%" >nul
copy /y "%~dp0_UNINSTALL.bat"      "%DEST%" >nul

:wizard
set "URLARG="
if not "%~1"=="" set "URLARG=-Url "%~1""
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%DEST%\Setup-Wizard.ps1" %URLARG%
if errorlevel 1 (
    echo.
    echo  Setup did not finish. Please send a photo of this window
    echo  to whoever gave you WebTrack.
    echo.
    pause
    exit /b 1
)
exit /b 0
