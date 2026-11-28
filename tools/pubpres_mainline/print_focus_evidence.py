#!/usr/bin/env python3
"""Expose bounded original focus receipts and PNG bytes for independent remote review.

This reader runs after the actual process. It does not execute, alter, replay,
or award acceptance to the application. Complete originals remain in artifacts.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path

CASES = (
    ("test_workbench_retained_water_hold_native", "held.png"),
    ("test_workbench_continuous_actor_pick", "continuous-pick.png"),
)
MAX_RECEIPT = 512 * 1024
MAX_PNG = 512 * 1024


def read_bounded(path, limit):
    if not path.is_file():
        return None
    if path.is_symlink() or path.stat().st_size > limit:
        raise ValueError("Original focus record exceeds the console review scope")
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Original focus record changed during bounded read")
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    args = parser.parse_args()
    for case, image in CASES:
        receipt = read_bounded(args.root / case / "receipt.json", MAX_RECEIPT)
        if receipt is None:
            print("PUBPRES_ORIGINAL_FOCUS_ABSENT " + json.dumps({"case": case, "receipt": "absent"}), flush=True)
            continue
        value = json.loads(receipt)
        print("PUBPRES_ORIGINAL_FOCUS_RECEIPT " + json.dumps({
            "case": case, "bytes": len(receipt), "sha256": hashlib.sha256(receipt).hexdigest(),
            "receipt": value}), flush=True)
        path = args.root / case / image
        if path.is_file() and path.stat().st_size > MAX_PNG:
            print("PUBPRES_ORIGINAL_FRAMEBUFFER_ARTIFACT_ONLY " + json.dumps(
                {"case": case, "file": image, "bytes": path.stat().st_size,
                 "reason": "original retained in artifact; exceeds bounded console image scope"}), flush=True)
            continue
        raw = read_bounded(path, MAX_PNG)
        if raw is None:
            print("PUBPRES_ORIGINAL_FOCUS_ABSENT " + json.dumps({"case": case, "file": image}), flush=True)
            continue
        if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError("Original framebuffer is not a PNG")
        print("PUBPRES_ORIGINAL_FRAMEBUFFER " + json.dumps({
            "case": case, "file": image, "sha256": hashlib.sha256(raw).hexdigest(),
            "bytes": len(raw), "png_base64": base64.b64encode(raw).decode("ascii")}), flush=True)


if __name__ == "__main__":
    main()
