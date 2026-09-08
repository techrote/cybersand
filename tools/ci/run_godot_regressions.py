#!/usr/bin/env python3
"""Run every current Godot fixture against the installed, identified runtime."""
import argparse
import hashlib
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    runtime = ROOT / "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
    identity = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True)
    identity += hashlib.sha256(runtime.read_bytes()).hexdigest() + "  " + str(runtime.relative_to(ROOT)) + "\n"
    (args.output / "identity.txt").write_text(identity, encoding="utf-8")
    cases = [("import", ["--editor", "--quit"], 240)]
    cases += [(p.stem, ["--script", "res://tests/" + p.name], 180)
              for p in sorted((ROOT / "godot/tests").glob("test_*.gd"))]
    cases += [(p, ["--script", "res://tests/" + p + ".gd"], 1200)
              for p in ("profile_native_world", "profile_scheduler")]
    cases += [("scene", ["--quit-after", "180"], 180)]
    for name, flags, timeout in cases:
        command = [args.godot, "--headless", "--path", str(ROOT / "godot"), *flags]
        print(f"Running {name}, timeout {timeout}s: {command}", flush=True)
        with (args.output / (name + ".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        output = (args.output / (name + ".log")).read_text(encoding="utf-8", errors="replace")
        print(output, end="", flush=True)
        if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
            raise RuntimeError(f"{name} failed (exit {result.returncode}); see retained output")
    print(f"Passed {len(cases)} invocations including all test_*.gd fixtures, profiles and scene")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
