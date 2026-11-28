#!/usr/bin/env python3
"""Source-bound regression replay of the revealed SWARM-005 #698 matrix.

Retain all 360 native JSON outputs, including failures and unavailable closure.
This is not new unseen qualification and does not select or tune a policy.
"""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
import gzip
import hashlib
import itertools
import json
from pathlib import Path
import re
import subprocess
import time

import runtime_custody

FIXTURES = ("island", "concave_intrusion", "foreign_solid")
PROFILES = ("industrial", "viaduct_like", "irregular_megastructure")
SEEDS = (707861, 414855, 959922, 681376)
POLICIES = ("off_off", "compact_only", "receptor_only", "both", "both_round1", "both_round0",
            "both_frame_frozen", "both_mosaic_frozen", "both_hard_only", "both_fixed_territory")
CASES = tuple(itertools.product(FIXTURES, PROFILES, SEEDS, POLICIES))
NORMALIZATION = "Only native request/result definition suffix and result request_digest/digest; all material, graph, work, status, failure, composition and assembly hashes remain exact."


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized(value):
    if isinstance(value, list):
        return [normalized(item) for item in value]
    if not isinstance(value, dict):
        return value
    out = {key: normalized(item) for key, item in value.items()}
    if "gentek" in value and "definition" in value and value["definition"]:
        prefix, separator, suffix = value["definition"].rpartition(".")
        if not separator or not re.fullmatch(r"[0-9a-f]{64}", suffix):
            raise ValueError("invalid compiled definition identity")
        out["definition"] = prefix + ".<compiled-input-sha256>"
        if "implementation" in value:
            out["request_digest"] = out["digest"] = "<definition-dependent>"
    return out


def behavior_hash(value) -> str:
    return sha(json.dumps(normalized(value), sort_keys=True, separators=(",", ":")).encode())


def metrics(value: dict) -> dict:
    m = value.get("metrics", {})
    return {"status": value["status"], "can_apply": value["can_apply"],
            "joints": len(value["joints"]), "rounds": len(value["rounds"]),
            "closure_evaluated": "still_required" in m,
            **{key: m.get(key) for key in ("original_required", "foreign_joined_required", "still_required",
                "total_charged_work", "frame_work", "mosaic_work", "solver_work", "shared_work")}}


