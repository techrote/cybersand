#!/usr/bin/env python3
"""Source-bound Materials Lab desktop qualification and four-path publication.

The established publisher owns build, manifest and branch-lease admission.
This profile adds the real catalogue suite and graphical authoring evidence;
neither an old runtime nor a parser-only receipt can satisfy publication.
"""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

import execution_policy

_spec = spec_from_file_location(
    "_materials_lab_private_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_former_workflow, _former_request = engine.WORKFLOW, engine.REQUEST
engine.BRANCH = "codex/materials-lab-v1-20261111"
engine.WORKFLOW = ".github/workflows/materials-lab-runtime-publication.yml"
engine.REQUEST = "tools/ci/materials_lab_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-11-materials-lab-completion.md"
engine.PRESSURE_CASE = "godot/tests/test_material_lab_catalogue.gd"
engine.BUNDLE_PREFIX = "materials-lab-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "materials-lab-runtime-publish-request-v1",
    "family": "materials-lab-v1",
    "variant": "native-inspection-isolated-authoring",
    "scope": "source-matched-linux-windows-native-and-graphical-lab",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_material_lab_catalogue": r"(?m)^MATERIAL_LAB_CATALOGUE: [1-9][0-9]* assertions, 0 failures; actual compiled native descriptor and resolver readback\s*$",
    "test_material_lab_experiment": r"(?m)^MATERIAL_LAB_EXPERIMENT: [1-9][0-9]* assertions; 0 failures\s*$",
    "test_material_lab_diagnostics": r"(?m)^MATERIAL_LAB_DIAGNOSTICS: [1-9][0-9]* assertions; 0 failures\s*$",
    "test_material_lab_service": r"(?m)^Materials Lab process lifecycle: [1-9][0-9]* checks, 0 failures\s*$",
    "test_material_lab_ui": r"(?m)^MATERIAL_LAB_UI: [1-9][0-9]* assertions; 0 failures; artifacts=.+$",
    "test_material_lab_world": r"(?m)^Materials Lab World UI: [1-9][0-9]* checks, 0 failures\s*$",
    "test_workbench_canvas": r"(?m)^WORKBENCH_CANVAS [1-9][0-9]* checks, 0 failures\s*$",
}
engine.CASE_TIMEOUTS = {}
engine.EXECUTION_SCOPE = (
    "actual target-OS import, compiled material catalogue/resolver, native Materials Lab "
    "experiments, process lifecycle, mounted authoring/effects/preset/World-recipe UI, "
    "source-matched candidate/reference World and shared Workbench controls. The Lab "
    "profile additionally requires complete catalogue-suite and graphical UI receipts. "
    "Full ordinary Native/Godot coverage and human acceptance remain separate"
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_former_workflow, _former_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/materials_lab_runtime_publication.py",
    "tools/ci/test_materials_lab_runtime_publication.py",
    "tools/package_materials_lab_candidate.py", "tools/ci/test_materials_lab_package.py",
    "tools/ci/execution_policy.py", "tools/ci/execution_telemetry.py",
    "tools/ci/godot_scheduling.py", "tools/ci/godot_scheduling_profile.json",
    "tools/ci/prepare_linux_display.sh", "godot/tests/support/ci_execution_policy.json",
    "docs/operations/materials-lab-authoring.md",
}
# These Python/generated inputs are part of actual desktop authoring, not only
# build metadata. Retain the complete tracked inventory, including new files.
engine.BUILD_EXACT.update(subprocess.check_output(
    ["git", "-C", str(engine.ROOT), "ls-files", "-z", "tools/material_catalogue", "materials/catalogue"],
    timeout=30,
).decode().split("\0"))
engine.BUILD_EXACT.discard("")

GRAPHICAL_CASES = {
    "test_material_lab_ui": ("effects-ui-capture-manifest.json", "08-kept-salt-world.png", "effects-ui-world-receipt.json"),
    "test_material_lab_world": ("world-capture-manifest.json", "07-candidate-world-density.png", "world-ui-receipt.json"),
}
# Bound capture redraw work on software-rendered CI while native authoring
# children execute. This only changes these graphical runner invocations.
GRAPHICAL_MAX_FPS = 15
WORLD_CHECKS = {"deterministic_repeat", "persistence_checkpoint", "persistence_replay",
                "quantity_balanced", "worker_1_4_equal"}
