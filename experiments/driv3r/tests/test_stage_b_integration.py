"""Focused synthetic integration regressions; no model or native qualification."""
from copy import deepcopy
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.contracts import Refusal, canonical, digest, operation_visits, validate_operations
from experiments.driv3r.controller import EpisodeController, validate_episode
from experiments.driv3r.providers import candidate, observation
from experiments.driv3r.stage_b.catalog import catalogs
from experiments.driv3r.stage_b.direct import DirectCaseProvider, load_cases as direct_cases
from experiments.driv3r.stage_b.fuzzy import FuzzyCaseProvider, load_cases as fuzzy_cases
from experiments.driv3r.stage_b.representation import (
    SemanticPolicy, decode, encode, request, request_for_policy, semantic_view,
)
from experiments.driv3r.stage_b.qualify import CampaignDeadline, episode_result, frozen_protocol, measure_probes
from experiments.driv3r.stage_b.vector import VectorProvider, load_cases as vector_cases
from experiments.driv3r.tests.test_controller import SyntheticNative, TestPolicy

ROOT = Path(__file__).resolve().parents[3]


class CatalogNativeDouble(SyntheticNative):
    """Existing synthetic double using exactly the shared catalog reset edits."""

    def reset(self, fixture, **_):
        edits, _ = catalogs(ROOT)
        if fixture not in edits:
            raise Refusal("Unknown synthetic catalog fixture")
        super().reset()
        self.state["materials"] = [0]*9216
        self.state["fixture"] = fixture
        self.last_cell_budget = None
        for x, y, width, height, material in edits[fixture]:
            for cy in range(y, y+height):
                for cx in range(x, x+width):
                    self.state["materials"][cy*96+cx] = material
        return self.observe()

    def apply(self, operations, **kwargs):
        self.last_cell_budget = kwargs["cell_budget"]
        if all(op["shape"] == "rectangle" for op in operations):
            return super().apply(operations, **kwargs)
        self.writes += 1
        changed = 0
        for op in operations:
            if op["shape"] != "pixels":
                raise Refusal("Mixed synthetic shapes are outside this test")
            for x, y in op["points"]:
                changed += self.state["materials"][y*96+x] != 58
                self.state["materials"][y*96+x] = 58
        self.state["revision"] += 1
        return {**self.observe(), "receipt": {"actual_changed_cells": changed,
                "expected_changed_cells": changed, "readback_matches": True}}


class SyntheticTypedBackend:
    """Typed parser fixture, explicitly not a real inference backend."""

    def decide(self, state, questions, **_):
        ids = list(questions["next_action"]["criteria"])
        choice = next((cid for cid in ids if cid.startswith("TOOL_")), ids[0])
        return {
            "status": "ok", "error": None, "latency_seconds": 0.0,
            "request": {"state": state, "questions": deepcopy(questions)},
            "model_identity": {"kind": "synthetic_unit_fixture"},
            "backend_identity": {"kind": "synthetic_unit_fixture"},
            "raw_response": {"answers": {"next_action": {
                "type": "choice", "choice": choice, "confidence": 1.0,
                "probabilities": {cid: float(cid == choice) for cid in ids}}},
                "usage": {"input_tokens": 1, "output_tokens": 0}},
        }


def rehash(record):
    previous = None
    for step in record["steps"]:
        step["previous_record_sha256"] = previous
        step.pop("record_sha256", None)
        step["record_sha256"] = digest(step)
        previous = step["record_sha256"]


