#!/usr/bin/env python3
"""Qualify authored-file replacement using disposable data and real OS faults.

This runner never publishes runtime binaries. It separates deterministic injected
I/O tests, Linux resource/permission faults, Windows sharing locks and deliberate
process termination. These tests do not establish power-loss/storage durability.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time


ERRORS = re.compile(r"SCRIPT ERROR|Parse Error|Failed to load script|Invalid call|Invalid access")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


@contextmanager
def windows_lock(path: Path, *, source: bool = False):
    """An actual READ handle; omit DELETE sharing for the selected endpoint."""
    import ctypes
    from ctypes import wintypes
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    create = kernel.CreateFileW
    create.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                       ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    create.restype = wintypes.HANDLE
    close = kernel.CloseHandle
    close.argtypes = [wintypes.HANDLE]
    close.restype = wintypes.BOOL
    handle = create(str(path), 0x80000000, 3 if source else 1, None, 3, 0x80, None)
    require(handle != wintypes.HANDLE(-1).value,
            f"Could not establish Windows sharing lock: {ctypes.get_last_error()}")
    try:
        # Verify the actual causal fence, without deleting or modifying a file.
        probe = create(str(path), 0x10000, 7, None, 3, 0x80, None)
        error = ctypes.get_last_error()
        if probe != wintypes.HANDLE(-1).value:
            close(probe)
            raise RuntimeError("Windows fixture did not deny DELETE access")
        require(error == 32, f"Expected Windows sharing violation 32, observed {error}")
        yield {"desired_access": 0x80000000, "share_mode": 3 if source else 1,
               "delete_access_probe_error": error}
    finally:
        require(bool(close(handle)), "Could not close Windows sharing-lock handle")


class Runner:
    def __init__(self, args):
        self.engine = args.godot.resolve()
        self.project = args.project.resolve()
        self.evidence = args.evidence.resolve()
        self.evidence.mkdir(parents=True, exist_ok=True)
        # Every invocation gets a fresh private profile, including repeated CI.
        self.userdata = Path(tempfile.mkdtemp(prefix="profile-", dir=self.evidence))
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.userdata), APPDATA=str(self.userdata))
        self.command = [str(self.engine), "--headless", "--audio-driver", "Dummy",
                        "--path", str(self.project), "--script", "res://tests/workbench_save_fault_child.gd"]
        self.rows = []
        self.sequence = 0

    def environment(self, kind, phase, **extra):
        return dict(self.env, CYBERSAND_SAVE_KIND=kind, CYBERSAND_SAVE_PHASE=phase,
                    CYBERSAND_SAVE_VALUE="old" if phase == "prepare" else "new", **extra)

    def decode(self, output, marker="WORKBENCH_SAVE_RESULT "):
        require(not ERRORS.search(output), "Godot script error; inspect retained log")
        matches = [line[len(marker):] for line in output.splitlines() if line.startswith(marker)]
        require(len(matches) == 1, f"Expected one completion marker {marker!r}")
        return json.loads(matches[0])

    def run(self, kind, phase, *, label=None, preexec=None, **extra):
        self.sequence += 1
        label = label or f"{kind}-{phase}-{self.sequence}"
        completed = subprocess.run(self.command, env=self.environment(kind, phase, **extra),
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                   encoding="utf-8", errors="replace", timeout=90, preexec_fn=preexec)
        (self.evidence / f"{label}.log").write_text(completed.stdout, encoding="utf-8")
        require(completed.returncode == 0, f"Child {label} exited {completed.returncode}")
        return self.decode(completed.stdout)

    def gate(self, value="new"):
        self.sequence += 1
        gate = self.evidence / f"gate-{self.sequence}.ready"
        env = self.environment("helper", "attempt", CYBERSAND_SAVE_GATE=str(gate))
        env["CYBERSAND_SAVE_VALUE"] = value
        process = subprocess.Popen(self.command, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        lines = []
        messages = queue.Queue()

        def consume():
            for line in process.stdout:
                lines.append(line)
                messages.put(line)
            messages.put(None)

        reader = threading.Thread(target=consume, daemon=True)
        reader.start()
        deadline = time.monotonic() + 60
        try:
            while time.monotonic() < deadline:
                line = messages.get(timeout=max(0.1, deadline - time.monotonic()))
                require(line is not None, "Child exited before commit gate")
                if line.startswith("SAVE_COMMIT_READY "):
                    return process, gate, json.loads(line[len("SAVE_COMMIT_READY "):]), lines, reader
            raise RuntimeError("Child failed to reach commit gate")
        except BaseException:
            process.kill()
            process.wait(timeout=15)
            reader.join(timeout=5)
            (self.evidence / f"gate-start-failed-{self.sequence}.log").write_text("".join(lines), encoding="utf-8")
            raise

    def finish(self, child, label, *, terminate=False):
        process, gate, _, lines, reader = child
        if terminate:
            process.kill()
        else:
            gate.write_text("commit\n", encoding="utf-8")
        try:
            code = process.wait(timeout=60)
        except BaseException:
            process.kill()
            process.wait(timeout=15)
            raise
        finally:
            reader.join(timeout=5)
            (self.evidence / f"{label}.log").write_text("".join(lines), encoding="utf-8")
        if terminate:
            require(code != 0, "Deliberately killed process unexpectedly returned success")
            return {"exit_code": code, "termination":"SIGKILL" if sys.platform != "win32" else "TerminateProcess"}
        require(code == 0, f"Commit-gated child exited {code}")
        return self.decode("".join(lines))

    def preserve(self, kind, prepared, refused, fault):
        require(bool(refused["error"]), f"{kind}/{fault}: failed save reported success")
        require(prepared["after_sha256"] == refused["after_sha256"], f"{kind}/{fault}: old bytes changed")
        require(refused["readable"], f"{kind}/{fault}: old save cannot reload")
        recovered = self.run(kind, "attempt", label=f"{kind}-{fault}-retry")
        require(not recovered["error"] and recovered["readable"], f"{kind}/{fault}: normal retry failed")
        require(recovered["after_sha256"] != prepared["after_sha256"], f"{kind}/{fault}: retry did not commit new document")
        self.rows.append({"kind":kind, "fault":fault, "evidence_class":"real-os-failure",
                          "before":prepared, "refusal":refused, "retry":recovered})

    def qualify(self):
        command = self.command[:-1] + ["res://tests/test_workbench_file_transaction.gd"]
        unit = subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=90)
        output = unit.stdout + unit.stderr
        (self.evidence / "injected-and-native-boundaries.log").write_text(output, encoding="utf-8")
        require(unit.returncode == 0, "Injected boundary regression failed")
        result = self.decode(output, "FILE_TRANSACTION_RESULT ")
        require(not result["failures"], "Injected boundary regression reported failures")
        self.rows.append({"kind":"shared-helper", "evidence_class":"injected-and-native-boundaries", "result":result})

        for kind in ("ordinary", "generated", "project"):
            prepared = self.run(kind, "prepare")
            require(not prepared["error"] and prepared["readable"], f"{kind}: initial save/reload failed")
            replaced = self.run(kind, "attempt")
            require(not replaced["error"] and replaced["readable"], f"{kind}: replacement/reload failed")
            require(prepared["after_sha256"] != replaced["after_sha256"], f"{kind}: new bytes not published")
            self.rows.append({"kind":kind, "evidence_class":"real-writer-fresh-process-reload",
                              "before":prepared, "replacement":replaced})
            prepared = self.run(kind, "prepare")
            target = Path(prepared["path"])
            if sys.platform == "win32":
                with windows_lock(target) as lock:
                    refused = self.run(kind, "attempt", label=f"{kind}-locked-target")
                self.preserve(kind, prepared, refused, "locked-target")
                self.rows[-1]["lock"] = lock
            else:
                import resource

                def limit():
                    resource.setrlimit(resource.RLIMIT_FSIZE, (128, 128))
                    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
                    signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

                refused = self.run(kind, "attempt", preexec=limit, label=f"{kind}-limited-write")
                self.preserve(kind, prepared, refused, "RLIMIT_FSIZE-128-SIGXFSZ-ignored")
                prepared = self.run(kind, "prepare")
                permissions = target.parent.stat().st_mode
                try:
                    target.parent.chmod(0o555)
                    refused = self.run(kind, "attempt", label=f"{kind}-permission-denied")
                finally:
                    target.parent.chmod(permissions)
                self.preserve(kind, prepared, refused, "directory-permission-denied")

        prepared = self.run("helper", "prepare")
        child = self.gate()
        staging = Path(child[2]["staging"])
        staged_sha = sha(staging)
        target = Path(child[2]["target"])
        if sys.platform == "win32":
            with windows_lock(staging, source=True) as lock:
                refused = self.finish(child, "helper-locked-source")
            fault = "locked-source-with-unlocked-destination"
        else:
            permissions = target.parent.stat().st_mode
            try:
                target.parent.chmod(0o555)
                refused = self.finish(child, "helper-replace-permission-denied")
            finally:
                target.parent.chmod(permissions)
            fault = "replacement-directory-permission-denied"
            lock = None
        require(staging.exists() and sha(staging) == staged_sha, "Refusal did not preserve the complete blocked staging file")
        require(Path(refused["transaction"]["staging_retained"]) == staging, "Cleanup refusal not reported accurately")
        self.preserve("helper", prepared, refused, fault)
        self.rows[-1].update(staging_sha256=staged_sha, lock=lock)
        staging.unlink()

        # A process interrupted after closed-byte verification cannot publish a
        # half file. Retained staging is ignored, and an ordinary retry works.
        prepared = self.run("helper", "prepare")
        child = self.gate()
        staging = Path(child[2]["staging"])
        staged_sha = sha(staging)
        stopped = self.finish(child, "helper-process-termination", terminate=True)
        verified = self.run("helper", "verify")
        require(verified["after_sha256"] == prepared["after_sha256"] and verified["readable"], "Killed writer changed old save")
        require(staging.exists() and sha(staging) == staged_sha, "Killed writer did not leave intact isolated staging")
        recovered = self.run("helper", "attempt")
        require(not recovered["error"] and recovered["readable"] and recovered["value"] == "new", "Retry after termination failed")
        require(staging.exists() and sha(staging) == staged_sha, "Retry consumed another process's stale staging")
        self.rows.append({"kind":"helper", "fault":"process-termination-before-commit", "evidence_class":"real-process-termination",
                          "before":prepared, "after":verified, "retry":recovered, "staging_sha256":staged_sha, **stopped})
        staging.unlink()

        # Two independent processes deliberately reach the same commit boundary.
        # Each publishes one whole document; the later commit wins. No claim of
        # conflict detection, ordered edits or a cross-process lock is made.
        self.run("helper", "prepare")
        first, second = self.gate("first"), self.gate("second")
        require(first[2]["staging"] != second[2]["staging"], "Concurrent writers share staging")
        first[1].write_text("commit\n", encoding="utf-8")
        second[1].write_text("commit\n", encoding="utf-8")
        a = self.finish(first, "concurrent-first")
        b = self.finish(second, "concurrent-second")
        final = self.run("helper", "verify")
        require(not a["error"] and not b["error"], "Concurrent complete replacement refused")
        require(final["readable"] and final["value"] in ("first", "second"), "Concurrent replacement produced mixed/corrupt bytes")
        self.rows.append({"kind":"helper", "evidence_class":"real-concurrent-processes", "first":a, "second":b, "final":final})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, default=Path("build/workbench-save-qualification"))
    args = parser.parse_args()
    runner = Runner(args)
    root = runner.project.parent
    inputs = ["godot/scripts/workbench_file_transaction.gd", "godot/scripts/workbench_setup.gd",
              "godot/scripts/workbench_generated_map.gd", "godot/scripts/architectural_generator_dialog.gd",
              "godot/scripts/workbench_material_baseline.gd", "godot/native_extension/material_baseline_file.cpp",
              "godot/tests/test_workbench_file_transaction.gd", "godot/tests/workbench_save_fault_child.gd",
              "tools/ci/run_workbench_save_qualification.py"]
    version = subprocess.check_output([str(runner.engine), "--version"], text=True).strip()
    require(version == "4.7.stable.official.5b4e0cb0f", f"Pinned Godot 4.7 required, got {version}")
    report = {"schema":"workbench-save-qualification-v1", "authority":"historical-non-authoritative",
              "platform":sys.platform, "engine_version":version, "engine_sha256":sha(runner.engine),
              "source_head":subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
              "input_sha256":{path:sha(root / path) for path in inputs},
              "native_sha256":sha(runner.project / "addons/cybersand_native/bin" /
                                   ("cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so")),
              "status":"running", "completed":False, "cases":runner.rows,
              "limits":["No power-loss/fsync/directory-sync durability claim",
                        "No physical NVIDIA owner acceptance", "No multi-file transaction exists in these three formats",
                        "No hostile cross-process filesystem interference or conflict-detection guarantee"]}
    try:
        runner.qualify()
        report.update(status="passed", completed=True)
        print(f"Workbench save qualification: PASS ({len(runner.rows)} cases, {sys.platform})")
        return 0
    except Exception as error:
        report.update(status="failed", error=str(error))
        print(f"Workbench save qualification: FAIL: {error}", file=sys.stderr)
        return 1
    finally:
        (runner.evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
