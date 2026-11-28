#!/usr/bin/env python3
import copy
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

import engine_contract as contract
import payload


def pe(subsystem: int) -> bytes:
    data = bytearray(512)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 64)
    data[64:68] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", data, 68, 0x8664, 0, 0, 0, 0, 240, 0)
    struct.pack_into("<H", data, 88, 0x20B)
    struct.pack_into("<I", data, 88 + 60, 512)
    struct.pack_into("<H", data, 88 + 68, subsystem)
    return bytes(data)


class PayloadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.build = json.loads((contract.ROOT / contract.DIRECTORY / "engine.lock.json").read_bytes())
        self.source = subprocess.check_output(["git", "-C", str(contract.ROOT), "rev-parse", "HEAD"], text=True).strip()
        self.inputs = payload.expected_inputs(contract.ROOT, self.source)
        (self.folder / "bin").mkdir()
        (self.folder / "notices").mkdir()
        for role, subsystem in (("output_gui", 2), ("output_console", 3)):
            (self.folder / "bin" / self.build[role]).write_bytes(pe(subsystem))
        (self.folder / "notices/LICENSE.txt").write_text("Synthetic gate test only\n")
        (self.folder / "notices/COPYRIGHT.txt").write_text("No engine was built by this test\n")
        (self.folder / "workbench-godot.lock.json").write_bytes((contract.ROOT / contract.DIRECTORY / "engine.lock.json").read_bytes())
        (self.folder / "engine-source.patch").write_bytes(b"".join((contract.ROOT / item["path"]).read_bytes() for item in self.build["patches"]))
        header = {"precision": "single", "version_major": 4, "version_minor": 7, "version_patch": 0, "version_status": "stable"}
        api = {"api_equal_except_declared_build_labels": True, "interface_bytes_equal": True,
               "ignored_header_fields": ["version_build", "version_full_name"],
               "official_header": {**header, "version_build": "official", "version_full_name": "Godot Engine v4.7.stable.official"},
               "custom_header": {**header, "version_build": self.build["build_name"],
                                 "version_full_name": "Godot Engine v4.7.stable." + self.build["build_name"]}}
        (self.folder / "api-equivalence.json").write_text(json.dumps(api))
        reader = payload.load_module("test_font_pe_reader", contract.ROOT / contract.FROZEN_BUILDER)
        dependencies = {name: {key: self.build[name][key] for key in ("bytes", "sha256")}
                        for name in ("scons", "angle", "accesskit")}
        dependencies["official_reference"] = payload.OFFICIAL_ARCHIVE
        self.proof = {"schema": "workbench-godot-build-provenance-v1", "complete": True, "custom_engine": True,
                      "public_api_equivalent": True, "application_source": self.source, "workflow_run": "123", "workflow_attempt": "2",
                      "upstream_commit": self.build["source_commit"], "upstream_tree": payload.UPSTREAM_TREE,
                      "patches": self.build["patches"], "scope": self.build["scope"], "version": self.build["version"],
                      "build_name": self.build["build_name"], "input_admission": self.inputs,
                      "lock": payload.file_record(contract.ROOT / contract.DIRECTORY / "engine.lock.json"),
                      "builder": payload.file_record(contract.ROOT / contract.DIRECTORY / "build_engine.py"),
                      "patched_sources": {name: {"sha256": values["after_sha256"], "bytes": 100}
                                          for item in self.build["patches"] for name, values in item["files"].items()},
                      "scons_flags": self.build["scons_flags"] + ["angle_libs=C:/build/angle", "accesskit_sdk_path=C:/build/accesskit"],
                      "workers": 2, "python": "3.12.10", "platform": "Windows-synthetic-gate-test",
                      "dependency_archives": dependencies, "api_dumps": {"official": payload.API_RECORDS, "custom": payload.API_RECORDS},
                      "combined_patch": payload.file_record(self.folder / "engine-source.patch"),
                      "gui_executable": "bin/" + self.build["output_gui"], "console_executable": "bin/" + self.build["output_console"],
                      "executables": {self.build[role]: {**payload.file_record(self.folder / "bin" / self.build[role]),
                                                         "pe": reader.pe_imports(self.folder / "bin" / self.build[role])}
                                      for role in ("output_gui", "output_console")}}
        self.refresh()

    def refresh(self):
        self.proof["payload_files"] = {path.relative_to(self.folder).as_posix(): payload.file_record(path)
                                       for path in self.folder.rglob("*") if path.is_file() and path.name != "build-provenance.json"}
        (self.folder / "build-provenance.json").write_text(json.dumps(self.proof))
        self.identity = {"build_source": self.source, "build_run": 123, "build_attempt": 2,
                         "proof_sha256": payload.digest(self.folder / "build-provenance.json")}

    def verify(self, **changes):
        return payload.verify_payload(self.folder, **{**self.identity, **changes})

    def test_exact_gate_and_external_proof_source_run_attempt_binding(self):
        self.assertEqual(self.verify()["version"], self.build["version"])
        for changes in ({"proof_sha256": "0" * 64}, {"build_run": 124}, {"build_attempt": 1}):
            with self.subTest(changes=changes), self.assertRaises(ValueError): self.verify(**changes)

    def test_rehashing_tampered_flags_api_and_input_admission_does_not_admit_them(self):
        original = copy.deepcopy(self.proof)
        for key, replacement in (("scons_flags", ["threads=no"]), ("public_api_equivalent", False),
                                 ("input_admission", {}), ("patched_sources", {}), ("version", "4.7.stable.cybersand_egl_handoff.5b4e0cb0f")):
            self.proof = copy.deepcopy(original)
            self.proof[key] = replacement
            self.refresh()
            with self.subTest(key=key), self.assertRaises(ValueError): self.verify()

    def test_extra_payload_and_modified_pe_are_refused(self):
        extra = self.folder / "unexpected.dll"
        extra.write_bytes(b"not a dependency")
        with self.assertRaises(ValueError): self.verify()
        self.refresh()
        with self.assertRaises(ValueError): self.verify()
        extra.unlink()
        (self.folder / "bin" / self.build["output_gui"]).write_bytes(pe(3))
        self.refresh()
        with self.assertRaises(ValueError): self.verify()

    def test_rehashed_patch_change_and_api_header_relaxation_are_refused(self):
        path = self.folder / "engine-source.patch"
        original = path.read_bytes()
        path.write_bytes(original.replace(b"img = tex.image->duplicate();", b"img = tex.image;", 1))
        self.proof["combined_patch"] = payload.file_record(path)
        self.refresh()
        with self.assertRaises(ValueError): self.verify()
        path.write_bytes(original)
        self.proof["combined_patch"] = payload.file_record(path)
        api_path = self.folder / "api-equivalence.json"
        api = json.loads(api_path.read_bytes())
        api["ignored_header_fields"].append("precision")
        api_path.write_text(json.dumps(api))
        self.refresh()
        with self.assertRaises(ValueError): self.verify()

    def test_git_patch_decoration_only_is_ignored(self):
        simple = b"--- a/one.cpp\n+++ b/one.cpp\n@@ -1,1 +1,1 @@\n-old\n+new\n"
        decorated = b"diff --git a/one.cpp b/one.cpp\nindex abc123..def456 100644\n--- a/one.cpp\n+++ b/one.cpp\n@@ -1,1 +1,1 @@ void name() {\n-old\n+new\n"
        self.assertEqual(payload.normalized_patch(simple), payload.normalized_patch(decorated))
        self.assertNotEqual(payload.normalized_patch(simple), payload.normalized_patch(decorated.replace(b"+new", b"+wrong")))

    def windows_patch(self):
        path = contract.ROOT / "docs/audits/2026-11-24-pubpres-playability-final/font-engine-combined-source-lines.json"
        fixture = json.loads(path.read_bytes())
        data = ("\n".join(fixture["lines"]) + "\n").encode("utf-8")
        expected = "3dd0d224ad0a0a4187bfbc71fad3bf7c3030f0601b76284f0ff64d0cb38f229e"
        self.assertEqual(fixture["sha256"], expected)
        self.assertEqual(contract.sha(data), expected)
        return data

    def test_actual_windows_patch_has_exact_same_ordered_edits(self):
        # Immutable textual patch from source c2f8a73d / run45452580606 attempt1.
        # Four identical braces receive different context alignment in Git's
        # combined diff; all coordinates and replacement bytes remain exact.
        path = self.folder / "engine-source.patch"
        declared = path.read_bytes()
        actual = self.windows_patch()
        self.assertNotEqual(actual, declared)
        canonical = payload.normalized_patch(actual)
        self.assertEqual(canonical, payload.normalized_patch(declared))
        records = json.loads(canonical)
        self.assertEqual([len(record["edits"]) for record in records], [1, 5, 5])
        self.assertEqual([edit["old_line"] for edit in records[1]["edits"]], [3402, 3807, 3857, 4333, 4472])
        self.assertEqual([edit["old_line"] for edit in records[2]["edits"]], [2105, 2496, 2546, 2975, 3114])
        path.write_bytes(actual)
        self.proof["combined_patch"] = payload.file_record(path)
        self.refresh()
        self.assertTrue(self.verify()["complete"])

    def test_rehashed_windows_changed_line_coordinate_and_extra_edit_are_refused(self):
        actual = self.windows_patch()
        path = self.folder / "engine-source.patch"
        mutations = {
            "changed insertion": actual.replace(b"+\t\t\t\timg = tex.image->duplicate();", b"+\t\t\t\timg = tex.image;", 1),
            "changed insertion whitespace": actual.replace(b"+\tcurrent_window = nullptr;", b"+ current_window = nullptr;", 1),
            "moved edit": actual.replace(b"@@ -350,6 +350,9", b"@@ -351,6 +351,9", 1),
            "inconsistent new position": actual.replace(b"@@ -350,6 +350,9", b"@@ -350,6 +351,9", 1),
            "additional edit": actual + b"@@ -4000,1 +4025,1 @@\n-old\n+new\n",
            "modified file closure": actual.replace(b"text_server_fb/text_server_fb.cpp", b"text_server_fb/other.cpp"),
        }
        for label, changed in mutations.items():
            with self.subTest(label=label):
                self.assertNotEqual(changed, actual)
                path.write_bytes(changed)
                self.proof["combined_patch"] = payload.file_record(path)
                self.refresh()
                with self.assertRaises(ValueError): self.verify()

    def test_windows_patch_malformed_or_noncanonical_structure_is_refused(self):
        actual = self.windows_patch()
        first_file = actual.split(b"diff --git a/modules/text_server_adv/", 1)[0]
        malformed = {
            "wrong count": actual.replace(b"@@ -350,6 +350,9", b"@@ -350,7 +350,9", 1),
            "mode": actual.replace(b"100644", b"100755", 1),
            "rename": actual.replace(b"b/drivers/egl/egl_manager.cpp", b"b/drivers/egl/other.cpp", 1),
            "repeated file": actual + first_file,
            "empty added hunk": actual + b"@@ -4000,1 +4025,1 @@\n same\n",
            "no-op replacement": actual + b"@@ -4000,1 +4025,1 @@\n-same\n+same\n",
            "extra body line": actual + b"+undeclared\n",
            "truncated": actual[:-1],
            "carriage return": actual.replace(b"\n", b"\r\n"),
            "binary metadata": actual + b"GIT binary patch\n",
            "invalid utf8": actual.replace(b"current_window", b"\xffwindow", 1),
        }
        for label, changed in malformed.items():
            with self.subTest(label=label), self.assertRaises(ValueError):
                payload.normalized_patch(changed)

    def test_replacement_removed_bytes_and_hunk_order_are_exact(self):
        first = b"--- a/one.cpp\n+++ b/one.cpp\n@@ -1,2 +1,2 @@\n-old\n+new\n context\n"
        self.assertNotEqual(payload.normalized_patch(first), payload.normalized_patch(first.replace(b"-old", b"-other")))
        ordered = first + b"@@ -8,1 +8,1 @@\n-old2\n+new2\n"
        reversed_hunks = b"--- a/one.cpp\n+++ b/one.cpp\n@@ -8,1 +8,1 @@\n-old2\n+new2\n@@ -1,2 +1,2 @@\n-old\n+new\n context\n"
        self.assertEqual(len(json.loads(payload.normalized_patch(ordered))[0]["edits"]), 2)
        with self.assertRaises(ValueError): payload.normalized_patch(reversed_hunks)


if __name__ == "__main__":
    unittest.main()
