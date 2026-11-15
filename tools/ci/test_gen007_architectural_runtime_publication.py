#!/usr/bin/env python3
"""Fail-closed contract checks for the GEN-007 native publisher."""
import argparse
import copy
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest import mock
import gen007_architectural_runtime_publication as subject

def architecture(owner=False):
    phases = subject.OWNER_PHASES if owner else subject.FULL_PHASES
    rows = []
    for phase in phases:
        item = {"case": phase, "passed": True}
        if phase in subject.COUNTS:
            item["completion"] = [subject.COUNTS[phase]]
        if phase == "ui":
            item["completion"] = ["ARCHITECTURAL_UI checks=56 failures=0"]
        rows.append(item)
    return {"schema": 1, "passed": True, "failures": 0,
            "graphical_requested": True, "source_commit": "a"*40,
            "runtime_sha256": "b"*64, "cases": rows}

class Gen007PublicationGuards(unittest.TestCase):
    def test_scope_and_branch(self):
        self.assertEqual(subject.engine.BRANCH, "feat/gen007-architectural-generator-ab")
        self.assertEqual(subject.engine.WORKFLOW, ".github/workflows/architectural-generator-qualification.yml")
        self.assertEqual(subject.engine.REQUEST_VALUE["intent"], "publish-source-matched-runtimes")
        self.assertIn("tools/ci/gen007_architectural_runtime_publication.py", subject.engine.BUILD_EXACT)

    def test_full_and_package_campaigns_are_distinct(self):
        subject.validate_architecture(architecture(), "a"*40, "b"*64)
        subject.validate_architecture(architecture(True), "a"*40, "b"*64, owner=True)
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(architecture(True), "a"*40, "b"*64)

    def test_missing_fifth_card_and_multistyle_reopen_rejected(self):
        candidate = architecture()
        candidate["cases"][3]["completion"] = ["ARCHITECTURAL_UI checks=55 failures=0"]
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "b"*64)
        candidate = architecture()
        candidate["cases"] = [c for c in candidate["cases"] if c["case"] != "multistyle-reopen"]
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "b"*64)

    def test_stale_binary_or_headless_rejected(self):
        candidate = architecture()
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "c"*64)
        candidate["graphical_requested"] = False
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "b"*64)

    def test_flatten_failure_and_wrong_cases_rejected(self):
        good = {"status":"passed", "graphical":True, "cases":[[512,1]],
                "storage_faults":{"status":"passed"}}
        subject.validate_flatten(good)
        for changes in ({"graphical":False}, {"cases":[[1024,1]]},
                        {"storage_faults":{"status":"failed"}}, {"status":"running"}):
            case = copy.deepcopy(good)
            case.update(changes)
            with self.assertRaises(RuntimeError):
                subject.validate_flatten(case)

    def test_changed_source_input_and_tree_rejected(self):
        original = {"source_commit":"a"*40, "source_tree":"d"*40,
                    "runtime_sha256":"b"*64,
                    "source_inputs_sha256":{"native/src/one.cpp":"c"*64}}
        subject.validate_source(original, "a"*40, "b"*64, "d"*40,
                                {"native/src/one.cpp":"c"*64})
        for changes in ({"source_tree":"e"*40}, {"runtime_sha256":"e"*64},
                        {"source_inputs_sha256":{}}):
            case = dict(original, **changes)
            with self.assertRaises(RuntimeError):
                subject.validate_source(case, "a"*40, "b"*64, "d"*40,
                                        {"native/src/one.cpp":"c"*64})


class NativeSourceLineEndings(unittest.TestCase):
    def test_windows_checkout_preserves_raw_hash_for_every_native_suffix(self):
        attributes = (subject.engine.ROOT / ".gitattributes").read_bytes()
        suffixes = (".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx",
                    ".inc", ".inl", ".tpp")
        original = b"// native source fixture\nint source_value = 1;\n"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*args):
                return subprocess.check_output(["git", "-C", str(root), *args],
                                               stderr=subprocess.PIPE)

            git("init", "--quiet")
            git("config", "user.name", "GEN-007 checkout fixture")
            git("config", "user.email", "gen007-fixture@example.invalid")
            git("config", "commit.gpgsign", "false")
            git("config", "core.autocrlf", "false")
            (root / ".gitattributes").write_bytes(attributes)
            (root / "native/src").mkdir(parents=True)
            paths = ["native/src/fixture" + suffix for suffix in suffixes]
            for name in [*paths, "conversion-control.txt"]:
                (root / name).write_bytes(original)
            git("add", ".")
            git("commit", "--quiet", "-m", "Canonical native source bytes")
            git("config", "core.autocrlf", "true")
            for name in [*paths, "conversion-control.txt"]:
                (root / name).unlink()
            git("checkout-index", "--force", "--", *paths, "conversion-control.txt")
            # Confirm this is a Windows-style converting checkout. The source
            # pins, rather than a disabled conversion setting, must preserve LF.
            self.assertEqual((root / "conversion-control.txt").read_bytes(),
                             original.replace(b"\n", b"\r\n"))
            for name in paths:
                with self.subTest(source=name):
                    self.assertEqual(git("show", "HEAD:" + name), original)
                    self.assertEqual(hashlib.sha256((root / name).read_bytes()).hexdigest(),
                                     hashlib.sha256(original).hexdigest())


