@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_desktop.ps1" %*
exit /b %ERRORLEVEL%
