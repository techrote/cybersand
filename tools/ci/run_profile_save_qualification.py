#!/usr/bin/env python3
"""Exercise four public profile writers with isolated data and real OS failures.

This proves format reload, truthful acknowledgement and prior-file preservation
at caller boundaries. The unchanged shared transaction's injected I/O matrix is
qualified separately. No browser, graphical or power-loss claim is made here.
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
KINDS = ("worldgen", "material-lab", "transport", "water")


class Runner:
    def __init__(self, args):
        self.engine = args.godot.resolve()
        self.project = args.project.resolve()
        self.evidence = args.evidence.resolve()
        # Never mix a fresh receipt with earlier output or someone's profile.
        self.evidence.mkdir(parents=True, exist_ok=False)
        self.output = self.evidence / "outputs"
        self.output.mkdir()
        profile = Path(tempfile.mkdtemp(prefix="profile-", dir=self.evidence))
        self.env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile))
        self.command = [str(self.engine), "--headless", "--audio-driver", "Dummy",
                        "--path", str(self.project), "--script", "res://tests/profile_save_fault_child.gd"]
        self.sequence = 0
        self.rows = []

    def run(self, kind, value, *, invalid=False, preexec=None):
        self.sequence += 1
        env = self.env | {"CYBERSAND_PROFILE_KIND":kind, "CYBERSAND_PROFILE_VALUE":str(value),
                          "CYBERSAND_PROFILE_INVALID":"1" if invalid else "0",
                          "CYBERSAND_PROFILE_PATH":str(self.output / (kind + ".json"))}
        process = subprocess.run(self.command, env=env, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace", timeout=90, preexec_fn=preexec)
        output = process.stdout + process.stderr
        label = f"{self.sequence:02}-{kind}-{value}{'-invalid' if invalid else ''}.log"
        log = self.evidence / label
        log.write_text(output, encoding="utf-8")
        require(not ENGINE_ERRORS.search(output), "Profile caller had an engine/script error; inspect " + label)
        marker = "PROFILE_SAVE_RESULT "
        records = [json.loads(line[len(marker):]) for line in output.splitlines() if line.startswith(marker)]
        require(process.returncode == 0 and len(records) == 1, "Profile caller did not complete naturally: " + label)
        record = records[0]
        require(record["kind"] == kind and record["requested_value"] == value, "Wrong profile test response")
        path = Path(record["path"])
        require(record["sha256"] == sha(path) and record["bytes"] == path.stat().st_size, "Child/OS bytes disagree")
        require(record["format_loadable"], "Committed profile no longer reloads in its actual format reader")
        detail = record["details"]
        if kind == "worldgen":
            require(detail["accepted_recipe_unchanged"], "Save changed the accepted generation recipe")
            require(detail["outer_status"] == record["status"], "Generation outer/dialog result differs")
            require(bool(detail["last_error"]) != record["acknowledged"], "Generation save error was not updated truthfully")
        elif kind == "material-lab":
            require(detail["experiment_active"] != invalid, "Saving changed native experiment admission")
            require(detail["experiment_tick"] == (-1 if invalid else 0), "Saving advanced the experiment")
        elif kind == "transport":
            require(detail["applications"] == 0, "Save applied a profile to the running owner")
            if not record["acknowledged"]:
                require(detail["draft_unchanged"] and detail["editor_unchanged"], "Refusal altered the Transport draft/editor")
            else:
                require(detail["draft_value"] == value, "Successful save did not retain the saved draft")
        else:
            require(detail["visible_status"] == record["status"] and detail["status_label_visible"],
                    "Tower button did not expose its save result")
            require(detail["unrelated_error"] == "Unrelated retained diagnostic", "Save changed progression/diagnostic state")
            require(detail["resolved_seed"] == value, "Save altered the resolved Water policy")
        record.update(exit_code=process.returncode, natural_completion=True, engine_error_detected=False,
                      log=label, log_sha256=sha(log))
        return record

    @staticmethod
    def success(record, value):
        require(record["acknowledged"] and record["loaded_value"] == value,
                "Successful replacement failed to acknowledge or load the requested value")

    def preserve(self, kind, before, refusal, fault):
        require(not refusal["acknowledged"], f"{kind}/{fault}: failure was acknowledged as success")
        if fault != "invalid-input":
            require("did not replace the previous file" in refusal["status"], "Storage refusal omitted preservation outcome")
        require(refusal["sha256"] == before["sha256"] and refusal["bytes"] == before["bytes"],
                f"{kind}/{fault}: previous file changed")
        require(refusal["loaded_value"] == 7, "Previous file lost its saved value")
        retry = self.run(kind, 8)
        self.success(retry, 8)
        self.rows.append({"kind":kind, "fault":fault,
                          "evidence_class":"public-admission-refusal" if fault == "invalid-input" else "real-os-failure",
                          "before":before,"refusal":refusal,"retry":retry})

    def qualify(self):
        for kind in KINDS:
            old = self.run(kind, 7)
            self.success(old, 7)
            target = Path(old["path"])
            stale = target.with_name(target.name + ".tmp")
            stale.write_bytes(b"Retained unrelated predecessor staging file\n")
            stale_digest = sha(stale)
            new = self.run(kind, 8)
            self.success(new, 8)
            require(new["sha256"] != old["sha256"], "Replacement left old bytes")
            self.rows.append({"kind":kind,"fault":"none","evidence_class":"real-public-caller",
                              "before":old,"replacement":new,"stale_tmp_sha256":stale_digest})
            old = self.run(kind, 7)
            self.success(old, 7)
            self.preserve(kind, old, self.run(kind, 8, invalid=True), "invalid-input")
            old = self.run(kind, 7)
            self.success(old, 7)
            if sys.platform == "win32":
                with windows_lock(target) as lock:
                    refusal = self.run(kind, 8)
                self.preserve(kind, old, refusal, "locked-target")
                self.rows[-1]["lock"] = lock
            else:
                import resource
                limit_bytes = max(128, (old["bytes"] // 4096) * 4096 + 128)
                require(limit_bytes < old["bytes"], "Fixture does not span the selected buffered-write failure")

                def limited():
                    resource.setrlimit(resource.RLIMIT_FSIZE, (limit_bytes, limit_bytes))
                    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
                    signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

                self.preserve(kind, old, self.run(kind, 8, preexec=limited),
                              "RLIMIT_FSIZE-buffered-tail-SIGXFSZ-ignored")
                self.rows[-1]["limit_bytes"] = limit_bytes
                old = self.run(kind, 7)
                mode = target.parent.stat().st_mode
                try:
                    target.parent.chmod(0o555)
                    refusal = self.run(kind, 8)
                finally:
                    target.parent.chmod(mode)
                self.preserve(kind, old, refusal, "directory-permission-denied")
            require(sha(stale) == stale_digest, "Writer touched unrelated stale staging")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    runner = Runner(args)
    root = runner.project.parent
    inputs = ["godot/scripts/worldgen_workbench.gd", "godot/scripts/material_lab_panel.gd",
              "godot/scripts/transport_profile_panel.gd", "godot/scripts/main.gd", "godot/scripts/tower_panel.gd",
              "godot/scripts/workbench_file_transaction.gd", "godot/native_extension/material_baseline_file.cpp",
              "godot/tests/profile_save_fault_child.gd", "tools/ci/run_profile_save_qualification.py",
              "tools/ci/run_workbench_save_qualification.py", "godot/scripts/material_lab_experiment.gd",
              "godot/scripts/transport_profiles.gd", "godot/scripts/water_experiment_profiles.gd",
              "examples/worldgen/hilbert-seams.json"]
    version = subprocess.check_output([str(runner.engine), "--version"], text=True, timeout=30).strip()
    require(version == "4.7.stable.official.5b4e0cb0f", "Pinned Godot 4.7 required")
    report = {"schema":"profile-save-qualification-v1", "authority":"historical-non-authoritative",
              "source_head":subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
              "platform":sys.platform, "engine_version":version, "engine_sha256":sha(runner.engine),
              "input_sha256":{path:sha(root / path) for path in inputs}, "status":"running", "completed":False,
              "cases":runner.rows,
              "limits":["Headless public callers and actual format readers, not rendered or browser acceptance",
                        "No power-loss, hostile concurrent writer or whole-project transaction guarantee",
                        "Shared deterministic I/O-boundary tests are qualified separately"]}
    try:
        runner.qualify()
        report.update(status="passed", completed=True)
        print(f"Profile save qualification: PASS ({len(runner.rows)} cases, {sys.platform})")
        return 0
    except Exception as error:
        report.update(status="failed", error=str(error))
        print(f"Profile save qualification: FAIL: {error}", file=sys.stderr)
        return 1
    finally:
        (runner.evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
