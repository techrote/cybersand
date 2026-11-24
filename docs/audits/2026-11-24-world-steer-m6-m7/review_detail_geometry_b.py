#!/usr/bin/env python3
"""Read-only independent union/find audit of the 24 native detail cases.

Does not import the implementation's worker, compiler, tests or reducer.
The resulting report is a material geometry/custody review, not native attestation,
human preference, physics or gameplay qualification.
"""
from __future__ import annotations
import argparse
import base64
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import struct


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def read(root, descriptor):
    path = (root / descriptor['path']).resolve()
    assert path.is_relative_to(root.resolve()) and path.is_file() and path.stat().st_size <= 2 * 1024 * 1024
    raw = path.read_bytes()
    assert digest(raw) == descriptor['sha256']
    return raw


def rectangle(box):
    x, y, w, h = box
    assert all(type(n) is int for n in box) and 0 <= x < 64 and 0 <= y < 64 and w > 0 and h > 0 and x+w <= 64 and y+h <= 64
    return {yy*64+xx for yy in range(y, y+h) for xx in range(x, x+w)}


def partition(indices):
    # Scanline union/find, independent of the worker/reducer's graph flood fills.
    parent = {i: i for i in indices}
    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i in sorted(indices):
        for previous in (i-64, i-1 if i%64 else -1):
            if previous in parent:
                parent[root(i)] = root(previous)
    groups = defaultdict(set)
    for i in indices:
        groups[root(i)].add(i)
    return list(groups.values())


def review(directory):
    manifest_raw = (directory/'cases.json').read_bytes()
    manifest = json.loads(manifest_raw)
    assert manifest['format'] == 'cybersand-native-detail-comparison-evidence-v1'
    assert len(manifest['cases']) == 24 and manifest['model_calls'] == 0
    assert manifest['registration_sha256'] == '4e69cbdbca9a908ed2062cfc60b7bf448c4a44a73c1a5cd90b8640daabb16852'
    rows = []
    for case in manifest['cases']:
        before_raw, after_raw = read(directory,case['before']), read(directory,case['after'])
        assert len(before_raw) == len(after_raw) == 8192
        before, after = struct.unpack('<4096H',before_raw), struct.unpack('<4096H',after_raw)
        assert case['status'] == 'completed' and digest(after_raw) == case['projection_sha256']
        record = json.loads(read(directory,case['native_record']))
        assert record['state'] == 'completed' and record['provenance']['source_revision'] == manifest['source_revision']
        assert base64.b64decode(record['source_materials_base64'],validate=True) == before_raw
        assert base64.b64decode(record['material_cells_base64'],validate=True) == after_raw
        receipts = record['receipts']
        for receipt in receipts:
            assert receipt['backend'] == 'CyberNativeCellWorld' and receipt['status'] == 'completed'
            for field in ('requested','checked','changed','unchanged','confirmed','excluded','refused'):
                assert type(receipt[field]) is int and 0 <= receipt[field] <= 4096
            assert receipt['requested'] == receipt['checked'] == receipt['changed']+receipt['unchanged']+receipt['excluded']+receipt['refused']
            assert receipt['confirmed'] == receipt['changed']+receipt['unchanged']
            assert receipt['excluded'] == receipt['refused'] == 0
        assert 0 < sum(r['checked'] for r in receipts) <= 512
        replay = list(before)
        for edit in record['accepted_edits']:
            for i in rectangle(edit[:4]):
                replay[i] = edit[4]
        assert replay == list(after)
        recipe = json.loads(read(directory,case['recipe']))
        assert recipe['input_snapshot_sha256'] == digest(before_raw)
        changed = {i for i in range(4096) if before[i] != after[i]}
        assert len(changed) == sum(r['changed'] for r in receipts)
        context = case['context']
        assert changed <= rectangle(context['job_region'])
        for field in ('protected','fixed_regions','clearances'):
            for box in context[field]:
                guarded = rectangle(box)
                assert not changed & guarded
                if field == 'clearances':
                    assert all(before[i] == after[i] == 0 for i in guarded)
        assert not changed & {y*64+x for x,y in context['attachment_cells']}
        variable = set().union(*(rectangle(box) for box in context['variable_regions']))
        if case['job'] == 'edge_wear':
            assert changed <= variable and all(before[i] == 58 and after[i] == 0 for i in changed)
        else:
            assert all(before[i] == 0 and after[i] == 28 for i in changed)
        added = {i for i in changed if before[i] == 0 and after[i] != 0}
        pieces = partition(added)
        anchored = []
        for piece in pieces:
            neighbors = {j for i in piece for j in (i-64,i+64,i-1 if i%64 else -1,i+1 if i%64<63 else -1) if 0 <= j < 4096}
            anchored.append(any(before[j] in (7,13,28,58) for j in neighbors))
        rows.append({'id':case['id'],'job':case['job'],'arm':case['arm'],'changed_cells':len(changed),
                     'added_components':len(pieces),'source_anchored_components':sum(anchored),
                     'unanchored_added_cells':sum(len(piece) for piece, yes in zip(pieces,anchored) if not yes),
                     'occupied_components_before':len(partition({i for i,m in enumerate(before) if m})),
                     'occupied_components_after':len(partition({i for i,m in enumerate(after) if m})),
                     'source_sha256':digest(before_raw),'result_sha256':digest(after_raw),'receipt_chunks':len(receipts)})
    blocks = []
    for job in sorted({row['job'] for row in rows}):
        by_arm = {row['arm']:row for row in rows if row['job'] == job}
        assert set(by_arm) == {'deterministic','seeded','random_valid'}
        assert len({row['source_sha256'] for row in by_arm.values()}) == 1
        assert by_arm['seeded']['changed_cells'] == by_arm['random_valid']['changed_cells']
        blocks.append({'job':job,'seeded_random_changed_cells':by_arm['seeded']['changed_cells'],
                       'distinct_geometry_hashes':len({row['result_sha256'] for row in by_arm.values()}),
                       'random_unanchored_added_cells':by_arm['random_valid']['unanchored_added_cells']})
    return {'format':'cybersand-m67-detail-independent-review-b-v1','passed':True,
            'source_revision':manifest['source_revision'],'manifest_sha256':digest(manifest_raw),
            'script_sha256':digest(Path(__file__).read_bytes()),'cases':rows,'blocks':blocks,'model_calls':0,
            'native_active_core_capacity':manifest['native_active_core_capacity'],
            'development_core_capacity_override':manifest['development_core_capacity_override'],
            'scope':'Independent scalar union/find, complete native planes, receipt counters and accepted-edit replay. No actor, physics, preference or model-quality conclusion.',
            'limitations':['Single fixture per worker and only two procedural seeds. Independent controls are diagnostics, not a representative architectural preference trial.',
                           'Framed-opening control has one identical output across all three arms. Seed invariance for fixed panels and explicit routes is retained.',
                           'Random edge wear also preserves the measured global component count in this fixture; no superiority claim follows from that metric.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    result = review(args.directory)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
