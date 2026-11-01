import copy
import math
import unittest
from bearing_candidate_analysis import efficacy,settling,state,disposition,longest

def base():
    return {"maximum_entry":10.,"maximum_pre_overlap":40,"descent_no_target":100,
            "common_start_stopping_distance":10.,"first_no_target":{"tick":5},"peak_upward_rebound":4.,
            "settled":{"span":.2,"net_drift":.01,"p95_abs_vy":2.,"max_abs_vy":3.,"overlap_sum":0,"overlap_frames":0,"overlap_max":0,"large_cycles":0},
            "longest_hover":0,"longest_artificial_lift":0}

class Gates(unittest.TestCase):
    def test_exact_gate_and_no_rounding(self):
        b=base();c=copy.deepcopy(b);c.update(maximum_entry=8.,maximum_pre_overlap=30,descent_no_target=75)
        self.assertTrue(efficacy(b,c)["pass"])
        c["maximum_entry"]=math.nextafter(8.,math.inf)
        self.assertFalse(efficacy(b,c)["pass"])
    def test_both_primary_outcomes_required(self):
        b=base();c=copy.deepcopy(b);c.update(maximum_entry=7,descent_no_target=0)
        self.assertFalse(efficacy(b,c)["pass"])
    def test_delay_or_prevention(self):
        b=base();c=copy.deepcopy(b);c.update(maximum_entry=8,maximum_pre_overlap=30,first_no_target={"tick":6})
        self.assertTrue(efficacy(b,c)["pass"])
        c["first_no_target"]=None
        self.assertTrue(efficacy(b,c)["failure_prevented"])
    def test_stopping_fraction_and_absolute_are_conjunctive(self):
        b=base();b["common_start_stopping_distance"]=1.;c=copy.deepcopy(b);c.update(maximum_entry=8,maximum_pre_overlap=30,common_start_stopping_distance=.7)
        self.assertFalse(efficacy(b,c)["corroboration"])
        c["common_start_stopping_distance"]=.5
        self.assertTrue(efficacy(b,c)["pass"])
    def test_censored_stop_is_not_improvement(self):
        b=base();c=copy.deepcopy(b);c["common_start_stopping_distance"]=None
        self.assertIsNone(efficacy(b,c)["stopping_reduction"])
    def test_rebound_exact_conjunction(self):
        b=base();c=copy.deepcopy(b);c["peak_upward_rebound"]=6.
        self.assertTrue(settling(b,c)["gates"]["rebound"])
        c["peak_upward_rebound"]=math.nextafter(6.,math.inf)
        self.assertFalse(settling(b,c)["gates"]["rebound"])
    def test_hover_and_persistent_overlap_fail(self):
        b=base();c=copy.deepcopy(b);c["longest_hover"]=30
        self.assertFalse(settling(b,c)["pass"])
        c=copy.deepcopy(b);c["settled"]["overlap_sum"]=1
        self.assertFalse(settling(b,c)["pass"])
    def test_safety_overrides_large_efficacy(self):
        self.assertEqual(state([{"pass":True,"material_effect":True}]*2,False,True),"N")
    def test_partial_requires_material_mechanism(self):
        c=[{"pass":False,"material_effect":True}]
        self.assertEqual(state(c,True,True),"P");self.assertEqual(state(c,True,False),"N")
    def test_all_disposition_labels(self):
        self.assertEqual(disposition("H","N"),"Y1 HIGH-VALUE / A2 NO-GO")
        self.assertEqual(disposition("N","H"),"A2 HIGH-VALUE / Y1 NO-GO")
        self.assertEqual(disposition("N","N"),"both NO-GO")
        self.assertEqual(disposition("H","P"),"partial/mechanistic result only")
        self.assertIn("combination",disposition("H","H"))
    def test_consecutive_episode(self):self.assertEqual(longest([False,True,True,False,True]),2)

if __name__=="__main__":unittest.main()
