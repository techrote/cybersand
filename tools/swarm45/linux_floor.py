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


def inspect(paths: list[Path], evidence: Path | None = None) -> dict:
    records = []
    errors = []
    if evidence is not None:
        evidence.mkdir(parents=True, exist_ok=True)
    for path in paths:
        custody.require(custody.binary_format(path, "linux"), "Linux floor check requires x86_64 ELF")
        output = subprocess.check_output(["objdump", "-T", str(path)], text=True, timeout=45)
        record = {"file": path.name, "sha256": custody.sha(path)}
        if evidence is not None:
            log = evidence / (path.name + ".objdump-T.log")
            log.write_text(output, encoding="utf-8")
            record.update(symbol_table=log.name, symbol_table_sha256=custody.sha(log))
        try:
            record.update(passed=True, maximum_imported_versions=symbol_versions(output))
        except ValueError as error:
            record.update(passed=False, error=str(error))
            errors.append(path.name + ": " + str(error))
        records.append(record)
    result = {"passed": not errors, "ceilings": {key: ".".join(map(str, value)) for key, value in CEILINGS.items()},
              "binaries": records, "errors": errors}
    if evidence is not None:
        custody.write_json(evidence / "linux-runtime-floor.json", result)
    custody.require(not errors, "Linux runtime floor failed: " + "; ".join(errors))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binaries", type=Path, nargs="+")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.binaries, args.output.parent)
    custody.write_json(args.output, result)
    print(result)


if __name__ == "__main__":
    main()
