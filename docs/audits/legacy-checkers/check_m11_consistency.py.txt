#!/usr/bin/env python3
"""Fail closed when M11 identity, dependency, or documentation claims drift."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
EXPECTED_BUILD = "m11-audit-remediation-render-handoff-water-native-repro-2026-08-28"
EXPECTED_SOURCE = "05ea45fda7bdd7b0150eb86c4922c202e89e08f4"
EXPECTED_GODOT = "4.7.stable.official.5b4e0cb0f"
EXPECTED_GODOT_CPP = "101ae38034304346a46ea9ea84ae156d3e860496"
EXPECTED_RAPIER = "v0.35.2"
ALLOWED_FRONTMATTER_STATUS = {"Current", "Approved design", "Planned", "Ambiguous"}


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(relative: str) -> dict:
    path = ROOT / relative
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AssertionError(f"cannot read {relative}: {exc}") from exc


def check_source_hashes(errors: list[str]) -> None:
    build_id = (ROOT / "docs/BUILD_ID.md").read_text(encoding="utf-8")
    records = re.findall(r"^\| `([^`]+)` \| `([0-9a-f]{64})` \|$", build_id, re.MULTILINE)
    if len(records) != 28:
        errors.append(f"BUILD_ID source hash table has {len(records)} records, expected 28")
    for relative, expected in records:
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"BUILD_ID source is missing: {relative}")
        elif sha256(path) != expected:
            errors.append(f"BUILD_ID source hash changed: {relative}")


def check_markdown(errors: list[str]) -> None:
    stale = {
        "docs/decisions/ADR-001-native-simulation-core.md": [
            "current Godot and native simulations remain separate",
            "CyberCellWorld powers the Godot proof",
            "The decision is not implemented",
        ],
        "docs/decisions/ADR-002-double-buffered-tile-jobs.md": [
            "The runnable Godot proof is not bridged to it",
        ],
        "docs/architecture/module-boundaries.md": [
            "no bridge coordinates the two",
        ],
        "docs/decisions/ADR-007-rigid-body-cellular-coupling.md": [
            "the native bridge and generalized production implementation",
            "generalized/native coupling remains",
        ],
    }
    for path in sorted((ROOT / "docs").rglob("*.md")):
        relative = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        is_retained_evidence = relative.startswith("docs/audits/") and not relative.endswith("/README.md")
        if not is_retained_evidence:
            match = re.search(r"^status: (.+)$", text, re.MULTILINE)
            if not match:
                errors.append(f"documentation frontmatter has no status: {relative}")
            elif match.group(1) not in ALLOWED_FRONTMATTER_STATUS:
                errors.append(f"unsupported frontmatter status in {relative}: {match.group(1)}")

        for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
            clean = target.split("#", 1)[0]
            if not clean or "://" in clean or clean.startswith(("mailto:", "res://")):
                continue
            resolved = (path.parent / clean).resolve()
            try:
                resolved.relative_to(ROOT)
            except ValueError:
                errors.append(f"documentation link escapes repository: {relative} -> {target}")
                continue
            if not resolved.exists():
                errors.append(f"broken documentation link: {relative} -> {target}")

        for phrase in stale.get(relative, []):
            if phrase in text:
                errors.append(f"stale pre-M11 claim in {relative}: {phrase}")


def main() -> int:
    errors: list[str] = []

    checkpoint = load_json("docs/audits/m11/checkpoint.json")
    migration = load_json("docs/audits/m11/migration-source.json")
    native = load_json("third_party/native-toolchain.lock.json")
    godot = load_json("third_party/godot-runtime.lock.json")
    rapier = load_json("godot/third_party/rapier2d.lock.json")
    validation = load_json("docs/audits/m11/validation-summary.json")

    if checkpoint.get("source_baseline_commit") != EXPECTED_SOURCE:
        errors.append("checkpoint source baseline differs from audited M11")
    if checkpoint.get("build_id") != EXPECTED_BUILD:
        errors.append("checkpoint build ID differs from audited M11")
    if checkpoint.get("expected_godot") != EXPECTED_GODOT:
        errors.append("checkpoint Godot version differs from audited M11")
    source = migration.get("authoritative_source", {})
    if source.get("source_commit") != EXPECTED_SOURCE or source.get("build_id") != EXPECTED_BUILD:
        errors.append("migration source record differs from audited M11")
    if migration.get("historical_archives_used_as_source") is not False:
        errors.append("migration source record does not exclude historical archives")
    if godot.get("godot_version") != EXPECTED_GODOT:
        errors.append("Godot runtime lock differs from audited M11")
    if rapier.get("rapier_tag") != EXPECTED_RAPIER:
        errors.append("Rapier lock differs from audited M11")

    godot_cpp = next((item for item in native.get("artifacts", []) if item.get("name") == "godot-cpp"), None)
    if not godot_cpp or godot_cpp.get("version") != EXPECTED_GODOT_CPP:
        errors.append("godot-cpp commit differs from audited M11")

    counts = validation.get("counts", {})
    expected_counts = {"passed": 34, "failed": 0, "timed-out": 0, "inconclusive": 1, "skipped": 0}
    if counts != expected_counts:
        errors.append(f"retained validation counts changed: {counts}")

    build_text = (ROOT / "docs/BUILD_ID.md").read_text(encoding="utf-8")
    for value in (EXPECTED_BUILD, EXPECTED_GODOT, EXPECTED_GODOT_CPP, "v0.35.2"):
        if value not in build_text:
            errors.append(f"BUILD_ID omits pinned value: {value}")

    project = (ROOT / "godot/project.godot").read_text(encoding="utf-8")
    for setting in (
        "window/size/viewport_width=1920",
        "window/size/viewport_height=1080",
        "window/size/window_width_override=1920",
        "window/size/window_height_override=1080",
    ):
        if setting not in project:
            errors.append(f"Godot project setting missing: {setting}")

    required = [
        "THIRD_PARTY_NOTICES.md",
        "LICENSE_STATUS.md",
        "godot/addons/godot-rapier2d/LICENSE",
        "godot/addons/godot-rapier2d/THIRDPARTY.txt",
        "godot/addons/cybersand_native/LICENSE-godot-cpp.md",
        "godot/.godot/.gdignore",
        "godot/.godot/extension_list.cfg",
        "godot/.godot/global_script_class_cache.cfg",
    ]
    for relative in required:
        if not (ROOT / relative).is_file():
            errors.append(f"required provenance/bootstrap file missing: {relative}")

    check_source_hashes(errors)
    check_markdown(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("M11 identity, dependency pins, source hashes, documentation links/statuses, and bootstrap files are consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
