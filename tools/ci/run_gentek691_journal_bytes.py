#!/usr/bin/env python3
"""Additional Windows evidence for an exact published candidate; never product CI replacement."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
MODES = ("missing-newline", "invalid-utf8", "incomplete-json")
MARKER = "INDEPENDENT_COMMITTED_JOURNAL_RESULT"
CHECK = "INDEPENDENT_COMMITTED_JOURNAL_CHECK "
SCOPE = "mounted native-backed Workbench completion signal, synthetic immutable receipt fixture"
PROBE = "godot/tests/probe_committed_journal_bytes.gd"
RUNNER = "tools/ci/run_gentek691_journal_bytes.py"
WORKFLOW = ".github/workflows/gentek691-journal-bytes.yml"
HELPER = "tools/ci/run_art_history_recovery.py"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
GODOT_ARCHIVE_SHA512 = "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9"
GODOT_ENGINE_SHA256 = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
NATIVE_SHA256 = "668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
RAPIER_SHA256 = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
BUILD_SOURCE = "c53fd6f9d3d0f2b3f39396c7e605654f65c17299"
PROBE_SHA256 = "70153c587196835708860edec5d92369ed9c10b7bcf75b1815ce19b95fc05206"
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
EXPECTED_JSON_ERROR = "ERROR: Parse JSON failed. Error at line 1: Expected key"
NATIVE_MARKER = "GENTEK691_NATIVE_BINDING_RESULT"
NATIVE_CHECK = "GENTEK691_NATIVE_BINDING_CHECK "
NATIVE_CLASSES = ("CyberNativeCellWorld", "CyberDemoBridge", "CyberNativePaintPlanner", "RapierPhysicsServer2D")
NATIVE_BINDINGS = {
    "CyberNativeCellWorld": ("stored_material_at", "rigid_body_id_at", "emit_disc"),
    "CyberDemoBridge": ("inspect_interaction", "loaded_native_runtime_values", "replace_material_baseline_file"),
    "CyberNativePaintPlanner": ("interface_version", "fill_connected"),
}
NATIVE_ASSERTIONS = len(NATIVE_CLASSES) + len(NATIVE_BINDINGS) + sum(map(len, NATIVE_BINDINGS.values())) + 4
# Bound by this runner's Git identity; materialized only in retained evidence.
# Reuses the candidate worker and native executor/atomic-publication contracts.
NATIVE_PREFLIGHT_SOURCE = r'''extends SceneTree
const Worker = preload("res://scripts/simulation_worker.gd")
const REQUIRED_CLASSES = __CLASSES__
const REQUIRED_BINDINGS = __BINDINGS__
var checks := 0
var failures: Array[String] = []
var result := {"classes":{},"types":{},"bindings":{}}
func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print("GENTEK691_NATIVE_BINDING_CHECK ",label," ",ok)
	if not ok: failures.append(label)
func finish() -> void:
	result.merge({"checks":checks,"failures":failures,"passed":failures.is_empty()})
	print("GENTEK691_NATIVE_BINDING_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	for name: String in REQUIRED_CLASSES:
		result.classes[name] = ClassDB.class_exists(name)
		check(result.classes[name],"ClassDB registration "+name)
	if not failures.is_empty(): finish();return
	# No worker thread is started: inspect the actual worker selection before use.
	var worker: RefCounted = Worker.new()
	var world: Object = worker._world
	var bridge: Object = ClassDB.instantiate("CyberDemoBridge")
	var planner: Object = ClassDB.instantiate("CyberNativePaintPlanner")
	var objects := {"CyberNativeCellWorld":world,"CyberDemoBridge":bridge,"CyberNativePaintPlanner":planner}
	for name: String in REQUIRED_BINDINGS:
		var object: Object = objects[name]
		result.types[name] = str(object.get_class()) if object != null else "null"
		check(result.types[name] == name,"actual native instance "+name)
	if not failures.is_empty(): finish();return
	for name: String in REQUIRED_BINDINGS:
		for method: String in REQUIRED_BINDINGS[name]:
			var key := name+"."+method
			result.bindings[key] = objects[name].has_method(method)
			check(result.bindings[key],"required native binding "+key)
	if not failures.is_empty(): finish();return
	result.worker_backend = str(world.get_class())
	result.native_readback = int(world.stored_material_at(0,0))
	check(result.native_readback >= 0 and result.native_readback < 256,"native stored-material call returns byte identity")
	var interaction: Dictionary = bridge.inspect_interaction(0,0,0)
	result.native_interaction_ok = bool(interaction.get("ok",false))
	check(result.native_interaction_ok,"native compiled interaction call accepts Empty")
	result.planner_interface_version = int(planner.interface_version())
	check(result.planner_interface_version == 1,"native planner interface call returns contract version")
	var runtime: Dictionary = bridge.loaded_native_runtime_values()
	result.runtime_path_file = runtime
	var expected := ProjectSettings.globalize_path("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll").simplify_path().to_lower()
	check(runtime.get("status") == "path_file_observed" and runtime.get("current_file_sha256") == "__NATIVE_SHA256__"
		and str(runtime.get("api_reported_library_path","")).simplify_path().to_lower() == expected
		and runtime.get("mapped_module_binding") == "unverified","native API reports pinned candidate path bytes with explicit mapped-module limit")
	finish()
'''.replace("__CLASSES__", json.dumps(NATIVE_CLASSES)).replace("__BINDINGS__", json.dumps(NATIVE_BINDINGS)).replace("__NATIVE_SHA256__", NATIVE_SHA256)


def sha(path: Path, algorithm: str = "sha256") -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def git(root: Path, *args: str, binary: bool = False):
    result = subprocess.check_output(["git", "-C", str(root), *args], timeout=60)
    return result if binary else result.decode("utf-8").rstrip("\r\n")


def require_sha(value: str, name: str) -> None:
    if re.fullmatch(r"[0-9a-f]{40}", value or "") is None:
        raise ValueError(name + " must be an exact commit/tree SHA, never a branch or placeholder")


def checkout_identity(root: Path, expected_sha: str, expected_tree: str | None = None) -> dict:
    result = {"root": str(root), "commit": git(root, "rev-parse", "HEAD"),
              "tree": git(root, "rev-parse", "HEAD^{tree}"),
              "working_status_all": git(root, "status", "--porcelain", "--untracked-files=all")}
    if result["commit"] != expected_sha or (expected_tree and result["tree"] != expected_tree):
        raise ValueError("Checkout does not match its fixed commit/tree: " + str(root))
    if result["working_status_all"]:
        raise ValueError("Initial checkout is not clean: " + str(root))
    return result


def harness_identity(root: Path, expected_sha: str) -> dict:
    result = checkout_identity(root, expected_sha)
    result["files_sha256"] = {}
    for relative in (WORKFLOW, RUNNER, PROBE):
        path = root / relative
        if path.is_symlink() or path.read_bytes() != git(root, "show", "HEAD:" + relative, binary=True):
            raise ValueError("Auxiliary harness bytes differ from its exact Git commit: " + relative)
        result["files_sha256"][relative] = sha(path)
    if result["files_sha256"][PROBE] != PROBE_SHA256:
        raise ValueError("The independent probe is not byte-identical to the reviewed original")
    return result


def load_candidate_helpers(candidate: Path):
    sys.path.insert(0, str(candidate / "tools/ci"))
    spec = importlib.util.spec_from_file_location("candidate_art_history_recovery", candidate / HELPER)
    if spec is None or spec.loader is None:
        raise ValueError("Candidate Art identity helper cannot be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if module.ROOT.resolve() != candidate:
        raise ValueError("Identity helper resolved a different product checkout")
    return module


def candidate_identity(helper, candidate: Path, engine: Path) -> dict:
    result = helper.identity(candidate / "godot", engine)
    tracked = {p.removeprefix("godot/") for p in git(candidate, "ls-files", "-z", "--", "godot").split("\0") if p.endswith(".gd")}
    if len(tracked) != 660 or set(result["project_script_sha256"]) != tracked:
        raise ValueError("Candidate must retain the exact 660 tracked GDScript inventory")
    if len(result["native_source_inputs"]) != 105:
        raise ValueError("Candidate must retain all 105 attested native inputs")
    if result["native_sha256"] != NATIVE_SHA256 or result["native_build_commit"] != BUILD_SOURCE:
        raise ValueError("Candidate runtime is not the specified newly published Windows build")
    # The established helper retains canonical hashes for cross-platform provenance.
    # Raw hashes additionally make every non-descriptor byte strict during import/tests.
    result["raw_project_script_sha256"] = {p: sha(candidate / "godot" / p) for p in sorted(tracked)}
    result["raw_native_source_inputs_sha256"] = {p: sha(candidate / p) for p in result["native_source_inputs"]}
    result["rapier_runtime_sha256"] = sha(candidate / RAPIER)
    if result["rapier_runtime_sha256"] != RAPIER_SHA256:
        raise ValueError("Rapier runtime differs from its pinned Windows binary")
    result["identity_helper_files_sha256"] = {str(Path(m.__file__).resolve().relative_to(candidate)): sha(Path(m.__file__))
        for name, m in sys.modules.items() if name.startswith("run_") and getattr(m, "__file__", None)
        and Path(m.__file__).resolve().is_relative_to(candidate / "tools/ci")}
    result["identity_helper_files_sha256"][HELPER] = sha(candidate / HELPER)
    return result


def reject_engine_errors(text: str, mode: str | None = None) -> None:
    clean = ANSI.sub("", text)
    errors = [line.strip() for line in clean.splitlines() if line.lstrip().startswith(("ERROR:", "USER ERROR:"))]
    permitted = [EXPECTED_JSON_ERROR] if mode == "incomplete-json" else []
    if ERRORS.search(clean) or any(line not in permitted for line in errors) or len(errors) > len(permitted):
        raise ValueError("Godot reported a script, native-loader or other unexpected engine error")


def verify_native_result(text: str, returncode: int) -> dict:
    if returncode != 0:
        raise ValueError(f"Actual native-preflight Godot process returned {returncode}")
    reject_engine_errors(text)
    markers = [line[len(NATIVE_MARKER) + 1:] for line in text.splitlines() if line.startswith(NATIVE_MARKER + " ")]
    if len(markers) != 1:
        raise ValueError("Require one native-binding completion marker")
    result = json.loads(markers[0])
    checks = [line for line in text.splitlines() if line.startswith(NATIVE_CHECK)]
    if (not isinstance(result, dict) or type(result.get("checks")) is not int or result["checks"] != NATIVE_ASSERTIONS
            or result.get("failures") != [] or result.get("passed") is not True
            or len(checks) != NATIVE_ASSERTIONS or any(not line.endswith(" true") for line in checks)):
        raise ValueError("Native preflight must finish all positive assertions without failures")
    classes = {name: True for name in NATIVE_CLASSES}
    bindings = {name + "." + method: True for name, methods in NATIVE_BINDINGS.items() for method in methods}
    if (result.get("classes") != classes or any(value is not True for value in result["classes"].values())
            or result.get("types") != {name: name for name in NATIVE_BINDINGS}
            or result.get("bindings") != bindings or any(value is not True for value in result["bindings"].values())
            or result.get("worker_backend") != "CyberNativeCellWorld"):
        raise ValueError("Native classes, real worker backend or required bindings are unavailable")
    runtime = result.get("runtime_path_file")
    if (type(result.get("native_readback")) is not int or not 0 <= result["native_readback"] < 256
            or result.get("native_interaction_ok") is not True
            or type(result.get("planner_interface_version")) is not int or result["planner_interface_version"] != 1
            or not isinstance(runtime, dict) or runtime.get("status") != "path_file_observed"
            or runtime.get("current_file_sha256") != NATIVE_SHA256 or runtime.get("mapped_module_binding") != "unverified"
            or type(runtime.get("current_file_size")) is not int or runtime["current_file_size"] <= 0
            or not isinstance(runtime.get("api_reported_library_path"), str) or not runtime["api_reported_library_path"]):
        raise ValueError("Native method calls or explicitly limited path/file observation are invalid")
    return result


def verify_result(text: str, mode: str, returncode: int) -> dict:
    if returncode != 0:
        raise ValueError(f"Actual Godot process returned {returncode}")
    if mode not in MODES:
        raise ValueError("Unknown probe mode")
    reject_engine_errors(text, mode)
    markers = [line[len(MARKER) + 1:] for line in text.splitlines() if line.startswith(MARKER + " ")]
    if len(markers) != 1:
        raise ValueError("Require exactly one independent completion marker")
    result = json.loads(markers[0])
    if (not isinstance(result, dict) or result.get("case") != mode
            or type(result.get("checks")) is not int or result["checks"] != 28
            or type(result.get("failures")) is not list or result["failures"]
            or result.get("passed") is not True):
        raise ValueError("Require this exact case, 28 positive assertions and zero failures")
    checks = [line for line in text.splitlines() if line.startswith(CHECK)]
    if len(checks) != 28 or any(not line.endswith(" true") for line in checks):
        raise ValueError("The original log must retain all 28 successful assertion lines")
    expected = "Malformed pending Art history record" if mode == "incomplete-json" else "Partial or invalid UTF-8 pending Art history record"
    if not isinstance(result.get("refusal"), str) or expected not in result["refusal"]:
        raise ValueError("Probe did not reach its intended committed-record refusal branch")
    counts = result.get("raw_counts")
    if (not isinstance(counts, dict) or set(counts) != {"first-valid", "second-to-repair"}
            or any(type(counts[k]) is not int or counts[k] != 1 for k in counts)):
        raise ValueError("Probe did not prove one raw event per repaired receipt")
    if re.fullmatch(r"[0-9a-f]{64}", str(result.get("original_sha256", ""))) is None or result.get("native_scope") != SCOPE:
        raise ValueError("Probe lacks its archive witness or accurate native fixture scope")
    return result


def self_test() -> int:
    rows = []
    def sample(mode="missing-newline"):
        r = {"case": mode, "checks": 28, "failures": [], "passed": True,
             "refusal": "Malformed pending Art history record" if mode == "incomplete-json" else "Partial or invalid UTF-8 pending Art history record",
             "original_sha256": "0" * 64, "raw_counts": {"first-valid": 1, "second-to-repair": 1}, "native_scope": SCOPE}
        return r
    def output(r):
        return "\n".join(CHECK + str(i) + " true" for i in range(28)) + "\n" + MARKER + " " + json.dumps(r)
    for mode in MODES:
        verify_result(output(sample(mode)), mode, 0)
        rows.append({"case": "accept-" + mode, "passed": True})
    verify_result(EXPECTED_JSON_ERROR + "\n" + output(sample("incomplete-json")), "incomplete-json", 0)
    rows.append({"case": "accept-exact-negative-json-diagnostic", "passed": True})
    good = output(sample())
    negatives = [("nonzero-exit", good, 1), ("native-crash", good, 3221225477),
                 ("missing-marker", good.split(MARKER)[0], 0), ("duplicate-marker", good + "\n" + MARKER + " " + json.dumps(sample()), 0),
                 ("missing-check", good.split("\n", 1)[1], 0), ("false-check", good.replace("0 true", "0 false", 1), 0),
                 ("extra-check", CHECK + "extra true\n" + good, 0), ("script-error", good + "\nSCRIPT ERROR: probe failed", 0),
                 ("invalid-json", good.split(MARKER)[0] + MARKER + " {", 0),
                 ("native-extension-load-error", "ERROR: GDExtension library not found\n" + good, 0),
                 ("native-dynamic-library-error", "ERROR: Can't open dynamic library: cybersand_native.dll\n" + good, 0),
                 ("native-colored-error", "\x1b[31mERROR: Could not load GDExtension library\x1b[0m\n" + good, 0),
                 ("unexpected-json-diagnostic", EXPECTED_JSON_ERROR + "\n" + good, 0)]
    for key, value in (("case", "invalid-utf8"), ("checks", 27), ("checks", 29), ("checks", True),
                       ("failures", ["failure"]), ("failures", 0), ("passed", False),
                       ("raw_counts", {"first-valid": 1, "second-to-repair": 0}),
                       ("raw_counts", {"first-valid": True, "second-to-repair": 1}),
                       ("original_sha256", "missing"), ("refusal", "unrelated failure"), ("native_scope", "actual edit")):
        r = sample(); r[key] = value
        negatives.append(("reject-" + key + "-" + str(value), output(r), 0))
    for name, text, code in negatives:
        try:
            verify_result(text, "missing-newline", code)
        except (ValueError, TypeError):
            rows.append({"case": name, "passed": True, "expected": "refused"})
        else:
            raise AssertionError("Parser accepted negative fixture: " + name)
    native = {"checks": NATIVE_ASSERTIONS, "failures": [], "passed": True,
              "classes": {name: True for name in NATIVE_CLASSES},
              "types": {name: name for name in NATIVE_BINDINGS},
              "bindings": {name + "." + method: True for name, methods in NATIVE_BINDINGS.items() for method in methods},
              "worker_backend": "CyberNativeCellWorld", "native_readback": 0,
              "native_interaction_ok": True, "planner_interface_version": 1,
              "runtime_path_file": {"status": "path_file_observed", "current_file_sha256": NATIVE_SHA256,
                                    "current_file_size": 123, "api_reported_library_path": "D:/candidate/native.dll",
                                    "mapped_module_binding": "unverified"}}
    def native_output(value):
        return "\n".join(NATIVE_CHECK + str(i) + " true" for i in range(NATIVE_ASSERTIONS)) + "\n" + NATIVE_MARKER + " " + json.dumps(value)
    native_good = native_output(native)
    verify_native_result(native_good, 0)
    rows.append({"case": "accept-native-binding-preflight", "passed": True})
    native_negatives = [("native-preflight-crash", native_good, 3221225477),
                        ("native-preflight-loader-error", "ERROR: GDExtension library failed to load\n" + native_good, 0),
                        ("native-preflight-missing-check", native_good.split("\n", 1)[1], 0),
                        ("native-preflight-failed-check", native_good.replace("0 true", "0 false", 1), 0),
                        ("native-preflight-missing-marker", native_good.split(NATIVE_MARKER)[0], 0),
                        ("native-preflight-duplicate-marker", native_good + "\n" + NATIVE_MARKER + " " + json.dumps(native), 0)]
    for key, value in (("checks", NATIVE_ASSERTIONS - 1), ("failures", ["native unavailable"]),
                       ("classes", {name: name != "CyberNativeCellWorld" for name in NATIVE_CLASSES}),
                       ("types", {name: "CyberCellWorld" if name == "CyberNativeCellWorld" else name for name in NATIVE_BINDINGS}),
                       ("bindings", {}), ("worker_backend", "CyberCellWorld"),
                       ("native_readback", True), ("native_interaction_ok", False),
                       ("planner_interface_version", 2),
                       ("runtime_path_file", {**native["runtime_path_file"], "current_file_sha256": "0" * 64}),
                       ("runtime_path_file", {**native["runtime_path_file"], "mapped_module_binding": "verified"})):
        changed = dict(native); changed[key] = value
        native_negatives.append(("reject-native-" + key + "-" + str(value), native_output(changed), 0))
    for name, text, code in native_negatives:
        try:
            verify_native_result(text, code)
        except (ValueError, TypeError):
            rows.append({"case": name, "passed": True, "expected": "refused"})
        else:
            raise AssertionError("Native preflight parser accepted negative fixture: " + name)
    print(json.dumps({"passed": True, "checks": len(rows), "cases": rows}, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidate", "harness", "godot", "godot-archive", "profiles", "evidence"):
        parser.add_argument("--" + name, type=Path)
    for name in ("candidate-sha", "candidate-tree", "harness-sha"):
        parser.add_argument("--" + name)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if any(getattr(args, key) is None for key in ("candidate", "candidate_sha", "candidate_tree", "harness", "harness_sha", "godot", "godot_archive", "profiles", "evidence")):
        parser.error("All candidate, harness, Godot, profile and evidence identity arguments are required")
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    report = {"schema": "gentek691-supplemental-committed-journal-bytes-v1", "additional_evidence_only": True,
              "passed": False, "status": "running", "native_scope": SCOPE, "expected_cases": list(MODES),
              "expected_assertions_per_case": 28, "cases": [], "lifecycle": [], "errors": [],
              "python": {"executable": str(Path(sys.executable).resolve()), "version": sys.version,
                         "version_info": list(sys.version_info[:3])},
              "github": {key: os.environ.get(key, "") for key in ("GITHUB_REPOSITORY", "GITHUB_EVENT_NAME", "GITHUB_REF", "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_WORKFLOW_REF", "GITHUB_WORKFLOW_SHA")}}
    def save():
        (evidence / "qualification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    save()
    helper = None
    profiles = args.profiles.resolve()
    candidate, harness = args.candidate.resolve(), args.harness.resolve()
    def execute(name, command, timeout, mode=None):
        profile = profiles / name
        profile.mkdir(exist_ok=False)
        env = dict(os.environ, APPDATA=str(profile), XDG_DATA_HOME=str(profile), CYBERSAND_SOURCE_REVISION=args.candidate_sha)
        row = {"name": name, "command": command, "profile": str(profile), "status": "running", "returncode": None,
               "profile_before": helper.profile_files(profile)}
        report["cases" if mode else "lifecycle"].append(row)
        log = evidence / (name + ".log")
        process = None
        started = time.monotonic()
        try:
            with log.open("wb") as stream:
                process = subprocess.Popen(command, cwd=evidence, env=env, stdout=stream, stderr=subprocess.STDOUT)
                row["pid"] = process.pid
                process.wait(timeout=timeout)
            row["returncode"] = process.returncode
            text = log.read_text(encoding="utf-8", errors="replace")
            if mode:
                row["completion"] = verify_result(text, mode, process.returncode)
            elif name == "native-preflight":
                row["completion"] = verify_native_result(text, process.returncode)
            else:
                reject_engine_errors(text)
                if process.returncode != 0:
                    raise ValueError(f"Lifecycle {name} failed with actual return code {process.returncode}")
                if name == "version" and text.strip() != GODOT_VERSION:
                    raise ValueError("Engine --version differs from the exact Godot 4.7 pin")
            row["status"] = "passed"
        except Exception as error:
            row.update(status="failed", error=f"{type(error).__name__}: {error}")
            report["errors"].append(name + ": " + row["error"])
        finally:
            if process is not None:
                if process.poll() is None:
                    process.kill(); process.wait(timeout=10)
                row["returncode"] = process.returncode
            row.update(elapsed_seconds=time.monotonic() - started, log_sha256=sha(log) if log.exists() else None,
                       profile_after=helper.profile_files(profile))
            copied = evidence / "profiles" / name
            copied.parent.mkdir(exist_ok=True)
            shutil.copytree(profile, copied)
            if helper.profile_files(copied) != row["profile_after"]:
                raise ValueError("Retained profile copy differs from actual execution bytes")
            row["profile_artifact"] = copied.relative_to(evidence).as_posix()
            save()
            print(f"{row['status'].upper()} {name}: checks={row.get('completion', {}).get('checks')} actual_exit={row['returncode']}", flush=True)
        return row
    try:
        if sys.platform != "win32":
            raise ValueError("This supplementary hosted runner requires actual Windows")
        if sys.version_info[:2] != (3, 12):
            raise ValueError("This supplementary runner requires the established Python 3.12 minor pin")
        report["python"]["executable_sha256"] = sha(Path(sys.executable))
        for value, name in ((args.candidate_sha, "candidate SHA"), (args.candidate_tree, "candidate tree"), (args.harness_sha, "harness SHA")):
            require_sha(value, name)
        if candidate == harness or candidate.is_relative_to(harness) or harness.is_relative_to(candidate):
            raise ValueError("Candidate and auxiliary harness must be separate checkouts")
        if any(profiles == root or profiles.is_relative_to(root) for root in (candidate, harness, evidence)):
            raise ValueError("Use a short fresh profile root outside both checkouts and evidence")
        profiles.mkdir(exist_ok=False)
        report["candidate_checkout"] = checkout_identity(candidate, args.candidate_sha, args.candidate_tree)
        report["harness_before"] = harness_identity(harness, args.harness_sha)
        inputs = evidence / "inputs"; inputs.mkdir()
        for relative in (RUNNER, PROBE, WORKFLOW):
            shutil.copyfile(harness / relative, inputs / Path(relative).name)
        native_preflight = inputs / "native-binding-preflight.gd"
        native_preflight.write_bytes(NATIVE_PREFLIGHT_SOURCE.encode("utf-8"))
        report["native_binding_preflight"] = {
            "source": native_preflight.relative_to(evidence).as_posix(), "sha256": sha(native_preflight),
            "expected_assertions": NATIVE_ASSERTIONS,
            "scope": "ClassDB registration, actual worker native backend and bounded native method calls; API path/file observation does not attest mapped bytes"}
        helper = load_candidate_helpers(candidate)
        engine = helper.direct_engine(args.godot, sys.platform)
        archive = args.godot_archive.resolve()
        report["godot_archive"] = {"path": str(archive), "size": archive.stat().st_size,
                                   "sha512": sha(archive, "sha512"), "sha256": sha(archive)}
        if report["godot_archive"]["sha512"] != GODOT_ARCHIVE_SHA512 or sha(engine) != GODOT_ENGINE_SHA256:
            raise ValueError("Godot archive or actual engine executable differs from its official pin")
        report["checkout_identity"] = candidate_identity(helper, candidate, engine)
        if report["checkout_identity"]["source_commit"] != args.candidate_sha or report["checkout_identity"]["source_tree"] != args.candidate_tree:
            raise ValueError("Candidate identity differs from exact final Q/tree")
        save()
        if execute("version", [str(engine), "--version"], 30)["status"] != "passed":
            raise ValueError("Pinned engine identity verification failed")
        base = [str(engine), "--audio-driver", "Dummy", "--headless", "--path", str(candidate / "godot")]
        original = helper.import_descriptors(candidate)
        original_diff = helper.other_tracked_diff(candidate)
        if execute("import", [*base, "--editor", "--quit"], 180)["status"] != "passed":
            raise ValueError("Candidate editor import failed")
        report["identity_before"] = candidate_identity(helper, candidate, engine)
        report["editor_import"] = helper.qualify_import_transition(
            report["checkout_identity"], report["identity_before"], original,
            helper.import_descriptors(candidate), original_diff, helper.other_tracked_diff(candidate), evidence)
        report["post_import_working_status_all"] = git(candidate, "status", "--porcelain", "--untracked-files=all")
        def strict_identity(row):
            current = candidate_identity(helper, candidate, engine)
            row["candidate_identity_after"] = current
            if current != report["identity_before"] or git(candidate, "status", "--porcelain", "--untracked-files=all") != report["post_import_working_status_all"]:
                raise ValueError("Strict candidate identity changed after the permitted editor-import transition")
            if harness_identity(harness, args.harness_sha) != report["harness_before"] or sha(native_preflight) != report["native_binding_preflight"]["sha256"]:
                raise ValueError("Auxiliary workflow/runner/probe/preflight identity changed during execution")
            save()
        preflight = execute("native-preflight", [*base, "--script", str(native_preflight)], 60)
        strict_identity(preflight)
        if preflight["status"] != "passed":
            raise ValueError("Mandatory native world/history-binding preflight failed")
        for mode in MODES:
            execute(mode, [*base, "--script", str(harness / PROBE), "--", mode], 120, mode)
            strict_identity(report["cases"][-1])
        report["identity_after"] = candidate_identity(helper, candidate, engine)
        report["harness_after"] = harness_identity(harness, args.harness_sha)
        report["positive_assertions"] = sum(r.get("completion", {}).get("checks", 0) for r in report["cases"])
        report["native_preflight_assertions"] = preflight.get("completion", {}).get("checks", 0)
        report["passed"] = (not report["errors"] and [r["name"] for r in report["cases"]] == list(MODES)
                            and all(r["status"] == "passed" and r["returncode"] == 0 for r in report["cases"])
                            and report["positive_assertions"] == 84 and report["native_preflight_assertions"] == NATIVE_ASSERTIONS
                            and report["identity_before"] == report["identity_after"])
        report["status"] = "passed" if report["passed"] else "failed"
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
        report["status"] = "failed"
    finally:
        save()
    print(json.dumps({key: report.get(key) for key in ("passed", "status", "positive_assertions", "native_preflight_assertions", "errors")}), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
