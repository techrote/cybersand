#!/usr/bin/env python3
"""Strict source-bound admission observations, with no physical-step credit.

An absent API is a property of the exact committed application, never a synonym
for a disabled treatment. This module also protects ordinary controls executed
by the existing final, mixed, renderer and deadline runners.
"""
from __future__ import annotations

from functools import lru_cache
import hashlib
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SELECTOR = "CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL"
HELPER = "scripts/material_publication_steps.gd"
MAIN = "scripts/main.gd"
COUNTERS = ("offers", "replaced_offers", "deferred_turns", "consumptions", "accepted_uploads",
            "accepted_uploads_after_policy_cancellation", "cancellations", "edit_requests", "paint_generation")
PENDING = ("pending_serial", "pending_generation", "pending_generated_usec", "first_offer_usec", "deadline_usec")
ANCHOR = ("anchor_session_step", "anchor_rapier_step", "anchor_uploaded_serial", "anchor_uploaded_usec")
ACCEPTED_SCOPE = "selected transactions whose policy identity survives upload; Main separately counts accepted transactions cancelled by texture recreation"
INT64_MIN, INT64_MAX = -(1 << 63), (1 << 63) - 1


def need(value, message):
    if not value:
        raise ValueError(message)


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def signed64(value, *, nonzero=False):
    return type(value) is int and INT64_MIN <= value <= INT64_MAX and (not nonzero or value != 0)


def live_bridge_identity(value: str) -> int:
    # JSON preserves Godot ObjectIDs as canonical strings, including negative
    # signed representations. Refuse coercion before calling int().
    need(type(value) is str and len(value) <= 20 and re.fullmatch(r"-?[1-9][0-9]*", value) is not None,
         "Live bridge identity is not a canonical nonzero signed int64 string")
    result = int(value)
    need(signed64(result, nonzero=True) and str(result) == value,
         "Live bridge identity exceeds the signed int64 domain")
    return result


def validate_status(status: dict, interval: int, *, allow_ownerless=False) -> None:
    need(type(interval) is int and interval in (0, 2), "Unregistered completed-step material interval")
    need(isinstance(status, dict) and status.get("schema") == "pubpres-material-steps-v1"
         and all(type(status.get(key)) is int and status[key] == interval
                 for key in ("requested_interval", "effective_interval"))
         and status.get("enabled") is (interval == 2) and status.get("disabled_reason") == ""
         and status.get("physical_credit") is False,
         "Requested completed-step material policy did not reach the live owner")
    need(status.get("accepted_upload_scope") == ACCEPTED_SCOPE, "Accepted-upload cancellation scope changed")
    need(type(status.get("scheduled_added_hold_usec")) is int and status["scheduled_added_hold_usec"] == 16667
         and type(status.get("source_age_guard_usec")) is int and status["source_age_guard_usec"] == 1000000,
         "Registered bounded material hold changed")
    need(all(integer(status.get(key)) for key in COUNTERS), "Invalid completed-step policy counter")
    need(status["accepted_uploads"] + status["accepted_uploads_after_policy_cancellation"]
         <= status["consumptions"] <= status["offers"]
         and status["replaced_offers"] <= status["offers"], "Impossible completed-step policy accounting")
    need(type(status.get("pending_count")) is int and status["pending_count"] in (0, 1),
         "Unbounded pending material publications")
    need(all(integer(status.get(key), -1) for key in (*PENDING, *ANCHOR, "paint_idle_usec", "last_source_age_usec"))
         and all(integer(status.get(key)) for key in ("last_hold_usec", "last_deadline_overrun_usec", "maximum_deadline_overrun_usec")),
         "Invalid material identity or clock")
    need(all(type(status.get(key)) is bool for key in ("paint_force", "paint_busy", "last_count_due", "last_deadline_due")),
         "Material policy boolean was coerced")
    need(all(type(status.get(key)) is str for key in ("last_cancel", "last_offer_result", "last_consumption_reason")),
         "Missing material policy reason")
    identity = status.get("identity")
    # Only the explicitly synthetic Main-history fixture admits its ownerless
    # [0, 0, World, 0] identity. Ordinary captures require the live signed ID.
    need(type(identity) is list and (identity == [] or len(identity) == 4
         and all(signed64(value) for value in identity) and identity[2] > 0
         and (identity[0] > 0 and identity[1] > 0 and identity[3] != 0
              or allow_ownerless and identity[0] == identity[1] == identity[3] == 0)),
         "Invalid four-part material owner identity")
    if status["pending_count"]:
        need(interval == 2 and len(identity) == 4 and status["pending_serial"] > 0
             and status["pending_generation"] == identity[2]
             and status["first_offer_usec"] > 0 and status["deadline_usec"] > 0
             and status["deadline_usec"] <= status["first_offer_usec"] + 16667,
             "Pending publication has no bounded fixed deadline or owner")
    else:
        need(all(status[key] == -1 for key in PENDING), "Empty pending slot retained publication authority")
    need((status["anchor_uploaded_serial"] == -1 and all(status[key] == -1 for key in ANCHOR))
         or status["anchor_uploaded_serial"] > 0 and status["anchor_uploaded_usec"] > 0
         and ((status["anchor_session_step"] == status["anchor_rapier_step"] == -1)
              or status["anchor_session_step"] > 0 and status["anchor_rapier_step"] > 0),
         "Accepted material anchor has incomplete actual completion identity")
    need(status["maximum_deadline_overrun_usec"] >= status["last_deadline_overrun_usec"],
         "Material deadline maximum lost an observed overrun")
    if interval == 0:
        need(all(status[key] == 0 for key in COUNTERS)
             and status["pending_count"] == 0 and identity == []
             and all(status[key] == -1 for key in (*ANCHOR, "paint_idle_usec", "last_source_age_usec"))
             and all(status[key] == 0 for key in ("last_hold_usec", "last_deadline_overrun_usec", "maximum_deadline_overrun_usec"))
             and all(status[key] is False for key in ("paint_force", "paint_busy", "last_count_due", "last_deadline_due")),
             "Ordinary count0 control acquired scheduling work or authority")


