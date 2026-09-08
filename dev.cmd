@echo off
setlocal
cd /d "%~dp0"
if defined PYTHON (
  "%PYTHON%" tools\dev.py %*
) else if exist ".local\python\Scripts\python.exe" (
  ".local\python\Scripts\python.exe" tools\dev.py %*
) else (
  python tools\dev.py %*
)
exit /b %errorlevel%
