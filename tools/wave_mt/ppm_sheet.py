#!/usr/bin/env python3
"""WAVE-MT-001: tile binary PPM frames into one PNG contact sheet (stdlib only).

    python tools/wave_mt/ppm_sheet.py out.png frame1.ppm frame2.ppm ... [--columns N] [--scale K]

--scale K keeps every K-th pixel (nearest neighbour) so large frames stay viewable.
"""
from __future__ import annotations

import argparse
import struct
import zlib


def read_ppm(path: str) -> tuple[int, int, bytes]:
    with open(path, "rb") as handle:
        data = handle.read()
    tokens: list[bytes] = []
    position = 0
    while len(tokens) < 4:
        while data[position:position + 1].isspace():
            position += 1
        end = position
        while not data[end:end + 1].isspace():
            end += 1
        tokens.append(data[position:end])
        position = end
    if tokens[0] != b"P6" or tokens[3] != b"255":
        raise ValueError(f"{path}: not a binary 8-bit PPM")
    width, height = int(tokens[1]), int(tokens[2])
    return width, height, data[position + 1:position + 1 + width * height * 3]


def write_png(path: str, width: int, height: int, rgb: bytearray) -> None:
    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += rgb[y * width * 3:(y + 1) * width * 3]
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(bytes(raw), 6)))
        handle.write(chunk(b"IEND", b""))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("out")
    parser.add_argument("frames", nargs="+")
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--scale", type=int, default=1)
    args = parser.parse_args()

    tiles = []
    for path in args.frames:
        width, height, pixels = read_ppm(path)
        step = args.scale
        out_w, out_h = (width + step - 1) // step, (height + step - 1) // step
        small = bytearray()
        for y in range(0, height, step):
            row = pixels[y * width * 3:(y + 1) * width * 3]
            for x in range(0, width, step):
                small += row[x * 3:x * 3 + 3]
        tiles.append((out_w, out_h, small))
    tile_w, tile_h = max(t[0] for t in tiles), max(t[1] for t in tiles)
    gap = 4
    columns = min(args.columns, len(tiles))
    rows = (len(tiles) + columns - 1) // columns
    sheet_w, sheet_h = columns * (tile_w + gap) - gap, rows * (tile_h + gap) - gap
    sheet = bytearray(b"\xff" * (sheet_w * sheet_h * 3))
    for index, (width, height, pixels) in enumerate(tiles):
        ox, oy = (index % columns) * (tile_w + gap), (index // columns) * (tile_h + gap)
        for y in range(height):
            start = ((oy + y) * sheet_w + ox) * 3
            sheet[start:start + width * 3] = pixels[y * width * 3:(y + 1) * width * 3]
    write_png(args.out, sheet_w, sheet_h, sheet)
    print(f"{args.out}: {sheet_w}x{sheet_h}, {len(tiles)} frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
