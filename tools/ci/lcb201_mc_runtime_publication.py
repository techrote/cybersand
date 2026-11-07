#!/usr/bin/env python3
"""Source-bound #201 moving-camera runtime publisher profile; never pushes.

Privately reuses the approved four-path publication engine, as the render-copy
profile does. Only the named moving-camera branch and a fresh explicit request can admit
builds/publication. The workflow owns the single-parent append. Historical
LCB-002, render-copy and #201 P1 profiles, requests and workflows are not touched.
"""
from importlib.util import module_from_spec, spec_from_file_location
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

_spec = spec_from_file_location(
    "_lcb201_mc_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_historical_workflow = engine.WORKFLOW
_historical_request = engine.REQUEST
_shared_markers = dict(engine.CASE_MARKERS)
engine.BRANCH = "claude/pf201-moving-camera"
engine.WORKFLOW = ".github/workflows/lcb201-mc-runtime-publication.yml"
engine.REQUEST = "tools/ci/lcb201_mc_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-05-lcb201-moving-camera-invalidation.md"
engine.BUNDLE_PREFIX = "lcb201-mc-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.PRESSURE_CASE = "godot/tests/test_lcb_pressure_optimization.gd"
engine.REQUEST_VALUE = {
    "schema": "lcb201-mc-publish-request-v1",
    "family": "pressure_flow_v1",
    "variant": "reference-cached-cached_dormant",
    "scope": "lcb201-moving-camera-cache-invalidation",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_lcb_pressure_optimization":
        r"(?m)^LCB_PRESSURE_OPTIMIZATION: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
    "test_lcb_pressure_reference": _shared_markers["test_lcb_pressure_reference"],
    "test_liquid_pressure_rapier": r"(?m)^LIQUID_PRESSURE_RAPIER: [1-9][0-9]* assertions; 0 failures\s*$",
    # The region-flip control this branch changed (selected-core flips keep the index).
    "test_simulation_worker_interest_ownership":
        r"(?m)^SIMULATION_WORKER_INTEREST_OWNERSHIP: [1-9][0-9]* assertions; 0 failures\s*$",
}
# Hosted job budgets (current-policy watchdogs are 3,940 s per case) admit
# import plus these four cases; policy, worker and Water Feel
# controls remain in the PR's full ready-for-review Godot gates.
engine.CASE_TIMEOUTS = {}
engine.EXECUTION_SCOPE = (
    "Import plus reference/cached/cached_dormant pressure arms with copied readback, "
    "identity and exact parity, the pressure reference sections, actual Rapier "
    "pressure-variant bodies and the worker region-flip cache control on each actual "
    "target OS, after native LCB-002/LCB-001 pressure groups; full current-head CI remains separate"
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_historical_workflow, _historical_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/lcb201_mc_runtime_publication.py",
    "tools/ci/test_lcb201_mc_runtime_publication.py",
    "godot/tests/test_simulation_worker_interest_ownership.gd",
    "tools/ci/execution_policy.py", "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json", "godot/tests/support/ci_execution_policy.json",
}
# The GDExtension regression must report every completed group; a green process
# or a positive assertion count alone cannot replace them.
OPTIMIZATION_SECTIONS = {
    "native_variants": True, "readback_encoding": True, "exact_parity": True,
    "gas_invalidation": True, "cold_restore": True, "default_preservation": True,
}
# Native groups that must pass before any runtime build, with the P1 and the
# moving-region (cache warmth, exact parity, chunk-lookup invalidation) controls.
NATIVE_FILTERS = ("LCB-002", "LCB-001 pressure")
NATIVE_REQUIRED = (
    "LCB-002 P1 wake summaries skip quiet scans and stay exact",
    "LCB-002 #201 moving region and move-assignment exactness",
)
_verify_bundle = engine.verify_bundle
_verify_shared = engine.verify_case_results


def focused_cases(discovered):
    """Preserve every selected current-policy watchdog, flag and display bit."""
    engine.require(set(engine.CASE_MARKERS).issubset(discovered), "Required focused regression is missing")
    return [engine.runner.Case(
        "import", ("--editor", "--quit"),
        engine.runner.execution_policy.watchdog_seconds("godot_import_seconds"), 3.0,
    )] + [discovered[name] for name in engine.CASE_MARKERS]


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


def verify_bundle(directory, platform, source, validated):
    manifest = _verify_bundle(directory, platform, source, validated)
    if validated:
        expected = ("lcb201-mc-runtime-attempt-" + manifest["workflow_attempt"]
                    + "-" + platform + "-" + os.environ["GITHUB_RUN_ID"] + "/validation.json")
        engine.require(manifest.get("validation_output") == expected,
                       "Moving-camera artifact identity differs from validated attempt")
        report = json.loads((directory / "validation.json").read_text(encoding="utf-8"))
        engine.require(report.get("scope") == engine.EXECUTION_SCOPE, "Moving-camera execution scope differs")
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
                             text) is None, "Native pressure log contains a failure or skip")
    if name_filter == "LCB-002":
        engine.require(all(name in passed for name in NATIVE_REQUIRED),
                       "P1 or moving-region native control did not run")
    receipt = engine.context(source) | {
        "schema": "lcb201-mc-native-publication-gate-v1", "filter": name_filter, "passed": passed,
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
