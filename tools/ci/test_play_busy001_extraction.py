#!/usr/bin/env python3
"""Pin/refusal tests for the exact pool slice; no fake successful pool substitute."""
import hashlib
import os
from pathlib import Path
import unittest
import run_play_busy001_pool as subject


class PoolExtractionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = Path(os.getenv("CYBERSAND_POOL_SOURCE_EXCERPT", str(subject.ROOT / subject.SOURCE))).read_bytes()
        cls.pool = subject.extract_pool(cls.raw)

    def test_exact_source(self):
        self.assertEqual(hashlib.sha256(self.pool).hexdigest(), subject.POOL_SHA256)
        self.assertIn(b"function(context, task);", self.pool)

    def test_windows_checkout_line_endings(self):
        self.assertEqual(subject.extract_pool(self.raw.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")), self.pool)

    def test_changed_task_claim_refused(self):
        changed = self.raw.replace(b"next_task_.fetch_add(1,", b"next_task_.fetch_add(2,")
        with self.assertRaisesRegex(ValueError, "source changed"):
            subject.extract_pool(changed)

    def test_duplicate_class_marker_refused(self):
        with self.assertRaisesRegex(ValueError, "one literal"):
            subject.extract_pool(self.raw + self.pool)

    def test_missing_marker_refused(self):
        with self.assertRaisesRegex(ValueError, "one literal"):
            subject.extract_pool(b"class FakePool {};\n")

    def test_truncated_class_refused(self):
        with self.assertRaisesRegex(ValueError, "closing delimiter"):
            subject.extract_pool(self.pool[:-5])

    def test_context_outside_class_is_not_substituted_for_class_identity(self):
        self.assertEqual(subject.extract_pool(b"// other World code\n" + self.pool), self.pool)

    def test_generated_header_keeps_verbatim_class(self):
        generated = subject.generated_header(self.pool)
        self.assertIn(self.pool, generated)
        self.assertEqual(generated.count(self.pool), 1)


if __name__ == "__main__":
    unittest.main()
