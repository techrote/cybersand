#!/usr/bin/env python3
"""Adversarial source/artifact join checks; synthetic bytes are never a runtime gate."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import restore_workbench_godot as engine


class EngineIdentity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.payload = self.root / "payload"
        self.output = self.root / "extracted"
        self.archive = self.root / "engine.zip"
        for folder in (self.source / "third_party/patches", self.source / "tools/ci", self.payload / "bin"):
            folder.mkdir(parents=True)
        self.patch_path = self.source / "third_party/patches/context.patch"
        self.patch_path.write_bytes(b"reviewed synthetic patch\n")
        self.builder = self.source / "tools/ci/build_workbench_godot.py"
        self.builder.write_bytes(b"# synthetic fixture, not an engine build\n")
        self.build = {"source_commit": "a" * 40, "version": "4.7.stable.fixture",
                      "output_gui": "fixture.exe", "output_console": "fixture.console.exe",
                      "scope": {"synthetic_test": True},
                      "patches": [{"path": "third_party/patches/context.patch", "sha256": engine.digest(self.patch_path)}]}
        self.build_path = self.source / "third_party/workbench-godot.lock.json"
        self.write(self.build_path, self.build)
        for name in ("fixture.exe", "fixture.console.exe"):
            (self.payload / "bin" / name).write_bytes(b"synthetic executable-shaped fixture; not executable\n")
        self.api = {"api_equal_except_declared_build_labels": True, "interface_bytes_equal": True,
                    "ignored_header_fields": ["version_build", "version_full_name"]}
        self.write(self.payload / "api-equivalence.json", self.api)
        self.proof = {"schema": "workbench-godot-build-provenance-v1", "complete": True,
                      "custom_engine": True, "public_api_equivalent": True,
                      "upstream_commit": self.build["source_commit"], "version": self.build["version"],
                      "patches": self.build["patches"], "scope": self.build["scope"],
                      "application_source": "b" * 40, "workflow_run": "123",
                      "lock": self.record(self.build_path), "builder": self.record(self.builder),
                      "gui_executable": "bin/fixture.exe", "console_executable": "bin/fixture.console.exe",
                      "executables": {name: {**self.record(self.payload / "bin" / name),
                          "pe": {"unresolved_non_system_imports": []}}
                          for name in ("fixture.exe", "fixture.console.exe")}}
        self.delivery = {"schema": "workbench-godot-evaluation-lock-v1", "repository": "techrote/cybersand",
                         "artifact_id": 456, "workflow_run": 123, "application_source": "b" * 40}
        self.rebind_fixture()
        self.root_patch = patch.object(engine, "ROOT", self.source)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    @staticmethod
    def write(path, value):
        path.write_text(json.dumps(value, sort_keys=True) + "\n")

    @staticmethod
    def record(path):
        return {"sha256": engine.digest(path), "bytes": path.stat().st_size}

    def rebind_fixture(self, members=None):
        self.proof["payload_files"] = {p.relative_to(self.payload).as_posix(): self.record(p)
            for p in self.payload.rglob("*") if p.is_file() and p.name != "build-provenance.json"}
        proof_path = self.payload / "build-provenance.json"
        self.write(proof_path, self.proof)
        self.delivery["build_provenance_sha256"] = engine.digest(proof_path)
        with zipfile.ZipFile(self.archive, "w") as archive:
            if members is None:
                for p in self.payload.rglob("*"):
                    if p.is_file():
                        archive.write(p, p.relative_to(self.payload).as_posix())
            else:
                for name, data in members:
                    # A string passed to writestr is normalized by ZipInfo on
                    # Windows. Emit the actual adversarial archive spelling.
                    member = zipfile.ZipInfo()
                    member.filename = member.orig_filename = name
                    archive.writestr(member, data)
        self.delivery["artifact_sha256"] = engine.digest(self.archive)
        self.write(self.source / "third_party/workbench-godot-evaluation.lock.json", self.delivery)

    def test_consistent_fixture_restores(self):
        result = engine.restore(self.archive, self.output)
        self.assertEqual(result["version"], self.build["version"])
        self.assertEqual(engine.verify_payload(self.output), self.proof)

    def test_archive_tamper_is_rejected_before_extraction(self):
        with self.archive.open("ab") as stream:
            stream.write(b"modified")
        with self.assertRaisesRegex(RuntimeError, "archive digest"):
            engine.restore(self.archive, self.output)
        self.assertFalse(self.output.exists())

    def test_payload_binary_tamper(self):
        (self.payload / "bin/fixture.exe").write_bytes(b"different binary")
        with self.assertRaisesRegex(RuntimeError, "payload drift"):
            engine.verify_payload(self.payload)

    def test_extra_payload_file(self):
        (self.payload / "unexpected.dll").write_bytes(b"extra")
        with self.assertRaisesRegex(RuntimeError, "Unexpected or missing"):
            engine.verify_payload(self.payload)

    def test_changed_current_builder(self):
        self.builder.write_bytes(b"changed builder")
        with self.assertRaisesRegex(RuntimeError, "build input differs"):
            engine.verify_payload(self.payload)

    def test_changed_current_patch(self):
        self.patch_path.write_bytes(b"unreviewed patch")
        with self.assertRaisesRegex(RuntimeError, "patch drift"):
            engine.verify_payload(self.payload)

    def test_incomplete_or_different_api_receipt(self):
        for field in ("complete", "public_api_equivalent", "custom_engine"):
            with self.subTest(field=field):
                self.proof[field] = False
                self.rebind_fixture()
                with self.assertRaisesRegex(RuntimeError, "Incomplete"):
                    engine.verify_payload(self.payload)
                self.proof[field] = True

    def test_wrong_workflow_source(self):
        self.proof["application_source"] = "c" * 40
        self.rebind_fixture()
        with self.assertRaisesRegex(RuntimeError, "build/run identity"):
            engine.verify_payload(self.payload)

    def test_undeclared_api_normalization(self):
        changed = copy.deepcopy(self.api)
        changed["ignored_header_fields"].append("classes")
        self.write(self.payload / "api-equivalence.json", changed)
        self.rebind_fixture()
        with self.assertRaisesRegex(RuntimeError, "API equivalence"):
            engine.verify_payload(self.payload)

    def test_unresolved_runtime_dependency(self):
        self.proof["executables"]["fixture.exe"]["pe"]["unresolved_non_system_imports"] = ["missing.dll"]
        self.rebind_fixture()
        with self.assertRaisesRegex(RuntimeError, "runtime dependency"):
            engine.verify_payload(self.payload)

    def test_unsafe_archive_paths(self):
        for name in ("../escape", "/absolute", "C:/absolute", "bin/../escape", "NUL", "bad\\path", "bad\x00path", "trailing.", "double//"):
            with self.subTest(name=name):
                self.rebind_fixture([(name, b"invalid")])
                with zipfile.ZipFile(self.archive) as archive:
                    self.assertEqual(archive.infolist()[0].orig_filename, name)
                destination = self.root / ("unsafe-" + str(len(list(self.root.iterdir()))))
                with self.assertRaises(RuntimeError):
                    engine.restore(self.archive, destination)
                self.assertEqual(list(destination.rglob("*")), [])
        self.assertFalse((self.root / "escape").exists())

    def test_windows_normalized_archive_alias_is_rejected(self):
        self.rebind_fixture([("bad\\path", b"invalid")])
        # Exercise Windows ZipInfo parsing even on the Linux developer host.
        with patch.object(zipfile.os, "sep", "\\"):
            with zipfile.ZipFile(self.archive) as archive:
                member = archive.infolist()[0]
                self.assertEqual(member.orig_filename, "bad\\path")
                self.assertEqual(member.filename, "bad/path")
            with self.assertRaisesRegex(RuntimeError, "Non-canonical"):
                engine.restore(self.archive, self.output)
        self.assertEqual(list(self.output.rglob("*")), [])

    def test_case_colliding_archive_members(self):
        self.rebind_fixture([("same.txt", b"one"), ("SAME.txt", b"two")])
        with self.assertRaisesRegex(RuntimeError, "Duplicate"):
            engine.restore(self.archive, self.output)


if __name__ == "__main__":
    unittest.main()
