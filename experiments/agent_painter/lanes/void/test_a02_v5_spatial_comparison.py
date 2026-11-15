"""Fail-closed, network-free source regressions for pinned A02 v5 spatial witness."""
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from a02_v5_spatial_comparison import (need, mask, iou, proximity_fraction,
                                       compare, visible_architecture, checked_zip)


class A02V5SpatialTests(unittest.TestCase):
    def test_native_little_endian_96_square(self):
        import struct
        raw = struct.pack("<9216i", *([0] * 9215 + [58]))
        self.assertEqual(mask(raw), {9215})
        with self.assertRaisesRegex(ValueError, "dimensions"):
            mask(raw[:-4])

    def test_reject_other_material_ids(self):
        import struct
        with self.assertRaisesRegex(ValueError, "material ID"):
            mask(struct.pack("<9216i", *([0] * 9215 + [59])))

    def test_iou_disjoint_and_equal(self):
        self.assertEqual(iou({1, 2}, {3}), 0)
        self.assertEqual(iou({1, 2}, {1, 2}), 1)
        self.assertAlmostEqual(iou({1, 2}, {2, 3}), 1 / 3)

    def test_iou_cannot_accept_empty_mask(self):
        with self.assertRaises(ValueError):
            iou(set(), {1})

    def test_proximity_nonwrapping_at_row_edge(self):
        # Adjacent flat-index cells 95/96 are far apart horizontally in a 96-wide crop.
        self.assertEqual(proximity_fraction({95}, {96}, radius=1), 0)
        self.assertEqual(proximity_fraction({95}, {94}, radius=1), 1)
        self.assertEqual(proximity_fraction({95}, {94}, radius=0), 0)

    def test_reject_invalid_proximity_radius(self):
        for radius in (-1, 9, 1.5, True):
            with self.subTest(radius=radius), self.assertRaises(ValueError):
                proximity_fraction({0}, {0}, radius)

    def test_hold_final_sealed_without_reading_zip(self):
        class NoReads:
            def read(self, name):
                raise AssertionError("not permitted to read a sealed target")
        with self.assertRaisesRegex(ValueError, "sealed/unknown"):
            visible_architecture(NoReads(), "FINAL")

    def test_v5_cannot_be_counted_as_new_structure(self):
        # Synthetic domains: v4 524 cells; v5 must add exactly 138 and retain all.
        four = set(range(524))
        five = set(range(662))
        result = compare(four, five, [("TRAIN", "toy", {0, 1})])
        self.assertEqual(len(result), 1)
        self.assertGreater(result[0]["v5_iou"], result[0]["v4_iou"])
        with self.assertRaisesRegex(ValueError, "138-cell"):
            compare(four, five - {0} | {700}, [("TRAIN", "toy", {0, 1})])

    def test_reject_nonoriginal_zip(self):
        with TemporaryDirectory() as tmp:
            file = Path(tmp) / "fake.zip"
            file.write_bytes(b"not a native research artifact")
            with self.assertRaisesRegex(ValueError, "whole original ZIP hash"):
                checked_zip(file, "0" * 64)

    def test_bool_is_not_integer_radius(self):
        with self.assertRaises(ValueError):
            proximity_fraction({0}, {0}, radius=True)


if __name__ == "__main__":
    unittest.main()
