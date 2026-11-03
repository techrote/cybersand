#!/usr/bin/env python3
"""Inventory every Actions workflow and enforce bounded, evidence-aware scheduling.

Install tools/requirements-ci-audit.txt first. This parses YAML rather than
guessing indentation. It deliberately does not evaluate arbitrary Actions
expressions: dynamic fan-out is reported as unknown, never as one job.
Actionlint remains the independent workflow syntax/expression validator.
"""
from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path
from typing import Any

import yaml


class WorkflowLoader(yaml.BaseLoader):
    """Keep Actions' `on` and booleans as strings; reject duplicate YAML keys."""

    def construct_mapping(self, node, deep=False):
        result = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if key in result:
                raise ValueError(f"duplicate YAML key: {key}")
            result[key] = self.construct_object(value_node, deep=deep)
        return result


ROUTINE_PREFIXES = {
    "documentation.yml": "docs",
    "gdextension.yml": "gdextension",
    "native.yml": "native",
    "native-scope-advisory.yml": "native-scope-advisory",
    "issue49-water-apparatus.yml": "issue49-water",
}
RUN_ISOLATED_CAMPAIGNS = {
    "physical-timeout-stress.yml", "play-busy001a-pool.yml",
    "play-busy001b-host.yml", "play-desktop-packet.yml", "play-life009.yml",
}


def routine_concurrency(prefix: str) -> dict[str, str]:
    return {
        "group": prefix + "-${{ github.event_name }}-${{ github.event_name == 'pull_request' && github.event.pull_request.number || github.run_id }}",
        "cancel-in-progress": "${{ github.event_name == 'pull_request' }}",
    }


def matrix_cardinality(matrix: Any) -> int | None:
    """Count literal Cartesian matrices using Actions include/exclude semantics."""
    if not isinstance(matrix, dict):
        return None
    axes = {k: v for k, v in matrix.items() if k not in {"include", "exclude"}}
    if any(not isinstance(v, list) for v in axes.values()):
        return None
    include, exclude = matrix.get("include", []), matrix.get("exclude", [])
    if not isinstance(include, list) or not isinstance(exclude, list):
        return None
    if any(not isinstance(row, dict) for row in include + exclude):
        return None
    # An expression nested in an axis object cannot be expanded here either.
    if "${{" in json.dumps(matrix):
        return None
    originals = [dict(zip(axes, values)) for values in itertools.product(*axes.values())] if axes else []
    originals = [row for row in originals if not any(
        all(row.get(k) == v for k, v in omitted.items()) for omitted in exclude)]
    expanded = [dict(row) for row in originals]
    added = []
    for addition in include:
        matches = [i for i, row in enumerate(originals) if all(
            k not in row or row[k] == v for k, v in addition.items())]
        if matches:
            for i in matches:
                expanded[i].update(addition)
        else:
            added.append(addition)
    return len(expanded) + len(added)


def inventory(root: Path) -> dict[str, Any]:
    workflows = []
    paths = sorted((root / ".github/workflows").glob("*.y*ml"))
    for path in paths:
        data = yaml.load(path.read_text(encoding="utf-8"), Loader=WorkflowLoader)
        if not isinstance(data, dict) or not isinstance(data.get("jobs"), dict):
            raise ValueError(f"{path.name}: workflow/jobs must be mappings")
        triggers = data.get("on", {})
        if isinstance(triggers, str):
            triggers = {triggers: None}
        elif isinstance(triggers, list):
            triggers = dict.fromkeys(triggers)
        if not isinstance(triggers, dict):
            raise ValueError(f"{path.name}: invalid workflow triggers")
        jobs = []
        for name, job in data["jobs"].items():
            strategy = job.get("strategy", {})
            matrix = strategy.get("matrix")
            count = matrix_cardinality(matrix) if matrix is not None else 1
            cap = strategy.get("max-parallel")
            slots = int(cap) if isinstance(cap, str) and cap.isdigit() else count
            if slots is not None and count is not None:
                slots = min(count, slots)
            jobs.append({
                "id": name, "name": job.get("name", name), "if": job.get("if"),
                "needs": job.get("needs", []), "runs_on": job.get("runs-on"),
                "reusable_workflow": job.get("uses"), "strategy": strategy,
                "literal_matrix_jobs": count,
                "matrix_job_count_known": count is not None,
                "runner_slots_upper_bound": None if job.get("uses") else slots,
                "timeout_minutes": job.get("timeout-minutes"),
                "concurrency": job.get("concurrency"),
            })
        workflows.append({
            "file": path.relative_to(root).as_posix(), "name": data.get("name"),
            "triggers": triggers, "concurrency": data.get("concurrency"),
            "jobs": jobs,
            "known_job_instances_before_conditions": sum(j["literal_matrix_jobs"] or 0 for j in jobs),
            "unresolved_matrix_jobs": [j["id"] for j in jobs if not j["matrix_job_count_known"]],
        })
    return {
        "schema": "cybersand-workflow-inventory-v1", "workflow_count": len(workflows),
        "interpretation": "Counts precede job conditions; dynamic expressions and reusable descendants require their actual plans. Per-matrix slot bounds are not an account-wide cap.",
        "workflows": workflows,
    }


def check(report: dict[str, Any]) -> list[str]:
    errors = []
    for workflow in report["workflows"]:
        filename = Path(workflow["file"]).name
        concurrency = workflow["concurrency"] or {}
        if filename in ROUTINE_PREFIXES and concurrency != routine_concurrency(ROUTINE_PREFIXES[filename]):
            errors.append(f"{filename}: routine PR supersession must preserve independent manual/main runs")
        if "workflow_dispatch" in workflow["triggers"] and concurrency.get("cancel-in-progress") == "true":
            errors.append(f"{filename}: unconditional cancellation can discard a requested manual run")
        if filename in RUN_ISOLATED_CAMPAIGNS and (
                "github.run_id" not in concurrency.get("group", "") or
                concurrency.get("cancel-in-progress") != "false"):
            errors.append(f"{filename}: qualification requests need independent non-cancelling run groups")
        for job in workflow["jobs"]:
            strategy = job["strategy"]
            if "matrix" not in strategy:
                continue
            label = filename + "/" + job["id"]
            if strategy.get("fail-fast") != "false":
                errors.append(f"{label}: independent evidence matrices must disable fail-fast")
            cap = strategy.get("max-parallel")
            if cap is None:
                # The unchanged, provenance-bound Rapier producer has only two
                # literal variants per OS; this is already a hard fan-out bound.
                count = job["literal_matrix_jobs"]
                if filename != "rapier-bvh-build.yml" or count is None or count > 2:
                    errors.append(f"{label}: matrix requires an explicit max-parallel")
            elif not isinstance(cap, str) or not cap.isdigit() or not 1 <= int(cap) <= 8:
                errors.append(f"{label}: matrix max-parallel must be a literal integer in 1..8")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = inventory(args.root.resolve())
    report["errors"] = check(report)
    report["status"] = "failed" if report["errors"] else "passed"
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
        print(json.dumps({"status": report["status"], "workflows": report["workflow_count"], "errors": report["errors"], "output": str(args.output)}))
    else:
        print(rendered, end="")
    return int(bool(report["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
