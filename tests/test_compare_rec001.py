"""Synthetic-only REC-001 v2 offline comparator regression tests (no Godot claims)."""
import json
import struct
import tempfile
import unittest
from pathlib import Path
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("rec_compare", ROOT / "tools/recording/compare_rec001.py")
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


def make_bmp(ids: bytes, w: int, h: int) -> bytes:
    stride = (w + 3) & ~3
    offset = 1078
    size = offset + stride*h
    header = bytearray(offset)
    header[:2] = b"BM"
    struct.pack_into("<I", header, 2, size)
    struct.pack_into("<I", header, 10, offset)
    struct.pack_into("<I", header, 14, 40)
    struct.pack_into("<iiHH", header, 18, w, h, 1, 8)
    return bytes(header) + b"".join(ids[y*w:(y+1)*w] + b"\x00"*(stride-w) for y in reversed(range(h)))


def recording(directory: Path, frames=3, changed=False, scenario="rem003/player-granular-review", drops=0):
    directory.mkdir()
    data = {"schema_id": MOD.SCHEMA, "schema_version": 2, "evidence_kind": MOD.EVIDENCE,
            "disposition": "complete", "incomplete_reason": "", "identity": {"source": {"source_revision": "synthetic/test"}},
            "configuration": {"roi": [11, 21, 4, 4], "retain_raw_ids": True, "capture_hz": 15},
            "counters": {"written_frames": frames, "dropped_frames": drops},
            "drops": {"retained": [{"attempt": 2, "reason": "queue-full", "capture_observed_monotonic_usec": 120000}] if drops else [], "omitted_count": 0}}
    (directory / "recording.json").write_text(json.dumps(data))
    for i in range(1, frames+1):
        name = f"frame-{i:06d}"
        ids = bytes([i + (1 if changed else 0)]*16)
        meta = {"schema_id": MOD.SCHEMA, "evidence_kind": MOD.EVIDENCE, "frame_index": i,
                "recording_roi": [11,21,4,4], "elapsed_monotonic_usec": i*100000,
                "material_generation": {"completed_simulation_tick": 8 if i==2 else i*10,
                                         "render_snapshot_serial": 10 if i==2 else i},
                "actor_sample": {"completed_simulation_tick": i*100},
                "scenario": {"id": scenario, "seed": 2, "definition_hash": "hash", "mode": "native", "source_recipe_hash": "recipe"},
                "worker_count": 4, "material_ids_file": name+".ids", "review_bitmap_file": name+".bmp",
                "player": {"origin": [1., 2.], "representation": "sampled-baseline"}}
        (directory / (name+".json")).write_text(json.dumps(meta))
        (directory / (name+".ids")).write_bytes(ids)
        (directory / (name+".bmp")).write_bytes(make_bmp(ids,4,4))
    return data


class CompareTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.a, self.b, self.out = (self.root/x for x in ("A","B","comparison"))
        recording(self.a, drops=1)
        recording(self.b, changed=True)

    def test_real_output_and_same_generation_tick(self):
        report = MOD.compare(self.a, self.b, self.out)
        self.assertTrue(report["same_scenario_and_roi"])
        self.assertEqual(len(report["matched_material_generation_ticks"]), 3)
        self.assertEqual(report["matched_material_generation_ticks"][0]["differing_material_cells"],16)
        self.assertEqual(report["sessions"]["A"]["recording_counters"]["dropped_frames"], 1)
        self.assertEqual(report["sessions"]["A"]["selected"][1]["material_tick"],8)
        self.assertEqual(report["sessions"]["A"]["selected"][1]["actor_tick"],200)
        self.assertTrue((self.out/"index.html").is_file())
        self.assertEqual((self.out/"A/frame-000001.bmp").read_bytes(),(self.a/"frame-000001.bmp").read_bytes())
        self.assertIn("not deterministic replay",(self.out/"index.html").read_text())
        self.assertTrue((self.out/"comparison.json").is_file())

    def test_source_inputs_unchanged(self):
        before = {(p.name,p.read_bytes()) for p in self.a.iterdir()}
        MOD.compare(self.a,self.b,self.out)
        self.assertEqual(before, {(p.name,p.read_bytes()) for p in self.a.iterdir()})

    def test_scenario_mismatch_disallows_pixel_deltas(self):
        path=self.b/"frame-000001.json"
        data=json.loads(path.read_text());data["scenario"]["id"]="different"
        path.write_text(json.dumps(data))
        report=MOD.compare(self.a,self.b,self.out)
        self.assertFalse(report["same_scenario_and_roi"])
        self.assertEqual(report["matched_material_generation_ticks"],[])
        self.assertTrue(any("scenario" in x for x in report["notes"]))

    def test_missing_material_and_bad_bmp_refused(self):
        (self.a/"frame-000001.ids").write_bytes(b"broken")
        with self.assertRaisesRegex(MOD.InvalidRecording,"byte count"):
            MOD.compare(self.a,self.b,self.out)
        (self.a/"frame-000001.ids").write_bytes(bytes([1]*16))
        (self.a/"frame-000001.bmp").write_bytes(b"BM")
        with self.assertRaisesRegex(MOD.InvalidRecording,"bitmap"):
            MOD.compare(self.a,self.b,self.out)

    def test_path_traversal_and_symlink_refused(self):
        path=self.a/"frame-000001.json";data=json.loads(path.read_text())
        data["review_bitmap_file"]="../B/frame-000001.bmp"
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(MOD.InvalidRecording,"invalid frame"):
            MOD.compare(self.a,self.b,self.out)

    def test_manifest_count_and_schema_refused(self):
        path=self.a/"recording.json";data=json.loads(path.read_text())
        data["counters"]["written_frames"]=7;path.write_text(json.dumps(data))
        with self.assertRaisesRegex(MOD.InvalidRecording,"written_frames"):
            MOD.compare(self.a,self.b,self.out)
        data["counters"]["written_frames"]=3;data["schema_version"]=1;path.write_text(json.dumps(data))
        with self.assertRaisesRegex(MOD.InvalidRecording,"unsupported schema"):
            MOD.compare(self.a,self.b,self.out)

    def test_nonmonotonic_elapsed_refused(self):
        path=self.a/"frame-000003.json";data=json.loads(path.read_text())
        data["elapsed_monotonic_usec"]=10000;path.write_text(json.dumps(data))
        with self.assertRaisesRegex(MOD.InvalidRecording,"nonmonotonic"):
            MOD.compare(self.a,self.b,self.out)

    def test_incomplete_and_omitted_drop_warning(self):
        p=self.a/"recording.json";d=json.loads(p.read_text())
        d["disposition"]="incomplete";d["incomplete_reason"]="synthetic stop"
        d["drops"]["omitted_count"]=10;p.write_text(json.dumps(d))
        report=MOD.compare(self.a,self.b,self.out)
        self.assertEqual(len(report["notes"]),2)
        self.assertIn("synthetic stop",report["notes"][0])

    def test_bounded_frames_and_existing_destination(self):
        with self.assertRaisesRegex(ValueError,"max_frames"):
            MOD.compare(self.a,self.b,self.out,max_frames=1)
        MOD.compare(self.a,self.b,self.out,max_frames=2)
        self.assertEqual(len(list((self.out/"A").iterdir())),2)
        with self.assertRaisesRegex(MOD.InvalidRecording,"output must be new"):
            MOD.compare(self.a,self.b,self.out)


if __name__ == "__main__":
    unittest.main()
