"""Unit proof for all binary-pointer publication combinations and refusal paths."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_actor_publication_stage as gate

SOURCE = "a" * 40
TREE = "b" * 40
BRANCH = "integration/actor-compose-final-001-20261123"
RUN = "12345"
ATTEMPT = "1"


class ActorStageGate(unittest.TestCase):
    def setUp(self):
        self.changed = set(gate.PROVENANCE.values())
        self.staged = {}
        self.runtimes = {}
        for platform, binary in gate.BINARIES.items():
            payload = (b"MZ" if platform == "windows" else b"\x7fELF") + platform.encode() + b"-fresh-actor"
            digest = hashlib.sha256(payload).hexdigest()
            self.runtimes[binary] = payload
            self.staged[binary] = ("version https://git-lfs.github.com/spec/v1\n"
                                   "oid sha256:" + digest + "\nsize " + str(len(payload)) + "\n").encode()
            record = {
                "artifact": binary, "sha256": digest, "size": len(payload),
                "source_commit": SOURCE, "build_commit": SOURCE, "source_tree": TREE,
                "publication_branch": BRANCH, "workflow_run": RUN, "workflow_attempt": ATTEMPT,
                "status": "evaluation-candidate-passed", "source_inputs": {"native/src/world.cpp": "hash"},
                "build_inputs": {"godot/project.godot": "hash"}, "qualification": {"status": "passed"},
                "installed_package_qualification": {"status": "passed"} if platform == "windows" else None,
            }
            self.staged[gate.PROVENANCE[platform]] = json.dumps(record).encode()

    def verify(self):
        return gate.verify(self.changed, self.staged, self.runtimes,
                           source=SOURCE, source_tree=TREE, branch=BRANCH, run_id=RUN, attempt=ATTEMPT)

    def test_application_only_reuse_requires_both_live_files_and_exact_maps(self):
        changes = [b"godot/scripts/shared_workbench.gd\n"]
        branch = [BRANCH]

        def git(*args):
            if args[0] == "branch":
                return branch[0].encode()
            if args[0] == "diff":
                return changes[0]
            if args[0] == "rev-parse":
                return TREE.encode()
            return self.staged[args[1].removeprefix("HEAD:")]

        inputs = {"native/src/world.cpp": "hash"}
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name, payload in self.runtimes.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_bytes(payload)
            with patch.object(Path, "cwd", return_value=root), patch.object(gate, "git", side_effect=git), \
                    patch("native_candidate_identity.source", return_value=("e"*40, TREE, inputs)):
                self.assertTrue(gate.reusable_pair())
                branch[0] = "main"
                self.assertFalse(gate.reusable_pair())
                branch[0] = gate.SWARM_BRANCH
                self.assertFalse(gate.reusable_pair())
                with patch.dict(self.staged):
                    for name in gate.PROVENANCE.values():
                        record = json.loads(self.staged[name])
                        record["publication_branch"] = gate.SWARM_BRANCH
                        record["qualification"]["reciprocal_execution_sha256"] = "a" * 64
                        self.staged[name] = json.dumps(record).encode()
                    self.assertTrue(gate.reusable_pair())
                    name = gate.PROVENANCE["windows"]
                    record = json.loads(self.staged[name])
                    del record["qualification"]["reciprocal_execution_sha256"]
                    self.staged[name] = json.dumps(record).encode()
                    self.assertFalse(gate.reusable_pair())
                branch[0] = BRANCH
                workflow = ".github/workflows/gdextension.yml"
                changes[0] = (workflow + "\n").encode()
                with patch.dict(self.staged):
                    old = ("    branches: [main, codex/wb-art-paint-integrated-20261111, "
                           + gate.SWARM_BRANCH + "]\n").encode()
                    self.staged[SOURCE + ":" + workflow] = old
                    key = "e" * 40 + ":" + workflow
                    self.staged[key] = old.replace((", " + gate.SWARM_BRANCH).encode(), b"")
                    self.assertTrue(gate.reusable_pair())
                    self.staged[key] += b"  native: changed\n"
                    self.assertFalse(gate.reusable_pair())
                changes[0] = b"tools/build_native_extension_windows.sh\n"
                self.assertFalse(gate.reusable_pair())
                changes[0] = b"godot/scripts/shared_workbench.gd\n"
                name = gate.PROVENANCE["linux"]
                original = self.staged[name]
                record = json.loads(original)
                record["source_inputs"] = {**inputs, "native/src/extra.cpp": "hash"}
                self.staged[name] = json.dumps(record).encode()
                self.assertFalse(gate.reusable_pair())
                self.staged[name] = original
                (root / gate.BINARIES["windows"]).write_bytes(b"MZcorrupt")
                self.assertFalse(gate.reusable_pair())

    def check_reject(self, method):
        with self.assertRaises(gate.PublicationRejected):
            method()

    def test_both_one_or_neither_binary_changed(self):
        for flags in ((False, False), (True, False), (False, True), (True, True)):
            with self.subTest(flags=flags):
                self.changed = set(gate.PROVENANCE.values())
                self.changed.update(path for enable, path in zip(flags, gate.BINARIES.values()) if enable)
                result = self.verify()
                self.assertEqual([result[p]["pointer_changed"] for p in gate.BINARIES], list(flags))

    def test_mandatory_provenance_and_rogue_paths(self):
        self.changed.remove(gate.PROVENANCE["linux"])
        self.check_reject(self.verify)
        self.changed.add(gate.PROVENANCE["linux"])
        self.changed.add("native/src/rogue.cpp")
        self.check_reject(self.verify)

    def test_pointer_substitution(self):
        name = gate.BINARIES["windows"]
        self.staged[name] = self.staged[name].replace(b"oid sha256:", b"oid sha256:" + b"0")
        self.check_reject(self.verify)

    def test_wrong_lfs_size(self):
        name = gate.BINARIES["linux"]
        self.staged[name] = self.staged[name].replace(
            str(len(self.runtimes[name])).encode() + b"\n", b"98765\n")
        self.check_reject(self.verify)

    def test_tampered_candidate(self):
        name = gate.BINARIES["windows"]
        self.runtimes[name] = self.runtimes[name] + b"INJECT"
        self.check_reject(self.verify)

    def test_stale_candidate_provenance(self):
        name = gate.PROVENANCE["windows"]
        p = json.loads(self.staged[name])
        p["sha256"] = "f" * 64
        self.staged[name] = json.dumps(p).encode()
        self.check_reject(self.verify)

    def test_stale_source_and_parent_tree(self):
        for attr in ("source_commit", "source_tree", "build_commit"):
            name = gate.PROVENANCE["linux"]
            original = self.staged[name]
            p = json.loads(original)
            p[attr] = "c" * 40
            self.staged[name] = json.dumps(p).encode()
            self.check_reject(self.verify)
            self.staged[name] = original

    def test_stale_run_attempt_and_branch(self):
        for attr in ("workflow_run", "workflow_attempt", "publication_branch"):
            name = gate.PROVENANCE["windows"]
            original = self.staged[name]
            p = json.loads(original)
            p[attr] = "unexpected"
            self.staged[name] = json.dumps(p).encode()
            self.check_reject(self.verify)
            self.staged[name] = original

    def test_missing_qualification_or_installed_package(self):
        for attr in ("qualification", "installed_package_qualification"):
            name = gate.PROVENANCE["windows"]
            original = self.staged[name]
            p = json.loads(original)
            p[attr] = None
            self.staged[name] = json.dumps(p).encode()
            self.check_reject(self.verify)
            self.staged[name] = original

    def test_missing_build_inputs_and_nonpointer(self):
        name = gate.PROVENANCE["linux"]
        p = json.loads(self.staged[name])
        p["build_inputs"] = {}
        self.staged[name] = json.dumps(p).encode()
        self.check_reject(self.verify)
        p["build_inputs"] = {"actual": "hash"}
        self.staged[name] = json.dumps(p).encode()
        self.staged[gate.BINARIES["linux"]] = b"ELF, not Git LFS metadata"
        self.check_reject(self.verify)


if __name__ == "__main__":
    unittest.main()
