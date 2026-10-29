#!/usr/bin/env python3
"""Synthetic refusal tests for the UNARMED #290 publication contracts."""
import copy
import hashlib
import json
import unittest

import render_copy290_publication_gate as gate


def raw(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def fake_shared_object(platform):
    value = bytearray(4096)
    if platform == "linux":
        value[0:6] = b"\x7fELF\x02\x01"
        value[16:20] = b"\x03\x00\x3e\x00"
    else:
        value[0:2] = b"MZ"
        value[60:64] = (128).to_bytes(4, "little")
        value[128:134] = b"PE\x00\x00\x64\x86"
        value[150:152] = (0x2000).to_bytes(2, "little")
        value[152:154] = b"\x0b\x02"
    return bytes(value)


def bundles():
    out = {}
    logs = {
        "godot_import": b"Godot Engine v4.7.stable.official.5b4e0cb0f\n",
        "test_render_world_generation":
            b"RENDER_WORLD_GENERATION: 23 assertions, 0 failures\n",
        "test_render_patch_handoff_regression":
            b"Render patch handoff regression passed\n",
    }
    for platform, (runner, compiler) in gate.HOST_TARGETS.items():
        binary = fake_shared_object(platform)
        report = {
            "schema": "render-copy290-host-evidence-v1",
            "platform": platform, "source_sha": gate.BASE,
            "source_tree": gate.TREE, "run_id": gate.RUN_ID,
            "run_attempt": gate.ATTEMPT, "runner": runner,
            "toolchain": compiler,
            "godot_version": "4.7.stable.official.5b4e0cb0f",
            "godot_cpp_commit": "101ae38034304346a46ea9ea84ae156d3e860496",
            "scons_version": "4.10.1",
            "runtime_size": len(binary), "runtime_sha256": sha(binary),
            "cases": [
                {"name": name, "status": "passed", "exit_code": 0,
                 "timed_out": False, "log_sha256": sha(logs[name])}
                for name in gate.HOST_TARGETS and (
                    "godot_import", "test_render_world_generation",
                    "test_render_patch_handoff_regression")
            ]
        }
        out[platform] = {"report": raw(report), "runtime": binary,
                         "logs": copy.deepcopy(logs)}
    return out


def make_stage():
    host = bundles()
    sources = {"native/include/source%03d.hpp" % i: "a" * 64
               for i in range(80)}
    build = {"examples/worldgen/build%03d.json" % i: "b" * 64
             for i in range(549)}
    ledgers = {"source_inputs": sources, "build_inputs": build}
    identities = {p: sha(host[p]["runtime"]) for p in host}
    staged = {}
    for p in ("linux", "windows"):
        binary = host[p]["runtime"]
        digest = sha(binary)
        staged[gate.RUNTIME[p]] = {
            "mode": "100644",
            "blob": ("version https://git-lfs.github.com/spec/v1\n"
                     "oid sha256:" + digest + "\n"
                     "size " + str(len(binary)) + "\n").encode()
        }
        report = {
            "schema_version": 1, "platform": p,
            "artifact": gate.RUNTIME[p], "sha256": digest,
            "size": len(binary), "source_commit": gate.BASE,
            "source_tree": gate.TREE, "build_commit": gate.BASE,
            "status": "validated-development-runtime",
            "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" + str(gate.RUN_ID),
            "workflow_attempt": "1", "build_attempt": "1",
            "validation_sha256": sha(host[p]["report"]),
            "validation_output": ("render-copy290-host-evidence-" + p + "-"
                                  + str(gate.RUN_ID) + "/host-evidence.json"),
            "source_inputs": sources, "build_inputs": build,
            "acceptance": gate.BOUNDED_ACCEPTANCE,
            "source_input_hash_kind":
                "SHA-256 of committed Git object bytes (LFS pointer, not payload)",
            "evidence": "docs/audits/2026-10-29-render-copy290-publication-gate.md",
            "validated_platform": ("Linux" if p == "linux" else "Windows")
                                  + " x86_64 Godot 4.7 (actual headless render host)",
            "toolchain": gate.HOST_TARGETS[p][1],
        }
        staged[gate.MANIFEST[p]] = {"mode": "100644", "blob": raw(report)}
    return staged, host, identities, ledgers


class AuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.writer = "c" * 40
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
            "owner_comment_id": 9876543210,
            "destination_branch": gate.BRANCH,
        }
        self.comment = {
            "id": 9876543210,
            "user": {"login": "techrote"},
            "author_association": "OWNER",
            "issue_url": "https://api.github.com/repos/techrote/cybersand/issues/290",
            "html_url": "https://github.com/techrote/cybersand/pull/290#issuecomment-9876543210",
            "created_at": "2026-10-29T21:00:00Z",
            "updated_at": "2026-10-29T21:00:00Z",
            "body": gate.request_text(self.request),
        }

    def good(self, request=None, comment=None, writer=None):
        return gate.verify_owner_authorization(
            raw(self.request if request is None else request),
            self.comment if comment is None else comment,
            self.writer if writer is None else writer)

    def assert_refused(self, request=None, comment=None, writer=None):
        with self.assertRaises(RuntimeError):
            self.good(request, comment, writer)

    def test_valid_synthetic_owner_comment_not_real_authority(self):
        self.assertEqual(self.good()["reviewed_writer_sha"], self.writer)

    def test_untrusted_author_and_edited_owner_message(self):
        for key, value in (("login", "attacker"), ("login", "Techrote")):
            with self.subTest(key=key, value=value):
                c = copy.deepcopy(self.comment)
                c["user"][key] = value
                self.assert_refused(comment=c)
        for k, v in (("author_association", "CONTRIBUTOR"),
                     ("body", "Looks good"),
                     ("updated_at", "2026-10-29T21:00:01Z"),
                     ("created_at", None),
                     ("issue_url", "https://api.github.com/repos/techrote/cybersand/issues/295"),
                     ("id", 9876543211),
                     ("html_url", "https://github.com/techrote/cybersand/pull/295#issuecomment-9876543210")):
            with self.subTest(key=k):
                c = copy.deepcopy(self.comment)
                c[k] = v
                self.assert_refused(comment=c)

    def test_all_request_source_identity_and_scope_refusals(self):
        changes = {
            "schema": "other",
            "intent": "publish-everything",
            "producer_source_sha": "f" * 40,
            "producer_source_tree": "e" * 40,
            "producer_run_id": 40945893161,
            "producer_run_attempt": 2,
            "artifact_ids": {"linux": 12928489443, "windows": 1},
            "artifact_sha256": {"linux": "0" * 64, "windows": gate.ARTIFACT_DIGESTS["windows"]},
            "reviewed_writer_sha": "a" * 40,
            "owner_comment_id": 9876543209,
            "destination_branch": "main",
        }
        for name, altered in changes.items():
            with self.subTest(field=name):
                r = copy.deepcopy(self.request)
                r[name] = altered
                self.assert_refused(request=r)

    def test_missing_extra_duplicate_or_nonfinite_json(self):
        for key in self.request:
            with self.subTest(missing=key):
                r = copy.deepcopy(self.request)
                del r[key]
                self.assert_refused(request=r)
        r = copy.deepcopy(self.request)
        r["arbitrary_extra"] = True
        self.assert_refused(request=r)
        duplicate = raw(self.request).rstrip()[:-1] + b',"schema":"render-copy290-publish-request-v1"}'
        with self.assertRaises(RuntimeError):
            gate.verify_owner_authorization(duplicate, self.comment, self.writer)
        with self.assertRaises(RuntimeError):
            gate.verify_owner_authorization(b'{"missing": NaN}', self.comment, self.writer)

    def test_integer_bool_and_bad_writer_reference_refusals(self):
        for name in ("producer_run_id", "producer_run_attempt", "owner_comment_id"):
            r = copy.deepcopy(self.request)
            r[name] = True
            with self.subTest(name=name):
                self.assert_refused(request=r)
        self.assert_refused(writer="not-a-SHA")
        self.assert_refused(writer="d" * 40)


