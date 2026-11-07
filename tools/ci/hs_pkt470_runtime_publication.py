#!/usr/bin/env python3
"""Source-pinned #470 HS-PKT Linux/Windows runtime publication profile.

The source-bound engine verifies original native inputs, runnable target-OS
cases, original logs and the four canonical output files. This helper never
pushes; only the branch-scoped lease-checked Actions publisher can do so.
"""
from dataclasses import replace
from importlib.util import module_from_spec, spec_from_file_location
import argparse
import os
from pathlib import Path
import re
import sys

_spec = spec_from_file_location(
    "_hs_pkt470_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_historical_workflow = engine.WORKFLOW
_historical_request = engine.REQUEST

engine.BRANCH = "gpt/hard-surface-dirty-tiles-20261106"
engine.WORKFLOW = ".github/workflows/hs-pkt470-runtime-publication.yml"
engine.REQUEST = "tools/ci/hs_pkt470_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-06-hard-surface-packet-incremental.md"
engine.PRESSURE_CASE = "godot/tests/test_hard_surface_incremental_packet.gd"
engine.BUNDLE_PREFIX = "hs-pkt470-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "hs-pkt470-runtime-publication-request-v1",
    "family": "hard_surface_chunk_packet",
    "variant": "incremental_64x64",
    "scope": "hs-pkt470-main-lockstep-integration",
    "intent": "publish-source-matched-runtimes",
}
# These same actual target-OS cases are all run before either manifest may say
# validated-development-runtime. Never treat earlier exact-head results as a
# substitute for these rebuilt source-bound runtimes.
engine.CASE_MARKERS = {
    "test_hard_surface_incremental_packet":
        r"(?m)^HARD_SURFACE_INCREMENTAL [1-9][0-9]* checks passed\s*$",
    "test_coupling_lockstep_semantics":
        r"(?m)^COUPLING_LOCKSTEP_SEMANTICS ok\s*$",
    "test_coupling_lockstep":
        r"(?m)^COUPLING_LOCKSTEP self-check ok steps=89\s*$",
    "test_simulation_worker_interest_ownership":
        r"(?m)^SIMULATION_WORKER_INTEREST_OWNERSHIP: [1-9][0-9]* assertions; 0 failures\s*$",
    "test_render_patch_handoff_regression":
        r"(?m)^Render patch handoff regression passed\s*$",
    "test_workbench_canvas":
        r"(?m)^WORKBENCH_CANVAS [1-9][0-9]* checks, 0 failures\s*$",
}
engine.CASE_TIMEOUTS = {"test_workbench_canvas": 600, "test_coupling_lockstep": 600,
                        "test_hard_surface_incremental_packet": 600}
engine.EXECUTION_SCOPE = (
    "Import, full hard-surface PackedInt32Array byte oracle, lockstep semantic "
    "and live coupling tests, worker interest ownership, render patch ACK/"
    "backpressure and built-in workbench canvas on actual Linux and Windows "
    "runtimes; full ready-for-review execution and human gameplay acceptance "
    "remain separately recorded"
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_historical_workflow, _historical_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/hs_pkt470_runtime_publication.py",
    "tools/ci/test_hs_pkt470_runtime_publication.py",
    "godot/tests/test_hard_surface_incremental_packet.gd",
    "godot/tests/test_coupling_lockstep.gd",
    "godot/tests/test_coupling_lockstep_semantics.gd",
    "godot/tests/test_render_patch_handoff_regression.gd",
    "godot/tests/test_simulation_worker_interest_ownership.gd",
    "godot/tests/test_workbench_canvas.gd",
    "tools/ci/execution_policy.py", "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json",
    "godot/tests/support/ci_execution_policy.json",
}
NATIVE_REQUIRED = {
    "Hard-surface": (
        "Hard-surface bits match the display projection",
        "Hard-surface invalidation is independent and tile exact",
        "Hard-surface invalidation matches across worker counts",
    )
}
_verify_native_pattern = re.compile(r"(?m)^\[pass\] (.+?)\s*$")


def focused_cases(discovered):
    engine.require(set(engine.CASE_MARKERS).issubset(discovered),
                   "Required HS-PKT exact-runtime cases missing")
    return [engine.runner.Case(
        "import", ("--editor", "--quit"),
        engine.runner.execution_policy.watchdog_seconds("godot_import_seconds"), 3.0,
    )] + [replace(discovered[name],
                 timeout=min(discovered[name].timeout,
                             engine.CASE_TIMEOUTS.get(name, discovered[name].timeout)))
          for name in engine.CASE_MARKERS]


def verify_native(log, output, source, name_filter):
    engine.context(source)
    engine.require(name_filter in NATIVE_REQUIRED, "Unregistered native case family")
    data = log.read_bytes()
    lines = data.decode("utf-8")
    passes = _verify_native_pattern.findall(lines)
    totals = re.findall(r"(?m)^([0-9]+) tests passed\s*$", lines)
    engine.require(len(totals) == 1 and int(totals[0]) == len(passes) and passes,
                   "Native case totals absent or inconsistent")
    engine.require(len(passes) == len(set(passes))
                   and all(name_filter in name for name in passes),
                   "Foreign or duplicated native case in focused log")
    engine.require(all(name in passes for name in NATIVE_REQUIRED[name_filter]),
                   "Hard-surface exact native controls not executed")
    engine.require(re.search(
        r"(?im)^\[fail\]|\b(?:runtime error|AddressSanitizer|UndefinedBehaviorSanitizer|skipped)\b",
        lines
    ) is None, "Native case failure or skip")
    engine.write_json(output, {
        **engine.context(source),
        "schema": "hs-pkt470-native-prepublication-v1",
        "source": source,
        "filter": name_filter,
        "passed": passes,
        "log_sha256": __import__("hashlib").sha256(data).hexdigest(),
    })


def verify_case_results(directory, report):
    # Shared verifier checks process exit, absence of error/skip, exact case
    # order, original log digests and each named positive summary.
    engine._shared_verify_case_results(directory, report)
    # The mutable test script is intentionally *not* a selected publication
    # case; only the source-pinned immutable fixture and source hash are used.
    canvas = (directory / "test_workbench_canvas.log").read_text(encoding="utf-8")
    engine.require("built-in load skipped" not in canvas, "Built-in canvas silently skipped")
    lockstep = (directory / "test_coupling_lockstep.log").read_text(encoding="utf-8")
    engine.require("COUPLING_LOCKSTEP self-check ok steps=89" in lockstep,
                   "No actual 90-tick native/Rapier lockstep self-check completed")


engine._shared_verify_case_results = engine.verify_case_results
engine.focused_cases = focused_cases
engine.verify_case_results = verify_case_results


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "verify-native":
        parser = argparse.ArgumentParser(description="Verify actual HS-PKT native exactness")
        parser.add_argument("command", choices=["verify-native"])
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--filter", choices=NATIVE_REQUIRED, required=True)
        parser.add_argument("--log", type=Path, required=True)
        parser.add_argument("--output", type=Path, required=True)
        args = parser.parse_args()
        verify_native(args.log, args.output, args.source_sha, args.filter)
        return 0
    return engine.main()


if __name__ == "__main__":
    raise SystemExit(main())
