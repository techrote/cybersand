"""Adverse controls for mandatory Linux source and original-artifact coverage."""

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import execution_policy
import run_godot_regressions as runner
import verify_linux_godot_shards as subject
import verify_render_upload577_refusal as refusal


class LinuxCoverageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.cases = [runner.Case("unit", ("--script", "res://unit.gd"), 1200, 1),
                      runner.Case("pixels_render", ("--script", "res://pixels.gd"), 1200, 1, True)]
        self.options = {"cases": self.cases, "source": "a" * 40, "tree": "b" * 40,
            "runtime": {"cybersand_runtime": {"path": "native.so", "sha256": "c" * 64},
                        "rapier_runtime": {"path": "rapier.so", "sha256": "d" * 64}},
            "tested_inputs": {"tools/material_catalogue/lab.py": "e" * 64,
                              "materials/catalogue/catalogue.json": "f" * 64},
            "run_id": "123", "attempt": "1", "shard_count": 2, "godot_version": "4.7.control"}
        self.reports = []
        shards, _ = runner.build_shard_plan(self.cases, 2)
        for index, cases in enumerate(shards):
            directory = self.root / str(index)
            directory.mkdir()
            identity = {"source_sha": self.options["source"], "source_tree": self.options["tree"],
                "execution_policy": execution_policy.identity(), "shard_index": index,
                "shard_count": 2, "run_id": "123", "run_attempt": "1",
                "tested_inputs": self.options["tested_inputs"],
                "godot_version": "4.7.control", **self.options["runtime"]}
            report = {"identity": identity, "status": "passed", "completed": True,
                "source_drift": [],
                "assigned_cases": [case.name for case in cases], "results": []}
            for offset, case in enumerate([runner.Case("import", ("--editor", "--quit"), 1200, 1), *cases]):
                log = directory / (case.name + ".log")
                log.write_text("controlled assertions passed\n", encoding="utf-8")
                report["results"].append({"name": case.name, "role": "preflight" if offset == 0 else "case",
                    "timeout_seconds": case.timeout, "requires_display": case.requires_display,
                    "execution_policy": execution_policy.identity(), "status": "passed", "returncode": 0,
                    "natural_completion": True, "log": log.name, "log_sha256": subject.digest(log),
                    "command": runner.case_command("/controlled/Godot", case, "linux")})
            path = directory / "timings.json"
            path.write_text(json.dumps(report), encoding="utf-8")
            self.reports.append(path)

    def change(self, callback, index=0):
        path = self.reports[index]
        value = json.loads(path.read_text())
        callback(value)
        path.write_text(json.dumps(value))

    def verify(self):
        return subject.verify(self.root, **self.options)

    def test_complete_source_matched_originals_pass(self):
        self.assertEqual(self.verify()["case_count"], 2)
        self.assertEqual(self.verify()["source_inputs_verified"], 2)

    def test_missing_or_changed_authoring_inventory_is_rejected(self):
        for value in (None, {}, {"tools/material_catalogue/lab.py": "0" * 64,
                               "materials/catalogue/catalogue.json": "f" * 64}):
            with self.subTest(value=value):
                self.change(lambda report: report["identity"].update(tested_inputs=value))
                with self.assertRaisesRegex(ValueError, "tested_inputs identity"):
                    self.verify()

    def test_missing_or_changed_terminal_custody_is_rejected(self):
        for value in (None, ["tools/material_catalogue/lab.py"]):
            with self.subTest(value=value):
                self.change(lambda report: report.update(source_drift=value))
                with self.assertRaisesRegex(ValueError, "source inputs changed"):
                    self.verify()

    def test_missing_or_duplicate_shard_fails(self):
        self.change(lambda report: report["identity"].update(shard_index=0), index=1)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.verify()
        self.reports[1].unlink()
        with self.assertRaisesRegex(ValueError, "count"):
            self.verify()

    def test_changed_source_attempt_runtime_or_policy_fails(self):
        for key, value in (("source_sha", "f" * 40), ("source_tree", "f" * 40),
                           ("run_attempt", "2"), ("cybersand_runtime", {}), ("execution_policy", {})):
            path = self.reports[0]
            original = path.read_bytes()
            self.change(lambda report: report["identity"].update({key: value}))
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "identity"):
                self.verify()
            path.write_bytes(original)

    def test_natural_completion_is_required_even_after_zero_exit(self):
        self.change(lambda report: report["results"][1].update(natural_completion=False))
        with self.assertRaisesRegex(ValueError, "naturally"):
            self.verify()

    def test_late_failure_or_missing_case_cannot_be_hidden(self):
        self.change(lambda report: report["results"][1].update(returncode=19))
        with self.assertRaisesRegex(ValueError, "naturally"):
            self.verify()
        self.change(lambda report: report["results"].pop())
        with self.assertRaisesRegex(ValueError, "results missing"):
            self.verify()

    def test_changed_original_log_or_forged_error_status_fails(self):
        path = self.reports[0]
        report = json.loads(path.read_text())
        log = path.parent / report["results"][1]["log"]
        log.write_text("ERROR: late assertion\n")
        with self.assertRaisesRegex(ValueError, "log changed"):
            self.verify()
        self.change(lambda report: report["results"][1].update(log_sha256=subject.digest(log)))
        with self.assertRaisesRegex(ValueError, "error or skipped"):
            self.verify()

    def test_original_render_cannot_be_replaced_with_headless(self):
        self.change(lambda report: report["results"][1].update(command=["Godot", "--headless"]), index=1)
        with self.assertRaisesRegex(ValueError, "command differs"):
            self.verify()

    def test_original_import_command_is_required(self):
        self.change(lambda report: report["results"][0].update(command=["Godot", "--headless"]))
        with self.assertRaisesRegex(ValueError, "command differs"):
            self.verify()

    def test_missing_play_independent_readback_is_rejected(self):
        # A real PLAY name activates its source-selected raw evidence reader.
        from unittest import mock
        with mock.patch.object(runner, "case_readback_contract", return_value=runner.LIFE010_READBACK):
            with self.assertRaisesRegex(ValueError, "PLAY readback"):
                self.verify()

    def test_path_escape_is_not_an_original_artifact(self):
        self.change(lambda report: report["results"][1].update(log="../foreign.log"))
        with self.assertRaisesRegex(ValueError, "escapes"):
            self.verify()


