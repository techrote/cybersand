#!/usr/bin/env python3
"""No-Godot regressions for the PR #493-derived PressureFlow acceptance screen."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import tempfile
import unittest

import pf_gas_acceptance as gate
from stress_water_factorial import plan, write_json


class AcceptanceSubsetTests(unittest.TestCase):
    def test_unchanged_full_universe(self) -> None:
        self.assertEqual(len(plan()), 360)

    def test_rapid_strata_cover_every_mode_and_both_native_core_sizes(self) -> None:
        rows = gate.selection(0)
        self.assertEqual(len(rows), 40)
        self.assertEqual(len({row["id"] for row in rows}), 40)
        self.assertEqual({row["group"] for row in rows}, set(gate.GROUPS))
        self.assertEqual({row["fine"] for row in rows}, {False, True})
        self.assertEqual({row["ballistic"] for row in rows}, {False, True})
        self.assertEqual({row["face"] for row in rows}, {False, True})
        self.assertEqual({row["spray"] for row in rows}, {False, True})
        for group in gate.GROUPS:
            self.assertEqual(len([r for r in rows if r["group"] == group]), 10)
            self.assertEqual({r["water_mode"] for r in rows if r["group"] == group},
                             {r["water_mode"] for r in plan()})
        pf = [r for r in rows if r["family"] == "pressure_flow_v1"]
        self.assertEqual({r["variant"] for r in pf}, {"reference", "cached", "cached_dormant"})
        self.assertEqual({r["gas"] for r in pf}, {False, True})
        self.assertEqual({r["signed"] for r in rows if r["family"] == "inertial_cellular_v1"},
                         {False, True})

    def test_repetitions_and_configuration_identity(self) -> None:
        first = gate.selection(0)
        second = gate.selection(1)
        self.assertEqual({r["id"] for r in first}, {r["id"] for r in second})
        self.assertEqual(len({r["id"] for r in second}), 40)
        self.assertTrue(all(r["replicate"] == 0 for r in first))
        self.assertTrue(all(r["replicate"] == 1 for r in second))
        self.assertEqual(sorted(r["sequence"] for r in first), list(range(40)))
        self.assertEqual(sorted(r["sequence"] for r in second), list(range(40)))

    def test_fail_closed_on_wrong_abba_order_before_starting_godot(self) -> None:
        with self.assertRaisesRegex(ValueError, "Wrong ABBA"):
            gate.execute(argparse.Namespace(role="baseline", replicate=0, order_position=2))

    def test_source_manifest_rejects_runtime_substitution(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            native = root / "cybersand_native.dll"
            native.write_bytes(b"native candidate")
            manifest = root / "source.json"
            row = {
                "source_commit": "a" * 40, "source_tree_sha": "b" * 40,
                "native_sha256": "0" * 64,
                "compiler": "test", "build_flags": "release", "build_profile": "test",
                "build_job_url": "https://github.com/example/test/actions/runs/1",
            }
            write_json(manifest, row)
            with self.assertRaisesRegex(ValueError, "do not match"):
                gate.build_manifest(manifest, native)
            row["native_sha256"] = hashlib.sha256(native.read_bytes()).hexdigest()
            write_json(manifest, row)
            self.assertEqual(gate.build_manifest(manifest, native), row)


if __name__ == "__main__":
    unittest.main()
