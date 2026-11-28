#!/usr/bin/env python3
"""New Windows owner witnesses against the unchanged qualified 5f evaluator.

External observers are audit inputs. They do not become package payload, and
these headless witnesses do not replace the full 43/32/17 qualification campaign.
"""
from __future__ import annotations

import argparse
from collections import Counter
import ctypes
from ctypes import wintypes
import importlib.util
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shutil
import stat
import struct
import subprocess
import sys
import time
import zipfile

DIRECTORY = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("objectshard_delivery_audit", DIRECTORY / "review_delivery_45530425519.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
need, save, file_digest = audit.need, audit.save, audit.file_digest
SOURCE, TREE = audit.SOURCE, audit.TREE
MANIFEST = "objectshard-workbench-manifest.json"
GUI = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
GUI_SHA = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
OBSERVERS = {
    "authored": ("windows-owner-supplement/observe_authored_windows.gd",
                 "46b9344c7cae0f3d47b7dc142b193ce258dc138444070cdd93801309ad316186"),
    "live-cut": ("external-live-cut-recovery/observe_live_play_cut.gd",
                 "452b314cdd861428fcfaf5b8baac125a30c0a59f7d071cc188f4d4d435604d32"),
}
AUTHORED_SCHEMA = "objectshard-m4-authored-extent-reopen-v1"
CUT_SCHEMA = "objectshard-m4-live-play-cut-recovery-v1"
SETUP_KEYS = {"version", "extent", "actors", "next_id", "selected", "edits", "response",
              "liquid_policy", "normalize", "rule_radius", "source", "material", "brush", "fire"}


class Entry(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                ("pid", wintypes.DWORD), ("heap", ctypes.c_size_t), ("module", wintypes.DWORD),
                ("threads", wintypes.DWORD), ("parent", wintypes.DWORD),
                ("priority", wintypes.LONG), ("flags", wintypes.DWORD),
                ("executable", wintypes.WCHAR * 260)]


class Memory(ctypes.Structure):
    _fields_ = [("cb", wintypes.DWORD), ("faults", wintypes.DWORD)] + [
        (name, ctypes.c_size_t) for name in ("peak_working_set", "working_set", "peak_paged_pool",
            "paged_pool", "peak_nonpaged_pool", "nonpaged_pool", "pagefile", "peak_pagefile", "private_bytes")]


class ProcessFamily:
    """Retain actual process handles; wrapper and engine identities stay separate."""
    def __init__(self, pid: int):
        self.root = pid
        self.kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        self.psapi = ctypes.WinDLL("psapi", use_last_error=True)
        k = self.kernel
        k.CreateToolhelp32Snapshot.argtypes, k.CreateToolhelp32Snapshot.restype = [wintypes.DWORD, wintypes.DWORD], wintypes.HANDLE
        for name in ("Process32FirstW", "Process32NextW"):
            getattr(k, name).argtypes, getattr(k, name).restype = [wintypes.HANDLE, ctypes.POINTER(Entry)], wintypes.BOOL
        k.OpenProcess.argtypes, k.OpenProcess.restype = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE
        k.CloseHandle.argtypes, k.CloseHandle.restype = [wintypes.HANDLE], wintypes.BOOL
        k.GetExitCodeProcess.argtypes, k.GetExitCodeProcess.restype = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)], wintypes.BOOL
        k.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        k.GetProcessTimes.restype = wintypes.BOOL
        k.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
        k.QueryFullProcessImageNameW.restype = wintypes.BOOL
        k.TerminateProcess.argtypes, k.TerminateProcess.restype = [wintypes.HANDLE, wintypes.UINT], wintypes.BOOL
        self.psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Memory), wintypes.DWORD]
        self.psapi.GetProcessMemoryInfo.restype = wintypes.BOOL
        self.handles, self.processes, self.samples = {}, {}, []
        self.started = time.monotonic()
        self.scan()

    @staticmethod
    def ticks(value: wintypes.FILETIME) -> int:
        return (value.dwHighDateTime << 32) | value.dwLowDateTime

    def state(self, pid: int) -> dict:
        handle = self.handles[pid]
        result = {"pid": pid, "elapsed_seconds": time.monotonic() - self.started}
        code = wintypes.DWORD()
        if self.kernel.GetExitCodeProcess(handle, ctypes.byref(code)):
            result["exit_code"] = int(code.value)
        values = [wintypes.FILETIME() for _ in range(4)]
        if self.kernel.GetProcessTimes(handle, *(ctypes.byref(value) for value in values)):
            result.update(creation_filetime=self.ticks(values[0]), exit_filetime=self.ticks(values[1]),
                          kernel_seconds=self.ticks(values[2]) / 10_000_000,
                          user_seconds=self.ticks(values[3]) / 10_000_000)
        counters = Memory()
        counters.cb = ctypes.sizeof(counters)
        if self.psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
            result["memory"] = {key: int(getattr(counters, key))
                                for key in ("working_set", "peak_working_set", "private_bytes")}
        return result

    def scan(self) -> None:
        rows = {}
        snapshot = self.kernel.CreateToolhelp32Snapshot(2, 0)
        need(snapshot not in (None, ctypes.c_void_p(-1).value), "Could not observe owned Windows process family")
        try:
            entry = Entry()
            entry.dwSize = ctypes.sizeof(entry)
            available = self.kernel.Process32FirstW(snapshot, ctypes.byref(entry))
            while available:
                rows[int(entry.pid)] = {"parent_pid": int(entry.parent), "executable_name": entry.executable}
                available = self.kernel.Process32NextW(snapshot, ctypes.byref(entry))
        finally:
            self.kernel.CloseHandle(snapshot)
        descendants = {pid for pid in self.handles if self.state(pid).get("exit_code") == 259}
        if self.root not in self.handles:
            descendants.add(self.root)
        while True:
            expanded = descendants | {pid for pid, row in rows.items() if row["parent_pid"] in descendants}
            if expanded == descendants:
                break
            descendants = expanded
        for pid in sorted(descendants):
            if pid not in self.handles and pid in rows:
                handle = self.kernel.OpenProcess(0x1000 | 0x10 | 0x1, False, pid)
                if not handle:
                    continue
                path = ctypes.create_unicode_buffer(32768)
                size = wintypes.DWORD(len(path))
                observed = dict(rows[pid])
                if self.kernel.QueryFullProcessImageNameW(handle, 0, path, ctypes.byref(size)):
                    observed["image_path"] = path.value
                self.handles[pid], self.processes[pid] = handle, observed
        for pid in self.handles:
            self.samples.append(self.state(pid))

    def finish(self) -> dict:
        self.scan()
        final = {str(pid): {**self.processes[pid], **self.state(pid)} for pid in self.handles}
        for handle in self.handles.values():
            self.kernel.CloseHandle(handle)
        self.handles.clear()
        return {"scope": "Windows owned process handles; sampled memory and final CPU/lifetime, not a performance benchmark",
                "wrapper_pid": self.root, "processes": final, "samples": self.samples}

    def terminate_owned(self) -> list[int]:
        terminated = []
        for pid, handle in self.handles.items():
            if self.state(pid).get("exit_code") == 259:
                need(bool(self.kernel.TerminateProcess(handle, 125)), "Could not terminate an owned timed-out process")
                terminated.append(pid)
        return terminated


