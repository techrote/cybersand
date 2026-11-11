#!/usr/bin/env python3
"""Execute an existing-ID candidate in an external, isolated native World.

The untouched native sources are compiled separately as the source-matched
reference. Neither build is installed in the application. Exported fixtures
contain source and receipts, never candidate saved worlds or executables.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from typing import Any

import compiler
import lab

ROOT = lab.ROOT
SCENARIO_FIELDS = ("first", "second", "seed", "ticks", "workers")
PROBE = "tools/material_catalogue/lab_world_probe.cpp"
THIS_SOURCE = "tools/material_catalogue/world_candidate.py"
SIMULATION_SOURCES = (
    "native/src/world.cpp", "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp", "native/src/settled_world_discovery.cpp",
    "native/src/render_snapshot.cpp",
)
FIXTURE_SOURCES = (
    "godot/scripts/material_lab_experiment.gd",
    "godot/scripts/microscenario_reference_pack.gd",
    "godot/scripts/microscenario_host.gd",
)
BUILD_TIMEOUT = 180
EXECUTE_TIMEOUT = 60

_MATERIAL_ADAPTER = """// EXTERNAL MATERIALS LAB TEST ONLY: generated definitions own this fixture.
inline constexpr std::array<MaterialDefinition, 132> kMaterialDefinitions = [] {
    static_assert(material_catalogue_shadow::kMaterialDefinitions.size() == 132);
    std::array<MaterialDefinition, 132> out{};
    for (std::size_t index = 0; index < out.size(); ++index) {
        const auto& row = material_catalogue_shadow::kMaterialDefinitions[index];
        out[index] = {row.name, static_cast<MaterialState>(row.state), row.density,
            row.rgba, row.movable, row.valid, row.current_rule_available,
            static_cast<RuleKernel>(row.kernel), row.initial_state_a,
            row.initial_state_b, row.maximum_write_radius,
            static_cast<DensityMotion>(row.density_motion), row.accepts_density_exchange,
            static_cast<LateralFlowMode>(row.lateral_flow), row.viscosity_index};
    }
    return out;
}();"""

_PAIR_ADAPTER = """// EXTERNAL MATERIALS LAB TEST ONLY: sparse slots and legacy effects retained.
inline constexpr std::array<PairInteractionRule, 56> kPairInteractionRules = [] {
    static_assert(material_catalogue_shadow::kPairInteractionRules.size() == 56);
    std::array<PairInteractionRule, 56> out{};
    for (std::size_t index = 0; index < out.size(); ++index) {
        const auto& row = material_catalogue_shadow::kPairInteractionRules[index];
        out[index] = {row.id, row.channels,
            static_cast<InteractionTriggerKind>(row.trigger),
            static_cast<InteractionMatchKind>(row.match),
            static_cast<Material>(row.first), static_cast<Material>(row.second),
            static_cast<Material>(row.first_product), static_cast<Material>(row.second_product),
            row.probability, row.accounting, row.revalidation_tags, row.version,
            row.supersedes, row.tuning_pass_id};
    }
    return out;
}();"""


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def admit(candidate: Any, scenario: Any = None) -> tuple[dict, dict, dict]:
    """Reject unsupported consumers before invoking a compiler."""
    normalized, catalogue, _changes = lab.expand_candidate(candidate)
    if normalized["target_id"] == 132:
        lab.fail("/target_id", "World tests retain the 132 allocated native slots. Synthetic 132 is supported by Compile descriptor test only; it is not admitted to a World.")
    native = lab.baseline()["native"]
    material_id = normalized["target_id"]
    for key in ("hard_surface", "granular_support"):
        if normalized["capabilities"][key] != native["capabilities"][material_id][key]:
            lab.fail("/capabilities/" + key, "this World backend retains the native capability consumer. Restore the template capability or use Compile descriptor test; ineffective edits are not installed.")
    if normalized["appearance"]["visual_state_source"] != native["appearance"][material_id]["visual_state_source"]:
        lab.fail("/appearance/visual_state_source", "this World backend retains native visual-state projection. Restore the template projection or use Compile descriptor test. Base RGBA is supported by compiled descriptor readback.")
    if scenario is None:
        scenario = {"first": material_id, "second": 3, "seed": 2, "ticks": 120, "workers": 1}
    lab.fields(scenario, SCENARIO_FIELDS, "/scenario")
    for key in ("first", "second"):
        selected = lab.integer(scenario[key], 0, 131, "/scenario/" + key)
        if selected == 10:
            lab.fail("/scenario/" + key, "reserved invalid ID 10 cannot be placed")
    if material_id not in (scenario["first"], scenario["second"]):
        lab.fail("/scenario", "place the candidate as the upper dose or lower partner so the fixture contains the authored material")
    lab.integer(scenario["seed"], 0, 0x7FFFFFFF, "/scenario/seed")
    lab.integer(scenario["ticks"], 1, 600, "/scenario/ticks")
    lab.integer(scenario["workers"], 1, 4, "/scenario/workers")
    if scenario["workers"] not in (1, 4):
        lab.fail("/scenario/workers", "choose 1 or 4; this backend compares both worker counts")
    return normalized, catalogue, copy.deepcopy(scenario)


def _source_snapshot() -> tuple[dict, dict[str, bytes]]:
    paths = set(lab.SOURCE_FILES) | {PROBE, THIS_SOURCE} | set(FIXTURE_SOURCES)
    for directory in (ROOT / "native/include", ROOT / "native/src"):
        paths.update(str(path.relative_to(ROOT)) for path in directory.rglob("*")
                     if path.is_file() and path.suffix in (".hpp", ".h", ".cpp", ".inc"))
    raw = {name: (ROOT / name).read_bytes() for name in sorted(paths)}
    hashes = {name: _sha256(value.replace(b"\r\n", b"\n")) for name, value in raw.items()}
    head = lab._run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], ROOT, 10, check=False)
    identity = {"git_head": head.stdout.strip() if head.returncode == 0 else "unavailable",
                "lf_sha256": hashes, "digest": lab.digest(hashes),
                "qualification": "Complete native source/header trees, catalogue/lock, compiler, Lab tools, probe and reused fixture sources; hashes bind uncommitted changes. Git HEAD alone is not source custody."}
    return identity, raw


def _replace_table(source: str, declaration: str, replacement: str, pointer: str) -> str:
    if source.count(declaration) != 1:
        lab.fail(pointer, "native table declaration changed; the staged adapter needs source review")
    start = source.index(declaration)
    end = source.find("\n}};", start)
    if end == -1:
        lab.fail(pointer, "native table terminator changed; staged transformation refused")
    return source[:start] + replacement + source[end + len("\n}};"):]


def _stage(directory: Path, source: dict[str, bytes], catalogue: dict, *, candidate: bool) -> dict:
    directory.mkdir()
    for name, value in source.items():
        if name.startswith(("native/include/", "native/src/")) or name == PROBE:
            destination = directory / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(value)
    catalogue_path = directory / "catalogue.json"
    catalogue_path.write_bytes(lab.canonical(catalogue))
    compiler.compile_catalogue(catalogue_path, directory / "generated")
    transformations = []
    if candidate:
        for name, declaration, replacement in (
            ("native/include/cybersand/material.hpp",
             "inline constexpr std::array<MaterialDefinition, 132> kMaterialDefinitions{{", _MATERIAL_ADAPTER),
            ("native/include/cybersand/interaction_rules.hpp",
             "inline constexpr std::array<PairInteractionRule, 56> kPairInteractionRules{{", _PAIR_ADAPTER),
        ):
            path = directory / name
            before = path.read_bytes()
            text = _replace_table(before.decode("utf-8"), declaration, replacement, "/stage/" + name)
            if name.endswith("/material.hpp"):
                if text.count("#pragma once") != 1:
                    lab.fail("/stage/" + name, "header guard changed; staged transformation refused")
                text = text.replace("#pragma once", '#pragma once\n\n#include "catalogue.shadow.hpp"', 1)
            after = text.encode("utf-8")
            path.write_bytes(after)
            transformations.append({"path": name, "before_sha256": _sha256(before),
                                    "after_sha256": _sha256(after), "kind": "external-generated-table-adapter-v1"})
    files = {str(path.relative_to(directory)): _sha256(path.read_bytes())
             for path in sorted(directory.rglob("*")) if path.is_file()}
    return {"files_sha256": files, "digest": lab.digest(files), "transformations": transformations,
            "boundary": "External test fixture only; repository native source is never written."}


def _check_cancelled() -> None:
    lab._check_cancelled()


def _verify_stage(directory: Path, manifest: dict) -> None:
    for name, expected in manifest["files_sha256"].items():
        path = directory / name
        if not path.is_file() or _sha256(path.read_bytes()) != expected:
            lab.fail("/stage/" + name, "staged compiler input changed or disappeared; no native qualification is recorded")


def _build_and_execute(directory: Path, cxx: str, msvc: bool, scenario: dict,
                       material_id: int, sanitize: bool) -> tuple[dict, dict]:
    _check_cancelled()
    executable = directory / ("lab-world-probe.exe" if os.name == "nt" else "lab-world-probe")
    # Use staged-root-relative compiler inputs. Windows MinGW and Python may
    # disagree on DOS-short-name aliases for absolute temporary paths.
    inputs = [PROBE, *SIMULATION_SOURCES]
    if msvc:
        command = [cxx, "/nologo", "/std:c++20", "/EHsc", "/W4", "/Od",
                   "/I" + "native/include", "/I" + "generated",
                   *inputs, "/Fe:" + executable.name]
    else:
        command = [cxx, "-std=c++20", "-O0", "-Wall", "-Wextra", "-Werror", "-pthread",
                   "-I", "native/include", "-I", "generated",
                   *inputs, "-o", executable.name]
        if sanitize:
            command += ["-g1", "-fno-omit-frame-pointer", "-fsanitize=address,undefined", "-fno-sanitize-recover=all"]
    lab._run(command, directory, BUILD_TIMEOUT)
    process = lab._run([str(executable), str(material_id), *(str(scenario[key]) for key in SCENARIO_FIELDS)],
                       directory, EXECUTE_TIMEOUT)
    try:
        observed = json.loads(process.stdout)
    except ValueError as error:
        raise lab.LabError(f"/compile_world_test: malformed native World probe output: {error}") from error
    if observed.get("ok") is not True or observed.get("runtime_active") is not False:
        lab.fail("/compile_world_test", "native World qualification failed: " + json.dumps(observed.get("checks", observed), sort_keys=True))
    build = {"argv": [part.replace(str(directory), "$STAGED_FIXTURE") for part in command],
             "native_executable_sha256": _sha256(executable.read_bytes()),
             "compile_timeout_seconds": BUILD_TIMEOUT, "execute_timeout_seconds": EXECUTE_TIMEOUT}
    return observed, build


def _compare(reference: dict, candidate: dict) -> dict:
    before, after = reference["final"], candidate["final"]
    fields = ("content_hash", "state_hash", "physical_state_hash", "water_quantity", "material_cells", "quantity_ledger")
    differences = {field: {"reference": before[field], "candidate": after[field]}
                   for field in fields if before[field] != after[field]}
    return {"equal": not differences, "differences": differences,
            "reference_target_below_reservoir": before["target_below_reservoir"],
            "candidate_target_below_reservoir": after["target_below_reservoir"],
            "scope": "Actual stored native state at the requested completed tick. Unchanged output does not establish ineffectiveness for every configuration."}


def _receipt(result: dict, catalogue: dict, scenario: dict, identity_before: dict,
             identity_after: dict, reference_stage: dict, candidate_stage: dict,
             reference_build: dict, candidate_build: dict, reference: dict, observed: dict,
             comparison: dict, no_op: bool, cxx: str, msvc: bool, sanitize: bool, staging: Path) -> dict:
    version = lab._run([cxx] if msvc else [cxx, "--version"], staging, 10, check=False)
    versions = (version.stdout + "\n" + version.stderr).strip().splitlines()
    return {"schema_id": "cybersand.material-lab.world-receipt", "schema_version": 1,
            "candidate_digest": result["digest"], "compiled_catalogue_sha256": lab.digest(catalogue),
            "source_identity": identity_before, "source_identity_after": identity_after["digest"],
            "scenario": scenario, "scenario_digest": lab.digest(scenario),
            "fixture": "Materials Lab enclosed pair bay geometry v1; native demo::construct; shelf erased after 12 completed ticks before tick 13",
            "fixture_scope": "Reuses Lab/MicroScenario geometry with the native demo constructor. Raw World default policy and recorded finite capacities apply; this is not an exact replay of the mounted host or its transport-profile identity.",
            "seed_semantics": "Existing Lab fixture: upper dose shifts by seed % 5; native randomness retains its coordinate/tick streams.",
            "compiler": Path(cxx).name, "compiler_version": versions[0] if versions else "unavailable",
            "platform": sys.platform, "sanitizers": "address,undefined" if sanitize else "none",
            "sanitizer_runtime_options": {key: os.environ.get(key, "") for key in ("ASAN_OPTIONS", "UBSAN_OPTIONS")} if sanitize else {},
            "reference_stage": reference_stage, "candidate_stage": candidate_stage,
            "reference_build": reference_build, "candidate_build": candidate_build,
            "reference": reference, "candidate": observed, "comparison": comparison,
            "checks": {"source_unchanged": True, "reference_qualification": True,
                       "candidate_qualification": True, "unchanged_candidate": no_op,
                       "unchanged_candidate_parity": comparison["equal"] if no_op else None},
            "runtime_active": False,
            "limitations": ["No production installation, shader hot reload or new identity allocation.",
                "Capability and visual-state projection edits are refused by this World backend.",
                "Default native solver policy only; actors, ballistic coupling and other Workbench owners are absent.",
                "Chunk activity is observed; individual-cell sleep/deadline/eligibility is not exposed.",
                "Persistence is replayed inside each isolated build; no cross-build saved-world compatibility is claimed."]}


def _publish(staging: Path, destination: Path, receipt: dict, normalized: dict, candidate_digest: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    publication = Path(tempfile.mkdtemp(prefix=".lab-world-publish-", dir=destination.parent))
    try:
        for label in ("reference", "candidate"):
            _verify_stage(staging / label, receipt[label + "_stage"])
            shutil.copytree(staging / label, publication / label,
                            ignore=shutil.ignore_patterns("lab-world-probe", "*.exe", "*.obj", "*.pdb", "*.ilk"))
        (publication / "world-receipt.json").write_bytes(lab.canonical(receipt))
        (publication / "preset.json").write_bytes(lab.canonical({"schema_id": lab.EXPORT_SCHEMA,
            "schema_version": 1, "digest": candidate_digest, "candidate": normalized}))
        _check_cancelled()
        # Source custody is checked again immediately before publication.
        identity, _ = _source_snapshot()
        if identity["digest"] != receipt["source_identity"]["digest"]:
            lab.fail("/compile_world_test", "source changed before publication; no tested fixture exported")
        os.rename(publication, destination)
    finally:
        if publication.exists():
            shutil.rmtree(publication)


def compile_world_test(candidate: Any, *, scenario: Any = None, output_dir: Path | None = None,
                       sanitize: bool = False, cxx: str | None = None) -> dict:
    _check_cancelled()
    # Custody begins BEFORE schema/compatibility preflight, not after it.
    identity_before, inputs = _source_snapshot()
    normalized, catalogue, scenario = admit(candidate, scenario)
    result = lab.validate_candidate(normalized)
    cxx, msvc = lab._toolchain(cxx)
    if type(sanitize) is not bool:
        lab.fail("/sanitize", "expected true or false")
    if sanitize and msvc:
        lab.fail("/sanitize", "ASan/UBSan World tests require GCC or Clang; MSVC is supported without this flag")
    destination = Path(output_dir).resolve() if output_dir is not None else None
    if destination is not None:
        if destination.is_relative_to(ROOT.resolve()):
            lab.fail("/output_dir", "isolated World fixtures must be exported outside the repository")
        if destination.exists():
            lab.fail("/output_dir", "output already exists; choose a fresh directory")
    with tempfile.TemporaryDirectory(prefix="cybersand-lab-world-") as temporary:
        staging = Path(temporary)
        baseline = lab.baseline()
        reference_stage = _stage(staging / "reference", inputs, baseline, candidate=False)
        candidate_stage = _stage(staging / "candidate", inputs, catalogue, candidate=True)
        # Fail before compilation if staged sources are missing or changed.
        _verify_stage(staging / "reference", reference_stage)
        _verify_stage(staging / "candidate", candidate_stage)
        reference, reference_build = _build_and_execute(staging / "reference", cxx, msvc, scenario,
                                                       normalized["target_id"], sanitize)
        _verify_stage(staging / "reference", reference_stage)
        observed, candidate_build = _build_and_execute(staging / "candidate", cxx, msvc, scenario,
                                                      normalized["target_id"], sanitize)
        _verify_stage(staging / "candidate", candidate_stage)
        identity_after, _ = _source_snapshot()
        if identity_after["digest"] != identity_before["digest"]:
            lab.fail("/compile_world_test", "source inputs changed during validation, staging, compilation or execution; rerun against stable source")
        comparison = _compare(reference, observed)
        no_op = catalogue == baseline
        if no_op and not comparison["equal"]:
            lab.fail("/compile_world_test", "unchanged generated tables failed exact parity with untouched native source: " + json.dumps(comparison["differences"], sort_keys=True))
        receipt = _receipt(result, catalogue, scenario, identity_before, identity_after, reference_stage,
                           candidate_stage, reference_build, candidate_build, reference, observed,
                           comparison, no_op, cxx, msvc, sanitize, staging)
        _check_cancelled()
        lab.compatibility.check()
        final_identity, _ = _source_snapshot()
        if final_identity["digest"] != identity_before["digest"]:
            lab.fail("/compile_world_test", "source inputs changed before the final receipt; no tested status recorded")
        if destination is not None:
            _publish(staging, destination, receipt, normalized, result["digest"])
            result["output_dir"] = str(destination)
    result.update(state="compiled_tested", receipt=receipt,
                  boundary="Generated definitions were compiled into an external native World and compared with untouched source. Stored cells, quantity, deterministic 1/4-worker repeat and same-build persistence were exercised. The running application and production source remain unchanged; runtime-active is false.")
    return result
