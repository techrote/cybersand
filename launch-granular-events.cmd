@echo off
setlocal
call "%~dp0launch-desktop.cmd" -PrintIdentityOnly
if errorlevel 1 exit /b %ERRORLEVEL%
if /I "%~1"=="--identity-only" exit /b 0
for /f "delims=" %%G in ('git -C "%~dp0." rev-parse HEAD') do set "CYBERSAND_SOURCE_REVISION=%%G"
set "gcr_event_engine=C:\Godot47\Godot_v4.7-stable_win64.exe"
if defined CYBERSAND_GODOT set "gcr_event_engine=%CYBERSAND_GODOT%"
"%gcr_event_engine%" --headless --audio-driver Dummy --path "%~dp0godot" --editor --quit
if errorlevel 1 exit /b %ERRORLEVEL%
"%gcr_event_engine%" --path "%~dp0godot" res://gcr_fleet_playground.tscn
exit /b %ERRORLEVEL%
