#!/usr/bin/env python3
"""Exercise the shipped Windows C++ authoring stack under its package environment.

This is a focused preflight for the full PUBPRES evaluator. It uses the same
dependency copier and environment builder as the evaluator, records GCC's
program-search answers, compiles and runs a small C++ program at each adverse
installation path, and runs the actual Materials Lab World comparison once at
the combined path used by the independent extraction workflow.
"""
from __future__ import annotations

import argparse
import base64
import ctypes
from ctypes import wintypes
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "tools/pubpres_mainline"), str(ROOT / "tools/ci"),
                str(ROOT / "tools"), str(ROOT / "tools/material_catalogue")]

import common
import ramcache_strata_lab_package as portable_stack
import lab

SCHEMA = "pubpres-portable-authoring-witness-v1"
EXPECTED_GCC_SHA256 = "eccc5963340f7b57805b3750efc182c25c6d4eddb828c8cee2b0f974a0d943ac"
PROCESS_NAMES = {"g++.exe", "gcc.exe", "cc1plus.exe", "collect2.exe", "ld.exe", "as.exe"}
RULE_PREFIX = "PUBPRES-Portable-Authoring-"


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def canonical(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def write_json(path: Path, value: object) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(canonical(value))
    os.replace(temporary, path)


def path_variants(parent: Path) -> list[tuple[str, Path]]:
    """Return fresh installation roots covering the registered Windows paths."""
    return [
        ("short_ascii", parent / "ppa"),
        ("spaces", parent / "Owner Folder With Spaces" / "CyberSand Workbench"),
        ("parentheses", parent / "Owner (PUBPRES)" / "CyberSand"),
        ("unicode", parent / "Ωwner" / "CyberSand"),
        ("nested", parent / "deep" / "nested" / "portable" / "Workbench"),
        ("combined_adverse", parent / "Owner (PUBPRES) Ω" / "nested" / "CyberSand Workbench"),
    ]


def describe_path(label: str, path: Path) -> dict:
    text = str(path)
    return {"label": label, "installation": text, "path_characters": len(text),
            "has_space": " " in text, "has_parentheses": "(" in text and ")" in text,
            "has_non_ascii": any(ord(character) > 127 for character in text),
            "depth": len(path.parts), "ascii_only": text.isascii()}


def _hardlink_tree(source: Path, destination: Path) -> None:
    """Clone an already admitted package's bytes without another large copy."""
    need(source.is_dir() and not source.is_symlink(), "Hardlink source is not a real directory")
    need(not destination.exists(), "Refuse to overwrite a toolchain test installation")
    destination.mkdir(parents=True)
    for directory, children, files in os.walk(source, followlinks=False):
        here = Path(directory)
        relative = here.relative_to(source)
        target_directory = destination / relative
        for name in children:
            origin = here / name
            need(not origin.is_symlink(), "Portable dependency contains a symlink: " + str(origin))
            (target_directory / name).mkdir(exist_ok=True)
        for name in files:
            origin = here / name
            target = target_directory / name
            need(not origin.is_symlink(), "Portable dependency contains a symlink: " + str(origin))
            os.link(origin, target)


def _under(path: Path, root: Path) -> bool:
    try:
        path.resolve(strict=True).relative_to(root.resolve(strict=True))
        return True
    except (OSError, ValueError):
        return False


def resolve_reported_program(reported: str, compiler_root: Path, search_path: str) -> Path | None:
    """Resolve GCC's readback without accepting an external PATH fallback."""
    value = reported.strip().strip('"')
    if not value:
        return None
    candidate = Path(value)
    if candidate.is_absolute():
        return candidate.resolve() if candidate.is_file() else None
    if "/" in value or "\\" in value:
        for base in (compiler_root, Path.cwd()):
            path = (base / candidate).resolve()
            if path.is_file():
                return path
        return None
    selected = shutil.which(value, path=search_path)
    return Path(selected).resolve() if selected else None


class ProcessPathObserver:
    """Capture process identities and retain only creation-time descendants of test roots."""
    TH32CS_SNAPPROCESS = 0x00000002
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

    class Entry(ctypes.Structure):
        _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                    ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
                    ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                    ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG),
                    ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * 260)]

    def __init__(self, interval_seconds: float = 0.002, extra_names: set[str] | None = None):
        need(os.name == "nt", "Actual process-path sampling requires Windows")
        self.interval_seconds = interval_seconds
        self.names = {name.casefold() for name in PROCESS_NAMES | (extra_names or set())}
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._sample, name="pubpres-process-path-observer", daemon=True)
        self._records: dict[tuple[int, int], dict] = {}
        self._roots: dict[tuple[int, int], dict] = {}
        self._handles: dict[tuple[int, int], object] = {}
        self._lock = threading.Lock()
        self._errors: list[str] = []
        self._kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        self._snapshot = self._kernel.CreateToolhelp32Snapshot
        self._snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
        self._snapshot.restype = wintypes.HANDLE
        self._first = self._kernel.Process32FirstW
        self._first.argtypes = [wintypes.HANDLE, ctypes.POINTER(self.Entry)]
        self._first.restype = wintypes.BOOL
        self._next = self._kernel.Process32NextW
        self._next.argtypes = [wintypes.HANDLE, ctypes.POINTER(self.Entry)]
        self._next.restype = wintypes.BOOL
        self._open = self._kernel.OpenProcess
        self._open.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        self._open.restype = wintypes.HANDLE
        self._image = self._kernel.QueryFullProcessImageNameW
        self._image.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
                                ctypes.POINTER(wintypes.DWORD)]
        self._image.restype = wintypes.BOOL
        self._times = self._kernel.GetProcessTimes
        self._times.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.FILETIME),
                                ctypes.POINTER(wintypes.FILETIME), ctypes.POINTER(wintypes.FILETIME),
                                ctypes.POINTER(wintypes.FILETIME)]
        self._times.restype = wintypes.BOOL
        self._close = self._kernel.CloseHandle
        self._close.argtypes = [wintypes.HANDLE]
        self._close.restype = wintypes.BOOL

    def start(self) -> None:
        self._thread.start()

    def stop(self) -> dict:
        self._stop.set()
        self._thread.join(timeout=3)
        need(not self._thread.is_alive(), "Process-path observer did not stop")
        with self._lock:
            roots = {key: dict(row) for key, row in self._roots.items()}
            observations = {key: dict(row) for key, row in self._records.items()}
            handles = dict(self._handles)
        for key, handle in handles.items():
            creation, exit_time = wintypes.FILETIME(), wintypes.FILETIME()
            kernel_time, user_time = wintypes.FILETIME(), wintypes.FILETIME()
            try:
                if not self._times(handle, ctypes.byref(creation), ctypes.byref(exit_time),
                                   ctypes.byref(kernel_time), ctypes.byref(user_time)):
                    raise ctypes.WinError(ctypes.get_last_error())
                ended = (int(exit_time.dwHighDateTime) << 32) | int(exit_time.dwLowDateTime)
                row = roots.get(key, observations.get(key))
                if row is not None:
                    row["exit_filetime_100ns"] = ended or None
            except BaseException as error:
                if len(self._errors) < 20:
                    self._errors.append("process exit identity: " + type(error).__name__ + ": " + str(error))
            finally:
                self._close(handle)
        roots_list, observations_list = list(roots.values()), list(observations.values())
        correlated = self._correlated(roots_list, observations_list)
        correlated_keys = {(entry["pid"], entry["creation_filetime_100ns"]) for entry in correlated}
        return {"poll_interval_ms": self.interval_seconds * 1000,
                "roots": sorted(roots_list, key=lambda row: (row["creation_filetime_100ns"], row["pid"])),
                "observations": sorted(correlated, key=lambda row: (row["creation_filetime_100ns"], row["pid"])),
                "uncorrelated_observation_count": sum(1 for row in observations_list
                    if (row["pid"], row["creation_filetime_100ns"]) not in correlated_keys),
                "observer_errors": self._errors}

    @staticmethod
    def _correlated(roots: list[dict], observations: list[dict]) -> list[dict]:
        """Join only observed descendants whose live interval covers each child start."""
        rows = {(row["pid"], row["creation_filetime_100ns"]): row for row in observations}
        for row in roots:
            key = (row["pid"], row["creation_filetime_100ns"])
            rows[key] = {**rows.get(key, {}), **row}
        by_pid: dict[int, list[tuple[int, int]]] = {}
        for key in rows:
            by_pid.setdefault(key[0], []).append(key)
        for keys in by_pid.values():
            keys.sort(key=lambda key: key[1])
        correlated = {(row["pid"], row["creation_filetime_100ns"]) for row in roots}
        pending = set(rows) - correlated
        changed = True
        while changed:
            changed = False
            for key in tuple(pending):
                row = rows[key]
                parents = [candidate for candidate in by_pid.get(row["parent_pid"], [])
                           if candidate[1] < row["creation_filetime_100ns"]
                           and rows[candidate].get("exit_filetime_100ns") is not None
                           and row["creation_filetime_100ns"] < rows[candidate]["exit_filetime_100ns"]]
                if parents and parents[-1] in correlated:
                    pending.remove(key)
                    correlated.add(key)
                    changed = True
        return [rows[key] for key in correlated if key in rows]

    def _identity(self, handle, pid: int, parent_pid: int) -> dict:
        buffer = ctypes.create_unicode_buffer(32768)
        size = wintypes.DWORD(len(buffer))
        if not self._image(handle, 0, buffer, ctypes.byref(size)):
            raise ctypes.WinError(ctypes.get_last_error())
        creation = wintypes.FILETIME()
        exit_time, kernel_time, user_time = wintypes.FILETIME(), wintypes.FILETIME(), wintypes.FILETIME()
        if not self._times(handle, ctypes.byref(creation), ctypes.byref(exit_time),
                           ctypes.byref(kernel_time), ctypes.byref(user_time)):
            raise ctypes.WinError(ctypes.get_last_error())
        started = (int(creation.dwHighDateTime) << 32) | int(creation.dwLowDateTime)
        ended = (int(exit_time.dwHighDateTime) << 32) | int(exit_time.dwLowDateTime)
        return {"pid": pid, "parent_pid": parent_pid, "creation_filetime_100ns": started,
                "exit_filetime_100ns": ended or None, "image_path": str(Path(buffer.value))}

    def register_root(self, process) -> None:
        """Record the actual image and start time while a lab._run child is suspended."""
        try:
            handle = self._open(self.PROCESS_QUERY_LIMITED_INFORMATION, False, int(process.pid))
            if not handle:
                raise ctypes.WinError(ctypes.get_last_error())
            row = self._identity(handle, int(process.pid), os.getpid())
            row.update(root=True, first_seen_utc=datetime.now(timezone.utc).isoformat(), samples=0)
            with self._lock:
                key = (row["pid"], row["creation_filetime_100ns"])
                self._roots[key] = row
                if key in self._handles:
                    self._close(handle)
                else:
                    self._handles[key] = handle
        except BaseException as error:
            if "handle" in locals() and handle:
                self._close(handle)
            with self._lock:
                if len(self._errors) < 20:
                    self._errors.append("root identity: " + type(error).__name__ + ": " + str(error))

    def _sample(self) -> None:
        while not self._stop.is_set():
            try:
                handle = self._snapshot(self.TH32CS_SNAPPROCESS, 0)
                if handle == wintypes.HANDLE(-1).value:
                    raise ctypes.WinError(ctypes.get_last_error())
                try:
                    entry = self.Entry()
                    entry.dwSize = ctypes.sizeof(self.Entry)
                    ok = self._first(handle, ctypes.byref(entry))
                    while ok:
                        if entry.szExeFile.casefold() in self.names:
                            process = self._open(self.PROCESS_QUERY_LIMITED_INFORMATION, False,
                                                 entry.th32ProcessID)
                            if process:
                                keep = False
                                try:
                                    row = self._identity(process, int(entry.th32ProcessID),
                                                         int(entry.th32ParentProcessID))
                                    key = (row["pid"], row["creation_filetime_100ns"])
                                    stamp = datetime.now(timezone.utc).isoformat()
                                    with self._lock:
                                        self._records.setdefault(key, {**row, "first_seen_utc": stamp,
                                            "last_seen_utc": stamp, "samples": 0})
                                        self._records[key]["last_seen_utc"] = stamp
                                        self._records[key]["samples"] += 1
                                        if key not in self._handles:
                                            self._handles[key] = process
                                            keep = True
                                finally:
                                    if not keep:
                                        self._close(process)
                        ok = self._next(handle, ctypes.byref(entry))
                finally:
                    self._close(handle)
            except BaseException as error:  # keep diagnostic failures in the receipt
                if len(self._errors) < 20:
                    self._errors.append(type(error).__name__ + ": " + str(error))
            self._stop.wait(self.interval_seconds)


