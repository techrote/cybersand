#!/usr/bin/env python3
"""Compile the unchanged native oracle and an independent shadow metadata probe.

This is a bounded native-metadata check, not a World or UI qualification. No
production consumer imports the complete shadow; the separately admitted Main
display-name resource has its own mandatory B-consumer report. There is no
baseline-refresh mode.
The compiled native implementation, authenticated against the retained Git
checkpoint, is the oracle; neither authored JSON nor compiler output is used to
construct its facts. Reports include measured tool costs and source custody.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time
from typing import Any

import compatibility
import proof_scopes

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path("materials/catalogue/catalogue.json")
CANDIDATE = Path("materials/catalogue/generated/catalogue.shadow.hpp")
ORACLE = Path("tools/material_catalogue/native_oracle.cpp")
NATIVE_SOURCE = Path("native/src/material_rules.cpp")
RECEIPT_PATHS = {
    "tool_sources": (
        "tools/material_catalogue/native_oracle.cpp",
        "tools/material_catalogue/check_native_parity.py",
        "tools/material_catalogue/compatibility.py",
        "tools/material_catalogue/compiler.py",
        "tools/material_catalogue/proof_scopes.py",
        "tools/material_catalogue/presentation.py",
        "tools/material_catalogue/display_contract.py",
        "tools/material_catalogue/legacy_display_names.py",
    ),
    "inputs": (
        "materials/catalogue/catalogue.json",
        "materials/catalogue/generated/catalogue.shadow.hpp",
        "materials/catalogue/generated/catalogue_shadow.gd",
        "materials/catalogue/generated/inspection.json",
        "materials/catalogue/generated/manifest.json",
        "materials/catalogue/compatibility-lock.json",
    ),
    # Byte custody only. Neither native compilation nor shadow readback can
    # prove that the application actually routes labels through this resource.
    "consumer_source_custody": (
        "materials/catalogue/presentation.json",
        "materials/catalogue/presentation-manifest.json",
        "godot/scripts/generated/material_ui_names.gd",
        "godot/scripts/main.gd",
        "godot/scripts/microscenario_identity.gd",
        "tools/material_catalogue/fixtures/main-display-names-v1.json",
    ),
    "legacy_sources": tuple(sorted(compatibility.SOURCE_ROLES)),
}
NATIVE_RECEIPT_FIELDS = {
    "schema_id", "schema_version", "status", "scope", "source_commit", "source_commit_role",
    "checked_source", "protected_sources", "source_locks", *RECEIPT_PATHS,
    "compiler_version", "commands", "snapshot_sha256", "metadata",
    "native_authored_compiled_shadow_facts_equal", "compiled_queries", "fallback",
    "generated_mirrors", "measured_tool_costs", "cost_qualification", "world_executed",
    "physics_qualification", "godot_executed", "ui_behavior_executed", "b_consumer_qualified",
    "authority_scopes", "b_consumer_requirement",
}


class ParityError(ValueError):
    """A source, metadata, compile, or executable comparison failed."""


def _duplicate_keys(pairs: list[tuple[str, Any]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ParityError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _nonfinite(token: str) -> None:
    raise ParityError(f"non-finite JSON number {token}")


def read_json(text: str, label: str) -> Any:
    try:
        return json.loads(text, object_pairs_hook=_duplicate_keys, parse_constant=_nonfinite)
    except (ValueError, RecursionError) as error:
        raise ParityError(f"{label}: invalid JSON: {error}") from error


def _pointer(path: str, key: str | int) -> str:
    return path + "/" + str(key).replace("~", "~0").replace("/", "~1")


def compare(expected: Any, actual: Any, label: str, pointer: str = "") -> None:
    """Type-strict, path-qualified comparison, with ordered legacy tables.

    In particular True != 1, and a table reorder is not hidden by sorting here.
    """
    location = f"{label}#{pointer or '/'}"
    if type(expected) is not type(actual):
        raise ParityError(f"{location}: expected {type(expected).__name__}, got {type(actual).__name__}")
    if isinstance(expected, dict):
        missing, extra = sorted(set(expected) - set(actual)), sorted(set(actual) - set(expected))
        if missing or extra:
            raise ParityError(f"{location}: field mismatch; missing={missing}, extra={extra}")
        for key in expected:
            compare(expected[key], actual[key], label, _pointer(pointer, key))
    elif isinstance(expected, list):
        if len(expected) != len(actual):
            raise ParityError(f"{location}: expected {len(expected)} rows, got {len(actual)}")
        for index, (left, right) in enumerate(zip(expected, actual)):
            compare(left, right, label, _pointer(pointer, index))
    elif expected != actual:
        raise ParityError(f"{location}: native={expected!r}, candidate={actual!r}")


# Authored lists are sets keyed by explicit identities. Their source ordering
# carries no inheritance or precedence. Compiled candidate tables, however,
# are compared in exact native order by compare(), including legacy slots.
_AUTHORED_KEYS = {
    "/native/identity/aliases": ("namespace", "name"),
    "/native/materials": ("id",), "/native/capabilities": ("id",),
    "/native/appearance": ("id",),
    "/native/interactions/channels": ("channel",),
    "/native/interactions/layer_kinds": ("kind",),
    "/native/interactions/pairs": ("legacy_slot",),
    "/native/interactions/specialized": ("legacy_slot",),
    "/native/interactions/families": ("id",),
    "/native/interactions/memberships": ("family_id", "material"),
    "/native/interactions/coverage": ("subject_id", "channel_id"),
    "/native/interactions/tuning_passes": ("id",),
}


def compare_authored(expected: Any, actual: Any, label: str, pointer: str = "/native") -> None:
    if type(expected) is not type(actual):
        compare(expected, actual, label, pointer)
    elif isinstance(expected, dict):
        missing, extra = sorted(set(expected) - set(actual)), sorted(set(actual) - set(expected))
        if missing or extra:
            raise ParityError(f"{label}#{pointer}: field mismatch; missing={missing}, extra={extra}")
        for key in expected:
            compare_authored(expected[key], actual[key], label, _pointer(pointer, key))
    elif pointer in _AUTHORED_KEYS:
        fields = _AUTHORED_KEYS[pointer]
        if len(expected) != len(actual):
            raise ParityError(f"{label}#{pointer}: expected {len(expected)} rows, got {len(actual)}")

        def identity(row: Any, at: str) -> str:
            if not isinstance(row, dict) or not all(field in row for field in fields):
                raise ParityError(f"{label}#{at}: expected explicit identity fields {fields}")
            # JSON distinguishes boolean, numeric and string identity values.
            return json.dumps([row[field] for field in fields], sort_keys=True, allow_nan=False)

        actual_rows = {}
        for index, row in enumerate(actual):
            key = identity(row, _pointer(pointer, index))
            if key in actual_rows:
                previous = actual_rows[key][0]
                raise ParityError(f"{label}#{pointer}/{index}: duplicate identity {key}; first at {pointer}/{previous}")
            actual_rows[key] = (index, row)
        for row in expected:
            key = identity(row, pointer)
            if key not in actual_rows:
                raise ParityError(f"{label}#{pointer}: missing native identity {key}")
            index, actual_row = actual_rows[key]
            compare(row, actual_row, label, _pointer(pointer, index))
    else:
        compare(expected, actual, label, pointer)


def _shadow_mirrors(native: dict, gdscript: Path, inspection_path: Path) -> dict:
    text = gdscript.read_text(encoding="utf-8")
    marker = "const NATIVE_FACTS: Dictionary = "
    if text.count(marker) != 1:
        raise ParityError(f"{gdscript}: expected exactly one literal NATIVE_FACTS dictionary")
    prefix, _, payload = text.partition(marker)
    for declaration in ("const PRODUCTION_AUTHORITY: bool = false", 'const SCOPE: String = "current-shadow"',
                        'const BACKEND: String = "native"'):
        if declaration not in prefix.splitlines():
            raise ParityError(f"{gdscript}: missing explicit shadow declaration {declaration!r}")
    compare(native, read_json(payload, str(gdscript)), str(gdscript), "/NATIVE_FACTS")
    inspection = read_json(inspection_path.read_text(encoding="utf-8"), str(inspection_path))
    if not isinstance(inspection, dict) or "native" not in inspection:
        raise ParityError(f"{inspection_path}#/: missing native inspection facts")
    compare(native, inspection["native"], str(inspection_path), "/native")
    compare("shadow-only", inspection.get("authority"), str(inspection_path), "/authority")
    compare("native", inspection.get("backend"), str(inspection_path), "/backend")
    return {"gdscript_literal_facts_equal": True, "inspection_facts_equal": True,
            "godot_executed": False,
            "qualification": "The generated GDScript literal is compared as JSON-compatible metadata; no Godot parser or fallback physics execution."}


def run(command: list[str], root: Path, *, timeout: float = 60) -> tuple[str, float]:
    start = time.perf_counter()
    try:
        process = subprocess.run(command, cwd=root, text=True, encoding="utf-8", errors="strict",
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout,
                                 check=False)
    except (OSError, UnicodeError, subprocess.TimeoutExpired) as error:
        raise ParityError(f"metadata command failed: {shlex.join(command)}: {error}") from error
    elapsed = time.perf_counter() - start
    if process.returncode:
        diagnostic = (process.stderr or process.stdout).strip()
        raise ParityError(f"metadata command exited {process.returncode}: {shlex.join(command)}\n{diagnostic}")
    return process.stdout, elapsed


def file_fact(path: Path, root: Path) -> dict:
    data = path.read_bytes()
    try:
        name = path.relative_to(root).as_posix()
    except ValueError:
        name = str(path)
    return {"path": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def _fallback(native: dict, lock: dict) -> dict:
    facts = lock["fallback_source_facts"]
    materials, capabilities = native["materials"], native["capabilities"]
    native_rgba = []
    for row in materials:
        r, g, b, a = row["rgba"]
        native_rgba.append((r << 24) | (g << 16) | (b << 8) | a)
    compare(native_rgba, facts["base_rgba8"], "fallback/source-palette")
    compare([row["id"] for row in capabilities if row["hard_surface"]],
            facts["hard_surface_ids"], "fallback/hard-surface")
    compare([row["id"] for row in capabilities if row["granular_support"]],
            facts["granular_support_ids"], "fallback/granular-support")
    compare(sorted(row["id"] for row in materials if row["valid"]),
            sorted(facts["identity_constants"].values()), "fallback/identity-id-set")
    native_slush = materials[21]
    compare("slush", native_slush["name"], "native/slush-name")
    compare(1080, native_slush["density"], "native/slush-density")
    compare(1100, facts["slush_density"], "fallback/slush-density")
    compare(1100, facts["density_by_byte_id"][21], "fallback/slush-density-byte-id")
    return {"source_qualified_only": True, "godot_executed": False,
            "palette_rgba8_rows_equal": len(native_rgba),
            "hard_surface_ids_equal": len(facts["hard_surface_ids"]),
            "granular_support_ids_equal": len(facts["granular_support_ids"]),
            "valid_identity_id_set_equal": len(facts["identity_constants"]),
            "retained_slush_density": {"native": native_slush["density"], "fallback": facts["slush_density"]},
            "other_fallback_density_equality_asserted": False}


def check(root: Path = ROOT, *, source: Path | None = None, candidate: Path | None = None,
          cxx: str = "c++") -> dict:
    root = root.resolve()
    source = (source or root / SOURCE).resolve()
    candidate = (candidate or root / CANDIDATE).resolve()
    # Authenticate the protected bytes before compiling anything. Editing both
    # the lock and current sources cannot turn them into an accepted baseline.
    protected = compatibility.check(root)
    lock = compatibility.read_lock(root / compatibility.LOCK)
    authored = read_json(source.read_text(encoding="utf-8"), str(source))
    if not isinstance(authored, dict) or "native" not in authored:
        raise ParityError(f"{source}#/: expected an authored object with /native")
    compare({"schema_id": "cybersand.material-catalogue.shadow", "schema_version": 1, "scope": "current-shadow"},
            {key: value for key, value in authored.items() if key != "native"}, str(source))
    if not candidate.is_file():
        raise ParityError(f"{candidate}: missing shadow header; run the compiler explicitly")
    gdscript = candidate.with_name("catalogue_shadow.gd")
    inspection = candidate.with_name("inspection.json")
    compiler = shlex.split(cxx)
    if not compiler:
        raise ParityError("--cxx requires a compiler executable")
    version, _ = run([*compiler, "--version"], root, timeout=10)
    version = version.strip()
    # Hash the tools actually executing even when --root selects another source
    # checkout. Such an external-tool receipt cannot masquerade as a canonical
    # repository-bound Godot proof.
    tool_paths = [root / ORACLE, *(Path(__file__).with_name(Path(relative).name).resolve()
                                  for relative in RECEIPT_PATHS["tool_sources"][1:])]
    input_paths = [source, candidate, gdscript, inspection, candidate.with_name("manifest.json"),
                   root / compatibility.LOCK]
    custody_paths = {"tool_sources": tool_paths, "inputs": input_paths,
                     **{group: [root / relative for relative in RECEIPT_PATHS[group]]
                        for group in ("consumer_source_custody", "legacy_sources")}}
    inventories = {group: [file_fact(path, root) for path in paths]
                   for group, paths in custody_paths.items()}
    checked_source = proof_scopes.checked_source(root, inventories)
    measurements = {}
    with tempfile.TemporaryDirectory(prefix="cybersand-mat353-parity-") as directory:
        temporary = Path(directory)
        native_executable = temporary / "native-oracle"
        candidate_executable = temporary / "candidate-parity"
        common = [*compiler, "-std=c++20", "-O2", "-Wall", "-Wextra", "-Werror", "-I", str(root / "native/include")]
        original_command = [*common, str(root / ORACLE), str(root / NATIVE_SOURCE), "-o", str(native_executable)]
        _, measurements["native_compile_seconds"] = run(original_command, root)
        # The header is actually compiled and interpreted; parsing its text or
        # comparing two Python representations alone would not establish this.
        # Include spelling is a preprocessor string, not shell code.
        if any(character in str(candidate) for character in ('"', '\\', '\n', '\r')):
            raise ParityError("candidate header path cannot contain quotes, backslashes, or newlines")
        include_macro = '-DCYBERSAND_MATERIAL_CANDIDATE_HEADER="' + str(candidate) + '"'
        candidate_command = [*common, include_macro, str(root / ORACLE), str(root / NATIVE_SOURCE),
                             "-o", str(candidate_executable)]
        _, measurements["candidate_compile_seconds"] = run(candidate_command, root)
        original_output, measurements["native_snapshot_seconds"] = run([str(native_executable), "--snapshot"], root)
        original = read_json(original_output, "compiled original native snapshot")
        compare_authored(original, authored["native"], str(source))
        candidate_output, measurements["candidate_snapshot_seconds"] = run([str(candidate_executable), "--candidate-snapshot"], root)
        compiled_candidate = read_json(candidate_output, "compiled candidate snapshot")
        compare(original, compiled_candidate, str(candidate))
        parity_output, measurements["candidate_validation_seconds"] = run([str(candidate_executable), "--parity"], root)
        parity = read_json(parity_output, "compiled candidate parity")
        if not isinstance(parity, dict) or parity.get("status") != "PASS":
            raise ParityError("compiled candidate did not report PASS")
        fallback = _fallback(original, lock)
        mirrors = _shadow_mirrors(original, gdscript, inspection)
        measurements["native_executable_bytes"] = native_executable.stat().st_size
        measurements["candidate_executable_bytes"] = candidate_executable.stat().st_size

        def recipe(command: list[str]) -> list[str]:
            return [part.replace(str(temporary), "${BUILD_DIRECTORY}").replace(str(root), "${REPO_ROOT}")
                    for part in command]

        commands = {"native_compile": recipe(original_command), "candidate_compile": recipe(candidate_command),
                    "native_snapshot": ["${BUILD_DIRECTORY}/native-oracle", "--snapshot"],
                    "candidate_snapshot": ["${BUILD_DIRECTORY}/candidate-parity", "--candidate-snapshot"],
                    "candidate_validation": ["${BUILD_DIRECTORY}/candidate-parity", "--parity"]}
    for key, measured in measurements.items():
        if key.endswith("_seconds"):
            measurements[key] = round(measured, 6)
    # Close source custody after all probes, so concurrent source changes do
    # not silently receive a PASS under hashes taken at a different instant.
    compare(protected, compatibility.check(root), "post-check protected source identity")
    after = {group: [file_fact(path, root) for path in paths]
             for group, paths in custody_paths.items()}
    compare(inventories, after, "post-check input/tool/source custody")
    compare(checked_source, proof_scopes.checked_source(root, after), "post-check source identity")
    counts = {"material_slots": len(original["materials"]), "descriptor_fields_per_slot": 15,
              "valid_ids": sum(row["valid"] for row in original["materials"]),
              "hard_surface_ids": sum(row["hard_surface"] for row in original["capabilities"]),
              "granular_support_ids": sum(row["granular_support"] for row in original["capabilities"]),
              "pair_rules": len(original["interactions"]["pairs"]),
              "specialized_mechanisms": len(original["interactions"]["specialized"]),
              "semantic_families": len(original["interactions"]["families"]),
              "memberships": len(original["interactions"]["memberships"]),
              "coverage_records": len(original["interactions"]["coverage"]),
              "tuning_passes": len(original["interactions"]["tuning_passes"])}
    return {"schema_id": "cybersand.material-catalogue.native-parity", "schema_version": 2,
            "status": "PASS", "scope": proof_scopes.NATIVE_PROOF_SCOPE,
            "source_commit": compatibility.BASELINE, "protected_sources": protected,
            "source_commit_role": proof_scopes.NATIVE_SOURCE_COMMIT_ROLE,
            "checked_source": checked_source, "source_locks": lock["source_locks"], **inventories,
            "authority_scopes": copy.deepcopy(proof_scopes.AUTHORITY_SCOPES),
            "b_consumer_requirement": copy.deepcopy(proof_scopes.B_CONSUMER_REQUIREMENT),
            "compiler_version": version, "commands": commands,
            "snapshot_sha256": hashlib.sha256(original_output.encode("utf-8")).hexdigest(),
            "metadata": counts, "native_authored_compiled_shadow_facts_equal": True,
            "compiled_queries": parity, "fallback": fallback, "generated_mirrors": mirrors,
            "measured_tool_costs": measurements,
            "cost_qualification": "One local standalone metadata compile/probe run; not a simulation or performance benchmark. Timings vary by host and load.",
            "world_executed": False, "physics_qualification": False, "godot_executed": False,
            "ui_behavior_executed": False, "b_consumer_qualified": False}


def _report_output(path: Path, root: Path, *, source: Path | None = None,
                   candidate: Path | None = None) -> Path:
    """Refuse output/input aliases before any probe, including external inputs.

    Resolve both sides: a selected input may itself be a symlink, and a report
    can reach it through a file or parent-directory alias. Existing hard links
    are refused too. The fixed source paths do not depend on a mutable lock's
    claims about what is protected.
    """
    try:
        root = root.resolve()
        destination = path.resolve()
        selected_source = (source or root / SOURCE).resolve()
        selected_candidate = (candidate or root / CANDIDATE).resolve()
        repositories = {root, ROOT.resolve()}
        protected = {
            selected_source, selected_candidate,
            *(selected_candidate.with_name(name) for name in (
                "catalogue_shadow.gd", "inspection.json", "manifest.json")),
            *(Path(__file__).with_name(Path(relative).name).resolve()
              for relative in RECEIPT_PATHS["tool_sources"][1:]),
        }
        for repository in repositories:
            protected.update((repository / relative).resolve() for relative in (
                SOURCE, CANDIDATE, compatibility.LOCK, ORACLE,
                Path("tools/material_catalogue/check_native_parity.py"),
                Path("tools/material_catalogue/compatibility.py"),
                Path("tools/material_catalogue/compiler.py"),
                *(Path(relative) for paths in RECEIPT_PATHS.values() for relative in paths),
            ))
            protected.update((repository / CANDIDATE).with_name(name).resolve() for name in (
                "catalogue_shadow.gd", "inspection.json", "manifest.json"))
        for input_path in sorted(protected):
            if destination == input_path or (
                destination.exists() and input_path.exists() and destination.samefile(input_path)
            ):
                raise ParityError(f"--output aliases an input or protected source: {input_path}")
    except RuntimeError as error:
        raise ParityError(f"--output or input path cannot be resolved: {error}") from error

    # Resolve before applying the repository fence, so a link inside build/
    # cannot redirect a report into a source directory. The tooling checkout
    # remains protected when --root selects a different source checkout.
    for repository in repositories:
        if destination.is_relative_to(repository) and not destination.is_relative_to(repository / "build"):
            raise ParityError("--output inside the repository must be beneath build/; refusing a source overwrite")
    if path.suffix != ".json" or destination.suffix != ".json":
        raise ParityError("--output must name a .json report")
    if destination.exists() and not destination.is_file():
        raise ParityError("--output must name a regular report file, not a directory")
    return destination


def _write_report(path: Path, text: str, root: Path, *, source: Path | None = None,
                  candidate: Path | None = None) -> None:
    # Recheck immediately before publication as well as before check(). A
    # directory or file alias created while a probe ran must not evade custody.
    path = _report_output(path, root, source=source, candidate=candidate)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".native-parity-", suffix=".tmp", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="source root to authenticate and inspect")
    parser.add_argument("--source", type=Path, help="authored JSON to compare (default: repository catalogue)")
    parser.add_argument("--candidate", type=Path, help="compiled shadow header to compare (default: generated catalogue.shadow.hpp)")
    parser.add_argument("--cxx", default=os.environ.get("CXX", "c++"), help="C++20 compiler command (no shell execution)")
    parser.add_argument("--output", type=Path, help="optional JSON report; use build/ for repository-local output")
    args = parser.parse_args(argv)
    try:
        output = (_report_output(args.output, args.root, source=args.source, candidate=args.candidate)
                  if args.output else None)
        report = check(args.root, source=args.source, candidate=args.candidate, cxx=args.cxx)
        text = json.dumps(report, sort_keys=True, ensure_ascii=True, indent=2, allow_nan=False) + "\n"
        if output is not None:
            _write_report(output, text, args.root, source=args.source, candidate=args.candidate)
        print(text, end="")
    except (ParityError, compatibility.CompatibilityError, proof_scopes.ProofScopeError, OSError, UnicodeError) as error:
        print(f"native parity: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
