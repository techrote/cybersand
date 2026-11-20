#!/usr/bin/env python3
"""Fresh-process, real-Godot Art archive qualification with disposable user data.

The optional multi-GiB fixture contains real, valid JSONL bytes. It is neither a
filename mock nor sparse zeros. No existing user directory is accepted or erased.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
IMAGE_URL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwnnn3PwAFVQKpTzibEAAAAABJRU5ErkJggg=="
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")
MIB = 1024 * 1024
SENTINEL = b"EXISTING DESTINATION: cancellation must preserve these bytes.\n"


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for data in iter(lambda: source.read(MIB), b""):
            digest.update(data)
    return digest.hexdigest()


def jsonl(value: dict) -> bytes:
    return (json.dumps(value, separators=(",", ":")) + "\n").encode()


def inventory(directory: Path) -> dict:
    return {p.name: {"size": p.stat().st_size, "mtime_ns": p.stat().st_mtime_ns,
                     "sha256": sha(p)} for p in sorted(directory.iterdir()) if p.is_file()}


def unchanged(before: dict, after: dict) -> None:
    for name, identity in before.items():
        if after.get(name) != identity:
            raise AssertionError("Historical archive changed or vanished: " + name)


def verify_runtime(root: Path, platform: str) -> dict:
    filename = "runtime-provenance.linux.json" if platform == "linux" else "runtime-provenance.json"
    provenance = json.loads((root / "godot/addons/cybersand_native" / filename).read_text())
    for name, expected in provenance["source_inputs"].items():
        actual = hashlib.sha256((root / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        if actual != expected:
            raise ValueError("Retained native runtime does not match source: " + name)
    native = root / ("godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
                     if platform == "linux" else "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll")
    if sha(native) != provenance["sha256"] or native.stat().st_size != provenance["size"]:
        raise ValueError("Retained native runtime payload is absent or differs from provenance")
    rapier = root / ("godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
                     if platform == "linux" else "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
    # Committed Git LFS pointers are the binary authority, independently of a
    # materialized checkout or a historical provenance document.
    pointer = subprocess.check_output(["git", "show", "HEAD:" + rapier.relative_to(root).as_posix()], cwd=root)
    expected = re.search(rb"oid sha256:([0-9a-f]{64})", pointer)
    if expected is None or sha(rapier) != expected[1].decode():
        raise ValueError("Rapier payload differs from its committed LFS pin")
    return {"native_build_commit": provenance["source_commit"], "native_sha256": sha(native),
            "native_source_inputs": len(provenance["source_inputs"]), "rapier_sha256": sha(rapier)}


def package_project(destination: Path, platform: str) -> dict:
    """Archive and extract committed project bytes with verified retained runtimes.

    This is an extracted project package, using the separately authenticated
    Godot executable supplied by CI. It does not invent a fresh native build.
    """
    runtime = verify_runtime(ROOT, platform)
    if destination.exists():
        raise ValueError("Package destination must be new")
    destination.mkdir(parents=True)
    archive_path = destination / "workbench-project.zip"
    paths = subprocess.check_output(["git", "ls-files", "godot", "examples/worldgen"], cwd=ROOT, text=True).splitlines()
    staged = destination / "staged"
    for name in paths:
        if name.startswith("godot/.godot/"):
            continue
        if "/bin/" in name and not (name.endswith(".linux.x86_64.so") or
                                   name.endswith(".linux.x86_64-unknown-linux-gnu.so") or
                                   name.endswith(".windows.x86_64.dll") or
                                   name.endswith(".windows.x86_64-pc-windows-msvc.dll")):
            continue
        if "/bin/" in name and ((platform == "windows") != (".windows." in name)):
            continue
        data = (ROOT / name).read_bytes()
        # Scripts/tests must be the exact committed candidate; only verified
        # LFS binaries are taken from their materialized worktree payload.
        original = subprocess.check_output(["git", "show", "HEAD:"+name], cwd=ROOT)
        if not original.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            data = original
        elif data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            raise ValueError("Package includes an unmaterialized LFS pointer: " + name)
        target = staged / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    sys.path.insert(0, str(ROOT / "tools"))
    from package_explore001_candidate import stage_generator_profiles
    stage_generator_profiles(staged)
    files_sha256 = {p.relative_to(staged).as_posix(): sha(p) for p in sorted(staged.rglob("*")) if p.is_file()}
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in files_sha256:
            archive.write(staged / name, name)
    extracted = destination / "extracted"
    with zipfile.ZipFile(archive_path) as archive:
        archive.extractall(extracted)
    if any(sha(extracted/name)!=digest for name,digest in files_sha256.items()):
        raise ValueError("Extracted project differs from packaged manifest")
    result = {"archive": str(archive_path), "archive_sha256": sha(archive_path),
              "project": str(extracted / "godot"), "runtime": runtime,
              "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "files_sha256": files_sha256}
    (destination / "package-identity.json").write_text(json.dumps(result, indent=2)+"\n")
    return result


def fixture(case: Path, mib: int) -> tuple[dict, Path, dict]:
    data_home = case / "userdata"
    user = data_home / ("Godot" if sys.platform == "win32" else "godot") / "app_userdata/Cyber Sand Reference Sandbox"
    traffic = user / "art-traffic"
    traffic.mkdir(parents=True, exist_ok=False)
    path = traffic / "legacy.jsonl"
    digest = hashlib.sha256()
    start = time.monotonic()
    with path.open("wb") as output:
        for value in [{"kind": "request", "data": {"body": {"input": [{"role": "user", "content": [{"type": "input_image", "image_url": IMAGE_URL}]}]}}},
                      {"kind": "conversation", "data": {"role": "user", "content": "legacy seed", "image_offset": 0}}]:
            row = jsonl(value)
            output.write(row)
            digest.update(row)
        row = jsonl({"kind": "response", "data": {"body": "X" * (MIB - 42)}})
        while output.tell() < mib * MIB:
            output.write(row)
            digest.update(row)
    (user / "art-provider.cfg").write_text('[session]\ntraffic_path="user://art-traffic/legacy.jsonl"\n', encoding="utf-8")
    env = dict(os.environ, XDG_DATA_HOME=str(data_home), APPDATA=str(data_home),
               ART_LIFETIME_USER_DIR=str(user), GODOT_SILENCE_ROOT_WARNING="1")
    info = {"bytes": path.stat().st_size, "allocated_bytes": getattr(path.stat(), "st_blocks", 0)*512,
            "sha256": digest.hexdigest(), "generation_seconds": time.monotonic()-start}
    return env, traffic, info


def process_metrics(process: subprocess.Popen, engine_pid=None) -> dict:
    if sys.platform.startswith("linux"):
        result = {}
        pid = engine_pid or process.pid
        try:
            status = Path(f"/proc/{pid}/status").read_text()
            match = re.search(r"VmHWM:\s+(\d+) kB", status)
            if match:
                result["peak_rss_bytes"] = int(match[1])*1024
            for line in Path(f"/proc/{pid}/io").read_text().splitlines():
                key, value = line.split(":")
                result[key] = int(value)
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            pass
        return result
    if sys.platform == "win32":
        from ctypes import wintypes
        class Memory(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [(x, ctypes.c_size_t) for x in (
                "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage",
                "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage")]
        class IO(ctypes.Structure):
            _fields_ = [(x, ctypes.c_ulonglong) for x in ("ReadOperationCount", "WriteOperationCount", "OtherOperationCount", "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]
        memory, io = Memory(), IO()
        memory.cb = ctypes.sizeof(memory)
        own_handle = engine_pid and engine_pid!=process.pid
        ctypes.windll.kernel32.OpenProcess.restype = wintypes.HANDLE
        handle = wintypes.HANDLE(ctypes.windll.kernel32.OpenProcess(0x0400|0x0010, False, engine_pid)) if own_handle else wintypes.HANDLE(int(process._handle))
        result = {}
        if ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(memory), memory.cb):
            result["peak_rss_bytes"] = memory.PeakWorkingSetSize
        if ctypes.windll.kernel32.GetProcessIoCounters(handle, ctypes.byref(io)):
            result.update(read_transfer_bytes=io.ReadTransferCount, write_transfer_bytes=io.WriteTransferCount)
        if own_handle and handle:
            ctypes.windll.kernel32.CloseHandle(handle)
        return result
    return {}


def stop_process_tree(process: subprocess.Popen) -> None:
    if sys.platform=="win32":
        # The Godot console stub owns the real GUI/runtime process. Killing only
        # the stub would leave an active writer and invalidate a crash test.
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT, timeout=30)
    elif process.poll() is None:
        process.kill()


class Qualification:
    def __init__(self, args):
        self.args = args
        self.evidence = args.evidence.resolve()
        self.evidence.mkdir(parents=True, exist_ok=False)
        self.summary = {"schema": 1, "platform": sys.platform, "engine": subprocess.check_output([str(args.godot), "--version"], text=True).strip(),
                        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                        "results": [], "cases": {}, "runtime": verify_runtime(ROOT, "windows" if sys.platform=="win32" else "linux")}
        self.identity_paths = sorted((args.project / "scripts").glob("art*.gd")) + [args.project / "scripts/shared_workbench.gd"] + sorted((args.project / "tests").glob("*art*.gd"))
        self.summary["executed_source_sha256"] = {p.relative_to(args.project).as_posix(): sha(p) for p in self.identity_paths}
        self.summary["harness_sha256"] = sha(Path(__file__))
        self.summary["working_tree_status"] = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines()
        self.io_probe = None
        if sys.platform.startswith("linux") and shutil.which("cc"):
            self.io_probe = self.evidence / "art-traffic-io-probe.so"
            subprocess.run(["cc", "-shared", "-fPIC", "-O2", str(ROOT / "tools/ci/art_traffic_io_probe.c"), "-o", str(self.io_probe), "-ldl"], check=True)
            self.summary["io_observer"] = "libc archive fopen/fread/fwrite observer; counts actual operations in isolated child only"

    def save(self):
        (self.evidence / "summary.json").write_text(json.dumps(self.summary, indent=2)+"\n", encoding="utf-8")

    def execute(self, label, env, *, project=None, mode=None, ordinal=0, script=None, export=None, kill=False, trace=False, timeout=1200):
        report = self.evidence / (label + ".json")
        log = self.evidence / (label + ".log")
        command = [str(self.args.godot), "--audio-driver", "Dummy", "--max-fps", "120"]
        if self.args.graphical:
            command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"] if sys.platform=="win32" else ["--rendering-method", "gl_compatibility", "--display-driver", "x11"]
        else:
            command += ["--headless"]
        command += ["--path", str(project or self.args.project)]
        if script:
            command += ["--script", "res://tests/"+script+".gd"]
        elif mode:
            command += ["--script", "res://tests/run_art_traffic_lifetime.gd"]
        else:
            command += ["--editor", "--quit"]
        if trace and sys.platform.startswith("linux") and shutil.which("strace"):
            command = ["strace", "-f", "-yy", "-o", str(self.evidence / (label+".strace")), "-e", "trace=openat,read,write,pread64,pwrite64,copy_file_range,sendfile,rename,unlink,ftruncate"] + command
        effective_env = dict(env, ART_LIFETIME_MODE=mode or "", ART_LIFETIME_ORDINAL=str(ordinal),
                             ART_LIFETIME_RECEIPT=str(report), ART_LIFETIME_EXPORT=str(export or ""))
        io_receipt = self.evidence / (label+"-archive-io.json")
        if self.io_probe:
            effective_env["LD_PRELOAD"] = str(self.io_probe) + (":" + effective_env["LD_PRELOAD"] if effective_env.get("LD_PRELOAD") else "")
            effective_env["ART_TRAFFIC_IO_RECEIPT"] = str(io_receipt)
        actual_project = project or self.args.project
        record = {"label": label, "command": command, "mode": mode, "project": str(actual_project),
                  "production_inputs_sha256": {name: sha(actual_project / "scripts" / name) for name in ("art_provider.gd", "art_batch_panel.gd", "shared_workbench.gd")}}
        self.summary["results"].append(record)
        start = time.monotonic()
        metrics = {}
        engine_pid = None
        scanned_bytes, last_scan, scan_tail = 0, start, ""
        try:
            with log.open("w", encoding="utf-8") as output:
                process = subprocess.Popen(command, cwd=self.evidence, env=effective_env, stdout=output, stderr=subprocess.STDOUT)
                while process.poll() is None:
                    partial_receipt = {}
                    if report.exists():
                        try:
                            partial_receipt = json.loads(report.read_text())
                            engine_pid = partial_receipt.get("process_pid", engine_pid)
                        except json.JSONDecodeError:
                            pass
                    for key, value in process_metrics(process, engine_pid).items():
                        metrics[key] = max(metrics.get(key, 0), value)
                    if time.monotonic()-last_scan>=0.25:
                        with log.open("rb") as stream:
                            stream.seek(scanned_bytes)
                            chunk = stream.read(65536)
                            scanned_bytes += len(chunk)
                        scan_text = scan_tail+chunk.decode("utf-8", errors="replace")
                        scan_tail = scan_text[-100:]
                        last_scan = time.monotonic()
                        if ERRORS.search(scan_text):
                            record["stopped_on_script_error"] = True
                            stop_process_tree(process)
                    if kill:
                        if partial_receipt.get("kill_ready"):
                            stop_process_tree(process)
                            record["killed_after_checkpoint"] = True
                    if time.monotonic()-start > timeout:
                        stop_process_tree(process)
                        raise TimeoutError(label)
                    time.sleep(0.01)
                process.wait()
            record.update(exit_code=process.returncode, elapsed_seconds=time.monotonic()-start, process_metrics=metrics, engine_pid=engine_pid,
                          metrics_scope="engine" if engine_pid or sys.platform!="win32" else "console wrapper; not engine memory")
            if io_receipt.exists():
                record["archive_io"] = json.loads(io_receipt.read_text())
                if mode=="idle" and any(record["archive_io"].values()):
                    raise AssertionError("Idle startup performed archive fopen/read/write")
            text = log.read_text(encoding="utf-8", errors="replace")
            if ERRORS.search(text):
                raise AssertionError("Godot script errors: " + str(log))
            if not kill and process.returncode:
                raise AssertionError("Godot failed: " + str(log))
            if kill and not record.get("killed_after_checkpoint"):
                raise AssertionError("Crash test never reached its checkpoint")
            if mode:
                record["receipt"] = json.loads(report.read_text())
                if record["receipt"].get("failures") or record["receipt"].get("checks", 0)<1:
                    raise AssertionError("Godot lifetime assertions failed: " + str(report))
                if not kill and not record["receipt"].get("completed"):
                    raise AssertionError("Process exited without completing its lifetime phase")
            record["status"] = "passed"
            print("PASS", label, flush=True)
            return record.get("receipt", {})
        except Exception as error:
            record.update(status="failed", error=str(error))
            if log.exists():
                print(log.read_text(encoding="utf-8", errors="replace")[-6000:], file=sys.stderr)
            raise
        finally:
            self.save()

    def case(self, name, mib):
        env, traffic, fixture_info = fixture(self.evidence / name, mib)
        self.summary["cases"][name] = {"fixture": fixture_info, "initial": inventory(traffic)}
        return env, traffic

    def run(self):
        env, traffic = self.case("ordinary", 4)
        self.execute("import", env)
        initial = inventory(traffic)
        for i in range(3):
            self.execute(f"idle-{i+1}", env, mode="idle", trace=(i==0 and self.args.trace_idle))
            if inventory(traffic) != initial:
                raise AssertionError("Idle Workbench changed archive filenames, sizes, mtimes or hashes")
        for i in range(1,4):
            before = inventory(traffic)
            self.execute(f"continue-{i}", env, mode="continue", ordinal=i)
            after = inventory(traffic)
            unchanged(before, after)
            created = set(after)-set(before)
            if len(created)!=1 or sum(after[n]["size"] for n in created)>16384:
                raise AssertionError("Continuation created more than one bounded small segment")
            self.summary["cases"]["ordinary"][f"continue_{i}_growth_bytes"] = sum(after[n]["size"] for n in created)
        self.execute("reopen-three", env, mode="reopen", ordinal=3)
        destination = self.evidence / "ordinary-full.jsonl"
        receipt = self.execute("full-export", env, mode="export", ordinal=3, export=destination)
        self.verify_export(receipt["chain"], traffic, destination)
        preserved = inventory(traffic)
        destination.write_bytes(SENTINEL)
        self.execute("cancel-export", env, mode="cancel_export", ordinal=3, export=destination)
        if destination.read_bytes()!=SENTINEL:
            raise AssertionError("Cancel overwrote an existing destination")
        self.execute("crash-export", env, mode="crash_export", ordinal=3, export=destination, kill=True)
        if destination.read_bytes()!=SENTINEL:
            raise AssertionError("Interrupted export replaced its destination")
        unchanged(preserved, inventory(traffic))
        self.execute("crash-write", env, mode="crash_write", ordinal=4, kill=True)
        interrupted = inventory(traffic)
        reopened = self.execute("recover-after-crash", env, mode="reopen", ordinal=4)
        if not reopened.get("resume_warning"):
            raise AssertionError("Recovered truncated write was not disclosed")
        self.execute("continue-after-crash", env, mode="continue", ordinal=5)
        unchanged(interrupted, inventory(traffic))
        self.execute("reopen-after-recovery", env, mode="reopen", ordinal=5)
        sys.path.insert(0, str(ROOT / "tools"))
        from test_art_provider_transport import Handler
        received_marker = self.evidence / "cancel-continuation-request-received.txt"
        class StartedHandler(Handler):
            def do_POST(self):
                received_marker.write_text("delayed fixture received HTTP request headers\n", encoding="utf-8")
                super().do_POST()
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), StartedHandler)
        server.daemon_threads = True
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            before_cancel = inventory(traffic)
            receipt = self.execute("cancel-continuation", dict(env, ART_LIFETIME_ENDPOINT=f"http://127.0.0.1:{server.server_port}/v1", ART_LIFETIME_REQUEST_RECEIVED=str(received_marker)), mode="cancel_continue", ordinal=5)
            after_cancel = inventory(traffic)
            unchanged(before_cancel, after_cancel)
            created = set(after_cancel)-set(before_cancel)
            if len(created)!=1 or sum(after_cancel[n]["size"] for n in created)>16384:
                raise AssertionError("Cancelled Send did not create one bounded continuation segment")
            with (traffic / next(iter(created))).open(encoding="utf-8") as source:
                events = [json.loads(line) for line in source]
            kinds = [event["kind"] for event in events]
            if kinds != ["session_parent", "request", "conversation", "cancelled"] or events[-1]["data"]!="Human Stop":
                raise AssertionError("Cancelled Send did not preserve ordered request, user prompt and Human Stop events")
            self.summary["cases"]["ordinary"]["cancelled_continuation"] = {"event_kinds": kinds, "request_received": receipt["request_received"], "growth_bytes": sum(after_cancel[n]["size"] for n in created)}
            self.execute("reopen-cancelled-continuation", env, mode="reopen_cancelled", ordinal=5)
        finally:
            server.shutdown()
            server.server_close()
        if self.args.stress_mib:
            stress_env, stress_traffic = self.case("stress", self.args.stress_mib)
            baseline = inventory(stress_traffic)
            for i in range(3):
                self.execute(f"stress-idle-{i+1}", stress_env, mode="idle", trace=(i==0 and self.args.trace_idle))
                if inventory(stress_traffic)!=baseline:
                    raise AssertionError("Stress idle startup changed historical archive bytes")
            self.execute("stress-cancel-restore", stress_env, mode="cancel_restore")
            if inventory(stress_traffic)!=baseline:
                raise AssertionError("Cancelling restore changed archive bytes or filenames")
            self.execute("stress-continue", stress_env, mode="continue", ordinal=1)
            unchanged(baseline, inventory(stress_traffic))
            stress_export = self.evidence / "stress-full.jsonl"
            receipt = self.execute("stress-export", stress_env, mode="export", ordinal=1, export=stress_export)
            self.verify_export(receipt["chain"], stress_traffic, stress_export)
            unchanged(baseline, inventory(stress_traffic))
            measured = {r["label"]: r.get("process_metrics", {}).get("peak_rss_bytes", 0) for r in self.summary["results"]}
            idle_rss = max(measured.get(f"stress-idle-{i+1}", 0) for i in range(3))
            export_rss = measured.get("stress-export", 0)
            continuation_rss = measured.get("stress-continue", 0)
            if min(idle_rss, export_rss, continuation_rss)<=0:
                raise AssertionError("Missing actual engine memory measurement")
            additional_rss = max(export_rss, continuation_rss)-idle_rss
            self.summary["cases"]["stress"]["memory"] = {"idle_peak_rss_bytes": idle_rss, "continuation_peak_rss_bytes": continuation_rss,
                                                        "export_peak_rss_bytes": export_rss, "additional_rss_bytes": additional_rss,
                                                        "additional_rss_limit_bytes": 256*MIB}
            if additional_rss>256*MIB:
                raise AssertionError("Large archive continuation/export exceeded bounded additional memory")
        if self.args.baseline_project:
            old_env, old_traffic = self.case("eager-baseline", 64)
            before = inventory(old_traffic)
            self.execute("eager-before", old_env, project=self.args.baseline_project, mode="baseline_idle", trace=self.args.trace_idle)
            after = inventory(old_traffic)
            unchanged(before, after)
            self.summary["cases"]["eager-baseline"]["idle_growth_bytes"] = sum(v["size"] for k,v in after.items() if k not in before)
        if not self.args.skip_regressions:
            self.regressions()
        self.summary["status"] = "passed"
        final_identity = {p.relative_to(self.args.project).as_posix(): sha(p) for p in self.identity_paths}
        if final_identity != self.summary["executed_source_sha256"]:
            self.summary["status"] = "source_changed_during_execution"
            self.save()
            raise AssertionError("Execution source changed during qualification; retain results as engineering evidence and rerun final source")
        self.save()

    def verify_export(self, chain, traffic, destination):
        digest, size = hashlib.sha256(), 0
        for segment in chain:
            with (traffic / Path(segment).name).open("rb") as source:
                for data in iter(lambda: source.read(MIB), b""):
                    digest.update(data)
                    size += len(data)
        if destination.stat().st_size!=size or sha(destination)!=digest.hexdigest():
            raise AssertionError("Export differs from the ordered complete source event stream")
        self.summary["cases"].setdefault("exports", {})[destination.name] = {"bytes": size, "sha256": digest.hexdigest(), "byte_equality": True}

    def regressions(self):
        scripts = ["test_art_provider", "test_art_lazy_traffic", "test_art_traffic_integrity", "test_art_traffic_panel_safety", "test_art_panel_ui", "test_art_stored_material", "test_art_deferred_manual", "test_art_batch_native", "test_workbench_edit_ordering", "test_workbench_deferred_paint", "test_paint_editor_shapes", "test_paint_editor_executor", "test_paint_editor_recovery", "test_paint_editor_native", "test_art_undo", "test_workbench_input"]
        if self.args.graphical:
            scripts.append("test_art_batch_native_render")
        for script in scripts:
            data_home = self.evidence / (script+"-userdata")
            data_home.mkdir(exist_ok=False)
            env = dict(os.environ, XDG_DATA_HOME=str(data_home), APPDATA=str(data_home), GODOT_SILENCE_ROOT_WARNING="1")
            self.execute(script, env, script=script)
        data_home = self.evidence / "http-userdata"
        data_home.mkdir(exist_ok=False)
        env = dict(os.environ, XDG_DATA_HOME=str(data_home), APPDATA=str(data_home), GODOT_SILENCE_ROOT_WARNING="1")
        command = [sys.executable, str(ROOT / "tools/test_art_provider_transport.py"), "--godot", str(self.args.godot), "--project", str(self.args.project), "--output", str(self.evidence / "http-fixtures")]
        if self.args.graphical:
            command.append("--graphical")
        with (self.evidence / "http-fixtures.log").open("w") as output:
            subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, check=True, timeout=1200)
        self.summary["http_transport"] = "passed: actual local HTTP plus native provider, cancellation and timeout"
        self.save()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--stress-mib", type=int, default=2048)
    parser.add_argument("--baseline-project", type=Path)
    parser.add_argument("--skip-regressions", action="store_true")
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--trace-idle", action="store_true")
    parser.add_argument("--package-project", type=Path)
    args = parser.parse_args()
    if args.package_project:
        print(json.dumps(package_project(args.package_project.resolve(), "windows" if sys.platform=="win32" else "linux"), indent=2))
        return
    if args.godot is None or args.evidence is None:
        parser.error("--godot and --evidence are required for execution")
    args.godot, args.project = args.godot.resolve(), args.project.resolve()
    if args.stress_mib<0:
        parser.error("stress size must be nonnegative")
    Qualification(args).run()


if __name__ == "__main__":
    main()
