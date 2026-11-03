#!/usr/bin/env python3
"""Retain and independently verify the six required Native runner families."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

from execution_policy import identity as execution_policy_identity, watchdog_seconds
from native_execution_policy import COMMANDS, command_timeout_seconds, family_timeout_seconds

ROOT = Path(__file__).resolve().parents[2]
SUITES = frozenset({"tsan", "native-normal", "asan-ubsan", "worldgen", "soliding-normal", "soliding-asan"})
CASE_SUITES = frozenset({"tsan", "native-normal", "asan-ubsan"})
SCHEMA = "cybersand-native-shard-v2"
INPUTS = {
    "workflow": ".github/workflows/native.yml",
    "makefile": "Makefile",
    "test_registry": "native/tests/test_world.cpp",
    "verifier": "tools/ci/verify_native_shards.py",
    "verifier_tests": "tools/ci/test_native_shards.py",
    "native_family": "tools/ci/run_native_family.sh",
    "native_execution_policy": "tools/ci/native_execution_policy.py",
    "command_runner": "tools/ci/run_timed_command.py",
    "execution_policy": "tools/ci/execution_policy.py",
    "watchdog_policy": "godot/tests/support/ci_execution_policy.json",
    "physics_cli": "tools/physics/test_characterisation_cli.py",
    "worldgen_inventory": "tools/ci/check_worldgen_build_inventory.py",
    "native_watchdog_tests": "tools/ci/test_native_watchdogs.py",
}
EXIT_FILES = {"family": "family-exit-code.txt", "log_capture": "log-capture-exit-code.txt"}
STAGE_OUTPUTS = frozenset({"stage3b-validation-synthetic-smoke.json", "stage3b-validation-plan-smoke.json"})



def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_json(text):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("Duplicate JSON key: " + key)
            result[key] = value
        return result

    def invalid(value):
        raise ValueError("Non-finite JSON value: " + value)

    return json.loads(text, object_pairs_hook=pairs, parse_constant=invalid)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git(root, *args, timeout_seconds=None):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True,
                                   timeout=watchdog_seconds("operation_seconds") if timeout_seconds is None else timeout_seconds).strip()


def source_identity(root):
    # Four Git queries belong to one readback operation. Do not accidentally
    # promise four full operation allowances inside the job's capture headroom.
    deadline = time.monotonic() + watchdog_seconds("operation_seconds")

    def read(*arguments):
        remaining = deadline - time.monotonic()
        require(remaining > 0, "Native source identity readback exceeded its operation watchdog")
        return git(root, *arguments, timeout_seconds=remaining)

    source = read("rev-parse", "HEAD")
    tree = read("rev-parse", "HEAD^{tree}")
    require(re.fullmatch(r"[0-9a-f]{40}", source) and re.fullmatch(r"[0-9a-f]{40}", tree),
            "Incomplete source or tree identity")
    fingerprints = {key: digest((root / path).read_bytes()) for key, path in INPUTS.items()}
    registry = (root / INPUTS["test_registry"]).read_text(encoding="utf-8")
    require("int main(" in registry, "Native test registry is missing")
    cases = re.findall(r'\{"([^"]+)",\s*test_[A-Za-z0-9_]+\}', registry[registry.index("int main("):])
    require(cases and len(cases) == len(set(cases)), "Native test registry is empty or ambiguous")
    # Fence the complete checkout, including transitive local scientific helpers.
    # Generated build outputs and Python caches keep the repository's ignore rules.
    delta = sorted(set(read("diff", "--name-only", "HEAD").splitlines())
                   | set(read("ls-files", "--others", "--exclude-standard").splitlines()))
    require(time.monotonic() <= deadline, "Native source identity readback exceeded its operation watchdog")
    require(not delta, "Native execution inputs changed: " + ", ".join(delta))
    return {"source_sha": source, "source_tree": tree, "source_fingerprints": fingerprints,
            "source_delta_paths": delta, "expected_cases": cases}


def context_errors(identity, expected_source, run_id, run_attempt):
    errors = []
    if not re.fullmatch(r"[0-9a-f]{40}", expected_source):
        errors.append("Expected source must be a full Git SHA")
    if type(run_id) is not int or run_id <= 0 or type(run_attempt) is not int or run_attempt <= 0:
        errors.append("Run identity/attempt must be positive integers")
    if identity.get("source_sha") != expected_source:
        errors.append("Verifier checkout differs from workflow event SHA")
    if not re.fullmatch(r"[0-9a-f]{40}", identity.get("source_tree", "")):
        errors.append("Verifier source tree is missing")
    if set(identity.get("source_fingerprints", {})) != set(INPUTS):
        errors.append("Verifier source fingerprints are incomplete")
    if identity.get("source_delta_paths") != []:
        errors.append("Verifier source is not unchanged")
    cases = identity.get("expected_cases", [])
    if not cases or len(cases) != len(set(cases)):
        errors.append("Verifier native case inventory is empty or ambiguous")
    return errors


def read_exit_codes(folder):
    codes, hashes = {}, {}
    for key, name in EXIT_FILES.items():
        path = folder / name
        require(path.is_file() and not path.is_symlink(), "Original exit-code file is absent or a symlink")
        raw = path.read_bytes()
        require(re.fullmatch(rb"(?:0|[1-9][0-9]{0,2})\n", raw), "Malformed original shell exit code")
        code = int(raw)
        require(code <= 255, "Original shell exit code is out of range")
        codes[key], hashes[key] = code, digest(raw)
    return codes, hashes


def command_inventory(folder):
    inventory = {}
    for name in ("family", "commands"):
        directory = folder / name
        require(not directory.is_symlink(), "Execution evidence directory is a symlink")
        if not directory.exists():
            continue
        require(directory.is_dir(), "Execution evidence path is not a directory")
        for path in sorted(directory.rglob("*")):
            require(not path.is_symlink(), "Execution evidence contains a symlink")
            if path.is_dir():
                continue
            require(path.is_file(), "Execution evidence is not a regular file")
            raw = path.read_bytes()
            inventory[path.relative_to(folder).as_posix()] = {"bytes": len(raw), "sha256": digest(raw)}
    return inventory


def validate_command_outputs(folder, suite, inventory):
    require(isinstance(inventory, dict), "Execution output inventory is not an object")
    expected = [("family", "native-family-" + suite, "native_suite_seconds", [
        "bash", "tools/ci/run_native_family.sh", suite, "build/native-parallel/" + suite])]
    expected += [("commands/" + label, suite + "-" + label, key, command)
                 for label, key, command in COMMANDS[suite]]
    expected_receipts = {directory + "/receipt.json" for directory, _, _, _ in expected}
    observed_receipts = {name for name in inventory if name.endswith("/receipt.json")}
    require(observed_receipts == expected_receipts, "Native command receipt inventory differs")
    policy = execution_policy_identity()
    for directory, label, key, command in expected:
        receipt_name, log_name = directory + "/receipt.json", directory + "/command.log"
        require(log_name in inventory, "Original command log is absent")
        record = load_json((folder / receipt_name).read_text(encoding="utf-8"))
        require(isinstance(record, dict) and record.get("schema") == "execution-command-v1",
                "Unknown execution command schema")
        require(record.get("label") == label and record.get("command") == command,
                "Native command identity or ordered arguments differ")
        require(record.get("complete") is True and record.get("status") == "passed"
                and type(record.get("returncode")) is int and record["returncode"] == 0
                and record.get("timed_out") is False and record.get("natural_completion") is True,
                "Native command did not complete naturally and successfully")
        timeout = family_timeout_seconds(suite) if directory == "family" else command_timeout_seconds(suite, directory.split("/")[1])
        require(record.get("execution_policy") == policy
                and record.get("timeout_seconds") == timeout,
                "Native command execution policy differs")
        require(record.get("log_sha256") == inventory[log_name]["sha256"],
                "Original command log hash differs")


def scientific_inventory(root):
    paths = list(root.glob("stage3b-validation-*.json"))
    physics = root / "physics-cli-validation"
    require(not physics.is_symlink(), "Physics evidence directory is a symlink")
    if physics.exists():
        require(physics.is_dir(), "Physics evidence path is not a directory")
        paths.extend(physics.rglob("*"))
    inventory = {}
    for path in sorted(paths):
        require(not path.is_symlink(), "Scientific output contains a symlink")
        if path.is_dir():
            continue
        require(path.is_file(), "Scientific output is not a regular file")
        raw = path.read_bytes()
        inventory[path.relative_to(root).as_posix()] = {"bytes": len(raw), "sha256": digest(raw)}
    return inventory


def validate_scientific_outputs(root, suite, inventory):
    require(isinstance(inventory, dict), "Scientific output inventory is not an object")
    for path, value in inventory.items():
        require(isinstance(path, str) and isinstance(value, dict)
                and type(value.get("bytes")) is int and value["bytes"] >= 0
                and re.fullmatch(r"[0-9a-f]{64}", value.get("sha256", "")),
                "Scientific output identity is malformed")
    if suite == "worldgen":
        required = {"physics-cli-validation/validation.log", "physics-cli-validation/sanitized/results.json"}
        require(required <= set(inventory), "Required physics results or validation log are absent")
        result = load_json((root / "physics-cli-validation/sanitized/results.json").read_text(encoding="utf-8"))
        rows = result.get("invocations")
        require(isinstance(rows, list) and rows, "Physics invocation output inventory is absent")
        names = set()
        expected = set(required)
        # This checks output custody from the producing report, not its scientific assertions.
        for row in rows:
            require(isinstance(row, dict) and isinstance(row.get("name"), str)
                    and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", row["name"])
                    and row["name"] not in names, "Invalid/duplicate physics output name")
            names.add(row["name"])
            for field, suffix in (("stdout", ".jsonl"), ("stderr", ".stderr.log")):
                path = "physics-cli-validation/sanitized/" + row["name"] + suffix
                require(path in inventory and inventory[path]["sha256"] == row.get(field + "_sha256"),
                        "Original physics invocation output is absent or differs")
                expected.add(path)
        require(set(inventory) == expected, "Unexpected or missing physics scientific output")
    elif suite == "soliding-normal":
        require(set(inventory) == STAGE_OUTPUTS, "Required Stage3B scientific outputs are absent or unexpected")
    else:
        require(not inventory, "Unexpected scientific output for Native family")


def record_shard(root, output, suite, outcome, expected_source, run_id, run_attempt):
    require(suite in SUITES, "Unknown Native family")
    folder = output / suite
    log = folder / "run.log"
    receipt = {
        "schema": SCHEMA, "suite": suite, "source_sha": None, "source_tree": None,
        "event_sha": expected_source, "run_id": run_id, "run_attempt": run_attempt,
        "job_outcome": outcome, "runner_os": os.environ.get("RUNNER_OS", ""),
        "source_fingerprints": {}, "source_delta_paths": None,
        "log_present": log.is_file(), "log_bytes": None, "log_sha256": None,
        "exit_codes": {}, "exit_code_sha256": {}, "scientific_outputs": {}, "command_outputs": {},
        "errors": [],
    }
    try:
        identity = source_identity(root)
        receipt.update({key: identity[key] for key in
                        ("source_sha", "source_tree", "source_fingerprints", "source_delta_paths")})
        receipt["errors"].extend(context_errors(identity, expected_source, run_id, run_attempt))
    except Exception as error:
        receipt["errors"].append("source: " + type(error).__name__ + ": " + str(error))
    try:
        require(log.is_file() and not log.is_symlink(), "Original runner log is absent or a symlink")
        raw = log.read_bytes()
        receipt.update(log_bytes=len(raw), log_sha256=digest(raw))
    except Exception as error:
        receipt["errors"].append("log: " + type(error).__name__ + ": " + str(error))
    try:
        receipt["exit_codes"], receipt["exit_code_sha256"] = read_exit_codes(folder)
        require(all(code == 0 for code in receipt["exit_codes"].values()), "Original family or log capture exited nonzero")
    except Exception as error:
        receipt["errors"].append("exit codes: " + type(error).__name__ + ": " + str(error))
    try:
        receipt["command_outputs"] = command_inventory(folder)
        validate_command_outputs(folder, suite, receipt["command_outputs"])
    except Exception as error:
        receipt["errors"].append("execution outputs: " + type(error).__name__ + ": " + str(error))
    try:
        receipt["scientific_outputs"] = scientific_inventory(output.parent)
        validate_scientific_outputs(output.parent, suite, receipt["scientific_outputs"])
    except Exception as error:
        receipt["errors"].append("scientific output: " + type(error).__name__ + ": " + str(error))
    if outcome != "success":
        receipt["errors"].append("Native family execution outcome: " + outcome)
    if receipt["runner_os"] != "Linux":
        receipt["errors"].append("Native family did not run on the required Linux runner")
    write_json(folder / "receipt.json", receipt)
    return receipt


def verify_evidence(directory, identity, expected_source, run_id, run_attempt, policy_result, matrix_result):
    errors = context_errors(identity, expected_source, run_id, run_attempt)
    if policy_result != "success":
        errors.append("Native evidence/provider policy result: " + policy_result)
    if matrix_result != "success":
        errors.append("Native runner matrix result: " + matrix_result)
    if not directory.is_dir() or directory.is_symlink():
        errors.append("Original runner evidence directory is absent or a symlink")
    symlinks = [p for p in directory.rglob("*") if p.is_symlink()]
    if symlinks:
        errors.append("Original runner evidence contains symlinks")
    seen = {}
    originals = []
    for path in sorted(directory.rglob("receipt.json")):
        # Command receipts are sealed and validated through their owning family.
        # Other misplaced/duplicate receipts still enter the strict family gate.
        if len(path.parents) >= 4 and ((path.parent.name == "family" and path.parents[1].name in SUITES
                and path.parents[2].name == "native-parallel") or (
                path.parents[1].name == "commands" and path.parents[2].name in SUITES
                and path.parents[3].name == "native-parallel")):
            continue
        try:
            require(not path.is_symlink(), "Receipt is a symlink")
            r = load_json(path.read_text(encoding="utf-8"))
            require(isinstance(r, dict), "Receipt is not an object")
            suite = r.get("suite")
            require(suite in SUITES, "Unexpected Native family")
            require(suite not in seen, "Duplicate Native family: " + suite)
            seen[suite] = r
            require(path.parent.name == suite and path.parent.parent.name == "native-parallel",
                    "Receipt path does not identify its family")
            require(r.get("schema") == SCHEMA, "Unknown Native receipt schema")
            require(r.get("source_sha") == r.get("event_sha") == expected_source,
                    "Native family source/event SHA mismatch")
            require(r.get("source_tree") == identity.get("source_tree"), "Native family tree mismatch")
            require(type(r.get("run_id")) is int and r["run_id"] == run_id
                    and type(r.get("run_attempt")) is int and r["run_attempt"] == run_attempt,
                    "Native family run/attempt mismatch")
            require(r.get("runner_os") == "Linux", "Native family runner differs")
            require(r.get("source_fingerprints") == identity.get("source_fingerprints"),
                    "Native family source fingerprints differ")
            require(r.get("source_delta_paths") == [] and r.get("errors") == [],
                    "Native family source/custody errors remain")
            require(r.get("job_outcome") == "success", "Native family did not succeed")
            require(r.get("log_present") is True, "Native family log was absent at recording")
            codes, code_hashes = read_exit_codes(path.parent)
            require(r.get("exit_codes") == codes and r.get("exit_code_sha256") == code_hashes
                    and all(type(code) is int and code == 0 for code in r["exit_codes"].values()),
                    "Original family or log capture exit code differs or is nonzero")
            command_outputs = command_inventory(path.parent)
            require(r.get("command_outputs") == command_outputs,
                    "Original execution output inventory/bytes differ")
            validate_command_outputs(path.parent, suite, command_outputs)
            output_root = path.parent.parent.parent
            outputs = scientific_inventory(output_root)
            validate_scientific_outputs(output_root, suite, r.get("scientific_outputs"))
            require(r["scientific_outputs"] == outputs, "Original scientific output inventory/bytes differ")
            validate_scientific_outputs(output_root, suite, outputs)
            log = path.parent / "run.log"
            require(log.is_file() and not log.is_symlink(), "Original Native family log is absent or a symlink")
            raw = log.read_bytes()
            require(type(r.get("log_bytes")) is int and r["log_bytes"] == len(raw)
                    and r.get("log_sha256") == digest(raw), "Original Native family log bytes/hash differ")
            text = raw.decode("utf-8")
            require(text.rstrip().endswith("Native family passed: " + suite),
                    "Original Native family completion is absent")
            require(not any(marker in text for marker in
                            ("[fail]", "ERROR: AddressSanitizer", "SUMMARY: AddressSanitizer",
                             "WARNING: ThreadSanitizer", "SUMMARY: ThreadSanitizer", "runtime error:")),
                    "Original Native family log contains a sanitizer/test failure")
            observed = re.findall(r"^\[pass\] (.+)$", text, re.M)
            if suite in CASE_SUITES:
                require(observed == identity["expected_cases"], "Native test case coverage/order differs")
                summaries = re.findall(r"^([0-9]+) tests passed$", text, re.M)
                require(summaries == [str(len(identity["expected_cases"]))],
                        "Native test case summary is missing or inconsistent")
            originals.append({"suite": suite, "receipt": path.relative_to(directory).as_posix(),
                              "receipt_sha256": digest(path.read_bytes()),
                              "log": log.relative_to(directory).as_posix(), "log_bytes": len(raw),
                              "log_sha256": digest(raw), "source_case_passes": len(observed),
                              "exit_codes": codes, "exit_code_sha256": code_hashes,
                              "scientific_outputs": outputs, "command_outputs": command_outputs})
        except Exception as error:
            errors.append(str(path.relative_to(directory)) + ": " + type(error).__name__ + ": " + str(error))
    if set(seen) != SUITES:
        errors.append("Missing Native families: " + ", ".join(sorted(SUITES - set(seen))))
    return {
        "schema": "cybersand-native-qualification-v2", "source_sha": expected_source,
        "source_tree": identity.get("source_tree"), "run_id": run_id, "run_attempt": run_attempt,
        "expected_suites": sorted(SUITES), "received_suites": sorted(seen),
        "source_fingerprints": identity.get("source_fingerprints"),
        "expected_native_case_count": len(identity.get("expected_cases", [])),
        "policy_result": policy_result, "matrix_result": matrix_result,
        "outcomes": {suite: r.get("job_outcome") for suite, r in sorted(seen.items())},
        "original_evidence": originals, "errors": errors, "status": "failed" if errors else "passed",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    for name in ("record", "verify"):
        child = sub.add_parser(name)
        child.add_argument("--source-sha", required=True)
        child.add_argument("--run-id", required=True, type=int)
        child.add_argument("--run-attempt", required=True, type=int)
        child.add_argument("--output", required=True, type=Path)
        if name == "record":
            child.add_argument("--suite", required=True, choices=sorted(SUITES))
            child.add_argument("--outcome", required=True)
        else:
            child.add_argument("--directory", required=True, type=Path)
            child.add_argument("--policy-result", required=True)
            child.add_argument("--matrix-result", required=True)
    args = parser.parse_args()
    if args.operation == "record":
        report = record_shard(ROOT, args.output, args.suite, args.outcome,
                              args.source_sha, args.run_id, args.run_attempt)
        failed = bool(report["errors"])
    else:
        identity_error = None
        try:
            identity = source_identity(ROOT)
        except Exception as error:
            identity = {}
            identity_error = type(error).__name__ + ": " + str(error)
        report = verify_evidence(args.directory, identity, args.source_sha, args.run_id, args.run_attempt,
                                 args.policy_result, args.matrix_result)
        if identity_error:
            report["errors"].append("Verifier source readback: " + identity_error)
            report["status"] = "failed"
        write_json(args.output, report)
        failed = report["status"] != "passed"
    print(json.dumps(report, indent=2, sort_keys=True))
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
