"""Read-only independent audit of retained R3 Windows source/package evidence."""
from pathlib import Path
import sys, json, hashlib, zipfile, stat, struct, subprocess, datetime
sys.dont_write_bytecode = True
ROOT = Path('/workspace/scratch/038267c40e11/cybersand-swarm45-mainline')
BASE = Path('/workspace/scratch/038267c40e11/swarm45-hosted-r3')
OUT = Path('/workspace/scratch/038267c40e11/swarm45-publication-review-evidence')
sys.path.insert(0, str(ROOT / 'tools/swarm45'))
import runtime_custody as custody
import native_checks, accepted_main_smokes as smokes
from shared import legacy, package_identity, verify_project, ui_report_errors
from run_workbench_qualification import ERRORS
sha = lambda b: hashlib.sha256(b).hexdigest()
js = lambda p: json.loads(p.read_bytes())
RUNTIME = js(BASE / 'windows-runtime/swarm45-runtime-provenance.json')
SOURCE = '96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f'
assert RUNTIME['source_commit'] == SOURCE
API = js(OUT / 'r3-complete-run-artifacts-api.json')
archives = {}

def archive(name, destination, expected, artifact_id=None):
    path = BASE / name
    assert sha(path.read_bytes()) == expected
    if artifact_id:
        a = next(x for x in API['artifacts'] if x['id'] == artifact_id)
        assert a['digest'] == 'sha256:' + expected and a['size_in_bytes'] == path.stat().st_size
        assert a['workflow_run']['id'] == 44953582341 and a['workflow_run']['head_sha'] == SOURCE
    files = {}
    with zipfile.ZipFile(path) as zipped:
        for info in zipped.infolist():
            pure = Path(info.filename)
            assert not pure.is_absolute() and '..' not in pure.parts and '\\' not in info.filename
            assert not stat.S_ISLNK(info.external_attr >> 16)
            if info.is_dir(): continue
            assert info.filename not in files
            raw = zipped.read(info)
            assert raw == (destination / info.filename).read_bytes()
            files[info.filename] = sha(raw)
    assert set(files) == {p.relative_to(destination).as_posix() for p in destination.rglob('*') if p.is_file()}
    archives[name] = {'sha256': expected, 'bytes': path.stat().st_size, 'files': len(files), 'artifact_id': artifact_id}
    return files

archive('windows-package.zip', BASE / 'windows-package', 'fe8b0f72292508530d359bc0826c623ec4a70a78399ba6212a66562a210d5894', 14727751402)
archive('windows-source.zip', BASE / 'windows-source', 'd70cbee6a1d1aa7a018702b2f87dfd27a8049587cfb08c13d9452ff56c8beb8f', 14727344824)
archive('owner-artifact.zip', BASE / 'owner-artifact', '18e70a2708d71b1757153400b01390c6ace4147057b3957fec8ccd9cb1d426ad', 14727701534)
OWNER = BASE / 'owner-package'
inner = 'owner-artifact/CyberSand-SWARM45-Draft-HOLD-Windows-96b8d3fb9d5a.zip'
files = archive(inner, OWNER, 'ce50316be11caafe32879395b681ef7f131541732061ded5db36dc3af6236c6d')
manifest = js(OWNER / 'candidate-manifest.json')
manifest_sha = sha((OWNER / 'candidate-manifest.json').read_bytes())
assert manifest_sha == '73ae92f19034bf8a9311430200c269df1b18e6c2a2ee18c8609ef62379daaf3b'
assert files == dict(manifest['files_sha256'], **{'candidate-manifest.json': manifest_sha})
assert len(manifest['files_sha256']) == 1087
assert package_identity(OWNER, RUNTIME) == manifest
verify_project(OWNER / 'godot', RUNTIME)
assert manifest['draft_hold'] is True and manifest['reciprocal_programme_acceptance'] is False and manifest['owner_visual_acceptance'] == 'pending'
assert manifest['godot_version'] == '4.7.stable.official.5b4e0cb0f'
for name in ['gentek_reciprocal.exe', 'cybersand_native.windows.x86_64.dll']:
    dest = OWNER / ('godot/tools/' if name.endswith('.exe') else 'godot/addons/cybersand_native/bin/') / name
    assert dest.read_bytes() == (BASE / 'windows-runtime' / name).read_bytes()
