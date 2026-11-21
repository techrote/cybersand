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
EXPORTER = "tools/architecture/interlock_brutalism_export.cpp"
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
                 "examples/worldgen/architectural/interlock-brutalism.style.json",
                 "tools/architecture/requirements-render-linux.txt",
                 "tools/architecture/qualify_interlock.py", "tools/architecture/test_qualify_interlock.py", "Makefile",
                 "godot/native_extension/cyber_world_generator.cpp",
                 "native/tests/test_interlock_brutalism.cpp", "native/tests/test_world_generation.cpp",
                 "godot/tests/test_architectural_generator.gd",
                 "godot/tests/test_architectural_project_contract.gd",
                 ".github/workflows/gentek-interlock-draft.yml"):
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
    base = dict(module="interlock_brutalism", module_version=1, seed=seed,
                origin=[0, 0], extent=[512, 512], bay=bay, floor=floor, wall=wall,
                doors=1, windows=1)
    specs = [
        ("01-hero-512", "Interlock Brutalism — 512 × 512", {}),
        ("02-hero-landscape", "Broad composition — 1024 × 512", {"extent": [1024, 512]}),
        ("03-hero-large", "Large composition — 1024 × 1024", {"extent": [1024, 1024]}),
        ("04-hero-vertical", "Vertical composition — 512 × 1024", {"extent": [512, 1024]}),
    ]
    for index, variant_seed in enumerate([0, 1, 7, 19, 42, 123, 2026, 8675309], 5):
        specs.append((f"{index:02d}-seed-{variant_seed}", f"Seed {variant_seed}", {"seed": variant_seed}))
    specs.extend([
        ("13-narrow-bays", "Narrow bays — 48 cells", {"bay": 48}),
        ("14-wide-bays", "Wide bays — 96 cells", {"bay": 96}),
        ("15-short-rhythm", "Short vertical rhythm — 48 cells", {"floor": 48}),
        ("16-tall-rhythm", "Tall vertical rhythm — 96 cells", {"floor": 96}),
        ("17-thin-structure", "Thin structure — 1 cell", {"wall": 1}),
        ("18-heavy-structure", "Heavy structure — 5 cells", {"wall": 5}),
        ("19-glazing-on", "Glazing enabled", {"windows": 1}),
        ("20-glazing-off", "Glazing disabled", {"windows": 0}),
        ("21-doors-on", "Service openings enabled", {"doors": 1}),
        ("22-doors-off", "Service openings disabled", {"doors": 0}),
        ("23-negative-origin", "Negative world origin — -257, -193", {"origin": [-257, -193]}),
    ])
    for index, name in enumerate(['cantilever_spine', 'double_cantilever', 'buttress_wall', 'shelf_stack'],24):
        specs.append((f"{index:02d}-comparison-{name}", name.replace("_", " ").title(), {"module": name,"extent":[1024,512]}))
    specs.extend([('28-central-void', 'Central void — native crop', {'origin': [32, 96], 'extent': [192, 288]}), ('29-root-detail', 'Root and recess — native crop', {'origin': [0, 0], 'extent': [256, 256]})])
    specs.extend([
        ('30-void-sequence-middle', 'Central void sequence — middle', {'origin': [64, 216], 'extent': [224, 288]}),
        ('31-void-sequence-lower', 'Central void sequence — lower', {'origin': [64, 432], 'extent': [224, 288]}),
    ])
    # A consecutive survey is retained in full, rather than selected for aesthetics.
    for survey_seed in range(32):
        specs.append((f"survey-{survey_seed:02d}", f"Consecutive seed survey {survey_seed}", {"seed":survey_seed}))
    return [dict(base, **changes, name=name, label=label) for name, label, changes in specs]


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
    names = ['24-comparison-cantilever_spine', '25-comparison-double_cantilever', '26-comparison-buttress_wall', '27-comparison-shelf_stack'] + ["02-hero-landscape"]
    labels = ['Cantilever Spine', 'Double Cantilever', 'Buttress Wall', 'Shelf Stack'] + ["Interlock Brutalism"]
    result = Image.new("RGB", (1024, 554 * len(names)), "#101722")
    draw = ImageDraw.Draw(result)
    for index, (name, label) in enumerate(zip(names, labels)):
        native = Image.open(output / f"{name}.png").convert("RGB")
        if native.size != (1024, 512):
            raise RuntimeError("comparison extent mismatch")
        result.paste(native, (0, index * 554 + 42))
        draw.text((18, index * 554 + 9), label + " — same scale / seed / palette", font=font(21), fill="#d8e5ed")
    target = output / "comparison-native-scale.png"
    result.save(target)
    return {"name": "comparison-native-scale", "png_sha256": sha(target.read_bytes()),
            "kind": "unaltered 1:1 native previews with external labels", "sources": names}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/interlock-brutalism-gallery")
    parser.add_argument("--compiler", default=os.environ.get("CXX", "g++"))
    parser.add_argument("--seed", type=int, default=271828)
    parser.add_argument("--bay", type=int, default=80)
    parser.add_argument("--floor", type=int, default=72)
    parser.add_argument("--wall", type=int, default=3)
    parser.add_argument("--materials", type=int, nargs=4, default=[62, 114, 121, 114], metavar=("SHELL", "DECK", "GLASS", "ACCENT"))
    parser.add_argument("--no-build", action="store_true", help="reuse only with matching compiler identity, source inputs and binary hash")
    parser.add_argument("--require-clean-source", action="store_true")
    parser.add_argument("--only", nargs="+", help="render only named cases during visual iteration")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    frozen_head = git("rev-parse", "HEAD")
    frozen_tree = git("rev-parse", "HEAD^{tree}")
    inputs = source_inputs()
    changed = []
    for path, actual in inputs.items():
        tracked = subprocess.run(["git", "show", frozen_head + ":" + path], cwd=ROOT, capture_output=True)
        if tracked.returncode or sha(tracked.stdout) != actual:
            changed.append(path)
    if args.require_clean_source and changed:
        raise RuntimeError("source must be committed before qualification: " + ", ".join(changed))
    if args.require_clean_source and git("status", "--porcelain", "--untracked-files=all", "--", *sorted(inputs)):
        raise RuntimeError("source input index and working tree must be clean before rendering")
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
        composites.extend([overview(output, cases[:12], "contact-heroes-seeds"),
                           overview(output, cases[12:22], "contact-controls"),
                           overview(output, [c for c in cases if c["name"].startswith("survey-")], "contact-32-seed-survey"), comparison(output)])
    if source_inputs() != inputs or git("rev-parse", "HEAD") != frozen_head or git("rev-parse", "HEAD^{tree}") != frozen_tree:
        raise RuntimeError("source changed during rendering; discard this campaign and rerun")
    source = {"commit": frozen_head, "tree": frozen_tree,
              "parent_commit": PARENT, "original_showcase_parent_commit": ORIGINAL_SHOWCASE_PARENT,
              "input_sha256": digest_ledger(inputs), "inputs": inputs,
              "uncommitted_source_paths": changed}
    manifest = {"schema": "cybersand.interlock-brutalism-evidence-v1", "created_utc": datetime.now(timezone.utc).isoformat(),
                "source": source, "build": build, "render_count": len(records), "cases": records,
                "render_software": {"python": platform.python_version(), "pillow": pillow_version,
                                    "zlib": zlib.ZLIB_RUNTIME_VERSION},
                "composites": composites, "limitations": [
                    "Native material previews are authoritative material cells; they are not Godot framebuffer or Windows playtest captures.",
                    "1024x512 is a native extent; ordinary Architectural Generator project presets remain square."]}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (output / "source-inputs.json").write_text(json.dumps(source, indent=2) + "\n")
    gallery = ["# Interlock Brutalism — native material gallery", "",
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
