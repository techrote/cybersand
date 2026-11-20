#!/usr/bin/env python3
"""Fault-inject real Git publication children and synthetic runtime receipts.

These tests prove admission custody, not native execution. They reuse the
unchanged publisher's explicitly synthetic receipt/header fixture builders.
The hosted admission must independently execute the actual final Workbench.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest
from unittest import mock

import retained_runtime_admission as subject

REPO = Path(os.environ.get("GENTEK80_TEST_REPOSITORY", Path(__file__).resolve().parents[2] / "cybersand")).resolve()
sys.path.insert(0, str(REPO / "tools/ci"))
import gentek80_runtime_publication as publisher
import test_gentek80_runtime_publication as fixtures


class RetainedAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.wrapper = fixtures.Gentek80PublicationRoundtrip(methodName="runTest")
        self.wrapper.setUp()
        self.addCleanup(self.wrapper.doCleanups)
        self.fixture = self.wrapper.fixture
        self.root = self.fixture.root
        readme = self.root / "godot/native_extension/README.md"
        readme.parent.mkdir(parents=True, exist_ok=True)
        readme.write_bytes(b"Non-compilation source identity fixture\n")
        self.git("add", "godot/native_extension/README.md")
        # Add old manifests and real canonical LFS-pointer Git entries. The
        # working files remain synthetic materialized bytes, as in an LFS checkout.
        for name in subject.MANIFESTS.values():
            publisher.engine.write_json(self.root / name, {"old_fixture_provenance": True})
            self.git("add", name)
        rapier = {}
        for platform, (name, _) in publisher.engine.RAPIER.items():
            path = self.root / name
            path.write_bytes((platform + " pinned Rapier fixture\n").encode() * 8)
            rapier[platform] = (name, self.sha(path))
            self.stage_pointer(name, path.read_bytes())
        self.git("commit", "--quiet", "-m", "Retained runtime source fixture")
        self.built = self.git("rev-parse", "HEAD").decode().strip()
        self.fixture.source = self.built
        self.git("push", "--quiet", "origin", "HEAD:refs/heads/" + publisher.engine.BRANCH)
        for patch in (mock.patch.object(publisher.engine, "RAPIER", rapier),
                      mock.patch.dict(os.environ, {"GITHUB_SHA": self.built})):
            patch.start()
            self.addCleanup(patch.stop)
        # Exercise the original publisher fixture before invoking admission.
        # Its fake push environment is unit-fixture construction only; the
        # admission verifier is later forbidden to call publisher context.
        for platform, name in subject.RUNTIMES.items():
            path = self.root / name
            path.write_bytes(path.read_bytes() + ("qualified " + platform).encode())
        self.candidates = {platform: self.wrapper.candidate(platform) for platform in subject.RUNTIMES}
        for platform, args in self.candidates.items():
            self.fixture.accept(args)
            manifest = publisher.engine.manifest_path(args.bundle, platform)
            shutil.copyfile(manifest, self.root / subject.MANIFESTS[platform])
            self.git("add", subject.MANIFESTS[platform])
            self.stage_pointer(subject.RUNTIMES[platform], (self.root / subject.RUNTIMES[platform]).read_bytes())
        self.git("commit", "--quiet", "-m", "Four-file retained runtime publication fixture")
        self.refresh_final()
        patch = mock.patch.object(subject, "load_publisher", return_value=publisher)
        patch.start()
        self.addCleanup(patch.stop)

    def git(self, *arguments, input_bytes=None):
        return subprocess.check_output(["git", "-C", str(self.root), *arguments],
                                       input=input_bytes, stderr=subprocess.PIPE)

    @staticmethod
    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def stage_pointer(self, name, data):
        pointer = ("version https://git-lfs.github.com/spec/v1\noid sha256:"
                   + hashlib.sha256(data).hexdigest() + "\nsize " + str(len(data)) + "\n").encode()
        oid = self.git("hash-object", "-w", "--stdin", input_bytes=pointer).decode().strip()
        self.git("update-index", "--add", "--cacheinfo", "100644," + oid + "," + name)

    def refresh_final(self):
        self.published = self.git("rev-parse", "HEAD").decode().strip()
        self.tree = self.git("rev-parse", "HEAD^{tree}").decode().strip()

    def amend(self, names):
        self.git("add", *names)
        self.git("commit", "--amend", "--no-edit", "--quiet")
        self.refresh_final()

    def verify(self, platform="linux", **overrides):
        arguments = dict(candidate=self.root, bundle=self.candidates[platform].bundle, platform=platform,
                         built_source=self.built, published_source=self.published, published_tree=self.tree,
                         run_id="123456", run_attempt="1")
        arguments.update(overrides)
        # The final helper must never impersonate a source-build context.
        with mock.patch.object(subject.sys, "platform", "win32" if platform == "windows" else "linux"), \
             mock.patch.object(publisher.engine, "context", side_effect=AssertionError("forged build context")), \
             mock.patch.object(publisher.engine, "verify_bundle", side_effect=AssertionError("source-build bundle verifier")):
            return subject.verify(**arguments)

    def fresh(self, platform="linux"):
        output = self.fixture.directory / ("final-workbench-" + platform)
        output.mkdir(exist_ok=True)
        bundle = self.candidates[platform].bundle
        manifest = publisher.read_json(publisher.engine.manifest_path(bundle, platform))
        original = publisher.read_json(bundle / publisher.RECEIPTS["workbench"])
        value = copy.deepcopy(original)
        value.update(source_commit=self.published, source_tree=self.tree)
        for index, phase in enumerate(("author", "reopen")):
            value[phase].update(source_commit=self.published, process_id=900 + index)
        for row in value["results"][:-1]:
            name = row["case"]
            row["command"] = ["fixture-Godot", "--path", str(self.root / "godot")]
            row["command"] += ["--headless", "--editor", "--quit"] if name == "import" else [
                "--rendering-method", "gl_compatibility", "--script", "res://tools/qualify_gentek80_workbench.gd"]
            log = output / (name + ".log")
            log.write_text("synthetic final Workbench execution fixture " + name + "\n")
            row["log_sha256"] = self.sha(log)
            publisher.engine.write_json(output / (name + "-process.json"), row)
            if name != "import":
                publisher.engine.write_json(output / ("gentek80-workbench-" + name + ".json"), value[name])
        publisher.engine.write_json(output / "qualification.json", value)
        scripts = {path.relative_to(self.root / "godot").as_posix(): self.sha(path)
                   for path in (self.root / "godot").rglob("*.gd")}
        identity = {"source_commit": self.published, "source_tree": self.tree,
                    "runtime_sha256": manifest["sha256"], "runtime_bytes": manifest["size"],
                    "source_inputs_sha256": {path.relative_to(self.root).as_posix(): self.sha(path)
                        for directory in ("native/include", "native/src", "godot/native_extension")
                        for path in (self.root / directory).rglob("*") if path.is_file()},
                    "project_scripts_sha256": scripts}
        publisher.engine.write_json(output / "source-runtime-identity.json", identity)
        return output

    def test_both_platforms_preserve_built_and_published_identity_without_forging_context(self):
        environment = dict(os.environ)
        for platform in subject.RUNTIMES:
            with self.subTest(platform=platform):
                result = self.verify(platform)
                self.assertEqual(result["status"], "passed")
                self.assertEqual(result["built"]["source_commit"], self.built)
                self.assertEqual(result["published"]["source_commit"], self.published)
                self.assertIsNone(result["executed"])
                self.assertEqual(result["scope"], "retained-runtime-custody-only")
                self.assertEqual(set(result["published"]["changed_paths"]), subject.PUBLICATION_PATHS)
        self.assertEqual(dict(os.environ), environment)

    def test_wrong_head_tree_parent_run_or_attempt_is_rejected(self):
        for change in ({"published_source": self.built}, {"published_tree": "e" * 40},
                       {"built_source": "f" * 40}, {"run_id": "9999"}, {"run_attempt": "2"}):
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                self.verify(**change)

    def test_merge_parent_is_rejected(self):
        ancestor = self.git("rev-parse", self.built + "^").decode().strip()
        merge = self.git("commit-tree", self.tree, "-p", self.built, "-p", ancestor,
                         input_bytes=b"synthetic merge child\n").decode().strip()
        self.git("update-ref", "HEAD", merge)
        self.refresh_final()
        with self.assertRaisesRegex(RuntimeError, "sole built-source parent"):
            self.verify()

    def test_extra_publication_path_is_rejected(self):
        (self.root / "unrelated.txt").write_text("unexpected source change\n")
        self.amend(["unrelated.txt"])
        with self.assertRaisesRegex(RuntimeError, "exactly the four"):
            self.verify()

    def test_executable_publication_pointer_is_rejected(self):
        self.git("update-index", "--chmod=+x", subject.RUNTIMES["linux"])
        self.git("commit", "--amend", "--no-edit", "--quiet")
        self.refresh_final()
        with self.assertRaisesRegex(RuntimeError, "regular non-executable"):
            self.verify()

    def test_hidden_native_and_validator_byte_changes_are_rejected(self):
        manifest = publisher.read_json(publisher.engine.manifest_path(self.candidates["linux"].bundle, "linux"))
        for name in (next(iter(manifest["source_inputs"])), "tools/ci/gentek80_runtime_publication.py",
                     "godot/native_extension/README.md"):
            with self.subTest(path=name):
                path, original = self.root / name, (self.root / name).read_bytes()
                self.git("update-index", "--assume-unchanged", name)
                try:
                    path.write_bytes(b"hidden uncommitted input\n")
                    with self.assertRaisesRegex(RuntimeError, "[Ww]orking .*input differs"):
                        self.verify()
                finally:
                    path.write_bytes(original)
                    self.git("update-index", "--no-assume-unchanged", name)

    def test_untracked_godot_source_is_rejected(self):
        path = self.root / "godot/scripts/untracked.gd"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("extends Node\n")
        with self.assertRaisesRegex(RuntimeError, "Untracked or missing Godot"):
            self.verify()

    def test_staged_source_change_is_rejected(self):
        name = "tools/ci/gentek80_runtime_publication.py"
        original = (self.root / name).read_bytes()
        (self.root / name).write_text("staged different input\n")
        self.git("add", name)
        (self.root / name).write_bytes(original)
        with self.assertRaisesRegex(RuntimeError, "index differs"):
            self.verify()

    def test_materialized_pointer_runtime_and_rapier_mismatches_are_rejected(self):
        for name in (subject.RUNTIMES["linux"], publisher.engine.RAPIER["linux"][0]):
            with self.subTest(path=name):
                path, original = self.root / name, (self.root / name).read_bytes()
                try:
                    path.write_bytes(b"version https://git-lfs.github.com/spec/v1\n" + b"x" * 200)
                    with self.assertRaises(RuntimeError):
                        self.verify()
                finally:
                    path.write_bytes(original)

    def test_non_target_pointer_provenance_is_also_checked(self):
        path = subject.MANIFESTS["windows"]
        value = publisher.read_json(self.root / path)
        value["sha256"] = "e" * 64
        publisher.engine.write_json(self.root / path, value)
        self.amend([path])
        with self.assertRaisesRegex(RuntimeError, "provenance mismatch for windows: sha256"):
            self.verify()

    def test_bundle_manifest_must_byte_match_committed_original(self):
        path = publisher.engine.manifest_path(self.candidates["linux"].bundle, "linux")
        path.write_bytes(path.read_bytes() + b"\n")
        with self.assertRaisesRegex(RuntimeError, "bundle manifest differs"):
            self.verify()

    def test_missing_stale_and_rehashed_original_evidence_is_rejected(self):
        bundle = self.candidates["linux"].bundle
        receipt = bundle / publisher.RECEIPTS["workbench"]
        original = receipt.read_bytes()
        for mutation in (None, original + b"\n"):
            with self.subTest(mutation=mutation is None):
                if mutation is None:
                    receipt.unlink()
                else:
                    receipt.write_bytes(mutation)
                with self.assertRaisesRegex(RuntimeError, "receipt missing or modified"):
                    self.verify()
                receipt.write_bytes(original)
        report_path = bundle / "validation.json"
        report = publisher.read_json(report_path)
        report["source_commit"] = self.published
        publisher.engine.write_json(report_path, report)
        with self.assertRaisesRegex(RuntimeError, "report hash mismatch"):
            self.verify()

    def test_rehashed_report_cannot_relabel_source_or_reduce_execution_scope(self):
        bundle = self.candidates["linux"].bundle
        report_path = bundle / "validation.json"
        report = publisher.read_json(report_path)
        report["scope"] = "catalogue count only"
        publisher.engine.write_json(report_path, report)
        path = publisher.engine.manifest_path(bundle, "linux")
        manifest = publisher.read_json(path)
        manifest["validation_sha256"] = self.sha(report_path)
        publisher.engine.write_json(path, manifest)
        shutil.copyfile(path, self.root / subject.MANIFESTS["linux"])
        self.amend([subject.MANIFESTS["linux"]])
        with self.assertRaisesRegex(RuntimeError, "acceptance scope was altered"):
            self.verify()

    def test_fresh_final_workbench_joins_all80_outputs_to_original_on_both_platforms(self):
        for platform in subject.RUNTIMES:
            with self.subTest(platform=platform):
                result = self.verify(platform, workbench=self.fresh(platform))
                self.assertEqual(result["executed"]["source_commit"], self.published)
                self.assertEqual(result["scope"], "retained-runtime-and-final-head-workbench")
                self.assertEqual(result["final_workbench"]["styles"], 80)
                self.assertEqual([row["styles"] for row in result["final_workbench"]["original_output_matches"]], [80, 80])

    def test_full_workbench_identity_keeps_non_compilation_files_and_actual_orchestration_sha(self):
        output = self.fresh()
        with mock.patch.dict(os.environ, {"GITHUB_SHA": "e" * 40}):
            result = self.verify(workbench=output)
        name = "godot/native_extension/README.md"
        self.assertNotIn(name, result["input_ledgers"]["source_inputs"])
        self.assertEqual(result["source_identity_inputs_sha256"][name], self.sha(self.root / name))
        self.assertEqual(len(result["source_identity_inputs_sha256"]), len(result["input_ledgers"]["source_inputs"]) + 1)
        self.assertEqual(result["admission_workflow"]["GITHUB_SHA"], "e" * 40)
        self.assertNotEqual(result["admission_workflow"]["GITHUB_SHA"], result["executed"]["source_commit"])

    def test_fresh_source_tree_runtime_platform_and_identity_errors_are_rejected(self):
        output = self.fresh()
        report_path, identity_path = output / "qualification.json", output / "source-runtime-identity.json"
        original_report, original_identity = report_path.read_bytes(), identity_path.read_bytes()
        changes = [("report", "source_commit", self.built), ("report", "source_tree", "e" * 40),
                   ("report", "runtime_sha256", "e" * 64), ("report", "platform", "windows"),
                   ("identity", "source_commit", self.built), ("identity", "source_tree", "e" * 40),
                   ("identity", "runtime_sha256", "e" * 64), ("identity", "source_inputs_sha256", {}),
                   ("identity", "project_scripts_sha256", {})]
        for kind, key, value in changes:
            with self.subTest(kind=kind, field=key):
                path = report_path if kind == "report" else identity_path
                data = publisher.read_json(path)
                data[key] = value
                publisher.engine.write_json(path, data)
                with self.assertRaises(RuntimeError):
                    self.verify(workbench=output)
                report_path.write_bytes(original_report)
                identity_path.write_bytes(original_identity)

    def test_fresh_logs_and_material_recipe_join_cannot_be_relabelled(self):
        output = self.fresh()
        log = output / "author.log"
        original = log.read_bytes()
        log.write_bytes(original + b"changed process log\n")
        with self.assertRaisesRegex(RuntimeError, "process log is missing or changed"):
            self.verify(workbench=output)
        log.write_bytes(original)
        path = output / "qualification.json"
        report = publisher.read_json(path)
        for phase in ("author", "reopen"):
            report[phase]["cases"][0]["source_sha256"] = "e" * 64
            publisher.engine.write_json(output / ("gentek80-workbench-" + phase + ".json"), report[phase])
        publisher.engine.write_json(path, report)
        with self.assertRaisesRegex(RuntimeError, "differs from qualified build"):
            self.verify(workbench=output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
