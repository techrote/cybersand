#!/usr/bin/env python3
"""Execute bounded source-matched Architectural Generator tests and retain evidence.

Use --graphical for actual framebuffer capture. Headless Windows execution is
identified as such and is never promoted to graphical owner acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.7.stable.official.5b4e0cb0f"
LEGACY_BASE = "ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742"
SCRIPT_FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|GDExtension library not found")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def memory_bytes(child: subprocess.Popen) -> int | None:
    if os.name == "posix":
        try:
            text = Path(f"/proc/{child.pid}/status").read_text()
            match = re.search(r"^VmHWM:\s*(\d+)\s+kB", text, re.M)
            return int(match[1]) * 1024 if match else None
        except OSError:
            return None
    # Godot's Windows console executable launches the engine as a child.
    # Measuring the console wrapper (~5 MB) would mislabel engine memory.
    return None


def run(name: str, command: list[str], env: dict[str, str], output: Path,
        timeout: int, marker: str | None = None) -> dict:
    began = time.monotonic()
    log = output / f"{name}.log"
    peak = 0
    timed_out = False
    with log.open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream,
                                 stderr=subprocess.STDOUT, text=True)
        try:
            while child.poll() is None:
                peak = max(peak, memory_bytes(child) or 0)
                if time.monotonic() - began >= timeout:
                    timed_out = True
                    child.kill()
                    break
                time.sleep(0.05)
            peak = max(peak, memory_bytes(child) or 0)
            code = child.wait(timeout=20)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait(timeout=20)
    text = log.read_text(encoding="utf-8", errors="replace")
    completion = re.findall(marker, text) if marker else []
    passed = code == 0 and not timed_out and not SCRIPT_FAILURE.search(text)
    if marker:
        passed = passed and bool(completion)
    result = {"case": name, "command": command, "returncode": code, "timed_out": timed_out,
              "wall_seconds": time.monotonic() - began, "peak_resident_bytes": peak or None,
              "peak_memory_scope": ("Unavailable: Windows console launcher starts a separate engine; its child working set was not measured"
                                    if os.name == "nt" else
                                    "Godot process high-water RSS sampled while alive; excludes runner and display server"),
              "log_sha256": sha(log), "completion": completion, "passed": bool(passed)}
    (output / f"{name}-process.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("case", "passed", "wall_seconds", "peak_resident_bytes", "completion")}), flush=True)
    if not passed:
        print("\n".join(text.splitlines()[-100:]), file=sys.stderr)
    return result


def source_identity(project: Path, source_root: Path = ROOT) -> dict:
    try:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source_root, text=True).strip()
        tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=source_root, text=True).strip()
    except subprocess.CalledProcessError:
        commit, tree = "unavailable", "unavailable"
    native = project / "addons/cybersand_native/bin" / (
        "cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
    if not native.is_file() or native.read_bytes().startswith(b"version https://git-lfs.github.com/spec/v1"):
        raise ValueError("Source-matched native runtime is absent or is an LFS pointer")
    inputs = {}
    for directory in (source_root / "native/include", source_root / "native/src", source_root / "godot/native_extension"):
        for path in sorted(directory.rglob("*")):
            if path.is_file():
                inputs[path.relative_to(source_root).as_posix()] = sha(path)
    scripts = {}
    for path in sorted(project.rglob("*")):
        if path.is_file() and path.suffix == ".gd" and ".godot" not in path.parts:
            scripts[path.relative_to(project).as_posix()] = sha(path)
    return {"source_commit": commit, "source_tree": tree, "source_inputs_sha256": inputs,
            "runtime_sha256": sha(native), "runtime_bytes": native.stat().st_size,
            "project_scripts_sha256": scripts,
            "runtime_custody": "caller must supply same-source build receipt; hashes alone do not prove compilation"}


def compare_legacy(actual: dict, reference: dict, portable: dict) -> list[dict]:
    if reference.get("source_commit") != LEGACY_BASE or portable.get("source_commit") != LEGACY_BASE:
        raise ValueError("Legacy references must identify the exact immutable accepted base")
    if set(actual["profiles"]) != set(portable["profiles"]) or set(reference["profiles"]) != set(portable["profiles"]):
        raise ValueError("Legacy reference profile set is incomplete or changed")
    complete = {"case": "legacy-material-equivalence", "passed": actual["profiles"] == reference["profiles"],
                "reference_base": reference["source_commit"], "profiles": len(reference["profiles"]),
                "scope": "all captured fields, including native fingerprint and receipt, equal same-platform immutable base"}
    # Existing schema2/3 identity includes an ABI-dependent sizeof memory ledger.
    # Preserve that identity while independently requiring portable raster and
    # canonical recipe equality. The complete comparison above is never reduced.
    portable_keys = ("bounds", "cells", "schema", "recipe_sha256", "material_sha256")
    cross_platform = {"case": "legacy-cross-platform-material-equivalence",
                      "passed": all(actual["profiles"][name][key] == expected[key]
                                    for name, expected in portable["profiles"].items() for key in portable_keys),
                      "reference_base": portable["source_commit"], "profiles": len(portable["profiles"]),
                      "fields": list(portable_keys), "scope": "exact canonical recipes and native material bytes against retained Linux base"}
    return [complete, cross_platform]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--source-root", type=Path, default=ROOT,
                        help="source checkout associated with the supplied runtime (separate for immutable-base capture)")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile", type=Path, help="isolated user directory retained across author/reopen")
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--suite", choices=("all", "native", "owner", "ui", "legacy", "legacy-reference"), default="all")
    parser.add_argument("--legacy-regressions", action="store_true")
    parser.add_argument("--legacy-reference", type=Path,
                        help="complete same-platform receipt from --suite legacy-reference at the immutable base")
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()
    if args.legacy_reference and not (args.legacy_regressions or args.suite == "legacy"):
        parser.error("--legacy-reference requires --legacy-regressions or --suite legacy")
    project, output, engine = args.project.resolve(), args.output.resolve(), args.godot.resolve()
    source_root = args.source_root.resolve()
    output.mkdir(parents=True, exist_ok=True)
    profile = (args.profile or output / "profile").resolve()
    profile.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([str(engine), "--version"], timeout=30, text=True).strip()
    if version != VERSION:
        raise ValueError(f"Godot pin mismatch: {version}")
    identity = source_identity(project, source_root)
    if args.suite == "legacy-reference" and identity["source_commit"] != LEGACY_BASE:
        raise ValueError("Legacy reference must execute the exact immutable accepted-base checkout")
    identity.update({"godot_version": version, "godot_sha256": sha(engine), "platform": sys.platform,
                     "graphical_requested": args.graphical, "suite": args.suite})
    (output / "source-runtime-identity.json").write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
    env = os.environ.copy()
    for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                        ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
        destination = profile / suffix
        destination.mkdir(parents=True, exist_ok=True)
        env[key] = str(destination)
    env["CYBERSAND_ARCHITECTURE_OUTPUT"] = str(output)
    env["CYBERSAND_SOURCE_REVISION"] = identity["source_commit"]
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    results = [run("import", [*base, "--headless", "--editor", "--quit"], env, output, args.timeout)]
    if results[0]["passed"]:
        tests = []
        if args.suite in ("all", "native"):
            tests.append(("project-contract", "res://tests/test_architectural_project_contract.gd",
                          r"ARCHITECTURAL_PROJECT_CONTRACT checks=[1-9][0-9]* failures=0"))
            tests.append(("native", "res://tests/test_architectural_generator.gd",
                          r"ARCHITECTURE_RESULTS phase=native checks=([1-9][0-9]*) failures=0 complete=true"))
        if args.suite in ("all", "ui"):
            tests.append(("ui", "res://tests/test_architectural_generator_ui.gd",
                          r"ARCHITECTURAL_UI checks=[1-9][0-9]* failures=0"))
        if args.suite in ("all", "owner"):
            for phase in ("author", "reopen"):
                tests.append((phase, "res://tests/test_architectural_generator.gd",
                              rf"ARCHITECTURE_RESULTS phase={phase} checks=([1-9][0-9]*) failures=0 complete=true"))
        if args.legacy_regressions:
            for stem in ("worldgen_workbench", "worldgen_fields", "worldgen_typed", "worldgen_grammar", "worldgen_planes"):
                tests.append((stem, f"res://tests/test_{stem}.gd", r"[1-9][0-9]* assertions; 0 failures"))
            tests.append(("gen007_workbench", "res://tests/test_gen007_workbench.gd",
                          r"GEN007_WORKBENCH: [1-9][0-9]* assertions; 0 failures; completed="))
            tests.append(("gen007_inspection", "res://tests/test_gen007_inspection.gd",
                          r"GEN007_INSPECTION: [1-9][0-9]* assertions; 0 failures; completed="))
            tests.append(("workbench_canvas", "res://tests/test_workbench_canvas.gd", r"WORKBENCH_CANVAS [1-9][0-9]* checks, 0 failures"))
        if args.legacy_regressions or args.suite in ("legacy", "legacy-reference"):
            tests.append(("legacy-materials", str(ROOT / "tools/architecture/capture_legacy.gd"),
                          r"ARCHITECTURE_LEGACY checks=5 failures=0"))
            env["CYBERSAND_LEGACY_OUTPUT"] = str(output / "legacy-materials.json")
        for phase, script, marker in tests:
            env["CYBERSAND_ARCHITECTURE_PHASE"] = phase
            graphical = args.graphical and phase in ("ui", "author", "reopen")
            env["CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS"] = "1" if graphical else "0"
            display_flags = ["--headless"]
            if graphical:
                display_flags = ["--rendering-method", "gl_compatibility"]
                display_flags += (["--rendering-driver", "opengl3_angle"] if os.name == "nt"
                                  else ["--display-driver", "x11"])
            command = [*base, *display_flags, "--script", script]
            result = run(phase, command, env, output, args.timeout, marker)
            results.append(result)
            if not result["passed"]:
                break
        if (args.legacy_regressions or args.suite == "legacy") and results[-1]["case"] == "legacy-materials" and results[-1]["passed"]:
            portable = json.loads((ROOT / "tools/architecture/legacy-materials-ac0d9fb9.json").read_text(encoding="utf-8"))
            reference = portable
            if args.legacy_reference:
                reference = json.loads(args.legacy_reference.read_text(encoding="utf-8"))
                if (reference.get("platform") != sys.platform or reference.get("godot_version") != VERSION
                        or not reference.get("capture_qualification_passed", False)):
                    raise ValueError("Legacy reference must be a completed, source-stable capture for this platform and Godot pin")
            actual = json.loads((output / "legacy-materials.json").read_text(encoding="utf-8"))
            comparisons = compare_legacy(actual, reference, portable)
            results.extend(comparisons)
            (output / "legacy-material-comparison.json").write_text(json.dumps(comparisons, indent=2) + "\n", encoding="utf-8")
            for comparison in comparisons:
                print(json.dumps(comparison), flush=True)
    final_identity = source_identity(project, source_root)
    stable = all(identity[key] == final_identity[key] for key in
                 ("runtime_sha256", "source_inputs_sha256", "project_scripts_sha256"))
    results.append({"case": "source-stability", "passed": stable,
                    "scope": "native input bytes, runtime bytes and executed project scripts unchanged throughout campaign"})
    passed = all(item["passed"] for item in results)
    if args.suite == "legacy-reference" and passed:
        receipt_path = output / "legacy-materials.json"
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        receipt.update({"source_commit": identity["source_commit"], "source_tree": identity["source_tree"],
                        "runtime_sha256": identity["runtime_sha256"], "platform": sys.platform,
                        "godot_version": VERSION, "capture_qualification_passed": True})
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    manifest = {"schema": 1, "passed": passed, "cases": results, "source_commit": identity["source_commit"],
                "runtime_sha256": identity["runtime_sha256"], "graphical_requested": args.graphical,
                "failures": sum(not item["passed"] for item in results)}
    (output / "qualification.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
