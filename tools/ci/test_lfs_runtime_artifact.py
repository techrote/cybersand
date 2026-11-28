#!/usr/bin/env python3
"""Adversarial transport controls using synthetic bytes, never runtime proof."""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import lfs_runtime_artifact as transport


class RuntimeArtifact(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="lfs-artifact-control-")
        # Windows TEMP can contain an 8.3 alias; compare the same canonical
        # checkout identity used by the actual producer and consumer.
        self.root = Path(self.temporary.name).resolve()
        self.repo = self.root / "source"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Synthetic custody control")
        self.git("config", "user.email", "fixture@example.invalid")
        self.payload = {f"runtime/{platform}-{kind}.bin": (platform + kind + " synthetic fixture\n").encode()
                        for platform in ("linux", "windows") for kind in ("native", "rapier")}
        self.available = sorted(self.payload)
        self.selected = [p for p in self.available if "windows" in p]
        self.pointers = {p: ("version https://git-lfs.github.com/spec/v1\noid sha256:"
                              + hashlib.sha256(data).hexdigest() + f"\nsize {len(data)}\n").encode()
                         for p, data in self.payload.items()}
        self.reset_destinations()
        self.git("add", "runtime")
        self.git("commit", "-qm", "Synthetic committed pointers")
        self.source = self.git("rev-parse", "HEAD").strip()
        self.artifact = self.root / "producer"
        self.run_id, self.attempt = "123456789", 2
        self.output_number = 0
        self.pulls = 1

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.STDOUT).decode()

    def reset_destinations(self):
        for name, data in self.pointers.items():
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_symlink():
                target.unlink()
            target.write_bytes(data)

    def acquire(self, root, names, source, output, allowance):
        self.assertEqual(root, self.repo)
        self.assertEqual(source, self.source)
        self.assertEqual(names, self.available)
        self.assertGreater(allowance, 10)
        self.assertLessEqual(allowance, 600)
        output.mkdir(parents=True)
        commands = []
        for index in range(self.pulls + 1):
            label = "lfs-setup" if index == 0 else f"lfs-pull-{index}"
            success = index in (0, self.pulls)
            text = b"synthetic successful acquisition\n" if success else b"batch response: We couldn't respond to your request in time\n"
            log = output / (label + ".log")
            log.write_bytes(text)
            command = (["git", "lfs", "install", "--local"] if index == 0 else
                       ["git", "lfs", "pull", "--include=" + ",".join(names), "--exclude="])
            commands.append({"label": label, "log": log.name, "command": command,
                             "joined": True, "timed_out": False, "returncode": 0 if success else 2,
                             "retryable_service_timeout": not success, "log_bytes": len(text),
                             "log_sha256": hashlib.sha256(text).hexdigest()})
        objects = []
        for name in names:
            data = self.payload[name]
            (root / name).write_bytes(data)
            digest = hashlib.sha256(data).hexdigest()
            objects.append({"path": name, "sha256": digest, "bytes": len(data),
                            "actual_sha256": digest, "actual_bytes": len(data)})
        receipt = {"schema": "cybersand-lfs-acquisition-v1", "source_commit": source,
                   "status": "passed", "commands": commands, "objects": objects}
        transport.write(output / "receipt.json", receipt)
        return receipt

    def staged(self):
        with mock.patch.object(transport.materialize_lfs, "materialize", side_effect=self.acquire) as acquire:
            result = transport.stage(self.repo, self.available, self.source, self.run_id,
                                     self.attempt, self.artifact, 600)
        self.assertEqual(acquire.call_count, 1)
        self.assertEqual(result["status"], "passed")
        self.reset_destinations()
        return result

    def installed(self, **changes):
        self.output_number += 1
        args = dict(root=self.repo, selected=self.selected, available=self.available,
                    source=self.source, run_id=self.run_id, attempt=self.attempt,
                    artifact=self.artifact, output=self.root / f"install-{self.output_number}.json",
                    allowance_seconds=300)
        args.update(changes)
        return transport.install(**args)

    def reseal(self):
        manifest = json.loads((self.artifact / transport.MANIFEST).read_text())
        manifest["files_sha256"] = {p.relative_to(self.artifact).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in self.artifact.rglob("*") if p.is_file() and p.name != transport.MANIFEST}
        (self.artifact / transport.MANIFEST).write_text(json.dumps(manifest))

    def refuse(self, **changes):
        self.reset_destinations()
        with mock.patch.object(transport.materialize_lfs, "materialize") as network:
            with self.assertRaises((ValueError, OSError, subprocess.SubprocessError)):
                self.installed(**changes)
            network.assert_not_called()
        for name, original in self.pointers.items():
            self.assertEqual((self.repo / name).read_bytes(), original)

    def test_one_producer_installs_only_selected_platform_after_verifying_all_objects(self):
        self.staged()
        result = self.installed()
        self.assertEqual(result["status"], "passed")
        self.assertEqual([x["path"] for x in result["installed"]], self.selected)
        for name in self.available:
            self.assertEqual((self.repo / name).read_bytes(), self.payload[name] if name in self.selected else self.pointers[name])

    def test_actual_retry_log_sequence_remains_admissible_and_bound(self):
        self.pulls = 3
        self.staged()
        self.assertEqual(self.installed()["status"], "passed")

    @unittest.skipUnless(os.name == "posix", "POSIX executable bit")
    def test_install_uses_committed_mode_for_executable_and_library(self):
        executable, library = self.selected
        self.git("update-index", "--chmod=+x", executable)
        self.git("commit", "-qm", "Track executable companion")
        self.source = self.git("rev-parse", "HEAD").strip()
        self.staged()
        # Neither a downloaded artifact's permissions nor a stale pointer's
        # permissions establish whether the installed binary is executable.
        (self.artifact / "payload" / library).chmod(0o755)
        (self.repo / executable).chmod(0o644)
        self.installed()
        self.assertEqual((self.repo / executable).stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.repo / library).stat().st_mode & 0o777, 0o644)

    def test_other_source_run_or_attempt_is_refused_without_network_fallback(self):
        self.staged()
        for changes in ({"source": "a" * 40}, {"run_id": "999"}, {"attempt": 3}, {"attempt": True}):
            with self.subTest(changes=changes):
                self.refuse(**changes)

    def test_missing_other_platform_object_is_not_hidden_by_a_selected_subset(self):
        self.staged()
        (self.artifact / "payload" / self.available[0]).unlink()
        self.reseal()
        self.refuse()

    def test_resealed_wrong_bytes_cannot_override_the_consumers_committed_pointer(self):
        self.staged()
        path = self.artifact / "payload" / self.available[0]
        path.write_bytes(b"x" * len(self.payload[self.available[0]]))
        self.reseal()
        self.refuse()

    def test_extra_script_and_changed_acquisition_log_are_refused(self):
        self.staged()
        extra = self.artifact / "unexpected.py"
        extra.write_text("not an admitted member")
        self.refuse()
        extra.unlink()
        (self.artifact / "acquisition/lfs-setup.log").write_text("changed")
        self.refuse()

    def test_wrong_stage_attempt_is_refused_even_with_a_resealed_manifest(self):
        self.staged()
        path = self.artifact / "stage-result.json"
        result = json.loads(path.read_text()); result["attempt"] = 1
        path.write_text(json.dumps(result)); self.reseal()
        self.refuse()

    def test_unjoined_or_failed_original_acquisition_is_not_accepted_as_a_pass(self):
        self.staged()
        path = self.artifact / "acquisition/receipt.json"
        original = json.loads(path.read_text())
        for key, value in (("joined", False), ("timed_out", True), ("returncode", 2), ("command", ["another", "source"])):
            changed = copy.deepcopy(original)
            changed["commands"][-1][key] = value
            path.write_text(json.dumps(changed)); self.reseal()
            with self.subTest(key=key):
                self.refuse()

    def test_authentication_failure_cannot_be_reclassified_as_an_admissible_retry(self):
        self.pulls = 2
        self.staged()
        log = self.artifact / "acquisition/lfs-pull-1.log"
        log.write_text("batch response: authentication failure\n")
        path = self.artifact / "acquisition/receipt.json"
        receipt = json.loads(path.read_text())
        receipt["commands"][1].update(log_bytes=log.stat().st_size, log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
        path.write_text(json.dumps(receipt)); self.reseal()
        self.refuse()

    def test_duplicate_manifest_key_is_refused(self):
        self.staged()
        path = self.artifact / transport.MANIFEST
        path.write_text('{"status":"passed",' + path.read_text()[1:])
        self.refuse()

    def test_payload_symlink_is_refused_before_any_runtime_install(self):
        self.staged()
        name = self.available[0]
        outside = self.root / "outside.bin"; outside.write_bytes(self.payload[name])
        payload = self.artifact / "payload" / name; payload.unlink(); payload.symlink_to(outside)
        self.refuse()

    def test_selected_destination_symlink_does_not_modify_its_target(self):
        self.staged()
        outside = self.root / "outside.bin"; outside.write_bytes(b"preserve")
        target = self.repo / self.selected[0]; target.unlink(); target.symlink_to(outside)
        with self.assertRaises(ValueError):
            self.installed()
        self.assertEqual(outside.read_bytes(), b"preserve")

    def test_stale_staging_and_existing_receipt_are_preserved(self):
        self.staged()
        target = self.repo / self.selected[-1]
        stale = target.with_name(target.name + ".ci-runtime-stage"); stale.write_bytes(b"retained failed evidence")
        self.refuse()
        self.assertEqual(stale.read_bytes(), b"retained failed evidence")
        self.assertFalse((self.repo / self.selected[0]).with_name(Path(self.selected[0]).name + ".ci-runtime-stage").exists())
        output = self.root / "original-receipt.json"; output.write_text("retained")
        self.refuse(output=output)
        self.assertEqual(output.read_text(), "retained")

    def test_source_movement_during_preinstallation_leaves_all_original_destinations(self):
        self.staged()
        original_copy = transport.copy
        moved = False

        def move_source(source, target, budget):
            nonlocal moved
            original_copy(source, target, budget)
            if not moved:
                marker = self.repo / "source-moved.txt"; marker.write_text("changed")
                self.git("add", marker.name); self.git("commit", "-qm", "Moved synthetic source")
                moved = True

        with mock.patch.object(transport, "copy", side_effect=move_source):
            self.refuse()
        self.assertFalse(list(self.repo.rglob("*.ci-runtime-stage")))

    def test_failed_acquisition_retains_original_failure_and_has_no_usable_manifest(self):
        def failed(*args):
            output = args[3]; output.mkdir(parents=True)
            (output / "lfs-pull-1.log").write_text("original service refusal")
            raise RuntimeError("bounded acquisition failed")

        with mock.patch.object(transport.materialize_lfs, "materialize", side_effect=failed):
            with self.assertRaises(RuntimeError):
                transport.stage(self.repo, self.available, self.source, self.run_id, self.attempt, self.artifact, 600)
        self.assertFalse((self.artifact / transport.MANIFEST).exists())
        self.assertEqual(json.loads((self.artifact / "stage-result.json").read_text())["status"], "failed")
        self.assertEqual((self.artifact / "acquisition/lfs-pull-1.log").read_text(), "original service refusal")

    def test_original_deadline_includes_staging_and_never_leaves_a_transport_pass(self):
        clock = [100.0]

        def overrun(*args):
            result = self.acquire(*args)
            clock[0] += 601.0
            return result

        with mock.patch.object(transport.time, "monotonic", side_effect=lambda: clock[0]), \
                mock.patch.object(transport.materialize_lfs, "materialize", side_effect=overrun):
            with self.assertRaises(TimeoutError):
                transport.stage(self.repo, self.available, self.source, self.run_id, self.attempt, self.artifact, 600)
        self.assertFalse((self.artifact / transport.MANIFEST).exists())
        self.assertEqual(json.loads((self.artifact / "stage-result.json").read_text())["status"], "failed")

    def test_unsafe_duplicate_and_windows_colliding_inventory_is_refused(self):
        for values in (["../escape"], ["runtime/a", "runtime/a"], ["runtime/A", "runtime/a"], ["."], ["runtime/*.bin"]):
            with self.subTest(values=values), self.assertRaises(ValueError):
                transport.paths(values)

    def test_late_producer_seal_is_preserved_as_failure_and_cannot_be_consumed(self):
        clock = [100.0]
        original_write = transport.write

        def delayed_seal(path, value):
            original_write(path, value)
            if path.name == transport.MANIFEST:
                clock[0] += 601

        with mock.patch.object(transport.time, "monotonic", side_effect=lambda: clock[0]), \
                mock.patch.object(transport.materialize_lfs, "materialize", side_effect=self.acquire), \
                mock.patch.object(transport, "write", side_effect=delayed_seal):
            with self.assertRaises(TimeoutError):
                transport.stage(self.repo, self.available, self.source, self.run_id, self.attempt, self.artifact, 600)
        self.assertFalse((self.artifact / transport.MANIFEST).exists())
        self.assertTrue((self.artifact / "failed-manifest.json").is_file())
        self.assertEqual(json.loads((self.artifact / "stage-failure.json").read_text())["status"], "failed")
        self.refuse()

    def test_late_consumer_receipt_is_failed_even_when_installed_bytes_are_valid(self):
        self.staged()
        clock = [100.0]
        original_write = transport.write

        def delayed_seal(path, value):
            original_write(path, value)
            if path.name == "install-1.json" and value["status"] == "passed":
                clock[0] += 301

        with mock.patch.object(transport.time, "monotonic", side_effect=lambda: clock[0]), \
                mock.patch.object(transport, "write", side_effect=delayed_seal):
            with self.assertRaises(TimeoutError):
                self.installed()
        self.assertEqual(json.loads((self.root / "install-1.json").read_text())["status"], "failed")
        self.assertTrue((self.root / "install-1.json.failed-seal.json").is_file())
        for name in self.selected:
            self.assertEqual((self.repo / name).read_bytes(), self.payload[name])

    def test_nonpointer_source_and_invalid_allowance_are_refused_before_acquisition(self):
        ordinary = self.repo / "ordinary.txt"; ordinary.write_text("ordinary source")
        self.git("add", ordinary.name); self.git("commit", "-qm", "Ordinary nonpointer input")
        source = self.git("rev-parse", "HEAD").strip()
        with mock.patch.object(transport.materialize_lfs, "materialize") as network:
            with self.assertRaises(ValueError):
                transport.stage(self.repo, [ordinary.name], source, self.run_id, self.attempt, self.artifact, 600)
            network.assert_not_called()
        for seconds in (float("nan"), float("inf"), 10, -1):
            with self.subTest(seconds=seconds), self.assertRaises(ValueError):
                transport.Budget(seconds)


if __name__ == "__main__":
    unittest.main()
