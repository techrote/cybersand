"""Offline/adversarial readback/guide tests. No native/model dependencies."""
import io
import json
import struct
import unittest
from hashlib import sha256
from zipfile import ZipFile, ZIP_DEFLATED
from experiments.driv3r.stage_d.guidance import native_pair_shadow as s


class RetrospectiveGuardTests(unittest.TestCase):
    def _world_zip(self, *, changed: bool, wrong_world=False, bad_delta=False):
        before = bytearray(512 * 512 * 4)
        x, y = 12, 23
        off = 4 * (y * 512 + x)
        after = before[:]
        if changed:
            struct.pack_into('<i', after, off, 58)
        if bad_delta:
            struct.pack_into('<i', after, 4 * (y * 512 + x + 1), 58)
        name = 'readback-000005-after.world.i32le'
        resp = {'observation': {'world_material_path': name}}
        payload = io.BytesIO()
        with ZipFile(payload, 'w', compression=ZIP_DEFLATED) as z:
            z.writestr('execution/native/readback-000005-before.world.i32le', before)
            z.writestr('execution/native/' + name, after)
        payload.seek(0)
        return payload, {'request_id': 5}, resp, sha256(before).hexdigest(), (
            'f' * 64 if wrong_world else sha256(after).hexdigest())

    def test_real_one_cell_delta_and_brush_up_exact_bytes(self):
        for changed in (True, False):
            with self.subTest(changed=changed):
                payload, req, resp, b, a = self._world_zip(changed=changed)
                with ZipFile(payload) as z:
                    s._verify_world_readback(z, req, resp, b, a, [12, 23] if changed else None)

    def test_forbids_source_hash_substitution(self):
        payload, req, resp, b, a = self._world_zip(changed=True, wrong_world=True)
        with ZipFile(payload) as z, self.assertRaisesRegex(ValueError, 'source bytes mismatch'):
            s._verify_world_readback(z, req, resp, b, a, [12, 23])

    def test_forbids_second_unreceipted_material_edit(self):
        payload, req, resp, b, a = self._world_zip(changed=True, bad_delta=True)
        with ZipFile(payload) as z, self.assertRaisesRegex(ValueError, 'sole expected'):
            s._verify_world_readback(z, req, resp, b, a, [12, 23])

    def test_forbids_lifted_cursor_material_change(self):
        payload, req, resp, b, a = self._world_zip(changed=True)
        with ZipFile(payload) as z, self.assertRaisesRegex(ValueError, 'lifted cursor changed'):
            s._verify_world_readback(z, req, resp, b, a, None)

    def test_numerical_field_outside_is_neutral_not_permission(self):
        guide = {'frame': [4, 5, 2, 2]}
        data = struct.pack('<4H', 0, 20000, 40000, 65535)
        self.assertEqual(s._guide_at(data, guide, [4, 5]), 0)
        self.assertEqual(s._guide_at(data, guide, [5, 6]), 65535)
        self.assertEqual(s._guide_at(data, guide, [3, 5]), 0)
        self.assertEqual(s._guide_at(data, guide, [6, 5]), 0)

    def test_original_guide_sha_must_match_raw_u16_bytes(self):
        guide = {'protocol': 'cybersand.driv3r.d-common/1',
                 'encoding': 'u16le_higher_is_better_zero_is_neutral',
                 'native_material_authority': False, 'type': 'guidance',
                 'purpose': 'soft_positive_preference', 'frame': [4, 5, 2, 2],
                 'values': {'path': 'guide/positive.u16le', 'format': 'u16le',
                            'bytes': 8, 'sha256': 'a' * 64}}
        stream = io.BytesIO()
        with ZipFile(stream, 'w') as z:
            z.writestr('execution/original-guide.json', json.dumps(guide))
            z.writestr('execution/guide/positive.u16le', b'\x00' * 8)
        stream.seek(0)
        with ZipFile(stream) as z, self.assertRaisesRegex(ValueError, 'guide byte custody'):
            s._load_guide(z)

    def test_unauthorised_material_guide_rejected(self):
        guide = {'protocol': 'cybersand.driv3r.d-common/1',
                 'encoding': 'u16le_higher_is_better_zero_is_neutral',
                 'native_material_authority': True, 'type': 'guidance',
                 'purpose': 'soft_positive_preference', 'frame': [4, 5, 2, 2],
                 'values': {'path': 'guide/positive.u16le', 'format': 'u16le',
                            'bytes': 8, 'sha256': sha256(b'\x00' * 8).hexdigest()}}
        stream = io.BytesIO()
        with ZipFile(stream, 'w') as z:
            z.writestr('execution/original-guide.json', json.dumps(guide))
            z.writestr('execution/guide/positive.u16le', b'\x00' * 8)
        stream.seek(0)
        with ZipFile(stream) as z, self.assertRaisesRegex(ValueError, 'guide semantics'):
            s._load_guide(z)

    def test_rejects_invalid_arm_or_count(self):
        for mode, count in [('invalid', 36), ('free', 0), ('soft', 37), ('free', True)]:
            with self.subTest(mode=mode, count=count), self.assertRaisesRegex(ValueError, 'arm/count'):
                s.audit_arm('/not-found', mode, count)


if __name__ == '__main__':
    unittest.main()
