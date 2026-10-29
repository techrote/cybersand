#!/usr/bin/env python3
"""Adversarial read-only checks for render-copy #290 unarmed publisher prep."""
import unittest
import io
import json
import zipfile
from render_copy290_publication_preflight import (
    BUILD_DRIFT, FEATURE, NEW, PREP, RETAINED, context, drift_ok,
    no_request, paths_ok, pointer_ok, source_lease, HOST_CASES, HOST_TARGETS,
    verify_host_receipts, verify_host_artifact_archives,
    HOST_ARCHIVE_RUNTIME, digest,
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



class HostReceipts(unittest.TestCase):
    """Synthetic samples test refusals, NOT actual Linux/Windows runs."""

    @staticmethod
    def encode(obj):
        return (json.dumps(obj, sort_keys=True) + "\n").encode()

    def setUp(self):
        self.source, self.tree = "a" * 40, "b" * 40
        logs = {
            "godot_import": b"Godot Engine v4.7.stable.official.5b4e0cb0f\n",
            "test_render_world_generation":
                b"RENDER_WORLD_GENERATION: 23 assertions, 0 failures\n",
            "test_render_patch_handoff_regression":
                b"Render patch handoff regression passed\n",
        }
        self.bundles = {}
        for platform, (runner, toolchain) in HOST_TARGETS.items():
            binary = bytearray(4096)
            if platform == "linux":
                binary[:6] = b"\x7fELF\x02\x01"
                binary[16:18], binary[18:20] = b"\x03\x00", b"\x3e\x00"
            else:
                binary[:2], binary[60:64] = b"MZ", (128).to_bytes(4, "little")
                binary[128:134] = b"PE\x00\x00\x64\x86"
                binary[150:152] = (0x2000).to_bytes(2, "little")  # IMAGE_FILE_DLL
                binary[152:154] = b"\x0b\x02"  # PE32+
            binary = bytes(binary)
            record = {
                "schema": "render-copy290-host-evidence-v1",
                "platform": platform, "source_sha": self.source,
                "source_tree": self.tree, "run_id": 40900000001, "run_attempt": 1,
                "runner": runner, "toolchain": toolchain,
                "godot_version": "4.7.stable.official.5b4e0cb0f",
                "godot_cpp_commit": "101ae38034304346a46ea9ea84ae156d3e860496",
                "scons_version": "4.10.1", "runtime_sha256": digest(binary),
                "runtime_size": len(binary),
                "cases": [{"name": name, "status": "passed", "exit_code": 0,
                           "timed_out": False, "log_sha256": digest(logs[name])}
                          for name in HOST_CASES],
            }
            self.bundles[platform] = {"report": self.encode(record),
                                      "runtime": binary, "logs": dict(logs)}

    def verify(self):
        return verify_host_receipts(self.bundles, self.source, self.tree,
                                    40900000001, 1)

    def mutate(self, target="linux", **changes):
        record = json.loads(self.bundles[target]["report"])
        record.update(changes)
        self.bundles[target]["report"] = self.encode(record)

    def test_positive_synthetic_pair(self):
        self.assertTrue(self.verify())

    def test_missing_target(self):
        del self.bundles["windows"]
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_mixed_attempts(self):
        self.mutate("windows", run_attempt=2)
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_cross_source_or_tree(self):
        for key in ("source_sha", "source_tree"):
            with self.subTest(key=key):
                saved = self.bundles["linux"]["report"]
                self.mutate(**{key: "c" * 40})
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.bundles["linux"]["report"] = saved

    def test_swapped_runtime(self):
        self.bundles["linux"]["runtime"] = self.bundles["windows"]["runtime"]
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_executable_as_extension_even_with_rehashed_receipt(self):
        # A machine-compatible executable is not a loadable GDExtension DLL/SO.
        # Recompute the receipt hash to isolate the binary-kind validation.
        for platform, offset, bad in (
            ("linux", 16, b"\x02\x00"),     # ET_EXEC instead of ET_DYN
            ("windows", 150, b"\x00\x00"),  # no IMAGE_FILE_DLL
            ("windows", 152, b"\x0b\x01"),  # PE32 instead of PE32+
        ):
            with self.subTest(platform=platform, offset=offset):
                saved = self.bundles[platform]
                forged = bytearray(saved["runtime"])
                forged[offset:offset + len(bad)] = bad
                forged = bytes(forged)
                receipt = json.loads(saved["report"])
                receipt["runtime_sha256"] = digest(forged)
                self.bundles[platform] = dict(
                    saved, runtime=forged, report=self.encode(receipt))
                try:
                    with self.assertRaises(RuntimeError):
                        self.verify()
                finally:
                    self.bundles[platform] = saved

    def test_false_report(self):
        for change in ({"cases": []}, {"platform": "windows"}, {"run_id": True},
                       {"runner": "ubuntu-22.04"}, {"extra": 1}):
            with self.subTest(change=change):
                saved = self.bundles["linux"]["report"]
                self.mutate(**change)
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.bundles["linux"]["report"] = saved

    def test_duplicate_or_invalid_json(self):
        for bad in (b"{", b'{"schema":"x","schema":"x"}', b'{"schema":NaN}', b"\xff"):
            with self.subTest(bad=bad):
                self.bundles["linux"]["report"] = bad
                with self.assertRaises(RuntimeError):
                    self.verify()

    def test_log_mutation_or_missing(self):
        self.bundles["linux"]["logs"]["godot_import"] += b"tampered"
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_zero_assertion_failure_skip(self):
        name = "test_render_world_generation"
        original = self.bundles["linux"]["logs"][name]
        for change in (original.replace(b"23 assertions", b"0 assertions"),
                       original.replace(b"0 failures", b"1 failures"),
                       original + b"SCRIPT ERROR: ignored\n",
                       original + b"SKIPPED: no extension\n"):
            with self.subTest(change=change):
                self.bundles["linux"]["logs"][name] = change
                record = json.loads(self.bundles["linux"]["report"])
                record["cases"][1]["log_sha256"] = digest(change)
                self.bundles["linux"]["report"] = self.encode(record)
                with self.assertRaises(RuntimeError):
                    self.verify()

    def test_post_success_diagnostics_with_indentation_or_prefix(self):
        # A forged success receipt with a recomputed log digest must not
        # conceal diagnostics after the expected positive marker.
        name = "test_render_patch_handoff_regression"
        for suffix in (
            b"  ERROR: extension failed to initialize\n",
            b"[2026-10-29T10:45:00Z] ERROR: failed after marker\n",
            b"\tSKIPPED: native case not executed\n",
            b"prefix: TIMEOUT while loading library\n",
            b"Traceback (most recent call last):\n",
            b"FATAL: aborted after test output\n",
        ):
            with self.subTest(suffix=suffix):
                original_log = self.bundles["linux"]["logs"][name]
                original_report = self.bundles["linux"]["report"]
                mutated = original_log + suffix
                self.bundles["linux"]["logs"][name] = mutated
                record = json.loads(original_report)
                record["cases"][2]["log_sha256"] = digest(mutated)
                self.bundles["linux"]["report"] = self.encode(record)
                try:
                    with self.assertRaises(RuntimeError):
                        self.verify()
                finally:
                    self.bundles["linux"]["logs"][name] = original_log
                    self.bundles["linux"]["report"] = original_report

    def test_rehashed_post_success_noncolon_failure_indicators(self):
        # An internally consistent receipt must not admit a later test failure,
        # crash or panic lacking the ERROR:/FATAL: colon-based diagnostic form.
        name = "test_render_patch_handoff_regression"
        for suffix in (
            b"[fail] late native assertion\n",
            b"  FAILED: GDExtension check\n",
            b"Failure: host fixture diverged\n",
            b"Segmentation fault (core dumped)\n",
            b"Aborted (core dumped)\n",
            b"PANIC: renderer crashed\n",
        ):
            with self.subTest(suffix=suffix):
                original_log = self.bundles["linux"]["logs"][name]
                original_report = self.bundles["linux"]["report"]
                forged = original_log + suffix
                self.bundles["linux"]["logs"][name] = forged
                record = json.loads(original_report)
                record["cases"][2]["log_sha256"] = digest(forged)
                self.bundles["linux"]["report"] = self.encode(record)
                try:
                    with self.assertRaises(RuntimeError):
                        self.verify()
                finally:
                    self.bundles["linux"]["logs"][name] = original_log
                    self.bundles["linux"]["report"] = original_report

    def test_case_exit_or_timeout(self):
        for change in ({"exit_code": 1}, {"exit_code": True},
                       {"timed_out": True}, {"status": "skipped"}):
            with self.subTest(change=change):
                saved = self.bundles["windows"]["report"]
                record = json.loads(saved)
                record["cases"][2].update(change)
                self.bundles["windows"]["report"] = self.encode(record)
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.bundles["windows"]["report"] = saved



class HostArtifactArchives(unittest.TestCase):
    """Synthetic ZIPs test refusal semantics, not authentic host execution."""

    def setUp(self):
        self.sample = HostReceipts()
        self.sample.setUp()
        self.archives = {p: self.make_zip(p) for p in HOST_TARGETS}
        self.digests = {p: "sha256:" + digest(raw)
                        for p, raw in self.archives.items()}

    def make_zip(self, platform, remove=None, add=None, duplicate=False):
        bundle = self.sample.bundles[platform]
        entries = {"host-evidence.json": bundle["report"],
                   HOST_ARCHIVE_RUNTIME[platform]: bundle["runtime"]}
        entries.update({"logs/" + name + ".log": bundle["logs"][name]
                        for name in HOST_CASES})
        if remove:
            entries.pop(remove)
        if add:
            entries.update(add)
        out = io.BytesIO()
        with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, raw in sorted(entries.items()):
                archive.writestr(name, raw)
            if duplicate:
                with __import__("warnings").catch_warnings():
                    __import__("warnings").simplefilter("ignore", UserWarning)
                    archive.writestr("host-evidence.json", bundle["report"])
        return out.getvalue()

    def repin(self, platform):
        # Synthetic fixtures may repin. Real callers must authenticate
        # expected ZIP digests independently from Actions metadata.
        self.digests[platform] = "sha256:" + digest(self.archives[platform])

    def verify(self, run=40900000001, attempt=1):
        return verify_host_artifact_archives(self.archives, self.digests,
                                             self.sample.source, self.sample.tree,
                                             run, attempt)

    def test_positive_original_zip_pair(self):
        self.assertTrue(self.verify())

    def test_rejects_unknown_external_digest(self):
        self.digests["windows"] = "sha256:" + "a" * 64
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_missing_metadata(self):
        del self.digests["windows"]
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_modified_zip_even_when_rehashed(self):
        self.archives["linux"] = self.make_zip(
            "linux", add={"../../unexpected.log": b"extra"})
        self.repin("linux")
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_missing_member(self):
        self.archives["windows"] = self.make_zip(
            "windows", remove="logs/godot_import.log")
        self.repin("windows")
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_duplicate_member(self):
        self.archives["linux"] = self.make_zip("linux", duplicate=True)
        self.repin("linux")
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_corrupt_crc_even_if_outer_hash_recomputed(self):
        original = bytearray(self.archives["linux"])
        offset = original.find(b"PK\x01\x02")
        self.assertNotEqual(offset, -1)
        original[offset + 16] ^= 0x01  # Central directory CRC.
        self.archives["linux"] = bytes(original)
        self.repin("linux")
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_cross_platform_archive(self):
        self.archives["linux"] = self.archives["windows"]
        self.repin("linux")
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_truncated_zip_even_if_rehashed(self):
        self.archives["windows"] = self.archives["windows"][:30]
        self.repin("windows")
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_rejects_replayed_run_under_new_external_run(self):
        with self.assertRaises(RuntimeError):
            self.verify(run=40900000002)

    def test_rejects_replayed_attempt_under_new_external_attempt(self):
        with self.assertRaises(RuntimeError):
            self.verify(attempt=2)

    def test_rejects_boolean_external_run(self):
        with self.assertRaises(RuntimeError):
            self.verify(run=True)


if __name__ == "__main__":
    unittest.main()
