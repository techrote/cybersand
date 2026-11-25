"""Adversarial readers for raw native progression and paired source witnesses."""
import hashlib
import os
import struct
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zlib

import strata3_predecessor_compare as comparison


def observation(role="predecessor"):
    pose = {"position": [512.0, 842.0], "rotation": 0.0, "linear_velocity": [0.0, 0.0], "angular_velocity": 0.0}
    before = {"native_tick": 0, "rapier_tick": 0, "world_generation": 3, "physical_epoch": 1,
              "worker_id": "-9223371953052580148", "actor_session_id": "313364849859", "actor_body_ids": ["313482290378"]}
    after = dict(before, native_tick=3, rapier_tick=3)
    hashes = {key: hashlib.sha256(key.encode()).hexdigest() for key in ("play", "scripted", "effects", "background")}
    result = {"schema": "strata3-predecessor-observation-v1", "phase": "predecessor-comparison",
              "role": role, "scene": "industrial-underworks", "source_revision": comparison.BASELINE if role == "predecessor" else "a" * 40,
              "driver_sha256": "b" * 64, "completed": True, "checks": 100, "failures": [],
              "display_server": "X11", "rendering_method": "gl_compatibility", "rendering_adapter": "test-software",
              "ordinary_workbench": True, "diagnostic_headless": False, "process_id": 123,
              "admission_target_ms": 45000, "admission_elapsed_ms": 50000, "admission_target_met": False,
              "world_count": {"play_borrowed": 1, "decorative_owned": 3},
              "teardown": {"native_world_count": 0, "pending_native_world_count": 0},
              "initial_plane_native_hashes": hashes, "initial_native_hashes_canonical_json": comparison.canonical(hashes),
              "initial_actor": pose, "extent": [1024, 1024],
              "camera": {"origin": [0, 0], "view_size": [1024, 1024], "world_rect": [420, 135, 750, 750],
                         "window_size": [1600, 1000], "content_scale_factor": 1.0},
              "classic_pixels": {"rgba8_sha256": "d" * 64, "size": [750, 750]},
              "sample": {"before": before, "after": after, "elapsed_usec": 901000, "callbacks": 90,
                         "callback_intervals_usec": [10000] * 90, "main_process_ms": [1.0] * 90,
                         "completed_physical_steps": [{"rapier_tick": n, "completed_usec": 1000000 + n * 200000} for n in range(1, 4)],
                         "physical_intervals_usec": [200000, 200000],
                         "native_publications": [{"native_tick": n, "observed_usec": 1000000 + n * 200000,
                                                  "published_usec": 999000 + n * 200000, "serial": n, "worker_step_ms": 1.0}
                                                 for n in range(1, 4)],
                         "native_ticks_per_second": 3000000 / 901000, "rapier_ticks_per_second": 3000000 / 901000,
                         "actor_before": pose, "actor_after": dict(pose, position=[514.0, 842.0]), "actor_distance_cells": 2.0,
                         "native_capture_delta": 0, "decorative_upload_delta": 0},
              "observer_contract": {"image_readbacks_during_sample": 0, "extra_native_ticks": 0, "extra_worlds": 0,
                                    "physical_gpu_acceptance": False},
              "optical_statistics": {"original_presenter": True, "optical_api_present": False}}
    if role == "candidate":
        result["optical_configuration"] = {"profile": "classic", "enabled": False}
        result["optical_statistics"] = {"active": False}
    return result


def validate(row):
    comparison.validate_observation(row, role=row["role"], source=comparison.BASELINE if row["role"] == "predecessor" else "a" * 40,
                                    driver="b" * 64, scene="industrial-underworks")


