#!/usr/bin/env python3
"""Adversarial fail-closed tests for unarmed PR #290 four-path LFS publisher."""
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import urllib.request
import zipfile

import render_copy290_runtime_publication as subject


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def owner_request():
    parent = "a" * 40
    sequence = 1
    body = ("AUTHORIZE render-copy290 four-path LFS publication\n"
            "parent=" + parent + "\nsequence=1\n"
            "scope=source-matched-linux-windows-development-runtimes")
    req = {"schema": "render-copy290-publish-request-v1",
           "intent": "publish-source-matched-four-path-runtimes",
           "request_sequence": sequence,
           "authorized_parent_sha": parent,
           "owner_comment_id": 1234,
           "owner_comment_sha256": digest(body.encode()),
           "outputs": sorted(subject.FOUR)}
    comment = {"user": {"login": "techrote"}, "author_association": "OWNER",
               "issue_url": "https://api.github.com/repos/techrote/cybersand/issues/290",
               "body": body, "id": 1234}
    return req, comment, parent


def sample_elf():
    data = bytearray(4097)
    data[:6] = b"\x7fELF\x02\x01"
    data[16:20] = b"\x03\x00\x3e\x00"
    return bytes(data)


def sample_dll():
    data = bytearray(4097)
    data[:2] = b"MZ"
    data[60:64] = (64).to_bytes(4, "little")
    data[64:70] = b"PE\0\0\x64\x86"
    data[64 + 22:64 + 24] = (0x2000).to_bytes(2, "little")
    data[64 + 24:64 + 26] = b"\x0b\x02"
    return bytes(data)


class RequestRefusal(unittest.TestCase):
    def test_only_exact_owner_authorization(self):
        req, comment, parent = owner_request()
        self.assertTrue(subject.validate_request(req, comment, parent, "b" * 40, {subject.REQUEST}))

    def test_request_identity_refusals(self):
        req, comment, parent = owner_request()
        mutations = [
            {"request_sequence": 0}, {"request_sequence": True},
            {"request_sequence": -1}, {"authorized_parent_sha": "b" * 40},
            {"owner_comment_id": 0}, {"owner_comment_id": True},
            {"owner_comment_sha256": "0" * 64}, {"schema": "unknown"},
            {"intent": "publish-anything"}, {"outputs": ["x", "y", "z", "w"]},
            {"outputs": [*sorted(subject.FOUR), "additional"]},
        ]
        for update in mutations:
            with self.subTest(update=update):
                with self.assertRaises((RuntimeError, TypeError, ValueError)):
                    subject.validate_request(dict(req, **update), comment, parent, "b" * 40, {subject.REQUEST})

    def test_comment_provenance_and_body_refusals(self):
        req, comment, parent = owner_request()
        for update in [
            {"user": {"login": "somebody"}}, {"author_association": "CONTRIBUTOR"},
            {"issue_url": "https://api.github.com/repos/techrote/cybersand/issues/295"},
            {"body": comment["body"] + "\nrequest=2"}, {"id": 1235},
            {"user": {}}, {"author_association": None},
        ]:
            with self.subTest(update=update):
                with self.assertRaises(RuntimeError):
                    subject.validate_request(req, dict(comment, **update), parent, "b" * 40, {subject.REQUEST})

    def test_request_changes_must_be_only_one_path(self):
        req, comment, parent = owner_request()
        for files in [set(), {"native/src/world.cpp"},
                      {subject.REQUEST, "native/src/world.cpp"}]:
            with self.subTest(files=files):
                with self.assertRaises(RuntimeError):
                    subject.validate_request(req, comment, parent, "b" * 40, files)

    def test_request_cannot_authorize_own_source(self):
        req, comment, parent = owner_request()
        with self.assertRaises(RuntimeError):
            subject.validate_request(req, comment, parent, parent, {subject.REQUEST})

    def test_extra_field_refused(self):
        req, comment, parent = owner_request()
        req["publisher_override"] = True
        with self.assertRaises(RuntimeError):
            subject.validate_request(req, comment, parent, "b" * 40, {subject.REQUEST})

    def test_unarmed_preparation_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(subject, "ROOT", Path(tmp)), \
                 mock.patch.object(subject, "repo_identity", return_value={"source": "abc"}), \
                 mock.patch.object(subject, "git") as g:
                def fake_git(*args):
                    if args[:2] == ("diff", "--name-only"):
                        return ("\n".join(sorted(subject.PREP_DELTA)) + "\n").encode()
                    if args[:2] == ("ls-tree", "-r"):
                        return b"Makefile\nnative/src/world.cpp\n"
                    raise RuntimeError("Unexpected git call")
                g.side_effect = fake_git
                self.assertIsNone(subject.request_status("c" * 40, remote=False))

    def test_unarmed_unexpected_change_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(subject, "ROOT", Path(tmp)), \
                 mock.patch.object(subject, "repo_identity", return_value={}), \
                 mock.patch.object(subject, "git", return_value=b"native/src/world.cpp\n"):
                with self.assertRaises(RuntimeError):
                    subject.request_status("c" * 40, remote=False)


