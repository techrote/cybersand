#!/usr/bin/env python3
"""Assemble source-qualified Godot RGB framebuffer tiles into one streamed RGB PNG.

Memory is O(one output scanline + compression buffers), never output_width *
output_height. This is a *transport* for original RG8 shader output, not a
replacement material renderer. Incomplete/missing/overlapping tiles fail closed.
"""
from __future__ import annotations

from contextlib import ExitStack
import hashlib
from pathlib import Path
import shutil
import struct
import zlib

MAX_STREAM_PIXELS = 100_000_000
MAX_STREAM_SIDE = 65_536
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
BACKGROUND_RGB = (8, 11, 18)
EDGE_NATIVE_CELLS = 8


def _chunk(handle, kind: bytes, data: bytes) -> None:
    handle.write(struct.pack(">I", len(data)))
    handle.write(kind)
    handle.write(data)
    handle.write(struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while data := stream.read(1024 * 1024):
            digest.update(data)
    return digest.hexdigest()


def _plan(job_dir: Path, shot: dict) -> tuple[int, int, Path, list[tuple[int, int, list[dict]]]]:
    record = shot.get("assembly", {})
    if not isinstance(record, dict):
        raise ValueError("missing streamed framebuffer assembly record")
    width, height = record.get("width"), record.get("height")
    if type(width) is not int or type(height) is not int or not (
        0 < width <= MAX_STREAM_SIDE and 0 < height <= MAX_STREAM_SIDE
        and width * height <= MAX_STREAM_PIXELS
    ):
        raise ValueError("unbounded streamed output dimensions")
    directory = Path(record.get("directory", "")).resolve()
    root = job_dir.resolve()
    if not directory.is_relative_to(root) or directory.name != "_stream-" + str(shot.get("id", "")):
        raise ValueError("streamed tile directory is not the job's private staging directory")
    raw_tiles = record.get("tiles")
    if not isinstance(raw_tiles, list) or not raw_tiles or len(raw_tiles) > 4096:
        raise ValueError("invalid streamed tile inventory")
    rows: dict[int, list[dict]] = {}
    for tile in raw_tiles:
        if not isinstance(tile, dict):
            raise ValueError("non-object streamed tile entry")
        x, y, w, h = (tile.get(k) for k in ("x", "y", "width", "height"))
        if not all(type(v) is int and v >= 0 for v in (x, y, w, h)) or not (
            0 < w <= width and 0 < h <= height and x + w <= width and y + h <= height
        ):
            raise ValueError("invalid tile geometry")
        filename = str(tile.get("file", ""))
        if not filename.startswith("tile-") or not filename.endswith(".rgb") or "/" in filename or "\\" in filename:
            raise ValueError("invalid or unsafe streamed tile name")
        path = (directory / filename).resolve()
        if not path.is_relative_to(directory) or not path.is_file():
            raise ValueError("streamed tile is missing or outside staging")
        expected = w * h * 3
        if path.stat().st_size != expected or tile.get("bytes") != expected:
            raise ValueError("streamed tile length disagrees with RGB8 geometry")
        if tile.get("sha256") != _sha256(path):
            raise ValueError("streamed tile hash does not match Godot framebuffer evidence")
        rows.setdefault(y, []).append({**tile, "_path": path})
    bands: list[tuple[int, int, list[dict]]] = []
    next_y = 0
    for y in sorted(rows):
        if y != next_y:
            raise ValueError("streamed raster has a missing or overlapping row band")
        parts = sorted(rows[y], key=lambda item: item["x"])
        next_x = 0
        height_of_band = parts[0]["height"]
        for item in parts:
            if item["x"] != next_x or item["height"] != height_of_band:
                raise ValueError("streamed raster has a missing/overlapping tile or inconsistent band height")
            next_x += item["width"]
        if next_x != width:
            raise ValueError("streamed row band does not cover the full authored width")
        bands.append((y, height_of_band, parts))
        next_y += height_of_band
    if next_y != height:
        raise ValueError("streamed bands do not cover the full authored height")
    return width, height, directory, bands


def assemble_rgb_tiles(job_dir: Path, shot: dict) -> dict:
    """Emit one true RGB8 PNG by scanline. Return independently sampled metadata.

    The caller must update/seal the job and batch manifests *only after* this
    returns successfully. A partial PNG never becomes a valid manifest shot.
    """
    width, height, directory, bands = _plan(job_dir, shot)
    name = str(shot.get("file", ""))
    if name != str(shot.get("id", "")) + ".png":
        raise ValueError("streamed output name disagrees with requested shot id")
    destination = (job_dir / name).resolve()
    if not destination.is_relative_to(job_dir.resolve()) or destination.exists():
        raise ValueError("streamed PNG output already exists or escapes the private job directory")

    sampled = set()
    edges = {side: set() for side in ("left", "right", "top", "bottom")}
    non_background = 0
    samples = 0
    luma_min = 1.0
    luma_max = 0.0
    x_step = max(1, width // 256)
    y_step = max(1, height // 256)
    border_step_x = max(1, width // 512)
    border_step_y = max(1, height // 512)
    strip = min(EDGE_NATIVE_CELLS * int(shot.get("camera", {}).get("scale", 1)), min(width, height))
    compressor = zlib.compressobj(level=6)
    with destination.open("xb") as output:
        output.write(PNG_SIGNATURE)
        _chunk(output, b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        for y_start, row_count, parts in bands:
            with ExitStack() as stack:
                handles = [stack.enter_context(tile["_path"].open("rb")) for tile in parts]
                strides = [tile["width"] * 3 for tile in parts]
                for row in range(row_count):
                    pieces = [handle.read(length) for handle, length in zip(handles, strides)]
                    if any(len(piece) != length for piece, length in zip(pieces, strides)):
                        raise ValueError("streamed tile is truncated during assembly")
                    pixels = b"".join(pieces)
                    if len(pixels) != width * 3:
                        raise ValueError("assembled row has incorrect RGB length")
                    y = y_start + row
                    if y % y_step == 0 or y == height - 1:
                        for x in range(0, width, x_step):
                            colour = tuple(pixels[x * 3:x * 3 + 3])
                            sampled.add(colour)
                            non_background += int(colour != BACKGROUND_RGB)
                            light = (0.2126 * colour[0] + 0.7152 * colour[1] + 0.0722 * colour[2]) / 255.0
                            luma_min = min(luma_min, light)
                            luma_max = max(luma_max, light)
                            samples += 1
                    if y % border_step_y == 0 or y == height - 1:
                        for x in range(strip):
                            edges["left"].add(tuple(pixels[x * 3:x * 3 + 3]))
                            right = width - strip + x
                            edges["right"].add(tuple(pixels[right * 3:right * 3 + 3]))
                    if y < strip or y >= height - strip:
                        for x in range(0, width, border_step_x):
                            edges["top" if y < strip else "bottom"].add(
                                tuple(pixels[x * 3:x * 3 + 3]))
                    compressed = compressor.compress(b"\x00" + pixels)
                    if compressed:
                        _chunk(output, b"IDAT", compressed)
                for handle in handles:
                    if handle.read(1):
                        raise ValueError("tile has extra unaccounted RGB bytes")
        trailing = compressor.flush()
        if trailing:
            _chunk(output, b"IDAT", trailing)
        _chunk(output, b"IEND", b"")
    digest = _sha256(destination)
    stats = {
        "samples": samples,
        "distinct_colours": len(sampled),
        "non_background_fraction": non_background / max(1, samples),
        "luma_min": luma_min, "luma_max": luma_max,
        "nonblank": len(sampled) >= 4 and non_background > max(0, samples // 2000),
        "sampling": "streamed RGB8 scanline subset",
    }
    side_stats = {side: {"distinct_colours": len(colours),
                         "samples": len(colours), "sampling": "streamed edge samples"}
                  for side, colours in edges.items()}
    # Delete only the explicitly qualified private tile directory after PNG
    # bytes, hashes, and sampled metadata have been produced successfully.
    shutil.rmtree(directory)
    return {"width": width, "height": height,
            "png_sha256": digest, "png_bytes": destination.stat().st_size,
            "stats": stats, "edge_stats": side_stats,
            "streamed_output": {"format": "RGB8 PNG", "max_pixels": MAX_STREAM_PIXELS,
                                "assembly": "Godot halo-tiled RG8 shader framebuffer RGB scanlines"}}
