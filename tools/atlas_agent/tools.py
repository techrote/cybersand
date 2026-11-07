"""Narrow model-callable tools: schema, execution, accounting and boundary enforcement.

Model tool calls are untrusted input. Arguments are validated against the tool's own
schema before any action; paths go through :class:`PathPolicy`; processes run only
through fixed argument vectors for the chosen *kind*; every call is counted against
the configured limits.
"""
from __future__ import annotations

import copy
import hashlib
import json
import time
from dataclasses import dataclass, field
from pathlib import Path

from . import atlas, captures
from .errors import LimitReached, SandboxViolation, ToolError, ValidationFailed
from .procs import resolve_executables
from .sandbox import PathPolicy, sha256_bytes
from .schema import validate

RUBRIC = ["silhouette_scale_hierarchy", "architectural_geologic_richness", "authentic_micro_detail",
          "value_colour_discipline", "environmental_narrative", "coherent_integrated_composition",
          "cross_theme_distinctiveness"]
_BOUND_KEYS = ("minimum", "maximum", "minLength", "maxLength", "minItems", "maxItems", "pattern",
               "exclusiveMinimum")


def _obj(properties: dict) -> dict:
    return {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}


_S = lambda max_len=400: {"type": "string", "maxLength": max_len}  # noqa: E731
_PATH = {"type": "string", "minLength": 1, "maxLength": 300}

TOOL_SPECS: dict[str, dict] = {
    "list_files": {
        "description": "List files you are allowed to read, optionally under a workspace-relative prefix "
                       "(empty string lists everything readable). Shows which are writable.",
        "parameters": _obj({"prefix": {"type": "string", "maxLength": 300}}),
    },
    "read_file": {
        "description": "Read a line range of an approved text file (UTF-8). Long files must be read in ranges.",
        "parameters": _obj({"path": _PATH, "start_line": {"type": "integer", "minimum": 1},
                            "max_lines": {"type": "integer", "minimum": 1, "maximum": 400}}),
    },
    "inspect_pack": {
        "description": "Summarise a pack.json: metadata, palette (material ids), features with sizes/statuses, "
                       "scenes and rectangle counts, plus the pack SHA-256.",
        "parameters": _obj({"collection": {"type": "string", "minLength": 2, "maxLength": 64}}),
    },
    "run_validator": {
        "description": "Run the collection's own repository script with a fixed argument list. kind=validate runs "
                       "validate_pack; render_check verifies preview.svg matches pack.json; render_write regenerates "
                       "preview.svg (only for the collection you may edit). Returns the real exit code and output.",
        "parameters": _obj({"collection": {"type": "string", "minLength": 2, "maxLength": 64},
                            "kind": {"enum": ["validate", "render_check", "render_write"]}}),
    },
    "list_captures": {
        "description": "List verified rendered image evidence (input bundle and any bundle rendered in this run), "
                       "including the evidence class: 'godot-capture' (real renderer) or 'fixture' (flat raster, "
                       "NOT Godot output).",
        "parameters": _obj({}),
    },
    "view_image": {
        "description": "Attach one verified PNG capture to the conversation so you can critique its pixels. "
                       "Limited number of images per run.",
        "parameters": _obj({"bundle": {"enum": ["input", "rendered"]}, "shot_id": {"type": "string", "maxLength": 80},
                            "collection": {"type": "string", "maxLength": 64}}),
    },
    "render_capture": {
        "description": "Re-render the edited workspace pack with the unattended Godot capture tool. Returns "
                       "'unavailable' when no renderer is configured; never fabricates an image.",
        "parameters": _obj({"label": {"enum": ["after"]}}),
    },
    "compare_captures": {
        "description": "Compare the input bundle with the bundle rendered in this run (pack/RG8/PNG hashes, framing).",
        "parameters": _obj({}),
    },
    "replace_text": {
        "description": "Replace one exact, unique occurrence of old_text with new_text in an assigned file. "
                       "Only the files marked writable by list_files can be edited; the result must still parse.",
        "parameters": _obj({"path": _PATH, "old_text": {"type": "string", "minLength": 1, "maxLength": 20000},
                            "new_text": {"type": "string", "maxLength": 20000}}),
    },
    "submit_report": {
        "description": "Finish the run with a structured critique and proposals. Call exactly once when done.",
        "parameters": _obj({
            "outcome": {"enum": ["improved", "no_change", "critique_only", "blocked"]},
            "summary": _S(1500),
            "visual_evidence_used": {"type": "boolean"},
            "critique": {"type": "array", "maxItems": 7, "items": _obj({
                "dimension": {"enum": RUBRIC}, "score_0_to_5": {"type": "integer", "minimum": 0, "maximum": 5},
                "evidence": _S(600)})},
            "revision_proposals": {"type": "array", "maxItems": 8, "items": _obj({
                "target": _S(200), "change": _S(600), "rationale": _S(400)})},
            "edits_applied": {"type": "array", "maxItems": 10, "items": _S(300)},
            "validation_notes": _S(800),
        }),
    },
}


