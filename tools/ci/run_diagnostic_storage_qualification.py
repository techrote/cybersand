#!/usr/bin/env python3
"""Verify diagnostic CLI and guarded audit writers refuse incomplete replacement.

The three public CLIs execute their actual one-tick native/Rapier entry points.
The optional Goblin foundation's fixed writer has a separate guarded private
probe. This qualifies storage only, not a new physics, actor or Goblin campaign.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile

from run_workbench_save_qualification import require, sha, windows_lock

ENGINE_ERRORS = re.compile(r"SCRIPT ERROR|Parse Error|Failed to load script|Invalid call|Invalid access|^ERROR:", re.MULTILINE)
KINDS = ("physics", "thunderbowl", "physical-thunderbowl", "goblin")


class Runner:
    def __init__(self, args):
        self.engine = args.godot.resolve()
        self.project = args.project.resolve()
        self.evidence = args.evidence.resolve()
        self.evidence.mkdir(parents=True, exist_ok=False)
        self.output = self.evidence / "outputs with spaces"
        self.output.mkdir()
        profile = Path(tempfile.mkdtemp(prefix="profile-", dir=self.evidence))
        # The real Goblin adapter verifies both this disposable marker and that
        # Godot's actual user-data path is beneath the selected profile root.
        # No launch/provenance campaign is asserted by a fixed-byte writer probe.
        (profile / "goblin-profile.json").write_text(
            json.dumps({"schema":"cybersand-goblin-profile-v1"}), encoding="utf-8")
        self.env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile),
                        CYBERSAND_GOBLIN_PROFILE=str(profile))
        self.base = [str(self.engine), "--headless", "--audio-driver", "Dummy",
                     "--path", str(self.project), "--script"]
        self.sequence = 0
        self.rows = []

    def run(self, kind, value, *, preexec=None, relative=False):
        self.sequence += 1
        target = self.output / (kind + ".json")
        destination = os.path.relpath(target, self.project) if relative else str(target)
        if kind == "physics":
            batch = self.evidence / "physics-case.json"
            batch.write_text(json.dumps([{"id":"physics","mode":"barrel","material":0,
                                         "layout":"hard","ticks":1,"seed":value}]), encoding="utf-8")
            output_dir = os.path.relpath(self.output, self.project) if relative else str(self.output)
            command = self.base + ["res://tests/test_physics_characterisation.gd", "--", str(batch), output_dir]
        elif kind == "thunderbowl":
            command = self.base + ["res://examples/thunderbowl/run_thunderbowl.gd", "--", "--ticks=1",
                                   "--seed=" + str(value), "--output=" + destination]
        elif kind == "physical-thunderbowl":
            command = self.base + ["res://examples/thunderbowl/run_physical_thunderbowl.gd", "--", "--actors=1",
                                   "--ticks=1", "--seed=" + str(value), "--output=" + destination]
        else:
            command = self.base + ["res://tests/goblin_storage_fault_child.gd"]
        process = subprocess.run(command, env=self.env | {"CYBERSAND_DIAGNOSTIC_VALUE":str(value)}, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace", timeout=90, preexec_fn=preexec)
        output = process.stdout + process.stderr
        label = f"{self.sequence:02}-{kind}-{value}.log"
        log = self.evidence / label
        log.write_text(output, encoding="utf-8")
        require(not ENGINE_ERRORS.search(output), "Diagnostic had an engine/script error: " + label)
        if kind == "physics":
            marker = "PHYSICS_RESULT "
            records = [json.loads(line[len(marker):]) for line in output.splitlines() if line.startswith(marker)]
            require(len(records) == 1, "Missing/unexpected physics completion record")
            acknowledged = records[0].get("ok") is True
            error = str(records[0].get("error", ""))
            require(process.returncode == (0 if acknowledged else 1), "Physics result/exit disagreement")
        elif kind == "thunderbowl":
            acknowledged = "THUNDERBOWL_RESULT " in output
            error = "\n".join(line for line in output.splitlines() if line.startswith("THUNDERBOWL_ERROR: "))
            require(process.returncode == (0 if acknowledged else 2), "Thunderbowl result/exit disagreement")
        elif kind == "physical-thunderbowl":
            records = [json.loads(line) for line in output.splitlines() if line.startswith("{")]
            error = "\n".join(line for line in output.splitlines() if line.startswith("PHYSICAL_THUNDERBOWL_ERROR: "))
            acknowledged = len(records) == 1 and records[0].get("failed") is False
            require(process.returncode == (0 if acknowledged else 2), "Physical result/exit disagreement")
            require(len(records) == (1 if acknowledged else 0), "Refused output still printed a success report")
        else:
            marker = "GOBLIN_STORAGE_RESULT "
            records = [json.loads(line[len(marker):]) for line in output.splitlines() if line.startswith(marker)]
            require(len(records) == 1, "Missing guarded audit-writer completion")
            probe = records[0]
            require(all(probe.get(key) is True for key in
                        ("profile_verified", "wrong_path_refused", "wrong_profile_refused", "guards_preserved")),
                    "Goblin fixed-path/profile guard was bypassed")
            target = Path(probe["path"])
            acknowledged = probe["acknowledged"] is True
            error = str(probe.get("error", ""))
            require(process.returncode == (0 if acknowledged else 2), "Audit-writer acknowledgement/exit disagreement")
        require(bool(error) != acknowledged, "Diagnostic failure/success messages disagree")
        data = json.loads(target.read_text(encoding="utf-8"))
        if kind == "physics":
            loaded_value = data["spec"]["seed"]
            require(data["ok"] is True and data["completed_ticks"] == 1 and "frames" in data,
                    "Physics file lost its complete detailed result")
        elif kind == "thunderbowl":
            loaded_value = data["runner"]["config"]["seed"]
            require(data["failed"] is False and data["tick"] == 1, "Thunderbowl result invalid")
        elif kind == "physical-thunderbowl":
            loaded_value = data["config"]["seed"]
            require(data["failed"] is False and data["tick"] == 1, "Physical result invalid")
        else:
            loaded_value = data["seed"]
            require(data["fixture"] == "ULTIMA fixed audit writer, not a campaign transcript"
                    and data["payload"] == "Complete observed bytes. " * 64, "Audit fixture lost complete bytes")
        return {"path":str(target), "command":command, "exit_code":process.returncode,
                "natural_completion":True, "engine_error_detected":False,
                "acknowledged":acknowledged, "error":error, "value":loaded_value,
                "json_valid":True, "bytes":target.stat().st_size, "sha256":sha(target),
                "log":label, "log_sha256":sha(log),
                **({"guards":probe} if kind == "goblin" else {})}

    @staticmethod
    def success(record, value):
        require(record["acknowledged"] and record["value"] == value,
                "Diagnostic did not acknowledge/load the requested complete result")

    def preserve(self, kind, before, refusal, fault):
        require(not refusal["acknowledged"] and bool(refusal["error"]), "Failed output was acknowledged")
        require("not replaced" in refusal["error"] or "did not replace the previous file" in refusal["error"],
                "Refusal omitted the output preservation contract")
        require(refusal["sha256"] == before["sha256"] and refusal["bytes"] == before["bytes"]
                and refusal["value"] == 7, "Failed result write changed the earlier valid report")
        retry = self.run(kind, 8)
        self.success(retry, 8)
        self.rows.append({"kind":kind, "fault":fault, "evidence_class":"real-os-failure",
                          "before":before, "refusal":refusal, "retry":retry})

    def qualify(self):
        for kind in KINDS:
            old = self.run(kind, 7)
            self.success(old, 7)
            target = Path(old["path"])
            stale = target.with_name(target.name + (".partial" if kind == "goblin" else ".tmp"))
            stale.write_bytes(b"Unrelated retained diagnostic staging\n")
            stale_digest = sha(stale)
            new = self.run(kind, 8, relative=True)
            self.success(new, 8)
            self.rows.append({"kind":kind,"fault":"none",
                              "evidence_class":"guarded-audit-writer" if kind == "goblin" else "real-public-cli",
                              "before":old,"replacement":new,"relative_output":kind != "goblin",
                              "stale_tmp_sha256":stale_digest})
            old = self.run(kind, 7)
            self.success(old, 7)
            if sys.platform == "win32":
                with windows_lock(target) as lock:
                    refusal = self.run(kind, 8)
                self.preserve(kind, old, refusal, "locked-target")
                self.rows[-1]["lock"] = lock
            else:
                import resource
                # Keep the actual error inside the final buffered write, even
                # if variable diagnostic timing fields change the last digits.
                size = old["bytes"]
                limit_bytes = ((size - 1) // 4096) * 4096 + min(128, (size - 1) % 4096)
                require(0 < limit_bytes < size, "Diagnostic fixture is too small")

                def limited():
                    resource.setrlimit(resource.RLIMIT_FSIZE, (limit_bytes, limit_bytes))
                    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
                    signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

                self.preserve(kind, old, self.run(kind, 8, preexec=limited),
                              "RLIMIT_FSIZE-buffered-tail-SIGXFSZ-ignored")
                self.rows[-1]["limit_bytes"] = limit_bytes
                old = self.run(kind, 7)
                self.success(old, 7)
                mode = target.parent.stat().st_mode
                try:
                    target.parent.chmod(0o555)
                    refusal = self.run(kind, 8)
                finally:
                    target.parent.chmod(mode)
                self.preserve(kind, old, refusal, "directory-permission-denied")
            require(sha(stale) == stale_digest, "Writer altered unrelated old staging")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    runner = Runner(args)
    root = runner.project.parent
    inputs = ["godot/scripts/physics_characterisation.gd", "godot/tests/test_physics_characterisation.gd",
              "godot/examples/thunderbowl/thunderbowl_driver.gd", "godot/examples/thunderbowl/run_thunderbowl.gd",
              "godot/examples/thunderbowl/run_physical_thunderbowl.gd", "godot/scripts/workbench_file_transaction.gd",
              "godot/native_extension/material_baseline_file.cpp", "tools/ci/run_diagnostic_storage_qualification.py",
              "tools/ci/run_workbench_save_qualification.py", "godot/examples/thunderbowl/matches/mixed.json",
              "godot/goblin/goblin_controller.gd", "godot/goblin/goblin_adapter.gd",
              "godot/tests/goblin_storage_fault_child.gd"]
    version = subprocess.check_output([str(runner.engine), "--version"], text=True, timeout=30).strip()
    require(version == "4.7.stable.official.5b4e0cb0f", "Pinned Godot 4.7 required")
    report = {"schema":"diagnostic-storage-qualification-v1", "authority":"historical-non-authoritative",
              "source_head":subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
              "platform":sys.platform, "engine_version":version, "engine_sha256":sha(runner.engine),
              "input_sha256":{path:sha(root / path) for path in inputs}, "status":"running", "completed":False,
              "cases":runner.rows,
              "limits":["Three one-tick actual CLIs and one guarded fixed-audit-writer probe; no physics/controller or Goblin campaign acceptance",
                        "No browser/graphical/physical-owner or power-loss qualification",
                        "Shared deterministic I/O-boundary tests are qualified separately"]}
    try:
        runner.qualify()
        report.update(status="passed", completed=True)
        print(f"Diagnostic storage qualification: PASS ({len(runner.rows)} cases, {sys.platform})")
        return 0
    except Exception as error:
        report.update(status="failed", error=str(error))
        print(f"Diagnostic storage qualification: FAIL: {error}", file=sys.stderr)
        return 1
    finally:
        (runner.evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
