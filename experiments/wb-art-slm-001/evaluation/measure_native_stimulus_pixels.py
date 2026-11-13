#!/usr/bin/env python3
"""Measure real native model-review PNG pixels without opening the sealed theme key.

Exploratory *development-stimulus* diagnostics, never a theme-recognition or
current-source native/Windows qualification. The two seeds are repeated samples
of each original request, not independent structural templates.
"""
from __future__ import annotations

import argparse
import base64
from collections import defaultdict
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import statistics
import struct
import zlib

SIGNATURE = b"\x89PNG\r\n\x1a\n"
BACKGROUND = (13, 21, 28)
FOREGROUND = (232, 226, 205)
WIDTH = HEIGHT = 96
NEAR_JACCARD = 0.85  # Both aligned host seeds must independently exceed this.
TOKEN = re.compile(r'\bconst\s+token\s*=\s*"([0-9a-f]{64})"\s*;')
SEED = re.compile(r'^Unlabeled native material readback, host seed (17|73)$')
ID = re.compile(r'q[0-9]{3,}')


class StimulusError(ValueError):
    pass


class Gallery(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.cards: dict[str, list[tuple[int, bytes]]] = {}
        self.active: str | None = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'article':
            ident = a.get('data-id', '')
            if self.active is not None or not ID.fullmatch(ident) or ident in self.cards:
                raise StimulusError('duplicate, nested or invalid card ID')
            self.active = ident
            self.cards[ident] = []
        elif tag == 'img':
            if self.active is None:
                raise StimulusError('image outside a card')
            match = SEED.fullmatch(a.get('alt', ''))
            src = a.get('src', '')
            if not match or not src.startswith('data:image/png;base64,'):
                raise StimulusError('unbound host seed or external image')
            try:
                blob = base64.b64decode(src.partition(',')[2], validate=True)
            except (ValueError, base64.binascii.Error) as exc:
                raise StimulusError('bad image base64') from exc
            self.cards[self.active].append((int(match.group(1)), blob))

    def handle_endtag(self, tag):
        if tag == 'article':
            if self.active is None:
                raise StimulusError('orphan card closing tag')
            self.active = None


def pixels(blob: bytes) -> frozenset[int]:
    """Independent bounded RGB8 PNG/CRC/filter decoder; exact native display palette."""
    if not blob.startswith(SIGNATURE) or len(blob) > 128_000:
        raise StimulusError('not a bounded PNG')
    at, ihdr, compressed, ended, saw_data = 8, False, bytearray(), False, False
    while at < len(blob):
        if at + 12 > len(blob):
            raise StimulusError('short PNG chunk')
        size = struct.unpack_from('>I', blob, at)[0]
        end = at + 12 + size
        if end > len(blob) or size > 128_000:
            raise StimulusError('oversized or truncated PNG chunk')
        kind, body = blob[at + 4:at + 8], blob[at + 8:at + 8 + size]
        recorded_crc = struct.unpack_from('>I', blob, at + 8 + size)[0]
        if zlib.crc32(kind + body) & 0xffffffff != recorded_crc:
            raise StimulusError('PNG CRC mismatch')
        if not ihdr:
            if kind != b'IHDR' or size != 13 or struct.unpack('>IIBBBBB', body) != (96, 96, 8, 2, 0, 0, 0):
                raise StimulusError('not native 96x96 RGB8 PNG')
            ihdr = True
        elif kind == b'IDAT':
            compressed.extend(body)
            saw_data = True
        elif kind == b'sRGB':
            if size != 1:
                raise StimulusError('invalid PNG sRGB chunk')
        elif kind == b'IEND':
            if size != 0 or not saw_data or end != len(blob):
                raise StimulusError('incomplete PNG end')
            ended = True
            break
        else:
            raise StimulusError('unexpected PNG chunk in frozen native stimulus')
        at = end
    if not ended:
        raise StimulusError('missing PNG end')
    row_bytes = WIDTH * 3
    length = HEIGHT * (row_bytes + 1)
    stream = zlib.decompressobj()
    try:
        raw = stream.decompress(bytes(compressed), length + 1)
        raw += stream.flush(length + 1 - len(raw))
    except (zlib.error, ValueError) as exc:
        raise StimulusError('invalid compressed PNG pixels') from exc
    if len(raw) != length or not stream.eof or stream.unused_data or stream.unconsumed_tail:
        raise StimulusError('truncated/oversized PNG pixel stream')
    foreground: set[int] = set()
    prior = bytearray(row_bytes)
    for y in range(HEIGHT):
        start = y * (row_bytes + 1)
        filt, current = raw[start], bytearray(raw[start + 1:start + 1 + row_bytes])
        if filt > 4:
            raise StimulusError('unsupported PNG row filter')
        for x in range(row_bytes):
            left = current[x - 3] if x >= 3 else 0
            up = prior[x]
            upper_left = prior[x - 3] if x >= 3 else 0
            if filt == 1:
                current[x] = (current[x] + left) & 255
            elif filt == 2:
                current[x] = (current[x] + up) & 255
            elif filt == 3:
                current[x] = (current[x] + (left + up) // 2) & 255
            elif filt == 4:
                p = left + up - upper_left
                da, db, dc = abs(p-left), abs(p-up), abs(p-upper_left)
                predictor = left if da <= db and da <= dc else up if db <= dc else upper_left
                current[x] = (current[x] + predictor) & 255
        for x in range(WIDTH):
            rgb = tuple(current[x*3:x*3+3])
            if rgb == FOREGROUND:
                foreground.add(y * WIDTH + x)
            elif rgb != BACKGROUND:
                raise StimulusError('unexpected native display palette value')
        prior = current
    if not foreground:
        raise StimulusError('empty native model image; not positive artwork')
    return frozenset(foreground)


def jaccard(left: frozenset[int], right: frozenset[int]) -> float:
    return len(left & right) / len(left | right)


def measure(html: Path, expected_sha256: str) -> dict:
    original = html.read_bytes()
    source_sha = hashlib.sha256(original).hexdigest()
    if not re.fullmatch('[0-9a-f]{64}', expected_sha256) or source_sha != expected_sha256:
        raise StimulusError('frozen stimulus HTML SHA-256 mismatch')
    page = original.decode('utf-8')
    if len(TOKEN.findall(page)) != 1:
        raise StimulusError('missing or repeated review token')
    cards = Gallery(); cards.feed(page); cards.close()
    if cards.active is not None or not cards.cards:
        raise StimulusError('incomplete or empty gallery')
    keys = sorted(cards.cards)
    if keys != [f'q{i:03d}' for i in range(1, len(keys)+1)]:
        raise StimulusError('missing or nonconsecutive image card IDs')
    decoded: dict[str, tuple[frozenset[int], frozenset[int]]] = {}
    png_hashes: dict[str, tuple[str, str]] = {}
    for ident in keys:
        pair = cards.cards[ident]
        if len(pair) != 2 or [s for s, _ in pair] != [17, 73]:
            raise StimulusError('expected host seeds 17 and 73 once each')
        decoded[ident] = (pixels(pair[0][1]), pixels(pair[1][1]))
        png_hashes[ident] = tuple(hashlib.sha256(blob).hexdigest() for _, blob in pair)
    per_card, all_density, all_j = [], [], []
    for ident in keys:
        a, b = decoded[ident]
        ja = jaccard(a, b)
        densities = (len(a) / (WIDTH*HEIGHT), len(b) / (WIDTH*HEIGHT))
        all_density.extend(densities); all_j.append(ja)
        per_card.append({'id': ident, 'seed_17_cells': len(a), 'seed_73_cells': len(b),
                         'seed_pair_jaccard': round(ja, 6),
                         'seed_pair_changed_cell_fraction': round(len(a ^ b)/(WIDTH*HEIGHT), 6)})
    near = []
    for i, left in enumerate(keys):
        for right in keys[i+1:]:
            p = [jaccard(a, b) for a, b in zip(decoded[left], decoded[right])]
            if min(p) >= NEAR_JACCARD:
                near.append({'cards': [left, right], 'seed_17_jaccard': round(p[0], 6),
                             'seed_73_jaccard': round(p[1], 6),
                             'exact_png_pair': png_hashes[left] == png_hashes[right]})
    parents = {name: name for name in keys}
    def root(name):
        while parents[name] != name:
            name = parents[name]
        return name
    for pair in near:
        left, right = map(root, pair['cards'])
        parents[right] = left
    groups = defaultdict(list)
    for name in keys:
        groups[root(name)].append(name)
    repeated = sorted((group for group in groups.values() if len(group) > 1), key=lambda x: x[0])
    return {
        'scope': 'frozen LFM step-400 model-output native material-display PNGs; exploratory, blind, Linux pilot only',
        'html_sha256': source_sha, 'labels_opened': False,
        'cards': len(keys), 'displayed_native_images': 2*len(keys), 'host_seeds': [17, 73],
        'density_fraction': {'min': round(min(all_density), 6),
                             'median': round(statistics.median(all_density), 6),
                             'max': round(max(all_density), 6)},
        'within_request_seed_jaccard': {'min': round(min(all_j), 6),
                                        'median': round(statistics.median(all_j), 6),
                                        'mean': round(statistics.mean(all_j), 6),
                                        'max': round(max(all_j), 6),
                                        'below_0_2': sum(x < 0.2 for x in all_j),
                                        'at_least_0_8': sum(x >= 0.8 for x in all_j)},
        'exploratory_near_duplicate_rule': 'Aligned-seed foreground-cell Jaccard >=0.85 for BOTH seeds',
        'cross_request_near_pairs': near,
        'near_duplicate_clusters': repeated,
        'distinct_near_stimulus_clusters': len(groups),
        'admitted_display_cards': len(keys),
        'original_request_denominator_not_established_by_stimulus': True,
        'interpretation': 'Pixel morphology similarity is not blind human theme recognition, aesthetics, model semantic correctness or distinct structural templates',
        'per_card_blind_metrics': per_card,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--html', required=True, type=Path)
    parser.add_argument('--expected-html-sha256', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args(argv)
    report = measure(args.html, args.expected_html_sha256)
    formatted = json.dumps(report, indent=2) + '\n'
    if args.output:
        if args.output.exists():
            parser.error('refuse to overwrite previous stimulus audit')
        args.output.write_text(formatted, encoding='utf-8')
    print(formatted, end='')


if __name__ == '__main__':
    main()
