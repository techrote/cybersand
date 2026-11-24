#!/usr/bin/env python3
"""Run the fixed successor inventory serially on one owned hosted graphics machine."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))
from process_owner import bounded_process


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("runtime-root", "engine-root", "frozen-root", "output"):
        parser.add_argument("--" + key, type=Path, required=True)
    args = parser.parse_args()
    phase = os.environ.get("PUBPRES_FINAL_PHASE")
    if phase not in ("development", "final", "delivery"):
        raise ValueError("Missing verified campaign phase")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    windows = os.name == "nt"
    engine = args.engine_root.resolve() / ("Godot_v4.7-stable_win64.exe" if windows else "Godot_v4.7-stable_linux.x86_64")
    runtime = args.runtime_root.resolve()
    shutil.copyfile(args.engine_root.resolve() / "ENGINE.json", output / "ENGINE.json")
    display = [] if windows else ["--display-wrapper", str(ROOT / "tools/pubpres_playability_build/owned_xvfb.py")]
    report = {"schema": "pubpres-final-hosted-inventory-v1", "phase": phase,
              "source": os.environ.get("GITHUB_SHA"), "run_id": os.environ.get("GITHUB_RUN_ID"),
              "attempt": os.environ.get("GITHUB_RUN_ATTEMPT"), "platform": "windows" if windows else "linux",
              "outcomes": [], "unexecuted": [], "complete": False, "physical_acceptance": "HOLD"}
    def save():
        (output / "INVENTORY.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    def run(label, arguments, seconds):
        log = output / (label + ".log")
        command = [sys.executable, *arguments]
        print("Executing", label, flush=True)
        entry = {"name": label, "command": command, "timeout_seconds": seconds, "returncode": None}
        report["outcomes"].append(entry)
        save()
        with log.open("x", encoding="utf-8") as stream:
            status, timed_out = bounded_process(command, cwd=ROOT, stdout=stream, timeout=seconds)
        entry.update(returncode=status, timed_out=timed_out)
        save()
        return status == 0 and not timed_out
    basic = run("successor-correctness", [str(ROOT / "tools/pubpres_final/run_qualification.py"),
            "--runtime", str(runtime / "C"), "--engine", str(engine), "--output", str(output / "correctness"), *display], 8400)
    if phase == "final":
        run("original-safe-regressions", [str(ROOT / "tools/pubpres_playability_build/run_regressions.py"),
            "--profile", "completion-safe", "--runtime", str(runtime / "C"), "--engine", str(engine),
            "--output", str(output / "original-safe"), *display], 8400)
    if phase != "delivery" and basic:
        common = [str(ROOT / "tools/pubpres_final/run_comparison.py"),
                  "--control-source", str(args.frozen_root.resolve()), "--control-runtime", str(runtime / "D"),
                  "--candidate-source", str(ROOT), "--candidate-runtime", str(runtime / "C"),
                  "--engine", str(engine), *display]
        primary = ["wave_512_follow", "wave_gameplay_2048_follow"]
        for mode in ("source-abba", "slots-abba"):
            run(mode, [*common, "--mode", mode, "--case", primary[0], "--case", primary[1],
                       "--output", str(output / mode)], 4800)
        if phase == "final":
            # Independent 60-second ordinary mounted captures retain all steps
            # beyond the registered first-144 window. No tail is discarded.
            for slots in (2, 3):
                run("sustained-slots" + str(slots), [*common, "--mode", "single", "--sustained",
                    "--slots", str(slots), "--case", primary[1], "--output", str(output / ("sustained-slots" + str(slots)))], 1800)
            for case in ("wave_1024_follow_4", "wave_landscape_follow", "pressure_512_follow", "freemass_2048_follow"):
                run("confirmation-" + case, [*common, "--mode", "source-abba", "--case", case,
                    "--output", str(output / ("confirmation-" + case))], 2400)
    elif phase != "delivery":
        report["unexecuted"].append({"scope": "timed comparisons", "reason": "Required successor correctness did not pass"})
    report["complete"] = not report["unexecuted"] and all(row["returncode"] == 0 and not row["timed_out"] for row in report["outcomes"])
    save()
    print(json.dumps({"complete": report["complete"], "scope": "Execution/evidence validity, not performance acceptance",
                      "outcomes": len(report["outcomes"]), "unexecuted": report["unexecuted"]}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