class PublicationRoundtrip(unittest.TestCase):
    """Exercise the real record/accept/verify/stage path, not isolated validators.

    A local Git source and branch lease are real. Runtime headers and pinned
    dependency bytes are deliberately tiny fixtures: this verifies publication
    custody, not native execution (which remains the hosted campaign's job).
    """

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.root = self.directory / "source"
        self.root.mkdir()
        self.git("init", "--quiet")
        self.git("config", "user.name", "GEN-007 publisher fixture")
        self.git("config", "user.email", "gen007-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.autocrlf", "false")
        paths = set(subject.engine.BUILD_EXACT) | {
            subject.engine.EVIDENCE, subject.engine.REQUEST,
            "native/src/generation_architecture_modules.inc",
            *["godot/tests/" + name + ".gd" for name in subject.engine.CASE_MARKERS],
        }
        for relative in paths:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"# pinned source fixture\n")
        subject.engine.write_json(self.root / subject.engine.REQUEST,
                                  dict(subject.engine.REQUEST_VALUE, request_sequence=1))
        rapier = {}
        for platform, relative in subject.engine.RUNTIMES.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            data = bytearray(256)
            if platform == "linux":
                data[:6] = b"\x7fELF\x02\x01"
                data[16:20] = b"\x03\x00\x3e\x00"
            else:
                data[:2] = b"MZ"
                struct.pack_into("<I", data, 0x3c, 0x80)
                data[0x80:0x86] = b"PE\x00\x00\x64\x86"
                struct.pack_into("<H", data, 0x80 + 22, 0x2000)
                data[0x80 + 24:0x80 + 26] = b"\x0b\x02"
            path.write_bytes(data)
            dependency = self.root / subject.engine.RAPIER[platform][0]
            dependency.parent.mkdir(parents=True, exist_ok=True)
            dependency.write_bytes((platform + " pinned Rapier fixture").encode())
            rapier[platform] = (subject.engine.RAPIER[platform][0],
                                subject.engine.runner.sha256(dependency))
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Exact GEN-007 source fixture")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        remote = self.directory / "remote.git"
        subprocess.run(["git", "init", "--bare", "--quiet", str(remote)], check=True)
        self.git("remote", "add", "origin", str(remote))
        self.git("push", "--quiet", "origin", "HEAD:refs/heads/" + subject.engine.BRANCH)
        self.archive = self.directory / "godot.zip"
        self.archive.write_bytes(b"pinned engine archive fixture")
        self.toolchain = self.directory / "toolchain.txt"
        self.toolchain.write_text("Pinned compiler fixture\n", encoding="utf-8")
        patches = [
            mock.patch.object(subject.engine, "ROOT", self.root),
            mock.patch.object(subject.engine, "RAPIER", rapier),
            mock.patch.object(subject.engine, "GODOT_LINUX_SHA256",
                              subject.engine.runner.sha256(self.archive)),
            mock.patch.object(subject.engine.windows, "GODOT_SHA512",
                              hashlib.sha512(self.archive.read_bytes()).hexdigest()),
            mock.patch.dict(os.environ, {
                "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
                "GITHUB_REF": "refs/heads/" + subject.engine.BRANCH,
                "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + subject.engine.WORKFLOW
                                       + "@refs/heads/" + subject.engine.BRANCH,
                "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
            }),
        ]
        for patch in patches:
            patch.start()
            self.addCleanup(patch.stop)

    def git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.root), *arguments],
                                       stderr=subprocess.PIPE)

    def candidate(self, platform):
        directory = self.directory / platform
        directory.mkdir()
        args = argparse.Namespace(
            source_sha=self.source, platform=platform, bundle=directory / "bundle",
            runtime=self.root / subject.engine.RUNTIMES[platform], toolchain=self.toolchain,
            godot_archive=self.archive, qualification=directory / "architecture",
            flatten=directory / "flatten", package=directory / "package",
            package_flatten=directory / "package-flatten")
        subject.engine.record_build(args)
        manifest = subject.read_json(subject.engine.manifest_path(args.bundle, platform))
        for path in (args.qualification, args.flatten, args.package, args.package_flatten):
            path.mkdir()
        for path, owner in ((args.qualification, False), (args.package, True)):
            value = architecture(owner)
            value.update(source_commit=self.source, runtime_sha256=manifest["sha256"])
            subject.engine.write_json(path / "qualification.json", value)
        identity = {"source_commit": self.source, "source_tree": manifest["source_tree"],
                    "runtime_sha256": manifest["sha256"],
                    "source_inputs_sha256": manifest["source_inputs"]}
        subject.engine.write_json(args.qualification / "source-runtime-identity.json", identity)
        flatten = {"status": "passed", "graphical": True, "cases": [[512, 1]],
                   "storage_faults": {"status": "passed"}}
        for path in (args.flatten, args.package_flatten):
            subject.engine.write_json(path / "qualification.json", flatten)
        return args

    def accept(self, args):
        with mock.patch.object(subject.sys, "platform", "win32" if args.platform == "windows" else "linux"):
            subject.accept(args)
        return subject.engine.verify_bundle(args.bundle, args.platform, self.source, validated=True)

    def reseal_report(self, args, report):
        subject.engine.write_json(args.bundle / "validation.json", report)
        manifest_path = subject.engine.manifest_path(args.bundle, args.platform)
        manifest = subject.read_json(manifest_path)
        manifest["validation_sha256"] = subject.engine.runner.sha256(args.bundle / "validation.json")
        subject.engine.write_json(manifest_path, manifest)

    def test_both_platforms_accept_verify_and_stage_exact_build(self):
        candidates = {platform: self.candidate(platform) for platform in ("linux", "windows")}
        for platform, args in candidates.items():
            with self.subTest(platform=platform):
                manifest = self.accept(args)
                report = subject.read_json(args.bundle / "validation.json")
                self.assertEqual(report["source_inputs"], manifest["source_inputs"])
                self.assertEqual(report["source_tree"], manifest["source_tree"])
                self.assertEqual(manifest["status"], "validated-development-runtime")
                self.assertEqual(set(report["receipts"]),
                                 {"architecture", "identity", "flatten", "package", "package_flatten"}
                                 if platform == "windows" else {"architecture", "identity", "flatten"})
        subject.engine.stage(argparse.Namespace(source_sha=self.source,
                             linux_bundle=candidates["linux"].bundle,
                             windows_bundle=candidates["windows"].bundle))
        for platform, args in candidates.items():
            self.assertEqual((self.root / subject.engine.MANIFESTS[platform]).read_bytes(),
                             subject.engine.manifest_path(args.bundle, platform).read_bytes())
            self.assertEqual((self.root / subject.engine.RUNTIMES[platform]).read_bytes(),
                             (args.bundle / Path(subject.engine.RUNTIMES[platform]).name).read_bytes())

    def test_missing_or_substituted_report_ledger_is_rejected_after_rehash(self):
        args = self.candidate("linux")
        self.accept(args)
        original = subject.read_json(args.bundle / "validation.json")
        for replacement in (None, {}, {"native/src/other.cpp": "f" * 64}):
            with self.subTest(source_inputs=replacement):
                report = copy.deepcopy(original)
                if replacement is None:
                    del report["source_inputs"]
                else:
                    report["source_inputs"] = replacement
                self.reseal_report(args, report)
                with self.assertRaisesRegex(RuntimeError, "source tree/input ledger"):
                    subject.engine.verify_bundle(args.bundle, "linux", self.source, validated=True)

    def test_substituted_report_tree_is_rejected_after_rehash(self):
        args = self.candidate("linux")
        self.accept(args)
        report = subject.read_json(args.bundle / "validation.json")
        report["source_tree"] = "f" * 40
        self.reseal_report(args, report)
        with self.assertRaisesRegex(RuntimeError, "source tree/input ledger"):
            subject.engine.verify_bundle(args.bundle, "linux", self.source, validated=True)

    def test_stale_qualification_runtime_never_receives_validated_manifest(self):
        args = self.candidate("linux")
        path = args.qualification / "qualification.json"
        receipt = subject.read_json(path)
        receipt["runtime_sha256"] = "f" * 64
        subject.engine.write_json(path, receipt)
        with self.assertRaisesRegex(RuntimeError, "source/runtime matched"):
            self.accept(args)
        manifest = subject.read_json(subject.engine.manifest_path(args.bundle, "linux"))
        self.assertEqual(manifest["status"], "built-not-executed")
        self.assertFalse((args.bundle / "validation.json").exists())

    def test_windows_owner_receipt_cannot_be_replaced_by_full_campaign(self):
        args = self.candidate("windows")
        (args.package / "qualification.json").write_bytes(
            (args.qualification / "qualification.json").read_bytes())
        with self.assertRaisesRegex(RuntimeError, "phase missing/failed"):
            self.accept(args)
        manifest = subject.read_json(subject.engine.manifest_path(args.bundle, "windows"))
        self.assertEqual(manifest["status"], "built-not-executed")

if __name__ == "__main__":
    unittest.main()
