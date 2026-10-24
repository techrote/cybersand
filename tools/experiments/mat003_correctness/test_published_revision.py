"""Verify the actual immutable v4 publication against full historical Git bytes.

This is a static publication check, not a repeat of the spent 152-case readback
or independent verification of the self-attested owner authorization.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

from verifier_revision import PREFIX, VERIFIER_FILES

ROOT = Path(__file__).resolve().parents[3]
REGISTRATION = ROOT / 'docs/audits/mat003-overnight-2026-10-24/readback-registration-v4.json'
SEAL = 'b7d44256b4dc585f80afdd559f51fbd0d24a75d11aaf19fafdf64c56b54e07a4'
ORIGINAL = 'e655166989661617cd8d6cb4d58a71b9d88c9467'
REVISED = '610325422fc0cec496cf098990c40d5d4c292411'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], timeout=15)


class PublishedRevision(unittest.TestCase):
    def test_actual_registration_and_both_historical_reader_maps(self):
        raw = REGISTRATION.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), SEAL)
        revision = json.loads(raw)
        self.assertEqual(revision['source_commit'], ORIGINAL)
        self.assertEqual(revision['reader_source_commit'], REVISED)
        self.assertEqual(git('rev-parse', ORIGINAL + '^{tree}').decode().strip(), revision['source_tree'])
        for field, commit, names in (
                ('original_verifier_sha256', ORIGINAL, VERIFIER_FILES),
                ('revised_verifier_sha256', REVISED, (*VERIFIER_FILES, 'verifier_revision.py'))):
            expected = {PREFIX + name: hashlib.sha256(git('show', commit + ':' + PREFIX + name)).hexdigest()
                        for name in names}
            self.assertEqual(revision[field], expected)
        # The executable revised modules must still be the separately sealed set.
        for name, seal in revision['revised_verifier_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), seal, name)


if __name__ == '__main__':
    unittest.main()
