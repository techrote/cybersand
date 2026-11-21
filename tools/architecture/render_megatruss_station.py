#!/usr/bin/env python3
"""Render source-qualified GEN-007 material cells; never synthesize geometry.

The small C++ exporter calls the ordinary immutable Generator/chunk API. This
script applies the same BASE_RGBA8 palette as test_architectural_generator.gd,
retains raw material bytes and receipts, and records every build/render input.
PNG alpha is opaque, exactly as in the established native-preview gallery.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import zipfile
import zlib

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version

from compiler_cache import build_exporter

ROOT = Path(__file__).resolve().parents[2]
GENERATION_SOURCES = ["world_generation.cpp", "generation_fields.cpp",
    "generation_typed_fields.cpp", "generation_spatial.cpp", "generation_grammar.cpp",
    "generation_planes.cpp"]
EXPORTER = "tools/architecture/megatruss_station_export.cpp"
PALETTE = "godot/scripts/material_appearance_lut.gd"
ORIGINAL_SHOWCASE_PARENT = "615828b28337f85e4663e03ba479616db4ddf764"
# The integration qualifies preservation against the authoritative repaired CLASSIC source.
PARENT = "e27ff75758ef51c7b7c8b4d8a7093343cc2ecede"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def source_inputs() -> dict[str, str]:
    paths = {p for directory in (ROOT / "native/include", ROOT / "native/src")
             for p in directory.rglob("*") if p.is_file() and p.suffix in {".hpp", ".h", ".cpp", ".inc"}}
    paths.update([ROOT / EXPORTER, Path(__file__).resolve(), ROOT / PALETTE,
                  ROOT / "tools/architecture/compiler_cache.py",
                  ROOT / "tools/architecture/test_compiler_cache.py"])
    for name in ("godot/scripts/architectural_generator_project.gd",
                 "examples/worldgen/architectural/megatruss-station.style.json",
                 "tools/architecture/requirements-render-linux.txt",
                 "tools/architecture/qualify_megatruss.py", "Makefile",
                 "native/tests/test_megatruss_station.cpp", "native/tests/test_world_generation.cpp",
                 "godot/tests/test_architectural_generator.gd",
                 "godot/tests/test_architectural_project_contract.gd",
                 ".github/workflows/gentek-megatruss-draft.yml"):
        if (ROOT / name).is_file():
            paths.add(ROOT / name)
    return {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in sorted(paths)}


def digest_ledger(ledger: dict[str, str]) -> str:
    return sha(json.dumps(ledger, sort_keys=True, separators=(",", ":")).encode())


def palette() -> list[tuple[int, int, int, int]]:
    text = (ROOT / PALETTE).read_text()
    body = text.split("const BASE_RGBA8: Array[int] = [", 1)[1].split("]", 1)[0]
    colours = [int(value, 16) for value in re.findall(r"0x[0-9a-fA-F]{8}", body)]
    if len(colours) < 132:
        raise RuntimeError("authoritative material palette is incomplete")
    return [((c >> 24) & 255, (c >> 16) & 255, (c >> 8) & 255, 255) for c in colours]


def build_executable(output: Path, ledger: dict[str, str], compiler: str, skip: bool) -> tuple[Path, dict]:
    return build_exporter(root=ROOT, output=output, ledger=ledger, compiler=compiler,
                          skip=skip, generation_sources=GENERATION_SOURCES, exporter=EXPORTER)


def campaign(seed: int, bay: int, floor: int, wall: int) -> list[dict]:
    base = dict(module="megatruss_station", module_version=1, seed=seed,
                origin=[0, 0], extent=[512, 512], bay=bay, floor=floor, wall=wall,
                doors=1, windows=1)
    specifications = [
        ("01-hero-512", "Hero — 512 × 512", {}),
        ("02-hero-landscape", "Hero — 1024 × 512", {"extent": [1024, 512]}),
        ("03-hero-large", "Hero — 1024 × 1024", {"extent": [1024, 1024]}),
    ]
    for index, variant_seed in enumerate([1, 7, 19, 42, 271828, 8675309], 4):
        specifications.append((f"{index:02d}-seed-{variant_seed}", f"Seed {variant_seed}", {"seed": variant_seed}))
    specifications.extend([
        ("10-compact-bays", "Compact bays", {"bay": 48}),
        ("11-broad-bays", "Broad bays", {"bay": 80}),
        ("12-shallow-station", "Shallow station", {"floor": 64}),
        ("13-tall-station", "Tall station", {"floor": 128}),
        ("14-thin-members", "Thin members", {"wall": 1}),
        ("15-heavy-members", "Heavy members", {"wall": 5}),
        ("16-glazing-on", "Glazing on", {"windows": 1}),
        ("17-glazing-off", "Glazing off", {"windows": 0}),
        ("18-portals-off", "Portals off", {"doors": 0}),
        ("19-negative-origin", "Signed world origin — -512, -256", {"origin": [-512, -256], "extent": [1024, 512]}),
        ("20-steel-trestle-comparison", "Steel Trestle", {"module": "trestle", "extent": [1024, 512]}),
        ("21-space-frame-comparison", "Space Frame", {"module": "space_frame", "extent": [1024, 512]}),
    ])
    return [dict(base, **changes, name=name, label=label) for name, label, changes in specifications]


def station_programmes(case: dict) -> list[dict]:
    """Test-side explanation of the sampler's single lane-1773 macro choice.

    This never emits, modifies, or substitutes any native material cell.
    """
    mask = (1 << 64) - 1

    def mix(value: int) -> int:
        value = (value + 0x9E3779B97F4A7C15) & mask
        value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & mask
        value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & mask
        return value ^ (value >> 31)

    width, height = 6 * case["bay"], 3 * case["floor"]
    x0, y0 = case["origin"]
    result = []
    for sy in range(y0 // height, (y0 + case["extent"][1] - 1) // height + 1):
        for sx in range(x0 // width, (x0 + case["extent"][0] - 1) // width + 1):
            mixed_y = mix(sy & mask)
            rotated_y = ((mixed_y << 27) | (mixed_y >> 37)) & mask
            programme = mix(case["seed"] ^ mix(sx & mask) ^ rotated_y ^ mix(1773))
            hall = (programme >> 1) % 3
            right = hall == 0 or (hall == 1 and bool(programme & 16))
            result.append({"supercell_index": [sx, sy], "origin": [sx * width, sy * height],
                "programme_hash": f"{programme:016x}",
                "primary_support_layout": "long forked transfer arms" if programme & 1 else "short arms with broad transfer capitals",
                "main_hall_position": ["left", "central", "right"][hall],
                "main_hall_bays": [1 + hall, 2 + hall],
                "upper_concourse": bool(programme & 8),
                "secondary_truss": "crossed panels" if programme & 32 else "alternating diagonals",
                "hanging_gallery": "right" if right else "left",
                "roof_crown_variant": "right monitor and mast" if programme & 64 else "left monitor and mast"})
    return result


def native_image(executable: Path, output: Path, case: dict, colours: list, materials: list[int]) -> dict:
    name = case["name"]
    raw = output / f"{name}.cells"
    values = [str(raw), case["module"], case["module_version"], case["seed"],
              *case["origin"], *case["extent"], case["bay"], case["floor"], case["wall"],
              case["doors"], case["windows"], *materials]
    native = subprocess.run([str(executable), *map(str, values)], cwd=ROOT,
                            capture_output=True, text=True, check=True, timeout=180)
    record = json.loads(native.stdout)
    cells = raw.read_bytes()
    if len(cells) != case["extent"][0] * case["extent"][1]:
        raise RuntimeError("incorrect native material payload length")
    pixels = bytes(component for material in cells for component in colours[material])
    image = Image.frombytes("RGBA", tuple(case["extent"]), pixels)
    target = output / f"{name}.png"
    image.save(target, optimize=False)
    record.update(case)
    record.update(materials={"wall": materials[0], "floor": materials[1], "window": materials[2], "accent": materials[3]},
                  material_sha256=sha(cells), png_sha256=sha(target.read_bytes()),
                  negative_space_ratio=cells.count(0) / len(cells),
                  palette_sha256=sha((ROOT / PALETTE).read_bytes()),
                  render_kind="native material cells, one pixel per cell, opaque BASE_RGBA8")
    if case["module"] == "megatruss_station":
        record["spatial_frequencies"] = {"supercell_width": 6 * case["bay"],
            "supercell_height": 3 * case["floor"], "base_bay_width": case["bay"],
            "secondary_panel_pitch": case["bay"] // 4}
        record["station_programmes"] = station_programmes(case)
    (output / f"{name}.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"case": name, "material_sha256": record["material_sha256"],
                      "negative_space_ratio": record["negative_space_ratio"]}), flush=True)
    return record


def font(size: int) -> ImageFont.ImageFont:
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/arial.ttf"):
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def overview(output: Path, cases: list[dict], name: str) -> dict:
    width, cell_h = 384, 422
    result = Image.new("RGB", (width * 3, cell_h * ((len(cases) + 2) // 3)), "#101722")
    draw = ImageDraw.Draw(result)
    for index, case in enumerate(cases):
        x, y = (index % 3) * width, (index // 3) * cell_h
        image = Image.open(output / f"{case['name']}.png").convert("RGB")
        scale = min((width - 12) / image.width, 372 / image.height)
        preview = image.resize((int(image.width * scale), int(image.height * scale)), Image.Resampling.NEAREST)
        result.paste(preview, (x + (width - preview.width) // 2, y + 36))
        draw.text((x + 8, y + 8), case["label"], fill="#d8e5ed", font=font(15))
        draw.text((x + 8, y + 406), f"bay {case['bay']}  floor {case['floor']}  wall {case['wall']}  seed {case['seed']}",
                  fill="#a0b3c5", font=font(11))
    target = output / f"{name}.png"
    result.save(target)
    return {"name": name, "png_sha256": sha(target.read_bytes()),
            "kind": "labelled contact sheet; nearest-neighbour previews only",
            "sources": [case["name"] for case in cases]}


def comparison(output: Path) -> dict:
    names = ["20-steel-trestle-comparison", "21-space-frame-comparison", "02-hero-landscape"]
    labels = ["Steel Trestle", "Space Frame", "Megatruss Station"]
    result = Image.new("RGB", (3 * 1024, 554), "#101722")
    draw = ImageDraw.Draw(result)
    for index, (name, label) in enumerate(zip(names, labels)):
        image = Image.open(output / f"{name}.png").convert("RGB")
        if image.size != (1024, 512):
            raise RuntimeError("comparison extent mismatch")
        result.paste(image, (index * 1024, 42))
        draw.text((index * 1024 + 18, 9), label + " — 1024 × 512 native cells", font=font(21), fill="#d8e5ed")
    target = output / "22-comparison-identical-scale.png"
    result.save(target)
    return {"name": "22-comparison-identical-scale", "png_sha256": sha(target.read_bytes()),
            "kind": "side-by-side 1:1 unaltered native previews with labels", "sources": names}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/megatruss-station-gallery")
    parser.add_argument("--compiler", default=os.environ.get("CXX", "g++"))
    parser.add_argument("--seed", type=int, default=271828)
    parser.add_argument("--bay", type=int, default=64)
    parser.add_argument("--floor", type=int, default=96)
    parser.add_argument("--wall", type=int, default=3)
    parser.add_argument("--materials", type=int, nargs=4, default=[58, 65, 121, 65], metavar=("SHELL", "DECK", "GLASS", "ACCENT"))
    parser.add_argument("--no-build", action="store_true", help="reuse only with matching compiler identity, source inputs and binary hash")
    parser.add_argument("--require-clean-source", action="store_true")
    parser.add_argument("--only", nargs="+", help="render only named cases during visual iteration")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    inputs = source_inputs()
    changed = []
    for path, actual in inputs.items():
        tracked = subprocess.run(["git", "show", "HEAD:" + path], cwd=ROOT, capture_output=True)
        if tracked.returncode or sha(tracked.stdout) != actual:
            changed.append(path)
    if args.require_clean_source and changed:
        raise RuntimeError("source must be committed before qualification: " + ", ".join(changed))
    executable, build = build_executable(output, inputs, args.compiler, args.no_build)
    cases = campaign(args.seed, args.bay, args.floor, args.wall)
    if args.only:
        unknown = set(args.only) - {case["name"] for case in cases}
        if unknown:
            raise RuntimeError("unknown campaign cases: " + ", ".join(sorted(unknown)))
        cases = [case for case in cases if case["name"] in args.only]
    colours = palette()
    records = [native_image(executable, output, case, colours, args.materials) for case in cases]
    composites = []
    if not args.only:
        composites.extend([overview(output, cases[:9], "23-contact-heroes-seeds"),
                           overview(output, cases[9:18], "24-contact-controls"), comparison(output)])
    if source_inputs() != inputs:
        raise RuntimeError("source changed during rendering; discard this campaign and rerun")
    source = {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
              "parent_commit": PARENT, "original_showcase_parent_commit": ORIGINAL_SHOWCASE_PARENT,
              "input_sha256": digest_ledger(inputs), "inputs": inputs,
              "uncommitted_source_paths": changed}
    manifest = {"schema": "cybersand.megatruss-station-evidence-v1", "created_utc": datetime.now(timezone.utc).isoformat(),
                "source": source, "build": build, "render_count": len(records), "cases": records,
                "render_software": {"python": platform.python_version(), "pillow": pillow_version,
                                    "zlib": zlib.ZLIB_RUNTIME_VERSION},
                "composites": composites, "limitations": [
                    "Native material previews are authoritative material cells; they are not Godot framebuffer or Windows playtest captures.",
                    "1024x512 is a native extent; ordinary Architectural Generator project presets remain square."]}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (output / "source-inputs.json").write_text(json.dumps(source, indent=2) + "\n")
    (output / "station-programmes.json").write_text(json.dumps([
        {"case": record["name"], "seed": record["seed"], "station_programmes": record["station_programmes"]}
        for record in records if "station_programmes" in record], indent=2) + "\n")
    gallery = ["# Megatruss Station — native material gallery", "",
               f"Source commit: `{source['commit']}`. Input ledger: `{source['input_sha256']}`.", "",
               "These PNGs map actual native material bytes through the ordinary preview palette.", "",
               "| Case | Extent | Bay / floor / wall | Seed | Empty | Material SHA-256 |",
               "| --- | --- | --- | --- | --- | --- |"]
    for record in records:
        gallery.append(f"| [{record['label']}]({record['name']}.png) | {'×'.join(map(str, record['extent']))} | "
                       f"{record['bay']} / {record['floor']} / {record['wall']} | {record['seed']} | "
                       f"{record['negative_space_ratio']:.1%} | `{record['material_sha256']}` |")
    for record in records:
        gallery.extend(["", f"## {record['label']}", "", f"![{record['label']}]({record['name']}.png)"])
    (output / "GALLERY.md").write_text("\n".join(gallery) + "\n")
    with zipfile.ZipFile(output / "exact-source-inputs.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in inputs:
            archive.write(ROOT / path, path)
        archive.write(output / "source-inputs.json", "source-inputs.json")
    print(f"Retained {len(records)} native PNGs and {len(composites)} comparisons/contact sheets in {output}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
