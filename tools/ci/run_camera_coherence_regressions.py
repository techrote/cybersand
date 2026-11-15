#!/usr/bin/env python3
"""Focused real-Workbench presentation and authoring regression processes.

The original PR593 expectations run only in the explicitly retained legacy
presentation policy. The new production test owns the coherent-policy oracle.
Each case retains its own exit/log; a failed case never becomes a skipped pass.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--project', type=Path, default=ROOT / 'godot')
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--graphical', action='store_true')
    parser.add_argument('--cases', nargs='*')
    args = parser.parse_args()
    args.evidence = args.evidence.resolve()
    args.evidence.mkdir(parents=True, exist_ok=True)
    legacy = {'CYBERSAND_DIAG_PRESENTATION': 'legacy'}
    cases = [
        ('temporal', 'test_workbench_temporal_presentation', 'TEMPORAL_PRESENTATION_RESULT', {}, False),
        ('temporal-dense', 'test_workbench_temporal_dense', 'TEMPORAL_DENSE_RESULT', {}, False),
        ('pose-trace', 'test_workbench_pose_trace', 'POSE_TRACE_RESULT', {}, False),
        ('engine-lab', 'test_workbench_engine_lab', 'ENGINE_LAB_RESULT', {}, False),
        ('clearance', 'test_workbench_presentation_coherence', 'WORKBENCH_PRESENTATION_COHERENCE_RESULT', {}, False),
        ('legacy-production', 'test_pr593_mask_coherent_production', 'PR593_PRODUCTION_POSE_RESULT', legacy, False),
        ('legacy-crossfade', 'test_pr593_mask_coherent_edit_crossfade', 'PR593_NATIVE_EDIT_CROSSFADE_RESULT', legacy, False),
        ('legacy-dense', 'test_pr593_mask_coherent_dense_budget', 'PR593_GUARD_DENSE_BUDGET_RESULT', legacy, False),
        ('cadence-contract', 'test_render_cadence_contract', 'RENDER_CADENCE_CONTRACT_RESULT', {}, False),
        ('cadence-worker', 'test_render_cadence_worker', 'RENDER_CADENCE_WORKER:', {}, False),
        ('ack-deadlines', 'test_render_ack_deadlines', 'RENDER_ACK_DEADLINES_RESULT', {}, False),
        ('camera-picking', 'test_native_pixel_camera', 'NATIVE_PIXEL_CAMERA_RESULT', {}, False),
        ('paint-author', 'test_paint_editor_workbench', 'PAINT_EDITOR_WORKBENCH', {'PAINT_REOPEN': ''}, False),
        ('paint-reopen', 'test_paint_editor_workbench', 'PAINT_EDITOR_WORKBENCH', {'PAINT_REOPEN': '1'}, False),
        ('failure-recovery', 'test_workbench_failure_recovery', 'WORKBENCH_FAILURE_RECOVERY', {}, False),
        ('material-catalogue', 'test_material_lab_catalogue', 'MATERIAL_LAB_CATALOGUE:', {}, False),
    ]
    if args.graphical:
        cases += [
            ('temporal-graphical', 'test_workbench_temporal_presentation', 'TEMPORAL_PRESENTATION_RESULT', {}, True),
            ('legacy-crossfade-graphical', 'test_pr593_mask_coherent_edit_crossfade', 'PR593_NATIVE_EDIT_CROSSFADE_RESULT', legacy, True),
            ('camera-framebuffer', 'test_native_pixel_scrolling_render', 'NATIVE_PIXEL_SCROLLING_RESULT', {}, True),
            ('camera-effects', 'test_native_camera_effects_render', 'NATIVE_CAMERA_EFFECTS_RESULT', {}, True),
        ]
    names = {row[0] for row in cases}
    if args.cases and not set(args.cases) <= names:
        parser.error('Unknown cases: ' + ', '.join(sorted(set(args.cases) - names)))
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    report = {'source_sha': source, 'cases': [], 'complete': False,
              'physical_gpu_acceptance': 'pending_owner',
              'executed_files_sha256': {p.relative_to(args.project).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for folder in ('scripts', 'shaders', 'tests') for p in sorted((args.project / folder).rglob('*'))
                 if p.is_file() and p.suffix in ('.gd', '.gdshader')},
              'source_delta': subprocess.check_output(['git', 'diff', '--stat'], cwd=ROOT, text=True)}
    for name, script, marker, overrides, graphical in cases:
        if args.cases and name not in args.cases:
            continue
        folder = args.evidence / name
        folder.mkdir(exist_ok=True)
        profile = args.evidence / ('paint-userdata' if name.startswith('paint-') else name + '-userdata')
        env = dict(os.environ, CYBERSAND_SOURCE_REVISION=source, XDG_DATA_HOME=str(profile), APPDATA=str(profile),
                   CYBERSAND_DIAG_PRESENTATION='', CYBERSAND_DIAG_RENDER_CADENCE='', CYBERSAND_DIAG_FLYER_POSE='',
                   CYBERSAND_TEST_ARTIFACT_DIR=str(folder / 'frames'))
        env.update(overrides)
        command = [str(args.godot.resolve()), '--audio-driver', 'Dummy', '--path', str(args.project.resolve())]
        command += (['--rendering-method', 'gl_compatibility', '--rendering-driver',
                     'opengl3_angle' if os.name == 'nt' else 'opengl3', '--max-fps', '60']
                    if graphical else ['--headless'])
        command += ['--script', 'res://tests/' + script + '.gd']
        if script in ('test_workbench_temporal_presentation','test_workbench_temporal_dense'):
            flag = '--temporal-evidence=' if script == 'test_workbench_temporal_presentation' else '--temporal-dense-evidence='
            command += ['--', flag + str(folder)]
        row = {'name': name, 'command': command, 'graphical': graphical, 'status': 'failed'}
        started = time.monotonic()
        try:
            with (folder / 'console.log').open('w') as log:
                result = subprocess.run(command, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
            row['exit_code'] = result.returncode
            text = (folder / 'console.log').read_text(errors='replace')
            completions = [line for line in text.splitlines() if line.startswith(marker + ' ')]
            if result.returncode != 0 or ERRORS.search(text) or not completions:
                raise RuntimeError('Test did not complete successfully; inspect retained console.log')
            row['completion'] = completions[-1]
            row['status'] = 'passed'
        except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
            row['error'] = str(error)
        row['elapsed_seconds'] = time.monotonic() - started
        row['log_sha256'] = hashlib.sha256((folder / 'console.log').read_bytes()).hexdigest()
        report['cases'].append(row)
        (args.evidence / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
        print('CAMERA_COHERENCE_CASE', name, row['status'], row.get('completion', row.get('error')), flush=True)
    report['complete'] = bool(report['cases']) and all(row['status'] == 'passed' for row in report['cases'])
    (args.evidence / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['complete'] else 1


if __name__ == '__main__':
    sys.exit(main())
