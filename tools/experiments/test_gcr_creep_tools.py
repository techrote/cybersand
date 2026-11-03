"""Adversarial evidence-reader and accounting checks for the creep apparatus."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from analyze_gcr_creep import (EvidenceError, actuator_sample_gap, application_summary, conservation,
                               paired_comparisons, read, reduce_capture, summarize_rows, validate_capture,
                               validate_measured_controller_delivery)


class CreepTools(unittest.TestCase):
    def fixture(self):
        spec = {"id": "test-barrel", "kind": "barrel", "material": 2, "drive": "pulse", "ticks": 6}
        identity = {"source": "1" * 40, "source_inputs_sha256": "4" * 64,
                    "platforms": {"windows": {"native_sha256": "2" * 64, "engine_sha256": "3" * 64}}}
        protocol_hash = "5" * 64
        protocol = {"pulse_start": 2, "pulse_end": 4, "drive_end": 5,
                    "fixture_barrel": {"mass": 1}, "windows": {"tail": [4, 6]}}
        rows = []
        for tick in range(6):
            body = {"session": 2, "index": 0, "sample": tick + 1, "age": 0,
                    "actual_mass": 1, "actual_inertia": 2, "correction": [0, -.01],
                    "correction_potential_delta": .9212, "zeroing_removed_energy": .5,
                    "kinetic_after_zeroing": 0, "kinetic_after_wrench": .5,
                    "velocity_after_zeroing": [0, 0], "velocity_after_wrench": [0, -1],
                    "omega_after_zeroing": 0, "omega_after_wrench": .5,
                    "impulse": [0, -1], "angular_impulse": 1}
            rows.append({"tick": tick, "position": [tick * .1, 0], "rotation": 0,
                         "velocity": [.1, 0], "omega": 0,
                         "command_active": 2 <= tick < 4,
                         "drive_phase": "quiet" if tick < 2 else "driven" if tick < 4 else "released",
                         "input_action": {"move": [0, -1] if 2 <= tick < 4 else [0, 0]},
                         "controller": {"applied_force": [0, 0], "applied_torque": 0,
                                        "actual_impulse": [0, 0], "actual_torque_impulse": 0},
                         "application": {"accepted": True, "snapshot": tick + 1, "bodies": [body]},
                         "application_step": {"version": 1, "physics_call": tick,
                                              "snapshot_before": tick if tick else -1,
                                              "snapshot_after": tick + 1, "delivered_this_step": True},
                         "gcr": {"active_capacity_limiter": "source"},
                         "rest_receipt": {"mode": "control", "base_budget": 20},
                         "pre_overlap": 0, "post_overlap": 0, "material_count": 8,
                         "water": 0, "conserved": True, "hard_floor_contact": False, "hard_clearance": True})
        census = {"counts": [90, 2, 8, 0], "water_mass": 0, "failed": False}
        raw = {"schema": 1, "case": spec, "platform": "Windows", "ok": True, "errors": [],
               "dt": 1 / 60, "actual_mass": 1, "actual_inertia": 2, "gravity": 92.12,
               "before": copy.deepcopy(census), "after": copy.deepcopy(census),
               "identity": {"source": "1" * 40, "native_sha256": "2" * 64,
                            "engine_sha256": "3" * 64, "input_identity": "4" * 64,
                            "protocol_sha256": protocol_hash, "physics_backend": "Rapier2D",
                            "engine_version": "4.7-stable (official)"}, "rows": rows}
        return raw, spec, identity, protocol_hash, protocol

    def reduce(self, raw=None):
        default, spec, identity, protocol_hash, protocol = self.fixture()
        return reduce_capture(default if raw is None else raw, spec, identity, protocol_hash, "windows", protocol)

    def test_complete_capture_and_delivered_closure(self):
        result = self.reduce()
        self.assertEqual(result["status"], "complete_observation")
        self.assertEqual(result["full_window"]["applications"]["unique_accepted_applications"], 6)
        self.assertEqual(result["full_window"]["applications"]["delivered_delta_v_error_max"], 0)
        self.assertEqual(result["full_window"]["applications"]["delivered_delta_omega_error_max"], 0)
        self.assertTrue(result["conservation"]["exact"])

    def test_duplicate_json_keys_refuse(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "duplicate.json"
            path.write_text('{"ok":false,"ok":true}')
            with self.assertRaises(EvidenceError):
                read(path)

    def test_nonfinite_json_constants_and_exponent_overflow_refuse(self):
        for value in ("NaN", "Infinity", "-Infinity", "1e999"):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "value.json"
                path.write_text('{"value":' + value + '}')
                with self.assertRaises(EvidenceError):
                    read(path)

    def test_partial_capture_is_not_a_zero_result(self):
        raw, *_ = self.fixture()
        raw["rows"].pop()
        with self.assertRaisesRegex(EvidenceError, "Incomplete"):
            self.reduce(raw)

    def test_failed_capture_is_not_reduced(self):
        raw, *_ = self.fixture()
        raw["ok"] = False
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_retained_error_refuses_even_if_ok_is_true(self):
        raw, *_ = self.fixture()
        raw["errors"] = ["failed conservation"]
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_repeated_or_reordered_ticks_refuse(self):
        for value in (0, 3, -1, True):
            raw, *_ = self.fixture()
            raw["rows"][1]["tick"] = value
            with self.subTest(value=value), self.assertRaises(EvidenceError):
                self.reduce(raw)

    def test_input_identity_and_runtime_are_external_bindings(self):
        for key in ("source", "protocol_sha256", "native_sha256", "engine_sha256", "input_identity"):
            raw, *_ = self.fixture()
            raw["identity"][key] = "0" * len(raw["identity"][key])
            with self.subTest(key=key), self.assertRaises(EvidenceError):
                self.reduce(raw)

    def test_changed_case_refuses(self):
        raw, *_ = self.fixture()
        raw["case"] = dict(raw["case"], material=23)
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_wrong_backend_refuses(self):
        raw, *_ = self.fixture()
        raw["identity"]["physics_backend"] = "GodotPhysics2D"
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_boolean_position_is_not_a_number(self):
        raw, *_ = self.fixture()
        raw["rows"][0]["position"][0] = True
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_command_schedule_must_match_registration(self):
        raw, *_ = self.fixture()
        raw["rows"][0]["command_active"] = True
        with self.assertRaisesRegex(EvidenceError, "command interval"):
            self.reduce(raw)

    def test_native_response_law_and_budget_must_remain_control(self):
        for change in ({"mode": "R"}, {"base_budget": 40}):
            raw, *_ = self.fixture()
            raw["rows"][0]["rest_receipt"].update(change)
            with self.subTest(change=change), self.assertRaises(EvidenceError):
                self.reduce(raw)

    def test_mass_authoring_change_refuses(self):
        raw, *_ = self.fixture()
        raw["actual_mass"] = .5
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_forged_new_delivery_refuses(self):
        raw, *_ = self.fixture()
        raw["rows"][1]["application_step"]["snapshot_before"] = -1
        with self.assertRaisesRegex(EvidenceError, "marker"):
            self.reduce(raw)

    def test_duplicate_sample_claimed_as_new_refuses(self):
        raw, *_ = self.fixture()
        raw["rows"][1]["application"]["bodies"][0]["sample"] = 1
        with self.assertRaisesRegex(EvidenceError, "more than once"):
            self.reduce(raw)

    def test_held_receipts_never_inflate_application_population(self):
        raw, *_ = self.fixture()
        row = raw["rows"][0]
        held = copy.deepcopy(row)
        held["application_step"]["delivered_this_step"] = False
        summary = application_summary([row, held])
        self.assertEqual(summary["unique_accepted_applications"], 1)
        self.assertEqual(summary["missing_measurement_observations"]["accepted_but_not_new_this_step"], 1)

    def test_neutral_controller_drag_is_not_zero_actuation(self):
        raw, *_ = self.fixture()
        for row in raw["rows"]:
            row["controller"]["applied_force"] = [-.2, 0]
        summary = self.reduce(raw)["full_window"]
        self.assertEqual(summary["no_command_observations"], 4)
        self.assertEqual(summary["zero_reported_output_no_command_observations"], 0)
        self.assertAlmostEqual(summary["controller_linear_impulse_sum"][0], -.02)

    def test_missing_primary_actuation_refuses(self):
        for key in ("applied_force", "applied_torque", "actual_impulse", "actual_torque_impulse"):
            raw, *_ = self.fixture()
            raw["rows"][0]["controller"][key] = None
            with self.subTest(key=key), self.assertRaisesRegex(EvidenceError, "primary actuation"):
                self.reduce(raw)

    def test_missing_overlap_stays_unmeasured(self):
        raw, *_ = self.fixture()
        for row in raw["rows"]:
            row["post_overlap"] = None
        summary = self.reduce(raw)["full_window"]
        self.assertIsNone(summary["post_overlap_max"])

    def test_missing_energy_stays_null_not_zero(self):
        raw, *_ = self.fixture()
        for row in raw["rows"]:
            del row["application"]["bodies"][0]["zeroing_removed_energy"]
        summary = self.reduce(raw)["full_window"]["applications"]
        self.assertIsNone(summary["zeroing_removed_energy_sum"])
        self.assertEqual(summary["missing_measurement_observations"]["zeroing_removed_energy"], 6)

    def test_water_occupancy_may_change_if_exact_quantity_is_conserved(self):
        raw, *_ = self.fixture()
        raw["before"]["counts"] = [88, 2, 8, 2]
        raw["before"]["water_mass"] = 255
        raw["after"]["counts"] = [89, 2, 8, 1]
        raw["after"]["water_mass"] = 255
        self.assertTrue(self.reduce(raw)["conservation"]["exact"])

    def test_one_lost_water_quantum_refuses(self):
        raw, *_ = self.fixture()
        raw["before"]["water_mass"] = 255
        raw["after"]["water_mass"] = 254
        with self.assertRaisesRegex(EvidenceError, "Water quantity"):
            self.reduce(raw)

    def test_unexplained_material_change_refuses(self):
        raw, *_ = self.fixture()
        raw["after"]["counts"] = [91, 2, 7, 0]
        with self.assertRaisesRegex(EvidenceError, "material change"):
            self.reduce(raw)

    def test_claimed_conservation_without_raw_boundary_counts_refuses(self):
        raw, *_ = self.fixture()
        raw["after"] = {}
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_hard_contact_is_retained_as_a_confound(self):
        raw, *_ = self.fixture()
        raw["rows"][3]["hard_floor_contact"] = True
        result = self.reduce(raw)
        self.assertEqual(result["full_window"]["hard_floor_contact_observations"], 1)
        self.assertNotIn("rest_accepted", result)

    def test_actual_impulse_is_separate_from_requested_force_integral(self):
        raw, *_ = self.fixture()
        for row in raw["rows"]:
            row["controller"]["applied_force"] = [1, 0]
            row["controller"]["actual_impulse"] = [.01, 0]
            row["controller"]["actual_torque_impulse"] = .02
        result = self.reduce(raw)["full_window"]
        self.assertAlmostEqual(result["rig_reported_linear_impulse_sum"][0], .06)
        self.assertAlmostEqual(result["controller_linear_impulse_sum"][0], .1)
        self.assertAlmostEqual(result["rig_reported_impulse_vs_force_dt_error_max"], 1 / 60 - .01)
        self.assertAlmostEqual(result["rig_reported_angular_impulse_sum"], .12)

    def test_census_population_matches_registered_domain(self):
        raw, *_ = self.fixture()
        with self.assertRaisesRegex(EvidenceError, "registered domain"):
            conservation(raw, expected_population=200)

    def test_zero_negative_control_requires_complete_computed_coverage(self):
        raw, *_ = self.fixture()
        for row in raw["rows"]:
            row["gcr"].update(normal_accepted=0, tangent_accepted=0)
        self.assertTrue(self.reduce(raw)["full_window"]["computed_granular_normal_tangent_zero"])
        del raw["rows"][0]["gcr"]["normal_accepted"]
        self.assertIsNone(self.reduce(raw)["full_window"]["computed_granular_normal_tangent_zero"])

    def test_pairing_uses_matched_baseline_and_keeps_hard_contact(self):
        candidate = self.reduce()
        candidate["case"] = candidate["spec"]["id"] = "barrel-sand-pulse"
        baseline = copy.deepcopy(candidate)
        baseline["case"] = baseline["spec"]["id"] = "barrel-sand-passive"
        baseline["spec"]["drive"] = "passive"
        baseline["registered_windows"]["tail"]["motion"]["net_translation"][0] = 0
        candidate["registered_windows"]["tail"]["hard_floor_contact_observations"] = 1
        pairs = paired_comparisons([baseline, candidate])
        self.assertEqual(len(pairs), 1)
        difference = pairs[0]["registered_window_differences"]["tail"]
        self.assertAlmostEqual(difference["net_translation_difference"][0], .1)
        self.assertEqual(difference["hard_floor_contact_observations"], {"baseline": 0, "candidate": 1})

    def test_schema_boolean_is_not_a_version(self):
        raw, *_ = self.fixture()
        raw["schema"] = True
        with self.assertRaises(EvidenceError):
            self.reduce(raw)

    def test_boolean_case_number_does_not_match_numeric_protocol(self):
        raw, spec, identity, protocol_hash, _ = self.fixture()
        spec = dict(spec, material=1)
        raw["case"] = dict(spec, material=True)
        with self.assertRaisesRegex(EvidenceError, "Executed case"):
            validate_capture(raw, spec, identity, protocol_hash, "windows")

    def test_boolean_marker_integer_refuses(self):
        raw, *_ = self.fixture()
        raw["rows"][1]["application_step"]["physics_call"] = True
        with self.assertRaisesRegex(EvidenceError, "marker integers"):
            self.reduce(raw)

    def test_matching_sample_gap_is_compared_to_actual_controller_impulse(self):
        raw, *_ = self.fixture()
        row = raw["rows"][0]
        row["rest_receipt"]["bodies"] = [{"session": 2, "sample": 1, "sample_velocity": [1, 2], "sample_omega": .2}]
        row["controller"].update(actual_impulse=[.1, 0], actual_torque_impulse=.04)
        row["application"]["bodies"][0].update(velocity_before_correction=[1.1, 2], omega_before_correction=.22)
        gap = actuator_sample_gap([row])
        self.assertEqual(gap["linear_observations"], 1)
        self.assertAlmostEqual(gap["sample_to_application_delta_v_max"], .1)
        self.assertAlmostEqual(gap["gap_minus_rig_reported_controller_delta_v_error_max"], 0)
        self.assertAlmostEqual(gap["gap_minus_rig_reported_controller_delta_omega_error_max"], 0)

    def test_mismatched_native_sample_cannot_supply_phase_attribution(self):
        raw, *_ = self.fixture()
        row = raw["rows"][0]
        row["rest_receipt"]["bodies"] = [{"session": 2, "sample": 77, "sample_velocity": [0, 0], "sample_omega": 0}]
        gap = actuator_sample_gap([row])
        self.assertEqual(gap["linear_observations"], 0)
        self.assertIsNone(gap["sample_to_application_delta_v_max"])

    def measured_row(self):
        raw, *_ = self.fixture()
        row = raw["rows"][0]
        row["rest_receipt"]["bodies"] = [{"session": 2, "sample": 1, "sample_velocity": [1, 2], "sample_omega": .2}]
        row["application"]["bodies"][0].update(velocity_before_correction=[1.1, 2], omega_before_correction=.22)
        row["controller"].update(actual_impulse=[.1, 0], actual_torque_impulse=.04,
                                 measured_controller_impulse=[.1, 0], measured_controller_torque_impulse=.04,
                                 rig_reported_impulse=[.11, 0], rig_reported_torque_impulse=.05,
                                 impulse_measurement="same-phase-backend-velocity-difference",
                                 force_measurement="controller-request", measurement_valid=True, movement_limited=False)
        row["controller_delivery"] = {"measured": True, "method": "same-phase-backend-velocity-difference",
                                      "sample": 1, "session": 2, "impulse": [.1, 0], "torque_impulse": .04}
        return row

    def test_flat_delivery_is_recomputed_from_independent_stage_values(self):
        row = self.measured_row()
        validate_measured_controller_delivery([row], 1e-5)
        row["controller"]["actual_impulse"] = row["controller"]["measured_controller_impulse"] = [.2, 0]
        with self.assertRaisesRegex(EvidenceError, "backend velocity stages"):
            validate_measured_controller_delivery([row], 1e-5)

    def test_flat_old_rig_report_cannot_be_relabelled_as_measured(self):
        row = self.measured_row()
        del row["controller"]["impulse_measurement"]
        with self.assertRaisesRegex(EvidenceError, "measurement method"):
            validate_measured_controller_delivery([row], 1e-5)

    def test_flat_delivery_requires_current_matching_sample(self):
        row = self.measured_row()
        row["controller_delivery"]["sample"] = 77
        with self.assertRaisesRegex(EvidenceError, "different native sample"):
            validate_measured_controller_delivery([row], 1e-5)

    def test_stale_velocity_stages_cannot_measure_controller_delivery(self):
        row = self.measured_row()
        row["application"]["bodies"][0]["age"] = 1
        with self.assertRaisesRegex(EvidenceError, "different native sample"):
            validate_measured_controller_delivery([row], 1e-5)

    def test_zero_reported_output_is_separate_from_zero_backend_impulse(self):
        row = self.measured_row()
        row["controller"]["applied_force"] = [.0001, 0]
        row["application"]["bodies"][0].update(velocity_before_correction=[1, 2], omega_before_correction=.2)
        summary = summarize_rows([row], 1 / 60, "flyer")
        self.assertEqual(summary["zero_reported_output_no_command_observations"], 0)
        self.assertEqual(summary["zero_measured_backend_impulse_no_command_observations"], 1)


if __name__ == "__main__":
    unittest.main()
