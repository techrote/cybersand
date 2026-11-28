"""Bind a completed Windows outcomes ZIP to the unchanged delivered owner ZIP.

Read-only artifact review; no application or PowerShell process is launched.
"""
from pathlib import Path, PurePosixPath, PureWindowsPath
import argparse
import hashlib
import json
import zipfile


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def file_sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def positive(value):
    return type(value) is int and value > 0


def query_proof(value):
    assert value['passed'] is True and value['checks'] == 3 and value['failures'] == []
    assert value['powershell_version'].startswith('5.1.')
    paths = value['paths']
    assert isinstance(paths, list) and len(paths) == 2
    assert all(isinstance(p, str) and PureWindowsPath(p).is_absolute() for p in paths)
    assert paths[1] == paths[0] + '.nonexistent-query-control'
    row = value['observed_self']
    assert positive(row['ProcessId']) and row['ExecutablePath'].lower() == paths[0]
    assert isinstance(row['CreationDate'], str) and row['CreationDate']


def retained_log_binding(raw, observed_sha):
    """Shutdown may append to a live route log; prove its exact retained prefix."""
    assert len(raw) <= 4 * 1024 * 1024
    if sha(raw) == observed_sha:
        return {'kind': 'exact-final-file', 'observed_bytes': len(raw), 'final_sha256': sha(raw)}
    running = hashlib.sha256()
    for length, byte in enumerate(raw, 1):
        running.update(bytes((byte,)))
        if running.hexdigest() == observed_sha:
            assert b'SHARED_WORKBENCH_LAUNCH_READY' in raw[:length]
            return {'kind': 'exact-observed-prefix-with-later-appended-bytes',
                    'observed_bytes': length, 'final_bytes': len(raw), 'final_sha256': sha(raw)}
    raise AssertionError('The observed route-log bytes are not retained in the final artifact')


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--outcomes', required=True, type=Path)
parser.add_argument('--outcomes-sha256', required=True)
parser.add_argument('--package', required=True, type=Path)
parser.add_argument('--source', required=True)
parser.add_argument('--native', required=True)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
assert file_sha(args.outcomes) == args.outcomes_sha256
with zipfile.ZipFile(args.outcomes) as outcomes, zipfile.ZipFile(args.package) as package:
    source_raw = outcomes.read('application/qualification.json')
    extracted_raw = outcomes.read('extracted-evaluator/qualification.json')
    source = json.loads(source_raw)
    extracted = json.loads(extracted_raw)
    assert package.read('architecture-evidence/source-qualification.json') == source_raw
    manifest_raw = package.read('candidate-manifest.json')
    manifest = json.loads(manifest_raw)
    assert manifest['source_commit'] == args.source and manifest['native_sha256'] == args.native
    for report, count, packaged in [(source, 89, False), (extracted, 72, True)]:
        assert report['source_commit'] == args.source and report['status'] == 'passed'
        assert report['platform'] == 'win32' and report['graphical'] is True
        assert report['packaged'] is packaged and report['development_dirty_allowed'] is False
        assert report['actual_model_calls'] == 0 and report['physical_owner_acceptance'] == 'pending'
        assert len(report['results']) == count
        assert all(r['status'] == 'passed' and r['exit_code'] == 0 for r in report['results'])
        assert len({r['label'] for r in report['results']}) == count
        assert report['source_files_sha256']['addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'] == args.native
    assert source['source_files_sha256'] == extracted['source_files_sha256']
    assert source['godot_executable_sha256'] == extracted['godot_executable_sha256'] == manifest['files_sha256']['Godot_v4.7-stable_win64_console.exe']
    assert extracted['results'][0]['label'] == 'collaborative-pristine-delivered-cmd'

    reference = extracted['delivered_launcher']
    assert reference['path'] == 'architecture/collaborative/launcher/launcher.json'
    launcher_raw = outcomes.read('extracted-evaluator/' + reference['path'])
    assert sha(launcher_raw) == reference['sha256']
    launcher = json.loads(launcher_raw)
    assert launcher['source_revision'] == args.source and launcher['passed'] is True
    assert launcher['failures'] == [] and not launcher.get('cleanup_failures')
    assert launcher['checks'] == 10 and launcher['physical_owner_acceptance'] == 'pending'
    assert launcher['manifest_sha256'] == sha(manifest_raw)
    assert launcher['pristine_payload_verified'] is True and launcher['native_binary_sha256'] == args.native
    for key, name in [('launcher_sha256', 'Open Workbench.cmd'), ('gui_sha256', 'Godot_v4.7-stable_win64.exe'),
                      ('console_sha256', 'Godot_v4.7-stable_win64_console.exe')]:
        assert launcher[key] == manifest['files_sha256'][name]
    query_proof(launcher['query_self_test'])
    assert launcher['preexisting_processes'] == []
    assert positive(launcher['launcher_pid']) and launcher['launcher_exit_code'] == 0
    command = launcher['launcher_command']
    assert len(command) == 4 and command[1:3] == ['/d', '/c']
    package_root = PureWindowsPath(command[3]).parent
    assert PureWindowsPath(command[3]).name == 'Open Workbench.cmd'
    row = launcher['observed_process']
    assert row['ParentProcessId'] == launcher['launcher_pid'] and positive(row['ProcessId'])
    assert PureWindowsPath(row['ExecutablePath']) == package_root / 'Godot_v4.7-stable_win64.exe'
    assert type(row['MainWindowHandle']) is int and row['MainWindowHandle'] != 0
    assert isinstance(row['CreationDate'], str) and row['CreationDate']
    assert '--workbench' in row['CommandLine']
    assert launcher['accepted_route_marker'] == 'SHARED_WORKBENCH_LAUNCH_READY'
    samples = launcher['monitor_samples']
    assert 1 <= len(samples) <= 160
    assert any(s['cmd_exit_code'] == 0 and row in s['visible_owned_gui']
               and row in s['owned_processes']
               and any(log['ready'] is True and log['path'] == launcher['route_log']
                       and log['sha256'] == launcher['route_log_sha256']
                       for log in s['route_logs'])
               and 5 <= s['elapsed_seconds'] < 150 for s in samples)
    assert all(len(s['matching_processes']) <= 16 and len(s['route_logs']) <= 4 for s in samples)
    route = PurePosixPath(launcher['route_log'])
    assert not route.is_absolute() and '..' not in route.parts
    route_raw = outcomes.read('extracted-evaluator/architecture/collaborative/launcher/' + str(route))
    assert b'SHARED_WORKBENCH_LAUNCH_READY' in route_raw
    assert not any(t in route_raw for t in [b'SCRIPT ERROR:', b'Parse Error:', b'Failed to load script'])
    route_binding = retained_log_binding(route_raw, launcher['route_log_sha256'])
    assert launcher['cleanup'] == 'Only exact observed child image/PID/creation identities closed; none remain'
    early_raw = outcomes.read('windows-launcher-query-self-test.log')
    early_text = early_raw.decode('utf-8-sig').strip()
    prefix = 'WINDOWS_PROCESS_QUERY_SELF_TEST '
    assert early_text.startswith(prefix)
    early = json.loads(early_text[len(prefix):])
    query_proof(early)

    result = {'schema': 'cybersand.source-extracted-owner-pairing-review.v1', 'status': 'passed',
              'source_revision': args.source, 'native_binary_sha256': args.native,
              'outcomes_file': args.outcomes.name, 'outcomes_sha256': args.outcomes_sha256,
              'owner_package_file': args.package.name, 'owner_package_sha256': file_sha(args.package),
              'source_qualification_sha256': sha(source_raw), 'source_process_groups': 89,
              'extracted_qualification_sha256': sha(extracted_raw), 'extracted_process_groups': 72,
              'identical_executed_source_runtime_files': len(source['source_files_sha256']),
              'launcher_report_sha256': sha(launcher_raw), 'launcher_checks': launcher['checks'],
              'early_query_log_sha256': sha(early_raw), 'early_powershell_version': early['powershell_version'],
              'observed_process': row, 'launcher_pid': launcher['launcher_pid'],
              'route_log_binding': route_binding, 'monitor_samples': len(samples),
              'scope': 'Read-only original artifact pairing. The exact owner ZIP embeds the completed source report; its pristine extraction separately passed all72groups and the unchanged CMD produced its exact owned visible Workbench child. Original manifest/runtime hashes are retained. Physical owner acceptance remains pending.'}
args.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'status': 'passed', 'report': str(args.output), 'sha256': file_sha(args.output)}, indent=2))