def safe_member(name: str) -> Path:
    path = PurePosixPath(name)
    need(not path.is_absolute() and "\\" not in name and ":" not in name
         and all(part not in {"", ".", ".."} for part in name.split("/")), "Unsafe package member")
    return Path(*path.parts)


def extract_package(inner: Path, package: Path) -> dict:
    need(not package.exists(), "Pristine package destination already exists")
    package.mkdir(parents=True)
    with zipfile.ZipFile(inner) as archive:
        rows = archive.infolist()
        names = [r.filename for r in rows]
        need(len(names) == len(set(names)) == len({name.casefold() for name in names}),
             "Duplicate or case-colliding package payload")
        for row in rows:
            relative = safe_member(row.filename)
            need(not row.is_dir() and not stat.S_ISLNK(row.external_attr >> 16), "Unexpected directory/symlink payload")
            path = package / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            count = 0
            with archive.open(row) as source, path.open("xb") as target:
                while block := source.read(1024 * 1024):
                    count += len(block)
                    need(count <= row.file_size, "Unexpected package member length")
                    target.write(block)
            need(count == row.file_size, "Truncated package payload")
    return immutable(package, allow_generated=False)


def immutable(package: Path, *, allow_generated: bool) -> dict:
    # Inspect directories before os.walk descends into them; no symlink or
    # Windows junction/reparse entry may redirect a declared input or cache.
    root_metadata = package.lstat()
    need(stat.S_ISDIR(root_metadata.st_mode) and not stat.S_ISLNK(root_metadata.st_mode)
         and not (getattr(root_metadata, "st_file_attributes", 0) & 0x400),
         "Extracted package root must be a real directory")
    all_files = set()
    def refuse_walk(error):
        raise error
    for base, directories, filenames in os.walk(package, followlinks=False, onerror=refuse_walk):
        for name in directories + filenames:
            path = Path(base) / name
            metadata = path.lstat()
            need(not stat.S_ISLNK(metadata.st_mode)
                 and not (getattr(metadata, "st_file_attributes", 0) & 0x400),
                 "External symlink/reparse entry in extracted package")
            if path.is_file():
                all_files.add(path.relative_to(package).as_posix())
    manifest_path = package / MANIFEST
    manifest = json.loads(manifest_path.read_bytes())
    need(manifest["schema"] == "objectshard-m4-workbench-package-v1"
         and manifest["source_commit"] == SOURCE and manifest["source_tree"] == TREE,
         "Extracted package source differs from immutable qualification")
    expected = manifest["files_sha256"]
    observed = {name: file_digest(package / safe_member(name)) for name in expected}
    need(observed == expected, "An immutable application payload file changed")
    extras = all_files - set(expected) - {MANIFEST}
    code_suffixes = {".exe", ".dll", ".so", ".dylib", ".gdextension", ".gd", ".gdc", ".cs",
                     ".tscn", ".tres", ".pck", ".gdshader", ".gdshaderinc", ".ps1", ".cmd", ".bat", ".py"}
    generated = {}
    for name in sorted(extras):
        suffix = PurePosixPath(name).suffix.lower()
        cache = name.startswith("godot/.godot/") and suffix not in code_suffixes
        uid = name.endswith((".gd.uid", ".gdshader.uid")) and name[:-4] in expected
        imported = name.startswith("godot/") and name.endswith(".import") and name[:-7] in expected
        need(allow_generated and (cache or uid or imported), "Unlisted loadable/unpaired package input: " + name)
        generated[name] = "project-cache" if cache else ("paired-source-uid" if uid else "paired-asset-import")
    need(manifest["native"]["sha256"] == observed[manifest["native"]["path"]] == audit.DLL_SHA
         and observed[GUI] == GUI_SHA and observed[CONSOLE] == audit.CONSOLE_SHA
         and observed[manifest["rapier"]["path"]] == audit.RAPIER_SHA,
         "Actual packaged execution runtime differs from independent native/engine/Rapier pins")
    return {"manifest_sha256": file_digest(manifest_path), "payload_files": observed,
            "generated_files": generated}


