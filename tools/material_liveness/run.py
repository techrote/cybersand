#!/usr/bin/env python3
"""Build and run the bounded MAT-AUTH-002 real-World investigation.

All outputs must be outside the checkout. No production/runtime file is written.
Every attempt, including compiler/run failure and timeout, gets a retained receipt.
A plan contains schema=mat354.campaign.v1 and a finite cases array.
"""
from __future__ import annotations

import argparse
import ctypes
import errno
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
import stat
import subprocess
import sys
import tempfile
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
    # Windows temporary directories can name the same directory with an 8.3
    # alias or its expanded name. Normalize both operands before relativizing.
    name = path.resolve().relative_to(Path(root).resolve()).as_posix() if root is not None else str(path)
    return {'path': name, 'bytes': path.stat().st_size,
            'sha256': sha(path)}


def git(root, *arguments):
    completed = subprocess.run(['git', '-C', str(root), *arguments], text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30, check=True)
    return completed.stdout.strip()


def now():
    return datetime.now(timezone.utc).isoformat()


def sync_directory(path):
    if os.name == 'posix':
        descriptor = os.open(path, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


def write_json(path, value):
    path = Path(path)
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                     prefix='.' + path.name + '.', suffix='.partial', delete=False) as handle:
        temporary = Path(handle.name)
        json.dump(value, handle, indent=2, sort_keys=True, allow_nan=False)
        handle.write('\n')
        handle.flush()
        os.fsync(handle.fileno())
    # A progress receipt intentionally supersedes its own preceding version.
    os.replace(temporary, path)
    sync_directory(path.parent)


def publish_no_replace(temporary, destination):
    """Atomically expose a complete raw file, refusing every existing name."""
    temporary, destination = Path(temporary), Path(destination)
    if temporary.parent.resolve() != destination.parent.resolve():
        raise EvidenceError('raw temporary and final paths must share one directory')
    method = None
    if sys.platform.startswith('linux'):
        library = ctypes.CDLL(None, use_errno=True)
        operation = getattr(library, 'renameat2', None)
        if operation is not None:
            operation.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
            operation.restype = ctypes.c_int
            # Linux RENAME_NOREPLACE is an atomic rename that cannot overwrite.
            if operation(-100, os.fsencode(temporary), -100, os.fsencode(destination), 1) == 0:
                method = 'renameat2(RENAME_NOREPLACE)'
            else:
                code = ctypes.get_errno()
                if code not in (errno.ENOSYS, errno.EINVAL, getattr(errno, 'EOPNOTSUPP', errno.ENOSYS)):
                    raise OSError(code, os.strerror(code), str(destination))
    if method is None and os.name == 'nt':
        # Windows rename already refuses an existing destination.
        os.rename(temporary, destination)
        method = 'rename-no-replace'
    if method is None:
        # Portable same-filesystem fallback: atomic no-overwrite publication,
        # followed by removal of the private temporary name.
        os.link(temporary, destination)
        temporary.unlink()
        method = 'link-unlink-no-replace'
    sync_directory(destination.parent)
    return method


def verify_retained_outputs(processes):
    """Reauthenticate all raw bytes immediately before campaign completion."""
    checked = []
    for result in processes:
        for stream in ('stdout', 'stderr'):
            expected = result[stream]
            actual = fact(Path(expected['path']))
            if actual['bytes'] != expected['bytes'] or actual['sha256'] != expected['sha256']:
                raise EvidenceError(f"retained raw identity mismatch: {expected['path']}; "
                                    f"expected {expected['bytes']} bytes/{expected['sha256']}, "
                                    f"found {actual['bytes']} bytes/{actual['sha256']}")
            checked.append(actual)
    return {'status': 'PASS', 'files': len(checked), 'verified_utc': now(),
            'inventory_sha256': canonical_sha(checked)}