@contextmanager
def capture_popen_roots(observer: ProcessPathObserver):
    """Capture suspended roots created by lab._run before they can execute."""
    original = subprocess.Popen

    def observed_popen(*args, **kwargs):
        process = original(*args, **kwargs)
        creationflags = kwargs.get("creationflags", 0)
        if creationflags & getattr(lab.process_owner, "CREATE_SUSPENDED", 0):
            observer.register_root(process)
        return process

    subprocess.Popen = observed_popen
    try:
        yield
    finally:
        subprocess.Popen = original


class OfflineEgressRules:
    """Temporarily block network egress from staged authoring executables."""
    def __init__(self, identifier: str):
        self.identifier = identifier
        self.names: list[str] = []
        self.executables: list[str] = []
        self.next_index = 0

    def block(self, executables: list[Path]) -> None:
        for executable in sorted({path.resolve() for path in executables if path.is_file()}):
            name = RULE_PREFIX + self.identifier + "-" + str(self.next_index)
            self.next_index += 1
            _powershell_block(name, executable)
            self.names.append(name)
            self.executables.append(str(executable))

    def block_one(self, executable: Path) -> None:
        self.block([executable])

    def adopt_child_rules(self, rows: list[dict]) -> None:
        for row in rows:
            name, executable = row.get("name"), row.get("executable")
            need(type(name) is str and name.startswith(RULE_PREFIX + self.identifier + "-world-")
                 and type(executable) is str and Path(executable).is_absolute(),
                 "Generated executable firewall receipt has an invalid identity")
            if name not in self.names:
                self.names.append(name)
                self.executables.append(executable)

    def preflight(self) -> dict:
        script = ("$ErrorActionPreference = 'Stop'; $service = Get-Service -Name MpsSvc -ErrorAction Stop; "
                  "$profiles = @(Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name, "
                  "@{Name='Enabled';Expression={$_.Enabled.ToString() -eq 'True'}}, "
                  "@{Name='EnabledRaw';Expression={$_.Enabled.ToString()}}); "
                  "$receipt = [ordered]@{ service = $service.Status.ToString(); profiles = $profiles }; "
                  "$receipt | ConvertTo-Json -Compress -Depth 4")
        encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
        result = subprocess.run([str(powershell_executable()), "-NoProfile", "-NonInteractive",
                                 "-ExecutionPolicy", "Bypass", "-EncodedCommand", encoded],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30,
                                check=False, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), shell=False)
        if result.returncode:
            raise RuntimeError("Windows Firewall service/profile preflight failed: " +
                               (result.stderr or result.stdout).decode("utf-8", errors="replace")[-4000:])
        receipt = json.loads(result.stdout.decode("utf-8", errors="strict"))
        profiles = receipt.get("profiles", [])
        observed = {row.get("Name"): row.get("Enabled") for row in profiles if type(row) is dict}
        required = {"Domain", "Private", "Public"}
        passed = (receipt.get("service") == "Running" and required <= set(observed)
                  and all(observed[name] is True for name in required))
        return {"status": "passed" if passed else "failed", **receipt,
                "required_profiles": sorted(required), "all_profiles_enabled": passed}

    def remove(self) -> dict:
        prefix = RULE_PREFIX + self.identifier + "-"
        payload = base64.b64encode(json.dumps(prefix).encode("utf-8")).decode("ascii")
        script = ("$ErrorActionPreference = 'Stop'; $prefix = [System.Text.Encoding]::UTF8.GetString("
                  "[Convert]::FromBase64String('" + payload + "')); "
                  "$rules = @(Get-NetFirewallRule -Name ($prefix + '*') -ErrorAction SilentlyContinue); "
                  "$removed = @($rules | ForEach-Object { $_.Name }); "
                  "if ($rules.Count) { $rules | Remove-NetFirewallRule -ErrorAction Stop }; "
                  "$remaining = @(Get-NetFirewallRule -Name ($prefix + '*') -ErrorAction SilentlyContinue); "
                  "if ($remaining.Count) { throw 'Witness firewall rules remained after cleanup' }; "
                  "$removed | ConvertTo-Json -Compress")
        encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
        command = [str(powershell_executable()), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                   "-EncodedCommand", encoded]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30,
                                check=False, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), shell=False)
        if result.returncode:
            raise RuntimeError("PowerShell firewall cleanup failed: " +
                               (result.stderr or result.stdout).decode("utf-8", errors="replace")[-4000:])
        raw_removed = result.stdout.decode("utf-8", errors="replace").strip()
        if raw_removed:
            decoded = json.loads(raw_removed)
            removed = decoded if type(decoded) is list else [decoded]
        else:
            removed = []
        self.names.clear()
        self.executables.clear()
        return {"status": "passed", "rules_removed": removed}


