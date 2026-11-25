"""Real temporary Git/LFS repositories and immutable ZIPs exercise custody refusals.

These payloads are explicitly synthetic verifier fixtures, not runtime evidence.
No hosted execution, remote network, credentials or existing checkout is used.
"""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import publication_custody as gate


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def call(root, *args, data=None):
    return subprocess.run(["git", "-C", str(root), *args], input=data, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30).stdout


class Fixture:
    def __init__(self, flags=(True, True)):
        self.temp = tempfile.TemporaryDirectory(prefix="publication-custody-test-")
        self.base = Path(self.temp.name)
        self.root = self.base / "repo"
        self.root.mkdir()
        self.artifacts = self.base / "artifacts"
        self.artifacts.mkdir()
        self.remote = self.base / "remote.git"
        call(self.root, "init", "-b", "candidate")
        call(self.root, "config", "user.name", "Custody test")
        call(self.root, "config", "user.email", "custody@example.invalid")
        call(self.root, "config", "commit.gpgsign", "false")
        call(self.root, "lfs", "install", "--local")
        self.write(".gitattributes", b"bin/* filter=lfs diff=lfs merge=lfs -text\n")
        self.write("native/source.cpp", b"// synthetic custody fixture, never compiled\n")
        self.write("third_party/dependency.json", b'{"synthetic":true}\n')
        self.write("tools/qualification.py", b"# synthetic test selector\n")
        self.payloads = {p: prefix + b"-synthetic-custody-test-" + p.encode()
                         for p, prefix in gate.PLATFORMS.items()}
        self.binary_paths = {"linux": "bin/native.so", "windows": "bin/native.dll"}
        self.provenance_paths = {p: "provenance/" + p + ".json" for p in gate.PLATFORMS}
        for (platform, payload), changed in zip(self.payloads.items(), flags):
            self.write(self.binary_paths[platform], payload + b"-old" if changed else payload)
            self.write(self.provenance_paths[platform], b'{"old":true}\n')
        call(self.root, "add", ".")
        call(self.root, "commit", "-m", "synthetic tested parent")
        self.source = call(self.root, "rev-parse", "HEAD").decode().strip()
        self.tree = call(self.root, "rev-parse", "HEAD^{tree}").decode().strip()
        call(self.base, "clone", "--bare", str(self.root), str(self.remote))
        call(self.root, "remote", "add", "origin", str(self.remote))
        self.contract = {"schema_version": 1, "kind": "publication-custody-v1",
                         "source_commit": self.source, "source_tree": self.tree,
                         "branch": "candidate", "run_id": "12345", "attempt": "2",
                         "slots": {}, "artifacts": {}, "reports": []}
        self.records = {}
        for platform, payload in self.payloads.items():
            binary, provenance = self.binary_paths[platform], self.provenance_paths[platform]
            source_inputs = {"native/source.cpp": gate.digest((self.root / "native/source.cpp").read_bytes())}
            build_inputs = {name: gate.digest((self.root / name).read_bytes())
                            for name in ("third_party/dependency.json", "tools/qualification.py")}
            slot = {"binary_path": binary, "provenance_path": provenance,
                    "sha256": gate.digest(payload), "size": len(payload),
                    "source_inputs": source_inputs, "build_inputs": build_inputs,
                    "toolchain": "Synthetic fixture compiler identity, not executed",
                    "dependencies": {"godot_version": "synthetic-engine-pin", "godot_cpp_commit": "a" * 40}}
            p = {"artifact": binary, "sha256": slot["sha256"], "size": slot["size"],
                 "source_commit": self.source, "source_tree": self.tree, "build_commit": self.source,
                 "publication_branch": "candidate", "workflow_run": "12345", "workflow_attempt": "2",
                 "platform": platform + " x86_64", "status": "evaluation-candidate-passed",
                 "source_input_hash_kind": "sha256-canonical-lf",
                 "source_inputs": source_inputs, "build_inputs": build_inputs,
                 "toolchain": slot["toolchain"], **slot["dependencies"],
                 "qualification": {"status": "passed"}}
            if platform == "windows":
                p["installed_package_qualification"] = {"status": "passed"}
            data = json_bytes(p)
            slot["provenance_sha256"] = gate.digest(data)
            self.contract["slots"][platform] = slot
            self.write(binary, payload)
            self.write(provenance, data)
            records = {}
            roles = [platform] + (["installed-windows"] if platform == "windows" else [])
            for role in roles:
                spec = {"role": role, "platform": platform, "artifact": platform,
                        "member": role + "/qualification.json", "cases": {}}
                results = []
                for case, display in (("import", False), ("actual-graphical-case", True)):
                    command = ["synthetic-godot", "--path", "synthetic", "--case", case]
                    if not display:
                        command.append("--headless")
                    spec["cases"][case] = {"command": command, "requires_display": display}
                    log = ("SYNTHETIC fixture " + role + " " + case + "\n").encode()
                    records[role + "/" + case + ".log"] = log
                    results.append({"name": case, "role": "case", "command": command,
                                    "requires_display": display, "status": "passed", "returncode": 0,
                                    "natural_completion": True, "pid": 1234, "skip_messages": [],
                                    "launch_error": None, "capture_error": None, "diagnostic_error": False,
                                    "timeout_kind": None, "timeout_diagnostic_error": None,
                                    "log": case + ".log", "log_sha256": gate.digest(log)})
                candidate = {key: slot[key] for key in ("sha256", "size", "source_inputs", "build_inputs", "toolchain")}
                candidate.update(source_commit=self.source, source_tree=self.tree, artifact=binary)
                report = {"status": "passed", "completed": True, "executed_cases": len(results),
                          "platform": platform, "candidate": candidate, "results": results,
                          "installed_package": None}
                if role == "installed-windows":
                    report["installed_package"] = {"source_commit": self.source, "source_tree": self.tree,
                                                   "native_sha256": slot["sha256"]}
                records[spec["member"]] = json_bytes(report)
                spec["sha256"] = gate.digest(records[spec["member"]])
                if role == "installed-windows":
                    p["installed_package_qualification"]["gameplay_report_sha256"] = spec["sha256"]
                else:
                    p["qualification"]["report_sha256"] = spec["sha256"]
                self.contract["reports"].append(spec)
            data = json_bytes(p)
            slot["provenance_sha256"] = gate.digest(data)
            self.write(provenance, data)
            self.records[platform] = records
            self.repack(platform)
        call(self.root, "add", "bin", "provenance")

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def repack(self, platform):
        path = self.artifacts / (platform + ".zip")
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, data in self.records[platform].items():
                archive.writestr(name, data)
        sha, size = gate.file_identity(path)
        self.contract["artifacts"][platform] = {
            "path": path.name, "sha256": sha, "size": size, "run_id": "12345", "attempt": "2",
            "source_commit": self.source, "source_tree": self.tree, "branch": "candidate",
            "producer_conclusion": "success", "artifact_id": "100" if platform == "linux" else "200",
            "job_id": "101" if platform == "linux" else "201"}

    def mutate_report(self, role, fn, *, repin=True):
        platform = "linux" if role == "linux" else "windows"
        member = role + "/qualification.json"
        value = json.loads(self.records[platform][member])
        fn(value)
        self.records[platform][member] = json_bytes(value)
        if repin:
            spec = next(s for s in self.contract["reports"] if s["role"] == role)
            spec["sha256"] = gate.digest(self.records[platform][member])
            key = "installed_package_qualification" if role == "installed-windows" else "qualification"
            field = "gameplay_report_sha256" if role == "installed-windows" else "report_sha256"
            self.mutate_provenance(platform, lambda p: p[key].update({field: spec["sha256"]}))
        previous = copy.deepcopy(self.contract["artifacts"][platform])
        self.repack(platform)
        if not repin:
            self.contract["artifacts"][platform] = previous

    def mutate_provenance(self, platform, fn, *, repin=True):
        path = self.provenance_paths[platform]
        value = json.loads((self.root / path).read_bytes())
        fn(value)
        data = json_bytes(value)
        self.write(path, data)
        call(self.root, "add", path)
        if repin:
            self.contract["slots"][platform]["provenance_sha256"] = gate.digest(data)

    def move_remote(self):
        new = call(self.root, "commit-tree", self.tree, "-p", self.source,
                   data=b"synthetic branch movement\n").decode().strip()
        call(self.root, "push", "--no-verify", "origin", new + ":refs/heads/candidate")
        return new

    def verify(self, **kwargs):
        return gate.verify(self.root, self.contract, self.artifacts, **kwargs)

    def close(self):
        self.temp.cleanup()


