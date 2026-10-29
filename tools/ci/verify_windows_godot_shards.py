#!/usr/bin/env python3
"""Verify complete Windows headless execution across independent CI shards.

This is a source/coverage/log-byte reducer, not an alternative runtime test.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def verify(root: Path, source_sha: str, run_id: str, attempt: str,
           shard_count: int) -> dict:
    require(shard_count >= 1, "shard count must be positive")
    manifests = sorted(root.rglob("windows-execution.json"))
    require(len(manifests) == shard_count,
            f"expected {shard_count} original Windows shard reports, found {len(manifests)}")
    seen_indices: set[int] = set()
    observed: list[str] = []
    baseline: dict | None = None
    receipts = []
    for path in manifests:
        payload_bytes = path.read_bytes()
        report = json.loads(payload_bytes)
        require(report.get("source_commit") == source_sha, f"wrong source: {path}")
        require(str(report.get("run_id")) == str(run_id)
                and str(report.get("run_attempt")) == str(attempt),
                f"wrong run/attempt: {path}")
        index = report.get("shard_index")
        require(report.get("shard_count") == shard_count
                and isinstance(index, int) and not isinstance(index, bool)
                and 0 <= index < shard_count and index not in seen_indices,
                f"duplicate or invalid shard: {path}")
        seen_indices.add(index)
        require(report.get("status") == "passed"
                and report.get("completed") is True
                and not report.get("errors") and not report.get("source_drift"),
                f"failed, incomplete or drifted shard: {path}")
        applicable = report.get("applicable_cases")
        assigned = report.get("assigned_cases")
        excluded = report.get("out_of_scope_graphical_cases")
        require(isinstance(applicable, list) and all(isinstance(x, str) for x in applicable)
                and len(applicable) == len(set(applicable))
                and len(applicable) == report.get("applicable_case_count"),
                f"invalid full Windows case inventory: {path}")
        require(isinstance(assigned, list) and len(assigned) > 0
                and len(assigned) == len(set(assigned))
                and set(assigned).issubset(applicable),
                f"invalid shard assignment: {path}")
        require(isinstance(excluded, list) and not (set(applicable) & set(excluded))
                and len(applicable) + len(excluded) == report.get("all_discovered_case_count"),
                f"invalid explicit graphical exclusion: {path}")
        plan = report.get("case_plan", [])
        require(isinstance(plan, list)
                and [x.get("name") for x in plan] == assigned,
                f"case plan disagrees with assignment: {path}")
        records = report.get("results", [])
        require(isinstance(records, list), f"invalid test records: {path}")
        preflight = [x for x in records if x.get("role") == "preflight"]
        tests = [x for x in records if x.get("role") == "case"]
        require(len(preflight) == 1 and preflight[0].get("name") == "import"
                and len(tests) == len(assigned)
                and [x.get("name") for x in tests] == assigned
                and report.get("executed_case_count") == len(assigned)
                and len(preflight) + len(tests) == len(records)
                and all(x.get("status") == "passed" for x in records),
                f"missing, duplicated, unexecuted or failed case: {path}")
        log_hashes = report.get("log_sha256", {})
        require(isinstance(log_hashes, dict)
                and set(log_hashes) == {x.get("log") for x in records}
                and len(log_hashes) == len(records),
                f"missing or extra raw test log seals: {path}")
        for relative, expected in log_hashes.items():
            log_rel = Path(relative)
            require(not log_rel.is_absolute() and ".." not in log_rel.parts,
                    f"unsafe raw test path: {relative}")
            log_path = path.parent / log_rel
            require(log_path.is_file()
                    and hashlib.sha256(log_path.read_bytes()).hexdigest() == expected,
                    f"modified or missing original raw log: {log_path}")
        identity = {
            name: report.get(name) for name in (
                "source_commit", "source_tree", "runtime_source_commit",
                "runtime_build_commit", "runtime_provenance",
                "native_source_inputs", "cybersand_runtime", "rapier_runtime",
                "godot_identity", "godot_version", "tested_inputs",
                "all_discovered_case_count", "applicable_case_count",
                "applicable_cases", "out_of_scope_graphical_cases",
            )
        }
        if baseline is None:
            baseline = identity
        else:
            require(identity == baseline,
                    f"platform/runtime/source/inventory mismatch between Windows shards: {path}")
        observed.extend(assigned)
        receipts.append({
            "shard_index": index,
            "report_path": str(path),
            "report_sha256": hashlib.sha256(payload_bytes).hexdigest(),
            "case_count": len(assigned),
            "raw_logs_verified": len(records),
            "test_names": assigned,
        })
    require(seen_indices == set(range(shard_count)), "missing Windows shard index")
    assert baseline is not None
    expected_cases = baseline["applicable_cases"]
    require(Counter(observed) == Counter(expected_cases)
            and len(observed) == len(set(observed)),
            "missing or duplicated cases across Windows shards")
    return {
        "schema": "windows-godot-sharded-coverage-v1",
        "run_id": str(run_id),
        "attempt": str(attempt),
        "source_sha": source_sha,
        "source_tree": baseline["source_tree"],
        "shard_count": shard_count,
        "applicable_case_count": len(expected_cases),
        "graphical_cases_explicitly_out_of_scope": baseline["out_of_scope_graphical_cases"],
        "unique_case_count": len(set(observed)),
        "raw_logs_verified": sum(x["raw_logs_verified"] for x in receipts),
        "shards": sorted(receipts, key=lambda r: r["shard_index"]),
        "status": "passed",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--attempt", required=True)
    parser.add_argument("--shard-count", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.root, args.source_sha, args.run_id,
                    args.attempt, args.shard_count)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"WINDOWS_SHARD_COVERAGE PASS: {result['unique_case_count']} "
          f"cases across {args.shard_count} actual Windows shards, "
          f"{result['raw_logs_verified']} authenticated logs", flush=True)


if __name__ == "__main__":
    main()
