#!/usr/bin/env python3
"""Launch the real Godot world-art window without CyberSand's native game extensions.

The temporary standalone Godot project copies exact bytes from the checked-out
production shaders, LUT and tool source. No C++/Rapier/native plugins are loaded.
It owns and deletes only its newly created temporary project after Godot exits.
World-design input and exported PNG files stay outside that temporary project.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
FILES = (
    "tools/world_art_preview.tscn",
    "tools/world_art_preview.gd",
    "tools/world_art_render_rig.gd",
    "tools/world_art_grid.gd",
    "tools/world_design_pack_adapter.gd",
    "scripts/palette_shader_selector.gd",
    "scripts/material_appearance_lut.gd",
    "shaders/material_palette.gdshader",
    "shaders/material_emission.gdshader",
    "shaders/glow_composite.gdshader",
    "tests/world_art_preview_smoke.gd",
    "tests/test_world_design_pack_adapter.gd",
)
PROJECT = """; Standalone presentation-only Godot 4.7 project generated from source.

config_version=5

[application]

config/name="CyberSand World Art Preview"
config/features=PackedStringArray("4.7")

[display]

window/size/viewport_width=1600
window/size/viewport_height=900
window/size/window_width_override=1600
window/size/window_height_override=900
window/stretch/mode="canvas_items"

[rendering]

textures/canvas_textures/default_texture_filter=0
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
"""


def make_project(destination: Path) -> dict[str, str]:
    hashes = {}
    for name in FILES:
        source = GODOT / name
        if not source.is_file():
            raise FileNotFoundError(f"Missing source file: {source}")
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256(target.read_bytes()).hexdigest() != original_hash:
            raise OSError(f"Copied source differs: {name}")
        hashes[name] = original_hash
    (destination / "project.godot").write_text(PROJECT, encoding="utf-8")
    return hashes


def checked_run(command: list[str], env: dict[str, str]) -> int:
    print("WORLD_ART_EXEC", json.dumps(command, ensure_ascii=False), flush=True)
    try:
        return subprocess.call(command, env=env)
    except OSError as exc:
        print("WORLD_ART_ERROR", str(exc), file=sys.stderr, flush=True)
        return 3


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run CyberSand World Art Preview with original shader source but no game extensions."
    )
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"),
                        help="Godot 4.7 executable; defaults to GODOT or godot on PATH")
    parser.add_argument("--art-root", help="Directory containing all #454 collection folders")
    parser.add_argument("--pack", help="One specific pack.json (supersedes --art-root)")
    parser.add_argument("--design-revision", default="unverified external design source")
    parser.add_argument("--export-root", help="Absolute destination for unique screenshot sessions")
    parser.add_argument("--smoke-output", help="Absolute output directory (automated real GUI test)")
    parser.add_argument("--adapter-oracle", action="store_true",
                        help="Run source-pinned, headless RG8 adapter tests")
    parser.add_argument("--rendering-driver", default="", help="opengl3 / opengl3_angle")
    parser.add_argument("--quit-after", type=int, default=0,
                        help="Exit interactive window after this many rendered frames (CI launch smoke)")
    args = parser.parse_args()
    if args.quit_after < 0:
        parser.error("--quit-after must be nonnegative")
    if not args.adapter_oracle and not args.pack and not args.art_root:
        parser.error("Provide --art-root or --pack")
    if args.art_root and not Path(args.art_root).is_dir() and not args.pack:
        parser.error("The supplied --art-root is not a directory")
    if args.pack and not Path(args.pack).is_file():
        parser.error("The supplied --pack does not exist")
    if args.smoke_output and not Path(args.smoke_output).is_absolute():
        parser.error("The --smoke-output path must be absolute")
    if args.export_root and not Path(args.export_root).is_absolute():
        parser.error("The --export-root path must be absolute")
    with tempfile.TemporaryDirectory(prefix="cybersand-world-art-") as scratch:
        project = Path(scratch)
        hashes = make_project(project)
        print("WORLD_ART_SOURCE", json.dumps({
            "kind": "copied-unmodified-from-checkout",
            "project": str(project),
            "palette_sha256": hashes["shaders/material_palette.gdshader"],
            "emission_sha256": hashes["shaders/material_emission.gdshader"],
            "glow_sha256": hashes["shaders/glow_composite.gdshader"],
        }), flush=True)
        # Import/class scan is required on a newly assembled minimal project;
        # no native plugins are present to attempt loading.
        preflight = [args.godot, "--headless", "--path", str(project),
                     "--editor", "--import", "--quit"]
        code = checked_run(preflight, os.environ.copy())
        if code:
            return code
        if args.adapter_oracle:
            return checked_run([args.godot, "--headless", "--path", str(project),
                                "--script", "res://tests/test_world_design_pack_adapter.gd"],
                               os.environ.copy())
        command = [args.godot, "--path", str(project), "--audio-driver", "Dummy"]
        if args.rendering_driver:
            command += ["--rendering-driver", args.rendering_driver]
        if args.quit_after:
            command += ["--quit-after", str(args.quit_after)]
        if args.smoke_output:
            command += ["--script", "res://tests/world_art_preview_smoke.gd"]
        else:
            command += ["res://tools/world_art_preview.tscn"]
        command += ["--", "--design-revision=" + args.design_revision]
        if args.pack:
            command += ["--pack=" + str(Path(args.pack).resolve())]
        elif args.art_root:
            command += ["--art-root=" + str(Path(args.art_root).resolve())]
        if args.export_root:
            command += ["--export-root=" + str(Path(args.export_root).resolve())]
        if args.smoke_output:
            command += ["--smoke-output=" + str(Path(args.smoke_output).resolve())]
        return checked_run(command, os.environ.copy())


if __name__ == "__main__":
    sys.exit(main())