WINDOWS_SKIPS = {
    "test_lab.LabTests.test_cli_response_symlink_alias_preserves_preset": "POSIX symlink protocol alias fixture",
    "test_lab.LabTests.test_timeout_and_cancel_kill_real_child_descendants": "Real POSIX process-tree cleanup; Windows taskkill requires Windows qualification",
    "test_lab.LabTests.test_explicit_compiler_path_with_spaces_executes_native_candidate": "The actual spaced-path compiler symlink fixture uses POSIX symlinks; Windows compiler commands require a Windows qualification host",
}
PROCESS_OWNER_CASES = {
    "test_process_owner.ProcessOwnerTests." + name for name in (
        "test_timeout_retires_driver_child_and_grandchild",
        "test_cancellation_retires_driver_child_and_grandchild",
        "test_exited_driver_with_inherited_pipes_is_refused_and_retired",
        "test_success_retires_redirected_descendants_after_driver_exit",
    )
}

SUITE_SCRIPT = r'''
import json, pathlib, sys, unittest
root = pathlib.Path.cwd()
sys.path.insert(0, str(root / "tools/material_catalogue"))
suite = unittest.defaultTestLoader.discover(str(root / "tools/material_catalogue"), "test_*.py")
def ids(item):
    if isinstance(item, unittest.TestSuite):
        return [name for child in item for name in ids(child)]
    return [item.id()]
inventory = ids(suite)
result = unittest.TextTestRunner(verbosity=2).run(suite)
record = {"inventory": inventory, "tests_run": result.testsRun,
          "failures": [test.id() for test, _ in result.failures],
          "errors": [test.id() for test, _ in result.errors],
          "skipped": {test.id(): reason for test, reason in result.skipped},
          "expected_failures": [test.id() for test, _ in result.expectedFailures],
          "unexpected_successes": [test.id() for test in result.unexpectedSuccesses]}
pathlib.Path(sys.argv[1]).write_text(json.dumps(record, sort_keys=True) + "\n", encoding="utf-8")
sys.exit(0 if result.wasSuccessful() else 1)
'''


def require_platform(platform: str) -> None:
    engine.require((platform == "windows" and sys.platform == "win32") or
                   (platform == "linux" and sys.platform.startswith("linux")),
                   "Actual target-OS execution is required")


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    engine.require(isinstance(value, dict), "Expected JSON object: " + str(path))
    return value


def verify_context(record: dict, source: str) -> None:
    expected = engine.context(source)
    current_attempt = int(expected.pop("workflow_attempt"))
    for key, value in expected.items():
        engine.require(record.get(key) == value, "Qualification context differs: " + key)
    attempt = record.get("workflow_attempt", "")
    engine.require(isinstance(attempt, str) and attempt.isdecimal() and
                   0 < int(attempt) <= current_attempt, "Invalid qualification attempt")


def verify_suite_record(record: dict, platform: str) -> None:
    inventory = record.get("inventory", [])
    engine.require(isinstance(inventory, list) and len(inventory) >= 206 and
                   all(isinstance(name, str) for name in inventory) and
                   len(set(inventory)) == len(inventory) and
                   record.get("tests_run") == len(inventory),
                   "Catalogue suite did not complete its entire unique discovered inventory")
    engine.require(PROCESS_OWNER_CASES.issubset(inventory), "Actual descendant lifetime cases are missing")
    for key in ("failures", "errors", "expected_failures", "unexpected_successes"):
        engine.require(record.get(key) == [], "Nonpassing catalogue suite: " + key)
    allowed = WINDOWS_SKIPS if platform == "windows" else {}
    engine.require(record.get("skipped") == allowed, "Unregistered or missing platform-specific catalogue skips")
    engine.require(set(allowed).issubset(inventory), "Skipped test is absent from the discovered suite")