def powershell_executable() -> Path:
    system_root = Path(os.environ.get("SystemRoot", r"C:\Windows"))
    selected = system_root / "System32/WindowsPowerShell/v1.0/powershell.exe"
    need(selected.is_file(), "Windows PowerShell is missing from the Windows system directory")
    return selected


def _powershell_block(name: str, executable: Path) -> None:
    # This helper is used instead of shell interpolation for adversarial paths.
    payload = base64.b64encode(json.dumps([name, str(executable)]).encode("utf-8")).decode("ascii")
    script = ("$ErrorActionPreference = 'Stop'; $row = [System.Text.Encoding]::UTF8.GetString("
              "[Convert]::FromBase64String('" + payload + "')) | ConvertFrom-Json; "
              "$rule = New-NetFirewallRule -Name $row[0] -DisplayName $row[0] -Program $row[1] "
              "-Direction Outbound -Action Block -Profile Any -Enabled True -ErrorAction Stop; "
              "$readback = Get-NetFirewallRule -Name $row[0] -ErrorAction Stop; "
              "$application = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $readback -ErrorAction Stop; "
              "if ($readback.Enabled -ne 'True' -or $readback.Direction -ne 'Outbound' -or $readback.Action -ne 'Block' "
              "-or [System.IO.Path]::GetFullPath($application.Program) -ine [System.IO.Path]::GetFullPath($row[1])) "
              "{ throw ('Firewall rule readback differs: ' + $row[0]) }")
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    command = [str(powershell_executable()), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
               "-EncodedCommand", encoded]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30,
                            check=False, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), shell=False)
    if result.returncode:
        raise RuntimeError("PowerShell firewall rule failed for " + str(executable) + ": " +
                           (result.stderr or result.stdout).decode("utf-8", errors="replace")[-4000:])


