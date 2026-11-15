@echo off
setlocal
cd /d "%~dp0"
echo CyberSand Test It: matched render-cadence repair and legacy controls
echo The Windows PowerShell script will save a ZIP in Test-It-Results.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Test-It.ps1" -Cadence %*
set "CYBERSAND_TEST_IT_EXIT=%errorlevel%"
echo.
if not "%CYBERSAND_TEST_IT_EXIT%"=="0" echo Test incomplete. Preserve and share the ZIP even on failure.
if not "%CYBERSAND_TEST_IT_NO_PAUSE%"=="1" pause
exit /b %CYBERSAND_TEST_IT_EXIT%
