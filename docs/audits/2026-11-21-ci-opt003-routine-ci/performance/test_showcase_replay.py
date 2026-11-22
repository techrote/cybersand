#!/usr/bin/env python3
"""Independent synthetic controls for exact raw showcase replay; not execution evidence."""
import argparse
from pathlib import Path
import sys
import unittest

parser = argparse.ArgumentParser()
parser.add_argument("--proof-directory", type=Path, required=True)
parser.add_argument("--repository", type=Path, required=True)
args = parser.parse_args()
sys.path.insert(0, str(args.proof_directory.resolve()))
import test_compare_pair as fixtures
import audit_showcase_replay as audit

fixtures.REPOSITORY = args.repository.resolve()

class ReplayControls(fixtures.ReaderControls):
    def setUp(self):
        super().setUp()
        self.load("candidate")
        self.make_fixture()

    def run_audit(self):
        return audit.audit(self.directory, 101, 1)

    def test_exact(self):
        self.assertEqual(len(self.run_audit()["logs"]), 14)

    def test_resealed_inconsistent_body(self):
        path = self.root / "source/build/worldgen-showcase-logs/test_megatruss_station.log"
        path.write_text(path.read_text().replace("synthetic showcase complete", "unrelated output"))
        self.reseal()
        self.verify()  # Reproduces admission by the unchanged frozen reader.
        with self.assertRaisesRegex(ValueError, "complete replay group"):
            self.run_audit()

    def test_raw_failure(self):
        path = self.root / "source/build/worldgen-showcase-logs/test_megatruss_station_sanitized.log"
        path.write_text(path.read_text() + "ERROR: AddressSanitizer: synthetic failure\n")
        self.reseal()
        self.verify()
        with self.assertRaisesRegex(ValueError, "Failure marker"):
            self.run_audit()

    def test_duplicate_replay(self):
        raw = (self.root / "source/build/worldgen-showcase-logs/test_megatruss_station.log").read_bytes()
        path = self.folder / "commands/worldgen-test/command.log"
        path.write_bytes(path.read_bytes() + raw)
        with self.assertRaisesRegex(ValueError, "duplicate context"):
            self.run_audit()

    def test_wrong_attempt(self):
        with self.assertRaisesRegex(ValueError, "Wrong context"):
            audit.audit(self.directory, 101, 2)

names = ["test_exact", "test_resealed_inconsistent_body", "test_raw_failure",
         "test_duplicate_replay", "test_wrong_attempt"]
result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(ReplayControls(name) for name in names))
raise SystemExit(not result.wasSuccessful())

