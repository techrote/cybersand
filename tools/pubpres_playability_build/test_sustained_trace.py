#!/usr/bin/env python3
"""Exercise sustained witness custody independently of the summary claims."""

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from sustained_trace import reduce_trace


def fixture():
    source, workload = {"source_sha": "a" * 40}, {"extent": [2048, 1024]}
    receipt = {"source_identity": source, "fixture": workload, "capture_start_usec": 1000,
               "capture_end_usec": 65001000, "resident_samples": [{"world_generation": 3}]}
    rows = [{"event": "identity", "source": source, "fixture": workload}]
    for number in range(1, 145):
        completed = 1000 + number * 350000
        snapshot = {"native_completed_usec": completed - 40, "physics_handoff_usec": completed - 25,
                    "completed_body_sample": number + 1,
                    "required_hard_revision": 4}
        rows.append({"event": "rapier_step", "start_usec": completed - 20, "time_usec": completed,
                     "step": number, "manual_steps": number, "native_tick_used": number,
                     "native_snapshot_serial": number + 5, "epoch": 1, "session": 1, "fixed_delta": 1 / 60,
                     "pending_hard_chunks": 0, "installed_hard_revision": 4, "packet_hard_revision": 4,
                     "response_accepted": True, "response_refusal": "", "accepted_samples": [number + 1, number + 1],
                     "bodies": [{"slot": 0, "instance_id": 1}, {"slot": 1, "instance_id": 2}], **snapshot})
        rows.append({"event": "worker_snapshot", "tick_index": number, "snapshot_serial": number + 5,
                     "world_generation": 3, "failed": False, "hard_surface_revision": 4,
                     "water_ledger_healthy": True,
                     "water_ledger": {"visible": 22, "overfill": 1, "ballistic": 4, "total": 27, "expected": 27}, **snapshot})
        rows.append({"event": "native_completion_observed", "tick_index": number, "world_generation": 3,
                     "body_sample": number + 1})
        rows.append({"event": "physics_callback", "start_usec": completed - 20, "time_usec": completed + 12,
                     "before_step": number - 1, "after_step": number, "physics_frame": number + 10})
    transitions, pulses = [], []
    for number in range(10):
        interval = (number + 1) * 6000000
        dense, time = 2 * number + 2, 1000 + interval + 500
        pulses.append({"sequence": number, "elapsed_usec": interval, "paint_admitted": True,
                       "camera": "follow" if number % 2 == 0 else "free", "render_serial_before": dense - 1})
        rows.append({"event": "texture_upload", "world_generation": 3, "full_refresh": True, "patch_bytes": 4194304,
                     "render_serial": dense, "time_usec": time, "material": {"submitted_bytes": 4194304}})
        rows.append({"event": "texture_upload", "world_generation": 3, "full_refresh": False, "patch_bytes": 64,
                     "render_serial": dense + 1, "time_usec": time + 100, "material": {"submitted_bytes": 64}})
        transitions.append({"dense_serial": dense, "sparse_serial": dense + 1, "sparse_packet_bytes": 64,
                            "publisher_history_copy": False, "publisher_submitted_bytes": 64,
                            "elapsed_usec": time + 100 - 1000})
    receipt.update(actual_rapier_steps=144, late_rapier_steps=16, transition_receipts=transitions, pulses=pulses)
    return rows, receipt


class SustainedEvidenceTests(unittest.TestCase):
    def reduce(self, rows, receipt):
        raw = b"".join(json.dumps(row).encode() + b"\n" for row in rows)
        receipt["trace_sha256"] = hashlib.sha256(raw).hexdigest()
        with tempfile.TemporaryDirectory() as folder:
            trace = Path(folder) / "trace.jsonl"
            trace.write_bytes(raw)
            return reduce_trace(trace, receipt)

    def test_authoritative_raw_witnesses_recover_counts(self):
        result = self.reduce(*fixture())
        self.assertEqual((result["rapier_steps"], result["late_rapier_steps"], result["dense_to_sparse"]), (144, 16, 10))

    def test_empty_but_rehashed_trace_refuses(self):
        _, receipt = fixture()
        with self.assertRaisesRegex(ValueError, "trace is empty"):
            self.reduce([], receipt)

    def test_duplicate_physical_row_with_forged_hash_refuses(self):
        rows, receipt = fixture()
        rows.insert(2, rows[1].copy())
        with self.assertRaisesRegex(ValueError, "Duplicate, reordered or missing"):
            self.reduce(rows, receipt)

    def test_rehashed_wrong_identity_refuses(self):
        rows, receipt = fixture()
        rows[0]["source"] = {"source_sha": "b" * 40}
        with self.assertRaisesRegex(ValueError, "identity differs"):
            self.reduce(rows, receipt)

    def test_missing_worker_authority_refuses(self):
        rows, receipt = fixture()
        rows.pop(2)
        with self.assertRaisesRegex(ValueError, "lack.*matching native"):
            self.reduce(rows, receipt)

    def test_rehashed_duplicate_worker_or_unknown_event_refuses(self):
        for extra, message in (({"event": "unexpected"}, "Unknown sustained trace event"),
                               ({}, "Duplicate or reordered sustained worker publication")):
            with self.subTest(extra=extra):
                rows, receipt = fixture()
                rows.insert(3, {**rows[2], **extra})
                with self.assertRaisesRegex(ValueError, message):
                    self.reduce(rows, receipt)

    def test_impossible_handoff_or_wrong_publication_clock_refuses(self):
        for change, message in ((100, "step timing"), (1, "lack.*matching native")):
            with self.subTest(change=change):
                rows, receipt = fixture()
                rows[1]["physics_handoff_usec"] += change
                with self.assertRaisesRegex(ValueError, message):
                    self.reduce(rows, receipt)

    def test_rehashed_wrong_water_ledger_refuses(self):
        rows, receipt = fixture()
        rows[2]["water_ledger"]["expected"] += 1
        with self.assertRaisesRegex(ValueError, "lack.*matching native"):
            self.reduce(rows, receipt)

    def test_rehashed_duplicate_completed_physics_frame_refuses(self):
        rows, receipt = fixture()
        rows[8]["physics_frame"] = rows[4]["physics_frame"]
        with self.assertRaisesRegex(ValueError, "Duplicate, multi-step or out-of-capture callback"):
            self.reduce(rows, receipt)

    def test_completed_callback_beyond_capture_refuses(self):
        rows, receipt = fixture()
        rows[4]["time_usec"] = receipt["capture_end_usec"] + 1
        with self.assertRaisesRegex(ValueError, "out-of-capture callback"):
            self.reduce(rows, receipt)

    def test_missing_callback_authority_refuses(self):
        rows, receipt = fixture()
        rows.pop(4)
        with self.assertRaisesRegex(ValueError, "lacks its unique real physics callback"):
            self.reduce(rows, receipt)

    def test_rehashed_transition_tampering_refuses(self):
        rows, receipt = fixture()
        rows[-1]["patch_bytes"] = 63
        with self.assertRaisesRegex(ValueError, "transition witnesses differ"):
            self.reduce(rows, receipt)

    def test_declared_pulse_must_join_to_a_later_raw_transition(self):
        rows, receipt = fixture()
        receipt["pulses"][-1]["render_serial_before"] = receipt["transition_receipts"][-1]["sparse_serial"]
        with self.assertRaisesRegex(ValueError, "Recovery pulse lacks a matching"):
            self.reduce(rows, receipt)


if __name__ == "__main__":
    unittest.main()
