"""Negative/readback contracts for the MAT-003 S2F source-only preflight."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("s2f_validator", HERE / "verify_s2f.py")
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)

CONFIG = {"inputs": {"warmup_ticks": 120, "measured_ticks": 256, "seed": 204}}


def specimen(scenario: str = "active") -> tuple[dict, dict]:
    context = {"id": f"{scenario}-512-w4", "scenario": scenario,
               "side": 512, "workers": 4}
    visits = [0] * 256 if scenario == "quiet" else [14] * 256
    inputs = {"quiet": 0, "small": 2, "active": 128, "reactive": 32}[scenario]
    obs = {"status": "passed", "stage": "S2F-source-feasibility",
           "mode": "qualify", "performance_qualification": False,
           "tick_ns": [], "input_ns": [], "input_tick_ns_separate": True,
           "scenario": scenario, "side": 512, "workers_configured": 4,
           "workers_observed": False, "seed": 204, "warmup_ticks": 120,
           "sample_ticks": 256, "completed_ticks": 376,
           "resident_cells": 512 ** 2, "chunk_count": 16,
           "input_calls_after_warmup": 256 * inputs,
           "reactive_products_observed": 16 if scenario == "reactive" else 0,
           "positive_visit_ticks": sum(x > 0 for x in visits),
           "visits": visits, "phase_jobs": [4] * 256,
           "peak_process_rss_bytes": 123456, "resident_aggregate_bytes_nonadditive": 1048576}
    return obs, context


class EvidenceContracts(unittest.TestCase):
    def test_control_and_maintained_work(self):
        for scenario in ("quiet", "small", "active", "reactive"):
            with self.subTest(scenario=scenario):
                obs, ctx = specimen(scenario)
                validator.check_observation(obs, ctx, CONFIG)

    def test_no_timing_without_admission(self):
        obs, ctx = specimen()
        obs["tick_ns"] = [1] * 256
        with self.assertRaisesRegex(ValueError, "timing"):
            validator.check_observation(obs, ctx, CONFIG)

    def test_configured_worker_not_observed(self):
        obs, ctx = specimen()
        obs["workers_observed"] = True
        with self.assertRaisesRegex(ValueError, "dispatch"):
            validator.check_observation(obs, ctx, CONFIG)

    def test_declining_active_work_rejected(self):
        obs, ctx = specimen()
        obs["visits"] = [14] * 200 + [0] * 56
        obs["positive_visit_ticks"] = 200
        with self.assertRaisesRegex(ValueError, "inactive"):
            validator.check_observation(obs, ctx, CONFIG)

    def test_incomplete_ticks_rejected(self):
        obs, ctx = specimen()
        obs["visits"] = obs["visits"][:-1]
        with self.assertRaisesRegex(ValueError, "sample"):
            validator.check_observation(obs, ctx, CONFIG)

    def test_quiet_work_rejected(self):
        obs, ctx = specimen("quiet")
        obs["visits"][1] = 1
        obs["positive_visit_ticks"] = 1
        with self.assertRaisesRegex(ValueError, "quiescent"):
            validator.check_observation(obs, ctx, CONFIG)

    def test_absent_reaction_rejected(self):
        obs, ctx = specimen("reactive")
        obs["reactive_products_observed"] = 0
        with self.assertRaisesRegex(ValueError, "product"):
            validator.check_observation(obs, ctx, CONFIG)

    def test_false_cell_and_rss_rejected(self):
        obs, ctx = specimen()
        obs["resident_cells"] -= 1
        with self.assertRaisesRegex(ValueError, "resident scale"):
            validator.check_observation(obs, ctx, CONFIG)
        obs, ctx = specimen()
        obs["peak_process_rss_bytes"] = 0
        with self.assertRaisesRegex(ValueError, "memory"):
            validator.check_observation(obs, ctx, CONFIG)


if __name__ == "__main__":
    unittest.main()
