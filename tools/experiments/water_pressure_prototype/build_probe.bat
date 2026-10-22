@echo off
rem usage: build_probe.bat <outdir> <native root> <bench cpp> [extra cl flags...]
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
if not exist %1 mkdir %1
cd /d %1
set R=%2
set B=%3
shift
shift
shift
set EXTRA=
:loop
if "%~1"=="" goto done
set EXTRA=%EXTRA% %1
shift
goto loop
:done
cl /nologo /std:c++20 /EHsc /O2 /DNDEBUG %EXTRA% /I %R%\include %R%\src\world.cpp %R%\src\material_rules.cpp %R%\src\scheduler_geometry.cpp %R%\src\settled_world_discovery.cpp %B% /Fe:probe.exe > build.log 2>&1
echo exit %errorlevel%
