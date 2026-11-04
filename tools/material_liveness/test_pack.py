import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import pack


class EvidenceTransportTests(unittest.TestCase):
    def fixture(self, root):
        source = root / 'raw'
        source.mkdir()
        # Deliberately incomplete raw output must survive without becoming a pass.
        (source / 'case.stdout').write_bytes(b'{"type":"tick","tick":35')
        (source / 'case.stderr').write_bytes(b'\xff\x00retained failure\n')
        (source / 'campaign.json').write_text('{"status":"FAILED"}\n')
        (source / 'binary.exe').write_bytes(b'not part of source evidence')
        return source

    def test_failed_raw_round_trip_and_excluded_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fixture(root)
            result = pack.pack(source, root / 'transport', 'failed')
            restored = root / 'restored'
            pack.unpack(root / 'transport/failed.manifest.json', restored)
            self.assertEqual(len(result['files']), 3)
            self.assertEqual((restored / 'case.stdout').read_bytes(), (source / 'case.stdout').read_bytes())
            self.assertEqual((restored / 'case.stderr').read_bytes(), (source / 'case.stderr').read_bytes())
            self.assertFalse((restored / 'binary.exe').exists())

    def test_modified_shard_refused_before_raw_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pack.pack(self.fixture(root), root / 'transport', 'failed')
            shard = root / 'transport/failed.000.json'
            shard.write_bytes(shard.read_bytes() + b' ')
            with self.assertRaisesRegex(ValueError, 'shard identity'):
                pack.unpack(root / 'transport/failed.manifest.json', root / 'restored')
            self.assertFalse((root / 'restored').exists())

    def test_member_rehash_cannot_hide_payload_tamper(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pack.pack(self.fixture(root), root / 'transport', 'failed')
            shard_path = root / 'transport/failed.000.json'
            shard = json.loads(shard_path.read_text())
            shard['files'][0]['sha256'] = '0' * 64
            data = json.dumps(shard).encode()
            shard_path.write_bytes(data)
            manifest_path = root / 'transport/failed.manifest.json'
            manifest = json.loads(manifest_path.read_text())
            manifest['shards'][0].update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            manifest_path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'differs from manifest'):
                pack.unpack(manifest_path, root / 'restored')

    def test_overwrite_and_unsafe_names_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fixture(root)
            pack.pack(source, root / 'transport', 'failed')
            with self.assertRaisesRegex(ValueError, 'prefix exists'):
                pack.pack(source, root / 'transport', 'failed')
            with self.assertRaises(ValueError):
                pack.pack(source, root / 'other', '../escape')
            destination = root / 'restored'
            destination.mkdir()
            (destination / 'user.txt').write_text('preserve')
            with self.assertRaisesRegex(ValueError, 'not empty'):
                pack.unpack(root / 'transport/failed.manifest.json', destination)
            self.assertEqual((destination / 'user.txt').read_text(), 'preserve')

    def test_oversized_or_truncated_stream_refused(self):
        import base64
        import zlib
        raw = b'fixture' * 100
        entry = {'name': 'sample.stdout', 'bytes': len(raw), 'sha256': pack.sha(raw),
                 'zlib_base64': base64.b64encode(zlib.compress(raw)).decode()}
        self.assertEqual(pack.decode_entry(entry), raw)
        bad = copy.deepcopy(entry)
        bad['bytes'] = 1
        with self.assertRaises(ValueError):
            pack.decode_entry(bad)
        bad = copy.deepcopy(entry)
        bad['zlib_base64'] = base64.b64encode(zlib.compress(raw)[:-2]).decode()
        with self.assertRaises(ValueError):
            pack.decode_entry(bad)


if __name__ == '__main__':
    unittest.main()
