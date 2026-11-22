#!/usr/bin/env python3
"""Reclassify retained original renderer diagnostics without another GPU run."""
import argparse
import hashlib
import json
from pathlib import Path
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--recovery-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Retain prior review output; choose a new output path')
    sys.path.insert(0, str(args.repository / 'tools/pubpres_render_probes'))
    from run_probes import receipt_errors
    rows = []
    for platform in ('linux', 'windows'):
        archive = f'pubpres-playability-{platform}-renderer-probes-44962312107-1'
        for folder in sorted((args.recovery_root / archive).iterdir()):
            if not folder.is_dir() or not (folder / 'arm.json').is_file():
                continue
            arm = json.loads((folder / 'arm.json').read_text())
            request = json.loads((folder / 'request.json').read_text())
            process = json.loads((folder / 'process.json').read_text())
            hashes = arm['project_inputs_sha256']
            for relative, expected in hashes.items():
                assert digest(folder / 'project' / relative) == expected, relative
            log_hashes = {}
            for name in ('stdout.log', 'stderr.log', 'godot.log'):
                path = folder / name
                assert digest(path) == process[name + '_sha256'], name
                log_hashes[name] = digest(path)
            logs = '\n'.join((folder / name).read_text() for name in log_hashes)
            errors = []
            if process['returncode'] != 0:
                errors.append('Actual Godot process returned nonzero')
            assert process['cleanup_complete'] and not process['timed_out'] and not process['surviving_children_at_exit']
            receipt_path = folder / 'receipt.json'
            receipt = json.loads(receipt_path.read_text()) if receipt_path.is_file() else None
            if receipt is None:
                errors.append('No completed probe receipt')
            else:
                errors += receipt_errors(receipt, process, arm, request['source_commit'], request['nonce'],
                                         request['engine_sha256'], hashes, platform)
            row = {
                'platform': platform, 'archive': archive, 'arm': arm['id'],
                'source_commit': request['source_commit'], 'engine_sha256': request['engine_sha256'],
                'status': 'FAIL' if errors else 'PASS', 'errors': errors,
                'process_returncode': process['returncode'],
                'process_returncode_hex32': f"0x{process['returncode'] & 0xffffffff:08X}",
                'process_cleanup_complete': True,
                'script_started': 'ISOLATED_FONT_PROBE_SCRIPT_STARTED' in logs if arm['project'] == 'font' else None,
                'receipt_sha256': digest(receipt_path) if receipt else None,
                'adapter': receipt.get('adapter') if receipt else None,
                'loaded_extensions': receipt.get('loaded_extensions') if receipt else None,
                'project_inputs_sha256': hashes, 'log_sha256': log_hashes,
                'process_json_sha256': digest(folder / 'process.json'),
                'request_json_sha256': digest(folder / 'request.json'),
                'notable_log_lines': [line for line in logs.splitlines() if any(value in line for value in
                    ('OpenGL API ', 'Error initializing GLAD', 'FATAL:', 'handle_crash:'))],
            }
            if receipt and arm['project'] == 'material':
                observation = receipt['queued_observations'][0]
                diagnostic = receipt['diagnostics'][0]
                row['first_read'] = {key: observation.get(key) for key in (
                    'verified', 'current_sha256', 'expected_current_sha256',
                    'previous_sha256', 'expected_previous_sha256')}
                row['later_diagnostic_only'] = {
                    'immediate_repeat_current_sha256': diagnostic['immediate_repeat_current']['sha256'],
                    'later_current_sha256': diagnostic['later_frame_current']['sha256'],
                    'scope': 'Later correct bytes do not change failed first-read disposition.'}
            rows.append(row)
    mixed = []
    archive = 'pubpres-playability-linux-correctness-44963596029-1'
    for name in ('test_material_staging_reachability-safe-eager', 'test_material_staging_reachability-separate-eager'):
        folder = args.recovery_root / archive / name
        process = json.loads((folder / 'process.json').read_text())
        lines = (folder / 'stdout.log').read_text().splitlines()
        result = [json.loads(line.split('MATERIAL_STAGING_REACHABILITY_RESULT ', 1)[1])
                  for line in lines if line.startswith('MATERIAL_STAGING_REACHABILITY_RESULT ')]
        assert len(result) == 1 and result[0]['failures'] and process['returncode'] != 0
        mixed.append({'archive': archive, 'arm': name, 'status': 'FAIL', **result[0],
                      'process_json_sha256': digest(folder / 'process.json'),
                      'stdout_sha256': digest(folder / 'stdout.log'),
                      'scope': 'The named eager launcher exercises both eager and reachable policies internally.'})
    result = {
        'schema': 'pubpres003-recovered-renderer-classification-v1',
        'new_graphical_execution': False,
        'original_probe_source': '0940114ddf8ef65b1f7b088dc5812776a1c02e25',
        'engine_commit': '5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88',
        'strict_oracle_sha256': digest(args.repository / 'tools/pubpres_render_probes/run_probes.py'),
        'scope': 'Independent reclassification of original retained source-bound probe receipts. It does not qualify successor software or physical NVIDIA hardware.',
        'isolated_probe_arms': rows, 'mixed_policy_original_regressions': mixed,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'output': str(args.output), 'arms': len(rows),
                      'passed': sum(r['status'] == 'PASS' for r in rows),
                      'failed': sum(r['status'] == 'FAIL' for r in rows),
                      'mixed_regressions_failed': len(mixed)}))


if __name__ == '__main__':
    main()
