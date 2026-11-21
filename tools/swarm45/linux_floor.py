#!/usr/bin/env python3
"""Do not raise the retained Linux bundle's dynamic symbol requirements."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess

import runtime_custody as custody

CEILINGS = {"GLIBC": (2, 34), "GLIBCXX": (3, 4, 30), "CXXABI": (1, 3, 9)}


def symbol_versions(text: str) -> dict:
    result = {}
    custody.require("GLIBC_PRIVATE" not in text, "Private libc interface cannot enter the retained CLI")
    for family, ceiling in CEILINGS.items():
        versions = {tuple(map(int, match.split("."))) for match in re.findall(r"\(" + family + r"_([0-9]+(?:\.[0-9]+)+)\)", text)}
        custody.require(bool(versions), "Missing inspectable dynamic symbol family: " + family)
        highest = max(versions)
        custody.require(highest <= ceiling, "Raised Linux " + family + " requirement: " + ".".join(map(str, highest)))
        result[family] = ".".join(map(str, highest))
    return result


def inspect(paths: list[Path]) -> dict:
    records = []
    for path in paths:
        custody.require(custody.binary_format(path, "linux"), "Linux floor check requires x86_64 ELF")
        output = subprocess.check_output(["objdump", "-T", str(path)], text=True, timeout=45)
        records.append({"file": path.name, "sha256": custody.sha(path), "maximum_imported_versions": symbol_versions(output)})
    return {"passed": True, "ceilings": {key: ".".join(map(str, value)) for key, value in CEILINGS.items()}, "binaries": records}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binaries", type=Path, nargs="+")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.binaries)
    custody.write_json(args.output, result)
    print(result)


if __name__ == "__main__":
    main()
