#!/usr/bin/env python3
"""Strict offline reader of original complete-family receipts, logs and source."""
import argparse
from collections import Counter
from datetime import datetime
import io
import math
from pathlib import Path
import re
import shlex
import unittest

from common import (ENVIRONMENT, SOURCES, SUITES, assert_contract_parity, canonical, contract, digest,
                    expected_source, expected_tests, proof_identity, require, write)

FAILURE_MARKERS = ("[fail]", "ERROR: AddressSanitizer", "SUMMARY: AddressSanitizer",
                   "WARNING: ThreadSanitizer", "SUMMARY: ThreadSanitizer", "runtime error:")


def read_json(path, verifier):
    require(path.is_file() and not path.is_symlink(), "Missing/nonregular evidence: " + str(path))
    return verifier.load_json(path.read_text())


def seconds(value):
    require(type(value) in (int, float) and math.isfinite(value) and value > 0, "Invalid elapsed time")
    return value


def timestamp(value):
    parsed = datetime.fromisoformat(value)
    require(parsed.utcoffset() is not None, "Timestamp lacks timezone")
    return parsed.timestamp()


def printed_command(folder, receipt):
    raw = (folder / "command.log").read_text(encoding="utf-8", errors="replace")
    return raw + f"EXECUTION_TIMING {receipt['label']}: passed {receipt['elapsed_seconds']:.3f}s exit=0\n"


def validate_build_inventory(folder, arm, source, host, verifier):
    path = folder / "build-inventory.json"
    report = read_json(path, verifier)
    require(report.get("status") == "passed" and report.get("source_revision") == source["source_sha"]
            and report.get("makefile_sha256") == source["source_fingerprints"]["makefile"]
            and report.get("helper_sha256") == source["source_fingerprints"]["worldgen_inventory"], "Build inventory source/status differs")
    inventory = verifier.proof_inventory
    require(report.get("compiler_substitution") == inventory.COMPILER
            and report.get("make_version") == host["tools"]["make"]["version"].splitlines()[0], "Build inventory tool identity differs")
    require(set(report.get("families", {})) == {"worldgen-test", "worldgen-sanitize"}, "Incomplete build inventory")
    summary = {}
    for target, row in report["families"].items():
        for field, jobs in (("serial", 1), ("two_jobs", 2)):
            dry = row[field]
            command = ["make", "--no-print-directory", "--dry-run", "--always-make", f"-j{jobs}"]
            if arm == "candidate":
                command.append("--output-sync=target")
            command += ["CXX=" + inventory.COMPILER, target]
            require(set(dry) == {"command", "stdout", "stdout_sha256"} and dry.get("command") == command
                    and dry.get("stdout_sha256") == digest(dry.get("stdout", "").encode()),
                    "Original forced cold build inventory command/output hash differs")
        observed = inventory.compare(row["serial"]["stdout"], row["two_jobs"]["stdout"], target == "worldgen-sanitize")
        require(all(row.get(key) == value for key, value in observed.items()), "Precomputed build inventory differs from raw commands")
        summary[target] = {"objects": observed["object_count"], "binaries": observed["binary_count"]}
        if arm == "baseline":
            summary[target]["ordered_tests"] = len(observed["ordered_tests"])
        else:
            summary[target].update(showcases=len(observed["required_showcase_tests"]),
                                   ordered_main_tests=len(observed["ordered_main_tests"]), executions=observed["execution_count"])
    return {"status": "passed", "families": summary, "error": ""}, digest(path.read_bytes())


def validate_worldgen_tests(folder, expected):
    """Check real compiler argv and the complete 7+9 execution log, not a summary."""
    for target, test_contract in expected["tests"].items():
        raw = (folder / "commands" / target / "command.log").read_text()
        compilers = [shlex.split(line) for line in raw.splitlines() if line.startswith("g++-13 ")]
        require(Counter(map(tuple, compilers)) == Counter(map(tuple, expected["compiler_commands"][target].values())),
                "Actual complete 28-command compiler/flag/source inventory differs: " + target)
        main = list(re.finditer(r"^\./build/test_[^\r\n]+$", raw, re.M))
        require([item[0] for item in main] == test_contract["ordered_main_tests"], "Actual nine-test command coverage/order differs")
        prefix = "Running sanitized " if target == "worldgen-sanitize" else "Running "
        showcases = list(re.finditer(r"^" + prefix + r"(build/test_[^\r\n]+)$", raw, re.M))
        require(Counter(item[1] for item in showcases) == Counter(test_contract["showcases"]),
                "Actual seven-showcase coverage differs")
        require(all(item.start() < main[0].start() for item in showcases), "Main tests precede complete showcase output")


