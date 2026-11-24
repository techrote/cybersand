#!/usr/bin/env python3
"""Independent image/ACK and raw-prerequisite tamper controls, not GPU evidence."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import material_steps_oracle as oracle
from material_steps_status import ACCEPTED_SCOPE
from qualification_oracles import file_digest
from run_material_steps_comparison import correctness_prerequisite

SOURCE, DRIVER = "a" * 40, "opengl3"


class MaterialStepsOracle(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "source/godot"
        for relative in ("scripts/main.gd", "scripts/simulation_worker.gd", oracle.POLICY,
                         "scripts/full_image_ring_publisher.gd", "tests/support/ci_execution_policy.json",
                         oracle.FIXTURE[6:], "tests/test_material_steps_main_identity.gd"):
            path = self.project / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("synthetic-parser-control:" + relative)
        self.engine = self.root / "synthetic-engine"
        self.engine.write_bytes(b"synthetic, never executed")
        self.engine_hash = file_digest(self.engine)

    def receipt(self):
        result = {"schema": "pubpres-material-steps-main-history-v1", "checks": 32, "complete": True,
                  "failures": [], "source": SOURCE, "pid": 123, "driver": DRIVER, "render_thread_inline": True,
                  "synthetic_scheduling_clocks_and_completion_witness": True, "actual_rapier_steps": 0,
                  "performance_claim": False, "physical_credit": False,
                  "main_sha256": file_digest(self.project / "scripts/main.gd"),
                  "worker_sha256": file_digest(self.project / "scripts/simulation_worker.gd"),
                  "policy_sha256": file_digest(self.project / oracle.POLICY),
                  "publisher_sha256": file_digest(self.project / "scripts/full_image_ring_publisher.gd"),
                  "context": {"schema": "palette-qualification-context-v1", "source_revision": SOURCE,
                              "fixture": oracle.FIXTURE, "fixture_sha256": file_digest(self.project / oracle.FIXTURE[6:]),
                              "engine_sha256": self.engine_hash, "backend": DRIVER, "display_server": "X11", "platform": "Linux",
                              "godot": {"major": 4, "minor": 7}, "process_id": 123,
                              "execution_policy": {"ok": True, "schema_version": 1,
                                                   "path": "res://tests/support/ci_execution_policy.json",
                                                   "sha256": file_digest(self.project / "tests/support/ci_execution_policy.json")}},
                  "observations": [{**row, "current_verified": True, "previous_verified": True}
                                   for row in oracle.history_expectations()],
                  "transactions": oracle.transaction_expectations(50000)}
        for row in result["transactions"]:
            row["status"]["accepted_upload_scope"] = ACCEPTED_SCOPE
        return result

    def validate(self, data):
        return oracle.main_history_result("MATERIAL_STEPS_MAIN_RESULT " + json.dumps(data), SOURCE,
                                          self.project, DRIVER, engine_sha256=self.engine_hash)

    def headless(self):
        return [("test_material_publication_steps", "MATERIAL_STEPS_RESULT ",
                 {"schema": "pubpres-material-steps-policy-v1", "checks": 123, "complete": True, "failures": [],
                  "synthetic_clocks_and_steps": True, "physical_credit": False,
                  "policy_sha256": file_digest(self.project / oracle.POLICY)}),
                ("test_material_steps_main_identity", "MATERIAL_STEPS_IDENTITY_RESULT ",
                 {"schema": "pubpres-material-steps-main-identity-v1", "checks": 47, "complete": True, "failures": [],
                  "synthetic_identity_fields": True, "physical_credit": False, "native_edits_executed": 0,
                  "actual_rapier_steps": 0, "gpu_uploads": 0, "cancelled_cases": list(oracle.IDENTITY_CASES),
                  "main_sha256": file_digest(self.project / "scripts/main.gd"),
                  "fixture_sha256": file_digest(self.project / "tests/test_material_steps_main_identity.gd")})]

    def test_seven_current_previous_pairs_and_fourteen_real_ack_boundaries(self):
        result = self.validate(self.receipt())
        self.assertEqual(result["independent_validation"]["gpu_history_pairs"], 7)
        self.assertEqual(result["independent_validation"]["actual_rapier_steps"], 0)
        self.assertEqual(result["transactions"][-1]["acks"], [20, 24, 25, 30, 33, 34, 35])
        self.assertEqual(result["transactions"][6]["status"]["last_deadline_overrun_usec"], 1000)
        for test, marker, data in self.headless():
            oracle.headless_result(test, marker + json.dumps(data), self.project)

    def test_self_certified_pixels_fake_ack_fake_steps_and_wrong_sources_are_refused(self):
        faults = (
            ("fake_current", lambda d: d["observations"][1].update(current_sha256="0" * 64)),
            ("lost_previous24", lambda d: d["observations"][2].update(previous_sha256=d["observations"][2]["current_sha256"])),
            ("wrong_world", lambda d: d["observations"][3].update(uploaded_generation=42)),
            ("recovery_stale", lambda d: d["observations"][4].update(current_sha256=d["observations"][3]["current_sha256"])),
            ("skipped_ack", lambda d: d["transactions"][2]["acks"].append(22)),
            ("cancelled_ack", lambda d: d["transactions"][10]["acks"].append(31)),
            ("mutated_held_CPU", lambda d: d["transactions"][1].update(cpu_current_sha256=d["observations"][1]["current_sha256"])),
            ("renewed_deadline", lambda d: d["transactions"][3]["status"].update(deadline_usec=70000)),
            ("future_witness", lambda d: d["transactions"][4]["synthetic_witness"].update(completed_usec=60000)),
            ("lost_overrun", lambda d: d["transactions"][6]["status"].update(last_deadline_overrun_usec=0)),
            ("fake_cancel_count", lambda d: d["transactions"][10]["status"].update(cancellations=1)),
            ("lost_paused_escape", lambda d: d["transactions"][12]["status"].update(last_consumption_reason="completed_step_interval")),
            ("fake_absent_anchor", lambda d: d["transactions"][13]["status"].update(anchor_session_step=12, anchor_rapier_step=112)),
            ("boolean_step", lambda d: d.update(actual_rapier_steps=False)),
            ("fake_Rapier", lambda d: d["transactions"][4].update(actual_rapier_steps=2)),
            ("performance_credit", lambda d: d.update(performance_claim=True)),
            ("missing_pair", lambda d: d["observations"].pop()),
            ("missing_transaction", lambda d: d["transactions"].pop()),
            ("wrong_policy", lambda d: d.update(policy_sha256="0" * 64)),
            ("wrong_engine", lambda d: d["context"].update(engine_sha256="0" * 64)),
            ("wrong_owner", lambda d: d.update(render_thread_inline=False)),
        )
        for label, corrupt in faults:
            with self.subTest(label=label):
                data = self.receipt()
                corrupt(data)
                with self.assertRaises((ValueError, KeyError, TypeError)):
                    self.validate(data)

    def test_correctness_admission_replays_raw_logs_processes_and_all_three_fixtures(self):
        folder = self.root / "qualification"
        folder.mkdir()
        source = {"source_commit": SOURCE, "root": str(self.project.parent)}
        proof = {"outcomes": []}
        for test, marker, data in self.headless() + [("test_material_steps_main_history", "MATERIAL_STEPS_MAIN_RESULT ", self.receipt())]:
            target = folder / (test + "-slots2")
            target.mkdir()
            log = target / "stdout.log"
            log.write_text(marker + json.dumps(data) + "\n")
            graphic = test == "test_material_steps_main_history"
            command = [str(self.engine), "--path", str(folder / "project"),
                       *( ["--render-thread", "safe"] if graphic else ["--headless"] ),
                       "--script", "res://tests/" + test + ".gd"]
            process = {"command": command, "returncode": 0, "timed_out": False, "log_sha256": file_digest(log)}
            (target / "process.json").write_text(json.dumps(process))
            checked = self.validate(data) if graphic else oracle.headless_result(test, marker + json.dumps(data), self.project)
            proof["outcomes"].append({**process, "test": test, "slots": 2, "graphical": graphic, "valid": True, "evidence": checked})
        summary = folder / "SUMMARY.json"
        def write(): summary.write_text(json.dumps(proof))
        write()
        with patch("run_material_steps_comparison.existing_correctness_prerequisite", return_value={"base_gates_mocked_for_unit_test": True}):
            result = correctness_prerequisite(summary, source, {}, self.engine)
            self.assertEqual(len(result["count_prerequisites_replayed"]), 3)
            for label, mutate in (
                ("missing_GPU", lambda p: p["outcomes"].pop()),
                ("false_headless", lambda p: p["outcomes"][-1].update(graphical=False)),
                ("changed_summary_evidence", lambda p: p["outcomes"][-1]["evidence"].update(checks=31)),
                ("invented_process", lambda p: p["outcomes"][-1].update(command=["another-engine"])),
                ("lost_raw_hash", lambda p: p["outcomes"][-1].update(log_sha256="0" * 64)),
            ):
                original = copy.deepcopy(proof)
                mutate(proof)
                write()
                with self.subTest(label=label), self.assertRaises((ValueError, KeyError)):
                    correctness_prerequisite(summary, source, {}, self.engine)
                proof = original
            write()
            (folder / "test_material_steps_main_history-slots2/stdout.log").write_text("tampered raw receipt")
            with self.assertRaises(ValueError):
                correctness_prerequisite(summary, source, {}, self.engine)


if __name__ == "__main__":
    unittest.main()
