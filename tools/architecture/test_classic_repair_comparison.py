#!/usr/bin/env python3
"""Adverse controls against the independently captured real native snapshots."""
from __future__ import annotations

import json
from pathlib import Path
import unittest
import zipfile

from classic_repair_comparison import (
    CHUNK_BYTES, HEADER, HEADER74, MODULE_BYTES, PROFILE_BYTES, REPAIRED_PARENT,
    compare_legacy_snapshots,
)


class ReviewedRepairComparisonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.root = Path(__file__).resolve().parents[2]
        evidence = cls.root / "docs/images/gentek-80"
        receipt = json.loads((evidence / "classic-review-repair-oracle.json").read_text())
        cls.ids = list(receipt["qualifier_profiles"])
        with zipfile.ZipFile(evidence / "classic-review-repair-captures.zip") as archive:
            cls.before = archive.read("before/legacy.le16")
            cls.after = archive.read("after/legacy.le16")
            cls.rosework_before = archive.read("before/legacy-rosework.le16")
            cls.rosework_after = archive.read("after/legacy-rosework.le16")

    def compare(self, before: bytes | None = None, after: bytes | None = None) -> dict:
        return compare_legacy_snapshots(self.root, self.before if before is None else before,
                                        self.after if after is None else after, self.ids, REPAIRED_PARENT)

    def offset(self, module: str, profile: int = 0, chunk: int = 0) -> int:
        return len(HEADER) + self.ids.index(module) * MODULE_BYTES + profile * PROFILE_BYTES + 8 + chunk * CHUNK_BYTES

    def test_exact_independent_before_after_captures_pass(self) -> None:
        result = self.compare()
        self.assertEqual(len(result["changed_modules"]), 6)
        self.assertEqual(result["unmodified_classic_modules"], 66)
        self.assertTrue(result["reviewed_material_oracles_match"])
        self.assertFalse(result["same_platform_native_fingerprints_and_receipts_equal"])

    def test_all_72_only_qualifier_format_also_passes(self) -> None:
        end = len(HEADER) + 72 * MODULE_BYTES
        result = compare_legacy_snapshots(self.root, self.before[:end], self.after[:end], self.ids[:72], REPAIRED_PARENT)
        self.assertEqual(result["unmodified_module_exact_bytes_compared"], 66 * MODULE_BYTES)

    def test_rosework_palette_matches_its_own_independent_capture(self) -> None:
        end = len(HEADER) + 72 * MODULE_BYTES
        result = compare_legacy_snapshots(self.root, self.rosework_before[:end], self.rosework_after[:end],
                                          self.ids[:72], REPAIRED_PARENT, palette="rosework")
        self.assertEqual(result["independent_material_palette"], "rosework")
        self.assertEqual(len(result["changed_modules"]), 6)

    def test_wrong_material_palette_is_rejected(self) -> None:
        with self.assertRaisesRegex(AssertionError, "Authoritative parent material oracle mismatch"):
            self.compare(before=self.rosework_before, after=self.rosework_after)

    def test_explicit_74_header_is_preserved(self) -> None:
        result = compare_legacy_snapshots(self.root, HEADER74 + self.before[len(HEADER):],
                                          HEADER74 + self.after[len(HEADER):], self.ids,
                                          REPAIRED_PARENT, header=HEADER74)
        self.assertEqual(len(result["module_receipts"]), 74)

    def test_fixture_cannot_silently_switch_its_encoding(self) -> None:
        with self.assertRaisesRegex(AssertionError, "Legacy dump incomplete"):
            self.compare(after=HEADER74 + self.after[len(HEADER):])

    def test_changed_unreviewed_style_is_rejected(self) -> None:
        mutated = bytearray(self.after)
        mutated[self.offset("trestle") + 16] ^= 1
        with self.assertRaisesRegex(AssertionError, "Unreviewed CLASSIC output changed: trestle"):
            self.compare(after=bytes(mutated))

    def test_changed_reviewed_style_must_match_captured_materials(self) -> None:
        mutated = bytearray(self.after)
        mutated[self.offset("ring_pier") + 16] ^= 1
        with self.assertRaisesRegex(AssertionError, "Reviewed candidate material oracle mismatch: ring_pier"):
            self.compare(after=bytes(mutated))

    def test_wrong_parent_materials_are_rejected(self) -> None:
        mutated = bytearray(self.before)
        mutated[self.offset("ring_pier") + 16] ^= 1
        with self.assertRaisesRegex(AssertionError, "Authoritative parent material oracle mismatch: ring_pier"):
            self.compare(before=bytes(mutated))

    def test_repaired_fingerprint_change_is_rejected(self) -> None:
        mutated = bytearray(self.after)
        mutated[self.offset("ring_pier") - 8] ^= 1
        with self.assertRaisesRegex(AssertionError, "changed a recipe fingerprint"):
            self.compare(after=bytes(mutated))

    def test_stale_content_hash_on_changed_cells_is_rejected(self) -> None:
        mutated = bytearray(self.after)
        start = self.offset("ring_pier")
        mutated[start:start+8] = self.before[start:start+8]
        with self.assertRaisesRegex(AssertionError, "retained stale native hashes"):
            self.compare(after=bytes(mutated))

    def test_unchanged_closed_windows_cannot_change_receipts(self) -> None:
        mutated = bytearray(self.after)
        mutated[self.offset("suspended_deck", profile=2)] ^= 1
        with self.assertRaisesRegex(AssertionError, "Unchanged repaired cells changed native receipts"):
            self.compare(after=bytes(mutated))

    def test_reverting_all_repairs_is_not_accepted_as_preservation(self) -> None:
        with self.assertRaisesRegex(AssertionError, "Reviewed candidate material oracle mismatch"):
            self.compare(after=self.before)

    def test_unknown_or_duplicate_id_cannot_bypass_comparison(self) -> None:
        ids = list(self.ids)
        ids[0] = "ring_pier"
        with self.assertRaisesRegex(AssertionError, "fixture identities"):
            compare_legacy_snapshots(self.root, self.before, self.after, ids, REPAIRED_PARENT)

    def test_other_historical_parent_is_rejected(self) -> None:
        with self.assertRaisesRegex(AssertionError, "authoritative repaired e27 parent"):
            compare_legacy_snapshots(self.root, self.before, self.after, self.ids, "615828b28337f85e4663e03ba479616db4ddf764")

    def test_truncated_capture_is_rejected(self) -> None:
        with self.assertRaisesRegex(AssertionError, "Legacy dump incomplete"):
            self.compare(after=self.after[:-1])


if __name__ == "__main__":
    unittest.main(verbosity=2)
