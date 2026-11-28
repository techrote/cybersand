"""Real Git-index adversarial fixtures for the leased eight-path publisher."""
from __future__ import annotations

import hashlib
from pathlib import Path
import tempfile
import unittest

import publish_runtime as publisher
import run_request


class PublicationIndex(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name) / "source"
        self.bundle = Path(temporary.name) / "qualified"
        self.root.mkdir()
        self.bundle.mkdir()
        self.git("init", "--quiet")
        self.git("config", "user.name", "Isolated publication fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.binaries = {*publisher.RUNTIMES.values(), *publisher.CLIS.values()}
        self.baseline = {name: ("old payload " + name + "\n").encode() for name in publisher.PATHS}
        for name, data in self.baseline.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            self.index(name, data)
        self.git("commit", "--quiet", "--no-gpg-sign", "-m", "Original runtime fixture")

    def git(self, *arguments):
        return run_request.git(self.root, *arguments)

    def index(self, name, data, mode=None):
        if name in self.binaries:
            data = ("version https://git-lfs.github.com/spec/v1\noid sha256:"
                    + hashlib.sha256(data).hexdigest() + "\nsize " + str(len(data)) + "\n").encode()
        # Write index objects directly so this fixture checks exact pointer bytes
        # independently of a machine's Git LFS filter configuration.
        import subprocess
        sha = subprocess.run(["git", "-C", str(self.root), "hash-object", "-w", "--stdin"],
                             input=data, capture_output=True, check=True).stdout.decode().strip()
        mode = mode or ("100755" if name == publisher.CLIS["linux"] else "100644")
        self.git("update-index", "--add", "--cacheinfo", mode + "," + sha + "," + name)

    def stage(self, unchanged=()):
        self.hashes = {}
        for name in publisher.PATHS:
            data = self.baseline[name] if name in unchanged else ("qualified payload " + name + "\n").encode()
            path = self.bundle / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            (self.root / name).write_bytes(data)
            self.index(name, data)
            self.hashes[name] = hashlib.sha256(data).hexdigest()

    def check(self):
        return publisher.verify_staged_payload(self.root, self.bundle, self.hashes)

    def test_all_eight_changed_paths_are_exact(self):
        self.stage()
        value = self.check()
        self.assertEqual(value["changed_paths"], publisher.PATHS)
        self.assertEqual(value["unchanged_byte_identical_paths"], [])

    def test_four_byte_identical_binaries_remain_fully_verified(self):
        self.stage(self.binaries)
        value = self.check()
        self.assertEqual(value["unchanged_byte_identical_paths"], sorted(self.binaries))
        self.assertEqual(len(value["changed_paths"]), 4)

    def test_omitted_genuinely_changed_path_is_refused(self):
        self.stage()
        name = publisher.BINDINGS["windows"]
        self.git("reset", "--quiet", "HEAD", "--", name)
        with self.assertRaisesRegex(ValueError, "Staged publication differs"):
            self.check()

    def test_unrelated_staged_source_is_refused(self):
        self.stage()
        self.index("source.cpp", b"unqualified application edit\n")
        with self.assertRaisesRegex(ValueError, "exceeds"):
            self.check()

    def test_substituted_index_pointer_is_refused(self):
        self.stage()
        self.index(publisher.CLIS["windows"], b"unqualified executable")
        with self.assertRaisesRegex(ValueError, "Staged publication differs"):
            self.check()

    def test_substituted_index_metadata_is_refused(self):
        self.stage()
        self.index(publisher.PROVENANCE["linux"], b"fabricated provenance\n")
        with self.assertRaisesRegex(ValueError, "Staged publication differs"):
            self.check()

    def test_unmaterialized_pointer_is_refused(self):
        self.stage()
        name = publisher.RUNTIMES["linux"]
        (self.root / name).write_bytes(self.git("show", ":" + name))
        with self.assertRaisesRegex(ValueError, "Materialized publication differs"):
            self.check()

    def test_bundle_tampering_is_refused_even_if_reindexed(self):
        self.stage()
        name = publisher.CLIS["linux"]
        (self.bundle / name).write_bytes(b"substitute")
        (self.root / name).write_bytes(b"substitute")
        self.index(name, b"substitute")
        with self.assertRaisesRegex(ValueError, "Materialized publication differs"):
            self.check()

    def test_executable_mode_loss_is_refused(self):
        self.stage()
        name = publisher.CLIS["linux"]
        self.index(name, (self.bundle / name).read_bytes(), mode="100644")
        with self.assertRaisesRegex(ValueError, "Git mode"):
            self.check()

    def test_empty_transaction_and_incomplete_inventory_are_refused(self):
        self.stage(publisher.PATHS)
        with self.assertRaisesRegex(ValueError, "empty"):
            self.check()
        self.stage()
        del self.hashes[publisher.PATHS[0]]
        with self.assertRaisesRegex(ValueError, "exactly eight"):
            self.check()


if __name__ == "__main__":
    unittest.main()
