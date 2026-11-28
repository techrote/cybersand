#!/usr/bin/env python3
"""Adversarial scheduling/source parser controls; no runtime qualification."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from material_steps_contract import validate_evidence, verify_contract, validate_cohort, validate_registration, ROOT
from material_steps_status import (ACCEPTED_SCOPE, ANCHOR, COUNTERS, PENDING, SELECTOR,
                                   committed_capability, live_bridge_identity, validate_policy_observation, validate_status)
from run_material_steps_comparison import steps_campaign
import observer_support


def state(interval=2):
    value = {"schema": "pubpres-material-steps-v1", "requested_interval": interval, "effective_interval": interval,
             "enabled": interval == 2, "disabled_reason": "", "scheduled_added_hold_usec": 16667,
             "source_age_guard_usec": 1000000, "pending_count": 0, "identity": [],
             "paint_force": False, "paint_busy": False, "paint_idle_usec": -1,
             "accepted_upload_scope": ACCEPTED_SCOPE, "last_cancel": "configuration", "last_offer_result": "",
             "last_consumption_reason": "", "last_hold_usec": 0, "last_deadline_overrun_usec": 0,
             "maximum_deadline_overrun_usec": 0, "last_source_age_usec": -1,
             "last_count_due": False, "last_deadline_due": False, "physical_credit": False}
    value.update({key: -1 for key in (*PENDING, *ANCHOR)})
    value.update({key: 0 for key in COUNTERS})
    return value


def deadline_off():
    return {"schema": "pubpres-material-deadline-v1", "enabled": False, "physical_credit": False,
            **{key: 0 for key in ("requested_hz", "interval_usec", "pending_count", "offers", "replaced_offers", "consumptions", "accepted_uploads", "cancellations")},
            **{key: -1 for key in ("pending_serial", "pending_generation", "deadline_usec", "next_upload_usec")}}


def evidence(interval=2):
    initial = {"serial": 20, "generation": 42, "generated_usec": 90000}
    before = state(interval)
    if interval:
        before.update(identity=[7, 11, 42, -1234], anchor_session_step=10, anchor_rapier_step=110,
                      anchor_uploaded_serial=20, anchor_uploaded_usec=90010, last_source_age_usec=1,
                      offers=1, consumptions=1, accepted_uploads=1, last_offer_result="offered",
                      last_consumption_reason="initial_or_new_world")
    statuses = []
    current = copy.deepcopy(before)
    if interval:
        current.update(pending_count=1, pending_serial=21, pending_generation=42, pending_generated_usec=110001,
                       first_offer_usec=110010, deadline_usec=126677, offers=2, deferred_turns=1)
    statuses.append(copy.deepcopy(current))
    if interval:
        current.update(pending_serial=22, pending_generated_usec=115001, offers=3, replaced_offers=1, deferred_turns=2)
    statuses.append(copy.deepcopy(current))
    if interval:
        current.update({key: -1 for key in PENDING})
        current.update(pending_count=0, consumptions=2, accepted_uploads=2, anchor_session_step=12, anchor_rapier_step=112,
                       anchor_uploaded_serial=22, anchor_uploaded_usec=120021, last_source_age_usec=5009,
                       last_hold_usec=10000, last_count_due=True, last_consumption_reason="completed_step_interval")
    statuses.append(copy.deepcopy(current))
    if interval:
        current.update(pending_count=1, pending_serial=23, pending_generation=42, pending_generated_usec=125001,
                       first_offer_usec=125010, deadline_usec=141677, offers=4, deferred_turns=3)
    statuses.append(copy.deepcopy(current))
    if interval:
        current.update({key: -1 for key in PENDING})
        current.update(pending_count=0, consumptions=3, accepted_uploads=3, anchor_uploaded_serial=23,
                       anchor_uploaded_usec=141791, last_source_age_usec=16776, last_hold_usec=16767,
                       last_count_due=False, last_deadline_due=True, last_consumption_reason="scheduled_hold_deadline",
                       last_deadline_overrun_usec=100, maximum_deadline_overrun_usec=100)
    statuses.append(copy.deepcopy(current))
    uploads = [{"event": "texture_upload", "start_usec": 120011, "time_usec": 120020,
                "render_serial": 22, "world_generation": 42, "generated_usec": 115001},
               {"event": "texture_upload", "start_usec": 141780, "time_usec": 141790,
                "render_serial": 23, "world_generation": 42, "generated_usec": 125001}]
    rows, draws = [], []
    for index, clock in enumerate((112000, 117000, 121000, 130000, 142000)):
        serial, generated = (20, 90000) if index < 2 else (22, 115001) if index < 4 else (23, 125001)
        draw = {"event": "framebuffer_draw", "time_usec": clock, "process_frame": index + 10,
                "rendered_frames": index + 10, "inline_main": True, "render_serial": serial}
        draws.append(draw)
        rows.append({"event": "material_steps_delivery", "time_usec": clock + 5,
                     "delivered_draw_usec": clock, "process_frame": index + 10, "rendered_frames": index + 10,
                     "inline_main": True, "draw_render_serial": serial, "uploaded_serial": serial,
                     "uploaded_generation": 42, "uploaded_generated_usec": generated, "observer_usec": 2,
                     "status": statuses[index]})
    steps = [{"event": "rapier_step", "step": index + 11, "manual_steps": index + 111,
              "session": 7, "epoch": 11, "world_generation": 42,
              "time_usec": (110000 if index == 0 else 120000 if index == 1 else 145000 + (index - 2) * 5000)}
             for index in range(144)]
    selected = {"requested": {SELECTOR: str(interval), "CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ": "0"},
                "material_steps_api_present": True, "material_steps": before, "material_steps_uploaded": initial,
                "material_deadline": deadline_off()}
    data = {"capture_start_usec": 100000, "capture_end_usec": 1000000, "capture_physical_tick_start": 10,
            "case_nonce": "synthetic-parser-control", "source_identity": {"source_sha": "test-only"},
            "physical_owner_before": {"session": 7, "epoch": 11, "bridge": "-1234"},
            "selectors_before": copy.deepcopy(selected), "selectors_after": copy.deepcopy(selected)}
    data["selectors_after"]["material_steps"] = copy.deepcopy(current)
    header = {"event": "material_steps_identity", "schema": "pubpres-material-steps-observer-v1",
              "source": data["source_identity"], "case_nonce": data["case_nonce"], "capture_start_usec": 100000,
              "capture_end_usec": 1000000, "maximum_samples": 6000, "samples": 5, "overflow": False,
              "start_status": copy.deepcopy(before), "end_status": copy.deepcopy(current), "start_material": initial,
              "end_material": {"serial": 23, "generation": 42, "generated_usec": 125001}}
    return data, uploads + draws + steps, header, rows


class MaterialStepsContract(unittest.TestCase):
    def test_adversarial_registration_requires_exact_integer_and_boolean_domains(self):
        original = json.loads((ROOT / "tools/pubpres_final/material_steps_registration.json").read_bytes())
        mutations = [("order_false", lambda value: value["order"].__setitem__(0, False)),
                     ("order_float", lambda value: value["order"].__setitem__(1, 2.0))]
        for key, current in original.items():
            if type(current) is int:
                mutations += [(key + "_float", lambda value, key=key, current=current: value.update({key: float(current)})),
                              (key + "_bool", lambda value, key=key: value.update({key: False}))]
            elif type(current) is bool:
                mutations += [(key + "_int", lambda value, key=key, current=current: value.update({key: int(current)}))]
        for label, mutate in mutations:
            changed = copy.deepcopy(original)
            mutate(changed)
            with self.subTest(label=label):
                with self.assertRaises(ValueError):
                    validate_registration(changed)
                with self.assertRaises(ValueError):
                    steps_campaign(changed, ["wave_512_follow"])
                with patch("material_steps_contract.json.loads", return_value=changed), self.assertRaises(ValueError):
                    verify_contract()

    def test_registered_capture_uses_frozen_physical_oracle_and_full_counterbalance(self):
        self.assertEqual(len(verify_contract()["frozen_v3_sha256"]), 64)
        registration = json.loads((ROOT / "tools/pubpres_final/material_steps_registration.json").read_bytes())
        campaign = steps_campaign(registration, ["wave_512_follow"])
        self.assertEqual(registration["order"], [0, 2, 2, 0])
        self.assertEqual(campaign["measurement"]["minimum_real_steps"], 144)
        self.assertEqual(campaign["measurement"]["minimum_capture_usec"], 10000000)
        with self.assertRaises(ValueError):
            steps_campaign(registration, ["wave_1024_follow_4"])

    def test_count_anchors_join_real_steps_and_control_observes_no_policy_work(self):
        result = validate_evidence(*evidence(), 2)
        self.assertFalse(result["physical_credit"])
        self.assertTrue(result["treatment_exercised"])
        self.assertEqual(result["capture_policy_counters"]["accepted_uploads"], 2)
        self.assertEqual(result["capture_policy_counters"]["replaced_offers"], 1)
        self.assertEqual([row["independently_joined_step"] for row in result["accepted_transactions"]], [12, 12])
        self.assertEqual(result["windows"]["whole_capture"]["oldest_uploaded_material_at_draw_ms"], 27)
        self.assertEqual(result["windows"]["whole_capture"]["actual_selected_deadline_overrun_ms"]["max"], .1)
        self.assertGreater(result["windows"]["first_144_steps"]["policy_counter_trailing_unsampled_ms"], 0)
        control = validate_evidence(*evidence(0), 0)
        self.assertFalse(control["treatment_exercised"])
        self.assertEqual(control["windows"]["whole_capture"]["actual_uploads"], 2)
        self.assertTrue(all(value == 0 for value in control["capture_policy_counters"].values()))

    def test_latest_completion_and_synchronous_Main_boundary_are_mandatory(self):
        for label, corrupt in (
            ("stale_but_genuine_anchor", lambda d, e, h, r:
                (e[9].update(time_usec=125000), e[10].update(time_usec=135000))),
            ("future_genuine_anchor", lambda d, e, h, r:
                r[2]["status"].update(anchor_session_step=13, anchor_rapier_step=113)),
            ("step_between_take_and_upload", lambda d, e, h, r: e[9].update(time_usec=141778)),
            ("step_during_upload", lambda d, e, h, r: e[9].update(time_usec=141785)),
            ("step_between_upload_and_complete", lambda d, e, h, r: e[9].update(time_usec=141791)),
        ):
            values = evidence()
            corrupt(*values)
            with self.subTest(label=label), self.assertRaises(ValueError):
                validate_evidence(*values, 2)

    def test_pre_capture_boundary_is_exact_and_cannot_supply_independent_exercise(self):
        data, events, header, rows = evidence()
        for index, step in enumerate(events[7:]):
            step["time_usec"] = 140000 + index * 5000
        for row in rows[:2]:
            row["status"].update(first_offer_usec=103010, deadline_usec=119677)
        for row in rows[2:4]:
            row["status"].update(anchor_session_step=10, anchor_rapier_step=110,
                last_hold_usec=17000, last_count_due=False, last_deadline_due=True,
                last_consumption_reason="scheduled_hold_deadline", last_deadline_overrun_usec=333,
                maximum_deadline_overrun_usec=333)
        rows[4]["status"].update(anchor_session_step=11, anchor_rapier_step=111,
                                  maximum_deadline_overrun_usec=333)
        header["end_status"] = copy.deepcopy(rows[4]["status"])
        data["selectors_after"]["material_steps"] = copy.deepcopy(rows[4]["status"])
        result = validate_evidence(data, events, header, rows, 2)
        self.assertEqual(result["accepted_transactions"][0]["anchor_join_scope"], "pre_capture_boundary")
        self.assertIsNone(result["accepted_transactions"][0]["independently_joined_step"])
        self.assertEqual(result["accepted_transactions"][1]["independently_joined_step"], 11)
        self.assertFalse(result["treatment_exercised"])
        rows[2]["status"].update(anchor_session_step=9, anchor_rapier_step=109)
        with self.assertRaises(ValueError):
            validate_evidence(data, events, header, rows, 2)

    def test_live_owner_ids_are_canonical_signed64_and_ownerless_scope_is_explicit(self):
        for value in (-(1 << 63), (1 << 63) - 1, -1234, 1234):
            status = evidence()[3][0]["status"]
            status["identity"][3] = value
            validate_status(status, 2)
            self.assertEqual(live_bridge_identity(str(value)), value)
        for value in (0, "0", "-0", "+1234", "01234", "-01234", " 1234", "1234.0", 1234.0,
                      str(1 << 63), str(-(1 << 63) - 1), False):
            with self.subTest(bridge=value), self.assertRaises(ValueError):
                live_bridge_identity(value)
            values = evidence()
            values[0]["physical_owner_before"]["bridge"] = value
            with self.subTest(capture_bridge=value), self.assertRaises(ValueError):
                validate_evidence(*values, 2)
        for index in range(4):
            for value in (1 << 63, -(1 << 63) - 1, 0, False, 7.0):
                status = evidence()[3][0]["status"]
                status["identity"][index] = value
                with self.subTest(component=index, value=value), self.assertRaises(ValueError):
                    validate_status(status, 2)
        ownerless = evidence()[3][0]["status"]
        ownerless["identity"] = [0, 0, 42, 0]
        with self.assertRaises(ValueError):
            validate_status(ownerless, 2)
        validate_status(ownerless, 2, allow_ownerless=True)
        ownerless["identity"][0] = 7
        with self.assertRaises(ValueError):
            validate_status(ownerless, 2, allow_ownerless=True)

    def test_authority_clock_counter_and_pixel_age_forgeries_are_rejected(self):
        faults = (
            ("wrong_source", lambda d, e, h, r: h.update(source={})),
            ("wrong_nonce", lambda d, e, h, r: h.update(case_nonce="foreign")),
            ("lost_draw", lambda d, e, h, r: r.pop()),
            ("overflow", lambda d, e, h, r: h.update(overflow=True)),
            ("wrong_request", lambda d, e, h, r: d["selectors_before"]["requested"].update({SELECTOR: "0"})),
            ("missing_api", lambda d, e, h, r: d["selectors_after"].update(material_steps_api_present=False)),
            ("wall_deadline", lambda d, e, h, r: d["selectors_after"]["requested"].update(CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="30")),
            ("unbounded_pending", lambda d, e, h, r: r[0]["status"].update(pending_count=2)),
            ("changed_owner", lambda d, e, h, r: r[0]["status"].update(identity=[7, 12, 42, -1234])),
            ("counter_regression", lambda d, e, h, r: r[1]["status"].update(offers=1)),
            ("renewed_offer", lambda d, e, h, r: r[1]["status"].update(first_offer_usec=115010, deadline_usec=131677)),
            ("renewed_deadline", lambda d, e, h, r: r[1]["status"].update(deadline_usec=126678)),
            ("wrong_material", lambda d, e, h, r: r[1].update(uploaded_serial=22, draw_render_serial=22)),
            ("invented_freshness", lambda d, e, h, r: r[1].update(uploaded_generated_usec=116000)),
            ("separate_unknown", lambda d, e, h, r: r[0].update(inline_main=False)),
            ("forged_draw", lambda d, e, h, r: r[0].update(delivered_draw_usec=111999)),
            ("forged_frame", lambda d, e, h, r: r[0].update(process_frame=99)),
            ("unobserved_step", lambda d, e, h, r: r[2]["status"].update(anchor_session_step=155, anchor_rapier_step=255)),
            ("other_manual_step", lambda d, e, h, r: r[2]["status"].update(anchor_rapier_step=113)),
            ("future_physics", lambda d, e, h, r: e[8].update(time_usec=130000)),
            ("wrong_upload_anchor", lambda d, e, h, r: r[2]["status"].update(anchor_uploaded_serial=21)),
            ("future_anchor", lambda d, e, h, r: r[2]["status"].update(anchor_uploaded_usec=200000)),
            ("future_take", lambda d, e, h, r: r[2]["status"].update(last_source_age_usec=10000)),
            ("fake_count_due", lambda d, e, h, r: r[2]["status"].update(last_count_due=False)),
            ("forced_paint_escape", lambda d, e, h, r: r[2]["status"].update(paint_force=True)),
            ("lost_deadline_overrun", lambda d, e, h, r: r[4]["status"].update(last_deadline_overrun_usec=0)),
            ("suppressed_cancel", lambda d, e, h, r: h["end_status"].update(cancellations=1)),
            ("cancelled_upload_credit", lambda d, e, h, r: h["end_status"].update(accepted_uploads_after_policy_cancellation=1)),
            ("missing_offer", lambda d, e, h, r: h["end_status"].update(offers=5)),
            ("lost_physical_steps", lambda d, e, h, r: e.pop()),
        )
        for label, corrupt in faults:
            with self.subTest(label=label):
                values = evidence()
                corrupt(*values)
                with self.assertRaises((ValueError, KeyError, TypeError)):
                    validate_evidence(*values, 2)

    def test_simultaneous_eligibility_is_exercised_coalescing_without_unique_count_attribution(self):
        data, events, header, rows = evidence()
        events[0].update(start_usec=127678, time_usec=127690)
        events[8]["time_usec"] = 127000  # Actual completed step12, before its upload.
        for index in (2, 3):
            rows[index]["status"].update(anchor_uploaded_usec=127691, last_source_age_usec=12676,
                last_hold_usec=17667, last_deadline_due=True, last_deadline_overrun_usec=1000,
                maximum_deadline_overrun_usec=1000)
        events[4]["time_usec"] = 128000  # The third actual draw.
        rows[2].update(delivered_draw_usec=128000, time_usec=128005)
        rows[3]["status"].update(first_offer_usec=129010, pending_generated_usec=128001, deadline_usec=145677)
        events[1].update(start_usec=145780, time_usec=145790, generated_usec=128001)
        events[6]["time_usec"] = 146000
        rows[4].update(delivered_draw_usec=146000, time_usec=146005, uploaded_generated_usec=128001)
        rows[4]["status"].update(anchor_session_step=13, anchor_rapier_step=113, anchor_uploaded_usec=145791,
                                  last_source_age_usec=17776, maximum_deadline_overrun_usec=1000)
        header["end_status"] = copy.deepcopy(rows[4]["status"])
        header["end_material"]["generated_usec"] = 128001
        data["selectors_after"]["material_steps"] = copy.deepcopy(rows[4]["status"])
        result = validate_evidence(data, events, header, rows, 2)
        self.assertTrue(result["treatment_exercised"])
        self.assertEqual(result["independent_count_before_deadline_attribution"], "NOT_ESTABLISHED")
        self.assertEqual(result["coalescing_population"], "observed_coalescing")
        self.assertEqual(result["windows"]["whole_capture"]["accepted_eligibility_populations"],
                         {"count_only": 0, "both": 1, "deadline_only": 1, "neither_initial_or_immediate": 0})

    def test_strict_new_scalar_domains_reject_bool_and_float_credit(self):
        example = evidence()[3][0]["status"]
        for key, value in example.items():
            if type(value) is int:
                for changed in (False, float(value)):
                    with self.subTest(key=key, changed=changed):
                        bad = copy.deepcopy(example)
                        bad[key] = changed
                        with self.assertRaises(ValueError):
                            validate_status(bad, 2)
        for field in ("time_usec", "delivered_draw_usec", "process_frame", "rendered_frames", "draw_render_serial",
                      "uploaded_serial", "uploaded_generation", "uploaded_generated_usec", "observer_usec"):
            with self.subTest(field=field):
                values = evidence()
                values[3][0][field] = float(values[3][0][field])
                with self.assertRaises(ValueError):
                    validate_evidence(*values, 2)

    def test_source_bound_legacy_absence_is_distinct_from_current_effective_zero(self):
        for source in ("c2f8a73d34448bc1496ecd84bca02f0812c80d27",
                       subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()):
            capability = committed_capability(source)
            with tempfile.TemporaryDirectory() as temporary:
                project = Path(temporary)
                files = {}
                for relative in ("scripts/main.gd", "scripts/material_publication_steps.gd"):
                    target = project / relative
                    if relative.endswith("main.gd") or capability["api_present"]:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        raw = subprocess.check_output(["git", "-C", str(ROOT), "show", source + ":godot/" + relative])
                        target.write_bytes(raw)
                        files["res://" + relative] = hashlib.sha256(raw).hexdigest()
                    else:
                        files["res://" + relative] = None
                data = {"source_identity": {"source_sha": source, "files": files},
                        **{phase: {"requested": {SELECTOR: "0"}, "material_steps_api_present": capability["api_present"],
                                   "material_steps": state(0) if capability["api_present"] else None}
                           for phase in ("selectors_before", "selectors_after")}}
                result = validate_policy_observation(data, project)
                self.assertEqual(result["verified_off"], capability["api_present"])
                self.assertEqual(result["legacy_api_absence_verified"], not capability["api_present"])
                for label, corrupt in (
                    ("arbitrary_null", lambda d: d["selectors_after"].update(material_steps=None, material_steps_api_present=False)
                         if capability["api_present"] else d["selectors_after"].update(material_steps=state(0), material_steps_api_present=True)),
                    ("unobserved_request", lambda d: d["selectors_after"]["requested"].pop(SELECTOR)),
                    ("missing_helper_identity", lambda d: d["source_identity"]["files"].pop("res://scripts/material_publication_steps.gd")),
                    ("wrong_Main", lambda d: d["source_identity"]["files"].update({"res://scripts/main.gd": "0" * 64})),
                ):
                    changed = copy.deepcopy(data)
                    corrupt(changed)
                    with self.subTest(label=label, source=source), self.assertRaises((ValueError, KeyError)):
                        validate_policy_observation(changed, project)
                (project / "scripts/main.gd").write_bytes(b"altered application")
                with self.assertRaises(ValueError):
                    validate_policy_observation(data, project)

    def test_shared_owned_executor_sets_control_without_mutating_caller_or_frozen_executor(self):
        with patch.object(observer_support, "_execute_with_resources", return_value={"synthetic": True}) as executor:
            settings = {"unrelated": "preserved"}
            observer_support.execute_with_resources("engine", [], "folder", "source", settings, 1)
            self.assertNotIn(SELECTOR, settings)
            self.assertEqual(executor.call_args.args[4], {"unrelated": "preserved", SELECTOR: "0"})
            observer_support.execute_with_resources("engine", [], "folder", "source", {SELECTOR: "2"}, 1)
            self.assertEqual(executor.call_args.args[4][SELECTOR], "2")
            with self.assertRaises(ValueError):
                observer_support.execute_with_resources("engine", [], "folder", "source", {SELECTOR: "1"}, 1)

    def test_complete_cohort_retains_noop_and_hidden_episodes_without_a_winner(self):
        registration = json.loads((ROOT / "tools/pubpres_final/material_steps_registration.json").read_bytes())
        arms = []
        hidden = {"windows": {"whole_capture": {"withheld_body_submissions": 80,
                  "withholding_episodes": [{"slot": 0, "duration_ms": 5000, "right_censored": True}],
                  "withholding_censored_episodes": 1, "selected_completion_age_ms": {"p50": 4}}}}
        for index, interval in enumerate((0, 2, 2, 0)):
            values = evidence(interval)
            policy = validate_evidence(*values, interval)
            selected = copy.deepcopy(values[0]["selectors_before"])
            selected.update(physics="early", presentation="coherent", cadence="repaired", rendezvous={"mode": "off"})
            stats = {"source": "same-source", "match": {"cpu": "same-host", "water_law": "wave_flow_v1", "water_profile": "reference"},
                     "first_144_body_trajectory_sha256": "same-bodies", "first_144_admitted_moves_sha256": "same-input",
                     "command_counts": {"accepted": 200}, "command_mode": "repeated_callback",
                     "registered_material_treatment": {"backend": "full", "policy": ""},
                     "same_frame_continuation": {"enabled": False}, "selectors_before": selected, "selectors_after": copy.deepcopy(selected),
                     "windows": {"first_144_steps": {"completed_rapier_steps": 144, "rapier_steps_per_second": 10,
                                  "physical_gap_ms": {"p50": 80, "p95": 100, "p99": 200, "max": 300}}},
                     "physical_gap_counts_above_ms": {"first_144_steps": {"100": 20, "250": 2, "500": 0, "1000": 0}}}
            arms.append({"arm": "C", "index": index, "requested_interval": interval, "statistics": stats,
                         "material_steps": policy, "supplementary": {"input": "retained"},
                         "slots": {"requested_slots": 2, "effective_slots_verified": True},
                         "observers": {"presentation_enabled": True, "presentation": copy.deepcopy(hidden), "cpu": {},
                                       "material_steps_policy": {"requested_interval": interval}}})
        result = validate_cohort(arms, registration)
        self.assertFalse(result["registered_direction"]["repeatable_direction"])
        self.assertTrue(result["treatment_exercised_in_both_arms"])
        self.assertEqual(result["readings"][1]["presentation"], hidden)
        arms[1]["material_steps"]["treatment_exercised"] = False
        noop = validate_cohort(arms, registration)
        self.assertFalse(noop["treatment_exercised_in_both_arms"])
        self.assertEqual(len(noop["readings"]), 4)
        for label, corrupt in (
            ("missing_control", lambda a: a.pop()),
            ("boolean_index", lambda a: a[1].update(index=True)),
            ("float_index", lambda a: a[1].update(index=1.0)),
            ("boolean_control", lambda a: a[0].update(requested_interval=False)),
            ("float_treatment", lambda a: a[1].update(requested_interval=2.0)),
            ("float_policy", lambda a: a[1]["material_steps"].update(requested_interval=2.0)),
            ("float_effective", lambda a: a[1]["material_steps"].update(effective_interval=2.0)),
            ("boolean_exercise", lambda a: a[2]["material_steps"].update(treatment_exercised=1)),
            ("boolean_attribution", lambda a: a[2]["material_steps"].update(independent_count_before_deadline_observed=1)),
            ("float_observer_treatment", lambda a: a[1]["observers"]["material_steps_policy"].update(requested_interval=2.0)),
            ("float_steps", lambda a: a[1]["statistics"]["windows"]["first_144_steps"].update(completed_rapier_steps=144.0)),
            ("float_slots", lambda a: a[2]["slots"].update(requested_slots=2.0)),
            ("wrong_order", lambda a: a[1].update(requested_interval=0)),
            ("different_host", lambda a: a[2]["statistics"]["match"].update(cpu="foreign")),
            ("different_source", lambda a: a[2]["statistics"].update(source="foreign")),
            ("changed_physics", lambda a: a[2]["statistics"].update(first_144_body_trajectory_sha256="different")),
            ("extra_wall_deadline", lambda a: a[2]["statistics"]["selectors_after"]["requested"].update(CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="30")),
            ("missing_freshness", lambda a: a[2]["observers"].update(presentation=None)),
            ("wrong_slots", lambda a: a[2]["slots"].update(requested_slots=3)),
        ):
            changed = copy.deepcopy(arms)
            corrupt(changed)
            with self.subTest(label=label), self.assertRaises((ValueError, KeyError)):
                validate_cohort(changed, registration)


if __name__ == "__main__":
    unittest.main()
