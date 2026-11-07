"""No-key dry-run backend.

A scripted planner stands in for the model so the *whole* orchestration (budget
reservation, limits, tools, sandbox, validators, receipts) runs with no network and
no chargeable request. It is not an AI and not an API interaction: the receipt marks
``model_calls_simulated: true`` and every call ``kind: "simulated"``. Simulated usage
is derived from the request size so budget refusals trigger exactly as they would live.
"""
from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace

from .budget import Budget
from .errors import ConfigError


class DryRunBackend:
    def __init__(self, collection: str, plan: dict | None, has_captures: bool, has_renderer: bool, writable: bool):
        self.batches = self._batches(collection, plan or {}, has_captures, has_renderer, writable)
        self.outputs: dict[str, object] = {}
        self.cursor = 0
        self.rate_limit_headers: dict[str, str] = {}

    @staticmethod
    def _batches(collection: str, plan: dict, has_captures: bool, has_renderer: bool, writable: bool) -> list:
        batches: list = [[("inspect_pack", {"collection": collection}),
                          ("run_validator", {"collection": collection, "kind": "validate"})]]
        if has_captures:
            batches.append([("list_captures", {})])
            batches.append([("view_image", lambda out: _first_shot(out, collection))])
        edits = plan.get("edits", []) if writable else []
        if edits:
            batches.append([("replace_text", {k: e[k] for k in ("path", "old_text", "new_text")}) for e in edits])
            batches.append([("run_validator", {"collection": collection, "kind": "validate"}),
                            ("run_validator", {"collection": collection, "kind": "render_write"}),
                            ("run_validator", {"collection": collection, "kind": "render_check"})])
        if has_renderer:
            batches.append([("render_capture", {"label": "after"})])
            if has_captures:
                batches.append([("compare_captures", {})])
        batches.append([("submit_report", lambda out: _report(collection, plan, bool(edits), has_captures))])
        return batches

    def respond(self, budget: Budget, request: dict, input_tokens_ub: int, max_output_tokens: int) -> dict:
        reservation = budget.reserve(input_tokens_ub, max_output_tokens)
        self._absorb(request)
        if self.cursor >= len(self.batches):
            raise ConfigError("dry-run plan exhausted without a report", "dry_run_plan_exhausted")
        items = []
        for index, (name, args) in enumerate(self.batches[self.cursor]):
            arguments = args(self.outputs) if callable(args) else args
            items.append({"type": "function_call", "call_id": f"dry_{self.cursor}_{index}", "name": name,
                          "arguments": json.dumps(arguments), "status": "completed"})
        self.cursor += 1
        usage = SimpleNamespace(input_tokens=max(1, input_tokens_ub // 3), output_tokens=150,
                                input_tokens_details=SimpleNamespace(cached_tokens=0),
                                output_tokens_details=SimpleNamespace(reasoning_tokens=0))
        response = SimpleNamespace(id=f"dryrun_{self.cursor}", model="dry-run-scripted-planner", status="completed",
                                   output=items, usage=usage, incomplete_details=None)
        return {"response": response, "reservation": reservation, "retries": 0, "events": [], "duration_ms": 0,
                "request_id": None}

    def _absorb(self, request: dict) -> None:
        """Remember the last JSON result of each tool so later steps can use it."""
        pending = {}
        for item in request.get("input", []):
            if isinstance(item, dict) and item.get("type") == "function_call":
                pending[item["call_id"]] = item["name"]
            if isinstance(item, dict) and item.get("type") == "function_call_output":
                try:
                    self.outputs[pending.get(item["call_id"], "?")] = json.loads(item["output"])
                except (ValueError, TypeError):
                    pass


def _first_shot(outputs: dict, collection: str) -> dict:
    listing = outputs.get("list_captures") or {}
    bundle = (listing.get("bundles") or {}).get("input") or {}
    for shot in bundle.get("shots", []):
        if shot.get("verified"):
            return {"bundle": "input", "shot_id": shot["shot_id"], "collection": shot["collection"]}
    return {"bundle": "input", "shot_id": "full", "collection": collection}


def _report(collection: str, plan: dict, edited: bool, saw_images: bool) -> dict:
    return {"outcome": "improved" if edited else ("critique_only" if not plan else "no_change"),
            "summary": "Dry-run scripted planner executed the orchestration contract; no model was consulted. "
                       + ("A planned bounded edit was applied and re-validated." if edited else "No edit applied."),
            "visual_evidence_used": saw_images,
            "critique": [{"dimension": "silhouette_scale_hierarchy", "score_0_to_5": 0,
                          "evidence": "dry-run placeholder: no model critique was produced"}],
            "revision_proposals": [], "edits_applied": [e.get("note", "planned edit") for e in plan.get("edits", [])]
            if edited else [], "validation_notes": f"collection {collection}: see receipt validation entries"}


def load_plan(path: str | None) -> dict | None:
    if not path:
        return None
    try:
        plan = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ConfigError(f"cannot read dry-run plan: {exc}", "plan_unreadable") from None
    edits = plan.get("edits", [])
    if not isinstance(plan, dict) or not isinstance(edits, list):
        raise ConfigError("dry-run plan must be an object with an 'edits' list", "plan_unreadable")
    for edit in edits:
        if set(edit) - {"path", "old_text", "new_text", "note"} or not {"path", "old_text", "new_text"} <= set(edit):
            raise ConfigError("each dry-run edit needs exactly path/old_text/new_text (+note)", "plan_unreadable")
    return plan
