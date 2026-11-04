#!/usr/bin/env python3
"""Negative controls for the `water_contact.submerged.v1` reducer.

The retained stage-1 Windows packet must pass; each targeted corruption of a
temporary copy must fail with its own reason.
"""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import reduce_submerged_evidence as reducer  # noqa: E402

PACKET = reducer.ROOT / "docs/audits/water-contact-362-2026-11-04/submerged-stage1-windows"


class SubmergedReducerNegativeControls(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "packet"
        shutil.copytree(PACKET, self.path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def edit(self, name: str, change) -> None:
        file = self.path / name
        value = json.loads(file.read_text(encoding="utf-8"))
        change(value)
        file.write_text(json.dumps(value), encoding="utf-8")

    def assert_rejected(self, needle: str) -> None:
        report = reducer.reduce(self.path, reducer.MANIFEST, 1)
        self.assertEqual(report["status"], "failed")
        self.assertTrue(any(needle in e for e in report["errors"]), report["errors"])

    def test_retained_packet_passes(self) -> None:
        report = reducer.reduce(self.path, reducer.MANIFEST, 1)
        self.assertEqual(report["status"], "passed", report["errors"])
        self.assertEqual((report["dynamic_rows"], report["kinematic_rows"]), (4, 2))

    def test_oracle_disagreement_rejected(self) -> None:
        self.edit("G-D24-V180_FM3_w1.json", lambda v: v["observer"].__setitem__("oracle_admissible", 5))
        self.assert_rejected("classifier/adapter disagreement")

    def test_vacuous_classifier_rejected(self) -> None:
        self.edit("G-D24-V180_IN3_w4.json", lambda v: v["observer"].__setitem__("samples", 0))
        self.assert_rejected("classifier never sampled")

    def test_positive_control_failure_rejected(self) -> None:
        self.edit("index.json", lambda v: v["rows"][0].__setitem__("ok", False))
        self.assert_rejected("positive control")

    def test_missing_row_rejected(self) -> None:
        (self.path / "K-R1-T_IN3.json").unlink()
        self.assert_rejected("missing kinematic row")

    def test_parity_failure_rejected(self) -> None:
        self.edit("G-D24-V180_FM3_w4.json", lambda v: v.__setitem__("trace_sha256", "x"))
        self.assert_rejected("worker parity failed")

    def test_descent_quantity_change_rejected(self) -> None:
        self.edit("K-R1-T_FM3.json", lambda v: v["quantity"].__setitem__("after", v["quantity"]["after"] - 255))
        self.assert_rejected("kinematic descent failed")

    def test_v1_invariant_still_enforced(self) -> None:
        self.edit("G-D24-V180_IN3_w1.json", lambda v: v["inertial"].__setitem__("negative_vy", 1))
        self.assert_rejected("negative vy")

    def test_manifest_hash_rejected(self) -> None:
        self.edit("K-R1-T_FM3.json", lambda v: v.__setitem__("manifest_sha256", "0" * 64))
        self.assert_rejected("manifest hash differs")


if __name__ == "__main__":
    unittest.main()
