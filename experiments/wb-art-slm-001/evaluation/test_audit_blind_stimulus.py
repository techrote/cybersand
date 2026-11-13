"""Regression/adversarial controls for blind image-stimulus custody and repetition."""
from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from audit_blind_stimulus import audit, StimulusError

TOKEN = "a" * 64


def png(color):
    """One valid native-sized RGB PNG, using only stdlib."""
    def chunk(kind, contents):
        return struct.pack(">I", len(contents)) + kind + contents + struct.pack(">I", zlib.crc32(kind + contents))
    raw = (b"\x00" + bytes(color) * 96) * 96
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 96, 96, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def html(cards):
    records = []
    for i, seeds in enumerate(cards, 1):
        imgs = "".join(f'<img alt="Unlabeled native material readback, host seed {seed}" '
                       f'src="data:image/png;base64,{base64.b64encode(data).decode()}">'
                       for seed, data in seeds)
        records.append(f'<article data-id="q{i:03d}">{imgs}</article>')
    return '<html>' + ''.join(records) + f'<script>const token="{TOKEN}";</script></html>'


class StimulusAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "review.html"
        self.key_path = Path(self.temp.name) / "key.json"
        self.a, self.b = png((1, 2, 3)), png((4, 5, 6))
        self.c, self.d = png((7, 8, 9)), png((10, 11, 12))
        self.cards = [[(17, self.a), (73, self.b)], [(17, self.a), (73, self.b)],
                      [(17, self.c), (73, self.d)]]

    def tearDown(self):
        self.temp.cleanup()

    def put(self, doc=None):
        self.path.write_text(html(self.cards) if doc is None else doc, encoding="utf-8")
        return self.path

    def key(self):
        items = []
        for i, pair in enumerate(self.cards, 1):
            items.append({"id": f"q{i:03d}", "seeds": [17, 73],
                          "png_sha256": [hashlib.sha256(data).hexdigest() for _, data in pair],
                          "prediction_id": f"dev-{i}", "group_id": "g1" if i <= 2 else "g2"})
        key = {"schema_version": 1, "review_token": TOKEN, "native_admitted_requests": 3,
               "original_requests": 4, "first_pass_rejected": 1, "items": items}
        self.key_path.write_text(json.dumps(key), encoding="utf-8")
        return key

    def test_exact_duplicate_cards_preserve_original_denominator(self):
        self.put(); self.key()
        result = audit(self.path, self.key_path, hashlib.sha256(self.path.read_bytes()).hexdigest())
        self.assertEqual(result["review_cards"], 3)
        self.assertEqual(result["distinct_image_sha256"], 4)
        self.assertEqual(result["distinct_exact_image_pairs"], 2)
        self.assertEqual(result["duplicate_image_pair_cards"], [["q001", "q002"]])
        self.assertEqual(result["extra_duplicate_card_exposures"], 1)
        self.assertEqual(result["source_original_requests"], 4)
        self.assertEqual(result["source_first_pass_rejected"], 1)
        self.assertEqual(result["same_structural_group_duplicate_pairs"], 1)
        self.assertTrue(result["key_checked"])

    def test_different_review_html_is_refused(self):
        self.put()
        with self.assertRaisesRegex(StimulusError, "differs from frozen"):
            audit(self.path, expected_html_sha256="0" * 64)

    def test_wrong_seed_or_remote_image_fails_closed(self):
        original = html(self.cards)
        for changed in (original.replace("host seed 17", "host seed 18", 1),
                        original.replace("data:image/png;base64,", "https://untrusted.example/", 1),
                        original.replace("data:image/png;base64,", "data:image/jpeg;base64,", 1)):
            with self.subTest(changed=changed[:60]):
                self.put(changed)
                with self.assertRaises(StimulusError):
                    audit(self.path)

    def test_duplicate_card_and_bad_base64_refused(self):
        original = html(self.cards)
        for changed in (original.replace('data-id="q002"', 'data-id="q001"'),
                        original.replace("data:image/png;base64,i", "data:image/png;base64,!", 1)):
            self.put(changed)
            with self.assertRaises(StimulusError):
                audit(self.path)

    def test_key_image_or_token_mutation_refused(self):
        self.put(); key = self.key()
        for mutation in (lambda k: k["items"][0]["png_sha256"].__setitem__(0, "0" * 64),
                         lambda k: k.update(review_token="b" * 64),
                         lambda k: k["items"][1].update(id="q001"),
                         lambda k: k.update(original_requests=3)):
            data = json.loads(json.dumps(key)); mutation(data)
            self.key_path.write_text(json.dumps(data))
            with self.assertRaises(StimulusError):
                audit(self.path, self.key_path)

    def test_cross_structural_collision_flagged_not_hidden(self):
        self.put(); key = self.key(); key["items"][1]["group_id"] = "g3"
        self.key_path.write_text(json.dumps(key))
        report = audit(self.path, self.key_path)
        self.assertEqual(report["cross_structural_group_duplicate_cards"], [["q001", "q002"]])
        self.assertEqual(report["same_structural_group_duplicate_pairs"], 0)


if __name__ == "__main__":
    unittest.main()