class DataIntegrity(unittest.TestCase):
    def test_runtime_binary_kind(self):
        subject.runtime_kind(sample_elf(), "linux")
        subject.runtime_kind(sample_dll(), "windows")

    def test_executable_not_shared_object(self):
        elf = bytearray(sample_elf())
        elf[16:18] = b"\x02\x00"
        with self.assertRaises(RuntimeError):
            subject.runtime_kind(bytes(elf), "linux")
        win = bytearray(sample_dll())
        win[64 + 22:64 + 24] = b"\x00\x00"
        with self.assertRaises(RuntimeError):
            subject.runtime_kind(bytes(win), "windows")

    def test_windows_pe32_refusal(self):
        win = bytearray(sample_dll())
        win[64 + 24:64 + 26] = b"\x0b\x01"
        with self.assertRaises(RuntimeError):
            subject.runtime_kind(bytes(win), "windows")

    def test_selected_86_independent_hashes(self):
        raw = "".join("a" * 64 + "  native/tests/case" + str(i) + ".gd\n"
                      for i in range(86)).encode()
        self.assertEqual(len(subject.selected_hashes(raw)), 86)

    def test_selected_input_duplicates_refused(self):
        raw = ("a" * 64 + "  duplicate\n") * 86
        with self.assertRaises(RuntimeError):
            subject.selected_hashes(raw.encode())

    def test_selected_input_unsafe_path_refused(self):
        raw = "".join("a" * 64 + "  " +
                      ("../parent" if i == 85 else "native/tests/case" + str(i))
                      + "\n" for i in range(86)).encode()
        with self.assertRaises(RuntimeError):
            subject.selected_hashes(raw)

    def test_selected_input_missing_case_refused(self):
        raw = "".join("a" * 64 + "  native/tests/case" + str(i) + "\n"
                      for i in range(85)).encode()
        with self.assertRaises(RuntimeError):
            subject.selected_hashes(raw)

    def test_original_zip_integrity_and_members(self):
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, "w") as z:
            z.writestr("source.txt", "known\n")
            z.writestr("runtime.sha256", "value\n")
        got = subject.original_members(raw.getvalue(), {"source.txt"}, "fixture")
        self.assertEqual(got["source.txt"], b"known\n")
        with self.assertRaises(RuntimeError):
            subject.original_members(raw.getvalue(), {"missing.txt"}, "fixture")

    def test_duplicate_archive_entries_refused(self):
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, "w") as z:
            z.writestr("source.txt", "one")
            with unittest.mock.patch("warnings.warn"):
                z.writestr("source.txt", "two")
        with self.assertRaises(RuntimeError):
            subject.original_members(raw.getvalue(), {"source.txt"}, "fixture")

    def test_archive_traversal_refused(self):
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, "w") as z:
            z.writestr("../source.txt", "bad")
        with self.assertRaises(RuntimeError):
            subject.original_members(raw.getvalue(), {"../source.txt"}, "fixture")

    def test_empty_runtime_refused(self):
        for platform in ("linux", "windows"):
            with self.subTest(platform=platform):
                with self.assertRaises(RuntimeError):
                    subject.runtime_kind(b"", platform)


