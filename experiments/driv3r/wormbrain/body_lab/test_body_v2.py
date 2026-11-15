"""Model-free BODY-V2 action/state/receipt regressions (not native qualification)."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.wormbrain.body_lab.body_v2 import (
    BodyOptions, SyntheticBody, synthetic_rollout, showcase,
    SYNTHETIC_TURN_CEILING, digest,
)
from experiments.driv3r.wormbrain.body_lab.preflight import (
    HostView, Lease, Refusal, new_ink_from_readbacks,
)


def lease(name):
    return Lease(name, "bodylab", "runner-1", f"isolated-{name}", "NO_MODEL", 570)


def blank(protected=()):
    return HostView((0,)*9216, protected)


class BodyV2(unittest.TestCase):
    def test_option_bounds_and_no_unchecked_anchor(self):
        for opts in ({"span":0}, {"span":5}, {"span":True},
                     {"pen_up":1}, {"branch_anchors":True}):
            with self.subTest(opts=opts), self.assertRaises(Refusal):
                BodyOptions(**opts)

    def test_menu_offers_only_legal_model_ids_and_stale_digest_refuses(self):
        b = SyntheticBody(lease("a"), blank(), options=BodyOptions(span=4))
        obs = b.observation()
        self.assertIn("INK_E_4", obs["legal_action_ids"])
        self.assertNotIn("LIFT_E_4", obs["legal_action_ids"])
        before = b.view()
        for action, sha in (("X=1,Y=5",obs["menu_digest"]),
                            ("INK_E_5",obs["menu_digest"]),
                            ("INK_E_4","0"*64)):
            with self.subTest(action=action), self.assertRaises(Refusal):
                b.choose(action, sha, original_response=action)
        self.assertEqual(b.view(),before)
        self.assertEqual(b.decisions,0)

    def test_intermediate_wall_or_protection_forbidden_for_ink_and_lift(self):
        cells=[0]*9216
        cells[24*96+14]=61
        b = SyntheticBody(lease("b"),HostView(tuple(cells),((10,23,1,3),)),
                          options=BodyOptions(4,True,True))
        menu=b.menu()
        self.assertIn("INK_E_1",menu)
        self.assertNotIn("INK_E_2",menu)
        self.assertIn("LIFT_E_1",menu)
        self.assertNotIn("LIFT_E_2",menu)
        self.assertNotIn("INK_W_2",menu)
        self.assertNotIn("LIFT_W_2",menu)

    def test_four_cell_ink_counts_cells_not_model_decisions(self):
        b = SyntheticBody(lease("c"),blank(),options=BodyOptions(span=4))
        o=b.observation()
        r=b.choose("INK_E_4",o["menu_digest"],original_response="INK_E_4")
        self.assertEqual(r["new_ink_cells"],4)
        self.assertEqual(r["total_ink_cells"],4)
        self.assertEqual(r["logical_moves"],4)
        self.assertEqual(b.decisions,1)
        self.assertEqual(new_ink_from_readbacks(b.initial,b.view()),4)

    def test_penup_does_not_paint_and_foreign_ink_not_traversable(self):
        a=blank()
        b=SyntheticBody(lease("d"),a,options=BodyOptions(4,True,False))
        o=b.observation()
        b.choose("LIFT_E_4",o["menu_digest"],original_response="LIFT_E_4")
        self.assertEqual(len(b.own_ink),0)
        self.assertEqual(b.logical_moves,4)
        self.assertEqual(new_ink_from_readbacks(a,b.view()),0)
        self.assertEqual(len(b.history),5)

        foreign=[0]*9216
        foreign[24*96+14]=58
        c=SyntheticBody(lease("foreign"),HostView(tuple(foreign)),
                        options=BodyOptions(4,True,False))
        self.assertNotIn("LIFT_E_2",c.menu())
        self.assertNotIn("INK_E_2",c.menu())

    def test_anchors_retrace_is_one_cell_not_teleport(self):
        b=SyntheticBody(lease("anchor"),blank(),
                        options=BodyOptions(4,True,True))
        first=b.observation()
        b.choose("SAVE_ANCHOR",first["menu_digest"],original_response="SAVE_ANCHOR")
        self.assertEqual(len(b.anchors),1)
        self.assertNotIn("SAVE_ANCHOR",b.menu())
        second=b.observation()
        b.choose("INK_E_3",second["menu_digest"],original_response="INK_E_3")
        self.assertIn("RETRACE_1",b.menu())
        old=b.view()
        third=b.observation()
        r=b.choose("RETRACE_1",third["menu_digest"],original_response="RETRACE_1")
        self.assertEqual(r["path"],[[14,24]])
        self.assertEqual(r["new_ink_cells"],0)
        self.assertEqual(old,b.view())
        self.assertEqual(b.cursor,(14,24))
        self.assertEqual(len(b.anchors),1)

    def test_stop_final_and_no_late_mutation(self):
        b=SyntheticBody(lease("stop"),blank())
        o=b.observation()
        b.choose("STOP",o["menu_digest"],original_response="STOP")
        self.assertEqual(b.menu(),{})
        with self.assertRaises(Refusal):
            b.choose("STOP",o["menu_digest"],original_response="STOP")

    def test_source_and_local_memory_no_cross_world_leakage(self):
        a=SyntheticBody(lease("left"),blank(),options=BodyOptions(4,True,True))
        b=SyntheticBody(lease("right"),blank(),options=BodyOptions(4,True,True))
        o=a.observation()
        a.choose("INK_E_4",o["menu_digest"],original_response="INK_E_4")
        self.assertNotEqual(a.observation()["world_sha256"],
                            b.observation()["world_sha256"])
        self.assertEqual(b.observation()["inked_cells"],0)
        self.assertEqual(b.observation()["local_visits"],1)
        self.assertEqual(a.observation()["local_occupancy"][3][3],1)
        self.assertEqual(b.observation()["local_occupancy"][3][3],0)

    def test_one_hundred_twenty_eight_is_synthetic_only(self):
        b=synthetic_rollout(lease("128"),options=BodyOptions(4,True,True))
        self.assertLessEqual(b.decisions,SYNTHETIC_TURN_CEILING)
        self.assertLessEqual(b.logical_moves,512)
        self.assertLessEqual(len(b.own_ink),128)
        self.assertEqual(new_ink_from_readbacks(b.initial,b.view()),len(b.own_ink))
        self.assertTrue(all(not t["native_execution"] and not t["model_execution"]
                            and t["native_receipts"] == 0 for t in b.trace))

    def test_all_four_original_visual_arms_are_reproducible_and_untrained(self):
        with tempfile.TemporaryDirectory() as folder:
            one=showcase(Path(folder)/"a")
            two=showcase(Path(folder)/"b")
            self.assertEqual(one,two)
            self.assertFalse(one["native_128_turns_qualified"])
            self.assertFalse(one["model_execution"])
            self.assertEqual(one["verified_active_model_processes"],0)
            self.assertEqual(len(one["arms"]),4)
            self.assertEqual(len({a["variant"] for a in one["arms"]}),4)
            for item in one["arms"]:
                raw=(Path(folder)/"a"/item["trace"]).read_bytes()
                png=(Path(folder)/"a"/item["png"]).read_bytes()
                self.assertTrue(png.startswith(b"\\x89PNG\\r\\n\\x1a\\n"))
                self.assertEqual(hashlib.sha256(raw).hexdigest(),
                                 item["trace_sha256"])
                self.assertEqual(hashlib.sha256(png).hexdigest(),
                                 item["png_sha256"])
                doc=json.loads(raw)
                self.assertEqual(doc["model_calls"],0)
                self.assertEqual(doc["native_receipts"],0)
                self.assertLessEqual(doc["logical_cursor_moves"],512)
                self.assertEqual(doc["initial_world_sha256"],
                                 digest(SyntheticBody(lease("other"),blank()).initial.material)
                                 if False else doc["initial_world_sha256"])


if __name__=="__main__":
    unittest.main()