class RetainedUpload577RefusalTests(unittest.TestCase):
    """Parser/aggregate controls; genuine graphical originals are replayed separately."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.directory = self.root / "shard"
        self.directory.mkdir()
        self.path = self.directory / "timings.json"
        self.case = runner.Case(refusal.SCRIPT.removesuffix(".gd"),
            ("--script", "res://tests/" + refusal.SCRIPT), 1200, 1, True)
        self.engine = "/original/godot/" + refusal.LINUX_GODOT_ARCHIVE.removesuffix(".zip")
        self.options = {"cases": [self.case], "source": "a" * 40, "tree": "b" * 40,
            "runtime": {"cybersand_runtime": {"path": "native.so", "sha256": "c" * 64},
                        "rapier_runtime": {"path": "rapier.so", "sha256": "d" * 64}},
            "tested_inputs": {}, "run_id": "123", "attempt": "1", "shard_count": 1,
            "godot_version": refusal.LINUX_GODOT_VERSION}
        self.errors = list(refusal._existing_verifier().REFUSAL_ERRORS)
        paths = ["res://scripts/main.gd", "res://scripts/material_upload_hybrid.gd",
                 "res://scripts/simulation_worker.gd", "res://shaders/material_upload_copy.gdshader",
                 "res://tests/" + refusal.SCRIPT]
        self.data = {"schema": "render-upload-577-independent-main-refusal-v1", "ok": True,
            "checks": 166, "failures": [],
            "cases": [{"accepted": 11, "ack": 15, "channels": c, "final_mode": "full_update",
                       "final_serial": 15, "refused": 4} for c in (1, 2)],
            "expected_error_messages": [line.removeprefix("ERROR: ") for line in self.errors],
            "source_files_sha256": {p: subject.digest(runner.ROOT / p.replace("res://", "godot/")) for p in paths},
            "context": {"source_revision": self.options["source"], "platform": "Linux",
                "display_server": "X11", "backend": "opengl3", "fixture": "res://tests/" + refusal.SCRIPT,
                "fixture_sha256": subject.digest(runner.ROOT / "godot/tests" / refusal.SCRIPT),
                "engine_path": self.engine, "engine_sha256": refusal.LINUX_GODOT_EXECUTABLE_SHA256,
                "godot": {"major": 4, "minor": 7, "patch": 0, "status": "stable", "build": "official",
                          "hash": refusal.LINUX_GODOT_SOURCE_HASH}}}
        self.write()

    def output(self, data=None, errors=None):
        return "\n".join(self.errors if errors is None else errors) + "\n" + refusal.MARKER + \
            json.dumps(self.data if data is None else data) + "\n"

    def write(self, *, data=None, output=None, retained=None):
        data = copy.deepcopy(self.data if data is None else data)
        receipt = self.directory / (self.case.name + "-receipt.json")
        receipt.unlink(missing_ok=True)
        receipt.write_text(json.dumps(data if retained is None else retained))
        identity = {"source_sha": self.options["source"], "source_tree": self.options["tree"],
            "execution_policy": execution_policy.identity(), "shard_index": 0, "shard_count": 1,
            "run_id": "123", "run_attempt": "1", "tested_inputs": self.options["tested_inputs"],
            "godot_version": self.options["godot_version"], **self.options["runtime"]}
        report = {"identity": identity, "status": "passed", "completed": True, "source_drift": [],
                  "assigned_cases": [self.case.name], "results": []}
        for offset, case in enumerate([runner.Case("import", ("--editor", "--quit"), 1200, 1), self.case]):
            log = self.directory / (case.name + ".log")
            log.write_text("import complete\n" if offset == 0 else self.output(data) if output is None else output)
            row = {"name": case.name, "role": "preflight" if offset == 0 else "case",
                "timeout_seconds": case.timeout, "requires_display": case.requires_display,
                "execution_policy": execution_policy.identity(), "status": "passed", "returncode": 0,
                "natural_completion": True, "log": log.name, "log_sha256": subject.digest(log),
                "command": runner.case_command(self.engine, case, "linux")}
            if offset:
                row["intentional_diagnostics"] = {"status": "passed", "expected_error_count": 8,
                    "receipt": receipt.name, "receipt_sha256": subject.digest(receipt)}
            report["results"].append(row)
        self.path.write_text(json.dumps(report))

    def change(self, callback):
        report = json.loads(self.path.read_text())
        callback(report["results"][1])
        self.path.write_text(json.dumps(report))

    def verify(self):
        return subject.verify(self.root, **self.options)

    def test_exact_retained_corpus_passes_without_original_editor_installed(self):
        self.assertFalse(Path(self.engine).exists())
        result = self.verify()
        self.assertEqual(result["case_count"], 1)
        readback = result["intentional_diagnostic_readbacks"]
        self.assertEqual(len(readback), 1)
        self.assertEqual(readback[0]["checks"], 166)
        self.assertEqual(readback[0]["expected_error_count"], 8)
        self.assertEqual(readback[0]["engine_sha256"], refusal.LINUX_GODOT_EXECUTABLE_SHA256)

    def test_unlisted_missing_reordered_errors_and_skips_still_fail(self):
        controls = [self.output(errors=self.errors[:-1]),
            self.output(errors=[self.errors[1], self.errors[0], *self.errors[2:]])]
        controls += [self.output() + line + "\n" for line in (
            "ERROR: unrelated failure", "SCRIPT ERROR: assertion failed", "Parse Error: invalid token",
            "Failed to load script: foreign.gd", "Failed loading resource: res://foreign.tres", "SKIP unsupported")]
        for output in controls:
            with self.subTest(tail=output[-90:]), self.assertRaises(ValueError):
                self.write(output=output)
                self.verify()

    def test_missing_duplicate_malformed_or_nonobject_marker_fails(self):
        prefix = "\n".join(self.errors) + "\n"
        for output in (prefix, self.output() + refusal.MARKER + json.dumps(self.data) + "\n",
                       prefix + refusal.MARKER + "{broken}\n", prefix + refusal.MARKER + "[]\n",
                       self.output() + " " + refusal.MARKER + "{broken\n",
                       self.output() + refusal.MARKER.rstrip() + "\n"):
            with self.subTest(tail=output[-60:]), self.assertRaises(ValueError):
                self.write(output=output)
                self.verify()

    def test_missing_forged_seal_or_foreign_receipt_contract_fails(self):
        mutations = [lambda row: row.pop("intentional_diagnostics"),
            lambda row: row["intentional_diagnostics"].update(status="failed"),
            lambda row: row["intentional_diagnostics"].update(expected_error_count=7),
            lambda row: row["intentional_diagnostics"].update(expected_error_count=8.0),
            lambda row: row["intentional_diagnostics"].update(receipt="../foreign.json"),
            lambda row: row["intentional_diagnostics"].update(receipt_sha256="0" * 64),
            lambda row: row["intentional_diagnostics"].update(error="hidden failure")]
        for index, mutation in enumerate(mutations):
            with self.subTest(index=index), self.assertRaises(ValueError):
                self.write()
                self.change(mutation)
                self.verify()
        self.write()
        (self.directory / (self.case.name + "-receipt.json")).unlink()
        with self.assertRaisesRegex(ValueError, "Missing original"):
            self.verify()

    def test_resealed_receipt_must_equal_the_single_original_log_receipt(self):
        foreign = copy.deepcopy(self.data)
        foreign["observation"] = "different sealed object"
        self.write(retained=foreign)
        with self.assertRaisesRegex(ValueError, "differs from the original log"):
            self.verify()

    def test_corpus_source_and_actual_graphical_runtime_are_independently_required(self):
        mutations = [lambda d: d.update(ok=False), lambda d: d.update(checks=165),
            lambda d: d["cases"][0].update(ack=14), lambda d: d.update(failures=["assertion"]),
            lambda d: d["context"].update(source_revision="e" * 40),
            lambda d: d["source_files_sha256"].update({"res://scripts/main.gd": "0" * 64}),
            lambda d: d["context"].update(fixture_sha256="0" * 64),
            lambda d: d["context"].update(engine_sha256="0" * 64),
            lambda d: d["context"].update(engine_path="/foreign/editor"),
            lambda d: d["context"].update(platform="Windows"),
            lambda d: d["context"].update(display_server="headless"),
            lambda d: d["context"].update(backend="dummy"),
            lambda d: d["context"]["godot"].update(hash="0" * 40),
            lambda d: d["context"]["godot"].update(patch=False)]
        for index, mutation in enumerate(mutations):
            data = copy.deepcopy(self.data)
            mutation(data)
            with self.subTest(index=index), self.assertRaises(ValueError):
                self.write(data=data)
                self.verify()

    def test_arbitrary_editor_version_or_matching_foreign_path_is_not_authority(self):
        self.options["godot_version"] = "4.8.stable.official.unknown"
        self.write()
        with self.assertRaisesRegex(ValueError, "independently pinned"):
            self.verify()
        self.options["godot_version"] = refusal.LINUX_GODOT_VERSION
        self.engine = "/original/foreign-editor"
        data = copy.deepcopy(self.data)
        data["context"]["engine_path"] = self.engine
        self.write(data=data)
        with self.assertRaisesRegex(ValueError, "pinned Linux editor"):
            self.verify()

    def test_changed_release_archive_pin_is_not_admitted(self):
        path = refusal.ROOT / "third_party/godot-runtime.lock.json"
        original_reader = Path.read_text
        original = json.loads(original_reader(path))
        for mutate in (lambda lock: lock.update(godot_version="4.8.stable"),
                       lambda lock: lock["editor"].update(sha256="0" * 64),
                       lambda lock: lock["editor"].update(filename="other.zip"),
                       lambda lock: lock.update(platform="windows")):
            lock = copy.deepcopy(original)
            mutate(lock)
            def read(candidate, *args, **kwargs):
                return json.dumps(lock) if candidate == path else original_reader(candidate, *args, **kwargs)
            with mock.patch.object(Path, "read_text", new=read), self.assertRaisesRegex(ValueError, "independently pinned"):
                self.verify()

    def test_nonzero_exit_timeout_headless_or_bad_log_seal_stays_fatal(self):
        for mutation in (lambda row: row.update(returncode=9), lambda row: row.update(natural_completion=False),
                         lambda row: row.update(timeout_kind="case"), lambda row: row.update(diagnostic_error=True),
                         lambda row: row.update(requires_display=False),
                         lambda row: row.update(command=[self.engine, "--headless"]),
                         lambda row: row.update(log_sha256="0" * 64)):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.write()
                self.change(mutation)
                self.verify()

    def test_other_case_cannot_borrow_the_refusal_exception(self):
        self.case = runner.Case("ordinary_render", ("--script", "res://ordinary.gd"), 1200, 1, True)
        self.options["cases"] = [self.case]
        self.write()
        with self.assertRaisesRegex(ValueError, "error or skipped"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
