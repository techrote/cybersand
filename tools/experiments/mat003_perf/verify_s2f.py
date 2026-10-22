#!/usr/bin/env python3
"""Independent S2F preflight readback. Never promotes source-only runs to S2 timing."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def check_observation(observed: dict, context: dict, spec: dict) -> None:
    ident = context["id"]
    require(observed["status"] == "passed" and
            observed["stage"] == "S2F-source-feasibility", ident + ": fixture did not pass")
    require(observed["mode"] == "qualify" and
            observed["performance_qualification"] is False,
            ident + ": unadmitted performance measurement")
    require(observed["tick_ns"] == [] and observed["input_ns"] == [] and
            observed["input_tick_ns_separate"] is True,
            ident + ": preflight may not contain timing")
    require(observed["scenario"] == context["scenario"] and
            observed["side"] == context["side"] and
            observed["workers_configured"] == context["workers"] and
            observed["workers_observed"] is False,
            ident + ": wrong fixture context or invented dispatch qualification")
    sample = spec["inputs"]["measured_ticks"]
    warmup = spec["inputs"]["warmup_ticks"]
    require(observed["seed"] == spec["inputs"]["seed"] and
            observed["warmup_ticks"] == warmup and
            observed["sample_ticks"] == sample and
            observed["completed_ticks"] == warmup + sample,
            ident + ": wrong input/clock horizon")
    side = context["side"]
    require(observed["resident_cells"] == side ** 2 and
            observed["chunk_count"] == (side // 128) ** 2,
            ident + ": resident scale differs")
    visited = observed["visits"]
    jobs = observed["phase_jobs"]
    require(len(visited) == sample and len(jobs) == sample and
            all(type(x) is int and x >= 0 for x in visited + jobs),
            ident + ": incomplete/noninteger sample work records")
    positive = sum(x > 0 for x in visited)
    require(observed["positive_visit_ticks"] == positive,
            ident + ": positive-work receipt mismatch")
    if context["scenario"] == "quiet":
        require(positive == 0 and observed["input_calls_after_warmup"] == 0,
                ident + ": quiet must be truly quiescent")
    else:
        expected_input = {"small": 2, "active": 128, "reactive": 32}[context["scenario"]]
        require(positive >= 231 and
                observed["input_calls_after_warmup"] == sample * expected_input,
                ident + ": maintained workload became vacuous")
    if context["scenario"] == "reactive":
        require(observed["reactive_products_observed"] > 0,
                ident + ": current-catalogue product not witnessed")
    else:
        require(observed["reactive_products_observed"] == 0,
                ident + ": unexpected reactive count")
    for field in ("peak_process_rss_bytes", "resident_aggregate_bytes_nonadditive"):
        require(type(observed[field]) is int and observed[field] > 0,
                ident + ": absent or malformed memory witness")


def verify_directory(root: Path) -> dict:
    root = root.resolve()
    errors = []
    checked = []
    try:
        report = json.loads((root / "run.json").read_text())
        spec = json.loads((root / "source/tools/experiments/mat003_perf/s2f_registration.json").read_text())
        s1 = json.loads((root / "source/tools/experiments/mat003_prepass/world_registration.json").read_text())
        require(report["stage"] == spec["stage"] and
                spec["status"] == "preregistered-full-source-and-candidate-twins-untimed",
                "wrong registration stage/status")
        require(report["status"] == "passed-source-context-qualification" and
                report["errors"] == [],
                "collector did not pass full source qualification")
        require(report["preflight_only"] is False and
                report["source_context_qualification"] is True and
                report["candidate_twin_qualification"] is False and
                report["formal_timing_admitted"] is False and
                report["performance_qualification"] is False and
                spec["formal_timing_admitted"] is False and
                spec["performance_comparisons_admitted"] is False,
                "source qualification promoted timing without admission")
        require(report["baseline_native_commit"] == spec["baseline_native_commit"] and
                report["native_control_sha256"] == s1["baseline_control_sha256"],
                "native control identities disagree")
        paths = report["files"]
        require("bin/source-world-qualifier" in paths and
                "sealed-binary.json" in paths and "frozen-inputs.json" in paths,
                "missing binary or immutable identity seal")
        for rel, receipt in paths.items():
            item = Path(rel)
            require(not item.is_absolute() and ".." not in item.parts,
                    "path traversal in evidence manifest")
            path = root / item
            require(path.is_file() and path.stat().st_size == receipt["bytes"] and
                    sha256(path) == receipt["sha256"],
                    "missing/changed evidence: " + rel)
            checked.append(rel)
        frozen = json.loads((root / "frozen-inputs.json").read_text())
        seal = json.loads((root / "sealed-binary.json").read_text())
        require(frozen["input_sha256"] == report["input_sha256"] == seal["source_sha256"],
                "source snapshot changed between freeze and seal")
        require(seal["sha256"] == report["binary_sha256"] ==
                sha256(root / "bin/source-world-qualifier"),
                "sealed compiler output changed")
        for name, expected in s1["baseline_control_sha256"].items():
            require(report["input_sha256"][name] == expected,
                    "registered native dependency drift: " + name)
        require(report["compile"]["exit_code"] == 0 and
                not report["compile"]["timed_out"], "compile failed")
        expected = [row["id"] for row in spec["contexts"]]
        require(len(expected) == 24 and len(set(expected)) == 24,
                "registered full grid mutated")
        require(len(report["processes"]) == 24, "incomplete source qualification suite")
        require([p["id"] for p in report["processes"]] == expected,
                "source qualification order/duplicates changed")
        contexts = {row["id"]: row for row in spec["contexts"]}
        for item in report["processes"]:
            ident = item["id"]
            receipt = item["receipt"]
            require(receipt["exit_code"] == 0 and receipt["timed_out"] is False,
                    "failed/timed-out fixture: " + ident)
            require((root / receipt["stderr"]).read_bytes().strip() == b"",
                    "unexpected fixture stderr: " + ident)
            observed = json.loads((root / receipt["stdout"]).read_text())
            check_observation(observed, contexts[ident], spec)
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append(str(exc))
    return {"stage": "S2F-source-feasibility", "preflight_only": False,
            "source_context_qualification": True, "performance_qualification": False,
            "status": "passed" if not errors else "failed",
            "checked_file_count": len(checked),
            "checked_cases": expected if "expected" in locals() else [],
            "errors": errors}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = verify_directory(args.output)
    print(json.dumps(result, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
