#!/usr/bin/env python3
"""Build, verify and exercise the portable Windows World Art evaluation package.

The package reuses the ordinary isolated Godot project and capture launcher.
Only exact committed source and already verified real-Godot capture evidence
enter the package. No native CyberSand or Rapier runtime is included.
"""
from __future__ import annotations

import argparse
from html import escape
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import world_art_capture_support as support
import world_art_preview_launcher as launcher

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "world-art-evaluation.json"
SCHEMA = "cybersand.world-art-evaluation/1"
VERSION = "4.7.stable.official.5b4e0cb0f"
ENGINES = {
    "Godot_v4.7-stable_win64.exe": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
    "Godot_v4.7-stable_win64_console.exe": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
}
NOTICES = {
    "LICENSE.txt": "b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
    "COPYRIGHT.txt": "cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d",
}
CAPTURE_BUNDLES = (
    "batch-all-15", "features-all-120", "asymmetric-tall", "asymmetric-wide",
    "large-streamed-rgb8-67m", "compare-before", "compare-after",
    "framing-explicit", "framing-native", "framing-view-rect",
    "size-matrix-512x512", "size-matrix-1024x1024", "size-matrix-2048x1024",
    "size-matrix-1024x2048", "size-matrix-4096x1024", "size-matrix-1024x4096",
    "size-matrix-512x8192", "size-matrix-8192x512", "size-matrix-2048x8192",
    "size-matrix-16384x1024",
)
PYTHON_SOURCES = (
    "tools/world_art_preview_launcher.py", "tools/world_art_capture_support.py",
    "tools/world_art_stream_png.py", "tools/world_art_evaluation_package.py",
    "tools/test_world_art_capture.py",
    "examples/world-art-capture/build_gallery.py", "examples/world-art-capture/capture_atlas.py",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def relative_name(value: str) -> str:
    require(isinstance(value, str) and value and "\\" not in value and ":" not in value,
            "unsafe relative package path")
    path = PurePosixPath(value)
    require(not path.is_absolute() and all(part not in ("", ".", "..") for part in value.split("/")),
            "unsafe relative package path: " + value)
    return path.as_posix()


def inventory(directory: Path) -> dict[str, str]:
    files = {}
    for path in sorted(directory.rglob("*")):
        name = path.relative_to(directory).as_posix()
        require(not path.is_symlink(), "package contains a symbolic link: " + name)
        # Godot owns this regenerable cache after a user opens the viewer.
        if name == MANIFEST or name == "godot/.godot" or name.startswith("godot/.godot/"):
            continue
        if path.is_file():
            files[relative_name(name)] = support.sha256_file(path)
    return files


def copy_regular_tree(source: Path, destination: Path, *, ignored: set[str] | None = None) -> None:
    require(source.is_dir() and not source.is_symlink(), "missing real directory: " + str(source))
    ignore = ignored or set()
    destination.mkdir(parents=True, exist_ok=False)
    for path in sorted(source.iterdir()):
        if path.name in ignore or path.suffix == ".pyc":
            continue
        require(not path.is_symlink(), "dependency/evidence contains a symbolic link: " + str(path))
        if path.is_dir():
            copy_regular_tree(path, destination / path.name, ignored=ignore)
        elif path.is_file():
            shutil.copyfile(path, destination / path.name)
        else:
            raise ValueError("dependency/evidence contains a non-regular file: " + str(path))


def source_paths() -> list[str]:
    paths = ["godot/" + name for name in launcher.FILES]
    paths += list(PYTHON_SOURCES)
    paths += ["LICENSE_STATUS.md", "THIRD_PARTY_NOTICES.md",
              "docs/tools/world-art-evaluation.md", "docs/tools/world-art-preview.md",
              "docs/tools/world-art-capture.md", "docs/tools/art-pipeline-unification.md",
              "docs/world-design/README.md", "docs/world-design/QUALITY_BAR.md"]
    for collection in support.COLLECTION_ORDER:
        paths += [f"docs/world-design/{collection}/pack.json", f"docs/world-design/{collection}/README.md"]
    return sorted(paths)


def source_identity(source_sha: str) -> dict[str, str]:
    head = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    require(head == source_sha, "requested source SHA differs from the packaging checkout HEAD")
    hashes = {}
    for name in source_paths():
        path = ROOT / name
        require(path.is_file() and not path.is_symlink(), "missing regular source file: " + name)
        committed = subprocess.check_output(["git", "-C", str(ROOT), "show", source_sha + ":" + name])
        actual = support.sha256_file(path)
        require(actual == support.sha256_bytes(committed), "uncommitted source differs: " + name)
        hashes[name] = actual
    return hashes


def viewer_matches(batch: dict, hashes: dict[str, str], source_sha: str) -> None:
    viewer = batch.get("viewer", {})
    require(viewer.get("git_revision") == source_sha, "capture viewer commit differs from package source")
    require(viewer.get("files") == {name: hashes["godot/" + name] for name in launcher.FILES},
            "capture Godot source hashes differ from the packaged renderer")
    for key, name in (("launcher_sha256", "world_art_preview_launcher.py"),
                      ("capture_support_sha256", "world_art_capture_support.py"),
                      ("stream_png_sha256", "world_art_stream_png.py")):
        require(viewer.get(key) == hashes["tools/" + name], "capture Python source hash differs: " + name)
    require(batch.get("source_guard", {}).get("unchanged") is True,
            "capture did not prove unchanged source")


def check_corpus(batch: dict, kind: str, hashes: dict[str, str], bundle: Path) -> None:
    jobs = batch.get("jobs", [])
    require([job.get("collection") for job in jobs] == list(support.COLLECTION_ORDER),
            "gallery must contain each original collection exactly once in catalogue order")
    count = 0
    for job in jobs:
        name = job["collection"]
        require(job.get("pack_sha256") == hashes[f"docs/world-design/{name}/pack.json"],
                "gallery art differs from packaged source: " + name)
        shots = job.get("shots", [])
        if kind == "scenes":
            require({shot.get("id") for shot in shots} == {"full", "viewport", "detail"} and len(shots) == 3,
                    "each scene needs its full, viewport and detail Godot captures")
        else:
            authored = json.loads((ROOT / f"docs/world-design/{name}/pack.json").read_text(encoding="utf-8"))
            require(len(shots) == len(authored["features"]), "feature gallery inventory is incomplete: " + name)
            detail = support.read_json(bundle / relative_name(job["manifest"]))
            require([shot.get("selection", {}).get("feature") for shot in detail["shots"]]
                    == [feature["id"] for feature in authored["features"]],
                    "feature gallery identities differ from the packaged catalogue: " + name)
        count += len(shots)
    require(count == (45 if kind == "scenes" else 120), "incomplete original scene/feature gallery")


def copy_evidence(source: Path, output: Path, hashes: dict[str, str], source_sha: str) -> list[dict]:
    summary = json.loads((source / "qualification-summary.json").read_text(encoding="utf-8"))
    results = summary.get("results", [])
    graphical = [item for item in results if "GraphicalCaptureTests" in str(item.get("test", ""))]
    require(summary.get("ok") is True and summary.get("graphical_qualification") is True
            and summary.get("skipped") == 0 and summary.get("graphical_tests_passed", 0) >= 14
            and len(results) == summary.get("tests") and len(results) >= 30
            and len({item.get("test") for item in results}) == len(results)
            and len(graphical) == summary.get("graphical_tests_passed")
            and all(item.get("status") == "pass" for item in results),
            "capture suite did not complete its real graphical qualification")
    require(summary.get("platform") == "win32", "Windows package requires Windows graphical evidence")
    destination = output / "evidence"
    destination.mkdir()
    rows = []
    for name in CAPTURE_BUNDLES:
        bundle = source / name
        batch, problems = support.verify_bundle(bundle, recheck_packs=False)
        require(not problems, "invalid capture evidence " + name + ": " + "; ".join(problems))
        viewer_matches(batch, hashes, source_sha)
        engine = batch.get("engine", {})
        display = engine.get("display", {})
        require(engine.get("executable_sha256") == ENGINES["Godot_v4.7-stable_win64_console.exe"]
                and display.get("display_server") == "Windows"
                and display.get("rendering_driver") == "opengl3_angle"
                and display.get("graphics_adapter"), "capture runtime differs from the packaged Windows Godot pin")
        if name in ("batch-all-15", "features-all-120"):
            require(batch.get("art_source", {}).get("revision") == source_sha,
                    "original atlas capture commit differs from package source")
            check_corpus(batch, "scenes" if name == "batch-all-15" else "features", hashes, bundle)
        copy_regular_tree(bundle, destination / name)
        row = {"bundle": name, "manifest": f"evidence/{name}/batch-manifest.json",
               "manifest_sha256": batch["manifest_sha256"],
               "png_count": sum(len(job.get("shots", [])) for job in batch["jobs"]),
               "source_revision": batch.get("art_source", {}).get("revision")}
        fixture = source / "source-inputs" / name
        require(fixture.is_dir() or batch.get("art_source", {}).get("git") is True,
                "temporary qualification source was not retained: " + name)
        if fixture.exists():
            inputs = support.read_json(fixture / "source-inputs.json")
            records = inputs.get("inputs")
            jobs = {job["id"]: job for job in batch["jobs"]}
            require(inputs.get("bundle") == name and isinstance(records, list)
                    and len(records) == len(jobs), "incomplete retained fixture source inventory: " + name)
            seen = set()
            for item in records:
                require(isinstance(item, dict) and item.get("job") in jobs
                        and item["job"] not in seen, "unknown/duplicate retained fixture source")
                seen.add(item["job"])
                path = support.evidence_path(fixture, item.get("file"))
                require(path.name == item["job"] + ".json"
                        and support.sha256_file(path) == item.get("sha256") == jobs[item["job"]]["pack_sha256"],
                        "retained source does not match its rendered fixture: " + name)
            (destination / "source-inputs").mkdir(exist_ok=True)
            copy_regular_tree(fixture, destination / "source-inputs" / name)
            row["source_inputs"] = f"evidence/source-inputs/{name}/source-inputs.json"
        rows.append(row)
    for name in ("qualification-summary.json", "qualification.log"):
        shutil.copyfile(source / name, destination / name)
    return rows


def copy_python(source: Path, destination: Path) -> dict:
    require(os.name == "nt", "bundled Windows Python must be staged and executed on Windows")
    source = source.resolve(strict=True)
    require((source / "python.exe").is_file() and (source / "Lib/json").is_dir()
            and (source / "DLLs").is_dir() and (source / "LICENSE.txt").is_file(),
            "a complete licensed Windows Python installation is required")
    destination.mkdir(parents=True)
    for path in sorted(source.iterdir()):
        if path.suffix.lower() in (".exe", ".dll") or path.name == "LICENSE.txt":
            resolved = path.resolve(strict=True)
            require(resolved.is_file() and resolved.is_relative_to(source), "Python runtime escapes installation")
            shutil.copyfile(resolved, destination / path.name)
    for name in ("Lib", "DLLs"):
        copy_regular_tree(source / name, destination / name,
                          ignored={"__pycache__", "site-packages", "test", "tests", "ensurepip", "idlelib", "tkinter"})
    probe = subprocess.check_output([str(destination / "python.exe"), "-I", "-B", "-c",
        "import json, pathlib, hashlib, zipfile, zlib, subprocess, tempfile, sys; "
        "assert sys.version_info >= (3, 10); print(sys.version)"], text=True, timeout=30).strip()
    return {"version": probe, "executable_sha256": support.sha256_file(destination / "python.exe"),
            "dependency_policy": "licensed standard library only; no site packages, no network installation"}


def write_launchers(output: Path, source_sha: str, bundled_python: bool) -> None:
    preamble = '@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\n'
    viewer = preamble + (
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0godot" '
        '--editor --import --quit\r\n'
        'if errorlevel 1 (\r\n  echo World Art project import failed.\r\n  pause\r\n  exit /b 1\r\n)\r\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --path "%~dp0godot" '
        '--audio-driver Dummy --rendering-driver opengl3_angle %* res://tools/world_art_preview.tscn '
        '-- "--art-root=%~dp0docs\\world-design" "--design-revision=' + source_sha + '"\r\n'
        'set "RESULT=%ERRORLEVEL%"\r\nif not "%RESULT%"=="0" pause\r\nexit /b %RESULT%\r\n')
    (output / "Open World Art.cmd").write_bytes(viewer.encode("utf-8"))
    (output / "Open Gallery.cmd").write_bytes((preamble + 'start "" "%~dp0Gallery.html"\r\n').encode("utf-8"))
    python = '"%~dp0dependencies\\python\\python.exe"' if bundled_python else 'py -3'
    capture = preamble + (
        'if "%~1"=="" (\r\n  echo Usage: "Capture example.cmd" "C:\\ArtCaptures\\new-run"\r\n'
        '  echo Choose a new empty output directory.\r\n  exit /b 2\r\n)\r\n'
        + python + ' -B "%~dp0tools\\world_art_preview_launcher.py" '
        '--godot "%~dp0Godot_v4.7-stable_win64_console.exe" --rendering-driver opengl3_angle '
        '--capture --art-root "%~dp0docs\\world-design" --collection lumen-fault '
        '--shots full,viewport,detail --scale 1 --output-dir "%~1" '
        '--design-revision ' + source_sha + '\r\nexit /b %ERRORLEVEL%\r\n')
    (output / "Capture example.cmd").write_bytes(capture.encode("utf-8"))


def write_gallery(output: Path, rows: list[dict], source_sha: str) -> None:
    # Existing gallery builder owns every PNG card. This page only links its
    # verified scene/feature galleries and the retained qualification records.
    sections = [
        ("All fifteen original scenes", "evidence/batch-all-15/gallery/index.html"),
        ("All 120 reusable features", "evidence/features-all-120/gallery/index.html"),
        ("Windows capture test results", "evidence/qualification-summary.json"),
        ("Package source and file hashes", MANIFEST),
    ]
    links = ''.join('<li><a href="' + escape(url, quote=True) + '">' + escape(label) + '</a></li>'
                    for label, url in sections)
    examples = []
    for row in rows:
        if row["bundle"] in ("batch-all-15", "features-all-120"):
            continue
        batch = support.read_json(output / row["manifest"])
        for job in batch["jobs"]:
            for shot in job["shots"]:
                image = f'evidence/{row["bundle"]}/{relative_name(shot["file"])}'
                examples.append('<li><a href="' + escape(image, quote=True) + '">'
                                + escape(row["bundle"] + ' / ' + shot["id"])
                                + f' ({shot["width"]}×{shot["height"]})</a></li>')
        if row.get("source_inputs"):
            sources = support.read_json(output / row["source_inputs"])
            for item in sources["inputs"]:
                relative = str(PurePosixPath(row["source_inputs"]).parent / relative_name(item["file"]))
                examples.append('<li><a href="' + escape(relative, quote=True) + '">'
                                + escape(row["bundle"] + ' / original ' + item["job"] + '.json') + '</a></li>')
    html = ('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" '
            'content="width=device-width,initial-scale=1"><title>CyberSand World Art evaluation</title>'
            '<style>body{background:#09131d;color:#e2edf5;font:17px/1.6 system-ui,sans-serif;'
            'max-width:1000px;margin:40px auto;padding:0 24px}a{color:#8ed7ff}'
            'h1,h2{line-height:1.2}small{overflow-wrap:anywhere}</style>'
            '<h1>CyberSand World Art</h1><p>Portable Windows evaluation · actual Godot 4.7 material rendering.</p>'
            '<p><small>Source ' + escape(source_sha) + '</small></p><ul>' + links + '</ul>'
            '<h2>Large canvases, framing and before/after</h2><p>These are renderer qualification fixtures. '
            'Open each original PNG at full resolution to inspect far edges and material boundaries.</p><ul>'
            + ''.join(examples) + '</ul><p>Windows ANGLE CI is separate from acceptance on your physical GPU. '
            'Art preview dimensions do not qualify native CyberSand simulation limits.</p></html>')
    (output / "Gallery.html").write_text(html, encoding="utf-8")


def build(args: argparse.Namespace) -> dict:
    require(os.name == "nt", "Windows evaluation packages must be assembled and imported on Windows")
    hashes = source_identity(args.source_sha)
    output = args.output.resolve()
    require(not output.exists() and not output.is_relative_to(ROOT),
            "package destination must be a new directory outside the source checkout")
    for name, expected in ENGINES.items():
        require(support.sha256_file(args.engine_dir / name) == expected, "Godot engine hash differs: " + name)
    for name, expected in NOTICES.items():
        require(support.sha256_file(args.engine_notices / name) == expected, "Godot notice hash differs: " + name)
    # Exclusive directory claim; a failed build remains visibly incomplete and
    # cannot be taken over by a second builder. The sealed manifest is last.
    output.mkdir(parents=True, exist_ok=False)
    for name in source_paths():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    launcher.make_project(output / "godot")
    for name in ENGINES:
        shutil.copyfile(args.engine_dir / name, output / name)
    for name in NOTICES:
        shutil.copyfile(args.engine_notices / name, output / ("Godot-" + name))
    python = copy_python(args.python_root, output / "dependencies/python") if args.python_root else None
    rows = copy_evidence(args.capture_evidence, output, hashes, args.source_sha)
    # Import before sealing the payload so .gd.uid files are accounted for.
    # Cache bytes are regenerated on extraction; the launcher repeats this
    # class scan when the ZIP's intentionally omitted .godot cache is absent.
    imported = subprocess.run([str(output / "Godot_v4.7-stable_win64_console.exe"),
        "--headless", "--path", str(output / "godot"), "--editor", "--import", "--quit"],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        encoding="utf-8", errors="replace", timeout=180)
    (output / "evidence/package-import.log").write_text(imported.stdout, encoding="utf-8")
    require(imported.returncode == 0 and not support.LOG_ERROR_PATTERN.search(imported.stdout),
            "packaged Godot project import failed")
    # Do not trust pre-existing HTML copied from a capture artifact. Generate it
    # from the already validated manifests using the one authoritative builder.
    import importlib.util
    spec = importlib.util.spec_from_file_location("world_art_gallery", ROOT / "examples/world-art-capture/build_gallery.py")
    gallery = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gallery)
    for name in ("batch-all-15", "features-all-120"):
        old = output / "evidence" / name / "gallery"
        if old.exists():
            shutil.rmtree(old)  # Only this newly created package's copied HTML.
        gallery.build_gallery(output / "evidence" / name)
    write_launchers(output, args.source_sha, python is not None)
    write_gallery(output, rows, args.source_sha)
    shutil.copyfile(output / "docs/tools/world-art-evaluation.md", output / "READ-ME.md")
    manifest = support.seal_manifest({
        "schema": SCHEMA, "status": "complete", "source_commit": args.source_sha,
        "purpose": "private owner evaluation; Draft/HOLD, not a release or native simulation qualification",
        "godot_version": VERSION, "godot_files_sha256": ENGINES, "python": python,
        "source_files_sha256": hashes, "evidence": rows,
        "qualification": {"windows_capture": "passed", "package_launch": "requires separate smoke receipt",
                          "physical_windows_nvidia": "owner acceptance pending"},
        "files_sha256": inventory(output),
    })
    (output / MANIFEST).write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    verify(output)
    return manifest


