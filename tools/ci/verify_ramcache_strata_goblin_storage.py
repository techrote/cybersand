#!/usr/bin/env python3
"""Independently read the unchanged Goblin storage runner's original evidence.

This verifies the actual runner's recorded output bytes, guard observations,
fault inventory and retry results. The original runner does not record child
PIDs or held process lifetimes; this reader does not invent either claim.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import re

INPUTS = (
    "godot/goblin/goblin_controller.gd",
    "godot/goblin/goblin_adapter.gd",
    "godot/goblin/goblin_corpus.gd",
    "godot/goblin/goblin_transcript.gd",
    "godot/scripts/workbench_file_transaction.gd",
    "godot/tests/goblin_storage_fault_child.gd",
    "godot/native_extension/material_baseline_file.cpp",
    "tools/ci/windows_file_lock.py",
    "tools/ci/run_goblin_storage_qualification.py",
)
ERRORS = re.compile(r"SCRIPT ERROR|Parse Error|Failed to load script|Invalid call|Invalid access|^ERROR:", re.MULTILINE)
FIXTURE = "ULTIMA fixed audit writer, not a campaign transcript"
PAYLOAD = "Complete observed bytes. " * 64
STALE = b"Unrelated retained diagnostic staging\n"
MARKER = "GOBLIN_STORAGE_RESULT "


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def path_spelling(value: object, platform: str) -> str:
    require(isinstance(value, str), "Goblin fixed target is not a path string")
    # Godot records forward slashes while pathlib records backslashes on Windows.
    # Preserve every other character: no case folding, resolution or dot collapse.
    spelling = value.replace("\\", "/") if platform == "win32" else value
    require(all(part not in (".", "..") for part in spelling.split("/")),
            "Goblin fixed target contains a traversal or dot component")
    return spelling


def verify_storage_evidence(folder: Path, *, expected_source: str, platform: str,
                            engine_path: str, project_path: str, engine_sha256: str,
                            engine_version: str, expected_inputs: dict[str, str]) -> dict:
    folder = folder.resolve(strict=True)
    report = json.loads((folder / "report.json").read_text(encoding="utf-8"))
    require(platform in ("linux", "win32"), "Unsupported Goblin evidence platform")
    require(report.get("schema") == "goblin-storage-qualification-v1"
            and report.get("status") == "passed" and report.get("completed") is True
            and report.get("source_head") == expected_source and report.get("platform") == platform
            and report.get("engine_version") == engine_version and report.get("engine_sha256") == engine_sha256,
            "Goblin report identity, source or result differs")
    require(set(expected_inputs) == set(INPUTS) and report.get("input_sha256") == expected_inputs,
            "Goblin report omitted or changed an actual source input")
    requested = [7, 8, 7, 8, 8] + ([7, 8, 8] if platform == "linux" else [])
    observed = [7, 8, 7, 7, 8] + ([7, 7, 8] if platform == "linux" else [])
    acknowledged = [True, True, True, False, True] + ([True, False, True] if platform == "linux" else [])
    executions = report.get("executions")
    cases = report.get("cases")
    require(isinstance(executions, list) and len(executions) == len(requested)
            and isinstance(cases, list) and len(cases) == (3 if platform == "linux" else 2),
            "Goblin fault or execution inventory is incomplete or duplicated")
    command = [engine_path, "--headless", "--audio-driver", "Dummy", "--path", project_path,
               "--script", "res://tests/goblin_storage_fault_child.gd"]
    target = None
    for index, row in enumerate(executions):
        prefix = f"{index + 1:02}"
        expected_log = prefix + f"-seed-{requested[index]}.log"
        expected_capture = prefix + "-observed-output.bin"
        require(row.get("command") == command and row.get("natural_completion") is True
                and row.get("engine_error_detected") is False
                and row.get("acknowledged") is acknowledged[index]
                and type(row.get("exit_code")) is int and row["exit_code"] == (0 if acknowledged[index] else 2)
                and row.get("log") == expected_log and row.get("retained_bytes") == expected_capture,
                "Goblin execution differs from its registered command, order or completion")
        log = folder / expected_log
        capture = folder / expected_capture
        require(log.is_file() and not log.is_symlink() and capture.is_file() and not capture.is_symlink(),
                "Goblin original output or log is missing or linked")
        text = log.read_text(encoding="utf-8")
        headers = [line for line in text.splitlines() if line.startswith("Godot Engine v")]
        require(headers == [f"Godot Engine v{engine_version} - https://godotengine.org"]
                and not ERRORS.search(text) and row.get("log_sha256") == sha(log),
                "Goblin original log is changed, failed or from another engine")
        markers = [line[len(MARKER):] for line in text.splitlines() if line.startswith(MARKER)]
        require(len(markers) == 1, "Goblin original guarded-writer marker is missing or duplicated")
        probe = json.loads(markers[0])
        require(probe == row.get("guards") and probe.get("acknowledged") is acknowledged[index]
                and all(probe.get(key) is True for key in
                        ("profile_verified", "wrong_path_refused", "wrong_profile_refused", "guards_preserved"))
                and path_spelling(probe.get("path"), platform) == path_spelling(row.get("path"), platform)
                and isinstance(probe.get("error"), str) and probe["error"] == row.get("error"),
                "Goblin guard observations disagree with original process output")
        if target is None:
            target = path_spelling(probe["path"], platform)
        require(path_spelling(probe["path"], platform) == target,
                "Goblin executions did not use the same fixed output")
        require((not probe["error"]) if acknowledged[index] else
                ("not replaced" in probe["error"] or "did not replace the previous file" in probe["error"]),
                "Goblin replacement did not disclose its actual success or preservation")
        content = json.loads(capture.read_text(encoding="utf-8"))
        require(content == {"fixture": FIXTURE, "payload": PAYLOAD, "seed": observed[index]}
                and type(content["seed"]) is int and row.get("complete_json") is True
                and type(row.get("value")) is int and row["value"] == observed[index]
                and type(row.get("bytes")) is int and row["bytes"] == capture.stat().st_size
                and row.get("sha256") == sha(capture),
                "Goblin observed complete bytes do not prove the expected retained or replaced output")
    require(cases[0].get("fault") == "none" and cases[0].get("evidence_class") == "guarded-fixed-writer"
            and cases[0].get("before") == executions[0] and cases[0].get("replacement") == executions[1]
            and cases[0].get("stale_partial_sha256") == hashlib.sha256(STALE).hexdigest(),
            "Goblin ordinary replacement or stale-staging receipt differs")
    faults = (["locked-target"] if platform == "win32" else
              ["RLIMIT_FSIZE-128-buffered-tail-SIGXFSZ-ignored", "directory-permission-denied"])
    for index, fault in enumerate(faults):
        row = cases[index + 1]
        before, refusal, retry = executions[2 + index * 3:5 + index * 3]
        require(row.get("fault") == fault and row.get("evidence_class") == "real-os-failure"
                and row.get("before") == before and row.get("refusal") == refusal and row.get("retry") == retry
                and refusal["sha256"] == before["sha256"] and refusal["bytes"] == before["bytes"]
                and retry["sha256"] != before["sha256"],
                "Goblin OS refusal/retry sequence did not preserve old output and then replace it")
        if platform == "win32":
            require(row.get("lock") == {"desired_access": 0x80000000, "share_mode": 1,
                                        "delete_access_probe_error": 32},
                    "Goblin Windows fault lacks the actual verified DELETE sharing refusal")
        elif index == 0:
            require(type(row.get("limit_bytes")) is int and row["limit_bytes"] == 128,
                    "Goblin file-size fault did not retain its original 128-byte limit")
    profiles = list(folder.glob("profile-*"))
    require(len(profiles) == 1 and profiles[0].is_dir() and not profiles[0].is_symlink(),
            "Goblin original isolated profile is missing or ambiguous")
    profile = profiles[0]
    marker = profile / "goblin-profile.json"
    require(marker.is_file() and not marker.is_symlink()
            and json.loads(marker.read_text(encoding="utf-8")) == {"schema": "cybersand-goblin-profile-v1"},
            "Goblin selected-profile proof changed")
    recorded = PureWindowsPath(target) if platform == "win32" else PurePosixPath(target)
    require(recorded.is_absolute() and recorded.parts.count(profile.name) == 1,
            "Goblin fixed target is outside its recorded disposable profile")
    parts = recorded.parts[recorded.parts.index(profile.name) + 1:]
    require(len(parts) >= 2 and parts[-2:] == ("goblin", "transcript.json")
            and all(part not in ("", ".", "..") for part in parts), "Goblin target escaped its fixed output")
    retained = profile.joinpath(*parts)
    require(retained.is_file() and not retained.is_symlink() and sha(retained) == executions[-1]["sha256"],
            "Goblin final profile no longer contains the acknowledged complete retry")
    stale = retained.with_name(retained.name + ".partial")
    require(stale.is_file() and not stale.is_symlink() and stale.read_bytes() == STALE,
            "Goblin writer changed unrelated retained staging")
    return {"schema": "ramcache-strata-goblin-storage-review-v1", "status": "passed", "platform": platform,
            "source_commit": expected_source, "executions": len(executions), "faults": faults,
            "original_byte_hashes": [row["sha256"] for row in executions],
            "scope": "Original guarded-writer OS fault receipts and bytes; no child PID/lifetime claim"}
