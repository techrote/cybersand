"""Adversarial tests of the proposed #361 observer; these run no simulation."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from in_tools_contract import (ContractError, PLAN, source_check,
                               validate_plan, validate_receipt)


def packet(operation="source", material=3, family="inertial_cellular_v1", bits=8):
    q = (1 << bits) - 1 if material == 3 else 1
    owner = dict(generation=7, control_generation=9, equipment_epoch=2,
                 last_sequence=40, tick=12, policy_sha256="1" * 64,
                 state_hash="2" * 64, construction_receipt_sha256="a" * 64,
                 failed=False, mass_bits=bits, family=family,
                 material=material, radius=3, domain=[0, 0, 128, 128],
                 stored_units=10 * q, supply_remaining=4 * q, sink_remaining=4 * q)
    command = dict(schema="in-tools-command-proposal-v1", id="pulse-41", sequence=41,
                   generation=7, control_generation=9, equipment_epoch=2,
                   issued_tick=10, expires_tick=20, policy_sha256="1" * 64,
                   operation=operation, material=material,
                   rect=[32, 32, 1, 1], requested_units=q if operation in {"source", "sink"} else 0,
                   direction=[1, 0], speed_q16=0, motion="zero_new_motion")
    before_mat, after_mat = {"source": (0, material), "sink": (material, 0),
                             "open_valve": (1, 0), "close_valve": (0, 1)}[operation]
    added = q if operation == "source" else 0
    removed = q if operation == "sink" else 0
    receipt = dict(schema="in-tools-receipt-proposal-v1", command_id="pulse-41",
                   sequence=41, generation=7, policy_sha256="1" * 64, tick=12,
                   construction_receipt_sha256="a" * 64,
                   before_hash="2" * 64, after_hash="3" * 64, outcome="applied", reason="",
                   source_units=added, sink_units=removed,
                   stored_before=10 * q, stored_after=10 * q + added - removed,
                   supply_before=4 * q, supply_after=4 * q - added,
                   sink_budget_before=4 * q, sink_budget_after=4 * q - removed,
                   cells=[dict(xy=[32, 32], body_id=0, before_material=before_mat,
                               after_material=after_mat,
                               before_units=q if before_mat == material else 0,
                               after_units=q if after_mat == material else 0,
                               before_state_sha256="4" * 64, after_state_sha256="5" * 64,
                               before_motion=[0, 0, 0, 0], after_motion=[0, 0, 0, 0])])
    return dict(command=command, receipt=receipt, owner=owner)


def refusal(p, reason="blocked"):
    p = copy.deepcopy(p)
    r = p["receipt"]
    r.update(outcome="refused", reason=reason, after_hash=r["before_hash"],
             source_units=0, sink_units=0, stored_after=r["stored_before"],
             supply_after=r["supply_before"], sink_budget_after=r["sink_budget_before"])
    for c in r["cells"]:
        c.update(after_material=c["before_material"], after_units=c["before_units"],
                 after_state_sha256=c["before_state_sha256"], after_motion=c["before_motion"].copy())
    return p


class ReceiptTests(unittest.TestCase):
    def reject(self, p):
        with self.assertRaises(ContractError):
            validate_receipt(**p)

    def test_all_operations_are_consistency_only(self):
        for op in ("source", "sink", "open_valve", "close_valve"):
            with self.subTest(operation=op):
                result = validate_receipt(**packet(op))
                self.assertFalse(result["gameplay_qualified"])
                self.assertFalse(result["native_receipt_authenticated"])

    def test_water_precisions_and_brine_units(self):
        for material, family, bits in [(3, "inertial_cellular_v1", 3),
                                       (3, "inertial_cellular_v1", 8),
                                       (24, "inertial_cellular_v1", 8),
                                       (24, "cellular_yield_v1", 8)]:
            with self.subTest(material=material, family=family, bits=bits):
                self.assertEqual(validate_receipt(**packet(material=material, family=family, bits=bits))
                                 ["source_units"], (1 << bits) - 1 if material == 3 else 1)

    def test_fractional_freemass_sink_counts_units_not_slots(self):
        p = packet("sink", family="freemass_v1")
        p["receipt"]["cells"][0]["before_units"] = 17
        p["receipt"].update(sink_units=17, stored_after=2550 - 17, sink_budget_after=1020 - 17)
        self.assertEqual(validate_receipt(**p)["sink_units"], 17)
        p["receipt"]["sink_units"] = 1
        self.reject(p)

    def test_valid_explicit_refusal_preserves_everything(self):
        self.assertEqual(validate_receipt(**refusal(packet()))["source_units"], 0)

    def test_stale_generation_control_equipment_policy_and_sequence(self):
        for field, value in [("generation", 6), ("control_generation", 8),
                             ("equipment_epoch", 1), ("policy_sha256", "9" * 64),
                             ("sequence", 40), ("expires_tick", 11), ("issued_tick", 13)]:
            with self.subTest(field=field):
                p = packet()
                p["command"][field] = value
                if field == "sequence":
                    p["receipt"]["sequence"] = value
                self.reject(p)
                validate_receipt(**refusal(p, "stale"))

    def test_failed_world_cannot_accept(self):
        p = packet()
        p["owner"]["failed"] = True
        self.reject(p)
        validate_receipt(**refusal(p, "failed-world"))

    def test_fractional_in_request_refuses_without_rounding(self):
        p = packet()
        p["command"]["requested_units"] = 17
        self.reject(p)
        validate_receipt(**refusal(p, "fractional-quantity"))

    def test_new_momentum_is_not_admitted(self):
        p = packet()
        p["command"]["speed_q16"] = 1
        self.reject(p)
        validate_receipt(**refusal(p, "unsupported-momentum"))
        p = packet()
        p["receipt"]["cells"][0]["after_motion"] = [0, -1, 0, 0]
        self.reject(p)

    def test_material_policy_and_radius_must_match(self):
        for field, value in [("family", "pressure_flow_v1"), ("radius", 2)]:
            p = packet()
            p["owner"][field] = value
            self.reject(p)
            validate_receipt(**refusal(p, "unsupported-policy"))
        p = packet()
        p["command"]["material"] = 16
        self.reject(p)
        validate_receipt(**refusal(p, "unsupported-material"))

    def test_masked_cell_cannot_be_written(self):
        for op in ("source", "sink", "close_valve", "open_valve"):
            p = packet(op)
            p["receipt"]["cells"][0]["body_id"] = 13
            self.reject(p)
            validate_receipt(**refusal(p, "body-mask"))

    def test_closure_cannot_remove_liquid(self):
        p = packet("close_valve")
        p["receipt"]["cells"][0].update(before_material=3, before_units=255)
        self.reject(p)

    def test_partial_valve_is_refused(self):
        p = packet("close_valve")
        p["command"]["rect"][2] = 2
        c = copy.deepcopy(p["receipt"]["cells"][0])
        c.update(xy=[33, 32], after_material=0, after_state_sha256=c["before_state_sha256"])
        p["receipt"]["cells"].append(c)
        self.reject(p)

    def test_source_cannot_overwrite_foreign_material(self):
        p = packet()
        p["receipt"]["cells"][0]["before_material"] = 16
        self.reject(p)

    def test_sink_cannot_remove_foreign_material(self):
        p = packet("sink")
        p["receipt"]["cells"][0]["before_material"] = 16
        self.reject(p)

    def test_duplicate_or_incomplete_census(self):
        for cells in ([], packet()["receipt"]["cells"] * 2):
            p = packet()
            p["receipt"]["cells"] = cells
            self.reject(p)
        p = packet()
        p["command"]["rect"][2] = 2
        p["receipt"]["cells"] *= 2
        self.reject(p)

    def test_outside_world_refuses(self):
        p = packet()
        p["owner"]["domain"] = [0, 0, 16, 16]
        self.reject(p)
        validate_receipt(**refusal(p, "outside-domain"))

    def test_bound_and_request_capacity(self):
        p = packet()
        p["command"]["rect"][2] = 17
        self.reject(p)
        p = packet()
        p["command"]["requested_units"] = 510
        self.reject(p)

    def test_identity_mismatch_refuses(self):
        for key, value in [("generation", 6), ("policy_sha256", "9" * 64),
                           ("sequence", 39), ("tick", 13), ("command_id", "foreign"),
                           ("before_hash", "9" * 64), ("construction_receipt_sha256", "9" * 64)]:
            p = packet()
            p["receipt"][key] = value
            self.reject(p)

    def test_boolean_float_negative_and_overflow_are_not_quantities(self):
        for value in (True, 255.0, -1, 1 << 64):
            p = packet()
            p["receipt"]["source_units"] = value
            self.reject(p)
        for value in (True, 7.0):
            p = packet()
            p["command"]["generation"] = value
            self.reject(p)

    def test_unexplained_quantity_and_fabricated_budget(self):
        for field in ("stored_before", "stored_after", "supply_before", "supply_after",
                      "sink_budget_before", "sink_budget_after", "source_units", "sink_units"):
            p = packet()
            p["receipt"][field] += 1
            self.reject(p)

    def test_refusal_does_not_hide_state_or_quantity_change(self):
        p = refusal(packet())
        p["receipt"]["after_hash"] = "9" * 64
        self.reject(p)
        p = refusal(packet())
        p["receipt"]["cells"][0]["after_state_sha256"] = "9" * 64
        self.reject(p)

    def test_empty_success_and_empty_refusal_reason(self):
        p = refusal(packet())
        p["receipt"].update(outcome="applied", reason="", after_hash="3" * 64)
        self.reject(p)
        p = refusal(packet())
        p["receipt"]["reason"] = ""
        self.reject(p)

    def test_local_and_global_quantities_cannot_contradict(self):
        p = refusal(packet("sink"))
        p["owner"]["stored_units"] = 0
        p["receipt"].update(stored_before=0, stored_after=0)
        self.reject(p)
        p = packet()
        p["owner"]["stored_units"] = 1
        p["receipt"].update(stored_before=1, stored_after=256)
        self.reject(p)

    def test_world_quantity_respects_domain_capacity(self):
        for material in (3, 24):
            p = packet(material=material)
            p["owner"]["domain"] = [32, 32, 1, 1]
            self.reject(p)
        p = packet()
        p["owner"].update(domain=[32, 32, 1, 1], stored_units=0)
        p["receipt"].update(stored_before=0, stored_after=255)
        validate_receipt(**p)

    def test_every_motion_copy_obeys_native_ranges(self):
        for operation in ("source", "sink", "open_valve", "close_valve"):
            for value in ([0, -999, 0, 0], [33, 0, 0, 0], [0, 0, 16, 0], [True, 0, 0, 0]):
                p = packet(operation)
                p["receipt"]["cells"][0]["after_motion"] = value
                self.reject(p)
        p = refusal(packet("sink"))
        p["receipt"]["cells"][0]["after_motion"] = [1, 0, 0, 0]
        self.reject(p)
        p = packet()
        p["receipt"]["cells"][0]["after_state_sha256"] = p["receipt"]["cells"][0]["before_state_sha256"]
        self.reject(p)


class PlanTests(unittest.TestCase):
    def test_registration(self):
        result = validate_plan(json.loads(PLAN.read_text()))
        self.assertFalse(result["gameplay_qualified"])

    def test_source_lock_cannot_accept_changed_input(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "source.cpp").write_text("changed")
            with self.assertRaises(ContractError):
                source_check({"source_inputs": {"source.cpp": "0" * 64}}, root)

    def test_source_lock_cannot_escape_checkout(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ContractError):
                source_check({"source_inputs": {"../outside": "0" * 64}}, Path(d))

    def test_empty_lock_refuses(self):
        with self.assertRaises(ContractError):
            source_check({"source_inputs": {}})

    def test_planned_cannot_be_relabelled_implemented(self):
        p = json.loads(PLAN.read_text())
        p["fixtures"][0]["execution"] = "passed"
        with self.assertRaises(ContractError):
            validate_plan(p)

    def test_plan_enforces_declared_command_bound(self):
        p = json.loads(PLAN.read_text())
        e = p["fixtures"][0]["events"][0]
        p["fixtures"][0]["events"] = [dict(e, id=str(i)) for i in range(100)]
        with self.assertRaises(ContractError):
            validate_plan(p)

    def test_comparison_respects_real_family_and_radius_admission(self):
        for field, value in [("families", ["freemass_v1"]), ("radius", 2)]:
            p = json.loads(PLAN.read_text())
            p["comparison_arms"][1][field] = value
            with self.assertRaises(ContractError):
                validate_plan(p)


if __name__ == "__main__":
    unittest.main()
