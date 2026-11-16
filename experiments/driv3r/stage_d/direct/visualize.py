"""Reproducible, DEVELOPMENT-only *synthetic cursor* D-1A raster diagnostics.

A PNG pixel is NOT a Workbench material readback or a native PAINT receipt.
Every displayed path must first replay against the frozen geometry/seed/policy;
held-out controller outcomes are never generated or inspected here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import zlib

from . import offline as d
from . import paired

VERSION = "d1a-synthetic-cursor-gallery/1"
# RGB only; palette names explicitly describe synthetic grid/cursor states.
AIR = (250, 250, 249)
BAND = (230, 240, 239)
WALL = (62, 68, 73)
DECOY = (162, 166, 170)
MATERIAL_Z = (163, 75, 59)
PROTECTED = (100, 75, 143)
TRACE = (31, 106, 175)
RETRACE = (224, 139, 43)
START = (47, 150, 86)
TARGET = (160, 62, 138)


def _hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _png(width: int, height: int, rgb: bytes) -> bytes:
    """Encode exact RGB8 samples as a valid deterministic stdlib-only PNG."""
    if type(width) is not int or type(height) is not int or not (1 <= width <= 4096 and 1 <= height <= 4096):
        raise ValueError("Invalid bounded image dimensions")
    if len(rgb) != width * height * 3:
        raise ValueError("Invalid raster byte length")
    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xffffffff)
    row_bytes = width * 3
    raw = b"".join(b"\x00" + rgb[y * row_bytes:(y + 1) * row_bytes] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def render_episode(fixture: d.Fixture, episode: dict, scale: int = 10) -> bytes:
    """Paint a source-replayed synthetic cursor trace, never native material."""
    if type(scale) is not int or not (3 <= scale <= 32):
        raise ValueError("Scale must be a bounded integer in [3,32]")
    # Mandatory before reading the trajectory, so tampering and sealed
    # episodes cannot be converted into plausible-looking visual evidence.
    paired.verify_episode(fixture, episode)
    w, h = fixture.width, fixture.height
    if w * scale > 4096 or h * scale > 4096:
        raise ValueError("Image dimensions exceed safety bound")

    cells = [[AIR for _ in range(w)] for _ in range(h)]
    if fixture.task == "wall_offset":
        for y in range(h):
            for x in range(w):
                if fixture.legal((x, y)) and d.deviation(fixture, (x, y)) == 0.0:
                    cells[y][x] = BAND
    for x, y in fixture.solid:
        cells[y][x] = WALL if (x, y) in fixture.selected_wall else DECOY
    for x, y in fixture.material_z:
        cells[y][x] = MATERIAL_Z
    for x, y in fixture.protected:
        cells[y][x] = PROTECTED

    visited = {fixture.start}
    for x, y in episode["path"][1:]:
        cells[y][x] = RETRACE if (x, y) in visited else TRACE
        visited.add((x, y))
    sx, sy = fixture.start
    tx, ty = fixture.target
    cells[sy][sx] = START
    cells[ty][tx] = TARGET

    image_width, image_height = w * scale, h * scale
    pixel_rows = bytearray()
    for row in cells:
        expanded = b"".join(bytes(rgb) * scale for rgb in row)
        pixel_rows.extend(expanded * scale)
    return _png(image_width, image_height, bytes(pixel_rows))


def _source_fence(source_sha: str) -> None:
    """Never attach a commit label to dirty or mismatched worktree bytes."""
    if type(source_sha) is not str or re.fullmatch(r"[0-9a-f]{40}", source_sha) is None:
        raise ValueError("Explicit 40-hex source SHA required")
    root = Path(__file__).resolve().parents[4]
    def git(*args: str) -> str:
        return subprocess.check_output(["git", *args], cwd=root, text=True, timeout=15).strip()
    if git("rev-parse", "HEAD") != source_sha:
        raise ValueError("Checkout HEAD does not equal requested source SHA")
    if git("status", "--porcelain", "--", "experiments/driv3r/stage_d/direct"):
        raise ValueError("Dirty D-1A files cannot be source-attested")


def generate_development_gallery(output_dir: Path, source_sha: str, *,
                                 seed: int = 13, lengths: tuple[int, ...] = (1,),
                                 scale: int = 10) -> dict:
    """Create paired control rasters and SHA-bound manifest; no model/native job.

    Refuse existing output folders so a failed run cannot overwrite/purge old
    results or quietly mix outputs from different source revisions.
    """
    _source_fence(source_sha)
    if type(seed) is not int or not (0 <= seed <= 4294967295):
        raise ValueError("Seed must be an unsigned 32-bit integer")
    if type(lengths) not in (tuple, list) or not lengths or list(lengths) != sorted(set(lengths)) or 1 not in lengths or any(type(n) is not int or n not in (1, 2, 4, 8) for n in lengths):
        raise ValueError("Invalid canonical macro lengths")
    output_dir = Path(output_dir)
    if output_dir.exists():
        raise FileExistsError("Gallery output directory must not already exist")
    # Prepare ALL outputs before mutating the filesystem; fail closed if any
    # source replay fails or an unexpected sealed case is attempted.
    rows, images = [], {}
    for fixture in d.fixtures():
        if fixture.split != "development":
            continue  # inspect no held-out policy outcomes
        strong = "contour_astar" if fixture.task == "wall_offset" else "astar"
        arms = {
            "geometric": d.run_episode(fixture, strong, seed, tuple(lengths)),
            "random_legal": d.run_episode(fixture, "random_legal", seed, tuple(lengths)),
        }
        matched = paired.compare_matched(fixture, arms)
        for arm_name, episode in sorted(arms.items()):
            custody = paired.verify_episode(fixture, episode)
            filename = f"{fixture.fixture_id}__{arm_name}.png"
            if not re.fullmatch(r"[a-z0-9_]+\.png", filename):
                raise ValueError("Noncanonical fixture file name")
            data = render_episode(fixture, episode, scale)
            images[filename] = data
            rows.append({
                "fixture_id": fixture.fixture_id,
                "fixture_sha256": fixture.sha256,
                "structural_split": "development",
                "arm": arm_name,
                "policy": episode["policy"], "seed": seed,
                "macro_lengths": list(lengths),
                "path_sha256": custody["path_sha256"],
                "event_count": custody["event_count"],
                "synthetic_metrics": episode["metrics"],
                "matched_until_divergence": matched["common_choice_prefix_decisions"],
                "image_file": filename, "image_sha256": _hash(data),
            })
    rows.sort(key=lambda x: (x["fixture_id"], x["arm"]))
    record = {
        "version": VERSION, "source_commit": source_sha,
        "source_kind": "development_synthetic_cursor_only",
        "native_qualified": False, "sequential_native_receipts": 0,
        "model_evaluated": False, "heldout_policy_outcomes_evaluated": False,
        "raster_kind": "offline_grid_not_workbench_material_or_framebuffer",
        "scale": scale, "seed": seed, "macro_lengths": list(lengths),
        "images": rows, "index_sha256": d.digest(rows),
    }
    output_dir.mkdir(parents=True)
    for name, data in sorted(images.items()):
        (output_dir / name).write_bytes(data)
    (output_dir / "manifest.json").write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return record


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--seed", type=int, default=13)
    parser.add_argument("--macro", action="store_true", help="Enable 1/2/4/8-cell decision macros")
    parser.add_argument("--scale", type=int, default=10)
    args = parser.parse_args()
    record = generate_development_gallery(args.output, args.source_sha,
                                          seed=args.seed, lengths=(1, 2, 4, 8) if args.macro else (1,),
                                          scale=args.scale)
    print(json.dumps({"source_sha": args.source_sha, "index_sha256": record["index_sha256"],
                      "image_count": len(record["images"]), "output": str(args.output)}, sort_keys=True))


if __name__ == "__main__":
    main()
