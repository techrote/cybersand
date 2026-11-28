#!/usr/bin/env python3
"""New-engine cohort keeps exact engine ownership and original physical gates."""
import copy
from pathlib import Path
import unittest

from run_font_renderer_comparison import (ORDER, ROOT, registration, validate_cohort, validate_deadline_off)
from renderer_contract import verify_renderer_reducer


def arms_fixture():
    arms=[]
    for index,treatment in enumerate(ORDER):
        thread=treatment["render_thread"]
        match={"engine":"e"*64,"render_thread":{"requested":thread,"runtime":thread},
               "cpu":"same-host","renderer":"opengl3_angle","adapter":"same-adapter",
               "water_law":"wave_flow_v1","water_profile":"gameplay_main846f"}
        stats={"match":match,"source":"a"*40,"first_144_body_trajectory_sha256":"same-bodies",
               "first_144_admitted_moves_sha256":"same-moves","command_counts":{"accepted":200},
               "command_mode":"repeated_callback","registered_material_treatment":{"backend":"full","policy":""},
               "same_frame_continuation":{"enabled":False},
               "windows":{"first_144_steps":{"completed_rapier_steps":144,"rapier_steps_per_second":10,
                          "physical_gap_ms":{"p95":100,"p99":200,"max":300}}},
               "physical_gap_counts_above_ms":{"first_144_steps":{"100":20,"250":2,"500":0,"1000":0}}}
        arms.append({"index":index,"arm":"C","treatment":dict(treatment),"statistics":stats,
                     "slots":{"requested_slots":2,"effective_slots_verified":True},
                     "observers":{"presentation_enabled":False}})
    return arms


class FontRendererTests(unittest.TestCase):
    def test_separate_registration_retains_exact_same_engine_abba_and_original_oracle(self):
        value=registration()
        self.assertEqual(value["order"],ORDER)
        self.assertEqual([row["render_thread"] for row in ORDER],["safe","separate","separate","safe"])
        self.assertEqual(len(verify_renderer_reducer(ROOT)["registered_renderer_sha256"]),64)
        original=(ROOT/"tools/pubpres_final/renderer_registration.json").read_text()
        self.assertIn('"patched_render_owner_abba": [1, 2, 3, 4]',original)

    def test_same_engine_control_admits_no_owner_policy_outcome_or_observer_drift(self):
        original=arms_fixture();result=validate_cohort(original,registration(),"e"*64,False)
        self.assertTrue(result["physical_outcome_parity"]["same_source_pairs_equal"])
        self.assertFalse(result["registered_directions"]["same_repaired_engine_safe_separate_abba"]["repeatable_direction"])
        changes={"wrong-engine":lambda a:a[2]["statistics"]["match"].update(engine="f"*64),
                 "all-wrong-engine":lambda a:[row["statistics"]["match"].update(engine="f"*64) for row in a],
                 "different-cpu":lambda a:a[1]["statistics"]["match"].update(cpu="other"),
                 "different-runtime-owner":lambda a:a[1]["statistics"]["match"]["render_thread"].update(runtime="safe"),
                 "different-outcome":lambda a:a[1]["statistics"].update(first_144_body_trajectory_sha256="different"),
                 "different-action":lambda a:a[1]["statistics"].update(first_144_admitted_moves_sha256="different"),
                 "new-callback-credit":lambda a:a[1]["statistics"]["same_frame_continuation"].update(enabled=True),
                 "three-slots":lambda a:a[1]["slots"].update(requested_slots=3),
                 "extra-observer":lambda a:a[1]["observers"].update(presentation_enabled=True),
                 "missing-arm":lambda a:a.pop()}
        for name,change in changes.items():
            altered=copy.deepcopy(original);change(altered)
            with self.subTest(name=name),self.assertRaises(ValueError):
                validate_cohort(altered,registration(),"e"*64,False)

    def test_live_material_deadline_off_proof_is_required_in_both_selectors(self):
        status={"requested":{"CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ":"0"},
                "font_cohort_material_deadline":{"schema":"pubpres-material-deadline-v1","requested_hz":0,
                    "enabled":False,"physical_credit":False,"interval_usec":0,"pending_count":0,"accepted_uploads":0}}
        data={key:copy.deepcopy(status) for key in ("selectors_before","selectors_after")}
        validate_deadline_off(data)
        for phase in data:
            for field,value in (("requested_hz",30),("enabled",True),("physical_credit",True),
                                ("interval_usec",16667),("pending_count",1),("accepted_uploads",1),
                                ("pending_count",False),("accepted_uploads",0.0)):
                altered=copy.deepcopy(data);altered[phase]["font_cohort_material_deadline"][field]=value
                with self.subTest(phase=phase,field=field,value=value),self.assertRaises(ValueError):
                    validate_deadline_off(altered)
        altered=copy.deepcopy(data);altered["selectors_after"]["requested"]["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"]="30"
        with self.assertRaises(ValueError):validate_deadline_off(altered)


if __name__=="__main__":unittest.main()
