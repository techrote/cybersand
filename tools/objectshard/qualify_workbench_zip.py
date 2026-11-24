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
from verify_workbench_package import MANIFEST, verify

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
                        value.get("source_commit") != identity["source_commit"] or value.get("host") != "ordinary-workbench"):
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
