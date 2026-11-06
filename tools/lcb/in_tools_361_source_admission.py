"""Fail-closed source admission for the real IN-TOOLS #361 implementation.

A01 is structural: the protected path set and roles live in this source file.
The JSON record may supply blob identities only after exact path-set equality.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / "godot/tests/fixtures/lcb/in_tools/in-tools-361-source-admission.2026-11-06.json"
SCHEMA = "in-tools-361-source-admission-v2"
IMPLEMENTATION_BASE = "7e2c2fd1aa2759590d63d5dfb53ce9e4c0a76e4b"

AUTHORITY_ROLES: dict[str, str] = {
    "godot/scripts/usable_catalog.gd": "existing U02/U10 gameplay identity, cost, range and operation",
    "godot/scripts/physical_usable_script.gd": "physical usable material/script policy retained by the equipment path",
    "godot/scripts/physical_actor_session.gd": "physical command custody, release semantics and owner lifetime",
    "godot/scripts/physical_usable_equipment.gd": "explicit profile admission, copied owner identity and receipt validation",
    "godot/scripts/physical_usable_runtime.gd": "exclusive physical usable source/sink/aperture execution owner",
    "godot/scripts/in_tools_liquid_controller.gd": "finite #361 source budget, leak ownership and exact source accounting",
    "godot/scripts/simulation_worker.gd": "exclusive mutable World ownership, consume fence and terminal quarantine",
    "godot/scripts/actor_prototype_panel.gd": "explicit opt-in selector for drain, reversible leak and IN nozzle",
    "godot/scripts/main.gd": "main-thread input cancellation, profile publication and visible owner readback",
    "godot/native_extension/cyber_native_cell_world.cpp": "bounded native source/aperture adapter and authoritative readback",
    "godot/native_extension/cyber_native_cell_world.hpp": "native adapter method surface and ownership boundary",
    "native/include/cybersand/world.hpp": "authoritative World mutation, quantity and IN velocity API",
    "native/src/world.cpp": "authoritative cell-state mutation and external quantity ledger",
    "native/src/world_inertial.inc": "IN motion law and bounded external velocity ledger used by the nozzle",
    "native/include/cybersand/inertial_cellular.hpp": "IN velocity bounds and signed-vertical parameter contract",
    "native/include/cybersand/water_normalization.hpp": "whole-cell Water maximum and normalization semantics",
    "native/include/cybersand/liquid_solver_policy.hpp": "applied liquid-family identity distinguishing IN from ballistic paths",
}
EXPECTED_STATUSES = {"current", "changed", "introduced"}


class AdmissionError(RuntimeError):
    pass


def _reject_duplicate(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise AdmissionError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


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
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
    ).returncode == 0


def _valid_blob(value: Any, allow_none: bool = False) -> bool:
    if value is None:
        return allow_none
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(c in "0123456789abcdef" for c in value)
    )


def validate_record(record: dict[str, Any]) -> None:
    required = {
        "schema", "id", "parent_issue", "implementation_base",
        "admission_anchor", "predecessors", "authority_count", "authority",
    }
    if set(record) != required:
        raise AdmissionError(
            f"record keys differ: missing={sorted(required-set(record))} "
            f"extra={sorted(set(record)-required)}"
        )
    if record["schema"] != SCHEMA or record["parent_issue"] != 361:
        raise AdmissionError("wrong schema or parent issue")
    if record["implementation_base"] != IMPLEMENTATION_BASE:
        raise AdmissionError("implementation base changed")
    if not _valid_blob(record["admission_anchor"]):
        raise AdmissionError("invalid admission anchor")

    authority = record["authority"]
    if not isinstance(authority, list):
        raise AdmissionError("authority must be an array")
    if record["authority_count"] != len(AUTHORITY_ROLES) or len(authority) != len(AUTHORITY_ROLES):
        raise AdmissionError("authority count differs from code-pinned set")

    rows: dict[str, dict[str, Any]] = {}
    for row in authority:
        if not isinstance(row, dict) or set(row) != {
            "path", "base_blob", "admitted_blob", "status", "role"
        }:
            raise AdmissionError(f"invalid authority row: {row}")
        path = row["path"]
        if not isinstance(path, str) or not path:
            raise AdmissionError("invalid authority path")
        if path in rows:
            raise AdmissionError(f"duplicate authority path: {path}")
        rows[path] = row

    expected = set(AUTHORITY_ROLES)
    actual = set(rows)
    if actual != expected:
        raise AdmissionError(
            "authority path set differs from immutable checker set: "
            f"missing={sorted(expected-actual)} extra={sorted(actual-expected)}"
        )

    for path, expected_role in AUTHORITY_ROLES.items():
        row = rows[path]
        if row["role"] != expected_role:
            raise AdmissionError(f"authority role differs for {path}")
        if row["status"] not in EXPECTED_STATUSES:
            raise AdmissionError(f"invalid authority status for {path}")
        if not _valid_blob(row["admitted_blob"]):
            raise AdmissionError(f"invalid admitted blob for {path}")
        if row["status"] == "introduced":
            if row["base_blob"] is not None:
                raise AdmissionError(f"introduced path has a base blob: {path}")
        elif not _valid_blob(row["base_blob"]):
            raise AdmissionError(f"invalid base blob for {path}")
        if row["status"] == "current" and row["base_blob"] != row["admitted_blob"]:
            raise AdmissionError(f"current path changed identity: {path}")
        if row["status"] == "changed" and row["base_blob"] == row["admitted_blob"]:
            raise AdmissionError(f"changed path did not change identity: {path}")

    predecessors = record["predecessors"]
    expected_predecessors = {
        "frozen_preparation": {
            "pr": 379,
            "head": "e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1",
            "disposition": "frozen-historical-unmerged",
        },
        "reviewed_admission": {
            "pr": 404,
            "head": "b9abf9aa0ad8fa0e189fe0e4d6a15eccf8c95c33",
            "disposition": "selective-salvage-only",
        },
        "stale_implementation": {
            "pr": 383,
            "head": "8f99d391f35708e665810e6732a6777baa7c2cf5",
            "disposition": "selective-salvage-only",
        },
    }
    if predecessors != expected_predecessors:
        raise AdmissionError("predecessor identities changed")


def check(record: dict[str, Any] | None = None, root: Path = ROOT) -> dict[str, Any]:
    if record is None:
        record = parse_json(RECORD.read_text(encoding="utf-8"))
    validate_record(record)
    base = record["implementation_base"]
    anchor = record["admission_anchor"]

    for commit, label in ((base, "implementation base"), (anchor, "admission anchor")):
        if not _git_ok(root, "cat-file", "-e", f"{commit}^{{commit}}"):
            raise AdmissionError(f"{label} commit is unavailable")
    if not _git_ok(root, "merge-base", "--is-ancestor", base, anchor):
        raise AdmissionError("admission anchor is not descended from implementation base")

    head = _git(root, "rev-parse", "HEAD")
    tree = _git(root, "rev-parse", "HEAD^{tree}")
    if not _git_ok(root, "merge-base", "--is-ancestor", anchor, head):
        raise AdmissionError("checkout HEAD is not descended from admission anchor")

    rows = {row["path"]: row for row in record["authority"]}
    checked: list[dict[str, Any]] = []
    for path in AUTHORITY_ROLES:
        row = rows[path]
        base_blob = row["base_blob"]
        admitted_blob = row["admitted_blob"]
        if base_blob is None:
            if _git_ok(root, "cat-file", "-e", f"{base}:{path}"):
                raise AdmissionError(f"introduced path unexpectedly exists at base: {path}")
        else:
            actual_base = _git(root, "rev-parse", f"{base}:{path}")
            if actual_base != base_blob:
                raise AdmissionError(
                    f"base blob mismatch for {path}: {base_blob} != {actual_base}"
                )

        actual_anchor = _git(root, "rev-parse", f"{anchor}:{path}")
        if actual_anchor != admitted_blob:
            raise AdmissionError(
                f"admission anchor blob mismatch for {path}: "
                f"{admitted_blob} != {actual_anchor}"
            )
        actual_head = _git(root, "rev-parse", f"HEAD:{path}")
        if actual_head != admitted_blob:
            raise AdmissionError(
                f"descendant modifies admitted authority path: {path}: "
                f"{actual_head} != {admitted_blob}"
            )

        working_blob = _git(root, "hash-object", f"--path={path}", path)
        if working_blob != admitted_blob:
            raise AdmissionError(
                f"working source changed for {path}: {working_blob} != {admitted_blob}"
            )
        if not _git_ok(root, "diff", "--quiet", "HEAD", "--", path):
            raise AdmissionError(f"unstaged working mutation for {path}")
        if not _git_ok(root, "diff", "--cached", "--quiet", "HEAD", "--", path):
            raise AdmissionError(f"staged working mutation for {path}")
        checked.append({
            "path": path,
            "base_blob": base_blob,
            "admitted_blob": admitted_blob,
            "status": row["status"],
        })

    return {
        "schema": "in-tools-361-source-admission-result-v2",
        "status": "admitted",
        "source_commit": head,
        "source_tree": tree,
        "implementation_base": base,
        "admission_anchor": anchor,
        "authority_count": len(checked),
        "authority": checked,
    }


def main() -> int:
    print(json.dumps(check(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
