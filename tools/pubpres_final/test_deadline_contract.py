#!/usr/bin/env python3
"""Adversarial parser controls. Synthetic clocks never qualify runtime behavior."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

from deadline_contract import (COUNTERS, ROOT, validate_deadline_evidence, validate_status,
                               validate_deadline_cohort, verify_deadline_contract)
from run_deadline_comparison import correctness_prerequisite, deadline_campaign
from results import digest


def state(hz=30, offers=0, accepted=0, replaced=0, pending=-1):
    return {"schema": "pubpres-material-deadline-v1", "requested_hz": hz, "enabled": hz != 0,
            "interval_usec": {0: 0, 30: 33334, 60: 16667}[hz], "physical_credit": False,
            "offers": offers, "replaced_offers": replaced, "consumptions": accepted,
            "accepted_uploads": accepted, "cancellations": 0,
            "pending_count": int(pending > 0), "pending_serial": pending,
            "pending_generation": 42 if pending > 0 else -1,
            "deadline_usec": 174335 if pending > 0 else -1,
            "next_upload_usec": -1 if not accepted else 174335 if accepted == 1 else 214335}


def evidence(hz=30):
    begin, end = 100000, 1000000
    initial = {"serial": 10, "generation": 42, "generated_usec": 90000}
    uploads = [{"event": "texture_upload", "start_usec": 140000, "time_usec": 141000,
                "render_serial": 11, "world_generation": 42, "generated_usec": 120000},
               {"event": "texture_upload", "start_usec": 180000, "time_usec": 181000,
                "render_serial": 13, "world_generation": 42, "generated_usec": 150000}]
    before, after = state(hz), state(hz, 3, 2, 1) if hz else state(0)
    selector = {"requested": {"CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ": str(hz)},
                "material_deadline": before, "material_deadline_uploaded": initial}
    data = {"capture_start_usec": begin, "capture_end_usec": end, "case_nonce": "synthetic-parser-control",
            "source_identity": {"source_sha": "test-only-source"},
            "selectors_before": copy.deepcopy(selector), "selectors_after": copy.deepcopy(selector)}
    data["selectors_after"]["material_deadline"] = copy.deepcopy(after)
    end_material = {"serial": 13, "generation": 42, "generated_usec": 150000}
    header = {"event": "material_deadline_identity", "schema": "pubpres-material-deadline-observer-v1",
              "source": data["source_identity"], "case_nonce": data["case_nonce"],
              "capture_start_usec": begin, "capture_end_usec": end, "maximum_samples": 6000,
              "overflow": False, "samples": 4, "start_status": copy.deepcopy(before),
              "end_status": copy.deepcopy(after), "start_material": initial, "end_material": end_material}
    statuses = [state(hz, 1, 1), state(hz, 2, 1, 0, 12), state(hz, 3, 1, 1, 13), state(hz, 3, 2, 1)]
    rows, draws = [], []
    for index, clock in enumerate([145000, 160000, 170000, 185000]):
        serial, generated = (11, 120000) if index < 3 else (13, 150000)
        draw = {"event": "framebuffer_draw", "time_usec": clock, "process_frame": index + 10,
                "rendered_frames": index + 10, "inline_main": True, "render_serial": serial}
        draws.append(draw)
        rows.append({"event": "material_deadline_delivery", "time_usec": clock + 5,
                     "delivered_draw_usec": clock, "process_frame": index + 10, "rendered_frames": index + 10,
                     "inline_main": True, "draw_render_serial": serial, "uploaded_serial": serial,
                     "uploaded_generation": 42, "uploaded_generated_usec": generated, "observer_usec": 2,
                     "status": statuses[index] if hz else state(0)})
    steps = [{"event": "rapier_step", "step": index + 1, "time_usec": begin + (index + 1) * 6000}
             for index in range(144)]
    return data, uploads + draws + steps, header, rows


class DeadlineContract(unittest.TestCase):
    def setUp(self):
        self.registration = json.loads((ROOT / "tools/pubpres_final/deadline_registration.json").read_text())

    def test_unmodified_physical_oracle_and_three_independent_counterbalances(self):
        self.assertEqual(len(verify_deadline_contract()["frozen_v3_sha256"]), 64)
        self.assertEqual(self.registration["order"], [0, 30, 60, 60, 30, 0])
        self.assertEqual(self.registration["comparisons"],
                         {"off_vs_30_abba": [0, 1, 4, 5], "off_vs_60_abba": [0, 2, 3, 5],
                          "rate_30_vs_60_abba": [1, 2, 3, 4]})
        campaign = deadline_campaign(self.registration, ["wave_512_follow"])
        self.assertEqual(campaign["schema"], "pubpres-playability-campaign-v3")
        self.assertEqual(campaign["measurement"]["minimum_real_steps"], 144)
        with self.assertRaises(ValueError):
            deadline_campaign(self.registration, ["unregistered"])

    def test_coalescing_and_held_material_age_are_not_physical_steps(self):
        data, events, header, rows = evidence()
        value = validate_deadline_evidence(data, events, header, rows, 30)
        self.assertFalse(value["physical_credit"])
        self.assertEqual(value["capture_policy_counters"]["replaced_offers"], 1)
        whole = value["windows"]["whole_capture"]
        self.assertEqual(whole["actual_uploads"], 2)
        self.assertEqual(whole["pending_before_fixed_deadline_count"], 2)
        self.assertEqual(whole["material_generation_to_each_draw_delivery_ms"]["max"], 50)
        self.assertEqual(whole["upload_return_spacing_ms"]["max"], 40)
        self.assertGreater(value["windows"]["first_144_steps"]["policy_counter_trailing_unsampled_ms"], 0)
        self.assertEqual(whole["policy_counter_trailing_unsampled_ms"], 0)
        off = validate_deadline_evidence(*evidence(0), 0)
        self.assertTrue(all(off["capture_policy_counters"][key] == 0 for key in COUNTERS))
        self.assertEqual(off["windows"]["whole_capture"]["actual_uploads"], 2)

    def test_forged_schedule_and_material_observations_are_rejected(self):
        faults = (
            ("requested_rate", lambda d, e, h, r: d["selectors_before"]["requested"].update(CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="60")),
            ("effective_rate", lambda d, e, h, r: r[0]["status"].update(requested_hz=60)),
            ("physical_credit", lambda d, e, h, r: r[0]["status"].update(physical_credit=True)),
            ("unbounded_pending", lambda d, e, h, r: r[1]["status"].update(pending_count=2)),
            ("overflow", lambda d, e, h, r: h.update(overflow=True)),
            ("truncated", lambda d, e, h, r: r.pop()),
            ("wrong_capture", lambda d, e, h, r: h.update(case_nonce="another-capture")),
            ("wrong_source", lambda d, e, h, r: h.update(source={"source_sha": "another-source"})),
            ("fake_draw", lambda d, e, h, r: r[1].update(delivered_draw_usec=159999)),
            ("fake_frame", lambda d, e, h, r: r[1].update(process_frame=999)),
            ("fake_material_age", lambda d, e, h, r: r[1].update(uploaded_generated_usec=159000)),
            ("fake_uploaded_serial", lambda d, e, h, r: r[1].update(uploaded_serial=12)),
            ("foreign_pending_world", lambda d, e, h, r: r[1]["status"].update(pending_generation=43)),
            ("deadline_renewal", lambda d, e, h, r: r[2]["status"].update(deadline_usec=184335)),
            ("counter_regression", lambda d, e, h, r: r[2]["status"].update(offers=1)),
            ("lost_offer", lambda d, e, h, r: h["end_status"].update(offers=4)),
            ("hidden_cancellation", lambda d, e, h, r: h["end_status"].update(cancellations=1)),
            ("too_early_upload", lambda d, e, h, r: e[1].update(start_usec=150000)),
            ("too_few_actual_steps", lambda d, e, h, r: e.pop()),
            ("separate_draw_join", lambda d, e, h, r: r[0].update(inline_main=False)),
        )
        for name, corrupt in faults:
            with self.subTest(name=name):
                values = evidence()
                corrupt(*values)
                with self.assertRaises(ValueError):
                    validate_deadline_evidence(*values, 30)

    def test_interval_and_zero_suppression_are_exposed_without_a_speed_claim(self):
        value = validate_deadline_evidence(*evidence(60), 60)
        self.assertEqual(value["effective_interval_usec"], 16667)
        values = list(evidence())
        values[3][1]["status"]["deadline_usec"] = 150000
        values[3][2]["status"]["deadline_usec"] = 150000
        value = validate_deadline_evidence(*values, 30)
        self.assertEqual(value["windows"]["whole_capture"]["pending_overdue_at_draw_count"], 2)

    def test_new_status_fields_refuse_booleans_and_integral_floats(self):
        for field in ("requested_hz", "interval_usec", "pending_count", "pending_serial", "pending_generation",
                      "deadline_usec", "next_upload_usec", *COUNTERS):
            for value in (False, True, float(state()[field])):
                with self.subTest(field=field, value=value):
                    changed = state()
                    changed[field] = value
                    with self.assertRaises(ValueError):
                        validate_status(changed, 30)
        for field in ("time_usec", "delivered_draw_usec", "process_frame", "rendered_frames", "draw_render_serial",
                      "uploaded_serial", "uploaded_generation", "uploaded_generated_usec", "observer_usec"):
            with self.subTest(field=field):
                values = evidence()
                values[3][0][field] = float(values[3][0][field])
                with self.assertRaises(ValueError):
                    validate_deadline_evidence(*values, 30)

    def test_hardware_outcome_and_complete_order_are_still_required(self):
        arms = []
        for index, hz in enumerate(self.registration["order"]):
            selected = {"material_deadline": state(hz), "physics": "early", "presentation": "coherent",
                        "cadence": "repaired", "rendezvous": {"mode": "off"}}
            stats = {"source": "same-source", "match": {"cpu": "same-host", "water_law": "wave_flow_v1", "water_profile": "reference"},
                     "first_144_body_trajectory_sha256": "same-bodies", "first_144_admitted_moves_sha256": "same-input",
                     "command_counts": {"accepted": 200}, "command_mode": "repeated_callback",
                     "registered_material_treatment": {"backend": "full", "policy": ""},
                     "same_frame_continuation": {"enabled": False}, "selectors_before": selected, "selectors_after": selected,
                     "windows": {"first_144_steps": {"completed_rapier_steps": 144, "rapier_steps_per_second": 10,
                                  "physical_gap_ms": {"p95": 100, "p99": 200, "max": 300}}},
                     "physical_gap_counts_above_ms": {"first_144_steps": {"100": 20, "250": 2, "500": 0, "1000": 0}}}
            arms.append({"arm": "C", "index": index, "requested_hz": hz, "statistics": stats,
                         "deadline": {"requested_hz": hz, "physical_credit": False},
                         "slots": {"requested_slots": 2, "effective_slots_verified": True},
                         "observers": {"presentation_enabled": True, "presentation": {}, "cpu": {}}})
        result = validate_deadline_cohort(arms, self.registration)
        self.assertEqual(result["physical_acceptance"], "HOLD")
        self.assertTrue(all(not value["repeatable_direction"] for value in result["registered_directions"].values()))
        for name, corrupt in (
            ("hardware", lambda a: a[2]["statistics"]["match"].update(cpu="other-host")),
            ("source", lambda a: a[2]["statistics"].update(source="other-source")),
            ("physical_outcome", lambda a: a[2]["statistics"].update(first_144_body_trajectory_sha256="other-bodies")),
            ("material_backend", lambda a: a[2]["statistics"]["registered_material_treatment"].update(backend="blit")),
            ("missing_arm", lambda a: a.pop()),
            ("reordered_rate", lambda a: a[1].update(requested_hz=60)),
            ("other_slots", lambda a: a[2]["slots"].update(requested_slots=3)),
            ("disabled_pose_observer", lambda a: a[2]["observers"].update(presentation_enabled=False)),
            ("missing_pose_sidecar", lambda a: a[2]["observers"].update(presentation=None)),
            ("missing_cpu_sidecar", lambda a: a[2]["observers"].update(cpu=None)),
        ):
            with self.subTest(name=name):
                changed = copy.deepcopy(arms)
                corrupt(changed)
                with self.assertRaises(ValueError):
                    validate_deadline_cohort(changed, self.registration)

    def test_graphical_prerequisites_are_bound_to_exact_source_engine_and_both_histories(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            engine = folder / "synthetic-engine"
            engine.write_bytes(b"test-only engine identity")
            identity = {"source_commit": "candidate", "source_tree": "tree"}
            source = {**identity, "native_runtime": {"binary_sha256": "runtime", "manifest_sha256": "manifest"}}
            graphical = {"test_material_deadline_main_history", "test_full_image_ring_publication",
                         "pubpres_full_image_ring_oracle", "test_full_image_ring_main_recovery"}
            outcomes = [{"test": name, "slots": slots, "valid": True, "graphical": name in graphical}
                        for name, slots in [("test_material_publication_deadline", 2), ("test_material_deadline_main_identity", 2),
                                            ("test_material_deadline_main_history", 2), ("test_material_deadline_main_history", 3),
                                            ("test_physical_actor_integration", 2), ("test_workbench_physics_publication", 2),
                                            ("test_full_image_ring_publication", 3), ("pubpres_full_image_ring_oracle", 3),
                                            ("test_full_image_ring_main_recovery", 3)]]
            proof = {"schema": "pubpres-playability-final-correctness-v1", "complete": True, "headless_only": False,
                     "physical_acceptance": "HOLD", "source": identity, "driver": identity,
                     "native": source["native_runtime"], "engine_sha256": digest(engine),
                     "import_source_mutations": [], "final_source_mutations": [], "outcomes": outcomes}
            path = folder / "summary.json"
            path.write_text(json.dumps(proof))
            self.assertTrue(correctness_prerequisite(path, source, identity, engine)["complete"])
            for name, corrupt in (
                ("headless", lambda p: p.update(headless_only=True)),
                ("other_engine", lambda p: p.update(engine_sha256="other")),
                ("other_source", lambda p: p["source"].update(source_commit="other")),
                ("invalid_result", lambda p: p["outcomes"][0].update(valid=False)),
                ("missing_gpu_pair", lambda p: p["outcomes"].pop(3)),
                ("missing_original_transition", lambda p: p["outcomes"].pop(7)),
                ("source_mutation", lambda p: p["final_source_mutations"].append("main.gd")),
            ):
                with self.subTest(name=name):
                    changed = copy.deepcopy(proof)
                    corrupt(changed)
                    path.write_text(json.dumps(changed))
                    with self.assertRaises(ValueError):
                        correctness_prerequisite(path, source, identity, engine)


if __name__ == "__main__":
    unittest.main()
