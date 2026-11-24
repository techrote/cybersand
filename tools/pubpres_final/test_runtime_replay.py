from pathlib import Path
import ast
import unittest

import runtime_replay as replay


class RecordedRuntimeContract(unittest.TestCase):
    def test_only_declared_platform_edits(self):
        raw = replay.FROZEN_FILE.read_bytes()
        tree = ast.parse(raw.decode())
        original = ast.get_source_segment(raw.decode(), next(node for node in tree.body
            if isinstance(node, ast.FunctionDef) and node.name == "verify_experimental_runtime"))
        derived = replay.derive(raw)
        restored = derived.rstrip("\n").replace(
            "def verify_recorded_runtime(root, source, folder, *, target_platform):",
            "def verify_experimental_runtime(root, source, folder):").replace(
            'target_platform == "windows"', 'os.name == "nt"').replace(
            "Native build platform differs from explicitly recorded target",
            "Native build platform differs from executing host")
        self.assertEqual(restored, original)
        self.assertEqual(derived.count('target_platform == "windows"'), 3)
        self.assertNotIn("os.name", derived)
        self.assertEqual(len(replay.identity()["derived_function_sha256"]), 64)

    def test_frozen_source_and_gate_tampering_refuse(self):
        raw = replay.FROZEN_FILE.read_bytes()
        for changed in (
            raw + b"\n",
            raw.replace(b'need(record["source_commit"] == source["source_commit"]', b'need(True or record["source_commit"] == source["source_commit"]'),
            raw.replace(b'need(expected == actual == set(inputs)', b'need(True or expected == actual == set(inputs)'),
            raw.replace(b'dependency_custody.verify(folder, record)', b'{}'),
            raw.replace(b'and record.get("toolchain_drift_allowed") is False', b'and True'),
        ):
            self.assertNotEqual(changed, raw)
            with self.assertRaisesRegex(ValueError, "Frozen native runtime admission file differs"):
                replay.derive(changed)

    def test_target_must_be_explicit_registered_platform(self):
        for target in (None, "", "darwin", "Windows", "nt", True):
            with self.assertRaisesRegex(ValueError, "Explicit recorded"):
                replay.verify_recorded_runtime(Path("absent"), {}, Path("absent"), target_platform=target)


if __name__ == "__main__":
    unittest.main()
