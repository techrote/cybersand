#!/usr/bin/env python3
"""Transport exact committed LFS objects through one same-attempt CI producer.

Acquisition still uses the bounded materialize_lfs helper. Consumers perform no
network fallback: every available byte is checked against their own committed
pointers before any selected runtime is installed. Downstream native/Rapier
provenance and application qualification remain mandatory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time

import materialize_lfs

SCHEMA = "cybersand-lfs-runtime-artifact-v1"
MANIFEST = "manifest.json"


class Budget:
    def __init__(self, seconds: float):
        if not math.isfinite(seconds) or seconds <= 10:
            raise ValueError("Runtime transport requires a finite shared allowance above ten seconds")
        self.started = time.monotonic()
        self.deadline = self.started + seconds
        self.allowance = seconds

    def remaining(self) -> float:
        value = self.deadline - time.monotonic()
        if value <= 0:
            raise TimeoutError("Runtime artifact shared deadline exhausted")
        return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def paths(values: list[str]) -> list[str]:
    require(type(values) is list and all(type(x) is str for x in values), "Object inventory must contain literal strings")
    require(bool(values) and len(set(values)) == len(values), "Expected a unique nonempty literal object inventory")
    for value in values:
        path = PurePosixPath(value)
        require(bool(value) and value != "." and path.parts and not path.is_absolute()
                and ".." not in path.parts and path.as_posix() == value
                and not any(c in value for c in "\\,:\n\r*?[]"), "Unsafe runtime object path")
    require(len({value.casefold() for value in values}) == len(values), "Windows-colliding runtime object paths")
    return sorted(values)


def identity(source: str, run_id: str, attempt: int) -> dict:
    require(bool(re.fullmatch(r"[0-9a-f]{40}", source)), "Expected an exact source commit")
    require(type(run_id) is str and bool(re.fullmatch(r"[1-9][0-9]*", run_id)), "Expected an exact workflow run ID")
    require(type(attempt) is int and attempt > 0, "Expected a positive workflow attempt")
    return {"source_commit": source, "run_id": run_id, "attempt": attempt}


def git(root: Path, budget: Budget, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args], timeout=budget.remaining())


def source_inventory(root: Path, selected: list[str], source: str, budget: Budget) -> list[dict]:
    require(git(root, budget, "rev-parse", "HEAD").decode().strip() == source,
            "Runtime transport checkout differs from expected source")
    result = []
    for name in paths(selected):
        pointer = git(root, budget, "show", source + ":" + name)
        match = materialize_lfs.POINTER.fullmatch(pointer)
        require(match is not None, "Runtime transport requires a committed canonical LFS pointer: " + name)
        target = root / name
        require(target.resolve() == target, "Runtime destination is a symlink or escapes checkout")
        result.append({"path": name, "sha256": match[1].decode(), "bytes": int(match[2])})
    return result


def digest(path: Path, budget: Budget) -> str:
    require(path.is_file() and not path.is_symlink() and path.resolve() == path,
            "Expected a regular, non-aliased runtime artifact file")
    value = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            budget.remaining()
            block = stream.read(1024 * 1024)
            if not block:
                break
            value.update(block)
    return value.hexdigest()


def verify_object(path: Path, item: dict, budget: Budget) -> None:
    require(type(item.get("bytes")) is int and path.is_file()
            and path.stat().st_size == item["bytes"], "Runtime object size differs from committed pointer")
    require(digest(path, budget) == item["sha256"], "Runtime object hash differs from committed pointer")


def copy(source: Path, target: Path, budget: Budget) -> None:
    require(not target.exists() and not target.is_symlink(), "Runtime staging destination already exists")
    target.parent.mkdir(parents=True, exist_ok=True)
    require(target.parent.resolve() == target.parent, "Runtime staging parent is aliased")
    with source.open("rb") as incoming, target.open("xb") as outgoing:
        while True:
            budget.remaining()
            block = incoming.read(1024 * 1024)
            if not block:
                break
            outgoing.write(block)


def write(path: Path, value: dict) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


def read(path: Path) -> dict:
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 1024 * 1024,
            "Missing, aliased or oversized runtime manifest/receipt")

    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate runtime manifest/receipt key")
            result[key] = value
        return result

    def bad_constant(_):
        raise ValueError("Nonfinite JSON value")

    value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique,
                       parse_constant=bad_constant)
    require(type(value) is dict, "Runtime manifest/receipt must be an object")
    return value


def stage(root: Path, selected: list[str], source: str, run_id: str, attempt: int,
          output: Path, allowance_seconds: float) -> dict:
    root, output = root.resolve(), output.absolute()
    bound = identity(source, run_id, attempt)
    budget = Budget(allowance_seconds)
    inventory = source_inventory(root, selected, source, budget)
    require(output.resolve() == output and not output.exists(), "Producer output must be new and non-aliased")
    output.mkdir(parents=True)
    result = {"schema": SCHEMA + "-stage", **bound, "status": "failed",
              "allowance_seconds": allowance_seconds}
    try:
        receipt = materialize_lfs.materialize(root, [x["path"] for x in inventory], source,
                                             output / "acquisition", budget.remaining())
        require(receipt.get("status") == "passed", "Producer LFS acquisition did not pass")
        for item in inventory:
            original = root / item["path"]
            verify_object(original, item, budget)
            destination = output / "payload" / item["path"]
            copy(original, destination, budget)
            verify_object(destination, item, budget)
        require(source_inventory(root, selected, source, budget) == inventory,
                "Producer source or committed inventory moved")
        # This receipt describes the completed payload check, not the later
        # manifest seal. A seal failure must never leave a transport PASS.
        result.update(status="payload_verified", seconds=time.monotonic() - budget.started)
        write(output / "stage-result.json", result)
        files = {p.relative_to(output).as_posix(): digest(p, budget)
                 for p in sorted(output.rglob("*")) if p.is_file()}
        manifest = {"schema": SCHEMA, **bound, "status": "passed", "objects": inventory,
                    "files_sha256": files}
        budget.remaining()
        write(output / MANIFEST, manifest)
        budget.remaining()
        return manifest
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        # A final write can itself exhaust the deadline. Retain its original
        # bytes as failed evidence, but leave no usable successful seal.
        seal = output / MANIFEST
        if seal.exists():
            os.replace(seal, output / "failed-manifest.json")
        result.update(status="failed", error=f"{type(error).__name__}: {error}",
                      seconds=time.monotonic() - budget.started)
        if not (output / "stage-result.json").exists():
            write(output / "stage-result.json", result)
        else:
            write(output / "stage-failure.json", result)
        raise


def install(root: Path, selected: list[str], available: list[str], source: str,
            run_id: str, attempt: int, artifact: Path, output: Path,
            allowance_seconds: float = 300) -> dict:
    root, artifact, output = root.resolve(), artifact.absolute(), output.absolute()
    bound = identity(source, run_id, attempt)
    budget = Budget(allowance_seconds)
    selected, available = paths(selected), paths(available)
    require(set(selected) <= set(available), "Selected runtime is absent from the declared producer inventory")
    require(artifact.resolve() == artifact and artifact.is_dir(), "Runtime artifact directory is absent or aliased")
    require(output.resolve() == output and not output.exists(), "Consumer receipt must be new and non-aliased")
    output.parent.mkdir(parents=True, exist_ok=True)
    result = {"schema": SCHEMA + "-installation", **bound, "status": "failed",
              "allowance_seconds": allowance_seconds, "selected": selected, "available": available,
              "installed": []}
    temporaries = []
    try:
        inventory = source_inventory(root, available, source, budget)
        manifest = read(artifact / MANIFEST)
        require(manifest.get("schema") == SCHEMA and manifest.get("status") == "passed"
                and all(type(manifest.get(k)) is type(v) and manifest.get(k) == v for k, v in bound.items()),
                "Runtime artifact belongs to another source, run or attempt")
        require(manifest.get("objects") == inventory
                and all(type(x.get("bytes")) is int for x in manifest["objects"]),
                "Runtime artifact does not contain the exact declared committed inventory")
        files = manifest.get("files_sha256")
        require(type(files) is dict and bool(files), "Runtime artifact has no sealed inventory")
        payload = {"payload/" + x["path"] for x in inventory}
        required = payload | {"acquisition/receipt.json", "acquisition/lfs-setup.log", "stage-result.json"}
        require(required <= set(files), "Runtime artifact omits required payload or acquisition evidence")
        paths(list(files))
        for name in files:
            require(name in required or re.fullmatch(r"acquisition/lfs-pull-[1-3]\.log", name),
                    "Unexpected runtime artifact member")
            require(type(files[name]) is str and re.fullmatch(r"[0-9a-f]{64}", files[name]), "Invalid sealed file digest")
        entries = list(artifact.rglob("*"))
        require(not any(p.is_symlink() for p in entries), "Runtime artifact contains a symlink")
        require({p.relative_to(artifact).as_posix() for p in entries if p.is_file()} == set(files) | {MANIFEST},
                "Runtime artifact has extra or missing files")
        for name, expected in files.items():
            require(digest(artifact / name, budget) == expected, "Sealed runtime artifact bytes changed")
        receipt = read(artifact / "acquisition/receipt.json")
        require(receipt.get("schema") == "cybersand-lfs-acquisition-v1"
                and receipt.get("status") == "passed" and receipt.get("source_commit") == source,
                "Original acquisition did not pass for this source")
        staged = read(artifact / "stage-result.json")
        require(staged.get("schema") == SCHEMA + "-stage" and staged.get("status") == "payload_verified"
                and all(type(staged.get(k)) is type(v) and staged.get(k) == v for k, v in bound.items()),
                "Producer payload verification belongs to another source, run or attempt")
        commands = receipt.get("commands")
        require(type(commands) is list and 2 <= len(commands) <= 4 and all(type(x) is dict for x in commands),
                "Original acquisition command inventory is incomplete")
        logs = set()
        for index, command in enumerate(commands):
            label = "lfs-setup" if index == 0 else f"lfs-pull-{index}"
            log = label + ".log"
            expected_command = (["git", "lfs", "install", "--local"] if index == 0 else
                                ["git", "lfs", "pull", "--include=" + ",".join(available), "--exclude="])
            require(command.get("label") == label and command.get("log") == log
                    and command.get("command") == expected_command
                    and command.get("joined") is True and command.get("timed_out") is False,
                    "Original acquisition command identity or owned completion differs")
            original_log = artifact / "acquisition" / log
            require(type(command.get("log_bytes")) is int and original_log.stat().st_size == command["log_bytes"]
                    and digest(original_log, budget) == command.get("log_sha256"),
                    "Original acquisition command log differs from its receipt")
            if index in (0, len(commands) - 1):
                require(type(command.get("returncode")) is int and command["returncode"] == 0,
                        "Original acquisition setup/final pull did not succeed")
            else:
                require(command.get("retryable_service_timeout") is True
                        and materialize_lfs.retryable(command.get("returncode"), original_log.read_text(encoding="utf-8", errors="replace")),
                        "Original acquisition retried an inadmissible failure")
            logs.add("acquisition/" + log)
        require(set(files) == payload | {"acquisition/receipt.json", "stage-result.json"} | logs,
                "Sealed acquisition logs differ from the complete original command inventory")
        observed = receipt.get("objects")
        require(type(observed) is list and len(observed) == len(inventory) and all(type(x) is dict for x in observed),
                "Acquisition object inventory differs")
        for item, acquired in zip(inventory, observed):
            require(type(acquired.get("bytes")) is int and all(acquired.get(k) == v for k, v in item.items())
                    and acquired.get("actual_sha256") == item["sha256"]
                    and type(acquired.get("actual_bytes")) is int and acquired["actual_bytes"] == item["bytes"],
                    "Acquisition receipt does not prove exact committed bytes")
            verify_object(artifact / "payload" / item["path"], item, budget)
        # Check every available object before modifying any selected destination.
        for item in inventory:
            if item["path"] not in selected:
                continue
            target = root / item["path"]
            temporary = target.with_name(target.name + ".ci-runtime-stage")
            require(not temporary.exists() and not temporary.is_symlink(), "Refusing to overwrite retained runtime staging")
            temporaries.append(temporary)
            copy(artifact / "payload" / item["path"], temporary, budget)
            verify_object(temporary, item, budget)
        require(source_inventory(root, available, source, budget) == inventory, "Consumer source or inventory moved")
        for item in inventory:
            if item["path"] in selected:
                budget.remaining()
                target = root / item["path"]
                require(target.resolve() == target, "Runtime destination became aliased")
                os.replace(target.with_name(target.name + ".ci-runtime-stage"), target)
                verify_object(target, item, budget)
                result["installed"].append(item)
        require(source_inventory(root, available, source, budget) == inventory, "Consumer source moved during installation")
        result.update(status="passed", manifest_sha256=digest(artifact / MANIFEST, budget))
        return result
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        result["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        for path in temporaries:
            if path.exists() and not path.is_symlink():
                path.unlink()
        result["seconds"] = time.monotonic() - budget.started
        try:
            write(output, result)
            if result["status"] == "passed":
                budget.remaining()
        except (OSError, RuntimeError, ValueError) as error:
            if result["status"] == "passed":
                # The installation bytes may be valid but late. A late or
                # interrupted final receipt cannot authorize the next step.
                if output.exists():
                    failed = output.with_name(output.name + ".failed-seal.json")
                    require(not failed.exists(), "Refusing to replace retained failed receipt")
                    os.replace(output, failed)
                result.update(status="failed", error=f"{type(error).__name__}: {error}",
                              seconds=time.monotonic() - budget.started)
                write(output, result)
            raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("stage", "install"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--include", action="append", required=True)
    parser.add_argument("--available", action="append")
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--attempt", required=True, type=int)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--allowance-seconds", type=float)
    args = parser.parse_args()
    try:
        if args.operation == "stage":
            require(args.artifact is None and args.available is None, "Producer uses only its explicit include inventory")
            value = stage(args.root, args.include, args.expected_source, args.run_id, args.attempt,
                          args.output, 1200 if args.allowance_seconds is None else args.allowance_seconds)
        else:
            require(args.artifact is not None, "Consumer requires a same-attempt artifact")
            value = install(args.root, args.include, args.available or args.include, args.expected_source,
                            args.run_id, args.attempt, args.artifact, args.output,
                            300 if args.allowance_seconds is None else args.allowance_seconds)
        print(json.dumps({k: value[k] for k in ("schema", "source_commit", "run_id", "attempt", "status")}, sort_keys=True))
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"LFS runtime transport failed: {type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