def process(command: list[str], label: str, environment: dict, package: Path, output: Path,
            timeout: int, *, receipt_path: Path | None = None, schema: str | None = None) -> tuple[dict | None, dict]:
    log = output / (label + ".log")
    start = time.time()
    family = None
    process_record = {"command": command, "started_unix": start, "timeout_seconds": timeout,
                      "wrapper_runner_pid": os.getpid(), "natural_completion": False,
                      "execution_environment": {key: environment.get(key) for key in (
                          "CYBERSAND_SOURCE_REVISION", "CYBERSAND_PACKAGE_MANIFEST", "CYBERSAND_TEST_ARTIFACT_DIR",
                          "CYBERSAND_AUTHORED_PHASE", "CYBERSAND_EXTERNAL_RECEIPT", "CYBERSAND_AUTHOR_RECEIPT",
                          "CYBERSAND_LAUNCH_NONCE", "CYBERSAND_EXTERNAL_OBSERVER_SHA256", "APPDATA", "LOCALAPPDATA")}}
    try:
        with log.open("wb") as stream:
            child = subprocess.Popen(command, cwd=package, env=environment, stdout=stream, stderr=subprocess.STDOUT)
            process_record["popen_pid"] = child.pid
            family = ProcessFamily(child.pid)
            deadline = time.monotonic() + timeout
            while child.poll() is None:
                family.scan()
                if time.monotonic() >= deadline:
                    family.terminate_owned()
                    child.wait(timeout=20)
                    raise RuntimeError("External " + label + " witness timed out")
                time.sleep(0.25)
            process_record["returncode"] = child.returncode
            process_record["natural_completion"] = True
        family.scan()
        # The console wrapper may differ from the real Godot executable. A
        # retained handle, not PID equality, establishes each observed lifetime.
        receipt = None
        if receipt_path is not None:
            need(receipt_path.is_file(), "External witness did not write its exact receipt")
            receipt = json.loads(receipt_path.read_bytes())
            raw = log.read_text(encoding="utf-8", errors="replace")
            footers = []
            for line in raw.splitlines():
                try:
                    value = json.loads(line)
                except ValueError:
                    continue
                if isinstance(value, dict) and value.get("schema") == schema:
                    footers.append(value)
            need(footers == [receipt], "Original log must contain one exact matching receipt footer")
            need(not re.search(r"(?m)^(?:SCRIPT ERROR|ERROR):", raw), "Godot reported an execution error")
            engine_pid = int(receipt.get("process_id", receipt.get("evidence", {}).get("identity", {}).get("process_id", 0)))
            need(engine_pid in family.handles, "Actual reported Godot process was not independently observed")
            engine = family.processes[engine_pid]
            actual_path = Path(engine.get("image_path", "")).resolve()
            need(actual_path in {(package / GUI).resolve(), (package / CONSOLE).resolve()},
                 "Actual Godot executable is outside the pristine package")
            for _ in range(40):
                if family.state(engine_pid).get("exit_code") != 259:
                    break
                time.sleep(0.25)
            need(family.state(engine_pid).get("exit_code") == 0, "Actual Godot process did not exit naturally with zero")
            process_record["godot_pid"] = engine_pid
            process_record["godot_image_path"] = str(actual_path)
            process_record["godot_image_sha256"] = file_digest(actual_path)
            process_record["receipt_sha256"] = file_digest(receipt_path)
            need(receipt.get("source_commit") == SOURCE and type(receipt.get("checks")) is int
                 and receipt["checks"] > 0 and receipt.get("failures") == [],
                 "External witness is not a complete successful exact-source result")
        for _ in range(40):
            if all(family.state(pid).get("exit_code") != 259 for pid in family.handles):
                break
            time.sleep(0.25)
        need(family.root in family.handles and all(family.state(pid).get("exit_code") == 0
             for pid in family.handles), "Owned wrapper/engine family did not all exit naturally with zero")
        need(child.returncode == 0, "External process returned a failure exit")
        return receipt, process_record
    finally:
        process_record["completed_unix"] = time.time()
        process_record["elapsed_seconds"] = process_record["completed_unix"] - start
        if family is not None:
            process_record["forced_cleanup_pids"] = family.terminate_owned()
            process_record["resources"] = family.finish()
        if log.exists():
            process_record["log"] = {"path": str(log), "bytes": log.stat().st_size, "sha256": file_digest(log)}
        save(output / (label + "-process.json"), process_record)


def coherent(value: dict) -> None:
    need(value["between_callback_observations"] > 0 and value["incoherent_observations"] == 0,
         "External witness lacks coherent displayed-publication observations")


