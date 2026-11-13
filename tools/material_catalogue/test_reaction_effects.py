#!/usr/bin/env python3
"""Strict endpoint contracts and actual external native World acceptance."""
from __future__ import annotations
import copy
from pathlib import Path
import tempfile
import unittest
import lab
import reaction_effects as effects
import world_candidate


def salt_candidate():
    candidate = lab.create_candidate(23)
    rule = next(row for row in candidate["reactions"] if row["slot"] == 2)
    rule["effects"]["version"] = 2
    rule["effects"]["second"] = {"kind": "keep_existing"}
    rule["second_product"] = 23
    return candidate, rule


def metal_candidate():
    candidate = lab.create_candidate(28)
    rule = next(row for row in candidate["reactions"] if row["slot"] == 9)
    rule["effects"]["version"] = 2
    rule["effects"]["second"] = {"kind": "set_state", "state_b": 120}
    rule["second_product"] = 28
    rule["probability"] = 255
    return candidate, rule


class ReactionEffectsValidationTests(unittest.TestCase):
    def setUp(self):
        self.native = lab.baseline()["native"]

    def test_admits_explicit_non_water_keep_and_declared_counter(self):
        for candidate, rule in (salt_candidate(), metal_candidate()):
            effects.validate_rule(rule, self.native, "/reaction")
            self.assertTrue(effects.has_extended(candidate))
            self.assertEqual(lab.expand_candidate(candidate)[0], candidate)
            rule["match"] = 0
            effects.validate_rule(rule, self.native, "/reaction")

    def test_versions_are_strict_and_legacy_remains_replacement(self):
        _, rule = salt_candidate()
        for version in (None, True, "2", 2.0, 0, 3):
            rule["effects"]["version"] = version
            with self.subTest(version=version), self.assertRaisesRegex(lab.LabError, "/effects/version"):
                effects.validate_rule(rule, self.native, "/reaction")
        rule["effects"]["version"] = 1
        with self.assertRaisesRegex(lab.LabError, "version 2"):
            effects.validate_rule(rule, self.native, "/reaction")
        legacy = lab.create_candidate(23)
        self.assertFalse(effects.has_extended(legacy))
        for row in legacy["reactions"]:
            effects.validate_rule(row, self.native, "/reaction")

    def test_refuses_water_identity_change_and_positional_effects(self):
        _, rule = salt_candidate()
        cases = []
        changed = copy.deepcopy(rule)
        changed["effects"]["first"] = {"kind": "keep_existing"}
        changed["effects"]["second"] = {"kind": "replace_with_defaults"}
        changed["first_product"] = 3
        cases.append((changed, "Water retention"))
        changed = copy.deepcopy(rule)
        changed["second_product"] = 24
        cases.append((changed, "retain this participant"))
        changed = copy.deepcopy(rule)
        changed["match"] = 2
        cases.append((changed, "positional Symmetric"))
        changed = copy.deepcopy(rule)
        changed["first"] = 12
        changed["first_product"] = 12
        changed["effects"]["first"] = {"kind": "keep_existing"}
        cases.append((changed, "selected no-op"))
        for value, expected in cases:
            with self.subTest(expected=expected), self.assertRaisesRegex(lab.LabError, expected):
                effects.validate_rule(value, self.native, "/reaction")

    def test_refuses_undeclared_state_and_invalid_register_values(self):
        _, rule = metal_candidate()
        for invalid in (-1, 256, True, "120", 120.0, None):
            rule["effects"]["second"]["state_b"] = invalid
            with self.subTest(value=invalid), self.assertRaisesRegex(lab.LabError, "/state_b"):
                effects.validate_rule(rule, self.native, "/reaction")
        for value in (0, 255):
            rule["effects"]["second"]["state_b"] = value
            effects.validate_rule(rule, self.native, "/reaction")
        rule["effects"]["second"]["state_a"] = 1
        with self.assertRaisesRegex(lab.LabError, "unsupported=.*state_a"):
            effects.validate_rule(rule, self.native, "/reaction")
        _, unsupported = salt_candidate()
        unsupported["effects"]["second"] = {"kind": "set_state", "state_b": 1}
        with self.assertRaisesRegex(lab.LabError, "no supported register contract"):
            effects.validate_rule(unsupported, self.native, "/reaction")

    def test_unknown_effect_fields_and_kinds_are_not_approximated(self):
        _, rule = salt_candidate()
        for value in ({"kind": "set_temperature", "temperature": 600},
                      {"kind": "keep_existing", "state_b": 1},
                      {"kind": "replace_with_defaults", "state_b": 1},
                      {"kind": "set_state"}, {"kind": [1]}, None):
            rule["effects"]["second"] = value
            with self.subTest(value=value), self.assertRaises(lab.LabError):
                effects.validate_rule(rule, self.native, "/reaction")

    def test_compiler_probe_cannot_claim_world_effect_execution(self):
        candidate, _ = salt_candidate()
        with self.assertRaisesRegex(lab.LabError, "[Ww]orld"):
            lab.compile_test(candidate)

    def test_preset_round_trip_binds_effect_and_digest(self):
        candidate, _ = metal_candidate()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "charge.json"
            exported = lab.export_candidate(candidate, path)
            imported = lab.import_candidate(path)
            self.assertEqual(imported["candidate"], candidate)
            self.assertEqual(imported["digest"], lab.digest(candidate))
            self.assertEqual(exported["digest"], imported["digest"])

    def test_generated_table_is_deterministic_sparse_and_custodied(self):
        candidate, _ = salt_candidate()
        first = effects.header(candidate, self.native)
        self.assertEqual(first, effects.header(copy.deepcopy(candidate), self.native))
        self.assertEqual(first.count(b"Kind::KeepExisting, 0"), 1)
        self.assertEqual(first.count(b"    Pair{"), 56)
        candidate["reactions"].append(copy.deepcopy(candidate["reactions"][0]))
        with self.assertRaisesRegex(lab.LabError, "duplicate effect slot"):
            effects.header(candidate, self.native)

    def test_world_adapter_preserves_legacy_block_and_requires_exact_source(self):
        source = (lab.ROOT / "native/src/world.cpp").read_text()
        for newline in ("\n", "\r\n"):
            value = source.replace("\n", newline)
            transformed = effects.stage_world(value)
            self.assertEqual(transformed.count(effects.LEGACY_APPLICATION.replace("\n", newline)), 1)
            self.assertEqual(transformed.count('"lab-reaction-effects.hpp"'), 1)
            with self.assertRaisesRegex(lab.LabError, "requires source review"):
                effects.stage_world(value.replace("record_quantity_pair_event(reaction->rule_index, effects);", "changed();"))


