#!/usr/bin/env python3
"""Source-bound Main/Web display proof with mandatory retained runtime evidence.

--check is a nonwriting static gate, never B runtime qualification. Runtime mode
copies the real project, executes legacy/candidate/poison/rollback, and retains
every raw result, source manifest and log beside a NEW report. --verify checks
those actual files and the current source again. No World ticks, pixels, browser
or Wasm qualification follows from host-platform inherited Web execution.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

import compatibility
import display_contract
import legacy_display_names as legacy
import presentation
import proof_scopes
from check_native_parity import _report_output, compare, file_fact, read_json

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "cybersand.material-catalogue.display-consumer"
RAW_SCHEMA = "cybersand.material-catalogue.raw-display-probe"
PROBE = "tools/material_catalogue/display_probe.gd"
PROBE_COPY = "godot/tests/mat353b_display_probe.gd"
EDITOR_PIN = "third_party/godot-runtime.lock.json"
EDITOR_VERSION = "4.7.stable.official.5b4e0cb0f"
ENGINE_VERSION = "4.7-stable (official)"
STAGES = ("legacy", "candidate", "poison", "rollback")
OTHER_STAGE = {"legacy": None, "candidate": "legacy", "poison": "candidate", "rollback": "candidate"}
POISON = "SAND"
ALLOWANCES = {"import_seconds": 240, "probe_seconds": 180,
              "scope": "explicit local display-probe limits; not repository-wide watchdog values"}
RUNTIMES = {
    "godot/addons/cybersand_native/runtime-provenance.linux.json":
        "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "godot/addons/godot-rapier2d/runtime-provenance.linux.json":
        "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
}
TOOLS = (
    "tools/material_catalogue/check_display_consumer.py", PROBE,
    "tools/material_catalogue/compatibility.py", "tools/material_catalogue/display_contract.py",
    "tools/material_catalogue/legacy_display_names.py", "tools/material_catalogue/presentation.py",
    "tools/material_catalogue/compiler.py", "tools/material_catalogue/proof_scopes.py",
    "tools/material_catalogue/check_native_parity.py",
)
INPUTS = (presentation.CATALOGUE, presentation.PRESENTATION, presentation.MANIFEST,
          legacy.FIXTURE.as_posix(), compatibility.LOCK.as_posix(), EDITOR_PIN,
          *RUNTIMES, "godot/third_party/rapier2d.lock.json",
          "godot/tests/support/ci_execution_policy.json")
LOADED_TOOLS = {name: hashlib.sha256((ROOT / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
                for name in TOOLS if name.endswith(".py")}
CONTROLLERS = {"main": "scripts/main.gd", "inherited_web_controller": "scripts/web_demo_controller.gd"}
PROBE_SCRIPTS = ("scripts/main.gd", "scripts/web_demo_controller.gd", "scripts/tower_panel.gd",
                 "scripts/transport_profile_panel.gd", "scripts/microscenario_workbench.gd",
                 "scripts/microscenario_identity.gd", "scripts/microscenario_comparison.gd",
                 "scripts/experiment_tower.gd", "scripts/simulation_snapshot.gd", "scripts/cell_world.gd")
TOWER_IDS = ((2, 14, 2, 29, 13, 2), (3, 2, 3, 2, 3, 2),
             (3, 16, 24, 33, 20, 21, 8, 12, 30, 32, 36), (33, 2, 33, 33),
             (3, 23, 3, 8, 12, 28, 7, 16, 27))
HUD_IDS = (0, 2, 10, 80, 83, 113, 117, 131, 132, -1)
RUNTIME_SCOPE = "actual Main and inherited Web display/UI methods on Linux; no World, pixels, browser or Wasm qualification"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, ensure_ascii=False, allow_nan=False, indent=2) + "\n").encode()


def object_keys(value: object, keys, label: str) -> dict:
    if type(value) is not dict:
        raise ValueError(label + ": expected an object")
    compare(sorted(keys), sorted(value), label + " fields")
    return value


def no_alias(path: Path) -> None:
    for part in (path, *path.parents):
        if part.is_symlink():
            raise ValueError("filesystem aliases are not admitted: " + str(path))
    if path.exists() and (not path.is_file() or path.stat().st_nlink != 1):
        raise ValueError("expected an independent regular file: " + str(path))


def load_json(path: Path, maximum: int = 16 * 1024 * 1024) -> dict:
    no_alias(path)
    if path.stat().st_size > maximum:
        raise ValueError("bounded report size exceeded: " + str(path))
    return read_json(path.read_text(encoding="utf-8"), str(path))


def ignored(path: Path) -> bool:
    return ".godot" in path.parts or "__pycache__" in path.parts or path.name.endswith(".tmp")


def project_files(root: Path) -> list[dict]:
    result = []
    for path in sorted((root / "godot").rglob("*")):
        if ignored(path.relative_to(root / "godot")):
            continue
        if path.is_symlink():
            raise ValueError("project source alias: " + str(path))
        if path.is_file():
            result.append(file_fact(path, root))
    return result


def current_source(root: Path = ROOT) -> dict:
    root = root.resolve()
    guarded = compatibility.check(root, baseline_repository=root)
    legacy.check(root, root)
    for name, expected in LOADED_TOOLS.items():
        compare(expected, sha((root / name).read_bytes().replace(b"\r\n", b"\n")),
                "selected source differs from executing tool: " + name)
    inventories = {"tools": [file_fact(root / path, root) for path in TOOLS],
                   "inputs": [file_fact(root / path, root) for path in INPUTS],
                   "project": project_files(root)}
    if any(row["path"] == PROBE_COPY for row in inventories["project"]):
        raise ValueError("temporary probe path already exists in the source project")
    return {"compatibility": guarded, "inventories": inventories,
            "checked_source": proof_scopes.checked_source(root, inventories)}


def static_check(root: Path = ROOT) -> dict:
    return {"schema_id": SCHEMA, "schema_version": 2, "status": "PASS", "mode": "static",
            "scope": "current source, immutable legacy oracle and generated labels only",
            "authority_scopes": copy.deepcopy(proof_scopes.AUTHORITY_SCOPES),
            "godot_executed": False, "ui_behavior_executed": False, "b_consumer_qualified": False,
            "b_consumer_requirement": copy.deepcopy(proof_scopes.B_CONSUMER_REQUIREMENT),
            **current_source(root)}


def authenticate_editor(godot: Path, archive: Path, root: Path = ROOT) -> dict:
    pin = load_json(root / EDITOR_PIN)["editor"]
    archive_bytes = archive.read_bytes()
    compare(pin["size"], len(archive_bytes), "pinned Godot archive size")
    compare(pin["sha256"], sha(archive_bytes), "pinned Godot archive hash")
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as zipped:
        member = pin["filename"].removesuffix(".zip")
        compare([member], zipped.namelist(), "pinned Godot archive inventory")
        executable_sha = sha(zipped.read(member))
    compare(executable_sha, sha(godot.read_bytes()), "Godot executable versus authenticated archive")
    version = subprocess.run([str(godot.resolve()), "--version"], capture_output=True,
                             text=True, check=True, timeout=30)
    compare(EDITOR_VERSION, version.stdout.strip(), "actual Godot version")
    return {"version": EDITOR_VERSION, "archive": file_fact(archive.resolve(), root),
            "executable": file_fact(godot.resolve(), root), "pin": file_fact(root / EDITOR_PIN, root)}


def runtime_custody(root: Path = ROOT) -> dict:
    """Authenticate actual Linux bytes; unchanged source alone is insufficient."""
    manifests, artifacts, sources = [], [], {}
    lock_path = "godot/third_party/rapier2d.lock.json"
    compare(legacy.git_bytes(root, lock_path), (root / lock_path).read_bytes(), "accepted Rapier lock")
    compare("godot/addons/godot-rapier2d/runtime-provenance.linux.json",
            load_json(root / lock_path)["runtime_overrides"]["linux"], "selected Linux Rapier provenance")
    for name, artifact in RUNTIMES.items():
        compare(legacy.git_bytes(root, name), (root / name).read_bytes(), "accepted runtime provenance " + name)
        manifest = load_json(root / name)
        compare(1, manifest.get("schema_version"), "runtime provenance schema")
        compare(artifact, manifest.get("artifact"), "runtime artifact path")
        data = (root / artifact).read_bytes()
        if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            raise ValueError("Linux runtime must be materialized: " + artifact)
        compare(manifest["size"], len(data), "published runtime byte size")
        compare(manifest["sha256"], sha(data), "published runtime actual byte hash")
        pointer = subprocess.run(["git", "-C", str(root), "show", "HEAD:" + artifact],
                                 capture_output=True, check=True, timeout=30).stdout
        expected = ("version https://git-lfs.github.com/spec/v1\noid sha256:" + sha(data) +
                    "\nsize " + str(len(data)) + "\n").encode()
        compare(expected, pointer, "committed LFS runtime identity")
        for path, expected_sha in manifest["source_inputs"].items():
            compare(expected_sha, sha((root / path).read_bytes().replace(b"\r\n", b"\n")),
                    "runtime source input " + path)
            sources[path] = file_fact(root / path, root)
        manifests.append(file_fact(root / name, root))
        artifacts.append(file_fact(root / artifact, root))
    return {"scope": "measured published Linux libraries and their accepted source provenance",
            "manifests": manifests, "artifacts": artifacts,
            "source_inputs": [sources[path] for path in sorted(sources)]}


def stage_bytes(root: Path, stage: str) -> dict[str, bytes | None]:
    if stage not in STAGES:
        raise ValueError("unknown display stage")
    old = stage in {"legacy", "rollback"}
    changes = {name: legacy.git_bytes(root, name) if old else (root / name).read_bytes()
               for name in (display_contract.MAIN, display_contract.IDENTITY)}
    resource = None if old else (root / presentation.SCRIPT).read_bytes()
    if stage == "poison":
        needle = b'\t"sand", # 2\n'
        if resource.count(needle) != 1:
            raise ValueError("ordinary Sand label poison anchor changed")
        resource = resource.replace(needle, ('\t"' + POISON + '", # 2\n').encode(), 1)
    changes[presentation.SCRIPT] = resource
    if old:
        changes[presentation.SCRIPT + ".uid"] = None
    return changes


def stage_manifest(root: Path, stage: str, current: dict) -> dict:
    facts = {row["path"]: row for row in current["inventories"]["project"]}
    for name, data in stage_bytes(root, stage).items():
        if data is None:
            facts.pop(name, None)
        else:
            facts[name] = {"path": name, "bytes": len(data), "sha256": sha(data)}
    probe = (root / PROBE).read_bytes()
    facts[PROBE_COPY] = {"path": PROBE_COPY, "bytes": len(probe), "sha256": sha(probe)}
    return {"schema_id": SCHEMA + ".stage-sources", "schema_version": 1, "stage": stage,
            "source_revision": legacy.BASELINE if stage in {"legacy", "rollback"}
                               else current["checked_source"]["git_head"],
            "scope": "all copied source/resource bytes; fresh Godot caches and new UID metadata are import outputs",
            "source_files": [facts[path] for path in sorted(facts)]}


def script_paths(identity_source: bytes) -> list[str]:
    match = re.search(rb"const SOURCES: Array\[String\] = \[(.*?)\]", identity_source, re.S)
    if not match:
        raise ValueError("apparatus executable source list is not literal")
    paths = re.findall(rb'"([^"\n]+)"', match[1])
    if re.sub(rb'"[^"\n]+"|[\s,]', b"", match[1]) or len(set(paths)) != len(paths):
        raise ValueError("unsupported or duplicate apparatus source list")
    return [path.decode() for path in paths]


def runtime_identity(root: Path, stage: str, manifest: dict) -> dict:
    facts = {row["path"]: row for row in manifest["source_files"]}
    identity_source = stage_bytes(root, stage)[display_contract.IDENTITY]
    scripts = {name: facts["godot/" + name]["sha256"] for name in script_paths(identity_source)}
    return {"source_revision": manifest["source_revision"], "revision_status": "caller-supplied",
            "script_sha256": scripts,
            "script_set_sha256": sha(json.dumps(scripts, sort_keys=True, separators=(",", ":")).encode()),
            "source_scope": "listed apparatus scripts; not a full checkout manifest",
            "native_path": "res://" + RUNTIMES[next(iter(RUNTIMES))].removeprefix("godot/"),
            "native_sha256": facts[RUNTIMES[next(iter(RUNTIMES))]]["sha256"],
            "material_catalogue": {"count": 132, "reserved_ids": [10],
                                   "authority": "native artifact; cell_world.gd identifies the UI mirror"},
            "platform": "Linux", "godot": ENGINE_VERSION}


def expected_checks(other: bool) -> dict:
    result = {"inputs": 814, "comparison": 10 if other else 6}
    for controller in CONTROLLERS:
        for suffix, count in {"": 2, "/names": 277, "/selection": 974, "/tower": 119,
                              "/transport": 161, "/transport/source": 161,
                              "/transport/target": 161, "/workbench": 653,
                              "/hud": 10 if controller == "main" else 11}.items():
            result[controller + suffix] = count
    return result


def validate_controller(value: dict, name: str, oracle: dict, names: dict, identity: dict, facts: dict) -> None:
    object_keys(value, ("script", "script_sha256", "names", "selection", "tower", "transport", "workbench", "hud"), name)
    compare("res://" + CONTROLLERS[name], value["script"], name + " actual script")
    compare(facts["godot/" + CONTROLLERS[name]]["sha256"], value["script_sha256"], name + " script hash")
    compare([{"id": row["id"], "actual": names[row["id"]]} for row in oracle["cases"]], value["names"], name + " complete signed64 names")
    paintable, groups = oracle["paintable_ids"], oracle["group_first_ids"]
    cycles = [{"id": str(ident), "direction": direction, "selected": paintable[(index + direction) % len(paintable)],
               "secondary": paintable[(index + 1) % len(paintable)], "paint_slot": 0}
              for index, ident in enumerate(paintable) for direction in (-1, 1)]
    unknown = [{"id": str(ident), "direction": direction, "selected": paintable[direction % len(paintable)], "secondary": paintable[0]}
               for ident in (0, 10, -1, 132, 255, -(1 << 63), (1 << 63) - 1) for direction in (-1, 0, 1)]
    group_cycles = []
    for row in oracle["cases"]:
        selected = max([index for index, first in enumerate(groups) if int(row["id"]) >= first] or [0])
        group_cycles.extend({"id": row["id"], "direction": direction,
                             "selected": groups[(selected + direction) % len(groups)], "paint_slot": 0}
                            for direction in (-1, 1))
    compare({"paintable_ids": paintable, "group_first_ids": groups, "cycles": cycles,
             "unknown_cycles": unknown, "group_cycles": group_cycles}, value["selection"], name + " selection")

    def rows(ids, separator):
        return [{"index": index, "id": ident, "text": str(ident) + separator + names[str(ident)]}
                for index, ident in enumerate(ids)]

    transport_ids = [ident for ident in range(81) if ident != 10]
    compare({"source_items": rows(transport_ids, " "), "target_items": rows(transport_ids, " "),
             "default_selection": {"source": 3, "target": 2},
             "selections": [{"source": first, "target": second,
                             "effective_heading": "Effective validated draft: %s to %s" % (names[str(first)], names[str(second)])}
                            for first, second in zip(transport_ids, reversed(transport_ids))]},
            value["transport"], name + " transport v1 UI")
    workbench_ids = [ident for ident in range(1, 132) if ident != 10]
    ui_identity = {**identity, "source_revision": "unavailable", "revision_status": "not-embedded"}
    compare({"items": rows(workbench_ids, " / "), "selections": workbench_ids,
             "exported_material_identities": [{"id": ident, "ui_name": names[str(ident)]} for ident in [0, *workbench_ids]],
             "runtime_identity": ui_identity,
             "context_scope": "synthetic copied owner context; actual workbench setup/refresh/details methods"},
            value["workbench"], name + " workbench and exported ui_name")
    hud = []
    for ident in HUD_IDS:
        secondary = paintable[(paintable.index(ident) + 1) % len(paintable)] if ident in paintable else paintable[0]
        fragment = names[str(ident)] if name != "main" else "P %d:%s · M %d:%s" % (ident, names[str(ident)], secondary, names[str(secondary)])
        hud.append({"id": str(ident), "material_fragment": fragment})
    compare(hud, value["hud"], name + " actual HUD fragments")
    tower = object_keys(value["tower"], ("floor_picker", "floors"), name + " Tower")
    titles = ("Flowing powders", "Water and erosion", "Liquid gallery", "Mercury references", "Chemistry observations")
    compare([{"index": index, "id": index, "text": str(index + 1) + " / " + title} for index, title in enumerate(titles)],
            tower["floor_picker"], name + " Tower floors")
    if type(tower["floors"]) is not list or len(tower["floors"]) != 5:
        raise ValueError(name + ": all five Tower floor observations required")
    for index, (floor, ids) in enumerate(zip(tower["floors"], TOWER_IDS)):
        object_keys(floor, ("floor", "selected_floor_id", "labels", "tubes"), name + " Tower floor")
        compare(index, floor["floor"], name + " Tower floor index")
        compare(index, floor["selected_floor_id"], name + " Tower floor selection")
        compare([{"material_id": ident, "text": names[str(ident)], "selected_item_id": tube}
                 for tube, ident in enumerate(ids)], floor["labels"], name + " Tower labels/selection")
        if type(floor["tubes"]) is not list or len(floor["tubes"]) != len(ids):
            raise ValueError(name + ": complete Tower tube inventory required")
        for tube, (item, ident) in enumerate(zip(floor["tubes"], ids)):
            object_keys(item, ("index", "id", "text"), name + " Tower tube")
            compare(tube, item["index"], name + " Tower tube order")
            compare(tube, item["id"], name + " Tower tube ID")
            if type(item["text"]) is not str or not item["text"].startswith("%d / %s / " % (tube + 1, names[str(ident)])):
                raise ValueError(name + ": Tower tube display name differs")


def validate_comparison(value: dict, left: dict, right: dict, matched: bool) -> None:
    object_keys(value, ("matched_runtime_tick_seed", "reports", "scope", "slots"), "actual comparison")
    compare(matched, value["matched_runtime_tick_seed"], "actual comparison eligibility")
    compare("Necessary comparison checks only; organic user inputs are not replayed or proven matched", value["scope"], "comparison scope")
    reports = {slot: {"completed_tick": 0, "native": {"scope": "synthetic comparator input; no World execution"},
                      "observations": [], "outcome": "synthetic comparison control", "runtime_identity": ident, "worker_count": 1}
               for slot, ident in (("A", left), ("B", right))}
    compare(reports, value["reports"], "comparison actual input identities")
    hashes = ("bce0f4c8b4466214d43ea6fca653e0d867ea03759f22413427eff41d84366530",
              "9dead51411fdc91b280bc9118beecb071e7ce4634b49bdccfc21aeb4241a8c67")
    compare({slot: {"id": "display-probe/" + slot.lower(), "seed": 0, "recipe_version": 1,
                    "definition_hash": digest, "profile": "legacy"} for slot, digest in zip(("A", "B"), hashes)},
            value["slots"], "comparison controlled slots")


def validate_raw(raw: dict, stage: str, manifest: dict, oracle: dict, oracle_sha: str,
                 root: Path, other: dict | None = None, other_sha: str | None = None) -> dict:
    keys = ("schema_id", "schema_version", "godot", "platform", "display_server", "browser_or_wasm_execution",
            "scope", "oracle_sha256", "probe_sha256", "controllers", "runtime_identity", "loaded_scripts",
            "comparison_controls", "assertions", "checks", "failures", "status")
    object_keys(raw, keys, "raw display probe")
    compare(RAW_SCHEMA, raw["schema_id"], "raw probe schema")
    compare(1, raw["schema_version"], "raw probe schema version")
    compare(ENGINE_VERSION, raw["godot"], "raw engine version")
    compare("Linux", raw["platform"], "raw target platform")
    compare("headless", raw["display_server"], "raw display server")
    compare(False, raw["browser_or_wasm_execution"], "host-platform inherited Web scope")
    compare("Actual detached Main and inherited Web scripts, real UI methods and synthetic UI context; no World tick or rendered-pixel claim", raw["scope"], "raw proof scope")
    compare(oracle_sha, raw["oracle_sha256"], "raw immutable oracle hash")
    compare(sha((root / PROBE).read_bytes()), raw["probe_sha256"], "raw actual probe hash")
    checks = expected_checks(other is not None)
    compare(checks, raw["checks"], "complete UI check scopes")
    compare(sum(checks.values()), raw["assertions"], "complete assertion count")
    facts = {row["path"]: row for row in manifest["source_files"]}
    identity = runtime_identity(root, stage, manifest)
    compare(identity, raw["runtime_identity"], "actual apparatus fingerprint")
    compare({name: facts["godot/" + name]["sha256"] for name in PROBE_SCRIPTS}, raw["loaded_scripts"], "loaded production script hashes")
    names = {row["id"]: row["expected"] for row in oracle["cases"]}
    if stage == "poison":
        names["2"] = POISON
    object_keys(raw["controllers"], CONTROLLERS, "both real controllers")
    for name in CONTROLLERS:
        validate_controller(raw["controllers"][name], name, oracle, names, identity, facts)
    controls = raw["comparison_controls"]
    object_keys(controls, ("same_identity", "drifted_identity", "scope", *(["mixed_source", "other_probe_sha256"] if other else [])), "comparison controls")
    compare("actual comparator with synthetic capture-shaped records; no native observation or World execution", controls["scope"], "comparison control scope")
    validate_comparison(controls["same_identity"], identity, identity, True)
    drift = copy.deepcopy(identity)
    drift["script_sha256"]["scripts/main.gd"] = "f" * 64 if identity["script_sha256"]["scripts/main.gd"] != "f" * 64 else "0" * 64
    drift["script_set_sha256"] = sha(json.dumps(drift["script_sha256"], sort_keys=True, separators=(",", ":")).encode())
    validate_comparison(controls["drifted_identity"], identity, drift, False)
    if other is not None:
        if other["runtime_identity"]["script_set_sha256"] == identity["script_set_sha256"]:
            raise ValueError("mixed-source control did not use a different executable source set")
        compare(other_sha, controls["other_probe_sha256"], "actual other-probe file hash")
        # Godot JSON.parse_string reads JSON numbers as floats. Only this
        # cross-file identity was reloaded; all original raw fields above keep
        # their strict types, and only the two bounded numeric identity fields
        # have this exact readback representation.
        reloaded_identity = copy.deepcopy(other["runtime_identity"])
        catalogue = reloaded_identity["material_catalogue"]
        catalogue["count"] = float(catalogue["count"])
        catalogue["reserved_ids"] = [float(ident) for ident in catalogue["reserved_ids"]]
        validate_comparison(controls["mixed_source"], identity, reloaded_identity, False)
    compare("FAIL" if stage == "poison" else "PASS", raw["status"], "expected stage outcome")
    if stage != "poison":
        compare([], raw["failures"], "successful stage failures")
    else:
        if type(raw["failures"]) is not list or not raw["failures"]:
            raise ValueError("poison must produce actual equivalence failures")
        for failure in raw["failures"]:
            object_keys(failure, ("scope", "assertion", "actual", "expected"), "poison failure")
            if (failure["scope"] not in checks or type(failure["assertion"]) is not str or
                    POISON not in json.dumps(failure["actual"]) or "sand" not in json.dumps(failure["expected"])):
                raise ValueError("poison contains a failure unrelated to the routed Sand label")
        for name in CONTROLLERS:
            expected = {"scope": name + "/names", "assertion": "material_name(2)", "actual": POISON, "expected": "sand"}
            if expected not in raw["failures"]:
                raise ValueError("poison must fail the actual " + name + " method")
    return {"stage": stage, "assertions": raw["assertions"], "failures": len(raw["failures"]),
            "script_set_sha256": identity["script_set_sha256"], "status": raw["status"]}


def report_destination(output: Path, root: Path) -> tuple[Path, Path]:
    output = output.absolute()
    no_alias(output)
    output = _report_output(output, root)
    evidence = output.with_name(output.stem + ".evidence")
    for path in (output, evidence):
        if path.exists() or path.is_symlink():
            raise ValueError("choose a new report and evidence directory; refusing existing destination: " + str(path))
        for part in (path, *path.parents):
            if part.is_symlink():
                raise ValueError("report/evidence parent alias: " + str(path))
    return output, evidence


def new_file(path: Path, data: bytes) -> None:
    no_alias(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(data)


def publish_report(path: Path, data: bytes) -> None:
    """Atomic creation, never replacement, of the final qualifying receipt."""
    no_alias(path)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".display-report-", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        no_alias(path)
        os.link(temporary, path)  # Exclusive publication; EEXIST never overwrites.
    finally:
        temporary.unlink(missing_ok=True)


def recipe(stage: str, operation: str, revision: str) -> list[str]:
    command = ["${GODOT}", "--headless", "--path", "${PROJECT}"]
    if operation == "import":
        return command + ["--editor", "--import"]
    command += ["--script", "res://tests/mat353b_display_probe.gd", "--",
                "--oracle", "${ORACLE}", "--output", "${EVIDENCE}/" + stage + ".raw.json",
                "--source-revision", revision]
    if OTHER_STAGE[stage]:
        command += ["--other-probe", "${EVIDENCE}/" + OTHER_STAGE[stage] + ".raw.json"]
    return command


def process(command: list[str], command_recipe: list[str], evidence: Path, stage: str,
            operation: str, project: Path, environment: dict) -> dict:
    timeout = ALLOWANCES["import_seconds" if operation == "import" else "probe_seconds"]
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=project, env=environment, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        new_file(evidence / (stage + "." + operation + ".stdout.log"), error.stdout or b"")
        new_file(evidence / (stage + "." + operation + ".stderr.log"), error.stderr or b"")
        raise ValueError(stage + "/" + operation + ": local execution watchdog expired; incomplete evidence retained") from error
    paths = [evidence / (stage + "." + operation + "." + stream + ".log") for stream in ("stdout", "stderr")]
    for path, content in zip(paths, (result.stdout, result.stderr)):
        new_file(path, content)
    return {"command": command_recipe, "exit_code": result.returncode, "timeout_seconds": timeout,
            "seconds": round(time.monotonic() - started, 6),
            "stdout": file_fact(paths[0], evidence.parent), "stderr": file_fact(paths[1], evidence.parent)}


def check_project_copy(project: Path, manifest: dict) -> None:
    expected = {row["path"].removeprefix("godot/"): row for row in manifest["source_files"]}
    for relative, row in expected.items():
        path = project / relative
        no_alias(path)
        data = path.read_bytes()
        compare(row["bytes"], len(data), "copied input size " + relative)
        compare(row["sha256"], sha(data), "copied input hash " + relative)
    for path in project.rglob("*"):
        relative = path.relative_to(project)
        if ignored(relative):
            continue
        if path.is_symlink():
            raise ValueError("test-project alias introduced: " + str(relative))
        if path.is_file() and relative.as_posix() not in expected and path.suffix != ".uid":
            raise ValueError("unexpected executable/resource output in test copy: " + str(relative))


def evidence_file(row: dict, report: Path, expected: str) -> Path:
    object_keys(row, ("path", "bytes", "sha256"), "retained evidence fact")
    compare(expected, row["path"], "exact retained evidence filename")
    path = report.parent / expected
    no_alias(path)
    compare(row, file_fact(path, report.parent), "retained evidence bytes " + expected)
    return path


def validate_process(value: dict, report: Path, stage: str, operation: str, revision: str, raw: dict | None) -> None:
    object_keys(value, ("command", "exit_code", "timeout_seconds", "seconds", "stdout", "stderr"), stage + " execution receipt")
    compare(recipe(stage, operation, revision), value["command"], stage + " executed command recipe")
    compare(ALLOWANCES["import_seconds" if operation == "import" else "probe_seconds"], value["timeout_seconds"], "local timeout")
    compare(1 if stage == "poison" and operation == "probe" else 0, value["exit_code"], stage + " expected process return code")
    if type(value["seconds"]) not in (int, float) or not math.isfinite(value["seconds"]) or value["seconds"] < 0:
        raise ValueError("invalid measured process time")
    logs = []
    for stream in ("stdout", "stderr"):
        relative = report.stem + ".evidence/" + stage + "." + operation + "." + stream + ".log"
        path = evidence_file(value[stream], report, relative)
        if path.stat().st_size > 8 * 1024 * 1024:
            raise ValueError("bounded engine log size exceeded")
        logs.append(path.read_bytes())
    if any(b"SCRIPT ERROR:" in log or b"ERROR:" in log for log in logs):
        raise ValueError(stage + "/" + operation + ": engine error despite claimed process outcome")
    if raw is not None:
        marker = ("MATERIAL_DISPLAY_PROBE: %d assertions; %d failures; Linux; inherited Web is host-platform controller execution" %
                  (raw["assertions"], len(raw["failures"]))).encode()
        if logs[0].splitlines().count(marker) != 1:
            raise ValueError(stage + ": missing or mismatched actual probe completion marker")


def ui_projection(raw: dict, poison: bool = False) -> dict:
    result = copy.deepcopy(raw["controllers"])
    for value in result.values():
        value.pop("script")
        value.pop("script_sha256")
        value["workbench"].pop("runtime_identity")
    if poison:
        # The intentional same-length ordinary label is the sole expected delta.
        result = json.loads(json.dumps(result, ensure_ascii=False).replace(POISON, "sand"))
    return result


REPORT_FIELDS = {"schema_id", "schema_version", "status", "mode", "scope", "authority_scopes",
                 "current_source", "editor", "runtime", "allowances", "stages", "results",
                 "godot_executed", "ui_behavior_executed", "b_consumer_qualified", "world_executed",
                 "physics_qualification", "browser_or_wasm_execution", "pixels_qualified"}


def validate_bundle(document: dict, report: Path, root: Path, current: dict, editor: dict, runtimes: dict) -> dict:
    object_keys(document, REPORT_FIELDS, "current B report")
    for field, expected in (("schema_id", SCHEMA), ("schema_version", 2), ("status", "PASS"),
                            ("mode", "runtime"), ("scope", RUNTIME_SCOPE),
                            ("authority_scopes", proof_scopes.AUTHORITY_SCOPES),
                            ("current_source", current), ("editor", editor), ("runtime", runtimes),
                            ("allowances", ALLOWANCES), ("godot_executed", True),
                            ("ui_behavior_executed", True), ("b_consumer_qualified", True),
                            ("world_executed", False), ("physics_qualification", False),
                            ("browser_or_wasm_execution", False), ("pixels_qualified", False)):
        compare(expected, document[field], "B report " + field)
    if type(document["stages"]) is not list or len(document["stages"]) != len(STAGES):
        raise ValueError("all four legacy/candidate/poison/rollback stages are mandatory")
    oracle_path = root / legacy.FIXTURE
    oracle, oracle_sha = load_json(oracle_path), sha(oracle_path.read_bytes())
    raw_by_stage, raw_facts, summaries, expected_files = {}, {}, [], set()
    for stage, row in zip(STAGES, document["stages"]):
        object_keys(row, ("stage", "source_manifest", "import", "probe", "raw_report"), "B stage")
        compare(stage, row["stage"], "mandatory stage order")
        prefix = report.stem + ".evidence/" + stage
        source_path = evidence_file(row["source_manifest"], report, prefix + ".sources.json")
        manifest = load_json(source_path, 4 * 1024 * 1024)
        compare(stage_manifest(root, stage, current), manifest, stage + " exact tested source map")
        raw_path = evidence_file(row["raw_report"], report, prefix + ".raw.json")
        raw = load_json(raw_path, 8 * 1024 * 1024)
        previous = OTHER_STAGE[stage]
        summaries.append(validate_raw(raw, stage, manifest, oracle, oracle_sha, root,
                                      raw_by_stage.get(previous), raw_facts.get(previous)))
        validate_process(row["import"], report, stage, "import", manifest["source_revision"], None)
        validate_process(row["probe"], report, stage, "probe", manifest["source_revision"], raw)
        raw_by_stage[stage], raw_facts[stage] = raw, sha(raw_path.read_bytes())
        expected_files.update(prefix + suffix for suffix in (".sources.json", ".raw.json", ".import.stdout.log", ".import.stderr.log", ".probe.stdout.log", ".probe.stderr.log"))
    bundle = report.with_name(report.stem + ".evidence")
    actual_files = {path.relative_to(report.parent).as_posix() for path in bundle.rglob("*") if path.is_file()}
    compare(sorted(expected_files), sorted(actual_files), "complete retained evidence inventory")
    for stage in STAGES[1:]:
        compare(ui_projection(raw_by_stage["legacy"]), ui_projection(raw_by_stage[stage], stage == "poison"), stage + " complete old/new UI parity")
    old_identity = raw_by_stage["legacy"]["runtime_identity"]
    candidate_identity = raw_by_stage["candidate"]["runtime_identity"]
    compare(old_identity, raw_by_stage["rollback"]["runtime_identity"], "rollback original apparatus identity")
    if old_identity["script_set_sha256"] == candidate_identity["script_set_sha256"]:
        raise ValueError("old and generated executable source sets must differ")
    compare(summaries, document["results"], "summary versus mandatory raw outcomes")
    return {"status": "PASS", "schema_id": SCHEMA, "schema_version": 2,
            "b_consumer_qualified": True, "scope": RUNTIME_SCOPE, "results": summaries}


def verify(report: Path, root: Path = ROOT, *, godot: Path | None = None, archive: Path | None = None) -> dict:
    report, root = report.absolute(), root.resolve()
    before_report = file_fact(report, report.parent)
    document = load_json(report)
    object_keys(document, REPORT_FIELDS, "current B report")
    compare(SCHEMA, document["schema_id"], "B schema; metadata receipts cannot qualify a display consumer")
    compare(2, document["schema_version"], "B schema version; historical v1 is not current proof")
    current = current_source(root)
    selected_godot = godot or Path(document["editor"]["executable"]["path"])
    selected_archive = archive or Path(document["editor"]["archive"]["path"])
    if not selected_godot.is_absolute():
        selected_godot = root / selected_godot
    if not selected_archive.is_absolute():
        selected_archive = root / selected_archive
    editor = authenticate_editor(selected_godot, selected_archive, root)
    # A reviewer may supply the same authenticated parser bytes at another path.
    for key in ("archive", "executable"):
        if (godot if key == "executable" else archive) is not None:
            editor[key]["path"] = document["editor"][key]["path"]
    retained = [report.with_name(report.stem + ".evidence") / (stage + suffix)
                for stage in STAGES for suffix in (".sources.json", ".raw.json", ".import.stdout.log",
                                                  ".import.stderr.log", ".probe.stdout.log", ".probe.stderr.log")]
    before_evidence = [file_fact(path, report.parent) for path in retained]
    runtimes = runtime_custody(root)
    result = validate_bundle(document, report, root, current, editor, runtimes)
    compare(current, current_source(root), "post-verification current source custody")
    compare(before_report, file_fact(report, report.parent), "post-verification receipt custody")
    compare(before_evidence, [file_fact(path, report.parent) for path in retained], "post-verification raw evidence custody")
    after_editor = authenticate_editor(selected_godot, selected_archive, root)
    for key in ("archive", "executable"):
        if (godot if key == "executable" else archive) is not None:
            after_editor[key]["path"] = document["editor"][key]["path"]
    compare(editor, after_editor, "post-verification actual parser custody")
    compare(runtimes, runtime_custody(root), "post-verification runtime custody")
    for path in (report, *retained):
        no_alias(path)
    return result


def run(godot: Path, archive: Path, output: Path, root: Path = ROOT) -> dict:
    root = root.resolve()
    output, evidence = report_destination(output, root)
    current = current_source(root)
    editor, runtimes = authenticate_editor(godot, archive, root), runtime_custody(root)
    # Claim only a new evidence directory, after all read-only intake succeeds.
    output.parent.mkdir(parents=True, exist_ok=True)
    report_destination(output, root)
    evidence.mkdir()
    rows, raw_by_stage, raw_hashes, results = [], {}, {}, []
    oracle_path = (root / legacy.FIXTURE).resolve()
    oracle, oracle_sha = load_json(oracle_path), sha(oracle_path.read_bytes())
    with tempfile.TemporaryDirectory(prefix="mat353b-display-project-") as temporary:
        scratch = Path(temporary)
        project = scratch / "godot"
        shutil.copytree(root / "godot", project, ignore=shutil.ignore_patterns(".godot", "__pycache__", "*.tmp"))
        (project / PROBE_COPY.removeprefix("godot/")).write_bytes((root / PROBE).read_bytes())
        for stage in STAGES:
            if (project / ".godot").exists():
                shutil.rmtree(project / ".godot")
            for path, data in stage_bytes(root, stage).items():
                destination = project / path.removeprefix("godot/")
                if data is None:
                    destination.unlink(missing_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(data)
            manifest = stage_manifest(root, stage, current)
            check_project_copy(project, manifest)
            source_path = evidence / (stage + ".sources.json")
            new_file(source_path, canonical(manifest))
            operations = {}
            for operation in ("import", "probe"):
                host = scratch / "host" / stage / operation
                environment = {**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1",
                               **{"XDG_" + key.upper() + "_HOME": str(host / key) for key in ("config", "data", "cache")}}
                environment.pop("CYBERSAND_CI_WATCHDOG_SCALE", None)
                command_recipe = recipe(stage, operation, manifest["source_revision"])
                replacements = {"${GODOT}": str(godot.resolve()), "${PROJECT}": str(project),
                                "${ORACLE}": str(oracle_path), "${EVIDENCE}": str(evidence)}
                command = [part for part in command_recipe]
                for key, value in replacements.items():
                    command = [part.replace(key, value) for part in command]
                operations[operation] = process(command, command_recipe, evidence, stage, operation, project, environment)
                check_project_copy(project, manifest)
                if operation == "import":
                    validate_process(operations[operation], output, stage, operation, manifest["source_revision"], None)
            raw_path = evidence / (stage + ".raw.json")
            raw = load_json(raw_path)
            previous = OTHER_STAGE[stage]
            results.append(validate_raw(raw, stage, manifest, oracle, oracle_sha, root,
                                        raw_by_stage.get(previous), raw_hashes.get(previous)))
            validate_process(operations["probe"], output, stage, "probe", manifest["source_revision"], raw)
            raw_by_stage[stage], raw_hashes[stage] = raw, sha(raw_path.read_bytes())
            rows.append({"stage": stage, "source_manifest": file_fact(source_path, output.parent),
                         "raw_report": file_fact(raw_path, output.parent), **operations})
    compare(current, current_source(root), "post-probe current source custody")
    compare(editor, authenticate_editor(godot, archive, root), "post-probe actual parser custody")
    compare(runtimes, runtime_custody(root), "post-probe published runtime custody")
    document = {"schema_id": SCHEMA, "schema_version": 2, "status": "PASS", "mode": "runtime",
                "scope": RUNTIME_SCOPE, "authority_scopes": copy.deepcopy(proof_scopes.AUTHORITY_SCOPES),
                "current_source": current, "editor": editor, "runtime": runtimes,
                "allowances": ALLOWANCES, "stages": rows, "results": results,
                "godot_executed": True, "ui_behavior_executed": True, "b_consumer_qualified": True,
                "world_executed": False, "physics_qualification": False,
                "browser_or_wasm_execution": False, "pixels_qualified": False}
    summary = validate_bundle(document, output, root, current, editor, runtimes)
    publish_report(output, canonical(document))
    return {**summary, "report": str(output)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="static source gate only; no runtime B qualification")
    mode.add_argument("--verify", type=Path, help="verify a current schema-v2 runtime report and every retained raw file")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--output", type=Path, help="NEW runtime report; a NEW sibling .evidence directory is mandatory")
    args = parser.parse_args(argv)
    if bool(args.godot) != bool(args.archive):
        parser.error("--godot and --archive must be supplied together")
    if args.check and any((args.godot, args.archive, args.output)):
        parser.error("--check is nonwriting and cannot take parser/output arguments")
    if args.verify and args.output:
        parser.error("--verify never writes a report")
    if not args.check and not args.verify and not all((args.godot, args.archive, args.output)):
        parser.error("runtime proof requires --godot, --archive and a NEW --output")
    try:
        if args.check:
            result = static_check(args.root)
        elif args.verify:
            result = verify(args.verify, args.root, godot=args.godot, archive=args.archive)
        else:
            result = run(args.godot, args.archive, args.output, args.root)
        print(json.dumps(result, sort_keys=True, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print("display consumer proof: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
