#!/usr/bin/env python3
"""Read back INPUT011 actual-host modal/focus authority evidence.

This executes no engine. The original process must succeed and its raw log must
contain the complete trace. Source/runtime provenance remains an ordinary CI gate;
this verifier additionally binds its three consumed Godot files to the declared
Git source and the recorded runtime-read hashes.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys

from execution_policy import case_seconds, watchdog_microseconds, watchdog_seconds
from play_execution_contract import policy_matches, process_policy_matches, verify_log_policy

ROOT = Path(__file__).resolve().parents[2]
MODES = ("actor_picker", "environment_tuning", "pause_button", "focused_pause_button", "gui_focus", "window_focus")
LABELS = (*MODES, "bypass_negative")
RIGS = ("stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel")
OWNER = ("worker", "session", "bridge", "run_id", "epoch", "world_generation")
FILES = {"fixture_sha256": "godot/tests/play_input011_authority_case.gd",
         "main_sha256": "godot/scripts/main.gd",
         "panel_sha256": "godot/scripts/microscenario_panel.gd"}
MARKER = "PLAY_INPUT011_RESULT "


class EvidenceError(ValueError):
    pass


def need(condition: bool, reason: str) -> None:
    if not condition:
        raise EvidenceError(reason)


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def owner(state: dict) -> tuple:
    return tuple(state[key] for key in OWNER)


def completed(step: dict) -> bool:
    before, after = step["before"], step["after"]
    return (after["physics_tick"] == before["physics_tick"] + 1
            and after["bridge_step"] == before["bridge_step"] + 1)


def expected_waits() -> list[str]:
    result = ["first actual Main callback returns",
              "actual composed actor/native terrain acknowledgement",
              "automatic native and physical start"]
    for label in LABELS:
        result += [label + ": " + suffix for suffix in (
            "initial completed neutral step", "automatic held-input steps",
            "neutral release rearms", "fresh admitted physical steps", "genuine native progress")]
    return result


def validate(result: dict, source: str, rig: str, file_hashes: dict) -> dict:
    need("execution_policy" not in result or policy_matches(result["execution_policy"]),
         "execution_policy_mismatch")
    need(result["schema"] == "play-input011-v2" and rig in RIGS and result["rig"] == rig,
         "schema_or_rig")
    need(bool(re.fullmatch(r"[0-9a-f]{40}", source)) and result["source_revision"] == source,
         "source_identity")
    need(all(result[key] == value for key, value in file_hashes.items()), "consumed_source_identity")
    need(type(result["failures"]) is int and result["failures"] == 0 and type(result["assertions"]) is int
         and result["assertions"] >= 171, "reported_failure")
    need(result["real_host"] is True and result["automatic_callbacks"] is True
         and result["manual_physics_calls"] == 0 and result["retries"] == 0
         and result["physics_engine"] == "Rapier2D", "execution_scope")
    need(result["window_focus_seam"] is True and result["synthetic_window_notifications"] is True
         and result["actual_gui_focus_signals"] is True
         and result["cancellation_bypass_negative"] is True
         and all(result[key] is False for key in (
             "rendered_fps_measured", "physical_devices_qualified",
             "human_feel_qualified", "shader_startup_qualified")), "qualification_scope")
    need(0 < result["elapsed_usec"] <= watchdog_microseconds("complex_fixture_seconds"), "fixture_deadline")
    need(result["worker_joined"] is True and result["session_retired"] is True
         and 0 < result["teardown_usec"] <= watchdog_microseconds("operation_seconds"), "teardown")
    row = result["row"]
    need(row["completed"] is True and row["capture_overflow"] is False, "incomplete_capture")
    ack = row["first_main"]
    need(ack["limit_usec"] == watchdog_microseconds("main_ack_seconds")
         and 0 < ack["started_usec"] <= ack["acknowledged_usec"]
         <= ack["started_usec"] + watchdog_microseconds("main_ack_seconds")
         and ack["acknowledged_usec"] <= row["identity"]["time_usec"], "first_main_deadline")
    waits = row["waits"]
    need([wait["name"] for wait in waits] == expected_waits(), "wait_inventory")
    for wait in waits:
        need(wait["passed"] is True and wait["started_usec"] <= wait["ended_usec"] <= wait["deadline_usec"]
             and 0 < wait["deadline_usec"] - wait["started_usec"] <= watchdog_microseconds(
                 "main_ack_seconds" if wait["name"] == "first actual Main callback returns" else "operation_seconds"),
             "operation_deadline")
    identity = owner(row["identity"])
    need(bool(identity[3]) and all(type(identity[i]) is int and identity[i] != 0 for i in (0, 1, 2)),
         "owner_identity")  # Godot reference-counted ObjectIDs may be signed.
    records = row["records"]
    need(49 <= len(records) <= 512, "record_capacity")
    need({step["phase"] for step in records}
         == {label + "_" + stage for label in LABELS for stage in ("neutral", "held", "fresh")},
         "phase_inventory")
    need(len({(s["phase"], s["before"]["time_usec"], s["after"]["time_usec"]) for s in records})
         == len(records), "duplicate_record")
    previous = None
    for step in records:
        need(completed(step), "completed_rapier_step_missing")
        before, after = step["before"], step["after"]
        need(owner(before) == identity == owner(after) and not after["fault"]
             and before["time_usec"] <= after["time_usec"]
             and after["native_backend"] == "native-phased", "step_owner")
        need(all(isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
                 for value in after["move"] + after["position"]), "nonfinite_state")
        if previous is not None:
            need(before["time_usec"] >= previous["time_usec"]
                 and before["physics_tick"] >= previous["physics_tick"]
                 and before["native_tick"] >= previous["native_tick"], "record_order")
        previous = after
    transitions = row["transitions"]
    need([item["label"] for item in transitions] == list(LABELS)
         and [item["mode"] for item in transitions] == [*MODES, "actor_picker"], "transition_inventory")
    expected_move = [1.0, 0.0] if rig == "acrobat" else [0.0, -1.0]
    held_steps = fresh_steps = 0
    previous_end = row["identity"]["time_usec"]
    for index, transition in enumerate(transitions):
        negative = index == len(MODES)
        need(transition["negative"] is negative, "control_classification")
        before, after = transition["before"], transition["after"]
        need(owner(before) == identity == owner(after) == owner(transition["end"])
             and previous_end <= before["time_usec"] <= after["time_usec"]
             <= transition["end"]["time_usec"], "transition_owner")
        previous_end = transition["end"]["time_usec"]
        need(before["pending_edges"] == 2 and before["rearm"] is False
             and before["paused"] is False, "pending_input_missing")
        need(all(transition[key] is True for key in ("opened", "blocked", "closed"))
             and after["paused"] is False, "transition_path")
        need(all(after[key] == before[key] for key in (
            "main_callbacks", "physics_callbacks", "physics_tick", "bridge_step")), "callback_gap_missing")
        opened = transition["opened_state"]
        need(owner(opened) == identity
             and before["time_usec"] <= opened["time_usec"] <= after["time_usec"], "opened_state_custody")
        if transition["mode"] == "focused_pause_button":
            focus = transition["focused_button"]
            prior, guarded = focus["before"], focus["after_keyboard_toggle"]
            need(focus["focus_before"] is True and focus["focus_after"] is True
                 and focus["keyboard_context_allowed"] is False
                 and focus["keyboard_toggle_admitted"] is False, "focused_button_ownership")
            need(owner(prior) == identity == owner(guarded)
                 and before["time_usec"] <= prior["time_usec"] <= opened["time_usec"]
                 <= guarded["time_usec"] <= after["time_usec"]
                 and prior["pending_edges"] == 0 and opened["paused"] is True
                 and guarded["paused"] is True
                 and before["control_generation"] < prior["control_generation"]
                 < opened["control_generation"] == guarded["control_generation"]
                 < after["control_generation"], "focused_button_setter_not_applied")
        held = [step for step in records if step["phase"] == transition["label"] + "_held"]
        fresh = [step for step in records if step["phase"] == transition["label"] + "_fresh"]
        neutral = [step for step in records if step["phase"] == transition["label"] + "_neutral"]
        need(bool(neutral) and neutral[-1]["after"]["time_usec"] <= before["time_usec"]
             and neutral[-1]["after"]["move"] == [0.0, 0.0]
             and neutral[-1]["after"]["primary"] is False
             and neutral[-1]["after"]["pending_edges"] == 0, "initial_neutral_step_missing")
        need(held == transition["held"] and fresh == transition["fresh"], "record_custody")
        need(len(held) >= 3 and len(fresh) >= 3
             and after["time_usec"] <= held[0]["before"]["time_usec"]
             and held[-1]["after"]["time_usec"] <= fresh[0]["before"]["time_usec"]
             and fresh[-1]["after"]["time_usec"] <= transition["end"]["time_usec"], "phase_progress")
        held_steps += len(held)
        fresh_steps += len(fresh)
        if negative:
            need(transition["revoked"] is False and after["pending_edges"] == 2
                 and after["control_generation"] == before["control_generation"]
                 and transition["bypass_calls"] > 0, "cancellation_bypass_missing")
            need(transition["negative_reason"] == "stale_input_applied"
                 and transition["stale_applied"] is True and held[0]["after"]["primary"] is True
                 and held[0]["after"]["control_generation"] == before["control_generation"],
                 "negative_wrong_reason")
        else:
            need(transition["bypass_calls"] == 0 and transition["revoked"] is True
                 and after["pending_edges"] == 0 and after["rearm"] is True
                 and opened["pending_edges"] == 0
                 and after["control_generation"] > before["control_generation"], "immediate_revocation_missing")
            need(transition["stale_applied"] is False and all(
                step["after"]["rearm"] is True and not step["prepared"]
                and step["after"]["pending_edges"] == 0 and step["after"]["move"] == [0.0, 0.0]
                and step["after"]["primary"] is False
                and step["after"]["control_generation"] == after["control_generation"]
                for step in held), "stale_input_applied")
            refusal = transition["stale_receipt"]
            need(refusal["tested"] is True and refusal["admitted"] is False
                 and refusal["reason"] == "observation_not_issued" and refusal["rejected_delta"] == 1
                 and refusal["observed_tick"] <= refusal["tick"]
                 < refusal["observed_tick"] + refusal["lease_ticks"], "stale_authority_not_revoked")
        need(transition["expected_move"] == expected_move, "movement_mapping")
        for step in fresh:
            applied, prepared = step["after"], step["prepared"]
            need(bool(prepared) and prepared["move"] == expected_move == applied["move"]
                 and prepared["sequence"] == applied["sequence"]
                 and prepared["control_generation"] == applied["control_generation"]
                 and prepared["admitted_tick"] == step["before"]["physics_tick"]
                 and applied["accepted_commands"] > step["before"]["accepted_commands"]
                 and applied["control_generation"] > before["control_generation"]
                 and applied["rearm"] is False and applied["primary"] is False, "fresh_input_not_applied")
            if not negative:
                need(applied["control_generation"] == after["control_generation"],
                     "recovery_generation_changed")
        need(transition["end"]["native_tick"] > before["native_tick"], "native_progress_missing")
    return {"status": "passed", "source_revision": source, "rig": rig,
            "production_transitions": len(MODES), "actual_bypass_negatives": 1,
            "completed_held_steps": held_steps, "completed_fresh_steps": fresh_steps,
            "native_ticks_observed": transitions[-1]["end"]["native_tick"] - row["identity"]["native_tick"],
            "fixture_usec": result["elapsed_usec"], "teardown_usec": result["teardown_usec"],
            "physical_devices_qualified": False, "graphical_qualification": False}


def mirrored_step_change(result: dict, phase: str, change) -> None:
    transition = result["row"]["transitions"][0]
    step = transition[phase][0]
    target = next(item for item in result["row"]["records"] if item == step)
    change(step)
    change(target)


def adverse_controls(result: dict, source: str, rig: str, hashes: dict) -> list[dict]:
    transitions = lambda r: r["row"]["transitions"]
    changes = [
        ("wrong_source", "source_identity", lambda r: r.update(source_revision="0" * 40)),
        ("wrong_runtime_read_source", "consumed_source_identity", lambda r: r.update(main_sha256="0" * 64)),
        ("late_first_main", "first_main_deadline", lambda r: r["row"]["first_main"].update(
            acknowledged_usec=r["row"]["first_main"]["started_usec"] + watchdog_microseconds("main_ack_seconds") + 1)),
        ("failed_wait", "operation_deadline", lambda r: r["row"]["waits"][2].update(passed=False)),
        ("missing_transition", "transition_inventory", lambda r: transitions(r).pop(1)),
        ("duplicate_transition", "transition_inventory", lambda r: transitions(r).__setitem__(1, deepcopy(transitions(r)[0]))),
        ("callback_between_modal_edges", "callback_gap_missing", lambda r: transitions(r)[0]["after"].update(
            physics_callbacks=transitions(r)[0]["before"]["physics_callbacks"] + 1)),
        ("no_pending_input", "pending_input_missing", lambda r: transitions(r)[0]["before"].update(pending_edges=0)),
        ("old_edges_retained", "immediate_revocation_missing", lambda r: transitions(r)[0]["after"].update(pending_edges=2)),
        ("old_generation_retained", "immediate_revocation_missing", lambda r: transitions(r)[0]["after"].update(
            control_generation=transitions(r)[0]["before"]["control_generation"])),
        ("retired_primary_applied", "stale_input_applied", lambda r: mirrored_step_change(
            r, "held", lambda s: s["after"].update(primary=True))),
        ("missing_physical_completion", "completed_rapier_step_missing", lambda r: mirrored_step_change(
            r, "held", lambda s: s["after"].update(bridge_step=s["before"]["bridge_step"]))),
        ("neutral_only_recovery", "fresh_input_not_applied", lambda r: mirrored_step_change(
            r, "fresh", lambda s: s["after"].update(move=[0.0, 0.0]))),
        ("unbound_admitted_generation", "fresh_input_not_applied", lambda r: mirrored_step_change(
            r, "fresh", lambda s: s["prepared"].update(control_generation=-1))),
        ("expired_old_authority", "stale_authority_not_revoked", lambda r: transitions(r)[0]["stale_receipt"].update(
            tick=transitions(r)[0]["stale_receipt"]["observed_tick"] + transitions(r)[0]["stale_receipt"]["lease_ticks"])),
        ("no_native_progress", "native_progress_missing", lambda r: transitions(r)[0]["end"].update(
            native_tick=transitions(r)[0]["before"]["native_tick"])),
        ("wrong_negative_reason", "negative_wrong_reason", lambda r: transitions(r)[-1].update(negative_reason="timeout")),
        ("no_cancel_bypass", "cancellation_bypass_missing", lambda r: transitions(r)[-1].update(bypass_calls=0)),
        ("focused_keyboard_toggle_admitted", "focused_button_ownership", lambda r: transitions(r)[3]["focused_button"].update(keyboard_toggle_admitted=True)),
        ("focused_button_released_text_focus", "focused_button_ownership", lambda r: transitions(r)[3]["focused_button"].update(focus_after=False)),
        ("focused_button_skipped_setter", "focused_button_setter_not_applied", lambda r: transitions(r)[3]["opened_state"].update(control_generation=transitions(r)[3]["focused_button"]["before"]["control_generation"])),
        ("unjoined_worker", "teardown", lambda r: r.update(worker_joined=False)),
        ("physical_claim", "qualification_scope", lambda r: r.update(physical_devices_qualified=True)),
    ]
    outcomes = []
    for name, reason, change in changes:
        altered = deepcopy(result)
        change(altered)
        try:
            validate(altered, source, rig, hashes)
        except EvidenceError as error:
            need(str(error) == reason, f"adverse_wrong_reason:{name}:{error}")
            outcomes.append({"name": name, "rejected_for": reason})
        else:
            raise EvidenceError("adverse_false_pass:" + name)
    return outcomes


def check_process(process: dict, rig: str) -> None:
    need("status" in process and process["status"] == "passed"
         and type(process["returncode"]) is int and process["returncode"] == 0
         and process["timeout_seconds"] == case_seconds("test_play_input011_" + rig)
         and process_policy_matches(process)
         and not process.get("timed_out", False) and not process.get("timeout_kind")
         and not process.get("diagnostic_error") and not process.get("launch_error")
         and not process.get("capture_error") and not process.get("skip_messages")
         and not process.get("timeout_diagnostic_error")
         and process.get("inputs_unchanged", True) is True, "process_failed_or_incomplete")
    seconds = process.get("seconds", process.get("elapsed_seconds"))
    need(isinstance(seconds, (int, float)) and not isinstance(seconds, bool)
         and math.isfinite(seconds) and 0 < seconds <= case_seconds("test_play_input011_" + rig), "process_deadline")
    need(isinstance(process["command"], list)
         and "res://tests/test_play_input011_" + rig + ".gd" in process["command"],
         "process_case_mismatch")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--process-json", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--rig", choices=RIGS, required=True)
    parser.add_argument("--result", type=Path)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        need(bool(re.fullmatch(r"[0-9a-f]{40}", args.source)), "source_identity")
        original_log = args.log.read_bytes()
        original_process = args.process_json.read_bytes()
        log = original_log.decode("utf-8")
        executed_policy = verify_log_policy(log, args.source)
        need("ERROR:" not in log and not re.search(r"\bskipped\b|^\s*SKIP\b", log, re.I | re.M),
             "log_failed_or_skipped")
        markers = [line[len(MARKER):] for line in log.splitlines() if line.startswith(MARKER)]
        need(len(markers) == 1, "log_result_inventory")
        result = json.loads(markers[0])
        if args.result:
            need(json.loads(args.result.read_text(encoding="utf-8")) == result, "log_result_mismatch")
        process = json.loads(original_process)
        if "source_revision" in process:
            need(process["source_revision"] == args.source, "process_source_mismatch")
        need("execution_policy" not in process or policy_matches(process["execution_policy"]), "execution_policy_mismatch")
        if "results" in process:
            rows = [value for value in process["results"] if value["name"] == "test_play_input011_" + args.rig]
            need(len(rows) == 1, "process_inventory")
            process = rows[0]
        check_process(process, args.rig)
        if "source_revision" in process:
            need(process["source_revision"] == args.source, "process_source_mismatch")
        if "stdout_sha256" in process:
            need(process["stdout_sha256"] == digest(original_log), "process_log_digest")
        hashes = {}
        for field, path in FILES.items():
            canonical = subprocess.check_output(["git", "-C", str(ROOT), "show", args.source + ":" + path],
                                                timeout=watchdog_seconds("operation_seconds"))
            # Historical readback uses that exact Git revision, never a newer
            # checkout's source bytes. These paths have explicit eol=lf rules.
            hashes[field] = digest(canonical)
        reduced = validate(result, args.source, args.rig, hashes)
        if args.self_test:
            reduced["adverse_controls"] = adverse_controls(result, args.source, args.rig, hashes)
            process_controls = []
            for name, change, expected in (
                ("post_summary_crash", lambda p: p.update(returncode=-1073741819), "process_failed_or_incomplete"),
                ("missing_status", lambda p: p.pop("status"), "process_failed_or_incomplete"),
                ("process_timeout", lambda p: p.update(timed_out=True), "process_failed_or_incomplete"),
                ("process_over_bound", lambda p: p.update(seconds=case_seconds("test_play_input011_" + args.rig) + .001,
                    elapsed_seconds=case_seconds("test_play_input011_" + args.rig) + .001), "process_deadline"),
                ("wrong_case", lambda p: p.update(command=["godot", "--quit"]), "process_case_mismatch"),
            ):
                altered = deepcopy(process)
                change(altered)
                try:
                    check_process(altered, args.rig)
                except EvidenceError as error:
                    need(str(error) == expected, "process_adverse_wrong_reason:" + name)
                    process_controls.append({"name": name, "rejected_for": expected})
                else:
                    raise EvidenceError("process_adverse_false_pass:" + name)
            reduced["process_adverse_controls"] = process_controls
        need(args.log.read_bytes() == original_log and args.process_json.read_bytes() == original_process,
             "original_evidence_changed")
        reduced.update(execution_policy=executed_policy, log_sha256=digest(original_log), process_sha256=digest(original_process),
                       raw_result_sha256=digest(markers[0].encode("utf-8")), consumed_source_sha256=hashes,
                       verifier_sha256=digest(Path(__file__).read_bytes()))
        if args.output:
            need(not args.output.exists(), "output_already_exists")
            args.output.write_text(json.dumps(reduced, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(reduced, sort_keys=True))
        return 0
    except (EvidenceError, KeyError, TypeError, ValueError, OSError, subprocess.SubprocessError) as error:
        print("PLAY_INPUT011_VERIFICATION_FAILED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
