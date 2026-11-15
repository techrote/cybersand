"""M5 stdlib adversarial and matched-cohort smoke tests (synthetic only)."""
import copy
import unittest

from experiments.driv3r.m5_recovery.challenge import (
    START, GOAL, BUDGET, POLICIES, cohort, digest, legal, make_case, run
)


class M5ChallengeTests(unittest.TestCase):
    def test_all_frozen_families_are_distinct(self):
        ids = ("forced_culdesac", "switchback_gate", "misleading_plateau",
               "sealed_negative", "unblocked_control")
        self.assertEqual(len({digest(make_case(n)) for n in ids}), 5)

    def test_initial_prefix_genuinely_forces_brush_up_recovery(self):
        case = make_case("forced_culdesac")
        cursor = case["prefix"][-1]
        painted = {START, *case["prefix"]}
        offered = legal(case, painted, cursor, [START, *case["prefix"]], 0)
        self.assertEqual({o[0] for o in offered},
                         {"BACKTRACK", "RELOCATE_START", "STOP"})
        self.assertEqual(len(case["prefix"]), 7)

    def test_host_legal_catalog_not_affected_by_guidance_arm(self):
        case = make_case("misleading_plateau")
        initial = [START, *case["prefix"]]
        catalogs = [legal(case, set(initial), initial[-1], initial, 0)
                    for _ in POLICIES]
        self.assertTrue(all(x == catalogs[0] for x in catalogs))

    def test_strong_astar_reaches_all_reachable_development_goals(self):
        for name in ("forced_culdesac", "switchback_gate",
                     "misleading_plateau", "unblocked_control"):
            with self.subTest(name=name):
                report = run(make_case(name), "astar")
                self.assertTrue(report["terminated_at_goal"], report["stop_reason"])
                self.assertLessEqual(report["decisions"], BUDGET)
                self.assertTrue(report["connected_material"])
                self.assertEqual(report["model_decisions"], 0)
                self.assertFalse(report["native_qualified"])

    def test_sealed_hard_separator_refuses_false_success(self):
        case = make_case("sealed_negative")
        for policy in POLICIES:
            report = run(case, policy)
            self.assertFalse(report["terminated_at_goal"], policy)
            self.assertNotEqual(report["stop_reason"], "goal")
            self.assertEqual(report["connected_components"], 1)

    def test_recovery_does_not_erase_original_material(self):
        report = run(make_case("forced_culdesac"), "astar")
        recoveries = [e for e in report["events"] if e["kind"] == "recover"]
        self.assertTrue(recoveries)
        self.assertEqual(recoveries[0]["choice"], "RELOCATE_START")
        self.assertTrue(all(x["material_before_sha256"] ==
                            x["material_after_sha256"] for x in recoveries))
        self.assertGreater(report["productive_new_cells_after_recovery"], 0)

    def test_original_material_is_added_only_by_legal_one_cell_actions(self):
        case = make_case("misleading_plateau")
        for policy in POLICIES:
            report = run(case, policy)
            additions = [e for e in report["events"] if e["kind"] == "paint"]
            self.assertEqual(len(additions), report["new_painted_cells"])
            self.assertTrue(all(e["material_before_sha256"] !=
                                e["material_after_sha256"] for e in additions))
            self.assertTrue(all(e["native_receipt"] is None and
                                e["model_identity"] is None for e in report["events"]))

    def test_original_seeds_are_reproducible(self):
        case = make_case("switchback_gate")
        for policy in POLICIES:
            self.assertEqual(digest(run(case, policy, 570)),
                             digest(run(case, policy, 570)))
        self.assertEqual(digest(run(case, "random_legal", 570)),
                         digest(run(case, "random_legal", 570)))

    def test_candidate_hash_and_case_hash_change_under_tamper(self):
        case = make_case("forced_culdesac")
        before = digest(case)
        altered = copy.deepcopy(case)
        altered["hard"] = tuple(sorted(set(case["hard"]) - {(9, 6)}))
        self.assertNotEqual(digest(altered), before)
        self.assertNotEqual(
            digest(legal(case, {START, *case["prefix"]}, case["prefix"][-1],
                         [START, *case["prefix"]], 0)),
            digest(legal(altered, {START, *case["prefix"]}, case["prefix"][-1],
                         [START, *case["prefix"]], 0)))

    def test_cohort_is_matched_and_cannot_assert_model_or_native(self):
        rows = cohort()
        self.assertEqual(len(rows), 5)
        for name, arms in rows.items():
            with self.subTest(name=name):
                self.assertEqual(set(arms), set(POLICIES))
                self.assertEqual(len({x["initial_material_sha256"] for x in arms.values()}), 1)
                self.assertEqual(len({x["first_legal_catalog_sha256"] for x in arms.values()}), 1)
                self.assertTrue(all(not x["model_qualified"] and
                                    not x["native_qualified"] for x in arms.values()))


if __name__ == "__main__":
    unittest.main()
