#!/usr/bin/env python3
"""GIP-013: sandboxed, deterministic interaction-contract gremlin.

The built-in adapter is a *reference contract model*, NOT CyberSand/Rapier.
No production World, actor or user file is accessed by this runner.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import time
from urllib import request
from urllib.parse import urlsplit

SCHEMA = 1
PROMPT = ("You are Sprocket, Chief Gremlin of the Test Laboratory. Discover strange "
          "interactions using only permitted actions. Prefer surprising valid sequences. "
          "Never modify code or declare success. Suggest one action, then observe.")
FAULTS = ("rejected_apply_clears_stage", "inspect_transfers_pilot", "cancel_leaks_grab", "duplicate_body")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def digest(value):
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def sha_file(path):
    with open(path, "rb") as handle:
        h = hashlib.sha256()
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


class ContractWorld:
    """In-memory test double of selected ACTOR-002R contracts, not a physics solver."""

    def __init__(self, fault=None):
        self.fault = fault
        self.playing = False
        self.selected = 1
        self.pilot = 1
        self.mode = "inspect"
        self.tab = "Actors"
        self.grab = None
        self.pending = []
        self.controllers = {"1": "human", "2": "scripted", "3": "policy"}
        self.actors = {"1": [110, 111], "2": [220, 221, 222], "3": [330]}
        self.joints = {"1": ["110-111"], "2": ["220-221", "221-222"], "3": []}
        self.retired = []
        self.capacity = {"actors": 8, "bodies": 64, "proxies": 64}
        self.staged = None
        self.authored = {"1": [100, 100], "2": [240, 100], "3": [400, 100]}
        self.saved = None
        self.material_writes = 0
        self.native_tick = 0
        self.rapier_tick = 0
        self.epoch = 1
        self.generation = 1

    def snapshot(self):
        return copy.deepcopy({
            "playing": self.playing, "selected": self.selected, "pilot": self.pilot,
            "mode": self.mode, "tab": self.tab, "grab": self.grab,
            "pending": self.pending, "controllers": self.controllers,
            "actors": self.actors, "joints": self.joints, "retired": self.retired,
            "capacity": self.capacity, "staged": self.staged,
            "authored": self.authored, "saved": self.saved,
            "material_writes": self.material_writes,
            "native_tick": self.native_tick, "rapier_tick": self.rapier_tick,
            "epoch": self.epoch, "generation": self.generation,
        })

    def legal(self):
        """Only closed-vocabulary, bounded, context-valid actions are offered."""
        result = [{"kind": "tick", "count": 1}, {"kind": "tick", "count": 3},
                  {"kind": "pause" if self.playing else "play"},
                  {"kind": "open_config"}]
        result += [{"kind": "inspect", "actor": x} for x in (1, 2, 3)]
        result += [{"kind": "tab", "name": x} for x in
                   ("Actors", "Controllers", "Equipment", "Capacity", "Diagnostics")]
        result += [{"kind": "mode", "name": x} for x in
                   ("inspect", "paint", "grab", "place")]
        result += [{"kind": "pilot", "actor": x} for x in (1, 2)]
        result += [{"kind": "stage_capacity", "actors": x} for x in (1, 3, 8, 16)]
        if self.staged is not None:
            result.append({"kind": "apply_capacity"})
        result += [{"kind": "controller", "actor": 2, "source": x} for x in
                   ("scripted", "policy", "passive")]
        if self.playing and self.mode == "paint" and self.grab is None:
            result.append({"kind": "paint", "cells": 4})
        if self.playing and self.mode == "grab":
            if self.grab is None:
                result += [{"kind": "grab_begin", "actor": x} for x in (1, 2, 3)]
            else:
                result += [{"kind": "grab_move", "outside": x} for x in (False, True)]
                result += [{"kind": "grab_release"}, {"kind": "focus_loss"}]
        if self.playing and self.grab is None:
            result += [{"kind": "equipment", "actor": 1}, {"kind": "equipment", "actor": 2}]
        if not self.playing:
            result += [{"kind": "move_start", "actor": x, "dx": 8} for x in (1, 2, 3)]
        result.append({"kind": "save"})
        if self.saved is not None:
            result.append({"kind": "restore"})
        return result

    def apply(self, action):
        if action not in self.legal():
            return {"accepted": False, "reason": "illegal_action"}
        kind = action["kind"]
        accepted, reason = True, "ok"
        if kind == "tick":
            if self.playing:
                self.native_tick += action["count"]
                self.rapier_tick += action["count"]
        elif kind == "play":
            self.playing = True
        elif kind == "pause":
            self.playing = False
            self.grab = None
            self.pending.clear()
        elif kind == "inspect":
            self.selected = action["actor"]
            if self.fault == "inspect_transfers_pilot":
                self.pilot = action["actor"]
        elif kind == "pilot":
            self.pilot = action["actor"]
            self.generation += 1
        elif kind == "mode":
            self.mode = action["name"]
            if self.mode != "grab":
                self.grab = None
        elif kind == "tab":
            self.tab = action["name"]
        elif kind == "open_config":
            self.grab = None
            if self.fault == "cancel_leaks_grab" and kind:
                self.grab = 2
            self.tab = "Actors"
        elif kind == "stage_capacity":
            self.staged = {"actors": action["actors"], "bodies": 64, "proxies": 64}
        elif kind == "apply_capacity":
            if self.staged["actors"] < len(self.actors):
                accepted, reason = False, "capacity_below_population"
                if self.fault == "rejected_apply_clears_stage":
                    self.staged = None
            else:
                self.capacity = copy.deepcopy(self.staged)
                self.staged = None
        elif kind == "controller":
            self.controllers[str(action["actor"])] = action["source"]
            self.generation += 1
            self.pending.clear()
        elif kind == "grab_begin":
            self.grab = action["actor"]
            self.pending.clear()
        elif kind == "grab_move":
            pass  # bounded pointer forces are outside this non-physics model
        elif kind in ("grab_release", "focus_loss"):
            self.grab = None
        elif kind == "equipment":
            self.pending.append({"actor": action["actor"], "generation": self.generation})
        elif kind == "paint":
            self.material_writes += action["cells"]
        elif kind == "move_start":
            self.authored[str(action["actor"])][0] += action["dx"]
        elif kind == "save":
            self.saved = copy.deepcopy(self.authored)
        elif kind == "restore":
            self.authored = copy.deepcopy(self.saved)
            self.grab = None
            self.pending.clear()
            self.epoch += 1
            self.generation += 1
        if self.fault == "duplicate_body" and kind == "tick" and self.playing:
            self.actors["3"].append(220)
        return {"accepted": accepted, "reason": reason}


def violations(before, action, result, after):
    """Oracle stays separate from actor transition implementation."""
    found = []
    ids = [v for parts in after["actors"].values() for v in parts]
    if len(ids) != len(set(ids)):
        found.append("duplicate_body_identity")
    if set(ids).intersection(after["retired"]):
        found.append("retired_body_registered")
    if action["kind"] == "inspect" and after["pilot"] != before["pilot"]:
        found.append("inspection_transferred_pilot")
    if action["kind"] in ("grab_begin", "grab_move", "grab_release", "focus_loss", "open_config", "inspect", "tab"):
        if after["controllers"] != before["controllers"] or after["joints"] != before["joints"]:
            found.append("unrelated_controller_or_joint_mutation")
    if action["kind"] in ("pause", "open_config", "focus_loss", "restore") and after["grab"] is not None:
        found.append("stale_grab_authority")
    if action["kind"] in ("pause", "restore") and after["pending"]:
        found.append("pending_command_survived_revocation")
    if action["kind"] == "apply_capacity" and not result["accepted"]:
        if after["capacity"] != before["capacity"]:
            found.append("rejected_apply_mutated_accepted")
        if after["staged"] != before["staged"]:
            found.append("rejected_apply_lost_staged")
    if action["kind"] == "restore" and after["authored"] != before["saved"]:
        found.append("authored_restore_mismatch")
    if action["kind"] != "paint" and after["material_writes"] != before["material_writes"]:
        found.append("unowned_material_mutation")
    if action["kind"] == "paint" and after["material_writes"] - before["material_writes"] != action["cells"]:
        found.append("material_budget_violation")
    if action["kind"] != "tick" and (after["native_tick"] != before["native_tick"] or after["rapier_tick"] != before["rapier_tick"]):
        found.append("unexpected_physics_tick")
    if after["native_tick"] < before["native_tick"] or after["rapier_tick"] < before["rapier_tick"]:
        found.append("nonmonotonic_tick")
    if action["kind"] == "tick" and not before["playing"] and (after["native_tick"], after["rapier_tick"]) != (before["native_tick"], before["rapier_tick"]):
        found.append("paused_tick_advanced")
    return sorted(set(found))


class Sprocket:
    """Loopback-only HTTP client; all outputs are untrusted proposals."""
    def __init__(self, url, model, timeout=3.0):
        parsed = urlsplit(url)
        if parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost", "::1") or parsed.username or parsed.password or parsed.fragment:
            raise ValueError("Sprocket endpoint must be an explicitly supplied loopback HTTP URL")
        if parsed.path not in ("/v1/chat/completions", "/chat/completions"):
            raise ValueError("Sprocket requires a local OpenAI-compatible chat completions endpoint")
        self.url, self.model, self.timeout = url, model, timeout
        self.last = None
        self.repeats = 0
        self.consecutive_errors = 0
        self.disabled = False

    def propose(self, state, choices):
        if self.disabled:
            return None, "sprocket_disabled"
        summary = {key: state[key] for key in ("playing", "selected", "pilot", "mode", "tab", "grab", "pending", "controllers", "capacity", "staged", "native_tick", "rapier_tick", "generation")}
        summary["actor_count"] = len(state["actors"])
        summary["body_count"] = sum(map(len, state["actors"].values()))
        payload = {"model": self.model, "temperature": 0.8, "max_tokens": 48,
                   "messages": [{"role": "system", "content": PROMPT},
                                {"role": "user", "content": canonical({"state": summary, "legal_actions": list(enumerate(choices)), "reply": "JSON only: {\"choice\": integer}"})}]}
        data = json.dumps(payload).encode("utf-8")
        req = request.Request(self.url, data=data, headers={"Content-Type": "application/json"}, method="POST")
        class NoRedirect(request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                raise ValueError("redirect_refused")
        opener = request.build_opener(NoRedirect)
        try:
            with opener.open(req, timeout=self.timeout) as response:
                if response.status != 200:
                    raise ValueError("http_" + str(response.status))
                if int(response.headers.get("Content-Length", "0")) > 65536:
                    raise ValueError("oversized_response")
                raw = response.read(65537)
                if len(raw) > 65536:
                    raise ValueError("oversized_response")
            content = json.loads(raw)["choices"][0]["message"]["content"]
            chosen = json.loads(content)
            index = chosen.get("choice") if type(chosen) is dict else None
            if type(index) is not int or not 0 <= index < len(choices):
                return None, "invalid_choice"
            action = choices[index]
            self.repeats = self.repeats + 1 if action == self.last else 1
            self.last = action
            if self.repeats > 3:
                self.consecutive_errors += 1
                return None, "repeated_proposal"
            self.consecutive_errors = 0
            return action, None
        except Exception as exc:
            self.consecutive_errors += 1
            if self.consecutive_errors >= 2:
                self.disabled = True
            return None, "unavailable_or_malformed:" + type(exc).__name__


def choose_sequence(mode, seed, count, fault=None, sprocket=None, actions=None):
    world = ContractWorld(fault)
    randomizer = random.Random(seed)
    receipts, proposal_rejections, coverage = [], [], set()
    sprocket_actions, seeded_fallback_actions = 0, 0
    started = time.perf_counter_ns()
    for index in range(len(actions) if actions is not None else count):
        legal = world.legal()
        if actions is not None:
            action, origin = actions[index], "replay"
        elif mode == "CONTROL":
            action, origin = CONTROL_SEQUENCE[index % len(CONTROL_SEQUENCE)], "control"
        else:
            action, origin = None, "seeded"
            if mode == "SPROCKET" and sprocket is not None:
                action, error = sprocket.propose(world.snapshot(), legal)
                if error is not None:
                    proposal_rejections.append({"index": index, "reason": error})
                elif action is not None:
                    origin = "sprocket"
            if action is None:
                action = legal[randomizer.randrange(len(legal))]
                seeded_fallback_actions += 1
            else:
                sprocket_actions += 1
        before = world.snapshot()
        t0 = time.perf_counter_ns()
        result = world.apply(action)
        after = world.snapshot()
        elapsed = time.perf_counter_ns() - t0
        broken = violations(before, action, result, after)
        previous = receipts[-1]["action"]["kind"] if receipts else "START"
        coverage.add(previous + ">" + action.get("kind", "INVALID"))
        fact = {"index": index, "action": action,
                "before": before, "after": after, "result": result, "violations": broken}
        receipt = {**fact, "origin": origin, "fingerprint": digest(fact), "elapsed_ns": elapsed,
                   "native_tick": after["native_tick"], "rapier_tick": after["rapier_tick"],
                   "epoch": after["epoch"], "generation": after["generation"]}
        receipts.append(receipt)
        if broken:
            break  # CONTAINMENT: no subsequent action is dispatched
    total = time.perf_counter_ns() - started
    return {"mode": mode, "seed": seed, "adapter": "reference-contract-model",
            "receipts": receipts, "proposals_rejected": proposal_rejections,
            "unique_pairs": len(coverage), "pairs": sorted(coverage),
            "elapsed_ns": total, "sprocket_actions": sprocket_actions,
            "seeded_fallback_actions": seeded_fallback_actions,
            "failure": receipts[-1]["violations"] if receipts else []}


CONTROL_SEQUENCE = [
    {"kind": "inspect", "actor": 2}, {"kind": "play"},
    {"kind": "mode", "name": "grab"}, {"kind": "grab_begin", "actor": 2},
    {"kind": "grab_move", "outside": True}, {"kind": "open_config"},
    {"kind": "stage_capacity", "actors": 1}, {"kind": "apply_capacity"},
    {"kind": "tab", "name": "Controllers"}, {"kind": "pause"},
    {"kind": "move_start", "actor": 2, "dx": 8}, {"kind": "save"},
    {"kind": "move_start", "actor": 3, "dx": 8}, {"kind": "restore"},
    {"kind": "play"}, {"kind": "mode", "name": "paint"},
    {"kind": "paint", "cells": 4}, {"kind": "tick", "count": 3},
    {"kind": "pause"},
]


def shrink(mode, seed, actions, expected, fault=None, budget=160):
    candidate = list(actions)
    granularity, trials = 2, 0
    while len(candidate) >= 2 and trials < budget:
        size = (len(candidate) + granularity - 1) // granularity
        reduced = False
        for start in range(0, len(candidate), size):
            if trials >= budget:
                break
            attempt = candidate[:start] + candidate[start + size:]
            trials += 1
            result = choose_sequence(mode, seed, 0, fault=fault, actions=attempt)
            if expected and expected[0] in result["failure"]:
                candidate, reduced = attempt, True
                granularity = max(2, granularity - 1)
                break
        if not reduced:
            if granularity >= len(candidate):
                break
            granularity = min(len(candidate), granularity * 2)
    return candidate, trials


def identity(runtime=None, source_commit=None):
    here = Path(__file__).resolve()
    try:
        sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=here.parent,
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             check=True, timeout=2, text=True).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        sha = None
    return {"source_commit": source_commit or sha, "runner_sha256": sha_file(here),
            "runtime_sha256": sha_file(runtime) if runtime else None,
            "runtime_file": Path(runtime).name if runtime else None,
            "python": sys.version.split()[0], "schema": SCHEMA}


def atomic_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def save_run(root, run, ident, injected=None):
    folder = root / run["mode"].lower()
    folder.mkdir(exist_ok=False)
    receipts = run["receipts"]
    with (folder / "receipts.jsonl").open("x", encoding="utf-8") as handle:
        for rec in receipts:
            handle.write(canonical(rec) + "\n")
    action_trace = [r["action"] for r in receipts]
    transcript = {"schema": SCHEMA, "identity": ident,
                  "seed": run["seed"], "mode": run["mode"], "adapter": run["adapter"],
                  "fault_injection": injected,
                  "actions": action_trace, "fingerprints": [r["fingerprint"] for r in receipts],
                  "failure": run["failure"]}
    atomic_json(folder / "transcript.json", transcript)
    summary = {"mode": run["mode"], "seed": run["seed"], "adapter": run["adapter"],
               "actions_executed": len(receipts), "rejected_proposals": len(run["proposals_rejected"]),
               "invalid_proposal_rate": len(run["proposals_rejected"]) / max(1, len(receipts)),
               "execution_elapsed_ns": run["elapsed_ns"],
               "sprocket_actions": run["sprocket_actions"],
               "seeded_fallback_actions": run["seeded_fallback_actions"],
               "unique_interaction_pairs": run["unique_pairs"],
               "pairs": run["pairs"], "failure": run["failure"], "identity": ident,
               "injected_fault": injected, "proposals_rejected": run["proposals_rejected"]}
    if run["failure"]:
        mini, trials = shrink(run["mode"], run["seed"], action_trace, run["failure"], fault=injected)
        atomic_json(folder / "minimized.json", {"expected": run["failure"], "actions": mini,
                                               "attempts": trials, "adapter": run["adapter"]})
        summary["minimized_actions"] = len(mini)
    atomic_json(folder / "summary.json", summary)
    return summary


def report(root, summaries, notes):
    lines = ["# GIP-013 campaign report", "", "**Evidence class:** reference contract-model only; no real CyberSand World, Rapier or native worker executed.",
             "", "| Campaign | Steps | Invalid proposals | Unique adjacent action pairs | Invariant violations |",
             "| --- | ---: | ---: | ---: | --- |"]
    for row in summaries:
        lines.append(f'| {row["mode"]} | {row["actions_executed"]} | {row["rejected_proposals"]} | {row["unique_interaction_pairs"]} | {", ".join(row["failure"]) or "none observed"} |')
    lines += ["", "## Boundaries", "", "No finding in this report establishes real Workbench correctness or a physics-engine regression.",
              "A model-injected violation only demonstrates the independent oracle, containment, replay and shrink mechanism.",
              "Source/native provenance is recorded when supplied; missing hashes mean **unqualified**, never implicitly accepted."]
    if notes:
        lines += ["", "## Campaign notes", ""] + ["- " + n for n in notes]
    (root / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mode", choices=("control", "chaos", "sprocket", "all"), default="all")
    p.add_argument("--seed", type=int, default=13)
    p.add_argument("--steps", type=int, default=64)
    p.add_argument("--out", type=Path, help="New, non-existing evidence directory (default: new OS temp directory)")
    p.add_argument("--replay", type=Path, help="Replay a previously recorded transcript, verifying every fingerprint")
    p.add_argument("--runtime-file", type=Path, help="Optional exact native/runtime binary to SHA256")
    p.add_argument("--source-commit", help="Recorded source commit; never guessed")
    p.add_argument("--sprocket-url", help="Optional local loopback llama.cpp /v1/chat/completions URL")
    p.add_argument("--sprocket-model", default="sprocket-500m-q4_k_m.gguf")
    p.add_argument("--sprocket-model-file", type=Path, help="Optional local GGUF SHA256 provenance")
    p.add_argument("--inject-fault", choices=FAULTS, help="REFERENCE-MODEL oracle self-test only")
    p.add_argument("--expect-violation", action="store_true", help="For negative harness tests only")
    p.add_argument("--activate-immediately", action="store_true", help="Ceremonial override (always the CI/default behavior)")
    p.add_argument("--ceremonial-delay-seconds", type=int, default=0,
                   help="Explicit opt-in: perform control preflight, then wait until activation (normally 780); never in CI")
    args = p.parse_args(argv)
    if not 1 <= args.steps <= 500 or not -2147483648 <= args.seed <= 2147483647:
        p.error("steps 1..500 and seed signed int32 required")
    if args.ceremonial_delay_seconds < 0 or args.ceremonial_delay_seconds > 780:
        p.error("ceremonial delay must be 0..780 seconds")
    if args.ceremonial_delay_seconds and args.activate_immediately:
        p.error("activation modes are mutually exclusive")
    out = args.out if args.out else Path(tempfile.mkdtemp(prefix="gip013-"))
    if args.out:
        out.mkdir(parents=True, exist_ok=False)
    ident = identity(args.runtime_file, args.source_commit)
    ident["sprocket_model_sha256"] = sha_file(args.sprocket_model_file) if args.sprocket_model_file else None
    notes, summaries = [], []
    if args.replay:
        transcript = json.loads(args.replay.read_text(encoding="utf-8"))
        if transcript.get("schema") != SCHEMA or transcript.get("adapter") != "reference-contract-model":
            p.error("unsupported or unauthenticated transcript adapter/schema")
        fault = transcript.get("fault_injection")
        if fault is not None and fault not in FAULTS:
            p.error("unrecognized reference fault in transcript")
        run = choose_sequence(transcript["mode"], transcript["seed"], 0, fault=fault,
                              actions=transcript["actions"])
        actual = [r["fingerprint"] for r in run["receipts"]]
        match = actual == transcript["fingerprints"] and run["failure"] == transcript["failure"]
        summaries.append(save_run(out, run, ident, fault))
        notes.append("Transcript fingerprint equivalence: " + ("PASS" if match else "FAIL"))
        report(out, summaries, notes)
        print(canonical({"replay_matches": match, "output": str(out), "failure": run["failure"]}))
        return 0 if match else 3
    selected = ("CONTROL", "CHAOS", "SPROCKET") if args.mode == "all" else (args.mode.upper(),)
    preflight_started = time.monotonic()
    sprocket = Sprocket(args.sprocket_url, args.sprocket_model) if args.sprocket_url else None
    for mode in selected:
        if mode == "SPROCKET" and sprocket is None:
            notes.append("SPROCKET unavailable: no loopback model endpoint supplied; not counted as a model campaign.")
            continue
        if mode == "CONTROL":
            count = len(CONTROL_SEQUENCE)
        else:
            if args.ceremonial_delay_seconds:
                while time.monotonic() - preflight_started < args.ceremonial_delay_seconds:
                    time.sleep(min(0.1, args.ceremonial_delay_seconds - (time.monotonic() - preflight_started)))
            count = args.steps
        run = choose_sequence(mode, args.seed, count, fault=args.inject_fault, sprocket=sprocket)
        summaries.append(save_run(out, run, ident, args.inject_fault))
    atomic_json(out / "campaign-summary.json", {"schema": SCHEMA, "identity": ident,
                "campaigns": summaries, "notes": notes})
    report(out, summaries, notes)
    violation = any(s["failure"] for s in summaries)
    print(canonical({"output": str(out), "campaigns": [{"mode": s["mode"],
        "actions": s["actions_executed"], "failure": s["failure"], "unique_pairs": s["unique_interaction_pairs"]} for s in summaries],
        "notes": notes}))
    return 0 if violation == args.expect_violation else 2


if __name__ == "__main__":
    sys.exit(main())
