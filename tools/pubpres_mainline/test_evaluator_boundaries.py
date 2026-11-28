"""Adversarial delivery boundaries; no fake gameplay or native completion tests."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile
import common
import package as evaluator
import launcher


class DeliveryBoundaries(unittest.TestCase):
    def test_windows_path_rejects_escape_alias_and_device_names(self):
        for name in ('../escape', '/absolute', 'C:/escape', 'a\\b', 'a//b', 'a/./b',
                     'a/../b', 'a/trailing.', 'a/trailing ', 'a/NUL', 'a/COM1.txt',
                     'a/stream:alternate', 'a/control\x01', ''):
            with self.subTest(name=name), self.assertRaises(ValueError):
                evaluator.safe(name)
        self.assertEqual(evaluator.safe('nested (owner)/Ω/full source.json').as_posix(),
                         'nested (owner)/Ω/full source.json')

    def test_archive_external_digest_and_duplicate_members_refuse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / 'fixture.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('one.txt', b'one')
                archive.writestr('ONE.txt', b'two')
            with self.assertRaisesRegex(ValueError, 'SHA-256'):
                evaluator.extract(path, root / 'wrong-digest', '0' * 64)
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                evaluator.extract(path, root / 'duplicate', common.digest(path))
            self.assertFalse((root / 'wrong-digest').exists())

    def test_archive_path_escape_refuses_before_writing_outside(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / 'fixture.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('../escape.txt', b'untrusted')
            with self.assertRaises(ValueError):
                evaluator.extract(path, root / 'unpack', common.digest(path))
            self.assertFalse((root / 'escape.txt').exists())

    def test_archive_requires_complete_pristine_reader_after_crc(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / 'fixture.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('data.txt', b'original bytes')
            with mock.patch.object(evaluator, 'verify', side_effect=ValueError('unqualified payload')) as reader:
                with self.assertRaisesRegex(ValueError, 'unqualified payload'):
                    evaluator.extract(path, root / 'unpack', common.digest(path))
                reader.assert_called_once()
            self.assertEqual((root / 'unpack/data.txt').read_bytes(), b'original bytes')

    def test_collector_exports_diagnostics_and_excludes_authored_profile(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name, raw in {
                evaluator.MANIFEST: b'{"source":"example"}',
                evaluator.MANIFEST + '.sha256': b'fixture checksum',
                'diagnostics/run/import.log': b'Godot observed',
                'diagnostics/run/launch.json': b'{"status":"clean-exit"}',
                'userdata/roaming/Godot/app_userdata/Cyber Sand/workbench/pubpres-gameplay/segment-0.jsonl': b'{"type":"draw"}\n',
                'userdata/roaming/Godot/app_userdata/Cyber Sand/workbench/authored-private.json': b'PRIVATE AUTHORED DATA',
                'userdata/roaming/Godot/app_userdata/Cyber Sand/persistent-areas/world.cypm': b'PRIVATE WORLD',
            }.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            target = root / 'collected.zip'
            with mock.patch.object(evaluator, 'read_manifest', return_value={'source_commit': 'a'*40, 'source_tree': 'b'*40}):
                launcher.collect(root, target)
            with zipfile.ZipFile(target) as archive:
                names = archive.namelist()
                self.assertTrue(any(name.endswith('.jsonl') for name in names))
                self.assertFalse(any('authored-private' in name or 'world.cypm' in name for name in names))
                receipt = json.loads(archive.read('COLLECTION.json'))
                self.assertFalse(receipt['uploads_performed'])
                for name, identity in receipt['files'].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), identity['sha256'])
                    self.assertEqual(len(archive.read(name)), identity['bytes'])

    def test_selected_environment_removes_unregistered_architecture_options(self):
        actual = common.selected_environment({'CYBERSAND_DIAG_FAKE': '1',
            'CYBERSAND_WORKBENCH_COUPLING_CLOCK': '0', 'CYBERSAND_PLAYABILITY_RENDER_THREAD': 'separate',
            'PATH': 'portable tools'})
        self.assertNotIn('CYBERSAND_DIAG_FAKE', actual)
        self.assertEqual(actual['CYBERSAND_WORKBENCH_COUPLING_CLOCK'], '1')
        self.assertEqual(actual['CYBERSAND_PLAYABILITY_RENDER_THREAD'], 'safe')
        self.assertEqual(actual['PATH'], 'portable tools')
        self.assertEqual(actual['CYBERSAND_DIAG_FULL_IMAGE_SLOTS'], '2')


if __name__ == '__main__':
    unittest.main()
