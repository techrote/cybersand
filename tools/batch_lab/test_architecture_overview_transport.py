#!/usr/bin/env python3
"""Synthetic PNG-envelope adversaries only; these fixtures are not native captures."""
from __future__ import annotations

import base64
import copy
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from emit_architecture_overviews import (CHUNK_CHARACTERS, FAMILIES, MAX_IMAGE_BYTES,
                                        PNG_SIGNATURE, collect, digest, emit)

SOURCE = "1" * 40


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def synthetic_png(width: int, height: int) -> bytes:
    # Minimal grayscale fixture. The production helper never generates or edits.
    pixels = (b"\0" + bytes(width)) * height
    return (PNG_SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


def write_json(root: Path, name: str, value: dict) -> None:
    (root / name).write_text(json.dumps(value), encoding="utf-8")


def fixture(root: Path) -> tuple[dict, dict]:
    examples, frames = [], []
    for family, size in FAMILIES.items():
        plane = bytes(size[0] * size[1] * 2)
        (root / (family + ".u16le")).write_bytes(plane)
        image = synthetic_png(*size)
        name = family + "-whole-godot.png"
        (root / name).write_bytes(image)
        examples.append({"id": family, "extent": list(size), "plane": family + ".u16le",
                         "sha256": digest(plane), "all_tasks_completed": True})
        row = {"id": family, "view": "whole", "image": name, "image_sha256": digest(image),
               "native_source_revision": SOURCE, "native_material_sha256": digest(plane),
               "pixels": list(size), "region": [0, 0, *size], "kind": "godot-rendered-native-material-plane"}
        frames.append(row)
        for view in ("district-upper", "district-lower"):
            # Non-overview records are never selected or opened by this helper.
            frames.append(dict(row, view=view, image=family + "-" + view + "-godot.png"))
    native = {"format": "cybersand-native-flagship-campaign-v1", "source_revision": SOURCE,
              "checks": 1, "failures": 0, "examples": examples}
    rendered = {"format": "cybersand-native-flagship-renders-v1", "source_revision": SOURCE,
                "native_source_revision": SOURCE, "checks": 1, "failures": 0, "passed": True,
                "display": "synthetic-test", "renders": frames}
    write_json(root, "flagships-native.json", native)
    write_json(root, "flagships-render.json", rendered)
    return native, rendered


class TransportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.native, self.rendered = fixture(self.root)

    def tearDown(self):
        self.temporary.cleanup()

    def test_exact_unmodified_bytes_survive_bounded_chunks(self):
        stream = io.StringIO()
        report = emit(self.root, SOURCE, stream)
        self.assertEqual(report["emitted_images"], 4)
        records = []
        for line in stream.getvalue().splitlines():
            prefix, value = line.split(" ", 1)
            records.append((prefix, json.loads(value)))
        for family in FAMILIES:
            header = next(row for prefix, row in records if prefix == "ARCHITECTURE_OVERVIEW_PNG" and row["id"] == family)
            chunks = [row for prefix, row in records if prefix == "ARCHITECTURE_OVERVIEW_PNG_CHUNK" and row["id"] == family]
            self.assertEqual([row["index"] for row in chunks], list(range(header["chunks"])))
            self.assertTrue(all(len(row["base64"]) <= CHUNK_CHARACTERS for row in chunks))
            actual = base64.b64decode("".join(row["base64"] for row in chunks), validate=True)
            self.assertEqual(actual, (self.root / header["image"]).read_bytes())
            self.assertEqual(digest(actual), header["image_sha256"])
            self.assertEqual(header["source_revision"], SOURCE)

    def test_source_and_display_cannot_be_substituted(self):
        for key, value in (("source_revision", "2" * 40), ("native_source_revision", "2" * 40), ("display", "headless")):
            document = copy.deepcopy(self.rendered); document[key] = value
            write_json(self.root, "flagships-render.json", document)
            with self.assertRaises(ValueError):
                collect(self.root, SOURCE)

    def test_frame_path_is_fixed_and_duplicate_overviews_refuse(self):
        document = copy.deepcopy(self.rendered)
        document["renders"][0]["image"] = "../private.png"
        write_json(self.root, "flagships-render.json", document)
        with self.assertRaises(ValueError):
            collect(self.root, SOURCE)
        document = copy.deepcopy(self.rendered)
        document["renders"][1]["view"] = "whole"
        write_json(self.root, "flagships-render.json", document)
        with self.assertRaises(ValueError):
            collect(self.root, SOURCE)

    def test_bad_hash_or_crc_emits_no_partial_image_bytes(self):
        row = self.rendered["renders"][0]
        path = self.root / row["image"]
        broken = path.read_bytes()[:-1] + b"\x01"
        path.write_bytes(broken)
        stream = io.StringIO()
        with self.assertRaises(ValueError):
            emit(self.root, SOURCE, stream)
        self.assertEqual(stream.getvalue(), "")
        row["image_sha256"] = digest(broken)
        write_json(self.root, "flagships-render.json", self.rendered)
        with self.assertRaisesRegex(ValueError, "CRC"):
            collect(self.root, SOURCE)

    def test_native_plane_identity_is_not_only_a_report_label(self):
        (self.root / self.native["examples"][0]["plane"]).write_bytes(b"wrong")
        with self.assertRaises(ValueError):
            collect(self.root, SOURCE)

    def test_over_limit_png_is_omitted_without_resize_or_rewrite(self):
        name = self.rendered["renders"][0]["image"]
        oversized = b"x" * (MAX_IMAGE_BYTES + 1)
        (self.root / name).write_bytes(oversized)
        images, report = collect(self.root, SOURCE)
        self.assertEqual(len(images), 3)
        self.assertEqual(len(report["omitted"]), 1)
        self.assertIn("original artifact", report["omitted"][0]["reason"])
        self.assertEqual((self.root / name).read_bytes(), oversized)

    def test_dimensions_and_partial_reports_refuse(self):
        row = self.rendered["renders"][0]
        wrong = synthetic_png(1, 1)
        (self.root / row["image"]).write_bytes(wrong)
        row["image_sha256"] = digest(wrong)
        write_json(self.root, "flagships-render.json", self.rendered)
        with self.assertRaises(ValueError):
            collect(self.root, SOURCE)
        self.rendered["failures"] = 1
        write_json(self.root, "flagships-render.json", self.rendered)
        with self.assertRaises(ValueError):
            collect(self.root, SOURCE)


if __name__ == "__main__":
    unittest.main()
