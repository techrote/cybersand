import copy
import unittest

from post_arrest_analysis import clearance, episodes
from run_post_arrest import stable


def frames(values, pre=None):
    return [{"geometry": {"pre_overlap": (pre or values)[i], "post_ejection_overlap": v,
                          "post_tick_overlap_at_packed_pose": v}} for i, v in enumerate(values)]


class ClearanceTests(unittest.TestCase):
    def test_prevented_is_not_cleared_at_zero(self):
        r = clearance(frames([0]*1800))
        self.assertTrue(r["contact_prevented"])
        self.assertIsNone(r["first_sustained_clearance"])
        self.assertIsNone(r["right_censored_at"])

    def test_initial_air_frames_do_not_supply_clearance(self):
        r = clearance(frames([0]*90+[1]*1710))
        self.assertIsNone(r["first_zero_after_contact"])
        self.assertEqual(r["right_censored_at"], 1800)

    def test_one_zero_is_not_sustained(self):
        r = clearance(frames([1]*100+[0]+[1]*1699))
        self.assertEqual(r["first_zero_after_contact"], 100)
        self.assertIsNone(r["first_sustained_clearance"])
        self.assertEqual(r["recurrence_samples"], [101])

    def test_exact_sixty_qualifies(self):
        r = clearance(frames([1]*1740+[0]*60))
        self.assertEqual(r["first_sustained_clearance"], 1740)
        self.assertEqual(r["clearance_confirmed_at"], 1799)

    def test_fifty_nine_is_censored(self):
        self.assertEqual(clearance(frames([1]*1741+[0]*59))["right_censored_at"], 1800)

    def test_recurrence_after_sustained_is_preserved(self):
        r = clearance(frames([1]*100+[0]*60+[1]*10+[0]*1630))
        self.assertEqual(r["recurrence_after_sustained"], [160])
        self.assertEqual(r["first_sustained_clearance"], 100)

    def test_both_overlap_boundaries_required(self):
        f = frames([1]+[0]*1799)
        for row in f:
            row["geometry"]["post_tick_overlap_at_packed_pose"] = 1
        self.assertIsNone(clearance(f)["first_sustained_clearance"])

    def test_pre_ejection_contact_is_still_contact(self):
        f = frames([0]*1800, [1]+[0]*1799)
        r = clearance(f)
        self.assertFalse(r["contact_prevented"])
        self.assertEqual(r["first_sustained_clearance"], 0)

    def test_episode_edges(self):
        self.assertEqual(episodes([True, True, False, True]), [[0, 1], [3, 3]])

    def test_prefix_normalizes_only_explicit_volatile_data(self):
        a = {"body_input": [1, 2.0], "bearing": {"owner": "old", "raw_support": 9}, "consumer_usec": 123}
        b = copy.deepcopy(a)
        b["bearing"]["owner"] = "new"
        b["consumer_usec"] = 456
        self.assertEqual(stable(a), stable(b))
        for key in ("body_input", "bearing"):
            c = copy.deepcopy(b)
            if key == "body_input":
                c[key][1] += 1e-12
            else:
                c[key]["raw_support"] -= 1
            self.assertNotEqual(stable(a), stable(c))


if __name__ == "__main__":
    unittest.main()
