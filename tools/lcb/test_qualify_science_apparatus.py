#!/usr/bin/env python3
"""Pure qualification-runner identity guards; no Godot or Native execution."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import qualify_science_apparatus as q


class BuildIdentity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.addCleanup(patch.stopall)
        patch.object(q, "ROOT", self.root).start()
        for name in q.CORE_SOURCES:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
        self.sources = {name: q.file_sha(self.root / name) for name in q.CORE_SOURCES}
        self.args = argparse.Namespace(consumer=self.root / "consumer", compiler=self.root / "compiler",
            build_receipt=self.root / "build.json", compiler_source_map=self.root / "source-map.json")
        self.args.consumer.write_bytes(b"test consumer bytes")
        self.args.compiler.write_bytes(b"test compiler bytes")
        self.receipt = {"schema": "lcb-science-consumer-build-v1", "exe_sha256": q.file_sha(self.args.consumer),
            "compiler_sha256": q.file_sha(self.args.compiler), "flags": ["-std=c++20", "-O2"],
            "source_inputs": self.sources}

    def bind(self, receipt=None, sources=None):
        self.args.build_receipt.write_text(json.dumps(self.receipt if receipt is None else receipt))
        self.args.compiler_source_map.write_text(json.dumps(self.sources if sources is None else sources))
        return q.build_binding(self.args)

    def test_complete_flat_and_original_object_shapes(self):
        self.assertEqual(self.bind()["shape"], "flat-source-build-receipt-v1")
        old = copy.deepcopy(self.receipt)
        old.pop("schema")
        old["objects"] = {"core": {"compiled_inputs": old.pop("source_inputs"), "object_sha256": "12" * 32}}
        self.assertEqual(self.bind(old)["shape"], "original-object-compile-receipt-v1")

    def test_subset_maps_and_missing_core_inputs_refuse(self):
        smaller = dict(self.sources)
        smaller.pop("native/src/world.cpp")
        with self.assertRaisesRegex(ValueError, "complete build receipt/source-map equality"):
            self.bind(sources=smaller)
        receipt = dict(self.receipt, source_inputs=smaller)
        with self.assertRaisesRegex(ValueError, "complete build receipt/source-map equality"):
            self.bind(receipt, smaller)

    def test_no_hash_alias_or_ambiguous_source_container(self):
        both = dict(self.receipt, objects={"other": {"compiled_inputs": self.sources}})
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.bind(both)
        alias = dict(self.receipt)
        alias["binary_sha256"] = alias.pop("exe_sha256")
        with self.assertRaises(KeyError):
            self.bind(alias)

    def test_changed_consumer_compiler_and_compiled_source_refuse(self):
        for target in [self.args.consumer, self.args.compiler, self.root / "native/src/world.cpp"]:
            old = target.read_bytes()
            target.write_bytes(old + b" changed")
            try:
                with self.assertRaises(ValueError):
                    self.bind()
            finally:
                target.write_bytes(old)

    def test_bad_digest_path_flags_and_conflicting_object_bindings_refuse(self):
        for bad in [True, "AA" * 32, "0" * 63, "../outside.cpp"]:
            sources = dict(self.sources)
            sources["native/src/world.cpp"] = bad
            with self.assertRaises(ValueError):
                self.bind(sources=sources)
        for flags in [[], "-O2", [True]]:
            with self.assertRaisesRegex(ValueError, "compiler flags"):
                self.bind(dict(self.receipt, flags=flags))
        old = {k: v for k, v in self.receipt.items() if k not in ("schema", "source_inputs")}
        old["objects"] = {"a": {"compiled_inputs": self.sources, "object_sha256": "12" * 32},
                          "b": {"compiled_inputs": {"native/src/world.cpp": "34" * 32}, "object_sha256": "56" * 32}}
        with self.assertRaisesRegex(ValueError, "inconsistent repeated"):
            self.bind(old)


class OutputAdmission(unittest.TestCase):
    def test_new_external_output_only(self):
        with tempfile.TemporaryDirectory() as temp:
            root = (Path(temp) / "source").resolve()
            root.mkdir()
            with patch.object(q, "ROOT", root):
                with self.assertRaisesRegex(ValueError, "new and outside"):
                    q.new_out(root / "output")
                out = q.new_out(Path(temp) / "packet")
                with self.assertRaisesRegex(ValueError, "new and outside"):
                    q.new_out(out)

    def test_duplicate_json_keys_and_bool_worker_identity_refuse(self):
        with self.assertRaisesRegex(ValueError, "duplicate JSON"):
            q.a.loads('{"exe_sha256":"00","exe_sha256":"11"}')
        for value in [True, 1.0, "1"]:
            with self.assertRaisesRegex(ValueError, "invalid integer"):
                q.a.integer(value, 1, 4, "replay workers")


if __name__ == "__main__":
    unittest.main()
