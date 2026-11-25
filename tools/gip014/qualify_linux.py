#!/usr/bin/env python3
"""Focused Linux goblin-002 qualification; no native rebuild or default activation."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request
import zipfile

import campaign_queue
import run_goblin
import qualify_reproduction

ENGINE_URL = "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip"
ENGINE_SHA256 = "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c"
ENGINE_NAME = "Godot_v4.7-stable_linux.x86_64"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--plan", choices=campaign_queue.PLAN_KINDS, default="full")
    parser.add_argument("--godot", type=Path, help="Optional locally provisioned exact pinned engine")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    ledger = {"schema": "cybersand-goblin-linux-qualification-v2", "status": "running", "source_commit": run_goblin.git("rev-parse", "HEAD"),
              "steps": [], "scope": "Actual Linux Godot and retained source-matched native/Rapier runtime; no physical NVIDIA acceptance"}
    def save(name, code):
        ledger["steps"].append({"case": name, "exit_code": code, "status": "pass" if code == 0 else "failed"})
        run_goblin.write_json(out / "linux-qualification.json", ledger)
        return code == 0
    try:
        if args.godot:
            godot = args.godot.resolve(strict=True)
        else:
            archive = out / "godot-linux.zip"
            with urllib.request.urlopen(ENGINE_URL, timeout=120) as response, archive.open("wb") as stream:
                while block := response.read(1024 * 1024):
                    stream.write(block)
            if run_goblin.sha_file(archive) != ENGINE_SHA256:
                raise ValueError("Pinned Linux Godot archive digest differs")
            godot = out / ENGINE_NAME
            with zipfile.ZipFile(archive) as source:
                if source.testzip() is not None or source.namelist().count(ENGINE_NAME) != 1:
                    raise ValueError("Pinned Linux engine ZIP integrity failed")
                godot.write_bytes(source.read(ENGINE_NAME))
            godot.chmod(0o755)
        identity = run_goblin.runtime_identity(godot)
        if identity["source_dirty"]:
            raise ValueError("Focused qualification requires clean committed source")
        ledger["provenance"] = identity
        run_goblin.write_json(out / "linux-qualification.json", ledger)
        contracts_env = dict(os.environ, GOBLIN_PARITY_GODOT=str(godot))
        process = run_goblin.execute([sys.executable, "-m", "unittest", "discover", "-s", "tools/gip014", "-p", "test_*.py"],
                                     contracts_env, out / "python-contracts.log", 180)
        run_goblin.write_json(out / "python-contracts.json", process)
        okay = save("python-contracts", 0 if process["status"] == "pass" else 2)
        if okay:
            for case in ("unit", "discovery", "adapter", "expanded", "controller", "laboratory", "gameplay", "metamorphic", "baseline"):
                code = run_goblin.main(["--godot", str(godot), "--out", str(out / "source-tests" / case), "--case", case,
                                        "--timeout-seconds", "300"])
                okay = save(case, code) and okay
        if okay:
            exported = qualify_reproduction.qualify(out / "source-tests" / "laboratory", out / "regression-case")
            okay = save("native-regression-export", 0 if exported["status"] == "pass" else 2) and okay
        if okay:
            # One actual graphical Godot laboratory gate, with software X11
            # presentation honestly labeled. No external desktop input occurs.
            command = ["xvfb-run", "-a", sys.executable, "tools/gip014/run_goblin.py", "--godot", str(godot),
                       "--out", str(out / "source-tests" / "graphical"), "--case", "graphical", "--timeout-seconds", "300"]
            process = run_goblin.execute(command, dict(os.environ), out / "graphical-driver.log", 600)
            run_goblin.write_json(out / "graphical-driver.json", process)
            okay = save("graphical", 0 if process["status"] == "pass" else 2) and okay
        if okay:
            code = campaign_queue.main(["--godot", str(godot), "--out", str(out / "campaign"), "--plan", args.plan,
                                         "--wall-seconds", "7200", "--max-output-mib", "8192"])
            okay = save("campaign-" + args.plan, code) and okay
        ledger["status"] = "pass" if okay else "failed"
        run_goblin.write_json(out / "linux-qualification.json", ledger)
        print("GOBLIN_LINUX_QUALIFICATION " + json.dumps({"status": ledger["status"], "source_commit": identity["source_commit"]}), flush=True)
        return 0 if okay else 2
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        ledger.update(status="infrastructure_failure", error=str(error))
        run_goblin.write_json(out / "linux-qualification.json", ledger)
        print(json.dumps(ledger), flush=True)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
