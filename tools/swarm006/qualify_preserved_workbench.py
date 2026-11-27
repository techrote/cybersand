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

import qualify_workbench as input_qualification

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.7.stable.official.5b4e0cb0f"
SOURCE_PATHS = (".gitattributes", "godot", "native/include", "native/src", "native/experiments/gentek_swarm", "tools/swarm006", "tools/swarm45")
SOURCE_EXCLUDES = (":(exclude)godot/addons/**/bin/**",)
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|GDExtension library not found")
WATER_SECTIONS = {"activation", "parameters", "workers_substeps", "runtime_apply", "regeneration", "scenario_change",
                  "pause_resume", "invalid_recovery", "solver_switch", "comparison_scenes", "native_validation", "failure_recovery"}
CASES = (
    ("native-authoring", "test_workbench_authoring_patch.gd", "WORKBENCH_AUTHORING_PATCH:", {}, 180),
    ("protocol", "test_workbench_reciprocal_protocol.gd", "SWARM004_PROTOCOL", {}, 60),
    ("controller", "test_workbench_reciprocal_controller.gd", "SWARM004_CONTROLLER", {}, 120),
    ("controls-inspector", "swarm45_reciprocal_controls.gd", "SWARM004_CONTROLS", {}, 180),
    ("input-integrity", "swarm006_reciprocal_input.gd", "SWARM006_INPUT_INTEGRITY", {}, 180),
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


def native_paths(project: Path | None = None) -> tuple[Path, Path]:
    project = project or ROOT / "godot"
    native = project / "addons/cybersand_native/bin" / ("cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
    rapier = project / "addons/godot-rapier2d/bin" / ("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if os.name == "nt" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
    return native, rapier


def execution_inputs(project: Path, expected: dict | None = None) -> dict:
    """Hash raw installed source/assets/runtime; allow only new generated UID/cache files."""
    records = {}
    for path in sorted(project.rglob("*")):
        if path.is_symlink():
            raise ValueError("Execution project contains a symlink")
        if not path.is_file() or ".godot" in path.relative_to(project).parts:
            continue
        name = path.relative_to(project).as_posix()
        if expected is not None and path.suffix == ".uid" and name not in expected:
            continue
        records[name] = sha(path)
    return records


def identity_errors(identity: dict, engine: Path, cli: Path) -> list[str]:
    """The same exact-byte custody check ends the suite and follows graphics."""
    project = Path(identity["project"]) if "project" in identity else None
    native, rapier = native_paths(project)
    checks = {"source": lambda: git("rev-parse", "HEAD"), "tree": lambda: git("rev-parse", "HEAD^{tree}"),
              "platform": lambda: sys.platform, "engine_sha256": lambda: sha(engine), "cli_sha256": lambda: sha(cli),
              "native_sha256": lambda: sha(native), "rapier_sha256": lambda: sha(rapier),
              "inputs": source_inputs, "source_delta": lambda: source_delta(SOURCE_PATHS)}
    if project is not None:
        checks["execution_inputs"] = lambda: execution_inputs(project, identity.get("execution_inputs"))
    if "runtime_manifest" in identity:
        checks["runtime_manifest_sha256"] = lambda: sha(Path(identity["runtime_manifest"]))
    errors = []
    for key, read in checks.items():
        try:
            if read() != identity.get(key):
                errors.append("Preservation identity changed: " + key)
        except (OSError, subprocess.SubprocessError) as error:
            errors.append("Cannot recheck preservation " + key + ": " + str(error))
    return errors


def recheck_preservation(prior: Path, output: Path, engine: Path, cli: Path) -> int:
    """Recheck a completed suite after graphical consumers, without rerunning it."""
    if output.exists():
        raise ValueError("Refusing existing evidence directory")
    errors = []
    records = {}
    for name in ("identity", "qualification", "qualification-integrity"):
        try:
            value = json.loads((prior / (name + ".json")).read_text(encoding="utf-8"))
            if not isinstance(value, dict):
                raise ValueError("Expected an object")
            records[name] = value
        except (OSError, ValueError) as error:
            records[name] = {}
            errors.append("Missing or malformed prior " + name + ": " + str(error))
    identity, qualification, integrity = (records[key] for key in ("identity", "qualification", "qualification-integrity"))
    if type(integrity.get("schema")) is not int or integrity.get("schema") != 1 or integrity.get("source") != identity.get("source"):
        errors.append("Prior preservation integrity identity is invalid")
    for name in ("identity", "qualification"):
        path = prior / (name + ".json")
        if not path.is_file() or sha(path) != integrity.get(name + "_sha256"):
            errors.append("Prior preservation bytes changed: " + name)
    if (identity.get("development") is not False or identity.get("source_delta") != ""
            or not isinstance(identity.get("inputs"), dict) or ".gitattributes" not in identity.get("inputs", {})):
        errors.append("Prior preservation is not a clean source-bound qualification")
    if (qualification.get("passed") is not True or qualification.get("inputs_unchanged") is not True
            or qualification.get("identity") != identity):
        errors.append("Prior preservation did not finish with unchanged identity")
    results = qualification.get("results")
    expected = [("import", "")] + [(name, script) for name, script, _, _, _ in CASES]
    if (not isinstance(results, list) or len(results) != len(expected)
            or any(not isinstance(result, dict) or (result.get("name"), result.get("script")) != pair
                   for result, pair in zip(results if isinstance(results, list) else [], expected))):
        errors.append("Prior preservation has missing or unexpected completed cases")
    else:
        for result in results:
            if (result.get("passed") is not True or result.get("errors") != [] or result.get("returncode") != 0
                    or type(result.get("returncode")) is not int or result.get("timed_out") is not False
                    or result.get("child_reaped") is not True):
                errors.append("Prior preservation process did not pass: " + result["name"])
            path = prior / (result["name"] + ".log")
            if not path.is_file() or sha(path) != result.get("log_sha256"):
                errors.append("Prior preservation process log changed: " + result["name"])
    errors.extend(identity_errors(identity, engine, cli))
    output.mkdir(parents=True)
    record = {"schema": 1, "stage": "post-consumer-identity", "passed": not errors, "errors": errors,
              "prior_directory": str(prior), "prior_source": identity.get("source"),
              "prior_identity_sha256": integrity.get("identity_sha256"),
              "prior_qualification_sha256": integrity.get("qualification_sha256"),
              "scope": "Exact source/runtime and completed preservation evidence recheck; no tests rerun"}
    (output / "identity-recheck.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(record), flush=True)
    return int(bool(errors))


def retain_source_refusal(output: Path, dirty: str, engine: Path, cli: Path) -> Path:
    """Keep exact admission evidence without accepting or rewriting dirty inputs."""
    # Porcelain can report M even when a filtered semantic diff is empty.
    # Preserve exactly those refused paths, including both sides of a rename.
    status = subprocess.check_output(["git", "status", "--porcelain=v1", "-z", "--untracked-files=all", "--",
                                      *SOURCE_PATHS, *SOURCE_EXCLUDES], cwd=ROOT, timeout=60).decode("utf-8")
    entries = iter(status.split("\0"))
    paths = set()
    for entry in entries:
        if not entry:
            continue
        code, path = entry[:2], entry[3:]
        if code != "??" or not path.endswith(".uid"):
            paths.add(path)
        if "R" in code or "C" in code:
            original = next(entries, "")
            if original:
                paths.add(original)
    files = {}
    for path in sorted(paths):
        committed = subprocess.run(["git", "show", "HEAD:" + path], cwd=ROOT, capture_output=True, timeout=60)
        actual = ROOT / path
        files[path] = {"working_sha256": sha(actual) if actual.is_file() else None,
                       "committed_sha256": hashlib.sha256(committed.stdout).hexdigest() if committed.returncode == 0 else None}
    try:
        inputs, inventory_error = source_inputs(), None
    except OSError as error:
        inputs, inventory_error = None, str(error)
    record = {"schema": 1, "stage": "source-admission", "passed": False,
              "reason": "Qualification source must be committed and clean", "source": git("rev-parse", "HEAD"),
              "tree": git("rev-parse", "HEAD^{tree}"), "platform": sys.platform, "source_delta": dirty,
              "porcelain_status": status, "changed_files": files, "inputs": inputs, "source_input_inventory_error": inventory_error,
              "engine_sha256": sha(engine) if engine.is_file() else None,
              "cli_sha256": sha(cli) if cli.is_file() else None}
    output.mkdir(parents=True)
    path = output / "source-admission-refusal.json"
    path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return path


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
    parser.add_argument("--project", type=Path, help="Verified external source stage or pristine extracted project")
    parser.add_argument("--runtime", type=Path, help="Unified exact-source target runtime; positive gates use installed manifests")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--development", action="store_true", help="Explicitly unqualified local dirty-source engineering run")
    parser.add_argument("--recheck", type=Path, help="Only recheck exact custody of this earlier successful preservation directory")
    args = parser.parse_args()
    output, engine, cli = args.output.resolve(), args.godot.resolve(), args.cli.resolve()
    if output.exists():
        raise ValueError("Refusing existing evidence directory")
    if args.recheck is not None:
        return recheck_preservation(args.recheck.resolve(), output, engine, cli)
    if subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip() != VERSION:
        raise ValueError("Godot pin mismatch")
    dirty = source_delta(SOURCE_PATHS)
    if dirty and not args.development:
        evidence = retain_source_refusal(output, dirty, engine, cli)
        raise ValueError("Qualification source must be committed and clean; evidence: " + str(evidence))
    output.mkdir(parents=True)
    project = args.project.resolve() if args.project else ROOT / "godot"
    native, rapier = native_paths(project)
    magic = b"MZ" if os.name == "nt" else b"\x7fELF"
    if not native.read_bytes().startswith(magic):
        raise ValueError("Native runtime is not materialized for this host")
    inputs = source_inputs()
    identity = {"source": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
                "platform": sys.platform, "development": args.development, "source_delta": dirty,
                "engine_sha256": sha(engine), "native_sha256": sha(native), "rapier_sha256": sha(rapier),
                "cli_sha256": sha(cli), "inputs": inputs}
    if args.project:
        identity.update(project=str(project), execution_inputs=execution_inputs(project))
    if args.runtime:
        if not args.project or args.development:
            raise ValueError("Unified preservation requires an exact external project and no development override")
        spec = importlib.util.spec_from_file_location("unified_preservation_custody", ROOT / "tools/swarm45/runtime_custody.py")
        unified = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(unified)
        receipt = unified.verify(args.runtime.resolve())
        platform = "windows" if os.name == "nt" else "linux"
        if (receipt["platform"] != platform or cli != project / "tools" / receipt["cli"]
                or sha(cli) != receipt["files"][receipt["cli"]]["sha256"]
                or sha(native) != receipt["files"][receipt["extension"]]["sha256"]
                or json.loads((project / "tools" / ("swarm004-runtime." + platform + ".json")).read_bytes()) != unified.cli_binding(receipt)):
            raise ValueError("Unified preservation must use the installed source/target-bound native payload")
        manifest = args.runtime.resolve() / unified.NAME
        identity.update(runtime_manifest=str(manifest), runtime_manifest_sha256=sha(manifest),
                        qualification_programme=unified.QUALIFICATION_PROGRAMME, build_context=receipt["build_context"])
    (output / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    spec = importlib.util.spec_from_file_location("frozen_process_runner", ROOT / "native/experiments/gentek_swarm/run_swarm006.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    base = [str(engine), "--headless", "--audio-driver", "Dummy", "--path", str(project)]
    environment = os.environ.copy()
    if args.runtime:
        for key in ("CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"):
            environment.pop(key, None)
        environment["CYBERSAND_SOURCE_REVISION"] = identity["source"]
    else:
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
        if name == "input-integrity":
            (output / name).mkdir()
            env["SWARM004_UI_EVIDENCE"] = str(output / name)
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
            if name == "input-integrity":
                errors.extend(input_qualification.input_integrity_errors(output / name, record["assertions"],
                    identity["source"], identity["cli_sha256"], sha(project / input_qualification.INPUT_SCRIPT), require_graphics=False))
        except (ValueError, TypeError) as error:
            errors.append(str(error))
        record.update(name=name, script=script, errors=errors, passed=not errors)
        results.append(record)
        (output / (name + "-process.json")).write_text(json.dumps(record, indent=2) + "\n")
        print(json.dumps({"case": name, "passed": not errors, "errors": errors}), flush=True)
    custody_errors = identity_errors(identity, engine, cli)
    unchanged = not custody_errors
    passed = unchanged and all(r["passed"] for r in results)
    (output / "qualification.json").write_text(json.dumps({"scope": __doc__, "identity": identity,
        "passed": passed, "inputs_unchanged": unchanged, "identity_errors": custody_errors, "results": results}, indent=2) + "\n")
    (output / "qualification-integrity.json").write_text(json.dumps({"schema": 1, "source": identity["source"],
        "identity_sha256": sha(output / "identity.json"), "qualification_sha256": sha(output / "qualification.json")}, indent=2) + "\n")
    return int(not passed)


if __name__ == "__main__":
    sys.exit(main())
