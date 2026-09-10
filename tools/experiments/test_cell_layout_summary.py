"""Regression checks for L1 evidence parsing and registered statistics."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("summary", Path(__file__).with_name("summarize_cell_layout.py"))
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)
OUT = Path(__file__).resolve().parents[2] / "validation/local/issue-16"


class SummaryTests(unittest.TestCase):
    def test_nearest_rank_and_work_weighted_denominator(self):
        result = summary.summarize_samples([dict(ns=i, visited=2) for i in range(1, 101)])
        self.assertEqual((result["p50"], result["p95"], result["p99"]), (50, 95, 99))
        self.assertEqual(result["total"], 5050)
        self.assertEqual(result["ns_per_visited"], 25.25)
        self.assertIsNone(summary.summarize_samples([dict(ns=1, visited=0)])["ns_per_visited"])

    def test_epoch_timeline_uses_world_tick_after_sparse_setup(self):
        rows = [dict(sample=i, tick=i+5, ns=700 if i+5 in (256,511) else 100, visited=1)
                for i in range(515)]
        result = summary.epoch_proxy(rows)
        self.assertEqual([r["tick"] for r in result], [256,511])
        self.assertEqual([r["sample"] for r in result], [251,506])
        self.assertEqual([r["excess_ns"] for r in result], [600,600])

    def test_timing_parser_retains_work_and_state_but_omits_events(self):
        with tempfile.TemporaryDirectory(dir=OUT) as tmp:
            path = Path(tmp)/"records"
            core = bytes(240) + struct.pack("<Q",22) + bytes(range(22)) + bytes(128)
            path.write_bytes(core+struct.pack("<Q",1)+struct.pack("<QQ",3,17))
            self.assertEqual(summary.normalized_timing_record(path,2),core)
            path.write_bytes(core+struct.pack("<Q",0))
            self.assertEqual(summary.normalized_timing_record(path,2),core)
            path.write_bytes(core+struct.pack("<Q",1)+b"short")
            with self.assertRaises(ValueError): summary.normalized_timing_record(path,2)

    def test_partial_campaign_is_not_a_completed_screen(self):
        with tempfile.TemporaryDirectory(dir=OUT) as tmp:
            directory = Path(tmp)
            (directory/"plan.json").write_text(json.dumps([{}]*196))
            (directory/"results.json").write_text("[]")
            with self.assertRaisesRegex(ValueError,"Incomplete registered campaign"):
                summary.summarize(directory)
            self.assertFalse((directory/"reduced.json").exists())

    def test_work_crosschecks_csv_and_dispatch_threshold(self):
        with tempfile.TemporaryDirectory(dir=OUT) as tmp:
            path = Path(tmp)/"records"
            # One phase below the threshold and one at it.
            values = [5, 100, 40, 2, 2, 3, 1, 15, 2, 0, 1, 7, 8, 0, 0]
            path.write_bytes(struct.pack("<15Q", *values))
            ticks = [dict(tick=5, visited=100)]
            result = summary.work_summary(path,ticks,4)
            self.assertEqual(result["pool_dispatches_inferred_from_phase_jobs"],1)
            self.assertEqual(result["pool_jobs_inferred_from_phase_jobs"],8)
            self.assertEqual(summary.work_summary(path,ticks,1)["pool_jobs_inferred_from_phase_jobs"],0)
            with self.assertRaisesRegex(ValueError,"Work/CSV"):
                summary.work_summary(path,[dict(tick=5,visited=99)],4)
            values[7] = 16
            path.write_bytes(struct.pack("<15Q", *values))
            with self.assertRaisesRegex(ValueError,"Work/CSV"):
                summary.work_summary(path,ticks,4)


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    unittest.main()
