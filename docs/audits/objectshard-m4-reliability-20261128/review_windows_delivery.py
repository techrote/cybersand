#!/usr/bin/env python3
"""Read-only independent archive/source/Windows-receipt join; never runs the app."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PureWindowsPath
import subprocess
import sys
import zipfile


def sha(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-worktree', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--outer', type=Path, required=True)
    parser.add_argument('--outer-sha256', required=True)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--extract-root', type=Path, required=True)
    parser.add_argument('--native-build', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = args.source_worktree.resolve()
    require(subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
            == args.source, 'Trusted checkout is not the requested exact source')
    sys.path.insert(0, str(source / 'tools/objectshard'))
    import qualify_workbench as q
    import verify_workbench_package as verifier
    import reciprocal_windows_package as reciprocal
    import package_windows_workbench as package
    from qualify_windows_zip import extract

    commit, tree, inputs = q.native.source(source)
    scripts = q.committed_inputs()
    candidate = q.native.verify(source, args.native_build)
    require(sha(args.outer) == args.outer_sha256, 'Outer artifact digest mismatch')
    require(not args.extract_root.exists(), 'Independent extraction must be fresh')
    args.extract_root.mkdir(parents=True)
    with zipfile.ZipFile(args.outer) as outer:
        require(outer.namelist() == ['objectshard-workbench-evaluator.zip'], 'Unexpected artifact members')
    extract(args.outer, args.extract_root / 'wrapper')
    inner = args.extract_root / 'wrapper/objectshard-workbench-evaluator.zip'
    target = args.extract_root / 'Workbench independent extraction'
    extract(inner, target)
    manifest = verifier.verify(target)
    require((manifest['source_commit'], manifest['source_tree'], manifest['native']['source_inputs'])
            == (commit, tree, inputs), 'Archive source identity differs from trusted checkout')
    require(manifest['native']['sha256'] == candidate['sha256'], 'Archive DLL differs from producer')
    locations = verifier.verify_committed_godot_inputs(target, scripts, foreign_paths=reciprocal.FOREIGN_PATHS)
    reciprocal.verify_package(target, source)
    guide = subprocess.check_output(['git', '-C', str(source), 'show',
                                    commit + ':docs/operations/objectshard-workbench-playtest.md'])
    require((target / 'READ-ME.md').read_bytes() == guide, 'Owner guide differs from qualified source')
    for name, text in package.launchers(commit).items():
        require((target / name).read_bytes() == text.replace('\n', '\r\n').encode(),
                'Launcher differs from trusted source: ' + name)

    lanes = {}
    for name in ('headless', 'graphical', 'package-replay'):
        path = args.evidence / name / 'qualification.json'
        lane = json.loads(path.read_text(encoding='utf-8'))
        require(lane['status'] == 'passed' and lane['failures'] == [], 'Unpassed lane: ' + name)
        require((lane['source_commit'], lane['source_tree'], lane['native_source_inputs'])
                == (commit, tree, inputs), 'Lane source mismatch: ' + name)
        require(lane['executed_script_inputs'] == scripts, 'Lane execution inputs differ: ' + name)
        runtime = lane['runtime']
        require(runtime['native_sha256'] == candidate['sha256']
                and runtime['godot_sha256'] == manifest['godot']['console_sha256']
                and runtime['rapier_sha256'] == manifest['rapier']['sha256'], 'Lane runtime mismatch: ' + name)
        for case in lane['cases']:
            require(case['status'] == 'passed' and case['returncode'] == 0
                    and case['launch_error'] is None and not case['diagnostic_error']
                    and case['skip_messages'] == [], 'Unpassed case: ' + case['name'])
            require(bool(case['requires_display']) == ('--headless' not in case['command']),
                    'Renderer mode mismatch: ' + case['name'])
            require(sha(path.parent / case['log']) == case['log_sha256'], 'Case log digest differs: ' + case['name'])
        if name == 'package-replay':
            require(lane['package_manifest_sha256'] == sha(target / verifier.MANIFEST),
                    'Extracted execution used another package manifest')
            require(lane['packaged_godot_input_locations'] == locations, 'Extracted source locations differ')
        lanes[name] = {'receipt_sha256': sha(path), 'cases': len(lane['cases']),
                       'rendered_cases': sum('--headless' not in c['command'] for c in lane['cases']),
                       'headless_cases': sum('--headless' in c['command'] for c in lane['cases']),
                       'status': lane['status']}

    launcher_path = args.evidence / 'launcher/result.json'
    launch = json.loads(launcher_path.read_text(encoding='utf-8'))
    require(launch['status'] == 'passed' and launch['failures'] == [] and launch['zip_sha256'] == sha(inner),
            'Shipped launcher campaign did not execute this immutable inner archive')
    require([c['case'] for c in launch['cases']] == ['spaces', 'parentheses', 'unicode', 'nested'],
            'Missing clean extraction path cases')
    for case in launch['cases']:
        require(case['source_commit'] == commit
                and [(c['script'], c['exit_code']) for c in case['commands']]
                == [('Verify Workbench.cmd', 0), ('Open Workbench.cmd', 0)], 'Shipped CMD execution incomplete')
        receipt = case['launch_receipt']
        require(receipt['source_commit'] == commit and receipt['failures'] == 0 and receipt['checks'] >= 8
                and receipt['host'] == 'ordinary-workbench' and receipt['scene_id'] == 'tower'
                and receipt['startup_scene'] == 'res://feature_launcher.tscn'
                and receipt['rendering_driver'] == manifest['entry']['rendering_driver'], 'Wrong actual launch target')
    first = launch['cases'][0]
    require(first['tamper_refused'] and first['unlisted_input_refused']
            and len(first['provenance_refusals']) == 8, 'Missing source/provenance refusal controls')
    replay = json.loads((args.evidence / 'package-replay/qualification.json').read_text())
    executed_root = PureWindowsPath(launch['cases'][1]['root'])
    for case in replay['cases']:
        command = case['command']
        require(PureWindowsPath(command[command.index('--path') + 1]) == executed_root / 'godot',
                'Package replay escaped its actual clean Windows extraction')
    require(sha(args.outer) == args.outer_sha256, 'Outer archive changed during review')
    result = {'schema': 'objectshard-m4-independent-delivery-review-v1', 'status': 'passed',
              'source_commit': commit, 'source_tree': tree, 'source_inputs_verified': len(inputs),
              'execution_inputs_verified': len(scripts), 'packaged_input_locations_verified': len(locations),
              'verified_files': len(manifest['files_sha256']), 'outer_archive_sha256': sha(args.outer),
              'outer_archive_bytes': args.outer.stat().st_size,
              'inner_archive_filename': inner.name, 'inner_archive_bytes': inner.stat().st_size,
              'inner_archive_sha256': sha(inner), 'manifest_sha256': sha(target / verifier.MANIFEST),
              'native_sha256': candidate['sha256'], 'godot': manifest['godot'], 'rapier': manifest['rapier'],
              'entry': manifest['entry'], 'lanes': lanes, 'launcher_receipt_sha256': sha(launcher_path),
              'launcher_cases': [{'case': c['case'], 'checks': c['launch_receipt']['checks'],
                                 'commands': c['commands']} for c in launch['cases']],
              'provenance_refusal_cases': 8, 'independent_extraction': str(target),
              'scope': 'Independent Linux archive/source/hash audit joined to actual Windows source and clean shipped-CMD execution receipts; does not execute Windows locally or establish physical owner acceptance'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: result[k] for k in ('status', 'source_commit', 'inner_archive_bytes', 'inner_archive_sha256', 'verified_files', 'lanes')}))


if __name__ == '__main__':
    main()
