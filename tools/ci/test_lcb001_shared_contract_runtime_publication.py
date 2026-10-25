#!/usr/bin/env python3
"""Adversarial checks for the requested LCB-001 residual shared-contract runtime publisher."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as subject


BRANCH = "codex/lcb001-shared-contract"
WORKFLOW = "techrote/cybersand/.github/workflows/lcb001-shared-contract-runtime-publication.yml@refs/heads/" + BRANCH
RUNTIMES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
MANIFESTS = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
# An independent fixture: omitting a policy, host, LCB or Water case from the
# implementation must invalidate the otherwise passing complete receipt below.
SUCCESS_LOGS = {
    "test_liquid_solver_policy": 'LIQUID_SOLVER_POLICY: 385 assertions; 0 failures; completed={"validation":true,"default_readback":true,"refusals":11,"parity_checkpoints":5,"cysd1_defaults":true,"whole_cell_admission_parity":true,"whole_cell_overlay_refusals":true}\n',
    "test_microscenarios": "MICROSCENARIOS: 300 assertions; 0 failures\n",
    "test_microscenario_controllers": "MICROSCENARIO_CONTROLLERS: 90 assertions; 0 failures\n",
    "test_lcb_physics_contracts": "LCB physics contracts: 174 assertions, 0 failures\n",
    "test_lcb_negative_contracts": "LCB negative contracts: 74 assertions, 0 failures\n",
    "test_lcb_fixture_manifests": "LCB fixture manifests: 26 assertions, 0 failures\n",
    "test_lcb_scenario_catalogue": "LCB scenario catalogue: 27 scenarios, 774 assertions, 0 failures\n",
    "test_water_feel_integration": "WATER_FEEL_INTEGRATION: 24 policy cases + 70 scenario builds/reset/invalid/actions/RG8/authority passed default_hash=123456789\n",
    "test_lcb_pressure_reference": 'LCB_PRESSURE_REFERENCE: 250 assertions; 0 failures; completed={"native_dispatch":true,"no_fallback":true,"gas_identity":true,"gas_merge_split":true,"vent_reseal":true,"empty_only_gas":true,"quantity_ledger":true,"physical_state_hash":true,"save_roundtrip":true,"refusal_isolation":true,"default_goldens":true,"worker_parity":true}\n',
    "test_liquid_policy_worker": 'LIQUID_POLICY_WORKER: 29 assertions; 0 failures; completed={"initial":true,"explicit":true,"isolation":true,"refusals":3,"normalized":true,"no_request":true}\n',
    "test_microscenario_native_observation": "MICROSCENARIO_NATIVE_OBSERVATION: 100 assertions; 0 failures\n",
    "test_wex001_water_body_baseline": 'WEX001_SUMMARY {"schema":"wex001-summary-v1","cases":16,"shallow_control_peak_above":0,"moderate_displaced":1234,"moderate_peak_above":5678,"moderate_forbidden_peak":0,"moderate_first_forbidden_tick":-1,"moderate_body_floor_penetration":0.002,"hard_control_body_floor_penetration":0.0003,"deep_short_floor_contact":-1,"mirror_left_peak_above":7395,"mirror_right_peak_above":7395,"translated_peak_above":7395,"worker_shallow_hash":"123456789","worker_deep_hash":"234567890","observer_hash":"345678901"}\n',
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pointer(data: bytes) -> bytes:
    return ("version https://git-lfs.github.com/spec/v1\n"
            f"oid sha256:{digest(data)}\nsize {len(data)}\n").encode()


class RepositoryFixture(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.root = self.directory / "source"
        self.root.mkdir()
        self.git("init", "--quiet")
        self.git("config", "user.name", "Publisher guard fixture")
        self.git("config", "user.email", "publisher-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in ["README.md", *RUNTIMES.values(), *MANIFESTS.values(), subject.REQUEST, subject.EVIDENCE, *["godot/tests/" + name + ".gd" for name in SUCCESS_LOGS]]:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            content = json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1)) + "\n" if relative == subject.REQUEST else "original\n"
            path.write_text(content, encoding="utf-8", newline="\n")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Original source")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        self.args = argparse.Namespace(source_sha=self.source)
        patch = mock.patch.object(subject, "ROOT", self.root)
        patch.start()
        self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + BRANCH, "GITHUB_WORKFLOW_REF": WORKFLOW,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start()
        self.addCleanup(patch.stop)

    def git(self, *arguments: str, input: bytes | None = None) -> bytes:
        return subprocess.check_output(["git", "-C", str(self.root), *arguments], input=input, stderr=subprocess.PIPE)


class ContextTests(RepositoryFixture):
    def test_exact_feature_push_is_admitted(self):
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)

    def test_other_repo_branch_event_workflow_or_head_is_rejected(self):
        mutations = {
            "GITHUB_REPOSITORY": "someone/cybersand",
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_EVENT_NAME": "pull_request",
            "GITHUB_WORKFLOW_REF": WORKFLOW.replace("lcb001-shared-contract-runtime", "gen007-runtime"),
            "GITHUB_SHA": "f" * 40,
            "GITHUB_RUN_ATTEMPT": "0",
        }
        for key, value in mutations.items():
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError):
                    subject.context(self.source)

    def test_changed_remote_branch_is_refused_without_altering_checkout(self):
        remote = self.directory / "remote.git"
        subprocess.run(["git", "clone", "--quiet", "--bare", str(self.root), str(remote)], check=True, capture_output=True)
        remote_git = ["git", "--git-dir", str(remote)]
        subprocess.run([*remote_git, "update-ref", "refs/heads/" + BRANCH, self.source], check=True)
        self.git("remote", "add", "origin", str(remote))
        subject.check_source(self.args)
        changed = subprocess.check_output([
            *remote_git, "-c", "user.name=Remote fixture", "-c", "user.email=fixture@example.invalid",
            "commit-tree", self.source + "^{tree}", "-p", self.source,
        ], input=b"Concurrent source change\n").decode().strip()
        subprocess.run([*remote_git, "update-ref", "refs/heads/" + BRANCH, changed], check=True)
        with self.assertRaisesRegex(RuntimeError, "Feature branch changed"):
            subject.check_source(self.args)
        self.assertEqual(self.git("rev-parse", "HEAD").decode().strip(), self.source)



class SharedContractAdmissionTests(RepositoryFixture):
    def test_unarmed_publisher_refuses_before_remote_or_build_work(self):
        (self.root / subject.REQUEST).unlink()
        with mock.patch.object(subject, "git", wraps=subject.git) as git:
            with self.assertRaisesRegex(RuntimeError, "Missing explicit shared-contract publish request"):
                subject.check_source(self.args)
        self.assertFalse(any(call.args[0] == "ls-remote" for call in git.call_args_list))

    def test_request_is_bound_to_original_source(self):
        subject.require_publication_request(self.source)
        path = self.root / subject.REQUEST
        path.write_text('{"scope":"not pressure"}\n', encoding="utf-8", newline="\n")
        with self.assertRaisesRegex(RuntimeError, "differs from source commit"):
            subject.require_publication_request(self.source)

    def test_missing_candidate_and_evidence_are_refused(self):
        candidate = self.root / subject.PRESSURE_CASE
        candidate.unlink()
        with self.assertRaisesRegex(RuntimeError, "regression is not implemented"):
            subject.require_publication_request(self.source)
        candidate.write_text("candidate fixture\n", encoding="utf-8", newline="\n")
        (self.root / subject.EVIDENCE).unlink()
        with self.assertRaisesRegex(RuntimeError, "evidence file is missing"):
            subject.require_publication_request(self.source)

    def test_request_sequence_must_be_a_positive_integer(self):
        path = self.root / subject.REQUEST
        for value in (0, -1, True, "2", None):
            with self.subTest(request_sequence=value):
                payload = dict(subject.REQUEST_VALUE, request_sequence=value)
                path.write_text(json.dumps(payload) + "\n", encoding="utf-8", newline="\n")
                self.git("add", "--", subject.REQUEST)
                self.git("commit", "--quiet", "-m", "Invalid request sequence fixture")
                invalid_sha = self.git("rev-parse", "HEAD").decode().strip()
                with self.assertRaisesRegex(RuntimeError, "Invalid shared-contract publish request"):
                    subject.require_publication_request(invalid_sha)

    def test_retired_or_other_scope_request_cannot_arm_this_publisher(self):
        path = self.root / subject.REQUEST
        variants = [
            dict(subject.REQUEST_VALUE, schema="lcb001-pressure-reference-publish-request-v1"),
            dict(subject.REQUEST_VALUE, scope="residual201-pressure-cache"),
            dict(subject.REQUEST_VALUE, family="inertial_flow_v1"),
            dict(subject.REQUEST_VALUE, variant="cached"),
            dict(subject.REQUEST_VALUE, intent="build-only"),
            dict(subject.REQUEST_VALUE, unexpected="extension"),
        ]
        for payload in variants:
            with self.subTest(payload=payload):
                path.write_text(json.dumps(dict(payload, request_sequence=1)) + "\n", encoding="utf-8", newline="\n")
                self.git("add", "--", subject.REQUEST)
                self.git("commit", "--quiet", "-m", "Foreign scope request fixture")
                source = self.git("rev-parse", "HEAD").decode().strip()
                with self.assertRaisesRegex(RuntimeError, "Invalid shared-contract publish request"):
                    subject.require_publication_request(source)

    def test_every_required_case_must_exist_before_build_admission(self):
        for name in SUCCESS_LOGS:
            with self.subTest(name=name):
                path = self.root / "godot/tests" / (name + ".gd")
                data = path.read_bytes()
                path.unlink()
                with self.assertRaisesRegex(RuntimeError, "regression is not implemented"):
                    subject.require_publication_request(self.source)
                path.write_bytes(data)


class InputLedgerTests(RepositoryFixture):
    def test_grammar_sources_examples_and_fixture_are_source_bound(self):
        native_inputs = {
            "native/include/cybersand/generation_grammar.hpp": b"// grammar interface\n",
            "native/src/generation_grammar.cpp": b"// grammar implementation\n",
            "godot/native_extension/generation_grammar_adapter.inc": b"// grammar adapter\n",
            "godot/native_extension/generation_grammar_inspection.inc": b"// grammar inspection\n",
            "godot/native_extension/generation_workbench_inspection.inc": b"// GEN-007 native replay\n",
            "godot/native_extension/generation_workbench_methods.inc": b"// GEN-007 immutable adoption and stages\n",
        }
        build_inputs = {
            "examples/worldgen/hierarchy-multi-district.json": b'{"example":"hierarchy"}\n',
            "examples/worldgen/schemas/grammar-v1.schema.json": b'{"schema":"grammar-v1"}\n',
            "godot/tests/test_worldgen_grammar.gd": b"# grammar adapter regression\n",
            "godot/tests/test_gen007_reactions.gd": b"# paired native reaction qualification\n",
            "examples/worldgen/gen007-deepworks.json": b'{"example":"GEN-007"}\n',
            "godot/tests/fixtures/lcb/lcb-scenario-registry.json": b'{"registry":"current"}\n',
            "godot/tests/fixtures/lcb/lcb-physics-contracts.json": b'{"contracts":"current"}\n',
            "godot/tests/fixtures/wex001_water_body_baseline.json": b'[{"id":"W0"}]\n',
        }
        for relative in subject.BUILD_EXACT:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"# pinned build fixture\n")
        for relative, data in (native_inputs | build_inputs).items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Grammar input fixture")
        source = self.git("rev-parse", "HEAD").decode().strip()
        ledgers = subject.input_ledgers(source)
        self.assertEqual(ledgers["source_inputs"], {path: digest(data) for path, data in native_inputs.items()})
        for relative, data in build_inputs.items():
            self.assertEqual(ledgers["build_inputs"][relative], digest(data))
        for relative in (
            "godot/native_extension/generation_grammar_adapter.inc",
            "examples/worldgen/hierarchy-multi-district.json",
            "godot/tests/fixtures/lcb/lcb-scenario-registry.json",
            "godot/tests/fixtures/wex001_water_body_baseline.json",
            "godot/addons/godot-rapier2d/runtime-provenance.linux.json",
            "third_party/rapier-bvh-build.lock.json",
            "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
        ):
            with self.subTest(changed=relative):
                path = self.root / relative
                original = path.read_bytes()
                path.write_bytes(original + b"changed\n")
                with self.assertRaisesRegex(RuntimeError, "Working build/test input differs from source commit"):
                    subject.input_ledgers(source)
                path.write_bytes(original)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.report = {"results": [], "log_sha256": {}}
        for name, output in {"import": "Clean import completed\n", **SUCCESS_LOGS}.items():
            self.report["results"].append({
                "name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": [],
            })
            self.write_log(name, output)

    def write_log(self, name: str, output: str):
        path = self.root / (name + ".log")
        path.write_text(output, encoding="utf-8", newline="\n")
        self.report["log_sha256"][path.name] = digest(path.read_bytes())

    def test_json_bytes_do_not_change_with_windows_text_newline_defaults(self):
        original = Path.write_text

        def windows_write_text(path, data, *args, **kwargs):
            if kwargs.get("newline") is None:
                kwargs["newline"] = "\r\n"
            return original(path, data, *args, **kwargs)

        path = self.root / "runtime-provenance.json"
        with mock.patch.object(Path, "write_text", windows_write_text):
            subject.write_json(path, {"source": "fixture", "passed": True})
        self.assertEqual(path.read_bytes(), b'{\n  "passed": true,\n  "source": "fixture"\n}\n')

    def test_complete_ordered_shared_contract_and_retained_cases_are_required(self):
        subject.verify_case_results(self.root, self.report)
        for omitted in SUCCESS_LOGS:
            with self.subTest(omitted=omitted):
                shortened = dict(self.report, results=[item for item in self.report["results"] if item["name"] != omitted])
                with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
                    subject.verify_case_results(self.root, shortened)
        reordered = dict(self.report, results=[self.report["results"][0], *reversed(self.report["results"][1:])])
        with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
            subject.verify_case_results(self.root, reordered)

    def test_duplicate_case_cannot_substitute_for_missing_case(self):
        self.report["results"][-1] = dict(self.report["results"][-2])
        with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
            subject.verify_case_results(self.root, self.report)

    def test_zero_failing_or_foreign_summaries_are_rejected(self):
        for output in (
            "LCB negative contracts: 0 assertions, 0 failures\n",
            "LCB negative contracts: 74 assertions, 1 failures\n",
            SUCCESS_LOGS["test_lcb_physics_contracts"],
            "Clean execution with no LCB assertions\n",
        ):
            with self.subTest(output=output):
                self.write_log("test_lcb_negative_contracts", output)
                with self.assertRaisesRegex(RuntimeError, "Missing successful assertion summary"):
                    subject.verify_case_results(self.root, self.report)

    def test_error_or_skip_log_cannot_hide_behind_a_passing_record(self):
        for suffix in ("SCRIPT ERROR: omitted native path\n", "SKIP no native policy\n"):
            with self.subTest(suffix=suffix):
                self.write_log("test_microscenarios", SUCCESS_LOGS["test_microscenarios"] + suffix)
                with self.assertRaisesRegex(RuntimeError, "Execution log contains an error or skip"):
                    subject.verify_case_results(self.root, self.report)

    def test_changed_log_bytes_are_rejected(self):
        (self.root / "test_lcb_fixture_manifests.log").write_text("changed\n", encoding="utf-8", newline="\n")
        with self.assertRaisesRegex(RuntimeError, "Execution log digest mismatch"):
            subject.verify_case_results(self.root, self.report)

    def test_liquid_policy_helper_sections_cannot_be_omitted_or_noops(self):
        name = "test_liquid_solver_policy"
        prefix, raw = SUCCESS_LOGS[name].split("completed=", 1)
        sections = json.loads(raw)
        mutations = [{key: value for key, value in sections.items() if key != omitted} for omitted in sections]
        mutations += [dict(sections, refusals=10), dict(sections, refusals=True), dict(sections, parity_checkpoints=0),
                      dict(sections, cysd1_defaults=False), dict(sections, validation=1), [], "done"]
        for value in mutations:
            with self.subTest(sections=value):
                self.write_log(name, prefix + "completed=" + json.dumps(value) + "\n")
                with self.assertRaisesRegex(RuntimeError, "Incomplete liquid-policy helper sections"):
                    subject.verify_case_results(self.root, self.report)
        for output in (SUCCESS_LOGS[name] + SUCCESS_LOGS[name], SUCCESS_LOGS[name].replace("385 assertions", "0 assertions"),
                       SUCCESS_LOGS[name].replace("0 failures", "2 failures")):
            with self.subTest(output=output):
                self.write_log(name, output)
                with self.assertRaises(RuntimeError):
                    subject.verify_case_results(self.root, self.report)
    def test_pressure_candidate_sections_are_all_mandatory(self):
        name = "test_lcb_pressure_reference"
        prefix, raw = SUCCESS_LOGS[name].split("completed=", 1)
        sections = json.loads(raw)
        variants = [dict(sections, gas_identity=False), dict(sections, worker_parity=0),
                    {key: value for key, value in sections.items() if key != "native_dispatch"},
                    dict(sections, no_fallback=False), [], "done"]
        for value in variants:
            with self.subTest(sections=value):
                self.write_log(name, prefix + "completed=" + json.dumps(value) + "\n")
                with self.assertRaises(RuntimeError):
                    subject.verify_case_results(self.root, self.report)

    def test_worker_policy_sections_cannot_be_omitted_or_noops(self):
        name = "test_liquid_policy_worker"
        prefix, raw = SUCCESS_LOGS[name].split("completed=", 1)
        sections = json.loads(raw)
        variants = [{key: value for key, value in sections.items() if key != omitted} for omitted in sections]
        variants += [dict(sections, refusals=2), dict(sections, refusals=True),
                     dict(sections, explicit=False), dict(sections, normalized=1), [], "done"]
        for value in variants:
            with self.subTest(sections=value):
                self.write_log(name, prefix + "completed=" + json.dumps(value) + "\n")
                with self.assertRaises(RuntimeError):
                    subject.verify_case_results(self.root, self.report)

    def test_each_assertion_case_requires_one_positive_error_free_summary(self):
        for name, original in SUCCESS_LOGS.items():
            if name in ("test_wex001_water_body_baseline", "test_water_feel_integration"):
                continue
            for output in (re.sub(r"[1-9][0-9]* assertions", "0 assertions", original, count=1),
                    original.replace("0 failures", "1 failures"), original + original):
                with self.subTest(name=name, output=output):
                    self.write_log(name, output)
                    with self.assertRaises(RuntimeError):
                        subject.verify_case_results(self.root, self.report)
            self.write_log(name, original)

    def test_wex_requires_exactly_one_complete_sixteen_case_summary(self):
        name = "test_wex001_water_body_baseline"
        original = SUCCESS_LOGS[name]
        prefix, raw = original.split(" ", 1)
        summary = json.loads(raw)
        variants = [dict(summary, cases=value) for value in (0, 15, 17, True, "16")]
        variants += [dict(summary, schema="other-summary"), {"schema":"wex001-summary-v1", "cases":16}]
        for value in variants:
            with self.subTest(summary=value):
                self.write_log(name, prefix + " " + json.dumps(value) + "\n")
                with self.assertRaisesRegex(RuntimeError, "Incomplete WEX-001"):
                    subject.verify_case_results(self.root, self.report)
        for output in (original + original, "WEX001_SUMMARY {broken}\n", original + "ERROR: failure after summary\n"):
            with self.subTest(output=output):
                self.write_log(name, output)
                with self.assertRaises(RuntimeError):
                    subject.verify_case_results(self.root, self.report)


class FocusedExecutionTests(unittest.TestCase):
    def test_all_cases_have_finite_bounds_and_preserve_discovered_flags(self):
        discovered = {name: subject.runner.Case(name, ("--script", "res://tests/" + name + ".gd"), 180, 5.0)
                      for name in SUCCESS_LOGS}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], ["import", *SUCCESS_LOGS])
        expected = {"test_liquid_solver_policy":360, "test_lcb_pressure_reference":900,
                    "test_liquid_policy_worker":360, "test_microscenario_native_observation":240,
                    "test_wex001_water_body_baseline":600}
        for case in cases[1:]:
            self.assertEqual(case.flags, discovered[case.name].flags)
            self.assertEqual(case.requires_display, discovered[case.name].requires_display)
            self.assertEqual(case.timeout, expected.get(case.name, 180))
        del discovered["test_wex001_water_body_baseline"]
        with self.assertRaisesRegex(RuntimeError, "Required focused regression is missing"):
            subject.focused_cases(discovered)

    def test_cross_os_execution_is_refused_before_bundle_or_tool_access(self):
        for platform, host in (("windows", "linux"), ("linux", "win32")):
            with self.subTest(platform=platform), mock.patch.object(subject.sys, "platform", host), \
                    mock.patch.object(subject, "verify_bundle") as verify:
                with self.assertRaisesRegex(RuntimeError, "Actual target-OS execution is required"):
                    subject.execute(argparse.Namespace(platform=platform))
                verify.assert_not_called()

    def test_selected_rapier_backport_pins_match_the_current_provenance(self):
        expected = {
            "linux":"566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a",
            "windows":"b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7",
        }
        for platform, digest in expected.items():
            with self.subTest(platform=platform):
                self.assertEqual(subject.RAPIER[platform][1], digest)
                path = subject.ROOT / "godot/addons/godot-rapier2d" / ("runtime-provenance." + platform + ".json")
                self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["sha256"], digest)


class PublicationIndexTests(RepositoryFixture):
    def setUp(self):
        super().setUp()
        for platform, relative in RUNTIMES.items():
            data = bytearray(90)
            if platform == "linux":
                data[:6] = b"\x7fELF\x02\x01"
                data[16:20] = b"\x03\x00\x3e\x00"
            else:
                data[:2] = b"MZ"
                struct.pack_into("<I", data, 60, 64)
                data[64:70] = b"PE\0\0\x64\x86"
                struct.pack_into("<H", data, 86, 0x2000)
                struct.pack_into("<H", data, 88, 0x020B)
            data = bytes(data)
            (self.root / relative).write_bytes(data)
            self.stage_blob(relative, pointer(data))
            manifest = {
                "artifact": relative, "sha256": digest(data), "size": len(data),
                "source_commit": self.source, "status": "validated-development-runtime",
            }
            manifest_path = self.root / MANIFESTS[platform]
            manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8", newline="\n")
            self.git("add", "--", MANIFESTS[platform])

    def stage_blob(self, relative: str, data: bytes, mode: str = "100644"):
        oid = self.git("hash-object", "-w", "--stdin", input=data).decode().strip()
        self.git("update-index", "--add", "--cacheinfo", mode + "," + oid + "," + relative)

    def test_complete_matching_four_path_publication_is_admitted(self):
        subject.check_index(self.args)

    def test_unchanged_binary_bytes_with_new_manifests_are_admitted(self):
        self.git("commit", "--quiet", "-m", "Previous runtime publication")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        self.args.source_sha = self.source
        with mock.patch.dict(os.environ, {"GITHUB_SHA": self.source}):
            for relative in MANIFESTS.values():
                path = self.root / relative
                manifest = json.loads(path.read_text())
                manifest["source_commit"] = self.source
                path.write_text(json.dumps(manifest) + "\n", encoding="utf-8", newline="\n")
                self.git("add", "--", relative)
            subject.check_index(self.args)

    def test_extra_source_edit_or_missing_manifest_is_rejected(self):
        (self.root / "README.md").write_text("unrelated edit\n", encoding="utf-8", newline="\n")
        self.git("add", "README.md")
        with self.assertRaisesRegex(RuntimeError, "only the four runtime paths"):
            subject.check_index(self.args)
        self.git("reset", "--quiet", "HEAD", "--", "README.md", MANIFESTS["windows"])
        with self.assertRaisesRegex(RuntimeError, "must update both manifests"):
            subject.check_index(self.args)

    def test_mismatched_lfs_pointer_is_rejected(self):
        self.stage_blob(RUNTIMES["linux"], pointer(b"different runtime"))
        with self.assertRaisesRegex(RuntimeError, "Staged LFS pointer differs"):
            subject.check_index(self.args)

    def test_symlink_publication_is_rejected(self):
        self.stage_blob(RUNTIMES["linux"], b"/somewhere/else", mode="120000")
        with self.assertRaisesRegex(RuntimeError, "not a regular stage-zero file"):
            subject.check_index(self.args)

    def test_changed_manifest_or_unvalidated_source_is_rejected(self):
        path = self.root / MANIFESTS["windows"]
        manifest = json.loads(path.read_text())
        manifest["status"] = "built-not-executed"
        path.write_text(json.dumps(manifest) + "\n", encoding="utf-8", newline="\n")
        with self.assertRaisesRegex(RuntimeError, "Staged manifest differs"):
            subject.check_index(self.args)
        self.git("add", "--", MANIFESTS["windows"])
        with self.assertRaisesRegex(RuntimeError, "stale or unvalidated"):
            subject.check_index(self.args)


if __name__ == "__main__":
    unittest.main()
