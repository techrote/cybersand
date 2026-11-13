#!/usr/bin/env python3
"""TRAIN-only modifier-stratified, literal-word replay (opt-in v3).

The v2 first-400 sampler has *zero* modifier-6 and modifier-7 exposures.
Use the same source-admitted native traces, arranging all eight modifier
families across the early window. No new positive, training or native run.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re

import build_curriculum as base
import build_balanced_replay as v2

V2_ORDER_SHA256 = '8c4e1be31766926173eb8427a380b204cd14a0397d978700e5cb8223dc000915'
MODIFIER_RE = re.compile(r'^([a-z]+)-v\d+-m([0-7])-s\d+$')
MODIFIER_PRIORITY = (6, 7, 1, 2, 3, 4, 5, 0)


def modifier(row):
    """Read verified archive metadata, refusing disagreement with row identity."""
    match = MODIFIER_RE.fullmatch(row['native_case_id'])
    if (match is None or match.group(1) != row['theme'] or
            row['id'] not in (row['native_case_id'] + '-p0', row['native_case_id'] + '-p1')):
        raise ValueError('invalid or contradictory archived modifier/row identity')
    return int(match.group(2))


def modifier_order(traces):
    """One of each trace, then its complementary prompt; retain 12 early words."""
    original = v2.balanced_order(traces)
    if base.digest(('\n'.join(r['id'] for r in original) + '\n').encode()) != V2_ORDER_SHA256:
        raise ValueError('source is not pinned v2 qualified training order')
    per_theme = {}
    for theme in base.THEMES:
        cases = [r for r in original[:576] if r['theme'] == theme]
        if len(cases) != 48 or len({r['native_case_id'] for r in cases}) != 48:
            raise ValueError('expected 48 distinct native traces per theme')
        literal = [r for r in cases if r['prompt'] == theme and r['id'].endswith('-p0')]
        if len(literal) != 1 or modifier(literal[0]) != 0:
            raise ValueError('missing admitted one-word modifier-0 anchor')
        word = literal[0]
        remaining = [r for r in cases if r['native_case_id'] != word['native_case_id']]
        mod_count = Counter({m: 0 for m in range(8)})
        group_count = Counter({r['group_id']: 0 for r in cases})
        selected = [word]
        mod_count[0] = 1
        group_count[word['group_id']] = 1
        while remaining:
            next_mod = min({modifier(r) for r in remaining},
                           key=lambda m: (mod_count[m], MODIFIER_PRIORITY.index(m)))
            choice = min((r for r in remaining if modifier(r) == next_mod),
                         key=lambda r: (group_count[r['group_id']], r['group_id'],
                                        r['native_case_id']))
            selected.append(choice)
            remaining.remove(choice)
            mod_count[next_mod] += 1
            group_count[choice['group_id']] += 1
        if sorted(mod_count.values()) != [6] * 8 or sorted(group_count.values()) != [8] * 6:
            raise ValueError('lost original modifier/structure cardinality')
        per_theme[theme] = selected

    first = []
    for i in range(48):
        for j, theme in enumerate(base.THEMES):
            row = per_theme[theme][i]
            phrase = 'p0' if i % 2 == 0 else 'p1'
            if i == 10 and j in (4, 5, 6, 7):
                phrase = 'p1'  # retain v2 global 200/200 within first 400
            first.append(traces[row['native_case_id']][phrase])

    # A replay of the exact one-word p0 replaces *another modifier-0 p0*,
    # instead of silently removing scarce complex-modifier exposures.
    # Compensating two unrelated p0 -> p1 swaps within each theme preserves
    # equal prompt-form counts and exact source-row membership.
    for theme in base.THEMES:
        anchors = [i for i, row in enumerate(first[:400])
                   if row['theme'] == theme and modifier(row) == 0
                   and row['id'].endswith('-p1')][:2]
        if len(anchors) != 2:
            raise ValueError('insufficient p1 modifier-0 rows for replay anchors')
        used = set()
        for i in anchors:
            options = [j for j, row in enumerate(first[:400])
                       if row['theme'] == theme and modifier(row) != 0
                       and row['id'].endswith('-p0') and j >= 12 and j not in used]
            if not options:
                raise ValueError('insufficient p0 phrasing compensators')
            j = min(options, key=lambda k: (abs(k - i), k))
            used.add(j)
            for index in (i, j):
                old = first[index]
                next_phrase = 'p0' if old['id'].endswith('-p1') else 'p1'
                first[index] = traces[old['native_case_id']][next_phrase]
    second = [traces[r['native_case_id']]['p1' if r['id'].endswith('-p0') else 'p0']
              for r in first]
    ordered = first + second
    if (len({r['id'] for r in ordered}) != 1152
            or len({r['native_case_id'] for r in first}) != 576
            or Counter(r['id'].rsplit('-', 1)[-1] for r in first[:400]) !=
               {'p0': 200, 'p1': 200}):
        raise ValueError('modifier replay lost original source membership or phrasing balance')
    return ordered


def replay_prefix(ordered):
    """24 same-modifier replacements, with raw source identities preserved."""
    prefix = list(ordered[:400])
    group_counts = Counter(r['group_id'] for r in prefix)
    changes = []
    for theme in base.THEMES:
        word = next((r for r in prefix[:12] if r['theme'] == theme and
                     r['prompt'] == theme and r['id'].endswith('-p0')), None)
        if word is None:
            raise ValueError('literal source anchor missing')
        choices = [i for i, row in enumerate(prefix[12:], 12)
                   if row['theme'] == theme and modifier(row) == 0
                   and row['prompt'] != theme and row['id'].endswith('-p0')
                   and group_counts[row['group_id']] > 1]
        if len(choices) < 2:
            raise ValueError('insufficient native-admitted same-modifier replay choices')
        a = min(choices, key=lambda i: (abs(i - 133), i))
        choices.remove(a)
        b = min(choices, key=lambda i: (abs(i - 266), i))
        for position in (a, b):
            old = prefix[position]
            if group_counts[old['group_id']] <= 1:
                raise ValueError('replay would remove a structural group')
            group_counts[old['group_id']] -= 1
            prefix[position] = word
            changes.append({'position': position, 'displaced_id': old['id'],
                            'replayed_id': word['id']})
    changes.sort(key=lambda c: c['position'])
    before, after = ordered[:400], prefix
    if (len(changes) != 24 or len({r['native_case_id'] for r in after}) != 376
            or len({r['group_id'] for r in after}) != 72
            or Counter((r['theme'], modifier(r)) for r in before) !=
               Counter((r['theme'], modifier(r)) for r in after)
            or Counter((r['theme'], r['id'][-2:]) for r in before) !=
               Counter((r['theme'], r['id'][-2:]) for r in after)
            or Counter(r['theme'] for r in after if r['prompt'] == r['theme']) !=
               {theme: 3 for theme in base.THEMES}):
        raise ValueError('literal replay changed protected modifier/form balance')
    return prefix, changes


def build(folder, output):
    """Read only archived TRAIN rows; DEV/FINAL are compared by byte custody."""
    admission, _groups, traces = base.load_and_verify(folder)
    ordered = modifier_order(traces)
    prefix, displaced = replay_prefix(ordered)
    source_rows = [json.loads(line) for line in (folder / 'train.jsonl').read_text().splitlines()]
    source_index = {r['id']: i for i, r in enumerate(source_rows)}
    ordered_index = {r['id']: i for i, r in enumerate(ordered)}
    if (len(source_index) != 1152 or len(ordered_index) != 1152 or
            set(source_index) != set(ordered_index)):
        raise ValueError('source train membership changed')
    source_indices = [source_index[r['id']] for r in prefix]
    ordered_indices = [ordered_index[r['id']] for r in prefix]
    payload = b''.join(base.canonical(r) + b'\n' for r in ordered)
    ids = lambda seq: base.digest(('\n'.join(r['id'] for r in seq) + '\n').encode())
    index_digest = lambda seq: base.digest(('\n'.join(map(str, seq)) + '\n').encode())
    modifier_counts = Counter(str(modifier(r)) for r in prefix)
    per_theme_mod = {theme: {str(m): sum(r['theme'] == theme and modifier(r) == m
                                    for r in prefix) for m in range(8)}
                     for theme in base.THEMES}
    if (len(prefix) != 400 or sorted(Counter(r['theme'] for r in prefix).values()) !=
            [33] * 8 + [34] * 4 or
            any(max(counts.values()) - min(counts.values()) > 1
                for counts in per_theme_mod.values())):
        raise ValueError('modified first-400 modifier/theme exposure out of balance')
    manifest = {
        'schema_version': 1,
        'name': 'modifier-stratified-replay-v3',
        'status': 'TRAIN-only opt-in; no native re-execution, new positives or model gain',
        'train_sha256': admission['file_sha256']['train'],
        'dev_custody_sha256': admission['file_sha256']['dev'],
        'final_custody_sha256': admission['file_sha256']['final'],
        'compiler_sha256': admission['compiler_sha256'],
        'native_source': admission['runtime']['source_commit'],
        'v2_reference_order_sha256': V2_ORDER_SHA256,
        'ordered_ids_sha256': ids(ordered),
        'ordered_jsonl_sha256': base.digest(payload),
        'replay_400_ids_sha256': ids(prefix),
        'replay_400_source_indices_sha256': index_digest(source_indices),
        'replay_400_ordered_indices_sha256': index_digest(ordered_indices),
        'replay_400_displacements_sha256': base.digest(base.canonical(displaced)),
        'source_indices_refer_to': 'original admitted train.jsonl',
        'ordered_indices_refer_to': 'modifier_train.jsonl written by this generator',
        'records': len(ordered), 'replay_draws': len(prefix),
        'replay_unique_native_traces': len({r['native_case_id'] for r in prefix}),
        'replay_structural_groups': len({r['group_id'] for r in prefix}),
        'replay_displaced_draws': len(displaced),
        'literal_draws_per_theme': 3,
        'modifier_counts': dict(sorted(modifier_counts.items())),
        'per_theme_modifier_counts': per_theme_mod,
        'phrasing_counts': dict(sorted(Counter(r['id'][-2:] for r in prefix).items())),
        'first_400_m6_m7_exposures': modifier_counts['6'] + modifier_counts['7'],
        'accumulation_assumption': '400 draws equals 400 optimizer steps only with accumulation=1',
        'native_evidence': 'unchanged bootstrap Linux native receipts only; not current main/Windows',
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / 'modifier_train.jsonl').write_bytes(payload)
    (output / 'replay_first400_source_indices.json').write_text(json.dumps(source_indices, indent=2) + '\n')
    (output / 'replay_first400_ordered_indices.json').write_text(json.dumps(ordered_indices, indent=2) + '\n')
    (output / 'replay_displacements.json').write_text(json.dumps(displaced, indent=2) + '\n')
    (output / 'curriculum_manifest.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--corpus-dir', type=Path, default=Path(__file__).parent)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.corpus_dir, args.out), indent=2))


if __name__ == '__main__':
    main()