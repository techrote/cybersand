"""Offline source/request/release boundaries; no model or native execution."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from experiments.driv3r import provenance as inherited
from experiments.driv3r.stage_b import provenance


class FrozenInputsTests(unittest.TestCase):
    def test_exact_request_protocol_and_catalogs_are_bound(self):
        payload = provenance.request_payload(1)
        self.assertEqual(provenance.validate_request(payload), payload)
        frozen = provenance.frozen_inputs()
        self.assertEqual(frozen["fixture_count"], 16)
        self.assertEqual(payload["protocol_sha256"], frozen["protocol_sha256"])
        self.assertEqual(payload["catalog_sha256"], frozen["catalog_sha256"])
        self.assertEqual(frozen["cohorts"]["direct"]["counts"], {"development": 2, "held_out": 4})

    def test_scope_checkpoint_quantization_and_types_cannot_drift(self):
        payload = provenance.request_payload(1)
        for key, value in (("stage", "A"), ("training", True), ("schedules", True),
                           ("production_defaults", True), ("quantization", "Q4_K_M"),
                           ("accepted_stage_a_sha", "0"*40), ("sequence", True),
                           ("sequence", 0), ("sequence", 1001), ("protocol_sha256", "bad")):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                provenance.validate_request({**payload, key: value})
        with self.assertRaises(ValueError):
            provenance.validate_request({**payload, "permission_override": True})
        with self.assertRaises(ValueError):
            provenance.validate_request({**payload, "catalog_sha256": {}})

    def test_protocol_limit_seed_split_and_native_probe_mutations_refused(self):
        original = json.loads((provenance.ROOT / provenance.PROTOCOL_PATH).read_text())
        for key, value in (("max_model_requests", 145), ("max_campaign_seconds", 5401),
                           ("direct_max_decisions", 9), ("fuzzy_max_decisions", True)):
            data = deepcopy(original)
            data["limits"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                provenance.validate_protocol(data)
        for mutate in (lambda p: p["random_seeds"].append(573),
                       lambda p: p["held_out"].update(direct=5),
                       lambda p: p["probes"].update(no_native_execution=False),
                       lambda p: p["stage_c_gate"]["family_success"].update(direct=2)):
            data = deepcopy(original)
            mutate(data)
            with self.assertRaises(ValueError):
                provenance.validate_protocol(data)

    def test_fixture_reallocation_fails_even_with_same_number_of_cases(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for relative in (provenance.PROTOCOL_PATH, *provenance.CATALOGS):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(provenance.ROOT / relative, destination)
            path = root / provenance.CATALOGS[0]
            data = json.loads(path.read_text())
            data["cases"][0]["split"] = "held_out"
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                provenance.frozen_inputs(root)


class TriggerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.path = self.root / provenance.REQUEST_PATH
        self.path.parent.mkdir(parents=True)
        self.payload = provenance.request_payload(1)
        self.path.write_text(json.dumps(self.payload))
        self.git("init", "-q")
        self.git("config", "user.name", "synthetic-unit-fixture")
        self.git("config", "user.email", "synthetic@example.invalid")
        self.git("add", ".")
        self.git("commit", "-q", "-m", "unit first request")
        self.before = self.git("rev-parse", "HEAD")
        self.payload["sequence"] = 2
        self.path.write_text(json.dumps(self.payload))
        self.git("add", ".")
        self.git("commit", "-q", "-m", "unit second request")
        self.after = self.git("rev-parse", "HEAD")
        self.event = self.root / "push-event.json"
        self.event.write_text(json.dumps({"before": self.before, "after": self.after}))
        self.env = {"GITHUB_ACTIONS": "true", "GITHUB_EVENT_NAME": "push", "GITHUB_REF": provenance.BRANCH,
                    "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_PATH": str(self.event)}

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True,
                                       stderr=subprocess.PIPE).strip()

    def test_changed_request_with_next_sequence_is_admitted(self):
        receipt = provenance.validate_trigger(self.payload, self.after, self.root, self.env)
        self.assertEqual(receipt["previous_sequence"], 1)
        self.assertEqual(receipt["sequence"], 2)

    def test_wrong_events_branches_repositories_and_push_identity_refused(self):
        for key, value in (("GITHUB_EVENT_NAME", "pull_request"), ("GITHUB_EVENT_NAME", "schedule"),
                           ("GITHUB_REF", "refs/heads/main"), ("GITHUB_REPOSITORY", "somewhere/fork")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                provenance.validate_trigger(self.payload, self.after, self.root, {**self.env, key: value})
        with self.assertRaises(ValueError):
            provenance.validate_trigger(self.payload, "f"*40, self.root, self.env)

    def test_unchanged_request_and_skipped_sequence_are_refused(self):
        with self.assertRaises(ValueError):
            provenance.validate_trigger({**self.payload, "sequence": 3}, self.after, self.root, self.env)
        self.event.write_text(json.dumps({"before": self.after, "after": self.after}))
        with self.assertRaises(ValueError):
            provenance.validate_trigger(self.payload, self.after, self.root, self.env)

    def test_explicit_manual_rerun_does_not_require_sequence_bump(self):
        receipt = provenance.validate_trigger(self.payload, self.after, self.root,
                                              {**self.env, "GITHUB_EVENT_NAME": "workflow_dispatch"})
        self.assertEqual(receipt["event"], "workflow_dispatch")
        self.assertEqual(provenance.validate_trigger(self.payload, self.after, self.root, {})["event"],
                         "explicit_local_cli")


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.evidence = self.root / "evidence"
        self.evidence.mkdir()
        self.source = "a"*40
        self.frozen = provenance.frozen_inputs()
        self.inputs = {provenance.PROTOCOL_PATH: self.frozen["protocol_sha256"],
                       **self.frozen["catalog_sha256"], provenance.REQUEST_PATH: "c"*64}
        self.custody = {"schema": "driv3r-stage-b-source-custody-v1", "stage": "B", "source_sha": self.source,
                        "source_tree": "b"*40, "accepted_stage_a_sha": provenance.ACCEPTED_STAGE_A,
                        "source_inputs": self.inputs, "frozen_inputs": self.frozen,
                        "source_inputs_sha256": hashlib.sha256(inherited.canonical(self.inputs)).hexdigest()}
        inherited.write_json(self.evidence / "source-custody.json", self.custody)
        inherited.write_json(self.evidence / "request.json", {
            "schema": "driv3r-stage-b-request-receipt-v1", "source_sha": self.source,
            "source_tree": "b"*40, "request_sha256": "c"*64, "request": provenance.request_payload(1)})
        (self.evidence / "original-failure.json").write_text('{"status":"FAIL","raw_error":"original"}\n')
        (self.evidence / "native.png").write_bytes(b"synthetic-original-image-bytes")

    def tearDown(self):
        self.temporary.cleanup()

    def complete(self, **updates):
        inherited.write_json(self.evidence / "qualification-exit.json", {
            "schema": "driv3r-stage-b-qualification-exit-v1",
            "source_sha": self.source, "exit_code": 0, "log_capture_exit_code": 0})
        inherited.write_json(self.evidence / "execution/summary.json", {
            "schema": "driv3r-stage-b-summary-v1", "source_sha": self.source,
            "infrastructure_passed": True, "campaign_complete": True, "result": "HOLD", **updates})

    def test_failed_partial_run_is_archived_with_stage_b_identity_and_original_bytes(self):
        output = self.root / "release"
        manifest = provenance.package(self.evidence, output, self.source)
        self.assertEqual(manifest["schema"], "driv3r-stage-b-publication-v1")
        self.assertFalse(manifest["publication_eligible"])
        self.assertFalse(manifest["publication_is_acceptance"])
        self.assertTrue(manifest["draft_hold"])
        archive = output / manifest["assets"][0]["file"]
        self.assertTrue(archive.name.startswith("driv3r-stage-b-"))
        self.assertEqual(inherited.digest(archive), manifest["assets"][0]["sha256"])
        with zipfile.ZipFile(archive) as stored:
            self.assertEqual(stored.read("native.png"), (self.evidence / "native.png").read_bytes())
            self.assertEqual(json.loads(stored.read("original-failure.json"))["status"], "FAIL")
            self.assertEqual(json.loads(stored.read("EVIDENCE-INVENTORY.json")), inherited.inventory(self.evidence))

    def test_completed_safe_behavioral_hold_is_publishable_without_claiming_acceptance(self):
        self.complete()
        result = provenance.package(self.evidence, self.root / "release", self.source)
        self.assertTrue(result["publication_eligible"])
        self.assertFalse(result["publication_is_acceptance"])

    def test_diagnostic_or_incomplete_summary_is_not_publishable(self):
        for updates in ({"development": True}, {"development_only": True}, {"campaign_complete": False},
                        {"infrastructure_passed": False}, {"source_sha": "f"*40}):
            with self.subTest(updates=updates):
                for relative in ("qualification-exit.json", "execution/summary.json"):
                    (self.evidence / relative).unlink(missing_ok=True)
                self.complete(**updates)
                self.assertFalse(provenance._publication_eligible(self.evidence, self.source))

    def test_custody_stage_or_frozen_hash_substitution_cannot_be_published(self):
        for change in (lambda p: p.update(schema="driv3r-source-custody-v1"),
                       lambda p: p.update(accepted_stage_a_sha="f"*40),
                       lambda p: p["frozen_inputs"].update(protocol_sha256="f"*64)):
            custody = deepcopy(self.custody)
            change(custody)
            (self.evidence / "source-custody.json").write_text(json.dumps(custody))
            with self.assertRaises(ValueError):
                provenance.package(self.evidence, self.root / "release", self.source)

    def test_wrong_source_symlink_and_nested_or_existing_output_refused(self):
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, self.root / "release", "f"*40)
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, self.evidence / "release", self.source)
        (self.evidence / "link").symlink_to(self.evidence / "native.png")
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, self.root / "release", self.source)


class WorkflowBoundaryTests(unittest.TestCase):
    def test_only_stage_b_request_or_manual_can_start_heavy_job(self):
        import yaml
        workflow = yaml.load((provenance.ROOT / ".github/workflows/driv3r-stage-b.yml").read_text(),
                             Loader=yaml.BaseLoader)
        self.assertEqual(set(workflow["on"]), {"push", "workflow_dispatch"})
        self.assertEqual(workflow["on"]["push"]["paths"], [provenance.REQUEST_PATH])
        self.assertEqual(workflow["on"]["push"]["branches"], [provenance.BRANCH.removeprefix("refs/heads/")])
        self.assertEqual(workflow["jobs"]["qualify"]["runs-on"], "ubuntu-24.04")
        self.assertEqual(workflow["jobs"]["qualify"]["timeout-minutes"], "180")
        self.assertEqual(workflow["concurrency"]["cancel-in-progress"], "false")
        self.assertEqual(workflow["jobs"]["publish-evidence"]["needs"], "qualify")
        self.assertEqual(workflow["jobs"]["qualify"]["steps"][-1]["if"], "always()")

    def test_source_wrapper_requires_stage_b_workflow_in_inventory(self):
        inherited_custody = {"schema": "driv3r-source-custody-v1", "source_inputs": {}}
        with patch.object(inherited, "source_identity", return_value=inherited_custody), \
                patch.object(inherited, "git", return_value=""), self.assertRaises(ValueError):
            provenance.source_identity("a"*40)


if __name__ == "__main__":
    unittest.main()
