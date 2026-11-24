#!/usr/bin/env python3
"""Adversarial checks for explicit engine/owner isolation and honest draw clocks."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from renderer_contract import expected_renderer_reducer, verify_renderer_reducer
from run_renderer_comparison import validate_draw_identity, validate_renderer_cohort, validate_requested_renderer

ROOT = Path(__file__).resolve().parents[2]


class RegisteredRendererContract(unittest.TestCase):
    def setUp(self):
        self.registration = json.loads((ROOT / "tools/pubpres_final/renderer_registration.json").read_text())

    def test_only_explicit_render_owner_gate_differs_from_frozen_v3(self):
        record = verify_renderer_reducer(ROOT)
        self.assertEqual(len(record["registered_renderer_sha256"]), 64)
        original = (ROOT / "tools/pubpres_playability/results_same_frame.py").read_bytes()
        with self.assertRaises(ValueError):
            expected_renderer_reducer(original.replace(b"pending_hard_chunks", b"pending_fake_chunks", 1))

    def test_two_independent_counterbalanced_questions_are_registered(self):
        plan = self.registration["order"]
        self.assertEqual([(item["engine"], item["render_thread"]) for item in plan],
                         [("official", "safe"), ("patched", "safe"), ("patched", "separate"),
                          ("patched", "separate"), ("patched", "safe"), ("official", "safe")])
        self.assertEqual(self.registration["comparisons"],
                         {"engine_safe_abba": [0, 1, 4, 5], "patched_render_owner_abba": [1, 2, 3, 4]})

    def test_separate_cannot_claim_live_main_serial_as_draw_identity(self):
        safe = [{"event": "framebuffer_draw", "inline_main": True, "render_serial": 77}]
        separate = [{"event": "framebuffer_draw", "inline_main": False, "render_serial": -1,
                     "draw_identity_scope": "unknown: Separate notification deferred to Main"}]
        validate_draw_identity(safe, "safe")
        validate_draw_identity(separate, "separate")
        with self.assertRaises(ValueError):
            validate_draw_identity(safe, "separate")
        with self.assertRaises(ValueError):
            validate_draw_identity(separate, "safe")
        separate[0]["render_serial"] = 77
        with self.assertRaises(ValueError):
            validate_draw_identity(separate, "separate")

    def test_actual_rendezvous_owner_and_executable_must_match_requested_arm(self):
        case = {"fixture": "basin512", "camera": "follow", "workers": 4, "water_law": "wave_flow_v1"}
        campaign = {"measurement": {"water_profile": "reference"}}
        selector = {"physics": "early", "presentation": "coherent", "cadence": "repaired",
                    "rendezvous": {"mode": "off", "separate_render_thread": True}}
        data = {"source_identity": {"source_sha": "same-source", "engine_sha256": "patched-sha"},
                "case_nonce": "nonce", "renderer": "opengl3_angle", "fixture": {"name": "basin512"},
                "render_thread": {"requested": "separate", "runtime": "separate"}, "camera": "follow",
                "workers": 4, "water_law": "wave_flow_v1", "water_profile": "reference", "water_variant": "reference",
                "input_mode": "tape", "command_mode": "repeated_callback", "observer_mode": "full",
                "selectors_before": copy.deepcopy(selector), "selectors_after": copy.deepcopy(selector)}
        def validate(value):
            validate_requested_renderer(value, case, campaign, "same-source", "nonce", "patched-sha", "separate")
        validate(data)
        for name, corrupt in (
            ("source", lambda d: d["source_identity"].update(source_sha="other-source")),
            ("engine", lambda d: d["source_identity"].update(engine_sha256="official-sha")),
            ("actual_thread", lambda d: d["render_thread"].update(runtime="safe")),
            ("main_observed_owner", lambda d: d["selectors_after"]["rendezvous"].update(separate_render_thread=False)),
            ("physics_policy", lambda d: d["selectors_before"].update(physics="combined")),
            ("fixture", lambda d: d["fixture"].update(name="basin2048")),
        ):
            with self.subTest(name=name):
                changed = copy.deepcopy(data)
                corrupt(changed)
                with self.assertRaises(ValueError):
                    validate(changed)

    def test_engine_owner_exceptions_do_not_allow_hardware_or_outcome_drift(self):
        arms = []
        for index, treatment in enumerate(self.registration["order"]):
            thread, engine = treatment["render_thread"], treatment["engine"]
            match = {"engine": self.registration[engine + "_engine_sha256"],
                     "render_thread": {"requested": thread, "runtime": thread},
                     "cpu": "same-host", "renderer": "opengl3_angle", "adapter": "same-adapter",
                     "water_law": "wave_flow_v1", "water_profile": "reference"}
            stats = {"match": match, "source": "same-source", "first_144_body_trajectory_sha256": "same-bodies",
                     "first_144_admitted_moves_sha256": "same-moves", "command_counts": {"accepted": 200},
                     "command_mode": "repeated_callback", "registered_material_treatment": {"backend": "full", "policy": ""},
                     "same_frame_continuation": {"enabled": False},
                     "windows": {"first_144_steps": {"completed_rapier_steps": 144, "rapier_steps_per_second": 10,
                                  "physical_gap_ms": {"p95": 100, "p99": 200, "max": 300}}},
                     "physical_gap_counts_above_ms": {"first_144_steps": {"100": 20, "250": 2, "500": 0, "1000": 0}}}
            arms.append({"index": index, "arm": "C", "treatment": treatment, "statistics": stats,
                         "slots": {"requested_slots": 2, "effective_slots_verified": True}})
        result = validate_renderer_cohort(arms, self.registration)
        self.assertTrue(result["physical_outcome_parity"]["same_source_pairs_equal"])
        self.assertFalse(result["registered_directions"]["patched_render_owner_abba"]["repeatable_direction"])
        for name, corrupt in (
            ("different_cpu", lambda a: a[2]["statistics"]["match"].update(cpu="another-host")),
            ("different_driver", lambda a: a[2]["statistics"]["match"].update(adapter="another-adapter")),
            ("wrong_engine", lambda a: a[2]["statistics"]["match"].update(engine=self.registration["official_engine_sha256"])),
            ("wrong_render_thread", lambda a: a[2]["statistics"]["match"]["render_thread"].update(runtime="safe")),
            ("different_physical_outcome", lambda a: a[2]["statistics"].update(first_144_body_trajectory_sha256="other-bodies")),
            ("different_admitted_commands", lambda a: a[2]["statistics"].update(first_144_admitted_moves_sha256="other-moves")),
            ("wrong_slots", lambda a: a[2]["slots"].update(requested_slots=3)),
            ("missing_arm", lambda a: a.pop()),
        ):
            with self.subTest(name=name):
                changed = copy.deepcopy(arms)
                corrupt(changed)
                with self.assertRaises(ValueError):
                    validate_renderer_cohort(changed, self.registration)


if __name__ == "__main__":
    unittest.main()