def _digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


@lru_cache(maxsize=32)
def committed_capability(source: str, root: Path = ROOT) -> dict:
    need(type(source) is str and re.fullmatch(r"[0-9a-f]{40}", source) is not None,
         "Material capability requires the exact committed application identity")
    root = Path(root)
    paths = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only", source,
                                     "--", "godot/" + MAIN, "godot/" + HELPER], text=True).splitlines()
    need("godot/" + MAIN in paths, "Committed application Main is missing")
    main = subprocess.check_output(["git", "-C", str(root), "show", source + ":godot/" + MAIN])
    present = b"func material_step_status() -> Dictionary:" in main
    helper_present = "godot/" + HELPER in paths
    need(present is helper_present, "Partial or ambiguous committed material-step capability")
    helper = subprocess.check_output(["git", "-C", str(root), "show", source + ":godot/" + HELPER]) if present else None
    if present:
        need(b'"CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL"' in main
             and b'preload("res://scripts/material_publication_steps.gd")' in main,
             "Committed material-step API lacks its declared policy dependency")
    else:
        need(b"material_step_status" not in main and SELECTOR.encode() not in main,
             "Unrecognized legacy material-step capability")
    return {"source": source, "api_present": present, "main_sha256": _digest(main),
            "helper_sha256": _digest(helper) if helper is not None else None}


def validate_policy_observation(data: dict, project: Path, expected_interval: int = 0,
                                *, repository: Path = ROOT) -> dict:
    need(type(expected_interval) is int and expected_interval in (0, 2), "Unregistered policy observation")
    source = data["source_identity"]
    capability = committed_capability(source["source_sha"], repository)
    files = source["files"]
    for relative, key in ((MAIN, "main_sha256"), (HELPER, "helper_sha256")):
        path = project / relative
        actual = _digest(path.read_bytes()) if path.is_file() else None
        need("res://" + relative in files and actual == files["res://" + relative] == capability[key],
             "Observed material capability differs from actual staged and committed source: " + relative)
    need(capability["api_present"] or expected_interval == 0, "Count treatment requires an implemented source capability")
    for phase in ("selectors_before", "selectors_after"):
        selected = data[phase]
        need(selected["requested"].get(SELECTOR) == str(expected_interval)
             and selected.get("material_steps_api_present") is capability["api_present"]
             and "material_steps" in selected, "Material-step request or actual source capability changed")
        if capability["api_present"]:
            validate_status(selected["material_steps"], expected_interval)
        else:
            need(selected["material_steps"] is None, "Legacy source acquired an unregistered material policy")
    return {**capability, "requested_interval": expected_interval,
            "verified_off": capability["api_present"] and expected_interval == 0,
            "legacy_api_absence_verified": not capability["api_present"], "physical_credit": False,
            "scope": "Exact committed/staged Main and helper plus actual pre/post request/status; absent legacy capability is distinct from implemented effective0."}
