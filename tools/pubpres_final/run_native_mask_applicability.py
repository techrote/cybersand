#!/usr/bin/env python3
"""Execute one prebuilt, source-exact A/B/C/C/B/A applicability screen once."""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
from pathlib import Path
import resource
import subprocess
import time

from native_mask_applicability import BENCHMARK_PATH, BENCHMARK_SHA256, COHORTS, CPU_SCOPE, ORDER, cpu_observation, reduce_receipts
from native_empty_derived import reconstruct


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def child_cpu():
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    return {"user_seconds": usage.ru_utime, "system_seconds": usage.ru_stime}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--repository", required=True, type=Path)
    args = parser.parse_args()
    output = args.manifest.resolve().parent
    receipt_path = output / "timing-receipts.json"
    if receipt_path.exists():
        raise RuntimeError("Refusing to overwrite an original measurement receipt")
    manifest = json.loads(args.manifest.read_bytes())
    if manifest["runs"] or manifest["order"] != list(ORDER) or manifest["cohorts"] != [list(row) for row in COHORTS]:
        raise RuntimeError("Expected an unused, exactly registered three-arm manifest")
    for arm, build in manifest["builds"].items():
        if build["exit_code"] != 0 or digest(Path(build["binary_path"])) != build["binary_sha256"]:
            raise RuntimeError("Native binary changed or did not build: " + arm)
        if build["benchmark_sha256"] != BENCHMARK_SHA256 or build["source_inputs_sha256"].get(BENCHMARK_PATH) != BENCHMARK_SHA256:
            raise RuntimeError("Original benchmark source is absent or changed: " + arm)
        overlays = {}
        for name, expected in build["source_inputs_sha256"].items():
            stored = subprocess.run(["git", "show", build["source_commit"] + ":" + name],
                                    cwd=args.repository, capture_output=True)
            actual = hashlib.sha256(stored.stdout).hexdigest()
            if stored.returncode or actual != expected:
                if arm != "A" or name != BENCHMARK_PATH or expected != BENCHMARK_SHA256:
                    raise RuntimeError("Undeclared native source overlay: " + arm + ":" + name)
                overlays[name] = expected
        build["verified_source_overlays_sha256"] = overlays
    manifest["started_utc"] = stamp()
    manifest["runner_source_sha256"] = digest(Path(__file__))
    manifest["quiet_scope"] = "Root/B/C explicitly suspended heavy local work. External shared-host activity is unobserved. No stationarity assumption."
    manifest["cpu_collection"] = "Linux resource.getrusage(RUSAGE_CHILDREN), before Popen and immediately after communicate/reap. Exactly one child is launched inside each interval; no child is launched between measured intervals. Native worker threads are included."
    raw_runs, failures, descriptive = {}, [], []

    def save():
        args.manifest.write_text(json.dumps(manifest, indent=2) + "\n")
        receipt = {"schema": "pubpres-native-mask-applicability-receipts-v1", "manifest": manifest,
                   "raw_runs": raw_runs, "runner_source": Path(__file__).read_text(), "failures": failures}
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
        (output / "descriptive-processes.json").write_text(json.dumps({
            "status": "descriptive-only-pending-registered-reduction", "processes": descriptive}, indent=2) + "\n")
        return receipt

    save()
    for label, size, bodies, profile in COHORTS:
        for index, arm in enumerate(ORDER, 1):
            build = manifest["builds"][arm]
            name = f"{label}-{index}-{arm}"
            command = [build["binary_path"], str(size), str(bodies), "4", "72", str(profile)]
            if digest(Path(command[0])) != build["binary_sha256"]:
                raise RuntimeError("Native binary changed before execution: " + name)
            row = {"name": name, "arm": arm, "argv": command, "binary_sha256": build["binary_sha256"],
                   "started_utc": stamp(), "cpu_scope": CPU_SCOPE, "children_cpu_before": child_cpu()}
            wall_start = time.monotonic_ns()
            process = subprocess.Popen(command, cwd=args.repository, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            row["pid"] = process.pid
            try:
                stdout, stderr = process.communicate(timeout=120)
            except subprocess.TimeoutExpired:
                process.kill()
                stdout, stderr = process.communicate()
                failures.append({"name": name, "reason": "Owned native process timed out and was killed"})
            row["whole_process_wall_nanoseconds"] = time.monotonic_ns() - wall_start
            row["children_cpu_after"] = child_cpu()
            row.update(finished_utc=stamp(), exit_code=process.returncode)
            manifest["runs"].append(row)
            raw = {}
            for key, data in (("stdout", stdout), ("stderr", stderr)):
                (output / (name + "." + key)).write_bytes(data)
                raw[key] = data.decode()
                raw[key + "_sha256"] = hashlib.sha256(data).hexdigest()
            raw_runs[name] = raw
            try:
                if process.returncode or stderr:
                    raise RuntimeError("Native process did not exit cleanly")
                data = json.loads(stdout)
                stats = reconstruct(data)
                cpu = cpu_observation(row, sum(data["tick_nanoseconds"]))
                descriptive.append({"name": name, "workers_observed": data["workers_observed"], **stats, **cpu})
                print(name, "mean", round(stats["tick_mean_ms"], 3), "p95", round(stats["tick_p95_ms"], 3),
                      "max", round(stats["tick_max_ms"], 3), "workers", data["workers_observed"],
                      "whole-child CPU seconds", round(cpu["whole_child_cpu_seconds"], 3), flush=True)
            except Exception as error:
                failures.append({"name": name, "reason": repr(error)})
                print(name, "RETAINED FAILURE", repr(error), flush=True)
            save()
    manifest["finished_utc"] = stamp()
    receipt = save()
    try:
        if failures:
            raise RuntimeError("One or more original native processes failed")
        reduced = reduce_receipts(receipt)
    except Exception as error:
        (output / "timing-refusal.json").write_text(json.dumps({"registered_reduction": "REFUSED",
            "reason": repr(error), "original_receipt_sha256": digest(receipt_path)}, indent=2) + "\n")
        raise
    (output / "timing-reduction.json").write_text(json.dumps(reduced, indent=2) + "\n")
    print("All 18 original processes retain exact complete semantic/conservation parity and registered participation.", flush=True)


if __name__ == "__main__":
    main()
