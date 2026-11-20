#!/usr/bin/env python3
"""Package an immutable publication checkout with its already-qualified runtime.

This auxiliary harness never compiles, publishes, or manufactures a source-built
candidate manifest. Application source and native build source remain distinct.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

import retained_runtime_admission as admission

NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
PROVENANCE = "godot/addons/cybersand_native/runtime-provenance.json"
GUIDE = "docs/operations/gentek80-evaluation.md"
GUI = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
VERSION = "4.7.stable.official.5b4e0cb0f"
MANIFEST = "candidate-manifest.json"
CUSTODY = "retained-runtime-custody.json"
ASSETS = {GUI, CONSOLE, "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt",
          "vcruntime140.dll", "Microsoft-Visual-C-Runtime-LICENSE.docx",
          "Microsoft-Visual-Studio-2022-LICENSE.docx", "vc-runtime-provenance.json"}


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def safe_relative(name: str) -> str:
    require(isinstance(name, str) and name and "\\" not in name and ":" not in name,
            "Unsafe package path")
    path = PurePosixPath(name)
    require(not path.is_absolute() and ".." not in path.parts and str(path) == name,
            "Unsafe or noncanonical package path: " + name)
    return name


def extract_pristine(archive: Path, destination: Path, expected_sha256: str) -> None:
    require(re.fullmatch(r"[0-9a-f]{64}", expected_sha256) is not None and sha(archive) == expected_sha256,
            "Archive digest mismatch")
    require(not destination.exists(), "Extraction must use a new directory")
    destination.mkdir(parents=True)
    seen: set[str] = set()
    total = 0
    with zipfile.ZipFile(archive) as source:
        for item in source.infolist():
            if item.is_dir():
                safe_relative(item.filename.rstrip("/"))
                continue
            name = safe_relative(item.filename)
            require(name.casefold() not in seen, "Duplicate package member: " + name)
            seen.add(name.casefold())
            mode = (item.external_attr >> 16) & 0o170000
            require(mode != 0o120000, "Package symlinks are forbidden")
            total += item.file_size
            require(item.file_size <= 512 * 1024 * 1024 and total <= 1536 * 1024 * 1024,
                    "Package extraction exceeds its bounded payload allowance")
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.open(item) as incoming, target.open("wb") as outgoing:
                shutil.copyfileobj(incoming, outgoing)


def verify_inventory(directory: Path, manifest: dict) -> None:
    expected = manifest.get("files_sha256")
    require(isinstance(expected, dict) and bool(expected), "Missing complete package file map")
    for name, digest in expected.items():
        safe_relative(name)
        require(name != MANIFEST and re.fullmatch(r"[0-9a-f]{64}", str(digest)) is not None,
                "Invalid package file digest")
        target = directory / name
        require(target.is_file() and not target.is_symlink() and sha(target) == digest,
                "Missing or altered package file: " + name)
    require(not any(p.is_symlink() for p in directory.rglob("*")), "Package contains a symlink")
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file()}
    require(actual == set(expected) | {MANIFEST}, "Package has missing or extra files")


def accepted_packager(candidate: Path):
    path = candidate / "tools/package_explore001_candidate.py"
    spec = importlib.util.spec_from_file_location("_gentek80_accepted_packager", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git_payload(candidate: Path, final_sha: str):
    names = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json",
             "third_party/native-toolchain.lock.json", "third_party/rapier-bvh-build.lock.json",
             "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
             "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md", GUIDE]
    payload = subprocess.check_output(["git", "-C", str(candidate), "archive", final_sha, "--", *names], timeout=60)
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for entry in archive:
            require(not entry.issym() and not entry.islnk(), "Repository package source contains a link")
            if not entry.isfile() or entry.name.startswith("godot/.godot/"):
                continue
            name = safe_relative(entry.name)
            if "/bin/" in name and name not in (NATIVE, RAPIER):
                continue
            data = archive.extractfile(entry).read()
            if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                require(match is not None, "Noncanonical LFS pointer: " + name)
                data = (candidate / name).read_bytes()
                require(hashlib.sha256(data).hexdigest() == match[1].decode() and len(data) == int(match[2]),
                        "Unmaterialized or changed final LFS payload: " + name)
            yield name, data


def identity_fields(manifest: dict, final_sha: str, final_tree: str, built_sha: str, native_sha: str) -> None:
    require(type(manifest.get("schema")) is int and manifest["schema"] == 1
            and manifest.get("kind") == "gentek80-retained-runtime-evaluation",
            "Wrong retained-package schema")
    require(manifest.get("source_commit") == final_sha and manifest.get("source_tree") == final_tree,
            "Package application source mismatch")
    require(manifest.get("native_build_commit") == built_sha and manifest.get("native_sha256") == native_sha,
            "Package native build custody mismatch")
    require("build_commit" not in manifest and final_sha != built_sha,
            "Retained package must not fabricate a final-head build")


def qualified_asset_files(archive: Path, expected_sha: str, built_sha: str,
                          built_tree: str, native_sha: str) -> dict:
    require(sha(archive) == expected_sha, "Original qualified asset ZIP hash mismatch")
    with zipfile.ZipFile(archive) as source:
        names = [item.filename for item in source.infolist() if not item.is_dir()]
        require(len({safe_relative(name).casefold() for name in names}) == len(names),
                "Original qualified asset ZIP contains duplicate members")
        manifest = json.loads(source.read(MANIFEST))
        require(manifest.get("source_commit") == built_sha and manifest.get("source_tree") == built_tree
                and manifest.get("native_sha256") == native_sha and manifest.get("godot_version") == VERSION,
                "Original asset package does not identify the qualified build build")
        files = manifest["files_sha256"]
        require(ASSETS.issubset(files), "Original qualified package lacks dependency assets")
        expected = {name: files[name] for name in sorted(ASSETS)}
        require(all(hashlib.sha256(source.read(name)).hexdigest() == digest for name, digest in expected.items()),
                "Original dependency asset bytes differ from the qualified package manifest")
    return expected


def verify_package(candidate: Path, directory: Path, *, final_sha: str, final_tree: str,
                   built_sha: str, native_sha: str, assets_sha256: str,
                   bundle: Path, assets_archive: Path) -> dict:
    manifest = json.loads((directory / MANIFEST).read_text(encoding="utf-8"))
    identity_fields(manifest, final_sha, final_tree, built_sha, native_sha)
    verify_inventory(directory, manifest)
    custody = json.loads((directory / CUSTODY).read_text(encoding="utf-8"))
    require(custody.get("schema") == "gentek80-retained-runtime-custody-v1"
            and custody.get("kind") == "retained-runtime-reuse"
            and custody.get("application_source_commit") == final_sha
            and custody.get("application_source_tree") == final_tree
            and custody.get("native_build_commit") == built_sha
            and custody.get("native_sha256") == native_sha
            and custody.get("asset_package_sha256") == assets_sha256
            and "build_commit" not in custody,
            "Retained runtime custody does not match the package")
    provenance_bytes = subprocess.check_output(["git", "-C", str(candidate), "show", final_sha + ":" + PROVENANCE], timeout=60)
    require((directory / PROVENANCE).read_bytes() == provenance_bytes,
            "Package must retain the actual final committed native provenance")
    provenance = json.loads(provenance_bytes)
    require(provenance["source_commit"] == provenance["build_commit"] == built_sha
            and provenance["sha256"] == native_sha and sha(directory / NATIVE) == native_sha,
            "Published provenance must preserve the actual earlier build source")
    require(manifest.get("native_build_tree") == custody.get("native_build_tree") == provenance["source_tree"]
            and custody.get("native_bytes") == provenance["size"], "Original native build tree or size changed")
    original_paths = {"original-runtime-provenance.json": bundle / Path(PROVENANCE).name,
                      "original-validation.json": bundle / "validation.json",
                      "original-native-build-ledger.json": bundle / "gentek80-runtime-build-ledger.json"}
    require(custody.get("original_receipt_sha256") == {name: sha(path) for name, path in original_paths.items()}
            and all((directory / "provenance" / name).read_bytes() == path.read_bytes()
                    for name, path in original_paths.items()), "Copied original build/validation receipts differ")
    require((directory / "provenance/original-runtime-provenance.json").read_bytes() == provenance_bytes,
            "Original build provenance differs from the actual published record")
    expected_repo = {name: hashlib.sha256(data).hexdigest() for name, data in git_payload(candidate, final_sha)}
    require(manifest.get("repository_files_sha256") == expected_repo
            and all(manifest["files_sha256"].get(name) == value for name, value in expected_repo.items()),
            "Package repository payload differs from the exact final Git tree")
    packager = accepted_packager(candidate)
    vc = packager.verify_vc_runtime(directory)
    require(vc["files_sha256"]["vcruntime140.dll"] == manifest.get("vc_runtime_sha256"),
            "Package VC runtime identity mismatch")
    profiles = {p.name: sha(p) for p in sorted((directory / "examples/worldgen").glob("*.json"))}
    resource_profiles = {p.name: sha(p) for p in sorted((directory / "godot/authoring/worldgen").glob("*.json"))}
    require(profiles and profiles == resource_profiles == manifest.get("generator_profiles_sha256"),
            "Package canonical generator profiles differ")
    require(manifest.get("asset_package_sha256") == assets_sha256 and set(manifest.get("asset_files_sha256", {})) == ASSETS,
            "Missing qualified dependency-asset identity")
    expected_assets = qualified_asset_files(assets_archive, assets_sha256, built_sha, provenance["source_tree"], native_sha)
    require(manifest["asset_files_sha256"] == expected_assets,
            "Dependency hashes do not match the independently pinned original qualified ZIP")
    require(all(manifest["files_sha256"].get(name) == digest for name, digest in manifest["asset_files_sha256"].items()),
            "Bundled engine/runtime assets differ from their attested files")
    require(not (directory / "source-built-candidate-provenance.json").exists(),
            "Retained packaging must not impersonate a new source-built candidate")
    return manifest


def create(args) -> dict:
    candidate, bundle = args.candidate.resolve(), args.bundle.resolve()
    before = admission.verify(candidate, bundle, "windows", args.built_source, args.published_source,
                              args.published_tree, args.run_id, args.run_attempt)
    published = json.loads((candidate / PROVENANCE).read_text(encoding="utf-8"))
    require(not args.output.exists() and not args.archive.exists(), "Package destinations must be new")
    require(sha(args.assets_archive) == args.assets_sha256, "Qualified original asset ZIP digest mismatch")
    with tempfile.TemporaryDirectory(prefix="gentek80-qualified-assets-") as temp:
        assets = Path(temp) / "assets"
        extract_pristine(args.assets_archive, assets, args.assets_sha256)
        previous = json.loads((assets / MANIFEST).read_text(encoding="utf-8"))
        verify_inventory(assets, previous)
        require(previous.get("source_commit") == args.built_source
                and previous.get("source_tree") == published["source_tree"]
                and previous.get("native_sha256") == published["sha256"]
                and previous.get("godot_version") == VERSION,
                "Dependency assets must come from the actual qualified build owner package")
        require(ASSETS.issubset(previous["files_sha256"]), "Qualified package omits required engine/runtime assets")
        args.output.mkdir(parents=True)
        repository_files = {}
        for name, data in git_payload(candidate, args.published_source):
            target = args.output / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            repository_files[name] = hashlib.sha256(data).hexdigest()
        packager = accepted_packager(candidate)
        profiles = packager.stage_generator_profiles(args.output)
        vc_sha = packager.stage_vc_runtime(assets, args.output)
        for name in sorted(ASSETS - (packager.VC_RUNTIME_FILES | {"vc-runtime-provenance.json"})):
            shutil.copyfile(assets / name, args.output / name)
        version = subprocess.check_output([str(args.output / CONSOLE), "--version"], text=True, timeout=30).strip()
        require(version == VERSION, "Bundled Godot version mismatch")
        originals = {"original-runtime-provenance.json": bundle / Path(PROVENANCE).name,
                     "original-validation.json": bundle / "validation.json",
                     "original-native-build-ledger.json": bundle / "gentek80-runtime-build-ledger.json"}
        for name, path in originals.items():
            target = args.output / "provenance" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
        custody = {"schema": "gentek80-retained-runtime-custody-v1", "kind": "retained-runtime-reuse",
                   "application_source_commit": args.published_source, "application_source_tree": args.published_tree,
                   "native_build_commit": args.built_source, "native_build_tree": published["source_tree"],
                   "native_sha256": published["sha256"], "native_bytes": published["size"],
                   "original_qualification_run": args.run_id, "original_qualification_attempt": args.run_attempt,
                   "asset_package_sha256": args.assets_sha256,
                   "original_receipt_sha256": {name: sha(path) for name, path in originals.items()},
                   "verified_publication_boundary": before,
                   "orchestration_commit": os.environ.get("GITHUB_SHA"),
                   "orchestration_run": os.environ.get("GITHUB_RUN_ID"),
                   "scope": "Existing qualified native bytes packaged with their exact final application checkout; no native rebuild or publication."}
        write_json(args.output / CUSTODY, custody)
        (args.output / "Open Workbench.cmd").write_text(
            '@echo off\ncd /d "%~dp0"\n'
            f'set CYBERSAND_SOURCE_REVISION={args.published_source}\n'
            f'"%~dp0{CONSOLE}" --headless --path "%~dp0godot" --editor --quit\n'
            'if errorlevel 1 (pause & exit /b 1)\n'
            f'start "" "%~dp0{GUI}" --path "%~dp0godot" -- --workbench\n', encoding="utf-8", newline="\r\n")
        guide = (args.output / GUIDE).read_text(encoding="utf-8")
        (args.output / "READ-ME.md").write_text(
            "# Exact final application and runtime identity\n\n"
            f"Application/publication commit: `{args.published_source}`\n\n"
            f"Native build commit: `{args.built_source}`\n\n"
            f"Native Windows DLL SHA-256: `{published['sha256']}`\n\n"
            "The DLL is the qualified retained library from that build, unchanged. "
            "`retained-runtime-custody.json` records the build, publication and packaging proof. "
            "`candidate-manifest.json` hashes every shipped file.\n\n" + guide,
            encoding="utf-8")
        files = {p.relative_to(args.output).as_posix(): sha(p) for p in sorted(args.output.rglob("*")) if p.is_file()}
        manifest = {"schema": 1, "kind": "gentek80-retained-runtime-evaluation",
                    "purpose": "final-publication-head Windows Workbench evaluation; no new native compile",
                    "source_commit": args.published_source, "source_tree": args.published_tree,
                    "native_build_commit": args.built_source, "native_build_tree": published["source_tree"],
                    "native_sha256": published["sha256"], "godot_version": version,
                    "vc_runtime_sha256": vc_sha, "generator_profiles_sha256": profiles,
                    "asset_package_sha256": args.assets_sha256,
                    "asset_files_sha256": {name: previous["files_sha256"][name] for name in sorted(ASSETS)},
                    "repository_files_sha256": repository_files, "files_sha256": files}
        write_json(args.output / MANIFEST, manifest)
    verify_package(candidate, args.output, final_sha=args.published_source, final_tree=args.published_tree,
                   built_sha=args.built_source, native_sha=published["sha256"], assets_sha256=args.assets_sha256,
                   bundle=bundle, assets_archive=args.assets_archive)
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(args.output.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(args.output).as_posix())
    archive_sha = sha(args.archive)
    with tempfile.TemporaryDirectory(prefix="gentek80-final-package-check-") as temp:
        extracted = Path(temp) / "pristine"
        extract_pristine(args.archive, extracted, archive_sha)
        verify_package(candidate, extracted, final_sha=args.published_source, final_tree=args.published_tree,
                       built_sha=args.built_source, native_sha=published["sha256"], assets_sha256=args.assets_sha256,
                       bundle=bundle, assets_archive=args.assets_archive)
    after = admission.verify(candidate, bundle, "windows", args.built_source, args.published_source,
                             args.published_tree, args.run_id, args.run_attempt)
    require(sha(args.assets_archive) == args.assets_sha256, "Qualified asset archive changed during packaging")
    args.archive.with_suffix(args.archive.suffix + ".sha256").write_text(archive_sha + "  " + args.archive.name + "\n", encoding="utf-8")
    result = {"schema": "gentek80-final-package-assembly-v1", "status": "packaged-not-executed",
              "application_source_commit": args.published_source, "application_source_tree": args.published_tree,
              "native_build_commit": args.built_source, "native_sha256": published["sha256"],
              "archive": args.archive.name, "archive_sha256": archive_sha, "archive_bytes": args.archive.stat().st_size,
              "files": len(manifest["files_sha256"]), "asset_package_sha256": args.assets_sha256,
              "before": before, "after": after,
              "orchestration_commit": os.environ.get("GITHUB_SHA"), "orchestration_run": os.environ.get("GITHUB_RUN_ID")}
    write_json(args.receipt, result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidate", "bundle", "assets-archive", "output", "archive", "receipt"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("built-source", "published-source", "published-tree", "run-id", "run-attempt", "assets-sha256"):
        parser.add_argument("--" + name, required=True)
    print(json.dumps(create(parser.parse_args()), indent=2))


if __name__ == "__main__":
    main()
