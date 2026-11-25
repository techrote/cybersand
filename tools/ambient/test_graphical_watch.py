#!/usr/bin/env python3
"""Synthetic custody/refusal tests only; no Godot, World or graphical evidence."""
from __future__ import annotations

import argparse
import base64
import copy
from pathlib import Path
import tempfile
import unittest

import run_graphical_watch as watch

PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4h0AAAAASUVORK5CYII=")


class SustainedReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)
        self.report = {"schema": watch.SCHEMA, "status": "passed", "failures": [],
            "scene": "ambient2-courtyard", "follow_actor": 1, "requested_simulation_seconds": 10,
            "source_revision": "fixture-source", "observer_script_sha256": "fixture-observer",
            "engine_sha256": "fixture-engine", "display": "synthetic fixture display",
            "renderer": "synthetic fixture renderer", "rendering_method": "gl_compatibility",
            "rendering_driver": "opengl3", "physics_ticks_per_second": 60,
            "actual_simulation_seconds": 10.0, "physical_ticks": 600, "native_ticks": 600, "samples": []}
        for second in range(11):
            path = self.folder / f"frame-{second:04d}.png"
            path.write_bytes(PNG)
            self.report["samples"].append({"requested_simulation_second": second,
                "simulation_seconds_since_play": float(second), "diagnostics_physical_tick": second * 60,
                "diagnostics_native_tick": second * 60,
                "capture": {"path": str(path), "paused": second == 0,
                    "material_display": {"generation": 1, "render_serial": second, "revision": second},
                    "rendered_actor_frame": {"available": True, "mode": "synthetic matched fixture",
                                             "world_generation": 1, "revision": second}},
                "actors": [{"instance_id": 1, "tick": second * 60, "run_id": "fixture-run", "epoch": 1,
                    "generation": 4 if second == 0 else 5, "status": "paused" if second == 0 else "policy",
                    "decisions": second * 10, "error": "", "observation": {"position": [float(second), 5.0]},
                    "memory": {}, "recent_decisions_tail": []}]})

    def tearDown(self):
        self.temp.cleanup()

    def validate(self, report=None):
        return watch.validate_watch(self.folder, report or self.report, "ambient2-courtyard", 10,
                                    "fixture-source", "fixture-observer", "fixture-engine", "opengl3")

    def test_application_revision_rejects_short_alias_and_malformed_values(self):
        for value in ("main", "a7250e15", "A" * 40, "g" * 40, "a" * 39, "a" * 41, " " + "a" * 40, None):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                watch.full_application_revision(value)

    def test_wrong_full_application_revision_is_refused(self):
        with self.assertRaisesRegex(RuntimeError, "explicitly pinned revision"):
            watch.admit_application_revision({"source_commit": "a" * 40}, "b" * 40)

    def test_explicit_successor_and_retained_default_are_source_bound(self):
        self.assertEqual(watch.FROZEN_APPLICATION, "a7250e15495667b2fcf564cbed1eaa8dea217c45")
        revision = watch.admit_application_revision({"source_commit": "b" * 40}, "b" * 40)
        self.assertEqual(revision, "b" * 40)
        changed = copy.deepcopy(self.report)
        changed["source_revision"] = revision
        verified = watch.validate_watch(self.folder, changed, "ambient2-courtyard", 10,
                                       revision, "fixture-observer", "fixture-engine", "opengl3")
        self.assertEqual(verified["samples"], 11)
        with self.assertRaisesRegex(RuntimeError, "identity mismatch"):
            self.validate(changed)

    def test_complete_synthetic_custody_fixture(self):
        result = self.validate()
        self.assertEqual(result["samples"], 11)
        self.assertEqual(len(result["images"]), 11)

    def test_wrong_application_observer_or_engine_is_refused(self):
        for key in ("source_revision", "observer_script_sha256", "engine_sha256"):
            changed = copy.deepcopy(self.report)
            changed[key] = "wrong"
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, "identity mismatch"):
                self.validate(changed)

    def test_headless_or_wrong_renderer_is_refused(self):
        for key, value in (("display", "headless"), ("renderer", ""), ("rendering_driver", "wrong")):
            changed = copy.deepcopy(self.report)
            changed[key] = value
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, "graphical backend"):
                self.validate(changed)

    def test_short_horizon_or_missing_frame_is_refused(self):
        for key in ("actual_simulation_seconds", "physical_ticks", "native_ticks"):
            changed = copy.deepcopy(self.report)
            changed[key] = 0
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, "horizon"):
                self.validate(changed)
        self.report["samples"].pop()
        with self.assertRaisesRegex(RuntimeError, "Missing or excessive"):
            self.validate()

    def test_duplicate_frozen_progress_and_overstated_time_are_refused(self):
        for key, value in (("diagnostics_physical_tick", 0), ("diagnostics_native_tick", 0),
                           ("simulation_seconds_since_play", 0.0)):
            changed = copy.deepcopy(self.report)
            changed["samples"][1][key] = value
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                self.validate(changed)

    def test_foreign_material_publication_is_refused(self):
        self.report["samples"][2]["capture"]["rendered_actor_frame"]["world_generation"] = 2
        with self.assertRaisesRegex(RuntimeError, "native material identities"):
            self.validate()

    def test_changed_authority_and_nonfinite_pose_are_refused(self):
        changed = copy.deepcopy(self.report)
        changed["samples"][3]["actors"][0]["generation"] = 6
        with self.assertRaisesRegex(RuntimeError, "actor authority"):
            self.validate(changed)
        changed = copy.deepcopy(self.report)
        changed["samples"][3]["actors"][0]["observation"]["position"][0] = float("nan")
        with self.assertRaisesRegex(RuntimeError, "finite copied"):
            self.validate(changed)

    def test_missing_or_escaped_png_is_refused(self):
        changed = copy.deepcopy(self.report)
        changed["samples"][3]["capture"]["path"] = str(self.folder.parent / "frame-0003.png")
        with self.assertRaisesRegex(RuntimeError, "escaped"):
            self.validate(changed)
        (self.folder / "frame-0003.png").unlink()
        with self.assertRaisesRegex(RuntimeError, "escaped"):
            self.validate()

    def test_observation_budget_and_empty_decision_are_refused(self):
        changed = copy.deepcopy(self.report)
        changed["samples"][3]["actors"][0]["memory"]["visited_tail"] = [{}] * 9
        with self.assertRaisesRegex(RuntimeError, "budget"):
            self.validate(changed)
        changed = copy.deepcopy(self.report)
        changed["samples"][3]["actors"][0]["decisions"] = 0
        with self.assertRaisesRegex(RuntimeError, "procedural decision"):
            self.validate(changed)


if __name__ == "__main__":
    unittest.main()

