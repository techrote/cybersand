#!/usr/bin/env python3
"""Adversarial checks for the branch-scoped player runtime publisher."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest import mock

import player_runtime_publication as subject


BRANCH = "feat/player-control-playground"
WORKFLOW = "techrote/cybersand/.github/workflows/player-runtime-publication.yml@refs/heads/" + BRANCH
RUNTIMES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
MANIFESTS = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
# An independent fixture: omitting a player/legacy case from the implementation
# must invalidate the otherwise passing complete execution receipt below.
SUCCESS_LOGS = {
    "test_player_acrobat": "PLAYER_ACROBAT: 304 assertions, 0 failures\n",
    "test_player_acrobat_physics": "PLAYER_ACROBAT_PHYSICS: 36 assertions, 0 failures\n",
    "test_player_material_field": "PLAYER_MATERIAL_FIELD: 56 assertions; 0 failures\n",
    "test_player_playground_course": "PLAYER_COURSE: 1446 assertions, 0 failures\n",
    "test_player_playground_runtime": "PLAYER_PLAYGROUND_RUNTIME: 1329 assertions, 0 failures; scope=all-seven-native-and-Rapier\n",
    "test_player_vehicle_controls": "Player vehicle controls: 79 assertions, 0 failures\n",
    "test_worldgen_workbench": "WORLDGEN_WORKBENCH: 100 assertions; 0 failures\n",
    "test_worldgen_fields": "WORLDGEN_FIELDS: 100 assertions; 0 failures\n",
    "test_worldgen_typed": "GEN-003 typed adapter and workbench: 100 assertions; 0 failures\n",
    "test_render_world_generation": "RENDER_WORLD_GENERATION: 100 assertions, 0 failures\n",
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pointer(data: bytes) -> bytes:
    return ("version https://git-lfs.github.com/spec/v1\n"
            f"oid sha256:{digest(data)}\nsize {len(data)}\n").encode()


class RepositoryFixture(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.root = self.directory / "source"
        self.root.mkdir()
        self.git("init", "--quiet")
        self.git("config", "user.name", "Publisher guard fixture")
        self.git("config", "user.email", "publisher-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in ["README.md", *RUNTIMES.values(), *MANIFESTS.values()]:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("original\n", encoding="utf-8", newline="\n")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Original source")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        self.args = argparse.Namespace(source_sha=self.source)
        patch = mock.patch.object(subject, "ROOT", self.root)
        patch.start()
        self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + BRANCH, "GITHUB_WORKFLOW_REF": WORKFLOW,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start()
        self.addCleanup(patch.stop)

    def git(self, *arguments: str, input: bytes | None = None) -> bytes:
        return subprocess.check_output(["git", "-C", str(self.root), *arguments], input=input, stderr=subprocess.PIPE)


class ContextTests(RepositoryFixture):
    def test_exact_feature_push_is_admitted(self):
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)

    def test_other_repo_branch_event_workflow_or_head_is_rejected(self):
        mutations = {
            "GITHUB_REPOSITORY": "someone/cybersand",
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_EVENT_NAME": "pull_request",
            "GITHUB_WORKFLOW_REF": WORKFLOW.replace("player-runtime", "gen003-runtime"),
            "GITHUB_SHA": "f" * 40,
            "GITHUB_RUN_ATTEMPT": "0",
        }
        for key, value in mutations.items():
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError):
                    subject.context(self.source)

    def test_changed_remote_branch_is_refused_without_altering_checkout(self):
        remote = self.directory / "remote.git"
        subprocess.run(["git", "clone", "--quiet", "--bare", str(self.root), str(remote)], check=True, capture_output=True)
        remote_git = ["git", "--git-dir", str(remote)]
        subprocess.run([*remote_git, "update-ref", "refs/heads/" + BRANCH, self.source], check=True)
        self.git("remote", "add", "origin", str(remote))
        subject.check_source(self.args)
        changed = subprocess.check_output([
            *remote_git, "-c", "user.name=Remote fixture", "-c", "user.email=fixture@example.invalid",
            "commit-tree", self.source + "^{tree}", "-p", self.source,
        ], input=b"Concurrent source change\n").decode().strip()
        subprocess.run([*remote_git, "update-ref", "refs/heads/" + BRANCH, changed], check=True)
        with self.assertRaisesRegex(RuntimeError, "Feature branch changed"):
            subject.check_source(self.args)
        self.assertEqual(self.git("rev-parse", "HEAD").decode().strip(), self.source)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.report = {"results": [], "log_sha256": {}}
        for name, output in {"import": "Clean import completed\n", **SUCCESS_LOGS}.items():
            self.report["results"].append({
                "name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": [],
            })
            self.write_log(name, output)

    def write_log(self, name: str, output: str):
        path = self.root / (name + ".log")
        path.write_text(output, encoding="utf-8", newline="\n")
        self.report["log_sha256"][path.name] = digest(path.read_bytes())

    def test_json_bytes_do_not_change_with_windows_text_newline_defaults(self):
        original = Path.write_text

        def windows_write_text(path, data, *args, **kwargs):
            if kwargs.get("newline") is None:
                kwargs["newline"] = "\r\n"
            return original(path, data, *args, **kwargs)

        path = self.root / "runtime-provenance.json"
        with mock.patch.object(Path, "write_text", windows_write_text):
            subject.write_json(path, {"source": "fixture", "passed": True})
        self.assertEqual(path.read_bytes(), b'{\n  "passed": true,\n  "source": "fixture"\n}\n')

    def test_complete_six_player_and_four_worldgen_cases_are_required(self):
        subject.verify_case_results(self.root, self.report)
        for omitted in SUCCESS_LOGS:
            with self.subTest(omitted=omitted):
                shortened = dict(self.report, results=[item for item in self.report["results"] if item["name"] != omitted])
                with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
                    subject.verify_case_results(self.root, shortened)

    def test_duplicate_case_cannot_substitute_for_missing_case(self):
        self.report["results"][-1] = dict(self.report["results"][-2])
        with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
            subject.verify_case_results(self.root, self.report)

    def test_zero_assertions_and_narrowed_runtime_scope_are_rejected(self):
        for output in (
            "PLAYER_PLAYGROUND_RUNTIME: 0 assertions, 0 failures; scope=all-seven-native-and-Rapier\n",
            "PLAYER_PLAYGROUND_RUNTIME: 1329 assertions, 0 failures; scope=physical-and-input-only\n",
        ):
            with self.subTest(output=output):
                self.write_log("test_player_playground_runtime", output)
                with self.assertRaisesRegex(RuntimeError, "Missing successful assertion summary"):
                    subject.verify_case_results(self.root, self.report)

    def test_error_or_skip_log_cannot_hide_behind_a_passing_record(self):
        for suffix in ("SCRIPT ERROR: omitted native path\n", "SKIP no native field\n"):
            with self.subTest(suffix=suffix):
                self.write_log("test_player_material_field", SUCCESS_LOGS["test_player_material_field"] + suffix)
                with self.assertRaisesRegex(RuntimeError, "Execution log contains an error or skip"):
                    subject.verify_case_results(self.root, self.report)

    def test_changed_log_bytes_are_rejected(self):
        (self.root / "test_player_acrobat.log").write_text("changed\n", encoding="utf-8", newline="\n")
        with self.assertRaisesRegex(RuntimeError, "Execution log digest mismatch"):
            subject.verify_case_results(self.root, self.report)


class PublicationIndexTests(RepositoryFixture):
    def setUp(self):
        super().setUp()
        for platform, relative in RUNTIMES.items():
            data = bytearray(90)
            if platform == "linux":
                data[:6] = b"\x7fELF\x02\x01"
                data[16:20] = b"\x03\x00\x3e\x00"
            else:
                data[:2] = b"MZ"
                struct.pack_into("<I", data, 60, 64)
                data[64:70] = b"PE\0\0\x64\x86"
                struct.pack_into("<H", data, 86, 0x2000)
                struct.pack_into("<H", data, 88, 0x020B)
            data = bytes(data)
            (self.root / relative).write_bytes(data)
            self.stage_blob(relative, pointer(data))
            manifest = {
                "artifact": relative, "sha256": digest(data), "size": len(data),
                "source_commit": self.source, "status": "validated-development-runtime",
            }
            manifest_path = self.root / MANIFESTS[platform]
            manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8", newline="\n")
            self.git("add", "--", MANIFESTS[platform])

    def stage_blob(self, relative: str, data: bytes, mode: str = "100644"):
        oid = self.git("hash-object", "-w", "--stdin", input=data).decode().strip()
        self.git("update-index", "--add", "--cacheinfo", mode + "," + oid + "," + relative)

    def test_complete_matching_four_path_publication_is_admitted(self):
        subject.check_index(self.args)

    def test_unchanged_binary_bytes_with_new_manifests_are_admitted(self):
        self.git("commit", "--quiet", "-m", "Previous runtime publication")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        self.args.source_sha = self.source
        with mock.patch.dict(os.environ, {"GITHUB_SHA": self.source}):
            for relative in MANIFESTS.values():
                path = self.root / relative
                manifest = json.loads(path.read_text())
                manifest["source_commit"] = self.source
                path.write_text(json.dumps(manifest) + "\n", encoding="utf-8", newline="\n")
                self.git("add", "--", relative)
            subject.check_index(self.args)

    def test_extra_source_edit_or_missing_manifest_is_rejected(self):
        (self.root / "README.md").write_text("unrelated edit\n", encoding="utf-8", newline="\n")
        self.git("add", "README.md")
        with self.assertRaisesRegex(RuntimeError, "only the four runtime paths"):
            subject.check_index(self.args)
        self.git("reset", "--quiet", "HEAD", "--", "README.md", MANIFESTS["windows"])
        with self.assertRaisesRegex(RuntimeError, "must update both manifests"):
            subject.check_index(self.args)

    def test_mismatched_lfs_pointer_is_rejected(self):
        self.stage_blob(RUNTIMES["linux"], pointer(b"different runtime"))
        with self.assertRaisesRegex(RuntimeError, "Staged LFS pointer differs"):
            subject.check_index(self.args)

    def test_symlink_publication_is_rejected(self):
        self.stage_blob(RUNTIMES["linux"], b"/somewhere/else", mode="120000")
        with self.assertRaisesRegex(RuntimeError, "not a regular stage-zero file"):
            subject.check_index(self.args)

    def test_changed_manifest_or_unvalidated_source_is_rejected(self):
        path = self.root / MANIFESTS["windows"]
        manifest = json.loads(path.read_text())
        manifest["status"] = "built-not-executed"
        path.write_text(json.dumps(manifest) + "\n", encoding="utf-8", newline="\n")
        with self.assertRaisesRegex(RuntimeError, "Staged manifest differs"):
            subject.check_index(self.args)
        self.git("add", "--", MANIFESTS["windows"])
        with self.assertRaisesRegex(RuntimeError, "stale or unvalidated"):
            subject.check_index(self.args)


if __name__ == "__main__":
    unittest.main()
