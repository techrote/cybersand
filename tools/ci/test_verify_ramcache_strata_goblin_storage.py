#!/usr/bin/env python3
"""Synthetic reader controls; these tests are not OS storage qualification."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import verify_ramcache_strata_goblin_storage as reader


class OriginalReceiptReview(unittest.TestCase):
    def fixture(self, folder: Path, platform="linux"):
        profile = folder / "profile-original"
        target = profile / "Godot/app_userdata/Sandbox/goblin/transcript.json"
        target.parent.mkdir(parents=True)
        (profile / "goblin-profile.json").write_text(json.dumps({"schema": "cybersand-goblin-profile-v1"}))
        target.with_name(target.name + ".partial").write_bytes(reader.STALE)
        source, version = "1" * 40, "4.7.stable.official.5b4e0cb0f"
        engine = "C:\\engine\\Godot.exe" if platform == "win32" else "/engine/Godot"
        project = "C:\\source\\godot" if platform == "win32" else "/source/godot"
        recorded = ("C:\\evidence\\profile-original\\Godot\\app_userdata\\Sandbox\\goblin\\transcript.json"
                    if platform == "win32" else "/evidence/profile-original/Godot/app_userdata/Sandbox/goblin/transcript.json")
        command = [engine, "--headless", "--audio-driver", "Dummy", "--path", project,
                   "--script", "res://tests/goblin_storage_fault_child.gd"]
        requested = [7, 8, 7, 8, 8] + ([7, 8, 8] if platform == "linux" else [])
        observed = [7, 8, 7, 7, 8] + ([7, 7, 8] if platform == "linux" else [])
        rows = []
        for index, (request, actual) in enumerate(zip(requested, observed)):
            acknowledged = index not in (3, 6)
            guard = {"acknowledged": acknowledged, "error": "" if acknowledged else "Output not replaced",
                     "path": recorded.replace("\\", "/") if platform == "win32" else recorded,
                     "profile_verified": True, "wrong_path_refused": True,
                     "wrong_profile_refused": True, "guards_preserved": True}
            log = folder / f"{index + 1:02}-seed-{request}.log"
            log.write_text(f"Godot Engine v{version} - https://godotengine.org\n" + reader.MARKER + json.dumps(guard) + "\n")
            capture = folder / f"{index + 1:02}-observed-output.bin"
            capture.write_text(json.dumps({"fixture": reader.FIXTURE, "payload": reader.PAYLOAD, "seed": actual}))
            rows.append({"path": recorded, "command": command.copy(), "exit_code": 0 if acknowledged else 2,
                         "natural_completion": True, "engine_error_detected": False, "acknowledged": acknowledged,
                         "error": guard["error"], "value": actual, "complete_json": True,
                         "bytes": capture.stat().st_size, "sha256": reader.sha(capture), "retained_bytes": capture.name,
                         "log": log.name, "log_sha256": reader.sha(log), "guards": guard})
        target.write_bytes((folder / rows[-1]["retained_bytes"]).read_bytes())
        cases = [{"fault": "none", "evidence_class": "guarded-fixed-writer", "before": rows[0], "replacement": rows[1],
                  "stale_partial_sha256": hashlib.sha256(reader.STALE).hexdigest()}]
        faults = (["locked-target"] if platform == "win32" else
                  ["RLIMIT_FSIZE-128-buffered-tail-SIGXFSZ-ignored", "directory-permission-denied"])
        for index, fault in enumerate(faults):
            before, refused, retry = rows[2 + index * 3:5 + index * 3]
            case = {"fault": fault, "evidence_class": "real-os-failure", "before": before, "refusal": refused, "retry": retry}
            if platform == "win32":
                case["lock"] = {"desired_access": 0x80000000, "share_mode": 1, "delete_access_probe_error": 32}
            elif index == 0:
                case["limit_bytes"] = 128
            cases.append(case)
        kwargs = dict(expected_source=source, platform=platform, engine_path=engine, project_path=project,
                      engine_sha256="2" * 64, engine_version=version,
                      expected_inputs={name: "3" * 64 for name in reader.INPUTS})
        report = {"schema": "goblin-storage-qualification-v1", "source_head": source, "platform": platform,
                  "engine_version": version, "engine_sha256": kwargs["engine_sha256"],
                  "input_sha256": kwargs["expected_inputs"].copy(), "status": "passed", "completed": True,
                  "cases": cases, "executions": rows}
        return report, kwargs, target

    def verify(self, folder, report, kwargs):
        (folder / "report.json").write_text(json.dumps(report))
        return reader.verify_storage_evidence(folder, **kwargs)

    def rewrite_guard(self, folder, row):
        path = folder / row["log"]
        header = path.read_text().splitlines()[0]
        path.write_text(header + "\n" + reader.MARKER + json.dumps(row["guards"]) + "\n")
        row["log_sha256"] = reader.sha(path)

    def test_original_complete_platform_shapes(self):
        for platform, count in (("linux", 8), ("win32", 5)):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                report, kwargs, _ = self.fixture(folder, platform)
                result = self.verify(folder, report, kwargs)
                self.assertEqual(result["executions"], count)
                self.assertIn("no child PID/lifetime claim", result["scope"])

    def test_windows_mixed_separators_preserve_one_fixed_target(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            report, kwargs, _ = self.fixture(folder, "win32")
            for index, row in enumerate(report["executions"]):
                if index % 2:
                    row["guards"]["path"] = row["guards"]["path"].replace("/Godot/", "\\Godot/")
                else:
                    row["path"] = row["path"].replace("\\goblin\\", "/goblin\\")
                self.rewrite_guard(folder, row)
            self.assertEqual(self.verify(folder, report, kwargs)["executions"], 5)

    def test_windows_separator_equivalence_does_not_change_target(self):
        changes = {
            "drive": lambda p: p.replace("C:", "D:"),
            "drive_case": lambda p: p.replace("C:", "c:"),
            "profile": lambda p: p.replace("profile-original", "profile-foreign"),
            "directory": lambda p: p.replace("Sandbox", "Other"),
            "directory_case": lambda p: p.replace("Godot", "godot"),
            "leaf": lambda p: p.replace("transcript.json", "other.json"),
            "dot": lambda p: p.replace("/Godot/", "/./Godot/"),
            "traversal": lambda p: p.replace("/Godot/", "/outside/../Godot/"),
            "relative": lambda p: p.removeprefix("C:/"),
            "double_separator": lambda p: p.replace("/Godot/", "//Godot/"),
        }
        for name, change in changes.items():
            with self.subTest(change=name), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                report, kwargs, _ = self.fixture(folder, "win32")
                row = report["executions"][0]
                row["guards"]["path"] = change(row["guards"]["path"])
                self.rewrite_guard(folder, row)
                with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_windows_agreed_paths_still_require_absolute_profile_and_fixed_leaf(self):
        changes = {
            "foreign_profile": lambda p: p.replace("profile-original", "profile-foreign"),
            "foreign_leaf": lambda p: p.replace("transcript.json", "other.json"),
            "relative": lambda p: p.removeprefix("C:/"),
            "dot_before_profile": lambda p: p.replace("/evidence/", "/evidence/./"),
            "traversal_before_profile": lambda p: p.replace("/evidence/", "/evidence/other/../"),
            "traversal_after_profile": lambda p: p.replace("/Godot/", "/other/../Godot/"),
        }
        for name, change in changes.items():
            with self.subTest(change=name), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                report, kwargs, _ = self.fixture(folder, "win32")
                for row in report["executions"]:
                    row["guards"]["path"] = change(row["guards"]["path"])
                    row["path"] = row["guards"]["path"].replace("/", "\\")
                    self.rewrite_guard(folder, row)
                with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_windows_marker_and_recorded_guards_remain_exact(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            report, kwargs, _ = self.fixture(folder, "win32")
            row = report["executions"][0]
            row["guards"]["path"] = row["guards"]["path"].replace("/", "\\")
            with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_linux_separator_spelling_is_not_normalized(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            report, kwargs, _ = self.fixture(folder)
            report["executions"][0]["path"] = report["executions"][0]["path"].replace("/", "\\")
            with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_refuses_changed_source_and_inventory(self):
        mutations = [lambda r: r.update(source_head="4" * 40),
                     lambda r: r["input_sha256"].pop(reader.INPUTS[0]),
                     lambda r: r["cases"].pop(),
                     lambda r: r["executions"].append(copy.deepcopy(r["executions"][0]))]
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                report, kwargs, _ = self.fixture(folder)
                mutation(report)
                with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_refuses_different_child_and_disconnected_guard(self):
        for change in ("command", "guard"):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                report, kwargs, _ = self.fixture(folder)
                if change == "command": report["executions"][0]["command"][-1] = "res://tests/other.gd"
                else: report["executions"][0]["guards"]["wrong_path_refused"] = False
                with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_refuses_failed_log_even_with_recomputed_hash(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            report, kwargs, _ = self.fixture(folder)
            row = report["executions"][0]
            path = folder / row["log"]
            path.write_text(path.read_text() + "SCRIPT ERROR: unrelated failure\n")
            row["log_sha256"] = reader.sha(path)
            with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_refuses_replaced_refusal_bytes_even_with_recomputed_hash(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            report, kwargs, _ = self.fixture(folder)
            row = report["executions"][3]
            path = folder / row["retained_bytes"]
            path.write_bytes((folder / report["executions"][4]["retained_bytes"]).read_bytes())
            row.update(sha256=reader.sha(path), bytes=path.stat().st_size, value=8)
            with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_refuses_changed_final_or_unrelated_staging(self):
        for change in ("final", "stale"):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                report, kwargs, target = self.fixture(folder)
                (target if change == "final" else target.with_name(target.name + ".partial")).write_bytes(b"changed")
                with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)

    def test_refuses_false_windows_lock_and_linux_limit(self):
        for platform in ("win32", "linux"):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                report, kwargs, _ = self.fixture(folder, platform)
                if platform == "win32": report["cases"][1]["lock"]["delete_access_probe_error"] = 0
                else: report["cases"][1]["limit_bytes"] = 8192
                with self.assertRaises(RuntimeError): self.verify(folder, report, kwargs)


if __name__ == "__main__":
    unittest.main()
