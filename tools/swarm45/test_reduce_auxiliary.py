"""Original-shape evidence fixtures and forged-summary negatives, never execution claims."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import struct
import tempfile
import unittest
import zlib

import runtime_custody as custody
import reduce_auxiliary as subject
from shared import load


def png(path: Path, *, blank: bool = False) -> None:
    width, height = 640, 512
    rgb = b"".join(bytes((0, 0, 0) if blank else (x % 256, y % 256, (x + y) % 256)) for y in range(height) for x in range(width))
    raw = b"".join(b"\0" + rgb[y * width * 3:(y + 1) * width * 3] for y in range(height))
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


class OwnerOriginalEvidence(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.evidence = Path(self.temporary.name)
        self.directory = self.evidence / "windows-launcher"
        self.dispatch_root = self.directory / "dispatch"
        self.dispatch_root.mkdir(parents=True)
        self.source = "a" * 40
        self.receipt = {"source_commit": self.source, "platform": "windows", "extension": "native.dll", "cli": "cli.exe",
                        "files": {"native.dll": {"sha256": "b" * 64}, "cli.exe": {"sha256": "c" * 64}}}
        self.seal = {"source_commit": self.source, "archive_sha256": "d" * 64,
                     "launcher_sha256": "e" * 64, "manifest_sha256": "f" * 64}
        self.graphical = {"package_zip_sha256": self.seal["archive_sha256"],
                          "execution_layout": {"manifest_sha256": self.seal["manifest_sha256"],
                              "files_sha256": {"Godot_v4.7-stable_win64.exe": "1" * 64}}}
        paths = {"owner-dispatch.log": f"Verified GENTEK-SWARM-006 source {self.source}; exact source\n",
                 "isolated profile with spaces/roaming/Godot/godot.log": subject.DISPATCH.PINNED_ENGINE_HEADER + "\n"
                    + "\n".join(subject.DISPATCH.RECOVERED_AUDIO_BLOCK) + "\n" + subject.DISPATCH.MARKER + "\n"}
        for name, text in paths.items():
            path = self.dispatch_root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        png(self.dispatch_root / "owner-workbench-window.png")
        engine = r"C:\Owner package with spaces\Godot_v4.7-stable_win64.exe"
        project = r"C:\Owner package with spaces\godot"
        self.dispatch = {"schema": 2, "source_commit": self.source, "audio_diagnostic_policy": subject.DISPATCH.AUDIO_POLICY,
            "audio_prefix_grace_seconds": subject.DISPATCH.AUDIO_PREFIX_GRACE_SECONDS, "platform": "Windows", "verify_only": False,
            "launcher_returncode": 0, "verified_source_logged": True, "owned_before_resume": True, "job_empty_after_retirement": True,
            "window": {"visible": True, "responsive": True, "title": "CyberSand Development workbench", "width": 640, "height": 512, "job_member": True},
            "stable_seconds": 10, "godot_argv": [engine, "--path", project, "--", "--workbench"],
            "expected_engine": engine, "expected_project": project, "launch_marker_observed": True,
            "screenshot": subject.owner_png(self.dispatch_root / "owner-workbench-window.png"),
            "archive_sha256": self.seal["archive_sha256"], "launcher_sha256": self.seal["launcher_sha256"],
            "test_sha256": custody.sha(custody.ROOT / "tools/swarm006/owner_dispatch.py"),
            "job_helper_sha256": custody.sha(subject.DISPATCH.JOB_HELPER), "passed": True, "validation_errors": [], "owner_nvidia_acceptance": "pending"}
        for key, value in (("engine_sha256", "1" * 64), ("native_sha256", "b" * 64),
                           ("reciprocal_cli_sha256", "c" * 64), ("manifest_sha256", "f" * 64)):
            self.dispatch[key] = self.dispatch["expected_" + key] = value
        original = {"C:/runner/dispatch/" + name: text for name, text in paths.items()}
        self.dispatch.update(subject.DISPATCH.classify_startup_logs(original))
        self.dispatch["logs_sha256"] = {name.replace("/", "\\"): custody.sha(self.dispatch_root / name) for name in paths}
        cases = (("direct-inner-archive", True, self.source), ("github-nested-artifact", True, self.source),
                 ("stale-destination", False, "Destination already exists"), ("corrupted-archive", False, "ZIP SHA-256 mismatch"),
                 ("wrong-sidecar-name", False, "sidecar does not name"), ("missing-sidecar", False, "Missing separate SHA-256 sidecar"))
        rows = []
        for name, passed, message in cases:
            path = self.directory / (name + ".log")
            path.write_text(message + "\n")
            rows.append({"case": name, "expected_success": passed, "returncode": 0 if passed else 1,
                         "passed": True, "log_sha256": custody.sha(path)})
        rows.append({"case": "actual-owner-graphical-dispatch", "passed": True, "expected_success": True,
                     "evidence": "dispatch/owner-dispatch-qualification.json"})
        self.value = {**self.seal, "platform": "Windows", "passed": True, "graphical_dispatch_passed": True, "graphical_qualification": False,
                      "owner_nvidia_acceptance": "pending", "results": rows}
        custody.write_json(self.evidence / "windows-package-seal.json", self.seal)
        self.save()

    def save(self):
        path = self.dispatch_root / "owner-dispatch-qualification.json"
        custody.write_json(path, self.dispatch)
        self.value["results"][-1]["evidence_sha256"] = custody.sha(path)
        self.value["files_sha256"] = custody.inventory(self.directory)
        self.value["files_sha256"].pop("owner-launcher-qualification.json", None)
        custody.write_json(self.directory / "owner-launcher-qualification.json", self.value)

    def check(self):
        return subject.validate_owner_launcher(self.evidence, self.graphical, self.receipt)

    def test_complete_original_shape_and_exact_audio_recovery_are_accepted(self):
        self.assertEqual(subject.DISPATCH.evidence_errors(self.dispatch), [])
        self.assertEqual(self.check()["report"], "windows-launcher/owner-launcher-qualification.json")

    def test_rehashed_summary_cannot_hide_failed_launcher_or_dispatch(self):
        self.value["results"][0]["returncode"] = 99
        self.save()
        with self.assertRaisesRegex(ValueError, "original launcher"):
            self.check()
        self.value["results"][0]["returncode"] = 0
        self.dispatch["window"]["responsive"] = False
        self.save()
        with self.assertRaisesRegex(ValueError, "original dispatch validation"):
            self.check()

    def test_rehashed_failed_raw_log_cannot_borrow_success_flags(self):
        name = "isolated profile with spaces/roaming/Godot/godot.log"
        path = self.dispatch_root / name
        path.write_text(path.read_text() + "SCRIPT ERROR: hidden original failure\n")
        self.dispatch["logs_sha256"][name.replace("/", "\\")] = custody.sha(path)
        self.save()
        with self.assertRaisesRegex(ValueError, "raw logs/audio"):
            self.check()

    def test_rehashed_blank_screenshot_and_foreign_runtime_cannot_pass(self):
        png(self.dispatch_root / "owner-workbench-window.png", blank=True)
        self.dispatch["screenshot"]["sha256"] = custody.sha(self.dispatch_root / "owner-workbench-window.png")
        self.save()
        with self.assertRaisesRegex(ValueError, "framebuffer"):
            self.check()
        png(self.dispatch_root / "owner-workbench-window.png")
        self.dispatch["screenshot"] = subject.owner_png(self.dispatch_root / "owner-workbench-window.png")
        self.dispatch["native_sha256"] = self.dispatch["expected_native_sha256"] = "9" * 64
        self.save()
        with self.assertRaisesRegex(ValueError, "source/runtime/process"):
            self.check()


class SmokeOriginalEvidence(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.receipt = {"platform": "linux", "extension": "native.so", "files": {"native.so": {"sha256": "d" * 64}}}
        self.engine = "/fixture/Godot_v4.7-stable_linux.x86_64"
        self.project = "/fixture/project/godot"
        self.rows = []
        for label, script, marker, graphical in subject.SMOKE_CASES:
            command = self.command(script, graphical)
            row = {"label": label, "status": "passed", "exit_code": 0, "command": command}
            text = "Godot import completed\n"
            if marker:
                result = {"checks": 8, "failures": []}
                if label == "art-durability":
                    result = {"checks": 13, "failures": [], "scope": "session-only"}
                if label == "workbench-wave":
                    result = {"schema": "workbench-wave-631-v1", "failures": 0, "assertions": 8,
                              "real_workbench": True, "native_ticks": 8, "platform": "Linux", "godot": "4.7-stable (official)",
                              "sections": {name: True for name in subject.WATER_SECTIONS}}
                if label.startswith("paint-"):
                    result.update(reopen="1" if label.endswith("reopen") else "0", completed=True)
                if label in ("actors-author", "actors-reopen"):
                    result.update(headless=False, preservation_notes=[], screenshots=[{"path": "/retained/" + label + "-frames/actual.png"}])
                    custody.write_json(self.directory / (label + ".json"), result)
                    png(self.directory / (label + "-frames/actual.png"))
                row["completion"] = result
                text = marker + " " + json.dumps(result) + "\n"
            (self.directory / (label + ".log")).write_text(text)
            self.rows.append(row)
        self.rows.append({"label": "flatten-512x1", "status": "passed", "exit_code": 0,
                          "command": ["python3", "/source/tools/ci/run_flatten_qualification.py", "--cases", "512x1"]})
        (self.directory / "flatten-512x1.log").write_text("completed original Flatten child\n")
        for folder, names in (("paint-workbench-frames", ("paint001-mixed-stamp-preview.png", "paint001-mounted-editor.png")),
                              ("paint-generated-frames", ("paint001-generated-authored.png", "paint001-generated-reopened.png")),
                              ("art-frames", ("native-material-readback.png", "stage1.png", "stage1-1280.png"))):
            for name in names: png(self.directory / folder / name)
        original = load("swarm456_scoped_flatten_test_receipts", "tools/ci/test_gen008_flatten_runtime_publication.py")
        fixture = original.FlattenReceiptAdmission()
        fixture.setUp()
        self.addCleanup(fixture.tearDown)
        flatten = self.directory / "flatten"
        shutil.copytree(fixture.directory, flatten)
        keep = {"flatten-import", "standalone-format-adversarial", "side-512-workers-1-author", "side-512-workers-1-reopen",
                "owner-failure-author", "owner-failure-reopen"}
        self.flatten_rows = [row for row in fixture.records if row["label"] in keep]
        for row in self.flatten_rows:
            label = row["label"]
            script = (None if label == "flatten-import" else "test_workbench_material_baseline" if label == "standalone-format-adversarial"
                      else "test_workbench_flatten_owner_failure" if label.startswith("owner-failure") else "test_workbench_flatten")
            row["command"] = self.command(script, label not in ("flatten-import", "standalone-format-adversarial"))
            if label == "standalone-format-adversarial":
                row["completion"] = {"checks": 90, "failures": 0}
        for path in flatten.glob("*-frames/*.png"): png(path)
        custody.write_json(flatten / "results.json", self.flatten_rows)
        summary = json.loads((flatten / "qualification.json").read_text())
        summary["cases"] = [[512, 1]]
        custody.write_json(flatten / "qualification.json", summary)
        self.value = {"results": self.rows, "godot_engine_sha256": fixture.engine_sha}
        self.save()

    def command(self, script, graphical):
        command = [self.engine, "--audio-driver", "Dummy"]
        command += ["--display-driver", "x11", "--rendering-method", "gl_compatibility"] if graphical else ["--headless"]
        command += ["--path", self.project]
        command += ["--script", "res://tests/" + script + ".gd"] if script else ["--editor", "--quit"]
        return command

    def save(self):
        custody.write_json(self.directory / "results.json", self.rows)

    def check(self):
        subject.validate_smokes(self.directory, self.value, self.receipt)

    def test_complete_named_original_receipts_are_accepted(self):
        self.check()

    def test_retired_or_wrong_scope_art_history_cannot_qualify_new_session_smoke(self):
        index = next(i for i, row in enumerate(self.rows) if row["label"] == "art-durability")
        row = self.rows[index]
        log = self.directory / "art-durability.log"
        valid = {"checks": 13, "failures": [], "scope": "session-only"}
        # Retired cross-session durability evidence is not the accepted #727 test.
        log.write_text("ART_HISTORY_DURABILITY_RESULT " + json.dumps({"checks": 345, "failures": []}) + "\n")
        with self.assertRaisesRegex(ValueError, "Missing/duplicate completion"):
            self.check()
        for change in ({"scope": "cross-session"}, {"checks": 9}, {"checks": True},
                       {"failures": ["old log changed"]}, {"failures": 0}):
            with self.subTest(change=change):
                altered = {**valid, **change}
                row["completion"] = altered
                log.write_text("ART_HISTORY_SESSION_RESULT " + json.dumps(altered) + "\n")
                self.save()
                with self.assertRaisesRegex(ValueError, "accepted session-only audit"):
                    self.check()
        row["completion"] = valid
        self.save()
        line = "ART_HISTORY_SESSION_RESULT " + json.dumps(valid) + "\n"
        log.write_text(line + line)
        with self.assertRaisesRegex(ValueError, "Missing/duplicate completion"):
            self.check()

    def test_rehashed_summary_cannot_hide_failed_exit_or_missing_actual_receipt(self):
        self.rows[1]["exit_code"] = 99
        self.save()
        with self.assertRaisesRegex(ValueError, "Original smoke process failed"):
            self.check()
        self.rows[1]["exit_code"] = 0
        self.save()
        (self.directory / "workbench-canvas.log").write_text("FAIL unrelated raw log\n")
        with self.assertRaisesRegex(ValueError, "completion is absent"):
            self.check()

    def test_rehashed_markers_cannot_remove_fresh_reopen_or_native_failure_evidence(self):
        row = self.flatten_rows[3]
        row["completion"]["process_instance"] = self.flatten_rows[2]["completion"]["process_instance"]
        custody.write_json(self.directory / "flatten/results.json", self.flatten_rows)
        (self.directory / "flatten" / (row["label"] + ".log")).write_text("FLATTEN_RESULT " + json.dumps(row["completion"]) + "\n")
        with self.assertRaisesRegex(ValueError, "reused a process"):
            self.check()

    def test_rehashed_success_flags_cannot_hide_raw_headless_or_png_removal(self):
        self.rows[2]["command"].append("--headless")
        self.save()
        with self.assertRaisesRegex(ValueError, "graphics mode"):
            self.check()
        self.rows[2]["command"].remove("--headless")
        self.save()
        (self.directory / "actors-author-frames/actual.png").unlink()
        with self.assertRaisesRegex(ValueError, "framebuffer"):
            self.check()


if __name__ == "__main__":
    unittest.main()
