#!/usr/bin/env python3
"""Read-only custody checks for a two-platform publication stage or immutable child.

This is an additive verifier, not a publisher or an execution-acceptance reducer.
The contract SHA-256 must come from a trusted acquisition/review record outside
the untrusted candidate. Hash-consistent evidence cannot authenticate itself.
Existing programme-specific native, graphics and installed-package gates remain
mandatory. See docs/operations/publication-custody.md for the migration contract.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile


class Rejected(ValueError):
    """An incomplete or inconsistent custody claim; never a skipped pass."""


POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\n"
                     rb"oid sha256:([0-9a-f]{64})\nsize ([1-9][0-9]*)\n")
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
PLATFORMS = {"linux": b"\x7fELF", "windows": b"MZ"}
MAX_ARCHIVE_BYTES = 256 * 1024 * 1024
MAX_MEMBER_BYTES = 64 * 1024 * 1024
MAX_EXPANDED_BYTES = 256 * 1024 * 1024
MAX_ARCHIVE_MEMBERS = 4096


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Rejected(message)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def strict_json(data: bytes) -> dict:
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result
    try:
        result = json.loads(data, object_pairs_hook=pairs,
                            parse_constant=lambda value: (_ for _ in ()).throw(
                                Rejected("Nonfinite JSON value: " + value)))
    except (ValueError, UnicodeDecodeError) as error:
        raise Rejected("Invalid JSON: " + str(error)) from error
    require(isinstance(result, dict), "Expected a JSON object")
    return result


def relative(name: str) -> str:
    require(isinstance(name, str) and bool(name), "Missing relative path")
    require(not any(ord(c) < 32 for c in name) and "\\" not in name and ":" not in name,
            "Unsafe path: " + name)
    path = PurePosixPath(name)
    require(not path.is_absolute() and all(p not in ("", ".", "..") for p in name.split("/"))
            and path.as_posix() == name, "Noncanonical relative path: " + name)
    return name


def regular_file(root: Path, name: str) -> Path:
    path = root / relative(name)
    current = root
    for part in PurePosixPath(name).parts:
        current = current / part
        require(not current.is_symlink(), "Symlink is not custody evidence: " + name)
    require(path.is_file() and stat.S_ISREG(path.stat().st_mode), "Missing regular file: " + name)
    return path


def file_identity(path: Path) -> tuple[str, int]:
    hasher = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
            size += len(block)
    return hasher.hexdigest(), size


def git(root: Path, *args: str, data: bytes | None = None) -> bytes:
    try:
        return subprocess.run(["git", "-C", str(root), *args], input=data, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60).stdout
    except (subprocess.SubprocessError, OSError) as error:
        # Do not reflect stderr: a remote URL may contain credentials.
        raise Rejected("Git custody inspection failed: " + args[0]) from error


def exact_commit(value: object, label: str) -> str:
    require(isinstance(value, str) and HEX40.fullmatch(value) is not None,
            "Missing exact " + label)
    return value


def exact_hash(value: object, label: str) -> str:
    require(isinstance(value, str) and HEX64.fullmatch(value) is not None,
            "Missing SHA-256: " + label)
    return value


def positive_id(value: object, label: str) -> str:
    require(isinstance(value, str) and re.fullmatch(r"[1-9][0-9]*", value) is not None,
            "Missing positive identity: " + label)
    return value


def load_contract(path: Path, expected_sha256: str) -> dict:
    exact_hash(expected_sha256, "externally pinned contract")
    data = path.read_bytes()
    require(digest(data) == expected_sha256, "Contract differs from independent custody pin")
    return strict_json(data)


def input_ledger(root: Path, source: str, expected: dict) -> None:
    """Hash actual committed blobs in one read, preserving the existing LF convention."""
    require(isinstance(expected, dict) and bool(expected), "Missing complete input ledger")
    names = sorted(expected)
    for name in names:
        relative(name)
        exact_hash(expected[name], "input " + name)
    tree_entries = {}
    for entry in git(root, "ls-tree", "-r", "-z", source).split(b"\0"):
        if entry:
            metadata, name = entry.split(b"\t", 1)
            tree_entries[name.decode()] = metadata.split()[:2]
    for name in names:
        require(tree_entries.get(name) in ([b"100644", b"blob"], [b"100755", b"blob"]),
                "Input must be a committed regular file: " + name)
    requests = b"".join((source + ":" + name + "\n").encode() for name in names)
    stream = io.BytesIO(git(root, "cat-file", "--batch", data=requests))
    for name in names:
        header = stream.readline().strip().split()
        require(len(header) == 3 and header[1] == b"blob", "Missing input blob: " + name)
        size = int(header[2])
        data = stream.read(size)
        require(len(data) == size and stream.read(1) == b"\n", "Truncated input: " + name)
        require(digest(data.replace(b"\r\n", b"\n")) == expected[name],
                "Committed input differs from qualified ledger: " + name)
    require(stream.read() == b"", "Extra Git input data")


def remote_lease(root: Path, remote: str, branch: str) -> str:
    require(re.fullmatch(r"[A-Za-z0-9_.-]+", remote) is not None and not remote.startswith("-"),
            "Use a configured remote name")
    git(root, "check-ref-format", "refs/heads/" + branch)
    lines = git(root, "ls-remote", "--refs", "--exit-code", remote, "refs/heads/" + branch).splitlines()
    require(len(lines) == 1, "Branch lease is missing or ambiguous")
    fields = lines[0].decode().split("\t")
    require(len(fields) == 2 and fields[1] == "refs/heads/" + branch, "Wrong leased branch")
    return exact_commit(fields[0], "observed branch head")


def changed_paths(root: Path, source: str, child: str | None) -> set[str]:
    args = ("diff", "--name-status", "--no-renames", "-z", source)
    raw = git(root, *args, child) if child else git(root, *args, "--cached")
    fields = raw.rstrip(b"\0").split(b"\0") if raw else []
    require(len(fields) % 2 == 0, "Malformed changed-path inventory")
    names = set()
    for status, path in zip(fields[::2], fields[1::2]):
        require(status == b"M", "Publication may only modify existing regular paths")
        name = relative(path.decode())
        require(name not in names, "Duplicate changed path")
        names.add(name)
    return names


def blob(root: Path, revision: str, name: str) -> bytes:
    relative(name)
    if revision == ":":
        entries = git(root, "ls-files", "--stage", "-z", "--", name).split(b"\0")
        require(len(entries) == 2 and entries[-1] == b"", "Missing indexed path: " + name)
        metadata, found = entries[0].split(b"\t", 1)
        mode, oid, stage = metadata.split()
        require(mode == b"100644" and stage == b"0" and found.decode() == name,
                "Index path must be a normal, unconflicted file: " + name)
    else:
        entries = git(root, "ls-tree", "-z", revision, "--", name).split(b"\0")
        require(len(entries) == 2 and entries[-1] == b"", "Missing committed path: " + name)
        metadata, found = entries[0].split(b"\t", 1)
        mode, kind, oid = metadata.split()
        require(mode == b"100644" and kind == b"blob" and found.decode() == name,
                "Committed path must be a normal file: " + name)
    return git(root, "cat-file", "blob", oid.decode())


def lfs_storage(root: Path) -> Path:
    values = [line.removeprefix("LocalMediaDir=") for line in git(root, "lfs", "env").decode().splitlines()
              if line.startswith("LocalMediaDir=")]
    require(len(values) == 1 and bool(values[0]), "Cannot identify local Git LFS object storage")
    return Path(values[0])


def archive_members(path: Path, expected: dict) -> dict[str, bytes]:
    require(type(expected.get("size")) is int and 0 < expected["size"] <= MAX_ARCHIVE_BYTES,
            "Invalid or oversized artifact archive")
    try:
        # Decode exactly the bytes covered by the independent pin. Reopening a
        # mutable pathname after hashing could silently consume another ZIP.
        # One extra byte detects oversized input without an unbounded read.
        with path.open("rb") as stream:
            data = stream.read(expected["size"] + 1)
        require((digest(data), len(data)) ==
                (exact_hash(expected.get("sha256"), "artifact"), expected["size"]),
                "Artifact archive differs from independent API/acquisition pin")
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            records = {}
            inventory = archive.infolist()
            require(len(inventory) <= MAX_ARCHIVE_MEMBERS, "Too many artifact members")
            require(sum(info.file_size for info in inventory) <= MAX_EXPANDED_BYTES,
                    "Artifact expanded size exceeds custody budget")
            for info in inventory:
                require(info.file_size <= MAX_MEMBER_BYTES, "Artifact member exceeds custody budget")
                if info.is_dir():
                    continue
                name = relative(info.filename)
                require(name not in records, "Duplicate archive member: " + name)
                require(not stat.S_ISLNK(info.external_attr >> 16), "Symlink in evidence archive")
                records[name] = archive.read(info)
            require(bool(records), "Empty evidence artifact")
            return records
    except (zipfile.BadZipFile, RuntimeError, OSError) as error:
        raise Rejected("Invalid evidence artifact") from error


def verify_report(records: dict[str, bytes], spec: dict, campaign: dict, slot: dict) -> dict:
    """Join real runner process records to their original log bytes and exact case plan.

    Case-specific assertions/readbacks remain the existing owner's responsibility;
    this function does not reinterpret a semantic failure as successful custody.
    """
    member = relative(spec["member"])
    require(member in records, "Missing qualification report: " + member)
    require(digest(records[member]) == exact_hash(spec.get("sha256"), "independently pinned report"),
            "Report differs from independent member pin")
    report = strict_json(records[member])
    require(report.get("status") == "passed" and report.get("completed") is True,
            "Incomplete or failed qualification report")
    require(report.get("platform") == spec["platform"], "Wrong report platform")
    candidate = report.get("candidate", {})
    for key in ("source_commit", "source_tree"):
        require(candidate.get(key) == campaign[key], "Wrong report " + key)
    for key in ("artifact", "sha256", "size", "source_inputs", "build_inputs", "toolchain"):
        expected = slot["binary_path"] if key == "artifact" else slot[key]
        require(candidate.get(key) == expected, "Report candidate mismatch: " + key)
    plan = spec.get("cases")
    require(isinstance(plan, dict) and bool(plan), "Missing independently derived required cases")
    results = report.get("results")
    require(isinstance(results, list) and len(results) == len(plan)
            and type(report.get("executed_cases")) is int and report["executed_cases"] == len(plan),
            "Incomplete case coverage")
    seen = set()
    for process in results:
        require(isinstance(process, dict), "Malformed process record")
        name = process.get("name")
        require(isinstance(name, str) and name in plan and name not in seen,
                "Missing, duplicate or unrelated process")
        seen.add(name)
        required = plan[name]
        require(isinstance(required, dict) and type(required.get("requires_display")) is bool
                and isinstance(required.get("command"), list) and bool(required["command"]),
                "Missing exact command/display requirement")
        require(process.get("command") == required["command"]
                and process.get("requires_display") is required["requires_display"],
                "Case command or actual display mode differs")
        require(process.get("status") == "passed" and process.get("natural_completion") is True
                and process.get("role") == "case" and type(process.get("returncode")) is int
                and process["returncode"] == 0 and type(process.get("pid")) is int and process["pid"] > 0
                and process.get("skip_messages") == [], "Process did not genuinely complete")
        for key in ("launch_error", "capture_error", "diagnostic_error", "timeout_kind", "timeout_diagnostic_error"):
            require(key in process and process[key] in (None, False, ""), "Failed or missing process field: " + key)
        log = relative(process.get("log"))
        log_member = (PurePosixPath(member).parent / log).as_posix()
        require(log_member in records and bool(records[log_member]), "Missing original process log")
        require(digest(records[log_member]) == exact_hash(process.get("log_sha256"), "process log"),
                "Report/log content mismatch")
    require(seen == set(plan), "Required cases missing")
    installed = report.get("installed_package")
    if spec["role"] == "installed-windows":
        require(isinstance(installed, dict) and installed.get("source_commit") == campaign["source_commit"]
                and installed.get("source_tree") == campaign["source_tree"]
                and installed.get("native_sha256") == slot["sha256"], "No source-matched installed package")
    else:
        require(installed is None, "Source report unexpectedly describes an installed package")
    return {"member": member, "sha256": digest(records[member]), "case_count": len(seen),
            "role": spec["role"], "platform": spec["platform"]}


def verify(root: Path, contract: dict, artifact_root: Path, *, remote: str = "origin",
           child: str | None = None) -> dict:
    require(type(contract.get("schema_version")) is int and contract["schema_version"] == 1
            and contract.get("kind") == "publication-custody-v1", "Unsupported custody contract")
    source = exact_commit(contract.get("source_commit"), "qualified source")
    tree = exact_commit(contract.get("source_tree"), "qualified tree")
    branch = contract.get("branch")
    require(isinstance(branch, str) and bool(branch), "Missing dedicated branch")
    git(root, "check-ref-format", "refs/heads/" + branch)
    run = positive_id(contract.get("run_id"), "workflow run")
    attempt = positive_id(contract.get("attempt"), "workflow attempt")
    require(git(root, "rev-parse", source + "^{tree}").decode().strip() == tree, "Qualified tree mismatch")
    if child:
        exact_commit(child, "publication child")
        require(git(root, "rev-list", "--parents", "-n", "1", child).decode().strip().split() == [child, source],
                "Publication must be one child of the exact tested source")
        revision = child
        index_snapshot = None
    else:
        require(git(root, "rev-parse", "HEAD").decode().strip() == source, "Checkout moved from tested parent")
        require(git(root, "branch", "--show-current").decode().strip() == branch, "Wrong publication branch")
        require(remote_lease(root, remote, branch) == source, "Remote branch moved before custody check")
        index_snapshot = git(root, "ls-files", "--stage", "-z")
        revision = ":"
    slots = contract.get("slots")
    require(isinstance(slots, dict) and set(slots) == set(PLATFORMS), "Both platform slots are mandatory")
    paths = [relative(slot[key]) for slot in slots.values() for key in ("binary_path", "provenance_path")]
    require(len(set(paths)) == 4, "Publication paths must be distinct")
    changed = changed_paths(root, source, child)
    required = {slot["provenance_path"] for slot in slots.values()}
    require(required <= changed <= set(paths), "Both provenance paths must change; unrelated paths are forbidden")
    storage = lfs_storage(root)
    runtimes = {}
    provenance_records = {}
    for platform, slot in slots.items():
        binary, provenance = slot["binary_path"], slot["provenance_path"]
        old = blob(root, source, binary)
        indexed = blob(root, revision, binary)
        require(POINTER.fullmatch(old) is not None, "Parent runtime is not a canonical LFS pointer")
        pointer = POINTER.fullmatch(indexed)
        require(pointer is not None, "Publication runtime is not a canonical LFS pointer")
        oid, size = pointer[1].decode(), int(pointer[2])
        require((indexed != old) == (binary in changed), "Changed-pointer inventory mismatch")
        require(oid == exact_hash(slot.get("sha256"), "qualified binary") and type(slot.get("size")) is int
                and size == slot["size"], "Pointer differs from qualified bytes")
        actual = regular_file(root, binary)
        require(file_identity(actual) == (oid, size), "Materialized runtime differs from pointer/provenance")
        with actual.open("rb") as stream:
            require(stream.read(len(PLATFORMS[platform])) == PLATFORMS[platform], "Wrong binary platform format")
        local = regular_file(storage, oid[:2] + "/" + oid[2:4] + "/" + oid)
        require(file_identity(local) == (oid, size), "Missing or corrupt local LFS object")
        data = blob(root, revision, provenance)
        require(digest(data) == exact_hash(slot.get("provenance_sha256"), "qualified provenance"),
                "Provenance differs from independent custody pin")
        require(data != blob(root, source, provenance), "Unchanged provenance is forbidden")
        p = strict_json(data)
        provenance_records[platform] = p
        expected = {"artifact": binary, "sha256": oid, "size": size, "source_commit": source,
                    "build_commit": source, "source_tree": tree, "publication_branch": branch,
                    "workflow_run": run, "workflow_attempt": attempt, "platform": platform + " x86_64",
                    "status": "evaluation-candidate-passed", "source_input_hash_kind": "sha256-canonical-lf"}
        for key, value in expected.items():
            require(type(p.get(key)) is type(value) and p[key] == value, "Invalid provenance field: " + key)
        for key in ("source_inputs", "build_inputs"):
            input_ledger(root, source, slot.get(key))
            require(p.get(key) == slot[key], "Provenance input ledger mismatch: " + key)
        require(isinstance(slot.get("toolchain"), str) and bool(slot["toolchain"])
                and p.get("toolchain") == slot["toolchain"], "Compiler identity mismatch")
        dependencies = slot.get("dependencies")
        require(isinstance(dependencies, dict) and bool(dependencies), "Missing dependency identity")
        for key, value in dependencies.items():
            require(isinstance(value, str) and bool(value) and p.get(key) == value, "Dependency identity mismatch")
        require(isinstance(p.get("qualification"), dict) and p["qualification"].get("status") == "passed",
                "Missing programme qualification")
        if platform == "windows":
            require(isinstance(p.get("installed_package_qualification"), dict)
                    and p["installed_package_qualification"].get("status") == "passed",
                    "Missing installed Windows qualification")
        runtimes[platform] = {"sha256": oid, "size": size, "pointer_changed": binary in changed}
    archives = {}
    artifact_specs = contract.get("artifacts")
    require(isinstance(artifact_specs, dict) and bool(artifact_specs), "Missing pinned immutable artifacts")
    for key, spec in artifact_specs.items():
        require(isinstance(spec, dict), "Invalid artifact specification")
        for name, expected in (("run_id", run), ("attempt", attempt), ("source_commit", source),
                               ("source_tree", tree), ("branch", branch), ("producer_conclusion", "success")):
            require(spec.get(name) == expected, "Artifact belongs to wrong or failed campaign: " + name)
        positive_id(spec.get("artifact_id"), "artifact")
        positive_id(spec.get("job_id"), "producer job")
        archives[key] = archive_members(regular_file(artifact_root, spec["path"]), spec)
    reports = contract.get("reports")
    require(isinstance(reports, list) and len(reports) == 3
            and all(isinstance(spec, dict) for spec in reports)
            and {spec.get("role") for spec in reports} == {"linux", "windows", "installed-windows"},
            "Linux, Windows and installed Windows reports are mandatory")
    verified = []
    for spec in reports:
        platform = "linux" if spec["role"] == "linux" else "windows"
        require(spec.get("platform") == platform and spec.get("artifact") in archives,
                "Wrong report platform or missing artifact")
        result = verify_report(archives[spec["artifact"]], spec, contract, slots[platform])
        p = provenance_records[platform]
        referred = (p["installed_package_qualification"].get("gameplay_report_sha256")
                    if spec["role"] == "installed-windows" else p["qualification"].get("report_sha256"))
        require(referred == result["sha256"], "Provenance does not reference the verified report")
        verified.append(result)
    if not child:
        require(git(root, "ls-files", "--stage", "-z") == index_snapshot
                and changed_paths(root, source, None) == changed,
                "Index moved during custody check")
        require(git(root, "diff", "--name-only", "-z") == b"", "Unstaged tracked changes remain")
        require(remote_lease(root, remote, branch) == source, "Remote branch moved during custody check")
        require(git(root, "rev-parse", "HEAD").decode().strip() == source, "Local parent moved during custody check")
        require(git(root, "branch", "--show-current").decode().strip() == branch,
                "Local branch moved during custody check")
        require(git(root, "ls-files", "--stage", "-z") == index_snapshot,
                "Index moved during final lease inspection")
    return {"schema_version": 1, "status": "custody-verified", "mode": "immutable-replay" if child else "stage",
            "source_commit": source, "source_tree": tree, "publication_child": child,
            "run_id": run, "attempt": attempt, "changed_paths": sorted(changed), "runtimes": runtimes,
            "reports": verified, "publication_authorized": False, "remote_lfs_storage_verified": False,
            "qualification_semantics_verified": False,
            "limitations": ["Trusted external contract and artifact acquisition are required",
                            "Programme-specific native, graphical and readback gates remain mandatory",
                            "Stage lease observations do not replace the publisher's atomic expected-parent push",
                            "Local LFS object presence does not prove remote LFS storage or physical owner acceptance"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--contract-sha256", required=True)
    parser.add_argument("--artifacts", required=True, type=Path)
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--replay-child")
    args = parser.parse_args()
    try:
        contract = load_contract(args.contract, args.contract_sha256)
        result = verify(args.root.resolve(), contract, args.artifacts.resolve(),
                        remote=args.remote, child=args.replay_child)
    except (Rejected, OSError, KeyError, TypeError, UnicodeError) as error:
        print(json.dumps({"status": "rejected", "publication_authorized": False, "reason": str(error)}))
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
