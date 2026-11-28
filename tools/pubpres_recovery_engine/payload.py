#!/usr/bin/env python3
"""Admit the new font engine using an externally supplied build/proof identity.

This does not admit the original #609 engine; its frozen verifier stays separate.
The caller supplies the expected build source/run/attempt and provenance digest
from the producing workflow or independently checked artifact metadata.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import stat
import subprocess
import zipfile

import engine_contract as contract

ROOT = contract.ROOT
SHA = re.compile(r"[0-9a-f]{64}")
COMMIT = re.compile(r"[0-9a-f]{40}")
UPSTREAM_TREE = "a74f51b5f510fdacf72be7d8f8d598e7b7c192cd"
OFFICIAL_ARCHIVE = {"bytes": 83764371, "sha256": "02a5312236f4e0209c78bcb2f52135b1963e6b8888c873c9cee81459e60bcd71"}
API_RECORDS = {
    "extension_api.json": {"bytes": 6965055, "sha256": "53d37f85be32b6d10fb2266ca51f6ef0c3a55728acdb7c8301b1458a93c00943"},
    "gdextension_interface.h": {"bytes": 142425, "sha256": "640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254"},
    "gdextension_interface.json": {"bytes": 328021, "sha256": "7d8c0a039d9743eb8ebf88681ae0c641d8d3aa5ffca11081745a84da803e09a1"}}


def need(ok, message):
    if not ok:
        raise ValueError(message)


def digest(path: Path) -> str:
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def file_record(path: Path) -> dict:
    return {"bytes": path.stat().st_size, "sha256": digest(path)}


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def relative(name: str):
    # Reuse the retained path rules, including Windows aliases and device names.
    return load_module("font_engine_original_restore", ROOT / "tools/ci/restore_workbench_godot.py").relative(name)


def committed(root: Path, source: str, name: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), "show", source + ":" + name])


def expected_inputs(root: Path, source: str) -> dict:
    need(COMMIT.fullmatch(source), "Expected engine build source must be a full commit")
    derivation = contract.validate_derivation(root)
    names = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only", source,
                                     "--", contract.DIRECTORY], text=True).splitlines()
    names = {name for name in names if Path(name).parent.as_posix() == contract.DIRECTORY
             and Path(name).suffix in contract.INPUT_SUFFIXES}
    critical = {contract.DIRECTORY + "/" + name for name in
                contract.CRITICAL_NAMES}
    legacy = contract.LEGACY_INPUTS
    need(critical <= names, "Build source lacks the complete declared engine inputs")
    records = {}
    for name in sorted(names | legacy):
        data = committed(root, source, name)
        if name in critical | legacy:
            need((root / name).read_bytes() == data, "Current critical engine input differs from build source: " + name)
        records[name] = contract.sha(data)
    return {**derivation, "application_source": source, "files_sha256": records}


def normalized_patch(data: bytes) -> str:
    """Return exact ordered edits, allowing only unchanged context alignment.

    Git can match an identical closing brace on either side of an insertion.
    Reconstruct both complete hunk line vectors before trimming their common
    prefix/suffix; the resulting old/new coordinates and replacement bytes
    must still match. No whitespace, changed line, mode, path or edit is ignored.
    Only the registered regular-file, LF unified-diff representation is admitted.
    """
    need(isinstance(data, bytes) and 0 < len(data) < 1024 * 1024
         and data.endswith(b"\n") and b"\r" not in data and b"\0" not in data,
         "Invalid combined patch encoding or size")
    try:
        lines = data.decode("utf-8").split("\n")[:-1]
    except UnicodeDecodeError as error:
        raise ValueError("Combined patch is not UTF-8") from error
    result, seen, cursor = [], set(), 0
    path_pattern = r"[A-Za-z0-9_.\-/]+"
    hunk_pattern = re.compile(r"@@ -([1-9][0-9]*)(?:,([1-9][0-9]*))? "
                              r"\+([1-9][0-9]*)(?:,([1-9][0-9]*))? @@(?:[ \t].*)?")
    while cursor < len(lines):
        decorated_path = None
        if lines[cursor].startswith("diff --git "):
            match = re.fullmatch(r"diff --git a/(" + path_pattern + r") b/(" + path_pattern + r")", lines[cursor])
            need(match is not None and match[1] == match[2], "Unexpected combined patch rename/header")
            decorated_path = match[1]
            cursor += 1
            if cursor < len(lines) and lines[cursor].startswith("index "):
                need(re.fullmatch(r"index [0-9a-f]{6,40}\.\.[0-9a-f]{6,40} 100644", lines[cursor]),
                     "Unexpected patch mode/index")
                cursor += 1
        need(cursor + 1 < len(lines), "Truncated combined patch file header")
        old_header = re.fullmatch(r"--- a/(" + path_pattern + r")", lines[cursor])
        new_header = re.fullmatch(r"\+\+\+ b/(" + path_pattern + r")", lines[cursor + 1])
        need(old_header is not None and new_header is not None and old_header[1] == new_header[1],
             "Unexpected combined patch file header")
        name = old_header[1]
        need(not name.startswith("/") and all(part not in ("", ".", "..") for part in name.split("/"))
             and (decorated_path is None or decorated_path == name) and name not in seen,
             "Duplicate, aliased or mismatched combined patch path")
        seen.add(name)
        cursor += 2
        edits, previous_old_end, previous_new_end, delta = [], 0, 0, 0
        while cursor < len(lines) and lines[cursor].startswith("@@"):
            hunk = hunk_pattern.fullmatch(lines[cursor])
            need(hunk is not None, "Invalid patch hunk")
            old_start, old_count = int(hunk[1]), int(hunk[2] or "1")
            new_start, new_count = int(hunk[3]), int(hunk[4] or "1")
            need(old_start >= previous_old_end and new_start >= previous_new_end
                 and new_start - old_start == delta, "Overlapping, reordered or inconsistent patch hunk coordinates")
            cursor += 1
            old_lines, new_lines = [], []
            while len(old_lines) < old_count or len(new_lines) < new_count:
                need(cursor < len(lines) and lines[cursor] and lines[cursor][0] in " +-",
                     "Truncated or malformed patch hunk body")
                line = lines[cursor]
                cursor += 1
                if line[0] in " -":
                    old_lines.append(line[1:])
                if line[0] in " +":
                    new_lines.append(line[1:])
                need(len(old_lines) <= old_count and len(new_lines) <= new_count,
                     "Patch hunk line counts differ")
            prefix = 0
            while prefix < min(old_count, new_count) and old_lines[prefix] == new_lines[prefix]:
                prefix += 1
            old_end, new_end = old_count, new_count
            while old_end > prefix and new_end > prefix and old_lines[old_end - 1] == new_lines[new_end - 1]:
                old_end -= 1
                new_end -= 1
            removed, added = old_lines[prefix:old_end], new_lines[prefix:new_end]
            need(removed or added, "Empty/no-op patch hunk is not registered")
            edits.append({"old_line": old_start + prefix, "new_line": new_start + prefix,
                          "removed": removed, "added": added})
            previous_old_end, previous_new_end = old_start + old_count, new_start + new_count
            delta += new_count - old_count
        need(edits, "Combined patch file has no declared edit")
        result.append({"path": name, "mode": "100644", "edits": edits})
    # Distinct files may occur in patch-stack or git-diff alphabetical order.
    # Every file path/mode and every ordered edit/coordinate remains exact.
    return json.dumps(sorted(result, key=lambda row: row["path"]), ensure_ascii=False, separators=(",", ":"))


def validate_proof(proof: dict, *, build_source: str, build_run: int, build_attempt: int,
                   build: dict, inputs: dict, root: Path = ROOT):
    need(type(build_run) is int and build_run > 0 and type(build_attempt) is int and build_attempt > 0,
         "Expected build run/attempt must be positive integers")
    need(proof.get("schema") == "workbench-godot-build-provenance-v1" and proof.get("complete") is True
         and proof.get("custom_engine") is True and proof.get("public_api_equivalent") is True,
         "Incomplete new engine build/API proof")
    need(proof.get("application_source") == build_source and str(proof.get("workflow_run")) == str(build_run)
         and str(proof.get("workflow_attempt")) == str(build_attempt), "New engine build source/run/attempt differs")
    need(proof.get("upstream_commit") == build["source_commit"] and proof.get("upstream_tree") == UPSTREAM_TREE
         and proof.get("patches") == build["patches"] and proof.get("scope") == build["scope"]
         and proof.get("version") == build["version"] and proof.get("build_name") == build["build_name"],
         "New engine source, patches, identity or scope differs")
    need(proof.get("input_admission") == inputs, "New engine committed input admission differs")
    for field, name in (("lock", contract.DIRECTORY + "/engine.lock.json"),
                        ("builder", contract.DIRECTORY + "/build_engine.py")):
        need(proof.get(field) == file_record(root / name), "New engine builder/lock record differs")
    sources = {name: hashes["after_sha256"] for patch in build["patches"] for name, hashes in patch["files"].items()}
    need(set(proof.get("patched_sources", {})) == set(sources), "Unexpected patched engine source")
    for name, expected in sources.items():
        record = proof["patched_sources"][name]
        need(record.get("sha256") == expected and type(record.get("bytes")) is int and record["bytes"] > 0,
             "Patched engine source bytes differ: " + name)
    flags = proof.get("scons_flags", [])
    prefix = build["scons_flags"]
    need(flags[:len(prefix)] == prefix and len(flags) == len(prefix) + 2
         and flags[-2].startswith("angle_libs=") and len(flags[-2]) > len("angle_libs=")
         and flags[-1].startswith("accesskit_sdk_path=") and len(flags[-1]) > len("accesskit_sdk_path="),
         "New engine compiler/dependency flags differ")
    need(type(proof.get("workers")) is int and 1 <= proof["workers"] <= 4
         and str(proof.get("python", "")).startswith("3.12.")
         and str(proof.get("platform", "")).startswith("Windows-"), "Unregistered engine build host")
    dependencies = {name: {key: build[name][key] for key in ("bytes", "sha256")}
                    for name in ("scons", "angle", "accesskit")}
    dependencies["official_reference"] = OFFICIAL_ARCHIVE
    need(proof.get("dependency_archives") == dependencies, "New engine dependency archives differ")
    dumps = proof.get("api_dumps", {})
    need(set(dumps) == {"official", "custom"} and dumps["official"] == API_RECORDS
         and set(dumps["custom"]) == set(API_RECORDS), "Incomplete exact API dump records")
    for name, original in API_RECORDS.items():
        current = dumps["custom"][name]
        if name == "extension_api.json":
            need(type(current.get("bytes")) is int and current["bytes"] > 0
                 and SHA.fullmatch(current.get("sha256", "")), "Missing new engine API dump")
        else:
            need(current == original, "New engine public interface bytes differ")


def verify_payload(directory: Path, *, build_source: str, build_run: int, build_attempt: int,
                   proof_sha256: str, root: Path = ROOT) -> dict:
    directory, root = Path(directory).resolve(), Path(root).resolve()
    need(SHA.fullmatch(proof_sha256), "Expected provenance SHA-256 is required externally")
    proof_path = directory / "build-provenance.json"
    need(not directory.is_symlink() and not proof_path.is_symlink() and digest(proof_path) == proof_sha256,
         "New engine provenance differs from expected build/artifact")
    build = json.loads((root / contract.DIRECTORY / "engine.lock.json").read_bytes())
    inputs = expected_inputs(root, build_source)
    proof = json.loads(proof_path.read_bytes())
    validate_proof(proof, build_source=build_source, build_run=build_run, build_attempt=build_attempt,
                   build=build, inputs=inputs, root=root)
    records = proof.get("payload_files", {})
    need(isinstance(records, dict) and records and len(records) < 1000, "Missing or unbounded engine payload ledger")
    actual = set()
    for path in directory.rglob("*"):
        need(not path.is_symlink(), "Engine payload contains a symlink")
        if path.is_file():
            actual.add(path.relative_to(directory).as_posix())
    need(actual == set(records) | {"build-provenance.json"}
         and len({name.casefold() for name in actual}) == len(actual), "Missing, extra or colliding engine payload files")
    for name, record in records.items():
        path = directory / relative(name)
        need(record == file_record(path), "New engine payload bytes differ: " + name)
    mandatory = {"api-equivalence.json", "engine-source.patch", "workbench-godot.lock.json",
                 "bin/" + build["output_gui"], "bin/" + build["output_console"],
                 "notices/LICENSE.txt", "notices/COPYRIGHT.txt"}
    need(mandatory <= set(records) and all(name in mandatory or name.startswith("notices/") for name in records),
         "Unexpected payload role or absent licence")
    need((directory / "workbench-godot.lock.json").read_bytes() == (root / contract.DIRECTORY / "engine.lock.json").read_bytes(),
         "Packaged engine lock differs")
    combined = directory / "engine-source.patch"
    need(proof.get("combined_patch") == file_record(combined), "Combined source patch record differs")
    contract.verify_patch_stack(root, normalized_patch)
    expected = (root / contract.DIRECTORY / "godot-final-source.patch").read_bytes()
    need(normalized_patch(combined.read_bytes()) == normalized_patch(expected), "Combined source patch changes undeclared hunks")
    pe_reader = load_module("font_engine_exact_pe", root / contract.FROZEN_BUILDER)
    need(set(proof.get("executables", {})) == {build["output_gui"], build["output_console"]}, "Engine executable set differs")
    for role, key, subsystem in (("gui_executable", "output_gui", 2), ("console_executable", "output_console", 3)):
        need(proof.get(role) == "bin/" + build[key], "New engine executable role differs")
        path = directory / proof[role]
        observed = pe_reader.pe_imports(path)
        need(proof["executables"][build[key]] == {**file_record(path), "pe": observed}
             and observed["subsystem"] == subsystem and observed["unresolved_non_system_imports"] == [],
             "New engine PE bytes or static dependency closure differs")
    api = json.loads((directory / "api-equivalence.json").read_bytes())
    header = {"precision": "single", "version_major": 4, "version_minor": 7,
              "version_patch": 0, "version_status": "stable"}
    expected_api = {"api_equal_except_declared_build_labels": True, "interface_bytes_equal": True,
                    "ignored_header_fields": ["version_build", "version_full_name"],
                    "official_header": {**header, "version_build": "official", "version_full_name": "Godot Engine v4.7.stable.official"},
                    "custom_header": {**header, "version_build": build["build_name"],
                                      "version_full_name": "Godot Engine v4.7.stable." + build["build_name"]}}
    need(api == expected_api, "New engine public API/precision evidence differs")
    return proof


def restore(archive: Path, output: Path, *, archive_sha256: str, **identity) -> dict:
    need(SHA.fullmatch(archive_sha256) and digest(archive) == archive_sha256, "New engine archive differs from external digest")
    need(not output.exists(), "Use a fresh new-engine extraction directory")
    output.mkdir(parents=True)
    seen, total = set(), 0
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            need(member.orig_filename == member.filename, "Non-canonical engine ZIP path")
            name = member.orig_filename[:-1] if member.is_dir() else member.orig_filename
            path = relative(name)
            need(name.casefold() not in seen and not stat.S_ISLNK(member.external_attr >> 16), "Duplicate or linked engine ZIP member")
            seen.add(name.casefold())
            total += member.file_size
            need(len(seen) < 1000 and total < 1024 ** 3, "Unbounded new engine archive")
            destination = output / path
            if member.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(bundle.read(member))
    return verify_payload(output, **identity)


def add_identity_arguments(parser):
    parser.add_argument("--engine-build-source", required=True)
    parser.add_argument("--engine-build-run", required=True, type=int)
    parser.add_argument("--engine-build-attempt", required=True, type=int)
    parser.add_argument("--engine-proof-sha256", required=True)


def identity_arguments(args) -> dict:
    return {"build_source": args.engine_build_source, "build_run": args.engine_build_run,
            "build_attempt": args.engine_build_attempt, "proof_sha256": args.engine_proof_sha256}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--archive-sha256")
    parser.add_argument("--evidence", type=Path, required=True)
    add_identity_arguments(parser)
    args = parser.parse_args()
    identity = identity_arguments(args)
    proof = (restore(args.archive, args.directory, archive_sha256=args.archive_sha256 or "", **identity)
             if args.archive else verify_payload(args.directory, **identity))
    need(not args.evidence.exists(), "Refusing to replace an engine admission receipt")
    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    report = {"schema": "pubpres-font-engine-admission-v1", "complete": True, **identity,
              "archive_sha256": args.archive_sha256, "version": proof["version"],
              "gui_sha256": proof["executables"][Path(proof["gui_executable"]).name]["sha256"],
              "console_sha256": proof["executables"][Path(proof["console_executable"]).name]["sha256"],
              "public_api_equivalent": True, "physical_acceptance": "HOLD"}
    args.evidence.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
