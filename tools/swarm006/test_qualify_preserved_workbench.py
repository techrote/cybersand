#!/usr/bin/env python3
"""Reject incomplete preservation reports and uncommitted executable source."""
import unittest
import json
import copy
from contextlib import redirect_stdout
import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
from unittest.mock import patch

import qualify_preserved_workbench as q


IMPORT_PATHS = ("godot/addons/godot-rapier2d/Radial2D.svg.import",
                "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
                "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
                "godot/addons/godot-rapier2d/logo_square_2d.png.import")


class SourceAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name) / "repo"
        self.root.mkdir()
        self.git("init", "--quiet")
        self.git("config", "user.name", "Source admission fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.autocrlf", "true")
        self.payloads = {name: (q.ROOT / name).read_bytes() for name in (".gitattributes", *IMPORT_PATHS)}
        self.payloads.update({"godot/scripts/example.gd": b"extends RefCounted\n",
                              "godot/example.svg": b'<svg xmlns="http://www.w3.org/2000/svg"/>\n',
                              "checkout-control.txt": b"Windows conversion is active.\n"})
        for name, data in self.payloads.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Isolated source admission fixture")
        for name in self.payloads:
            (self.root / name).unlink()
        self.git("checkout-index", "--all", "--force", "--index")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, stderr=subprocess.PIPE)

    def test_windows_autocrlf_checkout_and_archive_keep_actual_import_bytes(self):
        # This uses Git's real Windows conversion mode on either host. The
        # hosted Windows lane runs the same test with actual Windows Git.
        self.assertIn(b"\r\n", (self.root / "checkout-control.txt").read_bytes())
        with patch.object(q, "ROOT", self.root):
            before = q.source_inputs()
            self.assertIn(".gitattributes", before)
            self.assertEqual("", q.source_delta(q.SOURCE_PATHS))
            archive = self.git("archive", "--format=tar", "HEAD")
            with tarfile.open(fileobj=io.BytesIO(archive)) as members:
                for name in IMPORT_PATHS:
                    expected = self.payloads[name]
                    self.assertNotIn(b"\r", expected)
                    self.assertEqual(expected, (self.root / name).read_bytes(), name)
                    self.assertEqual(expected, members.extractfile(name).read(), name)
                    # Actual Windows Godot rewrote precisely these committed
                    # LF bytes. The pinned checkout already has those bytes.
                    (self.root / name).write_bytes(expected)
            self.assertEqual(before, q.source_inputs())
            self.assertEqual("", q.source_delta(q.SOURCE_PATHS))

    def test_changed_import_asset_script_and_attributes_refuse_with_evidence(self):
        alias = Path(self.folder.name) / "runtime-alias"
        alias.mkdir()
        engine, cli = alias / ".." / "godot", Path(self.folder.name) / "cli"
        engine.write_bytes(b"engine fixture");cli.write_bytes(b"native fixture")
        # main() resolves paths before checking the engine version. Exercise
        # an actual alias on every host, including Windows TEMP path aliases.
        self.assertNotEqual(str(engine), str(engine.resolve()))
        original_check_output = subprocess.check_output
        version_commands = []

        def command_output(command, **kwargs):
            if command[0] == "git":
                return original_check_output(command, **kwargs)
            self.assertEqual(Path(command[0]).resolve(), engine.resolve(), "unexpected non-Git executable")
            self.assertEqual(command[1:], ["--version"], "only the engine version query is mocked")
            self.assertEqual(kwargs, {"text": True, "timeout": 30})
            version_commands.append(command)
            return q.VERSION + "\n"

        for unexpected in ([str(cli), "--version"], [str(engine), "--headless"],
                           [str(engine), "--version", "--extra"]):
            with self.assertRaises(AssertionError):
                command_output(unexpected, text=True, timeout=30)

        for index, name in enumerate((IMPORT_PATHS[0], "godot/example.svg", "godot/scripts/example.gd", ".gitattributes")):
            path = self.root / name
            original = path.read_bytes()
            with patch.object(q, "ROOT", self.root):
                original_inputs = q.source_inputs()
            path.write_bytes(original + b"changed source content\n")
            output = Path(self.folder.name) / ("refusal-" + str(index))
            with patch.object(q, "ROOT", self.root), patch.object(q.subprocess, "check_output", side_effect=command_output), patch.object(sys, "argv", ["qualification", "--godot", str(engine), "--cli", str(cli), "--output", str(output)]):
                self.assertIn(name, q.source_delta(q.SOURCE_PATHS))
                with self.assertRaisesRegex(ValueError, "committed and clean; evidence:"):
                    q.main()
                record = json.loads((output / "source-admission-refusal.json").read_text())
                self.assertIs(record["passed"], False)
                self.assertEqual("source-admission", record["stage"])
                self.assertEqual(self.git("rev-parse", "HEAD").decode().strip(), record["source"])
                self.assertIn(name, record["source_delta"])
                changed = record["changed_files"][name]
                self.assertEqual(q.sha(path), changed["working_sha256"])
                self.assertNotEqual(changed["committed_sha256"], changed["working_sha256"])
                self.assertEqual(q.sha(engine), record["engine_sha256"])
                self.assertEqual(q.sha(cli), record["cli_sha256"])
                self.assertIn(".gitattributes", record["inputs"])
                self.assertNotEqual(original_inputs, record["inputs"])
                self.assertFalse((output / "qualification.json").exists())
                self.assertIn(name, q.source_delta(q.SOURCE_PATHS))
            path.write_bytes(original)
        self.assertEqual([[str(engine.resolve()), "--version"]] * 4, version_commands)

    def test_deleted_import_preserves_refusal_when_full_inventory_is_unavailable(self):
        (self.root / IMPORT_PATHS[0]).unlink()
        with patch.object(q, "ROOT", self.root):
            dirty = q.source_delta(q.SOURCE_PATHS)
            evidence = q.retain_source_refusal(Path(self.folder.name) / "deleted", dirty, Path("missing-engine"), Path("missing-cli"))
        record = json.loads(evidence.read_text())
        self.assertIs(record["passed"], False)
        self.assertIsNone(record["changed_files"][IMPORT_PATHS[0]]["working_sha256"])
        self.assertIsNotNone(record["changed_files"][IMPORT_PATHS[0]]["committed_sha256"])
        self.assertIsNone(record["inputs"])
        self.assertIn(IMPORT_PATHS[0].split("/")[-1], record["source_input_inventory_error"])

    def test_porcelain_only_change_and_rename_retain_exact_refused_paths(self):
        original_check_output = subprocess.check_output
        status = " M " + IMPORT_PATHS[0] + "\0"
        def command_output(command, **kwargs):
            if command[:4] == ["git", "status", "--porcelain=v1", "-z"]:
                return status.encode()
            return original_check_output(command, **kwargs)
        self.assertEqual(b"", self.git("diff", "--name-only", "HEAD"))
        with patch.object(q, "ROOT", self.root), patch.object(q.subprocess, "check_output", side_effect=command_output):
            evidence = q.retain_source_refusal(Path(self.folder.name) / "porcelain-only", status[:-1], Path("missing"), Path("missing"))
        record = json.loads(evidence.read_text())
        self.assertEqual(status, record["porcelain_status"])
        item = record["changed_files"][IMPORT_PATHS[0]]
        self.assertEqual(item["committed_sha256"], item["working_sha256"])
        self.assertIs(record["passed"], False)
        self.git("mv", "godot/scripts/example.gd", "godot/scripts/renamed.gd")
        with patch.object(q, "ROOT", self.root):
            evidence = q.retain_source_refusal(Path(self.folder.name) / "renamed", q.source_delta(q.SOURCE_PATHS), Path("missing"), Path("missing"))
        record = json.loads(evidence.read_text())
        self.assertIsNone(record["changed_files"]["godot/scripts/example.gd"]["working_sha256"])
        self.assertIsNone(record["changed_files"]["godot/scripts/renamed.gd"]["committed_sha256"])
        self.assertEqual(record["changed_files"]["godot/scripts/example.gd"]["committed_sha256"],
                         record["changed_files"]["godot/scripts/renamed.gd"]["working_sha256"])

    def prior_fixture(self):
        """Synthetic completed-run metadata, never a runtime acceptance claim."""
        prior = Path(self.folder.name) / "prior"
        prior.mkdir()
        engine, cli = Path(self.folder.name) / "godot", Path(self.folder.name) / "cli"
        engine.write_bytes(b"engine fixture");cli.write_bytes(b"native fixture")
        with patch.object(q, "ROOT", self.root):
            native, rapier = q.native_paths()
            for path in (native, rapier):
                path.parent.mkdir(parents=True, exist_ok=True);path.write_bytes(b"runtime fixture")
            identity = {"source": q.git("rev-parse", "HEAD"), "tree": q.git("rev-parse", "HEAD^{tree}"),
                "platform": sys.platform, "development": False, "source_delta": q.source_delta(q.SOURCE_PATHS),
                "inputs": q.source_inputs(), "engine_sha256": q.sha(engine), "cli_sha256": q.sha(cli),
                "native_sha256": q.sha(native), "rapier_sha256": q.sha(rapier)}
        results = []
        for name, script in [("import", "")] + [(name, script) for name, script, _, _, _ in q.CASES]:
            log = prior / (name + ".log");log.write_bytes(("synthetic completed case " + name).encode())
            results.append({"name": name, "script": script, "passed": True, "errors": [], "returncode": 0,
                            "timed_out": False, "child_reaped": True, "log_sha256": q.sha(log)})
        qualification = {"identity": identity, "passed": True, "inputs_unchanged": True, "results": results}
        self.write_prior(prior, identity, qualification)
        return prior, engine, cli, native, rapier, identity, qualification

    def write_prior(self, prior, identity, qualification):
        for name, value in (("identity", identity), ("qualification", qualification)):
            (prior / (name + ".json")).write_text(json.dumps(value), encoding="utf-8")
        (prior / "qualification-integrity.json").write_text(json.dumps({"schema": 1, "source": identity["source"],
            "identity_sha256": q.sha(prior / "identity.json"), "qualification_sha256": q.sha(prior / "qualification.json")}), encoding="utf-8")

    def recheck(self, prior, output, engine, cli):
        with patch.object(q, "ROOT", self.root), redirect_stdout(io.StringIO()):
            code = q.recheck_preservation(prior, output, engine, cli)
        result = json.loads((output / "identity-recheck.json").read_text())
        self.assertEqual(code == 0, result["passed"])
        return result

    def test_final_recheck_accepts_exact_completed_custody_without_test_rerun(self):
        prior, engine, cli, _, _, _, _ = self.prior_fixture()
        original_check_output = subprocess.check_output
        def git_only(command, **kwargs):
            self.assertEqual("git", command[0], "identity-only recheck must not launch Godot or the native CLI")
            return original_check_output(command, **kwargs)
        output = Path(self.folder.name) / "recheck"
        with patch.object(q, "ROOT", self.root), patch.object(q.subprocess, "check_output", side_effect=git_only), patch.object(sys, "argv", ["qualification", "--godot", str(engine), "--cli", str(cli), "--output", str(output), "--recheck", str(prior)]), redirect_stdout(io.StringIO()):
            self.assertEqual(0, q.main())
        self.assertIs(json.loads((output / "identity-recheck.json").read_text())["passed"], True)

    def test_final_recheck_rejects_changed_source_attributes_and_all_runtimes(self):
        prior, engine, cli, native, rapier, _, _ = self.prior_fixture()
        for index, path in enumerate([self.root / IMPORT_PATHS[0], self.root / "godot/example.svg",
                                     self.root / "godot/scripts/example.gd", self.root / ".gitattributes", engine, cli, native, rapier]):
            original = path.read_bytes();path.write_bytes(original + b"changed\n")
            result = self.recheck(prior, Path(self.folder.name) / ("changed-" + str(index)), engine, cli)
            self.assertFalse(result["passed"], str(path))
            self.assertTrue(result["errors"], str(path))
            path.write_bytes(original)
        native.unlink()
        self.assertFalse(self.recheck(prior, Path(self.folder.name) / "missing-runtime", engine, cli)["passed"])

    def test_final_recheck_rejects_stale_missing_or_altered_prior_completion(self):
        prior, engine, cli, _, _, identity, qualification = self.prior_fixture()
        for name in ("identity", "qualification", "qualification-integrity"):
            path = prior / (name + ".json");original = path.read_bytes();path.unlink()
            self.assertFalse(self.recheck(prior, Path(self.folder.name) / ("missing-" + name), engine, cli)["passed"])
            path.write_bytes(original)
        log = prior / "import.log";original = log.read_bytes();log.write_bytes(original + b"changed")
        self.assertFalse(self.recheck(prior, Path(self.folder.name) / "changed-log", engine, cli)["passed"])
        log.write_bytes(original)
        path = prior / "qualification.json";path.write_text(json.dumps(dict(qualification, extra="changed")))
        self.assertFalse(self.recheck(prior, Path(self.folder.name) / "changed-prior-bytes", engine, cli)["passed"])
        mutations = [lambda i, r: r.update(passed=False), lambda i, r: r["results"].pop(),
                     lambda i, r: r["results"][0].update(child_reaped=False),
                     lambda i, r: i.update(source="0"*40), lambda i, r: i.update(tree="0"*40),
                     lambda i, r: i.update(development=True), lambda i, r: i["inputs"].pop(".gitattributes")]
        for index, change in enumerate(mutations):
            revised_identity, revised = copy.deepcopy(identity), copy.deepcopy(qualification)
            revised["identity"] = revised_identity
            change(revised_identity, revised)
            self.write_prior(prior, revised_identity, revised)  # Fresh checksums cannot hide semantic refusal.
            self.assertFalse(self.recheck(prior, Path(self.folder.name) / ("prior-invalid-" + str(index)), engine, cli)["passed"])


