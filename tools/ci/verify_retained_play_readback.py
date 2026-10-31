#!/usr/bin/env python3
"""Independently re-read retained PLAY evidence without replacing its originals.

The runner's success flag is a claim, not a substitute for its raw packet,
process, source and verifier evidence. Each call shares one operation watchdog
across source lookups, a fresh correctness-reader process and final sealing.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

import execution_policy
import run_godot_regressions as runner


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def same_json(actual: object, expected: object) -> bool:
    """Permit JSON int/float equality, never boolean-as-one or nonfinite values."""
    if type(expected) in (int, float):
        return type(actual) in (int, float) and math.isfinite(actual) and actual == expected
    if isinstance(expected, dict):
        return (isinstance(actual, dict) and actual.keys() == expected.keys()
                and all(same_json(actual[key], value) for key, value in expected.items()))
    if isinstance(expected, list):
        return (isinstance(actual, list) and len(actual) == len(expected)
                and all(same_json(a, b) for a, b in zip(actual, expected)))
    return type(actual) is type(expected) and actual == expected


def local_file(directory: Path, relative: object) -> Path:
    require(isinstance(relative, str) and bool(relative)
            and "\\" not in relative and ":" not in relative,
            "Unsafe retained PLAY artifact path")
    path = Path(relative)
    require(not path.is_absolute() and not {"..", "."}.intersection(relative.split("/")),
            "Retained PLAY artifact path escapes its shard")
    current = directory
    require(not current.is_symlink(), "Retained PLAY shard is a symlink")
    for part in path.parts:
        current /= part
        require(not current.is_symlink(), "Retained PLAY artifact contains a symlink")
    require(current.is_file() and current.resolve().is_relative_to(directory.resolve()),
            "Missing retained PLAY artifact: " + relative)
    return current


def original_source_identity(relative: str, identity: object, source: str,
                             platform: str, remaining) -> dict:
    """Bind original LF/CRLF hashes and the fresh reader to one Git blob."""
    require(isinstance(identity, dict) and set(identity) == {
        "path", "source_revision", "actual_sha256", "canonical_sha256"},
        "Missing retained PLAY source identity: " + relative)
    canonical = subprocess.check_output(
        ["git", "-C", str(runner.ROOT), "show", source + ":" + relative],
        timeout=remaining())
    actual = (runner.ROOT / relative).read_bytes()
    canonical_digest = hashlib.sha256(canonical).hexdigest()
    permitted_originals = {canonical_digest}
    if platform == "Windows":
        permitted_originals.add(hashlib.sha256(canonical.replace(b"\n", b"\r\n")).hexdigest())
    require(identity["path"] == relative and identity["source_revision"] == source
            and identity["canonical_sha256"] == canonical_digest
            and identity["actual_sha256"] in permitted_originals,
            "Retained PLAY source identity mismatch: " + relative)
    require(actual.replace(b"\r\n", b"\n") == canonical,
            "Coverage reader differs from committed PLAY source: " + relative)
    remaining()
    return {"path": relative, "source_revision": source,
            "canonical_sha256": canonical_digest,
            "original_actual_sha256": identity["actual_sha256"],
            "coverage_actual_sha256": hashlib.sha256(actual).hexdigest()}


def check_reduced(value: object, contract: runner.ReadbackContract, *, source: str,
                  rig: str, inputs: dict, source_ids: dict, verifier_digest: str) -> dict:
    require(isinstance(value, dict), "Retained PLAY reduced evidence is not an object")
    require(value.get("source_revision") == source and value.get("rig") == rig,
            "Retained PLAY reduced source or rig mismatch")
    require(same_json(value.get("execution_policy"), execution_policy.identity()),
            "Retained PLAY reduced execution policy mismatch")
    for name, expected in inputs.items():
        key = contract.result_digest_field if name == "result" else name + "_sha256"
        require(value.get(key) == expected, "Retained PLAY reduced input digest mismatch: " + name)
    for field, expected in contract.required_values:
        require(same_json(value.get(field), expected),
                "Retained PLAY required result mismatch: " + field)
    for field, minimum in contract.minimum_values:
        require(type(value.get(field)) is int and value[field] >= minimum,
                "Retained PLAY minimum result mismatch: " + field)
    for field, count in contract.control_counts:
        controls = value.get(field)
        require(isinstance(controls, list) and len(controls) == count
                and all(isinstance(row, dict) and isinstance(row.get("name"), str)
                        and bool(row["name"]) and isinstance(row.get("rejected_for"), str)
                        and bool(row["rejected_for"]) for row in controls)
                and len({row["name"] for row in controls}) == count,
                "Retained PLAY control inventory mismatch: " + field)
    if contract.verifier_digest_field:
        require(value.get(contract.verifier_digest_field) == verifier_digest,
                "Retained PLAY reduced verifier digest mismatch")
    if contract.consumed_source_fields:
        expected = {field: source_ids[path]["canonical_sha256"]
                    for field, path in contract.consumed_source_fields}
        require(same_json(value.get("consumed_source_sha256"), expected),
                "Retained PLAY consumed source identity mismatch")
    return value


def check_original_command(command: object, contract: runner.ReadbackContract,
                           paths: dict, source: str, rig: str, platform: str) -> None:
    """Allow archived host roots, while requiring the original command contract."""
    require(isinstance(command, list) and all(isinstance(part, str) and part for part in command),
            "Missing retained PLAY verifier command")
    arguments = [part.format(rig=rig, platform=platform) for part in contract.arguments]
    require(len(command) == 13 + len(arguments)
            and command[1].replace("\\", "/").endswith("/" + contract.verifier)
            and command[2] == "--result" and command[4] == "--log"
            and command[6] == "--process-json" and command[8:10] == ["--source", source]
            and command[10:10 + len(arguments)] == arguments
            and command[-3:-1] == ["--self-test", "--output"],
            "Retained PLAY verifier command differs from source")
    roots = set()
    for index, key in ((3, "result"), (5, "log"), (7, "process"), (-1, "output")):
        value = command[index].replace("\\", "/")
        suffix = "/" + paths[key]
        require(value.endswith(suffix), "Retained PLAY verifier command uses foreign inputs")
        roots.add(value[:-len(suffix)])
    require(len(roots) == 1, "Retained PLAY verifier command mixes artifact roots")


def verify(case: runner.Case, row: dict, directory: Path, source: str,
           platform: str = "Linux", *, output_dir: Path | None = None) -> dict:
    """Return a sealed independent proof; raise on missing or invalid originals.

    ``output_dir`` must be unused. By default it is a separate coverage-readback
    subdirectory of the downloaded shard; no original reader output is replaced.
    Both success and failure retain a new proof and any fresh reader stdout.
    """
    started = time.monotonic()
    allowance = execution_policy.watchdog_seconds("operation_seconds")
    def remaining() -> float:
        value = allowance - (time.monotonic() - started)
        require(value > 0, "Retained PLAY readback exhausted its operation watchdog")
        return value

    require(re.fullmatch(r"[A-Za-z0-9_]+", case.name) is not None, "Unsafe PLAY case name")
    directory = Path(directory)
    require(not directory.is_symlink(), "Retained PLAY shard is a symlink")
    directory = directory.resolve()
    output_dir = Path(output_dir) if output_dir is not None else directory / "coverage-readback" / case.name
    output_dir.mkdir(parents=True, exist_ok=False)
    output_dir = output_dir.resolve()
    proof = {"schema": "retained-play-readback-v1", "status": "running", "complete": False,
             "case": case.name, "source_revision": source, "platform": platform,
             "timeout_seconds": allowance, "output_directory": str(output_dir)}
    proof_path = output_dir / "proof.json"
    runner.write_json(proof_path, proof)
    try:
        require(isinstance(source, str) and re.fullmatch(r"[0-9a-f]{40}", source) is not None,
                "Retained PLAY readback requires an exact source commit")
        require(platform in {"Linux", "Windows"}, "Unsupported retained PLAY platform")
        contract = runner.case_readback_contract(case)
        require(contract is not None, "Case has no independent PLAY readback contract")
        rig = case.name.removeprefix(contract.prefix)
        readback = row.get("independent_evidence")
        require(isinstance(readback, dict) and readback.get("status") == "passed"
                and type(readback.get("returncode")) is int and readback["returncode"] == 0
                and not readback.get("error") and readback.get("timeout_seconds") == allowance,
                "Retained PLAY readback did not pass naturally")
        require(type(readback.get("seconds")) in (int, float)
                and math.isfinite(readback["seconds"]) and 0 <= readback["seconds"] <= allowance,
                "Retained PLAY readback exceeded its operation watchdog")
        require(row.get("name") == case.name and row.get("role") == "case"
                and row.get("status") == "passed" and type(row.get("returncode")) is int
                and row["returncode"] == 0 and row.get("natural_completion") is True
                and row.get("timeout_seconds") == case.timeout
                and row.get("requires_display") is case.requires_display
                and same_json(row.get("execution_policy"), execution_policy.identity())
                and not any(row.get(key) for key in (
                    "timed_out", "timeout_kind", "diagnostic_error", "launch_error", "skip_messages")),
                "Retained PLAY engine process did not pass naturally")
        base = case.name + "-readback/"
        relative = {"process": base + "engine-process.json", "log": case.name + ".log",
                    "result": (base + "raw-result.json" if contract.embedded_marker else
                               case.name + "-artifacts/" + rig + "-" + contract.result_suffix + ".json"),
                    "output": base + "verified.json", "verifier_log": base + "verifier-output.txt"}
        require(row.get("log") == relative["log"] and readback.get("receipt") == relative["process"]
                and readback.get("output") == relative["output"]
                and readback.get("verifier_log") == relative["verifier_log"]
                and (not contract.embedded_marker or readback.get("raw_result") == relative["result"]),
                "Retained PLAY artifact inventory differs from source")
        paths = {name: local_file(directory, path) for name, path in relative.items()}
        seals = {name: digest(path) for name, path in paths.items()}
        input_seals = {name: seals[name] for name in ("process", "log", "result")}
        require(readback.get("input_sha256") == input_seals
                and readback.get("receipt_sha256") == seals["process"]
                and row.get("log_sha256") == seals["log"]
                and readback.get("output_sha256") == seals["output"]
                and readback.get("verifier_log_sha256") == seals["verifier_log"],
                "Retained PLAY original artifact digest mismatch")
        process = json.loads(paths["process"].read_text(encoding="utf-8"))
        require(same_json(process, {key: value for key, value in row.items() if key != "independent_evidence"}),
                "Retained PLAY engine receipt differs from its case row")
        if contract.embedded_marker:
            marker = contract.embedded_marker.encode("utf-8")
            payloads = [line[len(marker):] for line in paths["log"].read_bytes().splitlines()
                        if line.startswith(marker)]
            require(payloads == [paths["result"].read_bytes()],
                    "Retained PLAY raw payload differs from its original log")
        check_original_command(readback.get("command"), contract, relative, source, rig, platform)
        dependencies = {path.format(rig=rig) for path in contract.source_inputs}
        originals = readback.get("source_input_identity", {})
        require(isinstance(originals, dict) and set(originals) == dependencies,
                "Retained PLAY source dependency inventory mismatch")
        source_ids = {path: original_source_identity(path, originals[path], source, platform, remaining)
                      for path in sorted(dependencies)}
        verifier = original_source_identity(contract.verifier, readback.get("verifier_identity"),
                                            source, platform, remaining)
        original = check_reduced(json.loads(paths["output"].read_text(encoding="utf-8")), contract,
            source=source, rig=rig, inputs=input_seals, source_ids=source_ids,
            verifier_digest=verifier["original_actual_sha256"])
        original_files = {relative[name]: value for name, value in seals.items()}
        artifact_directory = directory / (case.name + "-artifacts")
        if artifact_directory.exists():
            require(not artifact_directory.is_symlink(), "Retained PLAY artifact directory is a symlink")
            for artifact in sorted(artifact_directory.rglob("*")):
                require(not artifact.is_symlink(), "Retained PLAY packet is a symlink")
                if artifact.is_file():
                    path = artifact.relative_to(directory).as_posix()
                    original_files[path] = digest(local_file(directory, path))
                    remaining()
        proof.update(original_files=original_files, source_inputs=source_ids, verifier_identity=verifier)
        fresh_output = output_dir / "verified.json"
        fresh_log = output_dir / "verifier-output.txt"
        command = [sys.executable, str(runner.ROOT / contract.verifier),
                   "--result", str(paths["result"]), "--log", str(paths["log"]),
                   "--process-json", str(paths["process"]), "--source", source,
                   *(part.format(rig=rig, platform=platform) for part in contract.arguments),
                   "--self-test", "--output", str(fresh_output)]
        proof["command"] = command
        with fresh_log.open("w", encoding="utf-8") as log:
            child = subprocess.run(command, cwd=runner.ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   timeout=remaining())
        proof["returncode"] = child.returncode
        require(child.returncode == 0, "Independent retained PLAY reader rejected original evidence")
        remaining()
        fresh = check_reduced(json.loads(fresh_output.read_text(encoding="utf-8")), contract,
            source=source, rig=rig, inputs=input_seals, source_ids=source_ids,
            verifier_digest=verifier["coverage_actual_sha256"])
        comparable_original, comparable_fresh = dict(original), dict(fresh)
        if contract.verifier_digest_field:
            comparable_original[contract.verifier_digest_field] = verifier["canonical_sha256"]
            comparable_fresh[contract.verifier_digest_field] = verifier["canonical_sha256"]
        require(same_json(comparable_fresh, comparable_original),
                "Independent PLAY reduction differs from retained evidence")
        require(all(digest(local_file(directory, path)) == value for path, value in original_files.items()),
                "Original PLAY evidence changed during independent readback")
        require(all(digest(runner.ROOT / path) == value["coverage_actual_sha256"]
                    for path, value in {**source_ids, contract.verifier: verifier}.items()),
                "PLAY reader or source dependency changed during independent readback")
        remaining()
        proof.update(verified_sha256=digest(fresh_output), verifier_log_sha256=digest(fresh_log))
        remaining()
        proof["status"] = "passed"
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        proof.update(status="failed", error=f"{type(error).__name__}: {error}")
        raise ValueError(proof["error"]) from error
    finally:
        proof.update(complete=proof["status"] in {"passed", "failed"},
                     elapsed_seconds=round(time.monotonic() - started, 6))
        runner.write_json(proof_path, proof)
    return proof
