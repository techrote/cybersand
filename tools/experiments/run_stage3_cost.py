"""Immutable, sequential Stage-3 producer/journal/connectivity cost campaign."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import statistics

from run_soliding_baseline import DEFAULT_CXX, ROOT, digest, execute, fresh_directory, git, hardware, write

ARTIFACT_SCHEMA = 'soliding-stage3-cost-artifact-v1'
RESULT_SCHEMA = 'soliding-stage3-cost-v1'
CORE = ['native/src/world.cpp', 'native/src/material_rules.cpp', 'native/src/scheduler_geometry.cpp',
        'native/src/render_snapshot.cpp', 'native/src/settled_world_discovery.cpp', 'native/src/c_api.cpp']
DRIVER_FILES = ['tools/experiments/run_stage3_cost.py', 'tools/experiments/run_soliding_baseline.py']
CONTRACTS = ['docs/operations/soliding-stage3-freeze.md', 'docs/operations/soliding-measurement.md',
             'docs/operations/soliding-stage3-spark-measurement.md']


def case(arm, fixture, side, workers, settle, ticks, offset=(0, 0)):
    return {'arm': arm, 'fixture': fixture, 'side': side, 'workers': workers,
            'settle': settle, 'ticks': ticks, 'offset': list(offset)}


def registered_cases():
    result = []
    for fixture in ('wall', 'redbrick'):
        for side in (512, 1024, 2048):
            for workers in (1, 4):
                for arm in ('current', 'producer', 'journal', 'connectivity'):
                    result.append(case(arm, fixture, side, workers, 2, 256))
    for fixture in ('local-edit', 'ring', 'bridge', 'mask', 'pending-event', 'exclusion', 'churn'):
        for workers in (1, 4):
            for arm in ('current', 'connectivity'):
                result.append(case(arm, fixture, 512, workers, 2, 128))
    for fixture in ('granular-rest', 'granular-release'):
        for workers in (1, 4):
            for arm in ('current', 'connectivity'):
                result.append(case(arm, fixture, 512, workers, 256, 128))
    for workers in (1, 4):
        for arm in ('current', 'connectivity'):
            result.append(case(arm, 'local-edit', 2048, workers, 2, 64))
            result.append(case(arm, 'ring', 512, workers, 2, 64, (-257, 1)))
    return result


def smoke_cases():
    return [case(arm, 'wall', 64, 1, 2, 2) for arm in
            ('current', 'producer', 'journal', 'connectivity')] + [
        case('connectivity', fixture, 64, 4, 2, 2, (-32, 0))
        for fixture in ('ring', 'bridge', 'mask')]


def prepare(args):
    out = fresh_directory(args.out)
    source_ref = git('rev-parse', args.source_ref + '^{commit}').decode().strip()
    paths = git('ls-tree', '-r', '--name-only', source_ref, '--',
                'native/src', 'native/include', 'native/bench/stage3_cost.cpp').decode().splitlines()
    inputs = out / 'source'
    hashes = {}
    for name in paths:
        target = inputs / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(git('show', source_ref + ':' + name))
        hashes[name] = digest(target)
    cxx = Path(args.cxx).resolve()
    env = os.environ.copy()
    env['PATH'] = str(cxx.parent) + os.pathsep + env.get('PATH', '')
    manifest = {'schema': ARTIFACT_SCHEMA, 'result_schema': RESULT_SCHEMA,
                'source_ref': source_ref, 'working_head': git('rev-parse', 'HEAD').decode().strip(),
                'working_status': git('status', '--short').decode(), 'source_root': str(inputs),
                'source_files': hashes, 'compiler': str(cxx), 'compiler_sha256': digest(cxx),
                'driver_files': {name: digest(ROOT / name) for name in DRIVER_FILES},
                'contracts': {name: digest(ROOT / name) for name in CONTRACTS},
                'hardware': hardware(), 'scope': 'read-only Stage-3 cost; no acceleration claim'}
    write(out / 'intake.json', manifest)
    version, version_path = execute(out, 'compiler-version', [cxx, '--version'], env, 30)
    if version['exit'] or 'clang version 23.1.0' not in version_path.read_text(encoding='utf-8'):
        raise RuntimeError('pinned compiler identity failed; attempt retained')
    manifest['compiler_version'] = version_path.read_text(encoding='utf-8')
    exe = out / 'stage3_cost.exe'
    command = [cxx, '-std=c++20', '-Wall', '-Wextra', '-Wpedantic', '-Wconversion', '-Wshadow',
               '-O3', '-DNDEBUG', '-flto', '-pthread', '-I' + str(inputs / 'native/include'),
               *[inputs / name for name in CORE], inputs / 'native/bench/stage3_cost.cpp']
    if os.name == 'nt':
        command.append('-lpsapi')
    command += ['-o', exe]
    build, _ = execute(out, 'build', command, env, 1200)
    if build['exit']:
        raise RuntimeError('build failed; attempt retained')
    manifest.update(executable=str(exe), executable_sha256=digest(exe), build=build)
    write(out / 'artifact.json', manifest)
    print(out / 'artifact.json', flush=True)


def verify_artifact(path):
    artifact = json.loads(Path(path).read_text(encoding='utf-8'))
    if artifact.get('schema') != ARTIFACT_SCHEMA or digest(artifact['executable']) != artifact['executable_sha256']:
        raise RuntimeError('artifact identity mismatch')
    for name, expected in artifact['source_files'].items():
        if digest(Path(artifact['source_root']) / name) != expected:
            raise RuntimeError('frozen input changed: ' + name)
    for name, expected in artifact['driver_files'].items():
        if digest(ROOT / name) != expected:
            raise RuntimeError('running driver/helper differs from prepared artifact: ' + name)
    for name, expected in artifact['contracts'].items():
        if digest(ROOT / name) != expected:
            raise RuntimeError('measurement contract changed after preparation: ' + name)
    return artifact


def validate_value(expected, value):
    for key in ('arm', 'fixture', 'side', 'workers', 'settle', 'ticks'):
        if value.get(key) != expected[key]:
            raise ValueError('wrong result identity: ' + key)
    if value.get('schema') != RESULT_SCHEMA or value.get('offset') != expected['offset']:
        raise ValueError('wrong result schema/offset')
    if not value.get('valid'):
        raise ValueError('benchmark invariant failed')
    if expected['arm'] == 'current':
        if value.get('producer') is not None or value.get('journal') is not None or value.get('connectivity') is not None:
            raise ValueError('Current fabricated discovery counters')
    else:
        if value.get('producer') is None or value.get('journal') is None:
            raise ValueError('candidate omitted producer/journal counters')
    if expected['arm'] == 'connectivity':
        if value.get('connectivity') is None or value.get('region_storage_bytes', 0) == 0:
            raise ValueError('connectivity arm omitted metrics/storage')
    elif value.get('connectivity') is not None:
        raise ValueError('non-connectivity arm fabricated connectivity counters')
    return value


def spread(values):
    if not values:
        return None
    ordered = sorted(values)
    return {'median': statistics.median(ordered), 'min': ordered[0], 'max': ordered[-1]}


def run(args):
    if not 1 <= args.repeats <= 9:
        raise ValueError('repeats outside registered bounds')
    artifact_path = Path(args.artifact).resolve()
    artifact = verify_artifact(artifact_path)
    out = fresh_directory(args.out)
    base = smoke_cases() if args.profile == 'smoke' else registered_cases()
    plan = []
    for repeat in range(1, args.repeats + 1):
        ordered = base if repeat % 2 else list(reversed(base))
        for index, item in enumerate(ordered):
            identity = f"{item['arm']}-{item['fixture']}-s{item['side']}-w{item['workers']}-r{repeat}-n{index + 1}"
            command = [artifact['executable'], item['arm'], item['fixture'], item['side'],
                       item['workers'], item['settle'], item['ticks'], *item['offset']]
            plan.append({**item, 'repeat': repeat, 'name': identity, 'command': command})
    plan_record = {'schema': 'soliding-stage3-cost-plan-v1', 'profile': args.profile,
                   'artifact': str(artifact_path), 'artifact_sha256': digest(artifact_path),
                   'repeats': args.repeats, 'timeout_seconds': args.timeout,
                   'uncontended_note': args.uncontended_note, 'cases': plan,
                   'hardware_before': hardware(), 'working_head': git('rev-parse', 'HEAD').decode().strip(),
                   'working_status': git('status', '--short').decode()}
    write(out / 'plan.json', plan_record)
    env = os.environ.copy()
    env['PATH'] = str(Path(artifact['compiler']).parent) + os.pathsep + env.get('PATH', '')
    rows = []
    for item in plan:
        execution, stdout = execute(out, item['name'], item['command'], env, args.timeout)
        row = {key: item[key] for key in ('name', 'arm', 'fixture', 'side', 'workers',
                                          'settle', 'ticks', 'offset', 'repeat')}
        row.update(exit=execution['exit'], stdout_sha256=digest(stdout), passed=False)
        try:
            if execution['exit']:
                raise RuntimeError('process failed')
            row['value'] = validate_value(item, json.loads(stdout.read_text(encoding='utf-8')))
            row['passed'] = True
        except (ValueError, KeyError, RuntimeError, json.JSONDecodeError) as error:
            row['failure'] = str(error)
        rows.append(row)
        write(out / 'results.json', rows)
        print(item['name'], 'PASS' if row['passed'] else 'FAIL', flush=True)

    cohort_failures = []
    cohorts = {}
    for row in rows:
        if not row['passed']:
            continue
        key = (row['fixture'], row['side'], row['workers'], row['settle'], row['ticks'],
               tuple(row['offset']), row['repeat'])
        cohorts.setdefault(key, []).append(row)
    for key, cohort in cohorts.items():
        hashes = {row['value']['final_content_hash'] for row in cohort}
        if len(hashes) != 1:
            cohort_failures.append({'cohort': list(key[:-2]) + [list(key[-2]), key[-1]],
                                    'failure': 'arm content hashes differ'})

    groups = []
    group_keys = sorted({(row['arm'], row['fixture'], row['side'], row['workers'], tuple(row['offset'])) for row in rows})
    for key in group_keys:
        selected = [row['value'] for row in rows if row['passed'] and
                    (row['arm'], row['fixture'], row['side'], row['workers'], tuple(row['offset'])) == key]
        groups.append({'arm': key[0], 'fixture': key[1], 'side': key[2], 'workers': key[3],
                       'offset': list(key[4]), 'successful_repeats': len(selected),
                       'setup_ms': spread([value['setup_ms'] for value in selected]),
                       'tick_p95_ms': spread([value['tick_timing']['p95_ms'] for value in selected]),
                       'ordinary_tick_p95_ms': spread([value['ordinary_tick_timing']['p95_ms'] for value in selected]),
                       'epoch_clear_ms': spread([value['epoch_clear_timing']['p95_ms']
                                                for value in selected if value['epoch_clear_timing'] is not None]),
                       'complete_p95_ms': spread([value['complete_timing']['p95_ms'] for value in selected]),
                       'initial_journal_ms': spread([value['initial_journal_ms'] for value in selected]),
                       'initial_region_ms': spread([value['initial_region_ms'] for value in selected]),
                       'peak_rss_bytes': spread([value['peak_rss_bytes'] for value in selected])})
    summary = {'schema': 'soliding-stage3-cost-summary-v1', 'profile': args.profile,
               'attempted': len(rows), 'passed': sum(row['passed'] for row in rows),
               'cohort_failures': cohort_failures, 'groups': groups,
               'results_sha256': digest(out / 'results.json'), 'plan_sha256': digest(out / 'plan.json'),
               'hardware_after': hardware(),
               'interpretation': 'Stage-3 read-only cost model; no speedup, acceleration or Stage-4 claim'}
    write(out / 'summary.json', summary)
    print(out / 'summary.json', flush=True)
    if summary['passed'] != summary['attempted'] or cohort_failures:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest='action', required=True)
    build = subs.add_parser('prepare')
    build.add_argument('--source-ref', default='HEAD')
    build.add_argument('--out', required=True)
    build.add_argument('--cxx', default=str(DEFAULT_CXX))
    build.set_defaults(function=prepare)
    matrix = subs.add_parser('run')
    matrix.add_argument('--artifact', required=True)
    matrix.add_argument('--out', required=True)
    matrix.add_argument('--profile', choices=('smoke', 'registered'), default='registered')
    matrix.add_argument('--repeats', type=int, default=3)
    matrix.add_argument('--timeout', type=int, default=300)
    matrix.add_argument('--uncontended-note', required=True)
    matrix.set_defaults(function=run)
    args = parser.parse_args()
    args.function(args)


if __name__ == '__main__':
    main()
