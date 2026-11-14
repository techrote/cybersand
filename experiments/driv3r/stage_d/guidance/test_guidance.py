"""Cheap, isolated stdlib tests for experimental guidance; no native Worlds."""
import json
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.stage_d.guidance.field import (
    CONVERSION, GuidanceField, Hysteresis, decode_png8, export_bundle,
    import_png8, load_bundle, radial_airbrush, rgba_png, speckle_png,
)
from experiments.driv3r.stage_d.guidance.study import (
    CriticSnapshot, factorial_arms, matched_arms, shadow_verdict, stable_hash,
)


class FieldTests(unittest.TestCase):
    def test_u16le_order_and_bounds(self):
        f = GuidanceField(2, 2, (0, 1, 0x1234, 65535), 7, 9)
        self.assertEqual(f.raw(), bytes.fromhex("000001003412ffff"))
        self.assertEqual(f.at(8, 10), 65535)
        self.assertEqual(GuidanceField.from_raw(2, 2, f.raw(), 7, 9), f)
        with self.assertRaises(IndexError):
            f.at(6, 9)
        with self.assertRaises(ValueError):
            GuidanceField(1, 1, (65536,))
        with self.assertRaises(ValueError):
            GuidanceField.from_raw(2, 2, b"\0\0")

    def test_airbrush_gradient_and_determinism(self):
        f = radial_airbrush(11, 11, center_x=5.5, center_y=5.5,
                            radius_cells=5, hardness=0.2, gradient_length=0.9)
        self.assertEqual(f.at(5, 5), 65535)
        self.assertEqual(f.at(0, 0), 0)
        self.assertLess(f.at(1, 5), f.at(3, 5))
        self.assertEqual(f, radial_airbrush(11, 11, center_x=5.5, center_y=5.5,
                                            radius_cells=5, hardness=0.2, gradient_length=0.9))
        with self.assertRaises(ValueError):
            radial_airbrush(1, 1, center_x=0, center_y=0, radius_cells=0)

    def test_speckles_not_numeric_truth(self):
        f = GuidanceField(8, 1, (65535,) * 8)
        raw_hash = f.sha256
        self.assertEqual(speckle_png(f, seed=42, centre_density=.5),
                         speckle_png(f, seed=42, centre_density=.5))
        self.assertNotEqual(speckle_png(f, seed=42, centre_density=.5),
                            speckle_png(f, seed=43, centre_density=.5))
        self.assertEqual(f.sha256, raw_hash)
        w, h, px = decode_png8(speckle_png(f, seed=42, centre_density=.5))
        self.assertEqual((w, h), (8, 1))
        self.assertTrue(all(alpha in (0, 255) for alpha in px[3::4]))

    def test_png_import_rgba_and_manifest(self):
        source = rgba_png(3, 1, bytes((255,255,255,255, 255,255,255,0, 0,0,0,255)))
        f = import_png8(source, x=3, y=4)
        self.assertEqual(f.values, (65535, 0, 0))
        self.assertEqual(f.at(3, 4), 65535)
        self.assertEqual(CONVERSION, "png8_rec709_luma_times_alpha_round_u16_v1")

    def test_png_crc_rejection(self):
        png = bytearray(rgba_png(1, 1, bytes((0, 1, 2, 3))))
        png[-5] ^= 4
        with self.assertRaises(ValueError):
            decode_png8(bytes(png))

    def test_bundle_roundtrip_and_tampering(self):
        f = GuidanceField(2, 2, (12, 450, 65000, 0))
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "guide"
            export_bundle(p, f, seed=9, centre_density=.4)
            restored, manifest = load_bundle(p)
            self.assertEqual(restored, f)
            self.assertEqual(manifest["values"]["sha256"], f.sha256)
            self.assertFalse(manifest["native_material_authority"])
            self.assertEqual(manifest["source_kind"], "manual_scalar")
            with p.with_suffix(".u16le").open("ab") as target:
                target.write(b"z")
            with self.assertRaises(ValueError):
                load_bundle(p)

    def test_bundle_preview_tampering(self):
        f = GuidanceField(1, 1, (65535,))
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "guide"
            export_bundle(p, f, seed=0, centre_density=1)
            document = json.loads(p.with_suffix(".json").read_text())
            document["seed"] = 123
            p.with_suffix(".json").write_text(json.dumps(document))
            # Note: at density=1 all seeds yield same image; change density.
            document["centre_density"] = 0
            p.with_suffix(".json").write_text(json.dumps(document))
            with self.assertRaises(ValueError):
                load_bundle(p)

    def test_hysteresis_neutral_not_forbidden(self):
        h = Hysteresis(100, 200)
        self.assertEqual(h.assess(99, True), (False, "propose_recovery"))
        self.assertEqual(h.assess(150, False), (False, "no_transition"))
        self.assertEqual(h.assess(200, False), (True, "reentered"))
        self.assertEqual(h.assess(150, True), (True, "no_transition"))
        with self.assertRaises(ValueError):
            Hysteresis(200, 200)