class AtomicStageTests(unittest.TestCase):
    def setUp(self):
        self.stage, self.host, self.trusted, self.ledgers = make_stage()

    def good(self, stage=None, host=None, trusted=None, ledgers=None):
        return gate.verify_four_path_stage(
            self.stage if stage is None else stage,
            self.host if host is None else host,
            self.trusted if trusted is None else trusted,
            self.ledgers if ledgers is None else ledgers)

    def assert_refused(self, *, stage=None, host=None, trusted=None, ledgers=None):
        with self.assertRaises(RuntimeError):
            self.good(stage, host, trusted, ledgers)

    def test_valid_four_path_synthetic_dry_run(self):
        self.assertTrue(self.good())

    def test_absent_extra_pointer_and_manifest_paths(self):
        for key in self.stage:
            with self.subTest(path=key):
                s = copy.deepcopy(self.stage)
                del s[key]
                self.assert_refused(stage=s)
        s = copy.deepcopy(self.stage)
        s["docs/README.md"] = {"mode": "100644", "blob": b"tampered"}
        self.assert_refused(stage=s)

    def test_symlink_executable_or_unstaged_file(self):
        for name in self.stage:
            for mode in ("120000", "100755", "160000", "0"):
                with self.subTest(path=name, mode=mode):
                    s = copy.deepcopy(self.stage)
                    s[name]["mode"] = mode
                    self.assert_refused(stage=s)

    def test_pointer_hash_size_format_and_no_old_reuse(self):
        for p in ("linux", "windows"):
            for change in (
                b"size 100\n", b"oid sha256:" + b"0" * 64 + b"\n",
                b"version https://git-lfs.github.com/spec/v1\r\n",
                b"\nmore", b"size 00004096\n"):
                with self.subTest(platform=p, change=change):
                    s = copy.deepcopy(self.stage)
                    s[gate.RUNTIME[p]]["blob"] += change
                    self.assert_refused(stage=s)
        trusted = copy.deepcopy(self.trusted)
        trusted["windows"] = gate.RETAINED["windows"][3]
        self.assert_refused(trusted=trusted)

    def test_cross_platform_host_receipt_identity_and_evidence_negative(self):
        for p in ("linux", "windows"):
            with self.subTest(platform=p):
                h = copy.deepcopy(self.host)
                h[p]["logs"]["test_render_world_generation"] += b"FAILED: injected\n"
                self.assert_refused(host=h)
            with self.subTest(platform=p, swapped=True):
                h = copy.deepcopy(self.host)
                h[p]["runtime"] = self.host["windows" if p == "linux" else "linux"]["runtime"]
                self.assert_refused(host=h)

    def test_independent_source_and_build_ledger_refusals(self):
        for key in ("source_inputs", "build_inputs"):
            l = copy.deepcopy(self.ledgers)
            l[key].pop(next(iter(l[key])))
            with self.subTest(kind=key):
                self.assert_refused(ledgers=l)
        l = copy.deepcopy(self.ledgers)
        l["source_inputs"]["bad"] = "not-a-sha"
        self.assert_refused(ledgers=l)

    def test_each_manifest_identity_field_refuses_drift(self):
        path = gate.MANIFEST["linux"]
        changes = {
            "source_commit": "1" * 40, "source_tree": "2" * 40,
            "build_commit": "3" * 40, "platform": "windows",
            "workflow_run": "https://github.com/techrote/cybersand/actions/runs/1",
            "workflow_attempt": "2",
            "validation_sha256": "4" * 64,
            "status": "built-not-executed", "schema_version": 2,
            "size": 0, "sha256": "5" * 64,
            "acceptance": "all tests passed",
            "artifact": "godot/addons/cybersand_native/bin/wrong.so",
        }
        for key, altered in changes.items():
            with self.subTest(field=key):
                s = copy.deepcopy(self.stage)
                m = json.loads(s[path]["blob"])
                m[key] = altered
                s[path]["blob"] = raw(m)
                self.assert_refused(stage=s)

    def test_duplicate_manifest_and_mismatching_build_hash(self):
        path = gate.MANIFEST["windows"]
        s = copy.deepcopy(self.stage)
        s[path]["blob"] = s[path]["blob"].rstrip()[:-1] + b',"size":4096}'
        self.assert_refused(stage=s)
        s = copy.deepcopy(self.stage)
        m = json.loads(s[path]["blob"])
        key = next(iter(m["build_inputs"]))
        m["build_inputs"][key] = "c" * 64
        s[path]["blob"] = raw(m)
        self.assert_refused(stage=s)


if __name__ == "__main__":
    unittest.main(verbosity=2)
