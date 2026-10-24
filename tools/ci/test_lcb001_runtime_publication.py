#!/usr/bin/env python3
"""Adversarial checks for the branch-scoped LCB-001 runtime publisher."""

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

import lcb001_runtime_publication as subject


BRANCH = "claude/issue-200-policy-foundation"
WORKFLOW = "techrote/cybersand/.github/workflows/lcb001-runtime-publication.yml@refs/heads/" + BRANCH
RUNTIMES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
MANIFESTS = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
# An independent fixture: omitting a policy, host, LCB or Water case from the
# implementation must invalidate the otherwise passing complete receipt below.
SUCCESS_LOGS = {
    "test_liquid_solver_policy": 'LIQUID_SOLVER_POLICY: 180 assertions; 0 failures; completed={"validation":true,"default_readback":true,"refusals":12,"parity_checkpoints":5,"cysd1_defaults":true}\n',
    "test_microscenarios": "MICROSCENARIOS: 300 assertions; 0 failures\n",
    "test_microscenario_controllers": "MICROSCENARIO_CONTROLLERS: 90 assertions; 0 failures\n",
    "test_lcb_physics_contracts": "LCB physics contracts: 174 assertions, 0 failures\n",
    "test_lcb_negative_contracts": "LCB negative contracts: 74 assertions, 0 failures\n",
    "test_lcb_fixture_manifests": "LCB fixture manifests: 26 assertions, 0 failures\n",
    "test_lcb_scenario_catalogue": "LCB scenario catalogue: 25 scenarios, 774 assertions, 0 failures\n",
    "test_water_feel_integration": "WATER_FEEL_INTEGRATION: 24 policy cases + 70 scenario builds/reset/invalid/actions/RG8/authority passed default_hash=123456789\n",
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
            "GITHUB_WORKFLOW_REF": WORKFLOW.replace("lcb001-runtime", "gen007-runtime"),
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


class InputLedgerTests(RepositoryFixture):
    def test_grammar_sources_examples_and_fixture_are_source_bound(self):
        native_inputs = {
            "native/include/cybersand/generation_grammar.hpp": b"// grammar interface\n",
            "native/src/generation_grammar.cpp": b"// grammar implementation\n",
            "godot/native_extension/generation_grammar_adapter.inc": b"// grammar adapter\n",
            "godot/native_extension/generation_grammar_inspection.inc": b"// grammar inspection\n",
            "godot/native_extension/generation_workbench_inspection.inc": b"// GEN-007 native replay\n",
            "godot/native_extension/generation_workbench_methods.inc": b"// GEN-007 immutable adoption and stages\n",
        }
        build_inputs = {
            "examples/worldgen/hierarchy-multi-district.json": b'{"example":"hierarchy"}\n',
            "examples/worldgen/schemas/grammar-v1.schema.json": b'{"schema":"grammar-v1"}\n',
            "godot/tests/test_worldgen_grammar.gd": b"# grammar adapter regression\n",
            "godot/tests/test_gen007_reactions.gd": b"# paired native reaction qualification\n",
            "examples/worldgen/gen007-deepworks.json": b'{"example":"GEN-007"}\n',
        }
        for relative in subject.BUILD_EXACT:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"# pinned build fixture\n")
        for relative, data in (native_inputs | build_inputs).items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Grammar input fixture")
        source = self.git("rev-parse", "HEAD").decode().strip()
        ledgers = subject.input_ledgers(source)
        self.assertEqual(ledgers["source_inputs"], {path: digest(data) for path, data in native_inputs.items()})
        for relative, data in build_inputs.items():
            self.assertEqual(ledgers["build_inputs"][relative], digest(data))
        for relative in (
            "godot/native_extension/generation_grammar_adapter.inc",
            "examples/worldgen/hierarchy-multi-district.json",
        ):
            with self.subTest(changed=relative):
                path = self.root / relative
                original = path.read_bytes()
                path.write_bytes(original + b"changed\n")
                with self.assertRaisesRegex(RuntimeError, "Working build/test input differs from source commit"):
                    subject.input_ledgers(source)
                path.write_bytes(original)


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

    def test_complete_ordered_all_retained_and_semantic_plane_cases_are_required(self):
        subject.verify_case_results(self.root, self.report)
        for omitted in SUCCESS_LOGS:
            with self.subTest(omitted=omitted):
                shortened = dict(self.report, results=[item for item in self.report["results"] if item["name"] != omitted])
                with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
                    subject.verify_case_results(self.root, shortened)
        reordered = dict(self.report, results=[self.report["results"][0], *reversed(self.report["results"][1:])])
        with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
            subject.verify_case_results(self.root, reordered)

    def test_duplicate_case_cannot_substitute_for_missing_case(self):
        self.report["results"][-1] = dict(self.report["results"][-2])
        with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
            subject.verify_case_results(self.root, self.report)

    def test_zero_failing_or_foreign_summaries_are_rejected(self):
        for output in (
            "LCB negative contracts: 0 assertions, 0 failures\n",
            "LCB negative contracts: 74 assertions, 1 failures\n",
            SUCCESS_LOGS["test_lcb_physics_contracts"],
            "Clean execution with no LCB assertions\n",
        ):
            with self.subTest(output=output):
                self.write_log("test_lcb_negative_contracts", output)
                with self.assertRaisesRegex(RuntimeError, "Missing successful assertion summary"):
                    subject.verify_case_results(self.root, self.report)

    def test_error_or_skip_log_cannot_hide_behind_a_passing_record(self):
        for suffix in ("SCRIPT ERROR: omitted native path\n", "SKIP no native policy\n"):
            with self.subTest(suffix=suffix):
                self.write_log("test_microscenarios", SUCCESS_LOGS["test_microscenarios"] + suffix)
                with self.assertRaisesRegex(RuntimeError, "Execution log contains an error or skip"):
                    subject.verify_case_results(self.root, self.report)

    def test_changed_log_bytes_are_rejected(self):
        (self.root / "test_lcb_fixture_manifests.log").write_text("changed\n", encoding="utf-8", newline="\n")
        with self.assertRaisesRegex(RuntimeError, "Execution log digest mismatch"):
            subject.verify_case_results(self.root, self.report)

    def test_liquid_policy_helper_sections_cannot_be_omitted_or_noops(self):
        name = "test_liquid_solver_policy"
        prefix, raw = SUCCESS_LOGS[name].split("completed=", 1)
        sections = json.loads(raw)
        mutations = [{key: value for key, value in sections.items() if key != omitted} for omitted in sections]
        mutations += [dict(sections, refusals=11), dict(sections, refusals=True), dict(sections, parity_checkpoints=0),
                      dict(sections, cysd1_defaults=False), dict(sections, validation=1), [], "done"]
        for value in mutations:
            with self.subTest(sections=value):
                self.write_log(name, prefix + "completed=" + json.dumps(value) + "\n")
                with self.assertRaisesRegex(RuntimeError, "Incomplete liquid-policy helper sections"):
                    subject.verify_case_results(self.root, self.report)
        for output in (SUCCESS_LOGS[name] + SUCCESS_LOGS[name], SUCCESS_LOGS[name].replace("180 assertions", "0 assertions"),
                       SUCCESS_LOGS[name].replace("0 failures", "2 failures")):
            with self.subTest(output=output):
                self.write_log(name, output)
                with self.assertRaises(RuntimeError):
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
