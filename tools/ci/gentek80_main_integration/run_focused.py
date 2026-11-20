#!/usr/bin/env python3
"""Execute existing combined-Workbench regressions without rebuilding native code."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root, engine, output = args.candidate.resolve(), args.godot.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sys.path[:0] = [str(root / 'tools/architecture'), str(root / 'tools'), str(root / 'tools/ci')]
    import qualify
    import qualify_workbench_landscapes as custody
    from stress_physical_godot import case_environment
    report = {'schema': 'gentek80-main-existing-regressions-v1', 'passed': False, 'cases': []}
    try:
        identity, runtime = custody.source_identity(), custody.verify_runtime_identity()
        project = custody.project_identity(root / 'godot', identity, runtime)
        version = subprocess.check_output([str(engine), '--version'], text=True, timeout=30).strip()
        custody.require(version == qualify.VERSION, 'Godot version mismatch')
        report.update(source=identity, runtime=runtime, project_inputs_sha256=project,
                      godot_version=version, godot_sha256=qualify.sha(engine), platform=sys.platform)
        architecture = output / 'architecture'
        record = qualify.run('architecture', [sys.executable, str(root / 'tools/architecture/qualify.py'),
                             '--godot', str(engine), '--output', str(architecture), '--suite', 'all', '--graphical'],
                             os.environ.copy(), output, 1800)
        report['cases'].append(record)
        architecture_report = json.loads((architecture / 'qualification.json').read_text())
        custody.require(record['passed'] and architecture_report['passed'] and architecture_report['failures'] == 0,
                        'Existing architectural native/project/UI/author/reopen suite failed')
        cases = [
            ('installed-author', 'test_workbench_generator_installed', 'installed', {}, r'WB_GENERATOR_INSTALLED checks=[1-9][0-9]* failures=0'),
            ('installed-reopen', 'test_workbench_generator_installed', 'installed', {'WB_GENERATOR_REOPEN':'1'}, r'WB_GENERATOR_INSTALLED checks=[1-9][0-9]* failures=0'),
            ('paint-author', 'test_paint_editor_generated_workbench', 'paint-generated', {}, r'PAINT_EDITOR_GENERATED_WORKBENCH (.*)'),
            ('paint-reopen', 'test_paint_editor_generated_workbench', 'paint-generated', {'PAINT_GENERATED_REOPEN':'1'}, r'PAINT_EDITOR_GENERATED_WORKBENCH (.*)'),
            ('art-lazy', 'test_art_lazy_traffic', 'art-lazy', {}, r'ART_LAZY_TRAFFIC (.*)'),
            ('art-integrity', 'test_art_traffic_integrity', 'art-integrity', {}, r'ART_TRAFFIC_INTEGRITY (.*)'),
            ('art-panel-safety', 'test_art_traffic_panel_safety', 'art-panel', {}, r'ART_TRAFFIC_PANEL (.*)'),
            ('art-native-batch', 'test_art_batch_native', 'art-native', {}, r'ART_STAGE1_RESULT (.*)'),
            ('workbench_edit_ordering', 'test_workbench_edit_ordering', 'edit-order', {}, r'EDIT_ORDER_RESULT (.*)'),
            ('paint-native', 'test_paint_editor_native', 'paint-native', {}, r'PAINT_EDITOR_NATIVE (.*)'),
            ('material-baseline', 'test_workbench_material_baseline', 'baseline', {}, r'WORKBENCH_MATERIAL_BASELINE checks=[1-9][0-9]* failures=0'),
            ('water-lab', 'test_workbench_wave_spill', 'water', {}, r'WORKBENCH_WAVE_SPILL (.*)'),
        ]
        display = ['--rendering-method', 'gl_compatibility'] + (['--rendering-driver', 'opengl3_angle'] if os.name == 'nt' else ['--display-driver', 'x11'])
        for label, script, profile, extra, marker in cases:
            environment = case_environment(output / 'profiles' / profile)
            environment.update(CYBERSAND_SOURCE_REVISION=identity['source_commit'], **extra)
            command = [str(engine), '--audio-driver', 'Dummy', '--path', str(root / 'godot'),
                       *display, '--script', f'res://tests/{script}.gd']
            record = qualify.run(label, command, environment, output, 600, marker)
            text = (output / (label + '.log')).read_text(errors='replace')
            if marker.endswith('(.*)'):
                matches = re.findall(marker, text)
                custody.require(len(matches) == 1, 'Missing/duplicate result: ' + label)
                result = json.loads(matches[0])
                record['assertions'] = result.get('checks')
                record['assertion_failures'] = result.get('failures')
                record['passed'] = record['passed'] and bool(result.get('checks')) and not result.get('failures')
                if 'completed' in result:
                    record['passed'] = record['passed'] and result['completed'] is True
            report['cases'].append(record)
            custody.write_json(output / 'qualification.json', report)
            custody.require(record['passed'], 'Existing regression failed: ' + label)
        custody.require(custody.source_identity() == identity and custody.verify_runtime_identity() == runtime
                        and custody.project_identity(root / 'godot', identity, runtime) == project,
                        'Source/runtime/project changed during existing-suite execution')
        report.update(passed=True, source_stable=True)
    except Exception as error:
        report['error'] = str(error)
        print('FOCUSED_QUALIFICATION_FAILED:', error, file=sys.stderr)
    report['completed'] = True
    custody.write_json(output / 'qualification.json', report)
    print(json.dumps({'passed':report['passed'], 'cases':len(report['cases']), 'source':report.get('source',{}).get('source_commit')}))
    return int(not report['passed'])


if __name__ == '__main__':
    raise SystemExit(main())
