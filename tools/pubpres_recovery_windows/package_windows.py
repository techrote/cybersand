#!/usr/bin/env python3
"""Assemble the source-exact Draft/HOLD PUBPRES final Windows evaluator.

The predecessor packer remains unchanged. Its archive, PE, native-build and
dependency-custody routines are reused; this successor has its own manifest,
source set and explicit experimental selectors. No binary is promoted.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import sys
import zipfile
import recovery_policy
import atomic_delivery

ROOT = Path(__file__).resolve().parents[2]
TOOLS = "tools/pubpres_recovery_windows"
LEGACY = "tools/pubpres_playability_windows"
spec = importlib.util.spec_from_file_location("pubpres_frozen_package", ROOT / LEGACY / "package_windows.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
need, digest, write_json = base.need, base.digest, base.write_json
MANIFEST = base.MANIFEST
SCHEMA = "pubpres-playability-recovery-windows-v1"
MISSION = "PUBPRES-PLAYABILITY-FINAL-CLOSURE-001"
DONOR = "c90dbc46e1f57f28e06b1f4205b83467335ff657"
PATCHED_GUI = "Godot-PUBPRES-EGL-4.7.exe"
PATCHED_SHA = "d6a1e5795205eb7968131df55f39916af112f716ec419fce5f97ccb48990fd45"
DEFAULTS = {"source": "C", "engine": "stock", "render_thread": "safe", "material": "full",
            "full_image_slots": 2, "same_frame_continuation": "off", "scene": "ordinary"}
SCENES = {"ordinary", "wave512", "wave1024", "wave2048", "mixed2048"}


def command(candidate: str, scene: str = "ordinary", collector: bool = False, *, mode="Selected", donor=False) -> bytes:
    need(base.COMMIT.fullmatch(candidate) and scene in SCENES, "Unknown exact source or owner scene")
    need(mode in ("Selected","Fallback","Experimental") and (not donor or mode=="Fallback"),"Unknown recovery command selection")
    script = "Collect-Results.ps1" if collector else "Start-PUBPRES-Final.ps1"
    configured=recovery_policy.configuration(recovery_policy.selection(),mode.lower(),'D' if donor else 'C')
    engine_args=f" -Engine {configured['engine'].title()} -RenderThread {configured['render_thread'].title()}"
    args = "" if collector else f" -Action Open -OwnerProfile -Scene {scene} -RecoveryMode {mode}" + (" -Source Donor" if donor else "") + " %adapter%"
    if not collector: args+=engine_args
    # The CMD explicitly launches Windows PowerShell 5.1. PowerShell 7 can
    # otherwise shadow the inbox Utility module (including Get-FileHash).
    lines = ["@echo off", "setlocal", 'set "PSModulePath=%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\Modules"']
    if collector:
        lines += ['echo Collecting Workbench results. Verifying the evaluator and reading matching runs...',
                  'for %%I in ("%~dp0..\\Runs\\Reports") do echo Report folder: "%%~fI"']
    if not collector:
        lines.append('set "adapter="')
        lines.append('if /i "%~1"=="--hosted-smoke" set "adapter=-RenderingDriver opengl3_angle -QuitAfterReady"')
        lines.append('if /i "%~1"=="--headless-smoke" set "adapter=-HeadlessSmoke -QuitAfterReady"')
    lines += ['"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass '
              f'-File "%~dp0tools\\pubpres_recovery_windows\\{script}" -PackageRoot "%~dp0." '
              f'-ExpectedCandidate {candidate}{args}', 'set "result=%errorlevel%"']
    if collector:
        lines += ['if not "%result%"=="0" echo Collection failed with exit code %result%. See the error above.',
                  'if /i not "%~1"=="--hosted-smoke" (',
                  '  echo Press any key to close this window.',
                  '  pause >nul', ')']
    else:
        lines.append('if not "%result%"=="0" if /i not "%~1"=="--hosted-smoke" if /i not "%~1"=="--headless-smoke" pause')
    lines += ['exit /b %result%', ""]
    return "\r\n".join(lines).encode("ascii")


def selected_defaults():
    chosen=recovery_policy.configuration(recovery_policy.selection())
    return dict(DEFAULTS,engine=chosen['engine'],render_thread=chosen['render_thread'])


def engine_restorer():
    spec = importlib.util.spec_from_file_location("pubpres_exact_engine_restore", ROOT / "tools/ci/restore_workbench_godot.py")
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def verify_reciprocal(project: Path) -> None:
    receipt = json.loads((project / "tools/swarm004-runtime.windows.json").read_bytes())
    helper = project / "tools/gentek_reciprocal.exe"
    need(receipt["platform"] == "windows" and receipt["artifact"] == "godot/tools/gentek_reciprocal.exe"
         and receipt["bytes"] == helper.stat().st_size and receipt["sha256"] == digest(helper),
         "Windows reciprocal helper differs from its accepted source binding")
    base.pe_x64(helper)


def qualified_engine(original: Path, packaged: Path) -> Path:
    need(original is not None and original.is_file() and digest(original) == digest(packaged),
         "Packaged engine differs from the executable used for qualification")
    return original.resolve()


def verify_patched(output: Path, record: dict):
    if record is None:
        return
    need(record["root"] == "engines/egl" and record["gui"]["path"] == PATCHED_GUI
         and record["gui"]["sha256"] == PATCHED_SHA and record["default"] is False,
         "Patched engine role or default differs")
    restore = engine_restorer()
    proof = restore.verify_payload(output / "engines/egl")
    _, delivery = restore.locks()
    need(record["artifact"] == delivery and record["version"] == proof["version"]
         and record["provenance_sha256"] == delivery["build_provenance_sha256"]
         and digest(output / PATCHED_GUI) == PATCHED_SHA
         and digest(output / "engines/egl" / proof["gui_executable"]) == PATCHED_SHA,
         "Patched engine original custody or executable copy differs")
    base.pe_x64(output / PATCHED_GUI)


def verify_sources(output: Path, record: dict):
    """The retained independent native/Rapier closure verifier, for C and D."""
    toolchains = []
    for key, source in record["sources"].items():
        need(base.COMMIT.fullmatch(source["source_commit"]) and base.COMMIT.fullmatch(source["source_tree"]), "Incomplete source identity")
        prefix = "sources/" + key
        need(source["root"] == prefix and source["project"] == prefix + "/godot"
             and source["native"]["path"] == prefix + "/" + base.NATIVE
             and source["native"]["receipt"] == prefix + "/provenance/" + base.RUNTIME_RECEIPT
             and source["rapier"]["path"] == prefix + "/" + base.RAPIER
             and source["rapier"]["receipt"] == prefix + "/" + base.RAPIER_RECEIPT, "Cross-source runtime path substitution")
        for runtime in (source["native"], source["rapier"]):
            base.pe_x64(output / base.safe_name(runtime["path"]))
            need(digest(output / runtime["path"]) == runtime["sha256"]
                 and (output / runtime["path"]).stat().st_size == runtime["bytes"], "Runtime bytes differ")
        need(digest(output / source["native"]["receipt"]) == source["native"]["receipt_sha256"], "Native receipt hash differs")
        native = json.loads((output / source["native"]["receipt"]).read_text(encoding="utf-8"))
        need(native["schema"] == "pubpres-playability-native-build-v1" and native["platform"] == "windows"
             and native["returncode"] == 0 and native["source_commit"] == source["source_commit"]
             and native["source_tree"] == source["source_tree"] and native["runtime_file"] == PurePosixPath(base.NATIVE).name
             and native["runtime_sha256"] == source["native"]["sha256"] and native["runtime_bytes"] == source["native"]["bytes"]
             and native["production_runtime_promotion"] is False and native["toolchain_drift_allowed"] is False,
             "Cross-source native receipt substitution or unsupported promotion")
        need(len(native["source_inputs_sha256"]) == source["native"]["source_input_count"], "Incomplete native closure count")
        actual = {p.relative_to(output / prefix).as_posix() for scope in base.SCOPES
                  for p in (output / prefix / scope).rglob("*") if p.is_file() and p.suffix in base.SUFFIXES}
        need(actual and actual == set(native["source_inputs_sha256"]), "Native source closure set differs")
        for name, expected in native["source_inputs_sha256"].items():
            need(base.SHA.fullmatch(expected) and base.canonical_digest((output / prefix / base.safe_name(name)).read_bytes()) == expected,
                 "Packaged native source differs: " + key + "/" + name)
        need(native["build_script"] == "tools/build_native_extension_windows.sh"
             and base.canonical_digest((output / prefix / native["build_script"]).read_bytes()) == native["build_script_sha256"],
             "Packaged build script differs")
        need(digest(output / prefix / "provenance/build.log") == native["log_sha256"], "Packaged build log differs")
        need(digest(output / base.BUILD_DRIVER) == native["driver_sha256"], "Exact native build driver differs")
        dependency = base.dependency_custody.verify(output / prefix / "provenance", native)
        need(dependency["builder_commit"] == record["candidate_commit"], "Dependency builder does not identify this candidate")
        base.dependency_custody.verify_driver((output / base.BUILD_DRIVER).parent, native)
        toolchain = {name: native[name] for name in ("godot_cpp_commit", "godot_cpp_library_sha256", "godot_cpp_dependency_sha256",
                                                   "compiler_command", "compiler_version", "toolchain_drift_allowed")}
        need(toolchain == source["toolchain"] and base.COMMIT.fullmatch(native["godot_cpp_commit"])
             and base.SHA.fullmatch(native["godot_cpp_library_sha256"]) and native["compiler_command"] and native["compiler_version"],
             "Toolchain identity is incomplete or inconsistent")
        rapier = json.loads((output / source["rapier"]["receipt"]).read_text(encoding="utf-8"))
        need(rapier["artifact"] == base.RAPIER and rapier["sha256"] == source["rapier"]["sha256"]
             and rapier["size"] == source["rapier"]["bytes"] and rapier.get("source_inputs"), "Retained Rapier identity differs")
        for name, expected in rapier["source_inputs"].items():
            need(base.SHA.fullmatch(expected) and base.canonical_digest((output / prefix / base.safe_name(name)).read_bytes()) == expected,
                 "Retained Rapier source differs")
        derived = json.loads((output / prefix / base.NATIVE_RECEIPT).read_text(encoding="utf-8"))
        need(derived["source_commit"] == source["source_commit"] and derived["sha256"] == native["runtime_sha256"]
             and derived["source_inputs"] == native["source_inputs_sha256"] and derived["build_receipt"] == source["native"]["receipt"]
             and derived["build_receipt_sha256"] == source["native"]["receipt_sha256"] and derived["production_runtime_promotion"] is False,
             "Runtime observation would read stale provenance")
        need(source["features"] == base.source_features(key), "Unsupported feature advertisement")
        toolchains.append(toolchain)
    need(all(value == toolchains[0] for value in toolchains), "Comparison native toolchains differ")


def verify(output: Path, candidate: str) -> dict:
    output = Path(output)
    record = json.loads((output / MANIFEST).read_text(encoding="utf-8"))
    need(base.COMMIT.fullmatch(candidate) and record["schema"] == SCHEMA and record["mission"] == MISSION
         and record["candidate_commit"] == candidate and record["physical_acceptance"] == "HOLD"
         and record["production_defaults_changed"] is False and record["defaults"] == selected_defaults(), "Final package identity/default/HOLD differs")
    need(record["package_filename"] == f"CyberSand-{MISSION}-{candidate[:12]}-Windows.zip", "Package filename differs")
    need(record.get('patched_engine') is None,'Recovery stock selection cannot include an unqualified optional engine')
    need((output / (MANIFEST + ".sha256")).read_text(encoding="ascii") == f"{digest(output / MANIFEST)}  {MANIFEST}\n", "Manifest checksum differs")
    inventory = record["files_sha256"]
    need(inventory and len(inventory) == record["file_count"] <= 30000
         and len({name.casefold() for name in inventory}) == len(inventory), "Invalid inventory")
    need(base.file_hashes(output) == inventory, "Package has missing, changed or unexpected files")
    need(set(record["sources"]) in ({"C"}, {"C", "D"}) and record["sources"]["C"]["source_commit"] == candidate, "Source roles differ")
    if "D" in record["sources"]:
        need(record["sources"]["D"]["source_commit"] == DONOR, "Frozen donor differs")
    verify_sources(output, record)
    engine = record["engine"]
    need(engine["version"] == base.GODOT_VERSION and engine["archive_sha512"] == base.GODOT_SHA512, "Stock engine pin differs")
    for role, name in (("gui", base.GUI), ("console", base.CONSOLE)):
        need(engine[role] == {"path": name, "sha256": base.GODOT_EXECUTABLE_SHA256[name]}, "Stock engine role/hash differs")
        base.pe_x64(output / name)
    vc = json.loads((output / "vc-runtime-provenance.json").read_text(encoding="utf-8-sig"))
    need(vc["schema"] == 1 and set(vc["files_sha256"]) == base.VC_FILES
         and vc["authenticode"]["status"] == "Valid", "Signed VC runtime custody differs")
    for name, expected in vc["files_sha256"].items():
        need(digest(output / name) == expected, "VC runtime/licence changed")
    need(engine["vc_runtime_sha256"] == digest(output / "vcruntime140.dll"), "VC engine binding differs")
    need(record["owner_launcher"] == TOOLS + "/Start-PUBPRES-Final.ps1"
         and record["owner_observer"] == TOOLS + "/owner_start.gd"
         and record["owner_results_collector"] == TOOLS + "/Collect-Results.ps1", "Owner entrypoint differs")
    for name, scene in record["owner_commands"].items():
        need((output / base.safe_name(name)).read_bytes() == command(candidate, scene), "Owner command differs")
    need(record["owner_commands"] == {"Open Workbench.cmd": "ordinary", "Open Wave 512.cmd": "wave512",
         "Open Wave 1024.cmd": "wave1024", "Open Wave 2048.cmd": "wave2048", "Open Mixed 2048.cmd": "mixed2048"}, "Scene command set differs")
    need((output / "Collect Results.cmd").read_bytes() == command(candidate, collector=True), "Collector command differs")
    configured=recovery_policy.selection(output/TOOLS/recovery_policy.SELECTION)
    need(record.get('recovery_selection')==configured and configured==recovery_policy.selection()
         and record.get('recovery_selection_sha256')==digest(output/TOOLS/recovery_policy.SELECTION),
         'Source-pinned recovery owner selection differs')
    comparisons=recovery_policy.scene_comparison_commands(configured)
    need(record.get('comparison_commands')==comparisons,'Matched scene comparison command inventory differs')
    for name,value in comparisons.items():
        need((output/name).read_bytes()==command(candidate,value['scene'],mode=value['mode']),
             'Matched scene comparison command differs')
    if recovery_policy.requires_atomic(configured):
        atomic_delivery.verify(output,record.get('atomic_engine'),selected=configured['architecture']!='stock_safe')
    else:
        need(record.get('atomic_engine') is None,'Unregistered optional atomic engine')
    need((output/recovery_policy.FALLBACK_COMMAND).read_bytes()==command(candidate,mode='Fallback'),
         'Stock Safe fallback command differs')
    if 'D' in record['sources']:
        need((output/recovery_policy.DONOR_COMMAND).read_bytes()==command(candidate,mode='Fallback',donor=True),
             'Frozen control command differs')
    if configured['experimental_architecture']!='none':
        need((output/recovery_policy.EXPERIMENTAL_COMMAND).read_bytes()==command(candidate,mode='Experimental'),
             'Explicit bounded experimental command differs')
    else:
        need(not (output/recovery_policy.EXPERIMENTAL_COMMAND).exists(),'Unregistered experimental launcher')
        need(not any((output/f'Open {name} - Bounded Experimental.cmd').exists() for name in recovery_policy.SCENE_NAMES),
             'Unregistered experimental scene launcher')
    gate=json.loads((output/'qualification/recovery-correctness.json').read_bytes())
    need(gate.get('schema')=='pubpres-recovery-owner-correctness-v1' and gate.get('source_commit')==candidate
         and gate.get('source_tree')==record['sources']['C']['source_tree'] and gate.get('selection')==configured
         and gate.get('engine_sha256')==engine['gui']['sha256']
         and gate.get('native_sha256')==record['sources']['C']['native']['sha256']
         and gate.get('physical_acceptance')=='HOLD' and gate.get('stock',{}).get('outcomes')==19
         and gate['stock'].get('raw_inputs_and_supplemental_replayed') is True
         and gate.get('members',{}).get('outcomes')==4 and gate['members'].get('raw_inputs_and_supplemental_replayed') is True
         and gate.get('native_owner',{}).get('checks')==150 and gate['native_owner'].get('raw_inputs_and_native_receipt_replayed') is True
         and ((configured['water_composition']==0 and gate.get('water') is None)
              or (configured['water_composition']==1 and gate.get('water',{}).get('outcomes')==4
                  and gate['water'].get('raw_inputs_and_supplemental_replayed') is True)),
         'Selected recovery configuration lacks resulting-source graphical correctness custody')
    if recovery_policy.requires_atomic(configured):
        atomic_delivery.verify_gate(gate.get('atomic'),record['atomic_engine'],candidate,record['sources']['C'],
            bool(configured['water_composition']),safe_water=bool(configured['water_composition']) and configured['architecture']=='atomic_safe0')
    else: need(gate.get('atomic') is None,'Stock-only package cannot claim atomic qualification')
    need(digest(output / "ACCEPTANCE.md") == digest(output / TOOLS / "ACCEPTANCE.md"), "Owner acceptance instructions differ")
    registration = json.loads((output / "tools/pubpres_final/registration.json").read_text())
    need(registration["schema"] == "pubpres-playability-final-registration-v1"
         and registration["predecessor"]["source"] == DONOR, "Qualification registration differs")
    verify_patched(output, record["patched_engine"])
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidate-root", "candidate-runtime", "donor-root", "donor-runtime", "godot-zip", "vc-runtime", "notices", "archive", "patched-engine-archive", "stock-correctness", "water-correctness", "members-correctness", "native-correctness", "atomic-engine-directory", "atomic-inventory", "qualified-stock-engine"):
        parser.add_argument("--" + name, type=Path)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if args.verify:
        result = verify(output, args.candidate_sha)
        print(json.dumps({"verified_files": result["file_count"], "candidate": args.candidate_sha, "physical_acceptance": "HOLD"}))
        return
    need(os.name == "nt", "Build the evaluator on actual Windows")
    need(args.patched_engine_archive is None,'Recovery stock selection cannot include an unqualified optional engine')
    need(all(getattr(args, name) for name in ("candidate_root", "candidate_runtime", "godot_zip", "vc_runtime", "notices", "archive")), "Supply source/runtime and dependency stages")
    need(bool(args.donor_root) == bool(args.donor_runtime), "Supply both frozen donor inputs or neither")
    root, archive = args.candidate_root.resolve(), args.archive.resolve()
    need(base.COMMIT.fullmatch(args.candidate_sha) and archive.name == f"CyberSand-{MISSION}-{args.candidate_sha[:12]}-Windows.zip", "Use the exact source filename")
    need(not any(path.exists() for path in (output, archive, Path(str(archive)+".sha256"), Path(str(archive)+".json")))
         and output not in archive.parents, "Output and sidecars must be fresh, archive outside payload")
    packer_inputs=[path.relative_to(ROOT).as_posix() for path in (ROOT/TOOLS).glob('*.py')]
    for name in [*packer_inputs,LEGACY + "/package_windows.py"]:
        need(base.canonical_digest((ROOT / name).read_bytes()) == base.canonical_digest(base.committed(root, args.candidate_sha, name)), "Packer source differs: " + name)
    output.mkdir(parents=True)
    sources = {"C": base.stage_project(root, args.candidate_sha, "C", args.candidate_runtime, output, MISSION)}
    # The shared source projection materializes both platform companions. Only
    # the admitted Windows helper and its Windows receipt ship in this package.
    project = output / sources["C"]["project"]
    for linux_only in ("tools/gentek_reciprocal", "tools/swarm004-runtime.linux.json"):
        (project / linux_only).unlink()
    verify_reciprocal(project)
    if args.donor_root:
        base.git(root, "merge-base", "--is-ancestor", DONOR, args.candidate_sha)
        sources["D"] = base.stage_project(args.donor_root, DONOR, "D", args.donor_runtime, output, MISSION)
    paths = [TOOLS, LEGACY, "tools/pubpres_playability_build", "tools/pubpres_final/registration.json",
             "tools/ci/restore_workbench_godot.py", "tools/ci/build_workbench_godot.py",
             "third_party/workbench-godot.lock.json", "third_party/workbench-godot-evaluation.lock.json",
             "third_party/patches/godot-egl-current-window.patch"]
    base.archive_source(root, args.candidate_sha, output, paths)
    engine = base.stage_dependencies(output, args.godot_zip, args.vc_runtime, args.notices)
    configured=recovery_policy.selection()
    atomic=None
    if recovery_policy.requires_atomic(configured):
        need(args.atomic_engine_directory is not None and args.atomic_inventory is not None,
             'Registered atomic configuration lacks exact engine and actual Windows application evidence')
        atomic=atomic_delivery.stage(args.atomic_engine_directory.resolve(),output,selected=configured['architecture']!='stock_safe')
    else:
        need(args.atomic_engine_directory is None and args.atomic_inventory is None,'Stock-only package cannot carry unregistered atomic inputs')
    need(args.stock_correctness is not None,'Recovery evaluator requires retained actual Windows correctness')
    # Process evidence is path-bound to the executable that actually ran.
    # Replaying it with the staged duplicate would misidentify that process.
    stock_engine = qualified_engine(args.qualified_stock_engine, output / engine["gui"]["path"])
    gate=recovery_policy.qualify(root,args.candidate_runtime.resolve(),stock_engine,
        args.stock_correctness,args.water_correctness,members_summary=args.members_correctness,native_summary=args.native_correctness,
        atomic_root=None if atomic is None else args.atomic_engine_directory.resolve(),
        atomic_inventory=args.atomic_inventory)
    qualification = output / 'qualification'
    qualification.mkdir()
    write_json(qualification / 'recovery-correctness.json', gate)
    patched = None
    if args.patched_engine_archive:
        restore = engine_restorer()
        restored = restore.restore(args.patched_engine_archive, output / "engines/egl")
        proof = restore.verify_payload(output / "engines/egl")
        # Keep the recovered artifact byte-for-byte. The separately declared
        # executable copy sits beside the signed VC dependency used by Rapier.
        shutil.copyfile(output / "engines/egl" / proof["gui_executable"], output / PATCHED_GUI)
        patched = {"root": "engines/egl", "gui": {"path": PATCHED_GUI, "sha256": PATCHED_SHA}, "default": False,
                   "version": proof["version"], "artifact": restored["artifact"],
                   "provenance_sha256": restored["artifact"]["build_provenance_sha256"]}
    commands = {"Open Workbench.cmd": "ordinary", "Open Wave 512.cmd": "wave512", "Open Wave 1024.cmd": "wave1024",
                "Open Wave 2048.cmd": "wave2048", "Open Mixed 2048.cmd": "mixed2048"}
    for name, scene in commands.items():
        (output / name).write_bytes(command(args.candidate_sha, scene))
    (output / "Collect Results.cmd").write_bytes(command(args.candidate_sha, collector=True))
    (output/recovery_policy.FALLBACK_COMMAND).write_bytes(command(args.candidate_sha,mode='Fallback'))
    if 'D' in sources:
        (output/recovery_policy.DONOR_COMMAND).write_bytes(command(args.candidate_sha,mode='Fallback',donor=True))
    if configured['experimental_architecture']!='none':
        (output/recovery_policy.EXPERIMENTAL_COMMAND).write_bytes(command(args.candidate_sha,mode='Experimental'))
    comparisons=recovery_policy.scene_comparison_commands(configured)
    for name,value in comparisons.items():
        (output/name).write_bytes(command(args.candidate_sha,value['scene'],mode=value['mode']))
    shutil.copyfile(output / TOOLS / "README.md", output / "READ-ME.md")
    shutil.copyfile(output / TOOLS / "ACCEPTANCE.md", output / "ACCEPTANCE.md")
    record = {"schema": SCHEMA, "mission": MISSION, "candidate_commit": args.candidate_sha,
              "package_filename": archive.name, "sources": sources, "engine": engine, "patched_engine": patched,"atomic_engine":atomic,
              "defaults": selected_defaults(), "owner_commands": commands, "comparison_commands":comparisons,"owner_launcher": TOOLS + "/Start-PUBPRES-Final.ps1",
              "owner_observer": TOOLS + "/owner_start.gd", "owner_results_collector": TOOLS + "/Collect-Results.ps1",
              "physical_acceptance": "HOLD", "production_defaults_changed": False,
              "recovery_selection":recovery_policy.selection(),
              "recovery_selection_sha256":digest(output/TOOLS/recovery_policy.SELECTION),
              "scope": "Ordinary interactive evaluator; startup, source and material qualification do not establish physical Windows/NVIDIA playability."}
    record["files_sha256"] = base.file_hashes(output)
    record["file_count"] = len(record["files_sha256"])
    write_json(output / MANIFEST, record)
    (output / (MANIFEST + ".sha256")).write_text(f"{digest(output / MANIFEST)}  {MANIFEST}\n", encoding="ascii")
    verify(output, args.candidate_sha)
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for name in sorted([*record["files_sha256"], MANIFEST, MANIFEST + ".sha256"]):
            bundle.write(output / base.safe_name(name), name)
    with zipfile.ZipFile(archive) as bundle:
        need(bundle.testzip() is None, "ZIP CRC failed")
    checksum = digest(archive)
    Path(str(archive)+".sha256").write_text(f"{checksum}  {archive.name}\n", encoding="ascii")
    write_json(Path(str(archive)+".json"), {"schema": SCHEMA, "candidate_commit": args.candidate_sha,
               "archive_sha256": checksum, "archive_bytes": archive.stat().st_size,
               "manifest_sha256": digest(output / MANIFEST), "physical_acceptance": "HOLD"})
    print(f"{checksum}  {archive.name}")


if __name__ == "__main__":
    main()
