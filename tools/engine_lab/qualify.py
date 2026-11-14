#!/usr/bin/env python3
"""ENG-LAB-001: source-bound Godot 4.7 passive recorder and mounted Workbench qualification."""
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

ROOT = Path(__file__).resolve().parents[2]
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
ERROR = re.compile(r"(?im)^(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script)")
TESTS = [
    ("unit", "res://tests/test_engine_lab_passive_recorder.gd", "ENG_LAB_PASSIVE:"),
    ("mount", "res://tests/test_engine_lab_passive_mount.gd", "ENGINE_LAB_MOUNT:"),
]


def sha(path: Path) -> str:
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def run(args: list[str], cwd: Path, evidence: Path, marker: str, deadline: int) -> dict:
    started = time.monotonic()
    report: dict = {"command": args, "ok": False, "timeout_s": deadline}
    try:
        result = subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                                errors="replace", timeout=deadline,
                                env={**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1"})
        log = result.stdout + "\n--- stderr ---\n" + result.stderr
        report["returncode"] = result.returncode
        matched = bool(re.search(re.escape(marker) + r" \d+ (?:checks|assertions), 0 failures", log)) if marker else True
        report["ok"] = (result.returncode == 0 and ERROR.search(log) is None and matched)
        report["marker"] = matched
    except subprocess.TimeoutExpired as exc:
        log = f"TIMEOUT: {exc}\nstdout:{exc.stdout}\nstderr:{exc.stderr}"
        report["error"] = "timeout"
    evidence.write_text(log, encoding="utf-8")
    report["elapsed_seconds"] = round(time.monotonic() - started, 3)
    report["log_sha256"] = sha(evidence)
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--godot", type=Path, required=True)
    ap.add_argument("--expected-sha", required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--rendering-driver",
                    default="opengl3_angle" if sys.platform == "win32" else "opengl3")
    args = ap.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / "receipt.json"
    if receipt.exists():
        ap.error("Refusing to overwrite retained evidence")
    report: dict = {"schema":"eng-lab-passive-ci-v1", "ok":False,
                    "qualification":"actual native/graphics Workbench + detached recorder",
                    "cases": {}, "source": None}
    try:
        source = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                                          text=True, timeout=30).strip()
        if source != args.expected_sha:
            raise RuntimeError(f"source HEAD mismatch {source}")
        if subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"],
                                   text=True, timeout=30).strip():
            raise RuntimeError("checkout source is dirty")
        report["source"] = source
        engine = args.godot.resolve(strict=True)
        version = subprocess.check_output([str(engine),"--version"], cwd=ROOT,
                                          text=True, timeout=30).strip()
        if version != GODOT_VERSION:
            raise RuntimeError("Godot version mismatch " + version)
        report["godot"] = {"version":version,"sha256":sha(engine)}
        platform = "windows" if sys.platform == "win32" else "linux"
        library = ("cybersand_native.windows.x86_64.dll" if platform == "windows"
                   else "libcybersand_native.linux.x86_64.so")
        native = ROOT / "godot/addons/cybersand_native/bin" / library
        manifest_file = ROOT / "godot/addons/cybersand_native" / (
            "runtime-provenance.json" if platform == "windows" else "runtime-provenance.linux.json")
        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
        if native.stat().st_size < 1024 or sha(native) != manifest.get("sha256"):
            raise RuntimeError("not a source-matched native binary")
        report["native"] = {"sha256":sha(native),"source_commit":manifest.get("source_commit")}
        project = ROOT / "godot"
        checks = [
            ("import",[str(engine),"--headless","--path",str(project),"--editor","--quit"],"",240),
            ("unit",[str(engine),"--headless","--path",str(project),"--script",TESTS[0][1]],TESTS[0][2],180),
            ("mount",[str(engine),"--path",str(project),"--rendering-driver",args.rendering_driver,
                      "--script",TESTS[1][1]],TESTS[1][2],300),
        ]
        for name,command,marker,seconds in checks:
            case = run(command,ROOT,out/(name+".log"),marker,seconds)
            report["cases"][name]=case
            print(name, "PASS" if case["ok"] else "FAIL", case["elapsed_seconds"],flush=True)
            if not case["ok"]:
                raise RuntimeError("qualification case failed: "+name)
        report["ok"] = True
    except Exception as exc:
        report["error"] = type(exc).__name__ + ": " + str(exc)
        print(report["error"],file=sys.stderr,flush=True)
    finally:
        receipt.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
