#!/usr/bin/env python3
"""Compose the accepted portable Materials Lab stack for the integrated evaluator.

The application keeps its already published native runtime.  This helper copies
only the existing offline authoring tools and a fresh HEAD-only compatibility
repository; the combined packager owns application, engine and archive custody.
"""
from __future__ import annotations

import hashlib
import importlib.util
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_materials_lab_candidate as lab
import portable_compiler_utf8
from package_wave_flow_candidate import REGENERATED_RAPIER_IMPORTS

WINDOWS_LFS = frozenset({
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
    "godot/tools/gentek_reciprocal.exe",
})
LFS_POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n")
HISTORY_SCOPE = "self-contained HEAD ancestry; no original checkout configuration"
PORTABLE_SOURCE_REF = "refs/heads/portable-source"
TOOL_PATHS = {"python": "python/python.exe", "git": "git/cmd/git.exe", "compiler": "cxx/bin/g++.exe"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def blob_oid(path: Path) -> str:
    result = hashlib.sha1(b"blob " + str(path.stat().st_size).encode() + b"\0")
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def relative(name: str) -> str:
    require(isinstance(name, str), "Source path must be a string")
    path = PurePosixPath(name)
    require(name and not path.is_absolute()
            and not any(part in ("", ".", "..") for part in name.split("/"))
            and "\\" not in name and ":" not in name and "\0" not in name,
            "Unsafe source-relative path")
    return name


def git(root: Path, *args: str, executable=None) -> bytes:
    try:
        return subprocess.check_output([str(executable or "git"), "-C", str(root), *args],
                                       env=lab.clean_git_environment(), timeout=300,
                                       stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as error:
        raw = error.stderr or b""
        detail = raw[:4096].decode("utf-8", errors="replace").strip()
        if len(raw) > 4096:
            detail += " [stderr truncated]"
        operation = args[0] if args else "<no operation>"
        raise RuntimeError("Portable source Git command failed (exit " + str(error.returncode)
                           + ", " + operation + "): " + detail) from error


def inventory(root: Path, *, git_executable=None) -> dict[str, str]:
    result = {}
    for entry in git(root, "ls-tree", "-rz", "HEAD", executable=git_executable).split(b"\0"):
        if not entry:
            continue
        metadata, raw_name = entry.split(b"\t", 1)
        mode, kind, oid = metadata.decode("ascii").split()
        name = relative(raw_name.decode("utf-8"))
        require(kind == "blob" and mode in ("100644", "100755"), "Linked/non-file source is not portable: " + name)
        require(name not in result and ".git" not in name.split("/"), "Ambiguous source path")
        result[name] = oid
    require(result and len(result) == len({name.casefold() for name in result}), "Missing/case-ambiguous source inventory")
    return result


def stage_source(repository: Path, source_commit: str, destination: Path) -> dict:
    """Retain only HEAD ancestry and canonical committed bytes, with no remotes."""
    history = lab.clean_source_repository(repository, source_commit, destination)
    # A detached HEAD-only clone can have an empty refs directory. Git requires
    # that directory, but the portable archive deliberately contains only files.
    # One exact loose ref preserves it without adding history or a reflog.
    git(destination, "-c", "core.logAllRefUpdates=false", "update-ref", PORTABLE_SOURCE_REF, source_commit)
    original = inventory(destination)
    # Checkout/archive conversion honors explicit eol=crlf even when autocrlf is
    # disabled. Restore changed files from immutable blobs, never from the donor
    # working tree. Binary art and all LFS pointers are compared identically.
    for name, oid in original.items():
        target = destination / name
        require(target.is_file() and not target.is_symlink(), "Missing real committed file: " + name)
        if blob_oid(target) != oid:
            target.write_bytes(git(destination, "cat-file", "blob", oid))
        require(blob_oid(target) == oid, "Canonical source copy differs from Git: " + name)
    record = {"schema": "ramcache-strata-lab-source-v1", "source_commit": source_commit,
              "source_tree": git(destination, "rev-parse", "HEAD^{tree}").decode().strip(),
              "source_history": history, "original_files": original}
    verify_source(destination, record, expected_source=source_commit, expected_tree=record["source_tree"],
                  materialized_lfs={})
    return record


def verify_source(source: Path, record: dict, *, expected_source: str, expected_tree: str,
                  materialized_lfs: dict, omitted_files: dict | None = None, git_executable=None) -> dict:
    """Authenticate all committed blobs; Godot's new untracked imports may exist.

    Only the caller's exact Windows LFS materializations and the existing four
    hash-pinned Rapier import descriptors can differ. Runtime manifests receive
    no exemption. The outer evaluator manifest authenticates every pristine file,
    including this repository's object database and the copied dependencies.
    """
    source = source.resolve(strict=True)
    omitted_files = omitted_files or {}
    require(record.get("schema") == "ramcache-strata-lab-source-v1"
            and record.get("source_commit") == expected_source and record.get("source_tree") == expected_tree,
            "Portable authoring source identity mismatch")
    history = record.get("source_history", {})
    require(history.get("source_commit") == expected_source and history.get("scope") == HISTORY_SCOPE
            and re.fullmatch(r"[0-9a-f]{64}", str(history.get("bundle_sha256", ""))) is not None
            and isinstance(history.get("bundle_bytes"), int) and history["bundle_bytes"] > 0,
            "Missing HEAD-only source history receipt")
    dotgit = source / ".git"
    require(dotgit.is_dir() and not dotgit.is_symlink(), "Portable source needs its own real Git database")
    for path in source.rglob("*"):
        require(not path.is_symlink(), "Portable source contains a symbolic link: " + str(path.relative_to(source)))
    anchor = dotgit / PORTABLE_SOURCE_REF
    require(anchor.is_file(), "Portable source needs its exact loose reference: " + PORTABLE_SOURCE_REF)
    require(anchor.read_bytes() == (expected_source + "\n").encode("ascii"),
            "Portable source loose reference differs from qualified source")
    require((dotgit / "HEAD").is_file()
            and (dotgit / "HEAD").read_bytes() == (expected_source + "\n").encode("ascii"),
            "Portable source HEAD must remain detached at qualified source")
    for name in ("objects/info/alternates", "objects/info/http-alternates", "shallow", "info/grafts"):
        require(not (dotgit / name).exists(), "Portable history depends on external/replaced objects: " + name)
    require(not (dotgit / "hooks").exists(), "Portable source must not retain hooks")
    require(not git(source, "remote", executable=git_executable).strip(), "Portable source retained a remote URL")
    require(not git(source, "for-each-ref", "refs/replace", executable=git_executable).strip(), "Replaced Git history refused")
    require(git(source, "rev-parse", "--is-shallow-repository", executable=git_executable).strip() == b"false",
            "Portable compatibility history is shallow")
    require(git(source, "rev-parse", "HEAD", executable=git_executable).decode().strip() == expected_source
            and git(source, "rev-parse", "HEAD^{tree}", executable=git_executable).decode().strip() == expected_tree,
            "Delivered Git HEAD/tree differs from qualified source")
    # Local config comes from a new bundle clone, never the developer checkout.
    # Reject injected source/execution/credential configuration on replay.
    configuration = git(source, "config", "--local", "--null", "--list", executable=git_executable)
    allowed_config = {"core.repositoryformatversion", "core.filemode", "core.bare", "core.logallrefupdates",
                      "core.autocrlf", "core.longpaths", "core.ignorecase", "core.symlinks"}
    for entry in configuration.split(b"\0"):
        if entry:
            key, _value = entry.split(b"\n", 1)
            require(key.decode().lower() in allowed_config, "Unexpected portable Git configuration: " + key.decode())
    original = inventory(source, git_executable=git_executable)
    require(record.get("original_files") == original, "Portable source inventory differs from committed tree")
    require(set(materialized_lfs) <= WINDOWS_LFS and set(materialized_lfs) <= set(original),
            "Unreviewed source materialization")
    require(set(omitted_files) <= set(REGENERATED_RAPIER_IMPORTS) and set(omitted_files) <= set(original)
            and all(value == REGENERATED_RAPIER_IMPORTS[name] for name, value in omitted_files.items()),
            "Unreviewed committed-source omission")
    for name, oid in original.items():
        target = source / name
        if name in omitted_files:
            original_bytes = git(source, "cat-file", "blob", oid, executable=git_executable)
            require(hashlib.sha256(original_bytes).hexdigest() == omitted_files[name],
                    "Regenerated import no longer matches reviewed source: " + name)
            require(target.with_suffix("").is_file(), "Regenerated import lost its source image: " + name)
            require(not target.exists() or target.is_file(), "Regenerated import is not a regular file")
            continue
        require(target.is_file(), "Missing committed source: " + name)
        if name in materialized_lfs:
            pointer = LFS_POINTER.fullmatch(git(source, "cat-file", "blob", oid, executable=git_executable))
            require(pointer is not None, "Materialized file lacks an exact committed LFS pointer: " + name)
            identity = {"sha256": pointer[1].decode(), "size": int(pointer[2])}
            require(materialized_lfs[name] == identity and target.stat().st_size == identity["size"]
                    and sha(target) == identity["sha256"], "Materialized runtime differs from Git LFS: " + name)
        else:
            require(blob_oid(target) == oid, "Committed portable source changed: " + name)
    # Connectivity checks the retained compatibility history without re-hashing
    # the entire object database on every post-launch replay. The pristine
    # package inventory separately hashes all delivered Git database bytes.
    require(not git(source, "fsck", "--connectivity-only", "--no-reflogs", "--unreachable",
                    executable=git_executable).strip(), "Portable history contains unreachable objects")
    for target in set(git(source, "for-each-ref", "--format=%(objectname)",
                          executable=git_executable).decode().split()):
        git(source, "merge-base", "--is-ancestor", target, "HEAD", executable=git_executable)
    return {"source_commit": expected_source, "source_tree": expected_tree,
            "tracked_files": len(original), "materialized_lfs": len(materialized_lfs),
            "regenerated_imports": len(omitted_files),
            "history_commits": int(git(source, "rev-list", "--count", "HEAD", executable=git_executable)),
            "remote_count": 0}


def dependency_environment(package: Path) -> dict[str, str]:
    return lab.dependency_environment(package)


def dependency_identity(destination: Path, *, execute: bool) -> dict:
    """Bind the existing copied distributions, tool entry points and notices."""
    require(destination.is_dir() and not destination.is_symlink(), "Missing offline dependencies")
    for path in destination.rglob("*"):
        require(not path.is_symlink(), "Portable dependency contains a symbolic link")
    require((destination / "python/Lib/json").is_dir() and (destination / "python/DLLs").is_dir(),
            "Incomplete portable Python standard library")
    prefixes = [name for name in ("mingw64", "ucrt64") if (destination / "git" / name / "bin/git.exe").is_file()]
    require(len(prefixes) == 1 and (destination / "git" / prefixes[0] / "share/licenses").is_dir(),
            "Incomplete or ambiguous portable Git distribution")
    if prefixes[0] == "mingw64":
        require((destination / "git/mingw64/libexec").is_dir(), "Missing legacy portable Git helpers")
    notices = {path.relative_to(destination).as_posix(): sha(path) for path in sorted(destination.rglob("*"))
               if path.is_file() and any(part.lower().startswith(("copying", "license"))
                                        for part in path.relative_to(destination).parts)}
    require("python/LICENSE.txt" in notices and "git/LICENSE.txt" in notices
            and any(name.startswith("git/" + prefixes[0] + "/share/licenses/") for name in notices)
            and any(name.startswith("cxx/") for name in notices), "Missing portable dependency license notices")
    tools = {}
    for name, relative_path in TOOL_PATHS.items():
        path = destination / relative_path
        require(path.is_file() and not path.is_symlink(), "Missing offline authoring tool: " + relative_path)
        item = {"path": relative_path, "sha256": sha(path), "bytes": path.stat().st_size}
        if execute:
            result = subprocess.run([str(path), "--version"], check=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=30,
                                    env=dependency_environment(destination.parent))
            version = result.stdout.decode("utf-8", errors="strict").strip()
            require(version and len(version) < 16384, "Missing/unbounded portable tool version")
            item["version"] = version
        tools[name] = item
    record = {"schema": "ramcache-strata-offline-lab-tools-v1", "tools": tools,
              "git_native_prefix": prefixes[0], "licenses_sha256": notices,
              "scope": "offline candidate compilation; published application runtime unchanged"}
    # Older immutable evaluators retain their original identity shape. Every
    # newly staged toolchain below receives a source-bound UTF-8 resource
    # receipt; archive verification also authenticates its derived executables.
    if (destination / "cxx/CYBERSAND-COMPILER-UTF8.json").is_file():
        record["compiler_utf8"] = portable_compiler_utf8.verify(
            destination / "cxx", execute=execute and os.name == "nt")
    return record


def _ignore_compiler_python_cache(directory: str, names: list[str]) -> set[str]:
    """Omit only reproducible embedded-Python caches from the runner's compiler.

    The hosted image already contains GDB's embedded-Python bytecode caches.
    Keep the corresponding modules and the entire licensed toolchain; an unusual
    cache entry or a sourceless module must refuse instead of disappearing.
    """
    if "__pycache__" not in names:
        return set()
    cache = Path(directory) / "__pycache__"
    require(cache.is_dir() and not cache.is_symlink(),
            "Compiler Python cache is not a real directory: " + str(cache))
    for path in cache.iterdir():
        require(path.is_file() and not path.is_symlink() and path.suffix == ".pyc",
                "Unexpected compiler Python cache entry: " + str(path))
        try:
            source = Path(importlib.util.source_from_cache(str(path)))
        except ValueError as error:
            raise RuntimeError("Unrecognized compiler Python cache: " + str(path)) from error
        require(source.parent == cache.parent and source.is_file() and not source.is_symlink(),
                "Compiler Python cache lacks its retained module: " + str(path))
    return {"__pycache__"}


def stage_dependencies(destination: Path, *, python_root: Path = Path(sys.base_prefix),
                       git_root: Path = Path(r"C:\Program Files\Git"),
                       compiler_root: Path = Path(r"C:\mingw64")) -> dict:
    require(os.name == "nt", "Stage the offline Windows tools on the Windows package runner")
    require(not destination.exists(), "Refuse to overwrite offline dependency destination")
    destination.mkdir(parents=True)
    lab.copy_python(python_root, destination / "python")
    lab.copy_git(git_root, destination / "git")
    lab.copy_portable_tree(compiler_root, destination / "cxx", ignore=_ignore_compiler_python_cache)
    portable_compiler_utf8.prepare(destination / "cxx")
    record = dependency_identity(destination, execute=True)
    require("compiler_utf8" in record, "New portable compiler lacks UTF-8 resource custody")
    return record


def verify_dependencies(destination: Path, record: dict, *, execute: bool = True) -> dict:
    observed = dependency_identity(destination, execute=execute)
    expected = record
    if not execute:
        # Cross-platform archive readers may authenticate executable bytes, but
        # only the Windows extracted run can independently reproduce versions.
        expected = {**record, "tools": {key: {k: v for k, v in value.items() if k != "version"}
                                       for key, value in record.get("tools", {}).items()}}
    require(observed == expected, "Portable authoring dependency identity changed")
    return observed
