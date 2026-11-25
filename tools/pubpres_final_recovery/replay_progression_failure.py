#!/usr/bin/env python3
"""Independently recover the original Windows progression failure without relabelling it.

The externally pinned original artifact is read directly. Its count reader and
independent physical reader must match the actual registered source bytes. The
output is a separate review receipt, never a replacement original result.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/pubpres_final"))
import run_comparison  # Establish the frozen dependency import paths.
from material_steps_contract import reduce_evidence, validate_cohort
from independent_reduction import reduce as physical_reduce

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "4bde032f27e90e6e974b3ddc123264afa8fa5012"
TREE = "0e9be155adfc408641e391c6d184e01fce235866"
RUN = 45477483707
ARTIFACT = 14966741716
ARCHIVE_SHA256 = "4a469346e11d2533293012904072a228d4199240f5f4d70423ec91e54260a4f1"
EXPECTED_FAILURE = {"case": "wave_512_follow", "reason": "Valid no-op/deadline-only count2 arm: registered deferral/coalescing/real-count eligibility was not exercised in both arms"}


def need(ok, message):
    if not ok:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def source_bytes(name):
    return subprocess.check_output(["git", "-C", str(ROOT), "show", SOURCE + ":" + name])


def review(archive: Path) -> dict:
    archive = archive.resolve()
    need(digest(archive.read_bytes()) == ARCHIVE_SHA256, "Not the original pinned Windows artifact")
    with zipfile.ZipFile(archive) as bundle, tempfile.TemporaryDirectory(prefix="pubpres-original-review-") as temporary:
        need(bundle.testzip() is None, "Original artifact ZIP CRC failed")
        names = bundle.namelist()
        need(len(names) == len(set(names)) and len(names) < 10000, "Duplicate or unbounded artifact inventory")
        root = Path(temporary)
        # Preserve every included original byte; omit reproducible caches from
        # the review extraction because none is consumed by these readers.
        for member in bundle.infolist():
            path = Path(member.filename)
            need(not path.is_absolute() and ".." not in path.parts, "Unsafe original artifact member")
            if member.is_dir() or "profile" in path.parts or "shader_cache" in path.parts:
                continue
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(bundle.read(member))
        inventory = json.loads((root / "INVENTORY.json").read_bytes())
        summary_path = root / "material-completed-steps/SUMMARY.json"
        summary = json.loads(summary_path.read_bytes())
        need(inventory["source"] == SOURCE and inventory["run_id"] == str(RUN)
             and inventory["attempt"] == "1" and inventory["platform"] == "windows"
             and inventory["complete"] is False and inventory["unexecuted"] == [], "Original failed inventory differs")
        failed = [row for row in inventory["outcomes"] if row["returncode"] != 0 or row["timed_out"]]
        need(len(failed) == 1 and failed[0]["name"] == "material-completed-steps"
             and failed[0]["returncode"] == 1 and failed[0]["timed_out"] is False, "Original failure is not the registered treatment gate")
        need(summary["complete"] is False and summary["failures"] == [EXPECTED_FAILURE]
             and summary["source"]["source_commit"] == SOURCE and summary["source"]["source_tree"] == TREE,
             "Original count failure/source differs")
        driver = summary["driver"]["files_sha256"]
        need(driver and all(digest(source_bytes(name)) == expected for name, expected in driver.items()),
             "Original driver closure does not match Git source")
        readers = ("material_steps_contract.py", "material_steps_status.py", "independent_reduction.py")
        for name in readers:
            relative = "tools/pubpres_final/" + name
            need((ROOT / relative).read_bytes() == source_bytes(relative), "Review imported changed original reader: " + name)
        reviewed = []
        for case in summary["cases"]:
            arms = case["arms"]
            need(len(arms) == 4, "Original count cohort is incomplete")
            replay = validate_cohort(arms, summary["registration"])
            need(replay == case["cohort"], "Registered cohort result does not reproduce")
            row = {"case": case["case"], "treatment_exercised_in_both_arms": replay["treatment_exercised_in_both_arms"],
                   "registered_direction": replay["registered_direction"], "arms": []}
            for arm in arms:
                folder = root / "material-completed-steps" / case["case"] / f"{arm['index']}-count{arm['requested_interval']}"
                receipt_path = folder / "receipt.json"
                need(digest(receipt_path.read_bytes()) == arm["receipt_sha256"], "Original arm receipt changed")
                events_path = folder / "receipt-events.jsonl"
                events = [json.loads(line) for line in events_path.read_text().splitlines()][1:]
                policy = reduce_evidence(receipt_path, events, arm["requested_interval"])
                need(policy == arm["material_steps"], "Raw count/source/ownership replay differs from retained reduction")
                independent = physical_reduce(receipt_path)
                window = independent["windows"]["first_144_steps"]
                retained_window = arm["statistics"]["windows"]["first_144_steps"]
                need(window["completed_rapier_steps"] == retained_window["completed_rapier_steps"] == 144
                     and abs(window["rapier_steps_per_second"] - retained_window["rapier_steps_per_second"]) < 1e-12
                     and all(abs(window["physical_gap_ms"][key] - retained_window["physical_gap_ms"][key]) < 1e-9
                             for key in ("max", "p50", "p95", "p99")), "Independent raw physical measurements differ")
                row["arms"].append({"index": arm["index"], "requested_interval": arm["requested_interval"],
                    "receipt_sha256": arm["receipt_sha256"], "events_sha256": digest(events_path.read_bytes()),
                    "source": SOURCE, "native_binary_sha256": summary["source"]["native_runtime"]["binary_sha256"],
                    "process_exit_code": arm["process"]["exit_code"], "process_timed_out": arm["process"]["timed_out"],
                    "physical_witness": independent["physical_witness"], "first_144_steps": window,
                    "treatment_exercise": policy["treatment_exercise"],
                    "capture_policy_counters": policy["capture_policy_counters"],
                    "accepted_eligibility_populations": policy["windows"]["first_144_steps"]["accepted_eligibility_populations"],
                    "independent_count_before_deadline_observed": policy["independent_count_before_deadline_observed"]})
            reviewed.append(row)
        return {"schema": "pubpres-original-progression-failure-review-v1", "source": SOURCE, "tree": TREE,
                "run_id": RUN, "attempt": 1, "artifact_id": ARTIFACT, "archive_sha256": ARCHIVE_SHA256,
                "archive_bytes": archive.stat().st_size, "archive_members": len(names), "archive_crc_passed": True,
                "review_program_sha256": digest(Path(__file__).read_bytes()), "original_driver_inputs_checked": len(driver),
                "inventory_sha256": digest((root / "INVENTORY.json").read_bytes()),
                "original_summary_sha256": digest(summary_path.read_bytes()), "original_failure": EXPECTED_FAILURE,
                "original_stage_outcomes": [{key: item[key] for key in ("name", "returncode", "timed_out")}
                                            for item in inventory["outcomes"]], "cases": reviewed,
                "diagnosis": "Valid treatment-execution failure, reproduced. Wave512 first count2 arm never deferred or replaced an offered material packet. The reader correctly withholds count2 performance attribution. Large Wave exercised coalescing but failed the unchanged directional performance gate.",
                "disposition": "Original Windows graphical FAIL retained. No oracle repair is warranted. Retire unchanged count2 timing prospectively; preserve all policy/correctness witnesses and adverse/no-op results.",
                "physical_acceptance": "HOLD", "complete": True,
                "scope": "Offline independent original-byte/count/physical-step review. No new graphical execution, no workflow pass override, no complete GPU requalification and no physical Windows/NVIDIA acceptance."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    need(not args.output.exists(), "Preserve prior review evidence")
    record = review(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"complete": True, "original_disposition": "FAIL retained", "cases": len(record["cases"]), "output": str(args.output)}))


if __name__ == "__main__":
    main()
