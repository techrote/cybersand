#!/usr/bin/env python3
"""Read-only custody and full-audit replay for the published Apply experiment.

This verifies existing bytes. It imports no Art code, creates no World, invokes
no model and writes nothing except its JSON stdout. The independently authored
method is intended for a lead-brokered run when the reviewer's executor is absent.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile

SOURCE = "8a015efbeb7926a3c835303d3b163c01d353aca3"
TREE = "ad991f1fe8e2c8945120526377d85392d0a3212a"
ARCHIVE_SHA = "047252caaabaeec69f7344053a56a92b097aac87ece9032ff65f37d281b7185f"
MANIFEST_SHA = "6f93ee286b606b7fe66111a69c20e038ee481fc8f78f618eba39a71ea4d9605c"
LOG_SHA = "79efe35050fe215372ceadcf9c319705a8ce2e0c4d1e94a103a3d57e649c34ec"
EDITED_SHA = "326174c77f57722f97786401a4ee5356c7fd261aeb8c4d176d52b41010e3cff4"
CANARY = "ART-APPLY-PRIVATE-2026-11-25"
MAX_TOTAL = 64 * 1024 * 1024
MAX_MEMBER = 32 * 1024 * 1024
checks = 0


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def terminal(text: str, marker: str) -> dict:
    matches = [line[len(marker)+1:] for line in text.splitlines()
               if line.startswith(marker + " ")]
    require(len(matches) == 1, "Expected exactly one terminal marker: " + marker)
    value = json.loads(matches[0])
    require(isinstance(value, dict), "Terminal marker is not an object")
    return value


def read_json(data: bytes) -> dict:
    value = json.loads(data.decode("utf-8"))
    require(isinstance(value, dict), "Expected a JSON object")
    return value


def failure_count(value: object) -> int:
    return len(value) if isinstance(value, list) else int(value)


def verify(archive_path: Path, manifest_path: Path) -> dict:
    archive_bytes = archive_path.read_bytes()
    manifest_bytes = manifest_path.read_bytes()
    require(len(archive_bytes) == 114221 and sha(archive_bytes) == ARCHIVE_SHA,
            "Original compressed archive identity differs")
    require(sha(manifest_bytes) == MANIFEST_SHA, "Published manifest bytes differ")
    manifest = read_json(manifest_bytes)
    require(manifest["current_combined_source"] == SOURCE and manifest["current_tree"] == TREE,
            "Manifest source/tree differs from the reviewed experiment")
    entries = manifest["entries"]
    require(isinstance(entries, list) and len(entries) == 64, "Original member denominator differs")
    declared = {entry["path"]: entry for entry in entries}
    require(len(declared) == len(entries), "Duplicate manifest paths")
    require(sum(int(e["bytes"]) for e in entries) == 31575371, "Original payload byte total differs")
    for name, entry in declared.items():
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and "\\" not in name
                and 0 <= int(entry["bytes"]) <= MAX_MEMBER,
                "Unsafe or unbounded member identity: " + name)
    payload: dict[str, bytes] = {}
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        infos = archive.infolist()
        require(len(infos) == 65 and len({info.filename for info in infos}) == 65,
                "ZIP member denominator or uniqueness differs")
        require(sum(info.file_size for info in infos) <= MAX_TOTAL,
                "ZIP exceeds the bounded review capacity")
        extra = [info for info in infos if info.filename not in declared]
        require(len(extra) == 1, "Unmanifested payload exists beyond the embedded manifest")
        embedded = archive.read(extra[0])  # zipfile verifies the original CRC on complete read.
        require(embedded == manifest_bytes, "Embedded manifest differs from the published one")
        for info in infos:
            if info.filename not in declared:
                continue
            entry = declared[info.filename]
            require(not info.is_dir() and info.file_size == int(entry["bytes"]),
                    "Member metadata differs: " + info.filename)
            data = archive.read(info)  # Complete read validates ZIP CRC as well as SHA below.
            require(len(data) == int(entry["bytes"]) and sha(data) == entry["sha256"],
                    "Original member CRC/SHA identity differs: " + info.filename)
            payload[info.filename] = data

    log = payload["native-8a0-passed/output.log"]
    require(sha(log) == LOG_SHA, "Passing original process log differs")
    text = log.decode("utf-8")
    passed = terminal(text, "ART_CONVERSATION_APPLY_RESULT")
    require(passed["checks"] == 154 and failure_count(passed["failures"]) == 0,
            "Final ordinary Workbench lifecycle did not pass all154 checks")
    require(passed["display"] == "headless" and passed["model_calls"] == 0,
            "Display/model scope differs from this headless fixture experiment")
    lines = [line for line in text.splitlines() if line.startswith("ART_CONVERSATION_APPLY_CHECK ")]
    require(len(lines) == 154 and all(line.endswith(" true") for line in lines),
            "Individual lifecycle assertions do not reproduce the terminal count")
    require(not any(line.startswith(("SCRIPT ERROR:", "ERROR:")) for line in text.splitlines()),
            "Passing process contains an engine/script error")

    audit_names = [name for name in payload
                   if name.startswith("native-8a0-passed/") and "/art-traffic/" in name and name.endswith(".jsonl")]
    require(len(audit_names) == 1, "Passing profile has an unexpected audit-file denominator")
    audit = payload[audit_names[0]]
    require(CANARY.encode() not in audit, "Registered fixture credential leaked into admitted audit")
    events = [json.loads(line) for line in audit.decode("utf-8").splitlines() if line]
    require(events and events[0]["kind"] == "session_start" and events[0]["schema"] == 2,
            "Passing audit lacks a modern complete session header")
    segment = events[0]["segment_id"]
    live: list[dict] = []
    kinds: dict[str, int] = {}
    snapshots = []
    for index, event in enumerate(events[1:], 1):
        require(event["segment_id"] == segment and event["event_index"] == index
                and event["event_id"] == segment + ":" + str(index),
                "Audit event identity/order is not contiguous")
        kind = event["kind"]
        kinds[kind] = kinds.get(kind, 0) + 1
        data = event["data"]
        if kind == "conversation":
            require(isinstance(data, dict) and data.get("role") in ("user", "assistant")
                    and isinstance(data.get("content"), str), "Malformed admitted conversation")
            live.append(data)
        elif kind == "conversation_edited":
            require(isinstance(data, dict) and isinstance(data.get("turns"), list)
                    and isinstance(data.get("last_result"), str), "Incomplete edited snapshot")
            require(all(isinstance(turn, dict) and turn.get("role") in ("user", "assistant")
                        and isinstance(turn.get("content"), str) for turn in data["turns"]),
                    "Edited snapshot contains malformed turns")
            live = data["turns"]
            snapshots.append(data)
        elif kind == "conversation_cleared":
            live = []
    require(kinds.get("request", 0) == 0, "Conversation preparation admitted an HTTP request")
    expected = "prefix [redacted] suffix" + "x" * (1024 * 1024 - 1)
    require(len(expected) == 1048599 and sha(expected.encode()) == EDITED_SHA,
            "Independent complete-value reference identity differs")
    exact = [snapshot for snapshot in snapshots if len(snapshot["turns"]) == 1
             and snapshot["turns"][0]["content"] == expected]
    require(len(exact) == 1, "Complete redacted one-megabyte snapshot is missing or duplicated")
    successes = [outcome for outcome in passed["outcomes"] if outcome.get("case") == "complete-redacted-success"]
    require(len(successes) == 1 and successes[0]["characters"] == len(expected)
            and successes[0]["sha256"] == EDITED_SHA, "Process success receipt differs from exact audit bytes")

    mechanism = terminal(payload["provider-teardown-7e0/test_art_conversation_preparation/output.log"].decode(),
                         "ART_CONVERSATION_PREPARATION_RESULT")
    require(mechanism["checks"] == 66 and failure_count(mechanism["failures"]) == 0
            and mechanism["model_calls"] == 0 and mechanism["actual_http_exchanges"] == 0,
            "Queued-Provider mechanism evidence differs")
    parse_log = payload["native-f909-parse-failure/output.log"].decode()
    require("SCRIPT ERROR:" in parse_log and "seed" in parse_log
            and "ART_CONVERSATION_APPLY_RESULT " not in parse_log, "Original parse failure is not retained")
    fixture_failure = terminal(payload["native-f605-fixture-order-failure/output.log"].decode(),
                               "ART_CONVERSATION_APPLY_RESULT")
    require(fixture_failure["checks"] == 154 and failure_count(fixture_failure["failures"]) == 11,
            "Original stale-editor fixture failure denominator differs")
    incomplete = []
    for name in ("baseline-e536-first-incomplete/execution.json",
                 "pair-second-incomplete/baseline-e536/execution.json"):
        execution = read_json(payload[name])
        code = next((execution[key] for key in ("exit_code", "returncode", "return_code")
                     if key in execution), None)
        require(code == -9, "Incomplete near-cap baseline is not retained as a failure: " + name)
        incomplete.append({"path": name, "execution": execution})
    require(not any(name.startswith("pair-second-incomplete/candidate") for name in payload),
            "Unexpected candidate near-cap arm requires a new comparison interpretation")
    return {"schema": "art-conversation-preparation-raw-review-v1", "status": "passed",
            "checks": checks, "source": SOURCE, "tree": TREE, "archive_sha256": ARCHIVE_SHA,
            "manifest_sha256": MANIFEST_SHA, "verified_original_payload_files": len(payload),
            "verified_zip_members_including_manifest": 65, "original_payload_bytes": 31575371,
            "passing_process_log_sha256": LOG_SHA, "lifecycle_checks": passed["checks"],
            "provider_mechanism_checks": mechanism["checks"], "display": passed["display"],
            "model_calls": 0, "audit_sha256": sha(audit), "audit_bytes": len(audit),
            "audit_events": len(events)-1, "audit_kinds": kinds,
            "complete_redacted_snapshot_characters": len(expected), "complete_redacted_snapshot_sha256": EDITED_SHA,
            "final_replayed_turns": len(live), "native_draw_batches_from_test": 0,
            "retained_failures": {"parse_source": "f9099628", "fixture_source": "f6054aaf",
                                  "fixture_failed_checks": 11, "near_cap_incomplete": incomplete},
            "limits": ["Independent read-only byte/record replay, not another native execution.",
                       "Actual headless lifecycle and one-megabyte snapshot; no graphical or Windows acceptance.",
                       "The two near-cap baselines are incomplete; no completed paired near-cap speedup is claimed.",
                       "No genuine-model or actor-traversal experiment."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.archive, args.manifest)
    except (ValueError, KeyError, TypeError, OSError, zipfile.BadZipFile, json.JSONDecodeError) as error:
        result = {"schema": "art-conversation-preparation-raw-review-v1", "status": "failed",
                  "checks": checks, "error": str(error)}
    print(json.dumps(result, sort_keys=True, indent=2))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
