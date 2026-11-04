"""Narrow current B import admission; this is source proof, not UI execution.

The accepted native/Godot executable and routing sources are authenticated
through a separately pinned current-main Git baseline. The legacy display
oracle and the 27-owner compatibility authority retain their historical
baselines. Only the one
Main method/preload and one apparatus source entry may change in this bounded
checkpoint. Thus a renamed copy, extra alias or dynamically assembled indirect
import cannot become a second consumer by evading a filename search. A later
integration changes this explicit admission after review, never the 27 A locks.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess

import legacy_display_names as legacy
import presentation

ROOT = Path(__file__).resolve().parents[2]
# Accepted #374, #377 and #390 integrations: ordinary source, never path exemptions.
# This is distinct from legacy.BASELINE and compatibility.BASELINE.
B_ADMISSION_BASELINE = "751edc0b495dc85484ad5509a7c95f863651c76b"
B_ADMISSION_TREE = "b0d42a256285e6049a6d3bdd1613d7ecd89f43c6"
RESOURCE = "godot/scripts/generated/material_ui_names.gd"
MAIN = "godot/scripts/main.gd"
IDENTITY = "godot/scripts/microscenario_identity.gd"
PRELOAD = 'const MaterialUiNames = preload("res://scripts/generated/material_ui_names.gd")\n'
METHOD = '''func material_name(material_id: int) -> String:
\tif material_id >= 0 and material_id < MaterialUiNames.NAMES.size() and material_id != 10:
\t\treturn MaterialUiNames.NAMES[material_id]
\treturn "material-%d" % material_id
'''
IDENTITY_NEEDLE = '\t"scripts/web_demo_controller.gd",\n'
IDENTITY_ENTRY = '\t"scripts/generated/material_ui_names.gd",\n'
EXECUTABLE_SUFFIXES = {".gd", ".tscn", ".tres", ".godot", ".gdshader", ".gdextension", ".cfg",
                       ".h", ".hh", ".hpp", ".hxx", ".c", ".cc", ".cpp", ".cxx", ".inc"}
EXECUTABLE_ROOTS = ("godot", "native")


def _lf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n")


def _blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def script_inventory(repository: Path = ROOT) -> dict[str, str]:
    tree = subprocess.run(["git", "-C", str(repository), "rev-parse", B_ADMISSION_BASELINE + "^{tree}"],
                          check=True, capture_output=True, text=True, timeout=30).stdout.strip()
    if tree != B_ADMISSION_TREE:
        raise ValueError("B admission tree differs from the reviewed accepted source")
    raw = subprocess.run(["git", "-C", str(repository), "ls-tree", "-rz", B_ADMISSION_BASELINE,
                          "--", *EXECUTABLE_ROOTS], check=True, capture_output=True, timeout=30).stdout
    result = {}
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        meta, path = entry.split(b"\t", 1)
        mode, kind, digest = meta.split()
        name = path.decode("utf-8")
        if Path(name).suffix in EXECUTABLE_SUFFIXES and ".godot" not in Path(name).parts:
            if mode != b"100644" or kind != b"blob":
                raise ValueError("unapproved production script type: " + name)
            result[name] = digest.decode("ascii")
    if MAIN not in result or IDENTITY not in result or RESOURCE in result:
        raise ValueError("accepted B executable source inventory is incomplete")
    return result


def check(root: Path = ROOT, baseline_repository: Path = ROOT) -> dict:
    root = root.resolve()
    generated = presentation.check(root)
    # Full old return table is authenticated independently of presentation.
    legacy.check(root, baseline_repository)
    accepted = script_inventory(baseline_repository)
    # #374/#377/#390 change neither pre-cutover Main nor the apparatus source list.
    # Authenticate that premise independently; a later Main/routing transition
    # cannot be admitted merely by moving the executable inventory baseline.
    for name in (MAIN, IDENTITY):
        if _blob_sha(_lf(legacy.git_bytes(baseline_repository, name))) != accepted[name]:
            raise ValueError(name + ": B admission baseline differs from frozen legacy display source; separate consumer transition required")
    old_main = _lf(legacy.git_bytes(baseline_repository, MAIN)).decode("utf-8")
    old_method = legacy.function(old_main, "material_name")
    expected_main = old_main.replace("extends Control\n", "extends Control\n\n" + PRELOAD, 1)
    expected_main = expected_main.replace(old_method, METHOD, 1)
    actual_main = _lf((root / MAIN).read_bytes()).decode("utf-8")
    if actual_main != expected_main:
        raise ValueError("main.gd: only the declared MaterialUiNames preload and material_name consumer are admitted; alias/second use/legacy fallback or unrelated drift refused")
    old_identity = _lf(legacy.git_bytes(baseline_repository, IDENTITY)).decode("utf-8")
    if old_identity.count(IDENTITY_NEEDLE) != 1:
        raise ValueError("legacy apparatus source-list anchor changed")
    expected_identity = old_identity.replace(IDENTITY_NEEDLE, IDENTITY_NEEDLE + IDENTITY_ENTRY)
    if _lf((root / IDENTITY).read_bytes()).decode("utf-8") != expected_identity:
        raise ValueError("microscenario_identity.gd: expected only the admitted executable resource entry; stale source fingerprint refused")
    current = {p.relative_to(root).as_posix(): p for tree in EXECUTABLE_ROOTS for p in (root / tree).rglob("*")
               if p.is_file() and p.suffix in EXECUTABLE_SUFFIXES and
               ".godot" not in p.relative_to(root).parts}
    if set(current) != set(accepted) | {RESOURCE}:
        raise ValueError("unapproved executable source inventory; missing=%s extra=%s (second consumers/renamed resources are not admitted)" %
                         (sorted((set(accepted) | {RESOURCE}) - set(current)),
                          sorted(set(current) - (set(accepted) | {RESOURCE}))))
    facts = []
    for name, path in sorted(current.items()):
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise ValueError("executable source aliases are not admitted: " + name)
        data = _lf(path.read_bytes())
        if name not in {MAIN, IDENTITY, RESOURCE} and _blob_sha(data) != accepted[name]:
            raise ValueError(name + ": executable source drift outside the single B consumer; indirect/alias imports require separate admission")
        facts.append({"path": name, "lf_bytes": len(data), "lf_sha256": hashlib.sha256(data).hexdigest()})
    inventory_bytes = json.dumps(facts, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {"status": "PASS", "consumer": "godot/scripts/main.gd::material_name",
            "resource": RESOURCE, "admission_source_commit": B_ADMISSION_BASELINE,
            "admission_source_tree": B_ADMISSION_TREE,
            "legacy_display_oracle_commit": legacy.BASELINE,
            "legacy_display_oracle_tree": legacy.BASELINE_TREE,
            "generated_artifacts": generated["artifacts"],
            "executable_source_count": len(facts),
            "executable_source_inventory_sha256": hashlib.sha256(inventory_bytes).hexdigest(),
            "other_executable_sources_match_accepted_git": True,
            "runtime_execution": False, "b_consumer_report_required": True}
