"""Cheap M4 contract tests: synthetic only, explicitly not native/model evidence."""
from __future__ import annotations
import copy
import tempfile
from pathlib import Path
import unittest

from experiments.driv3r.d_common.v1.verify import validate_bundle
from experiments.driv3r.m4.guides import make, values_for, FRAME,ARMS
from experiments.driv3r.m4.compare import legal,MAX_DECISIONS,MAX_NATIVE_PAINT,MAX_AUTO_STEPS
from experiments.driv3r.m4.aggregate import compare


def native():
    return {"focus":[0,0,96,96],"materials":[0]*(96*96),
            "protected_rectangles":[[40,40,8,8]],
            "world_material_sha256":"a"*64,
            "material_sha256":"b"*64,
            "generation":3,"revision":2,"tick":0}


def summary(arm):
    base={"arm":arm,"source_sha":"f"*40,"initial_world_sha256":"a"*64,
          "first_legal_catalog_sha256":"b"*64,"model_requests":36,
          "actual_native_edits":36,"model_selected_native_edits":35,
          "neural_recovery_interventions":1,
          "productive_procedural_steps_after_recovery":1,
          "recovery_leverage":1,
          "final_world_sha256":"c"*64,
          "independent_native_replay":True}
    base["decision_effects"]=[{"source_world_sha256":"a"*64,
           "cursor_before":[12,24],
           "legal_sha256":"b"*64,"candidate_ids":["MOVE_E","STOP"],
           "choice":"MOVE_E","cursor_after":[13,24],
           "world_after_sha256":"c"*64}]
    return base


