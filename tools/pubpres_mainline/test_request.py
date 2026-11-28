"""A stale request or a foreign source must not dispatch qualification/publication."""
import copy
import contextlib
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import campaign_request as request


class RequestTests(unittest.TestCase):
    def setUp(self):
        self.good = {"schema": "pubpres-mainline-request-v2", "phase": "build", "purpose": "Three exact native builds",
            "accepted_main": request.MAIN, "owner_reference": request.OWNER, "payload_sha256": "a" * 64,
            "runtime_run": None, "runtime_attempt": None, "runtime_source": None,
            "qualification_run": None, "qualification_attempt": None, "qualification_source": None, "publication_commit": None,
            "physical_acceptance": "HOLD", "promotion": "DRAFT_ONLY"}

    def test_fresh_build_and_bound_qualification(self):
        request.validate_record(self.good)
        self.good.update(phase="qualify", runtime_run=123, runtime_attempt=1, runtime_source="b" * 40)
        request.validate_record(self.good)

    def test_foreign_roles_authority_and_incomplete_runtime_refuse(self):
        for key, value in (("accepted_main", "a" * 40), ("owner_reference", "b" * 40),
                           ("physical_acceptance", "PASS"), ("promotion", "MERGE"),
                           ("phase", "unknown"), ("payload_sha256", "short"),
                           ("runtime_run", 42), ("purpose", "")):
            bad = copy.deepcopy(self.good)
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                request.validate_record(bad)
        bad = dict(self.good, phase="qualify")
        with self.assertRaises(ValueError):
            request.validate_record(bad)

    def test_publication_and_delivery_have_separate_exact_authority(self):
        value = dict(self.good, phase="publish", runtime_run=1, runtime_attempt=1, runtime_source="b" * 40)
        with self.assertRaises(ValueError):
            request.validate_record(value)
        value.update(qualification_run=2, qualification_attempt=1, qualification_source="c" * 40)
        request.validate_record(value)
        value["phase"] = "delivery"
        with self.assertRaises(ValueError):
            request.validate_record(value)
        value["publication_commit"] = "d" * 40
        request.validate_record(value)

    def test_validated_cli_exports_source_bound_general_performance_hold(self):
        with tempfile.TemporaryDirectory(prefix="pubpres-request-output-") as directory:
            output = Path(directory) / "github-output.txt"
            with mock.patch.object(request, "validate", return_value=self.good), \
                    mock.patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}), \
                    mock.patch("sys.argv", ["request.py"]), \
                    contextlib.redirect_stdout(io.StringIO()):
                request.main()
            self.assertIn(
                "general_performance_status=hold-observer-contract\n",
                output.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
