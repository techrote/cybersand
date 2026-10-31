#!/usr/bin/env python3
"""NONQUALIFYING source-pinned palette decomposition compiler experiment.

Adapted from frozen #312 replay at5de46847; production source is untouched.
No Godot, graphics device or native World is created. See the dated protocol.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ARTIFACT_ID = 13020405751
RUN_ID = 41139717684
ARTIFACT_BYTES = 3299869
ARTIFACT_SHA256 = "426dd61cb2dc13395c586b4e601f83f67f16865f1d101cd2dab28682be6b6fad"
SOURCE_SHA256 = "192c1a086d5124ce4b22cb172bd90876212779e4d6c67447f9278493ba3ff03c"
SOURCE_BYTES = 175942
SOURCE_COMMIT = "3b986726c52babe3013df48300d97f775392aa38"
SHADER_SHA256 = "426c2b8a829d6ca216659b73f7663ba6c7f6dddd300726b81ed1eec85bbd3e1d"
TRACE_PATH = "campaign/hoist-control-cold/d3d-trace/d3d-trace-5340.jsonl"
HLSL_PATH = "campaign/hoist-control-cold/d3d-trace/d3d-5340-44-source.hlsl"
MANIFEST_PATH = "d3d-compiler/build-receipt.json"
COMPILER_SHA256 = "64054871e088d47b4b7380f90efa40cf2f57bd966724764330a029f4fc3aa6eb"
FLAGS = 0xC000
BUDGET_SECONDS = 20.0
INVALID_PREFIX = b"#error PACE003_EXPECTED_INVALID_SOURCE_CONTROL\n"
import pace003_decomposition_variants as variants
CASES = ("tiny-valid", "invalid-source") + variants.CASES
CASE_SECONDS = 180.0
MAX_BLOB_BYTES = 64 * 1024 * 1024
PREFLIGHT_SOURCE = b"float4 main(float4 p:SV_Position):SV_Target0{return float4(0.25,0.5,0.75,1.0);}\n"


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def record(path: Path) -> dict:
    data = path.read_bytes()
    return {"file": path.name, "bytes": len(data), "sha256": sha256(data)}


def write_new(path: Path, data: bytes) -> dict:
    with path.open("xb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    return record(path)


def json_new(path: Path, value: dict) -> dict:
    return write_new(path, (json.dumps(value, indent=2) + "\n").encode())


def read_original(archive_path: Path, metadata_path: Path) -> tuple[bytes, dict]:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8-sig"))
    require(metadata.get("id") == ARTIFACT_ID and metadata.get("workflow_run", {}).get("id") == RUN_ID
            and metadata.get("expired") is False, "Original artifact metadata mismatch")
    raw = archive_path.read_bytes()
    require(len(raw) == ARTIFACT_BYTES and sha256(raw) == ARTIFACT_SHA256, "Original ZIP identity mismatch")
    with zipfile.ZipFile(archive_path) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        require(len(names) == len(set(names)), "Duplicate original ZIP entry")
        for entry in entries:
            name = entry.filename
            path = PurePosixPath(name)
            require(bool(name) and not path.is_absolute() and ".." not in path.parts
                    and "\\" not in name and ":" not in name
                    and not stat.S_ISLNK(entry.external_attr >> 16), "Unsafe original ZIP entry")
        require(archive.testzip() is None, "Original ZIP CRC failure")
        trace_raw = archive.read(TRACE_PATH)
        require(trace_raw.endswith(b"\n"), "Original trace is truncated")
        events = [json.loads(line) for line in trace_raw.splitlines()]
        begins = [event for event in events if event.get("event") == "compile_begin" and event.get("call") == 44]
        require(len(begins) == 1 and not any(event.get("event") == "compile_end" and event.get("call") == 44
                                          for event in events), "Expected original open call44 is absent")
        begin = begins[0]
        source = archive.read(HLSL_PATH)
        manifest = json.loads(archive.read(MANIFEST_PATH))
        require(len(source) == SOURCE_BYTES and sha256(source) == SOURCE_SHA256, "Captured HLSL identity mismatch")
        require(begin.get("api") == "D3DCompile" and begin.get("flags1") == 0xC000
                and begin.get("flags2") == 0 and begin.get("include_pointer_present") is False
                and begin.get("secondary_flags") == 0 and begin.get("secondary_size") == 0,
                "Original compiler API inputs differ")
        for key, expected in (("source_name", "C:\\fakepath"), ("entry", "main"), ("target", "ps_5_0")):
            require(begin.get(key) == {"value": expected, "truncated": False}, "Original " + key + " differs")
        require(begin.get("defines_present") is True and begin.get("defines_truncated") is False
                and begin.get("defines") == [{"name": {"value": "ANGLE_ENABLE_LOOP_FLATTEN", "truncated": False},
                                               "definition": {"value": "1", "truncated": False}}],
                "Original macro inputs differ")
        require(begin.get("source") == {"file": PurePosixPath(HLSL_PATH).name,
                "bytes": SOURCE_BYTES, "written": SOURCE_BYTES, "complete": True}, "Original source capture is incomplete")
        identity = events[0]
        require(identity.get("event") == "identity" and identity.get("system_sha256") ==
                identity.get("expected_system_sha256") == manifest["system_original"]["sha256"] == COMPILER_SHA256,
                "Original authentic compiler identities disagree")
    return source, {"original_artifact_id": ARTIFACT_ID, "original_run_id": RUN_ID,
                    "original_artifact": record(archive_path), "original_metadata": record(metadata_path),
                    "original_source_commit": SOURCE_COMMIT, "production_shader_sha256": SHADER_SHA256,
                    "captured_hlsl_sha256": SOURCE_SHA256, "captured_hlsl_bytes": SOURCE_BYTES,
                    "original_trace_path": TRACE_PATH, "original_trace_sha256": sha256(trace_raw),
                    "original_call": begin, "system_original": manifest["system_original"]}



def compiler_child(input_path: Path, receipt_path: Path, output: Path, name: str) -> int:
    require(os.name == "nt" and ctypes.sizeof(ctypes.c_void_p) == 8, "Native Windows x64 is required")
    require(name in CASES, "Unregistered compiler case")
    flags = FLAGS
    preflight = name == "tiny-valid"
    output.mkdir(exist_ok=False)
    receipt = json.loads(receipt_path.read_text())
    source = input_path.read_bytes()
    original = (receipt_path.parent / "captured-call44.hlsl").read_bytes()
    expected, generated_receipt = generate_case(original, name)
    require(source == expected, "Generated compiler source changed")
    require(receipt["system_original"]["sha256"] == COMPILER_SHA256, "Original compiler receipt changed")

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetSystemDirectoryW.argtypes = [wintypes.LPWSTR, wintypes.UINT]
    kernel.GetSystemDirectoryW.restype = wintypes.UINT
    kernel.GetModuleFileNameW.argtypes = [wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD]
    kernel.GetModuleFileNameW.restype = wintypes.DWORD
    kernel.GetCurrentProcess.argtypes = []
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    kernel.GetCurrentThread.argtypes = []
    kernel.GetCurrentThread.restype = wintypes.HANDLE
    kernel.GetCurrentThreadId.argtypes = []
    kernel.GetCurrentThreadId.restype = wintypes.DWORD
    for api in (kernel.GetProcessTimes, kernel.GetThreadTimes):
        api.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        api.restype = wintypes.BOOL
    path_buffer = ctypes.create_unicode_buffer(32768)
    count = kernel.GetSystemDirectoryW(path_buffer, len(path_buffer))
    require(0 < count < len(path_buffer), "GetSystemDirectoryW failed")
    compiler_path = Path(path_buffer.value, "d3dcompiler_47.dll").resolve()
    before = record(compiler_path)
    require(before["sha256"] == receipt["system_original"]["sha256"], "Hosted System32 compiler changed from original")
    compiler = ctypes.WinDLL(str(compiler_path), winmode=0x100 | 0x800, use_last_error=True)
    count = kernel.GetModuleFileNameW(compiler._handle, path_buffer, len(path_buffer))
    require(0 < count < len(path_buffer) and Path(path_buffer.value).resolve() == compiler_path,
            "Loaded compiler is not the authenticated native System32 module")

    class Macro(ctypes.Structure):
        _fields_ = [("Name", ctypes.c_char_p), ("Definition", ctypes.c_char_p)]

    macros = (Macro * 2)(Macro(b"ANGLE_ENABLE_LOOP_FLATTEN", b"1"), Macro(None, None))
    compile_call = compiler.D3DCompile
    compile_call.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.POINTER(Macro),
                            ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, wintypes.UINT,
                            wintypes.UINT, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p)]
    compile_call.restype = ctypes.c_int32
    disassemble = compiler.D3DDisassemble
    disassemble.argtypes = [ctypes.c_void_p, ctypes.c_size_t, wintypes.UINT, ctypes.c_char_p,
                           ctypes.POINTER(ctypes.c_void_p)]
    disassemble.restype = ctypes.c_int32

    def cpu(api, handle) -> dict:
        values = [wintypes.FILETIME() for _ in range(4)]
        require(bool(api(handle, *(ctypes.byref(value) for value in values))), "Get CPU times failed")
        ticks = lambda value: (value.dwHighDateTime << 32) | value.dwLowDateTime
        return {"kernel_100ns": ticks(values[2]), "user_100ns": ticks(values[3])}

    def blob_bytes(pointer) -> bytes | None:
        if not pointer.value:
            return None
        vtable = ctypes.cast(pointer, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
        get_pointer = ctypes.WINFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p)(vtable[3])
        get_size = ctypes.WINFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p)(vtable[4])
        size = get_size(pointer)
        require(size <= MAX_BLOB_BYTES, "Compiler output exceeds declared capture bound")
        address = get_pointer(pointer)
        require(bool(address) or size == 0, "Nonempty compiler blob has no storage")
        return ctypes.string_at(address, size)

    def release(pointer) -> None:
        if pointer.value:
            vtable = ctypes.cast(pointer, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
            ctypes.WINFUNCTYPE(wintypes.ULONG, ctypes.c_void_p)(vtable[2])(pointer)
            pointer.value = None

    source_buffer = ctypes.create_string_buffer(source)
    code, messages = ctypes.c_void_p(), ctypes.c_void_p()
    thread_handle, process_handle = kernel.GetCurrentThread(), kernel.GetCurrentProcess()
    thread_before, process_before = cpu(kernel.GetThreadTimes, thread_handle), cpu(kernel.GetProcessTimes, process_handle)
    begin = {"scope": "NONQUALIFYING palette decomposition compiler-only experiment", "preflight": preflight,
             "case": name, "pid": os.getpid(), "tid": kernel.GetCurrentThreadId(),
             "compiler_path": str(compiler_path), "compiler": before,
             "source_bytes": len(source), "source_sha256": sha256(source),
             "generator_receipt_sha256": sha256(json_bytes(generated_receipt)),
             "source_name": "C:\\fakepath", "entry": "main", "target": "ps_5_0",
             "macros": [["ANGLE_ENABLE_LOOP_FLATTEN", "1"]], "include_pointer_present": False,
             "flags1": flags, "flags2": 0, "thread_before": thread_before, "process_before": process_before,
             "utc": dt.datetime.now(dt.timezone.utc).isoformat()}
    json_new(output / "begin.json", begin)
    print("PACE003_DECOMPOSITION_BEGIN " + json.dumps(begin), flush=True)
    # Timing excludes receipt I/O; the unchanged parent case clock includes it.
    thread_start, process_start = cpu(kernel.GetThreadTimes, thread_handle), cpu(kernel.GetProcessTimes, process_handle)
    started = time.perf_counter_ns()
    result = compile_call(source_buffer, len(source), b"C:\\fakepath", macros, None,
                          b"main", b"ps_5_0", flags, 0, ctypes.byref(code), ctypes.byref(messages))
    ended = time.perf_counter_ns()
    thread_end, process_end = cpu(kernel.GetThreadTimes, thread_handle), cpu(kernel.GetProcessTimes, process_handle)
    cpu_delta = lambda first, last: sum(last.values()) / 1e7 - sum(first.values()) / 1e7
    returned = {"case": name, "preflight": preflight, "pid": begin["pid"], "tid": begin["tid"],
                "flags1": flags, "flags2": 0, "hresult": result & 0xFFFFFFFF,
                "compile_succeeded": result >= 0, "wall_s": (ended - started) / 1e9,
                "thread_cpu_s": cpu_delta(thread_start, thread_end),
                "process_cpu_s": cpu_delta(process_start, process_end),
                "thread_start": thread_start, "thread_end": thread_end,
                "process_start": process_start, "process_end": process_end}
    # This stage receipt precedes blob copies, disassembly and DLL rehashing.
    # A later diagnostic timeout cannot masquerade as an open compiler API.
    json_new(output / "compile-return.json", returned)
    print("PACE003_DECOMPOSITION_COMPILE_RETURN " + json.dumps(returned), flush=True)
    files = []
    assembly = ctypes.c_void_p()
    disassembly_result = None
    try:
        code_data, message_data = blob_bytes(code), blob_bytes(messages)
        if code_data is not None:
            files.append(write_new(output / "bytecode.bin", code_data))
        if message_data is not None:
            files.append(write_new(output / "messages.bin", message_data))
        if result >= 0:
            require(bool(code_data) and code_data.startswith(b"DXBC"), "Successful compile has no DXBC bytecode")
            code_buffer = ctypes.create_string_buffer(code_data)
            disassembly_result = disassemble(code_buffer, len(code_data), 0, None, ctypes.byref(assembly))
            assembly_data = blob_bytes(assembly)
            if assembly_data is not None:
                files.append(write_new(output / "disassembly.txt", assembly_data))
            require(disassembly_result >= 0 and bool(assembly_data), "Successful bytecode cannot be disassembled")
        require(record(compiler_path) == before, "Authentic compiler changed during execution")
        end = {**returned,
               "files": files, "disassembly_hresult": disassembly_result,
               "compiler_unchanged": True, "validation_disabled": False}
        json_new(output / "end.json", end)
        print("PACE003_DECOMPOSITION_END " + json.dumps(end), flush=True)
        return 0 if result >= 0 else 1
    finally:
        release(assembly)
        release(messages)
        release(code)


def validate_child_records(row_dir: Path, begin: dict | None, end: dict | None, *,
                           name: str, flags: int, preflight: bool, pid: int, compiler_sha256: str) -> None:
    """Bind any actual compiler evidence to this process and authenticated inputs."""
    require(name in CASES and flags == FLAGS, "Unregistered case or compiler flags")
    if begin is None:
        require(end is None, "Compiler end has no retained begin")
        return
    source = (row_dir.parent / "inputs" / (name + ".hlsl")).read_bytes()
    original = (row_dir.parent / "captured-call44.hlsl").read_bytes()
    expected, generated_receipt = generate_case(original, name)
    require(source == expected, "Retained input differs from registered generation")
    expected_source, expected_size = sha256(source), len(source)
    require(begin.get("generator_receipt_sha256") == sha256(json_bytes(generated_receipt)), "Generator receipt differs")
    require(begin.get("case") == name and begin.get("pid") == pid and begin.get("preflight") is preflight
            and type(begin.get("tid")) is int and begin["tid"] > 0, "Compiler process identity differs")
    require(begin.get("source_sha256") == expected_source and begin.get("source_bytes") == expected_size
            and begin.get("flags1") == flags and begin.get("flags2") == 0
            and begin.get("source_name") == "C:\\fakepath" and begin.get("entry") == "main"
            and begin.get("target") == "ps_5_0" and begin.get("include_pointer_present") is False
            and begin.get("macros") == [["ANGLE_ENABLE_LOOP_FLATTEN", "1"]], "Executed compiler inputs differ")
    require(begin.get("compiler", {}).get("sha256") == compiler_sha256, "Executed compiler identity differs")
    if end is None:
        return
    require(end.get("case") == name and end.get("preflight") is preflight, "Compiler result belongs to another case")
    require(type(end.get("hresult")) is int and 0 <= end["hresult"] <= 0xFFFFFFFF
            and end.get("compile_succeeded") is (end["hresult"] < 0x80000000), "Compiler HRESULT/success contradiction")
    require(end.get("compiler_unchanged") is True and end.get("validation_disabled") is False,
            "Compiler identity or validation control changed")
    for key in ("wall_s", "thread_cpu_s", "process_cpu_s"):
        require(type(end.get(key)) in (float, int) and math.isfinite(end[key]) and end[key] >= 0,
                "Invalid compiler timing: " + key)
    files = end.get("files")
    require(isinstance(files, list) and len({item.get("file") for item in files}) == len(files),
            "Compiler output inventory is missing or duplicated")
    for item in files:
        require(item.get("file") in ("bytecode.bin", "messages.bin", "disassembly.txt"), "Unexpected compiler output")
        require(record(row_dir / item["file"]) == item, "Compiler output bytes changed")
    if not end["compile_succeeded"]:
        require(not any(item["file"] == "bytecode.bin" for item in files), "Rejected input unexpectedly has bytecode")
    if end["compile_succeeded"]:
        names = {item["file"] for item in files}
        require({"bytecode.bin", "disassembly.txt"}.issubset(names)
                and (row_dir / "bytecode.bin").read_bytes().startswith(b"DXBC")
                and (row_dir / "disassembly.txt").stat().st_size > 0
                and type(end.get("disassembly_hresult")) is int and end["disassembly_hresult"] >= 0,
                "Successful compile lacks valid retained bytecode/disassembly")


def validate_compile_return(begin: dict | None, returned: dict | None, end: dict | None) -> None:
    if returned is None:
        require(end is None, "Postprocessing result has no retained compile return")
        return
    require(begin is not None, "Compile return has no retained begin")
    for key in ("case", "preflight", "pid", "tid", "flags1", "flags2"):
        require(returned.get(key) == begin.get(key), "Compile return identity differs: " + key)
    require(type(returned.get("hresult")) is int and 0 <= returned["hresult"] <= 0xFFFFFFFF
            and returned.get("compile_succeeded") is (returned["hresult"] < 0x80000000),
            "Compile return HRESULT/success contradiction")
    for key in ("wall_s", "thread_cpu_s", "process_cpu_s"):
        require(type(returned.get(key)) in (float, int) and math.isfinite(returned[key]) and returned[key] >= 0,
                "Invalid compile return timing: " + key)
    for prefix in ("thread", "process"):
        first, last = returned.get(prefix + "_start"), returned.get(prefix + "_end")
        require(isinstance(first, dict) and isinstance(last, dict)
                and set(first) == set(last) == {"kernel_100ns", "user_100ns"}
                and all(type(first[key]) is int and type(last[key]) is int
                        and 0 <= first[key] <= last[key] for key in first), "Invalid original CPU counters")
        measured = sum(last.values()) / 1e7 - sum(first.values()) / 1e7
        require(math.isclose(measured, returned[prefix + "_cpu_s"], abs_tol=1e-10),
                "Compile return CPU duration differs from original counters")
    if end is not None:
        require(all(end.get(key) == value for key, value in returned.items()),
                "Postprocessing changed the recorded compiler return")


def json_bytes(value) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def generate_case(original: bytes, name: str) -> tuple[bytes, dict]:
    variants.validate_source(original)
    require(name in CASES, "Unregistered compiler case")
    if name in variants.CASES:
        return variants.generate(original, name)
    source = PREFLIGHT_SOURCE if name == "tiny-valid" else INVALID_PREFIX + original
    return source, {"case": name, "source_bytes": len(source), "source_sha256": sha256(source),
                    "original_sha256": SOURCE_SHA256,
                    "kind": "tiny valid API control" if name == "tiny-valid" else "explicit preprocessor rejection control"}


def classify_row(row: dict) -> str:
    """Only a completed compiler call can pass either API control."""
    begin, returned, end = row.get("begin"), row.get("compile_return"), row.get("end")
    if begin is None:
        return "apparatus_failed"
    if row.get("timed_out"):
        return "compiler_timeout" if returned is None else "postprocessing_timeout"
    if not row.get("completion_observed_within_limit"):
        return "deadline_not_proven"
    if returned is None or end is None:
        return "apparatus_failed"
    if end.get("compile_succeeded") is True and row.get("returncode") == 0:
        return "compiled"
    if end.get("compile_succeeded") is False and row.get("returncode") == 1:
        messages = [item for item in end.get("files", []) if item.get("file") == "messages.bin"]
        if len(messages) == 1 and messages[0].get("bytes", 0) > 0:
            return "compiler_rejected"
    return "apparatus_failed"


def adjudicate(rows: list[dict], errors: list[str]) -> dict:
    by_name = {row["name"]: row for row in rows}
    complete = len(rows) == len(CASES) and tuple(row["name"] for row in rows) == CASES
    controls = complete and by_name["tiny-valid"]["status"] == "compiled" and by_name[
        "invalid-source"]["status"] == "compiler_rejected"
    invalid_text = by_name.get("invalid-source", {}).get("diagnostic_control_marker", False)
    controls = controls and invalid_text is True
    apparatus_ok = complete and controls and not errors and all(row["status"] not in (
        "apparatus_failed", "postprocessing_timeout", "deadline_not_proven") for row in rows)
    decisions = {}
    for family, names in variants.FAMILIES.items():
        members = [by_name[name] for name in names if name in by_name]
        all_compiled = len(members) == len(names) and all(row["status"] == "compiled" for row in members)
        compile_total = sum(row["compile_return"]["wall_s"] for row in members) if all_compiled else None
        process_total = sum(row["completion_observation_elapsed_s"] for row in members) if all_compiled else None
        fits = all_compiled and compile_total <= BUDGET_SECONDS and process_total <= BUDGET_SECONDS
        decision = "INCONCLUSIVE" if not apparatus_ok else "GO_PROTOTYPE" if fits else "NO_GO_TESTED_FAMILY"
        decisions[family] = {"programs": list(names), "all_compiled": all_compiled,
                            "serial_compile_wall_s": compile_total, "serial_process_observation_s": process_total,
                            "budget_s": BUDGET_SECONDS, "decision": decision,
                            "reason": "apparatus/control/integrity failure" if not apparatus_ok else
                            "complete family fits both compiler and process budgets" if fits else
                            "required program failed or serial budget exceeded"}
    decision = "INCONCLUSIVE" if not apparatus_ok else "GO_PROTOTYPE" if any(
        item["decision"] == "GO_PROTOTYPE" for item in decisions.values()) else "NO_GO_TESTED_DECOMPOSITION"
    return {"decision": decision, "controls_passed": controls, "apparatus_completed": apparatus_ok,
            "families": decisions, "graphical_qualification": False, "main_startup_qualified": False,
            "scope": "Compiler feasibility of these exact inputs only; GO proposes a separately qualified renderer prototype"}


def run_case(output: Path, name: str) -> dict:
    import psutil
    require(psutil.__version__ == "7.1.3", "Process measurement dependency differs")
    row_dir = output / name
    require(not row_dir.exists(), "Original process output already exists")
    log_path = output / (name + ".log")
    input_path = output / "inputs" / (name + ".hlsl")
    command = [sys.executable, "-B", str(Path(__file__).resolve()), "--child", "--input", str(input_path),
               "--input-receipt", str(output / "input-receipt.json"), "--output", str(row_dir), "--case", name]
    limit = 30.0 if name in ("tiny-valid", "invalid-source") else CASE_SECONDS
    timed_out, snapshot, cleanup_error = False, None, None
    with log_path.open("xb") as log:
        started = time.perf_counter()
        child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                 creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        try:
            while True:
                observed_exit = child.poll()
                elapsed = time.perf_counter() - started
                if observed_exit is not None:
                    # An exit first observed after the boundary never passes.
                    decision_elapsed = elapsed
                    break
                if elapsed >= limit:
                    timed_out, decision_elapsed = True, elapsed
                    snapshot = {"pid": child.pid, "observed_elapsed_s": elapsed,
                                "scope": "Parent observation after deadline; CPU includes process setup and possible overshoot"}
                    try:
                        process = psutil.Process(child.pid)
                        snapshot["process_cpu_times"] = process.cpu_times()._asdict()
                        snapshot["threads"] = [thread._asdict() for thread in process.threads()]
                        snapshot["memory_info"] = process.memory_info()._asdict()
                    except (psutil.Error, OSError) as error:
                        snapshot["snapshot_error"] = str(error)
                    json_new(output / (name + "-timeout.json"), snapshot)
                    break
                time.sleep(min(0.05, max(0.001, limit - elapsed)))
        finally:
            if child.poll() is None:
                # This child invokes only an in-process compiler DLL and starts no descendants.
                child.kill()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                cleanup_error = "Compiler child did not exit after termination"
    read_optional = lambda filename: json.loads((row_dir / filename).read_text()) if (
        row_dir / filename).is_file() else None
    begin, returned, end = (read_optional(name) for name in ("begin.json", "compile-return.json", "end.json"))
    validate_child_records(row_dir, begin, end, name=name, flags=FLAGS, preflight=name == "tiny-valid",
                           pid=child.pid, compiler_sha256=COMPILER_SHA256)
    validate_compile_return(begin, returned, end)
    row = {"name": name, "command": command, "pid": child.pid, "flags1": FLAGS, "flags2": 0,
           "case_limit_s": limit, "timed_out": timed_out,
           "completion_observation_elapsed_s": decision_elapsed,
           "completion_observed_within_limit": not timed_out and decision_elapsed <= limit,
           "cleanup_completed_elapsed_s": time.perf_counter() - started,
           "cleanup_error": cleanup_error, "returncode": child.returncode,
           "timeout_snapshot": snapshot, "begin": begin, "compile_return": returned, "end": end,
           "log": record(log_path), "input": record(input_path), "graphical_qualification": False}
    row["diagnostic_control_marker"] = name == "invalid-source" and (row_dir / "messages.bin").is_file() and (
        b"PACE003_EXPECTED_INVALID_SOURCE_CONTROL" in (row_dir / "messages.bin").read_bytes())
    row["status"] = "apparatus_failed" if cleanup_error else classify_row(row)
    json_new(output / (name + "-process.json"), row)
    print("PACE003_DECOMPOSITION_PROCESS " + json.dumps(row), flush=True)
    return row


SOURCE_FILES = (
    "tools/diagnostics/run_pace003_decomposition.py",
    "tools/diagnostics/test_run_pace003_decomposition.py",
    "tools/diagnostics/pace003_decomposition_variants.py",
    "tools/diagnostics/test_pace003_decomposition_variants.py",
    ".github/workflows/play-pace003-palette-decomposition.yml",
)


def source_identity(expected: str, output: Path) -> dict:
    git = lambda *args: subprocess.check_output(["git", *args], cwd=ROOT)
    head, tree = git("rev-parse", "HEAD").decode().strip(), git("rev-parse", "HEAD^{tree}").decode().strip()
    require(head == expected, "Compiler harness HEAD differs from requested source")
    require(not git("diff", "HEAD", "--name-only").strip(), "Tracked source checkout is modified")
    source_files = []
    for name in SOURCE_FILES:
        data = (ROOT / name).read_bytes()
        require(data == git("show", "HEAD:" + name), "Executed source differs from committed bytes")
        artifact_path = "workflow-source/" + Path(name).name if name.startswith(".github/") else name
        destination = output / "retained-source" / artifact_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        source_files.append({"path": name, "artifact_path": artifact_path, **write_new(destination, data)})
    return {"source_head": head, "source_tree": tree, "source_files": source_files,
            "python_version": sys.version, "python_executable": record(Path(sys.executable)),
            "fresh_processes": True, "os_file_cache_coldness_proven": False}


def inventory(output: Path) -> list[dict]:
    result = []
    for path in sorted(output.rglob("*")):
        require(not path.is_symlink(), "Evidence symlink refused")
        if path.is_file() and path != output / "inventory.json":
            result.append({"path": path.relative_to(output).as_posix(), **record(path)})
    return result


def verify(output: Path, expected_source_sha: str) -> dict:
    """Fail closed on incomplete, altered or unregistered evidence, without Windows execution."""
    report = json.loads((output / "campaign.json").read_text())
    git = lambda *args: subprocess.check_output(["git", *args], cwd=ROOT)
    require(expected_source_sha and report["source"]["source_head"] == expected_source_sha,
            "Evidence source differs from independently requested head")
    require(report["source"]["source_tree"] == git("rev-parse", expected_source_sha + "^{tree}").decode().strip(),
            "Evidence source tree differs from immutable commit")
    originals = output / "retained-original"
    pinned_source, pinned_receipt = read_original(originals / report["original"]["original_artifact"]["file"],
                                                  originals / report["original"]["original_metadata"]["file"])
    require(report["original"] == pinned_receipt == json.loads((output / "input-receipt.json").read_text()),
            "Original archive/metadata receipt differs")
    original = (output / "captured-call44.hlsl").read_bytes()
    require(original == pinned_source, "Original HLSL differs from authenticated archive")
    variants.validate_source(original)
    require(report["case_order"] == list(CASES), "Campaign case registration differs")
    require(report["compiler_sha256"] == COMPILER_SHA256 and report["flags1"] == FLAGS
            and report["flags2"] == 0 and report["case_limit_s"] == CASE_SECONDS
            and report["budget_s"] == BUDGET_SECONDS, "Registered controls changed")
    require(report["rows"] == [json.loads((output / (name + "-process.json")).read_text())
                               for name in CASES], "Process inventory is incomplete or differs")
    pids = []
    for row in report["rows"]:
        name = row["name"]
        pids.append(row["pid"])
        source, receipt = generate_case(original, name)
        input_path = output / "inputs" / (name + ".hlsl")
        require(input_path.read_bytes() == source and record(input_path) == row["input"], "Executed input changed")
        require(json.loads((output / "inputs" / (name + ".json")).read_text()) == receipt, "Generation ledger changed")
        require(record(output / (name + ".log")) == row["log"], "Original process log changed")
        for filename, key in (("begin.json", "begin"), ("compile-return.json", "compile_return"), ("end.json", "end")):
            path = output / name / filename
            actual = json.loads(path.read_text()) if path.is_file() else None
            require(actual == row[key], "Original child record differs: " + name + "/" + filename)
        validate_child_records(output / name, row["begin"], row["end"], name=name, flags=FLAGS,
                               preflight=name == "tiny-valid", pid=row["pid"], compiler_sha256=COMPILER_SHA256)
        validate_compile_return(row["begin"], row["compile_return"], row["end"])
        require(row["case_limit_s"] == (30.0 if name in ("tiny-valid", "invalid-source") else CASE_SECONDS),
                "Process limit changed")
        elapsed = row["completion_observation_elapsed_s"]
        require(type(elapsed) in (int, float) and math.isfinite(elapsed) and elapsed >= 0, "Bad parent timing")
        require(row["completion_observed_within_limit"] is (not row["timed_out"] and elapsed <= row["case_limit_s"]),
                "Process deadline result contradicts observation")
        if row["timed_out"]:
            require(elapsed >= row["case_limit_s"] and row["timeout_snapshot"] == json.loads(
                (output / (name + "-timeout.json")).read_text()), "Deadline snapshot differs")
            require(row["timeout_snapshot"]["pid"] == row["pid"]
                    and row["timeout_snapshot"]["observed_elapsed_s"] == elapsed, "Deadline snapshot identity differs")
        else:
            require(row["timeout_snapshot"] is None and not (output / (name + "-timeout.json")).exists(),
                    "Unexpected timeout snapshot")
        if row["compile_return"] is not None and not row["timed_out"]:
            require(row["compile_return"]["wall_s"] <= elapsed, "Compiler time exceeds whole-process observation")
        require(row["status"] == ("apparatus_failed" if row["cleanup_error"] else classify_row(row)), "Classification differs")
        marker = name == "invalid-source" and (output / name / "messages.bin").is_file() and (
            b"PACE003_EXPECTED_INVALID_SOURCE_CONTROL" in (output / name / "messages.bin").read_bytes())
        require(row["diagnostic_control_marker"] is marker, "Invalid-source control diagnostic differs")
    # PIDs can be reused by the OS after a process exits; commands/records, not
    # uniqueness of the integer alone, authenticate separate invocations.
    require(report["adjudication"] == adjudicate(report["rows"], report["errors"]), "Decision differs on readback")
    require(tuple(item["path"] for item in report["source"]["source_files"]) == SOURCE_FILES,
            "Executed source inventory omitted, duplicated or reordered files")
    for item in report["source"]["source_files"]:
        expected_path = "workflow-source/" + Path(item["path"]).name if item["path"].startswith(".github/") else item["path"]
        require(item["artifact_path"] == expected_path, "Retained source path changed")
        path = output / "retained-source" / item["artifact_path"]
        require(record(path) == {key: item[key] for key in ("file", "bytes", "sha256")}, "Retained source changed")
        require(path.read_bytes() == git("show", expected_source_sha + ":" + item["path"]),
                "Retained source is not the immutable commit content")
    require(json.loads((output / "inventory.json").read_text())["files"] == inventory(output), "Evidence inventory differs")
    return {"verified": True, "source_head": report["source"]["source_head"],
            "decision": report["adjudication"]["decision"], "original_rows": len(report["rows"]),
            "graphical_qualification": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--metadata", type=Path)
    parser.add_argument("--expected-source-sha")
    parser.add_argument("--authenticate-only", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--child", action="store_true")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--input-receipt", type=Path)
    parser.add_argument("--case")
    args = parser.parse_args()
    output = args.output.resolve()
    if args.verify:
        print(json.dumps(verify(output, args.expected_source_sha), indent=2))
        return 0
    if args.child:
        return compiler_child(args.input, args.input_receipt, output, args.case)
    require(args.archive is not None and args.metadata is not None, "Original archive and metadata are required")
    original, original_receipt = read_original(args.archive, args.metadata)
    output.mkdir(exist_ok=False)
    write_new(output / "captured-call44.hlsl", original)
    json_new(output / "input-receipt.json", original_receipt)
    if args.authenticate_only:
        print(json.dumps(original_receipt, indent=2))
        return 0
    require(os.name == "nt", "Compiler execution requires Windows")
    source = source_identity(args.expected_source_sha, output)
    (output / "retained-original").mkdir()
    write_new(output / "retained-original" / args.archive.name, args.archive.read_bytes())
    write_new(output / "retained-original" / args.metadata.name, args.metadata.read_bytes())
    (output / "inputs").mkdir()
    for name in CASES:
        generated, receipt = generate_case(original, name)
        write_new(output / "inputs" / (name + ".hlsl"), generated)
        json_new(output / "inputs" / (name + ".json"), receipt)
    variants.validate_plans()
    report = {"scope": "NONQUALIFYING compiler-only decomposition feasibility",
              "source": source, "original": original_receipt, "compiler_sha256": COMPILER_SHA256,
              "flags1": FLAGS, "flags2": 0, "case_order": list(CASES),
              "case_limit_s": CASE_SECONDS, "budget_s": BUDGET_SECONDS,
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "rows": [], "errors": []}
    for name in CASES:
        try:
            row = run_case(output, name)
            report["rows"].append(row)
            # A broken API control cannot justify executing the expensive palette.
            if name == "tiny-valid" and row["status"] != "compiled":
                raise ValueError("Tiny valid API control failed")
            if name == "invalid-source" and (row["status"] != "compiler_rejected" or not row["diagnostic_control_marker"]):
                raise ValueError("Invalid-source API control failed")
        except Exception as error:
            report["errors"].append(type(error).__name__ + ": " + str(error))
            break
    for item in source["source_files"]:
        if record(ROOT / item["path"])["sha256"] != item["sha256"]:
            report["errors"].append("Executed source changed: " + item["path"])
    report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    report["adjudication"] = adjudicate(report["rows"], report["errors"])
    json_new(output / "campaign.json", report)
    json_new(output / "inventory.json", {"files": inventory(output)})
    print("PACE003_DECOMPOSITION_DECISION " + json.dumps(report["adjudication"]), flush=True)
    return 0 if report["adjudication"]["decision"] == "GO_PROTOTYPE" else 1 if report[
        "adjudication"]["apparatus_completed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