def validate_physics(root, folder, source_root, binaries, expected, verifier):
    physics = verifier.proof_physics
    directory = root / "source/build/physics-cli-validation/sanitized"
    report = read_json(directory / "results.json", verifier)
    planned = expected["physics_invocations"]
    names = [row["name"] for row in planned]
    executable = str(Path(source_root) / "build/physics_characterisation_sanitized")
    require(report.get("status") == "passed" and report.get("test_groups") == 3
            and report.get("failures") == 0 and report.get("errors") == 0
            and report.get("complete_invocation_inventory") is True, "Physics scientific execution did not complete successfully")
    require(report.get("executable") == executable
            and report.get("executable_sha256") == binaries["build/physics_characterisation_sanitized"]["sha256"],
            "Physics executable source/binary identity differs")
    require(report.get("building_ids") == list(physics.BUILDING_IDS) and report.get("invalid_ids") == list(physics.INVALID_IDS)
            and report.get("dispatch_workers") == physics.PHYSICS_DISPATCH_WORKERS
            and report.get("planned_invocations") == report.get("checked_invocations") == names,
            "Physics manifest/checked invocation inventory differs")
    rows = report.get("invocations", [])
    require(isinstance(rows, list) and [row.get("name") for row in rows] == names and len(names) == 154,
            "Missing, duplicate or reordered physics invocation")
    prepared = {}
    for item, row in zip(planned, rows):
        require(row.get("command") == physics.invocation_command(Path(executable), item["top"], item["bottom"]),
                "Original physics invocation arguments differ")
        require(row.get("timed_out") is False and row.get("launch_error") is None
                and row.get("watchdog_key") == "operation_seconds"
                and row.get("timeout_seconds") == physics.watchdog_seconds("operation_seconds"),
                "Physics invocation did not complete with original watchdog")
        require(type(row.get("seconds")) in (float, int) and math.isfinite(row["seconds"]) and row["seconds"] >= 0,
                "Invalid physics invocation time")
        raw = {}
        for field, suffix in (("stdout", ".jsonl"), ("stderr", ".stderr.log")):
            path = directory / (item["name"] + suffix)
            require(path.is_file() and not path.is_symlink(), "Missing original physics output")
            data = path.read_bytes()
            require(row.get(field + "_sha256") == digest(data), "Original physics output hash differs")
            raw[field] = data.decode()
        prepared[item["name"]] = {**row, **raw}
    # Reapply the original scientific assertions to the original retained outputs.
    # prepared_results prevents any native process execution in this offline check.
    case = physics.CharacterisationCliTests
    case.executable, case.output = Path(executable), directory
    case.prepared_results, case.checked_invocations, case.records = prepared, [], rows
    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream).run(unittest.defaultTestLoader.loadTestsFromTestCase(case))
    require(result.wasSuccessful() and result.testsRun == 3 and case.checked_invocations == names,
            "Original physics scientific assertions failed on retained outputs: " + stream.getvalue())
    command_log = (folder / "commands/physics-characterisation-sanitize/command.log").read_text()
    compilers = [shlex.split(line) for line in command_log.splitlines() if line.startswith("g++-13 ")]
    require(compilers == [expected["physics_compiler_command"]], "Original physics compiler/flag/source inventory differs")
    require(command_log.count("CLI material accounting: passed; 154 invocations\n") == 1,
            "Original physics completion summary is missing or duplicated")
    return {"invocation_count": len(rows), "scientific_assertions_reapplied": True,
            "results_sha256": digest((directory / "results.json").read_bytes())}


