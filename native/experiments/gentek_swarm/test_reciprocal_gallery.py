#!/usr/bin/env python3
"""Adversarial offline-audit tests; mutated records are never native evidence."""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reciprocal_gallery as gallery

BASE = None


def damage_fixture():
    """Revoke one fulfilled original required socket in a synthetic derivative."""
    value = copy.deepcopy(BASE)
    for owner in ("frame", "mosaic"):
        value["input"][owner]["profile"]["destruction"] = 0.25
    last = value["rounds"][-1]
    damage = {"frame": copy.deepcopy(last["frame"]), "mosaic": copy.deepcopy(last["mosaic"]),
              "frame_changed": 1, "mosaic_changed": 0,
              "frame_footprint_changed": 1, "mosaic_footprint_changed": 0,
              "work": 64, "reason": "synthetic audit mutation; no native success claim"}
    width = value["input"]["frame"]["width"]
    source = next(c for c in value["original_frame"]["result"]["connectors"]
                  if c["required"] and c["fulfilled"] and
                  damage["frame"]["result"]["cells"][c["a"][1] * width + c["a"][0]])
    cell = source["a"][1] * width + source["a"][0]
    for field in ("cells", "roles", "provenance"):
        damage["frame"]["result"][field][cell] = 0
    for connector in damage["frame"]["result"]["connectors"]:
        if connector["id"] == source["id"]:
            connector.update(fulfilled=False, counterpart=0, state="unresolved")
    value["damage_derivative"] = damage
    value["cells"][cell] = 0
    value["ledger"][cell] = [0] * 6
    value["obligations"].append({"connector": source["id"], "instance": source["instance"],
        "original": source["a"].copy(), "facing": source["facing"].copy(), "slot": 0,
        "origin": "damage_lost_internal", "foreign_joined": False, "local_terminated": False,
        "state": "STILL_REQUIRED", "reason": "synthetic revoked original required socket"})
    value["metrics"]["damage_lost_required"] = 1
    value["metrics"]["still_required"] += 1
    value["metrics"]["shared_work"] += 64
    value["metrics"]["total_charged_work"] += 64
    value.update(status="blocked", can_apply=False)
    return value


class DamageAuditTests(unittest.TestCase):
    def audit(self, value):
        return gallery.audit_composition(value, value["source"])

    def assert_refused(self, value, expected):
        result = self.audit(value)
        self.assertEqual(result["result"], "FAIL", result)
        self.assertTrue(any(expected in item for item in result["errors"]), result["errors"])

    def test_unchanged_native_output_passes(self):
        result = self.audit(BASE)
        self.assertEqual(result["result"], "PASS", result["errors"])

    def test_lost_internal_receipt_is_recognized(self):
        result = self.audit(damage_fixture())
        self.assertEqual(result["result"], "PASS", result["errors"])
        self.assertEqual(result["still_required"], BASE["metrics"]["still_required"] + 1)

    def test_deleted_lost_obligation_is_refused(self):
        value = damage_fixture()
        value["obligations"].pop()
        self.assert_refused(value, "damage-revoked required obligations deleted or invented")

    def test_invented_lost_obligation_is_refused(self):
        value = damage_fixture()
        value["obligations"][-1]["connector"] = 0x7fffffff
        self.assert_refused(value, "damage-revoked required obligations deleted or invented")

    def test_internal_obligation_cannot_claim_a_foreign_join(self):
        value = damage_fixture()
        value["obligations"][-1].update(foreign_joined=True, state="FOREIGN_JOINED")
        self.assert_refused(value, "required closure lacks native joint witness")

    def test_lost_internal_cannot_change_origin(self):
        value = damage_fixture()
        value["obligations"][-1]["origin"] = "original_frame"
        self.assert_refused(value, "damage-revoked required obligations deleted or invented")

    def test_lost_internal_preserves_original_socket(self):
        value = damage_fixture()
        value["obligations"][-1]["original"][0] += 1
        self.assert_refused(value, "damage-revoked obligation changed original source identity")

    def test_unrequested_lost_internal_is_refused(self):
        value = damage_fixture()
        value["damage_derivative"] = None
        self.assert_refused(value, "damage-revoked obligation lacks an original fulfilled required socket")

    def test_lost_metric_matches_source_set(self):
        value = damage_fixture()
        value["metrics"]["damage_lost_required"] = 0
        self.assert_refused(value, "damage-revoked required obligation metric mismatch")

    def test_lost_internal_blocks_apply(self):
        value = damage_fixture()
        value.update(can_apply=True, status="complete")
        self.assert_refused(value, "unqualified partial/diagnostic proposal is Apply-authorized")

    def test_internal_obligation_cannot_invent_a_foreign_slot(self):
        value = damage_fixture()
        value["obligations"][-1]["slot"] = 99
        self.assert_refused(value, "damage-revoked internal obligation invented a foreign slot or local ending")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    with tempfile.TemporaryDirectory(prefix="swarm004-gallery-test-") as temporary:
        output = Path(temporary) / "base.json"
        subprocess.run([str(args.binary.resolve()), "single", str(output), "offline-gallery-unit-control",
                        "island", "branching_irregular", "4099", "0", "no_negotiation"],
                       check=True, timeout=60, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        BASE = json.loads(output.read_text())
        unittest.main(argv=[sys.argv[0], *remaining], verbosity=2)