def verify(package: Path) -> dict:
    package = package.resolve(strict=True)
    manifest = support.read_json(package / MANIFEST)
    require(manifest.get("schema") == SCHEMA and manifest.get("status") == "complete"
            and support.manifest_is_sealed(manifest), "invalid/incomplete package manifest")
    expected = manifest.get("files_sha256")
    require(isinstance(expected, dict) and expected, "package file inventory is missing")
    for name in expected:
        relative_name(name)
    require(inventory(package) == expected, "package file inventory/hash mismatch")
    require(manifest.get("godot_files_sha256") == ENGINES,
            "package engine identity differs from Godot 4.7 pin")
    for name, digest in ENGINES.items():
        require(expected.get(name) == digest, "package contains an unpinned engine: " + name)
    for name, digest in manifest.get("source_files_sha256", {}).items():
        require(expected.get(relative_name(name)) == digest, "packaged source identity mismatch: " + name)
    for name in ("Open World Art.cmd", "Open Gallery.cmd", "Capture example.cmd", "Gallery.html", "godot/project.godot"):
        require(name in expected, "required package entry point missing: " + name)
    require(not any(name.startswith("godot/addons/") for name in expected), "native/plugin runtime entered art package")
    return manifest


def smoke(args: argparse.Namespace) -> dict:
    require(os.name == "nt", "actual Windows launch/capture smoke requires Windows")
    package = args.package.resolve(strict=True)
    manifest = verify(package)
    require(manifest.get("python"), "smoke requires the self-contained bundled Python package")
    report = args.report.resolve()
    require(not report.exists() and not report.is_relative_to(package), "smoke report needs a fresh external directory")
    report.mkdir(parents=True, exist_ok=False)
    cache = package / "godot/.godot"
    if cache.exists():
        shutil.rmtree(cache)  # Regenerable, verified local cache omitted from the ZIP.
    env = os.environ.copy()
    for name in ("PYTHONHOME", "PYTHONPATH", "PYTHONSTARTUP"):
        env.pop(name, None)
    windows = Path(os.environ.get("SystemRoot", r"C:\Windows"))
    env.update(PATH=os.pathsep.join((str(windows / "System32"), str(windows))), PYTHONDONTWRITEBYTECODE="1",
               PYTHONUTF8="1", GODOT_SILENCE_ROOT_WARNING="1")
    commands = [
        [str(windows / "System32/cmd.exe"), "/d", "/c", "call", "Open World Art.cmd", "--quit-after", "120"],
        [str(windows / "System32/cmd.exe"), "/d", "/c", "call", "Capture example.cmd", str(report / "capture")],
    ]
    executions = []
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=package, env=env, text=True, encoding="utf-8", errors="replace",
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
        (report / f"{index + 1}-execution.log").write_text(result.stdout, encoding="utf-8")
        require(result.returncode == 0 and not support.LOG_ERROR_PATTERN.search(result.stdout),
                f"packaged Windows entry point {index + 1} failed; see smoke logs")
        executions.append({"entry_point": command[4], "exit_code": result.returncode})
    batch, problems = support.verify_bundle(report / "capture", recheck_packs=False)
    require(not problems and len(batch.get("jobs", [])) == 1, "packaged capture failed evidence validation")
    verify(package)
    receipt = {"source_commit": manifest["source_commit"], "package_manifest_sha256": manifest["manifest_sha256"],
               "platform": sys.platform, "godot_version": VERSION, "executions": executions,
               "capture_manifest_sha256": batch["manifest_sha256"], "engine": batch["engine"],
               "ok": True, "physical_gpu_acceptance": False}
    (report / "windows-package-smoke.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def archive(package: Path, destination: Path) -> dict:
    manifest = verify(package)
    require(not destination.resolve().is_relative_to(package.resolve()), "archive cannot be inside the package")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("xb") as output:
        with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zipper:
            for name in sorted([*manifest["files_sha256"], MANIFEST]):
                zipper.write(package / name, "CyberSand-World-Art/" + name)
    return {"zip": str(destination), "sha256": support.sha256_file(destination), "source_commit": manifest["source_commit"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build_parser = commands.add_parser("build")
    for flag in ("output", "engine-dir", "engine-notices", "capture-evidence"):
        build_parser.add_argument("--" + flag, type=Path, required=True)
    build_parser.add_argument("--source-sha", required=True)
    build_parser.add_argument("--python-root", type=Path)
    for name in ("verify", "smoke", "archive"):
        sub = commands.add_parser(name)
        sub.add_argument("--package", type=Path, required=True)
        if name == "smoke":
            sub.add_argument("--report", type=Path, required=True)
        if name == "archive":
            sub.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "build":
            result = build(args)
        elif args.command == "verify":
            result = verify(args.package)
        elif args.command == "smoke":
            result = smoke(args)
        else:
            result = archive(args.package, args.output)
        print("WORLD_ART_PACKAGE_OK " + json.dumps({key: result.get(key) for key in
              ("source_commit", "manifest_sha256", "zip", "sha256", "ok") if key in result}))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, support.CaptureError) as error:
        print("WORLD_ART_PACKAGE_ERROR " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
