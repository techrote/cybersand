#!/usr/bin/env python3
"""Semantic adversarial controls for the added treatment/freshness evidence."""
from __future__ import annotations

import copy
import unittest

from metrics import measure_window, validate_slot_treatment
from run_comparison import comparison_plan, validate_registered_sources


def ring_status():
    return {"backend": "full", "full_image_slots_requested": "3", "full_image_slots": 3,
            "full_image_slot_count": 3, "texture_ids": [101, 102, 103], "texture_rids": [901, 902, 903],
            "current_slot": 0, "previous_slot": 1, "spare_slot": 2, "upload_slot": 0,
            "allocated_logical_gpu_bytes": 3 * 512 * 512 * 2}


def ring_capture():
    status = ring_status()
    selector = {"requested": {"CYBERSAND_DIAG_FULL_IMAGE_SLOTS": "3"}, "material": status}
    data = {"selectors_before": copy.deepcopy(selector), "selectors_after": copy.deepcopy(selector),
            "fixture": {"extent": [512, 512]}}
    events = [{"event": "texture_upload", "material": copy.deepcopy(status)} for _ in range(2)]
    return data, events


class FinalContract(unittest.TestCase):
    def test_exact_new_arm_orders(self):
        self.assertEqual(comparison_plan("slots-abba", 2),
                         [{"role": "C", "slots": n} for n in (2, 3, 3, 2)])
        self.assertEqual(comparison_plan("source-abba", 2),
                         [{"role": role, "slots": 2} for role in ("D", "C", "C", "D")])
        with self.assertRaises(ValueError):
            comparison_plan("source-abba", 3)

    def test_source_roles_are_frozen_predecessor_and_exact_driver_head(self):
        driver = {"source_commit": "candidate", "source_tree": "candidate-tree"}
        registration = {"predecessor": {"source": "frozen"}}
        sources = {"C": dict(driver), "D": {"source_commit": "frozen", "source_tree": "frozen-tree"}}
        validate_registered_sources(sources, driver, registration, "source-abba")
        for role, key in (("C", "source_commit"), ("C", "source_tree"), ("D", "source_commit")):
            modified = copy.deepcopy(sources)
            modified[role][key] = "wrong-source"
            with self.assertRaises(ValueError):
                validate_registered_sources(modified, driver, registration, "source-abba")

    def test_actual_slot_inventory_and_treatment_are_required(self):
        data, events = ring_capture()
        accepted = validate_slot_treatment(data, events, 3, True)
        self.assertEqual(accepted["logical_gpu_bytes"], 1572864)
        faults = [
            ("requested_selector", lambda d, e: d["selectors_after"]["requested"].update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2")),
            ("live_selector", lambda d, e: d["selectors_after"]["material"].update(full_image_slots=2)),
            ("runtime_alias", lambda d, e: e[0]["material"].update(texture_rids=[901, 901, 903])),
            ("identity_recreation", lambda d, e: e[1]["material"].update(texture_ids=[101, 102, 104])),
            ("wrong_upload_role", lambda d, e: e[0]["material"].update(upload_slot=1)),
            ("role_alias", lambda d, e: e[0]["material"].update(previous_slot=0)),
            ("wrong_bytes", lambda d, e: e[0]["material"].update(allocated_logical_gpu_bytes=1048576)),
            ("publication_switch", lambda d, e: e[0]["material"].update(backend="blit")),
        ]
        for name, corrupt in faults:
            with self.subTest(name=name):
                copied_data, copied_events = copy.deepcopy(data), copy.deepcopy(events)
                corrupt(copied_data, copied_events)
                with self.assertRaises(ValueError):
                    validate_slot_treatment(copied_data, copied_events, 3, True)

    def test_historical_missing_status_cannot_be_a_ring_pass(self):
        selector = {"requested": {"CYBERSAND_DIAG_FULL_IMAGE_SLOTS": "2"}, "material": {"backend": "full"}}
        data = {"selectors_before": selector, "selectors_after": selector}
        events = [{"event": "texture_upload", "material": {"backend": "full"}}]
        old = validate_slot_treatment(data, events, 2, False)
        self.assertFalse(old["effective_slots_verified"])
        with self.assertRaises(ValueError):
            validate_slot_treatment(data, events, 2, True)
        with self.assertRaises(ValueError):
            validate_slot_treatment(data, events, 3, False)

    def test_generated_fixture_requires_registered_extent_without_rewriting_receipt(self):
        data, events = ring_capture()
        data["fixture"] = {"name": "reference2048", "generated_sha256": "a" * 64}
        for event in events:
            event["material"]["allocated_logical_gpu_bytes"] = 3 * 2048 * 2048 * 2
        original = copy.deepcopy(data)
        observed = validate_slot_treatment(data, events, 3, True, expected_extent=[2048, 2048])
        self.assertEqual(observed["registered_extent"], [2048, 2048])
        self.assertEqual(observed["logical_gpu_bytes"], 25165824)
        self.assertEqual(data, original)
        for bad in (None, [], [2048], [2048, 1024], [2048, 2048.0], [False, 2048], [0, 2048]):
            with self.subTest(expected_extent=bad), self.assertRaises(ValueError):
                validate_slot_treatment(data, events, 3, True, expected_extent=bad)
        changed = copy.deepcopy(data)
        changed["fixture"]["extent"] = [1024, 2048]
        with self.assertRaises(ValueError):
            validate_slot_treatment(changed, events, 3, True, expected_extent=[2048, 2048])
        false_bytes = copy.deepcopy(events)
        false_bytes[0]["material"]["allocated_logical_gpu_bytes"] = 2 * 2048 * 2048 * 2
        with self.assertRaises(ValueError):
            validate_slot_treatment(data, false_bytes, 3, True, expected_extent=[2048, 2048])

    def test_refcounted_object_ids_keep_signed_int64_identity(self):
        data, events = ring_capture()
        negative = [-9223371955351058792, -9223371955317504358, -9223371955283949924]
        for event in events:
            event["material"]["texture_ids"] = negative.copy()
        result = validate_slot_treatment(data, events, 3, True)
        self.assertEqual(result["fixed_texture_ids"], negative)
        for invalid in (0, -(1 << 63) - 1, 1 << 63, True, -1.5):
            with self.subTest(invalid=invalid):
                broken = copy.deepcopy(events)
                broken[0]["material"]["texture_ids"][0] = invalid
                with self.assertRaises(ValueError):
                    validate_slot_treatment(data, broken, 3, True)
        for key, values in (("texture_ids", [negative[0], negative[0], negative[2]]),
                            ("texture_ids", [negative[0], negative[1], -97]),
                            ("texture_rids", [-1, 902, 903]),
                            ("texture_rids", [1 << 63, 902, 903])):
            with self.subTest(key=key, values=values):
                broken = copy.deepcopy(events)
                broken[1]["material"][key] = values
                with self.assertRaises(ValueError):
                    validate_slot_treatment(data, broken, 3, True)

    def test_repeated_admission_cannot_hide_wait_or_invent_material_draw(self):
        rows = [
            {"event": "command_attempt", "time_usec": 1000, "absolute_tick": 0, "sequence_after": 1},
            {"event": "command_attempt", "time_usec": 9000, "absolute_tick": 0, "sequence_after": 2},
            {"event": "rapier_step", "time_usec": 10000, "start_usec": 9500, "step": 1,
             "command_sequence": 2, "world_generation": 1, "native_tick_used": 1,
             "completed_body_sample": 1, "required_hard_revision": 1, "native_completed_usec": 2000,
             "solver_usec": 100, "execution_kind": "physics_callback"},
            {"event": "texture_upload", "start_usec": 11000, "time_usec": 12000,
             "render_serial": 7, "generated_usec": 4000},
            {"event": "texture_upload", "start_usec": 13000, "time_usec": 14000,
             "render_serial": 8, "generated_usec": 5000},
            {"event": "framebuffer_draw", "time_usec": 15000, "render_serial": 8, "inline_main": True},
        ]
        result = measure_window(rows, {"capture_start_usec": 0}, 16000)
        self.assertEqual(result["first_admitted_command_for_tick_to_step_ms"]["max"], 9)
        self.assertEqual(result["consumed_command_to_step_ms"]["max"], 1)
        self.assertEqual(result["unmatched_uploads_at_window_end"], 1)
        self.assertEqual(result["matching_material_generation_to_draw_delivery_ms"]["max"], 10)
        self.assertEqual(result["matching_upload_return_to_draw_delivery_ms"]["max"], 1)
        self.assertEqual(result["latest_physical_completion_age_at_draw_delivery_ms"]["max"], 5)
        deferred = copy.deepcopy(rows)
        deferred[-1].update(inline_main=False, render_serial=-1)
        unknown = measure_window(deferred, {"capture_start_usec": 0}, 16000)
        self.assertFalse(unknown["material_draw_identity_available"])
        self.assertIsNone(unknown["unmatched_uploads_at_window_end"])
        self.assertIsNone(unknown["matching_material_generation_to_draw_delivery_ms"])
        self.assertEqual(unknown["latest_physical_completion_age_at_draw_delivery_ms"]["max"], 5)
        bad = copy.deepcopy(rows)
        bad[2]["command_sequence"] = 999
        with self.assertRaises(ValueError):
            measure_window(bad, {"capture_start_usec": 0}, 16000)


if __name__ == "__main__":
    unittest.main()
