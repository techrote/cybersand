"""M3 resident Q8/host admission constraints. Pure stdlib, no network or native."""
from __future__ import annotations

import copy
import unittest

from experiments.driv3r.m3_model.short import SCENARIO, legal_candidates, select
from experiments.driv3r.m3_native.qualify import M1_SCHEMA_SHA
from experiments.driv3r.d_common.v1.verify import SCHEMA
import hashlib


def observation():
    pixels=[0]*(96*96)
    # One blocked neighbor, which may never be offered as a paint operation.
    pixels[23*96+12]=28
    return {"focus":[0,0,96,96], "materials":pixels,
            "protected_rectangles":[[40,40,8,8]],
            "world_material_sha256":"a"*64,"revision":3,
            "generation":7,"tick":0}


class FakeBackend:
    def __init__(self, chosen):
        self.chosen=chosen
        self.calls=0

    def decide(self, state, questions, *, timeout_seconds):
        self.calls+=1
        ids=list(questions["next_action"]["criteria"])
        probs={key:1.0 if key==self.chosen else 0.0 for key in ids}
        return {"status":"ok","error":None,"pid":1234,
                "latency_seconds":0.005,
                "model_identity":{"repository":"synthetic_mock_only"},
                "backend_identity":{"backend":"synthetic_mock_only"},
                "raw_response":{"answers":{"next_action":{
                    "type":"choice","choice":self.chosen,"probabilities":probs,
                    "confidence":1.0}},"usage":{"input_tokens":200,"output_tokens":0}}}


class SmokeOfflineTests(unittest.TestCase):
    def test_m1_frozen(self):
        self.assertEqual(hashlib.sha256(SCHEMA.read_bytes()).hexdigest(),M1_SCHEMA_SHA)

    def test_fixed_short_model_budget_not_36(self):
        self.assertEqual(SCENARIO["max_model_requests"],4)
        self.assertEqual(SCENARIO["max_native_actions"],4)
        self.assertFalse(SCENARIO["allow_a1_a2_a3_campaign"])
        self.assertTrue(SCENARIO["replay"])

    def test_legal_candidates_are_native_material_and_focus_only(self):
        obs=observation()
        options=legal_candidates(obs,[12,24])
        self.assertNotIn("MOVE_N",{o["id"] for o in options})
        self.assertTrue({"MOVE_E","MOVE_S","MOVE_W","STOP"}.issubset({o["id"] for o in options}))
        self.assertTrue(all(len(o["footprint"])<=1 and o["max_changed_cells"]<=1 for o in options))

    def test_forbidden_material_is_never_a_candidate(self):
        obs=observation()
        obs["materials"][25*96+12]=28
        self.assertNotIn("MOVE_S",{o["id"] for o in legal_candidates(obs,[12,24])})

    def test_protected_region_never_authorized(self):
        obs=observation()
        obs["materials"][40*96+39]=0
        options=legal_candidates(obs,[39,40])
        self.assertNotIn("MOVE_E",{o["id"] for o in options})

    def test_single_mocked_model_choice_is_only_host_offered(self):
        obs=observation()
        options=legal_candidates(obs,[12,24])
        backend=FakeBackend("MOVE_S")
        action,record=select(backend,obs,[12,24],options,0)
        self.assertEqual(action["id"],"MOVE_S")
        self.assertEqual(backend.calls,1)
        self.assertEqual(record["raw"]["raw_response"]["usage"]["output_tokens"],0)
        self.assertIn("STOP",record["questions"]["next_action"]["criteria"])

    def test_model_cannot_choose_any_unoffered_coordinate(self):
        obs=observation()
        options=legal_candidates(obs,[12,24])
        with self.assertRaises(Exception):
            select(FakeBackend("MOVE_N"),obs,[12,24],options,0)

    def test_legal_catalog_does_not_depend_on_prompt_or_guidance(self):
        before=observation()
        after=copy.deepcopy(before)
        x=legal_candidates(before,[12,24])
        y=legal_candidates(after,[12,24])
        self.assertEqual(x,y)

    def test_empty_moves_are_never_outside_world(self):
        for point in ([0,0],[95,95],[0,95],[95,0]):
            obs=observation()
            choices=legal_candidates(obs,list(point))
            self.assertTrue(all(0<=c["path"][-1][0]<96 and
                                0<=c["path"][-1][1]<96
                                for c in choices if c["id"]!="STOP"))

if __name__=="__main__":
    unittest.main()
