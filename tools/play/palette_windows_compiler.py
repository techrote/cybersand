#!/usr/bin/env python3
"""Read the shader compiler loaded by one live Windows engine process.

The caller must authenticate the fixture's PID/nonce/source marker. This helper
never guesses a System32 DLL, loads d3dcompiler, changes the target, or kills it.
Hash/version identify the file held open at the observed module path; they are
not an in-memory image hash or a substitute for the fixture's source identity.
"""
from __future__ import annotations

import argparse
import ctypes as C
import hashlib
import json
import math
import ntpath
import os
from pathlib import Path
import re
import subprocess
import sys
import time

SCHEMA = "palette-windows-compiler-v1"
MODULE = "d3dcompiler_47.dll"
MAX_MODULES = 4096
MAX_FILE_BYTES = 64 * 1024 * 1024
MAX_VERSION_BYTES = 1024 * 1024
MAX_REPLY_BYTES = 256 * 1024
SCOPE = ("Live requested-process module path; hash/version of the file held open "
         "at that path, not an in-memory image hash. No target process mutation.")


class Unavailable(Exception):
    pass


class FileTime(C.Structure):
    _fields_ = [("low", C.c_uint32), ("high", C.c_uint32)]

    def value(self):
        return self.low | (self.high << 32)


class FileInfo(C.Structure):
    _fields_ = [("attributes", C.c_uint32), ("created", FileTime),
                ("accessed", FileTime), ("written", FileTime),
                ("volume", C.c_uint32), ("size_high", C.c_uint32),
                ("size_low", C.c_uint32), ("links", C.c_uint32),
                ("index_high", C.c_uint32), ("index_low", C.c_uint32)]


class VersionInfo(C.Structure):
    _fields_ = [(name, C.c_uint32) for name in (
        "signature", "structure_version", "file_ms", "file_ls",
        "product_ms", "product_ls", "flags_mask", "flags", "os", "type",
        "subtype", "date_ms", "date_ls")]


def _require(value, reason):
    if not value:
        raise Unavailable(reason)


