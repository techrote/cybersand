"""Bind a separately built Windows candidate to the exact checked-out source.

Candidate manifests never replace the committed retained-runtime provenance.
Custody is supplied by the same-run Actions artifact producer/consumer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

NAME = "candidate-provenance.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source(root):
    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args], timeout=60).decode().strip()
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
    git("diff", "--exit-code", "HEAD", "--", "native/include", "native/src", "godot/native_extension")
    tracked = set(git("ls-files", "--", "native/include", "native/src", "godot/native_extension").splitlines())
    inputs = {}
    for directory in ("native/include", "native/src", "godot/native_extension"):
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and path.suffix in suffixes:
                if path.relative_to(root).as_posix() not in tracked:
                    raise ValueError("Untracked native candidate source: " + str(path))
                inputs[path.relative_to(root).as_posix()] = hashlib.sha256(
                    path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    if not inputs:
        raise ValueError("Missing native candidate inputs")
    return git("rev-parse", "HEAD"), git("rev-parse", "HEAD^{tree}"), inputs


def create(root, directory):
    commit, tree, inputs = source(root)
    binary = directory / Path(NATIVE).name
    if not binary.read_bytes().startswith(b"MZ"):
        raise ValueError("Candidate is not a Windows PE runtime")
    manifest = {"schema_version": 1, "kind": "source-built-windows-candidate",
                "artifact": NATIVE, "source_commit": commit, "build_commit": commit,
                "source_tree": tree, "source_inputs": inputs,
                "sha256": sha(binary), "size": binary.stat().st_size}
    (directory / NAME).write_text(json.dumps(manifest, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    return manifest


def verify(root, directory):
    manifest = json.loads((directory / NAME).read_text(encoding="utf-8"))
    commit, tree, inputs = source(root)
    binary = directory / Path(NATIVE).name
    if (manifest.get("schema_version") != 1 or manifest.get("kind") != "source-built-windows-candidate"
            or manifest.get("artifact") != NATIVE or manifest.get("source_commit") != commit
            or manifest.get("build_commit") != commit or manifest.get("source_tree") != tree
            or manifest.get("source_inputs") != inputs or not binary.read_bytes().startswith(b"MZ")
            or sha(binary) != manifest.get("sha256") or binary.stat().st_size != manifest.get("size")):
        raise ValueError("Source-built Windows candidate identity mismatch")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--create", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    result = create(root, args.directory) if args.create else verify(root, args.directory)
    print(result["source_commit"], result["sha256"])
