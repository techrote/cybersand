#!/usr/bin/env python3
"""Qualify controller/CLI capture replacement using disposable real OS faults.

The shared transaction's deterministic boundary suite is separately mandatory.
This runner proves the two public capture callers propagate its actual outcome.
It does not constitute a graphical, browser, physics or power-loss qualification.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

from run_workbench_save_qualification import ERRORS, require, sha, windows_lock


class Runner:
    def __init__(self, args):
        self.engine = args.godot.resolve()
        self.project = args.project.resolve()
        self.evidence = args.evidence.resolve()
        self.evidence.mkdir(parents=True, exist_ok=True)
        self.output = self.evidence / "outputs"
        self.output.mkdir()
        profile = Path(tempfile.mkdtemp(prefix="profile-", dir=self.evidence))
        self.env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile))
        self.base = [str(self.engine), "--headless", "--audio-driver", "Dummy",
                     "--path", str(self.project), "--script"]
        self.sequence = 0
        self.rows = []

    def run(self, kind, value, *, preexec=None, relative_output=False):
        self.sequence += 1
        if kind == "controller":
            command = self.base + ["res://tests/microscenario_capture_fault_child.gd"]
            env = self.env | {"CYBERSAND_CAPTURE_VALUE":value,
                              "CYBERSAND_CAPTURE_INITIAL_ERROR":"MicroScenario capture: earlier failure"}
        else:
            path = self.output / "cli.json"
            destination = os.path.relpath(path, self.project) if relative_output else str(path)
            command = self.base + ["res://tests/run_microscenario.gd", "--",
                                   "--scenario=fixtures/unequal-head", "--ticks=1",
                                   "--seed=" + ("11" if value == "old" else "12"),
                                   "--output=" + destination]
            env = self.env
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=90, preexec_fn=preexec)
        text = result.stdout + result.stderr
        label = f"{self.sequence}-{kind}-{value}.log"
        (self.evidence / label).write_text(text, encoding="utf-8")
        require(not ERRORS.search(text), "Capture caller had a script error; inspect " + label)
        if kind == "controller":
            marker = "MICROSCENARIO_CAPTURE_RESULT "
            rows = [json.loads(line[len(marker):]) for line in text.splitlines() if line.startswith(marker)]
            require(result.returncode == 0 and len(rows) == 1, "Controller test did not complete naturally")
            path = Path(rows[0]["path"])
            error = rows[0]["error"]
            require(rows[0]["acknowledgements"] == (0 if error else 1), "Controller acknowledged an uncommitted capture")
            require(rows[0]["acknowledged_value"] == ("previously acknowledged" if error else value),
                    "Controller changed the retained result on refusal or acknowledged wrong bytes")
        else:
            require(result.returncode in (0, 2), "CLI failed outside its capture result contract")
            error = "\n".join(line for line in text.splitlines() if line.startswith("MICROSCENARIO_ERROR: "))
            require((result.returncode == 2) == bool(error), "CLI error/exit status disagreement")
            require(("MICROSCENARIO_RESULT " in text) == (result.returncode == 0), "CLI success acknowledgement disagreement")
        payload = json.loads(path.read_text(encoding="utf-8"))
        actual = payload.get("value") if kind == "controller" else payload.get("seed")
        return {"path":str(path), "error":error, "exit_code":result.returncode,
                "sha256":sha(path), "bytes":path.stat().st_size, "value":actual,
                "json_valid":True, "log":label, "log_sha256":sha(self.evidence / label),
                **({"acknowledgements":rows[0]["acknowledgements"], "acknowledged_value":rows[0]["acknowledged_value"]}
                   if kind == "controller" else {"output_argument":destination})}

    @staticmethod
    def value(kind, record, expected):
        wanted = expected if kind == "controller" else (11 if expected == "old" else 12)
        require(record["value"] == wanted, f"{kind}: wrong committed value {record['value']!r}")

    def preserve(self, kind, before, refused, fault):
        require(bool(refused["error"]), f"{kind}/{fault}: failure reported success")
        require("did not replace the previous file" in refused["error"], "Refusal omitted the verified preservation contract")
        require(refused["sha256"] == before["sha256"] and refused["bytes"] == before["bytes"],
                f"{kind}/{fault}: previous capture changed")
        self.value(kind, refused, "old")
        recovered = self.run(kind, "new")
        require(not recovered["error"], "Normal retry failed")
        self.value(kind, recovered, "new")
        self.rows.append({"kind":kind, "fault":fault, "evidence_class":"real-os-failure",
                          "before":before, "refusal":refused, "retry":recovered})

    def qualify(self):
        for kind in ("controller", "cli"):
            old = self.run(kind, "old")
            require(not old["error"], "Initial capture failed")
            self.value(kind, old, "old")
            target = Path(old["path"])
            stale = target.with_name(target.name + ".tmp")
            stale.write_bytes(b"unrelated retained pre-transaction staging\n")
            stale_sha = sha(stale)
            # Existing documented relative outputs resolve from --path's
            # project directory. Exercise that compatibility, including spaces.
            new = self.run(kind, "new", relative_output=kind == "cli")
            require(not new["error"] and new["sha256"] != old["sha256"], "Normal replacement failed")
            self.value(kind, new, "new")
            require(sha(stale) == stale_sha, "Writer altered an unrelated stale temporary file")
            self.rows.append({"kind":kind, "evidence_class":"real-public-caller",
                              "before":old, "replacement":new, "stale_tmp_sha256":stale_sha})
            old = self.run(kind, "old")
            if sys.platform == "win32":
                with windows_lock(target) as lock:
                    refused = self.run(kind, "new")
                self.preserve(kind, old, refused, "locked-target")
                self.rows[-1]["lock"] = lock
            else:
                import resource
                # Put the failure in the final libc buffer. The old CLI writer
                # caught an early 128-byte failure but lost the old result on a
                # later buffered flush failure; keep both evidence classes clear.
                limit_bytes = max(128, (old["bytes"] // 4096) * 4096 + 128)
                require(limit_bytes < old["bytes"], "Fixture does not span its selected buffered-write fault")

                def limited():
                    resource.setrlimit(resource.RLIMIT_FSIZE, (limit_bytes, limit_bytes))
                    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
                    signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

                refused = self.run(kind, "new", preexec=limited)
                self.preserve(kind, old, refused, "RLIMIT_FSIZE-buffered-tail-SIGXFSZ-ignored")
                self.rows[-1]["limit_bytes"] = limit_bytes
                old = self.run(kind, "old")
                mode = target.parent.stat().st_mode
                try:
                    target.parent.chmod(0o555)
                    refused = self.run(kind, "new")
                finally:
                    target.parent.chmod(mode)
                self.preserve(kind, old, refused, "directory-permission-denied")
            require(sha(stale) == stale_sha, "Failure/retry altered unrelated staging")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    runner = Runner(args)
    root = runner.project.parent
    inputs = ["godot/scripts/main.gd", "godot/tests/run_microscenario.gd",
              "godot/scripts/workbench_file_transaction.gd", "godot/native_extension/material_baseline_file.cpp",
              "godot/tests/microscenario_capture_fault_child.gd", "tools/ci/run_microscenario_capture_qualification.py",
              "tools/ci/run_workbench_save_qualification.py"]
    version = subprocess.check_output([str(runner.engine), "--version"], text=True, timeout=30).strip()
    require(version == "4.7.stable.official.5b4e0cb0f", "Pinned Godot 4.7 required")
    report = {"schema":"microscenario-capture-qualification-v1", "authority":"historical-non-authoritative",
              "source_head":subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
              "platform":sys.platform, "engine_version":version, "engine_sha256":sha(runner.engine),
              "input_sha256":{path:sha(root / path) for path in inputs},
              "status":"running", "completed":False, "cases":runner.rows,
              "limits":["Headless controller method and native CLI, not fresh graphical/browser observation",
                        "No physics acceptance or power-loss/storage durability claim",
                        "Same helper fault-boundary suite is qualified separately"]}
    try:
        runner.qualify()
        report.update(status="passed", completed=True)
        print(f"MicroScenario capture qualification: PASS ({len(runner.rows)} cases, {sys.platform})")
        return 0
    except Exception as error:
        report.update(status="failed", error=str(error))
        print(f"MicroScenario capture qualification: FAIL: {error}", file=sys.stderr)
        return 1
    finally:
        (runner.evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
