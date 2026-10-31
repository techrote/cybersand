#!/usr/bin/env python3
"""Require exact source, runtime, logs and unique Linux coverage on every run."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess

import execution_policy
import run_godot_regressions as runner
import verify_retained_play_readback


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_file(directory: Path, relative: object) -> Path:
    require(isinstance(relative, str) and bool(relative), "Missing original artifact path")
    path = directory / relative
    require(not Path(relative).is_absolute() and ".." not in Path(relative).parts,
            "Artifact path escapes its original shard")
    require(path.is_file() and not path.is_symlink(), "Missing original artifact: " + str(path))
    return path


def verify(root: Path, *, cases: list, source: str, tree: str, runtime: dict,
           run_id: str, attempt: str, shard_count: int, godot_version: str,
           readback_output: Path | None = None) -> dict:
    paths = sorted(root.rglob("timings.json"))
    require(len(paths) == shard_count, "Original Linux shard count mismatch")
    plans, _ = runner.build_shard_plan(cases, shard_count)
    seen = set()
    observed = []
    originals = []
    for path in paths:
        report = json.loads(path.read_text(encoding="utf-8"))
        identity = report.get("identity", {})
        index = identity.get("shard_index")
        require(type(index) is int and 0 <= index < shard_count and index not in seen,
                "Duplicate or invalid Linux shard index")
        seen.add(index)
        for key, expected in {"source_sha": source, "source_tree": tree, "shard_count": shard_count,
                "run_id": run_id, "run_attempt": attempt, "godot_version": godot_version,
                "execution_policy": execution_policy.identity(), **runtime}.items():
            require(identity.get(key) == expected, f"Linux {key} identity mismatch")
        require(report.get("status") == "passed" and report.get("completed") is True,
                "Linux shard did not complete successfully")
        assigned = plans[index]
        require(report.get("assigned_cases") == [case.name for case in assigned],
                "Linux source-derived assignment changed")
        records = report.get("results")
        expected_cases = [runner.Case("import", ("--editor", "--quit"), execution_policy.watchdog_seconds("godot_import_seconds"), 1), *assigned]
        require(isinstance(records, list) and len(records) == len(expected_cases),
                "Linux import or case results missing")
        for offset, (row, case) in enumerate(zip(records, expected_cases)):
            require(row.get("name") == case.name and row.get("role") == ("preflight" if offset == 0 else "case")
                    and row.get("timeout_seconds") == case.timeout
                    and row.get("requires_display") == case.requires_display,
                    "Linux source-derived case or watchdog mismatch")
            require(row.get("execution_policy") == execution_policy.identity()
                    and row.get("status") == "passed" and type(row.get("returncode")) is int
                    and row["returncode"] == 0 and row.get("natural_completion") is True
                    and not any(row.get(key) for key in ("diagnostic_error", "launch_error", "skip_messages", "timeout_kind")),
                    "Linux case did not complete naturally with all checks passing")
            log = local_file(path.parent, row.get("log"))
            require(digest(log) == row.get("log_sha256"), "Original Linux log changed")
            text = log.read_text(encoding="utf-8", errors="replace")
            require("ERROR:" not in text and not re.search(r"\bskipped\b|^\s*SKIP\b", text, re.I | re.M),
                    "Original Linux log contains an error or skipped check")
            require(isinstance(row.get("command"), list)
                    and row["command"][1:] == runner.case_command("GODOT", case, "linux")[1:],
                    "Linux original command differs from source")
            if offset:
                if runner.case_readback_contract(case) is not None:
                    verify_retained_play_readback.verify(case, row, path.parent, source, "Linux",
                        output_dir=(readback_output / case.name) if readback_output is not None else None)
                observed.append(case.name)
        originals.append({"path": str(path.relative_to(root)), "sha256": digest(path), "shard_index": index})
    require(Counter(observed) == Counter(case.name for case in cases), "Linux complete suite union differs from source")
    return {"schema": "linux-godot-coverage-v1", "status": "passed", "source_sha": source,
        "source_tree": tree, "run_id": run_id, "run_attempt": attempt, "shard_count": shard_count,
        "case_count": len(observed), "cases": observed, "originals": originals,
        "execution_policy": execution_policy.identity()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--attempt", required=True)
    parser.add_argument("--shard-count", type=int, required=True)
    parser.add_argument("--godot-version", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = {"status": "failed"}
    try:
        def git(*flags):
            return subprocess.check_output(["git", *flags], cwd=execution_policy.ROOT, text=True,
                timeout=execution_policy.watchdog_seconds("operation_seconds")).strip()
        require(git("rev-parse", "HEAD") == args.source_sha, "Coverage checkout differs from source")
        require(not git("diff", "--name-only", "HEAD"), "Coverage source has tracked modifications")
        require((args.runtime / "source-sha.txt").read_text().strip() == args.source_sha, "Built runtime source differs")
        runtime = {}
        for key, relative, filename in (
            ("cybersand_runtime", "godot/addons/cybersand_native/bin/", "libcybersand_native.linux.x86_64.so"),
            ("rapier_runtime", "godot/addons/godot-rapier2d/bin/", "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")):
            runtime[key] = {"path": relative + filename, "sha256": digest(args.runtime / filename)}
        result = verify(args.root, cases=runner.discover_cases(), source=args.source_sha, tree=git("rev-parse", "HEAD^{tree}"),
            runtime=runtime, run_id=args.run_id, attempt=args.attempt, shard_count=args.shard_count, godot_version=args.godot_version,
            readback_output=args.output.parent / "linux-play-readback")
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        result["error"] = f"{type(error).__name__}: {error}"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
