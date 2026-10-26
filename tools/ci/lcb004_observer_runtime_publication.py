#!/usr/bin/env python3
"""Unarmed, branch-isolated observer successor of the complete 003 profile.

The private 003 -> Water005 -> Brine005 -> 001 chain retains every accepted
host/control case and owns byte/source/target-OS/lease checks. This helper never
pushes. A separate, initially absent observer request is required before builds.
"""
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import re

_spec = spec_from_file_location(
    "_lcb004_observer_private_application_profile",
    Path(__file__).with_name("lcb003_application_host_runtime_publication.py"),
)
application = module_from_spec(_spec)
_spec.loader.exec_module(application)
engine = application.engine
engine.BRANCH = "codex/lcb004-observer"
engine.WORKFLOW = ".github/workflows/lcb004-observer-runtime-publication.yml"
engine.REQUEST = "tools/ci/lcb004_observer_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-10-25-lcb004-observer-publication.md"
engine.BUNDLE_PREFIX = "lcb004-observer-runtime"
engine.REQUEST_VALUE = {
    "schema": "lcb004-observer-publish-request-v1",
    "family": "multi_solver",
    "variant": "fm-cy-pf0-pf1-pf2-in-water-brine",
    "scope": "lcb004-copied-inertial-ledger-and-phased-worker-participation-with-complete003-host-controls",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = dict(engine.CASE_MARKERS) | {
    "test_lcb_inertial_observation": r"(?m)^INERTIAL_OBSERVATION: 504 assertions; 0 failures\s*$",
    "test_native_worker_observation": r"(?m)^NATIVE_WORKER_OBSERVATION: 265 assertions; 0 failures\s*$",
}
engine.CASE_TIMEOUTS = dict(engine.CASE_TIMEOUTS) | {
    "test_lcb_inertial_observation": 180,
    "test_native_worker_observation": 180,
}
engine.EXECUTION_SCOPE = (
    "Import plus all 35 retained 003 host/IN/pressure/shared-contract cases and "
    "the copied nineteen-field Brine IN ledger (504 assertions) and native "
    "worker observation (265 assertions) on each actual target OS. The ledger "
    "fixture checks bounded independent state closure, configured1/4 parity, "
    "retirement, copy isolation, CYPS3 continuation and quarantine. Worker "
    "observations distinguish configured count from the actual maximum distinct "
    "participants in one Phased dispatch, including measured idle and explicitly "
    "unmeasured Serial work. Full ready-PR gates, Water-IN/global scientific "
    "closure, per-worker utilization and campaign/package qualification remain separate"
)
engine.BUILD_EXACT = set(engine.BUILD_EXACT) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/lcb004_observer_runtime_publication.py",
    "tools/ci/test_lcb004_observer_runtime_publication.py",
}

LEDGER_KEYS = frozenset((
    "gravity_y", "impulse_x", "impulse_y", "loss", "support", "remainder",
    "updates", "unit_moves", "density_swaps", "contacts", "rests",
    "velocity_retired", "retired_x", "retired_y", "external_x", "external_y",
    "maximum_read_reach", "maximum_write_reach", "external_speed",
))
UNSIGNED_KEYS = frozenset((
    "updates", "unit_moves", "density_swaps", "contacts", "rests",
    "velocity_retired", "maximum_read_reach", "maximum_write_reach",
))
INERTIAL_FIXTURE = "godot/tests/fixtures/lcb/inertial-adapter-parameters.json"
_verify_application = engine.verify_case_results
_require_application_request = engine.require_publication_request


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        engine.require(key not in result, "Duplicate observer JSON field: " + key)
        result[key] = value
    return result


def _nonfinite(value):
    raise ValueError("Non-finite observer JSON: " + value)


def strict_json(text, label):
    try:
        return json.loads(text, object_pairs_hook=_unique_object, parse_constant=_nonfinite)
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed observer JSON: " + label) from exc


def require_publication_request(source):
    # Preserve the source-bound accepted validator, then disallow duplicate keys
    # that the historical JSON parser could otherwise collapse before checking.
    _require_application_request(source)
    strict_json((engine.ROOT / engine.REQUEST).read_text(encoding="utf-8"), "request")


def _keys(value, expected, label):
    engine.require(isinstance(value, dict) and set(value) == set(expected),
                   "Incomplete observer fields: " + label)


def decimal64(value, unsigned=False):
    engine.require(isinstance(value, str) and
                   re.fullmatch(r"0|[1-9][0-9]*|-[1-9][0-9]*", value) is not None,
                   "Observer value is not a canonical decimal string")
    # Check the length before int(), including Python's large-input bound.
    engine.require(len(value) <= 20, "Observer decimal is outside native64 range")
    number = int(value)
    low, high = (0, (1 << 64) - 1) if unsigned else (-(1 << 63), (1 << 63) - 1)
    engine.require(low <= number <= high, "Observer decimal is outside native64 range")
    return number


