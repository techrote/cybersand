"""Preregistered isolated journal cost decomposition; no World or speedup claim."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import statistics

from run_soliding_baseline import DEFAULT_CXX, ROOT, digest, execute, fresh_directory, git, hardware, write

PROTOCOL = 'settled-discovery-cost-v1'
INPUTS = ['native/bench/settled_discovery.cpp', 'native/include/cybersand/settled_discovery.hpp',
          'tools/experiments/run_settled_discovery.py', 'tools/experiments/run_soliding_baseline.py',
          'docs/systems/settled-region-discovery.md']


def prepare(args):
    out = fresh_directory(args.out)
    inputs = out / 'source'
    hashes = {}
    for name in INPUTS:
        target = inputs / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((ROOT / name).read_bytes())
        hashes[name] = digest(target)
    cxx = Path(args.cxx).resolve()
    env = os.environ.copy()
    env['PATH'] = str(cxx.parent) + os.pathsep + env.get('PATH', '')
    manifest = {'schema': PROTOCOL, 'working_head': git('rev-parse', 'HEAD').decode().strip(),
                'working_status': git('status', '--short').decode(), 'source_root': str(inputs),
                'source_files': hashes, 'compiler': str(cxx), 'compiler_sha256': digest(cxx),
                'hardware': hardware(), 'scope': 'synthetic array-reader journal costs; no World integration'}
    write(out / 'intake.json', manifest)
    version, version_path = execute(out, 'compiler-version', [cxx, '--version'], env, 30)
    if version['exit'] or 'clang version 23.1.0' not in version_path.read_text(encoding='utf-8'):
        raise RuntimeError('pinned Clang identity failed; attempt retained')
    manifest['compiler_version'] = version_path.read_text(encoding='utf-8')
    exe = out / 'settled_discovery.exe'
    command = [cxx, '-std=c++20', '-O3', '-DNDEBUG', '-static', '-Wall', '-Wextra', '-Wpedantic',
               '-Wconversion', '-Wshadow', '-Werror', '-I' + str(inputs / 'native/include'),
               inputs / 'native/bench/settled_discovery.cpp', '-o', exe]
    build, _ = execute(out, 'build', command, env, 180)
    if build['exit']:
        raise RuntimeError('build failed; attempt retained')
    manifest.update(executable=str(exe), executable_sha256=digest(exe), build=build)
    write(out / 'artifact.json', manifest)
    print(out / 'artifact.json', flush=True)


def run(args):
    artifact_path = Path(args.artifact).resolve()
    artifact = json.loads(artifact_path.read_text(encoding='utf-8'))
    if artifact['schema'] != PROTOCOL or digest(artifact['executable']) != artifact['executable_sha256']:
        raise RuntimeError('artifact identity mismatch')
    for name, expected in artifact['source_files'].items():
        if digest(Path(artifact['source_root']) / name) != expected:
            raise RuntimeError('frozen input changed: ' + name)
    for name in INPUTS[2:4]:
        if digest(ROOT / name) != artifact['source_files'][name]:
            raise RuntimeError('running driver/helper differs from prepared artifact: ' + name)
    if not 1 <= args.repeats <= 31 or not 1 <= args.idle_epochs <= 10000000 or not 1 <= args.local_rounds <= 100000:
        raise ValueError('matrix outside registered limits')
    out = fresh_directory(args.out)
    cases = [(size, budget) for size in args.sizes for budget in args.budgets]
    plan = []
    for repeat in range(args.repeats):
        for size, budget in (cases if repeat % 2 == 0 else list(reversed(cases))):
            name = f's{size}-b{budget}-r{repeat + 1}'
            plan.append({'name': name, 'side': size, 'budget': budget, 'repeat': repeat + 1,
                         'command': [artifact['executable'], size, budget, args.idle_epochs, args.local_rounds]})
    write(out / 'plan.json', {'schema': PROTOCOL, 'artifact': str(artifact_path),
          'artifact_sha256': digest(artifact_path), 'repeats': args.repeats, 'idle_epochs': args.idle_epochs,
          'local_rounds': args.local_rounds, 'label': args.label, 'cases': plan,
          'hardware': hardware(), 'working_head': git('rev-parse', 'HEAD').decode().strip(),
          'driver_sha256': digest(__file__), 'timeout_seconds': args.timeout,
          'reservation': 'operator coordinated; process snapshots alone do not prove uncontended execution'})
    env = os.environ.copy()
    env['PATH'] = str(Path(artifact['compiler']).parent) + os.pathsep + env.get('PATH', '')
    results = []
    for case in plan:
        execution, output = execute(out, case['name'], case['command'], env, args.timeout)
        result = {'name': case['name'], 'side': case['side'], 'budget': case['budget'],
                  'exit': execution['exit'], 'stdout_sha256': digest(output), 'passed': False}
        try:
            if execution['exit']:
                raise RuntimeError('process failed')
            value = json.loads(output.read_text(encoding='utf-8'))
            if value['schema'] != PROTOCOL or value['side'] != case['side'] or value['budget'] != case['budget']:
                raise ValueError('wrong result identity')
            if not value['source_exact'] or value['fair_unaffected_blocks'] != value['blocks'] - 1:
                raise ValueError('source/fairness invariant failed')
            phases = {phase['name']: phase for phase in value['phases']}
            if (phases['initial']['work_units'] != case['side'] ** 2 + 2 * value['blocks'] or
                    phases['idle']['work_units'] != 0 or
                    phases['local_aba']['work_units'] != args.local_rounds * 1026 or
                    phases['recovery']['pending_after'] != 0):
                raise ValueError('analytical work/queue invariant failed')
            result.update(passed=True, value=value)
        except (ValueError, KeyError, RuntimeError) as error:
            result['failure'] = str(error)
        results.append(result)
        write(out / 'results.json', results)
        print(case['name'], 'PASS' if result['passed'] else 'FAIL', flush=True)
    groups = []
    for size, budget in cases:
        good = [row['value'] for row in results if row['side'] == size and row['budget'] == budget and row['passed']]
        group = {'side': size, 'budget': budget, 'successful_repeats': len(good), 'requested_repeats': args.repeats}
        def spread(values):
            return {'median': statistics.median(values), 'min': min(values), 'max': max(values)} if values else None
        group['registration_ms'] = spread([value['registration_ms'] for value in good])
        group['phase_elapsed_ms'] = {name: spread([next(p['elapsed_ms'] for p in value['phases'] if p['name'] == name)
                                                for value in good])
                                     for name in ['initial', 'idle', 'local_aba', 'churn', 'recovery']}
        groups.append(group)
    summary = {'schema': PROTOCOL, 'label': args.label, 'attempted': len(results),
               'passed': sum(row['passed'] for row in results), 'groups': groups,
               'results_sha256': digest(out / 'results.json'), 'plan_sha256': digest(out / 'plan.json'),
               'interpretation': 'isolated journal and array-reader costs; no speedup or Stage3 exit claim'}
    write(out / 'summary.json', summary)
    print(out / 'summary.json', flush=True)
    if summary['passed'] != summary['attempted']:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    build = sub.add_parser('prepare')
    build.add_argument('--out', required=True)
    build.add_argument('--cxx', default=str(DEFAULT_CXX))
    build.set_defaults(function=prepare)
    matrix = sub.add_parser('run')
    matrix.add_argument('--artifact', required=True)
    matrix.add_argument('--out', required=True)
    matrix.add_argument('--sizes', type=int, nargs='+', choices=[128, 512, 2048], default=[128, 512, 2048])
    matrix.add_argument('--budgets', type=int, nargs='+', choices=[64, 1024, 8192], default=[64, 1024, 8192])
    matrix.add_argument('--repeats', type=int, default=7)
    matrix.add_argument('--idle-epochs', type=int, default=100000)
    matrix.add_argument('--local-rounds', type=int, default=128)
    matrix.add_argument('--timeout', type=int, default=60)
    matrix.add_argument('--label', default='registered-campaign')
    matrix.set_defaults(function=run)
    args = parser.parse_args()
    args.function(args)


if __name__ == '__main__':
    main()
