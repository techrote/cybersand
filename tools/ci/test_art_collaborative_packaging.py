"""Reject incomplete, stale or mis-scoped collaborative application evidence.

These receipt mutations are synthetic unit adversaries. They do not execute
Godot or qualify a Windows evaluator.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/ci"))
import package_art_collaborative as package
import run_art_collaborative_gates as gates

COMMIT = "a" * 40
TREE = "b" * 40


def fixture(graphical: bool = False) -> dict:
    return {
        "schema": gates.SCHEMA, "status": "passed", "model_calls": 0,
        "source": {"commit": COMMIT, "tree": TREE, "tracked_source_clean": True},
        "platform": "windows", "graphical": graphical,
        "runtime": {
            "godot_sha256": "c" * 64, "godot_version": "4.7.stable.official.5b4e0cb0f",
            "provenance_sha256": "d" * 64,
            "payloads": {path: "e" * 64 for path in gates.RUNTIME_PATHS["windows"]},
        },
        "cases": [{"name": name, "marker": marker, "status": "passed", "exit_code": 0,
                   "timed_out": False, "log_sha256": "f" * 64,
                   "result": {"checks": 1, "failures": [], "model_calls": 0,
                              "display": "Windows" if graphical else "headless"}}
                  for name, marker in gates.TESTS.items()],
    }


class CollaborativeReceiptBoundary(unittest.TestCase):
    def validate(self, value: dict, graphical: bool = False) -> dict:
        return gates.validate_receipt(value, commit=COMMIT, tree=TREE,
                                      platform_name="windows", graphical=graphical)

    def test_complete_synthetic_receipt_is_structurally_admitted(self):
        for graphical in (False, True):
            value = fixture(graphical)
            self.assertIs(self.validate(value, graphical), value)

    def test_integer_zero_failure_count_is_accepted_without_rewriting(self):
        value = fixture()
        value["cases"][1]["result"]["failures"] = 0
        self.assertIs(self.validate(value), value)
        marker = "ZERO_FAILURES"
        self.assertEqual(gates.parse_case_output(marker + ' {"checks":3,"failures":0}', marker)["failures"], 0)

    def test_failure_and_check_types_do_not_coerce_booleans_or_strings(self):
        for bad in (False, True, 0.0, "0", {}, None):
            value = fixture()
            value["cases"][0]["result"]["failures"] = bad
            with self.subTest(failures=bad), self.assertRaises(ValueError):
                self.validate(value)
        value = fixture()
        value["cases"][0]["result"]["checks"] = True
        with self.assertRaises(ValueError):
            self.validate(value)

    def test_incomplete_or_duplicate_case_inventory_refuses(self):
        for mutation in ("missing", "duplicate", "unknown"):
            value = fixture()
            if mutation == "missing":
                value["cases"].pop()
            elif mutation == "duplicate":
                value["cases"][-1] = copy.deepcopy(value["cases"][0])
            else:
                value["cases"][-1]["name"] = "not_a_registered_case"
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.validate(value)

    def test_every_nonpass_process_disposition_refuses(self):
        for field, bad in (("status", "skipped"), ("exit_code", 1), ("exit_code", None), ("timed_out", True)):
            value = fixture()
            value["cases"][0][field] = bad
            with self.subTest(field=field, bad=bad), self.assertRaises(ValueError):
                self.validate(value)

    def test_case_failure_empty_checks_marker_and_hash_refuse(self):
        mutations = [
            lambda row: row.update(marker="UNRELATED_PASS"),
            lambda row: row.update(log_sha256="not-a-hash"),
            lambda row: row["result"].update(failures=["a failed assertion"]),
            lambda row: row["result"].update(checks=0),
            lambda row: row["result"].update(model_calls=1),
        ]
        for mutation in mutations:
            value = fixture()
            mutation(value["cases"][0])
            with self.assertRaises(ValueError):
                self.validate(value)

    def test_stale_source_and_dirty_source_refuse(self):
        for key, bad in (("commit", "0" * 40), ("tree", "0" * 40), ("tracked_source_clean", False)):
            value = fixture()
            value["source"][key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(value)

    def test_wrong_platform_or_display_scope_refuses(self):
        for key, bad in (("platform", "linux"), ("graphical", True), ("model_calls", 1),
                         ("status", "running"), ("schema", "legacy")):
            value = fixture()
            value[key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(value)

    def test_missing_native_rapier_or_engine_identity_refuses(self):
        value = fixture()
        value["runtime"]["payloads"].pop(next(iter(value["runtime"]["payloads"])))
        with self.assertRaises(ValueError):
            self.validate(value)
        for key, bad in (("godot_sha256", ""), ("godot_version", "another-engine")):
            value = fixture()
            value["runtime"][key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(value)

    def test_pair_must_use_identical_payloads(self):
        headless, displayed = fixture(), fixture(True)
        package.validate_pair(headless, displayed)
        displayed["runtime"]["godot_sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            package.validate_pair(headless, displayed)

    def test_marker_parser_requires_one_complete_success(self):
        marker = "FIXTURE_RESULT"
        valid = '{"checks":2,"failures":[],"model_calls":0}'
        self.assertEqual(gates.parse_case_output(marker + " " + valid, marker)["checks"], 2)
        for content in ("", marker + " " + valid + "\n" + marker + " " + valid,
                        marker + ' {"checks":2,"failures":["failure"]}',
                        marker + ' {"checks":0,"failures":[]}',
                        marker + " invalid"):
            with self.subTest(content=content[:40]), self.assertRaises((ValueError, json.JSONDecodeError)):
                gates.parse_case_output(content, marker)

    def test_success_marker_cannot_hide_script_or_resource_errors(self):
        marker = "FIXTURE_RESULT"
        success = marker + ' {"checks":5,"failures":[]}'
        for signature in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script",
                          "Failed loading resource:", "Error loading resource:"):
            with self.subTest(signature=signature), self.assertRaises(ValueError):
                gates.parse_case_output(signature + " retained negative\n" + success, marker)

    def test_untracked_source_guard_only_exempts_declared_generated_outputs(self):
        status = "\0".join([
            "?? evidence/case/summary.json", "?? godot/scripts/example.gd.uid",
            "?? godot/shaders/example.gdshader.uid", "?? godot/scripts/foreign.gd",
            "?? tools/ci/foreign.py", "?? foreign_root.py", "?? build/foreign.py",
            "?? docs/unchecked-guide.md", ""])
        self.assertEqual(gates.untracked_source_rows(status), [
            "?? godot/scripts/foreign.gd", "?? tools/ci/foreign.py", "?? foreign_root.py",
            "?? build/foreign.py", "?? docs/unchecked-guide.md"])

    def test_packager_requires_complete_original_logs(self):
        value = fixture()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "summary.json"
            for case in value["cases"]:
                log = path.parent / case["name"] / "process.log"
                log.parent.mkdir()
                log.write_text(case["marker"] + " " + json.dumps(case["result"]) + "\n", encoding="utf-8")
                case["log_sha256"] = hashlib.sha256(log.read_bytes()).hexdigest()
            path.write_text(json.dumps(value), encoding="utf-8")
            package.receipt(path, COMMIT, TREE, False)
            value["cases"][0]["result"]["checks"] += 1
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError):
                package.receipt(path, COMMIT, TREE, False)
            value["cases"][0]["result"]["checks"] -= 1
            path.write_text(json.dumps(value), encoding="utf-8")
            log.write_text("changed log\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                package.receipt(path, COMMIT, TREE, False)
            log.unlink()
            with self.assertRaises(ValueError):
                package.receipt(path, COMMIT, TREE, False)

    def _creative_artifacts(self, root: Path) -> tuple[Path, dict]:
        path = root / "evidence/summary.json"
        source = path.parent / "test_art_collaborative_native"
        source.mkdir(parents=True)
        value = fixture(True)
        native = next(case for case in value["cases"] if case["name"] == "test_art_collaborative_native")
        native["artifacts_sha256"] = {}
        names = [f"{index:02d}-{name}-{suffix}" for index, name in enumerate(package.SCENARIO_IDS)
                 for suffix in package.EXAMPLE_SUFFIXES] + ["creative-native-summary.json"]
        for name in names:
            data = b"\x89PNG\r\n\x1a\nsynthetic unit bytes" if name.endswith(".png") else json.dumps({"synthetic_unit_fixture": name}).encode()
            (source / name).write_bytes(data)
            native["artifacts_sha256"][name] = hashlib.sha256(data).hexdigest()
        return path, value

    def test_only_declared_creative_artifacts_are_packaged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path, value = self._creative_artifacts(root)
            source = path.parent / "test_art_collaborative_native"
            (source / "unrelated-private-profile.json").write_text('{"must_not_copy":true}')
            output = root / "package"
            output.mkdir()
            result = package.stage_example_artifacts(output, path, value)
            self.assertEqual(len(result["original_files_sha256"]), len(package.SCENARIO_IDS) * len(package.EXAMPLE_SUFFIXES) + 1)
            self.assertFalse((output / package.EXAMPLE_DIRECTORY / "unrelated-private-profile.json").exists())
            installer = (output / "Install evaluated starts.cmd").read_text()
            self.assertEqual(installer.count('if not exist "%ART_EXAMPLE_DEST%\\setup-'), 9)
            self.assertNotIn("http", installer)
            self.assertTrue(installer.count("%~dp0profile") == 1)
            for label, name in result["setup_labels"].items():
                self.assertLessEqual(len(label), 48)
                self.assertTrue((output / package.EXAMPLE_DIRECTORY / name).is_file())

    def test_missing_or_changed_native_example_refuses(self):
        for mutation in ("missing", "changed", "unhashed"):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path, value = self._creative_artifacts(root)
                name = "00-industrial_repair-after-native.png"
                source = path.parent / "test_art_collaborative_native" / name
                if mutation == "missing":
                    source.unlink()
                elif mutation == "changed":
                    source.write_bytes(b"changed")
                else:
                    native = next(case for case in value["cases"] if case["name"] == "test_art_collaborative_native")
                    native["artifacts_sha256"].pop(name)
                output = root / "package"
                output.mkdir()
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    package.stage_example_artifacts(output, path, value)

    def test_standalone_example_verifier_requires_explicit_complete_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path, value = self._creative_artifacts(root)
            output = root / "package"
            output.mkdir()
            examples = package.stage_example_artifacts(output, path, value)
            identity = {"creative_examples": examples, "files_sha256": copy.deepcopy(examples["original_files_sha256"])}
            package.validate_packaged_examples(identity, value)
            name = "00-industrial_repair-after-native.png"
            relative = package.EXAMPLE_DIRECTORY + "/" + name
            for mutation in ("missing", "invalid", "manifest_missing", "coherent_missing"):
                changed_value, changed_identity = copy.deepcopy(value), copy.deepcopy(identity)
                native = next(case for case in changed_value["cases"] if case["name"] == "test_art_collaborative_native")
                if mutation in ("missing", "coherent_missing"):
                    native["artifacts_sha256"].pop(name)
                elif mutation == "invalid":
                    native["artifacts_sha256"][name] = None
                if mutation in ("manifest_missing", "coherent_missing"):
                    changed_identity["files_sha256"].pop(relative)
                if mutation == "coherent_missing":
                    changed_identity["creative_examples"]["original_files_sha256"][relative] = None
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    package.validate_packaged_examples(changed_identity, changed_value)

    def test_standalone_example_verifier_requires_exact_named_start_mapping(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path, value = self._creative_artifacts(root)
            output = root / "package"
            output.mkdir()
            examples = package.stage_example_artifacts(output, path, value)
            identity = {"creative_examples": examples, "files_sha256": copy.deepcopy(examples["original_files_sha256"])}
            for field, bad in (("setup_labels", {}), ("setup_labels", {"art02-renamed": "foreign.json"}),
                               ("source_receipt", "qualification/unrelated.json"), ("model_calls", False)):
                changed = copy.deepcopy(identity)
                changed["creative_examples"][field] = bad
                with self.subTest(field=field, bad=bad), self.assertRaises(ValueError):
                    package.validate_packaged_examples(changed, value)

    def test_graphical_receipt_requires_actual_ui_backend_field(self):
        value = fixture(True)
        ui = next(case for case in value["cases"] if case["name"] == "test_art_collaboration_workspace")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "summary.json"
            for bad in (None, "", "headless"):
                ui["result"]["display"] = bad
                path.write_text(json.dumps(value), encoding="utf-8")
                with self.subTest(display=bad), self.assertRaises(ValueError):
                    package.receipt(path, COMMIT, TREE, True, check_logs=False)


if __name__ == "__main__":
    unittest.main()