class ArtifactAuth(unittest.TestCase):
    def test_signed_redirect_never_forwards_token(self):
        original = urllib.request.Request(
            "https://api.github.com/repos/techrote/cybersand/actions/artifacts/1/zip",
            headers={"Authorization": "Bearer secret", "Accept": "application/zip"})
        redirected = subject.SafeRedirect().redirect_request(
            original, None, 302, "Redirect",
            {}, "https://fake.blob.core.windows.net/signed.zip?token=signature")
        self.assertIsNotNone(redirected)
        self.assertFalse(any(k.lower() == "authorization" for k in redirected.headers))

    def test_external_redirect_host_refusal(self):
        original = urllib.request.Request("https://api.github.com/any",
                                          headers={"Authorization": "Bearer secret"})
        with self.assertRaises(RuntimeError):
            subject.SafeRedirect().redirect_request(
                original, None, 302, "Redirect", {},
                "https://attacker.example/signed.zip")

    def test_http_artifact_refusal(self):
        original = urllib.request.Request("https://api.github.com/any")
        with self.assertRaises(RuntimeError):
            subject.SafeRedirect().redirect_request(
                original, None, 302, "Redirect", {}, "http://unsafe.example/zip")

    def test_lease_must_equal_exact_head(self):
        with mock.patch.object(subject, "git", return_value=b"x" * 40 +
                               b"\trefs/heads/" + subject.BRANCH.encode()):
            with self.assertRaises(RuntimeError):
                subject.lease("y" * 40)

    def test_lease_correct(self):
        source = "c" * 40
        with mock.patch.object(subject, "git", return_value=source.encode() +
                               b"\trefs/heads/" + subject.BRANCH.encode()):
            subject.lease(source)

    def test_write_allowlist_exact_four_paths(self):
        self.assertEqual(len(subject.FOUR), 4)
        self.assertEqual(len(subject.OUTPUT), 2)
        self.assertEqual(len(subject.MANIFEST), 2)
        self.assertEqual(set(subject.OUTPUT.values()) | set(subject.MANIFEST.values()),
                         subject.FOUR)

    def test_final_stage_rejects_mismatched_staged_paths(self):
        with mock.patch.object(subject, "repo_identity", return_value={}), \
             mock.patch.object(subject, "git", return_value=b"native/src/world.cpp\0"):
            with self.assertRaises(RuntimeError):
                subject.check_index("c" * 40)


