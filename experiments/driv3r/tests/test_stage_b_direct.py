"""Synthetic unit tests of the frozen cohort; never native or model evidence."""
from copy import deepcopy
from pathlib import Path
import tempfile
import threading
import unittest

from experiments.driv3r.contracts import Refusal, validate_decision
from experiments.driv3r.controller import EpisodeController
from experiments.driv3r.providers import observation, permitted
from experiments.driv3r.stage_b.direct import (
    DirectCaseProvider, GeometricPolicy, RandomLegalPolicy, _shortest_legal_moves,
    load_cases, score_episode,
)
from experiments.driv3r.tests.test_controller import SyntheticNative, TestPolicy


class DirectFixtureDouble(SyntheticNative):
    """Existing unit double with catalog materials, not another native backend."""

    def reset(self, fixture, **kwargs):
        super().reset(**kwargs)
        case = next(c for c in load_cases() if c["fixture"]["id"] == fixture)
        self.state["materials"] = [0]*9216
        for x, y, width, height, material in case["fixture"]["edits"]:
            for cy in range(y, y+height):
                for cx in range(x, x+width):
                    self.state["materials"][cy*96+cx] = material
        self.state["fixture"] = fixture
        return self.observe()


class DirectCohortTests(unittest.TestCase):
    def observed(self, case, **provider_options):
        provider = DirectCaseProvider(case, **provider_options)
        state = DirectFixtureDouble().reset(provider.fixture)["observation"]
        obs = observation(state, provider, episode_id="synthetic-stage-b-direct", step=0,
                          decisions_remaining=case["max_decisions"], changed_cells_remaining=32,
                          wall_seconds_remaining=60)
        return provider, state, obs, provider.candidates(state, obs)

    def run_case(self, case, policy, **provider_options):
        native = DirectFixtureDouble()
        with tempfile.TemporaryDirectory() as tmp:
            result = EpisodeController(max_decisions=case["max_decisions"], max_changed_cells=32,
                                       max_wall_seconds=60, request_seconds=5).run(
                native=native, provider=DirectCaseProvider(case, **provider_options), policy=policy,
                episode_id="synthetic-stage-b-direct", output=Path(tmp)/"episode")
        return result, native

    def test_frozen_split_reachability_and_fit_inside_decision_budget(self):
        cases = load_cases()
        self.assertEqual((len(load_cases("development")), len(load_cases("held_out"))), (2, 4))
        self.assertEqual({c["category"] for c in load_cases("held_out")},
                         {"corner", "offset_recovery", "blocked_preferred_move", "early_stop"})
        for case in cases:
            with self.subTest(case=case["id"]):
                _, state, _, _ = self.observed(case)
                self.assertTrue(permitted(state, *case["start"]))
                self.assertTrue(permitted(state, *case["target"]))
                moves = _shortest_legal_moves(state, case["start"], case["target"])
                self.assertEqual(moves, case["success"]["expected_shortest_legal_moves"])
                self.assertLessEqual(moves+1, case["max_decisions"])
                self.assertLessEqual(case["max_decisions"], 8)
                self.assertNotEqual(case["objective"], case["paraphrase"])

    def test_catalog_copies_do_not_allow_silent_case_redefinition(self):
        case = load_cases()[0]
        case["target"][0] += 1
        with self.assertRaises(Refusal):
            DirectCaseProvider(case)
        self.assertEqual(load_cases()[0]["target"], [11, 19])
        with self.assertRaises(Refusal):
            DirectCaseProvider("unregistered-case")
        with self.assertRaises(ValueError):
            load_cases("training")

    def test_all_candidates_are_legal_cardinal_and_stop_never_paints(self):
        for case in load_cases():
            with self.subTest(case=case["id"]):
                _, state, obs, candidates = self.observed(case)
                self.assertEqual(len([c for c in candidates if c["id"] == "STOP"]), 1)
                for action in candidates:
                    if action["kind"] == "stop":
                        self.assertEqual(action["operations"], [])
                        self.assertIsNone(action["destination"])
                    else:
                        point = action["destination"]
                        self.assertTrue(permitted(state, *point))
                        self.assertEqual(sum(abs(a-b) for a, b in zip(point, obs["cursor"])), 1)
                        self.assertNotIn("expected_shortest_legal_moves", action["predicted"])
                        self.assertNotIn("oracle", str(action["predicted"]))
        blocked = next(c for c in load_cases() if c["category"] == "blocked_preferred_move")
        _, _, _, candidates = self.observed(blocked)
        self.assertEqual({c["id"] for c in candidates}, {"UP", "DOWN", "LEFT", "STOP"})

    def test_objective_wrong_actions_remain_legal_not_host_repaired(self):
        corner = next(c for c in load_cases() if c["category"] == "corner")
        _, _, _, candidates = self.observed(corner)
        up = next(c for c in candidates if c["id"] == "UP")
        self.assertEqual(up["predicted"]["wall_clearance_cells"], 1)
        self.assertEqual(up["predicted"]["clearance_requirement"]["minimum_cells"], 2)
        # Physical permission does not encode task quality: a poor UP choice
        # reaches the executor unchanged, then fails the geometric criterion.
        record, native = self.run_case(corner, TestPolicy("UP"))
        self.assertEqual(record["steps"][0]["selected_action"]["id"], "UP")
        self.assertEqual(record["steps"][0]["host_status"], "applied")
        self.assertGreater(native.writes, 0)
        self.assertFalse(score_episode(corner, record)["task_success"])

    def test_geometric_baseline_solves_frozen_geometry_with_explicit_stop(self):
        for case in load_cases():
            with self.subTest(case=case["id"]):
                record, _ = self.run_case(case, GeometricPolicy())
                score = score_episode(case, record)
                self.assertTrue(score["task_success"], score)
                self.assertFalse(record["task_complete"])
                self.assertTrue(score["explicit_policy_stop"])
                self.assertEqual(record["steps"][-1]["selected_action"]["id"], "STOP")
                self.assertEqual(score["protected_changed_cells"], 0)
                self.assertEqual(score["unexpected_changed_cells"], 0)
                self.assertEqual(score["excess_movements"], 0)
                self.assertEqual(score["actual_changed_cells"], score["readback_changed_cells"])

    def test_baselines_are_stable_under_candidate_order(self):
        for case in load_cases():
            _, _, obs, candidates = self.observed(case)
            for factory in (GeometricPolicy, lambda: RandomLegalPolicy(57031)):
                normal = factory().decide(obs, candidates, timeout_seconds=5, cancel_event=threading.Event())
                reverse = factory().decide(obs, candidates[::-1], timeout_seconds=5, cancel_event=threading.Event())
                self.assertEqual(normal["candidate_id"], reverse["candidate_id"])
                validate_decision(normal, obs, candidates)
                validate_decision(reverse, obs, candidates[::-1])

    def test_same_information_geometric_baseline_has_no_fixture_parameter(self):
        case = load_cases()[0]
        _, _, obs, candidates = self.observed(case)
        answer = GeometricPolicy().decide(obs, candidates, timeout_seconds=5, cancel_event=threading.Event())
        # Changing opaque episode/world identity changes custody hashes but not
        # the geometric answer. No case ID, private fixture or oracle is read.
        other = deepcopy(obs)
        other["episode_id"] = "different-audit-identity"
        other["world"]["id"] = "different-world-identity"
        again = GeometricPolicy().decide(other, candidates, timeout_seconds=5, cancel_event=threading.Event())
        self.assertEqual(answer["candidate_id"], again["candidate_id"])
        self.assertNotEqual(answer["state_sha256"], again["state_sha256"])

    def test_random_baseline_can_choose_stop_and_records_seed(self):
        case = load_cases()[0]
        _, _, obs, candidates = self.observed(case)
        seen = set()
        for seed in range(30):
            answer = RandomLegalPolicy(seed).decide(obs, candidates, timeout_seconds=5, cancel_event=threading.Event())
            seen.add(answer["candidate_id"])
            self.assertEqual(answer["raw"]["seed"], seed)
            self.assertTrue(answer["raw"]["includes_stop"])
            self.assertEqual(answer["raw"]["sampling_probability"], 1/len(candidates))
            self.assertEqual(set(answer["probabilities"].values()), {1/len(candidates)})
        self.assertEqual(seen, {c["id"] for c in candidates})

    def test_seeded_random_episode_reproduces_actions_across_orderings(self):
        case = next(c for c in load_cases() if c["category"] == "blocked_preferred_move")
        normal, _ = self.run_case(case, RandomLegalPolicy(57031))
        reverse, _ = self.run_case(case, RandomLegalPolicy(57031), reverse_order=True)
        self.assertEqual([s["decision"]["candidate_id"] for s in normal["steps"]],
                         [s["decision"]["candidate_id"] for s in reverse["steps"]])
        self.assertEqual(normal["final_native"]["materials"], reverse["final_native"]["materials"])
        self.assertEqual(normal["terminal_status"], reverse["terminal_status"])

    def test_stop_at_initial_target_is_real_decision_with_zero_writes(self):
        case = next(c for c in load_cases() if c["category"] == "early_stop")
        provider, _, _, candidates = self.observed(case)
        self.assertFalse(provider.complete())
        self.assertEqual(len(candidates), 5)
        record, native = self.run_case(case, TestPolicy("STOP"))
        self.assertEqual(record["decisions"], 1)
        self.assertEqual(native.writes, 0)
        score = score_episode(case, record)
        self.assertTrue(score["task_success"], score)
        self.assertEqual(score["readback_changed_cells"], 0)

    def test_wrong_early_stop_and_model_failure_stay_in_denominator(self):
        case = load_cases()[0]
        for policy in (TestPolicy("STOP"), TestPolicy(status="timeout"), TestPolicy("UNKNOWN")):
            with self.subTest(policy=policy.__dict__):
                record, native = self.run_case(case, policy)
                score = score_episode(case, record)
                self.assertFalse(score["task_success"])
                self.assertTrue(score["failure_reasons"])
                self.assertEqual(score["case_id"], case["id"])
                self.assertEqual(native.writes, 0)
                if policy.choice == "STOP":
                    self.assertTrue(score["premature_stop"])

    def test_early_stop_case_penalizes_unnecessary_real_movement(self):
        case = next(c for c in load_cases() if c["category"] == "early_stop")
        record, native = self.run_case(case, TestPolicy("UP"))
        score = score_episode(case, record)
        self.assertGreater(native.writes, 0)
        self.assertFalse(score["task_success"])
        self.assertGreater(score["movements_after_first_goal"], 0)
        self.assertIn("movement_budget_exceeded", score["failure_reasons"])

    def test_corrupted_readback_and_cursor_cannot_receive_success(self):
        case = load_cases()[0]
        record, _ = self.run_case(case, GeometricPolicy())
        self.assertTrue(score_episode(case, record)["task_success"])
        edited = deepcopy(record)
        edited["final_native"]["materials"][8*96+8] = 58
        bad = score_episode(case, edited)
        self.assertFalse(bad["task_success"])
        self.assertEqual(bad["protected_changed_cells"], 1)
        edited = deepcopy(record)
        edited["final_cursor"] = [1, 1]
        bad = score_episode(case, edited)
        self.assertFalse(bad["task_success"])
        self.assertFalse(bad["path_bound_to_native_readback"])


if __name__ == "__main__":
    unittest.main()
