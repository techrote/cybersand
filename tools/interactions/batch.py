#!/usr/bin/env python3
"""INT-000 generated-fixture, batch evidence and pass-comparison driver.

This tool deliberately delegates fixture construction and execution to the
repository's schema-2 Godot scripts. It does not implement material semantics.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
from typing import Any

FIXTURES: dict[str, int] = {
    "materials/salt-water": 120,
    "materials/sand-water-control": 120,
    "materials/lava-water": 120,
    "materials/fire-gunpowder": 120,
    "materials/acid-metal": 120,
    "materials/spark-metal": 120,
    "materials/cement-water": 240,
}
BATCH_SCHEMA = "cybersand.int-evidence-batch"
BATCH_VERSION = 1


def run_command(command: list[str], cwd: pathlib.Path) -> None:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
    if completed.stdout:
        sys.stdout.write(completed.stdout)
    if completed.stderr:
        sys.stderr.write(completed.stderr)
    if completed.returncode != 0:
        raise RuntimeError(f"command failed ({completed.returncode}): {' '.join(command)}")


def godot_base(godot: str, root: pathlib.Path, script: str) -> list[str]:
    return [godot, "--headless", "--path", str(root / "godot"), "--script", script, "--"]


def generate(args: argparse.Namespace) -> int:
    root = pathlib.Path(args.root).resolve()
    output = pathlib.Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    command = godot_base(args.godot, root, "res://tests/export_microscenario_definition.gd")
    command += [f"--scenario={args.scenario}", f"--seed={args.seed}", f"--output={output}"]
    run_command(command, root)
    return 0


def interaction_catalogue(profile: dict[str, Any]) -> dict[str, Any]:
    return {
        key: profile.get(key, [] if key not in {"catalogue_validation"} else {})
        for key in [
            "schema_id",
            "schema_version",
            "profile_id",
            "profile_version",
            "channels",
            "layer_kinds",
            "families",
            "authored_layers",
            "pair_rules",
            "specialized_rules",
            "coverage",
            "tuning_passes",
            "catalogue_validation",
        ]
    }


def coverage_gaps(coverage: list[dict[str, Any]]) -> list[dict[str, Any]]:
    gaps: list[dict[str, Any]] = []
    for entry in coverage:
        if (
            entry.get("authored_status") == "untested"
            or entry.get("evidence_status") in {"none", "deferred_revalidation"}
        ):
            gaps.append(entry)
    return gaps


def coverage_summary(coverage: list[dict[str, Any]]) -> dict[str, dict[str, int]]:
    authored: dict[str, int] = {}
    evidence: dict[str, int] = {}
    for entry in coverage:
        a = str(entry.get("authored_status", "unknown"))
        e = str(entry.get("evidence_status", "unknown"))
        authored[a] = authored.get(a, 0) + 1
        evidence[e] = evidence.get(e, 0) + 1
    return {"authored_status": authored, "evidence_status": evidence}


def semantic_native(native: dict[str, Any]) -> dict[str, Any]:
    return {
        key: native.get(key)
        for key in ["tick", "content_hash", "water_integer", "water_cells"]
        if key in native
    }


def compact_report(report: dict[str, Any], path: pathlib.Path) -> dict[str, Any]:
    runner = report.get("runner", {})
    profile = report.get("interaction_profile_full", {})
    return {
        "path": str(path),
        "id": report.get("id"),
        "seed": report.get("seed"),
        "definition_hash": report.get("definition_hash"),
        "outcome": report.get("outcome"),
        "completed_tick": report.get("completed_tick"),
        "worker_count": report.get("worker_count"),
        "runtime_identity": report.get("runtime_identity", {}),
        "kinetic_contact_baseline": report.get("kinetic_contact_baseline", {}),
        "interaction_profile": {
            "schema_id": profile.get("schema_id"),
            "schema_version": profile.get("schema_version"),
            "profile_id": profile.get("profile_id"),
            "profile_version": profile.get("profile_version"),
            "tuning_passes": profile.get("tuning_passes", []),
        },
        "interaction_inspection": report.get("interaction_inspection", []),
        "observations": report.get("observations", []),
        "water_ledger": report.get("water_ledger", {}),
        "semantic_native": semantic_native(report.get("native", {})),
        "native": report.get("native", {}),
        "work_statistics": report.get("work_statistics", {}),
        "timing": report.get("timing", {}),
        "runner": runner,
    }


def validate_worker_parity(entries: list[dict[str, Any]]) -> None:
    by_fixture: dict[str, list[dict[str, Any]]] = {}
    for entry in entries:
        by_fixture.setdefault(str(entry["id"]), []).append(entry)
    parity_fields = [
        "outcome",
        "completed_tick",
        "observations",
        "interaction_inspection",
        "water_ledger",
        "semantic_native",
    ]
    for fixture, group in by_fixture.items():
        if len(group) < 2:
            continue
        reference = group[0]
        for candidate in group[1:]:
            changed = [
                field for field in parity_fields
                if reference.get(field) != candidate.get(field)
            ]
            if changed:
                raise RuntimeError(
                    f"worker-parity drift for {fixture}: {', '.join(changed)}"
                )


def batch_run(args: argparse.Namespace) -> int:
    root = pathlib.Path(args.root).resolve()
    output_dir = pathlib.Path(args.output).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    workers = sorted({int(value) for value in args.workers.split(",") if value})
    if not workers or any(value < 1 or value > 32 for value in workers):
        raise ValueError("workers must be a comma-separated set in 1..32")

    entries: list[dict[str, Any]] = []
    coverage: list[dict[str, Any]] | None = None
    catalogue: dict[str, Any] | None = None
    for scenario, ticks in FIXTURES.items():
        slug = scenario.replace("/", "__")
        for worker_count in workers:
            path = output_dir / f"{slug}__w{worker_count}.json"
            command = godot_base(args.godot, root, "res://tests/run_microscenario.gd")
            command += [
                f"--scenario={scenario}",
                f"--seed={args.seed}",
                f"--ticks={ticks}",
                f"--workers={worker_count}",
                "--mode=Benchmark",
                "--observers=on",
                f"--output={path}",
                f"--source-sha={args.source_sha}",
            ]
            run_command(command, root)
            report = json.loads(path.read_text(encoding="utf-8"))
            if report.get("outcome") == "fail":
                raise RuntimeError(f"fixture failed: {scenario} / workers={worker_count}")
            profile = report.get("interaction_profile_full", {})
            if profile.get("schema_id") != "cybersand.interactions":
                raise RuntimeError(f"fixture lacks INT provenance: {scenario}")
            if not profile.get("catalogue_validation", {}).get("ok", False):
                raise RuntimeError(f"fixture exposes invalid INT catalogue: {scenario}")
            current_catalogue = interaction_catalogue(profile)
            if catalogue is None:
                catalogue = current_catalogue
                coverage = profile.get("coverage", [])
            elif current_catalogue != catalogue:
                raise RuntimeError(f"interaction catalogue drift within batch: {scenario}")
            entries.append(compact_report(report, path))

    validate_worker_parity(entries)
    retained_coverage = coverage or []
    manifest = {
        "schema": BATCH_SCHEMA,
        "version": BATCH_VERSION,
        "fixture_set": "int000-mechanism-proof-v1",
        "source_sha": args.source_sha,
        "seed": args.seed,
        "workers": workers,
        "fixtures": list(FIXTURES),
        "interaction_catalogue": catalogue or {},
        "coverage": retained_coverage,
        "coverage_summary": coverage_summary(retained_coverage),
        "coverage_gaps": coverage_gaps(retained_coverage),
        "entries": entries,
        "scope": (
            "Generated schema-2 native-only evidence. Contact opportunity still depends on "
            "the pinned transport/Water/scheduler identities in each retained report."
        ),
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(manifest_path)
    return 0


def load_manifest(path: str) -> dict[str, Any]:
    value = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    if value.get("schema") != BATCH_SCHEMA or value.get("version") != BATCH_VERSION:
        raise ValueError(f"not an INT evidence manifest: {path}")
    return value


def stable_section_diff(
    baseline: list[dict[str, Any]],
    candidate: list[dict[str, Any]],
    key: str,
) -> list[dict[str, Any]]:
    before = {str(item.get(key)): item for item in baseline}
    after = {str(item.get(key)): item for item in candidate}
    changes: list[dict[str, Any]] = []
    for identity in sorted(set(before) | set(after)):
        left = before.get(identity)
        right = after.get(identity)
        if left is None:
            changes.append({"id": identity, "kind": "added", "candidate": right})
            continue
        if right is None:
            changes.append({"id": identity, "kind": "removed", "baseline": left})
            continue
        fields = sorted(
            field for field in set(left) | set(right)
            if left.get(field) != right.get(field)
        )
        if fields:
            changes.append({
                "id": identity,
                "kind": "changed",
                "fields": fields,
                "baseline": {field: left.get(field) for field in fields},
                "candidate": {field: right.get(field) for field in fields},
            })
    return changes


def catalogue_diff(
    baseline: dict[str, Any],
    candidate: dict[str, Any],
) -> dict[str, list[dict[str, Any]]]:
    sections = {
        "channels": "id",
        "layer_kinds": "id",
        "families": "id",
        "authored_layers": "id",
        "pair_rules": "rule_id",
        "specialized_rules": "rule_id",
        "coverage": "subject_id",
        "tuning_passes": "id",
    }
    return {
        section: stable_section_diff(
            baseline.get(section, []),
            candidate.get(section, []),
            key,
        )
        for section, key in sections.items()
    }


def compare(args: argparse.Namespace) -> int:
    baseline = load_manifest(args.baseline)
    candidate = load_manifest(args.candidate)
    before = {(entry["id"], entry["worker_count"]): entry for entry in baseline["entries"]}
    after = {(entry["id"], entry["worker_count"]): entry for entry in candidate["entries"]}
    keys = sorted(set(before) | set(after))
    differences: list[dict[str, Any]] = []
    fields = [
        "definition_hash",
        "outcome",
        "completed_tick",
        "observations",
        "interaction_inspection",
        "water_ledger",
        "semantic_native",
        "kinetic_contact_baseline",
    ]
    for key in keys:
        left = before.get(key)
        right = after.get(key)
        if left is None or right is None:
            differences.append({"key": key, "kind": "missing-entry", "baseline": left, "candidate": right})
            continue
        changed = [field for field in fields if left.get(field) != right.get(field)]
        if changed:
            differences.append({"key": key, "kind": "changed", "fields": changed})
    interaction_changes = catalogue_diff(
        baseline.get("interaction_catalogue", {}),
        candidate.get("interaction_catalogue", {}),
    )
    changed_interactions_or_parameters = [
        {"section": section, **change}
        for section, changes in interaction_changes.items()
        for change in changes
    ]
    result = {
        "schema": "cybersand.int-pass-comparison",
        "version": 1,
        "baseline_source_sha": baseline.get("source_sha"),
        "candidate_source_sha": candidate.get("source_sha"),
        "baseline_fixture_set": baseline.get("fixture_set"),
        "candidate_fixture_set": candidate.get("fixture_set"),
        "baseline_coverage_gaps": baseline.get("coverage_gaps", []),
        "candidate_coverage_gaps": candidate.get("coverage_gaps", []),
        "interaction_changes": interaction_changes,
        "changed_interactions_or_parameters": changed_interactions_or_parameters,
        "evidence_differences": differences,
        "equal_interaction_catalogue": not changed_interactions_or_parameters,
        "equal_observed_evidence": not differences,
        "note": (
            "Every stable-ID catalogue change reports added/removed/changed fields. "
            "Evidence differences and catalogue changes are review inputs, not automatic "
            "accept/reject tuning verdicts."
        ),
    }
    destination = pathlib.Path(args.output)
    destination.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(destination)
    return 0


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument("--root", default=".")
    p.add_argument("--godot", default="godot")
    sub = p.add_subparsers(dest="command", required=True)

    gen = sub.add_parser("generate")
    gen.add_argument("scenario", choices=sorted(FIXTURES))
    gen.add_argument("--seed", type=int, default=0)
    gen.add_argument("--output", required=True)
    gen.set_defaults(action=generate)

    run = sub.add_parser("run")
    run.add_argument("--seed", type=int, default=0)
    run.add_argument("--workers", default="1,4")
    run.add_argument("--source-sha", default="unavailable")
    run.add_argument("--output", required=True)
    run.set_defaults(action=batch_run)

    diff = sub.add_parser("compare")
    diff.add_argument("baseline")
    diff.add_argument("candidate")
    diff.add_argument("--output", required=True)
    diff.set_defaults(action=compare)
    return p


def main() -> int:
    args = parser().parse_args()
    if getattr(args, "seed", 0) < 0:
        raise ValueError("seed must be non-negative")
    return int(args.action(args))


if __name__ == "__main__":
    raise SystemExit(main())
