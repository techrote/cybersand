#!/usr/bin/env python3
"""Source-matched Wave Flow runtime publication on the owned PR #631 branch.

Reuse the existing source/input, target-OS, LFS and four-file publication guards.
An explicit versioned request arms builds; this helper never pushes or merges.
The ordinary full Native/Godot/Water gates remain separate.
"""
from dataclasses import replace
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re

_spec = spec_from_file_location(
    "_wave_mt_private_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_old_workflow, _old_request = engine.WORKFLOW, engine.REQUEST
_shared_markers = dict(engine.CASE_MARKERS)
engine.BRANCH = "astra/wave-mt-001-669-finisher"
engine.WORKFLOW = ".github/workflows/wave-mt-runtime-publication.yml"
engine.REQUEST = "tools/ci/wave_mt_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-15-wave-mt-001-astra-takeover.md"
engine.PRESSURE_CASE = "godot/tests/test_wave_flow.gd"
engine.BUNDLE_PREFIX = "wave-mt-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "wave-mt-runtime-publish-request-v1",
    "family": "experimental-wave-flow-v1",
    "variant": "opt-in-default-off",
    "scope": "linux-windows-native-wave-rapier-needle",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_wave_flow": r"(?m)^WAVE_FLOW: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
    "test_liquid_solver_policy": _shared_markers["test_liquid_solver_policy"],
    "test_lcb_pressure_reference": _shared_markers["test_lcb_pressure_reference"],
    "test_liquid_pressure_rapier": r"(?m)^LIQUID_PRESSURE_RAPIER: [1-9][0-9]* assertions; 0 failures\s*$",
}
engine.CASE_TIMEOUTS = {}
engine.EXECUTION_SCOPE = (
    "Exact-source Linux/Windows Godot 4.7 import, experimental Wave Flow construction, "
    "selection, mass/region/state/refusal contracts and real Rapier/Needle fixtures; "
    "unchanged liquid-policy and PressureFlow/Rapier controls. Complete ordinary "
    "Native, sanitizer, Godot and Water gates remain separately required."
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_old_workflow, _old_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "docs/audits/2026-11-15-wave-mt-001-completion.md",
    ".github/workflows/wave-flow.yml",
    "tools/ci/wave_mt_runtime_publication.py",
    "tools/ci/test_wave_mt_runtime_publication.py",
    "tools/package_wave_flow_candidate.py",
    "tools/package_explore001_candidate.py",
    "tools/ci/native_candidate_identity.py",
    "tools/ci/stage_windows_vc_runtime.ps1",
    "tools/ci/execution_policy.py",
    "tools/ci/execution_telemetry.py",
    "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json",
    "tools/ci/test_godot_attempt_custody.py",
    "godot/tests/support/ci_execution_policy.json",
    "native/bench/wave_mt_matrix.cpp",
    "native/bench/wave_default_off_pair.cpp",
    "tools/wave_mt/run_matrix.py",
    "tools/wave_mt/summarise.py",
    "tools/wave_mt/test_matrix.py",
    "tools/wave_mt/run_default_off_pair.py",
    "tools/wave_mt/test_default_off_pair.py",
    "tools/material_catalogue/compatibility.py",
    "docs/operations/wave-flow-evaluation.md",
}
WAVE_SECTIONS = {
    "native_configuration", "mass_readback", "region_pause", "state_identity",
    "save_refusal", "solver_comparison", "fixtures", "rapier_contact", "needle_contact",
}
_verify_shared = engine.verify_case_results


def verify_wave_summary(output: str) -> None:
    summaries = re.findall(engine.CASE_MARKERS["test_wave_flow"], output)
    engine.require(len(summaries) == 1, "Missing unique successful Wave Flow summary")
    try:
        completed = json.loads(summaries[0])
    except (ValueError, TypeError) as error:
        raise RuntimeError("Malformed Wave Flow completion summary") from error
    engine.require(isinstance(completed, dict) and set(completed) == WAVE_SECTIONS
                   and all(value is True for value in completed.values()),
                   "Incomplete Wave Flow, real Rapier or Needle execution")


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_shared(directory, report)
    engine.require(report.get("scope") == engine.EXECUTION_SCOPE,
                   "Runtime qualification scope differs")
    verify_wave_summary((directory / "test_wave_flow.log").read_text(encoding="utf-8"))


def focused_cases(discovered):
    engine.require(set(engine.CASE_MARKERS).issubset(discovered),
                   "Required runtime regression is missing")
    return [engine.runner.Case("import", ("--editor", "--quit"),
                              engine.runner.execution_policy.watchdog_seconds("godot_import_seconds"), 3.0)] + [
        replace(discovered[name]) for name in engine.CASE_MARKERS
    ]


engine.verify_case_results = verify_case_results
engine.focused_cases = focused_cases

if __name__ == "__main__":
    raise SystemExit(engine.main())