def verify_arm(directory, repository, arm, suite, run_id, run_attempt, proof, verifier):
    root = directory / arm
    source = expected_source(repository, arm, verifier)
    expected = contract(repository, arm, verifier)
    test_commands = expected["tests"]
    pre = read_json(root / "pre.json", verifier)
    post = read_json(root / "post.json", verifier)
    for snapshot in (pre, post):
        require(snapshot.get("schema") == "ci-opt003-worldgen-runtime-snapshot-v1" and snapshot.get("arm") == arm,
                "Snapshot identity differs")
        require(snapshot.get("source") == source and snapshot.get("proof") == proof, "Snapshot source/proof differs")
        require(type(snapshot.get("run_id")) is int and snapshot["run_id"] == run_id
                and type(snapshot.get("run_attempt")) is int and snapshot["run_attempt"] == run_attempt,
                "Snapshot run/attempt differs")
    require(pre.get("cold_build") is True and post.get("cold_build") is False, "Arm lacks cold/completed build evidence")
    source_root = pre.get("source_root", "")
    require(source_root == post.get("source_root") and Path(source_root).is_absolute()
            and source_root.endswith("/build/proof/worldgen/" + arm + "/source"), "Physical source root differs or is absent")
    require(pre["host"] == post["host"], "Worker/compiler changed during an arm")
    host = pre["host"]
    require(host.get("runner_environment") == "github-hosted" and host.get("runner_os") == "Linux"
            and host.get("image") == "ubuntu24" and host.get("environment") == ENVIRONMENT,
            "Unexpected hosted/compiler environment")
    require(re.fullmatch(r"[0-9a-f]{64}", host.get("runner_name_sha256", "")) and host.get("job") == "pair",
            "Worker/job identity is absent")
    require(host.get("cpu_model") and host.get("image_version") and type(host.get("logical_cpu_count")) is int,
            "Hardware/image identity absent")
    require(set(host.get("tools", {})) == {"gcc-13", "g++-13", "make", "ld"}, "Incomplete compiler/tool identities")
    for name, tool in host["tools"].items():
        require(re.fullmatch(r"[0-9a-f]{64}", tool.get("sha256", "")) and tool.get("path", "").startswith("/usr/bin/")
                and tool.get("version"), "Invalid compiler/tool identity")
        if name in ("gcc-13", "g++-13"):
            require(tool.get("full_version", "").startswith("13.") and tool.get("target"), "GCC 13 identity absent")
    require(read_json(root / "capture.json", verifier) == {"arm": arm, "outcome": "success", "errors": []},
            "Capture did not complete successfully")
    folder = root / "source/build/native-parallel" / suite
    receipt = read_json(folder / "receipt.json", verifier)
    require(receipt.get("schema") == verifier.SCHEMA and receipt.get("suite") == suite, "Original shard schema/suite differs")
    require(receipt.get("source_sha") == receipt.get("event_sha") == source["source_sha"]
            and receipt.get("source_tree") == source["source_tree"], "Original shard source/tree differs")
    require(type(receipt.get("run_id")) is int and receipt["run_id"] == run_id
            and type(receipt.get("run_attempt")) is int and receipt["run_attempt"] == run_attempt,
            "Original shard run/attempt differs")
    require(receipt.get("source_fingerprints") == source["source_fingerprints"]
            and receipt.get("source_delta_paths") == [] and receipt.get("errors") == [], "Original recorder/source errors remain")
    require(receipt.get("job_outcome") == "success" and receipt.get("runner_os") == "Linux", "Original job did not succeed")
    recorded = read_json(root / "record-command.json", verifier)
    require(recorded.get("returncode") == 0 and type(recorded.get("returncode")) is int
            and recorded.get("output_sha256") == digest(recorded.get("output", "").encode())
            and verifier.load_json(recorded.get("output", "")) == receipt, "Original record command differs or failed")
    require(recorded.get("command") == ["python3", "tools/ci/verify_native_shards.py", "record", "--suite", suite,
            "--outcome", "success", "--source-sha", source["source_sha"], "--run-id", str(run_id),
            "--run-attempt", str(run_attempt), "--output", "build/native-parallel"], "Original record command identity differs")
    codes, hashes = verifier.read_exit_codes(folder)
    require(receipt.get("exit_codes") == codes and receipt.get("exit_code_sha256") == hashes
            and all(code == 0 for code in codes.values()), "Original exit codes differ or failed")
    inventory = verifier.command_inventory(folder)
    require(receipt.get("command_outputs") == inventory, "Original command output bytes/hash differ")
    # This canonical validator checks ALL ordered argv, original policy/timeouts,
    # exact receipt inventory, complete/natural success, and raw command log hashes.
    verifier.validate_command_outputs(folder, suite, inventory)
    scientific = verifier.scientific_inventory(root / "source/build")
    if arm == "baseline":
        require(not (root / "source/build/worldgen-showcase-logs").exists(), "Unexpected diagnostic files in baseline evidence")
    require(receipt.get("scientific_outputs") == scientific, "Original scientific output bytes/hash differ")
    scientific_context = {"expected_source": source["source_sha"], "run_id": run_id, "run_attempt": run_attempt} if arm == "candidate" else {}
    verifier.validate_scientific_outputs(root / "source/build", suite, scientific, **scientific_context)
    raw_log = (folder / "run.log").read_bytes()
    require(receipt.get("log_present") is True and receipt.get("log_bytes") == len(raw_log)
            and receipt.get("log_sha256") == digest(raw_log), "Original family log bytes/hash differ")
    text = raw_log.decode()
    require(not any(marker in text for marker in FAILURE_MARKERS), "Original logs contain sanitizer/test failure")
    expected_context = {"commit": source["source_sha"], "tree": source["source_tree"], "tracked_delta_sha256": None,
                        "run_id": str(run_id), "run_attempt": str(run_attempt), "job": host["job"],
                        "runner_name_sha256": host["runner_name_sha256"]}
    expected_paths = ["family", *["commands/" + label for label, _, _ in verifier.COMMANDS[suite]]]
    records = {}
    for name in expected_paths:
        record = read_json(folder / name / "receipt.json", verifier)
        require(record.get("source") == expected_context and record.get("log") == "command.log", "Command source/context differs")
        seconds(record["elapsed_seconds"])
        rows = (folder / name / "performance.jsonl").read_text().splitlines()
        require(len(rows) == 1, "Missing or duplicated original performance row")
        performance = verifier.load_json(rows[0])
        require(performance.get("source") == expected_context and performance.get("result") == "passed"
                and performance.get("natural_completion") is True and performance.get("watchdog_reached") is False
                and performance.get("wall_seconds") == record["elapsed_seconds"]
                and performance.get("execution_policy") == record["execution_policy"], "Original performance receipt differs")
        recorded_host = performance.get("host", {})
        for key, value in {"platform": "Linux", "runner_class": "github-hosted", "hardware_cohort": "github-hosted",
                           "runner_environment": "github-hosted", "runner_image": host["image"],
                           "runner_image_version": host["image_version"], "cpu_model": host["cpu_model"],
                           "architecture": host["architecture"], "logical_cpu_count": host["logical_cpu_count"]}.items():
            require(recorded_host.get(key) == value, "Original command worker identity differs: " + key)
        records[name] = record
    family = records["family"]
    family_start = timestamp(family["started_utc"])
    family_end = family_start + family["elapsed_seconds"]
    require(timestamp(pre["captured_utc"]) <= family_start < family_end <= timestamp(post["captured_utc"]),
            "Family execution is outside source snapshots")
    previous_end = family_start
    concatenated = ""
    for label, _, _ in verifier.COMMANDS[suite]:
        path = "commands/" + label
        record = records[path]
        start = timestamp(record["started_utc"])
        end = start + record["elapsed_seconds"]
        require(previous_end <= start < end <= family_end, "Original command order/parent timing differs")
        previous_end = end
        concatenated += printed_command(folder / path, record)
    family_log = (folder / "family/command.log").read_text()
    require(family_log.endswith(concatenated), "Family log lacks the exact complete ordered command output")
    prefix = family_log[:-len(concatenated)].splitlines()
    inventory_summary, build_inventory_sha256 = validate_build_inventory(folder, arm, source, host, verifier)
    require(len(prefix) == 3 and verifier.load_json(prefix[0]) == inventory_summary
            and prefix[1] == str(host.get("nproc"))
            and re.fullmatch(r"MemTotal:\s+" + str(host.get("memory_kib")) + r" kB", prefix[2]),
            "Original inventory/host prefix differs")
    physics_validation = root / "source/build/physics-cli-validation/validation.log"
    require(physics_validation.read_text() == printed_command(folder / "commands/physics-characterisation-sanitize",
                records["commands/physics-characterisation-sanitize"]), "Original physics tee output is incomplete/different")
    expected_log = (f"source_sha={source['source_sha']} suite={suite} run={run_id} attempt={run_attempt}\n"
                    + "compiler=" + host["tools"]["g++-13"]["version"].splitlines()[0] + "\n"
                    + printed_command(folder / "family", family) + "Native family passed: " + suite + "\n")
    require(text == expected_log, "Original run.log is not the exact source-bound successful command output")
    validate_worldgen_tests(folder, expected)
    test_label = "physics-characterisation-sanitize"
    binaries = read_json(root / "binary-digests.json", verifier)
    expected_binaries = {"build/physics_characterisation_sanitized"}
    for target in test_commands.values():
        expected_binaries |= set(target["showcases"]) | {command.removeprefix("./") for command in target["ordered_main_tests"]}
    require(set(binaries) == expected_binaries, "Binary digest inventory is incomplete or unexpected")
    for value in binaries.values():
        require(type(value.get("bytes")) is int and value["bytes"] > 0
                and re.fullmatch(r"[0-9a-f]{64}", value.get("sha256", "")), "Invalid binary identity")
    physics = validate_physics(root, folder, source_root, binaries, expected, verifier)
    return {"source_sha": source["source_sha"], "source_tree": source["source_tree"], "host": host,
            "source_snapshot_start": timestamp(pre["captured_utc"]), "source_snapshot_end": timestamp(post["captured_utc"]),
            "family_started_utc": family["started_utc"], "family_elapsed_seconds": family["elapsed_seconds"],
            "commands": [{"label": label, "seconds": records["commands/" + label]["elapsed_seconds"]}
                         for label, _, _ in verifier.COMMANDS[suite]],
            "first_complete_functional_command_seconds": (timestamp(records["commands/" + test_label]["started_utc"])
                + records["commands/" + test_label]["elapsed_seconds"] - family_start),
            "test_commands": test_commands, "receipt_sha256": digest((folder / "receipt.json").read_bytes()),
            "run_log_sha256": digest(raw_log), "command_outputs": inventory,
            "scientific_outputs": scientific, "binary_digests": binaries,
            "physics": physics, "build_inventory_sha256": build_inventory_sha256}


