#!/usr/bin/env python3
"""Enforce the active GitHub-hosted CI provider policy."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

GITHUB_HOSTED_LABEL = re.compile(r"^(?:ubuntu|windows|macos)-[A-Za-z0-9._-]+$")
FORBIDDEN_PROVIDER = re.compile(r"\b(?:avrea|sengi|circleci|circle[- ]?ci)\b", re.IGNORECASE)
RUNNER_INDIRECTION = re.compile(r"\b(?:vars\.)?[A-Za-z][A-Za-z0-9_]*_RUNNER\b")
RUNS_ON = re.compile(r"^\s*runs-on:\s*(.*?)\s*(?:#.*)?$")


def _workflow_paths(root: Path) -> list[Path]:
    directory = root / ".github" / "workflows"
    if not directory.is_dir():
        return []
    return sorted([*directory.glob("*.yml"), *directory.glob("*.yaml")])


def check(root: Path) -> dict[str, object]:
    root = root.resolve()
    errors: list[str] = []

    circle_config = root / ".circleci" / "config.yml"
    if circle_config.exists():
        errors.append("obsolete active CI config is present: .circleci/config.yml")

    for path in _workflow_paths(root):
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        for number, raw in enumerate(text.splitlines(), start=1):
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue

            if FORBIDDEN_PROVIDER.search(raw):
                errors.append(
                    f"{relative}:{number}: external CI/provider routing token is forbidden"
                )

            if RUNNER_INDIRECTION.search(raw):
                errors.append(
                    f"{relative}:{number}: *_RUNNER indirection is forbidden in active workflows"
                )

            match = RUNS_ON.match(raw)
            if match:
                label = match.group(1).strip().strip("\'\"")
                if not GITHUB_HOSTED_LABEL.fullmatch(label):
                    errors.append(
                        f"{relative}:{number}: runs-on must be a literal GitHub-hosted "
                        f"ubuntu/windows/macos label, found {label!r}"
                    )

    return {
        "status": "failed" if errors else "passed",
        "scope": "active CI provider and runner routing",
        "errors": errors,
        "policy": {
            "routine_provider": "GitHub-hosted Actions",
            "external_provider_config": "forbidden unless policy is explicitly changed",
            "runner_indirection": "forbidden",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    result = check(args.root)
    print(json.dumps(result, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