class M4OfflineTests(unittest.TestCase):

    def test_model_identity_is_the_exact_pinned_q8_gguf_not_reference_repository(self):
        from experiments.driv3r.backend import PINS
        self.assertEqual(PINS["model"]["repository"],"LiquidAI/d1-2B-GGUF")
        self.assertEqual(PINS["model"]["quantization"],"Q8_0")
        self.assertEqual(PINS["model"]["bytes"],1846240576)
        self.assertEqual(len(PINS["model"]["sha256"]),64)

    def test_36_forward_decisions_are_strictly_bounded(self):
        self.assertEqual(MAX_DECISIONS,36)
        self.assertLessEqual(MAX_NATIVE_PAINT,64)
        self.assertLessEqual(MAX_AUTO_STEPS,12)

    def test_a1_a2_a3_have_identical_original_numeric_positive_core(self):
        with tempfile.TemporaryDirectory() as d:
            rows={}
            for arm in ARMS:
                root=Path(d)/arm;root.mkdir()
                guide,raw=make(root,"fixture-m4",arm)
                self.assertEqual(guide["values"]["format"],"u16le")
                self.assertEqual(guide["canvas_size"],[512,512])
                self.assertEqual(guide["frame"],FRAME)
                self.assertFalse(guide["native_material_authority"])
                self.assertEqual(validate_bundle([guide])["validated"],1)
                rows[arm]=(guide,raw)
            self.assertEqual(rows["A1"][1]["core"],rows["A2"][1]["core"])
            self.assertEqual(rows["A1"][1]["core"],rows["A3"][1]["core"])
            self.assertEqual(len(rows["A1"][0]["optional_channels"]),0)
            self.assertEqual(len(rows["A2"][0]["optional_channels"]),3)
            self.assertEqual(len(rows["A3"][0]["optional_channels"]),2)

    def test_typed_semantics_separate_geometry_from_soft_preference(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            g,raw=make(root,"fixture-m4","A3")
            semantic={(c["semantic_id"],c["signal_class"]) for c in g["optional_channels"]}
            self.assertIn(("signed_distance/v1","geometry_metric"),semantic)
            self.assertIn(("flow_vector_xy/v1","geometry_metric"),semantic)
            sample=values_for(g,raw,[14,28])
            self.assertIsInstance(sample["distance"]["sample"],int)
            self.assertEqual(len(sample["flow"]["sample"]),2)

    def test_identical_host_legal_candidates_for_same_native_state(self):
        n=native()
        start=[12,24]
        for arm in ARMS:
            self.assertEqual(legal(n,start,[start],0,0),
                             legal(copy.deepcopy(n),start,[start],0,0))

    def test_recovery_candidates_are_not_guidance_dependent(self):
        n=native()
        path=[[12,24],[13,24],[14,24],[15,24],[16,24],[17,24]]
        ids={c["id"] for c in legal(n,[17,24],path,0,2)}
        self.assertIn("BACKTRACK",ids)
        self.assertIn("RELOCATE_START",ids)

    def test_36_budget_never_exceeds_native_write_hard_limit(self):
        opts=legal(native(),[12,24],[[12,24]],0,MAX_NATIVE_PAINT)
        self.assertEqual([c["id"] for c in opts],["STOP"])

    def test_aggregate_requires_exact_same_first_legal_catalog(self):
        arms={arm:summary(arm) for arm in ARMS}
        self.assertEqual(compare(arms)["status"],"COMPLETE_COMPARISON")
        arms["A2"]["first_legal_catalog_sha256"]="d"*64
        with self.assertRaises(ValueError):
            compare(arms)

    def test_first_choice_and_native_effect_divergence_are_distinct(self):
        arms={arm:summary(arm) for arm in ARMS}
        arms["A3"]["decision_effects"][0]["choice"]="STOP"
        arms["A3"]["decision_effects"][0]["cursor_after"]=[12,24]
        arms["A3"]["decision_effects"][0]["world_after_sha256"]="a"*64
        out=compare(arms)
        self.assertEqual(out["first_choice_divergence_on_matched_world"],0)
        self.assertEqual(out["first_consequential_native_cursor_or_material_divergence"],0)

    def test_incomplete_comparison_cannot_claim_success(self):
        self.assertEqual(compare({"A1":summary("A1")})["status"],"INCOMPLETE")


    def test_real_native_receipt_adapter_consumes_before_and_after_world_fences(self):
        from unittest.mock import patch
        from experiments.driv3r.m4.compare import draw
        class Native:
            def cursor_move(self, start, end):
                return {"status":"completed","receipt":{"actual_changed_cells":0}}
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            (root/"native").mkdir()
            (root/"native/actual.png").write_bytes(b"\x89PNG\r\n\x1a\n")
            before={"world_id":"fixture:1","generation":1,"revision":3,"tick":0,
                    "material_sha256":"a"*64,"world_material_sha256":"b"*64}
            after={**before,"revision":4,"material_sha256":"c"*64,
                   "world_material_sha256":"d"*64,"png_path":"actual.png"}
            reply={"status":"completed",
                   "receipt":{"actual_changed_cells":1,"readback_matches":True,
                              "receipts_reconstruct_materials":True},
                   "observation":after}
            obs={"record_id":"obs-fixture"}
            actions=[];receipts=[];artifacts=[];journal=[obs]
            history=[[12,24]]
            cursor={"from":[12,24],"to":[12,25],"index":0,"candidate":"MOVE_S"}
            with patch("experiments.driv3r.m4.compare._native_action",return_value=reply):
                result=draw(root,"fixture",Native(),journal,actions,receipts,artifacts,
                            {},cursor,history,"MODEL_A1_0",obs,before,
                            model=True,legal_hash="e"*64,present_hash="f"*64)
            self.assertEqual(result["world_precondition"]["revision"],3)
            self.assertEqual(result["world_postcondition"]["revision"],4)
            self.assertEqual(result["actor"],"d1")
            self.assertEqual(result["cursor_after"],[12,25])
            self.assertEqual(len(actions),1)
            self.assertEqual(len(receipts),1)
            self.assertEqual(history,[[12,24],[12,25]])


if __name__=="__main__":
    unittest.main()
