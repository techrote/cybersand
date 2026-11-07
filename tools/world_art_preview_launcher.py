#!/usr/bin/env python3
"""Launch the real Godot world-art window without CyberSand's native game extensions.

Modes
  interactive (default)  open the native Godot window on --art-root / --pack
  --capture              unattended, display-backed Godot rendering to PNG + JSON
                         manifest (MAP-AUTO-01 / #498); see docs/tools/world-art-capture.md
  --verify-bundle DIR    re-verify a retained capture bundle (no Godot needed)
  --compare-bundles A B  report before/after framing equivalence and changes
  --adapter-oracle / --smoke-output   existing source-pinned regression tests

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
import platform
import shutil
import subprocess
import sys
import tempfile
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import world_art_capture_support as support  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
FILES = (
    "tools/world_art_preview.tscn",
    "tools/world_art_preview.gd",
    "tools/world_art_render_rig.gd",
    "tools/world_art_grid.gd",
    "tools/world_art_full_export.gd",
    "tools/world_art_capture.gd",
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
DEFAULT_REVISION_LABEL = "unverified external design source"


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


def resolve_engine(requested: str) -> str | None:
    """Resolve an explicitly supplied executable or a command on PATH.

    Do not silently download Godot or infer a machine-specific install path.
    """
    direct = Path(os.path.expandvars(os.path.expanduser(requested)))
    if direct.is_file():
        return str(direct.resolve())
    return shutil.which(requested)


def checked_run(command: list[str], env: dict[str, str]) -> int:
    print("WORLD_ART_EXEC", json.dumps(command, ensure_ascii=False), flush=True)
    try:
        return subprocess.call(command, env=env)
    except OSError as exc:
        print("WORLD_ART_ERROR", str(exc), file=sys.stderr, flush=True)
        return 3


def run_logged(command: list[str], env: dict[str, str], timeout: float) -> tuple[int | None, str]:
    """Run, echo and record combined output. Returns (exit code or None on timeout, text)."""
    print("WORLD_ART_EXEC", json.dumps(command, ensure_ascii=False), flush=True)
    try:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, encoding="utf-8", errors="replace")
    except OSError as exc:
        raise support.CaptureError(support.EXIT_ENGINE, f"cannot start Godot: {exc}") from None
    timed_out = threading.Event()

    def kill() -> None:
        timed_out.set()
        process.kill()

    timer = threading.Timer(timeout, kill)
    timer.start()
    lines: list[str] = []
    try:
        assert process.stdout is not None
        for line in process.stdout:
            lines.append(line)
            print(line, end="", flush=True)
        process.wait()
    finally:
        timer.cancel()
    return (None if timed_out.is_set() else process.returncode), "".join(lines)


def add_capture_arguments(parser: argparse.ArgumentParser) -> None:
    group = parser.add_argument_group("unattended capture (--capture)")
    group.add_argument("--capture", action="store_true",
                       help="render without any GUI interaction and write PNG + manifest evidence")
    group.add_argument("--output-dir", help="new or empty directory for the capture bundle (never inside art sources)")
    group.add_argument("--collection", action="append", metavar="NAME",
                       help="with --art-root: capture only this collection (repeatable); default all discovered")
    group.add_argument("--shots", help="comma list of full,viewport,detail or 'none' "
                       "(default full,viewport,detail; features-only when --feature/--all-features is given)")
    group.add_argument("--feature", action="append", metavar="ID[:VARIANT]",
                       help="also render this reusable feature (and authored variant) (repeatable)")
    group.add_argument("--all-features", action="store_true", help="render every feature's base variant")
    group.add_argument("--all-variants", action="store_true", help="render every feature and every authored variant")
    group.add_argument("--resolution", default="1920x1080", help="viewport/detail bound WIDTHxHEIGHT (default 1920x1080)")
    group.add_argument("--framing", choices=("fit", "native"), default="fit",
                       help="viewport framing: whole map (fit, default) or 1 px per native cell")
    group.add_argument("--zoom", type=float, help="viewport pixels per native cell (0.03..32)")
    group.add_argument("--center", help="with --zoom: view centre X,Y in native cells (default map centre)")
    group.add_argument("--view", help="viewport fits this native-cell rectangle X,Y,W,H")
    group.add_argument("--crop", help="detail crop in native cells X,Y,W,H (default centre half of the map)")
    group.add_argument("--detail-zoom", type=float, help="detail pixels per native cell (default largest integer fitting --resolution)")
    group.add_argument("--scale", type=int, default=2, help="full-composition output scale 1..8 (default 2)")
    group.add_argument("--feature-scale", type=int, default=4, help="feature output scale 1..8 (default 4)")
    group.add_argument("--time", type=float, default=1.37,
                       help="fixed shader presentation time in seconds (default 1.37, the viewer default)")
    group.add_argument("--no-glow", action="store_true", help="disable emission + glow")
    group.add_argument("--no-detail", action="store_true", help="disable structured material detail")
    group.add_argument("--no-background", action="store_true", help="disable background / decor")
    group.add_argument("--allow-blank", action="store_true", help="do not fail on a blank framebuffer")
    group.add_argument("--display-driver", default="", help="optional Godot display driver (x11 / windows / headless)")
    group.add_argument("--timeout", type=float, default=1800.0, help="seconds before the render is killed (default 1800)")
    group.add_argument("--verify-bundle", metavar="DIR", help="re-verify a capture bundle and exit")
    group.add_argument("--compare-bundles", nargs=2, metavar=("BEFORE", "AFTER"),
                       help="compare two bundles captured with equivalent framing and exit")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run CyberSand World Art Preview with original shader source but no game extensions.")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"),
                        help="Godot 4.7 executable; defaults to GODOT or godot on PATH")
    parser.add_argument("--art-root", help="Directory containing all #454 collection folders")
    parser.add_argument("--pack", action="append",
                        help="One specific pack.json (capture: repeatable; also accepts a collection directory)")
    parser.add_argument("--design-revision", default=None,
                        help="Art revision label. Interactive: caller-provided. Capture: optional, must match the "
                             "checkout HEAD (the real revision is detected from git)")
    parser.add_argument("--export-root", help="Absolute destination for unique screenshot sessions")
    parser.add_argument("--smoke-output", help="Absolute output directory (automated real GUI test)")
    parser.add_argument("--adapter-oracle", action="store_true",
                        help="Run source-pinned, headless RG8 adapter tests")
    parser.add_argument("--rendering-driver", default="", help="opengl3 / opengl3_angle")
    parser.add_argument("--quit-after", type=int, default=0,
                        help="Exit interactive window after this many rendered frames (CI launch smoke)")
    add_capture_arguments(parser)
    return parser


# ------------------------------------------------------------------- capture

def _fail(failures: list[str], code: int, message: str, state: dict) -> None:
    failures.append(message)
    state.setdefault("code", code)


def run_capture(args: argparse.Namespace, godot_executable: str) -> int:
    shots = support.build_shots(args)
    packs: list[Path] = []
    for item in args.pack or []:
        path = support.resolve_pack(item)
        if path not in packs:
            packs.append(path)
    art_root = Path(args.art_root).expanduser().resolve() if args.art_root else None
    if art_root is not None:
        for path in support.discover_collections(art_root, args.collection):
            if path.resolve() not in packs:
                packs.append(path.resolve())
    elif args.collection:
        raise support.CaptureError(support.EXIT_USAGE, "--collection requires --art-root")
    if not packs:
        raise support.CaptureError(support.EXIT_USAGE, "capture needs --pack and/or --art-root")
    if not args.output_dir:
        raise support.CaptureError(support.EXIT_USAGE, "--output-dir is required with --capture")
    output = Path(args.output_dir).expanduser().resolve()
    guards = support.guard_directories(packs, art_root)
    for guard in guards:
        if support.is_inside(output, guard) or support.is_inside(guard, output):
            raise support.CaptureError(support.EXIT_USAGE,
                                       f"--output-dir {output} overlaps the read-only art source {guard}; choose a separate directory")
    if support.is_inside(output, ROOT / "godot") or support.is_inside(output, GODOT):
        raise support.CaptureError(support.EXIT_USAGE, "--output-dir must not be inside the CyberSand godot/ project")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise support.CaptureError(support.EXIT_USAGE,
                                   f"--output-dir {output} exists and is not empty; use a new directory so earlier evidence is never overwritten")
    art_source = support.describe_art_source(packs, art_root, args.design_revision)
    viewer_git = support.git_identity(ROOT)
    jobs = []
    for index, pack in enumerate(packs, 1):
        blob = support.pack_git_blob(pack, art_source["toplevel"])
        jobs.append({"id": f"{index:02d}-{pack.parent.name}", "collection": pack.parent.name,
                     "pack_path": str(pack), "pack_sha256": support.sha256_file(pack),
                     "pack_git": blob, "shots": shots})
    presentation = {"time": args.time, "glow": not args.no_glow, "structured_detail": not args.no_detail,
                    "background": not args.no_background}
    before = {str(g): support.snapshot_tree(g) for g in guards}
    git_before = art_source["dirty_entries"]
    output.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []
    state: dict = {}
    log_text = ""
    run_summary: dict = {}
    display: dict = {}
    viewer_expected: dict = {}
    started = time.monotonic()
    env = os.environ.copy()
    env.setdefault("GODOT_SILENCE_ROOT_WARNING", "1")
    try:
        with tempfile.TemporaryDirectory(prefix="cybersand-world-art-capture-") as scratch:
            project = Path(scratch) / "project"
            project.mkdir()
            hashes = make_project(project)
            viewer = {"git_revision": viewer_git["revision"], "git_dirty": viewer_git["dirty"],
                      "files": hashes,
                      "launcher_sha256": support.sha256_file(Path(__file__)),
                      "capture_support_sha256": support.sha256_file(Path(support.__file__))}
            viewer_expected = viewer
            request = {"schema": support.SCHEMA_REQUEST, "output_dir": str(output),
                       "art_source": art_source, "viewer": viewer, "presentation": presentation,
                       "allow_blank": args.allow_blank, "jobs": jobs}
            request_path = Path(scratch) / "request.json"
            request_path.write_text(json.dumps(request, indent=1), encoding="utf-8")
            code, text = run_logged([godot_executable, "--headless", "--path", str(project), "--editor",
                                     "--import", "--quit"], env, min(args.timeout, 900.0))
            log_text += text
            if code is None or code != 0 or support.scan_log(text):
                raise support.CaptureError(support.EXIT_ENGINE,
                                           "Godot could not import the temporary project (wrong executable or version?): "
                                           + "; ".join(support.scan_log(text)[:3] or [f"exit {code}"]))
            command = [godot_executable, "--path", str(project), "--audio-driver", "Dummy"]
            if args.rendering_driver:
                command += ["--rendering-driver", args.rendering_driver]
            if args.display_driver:
                command += ["--display-driver", args.display_driver]
            command += ["--script", "res://tools/world_art_capture.gd", "--", f"--request={request_path}"]
            code, text = run_logged(command, env, args.timeout)
            log_text += text
            if code is None:
                _fail(failures, support.EXIT_RENDER, f"Godot did not finish within --timeout {args.timeout:.0f}s and was killed", state)
            elif code == 77:
                _fail(failures, support.EXIT_NO_DISPLAY,
                      "no graphical display: Godot used the headless display server. Run under X11/Xvfb "
                      "(for example xvfb-run -a ...) with OpenGL/llvmpipe, or from a Windows desktop session", state)
            elif code != 0:
                runner = [line.strip() for line in text.splitlines() if "WORLD_ART_CAPTURE_ERROR" in line][:5]
                _fail(failures, support.EXIT_RENDER, f"Godot capture runner exited with status {code}"
                      + (": " + " | ".join(runner) if runner else ""), state)
            problems = support.scan_log(text)
            if problems:
                _fail(failures, support.EXIT_RENDER, "Godot logged render/shader/script errors: " + " | ".join(problems[:5]), state)
    except support.CaptureError as error:
        _fail(failures, error.code, error.message, state)
    (output / "godot-capture.log").write_text(log_text, encoding="utf-8")

    run_path = output / "godot-run.json"
    if run_path.is_file():
        run_summary = json.loads(run_path.read_text(encoding="utf-8"))
        display = run_summary.get("display", {})
    elif "code" not in state:
        _fail(failures, support.EXIT_RENDER, "the Godot runner never wrote godot-run.json", state)
    if display:
        if not str(display.get("godot", "")).startswith("4.7"):
            _fail(failures, support.EXIT_ENGINE, f"Godot {display.get('godot')} is not 4.7", state)
        if args.rendering_driver and display.get("rendering_driver") != args.rendering_driver:
            _fail(failures, support.EXIT_EVIDENCE,
                  f"requested rendering driver {args.rendering_driver!r} but Godot used {display.get('rendering_driver')!r}", state)
        if display.get("rendering_method") != "gl_compatibility":
            _fail(failures, support.EXIT_EVIDENCE, f"unexpected rendering method {display.get('rendering_method')!r}", state)

    after = {str(g): support.snapshot_tree(g) for g in guards}
    changes = support.diff_snapshots(before, after)
    git_after = support.git_identity(Path(art_source["toplevel"] or guards[0]))
    source_guard = {"guarded_directories": [str(g) for g in guards], "unchanged": not changes,
                    "changes": changes[:50], "git_status_entries_before": git_before,
                    "git_status_entries_after": git_after.get("dirty_entries", []),
                    "git_head_after": git_after.get("revision")}
    if changes:
        _fail(failures, support.EXIT_SOURCE_CHANGED, "the read-only art source changed during capture: " + "; ".join(changes[:5]), state)
    if art_source["revision"] and git_after.get("revision") and art_source["git"] and git_after["revision"] != art_source["revision"]:
        _fail(failures, support.EXIT_SOURCE_CHANGED, "art checkout HEAD moved during capture", state)

    job_entries = []
    for job in jobs:
        entry = {"id": job["id"], "collection": job["collection"], "pack_path": job["pack_path"],
                 "pack_sha256": job["pack_sha256"], "pack_git": job["pack_git"], "status": "failed",
                 "manifest": f"{job['id']}/manifest.json", "shots": []}
        manifest_path = output / job["id"] / "manifest.json"
        if manifest_path.is_file():
            manifest = support.read_json(manifest_path)
            entry["manifest_sha256"] = support.sha256_file(manifest_path)
            issues = support.verify_job(manifest_path.parent, manifest, art_source, viewer_expected or None,
                                        recheck_packs=True, allow_blank=args.allow_blank)
            entry["shots"] = [{"id": s.get("id"), "kind": s.get("kind"), "file": f"{job['id']}/{s.get('file')}",
                               "width": s.get("width"), "height": s.get("height"), "png_sha256": s.get("png_sha256")}
                              for s in manifest.get("shots", []) if s.get("status") == "complete"]
            entry["renderer"] = {k: manifest.get("renderer", {}).get(k) for k in
                                 ("rendering_method", "rendering_driver", "graphics_adapter")}
            if issues:
                entry["problems"] = issues
                _fail(failures, support.EXIT_EVIDENCE if manifest.get("status") == "complete" else support.EXIT_RENDER,
                      "; ".join(issues[:3]), state)
            else:
                entry["status"] = "complete"
        else:
            _fail(failures, support.EXIT_RENDER, f"{job['id']}: no manifest was written", state)
        job_entries.append(entry)

    status = "completed" if not failures else "failed"
    batch = {
        "schema": support.SCHEMA_BATCH, "status": status, "failures": failures,
        "tool": {"entry_point": "tools/world_art_preview_launcher.py --capture", "python": platform.python_version(),
                 "platform": platform.platform()},
        "viewer": viewer_expected, "art_source": art_source,
        "engine": {"executable": godot_executable, "executable_sha256": support.sha256_file(Path(godot_executable)),
                   "requested_rendering_driver": args.rendering_driver or None,
                   "requested_display_driver": args.display_driver or None, "display": display},
        "presentation": presentation, "shots_requested": shots, "allow_blank": args.allow_blank,
        "synthetic_condition_notice": ("Material condition bytes are SYNTHETIC native creation-state fixtures; "
                                       "images are presentation of authored geometry, not simulated physical state."),
        "limitations": [
            "Pixels differ legitimately between operating systems, drivers and GPUs; compare source identity, "
            "geometry, completeness and renderer-specific invariants across platforms.",
            "Presentation-only layering; not a four-native-plane (#501) render.",
            "Provisional pack schema; not a production import/save contract.",
        ],
        "source_guard": source_guard, "jobs": job_entries,
    }
    support.seal_manifest(batch)
    (output / "batch-manifest.json").write_text(json.dumps(batch, indent=2) + "\n", encoding="utf-8")
    result = {"status": status, "exit_code": support.EXIT_OK if not failures else state.get("code", support.EXIT_RENDER),
              "bundle": str(output), "batch_manifest": str(output / "batch-manifest.json"),
              "manifest_sha256": batch["manifest_sha256"], "elapsed_seconds": round(time.monotonic() - started, 1),
              "jobs": [{"id": e["id"], "collection": e["collection"], "status": e["status"],
                        "manifest": str(output / e["manifest"]),
                        "images": [str(output / s["file"]) for s in e["shots"]]} for e in job_entries],
              "failures": failures}
    print("WORLD_ART_CAPTURE_RESULT " + json.dumps(result), flush=True)
    for message in failures:
        print("WORLD_ART_ERROR " + message, file=sys.stderr, flush=True)
    return result["exit_code"]


# ---------------------------------------------------------------------- main

def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.verify_bundle:
            batch, problems = support.verify_bundle(Path(args.verify_bundle))
            print(json.dumps({"bundle": str(Path(args.verify_bundle).resolve()), "valid": not problems,
                              "problems": problems, "manifest_sha256": batch.get("manifest_sha256"),
                              "art_revision": batch.get("art_source", {}).get("revision"),
                              "jobs": len(batch.get("jobs", []))}, indent=2))
            return support.EXIT_OK if not problems else support.EXIT_EVIDENCE
        if args.compare_bundles:
            report = support.compare_bundles(Path(args.compare_bundles[0]), Path(args.compare_bundles[1]))
            print(json.dumps(report, indent=2))
            return support.EXIT_OK if report["comparable"] else support.EXIT_EVIDENCE
        if args.capture:
            exe = resolve_engine(args.godot)
            if exe is None:
                raise support.CaptureError(support.EXIT_ENGINE, f"Godot executable not found: {args.godot!r}. Supply --godot=PATH "
                                           "or set GODOT. On Windows prefer the *_console.exe build so Godot's log is captured.")
            if platform.system() == "Windows" and "console" not in Path(exe).name.lower():
                print("WORLD_ART_NOTE: this Godot build has no console; its log cannot be captured "
                      "(results are still verified from the evidence files). Prefer Godot_v4.7-stable_win64_console.exe.",
                      file=sys.stderr, flush=True)
            return run_capture(args, exe)
    except support.CaptureError as error:
        print("WORLD_ART_ERROR " + error.message, file=sys.stderr, flush=True)
        return error.code

    pack_arg = None
    if args.pack:
        if len(args.pack) > 1:
            parser.error("interactive mode accepts one --pack; use --capture for several")
        pack_arg = args.pack[0]
    if args.quit_after < 0:
        parser.error("--quit-after must be nonnegative")
    if not args.adapter_oracle and not pack_arg and not args.art_root:
        parser.error("Provide --art-root or --pack")
    if args.art_root and not Path(args.art_root).is_dir() and not pack_arg:
        parser.error("The supplied --art-root is not a directory")
    if pack_arg and not Path(pack_arg).is_file():
        parser.error("The supplied --pack does not exist")
    if args.smoke_output and not Path(args.smoke_output).is_absolute():
        parser.error("The --smoke-output path must be absolute")
    if args.export_root and not Path(args.export_root).is_absolute():
        parser.error("The --export-root path must be absolute")
    godot_executable = resolve_engine(args.godot)
    if godot_executable is None:
        parser.error(
            "Godot executable not found: " + repr(args.godot)
            + ". Supply --godot=PATH_TO_YOUR_INSTALLED_GODOT_4_7_EXE"
            + " or add the executable to PATH. On Windows PowerShell, try"
            + " 'Get-Command godot, godot4 -ErrorAction SilentlyContinue'."
            + " This viewer does not need another CyberSand clone or native libraries."
        )
    design_revision = args.design_revision or DEFAULT_REVISION_LABEL
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
        preflight = [godot_executable, "--headless", "--path", str(project),
                     "--editor", "--import", "--quit"]
        code = checked_run(preflight, os.environ.copy())
        if code:
            return code
        if args.adapter_oracle:
            return checked_run([godot_executable, "--headless", "--path", str(project),
                                "--script", "res://tests/test_world_design_pack_adapter.gd"],
                               os.environ.copy())
        command = [godot_executable, "--path", str(project), "--audio-driver", "Dummy"]
        if args.rendering_driver:
            command += ["--rendering-driver", args.rendering_driver]
        if args.display_driver:
            command += ["--display-driver", args.display_driver]
        if args.quit_after:
            command += ["--quit-after", str(args.quit_after)]
        if args.smoke_output:
            command += ["--script", "res://tests/world_art_preview_smoke.gd"]
        else:
            command += ["res://tools/world_art_preview.tscn"]
        command += ["--", "--design-revision=" + design_revision]
        if pack_arg:
            command += ["--pack=" + str(Path(pack_arg).resolve())]
        elif args.art_root:
            command += ["--art-root=" + str(Path(args.art_root).resolve())]
        if args.export_root:
            command += ["--export-root=" + str(Path(args.export_root).resolve())]
        if args.smoke_output:
            command += ["--smoke-output=" + str(Path(args.smoke_output).resolve())]
        return checked_run(command, os.environ.copy())


if __name__ == "__main__":
    sys.exit(main())
