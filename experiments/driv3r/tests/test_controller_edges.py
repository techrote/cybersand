"""Synthetic edge controls: partial receipts, admission fences and exact IDs.

These doubles isolate controller correctness. They never constitute d1 inference
or native World evidence; the separate opt-in native suite owns that proof.
"""
from copy import deepcopy
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

from experiments.driv3r.contracts import Refusal, digest, validate_candidates
from experiments.driv3r.controller import EpisodeController, validate_episode
from experiments.driv3r.providers import DirectProvider, FuzzyProvider, observation
from experiments.driv3r.replay import replay_episode
from experiments.driv3r.tests.test_controller import SyntheticNative, TestPolicy


class PartialReceiptNative(SyntheticNative):
    """Apply an actual synthetic prefix, then cancel at its acknowledgement."""
    def __init__(self, cancel_event, *, prefix_cells=7, corrupt=False):
        super().__init__()
        self.cancel_event = cancel_event
        self.prefix_cells = prefix_cells
        self.corrupt = corrupt

    def apply(self, operations, **_):
        self.writes += 1
        before_hash = digest(self.state["materials"])
        points = list(dict.fromkeys((x, y) for op in operations
            for y in range(op["y0"], op["y1"] + 1)
            for x in range(op["x0"], op["x1"] + 1)))
        changed = 0
        for x, y in points[:self.prefix_cells]:
            changed += self.state["materials"][y * 96 + x] != 58
            self.state["materials"][y * 96 + x] = 58
        if self.corrupt:
            self.state["materials"][95 * 96 + 95] = 58
            changed += 1
        self.state["revision"] += 1
        self.cancel_event.set()
        after = self.observe()
        return {**after, "status": "partial", "receipt": {
            "actual_changed_cells": changed, "expected_changed_cells": len(points),
            "readback_matches": True, "before_world_sha256": before_hash,
            "after_world_sha256": after["observation"]["world_material_sha256"],
            "terminal": {"status": "partial", "changed": changed, "reason": "Synthetic receipt-boundary cancellation"}}}


