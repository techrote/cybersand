"""Exact-source custody tests in isolated Git repositories; no runtime claims."""
from __future__ import annotations

import copy
from pathlib import Path
import subprocess
import tempfile
import unittest

from check_native_parity import file_fact
import proof_scopes


class CurrentSourceCustodyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353-current-source-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name in ("tools/oracle.py", "source/input.json", "docs/context.md"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture " + name + "\n")
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "isolated source context")

    def git(self, *arguments):
        return subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Proof fixture",
                               "-c", "user.email=proof-fixture@invalid.local", *arguments],
                              check=True, capture_output=True, text=True, timeout=30).stdout

    def inventories(self):
        return {"tools": [file_fact(self.root / "tools/oracle.py", self.root)],
                "inputs": [file_fact(self.root / "source/input.json", self.root)]}

    def context(self):
        return proof_scopes.checked_source(self.root, self.inventories())

    def test_bound_bytes_are_distinct_from_git_context(self):
        before = self.context()
        self.assertEqual(before["git_head"], self.git("rev-parse", "HEAD").strip())
        self.assertEqual(before["git_head_tree"], self.git("rev-parse", "HEAD^{tree}").strip())
        self.assertEqual(before["listed_worktree_changes"], [])
        (self.root / "source/input.json").write_text("changed byte source\n")
        after = self.context()
        self.assertEqual(before["git_head"], after["git_head"])
        self.assertNotEqual(before["inventories_sha256"], after["inventories_sha256"])
        self.assertEqual(after["listed_worktree_changes"], [" M source/input.json"])

    def test_unrelated_work_does_not_change_a_scoped_byte_fingerprint(self):
        before = self.context()
        (self.root / "docs/context.md").write_text("unrelated narrative changed\n")
        self.assertEqual(before, self.context())

    def test_new_untracked_input_is_reported_and_hashed(self):
        additional = self.root / "source/new.json"
        additional.write_text("new input\n")
        rows = self.inventories()
        rows["inputs"].append(file_fact(additional, self.root))
        result = proof_scopes.checked_source(self.root, rows)
        self.assertEqual(result["listed_worktree_changes"], ["?? source/new.json"])
        self.assertNotEqual(result["inventories_sha256"], self.context()["inventories_sha256"])
        rows = dict(reversed(list(rows.items())))
        rows["inputs"].reverse()
        self.assertEqual(result, proof_scopes.checked_source(self.root, rows))

    def test_malformed_and_ambiguous_inventories_fail_closed(self):
        for malformed in ({}, {"inputs": []}, {1: self.inventories()["inputs"]}):
            with self.subTest(inventory=malformed), self.assertRaises(proof_scopes.ProofScopeError):
                proof_scopes.checked_source(self.root, malformed)
        for field, value in (("path", "source/../input.json"), ("path", "source/./input.json"),
                             ("path", ""), ("bytes", True), ("bytes", -1),
                             ("sha256", "0" * 63), ("sha256", 9)):
            with self.subTest(field=field, value=value):
                rows = copy.deepcopy(self.inventories())
                rows["inputs"][0][field] = value
                with self.assertRaises(proof_scopes.ProofScopeError):
                    proof_scopes.checked_source(self.root, rows)
        rows = self.inventories()
        rows["inputs"].append(copy.deepcopy(rows["inputs"][0]))
        with self.assertRaisesRegex(proof_scopes.ProofScopeError, "duplicate source fact"):
            proof_scopes.checked_source(self.root, rows)

    def test_missing_git_or_nonroot_checkout_does_not_receive_context(self):
        with self.assertRaisesRegex(proof_scopes.ProofScopeError, "selected repository root"):
            proof_scopes.checked_source(self.root / "source", self.inventories())
        with tempfile.TemporaryDirectory(prefix="mat353-no-git-") as directory:
            with self.assertRaisesRegex(proof_scopes.ProofScopeError, "cannot identify checked source"):
                proof_scopes.checked_source(Path(directory), self.inventories())


if __name__ == "__main__":
    unittest.main()
