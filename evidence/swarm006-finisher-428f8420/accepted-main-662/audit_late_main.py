"""Read-only source-impact review; all generated files/objects stay beside this file."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess

ROOT = Path('/workspace/scratch/d425b9146667/cybersand-swarm006-finisher')
OUT = Path(__file__).resolve().parent
WORK = ROOT.parent
BASE = '846fe0533b3170e7b01f690518da49fc40cc24d1'
PREVIOUS = '30e1cddd3d678456df10f52f7a2fb2210a9daaad'
MAIN = '662df51cd8409a52332fa7ef15d06d8ab8945aed'
HEAD = '428f842034a1f80d593bcc6bb32af2dd99cd0105'
TREE = 'cb1f4fdaf7b9cb487e850f1702a4f9085d0cb300'
PRIOR = WORK / 'swarm006-evidence/workbench-dev/accepted-main-30e1cddd-preflight-428f8420'
PENDING = WORK / 'swarm006-evidence/workbench-dev/pending-pr715-reconciliation-ca634458'
HOSTED = WORK / 'swarm006-evidence/hosted-428f8420'
RUNTIME = HOSTED / 'swarm006-finisher-windows-runtime-44959721570'
WINDOWS = HOSTED / 'swarm006-finisher-windows-evidence-44959721570'
DELIVERY = WORK / 'swarm006-delivery'
SCIENCE = WORK / 'swarm006-science-custody/native-carry-forward-428f8420.json'
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS='0')

def git(*args, env=None):
    return subprocess.check_output(['git', *args], cwd=ROOT, env=env or ENV)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def file_sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def load(path):
    return json.loads(path.read_text())

protected_paths = [DELIVERY / 'Qualification-Report.md', DELIVERY / 'source-state.json',
    DELIVERY / 'owner-package-custody.json', DELIVERY / 'Owner-Acceptance.md', SCIENCE,
    DELIVERY / 'CyberSand-SWARM006-Finisher-428f842034a1-Evidence.zip',
    DELIVERY / 'CyberSand-SWARM006-Draft-HOLD-Windows-428f842034a1.zip']
protected_paths += [p for folder in (PRIOR, PENDING) for p in sorted(folder.iterdir()) if p.is_file()]

def snapshot():
    index = Path(git('rev-parse', '--git-path', 'index').decode().strip())
    if not index.is_absolute():
        index = ROOT / index
    return {'head': git('rev-parse', 'HEAD').decode().strip(),
        'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
        'branch': git('branch', '--show-current').decode().strip(),
        'status': git('status', '--porcelain=v1', '--untracked-files=all').decode(),
        'index_sha256': file_sha(index),
        'refs_sha256': sha(git('for-each-ref', '--format=%(refname) %(objectname)')),
        'protected_files': {str(p): {'sha256': file_sha(p), 'bytes': p.stat().st_size} for p in protected_paths}}

before = snapshot()
assert before['head'] == HEAD and before['tree'] == TREE and not before['status']
expected_protected = {
    'Qualification-Report.md': '441f8674fd6de9c99a45a9789136926a4ad0e7af9210ca446d1d4a33b575b0c7',
    'source-state.json': '42b8d169d442e81a568eadd2388afcc788b755435073c58eb0f57584ea58ceef',
    'owner-package-custody.json': 'f7bc0e29c1e4a899ea357145b5e724dacb6fffbe128be3d6c67220605d2fafb5',
    'CyberSand-SWARM006-Finisher-428f842034a1-Evidence.zip': 'ec2fca91e6ecf08873c39e9c153bcda25a83c1d2fe6bba570c5a0e7a2fa43067',
    'CyberSand-SWARM006-Draft-HOLD-Windows-428f842034a1.zip': '2462275ad0093097b3c80b6bfe6fb543780b2b53cf3ee2ec56829c4341c7f015'}
for name, expected in expected_protected.items():
    assert before['protected_files'][str(DELIVERY / name)]['sha256'] == expected, name

remote = load(OUT / 'accepted-662df51c-github-commit.json')
comparison = load(OUT / 'accepted-30e-to-662-github-compare.json')
pr715 = load(OUT / 'pr715-status-observation.json')
parents = git('show', '-s', '--format=%P', MAIN).decode().strip().split()
assert remote['sha'] == MAIN
assert parents == [PREVIOUS, '19023b4016facfda2b13b9a1503742e4a9fe1982'] == [p['sha'] for p in remote['parents']]
assert git('rev-parse', MAIN + '^{tree}').decode().strip() == remote['tree']['sha'] == '39b658c5de9c5e541312b5190bd5d8ba797c6bed'
assert pr715['draft'] is True and pr715['merged'] is False and pr715['head_sha'] == '919134a39d31461947c410c233d59d1965c48414'
changed = git('diff', '--name-only', PREVIOUS, MAIN).decode().splitlines()
cumulative = git('diff', '--name-only', BASE, MAIN).decode().splitlines()
assert len(changed) == 13 and changed == sorted(f['filename'] for f in comparison['files'])
stats = {p: {'additions': int(a), 'deletions': int(d)} for a, d, p in
    (line.split('\t') for line in git('diff', '--numstat', PREVIOUS, MAIN).decode().splitlines())}
for f in comparison['files']:
    assert stats[f['filename']] == {k: f[k] for k in ('additions', 'deletions')}
patch = git('diff', '--binary', '--full-index', PREVIOUS, MAIN)
(OUT / 'accepted-30e1cddd-to-662df51c.patch').write_bytes(patch)

# merge-tree writes only to this new review directory; no repository objects,
# index, refs, working files, runtimes or pre-existing evidence are modified.
objects = OUT / 'temporary-git-objects'
objects.mkdir()
repo_objects = Path(git('rev-parse', '--git-path', 'objects').decode().strip())
if not repo_objects.is_absolute():
    repo_objects = ROOT / repo_objects
merge_env = dict(ENV, GIT_OBJECT_DIRECTORY=str(objects), GIT_ALTERNATE_OBJECT_DIRECTORIES=str(repo_objects))
run = subprocess.run(['git', 'merge-tree', '--write-tree', '--messages', HEAD, MAIN], cwd=ROOT,
    env=merge_env, capture_output=True)
assert run.returncode in (0, 1), run.stderr
(OUT / 'merge-tree.stdout.txt').write_bytes(run.stdout)
(OUT / 'merge-tree.stderr.txt').write_bytes(run.stderr)
lines = run.stdout.decode().splitlines()
projected = lines[0]
assert re.fullmatch('[0-9a-f]{40}', projected)
conflicts = sorted({m.group(1) for line in lines if (m := re.match(r'^\d{6} [0-9a-f]{40} [123]\t(.+)$', line))})
projection_patch = git('diff', '--binary', '--full-index', HEAD, projected, env=merge_env)
(OUT / 'qualified-428-to-unresolved-accepted-main-projection.patch').write_bytes(projection_patch)
refs = {'qualified_successor': HEAD, 'accepted_foundation': BASE, 'previous_accepted_main': PREVIOUS,
        'new_accepted_main': MAIN, 'unresolved_preflight_tree': projected}

def entries(ref):
    result = {}
    for line in git('ls-tree', '-r', '-z', ref, env=merge_env).split(b'\0'):
        if not line:
            continue
        header, path = line.split(b'\t', 1)
        mode, kind, oid = header.decode().split()
        if kind == 'blob':
            result[path.decode()] = {'mode': mode, 'git_blob': oid}
    return result

trees = {name: entries(ref) for name, ref in refs.items()}
blob_cache = {}
def blob(oid):
    if oid not in blob_cache:
        blob_cache[oid] = git('cat-file', 'blob', oid, env=merge_env)
    return blob_cache[oid]

def metadata(key, path):
    item = trees[key].get(path)
    if item is None:
        return None
    data = blob(item['git_blob'])
    return {**item, 'sha256': sha(data), 'bytes': len(data)}

rows = [{'path': p, **stats[p], 'conflicted_in_cumulative_preflight': p in conflicts,
    **{key: metadata(key, p) for key in refs}} for p in changed]

def project(name, selected, source=None):
    selected = sorted(selected)
    missing = [p for p in selected if p not in trees['unresolved_preflight_tree']]
    differences = [p for p in selected if trees['qualified_successor'].get(p) != trees['unresolved_preflight_tree'].get(p)]
    assert not missing and not differences, (name, missing, differences)
    inventory = {p: trees['qualified_successor'][p] for p in selected}
    return {'name': name, 'path_count': len(selected),
        'path_mode_blob_inventory_sha256': sha(json.dumps(inventory, sort_keys=True, separators=(',', ':')).encode()),
        'source_inventory': str(source) if source else None,
        'source_inventory_sha256': file_sha(source) if source else None,
        'same_git_mode_and_blob': True, 'missing_paths': missing, 'changed_paths': differences}

cli_path = RUNTIME / 'reciprocal-runtime-provenance.json'
adapter_path = RUNTIME / 'candidate-provenance.json'
preservation_path = WINDOWS / 'swarm006-preservation/identity.json'
cli, adapter, preservation = map(load, (cli_path, adapter_path, preservation_path))
for record in (cli, adapter):
    assert record['source_commit'] == HEAD and record['source_tree'] == TREE
assert preservation['source'] == HEAD
for inventory in (cli['source_inputs_sha256'], adapter['source_inputs']):
    for p, expected in inventory.items():
        assert sha(blob(trees['qualified_successor'][p]['git_blob']).replace(b'\r\n', b'\n')) == expected, p
science = load(SCIENCE)
assert science['final_source'] == HEAD and science['final_tree'] == TREE
for p, expected in science['native_inputs'].items():
    assert metadata('qualified_successor', p)['sha256'] == expected, p
for r in science['frozen_scientific_inputs']:
    assert metadata('qualified_successor', r['path'])['sha256'] == r['sha256']
projections = [project('qualified CLI source inputs', cli['source_inputs_sha256'], cli_path),
    project('qualified GDExtension source inputs', adapter['source_inputs'], adapter_path),
    project('qualified Windows preservation inputs', preservation['inputs'], preservation_path),
    project('entire native subtree', (p for p in trees['qualified_successor'] if p.startswith('native/'))),
    project('entire Godot subtree', (p for p in trees['qualified_successor'] if p.startswith('godot/'))),
    project('SWARM006 qualification and package tools', (p for p in trees['qualified_successor'] if p.startswith('tools/swarm006/'))),
    project('actual native science build inventory', science['native_inputs'], SCIENCE),
    project('frozen scientific registration, runner and orchestrator', [r['path'] for r in science['frozen_scientific_inputs']], SCIENCE),
    project('scoped workflow, packaging helper, candidate identity and attributes', [
        '.github/workflows/swarm006-finisher-qualification.yml', '.gitattributes',
        'tools/package_explore001_candidate.py', 'tools/ci/native_candidate_identity.py'])]
prior = load(PRIOR / 'accepted-main-preflight.json')
definition = hashlib.sha256()
for row in prior['native_definition_inputs']:
    assert metadata('qualified_successor', row['path']) == {k: row[k] for k in ('mode', 'git_blob', 'sha256', 'bytes')}
    assert metadata('unresolved_preflight_tree', row['path']) == metadata('qualified_successor', row['path'])
    definition.update(row['label'].encode() + b'\0' + blob(row['git_blob']))
assert len(prior['native_definition_inputs']) == 52 and definition.hexdigest() == science['native_definition_sha256']

def rule(text, target):
    found = re.search(r'^' + re.escape(target) + r':[^\n]*\n(?:\t[^\n]*\n)*', text, re.M)
    assert found, target
    return found.group(0)

old_make = blob(trees['qualified_successor']['Makefile']['git_blob']).decode()
new_make = blob(trees['unresolved_preflight_tree']['Makefile']['git_blob']).decode()
make_projection = {}
for target in ('workbench-authoring-patch-test', '$(BUILD_DIR)/test_workbench_authoring_patch'):
    old, new = rule(old_make, target), rule(new_make, target)
    assert old == new
    make_projection[target] = {'unchanged': True, 'text': old, 'sha256': sha(old.encode())}
def assignments(text, variable):
    lines, result = text.splitlines(keepends=True), []
    for index, line in enumerate(lines):
        if not re.match(r'^' + re.escape(variable) + r'\s*[:?+]?=', line):
            continue
        selected = [line]
        while selected[-1].rstrip('\r\n').endswith('\\'):
            index += 1
            selected.append(lines[index])
        result.append(''.join(selected))
    return result

for variable in ('CXX', 'COMMON_FLAGS', 'DEBUG_FLAGS', 'CORE_SOURCES'):
    old, new = assignments(old_make, variable), assignments(new_make, variable)
    assert old and old == new, variable
    make_projection[variable] = {'unchanged': True, 'text': old}

projected_paths = git('diff', '--name-only', HEAD, projected, env=merge_env).decode().splitlines()
assert projected_paths == cumulative
assert conflicts == ['docs/reference/status-and-roadmap.md'] and run.returncode == 1
shutil.rmtree(objects)
after = snapshot()
assert before == after
record = {'schema': 'cybersand-swarm006-late-main-source-impact-review-v1',
    'recorded_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'reviewer': '/root/swarm006_platform_review; independent platform/publication reviewer',
    'status': 'GO_UNCHANGED_428_DELIVERY_WITH_EXPLICIT_PENDING_MAIN_INCORPORATION',
    'scope': 'Read-only accepted30e-to662 source delta and cumulative accepted-only projection; no runtime test, build or new qualification.',
    'refs': refs, 'qualified_tree': TREE, 'new_accepted_main_tree': remote['tree']['sha'],
    'new_accepted_main_parents': parents, 'new_accepted_main_commit_time': remote['committer']['date'],
    'remote_commit_sha256': file_sha(OUT / 'accepted-662df51c-github-commit.json'),
    'remote_compare_sha256': file_sha(OUT / 'accepted-30e-to-662-github-compare.json'),
    'pr715': pr715, 'accepted_delta_path_count': len(changed), 'accepted_delta_paths': rows,
    'accepted_patch_sha256': sha(patch), 'cumulative_accepted_changed_paths': cumulative,
    'merge_preflight': {'returncode': run.returncode, 'tree': projected,
        'merge_bases': git('merge-base', '--all', HEAD, MAIN).decode().splitlines(),
        'conflict_paths': conflicts, 'messages': [s for s in lines if s.startswith('CONFLICT')],
        'changed_paths_from_qualified': projected_paths, 'patch_sha256': sha(projection_patch),
        'object_writes_confined_to_new_review_directory': True, 'temporary_objects_removed': True},
    'unchanged_input_projections': projections, 'make_target_projection': make_projection,
    'native_definition_sha256': definition.hexdigest(), 'native_definition_path_count': 52,
    'science_custody': {'mapping_sha256': file_sha(SCIENCE),
        'actual_execution_source': science['actual_execution_source'],
        'actual_new_candidate_executions': science['actual_new_candidate_executions'],
        'retained_reference_executions': science['actual_retained_reference_executions'],
        'final_source': science['final_source'],
        'final_labelled_executions': science['native_executions_performed_under_final_source_label'],
        'new_662_labelled_executions': 0, 'mapping_unchanged': True},
    'source_and_protected_artifacts_untouched': {'before': before, 'after': after, 'equal': True},
    'sealed_snapshot': {'report_live_main': PREVIOUS, 'qualified_software': HEAD, 'qualified_foundation': BASE,
        'archive_sha256': expected_protected['CyberSand-SWARM006-Finisher-428f842034a1-Evidence.zip'],
        'new_main_observation_is_separate_append_only_addendum': True},
    'qualification_disposition': 'Existing qualification remains exact428/treecb1f on foundation846. Neither30e nor662 is incorporated. No receipts, binary identities or archive labels are changed; equal projected inputs do not constitute qualification of662 or any future combined source.',
    'pending_contract': 'Revalidate actual accepted004/005 merge and then-current main; incorporate both accepted CI increments with that accepted source, retain CI log/command gates and all donor/recovery authority boundaries, resolve additive roadmap conflict, renew resulting-source runtime/custody/qualification as required. Do not import unmerged715. Latest-main incorporation remains deliberately pending, not technically impossible.',
    'immediate_source_repair_required': False, 'review_limit': 'Does not independently requalify CI-OPT-003 performance/concurrency or physical NVIDIA/original owner-world behavior.'}
(OUT / 'accepted-main-review.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'status': record['status'], 'new_delta_paths': len(changed), 'cumulative_paths': len(cumulative),
    'conflicts': conflicts, 'projections': [{k: v for k, v in p.items() if k in ('name', 'path_count', 'changed_paths')} for p in projections],
    'native_definition': definition.hexdigest(), 'source_and_sealed_artifacts_untouched': True,
    'review_sha256': file_sha(OUT / 'accepted-main-review.json')}, indent=2))
