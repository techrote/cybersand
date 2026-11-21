#!/usr/bin/env python3
"""Synthetic evidence-reader controls only; never native/hosted qualification."""
import argparse
import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import shlex
import tempfile
import unittest
from unittest.mock import patch

from common import ENVIRONMENT, SOURCES, assert_contract_parity, canonical, contract, digest, git, blob, write
from compare_pair import compare, printed_command, verify_arm

REPOSITORY = None
PROOF = {"sha": "a" * 40, "tree": "b" * 40, "fingerprints": {"synthetic-proof": "c" * 64}}
CACHE = {}


def fixture_inventory(repository, arm, verifier, expected, host):
    key = SOURCES[arm][0]
    if key in CACHE:
        return copy.deepcopy(CACHE[key])
    with tempfile.TemporaryDirectory(prefix="synthetic-cold-make-plan-") as temporary:
        root = Path(temporary)
        (root / "Makefile").write_bytes(blob(repository, key, "Makefile"))
        # Empty placeholders let the ORIGINAL forced dry-run inspect real source
        # path/flag/graph obligations. No compiler or scientific test runs here.
        for name in git(repository, "ls-tree", "-r", "--name-only", key, "--", "native").decode().splitlines():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"")
        families = {}
        inventory = verifier.proof_inventory
        for target in ("worldgen-test", "worldgen-sanitize"):
            serial, bounded = inventory.dry_run(root, target, 1), inventory.dry_run(root, target, 2)
            families[target] = {"serial": serial, "two_jobs": bounded,
                               **inventory.compare(serial["stdout"], bounded["stdout"], target == "worldgen-sanitize")}
    report = {"status": "passed", "source_revision": key,
              "makefile_sha256": expected["source"]["source_fingerprints"]["makefile"],
              "helper_sha256": expected["source"]["source_fingerprints"]["worldgen_inventory"],
              "make_version": host["tools"]["make"]["version"].splitlines()[0],
              "compiler_substitution": inventory.COMPILER, "families": families}
    CACHE[key] = copy.deepcopy(report)
    return report


class ReaderControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="synthetic-worldgen-reader-")
        self.directory = Path(self.temp.name)
        self.loader = None
        self.load("baseline")
        self.make_fixture()

    def tearDown(self):
        self.loader.__exit__(None, None, None)
        self.temp.cleanup()

    def load(self, arm):
        if self.loader is not None:
            self.loader.__exit__(None, None, None)
        self.arm = arm
        self.loader = canonical(REPOSITORY, arm)
        self.v = self.loader.__enter__()
        self.expected = contract(REPOSITORY, arm, self.v)
        self.root = self.directory / arm
        self.folder = self.root / "source/build/native-parallel/worldgen"
        self.source = self.expected["source"]
        self.source_root = "/synthetic/workspace/build/proof/worldgen/" + arm + "/source"

    def read(self, path):
        return self.v.load_json(path.read_text())

    def make_fixture(self):
        v = self.v
        self.host = {"runner_environment": "github-hosted", "runner_os": "Linux", "image": "ubuntu24",
            "image_version": "synthetic-1", "architecture": "x86_64", "cpu_model": "Synthetic CPU",
            "logical_cpu_count": 4, "nproc": 4, "memory_kib": 16000000,
            "runner_name_sha256": "d" * 64, "job": "pair", "environment": ENVIRONMENT,
            "tools": {name: {"path": "/usr/bin/" + name, "sha256": "e" * 64,
                "version": name + " (synthetic) 13.3.0\n", "full_version": "13.3.0", "target": "x86_64-linux-gnu"}
                      for name in ("gcc-13", "g++-13", "make", "ld")}}
        context = {"commit": self.source["source_sha"], "tree": self.source["source_tree"],
            "tracked_delta_sha256": None, "run_id": "101", "run_attempt": "1", "job": "pair",
            "runner_name_sha256": self.host["runner_name_sha256"]}
        start = datetime(2026, 11, 21, tzinfo=timezone.utc) + timedelta(seconds=0 if self.arm == "baseline" else 100)
        for phase, offset, cold in (("pre", 0, True), ("post", 60, False)):
            write(self.root / (phase + ".json"), {"schema": "ci-opt003-worldgen-runtime-snapshot-v1", "arm": self.arm,
                "source": self.source, "source_root": self.source_root, "proof": PROOF, "run_id": 101, "run_attempt": 1,
                "cold_build": cold, "host": self.host, "captured_utc": (start + timedelta(seconds=offset)).isoformat()})
        inventory = fixture_inventory(REPOSITORY, self.arm, v, self.expected, self.host)
        write(self.folder / "build-inventory.json", inventory)
        summary = {}
        for target, row in inventory["families"].items():
            summary[target] = {"objects": 12, "binaries": 16}
            if self.arm == "baseline":
                summary[target]["ordered_tests"] = 16
            else:
                summary[target].update(showcases=7, ordered_main_tests=9, executions=16)
        self.prefix = json.dumps({"status": "passed", "families": summary, "error": ""}) + "\n4\nMemTotal: 16000000 kB\n"
        binaries = {"build/physics_characterisation_sanitized": {"bytes": 100, "sha256": "f" * 64}}
        logs = {"physics-characterisation-sanitize": shlex.join(self.expected["physics_compiler_command"])
                + "\nCLI material accounting: passed; 154 invocations\n"}
        for target, tests in self.expected["tests"].items():
            parts = [shlex.join(command) for command in self.expected["compiler_commands"][target].values()]
            for binary in tests["showcases"]:
                marker = "Running sanitized " if target == "worldgen-sanitize" else "Running "
                parts.append(marker + binary)
                if self.arm == "candidate":
                    header = f"source_sha={self.source['source_sha']} run_id=101 run_attempt=1 binary={Path(binary).name}\n"
                    log = header + "synthetic showcase complete\n"
                    path = self.root / "source/build/worldgen-showcase-logs" / (Path(binary).name + ".log")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(log)
                    parts.append(log.rstrip())
                binaries[binary] = {"bytes": 100, "sha256": "f" * 64}
            parts.extend(tests["ordered_main_tests"])
            for command in tests["ordered_main_tests"]:
                binaries[command.removeprefix("./")] = {"bytes": 100, "sha256": "f" * 64}
            logs[target] = "\n".join(parts) + "\n"
        write(self.root / "binary-digests.json", binaries)
        self.make_physics()
        rows = [("family", "native-family-worldgen", ["bash", "tools/ci/run_native_family.sh", "worldgen",
                "build/native-parallel/worldgen"], v.family_timeout_seconds("worldgen"), 10, 40)]
        rows += [("commands/" + label, "worldgen-" + label, command,
                  v.command_timeout_seconds("worldgen", label), 13 + index * 4, 1)
                 for index, (label, _, command) in enumerate(v.COMMANDS["worldgen"])]
        for name, label, command, timeout, offset, elapsed in rows:
            folder = self.folder / name
            folder.mkdir(parents=True, exist_ok=True)
            log = logs.get(name.removeprefix("commands/"), "synthetic parent\n")
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
        write(self.root / "capture.json", {"arm": self.arm, "outcome": "success", "errors": []})
        self.reseal()

    def make_physics(self):
        physics = self.v.proof_physics
        directory = self.root / "source/build/physics-cli-validation/sanitized"
        directory.mkdir(parents=True, exist_ok=True)
        executable = Path(self.source_root) / "build/physics_characterisation_sanitized"
        rows = []
        for item in self.expected["physics_invocations"]:
            if item["name"].startswith("invalid-"):
                stdout, stderr, code = "", "invalid material\n", 1
            else:
                material = int(item["name"].split("-")[1])
                upper = item["name"].endswith("-upper")
                counts, sums = [0] * 132, [0] * 132
                counts[0], sums[0] = 550, 25625
                counts[1], sums[1] = (210, 10575) if upper else (252, 14196)
                counts[material], sums[material] = (48, 4200) if upper else (6, 579)
                samples = [{"type": "sample", "tick": tick, "counts": counts, "sum_y": sums, "water_mass": 0} for tick in (0, 1)]
                samples.append({"type": "result", "completed_ticks": 1, "overflow": 0, "left_x": 64, "surface_y": 96, "floor_y": 98})
                stdout, stderr, code = "\n".join(map(json.dumps, samples)) + "\n", "", 0
            (directory / (item["name"] + ".jsonl")).write_text(stdout)
            (directory / (item["name"] + ".stderr.log")).write_text(stderr)
            rows.append({"name": item["name"], "command": physics.invocation_command(executable, item["top"], item["bottom"]),
                "returncode": code, "timed_out": False, "launch_error": None, "seconds": 0.001,
                "watchdog_key": "operation_seconds", "timeout_seconds": physics.watchdog_seconds("operation_seconds"),
                "stdout_sha256": digest(stdout.encode()), "stderr_sha256": digest(stderr.encode())})
        names = [row["name"] for row in rows]
        write(directory / "results.json", {"status": "passed", "executable": str(executable), "executable_sha256": "f" * 64,
            "test_groups": 3, "failures": 0, "errors": 0, "building_ids": list(physics.BUILDING_IDS), "invalid_ids": list(physics.INVALID_IDS),
            "dispatch_workers": physics.PHYSICS_DISPATCH_WORKERS, "planned_invocations": names,
            "checked_invocations": names, "complete_invocation_inventory": True, "invocations": rows})

    def reseal(self):
        text = self.prefix
        for label, _, _ in self.v.COMMANDS["worldgen"]:
            folder = self.folder / "commands" / label
            record = self.read(folder / "receipt.json")
            record["log_sha256"] = digest((folder / "command.log").read_bytes())
            write(folder / "receipt.json", record)
            printed = printed_command(folder, record)
            text += printed
            if label == "physics-characterisation-sanitize":
                (self.root / "source/build/physics-cli-validation/validation.log").write_text(printed)
        (self.folder / "family/command.log").write_text(text)
        family = self.read(self.folder / "family/receipt.json")
        family["log_sha256"] = digest(text.encode())
        write(self.folder / "family/receipt.json", family)
        log = (f"source_sha={self.source['source_sha']} suite=worldgen run=101 attempt=1\n"
            + "compiler=" + self.host["tools"]["g++-13"]["version"].splitlines()[0] + "\n"
            + printed_command(self.folder / "family", family) + "Native family passed: worldgen\n")
        (self.folder / "run.log").write_text(log)
        codes, hashes = self.v.read_exit_codes(self.folder)
        receipt = {"schema": self.v.SCHEMA, "suite": "worldgen", "source_sha": self.source["source_sha"],
            "source_tree": self.source["source_tree"], "event_sha": self.source["source_sha"], "run_id": 101, "run_attempt": 1,
            "source_fingerprints": self.source["source_fingerprints"], "source_delta_paths": [], "errors": [],
            "job_outcome": "success", "runner_os": "Linux", "exit_codes": codes, "exit_code_sha256": hashes,
            "command_outputs": self.v.command_inventory(self.folder),
            "scientific_outputs": self.v.scientific_inventory(self.root / "source/build"),
            "log_present": True, "log_bytes": len(log.encode()), "log_sha256": digest(log.encode())}
        write(self.folder / "receipt.json", receipt)
        output = json.dumps(receipt, indent=2, sort_keys=True) + "\n"
        write(self.root / "record-command.json", {"returncode": 0, "output": output, "output_sha256": digest(output.encode()),
            "command": ["python3", "tools/ci/verify_native_shards.py", "record", "--suite", "worldgen", "--outcome", "success",
                "--source-sha", self.source["source_sha"], "--run-id", "101", "--run-attempt", "1", "--output", "build/native-parallel"]})

    def verify(self):
        return verify_arm(self.directory, REPOSITORY, self.arm, "worldgen", 101, 1, PROOF, self.v)

    def test_complete_baseline(self):
        result = self.verify()
        self.assertEqual(len(result["commands"]), 3)
        self.assertEqual(result["physics"]["invocation_count"], 154)

    def test_complete_candidate_and_pair(self):
        self.load("candidate")
        self.make_fixture()
        self.assertTrue(self.verify()["physics"]["scientific_assertions_reapplied"])
        declaration = {"schema": "ci-opt003-worldgen-runtime-pair-v1", "proof": PROOF, "suite": "worldgen",
            "run_id": 101, "run_attempt": 1, "order": ["baseline", "candidate"], "repetitions": 1,
            "job_cap_minutes": 360, "contracts": assert_contract_parity(REPOSITORY), "host": self.host}
        write(self.directory / "proof.json", declaration)
        with patch("compare_pair.proof_identity", return_value=PROOF):
            result = compare(self.directory, REPOSITORY, "worldgen", 101, 1, PROOF["sha"])
        self.assertFalse(result["whole_native_qualified"])
        self.assertFalse(result["routine_ci_qualified"])

    def test_failure_timeout_cancel_wrong_source_and_short_watchdog(self):
        path = self.folder / "commands/worldgen-test/receipt.json"
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

    def test_missing_duplicate_or_reordered_tests_and_wrong_compiler_after_reseal(self):
        path = self.folder / "commands/worldgen-test/command.log"
        original = path.read_text()
        main = self.expected["tests"]["worldgen-test"]["ordered_main_tests"]
        showcase = "Running " + self.expected["tests"]["worldgen-test"]["showcases"][0] + "\n"
        variants = [original.replace(main[-1] + "\n", ""), original + main[-1] + "\n",
            original.replace("\n".join(main), "\n".join(reversed(main))),
            original.replace(showcase, ""), original.replace(showcase, showcase * 2), original.replace("-Werror", "-Wno-error", 1)]
        for value in variants:
            with self.subTest(value=value[-100:]):
                path.write_text(value)
                self.reseal()
                with self.assertRaises(ValueError):
                    self.verify()

    def test_partial_physics_timeout_wrong_arguments_and_scientific_failure(self):
        directory = self.root / "source/build/physics-cli-validation/sanitized"
        path = directory / "results.json"
        original = self.read(path)
        variants = []
        value = copy.deepcopy(original); value["invocations"].pop(); variants.append(value)
        value = copy.deepcopy(original); value["invocations"][0]["timed_out"] = True; variants.append(value)
        value = copy.deepcopy(original); value["invocations"][0]["command"][1] = "wrong"; variants.append(value)
        value = copy.deepcopy(original); value["invocations"][0]["returncode"] = 19; variants.append(value)
        for value in variants:
            with self.subTest(value=len(value["invocations"])):
                write(path, value); self.reseal()
                with self.assertRaises(ValueError):
                    self.verify()
        write(path, original)
        first = original["invocations"][0]
        stdout = directory / (first["name"] + ".jsonl")
        rows = [json.loads(line) for line in stdout.read_text().splitlines()]
        rows[0]["counts"][0] -= 1
        stdout.write_text("\n".join(map(json.dumps, rows)) + "\n")
        original["invocations"][0]["stdout_sha256"] = digest(stdout.read_bytes())
        write(path, original); self.reseal()
        with self.assertRaisesRegex(ValueError, "scientific assertions"):
            self.verify()

    def test_stale_or_missing_raw_artifact(self):
        path = self.folder / "commands/worldgen-test/command.log"
        original = path.read_text()
        path.write_text(original + "stale\n")
        with self.assertRaises(ValueError):
            self.verify()
        path.write_text(original)
        (self.folder / "commands/worldgen-test/receipt.json").unlink()
        with self.assertRaises(ValueError):
            self.verify()

    def test_failed_log_capture(self):
        (self.folder / "log-capture-exit-code.txt").write_text("1\n")
        self.reseal()
        with self.assertRaises(ValueError):
            self.verify()

    def test_candidate_missing_stale_or_empty_showcase_logs(self):
        self.load("candidate"); self.make_fixture()
        path = self.root / "source/build/worldgen-showcase-logs/test_megatruss_station.log"
        original = path.read_text()
        for value in (original.replace(self.source["source_sha"], "0" * 40), original.splitlines()[0] + "\n", None):
            with self.subTest(value=value):
                if value is None:
                    path.unlink()
                else:
                    path.write_text(value)
                self.reseal()
                with self.assertRaises(ValueError):
                    self.verify()

    def test_warm_changed_worker_or_incomplete_binary_inventory(self):
        path = self.root / "pre.json"
        original = self.read(path)
        for field, value in (("cold_build", False), ("host", {**self.host, "cpu_model": "Different worker"})):
            write(path, {**original, field: value})
            with self.assertRaises(ValueError):
                self.verify()
        write(path, original)
        path = self.root / "binary-digests.json"
        binaries = self.read(path); binaries.pop(next(iter(binaries))); write(path, binaries)
        with self.assertRaises(ValueError):
            self.verify()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    REPOSITORY = args.repository.resolve()
    unittest.main(argv=[__file__, *remaining])
