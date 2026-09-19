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
        "interaction_profile": {
            "schema_id": profile.get("schema_id"),
            "schema_version": profile.get("schema_version"),
            "profile_id": profile.get("profile_id"),
            "profile_version": profile.get("profile_version"),
            "tuning_passes": profile.get("tuning_passes", []),
        },
        "interaction_inspection": report.get("interaction_inspection", []),
        "observations": report.get("observations", []),
        "native": report.get("native", {}),
        "runner": runner,
    }


def batch_run(args: argparse.Namespace) -> int:
    root = pathlib.Path(args.root).resolve()
    output_dir = pathlib.Path(args.output).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    workers = sorted({int(value) for value in args.workers.split(",") if value})
    if not workers or any(value < 1 or value > 32 for value in workers):
        raise ValueError("workers must be a comma-separated set in 1..32")

    entries: list[dict[str, Any]] = []
    coverage: list[dict[str, Any]] | None = None
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
            if coverage is None:
                coverage = profile.get("coverage", [])
            entries.append(compact_report(report, path))

    manifest = {
        "schema": BATCH_SCHEMA,
        "version": BATCH_VERSION,
        "fixture_set": "int000-mechanism-proof-v1",
        "source_sha": args.source_sha,
        "seed": args.seed,
        "workers": workers,
        "fixtures": list(FIXTURES),
        "coverage": coverage or [],
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


def compare(args: argparse.Namespace) -> int:
    baseline = load_manifest(args.baseline)
    candidate = load_manifest(args.candidate)
    before = {(entry["id"], entry["worker_count"]): entry for entry in baseline["entries"]}
    after = {(entry["id"], entry["worker_count"]): entry for entry in candidate["entries"]}
    keys = sorted(set(before) | set(after))
    differences: list[dict[str, Any]] = []
    fields = ["definition_hash", "outcome", "completed_tick", "observations", "interaction_inspection", "native"]
    for key in keys:
        left = before.get(key)
        right = after.get(key)
        if left is None or right is None:
            differences.append({"key": key, "kind": "missing-entry", "baseline": left, "candidate": right})
            continue
        changed = [field for field in fields if left.get(field) != right.get(field)]
        if changed:
            differences.append({"key": key, "kind": "changed", "fields": changed})
    result = {
        "schema": "cybersand.int-pass-comparison",
        "version": 1,
        "baseline_source_sha": baseline.get("source_sha"),
        "candidate_source_sha": candidate.get("source_sha"),
        "baseline_fixture_set": baseline.get("fixture_set"),
        "candidate_fixture_set": candidate.get("fixture_set"),
        "differences": differences,
        "equal_observed_evidence": not differences,
        "note": "A difference is evidence to review, not an automatic accept/reject tuning verdict.",
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
