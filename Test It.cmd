@echo off
setlocal
rem An intermediate cmd can inherit incompatible PowerShell 7 module paths.
rem Windows PowerShell constructs its in-box defaults when this is absent.
set "PSModulePath="
cd /d "%~dp0"
echo CyberSand Test It: original versus coherent Workbench presentation
echo The Windows PowerShell script will save a ZIP in Test-It-Results.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Test-It.ps1" -Coherence %*
set "CYBERSAND_TEST_IT_EXIT=%errorlevel%"
echo.
if not "%CYBERSAND_TEST_IT_EXIT%"=="0" echo Test incomplete. Preserve and share the ZIP even on failure.
if not "%CYBERSAND_TEST_IT_NO_PAUSE%"=="1" pause
exit /b %CYBERSAND_TEST_IT_EXIT%
