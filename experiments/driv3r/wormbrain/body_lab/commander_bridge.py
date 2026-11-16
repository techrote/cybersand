"""Four-episode Commander lease adapter; NO inference dispatch or native execution.

Imports the public *data contract* of DRIV3R Commander #629 without importing or
editing its lane. Runner IDs, model outputs and material snapshots are external
claims until a separate native/runner transport independently authenticates them.
A fixture receipt is never evidence of a model process or Godot PAINT.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import re
import time

from .body_v2 import BodyOptions
from .fixture_journal import InertReceiptJournal
from .native_inert_adapter import (
    ExternalSnapshot, check_fixture_transcript, offered, prepare,
)
from .preflight import Lease, Refusal, HostView, BASELINE

REQUEST = "driv3r.wormfleet.request/1"
PLAN = "driv3r.wormfleet.plan/1"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
SHA1 = re.compile(r"[0-9a-f]{40}\Z")
IDENT = re.compile(r"[A-Za-z0-9_.-]{1,100}\Z")


def _require(condition, reason):
    if not condition:
        raise Refusal(reason)


def _canonical(value):
    # Intentionally identical to Commander's JSON canonical() incl. newline.
    return (json.dumps(value, sort_keys=True, separators=(",", ":"),
                       ensure_ascii=True) + "\n").encode("ascii")


def _digest(value):
    return hashlib.sha256(_canonical(value)).hexdigest()


@dataclass(frozen=True)
class WormIdentity:
    lease: Lease
    runner_slot: int
    episode_id: str
    model_id: str
    model_revision: str
    model_sha256: str
    checkpoint_sha256: str
    evidence_class: str
    decision_budget: int
    material_budget: int


def import_commander_plan(request, plan, runner_bindings):
    """Fail-closed structural import, NOT authentication of GitHub runner/PIDs.

    runner_bindings: {0: 'external-runner-A', 1: 'external-runner-B'}.
    These names are unverified labels, not evidence that models are loaded.
    """
    _require(type(request) is dict and type(plan) is dict, "Missing Commander request/plan")
    _require(request.get("schema") == REQUEST and plan.get("schema") == PLAN,
             "Unknown Commander schema")
    _require(request.get("training") is False and request.get("paid_api") is False
             and request.get("native_permissions_remain_host_owned") is True
             and request.get("automatically_expand") is False, "Unsafe Commander authority")
    _require(request.get("max_runners") == 2 and
             request.get("models_per_runner") == 2, "Unqualified residency topology")
    _require(type(runner_bindings) is dict and set(runner_bindings) == {0, 1},
             "Two external runner bindings required")
    _require(all(type(v) is str and IDENT.fullmatch(v)
                 for v in runner_bindings.values()) and
             len(set(runner_bindings.values())) == 2, "Duplicate or unsafe runner binding")
    _require(all(type(request.get(k)) is str and SHA256.fullmatch(request[k])
                 for k in ("source_sha256", "host_source_sha256")),
             "Unpinned Commander source fingerprints")
    _require(type(request.get("campaign")) is str and
             IDENT.fullmatch(request["campaign"]) and
             type(request.get("wrangler")) is str and
             IDENT.fullmatch(request["wrangler"]), "Invalid campaign or wrangler")
    digest = _digest(request)
    _require(plan.get("request_sha256") == digest and
             plan.get("campaign") == request["campaign"] and
             plan.get("wrangler") == request["wrangler"] and
             plan.get("total_leases") == 4 and
             plan.get("dispatch_permitted") is False,
             "Commander plan changed or dispatch authority escalated")
    supplied = request.get("episodes")
    _require(type(supplied) is list and len(supplied) == 4, "Require four episodes")
    _require(type(plan.get("runner_jobs")) is list and
             len(plan["runner_jobs"]) == 2, "Require exactly two runner job records")

    expected = {}
    seeds = set()
    for ep in supplied:
        _require(type(ep) is dict and type(ep.get("id")) is str and
                 IDENT.fullmatch(ep["id"]) and ep["id"] not in expected,
                 "Duplicate or malformed episode")
        _require(type(ep.get("seed")) is int and ep["seed"] >= 0 and
                 ep["seed"] not in seeds, "Duplicate or malformed seed")
        seeds.add(ep["seed"])
        slot = ep.get("runner_slot")
        _require(type(slot) is int and slot in (0, 1), "Invalid runner slot")
        _require(ep.get("evidence_class") in ("native_model", "model_scored_w0"),
                 "Invalid evidence class")
        budget = 36 if ep["evidence_class"] == "native_model" else 128
        _require(type(ep.get("decision_budget")) is int and
                 1 <= ep["decision_budget"] <= budget and
                 type(ep.get("material_budget")) is int and
                 0 <= ep["material_budget"] <=
                 min(ep["decision_budget"], budget) and
                 ep.get("allow_model_training") is False, "Unsafe episode budget/training")
        _require(type(ep.get("model_id")) is str and ep["model_id"].strip() and
                 type(ep.get("model_revision")) is str and
                 ep["model_revision"].strip() and
                 all(type(ep.get(k)) is str and SHA256.fullmatch(ep[k])
                     for k in ("model_sha256", "checkpoint_sha256")),
                 "Missing immutable model weights")
        expected[ep["id"]] = ep

    identities = {}
    seen_slots = set()
    for job in plan["runner_jobs"]:
        _require(type(job) is dict and type(job.get("runner_slot")) is int and
                 job["runner_slot"] in (0, 1) and
                 job["runner_slot"] not in seen_slots and
                 job.get("source_sha256") == request["source_sha256"],
                 "Cross-source or duplicate runner")
        slot = job["runner_slot"]
        seen_slots.add(slot)
        _require(type(job.get("leases")) is list and len(job["leases"]) == 2,
                 "Each runner must own two distinct leases")
        for row in job["leases"]:
            _require(type(row) is dict, "Malformed lease")
            episode_id = row.get("id")
            _require(episode_id in expected and episode_id not in identities,
                     "Foreign, repeated or missing lease")
            ep = expected[episode_id]
            lease_id = "wf-" + _digest({"request": digest, "id": episode_id})[:28]
            _require(row == {"lease_id": lease_id, **ep} and
                     ep["runner_slot"] == slot, "Commander lease mutated")
            # World identity is *isolated* and external; it is NOT a Godot World.
            lease = Lease(lease_id, request["wrangler"], runner_bindings[slot],
                          "body-" + lease_id, ep["model_id"], ep["seed"])
            identities[lease_id] = WormIdentity(
                lease, slot, episode_id, ep["model_id"], ep["model_revision"],
                ep["model_sha256"], ep["checkpoint_sha256"],
                ep["evidence_class"], ep["decision_budget"], ep["material_budget"])
    _require(seen_slots == {0, 1} and len(identities) == 4,
             "Four distinct Commander leases not established")
    return identities


class FourWormWrangler:
    """One bounded controller for four separate *unverified external* episodes.

    It can validate model-response bytes and source/material mock transcripts.
    Only an independent real model/native transport can promote any of these
    records to authenticated inference and native PAINT evidence.
    """

    def __init__(self, request, plan, runner_bindings, *, native_source_sha,
                 episode_timeout_seconds=300):
        _require(type(native_source_sha) is str and SHA1.fullmatch(native_source_sha),
                 "Missing exact native host source commit")
        _require(type(episode_timeout_seconds) is int and
                 1 <= episode_timeout_seconds <= 900, "Unbounded episode deadline")
        self.identities = import_commander_plan(request, plan, runner_bindings)
        self.native_source_sha = native_source_sha
        self.deadline_ns = time.monotonic_ns() + episode_timeout_seconds * 1_000_000_000
        self.sessions = {}
        self.request_sha256 = _digest(request)

    def _on_time(self):
        _require(time.monotonic_ns() < self.deadline_ns,
                 "Wrangler deadline expired; STOP/cleanup remains host-owned")

    def attach(self, lease_id, initial: HostView, snapshot: ExternalSnapshot):
        self._on_time()
        _require(lease_id in self.identities and lease_id not in self.sessions,
                 "Unplanned/reused lease")
        ident = self.identities[lease_id]
        _require(isinstance(initial, HostView) and
                 isinstance(snapshot, ExternalSnapshot) and
                 (snapshot.lease_id, snapshot.runner, snapshot.world,
                  snapshot.source_sha) ==
                 (lease_id, ident.lease.runner, ident.lease.world,
                  self.native_source_sha), "External snapshot/lease not isolated")
        # Independently check original/source/protection and initial material.
        offered(ident.lease, initial, snapshot,
                expected_source_sha=self.native_source_sha, decisions=0,
                decision_ceiling=min(ident.decision_budget, BASELINE[0]),
                material_ceiling=min(ident.material_budget, BASELINE[1]))
        self.sessions[lease_id] = {
            "initial": initial, "snapshot": snapshot, "decisions": 0,
            "pending": None, "pending_raw_output": None,
            "raw_outputs": [], "original_output_bytes": [],
            "fixture_receipts": [], "stopped": False,
            "fixture_journal": None, "quarantined": False,
        }

    def offer(self, lease_id, *, options=BodyOptions()):
        self._on_time()
        session = self._session(lease_id)
        _require(session["pending"] is None and not session["stopped"]
                 and not session["quarantined"],
                 "Cannot offer during an unfinished, quarantined or stopped episode")
        ident = self.identities[lease_id]
        return offered(ident.lease, session["initial"],
                       session["snapshot"], options=options,
                       expected_source_sha=self.native_source_sha,
                       decisions=session["decisions"],
                       decision_ceiling=min(ident.decision_budget, BASELINE[0]),
                       material_ceiling=min(ident.material_budget, BASELINE[1]))

    def submit(self, lease_id, action, token, raw_model_output, *,
               options=BodyOptions()):
        """Prepare only. Raw bytes are externally supplied, NOT model-authenticated."""
        self._on_time()
        session = self._session(lease_id)
        _require(session["pending"] is None and not session["stopped"]
                 and not session["quarantined"],
                 "Unfinished/quarantined/stopped episode")
        _require(type(raw_model_output) is bytes and
                 0 < len(raw_model_output) <= 65536,
                 "Original model response bytes required (unverified)")
        ident = self.identities[lease_id]
        _require(session["decisions"] < min(ident.decision_budget, BASELINE[0])
                 or action == "STOP", "Native hard decision ceiling")
        plan = prepare(ident.lease, session["initial"], session["snapshot"],
                       action, token, options=options,
                       expected_source_sha=self.native_source_sha,
                       decisions=session["decisions"],
                       decision_ceiling=min(ident.decision_budget, BASELINE[0]),
                       material_ceiling=min(ident.material_budget, BASELINE[1]))
        ink_after = plan["new_ink_before"] + sum(
            op["kind"] == "PAINT_ONE" for op in plan["operations"])
        _require(ink_after <= min(ident.material_budget, BASELINE[1]),
                 "Commander material budget exceeded")
        plan["raw_model_output_sha256"] = hashlib.sha256(raw_model_output).hexdigest()
        plan["original_response_attested_by"] = "external-unverified"
        plan["commander_request_sha256"] = self.request_sha256
        plan["model_sha256"] = ident.model_sha256
        plan["checkpoint_sha256"] = ident.checkpoint_sha256
        session["pending"] = plan
        session["pending_raw_output"] = bytes(raw_model_output)
        return json.loads(json.dumps(plan))

    def accept_fixture(self, lease_id, rows):
        """Only mock readbacks. NEVER label these as genuine Godot/native receipts."""
        self._on_time()
        session = self._session(lease_id)
        _require(session["pending"] is not None
                 and session["fixture_journal"] is None
                 and not session["quarantined"],
                 "No wholesale fixture acceptance during an open/quarantined stream")
        checked = check_fixture_transcript(
            session["pending"], session["snapshot"], rows)
        end = rows[-1][2]
        session["snapshot"] = end
        session["decisions"] += 1
        session["raw_outputs"].append(session["pending"]["raw_model_output_sha256"])
        session["original_output_bytes"].append(session["pending_raw_output"])
        session["fixture_receipts"].append(checked["terminal_fingerprint"])
        session["stopped"] = session["pending"]["selected_action"] == "STOP"
        session["pending"] = None
        session["pending_raw_output"] = None
        return {"evidence_class": "mock-external-transcript-checked",
                "model_execution_verified": False, "native_authenticated": False,
                "decisions_recorded": session["decisions"],
                "terminal_fingerprint": end.fingerprint()}

    def begin_fixture_stream(self, lease_id):
        """Begin one native-INERT per-cell receipt stream, never actual PAINT."""
        self._on_time()
        s = self._session(lease_id)
        _require(s["pending"] is not None and s["fixture_journal"] is None
                 and not s["quarantined"], "No fresh unquarantined pending plan")
        s["fixture_journal"] = InertReceiptJournal(s["pending"], s["snapshot"])
        return s["fixture_journal"].report()

    def accept_fixture_step(self, lease_id, row):
        """Accept one external MOCK readback, preserving partial failures."""
        self._on_time()
        s = self._session(lease_id)
        j = s["fixture_journal"]
        _require(j is not None and not s["quarantined"],
                 "No open fixture stream or episode quarantined")
        try:
            report = j.accept(row)
        except Refusal:
            s["quarantined"] = True
            raise
        if j.state != "complete":
            return report
        end = j.current
        s["snapshot"] = end
        s["decisions"] += 1
        s["raw_outputs"].append(s["pending"]["raw_model_output_sha256"])
        s["original_output_bytes"].append(s["pending_raw_output"])
        s["fixture_receipts"].append(j.chain_sha256)
        s["stopped"] = s["pending"]["selected_action"] == "STOP"
        s["pending"] = None
        s["pending_raw_output"] = None
        s["fixture_journal"] = None
        return {**report, "fixture_complete": True,
                "decisions_recorded": s["decisions"],
                "native_authenticated": False}

    def quarantine_fixture(self, lease_id, reason):
        """Lock an uncertain partial transcript; external host owns cleanup."""
        s = self._session(lease_id)
        _require(s["pending"] is not None and not s["quarantined"],
                 "No pending non-quarantined decision")
        if s["fixture_journal"] is None:
            s["fixture_journal"] = InertReceiptJournal(s["pending"], s["snapshot"])
        report = s["fixture_journal"].quarantine(reason)
        s["quarantined"] = True
        return report

    def _session(self, lease_id):
        _require(lease_id in self.sessions, "Worm lease not attached")
        return self.sessions[lease_id]

    def report(self):
        return {
            "schema": "driv3r.body_lab.commander-wrangler/1",
            "commander_request_sha256": self.request_sha256,
            "leases_planned": 4, "leases_attached": len(self.sessions),
            "mock_fixture_decisions": sum(s["decisions"] for s in self.sessions.values()),
            "stopped": sum(s["stopped"] for s in self.sessions.values()),
            "fixture_quarantines": sum(s["quarantined"] for s in self.sessions.values()),
            "pending_fixture_operations": sum(
                (len(s["fixture_journal"].records)
                 if s["fixture_journal"] is not None else 0)
                for s in self.sessions.values()),
            "verified_active_model_processes": 0,
            "authenticated_native_receipts": 0, "native_128_turns_qualified": False,
            "evidence_class": "unverified-external-with-mock-only-replay",
        }
