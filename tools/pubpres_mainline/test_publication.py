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


class OriginalEvidenceTransportTests(unittest.TestCase):
    """Original byte custody must survive chunking and reject plausible substitutes."""

    @staticmethod
    def archive(entries=None):
        import gzip
        import io
        import tarfile
        entries = entries if entries is not None else [("observations/data.bin", bytes(range(256))*2, None)]
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode="w", format=tarfile.USTAR_FORMAT) as archive:
            for name, payload, kind in entries:
                member = tarfile.TarInfo(name)
                member.type = kind or tarfile.REGTYPE
                member.size = len(payload) if member.isfile() else 0
                archive.addfile(member, io.BytesIO(payload) if member.isfile() else None)
        return gzip.compress(data.getvalue(), mtime=0)

    def specimen(self, raw=None):
        import base64
        import hashlib
        import publish_local_evidence as evidence
        raw = self.archive() if raw is None else raw
        chunks, replies = [], {}
        for offset in range(0, len(raw), 96):
            part = raw[offset:offset+96]
            sha = evidence.git_blob_sha(part)
            chunks.append({"offset": offset, "bytes": len(part), "sha256": hashlib.sha256(part).hexdigest(), "git_blob": sha})
            replies[sha] = {"sha": sha, "size": len(part), "encoding": "base64", "content": base64.b64encode(part).decode("ascii") + "\n"}
        item = {"role": "spawn", "filename": "original.tar.gz", "bytes": len(raw),
                "sha256": hashlib.sha256(raw).hexdigest(), "assembled_git_blob": evidence.git_blob_sha(raw), "chunks": chunks}
        return raw, item, replies

    def test_original_binary_archive_reassembles_without_recompression(self):
        import publish_local_evidence as evidence
        raw, item, replies = self.specimen()
        result = evidence.assemble(item, replies.__getitem__)
        self.assertEqual(result, raw)
        self.assertGreater(len(item["chunks"]), 1)
        self.assertEqual(evidence.validate_archive(result)["content_bytes"], 512)

    def test_missing_reordered_overlapping_and_unbounded_chunks_refuse(self):
        import publish_local_evidence as evidence
        for mutate in (
            lambda item: item["chunks"].pop(),
            lambda item: item["chunks"].reverse(),
            lambda item: item["chunks"][1].update(offset=1),
            lambda item: item.update(chunks=item["chunks"]*17),
            lambda item: item["chunks"][0].update(bytes=evidence.MAX_CHUNK_BYTES+1),
        ):
            raw, item, replies = self.specimen()
            mutate(item)
            with self.assertRaises(ValueError):
                evidence.assemble(item, replies.__getitem__)

    def test_corrupt_api_size_encoding_bytes_and_canonical_git_identity_refuse(self):
        import base64
        import publish_local_evidence as evidence
        for field, value in (("size", 1), ("encoding", "utf-8"), ("content", "!invalid!"), ("sha", "0"*40)):
            raw, item, replies = self.specimen()
            replies[item["chunks"][0]["git_blob"]][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                evidence.assemble(item, replies.__getitem__)
        raw, item, replies = self.specimen()
        first = item["chunks"][0]
        replies[first["git_blob"]]["content"] = base64.b64encode(b"x"*first["bytes"]).decode("ascii")
        with self.assertRaises(ValueError):
            evidence.assemble(item, replies.__getitem__)
        raw, item, replies = self.specimen()
        old = item["chunks"][0]["git_blob"]
        item["chunks"][0]["git_blob"] = "0"*40
        replies["0"*40] = dict(replies[old], sha="0"*40)
        with self.assertRaises(ValueError):
            evidence.assemble(item, replies.__getitem__)

    def test_full_archive_sha_and_canonical_git_identity_refuse_substitution(self):
        import publish_local_evidence as evidence
        for field, value in (("sha256", "0"*64), ("assembled_git_blob", "0"*40)):
            raw, item, replies = self.specimen()
            item[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                evidence.assemble(item, replies.__getitem__)

    def test_unsafe_alias_paths_links_private_support_and_truncation_refuse(self):
        import tarfile
        import publish_local_evidence as evidence
        for entries in (
            [("../outside", b"x", None)], [("/absolute", b"x", None)], [("bad\\path", b"x", None)],
            [("C:/absolute", b"x", None)], [("same", b"x", None), ("./same", b"x", None)],
            [("link", b"", tarfile.SYMTYPE)], [(".ssh/key", b"x", None)], [("Xauthority", b"x", None)],
        ):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                evidence.validate_archive(self.archive(entries))
        with self.assertRaises(ValueError):
            evidence.validate_archive(self.archive()[:-4])

    def test_expansion_member_count_and_content_bounds_are_enforced(self):
        import gzip
        from unittest.mock import patch
        import publish_local_evidence as evidence
        raw = self.archive()
        with patch.object(evidence, "MAX_EXPANDED_BYTES", len(gzip.decompress(raw))-1), self.assertRaises(ValueError):
            evidence.validate_archive(raw)
        with patch.object(evidence, "MAX_MEMBERS", 2), self.assertRaises(ValueError):
            evidence.validate_archive(self.archive([("one", b"x", None), ("two", b"x", None)]))
        with patch.object(evidence, "MAX_CONTENT_BYTES", 512), self.assertRaises(ValueError):
            evidence.validate_archive(raw)

    def test_registered_originals_keep_their_independent_archive_identities(self):
        import json
        from pathlib import Path
        import publish_local_evidence as evidence
        record = json.loads(Path(evidence.__file__).with_name("local_evidence.json").read_bytes())
        self.assertIs(evidence.validate_record(record), record)
        self.assertEqual([(item["bytes"], item["sha256"], item["assembled_git_blob"], len(item["chunks"])) for item in record["archives"]], [
            (1261587, "3b98692ecd8e95ea83d6e1df2c2102776a74d0a8adeeccd80f41ae24bcdec951", "9025baa1e02d0a94761d9e2f3ecd1a32471250a6", 10),
            (859227, "6afbef1a2c5efde0363ced44efd534cd38be197def38f1be3a519eb42e67cdc7", "a50fbc60926ab70dcfda1f0ec848a29bde778dba", 7),
            (964518, "519a5fb08fd4d9f8aa1c55eecd37eaee605796a1ab3f74a3db966d10cd6da345", "343a18a94754155b0f220252077dcb1287e758db", 8),
        ])
        changed = copy.deepcopy(record)
        changed["archives"].reverse()
        with self.assertRaises(ValueError):
            evidence.validate_record(changed)


class InspectionSchedulingProjectionTests(unittest.TestCase):
    """Only the reviewed read-only inspector scheduling repair can join Q4."""

    def project(self, before=None, after=None, extra=()):
        from types import SimpleNamespace
        from unittest.mock import patch
        reference = "a" * 40
        path = publication.INSPECTION_WORKFLOW
        old, new = publication.INSPECTION_SCHEDULING_BLOBS
        replies = {
            ("diff", "--name-only", reference, "HEAD"): "\n".join([path, *extra]),
            ("ls-tree", reference, "--", path): before or f"100644 blob {old}\t{path}",
            ("ls-tree", "HEAD", "--", path): after or f"100644 blob {new}\t{path}",
            ("rev-parse", reference + "^{tree}"): "b" * 40,
            ("rev-parse", "HEAD"): "c" * 40,
            ("rev-parse", "HEAD^{tree}"): "d" * 40,
        }
        with patch.object(publication, "git", side_effect=lambda *args: replies[args]), \
                patch.object(publication.subprocess, "run", return_value=SimpleNamespace(returncode=0)):
            return publication.source_projection(reference)

    def test_current_inspector_is_exactly_the_single_reviewed_line_addition(self):
        import hashlib
        raw = (publication.ROOT / publication.INSPECTION_WORKFLOW).read_bytes()
        line = b"      max-parallel: 2\n"
        self.assertEqual(raw.count(line), 1)
        self.assertIn(b"    strategy:\n      fail-fast: false\n" + line + b"      matrix:\n", raw)
        original = raw.replace(line, b"", 1)

        def blob(data):
            return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()

        self.assertEqual((blob(original), blob(raw)), publication.INSPECTION_SCHEDULING_BLOBS)
        result = self.project()
        self.assertEqual(result["reviewed_inspector_scheduling_transition"]["before_blob"], blob(original))
        self.assertEqual(result["reviewed_inspector_scheduling_transition"]["after_blob"], blob(raw))
        self.assertIs(result["production_and_qualification_bytes_identical"], True)

    def test_foreign_reversed_same_blob_and_file_mode_changes_refuse(self):
        path = publication.INSPECTION_WORKFLOW
        old, new = publication.INSPECTION_SCHEDULING_BLOBS
        for before, after in (("0" * 40, new), (old, "0" * 40), (new, old), (old, old), (new, new)):
            with self.subTest(before=before, after=after), self.assertRaisesRegex(ValueError, "exact reviewed"):
                self.project(f"100644 blob {before}\t{path}", f"100644 blob {after}\t{path}")
        for mode, kind in (("100755", "blob"), ("120000", "blob"), ("040000", "tree")):
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, "exact reviewed"):
                self.project(after=f"{mode} {kind} {new}\t{path}")

    def test_exact_inspector_repair_cannot_carry_application_or_qualification_changes(self):
        for path in ("godot/scripts/main.gd", "native/src/world.cpp",
                     "tools/pubpres_mainline/run_focused.py", "tools/pubpres_mainline/qualification.py",
                     ".github/workflows/another.yml"):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "Unqualified source change"):
                self.project(extra=(path,))


