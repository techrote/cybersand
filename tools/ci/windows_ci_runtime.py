#!/usr/bin/env python3
"""Build and independently verify a current-run Windows GDExtension artifact.

The retained Git LFS DLL is an immutable release asset, not the DLL built for
every pull request.  This receipt binds a same-run CI-produced DLL to its exact
source tree, complete native build-input inventory and Actions run identity.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
DLL_NAME = Path(NATIVE).name
RECEIPT_NAME = "runtime-provenance.json"
PROVENANCE_PATH = "build/windows-runtime/runtime-provenance.json"
RECEIPT_KEYS = frozenset({
    "schema_version", "artifact", "source_commit", "build_commit",
    "source_tree", "run_id", "attempt", "sha256", "size", "source_inputs",
})


def require(ok: bool, why: str) -> None:
    if not ok:
        raise RuntimeError("Windows CI runtime provenance: " + why)


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), *args], timeout=120,
    ).decode("utf-8").strip()


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def native_input_paths(root: Path) -> set[str]:
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp",
                ".hxx", ".inc", ".inl", ".tpp"}
    return {
        path.relative_to(root).as_posix()
        for directory in ("native/include", "native/src", "godot/native_extension")
        for path in (root / directory).rglob("*")
        if path.is_file() and path.suffix in suffixes
    }


def current_inputs(root: Path) -> dict[str, str]:
    paths = native_input_paths(root)
    require(bool(paths), "no native build inputs")
    native_roots = ("native/include", "native/src", "godot/native_extension")
    tracked = subprocess.check_output(
        ["git", "-C", str(root), "ls-files", "-z", "--", *native_roots],
        timeout=120,
    ).decode("utf-8").split("\0")
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp",
                ".hxx", ".inc", ".inl", ".tpp"}
    expected = {name for name in tracked if name and Path(name).suffix in suffixes}
    require(paths == expected, "uncommitted or missing native source input")
    clean = subprocess.run(
        ["git", "-C", str(root), "diff", "--quiet", "HEAD", "--", *native_roots],
        timeout=120, check=False,
    )
    require(clean.returncode == 0, "native source differs from tested commit")
    return {
        path: digest((root / path).read_bytes().replace(b"\r\n", b"\n"))
        for path in sorted(paths)
    }


def write_bundle(root: Path, dll: Path, directory: Path, *,
                 source_sha: str, run_id: str, attempt: str) -> dict:
    require(git(root, "rev-parse", "HEAD") == source_sha,
            "build checkout SHA is not the requested source")
    require(bool(run_id) and bool(attempt), "missing Actions run identity")
    require(dll.is_file() and not dll.is_symlink(), "build DLL missing or symlinked")
    data = dll.read_bytes()
    require(data.startswith(b"MZ") and len(data) > 1024,
            "build artifact is not a real Windows PE DLL")
    receipt = {
        "schema_version": 2, "artifact": NATIVE,
        "source_commit": source_sha, "build_commit": source_sha,
        "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
        "run_id": str(run_id), "attempt": str(attempt),
        "sha256": digest(data), "size": len(data),
        "source_inputs": current_inputs(root),
    }
    directory.mkdir(parents=True, exist_ok=True)
    require(not (directory / DLL_NAME).is_symlink() and
            not (directory / RECEIPT_NAME).is_symlink(),
            "refusing to replace symlinked runtime evidence")
    shutil.copyfile(dll, directory / DLL_NAME)
    (directory / RECEIPT_NAME).write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify_bundle(root, directory, source_sha=source_sha,
                  run_id=run_id, attempt=attempt)
    return receipt


def verify_bundle(root: Path, directory: Path, *,
                  source_sha: str, run_id: str, attempt: str) -> tuple[dict, bytes]:
    require(bool(run_id) and bool(attempt), "missing expected Actions identity")
    require(git(root, "rev-parse", "HEAD") == source_sha,
            "verifying checkout SHA differs from requested source")
    manifest_path = directory / RECEIPT_NAME
    dll_path = directory / DLL_NAME
    require(manifest_path.is_file() and not manifest_path.is_symlink()
            and dll_path.is_file() and not dll_path.is_symlink(),
            "missing or symlinked same-run runtime artifact")
    raw = manifest_path.read_bytes()
    manifest = json.loads(raw)
    require(isinstance(manifest, dict) and set(manifest) == RECEIPT_KEYS
            and manifest["schema_version"] == 2
            and manifest["artifact"] == NATIVE
            and manifest["source_commit"] == source_sha
            and manifest["build_commit"] == source_sha
            and manifest["source_tree"] == git(root, "rev-parse", "HEAD^{tree}")
            and manifest["run_id"] == str(run_id)
            and manifest["attempt"] == str(attempt),
            "source, schema, tree or run identity mismatch")
    inputs = manifest["source_inputs"]
    require(isinstance(inputs, dict) and inputs == current_inputs(root),
            "incomplete or stale native source input digests")
    data = dll_path.read_bytes()
    require(data.startswith(b"MZ") and len(data) > 1024
            and type(manifest["size"]) is int and manifest["size"] == len(data)
            and manifest["sha256"] == digest(data),
            "compiled DLL bytes differ from source-bound receipt")
    return manifest, raw


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("create", "verify"))
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--native", type=Path)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--attempt", required=True)
    args = parser.parse_args()
    if args.operation == "create":
        require(args.native is not None, "create requires --native")
        write_bundle(ROOT, args.native, args.directory, source_sha=args.source_sha,
                     run_id=args.run_id, attempt=args.attempt)
    else:
        verify_bundle(ROOT, args.directory, source_sha=args.source_sha,
                      run_id=args.run_id, attempt=args.attempt)
    print("WINDOWS_CI_RUNTIME_PROVENANCE PASS", flush=True)


if __name__ == "__main__":
    main()
