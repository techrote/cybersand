"""Adversarial pixel-level tests, with no model, native or blind answer-key access."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
from measure_native_stimulus_pixels import measure, pixels, StimulusError, BACKGROUND, FOREGROUND


def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)


def image(cells, *, palette=FOREGROUND, filt=0):
    raw = bytearray()
    for y in range(96):
        raw.append(filt)
        for x in range(96):
            raw.extend(palette if y*96+x in cells else BACKGROUND)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 96, 96, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def document(cards):
    rows = []
    for i, pair in enumerate(cards, 1):
        imgs = ''.join(f'<img alt="Unlabeled native material readback, host seed {seed}" src="data:image/png;base64,{base64.b64encode(blob).decode()}">' for seed, blob in pair)
        rows.append(f'<article data-id="q{i:03d}">{imgs}</article>')
    return '<html>' + ''.join(rows) + '<script>const token="' + 'a'*64 + '";</script></html>'


class PixelAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'review.html'
        self.one = image({1, 2, 3})
        self.two = image({2, 3, 4})
        self.other = image({100, 200})
        self.cards = [[(17,self.one),(73,self.two)], [(17,self.one),(73,self.two)], [(17,self.other),(73,self.other)]]

    def tearDown(self):
        self.temp.cleanup()

    def run_audit(self, cards=None, doc=None):
        value = document(self.cards if cards is None else cards) if doc is None else doc
        self.path.write_text(value, encoding='utf-8')
        return measure(self.path, hashlib.sha256(self.path.read_bytes()).hexdigest())

    def test_identical_pairs_not_independent_requests(self):
        result=self.run_audit()
        self.assertEqual(result['cards'],3)
        self.assertEqual(result['original_request_count_unchanged'],36)
        self.assertEqual(result['distinct_near_stimulus_clusters'],2)
        self.assertEqual(result['near_duplicate_clusters'],[['q001','q002']])
        self.assertEqual(result['cross_request_near_pairs'][0]['exact_png_pair'],True)
        self.assertEqual(result['per_card_blind_metrics'][0]['seed_pair_jaccard'],0.5)

    def test_untrusted_or_wrong_host_seed_refused(self):
        doc=document(self.cards)
        for bad in (doc.replace('host seed 17','host seed 71',1),
                    doc.replace('data:image/png;base64,','https://example.invalid/',1),
                    doc.replace('data-id="q002"','data-id="q001"',1)):
            with self.subTest(case=bad[:20]):
                with self.assertRaises(StimulusError):self.run_audit(doc=bad)

    def test_png_crc_and_compressed_corruption_refused(self):
        damaged=bytearray(self.one)
        damaged[-12-10] ^= 1
        with self.assertRaises(StimulusError):pixels(bytes(damaged))
        broken=self.one[:-6]
        with self.assertRaises(StimulusError):pixels(broken)
        with self.assertRaises(StimulusError):pixels(self.one+b'garbage')

    def test_invalid_palette_filter_and_empty_refused(self):
        with self.assertRaises(StimulusError):pixels(image({1},palette=(255,0,0)))
        with self.assertRaises(StimulusError):pixels(image({1},filt=5))
        with self.assertRaises(StimulusError):pixels(image(set()))

    def test_wrong_frozen_html_hash_fails_closed(self):
        self.path.write_text(document(self.cards))
        with self.assertRaisesRegex(StimulusError,'SHA-256 mismatch'):
            measure(self.path,'0'*64)

    def test_reject_wrong_card_count_or_double_seed(self):
        cards=[[(17,self.one),(17,self.two)]]
        with self.assertRaises(StimulusError): self.run_audit(cards=cards)
        cards=[[(17,self.one)]]
        with self.assertRaises(StimulusError): self.run_audit(cards=cards)


if __name__ == '__main__':unittest.main()