#!/usr/bin/env python3
"""Exercise the independent streaming ZIP auditor with real engines and adversarial bytes."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile

import inspect_windows_evaluator as auditor


def fixture(data: bytes, declared_size: int | None = None) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as archive:
        info = zipfile.ZipInfo("image.exe", (1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, data)
    raw = bytearray(output.getvalue())
    if declared_size is not None:
        central = raw.index(b"PK\x01\x02")
        struct.pack_into("<I", raw, central + 24, declared_size)
    return bytes(raw)


def run(official: Path) -> dict:
    rows = []
    expected = {
        "Godot_v4.7-stable_win64.exe": (178485256, "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"),
        "Godot_v4.7-stable_win64_console.exe": (198152, "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c"),
    }
    assert auditor.file_sha(official) == "02a5312236f4e0209c78bcb2f52135b1963e6b8888c873c9cee81459e60bcd71"
    with zipfile.ZipFile(official) as archive:
        for name, (size, digest) in expected.items():
            result = auditor.pe_amd64(archive, name)
            assert result["bytes"] == size and result["sha256"] == digest
            rows.append({"case": "official-" + name, "status": "passed", "result": result})

    base = bytearray(256)
    base[:2] = b"MZ"
    struct.pack_into("<I", base, 0x3c, 128)
    base[128:134] = b"PE\0\0\x64\x86"
    struct.pack_into("<H", base, 148, 64)
    struct.pack_into("<H", base, 152, 0x20b)
    variants = [
        ("missing-dos-magic", 0, b"XX", "Missing MZ header"),
        ("pe-outside-file", 0x3c, struct.pack("<I", 255), "Missing PE AMD64 signature"),
        ("wrong-machine", 132, b"\x4c\x01", "Missing PE AMD64 signature"),
        ("empty-optional-header", 148, struct.pack("<H", 0), "Invalid optional header bounds"),
        ("oversize-optional-header", 148, struct.pack("<H", 65535), "Invalid optional header bounds"),
        ("wrong-optional-format", 152, struct.pack("<H", 0x10b), "Expected PE32+ image"),
    ]

    def refused(name: str, raw: bytes, method: str, expected_reason: str, extra: dict | None = None) -> None:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            try:
                getattr(auditor, method)(archive, "image.exe")
            except ValueError as exc:
                assert expected_reason in str(exc), (name, str(exc))
                rows.append({"case": name, "status": "refused", "reason": str(exc),
                             "fixture_sha256": hashlib.sha256(raw).hexdigest(), **(extra or {})})
            else:
                raise AssertionError("Accepted malformed fixture: " + name)

    for name, offset, change, reason in variants:
        data = bytearray(base)
        data[offset:offset + len(change)] = change
        refused(name, fixture(data), "pe_amd64", reason)

    # Independent reviewer A's concrete counterexample: CRC covers 90 actual
    # bytes, central length claims 200, and the optional header requires 188.
    data = bytearray(90)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3c, 64)
    data[64:70] = b"PE\0\0\x64\x86"
    struct.pack_into("<H", data, 84, 100)
    struct.pack_into("<H", data, 88, 0x20b)
    raw = fixture(data, 200)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        assert archive.testzip() is None and len(archive.read("image.exe")) == 90
        assert archive.getinfo("image.exe").file_size == 200
    for method in ("member_sha", "pe_amd64"):
        refused("overreported-member-size-" + method, raw, method, "ZIP member length differs",
                {"actual_decompressed_bytes": 90, "declared_member_bytes": 200,
                 "required_optional_header_end": 188, "crc": "valid"})

    return {"schema": "objectshard-m4-independent-zip-stream-review-v1", "status": "passed",
            "audit_script_sha256": auditor.file_sha(Path(auditor.__file__)),
            "challenge_script_sha256": auditor.file_sha(Path(__file__)),
            "source_scope": "Audit-only bounded reads with actual decompressed-length validation; no product or workflow changes.",
            "case_count": len(rows), "cases": rows,
            "retained_negative": "Independent review found that the first stream draft trusted forged ZIP central length. No evaluator was inspected with that draft. Both corrected helpers refuse the concrete witness."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--official-godot-archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = run(args.official_godot_archive)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "case_count": result["case_count"],
                      "audit_script_sha256": result["audit_script_sha256"]}))
