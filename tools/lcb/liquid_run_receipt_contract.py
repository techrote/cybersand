"""Independent full-byte oracle for native LCB run and construction receipts.

Only struct/hashlib and explicit fixture inputs construct expected bytes. The
four physical hashes are measured native facts, not independent physics proof.
No C++ parsing, native invocation or native receipt decoding supplies encoding
expectations. --native-dir compares independently constructed complete bytes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "docs/reference/liquid-run-receipt-vectors.json"
NATIVE = ROOT / "native/tests/liquid_run_receipt_vectors.inc"
CASES = ("controlled_native_scope", "exploratory", "caller_claims", "selected_region",
         "pressure_state_extension", "normalized_bound", "refused_attempt")
LIQUIDS = ((3, 1), (8, 2), (12, 2), (16, 2), (20, 2), (21, 2), (24, 2),
           (30, 2), (32, 2), (33, 2), (36, 2))
SETUP = {"kind": 1, "definition_schema": 1, "definition_digest": None, "seed": 7,
         "domain": [0, 0, 8, 8], "coverage": 1, "gaps": 63}
# Measured fixture facts from the combined-source native capture below.
# Parent captures remain historical and are never reattested as this source.
PHYSICAL_FACTS = {'captured_date': '2026-10-25',
 'platform': 'Windows x86_64',
 'compiler': 'LLVM-MinGW 20260826 UCRT, clang++23.1.0 -O1 C++20',
 'reserve_bytes': 1048576,
 'commit_bytes': 4096,
 'binary_sha256': 'ddc8ba937535b3071b124d78b167c8ac413cc3bde4acf27b21d612d98cdc64b0',
 'capture_receipt_sha256': 'a4360754d6ba76647f72efc1fc0e54e7f570cdadb122e190d95a7911c26e0a94',
 'source_base': 'dfa6d742bbeef75a9a8d927467f5b6c5d5aba1bb',
 'native_input_manifest_sha256': '76b842845d99f30b2513083a1415048d303af8aa59f02acaf22cc13a9275b8e1',
 'qualification': 'Four measured fixture physical hashes only; no receipt decoding or native bytes '
                  'supply Python encoding expectations. Historical parent facts retained '
                  'separately. Not published-runtime or independent physics proof.',
 'hash_version': 2,
 'hashes': {'empty': 5616549901072788646,
            'selected': 3978184822077514841,
            'pressure': 1353700890374999180,
            'normalized': 8248698509232541560}}

DEFAULT_CONFIG = {
    "water_semantics": [1, 8, 12, 0], "interaction": [1, 8, 9, 30],
    "geometry": [128, 32, 64, 2], "sleep_after_quiet_ticks": 3,
    "ambient_temperature": 200, "backend": 1, "workers": 1,
    "capacities": [64, 8, 4096, 4096, 4096, 1024],
    "maximum_explosion_radius": 64, "settled_discovery": [False, 4096, 0, False, 0],
    "diagnostics": [False, False, -1], "adhesion": True,
    "transport": {"version": 1, "configured": False, "materials": 81,
                  "horizontal": 2, "cadence": 1, "pair": [0, 0, 64, 8, 0, 1]},
}


def p(fmt, *values):
    return struct.pack("<" + fmt, *values)


def sha(value):
    return hashlib.sha256(value).digest()


def text(value):
    encoded = value.encode("ascii")
    if len(encoded) > 4096:
        raise ValueError("text capacity")
    return p("I", len(encoded)) + encoded


def words(values):
    if len(values) > 4096:
        raise ValueError("policy capacity")
    return p("I", len(values)) + b"".join(p("i", item) for item in values)


def current_identities():
    # Hash the documented source identities as raw LF-normalized bytes; no C++
    # encoding/defaults are parsed or imported into this independent codec.
    catalogue = hashlib.sha256(b"lcb-material-catalogue-v1\0")
    source_hashes = {}
    for relative in ("native/include/cybersand/material.hpp", "native/include/cybersand/interaction_rules.hpp"):
        data = (ROOT / relative).read_bytes().replace(b"\r\n", b"\n")
        source_hashes[relative] = hashlib.sha256(data).hexdigest()
        catalogue.update(p("I", len(relative)) + relative.encode("ascii") + p("I", len(data)) + data)
    matrix = (ROOT / "docs/reference/liquid-solver-capability-matrix.json").read_bytes().replace(b"\r\n", b"\n")
    return {"catalogue_digest": catalogue.hexdigest(),
            "capability_matrix_digest": hashlib.sha256(b"lcb-capability-matrix-v1\0" + matrix).hexdigest(),
            "catalogue_source_sha256": source_hashes, "matrix_file_sha256": hashlib.sha256(matrix).hexdigest()}


def assignments(pressure=False):
    return [(material, 3 if pressure and material == 3 else family, 0) for material, family in LIQUIDS]


def policy_hash(identity, pressure=False):
    result = b"lcb-liquid-policy\0" + p("H", 1)
    result += bytes.fromhex(identity["catalogue_digest"]) + bytes.fromhex(identity["capability_matrix_digest"])
    applied = assignments(pressure)
    result += p("H", len(applied)) + b"".join(p("HBB", *item) for item in applied)
    return sha(result + p("BH", 0, 0))


def policy_request(identity, pressure=False):
    result = [0x4C435057, 1, 1]
    for name in ("catalogue_digest", "capability_matrix_digest"):
        for value in struct.unpack(">8I", bytes.fromhex(identity[name])):
            result.append(value if value < 2**31 else value - 2**32)
    result.append(len(LIQUIDS))
    for item in assignments(pressure):
        result.extend(item)
    return result + [0, 0]


def descriptor(value=SETUP):
    kind, schema, definition = value["kind"], value["definition_schema"], value["definition_digest"]
    x, y, width, height = value["domain"]
    coverage, gaps = value["coverage"], value["gaps"]
    if kind not in (1, 2) or schema != (2 if kind == 2 else 1):
        raise ValueError("setup kind/schema")
    if not 1 <= width <= 1024 or not 1 <= height <= 1024 or x + width - 1 >= 2**63 or y + height - 1 >= 2**63:
        raise ValueError("setup domain")
    if coverage not in (1, 2) or (coverage == 2 and definition is None) or gaps & ~63:
        raise ValueError("setup coverage")
    if coverage == 1 and gaps & 31 != 31:
        raise ValueError("payload cannot cover non-cell setup")
    if (kind == 2 or coverage == 2) and not gaps & 32:
        raise ValueError("registered collection remains unverified")
    return p("BHB", kind, schema, definition is not None) + (bytes.fromhex(definition) if definition else b"") + \
        p("QqqIIBI", value["seed"], x, y, width, height, coverage, gaps)


def payload_bytes(cells):
    return text("cybersand-lcb-final-cell-payload-v1") + p("HBhqqIIQ", 1, 8, 200, 0, 0, 8, 8, len(cells)) + \
        b"".join(p("qqBHBh", *cell) for cell in cells)


def setup_hash(payload, setup=SETUP):
    return sha(text("cybersand-prepared-setup-v1") + p("H", 1) + descriptor(setup) + payload)


def normalization_values():
    before_cells = [(1, 1, 3, 127, 0, 200), (2, 1, 3, 128, 0, 200)]
    after_cells = [(2, 1, 3, 255, 0, 200)]
    before, after = sha(payload_bytes(before_cells)), sha(payload_bytes(after_cells))
    setup_before, setup_after = setup_hash(before), setup_hash(after)
    totals = [1, 1, 0, 127, 127, 0, 255, 255]
    receipt = text("cybersand-water-normalization-receipt-v1") + p("H", 1) + text("water-normalize-v1")
    receipt += p("HBQQ", 1, 8, 7, 7) + setup_before + setup_after + before + after + p("QQQQQqQQ", *totals)
    return {"before_cells": before_cells, "after_cells": after_cells, "before": before, "after": after,
            "setup_before": setup_before, "setup_after": setup_after, "totals": totals, "hash": sha(receipt),
            "canonical": receipt}


def transport_hash():
    value = DEFAULT_CONFIG["transport"]
    result = text("cybersand-transport-receipt-v1") + p("HB", value["version"], value["configured"])
    result += bytes([value["horizontal"]]) * value["materials"] + bytes([value["cadence"]]) * value["materials"]
    return sha(result + bytes(value["pair"]) * value["materials"]**2)


def quantity_facts(normalized=False):
    result = p("HBQQQ", 1, 8, 255 if normalized else 0, 255 if normalized else 0, 0)
    result += p("H", 6)
    result += p("QQ", 127, 127) if normalized else p("QQ", 0, 0)
    result += p("QQ", 0, 0) * 5
    result += p("H", 56) + p("QQQ", 0, 0, 0) * 56
    result += p("H", 19) + p("QQ", 0, 0) * 19
    result += p("H", 256)
    counts = [int(normalized and material == 3) for material in range(256)]
    result += b"".join(p("Q", count) for count in counts) * 2
    result += p("B", normalized)
    if normalized:
        n = normalization_values()
        result += p("BQQQQ", 8, 255, 127, 127, 255)
        result += n["setup_before"] + n["setup_after"] + n["before"] + n["after"] + p("B", 1) + n["hash"]
    return result


def native(case, identity):
    selected = case == "selected_region"
    normalized = case == "normalized_bound"
    pressure = case == "pressure_state_extension"
    config = DEFAULT_CONFIG
    result = p("B", 1) + policy_hash(identity, pressure)
    result += bytes.fromhex(identity["catalogue_digest"]) + bytes.fromhex(identity["capability_matrix_digest"])
    result += words(policy_request(identity, pressure)) + p("BBBB", *config["water_semantics"]) + transport_hash()
    result += p("IBBI", *config["interaction"])
    result += p("iiiiIhBI", *config["geometry"], config["sleep_after_quiet_ticks"], config["ambient_temperature"],
                config["backend"], config["workers"])
    result += p("QQQQQQ", *config["capacities"])
    result += p("iBQQBQBBhB", config["maximum_explosion_radius"], *config["settled_discovery"],
                *config["diagnostics"], config["adhesion"])
    result += p("B", 2 if selected else 1)
    if selected:
        result += p("qqqqqqqq", 0, 0, 8, 8, 0, 0, 0, 0)
    result += p("B", 2 if selected else 1)  # native selected core range
    if selected:
        result += p("qqqq", 0, 0, 0, 0)
    result += p("B", 1)  # no applied range latched before first tick
    measured = PHYSICAL_FACTS["hashes"]["pressure" if pressure else "selected" if selected else
                                         "normalized" if normalized else "empty"]
    result += p("QQBIQB", 0, 0, 1, PHYSICAL_FACTS["hash_version"], measured, pressure)
    if pressure:
        result += p("BHHB", 3, 1, 0, 0)
    result += p("B", pressure)
    if pressure:
        result += p("HBi", 1, 1, 32)
    return result + quantity_facts(normalized)


def normalization_binding():
    n = normalization_values()
    return p("H", 1) + text("water-normalize-v1") + p("H", 1) + n["hash"] + n["before"] + n["after"] + \
        n["setup_before"] + n["setup_after"] + p("QQB", 7, 7, 8) + p("QQQQQqQQ", *n["totals"])


def claims(case):
    if case != "caller_claims":
        return p("BB", 0, 0)
    return p("BB", 1, 1) + text("1" * 40) + p("B", 1) + text("2" * 40) + p("B", 0) + \
        p("BB", 1, 1) + bytes([0x33]) * 32 + p("BB", 2, 1) + text("4.7.stable.official.5b4e0cb0f")


def canonical(case, identity):
    if case == "refused_attempt":
        request = policy_request(identity)
        request[21] = 4
        request[22] = 1
        request_hash = sha(text("cybersand-construction-request-v1") + p("HB", 1, 1) + words(request))
        payload = sha(payload_bytes([]))
        return text("cybersand-construction-attempt-v1") + p("HQBB", 1, 5, 1, 1) + request_hash + words(request) + \
            p("BBBH", 1, 7, 1, 3) + text("cached for inertial_cellular_v1") + text("") + \
            native(case, identity) + descriptor() + payload + setup_hash(payload)
    normalized = case == "normalized_bound"
    payload = sha(payload_bytes(normalization_values()["after_cells"] if normalized else []))
    result = text("cybersand-run-receipt-v1") + p("HBBIQQ", 1, 2 if case == "exploratory" else 1, 1, 15, 1, 0)
    result += words(policy_request(identity, case == "pressure_state_extension")) + native(case, identity)
    result += descriptor() + payload + setup_hash(payload) + p("B", normalized)
    if normalized:
        result += normalization_binding()
    return result + p("BBBII", 1, case == "selected_region", 0, 60, 1) + claims(case)


def render(identity):
    vectors = []
    native_text = "// Generated by tools/lcb/liquid_run_receipt_contract.py; do not edit.\n"
    native_text += "// Complete independent bytes/inputs: docs/reference/liquid-run-receipt-vectors.json\n"
    for name in CASES:
        value = canonical(name, identity)
        digest = hashlib.sha256(value).hexdigest()
        vectors.append({"name": name, "byte_length": len(value), "sha256": digest, "canonical_hex": value.hex()})
        native_text += "{" + json.dumps(name) + ", " + json.dumps(digest) + "},\n"
    document = {"schema": 1, "status": "Native value receipts; host setup/execution and source/runtime provenance remain unverified",
                "oracle": "Independent Python struct/hashlib expected bytes; native tests compare frozen SHA256 identities",
                "current_identity_facts": identity, "measured_physical_facts": PHYSICAL_FACTS,
                "fixture_inputs": {"liquids": LIQUIDS, "setup": SETUP, "config": DEFAULT_CONFIG,
                                   "normalization_before_cells": normalization_values()["before_cells"],
                                   "normalization_after_cells": normalization_values()["after_cells"],
                                   "normalization_totals": normalization_values()["totals"],
                                   "selected_region": [0, 0, 8, 8], "selected_cores": [0, 0, 0, 0],
                                   "applied_cores_at_tick0": None, "run_generation": 1,
                                   "attempt_generation": 5, "pressure_parameters": [1, True, 32],
                                   "source_claim": ["1" * 40, "2" * 40, None],
                                   "runtime_claim": ["33" * 32, 2, 1, "4.7.stable.official.5b4e0cb0f"],
                                   "execution": [1, False, False, 60, 1], "quantity_shape": [1, 6, 56, 19, 256]},
                "vectors": vectors}
    return json.dumps(document, indent=1) + "\n", native_text


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--native-dir", type=Path, help="compare seven independently encoded complete native fixture files")
    args = parser.parse_args()
    identity = current_identities()
    if args.native_dir:
        actual_names = {path.stem for path in args.native_dir.glob("*.bin")}
        if actual_names != set(CASES):
            print("native receipt fixture inventory mismatch", file=sys.stderr)
            return 1
        for name in CASES:
            expected = canonical(name, identity)
            actual = (args.native_dir / (name + ".bin")).read_bytes()
            if expected != actual:
                first = next((i for i, (left, right) in enumerate(zip(expected, actual)) if left != right),
                             min(len(expected), len(actual)))
                print(f"{name}: complete bytes differ at {first}; expected {len(expected)}, actual {len(actual)}", file=sys.stderr)
                return 1
    for path, value in zip((VECTORS, NATIVE), render(identity)):
        if args.write:
            path.write_text(value, encoding="utf-8", newline="\n")
        elif not path.exists() or path.read_text(encoding="utf-8") != value:
            print(f"stale receipt artifact: {path.relative_to(ROOT)}", file=sys.stderr)
            return 1
    print(f"liquid run receipts: {len(CASES)} independent complete vectors {'written' if args.write else 'match'}" +
          ("; native bytes match" if args.native_dir else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
