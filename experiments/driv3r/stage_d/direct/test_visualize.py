"""Stdlib-only DEVELOPMENT synthetic cursor gallery and custody regressions."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

from experiments.driv3r.stage_d.direct import offline as d
from experiments.driv3r.stage_d.direct import paired
from experiments.driv3r.stage_d.direct import visualize as v


def decode_png_rgb(data: bytes):
    """Independent minimal RGB8 PNG reader: verifies chunk CRCs and scanlines."""
    assert data.startswith(b"\x89PNG\r\n\x1a\n")
    pos, compressed, dimensions = 8, [], None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        value = data[pos + 8:pos + 8 + length]
        crc = struct.unpack(">I", data[pos + 8 + length:pos + 12 + length])[0]
        assert crc == zlib.crc32(kind + value) & 0xffffffff
        pos += length + 12
        if kind == b"IHDR":
            w, h, bits, color, compression, filt, interlace = struct.unpack(">IIBBBBB", value)
            assert (bits, color, compression, filt, interlace) == (8, 2, 0, 0, 0)
            dimensions = (w, h)
        elif kind == b"IDAT":
            compressed.append(value)
        elif kind == b"IEND":
            assert not value and pos == len(data)
            break
    assert dimensions is not None
    w, h = dimensions
    raw = zlib.decompress(b"".join(compressed))
    rows = []
    for y in range(h):
        row = raw[y * (1 + 3 * w):(y + 1) * (1 + 3 * w)]
        assert row[0] == 0
        rows.append(row[1:])
    assert len(raw) == (1 + 3 * w) * h
    return w, h, rows


class SyntheticGalleryTests(unittest.TestCase):
    def setUp(self):
        self.f = d.routing_fixture("gate", "development")
        self.episode = d.run_episode(self.f, "astar", seed=13)

    def test_png_crc_dimensions_and_pixel_roles(self):
        raw = v.render_episode(self.f, self.episode, scale=4)
        w, h, rows = decode_png_rgb(raw)
        self.assertEqual((w, h), (self.f.width * 4, self.f.height * 4))
        def cell(x, y):
            return tuple(rows[y * 4 + 2][(x * 4 + 2) * 3:(x * 4 + 2) * 3 + 3])
        self.assertEqual(cell(*self.f.start), v.START)
        self.assertEqual(cell(*self.f.target), v.TARGET)
        self.assertEqual(cell(11, 7), v.MATERIAL_Z)
        self.assertEqual(cell(27, 16), v.PROTECTED)
        self.assertEqual(cell(0, 0), v.AIR)
        self.assertEqual(raw, v.render_episode(self.f, self.episode, scale=4))

    def test_wall_selected_identity_decoy_and_distance_band(self):
        f = d.wall_fixture("step", "development")
        e = d.run_episode(f, "contour_astar")
        _, _, rows = decode_png_rgb(v.render_episode(f, e, scale=3))
        def cell(x, y):
            return tuple(rows[y * 3 + 1][(x * 3 + 1) * 3:(x * 3 + 1) * 3 + 3])
        self.assertEqual(cell(34, 10), v.DECOY)
        self.assertEqual(cell(*min(f.selected_wall)), v.WALL)
        self.assertEqual(cell(25, 35), v.AIR)

    def test_tampered_and_counterfeit_native_evidence_refused(self):
        for corruption in ("path", "score", "native"):
            forged = copy.deepcopy(self.episode)
            if corruption == "path":
                forged["path"].append([0, 0])
            elif corruption == "score":
                forged["metrics"]["arrived"] = False
            else:
                forged["native_qualified"] = True
            with self.subTest(corruption=corruption):
                with self.assertRaises(paired.EvidenceError):
                    v.render_episode(self.f, forged)

    def test_sealed_heldout_episode_cannot_be_rendered(self):
        f = d.wall_fixture("switchback", "heldout")
        with self.assertRaises(paired.EvidenceError):
            v.render_episode(f, {"path": [list(f.start)]})

    def test_scale_refuses_invalid_or_truthy_boolean(self):
        for scale in (True, 0, 2, 33, 4.0, "4"):
            with self.subTest(scale=scale):
                with self.assertRaises(ValueError):
                    v.render_episode(self.f, self.episode, scale=scale)

    def test_refuse_relabelled_or_mutated_development_fixture(self):
        from dataclasses import replace
        f = replace(self.f, material_z=frozenset())
        with self.assertRaises(paired.EvidenceError):
            v.render_episode(f, self.episode)

    def test_gallery_all_development_cases_and_raster_hashes(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(v, "_source_fence"):
            folder = Path(tmp) / "d1a-gallery"
            index = v.generate_development_gallery(folder, "a" * 40, seed=13)
            self.assertEqual(len(index["images"]), 14)
            self.assertEqual({r["structural_split"] for r in index["images"]}, {"development"})
            self.assertTrue(all(not r["synthetic_metrics"]["native_receipts"] for r in index["images"]))
            self.assertFalse(index["native_qualified"])
            self.assertFalse(index["model_evaluated"])
            self.assertFalse(index["heldout_policy_outcomes_evaluated"])
            self.assertEqual(index, json.loads((folder / "manifest.json").read_text()))
            self.assertEqual(index["index_sha256"], d.digest(index["images"]))
            for r in index["images"]:
                content = (folder / r["image_file"]).read_bytes()
                self.assertEqual(r["image_sha256"], hashlib.sha256(content).hexdigest())
                decode_png_rgb(content)
            with self.assertRaises(FileExistsError):
                v.generate_development_gallery(folder, "a" * 40, seed=13)

    def test_gallery_deterministic_with_identical_source_seed(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(v, "_source_fence"):
            a = v.generate_development_gallery(Path(tmp) / "a", "a" * 40, seed=79,
                                                lengths=(1, 2, 4, 8), scale=3)
            b = v.generate_development_gallery(Path(tmp) / "b", "a" * 40, seed=79,
                                                lengths=(1, 2, 4, 8), scale=3)
            self.assertEqual(a, b)
            self.assertEqual(a["index_sha256"], b["index_sha256"])

    def test_gallery_refuses_invalid_inputs_before_writes(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(v, "_source_fence"):
            for i, (seed, lengths) in enumerate(((True, (1,)), (-1, (1,)),
                                                 (0, (2,)), (0, (1, 1)),
                                                 (0, (1, True)), (0, (1, 9)))):
                output = Path(tmp) / f"invalid_{i}"
                with self.assertRaises(ValueError):
                    v.generate_development_gallery(output, "a" * 40, seed=seed, lengths=lengths)
                self.assertFalse(output.exists())

    def test_commit_fence_checks_head_and_dirty_lane(self):
        with self.assertRaises(ValueError):
            v._source_fence("notsha")
        with patch.object(v.subprocess, "check_output", side_effect=["b" * 40]):
            with self.assertRaisesRegex(ValueError, "HEAD"):
                v._source_fence("a" * 40)
        with patch.object(v.subprocess, "check_output", side_effect=["a" * 40, " M experiments/driv3r/stage_d/direct/offline.py"]):
            with self.assertRaisesRegex(ValueError, "Dirty"):
                v._source_fence("a" * 40)
        with patch.object(v.subprocess, "check_output", side_effect=["a" * 40, ""]):
            v._source_fence("a" * 40)


if __name__ == "__main__":
    unittest.main()