def make_zip(members):
    result = io.BytesIO()
    with zipfile.ZipFile(result, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for path, value in members.items():
            z.writestr(path, value)
    return result.getvalue()


class StagingContract(unittest.TestCase):
    """Exercise the real stage() assembly without a live owner request or git add."""

    def fixture(self, *, corrupt_windows=False, missing_windows=False):
        source = "c" * 40
        tree = "d" * 40
        linux = sample_elf()
        windows = sample_dll()
        selected = {f"native/tests/case{i}.gd": "a" * 64 for i in range(86)}
        selected_text = "".join(v + "  " + k + "\n" for k, v in selected.items()).encode()
        checked = "".join(k + ": OK\n" for k in selected).encode()
        tracked = json.dumps({"schema": "fixture",
                              "source_sha": source, "source_tree": tree,
                              "input_count": len(selected), "inputs": selected}).encode()
        def build(runtime, platform):
            props = {
                "source.txt": (source + "\n").encode(),
                "tree.txt": (tree + "\n").encode(),
                "tracked-git-inputs.json": tracked,
                "selected-build-inputs.sha256": selected_text,
                "post-build-input-check.txt": checked,
                "runtime.sha256": (digest(runtime) + "  runtime\n").encode(),
                "compiler-version.txt": b"pinned compiler\n",
                "scons-version.txt": b"4.10.1\n",
                "godot-cpp-commit.txt": (subject.GODOT_CPP + "\n").encode(),
                "native-build.txt": b"native build passed\n",
                "godot-cpp-build.txt": b"godot-cpp build passed\n",
            }
            if platform == "linux":
                props["post-host-input-check.txt"] = checked
            else:
                props["cybersand_native.windows.x86_64.dll"] = runtime
            return make_zip(props)
        def host(runtime, platform):
            payload = {"source_sha": source, "source_tree": tree,
                       "runtime_sha256": digest(runtime), "runtime_size": len(runtime),
                       "toolchain": "gcc-13" if platform == "linux"
                       else "llvm-mingw-20260826-ucrt"}
            return make_zip({
                "host-evidence.json": json.dumps(payload).encode(),
                "runtime/" + Path(subject.OUTPUT[platform]).name: runtime,
                "logs/godot_import.log": b"Godot Engine v4.7\n",
                "logs/test_render_world_generation.log":
                    b"RENDER_WORLD_GENERATION: 23 assertions, 0 failures\n",
                "logs/test_render_patch_handoff_regression.log":
                    b"Render patch handoff regression passed\n",
            })
        if corrupt_windows:
            windows = bytes([windows[0] ^ 1]) + windows[1:]
        artifacts = {
            "linux-build": build(linux, "linux"),
            "windows-build": build(sample_dll(), "windows"),
            "linux-host": host(linux, "linux"),
            "windows-host": host(windows, "windows"),
        }
        if missing_windows:
            artifacts.pop("windows-host")
        digest_map = {k: "sha256:" + digest(v) for k, v in artifacts.items()}
        return source, tree, artifacts, digest_map

    def run_stage(self, *, corrupt_windows=False, missing_windows=False):
        source, tree, artifacts, digests = self.fixture(
            corrupt_windows=corrupt_windows, missing_windows=missing_windows)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for path in subject.FOUR:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
            def fake_git(*args):
                if args == ("rev-parse", source + "^{tree}"):
                    return tree.encode()
                if args[0] == "diff":
                    return b""
                raise AssertionError("Unexpected git: " + repr(args))
            with mock.patch.object(subject, "ROOT", root), \
                 mock.patch.object(subject, "request_status", return_value={"request": "fixture"}), \
                 mock.patch.object(subject, "authenticated_producer_artifacts",
                                   return_value=(artifacts, digests)), \
                 mock.patch.object(subject, "source_ledgers",
                                   return_value={"source_inputs": {}, "build_inputs": {}}), \
                 mock.patch.object(subject, "repo_identity",
                                   return_value={"source_commit": source,
                                                 "source_tree": tree,
                                                 "build_commit": source,
                                                 "workflow_run": "fixture",
                                                 "workflow_attempt": "1"}), \
                 mock.patch.object(subject, "git", side_effect=fake_git), \
                 mock.patch.object(subject, "check_index", return_value=True), \
                 mock.patch.object(subject.subprocess, "run") as add, \
                 mock.patch.dict(subject.os.environ,
                                 {"GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1"}):
                if corrupt_windows or missing_windows:
                    with self.assertRaises((RuntimeError, KeyError)):
                        subject.stage(source)
                    add.assert_not_called()
                    self.assertFalse(any((root / name).exists()
                                         for name in subject.FOUR))
                else:
                    subject.stage(source)
                    add.assert_called_once()
                    for platform in subject.HOST_TARGETS:
                        identity = json.loads((root / subject.MANIFEST[platform]).read_text())
                        data = (root / subject.OUTPUT[platform]).read_bytes()
                        self.assertEqual(identity["source_commit"], source)
                        self.assertEqual(identity["source_tree"], tree)
                        self.assertEqual(identity["sha256"], digest(data))
                        self.assertEqual(identity["size"], len(data))
                        self.assertEqual(identity["status"], "validated-development-runtime")

    def test_stages_exactly_both_binaries_and_manifests(self):
        self.run_stage()

    def test_refuses_mismatched_build_host_binary_without_any_stage(self):
        self.run_stage(corrupt_windows=True)

    def test_refuses_missing_host_before_stage(self):
        self.run_stage(missing_windows=True)


if __name__ == "__main__":
    unittest.main()
