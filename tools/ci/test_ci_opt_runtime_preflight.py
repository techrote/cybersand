#!/usr/bin/env python3
"""Negative and positive executable CI-OPT-002 native preflight contracts."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ci_opt_runtime_preflight as gate


class RuntimePreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.src = "native/src/engine.cpp"
        path = self.root / self.src
        path.parent.mkdir(parents=True)
        path.write_bytes(b"native test\n")
        self.payload = b"MZ" + bytes(range(256)) * 5
        self.binary_sha = hashlib.sha256(self.payload).hexdigest()
        self.manifests = {}
        for platform, (manifest_name, artifact_name) in gate.NATIVE.items():
            binary = self.root / artifact_name
            binary.parent.mkdir(parents=True, exist_ok=True)
            binary.write_bytes(
                f"version https://git-lfs.github.com/spec/v1\n"
                f"oid sha256:{self.binary_sha}\nsize {len(self.payload)}\n".encode()
            )
            m = {"platform": platform, "status": "validated-development-runtime",
                 "artifact": artifact_name, "sha256": self.binary_sha,
                 "size": len(self.payload), "source_inputs": {
                     self.src: hashlib.sha256(b"native test\n").hexdigest()}}
            dest = self.root / manifest_name
            dest.write_text(json.dumps(m))
            self.manifests[platform] = m

    def save(self, platform):
        path = self.root / gate.NATIVE[platform][0]
        path.write_text(json.dumps(self.manifests[platform]))

    def test_lfs_pointer_and_materialized_binary_are_both_source_attested(self):
        self.assertEqual(gate.check(self.root, ("linux", "windows"))["status"], "admitted")
        (self.root / gate.NATIVE["linux"][1]).write_bytes(self.payload)
        result = gate.check(self.root, ("linux",))
        self.assertEqual(result["status"], "admitted")
        self.assertEqual(result["platforms"][0]["runtime_form"], "materialized")

    def test_stale_native_input_refuses_both_platforms(self):
        (self.root / self.src).write_bytes(b"native changed\n")
        verdict = gate.check(self.root, ("linux", "windows"))
        self.assertEqual(verdict["status"], "blocked_unpublished_runtime")
        self.assertTrue(all(any("source changed" in e for e in x["errors"])
                            for x in verdict["platforms"]))

    def test_corrupted_lfs_identity_or_wrong_binary_refuses(self):
        self.manifests["windows"]["sha256"] = "0" * 64
        self.save("windows")
        self.assertNotEqual(gate.check(self.root, ("windows",))["status"], "admitted")
        (self.root / gate.NATIVE["linux"][1]).write_bytes(self.payload + b"corrupt")
        self.assertNotEqual(gate.check(self.root, ("linux",))["status"], "admitted")

    def test_unqualified_or_wrong_platform_refuses(self):
        self.manifests["linux"]["status"] = "built-not-executed"
        self.save("linux")
        self.assertNotEqual(gate.check(self.root, ("linux",))["status"], "admitted")
        self.manifests["linux"]["status"] = "validated-development-runtime"
        self.manifests["linux"]["platform"] = "windows"
        self.save("linux")
        self.assertNotEqual(gate.check(self.root, ("linux",))["status"], "admitted")

    def test_symlink_and_path_traversal_refuse(self):
        self.manifests["linux"]["source_inputs"] = {"../outside.cpp": "f" * 64}
        self.save("linux")
        self.assertNotEqual(gate.check(self.root, ("linux",))["status"], "admitted")

    def test_missing_manifest_or_binary_refuse(self):
        (self.root / gate.NATIVE["windows"][0]).unlink()
        self.assertNotEqual(gate.check(self.root, ("windows",))["status"], "admitted")
        (self.root / gate.NATIVE["linux"][1]).unlink()
        self.assertNotEqual(gate.check(self.root, ("linux",))["status"], "admitted")

    def test_short_malformed_pointer_and_boolean_size_refuse(self):
        (self.root / gate.NATIVE["linux"][1]).write_bytes(b"not a binary\n")
        self.assertNotEqual(gate.check(self.root, ("linux",))["status"], "admitted")
        self.manifests["windows"]["size"] = True
        self.save("windows")
        self.assertNotEqual(gate.check(self.root, ("windows",))["status"], "admitted")

    def test_unrelated_source_changes_do_not_reject_reused_native_inputs(self):
        (self.root / "README.md").write_text("unrelated docs changed")
        self.assertEqual(gate.check(self.root, ("linux",))["status"], "admitted")


if __name__ == "__main__":
    unittest.main()
