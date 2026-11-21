#!/usr/bin/env python3
"""Challenge real Git deltas, original focused ZIPs and dispatch lease boundaries."""
import argparse
from copy import deepcopy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

import gentek691_final_ci_followup as gate

FIXTURES = None
TARGET = None
TREE = None


class SourceDeltaTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.git("init", "-q")
        self.git("config", "user.name", "fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        for name in gate.SCOPE | {"godot/scripts/art_batch_panel.gd"}:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("original\n")
        self.git("add", ".")
        self.git("commit", "-qm", "original")
        self.before = self.git("rev-parse", "HEAD")
        for name in gate.SCOPE:
            (self.root / name).write_text("changed CI classification\n")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.STDOUT).decode().strip()

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-qm", "candidate")
        return self.git("rev-parse", "HEAD")

    def test_exact_six_file_delta_is_admitted(self):
        self.assertEqual(len(gate.exact_delta(self.root, self.before, self.commit(), gate.SCOPE)), 6)

    def test_real_product_source_change_is_refused(self):
        (self.root / "godot/scripts/art_batch_panel.gd").write_text("production changed\n")
        with self.assertRaisesRegex(ValueError, "scope"):
            gate.exact_delta(self.root, self.before, self.commit(), gate.SCOPE)

    def test_real_file_deletion_is_refused(self):
        (self.root / sorted(gate.SCOPE)[0]).unlink()
        with self.assertRaisesRegex(ValueError, "scope"):
            gate.exact_delta(self.root, self.before, self.commit(), gate.SCOPE)

    def test_real_mode_change_is_refused(self):
        (self.root / sorted(gate.SCOPE)[0]).chmod(0o755)
        with self.assertRaisesRegex(ValueError, "mode changed"):
            gate.exact_delta(self.root, self.before, self.commit(), gate.SCOPE)

    def test_real_symlink_substitution_is_refused(self):
        path = self.root / sorted(gate.SCOPE)[0]
        path.unlink()
        path.symlink_to("test_godot_regression_sharding.py")
        with self.assertRaises(ValueError):
            gate.exact_delta(self.root, self.before, self.commit(), gate.SCOPE)


class FocusedArtifactTests(unittest.TestCase):
    def fixture(self, platform):
        matches = list(FIXTURES.glob("gentek691-focused-" + platform + "-*.zip"))
        self.assertEqual(len(matches), 1)
        return matches[0]

    def altered(self, member, mutate):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        destination = Path(temporary.name) / "altered.zip"
        with zipfile.ZipFile(self.fixture("linux")) as source, zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as target:
            for info in source.infolist():
                content = source.read(info.filename)
                if info.filename == member:
                    value = json.loads(content)
                    mutate(value)
                    content = json.dumps(value).encode()
                target.writestr(info, content)
        return destination

    def test_both_actual_original_archives_are_admitted(self):
        for platform, expected in [("linux", 964), ("windows", 906)]:
            with self.subTest(platform=platform):
                report = gate.validate_focused_zip(self.fixture(platform), platform, TARGET, TREE)
                self.assertEqual(report["art_checks"], expected)
                self.assertEqual(report["flatten_graphical_checks"], 337)
                self.assertEqual(report["flatten_standalone_format_checks"], 102)

    def test_stale_source_identity_is_refused(self):
        path = self.altered("art-recovery/qualification.json", lambda r: r["identity_before"].update(source_commit="0" * 40))
        with self.assertRaises(ValueError):
            gate.validate_focused_zip(path, "linux", TARGET, TREE)

    def test_failed_process_cannot_hide_behind_positive_summary(self):
        path = self.altered("art-recovery/qualification.json", lambda r: r["cases"][1].update(returncode=7))
        with self.assertRaisesRegex(ValueError, "return code"):
            gate.validate_focused_zip(path, "linux", TARGET, TREE)

    def test_missing_native_case_is_refused(self):
        path = self.altered("art-recovery/qualification.json", lambda r: r["cases"].pop())
        with self.assertRaisesRegex(ValueError, "inventory"):
            gate.validate_focused_zip(path, "linux", TARGET, TREE)

    def test_unwitnessed_crash_is_refused(self):
        def mutate(report):
            next(row for row in report["cases"] if row["name"] == "art-durability-crash-seed")["kill_requested"] = False
        path = self.altered("art-recovery/qualification.json", mutate)
        with self.assertRaisesRegex(ValueError, "hard-kill"):
            gate.validate_focused_zip(path, "linux", TARGET, TREE)

    def test_graphical_replacement_is_refused(self):
        def mutate(report):
            next(row for row in report if row["label"] == "side-512-workers-1-author")["command"].append("--headless")
        path = self.altered("flatten/results.json", mutate)
        with self.assertRaisesRegex(ValueError, "headless"):
            gate.validate_focused_zip(path, "linux", TARGET, TREE)

    def test_removed_failed_owner_case_is_refused(self):
        path = self.altered("flatten/results.json", lambda r: r.pop())
        with self.assertRaisesRegex(ValueError, "inventory"):
            gate.validate_focused_zip(path, "linux", TARGET, TREE)