def verify_ledger(value):
    _keys(value, ("schema", "ok", "available", "completed_tick", "session_generation",
                  "policy_hash", "extension_identity", "values"), "ledger")
    engine.require(value["schema"] == "lcb-inertial-ledger-observation-v1" and
                   value["ok"] is True and value["available"] is True,
                   "Native ledger is unavailable or refused")
    engine.require(decimal64(value["completed_tick"], True) == 12 and
                   decimal64(value["session_generation"], True) > 0,
                   "Native ledger owner/completed-tick binding differs")
    try:
        oracle = strict_json((engine.ROOT / INERTIAL_FIXTURE).read_text(encoding="utf-8"), "IN fixture")["damping_cases"][1]
        expected = (oracle["policy_hash"], oracle["extension_identity"])
    except (OSError, KeyError, IndexError, TypeError) as exc:
        raise RuntimeError("Missing native ledger fixture identity") from exc
    engine.require(all(isinstance(text, str) and re.fullmatch(r"[0-9a-f]{64}", text) is not None
                       for text in expected) and
                   (value["policy_hash"], value["extension_identity"]) == expected,
                   "Native ledger policy/effective IN identity differs")
    _keys(value["values"], LEDGER_KEYS, "nineteen-field ledger")
    numbers = {key: decimal64(item, key in UNSIGNED_KEYS) for key, item in value["values"].items()}
    engine.require(all(numbers[key] >= 0 for key in ("loss", "support", "remainder")) and
                   all(numbers[key] > 0 for key in ("updates", "unit_moves", "velocity_retired", "retired_y")) and
                   numbers["maximum_read_reach"] == 3 and numbers["maximum_write_reach"] == 2,
                   "Native ledger motion/retirement/reach is not proved")


def verify_participation(rows):
    expected = [("moving", tick, configured) for tick in range(9) for configured in (1, 4)] + [
        ("idle", 1, 4), ("serial-unmeasured", 1, 1)]
    engine.require(isinstance(rows, list) and len(rows) == len(expected),
                   "Incomplete native participation rows")
    multijob = False
    for row, (fixture, tick, configured) in zip(rows, expected):
        fields = {"fixture", "tick", "configured", "observed", "available"}
        fields |= {"visited_cells", "moved_cells"} if fixture == "serial-unmeasured" else {"scheduled_cores"}
        if fixture == "moving" and tick > 0:
            fields.add("maximum_phase_jobs")
        _keys(row, fields, "participation row")
        engine.require(row["fixture"] == fixture and
                       all(type(row[key]) is int and row[key] >= 0 for key in fields - {"fixture", "available"}) and
                       row["tick"] == tick and row["configured"] == configured and
                       type(row["available"]) is bool,
                       "Native participation cohort/type/order differs")
        observed = row["observed"]
        if fixture == "serial-unmeasured":
            engine.require(row["available"] is False and observed == 0 and
                           row["visited_cells"] > 0 and row["moved_cells"] > 0,
                           "Serial work was relabelled as measured participation")
        elif fixture == "idle" or tick == 0:
            engine.require(row["available"] is True and observed == 0 and row["scheduled_cores"] == 0,
                           "Idle/tick-zero participation was fabricated")
        else:
            engine.require(row["available"] is True and row["scheduled_cores"] >= 4 and
                           1 <= observed <= configured and observed <= row["maximum_phase_jobs"] <= row["scheduled_cores"],
                           "Actual Phased participation exceeds its execution bounds")
            if configured == 1:
                engine.require(observed == 1, "Nonempty inline phase did not observe one executor")
            else:
                multijob |= row["maximum_phase_jobs"] >= 2
    engine.require(multijob, "No genuine multiple-job configured-four phase executed")


def _one_value(directory, case, prefix):
    output = (directory / (case + ".log")).read_text(encoding="utf-8")
    engine.require(re.search(r"(?mi)^\s*(?:SCRIPT )?WARNING:", output) is None,
                   "Observer process reported a warning: " + case)
    lines = re.findall(r"(?m)^" + re.escape(prefix) + r" (.*)$", output)
    engine.require(len(lines) == 1, "Missing or duplicate observer result: " + case)
    return strict_json(lines[0], case)


def verify_case_results(directory, report):
    engine.require(isinstance(report, dict) and isinstance(report.get("results"), list) and
                   isinstance(report.get("log_sha256"), dict) and
                   all(isinstance(record, dict) for record in report["results"]),
                   "Malformed observer process report")
    for record in report["results"]:
        engine.require(isinstance(record.get("name"), str) and type(record.get("returncode")) is int and
                       all(key in record and record[key] is None for key in
                           ("capture_error", "timeout_kind", "timeout_diagnostics", "timeout_diagnostic_error")),
                       "Observer process capture/timeout did not complete")
    _verify_application(directory, report)
    verify_ledger(_one_value(directory, "test_lcb_inertial_observation", "INERTIAL_OBSERVATION_LEDGER:"))
    verify_participation(_one_value(directory, "test_native_worker_observation", "NATIVE_WORKER_PARTICIPATION:"))


engine.require_publication_request = require_publication_request
engine.verify_case_results = verify_case_results

if __name__ == "__main__":
    raise SystemExit(engine.main())
