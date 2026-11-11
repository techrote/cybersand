#!/usr/bin/env python3
"""Materials Lab candidate authoring and bounded native compilation service.

This is a tooling consumer of the accepted catalogue compiler. It never writes
production material definitions, changes a running World, allocates a production ID, or
claims that a compiled descriptor fixture is an installed simulation material.
The JSON file protocol is also used by the desktop Materials Lab.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from contextvars import ContextVar
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from typing import Any

import compatibility
import compiler
import reaction_effects

# The CLI and lazily loaded backends must share one cancellation context.
# Without this alias, `world_candidate` importing lab would create a second
# module when this file is running as __main__.
if __name__ == "__main__":
    sys.modules["lab"] = sys.modules[__name__]


ROOT = Path(__file__).resolve().parents[2]
PRESET_SCHEMA = "cybersand.material-lab.preset"
EXPORT_SCHEMA = "cybersand.material-lab.export"
SCHEMA_VERSION = 1
MAX_JSON_BYTES = 1024 * 1024
MAX_REACTIONS = 56
MAX_PROCESS_OUTPUT_BYTES = 1024 * 1024
_CANCEL_FILE: ContextVar[Path | None] = ContextVar("material_lab_cancel_file", default=None)
PRESET_FIELDS = (
    "schema_id", "schema_version", "source_catalogue_sha256", "template_id",
    "target_id", "name", "descriptor", "capabilities", "appearance", "reactions",
)
REACTION_FIELDS = (
    "slot", "rule_id", "first", "second", "first_product", "second_product",
    "probability", "match", "effects",
)
SOURCE_FILES = tuple(dict.fromkeys((
    "materials/catalogue/catalogue.json",
    "materials/catalogue/compatibility-lock.json",
    "native/include/cybersand/material.hpp",
    "native/include/cybersand/material_rules.hpp",
    "native/include/cybersand/material_capabilities.hpp",
    "native/include/cybersand/interaction_rules.hpp",
    "native/src/material_rules.cpp",
    "tools/material_catalogue/compiler.py",
    "tools/material_catalogue/native_capabilities.py",
    "tools/material_catalogue/compatibility.py",
    "tools/material_catalogue/lab.py",
    "tools/material_catalogue/world_case.py",
    "tools/material_catalogue/reaction_effects.py",
    "tools/material_catalogue/lab_native_probe.cpp",
    *compatibility.SOURCE_ROLES,
)))


class LabError(ValueError):
    """Actionable authoring refusal; production source is never changed."""


class LabCancelled(LabError):
    """The caller revoked this operation before it could publish a result."""


@contextmanager
def _cancellation_scope(path: Path | None):
    token = _CANCEL_FILE.set(Path(path).resolve() if path is not None else None)
    try:
        yield
    finally:
        _CANCEL_FILE.reset(token)


def _check_cancelled() -> None:
    path = _CANCEL_FILE.get()
    if path is not None and path.exists():
        raise LabCancelled("/cancel: operation cancelled; no tested status was recorded")


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
                      "effects": list(reaction_effects.EFFECT_KINDS),
                      "detail": "Edit existing owned sparse slots; rule IDs and order are retained. Effects v2 admit non-Water keep_existing and Metal/Combustible state_b only in compiled World tests, with role-preserving matching. Synthetic 132 has no reaction consumer."},
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
        reaction_effects.validate_rule(edited, native, at)
        effects = edited["effects"]
        rule_changed = False
        original_effects = _candidate_rule(original)["effects"]
        if effects != original_effects:
            changes.append({"path": at + "/effects", "before": original_effects,
                            "after": copy.deepcopy(effects), "boundary": "isolated compiled World endpoint effects"})
            rule_changed = True
        for key in ("first", "second", "first_product", "second_product", "probability", "match"):
            if edited[key] != original[key]:
                changes.append({"path": at + "/" + key, "before": original[key], "after": edited[key], "boundary": "isolated native resolver fixture"})
                original[key] = edited[key]
                rule_changed = True
        if rule_changed:
            # Slot/key retain legacy lineage, but their prose is not evidence
            # for edited products. Generate an exact candidate-only statement.
            first_name = native["materials"][original["first_product"]]["name"]
            second_name = native["materials"][original["second_product"]]["name"]
            orientation = ("source/target positions" if original["match"] == 2 else "first/second material roles")
            original["accounting"] = reaction_effects.describe(edited, native) if any(
                effects[endpoint]["kind"] != "replace_with_defaults" for endpoint in ("first", "second")) else (
                f"candidate effects v{effects['version']}: replace_with_defaults at both endpoints; {orientation} "
                f"produce {first_name} ({original['first_product']}) and {second_name} ({original['second_product']}); "
                "World quantity accounting and conservation have not been qualified for this edit"
            )
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
    _check_cancelled()
    normalized, catalogue, changes = expand_candidate(candidate)
    protected = compatibility.check()
    _check_cancelled()
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
    _check_cancelled()
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


def _terminate_process_tree(process: subprocess.Popen) -> None:
    """Kill compiler drivers and their children, not just the driver PID."""
    if os.name == "nt":
        if process.poll() is None:
            try:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               timeout=1.0, check=False)
            except (OSError, subprocess.SubprocessError):
                process.kill()
            if process.poll() is None:
                process.kill()
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        process.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        process.kill()


def _run(command: list[str], directory: Path, timeout: int | float, *, check: bool = True) -> subprocess.CompletedProcess:
    """Execute a bounded child with cancellation and bounded stdout/stderr.

    Readers prevent pipe deadlocks while retaining at most one MiB per stream.
    A process group contains compiler subprocesses on POSIX; Windows uses the
    native process-tree termination command. No shell interprets the argv.
    """
    _check_cancelled()
    streams = [bytearray(), bytearray()]
    overflow = threading.Event()
    options = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt"
               else {"start_new_session": True})
    process = subprocess.Popen(command, cwd=directory, stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               shell=False, **options)

    def capture(pipe, retained: bytearray) -> None:
        try:
            while chunk := pipe.read(16384):
                remaining = MAX_PROCESS_OUTPUT_BYTES - len(retained)
                retained.extend(chunk[:remaining])
                if len(chunk) > remaining:
                    overflow.set()
                    break
        finally:
            pipe.close()

    readers = [threading.Thread(target=capture, args=(pipe, retained), daemon=True)
               for pipe, retained in zip((process.stdout, process.stderr), streams)]
    for reader in readers:
        reader.start()
    deadline = time.monotonic() + timeout
    try:
        while process.poll() is None:
            _check_cancelled()
            if overflow.is_set():
                fail("/compile_test", f"process output exceeded the {MAX_PROCESS_OUTPUT_BYTES}-byte per-stream limit; no tested status was recorded")
            if time.monotonic() >= deadline:
                fail("/compile_test", f"bounded process exceeded {timeout:g} seconds; no tested status was recorded")
            time.sleep(0.025)
        # Normal compiler/probe completion must also close its output handles.
        # A detached descendant may otherwise keep a pipe reader alive forever.
        for reader in readers:
            reader.join(timeout=0.1)
        if any(reader.is_alive() for reader in readers):
            _terminate_process_tree(process)
            for reader in readers:
                reader.join(timeout=0.1)
            fail("/compile_test", "process returned before its child output streams closed; no tested status was recorded")
        _check_cancelled()
        if overflow.is_set():
            fail("/compile_test", f"process output exceeded the {MAX_PROCESS_OUTPUT_BYTES}-byte per-stream limit; no tested status was recorded")
    except BaseException:
        _terminate_process_tree(process)
        for reader in readers:
            reader.join(timeout=0.1)
        raise
    result = subprocess.CompletedProcess(command, process.returncode,
        streams[0].decode("utf-8", errors="replace"), streams[1].decode("utf-8", errors="replace"))
    if check and result.returncode:
        detail = (result.stderr + "\n" + result.stdout).strip()[-8000:]
        fail("/compile_test", f"process returned {result.returncode}: {detail}")
    return result


def _source_identity() -> dict:
    files = {name: hashlib.sha256((ROOT / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest() for name in SOURCE_FILES}
    result = _run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], ROOT, 10, check=False)
    return {"git_head": result.stdout.strip() if result.returncode == 0 else "unavailable",
            "lf_sha256": files, "digest": digest(files),
            "qualification": "The file digest binds this executed source, including uncommitted implementation changes; git_head alone does not."}


def compile_test(candidate: Any, *, output_dir: Path | None = None, diagnostic: dict | None = None,
                 sanitize: bool = False, cxx: str | None = None) -> dict:
    # Custody starts before either catalogue expansion or compatibility check.
    # Otherwise a change between validation and the first snapshot can be
    # misreported as stable, admitted source throughout compilation.
    identity_before = _source_identity()
    result = validate_candidate(candidate)
    normalized, catalogue, _changes = expand_candidate(result["candidate"])
    if reaction_effects.has_extended(normalized):
        fail("/reactions/effects", "keep_existing and set_state execute only in the compiled World backend. Open Candidate test and Compile + compare World; the descriptor/resolver probe does not apply endpoint state effects.")
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
        expected_input = hashlib.sha256(source.read_bytes()).hexdigest()
        outputs = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(generated.iterdir())}

        def verify_generated(directory: Path) -> None:
            if hashlib.sha256((directory / "candidate-catalogue.json").read_bytes()).hexdigest() != expected_input:
                fail("/compile_test", "candidate catalogue bytes changed after generation; no tested status recorded")
            observed_outputs = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in sorted((directory / "generated").iterdir()) if path.is_file()}
            if observed_outputs != outputs or any(not path.is_file() for path in (directory / "generated").iterdir()):
                fail("/compile_test", "generated compiler inputs differ from the executed source packet; no tested status recorded")

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
        executable_digest = hashlib.sha256(executable.read_bytes()).hexdigest()
        verify_generated(staging)
        executed = _run([str(executable), str(normalized["target_id"]),
                         str(diagnostic["source"]), str(diagnostic["target"]), str(diagnostic["roll"])], staging, 20)
        try:
            observed = json.loads(executed.stdout)
        except (json.JSONDecodeError, ValueError) as error:
            raise LabError(f"/compile_test: native probe did not return valid JSON: {error}") from error
        if not observed.get("ok") or observed.get("runtime_active") is not False:
            fail("/compile_test", "native probe did not acknowledge candidate-only successful execution")
        version = _run([cxx] if msvc else [cxx, "--version"], staging, 10, check=False)
        version_text = (version.stdout + "\n" + version.stderr).strip().splitlines()
        verify_generated(staging)
        if hashlib.sha256(executable.read_bytes()).hexdigest() != executable_digest:
            fail("/compile_test", "native executable changed during execution/version capture; no tested status recorded")
        # Keep the emitted PASS tied to the same admitted protected consumers.
        # This also verifies every compatibility prerequisite at publication.
        compatibility.check()
        identity_after = _source_identity()
        if identity_before["digest"] != identity_after["digest"]:
            fail("/compile_test", "source inputs changed during validation/compilation/execution; rerun against a stable source before recording tested status")
        _check_cancelled()
        receipt = {"schema_id": "cybersand.material-lab.native-receipt", "schema_version": 1,
                   "candidate_digest": result["digest"], "compiled_catalogue_sha256": digest(catalogue),
                   "source_identity": identity_before, "compiler": Path(cxx).name,
                   "compiler_version": version_text[0] if version_text else "unavailable",
                   "platform": sys.platform, "sanitizers": "address,undefined" if sanitize else "none",
                   "sanitizer_runtime_options": {key: os.environ.get(key, "") for key in ("ASAN_OPTIONS", "UBSAN_OPTIONS")} if sanitize else {},
                   "native_executable_sha256": executable_digest,
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
                verify_generated(publication)
                if (publication / "native-receipt.json").read_bytes() != canonical(receipt):
                    fail("/output_dir", "copied native receipt does not match the executed result")
                # rename is atomic on the same parent filesystem and never
                # overwrites a non-empty prior build directory.
                _check_cancelled()
                if _source_identity()["digest"] != identity_before["digest"]:
                    fail("/output_dir", "source changed during bundle publication; no tested fixture exported")
                os.rename(publication, destination)
            finally:
                if publication.exists():
                    shutil.rmtree(publication)
            result["output_dir"] = str(destination)
    if destination is None:
        _check_cancelled()
    result.update(state="compiled_tested", receipt=receipt,
                  boundary="Generated descriptors and sparse rules were compiled and exercised by native C++ functions. World movement, sleeping, state mutation and quantity accounting were not executed for this candidate. It is not runtime-active.")
    return result


def request(value: Any) -> dict:
    _check_cancelled()
    if type(value) is not dict or type(value.get("op")) is not str:
        fail("/op", "expected a Materials Lab operation")
    op = value["op"]
    allowed = {
        "create": ({"op", "template_id"}, {"synthetic"}),
        "validate": ({"op", "candidate"}, set()),
        "compile_test": ({"op", "candidate"}, {"output_dir", "diagnostic", "sanitize", "cxx"}),
        "compile_world_test": ({"op", "candidate"}, {"scenario", "output_dir", "sanitize", "cxx"}),
        "import": ({"op", "path"}, set()),
        "export": ({"op", "candidate", "path"}, set()),
        "import_world_case": ({"op", "path"}, set()),
        "export_world_case": ({"op", "candidate", "scenario", "path"}, set()),
    }
    if op not in allowed:
        fail("/op", "expected create, validate, compile_test, compile_world_test, import, export, import_world_case or export_world_case")
    required, optional = allowed[op]
    if not required <= value.keys() or value.keys() - required - optional:
        fail("/", f"invalid request fields for {op}; required={sorted(required)}, optional={sorted(optional)}")
    if op == "create":
        candidate = create_candidate(value["template_id"], synthetic=value.get("synthetic", False))
        return {"ok": True, "state": "draft", "candidate": candidate, "runtime_active": False,
                "supported_fields": supported_fields(candidate["template_id"])}
    if op == "validate":
        return validate_candidate(value["candidate"])
    if op in ("import", "export", "import_world_case", "export_world_case"):
        if type(value["path"]) is not str or not value["path"]:
            fail("/path", "expected an explicit file path")
        if op in ("import_world_case", "export_world_case"):
            import world_case
            return (world_case.import_case(Path(value["path"])) if op == "import_world_case" else
                    world_case.export_case(value["candidate"], value["scenario"], Path(value["path"])))
        return import_candidate(Path(value["path"])) if op == "import" else export_candidate(value["candidate"], Path(value["path"]))
    if "output_dir" in value and (type(value["output_dir"]) is not str or not value["output_dir"]):
        fail("/output_dir", "expected an external output directory path")
    if "cxx" in value and (type(value["cxx"]) is not str or not value["cxx"].strip()):
        fail("/cxx", "expected one non-empty compiler executable name or path; omit cxx to use the environment/default selection")
    boolean(value.get("sanitize", False), "/sanitize")
    if op == "compile_world_test":
        import world_candidate
        return world_candidate.compile_world_test(value["candidate"], scenario=value.get("scenario"),
            output_dir=Path(value["output_dir"]) if "output_dir" in value else None,
            sanitize=value.get("sanitize", False), cxx=value.get("cxx"))
    return compile_test(value["candidate"], output_dir=Path(value["output_dir"]) if "output_dir" in value else None,
                        diagnostic=value.get("diagnostic"), sanitize=value.get("sanitize", False), cxx=value.get("cxx"))


def _protocol_paths(value: Any, request_path: Path, response_path: Path | None,
                    cancel_path: Path | None) -> None:
    """Refuse overlapping protocol artifacts before any operation can write."""
    request_path = request_path.resolve()
    response_path = response_path.resolve() if response_path is not None else None
    cancel_path = cancel_path.resolve() if cancel_path is not None else None
    protected = {request_path}
    if response_path is not None:
        if response_path == request_path:
            fail("/response", "response path must not overwrite the request")
        if response_path.is_relative_to(ROOT.resolve()):
            fail("/response", "response must be outside the source repository")
        protected.add(response_path)
    if type(value) is dict:
        if value.get("op") in ("import", "export", "import_world_case", "export_world_case") and type(value.get("path")) is str and value["path"]:
            preset_path = Path(value["path"]).resolve()
            if response_path == preset_path:
                fail("/response", "response path must not overwrite the imported or exported preset")
            if value["op"] in ("export", "export_world_case") and preset_path == request_path:
                fail("/path", "export path must not overwrite the request")
            protected.add(preset_path)
        if value.get("op") in ("compile_test", "compile_world_test") and type(value.get("output_dir")) is str and value["output_dir"]:
            output_dir = Path(value["output_dir"]).resolve()
            if response_path is not None and response_path.is_relative_to(output_dir):
                fail("/response", "response path must be outside the compiled output directory")
            if cancel_path is not None and cancel_path.is_relative_to(output_dir):
                fail("/cancel_file", "cancellation marker must be outside the compiled output directory")
    if cancel_path in protected:
        fail("/cancel_file", "cancellation marker must not alias a request, response or preset")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--response", type=Path)
    parser.add_argument("--cancel-file", type=Path,
                        help="external cancellation marker; its existence revokes the pending operation")
    args = parser.parse_args(argv)
    value = None
    safe_response = False
    try:
        # First check protects the request even if its JSON cannot be parsed.
        _protocol_paths(value, args.request, args.response, args.cancel_file)
        safe_response = True
        value = read_json(args.request)
        safe_response = False
        _protocol_paths(value, args.request, args.response, args.cancel_file)
        safe_response = True
        with _cancellation_scope(args.cancel_file):
            result = request(value)
    except LabCancelled as error:
        result = {"ok": False, "state": "draft", "runtime_active": False,
                  "cancelled": True, "errors": [str(error)]}
    except (LabError, compiler.CatalogueError, compatibility.CompatibilityError, OSError, UnicodeError,
            ValueError, TypeError, KeyError, RecursionError, subprocess.SubprocessError) as error:
        result = {"ok": False, "state": "draft", "runtime_active": False, "errors": [str(error)]}
    if args.response is not None:
        try:
            if not safe_response:
                print(canonical(result).decode(), end="")
                return 2
            _atomic_json(args.response, result)
        except (LabError, OSError) as error:
            print(canonical({"ok": False, "state": "draft", "errors": [str(error)]}).decode(), end="")
            return 2
    else:
        print(canonical(result).decode(), end="")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
