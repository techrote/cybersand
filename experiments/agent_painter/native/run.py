"""Execute the current-source pilot, verify it and admit only real native TRAIN.

The normal mode requires same-source build custody and a clean tracked source.
--development is explicitly non-admitting local debugging with a verified
retained source-compatible runtime. Neither mode downloads a model or trains.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

from runtime import ROOT, canonical, development_runtime, digest, verify as verify_runtime

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from corpus import build_candidates, validate_splits
from verify import verify, safe_path


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def execute(command: list[str], env: dict, logfile: Path, seconds: int) -> dict:
    started = time.monotonic()
    result = {"command": command, "timeout_seconds": seconds, "timed_out": False, "exit_code": None}
    with logfile.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=os.name != "nt")
        try:
            result["exit_code"] = process.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            result["timed_out"] = True
            if os.name != "nt":
                os.killpg(process.pid, signal.SIGKILL)
            else:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], timeout=30,
                               stdout=log, stderr=subprocess.STDOUT, check=False)
                process.kill()
            result["exit_code"] = process.wait(timeout=30)
    result["elapsed_seconds"] = round(time.monotonic() - started, 3)
    return result


def native_cases(document: dict) -> dict:
    result = []
    seen = set()
    for example in document["examples"]:
        identifier = example["id"]
        if not isinstance(identifier, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", identifier) or identifier in seen:
            raise ValueError("Case IDs must be unique and path-safe")
        seen.add(identifier)
        compiled = example["compiled"]
        if compiled["focus"] != [0, 0, 96, 96]:
            raise ValueError("This pilot qualification is frozen to a 96-square focus")
        operations = compiled["operations"]
        if not 1 <= len(operations) <= 512:
            raise ValueError("Bounded native operation count required")
        result.append({
            "id": identifier, "family": example["family"], "seed": example["seed"],
            "width": 96, "height": 96, "operations": operations,
            "program_sha256": hashlib.sha256(canonical(example["program"])).hexdigest(),
            "operations_sha256": hashlib.sha256(canonical(operations)).hexdigest(),
        })
    if not 1 <= len(result) <= 1024:
        raise ValueError("Native candidate cohort must have 1–1024 cases")
    return {"schema_version": 1, "cases": result}


def admit(directory: Path, candidates: dict, report: dict) -> dict:
    """Write portable split files with original, hash-verified native evidence."""
    if report.get("passed") is not True or report.get("development_only"):
        raise ValueError("Only qualified, clean-source native passes can become TRAIN")
    validate_splits(candidates["examples"])
    custody = json.loads((directory / "runtime-custody.json").read_text())
    if (digest(directory / "candidates.json") != custody["candidates_sha256"]
            or json.loads((directory / "candidates.json").read_text()) != candidates
            or json.loads((directory / "native-verification.json").read_text()) != report
            or digest(directory / "runtime-custody.json") != report["runtime_custody_sha256"]
            or report["source_sha"] != custody["source_sha"]
            or report["runtime_sha256"] != custody["native_sha256"]):
        raise ValueError("Corpus input/verification custody changed before admission")
    output = directory / "corpus"
    output.mkdir(exist_ok=False)
    evidence_dir = output / "evidence"
    evidence_dir.mkdir()
    receipts = {row["id"]: row for row in report["cases"]}
    by_split = {split: [] for split in ("TRAIN", "DEVELOPMENT", "FINAL")}
    groups = {split: set() for split in by_split}
    seen_ids = set()
    for example in candidates["examples"]:
        identifier = example["id"]
        result = receipts[identifier]
        if not result["success"] or identifier in seen_ids:
            raise ValueError("Native admission requires one unique successful receipt per example")
        seen_ids.add(identifier)
        split = example["split"]
        groups[split].add(example["structural_group"])
        native_paths = {}
        for key, receipt_key, hash_key in (("png", "png", "image_sha256"),
                                           ("readback", "raw_materials", "readback_sha256"),
                                           ("receipt", "receipt", "receipt_sha256")):
            source = safe_path(directory, result[receipt_key])
            if digest(source) != result[hash_key]:
                raise ValueError("Native evidence changed after independent verification")
            relative = "evidence/" + source.name
            shutil.copyfile(source, output / relative)
            native_paths[key] = relative
        row = dict(example)
        row["native_qualified"] = True
        row["native_admission"] = {
            "state": "PASS", "native_execution": True, "verified": True,
            "source_sha": report["source_sha"], "runtime_sha256": report["runtime_sha256"],
            "program_sha256": result["program_sha256"], "operations_sha256": result["operations_sha256"],
            "readback_sha256": result["readback_sha256"], "png_sha256": result["image_sha256"],
            "receipt_sha256": result["receipt_sha256"], "affected_cells": result["affected_cells"],
            "acknowledged_cells": result["acknowledged_cells"], "paths": native_paths,
            "deterministic_replay": result["deterministic_replay"], "structure": result["structure"],
            "assessment_kind": "native execution and structural verification; visual quality remains owner/worker review",
        }
        by_split[split].append(row)
    for first in groups:
        for second in groups:
            if first != second and groups[first] & groups[second]:
                raise ValueError("A structural group crosses corpus partitions")
    manifest = {
        "schema_version": 1, "state": "native-admitted", "source_sha": report["source_sha"],
        "runtime_sha256": report["runtime_sha256"], "compiler_sha256": report["compiler_sha256"],
        "native_verification_sha256": digest(directory / "native-verification.json"),
        "split_files": {}, "structural_groups": {key: sorted(value) for key, value in groups.items()},
        "policy": "TRAIN only may optimize. DEVELOPMENT may guide iteration. FINAL remains sealed until model selection.",
        "counts": {key: len(value) for key, value in by_split.items()},
    }
    for split, rows in by_split.items():
        filename = split.lower() + ".jsonl"
        path = output / filename
        path.write_bytes(b"".join(canonical(row) + b"\n" for row in rows))
        manifest["split_files"][split] = {"path": filename, "sha256": digest(path), "count": len(rows)}
    # This metadata file has group IDs/counts/hashes, not FINAL prompts/programs.
    write_json(output / "admitted-corpus.json", manifest)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--runtime-manifest", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, choices=(1, 4), default=1)
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--development", action="store_true")
    parser.add_argument("--limit", type=int, help="Development-only first-N smoke cohort")
    args = parser.parse_args()
    if not args.development and args.runtime_manifest is None:
        parser.error("Qualified execution requires --runtime-manifest")
    if args.limit is not None and (not args.development or args.limit < 1):
        parser.error("--limit is permitted only for positive-count --development debugging")
    if not 30 <= args.timeout <= 3600:
        parser.error("Native process deadline must be 30–3600 seconds")
    output, godot = args.output.resolve(), args.godot.resolve()
    output.mkdir(parents=True, exist_ok=False)
    check_runtime = (lambda: development_runtime(ROOT, args.source_sha, godot)) if args.development else (
        lambda: verify_runtime(ROOT, args.runtime_manifest.resolve(), args.source_sha, godot))
    custody = check_runtime()
    document = build_candidates()
    if args.limit is not None:
        document["examples"] = document["examples"][:args.limit]
    write_json(output / "candidates.json", document)
    write_json(output / "input-cases.json", native_cases(document))
    harness = ROOT / "godot/tests/run_agent_painter_foundation.gd"
    custody.update({
        "harness_sha256": digest(harness), "input_manifest_sha256": digest(output / "input-cases.json"),
        "candidates_sha256": digest(output / "candidates.json"), "workers": args.workers,
        "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "claim": "Actual native Art/capture on recorded source and OS; PNGs visualize native material readback, not a graphical framebuffer",
    })
    write_json(output / "runtime-custody.json", custody)
    env = os.environ.copy()
    env.update(AP_NATIVE_CASES=str(output / "input-cases.json"), AP_NATIVE_OUTPUT=str(output),
               AP_NATIVE_WORKERS=str(args.workers), AP_NATIVE_SOURCE_SHA=args.source_sha,
               XDG_DATA_HOME=str(output / "profile/data"), XDG_CONFIG_HOME=str(output / "profile/config"),
               XDG_CACHE_HOME=str(output / "profile/cache"))
    import_command = [str(godot), "--headless", "--path", str(ROOT / "godot"), "--editor", "--quit"]
    imported = execute(import_command, env, output / "import.log", min(args.timeout, 600))
    write_json(output / "import-result.json", imported)
    if imported["exit_code"] != 0:
        print(json.dumps({"passed": False, "stage": "Godot import", **imported}, indent=2))
        return 1
    command = [str(godot), "--headless", "--path", str(ROOT / "godot"),
               "--script", "res://tests/run_agent_painter_foundation.gd"]
    result = execute(command, env, output / "engine.log", args.timeout)
    try:
        after = check_runtime()
        result["runtime_unchanged"] = all(custody.get(key) == value for key, value in after.items())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        result["runtime_unchanged"] = False
        result["custody_error"] = str(error)
    result["harness_unchanged"] = digest(harness) == custody["harness_sha256"]
    result["input_unchanged"] = (digest(output / "input-cases.json") == custody["input_manifest_sha256"]
                               and digest(output / "candidates.json") == custody["candidates_sha256"])
    write_json(output / "process-result.json", result)
    try:
        report = verify(output)
    except (ValueError, KeyError, OSError, TypeError) as error:
        report = {"passed": False, "failures": ["Verification incomplete: " + str(error)], "cases": []}
    write_json(output / "native-verification.json", report)
    if report["passed"] and not args.development:
        admit(output, document, report)
    from gallery import build as build_gallery
    build_gallery(output, output / "gallery")
    print(json.dumps({"passed": report["passed"], "development_only": args.development,
                      "native_cases": len(report["cases"]), "failures": report["failures"],
                      "output": str(output), **result}, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print("Native pilot refused: " + str(error), file=sys.stderr)
        raise SystemExit(2)