class OriginalReaderPlatformTests(unittest.TestCase):
    """Exercise the real frozen native/Rapier digest boundary on either host."""

    def fixture(self, root, platform, wrong_field=None):
        import hashlib
        import json
        project, folder = root / "project", root / "observations"
        folder.mkdir(parents=True, exist_ok=True)
        (project / "tests").mkdir(parents=True, exist_ok=True)
        (project / "tests/test_workbench_member_presentation.gd").write_text(
            "# Digest-bound reader unit fixture; no native or graphical execution.\n", encoding="utf-8")
        native = {"windows": "cybersand_native.windows.x86_64.dll",
                  "linux": "libcybersand_native.linux.x86_64.so"}
        rapier = {"windows": "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
                  "linux": "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"}
        payloads = {}
        for target in ("linux", "windows"):
            for kind, names in (("cybersand_native", native), ("godot-rapier2d", rapier)):
                file = project / "addons" / kind / "bin" / names[target]
                file.parent.mkdir(parents=True, exist_ok=True)
                raw = (target + ":" + kind).encode("ascii")
                file.write_bytes(raw)
                payloads[(target, kind)] = hashlib.sha256(raw).hexdigest()
        expected = publication._original_qualification.SUPPLEMENTAL["test_workbench_member_presentation"]
        data = {"checks": expected["exact_checks"], "failures": [], "source_revision": "a" * 40,
                "schema": expected["schema"], "graphical": True, "process_id": 123,
                "native_sha256": payloads[(platform, "cybersand_native")],
                "rapier_sha256": payloads[(platform, "godot-rapier2d")],
                "observations": []}
        if wrong_field:
            data[wrong_field] = "0" * 64
        raw = json.dumps(data)
        (folder / "receipt.json").write_text(raw, encoding="utf-8")
        return ("test_workbench_member_presentation", expected["prefix"] + raw,
                folder, {"source_commit": "a" * 40}, project)

    def test_actual_platform_paths_reach_the_next_unchanged_semantic_gate(self):
        import os
        from pathlib import Path
        from tempfile import TemporaryDirectory
        previous = publication._original_qualification.os
        host_name = os.name
        for platform in ("linux", "windows"):
            with self.subTest(platform=platform), TemporaryDirectory() as where:
                args = self.fixture(Path(where), platform)
                # Passing the byte boundary is not a complete gameplay pass:
                # the deliberately absent 72 observations must still refuse.
                with self.assertRaisesRegex(ValueError, "Multipart actual owner/member/physical history inventory"):
                    publication.replay_supplemental_result(platform, *args)
                self.assertIs(publication._original_qualification.os, previous)
                self.assertEqual(os.name, host_name)

    def test_wrong_native_or_rapier_bytes_refuse_for_both_target_platforms(self):
        from pathlib import Path
        from tempfile import TemporaryDirectory
        previous = publication._original_qualification.os
        for platform in ("linux", "windows"):
            for field in ("native_sha256", "rapier_sha256"):
                with self.subTest(platform=platform, field=field), TemporaryDirectory() as where:
                    args = self.fixture(Path(where), platform, field)
                    with self.assertRaisesRegex(ValueError, "Multipart native or Rapier bytes differ"):
                        publication.replay_supplemental_result(platform, *args)
                    self.assertIs(publication._original_qualification.os, previous)

    def test_nested_and_failed_replays_restore_module_binding_without_mutating_os(self):
        import os
        from unittest.mock import patch
        previous = publication._original_qualification.os
        host_name = os.name
        observed = []

        def nested():
            observed.append(publication._original_qualification.os.name)
            self.assertEqual(os.name, host_name)
            self.assertIs(publication._original_qualification.os.environ, os.environ)
            if len(observed) == 1:
                return publication.replay_supplemental_result("linux")
            raise RuntimeError("original-reader-refusal")

        with patch.object(publication, "supplemental_result", side_effect=nested):
            with self.assertRaisesRegex(RuntimeError, "original-reader-refusal"):
                publication.replay_supplemental_result("windows")
        self.assertEqual(observed, ["nt", "posix"])
        self.assertIs(publication._original_qualification.os, previous)
        self.assertEqual(os.name, host_name)
        with self.assertRaisesRegex(ValueError, "Unregistered original artifact platform"):
            publication.replay_supplemental_result("unknown")
        self.assertIs(publication._original_qualification.os, previous)


if __name__ == "__main__":
    unittest.main()
