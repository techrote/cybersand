#!/usr/bin/env python3
"""Exercise the real guarded Goblin writer under actual storage failures.

Narrow adaptation of ULTIMA diagnostic runner 08058e3fc3f7227052ef4324465a7bd4254f3709.
No other diagnostic consumer is imported or represented as qualified. Reports
retain the actual previous/refused/retry bytes and original child observations.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile

from windows_file_lock import require, windows_lock

ERRORS = re.compile(r"SCRIPT ERROR|Parse Error|Failed to load script|Invalid call|Invalid access|^ERROR:", re.MULTILINE)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Runner:
    def __init__(self, args):
        self.engine = args.godot.resolve()
        self.project = args.project.resolve()
        self.evidence = args.evidence.resolve()
        self.evidence.mkdir(parents=True, exist_ok=False)
        self.profile = Path(tempfile.mkdtemp(prefix="profile-", dir=self.evidence))
        (self.profile / "goblin-profile.json").write_text(
            json.dumps({"schema": "cybersand-goblin-profile-v1"}), encoding="utf-8")
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.profile), APPDATA=str(self.profile),
                        CYBERSAND_GOBLIN_PROFILE=str(self.profile))
        self.rows: list[dict] = []
        self.executions: list[dict] = []

    def run(self, value: int, *, preexec=None) -> dict:
        command = [str(self.engine), "--headless", "--audio-driver", "Dummy",
                   "--path", str(self.project), "--script", "res://tests/goblin_storage_fault_child.gd"]
        process = subprocess.run(command, env=self.env | {"CYBERSAND_DIAGNOSTIC_VALUE": str(value)},
                                 capture_output=True, text=True, encoding="utf-8", errors="replace",
                                 timeout=90, preexec_fn=preexec)
        output = process.stdout + process.stderr
        log = self.evidence / f"{len(self.executions) + 1:02}-seed-{value}.log"
        log.write_text(output, encoding="utf-8")
        require(not ERRORS.search(output), "Engine/script error in " + log.name)
        records = [json.loads(line.removeprefix("GOBLIN_STORAGE_RESULT "))
                   for line in output.splitlines() if line.startswith("GOBLIN_STORAGE_RESULT ")]
        require(len(records) == 1, "Missing unique guarded writer result")
        probe = records[0]
        require(all(probe.get(key) is True for key in
                    ("profile_verified", "wrong_path_refused", "wrong_profile_refused", "guards_preserved")),
                "Actual fixed-path/profile guard failed")
        acknowledged = probe["acknowledged"] is True
        require(process.returncode == (0 if acknowledged else 2), "Acknowledgement/exit disagreement")
        target = Path(probe["path"])
        require(target.is_relative_to(self.profile), "Writer escaped the disposable profile")
        captured = self.evidence / f"{len(self.executions) + 1:02}-observed-output.bin"
        captured.write_bytes(target.read_bytes())
        try:
            data = json.loads(captured.read_text(encoding="utf-8"))
            complete = data.get("fixture") == "ULTIMA fixed audit writer, not a campaign transcript" \
                and data.get("payload") == "Complete observed bytes. " * 64
            observed_value = data.get("seed")
        except (ValueError, UnicodeError):
            complete, observed_value = False, None
        row = {"path": str(target), "command": command, "exit_code": process.returncode,
               "natural_completion": True, "engine_error_detected": False,
               "acknowledged": acknowledged, "error": str(probe.get("error", "")),
               "value": observed_value, "complete_json": complete,
               "bytes": captured.stat().st_size, "sha256": sha(captured),
               "retained_bytes": captured.name, "log": log.name, "log_sha256": sha(log), "guards": probe}
        self.executions.append(row)
        return row

    @staticmethod
    def success(row: dict, value: int) -> None:
        require(row["acknowledged"] and not row["error"] and row["complete_json"]
                and row["value"] == value, "Complete requested output was not truthfully acknowledged")

    def preserve(self, old: dict, refused: dict, fault: str) -> None:
        row = {"fault": fault, "evidence_class": "real-os-failure", "before": old, "refusal": refused}
        self.rows.append(row)
        require(not refused["acknowledged"] and bool(refused["error"]), "Failed output was acknowledged")
        require("not replaced" in refused["error"] or "did not replace the previous file" in refused["error"],
                "Failure did not describe output preservation")
        require(refused["complete_json"] and refused["sha256"] == old["sha256"]
                and refused["bytes"] == old["bytes"] and refused["value"] == 7,
                "Failed replacement changed the earlier complete output")
        row["retry"] = self.run(8)
        self.success(row["retry"], 8)

    def qualify(self) -> None:
        old = self.run(7)
        self.success(old, 7)
        target = Path(old["path"])
        stale = target.with_name(target.name + ".partial")
        stale.write_bytes(b"Unrelated retained diagnostic staging\n")
        stale_sha = sha(stale)
        new = self.run(8)
        self.success(new, 8)
        self.rows.append({"fault": "none", "evidence_class": "guarded-fixed-writer",
                          "before": old, "replacement": new, "stale_partial_sha256": stale_sha})
        old = self.run(7)
        self.success(old, 7)
        if sys.platform == "win32":
            with windows_lock(target) as lock:
                refused = self.run(8)
            self.preserve(old, refused, "locked-target")
            self.rows[-1]["lock"] = lock
        else:
            import resource

            def limited():
                resource.setrlimit(resource.RLIMIT_FSIZE, (128, 128))
                resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
                signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

            self.preserve(old, self.run(8, preexec=limited), "RLIMIT_FSIZE-128-buffered-tail-SIGXFSZ-ignored")
            self.rows[-1]["limit_bytes"] = 128
            old = self.run(7)
            self.success(old, 7)
            mode = target.parent.stat().st_mode
            try:
                target.parent.chmod(0o555)
                refused = self.run(8)
            finally:
                target.parent.chmod(mode)
            self.preserve(old, refused, "directory-permission-denied")
        require(stale.is_file() and sha(stale) == stale_sha, "Writer altered unrelated retained staging")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    runner = Runner(args)
    root = runner.project.parent
    paths = ["godot/goblin/goblin_controller.gd", "godot/goblin/goblin_adapter.gd",
             "godot/goblin/goblin_corpus.gd", "godot/goblin/goblin_transcript.gd",
             "godot/scripts/workbench_file_transaction.gd", "godot/tests/goblin_storage_fault_child.gd",
             "godot/native_extension/material_baseline_file.cpp", "tools/ci/windows_file_lock.py",
             "tools/ci/run_goblin_storage_qualification.py"]
    inputs = {p: sha(root / p) for p in paths if (root / p).is_file()}
    version = subprocess.check_output([str(runner.engine), "--version"], text=True, timeout=30).strip()
    require(version == "4.7.stable.official.5b4e0cb0f", "Pinned Godot version required")
    source = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    report = {"schema": "goblin-storage-qualification-v1", "source_head": source,
              "platform": sys.platform, "engine_version": version, "engine_sha256": sha(runner.engine),
              "input_sha256": inputs, "status": "running", "completed": False,
              "cases": runner.rows, "executions": runner.executions,
              "limits": ["Guarded fixed-output writer only; campaign/replay/resource qualification is separate",
                         "Actual OS fault behavior only on the recorded platform; no power-loss or multi-file atomicity claim"]}
    try:
        runner.qualify()
        require(inputs == {p: sha(root / p) for p in inputs}, "Source changed during storage qualification")
        report.update(status="passed", completed=True)
        print(f"Goblin storage qualification: PASS ({len(runner.rows)} cases, {sys.platform})")
        return 0
    except Exception as error:
        report.update(status="failed", error=str(error))
        print("Goblin storage qualification: FAIL: " + str(error), file=sys.stderr)
        return 1
    finally:
        (runner.evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
