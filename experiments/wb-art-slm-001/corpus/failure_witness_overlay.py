#!/usr/bin/env python3
"""TRAIN-only v4 diagnostic: restore an admitted coral m0 composition witness.

V3's first 400 draws contain two m6 coral compositions but *zero* m0 coral
compositions, although the frozen development failures include both m6 and m0
coral requests. Select one already native-admitted TRAIN trace at the same
modifier, theme and prompt form; do not change its program or receipts.
This file performs no optimizer work, native replay or final-set evaluation.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

OLD = 'coral-v3-m0-s17-p1'
NEW = 'coral-v4-m0-s17-p1'
V3_REPLAY_SHA256 = '4691ed900ba5ad0bcbb54243da990f5f07f4a7564511124e119f4934eb97f148'
TRAIN_SHA256 = '972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def ids_hash(rows: list[dict]) -> str:
    return sha(('\n'.join(r['id'] for r in rows) + '\n').encode())


def index_hash(indices: list[int]) -> str:
    return sha(('\n'.join(map(str, indices)) + '\n').encode())


def modifier(row: dict) -> int:
    m = re.fullmatch(r'[a-z]+-v\d+-m([0-7])-s\d+-p[01]', row['id'])
    if not m or row['native_case_id'] != row['id'][:-3]:
        raise ValueError('noncanonical original training row identity')
    return int(m.group(1))


def composed(row: dict) -> bool:
    program = json.loads(row['completion'])
    return len(program['layers']) > 1


def coral_witness_count(rows: list[dict], mod: int) -> int:
    return sum(r['theme'] == 'coral' and modifier(r) == mod and composed(r)
               for r in rows)


def overlay(v3_prefix: list[dict], source_rows: list[dict]) -> tuple[list[dict], dict]:
    """Swap one exact corpus record; reject missing/changed/native-unaudited inputs.

    Caller MUST first run load_and_verify on the pinned original archive, and
    verify V3_REPLAY_SHA256. These immutable source rows already have an admitted
    compiled-operation SHA and a source-identified passing native receipt.
    """
    if len(v3_prefix) != 400 or len(source_rows) != 1152:
        raise ValueError('incorrect admitted train/draw cardinality')
    source = {r['id']: r for r in source_rows}
    if len(source) != 1152 or source.get(OLD) is None or source.get(NEW) is None:
        raise ValueError('missing original native-admitted witness')
    old_positions = [i for i, row in enumerate(v3_prefix) if row['id'] == OLD]
    if len(old_positions) != 1 or any(r['id'] == NEW for r in v3_prefix):
        raise ValueError('v3 source witness positions changed')
    position = old_positions[0]
    if position < 12 or v3_prefix[position] != source[OLD]:
        raise ValueError('v3 source row differs from admitted archive')
    old, new = source[OLD], source[NEW]
    if (old['split'] != 'train' or new['split'] != 'train' or
            old['theme'] != new['theme'] or old['theme'] != 'coral' or
            modifier(old) != modifier(new) or modifier(new) != 0 or
            old['id'][-2:] != new['id'][-2:] or
            composed(old) or not composed(new) or
            json.loads(new['completion'])['layers'][0]['motif'] != 'fan'):
        raise ValueError('witness changed its admitted theme/modifier/phrasing/morphology')
    if coral_witness_count(v3_prefix, 0) != 0 or coral_witness_count(v3_prefix, 6) < 2:
        raise ValueError('v3 coral failure-control baseline changed')
    updated = list(v3_prefix)
    updated[position] = new
    for attribute in (lambda r: r['theme'], lambda r: r['id'][-2:],
                      lambda r: (r['theme'], modifier(r))):
        if Counter(map(attribute, v3_prefix)) != Counter(map(attribute, updated)):
            raise ValueError('replay changed protected theme/form/modifier exposure')
    if (updated[:12] != v3_prefix[:12] or
            len({r['native_case_id'] for r in updated}) != 376 or
            len({r['group_id'] for r in updated}) != 72 or
            coral_witness_count(updated, 0) != 1 or
            coral_witness_count(updated, 6) != coral_witness_count(v3_prefix, 6) or
            Counter(r['theme'] for r in updated if r['prompt'] == r['theme']) !=
            {t: 3 for t in ('coral', 'veins', 'ribs', 'mycelium', 'roots', 'strata',
                            'dunes', 'crystals', 'honeycomb', 'labyrinth', 'ruins',
                            'circuitry')}):
        raise ValueError('witness overlay breaks native-trace/structural/literal custody')
    return updated, {
        'draw_index': position, 'original_id': OLD, 'replacement_id': NEW,
        'original_program_sha256': old['program_sha256'],
        'replacement_program_sha256': new['program_sha256'],
        'original_operations_sha256': old['operations_sha256'],
        'replacement_operations_sha256': new['operations_sha256'],
        'original_group': old['group_id'], 'replacement_group': new['group_id'],
    }


def build(corpus_dir: Path, output_dir: Path) -> dict:
    import build_curriculum as base
    import build_modifier_replay as v3

    admission, _groups, traces = base.load_and_verify(corpus_dir)
    if admission['file_sha256']['train'] != TRAIN_SHA256:
        raise ValueError('original corpus source SHA differs')
    order = v3.modifier_order(traces)
    prefix, _displacements = v3.replay_prefix(order)
    if ids_hash(prefix) != V3_REPLAY_SHA256:
        raise ValueError('v3 replay is not the pinned immutable candidate')
    source_rows = [json.loads(x) for x in (corpus_dir / 'train.jsonl').read_text().splitlines()]
    updated, change = overlay(prefix, source_rows)
    source_index = {r['id']: i for i, r in enumerate(source_rows)}
    indices = [source_index[r['id']] for r in updated]
    manifest = {
        'schema_version': 1, 'name': 'coral-m0-composed-witness-v4',
        'status': 'TRAIN-only optional diagnostic; no new positives or model gain',
        'source_train_sha256': TRAIN_SHA256,
        'dev_custody_sha256': admission['file_sha256']['dev'],
        'final_custody_sha256': admission['file_sha256']['final'],
        'compiler_sha256': admission['compiler_sha256'],
        'native_source': admission['runtime']['source_commit'],
        'v3_replay_ids_sha256': V3_REPLAY_SHA256,
        'v4_replay_ids_sha256': ids_hash(updated),
        'v4_original_source_indices_sha256': index_hash(indices),
        'first400_draws': len(updated),
        'unique_native_traces': len({r['native_case_id'] for r in updated}),
        'structural_groups': len({r['group_id'] for r in updated}),
        'coral_m0_composed_before': 0, 'coral_m0_composed_after': 1,
        'coral_m6_composed_preserved': coral_witness_count(updated, 6),
        'theme_modifier_and_phrasing_counts': 'identical to pinned v3',
        'literal_examples_per_theme': 3, 'change': change,
        'interpretation': 'source-admitted TRAIN witness exposure, NOT development repair or model success',
        'index_space': '0-based original admitted train.jsonl; never modifier_train.jsonl',
        'optimizer_effect': 'none until Training opts into separately identified run',
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / 'v4_source_indices.json').write_text(json.dumps(indices, indent=2) + '\n')
    (output_dir / 'v4_manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    return manifest


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--corpus-dir', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    a = ap.parse_args()
    print(json.dumps(build(a.corpus_dir, a.out), indent=2))


if __name__ == '__main__':
    main()