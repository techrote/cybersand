#!/usr/bin/env python3
"""Independent fail-closed readback of MAT-003PREPASS S0 evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


def checked_path(root: Path, relative: str) -> Path:
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"unsafe artifact path: {relative}")
    resolved = (root / path).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError(f"artifact escapes evidence directory: {relative}")
    return resolved


def validate_result(result: dict, registration: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(result, dict):
        return ["result is not an object"]
    if result.get("schema_version") != 1 or result.get("status") != "passed":
        errors.append("result schema/status is not a successful S0 result")
    if result.get("scope") != "synthetic-storage-only":
        errors.append("result must declare synthetic-storage-only scope")
    if result.get("world_qualification") is not False or result.get("timing_qualification") is not False:
        errors.append("S0 cannot qualify World or timings")
    if result.get("semantic_digest_algorithm") != "fnv1a64-le":
        errors.append("unexpected semantic digest algorithm")
    if result.get("natural_epoch_ticks") != 131080:
        errors.append("natural epoch primitive did not declare 131080 ticks")
    if result.get("natural_epoch16_clear_ticks") != [65536, 131071]:
        errors.append("natural epoch16 clear events differ from registration")
    if type(result.get("checks")) is not int or result["checks"] <= 0:
        errors.append("result has no positive executed check count")
    arms = result.get("arms")
    if not isinstance(arms, list):
        return errors + ["arms is not an array"]
    expected = {a["id"]: a for a in registration["arms"]}
    ids = [a.get("id") for a in arms if isinstance(a, dict)]
    if (len(ids) != len(arms) or not all(isinstance(i, str) for i in ids)
            or len(ids) != len(set(ids)) or set(ids) != set(expected)):
        return errors + ["missing, duplicate or unexpected registered arms"]
    digests: dict[int, set[str]] = {}
    records: dict[int, set[bytes]] = {}
    width_only_records: set[bytes] = set()
    for arm in arms:
        identifier = arm["id"]
        spec = expected[identifier]
        for key in ("logical_bits", "epoch_bits"):
            if type(arm.get(key)) is not int or arm[key] != spec[key]:
                errors.append(f"{identifier}: incorrect {key}")
        logical = spec["logical_bits"]
        rep = spec["representation"]
        if arm.get("representation") != rep:
            errors.append(f"{identifier}: representation differs from registration")
        if type(arm.get("checks")) is not int or arm["checks"] <= 0:
            errors.append(f"{identifier}: no executed checks")
        expected_clears = 514 if spec["epoch_bits"] == 8 else 2
        first_clear = 256 if spec["epoch_bits"] == 8 else 65536
        if (arm.get("natural_clear_count") != expected_clears or arm.get("natural_first_clear") != first_clear
                or arm.get("natural_last_clear") != 131071):
            errors.append(f"{identifier}: incorrect observed primitive clear events")
        for key in ("size_bytes", "align_bytes", "stride_bytes"):
            if type(arm.get(key)) is not int or arm[key] <= 0:
                errors.append(f"{identifier}: invalid {key}")
        if all(type(arm.get(k)) is int and arm[k] > 0 for k in ("size_bytes", "align_bytes", "stride_bytes")):
            size, align, stride = (arm[k] for k in ("size_bytes", "align_bytes", "stride_bytes"))
            if align & (align - 1) or stride != size or stride % align:
                errors.append(f"{identifier}: impossible alignment/array stride")
            if rep == "packed" and (size != logical // 8 or align != 1):
                errors.append(f"{identifier}: packed storage is not exact9/10-byte align1")
            if rep in ("source", "word", "split") and size != 8:
                errors.append(f"{identifier}: base/source word is not eight bytes")
            if rep == "padded" and size != 16:
                errors.append(f"{identifier}: padded control is not sixteen bytes")
            if rep == "aligned" and size < logical // 8:
                errors.append(f"{identifier}: aligned storage lacks logical capacity")
        if rep == "split" and arm.get("tail_stride_bytes") != (logical - 64) // 8:
            errors.append(f"{identifier}: split tail stride is incorrect")
        if arm.get("base_array_bytes") != 64 * arm.get("stride_bytes", 0):
            errors.append(f"{identifier}: incorrect base-array accounting")
        if rep == "split":
            expected_tail = 64 * (logical - 64) // 8
            if arm.get("allocated_tail_bytes") != expected_tail or arm.get("tail_capacity_bytes") != expected_tail:
                errors.append(f"{identifier}: incorrect fully prepared tail accounting")
            if type(arm.get("descriptor_bytes")) is not int or arm["descriptor_bytes"] <= 0:
                errors.append(f"{identifier}: missing bounded sidecar descriptor accounting")
        if rep in ("aligned", "packed") and arm.get("tail_offset_bytes") != 8:
            errors.append(f"{identifier}: tail offset differs from registered mapping")
        if arm.get("record_bytes") != 5 + (logical - 64) // 8:
            errors.append(f"{identifier}: semantic record truncates or adds fields")
        digest = arm.get("semantic_digest")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{16}", digest):
            errors.append(f"{identifier}: invalid supplementary FNV64 digest")
        else:
            digests.setdefault(logical, set()).add(digest)
        try:
            raw = bytes.fromhex(arm["semantic_records_hex"])
            length = 5 + (logical - 64) // 8
            if len(raw) != arm["record_count"] * length or arm["record_count"] != 64:
                errors.append(f"{identifier}: truncated semantic record stream")
            # Independently reduce explicit byte records; never hash C++ structs.
            reduced = 14695981039346656037
            for byte in raw:
                reduced = ((reduced ^ byte) * 1099511628211) & ((1 << 64) - 1)
            if f"{reduced:016x}" != digest:
                errors.append(f"{identifier}: semantic bytes/digest disagree")
            records.setdefault(logical, set()).add(raw)
        except (KeyError, ValueError, TypeError):
            errors.append(f"{identifier}: missing or invalid lossless semantic bytes")
        try:
            raw = bytes.fromhex(arm["width_only_records_hex"])
            if arm["width_only_record_bytes"] != 5 or arm["width_only_record_count"] != 64 or len(raw) != 320:
                errors.append(f"{identifier}: incorrect width-only record framing")
            reduced = 14695981039346656037
            for byte in raw:
                reduced = ((reduced ^ byte) * 1099511628211) & ((1 << 64) - 1)
            if f"{reduced:016x}" != arm["width_only_semantic_digest"]:
                errors.append(f"{identifier}: width-only bytes/digest disagree")
            width_only_records.add(raw)
        except (KeyError, ValueError, TypeError):
            errors.append(f"{identifier}: missing width-only exact record stream")
    for width, values in digests.items():
        if len(values) != 1:
            errors.append(f"C{width}: representation/epoch semantic digest disagreement")
    for width, values in records.items():
        if len(values) != 1:
            errors.append(f"C{width}: lossless semantic records differ")
    if len(width_only_records) != 1:
        errors.append("zero-extra width-only records differ across64/72/80")
    return errors


def verify_directory(root: Path) -> dict:
    errors: list[str] = []
    try:
        report = json.loads((root / "run.json").read_text())
        if report.get("schema_version") != 1 or report.get("scope") != "synthetic-storage-only":
            errors.append("invalid collector schema or scope")
        if report.get("status") != "passed":
            errors.append("collector did not complete successfully")
        if report.get("errors"):
            errors.append("collector retained errors")
        files = report["files"]
        if not isinstance(files, dict) or not files:
            raise ValueError("empty artifact ledger")
        for name, entry in files.items():
            data = checked_path(root, name).read_bytes()
            if len(data) != entry["bytes"] or hashlib.sha256(data).hexdigest() != entry["sha256"]:
                errors.append(f"artifact identity mismatch: {name}")
        registration_name = report["registration_file"]
        if registration_name not in files:
            errors.append("registration missing from hashed artifacts")
        registration = json.loads(checked_path(root, registration_name).read_text())
        if registration["execution"]["primary_timing_admitted"] is not False:
            errors.append("S0 registration unexpectedly admits primary timing")
        if report["baseline_commit"] != registration["execution_baseline"]:
            errors.append("baseline/registration disagreement")
        for name, expected_hash in registration["baseline_control_sha256"].items():
            if (report.get("baseline_control_sha256", {}).get(name) != expected_hash
                    or report["source_sha256"].get(name) != expected_hash):
                errors.append("production control differs from frozen baseline: " + name)
        modes = report["configurations"]
        if [mode["name"] for mode in modes] != ["normal", "sanitized"]:
            errors.append("normal and sanitized configurations were not both executed")
        all_results = []
        for mode in modes:
            if mode.get("binary") not in files:
                errors.append(f"{mode['name']}: binary identity missing")
            flags = registration["execution"]["sanitizer_flags" if mode["name"] == "sanitized" else "normal_flags"]
            command = mode.get("compile", {}).get("command", [])
            if command[1:1 + len(flags)] != flags:
                errors.append(f"{mode['name']}: compile flags differ from registration")
            for phase in ("compile", "execute"):
                receipt = mode.get(phase, {})
                if receipt.get("exit_code") != 0 or receipt.get("timed_out") is not False:
                    errors.append(f"{mode['name']} {phase} failed or timed out")
                for stream in ("stdout", "stderr"):
                    if receipt.get(stream) not in files:
                        errors.append(f"{mode['name']} {phase} {stream} not retained")
            name = mode.get("result_file")
            if not name or name not in files:
                errors.append(f"{mode['name']}: no hashed result")
                continue
            result = json.loads(checked_path(root, name).read_text())
            errors.extend(f"{mode['name']}: {e}" for e in validate_result(result, registration))
            raw_result = json.loads(checked_path(root, mode["execute"]["stdout"]).read_text())
            if raw_result != result:
                errors.append(f"{mode['name']}: parsed result differs from original stdout")
            stderr = checked_path(root, mode["execute"]["stderr"]).read_text()
            if stderr.strip():
                errors.append(f"{mode['name']}: unexpected test/sanitizer stderr")
            all_results.append(result)
        if len(all_results) == 2:
            for left, right in zip(all_results[0]["arms"], all_results[1]["arms"]):
                if left["id"] != right["id"] or left["semantic_digest"] != right["semantic_digest"]:
                    errors.append("normal/sanitized semantic result disagreement")
        for name, digest in report["source_sha256"].items():
            snapshot = "source/" + name
            if snapshot not in files or files[snapshot]["sha256"] != digest:
                errors.append(f"source snapshot not retained exactly: {name}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f"unreadable or malformed evidence: {exc}")
    return {"schema_version": 1, "status": "failed" if errors else "passed",
            "scope": "synthetic-storage-evidence-readback", "errors": errors,
            "limitations": ["Hashes verify identity, not trusted publication or authenticity.",
                            "Storage checks and primitive rollover do not qualify World semantics or performance."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    result = verify_directory(parser.parse_args().directory.resolve())
    print(json.dumps(result, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
