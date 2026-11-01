"""Measurement-boundary/conditional-admission controls, no runtime tuning."""
import copy
import unittest

from granular_bearing_analysis import conditional_gate, motion_budget, neutral, support_collapse, summarize


def frame():
    before = [112,160,0.08,0,3,0]
    corrected = [112,159.95,0.08,0,0,0]
    after = [112,159.95,0.08,0,-2,0]
    return {"tick":0,"after_step":before,"before_step":[112,159.9,0.08,0,2,0],
            "body_input":[1,112,160,0.08,8,14,0,3,0,1,1],
            "requested_results":[1,0,-2,0,-.05,0,0,0,1],"bridge_application":[0,0,-2,0,0,1],
            "application_details":[{"age":0,"before":before,"after_correction":corrected,
                                    "after_impulse":after,"applied_correction":[0,-.05]}],
            "backend":{"step":1/60,"gravity":[0,92.12],"linear_damp":.25},
            "bearing":{"raw_support":2},"geometry":{"pre_overlap":2}}


class Measurements(unittest.TestCase):
    def test_correction_momentum_is_not_an_impulse(self):
        b=motion_budget(frame())
        self.assertEqual(b["correction_dp"],[0,-3])
        self.assertEqual(b["impulse_dp"],[0,-2])
        self.assertEqual(b["impulse_error"],0)

    def test_actual_gravity_is_separate_from_law_reference(self):
        self.assertAlmostEqual(motion_budget(frame())["gravity_dp"][1],92.12/60)

    def test_age_blocks_synchronous_interpretation(self):
        f=frame();f["application_details"][0]["age"]=1
        with self.assertRaises(ValueError):motion_budget(f)

    def test_motion_boundary_mismatch_blocks(self):
        f=frame();f["after_step"]=list(f["after_step"]);f["after_step"][4]=4
        with self.assertRaises(ValueError):motion_budget(f)

    def test_conditional_admission_requires_both_observations(self):
        one={"first_support":{"vy":50},"maximum_initial_surface_entry":4,"maximum_pre_overlap":20}
        four={"first_support":{"vy":90},"maximum_initial_surface_entry":9,"maximum_pre_overlap":20}
        self.assertTrue(conditional_gate(one,four))
        four["first_support"]["vy"]=40
        self.assertFalse(conditional_gate(one,four))
        four["first_support"]=None
        self.assertFalse(conditional_gate(one,four))

    def test_support_collapse_requires_two_descending_zeros(self):
        frames=[frame() for _ in range(3)]
        for i,f in enumerate(frames):f["tick"]=i
        frames[1]["bearing"]["raw_support"]=0;frames[2]["bearing"]["raw_support"]=0
        self.assertEqual(support_collapse(frames),[1])
        frames[2]["body_input"][7]=-1
        self.assertEqual(support_collapse(frames),[])

    def test_incomplete_trace_blocks_reduction(self):
        with self.assertRaises(ValueError):summarize({"complete":True,"native_counters":{"dropped":0}}, {"frames":[]}, {})

    def test_neutrality_does_not_ignore_physics_changes(self):
        self.assertFalse(neutral({"frames":[]},{"frames":[]}))
        keys=("tick","body_input","before_step","after_step","pre_tick_metrics","pre_tick_results",
              "post_tick_metrics","requested_results","bridge_application","after_application",
              "physical_hash","events","stored_counts","attempted_tick","completed_tick")
        a={"frames":[{k:0 for k in keys} for _ in range(600)]};b=copy.deepcopy(a)
        self.assertTrue(neutral(a,b));b["frames"][500]["physical_hash"]=1
        self.assertFalse(neutral(a,b))


if __name__ == "__main__":unittest.main()
