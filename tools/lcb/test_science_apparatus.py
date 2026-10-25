#!/usr/bin/env python3
"""Adversarial apparatus admission/phase/accounting guards; no physics campaign."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import science_apparatus as a


def action(tick=0, kind="fill", mass=255, coherence=0):
    return {"tick": tick, "kind": kind, "x": 10, "y": 20, "width": 2, "height": 3,
            "material": 3 if kind == "fill" else 0,
            "normalized_mass": mass if kind == "fill" else 0, "coherence": coherence}


def definition(events, bits=8, coherence=12):
    return {"water_semantics": [1, bits, coherence, 0], "events": events}


class NumericAdmission(unittest.TestCase):
    def test_signed_unsigned_extrema_and_canonical_form(self):
        for value in [-(1 << 63), -1, 0, (1 << 63) - 1]:
            self.assertEqual(a.decimal64(str(value)), value)
        for value in [0, 1 << 63, (1 << 64) - 1]:
            self.assertEqual(a.decimal64(str(value), True), value)
        for value in ["-0", "01", "+1", "1.0", " 1", "1 ", "", "1e2", True, 1, None,
                      str(-(1 << 63) - 1), str(1 << 63)]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                a.decimal64(value)
        for value in ["-1", str(1 << 64)]:
            with self.assertRaises(ValueError):
                a.decimal64(value, True)

    def test_duplicate_names_and_nonfinite_json_refuse(self):
        for text in ['{"tick":0,"tick":1}', '{"outer":{"x":0,"x":1}}', '{"value":NaN}', '{"value":Infinity}', '{"value":1e999}']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                a.loads(text)
        self.assertEqual(a.loads('{"x":[0,true,null]}'), {"x": [0, True, None]})

    def test_no_bool_integer_coercion(self):
        for value in [True, False, "1", 1.0]:
            with self.assertRaises(ValueError):
                a.integer(value, 0, 10, "fixture")


class DefinitionBinding(unittest.TestCase):
    def setUp(self):
        import liquid_run_receipt_contract as encoding
        self.definition = {"seed": 0, "events": [action()], "interest": {"policy": "fixed", "region": [0, 0, 96, 96]},
                           "body_enabled": False, "transport_profile": {"version": 1}}
        digest = a.sha(a.canonical_definition(self.definition))
        self.receipt = {"prepared_payload_hash": "12" * 32}
        self.receipt["prepared_setup_hash"] = encoding.setup_hash(bytes.fromhex(self.receipt["prepared_payload_hash"]),
            {"kind": 2, "definition_schema": 2, "definition_digest": digest, "seed": 0,
             "domain": [0, 0, 1024, 1024], "coverage": 2, "gaps": 63}).hex()
        self.sidecar = {"definition_text": json.dumps(self.definition), "definition_hash": digest}

    def test_original_resolved_program_hash_and_native_setup_agree(self):
        a.bind_definition(self.sidecar, self.definition, self.receipt)
        # Integral JSON spelling may differ; a boolean never equals integer0.
        value = copy.deepcopy(self.definition)
        value["seed"] = 0.0
        a.bind_definition(dict(self.sidecar, definition_text=json.dumps(value)), self.definition, self.receipt)

    def test_old_identity_cannot_schedule_a_different_program(self):
        for target in ["event_tick", "event_mass", "interest", "seed", "boolean"]:
            changed = copy.deepcopy(self.definition)
            if target == "event_tick": changed["events"][0]["tick"] = 31
            elif target == "event_mass": changed["events"][0]["normalized_mass"] = 128
            elif target == "interest": changed["interest"]["region"][0] = 1
            elif target == "seed": changed["seed"] = 1
            else: changed["body_enabled"] = 0
            with self.subTest(target=target), self.assertRaises(ValueError):
                a.bind_definition(self.sidecar, changed, self.receipt)

    def test_changing_both_texts_still_cannot_keep_old_hash_or_native_identity(self):
        changed = copy.deepcopy(self.definition)
        changed["events"][0]["tick"] = 31
        sidecar = dict(self.sidecar, definition_text=json.dumps(changed))
        with self.assertRaises(ValueError):
            a.bind_definition(sidecar, changed, self.receipt)
        sidecar["definition_hash"] = a.sha(a.canonical_definition(changed))
        with self.assertRaises(ValueError):
            a.bind_definition(sidecar, changed, self.receipt)


class EventTranslation(unittest.TestCase):
    def test_source_stop_and_completed_phase_boundary(self):
        events = [action(0), action(2), action(3)]
        before = copy.deepcopy(events)
        wire, rows = a.event_wire(definition(events), 3)
        self.assertEqual(wire.decode().splitlines(), ["lcb-science-events-v1 2",
            "0 1 10 20 2 3 3 255 0", "2 1 10 20 2 3 3 255 0"])
        self.assertEqual(rows[-1]["disposition"], "outside_requested_horizon")
        self.assertEqual(events, before)
        self.assertEqual(a.event_wire(definition(events), 0)[0], b"lcb-science-events-v1 0\n")

    def test_identical_same_tick_occurrences_are_retained_in_order(self):
        event = action()
        wire, rows = a.event_wire(definition([event, copy.deepcopy(event), action(kind="erase")]), 1)
        self.assertEqual(len(wire.decode().splitlines()), 4)
        self.assertEqual(wire.decode().splitlines()[1], wire.decode().splitlines()[2])
        self.assertEqual([row["wire_index"] for row in rows], [0, 1, 2])
        self.assertEqual(wire.decode().splitlines()[-1], "0 0 10 20 2 3 0 0 0")

    def test_mass_quantum_live_coherence_and_round_to_zero_are_distinct(self):
        wire, rows = a.event_wire(definition([action(mass=1), action(mass=128, coherence=4)], 3, 6), 1)
        self.assertEqual(rows[0]["disposition"], "rounded_zero_source_noop")
        self.assertEqual(wire, b"lcb-science-events-v1 1\n0 1 10 20 2 3 3 4 4\n")
        # Prepared setup would scale4/12 to2/6; the live adapter retains4.
        self.assertNotEqual(4, (2 * 4 * 6 + 12) // 24)

    def test_sample_is_read_only_and_does_not_become_a_source(self):
        wire, rows = a.event_wire(definition([action(kind="sample")]), 1)
        self.assertEqual(wire, b"lcb-science-events-v1 0\n")
        self.assertEqual(rows[0]["disposition"], "read_only_host_observation")

    def test_bad_order_bounds_type_and_payload_refuse(self):
        invalid = [definition([action(2), action(1)]), definition([action()] * 129)]
        for key, value in [("x", -1), ("width", 1015), ("height", 0), ("tick", True),
                           ("normalized_mass", 0), ("normalized_mass", 256), ("coherence", 13),
                           ("material", 24), ("kind", "paint")]:
            event = action()
            event[key] = value
            invalid.append(definition([event]))
        event = action(kind="erase")
        event["normalized_mass"] = 1
        invalid.append(definition([event]))
        for d in invalid:
            with self.subTest(definition=d), self.assertRaises(ValueError):
                a.event_wire(d, 3)


class MomentumAccounting(unittest.TestCase):
    @staticmethod
    def row(vx, vy, speed, **ledger):
        values = {key: "0" for key in a.LEDGER_KEYS}
        values.update({key: str(value) for key, value in ledger.items()})
        return {"census": {"inertial": {"sum_vx": str(vx), "sum_vy": str(vy), "l1": str(speed)}}, "ledger": values}

    def test_initial_offsets_are_not_assumed_zero(self):
        first = self.row(-20, 30, 50, gravity_y=100, impulse_x=-20, impulse_y=-70, loss=50)
        second = self.row(-18, 34, 52, gravity_y=104, impulse_x=-18, impulse_y=-70, loss=52)
        a.momentum_closure(first, second)

    def test_signed_retirement_and_external_speed_are_separate(self):
        first = self.row(-20, 30, 50)
        retired = self.row(0, 0, 0, retired_x=-20, retired_y=30, velocity_retired=50)
        a.momentum_closure(first, retired)
        external = self.row(-8, 0, 8, retired_x=-20, retired_y=30, velocity_retired=50,
                            external_x=-8, external_speed=8)
        a.momentum_closure(retired, external)

    def test_each_component_and_speed_corruption_refuses(self):
        first = self.row(10, 20, 30)
        second = self.row(8, 22, 30, impulse_x=-2, gravity_y=4, impulse_y=-2, loss=4)
        a.momentum_closure(first, second)
        for key in ["sum_vx", "sum_vy", "l1"]:
            bad = copy.deepcopy(second)
            bad["census"]["inertial"][key] = str(int(bad["census"]["inertial"][key]) + 1)
            with self.subTest(key=key), self.assertRaises(ValueError):
                a.momentum_closure(first, bad)


if __name__ == "__main__":
    unittest.main()