def windows_descendant_controls(lab) -> dict:
    """Actual timeout/cancellation controls against an observed live child handle."""
    if sys.platform != "win32":
        return {"status": "not_applicable", "platform": sys.platform, "cases": []}
    import ctypes
    from ctypes import wintypes
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.WaitForSingleObject.restype = wintypes.DWORD
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel.TerminateProcess.restype = wintypes.BOOL
    rows = []
    with tempfile.TemporaryDirectory(prefix="cybersand-windows-descendants-") as temporary:
        directory = Path(temporary)
        for mode in ("timeout", "cancel"):
            pid_file, token = directory / (mode + ".pid"), directory / (mode + ".cancel")
            child = "import time; time.sleep(60)"
            parent = ("import pathlib,subprocess,sys,time; "
                      "child=subprocess.Popen([sys.executable,'-c'," + repr(child) + "]); "
                      "pathlib.Path(" + repr(str(pid_file)) + ").write_text(str(child.pid)); time.sleep(60)")
            observed = {}
            stop = threading.Event()
            def observe():
                deadline = time.monotonic() + 10
                while not stop.is_set() and time.monotonic() < deadline:
                    if pid_file.exists():
                        try:
                            pid = int(pid_file.read_text())
                        except ValueError:
                            time.sleep(0.01)
                            continue
                        handle = kernel.OpenProcess(0x00100001, False, pid)
                        observed.update(pid=pid, handle=handle, live=bool(handle) and kernel.WaitForSingleObject(handle, 0) == 258)
                        if mode == "cancel": token.write_text("cancel")
                        return
                    time.sleep(0.01)
            watcher = threading.Thread(target=observe)
            watcher.start()
            refused = False
            try:
                with lab._cancellation_scope(token):
                    try:
                        lab._run([sys.executable, "-c", parent], directory, 5 if mode == "timeout" else 15)
                    except lab.LabError:
                        refused = True
                stop.set()
                watcher.join(timeout=10)
                engine.require(not watcher.is_alive() and observed.get("live") is True,
                               "Windows cleanup control did not establish a live descendant")
                joined = kernel.WaitForSingleObject(observed["handle"], 5000) == 0
                engine.require(refused and joined, "Windows " + mode + " left its observed descendant running")
                rows.append({"mode": mode, "observed_child_pid": observed["pid"],
                             "observed_live": True, "refused": True, "child_exited": True})
            finally:
                stop.set()
                watcher.join(timeout=10)
                if observed.get("handle"):
                    if kernel.WaitForSingleObject(observed["handle"], 0) == 258:
                        kernel.TerminateProcess(observed["handle"], 1)
                        kernel.WaitForSingleObject(observed["handle"], 5000)
                    kernel.CloseHandle(observed["handle"])
    return {"status": "passed", "platform": "win32", "cases": rows}


def catalogue_tests(args: argparse.Namespace) -> None:
    require_platform(args.platform)
    identity = engine.context(args.source_sha) | engine.input_ledgers(args.source_sha)
    args.bundle.mkdir(parents=True, exist_ok=True)
    output = args.bundle / "catalogue-suite.json"
    engine.require(not output.exists(), "Do not overwrite an earlier catalogue-suite attempt")
    report = identity | {"schema": "materials-lab-catalogue-suite-v1", "platform": args.platform,
                         "completed": False, "status": "running"}
    engine.write_json(output, report)
    sys.path.insert(0, str(engine.ROOT / "tools/material_catalogue"))
    import lab
    compiler, msvc = lab._toolchain()
    engine.require(not msvc, "This publication profile requires its explicit GNU-compatible candidate compiler")
    version = lab._run([compiler, "--version"], engine.ROOT, 30)
    report["candidate_compiler"] = {"path": compiler, "version": version.stdout.strip(),
                                      "sha256": engine.runner.sha256(Path(compiler))}
    report["python"] = {"version": sys.version, "executable": sys.executable,
                        "sha256": engine.runner.sha256(Path(sys.executable))}
    report["descendant_cleanup"] = windows_descendant_controls(lab)
    raw = args.bundle / "catalogue-suite-result.json"
    command = [sys.executable, "-c", SUITE_SCRIPT, str(raw.resolve())]
    report["timeout_seconds"] = execution_policy.watchdog_seconds("native_suite_seconds")
    engine.write_json(output, report)
    process = lab._run(command, engine.ROOT, report["timeout_seconds"], check=False)
    log = args.bundle / "catalogue-suite.log"
    log.write_bytes((process.stdout + "\n" + process.stderr).encode("utf-8"))
    report.update(returncode=process.returncode, log_sha256=engine.runner.sha256(log))
    if raw.is_file():
        report["result"] = read_json(raw)
    report["status"] = "failed"
    engine.write_json(output, report)
    print(log.read_text(encoding="utf-8"), end="", flush=True)
    engine.require(process.returncode == 0, "Actual catalogue suite failed; original output is retained")
    verify_suite_record(report["result"], args.platform)
    engine.require(engine.input_ledgers(args.source_sha) == {key: identity[key] for key in ("source_inputs", "build_inputs")},
                   "Catalogue sources changed during execution")
    report.update(completed=True, status="passed")
    engine.write_json(output, report)


