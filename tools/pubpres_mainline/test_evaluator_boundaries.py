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
import qualification


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

    def test_optional_generator_copies_cannot_override_canonical_recipes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            canonical = {'examples/worldgen/gen007-deepworks.json': b'{"seed":1}\n',
                         'examples/worldgen/gen007-qualification.json': b'{"seed":2}\n'}
            for name, payload in canonical.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(payload)
            def git(source, *args):
                self.assertEqual(source, root)
                return ('\n'.join(canonical) + '\n').encode() if args[0] == 'ls-tree' else canonical[args[1][5:]]
            project = root / 'godot'
            copies = project / 'authoring/worldgen'
            with mock.patch.object(common, 'git', side_effect=git):
                self.assertEqual(qualification.generator_profiles(root, project)['optional_copies_sha256'],
                                 {'source': {}, 'project': {}})
                copies.mkdir(parents=True)
                for name, payload in canonical.items():
                    (copies / Path(name).name).write_bytes(payload)
                self.assertEqual(len(qualification.generator_profiles(root, project)['canonical_sha256']), 2)
                changed = copies / 'gen007-deepworks.json'
                changed.write_bytes(b'{"seed":999}\n')
                with self.assertRaisesRegex(ValueError, 'differ from canonical'):
                    qualification.generator_profiles(root, project)
                changed.write_bytes(canonical['examples/worldgen/gen007-deepworks.json'])
                (copies / 'unregistered.json').write_text('{}')
                with self.assertRaisesRegex(ValueError, 'discovery population'):
                    qualification.generator_profiles(root, project)

    def test_delivery_replays_real_four_path_git_publication_and_refuses_later_pointer_change(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'source'
            runtime = Path(temporary) / 'runtime'
            root.mkdir(); runtime.mkdir()
            common.git(root, 'init', '--quiet')
            common.git(root, 'config', 'user.name', 'Publication fixture')
            common.git(root, 'config', 'user.email', 'fixture@example.invalid')
            common.git(root, 'config', 'core.autocrlf', 'false')
            paths = set(common.NATIVE.values()) | set(common.MANIFEST.values())
            for name in paths:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('original pointer or manifest\n')
            common.git(root, 'add', '.')
            common.git(root, 'commit', '--quiet', '-m', 'Original qualified source')
            parent = common.source_identity(root)
            original = {'source_commit': parent['source_commit'], 'source_inputs_sha256': {'native/example.cpp': 'd'*64},
                        'runtime_sha256': 'a'*64, 'runtime_bytes': 17}
            common.write_json(runtime / 'PUBPRES-RUNTIME.json', original)
            for platform in ('linux', 'windows'):
                binary = {'sha256': 'a'*64 if platform == 'windows' else 'b'*64, 'size': 17}
                pointer = ('version https://git-lfs.github.com/spec/v1\noid sha256:' + binary['sha256'] + '\nsize 17\n')
                (root / common.NATIVE[platform]).write_text(pointer)
                manifest = {'kind': 'source-matched-pubpres-mainline-draft-runtime', 'status': 'validated-development-runtime',
                    'source_input_hash_kind': 'sha256-canonical-lf', 'source_commit': parent['source_commit'],
                    'build_commit': parent['source_commit'], 'source_inputs': original['source_inputs_sha256'],
                    'artifact': common.NATIVE[platform], **binary,
                    'publication_branch': evaluator.campaign_request.BRANCH,
                    'publication_workflow': '.github/workflows/pubpres-mainline.yml',
                    'publication_source_comparison': {'publication_parent': parent['source_commit'],
                        'publication_parent_tree': parent['source_tree'], 'qualified_source': parent['source_commit'],
                        'production_and_qualification_bytes_identical': True},
                    'build_custody': {'source': parent['source_commit'], 'run': 1, 'attempt': 1,
                                     'manifest_sha256': common.digest(runtime / 'PUBPRES-RUNTIME.json')},
                    'qualification': {'source': parent['source_commit'], 'run': 2, 'attempt': 1},
                    'publication_run': '3', 'publication_attempt': '1'}
                common.write_json(root / common.MANIFEST[platform], manifest)
            common.git(root, 'add', '.')
            common.git(root, 'commit', '--quiet', '-m', 'Publish exactly four runtime paths')
            publication = common.source_identity(root)['source_commit']
            selected = {'schema': 'pubpres-mainline-request-v2', 'phase': 'delivery', 'purpose': 'Boundary fixture',
                'accepted_main': common.ACCEPTED_MAIN, 'owner_reference': common.OWNER_REFERENCE,
                'payload_sha256': '0'*64, 'runtime_run': 1, 'runtime_attempt': 1,
                'runtime_source': parent['source_commit'], 'qualification_run': 2, 'qualification_attempt': 1,
                'qualification_source': parent['source_commit'], 'publication_commit': publication,
                'physical_acceptance': 'HOLD', 'promotion': 'DRAFT_ONLY'}
            def seal_delivery():
                entries = common.git(root, 'ls-tree', '-r', '-z', 'HEAD').split(b'\0')
                selected['payload_sha256'] = hashlib.sha256(b'\0'.join(row for row in entries if row
                    and row.split(b'\t', 1)[1].decode() != evaluator.campaign_request.REQUEST) + b'\0').hexdigest()
                common.write_json(root / evaluator.campaign_request.REQUEST, selected)
                common.git(root, 'add', '.')
                common.git(root, 'commit', '--quiet', '-m', 'Seal delivery source')
            seal_delivery()
            result = evaluator.publication_identity(root, runtime)
            self.assertEqual(result['commit'], publication)
            self.assertTrue(result['current_production_pointers_retained'])
            (root / common.NATIVE['windows']).write_text('another runtime pointer\n')
            common.git(root, 'add', '.')
            common.git(root, 'commit', '--quiet', '-m', 'Unexpected later runtime change')
            seal_delivery()
            with self.assertRaisesRegex(ValueError, 'changed a published runtime blob'):
                evaluator.publication_identity(root, runtime)


if __name__ == '__main__':
    unittest.main()
