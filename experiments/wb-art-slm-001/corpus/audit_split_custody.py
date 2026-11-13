#!/usr/bin/env python3
"""Read-only TRAIN/DEV custody and structural leakage audit of the saved bootstrap.

The sealed FINAL file is byte-hashed only; neither its prompts nor completions
are read. Native operation JSON is checked against the admitted exact program
and receipt hashes, but this is archived evidence, not a new native execution.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import re
import unicodedata
from pathlib import Path
from zipfile import ZipFile

ARCHIVE_SHA256 = '2d2de250731eeea825339e89f752ab8ebc65f3a929daa2c692120d985566948a'
COMPILER_SHA256 = 'a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb'
SOURCE_COMMIT = '90719c72b9fcf90593fb7878354051ad601b47fd'
RECORD_COUNTS = {'train': 1152, 'dev': 192, 'final': 192}
GROUP_COUNTS = {'train': 72, 'dev': 12, 'final': 12}
IDENTITY = re.compile(r'([a-z]+)-v[0-7]-m[0-7]-s\d+-p([01])\Z')


def digest(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(',', ':'), allow_nan=False).encode('utf-8')


def signature(program: dict) -> str:
    """The compiler's *post-modifier* ordered motif/layout signature."""
    if (type(program) is not dict or program.get('version') != 1 or
            type(program.get('theme')) is not str or
            type(program.get('layers')) is not list or
            not 1 <= len(program['layers']) <= 4):
        raise ValueError('invalid completed program shape')
    structure = []
    for layer in program['layers']:
        if type(layer) is not dict or type(layer.get('motif')) is not str or type(layer.get('layout')) is not str:
            raise ValueError('invalid completed motif/layout')
        structure.append([layer['motif'], layer['layout']])
    return canonical({'theme': program['theme'], 'structure': structure}).decode('utf-8')


def group_for(program: dict) -> str:
    # build_corpus.sha() hashes canonical_json(signature_string), not raw signature.
    return program['theme'] + ':' + digest(canonical(signature(program)))[:16]


def normalized_prompt(prompt: str) -> str:
    return ' '.join(unicodedata.normalize('NFKC', prompt).casefold().split())


def read_jsonl(blob: bytes, split: str) -> list[dict]:
    if not blob.endswith(b'\n') or b'\r' in blob:
        raise ValueError(f'{split} has noncanonical JSONL line endings')
    rows = [json.loads(line) for line in blob.splitlines()]
    if len(rows) != RECORD_COUNTS[split] or any(type(row) is not dict for row in rows):
        raise ValueError(f'{split} cardinality or record shape changed')
    return rows


def validate_pairs_and_leakage(rows_by_split: dict[str, list[dict]],
                               groups_by_id: dict[str, dict],
                               cases_by_id: dict[str, dict], runtime: dict) -> dict:
    """Reject forged group IDs, actual program/prompt leaks and receipt mismatch."""
    seen_ids: set[str] = set()
    owners = {label: {} for label in ('group', 'signature', 'program', 'prompt')}
    trace_pair: dict[str, list[dict]] = defaultdict(list)
    recorded_groups: dict[str, set[str]] = defaultdict(set)
    counted_cases: set[str] = set()
    for split in ('train', 'dev'):
        for row in rows_by_split[split]:
            rid = row.get('id')
            match = IDENTITY.fullmatch(rid) if isinstance(rid, str) else None
            if not match or rid in seen_ids or row.get('split') != split:
                raise ValueError('duplicate/invalid record ID or split')
            seen_ids.add(rid)
            program = json.loads(row['completion'])
            sig = signature(program)
            gid = group_for(program)
            case_id = rid[:-3]
            if (row['native_case_id'] != case_id or match.group(1) != program['theme'] or
                    row['theme'] != program['theme'] or row['group_id'] != gid or
                    digest(canonical(program)) != row['program_sha256']):
                raise ValueError('completion identity, program SHA or post-modifier group mismatch')
            group = groups_by_id.get(gid)
            if (group is None or group['signature'] != sig or group['split'] != split or
                    group['theme'] != program['theme']):
                raise ValueError('recomputed signature conflicts with structural split registry')
            case = cases_by_id.get(case_id)
            if (case is None or case['id'] != case_id or case['split'] != split or
                    case['group_id'] != gid or case['program'] != program or
                    case['program_sha256'] != row['program_sha256'] or
                    case['operations_sha256'] != row['operations_sha256'] or
                    digest(canonical(case['operations'])) != row['operations_sha256'] or
                    any(row[k] != case[k] for k in ('seed', 'width', 'height', 'material'))):
                raise ValueError('admitted completion differs from archived compiled geometry/context')
            receipt = row.get('native_receipt', {})
            if (row.get('native_qualified') is not True or row.get('native_runtime') != runtime or
                    receipt.get('id') != case_id or receipt.get('success') is not True or
                    receipt.get('operations_sha256') != row['operations_sha256'] or
                    receipt.get('outside_focus_violations') != 0 or
                    receipt.get('unexpected_material_cells') != 0 or
                    type(receipt.get('acknowledged_cells')) is not int or
                    receipt['acknowledged_cells'] <= 0 or
                    any(not re.fullmatch('[a-f0-9]{64}', str(receipt.get(k, '')))
                        for k in ('image_sha256', 'readback_sha256'))):
                raise ValueError('native receipt binding/protection/gates changed')
            prompt = normalized_prompt(row['prompt'])
            for kind, key in (('group', gid), ('signature', sig),
                              ('program', canonical(program)), ('prompt', prompt)):
                previous = owners[kind].setdefault(key, split)
                if previous != split:
                    raise ValueError(f'{kind} content leaked across TRAIN/DEV')
            counted_cases.add(case_id)
            recorded_groups[split].add(gid)
            trace_pair[case_id].append(row)
    if any(len(pair) != 2 or {r['id'][-2:] for r in pair} != {'p0', 'p1'} or
           any({k: v for k, v in r.items() if k not in ('id', 'prompt')} !=
               {k: v for k, v in pair[0].items() if k not in ('id', 'prompt')}
               for r in pair[1:]) or
           normalized_prompt(pair[0]['prompt']) == normalized_prompt(pair[1]['prompt'])
           for pair in trace_pair.values()):
        raise ValueError('seed/native-trace paraphrase pairing changed')
    if any(len(recorded_groups[s]) != GROUP_COUNTS[s] for s in ('train', 'dev')):
        raise ValueError('TRAIN/DEV effective structural family count differs')
    return {'train_records': len(rows_by_split['train']), 'dev_records': len(rows_by_split['dev']),
            'trace_pairs_verified': len(trace_pair), 'distinct_native_cases': len(counted_cases),
            'structural_groups_train': len(recorded_groups['train']),
            'structural_groups_dev': len(recorded_groups['dev']),
            'program_and_prompt_leakage_train_dev': 0,
            'note': 'FINAL content sealed; archive historical native receipts, no new execution'}


