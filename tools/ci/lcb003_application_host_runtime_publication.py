#!/usr/bin/env python3
"""Branch-scoped publication for the implemented LCB-003 host checkpoint.

Reuse the isolated IN/pressure profile and accepted byte/source/lease engine.
This helper never pushes. Actual browser execution and full ready-PR gates
remain separate; the request must be explicitly committed before any build.
"""
from importlib.util import module_from_spec, spec_from_file_location
import json
import math
from pathlib import Path
import re

_spec = spec_from_file_location(
    "_lcb003_union_publication_profile",
    Path(__file__).with_name("lcb005_inertial_runtime_publication.py"),
)
union = module_from_spec(_spec)
_spec.loader.exec_module(union)
engine = union.engine
engine.BRANCH = "codex/lcb003-application-host"
engine.WORKFLOW = ".github/workflows/lcb003-application-host-runtime-publication.yml"
engine.REQUEST = "tools/ci/lcb003_application_host_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-10-25-lcb003-runtime-publication.md"
engine.BUNDLE_PREFIX = "lcb003-application-host-runtime"
engine.PRESSURE_CASE = "godot/tests/test_liquid_water_reference_body.gd"
engine.REQUEST_VALUE = {
    "schema": "lcb003-application-host-publish-request-v1",
    "family": "multi_solver",
    "variant": "fm-cy-pf0-pf1-pf2-in-brine",
    "scope": "lcb003-prepared-world-owners-cysd-and-application-host",
    "intent": "publish-source-matched-runtimes",
}
HOST_MARKERS = {
    "test_liquid_water_reference_body": "LIQUID_WATER_REFERENCE_BODY",
    "test_liquid_physical_transaction": "LIQUID_PHYSICAL_TRANSACTION",
    "test_liquid_physical_preparation": "LIQUID_PHYSICAL_PREPARATION",
    "test_liquid_water_feel_host": "LIQUID_WATER_FEEL_HOST",
    "test_liquid_inertial_host": "LIQUID_INERTIAL_HOST",
    "test_liquid_sampled_preparation": "LIQUID_SAMPLED_PREPARATION",
    "test_liquid_prepared_host": "LIQUID_PREPARED_HOST",
    "test_liquid_comparison_ui": "LIQUID_COMPARISON_UI",
    "test_liquid_owner_observation": "LIQUID_OWNER_OBSERVATION",
    "test_liquid_tower_host": "LIQUID_TOWER_HOST",
    "test_liquid_host_evidence": "LIQUID_HOST_EVIDENCE",
    "test_liquid_pressure_rapier": "LIQUID_PRESSURE_RAPIER",
    "test_liquid_level_import_host": "LIQUID_LEVEL_IMPORT_HOST",
}
engine.CASE_MARKERS = dict(engine.CASE_MARKERS) | {
    name: rf"(?m)^{prefix}: [1-9][0-9]* assertions[;,] 0 failures\s*$"
    for name, prefix in HOST_MARKERS.items()
} | {
    "test_liquid_level_preparation":
        r"(?m)^LIQUID_LEVEL_PREPARATION: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
    "test_liquid_host_web_probe": r"(?m)^LIQUID_HOST_WEB_PROBE_NATIVE: (\{.+\})\s*$",
}
engine.EXECUTION_SCOPE = (
    "Import plus all fourteen retained shared-contract/IN/pressure cases and "
    "fifteen implemented host/API cases on each target OS: prepared owner "
    "adoption/refusal, normalization, real Main/worker moving reference bodies, "
    "thermal CYSD preparation and explicit user import, receipt observations, "
    "direct Rapier parity and the native prerequisite of the Web host probe. "
    "Water IN remains unavailable; actual browser execution, complete constructor "
    "coverage, human feel and full ready-PR CI are separate gates"
)
# The imported IN profile is present but deliberately unarmed on this branch.
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {"tools/ci/lcb005_inertial_publish_request.json"}) | {
    engine.WORKFLOW, engine.REQUEST,
    "tools/ci/lcb003_application_host_runtime_publication.py",
    "tools/ci/test_lcb003_application_host_runtime_publication.py",
}
LEVEL_SECTIONS = {name: True for name in (
    "thermal_payload", "normalization", "refusals_atomicity", "token_fences",
    "mixed_workers", "legacy_preservation",
)}
IMPORT_SECTIONS = {name: True for name in (
    "actual_user_route", "refusal_atomicity", "thermal_normalization",
    "restart_identity", "legacy_preservation",
)}
BODY_VARIANTS = ("reference", "cached", "cached_dormant", "freemass")
_verify_union = engine.verify_case_results


