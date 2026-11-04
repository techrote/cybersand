#!/usr/bin/env python3
"""Build and run the bounded MAT-AUTH-002 real-World investigation.

All outputs must be outside the checkout. No production/runtime file is written.
Every attempt, including compiler/run failure and timeout, gets a retained receipt.
A plan contains schema=mat354.plan.v1 and cases=[{id, argv, parity_group?}].
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import time

SCHEMA = 'mat354.campaign.v1'
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCES = (
    'native/tests/material_liveness_probe.cpp', 'native/src/material_rules.cpp',
    'native/src/scheduler_geometry.cpp', 'native/src/settled_world_discovery.cpp',
)
COMMON_FLAGS = ['-std=c++20', '-Wall', '-Wextra', '-Wpedantic', '-Wconversion', '-Wshadow', '-pthread']
MODES = {
    'normal': ['-O2', '-g'],
    'asan-ubsan': ['-O1', '-g', '-fno-omit-frame-pointer', '-fsanitize=address,undefined'],
    'tsan': ['-O1', '-g', '-fno-omit-frame-pointer', '-fsanitize=thread'],
}


class EvidenceError(ValueError):
    pass


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError(f'duplicate JSON key: {key}')
        result[key] = value
    return result


def load_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=unique_object,
                      parse_constant=lambda token: (_ for _ in ()).throw(EvidenceError(f'nonfinite {token}')))


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for part in iter(lambda: handle.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def fact(path, root=None):
    path = Path(path)
    return {'path': str(path.relative_to(root)) if root else str(path), 'bytes': path.stat().st_size,
            'sha256': sha(path)}


def git(root, *arguments):
    completed = subprocess.run(['git', '-C', str(root), *arguments], text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30, check=True)
    return completed.stdout.strip()


def now():
    return datetime.now(timezone.utc).isoformat()


def write_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
    temporary.replace(path)


def output_directory(value, root):
    path = Path(value).resolve()
    if path == root or root in path.parents:
        raise EvidenceError('output must be outside the source checkout')
    if path.exists() and any(path.iterdir()):
        raise EvidenceError('output directory is not empty; preserve earlier attempts and choose a new directory')
    path.mkdir(parents=True, exist_ok=True)
    return path


def protected_check(root):
    module_path = root / 'tools/material_catalogue/compatibility.py'
    spec = importlib.util.spec_from_file_location('mat354_legacy_guard', module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.check(root, baseline_repository=root)


def inventory(root, sources, extra_paths=()):
    paths = set(sources)
    paths.add('Makefile')
    paths.add('native/src/world.cpp')
    paths.add('materials/catalogue/compatibility-lock.json')
    paths.add('tools/material_catalogue/compatibility.py')
    for directory in ('native/include', 'native/src'):
        for path in (root / directory).rglob('*'):
            if path.is_file() and path.suffix in {'.h', '.hpp', '.hh', '.hxx', '.inc'}:
                paths.add(path.relative_to(root).as_posix())
    for path in (root / 'tools/material_liveness').glob('*.py'):
        paths.add(path.relative_to(root).as_posix())
    for value in extra_paths:
        path = Path(value).resolve()
        if path == root or root in path.parents:
            paths.add(path.relative_to(root).as_posix())
    return [fact(root / path, root) for path in sorted(paths)]


def validate_plan(plan):
    if type(plan) is not dict or plan.get('schema') != 'mat354.plan.v1':
        raise EvidenceError('plan schema must be mat354.plan.v1')
    cases = plan.get('cases')
    if type(cases) is not list or not 1 <= len(cases) <= 4096:
        raise EvidenceError('plan must contain 1..4096 cases')
    seen = set()
    for case in cases:
        if type(case) is not dict or set(case) - {'id', 'argv', 'parity_group', 'expected_workers'}:
            raise EvidenceError('unknown case field')
        name = case.get('id')
        if type(name) is not str or not re.fullmatch(r'[a-zA-Z0-9_.-]{1,120}', name) or name in seen:
            raise EvidenceError('case ID must be unique and safe')
        if name in {'compiler-version', 'link'} or re.fullmatch(r'(?:compile|input)-[0-9]+', name):
            raise EvidenceError('case ID collides with a retained build artifact')
        seen.add(name)
        argv = case.get('argv')
        if type(argv) is not list or len(argv) > 64 or any(type(v) is not str or len(v) > 1024 for v in argv):
            raise EvidenceError('case argv must contain at most 64 bounded strings')
        if 'parity_group' in case and (type(case['parity_group']) is not str or not case['parity_group']):
            raise EvidenceError('parity_group must be a nonempty string')
        if 'expected_workers' in case and (type(case['expected_workers']) is not int or case['expected_workers'] not in (1, 4)):
            raise EvidenceError('expected_workers must be integer 1 or 4')
    return cases


def process(argv, cwd, prefix, timeout, environment=None):
    stdout = Path(str(prefix) + '.stdout')
    stderr = Path(str(prefix) + '.stderr')
    started = now()
    begin = time.monotonic()
    result = {'argv': [str(v) for v in argv], 'cwd': str(cwd), 'started_utc': started,
              'timeout_seconds': timeout, 'timed_out': False}
    with stdout.open('wb') as out, stderr.open('wb') as err:
        try:
            proc = subprocess.Popen(argv, cwd=cwd, stdout=out, stderr=err, env=environment,
                                    start_new_session=(os.name == 'posix'))
            try:
                result['returncode'] = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                result['timed_out'] = True
                if os.name == 'posix':
                    os.killpg(proc.pid, signal.SIGKILL)
                else:
                    proc.kill()
                result['returncode'] = proc.wait(timeout=15)
        except OSError as exc:
            result['spawn_error'] = str(exc)
            result['returncode'] = None
    result['duration_seconds'] = time.monotonic() - begin
    result['finished_utc'] = now()
    result['stdout'] = fact(stdout)
    result['stderr'] = fact(stderr)
    return result


def cpu_identity():
    cpu = platform.processor()
    if os.name == 'posix' and Path('/proc/cpuinfo').is_file():
        for line in Path('/proc/cpuinfo').read_text().splitlines():
            if line.startswith('model name'):
                cpu = line.split(':', 1)[1].strip()
                break
    return {'os': platform.platform(), 'machine': platform.machine(), 'cpu': cpu,
            'logical_cpus': os.cpu_count(), 'python': sys.version, 'hostname': platform.node()}


def run(args):
    root = args.root.resolve()
    out = output_directory(args.output, root)
    receipt = {'schema': SCHEMA, 'status': 'INITIALIZING', 'started_utc': now(),
               'root': str(root), 'mode': args.mode, 'host': cpu_identity(), 'cases': [], 'build_steps': []}
    receipt_path = out / 'campaign.json'
    write_json(receipt_path, receipt)
    try:
        plan = load_json(args.plan)
        cases = validate_plan(plan)
        sources = plan.get('compile_sources', list(DEFAULT_SOURCES))
        if type(sources) is not list or not sources or any(type(v) is not str for v in sources):
            raise EvidenceError('compile_sources must be a nonempty list of relative paths')
        for value in sources:
            path = (root / value).resolve()
            if root not in path.parents or not path.is_file() or path.suffix != '.cpp':
                raise EvidenceError(f'invalid compilation source {value}')
        extra_flags = plan.get('compile_flags', [])
        if type(extra_flags) is not list or any(type(v) is not str for v in extra_flags):
            raise EvidenceError('compile_flags must be a string array')
        receipt['source_commit'] = git(root, 'rev-parse', 'HEAD')
        receipt['production_worktree_delta'] = git(root, 'diff', '--name-only', 'HEAD', '--', 'native/src', 'native/include')
        if receipt['production_worktree_delta']:
            raise EvidenceError('production input worktree mutation is forbidden even for diagnostics')
        receipt['source_tree'] = git(root, 'rev-parse', 'HEAD^{tree}')
        receipt['worktree_status'] = git(root, 'status', '--porcelain=v1', '--untracked-files=all')
        if receipt['worktree_status'] and not args.allow_dirty_apparatus:
            raise EvidenceError('source checkout is dirty; commit the registered apparatus or use explicit diagnostic --allow-dirty-apparatus')
        receipt['source_qualified'] = not bool(receipt['worktree_status'])
        receipt['protected_source_guard'] = protected_check(root)
        receipt['plan'] = plan
        receipt['plan_file'] = fact(args.plan.resolve())
        receipt['plan_sha256'] = canonical_sha(plan)
        receipt['compiled_input_inventory'] = inventory(root, sources, (args.plan,))
        receipt['input_inventory_sha256'] = canonical_sha(receipt['compiled_input_inventory'])
        compiler = shutil.which(args.compiler)
        if not compiler:
            raise EvidenceError(f'compiler unavailable: {args.compiler}')
        compiler = str(Path(compiler).resolve())
        receipt['compiler'] = fact(Path(compiler))
        version = process([compiler, '--version'], root, out / 'compiler-version', 30)
        receipt['compiler_version'] = version
        if version['returncode'] != 0 or version['timed_out']:
            raise EvidenceError('compiler identity command failed')
        flags = COMMON_FLAGS + MODES[args.mode] + ['-I' + str(root / 'native/include')] + extra_flags
        receipt['compile_flags'] = flags
        objects = []
        for index, source in enumerate(sources):
            obj = out / f'input-{index:02d}.o'
            dep = out / f'input-{index:02d}.d'
            command = [compiler, *flags, '-MMD', '-MF', str(dep), '-c', str(root / source), '-o', str(obj)]
            step = process(command, out, out / f'compile-{index:02d}', args.compile_timeout)
            step['input'] = source
            receipt['build_steps'].append(step)
            write_json(receipt_path, receipt)
            if step['returncode'] != 0 or step['timed_out']:
                raise EvidenceError(f'compile failure retained for {source}')
            objects.append(obj)
        executable = out / ('material_liveness_probe.exe' if os.name == 'nt' else 'material_liveness_probe')
        link = process([compiler, *flags, *(str(obj) for obj in objects), '-o', str(executable)],
                       out, out / 'link', args.compile_timeout)
        receipt['build_steps'].append(link)
        if link['returncode'] != 0 or link['timed_out']:
            raise EvidenceError('link failure retained')
        receipt['executable'] = fact(executable)
        receipt['dependency_files'] = [fact(path) for path in sorted(out.glob('input-*.d'))]
        dependencies = set()
        for dep in sorted(out.glob('input-*.d')):
            content = dep.read_text().replace('\\\n', ' ')
            # GCC Make-style -MMD files, with escaped whitespace handled below.
            for value in re.findall(r'(?:\\.|[^\s])+', content.split(':', 1)[1]):
                path = Path(re.sub(r'\\(.)', r'\1', value)).resolve()
                if path.is_file():
                    dependencies.add(path)
        receipt['actual_dependency_inventory'] = [fact(path, root) if root in path.parents else fact(path) for path in sorted(dependencies)]
        if inventory(root, sources, (args.plan,)) != receipt['compiled_input_inventory']:
            raise EvidenceError('source/runtime identity mismatch: inputs changed during build')
        receipt['status'] = 'RUNNING'
        write_json(receipt_path, receipt)
        environment = dict(os.environ)
        # Explicit strict defaults, recorded even when an operator supplies overrides.
        if args.mode == 'asan-ubsan':
            environment.setdefault('ASAN_OPTIONS', 'detect_leaks=1:halt_on_error=1')
            environment.setdefault('UBSAN_OPTIONS', 'halt_on_error=1:print_stacktrace=1')
        if args.mode == 'tsan':
            environment.setdefault('TSAN_OPTIONS', 'halt_on_error=1')
        receipt['sanitizer_environment'] = {k: environment[k] for k in ('ASAN_OPTIONS', 'UBSAN_OPTIONS', 'TSAN_OPTIONS') if k in environment}
        for case in cases:
            if sha(executable) != receipt['executable']['sha256']:
                raise EvidenceError('source/runtime identity mismatch: executable changed before case')
            result = process([str(executable), *case['argv']], root, out / case['id'], args.case_timeout, environment)
            result.update({key: case[key] for key in ('id', 'parity_group', 'expected_workers') if key in case})
            receipt['cases'].append(result)
            write_json(receipt_path, receipt)
            if result['returncode'] != 0 or result['timed_out']:
                raise EvidenceError(f'case failure retained: {case["id"]}; remaining cases are unexecuted')
        if inventory(root, sources, (args.plan,)) != receipt['compiled_input_inventory']:
            raise EvidenceError('source/runtime identity mismatch: inputs changed during campaign')
        if sha(executable) != receipt['executable']['sha256']:
            raise EvidenceError('source/runtime identity mismatch: executable changed during campaign')
        receipt['post_run_guard'] = protected_check(root)
        receipt['status'] = 'EXECUTED'
    except (EvidenceError, ValueError, OSError, subprocess.SubprocessError) as exc:
        receipt['status'] = 'FAILED'
        receipt['failure'] = str(exc)
    finally:
        receipt['finished_utc'] = now()
        receipt['executed_case_count'] = len(receipt['cases'])
        write_json(receipt_path, receipt)
    print(json.dumps({'receipt': str(receipt_path), 'status': receipt['status'], 'cases': len(receipt['cases'])}))
    return 0 if receipt['status'] == 'EXECUTED' else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--mode', choices=MODES, default='normal')
    parser.add_argument('--compiler', default='g++')
    parser.add_argument('--compile-timeout', type=int, default=300)
    parser.add_argument('--case-timeout', type=int, default=60)
    parser.add_argument('--allow-dirty-apparatus', action='store_true', help='diagnostic execution only; receipt cannot claim source-qualified')
    args = parser.parse_args(argv)
    if not 1 <= args.compile_timeout <= 900 or not 1 <= args.case_timeout <= 600:
        parser.error('timeouts must be bounded: compile 1..900, case 1..600 seconds')
    try:
        return run(args)
    except (EvidenceError, OSError) as exc:
        print(f'material liveness: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
