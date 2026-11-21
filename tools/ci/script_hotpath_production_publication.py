#!/usr/bin/env python3
"""Source-locked SCRIPT-HOTPATH-001 publication profile.

Reuses the existing independent native-publisher implementation: source and
input ledgers, target-OS execution records, atomic four-path LFS publication,
and branch fast-forward fencing. No push happens in this module.
"""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

_module = spec_from_file_location(
    "_script_hotpath_publisher_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_module)
_module.loader.exec_module(engine)

_original_workflow, _original_request = engine.WORKFLOW, engine.REQUEST
_legacy_policy = engine.CASE_MARKERS["test_liquid_solver_policy"]
engine.BRANCH = "exp/script-hotpath-001-native-fill"
engine.WORKFLOW = ".github/workflows/script-hotpath-production.yml"
engine.REQUEST = "tools/ci/script_hotpath_production_publish_request.json"
engine.EVIDENCE = "docs/experiments/script-hotpath-001-native-fill.md"
engine.PRESSURE_CASE = "godot/tests/test_script_hotpath_native_fill.gd"
engine.BUNDLE_PREFIX = "script-hotpath-production"
engine.REQUEST_VALUE = {
    "schema": "script-hotpath-production-publish-request-v1",
    "family": "script-hotpath-001",
    "variant": "native-compiled-paint-fill-with-script-fallback",
    "scope": "source-matched-linux-windows-paint-fill",
    "intent": "publish-source-matched-runtimes",
}
# Each receipt must prove the actual feature and material/physics controls,
# rather than certifying only a newly compiled but unused DLL.
engine.CASE_MARKERS = {
    "test_script_hotpath_native_fill":
        r'(?m)^SCRIPT_HOTPATH_RESULT \{(?=[^\n]*"checks":819)(?=[^\n]*"failures":\[\])(?=[^\n]*"backend_version":1)[^\n]+\}$',
    "test_paint_editor_shapes":
        r'(?m)^PAINT_EDITOR_SHAPES \{(?=[^\n]*"checks":165)(?=[^\n]*"failures":0)(?=[^\n]*"actual_native_readback":true)[^\n]+\}$',
    "test_paint_editor_executor":
        r'(?m)^PAINT_EXECUTOR \{(?=[^\n]*"checks":21)(?=[^\n]*"failures":\[\])[^\n]+\}$',
    "test_paint_editor_workbench":
        r'(?m)^PAINT_EDITOR_WORKBENCH \{(?=[^\n]*"checks":64)(?=[^\n]*"failures":\[\])(?=[^\n]*"frame_samples":[1-9][0-9]*)[^\n]+\}$',
    "test_liquid_solver_policy": _legacy_policy,
    "test_liquid_pressure_rapier":
        r'(?m)^LIQUID_PRESSURE_RAPIER: [1-9][0-9]* assertions; 0 failures\s*$',
}
engine.CASE_TIMEOUTS = {"test_script_hotpath_native_fill": 300,
                        "test_paint_editor_shapes": 480,
                        "test_paint_editor_executor": 300,
                        "test_paint_editor_workbench": 600,
                        "test_liquid_solver_policy": 360,
                        "test_liquid_pressure_rapier": 420}
engine.EXECUTION_SCOPE = (
    "Actual target-OS Godot 4.7 native-C++ PAINT connected-fill differential, "
    "bounded refusal/crop semantics, material source validation, PAINT shape and "
    "worker execution, ordinary mounted Workbench gestures and frame-gap "
    "telemetry, unchanged liquid solver policy and PressureFlow/Rapier controls; "
    "GDScript fallback parity and Windows owner GPU evidence separately retained"
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) -
                      {_original_workflow, _original_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/script_hotpath_production_publication.py",
    "tools/ci/test_script_hotpath_production_publication.py",
    "tools/ci/qualify_script_hotpath_windows.py",
    ".github/workflows/script-hotpath-windows.yml",
    ".github/workflows/script-hotpath-godot.yml",
    "godot/tests/bench_script_hotpath_native_fill.gd",
}
if __name__ == "__main__":
    raise SystemExit(engine.main())
