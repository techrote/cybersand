#!/usr/bin/env python3
"""Validate/render a coordination snapshot without network or wall-clock reads.

The ledger is neither a live GitHub client nor merge authority. Reuse the
hash-pinned PyYAML dependency in tools/requirements-ci-audit.txt.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime
import html
from pathlib import Path
import re
import sys
from typing import Any
from urllib.parse import parse_qs, quote, urlsplit

try:
    import yaml
except ImportError:
    yaml = None

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LEDGER = ROOT / "docs/operations/cybersand-active-work-ledger.yaml"
DEFAULT_OUTPUT = ROOT / "docs/operations/cybersand-active-work-ledger.md"
SEED_IDS = frozenset({
    "IN361-ADMISSION", "IN361-DRAIN", "LCB360-FEEL", "PF201-COST", "PF201-P1",
    "WCONTACT362-A", "MAT353-A", "MAT353-B", "MAT354-LIVENESS", "MAT358-PAIRED",
    "SOL364-CONTACT", "GCR-FLYER-BASE", "GCR-SCOOPER", "PLAY262-MAPS", "SOL364-B",
    "MATSOL-SOURCE", "IN361-VALVE", "IN361-NOZZLE", "MAT354-FIX",
    "MAT355-REACTIONS", "MAT356-LAB", "SOL365-RESTORE", "LCB363-DECISION",
    "PLAY270-ACCEPT",
})
STAGES = frozenset({
    "queued", "implementation_draft", "evidence_draft", "ready_owner_gate",
    "blocked", "no_go", "investigation_complete", "integrated", "deferred",
    "historical", "unknown", "coordination_hold",
})
ACTIVITIES = frozenset({
    "explicitly_stopped", "user_reported_started",
    "published_progress_session_unknown", "unknown", "not_started",
})
RESULTS = frozenset({"pass", "fail", "skipped", "not_run", "inapplicable", "unknown"})
DEPENDENCIES = frozenset({
    "hard", "hard_for_integration", "hard_for_implementation", "stacked",
    "coordination", "source_conflict", "informational",
})
ORDERING_EDGES = frozenset({"hard", "hard_for_integration", "hard_for_implementation", "stacked"})
CLASSIFICATIONS = frozenset({
    "active_relevant", "stacked", "evidence_only", "held_no_go", "historical", "unknown",
})
EVIDENCE_KINDS = frozenset({
    "github_metadata", "github_merge", "workflow_result", "source_receipt",
    "independent_review", "owner_decision", "user_report", "analysis",
    "tree_equivalence", "ownership",
})
AUTHORITIES = frozenset({"verified", "reported", "user_reported", "analysis"})
CONFIDENCE = frozenset({
    "verified_metadata", "reported_evidence", "user_reported", "planning_only", "mixed",
})
SHA = re.compile(r"[0-9a-f]{40}\Z")
IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*\Z")
UTC = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\Z")
MAX_BYTES = 8 * 1024 * 1024


class LedgerError(ValueError):
    """A bounded user-facing input or rendering error."""


if yaml is not None:
    class StrictLoader(yaml.SafeLoader):
        """No duplicate keys, aliases, explicit tags or implicit date objects."""

        yaml_implicit_resolvers = {
            key: [(tag, exp) for tag, exp in value if tag != "tag:yaml.org,2002:timestamp"]
            for key, value in yaml.SafeLoader.yaml_implicit_resolvers.items()
        }

        def __init__(self, stream: str):
            super().__init__(stream)
            self._depth = 0
            self._node_count = 0

        def compose_node(self, parent: Any, index: Any) -> Any:
            if self.check_event(yaml.AliasEvent):
                raise LedgerError("YAML aliases are not permitted in the ledger")
            if getattr(self.peek_event(), "tag", None) is not None:
                raise LedgerError("Explicit YAML tags are not permitted in the ledger")
            self._depth += 1
            self._node_count += 1
            if self._depth > 40 or self._node_count > 200000:
                raise LedgerError("YAML nesting or node count exceeds ledger bounds")
            try:
                return super().compose_node(parent, index)
            finally:
                self._depth -= 1

        def construct_mapping(self, node: Any, deep: bool = False) -> dict[str, Any]:
            if not isinstance(node, yaml.MappingNode):
                raise LedgerError("Expected a YAML mapping")
            result = {}
            for key_node, value_node in node.value:
                key = self.construct_object(key_node, deep=deep)
                if not isinstance(key, str):
                    raise LedgerError("Every YAML mapping key must be a string")
                if key in result:
                    raise LedgerError(f"Duplicate YAML key: {key}")
                result[key] = self.construct_object(value_node, deep=deep)
            return result


def loads_ledger(text: str) -> Any:
    if yaml is None:
        raise LedgerError("PyYAML is missing; install tools/requirements-ci-audit.txt with --require-hashes")
    if len(text.encode("utf-8")) > MAX_BYTES:
        raise LedgerError("Ledger exceeds the 8 MiB input bound")
    try:
        return yaml.load(text, Loader=StrictLoader)
    except (yaml.YAMLError, RecursionError) as exc:
        raise LedgerError(f"Malformed YAML: {exc}") from exc


def load_ledger(path: Path | str) -> Any:
    try:
        path = Path(path)
        if path.stat().st_size > MAX_BYTES:
            raise LedgerError("Ledger exceeds the 8 MiB input bound")
        return loads_ledger(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError) as exc:
        raise LedgerError(f"Cannot read ledger {path}: {exc}") from exc


def utc(value: str) -> datetime:
    if not isinstance(value, str) or not UTC.fullmatch(value):
        raise ValueError("expected an ISO UTC timestamp ending in Z")
    return datetime.fromisoformat(value[:-1] + "+00:00")


@dataclass
class ValidationResult:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


class Validator:
    def __init__(self, data: Any, as_of: str | None = None):
        self.data, self.as_of = data, as_of
        self.result = ValidationResult()
        self.evidence: dict[str, dict] = {}
        self.prs: dict[int, dict] = {}
        self.streams: dict[str, dict] = {}
        self.snapshot: dict = {}
        self.recorded_at: datetime | None = None
        self.repo = ""

    def error(self, path: str, code: str, message: str) -> None:
        self.result.errors.append(f"{path} [{code}]: {message}")

    def mapping(self, value: Any, path: str, required=frozenset(), optional=frozenset()) -> dict:
        if not isinstance(value, dict):
            self.error(path, "type", "expected a mapping")
            return {}
        missing = required - value.keys()
        if missing:
            self.error(path, "missing", "missing fields: " + ", ".join(sorted(missing)))
        if optional is not None:
            extra = value.keys() - required - optional
            if extra:
                self.error(path, "unknown_field", "unknown fields: " + ", ".join(sorted(map(str, extra))))
        return value

    def sequence(self, value: Any, path: str, nonempty: bool = False) -> list:
        if not isinstance(value, list):
            self.error(path, "type", "expected a list")
            return []
        if nonempty and not value:
            self.error(path, "empty", "expected at least one entry")
        return value

    def string(self, value: Any, path: str, nullable: bool = False) -> str | None:
        if nullable and value is None:
            return None
        if not isinstance(value, str) or not value.strip():
            self.error(path, "type", "expected a nonempty string" + (" or null" if nullable else ""))
            return None
        if any(ord(c) < 32 and c not in "\n\t\r" for c in value):
            self.error(path, "control_character", "unsupported control character")
        return value

    def strings(self, value: Any, path: str, nonempty: bool = False, unique: bool = True) -> list[str]:
        values = self.sequence(value, path, nonempty)
        out = [v for i, v in enumerate(values) if self.string(v, f"{path}[{i}]") is not None]
        if unique and len(out) != len(set(out)):
            self.error(path, "duplicate", "duplicate strings")
        return out

    def integer(self, value: Any, path: str, minimum: int = 1) -> int | None:
        if type(value) is not int or value < minimum:
            self.error(path, "type", f"expected an integer >= {minimum}")
            return None
        return value

    def boolean(self, value: Any, path: str, nullable: bool = False) -> bool | None:
        if nullable and value is None:
            return None
        if type(value) is not bool:
            self.error(path, "type", "expected a boolean" + (" or null" if nullable else ""))
            return None
        return value

    def choice(self, value: Any, choices, path: str) -> str | None:
        if not isinstance(value, str) or value not in choices:
            self.error(path, "enum", "expected one of: " + ", ".join(sorted(choices)))
            return None
        return value

    def sha(self, value: Any, path: str, nullable: bool = False) -> str | None:
        if nullable and value is None:
            return None
        if not isinstance(value, str) or not SHA.fullmatch(value):
            self.error(path, "source_identity", "expected a full lowercase 40-character Git SHA" + (" or null" if nullable else ""))
            return None
        return value

    def timestamp(self, value: Any, path: str, nullable: bool = False) -> datetime | None:
        if nullable and value is None:
            return None
        try:
            result = utc(value)
        except (TypeError, ValueError):
            self.error(path, "timestamp", "expected a valid ISO UTC timestamp ending in Z")
            return None
        if self.recorded_at is not None and result > self.recorded_at:
            self.error(path, "future_observation", "observation is later than snapshot.as_of_utc")
        return result

    def url(self, value: Any, path: str) -> str | None:
        if self.string(value, path) is None:
            return None
        try:
            p = urlsplit(value)
            valid = p.scheme == "https" and bool(p.netloc) and p.username is None and p.password is None
        except ValueError:
            valid = False
        if not valid or any(c.isspace() or ord(c) < 32 for c in value):
            self.error(path, "source_link", "expected an HTTPS evidence URL without credentials or whitespace")
            return None
        return value

    def identifier(self, value: Any, path: str) -> str | None:
        if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
            self.error(path, "identifier", "expected a stable ASCII identifier")
            return None
        return value

    def refs(self, value: Any, path: str, nonempty: bool = False) -> list[dict]:
        out = []
        for key in self.strings(value, path, nonempty):
            if key not in self.evidence:
                self.error(path, "evidence_ref", f"unknown evidence ID {key}")
            else:
                out.append(self.evidence[key])
        return out

    def same_source(self, a: dict, b: dict, path: str, a_sha="source_sha", a_tree="source_tree",
                    b_sha="source_sha", b_tree="source_tree") -> bool:
        if a.get(a_sha) != b.get(b_sha) or a.get(a_tree) != b.get(b_tree):
            self.error(path, "source_mismatch", "evidence source SHA/tree does not match the asserted source")
            return False
        return True

    def validate_snapshot(self, root: dict) -> None:
        self.snapshot = self.mapping(root.get("snapshot"), "snapshot", {
            "as_of_utc", "accepted_main", "inventory", "freshness_hours", "limitations",
        }, optional=None)
        self.recorded_at = self.timestamp(self.snapshot.get("as_of_utc"), "snapshot.as_of_utc")
        main = self.mapping(self.snapshot.get("accepted_main"), "snapshot.accepted_main", {"sha", "tree", "url"})
        self.sha(main.get("sha"), "snapshot.accepted_main.sha")
        self.sha(main.get("tree"), "snapshot.accepted_main.tree")
        link = self.url(main.get("url"), "snapshot.accepted_main.url")
        if link and link != f"https://github.com/{self.repo}/commit/{main.get('sha')}":
            self.error("snapshot.accepted_main.url", "source_link", "main URL must name the recorded commit")
        self.integer(self.snapshot.get("freshness_hours"), "snapshot.freshness_hours")
        self.strings(self.snapshot.get("limitations"), "snapshot.limitations", nonempty=True)
        inv = self.mapping(self.snapshot.get("inventory"), "snapshot.inventory", {
            "observed_at", "page_size", "pages", "exhaustive", "observed_open_count",
        })
        self.timestamp(inv.get("observed_at"), "snapshot.inventory.observed_at")
        size = self.integer(inv.get("page_size"), "snapshot.inventory.page_size")
        if size is not None and size > 100:
            self.error("snapshot.inventory.page_size", "pagination", "GitHub PR pages contain at most 100 entries")
        count = self.integer(inv.get("observed_open_count"), "snapshot.inventory.observed_open_count", 0)
        self.boolean(inv.get("exhaustive"), "snapshot.inventory.exhaustive")
        if inv.get("exhaustive") is not True:
            self.error("snapshot.inventory.exhaustive", "pagination", "bootstrap requires exhausted pagination")
        pages = self.sequence(inv.get("pages"), "snapshot.inventory.pages", nonempty=True)
        total, last_count = 0, None
        for i, raw in enumerate(pages):
            path = f"snapshot.inventory.pages[{i}]"
            page = self.mapping(raw, path, {"page", "count", "url"})
            number = self.integer(page.get("page"), path + ".page")
            n = self.integer(page.get("count"), path + ".count", 0)
            u = self.url(page.get("url"), path + ".url")
            if number != i + 1:
                self.error(path, "pagination", "pages must be sequential from 1")
            if n is not None:
                total, last_count = total + n, n
                if size is not None and n > size:
                    self.error(path, "pagination", "page count exceeds page_size")
                if n == 0 and i != len(pages) - 1:
                    self.error(path, "pagination", "an empty page must be terminal")
            if u:
                parsed = urlsplit(u)
                query = parse_qs(parsed.query)
                if (parsed.netloc != "api.github.com" or parsed.path != f"/repos/{self.repo}/pulls"
                        or query.get("state") != ["open"] or query.get("page") != [str(number)]
                        or query.get("per_page") != [str(size)]):
                    self.error(path, "pagination", "page URL must match repository, open state, page and page_size")
        if last_count != 0:
            self.error("snapshot.inventory.pages", "pagination", "retain an explicit terminal empty page")
        if count != total:
            self.error("snapshot.inventory", "inventory_count", "page totals differ from observed_open_count")

    def validate_evidence(self, root: dict) -> None:
        required = {"id", "kind", "url", "observed_at", "summary", "authority"}
        optional = {"subject_pr", "subject_issue", "issue_state", "source_sha", "source_tree",
                    "result", "scope", "platforms", "actor", "decision", "equivalence"}
        for i, raw in enumerate(self.sequence(root.get("evidence"), "evidence", nonempty=True)):
            path = f"evidence[{i}]"
            item = self.mapping(raw, path, required, optional)
            key = self.identifier(item.get("id"), path + ".id")
            if key:
                if key in self.evidence:
                    self.error(path, "duplicate_evidence", f"duplicate evidence ID {key}")
                else:
                    self.evidence[key] = item
            kind = self.choice(item.get("kind"), EVIDENCE_KINDS, path + ".kind")
            self.choice(item.get("authority"), AUTHORITIES, path + ".authority")
            self.url(item.get("url"), path + ".url")
            self.timestamp(item.get("observed_at"), path + ".observed_at")
            self.string(item.get("summary"), path + ".summary")
            for name in ("source_sha", "source_tree"):
                if name in item:
                    self.sha(item[name], path + "." + name, nullable=True)
            if item.get("subject_pr") is not None:
                self.integer(item["subject_pr"], path + ".subject_pr")
            if "subject_issue" in item or "issue_state" in item:
                number = self.integer(item.get("subject_issue"), path + ".subject_issue")
                self.choice(item.get("issue_state"), {"open", "closed"}, path + ".issue_state")
                if (kind != "github_metadata" or item.get("authority") != "verified"
                        or item.get("subject_pr") is not None
                        or item.get("url") not in (
                            f"https://github.com/{self.repo}/issues/{number}",
                            f"https://api.github.com/repos/{self.repo}/issues/{number}")):
                    self.error(path, "issue_authority", "issue state must identify one verified issue, not PR or other-object metadata")
            if item.get("result") is not None:
                self.choice(item["result"], RESULTS, path + ".result")
            if item.get("scope") is not None:
                self.string(item["scope"], path + ".scope")
            if "platforms" in item:
                self.strings(item["platforms"], path + ".platforms")
            for name in ("actor", "decision"):
                if name in item:
                    self.string(item[name], path + "." + name, nullable=True)
            if item.get("result") == "pass":
                self.sha(item.get("source_sha"), path + ".source_sha")
                self.sha(item.get("source_tree"), path + ".source_tree")
                self.string(item.get("scope"), path + ".scope")
                self.strings(item.get("platforms"), path + ".platforms", nonempty=True)
            if kind == "tree_equivalence":
                eq = self.mapping(item.get("equivalence"), path + ".equivalence", {
                    "tested_sha", "tested_tree", "head_sha", "head_tree", "base_sha", "parents", "verified",
                })
                for name in ("tested_sha", "tested_tree", "head_sha", "head_tree", "base_sha"):
                    self.sha(eq.get(name), path + ".equivalence." + name)
                parents = self.strings(eq.get("parents"), path + ".equivalence.parents", nonempty=True)
                for j, value in enumerate(parents):
                    self.sha(value, f"{path}.equivalence.parents[{j}]")
                self.boolean(eq.get("verified"), path + ".equivalence.verified")
                if (eq.get("verified") is not True or item.get("authority") != "verified"
                        or eq.get("tested_tree") != eq.get("head_tree")
                        or parents != [eq.get("base_sha"), eq.get("head_sha")]):
                    self.error(path, "tree_equivalence", "proof needs verified equal trees and exact ordered base/head parents")
            elif "equivalence" in item:
                self.error(path, "tree_equivalence", "equivalence proof must have kind tree_equivalence")

    def validate_prs(self, root: dict) -> None:
        required = {"number", "title", "url", "state", "draft", "merged", "head_ref", "head_sha", "head_tree",
                    "base_ref", "base_sha", "mergeable", "verified_at", "evidence", "merged_at", "merge_commit_sha"}
        for i, raw in enumerate(self.sequence(root.get("pull_requests"), "pull_requests")):
            path = f"pull_requests[{i}]"
            pr = self.mapping(raw, path, required)
            n = self.integer(pr.get("number"), path + ".number")
            if n is not None:
                if n in self.prs:
                    self.error(path, "duplicate_pr", f"duplicate PR metadata #{n}")
                else:
                    self.prs[n] = pr
            for name in ("title", "head_ref", "base_ref"):
                self.string(pr.get(name), path + "." + name)
            link = self.url(pr.get("url"), path + ".url")
            if link and link != f"https://github.com/{self.repo}/pull/{n}":
                self.error(path, "source_link", "PR URL must name its repository and number")
            self.choice(pr.get("state"), {"open", "closed"}, path + ".state")
            self.boolean(pr.get("draft"), path + ".draft")
            self.boolean(pr.get("merged"), path + ".merged")
            self.boolean(pr.get("mergeable"), path + ".mergeable", nullable=True)
            self.sha(pr.get("head_sha"), path + ".head_sha")
            self.sha(pr.get("head_tree"), path + ".head_tree", nullable=True)
            self.sha(pr.get("base_sha"), path + ".base_sha")
            self.sha(pr.get("merge_commit_sha"), path + ".merge_commit_sha", nullable=True)
            self.timestamp(pr.get("verified_at"), path + ".verified_at")
            self.timestamp(pr.get("merged_at"), path + ".merged_at", nullable=True)
            refs = self.refs([pr.get("evidence")], path + ".evidence", nonempty=True)
            if refs:
                ev = refs[0]
                expected_kind = "github_merge" if pr.get("merged") is True else "github_metadata"
                if ev.get("kind") != expected_kind or ev.get("authority") != "verified" or ev.get("subject_pr") != n:
                    self.error(path, "pr_authority", "PR state requires matching verified GitHub metadata/merge evidence")
                if ev.get("source_sha") != pr.get("head_sha") or ev.get("source_tree") != pr.get("head_tree"):
                    self.error(path, "source_mismatch", "PR evidence must match the recorded head SHA/tree")
            if pr.get("merged") is True:
                if pr.get("state") != "closed" or pr.get("merged_at") is None or pr.get("merge_commit_sha") is None:
                    self.error(path, "merge_proof", "merged PR needs closed state, merge time and merge commit")
            elif pr.get("merged_at") is not None or pr.get("merge_commit_sha") is not None:
                self.error(path, "merge_proof", "unmerged PR cannot carry merge identity")

    def validate_coverage(self, root: dict) -> None:
        seen = set()
        indexed: dict[int, dict] = {}
        for i, raw in enumerate(self.sequence(root.get("open_pr_inventory"), "open_pr_inventory")):
            path = f"open_pr_inventory[{i}]"
            row = self.mapping(raw, path, {"pr", "classification", "rationale", "evidence", "observed_at", "workstreams"})
            number = self.integer(row.get("pr"), path + ".pr")
            if number is not None:
                if number in seen:
                    self.error(path, "duplicate_coverage", f"PR #{number} classified more than once")
                seen.add(number)
                indexed[number] = row
            classification = self.choice(row.get("classification"), CLASSIFICATIONS, path + ".classification")
            self.string(row.get("rationale"), path + ".rationale")
            self.timestamp(row.get("observed_at"), path + ".observed_at")
            refs = self.refs([row.get("evidence")], path + ".evidence", nonempty=True)
            ids = self.strings(row.get("workstreams"), path + ".workstreams")
            pr = self.prs.get(number, {})
            if not pr or pr.get("state") != "open" or pr.get("merged") is not False:
                self.error(path, "coverage_state", "inventory must refer to an observed open, unmerged PR")
            if refs and refs[0].get("subject_pr") != number:
                self.error(path, "pr_authority", "coverage evidence refers to a different PR")
            if classification == "stacked" and pr.get("base_ref") == "main":
                self.error(path, "stack_order", "a PR targeting main is not a named-branch stack; retain its prerequisite as a dependency")
            if classification == "active_relevant" and not ids:
                self.error(path, "coverage_lane", "active relevant PR requires a detailed workstream")
            for key in ids:
                linked_prs = self.streams.get(key, {}).get("prs")
                if not isinstance(linked_prs, list) or number not in linked_prs:
                    self.error(path, "coverage_lane", f"workstream {key} does not link this PR")
        expected = {n for n, pr in self.prs.items() if pr.get("state") == "open"}
        if seen != expected:
            self.error("open_pr_inventory", "coverage_complete", f"missing {sorted(expected - seen)}; unexpected {sorted(seen - expected)}")
        inv = self.snapshot.get("inventory") if isinstance(self.snapshot.get("inventory"), dict) else {}
        if len(seen) != inv.get("observed_open_count") or len(expected) != inv.get("observed_open_count"):
            self.error("open_pr_inventory", "inventory_count", "unique coverage, open metadata and observed count must agree")
        for key, stream in self.streams.items():
            numbers = stream.get("prs") if isinstance(stream.get("prs"), list) else []
            for number in numbers:
                if type(number) is int and number in expected:
                    lanes = indexed.get(number, {}).get("workstreams")
                    if not isinstance(lanes, list) or key not in lanes:
                        self.error(key, "coverage_lane", f"open PR #{number} index omits this detailed lane")

    def validate_workstreams(self, root: dict) -> None:
        required = {"id", "programme", "title", "scope", "priority", "issues", "prs", "primary_pr", "delivery_stage",
                    "stage_evidence", "agent_activity", "activity_evidence", "review_disposition", "qualification",
                    "merge_approval", "source_confidence", "verified_at", "ownership", "dependencies", "blockers",
                    "next_action", "notes"}
        rows = self.sequence(root.get("workstreams"), "workstreams", nonempty=True)
        for i, raw in enumerate(rows):
            path = f"workstreams[{i}]"
            row = self.mapping(raw, path, required)
            key = self.identifier(row.get("id"), path + ".id")
            if key:
                if key in self.streams:
                    self.error(path, "duplicate_id", f"duplicate workstream ID {key}")
                else:
                    self.streams[key] = row
            for name in ("programme", "title", "scope"):
                self.string(row.get(name), path + "." + name)
            self.integer(row.get("priority"), path + ".priority")
            stage = self.choice(row.get("delivery_stage"), STAGES, path + ".delivery_stage")
            activity = self.choice(row.get("agent_activity"), ACTIVITIES, path + ".agent_activity")
            confidence = self.choice(row.get("source_confidence"), CONFIDENCE, path + ".source_confidence")
            self.timestamp(row.get("verified_at"), path + ".verified_at")
            self.strings(row.get("notes"), path + ".notes", unique=False)
            stage_refs = self.refs(row.get("stage_evidence"), path + ".stage_evidence")
            if stage in {"implementation_draft", "evidence_draft", "ready_owner_gate", "no_go",
                         "investigation_complete", "integrated", "historical", "coordination_hold"} and not stage_refs:
                self.error(path, "stage_authority", "this delivery stage requires source evidence")
            if confidence in {"user_reported", "planning_only"} and stage in {
                    "implementation_draft", "evidence_draft", "ready_owner_gate", "investigation_complete", "integrated"}:
                self.error(path, "delivery_authority", "user report/planning alone cannot establish a published or qualified deliverable")
            activity_refs = self.refs(row.get("activity_evidence"), path + ".activity_evidence")
            if activity == "user_reported_started" and not any(
                    e.get("kind") == "user_report" and e.get("decision") == "started" for e in activity_refs):
                self.error(path, "activity_authority", "a launched-chat claim requires an explicit user-reported started disposition")
            if activity == "explicitly_stopped" and not any(
                    e.get("kind") in ("user_report", "ownership") and e.get("decision") in ("stopped", "released")
                    for e in activity_refs):
                self.error(path, "activity_authority", "stopped sessions require an explicit stopped/released disposition")
            if activity == "published_progress_session_unknown" and not any(
                    e.get("kind") in ("github_metadata", "github_merge") and e.get("authority") == "verified" for e in activity_refs):
                self.error(path, "activity_authority", "published activity requires verified artifact metadata")
            valid_numbers = []
            for j, number in enumerate(self.sequence(row.get("prs"), path + ".prs")):
                if self.integer(number, f"{path}.prs[{j}]") is not None:
                    valid_numbers.append(number)
                    if number not in self.prs:
                        self.error(path, "pr_ref", f"unknown PR #{number}")
            if len(valid_numbers) != len(set(valid_numbers)):
                self.error(path, "duplicate_pr_ref", "duplicate PR references in one lane")
            primary = row.get("primary_pr")
            if primary is not None:
                self.integer(primary, path + ".primary_pr")
                if primary not in valid_numbers:
                    self.error(path, "pr_ref", "primary_pr must occur in prs")
            elif valid_numbers:
                self.error(path, "pr_ref", "a linked PR population needs one primary_pr")
            pr = self.prs.get(primary, {}) if type(primary) is int else {}
            if stage in {"implementation_draft", "evidence_draft", "investigation_complete", "ready_owner_gate"} and not pr:
                self.error(path, "delivery_authority", "a published delivery stage requires a verified primary PR artifact")
            if activity == "published_progress_session_unknown" and not any(
                    e.get("kind") in ("github_metadata", "github_merge") and e.get("authority") == "verified"
                    and type(e.get("subject_pr")) is int and e.get("subject_pr") in valid_numbers for e in activity_refs):
                self.error(path, "activity_authority", "published activity evidence must identify one of this lane's actual PRs")
            for j, raw_issue in enumerate(self.sequence(row.get("issues"), path + ".issues")):
                ip = f"{path}.issues[{j}]"
                issue = self.mapping(raw_issue, ip, {"number", "url", "state", "evidence"})
                n = self.integer(issue.get("number"), ip + ".number")
                u = self.url(issue.get("url"), ip + ".url")
                if u and u != f"https://github.com/{self.repo}/issues/{n}":
                    self.error(ip, "source_link", "issue URL must name its repository and number")
                state = self.choice(issue.get("state"), {"open", "closed", "unknown"}, ip + ".state")
                if state != "unknown" or issue.get("evidence") is not None:
                    ir = self.refs([issue.get("evidence")], ip + ".evidence", nonempty=True)
                    if ir and (ir[0].get("kind") != "github_metadata" or ir[0].get("authority") != "verified"
                               or ir[0].get("subject_issue") != n or ir[0].get("issue_state") != state
                               or ir[0].get("url") not in (
                                   f"https://github.com/{self.repo}/issues/{n}",
                                   f"https://api.github.com/repos/{self.repo}/issues/{n}")):
                        self.error(ip, "issue_authority", "observed issue state requires matching verified issue number, URL and state")
            self.validate_review(row, pr, path)
            self.validate_approval(row, pr, path)
            self.validate_ownership(row, pr, path)
            self.validate_qualifications(row, pr, path)
            self.validate_blockers(row, path)
            action = self.mapping(row.get("next_action"), path + ".next_action", {
                "text", "responsible", "owner_decision_required", "owner_decision", "stop_condition",
            })
            for name in ("text", "responsible", "stop_condition"):
                self.string(action.get(name), path + ".next_action." + name)
            decision_required = self.boolean(action.get("owner_decision_required"), path + ".next_action.owner_decision_required")
            self.string(action.get("owner_decision"), path + ".next_action.owner_decision", nullable=decision_required is not True)
            if decision_required is False and action.get("owner_decision") is not None:
                self.error(path, "owner_decision", "a recorded pending question must set owner_decision_required")
            if stage == "integrated" and not (pr and pr.get("merged") is True and pr.get("state") == "closed"):
                self.error(path, "integration_authority", "integrated requires a verified merged primary PR")
        seed_ids = self.strings(root.get("seed_ids"), "seed_ids", nonempty=True)
        if set(seed_ids) != SEED_IDS:
            self.error("seed_ids", "seed_coverage", "retain exactly the 24 supplied provisional IDs; additions belong in workstreams")
        if not SEED_IDS.issubset(self.streams):
            self.error("workstreams", "seed_coverage", "missing seeded lanes: " + ", ".join(sorted(SEED_IDS - self.streams.keys())))

    def validate_review(self, row: dict, pr: dict, path: str) -> None:
        review = self.mapping(row.get("review_disposition"), path + ".review_disposition", {
            "status", "evidence", "source_sha", "source_tree", "summary",
        })
        status = self.choice(review.get("status"), {"pass", "fail", "conditional", "pending", "unknown", "not_required"},
                             path + ".review_disposition.status")
        refs = self.refs(review.get("evidence"), path + ".review_disposition.evidence")
        self.string(review.get("summary"), path + ".review_disposition.summary")
        self.sha(review.get("source_sha"), path + ".review_disposition.source_sha", nullable=status != "pass")
        self.sha(review.get("source_tree"), path + ".review_disposition.source_tree", nullable=status != "pass")
        if status == "pass":
            independent = [e for e in refs if e.get("kind") == "independent_review"
                           and e.get("authority") == "verified" and e.get("result") == "pass"
                           and e.get("subject_pr") == pr.get("number")]
            if not independent:
                self.error(path, "review_authority", "PASS requires verified independent review evidence, not self-review/recommendation")
            for ev in independent:
                self.same_source(review, ev, path + ".review_disposition")
            if not pr or review.get("source_sha") != pr.get("head_sha") or review.get("source_tree") != pr.get("head_tree"):
                self.error(path, "review_source", "accepted review must bind the current primary PR head/tree")

    def validate_approval(self, row: dict, pr: dict, path: str) -> None:
        approval = self.mapping(row.get("merge_approval"), path + ".merge_approval", {"status", "evidence", "head_sha", "head_tree"})
        status = self.choice(approval.get("status"), {"not_recorded", "granted", "withheld", "not_required"}, path + ".merge_approval.status")
        refs = self.refs(approval.get("evidence"), path + ".merge_approval.evidence")
        self.sha(approval.get("head_sha"), path + ".merge_approval.head_sha", nullable=status != "granted")
        self.sha(approval.get("head_tree"), path + ".merge_approval.head_tree", nullable=status != "granted")
        if status == "granted":
            owner = self.repo.split("/", 1)[0]
            decisions = [e for e in refs if e.get("kind") == "owner_decision" and e.get("authority") == "verified"
                         and e.get("actor") == owner and e.get("decision") == "approve_merge"
                         and e.get("subject_pr") == pr.get("number")]
            if not decisions:
                self.error(path, "approval_authority", "merge approval requires the owner's explicit approve_merge decision for this PR")
            for ev in decisions:
                self.same_source(approval, ev, path + ".merge_approval", a_sha="head_sha", a_tree="head_tree")
            if not pr or approval.get("head_sha") != pr.get("head_sha") or approval.get("head_tree") != pr.get("head_tree"):
                self.error(path, "approval_source", "owner approval does not cover a different or missing PR head/tree")
        elif status == "not_recorded" and (refs or approval.get("head_sha") is not None or approval.get("head_tree") is not None):
            self.error(path, "approval_authority", "not_recorded must not carry an approval identity/reference")
        elif status == "withheld" and not any(
                e.get("kind") == "owner_decision" and e.get("authority") == "verified"
                and e.get("actor") == self.repo.split("/", 1)[0] for e in refs):
            self.error(path, "approval_authority", "withheld requires an explicit owner decision")

    def validate_ownership(self, row: dict, pr: dict, path: str) -> None:
        owner = self.mapping(row.get("ownership"), path + ".ownership", {
            "status", "writer_id", "branch", "role", "owner_group", "evidence",
        })
        status = self.choice(owner.get("status"), {"unknown", "claimed", "released", "collision"}, path + ".ownership.status")
        self.choice(owner.get("role"), {"coordination", "implementation", "evidence", "review", "planned"}, path + ".ownership.role")
        for name in ("writer_id", "branch", "owner_group"):
            self.string(owner.get(name), path + ".ownership." + name, nullable=status != "claimed")
        refs = self.refs(owner.get("evidence"), path + ".ownership.evidence")
        if status in {"claimed", "released", "collision"} and not any(e.get("kind") in ("ownership", "user_report") for e in refs):
            self.error(path, "ownership_authority", "ownership claims require an explicit custody/handover record")
        if status == "claimed" and pr and owner.get("branch") != pr.get("head_ref"):
            self.error(path, "ownership_branch", "claimed writer branch must match the primary PR")
        if status == "collision" and row.get("delivery_stage") != "coordination_hold":
            self.error(path, "ownership_collision", "a writer collision must remain coordination_hold")

    def validate_qualifications(self, row: dict, pr: dict, path: str) -> None:
        seen = set()
        for i, raw in enumerate(self.sequence(row.get("qualification"), path + ".qualification")):
            qp = f"{path}.qualification[{i}]"
            q = self.mapping(raw, qp, {"id", "scope", "result", "platforms", "source_sha", "source_tree", "binding",
                                      "evidence", "required_for_ready", "runtime", "limitations"})
            key = self.identifier(q.get("id"), qp + ".id")
            if key:
                if key in seen:
                    self.error(qp, "duplicate_gate", f"duplicate qualification gate {key}")
                seen.add(key)
            result = self.choice(q.get("result"), RESULTS, qp + ".result")
            binding = self.choice(q.get("binding"), {"exact_head", "historical", "tree_equivalent", "not_applicable"}, qp + ".binding")
            self.string(q.get("scope"), qp + ".scope")
            platforms = self.strings(q.get("platforms"), qp + ".platforms", nonempty=result == "pass")
            self.sha(q.get("source_sha"), qp + ".source_sha", nullable=result != "pass")
            self.sha(q.get("source_tree"), qp + ".source_tree", nullable=result != "pass")
            refs = self.refs(q.get("evidence"), qp + ".evidence", nonempty=result in {"pass", "fail", "skipped", "inapplicable"})
            self.boolean(q.get("required_for_ready"), qp + ".required_for_ready")
            self.string(q.get("runtime"), qp + ".runtime")
            self.string(q.get("limitations"), qp + ".limitations")
            if result == "pass" and isinstance(q.get("runtime"), str) and q["runtime"].strip().lower().replace("_", " ") in {
                    "not executed", "not run", "unknown", "unavailable", "n/a", "none"}:
                self.error(qp, "runtime_identity", "PASS cannot name an explicitly unexecuted/unknown runtime")
            if result == "pass" and binding == "not_applicable":
                self.error(qp, "pass_identity", "PASS cannot omit a source binding")
            outcomes = [e for e in refs if e.get("result") is not None]
            matching = [e for e in outcomes if e.get("result") == result and e.get("scope") == q.get("scope")]
            if result == "pass":
                matching = [e for e in matching if e.get("kind") in ("source_receipt", "workflow_result")
                            and e.get("authority") in ("verified", "reported")]
            if result in {"pass", "fail", "skipped", "inapplicable"} and not matching:
                self.error(qp, "result_authority", "result requires evidence with the same result and exact scope")
            if outcomes and not matching:
                self.error(qp, "result_scope", "evidence does not establish the claimed outcome/scope")
            coverage = set()
            for ev in matching:
                self.same_source(q, ev, qp)
                ev_platforms = ev.get("platforms") if isinstance(ev.get("platforms"), list) else []
                coverage.update(x for x in ev_platforms if isinstance(x, str))
                if ev.get("subject_pr") is not None and ev.get("subject_pr") != pr.get("number"):
                    self.error(qp, "result_pr", "result evidence belongs to a different primary PR")
            if result == "pass" and not set(platforms).issubset(coverage):
                self.error(qp, "platform_scope", "claimed platforms exceed result evidence")
            if binding == "exact_head" and (not pr or q.get("source_sha") != pr.get("head_sha")
                                            or q.get("source_tree") != pr.get("head_tree")):
                self.error(qp, "source_mismatch", "exact_head result must match the current primary PR SHA/tree")
            if binding == "tree_equivalent":
                proofs = [e.get("equivalence") for e in refs if e.get("kind") == "tree_equivalence"
                          and isinstance(e.get("equivalence"), dict)]
                valid = any(eq.get("verified") is True and eq.get("tested_sha") == q.get("source_sha")
                            and eq.get("tested_tree") == q.get("source_tree") and eq.get("head_sha") == pr.get("head_sha")
                            and eq.get("head_tree") == pr.get("head_tree") and eq.get("base_sha") == pr.get("base_sha")
                            and eq.get("tested_tree") == eq.get("head_tree")
                            and eq.get("parents") == [pr.get("base_sha"), pr.get("head_sha")] for eq in proofs)
                if not valid:
                    self.error(qp, "tree_equivalence", "synthetic-merge result needs verified current tree/parent equivalence")
            if result == "inapplicable" and binding != "not_applicable":
                self.error(qp, "inapplicable", "inapplicable scope needs not_applicable binding and evidence-backed rationale")

    def validate_blockers(self, row: dict, path: str) -> None:
        seen, unresolved = set(), []
        for i, raw in enumerate(self.sequence(row.get("blockers"), path + ".blockers")):
            bp = f"{path}.blockers[{i}]"
            blocker = self.mapping(raw, bp, {"id", "kind", "summary", "evidence", "resolved"})
            key = self.identifier(blocker.get("id"), bp + ".id")
            if key:
                if key in seen:
                    self.error(bp, "duplicate_blocker", f"duplicate blocker {key}")
                seen.add(key)
            self.choice(blocker.get("kind"), {"physical", "source", "ci", "owner", "coordination", "qualification"}, bp + ".kind")
            self.string(blocker.get("summary"), bp + ".summary")
            self.refs(blocker.get("evidence"), bp + ".evidence")
            if self.boolean(blocker.get("resolved"), bp + ".resolved") is False:
                unresolved.append(blocker)
        stage = row.get("delivery_stage") if isinstance(row.get("delivery_stage"), str) else None
        if any(b.get("kind") == "physical" for b in unresolved) and stage not in {"no_go", "blocked", "coordination_hold"}:
            self.error(path, "physical_no_go", "an unresolved physical blocker cannot be lifted by a CPU/CI subgate")
        if stage == "no_go" and not unresolved:
            self.error(path, "no_go_authority", "NO-GO must retain its unresolved failed-gate/blocker evidence")
        if stage in {"ready_owner_gate", "integrated"} and unresolved:
            self.error(path, "unresolved_blocker", "ready/integrated cannot have unresolved blockers")

    def validate_dependencies(self) -> None:
        graph: dict[str, list[str]] = defaultdict(list)
        claims: dict[str, list[tuple[str, dict]]] = defaultdict(list)
        branch_prs = {p["head_ref"]: p for p in self.prs.values() if isinstance(p.get("head_ref"), str)}
        for key, row in self.streams.items():
            path = f"workstream {key}"
            primary = row.get("primary_pr")
            pr = self.prs.get(primary, {}) if type(primary) is int else {}
            seen, stack_targets = set(), set()
            for i, raw in enumerate(self.sequence(row.get("dependencies"), path + ".dependencies")):
                dp = f"{path}.dependencies[{i}]"
                edge = self.mapping(raw, dp, {"id", "type", "reason"})
                target = self.identifier(edge.get("id"), dp + ".id")
                kind = self.choice(edge.get("type"), DEPENDENCIES, dp + ".type")
                self.string(edge.get("reason"), dp + ".reason")
                pair = (target, kind)
                if pair in seen:
                    self.error(dp, "duplicate_dependency", "duplicate typed dependency")
                seen.add(pair)
                if target == key:
                    self.error(dp, "self_dependency", "a workstream cannot depend on itself")
                if target not in self.streams:
                    self.error(dp, "dependency_ref", f"unknown workstream {target}")
                    continue
                if kind in ORDERING_EDGES:
                    graph[key].append(target)
                target_row = self.streams[target]
                target_pr_num = target_row.get("primary_pr")
                target_pr = self.prs.get(target_pr_num, {}) if type(target_pr_num) is int else {}
                if kind == "stacked":
                    if not pr or not target_pr or pr.get("base_ref") != target_pr.get("head_ref"):
                        self.error(dp, "stack_order", "stacked dependency must match actual base and prerequisite head branch")
                    if target_pr.get("merged") is True:
                        self.error(dp, "stack_order", "merged prerequisite needs reconciliation to an integration dependency")
                    stack_targets.add(target_pr_num if type(target_pr_num) is int else None)
                if row.get("delivery_stage") == "ready_owner_gate" and kind in ORDERING_EDGES and target_row.get("delivery_stage") != "integrated":
                    self.error(dp, "dependency_gate", "ready status cannot bypass an unintegrated hard/stacked prerequisite")
            base_ref = pr.get("base_ref")
            parent_pr = branch_prs.get(base_ref) if isinstance(base_ref, str) else None
            if parent_pr and parent_pr.get("number") != pr.get("number"):
                detailed_parent = any(s.get("primary_pr") == parent_pr.get("number") for s in self.streams.values())
                if detailed_parent and parent_pr.get("merged") is False and parent_pr.get("number") not in stack_targets:
                    self.error(path, "stack_missing", "actual named-branch stack is absent from typed dependencies")
            ownership = row.get("ownership") if isinstance(row.get("ownership"), dict) else {}
            if ownership.get("status") == "claimed" and isinstance(ownership.get("branch"), str):
                claims[ownership["branch"]].append((key, ownership))
        visiting, done = set(), set()

        def visit(key: str, trail: list[str]) -> None:
            if key in visiting:
                self.error("dependencies", "dependency_cycle", " -> ".join(trail + [key]))
                return
            if key in done:
                return
            visiting.add(key)
            for child in graph.get(key, []):
                visit(child, trail + [key])
            visiting.remove(key)
            done.add(key)

        for key in sorted(self.streams):
            visit(key, [])
        for branch, owners in claims.items():
            signatures = {(owner.get("writer_id"), owner.get("owner_group")) for _, owner in owners
                          if isinstance(owner.get("writer_id"), str) and isinstance(owner.get("owner_group"), str)}
            if len(signatures) > 1:
                self.error("ownership", "duplicate_writer", f"branch {branch} has competing claimed owners: {', '.join(k for k, _ in owners)}")
            scopes = [self.streams[k].get("scope") for k, _ in owners]
            if len(scopes) != len(set(s for s in scopes if isinstance(s, str))):
                self.error("ownership", "duplicate_scope", f"shared branch {branch} repeats one lane's scope")

    def validate_ready(self) -> None:
        main = self.snapshot.get("accepted_main") if isinstance(self.snapshot.get("accepted_main"), dict) else {}
        for key, row in self.streams.items():
            if row.get("delivery_stage") != "ready_owner_gate":
                continue
            path = f"workstream {key}"
            primary = row.get("primary_pr")
            pr = self.prs.get(primary, {}) if type(primary) is int else {}
            if not pr or pr.get("state") != "open" or pr.get("draft") is not False or pr.get("mergeable") is not True:
                self.error(path, "ready_metadata", "ready_owner_gate requires an open Ready, currently mergeable PR")
            if pr.get("base_ref") != "main" or pr.get("base_sha") != main.get("sha"):
                self.error(path, "ready_base", "ready source must target recorded accepted main")
            review = row.get("review_disposition") if isinstance(row.get("review_disposition"), dict) else {}
            if review.get("status") != "pass":
                self.error(path, "ready_review", "ready_owner_gate requires verified independent exact-head review")
            gates = row.get("qualification") if isinstance(row.get("qualification"), list) else []
            required = [q for q in gates if isinstance(q, dict) and q.get("required_for_ready") is True]
            if not required:
                self.error(path, "ready_gates", "ready status must declare at least one required qualification gate")
            for q in required:
                ids = q.get("evidence") if isinstance(q.get("evidence"), list) else []
                refs = [self.evidence[e] for e in ids if isinstance(e, str) and e in self.evidence]
                verified = [e for e in refs if e.get("authority") == "verified" and e.get("result") == q.get("result")
                            and e.get("scope") == q.get("scope")
                            and e.get("source_sha") == q.get("source_sha")
                            and e.get("source_tree") == q.get("source_tree")
                            and (q.get("result") != "pass" or e.get("kind") in ("source_receipt", "workflow_result"))]
                backed = bool(verified)
                if q.get("result") not in ("pass", "inapplicable") or not backed:
                    self.error(path, "ready_gates", f"required gate {q.get('id')} is not a verified PASS or justified inapplicable result")
                if q.get("result") == "pass":
                    covered = {platform for e in verified
                               for platform in (e.get("platforms") if isinstance(e.get("platforms"), list) else [])
                               if isinstance(platform, str)}
                    platforms = q.get("platforms") if isinstance(q.get("platforms"), list) else []
                    if any(not isinstance(p, str) or p not in covered for p in platforms):
                        self.error(path, "ready_platform_scope", "every required claimed platform must have matching verified result evidence")
                if q.get("result") == "pass" and q.get("binding") not in ("exact_head", "tree_equivalent"):
                    self.error(path, "ready_source", "historical results cannot qualify the current head")

    def validate_log(self, root: dict) -> None:
        covered = set()
        for i, raw in enumerate(self.sequence(root.get("change_log"), "change_log", nonempty=True)):
            path = f"change_log[{i}]"
            row = self.mapping(raw, path, {"at", "workstreams", "summary", "evidence"})
            self.timestamp(row.get("at"), path + ".at")
            self.string(row.get("summary"), path + ".summary")
            self.refs(row.get("evidence"), path + ".evidence", nonempty=True)
            for key in self.strings(row.get("workstreams"), path + ".workstreams", nonempty=True):
                if key not in self.streams:
                    self.error(path, "change_ref", f"unknown workstream {key}")
                covered.add(key)
        if set(self.streams) - covered:
            self.error("change_log", "change_coverage", "missing provenance for " + ", ".join(sorted(set(self.streams) - covered)))

    def validate_staleness(self) -> None:
        if self.as_of is None:
            return
        try:
            now = utc(self.as_of)
        except (TypeError, ValueError):
            self.error("as_of", "timestamp", "--as-of must be an explicit ISO UTC timestamp")
            return
        if self.recorded_at is None:
            return
        if now < self.recorded_at:
            self.error("as_of", "timestamp", "--as-of precedes the recorded snapshot")
            return
        threshold = self.snapshot.get("freshness_hours")
        if type(threshold) is not int or threshold < 1:
            return
        hours = (now - self.recorded_at).total_seconds() / 3600
        if hours > threshold:
            self.result.warnings.append(f"snapshot is {hours:.1f} hours old; revalidate source before decisions (threshold {threshold}h)")
        for key, row in sorted(self.streams.items()):
            if type(row.get("priority")) is int and row["priority"] <= 10:
                try:
                    age = (now - utc(row.get("verified_at"))).total_seconds() / 3600
                except (TypeError, ValueError):
                    continue
                if age > threshold:
                    self.result.warnings.append(f"{key} last corroborated {age:.1f} hours ago; activity/stage unchanged")

    def run(self) -> ValidationResult:
        root = self.mapping(self.data, "ledger", {
            "schema_version", "repository", "snapshot", "seed_ids", "evidence",
            "pull_requests", "open_pr_inventory", "workstreams", "change_log",
        }, optional=None)
        if type(root.get("schema_version")) is not int or root.get("schema_version") != 1:
            self.error("schema_version", "version", "only schema_version 1 is supported")
        self.repo = self.string(root.get("repository"), "repository") or ""
        if self.repo != "techrote/cybersand":
            self.error("repository", "repository", "this ledger schema is for techrote/cybersand")
        self.validate_snapshot(root)
        self.validate_evidence(root)
        self.validate_prs(root)
        self.validate_workstreams(root)
        self.validate_coverage(root)
        self.validate_dependencies()
        self.validate_ready()
        self.validate_log(root)
        self.validate_staleness()
        return self.result


def validate(data: Any, as_of: str | None = None) -> ValidationResult:
    """Return authority/structure failures without rewriting the input."""
    return Validator(data, as_of).run()


def md(value: Any) -> str:
    """Escape untrusted text for single-line Markdown table cells/headings."""
    value = html.escape(" ".join(str(value).split()), quote=False)
    value = re.sub(r"([\\*_{}\[\]()#+.!|>~-])", r"\\\1", value)
    return value.replace(chr(96), "\\" + chr(96))


def link(label: Any, url: str) -> str:
    # Quotes/brackets/parentheses cannot escape a Markdown link destination.
    return f"[{md(label)}]({quote(url, safe=':/?#&=%+@~.-_')})"


def render(data: Any) -> str:
    result = validate(data)
    if not result.ok:
        raise LedgerError("Cannot render invalid ledger:\n" + "\n".join(result.errors))
    snapshot = data["snapshot"]
    prs = {p["number"]: p for p in data["pull_requests"]}
    evidence = {e["id"]: e for e in data["evidence"]}
    rows = sorted(data["workstreams"], key=lambda s: (s["priority"], s["id"]))
    by_id = {s["id"]: s for s in rows}
    classifications = Counter(p["classification"] for p in data["open_pr_inventory"])
    stages = Counter(s["delivery_stage"] for s in rows)
    date = snapshot["as_of_utc"][:10]
    tick = chr(96)

    def code(value: str) -> str:
        # Only validated hexadecimal identities/constants are passed here.
        return tick + value + tick

    lines = [
        "---", "title: CyberSand active work ledger", "status: Ambiguous", "document-kind: navigation",
        "scope: Dated coordination snapshot, source identities, decisions and work ownership; no subsystem behavior authority",
        "canonical-for: []", f"last-reviewed: {date}",
        "related-documents: [active-work-ledger-maintenance.md, cybersand-codex-development-handover.md, ../reference/status-and-roadmap.md]",
        "---", "", "# CyberSand active work ledger", "",
        "<!-- Generated by tools/operations/active_work_ledger.py; edit the YAML only. -->", "",
        f"**Source snapshot:** {md(snapshot['as_of_utc'])}. **Detailed lanes:** {len(rows)}. "
        f"**Observed open PRs:** {len(data['open_pr_inventory'])}; **unknown classifications:** {classifications['unknown']}.", "",
        f"**Accepted main:** {link(snapshot['accepted_main']['sha'], snapshot['accepted_main']['url'])}; "
        f"tree {code(snapshot['accepted_main']['tree'])}.", "",
        "This page coordinates work. Canonical subsystem contracts and source-qualified receipts own behavior and acceptance. "
        "An open PR establishes an artifact; it does not establish a running chat. Ready state, executed checks, independent review "
        "and owner merge approval remain separate. No row authorizes a merge or a new feature writer.", "",
        "Edit [the canonical YAML](cybersand-active-work-ledger.yaml); follow the "
        "[single-steward maintenance workflow](active-work-ledger-maintenance.md). "
        "Normal rendering reads neither the network nor the current clock.", "",
        "## Contents", "",
        "- [Now and top decisions](#now-and-top-decisions) — bounded next actions for the highest-priority lanes.",
        "- [Owner approval gates](#owner-approval-gates) — pending questions and explicitly evidenced approval state.",
        "- [Ready or qualifying](#ready-or-qualifying) — source identity, actual qualification outcomes and review limits.",
        "- [Published work and uncertain agent activity](#published-work-and-uncertain-agent-activity) — artifact progress without inferred live sessions.",
        "- [Blocked and physical NO-GO](#blocked-and-physical-no-go) — retained failures and unresolved blockers.",
        "- [Dependencies and stacked integration](#dependencies-and-stacked-integration) — typed prerequisites, stack order and source conflicts.",
        "- [Queued, deferred, integrated and historical](#queued-deferred-integrated-and-historical) — parked work and verified accepted foundations.",
        "- [Evidence exceptions, staleness and full PR coverage](#evidence-exceptions-staleness-and-full-pr-coverage) — retrieval limits, source receipts and exhaustive classification.", "",
    ]

    def pr_links(row: dict) -> str:
        return ", ".join(link(f"#{n}", prs[n]["url"]) for n in row["prs"]) or "No published PR"

    def refs(ids: list[str]) -> str:
        return ", ".join(link(key, evidence[key]["url"]) for key in ids) or "Not recorded"

    def table(headers: list[str], records: list[list[str]]) -> None:
        lines.append("| " + " | ".join(headers) + " |")
        lines.append("| " + " | ".join("---" for _ in headers) + " |")
        lines.extend("| " + " | ".join(record) + " |" for record in records)
        lines.append("")

    def heading(text: str) -> None:
        lines.extend(["## " + text, ""])

    heading("Now and top decisions")
    now_rows = [s for s in rows if s["priority"] <= 10
                and s["delivery_stage"] not in {"integrated", "historical", "deferred", "queued"}]
    table(["Lane / PR", "Delivery / review / approval", "Bounded next action", "Responsible / stop"], [
        [f"**{md(s['id'])}** {pr_links(s)}",
         f"{md(s['delivery_stage'])} / {md(s['review_disposition']['status'])} / {md(s['merge_approval']['status'])}",
         md(s["next_action"]["text"]),
         md(s["next_action"]["responsible"] + "; " + s["next_action"]["stop_condition"])]
        for s in now_rows
    ])
    heading("Owner approval gates")
    owner_rows = [s for s in rows if s["next_action"]["owner_decision_required"]
                  or s["merge_approval"]["status"] in {"granted", "withheld"}]
    if not owner_rows:
        lines.extend(["No owner decision is recorded as immediately actionable in this snapshot.", ""])
    else:
        table(["Lane / PR", "Decision / approval", "Evidence and retained limits"], [
            [f"{md(s['id'])} {pr_links(s)}",
             md((s["next_action"]["owner_decision"] or "No pending question") + "; merge approval: " + s["merge_approval"]["status"]),
             refs(s["merge_approval"]["evidence"]) + "; " + md(s["next_action"]["stop_condition"])]
            for s in owner_rows
        ])
    lines.extend(["A recommendation or positive handling comment is not a merge decision. A decision about checkpoint compatibility "
                  "does not grant feature integration approval.", ""])
    heading("Ready or qualifying")
    for s in [s for s in rows if s["prs"] and s["delivery_stage"] not in {"integrated", "historical"}]:
        pr = prs[s["primary_pr"]]
        mergeable = str(pr["mergeable"]).lower() if pr["mergeable"] is not None else "unknown"
        lines.extend([
            f"### {md(s['id'])} — {md(s['title'])}", "",
            f"{pr_links(s)} · delivery **{md(s['delivery_stage'])}** · GitHub "
            f"{'Draft' if pr['draft'] else 'Ready'} · review **{md(s['review_disposition']['status'])}** · "
            f"merge approval **{md(s['merge_approval']['status'])}**.", "",
            f"Head {code(pr['head_sha'])}; tree {code(pr['head_tree'] or 'unknown')}. "
            f"Branch {md(pr['head_ref'])} targets {md(pr['base_ref'])} at {code(pr['base_sha'])}. "
            f"Mergeable: **{mergeable}**. Last verified: {md(s['verified_at'])}.", "",
            f"**Scope:** {md(s['scope'])}", "",
            f"**Review:** {md(s['review_disposition']['summary'])} {refs(s['review_disposition']['evidence'])}.", "",
        ])
        if s["qualification"]:
            qrows = []
            for q in sorted(s["qualification"], key=lambda q: q["id"]):
                source = (code(q["source_sha"]) + " / " + code(q["source_tree"] or "unknown")
                          if q["source_sha"] else "Not executed / unknown source")
                authorities = sorted({evidence[key]["authority"] for key in q["evidence"]
                                      if evidence[key].get("result") == q["result"]})
                qrows.append([
                    md(q["id"] + (" (required)" if q["required_for_ready"] else "")),
                    f"**{q['result'].upper()}** · {md(', '.join(authorities) or 'not asserted')}",
                    md(q["scope"] + "; " + ", ".join(q["platforms"])) + "; " + md(q["runtime"]),
                    source + "; " + md(q["binding"]),
                    refs(q["evidence"]) + "; " + md(q["limitations"]),
                ])
            table(["Gate", "Result / evidence authority", "Scope / platform / runtime",
                   "Tested SHA / tree / binding", "Receipt / limitations"], qrows)
        else:
            lines.extend(["No execution result is asserted for this lane; publication metadata alone is not qualification.", ""])
        lines.extend([f"**Next:** {md(s['next_action']['text'])} **Stop:** {md(s['next_action']['stop_condition'])}", ""])
        if s["notes"]:
            lines.extend(["**Retained notes:** " + " ".join(md(note) for note in s["notes"]), ""])
    heading("Published work and uncertain agent activity")
    table(["Lane / PR", "Agent activity", "Branch custody", "Confidence / last verified"], [
        [f"{md(s['id'])} {pr_links(s)}", md(s["agent_activity"]) + "; " + refs(s["activity_evidence"]),
         md(s["ownership"]["status"] + "; writer " + (s["ownership"]["writer_id"] or "unknown")
            + "; group " + (s["ownership"]["owner_group"] or "unknown")),
         md(s["source_confidence"] + "; " + s["verified_at"])]
        for s in rows
    ])
    heading("Blocked and physical NO-GO")
    blocked = [s for s in rows if s["delivery_stage"] in {"blocked", "no_go", "coordination_hold"}
               or any(not b["resolved"] for b in s["blockers"])]
    table(["Lane / PR", "Disposition", "Unresolved blocker / evidence", "Next action"], [
        [f"{md(s['id'])} {pr_links(s)}", f"**{md(s['delivery_stage'])}**",
         "; ".join(md(b["kind"] + ": " + b["summary"]) + " " + refs(b["evidence"])
                   for b in s["blockers"] if not b["resolved"]) or "Dependency/decision hold; see next action",
         md(s["next_action"]["text"])]
        for s in blocked
    ])
    lines.extend(["A CPU-cost or hosted-build PASS does not clear physical NO-GO, source compatibility, device/input acceptance "
                  "or an independent review gate. Historical passes keep their tested source identity.", ""])
    heading("Dependencies and stacked integration")
    edges = [(s, d) for s in rows for d in sorted(s["dependencies"], key=lambda d: (d["type"], d["id"]))]
    table(["Prerequisite / related lane", "Dependent lane", "Edge type", "State / reason"], [
        [f"{md(d['id'])} {pr_links(by_id[d['id']])}", f"{md(s['id'])} {pr_links(s)}", md(d["type"]),
         md(by_id[d["id"]]["delivery_stage"] + "; " + d["reason"])]
        for s, d in edges
    ])
    lines.extend(["Hard and stacked edges encode execution/integration order. Coordination and source-conflict edges warn of "
                  "shared authority; they never authorize another branch writer or a source-lock refresh.", ""])
    heading("Queued, deferred, integrated and historical")
    parked = [s for s in rows if s["delivery_stage"] in {
        "queued", "deferred", "integrated", "historical", "unknown", "investigation_complete",
    }]
    table(["Lane / PR", "Delivery", "Evidence / scope", "Bounded next action"], [
        [f"{md(s['id'])} {pr_links(s)}", md(s["delivery_stage"]), refs(s["stage_evidence"]) + "; " + md(s["scope"]),
         md(s["next_action"]["text"])] for s in parked
    ])
    lines.extend(["Merged child PRs do not close their parent programme. Historical and queued lanes are not automatically relaunched.", ""])
    heading("Evidence exceptions, staleness and full PR coverage")
    lines.extend([
        f"**Freshness threshold:** {snapshot['freshness_hours']} hours. The page retains the recorded source timestamp. "
        f"Run {code('validate --as-of YYYY-MM-DDTHH:MM:SSZ')} to obtain an explicit-time staleness warning; "
        "staleness never rewrites delivery or activity.", "",
    ])
    for limitation in snapshot["limitations"]:
        lines.append("- " + md(limitation))
    lines.extend(["", "### Inventory exhaustion", ""])
    table(["Page", "Observed entries", "Read-only source"], [
        [str(p["page"]), str(p["count"]), link("GitHub PR page", p["url"])]
        for p in snapshot["inventory"]["pages"]
    ])
    lines.extend([
        f"Captured {md(snapshot['inventory']['observed_at'])}; terminal empty page retained. "
        f"All {snapshot['inventory']['observed_open_count']} observed open PRs are classified below. "
        "This inventory precedes the ledger PR's own publication; later PRs require a new steward snapshot.", "",
    ])
    table(["Classification", "Count"], [[md(k), str(classifications[k])] for k in sorted(CLASSIFICATIONS)])
    table(["PR", "Classification / lanes", "Observed branch / head", "Rationale / source"], [
        [link(f"#{p['pr']} {prs[p['pr']]['title']}", prs[p["pr"]]["url"]),
         md(p["classification"] + "; " + (", ".join(p["workstreams"]) or "no detailed lane")),
         md(prs[p["pr"]]["head_ref"]) + " / " + code(prs[p["pr"]]["head_sha"]),
         md(p["rationale"]) + " " + refs([p["evidence"]]) + "; " + md(p["observed_at"])]
        for p in sorted(data["open_pr_inventory"], key=lambda p: p["pr"])
    ])
    lines.extend(["### Evidence register", ""])
    table(["ID / source", "Kind / authority", "Observed / original tested source", "Scoped statement"], [
        [link(e["id"], e["url"]), md(e["kind"] + " / " + e["authority"]),
         md(e["observed_at"]) + ("; " + code(e["source_sha"]) + " / " + code(e.get("source_tree") or "unknown")
                                 if e.get("source_sha") else "; no execution identity asserted"),
         md(e["summary"])]
        for e in sorted(data["evidence"], key=lambda e: e["id"])
    ])
    lines.extend(["### Dated reconciliation log", ""])
    table(["Source time", "Lanes", "Change / retained evidence"], [
        [md(e["at"]), md(", ".join(sorted(e["workstreams"]))), md(e["summary"]) + " " + refs(e["evidence"])]
        for e in sorted(data["change_log"], key=lambda e: (e["at"], ",".join(sorted(e["workstreams"])), e["summary"]))
    ])
    lines.extend(["### Delivery census", ""])
    table(["Delivery stage", "Detailed lanes"], [[md(k), str(stages[k])] for k in sorted(stages)])
    return "\n".join(lines).rstrip() + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "render", "check", "summary"))
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="render/check dashboard path")
    parser.add_argument("--as-of", help="explicit UTC time for staleness warnings; never rendered")
    args = parser.parse_args(argv)
    if args.as_of and args.command != "validate":
        parser.error("--as-of is supported only by validate; render/check use the recorded snapshot")
    try:
        data = load_ledger(args.ledger)
        result = validate(data, args.as_of)
        for message in result.warnings:
            print("WARNING " + message, file=sys.stderr)
        if not result.ok:
            for message in result.errors:
                print("ERROR " + message, file=sys.stderr)
            return 1
        if args.command == "validate":
            print(f"PASS: {len(data['workstreams'])} workstreams; {len(data['open_pr_inventory'])} "
                  f"classified open PRs; source snapshot {data['snapshot']['as_of_utc']}")
        elif args.command in {"render", "check"}:
            output = render(data).encode("utf-8")
            if args.command == "render":
                if args.output.resolve() == args.ledger.resolve():
                    raise LedgerError("Output must not overwrite the canonical YAML")
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_bytes(output)
                print(f"Rendered {args.output}")
            else:
                try:
                    actual = args.output.read_bytes()
                except OSError as exc:
                    raise LedgerError(f"Cannot check dashboard {args.output}: {exc}") from exc
                if actual != output:
                    print(f"FAIL: {args.output} is not the deterministic rendering; run render", file=sys.stderr)
                    return 1
                print("PASS: dashboard is byte-identical to canonical YAML rendering")
        else:
            print(f"Snapshot {data['snapshot']['as_of_utc']}; main {data['snapshot']['accepted_main']['sha']}")
            print(f"{len(data['workstreams'])} workstreams; {len(data['open_pr_inventory'])} open PRs")
            for stage, count in sorted(Counter(w["delivery_stage"] for w in data["workstreams"]).items()):
                print(f"{stage}: {count}")
        return 0
    except (LedgerError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
