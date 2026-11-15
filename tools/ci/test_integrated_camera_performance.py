#!/usr/bin/env python3
"""Guard executable custody and distinguish native work from repeated publications."""
from pathlib import Path
import copy
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


class ClockPhaseTests(unittest.TestCase):
    def data(self):
        start = {"sampled_usec": 1_000_000, "world_generation": 3, "uploaded_world_generation": 3,
                 "physical_epoch": 2, "rapier_bridge_object": 700, "rapier_initialized": True,
                 "actor_session_object": 800, "actor_session_epoch": 2,
                 "tick": 7, "completed_rapier_steps": 10, "completed_actor_steps": 10,
                 "successful_uploads": 4, "snapshot_published_usec": 995_000, "snapshot_age_ms": 5,
                 "current_uploaded_material_generated_usec": 900_000, "current_uploaded_material_age_ms": 100}
        first = dict(start, sampled_usec=1_250_000, tick=9, completed_rapier_steps=12,
                     completed_actor_steps=12, snapshot_published_usec=1_240_000,
                     snapshot_age_ms=10, current_uploaded_material_age_ms=350)
        last = dict(first, sampled_usec=1_500_000, tick=10, completed_rapier_steps=15,
                    completed_actor_steps=15, successful_uploads=5, snapshot_published_usec=1_490_000,
                    current_uploaded_material_generated_usec=1_400_000, current_uploaded_material_age_ms=100)
        return {"clock_schema": "integrated-camera-clocks-v1", "measurement_start": start, "frames": [first, last]}

    def test_completed_steps_and_successful_uploads_use_full_phase_elapsed_time(self):
        result = subject.clock_phase_metrics(self.data())
        self.assertEqual(result["elapsed_seconds"], .5)
        self.assertEqual(result["counts"], {"native_ticks": 3, "rapier_steps": 5, "actor_steps": 5,
                                            "successful_uploads": 1, "rendered_frame_observations": 2})
        self.assertEqual(result["rates_hz"]["rapier_steps"], 10)
        self.assertEqual(result["rates_hz"]["successful_uploads"], 2)
        self.assertEqual(result["ages"]["current_uploaded_material_age_ms"]["max"], 350)

    def test_paused_repeated_status_publications_are_zero_completed_work(self):
        data = self.data()
        for frame in data["frames"]:
            for key in subject.CLOCK_COUNTER_FIELDS.values():
                frame[key] = data["measurement_start"][key]
            frame["current_uploaded_material_generated_usec"] = 900_000
            frame["current_uploaded_material_age_ms"] = (frame["sampled_usec"] - 900_000) / 1000
        result = subject.clock_phase_metrics(data)
        for key in ("native_ticks", "rapier_steps", "actor_steps", "successful_uploads"):
            self.assertEqual(result["counts"][key], 0)
            self.assertEqual(result["rates_hz"][key], 0)
        self.assertEqual(result["ages"]["current_uploaded_material_age_ms"]["max"], 600)

    def test_intermediate_identity_replacement_or_counter_restart_is_rejected(self):
        for key in ("world_generation", "uploaded_world_generation", "physical_epoch",
                    "rapier_bridge_object", "actor_session_object", "actor_session_epoch"):
            with self.subTest(identity=key):
                data = self.data()
                data["frames"][0][key] += 1
                with self.assertRaisesRegex(ValueError, "identity changed"):
                    subject.clock_phase_metrics(data)
        for key in subject.CLOCK_COUNTER_FIELDS.values():
            with self.subTest(counter=key):
                data = self.data()
                data["frames"][0][key] = data["measurement_start"][key] - 1
                with self.assertRaisesRegex(ValueError, "counter restarted"):
                    subject.clock_phase_metrics(data)

    def test_missing_age_and_absent_actor_are_unavailable_not_zero(self):
        data = self.data()
        for row in [data["measurement_start"], *data["frames"]]:
            row.update(actor_session_object=0, actor_session_epoch=0, completed_actor_steps=None)
            for age, timestamp in subject.CLOCK_AGE_FIELDS.items():
                row[age] = row[timestamp] = None
        result = subject.clock_phase_metrics(data)
        self.assertIsNone(result["counts"]["actor_steps"])
        self.assertIsNone(result["rates_hz"]["actor_steps"])
        self.assertEqual(result["ages"]["snapshot_age_ms"], {"count": 0, "unavailable_samples": 2})

    def test_timestamp_cannot_refresh_on_a_repeated_or_failed_upload(self):
        data = self.data()
        data["frames"][0].update(current_uploaded_material_generated_usec=1_100_000,
                                 current_uploaded_material_age_ms=150)
        with self.assertRaisesRegex(ValueError, "without a successful upload"):
            subject.clock_phase_metrics(data)

    def test_bad_timestamp_age_or_clock_is_rejected(self):
        for patch in ({"snapshot_age_ms": -1}, {"snapshot_published_usec": 1_300_000},
                      {"snapshot_age_ms": 0}, {"sampled_usec": 1_000_000}):
            with self.subTest(patch=patch):
                data = self.data()
                data["frames"][0].update(patch)
                with self.assertRaises(ValueError): subject.clock_phase_metrics(data)

    def test_legacy_receipt_remains_explicitly_unmeasured(self):
        self.assertFalse(subject.clock_phase_metrics({})["available"])

    def test_abba_pool_uses_elapsed_weighting_and_keeps_individual_phases(self):
        arms = []
        for phase, scale in enumerate((1, 2)):
            data = self.data()
            for frame in data["frames"]:
                frame["sampled_usec"] = 1_000_000 + scale * (frame["sampled_usec"] - 1_000_000)
                for age, timestamp in subject.CLOCK_AGE_FIELDS.items():
                    frame[age] = (frame["sampled_usec"] - frame[timestamp]) / 1000
                frame.update(frame_ms=250 * scale, main_process_ms=1, shader_update_ms=1,
                             snapshot_consume_ms=1, worker_frame_state_ms=1, godot_process_ms=1)
            data.update(publications=[], uploads=[], actions=[], summary={"frame_ms": {"p50": 250 * scale, "p95": 250 * scale}})
            arms.append({"case": "clock-control", "subject": "A", "round": 0, "phase": phase,
                         "source_commit": "source", "data": data, "process": {}})
        result = subject.reduce_runs(arms)[0]["subjects"]["A"]["clock_metrics"]
        self.assertTrue(result["available"])
        self.assertEqual([phase["rates_hz"]["native_ticks"] for phase in result["phases"]], [6, 3])
        self.assertEqual(result["pooled_rates_hz"]["native_ticks"], 4)
        self.assertEqual(result["ages"]["snapshot_age_ms"]["count"], 4)