def raw_record(record: dict, raw_root: Path, identities: dict) -> bytes:
    path = Path(record["path"]).resolve()
    need(record.get("retained") is True and path.is_relative_to(raw_root.resolve()),
         "Raw witness escaped its external per-process output directory")
    need(path.is_file() and path.stat().st_size == record["bytes"] and file_digest(path) == record["sha256"],
         "Original raw witness bytes/hash differ")
    identities[str(path)] = {"relative_output": path.relative_to(raw_root.parent).as_posix(),
                             "bytes": record["bytes"], "sha256": record["sha256"]}
    return path.read_bytes()


def inventory(value: dict, raw_root: Path) -> dict:
    need(value["schema"] == "objectshard-m4-independent-inventory-v1", "Wrong raw inventory schema")
    identities = {}
    grid = raw_record(value["raw_grid"], raw_root, identities)
    need(len(grid) == 512 * 512, "Raw inventory is not the complete 512 canvas")
    counts = [0] * 256
    for material, count in Counter(grid).items():
        counts[material] = count
    need(counts == value["raw_world_material_counts"], "Raw material census differs from observer report")
    total = counts.copy()
    total[0] = 0
    owners = set()
    need(len(value["owned_inventory"]) <= 16, "Native mutable carrier roster exceeds its registered bound")
    for owner in value["owned_inventory"]:
        need(type(owner["id"]) is int and owner["id"] > 0 and owner["id"] not in owners,
             "Invalid/duplicated native Registry owner (distinct from shared-space reservation slots)")
        owners.add(owner["id"])
        materials = raw_record(owner["materials"], raw_root, identities)
        need(3 not in materials, "Water unexpectedly belongs to an ObjectShard carrier")
        for material, count in Counter(materials).items():
            if material:
                total[material] += count
    need(total == value["total_material_counts"], "Full World plus carrier census differs")
    water = value["water"]
    parcel_bytes = raw_record(water["raw_parcels_float64"], raw_root, identities)
    need(len(parcel_bytes) % 40 == 0, "Incomplete Float64 parcel record")
    parcels = list(struct.iter_unpack("<ddddd", parcel_bytes))
    need(len(parcels) == water["parcel_count"], "Parcel inventory count differs")
    parcel_pixels, quantity = set(), 0
    for x, y, vx, vy, amount in parcels:
        need(all(math.isfinite(v) for v in (x, y, vx, vy, amount))
             and amount > 0 and amount == int(amount), "Invalid actual parcel kinematics/quantity")
        quantity += int(amount)
        ix, iy = math.floor(x), math.floor(y)
        if 0 <= ix < 512 and 0 <= iy < 512 and grid[iy * 512 + ix] == 0:
            parcel_pixels.add(iy * 512 + ix)
    need(quantity == water["independent_parcel_quantity"] and len(parcel_pixels) == water["parcel_material_pixels"],
         "Independent parcel sum/projection differs")
    scan = water["raw_state_scan"]
    need(scan["water_cells"] == counts[3] and all(scan[key] == 0
         for key in ("water_visible", "water_overfill", "water_integer")),
         "Independent stored Water state scan differs from the zero-Water Tower census")
    need(counts[3] == 0 and quantity == 0 and water["independent_total_quantity"] == 0
         and all(water["native_ledger"][key] == 0 for key in ("visible", "overfill", "ballistic", "total", "expected")),
         "Tower witness unexpectedly contains Water; do not conflate rendered pixels and stored inventory")
    pixels = raw_record(value["rendered_grid"], raw_root, identities)
    need(len(pixels) == len(grid) * 2 and all(pixels[i * 2] == (3 if i in parcel_pixels else material)
         for i, material in enumerate(grid)), "Actual RG8 material channel differs from raw grid/parcel projection")
    need(value["presentation_projection_mismatches"] == [], "Observer reported a material presentation mismatch")
    return {"source": value["source"], "total_material_counts": total,
            "raw_world_material_counts": counts, "owner_ids": sorted(owners),
            "owner_incarnations": [{"id": owner["id"], "generation": owner["generation"],
                                   "body_generation": owner["body_generation"]} for owner in value["owned_inventory"]],
            "raw_files": identities}


def save_authored(record: dict, user_root: Path, output: Path) -> dict:
    path = Path(record["path"]).resolve()
    need(path.is_relative_to(user_root.resolve()) and path.is_file(), "Authored save escaped fresh user data")
    raw = path.read_bytes()
    need(len(raw) == record["bytes"] and audit.digest(raw) == record["sha256"], "Authored save bytes differ")
    document = json.loads(raw)
    need(set(document) == SETUP_KEYS and set(record["root_keys"]) == SETUP_KEYS
         and document == record["setup"] and document["version"] == 2 and document["extent"] == [512, 512],
         "Authored save is not the complete declared starting recipe")
    saved = output / "authored-saves" / path.name
    saved.parent.mkdir(exist_ok=True)
    saved.write_bytes(raw)
    return {"original_path": str(path), "retained_path": str(saved), "bytes": len(raw),
            "sha256": audit.digest(raw), "setup": document}


