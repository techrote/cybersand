#!/usr/bin/env python3
"""Independently audit the *stimulus*, not recognition, in a native-image review.

A pixel-identical pair displayed for two language requests is two requests but
only one distinct visual stimulus. Keep both original request denominators; do
not silently deduplicate model failures or relabel historical evidence.

This offline reader consumes the exported standalone HTML. The optional separate
answer key is for custody binding AFTER the rater has frozen their responses.
No training, model inference, native execution, or final-set data is accessed.
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
import struct

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
TOKEN = re.compile(r'\bconst\s+token\s*=\s*"([0-9a-f]{64})"\s*;')
ID = re.compile(r"q[0-9]{3,}")
SHA = re.compile(r"[0-9a-f]{64}")
SEED_ALT = re.compile(r"^Unlabeled native material readback, host seed (\d+)$")


class StimulusError(ValueError):
    pass


class _Cards(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.cards: dict[str, list[tuple[int, str, int, int]]] = {}
        self.active: str | None = None

    def handle_starttag(self, tag, attrs):
        fields = dict(attrs)
        if tag == "article":
            qid = fields.get("data-id", "")
            if self.active is not None or not ID.fullmatch(qid) or qid in self.cards:
                raise StimulusError("duplicate, malformed or nested review card")
            self.active = qid
            self.cards[qid] = []
        elif tag == "img":
            if self.active is None:
                raise StimulusError("unbound review image")
            match = SEED_ALT.fullmatch(fields.get("alt", ""))
            source = fields.get("src", "")
            if match is None or not source.startswith("data:image/png;base64,"):
                raise StimulusError("unlabelled, external or non-PNG image")
            try:
                binary = base64.b64decode(source.split(",", 1)[1], validate=True)
            except (ValueError, base64.binascii.Error) as exc:
                raise StimulusError("invalid native image base64") from exc
            if len(binary) < 24 or not binary.startswith(PNG_SIGNATURE) or binary[12:16] != b"IHDR":
                raise StimulusError("invalid PNG signature or IHDR")
            width, height = struct.unpack(">II", binary[16:24])
            if (width, height) != (96, 96):
                raise StimulusError("unexpected native material crop dimensions")
            self.cards[self.active].append((int(match.group(1)), hashlib.sha256(binary).hexdigest(), width, height))

    def handle_endtag(self, tag):
        if tag == "article":
            if self.active is None:
                raise StimulusError("orphan article end")
            self.active = None


def audit(html: Path, key_path: Path | None = None, expected_html_sha256: str | None = None) -> dict:
    original = html.read_bytes()
    source_sha = hashlib.sha256(original).hexdigest()
    if expected_html_sha256 is not None and (
        not SHA.fullmatch(expected_html_sha256) or source_sha != expected_html_sha256
    ):
        raise StimulusError("review HTML differs from frozen original")
    try:
        text = original.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise StimulusError("HTML must be UTF-8") from exc
    tokens = TOKEN.findall(text)
    if len(tokens) != 1:
        raise StimulusError("missing or duplicated review token")
    parser = _Cards()
    parser.feed(text)
    parser.close()
    if parser.active is not None or not parser.cards:
        raise StimulusError("incomplete or empty review cards")
    expected_ids = [f"q{i:03d}" for i in range(1, len(parser.cards) + 1)]
    if sorted(parser.cards) != expected_ids:
        raise StimulusError("missing or nonconsecutive review card ID")
    by_pair: dict[tuple[str, str], list[str]] = defaultdict(list)
    single_images: set[str] = set()
    card_hashes: dict[str, list[str]] = {}
    for qid in expected_ids:
        images = parser.cards[qid]
        if [x[0] for x in images] != [17, 73]:
            raise StimulusError("native pairs must use host seeds 17 then 73")
        pair = (images[0][1], images[1][1])
        by_pair[pair].append(qid)
        single_images.update(pair)
        card_hashes[qid] = list(pair)
    duplicates = [cards for cards in by_pair.values() if len(cards) > 1]
    report = {
        "scope": "historical Linux headless native display PNGs; no model/native/recognition rerun",
        "html_sha256": source_sha,
        "review_token": tokens[0],
        "review_cards": len(expected_ids),
        "images_in_cards": len(expected_ids) * 2,
        "distinct_image_sha256": len(single_images),
        "distinct_exact_image_pairs": len(by_pair),
        "duplicate_image_pair_cards": duplicates,
        "extra_duplicate_card_exposures": len(expected_ids) - len(by_pair),
        "interpretation": "Duplicate images reduce distinct visual stimuli, not first-pass model request denominators",
        "key_checked": False,
    }
    if key_path is not None:
        key = json.loads(key_path.read_text(encoding="utf-8"))
        if key.get("review_token") != tokens[0] or key.get("schema_version") != 1:
            raise StimulusError("answer key not bound to this stimulus")
        if key.get("native_admitted_requests") != len(expected_ids) or (
            key.get("original_requests") != key.get("native_admitted_requests", 0) + key.get("first_pass_rejected", -1)
        ):
            raise StimulusError("raw-request and native-admitted denominators do not close")
        items = key.get("items")
        if not isinstance(items, list) or len(items) != len(expected_ids) or (
            len({x.get("id") for x in items}) != len(expected_ids)
        ):
            raise StimulusError("answer key card inventory differs")
        lookup = {item["id"]: item for item in items}
        if set(lookup) != set(expected_ids):
            raise StimulusError("answer key missing stimulus items")
        for qid in expected_ids:
            item = lookup[qid]
            if item.get("seeds") != [17, 73] or item.get("png_sha256") != card_hashes[qid]:
                raise StimulusError("answer key/native displayed PNG hash mismatch: " + qid)
            if not item.get("prediction_id") or not item.get("group_id"):
                raise StimulusError("missing prediction or structural group identity")
        cross_groups = [cards for cards in duplicates
                        if len({lookup[qid]["group_id"] for qid in cards}) > 1]
        report.update(key_checked=True,
                      source_original_requests=key["original_requests"],
                      source_first_pass_rejected=key["first_pass_rejected"],
                      same_structural_group_duplicate_pairs=len(duplicates) - len(cross_groups),
                      cross_structural_group_duplicate_cards=cross_groups,
                      distinct_original_prediction_ids=len({x["prediction_id"] for x in items}))
    return report


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--html", required=True, type=Path)
    p.add_argument("--expected-html-sha256", help="Require the exact frozen review HTML")
    p.add_argument("--post-review-key", type=Path, help="Optional key custody; keep sealed until review finished")
    p.add_argument("--output", type=Path, help="Write an audit JSON file without changing the stimulus")
    args = p.parse_args(argv)
    result = audit(args.html, args.post_review_key, args.expected_html_sha256)
    value = json.dumps(result, indent=2) + "\n"
    if args.output:
        if args.output.exists():
            p.error("refuse to overwrite a previous audit")
        args.output.write_text(value, encoding="utf-8")
    print(value, end="")


if __name__ == "__main__":
    main()