def json_rows(directory: Path, name: str, prefix: str) -> list:
    output = (directory / (name + ".log")).read_text(encoding="utf-8")
    try:
        return [json.loads(value) for value in re.findall(r"(?m)^" + re.escape(prefix) + r" (\{.+\})\s*$", output)]
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed host observation: " + prefix) from exc


def exact_sections(value: object, expected: dict, message: str) -> None:
    engine.require(isinstance(value, dict) and value == expected and
                   all(type(value.get(key)) is bool for key in expected), message)


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_union(directory, report)
    name = "test_liquid_level_preparation"
    summaries = re.findall(engine.CASE_MARKERS[name], (directory / (name + ".log")).read_text(encoding="utf-8"))
    try:
        sections = json.loads(summaries[0])
    except (ValueError, TypeError, IndexError) as exc:
        raise RuntimeError("Malformed prepared CYSD sections") from exc
    exact_sections(sections, LEVEL_SECTIONS, "Incomplete prepared CYSD sections")
    values = json_rows(directory, "test_liquid_level_import_host", "LIQUID_LEVEL_IMPORT_HOST_RESULT")
    engine.require(len(values) == 1 and isinstance(values[0], dict) and values[0].get("ok") is True,
                   "Missing completed CYSD user route")
    exact_sections(values[0].get("sections"), IMPORT_SECTIONS, "Incomplete CYSD user-route sections")
    values = json_rows(directory, "test_liquid_water_reference_body", "LIQUID_WATER_REFERENCE_PLAY:")
    engine.require([value.get("variant") for value in values] == list(BODY_VARIANTS),
                   "Missing or duplicated ordinary moving-body cohorts")
    for value in values:
        engine.require(value.get("failed") is False and value.get("snapshot_failed") is False and
                       value.get("error") == "", "Ordinary body cohort quarantined")
        for key in ("completed_ticks", "snapshot_tick"):
            engine.require(type(value.get(key)) is int and value[key] >= 96,
                           "Incomplete ordinary body continuation")
        engine.require(value.get("attempted_tick") == value["completed_ticks"], "Failed final attempted body tick")
        for key in ("rapier_steps", "contacts", "applications", "received"):
            engine.require(type(value.get(key)) is int and value[key] > 0, "Missing actual body coupling: " + key)
        engine.require(type(value.get("water")) is int and value["water"] == value.get("initial_water") == 3718400,
                       "Ordinary body Water balance differs")
        impulse = value.get("accepted_impulse")
        engine.require(isinstance(impulse, list) and len(impulse) == 2 and
                       all(type(v) in (int, float) and math.isfinite(v) for v in impulse) and any(v != 0 for v in impulse),
                       "Missing finite signed accepted body feedback")
        if value["variant"] != "freemass":
            engine.require(isinstance(value.get("gas"), dict) and value["gas"].get("closes") is True,
                           "Ordinary pressure-body gas ledger does not close")
    values = json_rows(directory, "test_liquid_host_web_probe", "LIQUID_HOST_WEB_PROBE_NATIVE:")
    engine.require(len(values) == 1 and values[0].get("terminal") is True and values[0].get("ok") is True,
                   "Native Web-host prerequisite did not complete")
    checks = values[0].get("checks")
    engine.require(isinstance(checks, list) and len(checks) == 33 and
                   all(isinstance(check, dict) and isinstance(check.get("name"), str) and
                       check.get("passed") is True for check in checks) and
                   len({check["name"] for check in checks}) == len(checks),
                   "Incomplete native Web-host prerequisite checks")


engine.verify_case_results = verify_case_results

if __name__ == "__main__":
    raise SystemExit(engine.main())
