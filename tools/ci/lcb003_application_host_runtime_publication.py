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
    "_lcb003_water_union_publication_profile",
    Path(__file__).with_name("lcb005_water_inertial_runtime_publication.py"),
)
union = module_from_spec(_spec)
_spec.loader.exec_module(union)
engine = union.engine
engine.BRANCH = "codex/lcb003-final-integration"
engine.WORKFLOW = ".github/workflows/lcb003-application-host-runtime-publication.yml"
engine.REQUEST = "tools/ci/lcb003_application_host_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-10-25-lcb003-runtime-publication.md"
engine.BUNDLE_PREFIX = "lcb003-application-host-runtime"
engine.PRESSURE_CASE = "godot/tests/test_liquid_water_reference_body.gd"
engine.REQUEST_VALUE = {
    "schema": "lcb003-application-host-publish-request-v1",
    "family": "multi_solver",
    "variant": "fm-cy-pf0-pf1-pf2-in-water-brine",
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
    "test_liquid_ordinary_demo_host": "LIQUID_ORDINARY_DEMO_HOST",
    "test_liquid_reference_body_poses": "LIQUID_REFERENCE_BODY_POSES",
    "test_liquid_synchronous_reference_body": "LIQUID_SYNCHRONOUS_REFERENCE_BODY",
    "test_liquid_synchronous_water_reference_body": "LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY",
    "test_liquid_desktop_default_host": "LIQUID_DESKTOP_DEFAULT_HOST",
}
engine.CASE_MARKERS = dict(engine.CASE_MARKERS) | {
    name: rf"(?m)^{prefix}: [1-9][0-9]* assertions[;,] 0 failures\s*$"
    for name, prefix in HOST_MARKERS.items()
} | {
    "test_liquid_level_preparation":
        r"(?m)^LIQUID_LEVEL_PREPARATION: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
    "test_liquid_default_demo_preparation":
        r"(?m)^LIQUID_DEFAULT_DEMO_PREPARATION: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
    "test_liquid_host_web_probe": r"(?m)^LIQUID_HOST_WEB_PROBE_NATIVE: (\{.+\})\s*$",
}
engine.EXECUTION_SCOPE = (
    "Import plus all fourteen retained shared-contract/IN/pressure cases and "
    "twenty-one implemented host/API cases on each target OS, preserving the "
    "strict actual Water IN native proof for both mass precisions and worker counts: prepared owner "
    "adoption/refusal, normalization, real Main/worker moving reference bodies, "
    "thermal CYSD preparation and explicit user import, four ordinary demos, "
    "actual synchronous Physics Pit and Water Feel FM/PF bodies, CY/IN future-source refusal, "
    "explicit reference poses, receipt observations, "
    "native-authored desktop default adoption, positive FM/CY body play and "
    "three typed initial pressure-capacity refusals, "
    "direct Rapier parity and the native prerequisite of the Web host probe. "
    "Actual browser execution, complete constructor "
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
DEFAULT_SECTIONS = {name: True for name in (
    "recipe_and_law_parity", "selected_policy", "prepared_masks",
    "refusal_and_token_fences", "default_lifecycle", "origin_lifetime",
)}
BODY_VARIANTS = ("reference", "cached", "cached_dormant", "freemass")
ORDINARY_DEMOS = ("material_lab", "waterworks", "foundry", "neon_works")
SYNCHRONOUS_BODY_PRESETS = (2, 3, 4)
SYNCHRONOUS_WATER_PRESETS = (2, 3, 4, 0)
DEFAULT_PLAY_VARIANTS = ("freemass", "whole")
DEFAULT_CAPACITY_VARIANTS = ("reference", "cached", "cached_dormant")
WEB_WATER_ARMS = (("freemass_v1", "reference"), ("cellular_yield_v1", "reference"),
                  ("pressure_flow_v1", "reference"), ("pressure_flow_v1", "cached"),
                  ("pressure_flow_v1", "cached_dormant"), ("inertial_cellular_v1", "reference"))
WEB_MIXED_VARIANTS = ("freemass", "reference", "cached", "cached_dormant")
_verify_union = engine.verify_case_results


def web_check_names() -> list[str]:
    """The frozen native prerequisite, including all original thirty-three checks."""
    names = ["normal owner reached actual setup", "registered fixture parses",
             "actual runtime admits Water CY", "normal owner installs fractional Current control",
             "normal owner explicitly refuses missing normalization",
             "refusal retains actual World, copied receipt, sampled owner and owner observation",
             "normal owner installs explicit water-normalize-v1",
             "actual native normalization and frozen qualification read back",
             "ordinary reset retains explicit selection, normalized payload and new copied identity",
             "actual runtime admits Brine IN", "native damping7 edit admits"]
    for variant in WEB_MIXED_VARIANTS:
        names += [prefix + variant for prefix in ("native selected mixed arm ",
                  "normal owner installs mixed arm ", "actual IN instance geometry/damping/extension agree ",
                  "mixed families advance with exact quantity ")]
        if variant != "freemass":
            names.append("actual PF execution readback " + variant)
    names.append("three PF variants have exact mixed-family authority projection")
    for family, variant in WEB_WATER_ARMS:
        label = family + "/" + variant
        names += ["actual runtime admits common Water arm " + label,
                  "native validates common Water request " + label]
        if family in ("cellular_yield_v1", "inertial_cellular_v1"):
            names += [prefix + label for prefix in ("fractional Current control precedes Water refusal ",
                      "fractional Water refuses without normalization ",
                      "whole-cell refusal retains World/receipt/generation/owner/observation ")]
        names += [prefix + label for prefix in ("normal owner installs normalized common Water arm ",
                  "native family/variant/policy/hash-version/radius match common Water arm ",
                  "common Water uses exact gross and net setup ledger ",
                  "common Water advances30 ticks with exact quantity and actual whole-cell/IN semantics ")]
    return names + ["all four Water families and three pressure variants use one exact normalized setup payload",
                    "ordinary Current constructor remains available",
                    "ordinary Current constructor retires prepared identity and restores protected radius2"]


def unique_json_object(pairs: list) -> dict:
    value = {}
    for key, item in pairs:
        engine.require(key not in value, "Duplicate host observation field")
        value[key] = item
    return value


def json_rows(directory: Path, name: str, prefix: str) -> list:
    output = (directory / (name + ".log")).read_text(encoding="utf-8")
    try:
        values = [json.loads(value, object_pairs_hook=unique_json_object)
                  for value in re.findall(r"(?m)^" + re.escape(prefix) + r" (.*)$", output)]
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed host observation: " + prefix) from exc
    engine.require(all(isinstance(value, dict) for value in values), "Non-object host observation: " + prefix)
    return values


def exact_sections(value: object, expected: dict, message: str) -> None:
    engine.require(isinstance(value, dict) and value == expected and
                   all(type(value.get(key)) is bool for key in expected), message)


def completed_host_result(directory: Path, name: str, prefix: str) -> dict:
    values = json_rows(directory, name, prefix)
    engine.require(len(values) == 1 and isinstance(values[0], dict) and values[0].get("ok") is True,
                   "Missing completed host result: " + prefix)
    return values[0]


def finite_pair(value: object) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(
        type(item) in (int, float) and math.isfinite(item) for item in value)


def sha256_text(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def hash64_text(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{16}", value) is not None


def verify_web_prerequisite(value: dict) -> None:
    engine.require(value.get("terminal") is True and value.get("ok") is True and
                   type(value.get("schema_version")) is int and value["schema_version"] == 1 and
                   value.get("failures") == [], "Native Web-host prerequisite did not complete")
    checks = value.get("checks")
    engine.require(isinstance(checks, list) and len(checks) == 76 and
                   all(isinstance(check, dict) and check.get("passed") is True for check in checks) and
                   [check.get("name") for check in checks] == web_check_names(),
                   "Incomplete native Web-host prerequisite checks")
    normalization = value.get("normalization")
    engine.require(isinstance(normalization, dict) and normalization.get("rule") == "water-normalize-v1" and
                   type(normalization.get("water_after")) is int and normalization["water_after"] == 255 and
                   all(sha256_text(normalization.get(key)) for key in ("payload_sha256", "receipt_sha256")),
                   "Missing original native Web normalization/restart identity")
    mixed = value.get("mixed_runs")
    engine.require(isinstance(mixed, list) and all(isinstance(row, dict) for row in mixed) and
                   [row.get("variant") for row in mixed] == list(WEB_MIXED_VARIANTS),
                   "Incomplete original native Web mixed-family arms")
    for row in mixed:
        census = row.get("census")
        counts = census.get("counts") if isinstance(census, dict) else None
        engine.require(isinstance(counts, dict) and type(counts.get("water")) is int and counts["water"] > 0 and
                       all(type(counts.get(key)) is int and counts[key] == 48 for key in ("oil", "brine")) and
                       type(row.get("water_integer")) is int and row["water_integer"] == 12240 and
                       row.get("observed_retained_motion") is True and hash64_text(row.get("physical_hash")) and
                       all(sha256_text(row.get(key)) for key in ("policy_sha256", "native_receipt_sha256")),
                       "Incomplete original native Web mixed quantity/motion/identity")
        if row["variant"] != "freemass":
            engine.require(hash64_text(row.get("projection")) and
                           type(row.get("optimization_execution_version")) is int and
                           row["optimization_execution_version"] == 3, "Missing original native Web pressure execution")
    engine.require(len({row["policy_sha256"] for row in mixed}) == 4 and
                   len({row["projection"] for row in mixed[1:]}) == 1,
                   "Original native Web pressure projection or distinct policies differ")
    water = value.get("water_runs")
    engine.require(isinstance(water, list) and all(isinstance(row, dict) for row in water) and
                   [(row.get("family"), row.get("variant")) for row in water] == list(WEB_WATER_ARMS),
                   "Incomplete native Web common-Water arms")
    for row in water:
        family = row["family"]
        census = row.get("census")
        engine.require(all(sha256_text(row.get(key)) for key in
                           ("policy_sha256", "native_receipt_sha256", "normalized_payload_sha256")) and
                       hash64_text(row.get("physical_hash")) and
                       type(row.get("radius")) is int and row["radius"] == 3 and
                       type(row.get("hash_version")) is int and
                       row["hash_version"] == (3 if family == "inertial_cellular_v1" else 2),
                       "Native Web common-Water identity/geometry differs")
        engine.require(all(type(row.get(key)) is int and row[key] == expected for key, expected in
                           (("positive_delta", 127), ("negative_delta", 127), ("water_integer", 12495), ("ticks", 30))) and
                       row.get("quantity_exact_each_tick") is True and isinstance(census, dict) and
                       type(census.get("quantity")) is int and census["quantity"] == 12495 and
                       type(census.get("count")) is int and census["count"] > 0,
                       "Native Web common-Water normalization/continuation differs")
        if family in ("cellular_yield_v1", "inertial_cellular_v1"):
            engine.require(census.get("full") is True and census["count"] == 49,
                           "Native Web whole-cell Water population differs")
        if family == "inertial_cellular_v1":
            engine.require(row.get("observed_retained_motion") is True, "Native Web Water IN motion is absent")
    engine.require(len({row["normalized_payload_sha256"] for row in water}) == 1 and
                   len({row["policy_sha256"] for row in water}) == 6,
                   "Native Web common-Water payload or distinct policies differ")


def verify_ordinary_routes(directory: Path) -> None:
    value = completed_host_result(directory, "test_liquid_ordinary_demo_host", "LIQUID_ORDINARY_DEMO_HOST_RESULT")
    cohorts = value.get("cohorts")
    engine.require(isinstance(cohorts, list) and all(isinstance(row, dict) for row in cohorts) and
                   [(row.get("demo"), row.get("quality")) for row in cohorts] ==
                   [(demo, quality) for demo in ORDINARY_DEMOS for quality in (0, 2)],
                   "Incomplete ordinary demo/quality cohorts")
    for row in cohorts:
        engine.require(type(row.get("quality")) is int and type(row.get("executed_ticks")) is int and
                       row["executed_ticks"] >= 12 and type(row.get("reset_generation")) is int and
                       row["reset_generation"] > 0 and row.get("initial_player") == [24, 222] and
                       sha256_text(row.get("policy_hash")), "Incomplete ordinary execution/restart identity")
        region = row.get("region")
        engine.require(isinstance(region, list) and len(region) == 4 and all(type(v) is int for v in region) and
                       region[:2] == [0, 0] and all(0 < v <= 1024 for v in region[2:]),
                       "Invalid ordinary final execution region")
    matched = value.get("matched_geometry")
    engine.require(isinstance(matched, dict), "Missing ordinary matched-geometry controls")
    inertial, current = matched.get("inertial"), matched.get("current_comparator")
    engine.require(isinstance(inertial, dict) and type(inertial.get("geometry")) is int and inertial["geometry"] == 3 and
                   type(inertial.get("physical_hash_version")) is int and inertial["physical_hash_version"] == 3 and
                   sha256_text(inertial.get("extension")) and
                   isinstance(inertial.get("native_extension"), dict) and
                   inertial["native_extension"].get("family") == 4 and
                   inertial["native_extension"].get("extension_digest") == inertial["extension"] and
                   current == {"geometry": 3, "physical_hash_version": 2},
                   "Incomplete native IN/Current matched-geometry readback")

    value = completed_host_result(directory, "test_liquid_reference_body_poses", "LIQUID_REFERENCE_BODY_POSES_RESULT")
    engine.require(type(value.get("frozen_frames")) is int and value["frozen_frames"] >= 32 and
                   sha256_text(value.get("default_mask_sha256")) and
                   value.get("explicit_positions") == [[124, 92], [140, 72], [176, 52]],
                   "Incomplete frozen reference-pose/mask controls")

    value = completed_host_result(directory, "test_liquid_synchronous_reference_body", "LIQUID_SYNCHRONOUS_REFERENCE_BODY_RESULT")
    cohorts = value.get("cohorts")
    engine.require(isinstance(cohorts, list) and all(isinstance(row, dict) for row in cohorts) and
                   [row.get("preset") for row in cohorts] == list(SYNCHRONOUS_BODY_PRESETS),
                   "Incomplete synchronous pressure-body cohorts")
    for row in cohorts:
        variant = {2: "reference", 3: "cached", 4: "cached_dormant"}.get(row.get("preset"))
        engine.require(row.get("family") == "pressure_flow_v1" and row.get("variant") == variant and
                       sha256_text(row.get("policy_hash")), "Synchronous body native assignment differs")
        engine.require(type(row.get("preset")) is int and type(row.get("completed_ticks")) is int and
                       row["completed_ticks"] >= 240 and type(row.get("manual_steps")) is int and
                       row["manual_steps"] == row["completed_ticks"], "Incomplete synchronous body continuation")
        for key in ("contacts", "applications"):
            engine.require(type(row.get(key)) is int and row[key] > 0, "Missing synchronous body feedback: " + key)
        engine.require(type(row.get("water")) is int and row["water"] == 937125 and row.get("gas_closes") is True,
                       "Synchronous body quantity/gas ledger differs")
        impulse, magnitude = row.get("accepted_impulse"), row.get("absolute_impulse")
        engine.require(finite_pair(impulse) and any(v != 0 for v in impulse) and
                       type(magnitude) in (int, float) and math.isfinite(magnitude) and magnitude > 0 and
                       type(row.get("max_accepted_age")) is int and 0 <= row["max_accepted_age"] <= 8,
                       "Missing finite age-bounded synchronous accepted impulse")
        engine.require(row.get("initial_body0") == [124, 90] and finite_pair(row.get("final_body0")) and
                       row["final_body0"] != row["initial_body0"], "Synchronous authored body did not move")
    engine.require(len({row["policy_hash"] for row in cohorts}) == 3,
                   "Synchronous pressure bodies did not execute three distinct native policies")


def verify_synchronous_water(directory: Path) -> None:
    value = completed_host_result(directory, "test_liquid_synchronous_water_reference_body",
                                  "LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY_RESULT")
    engine.require(value.get("whole_cell_source_refusal_families") == ["cellular_yield_v1", "inertial_cellular_v1"],
                   "Missing synchronous CY/IN future-source refusal controls")
    cohorts = value.get("cohorts")
    engine.require(isinstance(cohorts, list) and all(isinstance(row, dict) for row in cohorts) and
                   [row.get("preset") for row in cohorts] == list(SYNCHRONOUS_WATER_PRESETS),
                   "Incomplete synchronous Water Feel cohorts")
    for row in cohorts:
        preset = row["preset"]
        family = "freemass_v1" if preset == 0 else "pressure_flow_v1"
        variant = {0: "reference", 2: "reference", 3: "cached", 4: "cached_dormant"}[preset]
        engine.require(type(preset) is int and row.get("family") == family and row.get("variant") == variant and
                       sha256_text(row.get("policy_hash")), "Synchronous Water native assignment differs")
        engine.require(type(row.get("quality")) is int and row["quality"] == 0 and
                       type(row.get("completed_ticks")) is int and row["completed_ticks"] == 240 and
                       type(row.get("manual_steps")) is int and row["manual_steps"] == 240 and
                       type(row.get("water")) is int and row["water"] == 3718400 and
                       type(row.get("observation_tick")) is int and row["observation_tick"] == 180,
                       "Incomplete synchronous Water quantity/execution/registered observation")
        for key in ("contacts", "applications"):
            engine.require(type(row.get(key)) is int and row[key] > 0, "Missing actual synchronous Water feedback")
        engine.require(row.get("pressure_accounting_valid") is True and row.get("gas_available") is (preset != 0) and
                       row.get("gas_closes") is (preset != 0), "Synchronous Water pressure/FM accounting differs")
        impulse, magnitude = row.get("accepted_impulse"), row.get("absolute_impulse")
        engine.require(finite_pair(impulse) and any(v != 0 for v in impulse) and
                       type(magnitude) in (int, float) and math.isfinite(magnitude) and magnitude > 0 and
                       type(row.get("max_accepted_age")) is int and 0 <= row["max_accepted_age"] <= 8,
                       "Missing finite age-bounded synchronous Water impulse")
        engine.require(row.get("initial_body0") == [124, 90] and finite_pair(row.get("final_body0")) and
                       row["final_body0"] != row["initial_body0"], "Synchronous Water body did not move")
    engine.require(len({row["policy_hash"] for row in cohorts}) == 4,
                   "Synchronous Water bodies did not execute four distinct native policies")


def verify_default_routes(directory: Path) -> None:
    name = "test_liquid_desktop_default_host"
    rows = json_rows(directory, name, "LIQUID_DESKTOP_DEFAULT_PLAY:")
    engine.require([row.get("variant") for row in rows] == list(DEFAULT_PLAY_VARIANTS),
                   "Missing or duplicated FM/CY desktop default play")
    for row in rows:
        engine.require(row.get("failed") is False and row.get("snapshot_failed") is False,
                       "Desktop default play quarantined")
        engine.require(type(row.get("completed_ticks")) is int and row["completed_ticks"] >= 96 and
                       type(row.get("attempted_tick")) is int and row["attempted_tick"] == row["completed_ticks"],
                       "Incomplete healthy desktop default continuation")
        for key in ("rapier_steps", "contacts", "applications"):
            engine.require(type(row.get(key)) is int and row[key] > 0, "Missing desktop default body feedback: " + key)
        impulse = row.get("signed_impulse")
        engine.require(finite_pair(impulse) and any(v != 0 for v in impulse), "Missing finite signed default feedback")
        engine.require(type(row.get("water")) is int and type(row.get("initial_water")) is int and
                       row["water"] == row["initial_water"] == 628320, "Desktop default quantity differs")
        ages = row.get("ages")
        # The diagnostic histogram includes rejected old results as well as
        # accepted results. The test separately asserts correct stale disposal.
        engine.require(isinstance(ages, dict) and bool(ages) and
                       all(isinstance(age, str) and re.fullmatch(r"[0-9]+", age) and
                           type(count) is int and count > 0 for age, count in ages.items()) and
                       any(int(age) <= 8 for age in ages), "Missing desktop default response-age observations")
    rows = json_rows(directory, name, "LIQUID_DESKTOP_DEFAULT_CAPACITY_REFUSAL:")
    engine.require([row.get("variant") for row in rows] == list(DEFAULT_CAPACITY_VARIANTS),
                   "Missing or duplicated typed pressure-default capacity refusals")
    for row in rows:
        engine.require(row.get("healthy") is True and type(row.get("tick")) is int and row["tick"] == 0 and
                       sha256_text(row.get("retained_receipt_hash")) and
                       row["retained_receipt_hash"] == row.get("actual_receipt_hash") and
                       row.get("attempt_kind") == "construction_attempt" and
                       isinstance(row.get("error"), str) and "capacity_refused" in row["error"],
                       "Pressure-default refusal lost retained healthy owner or actual native attempt")


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_union(directory, report)
    verify_ordinary_routes(directory)
    verify_synchronous_water(directory)
    verify_default_routes(directory)
    for name, expected in (("test_liquid_level_preparation", LEVEL_SECTIONS),
                           ("test_liquid_default_demo_preparation", DEFAULT_SECTIONS)):
        summaries = re.findall(engine.CASE_MARKERS[name], (directory / (name + ".log")).read_text(encoding="utf-8"))
        try:
            sections = json.loads(summaries[0])
        except (ValueError, TypeError, IndexError) as exc:
            raise RuntimeError("Malformed prepared sections: " + name) from exc
        exact_sections(sections, expected, "Incomplete prepared sections: " + name)
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
    engine.require(len(values) == 1, "Missing or duplicate native Web-host prerequisite")
    verify_web_prerequisite(values[0])


engine.verify_case_results = verify_case_results

if __name__ == "__main__":
    raise SystemExit(engine.main())
