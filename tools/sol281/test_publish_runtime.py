#!/usr/bin/env python3
"""Adverse publication controls; synthetic metadata makes no physics claim."""
import argparse
import copy
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import publish_runtime as subject


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sol281-publish-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.ctx = {"source": {"sha": "a" * 40, "tree": "b" * 40}, "run_id": "123", "run_attempt": "2",
                    "repository": subject.REPOSITORY, "ref": "refs/heads/" + subject.BRANCH,
                    "workflow_run": "https://github.com/techrote/cybersand/actions/runs/123"}
        self.inputs = {"native/src/fixture.cpp": "c" * 64}

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(subject.encoded(value))

    def bundle(self):
        directory = self.root / "build"
        directory.mkdir()
        data = bytearray(8192)
        data[:6] = b"\x7fELF\x02\x01"
        data[16:20] = b"\x03\x00\x3e\x00"
        runtime = directory / Path(subject.RUNTIMES["linux"]).name
        runtime.write_bytes(data)
        base = {"schema": "cybersand.sol281.source-build.v1", "source": self.ctx["source"],
                "inputs": self.inputs, "checkout_inputs": self.inputs}
        self.write(directory / "before.json", base)
        build = {**base, "before_manifest_sha256": subject.qualification.digest(directory / "before.json"),
                 "runtime": {"filename": runtime.name, "sha256": subject.sha(data), "size": len(data)},
                 "bindings": {"filename": "libgodot-cpp.linux.template_debug.x86_64.a", "sha256": "d" * 64,
                              "revision": subject.BINDINGS_REVISION}, "compiler": "synthetic compiler identity"}
        self.write(directory / "build.json", build)
        for name in ("prepare", "bindings", "extension", "native-regressions"):
            command = directory / name
            command.mkdir()
            (command / "command.log").write_bytes(b"original completed command\n")
            (command / "performance.jsonl").write_bytes(b"")
            self.write(command / "receipt.json", {"schema": "execution-command-v1", "status": "passed",
                "returncode": 0, "complete": True, "natural_completion": True, "timed_out": False,
                "log": "command.log", "log_sha256": subject.qualification.digest(command / "command.log"),
                "source": {"commit": self.ctx["source"]["sha"], "tree": self.ctx["source"]["tree"],
                           "run_id": "123", "run_attempt": "2"}})
        (directory / "source.tar.gz").write_bytes(b"synthetic source archive")
        (directory / "source.tar.gz.sha256").write_text(subject.qualification.digest(directory / "source.tar.gz") + "  source.tar.gz\n")
        return directory

    def test_build_rejects_missing_or_changed_identity(self):
        directory = self.bundle()
        subject.verify_build(directory, "linux", self.ctx, self.inputs)
        original = subject.load(directory / "build.json")
        cases = [lambda d: d.update(source={"sha": "e" * 40, "tree": "b" * 40}),
                 lambda d: d.update(inputs={}), lambda d: d.update(checkout_inputs={}),
                 lambda d: d.update(compiler=""), lambda d: d["bindings"].update(revision="f" * 40),
                 lambda d: d["runtime"].update(sha256="0" * 64),
                 lambda d: d.update(before_manifest_sha256="0" * 64)]
        for mutate in cases:
            with self.subTest(mutation=mutate):
                changed = copy.deepcopy(original)
                mutate(changed)
                self.write(directory / "build.json", changed)
                with self.assertRaises(RuntimeError):
                    subject.verify_build(directory, "linux", self.ctx, self.inputs)
        self.write(directory / "build.json", original)
        (directory / "unexpected.json").write_text("{}")
        with self.assertRaisesRegex(RuntimeError, "inventory"):
            subject.verify_build(directory, "linux", self.ctx, self.inputs)

    def test_build_rejects_previous_attempt_or_failed_command(self):
        directory = self.bundle()
        path = directory / "extension/receipt.json"
        original = subject.load(path)
        for mutation in (lambda d: d["source"].update(run_attempt="1"),
                         lambda d: d["source"].update(run_id="122"),
                         lambda d: d.update(natural_completion=False),
                         lambda d: d.update(returncode=1),
                         lambda d: d.update(log="../command.log")):
            changed = copy.deepcopy(original)
            mutation(changed)
            self.write(path, changed)
            with self.assertRaises(RuntimeError):
                subject.verify_build(directory, "linux", self.ctx, self.inputs)

    def test_runtime_signature_and_lfs_pointer_are_not_interchangeable(self):
        path = self.root / "runtime"
        path.write_bytes(b"version https://git-lfs.github.com/spec/v1\noid sha256:" + b"a" * 64 + b"\nsize 8192\n")
        for target in ("linux", "windows"):
            with self.assertRaises(RuntimeError):
                subject.commonengine.runtime_identity(path, target)
        data = bytearray(8192)
        data[:2] = b"MZ"
        struct.pack_into("<I", data, 60, 64)
        data[64:70] = b"PE\0\0\x64\x86"
        struct.pack_into("<H", data, 86, 0x2000)
        data[88:90] = b"\x0b\x02"
        path.write_bytes(data)
        self.assertEqual(subject.commonengine.runtime_identity(path, "windows")["size"], 8192)
        with self.assertRaises(RuntimeError):
            subject.commonengine.runtime_identity(path, "linux")

    def test_artifact_inventory_and_paths_fail_closed(self):
        root = self.root / "artifacts"
        root.mkdir()
        (root / "expected-123-2").mkdir()
        subject.artifact_roots(root, ["expected-123-2"])
        with self.assertRaises(RuntimeError):
            subject.artifact_roots(root, ["expected-123-1"])
        (root / "extra").mkdir()
        with self.assertRaises(RuntimeError):
            subject.artifact_roots(root, ["expected-123-2"])
        for path in ("../escape", "/absolute", "a/../b", "a\\b", "a//b", "x\nname"):
            with self.assertRaises(RuntimeError):
                subject.safe_relative(path)
        (root / "link").symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(RuntimeError):
            subject.files_in(root)

    def test_context_requires_actual_workflow_repository_and_source(self):
        environment = {"GITHUB_ACTIONS": "true", "RUNNER_ENVIRONMENT": "github-hosted", "RUNNER_OS": "Linux",
            "GITHUB_REPOSITORY": subject.REPOSITORY, "GITHUB_REF": self.ctx["ref"], "GITHUB_SERVER_URL": "https://github.com",
            "GITHUB_EVENT_NAME": "push", "GITHUB_SHA": "a" * 40, "GITHUB_WORKFLOW_SHA": "a" * 40,
            "GITHUB_WORKFLOW_REF": subject.REPOSITORY + "/.github/workflows/sol281-current-main.yml@" + self.ctx["ref"],
            "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "2"}
        with patch.object(subject.qualification, "source_identity", return_value=self.ctx["source"]), \
             patch.object(subject.qualification, "git", return_value=b"false\n"):
            with patch.dict(os.environ, environment, clear=True):
                self.assertEqual(subject.context(), self.ctx)
            for field, bad in (("RUNNER_ENVIRONMENT", "self-hosted"), ("GITHUB_REPOSITORY", "other/repo"),
                               ("GITHUB_REF", "refs/heads/main"), ("GITHUB_SHA", "f" * 40),
                               ("GITHUB_WORKFLOW_SHA", "f" * 40), ("GITHUB_WORKFLOW_REF", "other.yml"),
                               ("GITHUB_RUN_ATTEMPT", "0")):
                with patch.dict(os.environ, {**environment, field: bad}, clear=True), self.assertRaises(RuntimeError):
                    subject.context()

    def test_metadata_transition_does_not_exempt_other_source(self):
        native_path = "native/src/fixture.cpp"
        manifest_path = subject.MANIFESTS["linux"]
        source = {native_path: b"source\n", manifest_path: b"old provenance\n"}
        generated = {manifest_path: b"new source-bound provenance\n"}
        for path, raw in source.items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(generated.get(path, raw))
        ordered = sorted(source)
        blobs = b"".join(b"a" * 40 + b" blob " + str(len(source[p])).encode() + b"\n" + source[p] + b"\n" for p in ordered)
        with patch.object(subject, "ROOT", self.root), \
             patch.object(subject.qualification, "committed_crlf_paths", return_value=set()), \
             patch.object(subject.subprocess, "check_output", return_value=blobs):
            inputs = {p: subject.sha(raw) for p, raw in source.items()}
            subject.verify_checkout(inputs, generated)
            (self.root / native_path).write_bytes(b"changed source\n")
            with self.assertRaisesRegex(RuntimeError, "Qualified source changed"):
                subject.verify_checkout(inputs, generated)
            (self.root / native_path).write_bytes(source[native_path])
            (self.root / manifest_path).write_bytes(b"forged provenance\n")
            with self.assertRaisesRegex(RuntimeError, "trusted original artifacts"):
                subject.verify_checkout(inputs, generated)

    def test_partial_runtime_write_restores_original_publication(self):
        fixed = [*subject.RUNTIMES.values(), *subject.MANIFESTS.values()]
        original = {path: ("old " + path).encode() for path in fixed}
        for relative, data in original.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        base = subject.EVIDENCE + "/" + "a" * 40
        evidence = base + "/original.log"
        plan = {**{path: b"new runtime/provenance bytes" for path in fixed}, evidence: b"new evidence\r\n"}
        args = argparse.Namespace(output=self.root / "receipt.json")
        broken = self.root / subject.RUNTIMES["linux"]
        real_write = Path.write_bytes
        injected = False
        def partial_write(path, data):
            nonlocal injected
            if path == broken and not injected:
                injected = True
                real_write(path, data[:2])
                raise OSError("injected partial runtime write")
            return real_write(path, data)
        with patch.object(subject, "ROOT", self.root), patch.object(Path, "write_bytes", partial_write), \
             patch.object(subject, "verify_prepared") as verify:
            with self.assertRaisesRegex(OSError, "partial runtime write"):
                subject.install_plan(plan, {}, args, base)
            verify.assert_not_called()
        self.assertTrue(injected)
        self.assertEqual({path: (self.root / path).read_bytes() for path in fixed}, original)
        self.assertFalse((self.root / base).exists())
        self.assertFalse(args.output.exists())

    def test_staged_inventory_lfs_and_original_crlf_bytes(self):
        runtime = subject.RUNTIMES["linux"]
        evidence = subject.EVIDENCE + "/" + "a" * 40 + "/original.json"
        raw = b'{"original":"Windows"}\r\n'
        identity = {runtime: {"sha256": "f" * 64, "size": 8192},
                    evidence: {"sha256": subject.sha(raw), "size": len(raw)}}
        paths = sorted(identity)
        pointer = b"version https://git-lfs.github.com/spec/v1\noid sha256:" + b"f" * 64 + b"\nsize 8192\n"
        blobs = {runtime: pointer, evidence: raw}
        changed = list(paths)
        def git(*args):
            if args[0] == "diff":
                return "\0".join(changed).encode() + b"\0"
            if args[0] == "ls-files":
                return ("100644 " + "a" * 40 + " 0\t" + args[-1] + "\n").encode()
            if args[0] == "show":
                return blobs[args[1][1:]]
            raise AssertionError(args)
        with patch.object(subject.qualification, "git", side_effect=git):
            subject.verify_index(paths, identity)
            blobs[evidence] = raw.replace(b"\r\n", b"\n")
            with self.assertRaisesRegex(RuntimeError, "EOL"):
                subject.verify_index(paths, identity)
            blobs[evidence] = raw
            blobs[runtime] = pointer.replace(b"8192", b"8193")
            with self.assertRaisesRegex(RuntimeError, "LFS"):
                subject.verify_index(paths, identity)
            blobs[runtime] = pointer
            changed.append("unrelated/source.cpp")
            with self.assertRaisesRegex(RuntimeError, "path set"):
                subject.verify_index(paths, identity)

    def staged_checkout(self, name, unchanged_overrides=None):
        # Real Git index/HEAD behavior, with canonical pointer bytes as fixture
        # input. Runtime format and artifact attribution have separate tests.
        checkout = self.root / name
        checkout.mkdir()

        def git(*args):
            return subprocess.check_output(["git", "-C", str(checkout), *args],
                                           stderr=subprocess.PIPE, timeout=30)

        git("init", "-q")
        git("config", "user.name", "SOL281 publication fixture")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "core.autocrlf", "false")
        runtime = subject.RUNTIMES["linux"]
        manifest = subject.MANIFESTS["linux"]
        evidence = subject.EVIDENCE + "/" + "a" * 40 + "/original.json"
        source = "tools/sol281/source-fixture.json"
        source_bytes = b'{"source":"unchanged"}\n'
        pointer = (b"version https://git-lfs.github.com/spec/v1\noid sha256:"
                   + b"f" * 64 + b"\nsize 8192\n")
        # Matching source/evidence bytes expose Git rename folding if source is
        # deleted; the publication verifier must account for both paths.
        plan = {runtime: pointer, manifest: b'{"source":"qualified"}\n',
                evidence: source_bytes}
        before = {".gitattributes": b"* -text\n", runtime: pointer, manifest: b'{"source":"earlier"}\n',
                  source: source_bytes, **(unchanged_overrides or {})}
        for relative, data in before.items():
            destination = checkout / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        git("add", "--", *before)
        git("-c", "commit.gpgsign=false", "commit", "-qm", "original publication")
        for relative, data in {**plan, **(unchanged_overrides or {})}.items():
            destination = checkout / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        git("add", "--", *plan)
        identities = {path: {"sha256": subject.sha(raw), "size": len(raw)}
                      for path, raw in plan.items()}
        identities[runtime] = {"sha256": "f" * 64, "size": 8192}
        return checkout, git, plan, identities, source

    def test_real_git_index_allows_unchanged_runtime(self):
        manifest = subject.MANIFESTS["linux"]
        for name, overrides in (("new-metadata", {}),
                                ("same-metadata", {manifest: b'{"source":"qualified"}\n'})):
            with self.subTest(case=name):
                checkout, git, plan, identities, _ = self.staged_checkout(name, overrides)
                changed = set(git("diff", "--cached", "--no-renames", "--name-only", "-z", "HEAD").decode().split("\0")) - {""}
                expected = set(plan) - {subject.RUNTIMES["linux"]} - set(overrides)
                self.assertEqual(changed, expected)
                with patch.object(subject.qualification, "ROOT", checkout):
                    subject.verify_index(sorted(plan), identities)

    def test_real_git_index_rejects_invalid_unchanged_blobs(self):
        runtime = subject.RUNTIMES["linux"]
        pointer = (b"version https://git-lfs.github.com/spec/v1\noid sha256:"
                   + b"f" * 64 + b"\nsize 8192\n")
        cases = (("wrong-oid", runtime, pointer.replace(b"f" * 64, b"e" * 64), "LFS"),
                 ("wrong-size", runtime, pointer.replace(b"8192", b"8193"), "LFS"),
                 ("malformed-pointer", runtime, pointer.replace(b"version ", b"invalid "), "LFS"),
                 ("stale-metadata", subject.MANIFESTS["linux"], b'{"source":"stale"}\n', "evidence/provenance"))
        for name, path, raw, error in cases:
            with self.subTest(case=name):
                checkout, git, plan, identities, _ = self.staged_checkout(name, {path: raw})
                self.assertEqual(git("show", "HEAD:" + path), git("show", ":" + path))
                with patch.object(subject.qualification, "ROOT", checkout), self.assertRaisesRegex(RuntimeError, error):
                    subject.verify_index(sorted(plan), identities)

    def test_real_git_index_rejects_missing_staging_and_unplanned_changes(self):
        cases = (("unstaged-metadata", "evidence/provenance"),
                 ("unstaged-new-file", "stage-zero"),
                 ("deleted-runtime", "stage-zero"),
                 ("executable-runtime", "stage-zero"),
                 ("extra-source-edit", "path set"),
                 ("extra-source-deletion", "path set"))
        for name, error in cases:
            with self.subTest(case=name):
                checkout, git, plan, identities, source = self.staged_checkout(name)
                evidence = next(path for path in plan if path.startswith(subject.EVIDENCE + "/"))
                if name == "unstaged-metadata":
                    git("reset", "-q", "HEAD", "--", subject.MANIFESTS["linux"])
                elif name == "unstaged-new-file":
                    git("reset", "-q", "HEAD", "--", evidence)
                elif name == "deleted-runtime":
                    git("rm", "--cached", "--", subject.RUNTIMES["linux"])
                elif name == "executable-runtime":
                    git("update-index", "--chmod=+x", "--", subject.RUNTIMES["linux"])
                elif name == "extra-source-edit":
                    (checkout / source).write_bytes(b"unqualified source edit\n")
                    git("add", "--", source)
                else:
                    git("rm", "--", source)
                    self.assertIn(("R100\t" + source + "\t" + evidence + "\n").encode(),
                                  git("diff", "--cached", "--name-status", "-M", "HEAD"))
                with patch.object(subject.qualification, "ROOT", checkout), self.assertRaisesRegex(RuntimeError, error):
                    subject.verify_index(sorted(plan), identities)

    def test_real_git_checkout_still_rejects_unstaged_source_edits(self):
        checkout, git, plan, identities, source = self.staged_checkout("unstaged-source")
        manifest = subject.MANIFESTS["linux"]
        inputs = {path: subject.sha(git("show", "HEAD:" + path)) for path in (source, manifest)}
        generated = {manifest: plan[manifest]}
        with patch.object(subject, "ROOT", checkout), patch.object(subject.qualification, "ROOT", checkout):
            subject.verify_checkout(inputs, generated)
            (checkout / source).write_bytes(b"unstaged unqualified source edit\n")
            # Index validation does not replace the unchanged checkout contract.
            subject.verify_index(sorted(plan), identities)
            with self.assertRaisesRegex(RuntimeError, "Qualified source changed"):
                subject.verify_checkout(inputs, generated)

    def test_real_git_staging_preserves_current_and_historical_evidence_bytes(self):
        # Exercise the actual repository attributes and Git clean filters. A
        # mocked index cannot catch a newly dated archive missing its -text rule.
        attributes = (subject.ROOT / ".gitattributes").read_bytes()
        checkout = self.root / "checkout"
        checkout.mkdir()

        def git(*args):
            return subprocess.check_output(["git", "-C", str(checkout), *args],
                                           stderr=subprocess.PIPE, timeout=30)

        git("init", "-q")
        git("config", "user.name", "SOL281 publication fixture")
        git("config", "user.email", "fixture@example.invalid")
        (checkout / ".gitattributes").write_bytes(attributes)
        control = "tools/sol281/attribute-control.json"
        (checkout / control).parent.mkdir(parents=True)
        (checkout / control).write_bytes(b'{"source":"canonical LF"}\r\n')
        git("add", "--", ".gitattributes", control)
        # The archive exception must not disable ordinary source normalization.
        self.assertEqual(git("show", ":" + control), b'{"source":"canonical LF"}\n')
        git("-c", "commit.gpgsign=false", "commit", "-qm", "fixture attributes and source")

        source = "a" * 40
        plan = {
            subject.EVIDENCE + "/" + source + "/cohorts/windows/contact-w1/report.json":
                b'{"platform":"Windows","original":true}\r\n',
            subject.EVIDENCE + "/" + source + "/cohorts/windows/mechanism/qualification.log":
                b"original Windows output\r\nsecond line\r\n\r\n",
            subject.EVIDENCE + "/" + source + "/cohorts/linux/core/report.json":
                b'{"platform":"Linux","original":true}\n',
            "docs/audits/sol281-20261101/hosted/" + source + "/original.json":
                b'{"historical":"unaltered Windows evidence"}\r\n',
        }
        for relative, raw in plan.items():
            destination = checkout / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
        paths = sorted(plan)
        git("add", "--", *paths)
        for relative, raw in plan.items():
            with self.subTest(path=relative):
                self.assertEqual(git("show", ":" + relative), raw)
        identities = {path: {"sha256": subject.sha(raw), "size": len(raw)}
                      for path, raw in plan.items()}
        with patch.object(subject.qualification, "ROOT", checkout):
            subject.verify_index(paths, identities)
        git("diff", "--cached", "--check")


if __name__ == "__main__":
    unittest.main()
