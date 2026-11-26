#!/usr/bin/env python3
"""Container/custody controls; no synthetic fixture is a qualified evaluator."""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import types
import unittest
from unittest import mock
import zipfile

import strata3_package_portable_verify as package

SOURCE_REPO: Path | None = None


class ContainerControls(unittest.TestCase):
    def archive(self, root, extras=None):
        archive = root / "synthetic-container-only.zip"
        manifest = json.dumps({"scope": "container-test-only"}).encode()
        with zipfile.ZipFile(archive, "w") as output:
            output.writestr(package.MANIFEST, manifest)
            for name, data in extras or [("safe/item.txt", b"original")]:
                output.writestr(name, data)
        return archive, package.file_sha(archive), hashlib.sha256(manifest).hexdigest()

    def test_container_bytes_and_absent_extraction(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, digest, manifest_digest = self.archive(root)
            _, files, _ = package.inspect_archive(archive, digest, manifest_digest)
            folder = root / "new extraction"
            package.extract_original(archive, folder, files)
            self.assertEqual(package.snapshot(folder), files)
            with self.assertRaisesRegex(ValueError, "absent extraction"):
                package.extract_original(archive, folder, files)

    def test_changed_zip_and_manifest_digest_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive, digest, manifest_digest = self.archive(Path(temporary))
            with self.assertRaisesRegex(ValueError, "ZIP identity differs"):
                package.inspect_archive(archive, "a" * 64, manifest_digest)
            with self.assertRaisesRegex(ValueError, "manifest identity differs"):
                package.inspect_archive(archive, digest, "a" * 64)

    def test_unsafe_paths_and_windows_ambiguity_refused(self):
        for name in ("/root", "../other", "a/../other", "a//b", "C:/absolute", "a\\b", "a/NUL.txt",
                     "a/name.", "a/name ", "a/name\x00rest", "a/COM1.txt"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.archive_member_name(name)

    def test_raw_zip_nul_and_backslash_refused(self):
        for replacement in (b"safe\x00item.txt", b"safe\\item.txt"):
            with self.subTest(replacement=replacement), tempfile.TemporaryDirectory() as temporary:
                archive, _, manifest_digest = self.archive(Path(temporary))
                archive.write_bytes(archive.read_bytes().replace(b"safe/item.txt", replacement))
                with self.assertRaises(ValueError):
                    package.inspect_archive(archive, package.file_sha(archive), manifest_digest)

    def test_case_colliding_names_and_symlink_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, digest, manifest_digest = self.archive(root, [("safe/A", b"a"), ("safe/a", b"b")])
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                package.inspect_archive(archive, digest, manifest_digest)
            archive, _, manifest_digest = self.archive(root)
            with zipfile.ZipFile(archive, "a") as output:
                item = zipfile.ZipInfo("linked")
                item.create_system = 3
                item.external_attr = (stat.S_IFLNK | 0o777) << 16
                output.writestr(item, "outside")
            with self.assertRaisesRegex(ValueError, "non-file"):
                package.inspect_archive(archive, package.file_sha(archive), manifest_digest)


class UnchangedVerifierBoundary(unittest.TestCase):
    def package(self, original, later_gate=None):
        module = types.SimpleNamespace(predecessor=types.SimpleNamespace(verify=original))
        def verify(folder, *, pristine):
            self.assertTrue(pristine)
            result = module.predecessor.verify(folder)
            if later_gate:
                later_gate()
            return result
        module.verify = verify
        return module

    def test_unexpected_original_gate_failure_is_not_relabelled(self):
        def original(_):
            raise RuntimeError("Changed packaged file: native.dll")
        module = self.package(original)
        calls = []
        with self.assertRaisesRegex(ValueError, "outside the registered path limitation"):
            package.invoke_frozen_package(module, lambda folder: calls.append(folder), Path("fixture"))
        self.assertEqual(calls, [])
        self.assertIs(module.predecessor.verify, original)

    def test_later_frozen_gate_refuses_and_original_function_is_restored(self):
        def original(_):
            raise RuntimeError(package.EXPECTED_PATH_REFUSAL)
        def reject():
            raise RuntimeError("Gallery receipt differs")
        module = self.package(original, reject)
        with self.assertRaisesRegex(RuntimeError, "Gallery receipt differs"):
            package.invoke_frozen_package(module, lambda _: {"synthetic": True}, Path("fixture"))
        self.assertIs(module.predecessor.verify, original)

    def test_original_success_requires_identical_manifest(self):
        original = lambda _: {"identity": "original"}
        module = self.package(original)
        with self.assertRaisesRegex(ValueError, "manifests disagree"):
            package.invoke_frozen_package(module, lambda _: {"identity": "different"}, Path("fixture"))
        self.assertIs(module.predecessor.verify, original)

    def test_frozen_package_modules_load_from_exact_application(self):
        if SOURCE_REPO is None:
            self.skipTest("Supply --source-repo for frozen source loading control")
        module, _, identity, inputs = package.load_package_reader(SOURCE_REPO)
        self.assertEqual(module.ROOT, SOURCE_REPO.resolve())
        self.assertEqual(identity["application_source"], package.paired.APPLICATION)
        self.assertIn(package.PACKAGE_READER, inputs)
        self.assertEqual(package.frozen_module_inputs(SOURCE_REPO.resolve(), module), inputs)

    def test_cli_receipt_cannot_overwrite_payload_or_frozen_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, extraction = root / "frozen source", root / "new extraction"
            source.mkdir()
            for output in (extraction / package.MANIFEST, source / "new-receipt.json"):
                arguments = ["portable-package", "--source-repo", str(source), "--archive", str(root / "not-used.zip"),
                             "--archive-sha256", "a" * 64, "--manifest-sha256", "b" * 64,
                             "--extract-to", str(extraction), "--output", str(output)]
                with self.subTest(output=output), mock.patch.object(sys, "argv", arguments), \
                     mock.patch.object(package, "verify_package") as verify, contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(package.main(), 1)
                    verify.assert_not_called()
                self.assertFalse(output.exists())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source-repo", type=Path)
    args, remaining = parser.parse_known_args()
    SOURCE_REPO = args.source_repo
    unittest.main(argv=[sys.argv[0], *remaining])
