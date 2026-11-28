#!/usr/bin/env python3
"""Execute the shipped Workbench CMD from immutable ZIP extractions on Windows."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile

from qualify_windows_zip import extract
from verify_workbench_package import (CANDIDATE_PROVENANCE, CANDIDATE_REUSE_PROVENANCE,
                                      MANIFEST, RETAINED_PROVENANCE, RETAINED_REFERENCE, verify)

PATHS = {"spaces": "Workbench evaluation with spaces", "parentheses": "Workbench (1)",
         "unicode": "Workbench_日本語_é", "nested": "nested/owner evaluation/longer directory/Workbench"}


def create_archive(package: Path, archive: Path) -> dict:
    identity = verify(package)
    if archive.exists():
        raise ValueError("Refusing to overwrite delivered ZIP")
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for member in sorted(identity["files_sha256"]) + [MANIFEST]:
            z.write(package / member, member)
    return identity


def qualify_provenance_refusals(target: Path, output: Path, timeout: int) -> list[dict]:
    """Exercise the shipped verifier against deliberately defective ledgers.

    Only this disposable extraction is changed. Candidate-field mutations also
    update its payload hash so the structural custody checks, rather than just
    the outer file checksum, must reject a stale or unrelated native ledger.
    """
    paths = {"candidate": target / CANDIDATE_PROVENANCE,
             "manifest": target / MANIFEST, "reference": target / RETAINED_REFERENCE}
    original = {name: path.read_bytes() for name, path in paths.items()}
    active_retained = target / RETAINED_PROVENANCE
    if active_retained.exists():
        raise ValueError("Provenance refusal fixture would overwrite an active ledger")
    reuse = (target / CANDIDATE_REUSE_PROVENANCE).is_file()
    stale_identity_refusal = ("Reused native candidate equivalence provenance mismatch"
                              if reuse else "Reused native candidate lacks an inventoried equivalence receipt")
    cases = (
        ("missing-candidate", None, "Missing package file:"),
        ("tampered-candidate", None, "Package file changed:"),
        ("incorrect-candidate-kind", {"kind": "retained-runtime"}, "Native candidate provenance contract mismatch"),
        ("stale-candidate-source", {"source_commit": "0" * 40}, stale_identity_refusal),
        ("stale-candidate-build", {"build_commit": "0" * 40}, stale_identity_refusal),
        ("wrong-candidate-runtime", {"sha256": "0" * 64}, "Candidate binary identity mismatch"),
        ("missing-retained-reference", None, "Missing package file:"),
        ("active-retained-provenance", None, "Active retained runtime provenance is forbidden"),
    )
    observations = []
    try:
        for name, mutation, expected in cases:
            for key, path in paths.items():
                path.write_bytes(original[key])
            active_retained.unlink(missing_ok=True)
            if mutation is not None:
                candidate = json.loads(original["candidate"])
                candidate.update(mutation)
                paths["candidate"].write_text(json.dumps(candidate), encoding="utf-8")
                manifest = json.loads(original["manifest"])
                manifest["files_sha256"][CANDIDATE_PROVENANCE] = hashlib.sha256(paths["candidate"].read_bytes()).hexdigest()
                paths["manifest"].write_text(json.dumps(manifest), encoding="utf-8")
            elif name == "missing-candidate":
                paths["candidate"].unlink()
            elif name == "tampered-candidate":
                paths["candidate"].write_bytes(original["candidate"] + b"\nDeliberate provenance tamper.\n")
            elif name == "missing-retained-reference":
                paths["reference"].unlink()
            elif name == "active-retained-provenance":
                active_retained.write_bytes(original["reference"])
            cmd = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", "Verify Workbench.cmd", "--noninteractive"]
            run = subprocess.run(cmd, cwd=target, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
            log_name = "provenance-" + name + "-refusal.log"
            (output / log_name).write_bytes(run.stdout)
            if run.returncode == 0 or expected.encode() not in run.stdout:
                raise ValueError("Shipped verifier did not specifically refuse " + name)
            observations.append({"case": name, "exit_code": run.returncode, "expected_refusal": expected, "log": log_name})
    finally:
        for key, path in paths.items():
            path.write_bytes(original[key])
        active_retained.unlink(missing_ok=True)
    verify(target)
    return observations


def qualify(args: argparse.Namespace) -> dict:
    if sys.platform != "win32":
        raise ValueError("Shipped CMD qualification requires actual Windows")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if args.extract_root.exists():
        raise ValueError("Refusing to reuse delivered ZIP extraction")
    archive_hash = hashlib.sha256(args.zip.read_bytes()).hexdigest()
    report = {"schema": "objectshard-m4-workbench-zip-v1", "status": "incomplete", "zip_sha256": archive_hash,
              "cases": [], "failures": [], "physical_owner_acceptance": "not established by hosted execution"}
    try:
        for name, relative in PATHS.items():
            target = (args.extract_root / relative).resolve()
            extract(args.zip, target)
            identity = verify(target)
            user = (output / "isolated-user-data" / name).resolve()
            user.mkdir(parents=True)
            row = {"case": name, "root": str(target), "source_commit": identity["source_commit"], "commands": []}
            report["cases"].append(row)
            for script, flag, kind in (("Verify Workbench.cmd", "--noninteractive", "verify"),
                                       ("Open Workbench.cmd", "--self-test", "launch")):
                receipt = output / (name + "-" + kind + ".json")
                environment = dict(os.environ, OBJECTSHARD_LAUNCH_RECEIPT=str(receipt), APPDATA=str(user), LOCALAPPDATA=str(user))
                cmd = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", script, flag]
                start = time.monotonic()
                run = subprocess.run(cmd, cwd=target, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     timeout=args.timeout)
                (output / (name + "-" + kind + ".log")).write_bytes(run.stdout)
                row["commands"].append({"script": script, "exit_code": run.returncode, "seconds": time.monotonic() - start})
                if run.returncode:
                    raise ValueError(name + ": shipped launcher failed: " + script)
                if kind == "launch":
                    value = json.loads(receipt.read_text(encoding="utf-8"))
                    if (value.get("schema") != "objectshard-m4-workbench-package-launch-v1" or
                        type(value.get("failures")) is not int or value["failures"] != 0 or
                        type(value.get("checks")) is not int or value["checks"] < 8 or
                        value.get("source_commit") != identity["source_commit"] or value.get("host") != "ordinary-workbench" or
                        value.get("rendering_driver") != identity["entry"]["rendering_driver"] or
                        value.get("rendering_method") != "gl_compatibility" or
                        value.get("startup_scene") != "res://feature_launcher.tscn" or value.get("scene_id") != "tower" or
                        not {"--shared-workbench", "--objectshard-m4-workbench", "--object-shard-scene=tower"}.issubset(value.get("launch_arguments", []))):
                        raise ValueError("Missing exact-source ordinary Workbench launch receipt")
                    row["launch_receipt"] = value
            if name == "spaces":
                # Only this disposable extraction is tampered with; delivered ZIP
                # remains immutable and the original bytes are restored in finally.
                path = target / "READ-ME.md"
                original = path.read_bytes()
                try:
                    path.write_bytes(original + b"\nDeliberate qualification tamper.\n")
                    cmd = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", "Verify Workbench.cmd", "--noninteractive"]
                    run = subprocess.run(cmd, cwd=target, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=args.timeout)
                    (output / "tamper-refusal.log").write_bytes(run.stdout)
                    if run.returncode == 0 or not re.search(rb"Package file changed:\s*READ-ME\.md", run.stdout):
                        raise ValueError("Verifier did not specifically refuse altered source bytes")
                    row["tamper_refused"] = True
                finally:
                    path.write_bytes(original)
                unexpected = target / "godot" / "unexpected-input.gdextension"
                if unexpected.exists():
                    raise ValueError("Unexpected-file refusal fixture would overwrite a package member")
                try:
                    unexpected.write_text("[configuration]\nentry_symbol = \"not_executed\"\n", encoding="utf-8")
                    cmd = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", "Verify Workbench.cmd", "--noninteractive"]
                    run = subprocess.run(cmd, cwd=target, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=args.timeout)
                    (output / "unlisted-input-refusal.log").write_bytes(run.stdout)
                    if run.returncode == 0 or not re.search(rb"Unlisted package input:\s*godot/unexpected-input\.gdextension", run.stdout):
                        raise ValueError("Verifier did not specifically refuse an unlisted loadable input")
                    row["unlisted_input_refused"] = True
                finally:
                    unexpected.unlink(missing_ok=True)
                row["provenance_refusals"] = qualify_provenance_refusals(target, output, args.timeout)
            verify(target)
        if hashlib.sha256(args.zip.read_bytes()).hexdigest() != archive_hash:
            raise ValueError("Delivered archive changed during qualification")
        report["status"] = "passed"
    except Exception as error:
        report["failures"].append(str(error))
        report["status"] = "failed"
    finally:
        (output / "result.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--zip", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--extract-root", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    if args.package:
        create_archive(args.package, args.zip)
    result = qualify(args)
    print(json.dumps(result, indent=2, ensure_ascii=True))
    raise SystemExit(0 if result["status"] == "passed" else 1)
