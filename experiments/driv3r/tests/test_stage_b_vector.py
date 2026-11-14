"""Synthetic unit checks only; these fixtures do not qualify real model/native use."""
from copy import deepcopy
from pathlib import Path
import tempfile
import threading
import unittest

from experiments.driv3r.contracts import Refusal, digest, validate_decision
from experiments.driv3r.controller import EpisodeController, decision_record, validate_episode
from experiments.driv3r.providers import observation, permitted
from experiments.driv3r.stage_b.representation import decode, encode
from experiments.driv3r.stage_b.vector import (
    ALGORITHMS, DIRECTIONS, VectorGeometricBaseline, VectorGeometryPreferenceBaseline,
    VectorProvider, VectorRandomBaseline,
    generate_path, load_cases, path_metrics, score_episode, validate_case,
)
from experiments.driv3r.tests.test_controller import SyntheticNative


class SyntheticVectorNative(SyntheticNative):
    """Material-array test double; never a native execution or inference claim."""
    def __init__(self, case):
        super().__init__()
        self.case = case

    def reset(self, fixture=None, **_):
        if fixture is not None and fixture != self.case["fixture"]["id"]:
            raise Refusal("Unknown synthetic vector fixture")
        super().reset()
        self.state["materials"] = [0]*9216
        self.state["world_id"] = "synthetic-vector-unit-world"
        for x, y, w, h, material in self.case["fixture"]["edits"]:
            for py in range(y, y+h):
                for px in range(x, x+w):
                    self.state["materials"][py*96+px] = material
        return self.observe()

    def apply(self, operations, **_):
        self.writes += 1
        changed = 0
        for op in operations:
            if op["shape"] != "pixels":
                raise Refusal("Synthetic vector double accepts only pixels")
            for x, y in op["points"]:
                if not permitted(self.state, x, y):
                    raise Refusal("Synthetic protected cell")
                changed += self.state["materials"][y*96+x] != 58
                self.state["materials"][y*96+x] = 58
        self.state["revision"] += 1
        return {**self.observe(), "receipt": {"actual_changed_cells": changed,
                "expected_changed_cells": changed, "readback_matches": True}}


class SequencePolicy:
    name = "synthetic-vector-sequence-policy"

    def __init__(self, *choices):
        self.choices = iter(choices)
        self.seen = []

    def decide(self, obs, candidates, **_):
        self.seen.append((deepcopy(obs), deepcopy(candidates)))
        choice = next(self.choices)
        return decision_record(obs, candidates, choice=choice,
                               probabilities={c["id"]: float(c["id"] == choice) for c in candidates}, confidence=1.0,
                               model_identity={"kind": "synthetic_unit_fixture"},
                               backend_identity={"kind": "synthetic_unit_fixture"}, raw={"synthetic": True})


def observed(native, provider, step=0):
    return observation(native, provider, episode_id="vector-unit", step=step, decisions_remaining=4-step,
                       changed_cells_remaining=64, wall_seconds_remaining=30)


