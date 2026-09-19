"""Issue #12 immutable Current ordinary-sleep control; retain every attempt.

Prepare snapshots native inputs from an explicit Git commit before compilation.
Run never recompiles or reads a changed World implementation. This harness makes
no soliding performance claim and never publishes an experimental DLL.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CXX = Path('C:/kybersand/.local/llvm-mingw-20260826-ucrt-x86_64/bin/clang++.exe')
CORE = ['native/src/world.cpp', 'native/src/material_rules.cpp', 'native/src/scheduler_geometry.cpp']
FIXTURES = ['wall', 'redbrick', 'local-edit', 'granular-rest', 'granular-release']


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def hardware():
    result = {'platform': platform.platform(), 'logical_cpu_count': os.cpu_count(),
              'python': sys.version, 'python_executable': sys.executable}
    if os.name == 'nt':
        commands = {
            'cpu': 'Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed | ConvertTo-Json -Compress',
            'memory': 'Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory | ConvertTo-Json -Compress',
            'possible_contenders': 'Get-Process | Where-Object { $_.ProcessName -match "clang|godot|benchmark|soliding_baseline|tests_world" } | Select-Object ProcessName,Id,CPU | ConvertTo-Json -Compress',
        }
        for key, command in commands.items():
            attempt = subprocess.run(['powershell', '-NoProfile', '-Command', command], capture_output=True, text=True, timeout=30)
            result[key] = {'exit': attempt.returncode, 'stdout': attempt.stdout.strip(), 'stderr': attempt.stderr.strip()}
        attempt = subprocess.run(['powercfg', '/getactivescheme'], capture_output=True, text=True, timeout=30)
        result['power_plan'] = {'exit': attempt.returncode, 'stdout': attempt.stdout.strip(), 'stderr': attempt.stderr.strip()}
    return result


def execute(directory, name, command, env, timeout):
    command = list(map(str, command))
    stdout, stderr = directory / (name + '.stdout'), directory / (name + '.stderr')
    if stdout.exists() or stderr.exists():
        raise RuntimeError(f'refuse overwrite: {name}')
    started = time.monotonic()
    metadata = {'command': command, 'cwd': str(ROOT), 'timeout_seconds': timeout,
                'started_utc': dt.datetime.now(dt.timezone.utc).isoformat()}
    with stdout.open('wb') as output, stderr.open('wb') as errors:
        try:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=errors, timeout=timeout)
            metadata['exit'] = process.returncode
        except subprocess.TimeoutExpired:
            metadata['exit'] = 124
            metadata['failure'] = 'timeout'
        except OSError as error:
            metadata['exit'] = 125
            metadata['failure'] = str(error)
    metadata.update(elapsed_seconds=time.monotonic() - started,
                    stdout_sha256=digest(stdout), stderr_sha256=digest(stderr))
    write(directory / (name + '.execution.json'), metadata)
    return metadata, stdout


def fresh_directory(path):
    path = Path(path).resolve()
    path.mkdir(parents=True, exist_ok=False)
    return path


def prepare(args):
    out = fresh_directory(args.out)
    source_ref = git('rev-parse', args.source_ref + '^{commit}').decode().strip()
    source_paths = git('ls-tree', '-r', '--name-only', source_ref, '--', 'native/src', 'native/include').decode().splitlines()
    inputs = out / 'source'
    source_files = {}
    for name in source_paths:
        path = inputs / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(git('show', source_ref + ':' + name))
        source_files[name] = digest(path)
    harness = inputs / 'native/bench/soliding_baseline.cpp'
    harness.parent.mkdir(parents=True, exist_ok=True)
    harness.write_bytes((ROOT / 'native/bench/soliding_baseline.cpp').read_bytes())
    source_files['native/bench/soliding_baseline.cpp'] = digest(harness)
    cxx = Path(args.cxx).resolve()
    env = os.environ.copy()
    env['PATH'] = str(cxx.parent) + os.pathsep + env.get('PATH', '')
    manifest = {'schema': 'soliding-baseline-artifact-v1', 'measurement_protocol': 'soliding-baseline-v2', 'source_ref': source_ref,
                'working_head': git('rev-parse', 'HEAD').decode().strip(),
                'working_status': git('status', '--short').decode(),
                'source_root': str(inputs), 'source_files': source_files,
                'compiler': str(cxx), 'compiler_sha256': digest(cxx),
                'driver_sha256': digest(__file__), 'hardware': hardware(),
                'measurement_contract_sha256': digest(ROOT / 'docs/operations/soliding-measurement.md')}
    write(out / 'intake.json', manifest)
    version, version_path = execute(out, 'compiler-version', [cxx, '--version'], env, 30)
    if version['exit']:
        raise RuntimeError('compiler identity failed; attempt retained')
    manifest['compiler_version'] = version_path.read_text(encoding='utf-8')
    if 'clang version 23.1.0' not in manifest['compiler_version']:
        raise RuntimeError('expected pinned Clang 23.1.0; refusing toolchain drift')
    exe = out / 'soliding_baseline.exe'
    command = [cxx, '-std=c++20', '-Wall', '-Wextra', '-Wpedantic', '-Wconversion', '-Wshadow',
               '-pthread', '-static', '-O3', '-DNDEBUG', '-flto', '-I' + str(inputs / 'native/include'),
               *[inputs / name for name in CORE], harness, '-o', exe]
    build, _ = execute(out, 'build', command, env, 1200)
    if build['exit']:
        raise RuntimeError('build failed; attempt retained')
    manifest.update(executable=str(exe), executable_sha256=digest(exe), build=build)
    write(out / 'artifact.json', manifest)
    print(out / 'artifact.json', flush=True)


def run(args):
    out = fresh_directory(args.out)
    artifact_path = Path(args.artifact).resolve()
    artifact = json.loads(artifact_path.read_text(encoding='utf-8'))
    if digest(artifact['executable']) != artifact['executable_sha256']:
        raise RuntimeError('frozen executable changed')
    for name, expected in artifact['source_files'].items():
        if digest(Path(artifact['source_root']) / name) != expected:
            raise RuntimeError('frozen input changed: ' + name)
    fixtures = args.fixtures.split(',')
    if any(f not in FIXTURES for f in fixtures):
        raise ValueError('unknown fixture')
    sizes = [int(value) for value in args.sizes.split(',')]
    workers = [int(value) for value in args.workers.split(',')]
    offsets = [tuple(map(int, value.split(':'))) for value in args.offsets.split(',')]
    if any(len(offset) != 2 for offset in offsets) or args.repeats < 1:
        raise ValueError('invalid offsets or repeats')
    registered = args.ticks >= 2048 and args.settle == 120 and args.warmup == 120 and args.repeats >= 7
    plan = {'schema': 'soliding-baseline-run-v1', 'artifact': str(artifact_path),
            'artifact_sha256': digest(artifact_path), 'source_ref': artifact['source_ref'],
            'measurement_protocol': artifact.get('measurement_protocol', 'soliding-baseline-v1'),
            'executable_sha256': artifact['executable_sha256'], 'driver_sha256': digest(__file__),
            'hardware_before': hardware(), 'uncontended_note': args.uncontended_note,
            'configuration': vars(args), 'registered_timing_campaign': registered,
            'scope': 'native Current ordinary sleep only; no rendering, Rapier, discovery or acceleration'}
    # Write the fixed run schedule before executing any measured process.
    commands = []
    for repeat in range(args.repeats):
        for size in sizes:
            for offset in offsets:
                for worker in workers:
                    for fixture in fixtures:
                        name = f'r{repeat:02d}-{fixture}-{size}-w{worker}-x{offset[0]}-y{offset[1]}'
                        command = [artifact['executable'], fixture, size, worker, args.settle,
                                   args.warmup, args.ticks, *offset]
                        commands.append((name, command))
    plan['commands'] = commands
    write(out / 'registration.json', plan)
    results = []
    env = os.environ.copy()
    env['PATH'] = str(Path(artifact['compiler']).parent) + os.pathsep + env.get('PATH', '')
    hashes = {}
    state_hashes = {}
    failures = 0
    for name, command in commands:
        execution, output = execute(out, name, command, env, args.timeout)
        result = {'name': name, 'exit': execution['exit'], 'output': str(output)}
        if execution['exit']:
            failures += 1
        try:
            value = json.loads(output.read_text(encoding='utf-8'))
            if value['schema'] != plan['measurement_protocol']:
                raise ValueError('artifact measurement protocol mismatch')
            key = (value['fixture'], value['size'], tuple(value['offset']), value['measured_ticks'])
            # These frozen controls share a schema and Current phased worker contract:
            # require both full state and semantic content parity across repeats/workers.
            identity = (value['final_content_hash'], value['final_material_counts'])
            match = key not in hashes or hashes[key] == identity
            state_match = key not in state_hashes or state_hashes[key] == value['final_state_hash']
            if not match or not state_match or not value['valid']:
                failures += 1
            hashes.setdefault(key, identity)
            state_hashes.setdefault(key, value['final_state_hash'])
            result.update(fixture=value['fixture'], size=value['size'], workers=value['workers'],
                          offset=value['offset'], valid=value['valid'], deterministic_content=match, deterministic_state=state_match,
                          final_content_hash=value['final_content_hash'], final_state_hash=value['final_state_hash'],
                          cell_storage_bytes=value['cell_storage_bytes'],
                          tick_timing=value['tick_timing'], tick_plus_edit_timing=value['tick_plus_edit_timing'],
                          epoch_clear_timing=value['epoch_clear_timing'],
                          resident_cell_bytes=value['resident_cell_bytes'], resident_chunks=value['resident_chunks'],
                          total_visited_cells=sum(row['visited_cells'] for row in value['samples']),
                          total_moved_cells=sum(row['moved_cells'] for row in value['samples']),
                          total_scheduled_cores=sum(row['scheduled_cores'] for row in value['samples']))
        except (ValueError, KeyError, TypeError) as error:
            result['parse_failure'] = str(error)
            failures += 1
        results.append(result)
        write(out / 'progress.json', {'failures': failures, 'results': results})
        print(name, 'exit', execution['exit'], flush=True)
    grouped = {}
    for result in results:
        if 'tick_timing' not in result:
            continue
        key = f"{result['fixture']}/{result['size']}/w{result['workers']}/{result['offset']}"
        grouped.setdefault(key, []).append(result)
    aggregates = {key: {'processes': len(values),
                        'median_process_p95_ms': statistics.median(v['tick_timing']['p95_ms'] for v in values),
                        'median_process_p99_ms': statistics.median(v['tick_timing']['p99_ms'] for v in values),
                        'worst_process_max_ms': max(v['tick_timing']['max_ms'] for v in values),
                        'total_tick_ms': sum(v['tick_timing']['total_ms'] for v in values)}
                  for key, values in grouped.items()}
    write(out / 'completed.json', {'registration': plan, 'failures': failures, 'results': results,
                                   'grouped': aggregates, 'hardware_after': hardware()})
    print(out / 'completed.json', flush=True)
    return int(failures != 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest='mode', required=True)
    prep = modes.add_parser('prepare')
    prep.add_argument('--source-ref', required=True)
    prep.add_argument('--out', required=True)
    prep.add_argument('--cxx', default=str(DEFAULT_CXX))
    matrix = modes.add_parser('run')
    matrix.add_argument('--artifact', required=True)
    matrix.add_argument('--out', required=True)
    matrix.add_argument('--fixtures', default=','.join(FIXTURES))
    matrix.add_argument('--sizes', default='512,1024,2048')
    matrix.add_argument('--workers', default='1,4')
    matrix.add_argument('--offsets', default='0:0')
    matrix.add_argument('--repeats', type=int, default=7)
    matrix.add_argument('--settle', type=int, default=120)
    matrix.add_argument('--warmup', type=int, default=120)
    matrix.add_argument('--ticks', type=int, default=2048)
    matrix.add_argument('--timeout', type=int, default=120)
    matrix.add_argument('--uncontended-note', required=True,
                        help='Describe process/host exclusivity; supplied assertion is preserved, not independently proven')
    args = parser.parse_args()
    return prepare(args) if args.mode == 'prepare' else run(args)


if __name__ == '__main__':
    raise SystemExit(main())
