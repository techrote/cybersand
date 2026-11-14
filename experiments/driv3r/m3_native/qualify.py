"""M3 bounded native A1 recovery smoke: *real* Workbench material, logical cursor rewind.

This intentionally performs ONE native paint action (not neural inference), one
brush-up BACKTRACK_CURSOR, fresh native readbacks, STOP and independent native
replay. It neither claims a native cursor teleport nor implements material Undo.
D1A/B/D2 and accepted M1 bytes remain unchanged.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import time
import traceback

from experiments.driv3r.native import NativeSession, verify_observation
from experiments.driv3r.providers import permitted
from experiments.driv3r.d_common.v1.verify import SCHEMA, validate_bundle

ROOT = Path(__file__).resolve().parents[3]
M1_SHA = "8fa90de6be209ed0b7bd125039e6ec8b332fb1a6"
M1_SCHEMA_SHA = "ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d"
PROTOCOL = "cybersand.driv3r.d-common/1"
START = [12, 24]
DESTINATION = [12, 25]
FOCUS = [0, 0, 96, 96]
SCENARIO = {
    "id": "m3-single-native-recovery-001",
    "fixture": "wall-v1", "World": [512, 512],
    "start": START, "destination": DESTINATION, "paint_material": 58,
    "guidance": "positive_u16le_only", "policy": "deterministic_single_choice",
    "recovery": "BACKTRACK_CURSOR_brush_up_no_material_restore",
    "max_native_paint_actions": 1, "max_recovery_decisions": 1,
    "allow_native_undo": False, "allow_model": False,
}


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def digest(value) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def _assert(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError(message)


def _git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True, timeout=20).strip()


def _blob(root: Path, path: str, fmt: str) -> dict:
    _assert(not Path(path).is_absolute() and ".." not in Path(path).parts, "Unsafe evidence path")
    data = (root / path).read_bytes()
    return {"path": path, "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data), "format": fmt}


def _dump(root: Path, relative: str, value) -> dict:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as f:
        f.write(canonical(value))
        f.flush()
        os.fsync(f.fileno())
    return _blob(root, relative, "json")


def world(observation: dict) -> dict:
    return {
        "id": observation["world_id"],
        "generation": int(observation["generation"]),
        "revision": int(observation["revision"]),
        "tick": int(observation["tick"]),
        "material_sha256": observation["material_sha256"],
        "world_material_sha256": observation["world_material_sha256"],
        "width_cells": 512, "height_cells": 512,
    }


def guidance(root: Path, episode: str) -> dict:
    """A small positive-only scalar tile, never a native material permission."""
    tile = root / "guide"
    tile.mkdir(exist_ok=False)
    values = [max(0, 65535 - 1800*((x-4)**2+(y-5)**2))
              for y in range(8) for x in range(8)]
    (tile/"positive.u16le").write_bytes(struct.pack("<64H", *values))
    return {
        "protocol": PROTOCOL, "type": "guidance", "record_id": "guide-001",
        "episode_id": episode, "sequence": 0,
        "label": "Positive scalar target near first legal Workbench movement",
        "frame": [8, 20, 8, 8], "source_kind": "procedural",
        "purpose": "soft_positive_preference",
        "values": _blob(root, "guide/positive.u16le", "u16le"),
        "display": None, "encoding": "u16le_higher_is_better_zero_is_neutral",
        "speckle": {"seed": 570, "radius_cells": 8, "centre_density": 1.0,
                    "hardness": 0.2, "gradient_length": 0.8},
        "hysteresis": {"exit_below": 10000, "reenter_at_or_above": 20000},
        "native_material_authority": False, "authoring_seed": 570,
        "canvas_size": [512, 512], "optional_channels": [],
    }


def observation_record(root: Path, source: dict, episode: str, seq: int,
                       record_id: str, cursor: list[int], history: list[list[int]],
                       prior_action: str | None = None,
                       prior_receipt: str | None = None) -> dict:
    _assert(source["focus"] == FOCUS, "Unexpected real native focus")
    _assert(source["width"] == 96 and source["height"] == 96,
            "M3 pilot requires qualified fixed 96 crop")
    _assert(len(source["materials"]) == 96*96, "Native material crop incomplete")
    _assert(not source.get("retired"), "Observed native World was retired")
    return {
        "protocol": PROTOCOL, "type": "observation", "record_id": record_id,
        "episode_id": episode, "sequence": seq, "objective": "Draw one safe cell, then brush-up backtrack preserving that cell",
        "subgoal": "Paint adjacent legal cell" if prior_action is None else
                   "Retain the real native edit while backing the logical cursor",
        "world": world(source), "cursor": cursor.copy(), "target": DESTINATION.copy(),
        "guidance_ref": "guide-001", "last_action_ref": prior_action,
        "last_native_receipt_ref": prior_receipt,
        "local_material": _blob(root, "native/" + source["material_path"], "i32le"),
        "local_crop": [0, 0, 96, 96],
        "host_geometry": {"selected_wall_offset_cells": 4,
                          "target_manhattan_cells": abs(cursor[0]-12)+abs(cursor[1]-25)},
        "history_sha256": digest(history),
        "rules": {"focus": FOCUS, "allowed_materials": [0, 58], "forbidden_materials": [28],
                  "protected_rectangles": [[40, 40, 8, 8]]},
        "budget": {"decisions_remaining": 1 if prior_action is None else 0,
                   "material_cell_budget": 1 if prior_action is None else 0,
                   "wall_seconds_remaining": 600},
        "feedback_views": [],
        "guidance_channel_handling": {"unsupported_policy": "reject_unsupported",
                                      "used_channel_ids": [], "ignored_channels": []},
    }


class RecoveryCursor:
    """Host-owned logical motion history. No native brush-down rewind or teleport."""
    def __init__(self):
        self.cursor = START.copy()
        self.history = [START.copy()]
        self.recoveries = 0

    def advance(self, destination: list[int]) -> None:
        _assert(self.cursor == START and destination == DESTINATION and len(self.history) == 1,
                "Only one bounded forward action is admitted")
        self.cursor = destination.copy()
        self.history.append(destination.copy())

    def backtrack(self) -> tuple[list[int], list[int]]:
        _assert(len(self.history) == 2 and self.recoveries == 0,
                "No second or unanchored recovery allowed")
        before = self.cursor.copy()
        self.history.pop()
        self.cursor = self.history[-1].copy()
        self.recoveries += 1
        _assert(self.cursor == START, "Cursor did not return to saved anchor")
        return before, self.cursor.copy()


def replay_original(godot: Path, manifest: Path, source_sha: str,
                    root: Path, expected_world_sha: str, action: dict) -> dict:
    """Fresh independent process, reapplying the exact original action operation."""
    with NativeSession(ROOT, godot, root/"replay-native", source_sha,
                       runtime_manifest=manifest) as native:
        reset = native.reset("wall-v1")
        _assert(reset["status"] == "completed", "Independent native replay fixture refused")
        before = native.observe()
        _assert(before["status"] == "completed", "Replay native observation refused")
        source = before["observation"]
        original = world(source)
        _assert(source["materials"][25*96+12] == 0, "Replay fixture differs at target")
        _assert(original["world_material_sha256"] != expected_world_sha,
                "Replay input already contains the edited material")
        operation = [action["operation"]]
        applied = native.apply(operation, expected_generation=source["generation"],
                               expected_revision=source["revision"], expected_tick=source["tick"],
                               action_id="m3-independent-replay-001", cell_budget=1)
        _assert(applied["status"] == "completed", "Independent native replay action refused")
        _assert(applied["receipt"]["actual_changed_cells"] == 1 and
                applied["receipt"]["readback_matches"] is True,
                "Independent replay receipt fails changed-cell/readback gate")
        current = native.observe()
        _assert(current["status"] == "completed", "Replay fresh readback refused")
        _assert(current["observation"]["world_material_sha256"] == expected_world_sha,
                "Independent native replay material bytes differ from first execution")
        _assert(current["observation"]["materials"][25*96+12] == 58,
                "Native replay final target material mismatch")
        stopped = native.stop("M3 independent replay Stop")
        _assert(stopped["status"] == "stopped", "Replay Stop failed")
    return {
        "source_sha": source_sha, "expected_world_sha256": expected_world_sha,
        "actual_world_sha256": current["observation"]["world_material_sha256"],
        "native_actual_changed_cells": applied["receipt"]["actual_changed_cells"],
        "same_native_material_bytes": True,
        "source_action_sha256": digest(action), "brush_up_recovery_is_logical": True,
        "replay_process_exit_code": json.loads(
            (root/"replay-native/cleanup.json").read_text())["exit_code"],
    }


def qualify(args) -> dict:
    root = args.output.resolve()
    _assert(not root.exists(), "Evidence directory already exists")
    _assert(_git("rev-parse", "HEAD") == args.source_sha, "Exact source checkout mismatch")
    _assert(_git("merge-base", "--is-ancestor", M1_SHA, "HEAD") == "",
            "M1 ancestry command returned unexpected output")
    _assert(hashlib.sha256(SCHEMA.read_bytes()).hexdigest() == M1_SCHEMA_SHA,
            "Owner-approved M1 schema bytes changed")
    _assert(args.runtime_manifest.is_file(), "Pinned native manifest missing")
    root.mkdir(parents=True)
    started = time.monotonic()
    checks: list[dict] = []
    def check(label, value):
        checks.append({"label": label, "passed": bool(value)})
        _dump(root, f"checks/{len(checks):02d}-{label}.json",
              {"passed":bool(value), "source_sha":args.source_sha})
        _assert(bool(value), label)

    try:
        episode = "m3-one-real-action"
        guide = guidance(root, episode)
        op = {"shape":"rectangle","material":58,"x0":12,"y0":25,"x1":12,"y1":25}
        operation = [op]
        catalog = [
            {"id":"MOVE_DOWN_ONE","path":[START,DESTINATION],
             "operations":operation,"cell_budget":1},
            {"id":"STOP","path":[],"operations":[],"cell_budget":0},
        ]
        catalog.sort(key=lambda v:v["id"])
        legal_sha = digest(catalog)
        catalog_blob = _dump(root, "host-offered-legal-catalog.json", catalog)
        cursor = RecoveryCursor()
        with NativeSession(ROOT, args.godot, root/"native", args.source_sha,
                           runtime_manifest=args.runtime_manifest) as native:
            reset = native.reset("wall-v1")
            check("real_reset", reset["status"] == "completed")
            fresh = native.observe()
            check("fresh_native_observation", fresh["status"] == "completed")
            before = fresh["observation"]
            check("native_focus_and_material_auth", before["focus"] == FOCUS
                  and before["allowed_materials"] == [58]
                  and before["materials"][25*96+12] == 0
                  and permitted(before,12,25))
            obs1 = observation_record(root,before,episode,1,"obs-001",
                                      cursor.cursor,cursor.history)
            # Model cannot create coordinates: deterministic host-selected finite catalog.
            result = native.apply(operation, expected_generation=before["generation"],
                                  expected_revision=before["revision"],
                                  expected_tick=before["tick"],
                                  action_id="MOVE_DOWN_ONE", cell_budget=1)
            check("actual_native_action", result["status"] == "completed"
                  and result["receipt"]["actual_changed_cells"] == 1
                  and result["receipt"]["expected_changed_cells"] == 1
                  and result["receipt"]["readback_matches"] is True
                  and result["receipt"]["receipts_reconstruct_materials"] is True
                  and len(result["receipt"]["native_receipts"]) >= 1)
            cursor.advance(DESTINATION)
            again = native.observe()
            check("actual_post_edit_readback", again["status"] == "completed"
                  and again["observation"]["world_material_sha256"] ==
                     result["observation"]["world_material_sha256"]
                  and again["observation"]["materials"][25*96+12] == 58
                  and again["observation"]["world_material_sha256"] !=
                     before["world_material_sha256"])
            after = again["observation"]
            receipt_artifact = _dump(root,"receipts/paint-001.json",
                                     {"status":result["status"],"receipt":result["receipt"]})
            action = {
                "protocol":PROTOCOL, "type":"action", "record_id":"action-001",
                "episode_id":episode, "sequence":2,
                "observation_ref":"obs-001", "world_precondition":world(before),
                "candidate_set_sha256":legal_sha,
                "legal_candidate_set_sha256":legal_sha,
                "candidate_id":"MOVE_DOWN_ONE", "actor":"deterministic",
                "mode":"add_material",
                "cursor_before":START.copy(), "cursor_after":DESTINATION.copy(),
                "path":[START.copy(),DESTINATION.copy()],"brush_state":"add",
                "guidance_ref":"guide-001", "operation_sha256":digest(operation),
                "model_decision_ref":None,
                "predicted_effects":{"changed_cells":1,"guidance_is_soft":True},
                "execution_status":"committed",
                "native_receipt_ref":"native-receipt-001",
                "native_receipt_artifact":receipt_artifact,
                "world_postcondition":world(after),
                # Not part of D-COMMON action record; retained separately for replay.
            }
            obs2 = observation_record(root,after,episode,3,"obs-002",
                                      cursor.cursor,cursor.history,
                                      "action-001","native-receipt-001")
            _assert(obs2["world"]["world_material_sha256"] != obs1["world"]["world_material_sha256"],
                    "Native action did not paint any cells")
            previous, returned = cursor.backtrack()
            unchanged = native.observe()
            check("native_material_persisted_during_brush_up_backtrack",
                  unchanged["status"] == "completed"
                  and unchanged["observation"]["world_material_sha256"] ==
                      after["world_material_sha256"]
                  and unchanged["observation"]["material_sha256"] ==
                      after["material_sha256"]
                  and unchanged["observation"]["materials"][25*96+12] == 58
                  and previous == DESTINATION and returned == START)
            recovered = unchanged["observation"]
            reversal = {
                "protocol":PROTOCOL, "type":"reversal", "record_id":"reversal-001",
                "episode_id":episode, "sequence":4,
                "mechanism":"BACKTRACK_CURSOR",
                "source_action_ref":"action-001","history_anchor_ref":"obs-001",
                "cursor_before":previous,"cursor_after":returned,
                "brush_lifted":True,"preserve_material_edits":True,
                "before_world":world(after),"after_world":world(recovered),
                "native_undo_receipt_ref":None,"native_undo_receipt_artifact":None,
                "actual_material_cells_changed":0,"status":"applied",
                "reason_code":"brush_up_host_cursor_only_preserves_native_material",
            }
            obs3 = observation_record(root,recovered,episode,5,"obs-003",
                                      cursor.cursor,cursor.history,
                                      "action-001","native-receipt-001")
            # Negative control: stale authority cannot mutate the real World.
            stale = native.apply([{"shape":"rectangle","material":58,
                                   "x0":12,"y0":26,"x1":12,"y1":26}],
                                 expected_generation=before["generation"],
                                 expected_revision=before["revision"],
                                 expected_tick=before["tick"],
                                 action_id="M3_STALE_REFUSAL",cell_budget=1)
            check("stale_action_refused_no_native_edit",
                  stale["status"] == "refused" and
                  stale["receipt"]["actual_changed_cells"] == 0)
            stop = native.stop("M3 bounded native smoke explicit Stop")
            check("host_stop_and_material_preservation",
                  stop["status"] == "stopped"
                  and stop["observation"]["retired"]
                  and stop["observation"]["world_material_sha256"] ==
                      recovered["world_material_sha256"])
            late = native.apply([{"shape":"rectangle","material":58,
                                  "x0":12,"y0":26,"x1":12,"y1":26}],
                                expected_generation=before["generation"],
                                expected_revision=recovered["revision"],
                                expected_tick=recovered["tick"],
                                action_id="M3_AFTER_STOP_REFUSAL",cell_budget=1)
            check("post_stop_action_refused_without_write",
                  late["status"] == "refused"
                  and late["receipt"]["actual_changed_cells"] == 0)
        cleanup = json.loads((root/"native/cleanup.json").read_text())
        check("native_session_reaped",cleanup["exit_code"] == 0)
        replay_action={"operation":op,"candidate_id":"MOVE_DOWN_ONE",
                       "world_before_sha256":before["world_material_sha256"]}
        replay = replay_original(args.godot, args.runtime_manifest, args.source_sha,
                                 root, recovered["world_material_sha256"], replay_action)
        check("actual_independent_replay",replay["same_native_material_bytes"]
              and replay["replay_process_exit_code"] == 0)
        _dump(root,"replay-result.json",replay)
        records = [guide,obs1,action,obs2,reversal,obs3]
        world_blob = _blob(root,"native/"+recovered["world_material_path"],"i32le")
        provenance={
            "protocol":PROTOCOL,"type":"provenance","record_id":"provenance-001",
            "episode_id":episode,"sequence":6,"evidence_class":"native",
            "source_commit":args.source_sha,"source_tree":_git("rev-parse","HEAD^{tree}"),
            "base_commit":M1_SHA,"interface_schema_sha256":M1_SCHEMA_SHA,
            "experiment_id":"m3-a1-one-native-action","arm":"A1_native_smoke",
            "split":"pilot","scenario_sha256":digest(SCENARIO),
            "algorithm":{"name":"m3_native_backtrack_smoke","version":"1",
                         "seed":570,"recipe_sha256":digest(SCENARIO)},
            "model":None,"native":world_blob,"native_receipts":[receipt_artifact],
            "guidance_ref":"guide-001",
            "episode_record_refs":[v["record_id"] for v in records],
            "final_world":world(recovered),"outcome":"success",
            "metrics":{"native_paint_actions":1,"native_actual_cells_changed":1,
                       "cursor_backtracks":1,"logical_cursor_restored":True,
                       "native_material_preserved_after_backtrack":True,
                       "native_undo_executed":False,
                       "first_consequential_material_divergence":"one_real_cell",
                       "duration_seconds":round(time.monotonic()-started,3)},
            "replay":"pass","artifacts":[
                _blob(root,"native/"+before["png_path"],"png"),
                _blob(root,"native/"+after["png_path"],"png"),
                _blob(root,"native/"+recovered["png_path"],"png")
            ]
        }
        records.append(provenance)
        check("complete_five_record_contract_with_real_material_custody",
              validate_bundle(records,evidence_root=root)["evidence_bytes_verified"])
        with (root/"events.jsonl").open("xb") as f:
            for row in records:
                f.write(canonical(row)+b"\n")
        check("final_native_source_and_permissions_unchanged",
              hashlib.sha256(SCHEMA.read_bytes()).hexdigest() == M1_SCHEMA_SHA)
        summary={
            "schema":"driv3r-m3-native-smoke-v1",
            "source_sha":args.source_sha,"frozen_m1_sha":M1_SHA,
            "m1_schema_sha256":M1_SCHEMA_SHA,
            "status":"PASS",
            "qualification":"REAL_NATIVE_WORKBENCH_ONE_ACTION_AND_BRUSH_UP_RECOVERY",
            "model_used":False,"model_comparisons_performed":False,
            "real_native_paint_actions":1, "actual_native_material_cells_changed":1,
            "reversal":"BACKTRACK_CURSOR",
            "recovery_scope":"HOST_LOGICAL_CURSOR_ONLY_MATERIAL_PRESERVED",
            "real_material_undo_qualified":False,
            "replay":"PASS_INDEPENDENT_NATIVE_PROCESS",
            "checked_native_receipt":receipt_artifact,
            "original_world_material_sha256":before["world_material_sha256"],
            "final_world_material_sha256":recovered["world_material_sha256"],
            "tests":checks,"elapsed_seconds":round(time.monotonic()-started,3),
            "not_qualified":["long_horizon","visual_d1","real_native_undo",
                             "parallel_A1_A2_A3","different_world_dimensions"],
        }
        _dump(root,"summary.json",summary)
        print(json.dumps({"m3_status":"PASS","source_sha":args.source_sha,
                          "real_cells_changed":1,"native_replay":True,
                          "scope":"one native paint + brush-up logical backtrack"},sort_keys=True),flush=True)
        return summary
    except BaseException as exc:
        # Original partial receipts, readbacks and child cleanup remain on disk.
        failure={"schema":"driv3r-m3-native-smoke-failure-v1",
                 "source_sha":args.source_sha,"status":"FAILED",
                 "exception":f"{type(exc).__name__}: {exc}",
                 "traceback":traceback.format_exc(),"checks":checks,
                 "elapsed_seconds":round(time.monotonic()-started,3)}
        _dump(root,"failure.json",failure)
        print(json.dumps({"m3_status":"FAIL","reason":failure["exception"]}),flush=True)
        raise


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--godot",type=Path,required=True)
    p.add_argument("--runtime-manifest",type=Path,required=True)
    p.add_argument("--source-sha",required=True)
    p.add_argument("--output",type=Path,required=True)
    x=p.parse_args()
    _assert(len(x.source_sha)==40, "Missing full source SHA")
    qualify(x)


if __name__=="__main__":
    main()
