#!/usr/bin/env python3
"""Verify complete Windows headless execution across independent CI shards.

This is a source/coverage/log-byte reducer, not an alternative runtime test.
"""
import argparse
from collections import Counter
import hashlib
import json
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def source_contract(root: Path, source_sha: str, shard_count: int) -> dict:
    """Derive authority from the exact checkout, never from shard reports.

    The reducer need not materialize either LFS DLL. Compare committed LFS
    object identities and the original archived manifest, not synthetic bytes.
    Actual runtime execution and artifact/run custody remain separate checks.
    """
    import run_godot_regressions as runner
    import run_windows_godot_regressions as windows

    require(windows.git(root, "rev-parse", "HEAD").decode().strip() == source_sha,
            "coverage checkout differs from expected source")
    windows.git(root, "diff", "--exit-code", "HEAD", "--", *windows.INPUT_SCOPES,
                ":!godot/.godot")
    tree = windows.git(root, "rev-parse", "HEAD^{tree}").decode().strip()
    cases = runner.discover_cases(root)
    selected = [case for case in cases if not case.requires_display]
    excluded = [case.name for case in cases if case.requires_display]
    require(bool(selected), "source discovery has no applicable Windows cases")
    shards, _ = runner.build_shard_plan(selected, shard_count)
    raw_manifest = windows.git(root, "show", "HEAD:" + windows.PROVENANCE)
    manifest = json.loads(raw_manifest)
    require(manifest.get("schema_version") == 1
            and manifest.get("artifact") == windows.NATIVE,
            "unexpected source runtime manifest")
    inputs = manifest.get("source_inputs", {})
    require(bool(inputs) and set(inputs) == windows.native_input_paths(root),
            "source runtime manifest does not cover current native inputs")
    for relative, digest in inputs.items():
        content = (root / relative).read_bytes().replace(b"\r\n", b"\n")
        require(hashlib.sha256(content).hexdigest() == digest,
                "source runtime manifest is stale: " + relative)
    binaries = {}
    for relative in (windows.NATIVE, windows.RAPIER):
        pointer = windows.git(root, "show", "HEAD:" + relative)
        match = re.fullmatch(
            rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n",
            pointer,
        )
        require(match is not None, "noncanonical source LFS pointer: " + relative)
        binaries[relative] = {"path": relative, "sha256": match[1].decode(),
                              "size": int(match[2])}
    require(binaries[windows.NATIVE]["sha256"] == manifest.get("sha256")
            and binaries[windows.NATIVE]["size"] == manifest.get("size"),
            "source native pointer differs from runtime manifest")
    require(binaries[windows.RAPIER]["sha256"] == windows.RAPIER_SHA256,
            "source Rapier pointer differs from selected pin")
    tracked = windows.git(root, "ls-files", "-z", "--", *windows.INPUT_SCOPES).decode().split("\0")
    return {
        "source_tree": tree,
        "all_discovered_case_count": len(cases),
        "applicable_case_count": len(selected),
        "applicable_cases": [case.name for case in selected],
        "out_of_scope_graphical_cases": excluded,
        "plans": [[runner.case_dict(case) for case in shard] for shard in shards],
        "runtime_source_commit": manifest["source_commit"],
        "runtime_build_commit": manifest["build_commit"],
        "runtime_provenance": {"path": windows.PROVENANCE,
                               "sha256": hashlib.sha256(raw_manifest).hexdigest()},
        "native_source_inputs": inputs,
        "cybersand_runtime": binaries[windows.NATIVE],
        "rapier_runtime": binaries[windows.RAPIER],
        "godot_version": windows.GODOT_VERSION,
        "godot_archive_sha512": windows.GODOT_SHA512,
        "tested_input_paths": sorted(p for p in tracked if p and not p.startswith("godot/.godot/")),
    }


