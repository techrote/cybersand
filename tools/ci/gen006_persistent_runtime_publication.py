#!/usr/bin/env python3
"""Source-bound GEN-006 qualification and four-path runtime publication.

The accepted publication engine still owns request admission, canonical Git
input custody, runtime identity, artifact validation, staging and branch lease.
Only the execution profile is replaced with the bounded persistent-area campaign.
"""
from __future__ import annotations

import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import zipfile

_spec = spec_from_file_location("_gen006_private_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"))
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_old_workflow, _old_request = engine.WORKFLOW, engine.REQUEST
engine.BRANCH = "exp/gen006-persistent-areas-001-20261121"
engine.WORKFLOW = ".github/workflows/gen006-persistent-areas-qualification.yml"
engine.REQUEST = "tools/ci/gen006_persistent_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-21-gen006-persistent-areas.md"
engine.PRESSURE_CASE = "godot/tests/test_persistent_area_native_bridge.gd"
engine.CASE_MARKERS = {
    "test_persistent_area_native_bridge": r"GEN006_NATIVE_BRIDGE assertions=[1-9][0-9]* failures=0",
    "test_persistent_area_owner_adversarial": r"GEN006_OWNER_ADVERSARIAL assertions=[1-9][0-9]* failures=0",
    "test_persistent_area_clock": r"GEN006_CLOCK",
    "test_persistent_area_store": r"GEN006_STORE",
    "test_persistent_areas_workbench": r"PERSISTENT_AREAS_WORKBENCH",
}
engine.BUNDLE_PREFIX = "gen006-persistent-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "gen006-persistent-runtime-publish-request-v1",
    "family": "persistent-authored-areas",
    "variant": "bounded-full-world-cyps2-current-free-mass",
    "scope": "three-areas-native-game-time-durable-recovery-linux-windows",
    "intent": "publish-source-matched-runtimes",
}
engine.EXECUTION_SCOPE = (
    "Three actor-free 512x512 Current/FreeMass authored areas, full CYPS2 "
    "continuation, exact bounded native catch-up with explicit debt, isolated "
    "durable profiles, independent-process recovery and actual Godot 4.7 "
    "graphical Linux/Windows execution. Draft/HOLD; no physical NVIDIA owner "
    "acceptance, arbitrary actor persistence or general GEN-006 streaming claim."
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_old_workflow, _old_request}) | {
    "tools/ci/reciprocal_windows_package.py", "tools/swarm45/runtime_custody.py",
    "godot/tools/swarm004-runtime.windows.json",
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE, engine.PRESSURE_CASE,
    "tools/ci/gen006_persistent_runtime_publication.py",
    "tools/ci/test_gen006_persistent_runtime_publication.py",
    "tools/ci/test_gen006_source_custody.py",
    "tools/ci/test_gen006_packaged_smoke.ps1",
    "tools/ci/run_persistent_areas_qualification.py",
    "tools/ci/run_gen006_storage_recovery.py",
    "tools/ci/build_gentek80_runtime.py",
    "tools/package_gen006_persistent_areas.py",
    "tools/package_workbench_landscape_review.py",
    "tools/package_explore001_candidate.py",
    "tools/package_wave_flow_candidate.py",
    "tools/qualify_workbench_landscapes.py",
    "tools/ci/stage_windows_vc_runtime.ps1",
    "tools/ci/native_candidate_identity.py",
    "tools/ci/run_flatten_qualification.py",
    "tools/ci/run_workbench_qualification.py",
    "tools/ci/wave_mt_runtime_publication.py",
    "tools/ci/execution_policy.py", "tools/ci/execution_telemetry.py",
    "tools/ci/godot_scheduling.py", "tools/ci/godot_scheduling_profile.json",
    "tools/ci/performance_history.py", "godot/tests/support/ci_execution_policy.json",
} | set(engine.windows.RAPIER_IMPORT_DESCRIPTORS)