def authored_result(value: dict, phase: str, nonce: str, raw_root: Path, user_root: Path,
                    output: Path, author: dict | None, author_receipt: Path) -> dict:
    need(value["phase"] == phase and value["launch_nonce"] == nonce
         and value["observer_sha256"] == OBSERVERS["authored"][1]
         and value["operating_system"] == "Windows" and value["display_driver"] == "headless",
         "Authored process identity/platform/scope differs")
    coherent(value["display_coherence"])
    required = {"intact", "cut", "cut_inventory", "inventory_witnesses", "mounted_actions"}
    need(required <= set(value), "Authored observer lacks complete physical/persistence witnesses")
    need(value["intact"]["extent"] == value["cut"]["extent"] == [512, 512]
         and value["intact"]["body_count"] == 0 and value["cut"]["body_count"] == 1,
         "Authored intact/cut body lifecycle differs")
    inv = inventory(value["cut_inventory"], raw_root)
    need(inv["total_material_counts"][7] == 2184 and inv["total_material_counts"][43] == 2232
         and len(inv["owner_ids"]) == 1, "Authored Tower material ownership differs")
    need(value["inventory_witnesses"] == [value["cut_inventory"]], "Authored inventory witness copies differ")
    captions = [row["caption"] for row in value["mounted_actions"]]
    if phase == "author":
        need(captions == ["Structures…", "Enable on current canvas", "New blank",
                         "Enable on current canvas", "Multi-storey tower",
                         "Save start [Ctrl+S]", "Save start [Ctrl+S]"], "Mounted author action inventory differs")
        before, refused, supported = (value[k] for k in ("default_before", "default_refusal", "supported_1024"))
        need(before["extent"] == [2048, 2048] and before["paused"] is True
             and not before["runtime_enabled"] and not before["port_enabled"],
             "Production default was not the unchanged paused 2048 canvas")
        need(not refused["runtime_enabled"] and not refused["port_enabled"] and not refused["attached"]
             and all(refused[k] == before[k] for k in ("world_generation", "worker_instance_id", "native_tick", "world_revision"))
             and "512 or 1024" in refused["message"], "Unsupported extent refusal changed the World or lacked guidance")
        need(supported["extent"] == [1024, 1024] and supported["body_count"] == 0
             and supported["attached"] is True, "Supported 1024 authoring did not attach normally")
        saved = {key: save_authored(value[key], user_root, output) for key in ("saved_intact", "saved_cut")}
        need(value["saved_intact"]["support_material_cells"] == 800
             and value["saved_cut"]["support_material_cells"] == 6
             and len(saved["saved_cut"]["setup"]["edits"]) > len(saved["saved_intact"]["setup"]["edits"]),
             "Authored support erasure was not preserved")
    else:
        need(author is not None and captions == ["Load start", "Load start"]
             and value["author_receipt_sha256"] == file_digest(author_receipt)
             and value["author_process_id"] == author["process_id"]
             and value["launch_nonce"] != author["launch_nonce"], "Fresh-process author/reopen chain differs")
        saved = {}
        for suffix in ("intact", "cut"):
            prior = author["saved_" + suffix]
            need(value["reopened_" + suffix] == prior, "Reopen changed the exact author save identity")
            saved["saved_" + suffix] = save_authored(prior, user_root, output)
            need(value["loaded_setups"][prior["label"]] == prior["setup"], "Fresh Load did not restore the full authored recipe")
    return {"checks": value["checks"], "saved": saved, "inventory": inv, "mounted_actions": captions}


def point_velocity(sample: dict, local: list) -> tuple[float, float]:
    x, y = local[0] - sample["com_x"], local[1] - sample["com_y"]
    c, s = math.cos(sample["rotation"]), math.sin(sample["rotation"])
    ox, oy = c * x - s * y, s * x + c * y
    return sample["vx"] - oy * sample["angular_velocity"], sample["vy"] + ox * sample["angular_velocity"]


