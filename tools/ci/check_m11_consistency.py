#!/usr/bin/env python3
"""Verify M11 evidence against the audited revision; current validation is separate."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HISTORICAL_SOURCE = "05ea45fda7bdd7b0150eb86c4922c202e89e08f4"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def historical_blob(root, relative):
    return subprocess.check_output(["git", "-C", str(root), "show", HISTORICAL_SOURCE + ":" + relative], stderr=subprocess.PIPE)

def check(root, compare_working_tree=False, reader=historical_blob):
    errors, differences = [], []
    records_checked = source_hashes_checked = 0
    try:
        manifest = json.loads((root / "docs/audits/m11-retention.json").read_text(encoding="utf-8"))
        if manifest["historical_source_commit"] != HISTORICAL_SOURCE:
            raise ValueError("retention manifest changed the audited M11 source revision")
        records = dict(manifest["files"])
        records[manifest["legacy_checker"]["path"]] = manifest["legacy_checker"]["sha256"]
        for relative, expected in records.items():
            path = (root / relative).resolve()
            if not path.is_relative_to(root.resolve()):
                raise ValueError("retention path escapes source root: " + relative)
            if not path.is_file() or digest(path.read_bytes().replace(b"\r\n", b"\n")) != expected:
                errors.append("retained historical record changed or missing: " + relative)
            records_checked += 1
        text = (root / "docs/BUILD_ID.md").read_text(encoding="utf-8")
        rows = re.findall(r"^\| `([^`]+)` \| `([0-9a-f]{64})` \|$", text, re.MULTILINE)
        if len(rows) != 28:
            errors.append(f"historical source hash table has {len(rows)} entries, expected 28")
        for relative, expected in rows:
            # Missing Git objects fail; never substitute current files or LFS OIDs.
            if digest(reader(root, relative)) != expected:
                errors.append("audited Git source hash differs: " + relative)
            source_hashes_checked += 1
            if compare_working_tree:
                path = root / relative
                data = path.read_bytes() if path.is_file() else b""
                if path.suffix in {".cpp", ".hpp", ".h", ".gd", ".godot", ".tscn"}:
                    data = data.replace(b"\r\n", b"\n")
                if digest(data) != expected:
                    differences.append(relative)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        errors.append(f"cannot verify historical evidence: {exc}; fetch full source history if Git objects are missing")
    return {"status": "failed" if errors or differences else "passed",
            "scope": "historical M11 integrity; no current runtime acceptance",
            "historical_source_commit": HISTORICAL_SOURCE,
            "records_checked": records_checked, "source_hashes_checked": source_hashes_checked,
            "compare_working_tree": compare_working_tree, "working_tree_differences": differences,
            "errors": errors}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--compare-working-tree", action="store_true", help="Strict legacy comparison: current implementation drift exits nonzero")
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    result = check(args.root.resolve(), args.compare_working_tree)
    output = json.dumps(result, indent=2) + "\n"
    if args.json:
        args.json.write_text(output, encoding="utf-8")
    print(output, end="")
    return int(result["status"] != "passed")

if __name__ == "__main__":
    raise SystemExit(main())
