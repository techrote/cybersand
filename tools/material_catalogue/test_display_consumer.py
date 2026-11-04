"""Adverse B-reader controls using synthetic records, never runtime qualification.

Only immutable oracle/probe inputs are read from this checkout. All records,
parser stand-ins and mutations live in temporary directories. Full raw schemas
are exercised; current-source and external parser authentication are isolated so
these unit tests require neither Godot nor materialized Linux libraries.
"""
from __future__ import annotations

import contextlib
import copy
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import check_display_consumer as check


def controller_fixture(name, oracle, names, identity, facts):
    paintable, groups = oracle["paintable_ids"], oracle["group_first_ids"]
    rows = lambda ids, separator: [{"index": index, "id": ident,
                                   "text": str(ident) + separator + names[str(ident)]}
                                  for index, ident in enumerate(ids)]
    selection = {
        "paintable_ids": paintable, "group_first_ids": groups,
        "cycles": [{"id": str(ident), "direction": direction,
                    "selected": paintable[(index + direction) % len(paintable)],
                    "secondary": paintable[(index + 1) % len(paintable)], "paint_slot": 0}
                   for index, ident in enumerate(paintable) for direction in (-1, 1)],
        "unknown_cycles": [{"id": str(ident), "direction": direction,
                            "selected": paintable[direction % len(paintable)], "secondary": paintable[0]}
                           for ident in (0, 10, -1, 132, 255, -(1 << 63), (1 << 63) - 1)
                           for direction in (-1, 0, 1)],
        "group_cycles": [],
    }
    for case in oracle["cases"]:
        before = [index for index, first in enumerate(groups) if first <= int(case["id"])]
        index = before[-1] if before else 0
        for direction in (-1, 1):
            selection["group_cycles"].append({"id": case["id"], "direction": direction,
                                              "selected": groups[(index + direction) % len(groups)], "paint_slot": 0})
    transport_ids = [ident for ident in range(81) if ident != 10]
    workbench_ids = [ident for ident in range(1, 132) if ident != 10]
    titles = ("Flowing powders", "Water and erosion", "Liquid gallery", "Mercury references", "Chemistry observations")
    floors = []
    for index, ids in enumerate(check.TOWER_IDS):
        floors.append({"floor": index, "selected_floor_id": index,
                       "labels": [{"material_id": ident, "text": names[str(ident)], "selected_item_id": tube}
                                  for tube, ident in enumerate(ids)],
                       "tubes": [{"index": tube, "id": tube,
                                  "text": "%d / %s / synthetic reader fixture" % (tube + 1, names[str(ident)])}
                                 for tube, ident in enumerate(ids)]})
    hud = []
    for ident in check.HUD_IDS:
        secondary = paintable[(paintable.index(ident) + 1) % len(paintable)] if ident in paintable else paintable[0]
        fragment = names[str(ident)] if name != "main" else "P %d:%s · M %d:%s" % (ident, names[str(ident)], secondary, names[str(secondary)])
        hud.append({"id": str(ident), "material_fragment": fragment})
    return {
        "script": "res://" + check.CONTROLLERS[name],
        "script_sha256": facts["godot/" + check.CONTROLLERS[name]]["sha256"],
        "names": [{"id": case["id"], "actual": names[case["id"]]} for case in oracle["cases"]],
        "selection": selection,
        "tower": {"floor_picker": [{"index": index, "id": index, "text": "%d / %s" % (index + 1, title)}
                                    for index, title in enumerate(titles)], "floors": floors},
        "transport": {"source_items": rows(transport_ids, " "), "target_items": rows(transport_ids, " "),
                      "default_selection": {"source": 3, "target": 2},
                      "selections": [{"source": first, "target": second,
                                      "effective_heading": "Effective validated draft: %s to %s" % (names[str(first)], names[str(second)])}
                                     for first, second in zip(transport_ids, reversed(transport_ids))]},
        "workbench": {"items": rows(workbench_ids, " / "), "selections": workbench_ids,
                      "exported_material_identities": [{"id": ident, "ui_name": names[str(ident)]} for ident in [0, *workbench_ids]],
                      "runtime_identity": {**identity, "source_revision": "unavailable", "revision_status": "not-embedded"},
                      "context_scope": "synthetic copied owner context; actual workbench setup/refresh/details methods"},
        "hud": hud,
    }


