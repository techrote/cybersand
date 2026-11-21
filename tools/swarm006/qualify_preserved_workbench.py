#!/usr/bin/env python3
"""Scoped real-Godot regression for the SWARM006 accepted-main integration.

This reuses existing tests for Art, Paint, Water, Rapier, Flatten, architecture
and the native reciprocal transaction. It does not replace graphical Windows
source/pristine qualification or attest a retained production binary.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.7.stable.official.5b4e0cb0f"
SOURCE_PATHS = ("godot", "native/include", "native/src", "native/experiments/gentek_swarm", "tools/swarm006")
SOURCE_EXCLUDES = (":(exclude)godot/addons/**/bin/**",)
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|GDExtension library not found")
WATER_SECTIONS = {"activation", "parameters", "workers_substeps", "runtime_apply", "regeneration", "scenario_change",
                  "pause_resume", "invalid_recovery", "solver_switch", "comparison_scenes", "native_validation", "failure_recovery"}
CASES = (
    ("native-authoring", "test_workbench_authoring_patch.gd", "WORKBENCH_AUTHORING_PATCH:", {}, 180),
    ("protocol", "test_workbench_reciprocal_protocol.gd", "SWARM004_PROTOCOL", {}, 60),
    ("controller", "test_workbench_reciprocal_controller.gd", "SWARM004_CONTROLLER", {}, 120),
    ("controls-inspector", "test_workbench_reciprocal_controls.gd", "SWARM004_CONTROLS", {}, 180),
    ("art", "test_art_undo.gd", "ART_UNDO_RESULT", {"ART_UNDO_WORKERS": "1"}, 300),
    ("paint-author", "test_paint_editor_workbench.gd", "PAINT_EDITOR_WORKBENCH", {"PAINT_REOPEN": "0"}, 240),
    ("paint-reopen", "test_paint_editor_workbench.gd", "PAINT_EDITOR_WORKBENCH", {"PAINT_REOPEN": "1"}, 240),
    ("water", "test_workbench_wave.gd", "WORKBENCH_WAVE_RESULT", {}, 420),
    ("rapier-actors", "test_workbench_actor_composition_native.gd", "Workbench actor composition native:", {}, 240),
    ("architecture", "test_architectural_generator.gd", "ARCHITECTURE_RESULTS", {"CYBERSAND_ARCHITECTURE_PHASE": "native"}, 300),
    ("flatten-author", "test_workbench_flatten.gd", "FLATTEN_RESULT", {"FLATTEN_SIDE": "512", "FLATTEN_WORKERS": "1", "FLATTEN_REOPEN": "0"}, 420),
    ("flatten-reopen", "test_workbench_flatten.gd", "FLATTEN_RESULT", {"FLATTEN_SIDE": "512", "FLATTEN_WORKERS": "1", "FLATTEN_REOPEN": "1"}, 420),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=60).strip()


def source_delta(paths: tuple[str, ...]) -> str:
    # Godot imports create .uid sidecars for scripts and shaders. Untracked
    # generated sidecars are not inputs; tracked sidecars remain hash-bound.
    tracked = git("status", "--porcelain", "--untracked-files=no", "--", *paths, *SOURCE_EXCLUDES)
    additions = git("ls-files", "--others", "--exclude-standard", "--", *paths, *SOURCE_EXCLUDES).splitlines()
    source = ["?? " + path for path in additions if not path.endswith(".uid")]
    return "\n".join(([tracked] if tracked else []) + source)


def source_inputs() -> dict:
    # Bind tracked scenes, project settings, shaders and other execution assets
    # as well as scripts. Runtime binaries have their own identity below.
    paths = git("ls-files", "--", *SOURCE_PATHS, *SOURCE_EXCLUDES).splitlines()
    return {path: sha(ROOT / path) for path in paths}


def completion(text: str, marker: str, case: str = "") -> dict:
    lines = [line.removeprefix(marker).strip() for line in text.splitlines() if line.startswith(marker + " ")]
    if len(lines) != 1:
        raise ValueError("Expected exactly one complete assertion report: " + marker)
    tail = lines[0]
    if tail.startswith("{"):
        result = json.loads(tail)
    else:
        match = re.search(r"checks=(\d+)\s+failures=(\d+)", tail) or re.search(r"(\d+) (?:checks|assertions), (\d+) failures", tail)
        if not match:
            raise ValueError("Malformed assertion report: " + marker)
        result = {"checks": int(match[1]), "failures": int(match[2])}
    if type(result.get("checks", result.get("assertions"))) is not int or result.get("checks", result.get("assertions", 0)) < 1 or result.get("failures") not in (0, []):
        raise ValueError("Failed or incomplete assertion report: " + marker)
    if result.get("completed", True) is not True or result.get("passed", True) is not True:
        raise ValueError("Mandatory test stages did not finish: " + marker)
    if marker == "ARCHITECTURE_RESULTS" and "complete=true" not in tail:
        raise ValueError("Native architectural gallery did not complete")
    if marker == "WORKBENCH_WAVE_RESULT":
        sections = result.get("sections", {})
        if (result.get("real_workbench") is not True or not isinstance(sections, dict)
                or set(sections) != WATER_SECTIONS or not all(value is True for value in sections.values())):
            raise ValueError("Real Workbench Water stages are incomplete")
    expected = {}
    if case.startswith("paint-"):
        expected = {"reopen": "1" if case == "paint-reopen" else "0"}
    elif case.startswith("flatten-"):
        expected = {"phase": "reopen" if case == "flatten-reopen" else "author",
                    "side": 512, "workers": 1, "canonical_bytes": 512 * 512 * 2}
    elif case == "art":
        expected = {"workers": 1}
    if any(type(result.get(key)) is not type(value) or result.get(key) != value for key, value in expected.items()):
        raise ValueError("Wrong author/reopen mode or declared fixture scope: " + case)
    if case == "architecture" and "phase=native " not in tail:
        raise ValueError("Wrong architectural qualification phase")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--cli", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--development", action="store_true", help="Explicitly unqualified local dirty-source engineering run")
    args = parser.parse_args()
    output, engine, cli = args.output.resolve(), args.godot.resolve(), args.cli.resolve()
    if output.exists():
        raise ValueError("Refusing existing evidence directory")
    if subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip() != VERSION:
        raise ValueError("Godot pin mismatch")
    dirty = source_delta(SOURCE_PATHS)
    if dirty and not args.development:
        raise ValueError("Qualification source must be committed and clean")
    output.mkdir(parents=True)
    native = ROOT / "godot/addons/cybersand_native/bin" / ("cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
    rapier = ROOT / "godot/addons/godot-rapier2d/bin" / ("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if os.name == "nt" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
    magic = b"MZ" if os.name == "nt" else b"\x7fELF"
    if not native.read_bytes().startswith(magic):
        raise ValueError("Native runtime is not materialized for this host")
    inputs = source_inputs()
    identity = {"source": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
                "platform": sys.platform, "development": args.development, "source_delta": dirty,
                "engine_sha256": sha(engine), "native_sha256": sha(native), "rapier_sha256": sha(rapier),
                "cli_sha256": sha(cli), "inputs": inputs}
    (output / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    spec = importlib.util.spec_from_file_location("frozen_process_runner", ROOT / "native/experiments/gentek_swarm/run_swarm006.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    base = [str(engine), "--headless", "--audio-driver", "Dummy", "--path", str(ROOT / "godot")]
    environment = os.environ.copy()
    environment.update(CYBERSAND_SWARM004_CLI=str(cli), CYBERSAND_SWARM004_SOURCE=identity["source"],
                       CYBERSAND_SWARM004_SHA256=identity["cli_sha256"], CYBERSAND_SOURCE_REVISION=identity["source"])
    results = []
    for name, script, marker, extra, timeout in (("import", "", "", {}, 180), *CASES):
        group = name.split("-")[0] if name.startswith(("paint-", "flatten-")) else name
        env = environment.copy()
        for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"):
            target = output / "profiles" / group / variable
            target.mkdir(parents=True, exist_ok=True)
            env[variable] = str(target)
        env.update(extra)
        command = [*base, "--editor", "--quit"] if name == "import" else [*base, "--script", "res://tests/" + script]
        # Frozen process helper inherits its environment; run this script's
        # sequential children with isolated per-fixture profiles and no providers.
        prior = os.environ.copy()
        try:
            os.environ.clear(); os.environ.update(env)
            record = runner.execute(command, output / (name + ".log"), timeout, ROOT)
        finally:
            os.environ.clear(); os.environ.update(prior)
        text = (output / (name + ".log")).read_text(encoding="utf-8", errors="replace")
        errors = []
        if record["returncode"] != 0 or record["timed_out"] or not record["child_reaped"] or ERRORS.search(text):
            errors.append("Godot process/script failed")
        try:
            if marker:
                record["assertions"] = completion(text, marker, name)
        except (ValueError, TypeError) as error:
            errors.append(str(error))
        record.update(name=name, script=script, errors=errors, passed=not errors)
        results.append(record)
        (output / (name + "-process.json")).write_text(json.dumps(record, indent=2) + "\n")
        print(json.dumps({"case": name, "passed": not errors, "errors": errors}), flush=True)
    unchanged = (git("rev-parse", "HEAD") == identity["source"] and sha(engine) == identity["engine_sha256"]
                 and sha(cli) == identity["cli_sha256"]
                 and sha(native) == identity["native_sha256"] and sha(rapier) == identity["rapier_sha256"]
                 and source_inputs() == inputs and source_delta(SOURCE_PATHS) == dirty)
    passed = unchanged and all(r["passed"] for r in results)
    (output / "qualification.json").write_text(json.dumps({"scope": __doc__, "identity": identity,
        "passed": passed, "inputs_unchanged": unchanged, "results": results}, indent=2) + "\n")
    return int(not passed)


if __name__ == "__main__":
    sys.exit(main())