def verify_catalogue_bundle(directory: Path, platform: str, source: str) -> dict:
    report = read_json(directory / "catalogue-suite.json")
    verify_context(report, source)
    expected = engine.input_ledgers(source)
    for key, value in expected.items():
        engine.require(report.get(key) == value, "Catalogue suite custody mismatch: " + key)
    engine.require(report.get("schema") == "materials-lab-catalogue-suite-v1" and
                   report.get("platform") == platform and report.get("completed") is True and
                   report.get("status") == "passed" and report.get("returncode") == 0,
                   "Missing complete target-OS catalogue suite")
    engine.require(report.get("log_sha256") == engine.runner.sha256(directory / "catalogue-suite.log"),
                   "Catalogue suite output changed")
    engine.require(report.get("result") == read_json(directory / "catalogue-suite-result.json"),
                   "Catalogue suite result changed")
    verify_suite_record(report["result"], platform)
    if platform == "windows":
        cleanup = report.get("descendant_cleanup", {})
        engine.require(cleanup.get("status") == "passed" and cleanup.get("platform") == "win32" and
                       [row.get("mode") for row in cleanup.get("cases", [])] == ["timeout", "cancel"] and
                       all(row.get("observed_live") is True and row.get("refused") is True and
                           row.get("child_exited") is True for row in cleanup["cases"]),
                       "Actual Windows descendant cleanup was not qualified")
    return report


def current_world_source() -> dict:
    sys.path.insert(0, str(engine.ROOT / "tools/material_catalogue"))
    import world_candidate
    return world_candidate._source_snapshot()[0]


