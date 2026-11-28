"""Independent stream-manifest audit of the exact final M6/M7 Windows owner ZIP.

Uses the retained original artifact; never launches a native process.
A package pass does not replace fresh extracted execution or physical acceptance.
"""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import io
import tarfile
import json
import shutil
import stat
import subprocess
import zipfile


def digest_file(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def safe_names(archive):
    names = [entry.filename for entry in archive.infolist()]
    assert len(names) == len(set(names)), 'Duplicate ZIP member'
    assert len(names) == len({name.casefold() for name in names}), 'Windows case collision'
    for entry in archive.infolist():
        name = entry.filename
        assert not name.startswith('/') and '\\' not in name and ':' not in name
        assert '..' not in PurePosixPath(name).parts
        assert not stat.S_ISLNK(entry.external_attr >> 16), 'Symlink member'
    return {entry.filename for entry in archive.infolist() if not entry.is_dir()}


def preserve(path, data):
    if path.exists():
        assert path.read_bytes() == data, 'Refusing to replace different retained bytes: '+str(path)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--outer', required=True, type=Path)
parser.add_argument('--outer-sha256', required=True)
parser.add_argument('--artifact-id', required=True, type=int)
parser.add_argument('--source', required=True)
parser.add_argument('--tree', required=True)
parser.add_argument('--native-sha256', required=True)
parser.add_argument('--run-id', required=True, type=int)
parser.add_argument('--repo', required=True, type=Path)
args = parser.parse_args()
base = args.outer.resolve().parent
assert digest_file(args.outer) == args.outer_sha256
inner_name = 'CyberSand-Architecture-Workbench-Windows-'+args.source[:12]+'.zip'
inner_path = base / inner_name
with zipfile.ZipFile(args.outer) as outer:
    assert safe_names(outer) == {inner_name, inner_name+'.sha256'}
    sidecar = outer.read(inner_name+'.sha256')
    fields = sidecar.decode('utf-8-sig').strip().split()
    assert len(fields) == 2 and fields[1].lstrip('*') == inner_name
    expected_inner = fields[0].lower()
    assert len(expected_inner) == 64 and all(c in '0123456789abcdef' for c in expected_inner)
    if not inner_path.exists():
        partial = base / (inner_name+'.partial')
        with outer.open(inner_name) as source, partial.open('xb') as destination:
            shutil.copyfileobj(source, destination, 1024*1024)
        assert digest_file(partial) == expected_inner
        partial.rename(inner_path)
    assert digest_file(inner_path) == expected_inner
    preserve(base/(inner_name+'.sha256'), sidecar)

with zipfile.ZipFile(inner_path) as package:
    files = safe_names(package)
    manifest_bytes = package.read('candidate-manifest.json')
    manifest = json.loads(manifest_bytes)
    assert manifest['source_commit'] == args.source and manifest['source_tree'] == args.tree
    assert manifest['native_sha256'] == args.native_sha256
    hashes = manifest['files_sha256']
    for name, expected in hashes.items():
        assert name in files, name
        with package.open(name) as stream:
            assert hashlib.file_digest(stream, 'sha256').hexdigest() == expected, name
    assert files-set(hashes) == {'candidate-manifest.json'}
    native = json.loads(package.read('source-built-candidate-provenance.json'))
    assert native['source_commit'] == native['build_commit'] == args.source
    assert native['source_tree'] == args.tree and native['sha256'] == args.native_sha256
    assert native['size'] == package.getinfo(native['artifact']).file_size
    with package.open(native['artifact']) as stream:
        assert stream.read(2) == b'MZ'
    assert len(native['source_inputs']) == 105
    reference_commits = [args.source, 'f5f6e9f35727d81868bcced4da8b913b470ea635', 'fe2395c7060dae736dc2e5dc8d1e4e050b2d2e52', '76fcf209e0cda5820aa64e104bfae732075ae7c3']
    for commit in reference_commits:
        for name, expected in native['source_inputs'].items():
            raw = subprocess.check_output(['git', 'show', commit+':'+name], cwd=args.repo)
            assert hashlib.sha256(raw.replace(b'\r\n', b'\n')).hexdigest() == expected, (commit, name)
    actual_tree = subprocess.check_output(['git', 'rev-parse', args.source+'^{tree}'], cwd=args.repo, text=True).strip()
    assert actual_tree == args.tree

    # Independently bind every bundled repository source/asset, including files
    # outside the qualification runner's narrower executable identity index.
    tracked = set(subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', args.source], cwd=args.repo, text=True).splitlines())
    committed_files_verified = 0
    platform_converted_source_files = []
    derived_profiles_verified = 0
    for name, expected in hashes.items():
        if name == native['artifact'] or name.startswith('architecture-evidence/'):
            continue
        mapped = name
        if name == 'godot/addons/cybersand_native/retained-runtime-provenance.reference.json':
            mapped = 'godot/addons/cybersand_native/runtime-provenance.json'
        elif name == 'READ-ME.md':
            mapped = 'docs/operations/world-steer-collaborative-architecture.md'
        elif name.startswith('godot/authoring/worldgen/'):
            mapped = 'examples/worldgen/'+name.rsplit('/', 1)[-1]
            assert hashes[mapped] == expected
            derived_profiles_verified += 1
        if mapped not in tracked:
            assert not name.startswith('godot/'), ('Unrecognized packaged project file', name)
            continue
        committed = subprocess.check_output(['git', 'show', args.source+':'+mapped], cwd=args.repo)
        if committed.startswith(b'version https://git-lfs.github.com/spec/v1\n'):
            pointer = dict(line.split(' ',1) for line in committed.decode().splitlines()[1:])
            assert pointer['oid'] == 'sha256:'+expected and int(pointer['size']) == package.getinfo(name).file_size, name
        else:
            if hashlib.sha256(committed).hexdigest() != expected:
                actual = package.read(name)
                assert actual.replace(b'\r\n', b'\n') == committed, name
                platform_converted_source_files.append({'path': name, 'git_path': mapped,
                    'git_sha256': hashlib.sha256(committed).hexdigest(), 'packaged_sha256': expected})
        committed_files_verified += 1
    if platform_converted_source_files:
        paths = sorted(set(row['git_path'] for row in platform_converted_source_files))
        raw_archive = subprocess.check_output(['git', '-c', 'core.autocrlf=true', 'archive',
                                              '--format=tar', args.source, '--', *paths], cwd=args.repo)
        with tarfile.open(fileobj=io.BytesIO(raw_archive)) as archive:
            for row in platform_converted_source_files:
                assert archive.extractfile(row['git_path']).read() == package.read(row['path']), row['path']
                row['exact_windows_git_archive_match'] = True

    qualification_bytes = package.read('architecture-evidence/source-qualification.json')
    qualification = json.loads(qualification_bytes)
    qualification_digest = hashlib.sha256(qualification_bytes).hexdigest()
    evidence = json.loads(package.read('architecture-evidence/evidence-provenance.json'))
    assert qualification['source_commit'] == evidence['source_commit'] == args.source
    assert qualification['status'] == 'passed' and qualification['graphical'] is True
    assert qualification['platform'] == 'win32' and qualification['packaged'] is False
    assert qualification['development_dirty_allowed'] is False and qualification['architecture_m3_m5'] is True
    assert qualification['actual_model_calls'] == evidence['actual_model_calls'] == 0
    assert qualification['physical_owner_acceptance'] == evidence['physical_owner_acceptance'] == 'pending'
    assert evidence['graphical'] is True and evidence['platform'] == 'win32'
    assert evidence['native_sha256'] == args.native_sha256
    assert qualification_digest == evidence['qualification_sha256'] == manifest['architecture_evidence']['qualification_sha256']
    assert len(qualification['results']) == 89
    assert all(row['status'] == 'passed' and row['exit_code'] == 0 for row in qualification['results'])
    assert len(qualification['source_files_sha256']) >= 100
    for name, expected in qualification['source_files_sha256'].items():
        assert hashes['godot/'+name] == expected, name
        if name == 'addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll':
            assert expected == args.native_sha256
            continue
        committed = subprocess.check_output(['git', 'show', args.source+':godot/'+name], cwd=args.repo)
        if committed.startswith(b'version https://git-lfs.github.com/spec/v1\n'):
            fields = dict(line.split(' ',1) for line in committed.decode().splitlines()[1:])
            assert fields['oid'] == 'sha256:'+expected, name
            assert int(fields['size']) == package.getinfo('godot/'+name).file_size, name
        else:
            assert hashlib.sha256(committed).hexdigest() == expected, name
    for name, expected in evidence['files_sha256'].items():
        assert hashes[name] == expected, name
    evidence_count = sum(name.startswith('architecture-evidence/') for name in hashes)
    assert manifest['architecture_evidence']['files'] == evidence_count
    captures = ['architecture-module-library-ui.png', 'architecture-zero-write-preview-ui.png', 'architecture-native-placement-ui.png']
    for name in captures:
        path = 'architecture-evidence/stages/'+name
        assert path in hashes and package.getinfo(path).file_size > 100
    assert qualification['collaborative_m6_m7'] is True and evidence['collaborative_m6_m7'] is True
    assert manifest['godot_version'] == '4.7.stable.official.5b4e0cb0f'
    engine_name = 'Godot_v4.7-stable_win64_console.exe'
    assert qualification['godot_executable_sha256'] == hashes[engine_name]
    assert hashes[engine_name] == 'd8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c'
    assert hashes['Godot_v4.7-stable_win64.exe'] == 'b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8'
    rapier_name = 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
    assert hashes[rapier_name] == 'b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7'
    report_rows = qualification['results']
    labels = [row['label'] for row in report_rows]
    assert len(labels) == len(set(labels)), 'Duplicate qualification process label'
    custody_path = 'architecture-evidence/collaborative/custody.json'
    custody_raw = package.read(custody_path)
    custody = json.loads(custody_raw)
    custody_sha = hashlib.sha256(custody_raw).hexdigest()
    assert qualification['collaborative_evidence']['path'] == 'architecture/collaborative/custody.json'
    assert qualification['collaborative_evidence']['sha256'] == custody_sha
    for contract in [qualification['collaborative_evidence'], evidence['collaborative_custody'], manifest['architecture_evidence']['collaborative_custody']]:
        assert contract['native_active_core_capacity'] == 1024 and contract['cropped_route_worlds'] is False
        assert contract['sha256'] == custody_sha
    assert custody['passed'] is True and custody['failures'] == []
    assert custody['source_revision'] == args.source and custody['native_binary_sha256'] == args.native_sha256
    assert custody['native_active_core_capacity'] == 1024 and custody['cropped_route_worlds'] is False
    assert custody['model_calls'] == 0 and custody['physical_owner_acceptance'] == 'pending'
    expected_counts = {'modules':40,'catalogue_native_observations':100,'detail_cases':24,'comparison_proposals':60,
                       'comparison_native_completed':23,'comparison_pre_native_refusals':37,'full_native_flagships':4,
                       'full_world_actor_trials':4,'fresh_actor_reopens':4,'catalogue_part_frames':40,'flagship_frames':12,
                       'collaborative_ui_frames':7,'hierarchy_frames':3,'delegated_local_workers':3}
    assert custody['counts'] == expected_counts
    for name, expected in custody['files_sha256'].items():
        assert hashes['architecture-evidence/collaborative/'+name] == expected, name
    tick_source = 'CyberSimulationWorker.take_latest_snapshot(0).tick_index'
    for report_name in ['architecture-gameplay.json','architecture-gameplay-reopen.json']:
        gameplay = json.loads(package.read('architecture-evidence/collaborative/gameplay/'+report_name))
        assert gameplay['native_tick_source'] == tick_source
        assert gameplay['source_revision'] == args.source and gameplay['native_active_core_capacity'] == 1024
        for attempt in gameplay['attempts']:
            assert attempt['native_tick_source'] == tick_source
            assert attempt['native_tick_bounds']['end'] - attempt['native_tick_bounds']['begin'] == attempt['native_ticks']
            cached = attempt['render_cached_native_tick_bounds']
            assert cached['end'] - cached['begin'] == attempt['render_cached_native_ticks']
            assert attempt['native_ticks'] > 0 and attempt['actor_ticks'] > 0
            if report_name == 'architecture-gameplay.json':
                assert attempt['native_ticks'] >= attempt['actor_ticks'] - 2
            assert all('render_cached_native_tick' in sample for sample in attempt['samples'])
    for required in ['collaborative-catalogue-native','collaborative-catalogue-render','collaborative-detail-native',
                     'collaborative-composition-native','collaborative-flagships-native','collaborative-flagships-render',
                     'collaborative-full-world-gameplay','collaborative-gameplay-fresh-reopen','collaborative-native-ui',
                     'collaborative-hierarchy-native','collaborative-hierarchy-independent-reduction',
                     'collaborative-hierarchy-fresh-reopen','collaborative-hierarchy-render','collaborative-evidence-custody']:
        assert required in labels, required
    for name in ['candidate-manifest.json', 'source-built-candidate-provenance.json', 'architecture-evidence/source-qualification.json', 'architecture-evidence/evidence-provenance.json', custody_path]:
        preserve(base/'owner-audit'/name, package.read(name))

    audit = {'schema': 'cybersand.owner-evaluator-custody.v1', 'status': 'passed', 'source_commit': args.source, 'source_tree': args.tree,
             'run_id': args.run_id, 'run_attempt': 1, 'artifact_id': args.artifact_id, 'outer_file': args.outer.name,
             'outer_bytes': args.outer.stat().st_size, 'outer_sha256': args.outer_sha256, 'inner_file': inner_name,
             'inner_bytes': inner_path.stat().st_size, 'inner_sha256': expected_inner,
             'zip_entries': len(package.infolist()), 'zip_regular_files': len(files),
             'zip_uncompressed_bytes': sum(entry.file_size for entry in package.infolist()),
             'manifest_files_verified': len(hashes), 'manifest_sha256': hashlib.sha256(manifest_bytes).hexdigest(),
             'unlisted_files': ['candidate-manifest.json'], 'path_safety': {'safe_relative_paths': True, 'no_duplicates': True, 'no_casefold_collisions': True, 'no_symlinks': True},
             'native_sha256': args.native_sha256, 'native_bytes': native['size'], 'native_inputs_verified': 105,
             'native_inputs_match_commits': reference_commits, 'godot_version': manifest['godot_version'],
             'source_qualification_sha256': qualification_digest, 'source_qualification_processes': len(qualification['results']), 'collaborative_custody_sha256': custody_sha, 'collaborative_counts': custody['counts'], 'collaborative_raw_file_hashes_verified': len(custody['files_sha256']),
             'qualified_source_file_hashes_verified': len(qualification['source_files_sha256']), 'committed_source_and_asset_files_verified': committed_files_verified, 'platform_converted_source_files': platform_converted_source_files, 'source_export_scope': 'Raw package hashes are exact; CRLF-only committed assets also independently match git -c core.autocrlf=true archive of the exact tree.', 'derived_generator_profiles_verified': derived_profiles_verified, 'architecture_evidence_files': evidence_count, 'ui_capture_files': captures,
             'scope': 'Read-only original artifact and complete package verification. Embedded source Windows qualification and every actual app/runtime file hash match the package. Fresh extracted application execution is reviewed separately. No physical owner acceptance.'}

output = base/'owner-evaluator-custody-a.json'
preserve(output, (json.dumps(audit, indent=2)+'\n').encode())
print(json.dumps({'status': 'passed', 'audit': str(output), 'audit_sha256': digest_file(output), 'inner_file': str(inner_path),
                  'inner_sha256': expected_inner, 'manifest_files_verified': len(hashes), 'qualified_source_files_verified': len(qualification['source_files_sha256']),
                  'native_inputs_verified': 105, 'source_qualification_processes': len(qualification['results'])}, indent=2))
