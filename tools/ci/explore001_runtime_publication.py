#!/usr/bin/env python3
"""Branch-scoped EXPLORE-001 source-matched native runtime publisher.

Only the explicit on-branch request can arm a publication. Reuse the
established four-path LFS/provenance engine without weakening its checks.
"""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import sys

_spec = spec_from_file_location(
    "_explore001_private_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_historical_workflow = engine.WORKFLOW
_historical_request = engine.REQUEST
engine.BRANCH = "feat/explore001-gen007-playable-workbench"
engine.WORKFLOW = ".github/workflows/explore001-runtime-publication.yml"
engine.REQUEST = "tools/ci/explore001_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-08-explore001-integration-qa.md"
engine.PRESSURE_CASE = "godot/tests/test_explore001_generated_workbench.gd"
engine.BUNDLE_PREFIX = "explore001-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "explore001-runtime-publish-request-v1",
    "family": "gen007_playable_workbench",
    "variant": "source-matched-prepared-play-plane",
    "scope": "explore001-exact-source-native-godot-rapier-linux-windows",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_explore001_generated_workbench":
        r"(?m)^EXPLORE001_RESULTS checks=[1-9][0-9]* failures=0 small=true new=true reopened=false elapsed_ms=[0-9]+\\s*$",
    "test_workbench_canvas":
        r"(?m)^WORKBENCH_CANVAS [1-9][0-9]* checks, 0 failures\\s*$",
}
engine.CASE_TIMEOUTS = {
    "test_explore001_generated_workbench": 1800,
    "test_workbench_canvas": 900,
}
engine.EXECUTION_SCOPE = (
    "Exact-source Linux/Windows rebuilt GDExtension, official Godot 4.7 import, "
    "actual GEN-007 512/1024/2048 prepared native play-plane, Rapier flyer and "
    "authoring/start persistence initial-process assertions, and ordinary "
    "shared workbench native owner/control. Full exact-head suite, fresh-process "
    "reopening, Palette backend and human Windows traversal remain separate gates."
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) -
                      {_historical_workflow, _historical_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/explore001_runtime_publication.py",
    "tools/ci/test_explore001_runtime_publication.py",
    "tools/ci/execution_policy.py",
    "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json",
    "godot/tests/support/ci_execution_policy.json",
    "godot/tests/test_explore001_generated_workbench.gd",
    "godot/tests/test_workbench_canvas.gd",
    "godot/scripts/workbench_generator_dialog.gd",
    "godot/scripts/workbench_generated_map.gd",
    "docs/operations/explore001-desktop-playtest.md",
}
NATIVE_REQUIRED = {
    "LCB-002": ("LCB-002 P1 wake summaries skip quiet scans and stay exact",),
    "LCB-001 pressure": (),
    "Workbench parallel": ("Workbench parallel PressureFlow heads match serial (all variants)",),
    "Pair reaction": ("Pair reaction tables match the authored resolver",),
}
NATIVE_FILTERS = tuple(NATIVE_REQUIRED)

def verify_native(log: Path, output: Path, source: str, name_filter: str):
    """Require a complete, real, uniquely named, successful native group."""
    engine.context(source)
    engine.require(name_filter in NATIVE_FILTERS, "Unregistered native group")
    data = log.read_bytes()
    text = data.decode("utf-8")
    passed = re.findall(r"(?m)^\\[pass\\] (.+?)\\s*$", text)
    totals = re.findall(r"(?m)^([0-9]+) tests passed\\s*$", text)
    engine.require(len(totals) == 1 and int(totals[0]) == len(passed) and passed,
                   "Incomplete native group or mismatched totals")
    engine.require(len(set(passed)) == len(passed) and
                   all(name_filter in name for name in passed), "Duplicate/foreign native cases")
    engine.require(re.search(r"(?im)^\\[fail\\]|\\b(?:runtime error|AddressSanitizer|UndefinedBehaviorSanitizer|skipped)\\b", text) is None,
                   "Native group failed or skipped")
    engine.require(all(name in passed for name in NATIVE_REQUIRED[name_filter]),
                   "Named native control did not run")
    record = engine.context(source) | {
        "schema": "explore001-native-publication-gate-v1",
        "filter": name_filter, "passed": passed,
        "log_sha256": hashlib.sha256(data).hexdigest(),
        "log_bytes": len(data),
    }
    engine.write_json(output, record)
    return record

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "verify-native":
        parser = argparse.ArgumentParser()
        parser.add_argument("command", choices=["verify-native"])
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--filter", required=True, choices=NATIVE_FILTERS)
        parser.add_argument("--log", required=True, type=Path)
        parser.add_argument("--output", required=True, type=Path)
        args = parser.parse_args()
        verify_native(args.log, args.output, args.source_sha, args.filter)
        return 0
    return engine.main()

if __name__ == "__main__":
    raise SystemExit(main())
