"""Synthetic unit fixtures verify refusal paths; they are never inference proof."""
from copy import deepcopy
from pathlib import Path
import tempfile
import threading
import time
import unittest

from experiments.driv3r.contracts import Refusal, digest, validate_candidates, validate_decision, validate_observation
from experiments.driv3r.controller import EpisodeController, GeometricBaseline, decision_record, validate_episode
from experiments.driv3r.providers import DirectProvider, FuzzyProvider, observation


class SyntheticNative:
    """Explicitly synthetic unit-test double, no native qualification claim."""
    def __init__(self):
        self.writes = 0
        self.stops = 0

    def reset(self, fixture="wall-v1", **_):
        cells = [0]*9216
        for y in range(8, 65):
            cells[y*96+8] = 28
        self.state = {"world_id": "synthetic-unit-world", "generation": 1, "revision": 1, "tick": 0,
                      "width": 96, "height": 96, "focus": [0, 0, 96, 96], "allowed_materials": [58],
                      "protected_rectangles": [[40, 40, 8, 8]], "materials": cells, "retired": False}
        return self.observe()

    def observe(self, **_):
        self.state["material_sha256"] = digest(self.state["materials"])
        self.state["world_material_sha256"] = digest(self.state["materials"])
        return {"status": "completed", "observation": deepcopy(self.state)}

    def apply(self, operations, **_):
        self.writes += 1
        changed = 0
        for op in operations:
            for y in range(op["y0"], op["y1"]+1):
                for x in range(op["x0"], op["x1"]+1):
                    changed += self.state["materials"][y*96+x] != op["material"]
                    self.state["materials"][y*96+x] = op["material"]
        self.state["revision"] += 1
        return {**self.observe(), "receipt": {"actual_changed_cells": changed,
                "expected_changed_cells": changed, "readback_matches": True}}

    def stop(self, reason):
        self.stops += 1
        self.state["retired"] = True
        return {**self.observe(), "status": "stopped", "reason": reason}


