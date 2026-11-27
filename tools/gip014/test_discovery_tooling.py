"""Recovered synthetic discovery-tooling qualification controls.

These records are deliberately constructed test data. The optional exact Godot
4.7 process loads four pure modules only: no native extension, World, Workbench,
physics, or actual gameplay is exercised or credited.
"""
from __future__ import annotations

import copy
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import tempfile
import unittest

import campaign_evidence as evidence
import campaign_queue as queue
import corpus_io
import replay_identity
from owned_process import execute

ROOT = Path(__file__).resolve().parents[2]
PURE_MODULES = ("goblin_state.gd", "goblin_coverage.gd", "goblin_corpus.gd", "goblin_gameplay_oracles.gd")
TOTALS = ("attempted_records", "admitted_observed_actions", "completed_admitted_actions",
          "partial_admitted_actions", "refused_actions", "records_without_native_observation",
          "state_action_pairs", "parameter_variants", "refused_parameter_variants")


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def fingerprint(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def artificial_observation():
    return {"mounted": True, "fixture_id": "construction", "scene_identity": "synthetic-scene",
            "world_size": [512, 512], "paused": True, "tool": "Brush", "material": 2, "brush_radius": 0,
            "native": {"generation": 7, "revision": 1, "tick": 0, "paused": True, "busy": False, "failed": False},
            "undo_available": False, "redo_available": False, "selection": [0, 0, 0, 0],
            "clipboard_size": [0, 0], "actors": [], "selected_actor": 0, "pilot_actor": 0,
            "saved_authored_digest": "", "camera": {"origin": [0, 0], "size": [480, 270], "mode": "free"},
            "details_open": False, "paint_preview": {"dragging": False},
            "configuration": {"response": "DYNAMIC"}, "source": {"authored": []}}


def artificial_capture(native, cells):
    source = dict(native, paused=True, failed=False)
    return {"source_matches": True, "source_before": source, "source_after": copy.deepcopy(source),
            "region": [20, 20, 2, 2], "materials": list(cells),
            "admission": {"status": "queued", "operation_id": 11},
            "native_receipt": {"status": "completed", "kind": "capture", "backend": "CyberNativeCellWorld",
                               "operation_id": 11, "generation": source["generation"],
                               "observed_generation": source["generation"], "revision": source["revision"],
                               "tick": source["tick"]}}


def artificial_row(name, arguments=None, before=None, after=None, status="completed", accepted=True):
    first = copy.deepcopy(before if before is not None else artificial_observation())
    last = copy.deepcopy(after if after is not None else first)
    return {"action": {"id": name, "args": arguments or {}}, "before": first, "after": last,
            "status": status, "classification": "game_observation", "admission": {"accepted": accepted},
            "native_receipt": {}, "capture_before": {}, "capture_after": {}, "assertions": [],
            "semantic_sha256": "", "observation_sha256": "", "error": ""}


def artificial_fixtures(include_current=True):
    base = artificial_observation()
    rich = copy.deepcopy(base)
    rich.update(actors=[{"id": 1, "observed": True, "model": "runner", "position": [64.5, 80],
                         "authored_control": {"source": "keyboard", "enabled": True, "usable_index": -1},
                         "capabilities": {"capabilities": ["drive", "jump"]}},
                        {"id": 2, "observed": False, "model": "unobserved", "position": [0, 0]}],
                selected_actor=1, pilot_actor=1, undo_available=True, selection=[20, 20, 2, 2],
                clipboard_size=[8, 8], details_open=True, saved_authored_digest="synthetic-authored-save")
    rich["camera"] = {"origin": [63.5, -65], "size": [240, 135], "mode": "follow"}
    rich["paint_preview"]["dragging"] = True
    rich["configuration"]["response"] = "RFT"
    rich["source"]["authored"] = [{"material": 2}]
    rich["material_probe"] = {"current": True, "evidence_kind": "actual_native_material_capture",
                              "generation": 7, "revision": 1, "tick": 0, "region": [20, 20, 2, 2],
                              "counts": {"0": 1, "2": 2, "12": 1}}
    stale = copy.deepcopy(rich)
    stale["native"]["tick"] = 1
    late = copy.deepcopy(rich)
    late["native"]["tick"] = 256
    late["material_probe"]["current"] = False
    late["actors"][0]["position"] = [512, 30]
    observations = [{}, base, rich, stale, late]
    rows = [artificial_row("pause")]
    for name, arguments, tool, material in [
        ("brush", {"x": 20, "y": 20, "radius": 1}, "Brush", 2),
        ("undo", {}, "Brush", 2),
        ("redo", {}, "Brush", 2),
        ("paste", {"x": 20, "y": 20}, "Brush", 2),
        ("erase", {"x": 20, "y": 20, "radius": 1}, "Brush", 2),
        ("stroke", {"x0": 20, "y0": 20, "x1": 21, "y1": 21, "radius": 0}, "Rectangle", 2),
        ("rectangle", {"x0": 20, "y0": 20, "x1": 21, "y1": 21}, "Rectangle", 58),
    ]:
        first = copy.deepcopy(base)
        first.update(tool=tool, material=material)
        last = copy.deepcopy(first)
        last["native"]["revision"] = 2
        row = artificial_row(name, arguments, first, last)
        row["capture_before"] = artificial_capture(first["native"], [0, 0, 0, 0])
        row["capture_after"] = artificial_capture(last["native"], [material, 3, material, 0])
        row["native_receipt"] = {"status": "completed", "kind": "edit", "backend": "CyberNativeCellWorld",
                                  "generation": 7, "observed_generation": 7, "revision": 2, "tick": 0, "changed": 3}
        rows.append(row)
    running = copy.deepcopy(base)
    running["paused"] = running["native"]["paused"] = False
    running["native"]["tick"] = 5
    partial = artificial_row("live_stroke", {"x0": 20, "y0": 20, "x1": 21, "y1": 21, "radius": 0},
                             base, running, status="partial")
    rows.append(partial)
    refused = artificial_row("undo", status="refused", accepted=False)
    refused.update(classification="not_applicable", error="synthetic empty history refusal")
    rows.append(refused)
    rows.append(artificial_row("pause", before={}, after={}))
    rows.append(artificial_row("actor_place", {"model": "runner", "x": 64, "y": 80}, base, rich))
    replaced = copy.deepcopy(base)
    replaced.update(fixture_id="history_edges", scene_identity="synthetic-replacement")
    replaced["native"]["generation"] = 8
    rows.append(artificial_row("replace_fixture", {"fixture": "history_edges"}, rich, replaced))
    if include_current:
        explicit_legacy = dict(base, adapter_version=2)
        current = dict(base, adapter_version=3)
        exposed = copy.deepcopy(current)
        exposed["material_lineage"] = {"state": "simulation_exposed"}
        unsupported = dict(base, adapter_version=4)
        observations.extend([explicit_legacy, dict(base, adapter_version=2.0), current,
                             dict(base, adapter_version=3.0), exposed, unsupported,
                             dict(base, adapter_version="3"), dict(base, adapter_version=True)])
        rows.extend([artificial_row("pause", before=current, after=exposed),
                     artificial_row("pause", before=unsupported, after=unsupported)])
    return {"observations": observations, "rows": rows,
            "context": {"fixture_id": "construction", "fixture_version": 2, "fixture_sha256": "1" * 64,
                        "provenance_sha256": "2" * 64, "seed": 13, "personality": "CONTROL"}}


DRIVER = r'''extends SceneTree
const State = preload("res://goblin/goblin_state.gd")
const Coverage = preload("res://goblin/goblin_coverage.gd")
const Corpus = preload("res://goblin/goblin_corpus.gd")

func _action_validator(action: Dictionary) -> Dictionary:
    # Deliberately finite synthetic validator; it grants no gameplay authority.
    return {"ok": action.get("id") in ["pause", "brush", "undo", "redo", "paste", "erase",
        "stroke", "rectangle", "live_stroke", "actor_place", "replace_fixture"] and action.get("args") is Dictionary}

func _keys(coverage: RefCounted) -> Dictionary:
    var values: Dictionary = {}
    for dimension: String in Coverage.DIMENSIONS:
        var keys: Array = coverage._counts[dimension].keys()
        keys.sort()
        values[dimension] = keys
    return values

func _initialize() -> void:
    # The adapter supplies integral fields as actual integers. JSON decoding
    # produces floats; normalize only integral JSON numbers to that contract.
    var input: Dictionary = Corpus._canonical(JSON.parse_string(FileAccess.get_file_as_string("res://input.json")))
    var coverage: RefCounted = Coverage.new()
    var corpus: RefCounted = Corpus.new()
    var begun: bool = corpus.begin_episode(input.context)
    var states: Array = []
    var signatures: Array = []
    for observation: Dictionary in input.observations:
        states.append(State.abstract(observation))
        signatures.append(State.signature(observation))
    var per_row: Array = []
    for row: Dictionary in input.rows:
        var isolated: RefCounted = Coverage.new()
        isolated.observe(row)
        per_row.append({"summary": isolated.summary(), "keys": _keys(isolated)})
        var novelty: Dictionary = coverage.observe(row)
        corpus.observe(row, novelty)
    var exported: Dictionary = corpus.export_data()
    var imported: RefCounted = Corpus.new()
    var accepted: Dictionary = imported.import_data(exported, _action_validator)
    var imported_data: Dictionary = imported.export_data()
    var before_bad: String = JSON.stringify(imported_data, "", true)
    var bad: Dictionary = exported.duplicate(true)
    bad.records[0].actions[0].id = "external_command"
    bad.records[0].id = Corpus._entry_id(bad.records[0])
    var refused: Dictionary = imported.import_data(bad, _action_validator)
    var intact: bool = before_bad == JSON.stringify(imported.export_data(), "", true)
    var confirmed: Dictionary = exported.duplicate(true)
    confirmed.records[0].classification = "confirmed_production_gameplay_defect"
    var demoted: RefCounted = Corpus.new()
    var demotion: Dictionary = demoted.import_data(confirmed, _action_validator)
    print("GOBLIN_DISCOVERY_PARITY " + JSON.stringify({
        "evidence_kind": "deliberately_synthetic_cross_language_control", "native_gameplay_evidence": false,
        "godot_version": Engine.get_version_info(), "begun": begun,
        "states": states, "signatures": signatures, "summary": coverage.summary(), "keys": _keys(coverage),
        "per_row": per_row, "corpus": exported, "import_result": accepted, "imported_corpus": imported_data,
        "bad_corpus": bad, "bad_import_result": refused, "bad_import_transactional": intact,
        "confirmation_import": demotion, "demoted_corpus": demoted.export_data()
    }, "", true))
    quit()
'''


class CrossLanguageControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        supplied = os.environ.get("GOBLIN_PARITY_GODOT")
        if not supplied:
            raise unittest.SkipTest("Set GOBLIN_PARITY_GODOT for the exact4.7 pure GDS/Python parity gate")
        engine = Path(supplied)
        if not engine.is_file():
            raise AssertionError("GOBLIN_PARITY_GODOT must identify the qualified engine file")
        cls.fixture = artificial_fixtures()
        cls.temporary = tempfile.TemporaryDirectory(prefix="goblin-pure-parity-")
        cls.addClassCleanup(cls.temporary.cleanup)
        project = Path(cls.temporary.name)
        (project / "goblin").mkdir()
        module_hashes = {}
        for name in PURE_MODULES:
            source = ROOT / "godot/goblin" / name
            shutil.copyfile(source, project / "goblin" / name)
            module_hashes[name] = fingerprint(source)
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Goblin Synthetic Parity"\n', encoding="utf-8")
        (project / "input.json").write_bytes(encoded(cls.fixture))
        (project / "driver.gd").write_text(DRIVER, encoding="utf-8")
        environment = dict(os.environ)
        for name in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"):
            directory = project / name.lower()
            directory.mkdir()
            environment[name] = str(directory)
        result = execute([str(engine.resolve()), "--headless", "--path", str(project),
                          "--script", "res://driver.gd"], environment, project / "parity.log",
                         60, cwd=ROOT, memory_limit_mib=3072)
        log = (project / "parity.log").read_text(encoding="utf-8")
        if result["status"] != "pass":
            raise AssertionError(json.dumps(result, sort_keys=True) + "\n" + log[:12000])
        marker = "GOBLIN_DISCOVERY_PARITY "
        payloads = [json.loads(line[len(marker):]) for line in log.splitlines() if line.startswith(marker)]
        if len(payloads) != 1:
            raise AssertionError("Missing or duplicate actual GDS parity completion")
        cls.actual = payloads[0]
        version = cls.actual["godot_version"]
        if any(version.get(k) != v for k, v in {"major": 4, "minor": 7, "patch": 0,
                                                "status": "stable", "build": "official"}.items()) \
                or not str(version.get("hash", "")).startswith("5b4e0cb0f"):
            raise AssertionError("Parity requires the exact pinned Godot4.7: " + repr(version))
        if module_hashes != {name: fingerprint(project / "goblin" / name) for name in PURE_MODULES}:
            raise AssertionError("Pure source changed while executing the parity gate")
        # Keep small diagnostic identity in the enclosing qualification log.
        print("GOBLIN_SYNTHETIC_PARITY_PROCESS " + json.dumps({
            "evidence_kind": "deliberately_synthetic_control", "native_gameplay_evidence": False,
            "godot_sha256": fingerprint(engine), "module_sha256": module_hashes, "process": result}, sort_keys=True))

    def test_state_projection_and_signatures_match_independent_python(self):
        self.assertFalse(self.actual["native_gameplay_evidence"])
        expected = [evidence.state(v) for v in self.fixture["observations"]]
        self.assertEqual(self.actual["states"], expected)
        self.assertEqual(self.actual["signatures"], [evidence.digest(v) for v in expected])
        self.assertTrue(self.actual["states"][2]["material_sample"]["available"])
        self.assertFalse(self.actual["states"][3]["material_sample"]["available"])
        self.assertEqual(self.actual["states"][0]["world_size"], "unknown")

    def test_explicit_current_and_legacy_versions_have_exact_parity(self):
        states = self.actual["states"]
        self.assertEqual(states[5], states[1])
        self.assertEqual(states[6], states[1])
        self.assertEqual(states[7]["schema"], "cybersand-goblin-state-v2")
        self.assertEqual(states[7]["progress_phase"], "zero_tick")
        self.assertEqual(states[7], states[8])
        self.assertEqual(states[7], states[9])
        self.assertTrue(all(v == {"schema": "cybersand-goblin-state-unsupported",
                                  "reason": "unsupported_adapter_version"} for v in states[10:]))
        unsupported = self.actual["per_row"][-1]
        self.assertTrue(all(not keys for keys in unsupported["keys"].values()))
        self.assertEqual(unsupported["summary"]["records_without_native_observation"], 1)

    def test_all_nine_coverage_key_sets_and_counts_match(self):
        expected = evidence.coverage({"steps": self.fixture["rows"]})
        self.assertEqual(self.actual["keys"], expected["keys"])
        self.assertEqual(self.actual["summary"]["unique"], expected["unique"])
        for key in TOTALS:
            self.assertEqual(self.actual["summary"][key], expected[key], key)
        for row, actual in zip(self.fixture["rows"], self.actual["per_row"]):
            with self.subTest(action=row["action"]["id"], status=row["status"]):
                isolated = evidence.coverage({"steps": [row]})
                self.assertEqual(actual["keys"], isolated["keys"])
                for key in TOTALS:
                    self.assertEqual(actual["summary"][key], isolated[key], key)
        self.assertGreater(expected["unique"]["material_interaction"], 0)
        self.assertGreater(expected["unique"]["actor_environment"], 0)
        self.assertGreater(expected["unique"]["boundary_refusal"], 0)

    def test_selected_pair_credit_requires_its_actual_paint_operation(self):
        for row, actual in zip(self.fixture["rows"], self.actual["per_row"]):
            name = row["action"]["id"]
            if name in {"undo", "redo", "paste", "erase", "stroke", "live_stroke"}:
                self.assertEqual(actual["keys"]["tool_material"], [], name)
            if name == "brush":
                self.assertEqual(actual["keys"]["tool_material"], ["Brush:2"])
            if name == "rectangle":
                self.assertEqual(actual["keys"]["tool_material"], ["Rectangle:58"])
        unobserved = next(actual["summary"] for row, actual in zip(self.fixture["rows"], self.actual["per_row"])
                          if row["before"] == {} and row["after"] == {})
        self.assertEqual(unobserved["records_without_native_observation"], 1)
        self.assertEqual(unobserved["completed_admitted_actions"], 0)

    def test_export_import_numeric_identity_and_confirmation_demotion(self):
        corpus = self.actual["corpus"]
        self.assertTrue(self.actual["begun"])
        self.assertGreater(corpus_io.validate_corpus(corpus)["records"], 0)
        self.assertTrue(self.actual["import_result"]["ok"])
        imported = self.actual["imported_corpus"]
        self.assertEqual([r["id"] for r in imported["records"]], [r["id"] for r in corpus["records"]])
        self.assertTrue(all(r["verification"] == "imported_unverified" for r in imported["records"]))
        self.assertTrue(corpus_io.validate_corpus(imported)["valid"])
        numeric = json.loads(json.dumps(corpus), parse_int=float)
        self.assertTrue(corpus_io.validate_corpus(numeric)["valid"])
        self.assertTrue(self.actual["confirmation_import"]["ok"])
        demoted = self.actual["demoted_corpus"]["records"][0]
        self.assertEqual(demoted["classification"], "unresolved_observation")
        self.assertFalse(demoted["reusable"])

    def test_unsupported_import_is_transactionally_refused_in_both_languages(self):
        self.assertFalse(self.actual["bad_import_result"]["ok"])
        self.assertTrue(self.actual["bad_import_transactional"])
        with self.assertRaisesRegex(ValueError, "unsupported game action"):
            corpus_io.validate_corpus(self.actual["bad_corpus"])
        duplicate = copy.deepcopy(self.actual["corpus"])
        duplicate["records"].append(copy.deepcopy(duplicate["records"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            corpus_io.validate_corpus(duplicate)


class ObservationVersionControls(unittest.TestCase):
    def test_qualified_legacy_projection_and_all_nine_key_sets_remain_exact(self):
        # These values were independently recorded from the frozen 5ee reader
        # before this source change. They qualify reader compatibility only.
        fixture = artificial_fixtures(include_current=False)
        expected = ["113293f210ca4d23c9643fe257014c531f2347525f8c1cfa502b1f87d856370d",
                    "9b3327b0b0decad7edc6b802dc8e82123f93410b1b4bc81cc3b73325b3697e36",
                    "5d0f027a86b854c8e410b868d824974a03784c9b7eb6d10c915999a4a861d355",
                    "6858c91fc721f4f1bd2474ef8a4e59ee0f74683a7f0d33b9909339796517d984",
                    "86ec08262049ea3243573bd30845519b11dfb906c4a2613a7b51f67d5b52bee5"]
        self.assertEqual([evidence.digest(evidence.state(v)) for v in fixture["observations"]], expected)
        for version in (1, 2, 2.0):
            observation = dict(artificial_observation(), adapter_version=version)
            self.assertEqual(evidence.digest(evidence.state(observation)), expected[1])
            self.assertTrue(evidence.observed(observation))
        keys = evidence.coverage({"steps": fixture["rows"]})["keys"]
        self.assertEqual(hashlib.sha256(encoded(keys)).hexdigest(),
                         "8b5d6cdb06ace1ca7e2b69c4634e0816a68b604f33eff7135890055b0bef08a6")

    def test_current_zero_tick_is_not_authored_lineage_or_a_new_coverage_dimension(self):
        legacy = evidence.state(artificial_observation())
        expected = dict(legacy, schema="cybersand-goblin-state-v2", progress_phase="zero_tick")
        for version in (3, 3.0):
            observation = dict(artificial_observation(), adapter_version=version)
            self.assertEqual(evidence.state(observation), expected)
            self.assertTrue(evidence.observed(observation))
            observation["material_lineage"] = {"state": "simulation_exposed"}
            self.assertEqual(evidence.state(observation), expected)
            observation["material_lineage"] = {"state": "authored_compatible"}
            self.assertEqual(evidence.state(observation), expected)

    def test_unsupported_versions_have_no_observed_coverage(self):
        expected = {"schema": "cybersand-goblin-state-unsupported", "reason": "unsupported_adapter_version"}
        for version in (0, -1, 4, 3.5, "3", True, None, math.inf, math.nan):
            with self.subTest(version=version):
                observation = dict(artificial_observation(), adapter_version=version)
                self.assertEqual(evidence.state(observation), expected)
                self.assertFalse(evidence.observed(observation))
                result = evidence.coverage({"steps": [artificial_row("pause", before=observation, after=observation)]})
                self.assertTrue(all(not keys for keys in result["keys"].values()))
                self.assertEqual(result["admitted_observed_actions"], 0)
                self.assertEqual(result["records_without_native_observation"], 1)


class QueueCustodyControls(unittest.TestCase):
    def test_matched_plan_has_twelve_complete_equal_budget_blocks(self):
        rows = queue.episodes_for("matched")
        self.assertEqual(len(rows), 108)
        self.assertEqual(len({r["id"] for r in rows}), 108)
        self.assertEqual(rows, queue.episodes_for("matched"))
        blocks = {}
        for row in rows:
            self.assertEqual(row["cohort"], "matched")
            self.assertEqual(row["budget"], 64)
            key = row["fixture"], row["seed"], row["budget"], row["timeout_seconds"]
            blocks.setdefault(key, []).append(row["policy"])
        self.assertEqual(len(blocks), 12)
        self.assertTrue(all(Counter(modes) == Counter(queue.MODES) for modes in blocks.values()))
        self.assertEqual(sorted(r["budget"] for r in queue.episodes_for("long")), [128, 128, 256, 256, 512, 512, 1024, 1024])

    def test_all_attempt_custody_retains_missing_costs_and_rejects_mutation(self):
        with tempfile.TemporaryDirectory(prefix="goblin-queue-unit-") as directory:
            out = Path(directory)
            episode = queue.episodes_for("smoke")[0]
            attempts = []
            for number, status in ((1, "timeout"), (2, "crash")):
                target = out / episode["id"] / f"attempt-{number:02d}"
                target.mkdir(parents=True)
                result = {"episode": episode, "status": status, "classification": "infrastructure_failure",
                          "process": {"elapsed_seconds": number + 0.5, "peak_tree_rss_bytes": 1024 * number}}
                (target / "result.json").write_bytes(encoded(result))
                attempts.append({"number": number, "status": status, "result_sha256": fingerprint(target / "result.json")})
            attempts.append({"number": 3, "status": "interrupted"})
            value = {"episodes": [{"episode": episode, "status": "interrupted", "attempts": attempts}],
                     "plan": {"provenance": {}}}
            all_attempts = queue.collect_attempts(out, value, recheck=True)
            latest = queue.collect(out, value, recheck=True)
            self.assertEqual([r["attempt_number"] for r in all_attempts], [1, 2, 3])
            self.assertEqual(latest, [all_attempts[-1]])
            self.assertNotIn("process", all_attempts[-1])
            self.assertNotIn("coverage", all_attempts[-1])
            altered = out / episode["id"] / "attempt-01/result.json"
            altered.write_bytes(altered.read_bytes() + b"\n")
            with self.assertRaisesRegex(ValueError, "receipt changed"):
                queue.collect_attempts(out, value, recheck=True)

    def test_recorded_episode_identity_cannot_be_relabelled(self):
        with tempfile.TemporaryDirectory(prefix="goblin-identity-unit-") as directory:
            out = Path(directory)
            episode = queue.episodes_for("smoke")[0]
            target = out / episode["id"] / "attempt-01"
            target.mkdir(parents=True)
            wrong = dict(episode, seed=episode["seed"] + 1)
            path = target / "result.json"
            path.write_bytes(encoded({"episode": wrong, "status": "interrupted"}))
            value = {"episodes": [{"episode": episode, "attempts": [{"number": 1, "status": "interrupted",
                                                                 "result_sha256": fingerprint(path)}]}]}
            with self.assertRaisesRegex(ValueError, "identity differs"):
                queue.collect_attempts(out, value, recheck=True)

    def test_reciprocal_runtime_identity_matches_each_platform_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            reciprocal = set.union(*replay_identity.RECIPROCAL_FILES.values())
            all_names = reciprocal | replay_identity.IMPORT_DESCRIPTORS | set.union(*replay_identity.RUNTIME_FILES.values())
            for name in all_names:
                path = project / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(name.encode())
            for platform in ("linux", "windows"):
                applicable = replay_identity.RECIPROCAL_FILES[platform] | replay_identity.RUNTIME_FILES[platform] | replay_identity.IMPORT_DESCRIPTORS
                source = replay_identity.game_inputs(project, platform, all_names)
                extracted = replay_identity.game_inputs(project, platform, applicable)
                self.assertEqual(source, extracted)
                self.assertEqual(set(source), applicable)

    def test_only_the_four_declared_descriptors_allow_crlf_normalization(self):
        with tempfile.TemporaryDirectory(prefix="goblin-normalization-unit-") as directory:
            project = Path(directory)
            names = {*replay_identity.IMPORT_DESCRIPTORS, *replay_identity.RUNTIME_FILES["linux"], "probe.gd"}
            for name in names:
                path = project / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"synthetic fixture line\r\nsecond line\r\n")
            snapshot = {"files": {name: fingerprint(project / name) for name in names},
                        "normalized_import_descriptors": {
                            name: hashlib.sha256((project / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
                            for name in replay_identity.IMPORT_DESCRIPTORS}}
            before = replay_identity.game_inputs(project, "linux")
            queue.check_stage(project, snapshot)
            for name in replay_identity.IMPORT_DESCRIPTORS:
                path = project / name
                path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n"))
            queue.check_stage(project, snapshot)
            self.assertEqual(before, replay_identity.game_inputs(project, "linux"))
            descriptor = project / sorted(replay_identity.IMPORT_DESCRIPTORS)[0]
            descriptor.write_bytes(descriptor.read_bytes() + b"semantic change\n")
            with self.assertRaisesRegex(ValueError, "normalized import descriptor changed"):
                queue.check_stage(project, snapshot)
            descriptor.write_bytes(b"synthetic fixture line\nsecond line\n")
            other = project / "probe.gd"
            other.write_bytes(other.read_bytes().replace(b"\r\n", b"\n"))
            self.assertNotEqual(before, replay_identity.game_inputs(project, "linux"))
            with self.assertRaisesRegex(ValueError, "Immutable staged source changed"):
                queue.check_stage(project, snapshot)


if __name__ == "__main__":
    unittest.main()
