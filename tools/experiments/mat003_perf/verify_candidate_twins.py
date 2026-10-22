#!/usr/bin/env python3
"""Independent reject-by-default readback for MAT-003 untimed candidate twins."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def normalized_compile(argv: list[str]) -> list[str]:
    out: list[str] = []
    skip_output = False
    for item in argv:
        if item.startswith("-DMAT003_TWIN_OBSERVERS="):
            out.append("-DMAT003_TWIN_OBSERVERS=<MODE>")
        elif skip_output:
            out.append("<BINARY>")
            skip_output = False
        else:
            out.append(item)
            if item == "-o":
                skip_output = True
    return out


def check_case(value: dict, arm_id: str, mode: str, anchor: dict) -> None:
    ident = arm_id + "/" + mode + "/" + anchor["id"]
    require(value["status"] == "passed" and value["stage"] == "S2-candidate-twins",
            ident + ": fixture did not pass")
    require(value["performance_qualification"] is False and
            value["formal_timing_admitted"] is False and
            value["tick_ns"] == [] and value["input_ns"] == [],
            ident + ": candidate qualification contains unadmitted timing")
    require(value["arm_id"] == arm_id and value["observer_mode"] == mode,
            ident + ": arm/mode identity mismatch")
    require(value["scenario"] == anchor["scenario"] and
            value["side"] == anchor["side"] and
            value["workers_configured"] == anchor["workers"] and
            value["seed"] == 204 and value["warmup_ticks"] == 120 and
            value["sample_ticks"] == 256 and value["completed_ticks"] == 376,
            ident + ": wrong registered fixture parameters")
    require(value["resident_cells"] == anchor["side"] ** 2 and
            value["chunk_count"] == (anchor["side"] // 128) ** 2,
            ident + ": wrong resident geometry")
    visits = value["visits"]
    jobs = value["phase_jobs"]
    require(len(visits) == 256 and len(jobs) == 256 and
            all(type(x) is int and x >= 0 for x in visits + jobs),
            ident + ": malformed work arrays")
    require(value["positive_visit_ticks"] == sum(x > 0 for x in visits),
            ident + ": positive work tally mismatch")
    if anchor["scenario"] == "quiet":
        require(value["positive_visit_ticks"] == 0 and
                value["input_calls_after_warmup"] == 0,
                ident + ": quiet anchor not quiescent")
    else:
        require(value["positive_visit_ticks"] >= 231 and
                value["input_calls_after_warmup"] == 128 * 256,
                ident + ": active anchor became vacuous")
    require(value["water_mass_before_sample"] + value["input_water_added"] -
            value["input_water_removed"] == value["water_mass_after_sample"] ==
            value["summary"]["water_mass"],
            ident + ": Water source/sink ledger does not reconcile")
    require(sum(value["summary"][key] for key in ("empty", "water", "sand", "wall", "other")) ==
            value["resident_cells"], ident + ": final material summary does not cover residency")
    require(type(value["content_hash"]) is int and type(value["state_hash"]) is int,
            ident + ": missing semantic hashes")
    require(type(value["peak_process_rss_bytes"]) is int and value["peak_process_rss_bytes"] > 0,
            ident + ": missing process memory witness")
    if mode == "timing-twin":
        require(value["observer_compiled"] is False and
                value["dispatch_calls"] == value["dispatched_tasks"] == value["worker_tasks"] == 0,
                ident + ": observer-off twin retained observer work")
    else:
        require(value["observer_compiled"] is True, ident + ": observed twin not observer-enabled")
        if arm_id != "C64-E8-source" and anchor["workers"] == 4:
            require(value["dispatch_calls"] > 0 and value["dispatched_tasks"] > 0 and
                    value["worker_tasks"] > 0,
                    ident + ": observed candidate did not prove worker dispatch/execution")


def verify(root: Path, source_evidence: Path) -> dict:
    root = root.resolve()
    source_evidence = source_evidence.resolve()
    errors: list[str] = []
    checked: list[str] = []
    checked_cases: list[str] = []
    try:
        run = json.loads((root / "run.json").read_text())
        spec = json.loads((root / "source/tools/experiments/mat003_perf/s2f_registration.json").read_text())
        twin = spec["candidate_twin_qualification"]
        require(run["stage"] == "S2-candidate-twins" and
                run["status"] == "passed-candidate-twins" and run["errors"] == [],
                "candidate twin collector did not pass")
        require(run["performance_qualification"] is False and
                run["formal_timing_admitted"] is False and
                spec["formal_timing_admitted"] is False and
                spec["performance_comparisons_admitted"] is False and
                twin["timed"] is False,
                "candidate twins promoted timing without admission")
        require(run["compile_count"] == twin["execution"]["maximum_arm_builds"] == 34 and
                run["fixture_count"] == twin["execution"]["maximum_fixture_processes"] == 68,
                "candidate twin process matrix incomplete")

        for rel, receipt in run["files"].items():
            item = Path(rel)
            require(not item.is_absolute() and ".." not in item.parts,
                    "path traversal in twin evidence manifest")
            path = root / item
            require(path.is_file() and path.stat().st_size == receipt["bytes"] and
                    digest(path) == receipt["sha256"],
                    "missing/changed twin evidence: " + rel)
            checked.append(rel)

        source_run = json.loads((source_evidence / "run.json").read_text())
        require(source_run["status"] == "passed-source-context-qualification" and
                source_run["source_head"] == run["source_head"],
                "source prerequisite does not bind candidate head")
        require(digest(source_evidence / "run.json") == run["source_evidence"]["run_sha256"],
                "source prerequisite run changed after twin collection")
        source_cases: dict[str, dict] = {}
        for process in source_run["processes"]:
            receipt = process["receipt"]
            require(receipt["exit_code"] == 0 and receipt["timed_out"] is False,
                    "source prerequisite contains failed process")
            source_cases[process["id"]] = json.loads(
                (source_evidence / receipt["stdout"]).read_text())
        require(len(source_cases) == 24, "source prerequisite is not the full 24-context grid")

        arms = twin["arms"]
        modes = twin["observer_modes"]
        anchors = twin["anchors"]
        require(len(arms) == 17 and modes == ["observed", "timing-twin"] and len(anchors) == 2,
                "candidate twin registration matrix changed")
        expected_ids = [
            arm + "__" + mode + "__" + anchor["id"]
            for arm in arms for mode in modes for anchor in anchors
        ]
        require([item["id"] for item in run["processes"]] == expected_ids,
                "candidate twin process order, duplication or omission changed")

        values: dict[tuple[str, str, str], dict] = {}
        anchor_map = {a["id"]: a for a in anchors}
        for process in run["processes"]:
            arm = process["arm_id"]
            mode = process["observer_mode"]
            anchor_id = process["anchor_id"]
            require(process["id"] == arm + "__" + mode + "__" + anchor_id,
                    "candidate process identity mismatch")
            receipt = process["receipt"]
            require(receipt["exit_code"] == 0 and receipt["timed_out"] is False,
                    process["id"] + ": failed/timed out")
            require((root / receipt["stderr"]).read_bytes().strip() == b"",
                    process["id"] + ": fixture stderr not empty")
            value = json.loads((root / receipt["stdout"]).read_text())
            check_case(value, arm, mode, anchor_map[anchor_id])
            values[(arm, mode, anchor_id)] = value
            checked_cases.append(process["id"])

        pair_fields = (
            "scenario", "side", "workers_configured", "seed", "warmup_ticks",
            "sample_ticks", "completed_ticks", "resident_cells", "chunk_count",
            "positive_visit_ticks", "input_calls_after_warmup", "input_water_added",
            "input_water_removed", "water_mass_before_sample", "water_mass_after_sample",
            "content_hash", "state_hash", "cell_stride", "cell_alignment", "summary",
            "visits", "phase_jobs",
        )
        semantic_fields = (
            "scenario", "side", "workers_configured", "seed", "warmup_ticks",
            "sample_ticks", "completed_ticks", "resident_cells", "chunk_count",
            "positive_visit_ticks", "input_calls_after_warmup", "input_water_added",
            "input_water_removed", "water_mass_before_sample", "water_mass_after_sample",
            "content_hash", "summary", "visits", "phase_jobs",
        )

        for arm in arms:
            observed_build = run["binaries"][arm + "/observed"]
            timing_build = run["binaries"][arm + "/timing-twin"]
            require(observed_build["overlay_tree_sha256"] == timing_build["overlay_tree_sha256"] ==
                    run["overlays"][arm]["tree_sha256"],
                    arm + ": twin binaries do not share one immutable overlay")
            require(observed_build["observer_define"] == 1 and timing_build["observer_define"] == 0,
                    arm + ": wrong twin observer definitions")
            require(normalized_compile(observed_build["compile"]["argv"]) ==
                    normalized_compile(timing_build["compile"]["argv"]),
                    arm + ": twin compile commands differ beyond observer definition/output")
            for anchor in anchors:
                a = values[(arm, "observed", anchor["id"])]
                b = values[(arm, "timing-twin", anchor["id"])]
                for field in pair_fields:
                    require(a[field] == b[field],
                            arm + "/" + anchor["id"] + ": observer twin semantic/work mismatch: " + field)

        for anchor in anchors:
            anchor_id = anchor["id"]
            reference = values[("C64-E8-source", "timing-twin", anchor_id)]
            source = source_cases[anchor_id]
            require(reference["content_hash"] == source["source_world_content_hash"] and
                    reference["state_hash"] == source["source_world_state_hash"] and
                    reference["visits"] == source["visits"] and
                    reference["phase_jobs"] == source["phase_jobs"] and
                    reference["input_calls_after_warmup"] == source["input_calls_after_warmup"] and
                    reference["positive_visit_ticks"] == source["positive_visit_ticks"],
                    "source twin does not reproduce full-source prerequisite: " + anchor_id)
            for arm in arms:
                candidate = values[(arm, "timing-twin", anchor_id)]
                for field in semantic_fields:
                    require(candidate[field] == reference[field],
                            arm + "/" + anchor_id + ": candidate diverges from source semantics/work: " + field)

        seal = json.loads((root / "sealed-binaries.json").read_text())
        require(seal["status"] == "sealed-before-any-fixture-execution" and
                seal["source_head"] == run["source_head"] and
                seal["performance_qualification"] is False,
                "binary seal malformed")
        require(set(seal["binaries"]) == set(run["binaries"]),
                "sealed binary set differs from executed binary set")
        for key, value in seal["binaries"].items():
            binary = root / value["path"]
            require(digest(binary) == value["sha256"] == run["binaries"][key]["sha256"],
                    "sealed/executed binary digest mismatch: " + key)
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append(str(exc))
    return {
        "stage": "S2-candidate-twins",
        "performance_qualification": False,
        "formal_timing_admitted": False,
        "status": "passed" if not errors else "failed",
        "checked_file_count": len(checked),
        "checked_case_count": len(checked_cases),
        "checked_cases": checked_cases,
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--source-evidence", required=True, type=Path)
    args = parser.parse_args()
    result = verify(args.root, args.source_evidence)
    print(json.dumps(result, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
