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

ORIGINAL = "88bb920c42755669ac8fba37b9fc46249c5bd0a6"
RUN = "46027331150"
MANIFEST_SHA = "780c6722476e44a48fec46a32dfe8ef2080108b7372a03982408c76c229f126a"
DEPENDENCY_SHA = "4c7bd411e8386abc7be896ef4b3958b8d700ea781951db7d3f4be4d6ffc5a180"
WINDOWS_RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
LINUX_RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"


def write(path, obj):
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def install_rapier(transport, output):
    def git(*args):
        return subprocess.check_output(["git", "-C", str(ROOT), *map(str, args)], timeout=180)
    git("merge-base", "--is-ancestor", ORIGINAL, "HEAD")
    need(git("show", "HEAD:" + WINDOWS_RAPIER) == git("show", ORIGINAL + ":" + WINDOWS_RAPIER),
         "Resulting application requires a different Rapier object")
    with tempfile.TemporaryDirectory(prefix="pubpres-rapier-", dir=os.environ.get("RUNNER_TEMP")) as temp:
        original = Path(temp).resolve() / "source"
        # Transport reads Git's committed pointer and writes only the selected
        # object. Keep this disposable checkout separate from application bytes.
        git("worktree", "add", "--quiet", "--detach", "--no-checkout", original, ORIGINAL)
        try:
            receipt = install(original, [WINDOWS_RAPIER], [LINUX_RAPIER, WINDOWS_RAPIER],
                              ORIGINAL, RUN, 1, transport, output / "rapier-install.json")
            shutil.copyfile(original / WINDOWS_RAPIER, ROOT / WINDOWS_RAPIER)
        finally:
            git("worktree", "remove", "--force", original)
    need(digest(ROOT / WINDOWS_RAPIER) == receipt["installed"][0]["sha256"], "Installed Rapier bytes changed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("runtime", "rapier-transport", "stock-engine", "atomic-root", "output"):
        parser.add_argument("--" + flag, type=Path, required=True)
    parser.add_argument("--arm", choices=("stock-held-placement","atomic-submission-safe-0",
                                        "atomic-submission-separate-0","atomic-submission-separate-4"))
    args = parser.parse_args()
    need(os.name == "nt", "Held replay requires actual Windows graphical execution")
    original, stock, atomic_root, output = (p.resolve() for p in (args.runtime, args.stock_engine, args.atomic_root, args.output))
    need(not output.exists() and not (original / BINDING).exists(), "Replay requires fresh output and original native receipts")
    need(digest(original / "PUBPRES-RUNTIME.json") == MANIFEST_SHA
         and digest(original / "GODOT-CPP-DEPENDENCY.json") == DEPENDENCY_SHA
         and digest(stock) == ENGINE_SHA256["windows"], "Original Windows runtime, dependency receipt or stock engine differs")
    build = atomic_delivery.verify_payload(atomic_root)
    custom = atomic_root / build["gui_executable"]
    output.mkdir(parents=True)
    install_rapier(args.rapier_transport.resolve(), output)
    source = source_identity(ROOT)
    binding = make_binding(ROOT, source, original, target_platform="windows")
    need(binding["original_build"]["source_commit"] == ORIGINAL, "Fixture replay native source differs")
    runtime = output / "bound-runtime"
    shutil.copytree(original, runtime)
    write(runtime / BINDING, binding)
    source["native_runtime"] = validate_runtime(ROOT, source, runtime, False)
    driver = driver_identity()
    pin = atomic_delivery.pin()
    exact = ["--engine-payload", atomic_root, "--engine-build-source", pin["source"],
             "--engine-build-run", pin["run"], "--engine-build-attempt", pin["attempt"],
             "--engine-proof-sha256", pin["proof_sha256"]]
    report = {"application": source["source_commit"], "native_build": ORIGINAL, "runtime_workflow": RUN,
              "attempt": 1, "binding_sha256": digest(runtime / BINDING), "outcomes": [], "complete": False,
              "scope": "Windows held placement and original bounded actual-submission gates only.", "physical_acceptance": "HOLD"}
    for label, engine, focus, thread, budget in (
        ("stock-held-placement", stock, "held-placement", "safe", 0),
        ("atomic-submission-safe-0", custom, "submission", "safe", 0),
        ("atomic-submission-separate-0", custom, "submission", "separate", 0),
        ("atomic-submission-separate-4", custom, "submission", "separate", 4),
    ):
        if args.arm and args.arm != label:
            continue
        folder = output / label
        cmd = [sys.executable, RECOVERY / "run_qualification.py", "--source", ROOT, "--runtime", runtime,
               "--engine", engine, "--output", folder, "--focus", focus, "--render-thread", thread,
               "--lookahead", budget, *([] if engine == stock else exact)]
        print(f"Running {label}", flush=True)
        with (output / (label + ".log")).open("x", encoding="utf-8") as stream:
            code, timeout = bounded_process(list(map(str, cmd)), cwd=ROOT, stdout=stream, timeout=1200)
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
