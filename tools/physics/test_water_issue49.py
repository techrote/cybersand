from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("water_issue49", HERE / "water_issue49.py")
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("unable to load water_issue49 runner")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def surface_sample(tick: int, value: int | None, *, valid: bool = True) -> dict:
    return {
        "tick": tick,
        "surface_spread_milli": value,
        "surface_coverage_valid": valid,
    }


def level_sample(tick: int, value: int | None, *, valid: bool = True) -> dict:
    return {
        "tick": tick,
        "level_difference_milli": value,
        "level_difference_valid": valid,
    }


class EquilibriumContractTests(unittest.TestCase):
    def test_dry_column_concentration_cannot_look_flat(self) -> None:
        samples = [surface_sample(0, 4000)]
        samples.extend(surface_sample(tick, 0, valid=False) for tick in (60, 120, 180, 240, 300))
        result = MODULE.sustained_suffix_status(
            samples, "calm-settling", lambda value: value <= 1000
        )
        self.assertEqual(result, {"status": "invalid_coverage", "tick": None})

    def test_empty_roi_is_invalid_not_flat(self) -> None:
        samples = [surface_sample(0, None, valid=False)]
        samples.extend(
            surface_sample(tick, None, valid=False)
            for tick in (60, 120, 180, 240, 300)
        )
        row = {"scenario": "calm-settling", "samples": samples}
        result = MODULE.derive_equilibrium(row)
        self.assertEqual(result["one_cell"]["status"], "invalid_coverage")
        self.assertIsNone(result["one_cell"]["tick"])

    def test_transient_five_sample_pass_is_revoked_by_regression(self) -> None:
        samples = [surface_sample(0, 4000)]
        samples.extend(
            surface_sample(tick, 800)
            for tick in (60, 120, 180, 240, 300)
        )
        samples.append(surface_sample(360, 2000))
        result = MODULE.sustained_suffix_status(
            samples, "calm-settling", lambda value: value <= 1000
        )
        self.assertEqual(result, {"status": "not_reached", "tick": None})

    def test_final_five_sample_suffix_reaches(self) -> None:
        samples = [level_sample(0, 8000)]
        samples.extend(
            level_sample(tick, value)
            for tick, value in (
                (60, 5000),
                (120, 900),
                (180, 800),
                (240, 700),
                (300, 600),
                (360, 500),
            )
        )
        result = MODULE.sustained_suffix_status(
            samples, "communicating-pools", lambda value: value <= 1000
        )
        self.assertEqual(result, {"status": "reached", "tick": 120})

    def test_censored_values_never_reduce_as_zero(self) -> None:
        reduction = MODULE.reached_median(
            [
                {"status": "reached", "tick": 120},
                {"status": "not_reached", "tick": None},
                {"status": "invalid_coverage", "tick": None},
                {"status": "reached", "tick": 180},
            ]
        )
        self.assertEqual(reduction["reached_tick_median"], 150.0)
        self.assertEqual(
            reduction["status_counts"],
            {"reached": 2, "not_reached": 1, "invalid_coverage": 1},
        )

    def test_monotonic_slope_is_not_a_terrace(self) -> None:
        result = MODULE.residual_terraces([1000, 2000, 3000, 4000, 5000])
        self.assertEqual(result["count"], 0)

    def test_discrete_shelf_survives_slope_removal(self) -> None:
        result = MODULE.residual_terraces([1000, 1000, 1000, 4000, 4000, 4000])
        self.assertGreaterEqual(result["count"], 1)


class RunnerDurabilityTests(unittest.TestCase):
    def test_nonempty_destination_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw)
            (path / "existing.txt").write_text("historical", encoding="utf-8")
            with self.assertRaises(MODULE.EvidenceError):
                MODULE.prepare_output(path)
            self.assertEqual(
                (path / "existing.txt").read_text(encoding="utf-8"), "historical"
            )

    def _attempt(self, command: list[str], timeout: int = 5):
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw)
            return MODULE.execute_attempt(
                command,
                timeout_seconds=timeout,
                cwd=path,
                stdout_path=path / "stdout.json",
                execution_path=path / "execution.json",
                metadata={"case": "adversarial"},
            )

    def test_nonzero_child_is_retained(self) -> None:
        disposition, row, record = self._attempt(
            [sys.executable, "-c", "import sys; print('partial'); sys.exit(7)"]
        )
        self.assertEqual(disposition, "nonzero_exit")
        self.assertIsNone(row)
        self.assertEqual(record["exit"], 7)

    def test_malformed_child_output_is_retained(self) -> None:
        disposition, row, record = self._attempt(
            [sys.executable, "-c", "print('not-json')"]
        )
        self.assertEqual(disposition, "malformed_output")
        self.assertIsNone(row)
        self.assertIn("error", record)

    def test_timeout_is_retained(self) -> None:
        disposition, row, record = self._attempt(
            [sys.executable, "-c", "import time; time.sleep(2); print('{}')"],
            timeout=1,
        )
        self.assertEqual(disposition, "timeout")
        self.assertIsNone(row)
        self.assertIsNone(record["exit"])

    def test_registered_matrix_is_complete_and_unique(self) -> None:
        cases = MODULE.registered_cases()
        self.assertEqual(len(cases), 10 * 3 * 2 * 2)
        self.assertEqual(len({case["case"] for case in cases}), len(cases))


if __name__ == "__main__":
    unittest.main()