class WindowsReader:
    """Only query/read handles; no PROCESS_TERMINATE or PROCESS_VM_WRITE rights."""

    def __init__(self, pid, deadline):
        _require(sys.platform == "win32" and C.sizeof(C.c_void_p) == 8,
                 "64-bit Windows observer required")
        self.deadline = deadline
        self.kernel = C.WinDLL("kernel32.dll", use_last_error=True)
        self.version = C.WinDLL("version.dll", use_last_error=True)
        ptr, u32, flag = C.c_void_p, C.c_uint32, C.c_int32
        signatures = {
            "OpenProcess": ([u32, flag, u32], ptr),
            "CloseHandle": ([ptr], flag),
            "WaitForSingleObject": ([ptr, u32], u32),
            "GetProcessTimes": ([ptr, *([C.POINTER(FileTime)] * 4)], flag),
            "QueryFullProcessImageNameW": ([ptr, u32, C.c_wchar_p, C.POINTER(u32)], flag),
            "K32EnumProcessModulesEx": ([ptr, C.POINTER(ptr), u32, C.POINTER(u32), u32], flag),
            "K32GetModuleFileNameExW": ([ptr, ptr, C.c_wchar_p, u32], u32),
            "CreateFileW": ([C.c_wchar_p, u32, u32, ptr, u32, u32, ptr], ptr),
            "GetFileInformationByHandle": ([ptr, C.POINTER(FileInfo)], flag),
            "ReadFile": ([ptr, ptr, u32, C.POINTER(u32), ptr], flag),
        }
        for name, (args, result) in signatures.items():
            function = getattr(self.kernel, name)
            function.argtypes, function.restype = args, result
        for name, args, result in (
            ("GetFileVersionInfoSizeW", [C.c_wchar_p, C.POINTER(u32)], u32),
            ("GetFileVersionInfoW", [C.c_wchar_p, u32, u32, ptr], flag),
            ("VerQueryValueW", [ptr, C.c_wchar_p, C.POINTER(ptr), C.POINTER(u32)], flag),
        ):
            function = getattr(self.version, name)
            function.argtypes, function.restype = args, result
        # Query information, read virtual memory for PSAPI, and observe exit.
        self.process = self.kernel.OpenProcess(0x400 | 0x10 | 0x100000, False, pid)
        if not self.process:
            self.check(False, "OpenProcess")

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.kernel.CloseHandle(self.process)

    def check(self, result, operation):
        _require(result, operation + " failed (winerror " + str(C.get_last_error()) + ")")
        _require(time.perf_counter() < self.deadline, "observation deadline reached")

    def process_identity(self):
        _require(self.kernel.WaitForSingleObject(self.process, 0) == 258,
                 "requested process is no longer live or exit could not be observed")
        created, exited, kernel, user = (FileTime() for _ in range(4))
        self.check(self.kernel.GetProcessTimes(self.process, C.byref(created), C.byref(exited),
                                              C.byref(kernel), C.byref(user)), "GetProcessTimes")
        path = C.create_unicode_buffer(32768)
        size = C.c_uint32(len(path))
        self.check(self.kernel.QueryFullProcessImageNameW(self.process, 0, path, C.byref(size)),
                   "QueryFullProcessImageNameW")
        _require(0 < size.value < len(path) - 1 and created.value() > 0,
                 "process identity is missing or truncated")
        return {"created_100ns": created.value(), "image_path": path.value}

    def module(self):
        modules = (C.c_void_p * MAX_MODULES)()
        needed = C.c_uint32()
        self.check(self.kernel.K32EnumProcessModulesEx(self.process, modules, C.sizeof(modules),
                                                      C.byref(needed), 3), "EnumProcessModulesEx")
        _require(0 < needed.value <= C.sizeof(modules)
                 and needed.value % C.sizeof(C.c_void_p) == 0, "module inventory exceeds bound or is invalid")
        matches = []
        for address in modules[:needed.value // C.sizeof(C.c_void_p)]:
            path = C.create_unicode_buffer(32768)
            count = self.kernel.K32GetModuleFileNameExW(self.process, address, path, len(path))
            self.check(count, "GetModuleFileNameExW")
            _require(count < len(path) - 1, "module path is truncated")
            if ntpath.basename(path.value).lower() == MODULE:
                matches.append({"path": path.value, "base_address": int(address)})
        _require(len(matches) == 1, "compiler module is not loaded" if not matches else "compiler module is ambiguous")
        return matches[0]

    def file_info(self, handle):
        info = FileInfo()
        self.check(self.kernel.GetFileInformationByHandle(handle, C.byref(info)), "GetFileInformationByHandle")
        return {"volume_serial": info.volume, "file_index": info.index_low | (info.index_high << 32),
                "bytes": info.size_low | (info.size_high << 32), "last_write_100ns": info.written.value()}

    def file_version(self, path):
        ignored = C.c_uint32()
        size = self.version.GetFileVersionInfoSizeW(path, C.byref(ignored))
        self.check(size, "GetFileVersionInfoSizeW")
        _require(size <= MAX_VERSION_BYTES, "version resource exceeds bound")
        data = C.create_string_buffer(size)
        self.check(self.version.GetFileVersionInfoW(path, 0, size, data), "GetFileVersionInfoW")
        pointer, length = C.c_void_p(), C.c_uint32()
        self.check(self.version.VerQueryValueW(data, "\\", C.byref(pointer), C.byref(length)), "VerQueryValueW")
        _require(pointer.value and length.value >= C.sizeof(VersionInfo), "fixed version record is missing")
        info = C.cast(pointer, C.POINTER(VersionInfo)).contents
        _require(info.signature == 0xFEEF04BD, "fixed version signature is invalid")
        return ".".join(str(part) for part in (info.file_ms >> 16, info.file_ms & 65535,
                                               info.file_ls >> 16, info.file_ls & 65535))

    def file_identity(self, path):
        # Deny concurrent write/delete while hashing and querying the same path.
        handle = self.kernel.CreateFileW(path, 0x80000000, 1, None, 3, 0x08000080, None)
        if not handle or handle == C.c_void_p(-1).value:
            self.check(False, "CreateFileW compiler module")
        try:
            before = self.file_info(handle)
            _require(0 < before["bytes"] <= MAX_FILE_BYTES, "compiler module file exceeds size bound")
            digest, total = hashlib.sha256(), 0
            buffer, count = C.create_string_buffer(65536), C.c_uint32()
            while total < before["bytes"]:
                wanted = min(len(buffer), before["bytes"] - total)
                self.check(self.kernel.ReadFile(handle, buffer, wanted, C.byref(count), None), "ReadFile")
                _require(0 < count.value <= wanted, "compiler module file was truncated")
                digest.update(buffer.raw[:count.value])
                total += count.value
            version = self.file_version(path)
            _require(self.file_info(handle) == before, "compiler module file changed during observation")
            return {"file_version": version, "sha256": digest.hexdigest(), "bytes": total,
                    "file_identity": before}
        finally:
            self.kernel.CloseHandle(handle)


def _observe(pid, seconds, reader_factory=WindowsReader):
    deadline = time.perf_counter() + seconds
    try:
        with reader_factory(pid, deadline) as reader:
            process = reader.process_identity()
            module = reader.module()
            identity = reader.file_identity(module["path"])
            _require(reader.module() == module, "loaded compiler module changed during observation")
            _require(reader.process_identity() == process, "requested process identity changed")
        _require(time.perf_counter() < deadline, "observation completed after its deadline")
        return {"schema": SCHEMA, "requested_pid": pid, "status": "observed",
                "process": process, "module": module | identity}
    except (Unavailable, OSError, ValueError, AttributeError) as error:
        return {"schema": SCHEMA, "requested_pid": pid, "status": "unavailable", "reason": str(error)[:2048]}


def _policy_limits():
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/ci"))
    import execution_policy as policy
    identity = policy.identity()
    values = identity["watchdogs"]
    return values["diagnostic_capture_seconds"], values["terminate_grace_seconds"], identity


def _decode_reply(data, pid):
    _require(len(data) <= MAX_REPLY_BYTES, "observer reply exceeds bound")
    def pairs(items):
        result = {}
        for key, value in items:
            _require(key not in result, "duplicate observer reply key")
            result[key] = value
        return result
    def constant(_):
        raise Unavailable("nonfinite observer reply")
    value = json.loads(data, object_pairs_hook=pairs, parse_constant=constant)
    _require(isinstance(value, dict) and value.get("schema") == SCHEMA
             and type(value.get("requested_pid")) is int and value["requested_pid"] == pid,
             "observer reply PID or schema mismatch")
    _require(value.get("status") in ("observed", "unavailable"), "unknown observer status")
    if value["status"] == "unavailable":
        _require(isinstance(value.get("reason"), str) and value["reason"], "missing unavailable reason")
        return value
    module, process = value.get("module"), value.get("process")
    _require(isinstance(module, dict) and isinstance(process, dict), "missing observed identity")
    path = module.get("path")
    _require(isinstance(path, str) and ntpath.isabs(path) and ntpath.basename(path).lower() == MODULE,
             "observed module path is invalid")
    _require(type(module.get("base_address")) is int and module["base_address"] > 0
             and type(module.get("bytes")) is int and 0 < module["bytes"] <= MAX_FILE_BYTES,
             "observed module size/base is invalid")
    _require(isinstance(module.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", module["sha256"]),
             "observed module digest is invalid")
    _require(isinstance(module.get("file_version"), str)
             and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+", module["file_version"]),
             "observed module version is invalid")
    _require(type(process.get("created_100ns")) is int and process["created_100ns"] > 0
             and isinstance(process.get("image_path"), str) and ntpath.isabs(process["image_path"]),
             "observed process identity is invalid")
    file_id = module.get("file_identity")
    _require(isinstance(file_id, dict) and file_id.get("bytes") == module["bytes"]
             and all(type(file_id.get(key)) is int and file_id[key] >= 0
                     for key in ("bytes", "volume_serial", "file_index", "last_write_100ns")),
             "observed file handle identity is invalid")
    return value


def _run_bounded(command, capture, grace, *, launch=subprocess.Popen):
    started = time.perf_counter()
    facts = {"helper_pid": None, "helper_returncode": None, "helper_joined": True,
             "helper_terminated": False, "helper_natural_completion": False}
    process, output = None, None
    try:
        environment = {name: value for name, value in os.environ.items()
                       if name.upper() in {"SYSTEMROOT", "WINDIR", "TEMP", "TMP"}}
        process = launch(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         env=environment, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        facts.update(helper_pid=process.pid, helper_joined=False)
        remaining = capture - (time.perf_counter() - started)
        if remaining <= 0:
            raise subprocess.TimeoutExpired(command, capture)
        candidate, _stderr = process.communicate(timeout=remaining)
        facts.update(helper_returncode=process.returncode, helper_joined=True,
                     helper_natural_completion=time.perf_counter() - started <= capture)
        _require(facts["helper_natural_completion"], "observer completed after capture deadline")
        _require(process.returncode == 0, "observer helper exited nonzero")
        _require(len(candidate) <= MAX_REPLY_BYTES, "observer reply exceeds bound")
        output = candidate
    except subprocess.TimeoutExpired:
        facts["reason"] = "observer capture deadline exceeded"
    except (OSError, Unavailable) as error:
        facts["reason"] = str(error)[:2048]
    finally:
        if process is not None and not facts["helper_joined"]:
            facts["helper_terminated"] = True
            try:
                process.kill()  # Only our returned process handle, never the engine PID.
                process.communicate(timeout=grace)
                facts.update(helper_returncode=process.returncode, helper_joined=True)
            except (OSError, subprocess.TimeoutExpired):
                facts["helper_joined"] = process.poll() is not None
                facts["helper_returncode"] = process.returncode
        facts["elapsed_seconds"] = time.perf_counter() - started
        if process is not None and facts["helper_joined"]:
            for stream in (process.stdout, process.stderr):
                if stream is not None:
                    stream.close()
    return output, facts


def observe_loaded_compiler(pid: int) -> dict:
    """One bounded observation; unavailable never invents a compiler identity."""
    base = {"schema": SCHEMA, "requested_pid": pid, "status": "unavailable", "scope": SCOPE,
            "observation_clock": "time.perf_counter", "capture_seconds": None,
            "cleanup_grace_seconds": None, "helper_pid": None, "helper_joined": True,
            "helper_terminated": False, "helper_natural_completion": False}
    if type(pid) is not int or not 0 < pid <= 0xFFFFFFFF:
        return base | {"reason": "invalid requested process ID"}
    if sys.platform != "win32":
        return base | {"reason": "Windows process module observation is unavailable on this platform"}
    facts = {}
    try:
        capture, grace, identity = _policy_limits()
        _require(all(type(n) in (int, float) and math.isfinite(n) and n > 0 for n in (capture, grace)),
                 "invalid shared observer watchdogs")
        base.update(capture_seconds=capture, cleanup_grace_seconds=grace, execution_policy=identity)
        command = [sys.executable, "-I", str(Path(__file__).resolve()),
                   "--observe-child", str(pid), "--seconds", str(capture)]
        data, facts = _run_bounded(command, capture, grace)
        if data is None:
            return base | facts
        return base | facts | _decode_reply(data, pid)
    except (Unavailable, OSError, ValueError, ImportError, KeyError) as error:
        return base | facts | {"status": "unavailable", "reason": str(error)[:2048]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--observe-child", type=int, required=True)
    parser.add_argument("--seconds", type=float, required=True)
    args = parser.parse_args()
    if not (0 < args.observe_child <= 0xFFFFFFFF and math.isfinite(args.seconds) and args.seconds > 0):
        parser.error("Invalid observer identity or watchdog")
    print(json.dumps(_observe(args.observe_child, args.seconds), sort_keys=True, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