def _compiler_executables(dependencies: Path) -> list[Path]:
    selected = [dependencies / "python/python.exe", dependencies / "git/cmd/git.exe"]
    selected.extend((dependencies / "git").rglob("git.exe"))
    compiler = dependencies / "cxx"
    for path in compiler.rglob("*.exe"):
        if path.name.casefold() in PROCESS_NAMES:
            selected.append(path)
    return [path for path in selected if path.is_file()]


def _environment(package: Path) -> dict[str, str]:
    env = portable_stack.dependency_environment(package)
    # Preserve Windows TEMP/TMP exactly as the extracted evaluator inherits it.
    (package / "authoring-temp").mkdir(parents=True)
    # Prevent package/network helpers from consulting a proxy. The optional
    # per-process Windows Firewall rules below provide the actual egress block.
    for key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        env.pop(key, None)
    return env


def _environment_scope(env: dict[str, str]):
    class Scope:
        def __enter__(self):
            self.original = dict(os.environ)
            os.environ.clear()
            os.environ.update(env)
            tempfile.tempdir = None
            return self

        def __exit__(self, exc_type, exc, tb):
            os.environ.clear()
            os.environ.update(self.original)
            tempfile.tempdir = None
    return Scope()


def _tool_identity(package: Path, env: dict[str, str]) -> dict:
    dependencies = package / "dependencies"
    compiler_root = dependencies / "cxx"
    compiler = compiler_root / "bin/g++.exe"
    selected = shutil.which("g++", path=env["PATH"])
    need(selected is not None and Path(selected).resolve() == compiler.resolve(),
         "The production environment does not resolve its bundled g++.exe")
    result = {}
    queries = {"version": ["--version"], "target": ["-dumpmachine"],
               "full_version": ["-dumpfullversion"], "search_dirs": ["-print-search-dirs"]}
    query_receipts = {}
    for name, args in queries.items():
        run = lab._run([str(compiler), *args], package, 30)
        result[name] = (run.stdout + run.stderr).strip()
        query_receipts[name] = {"argv": [str(compiler), *args], "exit_code": run.returncode,
                                "stdout": run.stdout.strip(), "stderr": run.stderr.strip()}
    result["compiler_query_receipts"] = query_receipts
    result["inherited_search_environment"] = {
        key: env.get(key, "") for key in (
            "COMPILER_PATH", "GCC_EXEC_PREFIX", "LIBRARY_PATH", "GCC_SPECS",
            "CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH")}
    for role in ("ld", "ld.exe", "as", "as.exe", "collect2", "collect2.exe"):
        run = lab._run([str(compiler), "-print-prog-name=" + role], package, 30)
        reported = run.stdout.strip()
        resolved = resolve_reported_program(reported, compiler_root, env["PATH"])
        in_bundle = resolved is not None and _under(resolved, compiler_root)
        result[role] = {"reported_by_compiler": reported,
                        "exit_code": run.returncode, "stderr": run.stderr.strip(),
                        "resolved_path": str(resolved) if resolved else None,
                        "relative_to_bundle": resolved.relative_to(compiler_root.resolve()).as_posix() if in_bundle else None,
                        "sha256": sha(resolved) if in_bundle else None,
                        "bytes": resolved.stat().st_size if in_bundle else None,
                        "in_bundled_compiler": in_bundle,
                        "resolved_inside_bundle": in_bundle}
    for role in ("cc1plus", "cc1plus.exe"):
        run = lab._run([str(compiler), "-print-prog-name=" + role], package, 30)
        reported = run.stdout.strip()
        resolved = resolve_reported_program(reported, compiler_root, env["PATH"])
        in_bundle = resolved is not None and _under(resolved, compiler_root)
        result[role] = {"reported_by_compiler": reported,
                        "exit_code": run.returncode, "stderr": run.stderr.strip(),
                        "resolved_path": str(resolved) if resolved else None,
                        "relative_to_bundle": resolved.relative_to(compiler_root.resolve()).as_posix() if in_bundle else None,
                        "sha256": sha(resolved) if in_bundle else None,
                        "in_bundled_compiler": in_bundle,
                        "resolved_inside_bundle": in_bundle}
    where = {}
    where_exe = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/where.exe"
    for role in ("ld", "ld.exe", "as", "as.exe", "collect2", "collect2.exe"):
        found = lab._run([str(where_exe), role], package, 20, check=False)
        where[role] = {"exit_code": found.returncode,
                       "paths": [line.strip() for line in found.stdout.splitlines() if line.strip()],
                       "stderr": found.stderr.strip()}
    result["where_path_readback"] = where
    result["all_programs_inside_bundle"] = all(result[role]["resolved_inside_bundle"]
        for role in ("ld", "ld.exe", "as", "as.exe", "collect2", "collect2.exe",
                     "cc1plus", "cc1plus.exe"))
    return result


