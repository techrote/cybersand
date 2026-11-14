"""M3 pilot offline preflight only. Actual NativeSession requires explicit hosted runner."""
from __future__ import annotations

import copy
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.m3_native.qualify import (
    FOCUS, M1_SCHEMA_SHA, PROTOCOL, ROOT, SCENARIO, START, DESTINATION,
    RecoveryCursor, guidance, observation_record, world, _blob, digest, canonical,
)
from experiments.driv3r.d_common.v1.verify import SCHEMA


def synthetic_observation(root: Path) -> dict:
    crop = root/"native"
    crop.mkdir()
    values = [0]*(96*96)
    (crop/"test-crop.materials.i32le").write_bytes(b"\x00"*(96*96*4))
    return {
        "world_id":"fake-session:1", "generation":1, "revision":3, "tick":0,
        "material_sha256":"1"*64, "world_material_sha256":"2"*64,
        "focus":FOCUS, "width":96, "height":96, "materials":values,
        "material_path":"test-crop.materials.i32le",
        "allowed_materials":[58], "protected_rectangles":[[40,40,8,8]],
        "retired":False,
    }


class M3PilotContractTests(unittest.TestCase):
    def test_frozen_interface_sha(self):
        import hashlib
        self.assertEqual(hashlib.sha256(SCHEMA.read_bytes()).hexdigest(), M1_SCHEMA_SHA)

    def test_no_model_and_exact_one_forward_action(self):
        self.assertFalse(SCENARIO["allow_model"])
        self.assertFalse(SCENARIO["allow_native_undo"])
        self.assertEqual(SCENARIO["max_native_paint_actions"],1)
        self.assertEqual(SCENARIO["max_recovery_decisions"],1)

    def test_cursor_only_backtrack_keeps_material_responsibility_separate(self):
        c=RecoveryCursor()
        self.assertEqual(c.cursor,START)
        c.advance(DESTINATION)
        before,after=c.backtrack()
        self.assertEqual((before,after),(DESTINATION,START))
        self.assertEqual(c.history,[START])
        with self.assertRaises(AssertionError):
            c.backtrack()

    def test_reject_unanchored_cursor_advance(self):
        c=RecoveryCursor()
        with self.assertRaises(AssertionError):
            c.advance([10,10])

    def test_positive_core_is_lossless_and_has_no_optional_channels(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            record=guidance(root,"test-episode")
            self.assertEqual(record["protocol"],PROTOCOL)
            self.assertEqual(record["values"]["bytes"],128)
            self.assertEqual(record["values"]["format"],"u16le")
            self.assertFalse(record["optional_channels"])
            self.assertFalse(record["native_material_authority"])
            self.assertEqual(_blob(root,record["values"]["path"],"u16le"),record["values"])

    def test_m3_observation_never_promotes_synthetic_readback(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            fake=synthetic_observation(root)
            record=observation_record(root,fake,"test-episode",1,"obs-001",
                                      START,[START])
            self.assertEqual(record["world"]["width_cells"],512)
            self.assertEqual(record["world"]["height_cells"],512)
            self.assertEqual(record["cursor"],START)
            self.assertEqual(record["local_material"]["bytes"],96*96*4)
            self.assertFalse(record["guidance_channel_handling"]["used_channel_ids"])
            fake["materials"][0]=58
            self.assertEqual(record["world"]["material_sha256"],"1"*64)

    def test_schema_prevents_native_permission_extension(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            obs=observation_record(root,synthetic_observation(root),"test-episode",1,
                                   "obs-001",START,[START])
            self.assertEqual(obs["rules"]["allowed_materials"],[0,58])
            self.assertEqual(obs["rules"]["forbidden_materials"],[28])
            self.assertEqual(obs["rules"]["focus"],FOCUS)

    def test_canonical_catalog_hash_stable_to_map_order(self):
        self.assertEqual(digest({"id":"A","destination":[12,25]}),
                         digest({"destination":[12,25],"id":"A"}))
        self.assertEqual(canonical({"a":1,"b":2}),b'{"a":1,"b":2}')


if __name__ == "__main__":
    unittest.main()
