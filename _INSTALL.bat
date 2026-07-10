@echo off
setlocal
title WebTrack - Install
echo.
echo  Setting up WebTrack... a setup page will open in your browser.
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
copy /y "%SRC%\Setup-Web.ps1"      "%DEST%" >nul
copy /y "%SRC%\Setup-Wizard.ps1"   "%DEST%" >nul
copy /y "%SRC%\Install-Task.ps1"   "%DEST%" >nul
copy /y "%SRC%\Uninstall-Task.ps1" "%DEST%" >nul
copy /y "%SRC%\Uninstall-Quiet.ps1" "%DEST%" >nul
copy /y "%SRC%\run-hidden.vbs"     "%DEST%" >nul
copy /y "%~dp0_INSTALL.bat"        "%DEST%" >nul
copy /y "%~dp0_UNINSTALL.bat"      "%DEST%" >nul

:wizard
rem A link on the command line = silent install (no UI), straight to the wizard.
if not "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%DEST%\Setup-Wizard.ps1" -Url "%~1"
    if errorlevel 1 goto :failed
    exit /b 0
)

rem Normal run: modern setup page in a clean browser window.
rem   exit 0 = installed;  2 = opened but not finished;  1/3 = couldn't open -> classic popup.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\Setup-Web.ps1"
if errorlevel 3 goto :webfallback
if errorlevel 2 goto :abandoned
if errorlevel 1 goto :webfallback
exit /b 0

:abandoned
echo.
echo  Setup was closed before it finished - run _INSTALL.bat again when you're ready.
echo.
pause
exit /b 1

:webfallback
echo  Opening the classic setup window instead...
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%DEST%\Setup-Wizard.ps1"
if errorlevel 1 goto :failed
exit /b 0

:failed
echo.
echo  Setup did not finish. Please send a photo of this window
echo  to whoever gave you WebTrack.
echo.
pause
exit /b 1
