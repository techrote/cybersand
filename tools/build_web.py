#!/usr/bin/env python3
"""Build CyberSand's C++ engine for Godot Web without altering desktop files.

Requires pinned godot-cpp, activated Emscripten 4.0.11, SCons 4.10.1,
Godot 4.7 and its Web templates. See docs/WEB_DEMO.md.
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

ROOT = Path(__file__).resolve().parents[1]
CPP_REV = "101ae38034304346a46ea9ea84ae156d3e860496"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
SOURCES = [
    "godot/native_extension/cyber_native_cell_world.cpp",
    "godot/native_extension/register_types.cpp",
    "native/src/world.cpp", "native/src/render_snapshot.cpp",
    "native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
]

def run(args: list[str], *, cwd: Path = ROOT, timeout: int = 1200) -> None:
    print("+", " ".join(map(str, args)), flush=True)
    subprocess.run(args, cwd=cwd, check=True, timeout=timeout)

def output(args: list[str]) -> str:
    return subprocess.check_output(args, text=True, timeout=30).strip()

def compile_extension(cpp: Path, dest: Path, platform: str, threaded: bool) -> Path:
    if output(["git", "-C", str(cpp), "rev-parse", "HEAD"]) != CPP_REV:
        raise RuntimeError("godot-cpp revision does not match M11")
    if output(["git", "-C", str(cpp), "status", "--porcelain", "--untracked-files=no"]):
        raise RuntimeError("godot-cpp tracked source is dirty")
    web = platform == "web"
    target = "template_release" if web else "template_debug"
    arch = "wasm32" if web else "x86_64"
    run([sys.executable, "-m", "SCons", "-C", str(cpp), f"platform={platform}",
         f"target={target}", f"arch={arch}", f"threads={'yes' if threaded else 'no'}",
         "api_version=4.7", f"build_profile={ROOT / 'tools/web/build_profile.json'}",
         "lto=none", "debug_symbols=no", "-j", os.environ.get("SCONS_JOBS", "2")])
    libs = list((cpp / "bin").glob(f"libgodot-cpp.{platform}.{target}.{arch}*.a"))
    libs = [p for p in libs if ("nothreads" not in p.name) == threaded]
    if len(libs) != 1:
        raise RuntimeError(f"Ambiguous godot-cpp library: {libs}")
    dest.mkdir(parents=True, exist_ok=True)
    name = ("libcybersand_native.web." + ("threads" if threaded else "nothreads") + ".wasm"
            if web else "libcybersand_native.linux.x86_64.so")
    artifact = dest / name
    flags = ["-std=c++20", "-O3", "-DNDEBUG", "-fPIC", "-fno-math-errno"]
    if web:
        flags += ["-sSIDE_MODULE=1", "-sWASM_BIGINT", "-sMEMORY64=0",
                  "-sSUPPORT_LONGJMP=wasm", "-fwasm-exceptions", "-fvisibility=hidden"]
        if threaded:
            flags += ["-pthread"]
    else:
        flags += ["-shared", "-pthread"]
    includes = [ROOT / "native/include", cpp / "include", cpp / "gen/include", cpp / "gdextension"]
    command = ["em++" if web else os.environ.get("CXX", "g++"), *flags]
    command += [f"-I{p}" for p in includes]
    command += [str(ROOT / p) for p in SOURCES] + [str(libs[0]), "-o", str(artifact)]
    run(command)
    data = artifact.read_bytes()
    if web and data[:4] != b"\x00asm":
        raise RuntimeError("Compiler output is not WebAssembly")
    print("BUILT", artifact.name, len(data), hashlib.sha256(data).hexdigest(), flush=True)
    return artifact

def stage_project(library: Path, native_library: Path | None, cellular_only: bool, threaded: bool) -> Path:
    stage = ROOT / "build" / ("web-project-threaded" if threaded else "web-project")
    if stage.exists():
        shutil.rmtree(stage)  # Only this tool's disposable, fixed staging directory.
    shutil.copytree(ROOT / "godot", stage, ignore=shutil.ignore_patterns(".godot", "native_extension"))
    binaries = stage / "addons/cybersand_native/bin"
    shutil.copy2(library, binaries / library.name)
    if native_library:
        shutil.copy2(native_library, binaries / native_library.name)
    project = (stage / "project.godot").read_text()
    project = project.replace('run/main_scene="res://main.tscn"', 'run/main_scene="res://web_main.tscn"')
    if 'run/main_scene="res://web_main.tscn"' not in project:
        raise RuntimeError("Unexpected project main-scene configuration")
    if cellular_only:
        shutil.rmtree(stage / "addons/godot-rapier2d")
        project = project.replace('"Rapier2D"', '"GodotPhysics2D"')
    # Only the disposable Web project overrides desktop settings.
    project = project.replace("native_worker_threads=0", "native_worker_threads=1\nweb_demo=true")
    project = project.replace("viewport_width=1920", "viewport_width=1280")
    project = project.replace("viewport_height=1080", "viewport_height=800")
    project = project.replace("window_width_override=1920", "window_width_override=1280")
    project = project.replace("window_height_override=1080", "window_height_override=800")
    (stage / "project.godot").write_text(project)
    return stage

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpp", type=Path, default=os.environ.get("GODOT_CPP_ROOT"))
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--templates", type=Path, default=os.environ.get("WEB_TEMPLATE_ROOT"))
    parser.add_argument("--profile", choices=["compat", "threaded"], default="compat")
    parser.add_argument("--cellular-only", action="store_true")
    parser.add_argument("--compile-only", action="store_true")
    parser.add_argument("--native-tests", action="store_true")
    args = parser.parse_args()
    if not args.cpp or not args.cpp.is_dir():
        parser.error("Set GODOT_CPP_ROOT or --cpp to the pinned godot-cpp checkout")
    if "4.0.11" not in output(["emcc", "--version"]).splitlines()[0]:
        raise RuntimeError("Emscripten 4.0.11 is required")
    import SCons
    if SCons.__version__ != "4.10.1":
        raise RuntimeError("SCons 4.10.1 is required")
    threaded = args.profile == "threaded"
    libs = ROOT / "build/web-libs"
    library = compile_extension(args.cpp.resolve(), libs, "web", threaded)
    native_library = None
    if args.native_tests:
        native_library = compile_extension(args.cpp.resolve(), libs, "linux", True)
    if args.compile_only:
        return
    if output([args.godot, "--version"]) != GODOT_VERSION:
        raise RuntimeError(f"Expected Godot {GODOT_VERSION}")
    if args.templates is None:
        parser.error("Set WEB_TEMPLATE_ROOT or --templates to extracted Godot 4.7 Web templates")
    stage = stage_project(library, native_library, args.cellular_only, threaded)
    output_dir = ROOT / "build" / ("web-threaded" if threaded else "web")
    output_dir.mkdir(parents=True, exist_ok=True)
    preset = (ROOT / "godot/export_presets.cfg").read_text()
    for kind in ("debug", "release"):
        template = args.templates / f"web_dlink_{'' if threaded else 'nothreads_'}{kind}.zip"
        if not template.is_file():
            raise RuntimeError(f"Missing template: {template}")
        preset = preset.replace(f'custom_template/{kind}=""', f'custom_template/{kind}="{template.resolve().as_posix()}"')
    if threaded:
        preset = preset.replace("variant/thread_support=false", "variant/thread_support=true")
    (stage / "export_presets.cfg").write_text(preset)
    run([args.godot, "--headless", "--editor", "--path", str(stage), "--import"], timeout=240)
    if args.native_tests:
        tests = ["test_cell_world.gd", "test_material_appearance_lut.gd",
                 "test_native_render_bridge_regression.gd", "test_render_patch_handoff_regression.gd",
                 "test_native_fire_presentation_regression.gd", "test_native_edge_contact_regression.gd",
                 "test_web_demo.gd"]
        if not args.cellular_only:
            tests += ["test_rapier_backend_preflight.gd", "test_rapier_drop_in.gd", "test_rapier_manual_step.gd"]
        for name in tests:
            run([args.godot, "--headless", "--path", str(stage), "--script", f"res://tests/{name}"], timeout=240)
    run([args.godot, "--headless", "--path", str(stage), "--export-release", "Web Demo", str(output_dir / "index.html")], timeout=240)
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        if not (output_dir / name).is_file():
            raise RuntimeError(f"Export missing {name}")
    for name in ("THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"):
        shutil.copy2(ROOT / name, output_dir / name)
    shutil.copy2(ROOT / "tools/serve_web.py", output_dir / "serve_web.py")
    identity = {"source_commit": output(["git", "rev-parse", "HEAD"]),
                "godot": GODOT_VERSION, "godot_cpp": CPP_REV,
                "emscripten": "4.0.11", "profile": args.profile,
                "rapier": "disabled" if args.cellular_only else "0.35.2"}
    (output_dir / "build-info.json").write_text(json.dumps(identity, indent=2) + "\n")
    (output_dir / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n"
        for p in sorted(output_dir.iterdir()) if p.is_file() and p.name != "SHA256SUMS"))
    print("WEB_EXPORT", output_dir, flush=True)

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"Web build failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