def restore_generated_executable(path, expected, output_directory):
    """Restore only a lost owner-execute bit on our unchanged generated binary.

An already executable file is never chmod-ed or retried after an access denial.
No directory, ACL, ownership or other permission bit is changed.
"""
    path, output_directory = Path(path), Path(output_directory).resolve()
    if (path.is_symlink() or path.resolve().parent != output_directory or
            path.resolve() != Path(expected['path']).resolve()):
        raise EvidenceError('executable mode check is limited to this build output')
    with path.open('rb') as handle:
        before = os.fstat(handle.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise EvidenceError('generated executable is not a regular file')
        actual_hash = hashlib.file_digest(handle, 'sha256').hexdigest()
        if before.st_size != expected['bytes'] or actual_hash != expected['sha256']:
            raise EvidenceError('source/runtime identity mismatch: executable changed before case')
        mode = stat.S_IMODE(before.st_mode)
        # A present execute bit means any EACCES has another cause. Do not try
        # permission broadening or an alternate execution route.
        if os.name != 'posix' or mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH):
            return None
        if before.st_uid != os.geteuid():
            raise EvidenceError('generated executable is not owned by this process; mode repair refused')
        repaired_mode = mode | stat.S_IXUSR
        os.fchmod(handle.fileno(), repaired_mode)
        os.fsync(handle.fileno())
        handle.seek(0)
        if hashlib.file_digest(handle, 'sha256').hexdigest() != expected['sha256']:
            raise EvidenceError('executable bytes changed during owner-mode repair')
        after = path.stat()
        if (after.st_dev, after.st_ino) != (before.st_dev, before.st_ino) or stat.S_IMODE(after.st_mode) != repaired_mode:
            raise EvidenceError('generated executable changed during owner-mode repair')
    return {'kind': 'artifact-mode-repair', 'path': str(path), 'before_mode': oct(mode),
            'after_mode': oct(repaired_mode), 'sha256': expected['sha256'], 'at_utc': now(),
            'scope': 'restore owner execute bit on unchanged owned build artifact only'}


def sanitizer_configuration(mode, disable_leak_check, base_environment):
    if disable_leak_check and mode != 'asan-ubsan':
        raise EvidenceError('--disable-leak-check is valid only with --mode asan-ubsan')
    environment = dict(base_environment)
    leak_check = {'status': 'not-applicable', 'reason': 'build does not enable AddressSanitizer'}
    if mode == 'asan-ubsan':
        options = environment.get('ASAN_OPTIONS', 'halt_on_error=1')
        parts = [part for part in options.split(':') if part]
        leak_values = [part.partition('=')[2] for part in parts if part.partition('=')[0] == 'detect_leaks']
        if not disable_leak_check and any(value not in ('1', 'true', 'yes') for value in leak_values):
            raise EvidenceError('disabled leak detection requires explicit --disable-leak-check')
        parts = [part for part in parts if part.partition('=')[0] != 'detect_leaks']
        parts.append('detect_leaks=' + ('0' if disable_leak_check else '1'))
        environment['ASAN_OPTIONS'] = ':'.join(parts)
        environment.setdefault('UBSAN_OPTIONS', 'halt_on_error=1:print_stacktrace=1')
        leak_check = {'status': 'unexecuted' if disable_leak_check else 'requested',
                      'reason': 'explicit --disable-leak-check; separate ASan/UBSan execution' if disable_leak_check else 'LeakSanitizer requested with detect_leaks=1'}
    if mode == 'tsan':
        environment.setdefault('TSAN_OPTIONS', 'halt_on_error=1')
    metadata = {key: environment[key] for key in ('ASAN_OPTIONS', 'UBSAN_OPTIONS', 'TSAN_OPTIONS', 'LSAN_OPTIONS') if key in environment}
    return environment, metadata, leak_check


def output_directory(value, root):
    path, root = Path(value).resolve(), Path(root).resolve()
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
    root = Path(root).resolve()
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


def make_dependency_paths(content):
    """Read compiler Make dependencies without confusing drive letters/escapes.

    This handles generated -MMD files, not arbitrary Make programs. Backslashes
    before ordinary path characters remain Windows separators; quoted spaces,
    hashes, colons and dollar signs are decoded without shell interpretation.
    """
    if '\0' in content:
        raise EvidenceError('NUL in dependency file')
    content = re.sub(r'\\\r?\n', ' ', content)
    dependencies = []
    for line in content.splitlines():
        if not line.strip():
            continue
        delimiter, token_start, index = None, 0, 0
        while index < len(line):
            char = line[index]
            if char == '\\' and index + 1 < len(line) and line[index + 1] in ' \t#:$':
                index += 2
                continue
            if char.isspace():
                token_start = index + 1
            if char == ':':
                drive = (index == token_start + 1 and line[token_start].isalpha() and
                         index + 1 < len(line) and line[index + 1] in '/\\')
                if not drive:
                    delimiter = index
                    break
            index += 1
        if delimiter is None:
            raise EvidenceError('dependency rule has no target delimiter')
        values, current, index = [], [], delimiter + 1
        while index < len(line):
            char = line[index]
            if char.isspace():
                if current:
                    values.append(''.join(current))
                    current = []
                index += 1
                continue
            if char == '#':
                break
            if char == '\\' and index + 1 < len(line):
                following = line[index + 1]
                if following in ' \t#:$':
                    current.append(following)
                    index += 2
                    continue
                if following == '\\' and current:
                    current.append('\\')
                    index += 2
                    continue
            if char == '$' and index + 1 < len(line) and line[index + 1] == '$':
                current.append('$')
                index += 2
                continue
            current.append(char)
            index += 1
        if current:
            values.append(''.join(current))
        dependencies.extend(values)
    if not dependencies:
        raise EvidenceError('dependency files contain no inputs')
    return dependencies


