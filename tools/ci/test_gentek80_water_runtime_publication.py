#!/usr/bin/env python3
"""Challenge merged Water + Gentek publisher's exact-branch/workflow guard."""
from __future__ import annotations
import argparse
import os
import unittest
from unittest import mock

import gentek80_water_runtime_publication as subject

SOURCE = "a" * 40
BRANCH = "integration/gentek80-water-conflict-reconcile"
WORKFLOW = ".github/workflows/gentek80-water-merged-requalification.yml"
REPO = "techrote/cybersand"

def environment(**override: str) -> dict[str, str]:
    result = {
        "GITHUB_REPOSITORY": REPO, "GITHUB_EVENT_NAME": "push",
        "GITHUB_REF": "refs/heads/" + BRANCH,
        "GITHUB_WORKFLOW_REF": REPO + "/" + WORKFLOW + "@refs/heads/" + BRANCH,
        "GITHUB_SHA": SOURCE, "GITHUB_RUN_ID": "12345678",
        "GITHUB_RUN_ATTEMPT": "1",
    }
    result.update(override)
    return result

def fake_git(*args: str) -> bytes:
    if args == ("rev-parse", "HEAD"):
        return SOURCE.encode() + bytes([10])
    if args == ("rev-parse", SOURCE + "^{tree}"):
        return ("b" * 40).encode() + bytes([10])
    if args == ("ls-remote", "--exit-code", "origin", "refs/heads/" + BRANCH):
        return SOURCE.encode() + bytes([9]) + ("refs/heads/" + BRANCH).encode() + bytes([10])
    raise AssertionError("Unexpected git operation " + repr(args))

class WaterGentekPublisherCustody(unittest.TestCase):
    def test_wrapper_and_request_are_isolated(self) -> None:
        self.assertEqual(subject.engine.BRANCH, BRANCH)
        self.assertEqual(subject.engine.WORKFLOW, WORKFLOW)
        self.assertEqual(subject.engine.REQUEST, "tools/ci/gentek80_water_publish_request.json")
        self.assertEqual(subject.engine.REQUEST_VALUE["intent"], "qualify-source-matched-runtimes-without-merge")
        for path in (WORKFLOW, "tools/ci/gentek80_water_runtime_publication.py",
                     "tools/ci/test_gentek80_water_runtime_publication.py",
                     subject.engine.REQUEST, subject.engine.EVIDENCE):
            self.assertIn(path, subject.engine.BUILD_EXACT)

    def test_good_and_bad_workflow_context(self) -> None:
        with mock.patch.object(subject.engine, "git", side_effect=fake_git):
            with mock.patch.dict(os.environ, environment(), clear=True):
                result = subject.engine.context(SOURCE)
                self.assertEqual(result["source_commit"], SOURCE)
                self.assertEqual(result["source_tree"], "b" * 40)
            rejects = (
                {"GITHUB_REF":"refs/heads/integration/gentek-80-001"},
                {"GITHUB_REF":"refs/heads/main"},
                {"GITHUB_WORKFLOW_REF":REPO + "/.github/workflows/gentek80-qualification.yml@refs/heads/" + BRANCH},
                {"GITHUB_WORKFLOW_REF":REPO + "/" + WORKFLOW + "@refs/heads/main"},
                {"GITHUB_REPOSITORY":"attacker/cybersand"},
                {"GITHUB_EVENT_NAME":"pull_request"},
                {"GITHUB_SHA":"c" * 40},
                {"GITHUB_RUN_ID":"not-a-number"},
                {"GITHUB_RUN_ATTEMPT":"0"},
            )
            for corrupted in rejects:
                with self.subTest(corrupted=corrupted):
                    with mock.patch.dict(os.environ, environment(**corrupted), clear=True):
                        with self.assertRaises(RuntimeError):
                            subject.engine.context(SOURCE)

    def test_remote_lease_refuses_stale_head(self) -> None:
        with mock.patch.dict(os.environ, environment(), clear=True):
            with mock.patch.object(subject.engine, "git", side_effect=fake_git):
                with mock.patch.object(subject.engine, "require_publication_request", return_value=None):
                    subject.engine.check_source(argparse.Namespace(source_sha=SOURCE))
            def stale(*args: str) -> bytes:
                if args[0] == "ls-remote":
                    return ("d" * 40).encode() + bytes([9]) + ("refs/heads/" + BRANCH).encode() + bytes([10])
                return fake_git(*args)
            with mock.patch.object(subject.engine, "git", side_effect=stale):
                with mock.patch.object(subject.engine, "require_publication_request", return_value=None):
                    with self.assertRaisesRegex(RuntimeError, "Feature branch changed"):
                        subject.engine.check_source(argparse.Namespace(source_sha=SOURCE))

if __name__ == "__main__":
    unittest.main()
