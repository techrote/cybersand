#!/usr/bin/env python3
"""Read-only independent replay of the original near-cap Apply evidence.

No application code is imported, no native World is created, and no request is
sent. Every original ZIP member is checked. Complete audit values are rebuilt
from the pinned fixture definition, not accepted merely because a receipt says
they are complete. The only output is a JSON review record on stdout.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile

ARCHIVE_SHA = "461b2b4135e2592ac8fcd230281118398c1376afb6a9617100cd1eaf9f007b79"
MANIFEST_SHA = "b2012bed57c43ffcecf305412218a579403810ffe804d506e2f84a78ea641ada"
COMPARISON_SHA = "88e0bc8e7180e7ba7c4c21b91ff4501cb9465032d2bf5b059d04a46ed68dd7f1"
COMPLETE_SHA = "ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a"
BYTES = 16 * 1024 * 1024 - 8192
CANARY = b"art-fixture-private-key::2026-QA"
PINS = [
    ("baseline-e536", "e536d128f85e948223b25e13931a7a801faf956d",
     "61d38ec119665270a9fb4eea9ae78836348d7092", 22),
    ("prepared-8a0", "8a015efbeb7926a3c835303d3b163c01d353aca3",
     "ad991f1fe8e2c8945120526377d85392d0a3212a", 23),
]
checks = 0


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def object_value(data: bytes) -> dict:
    value = json.loads(data.decode("utf-8"))
    require(isinstance(value, dict), "Expected an object")
    return value


def replay_audit(data: bytes, expected: str) -> dict:
    require(CANARY not in data, "Fixture credential survived in complete audit")
    rows = data.decode("utf-8").splitlines()
    require(bool(rows), "Missing admitted audit")
    header = json.loads(rows[0])
    require(header["kind"] == "session_start" and header["schema"] == 2,
            "Missing complete session header")
    segment = header["segment_id"]
    counts: dict[str, int] = {}
    original = []
    edited = []
    for index, row in enumerate(rows[1:], 1):
        event = json.loads(row)
        require(event["segment_id"] == segment and event["event_index"] == index
                and event["event_id"] == segment + ":" + str(index),
                "Noncontiguous admitted audit identity")
        kind = event["kind"]
        counts[kind] = counts.get(kind, 0) + 1
        value = event["data"]
        if kind == "conversation":
            require(value["role"] == "user" and isinstance(value["content"], str),
                    "Malformed baseline conversation")
            original.append(value["content"])
        elif kind == "conversation_edited":
            require(isinstance(value["turns"], list) and len(value["turns"]) == 1
                    and value["turns"][0]["role"] == "user" and isinstance(value["last_result"], str),
                    "Malformed complete edited snapshot")
            edited.append(value["turns"][0]["content"])
    require(counts.get("request", 0) == 0, "Model request appeared in Apply audit")
    require(len(original) == 1 and original[0] == "x" * BYTES,
            "Original complete baseline value differs")
    require(len(edited) == 1 and edited[0] == expected,
            "Changed first character or unshown complete suffix differs")
    require(len(edited[0].encode("utf-8")) == BYTES
            and sha(edited[0].encode("utf-8")) == COMPLETE_SHA,
            "Exact edited byte/hash identity differs")
    return {"audit_bytes": len(data), "audit_sha256": sha(data),
            "events": len(rows)-1, "event_kinds": counts,
            "complete_value_bytes": BYTES, "complete_value_sha256": COMPLETE_SHA}


def verify(archive_path: Path, manifest_path: Path, comparison_path: Path) -> dict:
    compressed = archive_path.read_bytes()
    manifest_bytes = manifest_path.read_bytes()
    comparison_bytes = comparison_path.read_bytes()
    require(len(compressed) == 89454 and sha(compressed) == ARCHIVE_SHA, "Original ZIP differs")
    require(sha(manifest_bytes) == MANIFEST_SHA, "Original manifest differs")
    require(sha(comparison_bytes) == COMPARISON_SHA, "Original comparison differs")
    manifest = object_value(manifest_bytes)
    comparison = object_value(comparison_bytes)
    declared = {entry["path"]: entry for entry in manifest["entries"]}
    require(len(declared) == len(manifest["entries"]) == 29, "Payload denominator differs")
    require(sum(entry["bytes"] for entry in declared.values()) == 67120420,
            "Original payload byte denominator differs")
    for name, entry in declared.items():
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and "\\" not in name
                and 0 <= entry["bytes"] <= 40 * 1024 * 1024,
                "Unsafe or unbounded original path")
    payload: dict[str, bytes] = {}
    with zipfile.ZipFile(io.BytesIO(compressed)) as archive:
        members = archive.infolist()
        require(len(members) == len({m.filename for m in members}) == 30,
                "ZIP denominator or unique paths differs")
        require(sum(m.file_size for m in members) <= 80 * 1024 * 1024,
                "ZIP exceeds bounded review capacity")
        extra = [member for member in members if member.filename not in declared]
        require(len(extra) == 1 and archive.read(extra[0]) == manifest_bytes,
                "Unexpected unmanifested member or different embedded manifest")
        for member in members:
            if member.filename not in declared:
                continue
            entry = declared[member.filename]
            require(not member.is_dir() and member.file_size == entry["bytes"],
                    "Member metadata differs: " + member.filename)
            data = archive.read(member)  # Complete read checks original ZIP CRC.
            require(len(data) == entry["bytes"] and sha(data) == entry["sha256"],
                    "Member CRC/SHA differs: " + member.filename)
            payload[member.filename] = data
    require(payload["comparison.json"] == comparison_bytes, "Embedded comparison differs")
    require(len(comparison["arms"]) == 2, "Matched-arm denominator differs")
    expected = "Z" + "x" * (BYTES-1)
    require(sha(expected.encode()) == COMPLETE_SHA, "Independent fixture reconstruction differs")
    results = []
    for index, (name, source, tree, expected_checks) in enumerate(PINS):
        arm = comparison["arms"][index]
        require(arm["arm"] == name and arm["exit_code"] == 0, "Arm identity or exit differs")
        for state in ("source_before", "source_after"):
            require(arm[state]["commit"] == source and arm[state]["tree"] == tree
                    and arm[state]["tracked_source_clean"] is True,
                    "Source custody differs: " + name)
        report = object_value(payload[name+"/report.json"])
        require(report == arm["report"], "Original report differs from comparison: " + name)
        require(report["checks"] == expected_checks and report["failures"] == []
                and report["completion_phase"] == "completed" and report["display"] == "headless",
                "Original headless completion differs")
        log = payload[name+"/godot.log"].decode("utf-8")
        markers = [line[len("ART_WORKBENCH_FINAL_RESULT "):] for line in log.splitlines()
                   if line.startswith("ART_WORKBENCH_FINAL_RESULT ")]
        require(len(markers) == 1, "Missing unique final native-process marker")
        terminal = json.loads(markers[0])
        require(terminal["checks"] == expected_checks and terminal["failures"] == []
                and terminal["cases"] == report["cases"],
                "Original process marker differs from wrapper report")
        assertions = [line for line in log.splitlines() if line.startswith("ART_FINAL_CHECK ")]
        require(len(assertions) == expected_checks and all(line.endswith(" true") for line in assertions),
                "Individual native-process assertion denominator differs")
        require(not any(line.startswith(("ERROR:", "SCRIPT ERROR:")) for line in log.splitlines()),
                "Completed process contains an engine/script error")
        audit_names = [key for key in payload if key.startswith(name+"/")
                       and "/art-traffic/" in key and key.endswith(".jsonl")]
        require(len(audit_names) == 1, "Unexpected original audit denominator")
        audit = replay_audit(payload[audit_names[0]], expected)
        proof = object_value(payload[name+"/audit-verification.json"])
        require(proof == arm["audit"], "Original audit proof differs from comparison")
        require(proof["archives"] == 1 and proof["credential_redacted"] is True
                and proof["complete_conversations"][0]["bytes"] == BYTES
                and proof["complete_conversations"][0]["sha256"] == COMPLETE_SHA
                and proof["complete_conversations"][0]["model_requests"] == 0,
                "Published complete-value proof disagrees with replay")
        require(len(report["cases"]) == 1, "Unexpected measured-case denominator")
        case = report["cases"][0]
        require(case["context_bytes"] == BYTES and case["actual_sha256"] == COMPLETE_SHA
                and case["expected_sha256"] == COMPLETE_SHA and case["visible_characters"] == 4096,
                "Measured case differs from full audit")
        require(case["last_audit"]["stored"] is True
                and case["last_audit"]["kind"] == "conversation_edited", "No actual edited append")
        results.append({"arm": name, "source": source, "tree": tree, "checks": expected_checks,
                        "audit": audit, "case": case,
                        "runtime_hash_record": object_value(payload[name+"/hashes.json"])})
    baseline, candidate = (result["case"] for result in results)
    require(candidate["asynchronous_apply"] is True
            and candidate["apply_preparation"]["status"] == "committed",
            "Candidate did not complete the asynchronous owner commit")
    require(candidate["apply_usec"] == 43440 and baseline["apply_usec"] == 620436
            and candidate["frames"]["max_usec"] == 73356 and baseline["frames"]["max_usec"] == 639012,
            "Original responsiveness observations differ")
    require(candidate["apply_completion_usec"] - baseline["apply_usec"] == 24543,
            "Slower complete latency was lost")
    return {"schema": "art-near-cap-apply-raw-independent-review-v1", "status": "passed",
            "checks": checks, "archive_sha256": ARCHIVE_SHA, "manifest_sha256": MANIFEST_SHA,
            "comparison_sha256": COMPARISON_SHA, "verified_original_files": len(payload),
            "zip_members_including_manifest": 30, "original_payload_bytes": 67120420,
            "matched_complete_value_bytes": BYTES, "matched_complete_value_sha256": COMPLETE_SHA,
            "results": results, "completion_difference_usec": 24543,
            "limits": ["Independent byte/record replay, not another application run.",
                       "One sequential baseline-first pair; no statistical generalization.",
                       "Headless native Workbench; no Windows or physical/graphical acceptance.",
                       "Action/frame blocking improved in this pair; complete latency is slower.",
                       "Earlier incomplete low-memory attempts remain separate retained outcomes."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("comparison", type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.archive, args.manifest, args.comparison)
    except (ValueError, KeyError, TypeError, OSError, zipfile.BadZipFile, json.JSONDecodeError) as error:
        result = {"schema": "art-near-cap-apply-raw-independent-review-v1",
                  "status": "failed", "checks": checks, "error": str(error)}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
