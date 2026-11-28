"""A green-looking skipped or foreign workflow must never authorize publication."""
import copy
import unittest
import publish_runtime as publication


class PublicationAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.run = {"id": 42, "repository": {"full_name": publication.REPOSITORY},
                    "head_branch": publication.request.BRANCH, "head_sha": "a" * 40,
                    "event": "push", "path": publication.WORKFLOW, "run_attempt": 1, "status": "completed"}
        self.jobs = [{"id": index + 100, "run_id": 42, "name": name, "status": "completed", "conclusion": "success"}
                     for index, name in enumerate(sorted(publication.BUILD_JOBS))]

    def check(self, run, jobs):
        return publication.admit_jobs(run, jobs, source="a" * 40, attempt=1, expected=publication.BUILD_JOBS)

    def test_complete_original_campaign(self):
        self.assertEqual(set(self.check(self.run, self.jobs)), publication.BUILD_JOBS)

    def test_skipped_failed_missing_and_duplicate_gates_refuse(self):
        for status in ("skipped", "failure", "cancelled", None):
            jobs = copy.deepcopy(self.jobs)
            jobs[0]["conclusion"] = status
            with self.subTest(status=status), self.assertRaises(ValueError):
                self.check(self.run, jobs)
        for jobs in (self.jobs[:-1], self.jobs + [self.jobs[0]]):
            with self.assertRaises(ValueError):
                self.check(self.run, jobs)

    def test_foreign_source_branch_attempt_and_workflow_refuse(self):
        for field, value in (("head_sha", "b" * 40), ("head_branch", "main"), ("event", "pull_request"),
                             ("path", ".github/workflows/another.yml"), ("run_attempt", 2), ("status", "in_progress")):
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.check(dict(self.run, **{field: value}), self.jobs)
        jobs = copy.deepcopy(self.jobs)
        jobs[-1]["run_id"] = 43
        with self.assertRaises(ValueError):
            self.check(self.run, jobs)


if __name__ == "__main__":
    unittest.main()