def signature_from_manifest(encoded: str) -> str:
    obj = json.loads(encoded)
    if (type(obj) is not dict or set(obj) != {'theme', 'structure'} or
            type(obj['structure']) is not list or not obj['structure'] or
            any(type(pair) is not list or len(pair) != 2 or
                any(type(item) is not str for item in pair) for pair in obj['structure'])):
        raise ValueError('malformed registered structural signature')
    return canonical(obj).decode('utf-8')


def audit_archive(archive: Path) -> dict:
    data = archive.read_bytes()
    if len(data) != 2311486 or digest(data) != ARCHIVE_SHA256:
        raise ValueError('executed-corpus archive byte-size/SHA256 changed')
    with ZipFile(archive) as z:
        names = z.namelist()
        if len(names) != len(set(names)) or any(not name.startswith('corpus/') and name not in
            ('ARCHIVE_MANIFEST.json', 'READ_ME.txt') for name in names):
            raise ValueError('duplicate/unexpected archive paths')
        root = lambda name: z.read('corpus/' + name)
        admission = json.loads(root('admission.json'))
        manifest_bytes = root('manifest.json')
        manifest = json.loads(manifest_bytes)
        if (admission['state'] != 'native-qualified-bootstrap' or
                admission['runtime']['source_commit'] != SOURCE_COMMIT or
                admission['compiler_sha256'] != COMPILER_SHA256 or
                manifest['compiler_sha256'] != COMPILER_SHA256 or
                digest(manifest_bytes) != admission['corpus_manifest_sha256'] or
                admission['split_counts'] != RECORD_COUNTS or
                manifest['group_counts'] != GROUP_COUNTS or
                digest(root('visual_review.json')) != admission['review_sha256']):
            raise ValueError('original global admission/manifest/runtime custody differs')
        blobs = {s: root(f'{s}.jsonl') for s in RECORD_COUNTS}
        for split, blob in blobs.items():
            if digest(blob) != admission['file_sha256'][split]:
                raise ValueError(f'{split} sealed byte hash differs')
        # FINAL is hash-only. Never parse its prompts/completions in this tool.
        rows = {s: read_jsonl(blobs[s], s) for s in ('train', 'dev')}
        groups = {g['group_id']: g for g in manifest['groups']}
        if (len(groups) != len(manifest['groups']) or len(groups) != 96 or
                Counter(g['split'] for g in groups.values()) != GROUP_COUNTS):
            raise ValueError('structural group registry is ambiguous')
        for gid, grp in groups.items():
            if (grp['theme'] + ':' + digest(canonical(grp['signature']))[:16] != gid or
                    grp['signature'] != signature_from_manifest(grp['signature'])):
                raise ValueError('stored structural signature changed')
        cases = json.loads(root('native_cases.json'))['cases']
        if (len(cases) != 864 or digest(canonical(cases)) != manifest['cases_sha256'] or
                len({c['id'] for c in cases}) != len(cases)):
            raise ValueError('archived native program/operation cases changed')
        results = validate_pairs_and_leakage(rows, groups, {c['id']: c for c in cases}, admission['runtime'])
        results.update({'archive_sha256': ARCHIVE_SHA256,
                        'source_commit': SOURCE_COMMIT,
                        'train_file_sha256': admission['file_sha256']['train'],
                        'dev_file_sha256': admission['file_sha256']['dev'],
                        'final_file_sha256_checked_without_reading_examples': admission['file_sha256']['final'],
                        'declared_final_groups_checked_from_manifest': GROUP_COUNTS['final'],
                        'raw_global_receipt_packet_replayed': False})
        return results


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--archive', required=True, type=Path)
    args = ap.parse_args()
    print(json.dumps(audit_archive(args.archive), indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
