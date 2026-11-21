#!/usr/bin/env python3
"""Synthetic reader controls only: these fixtures are NOT hosted execution evidence."""
import argparse
import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import tempfile
import unittest

from common import ENVIRONMENT, SOURCES, canonical, digest, expected_source, expected_tests, write
from compare_pair import printed_command, verify_arm

REPOSITORY = None
PROOF = {"sha": "a" * 40, "tree": "b" * 40, "fingerprints": {"synthetic-proof": "c" * 64}}


class ReaderControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="synthetic-soliding-reader-")
        self.directory = Path(self.temp.name)
        self.loader = canonical(REPOSITORY)
        self.v = self.loader.__enter__()
        self.arm = "baseline"
        self.suite = "soliding-normal"
        self.make_fixture()

    def tearDown(self):
        self.loader.__exit__(None, None, None)
        self.temp.cleanup()

    def make_fixture(self):
        v = self.v
        self.root = self.directory / self.arm
        self.folder = self.root / "source/build/native-parallel" / self.suite
        self.source = expected_source(REPOSITORY, self.arm, v)
        self.tests = expected_tests(REPOSITORY, self.arm, self.suite)
        self.host = {"runner_environment": "github-hosted", "runner_os": "Linux", "image": "ubuntu24",
            "image_version": "synthetic-1", "architecture": "x86_64", "cpu_model": "Synthetic CPU",
            "logical_cpu_count": 4, "runner_name_sha256": "d" * 64, "job": "pair", "environment": ENVIRONMENT,
            "tools": {name: {"path": "/usr/bin/" + name, "sha256": "e" * 64,
                     "version": name + " (synthetic) 13.3.0\n", "full_version": "13.3.0", "target": "x86_64-linux-gnu"}
                      for name in ("gcc-13", "g++-13", "make", "ld")}}
        context = {"commit": self.source["source_sha"], "tree": self.source["source_tree"],
                   "tracked_delta_sha256": None, "run_id": "101", "run_attempt": "1", "job": "pair",
                   "runner_name_sha256": self.host["runner_name_sha256"]}
        start = datetime(2026, 11, 21, tzinfo=timezone.utc)
        for name, offset, cold in (("pre", 0, True), ("post", 60, False)):
            write(self.root / (name + ".json"), {"schema": "ci-opt003-soliding-snapshot-v1", "arm": self.arm,
                "source": self.source, "proof": PROOF, "run_id": 101, "run_attempt": 1,
                "cold_build": cold, "host": self.host, "captured_utc": (start + timedelta(seconds=offset)).isoformat()})
        rows = [("family", "native-family-" + self.suite, ["bash", "tools/ci/run_native_family.sh", self.suite,
                    "build/native-parallel/" + self.suite], v.family_timeout_seconds(self.suite), 10, 40)]
        rows += [("commands/" + label, self.suite + "-" + label, command,
                  v.command_timeout_seconds(self.suite, label), 13 + index * 4, 1)
                 for index, (label, _, command) in enumerate(v.COMMANDS[self.suite])]
        for name, label, command, timeout, offset, elapsed in rows:
            log = "\n".join(self.tests) + "\n" if name in ("commands/soliding-test", "commands/soliding-sanitize") else "synthetic complete output\n"
            folder = self.folder / name
            folder.mkdir(parents=True, exist_ok=True)
            (folder / "command.log").write_text(log)
            record = {"schema": "execution-command-v1", "label": label, "command": command,
                "execution_policy": v.execution_policy_identity(), "timeout_seconds": timeout,
                "status": "passed", "returncode": 0, "timed_out": False, "natural_completion": True,
                "complete": True, "started_utc": (start + timedelta(seconds=offset)).isoformat(),
                "elapsed_seconds": elapsed, "source": context, "log": "command.log", "log_sha256": digest(log.encode())}
            write(folder / "receipt.json", record)
            performance = {"source": context, "result": "passed", "natural_completion": True, "watchdog_reached": False,
                "wall_seconds": elapsed, "execution_policy": record["execution_policy"],
                "host": {"platform": "Linux", "runner_class": "github-hosted", "hardware_cohort": "github-hosted",
                    "runner_environment": "github-hosted", "runner_image": "ubuntu24", "runner_image_version": "synthetic-1",
                    "cpu_model": "Synthetic CPU", "architecture": "x86_64", "logical_cpu_count": 4}}
            (folder / "performance.jsonl").write_text(json.dumps(performance) + "\n")
        for name in v.EXIT_FILES.values():
            (self.folder / name).write_text("0\n")
        if self.suite == "soliding-normal":
            plan = {"apparatus_source_commit": self.source["source_sha"]}
            for name in v.STAGE_OUTPUTS:
                write(self.root / "source/build" / name, {"plan": plan} if "synthetic" in name else plan)
        binaries = {command.removeprefix("./"): {"bytes": 100, "sha256": "f" * 64} for command in self.tests}
        if self.suite == "soliding-normal":
            binaries.update({name: {"bytes": 100, "sha256": "f" * 64} for name in ("build/settled_discovery", "build/stage3_cost")})
        write(self.root / "binary-digests.json", binaries)
        write(self.root / "capture.json", {"arm": self.arm, "outcome": "success", "errors": []})
        self.reseal()

    def read(self, path):
        return self.v.load_json(path.read_text())

    def reseal(self):
        text = ""
        for label, _, _ in self.v.COMMANDS[self.suite]:
            folder = self.folder / "commands" / label
            record = self.read(folder / "receipt.json")
            record["log_sha256"] = digest((folder / "command.log").read_bytes())
            write(folder / "receipt.json", record)
            text += printed_command(folder, record)
        (self.folder / "family/command.log").write_text(text)
        family = self.read(self.folder / "family/receipt.json")
        family["log_sha256"] = digest(text.encode())
        write(self.folder / "family/receipt.json", family)
        log = (f"source_sha={self.source['source_sha']} suite={self.suite} run=101 attempt=1\n"
               + "compiler=" + self.host["tools"]["g++-13"]["version"].splitlines()[0] + "\n"
               + printed_command(self.folder / "family", family) + "Native family passed: " + self.suite + "\n")
        (self.folder / "run.log").write_text(log)
        codes, hashes = self.v.read_exit_codes(self.folder)
        receipt = {"schema": self.v.SCHEMA, "suite": self.suite, "source_sha": self.source["source_sha"],
            "source_tree": self.source["source_tree"], "event_sha": self.source["source_sha"], "run_id": 101, "run_attempt": 1,
            "source_fingerprints": self.source["source_fingerprints"], "source_delta_paths": [], "errors": [],
            "job_outcome": "success", "runner_os": "Linux", "exit_codes": codes, "exit_code_sha256": hashes,
            "command_outputs": self.v.command_inventory(self.folder),
            "scientific_outputs": self.v.scientific_inventory(self.root / "source/build"),
            "log_present": True, "log_bytes": len(log.encode()), "log_sha256": digest(log.encode())}
        write(self.folder / "receipt.json", receipt)
        output = json.dumps(receipt, indent=2, sort_keys=True) + "\n"
        write(self.root / "record-command.json", {"returncode": 0, "output": output, "output_sha256": digest(output.encode()),
            "command": ["python3", "tools/ci/verify_native_shards.py", "record", "--suite", self.suite,
                "--outcome", "success", "--source-sha", self.source["source_sha"], "--run-id", "101",
                "--run-attempt", "1", "--output", "build/native-parallel"]})

    def verify(self):
        return verify_arm(self.directory, REPOSITORY, self.arm, self.suite, 101, 1, PROOF, self.v)

    def test_complete_normal(self):
        self.assertEqual(len(self.verify()["commands"]), 4)

    def test_complete_asan(self):
        self.arm = "candidate"
        self.suite = "soliding-asan"
        self.make_fixture()
        self.assertEqual(len(self.verify()["commands"]), 3)

    def test_failure_timeout_cancel_and_wrong_source(self):
        path = self.folder / "commands/soliding-test/receipt.json"
        original = self.read(path)
        for changes in ({"returncode": 17, "status": "failed"}, {"timed_out": True, "status": "timeout"},
                        {"complete": False, "natural_completion": False, "status": "interrupted"},
                        {"source": {**original["source"], "commit": "0" * 40}},
                        {"timeout_seconds": 1}, {"command": ["make", "unrelated-smoke"]}):
            with self.subTest(changes=changes):
                write(path, {**original, **changes})
                self.reseal()
                with self.assertRaises(ValueError):
                    self.verify()
        write(path, original)

    def test_partial_duplicate_and_reordered_tests_even_after_hash_reseal(self):
        path = self.folder / "commands/soliding-test/command.log"
        for lines in (self.tests[:-1], self.tests + self.tests[-1:], list(reversed(self.tests)), []):
            with self.subTest(lines=lines):
                path.write_text("\n".join(lines) + "\n")
                self.reseal()
                with self.assertRaisesRegex(ValueError, "eight-test"):
                    self.verify()

    def test_stale_raw_artifact(self):
        with (self.folder / "commands/soliding-test/command.log").open("a") as stream:
            stream.write("stale\n")
        with self.assertRaises(ValueError):
            self.verify()

    def test_missing_receipt(self):
        (self.folder / "commands/soliding-test/receipt.json").unlink()
        with self.assertRaises(ValueError):
            self.verify()

    def test_log_capture_failure(self):
        (self.folder / "log-capture-exit-code.txt").write_text("1\n")
        self.reseal()
        with self.assertRaises(ValueError):
            self.verify()

    def test_stale_scientific_source_even_after_hash_reseal(self):
        write(self.root / "source/build/stage3b-validation-plan-smoke.json", {"apparatus_source_commit": "0" * 40})
        self.reseal()
        with self.assertRaises(ValueError):
            self.verify()

    def test_warm_or_changed_worker_or_missing_binary(self):
        pre_path = self.root / "pre.json"
        original = self.read(pre_path)
        for field, value in (("cold_build", False), ("host", {**self.host, "cpu_model": "Different worker"})):
            with self.subTest(field=field):
                write(pre_path, {**original, field: value})
                with self.assertRaises(ValueError):
                    self.verify()
        write(pre_path, original)
        binaries = self.read(self.root / "binary-digests.json")
        binaries.pop(next(iter(binaries)))
        write(self.root / "binary-digests.json", binaries)
        with self.assertRaises(ValueError):
            self.verify()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    REPOSITORY = args.repository.resolve()
    unittest.main(argv=[__file__, *remaining])
