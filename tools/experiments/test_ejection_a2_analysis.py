"""Weighting and preregistered decision gates, separate from frozen B/C tests."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parent))
import analyze_ejection_a2 as analysis


def row(success=False, recover=False):
    return {"production_success":success,"policies":{p:{str(k):{"legal":recover} for k in (1,2,3,4)}
                                                    for p in ("forward","forward_lateral")}}


def summary(rate, failed=1000):
    return {"failed":failed,"policies":{p:{"4":{"additional_fraction":rate}}
                                          for p in ("forward","forward_lateral")}}


class A2AnalysisTests(unittest.TestCase):
    def test_multiplicity_weighting_keeps_baseline_and_additions_separate(self):
        result=analysis.weighted_c([row(True),row(False,True),row()],[3,4,2])
        self.assertEqual((result["baseline"],result["failed"],result["total"]),(3,6,9))
        cap=result["policies"]["forward"]["4"]
        self.assertEqual(cap["additional_recovered"],4)
        self.assertEqual(cap["baseline_plus_chain"],7)
        self.assertEqual(cap["additional_fraction"],4/6)

    def test_invalid_multiplicities_are_not_silently_truncated(self):
        for weights in ([],[0],[1.5]):
            with self.assertRaises(ValueError):
                analysis.weighted_c([row()],weights)

    def test_preregistered_strong_no_go_threshold(self):
        self.assertIn("strong NO-GO",analysis.decide(summary(.001),summary(.001),{})["disposition"])
        self.assertIn("strong NO-GO",analysis.decide(summary(.01),summary(.01),{})["disposition"])

    def test_subgroup_signal_is_not_lost_in_aggregate(self):
        groups={"penetration:deep":{"unique":summary(.10,20),"events":summary(.10,50)}}
        result=analysis.decide(summary(.001),summary(.001),groups)
        self.assertIn("conditional subgroup",result["disposition"])
        self.assertEqual(result["high_value_predeclared_subgroups"],["penetration:deep"])
        groups["penetration:deep"]["unique"]["failed"]=19
        self.assertIn("strong NO-GO",analysis.decide(summary(.001),summary(.001),groups)["disposition"])

    def test_either_weight_can_raise_an_unexpected_signal(self):
        self.assertIn("GO signal",analysis.decide(summary(0),summary(.10),{})["disposition"])
        self.assertIn("GO signal",analysis.decide(summary(.10),summary(0),{})["disposition"])

    def test_intermediate_region_is_not_relabelled_no_go(self):
        self.assertIn("inconclusive",analysis.decide(summary(.02),summary(.02),{})["disposition"])

    def test_no_observed_failure_cannot_qualify_no_go(self):
        positive_only=analysis.weighted_c([row(True)],[1])
        self.assertIn("inconclusive",analysis.decide(positive_only,positive_only,{})["disposition"])
        empty=analysis.weighted_c([],[])
        self.assertIn("inconclusive",analysis.decide(empty,empty,{})["disposition"])

    def test_failed_replay_blocks_all_analysis(self):
        with self.assertRaises(ValueError):
            analysis.run({"capsules":[]},{"capsules":[]},{"ok":False},{},{},{},Path("."))


if __name__ == "__main__":
    unittest.main()
