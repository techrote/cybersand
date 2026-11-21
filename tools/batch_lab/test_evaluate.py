"""Synthetic reducer adversaries, separate from real native outcome evidence."""
import base64
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from evaluate import evaluate, blinded_bundle, reveal_votes


def example(identifier="native-test-fixture"):
    before = [0] * 256
    before[17] = 28
    after = before.copy()
    after[5*16+2:5*16+14] = [58] * 12
    raw = struct.pack("<256H", *after)
    source = struct.pack("<256H", *before)
    return {"attempt_id": identifier, "state": "completed", "config": {"extent": [16,16],
        "source_region": [0,0,16,16], "protection": [[1,1,1,1]], "model": "concealed-model-identity",
        "variant": "P3", "seed": 192837, "provider": "test-only", "prompt": "do not export this secret",
        "metrics_targets": {"structural_materials": [58], "require_connected": True,
            "route": [[2,13],[13,13]], "clearance_radius": 1,
            "features": [{"name":"pipe", "rect":[2,5,12,1], "minimum_fraction":1.0}]}},
        "material_cells_base64": base64.b64encode(raw).decode(), "material_sha256": hashlib.sha256(raw).hexdigest(),
        "source_materials_base64": base64.b64encode(source).decode(),
        "provenance": {"source_material_sha256": hashlib.sha256(source).hexdigest()}, "receipts": [{"changed":12}], "usage": {}}


class ReducerTests(unittest.TestCase):
    def test_nonzero_source_crop_uses_local_authoring_coordinates(self):
        tile = example()
        tile["config"]["source_region"] = [64, 64, 16, 16]
        tile["config"]["source_extent"] = [128, 128]
        record = evaluate(tile)["attempts"][0]
        self.assertTrue(record["evaluable"])
        self.assertEqual(record["metrics"]["changed_cells"], 12)
        self.assertEqual(record["metrics"]["outside_scope_changed_cells"], 0)
        self.assertTrue(record["metrics"]["structural_checks_pass"])

    def test_exact_materials_and_unknown_cost(self):
        record = evaluate({"attempt":example()})["attempts"][0]
        self.assertTrue(record["evaluable"])
        self.assertEqual(record["metrics"]["changed_cells"],12)
        self.assertTrue(record["metrics"]["structural_checks_pass"])
        self.assertIsNone(record["cost"])

    def test_all_original_attempts_not_current_tiles(self):
        doc = {"tiles":[{"attempt_id":"selected-only"}], "attempts":[example(),
               {"attempt_id":"bad","state":"refused","reason":"invalid output"},
               {"attempt_id":"stop","state":"stopped"}]}
        result=evaluate(doc)
        self.assertEqual(result["total_attempts"],3)
        self.assertEqual(result["states"],{"completed":1,"refused":1,"stopped":1})
        self.assertEqual(result["evaluable_attempts"],1)

    def test_tampered_native_plane_refuses(self):
        tile=example();tile["material_sha256"]="0"*64
        result=evaluate(tile)["attempts"][0]
        self.assertFalse(result["evaluable"])
        self.assertIn("SHA-256 mismatch",result["reason"])

    def test_unacknowledged_changes_refuse(self):
        tile=example();tile["receipts"][0]["changed"]=11
        self.assertFalse(evaluate(tile)["attempts"][0]["evaluable"])

    def test_duplicate_attempt_identity_retained_as_failure(self):
        result=evaluate({"attempts":[example(),example()]})
        self.assertEqual(result["total_attempts"],2)
        self.assertEqual(result["evaluable_attempts"],1)
        self.assertIn("Duplicate",result["attempts"][1]["reason"])

    def test_protected_material_corruption_detected(self):
        tile=example();raw=bytearray(base64.b64decode(tile["material_cells_base64"]))
        raw[34:36]=struct.pack("<H",58)
        tile["material_cells_base64"]=base64.b64encode(raw).decode();tile["material_sha256"]=hashlib.sha256(raw).hexdigest()
        tile["receipts"][0]["changed"]=13
        result=evaluate(tile)["attempts"][0]
        self.assertEqual(result["metrics"]["protected_changed_cells"],1)
        self.assertFalse(result["metrics"]["structural_checks_pass"])

    def test_blinding_retains_failures_and_hides_provenance(self):
        doc={"attempts":[example(),{"attempt_id":"failure-id","state":"refused"}]}
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)/"blind"
            result=blinded_bundle(doc,root,17)
            page=(root/"review/index.html").read_text()
            self.assertEqual(result["attempts"],2)
            self.assertIn("Outcome: refused",page)
            for hidden in ("concealed-model-identity","192837","native-test-fixture","failure-id","do not export this secret"):
                self.assertNotIn(hidden,page)
            key=json.loads((root/"unblinding-key.json").read_text())
            self.assertNotIn("do not export this secret",json.dumps(key))
            votes={"schema":"cybersand-blind-votes-v1","batch_id":key["batch_id"],"committed_at":"test-committed",
                   "votes":[{"anonymous_id":x["anonymous_id"],"judgement":"not assessable"} for x in key["attempts"]]}
            self.assertEqual(len(reveal_votes(votes,key)["attempts"]),2)
            votes["votes"].pop()
            with self.assertRaises(ValueError):reveal_votes(votes,key)
            with self.assertRaises(FileExistsError):blinded_bundle(doc,root,17)

    def test_cross_cohort_unblinding_refuses(self):
        with self.assertRaises(ValueError):
            reveal_votes({"schema":"cybersand-blind-votes-v1","batch_id":"wrong"},
                         {"schema":"cybersand-blind-key-v1","batch_id":"other"})


if __name__=="__main__":unittest.main()
