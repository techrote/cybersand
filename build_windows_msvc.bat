@echo off
setlocal

where cl >nul 2>nul
if errorlevel 1 (
    echo Microsoft C++ compiler not found. Run this from a Visual Studio Developer Command Prompt.
    exit /b 1
)

if not exist build mkdir build
set COMMON=/nologo /std:c++20 /EHsc /W4 /I native\include

echo Building and running tests...
cl %COMMON% /Od /Zi native\src\world.cpp native\src\material_rules.cpp native\src\scheduler_geometry.cpp native\src\render_snapshot.cpp native\src\settled_world_discovery.cpp native\src\c_api.cpp native\tests\test_world.cpp /Fe:build\tests.exe
if errorlevel 1 exit /b 1
build\tests.exe
if errorlevel 1 exit /b 1

echo Building benchmark...
cl %COMMON% /O2 /GL /DNDEBUG native\src\world.cpp native\src\material_rules.cpp native\src\scheduler_geometry.cpp native\bench\benchmark.cpp /Fe:build\benchmark.exe /link /LTCG
if errorlevel 1 exit /b 1

echo Building shared library...
cl %COMMON% /O2 /GL /DNDEBUG /LD /DCYBERSAND_BUILD_SHARED native\src\world.cpp native\src\material_rules.cpp native\src\scheduler_geometry.cpp native\src\render_snapshot.cpp native\src\settled_world_discovery.cpp native\src\c_api.cpp /Fe:build\cybersand.dll /link /LTCG
if errorlevel 1 exit /b 1

echo Build completed successfully.
endlocal