class ActualProgressionReader(unittest.TestCase):
    def test_complete_native_population_and_admission_miss_are_retained(self):
        validate(observation())
        validate(observation("candidate"))
        rows = [observation(role) for role in comparison.ORDER]
        result = comparison.compare(rows)
        self.assertEqual(result["medians"]["predecessor"]["admission_elapsed_ms"], 50000)
        self.assertFalse(result["populations"]["candidate"][0]["admission_target_met"])
        self.assertEqual(result["physical_owner_acceptance"], "pending")

    def test_success_exit_and_checks_do_not_hide_missing_physical_records(self):
        row = observation()
        row["sample"] = {}
        with self.assertRaisesRegex(RuntimeError, "Physical owner"):
            validate(row)

    def test_callback_rate_cannot_impersonate_actual_completed_steps(self):
        row = observation()
        row["sample"]["completed_physical_steps"] = []
        row["sample"]["rapier_ticks_per_second"] = 90
        with self.assertRaisesRegex(RuntimeError, "completed Rapier"):
            validate(row)

    def test_missing_step_and_repeated_step_are_rejected(self):
        for tick in (1, 3):
            row = observation()
            row["sample"]["completed_physical_steps"][1]["rapier_tick"] = tick
            with self.assertRaisesRegex(RuntimeError, "sequence"):
                validate(row)

    def test_tail_summary_cannot_omit_actual_stall(self):
        row = observation()
        row["sample"]["physical_intervals_usec"] = [200000, 150000]
        with self.assertRaisesRegex(RuntimeError, "interval tails"):
            validate(row)

    def test_forged_rates_and_callback_window_fail_independently(self):
        row = observation()
        row["sample"]["native_ticks_per_second"] = 60
        with self.assertRaisesRegex(RuntimeError, "rate does not follow"):
            validate(row)
        row = observation()
        row["sample"]["callback_intervals_usec"].pop()
        with self.assertRaisesRegex(RuntimeError, "callback records"):
            validate(row)

    def test_incomplete_native_or_actor_progression_is_rejected(self):
        row = observation()
        row["sample"]["native_publications"] = []
        with self.assertRaisesRegex(RuntimeError, "No native"):
            validate(row)
        row = observation()
        row["sample"]["actor_after"]["position"] = row["initial_actor"]["position"]
        with self.assertRaisesRegex(RuntimeError, "movement differs"):
            validate(row)

    def test_native_owner_swap_and_presentation_recapture_fail(self):
        for field, value in (("worker_id", "999"), ("physical_epoch", 2), ("actor_body_ids", ["888"])):
            row = observation()
            row["sample"]["after"][field] = value
            with self.assertRaisesRegex(RuntimeError, "Physical owner changed"):
                validate(row)
        row = observation()
        row["sample"]["native_capture_delta"] = 1
        with self.assertRaisesRegex(RuntimeError, "recapture"):
            validate(row)

    def test_headless_and_hidden_optical_processing_do_not_qualify(self):
        row = observation()
        row["diagnostic_headless"] = True
        with self.assertRaisesRegex(RuntimeError, "graphical Workbench"):
            validate(row)
        row = observation("candidate")
        row["optical_statistics"]["active"] = True
        with self.assertRaisesRegex(RuntimeError, "disabled exact Classic"):
            validate(row)

    def test_changed_native_geometry_camera_actor_or_image_cannot_form_pair(self):
        for key, value in (("initial_plane_native_hashes", {}), ("camera", {}), ("initial_actor", {}),
                           ("rendering_adapter", "different-hardware"), ("classic_pixels", {"rgba8_sha256": "e" * 64})):
            rows = [observation(role) for role in comparison.ORDER]
            rows[1][key] = value
            with self.assertRaises(RuntimeError):
                comparison.compare(rows)

    def test_missing_repeat_and_reordered_population_fail(self):
        rows = [observation(role) for role in comparison.ORDER]
        with self.assertRaisesRegex(RuntimeError, "six-process"):
            comparison.compare(rows[:-1])
        rows[0], rows[1] = rows[1], rows[0]
        with self.assertRaisesRegex(RuntimeError, "six-process"):
            comparison.compare(rows)

    def test_admission_criterion_cannot_be_weakened(self):
        row = observation()
        row["admission_target_ms"] = 60000
        row["admission_target_met"] = True
        with self.assertRaisesRegex(RuntimeError, "45-second"):
            validate(row)

    def test_presented_fps_is_not_reported_as_physical_owner_acceptance(self):
        row = observation()
        row["observer_contract"]["physical_gpu_acceptance"] = True
        with self.assertRaisesRegex(RuntimeError, "Observer scope"):
            validate(row)


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def test_png(raw, channels=4, width=2, height=2, depth=8, interlace=0):
    return (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, depth, 6 if channels == 4 else 2, 0, 0, interlace))
            + png_chunk(b"IDAT", zlib.compress(raw)) + png_chunk(b"IEND", b""))


