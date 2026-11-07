#!/usr/bin/env python3
"""Source-bound PF-GAS #504 ballistic-Water/workbench runtime publisher profile; never pushes.

Privately reuses the approved four-path publication engine, as the render-copy,
#201 P1 and #201 moving-camera profiles do. Only the named
integration/pf504-after-405-20261107 branch and a fresh explicit request can admit
builds/publication. The workflow owns the single-parent append. Historical
LCB-001/LCB-002, render-copy and #201 profiles, requests and workflows are not
touched.
"""
from dataclasses import replace
from importlib.util import module_from_spec, spec_from_file_location
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

_spec = spec_from_file_location(
    "_pf_gas_hotpath_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_historical_workflow = engine.WORKFLOW
_historical_request = engine.REQUEST
_shared_markers = dict(engine.CASE_MARKERS)
engine.BRANCH = "integration/pf504-after-405-20261107"
engine.WORKFLOW = ".github/workflows/pf504-post405-runtime-publication.yml"
engine.REQUEST = "tools/ci/pf504_post405_runtime_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-07-pf504-post405-merge-and-release.md"
engine.BUNDLE_PREFIX = "pf504-post405-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.PRESSURE_CASE = "godot/tests/test_pf_c2048_prepared.gd"
engine.REQUEST_VALUE = {
    "schema": "pf504-post405-runtime-publish-request-v1",
    "family": "pressure_flow_v1",
    "variant": "C2048-optimized-gas-hotpath-plus-accepted-camera-retention",
    "scope": "pf504-post405-integrated-source-matched-linux-windows",
    "intent": "publish-source-matched-runtimes",
}

engine.CASE_MARKERS = {
    "test_lcb_pressure_optimization":
        r"(?m)^LCB_PRESSURE_OPTIMIZATION: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
    "test_lcb_pressure_reference": _shared_markers["test_lcb_pressure_reference"],
    "test_liquid_pressure_rapier": r"(?m)^LIQUID_PRESSURE_RAPIER: [1-9][0-9]* assertions; 0 failures\s*$",
    "test_simulation_worker_interest_ownership":
        r"(?m)^SIMULATION_WORKER_INTEREST_OWNERSHIP: [1-9][0-9]* assertions; 0 failures\s*$",
    # The built-in my-canvas/bench-canvas starts, face tuning and fine cores this branch adds.
    "test_pf_c2048_prepared": r"(?m)^PF_C2048_PREPARED: [1-9][0-9]* checks; 0 failures\s*$",
    "test_workbench_canvas": r"(?m)^WORKBENCH_CANVAS [1-9][0-9]* checks, 0 failures\s*$",
}
# Hosted job budgets admit import plus these five cases; the remaining
# workbench, policy, worker and Water Feel controls stay in the PR's full
# ready-for-review Godot gates. The small-canvas case gets one explicit,
# stricter bound (its current-policy watchdog is 3,940 s; it completes in
# seconds) so every ceiling still fits inside both hosted job budgets.
engine.CASE_TIMEOUTS = {"test_workbench_canvas": 600, "test_pf_c2048_prepared": 300}
engine.EXECUTION_SCOPE = (
    "Integrated post-405 C2048 PressureFlow gas BFS/seed hotpath plus accepted camera-only cache retention, "
    "legacy C1024/explicit CYPS5 prepared-world compatibility, pressure "
    "reference/cached/cached_dormant exactness, Rapier/worker/canvas regression "
    "and genuine Linux/Windows Godot 4.7 execution. These development runtimes "
    "are not yet approved for production despite full-size measured benefit; representative "
    "eight-actor gameplay acceptance and final merge remain separate."
)

engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_historical_workflow, _historical_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/pf504_post405_runtime_publication.py",
    "tools/ci/test_pf504_post405_runtime_publication.py",
    "godot/tests/test_simulation_worker_interest_ownership.gd",
    "godot/tests/test_workbench_canvas.gd",
    "godot/tests/test_pf_c2048_prepared.gd",
    "tools/ci/execution_policy.py", "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json", "godot/tests/support/ci_execution_policy.json",
}
# The GDExtension regression must report every completed group; a green process
# or a positive assertion count alone cannot replace them.
OPTIMIZATION_SECTIONS = {
    "native_variants": True, "readback_encoding": True, "exact_parity": True,
    "gas_invalidation": True, "cold_restore": True, "default_preservation": True,
}
# Native groups that must pass before any runtime build, each with the named
# controls this branch changed or relies on.
NATIVE_REQUIRED = {
    "LCB-002": ("LCB-002 P1 wake summaries skip quiet scans and stay exact", "LCB-002 #201 moving region keeps exact warm pressure caches"),
    "LCB-001 pressure": (),
    "LCB-001 gas exact hotpath": ("LCB-001 gas exact hotpath seams, masks and worker parity",),
    "Workbench parallel": ("Workbench parallel PressureFlow heads match serial (all variants)",),
    "Pair reaction": ("Pair reaction tables match the authored resolver",),
}
NATIVE_FILTERS = tuple(NATIVE_REQUIRED)
_verify_bundle = engine.verify_bundle
_verify_shared = engine.verify_case_results


