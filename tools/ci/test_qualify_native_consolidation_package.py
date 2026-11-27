"""Exercise extraction admission and false-green paths without a platform renderer."""
from __future__ import annotations

import json
import copy
import hashlib
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import qualify_native_consolidation_package as gate


class ExtractionQualification(unittest.TestCase):
    def test_feature_inventory_binds_current_source_and_every_selected_programme(self):
        request = {"source_commit": "1" * 40, "source_tree": "2" * 40,
                   "integrated_features": ["actor_compose", "gentek_2048", "material_audition"]}
        self.assertEqual(gate.bind_features(dict(request), request), request["integrated_features"])
        for mismatch in ({"source_commit": "4" * 40}, {"source_tree": "5" * 40},
                         {"integrated_features": []}, {"integrated_features": ["invented"]},
                         {"integrated_features": ["gentek_2048", "gentek_2048"]},
                         {"integrated_features": list(reversed(request["integrated_features"]))}):
            with self.subTest(mismatch=mismatch), self.assertRaises(ValueError):
                gate.bind_features({**request, **mismatch}, request)

    def test_native_result_requires_exactly_one_completed_assertion(self):
        record = {"checks": 9, "failures": []}
        line = "FIXTURE " + json.dumps(record)
        self.assertEqual(gate.assertions(line, "FIXTURE "), record)
        for output in ("", line + "\n" + line, 'FIXTURE {"checks":0,"failures":[]}',
                       'FIXTURE {"checks":true,"failures":[]}', 'FIXTURE {"checks":9,"failures":["World"]}'):
            with self.subTest(output=output), self.assertRaises(ValueError):
                gate.assertions(output, "FIXTURE ")
        for replacement in ("missing", "wrong"):
            with self.assertRaises(ValueError):
                gate.assertions(json.dumps(dict(record, schema=replacement)), schema="objectshard")

    def test_reopen_requires_independent_process(self):
        gate.require_distinct({"pid": 21}, {"pid": 22})
        with self.assertRaises(ValueError):
            gate.require_distinct({"pid": 21}, {"pid": 21})

    def test_profile_excludes_external_feature_and_generator_overrides(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {
                "CYBERSAND_SWARM004_CLI": "foreign.exe", "CYBERSAND_SWARM004_SOURCE": "foreign",
                "CYBERSAND_SWARM004_SHA256": "foreign", "SWARM004_UI_MODE": "blocked",
                "CYBERSAND_ACTOR_COMPOSITION_REOPEN": "1", "WB_ACTOR_CAPTURE_DIR": "foreign"}):
            path = Path(temporary)
            result = gate.isolated_environment(path, "a" * 40)
            for name in ("CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256",
                         "SWARM004_UI_MODE", "CYBERSAND_ACTOR_COMPOSITION_REOPEN", "WB_ACTOR_CAPTURE_DIR"):
                self.assertNotIn(name, result)
            self.assertEqual(result["CYBERSAND_SOURCE_REVISION"], "a" * 40)
            self.assertTrue(Path(result["APPDATA"]).is_relative_to(path))

    def test_process_receipt_uses_the_launched_pid_and_rejects_false_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            log = output / "success.log"
            receipt, content = gate.execute([sys.executable], ["-c", "import os; print(os.getpid())"],
                                            dict(os.environ), log, 20)
            self.assertEqual(receipt["pid"], int(content.strip()))
            self.assertEqual(gate.delivery.read(log.with_suffix(".process.json")), receipt)
            self.assertEqual(receipt["log_sha256"], gate.delivery.sha(log))
            for index, command in enumerate(("print('SCRIPT ERROR: fixture')", "raise SystemExit(6)")):
                with self.subTest(command=command), self.assertRaises(ValueError):
                    gate.execute([sys.executable], ["-c", command], dict(os.environ), output / f"bad-{index}.log", 20)

    def test_unlisted_script_never_launches(self):
        runtime = gate.Extraction.__new__(gate.Extraction)
        runtime.manifest = {"files_sha256": {}}
        with patch.object(gate, "execute") as launched, self.assertRaises(ValueError):
            runtime.fixture(Path("evidence"), "phase", "some_external_fixture", {}, 5)
        launched.assert_not_called()

    def joined_fixture(self, *, areas=False):
        receipt = {"source_commit": "1" * 40, "source_tree": "2" * 40, "manifest_sha256": "3" * 64,
                   "archive_sha256": "4" * 64, "run_id": "777", "run_attempt": "2"}
        request = {key: receipt[key] for key in ("source_commit", "source_tree")}
        request["integrated_features"] = ["actor_compose", "gentek_2048"] + (["persistent_areas"] if areas else [])
        lanes = {}
        for name, assigned in gate.LANES.items():
            features = [key for key in request["integrated_features"] if key in assigned]
            roster = ["import", *(key + "/" + phase for key in features for phase in gate.PHASES[key])]
            lanes[name] = {**receipt, "status": "passed", "lane": name, "integrated_features": features,
                           "feature_results": {key: {"checks": 5} for key in features},
                           "processes": {phase: {"pid": 100 + i, "returncode": 0, "log_sha256": "a" * 64}
                                         for i, phase in enumerate(roster)}, "package_manifest_sha256": receipt["manifest_sha256"]}
        return lanes, request, receipt

    def test_join_rejects_wrong_foreign_incomplete_and_duplicated_lanes(self):
        lanes, request, receipt = self.joined_fixture()
        self.assertEqual(gate.join(lanes, receipt, request)["integrated_features"], request["integrated_features"])
        for key, invalid in (("source_commit", "a" * 40), ("source_tree", "b" * 40), ("run_id", "99"),
                             ("run_attempt", "1"), ("archive_sha256", "c" * 64), ("package_manifest_sha256", "d" * 64),
                             ("status", "running"), ("lane", "worlds"), ("integrated_features", ["gentek_2048"] * 2),
                             ("feature_results", {}), ("processes", {})):
            mutated = copy.deepcopy(lanes)
            mutated["authoring"][key] = invalid
            with self.subTest(key=key), self.assertRaises(ValueError):
                gate.join(mutated, receipt, request)
        bad = copy.deepcopy(lanes)
        bad["worlds"]["processes"]["actor_compose/capacity"]["returncode"] = 1
        for records in (bad, {"worlds": lanes["worlds"]}, {"worlds": lanes["worlds"], "authoring": lanes["worlds"]}):
            with self.assertRaises(ValueError):
                gate.join(records, receipt, request)

    def test_persistent_launcher_is_bound_to_requested_programme_and_run(self):
        lanes, request, receipt = self.joined_fixture(areas=True)
        proof = {**receipt, "schema": "cybersand-mainline-persistent-launcher-v1", "status": "passed",
                 "launcher": "Open Persistent Areas.cmd", "durable_areas": 3, "revision": 2,
                 "session_id": "native-session", "renderer": "ANGLE", "exit_code": 0}
        self.assertEqual(gate.join(lanes, receipt, request, proof)["status"], "passed")
        for invalid in (None, dict(proof, durable_areas=2), dict(proof, revision=0), dict(proof, session_id=""),
                        dict(proof, manifest_sha256="b" * 64), dict(proof, run_attempt="1"), dict(proof, renderer="dummy")):
            with self.subTest(proof=invalid), self.assertRaises(ValueError):
                gate.join(lanes, receipt, request, invalid)
        with self.assertRaises(ValueError):
            gate.verify_persistent_launcher(proof, receipt, ["gentek_2048"])

    def test_delivery_binding_reads_the_manifest_from_the_actual_archive(self):
        _, request, receipt = self.joined_fixture()
        raw = json.dumps(request).encode()
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, GITHUB_RUN_ID="777", GITHUB_RUN_ATTEMPT="2"):
            archive = Path(temporary) / "package.zip"
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr(gate.delivery.MANIFEST, raw)
            receipt.update(status="passed", archive=archive.name, archive_size=archive.stat().st_size,
                           archive_sha256=gate.delivery.sha(archive), manifest_sha256=hashlib.sha256(raw).hexdigest())
            self.assertEqual(gate.bind_delivery(archive, receipt, request), request)
            for mutation in ({"archive_sha256": "f" * 64}, {"manifest_sha256": "f" * 64},
                             {"run_attempt": "9"}, {"source_commit": "f" * 40}, {"archive_size": 0}):
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    gate.bind_delivery(archive, {**receipt, **mutation}, request)


if __name__ == "__main__":
    unittest.main()
