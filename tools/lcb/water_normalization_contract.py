"""Independent water-normalize-v1 canonical-byte and exact-rational oracle.

This tool uses only Python's standard library. It does not parse or import the
native implementation. Frozen vectors retain complete inputs and canonical
bytes; native tests compare the resulting identities independently.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "docs/reference/water-normalization-vectors.json"
NATIVE = ROOT / "native/tests/water_normalization_vectors.inc"
PAYLOAD_DOMAIN = "cybersand-lcb-final-cell-payload-v1"
SETUP_DOMAIN = "cybersand-prepared-setup-v1"
RECEIPT_DOMAIN = "cybersand-water-normalization-receipt-v1"


def tagged(value: str) -> bytes:
    encoded = value.encode("ascii")
    return struct.pack("<I", len(encoded)) + encoded


def water(x: int, y: int, mass: int, coherence: int = 0, temperature: int = 200) -> list[int]:
    return [x, y, 3, mass, coherence, temperature]


def fixture(name, bits, seed, cells, ambient=200, domain=(0, 0, 1024, 1024),
            definition=b"", *, kind=1, definition_schema=1, coverage=1, gaps=63):
    return {"name": name, "mass_bits": bits, "seed": seed, "ambient_temperature": ambient,
            "domain": list(domain), "cells": cells, "definition_source_hex": definition.hex(),
            "kind": kind, "definition_schema": definition_schema, "coverage": coverage, "gaps": gaps}


CASES = [
    fixture("mass8-pair", 8, 42, [water(0, 0, 127), water(1, 0, 128)], definition=b"v\0\xff"),
    fixture("mass3-pair", 3, 7, [water(-5, 9, 3, 12, -123), water(0, -1, 4)],
            domain=(-5, -1, 6, 11)),
    fixture("positive", 8, 0, [water(0, 0, 128), water(1, 0, 254), water(2, 0, 255)]),
    fixture("negative", 8, 0, [water(0, 0, 1), water(1, 0, 127)]),
    fixture("empty", 8, 0, []),
    fixture("foreign", 8, 1234,
            [water(20, 3, 128), [0, -1, 16, 0, 10, -250], water(-2, 3, 127), water(0, 0, 255)],
            domain=(-2, -1, 23, 5), definition=b"setup\0\xff"),
    fixture("registered-unverified", 8, 99, [water(0, 0, 128)], domain=(0, 0, 8, 8),
            definition=b"micro", kind=2, definition_schema=2, coverage=2),
    fixture("extremes", 8, 2**64 - 1,
            [water(2**63 - 1, -2**63, 128), water(2**63 - 2, -2**63, 127)],
            domain=(2**63 - 2, -2**63, 2, 1)),
]


def payload_bytes(case: dict, cells: list[list[int]]) -> bytes:
    result = tagged(PAYLOAD_DOMAIN)
    result += struct.pack("<HBhqqII", 1, case["mass_bits"], case["ambient_temperature"], *case["domain"])
    result += struct.pack("<Q", len(cells))
    for cell in cells:
        result += struct.pack("<qqBHBh", *cell)
    return result


def setup_bytes(case: dict, payload_digest: bytes) -> bytes:
    definition_source = bytes.fromhex(case["definition_source_hex"])
    definition_digest = hashlib.sha256(definition_source).digest() if definition_source else None
    result = tagged(SETUP_DOMAIN)
    result += struct.pack("<HBHB", 1, case["kind"], case["definition_schema"], definition_digest is not None)
    if definition_digest is not None:
        result += definition_digest
    result += struct.pack("<QqqIIBI", case["seed"], *case["domain"], case["coverage"], case["gaps"])
    return result + payload_digest


def vector(case: dict) -> dict:
    cells = sorted(case["cells"], key=lambda item: (item[1], item[0]))
    cells = [cell for cell in cells if cell[2] != 0 or cell[5] != case["ambient_temperature"]]
    maximum = 2 ** case["mass_bits"] - 1
    after = []
    up = down = unchanged = positive = negative = before_mass = after_mass = 0
    for cell in cells:
        if cell[2] != 3:
            after.append(cell)
            continue
        mass = cell[3]
        before_mass += mass
        # Exact rational distance to 1/2 is independent of the native integer
        # multiply/compare and the C++ test's power-of-two threshold formula.
        full = Fraction(mass, maximum) >= Fraction(1, 2)
        if mass == maximum:
            unchanged += 1
        elif full:
            up += 1
            positive += maximum - mass
        else:
            down += 1
            negative += mass
        if full:
            after.append([*cell[:3], maximum, *cell[4:]])
            after_mass += maximum
        elif cell[5] != case["ambient_temperature"]:
            after.append([*cell[:2], 0, 0, 0, cell[5]])
    before_payload = payload_bytes(case, cells)
    after_payload = payload_bytes(case, after)
    payload_before_hash = hashlib.sha256(before_payload).digest()
    payload_after_hash = hashlib.sha256(after_payload).digest()
    before_setup = setup_bytes(case, payload_before_hash)
    after_setup = setup_bytes(case, payload_after_hash)
    setup_before_hash = hashlib.sha256(before_setup).digest()
    setup_after_hash = hashlib.sha256(after_setup).digest()
    net = positive - negative
    totals = [up, down, unchanged, positive, negative, net, before_mass, after_mass]
    assert before_mass + positive == after_mass + negative
    receipt = tagged(RECEIPT_DOMAIN)
    receipt += struct.pack("<H", 1) + tagged("water-normalize-v1")
    receipt += struct.pack("<HBQQ", 1, case["mass_bits"], case["seed"], case["seed"])
    receipt += setup_before_hash + setup_after_hash + payload_before_hash + payload_after_hash
    receipt += struct.pack("<QQQQQqQQ", *totals)
    hashes = [payload_before_hash.hex(), payload_after_hash.hex(), setup_before_hash.hex(),
              setup_after_hash.hex(), hashlib.sha256(receipt).hexdigest()]
    return {"input": case, "canonical_before_cells": cells, "canonical_after_cells": after,
            "totals_fields": ["cells_up", "cells_down", "cells_unchanged", "positive_delta",
                              "negative_delta", "net_delta", "water_before", "water_after"],
            "totals": totals,
            "canonical_hex": {"payload_before": before_payload.hex(), "payload_after": after_payload.hex(),
                              "setup_before": before_setup.hex(), "setup_after": after_setup.hex(),
                              "receipt": receipt.hex()},
            "hashes": dict(zip(("payload_before", "payload_after", "setup_before", "setup_after", "receipt"), hashes)),
            "native_expected": "|".join([case["name"], *hashes, ",".join(map(str, totals))])}


def render() -> tuple[str, str]:
    vectors = [vector(case) for case in CASES]
    document = {"schema": 1, "rule": "water-normalize-v1", "rule_version": 1,
                "status": "Value-contract vectors; registered definition compilation remains host-unverified",
                "coverage": "Resolved native material/state/thermal tuples in a finite domain; setup gaps stay explicit",
                "source": "tools/lcb/water_normalization_contract.py independent struct/hashlib/Fraction oracle",
                "vectors": vectors}
    native = "// Generated by tools/lcb/water_normalization_contract.py; do not edit.\n"
    native += "// Complete inputs and canonical bytes: docs/reference/water-normalization-vectors.json\n"
    for value in vectors:
        native += "{" + json.dumps(value["input"]["name"]) + ", " + json.dumps(value["native_expected"]) + "},\n"
    return json.dumps(document, indent=1) + "\n", native


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    texts = zip((VECTORS, NATIVE), render())
    stale = []
    for path, text in texts:
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                stale.append(str(path.relative_to(ROOT)))
        else:
            path.write_text(text, encoding="utf-8", newline="\n")
    if stale:
        print("stale water normalization artifacts: " + ", ".join(stale), file=sys.stderr)
        return 1
    print(f"water normalization: {len(CASES)} independent complete canonical vectors {'match' if args.check else 'written'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
