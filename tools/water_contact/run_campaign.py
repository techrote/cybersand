#!/usr/bin/env python3
"""Reproducible WATER-CONTACT #362 campaign wrapper.

Runs godot/tests/run_water_contact_campaign.gd headlessly with an explicit
timeout, records source/tree/dirty-state, runtime-library and Godot identities
plus the exact command into <out>/packet.json, then runs the strict reducer.

Example:
  python tools/water_contact/run_campaign.py --godot C:/tools/Godot/Godot_v4.7-stable_win64_console.exe \
      --out evidence/windows --stage 2 --workers 1,4
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import reduce_impact_evidence as reducer  # noqa: E402

RUNTIMES = {
    "win32": ["godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
              "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"],
    "linux": ["godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
              "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"],
}


def git(*args: str) -> str:
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--stage", type=int, default=2)
    parser.add_argument("--workers", default="1,4")
    parser.add_argument("--cases", default="")
    parser.add_argument("--arms", default="")
    parser.add_argument("--timeout", type=int, default=5400, help="seconds for the whole Godot campaign")
    args = parser.parse_args(argv)
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    key = "win32" if sys.platform == "win32" else "linux"
    runtimes = {}
    for relative in RUNTIMES[key]:
        path = ROOT / relative
        runtimes[relative] = {"sha256": file_sha(path), "size": path.stat().st_size} if path.is_file() else None
    command = [args.godot, "--headless", "--path", str(ROOT / "godot"), "--script",
               "res://tests/run_water_contact_campaign.gd", "--", f"--out={out}", f"--stage={args.stage}",
               f"--workers={args.workers}", "--probes"]
    if args.cases:
        command.append(f"--cases={args.cases}")
    if args.arms:
        command.append(f"--arms={args.arms}")
    version = subprocess.run([args.godot, "--version"], capture_output=True, text=True).stdout.strip()
    packet = {
        "schema": "water-contact-packet-v1",
        "source_head": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}"),
        "source_branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "source_dirty_paths": [line for line in git("status", "--porcelain").splitlines() if line],
        "manifest_sha256": reducer.manifest_digest(reducer.MANIFEST),
        "runtimes": runtimes, "godot_version": version, "host": {"platform": platform.platform(),
        "machine": platform.machine(), "python": platform.python_version()},
        "command": command, "timeout_seconds": args.timeout,
        "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    started = time.monotonic()
    log = out / "godot.log"
    try:
        with log.open("w", encoding="utf-8", errors="replace") as handle:
            result = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT, timeout=args.timeout)
        packet["exit_code"] = result.returncode
    except subprocess.TimeoutExpired:
        packet["exit_code"] = "timeout"
    packet["duration_seconds"] = round(time.monotonic() - started, 1)
    (out / "packet.json").write_text(json.dumps(packet, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    workers = [int(v) for v in args.workers.split(",") if v]
    status = 0
    if not args.cases and not args.arms:
        report = reducer.reduce([out], reducer.MANIFEST, args.stage, workers)
        (out / "reduction.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                                            encoding="utf-8", newline="\n")
        print(json.dumps({"status": report["status"], "errors": report["errors"][:20]}, indent=2))
        status = 0 if report["status"] == "passed" else 1
    print(json.dumps({"exit_code": packet["exit_code"], "duration_seconds": packet["duration_seconds"]}))
    return status if packet["exit_code"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
