#!/usr/bin/env python3
"""Qualify the immutable delivered ZIP through its shipped Windows launchers.

Only an actual Windows run can pass. Each case extracts the same archive bytes;
neither launchers nor manifest entries are repaired after packaging. This probe
complements the full delivered-package test suite and is not physical acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time
import zipfile

from verify_package import verify

PATH_CASES = {
    "spaces": "ObjectShard evaluation with spaces",
    "parentheses": "ObjectShard Lab (1)",
    "nested": "nested evaluation/another level/longer extraction directory/owner playtesting/candidate",
    "unicode": "ObjectShard_日本語_é",
}


def qualify_verifier_adversaries(target: Path, output: Path, timeout: int) -> dict:
    """Exercise strict verification without relying on Get-FileHash autoload.

    The delivered archive never changes. One already-qualified extraction is
    deliberately corrupted only for the negative test, restored byte-for-byte
    in finally, and verified again before any success can be reported.
    """
    environment = dict(os.environ, OBJECTSHARD_QUALIFICATION_ROOT=str(target.resolve()))
    shadow = ("function global:Get-FileHash { throw 'Get-FileHash dependency forbidden by qualification' }; "
              "& (Join-Path $env:OBJECTSHARD_QUALIFICATION_ROOT 'tools/objectshard/verify_package.ps1') "
              "-Package $env:OBJECTSHARD_QUALIFICATION_ROOT")
    independent = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", shadow],
                                 cwd=target, env=environment, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, timeout=timeout)
    (output / "verifier-without-get-file-hash.log").write_bytes(independent.stdout)
    if independent.returncode != 0:
        raise ValueError("Shipped verifier depends on unavailable Get-FileHash module loading")
    document = target / "READ-ME.md"
    original = document.read_bytes()
    original_sha = hashlib.sha256(original).hexdigest()
    corrupted: subprocess.CompletedProcess | None = None
    try:
        document.write_bytes(original + b"\nDeliberate delivered-package tamper qualification.\n")
        command = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", "Verify ObjectShard Lab.cmd", "--noninteractive"]
        corrupted = subprocess.run(command, cwd=target, env=environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, timeout=timeout)
        (output / "verifier-tamper-refusal.log").write_bytes(corrupted.stdout)
        if corrupted.returncode == 0 or not re.search(rb"Package file changed:\s*READ-ME\.md", corrupted.stdout):
            raise ValueError("Shipped verifier did not specifically reject the changed READ-ME.md hash")
    finally:
        document.write_bytes(original)
        if hashlib.sha256(document.read_bytes()).hexdigest() != original_sha:
            raise ValueError("Deliberate verifier tamper could not be restored exactly")
        verify(target)
    assert corrupted is not None
    return {"get_file_hash_shadow_exit_code": independent.returncode,
            "tamper_exit_code": corrupted.returncode, "tamper_path": "READ-ME.md",
            "specific_hash_failure_observed": True, "restored_sha256": original_sha,
            "after_restoration_inventory_verified": True,
            "scope": "Unchanged delivered ZIP; explicit adversarial extraction restored and fully reverified"}


def extract(archive: Path, target: Path) -> None:
    with zipfile.ZipFile(archive) as stream:
        for item in stream.infolist():
            path = PurePosixPath(item.filename)
            if path.is_absolute() or ".." in path.parts or "\\" in item.filename or ":" in item.filename:
                raise ValueError("Unsafe ZIP member: " + item.filename)
            if item.external_attr >> 16 & 0o170000 == 0o120000:
                raise ValueError("ZIP symlinks are not admitted")
        stream.extractall(target)


def create_archive(package: Path, archive: Path) -> dict:
    identity = verify(package)
    if archive.exists():
        raise ValueError("Refusing to overwrite delivered ZIP")
    archive.parent.mkdir(parents=True, exist_ok=True)
    # Archive only the verified inventory and its manifest: no editor cache or
    # first-run files created by previous package replay can enter the delivery.
    members = sorted(identity["files_sha256"]) + ["objectshard-lab-manifest.json"]
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as stream:
        for member in members:
            stream.write(package / member, member)
    return identity



def validate_launch_receipt(launched: dict, identity: dict, *, preflight: bool = False) -> None:
    schema = "objectshard-worker-package-launch-v1" if preflight else "objectshard-package-launch-v1"
    minimum = 15 if preflight else 6
    if (launched.get("schema") != schema or type(launched.get("failures")) is not int or launched["failures"] != 0
            or type(launched.get("checks")) is not int or launched["checks"] < minimum
            or launched.get("source_commit") != identity["source_commit"]):
        raise ValueError("Missing or failed exact-source launch receipt")
    if preflight and (launched.get("host") != "standalone-exclusive-worker-rehearsal"
                      or launched.get("production_workbench") is not False):
        raise ValueError("Preflight launch receipt misrepresents the executed host")


def qualify(archive: Path, output: Path, timeout: int = 240, extract_root: Path | None = None) -> dict:
    if sys.platform != "win32":
        raise ValueError("Shipped CMD qualification requires actual Windows")
    output.mkdir(parents=True, exist_ok=False)
    extraction = extract_root or output / "extracted"
    if extraction.exists():
        raise ValueError("Refusing to reuse ZIP extraction directories")
    with archive.open("rb") as stream:
        archive_hash = hashlib.file_digest(stream, "sha256").hexdigest()
    report = {"schema": "objectshard-windows-zip-qualification-v1", "archive": str(archive.resolve()),
              "zip_sha256": archive_hash, "cases": [], "failures": [], "status": "incomplete"}
    try:
        for name, relative in PATH_CASES.items():
            target = extraction / relative
            extract(archive, target)
            identity = verify(target)
            row = {"case": name, "root": str(target.resolve()), "root_characters": len(str(target.resolve())),
                   "source_commit": identity["source_commit"], "commands": []}
            report["cases"].append(row)
            commands = [("Verify ObjectShard Lab.cmd", "--noninteractive", "verify"),
                        ("Open ObjectShard Lab.cmd", "--self-test", "launch")]
            if "preflight" in identity:
                commands.append((identity["preflight"]["launcher"], "--self-test", "preflight"))
            for script, flag, kind in commands:
                receipt = (output / (name + "-" + kind + ".json")).resolve()
                environment = dict(os.environ, OBJECTSHARD_LAUNCH_RECEIPT=str(receipt))
                command = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", script, flag]
                started = time.monotonic()
                result = subprocess.run(command, cwd=target, env=environment,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
                (output / (name + "-" + kind + ".log")).write_bytes(result.stdout)
                row["commands"].append({"script": script, "exit_code": result.returncode,
                                         "elapsed_seconds": time.monotonic() - started})
                if result.returncode != 0:
                    raise ValueError(name + ": shipped launcher failed: " + script)
                if kind != "verify":
                    launched = json.loads(receipt.read_text(encoding="utf-8"))
                    validate_launch_receipt(launched, identity, preflight=kind == "preflight")
                    row["launch_receipt" if kind == "launch" else "preflight_launch_receipt"] = launched
            verify(target)
            if name == "spaces":
                row["verifier_adversaries"] = qualify_verifier_adversaries(target, output, timeout)
        report["status"] = "passed"
    except Exception as error:
        report["failures"].append(str(error))
        raise
    finally:
        (output / "result.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, help="Create the immutable ZIP from this verified package first")
    parser.add_argument("--zip", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--extract-root", type=Path, help="Separate temporary root; do not upload four runtime copies with the evidence")
    args = parser.parse_args()
    if args.package:
        create_archive(args.package, args.zip)
    # The retained UTF-8 report preserves literal paths. Console JSON must also
    # survive Windows' legacy code page after successful Unicode-path probes.
    print(json.dumps(qualify(args.zip.resolve(), args.output.resolve(), args.timeout,
                             args.extract_root.resolve() if args.extract_root else None), indent=2, ensure_ascii=True))


if __name__ == "__main__":
    main()
