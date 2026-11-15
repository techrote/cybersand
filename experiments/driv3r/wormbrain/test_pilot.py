"""WORM-001 cheap source tests; no model/Godot/native effect is simulated as real."""
import json
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.d_common.v1.verify import validate_bundle
from experiments.driv3r.wormbrain.pilot import (
    MODES, FRAME, MAX_DECISIONS, MAX_PAINT, MAX_RECOVERIES,
    candidate_legal, guide_for, prompt_for, scent, turn_kind, START,
)


def native_stub():
    return {"focus":[0,0,96,96],
            "materials":[0]*(96*96),
            "protected_rectangles":[[40,40,8,8]],
            "world_material_sha256":"a"*64,
            "generation":1,"revision":2,"tick":0}


class WormPilotTests(unittest.TestCase):
    def test_pilot_budgets_are_bounded_and_keep_stop(self):
        self.assertEqual(MODES, ("free","soft"))
        self.assertEqual(MAX_DECISIONS, 36)
        self.assertEqual(MAX_PAINT, 36)
        self.assertEqual(MAX_RECOVERIES, 8)
        self.assertLessEqual(MAX_PAINT, 56)

    def test_guides_are_valid_m1_positive_core_and_never_native_permissions(self):
        with tempfile.TemporaryDirectory() as d:
            results={}
            for mode in MODES:
                path=Path(d)/mode
                path.mkdir()
                guide,values=guide_for(path, f"test-worm-{mode}", mode)
                self.assertEqual(guide["frame"], FRAME)
                self.assertEqual(guide["encoding"],"u16le_higher_is_better_zero_is_neutral")
                self.assertFalse(guide["native_material_authority"])
                self.assertEqual(len(values), FRAME[2]*FRAME[3])
                self.assertEqual(validate_bundle([guide], evidence_root=path)["validated"],1)
                results[mode]=guide,values
            self.assertEqual(max(results["free"][1]),0)
            self.assertGreater(max(results["soft"][1]),0)
            self.assertEqual(results["free"][0]["optional_channels"],[])
            self.assertEqual(results["soft"][0]["optional_channels"],[])

    def test_same_host_legal_options_irrespective_of_scent(self):
        state=native_stub()
        options=candidate_legal(state, START, [START], 0, 0)
        ids={o["id"] for o in options}
        self.assertEqual(ids,{"MOVE_N","MOVE_E","MOVE_S","MOVE_W","STOP"})
        self.assertEqual(options,candidate_legal(state, START,[START],0,0))
        self.assertEqual([o["id"] for o in candidate_legal(state,START,[START],0,MAX_PAINT)],["STOP"])

    def test_prompt_leaves_worm_free_of_goal_or_astar_distance(self):
        before=native_stub()
        opts=candidate_legal(before,START,[START],0,0)
        zero=[0]*(FRAME[2]*FRAME[3])
        state, questions, order=prompt_for("free",zero,before,START,[START],opts,0,"E")
        self.assertEqual(set(order),{o["id"] for o in opts})
        self.assertNotIn("goal", state)
        self.assertNotIn("target", state)
        self.assertNotIn("distance_to_goal",str(state))
        self.assertIn("worm",questions["worm_move"]["instructions"].lower())
        self.assertIn("MOVE_E",questions["worm_move"]["criteria"])
        self.assertEqual(state["candidate_hints"]["MOVE_E"]["soft_scent_u16"],0)

    def test_reproducible_option_order_does_not_depend_on_soft_mode(self):
        before=native_stub()
        opts=candidate_legal(before, START, [START],0,0)
        a=prompt_for("free",[0]*1024,before,START,[START],opts,13,"N")
        b=prompt_for("soft",[3]*1024,before,START,[START],opts,13,"N")
        self.assertEqual(a[2],b[2])
        self.assertNotEqual(a[0]["candidate_hints"]["MOVE_E"]["soft_scent_u16"],
                            b[0]["candidate_hints"]["MOVE_E"]["soft_scent_u16"])

    def test_scent_outside_frame_is_neutral(self):
        self.assertEqual(scent([65535]*(32*32), [90,90]),0)
        self.assertEqual(scent([65535]*(32*32), [8,20]),65535)

    def test_cardinal_turns_are_correct(self):
        self.assertEqual(turn_kind("E","E"),"straight")
        self.assertEqual(turn_kind("E","S"),"right turn")
        self.assertEqual(turn_kind("E","N"),"left turn")
        self.assertEqual(turn_kind("E","W"),"reverse")

    def test_derived_native_material_gallery_needs_actual_writes(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("Pillow rendering runs on native CI")
        from experiments.driv3r.wormbrain.pilot import gallery
        with tempfile.TemporaryDirectory() as d:
            base={"materials":[0]*(96*96)}
            painted={"materials":base["materials"].copy()}
            painted["materials"][25*96+12]=58
            trace=[{"choice":"MOVE_S","cursor_after":[12,25]}]
            result=gallery(Path(d)/"gallery",base,painted,
                           [{"point":[12,25]}],trace)
            self.assertEqual(len(result),3)
            self.assertTrue(all((Path(d)/a["path"]).is_file() for a in result))
            for a in result:
                self.assertEqual(a["sha256"],__import__("hashlib").sha256(
                    (Path(d)/a["path"]).read_bytes()).hexdigest())
            self.assertEqual(result[-1]["format"],"bin")  # schema-safe GIF


if __name__=="__main__":
    unittest.main()