def comparison_fixture(left, right, matched):
    hashes = ("bce0f4c8b4466214d43ea6fca653e0d867ea03759f22413427eff41d84366530",
              "9dead51411fdc91b280bc9118beecb071e7ce4634b49bdccfc21aeb4241a8c67")
    return {
        "matched_runtime_tick_seed": matched,
        "scope": "Necessary comparison checks only; organic user inputs are not replayed or proven matched",
        "reports": {slot: {"completed_tick": 0, "native": {"scope": "synthetic comparator input; no World execution"},
                           "observations": [], "outcome": "synthetic comparison control", "worker_count": 1,
                           "runtime_identity": identity} for slot, identity in (("A", left), ("B", right))},
        "slots": {slot: {"id": "display-probe/" + slot.lower(), "seed": 0, "recipe_version": 1,
                         "definition_hash": digest, "profile": "legacy"}
                  for slot, digest in zip(("A", "B"), hashes)},
    }


class DisplayReceiptGuards(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353b-reader-fixture-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.root = self.directory / "source"
        for relative in (check.PROBE, check.legacy.FIXTURE):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((check.ROOT / relative).read_bytes())
        self.oracle = check.load_json(self.root / check.legacy.FIXTURE)
        self.source = self.root / "checked-source.txt"
        self.source.write_text("synthetic reader fixture; no application execution\n")
        self.runtime_file = self.root / "runtime-stand-in"
        self.runtime_file.write_text("synthetic runtime bytes\n")
        self.godot, self.archive = self.directory / "editor", self.directory / "editor.zip"
        self.godot.write_text("synthetic parser bytes\n")
        self.archive.write_text("synthetic archive bytes\n")
        self.report = self.directory / "report.json"
        self.evidence = self.directory / "report.evidence"
        self.evidence.mkdir()
        self.manifests, self.identities = {}, {}
        for stage in check.STAGES:
            identity_stage = "legacy" if stage == "rollback" else stage
            facts = [{"path": "godot/" + path, "bytes": 1,
                      "sha256": check.sha((identity_stage + path).encode())} for path in check.PROBE_SCRIPTS]
            self.manifests[stage] = {"schema_id": check.SCHEMA + ".stage-sources", "schema_version": 1,
                                     "stage": stage, "source_revision": "1" * 40,
                                     "scope": "synthetic source inventory for reader tests", "source_files": facts}
            scripts = {row["path"].removeprefix("godot/"): row["sha256"] for row in facts}
            self.identities[stage] = {
                "source_revision": "1" * 40, "revision_status": "caller-supplied", "script_sha256": scripts,
                "script_set_sha256": check.sha(json.dumps(scripts, sort_keys=True, separators=(",", ":")).encode()),
                "source_scope": "listed apparatus scripts; not a full checkout manifest",
                "native_path": "res://synthetic-reader-runtime", "native_sha256": check.sha(self.runtime_file.read_bytes()),
                "material_catalogue": {"count": 132, "reserved_ids": [10],
                                       "authority": "native artifact; cell_world.gd identifies the UI mirror"},
                "platform": "Linux", "godot": check.ENGINE_VERSION,
            }
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.current = lambda root: {"checked_source": {"git_head": "1" * 40}, "fixture": check.file_fact(self.source, self.root)}
        self.runtime = lambda root: {"fixture": check.file_fact(self.runtime_file, self.root)}
        self.editor = lambda godot, archive, root: {"version": check.EDITOR_VERSION,
                                                   "executable": check.file_fact(godot, self.root),
                                                   "archive": check.file_fact(archive, self.root)}
        for name, function in (("current_source", self.current), ("runtime_custody", self.runtime),
                               ("authenticate_editor", self.editor),
                               ("stage_manifest", lambda root, stage, current: self.manifests[stage]),
                               ("runtime_identity", lambda root, stage, manifest: self.identities[stage])):
            self.stack.enter_context(patch.object(check, name, side_effect=function))
        self.document = {"schema_id": check.SCHEMA, "schema_version": 2, "status": "PASS", "mode": "runtime",
                         "scope": check.RUNTIME_SCOPE, "authority_scopes": copy.deepcopy(check.proof_scopes.AUTHORITY_SCOPES),
                         "current_source": self.current(self.root), "editor": self.editor(self.godot, self.archive, self.root),
                         "runtime": self.runtime(self.root), "allowances": check.ALLOWANCES, "stages": [], "results": [],
                         "godot_executed": True, "ui_behavior_executed": True, "b_consumer_qualified": True,
                         "world_executed": False, "physics_qualification": False,
                         "browser_or_wasm_execution": False, "pixels_qualified": False}
        raws, hashes = {}, {}
        for stage in check.STAGES:
            manifest, identity = self.manifests[stage], self.identities[stage]
            previous = check.OTHER_STAGE[stage]
            names = {case["id"]: case["expected"] for case in self.oracle["cases"]}
            if stage == "poison":
                names["2"] = check.POISON
            facts = {row["path"]: row for row in manifest["source_files"]}
            drift = copy.deepcopy(identity)
            drift["script_sha256"]["scripts/main.gd"] = "f" * 64
            drift["script_set_sha256"] = check.sha(json.dumps(drift["script_sha256"], sort_keys=True, separators=(",", ":")).encode())
            controls = {"same_identity": comparison_fixture(identity, identity, True),
                        "drifted_identity": comparison_fixture(identity, drift, False),
                        "scope": "actual comparator with synthetic capture-shaped records; no native observation or World execution"}
            if previous:
                reloaded = copy.deepcopy(self.identities[previous])
                reloaded["material_catalogue"].update({"count": 132.0, "reserved_ids": [10.0]})
                controls.update({"mixed_source": comparison_fixture(identity, reloaded, False), "other_probe_sha256": hashes[previous]})
            checks = check.expected_checks(previous is not None)
            raw = {"schema_id": check.RAW_SCHEMA, "schema_version": 1, "godot": check.ENGINE_VERSION,
                   "platform": "Linux", "display_server": "headless", "browser_or_wasm_execution": False,
                   "scope": "Actual detached Main and inherited Web scripts, real UI methods and synthetic UI context; no World tick or rendered-pixel claim",
                   "oracle_sha256": check.sha((self.root / check.legacy.FIXTURE).read_bytes()),
                   "probe_sha256": check.sha((self.root / check.PROBE).read_bytes()),
                   "controllers": {name: controller_fixture(name, self.oracle, names, identity, facts) for name in check.CONTROLLERS},
                   "runtime_identity": identity, "loaded_scripts": {path: facts["godot/" + path]["sha256"] for path in check.PROBE_SCRIPTS},
                   "comparison_controls": controls, "assertions": sum(checks.values()), "checks": checks,
                   "failures": [{"scope": name + "/names", "assertion": "material_name(2)", "actual": check.POISON, "expected": "sand"}
                                for name in check.CONTROLLERS] if stage == "poison" else [],
                   "status": "FAIL" if stage == "poison" else "PASS"}
            raw_path, source_path = self.evidence / (stage + ".raw.json"), self.evidence / (stage + ".sources.json")
            raw_path.write_bytes(check.canonical(raw))
            source_path.write_bytes(check.canonical(manifest))
            row = {"stage": stage, "raw_report": check.file_fact(raw_path, self.directory),
                   "source_manifest": check.file_fact(source_path, self.directory)}
            for operation in ("import", "probe"):
                stdout, stderr = (self.evidence / (stage + "." + operation + "." + stream + ".log") for stream in ("stdout", "stderr"))
                marker = "MATERIAL_DISPLAY_PROBE: %d assertions; %d failures; Linux; inherited Web is host-platform controller execution\n" % (raw["assertions"], len(raw["failures"]))
                stdout.write_text(marker if operation == "probe" else "synthetic import fixture\n")
                stderr.write_text("")
                row[operation] = {"command": check.recipe(stage, operation, manifest["source_revision"]),
                                  "exit_code": int(stage == "poison" and operation == "probe"),
                                  "timeout_seconds": check.ALLOWANCES[operation + "_seconds"], "seconds": 0.01,
                                  "stdout": check.file_fact(stdout, self.directory), "stderr": check.file_fact(stderr, self.directory)}
            self.document["stages"].append(row)
            self.document["results"].append({"stage": stage, "assertions": raw["assertions"], "failures": len(raw["failures"]),
                                              "script_set_sha256": identity["script_set_sha256"], "status": raw["status"]})
            raws[stage], hashes[stage] = raw, check.sha(raw_path.read_bytes())
        self.write_report()

    def write_report(self):
        self.report.write_bytes(check.canonical(self.document))

    def verify(self):
        return check.verify(self.report, self.root)

    def mutate_raw(self, stage, mutation):
        path = self.evidence / (stage + ".raw.json")
        raw = check.load_json(path)
        mutation(raw)
        path.write_bytes(check.canonical(raw))
        self.document["stages"][check.STAGES.index(stage)]["raw_report"] = check.file_fact(path, self.directory)
        self.write_report()

    def test_complete_synthetic_bundle_exercises_reader_without_qualifying_runtime(self):
        before = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in self.directory.rglob("*") if path.is_file()}
        self.assertEqual(self.verify()["status"], "PASS")
        self.assertEqual(before, {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in before})

    def test_v1_native_and_static_receipts_are_not_current_b_proof(self):
        original = copy.deepcopy(self.document)
        for field, bad in (("schema_version", 1), ("schema_version", True), ("schema_id", "cybersand.material-catalogue.native-parity"),
                           ("mode", "static"), ("b_consumer_qualified", False), ("ui_behavior_executed", 1),
                           ("godot_executed", False), ("world_executed", True), ("physics_qualification", True),
                           ("browser_or_wasm_execution", True), ("pixels_qualified", True)):
            with self.subTest(field=field, bad=bad):
                self.document = copy.deepcopy(original)
                self.document[field] = bad
                self.write_report()
                with self.assertRaises(ValueError):
                    self.verify()

    def test_each_stage_and_exact_order_are_mandatory(self):
        original = copy.deepcopy(self.document)
        for stage in check.STAGES:
            self.document = copy.deepcopy(original)
            self.document["stages"] = [row for row in self.document["stages"] if row["stage"] != stage]
            self.write_report()
            with self.subTest(stage=stage), self.assertRaisesRegex(ValueError, "all four"):
                self.verify()
        self.document = original
        self.document["stages"].reverse()
        self.write_report()
        with self.assertRaisesRegex(ValueError, "stage order"):
            self.verify()

    def test_controller_schema_names_ui_scopes_and_fingerprints_fail_closed(self):
        mutations = {
            "missing Web controller": lambda raw: raw["controllers"].pop("inherited_web_controller"),
            "extra controller": lambda raw: raw["controllers"].update({"alias": {}}),
            "missing name": lambda raw: raw["controllers"]["main"]["names"].pop(),
            "numeric signed64 ID": lambda raw: raw["controllers"]["main"]["names"][0].update({"id": 0}),
            "ID10 becomes invalid": lambda raw: raw["controllers"]["main"]["names"][10].update({"actual": "invalid"}),
            "LED case": lambda raw: raw["controllers"]["main"]["names"][80].update({"actual": "led white"}),
            "missing workbench": lambda raw: raw["controllers"]["main"].pop("workbench"),
            "exported ui_name": lambda raw: raw["controllers"]["inherited_web_controller"]["workbench"]["exported_material_identities"][2].update({"ui_name": "unused preload"}),
            "transport count": lambda raw: raw["controllers"]["main"]["transport"]["source_items"].pop(),
            "Tower selection": lambda raw: raw["controllers"]["main"]["tower"]["floors"][0].update({"selected_floor_id": 1}),
            "HUD": lambda raw: raw["controllers"]["main"]["hud"][0].update({"material_fragment": "wrong"}),
            "source fingerprint": lambda raw: raw["runtime_identity"].update({"script_set_sha256": "0" * 64}),
            "loaded source": lambda raw: raw["loaded_scripts"].update({"scripts/main.gd": "0" * 64}),
            "missing scope": lambda raw: raw["checks"].pop("main/tower"),
            "schema type": lambda raw: raw.update({"schema_version": True}),
            "positive failures": lambda raw: raw["failures"].append({"unexpected": "failure"}),
            "oracle mismatch": lambda raw: raw.update({"oracle_sha256": "0" * 64}),
            "mixed source eligibility": lambda raw: raw["comparison_controls"]["mixed_source"].update({"matched_runtime_tick_seed": True}),
            "nonintegral readback": lambda raw: raw["comparison_controls"]["mixed_source"]["reports"]["B"]["runtime_identity"]["material_catalogue"].update({"count": 132.5}),
        }
        original, document = (self.evidence / "candidate.raw.json").read_bytes(), copy.deepcopy(self.document)
        for label, mutation in mutations.items():
            self.document = copy.deepcopy(document)
            (self.evidence / "candidate.raw.json").write_bytes(original)
            self.mutate_raw("candidate", mutation)
            with self.subTest(control=label), self.assertRaises(ValueError):
                self.verify()

    def test_poison_must_change_and_fail_both_actual_controllers(self):
        original, document = (self.evidence / "poison.raw.json").read_bytes(), copy.deepcopy(self.document)
        for name in check.CONTROLLERS:
            for mutation in (lambda raw, name=name: raw["controllers"][name]["names"][2].update({"actual": "sand"}),
                             lambda raw, name=name: raw.update({"failures": [row for row in raw["failures"] if row["scope"] != name + "/names"]})):
                self.document = copy.deepcopy(document)
                (self.evidence / "poison.raw.json").write_bytes(original)
                self.mutate_raw("poison", mutation)
                with self.subTest(controller=name), self.assertRaises(ValueError):
                    self.verify()

    def test_missing_tampered_and_unlisted_evidence_is_refused(self):
        for suffix in ("raw.json", "sources.json", "probe.stdout.log", "import.stderr.log"):
            path = self.evidence / ("candidate." + suffix)
            before = path.read_bytes()
            for action in ("delete", "change"):
                path.unlink() if action == "delete" else path.write_bytes(before + b"changed")
                with self.subTest(suffix=suffix, action=action), self.assertRaises((OSError, ValueError)):
                    self.verify()
                path.write_bytes(before)
        (self.evidence / "unaccounted.log").write_text("extra")
        with self.assertRaisesRegex(ValueError, "evidence inventory"):
            self.verify()

    def test_evidence_fact_cannot_redirect_to_another_file(self):
        for path in ("../outside.json", "/absolute.json", "report.evidence/rollback.raw.json"):
            self.document["stages"][1]["raw_report"]["path"] = path
            self.write_report()
            with self.assertRaisesRegex(ValueError, "evidence filename"):
                self.verify()

    def test_stale_current_source_runtime_and_parser_bytes_are_refused(self):
        for path in (self.source, self.runtime_file, self.godot, self.archive):
            before = path.read_bytes()
            path.write_bytes(before + b"changed")
            with self.subTest(path=path.name), self.assertRaises(ValueError):
                self.verify()
            path.write_bytes(before)

    def test_late_receipt_raw_parser_archive_and_source_changes_are_refused(self):
        for path in (self.report, self.evidence / "candidate.raw.json", self.godot, self.archive, self.source, self.runtime_file):
            before = path.read_bytes()
            for delete in (False, True):
                def mutate(*_args):
                    path.unlink() if delete else path.write_bytes(before + b"late change")
                    return {"status": "synthetic callback, not runtime evidence"}
                with self.subTest(path=path.name, deleted=delete), patch.object(check, "validate_bundle", side_effect=mutate):
                    with self.assertRaises((OSError, ValueError)):
                        self.verify()
                path.write_bytes(before)

    def test_engine_errors_wrong_return_code_and_missing_completion_marker_are_refused(self):
        row = self.document["stages"][1]
        path = self.evidence / "candidate.probe.stdout.log"
        before = path.read_bytes()
        for content in (before + b"ERROR: invalid execution\n", b"missing marker\n", before + before):
            path.write_bytes(content)
            row["probe"]["stdout"] = check.file_fact(path, self.directory)
            self.write_report()
            with self.assertRaises(ValueError):
                self.verify()
        path.write_bytes(before)
        row["probe"]["stdout"] = check.file_fact(path, self.directory)
        row["probe"]["exit_code"] = 1
        self.write_report()
        with self.assertRaisesRegex(ValueError, "return code"):
            self.verify()


