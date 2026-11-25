#!/usr/bin/env python3
"""Independent read-only ZIP/source audit; never executes a supplied package.

This recovery reviewer does not import the package producer or its verifiers.
Actual Windows execution is established separately by original Actions receipts.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import subprocess
import tarfile
import zipfile

MANIFEST = "objectshard-workbench-manifest.json"
CANDIDATE = "source-built-candidate-provenance.json"
RETAINED = "godot/addons/cybersand_native/runtime-provenance.json"
REFERENCE = "godot/addons/cybersand_native/retained-runtime-provenance.reference.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
ENGINES = {"runtime_sha256": "Godot_v4.7-stable_win64.exe",
           "console_sha256": "Godot_v4.7-stable_win64_console.exe"}
GUIDE = "docs/operations/objectshard-workbench-playtest.md"
CPP_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
GENERATED = {CANDIDATE, *ENGINES.values(), "Open Workbench.cmd", "Verify Workbench.cmd", "READ-ME.md",
             "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt", "vcruntime140.dll", "vc-runtime-provenance.json",
             "Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx"}
SOURCE_SCOPES = ["godot", "native/include", "native/src", "tools/objectshard", GUIDE,
                 "docs/operations/objectshard-m3-preflight-playtest.md",
                 "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
                 "third_party/rapier-bvh-build.lock.json", "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
                 "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def file_sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def member_sha(archive: zipfile.ZipFile, name: str) -> str:
    digest = hashlib.sha256()
    size = 0
    with archive.open(name) as stream:
        while block := stream.read(1024 * 1024):
            digest.update(block)
            size += len(block)
    # Central-directory length is untrusted: a member can end early with its
    # CRC still valid. Preserve the old actual-byte PE bounds before accepting it.
    require(size == archive.getinfo(name).file_size, "ZIP member length differs: " + name)
    return digest.hexdigest()


def pe_amd64(archive: zipfile.ZipFile, name: str) -> dict:
    # Inspect the same exact byte bounds without allocating a full 178 MB engine.
    size = archive.getinfo(name).file_size
    with archive.open(name) as stream:
        dos = stream.read(64)
        require(len(dos) == 64 and dos[:2] == b"MZ", "Missing MZ header: " + name)
        offset = struct.unpack_from("<I", dos, 0x3c)[0]
        require(offset + 26 <= size, "Missing PE AMD64 signature: " + name)
        stream.seek(offset)
        header = stream.read(26)
        require(len(header) == 26 and header[:6] == b"PE\0\0\x64\x86", "Missing PE AMD64 signature: " + name)
        optional_size = struct.unpack_from("<H", header, 20)[0]
        require(optional_size >= 2 and offset + 24 + optional_size <= size, "Invalid optional header bounds: " + name)
        require(struct.unpack_from("<H", header, 24)[0] == 0x20b, "Expected PE32+ image: " + name)
    return {"bytes": size, "sha256": member_sha(archive, name), "machine": "AMD64", "optional_header": "PE32+"}


def inspect(args: argparse.Namespace) -> dict:
    def git(*parts: str) -> bytes:
        return subprocess.check_output(["git", "-C", str(args.checkout), *parts], timeout=120)
    source_tree = git("rev-parse", args.source_ref + "^{tree}").decode().strip()
    source_commit = git("rev-parse", args.source_ref + "^{commit}").decode().strip()
    windows_source = git("show", args.source_ref + ":tools/ci/run_windows_godot_regressions.py").decode()
    constants = {}
    for node in ast.parse(windows_source).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            if node.targets[0].id in {"GODOT_VERSION", "GODOT_SHA512", "RAPIER_SHA256"}:
                constants[node.targets[0].id] = ast.literal_eval(node.value)
    with args.godot_archive.open("rb") as stream:
        official_archive_sha512 = hashlib.file_digest(stream, "sha512").hexdigest()
    require(official_archive_sha512 == constants["GODOT_SHA512"], "Independent Godot archive differs from frozen pin")
    with zipfile.ZipFile(args.godot_archive) as official:
        require(official.testzip() is None, "Independent Godot archive CRC failure")
        official_engines = {}
        for name in ENGINES.values():
            with official.open(name) as stream:
                official_engines[name] = hashlib.file_digest(stream, "sha256").hexdigest()
    result = {"schema": "objectshard-m4-independent-windows-zip-audit-v1", "status": "incomplete",
              "scope": "Read-only original ZIP/source inspection; does not claim actual Windows or physical GPU execution",
              "application_source": args.expected_source, "source_reference_commit": source_commit,
              "source_reference_tree": source_tree, "tree_equivalent_source_reference": source_commit != args.expected_source,
              "zip": {"filename": args.zip.name, "bytes": args.zip.stat().st_size,
                      "sha256": file_sha(args.zip)}, "failures": []}
    try:
        with zipfile.ZipFile(args.zip) as archive:
            members = archive.infolist()
            names = [info.filename for info in members]
            require(len(names) == len(set(names)) == len({name.casefold() for name in names}), "Duplicate or case-colliding ZIP member")
            for info in members:
                path = PurePosixPath(info.filename)
                require(not path.is_absolute() and not any(p in {"", ".", ".."} for p in info.filename.split("/")), "Unsafe ZIP path: " + info.filename)
                require("\\" not in info.filename and ":" not in info.filename and not info.is_dir(), "Unexpected ZIP path: " + info.filename)
                require(not stat.S_ISLNK(info.external_attr >> 16), "Symlink ZIP entry: " + info.filename)
            require(archive.testzip() is None, "ZIP CRC integrity failure")
            manifest_bytes = archive.read(MANIFEST)
            manifest = json.loads(manifest_bytes)
            inventory = manifest["files_sha256"]
            require(manifest["schema"] == "objectshard-m4-workbench-package-v1", "Wrong package schema")
            require(manifest["source_commit"] == args.expected_source and manifest["source_tree"] == source_tree, "Package source identity differs from frozen input")
            require(set(names) == set(inventory) | {MANIFEST}, "ZIP differs from complete immutable payload inventory")
            require(RETAINED not in inventory and REFERENCE in inventory, "Retained-reference separation is broken")
            observed = {name: member_sha(archive, name) for name in inventory}
            require(observed == inventory, "An immutable payload hash differs")
            result["manifest"] = {"sha256": sha(manifest_bytes), "payload_files": len(inventory),
                                  "uncompressed_payload_bytes": sum(info.file_size for info in members),
                                  "entry": manifest["entry"], "purpose": manifest["purpose"]}
            candidate = json.loads(archive.read(CANDIDATE))
            require(type(candidate["schema_version"]) is int and candidate["schema_version"] == 1, "Candidate schema")
            require(candidate["kind"] == "source-built-windows-candidate" and candidate["artifact"] == NATIVE, "Candidate kind/artifact")
            require(candidate["source_commit"] == candidate["build_commit"] == args.expected_source and candidate["source_tree"] == source_tree, "Candidate source/build/tree")
            require(candidate["sha256"] == inventory[NATIVE] == manifest["native"]["sha256"] == args.native_sha256, "Candidate native digest differs from separately qualified native artifact")
            require(type(candidate["size"]) is int and candidate["size"] == archive.getinfo(NATIVE).file_size, "Candidate native size")
            result["native"] = pe_amd64(archive, NATIVE)
            result["native"]["separately_verified_candidate_artifact_id"] = args.native_artifact_id
            result["rapier"] = pe_amd64(archive, RAPIER)
            require(inventory[RAPIER] == manifest["rapier"]["sha256"] == constants["RAPIER_SHA256"], "Rapier differs from frozen approved hash")
            require(manifest["godot"]["version"] == constants["GODOT_VERSION"] and manifest["godot"]["archive_sha512"] == official_archive_sha512, "Godot archive/version attestation differs from frozen pin")
            require(manifest["godot"]["archive_size"] == args.godot_archive.stat().st_size, "Godot official archive size differs")
            result["godot"] = {"independent_official_archive": {"bytes": args.godot_archive.stat().st_size, "sha512": official_archive_sha512},
                               "attested_official_archive": manifest["godot"], "images": {}}
            for key, name in ENGINES.items():
                require(manifest["godot"][key] == inventory[name] == official_engines[name], "Godot image differs from independently acquired official archive")
                result["godot"]["images"][name] = pe_amd64(archive, name)
            vc = json.loads(archive.read("vc-runtime-provenance.json").decode("utf-8-sig"))
            require(vc["schema"] == 1 and set(vc["files_sha256"]) == {"vcruntime140.dll", "Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx"}, "VC runtime/notice inventory")
            require(all(inventory[name] == digest for name, digest in vc["files_sha256"].items()), "VC runtime/notice hash")
            require(manifest["vc_runtime_sha256"] == inventory["vcruntime140.dll"], "VC runtime manifest digest")
            result["vc_runtime"] = pe_amd64(archive, "vcruntime140.dll")
            native_inputs, source_files, lfs_files = {}, {}, {}
            with tarfile.open(fileobj=io.BytesIO(git("archive", "--format=tar", args.source_ref, "--", *SOURCE_SCOPES))) as source_archive:
                for info in source_archive:
                    if not info.isfile():
                        continue
                    name = info.name
                    data = source_archive.extractfile(info).read()
                    if name.startswith(("native/include/", "native/src/", "godot/native_extension/")) and Path(name).suffix in CPP_SUFFIXES:
                        native_inputs[name] = sha(data.replace(b"\r\n", b"\n"))
                    if name.startswith("godot/.godot/") or ("/bin/" in name and name not in {NATIVE, RAPIER}):
                        continue
                    delivered = REFERENCE if name == RETAINED else name
                    require(delivered in inventory, "Missing committed input: " + name)
                    if name == NATIVE:
                        continue
                    pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                    if pointer:
                        require(inventory[delivered] == pointer[1].decode() and archive.getinfo(delivered).file_size == int(pointer[2]), "Committed LFS identity mismatch: " + name)
                        lfs_files[delivered] = pointer[1].decode()
                    else:
                        require(inventory[delivered] == sha(data), "Committed source bytes differ: " + name)
                        source_files[delivered] = sha(data)
            require(candidate["source_inputs"] == native_inputs == manifest["native"]["source_inputs"], "Incomplete or stale native build input map")
            require(set(inventory) == set(source_files) | set(lfs_files) | {NATIVE} | GENERATED, "Unexpected or omitted generated payload input")
            require(archive.read("READ-ME.md") == archive.read(GUIDE), "Owner guide differs from exact committed guide")
            require(manifest["ordinary_production_defaults_changed"] is False and manifest["entry"]["opt_in"] is True, "Evaluator changed production-default declaration")
            require(manifest["entry"]["scenario_ids"] == ["tower", "viaduct", "timber", "mixed", "stress"], "Ordinary scene inventory changed")
            for name in ("Open Workbench.cmd", "Verify Workbench.cmd"):
                text = archive.read(name).decode().replace("\r\n", "\n")
                require('setlocal DisableDelayedExpansion' in text and 'set "OBJECTSHARD_PACKAGE_ROOT=%~dp0."' in text, "Launcher root is not extraction-relative")
                require('verify_workbench_package.ps1' in text and 'if errorlevel 1 goto failed' in text, "Launcher lost verification admission")
            launch = archive.read("Open Workbench.cmd").decode()
            require(args.expected_source in launch and '--shared-workbench --objectshard-m4-workbench --object-shard-scene=tower' in launch, "Launcher source/ordinary entry mismatch")
            require('--objectshard-diagnostics' not in launch, "Ordinary evaluator unexpectedly forces optional diagnostics")
            result["source_custody"] = {"native_input_count": len(native_inputs), "committed_source_files": len(source_files), "committed_lfs_payloads": lfs_files,
                                       "retained_reference_sha256": inventory[REFERENCE], "candidate_provenance_sha256": inventory[CANDIDATE],
                                       "owner_guide_sha256": inventory[GUIDE]}
        result["status"] = "passed"
    except (AssertionError, KeyError, OSError, TypeError, ValueError, zipfile.BadZipFile) as exc:
        result["status"] = "failed"
        result["failures"].append(str(exc))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", type=Path, required=True)
    parser.add_argument("--godot-archive", type=Path, required=True)
    parser.add_argument("--checkout", type=Path, required=True)
    parser.add_argument("--source-ref", required=True)
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--native-sha256", required=True)
    parser.add_argument("--native-artifact-id", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(bool(re.fullmatch(r"[0-9a-f]{64}", args.native_sha256)), "Expected a complete independently verified native digest")
    result = inspect(args)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    raise SystemExit(result["status"] != "passed")
