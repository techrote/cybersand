"""Read-only accepted-CI preflight; writes only external evidence and Git tree objects."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import subprocess

ROOT = Path('/workspace/scratch/d425b9146667/cybersand-swarm006-finisher')
OUT = Path(__file__).resolve().parent
BASE = '846fe0533b3170e7b01f690518da49fc40cc24d1'
HEAD = '428f842034a1f80d593bcc6bb32af2dd99cd0105'
MAIN = '30e1cddd3d678456df10f52f7a2fb2210a9daaad'
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS='0')
OLD = OUT.parent / 'pending-pr715-reconciliation-ca634458'
HOSTED = ROOT.parent / 'swarm006-evidence/hosted-428f8420'
RUNTIME = HOSTED / 'swarm006-finisher-windows-runtime-44959721570'
WINDOWS = HOSTED / 'swarm006-finisher-windows-evidence-44959721570'
OWNER = HOSTED / ('swarm006-finisher-owner-windows-' + HEAD)
REMOTE = ROOT.parent / 'swarm006-evidence/platform-final/accepted-ci-only-main-30e-commit.json'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, env=ENV)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def file_sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def snapshot():
    index = Path(git('rev-parse', '--git-path', 'index').decode().strip())
    if not index.is_absolute(): index = ROOT / index
    return {'head': git('rev-parse', 'HEAD').decode().strip(),
            'status': git('status', '--porcelain=v1', '--untracked-files=all').decode(),
            'branch': git('branch', '--show-current').decode().strip(),
            'index_sha256': file_sha(index),
            'refs_sha256': sha(git('for-each-ref', '--format=%(refname) %(objectname)')),
            'old_projection_files': {p.name: file_sha(p) for p in sorted(OLD.iterdir()) if p.is_file()}}

before = snapshot()
assert before['head'] == HEAD and not before['status']
remote = json.loads(REMOTE.read_text())
assert remote['sha'] == MAIN
assert [p['sha'] for p in remote['parents']] == [BASE, 'cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55']
paths = git('diff', '--name-only', BASE, MAIN).decode().splitlines()
assert len(paths) == 9 and set(paths) == {f['filename'] for f in remote['files']}
patch = git('diff', '--binary', '--full-index', BASE, MAIN)
(OUT / 'accepted-846fe053-to-30e1cddd.patch').write_bytes(patch)
run = subprocess.run(['git', 'merge-tree', '--write-tree', '--messages', HEAD, MAIN],
                     cwd=ROOT, env=ENV, capture_output=True)
assert run.returncode in (0, 1), run.stderr
(OUT / 'merge-tree.stdout.txt').write_bytes(run.stdout)
(OUT / 'merge-tree.stderr.txt').write_bytes(run.stderr)
lines = run.stdout.decode().splitlines()
simulation = lines[0]
assert re.fullmatch('[0-9a-f]{40}', simulation)
conflicts = sorted({m.group(1) for line in lines
                    if (m := re.match(r'^\d{6} [0-9a-f]{40} [123]\t(.+)$', line))})
(OUT / 'qualified-to-preflight-tree.diff').write_bytes(git('diff', '--binary', '--full-index', HEAD, simulation))
refs = {'accepted_foundation': BASE, 'qualified_successor': HEAD,
        'accepted_main': MAIN, 'preflight_tree': simulation}

def entries(ref):
    result = {}
    for line in git('ls-tree', '-r', '-z', ref).split(b'\0'):
        if not line: continue
        header, path = line.split(b'\t', 1)
        mode, kind, oid = header.decode().split()
        if kind == 'blob': result[path.decode()] = {'mode': mode, 'git_blob': oid}
    return result

trees = {name: entries(ref) for name, ref in refs.items()}
blobs = {}

def blob(oid):
    if oid not in blobs: blobs[oid] = git('cat-file', 'blob', oid)
    return blobs[oid]

def metadata(key, path):
    item = trees[key].get(path)
    if item is None: return None
    data = blob(item['git_blob'])
    return {**item, 'sha256': sha(data), 'bytes': len(data)}

rows = [{'path': p, 'conflicted': p in conflicts,
         **{key: metadata(key, p) for key in refs}} for p in paths]

def project(name, selected):
    selected = sorted(selected)
    missing = [p for p in selected if p not in trees['preflight_tree']]
    changed = [p for p in selected if trees['qualified_successor'].get(p) != trees['preflight_tree'].get(p)]
    assert not missing and not changed, (name, missing, changed)
    return {'name': name, 'path_count': len(selected), 'paths': selected,
            'same_git_mode_and_blob': True, 'missing_paths': missing, 'changed_paths': changed}

cli = json.loads((RUNTIME / 'reciprocal-runtime-provenance.json').read_text())
adapter = json.loads((RUNTIME / 'candidate-provenance.json').read_text())
preservation = json.loads((WINDOWS / 'swarm006-preservation/identity.json').read_text())
for record in (cli, adapter):
    assert record['source_commit'] == HEAD
    assert record['source_tree'] == git('rev-parse', HEAD + '^{tree}').decode().strip()
assert preservation['source'] == HEAD
for record in (cli['source_inputs_sha256'], adapter['source_inputs']):
    for p, expected in record.items():
        assert sha(blob(trees['qualified_successor'][p]['git_blob']).replace(b'\r\n', b'\n')) == expected, p
projections = [project('qualified CLI source inventory', cli['source_inputs_sha256']),
               project('qualified adapter source inventory', adapter['source_inputs']),
               project('qualified Windows preservation inventory', preservation['inputs']),
               project('entire native subtree', (p for p in trees['qualified_successor'] if p.startswith('native/'))),
               project('entire Godot subtree', (p for p in trees['qualified_successor'] if p.startswith('godot/'))),
               project('SWARM006 qualification and package tools', (p for p in trees['qualified_successor'] if p.startswith('tools/swarm006/'))),
               project('pinned workflow, packaging and attributes', ['.github/workflows/swarm006-finisher-qualification.yml',
                    '.gitattributes', 'tools/package_explore001_candidate.py', 'tools/ci/native_candidate_identity.py'])]
prior = json.loads((OLD / 'native-source-review-projection.json').read_text())
definition = hashlib.sha256()
native_rows = []
for row in prior['inputs']:
    p = row['path']; current = metadata('qualified_successor', p)
    assert current == {k: row[k] for k in ('mode', 'git_blob', 'sha256', 'bytes')}
    assert metadata('preflight_tree', p) == current
    definition.update(row['label'].encode() + b'\0' + blob(current['git_blob']))
    native_rows.append({'label': row['label'], 'path': p, **current})
assert len(native_rows) == 52 and definition.hexdigest() == prior['native_definition_sha256']

def rule(text, target):
    found = re.search(r'^' + re.escape(target) + r':[^\n]*\n(?:\t[^\n]*\n)*', text, re.M)
    assert found, target
    return found.group(0)

make_old = blob(trees['qualified_successor']['Makefile']['git_blob']).decode()
make_new = blob(trees['preflight_tree']['Makefile']['git_blob']).decode()
target_projection = {}
for target in ('workbench-authoring-patch-test', '$(BUILD_DIR)/test_workbench_authoring_patch'):
    a, b = rule(make_old, target), rule(make_new, target)
    assert a == b
    target_projection[target] = {'text': a, 'sha256': sha(a.encode()), 'unchanged': True}
for variable in ('CXX', 'COMMON_FLAGS', 'DEBUG_FLAGS', 'CORE_SOURCES'):
    pattern = r'^' + re.escape(variable) + r'\s*[:?+]?=.*$'
    a, b = re.findall(pattern, make_old, re.M), re.findall(pattern, make_new, re.M)
    assert a and a == b
    target_projection[variable] = {'text': a, 'unchanged': True}

artifact_files = [RUNTIME / 'reciprocal-runtime-provenance.json', RUNTIME / 'candidate-provenance.json',
                  WINDOWS / 'swarm006-preservation/identity.json',
                  WINDOWS / 'swarm006-preservation/qualification.json',
                  WINDOWS / 'swarm006-source/qualification.json',
                  WINDOWS / 'swarm006-package/qualification.json',
                  WINDOWS / 'swarm006-final-custody/identity-recheck.json', OWNER / 'swarm006-owner-seal.json']
artifact_rows = []
for p in artifact_files:
    value = json.loads(p.read_text())
    artifact_rows.append({'path': str(p), 'sha256': file_sha(p), 'bytes': p.stat().st_size,
                          'source': value.get('source_commit', value.get('source')),
                          'tree': value.get('source_tree', value.get('tree')),
                          'passed': value.get('passed'), 'errors': value.get('errors')})
binary_rows = []
for name, record in cli['files'].items():
    p = RUNTIME / name
    assert file_sha(p) == record['sha256'] and p.stat().st_size == record['bytes']
    binary_rows.append({'path': str(p), **record, 'hash_verified': True})
dll = RUNTIME / 'cybersand_native.windows.x86_64.dll'
assert file_sha(dll) == adapter['sha256'] == cli['extension_sha256']
binary_rows.append({'path': str(dll), 'sha256': adapter['sha256'], 'bytes': dll.stat().st_size, 'hash_verified': True})
zip_path = next(OWNER.glob('*.zip'))
zip_sha = file_sha(zip_path)
assert zip_sha in Path(str(zip_path) + '.sha256').read_text()
package = {'path': str(zip_path), 'sha256': zip_sha, 'bytes': zip_path.stat().st_size,
           'hash_verified_against_sha256_sidecar': True,
           'scope': 'Existing exact428 evaluator; no package changed or relabelled.'}
after = snapshot()
assert before == after
record = {'schema': 1, 'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'scope': 'Read-only accepted CI-only delta and exact428 evidence projection; not a new qualification or accepted004/005 reconciliation.',
          'refs': refs, 'qualified_tree': git('rev-parse', HEAD+'^{tree}').decode().strip(),
          'accepted_main_tree': git('rev-parse', MAIN+'^{tree}').decode().strip(),
          'accepted_main_parents': [p['sha'] for p in remote['parents']],
          'remote_metadata': {'path': str(REMOTE), 'sha256': file_sha(REMOTE), 'url': remote['html_url']},
          'accepted_paths': rows, 'accepted_patch_sha256': sha(patch),
          'merge_preflight': {'returncode': run.returncode, 'tree': simulation,
               'merge_bases': git('merge-base', '--all', HEAD, MAIN).decode().splitlines(),
               'conflict_paths': conflicts, 'messages': [s for s in lines if s.startswith('CONFLICT')],
               'changed_paths_from_qualified': git('diff', '--name-only', HEAD, simulation).decode().splitlines()},
          'unchanged_input_projections': projections, 'make_target_projection': target_projection,
          'cli_and_adapter_qualified_hashes_match_git_source': True,
          'native_definition_sha256': definition.hexdigest(), 'native_definition_inputs': native_rows,
          'preserved_qualification_artifacts': artifact_rows, 'verified_runtime_artifacts': binary_rows,
          'verified_owner_archive': package, 'source_untouched': {'before': before, 'after': after, 'equal': True},
          'qualification_limit': 'The existing receipts remain bound to commit428/treecb1f. Equal effective inputs do not satisfy their exact commit/tree checks for a future merge; no receipt was reissued.',
          'recommendation': 'Deliver the unchanged exact428 evaluator with truthful846 foundation and live30e pending-source notice. Preserve latest-main incorporation as an open objective; do not relabel the evaluator or import unmerged715. Batch a future accepted-main reconciliation if chosen, with applicable resulting-source checks and exact-source evidence renewal.'}
(OUT / 'accepted-main-preflight.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps({'accepted_paths': paths, 'merge_preflight': record['merge_preflight'],
                  'projections': [{k:v for k,v in p.items() if k!='paths'} for p in projections],
                  'native_definition_sha256': definition.hexdigest(), 'verified_owner_archive': package,
                  'source_untouched': True, 'receipt_sha256': file_sha(OUT / 'accepted-main-preflight.json')}, indent=2))
