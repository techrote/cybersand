#!/usr/bin/env python3
"""Run the repaired graphical input fixture against the admitted Windows cohort."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import atomic_delivery

ROOT = Path(__file__).resolve().parents[2]
RECOVERY = ROOT / "tools/pubpres_final_recovery"
sys.path[:0] = [str(RECOVERY), str(ROOT / "tools/ci")]
from identity import digest, driver_identity
from lfs_runtime_artifact import install
from process_owner import bounded_process
from qualification_gate import verify_summary
from retained_runtime import BINDING, make_binding, validate_runtime
from results import need
from run_campaign import source_identity
from run_focus import ENGINE_SHA256

HELD = ("88bb920c42755669ac8fba37b9fc46249c5bd0a6", "46027331150",
        "780c6722476e44a48fec46a32dfe8ef2080108b7372a03982408c76c229f126a",
        "4c7bd411e8386abc7be896ef4b3958b8d700ea781951db7d3f4be4d6ffc5a180")
WATER = ("e17ce40722a3fabdd6130990eecfca384bf5b6dd", "46032856091",
         "0e87d3e73397b321ba1f75db5ac50a31a04220e85c2bf6f17fd610a6097a1c4c",
         "a2f755ef13618fd05a792d372fc014bc65d0a53465b83da009d5548282aace68")
TRANSITIONS = ("stock-members", "atomic-water-separate-0", "atomic-water-separate-4")
WINDOWS_RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
LINUX_RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"


def write(path, obj):
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def install_rapier(transport, output, revision, run_id):
    def git(*args):
        return subprocess.check_output(["git", "-C", str(ROOT), *map(str, args)], timeout=180)
    git("merge-base", "--is-ancestor", revision, "HEAD")
    need(git("show", "HEAD:" + WINDOWS_RAPIER) == git("show", revision + ":" + WINDOWS_RAPIER),
         "Resulting application requires a different Rapier object")
    with tempfile.TemporaryDirectory(prefix="pubpres-rapier-", dir=os.environ.get("RUNNER_TEMP")) as temp:
        original = Path(temp).resolve() / "source"
        # Transport reads Git's committed pointer and writes only the selected
        # object. Keep this disposable checkout separate from application bytes.
        git("worktree", "add", "--quiet", "--detach", "--no-checkout", original, revision)
        try:
            receipt = install(original, [WINDOWS_RAPIER], [LINUX_RAPIER, WINDOWS_RAPIER],
                              revision, run_id, 1, transport, output / "rapier-install.json")
            shutil.copyfile(original / WINDOWS_RAPIER, ROOT / WINDOWS_RAPIER)
        finally:
            git("worktree", "remove", "--force", original)
    need(digest(ROOT / WINDOWS_RAPIER) == receipt["installed"][0]["sha256"], "Installed Rapier bytes changed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("runtime", "rapier-transport", "stock-engine", "atomic-root", "output"):
        parser.add_argument("--" + flag, type=Path, required=True)
    parser.add_argument("--arm", choices=("stock-held-placement","atomic-submission-safe-0",
                                        "atomic-submission-separate-0","atomic-submission-separate-4",*TRANSITIONS))
    args = parser.parse_args()
    need(os.name == "nt", "Held replay requires actual Windows graphical execution")
    original, stock, atomic_root, output = (p.resolve() for p in (args.runtime, args.stock_engine, args.atomic_root, args.output))
    need(not output.exists() and not (original / BINDING).exists(), "Replay requires fresh output and original native receipts")
    revision, run_id, manifest_sha, dependency_sha = WATER if args.arm in TRANSITIONS else HELD
    need(digest(original / "PUBPRES-RUNTIME.json") == manifest_sha
         and digest(original / "GODOT-CPP-DEPENDENCY.json") == dependency_sha
         and digest(stock) == ENGINE_SHA256["windows"], "Original Windows runtime, dependency receipt or stock engine differs")
    build = atomic_delivery.verify_payload(atomic_root)
    custom = atomic_root / build["gui_executable"]
    output.mkdir(parents=True)
    install_rapier(args.rapier_transport.resolve(), output, revision, run_id)
    source = source_identity(ROOT)
    binding = make_binding(ROOT, source, original, target_platform="windows")
    need(binding["original_build"]["source_commit"] == revision, "Fixture replay native source differs")
    runtime = output / "bound-runtime"
    shutil.copytree(original, runtime)
    write(runtime / BINDING, binding)
    source["native_runtime"] = validate_runtime(ROOT, source, runtime, False)
    driver = driver_identity()
    pin = atomic_delivery.pin()
    exact = ["--engine-payload", atomic_root, "--engine-build-source", pin["source"],
             "--engine-build-run", pin["run"], "--engine-build-attempt", pin["attempt"],
             "--engine-proof-sha256", pin["proof_sha256"]]
    report = {"application": source["source_commit"], "native_build": revision, "runtime_workflow": run_id,
              "attempt": 1, "binding_sha256": digest(runtime / BINDING), "outcomes": [], "complete": False,
              "scope": "Windows focused graphical qualification using a source-bound native runtime.", "physical_acceptance": "HOLD"}
    for label, engine, focus, thread, budget in (
        ("stock-held-placement", stock, "held-placement", "safe", 0),
        ("atomic-submission-safe-0", custom, "submission", "safe", 0),
        ("atomic-submission-separate-0", custom, "submission", "separate", 0),
        ("atomic-submission-separate-4", custom, "submission", "separate", 4),
        ("stock-members", stock, "members", "safe", 0),
        ("atomic-water-separate-0", custom, "water", "separate", 0),
        ("atomic-water-separate-4", custom, "water", "separate", 4),
    ):
        if (args.arm and args.arm != label) or (not args.arm and label in TRANSITIONS):
            continue
        folder = output / label
        cmd = [sys.executable, RECOVERY / "run_qualification.py", "--source", ROOT, "--runtime", runtime,
               "--engine", engine, "--output", folder, "--focus", focus, "--render-thread", thread,
               "--lookahead", budget, *([] if engine == stock else exact)]
        print(f"Running {label}", flush=True)
        with (output / (label + ".log")).open("x", encoding="utf-8") as stream:
            code, timeout = bounded_process(list(map(str, cmd)), cwd=ROOT, stdout=stream,
                                            timeout=2400 if focus=="water" else 1200)
        result = {"label": label, "returncode": code, "timed_out": timeout, "passed": False}
        if code == 0 and not timeout:
            try:
                result["raw_replay"] = verify_summary(folder / "SUMMARY.json", source, driver, engine, focus, thread, budget)
                result["passed"] = True
            except (ValueError, KeyError, TypeError, OSError) as error:
                result["failure"] = str(error)
        report["outcomes"].append(result)
        write(output / "SUMMARY.json", report)
        print(f"{label} passed={result['passed']}", flush=True)
    report["complete"] = all(row["passed"] for row in report["outcomes"])
    write(output / "SUMMARY.json", report)
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
