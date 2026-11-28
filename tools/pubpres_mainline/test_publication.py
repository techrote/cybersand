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


if __name__ == "__main__":
    unittest.main()
