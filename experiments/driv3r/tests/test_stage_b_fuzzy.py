"""Synthetic unit checks for frozen fuzzy geometry; no inference/native claim."""
from copy import deepcopy
from pathlib import Path
import tempfile
import unittest

from experiments.agent_painter.compiler import compile_program
from experiments.driv3r.contracts import Refusal, digest, validate_decision, validate_operations
from experiments.driv3r.controller import EpisodeController, decision_record, validate_episode
from experiments.driv3r.providers import observation
from experiments.driv3r.stage_b.fuzzy import (
    FixedOrderFuzzyBaseline, FuzzyCaseProvider, SeededRandomFuzzyBaseline,
    load_cases, score_episode, validate_case,
)
from experiments.driv3r.tests.test_controller import SyntheticNative


class FuzzyFixtureDouble(SyntheticNative):
    """The existing synthetic receipt double initialized from a frozen catalog."""

    def reset(self, fixture, **_):
        case = next(case for case in load_cases() if case["fixture"]["id"] == fixture)
        super().reset()
        self.state["materials"] = [0]*(96*96)
        for x, y, width, height, material in case["fixture"]["edits"]:
            for py in range(y, y+height):
                for px in range(x, x+width):
                    self.state["materials"][py*96+px] = material
        self.state["fixture"] = fixture
        return self.observe()


class SyntheticChoice:
    name = "synthetic-fuzzy-unit-choice"

    def __init__(self, choice):
        self.choice = choice

    def decide(self, obs, candidates, **_):
        return decision_record(obs, candidates, choice=self.choice, confidence=1.0,
                               probabilities={c["id"]: float(c["id"] == self.choice) for c in candidates},
                               model_identity={"kind": "synthetic_unit_fixture"},
                               backend_identity={"kind": "synthetic_unit_fixture"}, raw={"synthetic": True})


class FuzzyCaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = load_cases()

    def view(self, case, *, reverse_order=False, paraphrase=False):
        native = FuzzyFixtureDouble()
        state = native.reset(case["fixture"]["id"])["observation"]
        provider = FuzzyCaseProvider(case, reverse_order=reverse_order, paraphrase=paraphrase)
        obs = observation(state, provider, episode_id="synthetic-fuzzy-unit", step=0,
                          decisions_remaining=1, changed_cells_remaining=256, wall_seconds_remaining=30)
        return native, provider, obs, provider.candidates(state, obs)

    def execute(self, case, choice):
        native = FuzzyFixtureDouble()
        with tempfile.TemporaryDirectory() as tmp:
            record = EpisodeController(max_decisions=1, max_changed_cells=256, max_wall_seconds=30).run(
                native=native, provider=FuzzyCaseProvider(case), policy=SyntheticChoice(choice),
                episode_id="synthetic-fuzzy-unit", output=Path(tmp)/"episode")
        self.assertTrue(validate_episode(record)["passed"])
        return record, score_episode(case, record)

    def test_catalog_is_bounded_split_frozen_and_defensively_copied(self):
        self.assertEqual(len(self.cases), 6)
        self.assertEqual(len(load_cases("development")), 2)
        self.assertEqual(len(load_cases("held_out")), 4)
        self.assertEqual(len({case["id"] for case in self.cases}), 6)
        for case in self.cases:
            self.assertTrue(case["id"].startswith("b-fuzzy-"))
            self.assertEqual(case["id"], case["fixture"]["id"])
            self.assertEqual(len(case["candidates"]), 3)
        changed = load_cases()
        changed[0]["candidates"][0]["program"]["variation"] = 2
        self.assertEqual(load_cases()[0]["candidates"][0]["program"]["variation"], 0)
        with self.assertRaises(Refusal):
            load_cases("development_plus_selected_heldout")

    def test_all_alternatives_are_legal_distinct_shared_compiler_geometry(self):
        for case in self.cases:
            _, _, obs, choices = self.view(case)
            tools = [c for c in choices if c["kind"] == "tool"]
            self.assertEqual(len(tools), 3)
            self.assertEqual({c["id"] for c in choices}, {"TOOL_A", "TOOL_B", "TOOL_C", "SKIP", "STOP"})
            masks = []
            for tool in tools:
                compiled = compile_program(tool["predicted"]["program"], seed=570,
                                           focus=(0, 0, 96, 96), material=58, allowed_materials=(58,),
                                           max_operations=16, max_cell_work=1024)
                self.assertEqual(tool["operations"], compiled["operations"])
                cells = validate_operations(tool["operations"], obs["permissions"]["focus"], 58)
                self.assertFalse(any(40 <= x < 48 and 40 <= y < 48 for x, y in cells))
                self.assertLessEqual(len(cells), 1024)
                masks.append(cells)
            self.assertEqual(len({digest(sorted(mask)) for mask in masks}), 3)

    def test_actual_expected_geometry_distinguishes_every_case_and_bad_choices(self):
        winners = ["TOOL_B", "TOOL_A", "TOOL_C", "TOOL_B", "TOOL_A", "TOOL_C"]
        for case, winner in zip(self.cases, winners, strict=True):
            results = {}
            for choice in ("TOOL_A", "TOOL_B", "TOOL_C"):
                with self.subTest(case=case["id"], choice=choice):
                    record, score = self.execute(case, choice)
                    self.assertTrue(record["task_complete"])
                    self.assertEqual(record["completion_kind"], "graph_terminal_only")
                    self.assertTrue(score["fixture_matches"])
                    self.assertTrue(score["native_receipts_consistent"])
                    self.assertEqual(score["protected_changed_cells"], 0)
                    self.assertEqual(score["task_success"], choice == winner)
                    self.assertEqual(record["native_actions"], 1)
                    self.assertEqual(record["decisions"], 1)
                    results[choice] = score["quality_score"]
            self.assertEqual(results[winner], 1.0)
            self.assertTrue(all(value < 1.0 for cid, value in results.items() if cid != winner))
            self.assertGreater(len(set(results.values())), 1)

    def test_skip_and_stop_never_satisfy_unpainted_geometry(self):
        for case in self.cases:
            for choice in ("SKIP", "STOP"):
                record, score = self.execute(case, choice)
                self.assertFalse(score["task_success"])
                self.assertEqual(score["quality_score"], 0.0)
                self.assertEqual(record["actual_changed_cells"], 0)
                self.assertEqual(record["native_actions"], 0)
                self.assertEqual(record["task_complete"], choice == "SKIP")

    def test_coverage_separates_target_coverage_spill_and_legitimate_overdraw(self):
        case = next(c for c in self.cases if c["id"] == "b-fuzzy-held-coverage")
        _, shifted = self.execute(case, "TOOL_B")
        self.assertEqual(shifted["target_coverage"], 0.75)
        self.assertEqual(shifted["actual_changed_cells"], 24)
        self.assertEqual(shifted["acknowledged_full_action_overdraw_visits"], 8)
        self.assertEqual(shifted["spill_cells"], 0)
        _, thick = self.execute(case, "TOOL_C")
        self.assertEqual(thick["target_coverage"], 1.0)
        self.assertEqual(thick["spill_cells"], 32)
        self.assertEqual(thick["quality_score"], 0.5)
        dogleg = next(c for c in self.cases if c["id"] == "b-fuzzy-held-dogleg")
        _, joined = self.execute(dogleg, "TOOL_C")
        self.assertTrue(joined["task_success"])
        self.assertEqual(joined["actual_changed_cells"], 56)
        self.assertEqual(joined["acknowledged_full_action_overdraw_visits"], 8)

    def test_support_checks_continuous_marked_columns_not_any_roof_base_connection(self):
        case = next(c for c in self.cases if c["id"] == "b-fuzzy-dev-support")
        _, displaced = self.execute(case, "TOOL_C")
        self.assertTrue(all(not s["supported"] for s in displaced["supports"]))
        self.assertEqual(displaced["target_coverage"], 0.0)
        self.assertEqual(displaced["spill_cells"], 24)
        _, short = self.execute(case, "TOOL_B")
        self.assertTrue(all(not s["supported"] for s in short["supports"]))
        self.assertGreater(short["target_coverage"], 0.0)
        self.assertLess(short["target_coverage"], 1.0)

    def test_model_effects_contain_geometry_without_evaluation_or_correctness_labels(self):
        allowed = {"program", "program_sha256", "compiler_sha256", "operations_sha256",
                   "proposed_boxes", "cell_visits"}
        for case in self.cases:
            _, _, _, choices = self.view(case)
            for action in choices:
                if action["kind"] == "tool":
                    self.assertEqual(set(action["predicted"]), allowed)
                    self.assertNotIn("evaluation", action["predicted"])
                    self.assertNotIn("success", action["label"].lower())
                    self.assertNotIn("correct", action["label"].lower())

    def test_order_and_paraphrase_change_only_the_requested_presentation(self):
        for case in self.cases:
            _, _, obs, choices = self.view(case)
            _, _, reversed_obs, reversed_choices = self.view(case, reverse_order=True)
            self.assertEqual(choices, list(reversed(reversed_choices)))
            self.assertEqual(obs, reversed_obs)
            _, _, paraphrased_obs, paraphrased_choices = self.view(case, paraphrase=True)
            self.assertNotEqual(obs["objective"], paraphrased_obs["objective"])
            paraphrased_obs["objective"] = obs["objective"]
            self.assertEqual(obs, paraphrased_obs)
            self.assertEqual(choices, paraphrased_choices)

    def test_new_native_obstacle_removes_illegal_tool_before_model_choice(self):
        native, provider, obs, choices = self.view(self.cases[0])
        target = next(c for c in choices if c["id"] == "TOOL_A")
        op = target["operations"][0]
        native.state["materials"][op["y0"]*96+op["x0"]] = 28
        state = native.observe()["observation"]
        obs = observation(state, provider, episode_id="synthetic-fuzzy-unit", step=0,
                          decisions_remaining=1, changed_cells_remaining=256, wall_seconds_remaining=30)
        offered = provider.candidates(state, obs)
        self.assertNotIn("TOOL_A", [c["id"] for c in offered])
        self.assertIn("STOP", [c["id"] for c in offered])

    def test_provider_accepts_only_current_issued_action_once(self):
        _, provider, _, choices = self.view(self.cases[0])
        action = deepcopy(choices[0])
        action["operations"][0]["x1"] += 1
        with self.assertRaises(Refusal):
            provider.accept(action)
        provider.accept(choices[0])
        self.assertTrue(provider.complete())
        with self.assertRaises(Refusal):
            provider.accept(choices[0])

    def test_malformed_catalog_protection_material_and_duplicate_geometry_refused(self):
        for mutation in (
            lambda c: c["fixture"]["edits"][0].__setitem__(4, True),
            lambda c: c["candidates"][0]["program"]["components"][0].update(box=[40,40,8,2]),
            lambda c: c["candidates"][1].update(program=deepcopy(c["candidates"][0]["program"])),
            lambda c: c.update(id="shared-painter-owned-fixture"),
        ):
            case = deepcopy(self.cases[0])
            mutation(case)
            with self.assertRaises(Refusal):
                validate_case(case)

    def test_receipt_or_fixture_forgery_cannot_pass_geometry_gate(self):
        case = self.cases[0]
        record, score = self.execute(case, "TOOL_B")
        self.assertTrue(score["task_success"])
        bad = deepcopy(record)
        bad["steps"][0]["native_response"]["receipt"]["actual_changed_cells"] = 0
        result = score_episode(case, bad)
        self.assertTrue(result["geometry_success"])
        self.assertFalse(result["task_success"])
        self.assertFalse(result["native_receipts_consistent"])
        self.assertEqual(result["quality_score"], 0.0)
        bad = deepcopy(record)
        bad["initial_native"]["materials"][0] = 58
        self.assertFalse(score_episode(case, bad)["fixture_matches"])
        self.assertFalse(score_episode(case, bad)["task_success"])

    def test_missing_or_malformed_native_readback_is_not_evaluable(self):
        for record in ({}, {"initial_native": None, "final_native": None}):
            score = score_episode(self.cases[0], record)
            self.assertFalse(score["evaluable"])
            self.assertFalse(score["task_success"])
            self.assertEqual(score["quality_score"], 0.0)

    def test_protected_changes_cannot_earn_geometry_quality(self):
        case = self.cases[0]
        record, _ = self.execute(case, "TOOL_B")
        index = 40*96+40
        record["final_native"]["materials"][index] = 58
        record["steps"][0]["native_response"]["observation"]["materials"][index] = 58
        record["steps"][0]["native_response"]["receipt"]["actual_changed_cells"] += 1
        record["actual_changed_cells"] += 1
        result = score_episode(case, record)
        self.assertTrue(result["native_receipts_consistent"])
        self.assertEqual(result["protected_changed_cells"], 1)
        self.assertFalse(result["task_success"])
        self.assertEqual(result["quality_score"], 0.0)

    def test_selected_id_or_graph_terminal_cannot_override_actual_material_failure(self):
        case = self.cases[0]
        record, score = self.execute(case, "TOOL_A")
        self.assertTrue(record["task_complete"])
        self.assertFalse(score["task_success"])
        record["steps"][0]["selected_action"]["id"] = "TOOL_B"
        record["task_complete"] = True
        self.assertFalse(score_episode(case, record)["task_success"])

    def test_non_model_baselines_are_explicit_and_seed_is_order_independent(self):
        _, _, obs, choices = self.view(self.cases[0])
        fixed = FixedOrderFuzzyBaseline()
        forward = fixed.decide(obs, choices)
        reverse = fixed.decide(obs, list(reversed(choices)))
        self.assertEqual(validate_decision(forward, obs, choices)["id"], "TOOL_A")
        self.assertEqual(validate_decision(reverse, obs, list(reversed(choices)))["id"], "TOOL_C")
        sampled = set()
        for seed in range(30):
            first = SeededRandomFuzzyBaseline(seed).decide(obs, choices)
            other = SeededRandomFuzzyBaseline(seed).decide(obs, list(reversed(choices)))
            self.assertEqual(first["candidate_id"], other["candidate_id"])
            self.assertEqual(first["raw"]["sampling_probability"], 0.2)
            self.assertEqual(first["model_identity"]["kind"], "non_model_seeded_random_legal_baseline")
            sampled.add(validate_decision(first, obs, choices)["id"])
        self.assertEqual(sampled, {"TOOL_A", "TOOL_B", "TOOL_C", "SKIP", "STOP"})


if __name__ == "__main__":
    unittest.main()