assert (OWNER / custody.NAME).read_bytes() == (BASE / 'windows-runtime' / custody.NAME).read_bytes()
assert js(OWNER / 'godot/tools/swarm004-runtime.windows.json') == custody.cli_binding(RUNTIME) == js(OWNER / 'godot/tools/swarm004-runtime.json')
assert not (OWNER / 'godot/tools/gentek_reciprocal').exists() and not (OWNER / 'godot/tools/swarm004-runtime.linux.json').exists()
imports = {}
for p in sorted((OWNER / 'godot/addons/godot-rapier2d').rglob('*.import')):
    relative = p.relative_to(OWNER).as_posix()
    raw = subprocess.check_output(['git', '-C', str(ROOT), 'cat-file', 'blob', SOURCE + ':' + relative], timeout=30)
    assert raw == p.read_bytes() and b'\r\n' not in raw
    imports[relative] = sha(raw)
assert len(imports) == 4
launcher = (OWNER / 'Open Workbench.cmd').read_text()
for key in ['CYBERSAND_SWARM004_CLI', 'CYBERSAND_SWARM004_SOURCE', 'CYBERSAND_SWARM004_SHA256']:
    assert 'set "' + key + '="' in launcher
assert SOURCE in launcher and '-- --workbench' in launcher
test_sha = sha(subprocess.check_output(['git', '-C', str(ROOT), 'cat-file', 'blob', SOURCE + ':godot/tests/swarm45_reciprocal_ui.gd'], timeout=30))
assert test_sha == sha((OWNER / 'godot/tests/swarm45_reciprocal_ui.gd').read_bytes())