def actual_dependencies(root, dependency_files, compile_directory):
    root, compile_directory = Path(root).resolve(), Path(compile_directory).resolve()
    paths = set()
    for dependency_file in dependency_files:
        for name in make_dependency_paths(dependency_file.read_text(encoding='utf-8')):
            path = Path(name)
            if not path.is_absolute():
                path = compile_directory / path
            path = path.resolve()
            if not path.is_file():
                raise EvidenceError(f'compiler dependency is unavailable or misparsed: {name}')
            paths.add(path)
    if (root / 'native/src/world.cpp').resolve() not in paths:
        raise EvidenceError('compiler dependency inventory does not contain actual native/src/world.cpp')
    return [fact(path, root) if root in path.parents else fact(path) for path in sorted(paths)]


def compiler_flags(mode, operating_system):
    flags = list(COMMON_FLAGS)
    if operating_system == 'nt':
        # The Windows workflow uses installed LLVM's GNU-compatible driver in
        # a real MSVC development environment, not a POSIX thread runtime.
        flags.remove('-pthread')
        flags += ['-fexceptions', '-fcxx-exceptions']
    return flags + MODES[mode]


def physical_arguments(argv):
    """Identify matched physical configuration without execution capacity/repeat."""
    if len(argv) % 2 or any(not argv[i].startswith('--') for i in range(0, len(argv), 2)):
        raise EvidenceError('probe arguments must be flag/value pairs')
    arguments = {}
    for flag, value in zip(argv[::2], argv[1::2]):
        if flag in arguments:
            raise EvidenceError(f'duplicate probe flag {flag}')
        arguments[flag] = value
    return {flag: value for flag, value in arguments.items() if flag not in {'--workers', '--repeat'}}


def validate_plan(plan):
    if type(plan) is not dict or plan.get('schema') not in {'mat354.plan.v1', 'mat354.campaign.v1'}:
        raise EvidenceError('plan schema must be mat354.campaign.v1 or mat354.plan.v1')
    cases = plan.get('cases')
    if type(cases) is not list or not 1 <= len(cases) <= 4096:
        raise EvidenceError('plan must contain 1..4096 cases')
    seen, normalized = set(), []
    allowed = {'id', 'argv', 'parity_group', 'expected_workers', 'workers', 'fixture',
               'x', 'y', 'ticks', 'quiet', 'active_neighbour', 'variant', 'repeat', 'selection'}
    for case in cases:
        if type(case) is not dict or set(case) - allowed:
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
        config = physical_arguments(argv)
        actual_flags = dict(zip(argv[::2], argv[1::2]))
        if 'parity_group' in case and (type(case['parity_group']) is not str or not case['parity_group']):
            raise EvidenceError('parity_group must be a nonempty string')
        for field in ('workers', 'expected_workers'):
            if field in case and (type(case[field]) is not int or case[field] not in (1, 4)):
                raise EvidenceError(f'{field} must be integer 1 or 4')
        if 'workers' in case and 'expected_workers' in case and case['workers'] != case['expected_workers']:
            raise EvidenceError('workers and expected_workers aliases disagree')
        for field in ('x', 'y', 'ticks', 'quiet', 'repeat'):
            if field in case and type(case[field]) is not int:
                raise EvidenceError(f'{field} must be an integer')
        for field in ('ticks', 'quiet'):
            if field in case and case[field] < 1:
                raise EvidenceError(f'{field} must be positive')
        if 'active_neighbour' in case and type(case['active_neighbour']) is not bool:
            raise EvidenceError('active_neighbour must be boolean')
        for field in ('fixture', 'variant', 'selection'):
            if field in case and (type(case[field]) is not str or not case[field]):
                raise EvidenceError(f'{field} must be nonempty text')
        for field in ('fixture', 'x', 'y', 'ticks', 'quiet', 'workers', 'active_neighbour', 'variant', 'repeat'):
            if field not in case:
                continue
            flag = '--' + field.replace('_', '-')
            expected = int(case[field]) if field == 'active_neighbour' else case[field]
            if actual_flags.get(flag) != str(expected):
                raise EvidenceError(f'case {field} differs from its argv')
        item = dict(case)
        if 'expected_workers' not in item and 'workers' in item:
            item['expected_workers'] = item['workers']
        item.setdefault('parity_group', 'physical-' + canonical_sha(config))
        normalized.append(item)
    return normalized


