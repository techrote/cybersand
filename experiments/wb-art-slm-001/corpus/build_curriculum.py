#!/usr/bin/env python3
"""Produce an immutable, receipt-bound training order from the admitted bootstrap.

Only *reorders* existing train records. Never mints positives, repairs model output,
or reads final-assessment examples; final custody is checked by byte digest only.
The first 576 updates present distinct native traces; seed replicas and second
phrasings are not new independent structural groups. No training is launched.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re

THEMES = ('coral', 'veins', 'ribs', 'mycelium', 'roots', 'strata', 'dunes',
          'crystals', 'honeycomb', 'labyrinth', 'ruins', 'circuitry')
REQUIRED_RUNTIME = '90719c72b9fcf90593fb7878354051ad601b47fd'
REQUIRED_COMPILER = 'a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')


def load_and_verify(folder):
    admission = json.loads((folder / 'admission.json').read_text())
    manifest_path = folder / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    if (admission['state'] != 'native-qualified-bootstrap'
            or admission['runtime']['source_commit'] != REQUIRED_RUNTIME
            or admission['compiler_sha256'] != REQUIRED_COMPILER
            or admission['compiler_sha256'] != manifest['compiler_sha256']
            or digest(manifest_path.read_bytes()) != admission['corpus_manifest_sha256']
            or admission['split_counts'] != {'train': 1152, 'dev': 192, 'final': 192}):
        raise ValueError('pinned admission/compiler/source/split custody mismatch')
    for split in ('train', 'dev', 'final'):
        if digest((folder / f'{split}.jsonl').read_bytes()) != admission['file_sha256'][split]:
            raise ValueError(f'changed {split} file (no cross-split substitution)')
    groups = {g['group_id']: g for g in manifest['groups']}
    rows = [json.loads(x) for x in (folder / 'train.jsonl').read_text().splitlines()]
    ids = set()
    traces = defaultdict(dict)
    for r in rows:
        if r['id'] in ids or r['split'] != 'train' or r['group_id'] not in groups:
            raise ValueError('duplicate/non-training/unknown row')
        ids.add(r['id'])
        program = json.loads(r['completion'])
        signature = canonical({'theme': program['theme'],
                               'structure': [[layer['motif'], layer['layout']] for layer in program['layers']]}).decode()
        if (signature != groups[r['group_id']]['signature']
                or groups[r['group_id']]['split'] != 'train'
                or r['theme'] != program['theme']
                or digest(canonical(program)) != r['program_sha256']):
            raise ValueError('program/theme/actual structural signature differs from admission')
        receipt = r['native_receipt']
        if (r['native_qualified'] is not True or r['native_runtime'] != admission['runtime']
                or receipt['id'] != r['native_case_id']
                or receipt['operations_sha256'] != r['operations_sha256']
                or receipt['success'] is not True or receipt['acknowledged_cells'] <= 0
                or receipt['outside_focus_violations'] != 0
                or receipt['unexpected_material_cells'] != 0
                or not all(re.fullmatch('[a-f0-9]{64}', receipt[k]) for k in ('readback_sha256', 'image_sha256'))
                or r['material'] != 58):
            raise ValueError('row lacks originally admitted native source/receipt/protection gates')
        phrasing = r['id'].rsplit('-', 1)[-1]
        if phrasing not in ('p0', 'p1') or phrasing in traces[r['native_case_id']]:
            raise ValueError('missing/duplicate phrasing identity')
        traces[r['native_case_id']][phrasing] = r
    if len(rows) != 1152 or len(traces) != 576 or any(len(v) != 2 for v in traces.values()):
        raise ValueError('expected 576 native traces with two distinct text phrasings each')
    if Counter(r['theme'] for r in rows) != {t: 96 for t in THEMES}:
        raise ValueError('theme count imbalance in input')
    # Independently recompute canonical geometry hashes from the *archived*
    # native input records, not from a model prediction or keyword fallback.
    # This binds completion, host context, operation list and original receipt;
    # it is NOT a fresh execution of native Art or Stop/history gates.
    native = json.loads((folder / 'native_cases.json').read_text())['cases']
    indexed = {c['id']: c for c in native}
    if len(native) != 864 or len(indexed) != 864:
        raise ValueError('archived native case count/identity mismatch')
    for case_id, pair in traces.items():
        r = pair['p0']
        c = indexed.get(case_id)
        if (c is None or c['split'] != 'train' or c['group_id'] != r['group_id']
                or c['program'] != json.loads(r['completion'])
                or c['program_sha256'] != r['program_sha256']
                or (c['width'], c['height'], c['seed'], c['material'])
                   != (r['width'], r['height'], r['seed'], r['material'])
                or c['operations_sha256'] != r['operations_sha256']
                or digest(canonical(c['operations'])) != r['operations_sha256']):
            raise ValueError('archived program/context/geometry/receipt binding failed')
        # Both phrasings must supervise exactly the same admitted operation.
        other = pair['p1']
        for field in ('completion', 'group_id', 'program_sha256', 'operations_sha256',
                      'width', 'height', 'seed', 'material', 'native_receipt'):
            if other[field] != r[field]:
                raise ValueError('two text phrasings disagree on their native target')
    return admission, groups, traces


def order_rows(traces):
    # Disjoint native-trace passes: first 576 distinct geometries, then their
    # alternate text phrasings. Eight seed/modifier cases per structural group.
    per_theme = {}
    for theme in THEMES:
        themed = [(k, pair) for k, pair in traces.items() if pair['p0']['theme'] == theme]
        by_group = defaultdict(list)
        for key, pair in themed:
            by_group[pair['p0']['group_id']].append((key, pair))
        for members in by_group.values():
            members.sort(key=lambda x: x[0])
        # Prefer observed failure classes (coral compositions, veins/ribs routing)
        # within *training's own* source-qualified groups, never dev targets.
        group_order = sorted(by_group, key=lambda g: (
            0 if len(json.loads(by_group[g][0][1]['p0']['completion'])['layers']) > 1 else 1, g))
        if len(group_order) != 6 or any(len(by_group[g]) != 8 for g in group_order):
            raise ValueError('changed structural-group cardinality')
        ordered = [by_group[g][i] for i in range(8) for g in group_order]
        literal = next((item for item in ordered if item[1]['p0']['prompt'] == theme), None)
        if literal is None:
            raise ValueError('one-word row must be originally admitted train data')
        ordered.remove(literal)
        per_theme[theme] = [literal] + ordered
    first_pass = [per_theme[t][i] for i in range(48) for t in THEMES]
    primary, secondary = [], []
    for i, (key, pair) in enumerate(first_pass):
        # 12 literal p0; 12 diverse p1; then alternating. Exact 200/200 at
        # step 400 and 288/288 at step 576, with no repeated native trace.
        phrasing = 'p0' if i < 12 else ('p1' if i < 24 else ('p0' if i % 2 == 0 else 'p1'))
        primary.append(pair[phrasing])
        secondary.append(pair['p1' if phrasing == 'p0' else 'p0'])
    return primary + secondary


def build(folder, output):
    admission, groups, traces = load_and_verify(folder)
    ordered = order_rows(traces)
    if len({r['id'] for r in ordered}) != 1152:
        raise ValueError('curriculum lost or duplicated train records')
    prefix = ordered[:400]
    prefix_themes = Counter(r['theme'] for r in prefix)
    if (min(prefix_themes.values()) != 33 or max(prefix_themes.values()) != 34
            or Counter(r['id'].rsplit('-', 1)[-1] for r in prefix) != {'p0': 200, 'p1': 200}
            or len({r['native_case_id'] for r in prefix}) != 400
            or len({r['native_case_id'] for r in ordered[:576]}) != 576):
        raise ValueError('prefix diversity/balance guarantee broken')
    output_lines = b''.join(canonical(r) + b'\n' for r in ordered)
    ids = [r['id'] for r in ordered]
    recipe = {
        'schema_version': 1, 'name': 'literal-replay-v1',
        'scope': 'TRAIN ONLY; reorder existing native-admitted positives; no new native replay or model test',
        'train_sha256': admission['file_sha256']['train'],
        'dev_custody_sha256': admission['file_sha256']['dev'],
        'final_custody_sha256': admission['file_sha256']['final'],
        'compiler_sha256': admission['compiler_sha256'],
        'native_source': admission['runtime']['source_commit'],
        'order_sha256': digest(('\n'.join(ids)+'\n').encode()),
        'ordered_train_sha256': digest(output_lines),
        'records': len(ids), 'distinct_native_traces': len(traces),
        'first_12_ids': ids[:12],
        'first_400': {'unique_traces': 400, 'theme_counts': dict(sorted(prefix_themes.items())),
                      'phrasing_counts': {'p0': 200, 'p1': 200},
                      'distinct_structure_groups': len({r['group_id'] for r in prefix}),
                      'coral_compositions': sum(r['theme'] == 'coral' and len(json.loads(r['completion'])['layers']) > 1 for r in prefix)},
        'first_576_distinct_traces': 576,
        'observed_failure_target': ['coral malformed numeric literals (dev, never training)',
                                    'veins orthogonal primary motif on literal word',
                                    'ribs mislabeled as ruins on literal word'],
        'qualification': 'Only the unchanged original native receipts. Candidate model gains NOT measured.',
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / 'ordered_train.jsonl').write_bytes(output_lines)
    (output / 'curriculum_manifest.json').write_bytes(json.dumps(recipe, sort_keys=True, indent=2).encode()+b'\n')
    return recipe


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--corpus-dir', type=Path, default=Path(__file__).parent)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(build(a.corpus_dir, a.out), indent=2))


if __name__ == '__main__':
    main()
