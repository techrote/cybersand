#!/usr/bin/env python3
"""NONQUALIFYING exact-input FXC replay; no Godot, device, renderer or native World.

The original O2 call and its one-bit skip-optimization contrast run once each in
fresh, bounded processes. Validation stays enabled. This diagnoses compiler cost;
it cannot establish graphical correctness, frame rate or a production remedy.
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
CASES = (("original-o2", 0xC000), ("skip-optimization-only", 0xC004))
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
                identity.get("expected_system_sha256") == manifest["system_original"]["sha256"],
                "Original authentic compiler identities disagree")
    return source, {"original_artifact_id": ARTIFACT_ID, "original_run_id": RUN_ID,
                    "original_artifact": record(archive_path), "original_metadata": record(metadata_path),
                    "original_source_commit": SOURCE_COMMIT, "production_shader_sha256": SHADER_SHA256,
                    "captured_hlsl_sha256": SOURCE_SHA256, "captured_hlsl_bytes": SOURCE_BYTES,
                    "original_trace_path": TRACE_PATH, "original_trace_sha256": sha256(trace_raw),
                    "original_call": begin, "system_original": manifest["system_original"]}


def validate_case(name: str, flags: int) -> None:
    require((name, flags) in CASES, "Unregistered compiler case")
    require(flags & 0x2 == 0, "Compiler validation must remain enabled")
    require(flags ^ 0xC000 in (0, 0x4), "Only the skip-optimization bit may differ")


def compiler_child(input_path: Path, receipt_path: Path, output: Path, name: str, flags: int,
                   preflight: bool) -> int:
    require(os.name == "nt" and ctypes.sizeof(ctypes.c_void_p) == 8, "Native Windows x64 is required")
    validate_case(name, flags)
    output.mkdir(exist_ok=False)
    receipt = json.loads(receipt_path.read_text())
    source = input_path.read_bytes()
    require(len(source) == SOURCE_BYTES and sha256(source) == SOURCE_SHA256, "Replay source changed")
    if preflight:
        # Separate tiny API check: never Godot, the palette or a renderer cache.
        source = PREFLIGHT_SOURCE

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
    begin = {"scope": "NONQUALIFYING compiler-only replay", "preflight": preflight,
             "case": name, "pid": os.getpid(), "tid": kernel.GetCurrentThreadId(),
             "compiler_path": str(compiler_path), "compiler": before,
             "source_bytes": len(source), "source_sha256": sha256(source),
             "source_name": "C:\\fakepath", "entry": "main", "target": "ps_5_0",
             "macros": [["ANGLE_ENABLE_LOOP_FLATTEN", "1"]], "include_pointer_present": False,
             "flags1": flags, "flags2": 0, "thread_before": thread_before, "process_before": process_before,
             "utc": dt.datetime.now(dt.timezone.utc).isoformat()}
    json_new(output / "begin.json", begin)
    print("PACE003_FXC_BEGIN " + json.dumps(begin), flush=True)
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
    print("PACE003_FXC_COMPILE_RETURN " + json.dumps(returned), flush=True)
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
        print("PACE003_FXC_END " + json.dumps(end), flush=True)
        return 0 if result >= 0 else 1
    finally:
        release(assembly)
        release(messages)
        release(code)


def validate_child_records(row_dir: Path, begin: dict | None, end: dict | None, *,
                           name: str, flags: int, preflight: bool, pid: int, compiler_sha256: str) -> None:
    """Bind any actual compiler evidence to this process and authenticated inputs."""
    validate_case(name, flags)
    if begin is None:
        require(end is None, "Compiler end has no retained begin")
        return
    expected_source = sha256(PREFLIGHT_SOURCE) if preflight else SOURCE_SHA256
    expected_size = len(PREFLIGHT_SOURCE) if preflight else SOURCE_BYTES
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


def result_status(timed_out: bool, returncode: int, begin: dict | None, end: dict | None, *,
                  decision_elapsed_s: float, case_limit_s: float) -> str:
    require(math.isfinite(decision_elapsed_s) and decision_elapsed_s >= 0
            and math.isfinite(case_limit_s) and case_limit_s > 0, "Invalid process deadline observation")
    if timed_out:
        return "case_timeout"
    # The inherited monitor can observe an already-exited child on its loop
    # condition before testing the clock. Never turn that scheduling seam into
    # success. Diagnostic cleanup may also postpone this observation; retain a
    # conservative unproven result rather than inventing an exact exit time.
    if decision_elapsed_s > case_limit_s:
        return "deadline_not_proven"
    return "compile_completed" if returncode == 0 and begin is not None and end is not None and end.get(
        "compile_succeeded") is True else "compile_failed"


def run_case(output: Path, input_path: Path, receipt_path: Path, name: str, flags: int,
             preflight: bool) -> dict:
    import psutil
    sys.path.insert(0, str(ROOT / "tools/ci"))
    import godot_process_monitor as monitor
    import godot_timeout_diagnostics as diagnostics

    validate_case(name, flags)
    name_on_disk = ("preflight-" if preflight else "") + name
    row_dir = output / name_on_disk
    require(not row_dir.exists(), "Original process output already exists")
    log_path = output / (name_on_disk + ".log")
    command = [sys.executable, "-B", str(Path(__file__).resolve()), "--child", "--input", str(input_path),
               "--input-receipt", str(receipt_path), "--output", str(row_dir), "--case", name,
               "--flags", str(flags)] + (["--preflight"] if preflight else [])
    timeout = 30.0 if preflight else CASE_SECONDS
    timeout_snapshot = None
    with log_path.open("xb") as log:
        started = time.perf_counter()
        child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                 creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        def on_timeout(now: float) -> None:
            nonlocal timeout_snapshot
            timeout_snapshot = {"case_elapsed_s": now - started, "pid": child.pid}
            try:
                process = psutil.Process(child.pid)
                timeout_snapshot["process_cpu_times"] = process.cpu_times()._asdict()
                timeout_snapshot["threads"] = [thread._asdict() for thread in process.threads()]
            except (psutil.Error, OSError) as error:
                timeout_snapshot["snapshot_error"] = str(error)
            json_new(output / (name_on_disk + "-timeout.json"), timeout_snapshot)
        try:
            timed_out, timeout_kind, capture_error = monitor.wait(child, "pace003-fxc-" + name_on_disk,
                timeout, started, log_path, output / (name_on_disk + "-diagnostic"), on_timeout=on_timeout)
            decision_elapsed = time.perf_counter() - started
        finally:
            if child.poll() is None:
                diagnostics.stop_process_tree(child)
        child.wait(timeout=5)
    begin_path, end_path = row_dir / "begin.json", row_dir / "end.json"
    return_path = row_dir / "compile-return.json"
    begin = json.loads(begin_path.read_text()) if begin_path.is_file() else None
    returned = json.loads(return_path.read_text()) if return_path.is_file() else None
    end = json.loads(end_path.read_text()) if end_path.is_file() else None
    validate_child_records(row_dir, begin, end, name=name, flags=flags, preflight=preflight, pid=child.pid,
                           compiler_sha256=json.loads(receipt_path.read_text())["system_original"]["sha256"])
    validate_compile_return(begin, returned, end)
    row = {"name": name_on_disk, "preflight": preflight, "flags1": flags, "flags2": 0,
           "command": command, "pid": child.pid, "case_limit_s": timeout,
           "case_decision_elapsed_s": timeout_snapshot["case_elapsed_s"] if timed_out else decision_elapsed,
           "completion_observation_elapsed_s": decision_elapsed,
           "completion_observed_within_limit": not timed_out and decision_elapsed <= timeout,
           "deadline_observation_limit": "Observed after monitor/diagnostic cleanup; a late observation is conservatively refused even if actual exit may have been earlier",
           "cleanup_completed_elapsed_s": time.perf_counter() - started, "returncode": child.returncode,
           "timed_out": timed_out, "timeout_kind": timeout_kind, "diagnostic_error": capture_error,
           "timeout_snapshot": timeout_snapshot, "begin": begin, "compile_return": returned, "end": end,
           "compile_api_return_observed": returned is not None,
           "diagnostic_postprocessing_complete": end is not None,
           "status": result_status(timed_out, child.returncode, begin, end,
                                   decision_elapsed_s=decision_elapsed, case_limit_s=timeout),
           "log": record(log_path), "graphical_qualification": False}
    json_new(output / (name_on_disk + "-process.json"), row)
    print("PACE003_FXC_PROCESS " + json.dumps(row), flush=True)
    return row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--metadata", type=Path)
    parser.add_argument("--expected-source-sha")
    parser.add_argument("--child", action="store_true")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--input-receipt", type=Path)
    parser.add_argument("--case")
    parser.add_argument("--flags", type=int)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    args.output = args.output.resolve()
    if args.child:
        return compiler_child(args.input, args.input_receipt, args.output, args.case, args.flags, args.preflight)
    require(os.name == "nt", "Replay execution requires Windows; use unit tests for offline readers")
    require(args.archive is not None and args.metadata is not None, "Exact original ZIP and metadata are required")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    require(head == args.expected_source_sha, "Replay executable source head differs")
    require(not subprocess.check_output(["git", "diff", "HEAD", "--name-only"], cwd=ROOT, text=True).strip(),
            "Replay source checkout is modified")
    args.output.mkdir(exist_ok=False)
    source, receipt = read_original(args.archive, args.metadata)
    input_path, receipt_path = args.output / "captured-call44.hlsl", args.output / "input-receipt.json"
    write_new(input_path, source)
    json_new(receipt_path, receipt)
    source_files = ["tools/diagnostics/replay_pace003_hlsl.py", "tools/diagnostics/test_replay_pace003_hlsl.py",
                    ".github/workflows/play-pace003-hlsl-replay.yml", "tools/ci/godot_process_monitor.py",
                    "tools/ci/godot_timeout_diagnostics.py", "tools/ci/physical_progress_watchdog.py"]
    source_receipts = []
    retained = args.output / "retained-source"
    retained.mkdir()
    for path in source_files:
        data = (ROOT / path).read_bytes()
        artifact_path = "workflow-source/" + Path(path).name if path.startswith(".github/") else path
        destination = retained / artifact_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        source_receipts.append({"path": path, "artifact_path": artifact_path, **write_new(destination, data)})
    before_sources = {path: sha256((ROOT / path).read_bytes()) for path in source_files}
    report = {"scope": "NONQUALIFYING compiler-only experiment; no Godot, graphics device or native World",
              "source_head": head, "source_tree": subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"],
                  cwd=ROOT, text=True).strip(), "source_files": source_receipts, "input": receipt,
              "case_limit_s": CASE_SECONDS, "cold_process_per_case": True,
              "qualification_passed": False, "rows": [], "errors": [],
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat()}
    try:
        preflights = [run_case(args.output, input_path, receipt_path, name, flags, True) for name, flags in CASES]
        report["preflights"] = preflights
        require(all(row["status"] == "compile_completed" for row in preflights), "Tiny API preflight failed; no palette execution")
        for name, flags in CASES:
            report["rows"].append(run_case(args.output, input_path, receipt_path, name, flags, False))
        require(before_sources == {path: sha256((ROOT / path).read_bytes()) for path in source_files},
                "Replay executable source changed during execution")
        require(record(input_path)["sha256"] == SOURCE_SHA256, "Captured HLSL changed during execution")
    except Exception as error:
        report["errors"].append(type(error).__name__ + ": " + str(error))
    report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    report["status"] = "experiment_completed" if not report["errors"] and len(report["rows"]) == 2 else "apparatus_failed"
    final = json_new(args.output / "replay.json", report)
    print("PACE003_FXC_TERMINAL " + json.dumps(final), flush=True)
    # A failed original call remains red even if the modified-flags contrast succeeds.
    return 0 if report["status"] == "experiment_completed" and all(
        row["status"] == "compile_completed" for row in report["rows"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
