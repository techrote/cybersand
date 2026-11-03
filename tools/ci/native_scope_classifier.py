#!/usr/bin/env python3
"""Conservative, source-bound advisory for a possible future Native CI scope gate.

This tool never permits skipping an existing required check. An empty diff,
ambiguous path, unrecognised extension, or Native-facing input fails closed.
Renames are represented by both paths using Git's --no-renames diff.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

DOC_EXACT = frozenset({
    "AGENTS.md", "README.md", "CONTRIBUTING.md",
    ".github/pull_request_template.md",
})
PRESENTATION_SUFFIXES = frozenset({
    ".gd", ".gdshader", ".tscn", ".tres", ".png", ".jpg",
    ".jpeg", ".webp", ".svg", ".json", ".tmx",
})
PRESENTATION_PREFIXES = (
    "godot/scripts/", "godot/tests/", "godot/shaders/",
    "godot/scenes/", "godot/maps/", "godot/levels/",
)
PLAY_TOOL_SUFFIXES = frozenset({".py", ".json", ".md"})
NATIVE_PREFIXES = (
    "native/", "native/include/", "native/src/", "native/tests/",
    "godot/native_extension/", "godot/addons/",
    "tools/physics/", "tools/experiments/", "third_party/",
)


def reason(path: str) -> str:
    """Classify tracked paths by the conservative Native test dependency boundary."""
    # Inspect the raw segments: PurePosixPath would erase an internal ".".
    if (not isinstance(path, str) or not path or path.startswith("/")
            or "\\" in path or any(ord(char) < 32 or ord(char) == 127 for char in path)
            or any(part in {"", ".", ".."} for part in path.split("/"))):
        return "unsafe-or-invalid"
    if path.startswith("docs/") or path in DOC_EXACT:
        return "documentation-only"
    if path == "Makefile" or path.startswith(NATIVE_PREFIXES):
        return "native-impact"
    if path == ".github/workflows/native.yml":
        return "native-impact"
    if path == "godot/project.godot":
        return "presentation-only"
    if path.startswith(PRESENTATION_PREFIXES):
        return ("presentation-only"
                if PurePosixPath(path).suffix.lower() in PRESENTATION_SUFFIXES
                else "unknown-requires-native")
    if path.startswith("tools/play/"):
        return ("presentation-only"
                if PurePosixPath(path).suffix.lower() in PLAY_TOOL_SUFFIXES
                else "unknown-requires-native")
    return "unknown-requires-native"


def classify(paths: list[str]) -> dict:
    if not isinstance(paths, list) or any(not isinstance(path, str) for path in paths):
        raise ValueError("Path inventory must be a list of strings")
    unique = sorted(set(paths))
    classes = {p: reason(p) for p in unique}
    non_native = {"documentation-only", "presentation-only"}
    has_duplicates = len(paths) != len(unique)
    # Duplicate or empty inventories are never considered sufficient for an exemption.
    safe = bool(unique) and not has_duplicates and set(classes.values()) <= non_native
    only_docs = safe and set(classes.values()) == {"documentation-only"}
    return {
        "schema": "cybersand-native-scope-advisory-v3",
        "files": unique,
        "file_classes": classes,
        "duplicate_paths": has_duplicates,
        "candidate_native_execution_needed": not safe,
        "candidate_exemption_kind": (
            "documentation-only" if only_docs
            else "presentation-only" if safe
            else "none"
        ),
        "existing_native_merge_gate_changed": False,
        "native_skip_authorized": False,
        "disposition": "ADVISORY_ONLY_NO_GATE_CHANGE",
    }


def selftest() -> None:
    cases = [
        (["docs/README.md", "AGENTS.md"], False, "documentation-only"),
        (["godot/scripts/main.gd", "godot/tests/test_play_ui005_session_selection.gd"], False, "presentation-only"),
        (["godot/scripts/main.gd", "docs/README.md", "tools/play/run_pace003_campaign.py"], False, "presentation-only"),
        (["godot/shaders/material_palette.gdshader"], False, "presentation-only"),
        (["godot/scripts/unexpected.cpp"], True, "none"),
        (["godot/tests/unknown.hex"], True, "none"),
        (["native/src/world.cpp"], True, "none"),
        (["native/tests/test_world.cpp", "godot/scripts/main.gd"], True, "none"),
        (["godot/native_extension/src/native.cpp"], True, "none"),
        (["godot/addons/cybersand_native/runtime-provenance.json"], True, "none"),
        (["tools/physics/test_characterisation_cli.py"], True, "none"),
        (["tools/experiments/test_stage3b_validation.py"], True, "none"),
        ([".github/workflows/native.yml"], True, "none"),
        ([".github/workflows/play-pace003-host.yml"], True, "none"),
        (["Makefile"], True, "none"),
        (["third_party/native-toolchain.lock.json"], True, "none"),
        (["foo/new_kind.bin"], True, "none"),
        ([], True, "none"),
        (["../unsafe.cpp"], True, "none"),
        (["godot/scripts/main.gd", "godot/scripts/main.gd"], True, "none"),
    ]
    for paths, required, kind in cases:
        actual = classify(paths)
        if (actual["candidate_native_execution_needed"] is not required
                or actual["candidate_exemption_kind"] != kind
                or actual["native_skip_authorized"] is not False
                or actual["existing_native_merge_gate_changed"] is not False):
            raise RuntimeError(f"Classification fixture failed: {paths!r}: {actual!r}")
    print(f"PASS: {len(cases)} conservative classification fixtures; no merge-gate bypass")



def git(*arguments: str) -> bytes:
    return subprocess.check_output(["git", *arguments], timeout=30)


def source_identity(base_sha: str, head_sha: str) -> dict:
    """Authenticate the actual classifier and a clean, immutable Git comparison."""
    for expected in (base_sha, head_sha):
        resolved = git("rev-parse", "--verify", expected + "^{commit}").decode().strip()
        if resolved != expected:
            raise ValueError("Base/head must identify actual commit objects")
    if git("rev-parse", "HEAD").decode().strip() != head_sha:
        raise ValueError("Refusing wrong source HEAD")
    if git("status", "--porcelain=v1", "-z", "--untracked-files=all"):
        raise ValueError("Refusing scope report from a changed or untracked worktree")
    root = Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
    source = Path(__file__).resolve()
    relative = source.relative_to(root).as_posix()
    actual = source.read_bytes()
    if git("show", head_sha + ":" + relative) != actual:
        raise ValueError("Executed classifier differs from its recorded source commit")
    return {
        "source_mode": "clean-checked-out-commit-diff",
        "base_sha": base_sha,
        "head_sha": head_sha,
        "base_tree": git("rev-parse", base_sha + "^{tree}").decode().strip(),
        "head_tree": git("rev-parse", head_sha + "^{tree}").decode().strip(),
        "classifier_path": relative,
        "classifier_sha256": hashlib.sha256(actual).hexdigest(),
        "worktree_clean": True,
        "diff_options": ["--name-only", "-z", "--no-renames"],
    }

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--base-sha")
    parser.add_argument("--head-sha")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        selftest()
        return 0
    if not args.base_sha or not args.head_sha or args.output is None:
        parser.error("--base-sha, --head-sha and --output are required")
    if not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (args.base_sha, args.head_sha)):
        parser.error("Base/head must be immutable 40-digit hexadecimal commit SHAs")
    before = source_identity(args.base_sha, args.head_sha)
    raw = git("diff", "--name-only", "-z", "--no-renames", args.base_sha, args.head_sha)
    paths = [path.decode("utf-8", "strict") for path in raw.split(b"\0") if path]
    result = classify(paths)
    if source_identity(args.base_sha, args.head_sha) != before:
        raise SystemExit("Source identity changed during scope classification")
    result.update(before)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