def _mini_link_test(package: Path, env: dict[str, str], firewall: OfflineEgressRules | None) -> dict:
    compiler = package / "dependencies/cxx/bin/g++.exe"
    # Installation roots vary one property at a time. Putting Unicode into
    # every probe's own directory would invalidate the ASCII control.
    directory = package / "authoring-temp" / "minimal-cpp"
    directory.mkdir()
    source = directory / "portable-material.cpp"
    executable = directory / "portable-material.exe"
    source.write_text('#include <iostream>\nint main(){ std::cout << "offline-material-ok\\n"; return 0; }\n', encoding="utf-8")
    observer = ProcessPathObserver()
    observer.start()
    started = datetime.now(timezone.utc).isoformat()
    compile_result = None
    execution = None
    compile_error = None
    execution_error = None
    try:
        try:
            with capture_popen_roots(observer):
                compile_result = lab._run([str(compiler), "-std=c++20", "-O2", "-Wall", "-Wextra", "-Werror",
                                           str(source), "-o", str(executable)], directory, 120)
            need(executable.is_file(), "The production compiler returned success without a linked executable")
        except BaseException as error:
            compile_error = type(error).__name__ + ": " + str(error)
        if compile_error is None:
            try:
                if firewall is not None:
                    firewall.block_one(executable)
                with capture_popen_roots(observer):
                    execution = lab._run([str(executable)], directory, 30)
            except BaseException as error:
                execution_error = type(error).__name__ + ": " + str(error)
    finally:
        observed = observer.stop()
    paths: dict[str, list[str]] = {}
    for row in observed["observations"]:
        paths.setdefault(Path(row["image_path"]).name.casefold(), []).append(row["image_path"])
    needed = {"g++.exe", "cc1plus.exe", "collect2.exe", "ld.exe", "as.exe"}
    all_seen = needed <= set(paths)
    expected_compiler = (package / "dependencies/cxx/bin/g++.exe").resolve()
    root_compilers = [row for row in observed["roots"]
                      if Path(row["image_path"]).name.casefold() == "g++.exe"]
    compiler_root_observed = any(Path(row["image_path"]).resolve() == expected_compiler
                                 for row in root_compilers)
    observed_inside = all(all(_under(Path(path), package / "dependencies/cxx") for path in paths.get(name, []))
                          for name in needed if name in paths)
    execution_ok = execution is not None and execution.returncode == 0 and execution.stdout.strip() == "offline-material-ok"
    status = "passed" if (compile_error is None and execution_ok and all_seen and observed_inside
                           and compiler_root_observed and not observed["observer_errors"]) else "failed"
    return {"status": status, "started_utc": started,
            "compiler_argv": [str(compiler), "-std=c++20", "-O2", "-Wall", "-Wextra", "-Werror",
                              str(source), "-o", str(executable)],
            "source_sha256": sha(source),
            "executable_sha256": sha(executable) if executable.is_file() else None,
            "compiler_exit": compile_result.returncode if compile_result else None,
            "compiler_error": compile_error,
            "execution_exit": execution.returncode if execution else None,
            "execution_error": execution_error,
            "execution_stdout": execution.stdout.strip() if execution else "",
            "execution_stderr": execution.stderr.strip() if execution else "",
            "required_actual_processes_observed": sorted(name for name in needed if name in paths),
            "required_actual_processes_missing": sorted(needed - set(paths)),
            "compiler_root_observed": compiler_root_observed,
            "actual_process_paths_inside_bundle": observed_inside,
            "observed_roots": observed["roots"],
            "observed_process_paths": observed["observations"],
            "uncorrelated_observation_count": observed["uncorrelated_observation_count"],
            "observer_errors": observed["observer_errors"],
            "network_egress_blocked_for_linked_executable": firewall is not None}


