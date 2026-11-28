#!/usr/bin/env python3
"""Adversarial checks for cumulative material, authority and unearned ACK credit."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

import material_deadline_oracle as oracle
from qualification_oracles import digest, file_digest


SOURCE, ENGINE, DRIVER = "a" * 40, "b" * 64, "opengl3"


class DeadlineOracle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.project = Path(cls.temporary.name)
        for relative in ("scripts/main.gd", "scripts/simulation_worker.gd", oracle.POLICY,
                         "scripts/full_image_ring_publisher.gd", "tests/support/ci_execution_policy.json",
                         oracle.FIXTURE[6:], oracle.IDENTITY_FIXTURE[6:]):
            path = cls.project / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("test-only:" + relative + "\n", encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def receipt(self, slots=2):
        result = {"schema": "pubpres-material-deadline-main-history-v1", "checks": 46,
                  "complete": True, "failures": [], "source": SOURCE, "pid": 521,
                  "driver": DRIVER, "render_thread_inline": True,
                  "synthetic_scheduling_clocks": True, "performance_claim": False,
                  "main_sha256": file_digest(self.project / "scripts/main.gd"),
                  "worker_sha256": file_digest(self.project / "scripts/simulation_worker.gd"),
                  "policy_sha256": file_digest(self.project / oracle.POLICY),
                  "publisher_sha256": file_digest(self.project / "scripts/full_image_ring_publisher.gd"),
                  "context": {"schema": "palette-qualification-context-v1", "source_revision": SOURCE,
                              "fixture": oracle.FIXTURE, "fixture_sha256": file_digest(self.project / oracle.FIXTURE[6:]),
                              "engine_sha256": ENGINE, "backend": DRIVER, "display_server": "X11",
                              "platform": "Linux", "godot": {"major": 4, "minor": 7}, "process_id": 521,
                              "execution_policy": {"ok": True, "schema_version": 1,
                                                   "path": "res://tests/support/ci_execution_policy.json",
                                                   "sha256": file_digest(self.project / "tests/support/ci_execution_policy.json")}},
                  "observations": [], "transactions": [], "rates": []}
        for hz in (30, 60):
            for row in oracle.history_expectations():
                result["observations"].append({"hz": hz, **row,
                                               "current_verified": True, "previous_verified": True,
                                               "expected_current_sha256": row["current_sha256"],
                                               "expected_previous_sha256": row["previous_sha256"]})
            transactions = oracle.transaction_expectations(hz)
            result["transactions"].extend(transactions)
            result["rates"].append({"hz": hz, "acks": [20, 24, 25, 30], "status": transactions[-1]["status"],
                                    "actual_rapier_steps": 0, "full_image_slots": slots})
        return result

    def validate(self, receipt, slots=2):
        return oracle.main_history_result("MATERIAL_DEADLINE_MAIN_RESULT " + json.dumps(receipt),
                                          SOURCE, self.project, DRIVER, engine_sha256=ENGINE, slots=slots)

    def test_registered_histories_preserve_overlap_condition_and_prior_world(self):
        # Per-cell painting is deliberately different from the reducer's row copies.
        for count in (3, 4):
            cells = []
            for y in range(19):
                for x in range(33):
                    pixel = (3, 137)
                    for px, py, width, height, material, condition in oracle.PATCHES[:count]:
                        if px <= x < px + width and py <= y < py + height:
                            pixel = material, condition
                    cells.extend(pixel)
            self.assertEqual(oracle.patched_plane(count), bytes(cells))
        expected = oracle.history_expectations()
        self.assertEqual(expected[3]["previous_sha256"], digest(oracle.patched_plane(4)))
        self.assertNotEqual(expected[1]["current_sha256"], expected[2]["current_sha256"])
        self.validate(self.receipt())
        self.validate(self.receipt(3), 3)

    def test_wrong_bytes_cannot_self_certify_and_skipped_serials_earn_no_credit(self):
        faults = [
            ("self_certified_pixels", lambda d: d["observations"][1].update(current_sha256="0" * 64, expected_current_sha256="0" * 64)),
            ("lost_previous", lambda d: d["observations"][2].update(previous_sha256=d["observations"][2]["current_sha256"])),
            ("stale_world", lambda d: d["observations"][3].update(uploaded_generation=42)),
            ("lost_previous_world", lambda d: d["observations"][3].update(previous_verified=False)),
            ("skipped_ack", lambda d: d["transactions"][2]["acks"].append(22)),
            ("cancelled_ack", lambda d: d["rates"][0]["acks"].append(31)),
            ("premature_CPU_mutation", lambda d: d["transactions"][1].update(cpu_current_sha256=d["observations"][1]["current_sha256"])),
            ("renewed_deadline", lambda d: d["transactions"][3]["status"].update(deadline_usec=150000)),
            ("unbounded_pending", lambda d: d["transactions"][3]["status"].update(pending_count=2)),
            ("lost_cancellation", lambda d: d["transactions"][10]["status"].update(pending_serial=31, pending_count=1)),
            ("physical_credit", lambda d: d["rates"][0].update(actual_rapier_steps=1)),
            ("boolean_step", lambda d: d["rates"][0].update(actual_rapier_steps=False)),
            ("invented_performance", lambda d: d.update(performance_claim=True)),
            ("missing_gpu_history", lambda d: d["observations"].pop()),
            ("reordered_gpu_history", lambda d: d["observations"].reverse()),
            ("missing_boundary", lambda d: d["transactions"].pop()),
            ("wrong_policy_source", lambda d: d.update(policy_sha256="0" * 64)),
            ("wrong_worker_source", lambda d: d.update(worker_sha256="0" * 64)),
            ("wrong_engine", lambda d: d["context"].update(engine_sha256="0" * 64)),
            ("wrong_owner", lambda d: d.update(render_thread_inline=False)),
            ("wrong_slots", lambda d: d["rates"][1].update(full_image_slots=3)),
        ]
        for name, corrupt in faults:
            with self.subTest(name=name):
                receipt = self.receipt()
                corrupt(receipt)
                with self.assertRaises((ValueError, KeyError, TypeError)):
                    self.validate(receipt)

    def test_headless_coverage_cannot_be_reported_as_gpu_or_physical_success(self):
        policy = {"schema": "pubpres-material-deadline-policy-v1", "checks": 57,
                  "complete": True, "failures": [], "synthetic_clocks": True, "physical_credit": False,
                  "policy_sha256": file_digest(self.project / oracle.POLICY)}
        identity = {"schema": "pubpres-material-deadline-main-identity-v1", "checks": 25,
                    "complete": True, "failures": [], "synthetic_identity_fields": True,
                    "physical_credit": False, "gpu_uploads": 0, "cancelled_cases": oracle.IDENTITY_CASES.copy(),
                    "main_sha256": file_digest(self.project / "scripts/main.gd"),
                    "fixture_sha256": file_digest(self.project / oracle.IDENTITY_FIXTURE[6:])}
        for test, marker, data in (("test_material_publication_deadline", "MATERIAL_DEADLINE_RESULT ", policy),
                                   ("test_material_deadline_main_identity", "MATERIAL_DEADLINE_IDENTITY_RESULT ", identity)):
            oracle.headless_result(test, marker + json.dumps(data), self.project)
            corrupted = copy.deepcopy(data)
            corrupted["physical_credit"] = True
            with self.assertRaises(ValueError):
                oracle.headless_result(test, marker + json.dumps(corrupted), self.project)
        identity["cancelled_cases"].pop()
        with self.assertRaises(ValueError):
            oracle.headless_result("test_material_deadline_main_identity", "MATERIAL_DEADLINE_IDENTITY_RESULT " + json.dumps(identity), self.project)


if __name__ == "__main__":
    unittest.main()
