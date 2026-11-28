#!/usr/bin/env python3
"""Record static re-reading of original package evidence; invokes no Godot."""
import datetime
import hashlib
import json
import ntpath
from pathlib import Path
import re
import subprocess
import sys
import time

SOURCE = Path('/workspace/scratch/119285bae098/cybersand')
EVIDENCE = Path('/tmp/strata003-final-package-evidence')
OUTPUT = Path('/tmp/strata003-recovery-a')
APP = 'fd0830abcfadd9ae19162e5677943bb131223e59'
TREE = 'fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499'
SCRIPT = 'tools/ci/qualify_strata3_workbench.py'
WORKFLOW = '.github/workflows/strata-theatre-003.yml'

def require(value, text):
    if not value:
        raise RuntimeError(text)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(['git', '-C', str(SOURCE), *args], timeout=30)

def main():
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    require(git('rev-parse', 'HEAD').decode().strip() == APP and git('rev-parse', 'HEAD^{tree}').decode().strip() == TREE,
            'Reader checkout differs from frozen application')
    require(not git('status', '--porcelain'), 'Frozen application checkout is not clean')
    files = {}
    for name in (SCRIPT, WORKFLOW):
        data = (SOURCE / name).read_bytes()
        require(data == git('show', APP + ':' + name), 'Frozen reader/workflow bytes changed')
        files[name] = hashlib.sha256(data).hexdigest()
    command = [sys.executable, SCRIPT, '--verify', str(EVIDENCE / 'extracted'), '--suite', 'full']
    began = time.monotonic()
    process = subprocess.Popen(command, cwd=SOURCE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate(timeout=60)
    elapsed = time.monotonic() - began
    require(process.returncode == 0 and stdout.decode().strip() == 'STRATA3_VERIFIED ' + str(EVIDENCE / 'extracted') and not stderr,
            'Unchanged full campaign reader did not complete successfully')
    require(not git('status', '--porcelain'), 'Static reader changed frozen application checkout')
    recovery = json.loads((OUTPUT / 'evidence-recovery.json').read_text())
    require(recovery['archive_sha256'] == 'c01cbd055e762af0ca96e47a3e8c4f4cd4ecf47070d48d5eab361ead76938513'
            and recovery['files'] == 4245, 'Wrong recovered original evidence')
    names = ('launcher.json', 'launcher.stdout.log', 'launcher.stderr.log', 'extracted/campaign.json')
    original_hashes = {name: sha(EVIDENCE / name) for name in names}
    require(all(recovery['member_sha256'][name] == value for name, value in original_hashes.items()),
            'Original recovered receipt changed')
    launcher = json.loads((EVIDENCE / 'launcher.json').read_text(encoding='utf-8-sig'))
    output = (EVIDENCE / 'launcher.stdout.log').read_text(encoding='utf-8-sig')
    error = (EVIDENCE / 'launcher.stderr.log').read_text(encoding='utf-8-sig')
    require(set(launcher) == {'admitted', 'wrapper_pid', 'exit_code', 'pristine_directory', 'source_revision', 'command'}
            and type(launcher['wrapper_pid']) is int and launcher['wrapper_pid'] > 0
            and launcher['exit_code'] == 0 and launcher['source_revision'] == APP, 'Wrong actual launcher receipt')
    executable, arguments = launcher['command'].split(' ', 1)
    require(ntpath.normcase(executable) == r'c:\windows\system32\cmd.exe', 'Wrong actual CMD executable')
    directory = launcher['pristine_directory']
    expected = '/d /s /c ""' + ntpath.join(directory, 'Open Workbench.cmd') + '" --audio-driver Dummy --rendering-method gl_compatibility --rendering-driver opengl3 --quit-after 180"'
    require(ntpath.basename(directory) == 'strata owner package' and arguments == expected,
            'Actual shipped command differs from frozen workflow')
    require(not re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:', output + error), 'Original launcher contains engine errors')
    marker = 'STRATA_WORKBENCH_LAUNCH_ADMITTED '
    admissions = [json.loads(line[len(marker):]) for line in output.splitlines() if line.startswith(marker)]
    require(len(admissions) == 1 and admissions[0] == launcher['admitted'], 'Original admission and launcher receipt differ')
    admission = admissions[0]
    require(set(admission) == {'extent', 'source_revision', 'strata_enabled', 'workbench_script', 'worker_id', 'world_generation'}
            and admission['source_revision'] == APP and admission['extent'] == [2048, 2048]
            and admission['strata_enabled'] is False and admission['workbench_script'] == 'res://scripts/shared_workbench.gd'
            and type(admission['world_generation']) is int and admission['world_generation'] > 0
            and isinstance(admission['worker_id'], str) and re.fullmatch(r'-?[1-9][0-9]{0,18}', admission['worker_id']),
            'Native ordinary Workbench identity differs')
    headers = [line for line in output.splitlines() if line.startswith('Godot Engine v')]
    backend = [line for line in output.splitlines() if line.startswith('OpenGL API ')]
    require(headers == ['Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org'] * 2
            and len(backend) == 1 and 'Compatibility' in backend[0] and 'Microsoft Basic Render Driver' in backend[0],
            'Actual shipped runtime or backend identity differs')
    campaign = json.loads((EVIDENCE / 'extracted/campaign.json').read_text())
    require(campaign['source_identity']['source_commit'] == APP and campaign['source_identity']['source_tree'] == TREE
            and campaign['platform'] == 'win32' and campaign['suite'] == 'full' and len(campaign['cases']) == 31,
            'Wrong actual extracted campaign')
    admissions_rows = []
    for case in campaign['cases']:
        if case['phase'] not in ('install', 'reopen', 'progression', 'motion'):
            continue
        result = case['result']
        admissions_rows.append({'case': case['label'], 'phase': case['phase'], 'admission_elapsed_ms': result['admission_elapsed_ms'],
                                'admission_target_ms': result['admission_target_ms'], 'admission_target_met': result['admission_target_met']})
    record = {
        'schema': 'strata3-package-reader-completion-review-a-v1', 'reviewer': 'Specialist A',
        'started_at_utc': started, 'completed_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'application_source': APP, 'application_tree': TREE,
        'source_clean_before_and_after': True, 'frozen_input_sha256': files,
        'review_driver_sha256': sha(Path(__file__)),
        'reader': {'command': command, 'cwd': str(SOURCE), 'pid': process.pid, 'exit_code': process.returncode,
                   'wall_seconds': elapsed, 'completion_marker': stdout.decode().strip(), 'stderr_empty': not stderr,
                   'stdout_sha256': hashlib.sha256(stdout).hexdigest(), 'stderr_sha256': hashlib.sha256(stderr).hexdigest()},
        'artifact': {'id': 15080936111, 'run_id': 45721790366, 'bytes': recovery['archive_bytes'],
                     'sha256': recovery['archive_sha256'], 'verified_files': recovery['files'],
                     'uncompressed_bytes': recovery['uncompressed_bytes'],
                     'url': 'https://github.com/techrote/cybersand/actions/runs/45721790366/artifacts/15080936111'},
        'original_receipt_sha256': original_hashes,
        'campaign': {'cases': 31, 'suite': 'full', 'platform': 'win32', 'status': campaign['status'],
                     'completed': campaign['completed'], 'input_custody': campaign['input_custody'],
                     'case_labels': [case['label'] for case in campaign['cases']],
                     'admissions': admissions_rows},
        'actual_launcher': launcher, 'runtime_headers': headers, 'rendering_backend': backend[0],
        'engine_error_patterns_absent': True,
        'stderr_note': 'Recorded OpenGL 3.3 unavailable warning and automatic ANGLE fallback; no engine/script ERROR.',
        'scope': 'Static unchanged frozen full-campaign reader plus concrete original shipped-CMD receipt/log checks. No Godot invoked and no runtime campaign rerun.',
        'historical_boundary': 'This later completed read follows restoration of the workspace and recovery of the exact original artifact. Earlier outage-time read attempts remain unconfirmed or never started.',
        'limits': ['The shipped command followed full-suite resource preparation; the separate cold92ec annex owns first-command acceptance.',
                   'Launcher JSON has no command lifetime or scene-admission timestamp; none is inferred from it.',
                   'Package admissions are a separate hosted cohort and do not erase earlier source-campaign or Strata002 failures.',
                   'Static functional verification does not waive enabled-optics performance HOLD or physical owner gates.']
    }
    path = OUTPUT / 'package-reader-completion-a.json'
    path.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'receipt': str(path), 'sha256': sha(path), 'reader_exit': process.returncode,
                      'cases': 31, 'launcher_exit': launcher['exit_code'], 'no_godot_invoked': True}))

if __name__ == '__main__':
    main()