def verify_source_report(report: dict, directory: Path, expected: dict, index: int) -> None:
    """Bind one report to an independently derived source and test inventory."""
    for key in ("source_tree", "all_discovered_case_count", "applicable_case_count",
                "applicable_cases", "out_of_scope_graphical_cases", "runtime_source_commit",
                "runtime_build_commit", "runtime_provenance", "native_source_inputs",
                "cybersand_runtime", "rapier_runtime", "godot_version"):
        require(key in expected and report.get(key) == expected[key],
                f"source-derived {key} mismatch: {directory}")
    plan = expected["plans"][index]
    require(report.get("case_plan") == plan
            and report.get("assigned_cases") == [case["name"] for case in plan],
            f"source-derived shard plan mismatch: {directory}")
    raw = directory / "runtime-provenance.json"
    require(raw.is_file() and not raw.is_symlink()
            and hashlib.sha256(raw.read_bytes()).hexdigest() == expected["runtime_provenance"]["sha256"],
            f"missing or changed original runtime manifest: {directory}")
    godot = report.get("godot_identity")
    require(isinstance(godot, dict) and godot.get("version") == expected["godot_version"]
            and godot.get("archive_sha512") == expected["godot_archive_sha512"]
            and type(godot.get("archive_size")) is int and godot["archive_size"] > 0
            and all(isinstance(godot.get(k), str) and re.fullmatch(r"[0-9a-f]{64}", godot[k])
                    for k in ("console_sha256", "runtime_sha256")),
            f"missing or wrong pinned Godot identity: {directory}")
    tested = report.get("tested_inputs")
    require(isinstance(tested, dict) and sorted(tested) == expected["tested_input_paths"]
            and all(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest)
                    for digest in tested.values()),
            f"missing or changed source input inventory: {directory}")
    results = report.get("results")
    require(isinstance(results, list) and all(isinstance(row, dict) for row in results),
            f"invalid execution records: {directory}")
    tests = [row for row in results if row.get("role") == "case"]
    require(len(tests) == len(plan), f"source-derived case result count mismatch: {directory}")
    for result, case in zip(tests, plan):
        command = result.get("command")
        flags = case["flags"]
        require(result.get("name") == case["name"]
                and result.get("timeout_seconds") == case["timeout_seconds"]
                and result.get("requires_display") is False
                and isinstance(command, list) and len(command) >= len(flags) + 2
                and "--headless" in command and command[-len(flags):] == flags,
                f"source-derived command or watchdog mismatch: {directory}")
    require(all(type(row.get("returncode")) is int and row["returncode"] == 0
                and not row.get("skip_messages") and not row.get("launch_error")
                and not row.get("diagnostic_error") and not row.get("timeout_kind")
                for row in results), f"nonpassing execution detail: {directory}")


def verify(root: Path, source_sha: str, run_id: str, attempt: str,
           shard_count: int, *, expected: dict) -> dict:
    require(shard_count >= 1, "shard count must be positive")
    require(len(expected["plans"]) == shard_count, "source shard count mismatch")
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
        verify_source_report(report, path.parent, expected, index)
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
        for relative, expected_digest in log_hashes.items():
            log_rel = Path(relative)
            require(not log_rel.is_absolute() and ".." not in log_rel.parts
                    and "\\" not in relative and ":" not in relative,
                    f"unsafe raw test path: {relative}")
            log_path = path.parent / log_rel
            require(log_path.is_file() and not log_path.is_symlink()
                    and log_path.resolve().is_relative_to(path.parent.resolve())
                    and hashlib.sha256(log_path.read_bytes()).hexdigest() == expected_digest,
                    f"modified or missing original raw log: {log_path}")
        import run_godot_regressions as runner
        import verify_retained_play_readback
        for row, planned in zip(tests, expected["plans"][index]):
            case = runner.Case(planned["name"], tuple(planned["flags"]), planned["timeout_seconds"],
                               planned["estimated_seconds"], planned["requires_display"])
            if runner.case_readback_contract(case) is not None:
                verify_retained_play_readback.verify(case, row, path.parent, source_sha, "Windows",
                    output_dir=root.parent / "windows-play-readback" / case.name)
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
        "schema": "windows-godot-sharded-coverage-v2",
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
    expected = source_contract(Path(__file__).resolve().parents[2], args.source_sha, args.shard_count)
    result = verify(args.root, args.source_sha, args.run_id,
                    args.attempt, args.shard_count, expected=expected)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"WINDOWS_SHARD_COVERAGE PASS: {result['unique_case_count']} "
          f"cases across {args.shard_count} actual Windows shards, "
          f"{result['raw_logs_verified']} hash-verified logs against source-derived coverage", flush=True)


if __name__ == "__main__":
    main()
