#!/usr/bin/env python3
"""Read original shader parity atlases; require exact native framebuffer bytes.

This is NONQUALIFYING isolated-render evidence, never a PACE003 substitute.
The fixed inherited 2/255 RGBA8 check remains, but clipping to PNG must never
hide changed HDR values. This unchanged-arithmetic candidate must also preserve
every retained native framebuffer byte. Every differing tile is reported.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

RAW_RGBA_FORMATS = {5: np.dtype("u1"), 11: np.dtype("<f4"), 15: np.dtype("<f2")}
MATERIAL_COVERAGE_IDS = (1, 20, 50, 81, 110, 131)
MIN_COVERED_PIXELS = 72


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_frame_pixels(folder: Path, frame: dict) -> None:
    # Pinned Godot Image formats: RGBA8=5, RGBAF=11, RGBAH=15. Both target
    # platforms are little-endian; unknown layouts cannot establish parity.
    raw_format = frame["raw_format"]
    require(type(raw_format) is int and raw_format in RAW_RGBA_FORMATS,
            "Unsupported native atlas framebuffer format")
    dtype = RAW_RGBA_FORMATS[raw_format]
    data = (folder / frame["raw_filename"]).read_bytes()
    require(len(data) == 640 * 360 * 4 * dtype.itemsize,
            "Native atlas framebuffer raw byte count differs from its format/size")
    native = np.frombuffer(data, dtype=dtype).reshape((360, 640, 4))
    require(bool(np.isfinite(native).all()), "Native atlas framebuffer contains nonfinite channels")
    native = native.astype(np.float32)
    if raw_format == 5:
        native /= 255.0
    with Image.open(folder / frame["filename"]) as image:
        pixels = np.array(image.convert("RGBA"), dtype=np.int16)
    require(pixels.shape == (360, 640, 4), "Retained PNG dimensions differ")
    # Each atlas tile has a broad authored square at (2,2)-(18,18), and an
    # empty moat at (20,38). Sample its interior, avoiding edge algorithms.
    # These distributed ordinary/structured/building IDs all had 144/144
    # contrasting pixels in every original 16-frame atlas. Require half that
    # coverage in BOTH retained representations; an empty/fallback viewport
    # cannot prove parity just because baseline and candidate are equally blank.
    # Alpha participates so the intentional smoke-previous blend=0 remains valid.
    for material_id in MATERIAL_COVERAGE_IDS:
        x, y = material_id % 16 * 40, material_id // 16 * 40
        for label, values, tolerance in (("PNG", pixels, 2), ("native", native, 2 / 255)):
            interior = values[y + 4:y + 16, x + 4:x + 16]
            moat = values[y + 38, x + 20]
            covered = np.any(np.abs(interior - moat) > tolerance, axis=2)
            require(int(covered.sum()) >= MIN_COVERED_PIXELS,
                    f"Atlas {label} material coverage absent for ID {material_id}, frame {frame['index']}")


def load(folder: Path) -> dict:
    value = json.loads((folder / "atlas.json").read_text())
    require(value["schema"] == "play-pace003-palette-parity-atlas-v1", "Atlas schema differs")
    require(value["failures"] == 0, "Atlas reported rendering failures")
    require(value["display_server"] != "headless", "A headless atlas cannot establish visual parity")
    require(len(value["frames"]) == 16, "Atlas did not retain all 16 frames")
    submissions = value["frame_submissions_usec"]
    require(len(submissions) >= 32 and all(type(stamp) is int and stamp >= 0 for stamp in submissions)
            and all(b > a for a, b in zip(submissions, submissions[1:])),
            "Atlas graphical submission timestamps are absent or nonmonotonic")
    for i, frame in enumerate(value["frames"]):
        require(frame["index"] == i and frame["size"] == [640, 360], "Atlas frame identity or dimensions differ")
        require(type(frame["captured_usec"]) is int and type(frame["started_usec"]) is int
                and frame["captured_usec"] > frame["started_usec"] >= 0,
                "Atlas frame capture is not after its render request")
        for filename, sha in (("filename", "png_sha256"), ("raw_filename", "raw_sha256")):
            path = folder / frame[filename]
            require(path.parent == folder and digest(path) == frame[sha],
                    "Retained atlas image path or SHA-256 differs: " + filename)
        verify_frame_pixels(folder, frame)
    return value


def compare(baseline: Path, candidate: Path) -> dict:
    left, right = load(baseline), load(candidate)
    for key in ("godot", "platform", "display_server", "video_adapter", "palette_lut_sha256", "program_lut_sha256",
                "source_revision"):
        require(left[key] == right[key], "Atlas source/runtime/lookup identity differs: " + key)
    require(left["shader_sha256"] != right["shader_sha256"], "Need different retained shader inputs")
    compare_keys = ("index", "phase", "time", "blend", "smoke_previous", "structured_detail",
                    "water_presentation_mode", "size", "raw_format", "current_texture_sha256",
                    "previous_texture_sha256")
    result = {"schema": "play-pace003-palette-parity-comparison-v1", "scope": left["scope"],
              "baseline_shader_sha256": left["shader_sha256"],
              "candidate_shader_sha256": right["shader_sha256"],
              "baseline_report_sha256": digest(baseline / "atlas.json"),
              "candidate_report_sha256": digest(candidate / "atlas.json"),
              "rgba_tolerance_byte_units": 2, "tolerance_basis": "Existing same-backend material presentation tolerance, fixed before run; alpha included",
              "native_framebuffer_requirement": "byte-exact; this candidate changes dispatch only, not shader arithmetic",
              "raw_framebuffer_validity": "RGBA8/RGBAF/RGBAH, exact byte count, finite channels",
              "material_coverage_requirement": {"material_ids": list(MATERIAL_COVERAGE_IDS),
                  "minimum_interior_pixels_per_tile": MIN_COVERED_PIXELS, "sampled_interior_pixels": 144,
                  "difference_from_empty_moat": "greater than 2/255 in any RGBA channel, PNG and native"},
              "frames": [], "passed": True}
    for a, b in zip(left["frames"], right["frames"]):
        require({k: a[k] for k in compare_keys} == {k: b[k] for k in compare_keys},
                "Atlas rendering configuration or texture inputs differ")
        with Image.open(baseline / a["filename"]) as image:
            original = np.array(image.convert("RGBA"), dtype=np.int16)
        with Image.open(candidate / b["filename"]) as image:
            changed = np.array(image.convert("RGBA"), dtype=np.int16)
        require(original.shape == changed.shape == (360, 640, 4), "Retained PNG dimensions differ")
        difference = np.abs(original - changed)
        max_channels = difference.max(axis=(0, 1)).tolist()
        pixels_changed = (difference != 0).any(axis=2)
        pixels_outside = (difference > 2).any(axis=2)
        tiles = []
        for material_id in range(132):
            x, y = material_id % 16 * 40, material_id // 16 * 40
            tile = difference[y:y+40, x:x+40]
            if np.any(tile):
                tiles.append({"material_id": material_id,
                              "max_rgba_difference": tile.max(axis=(0, 1)).tolist(),
                              "changed_pixels": int((tile != 0).any(axis=2).sum()),
                              "outside_tolerance_pixels": int((tile > 2).any(axis=2).sum())})
        # The retained files were independently hashed by load(). A PNG can
        # be identical after clipping even when its original HDR values differ.
        raw_exact = a["raw_sha256"] == b["raw_sha256"]
        passed = not np.any(pixels_outside) and raw_exact
        result["frames"].append({"index": a["index"],
                                 "rgba_exact": not np.any(pixels_changed),
                                 "native_framebuffer_bytes_exact": raw_exact,
                                 "png_file_bytes_exact": a["png_sha256"] == b["png_sha256"],
                                 "max_rgba_difference": max_channels,
                                 "rms_rgba_difference": np.sqrt(np.mean(difference.astype(float)**2, axis=(0, 1))).tolist(),
                                 "changed_pixels": int(pixels_changed.sum()),
                                 "outside_tolerance_pixels": int(pixels_outside.sum()),
                                 "differing_material_tiles": tiles, "passed": bool(passed)})
        result["passed"] = bool(result["passed"] and passed)
    return result


def self_test() -> int:
    """Synthetic adversarial fixtures only; never engine-rendering evidence."""
    import copy
    import struct
    import tempfile
    import unittest

    def pair(root: Path) -> tuple[Path, Path]:
        baseline, candidate = root / "baseline", root / "candidate"
        native = np.zeros((360, 640, 4), dtype="<f2")
        native[..., 3] = 1.0
        pixels = np.zeros((360, 640, 4), dtype=np.uint8)
        pixels[..., 3] = 255
        for material_id in MATERIAL_COVERAGE_IDS:
            x, y = material_id % 16 * 40, material_id // 16 * 40
            native[y + 2:y + 18, x + 2:x + 18] = [2.0, 2.0, 2.0, 1.0]
            pixels[y + 2:y + 18, x + 2:x + 18] = [255, 255, 255, 255]
        raw = native.tobytes()
        for folder, shader in ((baseline, "a" * 64), (candidate, "b" * 64)):
            folder.mkdir()
            Image.fromarray(pixels).save(folder / "image.png")
            (folder / "image.raw").write_bytes(raw)
            frame = {"size": [640, 360], "filename": "image.png", "raw_filename": "image.raw",
                     "png_sha256": digest(folder / "image.png"), "raw_sha256": digest(folder / "image.raw"),
                     "raw_format": 15, "phase": 0, "time": 3.0, "blend": 1.0, "smoke_previous": False,
                     "structured_detail": 1.0, "water_presentation_mode": 0,
                     "current_texture_sha256": "c" * 64, "previous_texture_sha256": "c" * 64}
            record = {"schema": "play-pace003-palette-parity-atlas-v1", "failures": 0,
                      "scope": "SYNTHETIC comparator self-test, not engine evidence", "godot": {"hash": "synthetic"},
                      "source_revision": "d" * 40, "shader_sha256": shader, "platform": "Linux",
                      "display_server": "x11", "video_adapter": "synthetic",
                      "palette_lut_sha256": "e" * 64, "program_lut_sha256": "f" * 64,
                      "frame_submissions_usec": list(range(1, 33)),
                      "frames": [{**copy.deepcopy(frame), "index": i, "started_usec": i * 2,
                                  "captured_usec": i * 2 + 1} for i in range(16)]}
            (folder / "atlas.json").write_text(json.dumps(record))
        return baseline, candidate

    def update_hashes(folder: Path) -> None:
        record = json.loads((folder / "atlas.json").read_text())
        for frame in record["frames"]:
            frame["png_sha256"] = digest(folder / "image.png")
            frame["raw_sha256"] = digest(folder / "image.raw")
        (folder / "atlas.json").write_text(json.dumps(record))

    class Controls(unittest.TestCase):
        def test_exact_raw_and_png_accept(self):
            with tempfile.TemporaryDirectory() as folder:
                result = compare(*pair(Path(folder)))
                self.assertTrue(result["passed"])
                self.assertTrue(all(frame["native_framebuffer_bytes_exact"] for frame in result["frames"]))

        def test_equal_clipped_png_cannot_hide_hdr_difference(self):
            with tempfile.TemporaryDirectory() as folder:
                baseline, candidate = pair(Path(folder))
                raw = bytearray((candidate / "image.raw").read_bytes())
                # 2.0 and 3.0 both clip to 255 in the retained PNG's red channel.
                offset = (4 * 640 + 44) * 4 * 2
                raw[offset:offset + 2] = struct.pack("<e", 3.0)
                (candidate / "image.raw").write_bytes(raw)
                record = json.loads((candidate / "atlas.json").read_text())
                for frame in record["frames"]:
                    frame["raw_sha256"] = digest(candidate / "image.raw")
                (candidate / "atlas.json").write_text(json.dumps(record))
                result = compare(baseline, candidate)
                self.assertFalse(result["passed"])
                self.assertTrue(all(frame["rgba_exact"] for frame in result["frames"]))
                self.assertTrue(all(not frame["native_framebuffer_bytes_exact"] for frame in result["frames"]))

        def test_schema_validation_survives_python_optimization(self):
            with tempfile.TemporaryDirectory() as folder:
                baseline, _candidate = pair(Path(folder))
                record = json.loads((baseline / "atlas.json").read_text())
                record["schema"] = "invalid"
                (baseline / "atlas.json").write_text(json.dumps(record))
                with self.assertRaisesRegex(RuntimeError, "schema"):
                    load(baseline)

        def test_changed_original_raw_bytes_refuse(self):
            with tempfile.TemporaryDirectory() as folder:
                baseline, candidate = pair(Path(folder))
                (candidate / "image.raw").write_bytes(b"unrecorded change")
                with self.assertRaisesRegex(RuntimeError, "SHA-256"):
                    compare(baseline, candidate)

        def test_identical_blank_atlases_cannot_pass(self):
            for colour in ((0, 0, 0, 0), (0, 0, 0, 255), (255, 255, 255, 255)):
                with self.subTest(colour=colour), tempfile.TemporaryDirectory() as folder:
                    baseline, candidate = pair(Path(folder))
                    for target in (baseline, candidate):
                        Image.new("RGBA", (640, 360), colour).save(target / "image.png")
                        pixel = np.array(colour, dtype="<f2") / 255.0
                        (target / "image.raw").write_bytes(np.tile(pixel, (360, 640, 1)).tobytes())
                        update_hashes(target)
                    with self.assertRaisesRegex(RuntimeError, "material coverage absent"):
                        compare(baseline, candidate)

        def test_partial_atlas_or_blank_native_data_cannot_pass(self):
            for missing in ("one-material", "native-only"):
                with self.subTest(missing=missing), tempfile.TemporaryDirectory() as folder:
                    baseline, candidate = pair(Path(folder))
                    native = np.frombuffer((candidate / "image.raw").read_bytes(), dtype="<f2").copy().reshape(360, 640, 4)
                    if missing == "one-material":
                        material_id = MATERIAL_COVERAGE_IDS[-1]
                        x, y = material_id % 16 * 40, material_id // 16 * 40
                        native[y:y + 40, x:x + 40] = [0, 0, 0, 1]
                        with Image.open(candidate / "image.png") as image:
                            pixels = np.array(image)
                        pixels[y:y + 40, x:x + 40] = [0, 0, 0, 255]
                        Image.fromarray(pixels).save(candidate / "image.png")
                    else:
                        native[:] = [0, 0, 0, 1]
                    (candidate / "image.raw").write_bytes(native.tobytes())
                    update_hashes(candidate)
                    with self.assertRaisesRegex(RuntimeError, "material coverage absent"):
                        compare(baseline, candidate)

        def test_nonfinite_native_channels_refuse_even_if_png_is_valid(self):
            for invalid in (float("nan"), float("inf"), -float("inf")):
                with self.subTest(invalid=invalid), tempfile.TemporaryDirectory() as folder:
                    baseline, candidate = pair(Path(folder))
                    raw = bytearray((candidate / "image.raw").read_bytes())
                    raw[:2] = struct.pack("<e", invalid)
                    (candidate / "image.raw").write_bytes(raw)
                    update_hashes(candidate)
                    with self.assertRaisesRegex(RuntimeError, "nonfinite"):
                        compare(baseline, candidate)

        def test_unknown_raw_format_and_wrong_byte_count_refuse(self):
            for invalid in ("format", "size"):
                with self.subTest(invalid=invalid), tempfile.TemporaryDirectory() as folder:
                    baseline, candidate = pair(Path(folder))
                    if invalid == "format":
                        record = json.loads((candidate / "atlas.json").read_text())
                        for frame in record["frames"]:
                            frame["raw_format"] = 999
                        (candidate / "atlas.json").write_text(json.dumps(record))
                    else:
                        (candidate / "image.raw").write_bytes((candidate / "image.raw").read_bytes()[:-8])
                        update_hashes(candidate)
                    with self.assertRaisesRegex(RuntimeError, "format|byte count"):
                        compare(baseline, candidate)

    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    return 0 if result.wasSuccessful() else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path, nargs="?")
    parser.add_argument("candidate", type=Path, nargs="?")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not all((args.baseline, args.candidate, args.output)):
        parser.error("baseline, candidate and --output are required")
    result = compare(args.baseline, args.candidate)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"passed": result["passed"], "frames": len(result["frames"]),
                      "rgba_exact_frames": sum(x["rgba_exact"] for x in result["frames"]),
                      "native_framebuffer_exact_frames": sum(x["native_framebuffer_bytes_exact"] for x in result["frames"]),
                      "outside_tolerance_pixels": sum(x["outside_tolerance_pixels"] for x in result["frames"])}))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