class DisplayOutputGuards(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353b-output-fixture-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name) / "source"
        self.root.mkdir()
        self.outside = Path(temporary.name) / "outputs"
        self.outside.mkdir()
        self.input = self.outside / "input.json"
        self.input.write_text("preserve input\n")

    def test_existing_reports_directories_symlinks_and_hardlinks_are_preserved(self):
        before = (self.input.read_bytes(), self.input.stat().st_mtime_ns)
        with self.assertRaises(ValueError):
            check.report_destination(self.input, self.root)
        output = self.outside / "new.json"
        for alias in ("symlink", "hardlink"):
            output.symlink_to(self.input) if alias == "symlink" else os.link(self.input, output)
            with self.subTest(alias=alias), self.assertRaises(ValueError):
                check.report_destination(output, self.root)
            output.unlink()
        output.with_name("new.evidence").mkdir()
        with self.assertRaisesRegex(ValueError, "existing destination"):
            check.report_destination(output, self.root)
        self.assertEqual(before, (self.input.read_bytes(), self.input.stat().st_mtime_ns))

    def test_source_and_tooling_repository_output_fences(self):
        for relative in ("tools/report.json", "godot/report.json", "materials/report.json", "docs/report.json"):
            with self.subTest(path=relative), self.assertRaises(ValueError):
                check.report_destination(self.root / relative, self.root)
        with self.assertRaises(ValueError):
            check.report_destination(check.ROOT / "tools/material_catalogue/unused-test-report.json", self.root)
        output = self.root / "build/new.json"
        self.assertEqual(output, check.report_destination(output, self.root)[0])

    def test_atomic_publication_refuses_a_late_existing_file(self):
        output = self.outside / "new.json"
        check.report_destination(output, self.root)
        output.write_text("late file must survive\n")
        before = output.read_bytes()
        with self.assertRaises(FileExistsError):
            check.publish_report(output, b"new receipt\n")
        self.assertEqual(before, output.read_bytes())
        self.assertEqual([], list(self.outside.glob(".display-report-*")))

    def test_static_cli_remains_nonwriting_and_explicitly_unqualified(self):
        source = {"fixture": "static guard only"}
        with patch.object(check, "current_source", return_value=source):
            result = check.static_check(self.root)
        self.assertEqual(result["mode"], "static")
        for field in ("godot_executed", "ui_behavior_executed", "b_consumer_qualified"):
            self.assertIs(result[field], False)
        self.assertTrue(result["b_consumer_requirement"]["mandatory"])
        for arguments in (["--check", "--output", str(self.input)], ["--verify", str(self.input), "--output", str(self.input)]):
            with self.subTest(arguments=arguments), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    check.main(arguments)
                self.assertEqual(2, error.exception.code)
        self.assertEqual(b"preserve input\n", self.input.read_bytes())


if __name__ == "__main__":
    unittest.main()