def audit_layout(layout):
    packaged = layout == 'windows-package'
    top = BASE / layout
    qdir = top / layout
    sdir = top / ('windows-package-smokes' if packaged else 'windows-smokes')
    q, s = js(qdir / 'qualification.json'), js(sdir / 'accepted-main-smokes.json')
    for value, directory, final in [(q, qdir, 'qualification.json'), (s, sdir, 'accepted-main-smokes.json')]:
        assert value['passed'] is True and value['package'] is packaged and value['platform'] == 'windows'
        assert value['source_commit'] == SOURCE and value['source_tree'] == RUNTIME['source_tree'] and value['build_context'] == RUNTIME['build_context']
        assert value['runtime_manifest_sha256'] == sha((BASE / 'windows-runtime' / custody.NAME).read_bytes())
        custody.verify_inventory(directory, value['files_sha256'])
        assert set(value['files_sha256']) == {p.relative_to(directory).as_posix() for p in directory.rglob('*') if p.is_file()} - {final}
    assert len(q['results']) == 14 and q['graphical_required'] and q['lifecycle_passed']
    assert q['owner_visual_acceptance'] == 'pending' and q['reciprocal_programme_acceptance'] is False
    assert q['godot_sha256'] == s['godot_sha256'] == sha((OWNER / 'Godot_v4.7-stable_win64_console.exe').read_bytes())
    if packaged: assert q['package_zip_sha256'] == archives[inner]['sha256']
    records, examples = [], {}
    for index, row in enumerate(q['results']):
        case, example = row['case'], row.get('example')
        directory = qdir / ('headless' if index < 6 else (example or 'lifecycle'))
        assert row['passed'] is True and row['returncode'] == 0 and row['timed_out'] is False and not row.get('validation_errors')
        assert sha((directory / (case + '.log')).read_bytes()) == row['log_sha256']
        if packaged:
            assert row['command'][0].endswith('swarm45-pristine-package\\Godot_v4.7-stable_win64_console.exe')
            assert row['command'][row['command'].index('--path') + 1].endswith('swarm45-pristine-package\\godot')
        if index >= 6:
            assert '--headless' not in row['command'] and 'opengl3_angle' in row['command']
            report = js(directory / (case + '.json'))
            assert not ui_report_errors(report, case, example or 'transaction', SOURCE, manifest['reciprocal_cli_sha256'], test_sha, 'windows')
            if 'report_sha256' in row: assert sha((directory / (case + '.json')).read_bytes()) == row['report_sha256']
            records.append({'example': example or 'lifecycle', 'mode': case, 'checks': report['checks'], 'process_id': report['process_id'], 'native_status': report.get('native_status'), 'native_can_apply': report.get('native_can_apply'), 'transport_refusals': report['transport_refusals']})
    headless_checks = {}
    for name, marker, mechanical in [('runtime-selector', 'SWARM45_RUNTIME ', False), ('protocol', 'SWARM004_PROTOCOL ', False), ('controller-mechanical', 'SWARM004_CONTROLLER ', True), ('controls-native', 'SWARM004_CONTROLS ', False)]:
        log = qdir / 'headless' / (name + '.log')
        assert not legacy.marker_errors(log, marker, mechanical)
        headless_checks[name] = json.loads(next(x.removeprefix(marker) for x in log.read_text().splitlines() if x.startswith(marker)))['checks']
    adapter = js(qdir / 'headless/native-adapter.json')
    assert not legacy.assertion_errors(adapter) and adapter['passed'] is True
    headless_checks['native-adapter'] = adapter['checks']
    for example, definition in legacy.EXAMPLES.items():
        directory = qdir / example
        if definition.get('negative'):
            report = js(directory / 'blocked.json')
            record = legacy.blocked_evidence(directory, report)
            assert report['native_status'] == 'blocked' and report['native_can_apply'] is False and report['reciprocal_witness']['unresolved'] == 1
            examples[example] = {'blocked': True, 'joints': report['joint_count'], 'unresolved': 1, 'preview_baseline_equal': True}
        else:
            reports = {mode: js(directory / (mode + '.json')) for mode in ['create', 'reopen']}
            record = legacy.example_evidence(directory, reports)
            paths = list(directory.rglob('*.swarm004-evidence.json')); assert len(paths) == 1
            path = paths[0]; native = js(path)
            sidecar = js(path.with_name(path.name.replace('.swarm004-evidence.json', '.swarm004.json')))
            map_path = path.with_name(path.name.removesuffix('.swarm004-evidence.json'))
            assert sidecar['evidence_sha256'] == sha(path.read_bytes()) == sidecar['proposal_sha256'] == reports['create']['proposal_sha256']
            assert sidecar['map_sha256'] == sha(map_path.read_bytes())
            assert sidecar['native_receipt'] == reports['create']['native_receipt'] == reports['reopen']['native_receipt']
            assert sidecar['cli_sha256'] == manifest['reciprocal_cli_sha256'] and sidecar['native_source'] == native['source'] == SOURCE
            plane = struct.unpack('<262144H', (directory / 'expected-native.le16').read_bytes())
            width, height = map(int, reports['create']['native_recipe']['size']); ox, oy = map(int, reports['create']['native_recipe']['origin'])
            assert len(native['cells']) == width * height
            count = sum(bool(x) for x in native['cells'])
            assert count == sidecar['cell_count'] == sidecar['native_receipt']['changed_cells']
            assert all(plane[(oy + i // width) * 512 + ox + i % width] == m for i, m in enumerate(native['cells']) if m)
            assert native['schema'] == 5 and native['status'] == 'complete' and native['can_apply'] is True and native['metrics']['still_required'] == 0
            assert all(x['state'] == 'FOREIGN_JOINED' and x['foreign_joined'] is True for x in native['obligations'])
            assert len(native['joints']) == len(native['obligations']) == (8 if example == 'reciprocal' else 0)
            examples[example] = {'material_cells': count, 'foreign_joints': len(native['joints']), 'obligations': len(native['obligations']), 'local_terminations': native['metrics']['local_terminations'], 'native_cells_equal_applied_plane': True, 'saved_map_and_receipt_hashes_match': True, 'create_pid': reports['create']['process_id'], 'reopen_pid': reports['reopen']['process_id'], 'whole_plane_sha256': record['native_plane_sha256']}
        assert record['passed'] and not record['validation_errors']
        assert q['examples'][example]['native_plane_sha256'] == record['native_plane_sha256'] and q['examples'][example]['screenshots_sha256'] == record['screenshots_sha256']
    assert examples['reciprocal']['material_cells'] == 4001 and examples['swarm005_irregular']['material_cells'] == 6026
    assert s['required_cases'] == list(smokes.REQUIRED) and [x['label'] for x in s['results']] == list(smokes.REQUIRED) and len(s['results']) == 17
    assert s['results'] == js(sdir / 'results.json')
    smoke_rows = []
    for row in s['results']:
        assert row['status'] == 'passed' and row['exit_code'] == 0
        text = (sdir / (row['label'] + '.log')).read_text(errors='replace')
        assert not ERRORS.search(text) and not any(x.startswith('SKIP ') for x in text.splitlines())
        completion = row.get('completion', {})
        if completion: assert completion['failures'] in (0, []) and int(completion.get('checks', completion.get('assertions', 0))) > 0
        smoke_rows.append({'case': row['label'], 'checks': completion.get('checks', completion.get('assertions')), 'passed': True})
    wave = smokes.wave_result((sdir / 'workbench-wave.log').read_text(), 'windows')
    for label in ['actors-author', 'actors-reopen']:
        row = next(x for x in s['results'] if x['label'] == label)
        assert row['completion']['headless'] is False and row['completion']['preservation_notes'] == []
    flattened = js(sdir / 'flatten/qualification.json')
    assert flattened['status'] == 'passed' and flattened['graphical'] is True and flattened['cases'] == [[512, 1]]
    faults_path = sdir / 'flatten/storage-faults.json'; faults = js(faults_path)
    assert flattened['storage_faults']['report_sha256'] == sha(faults_path.read_bytes())
    assert faults['status'] == 'passed' and faults['completed'] is True and faults['platform'] == 'windows'
    for case in faults['cases']:
        assert case['exit_code'] == 0 and case['explicit_refusal'] and case['retry_ok'] and case['prior_sha256'] == case['after_sha256'] and case['partial_temporary_bytes'] == []
    pngs = {}
    for p in top.rglob('*.png'):
        if '/profile/' in str(p) or '/userdata/' in str(p): continue
        assert legacy.original_png(p), str(p)
        pngs[p.relative_to(top).as_posix()] = {'sha256': sha(p.read_bytes()), 'size': list(struct.unpack('>II', p.read_bytes()[16:24]))}
    return {'graphical_processes': 14, 'graphical_inventory_files': len(q['files_sha256']), 'headless_checks': headless_checks, 'ui': records, 'examples': examples, 'smoke_cases': 17, 'smoke_inventory_files': len(s['files_sha256']), 'smoke_results': smoke_rows, 'wave_assertions': wave['assertions'], 'wave_native_ticks': wave['native_ticks'], 'flatten_graphical_and_windows_storage_faults_pass': True, 'pngs': pngs}

layouts = {name: audit_layout(name) for name in ['windows-package', 'windows-source']}
ndir = BASE / 'windows-source/windows-native'; native = js(ndir / 'native-qualification.json')
assert native['platform'] == 'windows' and native['source_commit'] == SOURCE and native['build_context'] == RUNTIME['build_context'] and native['passed'] is True
custody.verify_inventory(ndir, native['files_sha256'])
assert len(native['results']) == 6
native_markers = {}
for row in native['results']:
    path = ndir / (row['case'] + '.log'); text = path.read_text(errors='replace')
    assert row['passed'] is True and row['returncode'] == 0 and not row['timed_out'] and sha(path.read_bytes()) == row['log_sha256']
    if row['case'] == 'v3-request':
        assert 'PASS SWARM005_V3_NATIVE_SHARED: eight paired native cases and four denied malformed requests' in text
    else:
        logical = row['case'].removeprefix('strict-')
        assert native_checks.marker_valid(logical, text)
        assert row['binary_sha256'] == RUNTIME['files'][logical + '.exe']['sha256']
        native_markers[logical] = [line for line in text.splitlines() if native_checks.re.fullmatch(native_checks.MARKERS[logical], line)]
v3 = js(ndir / 'v3/summary.json'); assert len(v3) == 8
for row in v3:
    complete = row['profile'] == 'irregular_megastructure' and row['compact'] == 1
    assert row['can_apply'] is complete and row['status'] == ('complete' if complete else 'blocked') and row['still_required'] == (0 if complete else 1) and row['joints'] == 0
    assert row['native_material_cells'] == (6035 if row['profile'] == 'viaduct_like' else (6026 if complete else 6034))
for name in ['bad_bool', 'swarm005_wrong_version', 'swarm004_wrong_version', 'trailing']:
    assert (ndir / 'v3' / (name + '.txt')).is_file() and not (ndir / 'v3' / (name + '.json')).exists()
guide = ROOT / 'evidence/swarm45-local/OWNER-EVALUATION.md'; draft = ROOT / 'build/swarm45-owner-evaluation-draft.md'
assert sha(guide.read_bytes()) == '74688f455b2a60075ebcde3e21a0147b7e1ab5d936e7d048476ebceff4b3745e'
assert guide.read_text() == draft.read_text().replace('PENDING_ACTUAL_ZIP_SHA256', archives[inner]['sha256']).replace('PENDING_ACTUAL_MANIFEST_SHA256', manifest_sha)
assert 'PENDING_' not in guide.read_text()
result = {'review': 'Independent R3 Windows source, actual evaluator and final guide evidence', 'reviewed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'source_commit': SOURCE, 'source_tree': RUNTIME['source_tree'], 'native_definition_sha256': RUNTIME['native_definition_sha256'], 'build_context': RUNTIME['build_context'], 'archives': archives, 'package_manifest_sha256': manifest_sha, 'package_manifest_payload_count': 1087, 'complete_zip_inventories_match': True, 'all_packaged_godot_source_inputs_match': True, 'canonical_rapier_import_sidecars': imports, 'runtime_and_os_bindings_exact': True, 'layouts': layouts, 'windows_native_markers': native_markers, 'windows_v3_cases': v3, 'malformed_requests_refused': 4, 'current_owner_guide_sha256': sha(guide.read_bytes()), 'guide_only_replaces_two_reviewed_placeholders': True, 'scope_verdict': 'GO for source-bound Windows native/source and actual extracted evaluator qualification and owner-guide readiness', 'overall_admission': 'HOLD pending actual publication review, final CI and physical owner acceptance', 'owner_visual_acceptance': 'pending', 'reciprocal_programme_acceptance': False}
path = OUT / 'r3-windows-source-package-checkpoint.json'; path.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps({'scope_verdict': result['scope_verdict'], 'package_files': 1087, 'source_graphical': layouts['windows-source']['graphical_processes'], 'package_graphical': layouts['windows-package']['graphical_processes'], 'source_smokes': 17, 'package_smokes': 17, 'source_pngs': len(layouts['windows-source']['pngs']), 'package_pngs': len(layouts['windows-package']['pngs']), 'checkpoint_sha256': sha(path.read_bytes())}))