class PublicationCustodyTests(unittest.TestCase):
    def setUp(self):
        self.fixture = Fixture()
        self.addCleanup(self.fixture.close)

    def test_all_four_actual_binary_change_combinations(self):
        for flags in ((False, False), (True, False), (False, True), (True, True)):
            with self.subTest(flags=flags):
                f = Fixture(flags)
                try:
                    before = call(f.root, "status", "--porcelain=v1")
                    result = f.verify()
                    self.assertEqual(result["status"], "custody-verified")
                    self.assertEqual([result["runtimes"][p]["pointer_changed"] for p in gate.PLATFORMS], list(flags))
                    self.assertFalse(result["publication_authorized"])
                    self.assertFalse(result["remote_lfs_storage_verified"])
                    self.assertFalse(result["qualification_semantics_verified"])
                    self.assertEqual(before, call(f.root, "status", "--porcelain=v1"))
                finally:
                    f.close()

    def test_rogue_staged_source_is_rejected(self):
        self.fixture.write("native/rogue.cpp", b"unqualified")
        call(self.fixture.root, "add", "native/rogue.cpp")
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_missing_changed_provenance_is_rejected(self):
        call(self.fixture.root, "restore", "--source=HEAD", "--staged", "--worktree", "provenance/linux.json")
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_actual_pointer_cannot_substitute_for_library(self):
        name = self.fixture.binary_paths["linux"]
        pointer = call(self.fixture.root, "show", ":" + name)
        self.fixture.write(name, pointer)
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_altered_binary_bytes_are_rejected(self):
        self.fixture.write("bin/native.dll", self.fixture.payloads["windows"] + b"tampered")
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_wrong_staged_pointer_is_rejected(self):
        self.fixture.write("bin/native.dll", b"MZ-substituted-payload")
        call(self.fixture.root, "add", "bin/native.dll")
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_missing_local_lfs_object_is_rejected_even_with_matching_worktree(self):
        slot = self.fixture.contract["slots"]["linux"]
        oid = slot["sha256"]
        path = gate.lfs_storage(self.fixture.root) / oid[:2] / oid[2:4] / oid
        path.unlink()
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_corrupt_local_lfs_object_is_rejected(self):
        oid = self.fixture.contract["slots"]["linux"]["sha256"]
        path = gate.lfs_storage(self.fixture.root) / oid[:2] / oid[2:4] / oid
        path.write_bytes(b"corrupt")
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_stale_source_tree_run_attempt_or_branch_provenance_is_rejected(self):
        for key in ("source_commit", "build_commit", "source_tree", "workflow_run", "workflow_attempt", "publication_branch"):
            with self.subTest(key=key):
                f = Fixture()
                try:
                    f.mutate_provenance("linux", lambda p: p.update({key: "9" * 40}))
                    with self.assertRaises(gate.Rejected):
                        f.verify()
                finally:
                    f.close()

    def test_forged_self_consistent_provenance_rejected_by_external_pin(self):
        self.fixture.mutate_provenance("linux", lambda p: p.update(untrusted_extra="forged"), repin=False)
        with self.assertRaisesRegex(gate.Rejected, "independent custody pin"):
            self.fixture.verify()

    def test_compiler_identity_is_required(self):
        self.fixture.mutate_provenance("windows", lambda p: p.update(toolchain="different compiler"))
        with self.assertRaisesRegex(gate.Rejected, "Compiler"):
            self.fixture.verify()

    def test_dependency_identity_is_required(self):
        self.fixture.mutate_provenance("windows", lambda p: p.update(godot_cpp_commit="b" * 40))
        with self.assertRaisesRegex(gate.Rejected, "Dependency"):
            self.fixture.verify()

    def test_wrong_source_input_hash_is_rejected(self):
        slot = self.fixture.contract["slots"]["linux"]
        slot["source_inputs"]["native/source.cpp"] = "b" * 64
        self.fixture.mutate_provenance("linux", lambda p: p.update(source_inputs=slot["source_inputs"]))
        with self.assertRaisesRegex(gate.Rejected, "Committed input"):
            self.fixture.verify()

    def test_missing_input_ledger_is_rejected(self):
        self.fixture.contract["slots"]["linux"]["build_inputs"] = {}
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_branch_moved_before_check_is_rejected(self):
        self.fixture.move_remote()
        with self.assertRaisesRegex(gate.Rejected, "Remote branch moved"):
            self.fixture.verify()

    def test_real_branch_movement_during_check_is_rejected(self):
        original = gate.remote_lease
        first = True
        def lease(root, remote, branch):
            nonlocal first
            value = original(root, remote, branch)
            if first:
                first = False
                self.fixture.move_remote()
            return value
        with mock.patch.object(gate, "remote_lease", side_effect=lease):
            with self.assertRaisesRegex(gate.Rejected, "during custody"):
                self.fixture.verify()

    def test_wrong_local_branch_is_rejected(self):
        call(self.fixture.root, "branch", "-m", "wrong-branch")
        with self.assertRaisesRegex(gate.Rejected, "Wrong publication branch"):
            self.fixture.verify()

    def test_same_sha_local_branch_switch_during_check_is_rejected(self):
        original = gate.verify_report
        changed = False
        def inspect(*args, **kwargs):
            nonlocal changed
            result = original(*args, **kwargs)
            if not changed:
                changed = True
                call(self.fixture.root, "switch", "-c", "other-local-branch")
            return result
        with mock.patch.object(gate, "verify_report", side_effect=inspect):
            with self.assertRaisesRegex(gate.Rejected, "Local branch moved"):
                self.fixture.verify()

    def test_unstaged_source_change_is_rejected(self):
        self.fixture.write("native/source.cpp", b"unqualified dirty source")
        with self.assertRaisesRegex(gate.Rejected, "Unstaged"):
            self.fixture.verify()

    def test_actual_index_rogue_path_or_pointer_movement_during_check_is_rejected(self):
        for path, payload in (("native/rogue.cpp", b"new unqualified source"),
                              ("bin/native.dll", b"MZ-new unqualified runtime")):
            with self.subTest(path=path):
                f = Fixture()
                original = gate.verify_report
                changed = False
                def inspect(*args, **kwargs):
                    nonlocal changed
                    result = original(*args, **kwargs)
                    if not changed:
                        changed = True
                        f.write(path, payload)
                        call(f.root, "add", path)
                    return result
                try:
                    with mock.patch.object(gate, "verify_report", side_effect=inspect):
                        with self.assertRaisesRegex(gate.Rejected, "Index moved"):
                            f.verify()
                finally:
                    f.close()

    def test_missing_evidence_archive_is_rejected(self):
        (self.fixture.artifacts / "windows.zip").unlink()
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_altered_receipt_refused_even_when_internal_hashes_agree(self):
        self.fixture.mutate_report("windows", lambda r: r.update(extra="forged"), repin=False)
        with self.assertRaisesRegex(gate.Rejected, "independent API/acquisition pin"):
            self.fixture.verify()

    def test_artifact_wrong_run_attempt_source_and_failed_producer_are_rejected(self):
        for key in ("run_id", "attempt", "source_commit", "source_tree", "branch", "producer_conclusion"):
            with self.subTest(key=key):
                original = self.fixture.contract["artifacts"]["linux"][key]
                self.fixture.contract["artifacts"]["linux"][key] = "wrong"
                with self.assertRaises(gate.Rejected):
                    self.fixture.verify()
                self.fixture.contract["artifacts"]["linux"][key] = original

    def test_missing_mandatory_report_is_rejected(self):
        self.fixture.contract["reports"].pop()
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_malformed_report_specification_is_cleanly_rejected(self):
        self.fixture.contract["reports"][0] = None
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_missing_duplicate_or_wrong_case_is_rejected(self):
        for action in (lambda r: r["results"].pop(),
                       lambda r: r["results"][1].update(name="import"),
                       lambda r: r["results"][1].update(name="unrelated-case")):
            f = Fixture()
            try:
                f.mutate_report("linux", action)
                with self.assertRaises(gate.Rejected):
                    f.verify()
            finally:
                f.close()

    def test_process_failure_skip_timeout_wrong_display_and_command_are_rejected(self):
        changes = ({"returncode": 1}, {"returncode": False}, {"natural_completion": False},
                   {"skip_messages": ["skipped"]}, {"status": "diagnostic-only"}, {"pid": 0},
                   {"timeout_kind": "watchdog"}, {"requires_display": False},
                   {"command": ["synthetic-godot", "--headless"]})
        for change in changes:
            with self.subTest(change=change):
                f = Fixture()
                try:
                    f.mutate_report("windows", lambda r: r["results"][1].update(change))
                    with self.assertRaises(gate.Rejected):
                        f.verify()
                finally:
                    f.close()

    def test_report_wrong_source_is_rejected(self):
        self.fixture.mutate_report("linux", lambda r: r["candidate"].update(source_commit="c" * 40))
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_altered_original_log_is_rejected(self):
        self.fixture.records["linux"]["linux/actual-graphical-case.log"] += b"tamper"
        self.fixture.repack("linux")
        with self.assertRaisesRegex(gate.Rejected, "Report/log"):
            self.fixture.verify()

    def test_missing_original_log_is_rejected(self):
        del self.fixture.records["linux"]["linux/actual-graphical-case.log"]
        self.fixture.repack("linux")
        with self.assertRaisesRegex(gate.Rejected, "Missing original"):
            self.fixture.verify()

    def test_missing_installed_package_identity_is_rejected(self):
        self.fixture.mutate_report("installed-windows", lambda r: r.update(installed_package=None))
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_provenance_must_reference_actual_qualified_report(self):
        self.fixture.mutate_provenance("linux", lambda p: p["qualification"].update(report_sha256="f" * 64))
        with self.assertRaisesRegex(gate.Rejected, "reference the verified report"):
            self.fixture.verify()

    def test_report_member_pin_is_separate_from_whole_artifact_pin(self):
        self.fixture.contract["reports"][0]["sha256"] = "f" * 64
        with self.assertRaisesRegex(gate.Rejected, "independent member pin"):
            self.fixture.verify()

    def test_archive_expansion_and_member_budgets_are_enforced_before_read(self):
        path = self.fixture.artifacts / "linux.zip"
        spec = self.fixture.contract["artifacts"]["linux"]
        for name in ("MAX_ARCHIVE_BYTES", "MAX_MEMBER_BYTES", "MAX_EXPANDED_BYTES", "MAX_ARCHIVE_MEMBERS"):
            with self.subTest(budget=name), mock.patch.object(gate, name, 1):
                with self.assertRaises(gate.Rejected):
                    gate.archive_members(path, spec)

    def test_archive_path_swap_after_capture_cannot_substitute_decoded_bytes(self):
        path = self.fixture.artifacts / "linux.zip"
        replacement = self.fixture.artifacts / "replacement.zip"
        expected = self.fixture.contract["artifacts"]["linux"]
        original = gate.zipfile.ZipFile
        with original(replacement, "w") as archive:
            for name, data in self.fixture.records["linux"].items():
                archive.writestr(name, data)
            archive.writestr("substituted-unpinned-member.txt", b"substituted ZIP")
        swapped = False
        def inspect(*args, **kwargs):
            nonlocal swapped
            if not swapped:
                replacement.replace(path)
                swapped = True
            return original(*args, **kwargs)
        with mock.patch.object(gate.zipfile, "ZipFile", side_effect=inspect):
            records = gate.archive_members(path, expected)
        self.assertTrue(swapped)
        self.assertNotEqual(gate.file_identity(path), (expected["sha256"], expected["size"]))
        self.assertEqual(records, self.fixture.records["linux"])

    def test_path_traversal_and_symlinks_are_rejected(self):
        for name in ("../escape", "/absolute", "C:\\Windows", "a/./b", "a//b", "a\nb"):
            with self.subTest(name=name):
                with self.assertRaises(gate.Rejected):
                    gate.relative(name)
        path = self.fixture.artifacts / "link.zip"
        path.symlink_to(self.fixture.artifacts / "linux.zip")
        self.fixture.contract["artifacts"]["linux"]["path"] = "link.zip"
        with self.assertRaises(gate.Rejected):
            self.fixture.verify()

    def test_contract_pin_and_duplicate_json_keys_are_rejected(self):
        path = self.fixture.base / "contract.json"
        data = json_bytes(self.fixture.contract)
        path.write_bytes(data)
        self.assertEqual(gate.load_contract(path, gate.digest(data)), self.fixture.contract)
        path.write_bytes(data + b" ")
        with self.assertRaises(gate.Rejected):
            gate.load_contract(path, gate.digest(data))
        with self.assertRaises(gate.Rejected):
            gate.strict_json(b'{"status":"failed","status":"passed"}')

    def test_immutable_replay_requires_exact_single_publication_child(self):
        f = self.fixture
        call(f.root, "commit", "-m", "synthetic publication child")
        child = call(f.root, "rev-parse", "HEAD").decode().strip()
        result = f.verify(child=child)
        self.assertEqual(result["mode"], "immutable-replay")
        self.assertFalse(result["publication_authorized"])
        call(f.root, "commit", "--allow-empty", "-m", "unrelated later source")
        later = call(f.root, "rev-parse", "HEAD").decode().strip()
        with self.assertRaisesRegex(gate.Rejected, "one child"):
            f.verify(child=later)

    def test_merge_publication_child_is_rejected(self):
        f = self.fixture
        other = call(f.root, "commit-tree", f.tree, "-p", f.source, data=b"other\n").decode().strip()
        merged = call(f.root, "commit-tree", f.tree, "-p", f.source, "-p", other,
                      data=b"bad merge publication\n").decode().strip()
        with self.assertRaisesRegex(gate.Rejected, "one child"):
            f.verify(child=merged)


if __name__ == "__main__":
    unittest.main()
