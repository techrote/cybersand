"""BODY-V5 bounded *fixture-only* operation journal, not a Godot transport.

This records externally supplied single-operation mock receipts in source order.
A partial/error/timeout is terminal for this journal: a real native host MUST
independently reconcile and clean up, never blindly retry an uncertain PAINT.
No receipt here attests a model PID, native source or actual persisted material.
"""
from __future__ import annotations

import copy
import hashlib
import json

from .native_inert_adapter import ExternalSnapshot, check_fixture_transcript, SCHEMA
from .preflight import Refusal


def _digest(value):
    return hashlib.sha256(json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("ascii")).hexdigest()


class InertReceiptJournal:
    """Per-lease, append-only fixture check with a fail-closed partial barrier."""

    def __init__(self, plan, starting_snapshot):
        if not isinstance(starting_snapshot, ExternalSnapshot):
            raise Refusal("Fixture journal requires an external snapshot")
        if (type(plan) is not dict or plan.get("schema") != SCHEMA
                or plan.get("before_fingerprint") != starting_snapshot.fingerprint()
                or plan.get("native_execution") is not False
                or plan.get("model_execution") is not False
                or plan.get("native_receipts_authenticated") is not False):
            raise Refusal("Only source-bound unexecuted inert plans accepted")
        operations = plan.get("operations")
        if type(operations) is not list or not 1 <= len(operations) <= 8:
            raise Refusal("Invalid bounded native-inert operation plan")
        if (plan.get("lease_id"), plan.get("runner"), plan.get("world"),
            plan.get("source_sha")) != (
            starting_snapshot.lease_id, starting_snapshot.runner,
            starting_snapshot.world, starting_snapshot.source_sha):
            raise Refusal("Inert plan and fixture World differ")
        self.plan = copy.deepcopy(plan)
        self.current = starting_snapshot
        self.records = []
        self.state = "pending"
        self.failure_code = None
        self.chain_sha256 = _digest({
            "schema": "driv3r.body_lab.fixture-journal/1",
            "plan": self.plan,
            "initial": starting_snapshot.fingerprint(),
        })

    def accept(self, row):
        if self.state != "pending":
            raise Refusal("Fixture journal is closed or quarantined")
        op = self.plan["operations"][len(self.records)]
        one = {**self.plan, "operations": [op],
               "before_fingerprint": self.current.fingerprint()}
        try:
            check_fixture_transcript(one, self.current, [row])
            after = row[2]
            if after.epoch == self.current.epoch:
                raise Refusal("Unadvanced epoch cannot confirm an operation")
        except (Refusal, IndexError, TypeError, KeyError) as exc:
            self.state = "quarantined"
            self.failure_code = "invalid-operation-receipt"
            raise Refusal("Partial/invalid fixture operation quarantined") from exc
        self.chain_sha256 = _digest({
            "previous": self.chain_sha256, "index": len(self.records),
            "kind": row[0], "changed_cells": row[1],
            "before": self.current.fingerprint(),
            "after": after.fingerprint(),
        })
        self.records.append({
            "index": len(self.records), "kind": row[0],
            "after_fingerprint": after.fingerprint(),
            "chain_sha256": self.chain_sha256,
        })
        self.current = after
        if len(self.records) == len(self.plan["operations"]):
            self.state = "complete"
        return self.report()

    def quarantine(self, reason):
        if self.state != "pending" or reason not in (
                "transport_loss", "timeout", "operator_abort",
                "source_uncertain", "external_stop_uncertain"):
            raise Refusal("Invalid quarantine transition")
        self.failure_code = reason
        self.state = "quarantined"
        return self.report()

    def report(self):
        return {
            "schema": "driv3r.body_lab.fixture-journal/1",
            "lease_id": self.plan["lease_id"],
            "state": self.state, "accepted_fixture_operations": len(self.records),
            "planned_operations": len(self.plan["operations"]),
            "last_fixture_fingerprint": self.current.fingerprint(),
            "chain_sha256": self.chain_sha256, "failure_code": self.failure_code,
            "model_execution_verified": False, "native_authenticated": False,
            "host_cleanup_authenticated": False,
            "safe_to_auto_retry": False,
            "evidence_class": "source-checked-external-mock-fixtures",
        }
