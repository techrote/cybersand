"""Opt-in BODY-V2 *synthetic* movement engine. Not native, trained or live inference.

The model/host integration boundary is intentionally tiny: enumerate legal IDs,
receive an exact offered ID, independently re-check before changing the isolated
synthetic World. Native integration must replace this World with authenticated
per-step material/epoch receipts and lift the separately pinned #611 ceilings.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import random

from .preflight import (
    H, W, HEADINGS, INK, HostView, Lease, Refusal, _png,
    new_ink_from_readbacks, swept_menu,
)

SYNTHETIC_TURN_CEILING = 128
SYNTHETIC_CURSOR_CEILING = 512
SYNTHETIC_INK_CEILING = 128
MAX_BRANCH_ANCHORS = 4


def digest(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def _legal_blank_or_owned(view, owned, cell):
    x, y = cell
    return (
        0 <= x < view.width
        and 0 <= y < view.height
        and not any(a <= x < a + w and b <= y < b + h for a, b, w, h in view.protected)
        and (view.material[y * view.width + x] == 0 or cell in owned)
    )


@dataclass(frozen=True)
class BodyOptions:
    span: int = 1
    pen_up: bool = False
    branch_anchors: bool = False

    def __post_init__(self):
        if type(self.span) is not int or not (1 <= self.span <= 4):
            raise Refusal("BODY-V2 span must be 1..4")
        if type(self.pen_up) is not bool or type(self.branch_anchors) is not bool:
            raise Refusal("BODY-V2 switches must be boolean")
        if self.branch_anchors and not self.pen_up:
            raise Refusal("Branch retrace requires enabled pen-up")


class SyntheticBody:
    """Per-lease synthetic World and action validator. Never a native receipt."""

    def __init__(self, lease: Lease, initial: HostView, *,
                 start=(12, 24), options=BodyOptions()):
        if not isinstance(lease, Lease) or not isinstance(initial, HostView):
            raise Refusal("Lease and host view required")
        if (type(start) is not tuple or len(start) != 2
                or any(type(v) is not int for v in start)
                or not _legal_blank_or_owned(initial, set(), start)):
            raise Refusal("Invalid starting cursor")
        self.lease = lease
        self.initial = initial
        self.material = list(initial.material)
        self.cursor = start
        self.heading = "E"
        self.options = options
        self.history = [start]   # actual traversed single-cell cursor positions
        self.own_ink = set()
        self.anchors = []
        self.visits = {start: 1}
        self.decisions = 0
        self.logical_moves = 0
        self.stopped = False
        self.trace = []

    def view(self):
        return HostView(tuple(self.material), self.initial.protected,
                        self.initial.width, self.initial.height)

    def menu(self):
        if self.stopped:
            return {}
        if self.decisions >= SYNTHETIC_TURN_CEILING:
            return {"STOP": ()}
        view = self.view()
        result = {"STOP": ()}
        available_moves = SYNTHETIC_CURSOR_CEILING - self.logical_moves
        if available_moves > 0:
            for ident, path in swept_menu(view, self.cursor,
                                           span=self.options.span).items():
                if ident == "STOP":
                    continue
                if (len(path) <= available_moves and
                        len(path) + len(self.own_ink) <= SYNTHETIC_INK_CEILING):
                    result[ident] = path
            if self.options.pen_up:
                for heading, (dx, dy) in HEADINGS.items():
                    path = []
                    for step in range(1, min(self.options.span, available_moves) + 1):
                        cell = (self.cursor[0] + dx * step,
                                self.cursor[1] + dy * step)
                        if not _legal_blank_or_owned(view, self.own_ink, cell):
                            break
                        path.append(cell)
                        result[f"LIFT_{heading}_{step}"] = tuple(path)
                if (self.options.branch_anchors and len(self.history) > 1 and
                        len(self.history) >= 2):
                    previous = self.history[-2]
                    # A rewind never teleports; it traverses one recorded cell.
                    if (sum(abs(a-b) for a,b in zip(self.cursor, previous)) == 1
                            and _legal_blank_or_owned(view, self.own_ink, previous)):
                        result["RETRACE_1"] = (previous,)
        if self.options.branch_anchors and len(self.anchors) < MAX_BRANCH_ANCHORS:
            if self.cursor not in self.anchors:
                result["SAVE_ANCHOR"] = ()
        return dict(sorted(result.items()))

    def observation(self, radius=3):
        if type(radius) is not int or not 1 <= radius <= 4:
            raise Refusal("Local observation radius must be 1..4")
        view = self.view()
        local = []
        for y in range(self.cursor[1]-radius, self.cursor[1]+radius+1):
            row = []
            for x in range(self.cursor[0]-radius, self.cursor[0]+radius+1):
                if not 0 <= x < view.width or not 0 <= y < view.height:
                    row.append(-1)
                elif any(a <= x < a+w and b <= y < b+h for a,b,w,h in view.protected):
                    row.append(3)
                elif (x,y) in self.own_ink:
                    row.append(1)
                elif view.material[y*view.width+x]:
                    row.append(2)
                else:
                    row.append(0)
            local.append(row)
        menu = self.menu()
        return {
            "evidence_class": "model-free-synthetic",
            "native_execution": False,
            "model_execution": False,
            "lease": self.lease.id,
            "world": self.lease.world,
            "cursor": list(self.cursor),
            "heading": self.heading,
            "decision_index": self.decisions,
            "inked_cells": len(self.own_ink),
            "cursor_logical_moves": self.logical_moves,
            "anchor_positions": [list(x) for x in self.anchors],
            "recent_actual_cursor_positions": [list(x) for x in self.history[-12:]],
            "local_occupancy": local,  # -1 edge, 0 empty, 1 own, 2 foreign, 3 protected
            "local_visits": self.visits.get(self.cursor, 0),
            "legal_action_ids": sorted(menu),
            "menu_digest": digest(menu),
            "world_sha256": digest(self.material),
            "epoch": self.decisions,
        }

    def choose(self, choice, offered_digest, *, original_response):
        if self.stopped:
            raise Refusal("STOP is final; late writes refused")
        before = self.observation()
        menu = self.menu()
        if type(choice) is not str or choice not in menu:
            raise Refusal("Model may choose only an offered action ID")
        if offered_digest != before["menu_digest"]:
            raise Refusal("Stale or forged offered-action digest")
        if type(original_response) is not str or not original_response:
            raise Refusal("Preserve an original selection response")
        path = menu[choice]
        prior_cursor = self.cursor
        prior_sha = before["world_sha256"]
        prior_ink = len(self.own_ink)
        if choice.startswith("INK_"):
            for x,y in path:
                if not self.view().empty_and_unprotected(x,y):
                    raise Refusal("Host rejected stale swept ink intermediate cell")
                self.material[y*self.initial.width+x] = INK
                self.own_ink.add((x,y))
        if choice == "RETRACE_1":
            if len(self.history) < 2 or path != (self.history[-2],):
                raise Refusal("Invalid cursor retrace")
            self.history.pop()
        else:
            self.history.extend(path)
        if path:
            self.cursor = path[-1]
            self.logical_moves += len(path)
            self.heading = next((d for d,(dx,dy) in HEADINGS.items()
                                 if (dx,dy) == (path[-1][0] - prior_cursor[0],
                                                 path[-1][1] - prior_cursor[1])),
                                self.heading) if len(path)==1 else choice.split("_")[1]
            self.visits[self.cursor] = self.visits.get(self.cursor, 0) + 1
        if choice == "SAVE_ANCHOR":
            self.anchors.append(self.cursor)
        if choice == "STOP":
            self.stopped = True
        self.decisions += 1
        after_sha = digest(self.material)
        delta = len(self.own_ink) - prior_ink
        if (delta != (len(path) if choice.startswith("INK_") else 0) or
                new_ink_from_readbacks(self.initial,self.view()) != len(self.own_ink)):
            raise Refusal("Synthetic World material-delta invariant broken")
        receipt = {
            "evidence_class": "model-free-synthetic",
            "native_execution": False,
            "model_execution": False,
            "native_receipts": 0,
            "lease": self.lease.id,
            "decision_index": before["decision_index"],
            "original_choice_response": original_response,
            "selected_action_id": choice,
            "offered_menu_digest": offered_digest,
            "path": [list(x) for x in path],
            "cursor_before": list(prior_cursor),
            "cursor_after": list(self.cursor),
            "new_ink_cells": delta,
            "total_ink_cells": len(self.own_ink),
            "logical_moves": self.logical_moves,
            "world_before_sha256": prior_sha,
            "world_after_sha256": after_sha,
            "stopped": self.stopped,
        }
        self.trace.append(receipt)
        return receipt



def replay_synthetic_actions(lease, initial, options, actions, *,
                             expected_final_sha256=None):
    """Source-matched model-free receipt replay, NOT independent native readback."""
    if type(actions) is not list or len(actions) > SYNTHETIC_TURN_CEILING:
        raise Refusal("Bounded source-matched replay only")
    b = SyntheticBody(lease, initial, options=options)
    for record in actions:
        if type(record) is not dict:
            raise Refusal("Bad replay record")
        observation = b.observation()
        if record.get("offered_menu_digest") != observation["menu_digest"]:
            raise Refusal("Replay offered-menu/source drift")
        choice = record.get("selected_action_id")
        raw = record.get("original_choice_response")
        emitted = b.choose(choice, observation["menu_digest"],
                           original_response=raw)
        if emitted != record:
            raise Refusal("Replay receipt mismatch, including original world hashes")
    if expected_final_sha256 is not None and digest(b.material) != expected_final_sha256:
        raise Refusal("Replay final material hash mismatch")
    return b


def synthetic_rollout(lease, *, options=BodyOptions(),
                      seed=570, turns=SYNTHETIC_TURN_CEILING):
    """Pure model-free seeded study, never evidence of a loaded model or Godot."""
    if type(turns) is not int or not 0 <= turns <= SYNTHETIC_TURN_CEILING:
        raise Refusal("Synthetic turn budget outside 0..128")
    cells = [0]*(W*H)
    for x in range(30,45):
        cells[36*W+x] = 61
    initial = HostView(tuple(cells), ((40,40,8,8),))
    body = SyntheticBody(lease, initial, options=options)
    rng = random.Random(seed)
    for _ in range(turns):
        before = body.observation()
        legal = before["legal_action_ids"]
        choices = [x for x in legal if x != "STOP"]
        if not choices:
            choice = "STOP"
        else:
            # A reproducible host-owned baseline; favor ink and straight motion
            # without a destination or an A* planner.
            ink = [x for x in choices if x.startswith("INK_")]
            lifts = [x for x in choices if x.startswith("LIFT_")]
            if lifts and rng.random() < 0.24:
                choices = lifts
            elif ink and rng.random() < 0.75:
                choices = ink
            choice = rng.choice(choices)
        body.choose(choice,before["menu_digest"],
                    original_response=f"deterministic-host-policy:{choice}")
        if body.stopped:
            break
    return body


def showcase(folder):
    """Four paired-seed opt-in synthetics, changing one body ability per arm."""
    out = Path(folder)
    out.mkdir(parents=True,exist_ok=False)
    variants = (
        ("baseline-one-cell", BodyOptions(1,False,False)),
        ("four-cell-ink", BodyOptions(4,False,False)),
        ("pen-up-four-cell", BodyOptions(4,True,False)),
        ("branch-retrace", BodyOptions(4,True,True)),
    )
    arms = []
    for i,(label,opts) in enumerate(variants):
        lease = Lease(f"body-v2-{i}","bodylab",
                      f"proposed-runner-{i//2}",f"body-world-{i}",
                      "NO_MODEL_ATTACHED",570)
        body = synthetic_rollout(lease,options=opts,seed=570)
        # Original controller trace is replayed on a fresh isolated synthetic World.
        # This is SAME-CODE evidence integrity, NOT independent native verification.
        verified = replay_synthetic_actions(
            lease, body.initial, opts, body.trace,
            expected_final_sha256=digest(body.material))
        if verified.material != body.material or verified.cursor != body.cursor:
            raise Refusal("Four-arm body-v2 deterministic replay mismatch")
        png = _png(body.view())
        trace = {
            "classification": "MODEL-FREE SYNTHETIC, NOT NATIVE",
            "lease": lease.id,
            "variant": label,
            "configured_model": None,
            "active_resident_model_pids": [],
            "native_receipts": 0,
            "model_calls": 0,
            "options": {"span":opts.span,"pen_up":opts.pen_up,
                        "branch_anchors":opts.branch_anchors},
            "source_matched_replay": True,
            "decisions": body.decisions,
            "logical_cursor_moves": body.logical_moves,
            "inked_cells_from_material_delta":
                new_ink_from_readbacks(body.initial,body.view()),
            "ended_by_stop": body.stopped,
            "actions": body.trace,
            "initial_world_sha256": digest(body.initial.material),
            "final_world_sha256": digest(body.material),
        }
        raw = (json.dumps(trace,sort_keys=True,indent=2)+"\n").encode()
        pn = f"body-{i}.png"
        jn = f"body-{i}.json"
        (out/pn).write_bytes(png)
        (out/jn).write_bytes(raw)
        arms.append({"lease":lease.id,"variant":label,
                     "decisions":body.decisions,
                     "painted_cells":len(body.own_ink),
                     "png":pn,"png_sha256":hashlib.sha256(png).hexdigest(),
                     "trace":jn,"trace_sha256":hashlib.sha256(raw).hexdigest()})
    manifest = {
        "schema":"driv3r-body-v2-synthetic/1",
        "source":"additive body_lab only",
        "native_execution":False,
        "model_execution":False,
        "verified_active_model_processes":0,
        "native_receipts":0,
        "native_128_turns_qualified":False,
        "synthetic_max_decisions":SYNTHETIC_TURN_CEILING,
        "arms":arms,
    }
    (out/"manifest.json").write_text(json.dumps(manifest,sort_keys=True,indent=2)+"\n")
    return manifest


if __name__=="__main__":
    import argparse
    p=argparse.ArgumentParser()
    p.add_argument("--out",required=True)
    a=p.parse_args()
    print(json.dumps(showcase(a.out),sort_keys=True,indent=2))
