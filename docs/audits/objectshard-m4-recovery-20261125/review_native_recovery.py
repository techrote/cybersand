#!/usr/bin/env python3
"""Independently recover the original M4 native artifact without rebuilding it.

This deliberately reads the archive's frozen inputs, binary bytes, logs and raw
benchmark rather than trusting the predecessor's independent-review summary.
It does not execute Godot, Rapier or the native binaries.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile


ORIGINAL_SHA = "1629687935c7a1b13fb86c231527ed29e7de13f944e7d933eac82d243b3307cd"
ORIGINAL_BYTES = 135239647
ORIGINAL_SOURCE = "f5b7ac7e651356c9f6d5657dfb0cb9d60111be81"
ORIGINAL_TREE = "fcbb55a7c80a9d1a887e4e0336491e07c3ae01db"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    root = args.source.resolve()

    def git(*parts: str) -> str:
        return subprocess.check_output(["git", "-C", str(root), *parts], text=True).strip()

    with args.archive.open("rb") as stream:
        archive_hash = hashlib.file_digest(stream, "sha256").hexdigest()
    assert args.archive.stat().st_size == ORIGINAL_BYTES
    assert archive_hash == ORIGINAL_SHA
    assert git("rev-parse", ORIGINAL_SOURCE + "^{tree}") == ORIGINAL_TREE
    report = {
        "schema": "objectshard-m4-native-recovery-review-v1",
        "reviewed_at_utc": datetime.now(timezone.utc).isoformat(),
        "reviewer": "recovery-specialist-A-independent-native",
        "source_head": git("rev-parse", "HEAD"),
        "source_tree": git("rev-parse", "HEAD^{tree}"),
        "source_status": git("status", "--short"),
        "original_source": ORIGINAL_SOURCE,
        "original_tree": ORIGINAL_TREE,
        "artifact": {"id": 14959327733, "bytes": ORIGINAL_BYTES, "sha256": archive_hash},
        "original_run": {"id": 45473059187, "attempt": 1, "job": 138725897119},
        "source_inputs": [],
        "executables": [],
        "budgets": [],
        "limitations": [
            "This is independent recovery of original execution evidence, not a new native build.",
            "The original aggregate campaign remains failed; Linux acquisition and Windows delivered replay failed.",
            "Native timing uses synthetic poses and acknowledgements, not Rapier, rendering or monitor presentation.",
            "Requested C++ allocations are not process RSS. LeakSanitizer was disabled in the original execution.",
            "Applicability to a successor requires equality of every recorded execution input, not commit-name similarity.",
        ],
    }
    with zipfile.ZipFile(args.archive) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names))
        assert all(not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts for name in names)
        report["archive_members"] = len(names)
        inputs = {}
        for name in sorted(n for n in names if n.endswith("/inputs.json")):
            record = json.loads(archive.read(name))
            specification = {key: value for key, value in record.items()
                             if key not in {"git_head", "git_status", "source_root", "input_digest"}}
            recalculated = digest(json.dumps(specification, sort_keys=True).encode())
            assert recalculated == record["input_digest"]
            assert record["git_head"] == ORIGINAL_SOURCE
            prefix = name.rsplit("/", 1)[0]
            for path, expected in record["sources"].items():
                assert digest(archive.read(prefix + "/source/" + path)) == expected, path
                assert digest((root / path).read_bytes()) == expected, path
                original = subprocess.check_output(["git", "-C", str(root), "show", ORIGINAL_SOURCE + ":" + path])
                assert digest(original) == expected, path
            inputs[name.split("/", 1)[0]] = (record, prefix)
            report["source_inputs"].append({"path": name, "sha256": digest(archive.read(name)),
                "count": len(record["sources"]), "input_digest": recalculated,
                "original_frozen_current_equal": True})
        native = json.loads(archive.read("native/summary.json"))
        report["native"] = {key: native[key] for key in
            ("status", "checks_reported", "test_cases_reported", "failures_reported", "counts_complete", "sanitizers", "leak_sanitizer")}
        assert native["status"] == "passed" and native["failures_reported"] == 0
        total_checks = total_cases = 0
        for suite, result in native["suites"].items():
            assert result["status"] == "passed"
            assert result["execution"]["returncode"] == 0 and not result["execution"]["timed_out"]
            prefix = inputs["native"][1]
            binary = prefix + "/test_object_shard_" + suite
            assert digest(archive.read(binary)) == result["binary_sha256"]
            log = archive.read(prefix + "/logs/test-" + suite + ".log")
            if suite == "world":
                assert re.search(r"\b192\b.*\bpassed\b|\bpassed\b.*\b192\b", log.decode(), re.I)
                total_cases += result["checks"]
            else:
                match = re.search(r"(\d+) checks, (\d+) failures", log.decode())
                if match:
                    observed_counts = tuple(map(int, match.groups()))
                else:
                    raw = json.loads(log.decode().splitlines()[-1])
                    observed_counts = (raw["checks"], raw["failures"])
                assert observed_counts == (result["checks"], 0)
                total_checks += result["checks"]
            report["executables"].append({"suite": suite, "sha256": result["binary_sha256"],
                "checks": result["checks"], "count_unit": result["count_unit"], "log_sha256": digest(log)})
        assert total_checks == native["checks_reported"] == 96500
        assert total_cases == native["test_cases_reported"] == 192

        benchmark_inputs, prefix = inputs["retained-lab-native-budgets"]
        benchmark = json.loads(archive.read(prefix + "/benchmark.json"))
        summary = json.loads(archive.read("retained-lab-native-budgets/summary.json"))
        assert digest(archive.read(prefix + "/benchmark_object_shard")) == summary["binary_sha256"]
        assert summary["execution"]["returncode"] == 0 and not summary["execution"]["timed_out"]
        assert benchmark["checks"] == summary["checks"] == 4276351 and benchmark["failures"] == 0
        budget = json.loads(archive.read(prefix + "/source/tools/objectshard/native_budgets.json"))
        expected_cases = {"empty_lab", "inert_stationary", "inert_moving", "reacting_one", "reacting_three",
            "perforated_reacting", "saturated_world_destinations", "dormant_twelve", "wake_burst_twelve",
            "compact_vs_tuned_serial_miniature"}
        assert {case["name"] for case in benchmark["cases"]} == expected_cases
        limits = budget["integrated_limits"]
        for case in benchmark["cases"]:
            observed = []
            if case["name"] == "compact_vs_tuned_serial_miniature":
                observed = [(key + "_steady_allocations", case["memory"][key + "_steady_allocations"],
                    budget["comparison_requirements"]["steady_cpp_allocations_each_candidate"]) for key in ("compact", "miniature")]
            else:
                frame = case["timings"]["native_frame_including_snapshot_receipt"]
                assert frame["samples"] >= budget["minimum_frame_samples_per_workload"]
                observed.extend(("native_frame_" + key + "_us", frame[key + "_us"], limits["native_frame_" + key + "_us"])
                                for key in ("p95", "p99", "max"))
                observed.extend((key, case["memory"][key], limits[key]) for key in
                                ("cpp_live_max_bytes", "cpp_peak_max_bytes", "registry_retained_max_bytes"))
                observed.extend((("steady_cpp_allocations", case["memory"]["steady_allocations"], limits["steady_cpp_allocations"]),
                    ("geometry_age_max_ticks", case["observations"]["geometry_age_max_ticks"], limits["geometry_age_max_ticks"])))
            for metric, actual, limit in observed:
                assert math.isfinite(actual) and actual <= limit
                report["budgets"].append({"case": case["name"], "metric": metric, "actual": actual, "limit": limit, "margin": limit - actual})
        assert len(report["budgets"]) == summary["budget_qualification"]["limits_checked"] == 74
        report["benchmark"] = {"checks": benchmark["checks"], "limits": len(report["budgets"]),
            "binary_sha256": summary["binary_sha256"], "report_sha256": digest(archive.read(prefix + "/benchmark.json")),
            "cpu_model": benchmark_inputs["cpu_model"], "platform": benchmark_inputs["platform"]}
    report["status"] = "PASS_ORIGINAL_NATIVE_EVIDENCE_RECOVERED"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": report["status"], "source_inputs": [x["count"] for x in report["source_inputs"]],
        "native_checks": total_checks, "world_cases": total_cases, "budget_limits": len(report["budgets"])}))


if __name__ == "__main__":
    main()