class TestPolicy:
    name = "synthetic-unit-policy"
    def __init__(self, choice="DOWN", mutate=None, status="ok"):
        self.choice, self.mutate, self.status = choice, mutate, status

    def decide(self, obs, candidates, **_):
        answer = decision_record(obs, candidates, choice=self.choice,
                                probabilities={c["id"]: float(c["id"] == self.choice) for c in candidates},
                                confidence=1.0, model_identity={"kind": "synthetic_unit_fixture"},
                                backend_identity={"kind": "synthetic_unit_fixture"}, raw={"synthetic": True},
                                status=self.status, error=None if self.status == "ok" else self.status)
        if self.mutate:
            self.mutate(answer)
        return answer


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.native = SyntheticNative()
        state = self.native.reset()["observation"]
        self.provider = DirectProvider()
        self.obs = observation(state, self.provider, episode_id="unit", step=0, decisions_remaining=8,
                               changed_cells_remaining=100, wall_seconds_remaining=30)
        self.candidates = self.provider.candidates(state, self.obs)
        self.answer = TestPolicy().decide(self.obs, self.candidates)

    def test_valid_observation_and_four_cardinal_choices_plus_stop(self):
        validate_observation(self.obs)
        self.assertEqual({c["id"] for c in self.candidates}, {"UP", "DOWN", "LEFT", "RIGHT", "STOP"})

    def test_distribution_resolves_id_after_order_perturbation(self):
        reverse = list(reversed(self.candidates))
        answer = TestPolicy().decide(self.obs, reverse)
        self.assertEqual(validate_decision(answer, self.obs, reverse)["id"], "DOWN")
        with self.assertRaises(Refusal):
            validate_decision(answer, self.obs, self.candidates)

    def test_changed_state_hash_refused(self):
        self.obs["cursor"] = [13, 24]
        with self.assertRaises(Refusal):
            validate_decision(self.answer, self.obs, self.candidates)

    def test_unknown_id_missing_probability_nan_wrong_argmax_refused(self):
        for field, value in (("candidate_id", "DELETE_WORLD"), ("probabilities", {"DOWN": 1.0}),
                             ("confidence", float("nan")), ("candidate_id", "UP")):
            answer = deepcopy(self.answer)
            answer[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(Refusal):
                validate_decision(answer, self.obs, self.candidates)

    def test_extra_executable_decision_field_refused(self):
        self.answer["operations"] = []
        with self.assertRaises(Refusal):
            validate_decision(self.answer, self.obs, self.candidates)

    def test_stop_cannot_smuggle_mutation(self):
        self.candidates[-1]["operations"] = self.candidates[0]["operations"]
        with self.assertRaises(Refusal):
            validate_candidates(self.candidates, self.obs)

    def test_movement_cannot_teleport_or_paint_another_point(self):
        for mutation in (lambda c: c.update(destination=[12, 31]), lambda c: c["operations"][0].update(x0=11)):
            candidates = deepcopy(self.candidates)
            mutation(candidates[0])
            with self.assertRaises(Refusal):
                validate_candidates(candidates, self.obs)

    def test_invalid_boolean_coordinates_material_and_extra_parameters(self):
        for field, value in (("x0", True), ("material", 0), ("x1", 1000), ("permission_override", True)):
            candidates = deepcopy(self.candidates)
            candidates[0]["operations"][0][field] = value
            with self.subTest(field=field), self.assertRaises(Refusal):
                validate_candidates(candidates, self.obs)

    def test_observation_rejects_unbounded_dump(self):
        self.obs["local"]["width"] = 96
        self.obs["local"]["materials"] = [0]*9216
        with self.assertRaises(Refusal):
            validate_observation(self.obs)

    def test_protected_wall_cannot_be_candidate(self):
        self.provider.cursor = [9, 24]
        state = self.native.observe()["observation"]
        obs = observation(state, self.provider, episode_id="unit", step=0, decisions_remaining=8,
                          changed_cells_remaining=100, wall_seconds_remaining=30)
        self.assertNotIn("LEFT", [c["id"] for c in self.provider.candidates(state, obs)])

    def test_fuzzy_profiles_use_unchanged_shared_compiler(self):
        provider = FuzzyProvider()
        state = self.native.observe()["observation"]
        choices = []
        for step in range(3):
            obs = observation(state, provider, episode_id="fuzzy", step=step, decisions_remaining=3-step,
                              changed_cells_remaining=1024, wall_seconds_remaining=30)
            candidates = provider.candidates(state, obs)
            action = candidates[0]
            self.assertEqual(len(action["operations"]), 1)
            self.assertEqual(len(action["predicted"]["compiler_sha256"]), 64)
            choices.append(action["id"])
            provider.accept(action)
        self.assertTrue(provider.complete())
        self.assertEqual(choices, ["ADD_PLATFORM_THIN", "EXTEND_SHORT", "SUPPORT_THIN"])


class EpisodeTests(unittest.TestCase):
    def execute(self, policy, *, provider=None, native=None, **kwargs):
        native = native or SyntheticNative()
        with tempfile.TemporaryDirectory() as tmp:
            result = EpisodeController(**kwargs).run(native=native, provider=provider or DirectProvider(),
                        policy=policy, episode_id="unit", output=Path(tmp)/"episode")
        return result, native

    def test_deterministic_baseline_native_ordering_and_record_chain(self):
        result, native = self.execute(GeometricBaseline())
        self.assertEqual(result["terminal_status"], "success")
        self.assertEqual((native.writes, native.stops, result["actual_changed_cells"]), (6, 1, 6))
        self.assertTrue(validate_episode(result)["passed"])
        self.assertEqual([s["selected_action"]["id"] for s in result["steps"]], ["DOWN"]*6)

    def test_invalid_candidate_cannot_mutate(self):
        result, native = self.execute(TestPolicy("UNKNOWN"))
        self.assertEqual(result["terminal_status"], "invalid_decision")
        self.assertEqual(native.writes, 0)

    def test_explicit_stop_has_zero_writes(self):
        result, native = self.execute(TestPolicy("STOP"))
        self.assertEqual(result["terminal_status"], "stop")
        self.assertEqual(native.writes, 0)

    def test_only_legal_stop_does_not_make_invalid_single_option_model_call(self):
        class Trapped(DirectProvider):
            def candidates(self, state, obs):
                return [c for c in super().candidates(state, obs) if c["kind"] == "stop"]
        class MustNotCall:
            name = "uncalled-unit-control"
            def decide(self, *_, **__):
                raise AssertionError("There is no decision when STOP is the only legal action")
        result, native = self.execute(MustNotCall(), provider=Trapped())
        self.assertEqual(result["terminal_status"], "stop")
        self.assertEqual(result["decisions"], 0)
        self.assertEqual(native.writes, 0)
        self.assertTrue(validate_episode(result)["passed"])

    def test_model_timeout_is_failure_not_stop(self):
        result, native = self.execute(TestPolicy(status="timeout"))
        self.assertEqual(result["terminal_status"], "model_failure")
        self.assertEqual(native.writes, 0)

    def test_stale_revision_after_decision_cannot_mutate(self):
        native = SyntheticNative()
        policy = TestPolicy(mutate=lambda _: native.state.update(revision=native.state["revision"]+1))
        result, native = self.execute(policy, native=native)
        self.assertEqual(result["terminal_status"], "native_refusal")
        self.assertEqual(native.writes, 0)

    def test_late_valid_answer_after_cancellation_cannot_mutate(self):
        event = threading.Event()
        with tempfile.TemporaryDirectory() as tmp:
            native = SyntheticNative()
            result = EpisodeController().run(native=native, provider=DirectProvider(),
                policy=TestPolicy(mutate=lambda _: event.set()), episode_id="cancel", output=Path(tmp)/"episode", cancel_event=event)
        self.assertEqual(result["terminal_status"], "cancelled")
        self.assertEqual(native.writes, 0)

    def test_cancellation_during_admission_refresh_cannot_mutate(self):
        event = threading.Event()
        class CancelDuringRefresh(SyntheticNative):
            observations = 0
            def observe(self, **kwargs):
                self.observations += 1
                if self.observations == 3:
                    event.set()
                return super().observe(**kwargs)
        with tempfile.TemporaryDirectory() as tmp:
            native = CancelDuringRefresh()
            result = EpisodeController().run(native=native, provider=DirectProvider(), policy=TestPolicy(),
                episode_id="refresh-cancel", output=Path(tmp)/"episode", cancel_event=event)
        self.assertEqual(result["terminal_status"], "cancelled")
        self.assertEqual(native.writes, 0)

    def test_late_answer_after_wall_deadline_cannot_mutate(self):
        result, native = self.execute(TestPolicy(mutate=lambda _: time.sleep(0.01)), max_wall_seconds=0.005)
        self.assertEqual(result["terminal_status"], "budget_exhausted")
        self.assertEqual(native.writes, 0)

    def test_count_budget_preserves_unrepaired_wrong_direction(self):
        result, native = self.execute(TestPolicy("UP"), max_decisions=2)
        self.assertEqual(result["terminal_status"], "budget_exhausted")
        self.assertEqual(result["final_cursor"], [12, 22])
        self.assertEqual(native.writes, 2)

    def test_changed_cell_budget_closes_native_prefix(self):
        result, native = self.execute(TestPolicy("DOWN"), max_changed_cells=1)
        self.assertEqual(result["terminal_status"], "budget_exhausted")
        self.assertEqual((native.writes, result["actual_changed_cells"]), (1, 1))

    def test_skip_advances_graph_without_claiming_paint(self):
        result, native = self.execute(TestPolicy("SKIP"), provider=FuzzyProvider())
        self.assertEqual(result["terminal_status"], "success")
        self.assertEqual(native.writes, 0)
        self.assertEqual(result["actual_changed_cells"], 0)

    def test_tampered_replay_record_refused(self):
        result, _ = self.execute(GeometricBaseline())
        result["steps"][0]["decision"]["candidate_id"] = "UP"
        with self.assertRaises(Refusal):
            validate_episode(result)


if __name__ == "__main__":
    unittest.main()
