#!/usr/bin/env python3
"""Adapter custody/refusal controls; synthetic reports are not Windows proof."""
import copy
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest import mock

import qualify_goblin001_storage as adapter

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_UIDS = ("godot/scripts/workbench_file_transaction.gd.uid",
                "godot/tests/goblin_storage_fault_child.gd.uid",
                "godot/tests/test_workbench_file_transaction.gd.uid",
                "godot/shaders/example.gdshader.uid",
                "godot/examples/example.gd.uid")


class StorageAdapter(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="goblin001-adapter-")
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def requested(self):
        return {"schema": adapter.SCHEMA, "status": "admitted", "repository": "techrote/cybersand",
                "accepted_base": adapter.ACCEPTED_BASE, "source_commit": "1" * 40, "source_tree": "2" * 40,
                "case_inventory": ["windows_os_faults", "native_file_transaction", "goblin001_controller", "ordinary_default_off"],
                "owner_playfeel_accepted": False, "public_release": False}

    def test_request_requires_exact_source_and_complete_scope(self):
        path = self.root / "request.json"
        adapter.write(path, self.requested())
        self.assertEqual(adapter.request(path), self.requested())
        for key, value in (("status", "prepared"), ("source_commit", "main"), ("source_tree", "0" * 40),
                           ("accepted_base", "3" * 40), ("case_inventory", ["windows_os_faults"]),
                           ("public_release", True), ("owner_playfeel_accepted", True)):
            changed = self.requested()
            changed[key] = value
            adapter.write(path, changed)
            with self.subTest(key=key), self.assertRaises(ValueError):
                adapter.request(path)

    def test_duplicate_request_keys_are_refused(self):
        path = self.root / "request.json"
        path.write_text('{"status":"prepared","status":"admitted"}')
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            adapter.request(path)

    def test_required_product_inputs_cannot_be_silently_omitted(self):
        with self.assertRaisesRegex(ValueError, "Missing required source input"):
            adapter.source_inputs(self.root)

    def test_generated_metadata_is_bound_to_finite_committed_owner_paths(self):
        root = self.root / "synthetic-source"
        root.mkdir()
        subprocess.run(["git", "init", str(root)], check=True, capture_output=True)
        adapter.git(root, "config", "core.autocrlf", "false")
        for name in FIXTURE_UIDS:
            path = root / name.removesuffix(".uid")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("extends RefCounted\n")
        adapter.git(root, "add", ".")
        subprocess.run(["git", "-C", str(root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "-qm", "Synthetic UID owners"], check=True, capture_output=True)
        for name in FIXTURE_UIDS:
            (root / name).write_text("uid://fixture123\n")
        retained = adapter.retain_generated_uids(root, self.root / "retained-uids")
        self.assertEqual(set(retained), set(FIXTURE_UIDS))
        self.assertFalse(adapter.git(root, "status", "--porcelain"))
        (root / "unrelated.gd").write_text("Unexpected source\n")
        with self.assertRaisesRegex(ValueError, "Unexpected product change"):
            adapter.retain_generated_uids(root, self.root / "second-retention")
        self.assertTrue((root / "unrelated.gd").is_file())
        self.assertIn("?? unrelated.gd", (self.root / "second-retention/git-status.txt").read_text())
        source = root / FIXTURE_UIDS[0].removesuffix(".uid")
        source.write_text("extends RefCounted\n# Unexpected tracked change\n")
        with self.assertRaisesRegex(ValueError, "Unexpected product change"):
            adapter.retain_generated_uids(root, self.root / "tracked-refusal")
        self.assertIn("Unexpected tracked change", (self.root / "tracked-refusal/git-diff.patch").read_text())
        self.assertIn("Unexpected tracked change", source.read_text())

    def test_imported_helper_must_belong_to_product(self):
        with mock.patch.object(adapter.importlib, "import_module", return_value=type("Other", (), {"__file__": str(self.root / "other.py")})):
            with self.assertRaisesRegex(ValueError, "another checkout"):
                adapter.module(ROOT, "fixture")

    def metadata_fixture(self):
        root = self.root / "metadata-source"
        root.mkdir()
        subprocess.run(["git", "init", str(root)], check=True, capture_output=True)
        adapter.git(root, "config", "core.autocrlf", "false")
        owner = root / "godot/scripts/owned.gd"
        owner.parent.mkdir(parents=True)
        owner.write_text("extends RefCounted\n")
        tracked_uid = root / "godot/scripts/tracked.gd.uid"
        tracked_uid.with_suffix("").write_text("extends RefCounted\n")
        tracked_uid.write_text("uid://committed123\n")
        descriptor = root / sorted(adapter.RAPIER_IMPORT_DESCRIPTORS)[0]
        descriptor.parent.mkdir(parents=True)
        descriptor.write_bytes(b"[remap]\nimporter=\"texture\"\n")
        adapter.git(root, "add", ".")
        subprocess.run(["git", "-C", str(root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "-qm", "Synthetic committed metadata owners"], check=True, capture_output=True)
        return root, owner, tracked_uid, descriptor

    def test_uid_with_untracked_owner_is_not_an_allowance(self):
        root, _, _, _ = self.metadata_fixture()
        (root / "godot/scripts/injected.gd").write_text("extends RefCounted\n")
        uid = root / "godot/scripts/injected.gd.uid"
        uid.write_text("uid://injected123\n")
        with self.assertRaisesRegex(ValueError, "Unexpected product change"):
            adapter.retain_generated_uids(root, self.root / "unowned-refusal")
        self.assertTrue(uid.exists())

    def test_uid_owner_source_bytes_must_equal_committed_blob(self):
        root, owner, _, _ = self.metadata_fixture()
        owner.write_text("extends RefCounted\n# injected source\n")
        uid = Path(str(owner) + ".uid")
        uid.write_text("uid://fixture123\n")
        with self.assertRaisesRegex(ValueError, "owner bytes differ"):
            adapter.retain_generated_uids(root, self.root / "changed-owner-refusal")
        self.assertTrue(uid.exists())
        self.assertIn("injected source", owner.read_text())

    def test_tracked_uid_is_never_removed_or_restored(self):
        root, _, tracked, _ = self.metadata_fixture()
        tracked.write_text("uid://changed123\n")
        with self.assertRaisesRegex(ValueError, "Unexpected product change"):
            adapter.retain_generated_uids(root, self.root / "tracked-uid-refusal")
        self.assertEqual(tracked.read_text(), "uid://changed123\n")

    def test_only_exact_rapier_descriptor_line_endings_can_be_restored(self):
        root, _, _, descriptor = self.metadata_fixture()
        original = descriptor.read_bytes()
        descriptor.write_bytes(original.replace(b"\n", b"\r\n"))
        output = self.root / "descriptor-retention"
        adapter.retain_generated_uids(root, output)
        self.assertEqual(descriptor.read_bytes(), original)
        name = descriptor.relative_to(root).as_posix()
        self.assertEqual((output / "import-descriptors" / name).read_bytes(), original.replace(b"\n", b"\r\n"))
        self.assertTrue(adapter.read(output / "import-descriptors.json")[name]["restored"])
        descriptor.write_bytes(original + b"changed=true\n")
        with self.assertRaisesRegex(ValueError, "beyond accepted line endings"):
            adapter.retain_generated_uids(root, self.root / "changed-descriptor-refusal")
        self.assertIn(b"changed=true", descriptor.read_bytes())

    # The synthetic reproduction intentionally selects CRLF. The workflow's
    # command-scope LF configuration must not override this private Git fixture.
    @mock.patch.dict(os.environ, {"GIT_CONFIG_COUNT": "0"})
    def test_false_crlf_index_dirt_refresh_preserves_the_exact_committed_tree(self):
        root, _, _, descriptor = self.metadata_fixture()
        original = descriptor.read_bytes()
        tree = adapter.git(root, "rev-parse", "HEAD^{tree}")
        adapter.git(root, "config", "core.autocrlf", "true")
        descriptor.unlink()
        adapter.git(root, "checkout", "--", descriptor.relative_to(root).as_posix())
        self.assertIn(b"\r\n", descriptor.read_bytes())
        descriptor.write_bytes(original)
        self.assertIn(descriptor.relative_to(root).as_posix(), adapter.git(root, "status", "--porcelain"))
        self.assertEqual(adapter.git(root, "diff", "--", descriptor.relative_to(root).as_posix()), "")
        output = self.root / "false-index-dirt"
        adapter.retain_generated_uids(root, output)
        receipt = adapter.read(output / "git-index-refresh.json")
        self.assertEqual(receipt["index_before"], tree)
        self.assertEqual(receipt["index_after"], tree)
        self.assertEqual(receipt["paths"], [descriptor.relative_to(root).as_posix()])
        self.assertEqual(descriptor.read_bytes(), original)
        self.assertEqual(adapter.git(root, "status", "--porcelain", "--untracked-files=all"), "")

    def test_preexisting_staged_change_is_not_an_index_refresh_allowance(self):
        root, owner, _, _ = self.metadata_fixture()
        owner.write_text("extends RefCounted\n# staged unexpected source\n")
        adapter.git(root, "add", "--", owner.relative_to(root).as_posix())
        staged = adapter.git(root, "write-tree")
        with self.assertRaisesRegex(ValueError, "Existing staged source changes"):
            adapter.retain_generated_uids(root, self.root / "staged-refusal")
        self.assertEqual(adapter.git(root, "write-tree"), staged)

    def test_complete_budget_uses_actual_canonical_fixture_discovery(self):
        result = adapter.budget(ROOT)
        self.assertEqual(result["fixture_seconds"], {adapter.CASES[0]: 1200, adapter.CASES[1]: 3940})
        self.assertEqual(result["rows"]["original_windows_os_runner"], 630)
        self.assertEqual(result["rows"]["original_controller_runner"], 540)
        self.assertEqual(result["rows"]["import_metadata_custody"], 1680)
        self.assertEqual(result["total_seconds"], 14980)
        self.assertLessEqual(result["total_seconds"], result["parent_minutes"] * 60)

    def test_increased_canonical_watchdogs_refuse_underbudget_parent(self):
        policy = adapter.module(ROOT, "execution_policy")
        changed = copy.deepcopy(policy.identity())
        changed["watchdogs"]["godot_setup_seconds"] += 6000
        with mock.patch.object(policy, "identity", return_value=changed), self.assertRaisesRegex(ValueError, "exceeds"):
            adapter.budget(ROOT)

    def test_actual_process_errors_are_retained_and_refused(self):
        output = self.root / "failed-process"
        with self.assertRaisesRegex(ValueError, "Original process failed"):
            adapter.run(ROOT, [sys.executable, "-c", "print('ERROR: synthetic injected fault')"], output, dict(os.environ), 30)
        record = adapter.read(output / "process.json")
        self.assertEqual(record["status"], "failed")
        self.assertTrue(record["retired"])
        self.assertEqual(record["log_sha256"], adapter.sha(output / "process.log"))

    def test_terminal_rejects_duplicate_failed_or_noninteger_assertions(self):
        path = self.root / "fixture.log"
        original = 'RESULT {"checks":81,"failures":[]}\n'
        path.write_text(original)
        self.assertEqual(adapter.terminal(path, "RESULT ")["checks"], 81)
        for changed in (original + original, original.replace("81", "true"), original.replace("[]", '["fault"]'), ""):
            path.write_text(changed)
            with self.subTest(log=changed), self.assertRaises(ValueError):
                adapter.terminal(path, "RESULT ")

    def os_fixture(self):
        folder = self.root / "os-fixture"
        folder.mkdir()
        engine = self.root / "synthetic-engine"
        engine.write_bytes(b"synthetic fixture, not executable")
        identity = {"source_commit": "1" * 40, "input_sha256": {name: "a" * 64 for name in adapter.INPUTS}}
        executions = []
        for index, (ok, seed) in enumerate(((True, 7), (True, 8), (True, 7), (False, 7), (True, 8))):
            document = folder / f"{index}.bin"
            adapter.write(document, {"fixture": "ULTIMA fixed audit writer, not a campaign transcript", "seed": seed,
                                     "payload": "Complete observed bytes. " * 64})
            log = folder / f"{index}.log"
            log.write_text("Synthetic storage observation\n")
            executions.append({"acknowledged": ok, "value": seed, "complete_json": True, "natural_completion": True,
                               "engine_error_detected": False, "retained_bytes": document.name, "sha256": adapter.sha(document),
                               "bytes": document.stat().st_size, "log": log.name, "log_sha256": adapter.sha(log),
                               "guards": {key: True for key in ("profile_verified", "wrong_path_refused", "wrong_profile_refused", "guards_preserved")}})
        report = {"status": "passed", "completed": True, "platform": "win32", "source_head": identity["source_commit"],
                  "engine_sha256": adapter.sha(engine), "input_sha256": {name: identity["input_sha256"][name] for name in adapter.OS_INPUTS},
                  "executions": executions, "cases": [{"fault": "none", "before": executions[0], "replacement": executions[1]},
                      {"fault": "locked-target", "before": executions[2], "refusal": executions[3], "retry": executions[4],
                       "lock": {"delete_access_probe_error": 32}}]}
        adapter.write(folder / "report.json", report)
        return folder, identity, engine, report

    def test_os_original_bytes_and_all_five_executions_are_read_back(self):
        folder, identity, engine, _ = self.os_fixture()
        adapter.verify_storage(folder, identity, engine)

    def test_os_summary_cannot_hide_missing_custody_or_missing_lock(self):
        folder, identity, engine, report = self.os_fixture()
        mutations = [lambda r: r.update(platform="linux"), lambda r: r.update(source_head="2" * 40),
                     lambda r: r["input_sha256"].pop(adapter.OS_INPUTS[0]), lambda r: r["executions"].pop(),
                     lambda r: r["cases"][1]["lock"].update(delete_access_probe_error=0),
                     lambda r: r["executions"][3].update(acknowledged=True)]
        for mutate in mutations:
            changed = copy.deepcopy(report)
            mutate(changed)
            adapter.write(folder / "report.json", changed)
            with self.subTest(mutate=mutate), self.assertRaises(ValueError):
                adapter.verify_storage(folder, identity, engine)

    def test_os_changed_output_bytes_are_refused(self):
        folder, identity, engine, report = self.os_fixture()
        (folder / report["executions"][3]["retained_bytes"]).write_bytes(b"truncated")
        with self.assertRaisesRegex(ValueError, "Original OS evidence changed"):
            adapter.verify_storage(folder, identity, engine)


if __name__ == "__main__":
    unittest.main(verbosity=2)
