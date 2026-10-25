"""Regressions for the standalone Gate C liquid-policy wire/hash contract oracle.

These preserve the registered oracle profiles; running native qualification is
checked separately and does not reinterpret the historical today profile.
"""
from __future__ import annotations

import hashlib
import itertools
import json
import struct
import unittest

import policy_contract as pc

MATRIX_BYTES = pc.MATRIX.read_bytes()
VEC_CAT = hashlib.sha256(b"lcb policy vector catalogue").hexdigest()


def hypo():
    return pc.make_build(MATRIX_BYTES, VEC_CAT, available=(1, 2, 3, 4))


class VectorFile(unittest.TestCase):
    def test_vectors_match_oracle(self):
        expected = pc.render(pc.build_vectors(MATRIX_BYTES, pc.catalogue_digest()))
        self.assertEqual(pc.VECTORS.read_text(encoding="utf-8"), expected,
                         "run python tools/lcb/policy_contract.py")

    def test_every_oracle_refusal_code_is_exercised(self):
        data = json.loads(pc.VECTORS.read_text(encoding="utf-8"))
        seen = {c["outcome"]["code"] for c in data["cases"] if not c["outcome"]["accepted"]}
        self.assertEqual(seen, set(pc.REFUSAL_CODES) - set(pc.NATIVE_ONLY_CODES))


class CanonicalBytes(unittest.TestCase):
    def test_default_layout_assembled_independently(self):
        b = hypo()
        p = pc.decode(pc.encode(pc.policy_for(b)), b)
        liquids = sorted(b["matrix"]["liquids"].items())
        expected = b"lcb-liquid-policy\x00" + (1).to_bytes(2, "little")
        expected += bytes.fromhex(b["catalogue_digest"]) + bytes.fromhex(b["capability_matrix_digest"])
        expected += len(liquids).to_bytes(2, "little")
        for m, row in liquids:
            expected += m.to_bytes(2, "little") + bytes([row["default"], 0])
        expected += b"\x00" + b"\x00\x00"  # family block count u8, material block count u16
        self.assertEqual(pc.canonical_bytes(p), expected)
        self.assertEqual(len(expected), 18 + 2 + 64 + 2 + 4 * 11 + 1 + 2)

    def test_block_lengths_are_bytes_and_values_signed_le(self):
        b = hypo()
        p = pc.decode(pc.encode(pc.policy_for(b, [(m, 4 if m == 3 else f, v) for m, f, v in
                                                  pc.default_assignments(b)], [(4, 1, [62259, 512])])), b)
        tail = pc.canonical_bytes(p)[-(1 + 1 + 2 + 4 + 8 + 2):]
        self.assertEqual(tail, bytes([1, 4]) + struct.pack("<HI", 1, 8) + struct.pack("<ii", 62259, 512)
                         + b"\x00\x00")

    def test_digest_words_are_big_endian_twos_complement(self):
        for digest in ("ff" * 32, "80000000" + "00" * 28, hashlib.sha256(b"x").hexdigest()):
            words = pc.digest_to_words(digest)
            self.assertTrue(all(pc.INT32_MIN <= w <= pc.INT32_MAX for w in words))
            self.assertEqual(pc.words_to_digest(words), digest)
        self.assertEqual(pc.digest_to_words("80000001" + "00" * 28)[0], -(1 << 31) + 1)


class Identity(unittest.TestCase):
    def test_round_trip_and_readback(self):
        data = json.loads(pc.VECTORS.read_text(encoding="utf-8"))
        builds = {"today": pc.make_build(MATRIX_BYTES, VEC_CAT, (1, 2)), "all_families_hypothetical": hypo(),
                  "gdscript_fallback": pc.make_build(MATRIX_BYTES, VEC_CAT, (1, 2), native=False)}
        for c in data["cases"]:
            if not c["outcome"]["accepted"]:
                continue
            b = builds[c["build"]]
            p = pc.decode(c["words"], b)
            again = pc.decode(pc.encode(p), b)
            self.assertEqual(again, p, c["name"])
            self.assertEqual(pc.encode(again), c["outcome"]["normalized_envelope"], c["name"])
            session = pc.Session(b)
            self.assertTrue(session.apply(c["words"])["accepted"])
            self.assertEqual(session.readback()["envelope"], c["outcome"]["normalized_envelope"])
            self.assertEqual(session.readback()["policy_hash"], c["outcome"]["policy_hash"])
            self.assertNotIn(0, [a[1] for a in again["assignments"]], "code 0 must never be applied")

    def test_equivalent_and_changed_policies(self):
        data = json.loads(pc.VECTORS.read_text(encoding="utf-8"))
        h = {c["name"]: c["outcome"].get("policy_hash") for c in data["cases"]}
        self.assertEqual(h["default"], h["default_by_material_default_code"])
        self.assertEqual(h["default"], h["default_water_code_zero"])
        distinct = ["default", "water_inertial", "water_inertial_changed_family_parameter",
                    "water_cellular_yield_flow_500", "water_cellular_yield_flow_600",
                    "water_cellular_yield_no_block", "water_pressure_cached_dormant", "brine_inertial"]
        self.assertEqual(len({h[n] for n in distinct}), len(distinct))

    def test_changed_digest_changes_hash_and_is_refused(self):
        b = hypo()
        p = pc.decode(pc.encode(pc.policy_for(b)), b)
        for field in ("catalogue_digest", "capability_matrix_digest"):
            q = dict(p, **{field: hashlib.sha256(field.encode()).hexdigest()})
            self.assertNotEqual(pc.policy_hash(q), pc.policy_hash(p))
            with self.assertRaises(pc.Refusal) as caught:
                pc.decode(pc.encode(q), b)
            self.assertEqual(caught.exception.code, "stale_capability_matrix")
            self.assertIn(field, caught.exception.detail)

    def test_capability_digest_binds_reviewed_classifications(self):
        base = pc.capability_matrix_digest(MATRIX_BYTES)
        data = json.loads(MATRIX_BYTES)
        cell = data["liquid_rows"][0]["families"]["inertial_cellular_v1"]
        for mutate in (lambda d: d["liquid_rows"][0].__setitem__("kernel_specialization", "changed"),
                       lambda d: d["liquid_rows"][0]["families"]["inertial_cellular_v1"].__setitem__("status",
                                                                                                    "rejected"),
                       lambda d: d["sources"].__setitem__("native/include/cybersand/material.hpp", "0" * 64)):
            changed = json.loads(MATRIX_BYTES)
            mutate(changed)
            self.assertNotEqual(pc.capability_matrix_digest(json.dumps(changed, indent=1).encode()), base)
        self.assertEqual(cell["status"], "proposed_experimental")

    def test_crlf_checkout_has_same_identity(self):
        self.assertEqual(pc.capability_matrix_digest(MATRIX_BYTES.replace(b"\n", b"\r\n")),
                         pc.capability_matrix_digest(MATRIX_BYTES))


