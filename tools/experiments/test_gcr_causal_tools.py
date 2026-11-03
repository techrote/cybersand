"""Adversarial checks for the two preregistered causal GCR lanes."""
import copy
import unittest

import analyze_gcr_causal as causal
import test_gcr_creep_tools as previous


class CausalTools(unittest.TestCase):
    def row(self, arm="C", kind="flyer", drive="sustained"):
        raw, _, _, _, _ = previous.CreepTools().fixture()
        row = raw["rows"][0]
        body = row["application"]["bodies"][0]
        body.update(current_origin=[0, 1], actual_mass=.1, actual_inertia=.975)
        before = dict(position=[0, 1], rotation=0, velocity=[0, 0], omega=0)
        after = dict(position=[0, 1], rotation=0, velocity=[.2, 0], omega=.1)
        impulse, torque = [.02, 0], .0975
        if drive == "unactuated" or kind == "barrel":
            after = copy.deepcopy(before)
            impulse, torque = [0, 0], 0
        row["controller"].update(actual_impulse=impulse, actual_torque_impulse=torque,
            impulse_measurement="direct-actuation-stage-backend-velocity-difference", measurement_valid=True,
            movement_limited=False)
        counter = dict(native_tick=0, rapier_steps=0, session_tick=0, packed_sample=0,
                       last_applied_sample=-1, last_snapshot=-1, rig_tick=0)
        end = dict(native_tick=1, rapier_steps=1, session_tick=1, packed_sample=1,
                   last_applied_sample=1, last_snapshot=1, rig_tick=1 if kind == "flyer" else 0)
        sample = dict(count=1, session=2, serial=1, phase="after-actuation" if arm == "T" else "before-actuation",
                      **copy.deepcopy(after if arm == "T" else before))
        actuator = dict(count=1 if kind == "flyer" else 0, before=before, after=after, actual_mass=.1,
                       actual_inertia=.975, actual_impulse=impulse, actual_torque_impulse=torque,
                       pose_unchanged=True, rig_tick_before=0, rig_tick_after=end["rig_tick"], advance_call_count=1)
        row["causal_phase"] = dict(arm=arm, counts=dict(actuation=actuator["count"], sample=1, native_tick=1,
            rapier_step=1, response_calls=1), counter_before=counter, counter_after=end,
            observed_session_tick_delta=1, fresh_sample_applied=True, actuation=actuator, sample=sample)
        setter = dict(accepted=True, arm=arm, sample=1, session=2, proposed_correction=[0, -.01],
            observed_translation=[0, -.01], pre_response_origin=[0, 1], after_response_origin=[0, .99],
            final_origin=[0, 1] if arm == "X" else [0, .99], applied_translation=[0, .01] if arm == "X" else [0, 0],
            inverse_translation=[0, .01] if arm == "X" else [0, 0], setter_count=int(arm in ("S", "X")),
            velocity_before_setter=[0, -1], velocity_after_setter=[0, -1], omega_before_setter=.5, omega_after_setter=.5,
            retained_angular_impulse=1, proposed_c_cross_J=0, observed_c_cross_J=0,
            counterfactual_no_correction_bridge_angular_impulse=1, offset_potential_delta=-.09212 if arm == "X" else 0,
            observed_bridge_potential_delta=.09212, rotation_before_setter=0, rotation_after_setter=0, rotation_roundtrip_delta=0)
        row["causal_phase"]["correction_setter"] = setter
        spec = dict(id="flat-sand-sustained-"+arm, kind=kind, drive=drive, arm=arm, geometry="flat", material=2)
        return row, spec

    def test_direct_actuation_and_both_sample_orders(self):
        for arm in ("C", "T", "S", "X"):
            row, spec = self.row(arm)
            causal.validate_phase(row, spec, causal.TC, 1e-5)

    def test_old_sample_gap_is_not_delivery_in_T(self):
        row, spec = self.row("T")
        self.assertEqual(row["causal_phase"]["sample"]["velocity"], [.2, 0])
        self.assertEqual(row["controller"]["actual_impulse"], [.02, 0])
        causal.validate_phase(row, spec, causal.TC, 1e-5)
        row["controller"]["actual_impulse"] = [0, 0]
        with self.assertRaisesRegex(causal.EvidenceError, "aliases"):
            causal.validate_phase(row, spec, causal.TC, 1e-5)

    def test_incorrect_sample_order_refuses(self):
        row, spec = self.row("T")
        row["causal_phase"]["sample"]["velocity"] = [0, 0]
        with self.assertRaisesRegex(causal.EvidenceError, "ordering"):
            causal.validate_phase(row, spec, causal.TC, 1e-5)

    def test_forged_clock_stage_and_receipt_refuse(self):
        for section, key in (("counter_after", "native_tick"), ("counter_after", "rapier_steps"),
                ("counter_after", "packed_sample"), ("counter_after", "last_applied_sample"),
                ("counter_after", "last_snapshot"), ("counter_after", "rig_tick")):
            row, spec = self.row()
            row["causal_phase"][section][key] = 5
            with self.subTest(key=key), self.assertRaises(causal.EvidenceError):
                causal.validate_phase(row, spec, causal.TC, 1e-5)

    def test_declared_counts_cannot_replace_clock_witness(self):
        row, spec = self.row()
        del row["causal_phase"]["counter_before"]
        with self.assertRaises(causal.EvidenceError):
            causal.validate_phase(row, spec, causal.TC, 1e-5)

    def test_direct_mass_and_unactuated_premise_refuse(self):
        row, spec = self.row(drive="unactuated")
        row["causal_phase"]["actuation"]["actual_mass"] = 2
        with self.assertRaisesRegex(causal.EvidenceError, "mass"):
            causal.validate_phase(row, spec, causal.TC, 1e-5)
        row, spec = self.row()
        spec["drive"] = "unactuated"
        with self.assertRaisesRegex(causal.EvidenceError, "Zero-ceiling"):
            causal.validate_phase(row, spec, causal.TC, 1e-5)

    def test_barrel_has_no_actor_clock_or_actuator(self):
        row, spec = self.row(kind="barrel")
        for side in ("counter_before", "counter_after"):
            row["causal_phase"][side].pop("rig_tick")
        causal.validate_phase(row, spec, causal.TC, 1e-5)
        row["controller"]["actual_impulse"] = [.01, 0]
        with self.assertRaisesRegex(causal.EvidenceError, "acquired an actuator"):
            causal.validate_phase(row, spec, causal.TC, 1e-5)

    def test_X_effective_translation_is_zero_but_offered_correction_remains(self):
        row, spec = self.row("X")
        causal.validate_setter(row, spec, causal.TC, 92.12, 1e-5)
        summary = causal.correction_summary([row])
        self.assertEqual(summary["offered_correction_sum"], [0, -.01])
        self.assertEqual(summary["effective_translation_sum"], [0, 0])
        self.assertAlmostEqual(summary["post_delivery_offset_sum"][1], .01)

    def test_setter_bound_to_original_receipt(self):
        for key, value in (("pre_response_origin", [0, 2]), ("velocity_before_setter", [0, 1]), ("omega_before_setter", 0)):
            row, spec = self.row("X")
            row["causal_phase"]["correction_setter"][key] = value
            with self.subTest(key=key), self.assertRaises(causal.EvidenceError):
                causal.validate_setter(row, spec, causal.TC, 92.12, 1e-5)

    def test_setter_rotation_roundtrip_is_bounded(self):
        row, spec = self.row("S")
        setter = row["causal_phase"]["correction_setter"]
        setter.update(rotation_after_setter=7.45e-9, rotation_roundtrip_delta=7.45e-9)
        causal.validate_setter(row, spec, causal.TC, 92.12, 1e-5)
        setter.update(rotation_after_setter=.001, rotation_roundtrip_delta=.001)
        with self.assertRaisesRegex(causal.EvidenceError, "rotation"):
            causal.validate_setter(row, spec, causal.TC, 92.12, 1e-5)

    def test_sham_cannot_cancel_translation(self):
        row, spec = self.row("S")
        setter = row["causal_phase"]["correction_setter"]
        setter.update(final_origin=[0, 1], applied_translation=[0, .01])
        with self.assertRaisesRegex(causal.EvidenceError, "Control/sham"):
            causal.validate_setter(row, spec, causal.TC, 92.12, 1e-5)

    def test_X_retains_original_corrected_COM_torque(self):
        row, spec = self.row("X")
        body = row["application"]["bodies"][0]
        body["impulse"] = [2, -1]
        setter = row["causal_phase"]["correction_setter"]
        setter.update(proposed_c_cross_J=.02, observed_c_cross_J=.02,
                      counterfactual_no_correction_bridge_angular_impulse=1.02)
        causal.validate_setter(row, spec, causal.TC, 92.12, 1e-5)
        setter["retained_angular_impulse"] = 1.02
        with self.assertRaisesRegex(causal.EvidenceError, "corrected-COM"):
            causal.validate_setter(row, spec, causal.TC, 92.12, 1e-5)

    def pair(self, registration=causal.TC, arm="T", hard=None, guard=None):
        window = dict(motion=dict(net_translation=[1, 0]), contact_node_duty=.5,
                      hard_clear_frames=300, effective_overlap_max=0)
        capture = dict(case=dict(id="flat-sand-sustained-C", arm="C", kind="flyer", drive="sustained", geometry="flat"),
            platform="windows", initial_state=dict(position=[0, 1]), initial_counts=[1, 2], initial_native_hash="hash",
            first_hard_clearance_loss_tick=None, first_rig_guard_tick=None,
            windows=dict(drive_late=copy.deepcopy(window)),
            full_window=dict(correction=dict(setter_calls=1)))
        other = copy.deepcopy(capture)
        other["case"].update(id="flat-sand-sustained-"+arm, arm=arm)
        other.update(first_hard_clearance_loss_tick=hard, first_rig_guard_tick=guard)
        other["windows"]["drive_late"]["motion"]["net_translation"][0] = 2
        rows = [dict(position=[tick*.01, 1], velocity=[0, 0], rotation=0, omega=0) for tick in range(1800)]
        protocol = dict(registration=registration, windows=dict(drive_late=[900, 1200]))
        return capture, other, dict(rows=rows), dict(rows=copy.deepcopy(rows)), protocol

    def test_hard_or_guard_censors_late_effect_not_operational_outcome(self):
        for hard, guard in ((1000, None), (None, 1000), (0, None), (None, 0)):
            result = causal.compare_pair(*self.pair(hard=hard, guard=guard))
            self.assertIsNone(result["registered_late_reporting_effect"])
            self.assertTrue(result["late_operational_reporting_effect"])
            self.assertEqual(result["common_uncensored_end_exclusive"], hard if hard is not None else guard)

    def test_clean_late_effect_remains_reportable(self):
        result = causal.compare_pair(*self.pair())
        self.assertTrue(result["registered_late_reporting_effect"])

    def test_event_tick900_requires_common_guard_and_hard_clearance(self):
        for hard, guard, expected in ((None, None, 900), (700, None, 699), (None, 700, 699), (0, None, None)):
            result = causal.compare_pair(*self.pair(causal.EVENT, "E0", hard, guard))
            if expected is None:
                self.assertIsNone(result["descent_comparison"])
            else:
                self.assertEqual(result["descent_comparison"]["tick"], expected)
                self.assertEqual(result["descent_comparison"]["registered_tick900_supported"], expected == 900)
                if expected != 900:
                    self.assertIsNone(result["descent_comparison"]["registered_channel_effect"])

    def test_sham_null_checks_whole_clean_prefix(self):
        args = self.pair(arm="S")
        args[3]["rows"][10]["velocity"] = [.1, 0]
        result = causal.compare_pair(*args)
        self.assertTrue(result["registered_null_comparison"])
        self.assertFalse(result["common_uncensored_physical_parity"]["within_registered_tolerance"])

    def calibration(self):
        identity = dict(source="1"*40, source_inputs_sha256="2"*64,
                        platforms=dict(windows=dict(native_sha256="3"*64, engine_sha256="4"*64)))
        actual = dict(source=identity["source"], input_identity=identity["source_inputs_sha256"],
                      protocol_sha256="5"*64, **identity["platforms"]["windows"])
        witnesses = {}
        for name, gain in (("control", .025), ("muted", 0)):
            witnesses[name] = dict(ok=True, errors=[], tick_ok=True, native_blocked_contacts=3,
                counter_before=0, counter_after=3, moves=0, material_cells_unchanged=True,
                counts_before=[22,2,1], counts_after=[22,2,1], water_before=0, water_after=0,
                native_hash_after="same-hash", effective_gain=gain,
                gcr=dict(nodes=0, legacy_non_granular=[0,0], event_scale=1, event_raw=[0,gain*4.8]))
        parity = dict(old_ok=True,new_ok=True,maximum_position_error=0,maximum_velocity_error=0,
                      maximum_rotation_error=0,maximum_omega_error=0,maximum_impulse_error=0)
        return dict(ok=True,errors=[],checks=100,identity=actual,calibration=witnesses,control_parity=parity), identity

    def test_positive_native_gain_witness(self):
        report, identity = self.calibration()
        result = causal.validate_calibration(report, identity, "5"*64, "windows")
        self.assertEqual(result["positive_native_contacts"], 3)

    def test_gain_readback_cannot_be_requested_value_only(self):
        report, identity = self.calibration()
        report["calibration"]["control"]["gcr"]["event_raw"] = [0, 0]
        with self.assertRaisesRegex(causal.EvidenceError, "gain"):
            causal.validate_calibration(report, identity, "5"*64, "windows")

    def test_gain_witness_requires_unchanged_native_generation_and_material(self):
        for key, value in (("native_hash_after", "different"), ("native_blocked_contacts", 0),
                           ("material_cells_unchanged", False), ("moves", 1)):
            report, identity = self.calibration()
            report["calibration"]["muted"][key] = value
            with self.subTest(key=key), self.assertRaises(causal.EvidenceError):
                causal.validate_calibration(report, identity, "5"*64, "windows")

    def test_gain_witness_source_binding(self):
        report, identity = self.calibration()
        report["identity"]["native_sha256"] = "0"*64
        with self.assertRaisesRegex(causal.EvidenceError, "bound"):
            causal.validate_calibration(report, identity, "5"*64, "windows")

    def event_raw(self):
        row, spec = self.row(drive="unactuated")
        spec.update(contact_gain=0, arm="E0")
        row["gcr"].update(legacy_non_granular=[0, 0], event_raw=[0, 0], event_accepted=[0, 0],
                          event_raw_torque=0, event_torque=0, event_budget_cost=0)
        row["event_channel"] = dict(gain_requested=0, native_counter_before=0, native_counter_after=3, native_blocked_contacts=3)
        reconstruction = dict(accepted=True, requested_options=dict(contact=0, bearing_candidate="GCR-REST", gcr_rest_mode="control",
            gcr_base_budget=20, workers=1), native_tick_after=0, body_before=[0], body_after=[0], session_before=2,
            session_after=2, upright_prime=True)
        return dict(native_reconstruction=reconstruction,initial_authoring=dict(accepted=True),
                    before=dict(counts=[10, 2, 100, 0]),rows=[row]), spec

    def test_E0_retains_positive_native_attempts_without_event_response(self):
        raw, spec = self.event_raw()
        causal.validate_event_capture(raw, spec)
        self.assertEqual(raw["rows"][0]["event_channel"]["native_blocked_contacts"], 3)

    def test_E0_nonzero_event_or_non_granular_legacy_refuses(self):
        for key, value in (("event_raw", [0,.01]), ("event_budget_cost", .01), ("legacy_non_granular", [.01,0])):
            raw, spec = self.event_raw()
            raw["rows"][0]["gcr"][key] = value
            with self.subTest(key=key), self.assertRaises(causal.EvidenceError):
                causal.validate_event_capture(raw,spec)


if __name__ == "__main__":
    unittest.main()
