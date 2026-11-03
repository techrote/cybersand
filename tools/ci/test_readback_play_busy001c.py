#!/usr/bin/env python3
"""Synthetic adverse controls for the 001C reader; never gameplay evidence."""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

import readback_play_busy001c as reader


def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)


def png(width: int, height: int, pixels: bytes, *, colour: int = 6,
        filters: list[int] | None = None, extra: bytes = b"") -> bytes:
    channels = 4 if colour == 6 else 3
    stride = width * channels
    scanlines = bytearray()
    for y in range(height):
        method = filters[y % len(filters)] if filters else 0
        scanlines.append(method)
        for x in range(stride):
            actual = pixels[y * stride + x]
            left = pixels[y * stride + x - channels] if x >= channels else 0
            above = pixels[(y - 1) * stride + x] if y else 0
            corner = pixels[(y - 1) * stride + x - channels] if y and x >= channels else 0
            if method == 0:
                predictor = 0
            elif method == 1:
                predictor = left
            elif method == 2:
                predictor = above
            elif method == 3:
                predictor = (left + above) // 2
            else:
                # Reference Paeth expressed as stable minimum over PNG's tie order.
                p = left + above - corner
                predictor = min((left, above, corner), key=lambda value: abs(p - value))
            scanlines.append((actual - predictor) % 256)
    return (reader.PNG_MAGIC + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colour, 0, 0, 0))
            + extra + chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b""))


