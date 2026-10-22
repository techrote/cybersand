@echo off
rem usage: build_sandbox.bat <outdir> <native root> <exe name> <title>
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
if not exist %1 mkdir %1
cd /d %1
set R=%2
mkdir obj_%3 2>nul
cl /nologo /std:c++20 /EHsc /O2 /DNDEBUG /DSANDBOX_TITLE_T=%4 /I %R%\include /Foobj_%3\ %R%\src\world.cpp %R%\src\material_rules.cpp %R%\src\scheduler_geometry.cpp %R%\src\settled_world_discovery.cpp %~dp0sandbox\water_sandbox.cpp /Fe:%3.exe /link /SUBSYSTEM:WINDOWS user32.lib gdi32.lib > %3.log 2>&1
echo %3 %errorlevel%
