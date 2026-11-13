#!/usr/bin/env python3
"""Source-lease, branch isolation and Windows ZIP portability regression guards."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

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
        for names in (("NUL.txt",), ("file:stream",), ("ending. ",), ("same.txt", "SAME.txt"), ("../outside",), ("/absolute",)):
            with self.subTest(names=names), self.assertRaises(RuntimeError): subject.validate_archive_names(list(names), 220)


if __name__ == "__main__":
    unittest.main()