def verify_capture(directory: Path, platform: str, native_sha256: str) -> dict:
    """Bind original graphical files and actual native receipts, not pixels alone."""
    report = read_json(directory / "graphical.json")
    engine.require(report.get("platform") == platform and report.get("status") == "passed" and
                   report.get("completed") is True and report.get("native_sha256") == native_sha256,
                   "Graphical Lab execution did not complete against the qualified runtime")
    engine.require([row.get("name") for row in report.get("results", [])] == list(GRAPHICAL_CASES),
                   "Incomplete graphical Lab case coverage")
    current = current_world_source()
    for row in report["results"]:
        name = row["name"]
        engine.require(row.get("status") == "passed" and row.get("returncode") == 0 and
                       row.get("natural_completion") is True and row.get("requires_display") is True and
                       row.get("skip_messages") == [] and not row.get("diagnostic_error") and
                       row.get("launch_error") is None, "Invalid graphical process: " + name)
        command = row.get("command", [])
        driver = "opengl3_angle" if platform == "windows" else "opengl3"
        driver_index = command.index("--rendering-driver") if "--rendering-driver" in command else -1
        fps_index = command.index("--max-fps") if "--max-fps" in command else -1
        user_args = command.index("--") if "--" in command else len(command)
        engine.require("--headless" not in command and driver_index >= 0 and driver_index + 1 < len(command) and
                       command[driver_index + 1] == driver,
                       "Graphical command does not select the required actual backend")
        engine.require(command.count("--max-fps") == 1 and 0 <= fps_index < user_args - 1 and
                       command[fps_index + 1] == str(GRAPHICAL_MAX_FPS) and
                       not any(argument.startswith("--max-fps=") for argument in command),
                       "Graphical command does not retain the bounded capture frame rate")
        log = directory / "graphical" / (name + ".log")
        engine.require(row.get("log_sha256") == engine.runner.sha256(log) and
                       len(re.findall(engine.CASE_MARKERS[name], log.read_text(encoding="utf-8"))) == 1,
                       "Graphical process output changed or omitted its assertions")
        capture = directory / "graphical" / name
        manifest_name, image_name, receipt_name = GRAPHICAL_CASES[name]
        manifest = read_json(capture / manifest_name)
        engine.require(manifest.get("platform") == platform.title() and
                       manifest.get("display") not in (None, "", "headless") and
                       manifest.get("failures") == 0 and manifest.get("runtime_active") is False,
                       "Capture does not establish actual target-OS graphical execution")
        if name == "test_material_lab_ui":
            engine.require(manifest.get("native_library_sha256") == native_sha256,
                           "Capture used a different native runtime")
        image = capture / image_name
        engine.require(image.read_bytes().startswith(b"\x89PNG\r\n\x1a\n") and
                       manifest.get("image_sha256") == engine.runner.sha256(image), "Capture PNG changed")
        receipt = read_json(capture / receipt_name)
        engine.require(receipt.get("schema_id") == "cybersand.material-lab.world-receipt" and
                       receipt.get("runtime_active") is False and
                       all(receipt.get("checks", {}).get(key) is True for key in
                           ("source_unchanged", "candidate_qualification", "reference_qualification")) and
                       receipt.get("candidate", {}).get("world_simulation") is True and
                       receipt.get("source_identity") == manifest.get("native_source_identity"),
                       "Graphical image lacks matching actual candidate World evidence")
        engine.require(receipt["source_identity"].get("digest") == current["digest"] and
                       receipt["source_identity"].get("lf_sha256") == current["lf_sha256"],
                       "Graphical native World receipt belongs to different source")
        if name == "test_material_lab_ui":
            engine.require(receipt.get("candidate_digest") == manifest.get("candidate_digest"), "Capture candidate digest differs")
        for side in ("candidate", "reference"):
            checks = receipt.get(side, {}).get("checks", {})
            engine.require(WORLD_CHECKS.issubset(checks) and all(value is True for value in checks.values()),
                           "Native graphical receipt failed or omitted qualification: " + side)
        source_map = manifest.get("source_sha256", {})
        expected_scripts = {"scripts/material_lab_" + leaf + ".gd" for leaf in
                            ("screen", "panel", "world_panel", "service", "catalogue", "experiment")}
        expected_scripts.add("tests/" + name + ".gd")
        engine.require(isinstance(source_map, dict) and expected_scripts.issubset(source_map),
                       "Graphical capture omitted its actual UI source inputs")
        for path, digest in source_map.items():
            relative = Path(path)
            engine.require(not relative.is_absolute() and ".." not in relative.parts and
                           engine.runner.sha256(engine.ROOT / "godot" / relative) == digest,
                           "Graphical source changed: " + path)
    actual_files = {path.relative_to(directory).as_posix() for path in (directory / "graphical").rglob("*") if path.is_file()}
    engine.require(actual_files and set(report.get("files_sha256", {})) == actual_files, "Incomplete graphical artifact inventory")
    for relative, digest in report.get("files_sha256", {}).items():
        path = Path(relative)
        engine.require(not path.is_absolute() and ".." not in path.parts and
                       engine.runner.sha256(directory / path) == digest, "Graphical artifact changed: " + relative)
    return report


def graphical_case(name: str, capture: Path, platform: str):
    driver = "opengl3_angle" if platform == "windows" else "opengl3"
    return engine.runner.Case(name, ("--max-fps", str(GRAPHICAL_MAX_FPS), "--rendering-driver", driver,
        "--script", "res://tests/" + name + ".gd", "--", "--capture-output=" + str(capture.resolve())),
        execution_policy.watchdog_seconds("graphical_case_seconds"), 1.0, True)


