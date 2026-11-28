"""Admission refuses foreign artifacts and failed resulting-source gates."""
import copy
import json
from pathlib import Path
import unittest
import reextract


class MetadataTests(unittest.TestCase):
    def setUp(self):
        self.request = json.loads((Path(reextract.__file__).resolve().parents[2] / reextract.REQUEST).read_bytes())
        r = self.request
        self.run = dict(id=r['run_id'], run_attempt=r['run_attempt'], head_sha=r['application_commit'],
                        head_branch=reextract.BRANCH, event='push', path='.github/workflows/pubpres-mainline.yml')
        self.artifact = dict(id=r['artifact_id'], name=r['artifact_name'], expired=False,
                             size_in_bytes=r['outer_bytes'], digest='sha256:' + r['outer_sha256'],
                             workflow_run=dict(id=r['run_id'], head_sha=r['application_commit']))
        focuses = ('frozen', 'water', 'members', 'held-placement', 'mainline', 'native-owner',
                   'selected-water', 'selected-members', 'selected-held-placement')
        names = ['admission', 'source-gates', 'Complete source-exact Windows evaluator']
        names += ['qualification-' + p + '-' + f for p in ('linux', 'windows') for f in focuses]
        names += ['features-' + p + '-' + m for p in ('linux', 'windows') for m in ('ramcache', 'strata', 'shared')]
        self.jobs = dict(total_count=27, jobs=[dict(id=i+1, name=n, status='completed', conclusion='success') for i,n in enumerate(names)])

    def validate(self):
        return reextract.validate_metadata(self.request, self.run, self.artifact, self.jobs)

    def test_complete_original_population(self):
        self.assertEqual(len(self.validate()), 27)

    def test_foreign_artifact_identity(self):
        for field, value in [('id', 1), ('name', 'foreign'), ('expired', True), ('size_in_bytes', 1), ('digest', 'sha256:'+'0'*64)]:
            with self.subTest(field=field):
                original = copy.deepcopy(self.artifact)
                self.artifact[field] = value
                with self.assertRaises(ValueError):
                    self.validate()
                self.artifact = original

    def test_foreign_application_or_run(self):
        for field, value in [('head_sha', '0'*40), ('run_attempt', 2), ('id', 1), ('head_branch', 'main'), ('path', 'foreign.yml')]:
            with self.subTest(field=field):
                original = copy.deepcopy(self.run)
                self.run[field] = value
                with self.assertRaises(ValueError):
                    self.validate()
                self.run = original

    def test_missing_duplicate_failed_or_skipped_gate(self):
        original = copy.deepcopy(self.jobs)
        for mode in ('missing', 'duplicate', 'failure', 'skipped'):
            with self.subTest(mode=mode):
                self.jobs = copy.deepcopy(original)
                if mode == 'missing':
                    self.jobs['jobs'].pop()
                elif mode == 'duplicate':
                    self.jobs['jobs'].append(copy.deepcopy(self.jobs['jobs'][0]))
                else:
                    self.jobs['jobs'][0]['conclusion'] = mode
                with self.assertRaises(ValueError):
                    self.validate()

    def test_archive_bound_to_source(self):
        self.artifact['workflow_run']['head_sha'] = '0'*40
        with self.assertRaises(ValueError):
            self.validate()


if __name__ == '__main__':
    unittest.main()
