import copy
import json
import unittest

from post_arrest_accounting import CAMPAIGN, account, oracle


class AccountingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.frames = json.loads((CAMPAIGN / "Y1-speed90-on/trajectory.json").read_text())["frames"]

    def test_retained_windows_close_without_fitting(self):
        result = oracle()
        self.assertTrue(result["pass"])
        self.assertEqual(len(result["rows"]), 42)
        self.assertEqual(len(result["pairs"]), 21)
        self.assertLess(result["maximum_unrounded_position_residual"], 2e-5)

    def test_wrong_impulse_cannot_close(self):
        frame = copy.deepcopy(self.frames[301])
        frame["application_details"][0]["requested_impulse"][1] += .01
        self.assertGreater(account(frame)["residuals"]["after_impulse"], .009)

    def test_missing_zeroing_cannot_close(self):
        frame = copy.deepcopy(self.frames[301])
        frame["application_details"][0]["after_correction"][4] = frame["after_step"][4]
        self.assertGreater(account(frame)["residuals"]["after_correction"], 1)

    def test_wrong_sample_boundary_cannot_close(self):
        following = copy.deepcopy(self.frames[302])
        following["before_step"][1] += .1
        self.assertGreater(account(self.frames[301], following)["residuals"]["next_pre_rapier"], .09)

    def test_final_missing_boundary_is_explicit(self):
        row = account(self.frames[599])
        self.assertTrue(row["next_boundary_missing"])
        self.assertIsNone(row["next_after_step"])
        self.assertNotIn("next_pre_rapier", row["residuals"])

    def test_oracle_leaves_copied_inputs_unchanged(self):
        before = copy.deepcopy(self.frames[301:303])
        account(self.frames[301], self.frames[302])
        self.assertEqual(before, self.frames[301:303])


if __name__ == "__main__":
    unittest.main()