class VectorGeometryTests(unittest.TestCase):
    def test_catalog_has_one_development_and_three_held_out_cases(self):
        cases = load_cases()
        self.assertEqual(len(load_cases("development")), 1)
        self.assertEqual(len(load_cases("held_out")), 3)
        self.assertEqual(len({c["fixture"]["id"] for c in cases}), 4)
        with self.assertRaises(Refusal):
            load_cases("training")

    def test_case_schema_rejects_unbounded_distance_seed_and_region(self):
        for key, value in (("distances", [6, 11]), ("distances", [6, 6]), ("distances", [True]),
                           ("seed", -1), ("start", [100, 20])):
            case = load_cases()[0]
            case[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(Refusal):
                validate_case(case)
        case = load_cases()[0]
        case["preference"]["coverage_region"] = [95, 0, 2, 1]
        with self.assertRaises(Refusal):
            validate_case(case)

    def test_all_algorithms_preserve_cardinal_displacement_and_bounds(self):
        for direction, (dx, dy) in DIRECTIONS.items():
            for distance in range(1, 11):
                for algorithm in ALGORITHMS:
                    with self.subTest(direction=direction, distance=distance, algorithm=algorithm):
                        path = generate_path([24, 24], direction, distance, algorithm, seed=2718)
                        metrics = path_metrics(path, [24, 24], direction, distance)
                        self.assertEqual(path[0], [24, 24])
                        self.assertEqual(path[-1], [24+dx*distance, 24+dy*distance])
                        self.assertLessEqual(metrics["travel_ratio"], 3)
                        self.assertLessEqual(metrics["max_transverse_excursion"], 2)
                        self.assertEqual(metrics["endpoint_error"], 0)
                        self.assertTrue(all(abs(a[0]-b[0])+abs(a[1]-b[1]) == 1 for a, b in zip(path, path[1:])))

    def test_seeded_paths_have_immutable_expected_hashes(self):
        case = load_cases("held_out")[2]
        path = generate_path(case["start"], "UP", 6, "SEEDED_BRIDGE", seed=case["seed"])
        self.assertEqual(digest(path), "5cbd54b614fba8f712feb1290d0b61492e9e0eb0266c10642d71d2e0eb7affb1")
        self.assertEqual(path, generate_path(case["start"], "UP", 6, "SEEDED_BRIDGE", seed=2718))
        self.assertNotEqual(path, generate_path(case["start"], "UP", 6, "SEEDED_BRIDGE", seed=1337))
        self.assertEqual(path[-1], generate_path(case["start"], "UP", 6, "SEEDED_BRIDGE", seed=1337)[-1])

    def test_compact_encoding_preserves_every_path_point_turn_and_retrace(self):
        for direction in DIRECTIONS:
            for distance in range(1, 11):
                for algorithm in ALGORITHMS:
                    path = generate_path([24, 24], direction, distance, algorithm, seed=2718)
                    self.assertEqual(decode(encode(path)), path)
        retraced = [[20+i % 2, 20] for i in range(12)]
        packed = encode(retraced)
        self.assertEqual(packed, {"$path_start": [20, 20], "$moves": "RLRLRLRLRLR"})
        self.assertEqual(decode(packed), retraced)

    def test_algorithms_have_different_masks_and_measured_coverage(self):
        case = load_cases("held_out")[0]
        paths = {a: generate_path(case["start"], "RIGHT", 10, a, seed=case["seed"]) for a in ALGORITHMS}
        masks = {a: frozenset(map(tuple, p)) for a, p in paths.items()}
        self.assertEqual(len(set(masks.values())), len(ALGORITHMS))
        counts = {a: path_metrics(p, case["start"], "RIGHT", 10, case["preference"]["coverage_region"])["coverage_cells"]
                  for a, p in paths.items()}
        self.assertEqual(counts, {"STRAIGHT": 0, "BOUNDED_SERPENTINE": 12, "HILBERT_MOTIF": 10, "SEEDED_BRIDGE": 6})

    def test_malformed_or_outside_corridor_path_refused(self):
        original = generate_path([20, 20], "RIGHT", 6, "STRAIGHT")
        endpoint = deepcopy(original)
        endpoint[-1] = [20, 26]
        jump = deepcopy(original)
        jump[1] = [22, 20]
        excursion = [[20, 20], [20, 21], [20, 22], [20, 23], [21, 23], [21, 22], [21, 21],
                     [21, 20], [22, 20], [23, 20], [24, 20], [25, 20], [26, 20]]
        for path in (endpoint, jump, excursion, original*4):
            with self.subTest(path=path), self.assertRaises(Refusal):
                path_metrics(path, [20, 20], "RIGHT", 6)
        with self.assertRaises(Refusal):
            generate_path([20, 20], "DIAGONAL", 6, "STRAIGHT")

    def test_retrace_counts_are_distinct_from_travel_and_unique_cells(self):
        path = [[20, 20], [21, 20], [20, 20], [21, 20], [22, 20]]
        metrics = path_metrics(path, [20, 20], "RIGHT", 2)
        self.assertEqual(metrics["travelled_length"], 4)
        self.assertEqual(metrics["unique_path_cells"], 3)
        self.assertEqual(metrics["retrace_visits"], 2)
        self.assertEqual(metrics["retraced_edges"], 2)


class VectorProviderTests(unittest.TestCase):
    def setUp(self):
        self.case = load_cases()[0]
        self.provider = VectorProvider(self.case)
        self.native = SyntheticVectorNative(self.case)
        self.state = self.native.reset()["observation"]

    def offers(self, step=0):
        obs = observed(self.state, self.provider, step)
        return obs, self.provider.candidates(self.state, obs)

    def test_intent_is_no_paint_then_later_tool_preserves_it(self):
        obs, choices = self.offers()
        self.assertEqual(len(choices), 8)
        self.assertNotIn("INTENT_DOWN_10", {c["id"] for c in choices})
        intent = next(c for c in choices if c["id"] == "INTENT_RIGHT_6")
        self.assertEqual(intent["operations"], [])
        self.assertIsNone(intent["destination"])
        self.assertEqual(intent["kind"], "skip")
        self.provider.accept(intent)
        self.assertEqual(self.provider.cursor, [20, 20])
        self.assertEqual(self.provider.history, [[20, 20]])
        self.assertEqual(self.native.writes, 0)
        next_obs, tools = self.offers(1)
        self.assertNotEqual(next_obs["subgoal"], obs["subgoal"])
        tool = next(c for c in tools if c["id"] == "STRAIGHT")
        self.assertIsNone(tool["destination"])
        self.assertEqual(tool["predicted"]["selected_intent"]["id"], "INTENT_RIGHT_6")
        self.assertEqual(tool["operations"][0]["points"][0], self.case["start"])
        self.assertEqual(len(tool["operations"][0]["points"]), 7)
        # Unit test simulates the controller's acknowledgement callback only.
        self.provider.accept(tool)
        self.assertEqual(self.provider.cursor, [26, 20])
        self.assertTrue(self.provider.complete())

    def test_wrong_but_legal_intent_is_not_repaired_to_target(self):
        _, choices = self.offers()
        self.provider.accept(next(c for c in choices if c["id"] == "INTENT_UP_6"))
        _, tools = self.offers(1)
        for tool in tools:
            if tool["kind"] == "tool":
                self.assertEqual(tool["predicted"]["metrics"]["endpoint"], [20, 14])
        self.provider.accept(next(c for c in tools if c["id"] == "STRAIGHT"))
        self.assertEqual(self.provider.cursor, [20, 14])
        self.assertNotEqual(self.provider.cursor, self.case["target"])
        self.assertTrue(self.provider.complete())

    def test_native_obstacles_remove_illegal_direction_and_pattern(self):
        case = load_cases("held_out")[0]
        provider = VectorProvider(case)
        native = SyntheticVectorNative(case).reset()["observation"]
        choices = provider.candidates(native, observed(native, provider))
        self.assertNotIn("INTENT_LEFT_6", {c["id"] for c in choices})
        self.assertNotIn("INTENT_LEFT_10", {c["id"] for c in choices})
        case = load_cases("held_out")[1]
        provider = VectorProvider(case)
        native = SyntheticVectorNative(case).reset()["observation"]
        choices = provider.candidates(native, observed(native, provider))
        provider.accept(next(c for c in choices if c["id"] == "INTENT_DOWN_10"))
        tools = provider.candidates(native, observed(native, provider, 1))
        self.assertNotIn("BOUNDED_SERPENTINE", {c["id"] for c in tools})
        self.assertIn("HILBERT_MOTIF", {c["id"] for c in tools})
        self.assertTrue(all(permitted(native, *p) for t in tools for op in t["operations"] for p in op["points"]))

    def test_focus_protected_cells_and_all_blocked_stop(self):
        self.assertEqual(self.state["materials"][40*96+40], 0)
        self.provider.cursor = [39, 40]
        self.provider.history = [[39, 40]]
        _, choices = self.offers()
        self.assertNotIn("INTENT_RIGHT_6", {c["id"] for c in choices})
        self.provider.cursor = [1, 1]
        self.provider.history = [[1, 1]]
        _, choices = self.offers()
        self.assertNotIn("INTENT_LEFT_6", {c["id"] for c in choices})
        self.assertNotIn("INTENT_UP_6", {c["id"] for c in choices})
        for x, y in ((0, 1), (2, 1), (1, 0), (1, 2)):
            self.state["materials"][y*96+x] = 28
        _, choices = self.offers()
        self.assertEqual([c["id"] for c in choices], ["STOP"])

    def test_forged_or_replayed_action_refused(self):
        _, choices = self.offers()
        action = next(c for c in choices if c["id"] == "INTENT_RIGHT_6")
        forged = deepcopy(action)
        forged["predicted"]["endpoint"] = [70, 70]
        with self.assertRaises(Refusal):
            self.provider.accept(forged)
        self.provider.accept(action)
        with self.assertRaises(Refusal):
            self.provider.accept(action)
        _, tools = self.offers(1)
        with self.assertRaises(Refusal):
            self.provider.accept(next(c for c in tools if c["id"] == "STOP"))

    def test_option_reversal_changes_only_order_and_random_is_order_independent(self):
        obs, choices = self.offers()
        reverse = VectorProvider(self.case, reverse_order=True)
        reversed_choices = reverse.candidates(self.state, observed(self.state, reverse))
        self.assertEqual(choices, list(reversed(reversed_choices)))
        left = VectorRandomBaseline(570, include_stop=True)
        right = VectorRandomBaseline(570, include_stop=True)
        a = left.decide(obs, choices, timeout_seconds=1, cancel_event=threading.Event())
        b = right.decide(obs, reversed_choices, timeout_seconds=1, cancel_event=threading.Event())
        self.assertEqual(a["candidate_id"], b["candidate_id"])
        validate_decision(a, obs, choices)
        self.assertTrue(a["raw"]["include_stop"])
        self.assertNotEqual(a["candidate_set_sha256"], b["candidate_set_sha256"])

    def test_geometry_selector_uses_visible_metrics_and_stable_least_travel_ties(self):
        _, choices = self.offers()
        baseline = VectorGeometryPreferenceBaseline()
        self.assertEqual(baseline.choose(choices), "INTENT_RIGHT_6")
        self.provider.accept(next(c for c in choices if c["id"] == "INTENT_RIGHT_6"))
        _, tools = self.offers(1)
        self.assertEqual(baseline.choose(tools), "STRAIGHT")
        # Renaming IDs and adjusting visible preferences checks that the selector
        # uses finite candidate geometry, without an evaluator case/answer key.
        synthetic = deepcopy(tools)
        for index, tool in enumerate(synthetic):
            if tool["kind"] == "tool":
                tool["id"] = f"CHOICE_{index}"
                tool["predicted"]["preference"]["minimum_coverage"] = 0
                tool["predicted"]["preference"]["maximum_travel_ratio"] = 3
        self.assertEqual(baseline.choose(synthetic), "CHOICE_0")
        synthetic[0]["predicted"]["metrics"]["travelled_length"] = 18
        self.assertEqual(baseline.choose(synthetic), "CHOICE_3")
        synthetic[3]["predicted"]["metrics"]["travelled_length"] = 18
        self.assertEqual(baseline.choose(synthetic), "CHOICE_0")
        self.assertEqual(baseline.choose(list(reversed(synthetic))), "CHOICE_0")
        for tool in synthetic:
            if tool["kind"] == "tool":
                tool["predicted"]["preference"]["minimum_coverage"] = 31
        self.assertEqual(baseline.choose(synthetic), "STOP")


class VectorEpisodeScoringTests(unittest.TestCase):
    def run_case(self, case, policy):
        native = SyntheticVectorNative(case)
        with tempfile.TemporaryDirectory() as folder:
            record = EpisodeController(max_decisions=2, max_changed_cells=40, max_wall_seconds=5).run(
                native=native, provider=VectorProvider(case), policy=policy, episode_id="vector-unit",
                output=Path(folder)/"episode")
        return native, record

    def test_synthetic_controller_has_two_requests_one_native_tool_and_consistent_mask(self):
        case = load_cases()[0]
        policy = SequencePolicy("INTENT_RIGHT_6", "STRAIGHT")
        native, record = self.run_case(case, policy)
        self.assertEqual(record["terminal_status"], "success")
        self.assertEqual(record["decisions"], 2)
        self.assertEqual(record["native_actions"], 1)
        self.assertEqual(record["actual_changed_cells"], 6)
        self.assertEqual(native.writes, 1)
        self.assertEqual(len(policy.seen), 2)
        self.assertEqual(policy.seen[0][0]["cursor"], policy.seen[1][0]["cursor"])
        self.assertNotEqual(policy.seen[0][0]["subgoal"], policy.seen[1][0]["subgoal"])
        validate_episode(record)
        score = score_episode(case, record)
        self.assertTrue(score["task_success"])
        self.assertTrue(score["planning_transition_only"])
        self.assertTrue(score["native_materials_match"])
        self.assertEqual(score["expected_changed_cells"], 6)
        self.assertEqual(score["observed_changed_cells"], 6)

    def test_held_out_preference_solutions_use_actual_material_coverage(self):
        expected = (("INTENT_RIGHT_10", "BOUNDED_SERPENTINE", 12),
                    ("INTENT_DOWN_10", "HILBERT_MOTIF", 31),
                    ("INTENT_UP_6", "SEEDED_BRIDGE", 13))
        for case, (intent, algorithm, coverage) in zip(load_cases("held_out"), expected):
            with self.subTest(case=case["id"]):
                _, record = self.run_case(case, SequencePolicy(intent, algorithm))
                validate_episode(record)
                score = score_episode(case, record)
                self.assertTrue(score["task_success"], score)
                self.assertEqual(score["coverage_cells"], coverage)
                self.assertEqual(score["endpoint_error"], 0)

    def test_straight_baseline_reaches_target_but_misses_held_out_coverage(self):
        for case in load_cases("held_out"):
            _, record = self.run_case(case, VectorGeometricBaseline())
            score = score_episode(case, record)
            self.assertTrue(score["intent_optimal"])
            self.assertTrue(score["target_reached"])
            self.assertTrue(score["path_invariants_pass"])
            self.assertTrue(score["native_materials_match"])
            self.assertEqual(score["selected_algorithm"], "STRAIGHT")
            self.assertFalse(score["preference_met"])
            self.assertFalse(score["task_success"])

    def test_geometry_preference_baseline_solves_finite_choices_without_case_access(self):
        expected = ("BOUNDED_SERPENTINE", "HILBERT_MOTIF", "SEEDED_BRIDGE")
        for case, algorithm in zip(load_cases("held_out"), expected):
            with self.subTest(case=case["id"]):
                _, record = self.run_case(case, VectorGeometryPreferenceBaseline())
                validate_episode(record)
                score = score_episode(case, record)
                self.assertTrue(score["task_success"], score)
                self.assertEqual(score["selected_algorithm"], algorithm)
                self.assertEqual(record["steps"][1]["decision"]["raw"]["selector"], "ordinary_code_visible_finite_geometry")
                self.assertEqual(record["steps"][1]["decision"]["model_identity"]["kind"], "deterministic_non_model_baseline")

    def test_poor_intent_remains_visible_as_quality_failure_with_valid_native_path(self):
        case = load_cases()[0]
        _, record = self.run_case(case, SequencePolicy("INTENT_UP_6", "STRAIGHT"))
        score = score_episode(case, record)
        self.assertEqual(record["final_cursor"], [20, 14])
        self.assertFalse(score["intent_optimal"])
        self.assertEqual(score["intent_target_error"], 12)
        self.assertTrue(score["path_invariants_pass"])
        self.assertTrue(score["native_materials_match"])
        self.assertFalse(score["task_success"])

    def test_stop_before_or_after_intent_has_no_paint_and_no_quality_success(self):
        case = load_cases()[0]
        for policy in (SequencePolicy("STOP"), SequencePolicy("INTENT_RIGHT_6", "STOP")):
            native, record = self.run_case(case, policy)
            self.assertEqual(record["terminal_status"], "stop")
            self.assertEqual(record["actual_changed_cells"], 0)
            self.assertEqual(native.writes, 0)
            score = score_episode(case, record)
            self.assertFalse(score["task_success"])
            self.assertFalse(score["path_applied"])
            self.assertTrue(score["failures"])

    def test_scoring_rejects_missing_material_and_forged_path_evidence(self):
        case = load_cases()[0]
        _, record = self.run_case(case, SequencePolicy("INTENT_RIGHT_6", "STRAIGHT"))
        bad = deepcopy(record)
        bad["steps"][1]["native_response"]["observation"]["materials"][20*96+24] = 0
        self.assertFalse(score_episode(case, bad)["native_materials_match"])
        bad = deepcopy(record)
        bad["steps"][1]["selected_action"]["predicted"]["path"][1] = [26, 26]
        self.assertFalse(score_episode(case, bad)["path_invariants_pass"])
        self.assertFalse(score_episode(case, bad)["task_success"])


if __name__ == "__main__":
    unittest.main()
