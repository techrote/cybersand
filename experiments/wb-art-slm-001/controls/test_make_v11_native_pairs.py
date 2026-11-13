"""Fixture custody tests; never attribute synthetic preflight to native execution."""
import hashlib
import json
import unittest

import make_v11_native_pairs as pairs
import pattern_compiler as baseline


class PairManifestTests(unittest.TestCase):
    def test_v1_v11_ids_and_input_fingerprints(self):
        doc = pairs.make_pairs()
        self.assertEqual(len(doc["cases"]), 32)
        self.assertEqual(len(doc["aliases"]), 16)
        self.assertEqual(doc["required_native_history_mode"], "each")
        self.assertEqual(len({c["id"] for c in doc["cases"]}), 32)
        for case in doc["cases"]:
            self.assertLessEqual(len(case["id"]), 38)
            self.assertEqual(case["operations_sha256"], hashlib.sha256(
                baseline.canonical_json(case["operations"]).encode()).hexdigest())
            self.assertEqual(case["theme"], "coral")
        for alias in doc["aliases"].values():
            self.assertNotEqual(alias["c10"]["operations_sha256"], alias["c11"]["operations_sha256"])
            self.assertEqual(alias["c10"]["compiler_version"], baseline.COMPILER_VERSION)
        self.assertEqual(pairs.make_pairs(), doc)


if __name__ == "__main__":
    unittest.main()
