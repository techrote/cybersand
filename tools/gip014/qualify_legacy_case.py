#!/usr/bin/env python3
"""Reproduce and reduce one retained oracle defect at its exact historical source.

This fixed forensic programme is separate from successor qualification. It never
changes the original expected invariant, promotes a production defect, or executes
commands from a tape. Only the pinned repository launch/export entrypoints run.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
import zipfile

from owned_process import execute, read_log_prefix
from run_goblin import ROOT, sha_file, write_json
from qualify_linux import ENGINE_URL, ENGINE_SHA256, ENGINE_NAME

LEGACY_SOURCE = "d849be8ef99cd9226cfc3ca0925752e42b691515"
LEGACY_TREE = "b6da28e8df80247bbfffb968cbe66e99b386959a"
TAPE_SHA256 = "050155da6012b4eed736b66d998315dc479914549475bab048a8a65c9ff3fb67"
COMPRESSED_SHA256 = "7686f4ef7abdc9f580bdd626e57bdffda312771eacddc0247fe2c93cea866596"
GODOT_SHA256 = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
MAX_OUTPUT_BYTES = 1024 * 1024 * 1024
ORIGINAL_ROWS = 44
MAX_PROBES = 24


def git_at(root: Path, *arguments: str) -> str:
    return subprocess.run(["git", *arguments], cwd=root, check=True, capture_output=True,
                          text=True, timeout=20).stdout.strip()


def source_identity(root: Path) -> dict:
    result = {"commit": git_at(root, "rev-parse", "HEAD"),
              "tree": git_at(root, "rev-parse", "HEAD^{tree}"),
              "dirty": bool(git_at(root, "status", "--porcelain", "--untracked-files=all"))}
    if result != {"commit": LEGACY_SOURCE, "tree": LEGACY_TREE, "dirty": False}:
        raise ValueError("Forensic execution requires the clean independently pinned historical checkout")
    return result


def original_case() -> tuple[bytes, dict]:
    path = ROOT / "tools/gip014/cases/monowheel-origin-d849-original.json.gz"
    if path.is_symlink() or path.stat().st_size != 65657 or sha_file(path) != COMPRESSED_SHA256:
        raise ValueError("Retained historical tape archive differs from its fixed custody identity")
    with gzip.open(path, "rb") as stream:
        raw = stream.read(938588)
    if len(raw) != 938587 or hashlib.sha256(raw).hexdigest() != TAPE_SHA256:
        raise ValueError("Historical native tape bytes differ")
    tape = json.loads(raw)
    provenance = tape["header"]["provenance"]
    if (provenance["source_commit"] != LEGACY_SOURCE or provenance["source_tree"] != LEGACY_TREE
            or provenance["source_dirty"] is not False or provenance["platform"] != "linux"
            or tape["header"]["evidence_kind"] != "headless_godot"
            or len(tape["steps"]) != ORIGINAL_ROWS
            or tape["summary"]["failures"] != [{"id": "actor_place_position", "kind": "gameplay", "step": 43}]):
        raise ValueError("Retained case identity/target differs from the registered native finding")
    return raw, tape


def provision_engine(output: Path) -> Path:
    archive = output / "godot-linux.zip"
    deadline = time.monotonic() + 180
    with urllib.request.urlopen(ENGINE_URL, timeout=45) as response, archive.open("xb") as stream:
        size = 0
        while block := response.read(1024 * 1024):
            size += len(block)
            if size > 256 * 1024 * 1024 or time.monotonic() > deadline:
                raise ValueError("Pinned runtime acquisition exceeded its finite bound")
            stream.write(block)
    if sha_file(archive) != ENGINE_SHA256:
        raise ValueError("Pinned Linux runtime archive digest differs")
    engine = output / ENGINE_NAME
    with zipfile.ZipFile(archive) as source:
        if source.namelist().count(ENGINE_NAME) != 1 or source.getinfo(ENGINE_NAME).file_size > 512 * 1024 * 1024:
            raise ValueError("Pinned runtime member differs from the fixed bounded engine")
        with source.open(ENGINE_NAME) as reader, engine.open("xb") as target:
            shutil.copyfileobj(reader, target, 1024 * 1024)
    if sha_file(engine) != GODOT_SHA256:
        raise ValueError("Pinned Linux runtime executable digest differs")
    engine.chmod(0o755)
    return engine


class OutputWatch:
    """Sample only this newly created evidence tree; stop the owned worker tree."""
    def __init__(self, output: Path):
        self.output = output
        self.cancel = output / "output-limit.cancel"
        self.stop = threading.Event()
        self.peak = 0
        self.exceeded = False
        self.error = None
        self.thread = threading.Thread(target=self.watch, daemon=True)

    def measure(self):
        deadline, total = time.monotonic() + 10, 0
        for count, path in enumerate(self.output.rglob("*"), 1):
            if count > 100000 or time.monotonic() > deadline:
                raise OSError("Owned evidence scan exceeded its finite entry/time bound")
            try:
                if path.is_symlink():
                    raise OSError("Unexpected link in owned forensic evidence")
                if path.is_file():
                    total += path.stat().st_size
            except FileNotFoundError:
                continue
        self.peak = max(self.peak, total)
        self.exceeded = self.exceeded or total > MAX_OUTPUT_BYTES

    def watch(self):
        while not self.stop.wait(0.2):
            try:
                self.measure()
                if self.exceeded:
                    self.cancel.write_bytes(b"fixed forensic output limit\n")
                    return
            except OSError as error:
                self.error = str(error)
                self.cancel.write_bytes(b"forensic output monitor failed\n")
                return

    def close(self):
        self.stop.set()
        self.thread.join(timeout=12)
        if self.thread.is_alive():
            self.error = "Owned evidence monitor did not finish its bounded scan"
        else:
            try:
                self.measure()
            except OSError as error:
                self.error = str(error)
        return {"sampled_peak_bytes": self.peak, "limit_bytes": MAX_OUTPUT_BYTES,
                "exceeded": self.exceeded, "error": self.error,
                "scope": "owned evidence tree sampled with200ms interval plus final closed-worker scan; each scan<=100000entries/10seconds"}


def product_contract_proof(tape: dict) -> dict:
    matches = []
    for row in tape.get("steps", []):
        failed = [item for item in row.get("assertions", []) if item.get("status") == "fail"]
        if not failed:
            continue
        action, after = row["action"], row["after"]
        actor = next((item for item in after["actors"] if item["id"] == after["selected_actor"]), {})
        body = actor.get("state", {})
        parts = body.get("retained_parts", [])
        spawn, physical = [256.0, 96.0], [256.0, 97.5]
        okay = (action.get("id") == "actor_place"
                and action.get("args") == {"model": "monowheel", "x": 256, "y": 96}
                and row["status"] == "completed" and row["admission"].get("accepted") is True
                and actor.get("model") == "monowheel" and actor.get("authored_spawn") == spawn
                and actor.get("position") == physical and body.get("position") == physical
                and len(parts) >= 2 and parts[0].get("position") == physical and parts[1].get("position") == spawn
                and after.get("paused") is True and after.get("actor_tick") == 0
                and after["native"].get("tick") == 0 and after["native"].get("failed") is False
                and len(failed) == 1 and failed[0].get("id") == "actor_place_position")
        matches.append({"step": row["index"], "valid": okay, "authored_origin": actor.get("authored_spawn"),
                        "physical_root": actor.get("position"), "original_assertion": failed})
    return {"valid": bool(matches) and all(row["valid"] for row in matches), "rows": matches,
            "contract": "Pinned physical_actor_catalog monowheel cab offset(0,1.5); rig adds local part offsets; first-body state reports cab",
            "classification": "test_oracle_defect", "production_gameplay_defect_confirmed": False}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--legacy-source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--godot", type=Path, help="Optional exact pinned Linux runtime")
    args = parser.parse_args(argv)
    output, legacy = args.out.resolve(), args.legacy_source.resolve(strict=True)
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "cybersand-goblin-historical-oracle-reduction-v1", "status": "running",
              "classification": "test_oracle_defect", "production_gameplay_defect_confirmed": False,
              "scope": "Historical exact-source failure reproduction/reduction only; no successor qualification or unchanged-invariant fix claimed",
              "driver_source": git_at(ROOT, "rev-parse", "HEAD"), "driver_sha256": sha_file(Path(__file__)),
              "stages": [], "max_probes": MAX_PROBES, "confirmations": 2,
              "reduction_wall_seconds": 600, "worker_wall_seconds": 900, "memory_limit_mib": 3072}
    watch = OutputWatch(output)
    watch.thread.start()
    code = 2

    def persist():
        write_json(output / "forensic-qualification.json", report)

    def stage(name: str, command: list[str], timeout=60, expected_failure=False):
        if watch.cancel.exists():
            raise ValueError("Owned evidence output monitor stopped the forensic programme")
        process = execute(command, dict(os.environ, PYTHONPATH=str(legacy)), output / (name + ".log"),
                          timeout, cwd=legacy, memory_limit_mib=3072, cancel_path=watch.cancel)
        report["stages"].append({"name": name, "process": process})
        write_json(output / (name + ".process.json"), process)
        persist()
        if process.get("interrupted"):
            raise KeyboardInterrupt
        if expected_failure:
            log = read_log_prefix(output / (name + ".log"))
            expected = (process["status"] == "test_failure" and process["exit_code"] == 1
                        and not process["diagnostic_errors"] and not process["surviving_owned_pids"]
                        and "AssertionError: Observed tape does not satisfy the exact regression acceptance contract" in log
                        and "FAILED (failures=1)" in log and "Ran 1 test" in log)
            if not expected:
                raise ValueError("Unchanged-invariant unittest did not retain precisely its expected historical failure")
        elif process["status"] != "pass" or process["surviving_owned_pids"]:
            raise ValueError("Forensic stage did not complete: " + name + ": " + process["status"])
        return process

    try:
        report["legacy_source"] = source_identity(legacy)
        raw, original = original_case()
        original_path = output / "original-transcript.json"
        original_path.write_bytes(raw)
        report["original_tape_sha256"] = TAPE_SHA256
        report["original_product_contract"] = product_contract_proof(original)
        if not report["original_product_contract"]["valid"]:
            raise ValueError("Original failure lacks the independently transcribed product-contract proof")
        godot = args.godot.resolve(strict=True) if args.godot else provision_engine(output)
        if sha_file(godot) != GODOT_SHA256:
            raise ValueError("Forensic programme requires the exact pinned Linux executable")
        report["godot_sha256"] = sha_file(godot)
        persist()
        reduced_output = output / "reduction"
        stage("native-reduction", [sys.executable, str(legacy / "tools/gip014/run_goblin.py"),
              "--godot", str(godot), "--out", str(reduced_output), "--case", "reduce", "--replay", str(original_path),
              "--max-probes", str(MAX_PROBES), "--confirmations", "2", "--reduction-seconds", "600",
              "--timeout-seconds", "180", "--memory-limit-mib", "3072"], timeout=900)
        reduction = json.loads((reduced_output / "reduction.json").read_text())
        reduced = json.loads((reduced_output / "reduced-transcript.json").read_text())
        if (reduction.get("status") != "reduced" or reduction.get("confirmed_original") is not True
                or not 0 < len(reduced["steps"]) < ORIGINAL_ROWS or len(reduction.get("attempts", [])) > MAX_PROBES):
            raise ValueError("Historical case did not finish its bounded confirmed reduction")
        report["reduced_product_contract"] = product_contract_proof(reduced)
        if not report["reduced_product_contract"]["valid"]:
            raise ValueError("Reduced failure lost the independent physical/authored origin proof")
        report["reduction"] = reduction
        report["original_actions"], report["reduced_actions"] = ORIGINAL_ROWS, len(reduced["steps"])
        bundle = output / "native-reproduction-bundle.json"
        write_json(bundle, {"schema": "cybersand-goblin-reproduction-bundle-v1", "original_tape": original,
                            "reduced_tape": reduced, "reduction": reduction})
        case = output / "regression-case"
        exporter = str(legacy / "tools/gip014/regression_bundle.py")
        stage("export", [sys.executable, exporter, "export", str(bundle), str(case)])
        shutil.copyfile(reduced_output / "reduced-transcript.json", case / "observed-transcript.json")
        stage("reproduction-check", [sys.executable, exporter, "check", str(case), "--mode", "reproduction"])
        stage("unchanged-invariant-unittest", [sys.executable, "-m", "unittest", "discover", "-s", str(case),
              "-p", "test_goblin_regression.py"], expected_failure=True)
        report["legacy_source_after"] = source_identity(legacy)
        report.update(status="pass", unchanged_invariant_regression="expected historical failure retained",
                      original_source_reproduced=True, successor_regression_pass_claimed=False)
        code = 0
    except KeyboardInterrupt:
        report.update(status="cancelled", operator_cancelled=True)
        code = 130
    except (OSError, ValueError, KeyError, TypeError, AssertionError, subprocess.SubprocessError) as error:
        report.update(status="incomplete_or_failed", error=str(error))
    finally:
        report["output_monitor"] = watch.close()
        if (watch.exceeded or watch.error) and code == 0:
            report.update(status="incomplete_or_failed", error="Output monitor did not preserve its evidence bound")
            code = 2
        persist()
        print("GOBLIN_HISTORICAL_REDUCTION " + json.dumps({key: report.get(key) for key in
              ("status", "classification", "original_actions", "reduced_actions", "error")}), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
