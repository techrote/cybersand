"""Read-only final delivery audit. Raw originals remain in downloaded Actions archives."""
import hashlib
import json
import pathlib
import re
import stat
import subprocess
import zipfile

ROOT = pathlib.Path('/tmp/art-d503-windows-custody')
REPO = pathlib.Path('/tmp/art-collaborative-002-source-v2')
SOURCE = 'd503d824aac4128968f7dfba5dccd540c3c07b59'
TREE = '464c60288d5461d61578b000ae68ac029cffb5bd'
PREFIX = 'art-workbench-collaborative-002-windows/'
HASH = re.compile(r'^[0-9a-f]{64}$')
RUNTIMES = {
    'Godot_v4.7-stable_win64.exe': 'b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8',
    'Godot_v4.7-stable_win64_console.exe': 'd8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c',
    'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll': '668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e',
    'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll': 'b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7',
    'vcruntime140.dll': 'd5e4d9a3e835fa679450145d6a7d94e36573a509317111904d9b3712c30d9066',
}
REQUIRED = {
    'test_art_owned_transport', 'test_art_conversation_preparation',
    'test_art_conversation_apply_preparation', 'test_art_authoring_proposal',
    'test_art_creative_cohort', 'test_art_collaborative_native',
    'test_art_collaboration_authority', 'test_art_collaboration_session',
    'test_art_collaboration_workspace',
}
SCENARIOS = [
    'industrial_repair', 'structural_facade', 'scifi_interior', 'revised_arcology',
    'protected_courtyard', 'palette_foundry', 'stopped_workshop', 'staged_megaframe', 'xeno_vault',
]
EXAMPLE_SUFFIXES = [
    'before-native.png', 'after-native.png', 'before-workbench.png', 'after-workbench.png',
    'editable-setup.json', 'result.json', 'original-native-receipts.json', 'direct-original-native-receipts.json',
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(path):
    return subprocess.check_output(['git', 'show', f'{SOURCE}:{path}'], cwd=REPO)


def write(name, value):
    (ROOT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def retain(path, data):
    # No duplicate aggregate or raw publication. Metadata reports reference Actions originals.
    pass


assert subprocess.check_output(['git', 'rev-parse', f'{SOURCE}^{{tree}}'], cwd=REPO, text=True).strip() == TREE
outer = ROOT / 'evaluator-artifact.zip'
evidence_path = ROOT / 'evidence-artifact.zip'
artifact_identity = json.loads((ROOT / 'expected-artifacts.json').read_text())
assert outer.stat().st_size == artifact_identity['evaluator']['bytes']
assert sha(outer.read_bytes()) == artifact_identity['evaluator']['sha256']
assert evidence_path.stat().st_size == artifact_identity['evidence']['bytes']
assert sha(evidence_path.read_bytes()) == artifact_identity['evidence']['sha256']
with zipfile.ZipFile(outer) as delivery:
    assert delivery.testzip() is None
    inner = delivery.read('art-workbench-collaborative-002-windows.zip')
    assert delivery.read('art-workbench-collaborative-002-windows.zip.sha256').decode().split()[0] == sha(inner)
assert inner == (ROOT / 'portable-d503.zip').read_bytes()

with zipfile.ZipFile(ROOT / 'portable-d503.zip') as package, zipfile.ZipFile(evidence_path) as evidence:
    assert package.testzip() is None and evidence.testzip() is None
    names = package.namelist()
    assert len(names) == len(set(names))
    assert len(names) == len({name.casefold() for name in names})
    assert all(n.startswith(PREFIX) and '..' not in pathlib.PurePosixPath(n).parts for n in names)
    windows_reserved = {'con', 'prn', 'aux', 'nul'} | {f'{kind}{i}' for kind in ['com', 'lpt'] for i in range(1, 10)}
    for info in package.infolist():
        name = info.filename
        assert '\\' not in name and ':' not in name and not info.is_dir(), name
        assert all(part not in ('', '.', '..') and not part.endswith((' ', '.'))
                   and part.split('.')[0].casefold() not in windows_reserved for part in name.split('/')), name
        mode = (info.external_attr >> 16) & 0xffff
        assert not stat.S_ISLNK(mode) and stat.S_IFMT(mode) in (0, stat.S_IFREG), name
    manifest_raw = package.read(PREFIX + 'candidate-manifest.json')
    manifest = json.loads(manifest_raw)
    assert manifest['source_commit'] == SOURCE and manifest['source_tree'] == TREE
    assert manifest['status'] == 'Draft/HOLD'
    assert manifest['automatic_model_requests'] is False
    assert manifest['application_qualification']['mode'] == 'full_required'
    files = manifest['files_sha256']
    assert set(names) == {PREFIX + p for p in files} | {PREFIX + 'candidate-manifest.json'}
    for path, expected in files.items():
        assert HASH.fullmatch(expected), path
        assert sha(package.read(PREFIX + path)) == expected, path
    assert len(files) == 1200
    excluded = [p for p in files if p.lower().startswith(('profile/', 'profile-local/', 'diagnostics/'))
                or '/art-traffic/' in p.lower() or p.lower().endswith(('.jsonl', '.pem', '.key'))
                or pathlib.PurePosixPath(p).name.lower() in {'.env', 'id_rsa', 'id_ed25519', 'art-provider.cfg'}]
    assert excluded == [], excluded
    for path, expected in RUNTIMES.items():
        assert files[path] == expected and sha(package.read(PREFIX + path)) == expected
    source_comparison = json.loads((ROOT / 'source-payload-comparison.json').read_text())
    assert source_comparison['source'] == SOURCE and not source_comparison['mismatches']
    assert len(source_comparison['canonical_matches']) == 1092
    assert len(source_comparison['materialized_lfs_matches']) == 2
    for path in source_comparison['canonical_matches']:
        assert package.read(PREFIX + path) == git_blob(path), path
    runtime_sources = {}
    for provenance in ['godot/addons/cybersand_native/runtime-provenance.json',
                       'godot/addons/godot-rapier2d/runtime-provenance.windows.json']:
        raw = package.read(PREFIX + provenance)
        record = json.loads(raw)
        assert record['sha256'] == files[record['artifact']]
        checked = {}
        for path, expected in record['source_inputs'].items():
            actual = sha(git_blob(path))
            assert actual == expected, path
            checked[path] = actual
        runtime_sources[provenance] = {'provenance_sha256': sha(raw), 'artifact_sha256': record['sha256'],
                                      'build_commit': record['build_commit'], 'source_inputs': checked}
        retain('package/' + provenance, raw)
    assert len(runtime_sources['godot/addons/cybersand_native/runtime-provenance.json']['source_inputs']) == 105
    summaries = {}
    logs = []
    # Re-read the exact retained gate that failed in the first 3a attempt.
    # A successful successor does not overwrite or explain that earlier miss.
    retained_native_raw = evidence.read('art-native-displayed.stdout.log')
    retained_native_error = evidence.read('art-native-displayed.stderr.log')
    retained_text = '\n'.join(retained_native_raw.decode('utf-8').splitlines())
    progress_values = re.findall(r'^ART_FIRST_PROGRESS_MS ([0-9]+)$', retained_text, re.M)
    native_results = re.findall(r'^ART_STAGE1_RESULT (.+)$', retained_text, re.M)
    assert len(progress_values) == len(native_results) == 1
    progress_ms = int(progress_values[0])
    retained_result = json.loads(native_results[0])
    assert progress_ms < 2000
    assert type(retained_result['checks']) is int and retained_result['checks'] == 151
    assert type(retained_result['failures']) is int and retained_result['failures'] == 0
    assert 'ART_CHECK sparse polygon makes visible progress before raster completes true' in retained_text
    assert 'ART_CHECK sparse polygon publishes an early native receipt true' in retained_text
    assert 'ART_CHECK first sparse pixels reach the display image true' in retained_text
    assert not re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource',
                         retained_text + retained_native_error.decode('utf-8'))
    retained_native_review = {
        'source_commit': SOURCE, 'checks': retained_result['checks'], 'failures': 0,
        'first_progress_ms': progress_ms, 'predicate': 'art.active and first_progress_ms < 2000',
        'predicate_reported_pass': True, 'stdout_sha256': sha(retained_native_raw),
        'stderr_sha256': sha(retained_native_error),
        'earlier_3a_attempt': {'run_id': 45553413100, 'artifact_id': 14995049040,
                              'first_progress_ms': 2187, 'checks': 151, 'failures': 1},
        'scope': 'Separate exact-source strict repeat. No cause, correction or universal latency guarantee is inferred; the original 3a negative remains retained.',
    }
    for scope in ['headless', 'displayed']:
        path = f'art-collaborative-{scope}/summary.json'
        raw = evidence.read(path)
        assert package.read(PREFIX + f'qualification/collaborative-{scope}.json') == raw
        summary = json.loads(raw)
        assert summary['status'] == 'passed' and type(summary['model_calls']) is int and summary['model_calls'] == 0
        assert summary['source'] == {'commit': SOURCE, 'tree': TREE, 'tracked_source_clean': True}
        assert summary['graphical'] == (scope == 'displayed') and summary['platform'] == 'windows'
        assert summary['runtime']['godot_sha256'] == RUNTIMES['Godot_v4.7-stable_win64_console.exe']
        assert summary['runtime']['godot_version'] == manifest['godot_version']
        for path, expected in summary['runtime']['payloads'].items():
            assert RUNTIMES[path] == expected
        assert summary['runtime']['provenance_sha256'] == files['godot/addons/cybersand_native/runtime-provenance.json']
        assert len(summary['cases']) == 9 and {c['name'] for c in summary['cases']} == REQUIRED
        for case in summary['cases']:
            assert case['status'] == 'passed' and case['exit_code'] == 0 and case['timed_out'] is False
            assert case['error'] == ''
            log_path = f"art-collaborative-{scope}/{case['name']}/process.log"
            log = evidence.read(log_path)
            assert sha(log) == case['log_sha256']
            text = log.decode('utf-8')
            assert not re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource', text)
            lines = [line for line in text.splitlines() if line.startswith(case['marker'] + ' ')]
            assert len(lines) == 1, (scope, case['name'])
            parsed = json.loads(lines[0].split(' ', 1)[1])
            assert parsed == case['result']
            assert type(parsed['checks']) is int and parsed['checks'] > 0
            assert ((type(parsed['failures']) is int and parsed['failures'] == 0)
                    or (isinstance(parsed['failures'], list) and parsed['failures'] == []))
            for art, expected in case['artifacts_sha256'].items():
                assert HASH.fullmatch(expected)
                assert sha(evidence.read(f"art-collaborative-{scope}/{case['name']}/{art}")) == expected
            logs.append({'scope': scope, 'name': case['name'], 'checks': parsed['checks'],
                         'log_sha256': sha(log), 'artifacts_verified': len(case['artifacts_sha256'])})
            retain(log_path, log)
        summaries[scope] = summary
        retain(f'art-collaborative-{scope}/summary.json', raw)
    examples = manifest['creative_examples']
    assert type(examples['model_calls']) is int and examples['model_calls'] == 0 and examples['scenario_ids'] == SCENARIOS
    assert examples['setup_labels'] == {f'art02-{scenario}': f'{i:02}-{scenario}-editable-setup.json'
                                        for i, scenario in enumerate(SCENARIOS)}
    original = examples['original_files_sha256']
    expected_examples = {'examples/art-collaborative-evaluated/' + f'{i:02}-{scenario}-{suffix}'
                         for i, scenario in enumerate(SCENARIOS) for suffix in EXAMPLE_SUFFIXES}
    expected_examples.add('examples/art-collaborative-evaluated/creative-native-summary.json')
    assert len(original) == 73 and set(original) == expected_examples
    native_case = next(c for c in summaries['displayed']['cases'] if c['name'] == 'test_art_collaborative_native')
    for path, expected in original.items():
        name = pathlib.PurePosixPath(path).name
        assert HASH.fullmatch(expected) and files[path] == expected
        assert native_case['artifacts_sha256'][name] == expected
        assert package.read(PREFIX + path) == evidence.read('art-collaborative-displayed/test_art_collaborative_native/' + name)
    assert sum(len(package.read(PREFIX + path)) for path in original) == examples['original_bytes']
    installed = {name: json.loads(evidence.read('installed-evaluator/' + name))
                 for name in ['installed-result.json', 'installed-execution.json', 'installed-examples.json', 'runtime-modules.json', 'art-responsiveness.json']}
    result = installed['installed-result.json']
    assert result == {'status': 'passed', 'source_commit': SOURCE, 'actual_launcher': True, 'display': 'Windows', 'automatic_model_requests': False}
    execution = installed['installed-execution.json']
    assert execution['source_commit'] == SOURCE and execution['exit_code'] == 0 and not execution['timed_out']
    workbench_raw = evidence.read('installed-evaluator/workbench.log')
    workbench_text = workbench_raw.decode('utf-8')
    owner_records = [json.loads(line.split(' ', 1)[1]) for line in workbench_text.splitlines()
                     if line.startswith('ART_OWNER_EVALUATOR ')]
    assert len(owner_records) == 1
    owner_record = owner_records[0]
    assert owner_record['source'] == SOURCE and owner_record['display'] == 'Windows'
    assert owner_record['automatic_requests'] is False
    assert not re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource', workbench_text)
    modules = installed['runtime-modules.json']
    assert modules['status'] == 'passed' and modules['source_commit'] == SOURCE and modules['source_tree'] == TREE
    assert modules['error'] is None and modules['enumeration_error_count'] == 0
    assert modules['cleanup']['error'] is None and modules['cleanup']['environment_restored'] is True
    assert modules['cleanup']['terminated_owned_process'] is True
    assert type(modules['cleanup']['exit_code']) is int
    assert {module['relative_path'] for module in [modules['executable']] + modules['modules']} == set(RUNTIMES) - {'Godot_v4.7-stable_win64_console.exe'}
    for module in [modules['executable']] + modules['modules']:
        rel = module['relative_path']
        assert module['status'] == 'verified'
        assert module['packaged_sha256'] == module['expected_sha256'] == module['observed_sha256'] == RUNTIMES[rel]
        assert module['observed_path'].lower() == module['expected_path'].lower()
        assert module['observed_path'].lower().startswith(modules['package'].lower() + '\\')
    setup_receipt = installed['installed-examples.json']
    assert setup_receipt['actual_installer'] and setup_receipt['package_local_only']
    assert set(setup_receipt['setups_sha256']) == set(examples['setup_labels'])
    for label, name in examples['setup_labels'].items():
        assert setup_receipt['setups_sha256'][label] == files['examples/art-collaborative-evaluated/' + name]
    diagnostic = installed['art-responsiveness.json']
    assert diagnostic['source_commit'] == SOURCE and diagnostic['automatic_requests'] is False
    assert diagnostic['contains_provider_config'] is False and diagnostic['teardown_completed'] is True
    descriptor_raw = evidence.read('installed-evaluator/installed-import-descriptors.json')
    descriptors = json.loads(descriptor_raw)
    assert descriptors['source_commit'] == SOURCE
    descriptor_paths = {
        'godot/addons/godot-rapier2d/Radial2D.svg.import',
        'godot/addons/godot-rapier2d/icons/Fluid2D.svg.import',
        'godot/addons/godot-rapier2d/icons/StateManager2D.svg.import',
        'godot/addons/godot-rapier2d/logo_square_2d.png.import',
    }
    assert set(descriptors['before']) == set(descriptors['after']) == descriptor_paths
    descriptor_review = {}
    for path in sorted(descriptor_paths):
        before, after = descriptors['before'][path], descriptors['after'][path]
        assert before == after
        data = before['utf8'].encode('utf-8')
        assert type(before['bytes']) is int and len(data) == before['bytes']
        assert HASH.fullmatch(before['sha256']) and sha(data) == before['sha256']
        assert data == package.read(PREFIX + path) == git_blob(path)
        descriptor_review[path] = {'bytes': len(data), 'sha256': sha(data),
                                   'before_after_source_and_payload_identical': True}
    for name in evidence.namelist():
        if name.startswith('installed-evaluator/') and not name.endswith('/'):
            retain(name, evidence.read(name))
    for path in ['candidate-manifest.json', 'APPLICATION-QUALIFICATION.json', 'Open Workbench.cmd', 'Install evaluated starts.cmd']:
        retain('package/' + path, package.read(PREFIX + path))
    scope_raw = evidence.read('qualification-scope/application-qualification-reuse.json')
    package_scope_raw = package.read(PREFIX + 'APPLICATION-QUALIFICATION.json')
    # The Windows packager writes this generated JSON using native CRLF;
    # keep both original digests and permit only that exact byte conversion.
    assert package_scope_raw.replace(b'\r\n', b'\n') == scope_raw
    assert json.loads(package_scope_raw) == json.loads(scope_raw)
    scope = json.loads(scope_raw)
    assert scope['mode'] == 'full_required' and scope['reuse'] is False
    assert scope['candidate_source_commit'] == SOURCE and scope['candidate_source_tree'] == TREE
    retain('qualification-scope/application-qualification-reuse.json', scope_raw)
    payload_review = {
        'source_commit': SOURCE, 'source_tree': TREE, 'scope': 'Independent read-only original Windows artifact and receipt review; no local Windows execution; derived-only publication.',
        'original_actions_artifacts': artifact_identity, 'outer_evaluator_sha256': sha(outer.read_bytes()), 'outer_evidence_sha256': sha(evidence_path.read_bytes()),
        'inner_zip_sha256': sha(inner), 'inner_zip_bytes': len(inner), 'manifest_sha256': sha(manifest_raw),
        'immutable_files_verified': len(files), 'package_members': len(names), 'payload_bytes': sum(i.file_size for i in package.infolist()),
        'canonical_source_files_verified': 1092, 'materialized_lfs_pointers_verified': 2,
        'excluded_private_payloads_found': excluded, 'runtimes': RUNTIMES,
        'native_example_original_files_verified': len(original), 'native_example_original_bytes': examples['original_bytes'],
        'guide_review': json.loads((ROOT / 'independent-guide-review.json').read_text()),
        'setup_labels': examples['setup_labels'], 'source_matched_native_inputs': 105,
        'source_matched_rapier_inputs': len(runtime_sources['godot/addons/godot-rapier2d/runtime-provenance.windows.json']['source_inputs']),
        'application_scope_copy': {'original_sha256': sha(scope_raw), 'package_sha256': sha(package_scope_raw),
                                   'only_difference': 'LF to CRLF', 'parsed_values_identical': True},
        'crc_verified': True, 'passed': True,
        'windows_portable_member_names_and_no_symlinks_verified': True,
    }
    receipt_review = {'source_commit': SOURCE, 'source_tree': TREE, 'passed': True, 'cases': logs,
                      'retained_displayed_native_progress': retained_native_review,
                      'installed_launch': result, 'installed_execution': execution, 'installed_setup_sha256': setup_receipt['setups_sha256'],
                      'actual_launcher_log': {'sha256': sha(workbench_raw), 'bytes': len(workbench_raw),
                                              'marker_source': owner_record['source'], 'marker_display': owner_record['display'],
                                              'marker_automatic_requests': owner_record['automatic_requests'], 'sole_marker': True},
                      'installed_import_descriptors': {'record_sha256': sha(descriptor_raw), 'files': descriptor_review},
                      'module_verification_status': modules['status'], 'module_probe_cleanup': modules['cleanup'],
                      'host': summaries['displayed']['host'], 'physical_owner_acceptance': 'pending'}
    write('independent-payload-review.json', payload_review)
    write('independent-receipt-review.json', receipt_review)
    write('native-source-input-review.json', runtime_sources)
    print(json.dumps({'payload': payload_review, 'receipt_case_counts': [(c['scope'], c['name'], c['checks']) for c in logs]}, indent=2))
