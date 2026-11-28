#!/usr/bin/env python3
"""Seal, verify and execute the integrated portable Windows Workbench.

Package identity is read independently from Git and every original platform
campaign. Cold CMD observation reuses the retained Strata process observer but
has a separate reader bound to this actual application, never its frozen donor.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import ntpath
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
import ramcache_strata_qualification as q
import strata3_cold_launcher as cold
import package_strata2_workbench as base
from package_explore001_candidate import stage_generator_profiles, verify_vc_runtime
from package_wave_flow_candidate import archive_environment, omit_regenerated_imports, REGENERATED_RAPIER_IMPORTS
from package_workbench_landscape_review import DEPENDENCIES

require, sha, write_json = q.require, q.sha, q.write_json
MANIFEST = "evaluation-manifest.json"
ARCHIVE_INPUTS = ["godot", "examples/worldgen", "third_party", "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md",
    "tools/ci/ramcache_strata_qualification.py", "tools/package_ramcache_strata.py",
    "docs/operations/persistent-area-ramcache-evaluation.md", "docs/operations/strata-optics-evaluation.md",
    "docs/operations/strata-optical-composition.md", "docs/systems/strata-optics.md",
    "docs/systems/strata-authoring.md", "docs/systems/strata-workbench.md",
    "docs/operations/ramcache-strata-integration.md"]
MATERIALIZED = {
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
    "godot/tools/gentek_reciprocal.exe",
}
OMITTED_PLATFORM = {"godot/tools/gentek_reciprocal", "godot/tools/swarm004-runtime.linux.json"}
MAXIMUM_UNCOMPRESSED_BYTES = 2 * 1024**3


def payload(folder: Path) -> dict:
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p != folder / MANIFEST}


def safe_name(name: str) -> str:
    cold.relative(name)
    return name


def persistent_launcher(source: dict) -> str:
    ordinary = base.launcher_text(source)
    require(ordinary.count("-- --workbench\n") == 1, "Ordinary portable host argument is ambiguous")
    # Both routes use the application's same default user:// profile. An
    # explicit shortcut-only profile would split the owner's durable areas.
    return ordinary.replace("-- --workbench\n", "-- --persistent-areas\n")


def original_inventory(runtime: dict) -> tuple[dict, dict]:
    items = q.custody.git("ls-tree", "-rz", "HEAD", "--", *ARCHIVE_INPUTS)
    original, omitted = {}, {}
    for entry in items.split(b"\0"):
        if not entry:
            continue
        metadata, raw = entry.split(b"\t", 1)
        mode, kind, oid = metadata.decode().split()
        name = safe_name(raw.decode())
        require(kind == "blob" and mode in ("100644", "100755"), "Linked source file refused")
        if name.startswith("godot/.godot/") or name in OMITTED_PLATFORM:
            continue
        if "/bin/" in name and name not in MATERIALIZED:
            continue
        if name in REGENERATED_RAPIER_IMPORTS:
            omitted[name] = REGENERATED_RAPIER_IMPORTS[name]
        original[name] = oid
    require(MATERIALIZED <= set(original), "Missing committed native, Rapier or SWARM runtime")
    return original, omitted


def materialized_identity(name: str) -> dict:
    raw = q.custody.git("show", "HEAD:" + name).decode()
    match = re.fullmatch(r"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", raw)
    require(match is not None, "Runtime is not an exact committed LFS identity")
    return {"sha256": match[1], "size": int(match[2])}


def owner_text(source: dict) -> str:
    return f'''# CyberSand — integrated RAMCACHE and Strata Theatre 003

Application: `{source["source_commit"]}`

Git tree: `{source["source_tree"]}`

Extract this entire ZIP into a writable folder and double-click **Open Workbench.cmd**.
Godot, the source-matched CyberSand extension, Rapier and the SWARM generator are included.
The first opening imports the project and may take longer. Saved profiles and settings
stay in this package's `userdata` folder. Keep that folder when moving your installation.
Use **Verify Package.cmd** to check the original payload hashes with Windows PowerShell.

## Ordinary Workbench and defaults

The normal launcher opens the ordinary Workbench. Strata starts disabled and **Classic**
is the optical default. Classic does not allocate enhanced-optics shader materials.
Persistent-area operation is a separate opt-in host. Existing ordinary authoring,
actors, Water, AMBIENT, Goblin, Materials Lab/Audition, Art, Architecture, Gentek and
SWARM remain available through their established controls. ObjectShard M4 is excluded.

## Persistent areas and RAMCACHE

Double-click **Open Persistent Areas.cmd**, or press **F2** and select **Persistent
areas — experimental three-area Workbench, saved dynamics and bounded catch-up**.
Both routes reopen the same package-local persistent-area profile.
Open **RAM cache…**. Initial settings are 512 MiB, strict durability, background saving
on and prefetch off. To use the owner-accepted optional path, select **Allow travel
before disk saving finishes**, then **Apply cache settings**. For hover preparation,
also select **Prepare likely destinations before travel** and **Apply cache settings**.
Hover a destination to request preparation; travel to it using the area's button. Use **Save all areas**
and wait for durable acknowledgement before closing. Complete shutdown
and reopening retain authored edits and evolved state. Deferred travel remains optional.

The accepted Waterworks delay remains: roughly 3.2 seconds on the owner's previous
Windows/TITAN evaluation, even while paused. This package does not replace catch-up
scheduling. HOT preparation remains bounded to 2 ticks or 5 ms per pass; WARM/COLD to
32 ticks or 100 ms, with automatic prediction considered about once a second.

## Strata and the owner's reproducible preference

In the ordinary Workbench toolbar, open **Strata Theatre…**, then **Scenes**.
Select **Underworks / Reactor Service** and click **Load selected example…**.
In **Optics**, select **Diorama** in the profile dropdown under **Enable optical
processing**. Scroll to **Per-plane composition**, select **Rear architecture**,
and set **Optical depth** to **1.3**. This is a reproducible artistic preference,
not the global default. **Save start** stores authored composition/optics; named
presets store reusable optical configurations. Temporary bypass, Show physical Play,
wipe and inspection focus stay separate. Application quality is a separate preference.

Strata and persistent-area hosting are deliberately separate. Trying Strata in a
persistent-area profile visibly refuses without allocating another World or changing
the current area. Return to the ordinary Workbench to use layered authoring.

## Qualification and accepted limits

The owner accepted the two preceding evaluator builds on Windows 11/NVIDIA TITAN RTX.
This combined archive receives fresh hosted Linux/Windows and extracted-Windows
qualification; it has not been physically retested on that GPU.

Optional enhanced optics retain their documented cost. The owner's 90% Classic-speed
gate waiver applies only to optional profiles. Original extracted Strata measurements
remain: Deep Focus 80.59%, Architectural 78.26%, Gameplay Clarity 75.68%, Diorama High 73.49%.
Those are historical measurements, not new performance results for this archive.
Classic stays default; correctness, source identity and regression gates are not waived.
Bright-daylight readability and camera rotation retain their previous qualification limits.
Actor reveal assists cover at most eight actors and the first 64 composed parts per
actor. Larger compositions remain visible, but parts beyond that bound do not receive
this optional optical assistance.

`evaluation-manifest.json` records the application, original native build source,
exact runtime hashes, six source-campaign identities, package input blobs and every
payload hash. `qualification` contains the source-campaign summaries; full original
execution evidence is retained in the linked workflow artifacts.
The complete combined operating guide is `docs/operations/ramcache-strata-integration.md`.
'''


VERIFY_PS1 = r'''$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $root 'evaluation-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'ramcache-strata-workbench-evaluation-v1') { throw 'Wrong evaluator manifest' }
$count = 0
foreach ($property in $manifest.files_sha256.PSObject.Properties) {
    $name = $property.Name
    if ($name -match '(^/|\\|(^|/)\.\.(/|$)|:)' -or !$name) { throw 'Unsafe manifest path' }
    $path = Join-Path $root $name
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Missing payload: ' + $name) }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $property.Value) {
        throw ('Changed payload: ' + $name)
    }
    $count += 1
}
if ($count -lt 100) { throw 'Incomplete payload inventory' }
Write-Host ('Verified ' + $count + ' original payload files. Application ' + $manifest.source_commit)
'''
VERIFY_CMD = '@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify Package.ps1"\r\npause\r\n'


def verify(folder: Path, *, pristine=False) -> dict:
    folder = folder.resolve(strict=True)
    record = q.read(folder / MANIFEST)
    source = q.identity()
    runtime = q.strata.retained_runtime_manifest("win32")
    require(record.get("schema") == "ramcache-strata-workbench-evaluation-v1"
            and record.get("source_identity") == source
            and record.get("source_commit") == source["source_commit"] and record.get("source_tree") == source["source_tree"]
            and record.get("runtime") == runtime and record.get("native_reuse") == q.native_reuse()
            and record.get("classic_default") is True and record.get("objectshard_m4_included") is False,
            "Evaluator source/runtime/default identity differs from qualified application")
    original, omitted = original_inventory(runtime)
    require(record.get("archived_git_blobs") == {k: v for k, v in original.items() if k not in omitted}
            and record.get("regenerated_imports_sha256") == omitted, "Package source inventory differs from Git")
    names = record.get("files_sha256")
    require(isinstance(names, dict) and names and len(names) == len({n.casefold() for n in names}),
            "Missing/ambiguous payload inventory")
    for name, digest in names.items():
        path = folder / safe_name(name)
        require(path.is_file() and not path.is_symlink() and sha(path) == digest, "Changed/missing payload: " + name)
    for name, oid in record["archived_git_blobs"].items():
        data = (folder / name).read_bytes()
        if name in MATERIALIZED:
            expected = materialized_identity(name)
            require(len(data) == expected["size"] and hashlib.sha256(data).hexdigest() == expected["sha256"],
                    "Materialized runtime differs from committed pointer")
        else:
            require(hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == oid,
                    "Archived source differs directly from Git: " + name)
    q.custody.project_identity(folder / "godot", source, runtime)
    q.strata.project_assets_identity(folder / "godot", source)
    base.verify_generator_profiles(folder, record, set(record["archived_git_blobs"]), names)
    require((folder / "Open Workbench.cmd").read_text(encoding="utf-8") == base.launcher_text(source),
            "Shipped ordinary launcher changed")
    require((folder / "Open Persistent Areas.cmd").read_text(encoding="utf-8") == persistent_launcher(source),
            "Shipped persistent-area launcher differs from the established source contract")
    require((folder / "Verify Package.ps1").read_text(encoding="utf-8") == VERIFY_PS1
            and (folder / "Verify Package.cmd").read_bytes() == VERIFY_CMD.encode(), "Payload verifier changed")
    require((folder / "READ-ME.md").read_text(encoding="utf-8") == owner_text(source), "Owner guidance differs from source")
    for name, digest in DEPENDENCIES.items():
        require(names.get(name) == digest, "Portable dependency pin changed: " + name)
    verify_vc_runtime(folder)
    require(names.get(cold.GUI) == q.strata.GODOT_GUI_SHA256 and names.get(cold.CONSOLE) == q.strata.GODOT_SHA256["win32"],
            "Portable Godot identity changed")
    required = {*MATERIALIZED, "Open Workbench.cmd", "Open Persistent Areas.cmd", "Verify Package.cmd", "Verify Package.ps1", "READ-ME.md",
                "godot/scripts/persistent_area_cache.gd", "godot/scripts/depth/workbench_strata_controller.gd",
                "godot/scripts/depth/workbench_strata_optics_panel.gd", "godot/shaders/strata_optical_plane.gdshader"}
    require(required <= set(names), "Incomplete integrated owner application")
    summaries = record.get("qualification", {})
    require(set(summaries) == {platform + "-" + mode for platform in ("linux", "win32") for mode in q.MODES},
            "Six required source campaigns missing")
    for name, digest in summaries.items():
        path = folder / "qualification" / (name + ".json")
        report = q.read(path)
        require(sha(path) == digest and report.get("source_identity") == source and report.get("status") == "passed"
                and report.get("completed") is True and report.get("input_custody") == "passed"
                and name == report.get("platform", "") + "-" + report.get("mode", ""), "Packaged source campaign changed")
    if pristine:
        require(payload(folder) == names, "Pristine archive has extra/missing files")
    return record


def build(args):
    admitted = q.admission()
    source = admitted["source_identity"]
    runtime = q.custody.windows.verify_retained_runtime(ROOT)
    output = args.output.resolve()
    require(not output.exists(), "Refusing to overwrite evaluator output")
    reports = {}
    for platform in ("linux", "win32"):
        for mode in q.MODES:
            path = args.evidence / (platform + "-" + mode)
            report = q.verify(path, source)
            require(report["platform"] == platform and report["mode"] == mode,
                    "Campaign location differs from original platform/mode")
            reports[platform + "-" + mode] = path / "integration.json"
    dependencies = args.dependencies.resolve(strict=True)
    for name, digest in DEPENDENCIES.items():
        require(sha(dependencies / name) == digest, "Portable dependency mismatch: " + name)
    verify_vc_runtime(dependencies)
    original, omitted = original_inventory(runtime)
    for name in MATERIALIZED:
        expected = materialized_identity(name)
        require((ROOT / name).stat().st_size == expected["size"] and sha(ROOT / name) == expected["sha256"],
                "Required LFS payload not materialized: " + name)
    archive = subprocess.check_output(["git", "archive", "HEAD", "--", *ARCHIVE_INPUTS], cwd=ROOT,
                                      env=archive_environment(), timeout=90)
    output.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as source_tar:
        for member in source_tar:
            if not member.isfile() or member.name not in original:
                continue
            data = (ROOT / member.name).read_bytes() if member.name in MATERIALIZED else source_tar.extractfile(member).read()
            require(not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"),
                    "Unmaterialized required archive member: " + member.name)
            target = output / safe_name(member.name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    profiles = stage_generator_profiles(output)
    require(omit_regenerated_imports(output) == omitted, "Unexpected regenerated import omission")
    for name in [*DEPENDENCIES, "vcruntime140.dll", "vc-runtime-provenance.json"]:
        shutil.copyfile(dependencies / name, output / name)
    (output / "Open Workbench.cmd").write_text(base.launcher_text(source), encoding="utf-8", newline="\r\n")
    (output / "Open Persistent Areas.cmd").write_text(persistent_launcher(source), encoding="utf-8", newline="\r\n")
    (output / "Verify Package.cmd").write_bytes(VERIFY_CMD.encode())
    (output / "Verify Package.ps1").write_text(VERIFY_PS1, encoding="utf-8", newline="\n")
    (output / "READ-ME.md").write_text(owner_text(source), encoding="utf-8")
    (output / "qualification").mkdir()
    qualification = {}
    for name, path in reports.items():
        target = output / "qualification" / (name + ".json")
        shutil.copyfile(path, target)
        qualification[name] = sha(target)
    record = {"schema": "ramcache-strata-workbench-evaluation-v1", "source_identity": source,
              "source_commit": source["source_commit"], "source_tree": source["source_tree"], "runtime": runtime,
              "native_reuse": admitted["native_reuse"], "classic_default": True, "objectshard_m4_included": False,
              "performance_policy": admitted["performance_policy"], "physical_gpu_acceptance_for_this_archive": False,
              "qualification": qualification, "generator_profiles_sha256": profiles,
              "archived_git_blobs": {k: v for k, v in original.items() if k not in omitted},
              "regenerated_imports_sha256": omitted, "files_sha256": payload(output),
              "workflow_url": "https://github.com/techrote/cybersand/actions/runs/" + os.environ.get("GITHUB_RUN_ID", ""),
              "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "")}
    write_json(output / MANIFEST, record)
    verify(output, pristine=True)
    archive_path = args.archive.resolve()
    require(not archive_path.exists(), "Refusing to overwrite archive")
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(output.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(output).as_posix())
    identity = {"filename": archive_path.name, "bytes": archive_path.stat().st_size, "sha256": sha(archive_path),
                "manifest_sha256": sha(output / MANIFEST), "source_commit": source["source_commit"],
                "source_tree": source["source_tree"], "files": len(record["files_sha256"])}
    write_json(archive_path.with_suffix(".identity.json"), identity)
    archive_path.with_suffix(".zip.sha256").write_text(identity["sha256"] + "  " + archive_path.name + "\n")
    require(q.identity() == source, "Source changed during packaging")
    return identity


def inspect_archive(archive: Path) -> dict:
    names, folded, total = {}, set(), 0
    with zipfile.ZipFile(archive) as bundle:
        for item in bundle.infolist():
            name = safe_name(item.orig_filename)
            require(name == item.filename and not item.is_dir() and not item.flag_bits & 1
                    and stat.S_IFMT(item.external_attr >> 16) in (0, stat.S_IFREG), "Unsupported ZIP member")
            require(name.casefold() not in folded, "Duplicate/case-colliding ZIP member")
            folded.add(name.casefold())
            total += item.file_size
            require(total <= MAXIMUM_UNCOMPRESSED_BYTES and item.file_size <= 1024**3, "Archive extraction bound exceeded")
            require(not any(part in ("userdata", ".godot", "__pycache__") for part in PurePosixPath(name).parts),
                    "Shipped package contains prior generated user/import state")
            names[name] = hashlib.sha256(bundle.read(item)).hexdigest()
        manifest = json.loads(bundle.read(MANIFEST))
    require(manifest.get("files_sha256") == {k: v for k, v in names.items() if k != MANIFEST},
            "Actual ZIP and complete payload manifest disagree")
    return names


def validate_launcher_log(text: str, source: str, *, persistent=False) -> dict:
    require(not cold.ERRORS.search(text), "Cold launcher log contains an engine/script error")
    headers = [line for line in text.splitlines() if line.startswith("Godot Engine v")]
    require(headers == ["Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org"] * 2,
            "CMD did not run the pinned importer followed by the ordinary application")
    devices = [line for line in text.splitlines() if line.startswith("OpenGL API ")]
    require(len(devices) == 1 and " - Compatibility - Using Device: " in devices[0], "No ordinary graphical backend")
    if persistent:
        value = json.loads(q.marker(text, "PERSISTENT_AREAS_READY "))
        require(set(value) == {"session", "area", "revision"} and value.get("area") in ("a", "b", "c")
                and re.fullmatch(r"[0-9a-f]{32}", str(value.get("session", "")))
                and type(value.get("revision")) is int and value["revision"] > 0,
                "Actual persistent shortcut did not open its durable three-area profile")
        return {"admission": value, "rendering_backend": devices[0],
                "source_identity_scope": "verified exact launcher and package payload; existing readiness marker"}
    value = json.loads(q.marker(text, "STRATA_WORKBENCH_LAUNCH_ADMITTED "))
    require(set(value) == {"source_revision", "workbench_script", "world_generation", "worker_id", "extent", "strata_enabled"}
            and value["source_revision"] == source and value["workbench_script"] == "res://scripts/shared_workbench.gd"
            and cold.integer(value["world_generation"], 1) and isinstance(value["worker_id"], str)
            and cold.ID.fullmatch(value["worker_id"]) and value["extent"] == [2048, 2048]
            and value["strata_enabled"] is False, "Cold CMD did not admit the actual ordinary native Workbench")
    return {"admission": value, "rendering_backend": devices[0]}


def validate_launcher_execution(process, raw_lifetimes, resources, log, source, *, persistent=False):
    # Independent application-parameterized reader of the retained cold observer's
    # original Win32 handles. No frozen Strata donor identity is overwritten.
    require(process.get("schema") == "strata3-cold-process-v1" and process.get("label") == "launcher"
            and process.get("platform") == "win32" and cold.integer(process.get("pid"), 1)
            and process.get("exit_code") == 0 and process.get("timed_out") is False
            and process.get("failure") is None and process.get("cleanup_errors") == []
            and process.get("timeout_seconds") == 180 and cold.number(process.get("wall_seconds"), 0.001)
            and process["wall_seconds"] <= 190 and " " in process.get("cwd", "")
            and ntpath.basename(process.get("executable", "")).lower() == "cmd.exe"
            and process.get("command") == cold.command_line(process["executable"], process["cwd"], persistent=persistent),
            "Wrong, failed or unbounded actual CMD execution")
    require(raw_lifetimes.get("schema") == "strata3-cold-process-lifetimes-v1", "Wrong lifetime schema")
    rows = raw_lifetimes.get("rows")
    require(isinstance(rows, list) and 5 <= len(rows) <= 128, "Missing complete CMD/Godot population")
    identities = set()
    for row in rows:
        key = (row.get("pid"), row.get("start_id"))
        require(cold.integer(key[0], 1) and cold.integer(key[1], 1) and key not in identities
                and row.get("exited") is True and row.get("exit_code") == 0
                and row.get("creation_filetime_100ns") == key[1]
                and cold.integer(row.get("exit_filetime_100ns"), key[1] + 1)
                and cold.number(row.get("final_cpu_seconds")) and cold.number(row.get("lifetime_seconds"), 0.000001)
                and math.isclose(row["lifetime_seconds"], (row["exit_filetime_100ns"] - key[1]) / 10_000_000, abs_tol=1e-9),
                "Process remains live, failed or lacks held-handle timing")
        identities.add(key)
    roots = [r for r in rows if r["pid"] == process["pid"]]
    require(len(roots) == 1 and cold.normalized(roots[0]["image_path"]) == cold.normalized(process["executable"]),
            "Actual CMD identity missing")
    root = roots[0]
    require(cold.number(process.get("started_unix_seconds"), 1)
            and abs(root["start_id"] / 10_000_000 - 11644473600 - process["started_unix_seconds"]) <= 5
            and root["lifetime_seconds"] <= process["wall_seconds"] + 1, "Process clock outside observed launch")
    consoles = sorted((r for r in rows if cold.normalized(r["image_path"]) ==
                       cold.normalized(ntpath.join(process["cwd"], cold.CONSOLE))), key=lambda r: r["start_id"])
    require(len(consoles) == 2 and all(r["parent_pid"] == root["pid"] for r in consoles)
            and root["start_id"] <= consoles[0]["start_id"] < consoles[0]["exit_filetime_100ns"] <= consoles[1]["start_id"]
            < consoles[1]["exit_filetime_100ns"] <= root["exit_filetime_100ns"], "CMD stages are not ordered shipped engines")
    engines = [r for r in rows if cold.normalized(r["image_path"]) == cold.normalized(ntpath.join(process["cwd"], cold.GUI))]
    require(len(engines) >= 2, "Bundled Godot children not observed")
    for console in consoles:
        children = [r for r in engines if r["parent_pid"] == console["pid"]]
        require(len(children) == 1 and console["start_id"] <= children[0]["start_id"]
                < children[0]["exit_filetime_100ns"] <= console["exit_filetime_100ns"], "Shipped console child identity missing")
    for row in rows:
        if row is root:
            continue
        parents = [p for p in rows if p["pid"] == row["parent_pid"] and p["start_id"] <= row["start_id"] <= p["exit_filetime_100ns"]]
        require(len(parents) == 1 and root["start_id"] <= row["start_id"] < row["exit_filetime_100ns"] <= root["exit_filetime_100ns"],
                "Process escaped the actual launcher tree")
    cold.validate_resources(resources, process, rows)
    result = validate_launcher_log(log, source, persistent=persistent)
    result.update(console_process_ids=[r["pid"] for r in consoles], engine_process_ids=[r["pid"] for r in engines],
                  cold_import_command_seconds=consoles[0]["lifetime_seconds"],
                  ordinary_workbench_command_seconds=consoles[1]["lifetime_seconds"])
    return result


def read_launcher_evidence(location: Path, source: str, *, persistent=False) -> dict:
    process = q.read(location / "process.json")
    for name, key in (("process.log", "log_sha256"), ("resources.json", "resources_sha256"),
                      ("lifetimes.json", "lifetimes_sha256")):
        require(sha(location / name) == process.get(key), "Original launcher observation changed: " + name)
    return validate_launcher_execution(process, q.read(location / "lifetimes.json"),
        q.read(location / "resources.json"), (location / "process.log").read_text(encoding="utf-8"),
        source, persistent=persistent)


def persistent_container(path: Path, magic: bytes, metadata_limit: int, native_limit: int) -> tuple[bytes, bytes]:
    require(path.is_file() and not path.is_symlink() and 52 <= path.stat().st_size <= 64 * 1024**2,
            "Missing, linked or oversized persistent container")
    data = path.read_bytes()
    require(52 <= len(data) <= 64 * 1024**2 and data[:8] == magic + b"\0", "Unsupported persistent container")
    version, metadata_size, native_size = struct.unpack_from("<III", data, 8)
    require(version == 1 and 1 <= metadata_size <= metadata_limit and native_size <= native_limit
            and len(data) == 52 + metadata_size + native_size
            and hashlib.sha256(data[52:]).digest() == data[20:52],
            "Persistent container lengths, version or checksum differ")
    return data[52:52 + metadata_size], data[52 + metadata_size:]


def read_persistent_profile(profile: Path, native_sha256: str) -> dict:
    metadata, native = persistent_container(profile / "current.cypm", b"CYSPROF", 262144 - 52, 0)
    value = json.loads(metadata)
    require(not native and value.get("version") == 1 and set(value.get("areas", {})) == {"a", "b", "c"}
            and value.get("active_area") in ("a", "b", "c") and value.get("revision", 0) > 0
            and re.fullmatch(r"[0-9a-f]{32}", str(value.get("session_id", "")))
            and value.get("profile_id") == "gen006-three-areas-v1"
            and value.get("compatibility") == "gen006-current-freemass-512-cyps2-v1:" + native_sha256,
            "Shortcut profile lacks the three durable source-matched areas")
    for area, record in value["areas"].items():
        filename = record.get("blob", "")
        require(re.fullmatch("area-" + area + r"-[0-9a-f]{32}\.cypa", filename)
                and record.get("area_id") == area and record.get("extent") == [512, 512]
                and sha(profile / filename) == record.get("sha256"), "Profile references an absent or changed native area")
        _, native = persistent_container(profile / filename, b"CYSAREA", 8 * 1024**2, 32 * 1024**2)
        require(native.startswith(b"CYPS") and hashlib.sha256(native).hexdigest() == record.get("native_sha256"),
                "Actual native checkpoint payload differs from its durable manifest")
    return {"session_id": value["session_id"], "revision": value["revision"], "active_area": value["active_area"],
            "manifest_sha256": sha(profile / "current.cypm"), "native_areas": value["areas"],
            "files_sha256": {p.name: sha(p) for p in profile.iterdir() if p.is_file()}}


def installed(args):
    require(sys.platform == "win32", "Actual shipped CMD qualification requires Windows")
    names = inspect_archive(args.archive)
    destination = args.installation.resolve()
    require(not destination.exists() and " " in str(destination), "Use a new extraction directory containing spaces")
    destination.mkdir(parents=True)
    with zipfile.ZipFile(args.archive) as bundle:
        for name in names:
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.open(name) as src, target.open("xb") as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
    require({p.relative_to(destination).as_posix(): sha(p) for p in destination.rglob("*") if p.is_file()} == names,
            "Pristine extracted bytes differ from actual archive")
    manifest = verify(destination, pristine=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    # This is deliberately the first Godot invocation against the extracted copy.
    cold.execute_launcher(destination, output / "cold-launch", q.metrics)
    location = output / "cold-launch"
    observation = read_launcher_evidence(location, manifest["source_commit"])
    write_json(output / "cold-launch-verification.json", observation)
    shortcut = []
    for phase in ("first", "reopen"):
        location = output / ("persistent-shortcut-" + phase)
        cold.execute_launcher(destination, location, q.metrics, persistent=True)
        result = read_launcher_evidence(location, manifest["source_commit"], persistent=True)
        profiles = list((destination / "userdata/roaming").glob(
            "Godot/app_userdata/*/persistent-areas/three-areas-v1/current.cypm"))
        require(len(profiles) == 1, "Persistent shortcut did not use the normal package-local default profile")
        retained = location / "original-profile"
        shutil.copytree(profiles[0].parent, retained)
        result["profile"] = read_persistent_profile(retained, manifest["runtime"]["cybersand_runtime"]["sha256"])
        ready, saved = result["admission"], result["profile"]
        require(ready["session"] == saved["session_id"] and ready["area"] == saved["active_area"]
                and ready["revision"] <= saved["revision"], "Shortcut readiness contradicts actual durable profile")
        shortcut.append(result)
    require(shortcut[0]["profile"]["session_id"] == shortcut[1]["profile"]["session_id"]
            and set(shortcut[0]["engine_process_ids"]).isdisjoint(shortcut[1]["engine_process_ids"]),
            "Persistent shortcut did not reopen the same profile through new actual engine processes")
    write_json(output / "persistent-shortcut-verification.json", {"status": "passed", "launches": shortcut,
               "scope": "Actual shipped CMD launch/default-profile route; durable save/close assertions are in separate full fixtures"})
    for mode in ("ramcache", "strata"):
        from types import SimpleNamespace
        code = q.run(SimpleNamespace(mode=mode, godot=destination / cold.CONSOLE,
                     project=destination / "godot", output=output / mode))
        require(code == 0, "Actual extracted " + mode + " campaign failed")
    verify(destination)
    result = {"schema": "ramcache-strata-extracted-evaluator-v1", "status": "passed",
              "source_commit": manifest["source_commit"], "source_tree": manifest["source_tree"],
              "archive": {"filename": args.archive.name, "bytes": args.archive.stat().st_size, "sha256": sha(args.archive)},
              "manifest_sha256": sha(destination / MANIFEST), "cold_cmd_was_first_engine_invocation": True,
              "cold_launch": observation, "extracted_modes": {m: sha(output / m / "integration.json") for m in ("ramcache", "strata")},
              "persistent_shortcut_receipt_sha256": sha(output / "persistent-shortcut-verification.json"),
              "payload_after_execution": "all original manifest files unchanged", "physical_gpu_acceptance": False}
    write_json(output / "extracted-verification.json", result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    make = commands.add_parser("build")
    for name in ("dependencies", "evidence", "output", "archive"):
        make.add_argument("--" + name, type=Path, required=True)
    check = commands.add_parser("verify")
    check.add_argument("package", type=Path)
    check.add_argument("--pristine", action="store_true")
    execute = commands.add_parser("installed")
    for name in ("archive", "installation", "output"):
        execute.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    result = build(args) if args.command == "build" else installed(args) if args.command == "installed" else verify(args.package, pristine=args.pristine)
    print(json.dumps({"status": "passed", "source_commit": result["source_commit"],
                      "archive_sha256": result.get("sha256", result.get("archive", {}).get("sha256"))}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