def _actual_lab_world(package: Path, env: dict[str, str], firewall: OfflineEgressRules | None) -> dict:
    need(firewall is not None, "Actual Materials Lab world witness requires verified offline egress blocks")
    python = package / "dependencies/python/python.exe"
    lab_cli = package / "source/tools/material_catalogue/lab.py"
    witness_cli = package / "source/tools/pubpres_mainline/portable_lab_witness.py"
    scratch = package / "authoring-temp"
    firewall_registry = scratch / "world-firewall-rules.json"
    need(not firewall_registry.exists(), "Refuse to overwrite the generated-probe firewall registry")
    write_json(firewall_registry, [])
    scenario = {"first": 2, "second": 3, "seed": 17, "ticks": 120, "workers": 1}
    observer = ProcessPathObserver(extra_names={"python.exe"})

    def invoke(name: str, request: dict, *, firewall_guard: bool = False) -> tuple[dict, dict]:
        request_path, response_path = scratch / (name + "-request.json"), scratch / (name + "-response.json")
        for path in (request_path, response_path):
            need(not path.exists(), "Refuse to overwrite a Materials Lab protocol file")
        write_json(request_path, request)
        if firewall_guard:
            command = [str(python), "-B", str(witness_cli), "--request", str(request_path),
                       "--response", str(response_path), "--firewall-registry", str(firewall_registry),
                       "--run-id", firewall.identifier]
            with capture_popen_roots(observer):
                completed = lab._run(command, package / "source", 420, check=False)
        else:
            command = [str(python), "-B", str(lab_cli), "--request", str(request_path),
                       "--response", str(response_path)]
            completed = lab._run(command, package / "source", 60, check=False)
        response = json.loads(response_path.read_bytes()) if response_path.is_file() else None
        return {"argv": command, "working_directory": str((package / "source").resolve()),
                "timeout_seconds": 420 if firewall_guard else 60,
                "exit_code": completed.returncode, "stdout": completed.stdout.strip(),
                "stderr": completed.stderr.strip()}, response

    create_process, created = invoke("create", {"op": "create", "template_id": 2})
    need(create_process["exit_code"] == 0 and type(created) is dict and created.get("ok") is True
         and type(created.get("candidate")) is dict,
         "Packaged Materials Lab could not create the registered Sand template")
    candidate = created["candidate"]
    original_density = candidate["descriptor"]["density"]
    candidate["descriptor"]["density"] = original_density + 1
    candidate["descriptor"]["rgba"] = [29, 97, 181, 255]
    request = {"op": "compile_world_test", "candidate": candidate, "scenario": scenario}
    observer.start()
    started = datetime.now(timezone.utc).isoformat()
    world_rules = []
    try:
        compile_process, result = invoke("world", request, firewall_guard=True)
    finally:
        observed = observer.stop()
        if firewall is not None:
            world_rules = json.loads(firewall_registry.read_bytes())
            firewall.adopt_child_rules(world_rules)
    paths: dict[str, list[str]] = {}
    for row in observed["observations"]:
        paths.setdefault(Path(row["image_path"]).name.casefold(), []).append(row["image_path"])
    compiler_root = package / "dependencies/cxx"
    required = {"python.exe", "g++.exe", "cc1plus.exe", "collect2.exe", "ld.exe", "as.exe"}
    missing = sorted(required - set(paths))
    expected_python = python.resolve()
    python_roots = [row for row in observed["roots"]
                    if Path(row["image_path"]).name.casefold() == "python.exe"]
    packaged_python_root = any(Path(row["image_path"]).resolve() == expected_python
                               for row in python_roots)
    packaged_python_firewall_blocked = firewall is not None and str(expected_python) in firewall.executables
    compiler_paths_inside = all(
        _under(Path(path), compiler_root)
        for name in ("g++.exe", "cc1plus.exe", "collect2.exe", "ld.exe", "as.exe")
        for path in paths.get(name, []))
    packaged_python_observed = any(_under(Path(path), package / "dependencies/python")
                                   for path in paths.get("python.exe", []))
    error_text = ""
    receipt = result.get("receipt", {}) if type(result) is dict else {}
    if type(receipt) is not dict:
        receipt = {}
    errors = result.get("errors", []) if type(result) is dict else []
    if errors:
        error_text = "\n".join(str(row) for row in errors)
    compiler_argv = {role: receipt.get(role, {}).get("argv", []) for role in ("reference_build", "candidate_build")}
    exact_compiler_argv = all(argv and Path(argv[0]).resolve() == (package / "dependencies/cxx/bin/g++.exe").resolve()
                              for argv in compiler_argv.values()) if receipt else False
    expected_probe_hashes = {role: receipt.get(role + "_build", {}).get("native_executable_sha256")
                             for role in ("reference", "candidate")}
    rules_by_role = {row.get("role"): row for row in world_rules if type(row) is dict}
    temp_root = Path(env.get("TEMP") or env.get("TMP") or tempfile.gettempdir()).resolve()
    generated_probes_blocked = (
        set(rules_by_role) == {"reference", "candidate"} and len(world_rules) == 2
        and all(type(expected_probe_hashes[role]) is str and len(expected_probe_hashes[role]) == 64
                and rules_by_role[role].get("sha256") == expected_probe_hashes[role]
                and rules_by_role[role].get("bytes", 0) > 0
                and Path(rules_by_role[role].get("executable", "")).name.casefold() == "lab-world-probe.exe"
                and Path(rules_by_role[role].get("executable", "")).is_absolute()
                and Path(rules_by_role[role]["executable"]).resolve(strict=False).is_relative_to(temp_root)
                for role in ("reference", "candidate")))
    passed = (compile_process["exit_code"] == 0 and type(result) is dict and result.get("ok") is True
              and result.get("state") == "compiled_tested" and receipt.get("runtime_active") is False
              and receipt.get("checks", {}).get("candidate_qualification") is True
              and exact_compiler_argv and not missing and compiler_paths_inside and packaged_python_observed
              and packaged_python_root
              and packaged_python_firewall_blocked
              and generated_probes_blocked
              and not observed["observer_errors"])
    return {"status": "passed" if passed else "failed",
            "state": result.get("state") if type(result) is dict else None,
            "started_utc": started,
            "operation": "packaged Python -> staged portable_lab_witness.py -> unchanged lab.main -> lab.request(compile_world_test)",
            "request_sha256": sha(scratch / "world-request.json"),
            "create_process": create_process, "create_result_sha256": sha(scratch / "create-response.json"),
            "world_process": compile_process, "world_response": result,
            "error": error_text, "candidate_template": 2, "candidate_target": candidate["target_id"],
            "density_before": original_density, "density_after": candidate["descriptor"]["density"],
            "scenario": scenario, "comparison": receipt.get("comparison"),
            "candidate_runtime_active": receipt.get("runtime_active"),
            "candidate_native_checks": receipt.get("candidate", {}).get("checks"),
            "compiler_argv": compiler_argv, "compiler_version": receipt.get("compiler_version"),
            "generated_catalogue_sha256": receipt.get("compiled_catalogue_sha256"),
            "source_identity": receipt.get("source_identity"),
            "required_actual_processes_observed": sorted(required - set(missing)),
            "required_actual_processes_missing": missing,
            "actual_compiler_process_paths_inside_bundle": compiler_paths_inside,
            "packaged_python_root_observed": packaged_python_root,
            "packaged_python_observed": packaged_python_observed,
            "packaged_python_egress_rule_registered": packaged_python_firewall_blocked,
            "generated_world_probes_blocked": generated_probes_blocked,
            "observed_roots": observed["roots"],
            "observed_process_paths": observed["observations"],
            "uncorrelated_observation_count": observed["uncorrelated_observation_count"],
            "observer_errors": observed["observer_errors"],
            "network_egress_blocked_for_packaged_python_and_generated_world_probes": generated_probes_blocked,
            "generated_world_probe_firewall_rules": world_rules}


