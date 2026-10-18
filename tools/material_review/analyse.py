#!/usr/bin/env python3
"""Reduce capture_material_review.gd output into review derivatives.

Raw framebuffer PNGs are never modified. Every derived image is written under
<capture>/derived/ and is labelled as enlarged/annotated in its file name.

    python tools/material_review/analyse.py <capture-dir> [--compare <other-dir>]

Outputs (per capture): temporal.json (per-region frame-to-frame activity from
the 1x glow-off animation), transition.json (crossfade endpoint agreement on
eligible pixels), labelled inventory/region sheets, nearest-neighbour crops and
APNG clips. With --compare, side-by-side pair sheets go to <capture>/derived/pairs.
Requires Pillow and NumPy.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# Mirrors is_temporally_smoothed_material() in material_palette.gdshader.
SMOOTHED = {2, 3, 4, 6, 20, 21, 22, 23, 24, 25, 26, 27, 29, 30, 32, 33, 34, 36, 37}
SCALE = 6


def load_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0


def luma(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def font(size: int) -> ImageFont.ImageFont:
    for name in ("consola.ttf", "DejaVuSansMono.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def regions_for(plate: dict) -> list[dict]:
    return plate.get("swatches") or plate.get("regions") or []


def temporal(root: Path, manifest: dict) -> dict:
    """Frame-to-frame luma change inside each region (1x, glow off)."""
    result: dict = {}
    names = manifest["material_names"]
    for plate_id, plate in manifest["plates"].items():
        anim = plate.get("anim_x1_noglow")
        if not anim:
            continue
        frames = [luma(load_rgb(root / p)) for p in anim["frames"]]
        stack = np.stack(frames)
        delta = np.abs(np.diff(stack, axis=0))
        camera = anim["camera"]
        rows = []
        whole = {"mean_abs_delta": float(delta.mean()), "changing_fraction": float((delta > 2.5 / 255).mean())}
        for region in regions_for(plate):
            x, y, w, h = region["rect"]
            x -= camera[0]
            y -= camera[1]
            if x < 0 or y < 0:
                continue
            d = delta[:, y:y + h, x:x + w]
            s = stack[:, y:y + h, x:x + w]
            rows.append({
                "id": region["id"],
                "name": names[region["id"]],
                "condition": region.get("condition"),
                "mean_abs_delta": round(float(d.mean()), 5),
                "changing_fraction": round(float((d > 2.5 / 255).mean()), 4),
                "p99_abs_delta": round(float(np.percentile(d, 99)), 4),
                "temporal_std": round(float(s.std(axis=0).mean()), 5),
                "spatial_std": round(float(s.mean(axis=0).std()), 4),
            })
        result[plate_id] = {"frames": len(frames), "fps": anim["fps"], "whole": whole, "regions": rows}
    (root / "temporal.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def transition(root: Path, manifest: dict) -> dict:
    plate = manifest["plates"].get("transition")
    if not plate:
        return {}
    size = plate["current_rg8"]["size"]

    def ids(key: str) -> np.ndarray:
        raw = np.fromfile(root / plate[key]["path"], dtype=np.uint8).reshape(size[1], size[0], 2)
        return raw[..., 0].astype(int)

    previous_ids, current_ids = ids("previous_rg8"), ids("current_rg8")
    smoothed = np.vectorize(lambda m: m in SMOOTHED)
    eligible = (previous_ids != current_ids) & (smoothed(previous_ids) | smoothed(current_ids))
    unchanged = previous_ids == current_ids
    reference_previous = load_rgb(root / "transition/reference_previous_t0.00_noglow.png")
    reference_current = load_rgb(root / "transition/reference_current_t0.00_noglow.png")
    out: dict = {"eligible_pixels": int(eligible.sum()), "blends": {}}
    for blend in (0.0, 0.25, 0.5, 0.75, 1.0):
        image = load_rgb(root / f"transition/blend_x1_t0.00_noglow_b{blend:.2f}.png")
        expected = reference_previous * (1 - blend) + reference_current * blend
        error = np.abs(image - expected).max(axis=2)
        out["blends"][f"{blend:.2f}"] = {
            "eligible_max_abs_error": round(float(error[eligible].max()), 4),
            "eligible_pixels_over_2_255": int((error[eligible] > 2 / 255).sum()),
            "same_id_max_abs_error_vs_current": round(float(np.abs(image - reference_current).max(axis=2)[unchanged].max()), 4),
        }
    (root / "transition.json").write_text(json.dumps(out, indent=2) + "\n")
    return out


def labelled_sheet(root: Path, manifest: dict, plate_id: str, still: str, columns: int, pad: int = 4) -> Path | None:
    plate = manifest["plates"].get(plate_id)
    if not plate:
        return None
    image = Image.open(root / plate_id / still).convert("RGB")
    camera = [0, 0]
    regions = regions_for(plate)
    label_font = font(18)
    cells = []
    for region in regions:
        x, y, w, h = region["rect"]
        box = ((x - camera[0]) * SCALE, (y - camera[1]) * SCALE, (x - camera[0] + w) * SCALE, (y - camera[1] + h) * SCALE)
        label = f"{region['id']} {manifest['material_names'][region['id']]}"
        if region.get("condition") not in (None, -1):
            label += f" c{region['condition']}"
        cells.append((image.crop(box), label))
    cell_w = max(c[0].width for c in cells) + pad * 2
    cell_h = max(c[0].height for c in cells) + 28 + pad * 2
    rows = (len(cells) + columns - 1) // columns
    sheet = Image.new("RGB", (cell_w * columns, cell_h * rows), (20, 22, 28))
    draw = ImageDraw.Draw(sheet)
    for index, (crop, label) in enumerate(cells):
        cx, cy = (index % columns) * cell_w + pad, (index // columns) * cell_h + pad
        sheet.paste(crop, (cx, cy))
        draw.text((cx, cy + crop.height + 4), label, fill=(230, 232, 236), font=label_font)
    out = root / "derived" / f"{plate_id}_labelled_{Path(still).stem}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    return out


def crop_enlarged(root: Path, source: str, box: tuple[int, int, int, int], factor: int, name: str) -> Path:
    image = Image.open(root / source).convert("RGB").crop(box)
    image = image.resize((image.width * factor, image.height * factor), Image.NEAREST)
    out = root / "derived" / f"{name}_enlarged{factor}x.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out)
    return out


def clips(root: Path, manifest: dict) -> list[Path]:
    written = []
    for plate_id, plate in manifest["plates"].items():
        for key in ("anim_x2_glow", "pan_x2_glow_frozen", "pan_x2_glow_running"):
            clip = plate.get(key)
            if not clip:
                continue
            paths = [f if isinstance(f, str) else f["path"] for f in clip["frames"]]
            frames = [Image.open(root / p).convert("RGB") for p in paths]
            out = root / "derived" / "clips" / f"{plate_id}_{key}.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            duration = int(round(1000 / clip["fps"])) if key == "anim_x2_glow" else 120
            frames[0].save(out, save_all=True, append_images=frames[1:], duration=duration, loop=0, format="PNG")
            written.append(out)
    return written


def heatmap(root: Path, manifest: dict, plate_id: str) -> Path | None:
    """Count of per-frame luma changes per logical pixel over the 1x glow-off
    animation, overlaid in red on a dimmed first frame (4x nearest)."""
    anim = manifest["plates"].get(plate_id, {}).get("anim_x1_noglow")
    if not anim:
        return None
    stack = np.stack([luma(load_rgb(root / p)) for p in anim["frames"]])
    changes = (np.abs(np.diff(stack, axis=0)) > 2.5 / 255).sum(axis=0)
    base = load_rgb(root / anim["frames"][0]) * 0.35
    heat = changes / max(1, changes.max())
    base[..., 0] = np.maximum(base[..., 0], heat)
    base[..., 1] = np.maximum(base[..., 1], (changes > 0) * 0.35)
    image = Image.fromarray((base * 255).astype(np.uint8))
    out = root / "derived" / f"{plate_id}_temporal_heat_enlarged4x.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    image.resize((image.width * 4, image.height * 4), Image.NEAREST).save(out)
    return out


def crop_clip(root: Path, manifest: dict, plate_id: str, box: tuple[int, int, int, int], name: str) -> Path | None:
    """APNG of a crop (2x output pixels) from the 2x glow-on animation."""
    clip = manifest["plates"].get(plate_id, {}).get("anim_x2_glow")
    if not clip:
        return None
    frames = [Image.open(root / p).convert("RGB").crop(box) for p in clip["frames"]]
    out = root / "derived" / "clips" / f"{name}.apng"
    out.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=int(round(1000 / clip["fps"])), loop=0, format="PNG")
    return out


def pairs(root: Path, other: Path, manifest: dict, label_a: str, label_b: str) -> list[Path]:
    """Side-by-side before/after sheets for identical-input stills."""
    other_manifest = json.loads((other / "manifest.json").read_text())
    written = []
    title_font = font(28)
    for plate_id, plate in manifest["plates"].items():
        other_plate = other_manifest["plates"].get(plate_id)
        if not other_plate:
            continue
        if other_plate["current_rg8"]["sha256"] != plate["current_rg8"]["sha256"] or \
                other_plate["previous_rg8"]["sha256"] != plate["previous_rg8"]["sha256"]:
            print(f"skip {plate_id}: RG8 inputs differ")
            continue
        for record in plate["images"]:
            if record.get("output") != [1920, 1080] or record.get("blend", 1.0) not in (1.0,):
                continue
            a = Image.open(other / record["path"]).convert("RGB")
            b = Image.open(root / record["path"]).convert("RGB")
            sheet = Image.new("RGB", (a.width, a.height * 2 + 80), (14, 15, 20))
            draw = ImageDraw.Draw(sheet)
            draw.text((12, 4), f"{label_a}: {plate_id} {Path(record['path']).stem}", fill=(235, 235, 235), font=title_font)
            sheet.paste(a, (0, 40))
            draw.text((12, a.height + 44), f"{label_b}", fill=(235, 235, 235), font=title_font)
            sheet.paste(b, (0, a.height + 80))
            out = root / "derived" / "pairs" / f"{plate_id}_{Path(record['path']).stem}_pair.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            sheet.save(out)
            written.append(out)
    return written


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--compare", type=Path, help="earlier capture (e.g. baseline) for paired sheets")
    parser.add_argument("--labels", default="baseline,candidate")
    parser.add_argument("--no-clips", action="store_true")
    args = parser.parse_args()
    root = args.capture
    manifest = json.loads((root / "manifest.json").read_text())
    temporal(root, manifest)
    transition(root, manifest)
    labelled_sheet(root, manifest, "inventory", "still_cam0-0_t0.00_glow_b1.00.png", 9)
    labelled_sheet(root, manifest, "liquids", "still_cam0-0_t0.00_noglow_b1.00.png", 5)
    labelled_sheet(root, manifest, "construction", "still_cam0-0_t0.00_noglow_b1.00.png", 8)
    labelled_sheet(root, manifest, "emission", "still_cam0-0_t0.00_glow_b1.00.png", 7)
    for plate_id in ("street", "construction", "liquids", "inventory"):
        heatmap(root, manifest, plate_id)
    if not args.no_clips:
        clips(root, manifest)
        # Compact crops (2x pixels) where still-scenery motion was reviewed.
        crop_clip(root, manifest, "construction", (0, 88, 640, 264), "construction_glass_ice_rows_crop")
        crop_clip(root, manifest, "liquids", (0, 0, 640, 172), "liquids_trays_crop")
        crop_clip(root, manifest, "liquids", (0, 236, 640, 344), "liquids_wet_pairs_crop")
    if args.compare:
        label_a, label_b = args.labels.split(",")
        pairs(root, args.compare, manifest, label_a, label_b)


if __name__ == "__main__":
    main()
