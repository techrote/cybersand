#!/usr/bin/env python3
"""Standalone LCB-000 Gate C liquid-policy wire/hash contract oracle.

This is an executable specification of the *Proposed* `LiquidSolverPolicy`
request envelope, its canonical hash bytes, validation precedence, refusal and
applied readback (docs/architecture/liquid-solver-family-policy.md,
"Request envelope and canonical hash"). It implements no native policy, World
or solver; #200/#212 own the native implementation and must reproduce these
vectors bit for bit.

    python tools/lcb/policy_contract.py          # rewrite the vector file
    python tools/lcb/policy_contract.py --check  # fail if it is stale
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MATRIX = ROOT / "docs/reference/liquid-solver-capability-matrix.json"
VECTORS = ROOT / "docs/reference/liquid-policy-wire-vectors.json"
CATALOGUE_SOURCES = ("native/include/cybersand/material.hpp",
                     "native/include/cybersand/interaction_rules.hpp")

MAGIC = 0x4C435057  # ASCII "LCPW", big-endian
ENVELOPE_VERSION = 1
POLICY_VERSION = 1
DIGEST_WORDS = 8
HEADER_WORDS = 3 + 2 * DIGEST_WORDS
MAX_BLOCK_WORDS = 64
RESERVED_IDS = {10}
INT32_MIN, INT32_MAX = -(1 << 31), (1 << 31) - 1
DOMAIN_POLICY = b"lcb-liquid-policy\x00"
DOMAIN_CATALOGUE = b"lcb-material-catalogue-v1\x00"
DOMAIN_CAPABILITY = b"lcb-capability-matrix-v1\x00"

FAMILIES = {"freemass_v1": 1, "cellular_yield_v1": 2, "pressure_flow_v1": 3, "inertial_cellular_v1": 4}
VARIANTS = {"reference": 0, "cached": 1, "cached_dormant": 2}
FAMILY_NAMES = {v: k for k, v in FAMILIES.items()}
VARIANT_NAMES = {v: k for k, v in VARIANTS.items()}
MATERIAL_DEFAULT = 0  # request-only family code; never applied, hashed or read back

# Illustrative contract-test parameter schemas. They exercise the block rules;
# #200/#212 replace them by appending block versions. No value is frozen here.
# key: (owner kind, owner code, block_version) -> (fields, mandatory, gate)
BLOCK_SCHEMAS = {
    ("family", 4, 1): {"fields": (("damping_q16", 0, 65536), ("speed_cap_q8", 256, 2048)),
                       "mandatory": True},
    ("material", 3, 1): {"fields": (("flow_rate_permille", 1, 1000),),
                         "mandatory": False, "requires_family": 2},
}

REFUSAL_CODES = (
    "unknown_material", "not_a_liquid", "unknown_family", "unknown_variant", "family_unavailable",
    "combination_rejected", "variant_unsupported", "water_semantics_incompatible",
    "platform_unsupported", "capacity_refused", "stale_capability_matrix", "malformed_policy",
    "unknown_parameter", "not_selectable", "normalization_required")
NATIVE_ONLY_CODES = ("water_semantics_incompatible", "capacity_refused", "normalization_required")


class Refusal(Exception):
    def __init__(self, code: str, detail: str, material: int | None = None):
        assert code in REFUSAL_CODES, code
        super().__init__(f"{code}: {detail}")
        self.code, self.detail, self.material = code, detail, material

    def as_dict(self) -> dict:
        return {"code": self.code, "material": self.material, "detail": self.detail}


# ---------------------------------------------------------------- identities

def _lf(path: Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


def catalogue_digest(root: Path = ROOT) -> str:
    """SHA-256 over the domain tag and each catalogue source as u32 length-prefixed path and bytes."""
    h = hashlib.sha256(DOMAIN_CATALOGUE)
    for rel in CATALOGUE_SOURCES:
        data = _lf(root / rel)
        h.update(struct.pack("<I", len(rel)) + rel.encode() + struct.pack("<I", len(data)) + data)
    return h.hexdigest()


def capability_matrix_digest(matrix_bytes: bytes) -> str:
    """SHA-256 over the domain tag and the LF-normalized generated matrix file.

    The file embeds both the parsed source-fact digests and every reviewed
    design classification (status, variants, notes, specialization text), so a
    reclassification changes this digest even when no source file changes.
    """
    return hashlib.sha256(DOMAIN_CAPABILITY + matrix_bytes.replace(b"\r\n", b"\n")).hexdigest()


def digest_to_words(hexdigest: str) -> list[int]:
    raw = bytes.fromhex(hexdigest)
    assert len(raw) == 32
    return [struct.unpack(">i", raw[i:i + 4])[0] for i in range(0, 32, 4)]


def words_to_digest(words: list[int]) -> str:
    return b"".join(struct.pack(">I", w & 0xFFFFFFFF) for w in words).hex()


# ------------------------------------------------------------------- build

def load_matrix(matrix_bytes: bytes) -> dict:
    data = json.loads(matrix_bytes)
    rows = {}
    for row in data["liquid_rows"]:
        cells = {}
        default = None
        for fam, cell in row["families"].items():
            cells[FAMILIES[fam]] = {"status": cell["status"], "variants": [VARIANTS[v] for v in cell["variants"]]}
            if cell["status"] == "current_default":
                default = FAMILIES[fam]
        rows[row["material_id"]] = {"name": row["name"], "default": default, "cells": cells}
    return {"descriptor_count": data["material_descriptor_count"], "liquids": rows}


def make_build(matrix_bytes: bytes, catalogue: str, available=(1, 2), native: bool = True,
               qualified=None, schemas=None) -> dict:
    """A running build's identity. `available` = family codes compiled and qualified.

    `qualified`, when given, further restricts admission to those (material, family)
    cells. A family compiled for some materials is not thereby qualified for every
    matrix-selectable material (LCB-001 #200 reconciliation, 2026-10-24).
    """
    return {"catalogue_digest": catalogue, "capability_matrix_digest": capability_matrix_digest(matrix_bytes),
            "matrix": load_matrix(matrix_bytes), "available": tuple(sorted(available)), "native": native,
            "qualified": None if qualified is None else frozenset(qualified),
            **({} if schemas is None else {"schemas": schemas})}


def current_default_cells(matrix_bytes: bytes) -> frozenset:
    """The (material, family) cells a build that executes only current defaults has qualified."""
    return frozenset((m, row["default"]) for m, row in load_matrix(matrix_bytes)["liquids"].items())


def default_assignments(build: dict) -> list[tuple[int, int, int]]:
    return [(m, row["default"], VARIANTS["reference"]) for m, row in sorted(build["matrix"]["liquids"].items())]


# ------------------------------------------------------------------ encode

def encode(policy: dict) -> list[int]:
    """Policy dict -> one flat int32 envelope (the only wire form)."""
    words = [MAGIC, policy.get("envelope_version", ENVELOPE_VERSION), policy["policy_version"]]
    words += digest_to_words(policy["catalogue_digest"]) + digest_to_words(policy["capability_matrix_digest"])
    words.append(len(policy["assignments"]))
    for a in policy["assignments"]:
        words += list(a)
    for key in ("family_blocks", "material_blocks"):
        words.append(len(policy[key]))
        for owner, version, values in policy[key]:
            words += [owner, version, len(values)] + list(values)
    return words


def policy_for(build: dict, assignments=None, family_blocks=(), material_blocks=(), **override) -> dict:
    p = {"policy_version": POLICY_VERSION, "catalogue_digest": build["catalogue_digest"],
         "capability_matrix_digest": build["capability_matrix_digest"],
         "assignments": list(assignments if assignments is not None else default_assignments(build)),
         "family_blocks": [tuple(b) for b in family_blocks], "material_blocks": [tuple(b) for b in material_blocks]}
    p.update(override)
    return p


# ------------------------------------------------------------------ decode

class _Reader:
    def __init__(self, words: list[int]):
        self.words, self.pos = words, 0

    def take(self, what: str) -> int:
        if self.pos >= len(self.words):
            raise Refusal("malformed_policy", f"truncated at word {self.pos} ({what})")
        w = self.words[self.pos]
        self.pos += 1
        return w

    def unsigned(self, what: str, maximum: int) -> int:
        w = self.take(what)
        if w < 0 or w > maximum:
            raise Refusal("malformed_policy", f"{what}={w} outside 0..{maximum} at word {self.pos - 1}")
        return w


def decode(words: list[int], build: dict) -> dict:
    """Validate an envelope against a build and return the normalized applied policy.

    Raises Refusal with the first failure in the documented precedence order.
    """
    # 1. Transport integrity: every element is an int32.
    for i, w in enumerate(words):
        if not isinstance(w, int) or isinstance(w, bool) or w < INT32_MIN or w > INT32_MAX:
            raise Refusal("malformed_policy", f"word {i} is not a signed 32-bit integer")
    liquids = build["matrix"]["liquids"]
    r = _Reader(words)
    # 2. Header.
    if len(words) < HEADER_WORDS + 3:
        raise Refusal("malformed_policy", f"envelope has {len(words)} words; minimum {HEADER_WORDS + 3}")
    if r.take("magic") != MAGIC:
        raise Refusal("malformed_policy", "bad magic")
    if r.take("envelope_version") != ENVELOPE_VERSION:
        raise Refusal("malformed_policy", "unknown envelope_version")
    if r.take("policy_version") != POLICY_VERSION:
        raise Refusal("malformed_policy", "unknown policy_version")
    cat = words_to_digest([r.take("catalogue_digest") for _ in range(DIGEST_WORDS)])
    cap = words_to_digest([r.take("capability_matrix_digest") for _ in range(DIGEST_WORDS)])
    # 3. Identity: compared before any catalogue-dependent interpretation.
    if cat != build["catalogue_digest"]:
        raise Refusal("stale_capability_matrix", "catalogue_digest differs from the running build")
    if cap != build["capability_matrix_digest"]:
        raise Refusal("stale_capability_matrix", "capability_matrix_digest differs from the running build")
    # 4. Section structure: counts, lengths and exact consumption.
    n = r.unsigned("assignment_count", len(liquids))
    raw_assign = [(r.unsigned("material_id", 0xFFFF), r.unsigned("family_code", 0xFF), r.unsigned("variant_code", 0xFF))
                  for _ in range(n)]
    blocks = {}
    for kind, limit_count, limit_owner in (("family", len(FAMILIES), 0xFF), ("material", len(liquids), 0xFFFF)):
        count = r.unsigned(f"{kind}_block_count", limit_count)
        blocks[kind] = []
        for _ in range(count):
            owner = r.unsigned(f"{kind}_block_owner", limit_owner)
            version = r.unsigned(f"{kind}_block_version", 0xFFFF)
            length = r.unsigned(f"{kind}_block_word_length", MAX_BLOCK_WORDS)
            blocks[kind].append((owner, version, [r.take(f"{kind}_block_value") for _ in range(length)]))
    if r.pos != len(words):
        raise Refusal("malformed_policy", f"{len(words) - r.pos} trailing words")
    # 5. Assignment identity and order.
    for m, f, v in raw_assign:
        if m >= build["matrix"]["descriptor_count"] or m in RESERVED_IDS:
            raise Refusal("unknown_material", "material id outside the catalogue or reserved", m)
        if m not in liquids:
            raise Refusal("not_a_liquid", "assignment to a non-liquid descriptor", m)
        if f != MATERIAL_DEFAULT and f not in FAMILY_NAMES:
            raise Refusal("unknown_family", f"family_code {f}", m)
        if v not in VARIANT_NAMES:
            raise Refusal("unknown_variant", f"variant_code {v}", m)
    ids = [a[0] for a in raw_assign]
    if any(b <= a for a, b in zip(ids, ids[1:])):
        raise Refusal("malformed_policy", "material ids not strictly ascending (duplicate or unsorted)")
    missing = sorted(set(liquids) - set(ids))
    if missing:
        raise Refusal("malformed_policy", f"incomplete assignments; missing {missing}", missing[0])
    # 6. Normalization: request code 0 becomes the material's default family.
    assignments = []
    for m, f, v in raw_assign:
        if f == MATERIAL_DEFAULT:
            if v != VARIANTS["reference"]:
                raise Refusal("malformed_policy", "material-default family requires reference variant", m)
            f = liquids[m]["default"]
        assignments.append((m, f, v))
    # 7. Matrix and build qualification.
    for m, f, v in assignments:
        cell = liquids[m]["cells"][f]
        if cell["status"] == "rejected":
            raise Refusal("combination_rejected", f"{liquids[m]['name']} x {FAMILY_NAMES[f]}", m)
        if cell["status"] == "proposed_alternate" or not cell["variants"]:
            raise Refusal("not_selectable", f"{liquids[m]['name']} x {FAMILY_NAMES[f]}", m)
        if v not in cell["variants"]:
            raise Refusal("variant_unsupported", f"{VARIANT_NAMES[v]} for {FAMILY_NAMES[f]}", m)
        is_default = f == liquids[m]["default"] and v == VARIANTS["reference"]
        if not build["native"] and not is_default:
            raise Refusal("platform_unsupported", "host has no native policy handshake", m)
        if f not in build["available"]:
            raise Refusal("family_unavailable", f"{FAMILY_NAMES[f]} is not compiled/qualified in this build", m)
        if build["qualified"] is not None and (m, f) not in build["qualified"]:
            raise Refusal("family_unavailable", f"{FAMILY_NAMES[f]} is not qualified for material {m} in this build", m)
    # 8. Parameter blocks. Historical vector profiles keep their original
    # illustrative schemas; native successor contracts can name an explicit set.
    schemas = build.get("schemas", BLOCK_SCHEMAS)
    family_of = {m: f for m, f, _ in assignments}
    used = set(family_of.values())
    for kind in ("family", "material"):
        owners = [b[0] for b in blocks[kind]]
        if any(b <= a for a, b in zip(owners, owners[1:])):
            raise Refusal("malformed_policy", f"{kind} blocks not strictly ascending (duplicate or unsorted)")
        for owner, version, values in blocks[kind]:
            schema = schemas.get((kind, owner, version))
            if schema is None:
                raise Refusal("unknown_parameter", f"unknown {kind} block ({owner}, v{version})")
            if len(values) != len(schema["fields"]):
                raise Refusal("unknown_parameter", f"{kind} block ({owner}, v{version}) has {len(values)} words; "
                                                   f"schema has {len(schema['fields'])}")
            if kind == "family" and owner not in used:
                raise Refusal("malformed_policy", f"extra family block for unassigned {FAMILY_NAMES[owner]}")
            if kind == "material" and family_of.get(owner) != schema["requires_family"]:
                raise Refusal("malformed_policy", f"material block ({owner}, v{version}) not declared by the "
                                                  "material's applied family", owner)
            for (name, lo, hi), value in zip(schema["fields"], values):
                if not lo <= value <= hi:
                    raise Refusal("malformed_policy", f"{name}={value} outside {lo}..{hi}")
    for (kind, owner, _), schema in schemas.items():
        if kind == "family" and schema["mandatory"] and owner in used \
                and owner not in [b[0] for b in blocks["family"]]:
            raise Refusal("unknown_parameter", f"missing mandatory family block for {FAMILY_NAMES[owner]}")
    return {"policy_version": POLICY_VERSION, "catalogue_digest": cat, "capability_matrix_digest": cap,
            "assignments": assignments, "family_blocks": blocks["family"], "material_blocks": blocks["material"]}


# ------------------------------------------------------------- canonical hash

def canonical_bytes(p: dict) -> bytes:
    """The exact byte form hashed into policy_hash (all integers little-endian)."""
    out = bytearray(DOMAIN_POLICY)
    out += struct.pack("<H", p["policy_version"])
    out += bytes.fromhex(p["catalogue_digest"]) + bytes.fromhex(p["capability_matrix_digest"])
    out += struct.pack("<H", len(p["assignments"]))
    for m, f, v in p["assignments"]:
        assert f != MATERIAL_DEFAULT
        out += struct.pack("<HBB", m, f, v)
    out += struct.pack("<B", len(p["family_blocks"]))
    for owner, version, values in p["family_blocks"]:
        out += struct.pack("<BHI", owner, version, 4 * len(values)) + struct.pack(f"<{len(values)}i", *values)
    out += struct.pack("<H", len(p["material_blocks"]))
    for owner, version, values in p["material_blocks"]:
        out += struct.pack("<HHI", owner, version, 4 * len(values)) + struct.pack(f"<{len(values)}i", *values)
    return bytes(out)


def policy_hash(p: dict) -> str:
    return hashlib.sha256(canonical_bytes(p)).hexdigest()


# ----------------------------------------------------------- session/readback

class Session:
    """The owner-boundary transaction: validate, then commit or keep the prior session."""

    def __init__(self, build: dict):
        self.build = build
        self.applied = decode(encode(policy_for(build)), build)
        self.generation = 0

    def apply(self, words: list[int]) -> dict:
        try:
            applied = decode(words, self.build)
        except Refusal as refusal:
            return {"accepted": False, "refusal": refusal.as_dict(), "readback": self.readback()}
        self.applied, self.generation = applied, self.generation + 1
        return {"accepted": True, "refusal": None, "readback": self.readback()}

    def readback(self) -> dict:
        p = self.applied
        liquids = self.build["matrix"]["liquids"]
        return {"version": p["policy_version"], "wire_version": ENVELOPE_VERSION, "policy_hash": policy_hash(p),
                "catalogue_digest": p["catalogue_digest"], "capability_matrix_digest": p["capability_matrix_digest"],
                "session_generation": self.generation,
                "assignments": [{"material": m, "name": liquids[m]["name"], "applied_family": FAMILY_NAMES[f],
                                 "applied_variant": VARIANT_NAMES[v]} for m, f, v in p["assignments"]],
                "family_blocks": [{"family": FAMILY_NAMES[o], "block_version": ver, "values": list(vals)}
                                  for o, ver, vals in p["family_blocks"]],
                "material_blocks": [{"material": o, "block_version": ver, "values": list(vals)}
                                    for o, ver, vals in p["material_blocks"]],
                "envelope": encode(p)}


# ----------------------------------------------------------------- vectors

def _with(assignments, material, family, variant=0):
    return [(m, family, variant) if m == material else (m, f, v) for m, f, v in assignments]


def build_vectors(matrix_bytes: bytes, catalogue: str) -> dict:
    # Vector builds use fixed synthetic catalogue digests so the vectors stay
    # stable; the real matrix supplies statuses and the capability digest.
    vec_cat = hashlib.sha256(b"lcb policy vector catalogue").hexdigest()
    other_cat = hashlib.sha256(b"lcb policy vector catalogue (changed)").hexdigest()
    defaults_only = current_default_cells(matrix_bytes)
    today = make_build(matrix_bytes, vec_cat, available=(1, 2), qualified=defaults_only)
    hypo = make_build(matrix_bytes, vec_cat, available=(1, 2, 3, 4))
    fallback = make_build(matrix_bytes, vec_cat, available=(1, 2), native=False, qualified=defaults_only)
    builds = {"today": today, "all_families_hypothetical": hypo, "gdscript_fallback": fallback}
    base = default_assignments(hypo)
    water_in = _with(base, 3, 4)
    damping = [(4, 1, [62259, 512])]
    words = {
        "default": encode(policy_for(hypo)),
        "default_by_material_default_code": encode(policy_for(hypo, [(m, 0, 0) for m, _, _ in base])),
        "default_water_code_zero": encode(policy_for(hypo, _with(base, 3, 0))),
        "changed_catalogue_digest": encode(policy_for(hypo, catalogue_digest=other_cat)),
        "changed_capability_digest": encode(policy_for(hypo, capability_matrix_digest=other_cat)),
        "water_inertial": encode(policy_for(hypo, water_in, damping)),
        "water_inertial_changed_family_parameter": encode(policy_for(hypo, water_in, [(4, 1, [62260, 512])])),
        "water_cellular_yield_flow_500": encode(policy_for(hypo, _with(base, 3, 2), (), [(3, 1, [500])])),
        "water_cellular_yield_flow_600": encode(policy_for(hypo, _with(base, 3, 2), (), [(3, 1, [600])])),
        "water_cellular_yield_no_block": encode(policy_for(hypo, _with(base, 3, 2))),
        "water_pressure_cached_dormant": encode(policy_for(hypo, _with(base, 3, 3, 2))),
        "brine_inertial": encode(policy_for(hypo, _with(base, 24, 4), damping)),
    }
    d = words["default"]
    malformed = {
        "empty": [],
        "truncated_header": d[:HEADER_WORDS],
        "bad_magic": [0] + d[1:],
        "unknown_envelope_version": d[:1] + [2] + d[2:],
        "unknown_policy_version": d[:2] + [2] + d[3:],
        "trailing_word": d + [0],
        "assignment_count_short": d[:HEADER_WORDS] + [len(base) - 1] + d[HEADER_WORDS + 1:],
        "assignment_count_negative": d[:HEADER_WORDS] + [-1] + d[HEADER_WORDS + 1:],
        "assignment_count_above_catalogue": d[:HEADER_WORDS] + [len(base) + 1] + d[HEADER_WORDS + 1:],
        "word_above_int32": d[:-1] + [INT32_MAX + 1],
        "block_length_past_end": encode(policy_for(hypo, water_in, damping))[:-1],
        "block_length_over_limit": encode(policy_for(hypo, water_in, [(4, 1, [0] * (MAX_BLOCK_WORDS + 1))])),
        "block_length_mismatch_schema": encode(policy_for(hypo, water_in, [(4, 1, [62259])])),
        "unknown_block_version": encode(policy_for(hypo, water_in, [(4, 2, [62259, 512])])),
        "missing_mandatory_block": encode(policy_for(hypo, water_in)),
        "extra_family_block": encode(policy_for(hypo, base, damping)),
        "material_block_wrong_family": encode(policy_for(hypo, base, (), [(3, 1, [500])])),
        "field_out_of_range": encode(policy_for(hypo, water_in, [(4, 1, [65537, 512])])),
        "duplicate_family_block": encode(policy_for(hypo, water_in, damping * 2)),
        "unsorted_assignments": encode(policy_for(hypo, [base[1], base[0]] + base[2:])),
        "duplicate_assignment": encode(policy_for(hypo, [base[0]] + base[:-1])),
        "missing_liquid": encode(policy_for(hypo, base[:-1])),
        "non_liquid_assignment": encode(policy_for(hypo, sorted(base[:-1] + [(2, 2, 0)]))),
        "reserved_material": encode(policy_for(hypo, sorted(base[:-1] + [(10, 2, 0)]))),
        "material_outside_catalogue": encode(policy_for(hypo, base[:-1] + [(132, 2, 0)])),
        "unknown_family_code": encode(policy_for(hypo, _with(base, 3, 5))),
        "unknown_variant_code": encode(policy_for(hypo, _with(base, 3, 1, 3))),
        "default_code_with_variant": encode(policy_for(hypo, _with(base, 3, 0, 1))),
        "variant_unsupported": encode(policy_for(hypo, _with(base, 3, 1, 1))),
        "combination_rejected": encode(policy_for(hypo, _with(base, 8, 3))),
        "not_selectable_alternate": encode(policy_for(hypo, _with(base, 32, 4), damping)),
    }
    cases = []

    def case(name, build_name, w, note=""):
        b = builds[build_name]
        entry = {"name": name, "build": build_name, "words": w, "note": note}
        try:
            p = decode(w, b)
        except Refusal as refusal:
            entry["outcome"] = {"accepted": False, **refusal.as_dict()}
        else:
            entry["outcome"] = {"accepted": True, "policy_hash": policy_hash(p),
                                "canonical_bytes_hex": canonical_bytes(p).hex(),
                                "normalized_envelope": encode(p)}
        cases.append(entry)

    for name, w in words.items():
        case(name, "all_families_hypothetical", w)
    case("water_inertial_today", "today", words["water_inertial"], "W-IN is not compiled today")
    case("water_cellular_yield_today", "today", words["water_cellular_yield_no_block"],
         "cellular_yield_v1 is compiled for ten liquids but not qualified for Water today")
    case("water_inertial_fallback", "gdscript_fallback", words["water_inertial"], "no native handshake")
    case("default_fallback", "gdscript_fallback", words["default"], "defaults remain constructible")
    for name, w in malformed.items():
        case(name, "all_families_hypothetical", w)

    session = Session(hypo)
    transcript = [{"step": "construct default", "readback_hash": session.readback()["policy_hash"],
                   "generation": session.generation}]
    for label, w in (("apply water_inertial", words["water_inertial"]),
                     ("apply changed_catalogue_digest", words["changed_catalogue_digest"]),
                     ("apply changed_capability_digest", words["changed_capability_digest"]),
                     ("apply block_length_past_end", malformed["block_length_past_end"]),
                     ("apply water_cellular_yield_flow_500", words["water_cellular_yield_flow_500"])):
        result = session.apply(w)
        transcript.append({"step": label, "accepted": result["accepted"], "refusal": result["refusal"],
                           "readback_hash": result["readback"]["policy_hash"], "generation": session.generation})
    return {
        "schema": "lcb-liquid-policy-wire-vectors-v1",
        "status": "Registered Gate C contract vectors from tools/lcb/policy_contract.py. "
                  "The historical today/hypothetical/fallback profiles retain their registered outcomes; "
                  "source-qualified running-build candidates are additionally checked by native tests.",
        "constants": {"magic": MAGIC, "envelope_version": ENVELOPE_VERSION, "policy_version": POLICY_VERSION,
                      "header_words": HEADER_WORDS, "max_block_words": MAX_BLOCK_WORDS,
                      "family_codes": FAMILIES, "variant_codes": VARIANTS, "material_default_request_code": 0,
                      "illustrative_block_schemas": {f"{k[0]}:{k[1]}:v{k[2]}": {
                          "fields": [list(f) for f in v["fields"]], "mandatory": v["mandatory"],
                          "requires_family": v.get("requires_family")} for k, v in BLOCK_SCHEMAS.items()}},
        "current_build_identity": {
            "catalogue_digest": catalogue,
            "catalogue_sources": list(CATALOGUE_SOURCES),
            "capability_matrix_digest": capability_matrix_digest(matrix_bytes),
            "capability_matrix_source": "docs/reference/liquid-solver-capability-matrix.json"},
        "vector_builds": {k: {"catalogue_digest": b["catalogue_digest"],
                              "capability_matrix_digest": b["capability_matrix_digest"],
                              "available_families": [FAMILY_NAMES[f] for f in b["available"]],
                              "qualified_cells": "all_selectable" if b["qualified"] is None else
                              [[m, FAMILY_NAMES[f]] for m, f in sorted(b["qualified"])],
                              "native": b["native"]} for k, b in builds.items()},
        "cases": cases,
        "session_transcript": transcript,
    }


def render(data: dict) -> str:
    text = json.dumps(data, indent=1)
    # Keep integer word lists on one line so the vectors stay reviewable.
    return re.sub(r"\[\n\s*(-?\d+(?:,\n\s*-?\d+)*)\n\s*\]",
                  lambda m: "[" + ", ".join(re.split(r",\n\s*", m.group(1))) + "]", text) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = render(build_vectors(MATRIX.read_bytes(), catalogue_digest()))
    if args.check:
        if not VECTORS.exists() or VECTORS.read_text(encoding="utf-8") != text:
            print(f"stale: {VECTORS.relative_to(ROOT)}; run python tools/lcb/policy_contract.py", file=sys.stderr)
            return 1
        print("policy wire vectors match the oracle")
        return 0
    VECTORS.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {VECTORS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
