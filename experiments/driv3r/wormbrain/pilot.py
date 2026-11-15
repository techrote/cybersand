"""DRIV3R-WORM-001: real pinned resident d1-2B Q8 steering native paint.

One source-fenced native Workbench world per arm. The Q8 brain selects legal
one-cell ink movements, material-preserving brush-up recovery or STOP. The
model never supplies native permissions or arbitrary cell coordinates.
Gallery PNG/GIF are derived from original native stored-material readbacks
and model-selected actions; they are not Godot framebuffer screenshots.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import time
import traceback

from experiments.driv3r.backend import PINS, parse_choice_response
from experiments.driv3r.qualify import new_backend
from experiments.driv3r.m3_history.native import HistorySession
from experiments.driv3r.m3_history.qualify import _record_reversal
from experiments.driv3r.m3_native.qualify import (
    ROOT, M1_SHA, M1_SCHEMA_SHA, PROTOCOL, START, _assert, _dump,
    _blob, canonical, digest, world, guidance, observation_record,
)
from experiments.driv3r.m4.compare import draw, legal, replay
from experiments.driv3r.d_common.v1.verify import SCHEMA, validate_bundle

MODES = ("free", "soft")
FRAME = [8, 20, 32, 32]
SEED = 570
MAX_DECISIONS = 36
MAX_PAINT = 36
MAX_RECOVERIES = 8
MAX_WALL_SECONDS = 4400
WHIMS = (
    "Try a curious bend, if it feels right.",
    "Consider holding a direction for a moment.",
    "A tiny sideways wobble might be interesting.",
    "Follow your nose, not a destination.",
    "A kink or odd corner would be quite wormlike.",
    "Sometimes a simple straight line is the strangest choice.",
)
DIRS = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0)}
SCENARIO = {
    "id": "driv3r-wormbrain-001",
    "native_fixture": "wall-v1",
    "source_native_world": [512, 512],
    "focus": [0, 0, 96, 96],
    "start": START,
    "seed": SEED,
    "guidance_modes": list(MODES),
    "max_model_decisions": MAX_DECISIONS,
    "max_native_one_cell_edits": MAX_PAINT,
    "max_logical_recoveries": MAX_RECOVERIES,
    "host_legality": "existing_M4_native_empty_one_cell_and_protection",
    "no_global_destination": True,
    "no_deterministic_post_recovery_paint": True,
    "training": False,
}


def guide_for(root: Path, episode: str, mode: str):
    if mode not in MODES:
        raise ValueError("Invalid worm guidance arm")
    result = guidance(root, episode)
    x0, y0, w, h = FRAME
    values = []
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if mode == "free":
                value = 0  # neutral: a wandering worm, not a compulsory path
            else:
                # A low-stakes, curved scent ribbon, not a target or wall mask.
                center = 28 + 5 * math.sin((x - 10) / 4.5)
                falloff = math.exp(-0.5 * ((y - center) / 5.0)**2)
                ahead = max(0.0, min(1.0, (x - 8) / 32))
                value = round(58000 * falloff * (0.5 + 0.5 * ahead))
            values.append(max(0, min(65535, value)))
    file = root / "guide/positive.u16le"
    file.write_bytes(struct.pack("<" + "H" * len(values), *values))
    result["frame"] = FRAME.copy()
    result["values"] = _blob(root, "guide/positive.u16le", "u16le")
    result["label"] = ("Neutral worm scent (no target)" if mode == "free"
                       else "Curving optional pheromone ribbon (soft preference)")
    result["speckle"]["radius_cells"] = 32
    result["authoring_seed"] = SEED
    return result, values


def scent(values, point):
    x, y = point
    x0, y0, w, h = FRAME
    if not(x0 <= x < x0+w and y0 <= y < y0+h):
        return 0
    return values[(y-y0)*w + x-x0]


def candidate_legal(before, cursor, history, recoveries, paints):
    """Original native-derived host menu, independent of guidance mode."""
    original = legal(before, cursor, history, recoveries, paints)
    if paints >= MAX_PAINT:
        return [c for c in original if c["id"] == "STOP"]
    return original


def turn_kind(heading, move):
    if move == heading:
        return "straight"
    if DIRS[move][0] == -DIRS[heading][0] and DIRS[move][1] == -DIRS[heading][1]:
        return "reverse"
    if DIRS[heading][0]*DIRS[move][1]-DIRS[heading][1]*DIRS[move][0] > 0:
        return "right turn"
    return "left turn"


def prompt_for(mode, values, before, cursor, history, offered, index, heading):
    # Neither arm is given a destination or a goal-distance oracle.
    order = [c["id"] for c in offered]
    random.Random(SEED*100 + index).shuffle(order)
    catalog = {c["id"]: c for c in offered}
    descriptions = {}
    numeric = {}
    for ident in order:
        c = catalog[ident]
        if ident == "STOP":
            descriptions[ident] = (
                "Curl up and end this worm drawing. Choose if genuinely finished "
                "or no appealing escape remains; there is no fixed destination."
            )
        elif c["kind"] == "backtrack":
            descriptions[ident] = (
                "Lift pen, wriggle back one earlier cursor position. All drawn ink stays."
            )
        elif c["kind"] == "branch_relocate":
            descriptions[ident] = (
                "Lift pen and squirm back to the saved birth branch. Ink stays."
            )
        else:
            point = c["path"][-1]
            direction = ident.removeprefix("MOVE_")
            soft = scent(values, point)
            descriptions[ident] = (
                f"Extend a REAL ink stroke one legal cell {direction} to {point}, "
                f"{turn_kind(heading, direction)} from heading {heading}; "
                f"optional pheromone scent {soft}/65535."
            )
            numeric[ident] = {"destination": point, "soft_scent_u16": soft,
                              "relative_turn": turn_kind(heading, direction)}
    whim = WHIMS[random.Random(SEED*1000 + index).randrange(len(WHIMS))]
    state = {
        "identity": "Small eccentric CyberSand line-worm, not a route optimiser",
        "mission": "Make a lively, odd, continuing ink line by choosing one offered move at a time.",
        "worm_turn": index,
        "max_turns": MAX_DECISIONS,
        "position": cursor,
        "heading": heading,
        "recent_positions": history[-7:],
        "already_inked_cells_this_run": len(history)-1,
        "current_impulse": whim,
        "scent_rule": "Soft artistic preference ONLY. Zero means neutral; never a wall or requirement.",
        "scent_field_sha256": before.get("_worm_guide_sha", None),
        "native_world_material_sha256": before["world_material_sha256"],
        "native_epoch": [before["generation"], before["revision"], before["tick"]],
        "eligible_moves": order,
        "candidate_hints": numeric,
        "safety": "Host alone validates legality, protected materials and native actions.",
    }
    questions = {"worm_move": {
        "type": "choice",
        "instructions": (
            "You are a slightly deranged but harmless line-steering worm brain. "
            "Choose exactly ONE available control. Prefer continuing a wiggly, "
            "sometimes purposeful, sometimes curious ink trail. Vary bends and "
            "stretches; explore, get distracted, respond to scent if you want, "
            "and recover when trapped. Do not chase an imaginary destination. "
            "STOP when the drawing has genuinely ended, not just because a turn "
            "looks odd. A legal ink movement paints ONE new cell; recovery lifts "
            "the brush and never erases it."
        ),
        "criteria": descriptions,
    }}
    return state, questions, order


def ask(backend, mode, guide, values, before, cursor, history, offered, index, heading):
    state, questions, order = prompt_for(mode, values, before, cursor, history,
                                         offered, index, heading)
    state["scent_field_sha256"] = guide["values"]["sha256"]
    original = backend.decide(canonical(state).decode(), questions, timeout_seconds=90)
    if original.get("status") != "ok":
        raise RuntimeError(f"Original resident Q8 worm choice failed: {original.get('status')} "
                           f"{original.get('error')}")
    selected = parse_choice_response(original["raw_response"], "worm_move", order)
    option = next(c for c in offered if c["id"] == selected["candidate_id"])
    note = {
        "index": index,
        "mode": mode,
        "exact_candidate_ids_in_presented_order": order,
        "host_legal_candidate_sha256": digest(offered),
        "presented_order_sha256": digest(order),
        "model_state": state, "questions": questions,
        "original_response": original,
        "parsed_choice": selected,
        "chosen_candidate": option["id"],
        "presentation_sha256": digest({"state": state, "questions": questions,
                                      "ordered_candidates": order}),
    }
    return option, note


def observe(root, episode, native, cursor, history, heading, guide,
            prior, prior_receipt, records, paint_count, decision):
    answer = native.observe()
    _assert(answer["status"] == "completed" and answer["m3"]["cursor"] == cursor,
            "Native Workbench observation / actual host logical cursor mismatch")
    before = answer["observation"]
    entry = observation_record(root, before, episode, len(records),
                               f"worm-obs-{len(records):04d}",
                               cursor, history, prior, prior_receipt)
    entry["objective"] = "Draw an odd, steerable line-worm trail; no arrival target"
    entry["subgoal"] = "Select the next safe ink movement or brush-up worm recovery"
    entry["target"] = None
    entry["host_geometry"] = {
        "worm_heading": heading,
        "worm_painted_cells": paint_count,
        "worm_turn": decision,
        "world_focus": [0, 0, 96, 96],
        "scent_mode": guide["label"],
    }
    entry["budget"] = {
        "decisions_remaining": max(0, MAX_DECISIONS-decision),
        "material_cell_budget": max(0, MAX_PAINT-paint_count),
        "wall_seconds_remaining": MAX_WALL_SECONDS,
    }
    records.append(entry)
    return before, entry


def stop_action(episode, records, index, cursor, before, obs, note):
    return {
        "protocol": PROTOCOL, "type": "action",
        "record_id": f"worm-stop-{index:04d}", "episode_id": episode,
        "sequence": len(records),
        "observation_ref": obs["record_id"],
        "world_precondition": world(before),
        "candidate_set_sha256": note["presentation_sha256"],
        "legal_candidate_set_sha256": note["host_legal_candidate_sha256"],
        "candidate_id": "STOP", "actor": "d1", "mode": "stop",
        "cursor_before": cursor.copy(), "cursor_after": cursor.copy(),
        "path": [cursor.copy()], "brush_state": "up",
        "guidance_ref": "guide-001", "operation_sha256": None,
        "model_decision_ref": f"worm-model-{index:04d}",
        "predicted_effects": {"actual_changed_cells": 0},
        "execution_status": "selected", "native_receipt_ref": None,
        "native_receipt_artifact": None, "world_postcondition": None,
    }


def gallery(root, initial, final, actions, traces):
    """Plot actual native material/cursor decisions, not Godot framebuffer graphics."""
    from PIL import Image, ImageDraw
    crop = 96
    native_grid = final["materials"]
    start_grid = initial["materials"]
    _assert(len(native_grid) == crop*crop and len(start_grid) == crop*crop,
            "Visualisation requires real 96x96 native material readbacks")
    points = {tuple(a["point"]) for a in actions}
    _assert(len(points) == len(actions), "Worm must not paint an already painted cell")
    for (x,y) in points:
        _assert(start_grid[y*crop+x] == 0 and native_grid[y*crop+x] == 58,
                "Worm gallery point is not confirmed by original native readback")
    root.mkdir(parents=True, exist_ok=False)
    small = Image.new("RGB", (crop, crop), (14, 17, 28))
    pix = small.load()
    for y in range(crop):
        for x in range(crop):
            mat = native_grid[y*crop+x]
            if mat != 0:
                pix[x,y] = (46, 61, 75) if mat != 58 else (106, 87, 65)
    for x,y in points:
        pix[x,y] = (242, 194, 69)
    small.putpixel(tuple(START), (73, 198, 217))
    endpoint = traces[-1]["cursor_after"] if traces else START
    small.putpixel(tuple(endpoint), (253, 97, 129))
    enlarged = small.resize((768,768), resample=Image.Resampling.NEAREST)
    enlarged.save(root/"native-material.png")
    xs = [START[0],*[p[0] for p in points]]
    ys = [START[1],*[p[1] for p in points]]
    x0, x1 = max(0,min(xs)-6), min(crop,max(xs)+7)
    y0, y1 = max(0,min(ys)-6), min(crop,max(ys)+7)
    zoom = small.crop((x0,y0,x1,y1))
    zoom = zoom.resize(((x1-x0)*16,(y1-y0)*16), resample=Image.Resampling.NEAREST)
    zoom.save(root/"worm-closeup.png")
    # Small honest animation: frames are reconstructed from the *actual original
    # model-selected paint/recovery trace*, not simulated extra worm movements.
    drawn = set()
    frames = []
    position = tuple(START)
    action_index = 0
    for trace in traces:
        if trace["choice"].startswith("MOVE_"):
            point = tuple(actions[action_index]["point"])
            action_index += 1
            drawn.add(point)
        position = tuple(trace["cursor_after"])
        frame = Image.new("RGB", (crop, crop), (14, 17, 28))
        f = frame.load()
        for y in range(crop):
            for x in range(crop):
                mat = start_grid[y*crop+x]
                if mat:
                    f[x,y] = (46, 61, 75) if mat != 58 else (106, 87, 65)
        for p in drawn:
            f[p] = (242, 194, 69)
        f[tuple(START)] = (73, 198, 217)
        f[position] = (253, 97, 129)
        frames.append(frame.resize((384,384), Image.Resampling.NEAREST))
    if frames:
        frames[0].save(root/"worm-motion.gif", save_all=True,
                       append_images=frames[1:], duration=240, loop=0,
                       optimize=False)
    return [
        _blob(root.parent, "gallery/native-material.png", "png"),
        _blob(root.parent, "gallery/worm-closeup.png", "png"),
        *([_blob(root.parent, "gallery/worm-motion.gif", "bin")] if frames else []),
    ]


def qualify(args):
    _assert(args.mode in MODES, "Unknown wormbrain mode")
    root = args.output.resolve()
    _assert(not root.exists(), "Cannot overwrite original wormbrain evidence")
    head = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                                   text=True, timeout=20).strip()
    _assert(head == args.source_sha, "Native worm source checkout differs from exact SHA")
    subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor",
                    M1_SHA, "HEAD"], check=True, timeout=20)
    _assert(hashlib.sha256(SCHEMA.read_bytes()).hexdigest() == M1_SCHEMA_SHA,
            "Owner-frozen M1 schema modified")
    model_manifest = json.loads(args.model_runtime_manifest.read_text())
    model = model_manifest["model_identity"]
    pin = PINS["model"]
    _assert(all(model[k] == pin[k] for k in ("repository","revision",
                                            "sha256","bytes","quantization")),
            "Resident d1-2B Q8 identity is not source pinned")
    root.mkdir(parents=True)
    episode = f"driv3r-worm-{args.mode}-seed570"
    guide, values = guide_for(root, episode, args.mode)
    records, actions, receipts, artifacts = [guide], [], [], []
    traces, cursor, history = [], START.copy(), [START.copy()]
    direction, prior, prior_receipt = "E", None, None
    recoveries = 0
    ending = "budget_exhausted"
    initial = final = None
    started = time.monotonic()
    backend = new_backend(model_manifest, root/"resident-inference",
                          threads=2, ctx_size=4096, batch_size=2048)
    try:
        with backend:
            with HistorySession(ROOT, args.godot, root/"native", args.source_sha,
                                runtime_manifest=args.runtime_manifest) as native:
                _assert(native.reset("wall-v1")["status"] == "completed",
                        "Worm native fixture reset refused")
                first = native.observe()
                _assert(first["status"] == "completed"
                        and first["m3"]["cursor"] == START,
                        "Worm native initial cursor is not at source-checked spawn")
                initial = first["observation"]
                _assert(native.save_branch("wormbirth", START)["status"] == "completed",
                        "Original worm branch anchor save refused")
                for i in range(MAX_DECISIONS):
                    _assert(time.monotonic() - started < MAX_WALL_SECONDS,
                            "Original worm model/native bounded deadline exceeded")
                    before, obs = observe(root, episode, native, cursor, history,
                                          direction, guide, prior, prior_receipt,
                                          records, len(actions), i)
                    offered = candidate_legal(before, cursor, history,
                                              recoveries, len(actions))
                    _assert(any(c["id"] == "STOP" for c in offered)
                            and len({c["id"] for c in offered}) == len(offered),
                            "Host offered no valid STOP or duplicate options")
                    choice, decision = ask(backend, args.mode, guide, values,
                                           before, cursor, history, offered,
                                           i, direction)
                    source_artifact = _dump(root, f"model/turn-{i:02d}.json", decision)
                    artifacts.append(source_artifact)
                    trace = {
                        "index": i, "choice": choice["id"], "kind": choice["kind"],
                        "cursor_before": cursor.copy(),
                        "source_world_sha256": before["world_material_sha256"],
                        "host_legal_sha256": decision["host_legal_candidate_sha256"],
                        "option_order_sha256": decision["presented_order_sha256"],
                        "candidate_ids": [c["id"] for c in offered],
                        "original_model_artifact": source_artifact["path"],
                        "heading_before": direction,
                    }
                    traces.append(trace)
                    if choice["id"] == "STOP":
                        records.append(stop_action(episode, records, i, cursor,
                                                   before, obs, decision))
                        ending = "stop"
                    elif choice["kind"] == "paint_and_move":
                        target = choice["path"][-1]
                        _assert(len(actions) < MAX_PAINT,
                                "Worm overran original bounded paint count")
                        record = draw(root, episode, native, records, actions,
                                      receipts, artifacts, guide,
                                      {"from": cursor.copy(), "to": target.copy(),
                                       "candidate": choice["id"], "index": i},
                                      history, f"WORM_{args.mode}_{i}",
                                      obs, before, model=True,
                                      legal_hash=decision["host_legal_candidate_sha256"],
                                      present_hash=decision["presentation_sha256"])
                        prior, prior_receipt = record["record_id"], record["native_receipt_ref"]
                        direction = choice["id"].removeprefix("MOVE_")
                        cursor = target.copy()
                    elif choice["kind"] in ("backtrack", "branch_relocate"):
                        _assert(prior is not None and recoveries < MAX_RECOVERIES,
                                "Recovery without original paint or beyond bounded limit")
                        old = cursor.copy()
                        if choice["kind"] == "backtrack":
                            target = history[-2].copy()
                            response = native.cursor_move(cursor, target)
                            mechanism = "BACKTRACK_CURSOR"
                            history.pop()
                        else:
                            target = START.copy()
                            response = native.relocate_branch("wormbirth", cursor)
                            mechanism = "RELOCATE_TO_BRANCH"
                            history.append(target.copy())
                        _assert(response["status"] == "completed"
                                and response["receipt"]["actual_changed_cells"] == 0
                                and response["observation"]["world_material_sha256"] ==
                                    before["world_material_sha256"]
                                and response["m3"]["cursor"] == target,
                                "Worm brush-up recovery changed native material/cursor unexpectedly")
                        records.append(_record_reversal(
                            episode, len(records), f"WORM_{i}", mechanism,
                            prior, obs["record_id"], before,
                            response["observation"], old, target))
                        cursor = target.copy()
                        recoveries += 1
                    else:
                        raise RuntimeError("Unregistered original model-selected control")
                    post = native.observe()
                    _assert(post["status"] == "completed" and post["m3"]["cursor"] == cursor,
                            "Fresh post-worm-step native readback failed")
                    trace["cursor_after"] = cursor.copy()
                    trace["world_after_sha256"] = post["observation"]["world_material_sha256"]
                    trace["material_changed"] = (
                        post["observation"]["world_material_sha256"] !=
                        before["world_material_sha256"]
                    )
                    trace["heading_after"] = direction
                    if ending == "stop":
                        break
                last = native.observe()
                _assert(last["status"] == "completed", "Worm terminal native observation failed")
                final = last["observation"]
                artifacts.append(_blob(root, "native/"+final["png_path"], "png"))
                _assert(native.stop("Source-fenced wormbrain bounded Stop")["status"]=="stopped",
                        "Native worm final Stop refused")
        cleanup=json.loads((root/"native/cleanup.json").read_text())
        _assert(cleanup["exit_code"] == 0, "Original native worm process not reaped")
        replayed = replay(root, args, actions, final["world_material_sha256"])
        _dump(root, "native-replay.json", replayed)
        _dump(root, "original-decisions.json", traces)
        _dump(root, "original-guide.json", guide)
        gallery_artifacts = gallery(root/"gallery", initial, final, actions, traces)
        artifacts.extend(gallery_artifacts)
        tree = subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD^{tree}"],
                                       text=True, timeout=15).strip()
        modelid = model_manifest["model_identity"]
        backendid = model_manifest["backend_identity"]
        provenance = {
            "protocol":PROTOCOL, "type":"provenance",
            "record_id":"provenance-001", "episode_id":episode,
            "sequence":len(records), "evidence_class":"native",
            "source_commit":args.source_sha, "source_tree":tree,
            "base_commit":M1_SHA, "interface_schema_sha256":M1_SCHEMA_SHA,
            "experiment_id":"driv3r-wormbrain-001",
            "arm":f"WORM_{args.mode.upper()}", "split":"pilot",
            "scenario_sha256":digest(SCENARIO),
            "algorithm":{"name":"wormbrain_steering","version":"1",
                         "seed":SEED,"recipe_sha256":digest(SCENARIO)},
            "model":{"repo":modelid["repository"],"revision":modelid["revision"],
                     "weights_sha256":modelid["sha256"],
                     "backend_sha256":backendid["binary_sha256"]},
            "native":_blob(root, "native/"+final["world_material_path"], "i32le"),
            "native_receipts":receipts,
            "guidance_ref":"guide-001",
            "episode_record_refs":[rec["record_id"] for rec in records],
            "final_world":world(final), "outcome":ending,
            "metrics":{"model_decisions":len(traces),
                       "native_material_edits":len(actions),
                       "brush_up_recoveries":recoveries,
                       "visible_line_length_cells":len(actions),
                       "terminal_reason":ending},
            "replay":"pass","artifacts":artifacts,
        }
        records.append(provenance)
        valid=validate_bundle(records, evidence_root=root)
        _assert(valid["evidence_bytes_verified"],
                "Worm native/source/original receipt custody missing")
        _dump(root, "bundle-validation.json", valid)
        with (root/"original-events.jsonl").open("xb") as stream:
            for rec in records:
                stream.write(canonical(rec)+b"\n")
        _assert(backend.shutdown_record and backend.shutdown_record["process_reaped"],
                "Original resident Q8 not fully reaped")
        model_files = [json.loads((root/f"model/turn-{i:02d}.json").read_text())
                       for i in range(len(traces))]
        _assert(len({m["original_response"]["pid"] for m in model_files}) == 1,
                "Worm did not preserve one resident model PID")
        report = {
            "schema":"driv3r-wormbrain-native-pilot/1",
            "status":"PASS" if actions else "VALID_NO_INK",
            "mode":args.mode,"source_sha":args.source_sha,
            "seed":SEED,"model_decisions":len(traces),
            "native_painted_cells":len(actions),
            "brush_up_recoveries":recoveries,
            "termination":ending,
            "initial_world_sha256":initial["world_material_sha256"],
            "final_world_sha256":final["world_material_sha256"],
            "initial_host_legal_catalog_sha256":(
                traces[0]["host_legal_sha256"] if traces else None),
            "independent_native_replay":True,
            "original_model_pid_count":1,
            "original_model_process_reaped":True,
            "native_exit_codes":[cleanup["exit_code"],replayed["exit_code"]],
            "material_derived_gallery":[a["path"] for a in gallery_artifacts],
            "model_artifact_count":len(model_files),
            "source_fenced_m1_valid":True,
            "elapsed_seconds":round(time.monotonic()-started,3),
            "limitations":["Worm turns are model-selected; no global goal or A* objective",
                           "PNG/GIF show stored native material and selected moves, not framebuffer",
                           "One seed, two soft-guidance arms: exploratory line character, not statistical proof"],
        }
        _dump(root,"execution/summary.json",report)
        print(json.dumps({k:report[k] for k in (
            "mode","status","model_decisions","native_painted_cells",
            "brush_up_recoveries","termination","independent_native_replay")},
                         sort_keys=True),flush=True)
        return report
    except BaseException as exc:
        _dump(root, "failure.json", {
            "source_sha":args.source_sha,"mode":args.mode,
            "error_type":type(exc).__name__,"message":str(exc),
            "traceback":traceback.format_exc(),
            "actual_model_decisions":len(traces),"actual_native_edits":len(actions),
        })
        raise


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--mode", choices=MODES, required=True)
    p.add_argument("--godot", type=Path, required=True)
    p.add_argument("--runtime-manifest", type=Path, required=True)
    p.add_argument("--model-runtime-manifest", type=Path, required=True)
    p.add_argument("--source-sha", required=True)
    p.add_argument("--output", type=Path, required=True)
    qualify(p.parse_args())


if __name__ == "__main__":
    main()
