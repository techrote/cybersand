#!/usr/bin/env python3
"""Unit tests for deterministic Godot regression shard planning."""

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_godot_regressions as subject


def fake(name: str, weight: float) -> subject.Case:
    return subject.Case(name, ("--script", name + ".gd"), 180, weight)


class ShardingTests(unittest.TestCase):
    def test_runtime_identity_follows_host_platform(self):
        windows_runtime, windows_rapier = subject.runtime_paths("win32")
        self.assertEqual(windows_runtime.name, "cybersand_native.windows.x86_64.dll")
        self.assertEqual(windows_rapier.name, "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")

        linux_runtime, linux_rapier = subject.runtime_paths("linux")
        self.assertEqual(linux_runtime.name, "libcybersand_native.linux.x86_64.so")
        self.assertEqual(linux_rapier.name, "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")

        with self.assertRaises(RuntimeError):
            subject.runtime_paths("darwin")

    def test_four_way_plan_has_exact_coverage(self):
        cases = [
            fake("a", 54),
            fake("b", 37),
            fake("c", 20),
            fake("d", 14),
            fake("e", 13),
            fake("f", 11),
            fake("g", 10),
            fake("h", 5),
        ]
        shards, _ = subject.build_shard_plan(cases, 4)
        flattened = [case.name for shard in shards for case in shard]
        self.assertCountEqual(flattened, [case.name for case in cases])
        self.assertEqual(len(flattened), len(set(flattened)))

    def test_plan_is_deterministic(self):
        cases = [fake("slow", 20), fake("mid", 10), fake("small", 5), fake("tiny", 1)]
        first, first_totals = subject.build_shard_plan(cases, 3)
        second, second_totals = subject.build_shard_plan(cases, 3)
        self.assertEqual(
            [[case.name for case in shard] for shard in first],
            [[case.name for case in shard] for shard in second],
        )
        self.assertEqual(first_totals, second_totals)

    def test_worker_parity_case_stays_on_two_vcpu_shard(self):
        cases = subject.discover_cases()
        shards, _ = subject.build_shard_plan(cases, 4)
        parity_shards = [
            index
            for index, shard in enumerate(shards)
            if any(case.name == "test_web_worker_parity" for case in shard)
        ]
        self.assertEqual(
            parity_shards,
            [2],
            "gdextension.yml routes only shard 2 to the >=2-vCPU parity runner; "
            "update the workflow and this assertion together if shard planning moves the parity case",
        )

    def test_unknown_case_weight_is_conservative(self):
        self.assertEqual(subject._weight("brand_new_test"), subject.DEFAULT_UNKNOWN_WEIGHT_SECONDS)

    def test_invalid_shard_count_is_rejected(self):
        with self.assertRaises(ValueError):
            subject.build_shard_plan([fake("a", 1)], 0)


if __name__ == "__main__":
    unittest.main()
