"""Reopen every original known-matrix result before admitting its coverage."""
from __future__ import annotations

from collections import Counter
import gzip
import json
from pathlib import Path

import replay_known_controls as replay
import runtime_custody as custody


def policy_options(policy: str) -> dict:
    # Exact existing replay_known_control.cpp / assembly004::Options contract.
    return {"rounds": 1 if policy == "both_round1" else 0 if policy == "both_round0" else 2,
            "vocabulary": True, "hierarchy": True, "shared_ownership": policy != "both_fixed_territory",
            "frame_adaptation": policy != "both_frame_frozen", "mosaic_adaptation": policy != "both_mosaic_frozen",
            "optional_negotiation": policy != "both_hard_only", "native_mosaic_bearing": True,
            "supported_native_receptors": policy not in ("off_off", "compact_only"),
            "compact_native_termination": policy not in ("off_off", "receptor_only"),
            "final_validation": True, "shared_extent": 13, "orientation_preference": -1}


def validate_case(directory: Path, row: dict, index: int, case: tuple, definition: str) -> dict:
    expected = {"case_id": index, **dict(zip(("fixture", "profile", "seed", "policy"), case))}
    custody.require(all(type(row.get(key)) is type(value) and row.get(key) == value for key, value in expected.items()),
                    "Known control missing, duplicated or rebound: " + str(index))
    custody.require(type(row.get("exitcode")) is int and row["exitcode"] == 0 and "error" not in row
                    and row.get("timed_out", False) is False and row.get("cancelled", False) is False,
                    "Known control original child failed: " + str(index))
    name = f"case-{index:03}.json.gz"
    path = directory / name
    custody.require(row.get("file") == name and path.is_file() and not path.is_symlink(),
                    "Known control original native output is absent: " + name)
    compressed = path.read_bytes()
    custody.require(type(row.get("gzip_bytes")) is int and row["gzip_bytes"] == len(compressed)
                    and row.get("gzip_sha256") == replay.sha(compressed), "Known control compressed bytes changed: " + name)
    raw = gzip.decompress(compressed)
    custody.require(type(row.get("raw_bytes")) is int and row["raw_bytes"] == len(raw)
                    and row.get("raw_sha256") == replay.sha(raw), "Known control original JSON bytes changed: " + name)
    value = json.loads(raw)
    custody.require(isinstance(value, dict) and type(value.get("schema")) is int and value["schema"] == 5
                    and value.get("type") == "reciprocal_assembly" and value.get("source") == "swarm005-unseen-holdout-v1"
                    and value.get("status") in ("complete", "blocked", "unsat", "exhausted", "cancelled", "oscillation")
                    and type(value.get("can_apply")) is bool, "Known control native document failed: " + name)
    inputs = value.get("input", {})
    for owner, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0.")):
        request = inputs.get(owner, {})
        custody.require(request.get("definition") == prefix + definition
                        and request.get("source") == "swarm005-unseen-holdout-v1"
                        and request.get("fixture") == case[0] and request.get("profile", {}).get("name") == case[1]
                        and type(request.get("seed")) is int and request["seed"] == case[2],
                        "Known control native input differs: " + name + ":" + owner)
    options = policy_options(case[3])
    actual = inputs.get("options", {})
    custody.require(set(actual) == set(options)
                    and all(type(actual[key]) is type(value) and actual[key] == value for key, value in options.items()),
                    "Known control native policy differs: " + name)
    metrics = replay.metrics(value)
    custody.require(all(type(row.get(key)) is type(item) and row.get(key) == item for key, item in metrics.items())
                    and row.get("behavior_sha256") == replay.behavior_hash(value),
                    "Known control summary differs from original native state: " + name)
    custody.require(value["can_apply"] == (value["status"] == "complete" and metrics["closure_evaluated"]
                                          and metrics["still_required"] == 0)
                    and not any(value.get("metrics", {}).get(key, 0) for key in ("hard_violations", "protected_violations")),
                    "Known control native Apply/protection invariant failed: " + name)
    custody.require(row.get("stdout") == value["status"] + " apply=" + str(int(value["can_apply"])) + "\n"
                    and row.get("stderr") == "", "Known control original completion differs: " + name)
    return metrics


def validate_known_controls(directory: Path, receipt: dict) -> dict:
    value = json.loads((directory / "manifest.json").read_bytes())
    custody.require(value.get("result") == "PASS" and value.get("schema") == 1
                    and value.get("programme") == "SWARM004-005-mainline-known-matrix-regression"
                    and value.get("registration") == "https://github.com/techrote/cybersand/issues/698"
                    and value.get("qualifying_source") is True and value.get("unseen") is False
                    and value.get("source") == custody.source() and value.get("errors") == []
                    and value.get("expected_cases") == len(replay.CASES) == 360
                    and value.get("normalization") == replay.NORMALIZATION,
                    "Known controls changed source, registration, classification or complete scope")
    custody.require(value.get("driver_sha256") == custody.sha(custody.ROOT / "tools/swarm45/replay_known_control.cpp")
                    and value.get("runner_sha256") == custody.sha(custody.ROOT / "tools/swarm45/replay_known_controls.py")
                    and value.get("executable_sha256") == receipt["files"]["replay_swarm005_known"]["sha256"],
                    "Known controls did not use the qualified source-built driver")
    rows = value.get("records", [])
    custody.require(isinstance(rows, list) and len(rows) == len(replay.CASES), "Known controls omitted original executions")
    for index, (row, case) in enumerate(zip(rows, replay.CASES)):
        validate_case(directory / "candidate", row, index, case, receipt["native_definition_sha256"])
    summary = {policy: dict(Counter(row["status"] for row in rows if row["policy"] == policy)) for policy in replay.POLICIES}
    custody.require(value.get("summary") == summary, "Known control summary discarded or reclassified outcomes")
    return {"report": "known-controls/manifest.json", "sha256": custody.sha(directory / "manifest.json"),
            "executions": len(rows), "reference_comparison": "separate independent scientific gate"}
