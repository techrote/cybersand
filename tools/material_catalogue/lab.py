#!/usr/bin/env python3
"""Materials Lab candidate authoring and bounded native compilation service.

This is a tooling consumer of the accepted catalogue compiler. It never writes
production material definitions, changes a World, allocates a production ID, or
claims that a compiled descriptor fixture is an installed simulation material.
The JSON file protocol is also used by the desktop Materials Lab.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any

import compatibility
import compiler


ROOT = Path(__file__).resolve().parents[2]
PRESET_SCHEMA = "cybersand.material-lab.preset"
EXPORT_SCHEMA = "cybersand.material-lab.export"
SCHEMA_VERSION = 1
MAX_JSON_BYTES = 1024 * 1024
MAX_REACTIONS = 56
PRESET_FIELDS = (
    "schema_id", "schema_version", "source_catalogue_sha256", "template_id",
    "target_id", "name", "descriptor", "capabilities", "appearance", "reactions",
)
REACTION_FIELDS = (
    "slot", "rule_id", "first", "second", "first_product", "second_product",
    "probability", "match", "effects",
)
SOURCE_FILES = (
    "materials/catalogue/catalogue.json",
    "materials/catalogue/compatibility-lock.json",
    "native/include/cybersand/material.hpp",
    "native/include/cybersand/material_rules.hpp",
    "native/include/cybersand/interaction_rules.hpp",
    "native/src/material_rules.cpp",
    "tools/material_catalogue/compiler.py",
    "tools/material_catalogue/compatibility.py",
    "tools/material_catalogue/lab.py",
    "tools/material_catalogue/lab_native_probe.cpp",
)


class LabError(ValueError):
    """Actionable authoring refusal; production source is never changed."""


def fail(pointer: str, message: str) -> None:
    raise LabError(f"{pointer or '/'}: {message}")


def fields(value: Any, expected: tuple[str, ...], pointer: str) -> dict:
    if type(value) is not dict:
        fail(pointer, "expected an object")
    missing, extra = sorted(set(expected) - value.keys()), sorted(value.keys() - set(expected))
    if missing or extra:
        fail(pointer, f"field mismatch; missing={missing}, unsupported={extra}")
    return value


def integer(value: Any, low: int, high: int, pointer: str) -> int:
    if type(value) is not int or not low <= value <= high:
        fail(pointer, f"expected an integer in {low}..{high}; booleans and numeric coercion are not accepted")
    return value


def boolean(value: Any, pointer: str) -> bool:
    if type(value) is not bool:
        fail(pointer, "expected true or false")
    return value


def canonical(value: Any) -> bytes:
    try:
        return compiler.canonical_json(value)
    except (ValueError, TypeError, UnicodeError, RecursionError) as error:
        raise LabError(f"/: invalid JSON value: {error}") from error


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def read_json(path: Path) -> Any:
    path = Path(path)
    if path.stat().st_size > MAX_JSON_BYTES:
        fail(str(path), f"JSON exceeds the {MAX_JSON_BYTES}-byte authoring limit")
    # Reuse the compiler's strict parser, including nested duplicate-key,
    # non-finite number, UTF-8 and JSON-pointer diagnostics.
    return compiler._read_json(path, compiler._Validator(path))


def baseline() -> dict:
    return compiler.load_catalogue(ROOT / "materials/catalogue/catalogue.json")


def _valid_template(material_id: Any, native: dict) -> int:
    material_id = integer(material_id, 1, 131, "/template_id")
    if not native["materials"][material_id]["valid"]:
        fail("/template_id", "ID 10 is the reserved invalid identity and cannot be authored")
    return material_id


def supported_fields(template_id: int) -> dict:
    source = baseline()["native"]["materials"][template_id]
    viscosity = source["kernel"] in (18, 23, 25)
    descriptor = {
        "density": {"editable": True, "min": 0, "max": 65535,
                    "boundary": "candidate compilation; production source rebuild and review required",
                    "applicability": "Native density-exchange descriptor, where the selected kernel uses density exchange."},
        "rgba": {"editable": True, "min": 0, "max": 255, "length": 4,
                 "boundary": "candidate base RGBA; production Godot appearance programmes remain separate",
                 "applicability": "Compiled base-colour bytes, not a live shader override."},
        "viscosity_index": {"editable": viscosity, "min": 0, "max": 255,
                            "boundary": "candidate compilation; selected native family may override it",
                            "applicability": (
                                "Generic yielding lateral-movement probability; gravity is unaffected. Mercury diagnostic override and selected inertial families take precedence."
                                if viscosity else
                                "Not an effective editable descriptor for this kernel. Water-CY uses its applied material policy; Lava, Acid and Oil use specialised movement.")},
    }
    return {
        "descriptor": descriptor,
        "capabilities": {"hard_surface": {"editable": True}, "granular_support": {"editable": True}},
        "appearance": {"visual_state_source": {"editable": True, "values": ["Zero", "StateA", "StateB"]}},
        "mechanism": {"editable": False, "kernel": source["kernel"],
                      "detail": "Select an existing material template to select its supported mechanism. Kernel, phase, movement, write-radius and state-default changes need a separately qualified contract."},
        "reactions": {"editable": True, "maximum": MAX_REACTIONS,
                      "effects": ["replace_with_defaults"],
                      "detail": "Edit existing sparse slots involving this template; rule IDs and legacy order are retained. Synthetic 132 cannot participate in schema-1 reactions."},
    }


def _candidate_rule(rule: dict) -> dict:
    return {
        "slot": rule["legacy_slot"], "rule_id": rule["id"],
        **{key: rule[key] for key in ("first", "second", "first_product", "second_product", "probability", "match")},
        "effects": {"version": 1, "first": {"kind": "replace_with_defaults"},
                    "second": {"kind": "replace_with_defaults"}},
    }


def create_candidate(template_id: int, *, synthetic: bool = False) -> dict:
    source = baseline()
    native = source["native"]
    template_id = _valid_template(template_id, native)
    boolean(synthetic, "/synthetic")
    if synthetic and template_id != 2:
        fail("/template_id", "the isolated synthetic-132 fixture uses Sand (ID 2); other new-ID mechanisms are not admitted")
    target_id = 132 if synthetic else template_id
    descriptor = copy.deepcopy(native["materials"][template_id])
    descriptor["id"] = target_id
    if synthetic:
        descriptor["name"] = "synthetic-powder"
    caps = native["capabilities"][template_id]
    return {
        "schema_id": PRESET_SCHEMA, "schema_version": SCHEMA_VERSION,
        "source_catalogue_sha256": digest(source), "template_id": template_id,
        "target_id": target_id,
        "name": "Synthetic powder candidate" if synthetic else descriptor["name"].replace("-", " ").capitalize() + " candidate",
        "descriptor": descriptor,
        "capabilities": {"hard_surface": False if synthetic else caps["hard_surface"],
                         "granular_support": caps["granular_support"]},
        "appearance": {"visual_state_source": native["appearance"][template_id]["visual_state_source"]},
        "reactions": [] if synthetic else [_candidate_rule(rule) for rule in native["interactions"]["pairs"]
                                            if template_id in (rule["first"], rule["second"])],
    }


def _effect(value: Any, pointer: str) -> None:
    fields(value, ("kind",), pointer)
    if value["kind"] != "replace_with_defaults":
        fail(pointer + "/kind", "only replace_with_defaults is supported in v1; keep_existing/set_state require a reviewed native state, temperature and quantity-ledger contract and are not approximated")


def expand_candidate(candidate: Any) -> tuple[dict, dict, list[dict]]:
    """Validate a compact draft and build one full canonical compiler input."""
    fields(candidate, PRESET_FIELDS, "")
    if candidate["schema_id"] != PRESET_SCHEMA or type(candidate["schema_version"]) is not int or candidate["schema_version"] != SCHEMA_VERSION:
        fail("/schema_version", f"expected {PRESET_SCHEMA} schema version {SCHEMA_VERSION}")
    source = baseline()
    if candidate["source_catalogue_sha256"] != digest(source):
        fail("/source_catalogue_sha256", "preset was authored against a different catalogue; duplicate a current template and explicitly reconcile the changes")
    native = source["native"]
    template_id = _valid_template(candidate["template_id"], native)
    target_id = integer(candidate["target_id"], 1, 132, "/target_id")
    synthetic = target_id == 132
    if (not synthetic and target_id != template_id) or (synthetic and template_id != 2):
        fail("/target_id", "retain the template identity, or use the isolated Sand-derived non-hard powder at 132; this does not allocate a production ID")
    name = candidate["name"]
    if type(name) is not str or not name.strip() or len(name) > 96 or any(ord(char) < 32 for char in name):
        fail("/name", "expected a non-empty display label of at most 96 characters without control characters")
    descriptor = fields(candidate["descriptor"], compiler.MATERIAL_FIELDS, "/descriptor")
    template = native["materials"][template_id]
    expected = copy.deepcopy(template)
    expected["id"] = target_id
    if synthetic:
        expected["name"] = "synthetic-powder"
    allowed = {"density", "rgba"}
    if template["kernel"] in (18, 23, 25):
        allowed.add("viscosity_index")
    changes = []
    for key in compiler.MATERIAL_FIELDS:
        if type(descriptor[key]) is not type(expected[key]) or descriptor[key] != expected[key]:
            if key not in allowed:
                fail("/descriptor/" + key,
                     "unsupported change for this template; identity, state defaults, kernel and scheduling geometry are not mutable through the Lab. " +
                     ("This viscosity descriptor is not consumed by the selected movement path." if key == "viscosity_index" else "Choose a supported template or obtain a separately qualified source transition."))
            changes.append({"path": "/descriptor/" + key, "before": expected[key], "after": descriptor[key], "boundary": "candidate-only"})
    caps = fields(candidate["capabilities"], ("hard_surface", "granular_support"), "/capabilities")
    for key in caps:
        boolean(caps[key], "/capabilities/" + key)
        old = native["capabilities"][template_id][key]
        if caps[key] != old:
            changes.append({"path": "/capabilities/" + key, "before": old, "after": caps[key], "boundary": "candidate-only explicit capability"})
    if synthetic and caps["hard_surface"]:
        fail("/capabilities/hard_surface", "isolated synthetic powder 132 must be explicitly non-hard; ID ranges do not grant capabilities")
    appearance = fields(candidate["appearance"], ("visual_state_source",), "/appearance")
    integer(appearance["visual_state_source"], 0, 2, "/appearance/visual_state_source")
    before_appearance = native["appearance"][template_id]["visual_state_source"]
    if appearance["visual_state_source"] != before_appearance:
        changes.append({"path": "/appearance/visual_state_source", "before": before_appearance,
                        "after": appearance["visual_state_source"], "boundary": "candidate-only projection"})
    reactions = candidate["reactions"]
    if type(reactions) is not list or len(reactions) > MAX_REACTIONS:
        fail("/reactions", f"expected at most {MAX_REACTIONS} structured sparse rule edits")
    if synthetic and reactions:
        fail("/reactions", "synthetic 132 is a descriptor/capability fixture only; the accepted compiler does not admit its reaction identity")
    occupied_slots: dict[int, str] = {}
    occupied_ids: dict[str, str] = {}
    for index, edited in enumerate(reactions):
        at = f"/reactions/{index}"
        fields(edited, REACTION_FIELDS, at)
        slot = integer(edited["slot"], 0, 55, at + "/slot")
        original = native["interactions"]["pairs"][slot]
        if edited["rule_id"] != original["id"]:
            fail(at + "/rule_id", f"slot {slot} retains immutable rule identity {original['id']!r}")
        if slot in occupied_slots or edited["rule_id"] in occupied_ids:
            fail(at, f"duplicate reaction slot/key; first origin {occupied_slots.get(slot, occupied_ids.get(edited['rule_id']))}")
        occupied_slots[slot], occupied_ids[edited["rule_id"]] = at, at
        if template_id not in (original["first"], original["second"]):
            fail(at + "/slot", "this rule is not owned by the selected template; select one of its original participants")
        for key in ("first", "second", "first_product", "second_product"):
            value = integer(edited[key], 0, 131, at + "/" + key)
            if not native["materials"][value]["valid"]:
                fail(at + "/" + key, "reserved invalid ID 10 cannot be a partner or product")
        if target_id not in (edited["first"], edited["second"]):
            fail(at, "an authored interaction must retain this candidate as a participant")
        integer(edited["probability"], 0, 255, at + "/probability")
        integer(edited["match"], 0, 2, at + "/match")
        first_active = native["materials"][edited["first"]]["kernel"] != 0
        second_active = native["materials"][edited["second"]]["kernel"] != 0
        if edited["match"] == 0 and not first_active:
            fail(at + "/first", "an Ordered reaction requires an active source kernel; RuleKernel::None never initiates World contact chemistry. Keep inert materials as targets, or use a qualified unordered pair with an active partner.")
        if edited["match"] != 0 and not (first_active or second_active):
            fail(at, "neither partner has an active kernel to initiate World contact chemistry; inert targets are supported, but a pair needs an active participant")
        effects = fields(edited["effects"], ("version", "first", "second"), at + "/effects")
        if type(effects["version"]) is not int or effects["version"] != 1:
            fail(at + "/effects/version", "only explicit endpoint-effects version 1 is supported")
        _effect(effects["first"], at + "/effects/first")
        _effect(effects["second"], at + "/effects/second")
        for key in ("first", "second", "first_product", "second_product", "probability", "match"):
            if edited[key] != original[key]:
                changes.append({"path": at + "/" + key, "before": original[key], "after": edited[key], "boundary": "isolated native resolver fixture"})
                original[key] = edited[key]
    if synthetic:
        source["scope"] = "isolated-synthetic"
        native["identity"]["allocated_slots"] = 133
        native["materials"].append(copy.deepcopy(descriptor))
        native["capabilities"][132] = copy.deepcopy(native["capabilities"][template_id])
        native["capabilities"][132]["id"] = 132
    else:
        native["materials"][target_id] = copy.deepcopy(descriptor)
    native["capabilities"][target_id].update(caps)
    native["appearance"][target_id]["visual_state_source"] = appearance["visual_state_source"]
    participants = {rule[field] for rule in native["interactions"]["pairs"] for field in ("first", "second")}
    for cap in native["capabilities"]:
        cap["pair_participant"] = cap["id"] in participants
    # The accepted compiler remains the single canonical schema/generation path.
    # It supplies descriptor bounds, every reference and cross-rule conflict check.
    with tempfile.TemporaryDirectory(prefix="cybersand-lab-validate-") as directory:
        path = Path(directory) / "candidate-catalogue.json"
        path.write_bytes(canonical(source))
        normalized_source = compiler.load_catalogue(path, isolated=synthetic)
    normalized = copy.deepcopy(candidate)
    normalized["name"] = name.strip()
    normalized["reactions"].sort(key=lambda item: item["slot"])
    return normalized, normalized_source, changes


def validate_candidate(candidate: Any) -> dict:
    normalized, catalogue, changes = expand_candidate(candidate)
    protected = compatibility.check()
    return {
        "ok": True, "state": "validated_candidate", "candidate": normalized,
        "digest": digest(normalized), "compiled_catalogue_sha256": digest(catalogue),
        "changes": changes, "supported_fields": supported_fields(normalized["template_id"]),
        "compatibility": {key: protected[key] for key in ("status", "baseline", "protected_sources", "catalogue_digest", "capability_digest", "production_cutover")},
        "runtime_active": False,
        "boundary": "Schema and unchanged production-source compatibility passed. This candidate is not installed in a World.",
    }


def _atomic_json(path: Path, value: Any) -> None:
    path = Path(path)
    data = canonical(value)
    if path.resolve().is_relative_to(ROOT.resolve()):
        fail(str(path), "Lab writes must be outside the source repository; choose your Materials Lab user folder or an external export path")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix="." + path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(data)
            output.flush()
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def export_candidate(candidate: Any, path: Path) -> dict:
    result = validate_candidate(candidate)
    envelope = {"schema_id": EXPORT_SCHEMA, "schema_version": SCHEMA_VERSION,
                "digest": result["digest"], "candidate": result["candidate"]}
    _atomic_json(Path(path), envelope)
    result["path"] = str(Path(path).resolve())
    return result


def import_candidate(path: Path) -> dict:
    envelope = read_json(Path(path))
    fields(envelope, ("schema_id", "schema_version", "digest", "candidate"), "/export")
    if envelope["schema_id"] != EXPORT_SCHEMA or type(envelope["schema_version"]) is not int or envelope["schema_version"] != SCHEMA_VERSION:
        fail("/export/schema_version", "unsupported material preset export schema/version")
    if type(envelope["digest"]) is not str or envelope["digest"] != digest(envelope["candidate"]):
        fail("/export/digest", "preset content does not match its deterministic digest; import rejected without changing the current draft")
    return validate_candidate(envelope["candidate"])


def _toolchain(cxx: str | None = None) -> tuple[str, bool]:
    # A request may select one executable, never shell syntax or arguments.
    # The path remains one argv element, including Windows paths with spaces.
    if cxx is not None and (type(cxx) is not str or not cxx.strip() or any(ord(char) < 32 for char in cxx)):
        fail("/cxx", "expected one non-empty compiler executable name or path, without control characters or command-line arguments")
    requested = cxx if cxx is not None else os.environ.get("CYBERSAND_LAB_CXX", "")
    names = [requested] if requested else (["cl.exe", "clang++", "g++", "c++"] if os.name == "nt" else ["c++", "g++", "clang++"])
    for name in names:
        if not name:
            continue
        executable = shutil.which(name)
        if executable:
            return executable, Path(executable).name.lower() in ("cl", "cl.exe")
    if cxx is not None:
        fail("/cxx", f"compiler executable was not found or is not executable: {cxx!r}. Supply a single g++/clang++/cl.exe name or filesystem path without flags. An explicit selection does not fall back to another compiler.")
    fail("/compiler", "No C++20 compiler was found. Install g++/clang++, or launch Godot from a Visual Studio x64 Developer Command Prompt with cl.exe available. CYBERSAND_LAB_CXX may select a compiler executable.")


def _run(command: list[str], directory: Path, timeout: int) -> subprocess.CompletedProcess:
    try:
        result = subprocess.run(command, cwd=directory, text=True, encoding="utf-8", errors="replace",
                                capture_output=True, timeout=timeout, shell=False)
    except subprocess.TimeoutExpired as error:
        raise LabError(f"/compile_test: bounded process exceeded {timeout} seconds; no tested status was recorded") from error
    if result.returncode:
        detail = (result.stderr + "\n" + result.stdout).strip()[-8000:]
        fail("/compile_test", f"process returned {result.returncode}: {detail}")
    return result


def _source_identity() -> dict:
    files = {name: hashlib.sha256((ROOT / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest() for name in SOURCE_FILES}
    result = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], capture_output=True, text=True, timeout=10)
    return {"git_head": result.stdout.strip() if result.returncode == 0 else "unavailable",
            "lf_sha256": files, "digest": digest(files),
            "qualification": "The file digest binds this executed source, including uncommitted implementation changes; git_head alone does not."}


def compile_test(candidate: Any, *, output_dir: Path | None = None, diagnostic: dict | None = None,
                 sanitize: bool = False, cxx: str | None = None) -> dict:
    result = validate_candidate(candidate)
    normalized, catalogue, _changes = expand_candidate(result["candidate"])
    cxx, msvc = _toolchain(cxx)
    if diagnostic is None:
        rules = normalized["reactions"]
        diagnostic = {"source": rules[0]["first"], "target": rules[0]["second"], "roll": 0} if rules else {"source": 2, "target": 3, "roll": 0}
    fields(diagnostic, ("source", "target", "roll"), "/diagnostic")
    for key in ("source", "target"):
        value = integer(diagnostic[key], 0, 131, "/diagnostic/" + key)
        if value == 10:
            fail("/diagnostic/" + key, "reserved invalid identity 10 cannot be queried")
    integer(diagnostic["roll"], 0, 255, "/diagnostic/roll")
    if sanitize and msvc:
        fail("/sanitize", "the bounded ASan/UBSan probe uses g++ or clang++; MSVC compilation remains supported without this flag")
    identity_before = _source_identity()
    destination = Path(output_dir).resolve() if output_dir is not None else None
    if destination is not None:
        if destination.is_relative_to(ROOT.resolve()):
            fail("/output_dir", "isolated compiled tests and generated files must be outside the repository")
        if destination.exists():
            fail("/output_dir", "output already exists; choose a fresh directory so previous receipts and files remain intact")
    # Build everything in scratch first. A failing compiler or executable cannot
    # partially replace an existing preset, previous receipt, or source directory.
    with tempfile.TemporaryDirectory(prefix="cybersand-lab-native-") as temporary:
        staging = Path(temporary)
        source = staging / "candidate-catalogue.json"
        source.write_bytes(canonical(catalogue))
        generated = staging / "generated"
        compiler.compile_catalogue(source, generated, isolated=normalized["target_id"] == 132)
        executable = staging / ("lab-native-probe.exe" if os.name == "nt" else "lab-native-probe")
        probe = ROOT / "tools/material_catalogue/lab_native_probe.cpp"
        if msvc:
            command = [cxx, "/nologo", "/std:c++20", "/EHsc", "/W4", "/WX", "/O2",
                       "/I" + str(ROOT / "native/include"), "/I" + str(generated),
                       str(probe), str(ROOT / "native/src/material_rules.cpp"), "/Fe:" + str(executable)]
        else:
            command = [cxx, "-std=c++20", "-O1" if sanitize else "-O2", "-Wall", "-Wextra", "-Werror",
                       "-I", str(ROOT / "native/include"), "-I", str(generated),
                       str(probe), str(ROOT / "native/src/material_rules.cpp"), "-o", str(executable)]
            if sanitize:
                command += ["-g", "-fno-omit-frame-pointer", "-fsanitize=address,undefined", "-fno-sanitize-recover=all"]
        _run(command, staging, 60)
        executed = _run([str(executable), str(normalized["target_id"]),
                         str(diagnostic["source"]), str(diagnostic["target"]), str(diagnostic["roll"])], staging, 20)
        try:
            observed = json.loads(executed.stdout)
        except (json.JSONDecodeError, ValueError) as error:
            raise LabError(f"/compile_test: native probe did not return valid JSON: {error}") from error
        if not observed.get("ok") or observed.get("runtime_active") is not False:
            fail("/compile_test", "native probe did not acknowledge candidate-only successful execution")
        identity_after = _source_identity()
        if identity_before["digest"] != identity_after["digest"]:
            fail("/compile_test", "source inputs changed during compilation/execution; rerun against a stable source before recording tested status")
        version = subprocess.run([cxx] if msvc else [cxx, "--version"], cwd=staging,
                                 text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=10)
        version_text = (version.stdout + "\n" + version.stderr).strip().splitlines()
        outputs = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(generated.iterdir())}
        receipt = {"schema_id": "cybersand.material-lab.native-receipt", "schema_version": 1,
                   "candidate_digest": result["digest"], "compiled_catalogue_sha256": digest(catalogue),
                   "source_identity": identity_before, "compiler": Path(cxx).name,
                   "compiler_version": version_text[0] if version_text else "unavailable",
                   "platform": sys.platform, "sanitizers": "address,undefined" if sanitize else "none",
                   "sanitizer_runtime_options": {key: os.environ.get(key, "") for key in ("ASAN_OPTIONS", "UBSAN_OPTIONS")} if sanitize else {},
                   "native_executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
                   "generated_sha256": outputs, "observed": observed}
        (staging / "native-receipt.json").write_bytes(canonical(receipt))
        # Reusable generated source is published only after the executed probe
        # succeeds. Temporary executables/objects are deliberately not exported.
        if destination is not None:
            destination.parent.mkdir(parents=True, exist_ok=True)
            publication = Path(tempfile.mkdtemp(prefix=".lab-publish-", dir=destination.parent))
            try:
                shutil.copytree(generated, publication / "generated")
                shutil.copyfile(source, publication / "candidate-catalogue.json")
                shutil.copyfile(staging / "native-receipt.json", publication / "native-receipt.json")
                (publication / "preset.json").write_bytes(canonical({"schema_id": EXPORT_SCHEMA, "schema_version": 1,
                    "digest": result["digest"], "candidate": normalized}))
                # rename is atomic on the same parent filesystem and never
                # overwrites a non-empty prior build directory.
                os.rename(publication, destination)
            finally:
                if publication.exists():
                    shutil.rmtree(publication)
            result["output_dir"] = str(destination)
    result.update(state="compiled_tested", receipt=receipt,
                  boundary="Generated descriptors and sparse rules were compiled and exercised by native C++ functions. World movement, sleeping, state mutation and quantity accounting were not executed for this candidate. It is not runtime-active.")
    return result


def request(value: Any) -> dict:
    if type(value) is not dict or type(value.get("op")) is not str:
        fail("/op", "expected a Materials Lab operation")
    op = value["op"]
    allowed = {
        "create": ({"op", "template_id"}, {"synthetic"}),
        "validate": ({"op", "candidate"}, set()),
        "compile_test": ({"op", "candidate"}, {"output_dir", "diagnostic", "sanitize", "cxx"}),
        "import": ({"op", "path"}, set()),
        "export": ({"op", "candidate", "path"}, set()),
    }
    if op not in allowed:
        fail("/op", "expected create, validate, compile_test, import or export")
    required, optional = allowed[op]
    if not required <= value.keys() or value.keys() - required - optional:
        fail("/", f"invalid request fields for {op}; required={sorted(required)}, optional={sorted(optional)}")
    if op == "create":
        candidate = create_candidate(value["template_id"], synthetic=value.get("synthetic", False))
        return {"ok": True, "state": "draft", "candidate": candidate, "runtime_active": False,
                "supported_fields": supported_fields(candidate["template_id"])}
    if op == "validate":
        return validate_candidate(value["candidate"])
    if op in ("import", "export"):
        if type(value["path"]) is not str or not value["path"]:
            fail("/path", "expected an explicit file path")
        return import_candidate(Path(value["path"])) if op == "import" else export_candidate(value["candidate"], Path(value["path"]))
    if "output_dir" in value and (type(value["output_dir"]) is not str or not value["output_dir"]):
        fail("/output_dir", "expected an external output directory path")
    if "cxx" in value and (type(value["cxx"]) is not str or not value["cxx"].strip()):
        fail("/cxx", "expected one non-empty compiler executable name or path; omit cxx to use the environment/default selection")
    boolean(value.get("sanitize", False), "/sanitize")
    return compile_test(value["candidate"], output_dir=Path(value["output_dir"]) if "output_dir" in value else None,
                        diagnostic=value.get("diagnostic"), sanitize=value.get("sanitize", False), cxx=value.get("cxx"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--response", type=Path)
    args = parser.parse_args(argv)
    try:
        result = request(read_json(args.request))
    except (LabError, compiler.CatalogueError, compatibility.CompatibilityError, OSError, UnicodeError,
            ValueError, TypeError, KeyError, RecursionError, subprocess.SubprocessError) as error:
        result = {"ok": False, "state": "draft", "runtime_active": False, "errors": [str(error)]}
    if args.response is not None:
        try:
            if args.response.resolve() == args.request.resolve():
                fail("/response", "response path must not overwrite the request")
            _atomic_json(args.response, result)
        except (LabError, OSError) as error:
            print(canonical({"ok": False, "state": "draft", "errors": [str(error)]}).decode(), end="")
            return 2
    else:
        print(canonical(result).decode(), end="")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