class StageBIntegrationTests(unittest.TestCase):
    def view(self, provider, *, step=0, state=None):
        if state is None:
            state = CatalogNativeDouble().reset(provider.fixture)["observation"]
        obs = observation(state, provider, episode_id="synthetic-integration", step=step,
                          decisions_remaining=8-step, changed_cells_remaining=256,
                          wall_seconds_remaining=60)
        return state, obs, provider.candidates(state, obs)

    def model_record(self):
        native = CatalogNativeDouble()
        with tempfile.TemporaryDirectory() as tmp:
            record = EpisodeController(max_decisions=1).run(
                native=native, provider=FuzzyCaseProvider(fuzzy_cases()[0]),
                policy=SemanticPolicy(SyntheticTypedBackend()), episode_id="synthetic-integration",
                output=Path(tmp)/"episode")
        self.assertTrue(validate_episode(record)["passed"])
        return record

    def test_shared_catalog_exactly_binds_unique_source_fixture_ids(self):
        fixtures, identities = catalogs(ROOT)
        cases = direct_cases()+fuzzy_cases()+vector_cases()
        self.assertEqual(len(fixtures), len(cases))
        self.assertEqual(len(identities), 3)
        for case in cases:
            self.assertEqual(fixtures[case["fixture"]["id"]], case["fixture"]["edits"])
            state = CatalogNativeDouble().reset(case["fixture"]["id"])["observation"]
            for x, y, width, height, material in case["fixture"]["edits"]:
                for cy in range(y, y+height):
                    for cx in range(x, x+width):
                        self.assertEqual(state["materials"][cy*96+cx], material)
            self.assertEqual(state["materials"][40*96+40], 0)
            self.assertIn([40, 40, 8, 8], state["protected_rectangles"])

    def test_semantic_compaction_roundtrips_every_family_and_vector_phase(self):
        views = []
        for constructor, cases in ((DirectCaseProvider, direct_cases()),
                                   (FuzzyCaseProvider, fuzzy_cases()),
                                   (VectorProvider, vector_cases())):
            for case in cases:
                provider = constructor(case)
                state, obs, choices = self.view(provider)
                views.append((obs, choices))
                if isinstance(provider, VectorProvider):
                    provider.accept(next(c for c in choices if c["kind"] == "skip"))
                    _, next_obs, next_choices = self.view(provider, step=1, state=state)
                    views.append((next_obs, next_choices))
        for obs, choices in views:
            with self.subTest(mode=obs["mode"], subgoal=obs["subgoal"][:60]):
                original_obs, original_choices = deepcopy(obs), deepcopy(choices)
                view = semantic_view(obs, choices)
                self.assertEqual(decode(encode(view)), view)
                compact = json.loads(request("compact", obs, choices)["state"])
                canonical_view = json.loads(request("canonical", obs, choices)["state"])
                self.assertEqual(decode(compact), canonical_view)
                self.assertEqual(obs, original_obs)
                self.assertEqual(choices, original_choices)
                for key in ("local", "history", "permissions", "budgets", "geometry", "cursor", "target"):
                    self.assertEqual(view["observation"][key], obs[key])

    def test_direct_ablation_retains_raw_state_and_task_constraints(self):
        for case in direct_cases():
            _, obs, choices = self.view(DirectCaseProvider(case))
            view = semantic_view(obs, choices, ablate=True)
            self.assertNotIn("geometry", view["observation"])
            for key in ("local", "cursor", "target", "history", "objective", "subgoal", "permissions", "budgets"):
                self.assertEqual(view["observation"][key], obs[key])
            for original, transformed in zip(choices, view["candidate_effects"], strict=True):
                if original["kind"] == "movement":
                    self.assertEqual(transformed["effects"]["destination"], original["destination"])
                    self.assertEqual(transformed["effects"]["clearance_requirement"],
                                     original["predicted"]["clearance_requirement"])
                    for key in ("wall_clearance_cells", "goal_distance", "offset_error", "retrace", "changed_cells"):
                        self.assertNotIn(key, transformed["effects"])

    def test_direct_only_ablation_refuses_fuzzy_and_vector_modes(self):
        for provider in (FuzzyCaseProvider(fuzzy_cases()[0]), VectorProvider(vector_cases()[0])):
            _, obs, choices = self.view(provider)
            with self.assertRaises(Refusal):
                request("without-host-metrics", obs, choices)

    def test_order_probe_reverses_only_candidates_and_criteria_order(self):
        _, obs, choices = self.view(FuzzyCaseProvider(fuzzy_cases()[0]))
        forward = request("compact", obs, choices)
        reverse = request("compact", obs, list(reversed(choices)))
        a, b = decode(json.loads(forward["state"])), decode(json.loads(reverse["state"]))
        self.assertEqual(a["observation"], b["observation"])
        self.assertEqual(a["candidate_effects"], list(reversed(b["candidate_effects"])))
        self.assertEqual(list(forward["questions"]["next_action"]["criteria"]),
                         list(reversed(reverse["questions"]["next_action"]["criteria"])))

    def test_pixel_visits_and_unique_changed_cells_remain_distinct(self):
        operations = [{"shape": "pixels", "material": 58, "points": [[60,12], [60,12], [61,12]]}]
        self.assertEqual(validate_operations(operations, [0,0,96,96], 58), {(60,12), (61,12)})
        self.assertEqual(operation_visits(operations), 3)
        with self.assertRaises(Refusal):
            validate_operations(operations, [0,0,96,96], 58, max_cells=2)

        class PixelProvider(FuzzyCaseProvider):
            def candidates(self, native, observed):
                actions = [candidate("PIXELS", "tool", "Synthetic duplicate pixel visits", deepcopy(operations)),
                           candidate("STOP", "stop", "Stop")]
                self._issued = {action["id"]: digest(action) for action in actions}
                return actions

        native = CatalogNativeDouble()
        with tempfile.TemporaryDirectory() as tmp:
            record = EpisodeController(max_decisions=1, max_changed_cells=2).run(
                native=native, provider=PixelProvider(fuzzy_cases()[0]), policy=TestPolicy("PIXELS"),
                episode_id="synthetic-pixels", output=Path(tmp)/"episode")
        self.assertEqual(native.last_cell_budget, 3)
        self.assertEqual(record["actual_changed_cells"], 2)
        self.assertEqual(record["native_actions"], 1)
        self.assertTrue(validate_episode(record)["passed"])

    def test_pixel_malformed_authority_and_bounds_are_refused(self):
        for op in (
            {"shape":"pixels", "material":58, "points":[[True,12]]},
            {"shape":"pixels", "material":28, "points":[[60,12]]},
            {"shape":"pixels", "material":58, "points":[[96,12]]},
            {"shape":"pixels", "material":58, "points":[]},
            {"shape":"pixels", "material":58, "points":[[60,12]], "override":True},
        ):
            with self.subTest(op=op), self.assertRaises(Refusal):
                validate_operations([op], [0,0,96,96], 58)

    def test_registered_model_request_custody_survives_full_audit_serialization(self):
        record = self.model_record()
        # Production journals serialize canonical JSON, so validate the loaded
        # representation rather than relying on live Python object identities.
        serialized = json.loads(canonical(record))
        self.assertTrue(validate_episode(serialized)["passed"])
        changed = deepcopy(serialized)
        changed["steps"][0]["decision"]["raw"]["request"]["state"] = "invented state"
        rehash(changed)
        with self.assertRaises(Refusal):
            validate_episode(changed)

    def test_unknown_explicit_model_policy_cannot_bypass_original_response_custody(self):
        original = self.model_record()
        for repository in ("LiquidAI/d1-2B-GGUF", "LiquidAI/d1-2B"):
            record = deepcopy(original)
            record["policy"] = "unregistered-model-policy"
            for step in record["steps"]:
                step["decision"]["model_identity"] = {"kind": "model", "repository": repository}
                step["decision"]["raw"] = {"invented": True}
            rehash(record)
            with self.subTest(repository=repository), self.assertRaises(Refusal):
                validate_episode(record)
        with self.assertRaises(Refusal):
            request_for_policy("unregistered-model-policy", original["steps"][0]["observation"],
                               original["steps"][0]["candidates"])

    def test_failure_summary_retains_episode_without_final_native_readback(self):
        record = self.model_record()
        record["terminal_status"] = "native_refusal"
        record["reason"] = "Synthetic failed native Stop transport; no final readback"
        record["final_native"] = None
        entry = {"family": "fuzzy", "case": fuzzy_cases()[0], "policy_label": "model",
                 "record": record, "score": {"task_success": False, "evaluable": False},
                 "episode_path": "synthetic/episode.json", "native_directory": "synthetic-native"}
        row = episode_result(entry)
        self.assertEqual(row["terminal_status"], "native_refusal")
        self.assertEqual(row["reason"], record["reason"])
        self.assertIsNone(row["final_material_sha256"])
        self.assertIsNone(row["final_png_sha256"])

    def test_partial_probe_group_preserves_completed_original_rows(self):
        class InterruptedProbeBackend(SyntheticTypedBackend):
            def __init__(self):
                self.calls = 0

            def decide(self, *args, **kwargs):
                self.calls += 1
                if self.calls == 2:
                    raise CampaignDeadline("Synthetic campaign deadline during second probe")
                return super().decide(*args, **kwargs)

        record = self.model_record()
        entry = {"family": "fuzzy", "case": fuzzy_cases()[0], "record": record}
        retained = []
        with tempfile.TemporaryDirectory() as tmp, redirect_stdout(io.StringIO()):
            with self.assertRaises(CampaignDeadline):
                measure_probes(entry, InterruptedProbeBackend(), Path(tmp), frozen_protocol(), 0, retained)
            persisted = list(Path(tmp).glob("*.json"))
            self.assertEqual(len(persisted), 1)
            self.assertEqual(len(retained), 1)
            self.assertEqual(json.loads(persisted[0].read_text()), retained[0])
            self.assertEqual(retained[0]["source_episode_sha256"], digest(record))
            self.assertTrue(retained[0]["valid"])
            self.assertFalse(retained[0]["native_execution"])


if __name__ == "__main__":
    unittest.main()
