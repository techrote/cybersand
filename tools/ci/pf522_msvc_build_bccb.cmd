@echo on
@setlocal
@set "MODE=%~1"
@if not "%MODE%"=="original" if not "%MODE%"=="probe" exit /b 2
@for /f "tokens=*" %%I in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath') do @set "VS_ROOT=%%I"
@if not defined VS_ROOT exit /b 3
@call "%VS_ROOT%\VC\Auxiliary\Build\vcvars64.bat"
@if errorlevel 1 exit /b 4
@where cl
@if errorlevel 1 exit /b 5
@if not exist evidence mkdir evidence
@for %%R in (baseline candidate) do (
  pushd %%R
  if not exist build mkdir build
  git rev-parse HEAD
  cl /nologo /std:c++20 /EHsc /W4 /I native\include /O2 /DNDEBUG native\src\world.cpp native\src\material_rules.cpp native\src\scheduler_geometry.cpp native\src\settled_world_discovery.cpp native\src\render_snapshot.cpp native\src\c_api.cpp native\tests\test_world.cpp native\tests\test_liquid_solver_policy.cpp native\tests\test_lcb_inertial.cpp native\tests\test_water_inertial.cpp native\tests\test_lcb_pressure.cpp native\tests\test_pressure_moving_mask.cpp native\tests\test_pressure_setup_capacity.cpp native\tests\test_water_cellular_yield.cpp native\tests\test_water_normalization.cpp native\tests\test_liquid_run_receipt.cpp native\tests\test_liquid_construction_refusal.cpp native\tests\test_quantity_ledger.cpp native\tests\test_ballistic_water.cpp native\tests\test_workbench_pressure_heads.cpp /Fe:build\%%R-%MODE%.exe > ..\evidence\compile-%%R-%MODE%.log 2>&1
  if errorlevel 1 (
    type ..\evidence\compile-%%R-%MODE%.log
    exit /b 6
  )
  popd
)
@echo PF522_MSVC_SOURCE_BUILDS_PASS %MODE%
@exit /b 0