class ControllerEdgeTests(unittest.TestCase):
    def episode(self, native, provider, policy, *, cancel_event=None, **limits):
        with tempfile.TemporaryDirectory() as directory:
            return EpisodeController(**limits).run(
                native=native, provider=provider, policy=policy, episode_id="edge-control",
                output=Path(directory) / "episode", cancel_event=cancel_event)

    def partial_episode(self, *, corrupt=False):
        cancel = threading.Event()
        native = PartialReceiptNative(cancel, corrupt=corrupt)
        provider = FuzzyProvider()
        result = self.episode(native, provider, TestPolicy("ADD_PLATFORM_THIN"), cancel_event=cancel)
        return result, native, provider

    def test_cancelled_partial_prefix_counts_cells_without_advancing_graph(self):
        result, native, provider = self.partial_episode()
        self.assertEqual(result["terminal_status"], "cancelled")
        self.assertEqual((native.writes, native.stops), (1, 1))
        self.assertEqual(result["actual_changed_cells"], 7)
        self.assertEqual(result["native_actions"], 0)
        self.assertEqual(result["native_attempts"], 1)
        self.assertEqual(result["partial_native_actions"], 1)
        self.assertEqual(provider.node, 0)
        self.assertFalse(result["task_complete"])
        step = result["steps"][0]
        self.assertEqual(step["selected_action"]["id"], "ADD_PLATFORM_THIN")
        self.assertEqual(step["native_response"]["status"], "partial")
        self.assertTrue(step["native_response"]["controller_prefix_consistent"])
        self.assertFalse(step["native_response"]["controller_consistent"])
        verification = validate_episode(result)
        self.assertTrue(verification["passed"])
        self.assertEqual(verification["actual_changed_cells"], 7)
        self.assertEqual(result["final_native"]["world_material_sha256"],
                         step["native_response"]["observation"]["world_material_sha256"])

    def test_partial_prefix_cannot_be_erased_from_episode_accounting(self):
        result, _, _ = self.partial_episode()
        result["actual_changed_cells"] = 0
        with self.assertRaisesRegex(Refusal, "changed-cell total mismatch"):
            validate_episode(result)

    def test_partial_prefix_final_material_hash_remains_bound(self):
        result, _, _ = self.partial_episode()
        result["final_native"]["world_material_sha256"] = result["initial_native"]["world_material_sha256"]
        with self.assertRaisesRegex(Refusal, "Stop changed World materials"):
            validate_episode(result)

    def test_partial_prefix_outside_candidate_is_preserved_and_refused(self):
        result, native, provider = self.partial_episode(corrupt=True)
        self.assertEqual(native.writes, 1)
        self.assertEqual(provider.node, 0)
        self.assertEqual(result["actual_changed_cells"], 8)
        self.assertFalse(result["steps"][0]["native_response"]["controller_prefix_consistent"])
        with self.assertRaisesRegex(Refusal, "unverified native application"):
            validate_episode(result)

    def test_unsupported_partial_replay_refuses_before_native_reset(self):
        result, _, _ = self.partial_episode()
        class ReplayNative(SyntheticNative):
            resets = 0
            def reset(self, *args, **kwargs):
                self.resets += 1
                return super().reset(*args, **kwargs)
        replay_native = ReplayNative()
        with tempfile.TemporaryDirectory() as directory:
            # Synthetic controller evidence has no native byte files. This patch
            # only isolates preflight ordering; it is explicitly not native replay.
            with patch("experiments.driv3r.replay.verify_observation", return_value=[]):
                with self.assertRaisesRegex(Refusal, "[Pp]artial.*[Rr]eplay|[Rr]eplay.*[Pp]artial"):
                    replay_episode(result, replay_native, Path(directory), Path(directory) / "replay")
        self.assertEqual(replay_native.resets, 0, "Unsupported partial replay must refuse before installing a new World")
        self.assertEqual(replay_native.writes, 0)

    def test_deadline_crossing_admission_refresh_blocks_native_write(self):
        class Clock:
            now = 100.0
            def __call__(self): return self.now
        clock = Clock()
        class ExpiringRefresh(SyntheticNative):
            observations = 0
            def observe(self, **kwargs):
                self.observations += 1
                # reset's snapshot, decision observation, then admission refresh.
                if self.observations == 3:
                    clock.now = 102.0
                return super().observe(**kwargs)
        native = ExpiringRefresh()
        with patch("experiments.driv3r.controller.time.monotonic", clock):
            result = self.episode(native, DirectProvider(), TestPolicy(), max_wall_seconds=1)
        self.assertEqual(result["terminal_status"], "budget_exhausted")
        self.assertEqual(result["steps"][0]["host_status"], "budget_exhausted")
        self.assertEqual(native.writes, 0)
        self.assertEqual(native.stops, 1)
        self.assertEqual(result["actual_changed_cells"], 0)

    def test_cardinal_id_must_match_exact_destination_and_footprint(self):
        native = SyntheticNative()
        state = native.reset()["observation"]
        provider = DirectProvider()
        observed = observation(state, provider, episode_id="direction-control", step=0,
            decisions_remaining=2, changed_cells_remaining=10, wall_seconds_remaining=30)
        original = provider.candidates(state, observed)
        by_id = {candidate["id"]: candidate for candidate in original}
        for supplied, opposite in (("UP", "DOWN"), ("DOWN", "UP"), ("LEFT", "RIGHT"), ("RIGHT", "LEFT")):
            candidates = deepcopy(original)
            candidate = next(c for c in candidates if c["id"] == supplied)
            candidate["destination"] = by_id[opposite]["destination"].copy()
            candidate["operations"] = deepcopy(by_id[opposite]["operations"])
            with self.subTest(supplied=supplied), self.assertRaisesRegex(Refusal, "ID differs from its cardinal movement"):
                validate_candidates(candidates, observed)

    def test_tampered_tools_cannot_cross_native_permissions(self):
        for label, x, y, material, terminal in (
                ("protected source material", 8, 20, 58, "native_refusal"),
                ("protected empty rectangle", 40, 40, 58, "native_refusal"),
                ("outside focus", 96, 60, 58, "invalid_decision"),
                ("unauthorized material", 52, 60, 0, "invalid_decision")):
            class TamperedProvider(FuzzyProvider):
                def candidates(self, state, observed):
                    candidates = super().candidates(state, observed)
                    candidates[0]["operations"] = [{"shape":"rectangle", "material":material,
                        "x0":x, "x1":x, "y0":y, "y1":y}]
                    return candidates
            native = SyntheticNative()
            result = self.episode(native, TamperedProvider(), TestPolicy("ADD_PLATFORM_THIN"))
            with self.subTest(label=label):
                self.assertEqual(result["terminal_status"], terminal)
                self.assertEqual(native.writes, 0)
                self.assertEqual(result["actual_changed_cells"], 0)


if __name__ == "__main__":
    unittest.main()
