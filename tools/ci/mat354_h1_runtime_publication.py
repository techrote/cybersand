#!/usr/bin/env python3
"""Exact-branch H1 runtime publication profile; this helper never pushes.

Reuse the retained four-path publisher without changing its source, build,
target-OS execution or LFS staging contract. An absent explicit request leaves
this lane unarmed. Historical requests cannot authorize this profile.
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
    "_mat354_h1_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_historical_workflow, _historical_request = engine.WORKFLOW, engine.REQUEST
engine.BRANCH = "fix/mat354b-moltenglass-deadline-20261104"
engine.WORKFLOW = ".github/workflows/mat354-h1-runtime-publication.yml"
engine.REQUEST = "tools/ci/mat354_h1_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-04-mat354-h1-qualification.md"
engine.BUNDLE_PREFIX = "mat354-h1-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.PRESSURE_CASE = "godot/tests/test_material_cooling_h1.gd"
engine.REQUEST_VALUE = {
    "schema": "mat354-h1-publish-request-v1",
    "family": "material_cooling",
    "variant": "molten_glass_future_deadline",
    "scope": "h1-only-reviewed-source-transition-and-source-matched-desktop-runtimes",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_material_cooling_h1": r"(?m)^H1_GODOT_PROOF: (\{.+\})\s*$",
    **{name: engine.CASE_MARKERS[name] for name in (
        "test_water_feel_integration", "test_liquid_solver_policy",
        "test_liquid_policy_worker", "test_lcb_pressure_reference",
        "test_microscenario_native_observation",
    )},
}
engine.CASE_TIMEOUTS = {}
engine.EXECUTION_SCOPE = (
    "Import and six H1 four-phase cooling/conversion/hot180 retirement, Water Feel, "
    "liquid-policy admission/refusal, worker-policy, pressure-reference and native-observation "
    "controls on each actual target OS, after ordinary and ASan/UBSan native H1 evidence; "
    "full exact-head CI, performance disposition and independent review remain separate"
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_historical_workflow, _historical_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/mat354_h1_runtime_publication.py", "tools/ci/test_mat354_h1_runtime_publication.py",
    "tools/ci/execution_policy.py", "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json", "godot/tests/support/ci_execution_policy.json",
    "tools/material_catalogue/compatibility.py", "tools/material_catalogue/h1_transition.py",
    "tools/material_catalogue/test_compatibility.py", "tools/material_catalogue/test_h1_transition.py",
    "materials/catalogue/compatibility-lock.json", "materials/catalogue/h1-source-transition.json",
    "tools/material_cooling_h1/qualify.py", "tools/material_liveness/run.py", "tools/material_liveness/reduce.py",
    "docs/audits/2026-11-04-mat354-h1-preregistration.md",
}
_verify_bundle = engine.verify_bundle
_verify_case_results = engine.verify_case_results

H1_SCOPE = "actual native cooling and hot180 retirement; native standalone owns distributed-worker proof"
H1_PHASES = ((0, 11, 4, 720), (1, 8, 1, 717), (2, 10, 2, 718), (3, 26, 3, 719))
NATIVE_CASES = (
    "phase-0", "zero-phase-0", "phase-1", "zero-phase-1",
    "phase-2", "zero-phase-2", "phase-3", "zero-phase-3",
    "boundary-31-8", "boundary-32-8", "boundary-63-8", "boundary-64-8",
    "boundary-127-8", "boundary-128-8", "boundary--1-8", "boundary--129--1",
    "molten_pair", "molten_pool_small", "molten_pool_large", "molten_hot",
    "hot-above180-reset", "eight-visible-heat-neighbours", "spark-is-not-thermal-heat",
    "last-heat-after-first-pair", "shared-molten-ice-pair-mercury",
    "source-masked-exactly-at-due", "same-source-save-continuation",
    "source-moves-across-activity-seam", "source-replaced-with-glass",
    "heat-partner-converts-natively-to-glass",
)
# Explicit registered trace coverage, independent of the log's PASS labels.
# Eight heat-neighbour subcases reuse one replica name and each restart at1.
# Restored save replicas resume the captured tick2 state at tick3.
_ISOLATED_REPLICAS = ("q3-w1", "q3-w4", "q1024-w1", "q1024-w4")
NATIVE_TICK_INVENTORY = {
    **{("phase-" + str(phase), replica): tuple(range(1, 769))
       for phase in range(4) for replica in _ISOLATED_REPLICAS},
    **{("zero-phase-" + str(phase), replica): tuple(range(1, 49))
       for phase in range(4) for replica in _ISOLATED_REPLICAS},
    **{(case, replica): tuple(range(1, 49))
       for case in ("boundary-31-8", "boundary-32-8", "boundary-63-8", "boundary-64-8",
                    "boundary-127-8", "boundary-128-8", "boundary--1-8", "boundary--129--1")
       for replica in _ISOLATED_REPLICAS},
    **{(case, replica): tuple(range(1, 129))
       for case in ("molten_pair", "molten_pool_small", "molten_pool_large", "molten_hot")
       for replica in ("w1", "w4")},
    **{("hot-above180-reset", replica): tuple(range(1, 33)) for replica in ("w1", "w4")},
    ("eight-visible-heat-neighbours", "w1"): tuple(range(1, 33)) * 8,
    ("spark-is-not-thermal-heat", "visible"): (1,),
    ("spark-is-not-thermal-heat", "masked"): (1,),
    ("last-heat-after-first-pair", "w1"): (1,),
    **{("shared-molten-ice-pair-mercury", replica): tuple(range(1, 769))
       for replica in ("w1", "w4", "awake")},
    ("source-masked-exactly-at-due", "w1"): tuple(range(1, 65)),
    ("same-source-save-continuation", "original"): tuple(range(1, 51)),
    ("same-source-save-continuation", "restored-w1"): tuple(range(3, 51)),
    ("same-source-save-continuation", "restored-w4"): tuple(range(3, 51)),
    **{("source-moves-across-activity-seam", replica): tuple(range(1, 49)) for replica in ("w1", "w4")},
    ("source-replaced-with-glass", "w1"): tuple(range(1, 33)),
    ("heat-partner-converts-natively-to-glass", "w1"): tuple(range(1, 49)),
}
engine.require({case for case, _ in NATIVE_TICK_INVENTORY} == set(NATIVE_CASES),
               "H1 native case and trace inventories differ")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        engine.require(key not in result, "Duplicate H1 evidence field")
        result[key] = value
    return result


def parse_json(text):
    try:
        return json.loads(text, object_pairs_hook=unique_object)
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed H1 evidence JSON") from exc


def focused_cases(discovered):
    """Keep every selected current-policy watchdog, flag and display bit."""
    engine.require(set(engine.CASE_MARKERS).issubset(discovered), "Required focused regression is missing")
    return [engine.runner.Case(
        "import", ("--editor", "--quit"),
        engine.runner.execution_policy.watchdog_seconds("godot_import_seconds"), 3.0,
    )] + [discovered[name] for name in engine.CASE_MARKERS]


def verify_h1_godot(text):
    rows = re.findall(engine.CASE_MARKERS["test_material_cooling_h1"], text)
    engine.require(len(rows) == 1, "Missing or duplicate H1 Godot completion")
    result = parse_json(rows[0])
    engine.require(isinstance(result, dict) and set(result) == {
        "schema", "assertions", "failures", "cohorts", "scope",
    }, "Incomplete H1 Godot proof")
    engine.require(result["schema"] == "mat354.h1.godot.v1" and result["scope"] == H1_SCOPE,
                   "Wrong H1 Godot evidence identity")
    engine.require(type(result["assertions"]) is int and result["assertions"] >= 13056,
                   "H1 Godot assertions do not cover the registered cooling and hot controls")
    engine.require(type(result["failures"]) is int and result["failures"] == 0,
                   "H1 Godot proof contains failures")
    engine.require(isinstance(result["cohorts"], list) and len(result["cohorts"]) == 4,
                   "Incomplete H1 phase cohorts")
    for row, (phase, x, first, conversion) in zip(result["cohorts"], H1_PHASES):
        expected = {"phase": phase, "x": x, "first_decrement_tick": first,
                    "conversion_tick": conversion, "completed_ticks": 768,
                    "configured_workers": [1, 4], "actual_distributed_workers_claimed": False}
        engine.require(isinstance(row, dict) and set(row) == set(expected) | {"physical_hash"},
                       "Incomplete H1 phase evidence")
        for key, value in expected.items():
            engine.require(type(row[key]) is type(value) and row[key] == value,
                           "H1 phase/conversion/worker evidence differs: " + key)
        engine.require(all(type(value) is int for value in row["configured_workers"]),
                       "H1 configured worker identity is malformed")
        engine.require(isinstance(row["physical_hash"], str)
                       and re.fullmatch(r"[0-9a-f]{16}", row["physical_hash"]) is not None,
                       "Missing H1 physical-state evidence")
    return result


def verify_case_results(directory, report):
    _verify_case_results(directory, report)
    verify_h1_godot((directory / "test_material_cooling_h1.log").read_text(encoding="utf-8"))


def verify_bundle(directory, platform, source, validated):
    manifest = _verify_bundle(directory, platform, source, validated)
    if validated:
        expected = ("mat354-h1-runtime-attempt-" + manifest["workflow_attempt"]
                    + "-" + platform + "-" + os.environ["GITHUB_RUN_ID"] + "/validation.json")
        engine.require(manifest.get("validation_output") == expected,
                       "H1 artifact identity differs from its validated attempt")
        report = json.loads((directory / "validation.json").read_text(encoding="utf-8"))
        engine.require(report.get("scope") == engine.EXECUTION_SCOPE, "H1 runtime scope differs")
    return manifest


def verify_native_text(text):
    """Read actual native traces without asserting a hosted publication origin."""
    engine.require(re.search(r"(?im)\b(?:error|runtime error|AddressSanitizer|UndefinedBehaviorSanitizer|skipped)\b", text) is None,
                   "Native H1 log contains an error or skip")
    rows = [parse_json(line) for line in text.splitlines() if line.strip()]
    engine.require(bool(rows) and all(isinstance(row, dict) and row.get("type") in {
        "h1_tick", "h1_case", "h1_regression_summary", "h1_regression_metadata", "h1_move_deadlines",
    } for row in rows), "Unexpected or absent native H1 evidence")
    metadata = [row for row in rows if row["type"] == "h1_regression_metadata"]
    engine.require(metadata == [{"type": "h1_regression_metadata", "kernel_entry_proxy_scope":
        "stationary downward rejections plus Glass conversions; successful motion uses separate actual move counters"}]
        and rows[0] == metadata[0], "Missing native H1 execution-counter scope")
    completed = [row for row in rows if row["type"] == "h1_case"]
    engine.require(completed == [{"type": "h1_case", "case": name, "status": "PASS"} for name in NATIVE_CASES],
                   "Incomplete, duplicate or reordered native H1 case coverage")
    summaries = [row for row in rows if row["type"] == "h1_regression_summary"]
    engine.require(summaries == [{"type": "h1_regression_summary", "status": "PASS"}]
                   and rows[-1] == summaries[0], "Missing native H1 terminal completion")
    ticks = [row for row in rows if row["type"] == "h1_tick"]
    actual_ticks = {key: [] for key in NATIVE_TICK_INVENTORY}
    for row in ticks:
        engine.require(isinstance(row.get("case"), str) and isinstance(row.get("replica"), str),
                       "Malformed native H1 case/replica identity")
        key = row["case"], row["replica"]
        engine.require(key in actual_ticks, "Unknown native H1 case/replica trace")
        engine.require(type(row.get("tick")) is int, "Malformed native H1 tick")
        for field in ("physical_hash", "tuple_hash"):
            engine.require(isinstance(row.get(field), str) and re.fullmatch(r"[0-9a-f]{16}", row[field]) is not None,
                           "Malformed native H1 " + field)
        actual_ticks[key].append(row["tick"])
    for key, expected in NATIVE_TICK_INVENTORY.items():
        engine.require(tuple(actual_ticks[key]) == expected,
                       "Incomplete, duplicate or reordered native H1 trace: " + "/".join(key))
    moves = [row for row in rows if row["type"] == "h1_move_deadlines"]
    engine.require([row.get("tick") for row in moves] == list(range(1, 49)),
                   "Incomplete native H1 relocation deadline evidence")
    engine.require(all(row.get("old_block", {}).get("due") == 0 for row in moves if row["tick"] >= 4),
                   "Moved native H1 source retained an obsolete deadline")
    phase_records = 0
    for phase, _x, first, conversion in H1_PHASES:
        replicas = {}
        for replica in ("q3-w1", "q3-w4", "q1024-w1", "q1024-w4"):
            actual = [row for row in ticks if row.get("case") == "phase-" + str(phase)
                      and row.get("replica") == replica]
            engine.require(all(type(row.get("tick")) is int for row in actual)
                           and [row.get("tick") for row in actual] == list(range(1, 769)),
                           "Incomplete or duplicate native cooling trajectory")
            for row in actual:
                tick = row["tick"]
                expected_a = max(0, 180 - max(0, (tick - first) // 4 + 1))
                engine.require(type(row.get("state_a")) is int and row["state_a"] == expected_a
                               and type(row.get("material")) is int and row["material"] == (35 if tick >= conversion else 36),
                               "Native H1 countdown/conversion trajectory differs")
                if tick <= conversion and tick % 4 == phase:
                    engine.require(type(row.get("kernel_entries_world")) is int and row["kernel_entries_world"] == 1,
                                   "Missing actual due-lane cooling-kernel execution")
                if replica.startswith("q3") and tick > 744:
                    engine.require(row.get("scheduled_jobs") == 0 and row.get("block_after", {}).get("due") == 0,
                                   "Native H1 converted region did not retire")
            replicas[replica] = actual
            phase_records += len(actual)
        for left, right in (("q3-w1", "q3-w4"), ("q1024-w1", "q1024-w4")):
            engine.require(all(a.get("physical_hash") == b.get("physical_hash")
                               and isinstance(a.get("physical_hash"), str) and a["physical_hash"]
                               for a, b in zip(replicas[left], replicas[right])),
                           "Native H1 configured-worker physical-state divergence")
    return {
        "cases": list(NATIVE_CASES),
        "trace_rows": len(ticks), "phase_trace_rows": phase_records,
        "trace_cohorts": [{"case": case, "replica": replica, "rows": len(sequence),
                           "first_tick": sequence[0], "last_tick": sequence[-1]}
                          for (case, replica), sequence in NATIVE_TICK_INVENTORY.items()],
        "relocation_deadline_rows": len(moves),
        "scope": "Focused H1 native traces; full campaign, distributed-claimant and performance evidence remain separate",
    }


def verify_native(log, output, source):
    """Bind complete actual H1 native traces to their hosted publication source."""
    context = engine.context(source)
    data = log.read_bytes()
    receipt = context | verify_native_text(data.decode("utf-8")) | {
        "schema": "mat354-h1-native-publication-gate-v1",
        "log_sha256": hashlib.sha256(data).hexdigest(), "log_bytes": len(data),
    }
    engine.write_json(output, receipt)
    return receipt


engine.focused_cases = focused_cases
engine.verify_case_results = verify_case_results
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
