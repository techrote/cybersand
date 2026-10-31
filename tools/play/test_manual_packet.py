#!/usr/bin/env python3
"""Adverse provenance/packet controls; synthetic files are not engine evidence."""
import csv
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
import warnings
import zipfile

import create_manual_packet as packet


class SourceControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Synthetic verifier control")
        self.git("config", "user.email", "test@example.invalid")
        (self.root / "source.txt").write_text("registered source\n", encoding="utf-8")
        self.git("add", "source.txt")
        self.git("commit", "-qm", "synthetic source")
        self.head = self.git("rev-parse", "HEAD").decode().strip()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.PIPE)

    def test_exact_clean_source_and_wrong_expected_head(self):
        self.assertEqual(packet.clean_identity(self.root, self.head)["commit"], self.head)
        for wrong in ("f" * 40, self.head[:8], self.head.upper()):
            with self.subTest(wrong=wrong), self.assertRaises(ValueError):
                packet.clean_identity(self.root, wrong)

    def test_modified_and_untracked_source_refused(self):
        (self.root / "source.txt").write_text("local modification\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not clean"):
            packet.clean_identity(self.root, self.head)
        self.git("checkout", "--", "source.txt")
        (self.root / "unexpected.gd").write_text("extends Node\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not clean"):
            packet.clean_identity(self.root, self.head)


class EngineControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / "synthetic.zip"
        self.names = ("main.exe", "console.exe")
        with zipfile.ZipFile(self.archive, "w") as archive:
            for name in self.names:
                data = b"synthetic byte-identity control: " + name.encode()
                archive.writestr(name, data)
                (self.root / name).write_bytes(data)
        self.pin = packet.digest(self.archive)

    def verify(self):
        return packet.verify_engine_files(self.archive, self.root / self.names[0], self.pin,
                                          "sha256", self.names, self.names[0])

    def test_bytes_authenticated_without_executing_engine(self):
        with mock.patch.object(subprocess, "run", side_effect=AssertionError("must not execute")), \
             mock.patch.object(subprocess, "Popen", side_effect=AssertionError("must not execute")):
            self.assertEqual(len(self.verify()["executables"]), 2)

    def test_modified_archive_or_binary_refused(self):
        original = self.archive.read_bytes()
        self.archive.write_bytes(original + b"unexpected bytes")
        with self.assertRaisesRegex(ValueError, "official pin"):
            self.verify()
        self.archive.write_bytes(original)
        (self.root / self.names[0]).write_bytes(b"stale executable")
        with self.assertRaisesRegex(ValueError, "differs from authenticated archive"):
            self.verify()

    def test_missing_or_replaced_companion_refused(self):
        companion = self.root / self.names[1]
        companion.write_bytes(b"different version probe")
        with self.assertRaisesRegex(ValueError, "differs from authenticated archive"):
            self.verify()
        companion.unlink()
        with self.assertRaisesRegex(ValueError, "companion is absent"):
            self.verify()

    def test_duplicate_archive_member_refused(self):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.archive, "a") as archive:
                archive.writestr(self.names[0], b"ambiguous member")
        self.pin = packet.digest(self.archive)
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.verify()


class PacketControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="manual's-packet-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.checkout = self.root / "checkout"
        self.checkout.mkdir()
        self.output = self.root / "local packet"
        self.identity = {"schema": packet.SCHEMA, "source": {"commit": "1" * 40, "tree": "2" * 40},
                         "checkout": str(self.checkout), "platform": "linux", "runtimes": {},
                         "host": {"system": "synthetic-test-only", "logical_cpus": 4},
                         "engine": {"version": "synthetic-test-only", "archive": str(self.root / "engine.zip"),
                                    "selected_executable": str(self.root / "synthetic engine")}}

    def test_all_cases_start_untested_and_cannot_overwrite(self):
        packet.write_packet(self.output, self.identity, {"status": "synthetic-test-only"})
        with (self.output / "RESULTS.csv").open(newline="", encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        self.assertEqual(len(rows), 51)
        self.assertEqual({row["status"] for row in rows}, {"untested"})
        self.assertEqual(len({row["case_id"] for row in rows}), len(rows))
        self.assertEqual({row["rig"] for row in rows} - {"all"}, {rig[0] for rig in packet.RIGS})
        for row in rows:
            self.assertTrue(row["procedure_and_expected"])
            self.assertEqual(row["evidence_files"], "")
        with self.assertRaisesRegex(ValueError, "already exists"):
            packet.write_packet(self.output, self.identity, {})

    def test_machine_packet_inside_checkout_refused(self):
        with self.assertRaisesRegex(ValueError, "outside the source"):
            packet.write_packet(self.checkout / "results", self.identity, {})
        self.assertFalse((self.checkout / "results").exists())

    def test_packet_tampering_refused_before_preflight(self):
        packet.write_packet(self.output, self.identity, {})
        (self.output / "launch.sh").write_text("changed command\n", encoding="utf-8")
        with mock.patch.object(packet, "collect", side_effect=AssertionError("must refuse first")):
            with self.assertRaisesRegex(ValueError, "Packet file changed"):
                packet.verify_packet(self.output)

    def test_launch_reverification_rejects_replaced_runtime(self):
        packet.write_packet(self.output, self.identity, {})
        with mock.patch.object(packet, "collect", return_value=(self.identity | {"runtimes": {"native": "changed"}}, {})):
            with self.assertRaisesRegex(ValueError, "identity changed"):
                packet.verify_packet(self.output)

    def test_edited_results_do_not_become_automated_acceptance(self):
        packet.write_packet(self.output, self.identity, {})
        (self.output / "RESULTS.csv").write_text("human-edited results\n", encoding="utf-8")
        with mock.patch.object(packet, "collect", return_value=(self.identity, {})):
            packet.verify_packet(self.output)
        self.assertNotIn("RESULTS.csv", json.loads((self.output / "MANIFEST.json").read_text()))
        self.assertIn("never executes Godot", (self.output / "CHECKLIST.md").read_text())

    def test_launch_reverification_rejects_changed_recorded_host(self):
        packet.write_packet(self.output, self.identity, {})
        fresh = self.identity | {"host": self.identity["host"] | {"logical_cpus": 8}}
        with mock.patch.object(packet, "collect", return_value=(fresh, {})):
            with self.assertRaisesRegex(ValueError, "recorded host identity changed"):
                packet.verify_packet(self.output)

    def test_windows_launcher_preserves_unicode_and_literal_apostrophes(self):
        identity = self.identity | {
            "platform": "windows", "checkout": "C:/Users/Zoë's folder/CyberSand",
            "engine": self.identity["engine"] | {"selected_executable": "C:/工具/Godot47/Godot_v4.7-stable_win64.exe"},
        }
        packet.write_packet(self.output, identity, {})
        data = (self.output / "launch.ps1").read_bytes()
        self.assertTrue(data.startswith(b"\xef\xbb\xbf"))
        script = data.decode("utf-8-sig")
        self.assertIn("Zoë''s folder", script)
        self.assertIn("C:/工具/Godot47/Godot_v4.7-stable_win64.exe", script)


if __name__ == "__main__":
    unittest.main(verbosity=2)
