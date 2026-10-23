#!/usr/bin/env python3
"""MAT-003PREPASS D: bounded, *experimental* GEN-006 codec/failure-contract fixture.

This is NOT a World serializer, chunk loader, persistence implementation, or
admission/eviction proof. Source semantics are deliberately a small subset:
material catalogue 0..131 except 10, Water 1..255/coherence <=12 and non-Water
state_a <=255. All identities below are synthetic fixture identities.
Run: python3 tools/experiments/mat003_gen006_codec_fixture.py
"""
from __future__ import annotations

import copy
import hashlib
import json
import struct
import unittest

MAGIC = b"CSG6X1\x00\x00"
HEADER = struct.Struct("<8sHI32s")  # magic, experimental version, payload length, SHA-256
WIRE_VERSION = 1
MAX_PAYLOAD = 65536
MAX_SIDE = 8
MAX_CELLS = MAX_SIDE * MAX_SIDE
IDENTITIES = {
    "catalogue": "fixture-mat002-catalogue-v1",
    "solver": "fixture-native-solver-v1",
    "state_schema": "fixture-state-schema-v1",
    "recipe": "fixture-gen005-recipe-v1",
    "baseline": "fixture-immutable-baseline-v1",
}
VALID_MATERIALS = frozenset(range(132)) - {10}


class Refusal(ValueError):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def refuse(code: str) -> None:
    raise Refusal(code)


def integer(value: object, lower: int, upper: int) -> bool:
    return type(value) is int and lower <= value <= upper


def bounded_id(value: object) -> bool:
    return isinstance(value, str) and 1 <= len(value) <= 128 and all(
        32 < ord(ch) < 127 for ch in value
    )


def canonical(data: object) -> bytes:
    try:
        return json.dumps(
            data, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
            allow_nan=False,
        ).encode("ascii")
    except (TypeError, ValueError):
        refuse("MALFORMED_PAYLOAD")


