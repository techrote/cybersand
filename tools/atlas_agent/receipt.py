"""Receipt skeleton, secret redaction, sealing and verification."""
from __future__ import annotations

import hashlib
import json
import os
import platform
import re
from pathlib import Path

from .errors import STATUS_FAILURE
from .schema import load_schema, validate

RECEIPT_SCHEMA_ID = "cybersand.atlas-agent.receipt/1"
RUNNER_VERSION = "1.0.0"

_SECRET_PATTERNS = [
    re.compile(r"sk-(?:proj-|svcacct-|admin-)?[A-Za-z0-9_\-]{16,}"),
    re.compile(r"Bearer\s+[A-Za-z0-9._~+/\-]{16,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
]
REDACTED = "[REDACTED]"


class Redactor:
    """Masks credential-shaped strings and the exact secret values of this process."""

    def __init__(self, secrets: list[str] | None = None):
        self.secrets = sorted({s for s in (secrets or []) if s and len(s) >= 8}, key=len, reverse=True)

    def text(self, value: str) -> str:
        for secret in self.secrets:
            value = value.replace(secret, REDACTED)
        for pattern in _SECRET_PATTERNS:
            value = pattern.sub(REDACTED, value)
        return value

    def obj(self, value):
        if isinstance(value, str):
            return self.text(value)
        if isinstance(value, dict):
            return {self.text(str(k)): self.obj(v) for k, v in value.items()}
        if isinstance(value, (list, tuple)):
            return [self.obj(v) for v in value]
        return value

    def contains_secret(self, text: str) -> bool:
        return any(s in text for s in self.secrets) or any(p.search(text) for p in _SECRET_PATTERNS)


def canonical(value) -> str:
    return json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + "\n"


def seal(receipt: dict) -> dict:
    body = {k: v for k, v in receipt.items() if k != "receipt_sha256"}
    receipt["receipt_sha256"] = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":"),
                                                          ensure_ascii=False).encode("utf-8")).hexdigest()
    return receipt


def skeleton(run_id: str, mode: str, started_utc: str, collection: str) -> dict:
    return {
        "schema": RECEIPT_SCHEMA_ID, "receipt_sha256": "",
        "run": {"id": run_id, "started_utc": started_utc, "finished_utc": None, "duration_seconds": 0.0, "mode": mode,
                "runner_version": RUNNER_VERSION, "python": platform.python_version(), "openai_sdk": None,
                "ci": bool(os.environ.get("GITHUB_ACTIONS")), "model_calls_simulated": mode == "dry-run",
                "runner_git_head": None, "runner_tree_dirty": None},
        "status": {"final": STATUS_FAILURE, "exit_code": 9, "reason_code": "not_finished", "reason": "",
                   "phase": "preflight"},
        "source": {"repository_head": None, "expected_source_sha": None, "source_dirty": None,
                   "source_manifest_sha256": None, "collection": collection, "lane": None, "lane_writable": False,
                   "fixture": False, "files": {}, "head_after_run": None, "source_unchanged_after_run": None},
        "policy": {"instructions_version": None, "instructions_sha256": None, "tool_schema_sha256": None,
                   "pricing_sha256": None, "read_globs": [], "write_globs": [], "generated_globs": [], "task_directive": None,
                   "tools_advertised": []},
        "model": {"requested": "", "observed": [], "reasoning_effort": None, "max_output_tokens_per_call": 0,
                  "image_detail": None, "api_endpoint": "none", "store": False, "truncation": "disabled"},
        "limits": {},
        "usage": {"api_attempts": 0, "api_responses": 0, "retries": 0, "iterations": 0, "tool_calls": 0,
                  "malformed_tool_calls": 0, "sandbox_violations": 0, "images_loaded": 0, "image_sends": 0,
                  "image_bytes": 0, "input_tokens": 0, "cached_input_tokens": 0, "output_tokens": 0,
                  "reasoning_tokens": 0, "tool_seconds": 0.0},
        "cost": {"currency": "USD", "basis": "token counts x published rates; the API reports tokens, not dollars",
                 "rates": None, "reserved_worst_case_total_usd": 0.0, "peak_reservation_usd": 0.0,
                 "computed_from_reported_usage_usd": 0.0, "ambiguous_charge_assumed_usd": 0.0, "committed_usd": 0.0,
                 "per_call_ceiling_usd": 0.0, "per_run_ceiling_usd": 0.0, "authorised_ceiling_usd": 0.0,
                 "remaining_allowance_usd": 0.0, "reservation_overruns": 0, "billing_reconciliation": "not-performed",
                 "simulated": mode == "dry-run"},
        "credit_gate": {"performed": False, "passed": None, "checks": [], "headroom_basis": None, "facts": {}},
        "calls": [], "tools": [], "validation": [], "edits": [], "images": [],
        "captures": {"input_bundle": None, "reference_bundle": None, "rendered_bundle": None, "comparison": None, "render_attempts": []},
        "visual_cycle": {"claimed": False, "reason": "no before/after Godot capture cycle was executed"},
        "final_report": None,
        "artifacts": {"patch": None, "tool_log": None, "transcript": None},
        "publication": {"mode": "none", "performed": False},
    }


def verify_receipt(path: Path, redactor: Redactor | None = None) -> list[str]:
    """Return problems: schema violations, broken seal, or credential-shaped content."""
    try:
        text = Path(path).read_text(encoding="utf-8")
        receipt = json.loads(text)
    except (OSError, ValueError) as exc:
        return [f"unreadable receipt: {exc}"]
    problems = validate(receipt, load_schema("receipt.schema.json"))
    body = {k: v for k, v in receipt.items() if k != "receipt_sha256"}
    expected = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":"),
                                         ensure_ascii=False).encode("utf-8")).hexdigest()
    if receipt.get("receipt_sha256") != expected:
        problems.append("receipt_sha256 does not match the content (edited after the run)")
    scanner = redactor or Redactor()
    if scanner.contains_secret(text):
        problems.append("receipt contains credential-shaped content")
    return problems
