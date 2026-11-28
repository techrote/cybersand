import copy
import unittest

from run_native_stage_probe import STAGES, joined_stages


class NativeStageProbeTests(unittest.TestCase):
    def fixture(self):
        before = {"schema": "PUBPRES-WAVE-COLUMNS-V1", "experimental_column_tiles": False,
                  "column_slots": 1, "ticks": 0, **{key: 0 for key in STAGES}}
        after = {**before, "ticks": 1, **{key: 100000 for key in STAGES}}
        step = {"event": "rapier_step", "step": 1, "world_generation": 7, "native_tick_used": 1,
                "completed_body_sample": 5, "time_usec": 3000, "native_completed_usec": 2000}
        packet = {"event": "worker_snapshot", "world_generation": 7, "tick_index": 1,
                  "completed_body_sample": 5, "failed": False, "time_usec": 2100,
                  "wave_column_probe": after, "native_tick_ms": 1.0}
        return {"water_before": {"wave_flow": {"column_probe": before}}}, [step, packet]

    def test_observed_tick_retains_elapsed_remainder(self):
        data, rows = self.fixture()
        result = joined_stages(data, rows)
        self.assertAlmostEqual(result[0]["native_outside_wave_stage_brackets_ms"], .4)
        self.assertNotIn("native_started_usec", result[0])

    def test_wrong_world_or_sample_cannot_join(self):
        for key in ("world_generation", "completed_body_sample"):
            data, rows = self.fixture()
            rows[1][key] += 1
            with self.assertRaisesRegex(ValueError, "matching healthy"):
                joined_stages(data, rows)

    def test_changed_duplicate_packet_is_refused(self):
        data, rows = self.fixture()
        extra = copy.deepcopy(rows[1]); extra["wave_column_probe"]["column_ns"] += 1
        with self.assertRaisesRegex(ValueError, "differs for one"):
            joined_stages(data, [*rows, extra])

    def test_skipped_turn_and_coerced_stage_are_refused(self):
        for key, value in (("ticks", 2), ("ticks", True), ("column_ns", True), ("column_ns", -1)):
            data, rows = self.fixture(); rows[1]["wave_column_probe"][key] = value
            with self.assertRaises(ValueError): joined_stages(data, rows)

    def test_invalid_or_overlapping_elapsed_is_refused(self):
        for value in (True, float("nan"), -.5, .2):
            data, rows = self.fixture(); rows[1]["native_tick_ms"] = value
            with self.assertRaises(ValueError): joined_stages(data, rows)


if __name__ == "__main__":
    unittest.main()
