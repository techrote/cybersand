#!/usr/bin/env python3
"""Build original exact-grid RGBA/native interchange fixtures, never concept art.

Only Python's standard library is required. This deliberately avoids resampling
and colour management: PNG samples, native IDs and the no-write mask are exact.
"""

from __future__ import annotations

import base64
import hashlib
import json
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "godot/data/strata2/imports"
WIDTH, HEIGHT = 64, 48
STRUCTURE = (64, 80, 96, 255)
ACCENT = (32, 192, 224, 255)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def png(rgba: bytes) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    scanlines = b"".join(b"\0" + rgba[y * WIDTH * 4 : (y + 1) * WIDTH * 4] for y in range(HEIGHT))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(scanlines, 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    pixels = [(255, 0, 255, 0)] * (WIDTH * HEIGHT)  # Hidden RGB tests alpha, not RGB=0.

    def rectangle(x: int, y: int, width: int, height: int, colour: tuple[int, int, int, int]) -> None:
        for py in range(y, y + height):
            for px in range(x, x + width):
                pixels[py * WIDTH + px] = colour

    rectangle(4, 4, 56, 4, STRUCTURE)
    rectangle(4, 40, 56, 4, STRUCTURE)
    rectangle(4, 8, 6, 32, STRUCTURE)
    rectangle(54, 8, 6, 32, STRUCTURE)
    rectangle(10, 8, 44, 4, STRUCTURE)
    rectangle(10, 36, 44, 4, STRUCTURE)
    rectangle(12, 13, 3, 22, STRUCTURE)
    rectangle(49, 13, 3, 22, STRUCTURE)
    rectangle(18, 6, 28, 1, ACCENT)
    rectangle(18, 41, 28, 1, ACCENT)
    rectangle(6, 16, 2, 16, ACCENT)
    rectangle(56, 16, 2, 16, ACCENT)
    pixels[9 * WIDTH + 31] = (32, 192, 224, 127)
    pixels[9 * WIDTH + 32] = (32, 192, 224, 128)
    rgba = bytes(channel for pixel in pixels for channel in pixel)
    source = png(rgba)
    (DESTINATION / "alpha-cutout.png").write_bytes(source)

    mask_pixels = [(255, 255, 255, 255)] * (WIDTH * HEIGHT)
    for y in range(HEIGHT):
        for x in range(32, WIDTH):
            mask_pixels[y * WIDTH + x] = (0, 0, 0, 255)
    mask_rgba = bytes(channel for pixel in mask_pixels for channel in pixel)
    (DESTINATION / "left-half-mask.png").write_bytes(png(mask_rgba))

    cell_values = [0 if pixel[3] < 128 else (58 if pixel[:3] == STRUCTURE[:3] else 66) for pixel in pixels]
    cells = struct.pack("<" + "H" * len(cell_values), *cell_values)
    mask = bytes(0 if pixel[3] < 128 else 1 for pixel in pixels)
    module = {
        "format": "cybersand-strata-module-v1",
        "id": "alpha-cutout-native",
        "name": "Synthetic cutout native frame",
        "extent": [WIDTH, HEIGHT],
        "anchor": [0, 0],
        "allowed_transforms": ["identity", "mirror_x", "mirror_y", "rotate_90", "rotate_180", "rotate_270"],
        "roles": [
            {"name": "structure", "material_ids": [58], "compatible_materials": [58, 63, 66], "source": "authored"},
            {"name": "accent", "material_ids": [66], "compatible_materials": [66, 77], "source": "authored"},
        ],
        "clearances": [],
        "protected_regions": [],
        "geometry": {
            "encoding": "uint16-le-row-major",
            "cells_base64": base64.b64encode(cells).decode(),
            "write_mask_base64": base64.b64encode(mask).decode(),
            "sha256": digest(cells),
            "mask_sha256": digest(mask),
        },
        "provenance": {
            "source_kind": "original-synthetic-native-fixture",
            "source_sha256": digest(source),
            "source_extent": [WIDTH, HEIGHT],
            "decoded_rgba_sha256": digest(rgba),
            "alpha_threshold": 128,
            "source": "tools/strata2_build_import_fixtures.py",
            "scope": "Exact synthetic material test data; not gallery art, physics, or a framebuffer capture.",
        },
    }
    module["content_sha256"] = digest(canonical(module))
    (DESTINATION / "alpha-cutout-native.json").write_bytes(canonical(module) + b"\n")
    manifest = {
        "format": "cybersand-strata-import-fixtures-v1",
        "source_kind": "original-synthetic-exact-grid-fixtures",
        "extent": [WIDTH, HEIGHT],
        "palette": [
            {"rgb": [64, 80, 96], "material": 58, "role": "structure"},
            {"rgb": [32, 192, 224], "material": 66, "role": "accent"},
        ],
        "known_cells": {
            "opaque_structure": {"point": [4, 4], "material": 58},
            "opaque_accent": {"point": [18, 6], "material": 66},
            "interior_transparent": {"point": [32, 24], "alpha": 0, "overlay": "no-write", "replace": 0},
            "partial_excluded": {"point": [31, 9], "alpha": 127, "overlay": "no-write", "replace": 0},
            "partial_included": {"point": [32, 9], "alpha": 128, "material": 66},
        },
        "counts_at_threshold_128": {"mapped": sum(mask), "no_write": len(mask) - sum(mask)},
        "files": [],
    }
    for name in ["alpha-cutout.png", "left-half-mask.png", "alpha-cutout-native.json"]:
        data = (DESTINATION / name).read_bytes()
        manifest["files"].append({"path": name, "bytes": len(data), "sha256": digest(data)})
    (DESTINATION / "fixture-manifest.json").write_bytes(json.dumps(manifest, indent=2, sort_keys=True).encode() + b"\n")
    print(json.dumps({"directory": str(DESTINATION), "files": manifest["files"], "counts": manifest["counts_at_threshold_128"]}))


if __name__ == "__main__":
    main()
