#!/usr/bin/env python3
"""Run fixed, development-only goblin Godot tests in a fresh application profile.

This is repository test tooling, not an in-game command interface. The child game
only receives committed fixture IDs, bounded options and an optional validated
action tape. No user save directory is reused, and native libraries are verified
against their existing source-input manifests before execution.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time
import zipfile

from verify_transcript import verify
from minimize import minimize

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ("material_playground", "actor_workshop", "construction", "liquid_channel", "save_reopen")
POLICIES = ("CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM")
TESTS = {
    "unit": ("test_goblin_policies", "test_goblin_contract"),
    "adapter": ("goblin_adapter",),
    "controller": ("goblin_controller",),
    "graphical": ("goblin_interactive",),
    "baseline": ("test_workbench_deferred_paint", "test_workbench_input"),
}
PROFILE_SCHEMA = "cybersand-goblin-profile-v1"
ERROR_MARKERS = ("SCRIPT ERROR:", "Parse Error:", "ERROR:", "Fatal signal", "Segmentation fault")
COMPLETION_MARKERS = {"campaign": "GOBLIN_CAMPAIGN_COMPLETE", "goblin_adapter": "GOBLIN_ADAPTER ",
                      "goblin_controller": "GOBLIN_CONTROLLER ", "test_goblin_policies": "GOBLIN_POLICY_UNIT ",
                      "goblin_interactive": "GOBLIN_INTERACTIVE_RESULT ",
                      "test_goblin_contract": "GOBLIN_CONTRACT_RESULT ",
                      "test_workbench_deferred_paint": "WB_DEFERRED_PAINT ",
                      "test_workbench_input": "WORKBENCH_INPUT "}


def sha_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True,
                          text=True, timeout=15).stdout.strip()


def runtime_identity(godot: Path) -> dict:
    version = subprocess.run([str(godot), "--version"], capture_output=True, text=True,
                             check=True, timeout=15).stdout.strip()
    required = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text())["godot_version"]
    if version != required:
        raise ValueError(f"Pinned Godot required: {required}; actual: {version}")
    target = "windows" if os.name == "nt" else "linux"
    if target == "linux" and platform.system() != "Linux":
        raise ValueError("This focused evaluator currently admits Linux and Windows only")
    engine = godot
    if target == "windows" and godot.name.endswith("_console.exe"):
        engine = godot.with_name(godot.name.removesuffix("_console.exe") + ".exe")
        if not engine.is_file():
            raise ValueError("The pinned Windows console launcher requires its matching engine executable")
    native_name = "runtime-provenance.json" if target == "windows" else "runtime-provenance.linux.json"
    manifests = {
        "native": ROOT / "godot/addons/cybersand_native" / native_name,
        "rapier": ROOT / f"godot/addons/godot-rapier2d/runtime-provenance.{target}.json",
    }
    result = {"source_commit": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}"),
              "source_dirty": bool(git("status", "--porcelain", "--untracked-files=all")),
              "godot_version": version, "godot_sha256": sha_file(engine), "platform": target,
              "host_platform": platform.platform(), "python": platform.python_version()}
    if engine != godot:
        result["godot_console_sha256"] = sha_file(godot)
    for name, path in manifests.items():
        manifest = json.loads(path.read_text(encoding="utf-8"))
        artifact = ROOT / manifest["artifact"]
        actual = sha_file(artifact)
        if actual != manifest["sha256"]:
            raise ValueError(f"{name} runtime bytes do not match retained provenance; materialize Git LFS first")
        drift = []
        for source, expected in manifest["source_inputs"].items():
            data = (ROOT / source).read_bytes().replace(b"\r\n", b"\n")
            if hashlib.sha256(data).hexdigest() != expected:
                drift.append(source)
        if drift:
            raise ValueError(f"{name} runtime source inputs differ: {drift}")
        result[name + "_sha256"] = actual
        result[name + "_build_commit"] = manifest.get("source_commit", manifest.get("build_commit"))
        result[name + "_source_input_count"] = len(manifest["source_inputs"])
        result[name + "_provenance_sha256"] = sha_file(path)
    return result


def stage_project(destination: Path) -> dict:
    """Snapshot source once so a concurrent edit cannot change a running process."""
    source = ROOT / "godot"
    def ignored(directory: str, names: list[str]) -> list[str]:
        parent = Path(directory)
        if parent == source:
            return [n for n in names if n == ".godot"]
        return [n for n in names if n.endswith((".tmp", ".log")) or n == "__pycache__"]
    shutil.copytree(source, destination, ignore=ignored)
    # The two portable bootstrap registries are needed before a clean import.
    cache = destination / ".godot"
    cache.mkdir()
    for name in (".gdignore", "extension_list.cfg", "global_script_class_cache.cfg"):
        original = source / ".godot" / name
        if original.is_file():
            shutil.copy2(original, cache / name)
    entries = {p.relative_to(destination).as_posix(): sha_file(p)
               for p in sorted(destination.rglob("*")) if p.is_file() and ".godot" not in p.parts}
    source_changed = [name for name, digest in entries.items() if not (source / name).is_file()
                      or sha_file(source / name) != digest]
    if source_changed:
        raise ValueError("Source changed during project snapshot; retry after the checkpoint settles")
    digest = hashlib.sha256(json.dumps(entries, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"project_files_sha256": digest, "files": entries}


def make_profile(path: Path, launch: dict, provenance: dict, replay: dict | None = None,
                 reproduction: dict | None = None) -> dict:
    path.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ)
    for variable, folder in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                             ("XDG_CACHE_HOME", "cache"), ("APPDATA", "appdata"),
                             ("LOCALAPPDATA", "localappdata")):
        directory = path / folder
        directory.mkdir()
        env[variable] = str(directory)
    env["CYBERSAND_GOBLIN_PROFILE"] = str(path)
    env["CYBERSAND_SOURCE_REVISION"] = provenance["source_commit"]
    # Godot's editor profiler initializes before the usual user-dir creation.
    # Precreate the established application path inside this new profile.
    for base in (path / "data/godot/app_userdata", path / "appdata/Godot/app_userdata"):
        (base / "Cyber Sand Reference Sandbox").mkdir(parents=True)
    write_json(path / "goblin-profile.json", {"schema": PROFILE_SCHEMA, "launch": launch,
                                             "provenance": provenance})
    if replay is not None:
        write_json(path / "goblin-replay.json", replay)
    if reproduction is not None:
        write_json(path / "goblin-reproduction.json", reproduction)
    return env


def retain_source_and_remove_project(out: Path, project: Path) -> None:
    """Keep the exact executed scripts; binaries remain identified by manifests."""
    if not project.is_dir():
        return
    with zipfile.ZipFile(out / "executed-game-source.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(project.rglob("*")):
            if path.is_file() and ".godot" not in path.parts and path.suffix in {".gd", ".gdshader", ".tscn", ".tres", ".godot", ".json", ".gdextension"}:
                archive.write(path, path.relative_to(project).as_posix())
    shutil.rmtree(project)


def execute(command: list[str], env: dict, log: Path, timeout: int | None) -> dict:
    started = time.monotonic()
    status, code = "crash", None
    with log.open("w", encoding="utf-8") as output:
        try:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=output,
                                     stderr=subprocess.STDOUT, timeout=timeout)
            code = process.returncode
            status = "pass" if code == 0 else ("crash" if code < 0 else "test_failure")
        except subprocess.TimeoutExpired:
            status = "timeout"
            output.write("\nGOBLIN_PROCESS_TIMEOUT\n")
    text = log.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in text.splitlines() if any(marker in line for marker in ERROR_MARKERS)]
    if errors and status == "pass":
        status = "diagnostic_failure"
    return {"status": status, "exit_code": code, "elapsed_seconds": round(time.monotonic() - started, 3),
            "timeout_seconds": timeout, "command": command, "log_sha256": sha_file(log),
            "diagnostic_errors": errors[:40]}


def read_transcript(profile: Path) -> tuple[dict | None, Path | None]:
    candidates = list(profile.rglob("goblin/transcript.json"))
    if len(candidates) != 1:
        return None, None
    path = candidates[0]
    if path.stat().st_size > 32 * 1024 * 1024:
        raise ValueError("Transcript exceeds the fixed 32 MiB limit")
    return json.loads(path.read_text(encoding="utf-8")), path


def reduce_gameplay(original: dict, *, out: Path, godot: Path, project: Path, provenance: dict,
                    timeout: int, max_attempts: int, repeats: int, graphical: bool) -> dict:
    """The reducer callback can invoke only the fixed goblin test entrypoint."""
    if original.get("header", {}).get("provenance") != provenance:
        raise ValueError("Reduction requires the recorded exact source snapshot and runtime identities")
    wanted_kind = "graphical_godot" if graphical else "headless_godot"
    if original["header"].get("evidence_kind") != wanted_kind:
        raise ValueError("Reduction must use the original headless/graphical execution mode")
    write_json(out / "original-transcript.json", original)
    attempts = []
    def replay_actions(actions: list[dict]) -> dict:
        index = len(attempts)
        target = out / f"probe-{index:03d}"
        target.mkdir()
        plan = {"schema": "cybersand-goblin-action-fixture-v1", "header": original["header"], "actions": actions}
        write_json(target / "reproduction-fixture.json", plan)
        launch = {"fixture_id": original["header"]["fixture_id"], "policy": original["header"]["policy"],
                  "seed": original["header"]["seed"], "budget": len(actions), "pacing_ms": 0,
                  "reproduce": True, "evidence_kind": wanted_kind}
        profile = target / "profile"
        env = make_profile(profile, launch, provenance, reproduction=plan)
        command = [str(godot)] + ([] if graphical else ["--headless"])
        if graphical and os.name == "nt":
            command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
        command += ["--path", str(project), "--script", "res://goblin/run_campaign.gd"]
        process = execute(command, env, target / "replay.log", timeout)
        attempts.append(process)
        write_json(target / "process.json", process)
        tape, _ = read_transcript(profile)
        if tape is None:
            raise ValueError(f"No observed reproduction transcript ({process['status']})")
        write_json(target / "transcript.json", tape)
        if process["status"] in {"timeout", "crash", "diagnostic_failure"}:
            raise ValueError(f"Reproduction process {process['status']}; retained attempted evidence")
        if (target / "replay.log").read_text(encoding="utf-8", errors="replace").splitlines().count(COMPLETION_MARKERS["campaign"]) != 1:
            raise ValueError("Reproduction process did not complete cleanup")
        return tape
    result = minimize(original, replay_actions, max_attempts=max_attempts, repeats=repeats)
    write_json(out / "reduction.json", result)
    fixture = {"schema": "cybersand-goblin-action-fixture-v1", "header": original["header"],
               "actions": result["actions"], "expected_failures": result["target_failures"],
               "reduction_status": result["status"], "original_transcript_sha256": result["original_transcript_sha256"]}
    write_json(out / "reproduction-fixture.json", fixture)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True, help="New disposable test output directory")
    parser.add_argument("--case", choices=("campaign", "interactive", "replay", "reduce", "reproduce", *TESTS), default="campaign")
    parser.add_argument("--fixture", choices=FIXTURES, default="material_playground")
    parser.add_argument("--policy", choices=POLICIES, default="CONTROL")
    parser.add_argument("--seed", type=int, default=13)
    parser.add_argument("--budget", type=int, default=64)
    parser.add_argument("--pacing-ms", type=int, default=0)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--replay", type=Path)
    parser.add_argument("--fixture-file", type=Path, help="A previously reduced bounded action fixture")
    parser.add_argument("--max-probes", type=int, default=24)
    parser.add_argument("--confirmations", type=int, default=2)
    parser.add_argument("--timeout-seconds", type=int, default=180)
    parser.add_argument("--retain-project", action="store_true", help="Keep the staged project after completion")
    args = parser.parse_args(argv)
    if not 1 <= args.budget <= 256 or not -(2**31) <= args.seed < 2**31:
        parser.error("budget must be 1..256; seed must be signed int32")
    if not 0 <= args.pacing_ms <= 3000 or not 30 <= args.timeout_seconds <= 240:
        parser.error("pacing must be 0..3000 ms; process timeout must be 30..240 seconds")
    if (args.case in ("replay", "reduce")) != (args.replay is not None):
        parser.error("--case replay/reduce requires --replay; other modes do not accept it")
    if (args.case == "reproduce") != (args.fixture_file is not None):
        parser.error("--case reproduce requires --fixture-file")
    if not 1 <= args.max_probes <= 64 or not 1 <= args.confirmations <= 3:
        parser.error("reduction supports 1..64 probes and 1..3 confirmations")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    try:
        godot = args.godot.resolve(strict=True)
        provenance = runtime_identity(godot)
        project = out / "project"
        snapshot = stage_project(project)
        provenance["project_files_sha256"] = snapshot["project_files_sha256"]
        write_json(out / "source-snapshot.json", snapshot)
        write_json(out / "provenance.json", provenance)
        graphical = args.graphical or args.case in ("interactive", "graphical")
        launch = {"fixture_id": args.fixture, "policy": args.policy, "seed": args.seed,
                  "budget": args.budget, "pacing_ms": args.pacing_ms,
                  "interactive": args.case == "interactive", "replay": args.case == "replay",
                  "reproduce": args.case == "reproduce",
                  "evidence_kind": "graphical_godot" if graphical else "headless_godot"}
        replay = None
        if args.replay:
            if args.replay.stat().st_size > 32 * 1024 * 1024:
                raise ValueError("Replay exceeds 32 MiB")
            replay = json.loads(args.replay.read_text(encoding="utf-8"))
            checked = verify(replay)
            if not checked["valid"]:
                raise ValueError("Selected transcript is invalid: " + str(checked["errors"]))
        reproduction = None
        if args.fixture_file:
            if args.fixture_file.stat().st_size > 32 * 1024 * 1024:
                raise ValueError("Reproduction fixture exceeds 32 MiB")
            reproduction = json.loads(args.fixture_file.read_text(encoding="utf-8"))
        profile = out / "profile"
        env = make_profile(profile, launch, provenance, replay if args.case == "replay" else None, reproduction)
        import_result = execute([str(godot), "--headless", "--path", str(project), "--editor", "--quit"],
                                env, out / "import.log", 240)
        write_json(out / "import-result.json", import_result)
        if import_result["status"] != "pass":
            print(json.dumps({"output": str(out), "status": "import_failure", "result": import_result}))
            if not args.retain_project:
                retain_source_and_remove_project(out, project)
            return 2
        if args.case == "reduce":
            result = reduce_gameplay(replay, out=out, godot=godot, project=project, provenance=provenance,
                                     timeout=args.timeout_seconds, max_attempts=args.max_probes,
                                     repeats=args.confirmations, graphical=graphical)
            if not args.retain_project:
                retain_source_and_remove_project(out, project)
            print(json.dumps({"output": str(out), "status": result["status"], "original_actions": result["original_actions"],
                              "reduced_actions": len(result["actions"]), "probes": len(result["attempts"])}))
            return 0 if result["status"] in ("reduced", "not_applicable") else 2
        cases = TESTS.get(args.case, ("campaign",))
        records = []
        for index, case in enumerate(cases):
            active_profile, active_env = profile, env
            if args.case in TESTS:
                active_profile = out / f"profile-{index:02d}-{case}"
                active_env = make_profile(active_profile, launch, provenance)
            command = [str(godot)] + ([] if graphical else ["--headless"])
            if graphical and os.name == "nt":
                command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
            command += ["--path", str(project)]
            if args.case == "interactive":
                command += ["res://goblin/goblin.tscn"]
            else:
                if case == "campaign":
                    script = "res://goblin/run_campaign.gd"
                elif case in ("goblin_adapter", "goblin_controller", "goblin_interactive"):
                    script = f"res://goblin/tests/test_{case.removeprefix('goblin_')}.gd"
                else:
                    script = f"res://tests/{case}.gd"
                command += ["--script", script]
            process_limit = None if args.case == "interactive" else args.timeout_seconds + (args.budget * args.pacing_ms // 1000)
            result = execute(command, active_env, out / f"{case}.log", process_limit)
            result["case"] = case
            log_text = (out / f"{case}.log").read_text(encoding="utf-8", errors="replace")
            if args.case != "interactive":
                result["completion_marker"] = COMPLETION_MARKERS[case]
                marker = COMPLETION_MARKERS[case]
                result["completion_observed"] = sum(line == marker if case == "campaign" else line.startswith(marker)
                                                    for line in log_text.splitlines()) == 1
                if result["status"] == "pass" and not result["completion_observed"]:
                    result["status"] = "incomplete_test"
            transcript, transcript_path = read_transcript(active_profile)
            if transcript is not None:
                write_json(out / "transcript.json", transcript)
                result["transcript_sha256"] = sha_file(transcript_path)
                result["summary"] = transcript.get("summary", {})
                readback = verify(transcript)
                write_json(out / f"{case}-independent-readback.json", readback)
                result["independent_readback"] = {key: readback[key] for key in ("valid", "errors", "independent_failures", "unreported_failures")}
                if result["status"] == "pass" and (not readback["valid"] or readback["unreported_failures"]):
                    result["status"] = "evidence_failure"
                if case == "campaign" and args.case != "interactive" and result["status"] == "pass" and transcript.get("summary", {}).get("termination") != "budget_complete":
                    result["status"] = "incomplete_evidence"
            elif case == "campaign" and result["status"] == "pass":
                result["status"] = "missing_transcript"
            records.append(result)
            write_json(out / "qualification.json", {"provenance": provenance, "tests": records,
                                                       "evidence_kind": launch["evidence_kind"]})
        passed = all(row["status"] == "pass" for row in records)
        print(json.dumps({"output": str(out), "passed": passed, "source_commit": provenance["source_commit"],
                          "source_dirty": provenance["source_dirty"], "tests": records}))
        if not args.retain_project:
            retain_source_and_remove_project(out, project)
        return 0 if passed else 2
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        write_json(out / "qualification-error.json", {"status": "qualification_error", "error": str(error)})
        print(json.dumps({"output": str(out), "status": "qualification_error", "error": str(error)}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