REQUIRED_LABELS = frozenset({
    "native-bridge", "clock", "store-unit", "owner-adversarial", "owner-timeout", "ordinary-workbench-launcher",
    "store-seed", "store-verify", "store-crash-staged", "store-lock-staged",
    "store-recover-staged", "store-crash-published", "store-lock-published",
    "store-recover-published", "store-repeat-verify",
    "workbench-write-w1", "workbench-reopen-w1",
    "workbench-crash-source_durable", "workbench-recover-source_durable",
    "workbench-crash-candidate_durable", "workbench-recover-candidate_durable",
    "workbench-write-w4", "workbench-reopen-w4",
    "regression-host-evidence", "regression-microscenario-controllers",
    "regression-host-capacity", "regression-workbench-input", "regression-material-baseline",
})
WORKBENCH_LABELS = frozenset(label for label in REQUIRED_LABELS
    if label.startswith("workbench-") and "-crash-" not in label)
NATIVE_MARKERS = (
    r"(?m)^GEN006_NATIVE_CONTINUATION_PASS initial_tick=37 completed_tick=325 slice_sizes=1,8,32 configured_workers=1,4 observed_workers=4 physical=[0-9a-f]{16} checkpoint_bytes=[1-9][0-9]* resident_cell_bytes=[1-9][0-9]* native_ticks=288 native_step_us=[1-9][0-9]*$",
    r"(?m)^GEN006_NATIVE_REFUSAL_ATOMICITY_PASS corrupt truncated wrong_tick wrong_hash oversized_slice body_mask partial_region private_tick_failure wave_refusal$",
    r"(?m)^GEN006_COARSE_SKIP_REFUSED_PASS sleeping_tick=[1-9][0-9]* reaction_tick=[1-9][0-9]* epoch_wrap_tick=256 requested_ticks=36000 credited_ticks=0 remaining_debt=36000$",
    r"(?m)^GEN006_NATIVE_THREE_AREAS_PASS sequence=A,B,C,A,B retained_checkpoint_bytes=[1-9][0-9]*$",
)
require = engine.require
sha = engine.runner.sha256
CAMPAIGN_SCRIPT = "tools/ci/run_persistent_areas_qualification.py"
CAMPAIGN_TIMEOUT_SECONDS = {"linux": 3600, "windows": 3600}


def safe_relative(value: object) -> str:
    require(isinstance(value, str) and value and "\\" not in value, "Invalid evidence path")
    path = PurePosixPath(value)
    require(not path.is_absolute() and ".." not in path.parts and ":" not in value,
            "Evidence path escapes its directory")
    return value


def verify_files(directory: Path, files: object) -> None:
    require(isinstance(files, dict) and files, "Missing original evidence file ledger")
    for relative, digest in files.items():
        path = directory / safe_relative(relative)
        require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None,
                "Invalid evidence SHA-256")
        require(path.is_file() and not path.is_symlink()
                and path.resolve().is_relative_to(directory.resolve())
                and all(not parent.is_symlink() for parent in path.parents if parent != directory.parent)
                and sha(path) == digest,
                "Original evidence changed or is missing: " + relative)


def verify_build_ledger(path: Path, platform: str, source: str, runtime: dict,
                        native_inputs: dict) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(value.get("schema") == "gentek80-native-build-v1" and value.get("returncode") == 0,
            "Native build did not complete successfully")
    require(value.get("source_commit") == source and value.get("platform") == platform
            and value.get("source_tree") == engine.git("rev-parse", source + "^{tree}").decode().strip(),
            "Native build source/platform differs")
    require(value.get("source_inputs_sha256") == native_inputs,
            "Native build input ledger differs from canonical source")
    require(value.get("runtime_sha256") == runtime["sha256"]
            and value.get("runtime_bytes") == runtime["size"], "Native build output differs")
    version = str(value.get("compiler_version", ""))
    require((platform == "linux" and re.search(r"\b13\.3\.0\b", version) is not None)
            or (platform == "windows" and "clang version 23.1.0" in version),
            "Diagnostic or unpinned compiler cannot qualify a release runtime")
    require(re.fullmatch(r"[0-9a-f]{64}", str(value.get("godot_cpp_library_sha256", ""))) is not None,
            "Missing pinned godot-cpp build identity")
    return value


