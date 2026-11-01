#!/usr/bin/env python3
"""Source-bound R runtime publisher profile; this helper never pushes.

Privately reuse the approved four-path publication engine. Only the named
feature branch and a fresh explicit request can admit builds/publication.
The historical #301 authorization/request is not consumed or replayed.
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
    "_render_copy_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_historical_workflow = engine.WORKFLOW
_historical_request = engine.REQUEST
engine.BRANCH = "codex/render-copy-production-20261101"
engine.WORKFLOW = ".github/workflows/render-copy-runtime-publication.yml"
engine.REQUEST = "tools/ci/render_copy_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-01-render-copy-production-reconciliation.md"
engine.BUNDLE_PREFIX = "render-copy-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.PRESSURE_CASE = "godot/tests/test_render_world_generation.gd"
engine.REQUEST_VALUE = {
    "schema": "render-copy-production-publish-request-v1",
    "family": "native_render_copy",
    "variant": "chunk_run",
    "scope": "current-main-r-byte-equivalence-and-source-matched-desktop-runtimes",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_render_world_generation": r"(?m)^RENDER_WORLD_GENERATION: [1-9][0-9]* assertions, 0 failures\s*$",
    "test_native_render_bridge_regression":
        r"(?m)^Native RenderBridge regression passed; full [1-9][0-9]* bytes, delta [1-9][0-9]* bytes/[1-9][0-9]* patches\s*$",
    "test_render_patch_handoff_regression": r"(?m)^Render patch handoff regression passed\s*$",
    "test_water_feel_integration": engine.CASE_MARKERS["test_water_feel_integration"],
    "test_liquid_solver_policy": engine.CASE_MARKERS["test_liquid_solver_policy"],
}
engine.CASE_TIMEOUTS = {}
engine.EXECUTION_SCOPE = (
    "Import and all five render-generation, native RG8 bridge, immutable patch-handoff, "
    "Water Feel projection/authority and liquid-policy admission/refusal controls on "
    "each actual target OS, after native byte-exact render-copy/nonmutation qualification; "
    "full current-head CI and graphical Control-versus-R qualification remain separate"
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_historical_workflow, _historical_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/render_copy_runtime_publication.py",
    "tools/ci/test_render_copy_runtime_publication.py",
    "tools/ci/execution_policy.py", "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json", "godot/tests/support/ci_execution_policy.json",
    "native/bench/render_copy.cpp",
}
_verify_bundle = engine.verify_bundle


def focused_cases(discovered):
    """Preserve every selected current-policy watchdog, flag and display bit."""
    engine.require(set(engine.CASE_MARKERS).issubset(discovered), "Required focused regression is missing")
    return [engine.runner.Case(
        "import", ("--editor", "--quit"),
        engine.runner.execution_policy.watchdog_seconds("godot_import_seconds"), 3.0,
    )] + [discovered[name] for name in engine.CASE_MARKERS]


def verify_bundle(directory, platform, source, validated):
    manifest = _verify_bundle(directory, platform, source, validated)
    if validated:
        expected = ("render-copy-runtime-attempt-" + manifest["workflow_attempt"]
                    + "-" + platform + "-" + os.environ["GITHUB_RUN_ID"] + "/validation.json")
        engine.require(manifest.get("validation_output") == expected,
                       "Render-copy artifact identity differs from validated attempt")
        report = json.loads((directory / "validation.json").read_text(encoding="utf-8"))
        engine.require(report.get("scope") == engine.EXECUTION_SCOPE, "Render-copy execution scope differs")
    return manifest


def verify_native(log, output, source):
    """Fail closed on absent, duplicate, zero-work or failing native evidence."""
    engine.context(source)
    data = log.read_bytes()
    text = data.decode("utf-8")
    rows = re.findall(r"(?m)^RENDER_COPY_QUALIFICATION (\{.+\})\s*$", text)
    engine.require(len(rows) == 1, "Missing or duplicate native render-copy qualification")
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            engine.require(key not in result, "Duplicate native qualification field")
            result[key] = value
        return result
    result = json.loads(rows[0], object_pairs_hook=unique_object)
    engine.require(isinstance(result, dict) and set(result) == {
        "assertions", "regions", "compared_bytes", "nonmutation_checks", "refusal_checks", "failures",
    }, "Incomplete native render-copy qualification fields")
    for field in ("assertions", "regions", "compared_bytes", "nonmutation_checks", "refusal_checks"):
        engine.require(type(result.get(field)) is int and result[field] > 0,
                       "Native render-copy qualification performed no " + field)
    engine.require(type(result.get("failures")) is int and result["failures"] == 0,
                   "Native render-copy qualification failed")
    engine.require(re.search(r"(?im)\b(?:error|runtime error|AddressSanitizer|UndefinedBehaviorSanitizer|skipped)\b", text) is None,
                   "Native render-copy log contains an error or skip")
    receipt = engine.context(source) | {
        "schema": "render-copy-native-publication-gate-v1", "result": result,
        "log_sha256": hashlib.sha256(data).hexdigest(), "log_bytes": len(data),
    }
    engine.write_json(output, receipt)
    return receipt


engine.focused_cases = focused_cases
engine.verify_bundle = verify_bundle


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "verify-native":
        parser = argparse.ArgumentParser(description=verify_native.__doc__)
        parser.add_argument("command", choices=["verify-native"])
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--log", type=Path, required=True)
        parser.add_argument("--output", type=Path, required=True)
        args = parser.parse_args()
        verify_native(args.log, args.output, args.source_sha)
        return 0
    return engine.main()


if __name__ == "__main__":
    raise SystemExit(main())
