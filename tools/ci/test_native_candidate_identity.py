"""Adversarial source-built candidate identity controls."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import native_candidate_identity as subject


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        def git(*args):
            subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)
        git("init", "--quiet")
        self.input = self.root / "native/src/example.cpp"
        self.input.parent.mkdir(parents=True)
        self.input.write_bytes(b"// native source\n")
        git("add", ".")
        git("-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture")
        self.directory = self.root / "candidate"
        self.directory.mkdir()
        self.binary = self.directory / Path(subject.NATIVE).name
        self.binary.write_bytes(b"MZ" + b"candidate-fixture" * 100)
        self.expected = subject.create(self.root, self.directory)

    def test_exact_candidate_passes(self):
        self.assertEqual(subject.verify(self.root, self.directory), self.expected)

    def test_changed_runtime_refuses(self):
        self.binary.write_bytes(b"MZchanged")
        with self.assertRaises(ValueError): subject.verify(self.root, self.directory)

    def test_stale_source_or_manifest_refuses(self):
        for key in ("source_commit", "build_commit", "source_tree", "sha256", "source_inputs"):
            with self.subTest(key=key):
                bad = dict(self.expected)
                bad[key] = {} if key=="source_inputs" else "0"*40
                (self.directory / subject.NAME).write_text(json.dumps(bad))
                with self.assertRaises(ValueError): subject.verify(self.root, self.directory)

    def test_dirty_native_source_refuses(self):
        self.input.write_bytes(b"// changed native source\n")
        with self.assertRaises(subprocess.CalledProcessError): subject.verify(self.root, self.directory)


if __name__ == "__main__": unittest.main()