def verify_qualification(directory: Path, value: dict, platform: str, source: str,
                         runtime_sha: str, godot_sha: str, ledger_sha: str,
                         ledgers: dict) -> None:
    require(value.get("schema") == "gen006-persistent-areas-qualification-v1"
            and value.get("status") == "passed" and value.get("completed") is True,
            "Incomplete persistent-area qualification")
    require(value.get("platform") == platform and value.get("source_commit") == source
            and value.get("source_tree") == engine.git("rev-parse", source + "^{tree}").decode().strip(),
            "Qualification source/platform mismatch")
    require(value.get("graphical") is True and value.get("input_custody") == "passed"
            and value.get("local_delta") == [], "Headless, dirty or unbound campaign cannot publish")
    require(value.get("native_sha256") == runtime_sha and value.get("engine_sha256") == godot_sha
            and value.get("engine_version") == engine.GODOT_VERSION
            and value.get("rapier_sha256") == engine.RAPIER[platform][1]
            and value.get("native_build_ledger_sha256") == ledger_sha,
            "Qualification runtime, engine or actual build identity differs")
    supplied = value.get("source_inputs_sha256", {})
    expected = ledgers["source_inputs"] | ledgers["build_inputs"]
    required = set(ledgers["source_inputs"]) | {
        path for path in ledgers["build_inputs"] if path.startswith("godot/")
        and Path(path).suffix in {".gd", ".tscn", ".tres", ".gdshader"}}
    required |= {"Makefile", "tools/build_native_extension.sh", "tools/build_native_extension_windows.sh",
                 "tools/ci/run_persistent_areas_qualification.py"}
    required |= set(engine.windows.RAPIER_IMPORT_DESCRIPTORS)
    require(isinstance(supplied, dict) and required.issubset(supplied)
            and all(expected.get(path) == digest for path, digest in supplied.items()),
            "Qualification omitted or changed a required source input")
    rows = value.get("results", [])
    require(isinstance(rows, list) and all(isinstance(row, dict) for row in rows), "Malformed result rows")
    labels = [row.get("label") for row in rows]
    require(len(labels) == len(set(labels)) and REQUIRED_LABELS.issubset(labels)
            and all(row.get("status") == "passed" for row in rows),
            "Required process evidence is missing, duplicated, failed or skipped")
    workbench = value.get("workbench", {})
    require(isinstance(workbench, dict) and WORKBENCH_LABELS.issubset(workbench),
            "Missing real Workbench return/recovery evidence")
    for label in WORKBENCH_LABELS:
        row = workbench[label]
        require(isinstance(row, dict) and row.get("failures") == [] and row.get("graphical") is True,
                "Actual graphical Workbench qualification failed: " + label)
    verify_files(directory, value.get("files_sha256"))
    custody = value.get("custody_checks", [])
    require(isinstance(custody, list)
            and [row.get("phase") for row in custody] == ["after-import", "after-campaign"]
            and all(row.get("unchanged") is True for row in custody),
            "Missing or failing original before/after source custody observations")
    require("source-custody.json" in value["files_sha256"], "Original source custody report is not bound")
    custody_report = json.loads((directory / "source-custody.json").read_text(encoding="utf-8"))
    require(custody_report.get("schema") == "gen006-source-custody-v1"
            and custody_report.get("checks") == custody,
            "Original source custody observations differ from qualification")
    before = {key:value.get(key) for key in ("source_commit", "source_tree", "source_inputs_sha256",
                                           "missing_source_inputs", "local_delta")}
    require(before["missing_source_inputs"] == [] and custody_report.get("source_before") == before,
            "Source custody baseline differs from qualification")
    binaries = {key:value[key] for key in ("native_sha256", "rapier_sha256", "engine_sha256")}
    require(all(row.get("source_after") == before and row.get("binaries_before") == binaries
                and row.get("binaries_after") == binaries for row in custody),
            "Source or executed runtime changed across a custody checkpoint")
    for row in rows:
        require(type(row.get("pid")) is int and row["pid"] > 0
                and row.get("log") in value["files_sha256"],
                "Process identity or original log missing: " + str(row.get("label")))
        if "-crash-" in row["label"]:
            require(row.get("forced_termination") is True, "Crash evidence did not terminate an actual process")
    require("results.json" in value["files_sha256"]
            and any(name.endswith(".png") for name in value["files_sha256"]),
            "Qualification has no original process report or graphical capture")