def compare(directory, repository, suite, run_id, run_attempt, proof_sha):
    require(directory.is_dir() and not directory.is_symlink(), "Evidence directory is missing or a symlink")
    require(not any(path.is_symlink() for path in directory.rglob("*")), "Evidence contains symlinks")
    require(type(run_id) is int and run_id > 0 and type(run_attempt) is int and run_attempt > 0, "Invalid run/attempt")
    proof = proof_identity(repository, proof_sha)
    with canonical(repository, "baseline") as verifier:
        declaration = read_json(directory / "proof.json", verifier)
        require(declaration.get("schema") == "ci-opt003-worldgen-runtime-pair-v1" and declaration.get("proof") == proof,
                "Proof declaration identity differs")
        require(declaration.get("suite") == suite and declaration.get("run_id") == run_id
                and declaration.get("run_attempt") == run_attempt and declaration.get("order") == ["baseline", "candidate"]
                and declaration.get("repetitions") == 1 and declaration.get("job_cap_minutes") == 360,
                "Predeclared pair/run contract differs")
    expected_contracts = assert_contract_parity(repository)
    require(declaration.get("contracts") == expected_contracts, "Source/test/physics/compiler/watchdog contract differs from Git source")
    arms = {}
    for arm in SOURCES:
        with canonical(repository, arm) as verifier:
            arms[arm] = verify_arm(directory, repository, arm, suite, run_id, run_attempt, proof, verifier)
    baseline, candidate = arms["baseline"], arms["candidate"]
    require(baseline["host"] == candidate["host"] == declaration.get("host"), "Pair did not use the same worker/compiler/image")
    require(baseline["source_snapshot_end"] <= candidate["source_snapshot_start"], "Pair arms overlap or run out of order")
    before, after = baseline["family_elapsed_seconds"], candidate["family_elapsed_seconds"]
    return {"schema": "ci-opt003-worldgen-runtime-pair-comparison-v1", "status": "passed", "scope": "paired-family-only",
            "whole_native_qualified": False, "routine_ci_qualified": False, "run_id": run_id, "run_attempt": run_attempt,
            "proof": proof, "suite": suite, "arms": arms, "seconds_saved": before - after,
            "observed_percent_saved": 100 * (before - after) / before,
            "measurement_limit": "One baseline-then-candidate cold same-worker pair; no percentile or population speedup claim. "
                                 "Family elapsed times exclude hosted setup, queue, capture and upload; obtain job runner-minutes separately."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--suite", choices=SUITES, required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--run-attempt", type=int, required=True)
    parser.add_argument("--proof-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = compare(args.directory, args.repository, args.suite, args.run_id, args.run_attempt, args.proof_sha)
    except Exception as error:
        report = {"status": "failed", "scope": "paired-family-only", "whole_native_qualified": False,
                  "routine_ci_qualified": False, "errors": [type(error).__name__ + ": " + str(error)]}
    write(args.output, report)
    print(report["status"] + ": complete paired worldgen family evidence; not whole-Native qualification")
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
