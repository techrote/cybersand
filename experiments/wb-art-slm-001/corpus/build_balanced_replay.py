#!/usr/bin/env python3
"""Opt-in train-only, theme/phrasing-balanced replay diagnostic.

No model training, new positive examples, native execution or final-set use.
The replay prefix is 400 *draws*, not an integrated training sampler: Training
must separately approve/pin an epoch policy and a new candidate identity.
"""
import argparse
from collections import Counter
import json
from pathlib import Path

import build_curriculum as base

FROZEN_V1_ORDER = '8b0781624039e5b401d88f8440934bb6b8b14c8935181387678493e3fbb3351a'


def balanced_order(traces):
    """Fix v1's theme/phrasing parity coupling without changing admitted rows."""
    original = base.order_rows(traces)
    first, second = [], []
    for i, record in enumerate(original[:576]):
        theme = base.THEMES[i % len(base.THEMES)]
        if record['theme'] != theme:
            raise ValueError('unexpected upstream theme round order')
        phrase = 'p0' if (i // len(base.THEMES)) % 2 == 0 else 'p1'
        # Four controlled flips produce 200/200 at row 400 and <=1 imbalance
        # in each individual theme, rather than the old 33/1 or 1/33.
        if i // len(base.THEMES) == 10 and i % len(base.THEMES) in (4, 5, 6, 7):
            phrase = 'p1'
        pair = traces[record['native_case_id']]
        first.append(pair[phrase])
        second.append(pair['p1' if phrase == 'p0' else 'p0'])
    result = first + second
    if len({r['id'] for r in result}) != 1152 or len({r['native_case_id'] for r in first}) != 576:
        raise ValueError('source training row or native trace lost/duplicated')
    return result


def replay_prefix(ordered):
    """Replay each native-admitted exact-word example twice after warm-up.

    Replacement chooses only an admitted same-theme p0 row and preserves every
    originally represented structural group, leaving all theme/phrase totals
    intact. Replays are intentionally NOT distinct source examples or renders.
    """
    if len(ordered) != 1152:
        raise ValueError('expected exact 1152-row admitted order')
    prefix = list(ordered[:400])
    words = {}
    for theme, row in zip(base.THEMES, prefix[:12]):
        if row['theme'] != theme or row['prompt'] != theme or not row['id'].endswith('-p0'):
            raise ValueError('first twelve must be exact admitted words')
        words[theme] = row
    groups = Counter(r['group_id'] for r in prefix)
    changes = []
    for k in range(24):
        theme = base.THEMES[k % len(base.THEMES)]
        ideal = 27 + k * 16
        options = [i for i in range(12, 400)
                   if prefix[i]['theme'] == theme and prefix[i]['id'].endswith('-p0')
                   and prefix[i]['prompt'] != theme and groups[prefix[i]['group_id']] > 1]
        if not options:
            raise ValueError('insufficient same-theme p0/group coverage for replay')
        pos = min(options, key=lambda i: (abs(i - ideal), i))
        removed = prefix[pos]
        groups[removed['group_id']] -= 1
        prefix[pos] = words[theme]
        changes.append({'position': pos, 'displaced_id': removed['id'], 'replayed_id': words[theme]['id']})
    if (len({r['native_case_id'] for r in prefix}) != 376
            or len({r['group_id'] for r in prefix}) != 72
            or Counter(r['theme'] for r in prefix if r['prompt'] == r['theme'])
               != {t: 3 for t in base.THEMES}):
        raise ValueError('native diversity, group coverage or word replay failed')
    return prefix, changes


def build(folder, output):
    admission, _groups, traces = base.load_and_verify(folder)
    v1 = base.order_rows(traces)
    source_hash = base.digest(('\n'.join(r['id'] for r in v1) + '\n').encode())
    if source_hash != FROZEN_V1_ORDER:
        raise ValueError('archive is not the pinned v1 admitted training sequence')
    balanced = balanced_order(traces)
    replay, displaced = replay_prefix(balanced)
    source_rows = [json.loads(line) for line in (folder / 'train.jsonl').read_text().splitlines()]
    by_id = {r['id']: i for i, r in enumerate(source_rows)}
    if len(by_id) != 1152 or set(by_id) != {r['id'] for r in balanced}:
        raise ValueError('balanced output changed the source train membership')
    indices = [by_id[r['id']] for r in replay]
    payload = b''.join(base.canonical(r) + b'\n' for r in balanced)
    counts = Counter(r['theme'] for r in replay)
    phrases = Counter(r['id'].rsplit('-', 1)[-1] for r in replay)
    per_theme = {t: {p: sum(r['theme'] == t and r['id'].endswith(p) for r in replay)
                     for p in ('p0', 'p1')} for t in base.THEMES}
    if (len(displaced) != 24 or phrases != {'p0': 200, 'p1': 200}
            or min(counts.values()) != 33 or max(counts.values()) != 34
            or len(counts) != len(base.THEMES)
            or any(abs(v['p0'] - v['p1']) > 1 for v in per_theme.values())):
        raise ValueError('theme and phrasing exposure balance failed')
    manifest = {
        'schema_version': 1,
        'name': 'theme-phrase-replay-v2',
        'status': 'opt-in candidate; no model training or native re-execution',
        'train_sha256': admission['file_sha256']['train'],
        'dev_custody_sha256': admission['file_sha256']['dev'],
        'final_custody_sha256': admission['file_sha256']['final'],
        'compiler_sha256': admission['compiler_sha256'],
        'native_source': admission['runtime']['source_commit'],
        'source_v1_order_sha256': source_hash,
        'balanced_order_sha256': base.digest(('\n'.join(r['id'] for r in balanced) + '\n').encode()),
        'balanced_jsonl_sha256': base.digest(payload),
        'replay_400_ids_sha256': base.digest(('\n'.join(r['id'] for r in replay) + '\n').encode()),
        'replay_400_indices_sha256': base.digest(('\n'.join(map(str, indices)) + '\n').encode()),
        'records_in_balanced_order': len(balanced),
        'replay_draws': len(replay),
        'replay_unique_native_traces': len({r['native_case_id'] for r in replay}),
        'replay_groups': len({r['group_id'] for r in replay}),
        'literal_exposures_per_theme': 3,
        'replay_displaced_draws': len(displaced),
        'first_400_theme_counts': dict(sorted(counts.items())),
        'first_400_phrasing_counts': dict(sorted(phrases.items())),
        'first_400_per_theme_phrasing': per_theme,
        'accumulation_assumption': '400 draws correspond to 400 optimizer steps only with accumulation=1',
        'native_evidence': 'Original 576 train traces only; no new native run or model gain'
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / 'balanced_train.jsonl').write_bytes(payload)
    (output / 'replay_first400_indices.json').write_text(json.dumps(indices, indent=2) + '\n')
    (output / 'replay_displacements.json').write_text(json.dumps(displaced, indent=2) + '\n')
    (output / 'curriculum_manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--corpus-dir', type=Path, default=Path(__file__).parent)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.corpus_dir, args.out), indent=2))


if __name__ == '__main__':
    main()
