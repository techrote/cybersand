"""Real disposable promisor repositories; no external service or owner data."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('evidence_custody', ROOT/'tools/docs/evidence_custody.py')
subject = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(subject)


class PromisorCustody(unittest.TestCase):
    def git(self, directory, *arguments, input=None, env=None):
        return subprocess.check_output(['git', '-C', str(directory), *arguments], input=input,
                                       stderr=subprocess.PIPE, env=env)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='custody-promisor-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.origin = self.root/'origin'
        self.origin.mkdir()
        self.git(self.origin, 'init', '--quiet')
        self.git(self.origin, 'config', 'uploadpack.allowFilter', 'true')
        self.git(self.origin, 'config', 'uploadpack.allowAnySHAInWant', 'true')
        self.payload = b'Immutable disposable evidence specimen.\n'
        (self.origin/'evidence.md').write_bytes(self.payload)
        self.git(self.origin, 'add', 'evidence.md')
        self.git(self.origin, '-c', 'user.name=Custody Test', '-c', 'user.email=custody@invalid.example',
                 'commit', '--quiet', '-m', 'Disposable specimen')
        self.blob = self.git(self.origin, 'rev-parse', 'HEAD:evidence.md').decode().strip()
        self.clone = self.root/'partial'
        # file:// makes Git use its actual local upload-pack filter/transport.
        # The external network is never needed by this fixture.
        self.git(self.root, 'clone', '--quiet', '--filter=blob:none', '--no-checkout',
                 self.origin.as_uri(), str(self.clone))
        self.assertEqual(self.presence(), self.blob+' missing')

    def presence(self):
        return self.git(self.clone, 'cat-file', '--batch-check', input=(self.blob+'\n').encode(),
                        env=os.environ | {'GIT_NO_LAZY_FETCH': '1'}).decode().strip()

    def fetch_children(self, trace):
        events = [json.loads(line) for line in trace.read_text().splitlines()]
        return [event['argv'] for event in events
                if event.get('event') == 'child_start' and 'fetch' in event.get('argv', [])]

    def assert_missing_without_transport(self, action):
        trace = self.root/'guarded-trace.jsonl'
        # A caller cannot accidentally re-enable fetching through its inherited
        # environment; the custody helper controls this read-only boundary.
        with patch.dict(os.environ, {'GIT_TRACE2_EVENT': str(trace), 'GIT_NO_LAZY_FETCH': '0'}):
            with self.assertRaisesRegex(ValueError, 'unavailable locally; fetch explicitly'):
                action()
        self.assertEqual(self.fetch_children(trace), [])
        self.assertEqual(self.presence(), self.blob+' missing')

    def test_missing_tree_blob_refuses_without_implicit_transport(self):
        self.assert_missing_without_transport(lambda: subject.tree(self.clone, 'HEAD', 'evidence.md'))

    def test_missing_batch_blob_refuses_without_implicit_transport(self):
        self.assert_missing_without_transport(lambda: subject.read_blobs(self.clone, [{'git_blob': self.blob}]))

    def test_unguarded_git_control_really_fetches_the_promised_blob(self):
        trace = self.root/'unguarded-trace.jsonl'
        data = self.git(self.clone, 'cat-file', 'blob', self.blob,
                        env=os.environ | {'GIT_TRACE2_EVENT': str(trace), 'GIT_NO_LAZY_FETCH': '0'})
        self.assertEqual(data, self.payload)
        self.assertTrue(self.fetch_children(trace))
        self.assertNotIn('missing', self.presence())

    def test_explicit_targeted_fetch_restores_verified_local_reads(self):
        head = self.git(self.clone, 'rev-parse', 'HEAD')
        self.git(self.clone, 'fetch', '--no-tags', '--no-write-fetch-head', '--stdin', 'origin',
                 input=(self.blob+'\n').encode())
        rows = subject.tree(self.clone, 'HEAD', 'evidence.md')
        self.assertEqual(rows, [{'path': 'evidence.md', 'git_blob': self.blob, 'bytes': len(self.payload)}])
        self.assertEqual(subject.read_blobs(self.clone, rows), {self.blob: self.payload})
        self.assertEqual(self.git(self.clone, 'rev-parse', 'HEAD'), head)


if __name__ == '__main__':
    unittest.main()
