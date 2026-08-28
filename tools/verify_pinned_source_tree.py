#!/usr/bin/env python3
"""Create or verify the canonical ledger for the pinned godot-cpp source."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re


LINE = re.compile(r"^([0-9a-f]{64})  ([^\\]+)$")
LEDGER_NAME = ".cybersand-source-files.sha256"


def hash_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_member(root: pathlib.Path, relative: str) -> pathlib.Path:
    pure = pathlib.PurePosixPath(relative)
    if (
        not relative
        or "\\" in relative
        or pure.is_absolute()
        or pure.as_posix() != relative
        or "." in pure.parts
        or ".." in pure.parts
    ):
        raise SystemExit(f"unsafe source-ledger path: {relative!r}")
    target = (root / pathlib.Path(*pure.parts)).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise SystemExit(f"source-ledger path escapes root: {relative!r}") from exc
    return target


def source_files(root: pathlib.Path) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for path in root.rglob("*"):
        if path.is_symlink():
            raise SystemExit(f"symlink is not allowed in pinned source: {path}")
        if path.is_file() and not path.name.startswith(".cybersand-source-"):
            files.append(path)
    return sorted(files, key=lambda item: item.relative_to(root).as_posix())


def create(root: pathlib.Path, ledger: pathlib.Path) -> None:
    if ledger.exists():
        raise SystemExit(f"refusing to overwrite source ledger: {ledger}")
    records = [
        f"{hash_file(path)}  {path.relative_to(root).as_posix()}\n"
        for path in source_files(root)
    ]
    ledger.write_text("".join(records), encoding="utf-8", newline="\n")


def verify(root: pathlib.Path, ledger: pathlib.Path) -> None:
    if not ledger.is_file():
        raise SystemExit(f"pinned source ledger is absent: {ledger}")
    seen: set[str] = set()
    for line_number, line in enumerate(
        ledger.read_text(encoding="utf-8").splitlines(), 1
    ):
        match = LINE.fullmatch(line)
        if not match:
            raise SystemExit(f"malformed source-ledger line {line_number}")
        expected, relative = match.groups()
        if relative in seen:
            raise SystemExit(f"duplicate source-ledger path: {relative}")
        seen.add(relative)
        target = safe_member(root, relative)
        if not target.is_file():
            raise SystemExit(f"pinned source file is absent: {relative}")
        actual = hash_file(target)
        if actual != expected:
            raise SystemExit(
                f"pinned source file changed: {relative}: {actual} != {expected}"
            )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["create", "verify"])
    parser.add_argument("root", type=pathlib.Path)
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        raise SystemExit(f"source root is absent: {root}")
    ledger = root / LEDGER_NAME
    if args.mode == "create":
        create(root, ledger)
    else:
        verify(root, ledger)


if __name__ == "__main__":
    main()