def band_pixels(blue: int) -> bytes:
    # Eight horizontal and vertical colour bands: exactly 64 sampled buckets.
    # Raising blue by64 changes every one of the 160*90 samples by >0.04.
    return b"".join(b"".join(bytes((x * 32, (y // 45) * 32, blue, 255)) * 80
                            for x in range(8)) for y in range(360))


BEFORE = band_pixels(0)
AFTER = band_pixels(64)
BEFORE_PNG = png(640, 360, BEFORE)
AFTER_PNG = png(640, 360, AFTER)


class EvidenceControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.args = argparse.Namespace(log=self.root / "render-execution.log", evidence_dir=self.root,
            process_receipt=self.root / "process.json", source_sha="a" * 40,
            runtime=self.root / "native.so", rapier=self.root / "rapier.so",
            godot_version="SYNTHETIC-CONTROL-NOT-ENGINE-EVIDENCE", platform="linux",
            output=self.root / "readback.json")
        self.args.runtime.write_bytes(b"SYNTHETIC native runtime")
        self.args.rapier.write_bytes(b"SYNTHETIC Rapier runtime")
        engine = self.root / "godot"
        engine.write_bytes(b"SYNTHETIC Godot identity")
        (self.root / "held-before.png").write_bytes(BEFORE_PNG)
        (self.root / "held-after.png").write_bytes(AFTER_PNG)
        self.held = {"generation": 1, "tick": 6, "phase": 2, "expected_tasks": 4,
            "minimum_claims": 2, "entered": 4, "waiting": 4, "active": 4,
            "completed": 0, "distinct_threads": 4, "stop_waiting": 0, "stop_active": 0,
            "dispatch_started_sequence": 1, "first_arrival_sequence": 2,
            "stop_sequence": 0, "release_sequence": 0, "drained_sequence": 0,
            "dispatch_return_sequence": 0, "armed": True, "selected": True,
            "released": False, "timed_out": False, "thread_identity_overflow": False,
            "scope": "SYNTHETIC copied native gate"}
        final = {**self.held, "active": 0, "waiting": 0, "completed": 4,
                 "armed": False, "released": True, "release_sequence": 3,
                 "drained_sequence": 4, "dispatch_return_sequence": 5}
        self.row = {"assertions": 32, "failures": 0, "elapsed_ms": 1000,
            "display_server": "X11", "rendering_driver": "opengl3", "rig": "jetbarrel",
            "process_pid": 212, "process_nonce": "b" * 32, "source_sha": "a" * 40,
            "native_phase_tick": 6, "native_phase": 2, "native_phase_jobs_held": 4,
            "native_phase_tasks": 4, "main_callbacks_during_hold": 7,
            "physics_callbacks_during_hold": 33, "input_callbacks_during_hold": 2,
            "rapier_steps_during_hold": 33, "actor_motion_pixels": 22.5,
            "framebuffer": [640, 360], "first_colour_buckets": 64, "second_colour_buckets": 64,
            "changed_samples_4px_grid": 14400, "source_snapshot_unchanged_during_hold": True,
            "rendered_frame_during_real_native_hold": True, "actual_frame_post_draw": True,
            "gate_receipt": final, "retries": 0, "physical_gamepad_qualified": False,
            "human_feel_qualified": False, "retirement": {"worker_joined": True,
                "session_retired": True, "main_freed": True}}
        self.events = [{"stage": stage, "elapsed_ms": 1000 + index * 100}
                       for index, stage in enumerate(reader.STAGES)]
        self.event("display_ready").update(display_server="X11", driver="opengl3",
            content_scale_pixels=[960, 540], window_pixels=[960, 540], process_pid=212,
            process_nonce="b" * 32, source_sha="a" * 40)
        self.event("native_phase_wake_queued").update(paint_requested=4, paint_admitted=4)
        self.event("native_phase_held").update(self.held)
        for stage in ("first_capture_end", "second_capture_end"):
            self.event(stage).update(ok=True, gate=copy.deepcopy(self.held))
        self.event("native_dispatch_returned").update(final)
        self.process = {"schema": "play-busy001c-process-v1", "source_sha": "a" * 40,
            "platform": "linux", "pid": 212, "launcher_pid": 212, "nonce": "b" * 32,
            "status": "completed", "error": None, "qualification": "original-host-process",
            "source_tree": "d" * 40,
            "argv": [str(engine), "--windowed", "--resolution", "960x540", "--rendering-method",
                     "gl_compatibility", "--display-driver", "x11", "--path", "godot",
                     "--script", "res://tests/play_busy001c_render.gd"],
            "returncode": 0, "timed_out": False, "cleanup_complete": True,
            "forced_cleanup": False, "budgets": copy.deepcopy(reader.BUDGETS),
            "identities": {"engine": reader.file_identity(engine),
                           "runtime": reader.file_identity(self.args.runtime),
                           "rapier": reader.file_identity(self.args.rapier)},
            "observed_processes": {"212": {"pid": 212, "parent_pid": 100, "creation_time": 12345.1, "role": "host"}}}
        self.write()

    def tearDown(self):
        self.temporary.cleanup()

    def event(self, stage: str) -> dict:
        return next(item for item in self.events if item["stage"] == stage)

    def write(self):
        self.args.log.write_text("\n".join(reader.PROGRESS_PREFIX + json.dumps(event) for event in self.events)
                                 + "\n" + reader.PREFIX + json.dumps(self.row) + "\n", encoding="utf-8")
        self.process["identities"]["log"] = reader.file_identity(self.args.log)
        self.write_process()

    def write_process(self):
        self.args.process_receipt.write_text(json.dumps(self.process), encoding="utf-8")

    def refuse(self, match: str):
        with self.assertRaisesRegex(ValueError, match):
            reader.readback(self.args)

    def test_original_process_and_exact_independent_pixels_pass(self):
        result = reader.readback(self.args)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["independent_pixels"]["colour_buckets"], [64, 64])
        self.assertEqual(result["independent_pixels"]["changed_samples_4px_grid"], 14400)
        self.assertFalse(result["scope"]["physical_device_focus"])
        self.assertFalse(result["scope"]["human_feel"])

    def test_windows_console_wrapper_requires_observed_descendant(self):
        self.args.platform = self.process["platform"] = "windows"
        self.row["display_server"] = "Windows"
        self.row["rendering_driver"] = "opengl3_angle"
        self.event("display_ready").update(display_server="Windows", driver="opengl3_angle")
        self.process["launcher_pid"] = 211
        self.process["observed_processes"]["212"]["parent_pid"] = 211
        self.process["observed_processes"]["211"] = {"pid": 211, "parent_pid": 100, "creation_time": 12345.0, "role": "host"}
        self.write()
        self.assertEqual(reader.readback(self.args)["status"], "passed")
        del self.process["observed_processes"]["211"]
        self.write_process()
        self.refuse("observation absent")

    def test_v1_truncated_png_counterexample_is_rejected(self):
        for name, suffix in (("held-before.png", b"a"), ("held-after.png", b"b")):
            (self.root / name).write_bytes(reader.PNG_MAGIC + struct.pack(">I", 13)
                                          + b"IHDR" + struct.pack(">II", 640, 360) + suffix)
        self.refuse("truncated PNG")

    def test_crc_corruption_is_rejected(self):
        data = bytearray(BEFORE_PNG)
        data[50] ^= 1
        (self.root / "held-before.png").write_bytes(data)
        self.refuse("CRC mismatch")

    def test_different_png_metadata_cannot_impersonate_changed_pixels(self):
        (self.root / "held-after.png").write_bytes(png(640, 360, BEFORE, extra=chunk(b"tEXt", b"note\0different")))
        self.refuse("pixel differences")

    def test_false_reported_colour_buckets_are_rejected(self):
        self.row["first_colour_buckets"] = 65
        self.write()
        self.refuse("colour buckets differ")

    def test_false_reported_pixel_changes_are_rejected(self):
        self.row["changed_samples_4px_grid"] = 14399
        self.write()
        self.refuse("pixel differences")

    def test_blank_pixels_cannot_borrow_fixture_claims(self):
        (self.root / "held-before.png").write_bytes(png(640, 360, bytes([0, 0, 0, 255]) * (640 * 360)))
        self.refuse("colour buckets differ")

    def test_missing_png_is_rejected(self):
        (self.root / "held-after.png").unlink()
        self.refuse("missing or oversized PNG")

    def test_capture_from_different_dispatch_is_rejected(self):
        self.event("second_capture_end")["gate"]["generation"] = 2
        self.write()
        self.refuse("different native dispatches")

    def test_premature_gate_release_is_rejected(self):
        self.event("first_capture_end")["gate"]["released"] = True
        self.write()
        self.refuse("held gate flag")

    def test_native_dispatch_return_before_manual_release_is_rejected(self):
        self.row["gate_receipt"]["release_sequence"] = 6
        self.event("native_dispatch_returned")["release_sequence"] = 6
        self.write()
        self.refuse("release/drain/return order")

    def test_incomplete_owner_retirement_is_rejected(self):
        for key in self.row["retirement"]:
            with self.subTest(key=key):
                self.row["retirement"][key] = False
                self.write()
                self.refuse("retirement incomplete")
                self.row["retirement"][key] = True

    def test_missing_graphical_identity_and_assertion_count_are_rejected(self):
        for key in ("display_server", "rendering_driver", "assertions"):
            with self.subTest(key=key):
                saved = self.row.pop(key)
                self.write()
                self.refuse("DisplayServer|driver|assertions")
                self.row[key] = saved

    def test_duplicate_or_missing_progress_stages_are_rejected(self):
        original = copy.deepcopy(self.events)
        for events in (original + [original[-1]], original[:-1], list(reversed(original))):
            self.events = events
            self.write()
            self.refuse("progress stages")

    def test_duplicate_result_is_rejected(self):
        with self.args.log.open("a") as handle:
            handle.write(reader.PREFIX + json.dumps(self.row) + "\n")
        self.refuse("exactly one original")

    def test_duplicate_json_key_is_rejected(self):
        text = self.args.log.read_text().replace('"failures": 0', '"failures": 1, "failures": 0')
        self.args.log.write_text(text)
        self.refuse("duplicate JSON key")

    def test_nan_and_infinite_actor_motion_are_rejected(self):
        for value in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(value=value):
                self.row["actor_motion_pixels"] = value
                self.write()
                self.refuse("nonfinite JSON")
        self.row["actor_motion_pixels"] = 1
        self.write()
        self.args.log.write_text(self.args.log.read_text().replace('"actor_motion_pixels": 1', '"actor_motion_pixels": 1e999'))
        self.refuse("finite number")

    def test_boolean_cannot_impersonate_numeric_observation(self):
        self.row["failures"] = False
        self.write()
        self.refuse("fixture failures")

    def test_arbitrary_or_mismatched_source_is_rejected(self):
        self.args.source_sha = "not-a-sha"
        self.refuse("full commit identity")
        self.args.source_sha = "c" * 40
        self.refuse("source SHA differs")

    def test_source_nonce_and_pid_are_bound_to_original_process(self):
        for key, value, message in (("process_nonce", "c" * 32, "identity differs"),
                                    ("process_pid", 213, "identity differs"),
                                    ("source_sha", "c" * 40, "identity differs")):
            with self.subTest(key=key):
                saved = self.row[key]
                self.row[key] = value
                self.write()
                self.refuse(message)
                self.row[key] = saved

    def test_failed_or_forcibly_cleaned_process_cannot_qualify(self):
        for key, value in (("returncode", 1), ("timed_out", True),
                           ("forced_cleanup", True), ("cleanup_complete", False)):
            with self.subTest(key=key):
                saved = self.process[key]
                self.process[key] = value
                self.write_process()
                self.refuse("exit successfully|retirement refused")
                self.process[key] = saved

    def test_observed_pid_requires_creation_identity(self):
        del self.process["observed_processes"]["212"]["creation_time"]
        self.write_process()
        self.refuse("creation identity absent")

    def test_log_and_runtime_hashes_must_match_original_process(self):
        for key in ("log", "runtime", "rapier", "engine"):
            with self.subTest(key=key):
                saved = self.process["identities"][key]["sha256"]
                self.process["identities"][key]["sha256"] = "0" * 64
                self.write_process()
                self.refuse("original " + key + " bytes differ")
                self.process["identities"][key]["sha256"] = saved

    def test_flat_legacy_identity_shape_cannot_qualify(self):
        self.process.update(self.process.pop("identities"))
        self.write_process()
        self.refuse("nested original file identities absent")

    def test_slow_force_draw_is_inside_original_capture_budget(self):
        # force_draw can block before frame_post_draw; its time must not vanish
        # merely because the callback fires before GDScript resumes.
        start = self.event("first_capture_begin")["elapsed_ms"]
        for event in self.events:
            if event["elapsed_ms"] > start:
                event["elapsed_ms"] += 2500
        self.write()
        self.refuse("original 2500ms wall budget")

    def test_incomplete_receipt_and_diagnostic_child_cannot_qualify(self):
        for key, value in (("status", "incomplete"), ("error", "lost process"),
                           ("qualification", "diagnostic-child")):
            with self.subTest(key=key):
                saved = self.process[key]
                self.process[key] = value
                self.write_process()
                self.refuse("not completed qualification")
                self.process[key] = saved

    def test_relocated_original_engine_preserves_untouched_receipt(self):
        original = self.process["identities"]["engine"]
        relocated = self.root / "downloaded-engine"
        relocated.write_bytes(Path(original["path"]).read_bytes())
        original["path"] = "/missing/original/runner/engine"
        self.write_process()
        with self.assertRaisesRegex(ValueError, "missing or empty file"):
            reader.readback(self.args)
        self.args.engine = relocated
        receipt_bytes = self.args.process_receipt.read_bytes()
        self.assertEqual(reader.readback(self.args)["status"], "passed")
        self.assertEqual(self.args.process_receipt.read_bytes(), receipt_bytes)
        relocated.write_bytes(b"different engine")
        self.refuse("original engine bytes differ")

    def test_diagnostic_descendant_cannot_supply_original_engine_evidence(self):
        self.process["observed_processes"]["212"]["role"] = "diagnostic"
        self.write_process()
        self.refuse("cannot supply original host evidence")

    def test_changed_execution_budgets_are_rejected(self):
        self.process["budgets"]["absolute_seconds"] = 121
        self.write_process()
        self.refuse("execution budgets differ")

    def test_headless_or_wrong_fixture_command_is_rejected(self):
        self.process["argv"].append("--headless")
        self.write_process()
        self.refuse("headless command")
        self.process["argv"].pop()
        self.process["argv"][-1] = "res://different.gd"
        self.write_process()
        self.refuse("command differs")

    def test_script_error_cannot_be_hidden_by_success_marker(self):
        with self.args.log.open("a") as handle:
            handle.write("SCRIPT ERROR: invalid run\n")
        self.refuse("error or timeout")

    def test_cli_refuses_the_original_malformed_png_case(self):
        (self.root / "held-before.png").write_bytes(b"invalid")
        command = [sys.executable, str(Path(reader.__file__).resolve())]
        for key in ("log", "evidence_dir", "process_receipt", "source_sha", "runtime", "rapier",
                    "godot_version", "platform", "output"):
            command += ["--" + key.replace("_", "-"), str(getattr(self.args, key))]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(self.args.output.read_text())["status"], "failed")


class PixelDecoderControls(unittest.TestCase):
    def test_all_five_png_filters_decode_exact_original_bytes(self):
        pixels = bytes((index * 23 + 11) % 256 for index in range(7 * 5 * 4))
        self.assertEqual(reader.decode_png(png(7, 5, pixels, filters=[0, 1, 2, 3, 4])), (7, 5, pixels))

    def test_rgb_is_decoded_with_opaque_alpha(self):
        self.assertEqual(reader.decode_png(png(2, 1, b"\x01\x02\x03\x04\x05\x06", colour=2)),
                         (2, 1, b"\x01\x02\x03\xff\x04\x05\x06\xff"))

    def test_missing_iend_and_trailing_data_are_rejected(self):
        source = png(1, 1, b"\x01\x02\x03\xff")
        for broken in (source[:-12], source + b"tail"):
            with self.assertRaisesRegex(ValueError, "incomplete PNG|trailing bytes"):
                reader.decode_png(broken)

    def test_invalid_filter_and_zlib_byte_count_are_rejected(self):
        header = reader.PNG_MAGIC + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
        for raw, message in ((b"\x05\x01\x02\x03\xff", "unknown PNG row filter"),
                             (b"\0" * 6, "decompressed length"), (b"\0" * 4, "decompressed length")):
            with self.assertRaisesRegex(ValueError, message):
                reader.decode_png(header + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))

    def test_oversized_dimensions_fail_before_decompression(self):
        header = reader.PNG_MAGIC + chunk(b"IHDR", struct.pack(">IIBBBBB", 999999, 999999, 8, 6, 0, 0, 0))
        with self.assertRaisesRegex(ValueError, "capacity"):
            reader.decode_png(header + chunk(b"IDAT", zlib.compress(b"\0")) + chunk(b"IEND", b""))

    def test_original_rgb_threshold_ignores_alpha_and_requires_sum_above_10(self):
        first = bytes([0, 0, 0, 0])
        self.assertEqual(reader.changed_samples(1, 1, first, bytes([0, 0, 0, 255])), 0)
        self.assertEqual(reader.changed_samples(1, 1, first, bytes([3, 3, 4, 255])), 0)
        self.assertEqual(reader.changed_samples(1, 1, first, bytes([3, 4, 4, 0])), 1)


if __name__ == "__main__":
    unittest.main()
