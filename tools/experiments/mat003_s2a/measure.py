#!/usr/bin/env python3
"""Execute the preregistered MAT-003 S2A paired timing matrix after explicit admission."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path("tools/experiments/mat003_s2a")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def dump(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def command(argv: list[str], cwd: Path, output: Path, label: str,
            timeout: int, environment: dict[str, str]) -> dict:
    out = output / (label + ".stdout")
    err = output / (label + ".stderr")
    out.parent.mkdir(parents=True, exist_ok=True)
    row = {"argv": argv, "cwd": str(cwd), "timeout": timeout,
           "stdout": out.relative_to(output).as_posix(),
           "stderr": err.relative_to(output).as_posix(),
           "exit_code": None, "timed_out": False}
    with out.open("wb") as stdout, err.open("wb") as stderr:
        try:
            completed = subprocess.run(argv, cwd=cwd, env=environment,
                                       stdout=stdout, stderr=stderr,
                                       timeout=timeout, check=False)
            row["exit_code"] = completed.returncode
        except subprocess.TimeoutExpired:
            row["timed_out"] = True
        except OSError as exc:
            stderr.write(str(exc).encode("utf-8"))
            row["exit_code"] = -1
    return row


def succeeded(row: dict) -> bool:
    return row["exit_code"] == 0 and row["timed_out"] is False


def nearest_rank(values: list[int], p: float) -> int:
    if not values:
        raise ValueError("empty sample")
    ordered = sorted(values)
    rank = max(1, math.ceil(p * len(ordered)))
    return ordered[rank - 1]


def timing_stats(values: list[int]) -> dict:
    if not values:
        raise ValueError("empty timing sample")
    total = sum(values)
    return {
        "count": len(values),
        "total_ns": total,
        "mean_ns": total / len(values),
        "p50_ns": nearest_rank(values, 0.50),
        "p95_ns": nearest_rank(values, 0.95),
        "p99_ns": nearest_rank(values, 0.99),
        "max_ns": max(values),
    }


def schedule(reg: dict) -> list[dict]:
    rows: list[dict] = []
    ordinal = 0
    for contrast in reg["contrasts"]:
        anchor = reg["anchors"][contrast["anchor"]]
        for pair_index, order in enumerate(reg["pair_orders"]):
            arms = (contrast["a"], contrast["b"]) if order == "AB" else (contrast["b"], contrast["a"])
            for within_pair, arm in enumerate(arms):
                ordinal += 1
                role = "A" if arm == contrast["a"] else "B"
                rows.append({
                    "ordinal": ordinal,
                    "contrast_id": contrast["id"],
                    "pair_index": pair_index,
                    "pair_order": order,
                    "within_pair": within_pair,
                    "role": role,
                    "arm_id": arm,
                    "anchor_key": contrast["anchor"],
                    **anchor,
                })
    return rows


def ratio_summary(ratios: list[float]) -> dict:
    if len(ratios) != 7:
        raise ValueError("expected seven paired ratios")
    median = statistics.median(ratios)
    deviations = [abs(x - median) for x in ratios]
    return {
        "ratios": ratios,
        "median": median,
        "min": min(ratios),
        "max": max(ratios),
        "median_absolute_deviation": statistics.median(deviations),
    }


def run(apparatus: Path, output: Path) -> dict:
    apparatus = apparatus.resolve()
    output = output.resolve()
    if output.exists():
        raise ValueError("output exists: timing evidence is append-only")
    output.mkdir(parents=True)
    reg = json.loads((ROOT / HERE / "registration.json").read_text())
    limits = reg["execution"]
    started = time.monotonic()
    environment = dict(os.environ)

    report = {
        "schema_version": 1, "stage": reg["stage"], "status": "incomplete",
        "formal_timing_admitted": bool(reg.get("formal_timing_admitted")),
        "performance_comparisons_admitted": bool(reg.get("performance_comparisons_admitted")),
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "registration_sha256": digest(ROOT / HERE / "registration.json"),
        "apparatus": {}, "schedule": [], "processes": [],
        "contrasts": [], "errors": [], "files": {}
    }

    def remaining() -> int:
        left = limits["timing_wall_budget_seconds"] - (time.monotonic() - started)
        if left <= 0:
            raise ValueError("S2A timing wall budget exhausted")
        return max(1, min(limits["timing_timeout_seconds"], int(left)))

    try:
        if reg["status"] != "admitted-paired-timing" or \
                reg["formal_timing_admitted"] is not True or \
                reg["performance_comparisons_admitted"] is not True:
            raise ValueError("S2A paired timing has not been explicitly admitted")
        admission = reg.get("admission_evidence")
        if not isinstance(admission, dict):
            raise ValueError("S2A admission evidence missing")
        for filename, key in (
            ("measure.py", "measure_py_sha256"),
            ("verify_measurement.py", "verify_measurement_py_sha256"),
            ("fixture.cpp", "fixture_cpp_sha256"),
        ):
            if digest(ROOT / HERE / filename) != admission[key]:
                raise ValueError("S2A admitted runner/fixture source changed: " + filename)

        apparatus_run = json.loads((apparatus / "run.json").read_text())
        readback = json.loads((apparatus / "independent-readback.json").read_text())
        seal = json.loads((apparatus / "sealed-binaries.json").read_text())
        if apparatus_run.get("status") != "passed-apparatus-qualification" or \
                apparatus_run.get("apparatus_qualification") is not True or \
                readback.get("status") != "passed":
            raise ValueError("S2A apparatus prerequisite did not pass")
        if digest(apparatus / "run.json") != admission["run_json_sha256"] or \
                digest(apparatus / "independent-readback.json") != admission["readback_sha256"] or \
                digest(apparatus / "sealed-binaries.json") != admission["sealed_binaries_sha256"]:
            raise ValueError("S2A apparatus evidence differs from admitted identities")
        if apparatus_run["source_head"] != admission["source_head"]:
            raise ValueError("S2A apparatus source head differs from admission")
        report["apparatus"] = {
            "source_head": apparatus_run["source_head"],
            "run_json_sha256": digest(apparatus / "run.json"),
            "readback_sha256": digest(apparatus / "independent-readback.json"),
            "sealed_binaries_sha256": digest(apparatus / "sealed-binaries.json"),
            "artifact_id": admission["artifact_id"],
            "artifact_sha256": admission["artifact_sha256"],
        }

        rows = schedule(reg)
        if len(rows) != limits["maximum_primary_timing_processes"] or len(rows) != 224:
            raise ValueError("S2A timing schedule does not contain exactly 224 processes")
        report["schedule"] = rows

        results: dict[tuple[str, int, str], dict] = {}
        for row in rows:
            arm = row["arm_id"]
            binary_info = seal["binaries"][arm]
            binary = apparatus / binary_info["path"]
            if digest(binary) != binary_info["sha256"]:
                raise ValueError("S2A sealed binary changed: " + arm)
            argv = [
                str(binary), "--side", str(row["side"]), "--workers", str(row["workers"]),
                "--warmup", str(reg["inputs"]["warmup_ticks"]),
                "--ticks", str(reg["inputs"]["sample_ticks"]),
                "--seed", str(reg["inputs"]["seed"]),
                "--scenario", row["scenario"], "--mode", "measure"
            ]
            label = f'processes/{row["ordinal"]:03d}-{row["contrast_id"]}-p{row["pair_index"]}-{row["role"]}'
            receipt = command(argv, apparatus, output, label, remaining(), environment)
            process = {**row, "receipt": receipt}
            report["processes"].append(process)
            if not succeeded(receipt):
                raise ValueError("S2A timing process failed/timed out: " + label)
            if (output / receipt["stderr"]).read_bytes().strip():
                raise ValueError("S2A timing process stderr not empty: " + label)
            value = json.loads((output / receipt["stdout"]).read_text())
            if value.get("status") != "passed" or value.get("mode") != "measure" or \
                    value.get("performance_qualification") is not True or \
                    value.get("formal_timing_admitted") is not False:
                raise ValueError("S2A timing binary returned malformed authorization/result: " + label)
            tick_ns = value.get("tick_ns")
            input_ns = value.get("input_ns")
            if not isinstance(tick_ns, list) or len(tick_ns) != reg["inputs"]["sample_ticks"] or \
                    not isinstance(input_ns, list) or len(input_ns) != reg["inputs"]["sample_ticks"]:
                raise ValueError("S2A timing process sample count changed: " + label)
            if any(type(x) is not int or x < 0 for x in tick_ns + input_ns):
                raise ValueError("S2A timing process contains invalid nanoseconds: " + label)
            reduced = {
                "value": value,
                "tick_stats": timing_stats(tick_ns),
                "input_stats": timing_stats(input_ns),
            }
            results[(row["contrast_id"], row["pair_index"], row["role"])] = reduced

        if len(report["processes"]) != 224:
            raise ValueError("S2A timing process matrix incomplete")

        for contrast in reg["contrasts"]:
            pairs = []
            ratios = []
            for pair_index, order in enumerate(reg["pair_orders"]):
                a = results[(contrast["id"], pair_index, "A")]
                b = results[(contrast["id"], pair_index, "B")]
                a_mean = a["tick_stats"]["mean_ns"]
                b_mean = b["tick_stats"]["mean_ns"]
                if a_mean <= 0:
                    raise ValueError("S2A A mean tick time is nonpositive")
                ratio = b_mean / a_mean
                ratios.append(ratio)
                pairs.append({
                    "pair_index": pair_index, "order": order,
                    "a_arm": contrast["a"], "b_arm": contrast["b"],
                    "a_tick_stats": a["tick_stats"], "b_tick_stats": b["tick_stats"],
                    "a_input_stats": a["input_stats"], "b_input_stats": b["input_stats"],
                    "b_over_a_mean_tick_ratio": ratio,
                    "a_clear_ticks": a["value"]["clear_ticks"],
                    "b_clear_ticks": b["value"]["clear_ticks"],
                    "a_peak_process_rss_bytes": a["value"]["peak_process_rss_bytes"],
                    "b_peak_process_rss_bytes": b["value"]["peak_process_rss_bytes"],
                })
            report["contrasts"].append({
                "id": contrast["id"], "anchor": contrast["anchor"],
                "a": contrast["a"], "b": contrast["b"],
                "pairs": pairs, "ratio_summary": ratio_summary(ratios)
            })

        report["status"] = "passed"
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        report["status"] = "incomplete"
        report["errors"].append(str(exc))
    finally:
        report["elapsed_seconds_budget_only_not_benchmark"] = time.monotonic() - started
        for path in sorted(output.rglob("*")):
            if path.is_file() and path.name != "run.json":
                report["files"][path.relative_to(output).as_posix()] = {
                    "bytes": path.stat().st_size, "sha256": digest(path)}
        dump(output / "run.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apparatus", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = run(args.apparatus, args.output)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(json.dumps({
        "status": result["status"],
        "formal_timing_admitted": result["formal_timing_admitted"],
        "process_count": len(result["processes"]),
        "contrast_count": len(result["contrasts"]),
        "errors": result["errors"]
    }, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
