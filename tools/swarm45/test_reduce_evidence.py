"""Original-process fixtures and rehashed contradictory-evidence regressions.

The constructed inventories below exercise consumer contracts; they are never
represented as a native build, hosted execution or physical owner result.
"""
from __future__ import annotations

import ast
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import publication_candidate as publication
import reduce_evidence as subject
import runtime_custody as custody
import shared


MARKERS = {
    "test_assembly": "SWARM004_ASSEMBLY: PASS checks=12",
    "test_reciprocal_mosaic": "reciprocal MOSAIC tests: 4 passed, 0 failed, 12 checks",
    "test_reciprocal": "reciprocal checks=12 both=1 joints=1 complete=1",
    "test_swarm005": "SWARM005_NATIVE_PILOT: PASS tests=4/4 assertions=12",
    "test_swarm006_source": "SWARM006_SOURCE_OPPORTUNITIES: PASS tests=4/4 assertions=12",
    "test_swarm006_admission": "recovery admission tests: 4 passed, 0 failed, 12 assertions",
    "test_custody_hash": "custody hash: 12 assertions PASS",
    "test_swarm006_recovery": "SWARM006 recovery: 4 groups passed, 0 failed; 12 assertions",
    "test_workbench_authoring_patch": "WORKBENCH_AUTHORING_PATCH_NATIVE checks=12 failures=0",
}


