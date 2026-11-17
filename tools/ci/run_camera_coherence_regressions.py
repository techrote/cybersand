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
from package_engine_lab_windows import GRAPHICS_ERRORS, validate_publication_regression_receipt, validate_lab_window_receipt

ROOT = Path(__file__).resolve().parents[2]
ERRORS = re.compile(r"SCRIPT ERROR:|SHADER ERROR:|Parse Error:|Failed to load script|Failed loading resource:")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--project', type=Path, default=ROOT / 'godot')
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--graphical', action='store_true')
    parser.add_argument('--render-thread', choices=('safe', 'separate'))
    parser.add_argument('--cases', nargs='*')
    args = parser.parse_args()
    args.evidence = args.evidence.resolve()
    args.evidence.mkdir(parents=True, exist_ok=True)
    legacy = {'CYBERSAND_DIAG_PRESENTATION': 'legacy'}
    cases = [
        ('temporal', 'test_workbench_temporal_presentation', 'TEMPORAL_PRESENTATION_RESULT', {}, False),
        ('temporal-dense', 'test_workbench_temporal_dense', 'TEMPORAL_DENSE_RESULT', {}, False),
        ('temporal-contact', 'test_workbench_temporal_contact', 'TEMPORAL_CONTACT_RESULT', {}, False),
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
        ('workbench-input', 'test_workbench_input', 'WORKBENCH_INPUT', {}, False),
        ('workbench-fleet', 'test_workbench_fleet_session', 'WORKBENCH_FLEET', {}, False),
        ('workbench-physics', 'test_workbench_physics_play', 'WORKBENCH_PHYSICS', {}, False),
        ('physics-pacing', 'test_workbench_physics_pacing', 'PHYSICS_PACING_RESULT', {}, False),
        ('physics-publication', 'test_workbench_physics_publication', 'PHYSICS_PUBLICATION_RESULT', {}, False),
        ('material-tiles', 'test_material_tile_publication', 'MATERIAL_TILE_PUBLICATION:', {}, False),
        ('palette-compile-bounds', 'test_palette_shader_compile_bounds', 'PALETTE_COMPILE_BOUNDS_RESULT', {}, False),
        ('rapier-manual', 'test_rapier_manual_step', 'Rapier2D manual-step', {}, False),
        ('terrain-packet', 'test_hard_surface_incremental_packet', 'HARD_SURFACE_INCREMENTAL', {}, False),
        ('full-material-upload', 'test_render_full_upload', 'RENDER_FULL_UPLOAD:', {}, False),
        ('native-rendezvous', 'test_workbench_native_rendezvous', 'NATIVE_RENDEZVOUS:', {}, False),
        ('native-rendezvous-integration', 'test_workbench_native_rendezvous_integration', 'PHYSICS_PUBLICATION_RESULT', {}, False),
        ('native-render-overlap', 'test_workbench_native_render_overlap', 'NATIVE_RENDER_OVERLAP:', {}, False),
        ('actor-integration', 'test_physical_actor_integration', 'Physical actor integration:', {}, False),
        ('native-world-clearance', 'test_pr566_mask_coherent_native_world', 'PR566_WORLD_CLEARANCE_RESULT', {}, False),
    ]
    if args.graphical:
        cases += [
            ('temporal-graphical', 'test_workbench_temporal_presentation', 'TEMPORAL_PRESENTATION_RESULT', {}, True),
            ('temporal-contact-graphical', 'test_workbench_temporal_contact', 'TEMPORAL_CONTACT_RESULT', {}, True),
            ('legacy-crossfade-graphical', 'test_pr593_mask_coherent_edit_crossfade', 'PR593_NATIVE_EDIT_CROSSFADE_RESULT', legacy, True),
            ('camera-framebuffer', 'test_native_pixel_scrolling_render', 'NATIVE_PIXEL_SCROLLING_RESULT', {}, True),
            ('camera-effects', 'test_native_camera_effects_render', 'NATIVE_CAMERA_EFFECTS_RESULT', {}, True),
            ('physics-publication-graphical', 'test_workbench_physics_publication', 'PHYSICS_PUBLICATION_RESULT', {}, True),
            ('material-tiles-graphical', 'test_material_tile_publication', 'MATERIAL_TILE_PUBLICATION:', {}, True),
            ('material-threaded-graphical', 'test_material_threaded_publication', 'MATERIAL_THREADED_PUBLICATION:', {}, True),
            ('material-threaded-safe-graphical', 'test_material_threaded_publication', 'MATERIAL_THREADED_PUBLICATION:', {}, True),
            ('font-mipmap-safe-graphical', 'test_default_font_mipmap_publication', 'DEFAULT_FONT_MIPMAP_PUBLICATION:', {}, True),
            ('font-mipmap-separate-graphical', 'test_default_font_mipmap_publication', 'DEFAULT_FONT_MIPMAP_PUBLICATION:', {}, True),
            ('depth-threaded-safe-graphical', 'test_depth_threaded_publication', 'DEPTH_THREADED_PUBLICATION:', {}, True),
            ('depth-threaded-separate-graphical', 'test_depth_threaded_publication', 'DEPTH_THREADED_PUBLICATION:', {}, True),
            ('paint-author-graphical', 'test_paint_editor_workbench', 'PAINT_EDITOR_WORKBENCH', {'PAINT_REOPEN': ''}, True),
            ('paint-reopen-graphical', 'test_paint_editor_workbench', 'PAINT_EDITOR_WORKBENCH', {'PAINT_REOPEN': '1'}, True),
            ('native-rendezvous-graphical', 'test_workbench_native_rendezvous_integration', 'PHYSICS_PUBLICATION_RESULT', {}, True),
            ('native-render-overlap-graphical', 'test_workbench_native_render_overlap', 'NATIVE_RENDER_OVERLAP:', {}, True),
            ('physics-pacing-graphical', 'test_workbench_physics_pacing', 'PHYSICS_PACING_RESULT', {}, True),
            ('engine-lab-safe-graphical', 'test_workbench_engine_lab', 'ENGINE_LAB_RESULT', {}, True),
            ('engine-lab-separate-graphical', 'test_workbench_engine_lab', 'ENGINE_LAB_RESULT', {}, True),
            ('materials-lab-safe-graphical', 'test_material_lab_ui', 'MATERIAL_LAB_WORKBENCH_MOUNT:', {}, True),
            ('materials-lab-separate-graphical', 'test_material_lab_ui', 'MATERIAL_LAB_WORKBENCH_MOUNT:', {}, True),
        ]
    names = {row[0] for row in cases}
    if args.cases and not set(args.cases) <= names:
        parser.error('Unknown cases: ' + ', '.join(sorted(set(args.cases) - names)))
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    report = {'source_sha': source, 'cases': [], 'complete': False,
              'physical_gpu_acceptance': 'pending_owner',
              'executed_files_sha256': {p.relative_to(args.project).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for folder in ('scripts', 'shaders', 'tests') for p in sorted((args.project / folder).rglob('*'))
                 if p.is_file() and p.suffix in ('.gd', '.gdshader', '.gdshaderinc')},
              'source_delta': subprocess.check_output(['git', 'diff', '--stat'], cwd=ROOT, text=True)}
    for name, script, marker, overrides, graphical in cases:
        if args.cases and name not in args.cases:
            continue
        folder = args.evidence / name
        folder.mkdir(exist_ok=True)
        profile = args.evidence / (('paint-graphical-userdata' if graphical else 'paint-userdata')
                                   if name.startswith('paint-') else name + '-userdata')
        env = dict(os.environ, CYBERSAND_SOURCE_REVISION=source, XDG_DATA_HOME=str(profile), APPDATA=str(profile),
                   CYBERSAND_DIAG_PRESENTATION='', CYBERSAND_DIAG_RENDER_CADENCE='', CYBERSAND_DIAG_FLYER_POSE='',
                   CYBERSAND_TEST_ARTIFACT_DIR=str(folder / 'frames'))
        env.update(overrides)
        render_thread = args.render_thread if graphical else 'safe'
        if script in ('test_workbench_physics_publication', 'test_workbench_native_rendezvous_integration'):
            env['CYBERSAND_PHYSICS_PUBLICATION_OUTPUT'] = str(folder / 'physics-publication.json')
        elif script == 'test_material_tile_publication':
            env['CYBERSAND_MATERIAL_TILE_OUTPUT'] = str(folder / 'material-tiles.json')
        elif script == 'test_material_threaded_publication':
            render_thread = 'safe' if 'safe' in name else (args.render_thread or 'safe')
            env['CYBERSAND_MATERIAL_QUEUE_THREAD'] = render_thread
            env['CYBERSAND_MATERIAL_QUEUE_OUTPUT'] = str(folder / 'material-threaded.json')
        elif script == 'test_default_font_mipmap_publication':
            render_thread = 'separate' if 'separate' in name else 'safe'
            env['CYBERSAND_FONT_MIPMAP_THREAD'] = render_thread
            env['CYBERSAND_FONT_MIPMAP_OUTPUT'] = str(folder)
            env['CYBERSAND_FONT_MIPMAP_REFERENCE'] = str(args.evidence / 'font-mipmap-safe-graphical') if render_thread == 'separate' else ''
        elif script == 'test_workbench_native_render_overlap':
            render_thread = 'separate' if graphical else 'safe'
            env['CYBERSAND_NATIVE_RENDER_OVERLAP_OUTPUT'] = str(folder / 'render-overlap.json')
        elif script == 'test_depth_threaded_publication':
            render_thread = 'separate' if 'separate' in name else 'safe'
            env['CYBERSAND_DEPTH_QUEUE_THREAD'] = render_thread
            env['CYBERSAND_DEPTH_QUEUE_OUTPUT'] = str(folder / 'depth-threaded.json')
        elif script == 'test_workbench_engine_lab' and graphical:
            render_thread = 'separate' if 'separate' in name else 'safe'
            env['CYBERSAND_ENGINE_LAB_SCREENSHOT'] = str(folder / 'engine-lab.png')
            env['CYBERSAND_ENGINE_LAB_OUTPUT'] = str(folder / 'engine-lab.json')
        elif script == 'test_material_lab_ui':
            render_thread = 'separate' if 'separate' in name else 'safe'
            env['CYBERSAND_MATERIAL_LAB_WINDOW_OUTPUT'] = str(folder)
        env['CYBERSAND_DIAG_NATIVE_RENDEZVOUS'] = 'render-overlap' if render_thread == 'separate' else '0'
        env['CYBERSAND_MATERIAL_PUBLICATION'] = 'auto'
        env['CYBERSAND_DIAG_PHYSICS_PUBLICATION'] = 'early'
        for selector in ('CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS', 'CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS',
                         'CYBERSAND_DIAG_MATERIAL_COPY_MODE', 'CYBERSAND_DIAG_COMMON_OBSERVER'):
            env[selector] = ''
        if name.startswith('paint-'):
            env['PAINT_CAPTURE_DIR'] = str(folder / 'frames') if graphical else ''
        command = [str(args.godot.resolve()), '--audio-driver', 'Dummy', '--path', str(args.project.resolve())]
        if render_thread is not None:
            command += ['--render-thread', render_thread]
        command += (['--rendering-method', 'gl_compatibility', '--rendering-driver',
                     'opengl3_angle' if os.name == 'nt' else 'opengl3', '--max-fps', '60']
                    if graphical else ['--headless'])
        command += ['--script', 'res://tests/' + script + '.gd']
        if script in ('test_workbench_temporal_presentation','test_workbench_temporal_dense','test_workbench_temporal_contact'):
            flag = {'test_workbench_temporal_presentation': '--temporal-evidence=',
                    'test_workbench_temporal_dense': '--temporal-dense-evidence=',
                    'test_workbench_temporal_contact': '--temporal-contact-evidence='}[script]
            command += ['--', flag + str(folder)]
        elif script == 'test_workbench_physics_pacing':
            command += ['--', '--physics-pacing-evidence=' + str(folder)]
        elif script == 'test_render_full_upload':
            command += ['--', '--render-full-upload-evidence=' + str(folder / 'full-upload.json')]
        elif script == 'test_material_lab_ui':
            command += ['--', '--workbench-mount-only']
        row = {'name': name, 'command': command, 'graphical': graphical, 'status': 'failed'}
        started = time.monotonic()
        try:
            with (folder / 'console.log').open('w', encoding='utf-8') as log:
                result = subprocess.run(command, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
            row['exit_code'] = result.returncode
            text = (folder / 'console.log').read_text(encoding='utf-8', errors='replace')
            completions = [line for line in text.splitlines() if line.startswith(marker + ' ')]
            if result.returncode != 0 or ERRORS.search(text) or GRAPHICS_ERRORS.search(text) or not completions:
                raise RuntimeError('Test did not complete successfully; inspect retained console.log')
            row['completion'] = completions[-1]
            if script == 'test_material_threaded_publication':
                row['receipt'] = validate_publication_regression_receipt(name, folder / 'material-threaded.json', args.project, source)
            elif script == 'test_default_font_mipmap_publication':
                row['receipt'] = validate_publication_regression_receipt(name, folder / 'result.json', args.project, source)
            elif script == 'test_workbench_native_rendezvous_integration':
                row['receipt'] = validate_publication_regression_receipt(name, folder / 'physics-publication.json', args.project, source)
            elif script == 'test_workbench_native_render_overlap':
                row['receipt'] = validate_publication_regression_receipt(name, folder / 'render-overlap.json', args.project, source)
            elif script == 'test_depth_threaded_publication':
                row['receipt'] = validate_publication_regression_receipt(name, folder / 'depth-threaded.json', args.project, source)
            elif script == 'test_workbench_engine_lab' and graphical:
                row['receipt'] = validate_lab_window_receipt(name, folder / 'engine-lab.json', args.project, source, folder / 'engine-lab.png')
            elif script == 'test_material_lab_ui':
                row['receipt'] = validate_lab_window_receipt(name, folder / 'result.json', args.project, source)
            row['status'] = 'passed'
        except (RuntimeError, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
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
