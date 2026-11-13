#!/usr/bin/env python3
"""Turn the pinned v3 replay into indices for the ORIGINAL admitted TRAIN file.

Do not pass modifier_train.jsonl as --train to the existing trainer: its
admission hash is deliberately different. This file performs no training.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def lines(path: Path) -> list[dict]:
    data = path.read_bytes()
    if not data.endswith(b'\n') or b'\r' in data:
        raise ValueError(f'noncanonical JSONL line endings: {path.name}')
    return [json.loads(line) for line in data.splitlines()]


def index_hash(indices: list[int]) -> str:
    return sha(('\n'.join(map(str, indices)) + '\n').encode())


def ids_hash(rows: list[dict]) -> str:
    return sha(('\n'.join(r['id'] for r in rows) + '\n').encode())


def validated_plan(source: list[dict], ordered: list[dict], src: list[int],
                   dest: list[int], recorded: dict) -> dict:
    """Reconcile both index spaces before handing original source indices to Training.

    The caller must separately verify the pinned archive receipt and exact
    ordered-file/manifest hashes. This function also compares complete row
    objects so same IDs with different completions cannot pass.
    """
    if len(source) != 1152 or len(ordered) != 1152 or len(src) != 400 or len(dest) != 400:
        raise ValueError('source/order/replay record counts changed')
    source_ids = [r['id'] for r in source]
    ordered_ids = [r['id'] for r in ordered]
    if (len(set(source_ids)) != 1152 or len(set(ordered_ids)) != 1152 or
            set(source_ids) != set(ordered_ids)):
        raise ValueError('candidate membership/uniqueness differs from admitted train')
    by_id = {r['id']: r for r in source}
    if any(by_id[r['id']] != r for r in ordered):
        raise ValueError('reordered row differs from original admitted target/receipt')
    if (ids_hash(ordered) != recorded['ordered_ids_sha256'] or
            index_hash(src) != recorded['replay_400_source_indices_sha256'] or
            index_hash(dest) != recorded['replay_400_ordered_indices_sha256']):
        raise ValueError('v3 replay/order digest differs from pinned manifest')
    for i, j in zip(src, dest):
        if (type(i) is not int or type(j) is not int or
                not 0 <= i < len(source) or not 0 <= j < len(ordered)):
            raise ValueError('invalid replay index or index-space confusion')
        if source[i] != ordered[j]:
            raise ValueError('source/ordered index-space confusion or altered target')
    draws = [source[i] for i in src]
    if ids_hash(draws) != recorded['replay_400_ids_sha256']:
        raise ValueError('v3 replay draw IDs differ from pinned manifest')
    if (len({r['id'] for r in draws}) != 376 or
            len({r['native_case_id'] for r in draws}) != 376 or
            len({r['group_id'] for r in draws}) != 72 or
            Counter(r['theme'] for r in draws if r['prompt'] == r['theme']) !=
            {t: 3 for t in ('coral','veins','ribs','mycelium','roots','strata',
                            'dunes','crystals','honeycomb','labyrinth','ruins','circuitry')}):
        raise ValueError('v3 literal/group/native-trace exposure changed')
    actual_mod = Counter()
    by_theme_mod = {}
    for row in draws:
        match = re.fullmatch(r'([a-z]+)-v\d+-m([0-7])-s\d+', row['native_case_id'])
        if match is None or match.group(1) != row['theme']:
            raise ValueError('invalid native modifier identity')
        theme, modifier = match.group(1), match.group(2)
        actual_mod[modifier] += 1
        by_theme_mod.setdefault(theme, Counter())[modifier] += 1
    if (dict(sorted(actual_mod.items())) != recorded['modifier_counts'] or
            {t: {str(m): c.get(str(m), 0) for m in range(8)}
             for t, c in by_theme_mod.items()} != recorded['per_theme_modifier_counts'] or
            dict(sorted(Counter(r['id'][-2:] for r in draws).items())) != recorded['phrasing_counts']):
        raise ValueError('modifier/theme/phrasing exposure differs from pinned evidence')
    return {
        'schema_version': 1,
        'name': 'wb-art-slm-corpus-v3-original-source-index-plan',
        'source_file': 'train.jsonl',
        'source_train_sha256': recorded['train_sha256'],
        'ordered_file': 'modifier_train.jsonl (audit only; NOT an admitted training source)',
        'ordered_jsonl_sha256': recorded['ordered_jsonl_sha256'],
        'compiler_sha256': recorded['compiler_sha256'],
        'native_source': recorded['native_source'],
        'replay_ids_sha256': recorded['replay_400_ids_sha256'],
        'first_400_source_indices_sha256': index_hash(src),
        'draws': 400,
        'unique_native_traces': 376,
        'independent_structural_groups': 72,
        'indexes_are_zero_based': True,
        'indices': src,
        'use': 'opt-in sampler only; preserve admitted input file and checkpoint policy; no optimizer run executed',
    }


def build(corpus_dir: Path, candidate_dir: Path, out: Path) -> dict:
    # Full TRAIN native operation/receipt custody is checked before accepting a plan.
    import build_curriculum as base
    admission, _, _ = base.load_and_verify(corpus_dir)
    recorded = json.loads((candidate_dir / 'curriculum_manifest.json').read_text())
    frozen = json.loads((Path(__file__).parent / 'curriculum_modifier_replay_v3.json').read_text())
    if recorded != frozen or recorded['train_sha256'] != admission['file_sha256']['train']:
        raise ValueError('v3 pinned manifest/admitted TRAIN source mismatch')
    if sha((corpus_dir / 'train.jsonl').read_bytes()) != recorded['train_sha256']:
        raise ValueError('original admitted train input replaced')
    if sha((candidate_dir / 'modifier_train.jsonl').read_bytes()) != recorded['ordered_jsonl_sha256']:
        raise ValueError('v3 ordered JSONL bytes differ from pinned manifest')
    source = lines(corpus_dir / 'train.jsonl')
    ordered = lines(candidate_dir / 'modifier_train.jsonl')
    src = json.loads((candidate_dir / 'replay_first400_source_indices.json').read_text())
    dest = json.loads((candidate_dir / 'replay_first400_ordered_indices.json').read_text())
    plan = validated_plan(source, ordered, src, dest, recorded)
    payload = json.dumps(plan, indent=2, sort_keys=True) + '\n'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(payload, encoding='utf-8')
    return {'plan_sha256': sha(payload.encode('utf-8')),
            'source_train_sha256': plan['source_train_sha256'],
            'first_400_source_indices_sha256': plan['first_400_source_indices_sha256'],
            'draws': 400, 'unique_native_traces': 376}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--corpus-dir', type=Path, required=True)
    parser.add_argument('--candidate-dir', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.corpus_dir, args.candidate_dir, args.out), indent=2))


if __name__ == '__main__':
    main()
