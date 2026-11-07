#!/usr/bin/env python3
"""Source-matched, temporary Windows GDExtension qualification (NOT retained release acceptance).

This separate path never changes the pinned retained-runtime validator. The cross-built
candidate DLL travels only as a one-day same-run CI artifact and is never committed
to the source repository. The ordinary Windows source/runtime acceptance gate
remains authoritative for publication and release.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time
import zipfile

import run_godot_regressions as runner
import run_windows_godot_regressions as windows


SCHEMA = "hs-pkt-ephemeral-windows-candidate-v1"
BINARY = "cybersand_native.windows.x86_64.dll"
GODOT_CPP_COMMIT = "101ae38034304346a46ea9ea84ae156d3e860496"
LLVM_MINGW_ARCHIVE_SHA256 = "cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_inputs(root: Path) -> dict[str, str]:
    # Standard manifest source scope, independently recalculated on both hosts.
    return {
        name: sha((root / name).read_bytes().replace(b"\r\n", b"\n"))
        for name in sorted(windows.native_input_paths(root))
    }


def source_revision(root: Path) -> tuple[str, str]:
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=root, text=True, timeout=30
    ).strip()
    tree = subprocess.check_output(
        ["git", "rev-parse", "HEAD^{tree}"], cwd=root, text=True, timeout=30
    ).strip()
    return commit, tree


def stage_candidate(root: Path, candidate: Path, output: Path) -> None:
    if not candidate.is_file() or candidate.read_bytes()[:2] != b"MZ":
        raise RuntimeError("Built Windows candidate is absent or not a PE runtime")
    output.mkdir(parents=True, exist_ok=True)
    commit, tree = source_revision(root)
    if os.getenv("GITHUB_HEAD_SHA") != commit:
        raise RuntimeError("Staged DLL source is not the exact PR branch head")
    payload = candidate.read_bytes()
    if len(payload) < 1_000_000:
        raise RuntimeError("Unexpectedly short Windows runtime")
    manifest = {
        "schema": SCHEMA,
        "qualification_only": True,
        "source_head_sha": commit,
        "source_tree_sha": tree,
        "godot_cpp_commit": GODOT_CPP_COMMIT,
        "llvm_mingw_archive_sha256": LLVM_MINGW_ARCHIVE_SHA256,
        "native_source_inputs": source_inputs(root),
        "candidate_file": BINARY,
        "candidate_sha256": sha(payload),
        "candidate_size": len(payload),
        "producing_run_id": os.environ.get("GITHUB_RUN_ID", ""),
        "producing_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", ""),
    }
    shutil.copyfile(candidate, output / BINARY)
    (output / "candidate-identity.json").write_text(
        json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8"
    )
    print("HS_WINDOWS_CANDIDATE_STAGE " + json.dumps(manifest, sort_keys=True), flush=True)


def verify_candidate(root: Path, directory: Path, expected: str) -> dict:
    if sys.platform != "win32":
        raise RuntimeError("Candidate regression must run on actual Windows")
    commit, tree = source_revision(root)
    if commit != expected:
        raise RuntimeError("Candidate Windows checkout does not match exact PR head")
    manifest_path = directory / "candidate-identity.json"
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    if (manifest.get("schema") != SCHEMA or manifest.get("qualification_only") is not True
            or manifest.get("source_head_sha") != commit
            or manifest.get("source_tree_sha") != tree
            or manifest.get("candidate_file") != BINARY
            or manifest.get("godot_cpp_commit") != GODOT_CPP_COMMIT
            or manifest.get("llvm_mingw_archive_sha256") != LLVM_MINGW_ARCHIVE_SHA256
            or manifest.get("producing_run_id") != os.environ.get("GITHUB_RUN_ID")
            or manifest.get("producing_run_attempt") != os.environ.get("GITHUB_RUN_ATTEMPT")):
        raise RuntimeError("Candidate artifact source, toolchain or same-run custody mismatch")
    actual_sources = source_inputs(root)
    if not actual_sources or actual_sources != manifest.get("native_source_inputs"):
        raise RuntimeError("Built candidate native source inventory differs from Windows checkout")
    input_binary = directory / BINARY
    payload = input_binary.read_bytes()
    if (payload[:2] != b"MZ" or
            len(payload) != manifest.get("candidate_size") or
            sha(payload) != manifest.get("candidate_sha256")):
        raise RuntimeError("Candidate Windows DLL differs from the source-matched build artifact")

    # The selected Rapier runtime remains committed, materialized and pinned.
    pointer = subprocess.check_output(
        ["git", "show", "HEAD:" + windows.RAPIER], cwd=root, timeout=30
    )
    match = re.fullmatch(
        rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n",
        pointer,
    )
    if not match or match[1].decode() != windows.RAPIER_SHA256:
        raise RuntimeError("Windows Rapier LFS pointer is not the selected pin")
    rapier = (root / windows.RAPIER).read_bytes()
    if not rapier.startswith(b"MZ") or sha(rapier) != windows.RAPIER_SHA256 or len(rapier) != int(match[2]):
        raise RuntimeError("Actual Windows Rapier DLL differs from selected pin")

    # Install only into the ephemeral CI checkout. No git commit, LFS pointer
    # rewrite, provenance change, protected-source bypass or runtime publication.
    runtime = root / windows.NATIVE
    runtime.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(input_binary, runtime)
    if sha(runtime.read_bytes()) != manifest["candidate_sha256"]:
        raise RuntimeError("Installed candidate DLL differs from verified artifact")
    subprocess.run(
        ["git", "diff", "--exit-code", "HEAD", "--",
         *windows.INPUT_SCOPES, ":!godot/.godot",
         ":!" + windows.NATIVE],
        cwd=root, check=True, timeout=30,
    )
    return {
        "candidate_mode": SCHEMA,
        "source_commit": commit,
        "source_tree": tree,
        "candidate_identity": {"sha256": sha(manifest_bytes), "file": "candidate-identity.json"},
        "native_source_inputs": actual_sources,
        "cybersand_runtime": {"path": windows.NATIVE, "sha256": manifest["candidate_sha256"],
                              "size": manifest["candidate_size"]},
        "rapier_runtime": {"path": windows.RAPIER, "sha256": windows.RAPIER_SHA256,
                           "size": len(rapier)},
        "retained_runtime_qualification": False,
        "published_runtime": False,
    }


def run_candidate(args: argparse.Namespace) -> int:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {
        "status": "running", "completed": False,
        "errors": [], "results": [], "log_sha256": {},
        "executed_case_count": 0,
        "qualification": "EPHEMERAL candidate only; NOT retained Windows release acceptance",
        "run_id": os.getenv("GITHUB_RUN_ID"), "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
        "platform": platform.platform(), "python_version": platform.python_version(),
    }
    runner.write_json(output / "windows-execution.json", report)
    started = time.monotonic()
    try:
        with windows.metadata_budget():
            report.update(verify_candidate(runner.ROOT, args.artifact.resolve(), args.expected_source_sha))
            report["tested_inputs"] = windows.tested_inputs(runner.ROOT)
            godot, report["godot_identity"] = windows.prepare_godot(args.godot_archive.resolve())
            report["godot_version"] = report["godot_identity"]["version"]
        os.environ["CYBERSAND_SOURCE_REVISION"] = report["source_commit"]
        budget = runner.scheduling.ExecutionBudget(args.execution_seconds, started=started)
        windows.execute_cases(str(godot), output, report, runner.discover_cases(),
                              shard_count=args.shard_count, shard_index=args.shard_index,
                              budget=budget)
        with windows.metadata_budget():
            after = windows.tested_inputs(runner.ROOT)
            report["source_drift"] = sorted(
                key for key in report["tested_inputs"].keys() | after.keys()
                if report["tested_inputs"].get(key) != after.get(key)
            )
            if report["source_drift"]:
                raise RuntimeError("Source or selected candidate runtime mutated during tests")
        report["status"] = (
            "passed" if report["completed"] and
            all(row["status"] == "passed" for row in report["results"]) else "failed"
        )
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as exc:
        report["status"] = "failed"
        report["errors"].append(f"{type(exc).__name__}: {exc}")
        observed = {row["name"] for row in report["results"] if row.get("role") == "case"}
        report["incomplete_cases"] = [
            name for name in report.get("assigned_cases", []) if name not in observed
        ]
    report["elapsed_seconds"] = round(time.monotonic() - started, 3)
    runner.write_json(output / "windows-execution.json", report)
    print("HS_WINDOWS_CANDIDATE " + json.dumps({
        "status": report["status"], "completed": report["completed"],
        "executed_case_count": report["executed_case_count"],
        "assigned_case_count": len(report.get("assigned_cases", [])),
        "errors": report["errors"], "source": report.get("source_commit"),
        "native": report.get("cybersand_runtime"),
    }, sort_keys=True), flush=True)
    return int(report["status"] != "passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    stage = modes.add_parser("stage")
    stage.add_argument("--binary", type=Path, required=True)
    stage.add_argument("--output", type=Path, required=True)
    execute = modes.add_parser("run")
    execute.add_argument("--artifact", type=Path, required=True)
    execute.add_argument("--godot-archive", type=Path, required=True)
    execute.add_argument("--expected-source-sha", required=True)
    execute.add_argument("--shard-count", type=int, required=True)
    execute.add_argument("--shard-index", type=int, required=True)
    execute.add_argument("--execution-seconds", type=float, default=7000.0)
    execute.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.mode == "stage":
        stage_candidate(runner.ROOT, args.binary.resolve(), args.output.resolve())
        return 0
    if args.shard_count < 1 or not 0 <= args.shard_index < args.shard_count:
        parser.error("Invalid shard index/count")
    return run_candidate(args)


if __name__ == "__main__":
    raise SystemExit(main())
