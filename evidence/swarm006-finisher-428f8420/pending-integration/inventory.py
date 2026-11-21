"""Read Git objects only; preserve a provisional, unaccepted PR715 projection.

This script writes only this external evidence directory and unreachable Git
merge-tree objects. It neither checks out nor executes any candidate source.
"""
import hashlib
import json
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path('/workspace/scratch/d425b9146667/cybersand-swarm006-finisher')
OUT = pathlib.Path(__file__).resolve().parent
OLD = OUT.parent / 'pending-pr715-reconciliation'
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS='0')
REFS = {
    'accepted_base': '846fe0533b3170e7b01f690518da49fc40cc24d1',
    'shared_donor_base': '8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7',
    'reviewed_successor': '8cf93e48bc23370c6ef7b835978689ca3aa3e9f8',
    'successor': 'ca63445888d818ed868f71869abb37ae4d00975e',
    'frozen_candidate': '79b8a0a4a1c2ace435d709b35114ee7065c935e6',
    'requested_candidate': '96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f',
    'candidate': '919134a39d31461947c410c233d59d1965c48414',
}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, env=ENV)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def snapshot():
    index = pathlib.Path(git('rev-parse', '--git-path', 'index').decode().strip())
    if not index.is_absolute():
        index = ROOT / index
    return {
        'head': git('rev-parse', 'HEAD').decode().strip(),
        'branch': git('branch', '--show-current').decode().strip(),
        'index_sha256': digest(index.read_bytes()),
        'status': git('status', '--porcelain=v1', '--untracked-files=all').decode(),
        'refs_sha256': digest(git('for-each-ref', '--format=%(refname) %(objectname)')),
        'historical_evidence': {str(p.relative_to(OLD)): digest(p.read_bytes())
                                for p in sorted(OLD.rglob('*')) if p.is_file()},
    }

before = snapshot()
assert before['head'] == REFS['successor'] and not before['status']
simulations = {}
for candidate_key in ('requested_candidate', 'candidate'):
    result = subprocess.run(['git', 'merge-tree', '--write-tree', '--messages',
                             REFS['successor'], REFS[candidate_key]], cwd=ROOT,
                            env=ENV, capture_output=True, check=False)
    assert result.returncode in (0, 1), result.stderr
    (OUT / f'merge-tree-{candidate_key}.stdout.txt').write_bytes(result.stdout)
    (OUT / f'merge-tree-{candidate_key}.stderr.txt').write_bytes(result.stderr)
    lines = result.stdout.decode().splitlines()
    assert re.fullmatch('[0-9a-f]{40}', lines[0])
    key = 'requested_simulation' if candidate_key == 'requested_candidate' else 'simulation'
    REFS[key] = lines[0]
    stage_paths = sorted({m.group(1) for line in lines
                          if (m := re.match(r'^\d{6} [0-9a-f]{40} [123]\t(.+)$', line))})
    simulations[key] = {
        'candidate_key': candidate_key,
        'successor': REFS['successor'], 'candidate': REFS[candidate_key],
        'tree': lines[0], 'exit_code': result.returncode,
        'merge_bases': git('merge-base', '--all', REFS['successor'], REFS[candidate_key]).decode().splitlines(),
        'conflicts': [line for line in lines if line.startswith('CONFLICT')],
        'conflict_paths': stage_paths,
    }
    (OUT / f'successor-to-{key}.diff').write_bytes(git('diff', '--no-ext-diff', REFS['successor'], REFS[key]))

def entries(ref):
    result = {}
    for line in git('ls-tree', '-r', '-z', ref).split(b'\0'):
        if not line:
            continue
        header, path = line.split(b'\t', 1)
        mode, kind, oid = header.decode().split()
        if kind == 'blob':
            result[path.decode()] = {'mode': mode, 'git_blob': oid}
    return result

trees = {key: entries(ref) for key, ref in REFS.items()}

def changed(a, b):
    return {p.decode() for p in git('diff', '--name-only', '--no-renames', '-z', a, b).split(b'\0') if p}

paths = sorted(changed(REFS['accepted_base'], REFS['successor']) |
               changed(REFS['accepted_base'], REFS['candidate']))
extra = ['native/src/generation_spatial.cpp', 'native/include/cybersand/material.hpp',
         'native/include/cybersand/generation_spatial.hpp', 'native/include/cybersand/generation_numeric.hpp',
         'godot/native_extension/cyber_prepared_liquid_world.hpp',
         'godot/native_extension/workbench_retained_setup.hpp',
         'godot/scripts/main.gd', 'godot/scripts/shared_workbench.gd']
objects = sorted({v['git_blob'] for tree in trees.values() for p, v in tree.items()
                  if p in paths or p in extra or p.startswith('native/experiments/gentek_swarm/')
                  and pathlib.PurePosixPath(p).suffix in ('.cpp', '.hpp')})
raw = subprocess.check_output(['git', 'cat-file', '--batch'], cwd=ROOT, env=ENV,
                              input=('\n'.join(objects)+'\n').encode())
blobs, at = {}, 0
for oid in objects:
    end = raw.index(b'\n', at)
    header = raw[at:end].decode().split()
    size = int(header[2]); at = end + 1
    assert header[0] == oid and header[1] == 'blob'
    blobs[oid] = raw[at:at+size]; at += size + 1

