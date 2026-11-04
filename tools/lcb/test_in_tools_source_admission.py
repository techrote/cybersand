"""Adversarial source-transition checks; no host/gameplay execution claims."""
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import in_tools_contract as legacy
import in_tools_source_admission as current


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.original = legacy.PLAN.read_bytes()
        self.record = legacy.parse_json(current.ADMISSION.read_text())

    def reject(self, record=None, original=None):
        with self.assertRaises(legacy.ContractError):
            current.admitted_plan(self.original if original is None else original,
                                  self.record if record is None else record)

    def test_complete_current_checkout_and_all_comparison_inputs(self):
        result = current.check()
        self.assertEqual(result["source_inputs_checked"], 25)
        self.assertEqual(result["comparison_inputs_checked"], 9)
        self.assertEqual(result["reviewed_source_changes"], ["godot/scripts/simulation_worker.gd"])
        self.assertFalse(result["gameplay_qualified"])
        self.assertFalse(result["native_receipt_authenticated"])
        self.assertFalse(result["runtime_qualified"])

    def test_historical_checker_still_refuses_current_worker(self):
        with self.assertRaisesRegex(legacy.ContractError, "source changed; re-admission required.*simulation_worker"):
            legacy.source_check(legacy.parse_json(self.original.decode()))

    def test_valid_json_cannot_bypass_historical_source_refusal(self):
        with tempfile.TemporaryDirectory() as temporary:
            packet = Path(temporary) / "packet.json"
            packet.write_text('{}')
            output = io.StringIO()
            with mock.patch.object(sys, "argv", ["contract", "--packet", str(packet)]), \
                 contextlib.redirect_stdout(output):
                self.assertEqual(legacy.main(), 1)
            self.assertIn("source changed; re-admission required", json.loads(output.getvalue())["reason"])

    def test_original_fixture_geometry_or_budget_cannot_change(self):
        for field in ("events", "domain", "horizon_ticks"):
            plan = json.loads(self.original)
            plan["fixtures"][0][field] = []
            with self.subTest(field=field):
                self.reject(original=json.dumps(plan).encode())

    def test_regenerating_original_hash_does_not_admit_a_changed_plan(self):
        raw = self.original + b"\n"
        self.record["original_plan"]["sha256"] = current.canonical_sha(raw)
        self.reject(original=raw)

    def test_original_plan_newline_rewrite_is_not_byte_identical(self):
        self.reject(original=self.original.replace(b"\n", b"\r\n"))

    def test_original_identity_cannot_be_retargeted(self):
        for key in ("path", "commit", "sha256"):
            record = copy.deepcopy(self.record)
            record["original_plan"][key] = "other"
            with self.subTest(key=key):
                self.reject(record)

    def test_unknown_missing_or_nonobject_admission_refuses(self):
        for value in (None, [], True, {**self.record, "skip_source_check": True},
                      {k: v for k, v in self.record.items() if k != "reviewed_changes"}):
            with self.subTest(value=type(value).__name__), self.assertRaises(legacy.ContractError):
                current.admitted_plan(self.original, value)

    def test_source_only_cannot_be_promoted_to_runtime_or_gameplay(self):
        for key in ("gameplay_qualified", "runtime_qualified"):
            for value in (True, 0, "false", None):
                record = copy.deepcopy(self.record)
                record[key] = value
                with self.subTest(key=key, value=value):
                    self.reject(record)

    def test_scope_or_authority_cannot_silently_change(self):
        for key in ("schema", "id", "scope", "authority"):
            record = copy.deepcopy(self.record)
            record[key] = "unreviewed"
            with self.subTest(key=key):
                self.reject(record)

    def test_source_inventory_cannot_omit_or_add_a_path(self):
        for mutation in ("omit", "extra", "escape"):
            record = copy.deepcopy(self.record)
            if mutation == "omit":
                del record["source_inputs"]["native/src/world.cpp"]
            else:
                record["source_inputs"]["../outside" if mutation == "escape" else "extra.cpp"] = "a" * 64
            with self.subTest(mutation=mutation):
                self.reject(record)

    def test_second_source_replacement_is_not_authorized(self):
        self.record["source_inputs"]["native/src/world.cpp"] = "a" * 64
        self.reject()

    def test_forged_worker_and_matching_transition_are_not_authorized(self):
        self.record["source_inputs"][current.WORKER] = "a" * 64
        self.record["reviewed_changes"][0]["after_sha256"] = "a" * 64
        self.reject()

    def test_old_digest_and_transition_source_must_be_exact(self):
        for key in ("path", "before_sha256", "source_commit", "integration_commit"):
            record = copy.deepcopy(self.record)
            record["reviewed_changes"][0][key] = "a" * 64
            with self.subTest(key=key):
                self.reject(record)

    def test_missing_duplicate_or_second_transition_refuses(self):
        for changes in ([], self.record["reviewed_changes"] * 2,
                        [{**self.record["reviewed_changes"][0], "extra": "not reviewed"}]):
            record = copy.deepcopy(self.record)
            record["reviewed_changes"] = changes
            with self.subTest(changes=changes):
                self.reject(record)

    def test_accepted_main_tree_and_comparison_identity_cannot_move(self):
        for key in ("accepted_main", "accepted_tree", "comparison_commit"):
            record = copy.deepcopy(self.record)
            record[key] = "a" * 40
            with self.subTest(key=key):
                self.reject(record)

    def test_malformed_duplicate_and_nonfinite_json_refuse(self):
        for raw in ('{"id":"first","id":"second"}', '{"x":NaN}', '{'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                legacy.parse_json(raw)

    def test_changed_or_missing_actual_bytes_refuse_after_valid_admission(self):
        plan = current.admitted_plan(self.original, self.record)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in plan["source_inputs"]:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((legacy.ROOT / relative).read_bytes())
            self.assertEqual(legacy.source_check(plan, root)["source_inputs_checked"], 25)
            for relative in (current.WORKER, "native/src/world.cpp"):
                path = root / relative
                original = path.read_bytes()
                path.write_bytes(original + b"\n")
                with self.subTest(path=relative), self.assertRaisesRegex(legacy.ContractError, "source changed"):
                    legacy.source_check(plan, root)
                path.write_bytes(original)
            (root / "native/src/world.cpp").unlink()
            with self.assertRaisesRegex(legacy.ContractError, "missing source input"):
                legacy.source_check(plan, root)

    def test_actual_git_tree_mismatch_and_missing_ancestry_refuse(self):
        real = current.git_bytes
        for mutation in ("tree", "ancestry"):
            def altered(root, *args):
                if mutation == "tree" and args == ("rev-parse", current.ACCEPTED_MAIN + "^{tree}"):
                    return b"0" * 40
                if mutation == "ancestry" and args[:2] == ("merge-base", "--is-ancestor"):
                    raise legacy.ContractError("required ancestor missing")
                return real(root, *args)
            with self.subTest(mutation=mutation), mock.patch.object(current, "git_bytes", side_effect=altered), \
                 self.assertRaises(legacy.ContractError):
                current.check()

    def test_committed_drift_cannot_hide_behind_restored_working_files(self):
        # Make real descendant Git commits, then restore admitted working bytes.
        # No production checkout or branch is changed by these negative controls.
        for relative in (current.WORKER, "native/src/world.cpp", current.ORIGINAL_PATH):
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / "source"
                env = {**os.environ, "GIT_LFS_SKIP_SMUDGE": "1",
                       "GIT_AUTHOR_NAME": "Admission test", "GIT_AUTHOR_EMAIL": "test@example.invalid",
                       "GIT_COMMITTER_NAME": "Admission test", "GIT_COMMITTER_EMAIL": "test@example.invalid"}
                subprocess.run(["git", "clone", "--shared", "--no-checkout", "--quiet",
                                str(legacy.ROOT), str(root)], check=True, env=env)
                def git(*args, data=None):
                    return subprocess.check_output(["git", "-C", str(root), *args],
                                                   input=data, stderr=subprocess.PIPE, env=env)
                parent = git("rev-parse", "HEAD").decode().strip()
                git("read-tree", "HEAD")
                blob = git("hash-object", "-w", "--stdin",
                           data=(legacy.ROOT / relative).read_bytes() + b"\n").decode().strip()
                git("update-index", "--cacheinfo", "100644", blob, relative)
                tree = git("write-tree").decode().strip()
                commit = git("commit-tree", tree, "-p", parent,
                             data=b"Unreviewed committed source control\n").decode().strip()
                git("update-ref", "--no-deref", "HEAD", commit)
                for path in {*self.record["source_inputs"], current.ORIGINAL_PATH}:
                    destination = root / path
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes((legacy.ROOT / path).read_bytes())
                with self.assertRaisesRegex(legacy.ContractError, "committed .*differs"):
                    current.check(root=root)

    def test_unavailable_git_objects_refuse(self):
        with mock.patch.object(current.subprocess, "check_output", side_effect=subprocess.CalledProcessError(128, "git")), \
             self.assertRaisesRegex(legacy.ContractError, "required Git source/ancestry unavailable"):
            current.check()

    def test_missing_pinned_comparison_cannot_be_substituted(self):
        real = subprocess.check_output
        def missing(args, **kwargs):
            if "show" in args and any(str(a).startswith(current.COMPARISON + ":") for a in args):
                raise subprocess.CalledProcessError(128, args)
            return real(args, **kwargs)
        with mock.patch.object(subprocess, "check_output", side_effect=missing), \
             self.assertRaisesRegex(legacy.ContractError, "comparison object unavailable"):
            current.check()

    def test_admitted_map_does_not_mutate_frozen_plan(self):
        before = legacy.PLAN.read_bytes()
        view = current.admitted_plan(before, self.record)
        historical = json.loads(before)
        for key, value in historical.items():
            if key not in {"source_inputs", "accepted_main", "accepted_tree"}:
                self.assertEqual(view[key], value)
        self.assertEqual(legacy.PLAN.read_bytes(), before)
        self.assertEqual(historical["source_inputs"][current.WORKER], current.BEFORE_WORKER)


if __name__ == "__main__":
    unittest.main()
