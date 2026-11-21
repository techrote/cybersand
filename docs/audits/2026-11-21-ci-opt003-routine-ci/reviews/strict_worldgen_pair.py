#!/usr/bin/env python3
"""Independent offline readback of immutable CI-OPT-003 worldgen proof artifacts.

This never executes compilers or tests and never modifies downloaded evidence.
The proof's original comparison.json is deliberately not consumed.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime
import hashlib
import importlib.util
import json
import math
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess
import sys

BASE = "846fe0533b3170e7b01f690518da49fc40cc24d1"
CANDIDATE = "506dfc8c343c5d24fe26e89a9542cf985c52853e"
PROOF = "371b9aef07e75cf99e20417884402a22a9ad58da"
INVENTORY_PATH = "tools/ci/check_worldgen_build_inventory.py"
PROFILE_PATH = "tools/ci/ci_opt003_proof/profile_make.py"
WRAPPERS = ("profile_make.py", "profile_cxx.py", "profile_shell.py")


def need(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    need(path.is_file() and not path.is_symlink(), "Missing/nonregular evidence: " + str(path))
    def pairs(items):
        value = {}
        for key, item in items:
            need(key not in value, "Duplicate JSON key: " + key)
            value[key] = item
        return value
    def invalid(value):
        raise ValueError("Nonfinite JSON value: " + value)
    return json.loads(path.read_text(), object_pairs_hook=pairs, parse_constant=invalid)


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], timeout=60)


def number(value, label, *, positive=False):
    need(type(value) in (int, float) and math.isfinite(value), "Invalid " + label)
    need(value > 0 if positive else value >= 0, "Negative/zero " + label)
    return value


def passed(row, label):
    need(row.get("status") == "passed" and type(row.get("returncode")) is int
         and row["returncode"] == 0, label + " did not pass")


def interval_union(rows):
    intervals = sorted((r["start_time_ns"], r["end_time_ns"]) for r in rows)
    total = 0
    if not intervals:
        return 0.0
    start, end = intervals[0]
    for left, right in intervals[1:]:
        if left > end:
            total += end - start
            start, end = left, right
        else:
            end = max(end, right)
    return (total + end - start) / 1e9


def load_contract(repo):
    original = git(repo, "show", BASE + ":" + INVENTORY_PATH)
    need(original == git(repo, "show", CANDIDATE + ":" + INVENTORY_PATH),
         "Original build inventory changed in candidate")
    need(original == git(repo, "show", PROOF + ":" + INVENTORY_PATH),
         "Original build inventory changed in proof")
    path = repo / INVENTORY_PATH
    need(path.read_bytes() == original, "Local inventory reader differs from frozen source")
    sys.path.insert(0, str(repo / "tools/ci"))
    spec = importlib.util.spec_from_file_location("strict_worldgen_original_inventory", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inspect_arm(directory, arm, target, sha, repo, contract, run_id, attempt):
    folder = directory / arm
    profile = read_json(folder / "profile.json")
    passed(profile, arm + " profile")
    need(profile.get("schema") == "cybersand-ci-opt003-make-profile-v1", "Unknown profile schema")
    expected_identity = {
        "commit": sha,
        "tree": git(repo, "rev-parse", sha + "^{tree}").decode().strip(),
        "tracked_status": "",
        "makefile_sha256": digest(git(repo, "show", sha + ":Makefile")),
    }
    need(profile["source_before"] == profile["source_after"] == expected_identity,
         arm + " source/tree/Makefile or clean-source identity differs")
    expected_instrumentation = {
        name: digest(git(repo, "show", PROOF + ":tools/ci/ci_opt003_proof/" + name))
        for name in WRAPPERS
    }
    need(profile["instrumentation_sha256"] == expected_instrumentation,
         arm + " instrumentation differs from frozen proof")
    need(profile["sanitizer_environment"] == {
        "ASAN_OPTIONS": "detect_leaks=0:strict_string_checks=1", "UBSAN_OPTIONS": "halt_on_error=1"},
        arm + " sanitizer environment differs")
    need(re.match(r"^g\+\+-13 .+13\.", profile["compiler_version"]), "Unexpected hosted compiler version")
    pstart = number(profile["start_time_ns"], "profile start", positive=True)
    pend = number(profile["end_time_ns"], "profile end", positive=True)
    elapsed = number(profile["elapsed_seconds"], "profile elapsed", positive=True)
    need(pend >= pstart and abs((pend-pstart)/1e9-elapsed) < 2,
         "Profile wall/monotonic clocks disagree")

    watchdog = read_json(directory / (arm + "-watchdog") / "receipt.json")
    passed(watchdog, arm + " watchdog")
    need(watchdog.get("schema") == "execution-command-v1"
         and watchdog.get("complete") is True and watchdog.get("natural_completion") is True
         and watchdog.get("timed_out") is False, "Incomplete/timeout/interrupted watchdog")
    need(watchdog["label"] == arm + "-" + target and watchdog["timeout_seconds"] == 3600,
         "Watchdog label/allowance differs")
    policy_path = "godot/tests/support/ci_execution_policy.json"
    policy_bytes = git(repo, "show", PROOF + ":" + policy_path)
    policy = json.loads(policy_bytes)
    need(watchdog["execution_policy"] == {
        "schema_version": 1, "policy_id": policy["policy_id"], "scale": 1.0,
        "watchdogs": policy["watchdogs"], "advisories": policy["advisories"],
        "path": policy_path, "sha256": digest(policy_bytes)}, "Changed execution watchdog policy")
    source = watchdog["source"]
    need(source["commit"] == PROOF
         and source["tree"] == git(repo, "rev-parse", PROOF + "^{tree}").decode().strip()
         and source["tracked_delta_sha256"] is None,
         "Watchdog proof source differs or has local changes")
    need(source["run_id"] == str(run_id) and source["run_attempt"] == str(attempt)
         and source["job"] == "pair", "Stale run/attempt/job receipt")
    need(re.fullmatch(r"[0-9a-f]{64}", source.get("runner_name_sha256", "")),
         "Missing exact worker binding")
    log = directory / (arm + "-watchdog") / "command.log"
    need(log.is_file() and not log.is_symlink() and digest(log.read_bytes()) == watchdog["log_sha256"],
         "Original watchdog command log is missing/corrupt")
    stdout = folder / "stdout.log"
    need(stdout.is_file() and not stdout.is_symlink(), "Missing original Make stdout")
    summary = {key: profile[key] for key in ("status", "elapsed_seconds", "returncode", "compiler_command_count", "shell_command_count")}
    need(log.read_bytes() == stdout.read_bytes() + (json.dumps(summary) + "\n").encode(),
         "Make stdout/profile summary differs from immutable watchdog log")
    lines_path = folder / "lines.jsonl"
    need(lines_path.is_file() and not lines_path.is_symlink(), "Missing timestamped original output")
    lines = [json.loads(line) for line in lines_path.read_text().splitlines()]
    need([row["line"] for row in lines] == stdout.read_text().splitlines(), "Timestamped output differs from original Make log")
    times = [row["time_ns"] for row in lines]
    need(times == sorted(times) and all(pstart <= t <= pend for t in times), "Output timing differs from profile interval")
    command = watchdog["command"]
    need(len(command) == 12 and command[:3] == ["python3", PROFILE_PATH, "--source"]
         and command[4] == "--output" and command[6:] == ["--target", target, "--jobs", "2", "--cxx", "g++-13"],
         "Changed profiled command")
    source_directory, output_directory = command[3], PurePosixPath(command[5])
    need(PurePosixPath(source_directory).is_absolute() and PurePosixPath(source_directory).name == arm,
         "Unexpected source worktree path")
    need(output_directory.is_absolute() and output_directory.parts[-4:] == ("build", "proof", target, arm),
         "Unexpected output namespace")
    workspace = output_directory.parents[3]
    compiler_wrapper = str(workspace / "tools/ci/ci_opt003_proof/profile_cxx.py")
    shell_wrapper = str(workspace / "tools/ci/ci_opt003_proof/profile_shell.py")
    need(profile["command"] == ["make", "--no-print-directory", "-j2", "CXX=" + compiler_wrapper,
                                "SHELL=" + shell_wrapper, target], "Changed Make/profile command")
    need(elapsed <= number(watchdog["elapsed_seconds"], "watchdog elapsed", positive=True) + 2,
         "Profile exceeds its outer execution duration")

    index = read_json(folder / "command-index.json")
    need(isinstance(index, list) and index, "Missing command index")
    records_directory = folder / "commands"
    need(records_directory.is_dir() and not records_directory.is_symlink(), "Missing raw command directory")
    entries = sorted(records_directory.iterdir())
    need(entries and all(p.is_file() and not p.is_symlink() and re.fullmatch(r"[0-9a-f]{32}\.json", p.name)
                         for p in entries), "Incomplete/unexpected raw command receipt")
    raw = [read_json(p) for p in entries]
    need(raw == index, "Raw command files differ from index or a receipt is missing")
    need(len({r.get("id") for r in raw}) == len(raw), "Duplicate command IDs")
    for path, row in zip(entries, raw):
        need(row["id"] == path.stem and row.get("schema") == "cybersand-ci-opt003-command-v1",
             "Incorrect raw receipt identity/schema")
        passed(row, "Raw command " + path.stem)
        need(row.get("signals") == [] and row["cwd"] == source_directory, "Signaled or wrong-source command")
        start, end = number(row["start_time_ns"], "command start", positive=True), number(row["end_time_ns"], "command end", positive=True)
        wall = number(row["elapsed_seconds"], "command elapsed", positive=True)
        need(pstart <= start <= end <= pend and abs((end-start)/1e9-wall) < 2,
             "Command timing outside original profile")
        for key in ("child_user_seconds", "child_system_seconds", "max_child_rss_kib"):
            number(row[key], key)
        need(row["kind"] in ("compiler", "shell"), "Unexpected command kind")

    sanitized = target == "worldgen-sanitize"
    expected_compilers = list(contract.expected_commands(sanitized).values())
    expected_tests = [contract.showcase_loop(sanitized),
                      *[[f"./build/test_{name}" + ("_sanitized" if sanitized else "")] for name in contract.TESTS]]
    compilers = [r for r in raw if r["kind"] == "compiler"]
    shells = [r for r in raw if r["kind"] == "shell"]
    need(all(r["argv"][0] == "g++-13" for r in compilers), "Unexpected actual compiler")
    actual_compilers = [[contract.COMPILER, *r["argv"][1:]] for r in compilers]
    need(Counter(map(tuple, actual_compilers)) == Counter(map(tuple, expected_compilers)),
         "Actual compiler arguments/outputs differ from original inventory")
    test_rows, test_commands, compiler_shells = [], [], []
    for row in sorted(shells, key=lambda r: r["start_time_ns"]):
        need(len(row["argv"]) == 3 and row["argv"][:2] == ["/bin/sh", "-c"], "Changed shell contract")
        tokens = shlex.split(row["argv"][2])
        need(tokens, "Empty shell command")
        if tokens[0] == compiler_wrapper:
            compiler_shells.append([contract.COMPILER, *tokens[1:]])
        elif tokens[:2] == ["mkdir", "-p"]:
            need(len(tokens) == 3 and tokens[2] in {
                "build", "build/worldgen-objects/normal", "build/worldgen-objects/normal-threaded",
                "build/worldgen-objects/sanitized", "build/worldgen-objects/sanitized-threaded"}, "Unregistered directory command")
        elif tokens[0] == "set" or tokens[0].startswith("./build/test_"):
            test_commands.append(tokens); test_rows.append(row)
        else:
            raise ValueError("Unregistered shell command: " + repr(tokens))
    need(test_commands == expected_tests, "Actual test receipts missing, reordered or changed")
    need(Counter(map(tuple, compiler_shells)) == Counter(map(tuple, expected_compilers)),
         "Compiler shell receipts missing or inconsistent")
    verified = profile["verified_inventory"]
    need(verified == {"compiler_commands": actual_compilers, "test_commands": test_commands,
                      "objects": 12, "binaries": 16, "test_executions": 16},
         "Profile summary differs from actual raw command receipts")
    need(profile["compiler_command_count"] == len(compilers) == 28
         and profile["shell_command_count"] == len(shells), "Summary command counts differ")
    original_inventory = read_json(directory / (arm + "-inventory.json"))
    need(original_inventory["status"] == "passed" and original_inventory["source_revision"] == sha
         and original_inventory["makefile_sha256"] == expected_identity["makefile_sha256"], "Wrong/stale cold build inventory")
    registered = original_inventory["families"][target]
    need(Counter(map(tuple, registered["compile_link_commands"])) == Counter(map(tuple, expected_compilers)),
         "Cold inventory no longer matches original source")
    need(registered["ordered_tests"] == [f"./build/test_{name}" + ("_sanitized" if sanitized else "")
                                        for name in (*contract.SHOWCASES, *contract.TESTS)],
         "Cold executable inventory differs")
    events = sorted((t, delta) for row in compilers for t, delta in ((row["start_time_ns"], 1), (row["end_time_ns"], -1)))
    active = peak = 0
    for _, change in events:
        active += change; peak = max(peak, active)
        need(active >= 0, "Invalid compiler lifetime")
    need(active == 0 and peak <= 2, "Compiler concurrency exceeds original two-job cap")
    heavy = [r for r in compilers if "-c" in r["argv"] and "native/src/world_generation.cpp" in r["argv"]]
    need(len(heavy) == 2, "Missing distinct heavy compiler contracts")
    return {
        "source": expected_identity, "profile_elapsed_seconds": elapsed,
        "watchdog_elapsed_seconds": watchdog["elapsed_seconds"],
        "compiler_union_seconds": interval_union(compilers),
        "test_union_seconds": interval_union(test_rows),
        "compiler_user_seconds": sum(r["child_user_seconds"] for r in compilers),
        "compiler_system_seconds": sum(r["child_system_seconds"] for r in compilers),
        "max_compiler_child_rss_kib": max(r["max_child_rss_kib"] for r in compilers),
        "compiler_peak_concurrency": peak, "compiler_records": len(compilers),
        "ordered_test_shell_records": len(test_rows), "executed_binaries": 16,
        "heavy_overlap_seconds": max(0, min(r["end_time_ns"] for r in heavy) - max(r["start_time_ns"] for r in heavy))/1e9,
        "compiler_rows": [{"argv": r["argv"], "elapsed_seconds": r["elapsed_seconds"],
                           "child_user_seconds": r["child_user_seconds"], "child_system_seconds": r["child_system_seconds"],
                           "max_child_rss_kib": r["max_child_rss_kib"]} for r in sorted(compilers, key=lambda r:r["start_time_ns"])],
        "test_rows": [{"command": r["argv"][2], "elapsed_seconds": r["elapsed_seconds"]} for r in test_rows],
        "runner_name_sha256": source["runner_name_sha256"], "compiler_version": profile["compiler_version"],
        "start_time_ns": pstart, "end_time_ns": pend,
    }


def verify(directory, repo, target, run_id, attempt):
    need(target in ("worldgen-test", "worldgen-sanitize") and run_id > 0 and attempt > 0, "Invalid proof context")
    for path in directory.rglob("*"):
        need(not path.is_symlink(), "Symlink evidence is refused")
    host = directory / "host.txt"
    need(host.is_file() and host.read_text().splitlines()[0] == f"proof_source={PROOF} run={run_id} attempt={attempt}",
         "Wrong proof/run/attempt host context")
    need(not git(repo, "diff", BASE, CANDIDATE, "--", "native", "tools/physics", "godot", "third_party",
                 ".github/workflows/native.yml", "tools/ci/run_native_family.sh", "tools/ci/native_execution_policy.py",
                 "tools/ci/verify_native_shards.py", INVENTORY_PATH), "Production/scientific/Native contract inputs differ")
    contract = load_contract(repo)
    base = inspect_arm(directory, "baseline", target, BASE, repo, contract, run_id, attempt)
    candidate = inspect_arm(directory, "candidate", target, CANDIDATE, repo, contract, run_id, attempt)
    need(base["runner_name_sha256"] == candidate["runner_name_sha256"]
         and base["compiler_version"] == candidate["compiler_version"], "Pair used different worker/compiler")
    need(base["end_time_ns"] < candidate["start_time_ns"], "Pair did not execute sequentially")
    files = {p.relative_to(directory).as_posix(): digest(p.read_bytes())
             for p in sorted(directory.rglob("*")) if p.is_file()}
    return {
        "schema": "ci-opt003-independent-worldgen-pair-v1", "status": "passed", "proof_sha": PROOF,
        "run_id": run_id, "run_attempt": attempt, "target": target,
        "baseline": base, "candidate": candidate,
        "saved_seconds": base["profile_elapsed_seconds"]-candidate["profile_elapsed_seconds"],
        "observed_fraction_saved": 1-candidate["profile_elapsed_seconds"]/base["profile_elapsed_seconds"],
        "retained_file_sha256": files,
        "limits": ["One sequential same-worker cold pair; no percentile or population estimate.",
                   "Compiler and test unions can overlap; do not sum them as disjoint phases.",
                   "RSS is per-child maximum, not simultaneous aggregate memory.",
                   "Canonical source-matched required CI and merge admission remain separate."],
    }


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--directory", type=Path, required=True)
    p.add_argument("--source-repository", type=Path, required=True)
    p.add_argument("--target", choices=("worldgen-test", "worldgen-sanitize"), required=True)
    p.add_argument("--run-id", type=int, required=True)
    p.add_argument("--run-attempt", type=int, default=1)
    p.add_argument("--output", type=Path, required=True)
    a=p.parse_args()
    need(not a.output.resolve().is_relative_to(a.directory.resolve()), "Write review outside immutable artifact")
    try:
        result=verify(a.directory.resolve(), a.source_repository.resolve(), a.target, a.run_id, a.run_attempt)
    except (ValueError, KeyError, OSError, TypeError, subprocess.SubprocessError) as error:
        result={"schema":"ci-opt003-independent-worldgen-pair-v1", "status":"failed", "error":str(error)}
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2, allow_nan=False)+"\n")
    print(json.dumps({k:v for k,v in result.items() if k not in {"baseline","candidate","retained_file_sha256"}}, indent=2))
    return result["status"] != "passed"


if __name__ == "__main__":
    raise SystemExit(main())