class OriginalPixelReader(unittest.TestCase):
    def test_archive_eol_is_portable_without_mutating_inherited_configuration(self):
        environment = {"GIT_CONFIG_COUNT":"1", "GIT_CONFIG_KEY_0":"core.eol", "GIT_CONFIG_VALUE_0":"crlf"}
        with mock.patch.dict(os.environ, environment):
            actual = comparison.archive_environment()
            self.assertEqual(actual["GIT_CONFIG_COUNT"], "3")
            self.assertEqual(actual["GIT_CONFIG_KEY_1"], "core.autocrlf")
            self.assertEqual(actual["GIT_CONFIG_VALUE_1"], "false")
            self.assertEqual(actual["GIT_CONFIG_KEY_2"], "core.eol")
            self.assertEqual(actual["GIT_CONFIG_VALUE_2"], "lf")
            self.assertEqual(actual["GIT_CONFIG_VALUE_0"], "crlf")
            self.assertEqual(actual["GIT_LFS_SKIP_SMUDGE"], "1")
            self.assertEqual(os.environ["GIT_CONFIG_COUNT"], "1")
        with mock.patch.dict(os.environ, {"GIT_CONFIG_COUNT":"invalid"}):
            with self.assertRaisesRegex(RuntimeError, "inherited Git"):
                comparison.archive_environment()

    def test_portable_paths_reject_drive_relative_and_rooted_paths_on_every_host(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "ordinary.png").write_bytes(b"test")
            self.assertEqual(comparison.safe_relative(root, "ordinary.png"), root / "ordinary.png")
            for name in ("/outside.png", "C:/outside.png", "C:outside.png", "../outside.png", "foo\\outside.png", "//server/outside.png"):
                with self.subTest(name=name), self.assertRaisesRegex(RuntimeError, "Unsafe evidence path"):
                    comparison.safe_relative(root, name)

    def test_known_all_five_filters_preserve_every_alpha_byte(self):
        # Two pixels per row, repeated across five independently known filter
        # encodings: None, Sub, Up, Average and Paeth. Alpha is intentionally
        # nonopaque so dropping it cannot satisfy exact-byte custody.
        rows = [bytes([4, 8, 12, 16, 20, 24, 28, 32]), bytes([4, 8, 12, 16, 16, 16, 16, 16]),
                bytes(8), bytes([2, 4, 6, 8, 8, 8, 8, 8]), bytes(8)]
        raw = b"".join(bytes([mode]) + row for mode, row in enumerate(rows))
        width, height, rgba = comparison.png_rgba(test_png(raw, height=5))
        self.assertEqual((width, height), (2, 5))
        self.assertEqual(rgba, bytes([4, 8, 12, 16, 20, 24, 28, 32]) * 5)

    def test_rgb_expands_only_opaque_alpha(self):
        raw = b"\0\x01\x02\x03\x04\x05\x06\0\x07\x08\x09\x0a\x0b\x0c"
        self.assertEqual(comparison.png_rgba(test_png(raw, channels=3))[2],
                         bytes([1, 2, 3, 255, 4, 5, 6, 255, 7, 8, 9, 255, 10, 11, 12, 255]))

    def test_crc_truncation_trailing_bytes_and_extra_scanlines_are_rejected(self):
        raw = b"\0" + bytes(8) + b"\0" + bytes(8)
        valid = test_png(raw)
        bad_crc = bytearray(valid)
        bad_crc[40] ^= 1
        for data in (bytes(bad_crc), valid[:-1], valid + b"x", test_png(raw + b"\0")):
            with self.assertRaises(RuntimeError):
                comparison.png_rgba(data)

    def test_unsupported_extent_bit_depth_interlace_and_filter_are_rejected(self):
        raw = b"\0" + bytes(8) + b"\0" + bytes(8)
        for data in (test_png(raw, width=4097), test_png(raw, depth=16), test_png(raw, interlace=1),
                     test_png(b"\5" + bytes(8) + b"\0" + bytes(8))):
            with self.assertRaises(RuntimeError):
                comparison.png_rgba(data)


if __name__ == "__main__":
    unittest.main()
