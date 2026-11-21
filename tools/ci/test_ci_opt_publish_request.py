#!/usr/bin/env python3
"""Monotonic source-pinned publisher request fixtures."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ci_opt_publish_request import sequence


class RequestTests(unittest.TestCase):
    def test_increment_is_positive_and_scope_unchanged(self):
        old = {"request_sequence": 3, "schema": "v1", "scope": "pinned"}
        current = {"request_sequence": 4, "schema": "v1", "scope": "pinned"}
        self.assertEqual(sequence(current, old), 4)
        self.assertEqual(sequence({"request_sequence": 1, "schema": "v1"}, None), 1)

    def test_noop_decrement_boolean_bad_schema_refuse(self):
        old = {"request_sequence": 3, "schema": "v1"}
        for candidate in (
            {"request_sequence": 3, "schema": "v1"},
            {"request_sequence": 2, "schema": "v1"},
            {"request_sequence": True, "schema": "v1"},
            {"request_sequence": 4, "schema": "v2"},
            {"request_sequence": 4, "schema": "v1", "extra": "policy bypass"},
            {"request_sequence": 1000000000, "schema": "v1"},
        ):
            with self.subTest(candidate=candidate):
                with self.assertRaises(ValueError):
                    sequence(candidate, old)


if __name__ == "__main__":
    unittest.main()