def run(args) -> dict:
    need(os.name == "nt", "Portable authoring witness requires the actual Windows runner")
    need(args.block_network, "Portable authoring witness requires --block-network")
    source = common.source_identity(ROOT)
    parent = args.parent.resolve()
    run_suffix = "".join(character for character in args.run_id if character.isalnum())[-8:]
    root = parent / ("p" + source["source_commit"][:6] + run_suffix)
    need(not root.exists(), "Witness run root already exists; choose a unique run id")
    output = args.output.resolve()
    need(not output.exists(), "Witness output already exists; choose a fresh directory")
    output.mkdir(parents=True)
    root.mkdir(parents=True)
    variants = path_variants(root)
    for _, install in variants:
        need(not install.exists(), "Installation path already exists; refusing to overwrite: " + str(install))
    observed_gcc_sha = portable_stack.sha(args.compiler_root / "bin/g++.exe")
    report = {"schema": SCHEMA, "status": "running", "source": source,
              "platform": {"system": sys.platform, "python": sys.version,
                           "os_version": __import__("platform").platform()},
              "compiler_source_root": str(args.compiler_root.resolve()),
              "toolchain_source_digest": observed_gcc_sha,
              "expected_original_gcc_sha256": EXPECTED_GCC_SHA256,
              "original_gcc_identity_match": observed_gcc_sha == EXPECTED_GCC_SHA256,
            "path_variants": [], "actual_materials_lab": None,
            "production_temp_environment": {key: os.environ.get(key, "") for key in ("TEMP", "TMP", "SystemRoot")},
              "offline_network_policy": "verified per-executable outbound Windows Firewall blocks for the packaged authoring tools and generated World probe executables",
              "timeouts_seconds": {"tool_queries": 30, "minimal_compile": 120,
                                    "minimal_execution": 30, "lab_world": 420}}
    write_json(output / "portable-authoring-witness.json", report)
    firewall = OfflineEgressRules(args.run_id) if args.block_network else None
    try:
        if observed_gcc_sha != EXPECTED_GCC_SHA256:
            report["status"] = "failed"
            report["toolchain_drift"] = {"status": "refused before reproduction",
                                           "expected_sha256": EXPECTED_GCC_SHA256,
                                           "observed_sha256": observed_gcc_sha}
            write_json(output / "portable-authoring-witness.json", report)
            raise RuntimeError("Refuse to attribute a reproduction to changed GCC; original compiler hash differs")
        try:
            report["firewall_preflight"] = firewall.preflight()
            if report["firewall_preflight"].get("status") != "passed":
                raise RuntimeError("Windows Firewall service is stopped or one or more profiles are disabled")
        except BaseException as error:
            report["status"] = "failed"
            report["firewall_preflight"] = report.get("firewall_preflight", {
                "status": "failed", "error": type(error).__name__ + ": " + str(error)})
            write_json(output / "portable-authoring-witness.json", report)
            raise
        write_json(output / "portable-authoring-witness.json", report)
        for index, (label, install) in enumerate(variants):
            environment_record = None
            try:
                (install / "dependencies").parent.mkdir(parents=True, exist_ok=True)
                if index == 0:
                    receipt = portable_stack.stage_dependencies(install / "dependencies",
                        python_root=args.python_root, git_root=args.git_root,
                        compiler_root=args.compiler_root)
                else:
                    _hardlink_tree(variants[0][1] / "dependencies", install / "dependencies")
                    receipt = portable_stack.dependency_identity(install / "dependencies", execute=True)
                source_receipt = None
                if label == "combined_adverse":
                    source_receipt = portable_stack.stage_source(
                        ROOT, source["source_commit"], install / "source")
                if firewall is not None:
                    firewall.block(_compiler_executables(install / "dependencies"))
                env = _environment(install)
                environment_record = {key: env.get(key, "") for key in (
                    "PATH", "CYBERSAND_LAB_CXX", "TEMP", "TMP", "SystemRoot")}
                with _environment_scope(env):
                    identity = _tool_identity(install, env)
                    mini = _mini_link_test(install, env, firewall)
                    lab_result = None
                    if label == "combined_adverse":
                        try:
                            lab_result = _actual_lab_world(install, env, firewall)
                        except BaseException as error:
                            lab_result = {"status": "failed",
                                          "error": type(error).__name__ + ": " + str(error)}
                path_passed = (identity.get("all_programs_inside_bundle") is True and
                               mini.get("status") == "passed" and
                               (label != "combined_adverse" or
                                (lab_result is not None and lab_result.get("status") == "passed")))
                item = {**describe_path(label, install), "status": "passed" if path_passed else "failed",
                        "effective_authoring_environment": environment_record,
                        "dependency_receipt": receipt, "source_receipt": source_receipt,
                        "compiler_readback": identity,
                        "minimal_compile_link_execute": mini,
                        "material_lab_world": lab_result}
            except BaseException as error:
                item = {**describe_path(label, install), "status": "failed",
                        "effective_authoring_environment": environment_record,
                        "error": type(error).__name__ + ": " + str(error)}
            report["path_variants"].append(item)
            report["actual_materials_lab"] = report["actual_materials_lab"] or item.get("material_lab_world")
            report["status"] = "passed" if all(row["status"] == "passed" for row in report["path_variants"]) else "failed"
            write_json(output / "portable-authoring-witness.json", report)
            identity = item.get("compiler_readback", {})
            ld = identity.get("ld", {})
            mini = item.get("minimal_compile_link_execute", {})
            print(json.dumps({"path": label, "status": item["status"],
                              "mini_status": mini.get("status"),
                              "mini_error": mini.get("compiler_error"),
                              "ld_reported": ld.get("reported_by_compiler"),
                              "ld_resolved": ld.get("resolved_path")},
                             ensure_ascii=False, sort_keys=True), flush=True)
    finally:
        if firewall is not None:
            report["offline_blocked_executables"] = list(firewall.executables)
            try:
                report["firewall_postflight"] = firewall.preflight()
                if report["firewall_postflight"].get("status") != "passed":
                    report["status"] = "failed"
            except BaseException as error:
                report["firewall_postflight"] = {"status": "failed",
                                                 "error": type(error).__name__ + ": " + str(error)}
                report["status"] = "failed"
            try:
                report["firewall_cleanup"] = firewall.remove()
            except BaseException as error:
                report["firewall_cleanup"] = {"status": "failed",
                                               "error": type(error).__name__ + ": " + str(error)}
                report["status"] = "failed"
                write_json(output / "portable-authoring-witness.json", report)
                raise
            write_json(output / "portable-authoring-witness.json", report)
            need(report["firewall_postflight"].get("status") == "passed",
                 "Windows Firewall service/profile state changed during offline qualification")
    need(len(report["path_variants"]) == len(variants), "Not all installation path controls completed")
    need(all(row["status"] == "passed" for row in report["path_variants"]),
         "At least one portable compiler installation path failed")
    need(report["actual_materials_lab"] is not None,
         "The combined adverse path did not execute the actual Materials Lab World backend")
    report["status"] = "passed"
    write_json(output / "portable-authoring-witness.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler-root", type=Path, default=Path(r"C:\mingw64"))
    parser.add_argument("--git-root", type=Path, default=Path(r"C:\Program Files\Git"))
    parser.add_argument("--python-root", type=Path, default=Path(sys.base_prefix))
    parser.add_argument("--parent", type=Path, default=Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir())))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--run-id", default=os.environ.get("GITHUB_RUN_ID", "local"))
    parser.add_argument("--block-network", action="store_true",
                        help="Require and remove temporary per-executable Windows Firewall egress blocks")
    args = parser.parse_args()
    try:
        report = run(args)
        print(json.dumps({"status": report["status"], "source": report["source"]["source_commit"],
                          "installation_paths": len(report["path_variants"]),
                          "actual_materials_lab": report["actual_materials_lab"]["state"]},
                         ensure_ascii=False, sort_keys=True), flush=True)
        return 0
    except BaseException as error:
        print(type(error).__name__ + ": " + str(error), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
