from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import run_request as guard
import runtime_custody as custody
import publish_runtime as publisher
import broad_validation as broad


class History(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "Isolated guard fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.frozen = self.commit({"source.cpp": "int main() { return 0; }\n"})
        self.donors = {key: self.frozen for key in guard.DONORS}
        for mock in (patch.object(guard, "ACCEPTED_MAIN", self.frozen), patch.object(guard, "DONORS", self.donors),
                     patch.object(custody, "definition_hash", return_value="e" * 64)):
            mock.start(); self.addCleanup(mock.stop)

    def git(self, *arguments):
        return guard.git(self.root, *arguments).decode().strip()

    def commit(self, files):
        for name, value in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value, encoding="utf-8")
        self.git("add", "--all")
        self.git("commit", "--quiet", "--no-gpg-sign", "-m", "guard fixture")
        return self.git("rev-parse", "HEAD")

    def qualification(self, **changes):
        return {"schema": 1, "programme": custody.PROGRAMME, "action": "qualify-mainline",
                "source_sha": self.frozen, "request_id": "test-001", "accepted_main": guard.ACCEPTED_MAIN,
                "frozen_donors": self.donors, "native_definition_sha256": "e" * 64, **changes}

    def publication(self, **changes):
        return {"schema": 1, "programme": custody.PROGRAMME, "action": "publish-runtime", "request_id": "publish-001",
                "expected_parent_sha": self.git("rev-parse", "HEAD"), "qualification_source_sha": self.frozen,
                "qualification_run_id": "123", "qualification_run_attempt": "1", "publication_artifact_id": "456", **changes}

    def push(self, name, value, additional=None):
        before = self.git("rev-parse", "HEAD")
        execution = self.commit({name: json.dumps(value), **(additional or {})})
        return execution, {"ref": guard.BRANCH, "before": before, "after": execution,
                           "created": False, "deleted": False, "forced": False}

    def test_qualification_binds_execution_and_separately_published_source(self):
        execution, event = self.push(guard.REQUEST, self.qualification())
        value = guard.validate(self.root, "push", guard.BRANCH, execution, execution, event)
        self.assertEqual(value["frozen_source_sha"], self.frozen)
        self.assertEqual(value["execution_source_sha"], execution)
        self.assertEqual(value["native_definition_sha256"], "e" * 64)

    def test_source_delta_and_definition_change_are_not_requests(self):
        execution, event = self.push(guard.REQUEST, self.qualification(), {"source.cpp": "changed\n"})
        with self.assertRaisesRegex(ValueError, "change only the request"):
            guard.validate(self.root, "push", guard.BRANCH, execution, execution, event)
        self.git("reset", "--hard", self.frozen)
        execution, event = self.push(guard.REQUEST, self.qualification(native_definition_sha256="f" * 64))
        with self.assertRaisesRegex(ValueError, "native definition differs"):
            guard.validate(self.root, "push", guard.BRANCH, execution, execution, event)

    def test_branch_created_force_or_wrong_target_is_refused(self):
        execution, event = self.push(guard.REQUEST, self.qualification())
        for key in ("created", "forced", "deleted"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                guard.validate(self.root, "push", guard.BRANCH, execution, execution, {**event, key: True})
        with self.assertRaises(ValueError):
            guard.validate(self.root, "push", "refs/heads/main", execution, execution, event)

    def test_publication_is_request_only_and_preserves_original_source(self):
        execution, event = self.push(publisher.REQUEST, self.publication())
        result = publisher.verify_request(self.root, execution, event)
        self.assertEqual(result["qualification_source_sha"], self.frozen)
        self.assertEqual(result["execution_sha"], execution)

    def test_publication_cannot_hide_source_edits_even_when_reverted(self):
        self.commit({"source.cpp": "temporary change\n"})
        self.commit({"source.cpp": "int main() { return 0; }\n"})
        execution, event = self.push(publisher.REQUEST, self.publication())
        self.assertEqual(guard.changed(self.root, self.frozen, execution), [publisher.REQUEST])
        with self.assertRaisesRegex(ValueError, "Source changed after qualification"):
            publisher.verify_request(self.root, execution, event)

    def test_publication_parent_branch_and_action_are_fenced(self):
        value = self.publication(expected_parent_sha="f" * 40)
        execution, event = self.push(publisher.REQUEST, value)
        with self.assertRaises(ValueError):
            publisher.verify_request(self.root, execution, event)
        self.git("reset", "--hard", self.frozen)
        execution, event = self.push(publisher.REQUEST, self.publication(action="merge"))
        with self.assertRaisesRegex(ValueError, "request contract"):
            publisher.verify_request(self.root, execution, event)

    def test_publication_contract_rejects_duplicate_keys_and_merge_ancestry(self):
        value = self.publication()
        execution, event = self.push(publisher.REQUEST, value)
        payload = json.dumps(value)[:-1] + ',"schema":1}'
        execution = self.commit({publisher.REQUEST: payload})
        event["before"], event["after"] = event["after"], execution
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            publisher.verify_request(self.root, execution, event)

    def test_broad_request_is_exact_parent_and_fixed_workflows_only(self):
        value = {"schema": 1, "qualification_programme": custody.QUALIFICATION_PROGRAMME,
                 "action": "qualify-full-regressions", "request_id": "broad-001",
                 "expected_parent_sha": self.frozen, "workflows": list(broad.WORKFLOWS)}
        execution, event = self.push(broad.REQUEST, value)
        self.assertEqual(broad.verify_request(self.root, execution, event)["execution_sha"], execution)
        for field, wrong in (("workflows", ["other-mission.yml"]), ("action", "merge"), ("qualification_programme", "other")):
            self.git("reset", "--hard", self.frozen)
            execution, event = self.push(broad.REQUEST, {**value, field: wrong})
            with self.subTest(field=field), self.assertRaises(ValueError):
                broad.verify_request(self.root, execution, event)
        self.git("reset", "--hard", self.frozen)
        execution, event = self.push(broad.REQUEST, value, {"source.cpp": "unqualified source change\n"})
        with self.assertRaisesRegex(ValueError, "source/runtime edits"):
            broad.verify_request(self.root, execution, event)


class ImmutableArtifact(unittest.TestCase):
    def setUp(self):
        self.request = {"qualification_run_id": "123", "qualification_run_attempt": "2", "qualification_source_sha": "a" * 40,
                        "publication_artifact_id": "456"}
        self.run = {"id": 123, "run_attempt": 2, "head_sha": "a" * 40, "head_branch": custody.BRANCH,
                    "event": "push", "status": "completed", "conclusion": "success", "workflow_id": 789,
                    "repository": {"full_name": "techrote/cybersand"}, "head_repository": {"full_name": "techrote/cybersand"}}
        self.workflow = {"id": 789, "path": custody.WORKFLOW}
        self.artifact = {"id": 456, "name": "swarm456-runtime-publication-candidate-" + "a" * 40 + "-123-2",
                         "expired": False, "size_in_bytes": 100, "digest": "sha256:" + "e" * 64,
                         "workflow_run": {"id": 123, "head_sha": "a" * 40}}

    def test_exact_completed_run_attempt_and_artifact_are_required(self):
        self.assertEqual(publisher.validate_run(self.request, self.run, self.workflow, [self.artifact]), self.artifact)
        for key, value in (("conclusion", "failure"), ("run_attempt", 3), ("head_sha", "b" * 40),
                           ("head_branch", "main"), ("status", "in_progress")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                publisher.validate_run(self.request, {**self.run, key: value}, self.workflow, [self.artifact])

    def test_wrong_workflow_artifact_or_missing_digest_is_refused(self):
        for artifact in ({**self.artifact, "expired": True}, {**self.artifact, "id": 999},
                         {**self.artifact, "digest": ""}, {**self.artifact, "workflow_run": {"id": 124, "head_sha": "a" * 40}}):
            with self.subTest(artifact=artifact), self.assertRaises(ValueError):
                publisher.validate_run(self.request, self.run, self.workflow, [artifact])
        with self.assertRaises(ValueError):
            publisher.validate_run(self.request, self.run, {**self.workflow, "path": ".github/workflows/other.yml"}, [self.artifact])
        with self.assertRaises(ValueError):
            publisher.validate_run(self.request, self.run, self.workflow, [self.artifact, self.artifact])


if __name__ == "__main__":
    unittest.main()
