#!/usr/bin/env python3
"""Prepare exact source-pixel crops and explicit manual import masks.

No source artwork is overwritten or resampled.  The mask is an authored
selection proposal; it is not recovered alpha, inferred depth, accepted native
geometry, or a physical collision claim.  The original source bytes are pinned
and checked before deriving these small, self-contained evaluator inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

from strata2_build_showcases import readable_json


COMMIT = "99a166e7fcae45eb22be1740e9f33f62faccbcc7"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "godot/data/strata2/reference-imports"
URI = "res://data/strata2/reference-imports/"
SOURCES = [
    {"id": "asteroid-service-gallery", "label": "Asteroid gallery · opaque reference plus explicit aperture mask",
     "source_path": "artwork/spacecraft_orbital_structures/batch2/asteroid_ladder_galleries.png",
     "source_sha256": "e663ce4379554b49c168447b023f24481ad7df3dc9106bddcd29ed40c952cf28",
     "crop": [1180, 384, 384, 320],
     "mask_rectangles": [[78, 112, 22, 178], [78, 112, 242, 22], [304, 112, 22, 190], [78, 292, 248, 20], [0, 300, 384, 14]],
     "palette": [{"rgb": [96, 96, 108], "material": 62, "role": "grey structure"},
                 {"rgb": [55, 66, 72], "material": 63, "role": "dark structure"},
                 {"rgb": [160, 160, 168], "material": 114, "role": "bright metal"},
                 {"rgb": [204, 152, 64], "material": 79, "role": "amber marking"},
                 {"rgb": [72, 91, 76], "material": 68, "role": "pipe colour"},
                 {"rgb": [38, 39, 43], "material": 100, "role": "dark rock"}]},
    {"id": "rocket-hangar-frame", "label": "Rocket hangar · opaque reference plus selected frame mask",
     "source_path": "artwork/works_yards/batch1/orbital_assembly_hangars-rocket_assembly_hall-cool_precision.png",
     "source_sha256": "033534dc0971a8250f27a7d9a91e60af6230559a872107505f574c33e1420fef",
     "crop": [368, 112, 512, 320],
     "mask_rectangles": [[40, 14, 472, 36], [40, 50, 24, 270], [395, 135, 24, 185], [390, 110, 122, 18]],
     "palette": [{"rgb": [57, 70, 89], "material": 62, "role": "dark steel"},
                 {"rgb": [92, 102, 115], "material": 114, "role": "bright steel"},
                 {"rgb": [22, 35, 51], "material": 130, "role": "deep frame"},
                 {"rgb": [126, 84, 22], "material": 76, "role": "gold crane paint"},
                 {"rgb": [198, 150, 61], "material": 79, "role": "amber detail"},
                 {"rgb": [126, 208, 244], "material": 77, "role": "cyan signal"}]},
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--originals", type=Path, required=True, help="Directory containing the unchanged exact-source original PNG files.")
    parser.add_argument("--check", action="store_true", help="Check shipped crop pixels, masks, fixture JSON and provenance without rewriting.")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipts = []
    for source in SOURCES:
        original_path = args.originals / Path(source["source_path"]).name
        original_bytes = original_path.read_bytes()
        assert sha(original_bytes) == source["source_sha256"], f"Original source identity differs: {original_path}"
        original = Image.open(original_path)
        assert original.mode == "RGB", "These inspected inputs are explicitly opaque RGB originals."
        x, y, width, height = source["crop"]
        cropped = original.crop((x, y, x + width, y + height))
        mask = Image.new("RGBA", cropped.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(mask)
        for mx, my, mw, mh in source["mask_rectangles"]:
            assert 0 <= mx < mx + mw <= width and 0 <= my < my + mh <= height
            draw.rectangle((mx, my, mx + mw - 1, my + mh - 1), fill=(255, 255, 255, 255))
        crop_name = source["id"] + ".png"
        mask_name = source["id"] + ".mask.png"
        crop_path, mask_path = OUTPUT / crop_name, OUTPUT / mask_name
        if args.check:
            assert Image.open(crop_path).mode == "RGB" and Image.open(crop_path).size == cropped.size
            assert Image.open(crop_path).tobytes() == cropped.tobytes(), f"Source pixels differ: {crop_path}"
            assert Image.open(mask_path).convert("RGBA").tobytes() == mask.tobytes(), f"Authored mask differs: {mask_path}"
        else:
            cropped.save(crop_path, compress_level=9)
            mask.save(mask_path, compress_level=9)
        mapped = unmapped = no_write = 0
        materials = bytearray(width * height * 2)
        write_mask = bytearray(width * height)
        crop_bytes = cropped.tobytes()
        mask_bytes = mask.tobytes()
        for i in range(width * height):
            pixel = crop_bytes[i * 3:i * 3 + 3]
            if mask_bytes[i * 4 + 3] == 0:
                no_write += 1
                continue
            distances = [sum((component - sample) ** 2 for component, sample in zip(pixel, row["rgb"])) for row in source["palette"]]
            nearest = min(range(len(distances)), key=distances.__getitem__)
            if distances[nearest] > 64 * 64:
                unmapped += 1
                continue
            mapped += 1
            material = source["palette"][nearest]["material"]
            materials[i * 2:i * 2 + 2] = material.to_bytes(2, "little")
            write_mask[i] = 1
        fixture = {"id": source["id"], "label": source["label"], "path": URI + crop_name,
                   "options": {"plane": "scripted", "crop": [0, 0, width, height], "origin": [128, 128],
                               "scale": 1, "transform": "identity", "alpha_mode": "overlay", "alpha_threshold": 128,
                               "mask_path": URI + mask_name, "palette": source["palette"], "color_distance": 64, "unmapped": "skip"}}
        # A separately declared narrower crop fits the protected interior of
        # the 512-square mounted native test. No input is silently rescaled.
        native_width = min(width, 448)
        native_cells = b"".join(materials[y * width * 2:(y * width + native_width) * 2] for y in range(height))
        native_mask = b"".join(write_mask[y * width:y * width + native_width] for y in range(height))
        native_included = sum(mask_bytes[(y * width + x) * 4 + 3] != 0 for y in range(height) for x in range(native_width))
        native_mapped = sum(native_mask)
        receipt = {"format": "cybersand-strata-reference-import-v1", "id": source["id"],
                   "source_repository": "techrote/sandmapsreference", "source_commit": COMMIT,
                   "source_path": source["source_path"], "source_url": f"https://raw.githubusercontent.com/techrote/sandmapsreference/{COMMIT}/{source['source_path']}",
                   "original_sha256": source["source_sha256"], "original_bytes": len(original_bytes), "original_resolution": list(original.size),
                   "original_mode": original.mode, "original_alpha_zero": 0, "original_alpha_partial": 0,
                   "selected_original_crop": source["crop"], "crop_path": URI + crop_name,
                   "crop_file_sha256": sha(crop_path.read_bytes()), "crop_rgb_pixels_sha256": sha(cropped.tobytes()),
                   "crop_semantics": "Exact original RGB pixels selected without scaling, filtering or altered colours; original file remains unchanged.",
                   "mask_path": URI + mask_name, "mask_sha256": sha(mask_path.read_bytes()), "mask_rectangles": source["mask_rectangles"],
                   "mask_semantics": "Explicit authored selection proposal. White opaque rectangles include; all other pixels are transparent/no-write. This mask is not source alpha or inferred authoritative depth.",
                   "mapping_policy": fixture["options"], "proposal_counts": {"source_pixels": width * height, "mapped": mapped, "mask_no_write": no_write, "unmapped_skipped": unmapped, "explicit_empty": 0},
                   "proposed_uint16le_sha256": sha(materials), "proposed_write_mask_sha256": sha(write_mask),
                   "native_qualification": {"canvas": [512, 512], "selected_crop": [0, 0, native_width, height], "origin": [32, 64],
                                            "proposed_uint16le_sha256": sha(native_cells), "proposed_write_mask_sha256": sha(native_mask),
                                            "mapped": native_mapped, "no_write": native_width * height - native_mapped,
                                            "mask_no_write": native_width * height - native_included, "unmapped_skipped": native_included - native_mapped,
                                            "scope": "Explicit qualification crop within the unchanged shipped source; same mapping/mask; no resampling."},
                   "qualification": "Deterministic input/proposal fixture only; native receipt/readback and actual Godot framebuffer belong to the source-bound Workbench qualification.",
                   "original_preservation": "The original is not copied into this small fixture bundle; exact source URL and SHA-256 identify the unmodified original. The shipped crop retains exact pixels and explicit crop coordinates."}
        for name, document in ((source["id"] + ".fixture.json", fixture), (source["id"] + ".provenance.json", receipt)):
            path = OUTPUT / name
            encoded = readable_json(document)
            if args.check:
                assert path.read_text() == encoded, f"Reference fixture metadata differs: {path}"
            else:
                path.write_text(encoded)
        receipts.append({"id": source["id"], "original_sha256": source["source_sha256"], "crop_pixels_sha256": receipt["crop_rgb_pixels_sha256"],
                         "proposal_counts": receipt["proposal_counts"], "proposed_uint16le_sha256": receipt["proposed_uint16le_sha256"]})
    print(json.dumps({"check": "PASS", "scope": "Exact source pixels plus explicit proposal masks; no native output claim", "fixtures": receipts}, indent=2))


if __name__ == "__main__":
    main()