def unique_pairs(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            refuse("DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def _cell(cell: object, side: int) -> int:
    if not isinstance(cell, dict):
        refuse("TRUNCATED_STATE")
    keys = {"index", "material_id", "state_a", "state_b", "touched_last_tick"}
    if keys - cell.keys():
        refuse("TRUNCATED_STATE")
    idx, material, a, b = (cell[k] for k in ("index", "material_id", "state_a", "state_b"))
    if not integer(idx, 0, side * side - 1):
        refuse("INVALID_CELL_INDEX")
    if not integer(material, 0, 65535) or material not in VALID_MATERIALS:
        refuse("UNKNOWN_MATERIAL")
    if not integer(a, 0, 65535) or not integer(b, 0, 255) or type(cell["touched_last_tick"]) is not bool:
        refuse("INVALID_STATE")
    if material == 3:
        if not (1 <= a <= 255 and b <= 12):
            refuse("INVALID_WATER_STATE")
    elif a > 255:
        refuse("INVALID_STATE")
    # Cloner (5) and Rocket (17) encode material references in state_b.
    # Zero is a legitimate uncaptured/unconfigured sentinel. A reserved or
    # unknown nonzero reference is incompatible rather than silently remapped.
    if material in (5, 17) and b != 0 and b not in VALID_MATERIALS:
        refuse("UNKNOWN_MATERIAL")
    return idx


def _ordered_unique_indices(values: object, key: str, count: int, code: str) -> None:
    if not isinstance(values, list) or len(values) > count:
        refuse(code)
    last = -1
    for item in values:
        if not isinstance(item, dict) or not integer(item.get(key), 0, count - 1):
            refuse(code)
        if item[key] <= last:
            refuse(code)
        last = item[key]


def validate(record: object) -> None:
    if not isinstance(record, dict):
        refuse("MALFORMED_PAYLOAD")
    expected = {
        "format", "version", "world_id", "chunk", "identities",
        "mutation_generation", "completed_tick", "ambient_temperature",
        "cells", "intents", "activity", "pending_boundary", "features", "sidecars",
        "required_extensions",
    }
    if expected - record.keys():
        refuse("TRUNCATED_STATE")
    if record.keys() - expected:
        refuse("UNKNOWN_REQUIRED_FIELD")
    if record["format"] != "cybersand.semantic.chunk.experimental" or record["version"] != WIRE_VERSION:
        refuse("INCOMPATIBLE_SCHEMA")
    if not bounded_id(record["world_id"]):
        refuse("INVALID_WORLD")
    chunk = record["chunk"]
    if not isinstance(chunk, dict) or set(chunk) != {"x", "y", "plane", "side"}:
        refuse("INVALID_CHUNK")
    if not all(integer(chunk[k], -(1 << 63), (1 << 63) - 1) for k in ("x", "y")):
        refuse("INVALID_CHUNK")
    if chunk["plane"] not in ("play", "scripted", "effects", "background"):
        refuse("INVALID_CHUNK")
    side = chunk["side"]
    if not integer(side, 1, MAX_SIDE):
        refuse("CAPACITY_REFUSAL")
    if record["identities"] != IDENTITIES:
        refuse("INCOMPATIBLE_IDENTITY")
    if not integer(record["mutation_generation"], 0, (1 << 64) - 1):
        refuse("INVALID_GENERATION")
    if not integer(record["completed_tick"], 0, (1 << 64) - 1):
        refuse("INVALID_CLOCK")
    if not integer(record["ambient_temperature"], -32768, 32767):
        refuse("INVALID_TEMPERATURE")
    _ordered_unique_indices(record["cells"], "index", side * side, "DUPLICATE_CELL")
    for cell in record["cells"]:
        _cell(cell, side)
    if not isinstance(record["intents"], list) or len(record["intents"]) > MAX_CELLS:
        refuse("CAPACITY_REFUSAL")
    seen_ids: set[str] = set()
    for intent in record["intents"]:
        if not isinstance(intent, dict) or not {"operation_id", "index", "kind", "origin", "generation"} <= intent.keys():
            refuse("TRUNCATED_STATE")
        if not bounded_id(intent["operation_id"]) or intent["operation_id"] in seen_ids:
            refuse("DUPLICATE_MUTATION")
        seen_ids.add(intent["operation_id"])
        if not integer(intent["index"], 0, side * side - 1):
            refuse("INVALID_CELL_INDEX")
        if intent["kind"] not in ("explicit_empty", "set", "same_value", "simulation"):
            refuse("INVALID_INTENT")
        if intent["origin"] not in ("player", "simulation", "reconcile"):
            refuse("INVALID_INTENT")
        if not integer(intent["generation"], 0, record["mutation_generation"]):
            refuse("INVALID_GENERATION")
    if not isinstance(record["activity"], list) or len(record["activity"]) > MAX_CELLS:
        refuse("CAPACITY_REFUSAL")
    _ordered_unique_indices(record["activity"], "index", side * side, "DUPLICATE_ACTIVITY")
    for block in record["activity"]:
        if not ({"active", "quiet_ticks", "next_interaction_tick"} <= block.keys()
                and type(block["active"]) is bool
                and integer(block["quiet_ticks"], 0, (1 << 32) - 1)
                and integer(block["next_interaction_tick"], 0, (1 << 64) - 1)):
            refuse("INVALID_ACTIVITY")
    if not isinstance(record["sidecars"], list) or len(record["sidecars"]) > 4:
        refuse("CAPACITY_REFUSAL")
    seen_fields: set[str] = set()
    for sidecar in record["sidecars"]:
        if not isinstance(sidecar, dict) or set(sidecar) != {"field", "schema", "values"}:
            refuse("SIDECAR_SCHEMA")
        if sidecar["field"] != "temperature" or sidecar["schema"] != "fixture-temp-i16-v1":
            refuse("SIDECAR_SCHEMA")
        if sidecar["field"] in seen_fields:
            refuse("DUPLICATE_SIDECAR")
        seen_fields.add(sidecar["field"])
        _ordered_unique_indices(sidecar["values"], "index", side * side, "SIDECAR_SCHEMA")
        for value in sidecar["values"]:
            if set(value) != {"index", "value"} or not integer(value["value"], -32768, 32767):
                refuse("SIDECAR_SCHEMA")
    for family, maximum in (("pending_boundary", 16), ("features", 16)):
        values = record[family]
        if not isinstance(values, list) or len(values) > maximum:
            refuse("CAPACITY_REFUSAL")
        ids: set[str] = set()
        for obj in values:
            if not isinstance(obj, dict) or not bounded_id(obj.get("id")) or obj["id"] in ids:
                refuse("INVALID_PENDING_OR_FEATURE")
            ids.add(obj["id"])
    for event in record["pending_boundary"]:
        if set(event) != {"id", "from", "to", "kind", "amount"}:
            refuse("INVALID_PENDING_OR_FEATURE")
        if (event["kind"] not in ("transfer", "explosion") or
            not integer(event["amount"], 0, 65535)):
            refuse("INVALID_PENDING_OR_FEATURE")
        for end in ("from", "to"):
            if (not isinstance(event[end], list) or len(event[end]) != 2 or
                not all(integer(v, -(1 << 63), (1 << 63) - 1) for v in event[end])):
                refuse("INVALID_PENDING_OR_FEATURE")
    for feature in record["features"]:
        if set(feature) != {"id", "lifecycle"} or feature["lifecycle"] not in ("active", "retired"):
            refuse("INVALID_PENDING_OR_FEATURE")
    if record["required_extensions"] != []:
        refuse("UNKNOWN_REQUIRED_EXTENSION")


def encode(record: object) -> bytes:
    validate(record)
    payload = canonical(record)
    if len(payload) > MAX_PAYLOAD:
        refuse("CAPACITY_REFUSAL")
    return HEADER.pack(MAGIC, WIRE_VERSION, len(payload), hashlib.sha256(payload).digest()) + payload


def decode(blob: bytes) -> dict:
    if not isinstance(blob, bytes) or len(blob) < HEADER.size:
        refuse("TRUNCATED_ENVELOPE")
    magic, version, length, digest = HEADER.unpack_from(blob)
    if magic != MAGIC or version != WIRE_VERSION:
        refuse("INCOMPATIBLE_SCHEMA")
    if length > MAX_PAYLOAD or len(blob) != HEADER.size + length:
        refuse("MALFORMED_LENGTH")
    payload = blob[HEADER.size:]
    if hashlib.sha256(payload).digest() != digest:
        refuse("CHECKSUM_FAILURE")
    try:
        obj = json.loads(payload, object_pairs_hook=unique_pairs)
    except Refusal:
        raise  # Preserve an explicit duplicate-key refusal from the parser.
    except (ValueError, UnicodeDecodeError):
        refuse("MALFORMED_PAYLOAD")
    validate(obj)
    return obj


def admitted_result(receipt: dict, live: dict) -> bool:
    """Simulate an exclusive-owner late-result fence, not a World admission."""
    for field in ("world_id", "session_id", "chunk", "plane", "incarnation",
                  "mutation_generation", "recipe", "baseline", "job_id"):
        if receipt.get(field) != live.get(field):
            refuse("STALE_RESULT")
    return True


def admit_mutation(record: dict, operation: dict, seen: dict[str, str]) -> tuple[dict, str]:
    """Exercise explicit intent, exactly-once receipt and CAS generation only."""
    if not isinstance(operation, dict) or set(operation) != {
        "id", "expected_generation", "new_generation", "index", "kind", "origin"
    } or not bounded_id(operation["id"]):
        refuse("INVALID_MUTATION")
    fingerprint = hashlib.sha256(canonical(operation)).hexdigest()
    if operation["id"] in seen:
        if seen[operation["id"]] == fingerprint:
            return record, "DUPLICATE_NOOP"
        refuse("DUPLICATE_CONFLICT")
    g = record["mutation_generation"]
    if not integer(operation["expected_generation"], 0, (1 << 64) - 1) or operation["expected_generation"] != g:
        refuse("STALE_GENERATION")
    if g == (1 << 64) - 1 or operation["new_generation"] != g + 1:
        refuse("GENERATION_GAP")
    if not integer(operation["index"], 0, record["chunk"]["side"] ** 2 - 1):
        refuse("INVALID_CELL_INDEX")
    if operation["kind"] not in ("same_value", "explicit_empty", "set", "simulation") or operation["origin"] not in ("player", "simulation", "reconcile"):
        refuse("INVALID_MUTATION")
    output = copy.deepcopy(record)
    output["mutation_generation"] += 1
    output["intents"].append({
        "operation_id": operation["id"], "index": operation["index"],
        "kind": operation["kind"], "origin": operation["origin"],
        "generation": output["mutation_generation"],
    })
    validate(output)
    seen[operation["id"]] = fingerprint
    return output, "ADMITTED"


def sample() -> dict:
    return {
        "format": "cybersand.semantic.chunk.experimental",
        "version": WIRE_VERSION,
        "world_id": "fixture-world",
        "chunk": {"x": -1, "y": 0, "plane": "play", "side": 8},
        "identities": dict(IDENTITIES),
        "mutation_generation": 7,
        "completed_tick": 255,
        "ambient_temperature": 200,
        "cells": [
            {"index": 0, "material_id": 3, "state_a": 127, "state_b": 12, "touched_last_tick": True},
            {"index": 2, "material_id": 0, "state_a": 0, "state_b": 0, "touched_last_tick": False},
        ],
        "intents": [
            {"operation_id": "same-value-edit", "index": 0, "kind": "same_value", "origin": "player", "generation": 6},
            {"operation_id": "erase-old-baseline", "index": 2, "kind": "explicit_empty", "origin": "player", "generation": 7},
        ],
        "activity": [{"index": 0, "active": True, "quiet_ticks": 2, "next_interaction_tick": 260}],
        "pending_boundary": [{"id": "transfer-1", "from": [-1, 0], "to": [0, 0], "kind": "transfer", "amount": 7}],
        "features": [{"id": "old-source-fixture", "lifecycle": "retired"}],
        "sidecars": [{"field": "temperature", "schema": "fixture-temp-i16-v1",
                      "values": [{"index": 1, "value": 410}]}],
        "required_extensions": [],
    }


class ExperimentalCodecTests(unittest.TestCase):
    def refusal(self, record: dict, code: str) -> None:
        with self.assertRaises(Refusal) as caught:
            decode(encode(record))  # validates before encode
        self.assertEqual(caught.exception.code, code)

    def test_roundtrip_negative_chunk_water_intent_and_boundary(self) -> None:
        fixture = sample()
        self.assertEqual(decode(encode(fixture)), fixture)
        self.assertEqual(fixture["chunk"]["x"], -1)
        self.assertEqual(fixture["intents"][1]["kind"], "explicit_empty")

    def test_optional_sidecar_absence_has_default(self) -> None:
        fixture = sample()
        fixture["sidecars"] = []
        self.assertEqual(decode(encode(fixture))["sidecars"], [])
        self.assertEqual(fixture["ambient_temperature"], 200)

    def test_corrupted_checksum(self) -> None:
        raw = bytearray(encode(sample()))
        raw[-1] ^= 1
        with self.assertRaisesRegex(Refusal, "CHECKSUM_FAILURE"):
            decode(bytes(raw))

    def test_short_envelope(self) -> None:
        with self.assertRaisesRegex(Refusal, "TRUNCATED_ENVELOPE"):
            decode(b"CS")

    def test_malformed_lengths_and_trailing_bytes(self) -> None:
        raw = bytearray(encode(sample()))
        struct.pack_into("<I", raw, 10, MAX_PAYLOAD + 1)
        with self.assertRaisesRegex(Refusal, "MALFORMED_LENGTH"):
            decode(bytes(raw))
        with self.assertRaisesRegex(Refusal, "MALFORMED_LENGTH"):
            decode(encode(sample()) + b"tail")

    def test_unknown_material_and_reserved_id(self) -> None:
        for value in (10, 132, 65535):
            fixture = sample()
            fixture["cells"][0]["material_id"] = value
            self.refusal(fixture, "UNKNOWN_MATERIAL")

    def test_state_carried_material_reference_refuses_unknown(self) -> None:
        for material in (5, 17):
            fixture = sample()
            fixture["cells"][0].update(material_id=material, state_a=0, state_b=10)
            self.refusal(fixture, "UNKNOWN_MATERIAL")

    def test_duplicate_json_key_with_valid_hash(self) -> None:
        payload = encode(sample())[HEADER.size:]
        self.assertIn(b'\x22world_id\x22:\x22fixture-world\x22', payload)
        payload = payload.replace(b'\x22world_id\x22:\x22fixture-world\x22',
                                  b'\x22world_id\x22:\x22fixture-world\x22,\x22world_id\x22:\x22other\x22', 1)
        raw = HEADER.pack(MAGIC, WIRE_VERSION, len(payload),
                          hashlib.sha256(payload).digest()) + payload
        with self.assertRaisesRegex(Refusal, "DUPLICATE_JSON_KEY"):
            decode(raw)

    def test_truncated_state(self) -> None:
        fixture = sample()
        del fixture["cells"][0]["state_a"]
        self.refusal(fixture, "TRUNCATED_STATE")

    def test_incompatible_schema_and_identity(self) -> None:
        fixture = sample()
        fixture["version"] = 2
        self.refusal(fixture, "INCOMPATIBLE_SCHEMA")
        fixture = sample()
        fixture["identities"]["catalogue"] = "unknown-catalogue"
        self.refusal(fixture, "INCOMPATIBLE_IDENTITY")
        fixture = sample()
        fixture["identities"]["solver"] = "unknown-solver"
        self.refusal(fixture, "INCOMPATIBLE_IDENTITY")

    def test_state_domain_refusal(self) -> None:
        fixture = sample()
        fixture["cells"][0]["state_a"] = 0
        self.refusal(fixture, "INVALID_WATER_STATE")
        fixture = sample()
        fixture["cells"][0]["state_b"] = 13
        self.refusal(fixture, "INVALID_WATER_STATE")

    def test_duplicate_cell_and_intent(self) -> None:
        fixture = sample()
        fixture["cells"].append(copy.deepcopy(fixture["cells"][-1]))
        self.refusal(fixture, "DUPLICATE_CELL")
        fixture = sample()
        fixture["intents"][1]["operation_id"] = "same-value-edit"
        self.refusal(fixture, "DUPLICATE_MUTATION")

    def test_invalid_sidecar_and_capacity(self) -> None:
        fixture = sample()
        fixture["sidecars"][0]["values"][0]["value"] = 40000
        self.refusal(fixture, "SIDECAR_SCHEMA")
        fixture = sample()
        fixture["chunk"]["side"] = 65536
        self.refusal(fixture, "CAPACITY_REFUSAL")

    def test_unknown_required_extension(self) -> None:
        fixture = sample()
        fixture["required_extensions"] = ["unregistered-pressure-v1"]
        self.refusal(fixture, "UNKNOWN_REQUIRED_EXTENSION")

    def test_stale_result_refusal_all_identifiers(self) -> None:
        live = {"world_id": "world", "session_id": "session2", "chunk": (-1, 0),
                "plane": "play", "incarnation": 10, "mutation_generation": 7,
                "recipe": "recipe", "baseline": "baseline", "job_id": "job19"}
        self.assertTrue(admitted_result(dict(live), live))
        for field in live:
            stale = dict(live)
            stale[field] = "stale"
            with self.assertRaisesRegex(Refusal, "STALE_RESULT"):
                admitted_result(stale, live)

    def test_duplicate_operation_idempotent_conflict_and_stale(self) -> None:
        fixture = sample()
        seen: dict[str, str] = {}
        op = {"id": "intent-8", "expected_generation": 7, "new_generation": 8,
              "index": 2, "kind": "explicit_empty", "origin": "player"}
        newer, status = admit_mutation(fixture, op, seen)
        self.assertEqual(status, "ADMITTED")
        self.assertEqual(newer["mutation_generation"], 8)
        self.assertEqual(newer["intents"][-1]["kind"], "explicit_empty")
        again, status = admit_mutation(newer, op, seen)
        self.assertEqual(status, "DUPLICATE_NOOP")
        self.assertIs(again, newer)
        changed = dict(op, kind="set")
        with self.assertRaisesRegex(Refusal, "DUPLICATE_CONFLICT"):
            admit_mutation(newer, changed, seen)
        with self.assertRaisesRegex(Refusal, "STALE_GENERATION"):
            admit_mutation(newer, dict(op, id="other"), seen)

    def test_no_raw_carrier_or_epoch_in_wire_payload(self) -> None:
        raw = encode(sample())
        self.assertNotIn(b"raw_bits", raw)
        self.assertNotIn(b"update_epoch", raw)
        self.assertIn(b"touched_last_tick", raw)


if __name__ == "__main__":
    unittest.main(verbosity=2)