def verify_case_results(directory: Path, report: dict) -> None:
    """Used by the unchanged engine on both execution and later publication."""
    qpath = directory / "qualification" / "qualification.json"
    require(sha(qpath) == report.get("qualification_sha256"), "Qualification report changed")
    ledger_path = directory / "native-build.json"
    require(sha(ledger_path) == report.get("native_build_ledger_sha256"), "Native build ledger changed")
    ledgers = engine.input_ledgers(report["source_commit"])
    build = verify_build_ledger(ledger_path, report["platform"], report["source_commit"], report["runtime"],
                                ledgers["source_inputs"])
    require(sha(directory / "native-build.log") == build.get("log_sha256"), "Original native build log changed")
    verify_qualification(qpath.parent, json.loads(qpath.read_text(encoding="utf-8")), report["platform"],
                         report["source_commit"], report["runtime"]["sha256"],
                         report["godot"]["runtime_sha256"], report["native_build_ledger_sha256"], ledgers)


engine.verify_case_results = verify_case_results


def record(args: argparse.Namespace) -> None:
    ledgers = engine.input_ledgers(args.source_sha)
    runtime = engine.runtime_identity(args.runtime, args.platform)
    verify_build_ledger(args.native_build_ledger, args.platform, args.source_sha, runtime, ledgers["source_inputs"])
    engine.record_build(args)
    destination = args.bundle / "native-build.json"
    if args.native_build_ledger.resolve() != destination.resolve():
        shutil.copyfile(args.native_build_ledger, destination)
    log = args.native_build_ledger.with_suffix(".log")
    value = json.loads(destination.read_text(encoding="utf-8"))
    require(log.is_file() and sha(log) == value.get("log_sha256"), "Native build output log changed")
    if log.resolve() != (args.bundle / "native-build.log").resolve():
        shutil.copyfile(log, args.bundle / "native-build.log")


def prepare_godot(archive: Path, platform: str) -> tuple[Path, dict]:
    if platform == "windows":
        return engine.windows.prepare_godot(archive)
    require(sha(archive) == engine.GODOT_LINUX_SHA256, "Linux Godot archive mismatch")
    directory = archive.with_suffix("")
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, "Godot archive is corrupt")
        bundle.extractall(directory)
    godot = directory / "Godot_v4.7-stable_linux.x86_64"
    godot.chmod(0o755)
    version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
    require(version == engine.GODOT_VERSION, "Godot version mismatch")
    return godot, {"version": version, "archive_sha256": engine.GODOT_LINUX_SHA256,
                   "runtime_sha256": sha(godot)}


def execute_campaign(command: list[str], *, cwd: Path, timeout: float,
                     bundle: Path) -> subprocess.CompletedProcess:
    """Donor default; successor profiles may supply an isolated process owner."""
    return subprocess.run(command, cwd=cwd, timeout=timeout)


