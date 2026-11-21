#!/usr/bin/env python3
"""Compile immutable before/after sources and render CLASSIC repair comparisons.

Both executables call the ordinary native Generator/chunk API using the same
retained exporter driver. Fresh snapshot-local object files prevent shared-cache
or working-tree changes from altering the named source identities.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tarfile
import time

from PIL import Image, ImageDraw

from gentek80_campaign import component_metrics, font, save, sha

ROOT = Path(__file__).resolve().parents[2]
EXPORTER = "tools/architecture/megatruss_station_export.cpp"
PALETTE = "godot/scripts/material_appearance_lut.gd"
SOURCES = ["world_generation.cpp", "generation_fields.cpp", "generation_typed_fields.cpp",
           "generation_spatial.cpp", "generation_grammar.cpp", "generation_planes.cpp"]
CASES = [
    {"name": "suspended-deck-contacts", "module": "suspended_deck", "extent": [96, 72],
     "bay": 96, "floor": 72, "wall": 3, "materials": [62, 66, 121, 66],
     "label": "Suspended Deck: upper carrier / hanger contact"},
    {"name": "rib-vault-steep", "module": "rib_vault", "extent": [32, 128],
     "bay": 32, "floor": 128, "wall": 1, "materials": [100, 62, 123, 62],
     "label": "Rib Vault: steep face-connected rib stroke"},
    {"name": "ring-pier-supports", "module": "ring_pier", "extent": [96, 88],
     "bay": 96, "floor": 88, "wall": 3, "materials": [62, 66, 121, 66],
     "label": "Ring Pier: diamond-to-deck support stems"},
    {"name": "tripod-frame-continuity", "module": "tripod_frame", "extent": [96, 176],
     "bay": 96, "floor": 88, "wall": 3, "materials": [62, 66, 121, 66],
     "label": "Tripod Frame: transfer deck / upper neck continuity"},
    {"name": "cascade-terrace-continuity", "module": "cascade_terrace", "extent": [96, 192],
     "bay": 96, "floor": 96, "wall": 3, "materials": [62, 66, 121, 66],
     "label": "Cascade Terrace: stepped decks meet the continuous core"},
    {"name": "scalloped-vault-compact", "module": "scalloped_vault", "extent": [48, 64],
     "bay": 48, "floor": 64, "wall": 2, "materials": [62, 66, 121, 66],
     "label": "Scalloped Vault: compact steep ribs retain face contact"},
    {"name": "suspended-deck-window-frame", "module": "suspended_deck", "extent": [96, 72],
     "bay": 96, "floor": 72, "wall": 3, "materials": [62, 66, 121, 66], "windows": True,
     "preserve_glazing": True, "kind": "pane close-up",
     "label": "Suspended Deck: framed glazing preserves the full pane"},
    {"name": "buttress-wall-window-frame", "module": "buttress_wall", "extent": [96, 80],
     "bay": 96, "floor": 80, "wall": 4, "materials": [104, 98, 120, 98], "windows": True,
     "preserve_glazing": True, "kind": "pane close-up",
     "label": "Buttress Wall: framed light slot preserves the full pane"},
]


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=ROOT)


def capture_snapshot(ref: str, directory: Path, exporter: bytes) -> dict:
    commit = git("rev-parse", ref + "^{commit}").decode().strip()
    tree = git("rev-parse", commit + "^{tree}").decode().strip()
    archive = git("archive", "--format=tar", commit, "--", "native/include", "native/src")
    directory.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as package:
        for member in package.getmembers():
            target = directory / member.name
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                source = package.extractfile(member)
                assert source is not None
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read())
    driver = directory / "repair_export.cpp"
    driver.write_bytes(exporter)
    inputs = {path.relative_to(directory).as_posix(): sha(path.read_bytes())
              for path in sorted(directory.rglob("*")) if path.is_file()}
    return {"commit": commit, "tree": tree, "inputs": inputs, "exporter_sha256": sha(exporter),
            "source_archive_sha256": sha(archive)}


def build(directory: Path, compiler: str) -> dict:
    command_prefix = shlex.split(compiler)
    version = subprocess.check_output(command_prefix + ["--version"], text=True).strip()
    executable = Path(shutil.which(command_prefix[0]) or command_prefix[0]).resolve()
    object_dir = directory / "objects"
    object_dir.mkdir()
    flags = ["-std=c++20", "-O2", "-g0", "-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow", "-Werror", "-Inative/include"]
    paths = ["native/src/" + source for source in SOURCES] + ["repair_export.cpp"]

    def compile_one(source: str) -> tuple[list[str], str]:
        target = object_dir / (Path(source).stem + ".o")
        command = command_prefix + flags + ["-c", source, "-o", str(target)]
        result = subprocess.run(command, cwd=directory, text=True, capture_output=True, timeout=1800)
        if result.returncode:
            raise RuntimeError("Fresh repair compiler failed: " + " ".join(command) + "\n" + result.stdout + result.stderr)
        return command, result.stdout + result.stderr

    began = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(compile_one, paths))
    target = directory / "repair_export"
    command = command_prefix + [str(object_dir / (Path(path).stem + ".o")) for path in paths] + ["-o", str(target)]
    linked = subprocess.run(command, cwd=directory, text=True, capture_output=True, timeout=300)
    log = "\n".join(result[1] for result in results) + linked.stdout + linked.stderr
    (directory / "build.log").write_text(log, encoding="utf-8")
    if linked.returncode:
        raise RuntimeError("Fresh repair link failed: " + log)
    return {"compiler": version, "compiler_command": command_prefix,
            "compiler_executable": str(executable), "compiler_executable_sha256": sha(executable.read_bytes()),
            "commands": [result[0] for result in results] + [command], "elapsed_seconds": time.monotonic() - began,
            "executable": str(target), "executable_sha256": sha(target.read_bytes()),
            "build_log_sha256": sha((directory / "build.log").read_bytes())}


def render(binary: Path, directory: Path, case: dict, colours: list) -> dict:
    raw = directory / (case["name"] + ".cells")
    arguments = [raw, case["module"], 1, 271828, 0, 0, *case["extent"], case["bay"], case["floor"],
                 case["wall"], 1, int(case.get("windows", False)), *case["materials"]]
    result = subprocess.run([str(binary), *map(str, arguments)], cwd=ROOT, text=True, capture_output=True, timeout=180, check=True)
    receipt = json.loads(result.stdout)
    cells = raw.read_bytes()
    if len(cells) != case["extent"][0] * case["extent"][1]:
        raise RuntimeError("Repair native payload extent mismatch")
    image = Image.frombytes("RGBA", tuple(case["extent"]), bytes(component for value in cells for component in colours[value]))
    target = directory / (case["name"] + ".png")
    image.save(target)
    mask = cells.translate(bytes([0] + [1] * 255))
    receipt.update({"case": case, "raw": raw.name, "png": target.name, "material_sha256": sha(cells),
                    "png_sha256": sha(target.read_bytes()), "occupied_components": component_metrics(mask, *case["extent"], 1)})
    if case["name"] == "suspended-deck-contacts":
        width, wall = case["extent"][0], case["wall"]
        contact_columns = [x for centre in (case["bay"] // 4, 3 * case["bay"] // 4)
                           for x in range(centre - wall, centre + wall + 1)]
        # Whole-bay connectivity cannot detect this defect: the side walls and
        # lower deck supply an indirect route even when the upper joint is open.
        receipt["upper_hanger_contact_columns"] = len(contact_columns)
        receipt["upper_hanger_contact_gaps"] = sum(cells[wall * width + x] == 0 or cells[(wall - 1) * width + x] == 0
                                                    for x in contact_columns)
    save(directory / (case["name"] + ".json"), receipt)
    return receipt


def compare(output: Path, before: dict, after: dict) -> dict:
    width, height = 720, 640
    canvas = Image.new("RGB", (width * 2, height), "#101722")
    draw = ImageDraw.Draw(canvas)
    case = before["case"]
    draw.text((20, 15), case["label"], fill="#edf4fa", font=font(23))
    for index, (title, receipt) in enumerate([("BEFORE", before), ("AFTER", after)]):
        path = output / title.lower() / receipt["png"]
        draw.text((index * width + 20, 58), title + " · " + receipt["commit"][:12], fill="#aebfd1", font=font(18))
        materials = case["materials"]
        window_label = "on" if case.get("windows") else "off"
        draw.text((index * width + 20, 84),
                  f"Native palette: shell {materials[0]} · deck {materials[1]} · glass {materials[2]} · accent {materials[3]} · windows {window_label}",
                  fill="#aebfd1", font=font(13))
        with Image.open(path) as original:
            scale = min((width - 40) // original.width, 480 // original.height)
            image = original.convert("RGB").resize((original.width * scale, original.height * scale), Image.Resampling.NEAREST)
            canvas.paste(image, (index * width + (width - image.width) // 2, 104 + (480 - image.height) // 2))
        draw.text((index * width + 20, 596), f"Cardinal occupied components: {receipt['occupied_components']['count']} · {scale}× native pixels",
                  fill="#d7e3ee", font=font(17))
        if "upper_hanger_contact_gaps" in receipt:
            draw.text((index * width + 20, 620), f"Missing direct upper hanger contacts: {receipt['upper_hanger_contact_gaps']} / {receipt['upper_hanger_contact_columns']}",
                      fill="#d7e3ee", font=font(13))
        if case.get("preserve_glazing"):
            cells = (output / title.lower() / receipt["raw"]).read_bytes()
            draw.text((index * width + 20, 620), f"Original glazing retained: {cells.count(case['materials'][2])} native cells",
                      fill="#d7e3ee", font=font(13))
    target = output / (case["name"] + "--before-after.png")
    canvas.save(target)
    old = (output / "before" / before["raw"]).read_bytes()
    new = (output / "after" / after["raw"]).read_bytes()
    repaired = after["occupied_components"]["count"] == 1
    if case["name"] == "suspended-deck-contacts":
        repaired = repaired and before["upper_hanger_contact_gaps"] > 0 and after["upper_hanger_contact_gaps"] == 0
    else:
        repaired = repaired and before["occupied_components"]["count"] > 1
    glazing_preserved = None
    if case.get("preserve_glazing"):
        glass = case["materials"][2]
        glazing_preserved = old.count(glass) > 0 and all((a == glass) == (b == glass) for a, b in zip(old, new))
        repaired = repaired and glazing_preserved
    return {"case": case["name"], "image": target.name, "png_sha256": sha(target.read_bytes()),
            "kind": case.get("kind", "structural repair"), "glazing_cells_preserved": glazing_preserved,
            "changed_material_cells": sum(a != b for a, b in zip(old, new)),
            "added_occupied_cells": sum(a == 0 and b != 0 for a, b in zip(old, new)),
            "removed_occupied_cells": sum(a != 0 and b == 0 for a, b in zip(old, new)),
            "before_components": before["occupied_components"]["count"], "after_components": after["occupied_components"]["count"],
            "repair_validated": repaired, "before": before, "after": after}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True, help="immutable pre-repair CLASSIC source")
    parser.add_argument("--after", default="HEAD", help="candidate source commit; extracted, never read from mutable source")
    parser.add_argument("--compiler", default="g++")
    parser.add_argument("--output", type=Path, default=ROOT / "build/gentek80-repair-comparison")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    after_sha = git("rev-parse", args.after + "^{commit}").decode().strip()
    tool_inputs = {}
    for relative in ("tools/architecture/gentek80_repair_comparison.py", "tools/architecture/gentek80_campaign.py"):
        working = (ROOT / relative).read_bytes().replace(b"\r\n", b"\n")
        committed = git("show", after_sha + ":" + relative).replace(b"\r\n", b"\n")
        if working != committed:
            raise RuntimeError("Repair evidence tool differs from the named after-source: " + relative)
        tool_inputs[relative] = sha(working)
    exporter = git("show", after_sha + ":" + EXPORTER)
    palette_source = git("show", after_sha + ":" + PALETTE)
    body = palette_source.decode().split("const BASE_RGBA8: Array[int] = [", 1)[1].split("]", 1)[0]
    values = [int(value, 16) for value in re.findall(r"0x[0-9a-fA-F]{8}", body)]
    colours = [((value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, 255) for value in values]
    records = {}
    for label, ref in [("before", args.before), ("after", after_sha)]:
        directory = output / label
        snapshot = directory / "source"
        if snapshot.exists():
            raise RuntimeError("Refusing to reuse previous native snapshot/build cache: " + str(snapshot))
        source = capture_snapshot(ref, snapshot, exporter)
        compiled = build(snapshot, args.compiler)
        renders = [render(Path(compiled["executable"]), directory, case, colours) for case in CASES]
        for receipt in renders:
            receipt["commit"] = source["commit"]
        records[label] = {"source": source, "build": compiled, "renders": renders}
        save(directory / "identity.json", records[label])
        print(label + " " + source["commit"], flush=True)
    comparisons = [compare(output, before, after) for before, after in zip(records["before"]["renders"], records["after"]["renders"])]
    successful = all(case["repair_validated"] and case["changed_material_cells"] > 0 for case in comparisons)
    report = {"schema": 1, "status": "pass" if successful else "fail", "comparisons": comparisons,
              "before_source": records["before"]["source"]["commit"], "after_source": records["after"]["source"]["commit"],
              "palette_source": after_sha, "palette_sha256": sha(palette_source), "exporter_source": after_sha,
              "comparison_tool_source": after_sha, "comparison_tool_inputs_sha256": tool_inputs,
              "scope": "Same native chunk fixture and exporter; immutable sources compiled afresh with one compiler. Geometric contact evidence, not physical stability."}
    save(output / "repair-comparison.json", report)
    (output / "README.md").write_text("# CLASSIC repair comparison\n\n" + "\n\n".join(
        f"## {case['case']}\n\n![Native before/after]({case['image']})\n\nChanged cells: {case['changed_material_cells']}; occupied components {case['before_components']} → {case['after_components']}." for case in comparisons) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "comparisons": [{k: case[k] for k in ["case", "changed_material_cells", "before_components", "after_components"]} for case in comparisons]}))
    return 0 if successful else 1


if __name__ == "__main__":
    raise SystemExit(main())
