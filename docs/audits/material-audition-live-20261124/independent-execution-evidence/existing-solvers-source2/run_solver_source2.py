#!/usr/bin/env python3
"""Independent existing Godot regressions on an immutable hosted Linux candidate."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

BASE = Path('/workspace/scratch/1f637294a480')
SOURCE = BASE / 'mat-solver-source2'
CANDIDATE = BASE / 'evidence/hosted-source2-linux/build/audition-linux'
EVIDENCE = BASE / 'qualification/existing-solver-regressions-source2'
GODOT = Path('/workspace/scratch/051e78157ffb/runtime/godot-4.7/Godot_v4.7-stable_linux.x86_64')
sys.path.insert(0, str(SOURCE / 'tools/ci'))
import run_material_audition_qualification as q

CASES = (
    ('test_workbench_material_baseline', None),
    ('test_liquid_solver_policy', 'LIQUID_SOLVER_POLICY:'),
    ('test_liquid_policy_worker', 'LIQUID_POLICY_WORKER:'),
    ('test_lcb_inertial_adapter', 'LCB_INERTIAL_ADAPTER:'),
    ('test_wave_flow', 'WAVE_FLOW:'),
    ('test_workbench_physics_play', None),
)

manifest = q.verify(SOURCE, CANDIDATE, 'linux')
assert manifest['source_commit'] == '3e91942d7d12b87ddae09ec0f0f087f1ba6748e9'
assert manifest['toolchain_drift'] is False
assert not EVIDENCE.exists()
EVIDENCE.mkdir()
for relative, original in (
    (q.RUNTIMES['linux'], CANDIDATE / Path(q.RUNTIMES['linux']).name),
    ('godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so',
     BASE / 'cybersand/godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so'),
):
    target = SOURCE / relative
    temporary = target.with_name(target.name + '.solver-qualification-tmp')
    shutil.copyfile(original, temporary)
    os.replace(temporary, target)
assert q.sha(SOURCE / q.RUNTIMES['linux']) == manifest['native_sha256']
rapier = 'godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so'
pointer = q.git(SOURCE, 'show', 'HEAD:' + rapier).decode()
assert q.sha(SOURCE / rapier) == next(line[11:] for line in pointer.splitlines() if line.startswith('oid sha256:'))
assert subprocess.check_output([str(GODOT), '--version'], text=True).strip() == q.VERSION
report = {
    'schema': 'cybersand.material-audition.existing-solver-regression',
    'schema_version': 1, 'source_commit': manifest['source_commit'],
    'source_tree': manifest['source_tree'], 'native_sha256': manifest['native_sha256'],
    'candidate_manifest_sha256': q.sha(CANDIDATE / q.MANIFEST),
    'native_build_run_id': manifest['run_id'], 'toolchain_drift': False,
    'godot_version': q.VERSION, 'godot_sha256': q.sha(GODOT),
    'rapier_sha256': q.sha(SOURCE / rapier), 'host': platform.platform(),
    'orchestrator_sha256': q.sha(Path(__file__)), 'scope': 'Existing retained tests, exact source2 detached worktree; no source edits or new compilation.',
    'status': 'running', 'cases': [],
}
environment = dict(os.environ)
environment.update(XDG_DATA_HOME=str(EVIDENCE / 'userdata'), APPDATA=str(EVIDENCE / 'userdata'),
                   CYBERSAND_WORKBENCH_PHYSICS_REPORT=str(EVIDENCE / 'workbench-physics-readback.json'),
                   CYBERSAND_SOURCE_REVISION=manifest['source_commit'])
prefix = [str(GODOT), '--audio-driver', 'Dummy', '--headless', '--path', str(SOURCE / 'godot')]
try:
    report['import'] = q.run_process(prefix + ['--editor', '--quit'], EVIDENCE / 'import.log', environment, 900)
    for name, marker in CASES:
        row = {'name': name, 'test_sha256': q.sha(SOURCE / ('godot/tests/' + name + '.gd'))}
        try:
            process = q.run_process(prefix + ['--script', 'res://tests/' + name + '.gd'],
                                    EVIDENCE / (name + '.log'), environment, 900, marker)
            raw = (EVIDENCE / (name + '.log')).read_text(encoding='utf-8')
            if marker:
                complete = process['completion']
                line = next(line for line in raw.splitlines() if line.startswith(marker + ' '))
                sections = json.loads(line.split('completed=', 1)[1])
                q.require(bool(sections) and all(value is True for value in sections.values()), 'Required native sections incomplete')
                complete = complete | {'completed': sections}
            elif name == 'test_workbench_material_baseline':
                matched = re.findall(r'^WORKBENCH_MATERIAL_BASELINE checks=(\d+) failures=(\d+)$', raw, re.M)
                q.require(len(matched) == 1 and int(matched[0][0]) > 0 and matched[0][1] == '0', 'Material baseline completion failed')
                complete = {'checks': int(matched[0][0]), 'failures': 0}
            else:
                lines = [line[len('WORKBENCH_PHYSICS '):] for line in raw.splitlines() if line.startswith('WORKBENCH_PHYSICS ')]
                q.require(len(lines) == 1, 'Missing unique Workbench physics completion')
                complete = json.loads(lines[0])
                q.require(type(complete.get('assertions')) is int and complete['assertions'] > 0 and
                          complete.get('failures') == [] and len(complete.get('results', [])) == 4,
                          'Shared Workbench physics cases failed or incomplete')
                q.require(json.loads((EVIDENCE / 'workbench-physics-readback.json').read_text()) == complete,
                          'Native Workbench readback differs from original marker')
            row.update(status='passed', process=process, completion=complete)
        except Exception as error:
            row.update(status='failed', error=str(error))
        report['cases'].append(row)
        q.verify(SOURCE, CANDIDATE, 'linux')
        q.require(q.sha(SOURCE / q.RUNTIMES['linux']) == manifest['native_sha256'], 'Runtime changed')
        q.write(EVIDENCE / 'qualification.json', report)
        print(json.dumps({'name': name, 'status': row['status'], 'checks': row.get('completion', {}).get('checks', row.get('completion', {}).get('assertions'))}), flush=True)
    report['status'] = 'passed' if all(row['status'] == 'passed' for row in report['cases']) else 'failed'
finally:
    report['files_sha256'] = {path.relative_to(EVIDENCE).as_posix(): q.sha(path)
                             for path in EVIDENCE.rglob('*') if path.is_file() and
                             path != EVIDENCE / 'qualification.json' and 'userdata' not in path.relative_to(EVIDENCE).parts}
    q.write(EVIDENCE / 'qualification.json', report)
raise SystemExit(0 if report['status'] == 'passed' else 1)
