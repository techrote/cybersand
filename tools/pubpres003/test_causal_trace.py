#!/usr/bin/env python3
"""Synthetic causal joins; no native work or performance claim is implied."""
import copy
from pathlib import Path
import subprocess
import tempfile
import unittest

from causal_trace import analyze
from run_focus import PREDECESSOR_DRIVER_INPUTS, planned_arms, selectors, verify_driver


def fixture():
    identity = {"enabled": True, "main_overflow": False, "worker_dropped": 0,
                "main_capacity": 30_000, "worker_capacity": 8192}
    receipt = {"physical_owner_before": {"epoch": 1, "session": 1}}
    packet = {"observer_owner": "main", "current_epoch": 1, "current_session": 1,
              "world_generation": 3, "packet_session": 1, "rigid_body_epoch": 1,
              "tick_index": 1, "completed_body_sample": 2, "requested_sample": 2,
              "required_hard_revision": 9, "packet_hard_revision": 9, "packet_present": True,
              "simulation_failed": False, "native_refusal": "", "origin_callback_id": 11,
              "physical_tick": 0, "manual_steps_before": 0}
    producer = {"observer_owner": "worker", "world_generation": 3, "session": 1,
                "rigid_body_epoch": 1, "tick_index": 1, "body_sample": 2, "required_hard_revision": 9}
    rows = [
        {**producer, "kind": "native_tick", "start_usec": 1500, "completed_usec": 2000},
        {**producer, "kind": "physics_publication", "packet_hard_revision": 9,
         "start_usec": 2050, "completed_usec": 2100},
        {**packet, "event": "mailbox_observation", "start_usec": 2200, "time_usec": 2300, "status": "ready"},
        {**packet, "event": "terrain_install", "start_usec": 2310, "time_usec": 2400,
         "operation": "check", "ready": True, "pending_after": 0, "queued_revision_after": 9},
        {**packet, "event": "transaction_entry", "start_usec": 2409, "time_usec": 2410,
         "pending_hard_chunks": 0, "native_and_terrain_gate_passed": True},
    ]
    steps = [{"event": "rapier_step", "world_generation": 3, "session": 1, "epoch": 1,
              "native_tick_used": 1, "completed_body_sample": 2, "required_hard_revision": 9,
              "step": 1, "manual_steps": 1, "time_usec": 3300, "native_completed_usec": 2000,
              "origin_callback_id": 11, "process_frame": 22}]
    return identity, rows, receipt, steps