def execute(args: argparse.Namespace) -> None:
    require((args.platform == "windows" and sys.platform == "win32") or
            (args.platform == "linux" and sys.platform.startswith("linux")),
            "Actual target-OS execution is required")
    campaign_timeout = CAMPAIGN_TIMEOUT_SECONDS[args.platform]
    manifest = engine.verify_bundle(args.bundle, args.platform, args.source_sha, validated=False)
    shutil.copyfile(args.bundle / Path(engine.RUNTIMES[args.platform]).name,
                    engine.ROOT / engine.RUNTIMES[args.platform])
    require(sha(engine.ROOT / engine.RAPIER[args.platform][0]) == engine.RAPIER[args.platform][1],
            "Rapier differs from pinned runtime")
    godot, identity = prepare_godot(args.godot_archive, args.platform)
    if args.platform == "linux":
        subprocess.run(["bash", "tools/check_linux_runtime_floor.sh"], cwd=engine.ROOT, check=True, timeout=60)
    ledger_path = args.bundle / "native-build.json"
    runtime = engine.runtime_identity(engine.ROOT / engine.RUNTIMES[args.platform], args.platform)
    verify_build_ledger(ledger_path, args.platform, args.source_sha, runtime, manifest["source_inputs"])
    report = {"schema_version": 1, "source_commit": args.source_sha, "platform": args.platform,
        "runtime": runtime, "godot": identity, "rapier_sha256": engine.RAPIER[args.platform][1],
        "status": "running", "completed": False, "scope": engine.EXECUTION_SCOPE,
        "native_build_ledger_sha256": sha(ledger_path),
        "campaign_timeout_seconds": campaign_timeout}
    report_path = args.bundle / "validation.json"
    engine.write_json(report_path, report)
    campaign = [sys.executable, str(engine.ROOT / CAMPAIGN_SCRIPT),
        "--godot", str(godot.resolve()), "--project", str(engine.ROOT / "godot"),
        "--evidence", str((args.bundle / "qualification").resolve()),
        "--require-clean-source", "--native-build-ledger", str(ledger_path.resolve())]
    result = execute_campaign(campaign, cwd=engine.ROOT, timeout=campaign_timeout, bundle=args.bundle)
    require(result.returncode == 0, "Persistent-area campaign failed; no validated runtime published")
    qpath = args.bundle / "qualification" / "qualification.json"
    report.update({"qualification_sha256": sha(qpath), "status": "passed", "completed": True})
    engine.write_json(report_path, report)
    verify_case_results(args.bundle, report)
    require(engine.runtime_identity(engine.ROOT / engine.RUNTIMES[args.platform], args.platform) == runtime,
            "Runtime changed during qualification")
    require(engine.input_ledgers(args.source_sha) == {key: manifest[key] for key in ("source_inputs", "build_inputs")},
            "Source changed during qualification")
    manifest.update({"status": "validated-development-runtime", "workflow_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
        "validated_platform": args.platform.title() + " x86_64 Godot 4.7 (actual graphical GitHub-hosted execution)",
        "acceptance": engine.EXECUTION_SCOPE,
        "validation_output": engine.BUNDLE_PREFIX + "-" + args.platform + "-" + os.environ["GITHUB_RUN_ID"] + "/validation.json",
        "validation_sha256": sha(report_path),
        "other_platforms": "Automated graphical/native target-OS evidence; physical Windows 11/NVIDIA owner acceptance remains pending."})
    engine.write_json(engine.manifest_path(args.bundle, args.platform), manifest)
    engine.verify_bundle(args.bundle, args.platform, args.source_sha, validated=True)


def verify_native(args: argparse.Namespace) -> None:
    data = args.log.read_bytes()
    output = data.decode("utf-8")
    require(all(len(re.findall(marker, output)) == 1 for marker in NATIVE_MARKERS),
            "Native continuation, worker parity, refusal or coarse-skip evidence incomplete")
    require(re.search(r"(?im)GEN006_NATIVE_FAIL|runtime error:|ERROR: AddressSanitizer|SUMMARY: .*Sanitizer", output) is None,
            "Native qualification failed or sanitizer reported an error")
    engine.write_json(args.output, engine.context(args.source_sha) | {
        "schema": "gen006-native-continuation-gate-v1", "status": "passed",
        "source_inputs": engine.input_ledgers(args.source_sha)["source_inputs"],
        "log_sha256": hashlib.sha256(data).hexdigest(), "binary_sha256": sha(args.binary),
        "sanitizer": args.sanitizer})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("record", "test", "stage", "check-source", "check-index", "verify-native"):
        command = commands.add_parser(name)
        command.add_argument("--source-sha", required=True)
        if name in ("record", "test"):
            command.add_argument("--platform", choices=engine.RUNTIMES, required=True)
            command.add_argument("--bundle", type=Path, required=True)
        if name == "record":
            command.add_argument("--runtime", type=Path, required=True)
            command.add_argument("--toolchain", type=Path, required=True)
            command.add_argument("--native-build-ledger", type=Path, required=True)
        elif name == "test":
            command.add_argument("--godot-archive", type=Path, required=True)
        elif name == "stage":
            command.add_argument("--linux-bundle", type=Path, required=True)
            command.add_argument("--windows-bundle", type=Path, required=True)
        elif name == "verify-native":
            command.add_argument("--log", type=Path, required=True)
            command.add_argument("--output", type=Path, required=True)
            command.add_argument("--binary", type=Path, required=True)
            command.add_argument("--sanitizer", action="store_true")
    args = parser.parse_args()
    {"record": record, "test": execute, "stage": engine.stage,
     "check-source": engine.check_source, "check-index": engine.check_index,
     "verify-native": verify_native}[args.command](args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
