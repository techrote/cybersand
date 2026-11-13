#!/usr/bin/env python3
"""Guard executable custody and distinguish native work from repeated publications."""
from pathlib import Path
import tempfile
import unittest

import run_integrated_camera_performance as subject


class EngineIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)

    def binary(self, name, payload):
        path = self.folder / name
        path.write_bytes(payload)
        return path

    def test_windows_console_and_actual_engine_are_separately_bound(self):
        launcher = self.binary("Godot_v4.7-stable_win64_console.exe", b"console wrapper")
        engine = self.binary("Godot_v4.7-stable_win64.exe", b"actual engine")
        identity = subject.engine_identity(launcher)
        self.assertNotEqual(identity["launcher"]["sha256"], identity["runtime"]["sha256"])
        self.assertEqual(identity["launcher"]["path"], str(launcher.resolve()))
        self.assertEqual(identity["runtime"]["path"], str(engine.resolve()))
        subject.verify_engine_context({"engine_path": str(engine), "engine_sha256": subject.sha(engine)}, identity)
        with self.assertRaises(ValueError):
            subject.verify_engine_context({"engine_path": str(engine), "engine_sha256": subject.sha(launcher)}, identity)

    def test_same_bytes_at_unexpected_engine_path_are_rejected(self):
        launcher = self.binary("Godot_v4.7-stable_linux.x86_64", b"engine")
        unrelated = self.binary("unrelated-engine", b"engine")
        identity = subject.engine_identity(launcher)
        self.assertEqual(identity["launcher"], identity["runtime"])
        subject.verify_engine_context({"engine_path": str(launcher), "engine_sha256": subject.sha(launcher)}, identity)
        with self.assertRaises(ValueError):
            subject.verify_engine_context({"engine_path": str(unrelated), "engine_sha256": subject.sha(unrelated)}, identity)

    def test_missing_console_sibling_is_not_accepted_as_the_engine(self):
        launcher = self.binary("Godot_v4.7-stable_win64_console.exe", b"console wrapper")
        with self.assertRaises(FileNotFoundError): subject.engine_identity(launcher)

    def test_runtime_mutation_changes_custody_identity(self):
        launcher = self.binary("Godot_v4.7-stable_win64_console.exe", b"console wrapper")
        engine = self.binary("Godot_v4.7-stable_win64.exe", b"actual engine")
        identity = subject.engine_identity(launcher)
        engine.write_bytes(b"changed engine")
        self.assertNotEqual(subject.engine_identity(launcher), identity)
        with self.assertRaises(ValueError):
            subject.verify_engine_context({"engine_path": str(engine), "engine_sha256": subject.sha(engine)}, identity)


class NativeTickObservationTests(unittest.TestCase):
    def data(self, ticks, start=7):
        return {"measurement_start": {"world_generation": 3, "tick": start},
                "publications": [{"world_generation": 3, "tick": tick, "native_tick_ms": float(tick)}
                                 for tick in ticks]}

    def test_repeated_and_premeasurement_publications_are_not_new_native_ticks(self):
        data = self.data([7, 7, 8, 8, 9, 9, 12])
        observed = subject.completed_native_ticks(data)
        self.assertEqual([row["tick"] for row in observed], [8, 9, 12])
        self.assertEqual(len(data["publications"]), 7)
        self.assertEqual(subject.summary([row["native_tick_ms"] for row in observed])["count"], 3)

    def test_paused_publications_and_tick_zero_do_not_claim_native_work(self):
        self.assertEqual(subject.completed_native_ticks(self.data([7, 7, 7])), [])
        self.assertEqual(subject.completed_native_ticks(self.data([0, 0], start=0)), [])

    def test_phase_repetition_keeps_distinct_measurements(self):
        first, second = self.data([8, 8, 9]), self.data([8, 8, 9])
        self.assertEqual(len(subject.completed_native_ticks(first) + subject.completed_native_ticks(second)), 4)

    def test_world_replacement_invalidates_a_controlled_phase(self):
        data = self.data([8])
        data["publications"][0]["world_generation"] = 4
        with self.assertRaisesRegex(ValueError, "World generation"): subject.completed_native_ticks(data)


if __name__ == "__main__":
    unittest.main()