def focused_cases(discovered):
    """Preserve every selected flag and display bit; watchdogs only tighten."""
    engine.require(set(engine.CASE_MARKERS).issubset(discovered), "Required focused regression is missing")
    return [engine.runner.Case(
        "import", ("--editor", "--quit"),
        engine.runner.execution_policy.watchdog_seconds("godot_import_seconds"), 3.0,
    )] + [replace(discovered[name], timeout=min(discovered[name].timeout,
                                                engine.CASE_TIMEOUTS.get(name, discovered[name].timeout)))
          for name in engine.CASE_MARKERS]


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_shared(directory, report)
    output = (directory / "test_lcb_pressure_optimization.log").read_text(encoding="utf-8")
    summaries = re.findall(engine.CASE_MARKERS["test_lcb_pressure_optimization"], output)
    engine.require(len(summaries) == 1, "Incomplete pressure-optimization helper sections")
    try:
        sections = json.loads(summaries[0])
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed pressure-optimization helper sections") from exc
    engine.require(sections == OPTIMIZATION_SECTIONS
                   and all(type(sections[key]) is bool for key in OPTIMIZATION_SECTIONS),
                   "Incomplete pressure-optimization helper sections")
    canvas = (directory / "test_workbench_canvas.log").read_text(encoding="utf-8")
    # A user canvas of the same name would skip the built-in check; CI must run it.
    engine.require("built-in load skipped" not in canvas, "Built-in workbench canvas check was skipped")


def verify_bundle(directory, platform, source, validated):
    manifest = _verify_bundle(directory, platform, source, validated)
    if validated:
        expected = ("pf504-post405-runtime-attempt-" + manifest["workflow_attempt"]
                    + "-" + platform + "-" + os.environ["GITHUB_RUN_ID"] + "/validation.json")
        engine.require(manifest.get("validation_output") == expected,
                       "PF-GAS #504 artifact identity differs from validated attempt")
        report = json.loads((directory / "validation.json").read_text(encoding="utf-8"))
        engine.require(report.get("scope") == engine.EXECUTION_SCOPE, "PF-GAS #504 execution scope differs")
    return manifest


def verify_native(log, output, source, name_filter):
    """Fail closed on absent, failing, skipped or zero-work native group output."""
    engine.context(source)
    engine.require(name_filter in NATIVE_FILTERS, "Unregistered native filter")
    data = log.read_bytes()
    text = data.decode("utf-8")
    passed = re.findall(r"(?m)^\[pass\] (.+?)\s*$", text)
    totals = re.findall(r"(?m)^([0-9]+) tests passed\s*$", text)
    engine.require(len(totals) == 1 and int(totals[0]) == len(passed) and passed,
                   "Missing or inconsistent native pass summary")
    engine.require(len(set(passed)) == len(passed) and all(name_filter in name for name in passed),
                   "Duplicate or foreign native test result")
    engine.require(re.search(r"(?im)^\[fail\]|\b(?:runtime error|AddressSanitizer|UndefinedBehaviorSanitizer|skipped)\b",
                             text) is None, "Native log contains a failure or skip")
    engine.require(all(name in passed for name in NATIVE_REQUIRED[name_filter]),
                   "Required native control did not run")
    receipt = engine.context(source) | {
        "schema": "pf-gas-hotpath-native-publication-gate-v1", "filter": name_filter, "passed": passed,
        "log_sha256": hashlib.sha256(data).hexdigest(), "log_bytes": len(data),
    }
    engine.write_json(output, receipt)
    return receipt


engine.focused_cases = focused_cases
engine.verify_bundle = verify_bundle
engine.verify_case_results = verify_case_results


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "verify-native":
        parser = argparse.ArgumentParser(description=verify_native.__doc__)
        parser.add_argument("command", choices=["verify-native"])
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--filter", required=True, choices=NATIVE_FILTERS)
        parser.add_argument("--log", type=Path, required=True)
        parser.add_argument("--output", type=Path, required=True)
        args = parser.parse_args()
        verify_native(args.log, args.output, args.source_sha, args.filter)
        return 0
    return engine.main()


if __name__ == "__main__":
    raise SystemExit(main())
