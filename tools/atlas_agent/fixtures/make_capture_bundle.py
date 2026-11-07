#!/usr/bin/env python3
"""Generate a FIXTURE capture bundle in the #498 batch-manifest layout from a pack.

The PNG is a flat palette raster (stdlib zlib) - it is NOT Godot output. The batch
manifest says ``"fixture": true`` so the runner classifies it as evidence class
``fixture`` and never lets it support a visual-improvement claim.

  python tools/atlas_agent/fixtures/make_capture_bundle.py --pack-dir <collection dir> --output-dir <new dir>
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from atlas_agent import captures  # noqa: E402

SCALE = 4


def _png(width: int, height: int, rows: list[bytes]) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rows)
    return (captures.PNG_SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def make_bundle(pack_dir: Path, output_dir: Path) -> Path:
    pack_path = Path(pack_dir) / "pack.json"
    pack = json.loads(pack_path.read_text(encoding="utf-8"))
    colour = {m["id"]: tuple(m["rgba"][:3]) for m in pack["palette"]}
    width, height = pack["scene"]["size"]
    grid = [[colour.get(0, (0, 0, 0))] * width for _ in range(height)]

    def stamp(items, ox, oy):
        for x, y, w, h, m in items:
            for yy in range(oy + y, oy + y + h):
                for xx in range(ox + x, ox + x + w):
                    grid[yy][xx] = colour[m]

    stamp(pack["scene"]["foundation"], 0, 0)
    features = {f["id"]: f for f in pack["features"]}
    for placement in pack["scene"]["placements"]:
        stamp(features[placement["feature"]]["rectangles"], placement["x"], placement["y"])
    rows = [b"".join(bytes(px) * SCALE for px in line) for line in grid for _ in range(SCALE)]
    png = _png(width * SCALE, height * SCALE, rows)
    collection = Path(pack_dir).name
    job_dir = Path(output_dir) / f"01-{collection}"
    job_dir.mkdir(parents=True)
    (job_dir / "full.png").write_bytes(png)
    png_sha = hashlib.sha256(png).hexdigest()
    rg8 = hashlib.sha256(json.dumps(grid).encode()).hexdigest()
    pack_sha = hashlib.sha256(pack_path.read_bytes()).hexdigest()
    camera = {"scale": SCALE, "framing": "native-fixture"}
    job = {"schema": captures.SCHEMA_JOB, "status": "complete",
           "job": {"id": f"01-{collection}", "collection": collection, "pack_sha256_expected": pack_sha},
           "input_pack": {"path": str(pack_path), "sha256": pack_sha},
           "shots": [{"id": "full", "kind": "full", "file": "full.png", "status": "complete",
                      "width": width * SCALE, "height": height * SCALE, "png_sha256": png_sha, "camera": camera,
                      "stats": {"nonblank": True},
                      "source": {"rg8_sha256": rg8, "native_width": width, "native_height": height}}]}
    job_path = job_dir / "manifest.json"
    job_path.write_text(json.dumps(job, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
    batch = {"schema": captures.SCHEMA_BATCH, "status": "completed", "fixture": True,
             "engine": {"kind": "fixture-flat-raster", "note": "flat palette raster, NOT Godot output"},
             "art_source": {"revision": None}, "presentation": {"scale": SCALE},
             "jobs": [{"id": f"01-{collection}", "collection": collection,
                       "manifest": f"01-{collection}/manifest.json", "status": "complete",
                       "manifest_sha256": hashlib.sha256(job_path.read_bytes()).hexdigest()}]}
    captures.seal(batch)
    (Path(output_dir) / "batch-manifest.json").write_text(json.dumps(batch, sort_keys=True, indent=2) + "\n",
                                                          encoding="utf-8", newline="\n")
    return Path(output_dir)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pack-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    out = Path(args.output_dir)
    if out.exists() and any(out.iterdir()):
        print("output directory must be empty", file=sys.stderr)
        return 2
    out.mkdir(parents=True, exist_ok=True)
    make_bundle(Path(args.pack_dir), out)
    print(f"wrote fixture capture bundle to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