def strip_bounds(schema):
    """Remove keywords the strict function-calling subset does not need (kept for local validation)."""
    if isinstance(schema, dict):
        return {k: strip_bounds(v) for k, v in schema.items() if k not in _BOUND_KEYS}
    if isinstance(schema, list):
        return [strip_bounds(v) for v in schema]
    return schema


def tool_definitions(names: list[str]) -> list[dict]:
    return [{"type": "function", "name": n, "description": TOOL_SPECS[n]["description"],
             "parameters": strip_bounds(copy.deepcopy(TOOL_SPECS[n]["parameters"])), "strict": True} for n in names]


def tools_sha256() -> str:
    return hashlib.sha256(json.dumps(TOOL_SPECS, sort_keys=True).encode()).hexdigest()


@dataclass
class ToolOutcome:
    text: str
    ok: bool
    error_code: str | None = None
    attachments: list[dict] = field(default_factory=list)
    report: dict | None = None


class ToolExecutor:
    def __init__(self, cfg: dict, work_root: Path, policy: PathPolicy, collection: str, writable: bool,
                 extras: list[str], redactor, executables: dict[str, str] | None = None,
                 input_bundle: Path | None = None, launcher: Path | None = None, out_dir: Path | None = None):
        self.cfg, self.limits, self.task = cfg, cfg["limits"], cfg["task"]
        self.work_root, self.policy, self.collection = Path(work_root), policy, collection
        self.writable, self.extras, self.redactor = writable, extras, redactor
        self.executables = executables or resolve_executables()
        self.input_bundle, self.launcher, self.out_dir = input_bundle, launcher, out_dir
        self.rendered_bundle: Path | None = None
        self.tool_calls = 0
        self.malformed = 0
        self.violations = 0
        self.tool_seconds = 0.0
        self.files_edited: set[str] = set()
        self.images: dict[str, dict] = {}  # sha256 -> record
        self.image_bytes = 0
        self.validation: list[dict] = []
        self.edits: list[dict] = []
        self.render_attempts: list[dict] = []
        self.comparison: dict | None = None
        self.bundle_summaries: dict[str, dict] = {}
        self.records: list[dict] = []
        self._shots: dict[str, dict[tuple, dict]] = {}

    # ------------------------------------------------------------- advertised set
    def tool_names(self) -> list[str]:
        names = ["list_files", "read_file", "inspect_pack", "run_validator"]
        if self.input_bundle or self.launcher:
            names += ["list_captures", "view_image"]
        if self.launcher:
            names.append("render_capture")
        if self.input_bundle and self.launcher:
            names.append("compare_captures")
        if self.writable:
            names.append("replace_text")
        names.append("submit_report")
        return names

    # ------------------------------------------------------------------ dispatch
    def execute(self, name: str, raw_arguments: object, call_no: int) -> ToolOutcome:
        if self.tool_calls >= int(self.limits["max_tool_calls"]):
            raise LimitReached(f"reached max_tool_calls={self.limits['max_tool_calls']}", "max_tool_calls")
        if self.tool_seconds >= float(self.limits["max_total_tool_seconds"]):
            raise LimitReached("max_total_tool_seconds exhausted", "max_total_tool_seconds")
        self.tool_calls += 1
        started = time.monotonic()
        args_text = raw_arguments if isinstance(raw_arguments, str) else json.dumps(raw_arguments, default=str)
        record = {"n": call_no, "name": str(name)[:60], "args_sha256": sha256_bytes(args_text.encode("utf-8", "replace")),
                  "ok": False, "error_code": None}
        outcome: ToolOutcome
        try:
            if name not in self.tool_names():
                raise ToolError("unknown_tool", f"tool {str(name)[:40]!r} is not available in this run")
            args = self._parse(name, raw_arguments)
            outcome = getattr(self, f"_t_{name}")(args)
        except ToolError as exc:
            if exc.code in ("malformed_arguments", "unknown_tool"):
                self.malformed += 1
            outcome = ToolOutcome(json.dumps({"error": exc.code, "message": exc.message}), False, exc.code)
        except SandboxViolation as exc:
            self.violations += 1
            record["violation"] = exc.reason_code
            outcome = ToolOutcome(json.dumps({"error": exc.reason_code, "message": exc.message}), False,
                                  exc.reason_code)
            if self.violations >= int(self.limits["max_sandbox_violations"]):
                self._finish(record, outcome, started)
                raise
        self._finish(record, outcome, started)
        if self.malformed > int(self.limits["max_malformed_tool_calls"]):
            raise LimitReached("too many malformed tool calls", "max_malformed_tool_calls")
        return outcome

    def _finish(self, record: dict, outcome: ToolOutcome, started: float) -> None:
        text = self.redactor.text(outcome.text)
        limit = int(self.limits["max_tool_output_bytes"])
        raw = text.encode("utf-8")
        if len(raw) > limit:
            text = raw[:limit].decode("utf-8", errors="ignore") + "\n[output truncated by max_tool_output_bytes]"
        outcome.text = text
        elapsed = time.monotonic() - started
        self.tool_seconds += elapsed
        record.update({"ok": outcome.ok, "error_code": outcome.error_code, "duration_ms": int(elapsed * 1000),
                       "output_sha256": sha256_bytes(text.encode("utf-8")), "output_bytes": len(text.encode("utf-8"))})
        self.records.append(record)

    def _parse(self, name: str, raw: object) -> dict:
        try:
            args = json.loads(raw) if isinstance(raw, str) else raw
        except ValueError:
            raise ToolError("malformed_arguments", "arguments are not valid JSON") from None
        if not isinstance(args, dict):
            raise ToolError("malformed_arguments", "arguments must be a JSON object")
        problems = validate(args, TOOL_SPECS[name]["parameters"])
        if problems:
            raise ToolError("malformed_arguments", "; ".join(problems[:4]))
        return args

    def _budget_timeout(self) -> float:
        return max(1.0, min(float(self.limits["max_tool_seconds"]),
                            float(self.limits["max_total_tool_seconds"]) - self.tool_seconds))

    def _known_collection(self, collection: str) -> str:
        if collection != self.collection and collection not in self.extras:
            raise SandboxViolation(f"collection {collection!r} is outside this run's approved set", "read_not_permitted")
        return collection

    # ---------------------------------------------------------------------- tools
    def _t_list_files(self, a: dict) -> ToolOutcome:
        prefix = a["prefix"]
        if prefix:
            prefix = self.policy.normalise(prefix.rstrip("/"))
        rows = []
        for path in sorted(self.work_root.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(self.work_root).as_posix()
            if (prefix and not (rel == prefix or rel.startswith(prefix + "/"))) or not self.policy.is_readable(rel):
                continue
            rows.append({"path": rel, "bytes": path.stat().st_size, "writable": self.policy.is_writable(rel)})
        shown = rows[:200]
        return ToolOutcome(json.dumps({"files": shown, "total": len(rows), "truncated": len(rows) > len(shown)}), True)

    def _t_read_file(self, a: dict) -> ToolOutcome:
        result = self.policy.read_text(a["path"], a["start_line"], a["max_lines"], int(self.limits["max_read_bytes"]))
        return ToolOutcome(json.dumps(result), True)

    def _t_inspect_pack(self, a: dict) -> ToolOutcome:
        collection = self._known_collection(a["collection"])
        self.policy.check_read(f"{atlas.WORLD_DESIGN}/{collection}/pack.json")
        return ToolOutcome(json.dumps(atlas.inspect_pack(self.work_root, collection)), True)

    def _t_run_validator(self, a: dict) -> ToolOutcome:
        if a["collection"] != self.collection:
            raise SandboxViolation("validators run only for the selected collection", "read_not_permitted")
        if a["kind"] == "render_write" and not self.writable:
            raise SandboxViolation("this lane has no write custody for the collection", "write_not_permitted")
        try:
            result = atlas.run_script(self.work_root, self.collection, a["kind"], self._budget_timeout(),
                                      int(self.limits["max_tool_output_bytes"]) // 2, self.executables)
        except ValidationFailed as exc:
            raise ToolError(exc.reason_code, exc.message) from None
        self.validation.append({"n": len(self.validation) + 1, "collection": self.collection, "kind": a["kind"],
                                "script": result["script"], "script_sha256": result["script_sha256"],
                                "argv": result["argv_public"], "exit_code": result["exit_code"],
                                "passed": result["passed"], "timed_out": result["timed_out"],
                                "duration_seconds": result["duration_seconds"],
                                "stdout_tail": self.redactor.text(result["stdout"][-600:]),
                                "stderr_tail": self.redactor.text(result["stderr"][-600:])})
        return ToolOutcome(json.dumps({k: result[k] for k in ("kind", "script", "exit_code", "passed", "timed_out",
                                                               "stdout", "stderr", "output_truncated")}), True)

    # captures ------------------------------------------------------------------
    def _bundle_dir(self, which: str) -> Path | None:
        return self.input_bundle if which == "input" else self.rendered_bundle

    def _load_bundle(self, which: str) -> dict:
        directory = self._bundle_dir(which)
        if directory is None:
            raise ToolError("bundle_unavailable", f"no {which} capture bundle exists in this run")
        if which not in self.bundle_summaries:
            _, shots, _ = captures.verify_bundle(directory)
            self._shots[which] = {(s["collection"], s["shot_id"]): s for s in shots}
            self.bundle_summaries[which] = captures.summarize_bundle(directory, which)
        return self.bundle_summaries[which]

    def _t_list_captures(self, a: dict) -> ToolOutcome:
        found = {}
        for which in ("input", "rendered"):
            if self._bundle_dir(which) is not None:
                found[which] = self._load_bundle(which)
        if not found:
            return ToolOutcome(json.dumps({"bundles": {}, "note": "no capture evidence available"}), True)
        return ToolOutcome(json.dumps({"bundles": found}), True)

    def _t_view_image(self, a: dict) -> ToolOutcome:
        summary = self._load_bundle(a["bundle"])
        collection = a["collection"] or self.collection
        shot = self._shots[a["bundle"]].get((collection, a["shot_id"]))
        if shot is None:
            raise ToolError("unknown_shot", "no such shot in that bundle (see list_captures)")
        data, info = captures.load_shot_for_model(shot, int(self.limits["max_image_bytes"]),
                                                  int(self.limits["max_image_edge_pixels"]))
        sha = shot["png_sha256"]
        if sha not in self.images:
            if len(self.images) >= int(self.limits["max_images"]):
                raise LimitReached(f"reached max_images={self.limits['max_images']}", "max_images")
            if self.image_bytes + len(data) > int(self.limits["max_total_image_bytes"]):
                raise LimitReached("max_total_image_bytes would be exceeded", "max_total_image_bytes")
            self.image_bytes += len(data)
            self.images[sha] = {"bundle": a["bundle"], "collection": collection, "shot_id": a["shot_id"],
                                "sha256": sha, "bytes": len(data), "width": info["width"], "height": info["height"],
                                "evidence_class": summary["evidence_class"], "sent_in_calls": []}
        return ToolOutcome(json.dumps({"attached": True, "sha256": sha, "width": info["width"],
                                       "height": info["height"], "evidence_class": summary["evidence_class"],
                                       "note": "the image follows in the next message"}), True,
                           attachments=[{"sha256": sha, "data": data, "width": info["width"],
                                         "height": info["height"]}])

    def _t_render_capture(self, a: dict) -> ToolOutcome:
        if self.launcher is None or self.out_dir is None:
            return ToolOutcome(json.dumps({"status": "unavailable", "reason": "no capture launcher configured"}), True)
        target = self.out_dir / "captures" / "after"
        pack_dir = self.work_root / atlas.WORLD_DESIGN / self.collection
        try:
            outcome = captures.run_capture(self.launcher, self.task.get("godot") or "", pack_dir, target,
                                           self._budget_timeout(), self.executables)
        except Exception as exc:  # configuration problems are reported to the model, not crashed on
            outcome = {"status": "unavailable", "reason": str(exc)[:200]}
        self.render_attempts.append({k: v for k, v in outcome.items() if k != "stderr_tail"})
        if outcome.get("status") == "completed":
            self.rendered_bundle = target
            self.bundle_summaries.pop("rendered", None)
            try:
                self._load_bundle("rendered")
            except ToolError as exc:
                outcome = {"status": "failed", "reason": exc.code}
        return ToolOutcome(json.dumps({k: v for k, v in outcome.items() if k != "bundle"}), True)

    def _t_compare_captures(self, a: dict) -> ToolOutcome:
        if self.input_bundle is None or self.rendered_bundle is None:
            raise ToolError("bundle_unavailable", "both an input bundle and a rendered bundle are required")
        self.comparison = captures.compare_bundles(self.input_bundle, self.rendered_bundle)
        return ToolOutcome(json.dumps(self.comparison), True)

    # edits ---------------------------------------------------------------------
    def _t_replace_text(self, a: dict) -> ToolOutcome:
        clean, path = self.policy.check_write(a["path"])
        if clean not in self.files_edited and len(self.files_edited) >= int(self.limits["max_files_edited"]):
            raise LimitReached(f"max_files_edited={self.limits['max_files_edited']} reached", "max_files_edited")
        original = path.read_bytes() if path.is_file() else None
        result = self.policy.replace_text(clean, a["old_text"], a["new_text"], int(self.limits["max_edit_bytes"]),
                                          int(self.limits["max_read_bytes"]) * 8)
        problems = self._post_edit_problems(clean, path)
        if problems:
            path.write_bytes(original or b"")  # restore: the edit must leave a parseable pack
            raise ToolError("edit_rejected", problems)
        self.files_edited.add(clean)
        self.edits.append({"n": len(self.edits) + 1, "path": clean, "before_sha256": result["before_sha256"],
                           "after_sha256": result["after_sha256"], "bytes_removed": result["bytes_removed"],
                           "bytes_added": result["bytes_added"]})
        return ToolOutcome(json.dumps({"edited": clean, "after_sha256": result["after_sha256"],
                                       "note": "re-run run_validator before relying on this edit"}), True)

    def _post_edit_problems(self, rel: str, path: Path) -> str:
        if not rel.endswith(".json"):
            return ""
        try:
            parsed = json.loads(path.read_text(encoding="utf-8"))
        except ValueError as exc:
            return f"edited JSON no longer parses: {exc}"
        if rel.endswith("/pack.json") and (parsed.get("schema_id") != "cybersand.world-feature-pack.proposal"
                                           or parsed.get("schema_version") != 1):
            return "pack schema_id/schema_version must not change"
        return ""

    # report --------------------------------------------------------------------
    def _t_submit_report(self, a: dict) -> ToolOutcome:
        if a["outcome"] == "improved" and not self.edits:
            raise ToolError("report_inconsistent", "outcome 'improved' requires at least one applied edit")
        if a["visual_evidence_used"] and not self.images:
            raise ToolError("report_inconsistent", "visual_evidence_used is true but no image was viewed")
        return ToolOutcome(json.dumps({"accepted": True}), True, report=a)
