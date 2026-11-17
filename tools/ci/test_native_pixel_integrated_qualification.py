#!/usr/bin/env python3
"""Source-lease, branch isolation and Windows ZIP portability regression guards."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import zlib

import native_pixel_integrated_qualification as subject


class QualificationTests(unittest.TestCase):
    SOURCE = "1" * 40
    TREE = "2" * 40

    def environment(self):
        return {"GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_REF": "refs/heads/" + subject.BRANCH,
                "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + subject.WORKFLOW + "@refs/heads/" + subject.BRANCH,
                "GITHUB_SHA": self.SOURCE, "GITHUB_EVENT_NAME": "push", "GITHUB_RUN_ID": "10", "GITHUB_RUN_ATTEMPT": "1"}

    def git(self, *args):
        if args == ("rev-parse", "HEAD"): return self.SOURCE.encode()
        if args == ("rev-parse", self.SOURCE + "^{tree}"): return self.TREE.encode()
        if args == ("merge-base", "--is-ancestor", subject.ACCEPTED_MAIN, self.SOURCE): return b""
        if args == ("ls-remote", "--exit-code", "origin", "refs/heads/" + subject.BRANCH):
            return (self.SOURCE + "\trefs/heads/" + subject.BRANCH).encode()
        raise AssertionError(args)

    def test_context_binds_real_head_workflow_and_accepted_main_ancestry(self):
        with patch.dict(os.environ, self.environment(), clear=True), patch.object(subject.engine, "git", side_effect=self.git) as git:
            result = subject.context(self.SOURCE)
            self.assertEqual(result["source_commit"], self.SOURCE)
            self.assertEqual(result["source_tree"], self.TREE)
            git.assert_any_call("merge-base", "--is-ancestor", subject.ACCEPTED_MAIN, self.SOURCE)

    def test_wrong_repository_branch_workflow_event_or_head_is_refused(self):
        for key in ("GITHUB_REPOSITORY", "GITHUB_REF", "GITHUB_WORKFLOW_REF", "GITHUB_SHA", "GITHUB_EVENT_NAME", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
            with self.subTest(key=key), patch.dict(os.environ, self.environment() | {key: "unexpected"}, clear=True), patch.object(subject.engine, "git", side_effect=self.git):
                with self.assertRaises(RuntimeError): subject.context(self.SOURCE)

    def test_missing_accepted_main_ancestry_is_not_admitted(self):
        def git(*args):
            if args[0] == "merge-base": raise subprocess.CalledProcessError(1, "git")
            return self.git(*args)
        with patch.dict(os.environ, self.environment(), clear=True), patch.object(subject.engine, "git", side_effect=git):
            with self.assertRaises(subprocess.CalledProcessError): subject.context(self.SOURCE)

    def test_remote_head_movement_blocks_admission(self):
        def git(*args):
            if args[0] == "ls-remote": return ("3" * 40 + "\trefs/heads/" + subject.BRANCH).encode()
            return self.git(*args)
        with patch.dict(os.environ, self.environment(), clear=True), patch.object(subject.engine, "git", side_effect=git):
            with self.assertRaisesRegex(RuntimeError, "branch moved"): subject.check_source(self.SOURCE)

    def test_changed_native_inputs_require_separate_publication(self):
        ledgers = {"source_inputs": {"native/src/world.cpp": "current"}, "build_inputs": {"fixture.gd": "test"}}
        with patch.dict(os.environ, self.environment(), clear=True), patch.object(subject.engine, "git", side_effect=self.git), patch.object(subject.engine, "input_ledgers", return_value=ledgers), patch.object(subject.profile, "read_json", return_value={"source_inputs": {"native/src/world.cpp": "historical"}}):
            with self.assertRaisesRegex(RuntimeError, "require separate publication"): subject.check_source(self.SOURCE)

    def test_historical_build_inputs_do_not_force_native_republication(self):
        ledgers = {"source_inputs": {"native/src/world.cpp": "same"}, "build_inputs": {"fixture.gd": "current"}}
        retained = {"source_inputs": ledgers["source_inputs"], "build_inputs": {"fixture.gd": "historical"}}
        with patch.dict(os.environ, self.environment(), clear=True), patch.object(subject.engine, "git", side_effect=self.git), patch.object(subject.engine, "input_ledgers", return_value=ledgers), patch.object(subject.profile, "read_json", return_value=retained):
            self.assertEqual(subject.check_source(self.SOURCE)["native_inputs"], 1)

    def test_entry_point_exposes_no_runtime_or_ref_publication(self):
        for command in ("stage", "check-index", "publish", "merge"):
            with self.subTest(command=command), patch.object(sys, "argv", ["profile", command]):
                with self.assertRaises(SystemExit) as result: subject.main()
                self.assertEqual(result.exception.code, 2)

    def test_dispatch_creates_nested_receipt_before_network_and_preserves_it(self):
        class Acknowledgement:
            status = 204
            def __enter__(self): return self
            def __exit__(self, *_): return False

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "absent" / "build" / "dispatch.json"
            args = argparse.Namespace(source_sha=self.SOURCE, output=output)
            calls = []
            def send(request, timeout):
                # The original failure happened here before any network call.
                # Each request must already have a durable previous-state receipt.
                receipt = json.loads(output.read_text())
                self.assertEqual(receipt["status"], "requesting")
                self.assertEqual(len(receipt["requests"]), len(calls))
                self.assertEqual(json.loads(request.data), {"ref": subject.BRANCH})
                calls.append(request.full_url)
                return Acknowledgement()
            with patch.dict(os.environ, {"GITHUB_TOKEN": "fixture-token"}), patch.object(subject, "check_source"), patch.object(subject, "context", return_value={"source_commit": self.SOURCE}), patch.object(subject.urllib.request, "urlopen", side_effect=send):
                result = subject.dispatch_existing(args)
                self.assertEqual(len(calls), len(subject.DISPATCH_WORKFLOWS))
                self.assertTrue(result["completed"])
                self.assertEqual(json.loads(output.read_text()), result)
                original = output.read_bytes()
                with self.assertRaisesRegex(RuntimeError, "overwrite"): subject.dispatch_existing(args)
                self.assertEqual(output.read_bytes(), original)
                self.assertEqual(len(calls), len(subject.DISPATCH_WORKFLOWS))

    def test_archive_roundtrip_preserves_hidden_history_and_original_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "package"
            for name, data in {"Open Workbench.cmd": b"@echo off\r\n", "source/.git/HEAD": b"fixture\n",
                               "source/data.bin": bytes(range(256))}.items():
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            archive = root / "evaluation.zip"
            result = subject.write_archive(source, archive, max_path=220)
            self.assertEqual(result["members"], 3)
            self.assertEqual(result["sha256"], hashlib.sha256(archive.read_bytes()).hexdigest())
            with zipfile.ZipFile(archive) as stored:
                for name in stored.namelist(): self.assertEqual(stored.read(name), (source / name).read_bytes())
                self.assertTrue(all(item.extract_version == 20 and item.compress_type == 8 for item in stored.infolist()))

    def test_archive_roundtrip_keeps_detached_git_usable_with_retained_ancestor(self):
        lab = subject.packager().lab
        with tempfile.TemporaryDirectory(prefix="detached Git ZIP ") as temporary:
            root = Path(temporary)
            original = root / "original source"
            original.mkdir()

            def git(directory, *arguments):
                return subprocess.run(["git", "-C", str(directory), *arguments], check=True,
                                      capture_output=True, env=lab.clean_git_environment()).stdout

            git(original, "init")
            retained = b"retained compatibility payload\n"
            (original / "retained.txt").write_bytes(retained)
            git(original, "add", "retained.txt")
            git(original, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "commit", "-m", "retained baseline")
            baseline = git(original, "rev-parse", "HEAD").decode().strip()
            (original / "retained.txt").write_bytes(b"current payload\n")
            git(original, "add", "retained.txt")
            git(original, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "commit", "-m", "current source")
            head = git(original, "rev-parse", "HEAD").decode().strip()
            package = root / "delivery"
            source = package / "source"
            lab.clean_source_repository(original, head, source)
            self.assertEqual((source / ".git/HEAD").read_text().strip(), head)
            self.assertTrue((source / ".git/refs").is_dir())
            self.assertFalse(any(path.is_file() for path in (source / ".git/refs").rglob("*")))
            (package / "empty cache/nested").mkdir(parents=True)
            original_files = lab.file_map(package)
            archive = root / "delivery.zip"
            subject.write_archive(package, archive, max_path=220)
            extracted = root / "extracted delivery"
            with zipfile.ZipFile(archive) as stored:
                empty = stored.getinfo("empty cache/nested/")
                self.assertTrue(empty.is_dir())
                self.assertEqual((empty.file_size, empty.compress_type, empty.extract_version), (0, zipfile.ZIP_STORED, 20))
                stored.extractall(extracted)
            delivered = extracted / "source"
            self.assertTrue((delivered / ".git/refs").is_dir())
            self.assertTrue((extracted / "empty cache/nested").is_dir())
            self.assertEqual(lab.file_map(extracted), original_files)
            self.assertEqual(git(delivered, "show", baseline + ":retained.txt"), retained)
            self.assertEqual(git(delivered, "rev-parse", "HEAD").decode().strip(), head)
            self.assertEqual(git(delivered, "rev-parse", "--is-shallow-repository").strip(), b"false")
            self.assertEqual(git(delivered, "merge-base", "--is-ancestor", baseline, head), b"")
            self.assertEqual(git(delivered, "remote"), b"")

    def test_original_long_qualification_cache_path_is_refused_for_outer_archive(self):
        original = "qualification/workbench/regressions/art-final-graphical/isolated-appdata/Godot/app_userdata/Cyber Sand Reference Sandbox/shader_cache/CanvasShaderGLES3/" + "4" * 64 + "/" + "f" * 40 + ".cache"
        self.assertEqual(len(original), 263)
        # Do not require Windows to first create the path that its Shell cannot
        # safely extract. Admit/refuse the original central-directory member.
        with self.assertRaisesRegex(RuntimeError, "exceeds Windows extraction budget"):
            subject.validate_archive_names([original], 220)

    def test_inner_evidence_archive_preserves_long_original_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            raw = root / "qualification"
            path = raw / ("original/" + "nested/" * 15 + "receipt.json")
            path.parent.mkdir(parents=True)
            path.write_bytes(b'{"historical":"unchanged"}\n')
            outer = root / "package"
            outer.mkdir()
            subject.write_archive(raw, outer / "qualification.zip")
            result = subject.write_archive(outer, root / "outer.zip", max_path=220)
            self.assertEqual(result["maximum_relative_path"], len("qualification.zip"))
            with zipfile.ZipFile(outer / "qualification.zip") as original:
                self.assertEqual(original.read(path.relative_to(raw).as_posix()), path.read_bytes())

    def test_windows_invalid_names_and_collisions_are_refused(self):
        for names in (("NUL.txt",), ("file:stream",), ("ending. ",), ("same.txt", "SAME.txt"), ("../outside",), ("/absolute",),
                      ("empty/", "EMPTY"), ("extra//",), ("parent/../",), ("/absolute/",), ("NUL/",)):
            with self.subTest(names=names), self.assertRaises(RuntimeError): subject.validate_archive_names(list(names), 220)
        with self.assertRaisesRegex(RuntimeError, "exceeds Windows extraction budget"):
            subject.validate_archive_names(["d" * 220 + "/"], 220)

    def ui007_receipt(self, directory, rig="acrobat"):
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)) +
               chunk(b"IDAT", zlib.compress(b"\x00\xff\xff\xff\xff")) + chunk(b"IEND", b""))
        frames = directory / "frames" / rig
        frames.mkdir(parents=True, exist_ok=True)
        captures = []
        for camera in ("follow", "overview"):
            path = frames / (rig + "-" + camera + ".png")
            path.write_bytes(png)
            captures.append({"camera": camera, "path": str(path), "sha256": hashlib.sha256(png).hexdigest(),
                             "width": 1, "height": 1, "actor_parts": 1, "identity": {"rig": rig}})
        frame = {"current_layout_acknowledged": True, "exact_published_layers_agree": True,
                 "after_callback_exclusive": 3, "published_callback": 4,
                 **{key: [2.0, 3.0] for key in ("presented_origin", "target_origin", "actor_origin", "terrain_origin")}}
        row = {"rig": rig, "completed": True, "return_button_navigation": True,
               "return_activation": "actual_root_viewport_mouse_motion_press_release",
               "return_native_focus": {"acknowledged": True, "after_rendered_frame": True},
               "return_input": {"hover_after_motion": True, "pressed_signals": 1, "button_size": [100, 30],
                                "gui_events": [{"kind": "motion", "position": [50, 15], "button_mask": 0},
                                               {"kind": "button", "position": [50, 15], "button_mask": 1, "button_index": 1, "pressed": True},
                                               {"kind": "button", "position": [50, 15], "button_mask": 0, "button_index": 1, "pressed": False}]},
               "follow_presentation": copy.deepcopy(frame), "overview_presentation": copy.deepcopy(frame),
               "graphical_captures": captures}
        return {"schema": "play-ui007-v1", "source_revision": self.SOURCE, "rig": rig,
                "display_server": "X11", "physics_engine": "Rapier2D", "assertions": 71, "failures": 0,
                "manual_physics_calls": 0, "retries": 0, "row": row,
                **{key: True for key in ("real_host", "automatic_callbacks", "worker_joined", "session_retired", "graphical_capture_executed")}}

    def read_ui007(self, directory, result, rig="acrobat"):
        log = directory / ("play-ui007-" + rig + ".log")
        log.write_text("PLAY_UI007_RESULT " + json.dumps(result) + "\n", encoding="utf-8")
        return subject.play_ui007_completion(log, directory / "frames" / rig, self.SOURCE, rig, "linux")

    def test_ui007_keeps_original_assertions_and_both_actual_capture_hashes(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            result = self.ui007_receipt(directory)
            self.assertEqual(self.read_ui007(directory, result), result)
            self.assertNotIn("checks", result)
            capture = directory / "frames/acrobat/acrobat-overview.png"
            capture.write_bytes(capture.read_bytes() + b"changed")
            with self.assertRaisesRegex(RuntimeError, "missing or changed"):
                self.read_ui007(directory, result)

    def test_ui007_refuses_headless_short_receipts_and_missing_owner_teardown(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            original = self.ui007_receipt(directory)
            for key, value in (("display_server", "headless"), ("source_revision", "3" * 40),
                               ("assertions", 1), ("assertions", True), ("failures", 1),
                               ("worker_joined", False), ("session_retired", False), ("manual_physics_calls", 1)):
                with self.subTest(key=key, value=value), self.assertRaises(RuntimeError):
                    self.read_ui007(directory, original | {key: value})

    def test_ui007_refuses_signal_only_navigation_missing_input_and_stale_layout(self):
        mutations = (
            lambda row: row.update(return_button_navigation=False),
            lambda row: row.update(return_activation="actual_button_pressed_signal; headless_window_hit_testing_unqualified"),
            lambda row: row["return_native_focus"].update(acknowledged=False),
            lambda row: row["return_input"].update(hover_after_motion=False),
            lambda row: row["return_input"].update(pressed_signals=0),
            lambda row: row["return_input"]["gui_events"].pop(),
            lambda row: row["return_input"]["gui_events"][1].update(button_mask=0),
            lambda row: row["return_input"]["gui_events"][1].update(position=[100, 15]),
            lambda row: row["follow_presentation"].update(published_callback=3),
            lambda row: row["overview_presentation"].update(actor_origin=[4, 5]),
            lambda row: row["graphical_captures"].pop(),
        )
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            original = self.ui007_receipt(directory)
            for index, mutate in enumerate(mutations):
                result = copy.deepcopy(original)
                mutate(result["row"])
                with self.subTest(index=index), self.assertRaises(RuntimeError): self.read_ui007(directory, result)

    def test_ui007_bundle_reduction_refuses_relabelled_completion_or_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            camera = {"source_commit": self.SOURCE, "godot": "/engine/Godot", "project": "/source/godot", "godot_sha256": "4" * 64}
            native = Path(subject.engine.RUNTIMES["linux"]).relative_to("godot").as_posix()
            identity = {"schema": "native-pixel-play-ui007-graphical-v1", "platform": "linux", "camera_source_identity": camera,
                        "engine_files_sha256": {"Godot": "4" * 64}, "runtime_files_sha256": {native: "5" * 64}}
            (directory / "source-identity.json").write_text(json.dumps(identity))
            records = []
            for rig, label in zip(subject.PLAY_UI007_RIGS, subject.PLAY_UI007_LABELS):
                raw = self.ui007_receipt(directory, rig)
                self.read_ui007(directory, raw, rig)
                records.append({"label": label, "command": subject.play_ui007_command(camera["godot"], camera["project"], rig, "linux"),
                                "status": "passed", "exit_code": 0, "completion": raw})
            path = directory / "results.json"
            path.write_text(json.dumps(records))
            subject.verify_play_ui007(directory, "linux", self.SOURCE, camera, "5" * 64)
            with self.assertRaisesRegex(RuntimeError, "native runtime differs"):
                subject.verify_play_ui007(directory, "linux", self.SOURCE, camera, "6" * 64)
            records[0]["completion"]["assertions"] = 999
            path.write_text(json.dumps(records))
            with self.assertRaisesRegex(RuntimeError, "original raw receipt"):
                subject.verify_play_ui007(directory, "linux", self.SOURCE, camera, "5" * 64)


if __name__ == "__main__":
    unittest.main()
