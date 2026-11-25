#!/usr/bin/env python3
"""Qualify the public Tower observation export using isolated data and OS faults.

Linux exercises real buffered-tail and directory permission failures. Windows
holds the old target open without delete sharing. Normal and refused writes use
both ordinary Tower context and the unchanged Water/blind engineering metadata.
This is a headless caller/format test, not a rendered or physical acceptance run.
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
KINDS = ("ordinary", "water-blind")
ORDINARY_KEYS = ["context", "floor", "platform", "recipe_version", "seed", "utc"]
WATER_KEYS = sorted(ORDINARY_KEYS + ["runtime_identity", "water_feel_version", "effective_policy",
    "effective_policy_hash", "policy_provenance", "scenario_id", "recipe_hash", "presentation_mode",
    "worker_count", "backend", "action_history", "observations", "water_accounting", "blind_label", "blind"])


class Runner:
    def __init__(self, args):
        self.engine = args.godot.resolve()
        self.project = args.project.resolve()
        self.evidence = args.evidence.resolve()
        self.evidence.mkdir(parents=True, exist_ok=False)
        profile = Path(tempfile.mkdtemp(prefix="profile-", dir=self.evidence))
        self.env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile))
        self.command = [str(self.engine), "--headless", "--audio-driver", "Dummy", "--path",
                        str(self.project), "--script", "res://tests/tower_observation_fault_child.gd"]
        self.sequence = 0
        self.rows = []

    def run(self, kind, value, *, button=True, preexec=None):
        self.sequence += 1
        env = self.env | {"CYBERSAND_OBSERVATION_KIND":kind, "CYBERSAND_OBSERVATION_VALUE":str(value),
                          "CYBERSAND_OBSERVATION_BUTTON":"1" if button else "0"}
        process = subprocess.run(self.command, env=env, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace", timeout=90, preexec_fn=preexec)
        output = process.stdout + process.stderr
        label = f"{self.sequence:02}-{kind}-{value}.log"
        log = self.evidence / label
        log.write_text(output, encoding="utf-8")
        require(not ENGINE_ERRORS.search(output), "Tower export had an engine/script error; inspect " + label)
        marker = "TOWER_OBSERVATION_RESULT "
        records = [json.loads(line[len(marker):]) for line in output.splitlines() if line.startswith(marker)]
        require(process.returncode == 0 and len(records) == 1, "Tower export did not complete naturally: " + label)
        record = records[0]
        require(record["kind"] == kind and record["requested_value"] == value, "Wrong Tower fixture response")
        path = Path(record["path"])
        require(record["sha256"] == sha(path) and record["bytes"] == path.stat().st_size, "Child/OS bytes disagree")
        require(record["json_loadable"], "Committed observation no longer parses as JSON")
        require(record["report_keys"] == (WATER_KEYS if kind == "water-blind" else ORDINARY_KEYS),
                "Observation report format changed")
        require(record["blind_mapping_size"] == (2 if kind == "water-blind" else 0),
                "The existing engineering blind-mapping boundary changed")
        if kind == "water-blind":
            require(record["reported_policy_seed"] == record["loaded_value"], "Water policy/report identity differs")
        require(record["context_unchanged"] and record["unrelated_error"] == "Unrelated retained diagnostic"
                and record["unrelated_policy_status"] == "Unrelated policy save result",
                "Export modified live context or another result field")
        if button:
            require(record["visible_status"] == record["status"] and record["status_label_visible"],
                    "Tower export button did not expose its result")
        else:
            require(record["return_value"] is record["acknowledged"], "Public method returned a false acknowledgement")
        if record["clipboard_available"]:
            require(record["clipboard_outcome_matches"], "Clipboard changed on refusal or differs from the committed export")
        else:
            require("Copied to clipboard" not in record["status"], "Unavailable clipboard was claimed copied")
        record.update(exit_code=process.returncode, natural_completion=True, engine_error_detected=False,
                      log=label, log_sha256=sha(log))
        return record

    @staticmethod
    def success(record, value):
        require(record["acknowledged"] and record["loaded_value"] == value,
                "Successful export did not acknowledge/load the requested observation")

    def preserve(self, kind, before, refused, fault):
        require(not refused["acknowledged"], "Refused observation was acknowledged as exported")
        require("did not replace the previous file" in refused["status"], "Refusal omitted the file outcome")
        require(refused["sha256"] == before["sha256"] and refused["bytes"] == before["bytes"]
                and refused["loaded_value"] == 7, "Refused export changed the previous observation")
        retry = self.run(kind, 8)
        self.success(retry, 8)
        self.rows.append({"kind":kind,"fault":fault,"evidence_class":"real-os-failure",
                          "before":before,"refusal":refused,"retry":retry})

    def qualify(self):
        for kind in KINDS:
            before = self.run(kind, 7, button=False)
            self.success(before, 7)
            target = Path(before["path"])
            stale = target.with_name(target.name + ".tmp")
            stale.write_bytes(b"Retained unrelated Tower staging fixture\n")
            stale_digest = sha(stale)
            after = self.run(kind, 8)
            self.success(after, 8)
            require(after["sha256"] != before["sha256"], "Replacement retained old observation bytes")
            self.rows.append({"kind":kind,"fault":"none","evidence_class":"real-public-caller",
                              "before":before,"replacement":after,"stale_tmp_sha256":stale_digest})
            before = self.run(kind, 7)
            if sys.platform == "win32":
                with windows_lock(target) as lock:
                    refused = self.run(kind, 8, button=kind == "water-blind")
                self.preserve(kind, before, refused, "locked-target")
                self.rows[-1]["lock"] = lock
            else:
                import resource
                limit = min(before["bytes"] - 1, max(128, (before["bytes"] // 4096) * 4096 + 128))
                require(0 < limit < before["bytes"], "Fixture does not span the selected failure")

                def limited():
                    resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))
                    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
                    signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

                refused = self.run(kind, 8, button=kind == "water-blind", preexec=limited)
                self.preserve(kind, before, refused, "RLIMIT_FSIZE-buffered-tail-SIGXFSZ-ignored")
                self.rows[-1]["limit_bytes"] = limit
                before = self.run(kind, 7)
                mode = target.parent.stat().st_mode
                try:
                    target.parent.chmod(0o555)
                    refused = self.run(kind, 8)
                finally:
                    target.parent.chmod(mode)
                self.preserve(kind, before, refused, "directory-permission-denied")
            require(sha(stale) == stale_digest, "Export touched unrelated stale staging")
            require(sorted(path.name for path in target.parent.glob(target.name + ".*.tmp")) == [],
                    "Export left an unexpected staging file after successful cleanup")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    runner = Runner(args)
    root = runner.project.parent
    inputs = ["godot/scripts/main.gd", "godot/scripts/tower_panel.gd",
              "godot/scripts/workbench_file_transaction.gd", "godot/native_extension/material_baseline_file.cpp",
              "godot/scripts/experiment_tower.gd", "godot/scripts/water_experiment_profiles.gd",
              "godot/scripts/water_experiment_blind.gd", "godot/scripts/water_feel_scenarios.gd",
              "godot/tests/tower_observation_fault_child.gd", "tools/ci/run_tower_observation_qualification.py",
              "tools/ci/run_workbench_save_qualification.py"]
    version = subprocess.check_output([str(runner.engine), "--version"], text=True, timeout=30).strip()
    require(version == "4.7.stable.official.5b4e0cb0f", "Pinned Godot 4.7 required")
    before = {path:sha(root / path) for path in inputs}
    report = {"schema":"tower-observation-qualification-v1","authority":"historical-non-authoritative",
              "source_head":subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
              "platform":sys.platform,"engine_version":version,"engine_sha256":sha(runner.engine),
              "input_sha256":before,"status":"running","completed":False,"cases":runner.rows,
              "limits":["Headless public controller/button calls, not rendered or physical acceptance",
                        "Clipboard checks run only when the host exposes that capability",
                        "Blind hidden_mapping remains engineering metadata, not blind-study capture readiness",
                        "No fsync/power-loss, hostile concurrent writer or whole-evidence transaction guarantee"]}
    try:
        runner.qualify()
        require(before == {path:sha(root / path) for path in inputs}, "Qualification inputs changed during execution")
        report.update(status="passed", completed=True, inputs_unchanged=True)
        print(f"Tower observation qualification: PASS ({len(runner.rows)} cases, {sys.platform})")
        return 0
    except Exception as error:
        report.update(status="failed", error=str(error))
        print(f"Tower observation qualification: FAIL: {error}", file=sys.stderr)
        return 1
    finally:
        (runner.evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