def graphical(args: argparse.Namespace) -> None:
    require_platform(args.platform)
    manifest = engine.verify_bundle(args.bundle, args.platform, args.source_sha, validated=True)
    verify_catalogue_bundle(args.bundle, args.platform, args.source_sha)
    output = args.bundle / "graphical"
    engine.require(not output.exists(), "Do not overwrite an earlier graphical attempt")
    output.mkdir()
    if args.platform == "windows":
        godot, godot_identity = engine.windows.prepare_godot(args.godot_archive)
    else:
        engine.require(engine.runner.sha256(args.godot_archive) == engine.GODOT_LINUX_SHA256, "Linux engine archive changed")
        godot = args.godot_archive.with_suffix("") / "Godot_v4.7-stable_linux.x86_64"
        godot_identity = {"version": engine.GODOT_VERSION, "runtime_sha256": engine.runner.sha256(godot)}
    report = engine.context(args.source_sha) | {
        "schema": "materials-lab-graphical-v1", "platform": args.platform, "godot": godot_identity,
        "native_sha256": manifest["sha256"], "status": "running", "completed": False,
        "results": [], "files_sha256": {},
    }
    report_path = args.bundle / "graphical.json"
    engine.write_json(report_path, report)
    for name in GRAPHICAL_CASES:
        capture = output / name
        case = graphical_case(name, capture, args.platform)
        result, failed = engine.runner.run_case(str(godot), case, output, "graphical")
        report["results"].append(result)
        if failed:
            report["status"] = "failed"
        engine.write_json(report_path, report)
    engine.require(report["status"] != "failed", "Graphical Lab case failed; original evidence is retained")
    engine.require(engine.input_ledgers(args.source_sha) == {key: manifest[key] for key in ("source_inputs", "build_inputs")},
                   "Graphical build/test inputs changed")
    engine.require(engine.runtime_identity(engine.ROOT / engine.RUNTIMES[args.platform], args.platform)["sha256"] == manifest["sha256"],
                   "Native runtime changed during graphical execution")
    report["files_sha256"] = {path.relative_to(args.bundle).as_posix(): engine.runner.sha256(path)
                               for path in sorted(output.rglob("*")) if path.is_file()}
    report.update(status="passed", completed=True)
    engine.write_json(report_path, report)
    verify_capture(args.bundle, args.platform, manifest["sha256"])
    manifest.update(materials_lab_graphical_sha256=engine.runner.sha256(report_path),
                    materials_lab_catalogue_suite_sha256=engine.runner.sha256(args.bundle / "catalogue-suite.json"),
                    validated_platform=args.platform.title() + " x86_64 Godot 4.7 (actual GitHub-hosted headless and graphical execution)",
                    materials_lab_graphical_scope="Actual mounted authoring and World UI, retained images and matching native source/quantity/persistence/worker receipts",
                    other_platforms="This publisher establishes its recorded Linux/Windows execution and graphical scope. Browser/WebAssembly, owner visual and target-PC/GPU acceptance remain separate.")
    engine.write_json(engine.manifest_path(args.bundle, args.platform), manifest)


def verify_materials_bundle(directory: Path, platform: str, source: str) -> dict:
    manifest = engine.verify_bundle(directory, platform, source, validated=True)
    verify_catalogue_bundle(directory, platform, source)
    graphical_report = verify_capture(directory, platform, manifest["sha256"])
    verify_context(graphical_report, source)
    for key, name in (("materials_lab_graphical_sha256", "graphical.json"),
                      ("materials_lab_catalogue_suite_sha256", "catalogue-suite.json")):
        engine.require(manifest.get(key) == engine.runner.sha256(directory / name), "Additional Lab qualification changed: " + name)
    return manifest


DISPATCH_WORKFLOWS = ("documentation.yml", "native.yml", "gdextension.yml", "palette-shader-qualification.yml")