class Refusals(unittest.TestCase):
    def test_refusal_never_replaces_prior_session(self):
        data = json.loads(pc.VECTORS.read_text(encoding="utf-8"))
        b = hypo()
        session = pc.Session(b)
        applied = session.apply(next(c["words"] for c in data["cases"] if c["name"] == "water_inertial"))
        self.assertTrue(applied["accepted"])
        before = session.readback()
        for c in data["cases"]:
            if c["build"] == "all_families_hypothetical" and not c["outcome"]["accepted"]:
                result = session.apply(c["words"])
                self.assertFalse(result["accepted"], c["name"])
                self.assertEqual(result["refusal"]["code"], c["outcome"]["code"], c["name"])
                self.assertEqual(session.readback(), before, c["name"])

    def test_transcript_keeps_prior_hash(self):
        data = json.loads(pc.VECTORS.read_text(encoding="utf-8"))
        t = data["session_transcript"]
        self.assertEqual([s["generation"] for s in t], [0, 1, 1, 1, 1, 2])
        self.assertEqual(t[1]["readback_hash"], t[2]["readback_hash"])
        self.assertEqual(t[1]["readback_hash"], t[4]["readback_hash"])

    def test_single_material_sweep_follows_matrix(self):
        b = hypo()
        liquids = b["matrix"]["liquids"]
        for m, f, v in itertools.product(sorted(liquids), pc.FAMILY_NAMES, pc.VARIANT_NAMES):
            assignments = [(x, f if x == m else row["default"], v if x == m else 0)
                           for x, row in sorted(liquids.items())]
            blocks = [(4, 1, [0, 256])] if f == 4 else []
            cell = liquids[m]["cells"][f]
            ok = cell["status"] in ("current_default", "proposed_experimental") and v in cell["variants"]
            try:
                pc.decode(pc.encode(pc.policy_for(b, assignments, blocks)), b)
                accepted = True
            except pc.Refusal:
                accepted = False
            self.assertEqual(accepted, ok, (m, f, v))

    def test_today_build_refuses_every_uncompiled_family(self):
        b = pc.make_build(MATRIX_BYTES, VEC_CAT, (1, 2))
        for f in (3, 4):
            assignments = [(m, f if m == 3 else d, 0) for m, d, _ in pc.default_assignments(b)]
            with self.assertRaises(pc.Refusal) as caught:
                pc.decode(pc.encode(pc.policy_for(b, assignments, [(4, 1, [0, 256])] if f == 4 else [])), b)
            self.assertEqual(caught.exception.code, "family_unavailable")

    def test_compiled_family_is_qualified_per_material_cell(self):
        # Historical today profile retains default-only per-cell qualification,
        # independently of new candidate cells in the running native build.
        b = pc.make_build(MATRIX_BYTES, VEC_CAT, (1, 2), qualified=pc.current_default_cells(MATRIX_BYTES))
        self.assertEqual(pc.policy_hash(pc.decode(pc.encode(pc.policy_for(b)), b)),
                         pc.policy_hash(pc.decode(pc.encode(pc.policy_for(hypo())), hypo())))
        assignments = [(m, 2 if m == 3 else d, 0) for m, d, _ in pc.default_assignments(b)]
        with self.assertRaises(pc.Refusal) as caught:
            pc.decode(pc.encode(pc.policy_for(b, assignments)), b)
        self.assertEqual((caught.exception.code, caught.exception.material), ("family_unavailable", 3))
        unqualified = pc.make_build(MATRIX_BYTES, VEC_CAT, (1, 2))
        self.assertEqual(pc.decode(pc.encode(pc.policy_for(unqualified, assignments)), unqualified)["assignments"],
                         assignments)


if __name__ == "__main__":
    unittest.main()