def execute(exe: Path, destination: Path, index: int, case: tuple, definition: str) -> tuple[dict, dict | None]:
    file = destination / f"case-{index:03}.json"
    begun = time.monotonic()
    record = {"case_id": index, "fixture": case[0], "profile": case[1], "seed": case[2], "policy": case[3]}
    value = None
    try:
        run = subprocess.run([str(exe), *map(str, case), str(file)], capture_output=True, text=True, timeout=45)
        record.update(exitcode=run.returncode, stdout=run.stdout, stderr=run.stderr)
        if file.is_file():
            raw = file.read_bytes()
            record.update(raw_sha256=sha(raw), raw_bytes=len(raw))
            compressed = gzip.compress(raw, compresslevel=6, mtime=0)
            zipped = file.with_suffix(".json.gz")
            with zipped.open("xb") as stream:
                stream.write(compressed)
            record.update(file=zipped.name, gzip_sha256=sha(compressed), gzip_bytes=len(compressed))
            file.unlink()
            value = json.loads(raw)
            if value.get("schema") != 5 or value.get("type") != "reciprocal_assembly":
                raise ValueError("unexpected composition schema")
            for gentek, prefix in (("frame", "frameweaver.frontier-growth-v0."),
                                   ("mosaic", "mosaic.prepared-regions-v0.")):
                request = value["input"][gentek]
                if request["definition"] != prefix + definition or request["seed"] != case[2] or \
                        request["source"] != "swarm005-unseen-holdout-v1":
                    raise ValueError("native output differs from the bound definition/input identity")
            record.update(metrics(value))
            record["behavior_sha256"] = behavior_hash(value)
            if value["can_apply"] != (value["status"] == "complete" and record["closure_evaluated"]
                                       and record["still_required"] == 0):
                raise ValueError("Apply authority inconsistent with actual closure")
            if any(value.get("metrics", {}).get(key, 0) for key in ("hard_violations", "protected_violations")):
                raise ValueError("native hard/protected violation")
        if run.returncode or value is None:
            raise ValueError("native case failed or produced no evidence")
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        record["error"] = f"{type(error).__name__}: {error}"
    record["elapsed_seconds"] = round(time.monotonic() - begun, 3)
    return record, value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--reference-exe", type=Path, help="Independently built frozen #697 native driver")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--local-preflight", action="store_true", help="Dirty source, explicitly non-qualifying")
    parser.add_argument("--workers", type=int, choices=range(1, 5), default=4)
    args = parser.parse_args()
    exe = args.exe.resolve(strict=True)
    reference = args.reference_exe.resolve(strict=True) if args.reference_exe else None
    identity = runtime_custody.source(require_clean=not args.local_preflight)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    candidate_dir = output / "candidate"
    candidate_dir.mkdir()
    reference_dir = output / "reference"
    if reference:
        reference_dir.mkdir()
    manifest = {"schema": 1, "programme": "SWARM004-005-mainline-known-matrix-regression",
        "registration": "https://github.com/techrote/cybersand/issues/698", "unseen": False,
        "qualifying_source": not args.local_preflight, "source": identity,
        "driver_sha256": sha(Path(__file__).with_name("replay_known_control.cpp").read_bytes()),
        "runner_sha256": sha(Path(__file__).read_bytes()), "executable_sha256": sha(exe.read_bytes()),
        "reference_executable_sha256": sha(reference.read_bytes()) if reference else None,
        "reference_source": "8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7" if reference else None,
        "expected_cases": len(CASES), "normalization": NORMALIZATION, "records": [], "errors": [],
        "result": "RUNNING"}
    begun = time.monotonic()

    def one(index, case):
        record, _ = execute(exe, candidate_dir, index, case, identity["native_definition_sha256"])
        if reference:
            old, _ = execute(reference, reference_dir, index, case,
                "12a4816dab749a9c872a4d531836db8ec6a170aab31576d70086efa80eeb3b6b")
            record["reference"] = old
            if "error" in old:
                record["error"] = "frozen reference execution failed"
            if "behavior_sha256" in old and "behavior_sha256" in record:
                record["behavior_equal"] = old["behavior_sha256"] == record["behavior_sha256"]
                # Accounting repair is receptor-opt-in only. The complete raw
                # OFF and compact-only controls must remain behaviorally exact.
                if case[3] in ("off_off", "compact_only") and not record["behavior_equal"]:
                    record["error"] = "behavior drift with receptor control OFF"
        return record

    def save():
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    save()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(one, index, case) for index, case in enumerate(CASES)]
        for future in as_completed(futures):
            record = future.result()
            manifest["records"].append(record)
            if "error" in record:
                manifest["errors"].append({"case_id": record["case_id"], "error": record["error"]})
            if len(manifest["records"]) % 36 == 0:
                save()
                print(json.dumps({"completed": len(manifest["records"]), "errors": len(manifest["errors"])}), flush=True)
    manifest["records"].sort(key=lambda item: item["case_id"])
    manifest["summary"] = {policy: dict(Counter(row.get("status", "execution_error")
        for row in manifest["records"] if row["policy"] == policy)) for policy in POLICIES}
    manifest["elapsed_seconds"] = round(time.monotonic() - begun, 3)
    if runtime_custody.source(require_clean=not args.local_preflight) != identity:
        manifest["errors"].append({"error": "source changed during replay"})
    if sha(exe.read_bytes()) != manifest["executable_sha256"] or (reference and
            sha(reference.read_bytes()) != manifest["reference_executable_sha256"]):
        manifest["errors"].append({"error": "executed binary changed during replay"})
    manifest["result"] = "FAIL" if manifest["errors"] or len(manifest["records"]) != len(CASES) else "PASS"
    save()
    print(json.dumps({key: manifest[key] for key in ("result", "summary", "elapsed_seconds", "errors")}, indent=2))
    return 0 if manifest["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
