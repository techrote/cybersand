#!/usr/bin/env python3
"""Independent accepted-Main oracle checks; no candidate generation or writes.

Only disposable directories are changed by adverse cases. Expected UI returns
are authenticated against pre-cutover Git, never computed from presentation.py.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import legacy_display_names as legacy


class LegacyDisplayOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = {
            path: legacy.git_bytes(legacy.ROOT, path)
            for path in (legacy.MAIN, legacy.CELL)
        }
        cls.expected = legacy.oracle()

    def parsed_with(self, path: str, before: str, after: str):
        sources = dict(self.original)
        source = sources[path].decode("utf-8")
        self.assertEqual(source.count(before), 1, "negative fixture must target one known source form")
        sources[path] = source.replace(before, after).encode("utf-8")
        with patch.object(legacy, "git_bytes", side_effect=lambda _root, name: sources[name]):
            return legacy.oracle()

    def test_current_fixture_authenticates_without_changing_bytes_or_mtime(self):
        fixture = legacy.ROOT / legacy.FIXTURE
        before = (fixture.read_bytes(), fixture.stat().st_mtime_ns)
        result = legacy.check()
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["cases"], 277)
        self.assertEqual(result["byte_domain_cases"], 256)
        self.assertEqual(result["signed_large_cases"], 21)
        self.assertEqual(result["fixture_sha256"], hashlib.sha256(before[0]).hexdigest())
        self.assertEqual((fixture.read_bytes(), fixture.stat().st_mtime_ns), before)

    def test_exact_five_exception_strings_empty_and_unknowns(self):
        names = {int(row["id"]): row["expected"] for row in self.expected["cases"]}
        self.assertEqual(len(names), 277)
        for ident, label in {
            0: "empty", 80: "LED white", 83: "rough oak log",
            113: "galvanised zinc sheet", 117: "bare iron plate", 131: "heat-shield tile",
        }.items():
            with self.subTest(ident=ident):
                self.assertEqual(names[ident], label)
        for ident in (10, *range(132, 256), *legacy.EDGE_IDS):
            with self.subTest(ident=ident):
                self.assertEqual(names[ident], "material-%d" % ident)
        self.assertEqual(self.expected["cases"][0]["id"], "0")
        self.assertIn("-9223372036854775808", {row["id"] for row in self.expected["cases"]})
        self.assertIn("9223372036854775807", {row["id"] for row in self.expected["cases"]})
        self.assertIn("9007199254740993", {row["id"] for row in self.expected["cases"]})

    def test_frozen_picker_order_and_group_boundaries(self):
        ids = self.expected["paintable_ids"]
        self.assertEqual(len(ids), 130)
        self.assertEqual(len(set(ids)), 130)
        self.assertEqual(set(ids), set(range(1, 132)) - {10})
        self.assertEqual(ids[:6], [2, 3, 1, 4, 20, 21])
        self.assertEqual(ids[-1], 131)
        self.assertEqual(self.expected["group_first_ids"], [2, 38, 57, 77, 81, 98, 113, 120])
        self.assertEqual(self.expected["match_arms"], 80)
        self.assertEqual(self.expected["building_labels"], 51)

    def test_altered_fixture_is_refused_without_repair(self):
        with tempfile.TemporaryDirectory(prefix="mat353-legacy-oracle-") as temporary:
            root = Path(temporary)
            fixture = root / legacy.FIXTURE
            fixture.parent.mkdir(parents=True)
            wrong = json.loads(json.dumps(self.expected))
            wrong["cases"][2]["expected"] = "decorative unused table"
            fixture.write_text(json.dumps(wrong, indent=2) + "\n", encoding="utf-8")
            before = (fixture.read_bytes(), fixture.stat().st_mtime_ns)
            # Only the disposable fixture path changes. The expected answer is
            # still the independent accepted-source parser, not this fixture.
            with patch.object(legacy, "oracle", return_value=self.expected):
                with self.assertRaisesRegex(ValueError, "frozen legacy-name fixture differs"):
                    legacy.check(root)
            self.assertEqual((fixture.read_bytes(), fixture.stat().st_mtime_ns), before)

    def test_missing_historical_git_cannot_be_substituted_by_current_source(self):
        error = subprocess.CalledProcessError(128, ["git", "show", legacy.BASELINE])
        with patch.object(legacy, "git_bytes", side_effect=error):
            with self.assertRaises(subprocess.CalledProcessError):
                legacy.oracle()

    def test_wrong_accepted_tree_is_refused_before_source_read(self):
        wrong_tree = subprocess.CompletedProcess([], 0, stdout="0" * 40 + "\n", stderr="")
        with patch.object(legacy.subprocess, "run", return_value=wrong_tree), \
                patch.object(legacy, "git_bytes") as source_read:
            with self.assertRaisesRegex(ValueError, "legacy oracle tree differs"):
                legacy.oracle()
        source_read.assert_not_called()

    def test_legacy_parser_rejects_new_unknown_formatting_or_extra_arm(self):
        changes = [
            ('return "material-%d" % material_id', 'return "invalid"'),
            ('\t\tCyberCellWorld.EMPTY:\n\t\t\treturn "empty"\n',
             '\t\tCyberCellWorld.EMPTY:\n\t\t\treturn "empty"\n\t\t10:\n\t\t\treturn "invalid"\n'),
        ]
        for before, after in changes:
            with self.subTest(change=before):
                with self.assertRaises(ValueError):
                    self.parsed_with(legacy.MAIN, before, after)

    def test_legacy_parser_rejects_extended_domain_and_picker_expressions(self):
        with self.assertRaisesRegex(ValueError, "legacy building range changed"):
            self.parsed_with(legacy.CELL, "const LAST_MATERIAL: int = 131", "const LAST_MATERIAL: int = 132")
        with self.assertRaisesRegex(ValueError, "unsupported legacy array item"):
            self.parsed_with(legacy.MAIN,
                             "const PAINTABLE_MATERIAL_IDS: Array[int] = [\n\tCyberCellWorld.SAND,",
                             "const PAINTABLE_MATERIAL_IDS: Array[int] = [\n\t2 + 0,")


if __name__ == "__main__":
    unittest.main()
