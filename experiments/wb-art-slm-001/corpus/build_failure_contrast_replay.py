#!/usr/bin/env python3
"""Immutable TRAIN-only v5 rehearsal: disambiguate two observed theme/motif failures.

This creates a *proposal* for Training, not a trained model or fresh native test.
All examples are existing, verified-admitted positives; paired examples are
contrasts in presentation order, never negative/invalid model targets.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
from zipfile import ZipFile

ARCHIVE_SHA256 = '2d2de250731eeea825339e89f752ab8ebc65f3a929daa2c692120d985566948a'
TRAIN_SHA256 = '972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66'
DEV_SHA256 = 'e8d9f0c1ab39eb28d760fac5fdc42cbbd770dc5505954d15050d214ffd062267'
FINAL_SHA256 = '54f1cb53e228953d08b2d5a0f43eeea7f81757bf0f3832e2b22e897203a9696c'
COMPILER_SHA256 = 'a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb'
SOURCE = '90719c72b9fcf90593fb7878354051ad601b47fd'
THEMES = ('roots', 'coral', 'veins', 'mycelium', 'strata', 'dunes', 'crystals',
          'honeycomb', 'labyrinth', 'ruins', 'circuitry', 'ribs')
ID = re.compile(r'^([a-z]+)-v([0-7])-m([0-7])-s(\d+)-p([01])$')
# Matched variant/modifier/seed and prompt register, intentionally different themes.
CONTRAST_SETTINGS = {
    ('veins', 'circuitry'): ((0, 2, 0), (1, 3, 1), (4, 6, 0), (5, 7, 1)),
    ('ribs', 'ruins'): ((0, 2, 0), (2, 3, 1), (4, 6, 0), (6, 7, 1)),
}
CORAL_SETTINGS = ((4, 0, 0), (5, 0, 1), (4, 6, 0), (5, 6, 1))


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def ids_digest(rows: list[dict]) -> str:
    return digest(('\n'.join(r['id'] for r in rows) + '\n').encode())


def index_digest(indices: list[int]) -> str:
    return digest(('\n'.join(map(str, indices)) + '\n').encode())


def parsed(row: dict) -> tuple[str, int, int, int, int]:
    m = ID.fullmatch(row['id'])
    if m is None or row['native_case_id'] != row['id'][:-3] or m[1] != row['theme']:
        raise ValueError('noncanonical admitted training identity')
    return m[1], int(m[2]), int(m[3]), int(m[4]), int(m[5])


def verify_row(row: dict) -> None:
    theme, variant, modifier, seed, phrase = parsed(row)
    receipt = row['native_receipt']
    program = json.loads(row['completion'])
    if (row['split'] != 'train' or theme not in THEMES or row['native_qualified'] is not True
            or program['theme'] != theme or program['version'] != 1 or
            not (1 <= len(program['layers']) <= 4) or row['seed'] != seed or
            row['material'] != 58 or row['width'] != 96 or row['height'] != 96 or
            row['native_runtime']['source_commit'] != SOURCE or
            row['visual_review'] not in ('case-inspected', 'template-group-pilot-admitted') or
            receipt['success'] is not True or receipt['id'] != row['native_case_id'] or
            receipt['operations_sha256'] != row['operations_sha256'] or
            receipt['changed_cells'] <= 0 or receipt['outside_focus_violations'] or
            receipt['unexpected_material_cells']):
        raise ValueError('admitted completion/native/host evidence changed')
    if (theme == 'veins' and program['layers'][0]['motif'] != 'network') or (
            theme == 'circuitry' and program['layers'][0]['motif'] != 'orthogonal') or (
            theme == 'ribs' and program['layers'][0]['motif'] != 'ribs') or (
            theme == 'ruins' and program['layers'][0]['motif'] != 'blocks'):
        raise ValueError('known-confusion motif witness was replaced')
    if theme == 'coral' and program['layers'][0]['motif'] != 'fan':
        raise ValueError('coral morphology witness changed')


def read_archive(path: Path) -> tuple[list[dict], dict]:
    data = path.read_bytes()
    if len(data) != 2311486 or digest(data) != ARCHIVE_SHA256:
        raise ValueError('not the original executed native-admitted corpus archive')
    with ZipFile(path) as z:
        admission = json.loads(z.read('corpus/admission.json'))
        originals = {'train': TRAIN_SHA256, 'dev': DEV_SHA256, 'final': FINAL_SHA256}
        for split, expected in originals.items():
            blob = z.read(f'corpus/{split}.jsonl')
            if digest(blob) != expected or admission['file_sha256'][split] != expected:
                raise ValueError('admitted split custody differs: ' + split)
            if split == 'train':
                train = [json.loads(line) for line in blob.splitlines()]
        if (admission['runtime']['source_commit'] != SOURCE or
                admission['compiler_sha256'] != COMPILER_SHA256 or
                admission['split_counts'] != {'train': 1152, 'dev': 192, 'final': 192} or
                admission['state'] != 'native-qualified-bootstrap'):
            raise ValueError('source, compiler or native admission changed')
    if len(train) != 1152 or len({r['id'] for r in train}) != 1152:
        raise ValueError('TRAIN identity count changed')
    for r in train:
        verify_row(r)
    return train, admission


def program_case_key(row: dict) -> tuple[str, int, int]:
    theme, variant, modifier, _seed, _p = parsed(row)
    return (theme, variant, modifier)


def build_rows(train: list[dict]) -> tuple[list[dict], dict]:
    """Build 376 unique positives + 24 literal repeats with paired error controls."""
    cases: dict[tuple[str, int, int], dict[int, dict]] = defaultdict(dict)
    for row in train:
        key = program_case_key(row)
        phrase = parsed(row)[4]
        if phrase in cases[key]:
            raise ValueError('duplicate original case/phrasing')
        cases[key][phrase] = row
    if len(cases) != 576 or any(set(phrases) != {0, 1} for phrases in cases.values()):
        raise ValueError('TRAIN native trace/phrasing pairs changed')
    anchors = [cases[(theme, 0, 0)][0] for theme in THEMES]
    if any(r['prompt'] != r['theme'] for r in anchors):
        raise ValueError('literal-word anchors are no longer original prompts')

    # A pair shares variant/modifier/seed, but its *theme, motif and target* differ.
    early: list[dict] = []
    matched_pairs = []
    for left, right in (('veins', 'circuitry'), ('ribs', 'ruins')):
        for variant, modifier, phrase in CONTRAST_SETTINGS[(left, right)]:
            a, b = cases[(left, variant, modifier)][phrase], cases[(right, variant, modifier)][phrase]
            if (a['seed'] != b['seed'] or a['group_id'] == b['group_id'] or
                    a['operations_sha256'] == b['operations_sha256']):
                raise ValueError('contrast lacks independent same-context native programs')
            early.extend((a, b))
            matched_pairs.append([a['id'], b['id']])
    for variant, modifier, phrase in CORAL_SETTINGS:
        r = cases[('coral', variant, modifier)][phrase]
        if len(json.loads(r['completion'])['layers']) < 2:
            raise ValueError('coral composed native witness missing')
        early.append(r)
    if len(early) != 20 or len({r['native_case_id'] for r in early}) != 20:
        raise ValueError('contrastive prefix is not unique')

    chosen: dict[str, list[dict]] = {}
    for i, theme in enumerate(THEMES):
        wanted = 32 if i < 4 else 31
        reserved = [anchors[i]] + [r for r in early if r['theme'] == theme]
        used = {r['native_case_id'] for r in reserved}
        if len(used) != len(reserved):
            raise ValueError('priority example overlaps literal source anchor')
        modcounts = Counter(parsed(r)[2] for r in reserved)
        groupcounts = Counter(r['group_id'] for r in reserved)
        # Exactly four distinct admitted native traces per modifier, with one
        # three-trace family for 31-case themes; all six structural groups survive.
        goals = {m: (3 if m == 5 and wanted == 31 else 4) for m in range(8)}
        while len(reserved) < wanted:
            options = [phrases[0] for (t, v, m), phrases in cases.items()
                       if t == theme and phrases[0]['native_case_id'] not in used
                       and modcounts[m] < goals[m]]
            if not options:
                raise ValueError('insufficient admitted unique examples for balanced selection')
            best = min(options, key=lambda r: (modcounts[parsed(r)[2]],
                                               groupcounts[r['group_id']], parsed(r)[2],
                                               parsed(r)[1]))
            reserved.append(best)
            used.add(best['native_case_id'])
            modcounts[parsed(best)[2]] += 1
            groupcounts[best['group_id']] += 1
        if modcounts != Counter(goals) or len(groupcounts) != 6:
            raise ValueError('group or modifier coverage target missed')
        # Assign prompt register only for non-priority traces. Preserve the
        # exact paired native program and choose a balanced form distribution.
        target_p0 = 15 if wanted == 32 or i >= 8 else 14
        fixed = {r['native_case_id']: parsed(r)[4] for r in [anchors[i]] + [r for r in early if r['theme'] == theme]}
        need = target_p0 - sum(p == 0 for p in fixed.values())
        free = [r for r in reserved if r['native_case_id'] not in fixed]
        if not 0 <= need <= len(free):
            raise ValueError('priority set over-constrains phrasing')
        free_ids = [r['native_case_id'] for r in reserved if r['native_case_id'] not in fixed]
        for j, cid in enumerate(free_ids):
            fixed[cid] = 0 if j % len(free_ids) < need else 1
        chosen[theme] = [cases[program_case_key(r)][fixed[r['native_case_id']]] for r in reserved]
        if sum(parsed(r)[4] == 0 for r in chosen[theme]) != target_p0:
            raise ValueError('per-theme phrasing quota missed')

    out = anchors + early
    used_ids = {r['native_case_id'] for r in out}
    rem = {t: [r for r in chosen[t] if r['native_case_id'] not in used_ids] for t in THEMES}
    for i in range(32):
        for theme in THEMES:
            if rem[theme]:
                out.append(rem[theme].pop(0))
    if len(out) != 376 or len({r['native_case_id'] for r in out}) != 376:
        raise ValueError('unique native-trace phase is not 376 distinct cases')
    # Explicit two replays per word; same exact training row, not a new sample.
    for offset in (134, 266):
        out[offset:offset] = list(anchors)
    if len(out) != 400 or len({r['native_case_id'] for r in out}) != 376:
        raise ValueError('400-draw native-trace identity invariant failed')
    groups = {r['group_id'] for r in out}
    by_theme = Counter(r['theme'] for r in out)
    by_phrase = Counter(parsed(r)[4] for r in out)
    literal = Counter(r['theme'] for r in out if r['prompt'] == r['theme'])
    if (len(groups) != 72 or sorted(by_theme.values()) != [33]*8 + [34]*4 or
            by_phrase != {0: 200, 1: 200} or
            literal != {theme: 3 for theme in THEMES}):
        raise ValueError('protected structure/theme/phrase/word balances failed')
    if any(len(r['id']) > 38 for r in out):
        raise ValueError('native alias name limit exceeded')
    contrast = {'matched_positive_pairs': matched_pairs,
                'coral_composed': [r['id'] for r in early if r['theme'] == 'coral']}
    return out, contrast


def build(archive: Path) -> dict:
    train, _admission = read_archive(archive)
    rows, contrasts = build_rows(train)
    by_id = {r['id']: i for i, r in enumerate(train)}
    indices = [by_id[r['id']] for r in rows]
    return {
        'schema_version': 1, 'name': 'failure-contrast-replay-v5',
        'status': 'TRAIN-only proposed source-index sampler; no optimizer/native execution',
        'source_archive_sha256': ARCHIVE_SHA256,
        'source_train_sha256': TRAIN_SHA256, 'dev_custody_sha256': DEV_SHA256,
        'final_custody_sha256': FINAL_SHA256, 'compiler_sha256': COMPILER_SHA256,
        'pinned_native_source': SOURCE, 'draws': 400,
        'unique_native_traces': 376, 'structural_groups': 72,
        'matched_motif_context_pairs': 8, 'coral_composed_m0_m6': 4,
        'first_32': '12 literal words, 16 matched positive contrasts, 4 composed coral witnesses',
        'theme_exposure_range': [33, 34], 'prompt_forms': {'p0': 200, 'p1': 200},
        'literal_exposures_per_theme': 3, 'source_indices_space': 'original admitted corpus/train.jsonl',
        'source_indices_sha256': index_digest(indices), 'ordered_ids_sha256': ids_digest(rows),
        'source_indices': indices, 'witnesses': contrasts,
        'strict_scope': 'original corpus TRAIN positives only; FINAL never parsed',
        'native_evidence': 'archived historical Linux receipts, not current main/Windows',
        'training_effect': 'none until Training launches a separately identified experiment',
    }


def verify_manifest(path: Path, archive: Path) -> None:
    actual = build(archive)
    claimed = json.loads(path.read_text(encoding='utf-8'))
    if claimed != actual:
        raise ValueError('source-index manifest differs from admitted TRAIN reconstruction')


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, required=True)
    p.add_argument('--out', type=Path)
    p.add_argument('--verify-manifest', type=Path)
    a = p.parse_args()
    if a.verify_manifest is not None:
        verify_manifest(a.verify_manifest, a.archive)
        print('PASS: manifest matches original executed-corpus TRAIN and fixed v5 source indices')
        return
    if a.out is None:
        p.error('--out is required unless --verify-manifest is supplied')
    m = build(a.archive)
    a.out.write_text(json.dumps(m, sort_keys=True, indent=2) + '\n')
    print(json.dumps({k: v for k, v in m.items() if k not in ('source_indices','witnesses')}, indent=2))


if __name__ == '__main__':
    main()
