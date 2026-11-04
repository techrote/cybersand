#!/usr/bin/env python3
"""Current, separately scoped MAT-AUTH proof identities.

These declarations describe the bounded authority transition. They do not
execute a consumer or upgrade metadata equality into application evidence.
Historical schema-v1 reports and their readers remain in retained Git history.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess


AUTHORITY_SCOPES = {
    "native_runtime": {
        "authority": "legacy-source",
        "production_cutover": False,
    },
    "complete_native_shadow": {
        "authority": "unconsumed-native-metadata",
        "production_cutover": False,
    },
    "main_display_names": {
        "authority": "generated-labels-only",
        "production_cutover": True,
        "consumer": "godot/scripts/main.gd::material_name(material_id: int) -> String",
        "resource": "godot/scripts/generated/material_ui_names.gd",
    },
}

B_CONSUMER_REQUIREMENT = {
    "mandatory": True,
    "schema_id": "cybersand.material-catalogue.display-consumer",
    "schema_version": 2,
    "status": "REQUIRED_SEPARATELY",
    "satisfied_by_this_report": False,
}

NATIVE_PROOF_SCOPE = "complete native-shadow metadata and unchanged native pure queries"
NATIVE_SOURCE_COMMIT_ROLE = "frozen legacy authority; checked_source identifies the current candidate"


class ProofScopeError(ValueError):
    """A current proof cannot bind its actual checked source."""


def _git(root: Path, arguments: list[str]) -> str:
    try:
        result = subprocess.run(["git", "-C", str(root), *arguments], check=True,
                                capture_output=True, text=True, encoding="utf-8", timeout=30)
    except (OSError, UnicodeError, subprocess.SubprocessError) as error:
        raise ProofScopeError(f"cannot identify checked source Git context: {error}") from error
    return result.stdout


def checked_source(root: Path, inventories: dict[str, list[dict]]) -> dict:
    """Bind exact checked bytes, with Git HEAD/tree as explicit context.

    The digest is scoped to the complete named inventories, not a claim about
    every file in a checkout. Working changes and new listed files are retained;
    HEAD is never substituted for the source bytes actually checked. External
    candidate inputs stay in the digest under their recorded absolute paths.
    """
    root = root.resolve()
    repository = Path(_git(root, ["rev-parse", "--show-toplevel"]).strip()).resolve()
    if repository != root:
        raise ProofScopeError("checked source must be the selected repository root")
    revisions = _git(root, ["rev-parse", "HEAD", "HEAD^{tree}"]).splitlines()
    if len(revisions) != 2 or any(not re.fullmatch(r"[0-9a-f]{40}", value) for value in revisions):
        raise ProofScopeError("checked source requires complete Git HEAD and tree identities")
    if (not isinstance(inventories, dict) or not inventories or
            any(type(group) is not str for group in inventories)):
        raise ProofScopeError("checked source requires nonempty named custody inventories")
    canonical = {}
    local_paths = set()
    for group, rows in sorted(inventories.items()):
        if not isinstance(group, str) or not isinstance(rows, list) or not rows:
            raise ProofScopeError("checked source requires nonempty named custody inventories")
        seen = set()
        for row in rows:
            if not isinstance(row, dict) or set(row) != {"path", "bytes", "sha256"}:
                raise ProofScopeError(f"{group}: malformed source fact")
            if (type(row["path"]) is not str or not row["path"] or
                    type(row["bytes"]) is not int or row["bytes"] < 0 or
                    type(row["sha256"]) is not str or not re.fullmatch(r"[0-9a-f]{64}", row["sha256"])):
                raise ProofScopeError(f"{group}: malformed source fact")
            if row["path"] in seen:
                raise ProofScopeError(f"{group}: duplicate source fact {row['path']}")
            seen.add(row["path"])
            path = Path(row["path"])
            if not path.is_absolute():
                if path.as_posix() != row["path"] or ".." in path.parts:
                    raise ProofScopeError(f"{group}: noncanonical source path {row['path']}")
                local_paths.add(row["path"])
        canonical[group] = sorted(rows, key=lambda row: row["path"])
    encoded = json.dumps(canonical, sort_keys=True, ensure_ascii=True,
                         separators=(",", ":"), allow_nan=False).encode("utf-8")
    # Restrict status to the checked inputs; unrelated documentation and report
    # files are not a source change for this scoped oracle. NUL preserves names.
    status = _git(root, ["status", "--porcelain=v1", "-z", "--untracked-files=all",
                         "--", *sorted(local_paths)]) if local_paths else ""
    return {
        "git_head": revisions[0],
        "git_head_tree": revisions[1],
        "scope": "exact listed input/tool/source bytes; not a full checkout or clean-tree claim",
        "inventories_sha256": hashlib.sha256(encoded).hexdigest(),
        "listed_worktree_changes": [entry for entry in status.split("\0") if entry],
    }
