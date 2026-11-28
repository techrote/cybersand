#!/usr/bin/env python3
"""Adversarial tests for the candidate-only source and publication boundaries."""
import argparse
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import material_audition_publication as publication


class PublicationBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.source = "a" * 40
        self.request = publication.REQUEST_VALUE | {"request_sequence": 1}
        self.environment = {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + publication.BRANCH,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + publication.WORKFLOW + "@refs/heads/" + publication.BRANCH,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "2",
        }

    def test_request_retains_hold_and_explicit_publication_intent(self):
        publication.validate_request(self.request)

    def test_request_cannot_request_merge_ready_or_default_change(self):
        for key, value in (("intent", "merge"), ("disposition", "Ready"), ("canonical_defaults_changed", True)):
            with self.subTest(key=key), self.assertRaises(ValueError):
                publication.validate_request(self.request | {key: value})

    def test_request_rejects_unknown_and_missing_fields(self):
        for request in (self.request | {"source_override": self.source}, publication.REQUEST_VALUE, {}):
            with self.assertRaises(ValueError):
                publication.validate_request(request)

    def test_request_sequence_is_positive_integer_not_boolean(self):
        for value in (0, -1, True, "1", 1.5):
            with self.subTest(value=value), self.assertRaises(ValueError):
                publication.validate_request(self.request | {"request_sequence": value})

    def test_context_refuses_other_branch_repository_event_source_and_workflow(self):
        def git(*args):
            return (self.source if args[-1] == "HEAD" else "b" * 40).encode()
        for key, value in (("GITHUB_REPOSITORY", "fork/cybersand"), ("GITHUB_EVENT_NAME", "pull_request"),
                           ("GITHUB_REF", "refs/heads/main"), ("GITHUB_SHA", "c" * 40),
                           ("GITHUB_WORKFLOW_REF", "techrote/cybersand/.github/workflows/other.yml@refs/heads/" + publication.BRANCH)):
            with self.subTest(key=key), patch.dict(os.environ, self.environment | {key: value}, clear=True), \
                    patch.object(publication.engine, "git", side_effect=git), self.assertRaises(RuntimeError):
                publication.engine.context(self.source)

    def test_current_request_and_remote_lease(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / publication.REQUEST
            path.parent.mkdir()
            raw = (json.dumps(self.request) + "\n").encode()
            path.write_bytes(raw)
            def git(_root, *args):
                return raw if args[0] == "show" else (self.source + "\trefs/heads/" + publication.BRANCH).encode()
            with patch.object(publication, "ROOT", root), patch.object(publication.engine, "context", return_value={}), \
                    patch.object(publication.qualification, "git", side_effect=git):
                publication.check_source(self.source)

    def test_request_worktree_change_or_changed_remote_tip_refuses(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / publication.REQUEST
            path.parent.mkdir()
            raw = (json.dumps(self.request) + "\n").encode()
            path.write_bytes(raw)
            for changed_request in (True, False):
                def git(_root, *args):
                    if args[0] == "show": return b"{}" if changed_request else raw
                    return (("c" * 40) + "\trefs/heads/" + publication.BRANCH).encode()
                with self.subTest(changed_request=changed_request), patch.object(publication, "ROOT", root), \
                        patch.object(publication.engine, "context", return_value={}), \
                        patch.object(publication.qualification, "git", side_effect=git), self.assertRaises(ValueError):
                    publication.check_source(self.source)

    def test_candidate_requires_same_run_source_platform_and_pinned_toolchain(self):
        valid = {"source_commit": self.source, "platform": "linux", "run_id": "123", "run_attempt": "1",
                 "toolchain_drift": False, "status": "built-not-executed"}
        with patch.dict(os.environ, self.environment, clear=True):
            publication.validate_candidate_context(valid, self.source, "linux")
            for key, value in (("source_commit", "b" * 40), ("platform", "windows"), ("run_id", "124"),
                               ("run_attempt", "3"), ("run_attempt", "0"), ("run_attempt", 1),
                               ("toolchain_drift", True), ("toolchain_drift", 0), ("status", "passed")):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    publication.validate_candidate_context(valid | {key: value}, self.source, "linux")

    def test_native_completion_rejects_failure_duplicate_empty_and_sanitizer_errors(self):
        valid = json.dumps({"status": "PASS", "suite": "material-audition-native", "assertions": 34081851}, separators=(",", ":"))
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "native.log"
            path.write_text(valid + "\n", encoding="utf-8")
            self.assertEqual(publication.native_completion(path)["assertions"], 34081851)
            for text in ("", valid + "\n" + valid, valid.replace('"PASS"', '"FAIL"'),
                         valid.replace("34081851", "0"), valid.replace("34081851", "true"),
                         valid + "\nERROR: AddressSanitizer: use-after-free", valid + "\nruntime error: overflow"):
                path.write_text(text, encoding="utf-8")
                with self.subTest(text=text[:45]), self.assertRaises(ValueError):
                    publication.native_completion(path)

    def test_index_rejects_a_source_edit_even_if_manifests_are_staged(self):
        changed = ("\0".join([*publication.engine.MANIFESTS.values(), "native/src/world.cpp"]) + "\0").encode()
        with patch.object(publication.engine, "context", return_value={}), \
                patch.object(publication.engine, "git", return_value=changed), self.assertRaises(RuntimeError):
            publication.engine.check_index(argparse.Namespace(source_sha=self.source))


if __name__ == "__main__":
    unittest.main()
