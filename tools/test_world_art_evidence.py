"""Adversarial unit regressions for World Art evidence and process ownership.

The tiny PNGs below are explicitly synthetic validator fixtures. They do not
render artwork and never count as graphical qualification or gallery evidence.
"""
from __future__ import annotations

from copy import deepcopy
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent))
import world_art_capture_support as support
import world_art_preview_launcher as launcher


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def validator_png(*, filter_byte: int = 0, compression: int = 0, filtering: int = 0,
                  split_idat: bool = False) -> bytes:
    rows = b"".join(bytes([filter_byte]) + bytes((x * 19 + y * 31) % 256 for x in range(24)) for y in range(4))
    encoded = zlib.compress(rows)
    if split_idat:
        middle = len(encoded) // 2
        body = (chunk(b"IDAT", encoded[:middle]) + chunk(b"tEXt", b"unit\x00split")
                + chunk(b"IDAT", encoded[middle:]))
    else:
        body = chunk(b"IDAT", encoded)
    return (support.PNG_SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", 8, 4, 8, 2, compression, filtering, 0))
            + body + chunk(b"IEND", b""))


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bundle = self.root / "bundle"
        job_dir = self.bundle / "01-fixture"
        job_dir.mkdir(parents=True)
        (job_dir / "full.png").write_bytes(validator_png())
        self.pack = self.root / "unit-fixture.json"
        self.pack.write_text('{"purpose":"synthetic validator unit test; not rendered art"}\n', encoding="utf-8")
        pack_hash = support.sha256_file(self.pack)
        self.job = {
            "schema": support.SCHEMA_JOB, "status": "complete",
            "input_pack": {"path": str(self.pack), "sha256": pack_hash},
            "job": {"id": "01-fixture", "collection": "fixture", "pack_path": str(self.pack),
                    "pack_sha256_expected": pack_hash},
            "viewer": {"source": "synthetic-unit-fixture"}, "art_source": {"revision": "unit-fixture"},
            "renderer": {"rendering_method": "unit", "rendering_driver": "unit", "graphics_adapter": "unit"},
            "presentation": {"time": 1.37}, "art_size_policy": support.classify_art_dimensions(8, 4),
            "shots": [{"id": "full", "file": "full.png", "kind": "full", "status": "complete",
                       "width": 8, "height": 4, "png_sha256": support.sha256_file(job_dir / "full.png"),
                       "stats": {"nonblank": True}, "source": {"native_width": 8, "native_height": 4,
                           "rg8_sha256": support.sha256_bytes(b"synthetic unit RG8 fixture")},
                       "camera": {"scale": 1}}],
        }
        self.batch = {
            "schema": support.SCHEMA_BATCH, "status": "completed", "failures": [],
            "allow_blank": False, "viewer": self.job["viewer"], "art_source": self.job["art_source"],
            "presentation": self.job["presentation"], "engine": {"synthetic_unit_fixture": True},
            "source_guard": {"unchanged": True, "changes": []},
            "jobs": [{"id": "01-fixture", "status": "complete", "collection": "fixture",
                      "pack_path": str(self.pack), "pack_sha256": pack_hash,
                      "manifest": "01-fixture/manifest.json", "manifest_sha256": "",
                      "art_size_policy": self.job["art_size_policy"], "renderer": self.job["renderer"],
                      "shots": support.shot_summary("01-fixture", self.job["shots"])}],
        }
        self.save_job(self.job, self.batch)
        self.save_batch(self.batch)
        self.assertEqual(support.verify_bundle(self.bundle)[1], [], "baseline synthetic validator fixture must be valid")

    def save_batch(self, batch: dict):
        (self.bundle / "batch-manifest.json").write_text(json.dumps(support.seal_manifest(batch)), encoding="utf-8")

    def save_job(self, job: dict, batch: dict):
        path = self.bundle / "01-fixture/manifest.json"
        path.write_text(json.dumps(job), encoding="utf-8")
        batch["jobs"][0]["manifest_sha256"] = support.sha256_file(path)

    def assert_refused(self):
        _, problems = support.verify_bundle(self.bundle)
        self.assertTrue(problems, "altered evidence was accepted")

    def test_resealed_batch_cannot_change_verified_shot_inventory(self):
        for key, changed in (("file", "01-fixture/other.png"), ("id", "different"), ("kind", "viewport"),
                             ("width", 9), ("height", 5), ("png_sha256", "0" * 64)):
            with self.subTest(key=key):
                batch = deepcopy(self.batch)
                batch["jobs"][0]["shots"][0][key] = changed
                self.save_batch(batch)
                self.assert_refused()

    def test_resealed_batch_cannot_change_job_status_or_source_identity(self):
        for key, changed in (("status", "failed"), ("collection", "another-collection"),
                             ("pack_sha256", "0" * 64), ("pack_path", "another.json"),
                             ("art_size_policy", {}), ("renderer", {})):
            with self.subTest(key=key):
                batch = deepcopy(self.batch)
                batch["jobs"][0][key] = changed
                self.save_batch(batch)
                self.assert_refused()

    def test_malformed_batch_objects_fail_with_problems(self):
        for key in ("viewer", "art_source", "engine", "presentation", "source_guard"):
            for value in (None, [], "invalid"):
                with self.subTest(key=key, value=value):
                    batch = deepcopy(self.batch)
                    batch[key] = value
                    self.save_batch(batch)
                    self.assert_refused()
        for value in (None, {}, [], [None], ["invalid"]):
            with self.subTest(jobs=value):
                batch = deepcopy(self.batch)
                batch["jobs"] = value
                self.save_batch(batch)
                self.assert_refused()

    def test_duplicate_job_ids_are_refused(self):
        batch = deepcopy(self.batch)
        batch["jobs"].append(deepcopy(batch["jobs"][0]))
        self.save_batch(batch)
        self.assert_refused()

    def test_comparison_validates_required_source_and_collection_fields(self):
        self.assertTrue(support.compare_bundles(self.bundle, self.bundle)["comparable"])
        for field, value in (("rg8_sha256", None), ("rg8_sha256", "not a digest"),
                             ("collection", []), ("collection", "")):
            with self.subTest(field=field, value=value):
                job, batch = deepcopy(self.job), deepcopy(self.batch)
                if field == "collection":
                    job["job"][field] = value
                    batch["jobs"][0][field] = value
                else:
                    job["shots"][0]["source"][field] = value
                self.save_job(job, batch)
                self.save_batch(batch)
                self.assert_refused()
                self.assertFalse(support.compare_bundles(self.bundle, self.bundle)["comparable"])

    def test_malformed_job_objects_and_shots_fail_with_problems(self):
        for key in ("input_pack", "job", "viewer", "art_source", "renderer", "presentation", "shots"):
            with self.subTest(key=key):
                job, batch = deepcopy(self.job), deepcopy(self.batch)
                job[key] = None
                self.save_job(job, batch)
                self.save_batch(batch)
                self.assert_refused()
        for value in ({}, [], [None], ["bad"]):
            job, batch = deepcopy(self.job), deepcopy(self.batch)
            job["shots"] = value
            self.save_job(job, batch)
            self.save_batch(batch)
            self.assert_refused()

    def test_malformed_shot_metadata_and_duplicate_shots_are_refused(self):
        for key in ("stats", "source", "camera"):
            with self.subTest(key=key):
                job, batch = deepcopy(self.job), deepcopy(self.batch)
                job["shots"][0][key] = []
                self.save_job(job, batch)
                self.save_batch(batch)
                self.assert_refused()
        job, batch = deepcopy(self.job), deepcopy(self.batch)
        job["shots"].append(deepcopy(job["shots"][0]))
        self.save_job(job, batch)
        self.save_batch(batch)
        self.assert_refused()

    def test_failed_source_guard_and_nonboolean_blank_flag_are_refused(self):
        for key, value in (("source_guard", {"unchanged": False, "changes": []}),
                           ("source_guard", {"unchanged": True, "changes": ["changed"]}),
                           ("failures", ["render failed"]), ("allow_blank", "false")):
            with self.subTest(key=key, value=value):
                batch = deepcopy(self.batch)
                batch[key] = value
                self.save_batch(batch)
                self.assert_refused()

    def test_absolute_traversal_and_windows_paths_are_refused(self):
        for name in ("/tmp/escape", "../escape", "C:/escape", "C:\\escape", "job/../escape", "job//full.png"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                support.evidence_path(self.bundle, name)
        for name in ("../escape", "/absolute", "C:/escape"):
            with self.subTest(manifest=name):
                batch = deepcopy(self.batch)
                batch["jobs"][0]["id"] = name
                batch["jobs"][0]["manifest"] = name + "/manifest.json"
                self.save_batch(batch)
                self.assert_refused()

    def test_symlinked_png_and_manifest_are_refused(self):
        for member in ("full.png", "manifest.json"):
            with self.subTest(member=member):
                target = self.bundle / "01-fixture" / member
                original = target.read_bytes()
                outside = self.root / ("outside-" + member)
                outside.write_bytes(original)
                target.unlink()
                try:
                    target.symlink_to(outside)
                except OSError:
                    target.write_bytes(original)
                    self.skipTest("host does not permit symbolic links")
                self.assert_refused()
                target.unlink()
                target.write_bytes(original)

    def test_retained_publication_claim_prevents_verification(self):
        (self.bundle / ".world-art-exclusive-claim").mkdir()
        self.assert_refused()

    def test_delayed_claim_cannot_take_over_a_completed_publication(self):
        output = self.root / "claim-race"
        output.mkdir()
        original_mkdir = Path.mkdir

        def racing_mkdir(path, *args, **kwargs):
            if path == output / ".world-art-exclusive-claim":
                (output / "earlier.png").write_bytes(b"existing publication")
            return original_mkdir(path, *args, **kwargs)

        with patch.object(Path, "mkdir", new=racing_mkdir):
            with self.assertRaises(support.CaptureError) as caught:
                support.claim_output_directory(output)
        self.assertEqual(caught.exception.code, support.EXIT_USAGE)
        self.assertEqual((output / "earlier.png").read_bytes(), b"existing publication")
        self.assertFalse((output / ".world-art-exclusive-claim").exists())

    def test_compare_invalid_bundle_returns_noncomparable_without_traceback(self):
        batch = deepcopy(self.batch)
        batch["jobs"][0]["shots"] = None
        self.save_batch(batch)
        result = support.compare_bundles(self.bundle, self.bundle)
        self.assertFalse(result["comparable"])
        self.assertTrue(result["before_problems"])
        cli = subprocess.run([sys.executable, str(Path(launcher.__file__)), "--compare-bundles",
                              str(self.bundle), str(self.bundle)], capture_output=True, text=True, timeout=20)
        self.assertNotEqual(cli.returncode, 0)
        self.assertNotIn("Traceback", cli.stdout + cli.stderr)

    def test_crc_valid_png_with_invalid_filters_or_chunk_sequence_is_refused(self):
        path = self.root / "invalid.png"
        for options in ({"filter_byte": 5}, {"compression": 1}, {"filtering": 1}, {"split_idat": True}):
            with self.subTest(options=options):
                path.write_bytes(validator_png(**options))
                with self.assertRaises(ValueError):
                    support.inspect_png(path)

    def test_large_integer_crop_is_a_clean_usage_error(self):
        # Larger than float conversion's range as well as the canvas bounds.
        huge = "9" * 400
        result = subprocess.run([sys.executable, str(Path(launcher.__file__)), "--capture", "--godot", sys.executable,
                                 "--pack", str(self.pack), "--crop", huge + ",0,8,4",
                                 "--output-dir", str(self.root / "huge-crop")],
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, support.EXIT_USAGE, result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stdout + result.stderr)
        self.assertFalse((self.root / "huge-crop").exists())

    def test_timeout_terminates_owned_descendants_before_they_publish(self):
        marker = self.root / "late-write.txt"
        started = self.root / "descendant-started.txt"
        child_code = ("import time; from pathlib import Path; "
                      + f"Path({str(started)!r}).write_text('started'); time.sleep(2); "
                      + f"Path({str(marker)!r}).write_text('late write')")
        parent_code = ("import subprocess,sys,time; "
                       + f"subprocess.Popen([sys.executable, '-c', {child_code!r}]); "
                       + "print('descendant created', flush=True); time.sleep(60)")
        code, log = launcher.run_logged([sys.executable, "-c", parent_code], os.environ.copy(), timeout=0.8)
        self.assertIsNone(code, log)
        self.assertTrue(started.is_file(), "the descendant did not start; process-tree test was inconclusive")
        time.sleep(1.5)
        self.assertFalse(marker.exists(), "a child wrote output after its owner's timeout")


if __name__ == "__main__":
    unittest.main()
