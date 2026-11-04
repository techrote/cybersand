#!/usr/bin/env python3
"""Independent, read-only Main display oracle from accepted pre-cutover Git.

This deliberately knows nothing about catalogue.json or presentation.py. Its
small literal parser refuses unfamiliar legacy code instead of interpreting a
new implementation as its own expected answer. The checked fixture is frozen
before the production consumer changes; this CLI has no fixture-write mode.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1"
BASELINE_TREE = "36ce5a01e754a141c321f41cac7f1c6b6059c371"
FIXTURE = Path("tools/material_catalogue/fixtures/main-display-names-v1.json")
MAIN = "godot/scripts/main.gd"
CELL = "godot/scripts/cell_world.gd"
EDGE_IDS = (-(1 << 63), -(1 << 63) + 1, -(1 << 32), -(1 << 31),
            -256, -132, -11, -10, -1, 256, 257, 65535, (1 << 31) - 1,
            1 << 31, (1 << 32) - 1, 1 << 32, (1 << 53) - 1,
            1 << 53, (1 << 53) + 1, (1 << 63) - 2, (1 << 63) - 1)


def git_bytes(root: Path, path: str) -> bytes:
    return subprocess.run(["git", "-C", str(root), "show", BASELINE + ":" + path],
                          check=True, capture_output=True, timeout=30).stdout


def function(source: str, name: str) -> str:
    match = re.search(r"(?ms)^func " + re.escape(name) + r"\([^\n]*\)[^\n]*:\n.*?(?=^func |\Z)", source)
    if match is None:
        raise ValueError("missing legacy function " + name)
    return match[0].rstrip() + "\n"


def _ids(main: str, name: str, constants: dict[str, int]) -> list[int]:
    match = re.search(r"const " + name + r": Array\[int\] = \[(.*?)\n\]", main, re.S)
    if match is None:
        raise ValueError("unsupported legacy array " + name)
    values = []
    for line in match[1].splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        token = re.fullmatch(r"CyberCellWorld\.([A-Z0-9_]+),", line)
        if token is None or token[1] not in constants:
            raise ValueError("unsupported legacy array item " + line)
        values.append(constants[token[1]])
    return values


def oracle(root: Path = ROOT) -> dict:
    tree = subprocess.run(["git", "-C", str(root), "rev-parse", BASELINE + "^{tree}"],
                          check=True, capture_output=True, text=True, timeout=30).stdout.strip()
    if tree != BASELINE_TREE:
        raise ValueError("legacy oracle tree differs from accepted source")
    sources = {path: git_bytes(root, path) for path in (MAIN, CELL)}
    main, cell = (sources[path].decode("utf-8") for path in (MAIN, CELL))
    constants = {key: int(value) for key, value in re.findall(
        r"^const ([A-Z][A-Z0-9_]*): int = ([0-9]+)$", cell, re.M)}
    if constants.get("FIRST_BUILDING_MATERIAL") != 81 or constants.get("LAST_MATERIAL") != 131:
        raise ValueError("legacy building range changed")
    method = function(main, "material_name")
    prefix = 'func material_name(material_id: int) -> String:\n\tmatch material_id:\n'
    suffix = ('\t\t_:\n'
              '\t\t\tif material_id >= CyberCellWorld.FIRST_BUILDING_MATERIAL and material_id <= CyberCellWorld.LAST_MATERIAL:\n'
              '\t\t\t\treturn CyberCellWorld.BUILDING_MATERIAL_NAMES[material_id - CyberCellWorld.FIRST_BUILDING_MATERIAL]\n'
              '\t\t\treturn "material-%d" % material_id\n')
    if not method.startswith(prefix) or not method.endswith(suffix):
        raise ValueError("unsupported legacy Main return structure")
    arms = method[len(prefix):-len(suffix)]
    arm_pattern = r'\t\tCyberCellWorld\.([A-Z0-9_]+):\n\t\t\treturn ("[^"\n]*")\n'
    found = list(re.finditer(arm_pattern, arms))
    if "".join(row[0] for row in found) != arms or len(found) != 80:
        raise ValueError("expected exactly 80 literal legacy match arms")
    names = {}
    for row in found:
        ident = constants[row[1]]
        if ident in names:
            raise ValueError("duplicate legacy arm")
        names[ident] = json.loads(row[2])
    building = re.search(r"const BUILDING_MATERIAL_NAMES: Array\[String\] = \[(.*?)\n\]", cell, re.S)
    if building is None:
        raise ValueError("missing legacy building labels")
    tokens = re.findall(r'"[^"\n]*"', building[1])
    remainder = re.sub(r'"[^"\n]*"', "", building[1])
    if remainder.replace(",", "").strip() or len(tokens) != 51:
        raise ValueError("unsupported legacy building label literals")
    names.update({81 + index: json.loads(token) for index, token in enumerate(tokens)})
    if set(names) != set(range(132)) - {10}:
        raise ValueError("legacy valid label domain changed")
    return {
        "schema_id": "cybersand.material-catalogue.legacy-display-oracle", "schema_version": 1,
        "source_commit": BASELINE, "source_tree": tree,
        "authority": "accepted Main match arms and CyberCellWorld building labels; independent of generated catalogue",
        "source_files": [{"path": path, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                         for path, data in sources.items()],
        "method_sha256": hashlib.sha256(method.encode("utf-8")).hexdigest(),
        "match_arms": 80, "building_labels": 51,
        "cases": [{"id": str(ident), "expected": names.get(ident, "material-%d" % ident)}
                  for ident in (*range(256), *EDGE_IDS)],
        "paintable_ids": _ids(main, "PAINTABLE_MATERIAL_IDS", constants),
        "group_first_ids": _ids(main, "MATERIAL_GROUP_FIRST_IDS", constants),
        "integer_encoding": "decimal strings preserve all signed 64-bit IDs through JSON/Godot",
    }


def check(root: Path = ROOT, baseline_repository: Path | None = None) -> dict:
    data = (root / FIXTURE).read_bytes()
    expected = (json.dumps(oracle(baseline_repository or root), sort_keys=True, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    if data != expected:
        raise ValueError("frozen legacy-name fixture differs from independently authenticated accepted Main")
    return {"status": "PASS", "source_commit": BASELINE, "fixture_sha256": hashlib.sha256(data).hexdigest(),
            "cases": 256 + len(EDGE_IDS), "byte_domain_cases": 256, "signed_large_cases": len(EDGE_IDS)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="nonwriting check (also the default)")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        result = check(args.root)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print("legacy display oracle: " + str(exc), file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