def meta(tree, path):
    value = trees[tree].get(path)
    if not value:
        return None
    data = blobs[value['git_blob']]
    return {**value, 'sha256': digest(data), 'bytes': len(data)}

def definition(tree):
    prefix = 'native/experiments/gentek_swarm/'
    cpp = sorted(p for p in trees[tree] if p.startswith(prefix) and '/' not in p[len(prefix):] and p.endswith('.cpp'))
    hpp = sorted(p for p in trees[tree] if p.startswith(prefix) and '/' not in p[len(prefix):] and p.endswith('.hpp'))
    names = [(p[len(prefix):], p) for p in cpp+hpp] + [('../../../'+p, p) for p in extra[:4]]
    h = hashlib.sha256()
    for label, p in names:
        h.update(label.encode()+b'\0'+blobs[trees[tree][p]['git_blob']])
    return {'sha256': h.hexdigest(), 'input_count': len(names),
            'inputs': [{'label': label, 'path': p, **meta(tree, p)} for label, p in names]}

defs = {key: definition(key) for key in ('reviewed_successor', 'successor', 'frozen_candidate',
                                        'requested_candidate', 'candidate', 'requested_simulation', 'simulation')}
assert defs['successor']['sha256'] == '72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0'
assert defs['candidate']['sha256'] == '217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7'
assert defs['candidate'] == defs['requested_candidate'] == defs['frozen_candidate']
old = json.loads((OLD / 'source-custody.json').read_text())
assert defs['successor']['inputs'] == old['native_definitions']['successor']['inputs']
working_inputs = [{'path': row['path'], 'sha256': digest((ROOT / row['path']).read_bytes()),
                   'equals_reviewed_blob': digest((ROOT / row['path']).read_bytes()) == row['sha256']}
                  for row in defs['successor']['inputs']]
assert len(working_inputs) == 52 and all(row['equals_reviewed_blob'] for row in working_inputs)
repair = {
    'native/experiments/gentek_swarm/mosaic_recovery.cpp': 'ec9dbe6dd227b7b376763961c51b12b94ff7cb143f43e4999d3a6e2eec678850',
    'native/experiments/gentek_swarm/swarm006_recovery_tests.cpp': 'f099a2841fdb78f5bbadfd418719a7ec04f7bf7cebfed776a85fcf3d2418ffc9',
}
for p, expected in repair.items():
    assert meta('successor', p)['sha256'] == meta('simulation', p)['sha256'] == expected
native_delta = sorted(changed('5722f254144fb8bf84a94fa2881e8860c9512316', REFS['successor']) &
                      {p for p in trees['successor'] if p.startswith('native/experiments/gentek_swarm/')})
assert native_delta == sorted(repair)
conflicts = simulations['simulation']['conflict_paths']
rows = [{'path': p, 'textual_conflict': p in conflicts, **{k: meta(k, p) for k in REFS}} for p in paths]
projected_changes = sorted(changed(REFS['successor'], REFS['simulation']))
seams = {p: {k: meta(k, p) for k in ('successor', 'candidate', 'simulation')} for p in extra[4:]}
after = snapshot()
assert before == after, {'before': before, 'after': after}
record = {
    'schema': 2,
    'scope': 'Read-only provisional reconciliation: PR715 is unaccepted; no candidate code or binary was imported, checked out, or executed.',
    'refs': REFS, 'simulations': simulations, 'inventory_paths': len(rows), 'files': rows,
    'native_definitions': defs,
    'native_review_projection': {
        'reviewed_commit': REFS['reviewed_successor'], 'published_commit': REFS['successor'],
        'same_52_definition_inputs': True, 'working_inputs': working_inputs,
        'same_reviewed_repair_bytes': repair,
        'only_native_delta_since_integrated_5722': native_delta,
        'qualification_claim': 'Exact-source projection only. No new build or runtime tests. Candidate receiver-accounting changes and any eventual combined source are not approved by this projection.',
    },
    'host_seams': seams,
    'candidate_frozen_to_requested_paths': sorted(changed(REFS['frozen_candidate'], REFS['requested_candidate'])),
    'candidate_requested_to_live_paths': sorted(changed(REFS['requested_candidate'], REFS['candidate'])),
    'projected_changes_from_successor': projected_changes,
    'source_untouched': {'before': before, 'after': after, 'equal': True},
}
(OUT / 'source-custody.json').write_text(json.dumps(record, indent=2)+'\n')
(OUT / 'simulation.json').write_text(json.dumps(simulations, indent=2)+'\n')
print(json.dumps({
    'refs': REFS, 'simulations': simulations,
    'inventory_paths': len(rows), 'projected_changes_count': len(projected_changes),
    'definitions': {k: {'sha256': v['sha256'], 'input_count': v['input_count']} for k, v in defs.items()},
    'candidate_requested_to_live_paths': record['candidate_requested_to_live_paths'],
    'host_seams': {p: {k: v['git_blob'] if v else None for k, v in values.items()} for p, values in seams.items()},
    'same_52_reviewed_native_inputs': True, 'source_untouched': True,
}, indent=2))
