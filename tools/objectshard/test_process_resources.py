"""Resource sampling controls; these synthetic values are not runtime evidence."""
from pathlib import Path
import json
import tempfile
import unittest

from process_resources import ProcessResources


class ResourceTests(unittest.TestCase):
    def test_rate_limit_and_zombie_do_not_erase_observed_peak(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            (root / "42").mkdir()
            (root / "42/status").write_text("State:\tR (running)\nVmRSS:\t500 kB\nVmHWM:\t700 kB\n")
            (root / "meminfo").write_text("MemTotal: 4096 kB\nMemAvailable: 1024 kB\n")
            now = [0.0]
            observer = lambda pid: {"available": True, "scope": "direct_process_only", "cpu_seconds": 1, "peak_rss_bytes": None}
            sampler = ProcessResources(root / "samples.jsonl", observer, proc_root=root, clock=lambda: now[0])
            first = sampler.observe(42)
            self.assertEqual(first["peak_rss_bytes"], 700 * 1024)
            now[0] = .5
            self.assertIs(sampler.observe(42), first)
            self.assertEqual(sampler.samples, 1)
            (root / "42/status").write_text("State:\tZ (zombie)\n")
            (root / "meminfo").write_text("MemTotal: 4096 kB\nMemAvailable: 512 kB\n")
            now[0] = 1.5
            final = sampler.observe(42)
            self.assertEqual(final["peak_rss_bytes"], 700 * 1024)
            self.assertEqual(final["minimum_host_mem_available_bytes"], 512 * 1024)
            sampler.finish({"returncode": -9, "status": "failed"})
            rows = [json.loads(line) for line in (root / "samples.jsonl").read_text().splitlines()]
            self.assertEqual(len(rows), 3)
            self.assertEqual(rows[-1]["returncode"], -9)
            self.assertEqual(rows[-1]["termination_cause"], "not established by these observations")

    def test_namespace_mismatch_never_reads_unrelated_process_memory(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            (root / "42").mkdir()
            (root / "42/status").write_text("VmRSS: 123456 kB\nVmHWM: 123456 kB\n")
            observer = lambda pid: {"available": False, "reason": "proc_pid_namespace_mismatch"}
            sampler = ProcessResources(root / "samples.jsonl", observer, proc_root=root)
            self.assertFalse(sampler.observe(42)["available"])
            self.assertIsNone(sampler.peak_rss)


if __name__ == "__main__":
    unittest.main()
