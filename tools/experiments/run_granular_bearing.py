"""One registered fixed-law real-Rapier arm, with source/runtime-bound custody.

The source-matched extension must already be installed in an isolated project.
No runtime publication, dependency download or response tuning is performed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

import ejection_a2 as a2

ROOT = Path(__file__).resolve().parents[2]
ARMS = ("drop1", "drop4", "speed0", "speed30", "speed60", "speed90")
INPUTS = ("godot/tests/test_granular_bearing_capture.gd", "godot/tests/test_ejection_topology_capture.gd",
          "godot/tests/test_ejection_capsules.gd", "godot/tests/helpers/physical_internal_watchdog.gd",
          "godot/scripts/rapier_physics_bridge.gd", "godot/scripts/rigid_body_coupling.gd",
          "godot/scripts/cell_world.gd", "godot/project.godot",
          "tools/experiments/run_granular_bearing.py", "tools/experiments/ejection_a2.py",
          "tools/experiments/ejection_topology.py")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=30)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", type=Path, required=True)
    p.add_argument("--project", type=Path, required=True)
    p.add_argument("--compiled-inputs", type=Path, required=True)
    p.add_argument("--arm", choices=ARMS, required=True)
    p.add_argument("--details", choices=("on", "off"), required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--speed-registration", type=Path)
    args = p.parse_args()
    if args.arm.startswith("speed"):
        if not args.speed_registration:
            p.error("speed arm requires a separately committed conditional registration")
        registration = json.loads(args.speed_registration.read_text(encoding="utf-8"))
        if not registration.get("admitted") or registration["velocities"] != [0, 30, 60, 90]:
            p.error("speed registration not admitted or altered")
        relative = args.speed_registration.resolve().relative_to(ROOT).as_posix()
        if git("show", "HEAD:"+relative) != args.speed_registration.read_bytes():
            p.error("speed registration must be committed before execution")
    compiled = json.loads(args.compiled_inputs.read_text(encoding="utf-8"))
    for relative, expected in compiled.items():
        if sha(ROOT/relative) != expected:
            p.error("native input changed since build: "+relative)
    for relative in INPUTS:
        if relative.startswith("godot/") and sha(ROOT/relative) != sha(args.project/relative[6:]):
            p.error("isolated project differs: "+relative)
    output = args.output.resolve()
    if output.exists():
        p.error("refuse overwriting an experiment directory")
    output.mkdir(parents=True)
    revision = git("rev-parse", "HEAD").decode().strip()
    env = os.environ.copy()
    env["CYBERSAND_SOURCE_REVISION"] = revision
    command = [str(args.godot.resolve()), "--headless", "--path", str(args.project.resolve()),
               "--script", "res://tests/test_granular_bearing_capture.gd", "--", "--arm="+args.arm,
               "--details="+args.details, "--output="+output.as_posix()]
    receipt = {"schema": 1, "source_revision": revision, "tree": git("rev-parse", "HEAD^{tree}").decode().strip(),
               "working_diff_sha256": hashlib.sha256(git("diff", "HEAD", "--binary")).hexdigest(),
               "source_inputs": {s: sha(ROOT/s) for s in INPUTS}, "native_inputs": compiled,
               "runtime": {"godot": sha(args.godot), "native": sha(args.project/"addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
                           "rapier": sha(args.project/"addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")},
               "platform": platform.platform(), "python": sys.version, "command": command,
               "outer_timeout_seconds": 150, "internal_timeout_seconds": 120}
    try:
        with (output/"capture.log").open("wb") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=150)
        receipt["returncode"] = result.returncode
        if result.returncode or "ERROR:" in (output/"capture.log").read_text(encoding="utf-8", errors="replace"):
            raise RuntimeError("capture failed; preserve log at "+str(output))
        acquisition = json.loads((output/"acquisition.json").read_text(encoding="utf-8"))
        events = [json.loads(s) for s in (output/"events.jsonl").read_text(encoding="utf-8").splitlines()]
        corpus, population, sampling = a2.build_corpus(events, acquisition)
        for name, value in (("corpus", corpus), ("population", population), ("sampling", sampling)):
            a2.write_json(output/(name+".json"), value)
        receipt["ok"] = True
        receipt["attempts"] = len(events)
        receipt["artifact_sha256"] = {f.name: sha(f) for f in output.iterdir() if f.is_file()}
    except Exception as error:
        receipt["ok"] = False
        receipt["error"] = str(error)
        raise
    finally:
        a2.write_json(output/"receipt.json", receipt)
    print(json.dumps({"ok": True, "arm": args.arm, "details": args.details, "attempts": len(events)}))


if __name__ == "__main__":
    main()
