"""Adversarial release-reader data, never native scientific execution claims."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import reduce_recovery as reducer
from shared import load

REPLAY = load("swarm456_recovery_reducer_test_reader", "tools/swarm006/replay_finisher.py")
RUNNER = REPLAY.frozen_runner()


class OriginalRecoveryEvidence(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.case = {"fixture": "island", "profile": "industrial", "seed": 17}
        self.policy, self.rounds = "off", 2
        self.identity = "island--industrial--s17--off--r2"
        self.directory = self.root / self.identity
        self.directory.mkdir()
        self.build = {"source_commit": "a" * 40, "definition_sha256": "b" * 64, "binary": "/test-only/scientific-driver"}
        self.request = {"options": reducer.request_options(self.policy, self.rounds)}
        for owner, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0.")):
            self.request[owner] = {"source": self.build["source_commit"], "definition": prefix + self.build["definition_sha256"],
                                   "seed": 17, "profile": {"name": "industrial"}, "fixture": "island", "width": 192, "height": 112,
                                   "limits": {"work": 2_000_000, "solver_work": 4_000_000, "bytes": 16_777_216}}
        self.native = {"schema": 5, "type": "reciprocal_assembly", "source": self.build["source_commit"],
                       "input": copy.deepcopy(self.request), "status": "blocked", "can_apply": False,
                       "cells": [7, 0], "rounds": [], "joints": [],
                       "obligations": [{"state": "STILL_REQUIRED", "origin": "original_frame"}],
                       "metrics": {"still_required": 1, "frame_work": 10, "total_charged_work": 10}}
        text = json.dumps({"schema": 1, "variant": "swarm006", "status": "blocked", "can_apply": False, "joints": 0}) + "\n"
        (self.root / (self.identity + ".log")).write_text(text)
        self.row = {**self.case, "id": self.identity, "policy": self.policy, "effective_policy": self.policy,
                    "rounds": self.rounds, **copy.deepcopy(RUNNER.reduce_result(self.native)), "input_representation": "full_exact", "storage": {},
                    "execution": {"returncode": 0, "child_reaped": True, "timed_out": False, "cancelled": False,
                                  "timeout_seconds": 90, "pid": 17, "log_sha256": RUNNER.sha(self.root / (self.identity + ".log")),
                                  "argv": [self.build["binary"], "run", str(self.directory), self.build["source_commit"],
                                           "island", "industrial", "17", self.policy, "2"]}}
        self.retain_request()
        self.retain("response-native.json", self.native)

    def retain(self, name, value):
        path = self.directory / name
        path.write_text(json.dumps(value))
        path.with_name(name + ".gz").unlink(missing_ok=True)
        self.row["storage"][name] = RUNNER.compress_json(path)
        (self.directory / "storage.json").write_text(json.dumps(self.row["storage"]))

    def retain_request(self):
        self.retain("request.json", self.request)
        self.retain("request-envelope.json", {"source": self.build["source_commit"], "input": self.request})
        self.row["request_sha256"] = hashlib.sha256(RUNNER.canonical(self.request)).hexdigest()

    def validate(self):
        return reducer.validate_recovery_case(self.root, self.row, self.case, self.policy, self.rounds, self.build, RUNNER)

    def test_original_native_reduction_retains_blocked_state(self):
        result = self.validate()
        self.assertEqual(result["status"], "blocked")
        self.assertEqual(result["still_required"], 1)
        self.assertFalse(result["can_apply"])

    def test_rehashed_invalid_apply_cannot_be_admitted(self):
        self.native.update(status="invalid", can_apply=True)
        self.retain("response-native.json", self.native)
        with self.assertRaises(ValueError):
            self.validate()

    def test_rehashed_native_metrics_must_match_the_actual_summary(self):
        self.native["metrics"]["frame_work"] += 1
        self.retain("response-native.json", self.native)
        with self.assertRaisesRegex(ValueError, "summary differs"):
            self.validate()

    def test_rehashed_request_and_response_cannot_switch_the_registered_policy(self):
        self.request["options"]["supported_native_receptors"] = True
        self.native["input"] = copy.deepcopy(self.request)
        self.retain_request(); self.retain("response-native.json", self.native)
        with self.assertRaisesRegex(ValueError, "registered policy"):
            self.validate()

    def test_rehashed_response_cannot_omit_the_original_request(self):
        self.native["input"] = {}
        self.retain("response-native.json", self.native)
        with self.assertRaisesRegex(ValueError, "Native input changed"):
            self.validate()

    def test_child_status_and_exact_command_remain_required(self):
        self.row["execution"]["returncode"] = 99
        with self.assertRaisesRegex(ValueError, "original child failed"):
            self.validate()
        self.row["execution"]["returncode"] = 0
        self.row["execution"]["argv"][7] = "recovery"
        with self.assertRaisesRegex(ValueError, "native command differs"):
            self.validate()

    def test_rehashed_fail_only_log_is_not_an_execution_receipt(self):
        path = self.root / (self.identity + ".log")
        path.write_text('"FAIL"\n')
        self.row["execution"]["log_sha256"] = RUNNER.sha(path)
        with self.assertRaisesRegex(ValueError, "original completion differs"):
            self.validate()


if __name__ == "__main__":
    unittest.main()
