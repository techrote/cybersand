#!/usr/bin/env python3
"""NONQUALIFYING cold shader-isolation evidence; never a Main/PACE003 pass.

The frozen shader and current candidate execute once each in fresh graphical
processes. Both original results survive, including a baseline timeout. The
existing process runner owns deadlines, diagnostics and process-tree cleanup.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import importlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/play"))
import run_pace003_campaign as campaign

runner = campaign.runner
BASELINE_COMMIT = "2443a78378d649df588efeac9db7c54084473329"
BASELINE_SHADER_SHA256 = "3d9ee3b04ce6eee03490ad2c4af1f487f208e9ff0db31e6d514127633c2e0fef"
SHADER_PATH = "godot/shaders/material_palette.gdshader"
ATLAS_PATH = "godot/tests/play_pace003_palette_atlas.gd"
COMPARATOR_PATH = "tools/play/compare_pace003_palette_atlas.py"
GL_TRACE_SOURCE_PATH = "tools/play/gl_startup_trace.c"
EXTRA_INPUTS = (ATLAS_PATH, COMPARATOR_PATH, "tools/play/run_pace003_shader_diagnostic.py",
                ".github/workflows/play-pace003-shader-diagnostic.yml", GL_TRACE_SOURCE_PATH,
                "tools/play/pace003_shader_variants.py", ".github/workflows/play-pace003-windows-paths.yml")
EXTRA_INPUTS += tuple("tools/play/d3d_compiler_trace/" + name for name in (
    "build_proxy.py", "d3dcompiler_trace.cpp", "proxy_preflight.cpp", "readback.py", "test_helpers.py"))
CASE_SECONDS = 180
SCHEMA = "play-pace003-shader-diagnostic-v1"
SCOPE = "NONQUALIFYING isolated shader experiment; not main.tscn/PACE003 acceptance"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def save(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def canonical_text_identity(raw: bytes, committed: bytes, relative: str) -> tuple[bytes, dict]:
    canonical = raw.replace(b"\r\n", b"\n")
    campaign.require(canonical == committed, "Diagnostic input differs from committed head: " + relative)
    return canonical, {"checkout_raw_sha256": digest(raw), "canonical_lf_sha256": digest(canonical),
                       "committed_blob_sha256": digest(committed), "checkout_raw_bytes": len(raw),
                       "canonical_lf_bytes": len(canonical), "crlf_normalized": raw != canonical}


def source_identity() -> dict:
    value = campaign.source_identity()
    value["diagnostic_text_input_identities"] = {}
    for relative in EXTRA_INPUTS:
        data = (ROOT / relative).read_bytes()
        _, identity = canonical_text_identity(data, campaign.windows.git(ROOT, "show", "HEAD:" + relative), relative)
        value["diagnostic_text_input_identities"][relative] = identity
        # Preserve the actual host's input-byte hash alongside its canonical
        # source identity. Windows core.autocrlf must not erase either receipt.
        value["execution_inputs"][relative] = digest(data)
    return value


def shader_inputs() -> tuple[bytes, bytes]:
    baseline = campaign.windows.git(ROOT, "show", BASELINE_COMMIT + ":" + SHADER_PATH)
    campaign.require(digest(baseline) == BASELINE_SHADER_SHA256, "Frozen baseline shader hash differs")
    candidate, _ = canonical_text_identity((ROOT / SHADER_PATH).read_bytes(),
        campaign.windows.git(ROOT, "show", "HEAD:" + SHADER_PATH), SHADER_PATH)
    campaign.require(candidate != baseline, "Candidate must differ from the frozen baseline")
    return baseline, candidate


def untraced_environment() -> dict[str, str]:
    child_env = os.environ.copy()
    child_env.pop("LD_AUDIT", None)
    child_env.pop("CYBERSAND_GL_TRACE_DIR", None)
    child_env.pop("PACE003_D3D_TRACE_DIR", None)
    return child_env


def retain_d3d_proxy(manifest_path: Path | None, godot: str, output: Path) -> dict:
    if manifest_path is None:
        return {"enabled": False}
    campaign.require(sys.platform == "win32", "D3D compiler capture requires actual Windows")
    manifest_path = manifest_path.resolve()
    manifest = campaign.load_json(manifest_path.read_text(encoding="utf-8"))
    proxy = Path(godot).resolve().parent / "d3dcompiler_47.dll"
    campaign.require(runner.sha256(proxy) == manifest["proxy"]["sha256"], "Installed proxy bytes differ from build")
    campaign.require(runner.sha256(Path(manifest["system_original"]["path"]))
                     == manifest["system_original"]["sha256"], "Authentic System32 compiler changed")
    preflight_path = manifest_path.parent / "preflight-result.json"
    preflight = campaign.load_json(preflight_path.read_text(encoding="utf-8"))
    campaign.require(all(preflight.get(key) is True for key in (
        "passed", "compile_and_compile2_byte_exact", "last_error_exact", "disassemble_forwarder_passed",
        "source_include_callbacks_passed", "failure_result_passed")), "D3D proxy preflight did not pass")
    observed = campaign.load_json((manifest_path.parent / "preflight-readback.json").read_text(encoding="utf-8"))
    campaign.require(observed.get("instrumentation_valid") is True and observed.get("preflight") is True,
                     "D3D preflight interception not independently validated")
    shutil.copyfile(proxy, output / "d3dcompiler_47.dll")
    shutil.copyfile(manifest_path, output / "d3d-proxy-build-receipt.json")
    return {"enabled": True, "scope": "NONQUALIFYING original D3DCompile input/call forwarding",
            "installed_proxy": str(proxy), "manifest": manifest,
            "manifest_sha256": runner.sha256(manifest_path),
            "preflight_sha256": runner.sha256(preflight_path),
            "preflight_scope": "Separate tiny compiler passthrough process; no Godot or palette warm-up"}


def retain_trace_library(library: Path | None, output: Path, source: dict) -> dict:
    if library is None:
        return {"enabled": False}
    campaign.require(sys.platform.startswith("linux"), "GL audit tracing is supported on Linux only")
    library = library.resolve()
    campaign.require(library.is_file() and library.stat().st_size > 0, "GL trace library is unavailable")
    retained = output / "gl_startup_trace.so"
    shutil.copyfile(library, retained)
    return {"enabled": True, "scope": "NONQUALIFYING LD_AUDIT driver-call instrumentation",
            "original_path": str(library), "retained_path": str(retained),
            "library_sha256": runner.sha256(retained), "library_bytes": retained.stat().st_size,
            "source_path": GL_TRACE_SOURCE_PATH,
            "source_identity": source["diagnostic_text_input_identities"][GL_TRACE_SOURCE_PATH]}


def trace_readback(path: Path) -> dict:
    traces = sorted(path.glob("gl-startup.*.jsonl"))
    campaign.require(bool(traces), "GL audit tracing produced no original event log")
    records = []
    for trace in traces:
        events = [campaign.load_json(line) for line in trace.read_text(encoding="utf-8").splitlines() if line]
        campaign.require(bool(events) and events[0].get("schema") == "cybersand-gl-startup-v1",
                         "GL trace header/schema missing")
        errors = [event for event in events if event.get("event") == "instrumentation_error"]
        campaign.require(not errors, "GL instrumentation reported an unresolved original symbol")
        footer = [event for event in events if event.get("event") == "footer"]
        records.append({"path": trace.name, "sha256": runner.sha256(trace), "events": len(events),
                        "footer": footer, "terminal_footer_present": len(footer) == 1,
                        "provider_bypasses": [event for event in events if event.get("event") == "instrumentation_bypass"]})
    return {"files": inventory(path), "traces": records,
            "scope_limit": "A timeout may lack a footer; event/source completeness must be reviewed before causal attribution"}


def inventory(path: Path) -> dict:
    campaign.require(not path.is_symlink(), "A diagnostic cache must not be a symlink: " + str(path))
    files = []
    if path.exists():
        campaign.require(path.is_dir(), "Expected a cache directory: " + str(path))
        for child in sorted(path.rglob("*")):
            campaign.require(not child.is_symlink(), "A diagnostic cache entry must not be a symlink")
            if child.is_file():
                files.append({"path": child.relative_to(path).as_posix(), "bytes": child.stat().st_size,
                              "sha256": runner.sha256(child)})
    return {"path": str(path), "exists": path.exists(), "file_count": len(files), "files": files}


def copy_warm_cache_inputs(source_caches: Path, source_project: Path,
                          caches: Path, project_cache: Path) -> tuple[dict, dict]:
    user_before = inventory(source_caches)
    project_before = inventory(source_project)
    campaign.require(user_before["exists"], "Retained cold user caches are missing")
    shutil.copytree(source_caches, caches, dirs_exist_ok=True)
    campaign.require(inventory(caches)["files"] == user_before["files"], "Warm user cache copy differs")
    if project_before["exists"]:
        shutil.copytree(source_project, project_cache)
    project_copy = inventory(project_cache)
    campaign.require(project_copy["exists"] == project_before["exists"]
                     and project_copy["files"] == project_before["files"], "Warm project shader cache copy differs")
    return user_before, project_before


def verify_warm_cache_sources(source_caches: Path, source_project: Path,
                             user_before: dict, project_before: dict) -> None:
    campaign.require(inventory(source_caches) == user_before,
                     "Original cold user caches changed during warm-copy comparison")
    campaign.require(inventory(source_project) == project_before,
                     "Original cold project shader cache changed during warm-copy comparison")


def read_d3d_trace(directory: Path, manifest: dict, warm: bool) -> dict:
    """A warm cache may avoid compilation; any observed proxy identity still must match."""
    readback = importlib.import_module("d3d_compiler_trace.readback")
    traces = []
    for path in sorted(directory.glob("*.jsonl")):
        raw = path.read_bytes()
        campaign.require(raw.endswith(b"\n"), "Partial original D3D trace line")
        events = [campaign.load_json(line) for line in raw.decode("utf-8").splitlines()]
        traces.append((path, events))
    if not warm or any(event.get("event") == "compile_begin" for _, events in traces for event in events):
        return readback.inspect(directory, manifest)
    identities = []
    normalize = lambda value: value.replace("/", "\\").casefold()
    for path, events in traces:
        campaign.require(bool(events) and events[0].get("event") == "identity", "Warm D3D trace lacks its original identity")
        identity = events[0]
        pid = identity["pid"]
        campaign.require(path.name == f"d3d-trace-{pid}.jsonl" and all(event["pid"] == pid for event in events),
                         "Warm D3D PID/file mismatch")
        indices = [event["event_index"] for event in events]
        campaign.require(len(set(indices)) == len(indices) and set(indices) == set(range(1, len(indices) + 1)),
                         "Warm D3D event indices are incomplete or duplicated")
        campaign.require(identity["system_sha256"] == identity["expected_system_sha256"]
                         == manifest["system_original"]["sha256"], "Warm D3D original System32 SHA mismatch")
        campaign.require(identity["proxy_sha256"] == manifest["proxy"]["sha256"], "Warm D3D loaded proxy SHA mismatch")
        campaign.require(normalize(identity["system_module"]) == normalize(manifest["system_original"]["path"])
                         and normalize(identity["system_module"]) != normalize(identity["proxy_module"]),
                         "Warm D3D original/proxy module paths differ from the manifest")
        campaign.require(identity["exports_forwarded"] == len(manifest["system_original"]["exports"]),
                         "Warm D3D forwarded export count differs")
        base = identity["system_module_base"]
        for name in ("d3dcompile_address", "d3dcompile2_address"):
            campaign.require(base <= identity[name] < base + manifest["system_original"]["image_size"],
                             "Warm D3D compiler pointer is outside the authentic System32 image")
        for event in events[1:]:
            campaign.require(event.get("event") == "forward_export_first_use",
                             "Warm D3D trace contains an incomplete call or capture failure")
            name = event["name"]
            campaign.require(not name.startswith("D3DCompile") and name != "D3DAssemble",
                             "Warm D3D trace observed an unwrapped compiler API")
        identities.append({"path": path.name, "sha256": runner.sha256(path),
                           "event_count": len(events), "identity": identity})
    return {"instrumentation_valid": None, "observed_compile_calls": 0,
            "proxy_identity_valid": True if identities else None, "trace_identities": identities,
            "scope": "Warm copied-cache process; no compiler interception, so no compiler-time attribution",
            "original_files": inventory(directory)}


class CpuSampler:
    """Bounded read-only samples of this runner's Godot descendants only.

    CPU values are sampled lower bounds, not exact process-exit accounting.
    Completed short-lived threads can be missed. Diagnostic debugger/helper
    CPU is deliberately excluded by executable identity.
    """

    def __init__(self, godot: str):
        import psutil
        self.psutil = psutil
        self.owner = psutil.Process()
        binary = Path(godot).resolve()
        self.executables = {os.path.normcase(str(binary))}
        if binary.name.endswith("_console.exe"):
            self.executables.add(os.path.normcase(str(binary.with_name(binary.name.replace("_console.exe", ".exe")))))
        self.samples = []
        self.errors = []
        self.maximum = {}
        self.stopped = threading.Event()
        self.started = time.perf_counter()
        self.thread = threading.Thread(target=self._sample, name="pace003-shader-cpu", daemon=True)

    def _sample(self) -> None:
        psutil = self.psutil
        while not self.stopped.is_set() and len(self.samples) < 1200:
            row = {"elapsed_seconds": time.perf_counter() - self.started, "processes": []}
            try:
                for child in self.owner.children(recursive=True):
                    try:
                        if os.path.normcase(child.exe()) not in self.executables:
                            continue
                        with child.oneshot():
                            cpu = child.cpu_times()
                            key = (child.pid, child.create_time())
                            total = cpu.user + cpu.system
                            self.maximum[key] = max(self.maximum.get(key, 0.0), total)
                            row["processes"].append({"pid": child.pid, "created_unix_seconds": key[1],
                                "status": child.status(), "user_seconds": cpu.user, "system_seconds": cpu.system,
                                "threads": [{"id": t.id, "user_seconds": t.user_time, "system_seconds": t.system_time}
                                            for t in child.threads()]})
                    except (psutil.NoSuchProcess, psutil.ZombieProcess):
                        pass
                    except psutil.AccessDenied as error:
                        if len(self.errors) < 32:
                            self.errors.append(str(error))
            except psutil.Error as error:
                if len(self.errors) < 32:
                    self.errors.append(str(error))
            self.samples.append(row)
            self.stopped.wait(0.25)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *_):
        self.stopped.set()
        self.thread.join(timeout=5)
        campaign.require(not self.thread.is_alive(), "CPU sampler did not stop")

    def result(self) -> dict:
        return {"scope": "sampled Godot process-tree CPU lower bound; helper CPU excluded; exited threads may be missed",
                "sampling_interval_seconds": 0.25, "max_samples": 1200,
                "samples_truncated": len(self.samples) >= 1200,
                "cpu_seconds_lower_bound": sum(self.maximum.values()),
                "observed_process_count": len(self.maximum), "errors": self.errors, "samples": self.samples}


def verify_atlas(folder: Path, shader_hash: str, source_sha: str) -> dict:
    comparator = importlib.import_module("compare_pace003_palette_atlas")
    value = comparator.load(folder)
    campaign.require(value["shader_sha256"] == shader_hash, "Atlas shader identity differs")
    campaign.require(value["source_revision"] == source_sha, "Atlas source identity differs")
    campaign.require(value["godot"].get("hash", "").startswith("5b4e0cb0f"), "Atlas Godot identity differs")
    campaign.require(value["platform"] == ("Windows" if sys.platform == "win32" else "Linux"),
                     "Atlas target platform differs")
    return {"report_sha256": runner.sha256(folder / "atlas.json"),
            "shader_sha256": shader_hash, "frames": len(value["frames"]),
            "first_submission_usec": value["frame_submissions_usec"][0],
            "first_capture_usec": value["frames"][0]["captured_usec"],
            "first_render_wall_usec": value["frames"][0]["captured_usec"] - value["frames"][0]["started_usec"],
            "video_adapter": value["video_adapter"], "display_server": value["display_server"]}


def run_variant(name: str, shader: bytes, args, report: dict, transcript, warm_from: str | None = None) -> dict:
    folder = args.output / name
    folder.mkdir(exist_ok=False)
    shader_file = folder / "material_palette.gdshader"
    shader_file.write_bytes(shader)
    atlas = folder / "atlas"
    atlas.mkdir()
    caches = folder / "isolated-caches"
    caches.mkdir()
    project_cache = ROOT / "godot/.godot/shader_cache"
    before = inventory(project_cache)
    if project_cache.exists():
        shutil.move(str(project_cache), str(folder / "prior-project-shader-cache"))
    # Only this job's generated project cache is relocated. No global/user cache
    # is deleted, and both tested shader variants begin with that path absent.
    child_env = untraced_environment()
    cache_variables = {"XDG_CACHE_HOME": "xdg-cache", "XDG_CONFIG_HOME": "xdg-config",
                       "XDG_DATA_HOME": "xdg-data", "MESA_SHADER_CACHE_DIR": "mesa"}
    if sys.platform == "win32":
        cache_variables = {"APPDATA": "roaming", "LOCALAPPDATA": "local"}
    for key, relative in cache_variables.items():
        path = caches / relative
        path.mkdir()
        child_env[key] = str(path)
    warm_source = None
    warm_project_source = None
    if warm_from is not None:
        campaign.require(any(row.get("name") == warm_from and row.get("status") == "diagnostic_completed"
                             for row in report["rows"]), "Warm comparison requires a completed retained cold candidate")
        source_caches = args.output / warm_from / "isolated-caches"
        source_project = args.output / warm_from / "result-project-shader-cache"
        warm_source, warm_project_source = copy_warm_cache_inputs(
            source_caches, source_project, caches, project_cache)
    child_env.update({"CYBERSAND_SOURCE_REVISION": report["source_sha"],
                      "CYBERSAND_ATLAS_SHADER": str(shader_file), "CYBERSAND_ATLAS_OUTPUT": str(atlas)})
    trace_dir = None
    if report["gl_trace"]["enabled"]:
        trace_dir = folder / "gl-trace"
        trace_dir.mkdir()
        child_env["LD_AUDIT"] = report["gl_trace"]["retained_path"]
        child_env["CYBERSAND_GL_TRACE_DIR"] = str(trace_dir)
    d3d_dir = None
    if report.get("d3d_trace", {}).get("enabled"):
        d3d_dir = folder / "d3d-trace"
        d3d_dir.mkdir()
        child_env["PACE003_D3D_TRACE_DIR"] = str(d3d_dir)
    row = {"name": name, "scope": SCOPE, "status": "failed", "shader_sha256": digest(shader),
           "shader_bytes": len(shader), "baseline_source_commit": BASELINE_COMMIT if name == "baseline-cold" else None,
           "source_sha": report["source_sha"], "cache_state": {
               "fresh_process": True, "project_cache_before_relocation": before,
               "temperature": "warm-copy" if warm_from else "cold",
               "copied_from_row": warm_from, "warm_source_before": warm_source,
               "warm_project_source_before": warm_project_source,
               "project_cache_at_launch": inventory(project_cache),
               "explicit_cache_environment": {key: child_env[key] for key in cache_variables},
               "explicit_caches_at_launch": inventory(caches),
               "scope_limit": "Explicit project/user/Mesa caches isolated; unobservable driver/OS caches are not claimed empty"},
           "errors": []}
    row["experimental_definition"] = next((entry for entry in report.get("variant_definitions", [])
                                            if entry["name"] == name), None)
    row["gl_trace"] = {"enabled": trace_dir is not None,
                       "library_sha256": report["gl_trace"].get("library_sha256"),
                       "child_only": True, "scope": "NONQUALIFYING instrumented run"}
    row["d3d_trace"] = {"enabled": d3d_dir is not None, "child_only": True,
                        "scope": "NONQUALIFYING authentic compiler passthrough; never Main acceptance"}
    save(folder / "row.json", row)
    flags = ("--rendering-driver", args.rendering_driver,
             "--script", "res://tests/play_pace003_palette_atlas.gd")
    sampler = CpuSampler(args.godot)
    started = time.perf_counter()
    try:
        with sampler, contextlib.redirect_stdout(transcript):
            process, failed = runner.run_case(args.godot, runner.Case(name, flags, CASE_SECONDS, 0, True),
                                              folder, "NONQUALIFYING-shader-atlas", env=child_env)
        row["process"] = process
        row["log_sha256"] = runner.sha256(folder / process["log"])
        if failed:
            row["errors"].append("Original graphical process " + process["status"])
        else:
            row["atlas"] = verify_atlas(atlas, row["shader_sha256"], report["source_sha"])
            row["status"] = "diagnostic_completed"
    except Exception as error:
        row["errors"].append(type(error).__name__ + ": " + str(error))
    finally:
        row["observed_wall_seconds_including_diagnostics"] = time.perf_counter() - started
        cpu = sampler.result()
        save(folder / "cpu-samples.json", cpu)
        row["cpu"] = {key: value for key, value in cpu.items() if key != "samples"}
        row["cpu"]["original_samples_sha256"] = runner.sha256(folder / "cpu-samples.json")
        if cpu["observed_process_count"] == 0 or cpu["samples_truncated"]:
            row["status"] = "failed"
            row["errors"].append("Godot CPU observation missing or exceeded its sample capacity")
        try:
            row["cache_state"]["project_cache_after"] = inventory(project_cache)
            row["cache_state"]["explicit_caches_after"] = inventory(caches)
            if project_cache.exists():
                shutil.move(str(project_cache), str(folder / "result-project-shader-cache"))
        except Exception as error:
            # Cache custody failure must not discard the actual original
            # process result or prevent the second variant from being attempted.
            row["status"] = "failed"
            row["errors"].append("Cache readback: " + type(error).__name__ + ": " + str(error))
        if trace_dir is not None:
            try:
                row["gl_trace"]["readback"] = trace_readback(trace_dir)
                campaign.require(runner.sha256(Path(report["gl_trace"]["retained_path"]))
                                 == report["gl_trace"]["library_sha256"], "GL trace library changed during execution")
            except Exception as error:
                row["status"] = "failed"
                row["errors"].append("GL trace readback: " + type(error).__name__ + ": " + str(error))
        if d3d_dir is not None:
            try:
                manifest = report["d3d_trace"]["manifest"]
                value = read_d3d_trace(d3d_dir, manifest, warm_from is not None)
                save(folder / "d3d-readback.json", value)
                row["d3d_trace"]["readback_sha256"] = runner.sha256(folder / "d3d-readback.json")
                row["d3d_trace"]["instrumentation_valid"] = value["instrumentation_valid"]
                campaign.require(runner.sha256(Path(report["d3d_trace"]["installed_proxy"]))
                                 == manifest["proxy"]["sha256"], "Installed D3D proxy changed during execution")
                campaign.require(runner.sha256(Path(manifest["system_original"]["path"]))
                                 == manifest["system_original"]["sha256"], "Original D3D compiler changed during execution")
            except Exception as error:
                row["status"] = "failed"
                row["errors"].append("D3D trace readback: " + type(error).__name__ + ": " + str(error))
        if warm_from is not None:
            try:
                verify_warm_cache_sources(args.output / warm_from / "isolated-caches",
                                          args.output / warm_from / "result-project-shader-cache",
                                          warm_source, warm_project_source)
                row["cache_state"]["original_cold_caches_unchanged"] = True
                row["cache_state"]["original_cold_project_shader_cache_unchanged"] = True
            except Exception as error:
                row["status"] = "failed"
                row["errors"].append("Warm source custody: " + str(error))
        save(folder / "row.json", row)
    return row


def execute_variants(variants, execute, report: dict, report_path: Path) -> None:
    """A failed original is retained and cannot prevent the candidate attempt."""
    for name, shader in variants:
        try:
            row = execute(name, shader)
        except Exception as error:
            row = {"name": name, "status": "failed", "scope": SCOPE,
                   "errors": [type(error).__name__ + ": " + str(error)]}
        report["rows"].append(row)
        save(report_path, report)


def self_test() -> int:
    import tempfile
    import unittest
    from unittest.mock import patch

    class Controls(unittest.TestCase):
        def test_original_failure_cannot_mask_or_skip_candidate(self):
            calls = []
            def execute(name, _):
                calls.append(name)
                if name == "baseline-cold":
                    raise RuntimeError("original timeout")
                return {"name": name, "status": "diagnostic_completed"}
            with tempfile.TemporaryDirectory() as folder:
                report = {"rows": [], "qualification_passed": False}
                execute_variants([("baseline-cold", b"a"), ("candidate-cold", b"b")], execute,
                                 report, Path(folder) / "diagnostic.json")
                self.assertEqual(calls, ["baseline-cold", "candidate-cold"])
                self.assertEqual(report["rows"][0]["status"], "failed")
                self.assertEqual(report["rows"][1]["status"], "diagnostic_completed")
                self.assertFalse(report["qualification_passed"])

        def test_bucket_variants_keep_all_original_branches_and_bounds(self):
            import pace003_shader_variants as variants
            original = campaign.windows.git(ROOT, "show", "HEAD:" + SHADER_PATH)
            definitions = variants.bucket_variants(original)
            self.assertEqual(len(definitions), 5)
            self.assertEqual(definitions[0]["shader"], original)
            self.assertFalse(definitions[0]["full_visual_candidate"])
            for row in definitions[1:]:
                self.assertFalse(row["qualification_passed"])
                self.assertTrue(row["full_visual_candidate"])
                self.assertNotIn(b"palette_passes", row["shader"])
                self.assertNotIn(b"switch (", row["shader"])
                for checked in row["source_checks"]:
                    values = [value for branch in checked["branches"] for value in branch["values"]]
                    expected = (set(range(1, 51)) - {46} if checked["selector"] == "flair" else set(range(81, 132)))
                    self.assertEqual(set(values), expected)
                    self.assertEqual(len(values), len(set(values)))
                    for branch in checked["branches"]:
                        self.assertEqual({value // 16 for value in branch["values"]}, {branch["group"]})
            with self.assertRaisesRegex(RuntimeError, "exact retained hoist"):
                variants.bucket_variants(b"different")

        def test_frozen_source_mismatch_refused(self):
            with patch.object(campaign.windows, "git", return_value=b"wrong baseline"):
                with self.assertRaisesRegex(RuntimeError, "baseline shader hash"):
                    shader_inputs()

        def test_atlas_cannot_substitute_shader_or_source(self):
            record = {"shader_sha256": "other", "source_revision": "another"}
            with patch.object(importlib, "import_module") as module:
                module.return_value.load.return_value = record
                with self.assertRaisesRegex(RuntimeError, "shader identity"):
                    verify_atlas(Path("unused"), "expected", "source")
                record["shader_sha256"] = "expected"
                with self.assertRaisesRegex(RuntimeError, "source identity"):
                    verify_atlas(Path("unused"), "expected", "source")

        def test_cache_symlink_refused(self):
            with tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "cache"
                with patch.object(Path, "is_symlink", return_value=True):
                    with self.assertRaisesRegex(RuntimeError, "symlink"):
                        inventory(path)

        def test_windows_crlf_preserves_raw_and_canonical_identities(self):
            raw, committed = b"shader_type canvas_item;\r\n", b"shader_type canvas_item;\n"
            canonical, identity = canonical_text_identity(raw, committed, "shader")
            self.assertEqual(canonical, committed)
            self.assertNotEqual(identity["checkout_raw_sha256"], identity["canonical_lf_sha256"])
            self.assertEqual(identity["canonical_lf_sha256"], identity["committed_blob_sha256"])
            self.assertTrue(identity["crlf_normalized"])
            with self.assertRaisesRegex(RuntimeError, "differs from committed"):
                canonical_text_identity(b"different\r\n", committed, "shader")

        def test_audit_is_child_only_and_windows_refused(self):
            with patch.dict(os.environ, {"LD_AUDIT": "outer.so", "CYBERSAND_GL_TRACE_DIR": "outer"}):
                child = untraced_environment()
                self.assertNotIn("LD_AUDIT", child)
                self.assertNotIn("CYBERSAND_GL_TRACE_DIR", child)
                self.assertEqual(os.environ["LD_AUDIT"], "outer.so")
            with patch.object(sys, "platform", "win32"):
                with self.assertRaisesRegex(RuntimeError, "Linux only"):
                    retain_trace_library(Path("unused"), Path("unused"), {})

        def test_absent_trace_cannot_report_instrumented_success(self):
            with tempfile.TemporaryDirectory() as folder:
                with self.assertRaisesRegex(RuntimeError, "no original event log"):
                    trace_readback(Path(folder))

        def test_windows_variants_are_frozen_and_nonqualifying(self):
            import pace003_shader_variants as variants
            frozen = (ROOT / SHADER_PATH).read_bytes()
            rows = variants.variants(frozen)
            self.assertEqual(len(rows), 5)
            self.assertEqual(rows[0]["shader"], frozen)
            self.assertEqual(len({row["sha256"] for row in rows}), 5)
            self.assertTrue(all(row["qualification_passed"] is False for row in rows))
            self.assertEqual((ROOT / SHADER_PATH).read_bytes(), frozen)
            with self.assertRaisesRegex(RuntimeError, "exact retained hoist"):
                variants.variants(frozen + b"\n")

        def test_warm_user_and_project_cache_copies_are_verified(self):
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                user, project, copy_user, copy_project = [root / name for name in ("cold-user", "cold-project", "warm-user", "warm-project")]
                user.mkdir()
                project.mkdir()
                (user / "user.bin").write_bytes(b"original user cache")
                (project / "shader.bin").write_bytes(b"original project cache")
                original_user, original_project = copy_warm_cache_inputs(user, project, copy_user, copy_project)
                self.assertEqual(inventory(copy_project)["files"], original_project["files"])
                verify_warm_cache_sources(user, project, original_user, original_project)
                (project / "shader.bin").write_bytes(b"changed retained source")
                with self.assertRaisesRegex(RuntimeError, "Original cold project shader cache changed"):
                    verify_warm_cache_sources(user, project, original_user, original_project)

        def test_broken_project_cache_copy_is_refused(self):
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                user, project, copy_user, copy_project = [root / name for name in ("cold-user", "cold-project", "warm-user", "warm-project")]
                user.mkdir()
                project.mkdir()
                (project / "shader.bin").write_bytes(b"original project cache")
                original_copy = shutil.copytree
                def incomplete_copy(source, destination, **kwargs):
                    result = original_copy(source, destination, **kwargs)
                    if Path(destination) == copy_project:
                        (copy_project / "shader.bin").write_bytes(b"wrong copied bytes")
                    return result
                with patch.object(shutil, "copytree", side_effect=incomplete_copy):
                    with self.assertRaisesRegex(RuntimeError, "Warm project shader cache copy differs"):
                        copy_warm_cache_inputs(user, project, copy_user, copy_project)

        def test_absent_cold_project_cache_stays_explicitly_absent(self):
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                user, project, copy_user, copy_project = [root / name for name in ("cold-user", "cold-project", "warm-user", "warm-project")]
                user.mkdir()
                original_user, original_project = copy_warm_cache_inputs(user, project, copy_user, copy_project)
                self.assertFalse(original_project["exists"])
                self.assertFalse(copy_project.exists())
                verify_warm_cache_sources(user, project, original_user, original_project)

        def _warm_identity_fixture(self, directory: Path):
            manifest = {"system_original": {"path": "C:\\Windows\\System32\\d3dcompiler_47.dll",
                                           "sha256": "a" * 64, "image_size": 4096, "exports": [{}, {}, {}]},
                        "proxy": {"sha256": "b" * 64}}
            identity = {"event_index": 1, "event": "identity", "pid": 17, "tid": 18,
                        "system_sha256": "a" * 64, "expected_system_sha256": "a" * 64,
                        "proxy_sha256": "b" * 64, "system_module": manifest["system_original"]["path"],
                        "proxy_module": "D:\\diagnostic\\d3dcompiler_47.dll", "exports_forwarded": 3,
                        "system_module_base": 10000, "d3dcompile_address": 10001, "d3dcompile2_address": 10002}
            path = directory / "d3d-trace-17.jsonl"
            path.write_text(json.dumps(identity) + "\n")
            return manifest, identity, path

        def test_warm_no_compiler_call_has_no_compiler_attribution(self):
            with tempfile.TemporaryDirectory() as folder:
                directory = Path(folder)
                absent = read_d3d_trace(directory, {}, True)
                self.assertIsNone(absent["instrumentation_valid"])
                self.assertIsNone(absent["proxy_identity_valid"])
                self.assertEqual(absent["observed_compile_calls"], 0)
                with self.assertRaisesRegex(ValueError, "no original trace"):
                    read_d3d_trace(directory, {}, False)
                manifest, _, _ = self._warm_identity_fixture(directory)
                observed = read_d3d_trace(directory, manifest, True)
                self.assertIsNone(observed["instrumentation_valid"])
                self.assertTrue(observed["proxy_identity_valid"])
                self.assertEqual(observed["observed_compile_calls"], 0)

        def test_warm_no_begin_does_not_bypass_proxy_identity_checks(self):
            for field, replacement in (("proxy_sha256", "wrong"), ("system_sha256", "wrong"),
                                       ("d3dcompile_address", 9999), ("exports_forwarded", 0)):
                with self.subTest(field=field), tempfile.TemporaryDirectory() as folder:
                    directory = Path(folder)
                    manifest, identity, path = self._warm_identity_fixture(directory)
                    identity[field] = replacement
                    path.write_text(json.dumps(identity) + "\n")
                    with self.assertRaises(RuntimeError):
                        read_d3d_trace(directory, manifest, True)

        def test_warm_incomplete_event_cannot_masquerade_as_cache_hit(self):
            with tempfile.TemporaryDirectory() as folder:
                directory = Path(folder)
                manifest, identity, path = self._warm_identity_fixture(directory)
                bad = {"event_index": 2, "event": "compile_end", "pid": 17, "tid": 18, "call": 1}
                path.write_text(json.dumps(identity) + "\n" + json.dumps(bad) + "\n")
                with self.assertRaisesRegex(RuntimeError, "incomplete call or capture failure"):
                    read_d3d_trace(directory, manifest, True)
                path.write_text(json.dumps(identity))
                with self.assertRaisesRegex(RuntimeError, "Partial original D3D trace"):
                    read_d3d_trace(directory, manifest, True)

    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    return 0 if result.wasSuccessful() else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--expected-source-sha")
    parser.add_argument("--rendering-driver", choices=("opengl3", "opengl3_angle"))
    parser.add_argument("--gl-trace-library", type=Path,
                        help="Linux-only ELF audit helper, injected into graphical Godot children only")
    parser.add_argument("--experiment", choices=("original-pair", "windows-paths", "windows-buckets"), default="original-pair")
    parser.add_argument("--d3d-proxy-manifest", type=Path)
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not all((args.godot, args.output, args.expected_source_sha, args.rendering_driver)):
        parser.error("--godot, --output, --expected-source-sha and --rendering-driver are required")
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    args.godot = str(Path(args.godot).resolve())
    report_path = args.output / "diagnostic.json"
    report = {"schema": SCHEMA, "scope": SCOPE, "diagnostic_only": True, "qualification_passed": False,
              "status": "diagnostic_failed", "rows": [], "errors": [], "retries": 0,
              "cold_order": ["baseline-cold", "candidate-cold"], "warm_execution": "not requested",
              "baseline_commit": BASELINE_COMMIT, "baseline_shader_sha256": BASELINE_SHADER_SHA256,
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "command": [sys.executable, *sys.argv],
              "platform": platform.platform(), "cpu_count": os.cpu_count(), "python": sys.version,
              "environment": {key: os.environ.get(key) for key in (
                  "LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GALLIVM_PERF", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT",
                  "GITHUB_SHA", "GITHUB_WORKFLOW_SHA", "GITHUB_WORKFLOW_REF", "ImageOS", "ImageVersion")},
              "rendering_driver": args.rendering_driver,
              "experiment": args.experiment,
              "comparison_limit": "Isolated palette atlas only; no gameplay, native throughput, Main readiness or PACE pass follows"}
    before = None
    try:
        expected_driver = "opengl3_angle" if sys.platform == "win32" else "opengl3"
        campaign.require(sys.platform == "win32" or sys.platform.startswith("linux"), "Unsupported target OS")
        campaign.require(args.rendering_driver == expected_driver, "Original target renderer control differs")
        before = source_identity()
        campaign.require(before["source_sha"] == args.expected_source_sha
                         and before["source_mode"] == "clean-recorded-inputs", "Require clean exact diagnostic head")
        report.update(before)
        report["gl_trace"] = retain_trace_library(args.gl_trace_library, args.output, before)
        report["d3d_trace"] = retain_d3d_proxy(args.d3d_proxy_manifest, args.godot, args.output)
        report["runtimes"] = campaign.runtime_identity()
        for kind, identity in report["runtimes"].items():
            shutil.copyfile(ROOT / identity["manifest"], args.output / (kind + "-runtime-provenance.json"))
        report["godot_sha256"] = runner.sha256(Path(args.godot))
        version = subprocess.check_output([args.godot, "--version"], text=True, timeout=30,
                                          env=untraced_environment()).strip()
        campaign.require(version == campaign.GODOT_VERSION, "Pinned Godot version differs")
        report["godot_version"] = version
        baseline, candidate = shader_inputs()
        variants_to_run = [("baseline-cold", baseline), ("candidate-cold", candidate)]
        if args.experiment in ("windows-paths", "windows-buckets"):
            campaign.require(sys.platform == "win32", "Windows path experiments require the actual target OS")
            import pace003_shader_variants as variants
            definitions = (variants.variants(candidate) if args.experiment == "windows-paths"
                           else variants.bucket_variants(candidate))
            report["variant_definitions"] = [
                {key: value for key, value in row.items() if key != "shader"} for row in definitions]
            variants_to_run = [(row["name"], row["shader"]) for row in definitions]
            report["cold_order"] = [row[0] for row in variants_to_run]
            report["comparison_limit"] = (
                "NONQUALIFYING bounded compiler experiments and unqualified control-flow candidates; "
                "any visual exclusion cannot qualify and no cross-variant visual parity is claimed")
        report["candidate_shader_sha256"] = digest(candidate)
        _, report["candidate_shader_text_identity"] = canonical_text_identity((ROOT / SHADER_PATH).read_bytes(),
            campaign.windows.git(ROOT, "show", "HEAD:" + SHADER_PATH), SHADER_PATH)
        child_env = untraced_environment()
        child_env["CYBERSAND_SOURCE_REVISION"] = report["source_sha"]
        save(report_path, report)
        with (args.output / "runner-transcript.txt").open("w", encoding="utf-8") as transcript:
            with contextlib.redirect_stdout(transcript):
                imported, failed = runner.run_case(args.godot,
                    runner.Case("import", ("--editor", "--import", "--quit"), 240, 0), args.output,
                    "NONQUALIFYING-headless-import", env=child_env)
            report["import"] = imported
            report["import_log_sha256"] = runner.sha256(args.output / imported["log"])
            campaign.require(not failed, "Fresh headless import failed")
            execute_variants(variants_to_run,
                lambda name, shader: run_variant(name, shader, args, report, transcript), report, report_path)
            if args.experiment in ("windows-paths", "windows-buckets"):
                eligible_names = {item["name"] for item in definitions if item.get("full_visual_candidate") is True}
                eligible = [row for row in report["rows"] if row["status"] == "diagnostic_completed"
                            and row["name"] in eligible_names]
                if eligible:
                    selected = min(eligible, key=lambda row: row["atlas"]["first_capture_usec"])
                    cold_name = selected["name"]
                    warm_name = cold_name.removesuffix("-cold") + "-warm"
                    shader = next(value for name, value in variants_to_run if name == cold_name)
                    report["warm_execution"] = {"selected_cold_row": cold_name,
                        "selection": "Smallest first-capture time among completed control-flow candidates",
                        "scope": "One subsequent fresh process with copied retained caches; never cold acceptance"}
                    execute_variants([(warm_name, shader)],
                        lambda name, data: run_variant(name, data, args, report, transcript, warm_from=cold_name),
                        report, report_path)
                else:
                    report["warm_execution"] = "Unavailable: no full-visual candidate completed within180s"
        completed = all(row["status"] == "diagnostic_completed" for row in report["rows"])
        if args.experiment in ("windows-paths", "windows-buckets"):
            report["comparison"] = {"status": "not-applicable",
                "reason": "Explicitly nonqualifying experiments; all candidates need separate preservation proof"}
            if not completed:
                report["errors"].append("At least one original diagnostic process failed; all first attempts retained")
        elif completed:
            comparison_log = args.output / "comparison.log"
            command = [sys.executable, str(ROOT / COMPARATOR_PATH),
                       str(args.output / "baseline-cold/atlas"), str(args.output / "candidate-cold/atlas"),
                       "--output", str(args.output / "comparison.json")]
            with comparison_log.open("w", encoding="utf-8") as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=90,
                                        check=False, env=untraced_environment())
            report["comparison"] = {"command": command, "returncode": result.returncode,
                                    "log_sha256": runner.sha256(comparison_log)}
            campaign.require(result.returncode == 0, "Original atlas visual comparison failed")
            comparison = campaign.load_json((args.output / "comparison.json").read_text(encoding="utf-8"))
            campaign.require(comparison.get("passed") is True, "Visual comparator did not report a pass")
            report["comparison"]["report_sha256"] = runner.sha256(args.output / "comparison.json")
        else:
            report["comparison"] = {"status": "unavailable", "reason": "At least one original atlas process failed; no parity claim"}
            report["errors"].append("Original baseline/candidate diagnostic is incomplete; all attempted rows retained")
        campaign.require(source_identity() == before, "Source inputs changed during diagnostic execution")
        campaign.require(campaign.runtime_identity() == report["runtimes"], "Runtime identities changed")
        if completed:
            report["status"] = "diagnostic_completed"
    except Exception as error:
        report["errors"].append(type(error).__name__ + ": " + str(error))
    finally:
        if before is not None:
            try:
                report["source_unchanged_after_execution"] = source_identity() == before
            except Exception as error:
                report["source_unchanged_after_execution"] = False
                report["errors"].append("Source readback: " + str(error))
        report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        if report["errors"] or report.get("source_unchanged_after_execution") is not True:
            report["status"] = "diagnostic_failed"
        save(report_path, report)
    print("PLAY_PACE003_SHADER_DIAGNOSTIC " + json.dumps({"scope": SCOPE, "status": report["status"],
          "qualification_passed": False, "rows": len(report["rows"]), "errors": report["errors"],
          "report_sha256": runner.sha256(report_path)}))
    # A known original timeout remains red. It is never converted into a green
    # qualification or concealed by a successful candidate.
    return 0 if report["status"] == "diagnostic_completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
