"""Read-only independent byte/receipt review of the final bcc Windows artifacts."""
import hashlib
import json
import pathlib
import re
import subprocess
import zipfile

ROOT = pathlib.Path('/tmp/art-bcc-windows-custody')
REPO = pathlib.Path('/tmp/art-collaborative-002-source-v2')
SOURCE = 'bcc92927ce3894a16d5544923cfbf7b1d0339fda'
TREE = '517164084860a19f18b36cb94f77597eb3220578'
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


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(path):
    return subprocess.check_output(['git', 'show', f'{SOURCE}:{path}'], cwd=REPO)


def write(name, value):
    (ROOT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def retain(path, data):
    target = ROOT / 'independent-originals' / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


assert subprocess.check_output(['git', 'rev-parse', f'{SOURCE}^{{tree}}'], cwd=REPO, text=True).strip() == TREE
outer = ROOT / 'evaluator-artifact.zip'
evidence_path = ROOT / 'evidence-artifact.zip'
assert outer.stat().st_size == 94402359
assert sha(outer.read_bytes()) == '5bf19d36afab227bbe489f9404530f24694e5f1e03d464e1613b0529f23d3699'
assert evidence_path.stat().st_size == 12820321
assert sha(evidence_path.read_bytes()) == '45df2fecb95f21fe769f15202d15411156b658d7670e249f76e4b6877f9b3f47'
with zipfile.ZipFile(outer) as delivery:
    assert delivery.testzip() is None
    inner = delivery.read('art-workbench-collaborative-002-windows.zip')
    assert delivery.read('art-workbench-collaborative-002-windows.zip.sha256').decode().split()[0] == sha(inner)
assert inner == (ROOT / 'portable-bcc.zip').read_bytes()

with zipfile.ZipFile(ROOT / 'portable-bcc.zip') as package, zipfile.ZipFile(evidence_path) as evidence:
    assert package.testzip() is None and evidence.testzip() is None
    names = package.namelist()
    assert len(names) == len(set(names))
    assert all(n.startswith(PREFIX) and '..' not in pathlib.PurePosixPath(n).parts for n in names)
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
    for scope in ['headless', 'displayed']:
        path = f'art-collaborative-{scope}/summary.json'
        raw = evidence.read(path)
        assert package.read(PREFIX + f'qualification/collaborative-{scope}.json') == raw
        summary = json.loads(raw)
        assert summary['status'] == 'passed' and summary['model_calls'] == 0
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
            assert parsed['checks'] > 0 and parsed['failures'] in (0, [])
            for art, expected in case['artifacts_sha256'].items():
                assert HASH.fullmatch(expected)
                assert sha(evidence.read(f"art-collaborative-{scope}/{case['name']}/{art}")) == expected
            logs.append({'scope': scope, 'name': case['name'], 'checks': parsed['checks'],
                         'log_sha256': sha(log), 'artifacts_verified': len(case['artifacts_sha256'])})
            retain(log_path, log)
        summaries[scope] = summary
        retain(f'art-collaborative-{scope}/summary.json', raw)
    examples = manifest['creative_examples']
    assert examples['model_calls'] == 0 and len(examples['scenario_ids']) == 9
    original = examples['original_files_sha256']
    assert len(original) == 73
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
    modules = installed['runtime-modules.json']
    assert modules['status'] == 'passed' and modules['source_commit'] == SOURCE and modules['source_tree'] == TREE
    assert modules['error'] is None and modules['enumeration_error_count'] == 0
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
    retain('qualification-scope/application-qualification-reuse.json', scope_raw)
    payload_review = {
        'source_commit': SOURCE, 'source_tree': TREE, 'scope': 'Independent read-only original Windows artifact and receipt review; no local Windows execution.',
        'outer_evaluator_sha256': sha(outer.read_bytes()), 'outer_evidence_sha256': sha(evidence_path.read_bytes()),
        'inner_zip_sha256': sha(inner), 'inner_zip_bytes': len(inner), 'manifest_sha256': sha(manifest_raw),
        'immutable_files_verified': len(files), 'package_members': len(names), 'payload_bytes': sum(i.file_size for i in package.infolist()),
        'canonical_source_files_verified': 1092, 'materialized_lfs_pointers_verified': 2,
        'excluded_private_payloads_found': excluded, 'runtimes': RUNTIMES,
        'native_example_original_files_verified': len(original), 'native_example_original_bytes': examples['original_bytes'],
        'setup_labels': examples['setup_labels'], 'source_matched_native_inputs': 105,
        'source_matched_rapier_inputs': len(runtime_sources['godot/addons/godot-rapier2d/runtime-provenance.windows.json']['source_inputs']),
        'application_scope_copy': {'original_sha256': sha(scope_raw), 'package_sha256': sha(package_scope_raw),
                                   'only_difference': 'LF to CRLF', 'parsed_values_identical': True},
        'crc_verified': True, 'passed': True,
    }
    receipt_review = {'source_commit': SOURCE, 'source_tree': TREE, 'passed': True, 'cases': logs,
                      'installed_launch': result, 'installed_execution': execution, 'installed_setup_sha256': setup_receipt['setups_sha256'],
                      'module_verification_status': modules['status'], 'module_probe_cleanup': modules['cleanup'],
                      'host': summaries['displayed']['host'], 'physical_owner_acceptance': 'pending'}
    write('independent-payload-review.json', payload_review)
    write('independent-receipt-review.json', receipt_review)
    write('native-source-input-review.json', runtime_sources)
    print(json.dumps({'payload': payload_review, 'receipt_case_counts': [(c['scope'], c['name'], c['checks']) for c in logs]}, indent=2))
