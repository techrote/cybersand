"""Fail-closed source admission for the #361 current-main successor.

This checker binds the successor to the minimal production authority actually
needed by the documented first slice. It deliberately does not recreate PR
#379's historical 25-input map.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / "godot/tests/fixtures/lcb/in_tools/in-tools-current-main-admission.2026-11-05.json"
SCHEMA = "in-tools-current-main-admission-v1"
EXPECTED_AUTHORITY_COUNT = 11
EXPECTED_PLANS = {
    "in-tools.valve-side.v2",
    "in-tools.valve-bottom.v2",
    "in-tools.sink-bottom.v2",
    "in-tools.sink-side.v2",
    "in-tools.source-channel.v2",
    "in-tools.usable-liquid-drain.v2",
}


class AdmissionError(RuntimeError):
    pass


def _reject_duplicate(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise AdmissionError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def parse_json(raw: str) -> dict[str, Any]:
    try:
        value = json.loads(raw, object_pairs_hook=_reject_duplicate)
    except json.JSONDecodeError as exc:
        raise AdmissionError(f"invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise AdmissionError("admission root must be an object")
    return value


def _git(root: Path, *args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(root), *args], stderr=subprocess.STDOUT, text=True
        ).strip()
    except subprocess.CalledProcessError as exc:
        raise AdmissionError(
            f"git {' '.join(args)} failed: {exc.output.strip()}"
        ) from exc


def _git_ok(root: Path, *args: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def validate_record(record: dict[str, Any]) -> None:
    required = {
        "schema", "id", "parent_issue", "predecessor", "assignment_pin",
        "adopted_main", "authority", "current", "planned", "required_contracts",
        "gameplay_qualified", "runtime_qualified", "windows_gate", "authority_count",
    }
    if set(record) != required:
        raise AdmissionError(
            f"record keys differ: missing={sorted(required-set(record))} "
            f"extra={sorted(set(record)-required)}"
        )
    if record["schema"] != SCHEMA:
        raise AdmissionError("unexpected schema")
    if record["parent_issue"] != 361:
        raise AdmissionError("wrong parent issue")
    predecessor = record["predecessor"]
    if predecessor != {
        "pr": 379,
        "head": "e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1",
        "tree": "3b5acd41fd7fb49ac8b06c94719fa1a700d8fd57",
        "disposition": "frozen-historical-unmerged",
    }:
        raise AdmissionError("historical predecessor identity changed")
    if record["assignment_pin"] != "ba9cbc89029be88b812af59b19e5c59829bbcd90":
        raise AdmissionError("assignment pin changed")
    if record["adopted_main"] != record["assignment_pin"]:
        raise AdmissionError("adopted main differs from authenticated assignment pin")
    authority = record["authority"]
    if not isinstance(authority, list) or len(authority) != EXPECTED_AUTHORITY_COUNT:
        raise AdmissionError("authority count differs from minimal reviewed set")
    if record["authority_count"] != EXPECTED_AUTHORITY_COUNT:
        raise AdmissionError("declared authority_count differs")
    paths = [row.get("path") for row in authority if isinstance(row, dict)]
    if len(paths) != len(set(paths)) or len(paths) != EXPECTED_AUTHORITY_COUNT:
        raise AdmissionError("authority paths are incomplete or duplicated")
    for row in authority:
        if set(row) != {"path", "git_blob", "role"}:
            raise AdmissionError(f"invalid authority row: {row}")
        if not isinstance(row["path"], str) or not row["path"]:
            raise AdmissionError("invalid authority path")
        blob = row["git_blob"]
        if not isinstance(blob, str) or len(blob) != 40 or any(c not in "0123456789abcdef" for c in blob):
            raise AdmissionError(f"invalid Git blob for {row['path']}")
        if not isinstance(row["role"], str) or not row["role"]:
            raise AdmissionError(f"missing role for {row['path']}")
    plans = record["planned"]
    plan_ids = {row.get("id") for row in plans if isinstance(row, dict)}
    if plan_ids != EXPECTED_PLANS or len(plans) != len(EXPECTED_PLANS):
        raise AdmissionError("planned fixture registration differs")
    for row in plans:
        if row.get("status") != "Planned" or row.get("execution") != "NOT_RUN":
            raise AdmissionError(f"fixture is not Planned/NOT_RUN: {row}")
    current = record["current"]
    if current.get("liquid_drain", {}).get("status") != "Current":
        raise AdmissionError("existing U10 status changed")
    if current.get("actor_usable_owner", {}).get("status") != "Current":
        raise AdmissionError("actor usable owner status changed")
    if record["gameplay_qualified"] is not False or record["runtime_qualified"] is not False:
        raise AdmissionError("admission cannot claim gameplay/runtime qualification")
    if record["windows_gate"] != "NOT_RUN":
        raise AdmissionError("committed registration must not predeclare Windows result")


def check(record: dict[str, Any] | None = None, root: Path = ROOT) -> dict[str, Any]:
    if record is None:
        record = parse_json(RECORD.read_text(encoding="utf-8"))
    validate_record(record)
    base = record["adopted_main"]
    if not _git_ok(root, "cat-file", "-e", f"{base}^{{commit}}"):
        raise AdmissionError("adopted main commit is unavailable")
    head = _git(root, "rev-parse", "HEAD")
    tree = _git(root, "rev-parse", "HEAD^{tree}")
    if not _git_ok(root, "merge-base", "--is-ancestor", base, head):
        raise AdmissionError("successor HEAD is not a descendant of adopted main")

    checked: list[dict[str, str]] = []
    for row in record["authority"]:
        path = row["path"]
        expected = row["git_blob"]
        base_blob = _git(root, "rev-parse", f"{base}:{path}")
        if base_blob != expected:
            raise AdmissionError(
                f"registered blob is stale for {path}: {expected} != {base_blob}"
            )
        working_blob = _git(root, "hash-object", f"--path={path}", path)
        if working_blob != expected:
            raise AdmissionError(
                f"working source changed for {path}: {working_blob} != {expected}"
            )
        if not _git_ok(root, "diff", "--quiet", base, "--", path):
            raise AdmissionError(f"successor modifies production authority path: {path}")
        checked.append({"path": path, "git_blob": expected})

    return {
        "schema": "in-tools-current-main-admission-result-v1",
        "status": "admitted",
        "source_commit": head,
        "source_tree": tree,
        "adopted_main": base,
        "authority_count": len(checked),
        "authority": checked,
        "planned_count": len(record["planned"]),
        "planned_execution": "NOT_RUN",
        "gameplay_qualified": False,
        "runtime_qualified": False,
    }


def main() -> int:
    result = check()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
