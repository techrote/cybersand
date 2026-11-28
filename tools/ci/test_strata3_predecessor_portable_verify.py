#!/usr/bin/env python3
"""Focused cross-host refusal controls, with optional original-corpus exercise."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

import strata3_predecessor_portable_verify as reader

SOURCE_REPO: Path | None = None
CAMPAIGN: Path | None = None
DRIVER = "qualify_workbench_strata3_predecessor.gd"


class BasenameControls(unittest.TestCase):
    def test_windows_dialect_keeps_exact_filename(self):
        for value in ("D:\\a\\observer\\" + DRIVER, "D:/a/observer/" + DRIVER,
                      "\\\\server\\share\\observer\\" + DRIVER):
            self.assertEqual(reader.recorded_command_name(value, "win32"), DRIVER)

    def test_wrong_suffix_prefix_and_case_are_not_accepted(self):
        for value in (DRIVER + ".bak", "other_" + DRIVER, DRIVER.upper(), "wrong_driver.gd"):
            self.assertNotEqual(reader.recorded_command_name("D:\\observer\\" + value, "win32"), DRIVER)

    def test_linux_does_not_reinterpret_windows_command(self):
        self.assertEqual(reader.recorded_command_name("/tmp/observer/" + DRIVER, "linux"), DRIVER)
        self.assertNotEqual(reader.recorded_command_name("D:\\observer\\" + DRIVER, "linux"), DRIVER)

    def test_invalid_or_unknown_dialect_fails_closed(self):
        for value, platform in (("", "win32"), ("x\x00y", "win32"), (DRIVER, "unknown")):
            with self.assertRaises(ValueError):
                reader.recorded_command_name(value, platform)

    def test_adapter_requires_exactly_one_frozen_site(self):
        source = "def verify(folder):\n    return Path(command[-1]).name == Path(observer['path']).name\n"
        original, adapted = reader.adapt_verify_source(source)
        self.assertEqual(adapted.replace(reader.NEW_EXPRESSION, reader.OLD_EXPRESSION), original)
        for altered in (source.replace(reader.OLD_EXPRESSION, "command[-1]"),
                        source.replace("return ", "return Path(command[-1]).name or ")):
            with self.assertRaisesRegex(ValueError, "basename expression changed"):
                reader.adapt_verify_source(altered)


class OriginalCorpusControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if SOURCE_REPO is None or CAMPAIGN is None:
            raise unittest.SkipTest("Supply --source-repo and --campaign for original-corpus refusal controls")

    def test_actual_original_receipt_is_admitted(self):
        result = reader.verify_portable(CAMPAIGN, SOURCE_REPO)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["reader_identity"]["application_source"], reader.APPLICATION)
        self.assertEqual(result["reader_identity"]["substitution_count"], 1)
        self.assertTrue(result["portable_reader_summary"]["classic_world_rgba8_identical"])
        if sys.platform != "win32" and result["recorded_platform"] == "win32":
            self.assertEqual(result["original_frozen_reader_outcome"], {
                "status": "rejected", "reason": "Observation did not execute the external graphical driver"})

    def test_rehashed_wrong_driver_is_still_refused(self):
        with tempfile.TemporaryDirectory(prefix="strata3-portable-reader-adverse-") as temporary:
            copy = Path(temporary) / "original-evidence-copy"
            shutil.copytree(CAMPAIGN, copy)
            record_path = copy / "comparison.json"
            record = json.loads(record_path.read_text(encoding="utf-8"))
            case = record["cases"][0]
            relative = case["label"] + "/process.json"
            process_path = copy / relative
            process = json.loads(process_path.read_text(encoding="utf-8"))
            process["command"][-1] = "D:\\a\\observer\\wrong_driver.gd"
            raw = (json.dumps(process, indent=2) + "\n").encode()
            process_path.write_bytes(raw)
            case["process"] = process
            record["files_sha256"][relative] = reader.digest(raw)
            record_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "Observation did not execute the external graphical driver"):
                reader.verify_portable(copy, SOURCE_REPO)

    def test_other_candidate_identity_is_refused(self):
        with tempfile.TemporaryDirectory(prefix="strata3-portable-reader-source-") as temporary:
            copy = Path(temporary) / "original-evidence-copy"
            shutil.copytree(CAMPAIGN, copy)
            path = copy / "comparison.json"
            record = json.loads(path.read_text(encoding="utf-8"))
            record["candidate_source"]["source_commit"] = "0" * 40
            path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "not the exact frozen fd identity"):
                reader.verify_portable(copy, SOURCE_REPO)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source-repo", type=Path)
    parser.add_argument("--campaign", type=Path)
    arguments, remaining = parser.parse_known_args()
    SOURCE_REPO, CAMPAIGN = arguments.source_repo, arguments.campaign
    unittest.main(argv=[sys.argv[0], *remaining])