class StudyTests(unittest.TestCase):
    def test_matched_sources_and_ablations(self):
        source = {"clearance": 5}
        views = matched_arms(snapshot_id="world:2:17", candidate_ids=["up", "down"],
                             geometry=source, guidance={"field_sha": "a"*64},
                             critic={"last": "KEEP"})
        self.assertEqual(len(views), 4)
        self.assertEqual(len({v["candidate_set_sha256"] for v in views.values()}), 1)
        self.assertTrue(all(v["input_hashes"] == views["combined"]["input_hashes"] for v in views.values()))
        self.assertIsNone(views["geometry_only"]["guidance"])
        self.assertIsNone(views["guidance_only"]["geometry"])
        self.assertIsNone(views["critic_only"]["geometry"])
        source["clearance"] = -1
        self.assertEqual(views["combined"]["geometry"]["clearance"], 5)
        self.assertEqual(stable_hash({"a": 1, "b": 2}), stable_hash({"b": 2, "a": 1}))

    def test_factorial_geometry_baseline(self):
        views = factorial_arms(snapshot_id="world:g:2", candidate_ids=["a", "b"],
                               geometry={"clearance": 4}, guidance={"preference": 2000},
                               critic={"shadow": "not_actuated"})
        self.assertEqual(len(views), 4)
        self.assertTrue(all(v["geometry"] == {"clearance": 4} for v in views.values()))
        self.assertIsNone(views["A_geometry"]["guidance"])
        self.assertIsNone(views["B_geometry_guidance"]["critic"])
        self.assertIsNone(views["C_geometry_critic"]["guidance"])
        self.assertIsNotNone(views["D_geometry_guidance_critic"]["critic"])
        self.assertEqual(len({v["candidate_set_sha256"] for v in views.values()}), 1)

    def test_shadow_keep_undo_stop_without_mutation(self):
        before = CriticSnapshot("before", 10.0, 0, 2)
        better = CriticSnapshot("after", 11.0, 0, 3)
        worse = CriticSnapshot("worse", 9.0, 1, 2)
        keep = shadow_verdict(before=before, after=better, undo_eligible=True, verified_native_receipt=True)
        undo = shadow_verdict(before=before, after=worse, undo_eligible=True, verified_native_receipt=True)
        stop = shadow_verdict(before=before, after=worse, undo_eligible=False, verified_native_receipt=True)
        self.assertEqual([keep["decision"], undo["decision"], stop["decision"]], ["KEEP", "UNDO", "STOP"])
        self.assertTrue(all(not v["native_material_changed_by_critic"] for v in (keep, undo, stop)))
        self.assertTrue(all(v["execution"].startswith("shadow_only") for v in (keep, undo, stop)))
        with self.assertRaises(ValueError):
            shadow_verdict(before=before, after=before, undo_eligible=True, verified_native_receipt=True)


if __name__ == "__main__":
    unittest.main()
