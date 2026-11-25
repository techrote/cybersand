#!/usr/bin/env python3
"""Exercise actual PowerShell collection with synthetic run files.

The narrow verifier double supplies only a synthetic package identity. These
tests do not qualify package integrity, executable bytes or a Windows runtime;
the installed-package lane executes the real verifier and shipped command.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

HERE = Path(__file__).resolve().parent
POWERSHELL = os.environ.get("PUBPRES_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")
CANDIDATE = "3" * 40
MANIFEST = "PUBPRES-PLAYABILITY-MANIFEST.json"
VERIFIER = r'''
param([switch]$Library,[string]$PackageRoot,[string]$ExpectedCandidate)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$script:PPManifestName = 'PUBPRES-PLAYABILITY-MANIFEST.json'
$script:PPUtf8 = [Text.UTF8Encoding]::new($false)
function Assert-PP([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Get-PPHash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Read-PPJson([string]$Path) { [IO.File]::ReadAllText($Path) | ConvertFrom-Json }
function Get-PPField($Object,[string]$Name) { if ($null -ne $Object.PSObject.Properties[$Name]) { $Object.$Name } }
function Test-PPPackage([string]$Root,[string]$Candidate) {
    $Value = Read-PPJson (Join-Path $Root $script:PPManifestName)
    Assert-PP ($Value.candidate_commit -ceq $Candidate) 'Synthetic candidate mismatch'
    return $Value
}
'''


@unittest.skipUnless(POWERSHELL, "PowerShell is required for actual collector execution")
class CollectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.package = self.root / "Package"
        self.package.mkdir()
        self.manifest = self.package / MANIFEST
        self.manifest.write_text(json.dumps({"schema": "pubpres-completion-windows-v1", "candidate_commit": CANDIDATE}))
        verifier = self.package / "tools/pubpres_playability_windows/Start-PUBPRES-Playability.ps1"
        verifier.parent.mkdir(parents=True)
        verifier.write_text(VERIFIER)
        self.run = self.root / "Runs/matching"
        self.run.mkdir(parents=True)
        self.record = {"candidate_commit": CANDIDATE, "package_manifest_sha256": self.sha(self.manifest.read_bytes())}
        self.put("run.json", json.dumps(self.record))

    def tearDown(self):
        self.temp.cleanup()

    @staticmethod
    def sha(data):
        return hashlib.sha256(data).hexdigest()

    def put(self, name, value="fixture\n"):
        path = self.run / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
        return path

    def collect(self):
        completed = subprocess.run([str(POWERSHELL), "-NoLogo", "-NoProfile", "-File",
                                    str(HERE / "Collect-PUBPRES-Results.ps1"), "-PackageRoot", str(self.package),
                                    "-ExpectedCandidate", CANDIDATE], capture_output=True, text=True, timeout=90)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        archives = list((self.root / "Runs/Reports").glob("*.zip"))
        self.assertEqual(len(archives), 1)
        path = archives[0]
        self.assertEqual(path.with_suffix(".zip.sha256").read_text(), self.sha(path.read_bytes()) + "  " + path.name + "\n")
        with zipfile.ZipFile(path) as archive:
            self.assertIsNone(archive.testzip())
            index = json.loads(archive.read("INDEX.json"))
            self.assertEqual(index["physical_acceptance"], "HOLD")
            self.assertEqual(set(archive.namelist()), {item["file"] for item in index["files"]} | {"INDEX.json"})
            for item in index["files"]:
                content = archive.read(item["file"])
                self.assertEqual((len(content), self.sha(content)), (item["bytes"], item["sha256"]))
        return index

    def test_matching_receipts_saved_starts_and_whitelist(self):
        paths = [self.put("ready-a.json", "{}"), self.put("launches/one/stdout.log"),
                 self.put("profile/logs/godot.log"), self.put("profile/workbench/authored.json"),
                 self.put("profile/engine-lab-example.json")]
        self.put("profile/private-unrelated.cfg", "not included")
        self.put("profile/cache/logs/large.log", "not included")
        foreign = self.root / "Runs/foreign"
        foreign.mkdir()
        (foreign / "run.json").write_text(json.dumps({**self.record, "candidate_commit": "4" * 40}))
        (foreign / "ready-other.json").write_text("not included")
        notes = self.root / "Runs/OWNER-ACCEPTANCE.md"
        notes.write_text("NOT RUN\n")
        snapshots = {p: p.read_bytes() for p in paths + [notes, self.manifest]}
        index = self.collect()
        self.assertEqual(index["matched_runs"], ["matching"])
        names = {item["file"] for item in index["files"]}
        self.assertIn("runs/matching/profile/workbench/authored.json", names)
        self.assertIn("OWNER-ACCEPTANCE.md", names)
        self.assertFalse(any("private-unrelated" in name or "cache/" in name or "foreign/" in name for name in names))
        self.assertEqual(index["omitted"], [])
        self.assertTrue(all(p.read_bytes() == content for p, content in snapshots.items()))

    def test_file_and_count_capacity_is_explicit(self):
        oversized = self.put("profile/logs/oversized.log")
        with oversized.open("r+b") as stream:
            stream.truncate(17 * 1024 * 1024)
        for n in range(530):
            self.put(f"profile/logs/{n:04}.log")
        index = self.collect()
        self.assertEqual(len(index["files"]), 512)
        self.assertLessEqual(index["total_bytes"], 128 * 1024 * 1024)
        self.assertTrue(any(item["file"].endswith("oversized.log") for item in index["omitted"]))
        self.assertTrue(all(item["bytes"] <= 16 * 1024 * 1024 for item in index["files"]))
        self.assertEqual(oversized.stat().st_size, 17 * 1024 * 1024)

    def test_directory_entry_enumeration_is_bounded(self):
        for n in range(8250):
            self.put(f"profile/irrelevant/{n:05}.txt", "")
        index = self.collect()
        self.assertEqual(index["visited_entries"], index["entry_limit"])
        self.assertTrue(any(item["file"] == "unvisited entries" for item in index["omitted"]))
        self.assertLessEqual(len(index["files"]), 512)

    def test_unrelated_root_files_still_consume_traversal_budget(self):
        for n in range(8250):
            (self.root / "Runs" / f"irrelevant-{n:05}.txt").touch()
        index = self.collect()
        self.assertEqual(index["visited_entries"], index["entry_limit"])
        self.assertTrue(any(item["file"] == "unvisited entries" for item in index["omitted"]))

    def test_invalid_or_oversized_run_identity_is_preserved_and_reported(self):
        invalid = self.root / "Runs/damaged"
        invalid.mkdir()
        path = invalid / "run.json"
        path.write_text("{broken")
        oversized = self.root / "Runs/oversized"
        oversized.mkdir()
        large = oversized / "run.json"
        with large.open("wb") as stream:
            stream.truncate(9 * 1024 * 1024)
        index = self.collect()
        self.assertEqual(index["matched_runs"], ["matching"])
        self.assertTrue(any(item["file"] == "runs/damaged/run.json" for item in index["omitted"]))
        self.assertTrue(any(item["file"] == "runs/oversized/run.json" for item in index["omitted"]))
        self.assertEqual(path.read_text(), "{broken")
        self.assertEqual(large.stat().st_size, 9 * 1024 * 1024)


if __name__ == "__main__":
    unittest.main()
