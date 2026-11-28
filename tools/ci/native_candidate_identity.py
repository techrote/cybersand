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
REUSE_NAME = "candidate-reuse-provenance.json"
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


def input_digest(inputs):
    payload = json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def create_reuse(root, directory, qualified_source, qualified_run, qualified_artifact):
    manifest = json.loads((directory / NAME).read_text(encoding="utf-8"))
    commit, tree, inputs = source(root)
    binary = directory / Path(NATIVE).name
    if (manifest.get("schema_version") != 1 or manifest.get("kind") != "source-built-windows-candidate"
            or manifest.get("artifact") != NATIVE
            or manifest.get("source_commit") != qualified_source
            or manifest.get("build_commit") != qualified_source
            or manifest.get("source_inputs") != inputs
            or not binary.read_bytes().startswith(b"MZ")
            or sha(binary) != manifest.get("sha256") or binary.stat().st_size != manifest.get("size")):
        raise ValueError("Qualified Windows candidate is not input-equivalent to current native source")
    reuse = {
        "schema_version": 1,
        "kind": "qualified-windows-candidate-input-equivalence",
        "artifact": NATIVE,
        "qualified_source_commit": qualified_source,
        "qualified_workflow_run": int(qualified_run),
        "qualified_artifact_id": int(qualified_artifact),
        "current_source_commit": commit,
        "current_source_tree": tree,
        "source_inputs_sha256": input_digest(inputs),
        "source_input_count": len(inputs),
        "sha256": manifest["sha256"],
        "size": manifest["size"],
        "claim": "Exact previously qualified Windows binary reused only because every native C/C++ input is byte-equivalent after LF normalization; application/test changes are requalified separately.",
    }
    (directory / REUSE_NAME).write_text(
        json.dumps(reuse, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return reuse


def verify(root, directory):
    manifest = json.loads((directory / NAME).read_text(encoding="utf-8"))
    commit, tree, inputs = source(root)
    binary = directory / Path(NATIVE).name
    binary_ok = (manifest.get("schema_version") == 1
                 and manifest.get("kind") == "source-built-windows-candidate"
                 and manifest.get("artifact") == NATIVE
                 and manifest.get("source_inputs") == inputs
                 and binary.read_bytes().startswith(b"MZ")
                 and sha(binary) == manifest.get("sha256")
                 and binary.stat().st_size == manifest.get("size"))
    if not binary_ok:
        raise ValueError("Windows candidate binary or native input identity mismatch")
    if (manifest.get("source_commit") == commit and manifest.get("build_commit") == commit
            and manifest.get("source_tree") == tree):
        return manifest
    reuse_path = directory / REUSE_NAME
    if not reuse_path.is_file():
        raise ValueError("Source-built Windows candidate identity mismatch; no explicit reuse receipt")
    reuse = json.loads(reuse_path.read_text(encoding="utf-8"))
    if (reuse.get("schema_version") != 1
            or reuse.get("kind") != "qualified-windows-candidate-input-equivalence"
            or reuse.get("artifact") != NATIVE
            or reuse.get("qualified_source_commit") != manifest.get("source_commit")
            or int(reuse.get("qualified_workflow_run", 0)) <= 0
            or int(reuse.get("qualified_artifact_id", 0)) <= 0
            or reuse.get("current_source_commit") != commit
            or reuse.get("current_source_tree") != tree
            or reuse.get("source_inputs_sha256") != input_digest(inputs)
            or reuse.get("source_input_count") != len(inputs)
            or reuse.get("sha256") != manifest.get("sha256")
            or reuse.get("size") != manifest.get("size")):
        raise ValueError("Qualified Windows candidate reuse receipt mismatch")
    return {
        **manifest,
        "source_commit": commit,
        "source_tree": tree,
        "reuse": reuse,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--create", action="store_true")
    group.add_argument("--create-reuse", action="store_true")
    parser.add_argument("--qualified-source")
    parser.add_argument("--qualified-run", type=int)
    parser.add_argument("--qualified-artifact", type=int)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.create_reuse:
        if not args.qualified_source or not args.qualified_run or not args.qualified_artifact:
            parser.error("--create-reuse requires --qualified-source, --qualified-run and --qualified-artifact")
        result = create_reuse(
            root, args.directory, args.qualified_source, args.qualified_run, args.qualified_artifact)
        print(result["current_source_commit"], result["sha256"])
    else:
        result = create(root, args.directory) if args.create else verify(root, args.directory)
        print(result["source_commit"], result["sha256"])