class CausalEvidenceTests(unittest.TestCase):
    def test_full_transaction_has_separate_delivery_observation_and_terrain_costs(self):
        result = analyze(*fixture())
        self.assertEqual(result["actual_completed_rapier_steps"], 1)
        self.assertEqual(result["matched_native_to_rapier_transactions"], 1)
        row = result["transactions"][0]
        self.assertEqual(row["native_compute_ms"], .5)
        self.assertEqual(row["native_complete_to_publish_ms"], .1)
        self.assertEqual(row["published_to_observed_ms"], .2)
        self.assertEqual(row["observed_until_terrain_ready_ms"], .1)
        self.assertEqual(row["transaction_to_completion_ms"], .89)

    def test_later_status_publication_does_not_reset_readiness_age(self):
        identity, rows, receipt, steps = fixture()
        rows.append({**rows[1], "start_usec": 2180, "completed_usec": 2190})
        self.assertEqual(analyze(identity, rows, receipt, steps)["transactions"][0]["first_healthy_publication_usec"], 2100)

    def test_gate_entry_without_real_completion_does_not_gain_step_credit(self):
        identity, rows, receipt, steps = fixture()
        rows.append({**rows[-1], "physical_tick": 7, "manual_steps_before": 7})
        result = analyze(identity, rows, receipt, steps)
        self.assertEqual(result["actual_completed_rapier_steps"], 1)
        self.assertEqual(result["transaction_entries_without_completion"], 1)
        rows[-1]["admitted"] = True
        with self.assertRaisesRegex(ValueError, "cannot claim"):
            analyze(identity, rows, receipt, steps)

    def test_no_completed_steps_cannot_be_replaced_by_transaction_entries(self):
        identity, rows, receipt, _ = fixture()
        with self.assertRaisesRegex(ValueError, "cannot substitute"):
            analyze(identity, rows, receipt, [])

    def test_duplicate_completion_cannot_reuse_entry_credit(self):
        identity, rows, receipt, steps = fixture()
        with self.assertRaisesRegex(ValueError, "reused"):
            analyze(identity, rows, receipt, steps + copy.deepcopy(steps))

    def test_wrong_owner_sample_terrain_and_callback_refuse_join(self):
        for field in ("world_generation", "packet_session", "rigid_body_epoch",
                      "completed_body_sample", "required_hard_revision", "origin_callback_id",
                      "manual_steps_before", "physical_tick"):
            with self.subTest(field=field):
                identity, rows, receipt, steps = fixture()
                rows[-1][field] = 999
                with self.assertRaises(ValueError):
                    analyze(identity, rows, receipt, steps)

    def test_queued_terrain_is_not_installed_terrain(self):
        identity, rows, receipt, steps = fixture()
        rows[3]["pending_after"] = 1
        with self.assertRaisesRegex(ValueError, "completed matching install"):
            analyze(identity, rows, receipt, steps)

    def test_failure_or_future_producer_timestamp_is_refused(self):
        for field, value in (("simulation_failed", True), ("native_refusal", "fault")):
            identity, rows, receipt, steps = fixture()
            rows[-1][field] = value
            with self.assertRaises(ValueError):
                analyze(identity, rows, receipt, steps)
        identity, rows, receipt, steps = fixture()
        rows[0]["completed_usec"] = 2200
        with self.assertRaisesRegex(ValueError, "chronology differs"):
            analyze(identity, rows, receipt, steps)

    def test_disabled_or_overflowed_observer_is_not_accepted_as_enabled(self):
        identity, rows, receipt, steps = fixture()
        identity["enabled"] = False
        with self.assertRaisesRegex(ValueError, "Disabled"):
            analyze(identity, rows, receipt, steps)
        self.assertFalse(analyze(identity, [], receipt, steps)["enabled"])
        identity["enabled"] = True
        identity["worker_dropped"] = 1
        with self.assertRaisesRegex(ValueError, "overflow"):
            analyze(identity, rows, receipt, steps)


class FocusedDesignTests(unittest.TestCase):
    def test_driver_binds_committed_code_and_refuses_dirty_or_untracked_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            def git(*args):
                return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.PIPE)
            git("init", "-q", "--initial-branch=fixture")
            for relative in (*PREDECESSOR_DRIVER_INPUTS, "tools/pubpres003/run_focus.py"):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("# synthetic driver provenance adversary\n")
            git("add", ".")
            git("-c", "user.name=PUBPRES test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture")
            record = verify_driver(root)
            self.assertEqual(record["source_commit"], git("rev-parse", "HEAD").decode().strip())
            path = root / "tools/pubpres003/untracked.py"
            path.write_text("# untracked executable input\n")
            with self.assertRaisesRegex(ValueError, "untracked"):
                verify_driver(root)
            path.unlink()
            (root / PREDECESSOR_DRIVER_INPUTS[0]).write_text("# altered imported oracle\n")
            with self.assertRaisesRegex(ValueError, "differs from committed"):
                verify_driver(root)

    def test_native_probe_and_continuation_have_independent_balanced_orders(self):
        for mode, key in (("native-probe-abba", "wave_column_probe"),
                          ("same-frame-abba", "same_frame_continuation"),
                          ("causal-overhead-abba", "causal")):
            with self.subTest(mode=mode):
                arms = planned_arms(mode)
                self.assertEqual([a[key] for a in arms], [False, True, True, False])
                other = [{k: v for k, v in a.items() if k != key} for a in arms]
                self.assertTrue(all(a == other[0] for a in other))

    def test_baseline_does_not_enable_causal_or_old_optional_interventions(self):
        arm = planned_arms("baseline")[0]
        self.assertTrue(all(v is False for v in arm.values()))
        settings = selectors(arm, "nonce")
        self.assertEqual(settings["CYBERSAND_DIAG_MATERIAL_POOL_POLICY"], "eager")
        self.assertEqual(settings["CYBERSAND_PLAYABILITY_RENDER_THREAD"], "safe")
        self.assertEqual(settings["CYBERSAND_DIAG_NATIVE_RENDEZVOUS"], "0")
        self.assertEqual(settings["CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES"], "0")


if __name__ == "__main__":
    unittest.main()
