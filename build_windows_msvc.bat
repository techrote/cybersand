@echo off
setlocal

where cl >nul 2>nul
if errorlevel 1 (
    echo Microsoft C++ compiler not found. Run this from a Visual Studio Developer Command Prompt.
    exit /b 1
)

if not exist build mkdir build
set COMMON=/nologo /std:c++20 /EHsc /W4 /I native\include
set SIMULATION_SOURCES=native\src\world.cpp native\src\material_rules.cpp native\src\scheduler_geometry.cpp native\src\settled_world_discovery.cpp
set BRIDGE_SOURCES=native\src\render_snapshot.cpp native\src\c_api.cpp
set CORE_SOURCES=%SIMULATION_SOURCES% %BRIDGE_SOURCES%

echo Building and running tests...
cl %COMMON% /Od /Zi %CORE_SOURCES% native\tests\test_world.cpp native\tests\test_liquid_solver_policy.cpp native\tests\test_lcb_inertial.cpp native\tests\test_water_inertial.cpp native\tests\test_lcb_pressure.cpp native\tests\test_pressure_moving_mask.cpp native\tests\test_pressure_setup_capacity.cpp native\tests\test_water_cellular_yield.cpp native\tests\test_water_normalization.cpp native\tests\test_liquid_run_receipt.cpp native\tests\test_liquid_construction_refusal.cpp native\tests\test_quantity_ledger.cpp /Fe:build\tests.exe
if errorlevel 1 exit /b 1
build\tests.exe
if errorlevel 1 exit /b 1

echo Building benchmark...
cl %COMMON% /O2 /GL /DNDEBUG %SIMULATION_SOURCES% native\bench\benchmark.cpp /Fe:build\benchmark.exe /link /LTCG
if errorlevel 1 exit /b 1

echo Building shared library...
cl %COMMON% /O2 /GL /DNDEBUG /LD /DCYBERSAND_BUILD_SHARED %CORE_SOURCES% /Fe:build\cybersand.dll /link /LTCG
if errorlevel 1 exit /b 1

echo Build completed successfully.
endlocal