class LeaseCommands:
    def __init__(self, evidence, *, stale_initial=False, move_after_dispatch=False, change_main=False):
        self.evidence = evidence
        self.dispatched = []
        self.stale_initial = stale_initial
        self.move_after_dispatch = move_after_dispatch
        self.change_main = change_main

    def api(self, name, path):
        is_main = path.endswith("/main")
        changed = self.stale_initial or (self.move_after_dispatch and self.dispatched)
        oid = gate.MAIN if is_main else TARGET
        if (is_main and self.change_main) or (not is_main and changed):
            oid = "f" * 40
        return {"object": {"sha": oid}}

    def run(self, name, command):
        self.dispatched.append(command)
        return b""


class DispatchLeaseTests(unittest.TestCase):
    def commands(self, **kw):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        return LeaseCommands(Path(temporary.name), **kw)

    def focused(self):
        return {"status": "passed", "head_sha": TARGET, "source_tree": TREE}

    def test_six_exact_requests_plus_retained_seventh_gate(self):
        commands = self.commands()
        result = gate.request_workflows(commands, TARGET, self.focused())
        self.assertEqual(len(commands.dispatched), 6)
        self.assertEqual(len(result["complete_gate_inventory"]), 7)
        self.assertEqual([c[3] for c in commands.dispatched], list(gate.WORKFLOWS))
        self.assertFalse(any("gentek80" in c[3] or c[3] == "gentek691-art-history-repro.yml" for c in commands.dispatched))

    def test_stale_owning_ref_blocks_first_request(self):
        commands = self.commands(stale_initial=True)
        with self.assertRaisesRegex(ValueError, "branch lease"):
            gate.request_workflows(commands, TARGET, self.focused())
        self.assertEqual(commands.dispatched, [])

    def test_changed_main_blocks_first_request(self):
        commands = self.commands(change_main=True)
        with self.assertRaisesRegex(ValueError, "main lease"):
            gate.request_workflows(commands, TARGET, self.focused())
        self.assertEqual(commands.dispatched, [])

    def test_ref_movement_preserves_first_request_and_stops_next(self):
        commands = self.commands(move_after_dispatch=True)
        with self.assertRaisesRegex(ValueError, "branch lease"):
            gate.request_workflows(commands, TARGET, self.focused())
        self.assertEqual(len(commands.dispatched), 1)
        result = json.loads((commands.evidence / "dispatch.json").read_text())
        self.assertEqual(result["status"], "failed")
        self.assertTrue(result["standard_dispatches"][0]["requested"])

    def test_unsuccessful_focused_gate_blocks_all_requests(self):
        commands = self.commands()
        focused = self.focused()
        focused["status"] = "failed"
        with self.assertRaisesRegex(ValueError, "focused gate"):
            gate.request_workflows(commands, TARGET, focused)
        self.assertEqual(commands.dispatched, [])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture-dir", type=Path, required=True)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--candidate-tree", required=True)
    args, remaining = parser.parse_known_args()
    FIXTURES, TARGET, TREE = args.fixture_dir.resolve(), args.candidate_sha, args.candidate_tree
    unittest.main(argv=[__file__, *remaining])
