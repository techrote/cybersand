#!/usr/bin/env python3
"""Run one fixed nine-action retained-clock diagnostic in an isolated profile.

This is a prospective hosted diagnostic, separate from successor qualification.
It records an oracle-applicability candidate or a negative result; neither is a
production defect claim. Only the committed fixed entrypoint may be executed.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
from pathlib import Path
import struct
import subprocess

import replay_identity
import run_goblin as runner
from campaign_queue import check_stage
from owned_process import read_log_prefix
from verify_transcript import verify

BASE_GAME_SOURCE = "5ee5dffc78d59a721f62be49fd51d24b870556c7"
GAME_SCRIPT = "godot/goblin/diagnostics/retained_clock.gd"
ADAPTER_SCRIPT = "godot/goblin/goblin_adapter.gd"
ADAPTER_BASE_BLOB = "aef80d5878ce80d298c029cae76a9fb16624fdf4"
ADAPTER_OBSERVATION_BLOB = "7f0fa3fbcab7de85350d0ca99154adc615d75cbf"
ADAPTER_BASE_SHA256 = "36681265aa48a647f0cc6dfc1d31977604bc9a59cf74b082a7f3beb336bfd64d"
ADAPTER_OBSERVATION_SHA256 = "70fe8fe199e123f1ed28fdf9a4539194c4b08c6f595b052097a74c0de5300cfb"
ENTRYPOINT = "res://goblin/diagnostics/retained_clock.gd"
GODOT_SHA256 = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
MARKER = "GOBLIN_RETAINED_CLOCK_COMPLETE "
MAX_REPORT_BYTES = 16 * 1024 * 1024
CONTROL = [{"id": "play", "args": {"ticks": 16}}, {"id": "pause", "args": {}},
           {"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}]
VARIANT = CONTROL[:2] + [{"id": "response_mode", "args": {"mode": "LA-EVENT-OFF"}}] + CONTROL[2:]


def adapter_delta(base: bytes, current: bytes) -> dict:
    """Admit only the independently reviewed exact read-only observation delta."""
    first, last = hashlib.sha256(base).hexdigest(), hashlib.sha256(current).hexdigest()
    if first != ADAPTER_BASE_SHA256 or last != ADAPTER_OBSERVATION_SHA256:
        raise ValueError("Adapter bytes differ from the pinned base or exact reviewed observation change")
    difference = "".join(difflib.unified_diff(base.decode("utf-8").splitlines(keepends=True),
                                           current.decode("utf-8").splitlines(keepends=True),
                                           fromfile="base5ee/" + ADAPTER_SCRIPT, tofile=ADAPTER_SCRIPT))
    return {"path": ADAPTER_SCRIPT, "base_sha256": first, "new_sha256": last,
            "base_git_blob": ADAPTER_BASE_BLOB, "new_git_blob": ADAPTER_OBSERVATION_BLOB,
            "diff": difference, "diff_sha256": hashlib.sha256(difference.encode("utf-8")).hexdigest(),
            "scope": "Bounded read-only queue/count/current-owner evidence inside the existing observation mutex"}


def clean_source() -> dict:
    if runner.git("status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Diagnostic execution requires clean committed source")
    changes = runner.git("diff", "--name-only", BASE_GAME_SOURCE, "HEAD", "--", "godot").splitlines()
    if changes != sorted([GAME_SCRIPT, ADAPTER_SCRIPT]):
        raise ValueError("Only the fixed diagnostic and exact reviewed adapter observation delta may differ")
    if runner.git("cat-file", "-t", BASE_GAME_SOURCE) != "commit":
        raise ValueError("Pinned game source is not available")
    path = runner.ROOT / GAME_SCRIPT
    if path.is_symlink() or not path.is_file():
        raise ValueError("Fixed diagnostic source is absent or linked")
    adapter = runner.ROOT / ADAPTER_SCRIPT
    if adapter.is_symlink() or not adapter.is_file():
        raise ValueError("Fixed adapter source is absent or linked")
    if (runner.git("rev-parse", BASE_GAME_SOURCE + ":" + ADAPTER_SCRIPT) != ADAPTER_BASE_BLOB
            or runner.git("rev-parse", "HEAD:" + ADAPTER_SCRIPT) != ADAPTER_OBSERVATION_BLOB):
        raise ValueError("Committed adapter objects do not match the reviewed observation change")
    base_bytes = subprocess.run(["git", "show", BASE_GAME_SOURCE + ":" + ADAPTER_SCRIPT], cwd=runner.ROOT,
                                check=True, capture_output=True, timeout=15).stdout
    observation_delta = adapter_delta(base_bytes, adapter.read_bytes())
    return {"source_commit": runner.git("rev-parse", "HEAD"),
            "source_tree": runner.git("rev-parse", "HEAD^{tree}"), "source_dirty": False,
            "base_game_source": BASE_GAME_SOURCE, "base_game_tree": runner.git("rev-parse", BASE_GAME_SOURCE + "^{tree}"),
            "game_changes": changes, "diagnostic_sha256": runner.sha_file(path),
            "base_game_files_unchanged": False, "other_base_game_files_unchanged": True,
            "product_and_oracle_logic_unchanged": True, "adapter_observation_delta": observation_delta,
            "comparison": "Exact tracked Git comparison; only the added fixed diagnostic and hash-pinned read-only adapter observation delta differ"}


def bounded_json(path: Path, limit: int = MAX_REPORT_BYTES) -> dict:
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= limit:
        raise ValueError("Evidence is missing, linked or outside its byte bound")
    value = json.loads(path.read_bytes())
    if not isinstance(value, dict):
        raise ValueError("Evidence root is not an object")
    return value


def capture_cells(capture: dict, observation: dict) -> list[int]:
    if not isinstance(capture, dict) or not isinstance(observation, dict):
        raise ValueError("Capture/observation shape is invalid")
    first, last, receipt, admission = (capture.get(k, {}) for k in
                                      ("source_before", "source_after", "native_receipt", "admission"))
    if not all(isinstance(value, dict) for value in (first, last, receipt, admission)):
        raise ValueError("Capture source/receipt shape is invalid")
    values = capture.get("materials")
    if (capture.get("source_matches") is not True or "error" in capture
            or capture.get("region") != [48, 48, 48, 48] or receipt.get("region") != [48, 48, 48, 48]
            or capture.get("count") != 2304 or not isinstance(values, list) or len(values) != 2304
            or any(type(value) is not int or not 0 <= value <= 131 for value in values)
            or admission.get("status") != "queued" or receipt.get("status") != "completed"
            or receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld"
            or type(admission.get("operation_id")) is not int
            or receipt.get("operation_id") != admission["operation_id"]
            or receipt.get("observed_generation") != first.get("generation")
            or first.get("paused") is not True or last.get("paused") is not True
            or first.get("failed") is not False or last.get("failed") is not False):
        raise ValueError("Regional native capture lacks the required actual operation proof")
    for key in ("generation", "revision", "tick"):
        if (type(first.get(key)) is not int or first[key] < 0
                or first[key] != last.get(key) or first[key] != receipt.get(key)
                or first[key] != observation.get("native", {}).get(key)):
            raise ValueError("Regional capture does not match its actual decision-boundary source")
    if hashlib.sha256(struct.pack("<2304i", *values)).hexdigest() != capture.get("material_sha256"):
        raise ValueError("Regional raw material bytes do not match their recorded digest")
    return values


def automatic_bundle(profile: Path, raw: dict) -> dict:
    variant = raw["cases"][1]
    if variant.get("hypothesis_reproduced") is not True:
        return {"required": False}
    recorded = variant.get("automatic_candidate_bundle", {})
    if recorded.get("path") != "user://goblin/candidate-002.json" or recorded.get("exists") is not True:
        raise ValueError("Automatic capture does not name the fixed second campaign archive")
    paths = list(profile.rglob("candidate-002.json"))
    if len(paths) != 1:
        raise ValueError("The actual automatic candidate archive is missing or ambiguous")
    actual = bounded_json(paths[0], 32 * 1024 * 1024)
    digest = runner.sha_file(paths[0])
    if (digest != recorded.get("sha256") or actual.get("schema") != "cybersand-goblin-reproduction-bundle-v1"
            or actual.get("captured_automatically") is not True or actual.get("gameplay_defect_confirmed") is not False
            or actual.get("original_tape") != variant.get("transcript")
            or actual.get("exact_provenance") != raw.get("actual_source_provenance")
            or actual.get("reduced_tape") != {} or actual.get("classification") != "unresolved_observation"):
        raise ValueError("Automatic candidate bytes or original tape/source custody differ")
    return {"required": True, "path": paths[0].relative_to(profile).as_posix(),
            "bytes": paths[0].stat().st_size, "sha256": digest, "original_tape_exact": True}


def disarmed_receipt(receipt) -> bool:
    return (isinstance(receipt, dict) and receipt.get("armed") is False
            and receipt.get("burst_queued") is False and receipt.get("stream_enabled") is False
            and isinstance(receipt.get("origin"), list) and len(receipt["origin"]) == 2
            and all(type(value) in (int, float) and value == 0 for value in receipt["origin"])
            and all(type(receipt.get(key)) is int and receipt[key] == 0
                    for key in ("material", "attempted", "inserted", "blocked", "stream_ticks")))


def actor_free(observation: dict) -> bool:
    if not isinstance(observation, dict):
        return False
    source, native = observation.get("source", {}), observation.get("native", {})
    if not isinstance(source, dict) or not isinstance(native, dict):
        return False
    if (observation.get("actor_ids") != [] or observation.get("actors") != [] or source.get("authored") != []
            or not disarmed_receipt(source.get("receipt"))):
        return False
    count = source.get("pending_commands")
    if type(count) is not int or not 0 <= count <= 16:
        return False
    proof = source.get("queue_evidence")
    if (not isinstance(proof, dict) or proof.get("schema") != "cybersand-goblin-source-queue-v1"
            or proof.get("copy_complete") is not True or type(proof.get("command_count")) is not int
            or proof["command_count"] != count or type(proof.get("owner_generation")) is not int
            or type(native.get("generation")) is not int or native["generation"] < 0
            or proof["owner_generation"] != native["generation"] or type(proof.get("owner_paused")) is not bool
            or native.get("failed") is not False
            or not disarmed_receipt(proof.get("current_source_receipt"))):
        return False
    if count > 0 and (observation.get("paused") is not True or native.get("paused") is not True
                      or proof["owner_paused"] is not True):
        return False
    commands = proof.get("commands")
    return (isinstance(commands, list) and len(commands) == count
            and all(isinstance(command, dict) and set(command) == {"command", "material", "origin"}
                    and command.get("command") == "stop" and type(command.get("material")) is int
                    and command["material"] == 0 and isinstance(command.get("origin"), list)
                    and len(command["origin"]) == 2
                    and all(type(value) in (int, float) and value == 0 for value in command["origin"])
                    for command in commands))


def adjudicate(raw: dict, provenance: dict, custody: dict) -> dict:
    if (raw.get("schema") != "goblin-retained-clock-diagnostic-v1"
            or raw.get("base_game_source") != BASE_GAME_SOURCE
            or raw.get("actual_source_provenance") != provenance
            or raw.get("instrumentation_sha256") != custody["diagnostic_sha256"]
            or raw.get("adapter_instrumentation_sha256") != custody["adapter_observation_delta"]["new_sha256"]
            or raw.get("prescribed_action_limit") != 9 or raw.get("production_defect_claim") is not False
            or raw.get("gameplay_defect_confirmed") is not False):
        raise ValueError("Diagnostic identity or bounded scope differs")
    cases = raw.get("cases")
    if not isinstance(cases, list) or len(cases) != 2:
        raise ValueError("The independent control and variant did not both complete")
    expected = [58 if x < 2 or x >= 46 or y < 2 or y >= 46 else
                2 if 16 <= x < 24 and 8 <= y < 16 else 0 for y in range(48) for x in range(48)]
    summaries = []
    for index, (case, prescribed) in enumerate(zip(cases, (CONTROL, VARIANT), strict=True)):
        tape = case.get("transcript", {})
        rows = tape.get("steps", [])
        if (len(rows) != len(prescribed) or tape.get("header", {}).get("provenance") != provenance
                or case.get("prescribed_actions") != prescribed
                or any(row.get("action") != action or row.get("status") != "completed"
                       or row.get("admission", {}).get("accepted") is not True for row, action in zip(rows, prescribed))):
            raise ValueError("Observed native tape is not the exact completed prescribed action sequence")
        checked = verify(tape)
        if not checked["valid"] or checked.get("unreported_failures"):
            raise ValueError("The actual tape fails independent structural/evidence validation")
        if case.get("source_evidence_kind") != "actual_observation_embedded_owner_mutex_snapshot":
            raise ValueError("The diagnostic does not identify its observation-owned source proof")
        if not actor_free(case.get("initial_observation", {})):
            raise ValueError("Initial absence of an emitting source lacks its actual queue/owner proof")
        for row in rows:
            for side in ("before", "after"):
                if not actor_free(row[side]):
                    raise ValueError("An actual action observation lacks its atomic absent/inert source proof")
        captures = case.get("captures", {})
        initial = capture_cells(captures.get("authored_start", {}), case.get("initial_observation", {}))
        evolved = capture_cells(captures.get("paused_after_play", {}), rows[1]["after"])
        reopened = capture_cells(captures.get("reopened_authored_start", {}), rows[-1]["after"])
        if (initial != expected or reopened != expected or evolved == expected
                or evolved.count(2) != 64 or evolved.count(58) != 368
                or sum(i // 48 for i, material in enumerate(evolved) if material == 2) <= 736):
            raise ValueError("Independent authored/Sand movement/Reopen material relationship was not established")
        if not case.get("checks") or any(value is not True for value in case["checks"].values()):
            raise ValueError("The diagnostic did not establish every reported precondition")
        failures = [{"step": row["index"], "id": assertion["id"]}
                    for row in rows for assertion in row.get("assertions", []) if assertion.get("status") == "fail"]
        if index == 0:
            if case.get("status") != "qualified_control" or failures or checked.get("independent_failures"):
                raise ValueError("The positive-tick control is not qualified")
        else:
            retained = capture_cells(captures.get("retained_after_response", {}), rows[2]["after"])
            if retained != evolved:
                raise ValueError("Ordinary response change did not retain the actually evolved material plane")
            reproduced = case.get("hypothesis_reproduced") is True
            if reproduced:
                if (case.get("status") != "hypothesis_reproduced"
                        or failures != [{"step": 4, "id": "authored_reopen_materials"}]
                        or not case.get("automatic_candidate_bundle", {}).get("exists")):
                    raise ValueError("Claimed oracle hypothesis lacks its exact failure or automatic capture")
            elif case.get("status") != "not_reproduced" or failures or checked.get("independent_failures"):
                raise ValueError("Variant has an unresolved or different observation")
        summaries.append({"case": case["case"], "actions": len(rows), "status": case["status"],
                          "original_termination": tape["summary"]["termination"], "original_failures": failures,
                          "independent_readback": checked})
    return {"status": "diagnostic_complete", "hypothesis_reproduced": cases[1].get("hypothesis_reproduced", False),
            "classification": cases[1]["classification"], "cases": summaries, "actual_completed_actions": 9,
            "production_gameplay_defect_confirmed": False,
            "scope": "Actual bounded diagnostic result; not a general qualification pass or unchanged-invariant correction"}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--reuse-import-cache", action="store_true")
    args = parser.parse_args(argv)
    output = args.out.resolve()
    if output.is_relative_to(runner.ROOT.resolve()):
        raise ValueError("Diagnostic evidence must be outside source")
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "cybersand-goblin-retained-clock-qualification-v1", "status": "initializing",
              "base_game_source": BASE_GAME_SOURCE, "driver_sha256": runner.sha_file(Path(__file__)),
              "prescribed_action_limit": 9, "game_wall_seconds": 90, "import_wall_seconds": 120,
              "memory_limit_mib": 3072, "stages": [], "production_defect_claim": False}
    project = None
    code = 2

    def persist():
        runner.write_json(output / "retained-clock-qualification.json", report)

    def stage(name, command, env, seconds):
        process = runner.execute(command, env, output / (name + ".log"), seconds, memory_limit_mib=3072)
        report["stages"].append({"name": name, "process": process})
        runner.write_json(output / (name + ".process.json"), process)
        persist()
        if process.get("interrupted"):
            raise KeyboardInterrupt
        if process["status"] != "pass" or process["surviving_owned_pids"]:
            raise ValueError("Owned diagnostic process did not complete: " + name + ": " + process["status"])

    try:
        custody = clean_source()
        report["source_custody"] = custody
        godot = args.godot.resolve(strict=True)
        if runner.sha_file(godot) != GODOT_SHA256:
            raise ValueError("Diagnostic requires the exact pinned Linux Godot runtime")
        provenance = runner.runtime_identity(godot)
        if provenance["platform"] != "linux" or provenance["source_commit"] != custody["source_commit"]:
            raise ValueError("Diagnostic platform/source differs")
        project = output / "project"
        snapshot = runner.stage_project(project, reuse_import_cache=args.reuse_import_cache)
        provenance["project_files_sha256"] = snapshot["project_files_sha256"]
        provenance["replay_identity"] = replay_identity.build(provenance, project, snapshot["files"])
        runner.write_json(output / "source-snapshot.json", snapshot)
        runner.write_json(output / "provenance.json", provenance)
        report["provenance"] = provenance
        profile = output / "profile"
        env = runner.make_profile(profile, {"fixture_id": "conservation_cell", "policy": "CONTROL", "seed": 13,
                                            "budget": 9, "pacing_ms": 0, "evidence_kind": "headless_godot"}, provenance)
        persist()
        if not args.reuse_import_cache:
            stage("import", [str(godot), "--headless", "--path", str(project), "--editor", "--quit"], env, 120)
        check_stage(project, snapshot)
        if clean_source() != custody:
            raise ValueError("Source changed before diagnostic execution")
        stage("diagnostic", [str(godot), "--headless", "--path", str(project), "--script", ENTRYPOINT], env, 90)
        log = read_log_prefix(output / "diagnostic.log")
        if sum(line.startswith(MARKER) for line in log.splitlines()) != 1:
            raise ValueError("The fixed completion marker was not observed exactly once")
        files = list(profile.rglob("retained-clock-diagnostic.json"))
        if len(files) != 1:
            raise ValueError("Expected one fixed diagnostic output in the isolated profile")
        raw = bounded_json(files[0])
        report["raw_report"] = {"path": files[0].relative_to(output).as_posix(),
                                "bytes": files[0].stat().st_size, "sha256": runner.sha_file(files[0])}
        report["adjudication"] = adjudicate(raw, provenance, custody)
        report["automatic_candidate_custody"] = automatic_bundle(profile, raw)
        check_stage(project, snapshot)
        if clean_source() != custody:
            raise ValueError("Source changed during diagnostic execution")
        report["status"] = "diagnostic_complete"
        code = 0
    except KeyboardInterrupt:
        report.update(status="cancelled", operator_cancelled=True)
        code = 130
    except (OSError, ValueError, KeyError, TypeError, AssertionError, subprocess.SubprocessError) as error:
        report.update(status="incomplete_or_unresolved", error=str(error))
    finally:
        if project is not None:
            try:
                runner.retain_source_and_remove_project(output, project)
                archive = output / "executed-game-source.zip"
                if not archive.is_file():
                    raise ValueError("Executed source archive was not retained")
                report["executed_source_archive"] = {"path": archive.name, "sha256": runner.sha_file(archive), "bytes": archive.stat().st_size}
            except (OSError, ValueError) as error:
                report["retention_error"] = str(error)
                if code == 0:
                    report["status"] = "incomplete_or_unresolved"
                    code = 2
        persist()
        print("GOBLIN_RETAINED_CLOCK_QUALIFICATION " + json.dumps({"status": report["status"], "exit_code": code,
              "production_defect_claim": False}), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
