#!/usr/bin/env python3
"""Local Git-object publication regressions; no remote, credential or ref write."""
from __future__ import annotations
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import prepare_publication as publication


class SourcePublication(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)/'repo';self.root.mkdir()
        self.run_git('init', '-q')
        self.run_git('config', 'user.name', 'synthetic publication fixture')
        self.run_git('config', 'user.email', 'fixture@example.invalid')
        for name in ('retained.txt', 'changed.txt', 'removed.txt', 'script.sh'):
            (self.root/name).write_text('baseline '+name+'\n')
        self.run_git('add', '.')
        self.run_git('commit', '-qm', 'synthetic baseline')
        self.base = self.run_git('rev-parse', 'HEAD').strip()
        (self.root/'changed.txt').write_bytes(b'changed\r\nexact bytes\x00\xff')
        (self.root/'same-content.txt').write_bytes((self.root/'changed.txt').read_bytes())
        (self.root/'removed.txt').unlink()
        (self.root/'script.sh').chmod(0o755)
        (self.root/'new-directory').mkdir()
        (self.root/'new-directory/symbolic').symlink_to('../changed.txt')
        self.run_git('add', '.')
        self.run_git('commit', '-qm', 'synthetic candidate')
        self.target = self.run_git('rev-parse', 'HEAD').strip()
        self.old = publication.BASELINES.copy()
        publication.BASELINES.update(native=self.base, workbench=self.base)

    def tearDown(self) -> None:
        publication.BASELINES.clear();publication.BASELINES.update(self.old)
        self.temp.cleanup()

    def run_git(self, *args: str, env: dict | None = None) -> str:
        return subprocess.check_output(['git', *args], cwd=self.root, text=True, env=env).strip()

    def prepare(self, **overrides) -> dict:
        arguments = dict(root=self.root, lane='native', first_parent=self.base, target=self.target,
                         output=Path(self.temp.name)/'publication', additional_parents=[], expected_remote_head=None, message=None)
        arguments.update(overrides)
        return publication.prepare(**arguments)

    def test_changed_blobs_modes_and_deletion_reconstruct_exact_target_tree(self) -> None:
        record = self.prepare()
        entries = {entry['path']: entry for entry in record['changed_paths']}
        self.assertNotIn('retained.txt', entries)
        self.assertIsNone(entries['removed.txt']['sha'])
        self.assertEqual('100755', entries['script.sh']['mode'])
        self.assertEqual('120000', entries['new-directory/symbolic']['mode'])
        self.assertEqual(entries['changed.txt']['sha'], entries['same-content.txt']['sha'])
        self.assertEqual(len({entry['sha'] for entry in entries.values() if entry['sha']}), len(record['blobs']))
        for blob in record['blobs']:
            content = base64.b64decode(Path(blob['base64_file']).read_text(), validate=True)
            original = subprocess.check_output(['git', 'cat-file', 'blob', blob['sha']], cwd=self.root)
            self.assertEqual(original, content)
        environment = dict(os.environ, GIT_INDEX_FILE=str(Path(self.temp.name)/'publication-test-index'))
        self.run_git('read-tree', self.base, env=environment)
        for entry in entries.values():
            if entry['sha'] is None:
                self.run_git('update-index', '--force-remove', '--', entry['path'], env=environment)
            else:
                self.run_git('update-index', '--add', '--cacheinfo', entry['mode'], entry['sha'], entry['path'], env=environment)
        self.assertEqual(record['expected_tree_sha'], self.run_git('write-tree', env=environment))
        self.assertEqual(self.run_git('rev-parse', self.target+'^{tree}'), record['expected_tree_sha'])
        self.assertEqual(self.base, record['first_parent_sha'])
        self.assertEqual(self.target, record['local_target_commit'])
        self.assertTrue(record['draft_hold'])
        self.assertEqual('experiment/gentek-swarm-006-native-recovery', record['branch'])
        self.assertEqual(record, json.loads((Path(self.temp.name)/'publication/manifest.json').read_text()))

    def test_dirty_worktree_and_untracked_source_are_refused(self) -> None:
        path = self.root/'changed.txt';original = path.read_bytes();path.write_bytes(b'not frozen')
        with self.assertRaisesRegex(ValueError, 'worktree must be clean'): self.prepare()
        path.write_bytes(original);(self.root/'untracked.cpp').write_text('not in target commit')
        with self.assertRaisesRegex(ValueError, 'worktree must be clean'): self.prepare()

    def test_existing_branch_requires_exact_lease_as_first_parent(self) -> None:
        with self.assertRaisesRegex(ValueError, 'leased head'): self.prepare(expected_remote_head=self.target)
        self.assertEqual(self.base, self.prepare(expected_remote_head=self.base)['expected_remote_head'])

    def test_workbench_requires_exact_native_additional_parent(self) -> None:
        with self.assertRaisesRegex(ValueError, 'frozen remote native parent'): self.prepare(lane='workbench')
        record = self.prepare(lane='workbench', additional_parents=[self.target])
        self.assertEqual([self.target], record['additional_parent_shas'])
        with self.assertRaisesRegex(ValueError, 'native lineage'):
            self.prepare(output=Path(self.temp.name)/'other', additional_parents=[self.target])


if __name__ == '__main__': unittest.main(verbosity=2)
