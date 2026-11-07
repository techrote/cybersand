#!/usr/bin/env python3
"""Real native G6KC1 restore-coordinate admission tests with valid SHA-256.

The source record is published by the existing native transaction fixture.
Each coordinate is changed in that record (not just in the API argument) and
rehash-validated before the native executable is invoked in a fresh process.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import struct
import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: gen006_chunk_signed_extent_qa.py NATIVE_EXECUTABLE "
            "PUBLISHED_G6KC1 OUT_DIR 1|4"
        )
    executable = Path(sys.argv[1]).resolve()
    source = Path(sys.argv[2])
    output = Path(sys.argv[3])
    workers = int(sys.argv[4])
    if workers not in (1, 4):
        raise ValueError("expected workers 1 or 4")
    record = source.read_bytes()
    if len(record) < 96 or record[:4] != b"G6KC" or record[4:8] != b"\\x01\\x00\\x00\\x00":
        raise ValueError("not a G6KC1 static chunk record")
    if hashlib.sha256(record[:-32]).digest() != record[-32:]:
        raise ValueError("untrusted source record hash")
    output.mkdir(parents=True, exist_ok=True)

    size = 64
    minimum = -(1 << 63)
    maximum = (1 << 63) - 1
    low = minimum // size
    high = maximum // size
    # At the multiplication endpoints themselves the 2-cell rule radius is
    # beyond int64_t cell space. One chunk inward is admissible. Every record
    # has a freshly computed *valid* SHA-256 to isolate coordinate authority.
    cases = [
        ("x_negative_multiply", low - 1, -8, False),
        ("x_negative_rule_radius", low, -8, False),
        ("x_negative_edge_valid", low + 1, -8, True),
        ("x_positive_edge_valid", high - 1, -8, True),
        ("x_positive_rule_radius", high, -8, False),
        ("x_positive_multiply", high + 1, -8, False),
        ("y_negative_multiply", -16, low - 1, False),
        ("y_negative_rule_radius", -16, low, False),
        ("y_negative_edge_valid", -16, low + 1, True),
        ("y_positive_edge_valid", -16, high - 1, True),
        ("y_positive_rule_radius", -16, high, False),
        ("y_positive_multiply", -16, high + 1, False),
    ]
    for name, x, y, admissible in cases:
        candidate = bytearray(record[:-32])
        # Header: u32 magic, u32 version, i64 chunk_x, i64 chunk_y.
        struct.pack_into("<qq", candidate, 8, x, y)
        candidate.extend(hashlib.sha256(candidate).digest())
        path = output / (name + ".g6c")
        path.write_bytes(candidate)
        outcome = subprocess.run(
            [
                str(executable), "--extent", str(path.resolve()),
                str(workers), str(x), str(y), "1" if admissible else "0",
            ], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            check=False,
        )
        print(name, outcome.stdout.strip(), flush=True)
        if outcome.returncode != 0 or "GEN006_SIGNED_EXTENT_NATIVE_PASS" not in outcome.stdout:
            raise RuntimeError(
                f"{name}: native restore failed expected admissible={admissible}, "
                f"return={outcome.returncode}"
            )
    print(
        "GEN006_REHASHED_SIGNED_EXTENT_QA_PASS",
        f"workers={workers}", f"cases={len(cases)}",
        "real_native_world=1 SHA256_recomputed=1 invalid_refusals_atomic=1",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
