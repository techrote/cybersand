@echo off
setlocal
cd /d "%~dp0..\.."
if not "%errorlevel%"=="0" exit /b 1

if not exist build\sol281\msvc mkdir build\sol281\msvc
if exist build\sol281\msvc-bin exit /b 1
mkdir build\sol281\msvc-bin
if not "%errorlevel%"=="0" exit /b 1
set "MSVC_STAGE=vs-environment"
set "VSROOT="
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSROOT=%%i"
if not defined VSROOT exit /b 1
call "%VSROOT%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 > build\sol281\msvc\vs-environment.log 2>&1
if not "%errorlevel%"=="0" goto failed
where cl > build\sol281\msvc\compiler-locations.txt 2>&1
if not "%errorlevel%"=="0" goto failed

set "COMMON=/std:c++20 /EHsc /W4 /Od /Zi /Bv /I native\include /Fo:build\sol281\msvc-bin\ /Fd:build\sol281\msvc-bin\native.pdb"
set "CORE=native\src\world.cpp native\src\material_rules.cpp native\src\scheduler_geometry.cpp native\src\settled_world_discovery.cpp native\src\render_snapshot.cpp native\src\c_api.cpp"

set "MSVC_STAGE=compile-solid_detachment"
cl %COMMON% %CORE% native\tests\test_solid_detachment.cpp /Fe:build\sol281\msvc-bin\test_solid_detachment.exe > build\sol281\msvc\compile-solid_detachment.log 2>&1
if not "%errorlevel%"=="0" goto failed
set "MSVC_STAGE=run-solid_detachment"
build\sol281\msvc-bin\test_solid_detachment.exe > build\sol281\msvc\run-solid_detachment.log 2>&1
if not "%errorlevel%"=="0" goto failed

set "MSVC_STAGE=compile-conservative_displacement"
cl %COMMON% %CORE% native\tests\test_conservative_displacement.cpp /Fe:build\sol281\msvc-bin\test_conservative_displacement.exe > build\sol281\msvc\compile-conservative_displacement.log 2>&1
if not "%errorlevel%"=="0" goto failed
set "MSVC_STAGE=run-conservative_displacement"
build\sol281\msvc-bin\test_conservative_displacement.exe > build\sol281\msvc\run-conservative_displacement.log 2>&1
if not "%errorlevel%"=="0" goto failed

set "MSVC_STAGE=compile-solid_contact_geometry"
cl %COMMON% native\tests\test_solid_contact_geometry.cpp /Fe:build\sol281\msvc-bin\test_solid_contact_geometry.exe > build\sol281\msvc\compile-solid_contact_geometry.log 2>&1
if not "%errorlevel%"=="0" goto failed
set "MSVC_STAGE=run-solid_contact_geometry"
build\sol281\msvc-bin\test_solid_contact_geometry.exe > build\sol281\msvc\run-solid_contact_geometry.log 2>&1
if not "%errorlevel%"=="0" goto failed

echo SOL281_MSVC_COMPLETE: three focused native executables passed
exit /b 0

:failed
set "MSVC_RESULT=%errorlevel%"
echo SOL281_MSVC_FAILED: %MSVC_STAGE%, exit %MSVC_RESULT%
if exist "build\sol281\msvc\%MSVC_STAGE%.log" type "build\sol281\msvc\%MSVC_STAGE%.log"
exit /b %MSVC_RESULT%
