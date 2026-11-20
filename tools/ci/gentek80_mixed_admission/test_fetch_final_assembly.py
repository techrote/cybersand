"""Adverse identity controls for the immutable final Windows assembly download."""
import copy
import unittest

import fetch_final_assembly as fetch


class AssemblyIdentityTests(unittest.TestCase):
    def setUp(self):
        self.metadata = {"id": int(fetch.ARTIFACT), "name": fetch.ARTIFACT_NAME,
                         "expired": False, "digest": "sha256:" + fetch.ARTIFACT_SHA,
                         "size_in_bytes": fetch.ARTIFACT_BYTES,
                         "workflow_run": {"id": int(fetch.RUN), "head_sha": fetch.ORCHESTRATION}}
        self.run = {"id": int(fetch.RUN), "run_attempt": 1, "head_sha": fetch.ORCHESTRATION,
                    "head_branch": "ci/gentek80-final-admission", "event": "push",
                    "status": "completed", "conclusion": "success"}

    def test_exact_original_successful_run(self):
        fetch.validate_metadata(self.metadata, self.run)

    def test_wrong_artifact_identity_digest_size_or_expiration(self):
        for key, value in (("id", 0), ("name", "replacement"), ("expired", True),
                           ("digest", "sha256:" + "0" * 64), ("size_in_bytes", fetch.ARTIFACT_BYTES + 1)):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.metadata)
                changed[key] = value
                with self.assertRaises(ValueError):
                    fetch.validate_metadata(changed, self.run)

    def test_artifact_wrong_source_or_run(self):
        for key, value in (("id", 0), ("head_sha", "0" * 40)):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.metadata)
                changed["workflow_run"][key] = value
                with self.assertRaises(ValueError):
                    fetch.validate_metadata(changed, self.run)

    def test_unexecuted_failed_or_different_source_run(self):
        for key, value in (("id", 0), ("run_attempt", 2), ("head_sha", "0" * 40),
                           ("head_branch", "main"), ("event", "pull_request"),
                           ("status", "in_progress"), ("conclusion", "failure")):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.run)
                changed[key] = value
                with self.assertRaises(ValueError):
                    fetch.validate_metadata(self.metadata, changed)

    def test_missing_metadata_is_refused(self):
        with self.assertRaises(ValueError):
            fetch.validate_metadata({}, self.run)
        with self.assertRaises(ValueError):
            fetch.validate_metadata(self.metadata, {})


if __name__ == "__main__":
    unittest.main()