def live_cut_result(value: dict, nonce: str, raw_root: Path, package: Path) -> dict:
    need(value["nonce"] == nonce, "Live Cut nonce differs")
    e = value["evidence"]
    need({"identity", "dispatch", "terminal", "delivered", "geometry_transition", "continued_motion",
          "inventory_before", "inventory_after", "inventory_witnesses", "display_coherence", "census_mismatches"} <= set(e),
         "Live Cut observer lacks required lifecycle records")
    identity = e["identity"]
    need(identity["platform"] == "Windows" and identity["display_driver"] == "headless"
         and identity["application_source"] == SOURCE and identity["application_tree"] == TREE
         and identity["native_sha256"] == audit.DLL_SHA and identity["rapier_sha256"] == audit.RAPIER_SHA
         and identity["observer_sha256"] == OBSERVERS["live-cut"][1]
         and identity["manifest_sha256"] == file_digest(package / MANIFEST),
         "Actual live Cut engine/native/observer/package identity differs")
    engine = Path(identity["engine_path"]).resolve()
    need(engine in {(package / GUI).resolve(), (package / CONSOLE).resolve()}
         and identity["engine_sha256"] == file_digest(engine), "Live Cut actual engine is outside verified package")
    coherent(e["display_coherence"])
    dispatch, terminal, delivered = e["dispatch"], e["terminal"], e["delivered"]
    native = terminal["native_receipt"]
    need(dispatch["paused"] is False and dispatch["mode"] == 5
         and dispatch["pending_after_press"] == 1 and dispatch["results_after_press"] == 0
         and dispatch["drag_after_release"] == 0 and terminal["outcome"] == "Applied"
         and native["accepted"] is True and native["operation"] == "erase"
         and native["source_target"] == dispatch["target"]
         and delivered["next_transaction"] > native["transaction_id"] and delivered["paused"] is False,
         "Mounted live Cut is not one exact displayed source-cell Applied transaction")
    moving = dispatch["physics"]
    need(moving["paused"] is False and moving["sleeping"] is False
         and math.hypot(moving["vx"], moving["vy"]) > 5 and abs(moving["angular_velocity"]) > .05,
         "Cut was not dispatched against genuine translating and rotating Rapier motion")
    pair = e["geometry_transition"]
    before, after = pair["before"], pair["after"]
    need(before["physical_step"] == after["physical_step"] and before["bridge_step"] == after["bridge_step"]
         and before["rid"] == after["rid"] and after["last_geometry_step"] == after["bridge_step"]
         and before["paused"] is after["paused"] is False,
         "Geometry transition is not the same actual physical step/RID during Play")
    target = dispatch["target"]
    width, height, survivor = dispatch["source_width"], dispatch["source_height"], dispatch["survivor_cell"]
    need(type(width) is int and type(height) is int and width > 0 and height > 0
         and type(survivor) is int and 0 <= survivor < width * height and survivor != target["cell"]
         and pair["survivor_cell"] == survivor
         and pair["survivor_local"] == dispatch["survivor_local"] == [survivor % width + .5, survivor // width + .5],
         "Surviving material point is not the exact dispatched stable lattice cell center")
    need(before["geometry_revision"] == target["geometry_revision"]
         and after["geometry_revision"] == native["geometry_revision"]
         and all(sample["generation"] == target["generation"]
                 and sample["body_generation"] == target["body_generation"] for sample in (before, after)),
         "Observed geometry transition does not join the dispatched owner and native receipt")
    old_v, new_v = point_velocity(before, pair["survivor_local"]), point_velocity(after, pair["survivor_local"])
    residual = math.dist(old_v, new_v)
    need(math.isfinite(residual) and 0 <= residual <= .001
         and math.isfinite(pair["point_velocity_residual"]) and 0 <= pair["point_velocity_residual"] <= .001
         and math.dist(old_v, pair["point_velocity_before"]) <= .001
         and math.dist(new_v, pair["point_velocity_after"]) <= .001,
         "Independent surviving-point velocity conservation failed")
    angle = math.atan2(math.sin(after["rotation"] - before["rotation"]), math.cos(after["rotation"] - before["rotation"]))
    need(math.hypot(after["x"] - before["x"], after["y"] - before["y"]) <= .0001
         and abs(angle) <= .0001 and abs(after["angular_velocity"] - before["angular_velocity"]) <= .0001
         and after["geometry_revision"] > before["geometry_revision"] and after["shape_count"] > 0
         and abs(before["mass"] - after["mass"] - 1) <= .0001,
         "Actual collider, origin pose or unit material mass debit differs")
    shown = delivered["native_shard"]
    need(shown["generation"] == target["generation"] and shown["body_generation"] == target["body_generation"]
         and shown["width"] == dispatch["source_width"] and shown["height"] == dispatch["source_height"]
         and shown["survivor_incarnation"] == dispatch["survivor_incarnation"],
         "Delivered owner, source lattice or surviving material incarnation differs")
    need(shown["geometry_revision"] == shown["applied_physics_revision"] == after["geometry_revision"]
         and shown["geometry_pending"] is False and shown["selected_material"] == 0
         and shown["survivor_material"] == 7 and shown["survivor_role"] == 1,
         "Native ACK/current geometry/source cells differ")
    previous, continued = delivered["physics"], e["continued_motion"]
    need(shown["id"] == target["owner"] and all(sample["owner"] == target["owner"]
         and sample["generation"] == target["generation"] and sample["body_generation"] == target["body_generation"]
         and sample["rid"] == moving["rid"] for sample in (moving, before, after, previous, continued)),
         "Observed native owner incarnation and actual RID do not survive through continued motion")
    angle = math.atan2(math.sin(continued["rotation"] - previous["rotation"]), math.cos(continued["rotation"] - previous["rotation"]))
    need(continued["native_tick"] >= delivered["native_tick"] + 8
         and continued["physical_step"] > previous["physical_step"] and continued["paused"] is False
         and continued["sleeping"] is False
         and math.hypot(continued["x"] - previous["x"], continued["y"] - previous["y"]) > .01
         and abs(angle) > .0001, "Actual motion did not continue after the live edit")
    first, last = inventory(e["inventory_before"], raw_root), inventory(e["inventory_after"], raw_root)
    need(first["owner_ids"] == last["owner_ids"] == [target["owner"]]
         and first["owner_incarnations"] == last["owner_incarnations"] == [{"id": target["owner"],
             "generation": target["generation"], "body_generation": target["body_generation"]}],
         "Both full census carrier inventories must identify the dispatched native body")
    need(e["inventory_witnesses"] == [e["inventory_before"], e["inventory_after"]] and e["census_mismatches"] == [],
         "Live Cut raw census witness copies differ")
    need(all(last["total_material_counts"][i] == first["total_material_counts"][i] - (1 if i == 7 else 0)
             for i in range(1, 256)), "Complete independent census did not prove exactly one Wood debit")
    return {"checks": value["checks"], "point_velocity_before": old_v, "point_velocity_after": new_v,
            "independent_point_velocity_residual": residual, "before_inventory": first, "after_inventory": last,
            "native_transaction_id": native["transaction_id"], "continued_native_ticks": continued["native_tick"] - delivered["native_tick"]}


def compact_process(label: str, value: dict, output: Path) -> dict:
    record = output / (label + "-process.json")
    return {**{key: item for key, item in value.items() if key != "resources"},
            "complete_resource_record": {"path": str(record), "bytes": record.stat().st_size,
                                         "sha256": file_digest(record)}}


def observe_system_imports(previous: dict, output: Path) -> dict:
    """Read System32 metadata without loading DLLs or inferring portable approval."""
    imported = previous["package_import_inventory"]
    need(imported["status"] == "captured-static-imports-core-OS-classification-pending",
         "Static import predecessor record is missing")
    system = Path(os.environ["SystemRoot"]).resolve() / "System32"
    rows = []
    for name in imported["core_windows_candidates"]:
        need(re.fullmatch(r"[a-z0-9_.+-]+\.dll", name), "Unsafe retained OS import name")
        path = system / name
        need(path.is_file() and path.resolve().parent == system.resolve(),
             "Retained direct OS import is absent from actual Windows System32: " + name)
        with path.open("rb") as stream:
            dos = stream.read(64)
            need(len(dos) == 64 and dos[:2] == b"MZ", "System import is not a PE image")
            offset = struct.unpack_from("<I", dos, 60)[0]
            need(offset + 26 <= path.stat().st_size, "Invalid system PE bounds")
            stream.seek(offset)
            header = stream.read(26)
            need(len(header) == 26 and header[:6] == b"PE\0\0\x64\x86"
                 and struct.unpack_from("<H", header, 24)[0] == 0x20b, "System import is not AMD64 PE32+")
        rows.append({"name": name, "observed_path": str(path), "bytes": path.stat().st_size,
                     "sha256": file_digest(path), "machine": "AMD64", "optional_header": "PE32+"})
    result = {"status": "actual-System32-observations-retained-OS-classification-pending",
              "windows_version": str(sys.getwindowsversion()), "images": rows,
              "api_set_contracts": imported["api_set_contracts"],
              "scope": "Read-only actual hosted System32 bytes; no LoadLibrary. Not an assertion that every file is inbox on Windows11. "
                       "Final portable dependency approval requires the independent concrete OS-name review."}
    save(output / "system-import-observations.json", result)
    return result


def run(args: argparse.Namespace) -> dict:
    need(sys.platform == "win32", "Supplement requires actual Windows execution")
    need(file_digest(args.audit_summary) == args.audit_summary_sha256, "Predecessor independent audit summary changed")
    previous = json.loads(args.audit_summary.read_bytes())
    need(previous["status"] == "passed" and previous["application_source"] == SOURCE
         and previous["application_tree"] == TREE and previous["qualification_run"] == audit.RUN
         and previous["qualification_attempt"] == audit.ATTEMPT
         and previous["audit_source"] == os.environ["GITHUB_SHA"]
         and previous["audit_run"] == int(os.environ["GITHUB_RUN_ID"]),
         "Supplement is not bound to this successful independent archive audit")
    args.output.mkdir(parents=True, exist_ok=True)
    run_meta, jobs, metadata, selected = audit.metadata(args.output)
    outer = args.work / "original-evaluator-artifact.zip"
    args.work.mkdir(parents=True, exist_ok=False)
    custody = audit.raw_artifact(selected["workbench-evaluator"], outer)
    need(custody == previous["artifacts"]["workbench-evaluator"], "Fresh original evaluator artifact identity changed")
    inner = args.work / audit.INNER_NAME
    audit.extract_inner(outer, inner)
    need(inner.stat().st_size == previous["principal_evaluator"]["bytes"]
         and file_digest(inner) == previous["principal_evaluator"]["sha256"], "Principal inner ZIP differs from reviewed bytes")
    package = args.work / "Pristine Workbench (1)"
    baseline = extract_package(inner, package)
    system_imports = observe_system_imports(previous, args.output)
    save(args.output / "immutable-before.json", baseline)
    external = args.output / "external-inputs"
    external.mkdir()
    observers = {}
    for kind, (relative, expected_hash) in OBSERVERS.items():
        source = DIRECTORY / relative
        auditor_root = DIRECTORY.parents[2]
        raw = audit.git(auditor_root, "show", os.environ["GITHUB_SHA"] + ":" + source.relative_to(auditor_root).as_posix())
        need(audit.digest(raw) == expected_hash, "Independently reviewed external observer Git bytes changed")
        destination = external / source.name
        destination.write_bytes(raw)
        observers[kind] = destination
    for source in (Path(__file__), DIRECTORY / "review_delivery_45530425519.py"):
        (external / source.name).write_bytes(source.read_bytes())
    env = dict(os.environ)
    for key in ("GITHUB_TOKEN", "GH_TOKEN"):
        env.pop(key, None)
    env.update(CYBERSAND_SOURCE_REVISION=SOURCE, CYBERSAND_PACKAGE_MANIFEST=str(package / MANIFEST))
    engine = str(package / CONSOLE)
    common = [engine, "--headless", "--path", str(package / "godot")]
    user_root = args.work / "fresh-user-data"
    shared = user_root / "authored"
    isolated = user_root / "live-cut"
    results, failures = {}, []
    author, author_path = None, args.output / "author-receipt.json"
    phases = ("import", "author", "reopen", "live-cut")
    try:
        for phase in phases:
            if phase == "reopen" and author is None:
                failures.append({"phase": phase, "error": "Author predecessor did not qualify"})
                continue
            profile = isolated if phase == "live-cut" else shared
            for directory in (profile / "Roaming", profile / "Local"):
                directory.mkdir(parents=True, exist_ok=True)
            actual_env = dict(env, APPDATA=str(profile / "Roaming"), LOCALAPPDATA=str(profile / "Local"))
            nonce = secrets.token_hex(24)
            raw_root = args.output / (phase + "-raw")
            raw_root.mkdir()
            actual_env["CYBERSAND_TEST_ARTIFACT_DIR"] = str(raw_root)
            try:
                if phase == "import":
                    _, lifetime = process([*common, "--editor", "--quit"], phase, actual_env, package, args.output, 1200)
                    results[phase] = {"status": "passed", "process": compact_process(phase, lifetime, args.output)}
                    continue
                receipt_path = args.output / (phase + "-receipt.json")
                if phase in {"author", "reopen"}:
                    actual_env.update(CYBERSAND_AUTHORED_PHASE=phase, CYBERSAND_EXTERNAL_RECEIPT=str(receipt_path),
                                      CYBERSAND_AUTHOR_RECEIPT=str(author_path), CYBERSAND_LAUNCH_NONCE=nonce,
                                      CYBERSAND_EXTERNAL_OBSERVER_SHA256=OBSERVERS["authored"][1])
                    command = [*common, "--script", str(observers["authored"])]
                    if phase == "reopen":
                        command += ["--", "--objectshard-m4-workbench"]
                    value, lifetime = process(command, phase, actual_env, package, args.output, 300,
                                              receipt_path=receipt_path, schema=AUTHORED_SCHEMA)
                    review = authored_result(value, phase, nonce, raw_root, user_root, args.output, author, author_path)
                    if phase == "author":
                        author = value
                else:
                    command = [*common, "--script", str(observers["live-cut"]), "--", "--objectshard-m4-workbench",
                               "--nonce=" + nonce, "--output=" + str(receipt_path)]
                    value, lifetime = process(command, phase, actual_env, package, args.output, 1200,
                                              receipt_path=receipt_path, schema=CUT_SCHEMA)
                    review = live_cut_result(value, nonce, raw_root, package)
                results[phase] = {"status": "passed", "nonce": nonce, "review": review,
                                  "process": compact_process(phase, lifetime, args.output)}
                save(args.output / (phase + "-independent-review.json"), results[phase])
            except Exception as error:
                failures.append({"phase": phase, "error_type": type(error).__name__, "error": str(error)})
    finally:
        after = immutable(package, allow_generated=True)
        need(after["manifest_sha256"] == baseline["manifest_sha256"]
             and after["payload_files"] == baseline["payload_files"], "Application payload changed during external witnesses")
        save(args.output / "immutable-after.json", after)
    if "author" in results and "reopen" in results:
        need(results["reopen"]["process"]["started_unix"] >= results["author"]["process"]["completed_unix"],
             "Author and fresh reopening process lifetimes overlap")
    result = {"schema": "objectshard-m4-windows-owner-supplement-v1",
              "status": "passed" if not failures and set(results) == set(phases) else "failed",
              "application_source": SOURCE, "application_tree": TREE, "qualification_run": audit.RUN,
              "audit_source": os.environ["GITHUB_SHA"], "audit_run": int(os.environ["GITHUB_RUN_ID"]),
              "audit_attempt": int(os.environ["GITHUB_RUN_ATTEMPT"]),
              "previous_audit_summary_sha256": args.audit_summary_sha256, "original_evaluator_artifact": custody,
              "principal_evaluator": previous["principal_evaluator"], "external_observers": OBSERVERS,
              "system_import_observations": system_imports,
              "phases": results, "failures": failures, "immutable_payload_unchanged": True,
              "scope": "New headless Windows witnesses through unchanged packaged application; full qualification remains 43/32/17",
              "physical_owner_acceptance": "HOLD"}
    save(args.output / "summary.json", result)
    print("OBJECTSHARD_M4_WINDOWS_OWNER_SUPPLEMENT " + json.dumps({
        "status": result["status"], "source": SOURCE, "phases": {k: v["status"] for k, v in results.items()},
        "checks": {k: v["review"]["checks"] for k, v in results.items() if "review" in v},
        "failures": failures, "immutable_payload_unchanged": True, "physical_owner_acceptance": "HOLD"},
        sort_keys=True), flush=True)
    need(result["status"] == "passed", "New external Windows owner witnesses did not all qualify")
    for filename in ("summary.json", "author-receipt.json", "reopen-receipt.json", "live-cut-receipt.json"):
        audit.emit_original_bytes("OBJECTSHARD_M4_ORIGINAL_JSON", {"filename": filename,
                                  "application_source": SOURCE, "qualification_run": audit.RUN},
                                  (args.output / filename).read_bytes())
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("audit-summary", "output", "work"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--audit-summary-sha256", required=True)
    args = parser.parse_args()
    args.audit_summary, args.output, args.work = (p.resolve() for p in (args.audit_summary, args.output, args.work))
    try:
        run(args)
    except Exception as error:
        save(args.output / "runner-failure.json", {"status": "failed", "application_source": SOURCE,
            "error_type": type(error).__name__, "error": str(error), "physical_owner_acceptance": "HOLD"})
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