def transport_fixture(root: Path, receipt: dict) -> dict[str, str]:
    """Complete fixed raw protocol fixture; values are synthetic test records."""
    v4 = shared.load("swarm456_transport_test_cases", "tools/swarm006/test_v4_request.py")
    logs = {}
    for version in ("v3", "v4"):
        folder = root / version
        folder.mkdir()
        source = "swarm005-v3-source-matched-regression" if version == "v3" else receipt["source_commit"]
        rows = []

        def native(label, text, apply, compact=True, supported=True, recovery=False, valid=True):
            (folder / (label + ".txt")).write_text(text)
            if not valid:
                if version == "v4":
                    refusal = "unexpected trailing reciprocal request tokens" if label == "trailing" else "reciprocal integer outside its declared range"
                    (folder / (label + ".log")).write_text(refusal + "\n")
                return None
            lines = text.splitlines()
            width, height = map(int, lines[1].split()[:2])
            parameters = dict(zip(("variation", "irregularity", "clutter", "destruction", "branching", "environment_affinity", "cohesion"),
                                  map(float, lines[3].split()[:7])))
            owners = {owner: {"source": source, "definition": prefix + receipt["native_definition_sha256"],
                      "width": width, "height": height, "seed": 605, "origin": [0, 0], "profile": {"name": lines[2], **parameters}}
                      for owner, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0."))}
            value = {"source": source, "schema": 6 if recovery else 5, "type": "reciprocal_assembly",
                "programme": "GENTEK-SWARM-006" if recovery else "GENTEK-SWARM-004",
                "identity": "gentek_swarm_006_negotiated_recovery_v1" if recovery else "gentek_swarm_004_reciprocal_assembly_v1",
                "status": "complete" if apply else "blocked", "can_apply": apply, "stop_reason": "fixture completion",
                "cells": [int(apply)] + [0] * (width * height - 1), "joints": [], "obligations": [],
                "input": {**owners, "options": {"rounds": 2, "shared_ownership": True, "compact_native_termination": bool(compact),
                    "supported_native_receptors": bool(supported), "negotiated_recovery": recovery, "recovery_offers": recovery}},
                "metrics": {"still_required": 0 if apply else 1, "frame_work": 1, "mosaic_work": 1, "solver_work": 1, "shared_work": 1},
                "rounds": [{"recovery_frontier": [], "mosaic_recovery_receipts": [], "recovery_attempts": [], "recovery_work": 0}]}
            custody.write_json(folder / (label + ".json"), value)
            if version == "v4":
                (folder / (label + ".log")).write_text(f"RECIPROCAL_REQUEST status={value['status']} joints=0 apply={int(apply)}\n")
            return value

        if version == "v3":
            for name in ("viaduct_like", "irregular_megastructure"):
                for compact, supported in ((0, 0), (1, 0), (0, 1), (1, 1)):
                    value = native(f"{name}-cap{compact}-receptor{supported}", subject.transport_request(name, compact, supported, v4),
                                   name == "irregular_megastructure" and compact == 1, compact, supported)
                    rows.append({"profile": name, "compact": compact, "supported": supported, "status": value["status"],
                                 "can_apply": value["can_apply"], "still_required": value["metrics"]["still_required"],
                                 "joints": 0, "native_material_cells": int(value["can_apply"])})
            for name in ("bad_bool", "swarm005_wrong_version", "swarm004_wrong_version", "trailing"):
                lines = subject.transport_request("irregular_megastructure", 1, 1, v4).splitlines()
                if name == "bad_bool": lines[5] = "2 1"
                elif name == "swarm005_wrong_version": lines[0] = "SWARM005 2"
                elif name == "swarm004_wrong_version": lines[0] = "SWARM004 3"
                else: lines.append("9999")
                native(name, "\n".join(lines) + "\n", False, valid=False)
            summary = rows
        else:
            for name in v4.CASES:
                off = native(name + "-v3", v4.request(name, False, True), False)
                native(name + "-v4-off", v4.request(name, False), False)
                candidate = native(name + "-v4-on", v4.request(name, True), True, recovery=True)
                native(name + "-v4-replay", v4.request(name, True), True, recovery=True)
                for label, value in (("off", off), ("on", candidate)):
                    plane = b"".join(cell.to_bytes(2, "little") for cell in value["cells"])
                    rows.append({"case": name, "recovery": label, "status": value["status"], "can_apply": value["can_apply"],
                        "stop_reason": value["stop_reason"], "native_cells": int(value["can_apply"]), "joints": 0, "obligations": 0,
                        "closure_evaluated": True, "unresolved": value["metrics"]["still_required"], "retained_obligation_unresolved": 0,
                        "material_sha256": hashlib.sha256(plane).hexdigest(), "metrics": value["metrics"]})
            for name, header, flags in (("wrong_version", "SWARM006 3", "1 1 1"), ("wrong_family", "SWARM005 4", "1 1 1"),
                                        ("bad_bool", "SWARM006 4", "1 1 2"), ("missing_bool", "SWARM006 4", "1 1"),
                                        ("trailing", "SWARM006 4", "1 1 1")):
                lines = v4.request("industrial", True).splitlines();lines[0], lines[5] = header, flags
                if name == "trailing": lines.append("999")
                native(name, "\n".join(lines) + "\n", False, valid=False)
            summary = {"source": source, "synthetic_blank_world": True, "owner_nvidia_acceptance": "pending", "rows": rows}
        custody.write_json(folder / "summary.json", summary)
        logs[version] = "\n".join(json.dumps(row) for row in rows)
    return logs


def native_fixture(root: Path) -> tuple[dict, dict]:
    names = custody.names("linux")
    receipt = {"source_commit": "a" * 40, "source_tree": "b" * 40, "platform": "linux", "build_context": {"run_id": "1"}, **names,
               "files": {name: {"sha256": hashlib.sha256(name.encode()).hexdigest(), "bytes": 1234}
                         for name in custody.expected_files("linux")},
               "build_inputs_sha256": {name: custody.canonical(custody.ROOT / name) for name in subject.TRANSPORT.values()},
               "native_definition_sha256": "d" * 64}
    transport_logs = transport_fixture(root, receipt)
    rows = []

    def process(label, text, command, **fields):
        path = root / (label + ".log")
        path.write_text(text + "\n", encoding="utf-8")
        row = {"case": label, "command": command, "process_id": 123, "returncode": 0, "timed_out": False,
               "child_reaped": True, "timeout_seconds": 180, "wall_seconds": 0.1, "passed": True,
               "validation_errors": [], "log_sha256": custody.sha(path), **fields}
        custody.write_json(root / (label + "-process.json"), row)
        rows.append(row)

    for mode in ("strict", "sanitized"):
        for name in custody.NATIVE_TESTS:
            relative = name if mode == "strict" else "sanitized/" + name
            process(mode + "-" + name, MARKERS[name], ["/runtime/" + relative], mode=mode,
                    binary_sha256=receipt["files"][relative]["sha256"])
    for label, script in subject.TRANSPORT.items():
        if label == "v1-v2-request":
            syntax = ast.parse((custody.ROOT / script).read_bytes())
            names = [(group.name, method.name) for group in syntax.body if isinstance(group, ast.ClassDef)
                     for method in group.body if isinstance(method, ast.FunctionDef) and method.name.startswith("test_")]
            text = "\n".join(name + " (__main__." + group + "." + name + ") ... ok" for group, name in names)
            text += "\nRan " + str(len(names)) + " tests in 0.1s\n\nOK"
            command = ["/python", "/source/" + script, "--binary", "/runtime/" + receipt["cli"], "-v"]
        else:
            version = "v3" if label == "v3-request" else "v4"
            text = transport_logs[version] + "\n" + ("PASS SWARM005_V3_NATIVE_SHARED: eight paired native cases and four denied malformed requests" if version == "v3"
                    else "PASS SWARM006_V4_NATIVE: four paired controls, exact replay, five malformed-request refusals")
            command = ["/python", "/source/" + script, "--exe", "/runtime/" + receipt["cli"], "--output", "/evidence/" + version]
            if version == "v4":
                command += ["--source", receipt["source_commit"]]
        process(label, text, command, binary_sha256=receipt["files"][receipt["cli"]]["sha256"],
                test_script_sha256=custody.sha(custody.ROOT / script))
    floor = {"passed": True, "ceilings": {"GLIBC": "2.34", "GLIBCXX": "3.4.30", "CXXABI": "1.3.9"}, "binaries": [], "errors": []}
    for name in (receipt["extension"], receipt["cli"]):
        log = root / (name + ".objdump-T.log")
        log.write_text("symbol (GLIBC_2.34)\nsymbol (GLIBCXX_3.4.30)\nsymbol (CXXABI_1.3.9)\n")
        floor["binaries"].append({"file": name, "sha256": receipt["files"][name]["sha256"], "passed": True,
                                 "symbol_table": log.name, "symbol_table_sha256": custody.sha(log),
                                 "maximum_imported_versions": floor["ceilings"]})
    custody.write_json(root / "linux-runtime-floor.json", floor)
    value = {key: receipt[key] for key in ("source_commit", "source_tree", "platform", "build_context")}
    value.update(schema=1, programme=custody.PROGRAMME, passed=True,
                 runtime_manifest_sha256=hashlib.sha256((json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode()).hexdigest(),
                 strict_tests=list(custody.NATIVE_TESTS), sanitizers=["address", "undefined"],
                 linux_runtime_floor=floor, results=rows)
    save_native(root, value)
    return receipt, value


def save_native(root: Path, value: dict) -> None:
    value["files_sha256"] = {name: digest for name, digest in custody.inventory(root).items() if name != "native.json"}
    custody.write_json(root / "native.json", value)


class NativeOriginalEvidence(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.receipt, self.value = native_fixture(self.root)

    def test_complete_original_inventory_fixture_passes(self):
        publication.report(self.root, "native.json", self.receipt, "native")

    def test_rehashed_failed_children_cannot_be_relabelled_passed(self):
        for field, failure in (("returncode", 99), ("timed_out", True), ("child_reaped", False),
                               ("timeout_seconds", 999), ("validation_errors", ["failed assertions"]),
                               ("binary_sha256", "f" * 64), ("command", ["/runtime/test_wrong_binary"])):
            with self.subTest(field=field):
                value = copy.deepcopy(self.value)
                value["results"][0][field] = failure
                custody.write_json(self.root / "strict-test_assembly-process.json", value["results"][0])
                save_native(self.root, value)
                with self.assertRaises(ValueError):
                    publication.report(self.root, "native.json", self.receipt, "native")
                custody.write_json(self.root / "strict-test_assembly-process.json", self.value["results"][0])

    def test_summary_cannot_replace_missing_or_different_original_process(self):
        value = copy.deepcopy(self.value)
        value["results"][0]["process_id"] += 1
        save_native(self.root, value)
        with self.assertRaisesRegex(ValueError, "differs from original process"):
            publication.report(self.root, "native.json", self.receipt, "native")
        (self.root / "strict-test_assembly-process.json").unlink()
        save_native(self.root, self.value)
        with self.assertRaisesRegex(ValueError, "not inventoried"):
            publication.report(self.root, "native.json", self.receipt, "native")

    def test_rehashed_failure_or_duplicate_marker_log_is_rejected(self):
        for text in ("FAIL no assertions ran\n", MARKERS["test_assembly"] + "\n" + MARKERS["test_assembly"] + "\n",
                     MARKERS["test_assembly"] + "\nAddressSanitizer: error\n"):
            value = copy.deepcopy(self.value)
            path = self.root / "strict-test_assembly.log"
            path.write_text(text)
            value["results"][0]["log_sha256"] = custody.sha(path)
            custody.write_json(self.root / "strict-test_assembly-process.json", value["results"][0])
            save_native(self.root, value)
            with self.assertRaisesRegex(ValueError, "suite marker"):
                publication.report(self.root, "native.json", self.receipt, "native")

    def test_unlisted_original_file_or_transport_completion_is_refused(self):
        self.value["files_sha256"].pop("v3/summary.json")
        custody.write_json(self.root / "native.json", self.value)
        with self.assertRaisesRegex(ValueError, "inventory omits"):
            publication.report(self.root, "native.json", self.receipt, "native")
        value = copy.deepcopy(self.value)
        row = value["results"][-1]
        path = self.root / "v4-request.log"
        path.write_text("four paired controls were not executed\n")
        row["log_sha256"] = custody.sha(path)
        custody.write_json(self.root / "v4-request-process.json", row)
        save_native(self.root, value)
        with self.assertRaisesRegex(ValueError, "transport marker"):
            publication.report(self.root, "native.json", self.receipt, "native")

    def test_rehashed_transport_summaries_and_native_payloads_are_reparsed(self):
        for name, mutate in (
            ("v3/summary.json", lambda _data: b"FAIL not JSON\n"),
            ("v4/summary.json", lambda data: json.dumps({**json.loads(data), "rows": json.loads(data)["rows"][:1] * 8}).encode()),
            ("v3/irregular_megastructure-cap1-receptor1.json", lambda data: json.dumps({**json.loads(data), "source": "foreign"}).encode()),
            ("v4/industrial-v4-on.json", lambda data: json.dumps({**json.loads(data), "status": "invalid", "can_apply": True}).encode()),
            ("v4/industrial-v4-on.txt", lambda data: data.replace(b"SWARM006 4", b"SWARM006 3", 1)),
        ):
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(mutate(original))
                save_native(self.root, self.value)
                with self.assertRaises(ValueError):
                    publication.report(self.root, "native.json", self.receipt, "native")
                path.write_bytes(original)
        custody.write_json(self.root / "v3/bad_bool.json", {"unexpected": "malformed request emitted output"})
        save_native(self.root, self.value)
        with self.assertRaisesRegex(ValueError, "Malformed transport request"):
            publication.report(self.root, "native.json", self.receipt, "native")

    def test_rehashed_transport_child_logs_must_match_native_completion_or_exact_refusal(self):
        success = "RECIPROCAL_REQUEST status=complete joints=0 apply=1\n"
        refusal = "reciprocal integer outside its declared range\n"
        for name, text in (
            ("industrial-v4-on", "FATAL: original transport child failed; no successful completion\n"),
            ("industrial-v4-on", "RECIPROCAL_REQUEST status=blocked joints=0 apply=1\n"),
            ("industrial-v4-on", "RECIPROCAL_REQUEST status=complete joints=5 apply=1\n"),
            ("industrial-v4-on", "RECIPROCAL_REQUEST status=complete joints=0 apply=0\n"),
            ("industrial-v4-on", success + success),
            ("industrial-v4-on", success + "FATAL: child failed after output\n"),
            ("industrial-v3", success),
            ("industrial-v4-off", success),
            ("industrial-v4-replay", refusal),
            ("bad_bool", success),
            ("missing_bool", refusal + success),
            ("wrong_version", ""),
            ("wrong_family", "unrelated failure\n"),
            ("trailing", refusal),
        ):
            with self.subTest(name=name, text=text):
                path = self.root / "v4" / (name + ".log")
                original = path.read_bytes()
                path.write_text(text)
                save_native(self.root, self.value)
                with self.assertRaisesRegex(ValueError, "Original transport child log"):
                    publication.report(self.root, "native.json", self.receipt, "native")
                path.write_bytes(original)

    def test_transport_child_logs_allow_raw_windows_line_endings(self):
        for path in (self.root / "v4").glob("*.log"):
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        save_native(self.root, self.value)
        publication.report(self.root, "native.json", self.receipt, "native")

    def test_actual_process_helper_receipt_is_accepted_and_failure_is_refused(self):
        child = shared.legacy.execute("actual-process", [sys.executable, "-c", "print('original process output')"], os.environ.copy(), self.root, 180)
        child = shared.legacy.validate_result(child, [], self.root)
        records = custody.inventory(self.root)
        self.assertEqual(subject.completed_process(self.root, records, child, "actual-process", 180), "original process output\n")
        failed = shared.legacy.execute("actual-failure", [sys.executable, "-c", "raise SystemExit(99)"], os.environ.copy(), self.root, 180)
        failed = shared.legacy.validate_result(failed, [], self.root)
        with self.assertRaisesRegex(ValueError, "did not complete"):
            subject.completed_process(self.root, custody.inventory(self.root), failed, "actual-failure", 180)


class GraphicalOriginalEvidence(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        with patch.dict(sys.modules, {"qualify_workbench": shared.legacy}):
            self.fixture = shared.load("swarm456_raw_graphical_test_fixture", "tools/swarm006/test_qualify_workbench.py")
        self.pair = {mode: self.fixture.report("reciprocal", mode) for mode in ("create", "reopen")}
        for mode, report in self.pair.items():
            report.update(historical_only=mode == "reopen", controller_phase="historical" if mode == "reopen" else "applied",
                          apply_disabled=True, undo_disabled=True)
        self.fixture.native_artifacts(self.root, self.pair["create"], True)
        plane, baseline = b"\x01\x00" * (512 * 512), bytes(512 * 512 * 2)
        plane_sha, baseline_sha = hashlib.sha256(plane).hexdigest(), hashlib.sha256(baseline).hexdigest()
        for stage in ("expected", "applied", "regenerated", "saved", "reopened"):
            (self.root / (stage + "-native.le16")).write_bytes(plane)
        for stage in ("baseline", "preview", "undone"):
            (self.root / (stage + "-native.le16")).write_bytes(baseline)
        for name in shared.legacy.CAPTURES:
            (self.root / name).write_bytes(self.fixture.synthetic_png())
        self.pair["create"]["native_planes_sha256"] = {stage: plane_sha for stage in ("expected", "applied", "regenerated", "saved")}
        self.pair["create"]["native_planes_sha256"].update({stage: baseline_sha for stage in ("baseline", "preview", "undone")})
        self.pair["reopen"]["native_planes_sha256"] = {"expected": plane_sha, "reopened": plane_sha}
        self.receipt = {"source_commit": self.fixture.SOURCE, "platform": "windows", "cli": "cli.exe",
                        "files": {"cli.exe": {"sha256": self.fixture.CLI}}}

    def validate(self):
        return subject.validate_example(self.root, "reciprocal", self.pair, self.receipt, self.fixture.TEST)

    def test_legacy_shallow_receipt_fixture_requires_transaction_witnesses(self):
        # Original reader fixtures do not establish independent transaction
        # captures or canonical native patch identity. Never invent them here.
        with self.assertRaisesRegex(ValueError, "three original transaction witnesses"):
            self.validate()

    def test_rehashed_native_changes_cannot_hide_behind_ui_passed_flags(self):
        value = json.loads((self.root / "initial-result.json").read_bytes())
        value["status"] = "blocked"
        self.fixture.rewrite_native(self.root, self.pair["create"], "initial", value)
        with self.assertRaisesRegex(ValueError, "Original native planes"):
            self.validate()


    def test_failed_inspector_reopen_or_truncated_png_is_rejected(self):
        self.pair["reopen"]["inspector_evidence"]["reopened"]["native_cell_picks"] = False
        with self.assertRaisesRegex(ValueError, "Original UI report"):
            self.validate()
        self.pair["reopen"]["inspector_evidence"]["reopened"]["native_cell_picks"] = True
        path = self.root / "native-reopened.png"
        path.write_bytes(path.read_bytes()[:24])
        with self.assertRaisesRegex(ValueError, "Original native planes"):
            self.validate()

    def test_blocked_original_cannot_claim_applied_or_saved_native_transactions(self):
        report = self.fixture.report("swarm005_viaduct", "blocked")
        report.update(historical_only=False, native_transactions={}, saved_artifacts={}, native_receipt={}, applied=False)
        self.fixture.native_artifacts(self.root, report, False)
        baseline = bytes(512 * 512 * 2)
        for stage in ("baseline", "preview"):
            (self.root / (stage + "-native.le16")).write_bytes(baseline)
        digest = hashlib.sha256(baseline).hexdigest()
        report["native_planes_sha256"] = {"baseline": digest, "preview": digest}
        (self.root / "native-unresolved.png").write_bytes(self.fixture.synthetic_png())
        validate = lambda: subject.validate_example(self.root, "swarm005_viaduct", {"blocked": report}, self.receipt, self.fixture.TEST)
        self.assertTrue(validate()["passed"])
        for key, value in (("applied", True), ("native_receipt", {"operation": "build", "changed_cells": 12}),
                           ("native_transactions", {"first_apply": {"operation": "build"}}),
                           ("saved_artifacts", {"map_sha256": "0" * 64})):
            original = report[key]
            report[key] = value
            with self.assertRaisesRegex(ValueError, "Negative native outcome claims"):
                validate()
            report[key] = original


class PreservationOriginalEvidence(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.directory = self.root / "linux-source-preservation"
        self.directory.mkdir()
        with patch.dict(sys.modules, {"qualify_workbench": shared.legacy}):
            self.owner = shared.load("swarm456_preservation_test_owner", "tools/swarm006/qualify_preserved_workbench.py")
            self.fixture = shared.load("swarm456_preservation_raw_fixture", "tools/swarm006/test_qualify_workbench.py")
        self.fixture.TEST = custody.sha(custody.ROOT / "godot" / shared.legacy.INPUT_SCRIPT)
        self.receipt = {"source_commit": self.fixture.SOURCE, "source_tree": "b" * 40, "platform": "linux", "build_context": {"run_id": "1"},
            "cli": "gentek_reciprocal", "extension": "native.so", "files": {"gentek_reciprocal": {"sha256": self.fixture.CLI}, "native.so": {"sha256": "d" * 64}},
            "build_inputs_sha256": {"godot/" + shared.legacy.INPUT_SCRIPT: custody.canonical(custody.ROOT / "godot" / shared.legacy.INPUT_SCRIPT)}}
        source_inputs = {".gitattributes": custody.sha(custody.ROOT / ".gitattributes")}
        self.addCleanup(patch.stopall)
        patch.object(self.owner, "source_inputs", return_value=source_inputs).start()
        patch.object(publication, "load", return_value=self.owner).start()
        installed = {"tools/gentek_reciprocal": self.fixture.CLI, "addons/cybersand_native/bin/native.so": "d" * 64}
        self.identity = {"source": self.receipt["source_commit"], "tree": self.receipt["source_tree"], "platform": "linux",
            "qualification_programme": custody.QUALIFICATION_PROGRAMME, "build_context": self.receipt["build_context"],
            "development": False, "source_delta": "", "inputs": source_inputs, "execution_inputs": installed,
            "native_sha256": "d" * 64, "cli_sha256": self.fixture.CLI, "engine_sha256": "e" * 64,
            "runtime_manifest_sha256": hashlib.sha256((json.dumps(self.receipt, indent=2, sort_keys=True) + "\n").encode()).hexdigest()}
        custody.write_json(self.directory / "identity.json", self.identity)
        custody.write_json(self.root / "linux-source/source-runtime-identity.json", {
            "source_commit": self.receipt["source_commit"], "build_context": self.receipt["build_context"], "godot_sha256": "e" * 64,
            "execution_layout": {"files_sha256": {"godot/" + name: digest for name, digest in installed.items()}}})
        rows = []
        for name, script, marker, _environment, timeout in (("import", "", "", {}, 180), *self.owner.CASES):
            assertions = {"completed": True, "checks": 12, "failures": []}
            if name == "input-integrity":
                folder = self.directory / name;folder.mkdir()
                assertions = self.fixture.input_fixture(folder)
                assertions.update(platform="Linux", display="headless")
            if name == "water": assertions.update(real_workbench=True, sections={key: True for key in self.owner.WATER_SECTIONS})
            if name.startswith("paint-"): assertions["reopen"] = "1" if name.endswith("reopen") else "0"
            if name.startswith("flatten-"): assertions.update(phase="reopen" if name.endswith("reopen") else "author", side=512, workers=1, canonical_bytes=524288)
            if name == "art": assertions["workers"] = 1
            text = marker + " " + json.dumps(assertions) + "\n" if marker else "original editor import\n"
            if name == "architecture": text = marker + " checks=12 failures=0 complete=true phase=native done\n"
            (self.directory / (name + ".log")).write_text(text)
            command = ["/engine", "--headless", "--path", "/project", "--script", "res://tests/" + script] if script else ["/engine", "--headless", "--path", "/project", "--editor", "--quit"]
            row = {"name": name, "script": script, "argv": command, "pid": 123, "returncode": 0, "timed_out": False,
                   "child_reaped": True, "cancelled": False, "timeout_seconds": timeout, "errors": [], "passed": True,
                   "log_sha256": custody.sha(self.directory / (name + ".log"))}
            if marker: row["assertions"] = self.owner.completion(text, marker, name)
            custody.write_json(self.directory / (name + "-process.json"), row)
            rows.append(row)
        self.value = {"identity": self.identity, "passed": True, "inputs_unchanged": True, "identity_errors": [], "results": rows}
        self.save()

    def save(self):
        custody.write_json(self.directory / "identity.json", self.identity)
        custody.write_json(self.directory / "qualification.json", self.value)
        integrity = {"schema": 1, "source": self.receipt["source_commit"], "identity_sha256": custody.sha(self.directory / "identity.json"),
                     "qualification_sha256": custody.sha(self.directory / "qualification.json")}
        custody.write_json(self.directory / "qualification-integrity.json", integrity)
        custody.write_json(self.root / "linux-source-final/identity-recheck.json", {"passed": True, "errors": [],
            "prior_source": self.receipt["source_commit"], "prior_identity_sha256": integrity["identity_sha256"],
            "prior_qualification_sha256": integrity["qualification_sha256"]})

    def test_all_original_named_completions_and_input_files_pass(self):
        publication.preservation(self.root, "linux-source", self.receipt)

    def test_rehashed_fail_log_missing_process_or_foreign_runtime_is_refused(self):
        path = self.directory / "native-authoring.log"
        path.write_text("FAIL no original assertions executed\n")
        row = self.value["results"][1]
        row["log_sha256"] = custody.sha(path)
        custody.write_json(self.directory / "native-authoring-process.json", row)
        self.save()
        with self.assertRaises(ValueError): publication.preservation(self.root, "linux-source", self.receipt)
        (self.directory / "import-process.json").unlink()
        with self.assertRaises(ValueError): publication.preservation(self.root, "linux-source", self.receipt)
        self.identity["cli_sha256"] = "f" * 64;self.save()
        with self.assertRaisesRegex(ValueError, "native/CLI identity"):
            publication.preservation(self.root, "linux-source", self.receipt)



if __name__ == "__main__":
    unittest.main()
