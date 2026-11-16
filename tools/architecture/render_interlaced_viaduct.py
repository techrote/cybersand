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
import shlex
import subprocess
import sys
import zipfile
import zlib

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
GENERATION_SOURCES = ["generation_fields.cpp",
    "generation_typed_fields.cpp", "generation_spatial.cpp", "generation_grammar.cpp",
    "generation_planes.cpp"]
EXPORTER = "tools/architecture/interlaced_viaduct_export.cpp"
PALETTE = "godot/scripts/material_appearance_lut.gd"
PARENT = "615828b28337f85e4663e03ba479616db4ddf764"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def source_inputs() -> dict[str, str]:
    paths = {p for directory in (ROOT / "native/include", ROOT / "native/src")
             for p in directory.rglob("*") if p.is_file() and p.suffix in {".hpp", ".h", ".cpp", ".inc"}}
    paths.update([ROOT / EXPORTER, Path(__file__).resolve(), ROOT / PALETTE])
    for name in ("godot/scripts/architectural_generator_project.gd",
                 "examples/worldgen/architectural/interlaced-viaduct.style.json",
                 "tools/architecture/requirements-render-linux.txt",
                 "tools/architecture/qualify_interlaced.py", "Makefile",
                 "native/tests/test_interlaced_viaduct.cpp", "native/tests/test_world_generation.cpp",
                 "godot/tests/test_architectural_generator.gd",
                 "godot/tests/test_architectural_project_contract.gd",
                 ".github/workflows/gentek-interlaced-draft.yml"):
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
    build = ROOT / "build/interlaced-render"
    build.mkdir(parents=True, exist_ok=True)
    executable = build / ("interlaced_viaduct_export.exe" if os.name == "nt" else "interlaced_viaduct_export")
    marker = build / "build-identity.json"
    native_inputs = {p: h for p, h in ledger.items() if p.startswith("native/") or p == EXPORTER}
    input_digest = digest_ledger(native_inputs)
    if skip:
        record = json.loads(marker.read_text())
        if record["native_input_sha256"] != input_digest or record["executable_sha256"] != sha(executable.read_bytes()):
            raise RuntimeError("cached exporter does not match the current native source inputs")
        return executable, record
    object_paths = ["build/worldgen-objects/normal/" + Path(name).stem + ".o" for name in GENERATION_SOURCES]
    object_command = ["make", "-j2", *object_paths, "CXX=" + compiler]
    prepared = subprocess.run(object_command, cwd=ROOT, capture_output=True, text=True, timeout=1800)
    if prepared.returncode:
        (output / "exporter-build.log").write_text(prepared.stdout + prepared.stderr)
        raise RuntimeError("native object preparation failed: " + prepared.stderr)
    command = [*shlex.split(compiler), "-std=c++20", "-O2", "-g0", "-Wall", "-Wextra",
               "-Wpedantic", "-Wconversion", "-Wshadow", "-Werror", "-Inative/include",
               *object_paths, EXPORTER, "-o", str(executable)]
    print("Building native exporter", flush=True)
    process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=1800)
    (output / "exporter-build.log").write_text(prepared.stdout + prepared.stderr + process.stdout + process.stderr)
    if process.returncode:
        raise RuntimeError("native exporter compilation failed:\n" + process.stderr)
    record = {"native_input_sha256": input_digest, "inputs": native_inputs,
              "compiler": subprocess.check_output([*shlex.split(compiler), "--version"], text=True).splitlines()[0],
              "object_build_command": object_command, "command": command, "executable_sha256": sha(executable.read_bytes()),
              "build_log_sha256": sha((output / "exporter-build.log").read_bytes())}
    marker.write_text(json.dumps(record, indent=2) + "\n")
    return executable, record


def campaign(seed: int, bay: int, floor: int, wall: int) -> list[dict]:
    base = dict(module="interlaced_viaduct", module_version=1, seed=seed,
                origin=[0, 0], extent=[512, 512], bay=bay, floor=floor, wall=wall,
                doors=1, windows=1, layers=3)
    specifications = [
        ("01-hero-512", "Hero — 512 × 512", {}),
        ("02-hero-landscape", "Hero — 1024 × 512", {"extent": [1024, 512]}),
        ("03-hero-large", "Hero — 1024 × 1024", {"extent": [1024, 1024]}),
    ]
    for index, variant_seed in enumerate([1, 7, 19, 42, 271828, 8675309], 4):
        specifications.append((f"{index:02d}-seed-{variant_seed}", f"Seed {variant_seed}", {"seed": variant_seed}))
    specifications.extend([
        ("10-narrow-bay", "Narrow structural bay", {"bay": 48}),
        ("11-broad-bay", "Broad structural bay", {"bay": 112}),
        ("12-short-vertical", "Short vertical separation", {"floor": 40}),
        ("13-tall-vertical", "Tall vertical separation", {"floor": 96}),
        ("14-thin-structure", "Thin structure", {"wall": 1}),
        ("15-heavy-structure", "Heavy structure", {"wall": 5}),
        ("16-windows-on", "Pierhead glazing on", {"windows": 1}),
        ("17-windows-off", "Pierhead glazing off", {"windows": 0}),
        ("18-doors-on", "Pier portals on", {"doors": 1}),
        ("19-doors-off", "Pier portals off", {"doors": 0}),
        ("20-negative-origin", "Signed origin — -517, -263", {"origin": [-517, -263]}),
        ("21-arched-viaduct", "Arched Viaduct v2", {"module": "arcade", "module_version": 2}),
        ("22-hanging-arcade", "Hanging Arcade", {"module": "hanging_arcade"}),
        ("23-suspended-deck", "Suspended Deck", {"module": "suspended_deck"}),
        ("24-primary-only", "Diagnostic — primary only", {"layers": 1}),
        ("25-secondary-only", "Diagnostic — secondary only", {"layers": 2}),
        ("26-combined", "Diagnostic — combined", {"layers": 3}),
    ])
    return [dict(base, **changes, name=name, label=label) for name, label, changes in specifications]


