"""Reseal complete archived packets; never execute a candidate or alter originals."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile


MUTATIONS = (
    ('missing-optional-logical-hash', 'optional', 'logical_hash', 'delete'),
    ('missing-touch-observations', 'touch', 'observations', 'delete'),
    ('extra-optional-field', 'optional', 'unregistered', 'extra'),
    ('changed-logical-hash', 'optional', 'logical_hash', 'increment'),
    ('changed-refusals', 'optional', 'refusals', 'increment'),
    ('changed-allocations', 'optional', 'allocations', 'increment'),
    ('changed-scheduled-cores', 'touch', 'scheduled_cores', 'increment'),
    ('changed-configured-workers', 'touch', 'configured_workers', 'increment'),
    ('substituted-optional-comparator', 'optional', 'logical_hash', 'comparator'),
    ('substituted-touch-comparator', 'touch', 'scheduled_cores', 'comparator'),
)


def exercise(source, commit, windows_optional, windows_touch, platform):
    if platform == 'linux':
        from verify_linux import verify
        offset = 12
    else:
        from verify_wasm import verify
        offset = 5
    source = Path(source)
    original = json.loads((source / 'result.json').read_bytes())
    positive = verify(source, commit, windows_optional, windows_touch)
    rows = []
    with tempfile.TemporaryDirectory(prefix='mat003-portability-negative-') as temporary:
        for name, kind, field, mutation in MUTATIONS:
            destination = Path(temporary) / name
            shutil.copytree(source, destination)
            result = copy.deepcopy(original)
            comparators = {'optional': copy.deepcopy(windows_optional), 'touch': copy.deepcopy(windows_touch)}
            index = next(i for i, row in enumerate(result['cases']) if row['kind'] == kind)
            row = result['cases'][index]['result']
            if mutation == 'delete': del row[field]
            elif mutation == 'extra': row[field] = 0
            else: row[field] += 1
            if mutation == 'comparator':
                # Substitution matches the forged archive exactly; simple equality
                # would pass. Only the independently pinned Windows identity rejects it.
                win = next(c for c in comparators[kind]['cases'] if c['mode'] == row['mode'] and not c['sanitized']
                           and (kind != 'optional' or (c['side'], c['tail_bits']) == (row['side'], row['tail_bits'])))
                win[field] = row[field]
            path = destination / f'case-{index:03d}.stdout'
            path.write_text(json.dumps(row), encoding='utf-8')
            receipt = result['commands'][offset + index]
            receipt['stdout_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            (destination / f'case-{index:03d}.receipt.json').write_text(json.dumps(receipt), encoding='utf-8')
            (destination / 'result.json').write_text(json.dumps(result), encoding='utf-8')
            seals = {p.relative_to(destination).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in destination.rglob('*') if p.is_file() and p.name != 'inventory.json'}
            (destination / 'inventory.json').write_text(json.dumps(seals), encoding='utf-8')
            try:
                verify(destination, commit, comparators['optional'], comparators['touch'])
            except ValueError as error:
                rows.append({'case': name, 'refused': True, 'reason': str(error)})
            except KeyError as error:
                rows.append({'case': name, 'refused': True, 'unstructured_error': repr(error)})
            else:
                rows.append({'case': name, 'refused': False})
    return {'platform': platform, 'positive': positive, 'mutations': rows}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('evidence', type=Path)
    p.add_argument('--source-commit', required=True)
    p.add_argument('--platform', choices=('linux', 'wasm'), required=True)
    p.add_argument('--windows-optional', type=Path, required=True)
    p.add_argument('--windows-touch', type=Path, required=True)
    a = p.parse_args()
    result = exercise(a.evidence, a.source_commit, json.loads(a.windows_optional.read_bytes()),
                      json.loads(a.windows_touch.read_bytes()), a.platform)
    print(json.dumps(result, indent=2))
    if not all(row['refused'] and 'unstructured_error' not in row for row in result['mutations']):
        raise SystemExit(1)
