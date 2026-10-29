#!/usr/bin/env python3
"""Adversarial safety tests for the unarmed RENDER-COPY-290 writer."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

import render_copy290_publication_gate as gate
import render_copy290_runtime_publisher as publisher


def raw(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


class RequestTests(unittest.TestCase):
    def setUp(self):
        self.writer = "c" * 40
        self.request_sha = "d" * 40
        self.request = {
            "schema": "render-copy290-publish-request-v1",
            "intent": gate.INTENT,
            "producer_source_sha": gate.BASE,
            "producer_source_tree": gate.TREE,
            "producer_run_id": gate.RUN_ID,
            "producer_run_attempt": gate.ATTEMPT,
            "artifact_ids": copy.deepcopy(gate.ARTIFACT_IDS),
            "artifact_sha256": copy.deepcopy(gate.ARTIFACT_DIGESTS),
            "reviewed_writer_sha": self.writer,
            "destination_branch": publisher.BRANCH,
        }

    def test_constants_preserve_separate_writer_branch_and_request_absence(self):
        self.assertEqual(publisher.BASE,
                         "d249435d041fd27e0508701e69fd6e7a29a8610a")
        self.assertNotEqual(publisher.BRANCH, publisher.GATE_BRANCH)
        self.assertNotIn(publisher.REQUEST, publisher.WRITER_FILES)
        self.assertEqual(len(publisher.WRITER_FILES), 4)
        self.assertEqual(len(publisher.PUBLICATION_PATHS), 4)

    def test_external_pin_shapes_and_windows_godot_digest(self):
        self.assertEqual(len(publisher.EXTERNAL_PINS["godot_windows_sha512"]), 128)
        for key in ("godot_linux_sha256", "rapier_linux_sha256",
                    "rapier_windows_sha256", "llvm_mingw_sha256"):
            with self.subTest(key=key):
                self.assertEqual(len(publisher.EXTERNAL_PINS[key]), 64)
                int(publisher.EXTERNAL_PINS[key], 16)
        int(publisher.EXTERNAL_PINS["godot_windows_sha512"], 16)
        self.assertEqual(
            publisher.EXTERNAL_PINS["godot_windows_sha512"],
            "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9")

    def test_request_shape_exact_values(self):
        self.assertEqual(set(self.request), gate.REQUEST_KEYS)
        self.assertEqual(self.request["destination_branch"], publisher.BRANCH)
        self.assertEqual(self.request["producer_source_sha"], gate.BASE)
        self.assertEqual(self.request["artifact_sha256"], gate.ARTIFACT_DIGESTS)

    def test_owner_text_names_request_commit_not_comment_id(self):
        text = gate.request_text(self.request, self.request_sha)
        self.assertIn("request_commit_sha: " + self.request_sha, text)
        self.assertIn("reviewed_writer_sha: " + self.writer, text)
        self.assertNotIn("comment_id", text)

    def test_request_extra_comment_id_is_forbidden(self):
        broken = copy.deepcopy(self.request)
        broken["owner_comment_id"] = 1
        self.assertNotEqual(set(broken), gate.REQUEST_KEYS)


class AuthorizationSelectionTests(unittest.TestCase):
    def setUp(self):
        self.writer = "c" * 40
        self.request_sha = "d" * 40
        self.request = {
            "schema": "render-copy290-publish-request-v1",
            "intent": gate.INTENT,
            "producer_source_sha": gate.BASE,
            "producer_source_tree": gate.TREE,
            "producer_run_id": gate.RUN_ID,
            "producer_run_attempt": gate.ATTEMPT,
            "artifact_ids": copy.deepcopy(gate.ARTIFACT_IDS),
            "artifact_sha256": copy.deepcopy(gate.ARTIFACT_DIGESTS),
            "reviewed_writer_sha": self.writer,
            "destination_branch": publisher.BRANCH,
        }
        self.bytes = raw(self.request)
        self.comment = {
            "id": 101,
            "user": {"login": "techrote"},
            "author_association": "OWNER",
            "issue_url": "https://api.github.com/repos/techrote/cybersand/issues/290",
            "html_url": "https://github.com/techrote/cybersand/pull/290#issuecomment-101",
            "created_at": "2026-10-29T22:15:00Z",
            "updated_at": "2026-10-29T22:15:00Z",
            "body": gate.request_text(self.request, self.request_sha),
        }

    def select(self, comments):
        return publisher.select_authorization(
            self.bytes, self.request, self.request_sha, comments)

    def test_one_exact_owner_comment_is_accepted(self):
        self.assertEqual(self.select([self.comment])["id"], 101)

    def test_no_comment_is_unarmed_not_implicitly_authorized(self):
        self.assertIsNone(self.select([]))

    def test_unrelated_or_edited_comments_do_not_authorize(self):
        variants = []
        for key, value in (
            ("body", "approve"),
            ("author_association", "CONTRIBUTOR"),
            ("updated_at", "2026-10-29T22:15:01Z"),
            ("issue_url", "https://api.github.com/repos/techrote/cybersand/issues/300"),
            ("html_url", "https://github.com/techrote/cybersand/pull/300#issuecomment-101"),
        ):
            item = copy.deepcopy(self.comment)
            item[key] = value
            variants.append(item)
        wrong_user = copy.deepcopy(self.comment)
        wrong_user["user"]["login"] = "someone-else"
        variants.append(wrong_user)
        self.assertIsNone(self.select(variants))

    def test_wrong_request_commit_does_not_authorize(self):
        self.assertIsNone(publisher.select_authorization(
            self.bytes, self.request, "e" * 40, [self.comment]))

    def test_duplicate_exact_authorizations_fail_closed(self):
        second = copy.deepcopy(self.comment)
        second["id"] = 102
        second["html_url"] = (
            "https://github.com/techrote/cybersand/pull/290#issuecomment-102")
        with self.assertRaisesRegex(RuntimeError, "Multiple exact owner"):
            self.select([self.comment, second])


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = (publisher.ROOT / ".github/workflows/render-copy290-runtime-publisher.yml").read_text(
            encoding="utf-8")

    def test_workflow_has_no_manual_dispatch_and_request_is_only_future_arm(self):
        self.assertNotIn("workflow_dispatch:", self.text)
        self.assertIn("tools/ci/render_copy290_publish_request.json", self.text)
        self.assertIn("armed == 'true'", self.text)

    def test_write_permission_is_scoped_to_publish_job(self):
        self.assertIn("permissions:\n  contents: read\n  actions: read\n  issues: read", self.text)
        self.assertEqual(self.text.count("contents: write"), 1)
        publish = self.text.split("\n  publish:\n", 1)[1]
        self.assertIn("contents: write", publish)

    def test_guard_and_admission_checkout_never_persist_credentials(self):
        before_publish = self.text.split("\n  publish:\n", 1)[0]
        self.assertGreaterEqual(before_publish.count("persist-credentials: false"), 2)

    def test_actual_publish_rechecks_authorization_index_and_lease(self):
        publish = self.text.split("\n  publish:\n", 1)[1]
        for token in (
            "materialize",
            "check-index",
            "--force-with-lease",
            "post-push",
            "git lfs install --local",
        ):
            with self.subTest(token=token):
                self.assertIn(token, publish)

    def test_real_artifact_dry_run_is_read_only_and_always_exercised(self):
        before_publish = self.text.split("\n  publish:\n", 1)[0]
        self.assertIn("original-evidence-dry-run:", before_publish)
        self.assertIn("verify-originals", before_publish)
        self.assertIn("persist-credentials: false", before_publish)
        self.assertNotIn("contents: write", before_publish)

    def test_no_main_branch_or_merge_operation(self):
        self.assertNotIn("refs/heads/main", self.text)
        self.assertNotIn("gh pr merge", self.text)
        self.assertNotIn("git merge", self.text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