def native_image(executable: Path, output: Path, case: dict, colours: list, materials: list[int]) -> dict:
    name = case["name"]
    raw = output / f"{name}.cells"
    values = [str(raw), case["module"], case["module_version"], case["seed"],
              *case["origin"], *case["extent"], case["bay"], case["floor"], case["wall"],
              case["doors"], case["windows"], *materials, case["layers"]]
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
    if case["layers"] != 3:
        record["render_kind"] = "native private source-layer ablation, not a chunk-generated ordinary preset"
    record["supercell"] = [3 * case["bay"], 3 * case["floor"]]
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


def comparison(output: Path, names: list[str], labels: list[str], target_name: str) -> dict:
    result = Image.new("RGB", (512 * len(names), 552), "#101722")
    draw = ImageDraw.Draw(result)
    for index, (name, label) in enumerate(zip(names, labels)):
        image = Image.open(output / f"{name}.png").convert("RGB")
        if image.size != (512, 512):
            raise RuntimeError("comparison extent mismatch")
        result.paste(image, (index * 512, 40))
        draw.text((index * 512 + 12, 9), label, font=font(19), fill="#d8e5ed")
    target = output / (target_name + ".png")
    result.save(target)
    return {"name": target_name, "png_sha256": sha(target.read_bytes()),
            "kind": "side-by-side 1:1 unaltered native previews with labels", "sources": names}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/interlaced-viaduct-gallery")
    parser.add_argument("--compiler", default=os.environ.get("CXX", "g++"))
    parser.add_argument("--seed", type=int, default=271828)
    parser.add_argument("--bay", type=int, default=80)
    parser.add_argument("--floor", type=int, default=64)
    parser.add_argument("--wall", type=int, default=3)
    parser.add_argument("--materials", type=int, nargs=4, default=[98, 65, 121, 65], metavar=("SHELL", "DECK", "GLASS", "ACCENT"))
    parser.add_argument("--no-build", action="store_true", help="reuse exporter only if its input and binary hashes match")
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
    checks = subprocess.run([str(executable), "--check-layers"], cwd=ROOT, capture_output=True, text=True, check=True, timeout=180)
    (output / "layer-checks.json").write_text(checks.stdout)
    records = [native_image(executable, output, case, colours, args.materials) for case in cases]
    composites = []
    if not args.only:
        composites.extend([overview(output, cases[:9], "27-contact-heroes-seeds"),
                           overview(output, cases[9:20], "28-contact-controls"),
                           comparison(output, ["24-primary-only", "25-secondary-only", "26-combined"],
                                      ["Primary masonry", "Secondary suspended frame", "Interlaced Viaduct"], "29-layer-comparison"),
                           comparison(output, ["21-arched-viaduct", "22-hanging-arcade", "23-suspended-deck", "01-hero-512"],
                                      ["Arched Viaduct v2", "Hanging Arcade", "Suspended Deck", "Interlaced Viaduct"], "30-classic-comparison")])
    if source_inputs() != inputs:
        raise RuntimeError("source changed during rendering; discard this campaign and rerun")
    source = {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
              "parent_commit": PARENT, "input_sha256": digest_ledger(inputs), "inputs": inputs,
              "uncommitted_source_paths": changed}
    manifest = {"schema": "cybersand.interlaced-viaduct-evidence-v1", "created_utc": datetime.now(timezone.utc).isoformat(),
                "source": source, "build": build, "render_count": len(records), "cases": records,
                "render_software": {"python": platform.python_version(), "pillow": pillow_version,
                                    "zlib": zlib.ZLIB_RUNTIME_VERSION},
                "composites": composites, "limitations": [
                    "Native material previews are authoritative material cells; they are not Godot framebuffer or Windows playtest captures.",
                    "Diagnostic layer images call the same native compose function with one layer disabled; ordinary combined captures use full chunk jobs.",
                    "1024x512 is a native extent; ordinary Architectural Generator project presets remain square."]}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (output / "source-inputs.json").write_text(json.dumps(source, indent=2) + "\n")
    gallery = ["# Interlaced Viaduct — native material gallery", "",
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
