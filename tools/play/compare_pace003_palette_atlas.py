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


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
        raw = struct.pack("<eeee", 2.0, 2.0, 2.0, 1.0) * (640 * 360)
        for folder, shader in ((baseline, "a" * 64), (candidate, "b" * 64)):
            folder.mkdir()
            Image.new("RGBA", (640, 360), (255, 255, 255, 255)).save(folder / "image.png")
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
                raw[:2] = struct.pack("<e", 3.0)
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