class NativeReactionEffectsTests(unittest.TestCase):
    """Every acceptance below compiles and executes two actual native Worlds."""
    def assert_native(self, result, *, expect_change=True):
        self.assertEqual(result["state"], "compiled_tested")
        self.assertFalse(result["runtime_active"])
        receipt = result["receipt"]
        if expect_change:
            self.assertFalse(receipt["comparison"]["equal"])
        for side in ("reference", "candidate"):
            self.assertTrue(all(receipt[side]["checks"].values()), receipt[side]["checks"])
        focused = receipt["candidate"]["effect_contract_checks"]
        self.assertEqual(focused["status"], "passed")
        self.assertEqual(focused["case_count"], 2)
        self.assertEqual({c["layout"] for c in focused["cases"]}, {0, 1})
        for case in focused["cases"]:
            self.assertEqual(case["state_a"], 173)
            self.assertEqual(case["temperature"], 371)
            self.assertEqual(case["pair_events"], 1)
            self.assertTrue(case["same_build_persistence"])
        return receipt, focused["cases"]

    def test_keep_existing_retains_native_state_temperature_and_partial_quantity(self):
        candidate, _ = salt_candidate()
        receipt, cases = self.assert_native(world_candidate.compile_world_test(candidate))
        for case in cases:
            self.assertEqual(case["state_b"], 91)
            self.assertEqual(case["water_consumed"], 83)
            self.assertEqual(case["water_produced"], 0)
        self.assertEqual({case["source_role"] for case in cases}, {"first", "second"})
        final = receipt["candidate"]["final"]
        self.assertEqual(final["material_cells"][23], 384)
        self.assertGreater(final["material_cells"][24], 0)
        self.assertGreater(final["quantity_ledger"]["pair_events"][2], 0)
        self.assertLess(receipt["reference"]["final"]["material_cells"][23], 384)

    def test_set_state_reaches_native_charge_consumer_and_survives_persistence(self):
        candidate, _ = metal_candidate()
        receipt, cases = self.assert_native(world_candidate.compile_world_test(candidate,
            scenario={"first": 12, "second": 28, "seed": 2, "ticks": 120, "workers": 4}))
        for case in cases:
            self.assertEqual(case["state_b"], 120)
            self.assertLess(case["state_b_after_four_ticks"], 120)
            self.assertEqual(case["water_consumed"], 0)
        final = receipt["candidate"]["final"]
        self.assertGreater(final["quantity_ledger"]["pair_events"][9], 0)
        self.assertTrue(any(run[1] == 28 and run[3] > 0 for run in final["grid"]["runs"]))
        self.assertEqual(final["material_cells"][29], 0)
        self.assertGreater(receipt["reference"]["final"]["material_cells"][29], 0)

    def test_declared_first_state_endpoint_is_applied_from_reverse_source(self):
        candidate, rule = metal_candidate()
        rule["first"], rule["second"] = rule["second"], rule["first"]
        rule["first_product"], rule["second_product"] = rule["second_product"], rule["first_product"]
        rule["effects"]["first"], rule["effects"]["second"] = rule["effects"]["second"], rule["effects"]["first"]
        _, cases = self.assert_native(world_candidate.compile_world_test(candidate,
            scenario={"first": 12, "second": 28, "seed": 2, "ticks": 120, "workers": 1}))
        self.assertEqual({case["source_role"] for case in cases}, {"second"})
        self.assertTrue(all(case["state_b"] == 120 for case in cases))

    def test_combustible_state_is_a_real_burn_counter(self):
        candidate = lab.create_candidate(12)
        rule = next(row for row in candidate["reactions"] if row["slot"] == 9)
        rule["second"] = rule["second_product"] = 7
        rule["probability"] = 255
        rule["effects"] = {"version": 2, "first": {"kind": "replace_with_defaults"},
                           "second": {"kind": "set_state", "state_b": 120}}
        _, cases = self.assert_native(world_candidate.compile_world_test(candidate,
            scenario={"first": 12, "second": 7, "seed": 2, "ticks": 120, "workers": 1}))
        self.assertTrue(all(case["retained_material"] == 7 and case["state_b_after_four_ticks"] < 120 for case in cases))

    def test_selected_same_value_effect_uses_bounded_sleep_wake_without_fake_motion(self):
        candidate, rule = metal_candidate()
        rule["first"] = rule["first_product"] = 2
        rule["effects"]["first"] = {"kind": "keep_existing"}
        rule["effects"]["second"]["state_b"] = 0
        _, cases = self.assert_native(world_candidate.compile_world_test(candidate,
            scenario={"first": 2, "second": 28, "seed": 2, "ticks": 120, "workers": 1}), expect_change=False)
        for case in cases:
            self.assertTrue(case["no_value_change"])
            self.assertGreater(case["zero_visited_ticks"], 0)
            self.assertGreaterEqual(case["future_pair_events"], 4)
            self.assertEqual(case["later_moved_cells"], 0)


if __name__ == "__main__":
    unittest.main()
