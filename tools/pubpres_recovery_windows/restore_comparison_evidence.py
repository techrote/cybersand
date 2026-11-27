"""Restore the omitted 00478 Windows project inputs and replay its existing Water-off receipt."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SOURCE = "00478f29b9abaccb1e358137e8a9a48894c1690b"
INVENTORY_SHA = "4b64023a0e5d9ee464872a3b8a50b063cd9fd38221880ac2fd7bdb70b3f14959"
MARKER_SHA = "3f2f8926791db77d84f7e269f05765e90af310eeaf98f0946501c94a01a7da47"
ROOT_PATH = Path("D:/a/cybersand/cybersand")
STOCK_PATH = Path("D:/a/_temp/godot/Godot_v4.7-stable_win64.exe")


def need(ok, message):
    if not ok:
        raise ValueError(message)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def file_map(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in folder.rglob("*") if p.is_file()}


@contextmanager
def original_archive_settings():
    # The ordinary Windows stage used autocrlf=true. The font/first-read
    # stage overrides it on its own Git command. Both retained LFS pointers
    # until the two exact Windows libraries were explicitly overlaid.
    count = int(os.environ.get("GIT_CONFIG_COUNT", "0"))
    values = {"GIT_CONFIG_COUNT": str(count + 1), f"GIT_CONFIG_KEY_{count}": "core.autocrlf",
              f"GIT_CONFIG_VALUE_{count}": "true", "GIT_LFS_SKIP_SMUDGE": "1"}
    original = {key: os.environ.get(key) for key in values}
    try:
        os.environ.update(values)
        yield
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def restore_project(source, target, actual, expected):
    need(actual == expected, f"Committed stage differs from complete original map for {target}")
    if target.exists():
        need(file_map(target) == expected, f"Existing replay project differs: {target}")
        return
    # Publish only a complete directory. No raw process, log or receipt is rewritten.
    with tempfile.TemporaryDirectory(dir=target.parent, prefix=".restore-project-") as work:
        staged = Path(work) / "project"
        shutil.copytree(source, staged)
        need(file_map(staged) == expected, f"Project copy changed: {target}")
        staged.rename(target)


def restore_inputs(root, directory, native, ordinary_groups, scratch):
    from run_focus import stage_committed_project
    from run_regressions import stage_source
    from run_graphical_controls import load_font_controls
    font = load_font_controls()
    rapier = read(root / "godot/addons/godot-rapier2d/runtime-provenance.windows.json")
    binary = root / rapier["artifact"]
    need(binary.stat().st_size == rapier["size"] and sha(binary) == rapier["sha256"],
         "Source-bound Windows Rapier bytes differ")
    for name, expected in rapier["source_inputs"].items():
        blob = subprocess.check_output(["git", "-C", str(root), "show", SOURCE + ":" + name])
        need(hashlib.sha256(blob).hexdigest() == expected, "Rapier source input differs: " + name)
    graph = directory / "atomic-font-and-first-read"
    for name in ("stock-safe", "atomic-safe", "atomic-separate"):
        need(file_map(graph / "font-projects" / name) == font.FONT_HASHES, "Retained font project differs: " + name)
    with original_archive_settings():
        ordinary = stage_source(root, SOURCE, scratch / "ordinary")
        template = stage_committed_project(root, SOURCE, scratch / "template")
    for project in (ordinary, template):
        shutil.copyfile(native["binary_path"], project / native["staged_relative_path"])
        shutil.copyfile(binary, project / Path(rapier["artifact"]).relative_to("godot"))
    shutil.copytree(template.parent / "examples/worldgen", template / "authoring/worldgen", dirs_exist_ok=True)
    need(not (template / font.OBSERVER).exists() and not (template / "override.cfg").exists(),
         "Startup observer overlay collision")
    (template / "override.cfg").write_bytes(font.OVERRIDE)
    shutil.copyfile(root / "tools/pubpres_final_windows/owner_start.gd", template / font.OBSERVER)
    custody = read(graph / "template/source-custody.json")
    need(custody["source_commit"] == SOURCE and custody["authored_mutations"] == []
         and custody["rapier"] == rapier and custody["observer_sha256"] == sha(template / font.OBSERVER),
         "Original graphical project custody differs")
    inputs = file_map(ordinary)
    template_inputs = file_map(template)
    # Validate every original inventory before materializing the first project.
    for name in sorted(ordinary_groups):
        need(read(directory / name / "SUMMARY.json")["staged_input_files_sha256"] == inputs,
             "Ordinary staged files differ: " + name)
    need(template_inputs == custody["authored_files_sha256"], "First-read template authored files differ")
    for name in sorted(ordinary_groups):
        restore_project(ordinary, directory / name / "project", inputs, inputs)
    restore_project(template, graph / "template/project", template_inputs, custody["authored_files_sha256"])
    # Successful historical startup arms intentionally removed their private
    # copies. The original replay checks their actual PID, command, receipts
    # and authored input hashes against this template, then adds/removes its
    # own two-slot test overlay. Do not manufacture an import or a launch.
    return {"ordinary_projects": sorted(ordinary_groups), "ordinary_files_per_project": len(inputs),
            "graphical_template_files": len(template_inputs), "retained_font_projects": 3}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("source", "runtime", "correctness", "stock-engine", "atomic-root", "output"):
        parser.add_argument("--" + key, required=True, type=Path)
    args = parser.parse_args()
    root, runtime, directory, stock, atomic, output = (
        p.resolve() for p in (args.source, args.runtime, args.correctness, args.stock_engine, args.atomic_root, args.output))
    need(os.name == "nt" and root == ROOT_PATH and stock == STOCK_PATH
         and directory == root / "build/closure-windows/application" and runtime == root / "build/runtime/C"
         and atomic == root / "build/engine-build02/payload" and output == root / "build/replay-custody/rehydration.json",
         "Use the original recorded Windows workspace, runtime and engine locations")
    need(not output.exists(), "Preserve the existing rehydration result")
    marker = directory / "WATER-OFF-ADMITTED.json"
    need(sha(directory / "INVENTORY.json") == INVENTORY_SHA and sha(marker) == MARKER_SHA,
         "Original comparison inventory or Water-off receipt changed")
    need(subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip() == SOURCE,
         "Original 00478 checkout required")
    # Load readers and stage code from the historical checkout, even when this
    # one transport utility is invoked from a newer workflow checkout.
    sys.path[:0] = [str(root / "tools/pubpres_final_recovery"), str(root / "tools/pubpres_recovery_windows")]
    from identity import driver_identity
    from qualification_gate import NON_WATER_GROUPS, verify_bounded_inventory
    from retained_runtime import build_inputs, validate_runtime
    from run_campaign import source_identity
    from atomic_delivery import verify_payload
    source = source_identity(root)
    driver = driver_identity()
    need(driver == read(directory / "INVENTORY.json")["driver"], "Original execution driver differs")
    native = validate_runtime(root, source, runtime, False)
    need(native["build_commit"] == native["dependency_builder_commit"] == SOURCE
         and "native_input_reuse" not in native, "Use the original resulting-source runtime")
    manifest = read(runtime / "PUBPRES-RUNTIME.json")
    inputs = build_inputs(root, source, manifest)
    need(len(manifest["source_inputs_sha256"]) == native["checked_source_files"] == 110, "Incomplete native input set")
    source["native_runtime"] = native
    build = verify_payload(atomic)
    custom = atomic / build["gui_executable"]
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent, prefix="source-inputs-") as scratch:
        restored = restore_inputs(root, directory, native, NON_WATER_GROUPS - {"atomic-font-and-first-read"}, Path(scratch))
    result = verify_bounded_inventory(marker, source, driver, stock, custom, 0)
    need(result == read(marker), "Original raw Water-off admission differs after rehydration")
    report = {"source": SOURCE, "original_run": "46046627411", "original_attempt": 1,
              "inventory_sha256": INVENTORY_SHA, "water_off_sha256": MARKER_SHA,
              "native_sha256": native["binary_sha256"], "native_checked_inputs": native["checked_source_files"],
              "native_and_build_inputs": len(inputs),
              "stock_engine_sha256": sha(stock), "custom_engine_sha256": sha(custom), **restored,
              "raw_admission_replayed": True, "water_composition": 0}
    with output.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
