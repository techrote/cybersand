#!/usr/bin/env python3
"""Verify all raw artifact parts and optionally reconstruct the exact original ZIP."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        help="New ZIP path; omission verifies parts without writing another copy")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    manifest = json.loads((root/"manifest.json").read_text(encoding="utf-8"))
    if args.output is not None and args.output.exists():
        raise ValueError("Refusing to overwrite existing output: "+str(args.output))
    stream = args.output.open("xb") if args.output is not None else None
    complete = hashlib.sha256()
    total = 0
    verified = []
    try:
        for part in manifest["parts"]:
            name = part["path"]
            if Path(name).name != name or total != part["offset"]:
                raise ValueError("Invalid part path/order")
            measured = hashlib.sha256()
            size = 0
            with (root/name).open("rb") as source:
                while True:
                    block = source.read(65536)
                    if not block:
                        break
                    measured.update(block)
                    complete.update(block)
                    size += len(block)
                    if stream is not None:
                        stream.write(block)
            if size != part["bytes"] or measured.hexdigest() != part["sha256"]:
                raise ValueError("Part size/hash differs: "+name)
            total += size
            verified.append(name)
        if total != manifest["original_bytes"] or complete.hexdigest() != manifest["original_sha256"]:
            raise ValueError("Reassembled artifact differs from the original identity")
    finally:
        if stream is not None:
            stream.close()
    print(json.dumps({"status":"PASS", "verified_parts":verified,
        "original_bytes":total, "original_sha256":complete.hexdigest(),
        "output":str(args.output.resolve()) if args.output is not None else None}, indent=2))


if __name__ == "__main__":
    main()
