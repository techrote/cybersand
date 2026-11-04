#!/usr/bin/env python3
"""Fail-closed tests of actual compiler-stream and retained-payload custody."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import mat354_h1_runtime_dependencies as subject

# Deliberately independent of the implementation's completion inventory.
EXPECTED = (
    "godot/native_extension/cyber_native_cell_world.cpp", "godot/native_extension/cyber_world_generator.cpp",
    "godot/native_extension/register_types.cpp", "native/src/world.cpp", "native/src/world_generation.cpp",
    "native/src/generation_fields.cpp", "native/src/generation_typed_fields.cpp", "native/src/generation_spatial.cpp",
    "native/src/generation_grammar.cpp", "native/src/generation_planes.cpp", "native/src/render_snapshot.cpp",
    "native/src/settled_world_discovery.cpp", "native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.capture = self.root / subject.DIRECTORY
        self.objects = self.capture / "objects"
        self.objects.mkdir(parents=True)
        self.source = "a" * 40
        self.tree = "b" * 40
        self.project = "/work/source"
        self.sdk = "/work/sdk"
        self.header = self.project + "/native/include/shared.hpp"
        self.generated = self.sdk + "/gen/include/godot_cpp/classes/node.hpp"
        self.system = "/usr/include/test-system.h"
        self.archive = self.sdk + "/bin/libgodot-cpp.linux.template_debug.x86_64.a"
        self.inputs = {}
        self.project_hashes = {}
        for path in [*(self.project + "/" + s for s in EXPECTED), self.header, self.generated, self.system]:
            self.inputs[path] = self.payload(path)
            if path.startswith(self.project + "/"):
                self.project_hashes[path[len(self.project) + 1:]] = self.inputs[path]["sha256_before"]
        archive = self.payload(self.archive)
        driver = "/usr/bin/g++-13"
        compiler = {
            label: {"selected": path, "resolved": path, "bytes": 123, "sha256": subject.digest(label.encode())}
            for label, path in (("compiler-driver", driver), ("compiler-cc1plus", "/usr/libexec/gcc/13/cc1plus"),
                                ("linker", "/usr/bin/ld"))}
        original = [driver, *subject.original_arguments("linux", self.project, self.sdk, self.archive, "/work/out.so")]
        environment = dict.fromkeys(subject.ENVIRONMENT)
        environment.update({"LC_ALL": "C", "TZ": "UTC", "SOURCE_DATE_EPOCH": "0",
                            "GODOT_CPP_ROOT": self.sdk, "LINUX_CXX": driver})
        invocation = {"original_argv": original, "actual_argv": original + list(subject.FLAGS),
                      "preflight_argv": subject.preflight_arguments(original), "cwd": self.project,
                      "environment": environment,
                      "compiler_before": compiler, "source": {"commit": self.source, "tree": self.tree},
                      "roots": {"project": self.project, "sdk": self.sdk, "toolchain": None,
                                "system": ["/usr/include", "/usr/lib/gcc"]},
                      "platform": "linux", "archive_path": self.archive, "output_path": "/work/out.so"}
        self.write("invocation.json", json.dumps(invocation).encode())
        units = []
        stream = b""
        for i, name in enumerate(EXPECTED):
            paths = [self.project + "/" + name, self.header, self.generated, self.system]
            raw = (subject.TARGET + ": " + " \\\n ".join(paths) + "\n").encode()
            stream += raw
            unit = {"source": name, "paths": paths}
            for label in ("preflight", "actual"):
                filename = label + "-" + str(i).zfill(2) + ".d"
                self.write(filename, raw)
                unit[label] = {"path": filename, **subject.file_fact(self.capture / filename)}
            units.append(unit)
        for name in ("preflight.stdout", "actual.stdout"):
            self.write(name, stream)
        for name in ("preflight.stderr", "actual.stderr"):
            self.write(name, b"")
        self.receipt = invocation | {
            "schema": subject.SCHEMA, "compiler_after": copy.deepcopy(compiler), "translation_units": units,
            "inputs": self.inputs, "archive": archive, "runtime": {"sha256": "c" * 64, "bytes": 200},
            "preflight_returncode": 0, "actual_returncode": 0,
            "files": {name: subject.file_fact(self.capture / name) for name in
                      ("invocation.json", "preflight.stdout", "preflight.stderr", "actual.stdout", "actual.stderr")}}
        text = "\n".join("executable[" + label + "] selected=" + f["selected"] + " resolved=" + f["resolved"] +
                         " size=" + str(f["bytes"]) + " sha256=" + f["sha256"] for label, f in compiler.items())
        self.toolchain = text + "\n" + archive["sha256_before"] + "  " + self.archive + "\n"
        self.manifest = {"platform": "linux", "source_tree": self.tree, "sha256": "c" * 64,
                         "size": 200, "source_inputs": self.project_hashes}
        self.save()

    def write(self, name, data):
        (self.capture / name).write_bytes(data)

    def payload(self, path):
        data = ("actual bytes of " + path).encode()
        sha = subject.digest(data)
        (self.objects / sha).write_bytes(data)
        scope = "project" if path.startswith(self.project + "/") else "sdk" if path.startswith(self.sdk + "/") else "system"
        return {"scope": scope, "resolved": path, "bytes": len(data), "sha256_before": sha,
                "sha256_after": sha, "object": sha}

    def save(self):
        path = self.root / subject.RECEIPT
        path.write_text(json.dumps(self.receipt), encoding="utf-8")
        self.manifest["toolchain"] = self.toolchain + subject.MARKER + subject.digest(path.read_bytes()) + "\n"

    def verify(self):
        return subject.verify(self.root, self.manifest, self.source, self.root)

    def test_complete_fourteen_actual_translation_units_pass(self):
        self.assertEqual(subject.SOURCES, EXPECTED)
        result = self.verify()
        self.assertEqual(len(result["translation_units"]), 14)
        self.assertIn(self.generated, result["inputs"])
        self.assertIn(self.system, result["inputs"])

    def test_missing_receipt_or_missing_payload_refuses(self):
        path = self.root / subject.RECEIPT
        path.unlink()
        with self.assertRaisesRegex(RuntimeError, "Missing compiled-input receipt"):
            self.verify()
        self.save()
        (self.objects / self.inputs[self.system]["object"]).unlink()
        with self.assertRaisesRegex(RuntimeError, "Retained input bytes"):
            self.verify()

    def test_missing_duplicate_reordered_and_spliced_units_refuse(self):
        good = copy.deepcopy(self.receipt["translation_units"])
        for units in (good[:-1], good + good[-1:], list(reversed(good)), good[:5] + [good[0]] + good[6:]):
            self.receipt["translation_units"] = units
            self.save()
            with self.assertRaisesRegex(RuntimeError, "translation unit"):
                self.verify()

    def test_omitted_input_hash_refuses_even_with_rebound_receipt(self):
        del self.receipt["inputs"][self.system]
        self.save()
        with self.assertRaisesRegex(RuntimeError, "Missing or unexpected input hash"):
            self.verify()

    def test_changed_input_hash_or_bytes_refuse(self):
        self.receipt["inputs"][self.header]["sha256_after"] = "f" * 64
        self.save()
        with self.assertRaisesRegex(RuntimeError, "Changed or malformed input hash"):
            self.verify()
        self.receipt["inputs"][self.header]["sha256_after"] = self.receipt["inputs"][self.header]["sha256_before"]
        self.save()
        (self.objects / self.inputs[self.header]["object"]).write_bytes(b"changed header")
        with self.assertRaisesRegex(RuntimeError, "Retained input bytes differ"):
            self.verify()

    def test_stale_source_and_runtime_refuse(self):
        for key, value in (("source", {"commit": "f" * 40, "tree": self.tree}),
                           ("runtime", {"sha256": "d" * 64, "bytes": 200})):
            original = self.receipt[key]
            self.receipt[key] = value
            self.save()
            with self.assertRaises(RuntimeError):
                self.verify()
            self.receipt[key] = original

    def test_wrong_compiler_or_changed_payload_refuses(self):
        self.receipt["compiler_after"]["compiler-driver"]["sha256"] = "f" * 64
        self.save()
        with self.assertRaisesRegex(RuntimeError, "Unstable compiler payload"):
            self.verify()
        self.receipt["compiler_before"]["compiler-driver"]["sha256"] = "f" * 64
        self.save()
        with self.assertRaisesRegex(RuntimeError, "Incorrect compiler payload"):
            self.verify()

    def test_modified_compiler_argv_or_missing_metadata_flag_refuses(self):
        original = copy.deepcopy(self.receipt)
        for field in ("original_argv", "actual_argv", "preflight_argv"):
            self.receipt = copy.deepcopy(original)
            self.receipt[field][2] = "-O0"
            self.save()
            with self.assertRaisesRegex(RuntimeError, "compiler argv"):
                self.verify()

    def test_only_separate_preflight_can_remove_original_output(self):
        self.assertNotIn("-o", self.receipt["preflight_argv"])
        self.assertIn("-o", self.receipt["actual_argv"])
        original = copy.deepcopy(self.receipt)
        self.receipt["preflight_argv"] = original["original_argv"] + list(subject.PREFLIGHT_FLAGS)
        self.save()
        with self.assertRaisesRegex(RuntimeError, "compiler argv"):
            self.verify()
        self.receipt = copy.deepcopy(original)
        index = self.receipt["actual_argv"].index("-o")
        del self.receipt["actual_argv"][index:index + 2]
        self.save()
        with self.assertRaisesRegex(RuntimeError, "compiler argv"):
            self.verify()

    def test_rebound_prohibited_missing_or_wrong_environment_refuses(self):
        original = copy.deepcopy(self.receipt)
        invocation = json.loads((self.capture / "invocation.json").read_text())
        changes = [(name, "/foreign/input") for name in subject.FORBIDDEN_ENVIRONMENT]
        changes += [("GODOT_CPP_ROOT", "/foreign/sdk"), ("GODOT_CPP_LIBRARY", "/foreign/archive.a"),
                    ("LINUX_CXX", "/foreign/compiler"), ("CPATH", None)]
        for field, value in changes:
            self.receipt = copy.deepcopy(original)
            changed_invocation = copy.deepcopy(invocation)
            if value is None:
                del self.receipt["environment"][field]
            else:
                self.receipt["environment"][field] = value
            changed_invocation["environment"] = self.receipt["environment"]
            self.write("invocation.json", json.dumps(changed_invocation).encode())
            self.receipt["files"]["invocation.json"] = subject.file_fact(self.capture / "invocation.json")
            self.save()
            with self.subTest(field=field, value=value), self.assertRaises(RuntimeError):
                self.verify()

    def test_rebound_empty_missing_extra_or_spliced_actual_invocation_refuses(self):
        original = json.loads((self.capture / "invocation.json").read_text())
        for changed in ({}, {k: v for k, v in original.items() if k != "actual_argv"},
                        {k: v for k, v in original.items() if k != "source"},
                        original | {"extra": "unreviewed"}, original | {"cwd": "/foreign/source"}):
            self.write("invocation.json", json.dumps(changed).encode())
            self.receipt["files"]["invocation.json"] = subject.file_fact(self.capture / "invocation.json")
            self.save()
            with self.assertRaisesRegex(RuntimeError, "Incomplete or spliced compiler invocation"):
                self.verify()

    def test_wrong_sdk_archive_identity_refuses(self):
        self.toolchain = self.toolchain.replace(self.receipt["archive"]["sha256_before"], "f" * 64)
        self.save()
        with self.assertRaisesRegex(RuntimeError, "SDK archive identity"):
            self.verify()

    def test_rebound_last_only_duplicate_truncated_or_unparsed_raw_stream_refuses(self):
        good = (self.capture / "actual.stdout").read_bytes()
        last = (self.capture / "actual-13.d").read_bytes()
        for raw in (last, good + last, good[:-1], good + b"unparsed\n", good.replace(b"shared.hpp", b"omitted.hpp", 1)):
            self.write("actual.stdout", raw)
            self.receipt["files"]["actual.stdout"] = subject.file_fact(self.capture / "actual.stdout")
            self.save()
            with self.assertRaises(RuntimeError):
                self.verify()

    def test_missing_duplicate_or_corrupt_individual_depfile_refuses(self):
        self.receipt["translation_units"][1]["actual"] = copy.deepcopy(self.receipt["translation_units"][0]["actual"])
        self.save()
        with self.assertRaisesRegex(RuntimeError, "Duplicate or spliced dependency file"):
            self.verify()

    def test_dependency_path_and_symlink_escapes_refuse(self):
        self.receipt["inputs"][self.header]["resolved"] = "/tmp/foreign-header.h"
        self.save()
        with self.assertRaisesRegex(RuntimeError, "Unexpected compiler input path"):
            self.verify()
        self.receipt["inputs"][self.header]["resolved"] = self.header
        self.save()
        payload = self.objects / self.inputs[self.header]["object"]
        original = Path.is_symlink
        with mock.patch.object(Path, "is_symlink", lambda path: path == payload or original(path)):
            with self.assertRaisesRegex(RuntimeError, "Retained input bytes differ"):
                self.verify()

    def test_receipt_path_escape_unknown_object_and_broadened_root_refuse(self):
        self.receipt["translation_units"][0]["actual"]["path"] = "../actual-00.d"
        self.save()
        with self.assertRaises(RuntimeError):
            self.verify()
        self.receipt["translation_units"][0]["actual"]["path"] = "actual-00.d"
        self.receipt["roots"]["system"] = ["/"]
        self.save()
        with self.assertRaisesRegex(RuntimeError, "Unadmitted system-header roots"):
            self.verify()

    def test_unbound_receipt_and_duplicate_json_fields_refuse(self):
        self.manifest["toolchain"] = self.toolchain
        with self.assertRaisesRegex(RuntimeError, "not bound"):
            self.verify()
        self.save()
        path = self.root / subject.RECEIPT
        text = path.read_text().replace('"schema":', '"schema": "duplicate", "schema":', 1)
        path.write_text(text)
        with self.assertRaisesRegex(RuntimeError, "Duplicate receipt field"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