class CompletionTests(unittest.TestCase):
    def test_complete_real_reports_and_no_duplicate_completion(self):
        line = 'SWARM004_CONTROLS {"checks":280,"failures":[],"completed":true}'
        self.assertEqual(q.completion(line, "SWARM004_CONTROLS")["checks"], 280)
        for invalid in ("", line + "\n" + line, line.replace('true', 'false'), line.replace('[]', '["failed"]'), line.replace('280', '0')):
            with self.assertRaises(ValueError):
                q.completion(invalid, "SWARM004_CONTROLS")

    def test_native_architecture_and_real_water_completion_are_required(self):
        arch = 'ARCHITECTURE_RESULTS phase=native checks=300 failures=0 complete=true'
        self.assertEqual(q.completion(arch, "ARCHITECTURE_RESULTS")["checks"], 300)
        with self.assertRaises(ValueError):
            q.completion(arch.replace('true', 'false'), "ARCHITECTURE_RESULTS")
        record = {"checks":100,"failures":[],"real_workbench":True,"sections":dict.fromkeys(q.WATER_SECTIONS, True)}
        water = 'WORKBENCH_WAVE_RESULT ' + json.dumps(record)
        self.assertEqual(q.completion(water, "WORKBENCH_WAVE_RESULT")["checks"], 100)
        for sections in ({}, {"activation":True}, dict.fromkeys(q.WATER_SECTIONS, False), dict.fromkeys(q.WATER_SECTIONS, 1)):
            with self.assertRaises(ValueError):
                q.completion('WORKBENCH_WAVE_RESULT ' + json.dumps(dict(record, sections=sections)), "WORKBENCH_WAVE_RESULT")

    def test_generated_uid_does_not_hide_real_untracked_or_modified_source(self):
        with patch.object(q, 'git', side_effect=[' M godot/scripts/existing.gd', 'godot/tests/generated.gd.uid\ngodot/shaders/generated.gdshader.uid\ngodot/tests/new.gd\ngodot/scenes/new.tscn']):
            delta = q.source_delta(('godot/tests', 'godot/scripts'))
        self.assertIn(' M godot/scripts/existing.gd', delta)
        self.assertIn('?? godot/tests/new.gd', delta)
        self.assertNotIn('generated.gd.uid', delta)
        self.assertNotIn('generated.gdshader.uid', delta)
        self.assertIn('?? godot/scenes/new.tscn', delta)

    def test_mode_and_scale_cannot_substitute_for_fresh_process_reopen(self):
        paint = 'PAINT_EDITOR_WORKBENCH {"checks":12,"failures":[],"reopen":"1"}'
        q.completion(paint, 'PAINT_EDITOR_WORKBENCH', 'paint-reopen')
        with self.assertRaises(ValueError):
            q.completion(paint.replace('"1"', '"0"'), 'PAINT_EDITOR_WORKBENCH', 'paint-reopen')
        record = {"checks":100,"failures":[],"completed":True,"phase":"reopen","side":512,"workers":1,"canonical_bytes":524288}
        q.completion('FLATTEN_RESULT '+json.dumps(record), 'FLATTEN_RESULT', 'flatten-reopen')
        for key, value in (("phase","author"),("side",16),("workers",8),("workers",True),("canonical_bytes",512)):
            with self.assertRaises(ValueError):
                q.completion('FLATTEN_RESULT '+json.dumps(dict(record, **{key:value})), 'FLATTEN_RESULT', 'flatten-reopen')

    def test_project_and_scene_assets_are_in_source_identity(self):
        with patch.object(q, 'git', return_value='godot/project.godot\ngodot/main.tscn'), patch.object(q, 'sha', side_effect=['project-sha','scene-sha']):
            self.assertEqual(q.source_inputs(), {'godot/project.godot':'project-sha','godot/main.tscn':'scene-sha'})


if __name__ == '__main__':
    unittest.main()
