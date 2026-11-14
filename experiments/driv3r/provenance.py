"""Exact source custody, explicit Stage A requests and immutable evidence packages.

Native build verification reuses #568's contract. This module only adds the
DRIV3R inputs and evidence inventory; a hash inventory is never an execution
receipt, and a packaged failed run remains a failed run.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

from experiments.agent_painter.native import runtime as shared_runtime

ROOT = Path(__file__).resolve().parents[2]
FOUNDATION = "2a565df45efc568eb96a2166e0b77f299e289625"
ACCEPTED_BASE = "ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742"
SOURCE_SCOPES = shared_runtime.SOURCE_SCOPES + [
    "experiments/driv3r", "godot/tests/run_driv3r_stage_a.gd",
    ".github/workflows/driv3r-stage-a.yml",
]
SOURCE_SUFFIXES = {".gd", ".tscn", ".godot", ".cpp", ".hpp", ".h", ".inc",
                   ".py", ".json", ".sh", ".yml", ".yaml", ".md"}
REQUEST_FIELDS = {
    "schema": "driv3r-stage-a-request-v1", "foundation_sha": FOUNDATION,
    "accepted_base": ACCEPTED_BASE, "model": "LiquidAI/d1-2B-GGUF",
    "quantization": "Q8_0", "stage": "A", "training": False,
    "schedules": False, "production_defaults": False,
    "publish_research_evidence": True,
}


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      allow_nan=False).encode("utf-8")


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as output:
        json.dump(value, output, indent=2, sort_keys=True, allow_nan=False)
        output.write("\n")


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args],
                                   text=True, timeout=60).strip()


def validate_request(data: object) -> dict:
    if not isinstance(data, dict) or set(data) != set(REQUEST_FIELDS) | {"sequence"}:
        raise ValueError("Stage A request fields differ from the frozen contract")
    for key, expected in REQUEST_FIELDS.items():
        if type(data[key]) is not type(expected) or data[key] != expected:
            raise ValueError("Unapproved Stage A request field: " + key)
    if type(data["sequence"]) is not int or not 1 <= data["sequence"] <= 1000:
        raise ValueError("Request sequence must be an integer in 1..1000")
    return dict(data)


def request(path: Path, source_sha: str, root: Path = ROOT) -> dict:
    data = validate_request(json.loads(path.read_text(encoding="utf-8")))
    if not re.fullmatch(r"[a-f0-9]{40}", source_sha) or git(root, "rev-parse", "HEAD") != source_sha:
        raise ValueError("Explicit request must run on its full checked-out source SHA")
    git(root, "merge-base", "--is-ancestor", FOUNDATION, source_sha)
    git(root, "merge-base", "--is-ancestor", ACCEPTED_BASE, source_sha)
    return {"schema": "driv3r-stage-a-request-receipt-v1", "request": data,
            "source_sha": source_sha, "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
            "request_sha256": digest(path), "workflow_run": os.environ.get("GITHUB_RUN_ID"),
            "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT")}


def source_identity(source_sha: str, root: Path = ROOT) -> dict:
    """Refuse dirty or untracked executable inputs, including this new adapter."""
    inherited = shared_runtime.source_identity(root, source_sha)
    git(root, "diff", "--exit-code", "HEAD", "--", *SOURCE_SCOPES)
    untracked = [name for name in git(root, "ls-files", "--others", "--exclude-standard",
                                    "--", *SOURCE_SCOPES).splitlines()
                 if Path(name).suffix in SOURCE_SUFFIXES]
    if untracked:
        raise ValueError("Untracked DRIV3R qualification inputs: " + ", ".join(untracked))
    inputs = {}
    for name in git(root, "ls-files", "--", *SOURCE_SCOPES).splitlines():
        path = root / name
        if path.suffix in SOURCE_SUFFIXES:
            if path.is_symlink():
                raise ValueError("Symlink in source inventory: " + name)
            inputs[name] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    for required in ("experiments/driv3r/provenance.py", "experiments/driv3r/pins.json",
                     "godot/tests/run_driv3r_stage_a.gd", ".github/workflows/driv3r-stage-a.yml"):
        if required not in inputs:
            raise ValueError("Incomplete DRIV3R source inventory: " + required)
    return {"schema": "driv3r-source-custody-v1", "source_sha": source_sha,
            "source_tree": inherited["source_tree"], "foundation_sha": FOUNDATION,
            "shared_source_inputs_sha256": inherited["source_inputs_sha256"],
            "source_inputs": inputs, "source_inputs_sha256": hashlib.sha256(canonical(inputs)).hexdigest()}


def runtime_custody(source_sha: str, native_manifest: Path, godot: Path,
                    root: Path = ROOT) -> dict:
    """Consume same-source build custody; never relabel retained diagnostics."""
    native = shared_runtime.verify(root, native_manifest, source_sha, godot)
    source = source_identity(source_sha, root)
    return {**source, "native": native,
            "claim": "Same-source native build and dependency custody; runtime tests supply execution evidence"}


def inventory(directory: Path) -> dict:
    """Hash all original evidence bytes, excluding reproducible local caches."""
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError("Evidence must be a real directory")
    entries = []
    ignored = {"__pycache__", ".godot", "userdata"}
    for path in sorted(directory.rglob("*")):
        relative = path.relative_to(directory)
        if any(part in ignored for part in relative.parts):
            continue
        if path.is_symlink():
            raise ValueError("Symlink in evidence: " + relative.as_posix())
        if not path.is_file():
            continue
        if path.stat().st_size > 256 * 1024 * 1024:
            raise ValueError("Unexpected heavyweight payload in evidence: " + relative.as_posix())
        entries.append({"path": relative.as_posix(), "bytes": path.stat().st_size,
                        "sha256": digest(path)})
    if not entries:
        raise ValueError("Empty evidence directory")
    return {"schema": "driv3r-evidence-inventory-v1", "files": entries,
            "files_sha256": hashlib.sha256(canonical(entries)).hexdigest()}


def verify_inventory(directory: Path, manifest: dict) -> None:
    if manifest != inventory(directory):
        raise ValueError("Evidence inventory differs from original bytes")


def package(directory: Path, output: Path, source_sha: str) -> dict:
    """Archive originals without converting workflow completion into a gate pass."""
    if not re.fullmatch(r"[a-f0-9]{40}", source_sha):
        raise ValueError("Full immutable source SHA required")
    if output.exists() or output.resolve().is_relative_to(directory.resolve()):
        raise ValueError("Publication refuses overwriting or nesting its evidence output")
    custody = json.loads((directory / "source-custody.json").read_text(encoding="utf-8"))
    if (custody.get("schema") != "driv3r-source-custody-v1"
            or custody.get("source_sha") != source_sha
            or not re.fullmatch(r"[a-f0-9]{40}", custody.get("source_tree", ""))
            or not isinstance(custody.get("source_inputs"), dict)
            or custody.get("source_inputs_sha256") != hashlib.sha256(canonical(custody["source_inputs"])).hexdigest()):
        raise ValueError("Evidence source custody differs from publication identity")
    evidence = inventory(directory)
    if any(row["path"] == "EVIDENCE-INVENTORY.json" for row in evidence["files"]):
        raise ValueError("Reserved evidence inventory path already exists")
    output.mkdir(parents=True)
    archive = output / ("driv3r-stage-a-" + source_sha[:12] + ".zip")
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as target:
        for row in evidence["files"]:
            path = directory / row["path"]
            if digest(path) != row["sha256"]:
                raise ValueError("Evidence changed while packaging: " + row["path"])
            target.write(path, row["path"])
        target.writestr("EVIDENCE-INVENTORY.json", json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    with zipfile.ZipFile(archive) as packaged:
        if packaged.testzip() is not None:
            raise ValueError("Evidence ZIP failed CRC verification")
        for row in evidence["files"]:
            content = packaged.read(row["path"])
            if len(content) != row["bytes"] or hashlib.sha256(content).hexdigest() != row["sha256"]:
                raise ValueError("Packaged evidence bytes differ: " + row["path"])
    entries = [{"file": archive.name, "bytes": archive.stat().st_size, "sha256": digest(archive)}]
    manifest = {"schema": "driv3r-stage-a-publication-v1", "source_sha": source_sha,
                "source_tree": custody["source_tree"],
                "foundation_sha": FOUNDATION, "accepted_base": ACCEPTED_BASE,
                "workflow_run": os.environ.get("GITHUB_RUN_ID"),
                "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
                "draft_hold": True, "publication_is_acceptance": False,
                "purpose": "Original bounded Stage A research evidence; consult execution reports for each gate",
                "evidence_files_sha256": evidence["files_sha256"], "assets": entries}
    write_json(output / "MANIFEST.json", manifest)
    with (output / "SHA256SUMS.txt").open("x", encoding="utf-8") as sums:
        sums.write("".join(row["sha256"] + "  " + row["file"] + "\n" for row in entries))
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    command = sub.add_parser("request")
    command.add_argument("--path", type=Path, default=Path(__file__).with_name("qualification-request.json"))
    command.add_argument("--source-sha", required=True)
    command.add_argument("--output", type=Path, required=True)
    command = sub.add_parser("source")
    command.add_argument("--source-sha", required=True)
    command.add_argument("--output", type=Path, required=True)
    command = sub.add_parser("package")
    command.add_argument("--directory", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    command.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    if args.command == "package":
        result = package(args.directory, args.output, args.source_sha)
    else:
        result = request(args.path, args.source_sha) if args.command == "request" else source_identity(args.source_sha)
        write_json(args.output, result)
    print(json.dumps({key: result.get(key) for key in ("schema", "source_sha", "source_tree")}, sort_keys=True))


if __name__ == "__main__":
    main()