class PhysicalGeometryTests(unittest.TestCase):
    def data(self):
        return {"actual_window": [960,720], "world_extent": [512,512], "worker_capacity": 1,
                "native_backend": "native-phased", "view_content_rect": [0,0,1880,710],
                "actual_pixel_scale": [2.5,2.5], "physical_view_transform": [.5,0,0,.5,10,267],
                "root_final_transform": [.5,0,0,.5,0,90], "root_content_scale_size": [1920,1080],
                "root_content_scale_mode": 1, "root_content_scale_aspect": 1, "root_embed_subwindows": True,
                "root_framebuffer_size": [960,540], "physical_content_rect": [10,267,940,355],
                "frames": [{"view": [376,142], "physical_pixel_scale": [2.5,2.5], "camera": [64,64]},
                           {"view": [376,142], "physical_pixel_scale": [2.5,2.5], "camera": [64.1,64]}]}

    def test_controlled_physical_geometry_matches_despite_intended_camera_difference(self):
        data, prior = self.data(), self.data()
        prior["frames"][1]["camera"] = [64,64]
        subject.verify_geometry_parity(data, prior)

    def test_changed_window_raster_or_physical_zoom_is_refused(self):
        for key, value in (("actual_window", [1280,960]), ("root_framebuffer_size", [1280,720]),
                           ("actual_pixel_scale", [1.25,1.25]), ("physical_view_transform", [1,0,0,1,20,354])):
            with self.subTest(key=key):
                data, prior = self.data(), self.data()
                data[key] = value
                with self.assertRaisesRegex(ValueError, key): subject.verify_geometry_parity(data, prior)

    def test_zoom_sequence_mismatch_is_refused_even_with_matching_final_view(self):
        data = self.data()
        prior = copy.deepcopy(data)
        data["frames"][0]["view"] = [300,113]
        with self.assertRaisesRegex(ValueError, "per-frame.*view"):
            subject.verify_geometry_parity(data, prior)


if __name__ == "__main__":
    unittest.main()
