"""Admit only the six independently captured GENTEK-80 CLASSIC repairs.

All other modules must retain complete same-platform native snapshot bytes.
Repaired modules retain recipe fingerprints and must match immutable pre/post
material oracles for each existing qualifier profile; this is not an ignore list.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

COMPARISON_INPUTS = (
    "tools/architecture/classic_repair_comparison.py",
    "docs/images/gentek-80/classic-review-repair-oracle.json",
)
REPAIRED_PARENT = "e27ff75758ef51c7b7c8b4d8a7093343cc2ecede"
APPROVED_MODULES = frozenset({"ring_pier", "tripod_frame", "cascade_terrace",
                              "scalloped_vault", "suspended_deck", "buttress_wall"})
HEADER = b"CLASSIC72-LE16-v1\n"
HEADER74 = b"CLASSIC74-LE16-v1\n"
CHUNK_BYTES = 16 + 64 * 64 * 2
PROFILE_BYTES = 8 + 4 * CHUNK_BYTES
MODULE_BYTES = 3 * PROFILE_BYTES


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def compare_legacy_snapshots(root: Path, before: bytes, after: bytes,
                             ids: list[str], parent_source: str, *,
                             palette: str = "standard", header: bytes = HEADER) -> dict:
    if parent_source != REPAIRED_PARENT:
        raise AssertionError("Reviewed CLASSIC repair comparison requires the authoritative repaired e27 parent")
    oracle_path = root / COMPARISON_INPUTS[1]
    oracle_bytes = oracle_path.read_bytes()
    oracle = json.loads(oracle_bytes)
    if (oracle.get("status") != "pass" or oracle.get("baseline_source_commit") != parent_source
            or set(oracle.get("approved_modules", [])) != APPROVED_MODULES):
        raise AssertionError("Invalid independent CLASSIC repair oracle authority")
    if palette not in {"standard", "rosework"}:
        raise AssertionError("Unknown independently captured qualifier material palette")
    captured = oracle["rosework_qualifier_profiles" if palette == "rosework" else "qualifier_profiles"]
    expected_ids = set(captured) - ({"arcade-v1", "arcade-v2"} if len(ids) == 72 else set())
    if len(ids) not in {72,74} or len(set(ids)) != len(ids) or set(ids) != expected_ids:
        raise AssertionError("CLASSIC fixture identities do not match the independently captured catalogue")
    if header not in {HEADER, HEADER74} or (header == HEADER74 and len(ids) != 74):
        raise AssertionError("Unexpected qualifier snapshot header")
    expected_length = len(header) + len(ids) * MODULE_BYTES
    if any(len(data) != expected_length or not data.startswith(header) for data in (before, after)):
        raise AssertionError("Legacy dump incomplete or unexpectedly encoded")
    receipts = []
    changed_modules = []
    unchanged_bytes = 0
    for index, module in enumerate(ids):
        start = len(header) + index * MODULE_BYTES
        old, new = before[start:start+MODULE_BYTES], after[start:start+MODULE_BYTES]
        receipt = {"module": module, "exact_bytes_equal": old == new,
                   "parent_sha256": digest(old), "candidate_sha256": digest(new)}
        if module not in APPROVED_MODULES:
            if old != new:
                offset = next(i for i, pair in enumerate(zip(old, new)) if pair[0] != pair[1])
                raise AssertionError(f"Unreviewed CLASSIC output changed: {module}, byte {offset}")
            unchanged_bytes += MODULE_BYTES
            receipt["policy"] = "exact native fingerprints, receipts and cells"
        else:
            profiles = captured[module]["profiles"]
            if [profile["profile"] for profile in profiles] != [0,1,2]:
                raise AssertionError(f"Independent repair oracle profiles incomplete: {module}")
            receipt["policy"] = "equal recipe fingerprints and fixed independent before/after material oracles"
            receipt["profiles"] = []
            for profile, expected in enumerate(profiles):
                offset = profile * PROFILE_BYTES
                if old[offset:offset+8] != new[offset:offset+8]:
                    raise AssertionError(f"Reviewed repair changed a recipe fingerprint: {module}, profile {profile}")
                old_cells = b""
                new_cells = b""
                for chunk in range(4):
                    chunk_start = offset + 8 + chunk * CHUNK_BYTES
                    old_chunk = old[chunk_start:chunk_start+CHUNK_BYTES]
                    new_chunk = new[chunk_start:chunk_start+CHUNK_BYTES]
                    old_cells += old_chunk[16:]
                    new_cells += new_chunk[16:]
                    if old_chunk[16:] == new_chunk[16:] and old_chunk != new_chunk:
                        raise AssertionError(f"Unchanged repaired cells changed native receipts: {module}, profile {profile}, chunk {chunk}")
                    if old_chunk[16:] != new_chunk[16:] and (
                            old_chunk[:8] == new_chunk[:8] or old_chunk[8:16] == new_chunk[8:16]):
                        raise AssertionError(f"Changed repaired cells retained stale native hashes: {module}, profile {profile}, chunk {chunk}")
                old_sha, new_sha = digest(old_cells), digest(new_cells)
                if old_sha != expected["before_material_sha256"]:
                    raise AssertionError(f"Authoritative parent material oracle mismatch: {module}, profile {profile}")
                if new_sha != expected["after_material_sha256"]:
                    raise AssertionError(f"Reviewed candidate material oracle mismatch: {module}, profile {profile}")
                receipt["profiles"].append({"profile": profile, "parent_material_sha256": old_sha,
                                             "candidate_material_sha256": new_sha,
                                             "exact_material_bytes_equal": old_cells == new_cells})
            if old != new:
                changed_modules.append(module)
        receipts.append(receipt)
    return {"module_receipts": receipts, "approved_review_repair_modules": sorted(APPROVED_MODULES),
            "changed_modules": changed_modules, "unmodified_classic_modules": 66,
            "unmodified_module_exact_bytes_compared": unchanged_bytes,
            "same_platform_native_fingerprints_equal": True,
            "same_platform_native_fingerprints_and_receipts_equal": before == after,
            "reviewed_material_oracles_match": True,
            "independent_material_palette": palette,
            "repair_oracle_path": COMPARISON_INPUTS[1], "repair_oracle_sha256": digest(oracle_bytes),
            "parent_snapshot_sha256": digest(before), "candidate_snapshot_sha256": digest(after)}
