"""Reader replacement must retain execution provenance and refuse incomplete seals."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from verifier_revision import PREFIX, VERIFIER_FILES, revision_sources


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class ReaderRevisionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ('authority.json', 'result.json', 'inventory.json'):
            (self.root / name).write_text('{}\n', encoding='utf-8')
        self.authority = {'source_sha256': {PREFIX + name: '1' * 64 for name in VERIFIER_FILES}}
        self.result = {'source_commit': '2' * 40, 'source_tree': '3' * 40}
        self.revision = {
            'schema': 1, 'kind': 'mat003-readback-revision',
            'readback_only': True, 'candidate_processes_allowed': 0,
            'builds_allowed': 0, 'timing_allowed': False,
            'validation_class': 'author-validation-pending-independent-review',
            'owner_authorization': {'authorized': True, 'reference': 'test owner scope'},
            'evidence_sha256': {name: digest(self.root / name) for name in ('authority.json', 'result.json', 'inventory.json')},
            **self.result,
            'original_verifier_sha256': copy.deepcopy(self.authority['source_sha256']),
            'revised_verifier_sha256': {PREFIX + name: digest(Path(__file__).parent / name)
                                       for name in (*VERIFIER_FILES, 'verifier_revision.py')},
        }

    def run_revision(self, revision=None, seal=None):
        path = self.root / 'revision.json'
        path.write_text(json.dumps(self.revision if revision is None else revision), encoding='utf-8')
        return revision_sources(self.root, self.authority, self.result, path, seal or digest(path), digest)

    def test_complete_replacement_keeps_original_evidence_unchanged(self):
        before = {name: digest(self.root / name) for name in ('authority.json', 'result.json', 'inventory.json')}
        self.assertEqual(self.run_revision(), self.revision['revised_verifier_sha256'])
        self.assertEqual(before, {name: digest(self.root / name) for name in before})

    def test_changed_registration_bytes_fail_the_external_seal(self):
        with self.assertRaisesRegex(ValueError, 'revision seal mismatch'):
            self.run_revision(seal='0' * 64)

    def test_different_archive_control_or_original_reader_is_refused(self):
        for field in ('authority.json', 'result.json', 'inventory.json'):
            revision = copy.deepcopy(self.revision)
            revision['evidence_sha256'][field] = '0' * 64
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'different evidence'):
                self.run_revision(revision)
        revision = copy.deepcopy(self.revision)
        revision['original_verifier_sha256'][PREFIX + 'oracle.py'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'original source seals'):
            self.run_revision(revision)

    def test_missing_extra_and_changed_running_module_are_refused(self):
        for mutation in ('missing', 'extra', 'changed'):
            revision = copy.deepcopy(self.revision)
            sources = revision['revised_verifier_sha256']
            if mutation == 'missing':
                del sources[PREFIX + 'matrix.py']
            elif mutation == 'extra':
                sources['../escape.py'] = '0' * 64
            else:
                sources[PREFIX + 'world_oracle.py'] = '0' * 64
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, 'source (set|identity)'):
                self.run_revision(revision)

    def test_authority_cannot_expand_to_execution_or_independent_acceptance(self):
        for field, value in (('readback_only', False), ('candidate_processes_allowed', 1),
                             ('builds_allowed', 1), ('timing_allowed', True),
                             ('validation_class', 'independently-accepted')):
            revision = copy.deepcopy(self.revision)
            revision[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_revision(revision)

    def test_missing_owner_and_changed_collected_source_are_refused(self):
        for field in ('owner_authorization', 'source_commit', 'source_tree'):
            revision = copy.deepcopy(self.revision)
            del revision[field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_revision(revision)


if __name__ == '__main__':
    unittest.main()
