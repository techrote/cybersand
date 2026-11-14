"""Frozen conditional Stage C contracts; running these does not count as model inference."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from experiments.driv3r.stage_c.qualify import prepare_cases, _compiled
from experiments.driv3r.stage_c.provenance import (
    CASE_PATH, STAGE_B_SOURCE, STAGE_B_RELEASE_SHA256, expected_request)
from experiments.driv3r.contracts import Refusal


class StageCOfflineTests(unittest.TestCase):
    def test_two_frozen_nonidentical_cases_per_family(self):
        cases=prepare_cases()
        self.assertEqual(len(cases),6)
        self.assertEqual({f:sum(item["family"]==f for item,_ in cases)
                          for f in ("greebles","pipework","architecture")},
                         {"greebles":2,"pipework":2,"architecture":2})
        self.assertEqual(len({pseudo["fixture"]["id"] for _,pseudo in cases}),6)
        for case,pseudo in cases:
            with self.subTest(case=case["id"]):
                self.assertEqual(pseudo["id"],pseudo["fixture"]["id"])
                self.assertIn(case["target_candidate_id"],[x["id"] for x in pseudo["candidates"]])
                self.assertEqual(len(pseudo["evaluation"]["required_rectangles"])>0,True)
                for option in pseudo["candidates"]:
                    compiled=_compiled(option)
                    self.assertEqual(compiled["family"],case["family"])
                    self.assertLessEqual(compiled["operation_count"],16)
                    self.assertLessEqual(compiled["estimated_cell_work"],1024)

    def test_candidate_target_is_geometry_not_answer_rewrite(self):
        for case,pseudo in prepare_cases():
            target=next(o for o in pseudo["candidates"] if o["id"]==case["target_candidate_id"])
            expected=_compiled(target)
            footprints=[{(x,y) for op in _compiled(option)["operations"]
                         for y in range(op["y0"],op["y1"]+1)
                         for x in range(op["x0"],op["x1"]+1)}
                        for option in pseudo["candidates"]]
            self.assertEqual(len(set(map(frozenset,footprints))),3)
            target_index=pseudo["candidates"].index(target)
            self.assertEqual(sum(len(x)==len(footprints[target_index]) and
                 x==footprints[target_index] for x in footprints),1)
            self.assertGreater(len(expected["operations"]),0)

    def test_stage_b_source_and_release_are_immutable(self):
        self.assertEqual(STAGE_B_SOURCE,"2ea0f09c8fbbead7386f47232b0a61cff59bdfdc")
        self.assertEqual(STAGE_B_RELEASE_SHA256,
                         "17b22a80463594575ea28cb688a5b5ab155366b1127d09c3198aef853cae3ce6")
        r=expected_request()
        self.assertTrue(r["draft_hold"])
        self.assertEqual(len(r["frozen_case_sha256"]),64)
        self.assertEqual(r["stage_b_source"],STAGE_B_SOURCE)

    def test_pipe_network_provider_offers_real_legal_art_not_box_forgery(self):
        from experiments.driv3r import PROTOCOL
        from experiments.driv3r.stage_c.qualify import StageCNativeToolProvider
        from experiments.driv3r.stage_b import fuzzy
        from experiments.driv3r.contracts import validate_candidates
        for case, pseudo in prepare_cases():
            for reversed_order in (False, True):
                with self.subTest(case=case["id"], reverse=reversed_order):
                    provider=StageCNativeToolProvider(pseudo, reverse_order=reversed_order)
                    native={"materials":fuzzy._fixture_materials(pseudo),
                            "width":96,"height":96,"focus":[0,0,96,96],
                            "protected_rectangles":[[40,40,8,8]]}
                    obs={"protocol":PROTOCOL,"episode_id":case["id"],"step":0,"mode":"fuzzy",
                         "objective":case["objective"],"subgoal":case["subgoal"],
                         "world":{"id":"offline-test","generation":1,"revision":1,"tick":0,
                                  "material_sha256":"a"*64,"world_material_sha256":"b"*64},
                         "permissions":{"focus":[0,0,96,96],"material":58,
                                        "protected_rectangles":[[40,40,8,8]]},
                         "cursor":case["cursor"],"target":case["target"],
                         "local":{"origin":[0,0],"width":1,"height":1,"materials":[0]},
                         "geometry":{},"history":[],
                         "budgets":{"decisions_remaining":3,"changed_cells_remaining":1024,
                                    "wall_seconds_remaining":90.0},"previous_native_ack":None}
                    options=provider.candidates(native,obs)
                    validate_candidates(options,obs)
                    self.assertEqual({x["id"] for x in options},
                                     {o["id"] for o in pseudo["candidates"]}|{"STOP","SKIP"})
                    tools=[x for x in options if x["kind"]=="tool"]
                    self.assertEqual(len(tools),3)
                    if case["family"]=="pipework":
                        for action in tools:
                            self.assertEqual(action["predicted"]["proposed_boxes"],[])
                            self.assertGreaterEqual(len(action["predicted"]["proposed_nodes"]),2)
                            self.assertTrue(action["operations"])

    def test_unknown_target_or_model_generated_program_cannot_enter(self):
        from experiments.driv3r.stage_c.qualify import CATALOG
        original=json.loads(CATALOG.read_text())
        original["cases"][0]["target_candidate_id"]="UNAUTHORIZED"
        with patch.object(Path,"read_text",return_value=json.dumps(original)):
            with self.assertRaises(Refusal):
                prepare_cases()
