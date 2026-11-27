"""Run the registered ABBA and bounded cohorts on the host holding the raw gates."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("current", "bounded"))
    for option in ("runtime-root", "stock-engine", "correctness", "output"):
        parser.add_argument("--" + option, type=Path, required=True)
    parser.add_argument("--atomic-root", type=Path)
    parser.add_argument("--current-main-source", type=Path)
    parser.add_argument("--display-wrapper", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    register = json.loads((HERE / "registration.json").read_bytes())
    selection = json.loads((ROOT / "tools/pubpres_recovery_windows/selection.json").read_bytes())
    shared = ["--runtime", args.runtime_root / "C", "--stock-engine", args.stock_engine,
              "--water-composition", str(selection["water_composition"])]
    if args.display_wrapper:
        shared.extend(["--display-wrapper", args.display_wrapper])
    for case in register["primary_cases"]:
        shared.extend(["--case", case])
    pin = json.loads((ROOT / "tools/pubpres_recovery_windows/atomic-engine.json").read_bytes())
    atomic = ["--correctness-inventory", args.correctness / "INVENTORY.json",
              "--engine-build-source", pin["source"], "--engine-build-run", str(pin["run"]),
              "--engine-build-attempt", str(pin["attempt"]), "--engine-proof-sha256", pin["proof_sha256"]]
    if args.atomic_root:
        atomic.extend(["--engine-payload", args.atomic_root])

    def run(name, script, options):
        command = [sys.executable, HERE / script, "--output", output / name, *shared, *options]
        print(subprocess.list2cmdline(list(map(str, command))), flush=True)
        subprocess.run(command, check=True)

    if args.mode == "current":
        if args.current_main_source is None:
            parser.error("current requires --current-main-source")
        windows = os.name == "nt"
        platform = "windows" if windows else "linux"
        rapier = json.loads((ROOT / f"godot/addons/godot-rapier2d/runtime-provenance.{platform}.json").read_bytes())
        subgroup = "stock-{}-correctness" if windows else "stock-{}"
        options = ["--current-main-source", args.current_main_source, "--current-main-runtime", args.runtime_root / "N",
                   "--rapier-runtime", ROOT / rapier["artifact"], "--architecture", selection["architecture"],
                   "--stock-correctness", args.correctness / subgroup.format("frozen") / "SUMMARY.json",
                   "--stock-water-correctness", args.correctness / subgroup.format("water") / "SUMMARY.json",
                   "--task-completion", "0"]
        if selection["architecture"] != "stock_safe":
            options.extend(atomic)
        run("current-main", "run_current_main_comparison.py", options)
    else:
        if os.name != "nt" or args.atomic_root is None:
            parser.error("qualified bounded timing requires Windows and --atomic-root")
        calibrations = []
        for role in ("stock", "bounded"):
            name = "calibration-" + role
            run(name, "run_bounded_comparison.py", [*atomic, "--mode", "observer-abba", "--calibration-engine", role])
            calibrations.extend(["--observer-calibration", output / name / "SUMMARY.json"])
        run("six-arms", "run_bounded_comparison.py", [*atomic, "--mode", "cohort", *calibrations])


if __name__ == "__main__":
    main()
