#!/usr/bin/env python3
"""Independent reject-by-default readback for MAT-003 S2A apparatus qualification."""
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


def qualification_cases(reg: dict) -> list[dict]:
    seen: set[tuple[str, str]] = set()
    rows: list[dict] = []
    for contrast in reg["contrasts"]:
        anchor_key = contrast["anchor"]
        anchor = reg["anchors"][anchor_key]
        for arm in (contrast["a"], contrast["b"]):
            key = (arm, anchor_key)
            if key in seen:
                continue
            seen.add(key)
            rows.append({"arm_id": arm, "anchor_key": anchor_key, **anchor})
    return rows


def check_result(value: dict, case: dict) -> None:
    ident = case["arm_id"] + "/" + case["id"]
    require(value["status"] == "passed" and value["stage"] == "S2A-paired-performance",
            ident + ": qualifier did not pass")
    require(value["mode"] == "qualify" and value["performance_qualification"] is False and
            value["formal_timing_admitted"] is False,
            ident + ": qualifier promoted performance")
    require(value["tick_ns"] == [] and value["input_ns"] == [] and value["startup_ns"] == 0,
            ident + ": qualifier emitted timing")
    require(value["arm_id"] == case["arm_id"] and value["scenario"] == case["scenario"] and
            value["side"] == case["side"] and value["workers_configured"] == case["workers"],
            ident + ": qualifier identity mismatch")
    require(value["seed"] == 204 and value["warmup_ticks"] == 120 and
            value["sample_ticks"] == 256 and value["completed_ticks"] == 376,
            ident + ": wrong registered horizon")
    require(value["resident_cells"] == case["side"] ** 2 and
            value["chunk_count"] == (case["side"] // 128) ** 2,
            ident + ": resident geometry mismatch")
    require(len(value["visits"]) == 256 and len(value["phase_jobs"]) == 256 and
            all(type(x) is int and x >= 0 for x in value["visits"] + value["phase_jobs"]),
            ident + ": malformed work arrays")
    require(value["positive_visit_ticks"] == sum(x > 0 for x in value["visits"]),
            ident + ": positive work tally mismatch")
    if case["scenario"] == "quiet":
        require(value["positive_visit_ticks"] == 0 and value["sample_input_calls"] == 0,
                ident + ": quiet anchor was not quiescent")
    else:
        require(value["positive_visit_ticks"] >= 231 and value["sample_input_calls"] == 128 * 256,
                ident + ": active anchor became vacuous")
    require(value["initial_water_mass"] + value["warmup_water_added"] +
            value["sample_water_added"] - value["warmup_water_removed"] -
            value["sample_water_removed"] == value["final_water_mass"] ==
            value["summary"]["water_mass"],
            ident + ": Water ledger mismatch")
    require(sum(value["summary"][key] for key in ("empty", "water", "sand", "wall", "other")) ==
            value["resident_cells"], ident + ": material summary does not cover residency")
    expected_clear = [256] if value["epoch_bits"] == 8 else []
    require(value["clear_ticks"] == expected_clear,
            ident + ": natural clear derivation changed")
    require(type(value["content_hash"]) is int and type(value["state_hash"]) is int and
            value["peak_process_rss_bytes"] > 0,
            ident + ": missing final evidence")


def verify(root: Path) -> dict:
    root = root.resolve()
    errors: list[str] = []
    checked_files: list[str] = []
    checked_cases: list[str] = []
    try:
        run = json.loads((root / "run.json").read_text())
        reg = json.loads((root / "source/tools/experiments/mat003_s2a/registration.json").read_text())
        require(reg["registration_version"] == 2 and
                reg["status"] == "preregistered-apparatus-qualification-only" and
                reg["formal_timing_admitted"] is False and
                reg["performance_comparisons_admitted"] is False,
                "wrong S2A preregistration state")
        require(run["status"] == "passed-apparatus-qualification" and
                run["apparatus_qualification"] is True and run["errors"] == [],
                "S2A apparatus collector did not pass")
        require(run["formal_timing_admitted"] is False and
                run["performance_comparisons_admitted"] is False,
                "S2A apparatus run promoted timing")
        require(len(reg["contrasts"]) == 16 and
                reg["pair_orders"] == ["AB", "BA", "AB", "BA", "AB", "BA", "AB"] and
                reg["run_order"]["primary_processes"] == 224,
                "S2A contrast or pair registration changed")
        require(run["compile_count"] == reg["execution"]["maximum_builds"] == 17 and
                run["qualification_process_count"] ==
                reg["execution"]["maximum_qualification_processes"] == 25,
                "S2A build/qualification count mismatch")

        for rel, receipt in run["files"].items():
            item = Path(rel)
            require(not item.is_absolute() and ".." not in item.parts,
                    "path traversal in S2A evidence manifest")
            path = root / item
            require(path.is_file() and path.stat().st_size == receipt["bytes"] and
                    digest(path) == receipt["sha256"],
                    "missing/changed S2A evidence: " + rel)
            checked_files.append(rel)

        seal = json.loads((root / "sealed-binaries.json").read_text())
        require(seal["status"] == "sealed-before-qualification-and-timing" and
                seal["formal_timing_admitted"] is False and
                seal["source_head"] == run["source_head"],
                "S2A binary seal malformed")
        require(set(seal["binaries"]) == set(run["binaries"]) and len(seal["binaries"]) == 17,
                "S2A sealed binary set mismatch")
        for arm, row in run["binaries"].items():
            sealed = seal["binaries"][arm]
            binary = root / sealed["path"]
            require(digest(binary) == sealed["sha256"] == row["sha256"],
                    "S2A binary hash mismatch: " + arm)
            require(sealed["overlay_tree_sha256"] == row["overlay_tree_sha256"] ==
                    run["overlays"][arm]["tree_sha256"],
                    "S2A overlay identity mismatch: " + arm)
            argv = row["compile"]["argv"]
            require("-DMAT003_TWIN_OBSERVERS=0" in argv and
                    any(arg.endswith("tools/experiments/mat003_s2a/fixture.cpp") for arg in argv),
                    "S2A performance binary compile contract changed: " + arm)

        expected = qualification_cases(reg)
        require(len(expected) == 25, "S2A expected qualifier context count changed")
        expected_ids = [row["arm_id"] + "__" + row["id"] for row in expected]
        require([row["id"] for row in run["qualification_cases"]] == expected_ids,
                "S2A qualifier order/duplication changed")

        values: dict[tuple[str, str], dict] = {}
        expected_by_id = {row["arm_id"] + "__" + row["id"]: row for row in expected}
        for row in run["qualification_cases"]:
            case = expected_by_id[row["id"]]
            receipt = row["receipt"]
            require(receipt["exit_code"] == 0 and receipt["timed_out"] is False,
                    row["id"] + ": failed/timed out")
            require((root / receipt["stderr"]).read_bytes().strip() == b"",
                    row["id"] + ": stderr not empty")
            value = json.loads((root / receipt["stdout"]).read_text())
            check_result(value, case)
            values[(case["arm_id"], case["anchor_key"])] = value
            checked_cases.append(row["id"])

        semantic_fields = (
            "scenario", "side", "workers_configured", "seed", "warmup_ticks",
            "sample_ticks", "completed_ticks", "resident_cells", "chunk_count",
            "positive_visit_ticks", "warmup_input_calls", "sample_input_calls",
            "warmup_water_added", "warmup_water_removed", "sample_water_added",
            "sample_water_removed", "initial_water_mass", "final_water_mass",
            "content_hash", "summary", "clear_ticks", "visits", "phase_jobs"
        )
        references = {
            "active_512_w4": values[("C64-E8-source", "active_512_w4")],
            "quiet_2048_w1": values[("C64-E8-word", "quiet_2048_w1")]
        }
        for (arm, anchor_key), value in values.items():
            reference = references[anchor_key]
            for field in semantic_fields:
                require(value[field] == reference[field],
                        arm + "/" + anchor_key + ": source-matched semantic/work mismatch: " + field)

        fixture = (root / "source/tools/experiments/mat003_s2a/fixture.cpp").read_text()
        require('p.mode != "qualify" && p.mode != "measure"' in fixture and
                'const bool measured = p.mode == "measure";' in fixture and
                'Clock::now()' in fixture,
                "frozen S2A binary source does not contain dormant measure path")
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append(str(exc))
    return {
        "stage": "S2A-apparatus-qualification",
        "status": "passed" if not errors else "failed",
        "formal_timing_admitted": False,
        "checked_file_count": len(checked_files),
        "checked_case_count": len(checked_cases),
        "checked_cases": checked_cases,
        "errors": errors
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    result = verify(args.root)
    print(json.dumps(result, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
