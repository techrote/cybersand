#!/usr/bin/env python3
"""Model-free regressions for source-verified v3 native receipt custody.

No model download, native runtime, optimizer training, or FINAL access.
The 2026-11-14 original native artifact is immutable and remains historical.
"""
import unittest

from v3_research_probe import (
    MANIFEST,
    QUARANTINED_NEAR_ALIAS,
    require_reference_manifest_sha256,
)


class SourceCustodyTests(unittest.TestCase):
    def test_exact_frozen_manifest_is_published(self):
        self.assertEqual(
            require_reference_manifest_sha256({"original_manifest_sha256": MANIFEST}),
            "2fdef5a3639606fb9af68319f9747a1de1e9a573da5c6197a2dcbc96579cb6cc",
        )

    def test_missing_manifest_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing/foreign"):
            require_reference_manifest_sha256({})

    def test_null_manifest_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing/foreign"):
            require_reference_manifest_sha256({"original_manifest_sha256": None})

    def test_foreign_manifest_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing/foreign"):
            require_reference_manifest_sha256({"original_manifest_sha256": "f" * 64})

    def test_near_alias_stays_quarantined(self):
        self.assertEqual(QUARANTINED_NEAR_ALIAS, ("void-v3-A01",))


if __name__ == "__main__":
    unittest.main(verbosity=2)
