#!/usr/bin/env python3
"""Native-material qualification campaign for Seeded Typology Megablock v1.

Geometry comes exclusively from the compiled C++ Generator. Python measures and
colours its immutable uint16 little-endian cells with CyberSand's existing LUT.
The survey and eight principal gallery seeds are fixed before visual review.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
from datetime import datetime, timezone

import numpy as np
import PIL
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PARENT_HEAD = "615828b28337f85e4663e03ba479616db4ddf764"
SURVEY_SEEDS = tuple(range(32))
GALLERY_SEEDS = tuple(range(8))
GENERATION_SOURCES = (
    "world_generation", "generation_fields", "generation_typed_fields",
    "generation_spatial", "generation_grammar", "generation_planes",
)
COMPARISON_MODULES = (
    "cantilever_spine", "staggered_balcony", "bridgehouse", "stacked_arcade",
)
MODULE = "seeded_typology_megablock"


def run(command: list[str], **kwargs) -> str:
    return subprocess.check_output(command, cwd=ROOT, text=True, **kwargs).strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def native_input_hashes() -> dict[str, str]:
    paths = sorted(set(
        list((ROOT / "native/include/cybersand").glob("*.hpp")) +
        list((ROOT / "native/include/cybersand").glob("*.h")) +
        list((ROOT / "native/src").glob("*.hpp")) +
        list((ROOT / "native/src").glob("*.inc")) +
        [ROOT / f"native/src/{name}.cpp" for name in GENERATION_SOURCES] +
        [ROOT / "native/tools/gentek_megablock_capture.cpp", ROOT / "Makefile"]
    ))
    return {str(p.relative_to(ROOT)): sha256(p) for p in paths}


def build(binary: Path, compiler: str, jobs: int) -> None:
    inputs = native_input_hashes()
    objects = [f"build/worldgen-objects/normal/{name}.o" for name in GENERATION_SOURCES]
    subprocess.run(["make", f"-j{jobs}", f"CXX={compiler}", *objects], cwd=ROOT, check=True)
    binary.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        compiler, "-std=c++20", "-O2", "-g", "-Wall", "-Wextra", "-Wpedantic",
        "-Wconversion", "-Wshadow", "-Werror", "-Inative/include", *objects,
        "native/tools/gentek_megablock_capture.cpp", "-o", str(binary),
    ], cwd=ROOT, check=True)
    if inputs != native_input_hashes():
        raise RuntimeError("native source changed during build; rerun against a stable source snapshot")
    dump(Path(str(binary) + ".build.json"), {
        "native_inputs_sha256": inputs,
        "binary_sha256": sha256(binary),
        "linked_objects_sha256": {path: sha256(ROOT / path) for path in objects},
        "compiler": run([compiler, "--version"]).splitlines()[0],
    })


def palette() -> np.ndarray:
    text = (ROOT / "godot/scripts/material_appearance_lut.gd").read_text(encoding="utf-8")
    block = text.split("const BASE_RGBA8: Array[int] = [", 1)[1].split("]", 1)[0]
    colours = [int(value, 16) for value in re.findall(r"0x([0-9a-fA-F]{8})", block)]
    if len(colours) != 132:
        raise ValueError(f"expected 132 canonical material colours, found {len(colours)}")
    return np.asarray([[(c >> 24) & 255, (c >> 16) & 255, (c >> 8) & 255] for c in colours], dtype=np.uint8)


def source_identity(compiler: str, binary: Path) -> dict:
    # Include untracked new source too: a local-delta run must never masquerade as
    # execution of its unchanged HEAD. The complete input ledger is reproducible.
    paths = sorted(set(
        list((ROOT / "native/include/cybersand").glob("*.hpp")) +
        list((ROOT / "native/include/cybersand").glob("*.h")) +
        [ROOT / f"native/src/{name}.cpp" for name in GENERATION_SOURCES] +
        list((ROOT / "native/src").glob("*.inc")) +
        list((ROOT / "native/src").glob("*.hpp")) +
        [ROOT / "native/tools/gentek_megablock_capture.cpp", Path(__file__).resolve(),
         ROOT / "godot/scripts/material_appearance_lut.gd", ROOT / "Makefile",
         ROOT / "godot/scripts/architectural_generator_project.gd",
         ROOT / "godot/native_extension/cyber_world_generator.cpp",
         ROOT / "godot/native_extension/cyber_world_generator.hpp",
         ROOT / "godot/tests/test_architectural_generator.gd",
         ROOT / "godot/tests/test_architectural_project_contract.gd",
         ROOT / "godot/tests/test_megablock_project.gd",
         ROOT / "native/tests/test_world_generation.cpp",
         ROOT / "native/tests/test_seeded_typology_megablock.cpp",
         ROOT / "examples/worldgen/architectural/seeded-typology-megablock.style.json",
         ROOT / ".github/workflows/gentek-megablock-draft-gallery.yml",
         ROOT / "tools/build_native_extension.sh", ROOT / "tools/build_pinned_godot_cpp.sh",
         ROOT / "tools/requirements-build.txt"]
    ))
    inputs = {str(p.relative_to(ROOT)): sha256(p) for p in paths}
    status = run(["git", "status", "--porcelain"])
    compiler_version = run([compiler, "--version"]).splitlines()[0]
    build_identity = json.loads(Path(str(binary) + ".build.json").read_text(encoding="utf-8"))
    if (build_identity["native_inputs_sha256"] != native_input_hashes() or
            build_identity["binary_sha256"] != sha256(binary) or
            build_identity["compiler"] != compiler_version):
        raise RuntimeError("capture binary/build ledger does not match current native inputs/compiler; rebuild")
    return {
        "parent_head": PARENT_HEAD,
        "git_head": run(["git", "rev-parse", "HEAD"]),
        "git_tree": run(["git", "rev-parse", "HEAD^{tree}"]),
        "git_status": status,
        "source_state": "clean_commit" if not status else "commit_plus_recorded_local_delta",
        "inputs_sha256": inputs,
        "input_ledger_sha256": hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
        "binary_sha256": sha256(binary),
        "compiler": compiler_version,
        "compiler_flags": "-std=c++20 -O2 -g -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror",
        "platform": platform.platform(),
        "processor": platform.processor(),
        "python": platform.python_version(),
        "numpy": np.__version__,
        "pillow": PIL.__version__,
        "linked_objects_sha256": build_identity["linked_objects_sha256"],
        "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    }


def capture(binary: Path, output: Path, lut: np.ndarray, name: str, **options) -> dict:
    raw = output / "raw" / f"{name}.u16"
    command = [str(binary), "--output", str(raw)]
    for key, value in options.items():
        command.extend(["--" + key.replace("_", "-"), str(value)])
    record = json.loads(run(command))
    cells = np.fromfile(raw, dtype="<u2").reshape(record["height"], record["width"])
    if int(cells.max()) >= len(lut):
        raise ValueError("native capture returned an unknown material ID")
    png = output / "png" / f"{name}.png"
    Image.fromarray(lut[cells]).save(png)
    record.update({
        "name": name, "raw": str(raw.relative_to(output)), "png": str(png.relative_to(output)),
        "material_sha256": sha256(raw), "png_sha256": sha256(png),
        "material_encoding": "row-major uint16 little-endian existing material IDs",
        "command": command,
        "material_counts": {str(int(m)): int(n) for m, n in zip(*np.unique(cells, return_counts=True))},
    })
    if "programmes" in record:
        record["non_atrium_lots_in_capture"] = sum(record["typology_lots_in_capture"].values()) - record["typology_lots_in_capture"]["atrium"]
        for programme in record["programmes"]:
            rect = programme["protected_void"]
            left, top = rect["x"] - record["origin"][0], rect["y"] - record["origin"][1]
            right, bottom = left + rect["width"], top + rect["height"]
            visible = cells[max(0, top):min(record["height"], bottom), max(0, left):min(record["width"], right)]
            programme["visible_protected_void_cells"] = int(visible.size)
            programme["visible_protected_void_empty"] = bool(np.all(visible == 0))
            if not programme["visible_protected_void_empty"]:
                raise AssertionError(f"{name}: protected programme void contains native material")
    warnings = []
    if not 0.08 <= record["occupied_ratio"] <= 0.72:
        warnings.append("occupancy outside broad 8–72% survey guard")
    if record["isolated_single_cells"]:
        warnings.append("isolated single occupied cells")
    if record["solid_components4"] > 1:
        warnings.append("multiple 4-connected occupied components; inspect crop boundaries")
    record["warnings"] = warnings
    dump(output / "records" / f"{name}.json", record)
    print(f"{name}: {record['occupied_ratio']:.1%} occupied; {record['solid_components4']} components", flush=True)
    return record


def contact_sheet(output: Path, records: list[dict], name: str, title: str, columns: int = 4) -> None:
    thumb, gap, label, top = 256, 14, 45, 64
    rows = (len(records) + columns - 1) // columns
    canvas = Image.new("RGB", (columns * (thumb + gap) + gap, top + rows * (thumb + label + gap)), "#101722")
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 15)
        heading = ImageFont.truetype("DejaVuSans.ttf", 22)
    except OSError:
        font = heading = ImageFont.load_default()
    draw.text((gap, 16), title, fill="#e2eaf2", font=heading)
    for index, record in enumerate(records):
        x = gap + index % columns * (thumb + gap)
        y = top + index // columns * (thumb + label + gap)
        image = Image.open(output / record["png"]).convert("RGB")
        image.thumbnail((thumb, thumb), resample=Image.Resampling.NEAREST)
        canvas.paste(image, (x, y))
        draw.text((x, y + thumb + 3), record["name"], fill="#e2eaf2", font=font)
        noun = "component" if record["solid_components4"] == 1 else "components"
        draw.text((x, y + thumb + 22), f"{record['occupied_ratio']:.1%} filled · {record['solid_components4']} {noun}", fill="#a8b9ca", font=font)
    canvas.save(output / "png" / f"{name}.png")


def survey_tables(output: Path, records: list[dict]) -> None:
    fields = ["seed", "material_sha256", "occupied_ratio", "solid_components4", "typology_families",
              "largest_empty_rectangle_area", "largest_empty_rectangle_dimensions", "warnings"]
    rows = []
    for r in records:
        rect = r["largest_empty_rectangle"]
        rows.append({"seed": r["seed"], "material_sha256": r["material_sha256"],
                     "occupied_ratio": r["occupied_ratio"], "solid_components4": r["solid_components4"],
                     "typology_families": r.get("typology_families", "not instrumented"),
                     "largest_empty_rectangle_area": rect["area"],
                     "largest_empty_rectangle_dimensions": f"{rect['width']}×{rect['height']}",
                     "warnings": "; ".join(r["warnings"]) or "none"})
    with (output / "seed-survey.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader(); writer.writerows(rows)
    dump(output / "seed-survey.json", records)
    dump(output / "typology-programmes.json", {
        "diagnostic": "private source-matched production programme helper; not a runtime format or independent oracle",
        "seeds": [{"seed": r["seed"], "families": r["typology_families"],
                   "typology_lots_in_capture": r["typology_lots_in_capture"],
                   "programmes": r["programmes"]} for r in records],
    })
    lines = ["# Fixed 32-seed native material survey", "",
        "Seeds 0–31 were registered before visual review. All use 512×512, bay96, floor64, wall4, windows/doors on.", "",
        "Hashes are SHA-256 of complete row-major uint16 little-endian material cells. Components use four-neighbour adjacency.",
        "Largest empty rectangle measures observed uninterrupted negative space, not traversal or structural safety.", "",
        "| Seed | Full-map SHA-256 | Occupied | Families | Components | Largest empty rectangle | Warnings |",
        "| ---: | --- | ---: | ---: | ---: | --- | --- |"]
    for row in rows:
        lines.append(f"| {row['seed']} | `{row['material_sha256']}` | {row['occupied_ratio']:.2%} | {row['typology_families']} | {row['solid_components4']} | {row['largest_empty_rectangle_dimensions']} ({row['largest_empty_rectangle_area']} cells) | {row['warnings']} |")
    (output / "seed-survey.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def benchmark_report(output: Path, records: list[dict]) -> None:
    rows = []
    for record in records:
        n = record["width"] * record["height"]
        rows.append({"module": record["module"], "cells": n,
                     "direct_sampler_median_ms": statistics.median(record["direct_sampler_ms"]),
                     "direct_sampler_ns_per_cell": statistics.median(record["direct_sampler_ms"]) * 1e6 / n,
                     "generator_median_ms": statistics.median(record["generator_raster_ms"]),
                     "direct_sampler_ms": record["direct_sampler_ms"],
                     "generator_raster_ms": record["generator_raster_ms"]})
    dump(output / "performance.json", rows)
    lines = ["# Native performance comparison", "",
        "Same executable, compiler, 512×512 extent, seed0, bay96/floor64/wall4 and material roles. Five measured repeats after native capture and direct/native parity warm-up.",
        "Direct sampler timing isolates geometry; chunk timing includes the existing generator, candidate evaluation, receipts and raster assembly. Timings are advisory on this shared host.", "",
        "| Module | Direct median ms | Direct ns/cell | Native chunk median ms |",
        "| --- | ---: | ---: | ---: |"]
    for r in rows:
        lines.append(f"| {r['module']} | {r['direct_sampler_median_ms']:.3f} | {r['direct_sampler_ns_per_cell']:.2f} | {r['generator_median_ms']:.3f} |")
    (output / "performance.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def package_index(output: Path, records: list[dict], identity: dict) -> None:
    lookup = {record["png"]: record for record in records}
    files = sorted((output / "png").glob("*.png"))
    lead = ["hero-1024.png", "hero-512.png", "seed-diversity.png",
            "survey-contact-00-15.png", "survey-contact-16-31.png", "parameter-controls.png", "classic-comparison.png"]
    files.sort(key=lambda p: (lead.index(p.name) if p.name in lead else len(lead), p.name))
    rows, cards = [], []
    for path in files:
        relative = str(path.relative_to(output))
        record = lookup.get(relative)
        extent = "×".join(map(str, Image.open(path).size))
        if record:
            config = (f"{record['module']} v1 · seed {record['seed']} · {record['width']}×{record['height']} · "
                      f"bay {record['bay_width']} / floor {record['floor_height']} / wall {record['wall']} · "
                      f"windows {record['windows']} / doors {record['doors']} · origin {record['origin']}")
            detail = (f"{record['occupied_ratio']:.2%} occupied; {record['solid_components4']} occupied components; "
                      f"material SHA-256 {record['material_sha256']}")
        else:
            config, detail = "Labelled contact sheet; individual native rasters linked below", "Nearest-neighbour thumbnail scaling; labels are outside map cells."
        rows.append(f"| [{path.name}]({relative}) | {extent} | {config} |")
        cards.append(f'<article><a href="{html.escape(relative)}"><img loading="lazy" src="{html.escape(relative)}" alt="{html.escape(path.stem)}"></a><h2>{html.escape(path.stem)}</h2><p>{html.escape(config)}</p><small>{html.escape(detail)}</small></article>')
    (output / "gallery-index.md").write_text("\n".join([
        "# Complete native PNG gallery", "", f"{len(files)} PNGs. Source `{identity['git_head']}` ({identity['source_state']}).", "",
        "All images use native material cells and the existing CyberSand material palette. Benchmark PNGs intentionally duplicate their paired control maps.", "",
        "| PNG | Pixel size | Exact configuration |", "| --- | --- | --- |", *rows, "",
    ]), encoding="utf-8")
    (output / "index.html").write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Seeded Typology Megablock — native gallery</title><style>body{margin:0;background:#0b111b;color:#dde6ef;font:16px/1.5 system-ui,sans-serif}header,main{max-width:1500px;margin:auto;padding:28px}header{padding-bottom:0}h1{margin:0 0 8px}a{color:#8ed3ff}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:24px}article{min-width:0;background:#131e2c;padding:16px;border-radius:10px}article:first-child{grid-column:1/-1}img{width:100%;height:auto;image-rendering:pixelated}h2{font-size:18px;margin:12px 0 4px}p,small{overflow-wrap:anywhere}p{margin:4px 0}small{color:#a7b9ca}</style><header><h1>Seeded Typology Megablock</h1><p>Deterministic native material output · fixed seeds 0–31 · click an image for full resolution.</p><p><a href="seed-survey.md">32-seed survey</a> · <a href="performance.md">Performance</a> · <a href="typology-programmes.json">Typology programmes</a> · <a href="source-identity.json">Source identity</a> · <a href="gallery-index.md">All configurations</a></p></header><main>''' + "\n".join(cards) + "</main></html>\n", encoding="utf-8")
    (output / "README.md").write_text("\n".join([
        "# Seeded Typology Megablock v1 — source-matched native gallery", "",
        "Open **index.html** locally for the complete full-resolution gallery. The package is self-contained; no network or application server is needed.", "",
        f"Source commit: `{identity['git_head']}`. Source state: `{identity['source_state']}`.",
        f"Frozen parent: `{PARENT_HEAD}`. Input ledger SHA-256: `{identity['input_ledger_sha256']}`.", "",
        "## What is included", "",
        f"- {len(files)} PNGs: 512/1024 heroes, every predetermined seed 0–31, ten parameter controls, negative origin, landscape, four CLASSIC controls, benchmark control duplicates and five contact sheets.",
        "- `raw/*.u16`: complete native cells, row-major unsigned 16-bit little-endian, with dimensions in the matching `records/*.json`.",
        "- `seed-survey.csv`, `.json`, `.md`: 32 full-map SHA-256 hashes, occupancy, components, typology families, negative-space measurements and warnings.",
        "- `typology-programmes.json`: exact private production helper diagnostics, each supercell's four bands, protected voids and native empty-cell verification.",
        "- `performance.json`, `.md`: five-repeat direct-sampler and native-chunk timing comparisons; advisory shared-host measurements.",
        "- `source-identity.json`: commit/tree/local-delta state, native/frontend/test/workflow/preset/palette input hashes, linked-object hashes, compiler and capture-binary identity.",
        "- `campaign.json`, `manifest-sha256.json`: complete capture records and retained-file integrity hashes.", "",
        "## Interpretation", "",
        "The PNGs colour actual native material IDs with the existing BASE_RGBA8 palette. No geometry is drawn by Python and no image generation or shader approximation is used. Contact sheets only rescale those PNGs with nearest-neighbour sampling and add captions outside the map.", "",
        "Occupied components use four-neighbour cell adjacency and include glazing. Connected material is not proof of physical structural stability or playable traversal. Largest empty rectangles measure observed clear space; each complete undamaged supercell also has its documented protected atrium band.", "",
        "The negative-origin fixture translates the module's origin and is expected to retain local geometry. Windows-off replaces glazing with shell material, so occupancy can remain identical. Doors-off closes the lower arcade opening.", "",
        "## Reproduce", "",
        "From the recorded source checkout, with a C++20 compiler, Python, NumPy and Pillow installed:", "",
        "```sh", "python3 tools/worldgen/gentek_megablock_campaign.py --compiler g++ --output build/gentek-megablock-gallery", "```", "",
        "The tool rebuilds native capture code, refuses source mutation during build/capture and verifies the binary/build ledger before reuse. CI separately runs the complete CLASSIC suite, focused sanitizer coverage, source-built Godot integration and Windows material parity.", "",
        "Draft / HOLD research evidence. No merge, Ready promotion, physical-PC acceptance or runtime-library publication is implied.", "",
    ]), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/gentek-megablock-gallery")
    parser.add_argument("--binary", type=Path, default=ROOT / "build/gentek_megablock_capture")
    parser.add_argument("--compiler", default=os.environ.get("CXX", "g++"))
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--skip-build", action="store_true")
    args = parser.parse_args()
    output, binary = args.output.resolve(), args.binary.resolve()
    if not args.skip_build:
        build(binary, args.compiler, args.jobs)
    for child in ("raw", "png", "records"):
        (output / child).mkdir(parents=True, exist_ok=True)
    lut = palette()
    identity = source_identity(args.compiler, binary)
    dump(output / "source-identity.json", identity)
    survey = [capture(binary, output, lut, f"seed-{seed:02d}", seed=seed) for seed in SURVEY_SEEDS]
    gallery = [capture(binary, output, lut, "hero-512", seed=0),
               capture(binary, output, lut, "hero-1024", seed=0, width=1024, height=1024)]
    controls = [
        ("compact-lots", {"bay": 64}), ("large-lots", {"bay": 128}),
        ("short-programme", {"level": 40}), ("tall-programme", {"level": 96}),
        ("thin-structure", {"wall": 2}), ("heavy-structure", {"wall": 5}),
        ("windows-on", {"windows": 1}), ("windows-off", {"windows": 0}),
        ("doors-on", {"doors": 1}), ("doors-off", {"doors": 0}),
        ("negative-origin", {"origin_x": -385, "origin_y": -257}),
        ("landscape", {"width": 1024, "height": 512}),
    ]
    gallery.extend(capture(binary, output, lut, name, seed=0, **options) for name, options in controls)
    comparisons = [capture(binary, output, lut, f"compare-{module}", module=module, seed=0)
                   for module in COMPARISON_MODULES]
    benchmarks = [capture(binary, output, lut, f"benchmark-{module}", module=module, seed=0, iterations=5)
                  for module in (MODULE, *COMPARISON_MODULES)]
    contact_sheet(output, survey[:16], "survey-contact-00-15", "Megablock · fixed seeds 0–15")
    contact_sheet(output, survey[16:], "survey-contact-16-31", "Megablock · fixed seeds 16–31")
    contact_sheet(output, survey[:8], "seed-diversity", "Megablock · eight predetermined seeds")
    contact_sheet(output, gallery[2:12], "parameter-controls", "Megablock · existing parameter controls")
    contact_sheet(output, [gallery[0], *comparisons], "classic-comparison", "Local programmes and repeating CLASSIC motifs", columns=3)
    survey_tables(output, survey)
    benchmark_report(output, benchmarks)
    if identity["inputs_sha256"] != source_identity(args.compiler, binary)["inputs_sha256"]:
        raise RuntimeError("campaign inputs changed while capturing; results are incomplete and must be regenerated")
    all_records = [*survey, *gallery, *comparisons, *benchmarks]
    package_index(output, all_records, identity)
    dump(output / "campaign.json", {
        "schema": 1, "module": MODULE, "version": 1, "source": identity,
        "survey_seeds_declared_before_review": SURVEY_SEEDS,
        "principal_gallery_seeds_declared_before_review": GALLERY_SEEDS,
        "palette": "godot/scripts/material_appearance_lut.gd BASE_RGBA8; opaque RGB",
        "rendering": "native material raster only; no generated illustration or shader simulation",
        "records": all_records,
    })
    hashes = {str(path.relative_to(output)): sha256(path) for path in sorted(output.rglob("*"))
              if path.is_file() and path.name != "manifest-sha256.json"}
    dump(output / "manifest-sha256.json", hashes)
    print(f"Retained {len(list((output / 'png').glob('*.png')))} PNGs and {len(survey)} surveyed seeds in {output}", flush=True)


if __name__ == "__main__":
    main()
