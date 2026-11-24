#!/usr/bin/env python3
"""Raw-clock adversaries for the native development screen; no runtime claim."""
import copy
import math
import unittest

from native_empty_derived import reconstruct


def sample():
    raw = [1000000 + index * 10000 for index in range(72)]
    phases = [[10000, 400000, 30000, 20000] for _ in raw]
    data = {"schema": "pubpres-empty-derived-native-v1", "scope": "native-only", "ticks": 72,
            "tick_nanoseconds": raw, "phase_nanoseconds": phases,
            "phase_columns": ["prepare", "column", "flux", "apply"], "bodies": 1,
            "checkpoints": [123] * 36, "wave_storage_bytes": 4096,
            "water_units": 2550, "launched_parcels": 3,
            "tick_mean_ms": sum(raw) / 72 / 1e6, "tick_max_ms": max(raw) / 1e6}
    for percentage in (50, 95, 99):
        data[f"tick_p{percentage}_ms"] = raw[math.ceil(72 * percentage / 100) - 1] / 1e6
    for index, name in enumerate(data["phase_columns"]):
        data[name + "_mean_ms"] = phases[0][index] / 1e6
    return data


class NativeEmptyClockReader(unittest.TestCase):
    def test_all_aggregates_reconstruct_without_pooling(self):
        data = sample()
        result = reconstruct(data)
        self.assertEqual(result["tick_mean_ms"], 1.355)
        self.assertEqual(result["tick_p50_ms"], 1.35)
        self.assertEqual(result["tick_p95_ms"], 1.68)
        self.assertEqual(result["tick_p99_ms"], result["tick_max_ms"])
        self.assertEqual(result["column_mean_ms"], 0.4)

    def test_missing_forged_or_noninteger_clocks_refuse(self):
        for name, mutate in (
            ("missing_tick", lambda d: d["tick_nanoseconds"].pop()),
            ("forged_mean", lambda d: d.update(tick_mean_ms=0.5)),
            ("forged_tail", lambda d: d.update(tick_p99_ms=1.35)),
            ("forged_phase", lambda d: d.update(column_mean_ms=0.01)),
            ("reordered_phase_labels", lambda d: d["phase_columns"].reverse()),
            ("missing_phase", lambda d: d["phase_nanoseconds"].pop()),
            ("overlapping_phase", lambda d: d["phase_nanoseconds"][0].__setitem__(0, 9000000)),
            ("bool_clock", lambda d: d["tick_nanoseconds"].__setitem__(0, True)),
            ("float_clock", lambda d: d["phase_nanoseconds"][0].__setitem__(0, 10000.0)),
            ("missing_checkpoint", lambda d: d["checkpoints"].pop()),
            ("bool_checkpoint", lambda d: d["checkpoints"].__setitem__(0, True)),
        ):
            with self.subTest(name=name):
                data = copy.deepcopy(sample())
                mutate(data)
                with self.assertRaises(ValueError):
                    reconstruct(data)


if __name__ == "__main__":
    unittest.main()