def dispatch_existing(args: argparse.Namespace) -> dict:
    """Request unchanged manual gates only on this campaign's leased bot child."""
    for key, expected in {
        "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
        "GITHUB_REF": "refs/heads/" + engine.BRANCH, "GITHUB_SHA": args.source_sha,
        "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + engine.WORKFLOW + "@refs/heads/" + engine.BRANCH,
    }.items():
        engine.require(os.environ.get(key) == expected, "Unexpected dispatch identity: " + key)
    engine.require(re.fullmatch(r"[0-9a-f]{40}", args.source_sha) is not None and
                   re.fullmatch(r"[0-9a-f]{40}", args.published_sha) is not None, "Expected full dispatch identities")
    run_id, attempt = os.environ.get("GITHUB_RUN_ID", ""), os.environ.get("GITHUB_RUN_ATTEMPT", "")
    engine.require(run_id.isdecimal() and int(run_id) > 0 and attempt.isdecimal() and int(attempt) > 0,
                   "Missing dispatch workflow identity")
    engine.require(engine.git("rev-parse", "HEAD").decode().strip() == args.published_sha and
                   engine.git("rev-list", "--parents", "-n", "1", "HEAD").decode().strip() == args.published_sha + " " + args.source_sha,
                   "Dispatch requires the exact single-parent runtime publication child")
    changed = set(engine.git("diff", "--name-only", "-z", args.source_sha, args.published_sha).decode().split("\0")) - {""}
    allowed = set(engine.RUNTIMES.values()) | set(engine.MANIFESTS.values())
    engine.require(changed.issubset(allowed) and set(engine.MANIFESTS.values()).issubset(changed),
                   "Published child changed paths outside the four runtime files")
    engine.require_publication_request(args.source_sha)
    token = os.environ.get("GITHUB_TOKEN", "")
    engine.require(bool(token), "Scoped Actions dispatch token is unavailable")
    engine.require(not args.output.exists(), "Do not overwrite an earlier dispatch receipt")
    report = {"schema": "materials-lab-existing-gates-dispatch-v1", "source_commit": args.source_sha,
              "published_commit": args.published_sha, "request_sequence": read_json(engine.ROOT / engine.REQUEST)["request_sequence"],
              "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" + run_id, "workflow_attempt": attempt,
              "status": "requesting", "completed": False, "requests": [],
              "scope": "requests only; resulting exact-source workflows require their own natural completion"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    engine.write_json(args.output, report)
    expected_remote = args.published_sha + "\trefs/heads/" + engine.BRANCH
    for workflow in DISPATCH_WORKFLOWS:
        engine.require(engine.git("ls-remote", "--exit-code", "origin", "refs/heads/" + engine.BRANCH).decode().strip() == expected_remote,
                       "Branch moved before manual gate dispatch")
        request = urllib.request.Request(
            "https://api.github.com/repos/techrote/cybersand/actions/workflows/" + workflow + "/dispatches",
            data=json.dumps({"ref": engine.BRANCH}).encode("utf-8"), method="POST",
            headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
                     "X-GitHub-Api-Version": "2022-11-28", "Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=60) as response:
            engine.require(response.status == 204, "Workflow dispatch was not acknowledged")
        report["requests"].append({"workflow": workflow, "status": "accepted", "head_sha": args.published_sha})
        engine.write_json(args.output, report)
        engine.require(engine.git("ls-remote", "--exit-code", "origin", "refs/heads/" + engine.BRANCH).decode().strip() == expected_remote,
                       "Branch moved while dispatching; do not attribute the request to the intended head")
    report.update(status="requested", completed=True)
    engine.write_json(args.output, report)
    return report


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "dispatch-existing":
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("command")
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--published-sha", required=True)
        parser.add_argument("--output", type=Path, required=True)
        print(json.dumps(dispatch_existing(parser.parse_args()), sort_keys=True))
        return 0
    if len(sys.argv) > 1 and sys.argv[1] in {"catalogue-tests", "graphical", "verify-lab", "stage"}:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("command", choices=["catalogue-tests", "graphical", "verify-lab", "stage"])
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--platform", choices=["linux", "windows"])
        parser.add_argument("--bundle", type=Path)
        parser.add_argument("--godot-archive", type=Path)
        parser.add_argument("--linux-bundle", type=Path)
        parser.add_argument("--windows-bundle", type=Path)
        args = parser.parse_args()
        if args.command == "stage":
            if args.linux_bundle is None or args.windows_bundle is None: parser.error("Both target-OS bundles are required")
            for platform, directory in (("linux", args.linux_bundle), ("windows", args.windows_bundle)):
                verify_materials_bundle(directory, platform, args.source_sha)
            engine.stage(args)
        else:
            if args.platform is None or args.bundle is None: parser.error("Platform and bundle are required")
            if args.command == "graphical" and args.godot_archive is None: parser.error("Godot archive is required")
            if args.command == "verify-lab": verify_materials_bundle(args.bundle, args.platform, args.source_sha)
            else: {"catalogue-tests": catalogue_tests, "graphical": graphical}[args.command](args)
        return 0
    return engine.main()


if __name__ == "__main__":
    raise SystemExit(main())
