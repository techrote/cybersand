#!/usr/bin/env python3
"""Adversarial read-only checks for render-copy #290 unarmed publisher prep."""
import unittest
from render_copy290_publication_preflight import (
    BUILD_DRIFT, FEATURE, NEW, PREP, RETAINED, context, drift_ok,
    no_request, paths_ok, pointer_ok, source_lease,
)


class Context(unittest.TestCase):
    def setUp(self):
        self.env = {"GITHUB_REPOSITORY": "techrote/cybersand",
                    "GITHUB_EVENT_NAME": "push", "GITHUB_REF": "refs/heads/" + PREP,
                    "RENDER_COPY290_HEAD_REPO": "techrote/cybersand"}

    def test_correct_push(self):
        context(self.env)

    def test_correct_pr(self):
        context(dict(self.env, GITHUB_EVENT_NAME="pull_request",
                     GITHUB_HEAD_REF=PREP, GITHUB_BASE_REF=FEATURE))

    def test_wrong_repository(self):
        with self.assertRaises(RuntimeError):
            context(dict(self.env, GITHUB_REPOSITORY="other/repo"))

    def test_wrong_branch(self):
        with self.assertRaises(RuntimeError):
            context(dict(self.env, GITHUB_REF="refs/heads/main"))


    def test_fork_head_refused(self):
        with self.assertRaises(RuntimeError):
            context(dict(self.env, GITHUB_EVENT_NAME="pull_request",
                         GITHUB_HEAD_REF=PREP, GITHUB_BASE_REF=FEATURE,
                         RENDER_COPY290_HEAD_REPO="outsider/cybersand"))

    def test_missing_pr_origin_refused(self):
        env = dict(self.env, GITHUB_EVENT_NAME="pull_request",
                   GITHUB_HEAD_REF=PREP, GITHUB_BASE_REF=FEATURE)
        env.pop("RENDER_COPY290_HEAD_REPO")
        with self.assertRaises(RuntimeError):
            context(env)

    def test_wrong_pr_base(self):
        with self.assertRaises(RuntimeError):
            context(dict(self.env, GITHUB_EVENT_NAME="pull_request",
                         GITHUB_HEAD_REF=PREP, GITHUB_BASE_REF="main"))

    def test_wrong_pr_head(self):
        with self.assertRaises(RuntimeError):
            context(dict(self.env, GITHUB_EVENT_NAME="pull_request",
                         GITHUB_HEAD_REF="untrusted", GITHUB_BASE_REF=FEATURE))

    def test_unapproved_dispatch(self):
        with self.assertRaises(RuntimeError):
            context(dict(self.env, GITHUB_EVENT_NAME="workflow_dispatch"))



class EventSourceLease(unittest.TestCase):
    def test_matching_source_sha(self):
        source_lease({"RENDER_COPY290_EVENT_SHA": "a" * 40}, "a" * 40)

    def test_changed_head_refused(self):
        with self.assertRaises(RuntimeError):
            source_lease({"RENDER_COPY290_EVENT_SHA": "a" * 40}, "b" * 40)

    def test_missing_sha_refused(self):
        with self.assertRaises(RuntimeError):
            source_lease({}, "a" * 40)

    def test_malformed_sha_refused(self):
        with self.assertRaises(RuntimeError):
            source_lease({"RENDER_COPY290_EVENT_SHA": "a" * 39}, "a" * 39)


class Preparation(unittest.TestCase):
    def test_exact_files(self):
        paths_ok(set(NEW))

    def test_source_modification_rejected(self):
        with self.assertRaises(RuntimeError):
            paths_ok(set(NEW) | {"native/src/world.cpp"})

    def test_missing_evidence_rejected(self):
        with self.assertRaises(RuntimeError):
            paths_ok(set(NEW) - {"docs/audits/2026-10-29-render-copy290-publisher-preflight.md"})

    def test_request_absent(self):
        no_request(False, False)

    def test_tracked_request_rejected(self):
        with self.assertRaises(RuntimeError):
            no_request(True, False)

    def test_untracked_request_rejected(self):
        with self.assertRaises(RuntimeError):
            no_request(False, True)


class RetainedLFS(unittest.TestCase):
    def setUp(self):
        self.record = RETAINED["linux"]
        self.pointer = (f"version https://git-lfs.github.com/spec/v1\n"
                        f"oid sha256:{self.record[3]}\nsize {self.record[4]}\n").encode()

    def test_exact_original_pointer(self):
        pointer_ok(self.pointer, self.record[3], self.record[4])

    def test_swapped_digest_refused(self):
        with self.assertRaises(RuntimeError):
            pointer_ok(self.pointer, RETAINED["windows"][3], self.record[4])

    def test_length_refused(self):
        with self.assertRaises(RuntimeError):
            pointer_ok(self.pointer, self.record[3], self.record[4] + 1)

    def test_trailing_garbage_refused(self):
        with self.assertRaises(RuntimeError):
            pointer_ok(self.pointer + b"EXTRA", self.record[3], self.record[4])


class HistoryDrift(unittest.TestCase):
    def setUp(self):
        self.native = {"native/src/world.cpp"} | {
            "native/src/fixture_%02d.cpp" % i for i in range(79)
        }
        self.source = {path: "old" for path in self.native}
        self.build = {"test/input_%03d" % i: "stable" for i in range(543)}
        self.build.update({path: "old" for path in BUILD_DRIFT})
        self.actual = {path: "old" for path in self.native}
        self.actual["native/src/world.cpp"] = "new"
        self.actual.update({path: "stable" for path in self.build})
        self.actual.update({path: "new" for path in BUILD_DRIFT})

    def test_expected_drift(self):
        drift_ok(self.native, self.source, self.build, self.actual)

    def test_silent_native_change(self):
        self.actual["native/src/fixture_01.cpp"] = "modified"
        with self.assertRaises(RuntimeError):
            drift_ok(self.native, self.source, self.build, self.actual)

    def test_missing_world_mismatch(self):
        self.actual["native/src/world.cpp"] = "old"
        with self.assertRaises(RuntimeError):
            drift_ok(self.native, self.source, self.build, self.actual)

    def test_unexpected_build_change(self):
        self.actual["test/input_001"] = "modified"
        with self.assertRaises(RuntimeError):
            drift_ok(self.native, self.source, self.build, self.actual)

    def test_missing_native_input(self):
        self.native.remove("native/src/fixture_01.cpp")
        with self.assertRaises(RuntimeError):
            drift_ok(self.native, self.source, self.build, self.actual)

    def test_incomplete_history(self):
        self.build.pop("test/input_001")
        with self.assertRaises(RuntimeError):
            drift_ok(self.native, self.source, self.build, self.actual)


if __name__ == "__main__":
    unittest.main()
