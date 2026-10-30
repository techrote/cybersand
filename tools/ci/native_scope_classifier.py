#!/usr/bin/env python3
"""Conservative, source-bound advisory for a possible future Native CI scope gate.

This tool never permits skipping an existing required check. An empty diff,
ambiguous path, unrecognised extension, or Native-facing input fails closed.
Renames are represented by both paths using Git's --no-renames diff.
"""
from __future__ import annotations

import argparse
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
    parts = PurePosixPath(path).parts
    if (not path or path.startswith("/") or "\\" in path
            or "//" in path or path.endswith("/")
            or "." in parts or ".." in parts):
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
    unique = sorted(set(paths))
    classes = {p: reason(p) for p in unique}
    non_native = {"documentation-only", "presentation-only"}
    has_duplicates = len(paths) != len(unique)
    # Duplicate or empty inventories are never considered sufficient for an exemption.
    safe = bool(unique) and not has_duplicates and set(classes.values()) <= non_native
    only_docs = safe and set(classes.values()) == {"documentation-only"}
    return {
        "schema": "cybersand-native-scope-advisory-v2",
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
        assert actual["candidate_native_execution_needed"] is required, (paths, actual)
        assert actual["candidate_exemption_kind"] == kind, (paths, actual)
        assert actual["native_skip_authorized"] is False
    print(f"PASS: {len(cases)} conservative classification fixtures; no merge-gate bypass")


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
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if source != args.head_sha:
        raise SystemExit("Refusing wrong source HEAD")
    raw = subprocess.check_output([
        "git", "diff", "--name-only", "-z", "--no-renames", args.base_sha, args.head_sha
    ])
    paths = [p.decode("utf-8", "strict") for p in raw.split(b"\0") if p]
    result = classify(paths)
    result.update({"base_sha": args.base_sha, "head_sha": args.head_sha})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