def time_budgets(plan, args):
    result = {}
    for name, field, option, maximum in (
        ('build', 'build_timeout_seconds', 'compile_timeout', 900),
        ('case', 'case_timeout_seconds', 'case_timeout', 60),
        ('campaign', 'campaign_timeout_seconds', 'campaign_timeout', 1800),
    ):
        registered = plan.get(field, maximum)
        if type(registered) is not int or not 1 <= registered <= maximum:
            raise EvidenceError(f'{field} must be integer in 1..{maximum}')
        requested = getattr(args, option, None)
        if requested is not None and (type(requested) is not int or not 1 <= requested <= registered):
            raise EvidenceError(f'{option} cannot exceed registered {registered}-second limit')
        result[name] = registered if requested is None else requested
    return result


def remaining_budget(*deadlines):
    remaining = min(deadlines) - time.monotonic()
    if remaining <= 0:
        raise EvidenceError('registered campaign/build time budget exhausted; unfinished work is unexecuted')
    return remaining


def process(argv, cwd, prefix, timeout, environment=None, *, generated_executable=None,
            artifact_directory=None):
    stdout = Path(str(prefix) + '.stdout')
    stderr = Path(str(prefix) + '.stderr')
    if os.path.lexists(stdout) or os.path.lexists(stderr):
        raise EvidenceError(f'raw output already exists; refusing overwrite for {prefix}')
    started = now()
    begin = time.monotonic()
    result = {'argv': [str(v) for v in argv], 'cwd': str(cwd), 'started_utc': started,
              'timeout_seconds': timeout, 'timed_out': False}
    out = tempfile.NamedTemporaryFile(mode='w+b', dir=stdout.parent, prefix='.' + stdout.name + '.', suffix='.partial', delete=False)
    err = tempfile.NamedTemporaryFile(mode='w+b', dir=stderr.parent, prefix='.' + stderr.name + '.', suffix='.partial', delete=False)
    temporary_stdout, temporary_stderr = Path(out.name), Path(err.name)
    # Partial files intentionally remain discoverable if publication itself fails.
    with out, err:
        if generated_executable is not None:
            repair = restore_generated_executable(Path(argv[0]), generated_executable, artifact_directory)
            if repair is not None:
                result['artifact_mode_repair'] = repair
        try:
            proc = subprocess.Popen(argv, cwd=cwd, stdout=out, stderr=err, env=environment,
                                    start_new_session=(os.name == 'posix'))
            try:
                result['returncode'] = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                result['timed_out'] = True
                try:
                    if os.name == 'posix':
                        os.killpg(proc.pid, signal.SIGKILL)
                    else:
                        proc.kill()
                except ProcessLookupError:
                    pass
                result['returncode'] = proc.wait(timeout=15)
        except OSError as exc:
            result['spawn_error'] = str(exc)
            result['returncode'] = None
        for handle in (out, err):
            handle.flush()
            os.fsync(handle.fileno())
    result['output_publication'] = {
        'stdout': publish_no_replace(temporary_stdout, stdout),
        'stderr': publish_no_replace(temporary_stderr, stderr),
        'flushed_and_fsynced_before_publication': True,
    }
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
    campaign_started = time.monotonic()
    root = args.root.resolve()
    out = output_directory(args.output, root)
    receipt = {'schema': SCHEMA, 'status': 'INITIALIZING', 'started_utc': now(),
               'root': str(root), 'mode': args.mode, 'host': cpu_identity(), 'cases': [], 'build_steps': [],
               'disable_leak_check': bool(getattr(args, 'disable_leak_check', False)), 'artifact_mode_repairs': []}
    receipt_path = out / 'campaign.json'
    write_json(receipt_path, receipt)
    try:
        environment, sanitizer_metadata, leak_check = sanitizer_configuration(
            args.mode, bool(getattr(args, 'disable_leak_check', False)), os.environ)
        receipt['sanitizer_environment'] = sanitizer_metadata
        receipt['leak_check'] = leak_check
        plan = load_json(args.plan)
        cases = validate_plan(plan)
        budgets = time_budgets(plan, args)
        receipt['time_budgets_seconds'] = budgets
        campaign_deadline = campaign_started + budgets['campaign']
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
        if 'accepted_source' in plan:
            accepted = plan['accepted_source']
            if type(accepted) is not str or not re.fullmatch('[0-9a-f]{40}', accepted):
                raise EvidenceError('accepted_source must be a complete commit SHA')
            git(root, 'merge-base', '--is-ancestor', accepted, 'HEAD')
            receipt['accepted_source'] = accepted
            receipt['production_accepted_delta'] = git(root, 'diff', '--name-only', accepted, 'HEAD', '--', 'native/src', 'native/include')
            if receipt['production_accepted_delta']:
                raise EvidenceError('production source differs from the accepted investigation baseline')
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
        build_deadline = time.monotonic() + budgets['build']
        receipt['build_started_utc'] = now()
        version = process([compiler, '--version'], root, out / 'compiler-version',
                          min(30, remaining_budget(build_deadline, campaign_deadline)))
        receipt['compiler_version'] = version
        if version['returncode'] != 0 or version['timed_out']:
            raise EvidenceError('compiler identity command failed')
        flags = compiler_flags(args.mode, os.name) + ['-I' + str(root / 'native/include')] + extra_flags
        receipt['compile_flags'] = flags
        objects = []
        for index, source in enumerate(sources):
            obj = out / (f'input-{index:02d}.obj' if os.name == 'nt' else f'input-{index:02d}.o')
            dep = out / f'input-{index:02d}.d'
            command = [compiler, *flags, '-MMD', '-MF', str(dep), '-c', str(root / source), '-o', str(obj)]
            step = process(command, out, out / f'compile-{index:02d}',
                           remaining_budget(build_deadline, campaign_deadline))
            step['input'] = source
            receipt['build_steps'].append(step)
            write_json(receipt_path, receipt)
            if step['returncode'] != 0 or step['timed_out']:
                raise EvidenceError(f'compile failure retained for {source}')
            objects.append(obj)
        executable = out / ('material_liveness_probe.exe' if os.name == 'nt' else 'material_liveness_probe')
        link = process([compiler, *flags, *(str(obj) for obj in objects), '-o', str(executable)],
                       out, out / 'link', remaining_budget(build_deadline, campaign_deadline))
        receipt['build_steps'].append(link)
        if link['returncode'] != 0 or link['timed_out']:
            raise EvidenceError('link failure retained')
        remaining_budget(build_deadline, campaign_deadline)
        receipt['build_finished_utc'] = now()
        receipt['executable'] = fact(executable)
        receipt['dependency_files'] = [fact(path) for path in sorted(out.glob('input-*.d'))]
        receipt['actual_dependency_inventory'] = actual_dependencies(root, sorted(out.glob('input-*.d')), out)
        if inventory(root, sources, (args.plan,)) != receipt['compiled_input_inventory']:
            raise EvidenceError('source/runtime identity mismatch: inputs changed during build')
        receipt['status'] = 'RUNNING'
        write_json(receipt_path, receipt)
        for case in cases:
            result = process([str(executable), *case['argv']], root, out / case['id'],
                             min(budgets['case'], remaining_budget(campaign_deadline)), environment,
                             generated_executable=receipt['executable'], artifact_directory=out)
            if result.get('artifact_mode_repair'):
                receipt['artifact_mode_repairs'].append({'case_id': case['id'], **result['artifact_mode_repair']})
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
        receipt['final_raw_verification'] = verify_retained_outputs([
            receipt['compiler_version'], *receipt['build_steps'], *receipt['cases']])
        remaining_budget(campaign_deadline)
        receipt['status'] = 'EXECUTED'
    except (EvidenceError, ValueError, OSError, subprocess.SubprocessError) as exc:
        receipt['status'] = 'FAILED'
        receipt['failure'] = str(exc)
    finally:
        receipt['finished_utc'] = now()
        receipt['duration_seconds'] = time.monotonic() - campaign_started
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
    parser.add_argument('--disable-leak-check', action='store_true',
                        help='ASan/UBSan only: explicitly leave LeakSanitizer unexecuted')
    parser.add_argument('--compile-timeout', type=int, help='optional shorter bound for the complete build')
    parser.add_argument('--case-timeout', type=int, help='optional shorter per-process bound')
    parser.add_argument('--campaign-timeout', type=int, help='optional shorter end-to-end campaign bound')
    parser.add_argument('--allow-dirty-apparatus', action='store_true', help='diagnostic execution only; receipt cannot claim source-qualified')
    args = parser.parse_args(argv)
    if args.disable_leak_check and args.mode != 'asan-ubsan':
        parser.error('--disable-leak-check is valid only with --mode asan-ubsan')
    try:
        return run(args)
    except (EvidenceError, OSError) as exc:
        print(f'material liveness: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
