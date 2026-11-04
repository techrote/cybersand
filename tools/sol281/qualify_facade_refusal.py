#!/usr/bin/env python3
"""Local exact-source build and pinned 122-case facade qualification.

All artifacts go to a previously absent output directory outside the checkout.
No source files, frozen guards, provenance pointers, workflows or refs are changed.
The unchanged original probe and the separately labelled status-instrumented probe
are distinct execution arms. Neither supplies live Rapier qualification.
"""
import argparse
import ast
import collections
import datetime
import hashlib
import importlib.util
import json
import math
import os
import platform
import shutil
import signal
import subprocess
import sys
import time
import zipfile
from pathlib import Path

sys.dont_write_bytecode = True

SUPPORT_SHA = 'b661a6f354f8c51e79759d22ad4573a875964b43'
PROBE_BLOB = '007dd7250c03a0f10a7f8451506d1a06619dfd04'
MATRIX_BLOB = '88d4f48d7889a270e89b23445d39bea394a5484e'
PROBE_SHA256 = '07fe277d561b4f912cab410cd3f04b34239fbbe0b2fc1819512a252112a420e6'
GODOT_VERSION = '4.7.stable.official.5b4e0cb0f'
BINDINGS_REVISION = '101ae38034304346a46ea9ea84ae156d3e860496'
BUILD_EXACT = {'tools/build_native_extension.sh', 'tools/build_native_extension_windows.sh',
               'tools/verify_pinned_source_tree.py', 'tools/build_pinned_godot_cpp.sh',
               'tools/toolchains/g++', 'tools/ci/execution_policy.py',
               'godot/tests/support/ci_execution_policy.json',
               'godot/addons/cybersand_native/cybersand_native.gdextension',
               'third_party/godot-runtime.lock.json', 'third_party/native-toolchain.lock.json',
               'tools/ci/run_windows_godot_regressions.py',
               'tools/sol281/qualify_facade_refusal.py',
               'tools/sol281/probes/mat_sol_godot_boundary_probe.gd',
               'godot/tests/test_sol_facade_refusals.gd'}
PHASES = {'disabled': 0, 'idle': 1, 'prepared': 2, 'acknowledged': 3,
          'committed': 4, 'restored': 5, 'active': 6, 'cancel': 1,
          'rollback': 1, 'reset': 0}
OPERATIONS = {'physical': 'get_physical_state_hash',
              'liquid1': 'get_liquid_comparison_hash', 'liquid2': 'get_liquid_comparison_hash',
              'window': 'set_simulation_window_enabled',
              'adhesion': 'set_liquid_surface_adhesion_enabled'}
EXTENDED_CASES = set(PHASES) | {'failed_transaction', 'reset_and_masked_fill',
                 'extreme_window', 'pending_liquid_prepared', 'pending_liquid_acknowledged',
                 'failed_world'}


def stamp(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(data): return hashlib.sha256(data).hexdigest()
def info(path):
    path = Path(path); data = path.read_bytes()
    return {'path': str(path), 'sha256': sha(data), 'bytes': len(data)}
def git(source, *args):
    return subprocess.check_output(['git', '-C', str(source), *args])
def blob_sha(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
def exact_blob(source, commit, path):
    return git(source, 'show', commit + ':' + path)
def new_dir(path):
    path = Path(path).resolve()
    if path.exists(): raise ValueError('Refusing existing output directory: ' + str(path))
    path.mkdir(parents=True)
    return path


def snapshot(source, commit):
    source = Path(source).resolve()
    actual = git(source, 'rev-parse', 'HEAD').decode().strip()
    if actual != commit: raise ValueError(f'HEAD differs from requested source: {actual} != {commit}')
    tree = git(source, 'rev-parse', commit + '^{tree}').decode().strip()
    paths = git(source, 'ls-tree', '-r', '--name-only', commit).decode().splitlines()
    selected = [p for p in paths if p.startswith(('native/include/', 'native/src/', 'godot/native_extension/')) or p in BUILD_EXACT]
    records = {}
    for path in selected:
        canonical = exact_blob(source, commit, path)
        actual_bytes = (source / path).read_bytes()
        if canonical != actual_bytes: raise ValueError('Dirty/missing build input: ' + path)
        records[path] = {'git_blob': blob_sha(canonical), 'sha256': sha(canonical), 'bytes': len(canonical)}
    return {'source_commit': commit, 'source_tree': tree, 'source_inputs': records}


def execution_policy(source):
    path = source / 'tools/ci/execution_policy.py'
    spec = importlib.util.spec_from_file_location('facade_execution_policy', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def dependency_snapshot(path, target):
    path = Path(path).resolve()
    revision = git(path, 'rev-parse', 'HEAD').decode().strip()
    if revision != BINDINGS_REVISION: raise ValueError('Wrong godot-cpp revision')
    if git(path, 'status', '--porcelain=v1', '--untracked-files=no').strip():
        raise ValueError('Dirty godot-cpp dependency')
    files = git(path, 'ls-files', '-z').decode().split('\0')
    records = {p: info(path / p) for p in files if p}
    generated = {p.relative_to(path).as_posix(): info(p) for p in sorted((path / 'gen/include').rglob('*')) if p.is_file()}
    # Current builds authenticate the actual library. They do not silently impose
    # or refresh the optional historical M11 product hash.
    library = info(path / f'bin/libgodot-cpp.{target}.template_debug.x86_64.a')
    return {'revision': revision, 'tree': git(path, 'rev-parse', 'HEAD^{tree}').decode().strip(),
            'tracked_files': records, 'generated_headers': generated, 'library': library}


def run_command(command, *, cwd, env, timeout, out, grace=10):
    start = time.monotonic()
    receipt = {'command': [str(x) for x in command], 'cwd': str(cwd), 'started_at': stamp(),
               'timeout_seconds': timeout, 'cleanup_seconds': grace, 'host': platform.platform()}
    with open(out / 'stdout.txt', 'wb') as stdout, open(out / 'stderr.txt', 'wb') as stderr:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stdout, stderr=stderr,
                                   start_new_session=(os.name != 'nt'),
                                   creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == 'nt' else 0)
        receipt['pid'] = process.pid
        try:
            code = process.wait(timeout=timeout)
            receipt.update(exit_code=code, timed_out=False, natural_completion=True)
        except subprocess.TimeoutExpired:
            if os.name != 'nt':
                os.killpg(process.pid, signal.SIGKILL)
            else:
                cleanup = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                    capture_output=True, text=True, timeout=grace)
                receipt['tree_cleanup'] = {'command': cleanup.args, 'exit_code': cleanup.returncode,
                    'stdout': cleanup.stdout, 'stderr': cleanup.stderr}
                if cleanup.returncode and process.poll() is None: process.kill()
            process.wait(timeout=grace)
            receipt.update(exit_code=process.returncode, timed_out=True, natural_completion=False)
    receipt['elapsed_seconds'] = time.monotonic() - start
    receipt['finished_at'] = stamp()
    receipt['stdout'] = info(out / 'stdout.txt')
    receipt['stderr'] = info(out / 'stderr.txt')
    write_json(out / 'command.json', receipt)
    return receipt


def build(args):
    source = args.source.resolve(); out = new_dir(args.output)
    if source in out.parents: raise ValueError('Build outputs must remain outside source checkout')
    before = snapshot(source, args.commit)
    dependency = dependency_snapshot(args.godot_cpp, args.target)
    policy = execution_policy(source)
    timeout = policy.watchdog_seconds('native_compile_seconds')
    compiler = Path(args.compiler).absolute()
    compiler_info = {**info(compiler), 'version': subprocess.check_output([str(compiler), '--version'], text=True)}
    # Preserve the Windows compiler invocation basename: LLVM-MinGW derives its
    # target from that name. Resolving its symlink before invocation is wrong.
    linker = Path(shutil.which('ld')) if args.target == 'linux' else compiler.parent / 'ld.lld'
    linker_info = {**info(linker), 'version': subprocess.check_output([str(linker), '--version'], text=True)}
    runtime_name = 'libcybersand_native.linux.x86_64.so' if args.target == 'linux' else 'cybersand_native.windows.x86_64.dll'
    runtime = out / runtime_name
    write_json(out / 'source-before.json', before)
    write_json(out / 'dependency-before.json', dependency)
    env = os.environ.copy()
    for name in ['CYBERSAND_ALLOW_TOOLCHAIN_DRIFT', 'CYBERSAND_VERIFY_M11_OUTPUT', 'CYBERSAND_DRY_RUN']:
        env.pop(name, None)
    compiler_env = 'LINUX_CXX' if args.target == 'linux' else 'WINDOWS_CXX'
    env.update(GODOT_CPP_ROOT=str(args.godot_cpp.resolve()),
               GODOT_CPP_LIBRARY=dependency['library']['path'],
               CYBERSAND_NATIVE_OUTPUT=str(runtime))
    env[compiler_env] = str(compiler)
    script = 'build_native_extension.sh' if args.target == 'linux' else 'build_native_extension_windows.sh'
    command = ['bash', str(source / 'tools' / script)]
    receipt = run_command(command, cwd=source, env=env, timeout=timeout, out=out,
                          grace=policy.watchdog_seconds('terminate_grace_seconds'))
    errors = []
    try:
        after = snapshot(source, args.commit); write_json(out / 'source-after.json', after)
        if before != after: errors.append('Source identity changed during compilation')
        if dependency_snapshot(args.godot_cpp, args.target) != dependency: errors.append('Dependency changed during compilation')
        if info(compiler)['sha256'] != compiler_info['sha256']: errors.append('Compiler changed during compilation')
        if info(linker)['sha256'] != linker_info['sha256']: errors.append('Linker changed during compilation')
    except Exception as error: errors.append(str(error))
    success = receipt['exit_code'] == 0 and not receipt['timed_out'] and runtime.is_file() and not errors
    result = {'schema': 'sol-facade-fresh-native-build-v1', 'status': 'PASS' if success else 'FAIL',
              'target': args.target, 'policy': policy.identity(),
              **before, 'created_at': stamp(), 'host': platform.platform(), 'runtime': info(runtime) if runtime.is_file() else None,
              'dependency_receipt': info(out / 'dependency-before.json'), 'bindings': dependency['library'],
              'compiler': compiler_info, 'linker': linker_info, 'command_receipt': receipt,
              'runner': info(__file__), 'errors': errors, 'environment': {k: env[k] for k in
                  ['GODOT_CPP_ROOT', 'GODOT_CPP_LIBRARY', compiler_env, 'CYBERSAND_NATIVE_OUTPUT']}}
    write_json(out / 'build.json', result)
    print(json.dumps({'status': result['status'], 'source': args.commit, 'runtime': result['runtime'], 'errors': errors}, indent=2), flush=True)
    return 0 if success else 1


def instrument(original):
    text = original.decode('utf-8')
    replacements = [
        ('\tvar result: Variant\n', '\tvar result: Variant\n\tvar boundary: Dictionary = {}\n'),
        ('\t\t\tresult = world.get_physical_state_hash()\n', '\t\t\tresult = world.get_physical_state_hash()\n\t\t\tboundary = world.get_last_boundary_result()\n'),
        ('\t\t\tresult = world.get_liquid_comparison_hash(1)\n', '\t\t\tresult = world.get_liquid_comparison_hash(1)\n\t\t\tboundary = world.get_last_boundary_result()\n'),
        ('\t\t\tresult = world.get_liquid_comparison_hash(2)\n', '\t\t\tresult = world.get_liquid_comparison_hash(2)\n\t\t\tboundary = world.get_last_boundary_result()\n'),
        ('\t\t\tworld.set_simulation_window_enabled(true)\n', '\t\t\tworld.set_simulation_window_enabled(true)\n\t\t\tboundary = world.get_last_boundary_result()\n'),
        ('\t\t\tworld.set_liquid_surface_adhesion_enabled(not before)\n', '\t\t\tworld.set_liquid_surface_adhesion_enabled(not before)\n\t\t\tboundary = world.get_last_boundary_result()\n'),
        ('"call":call_kind,"result":result}', '"call":call_kind,"result":result,"boundary":boundary}'),
    ]
    for old, new in replacements:
        if text.count(old) != 1: raise ValueError('Probe instrumentation anchor is not unique: ' + old)
        text = text.replace(old, new)
    return text.encode('utf-8')


def verify_engine(source, commit, executable, archive, target, policy):
    lock = json.loads(exact_blob(source, commit, 'third_party/godot-runtime.lock.json'))
    if target == 'windows':
        tree = ast.parse(exact_blob(source, commit, 'tools/ci/run_windows_godot_regressions.py'))
        expected = next(ast.literal_eval(node.value) for node in tree.body
                        if isinstance(node, ast.Assign) and any(isinstance(x, ast.Name)
                        and x.id == 'GODOT_SHA512' for x in node.targets))
        algorithm = 'sha512'
        required = ['Godot_v4.7-stable_win64_console.exe', 'Godot_v4.7-stable_win64.exe']
    else:
        expected, algorithm = lock['editor']['sha256'], 'sha256'
        required = ['Godot_v4.7-stable_linux.x86_64']
    actual = hashlib.new(algorithm, archive.read_bytes()).hexdigest()
    if actual != expected: raise ValueError('Godot archive does not match existing source pin')
    if executable.name != required[0]: raise ValueError('Unexpected Godot executable basename')
    members = {}
    with zipfile.ZipFile(archive) as package:
        if package.testzip() is not None: raise ValueError('Corrupt pinned Godot archive')
        for name in required:
            path = executable.parent / name
            if path.read_bytes() != package.read(name): raise ValueError('Engine differs from pinned archive: ' + name)
            members[name] = info(path)
    version = subprocess.check_output([str(executable), '--version'],
        timeout=policy.watchdog_seconds('operation_seconds'), text=True).strip()
    if version != lock['godot_version'] or version != GODOT_VERSION:
        raise ValueError('Wrong Godot version: ' + version)
    return {'archive': info(archive), 'pinned_archive_algorithm': algorithm,
            'pinned_archive_hash': actual, 'executables': members, 'version': version}


def prepare_execution(args, out, script_name, script_bytes):
    source = args.source.resolve()
    if source in out.parents: raise ValueError('Execution outputs must remain outside source checkout')
    build_receipt = json.loads(args.build_receipt.read_text())
    if build_receipt.get('status') != 'PASS' or build_receipt.get('source_commit') != args.commit:
        raise ValueError('Unqualified or wrong-source runtime build receipt')
    host = {'Linux': 'linux', 'Windows': 'windows'}.get(platform.system())
    if host != build_receipt.get('target'): raise ValueError('This is not the actual runtime target OS')
    current = snapshot(source, args.commit)
    if current['source_inputs'] != build_receipt['source_inputs']:
        raise ValueError('Native/build inputs differ from compiled inputs')
    runtime = (args.runtime or Path(build_receipt['runtime']['path'])).resolve()
    runtime_info = info(runtime)
    if any(runtime_info[k] != build_receipt['runtime'][k] for k in ['sha256', 'bytes']):
        raise ValueError('Runtime differs from source-specific build receipt')
    expected_name = 'libcybersand_native.linux.x86_64.so' if host == 'linux' else 'cybersand_native.windows.x86_64.dll'
    if runtime.name != expected_name: raise ValueError('Wrong runtime filename for target host')
    policy = execution_policy(source)
    engine = args.godot.resolve()
    engine_identity = verify_engine(source, args.commit, engine, args.godot_archive.resolve(), host, policy)
    project = out / 'project'
    (project / 'addons/cybersand_native/bin').mkdir(parents=True)
    (project / '.godot').mkdir()
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="SOL facade qualification"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    script = project / script_name; script.parent.mkdir(parents=True, exist_ok=True)
    script.write_bytes(script_bytes)
    (project / 'addons/cybersand_native/cybersand_native.gdextension').write_bytes(exact_blob(source, args.commit, 'godot/addons/cybersand_native/cybersand_native.gdextension'))
    (project / '.godot/extension_list.cfg').write_text('res://addons/cybersand_native/cybersand_native.gdextension\n')
    installed_runtime = project / 'addons/cybersand_native/bin' / runtime.name
    shutil.copyfile(runtime, installed_runtime)
    if os.name != 'nt':
        import resource
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    env = os.environ.copy(); env['GODOT_SILENCE_ROOT_WARNING'] = '1'
    isolation = [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]
    if os.name == 'nt': isolation += [('APPDATA', 'appdata'), ('LOCALAPPDATA', 'localappdata')]
    for key, name in isolation:
        env[key] = str(out / name); (out / name).mkdir()
    identity = {'schema': 'sol-facade-host-custody-v1', **current, 'target': host, 'host': platform.platform(),
                'created_at': stamp(), 'runtime': runtime_info, 'installed_runtime': info(installed_runtime),
                'build_receipt': info(args.build_receipt), 'engine': engine_identity,
                'installed_probe': info(script), 'runner': info(__file__), 'policy': policy.identity(),
                'qualification': 'Actual target-OS Godot/GDExtension facade; synthetic reservations; no live Rapier',
                'environment': {k: env[k] for k in [*[key for key, _ in isolation], 'GODOT_SILENCE_ROOT_WARNING']}}
    return {'source': source, 'out': out, 'current': current, 'runtime': runtime,
            'installed_runtime': installed_runtime, 'engine': engine, 'project': project,
            'env': env, 'identity': identity, 'policy': policy, 'script': script,
            'script_bytes': script_bytes, 'commit': args.commit}


def finish_integrity(context):
    errors = []
    try:
        if snapshot(context['source'], context['commit']) != context['current']:
            errors.append('Source changed during execution')
        identity = context['identity']
        if info(context['runtime']) != identity['runtime']: errors.append('Input runtime changed')
        if info(context['installed_runtime']) != identity['installed_runtime']: errors.append('Loaded runtime changed')
        for name, expected in identity['engine']['executables'].items():
            if info(context['engine'].parent / name) != expected: errors.append('Editor changed: ' + name)
        if context['script'].read_bytes() != context['script_bytes']: errors.append('Probe changed')
    except Exception as error: errors.append(str(error))
    return errors


def matrix(args):
    started = time.monotonic()
    out = new_dir(args.output)
    old_bytes = args.original_matrix.read_bytes()
    probe = args.probe or args.source / 'tools/sol281/probes/mat_sol_godot_boundary_probe.gd'
    probe_bytes = probe.read_bytes()
    if blob_sha(old_bytes) != MATRIX_BLOB: raise ValueError('Wrong pinned original matrix')
    if blob_sha(probe_bytes) != PROBE_BLOB or sha(probe_bytes) != PROBE_SHA256:
        raise ValueError('Wrong pinned original probe')
    old = json.loads(old_bytes)
    if len(old['records']) != 122: raise ValueError('Wrong original process inventory')
    if any(record['timeout_seconds'] != 30 for record in old['records']):
        raise ValueError('Original retained-apparatus deadline changed')
    installed = instrument(probe_bytes) if args.instrumented else probe_bytes
    context = prepare_execution(args, out, 'probe.gd', installed)
    policy = context['policy']
    budget = args.budget_seconds if args.budget_seconds is not None else policy.watchdog_seconds('native_suite_seconds')
    if not math.isfinite(budget) or budget <= 0:
        raise ValueError('Arm budget must be finite and positive')
    deadline = started + budget
    child_allowance = policy.watchdog_seconds('ordinary_case_seconds')
    grace = policy.watchdog_seconds('terminate_grace_seconds')
    readback_reserve = policy.watchdog_seconds('operation_seconds')
    identity = context['identity']
    identity.update(original_matrix=info(args.original_matrix), pinned_probe=info(probe),
                    instrumented=args.instrumented, support_commit=SUPPORT_SHA,
                    case_deadline={'basis': 'current shared ordinary_case_seconds; no inherited historical short deadline',
                                   'seconds': child_allowance, 'historical_apparatus_seconds': 30},
                    arm_budget_seconds=budget, readback_reserve_seconds=readback_reserve,
                    deadline_policy='Launch only when the full child allowance plus two cleanup allowances and readback reserve fit; otherwise retain NOT_STARTED and fail incomplete.')
    write_json(out / 'identity.json', identity)
    records = []
    for i, original in enumerate(old['records']):
        phase, call, workers = original['phase'], original['call'], original['configured_workers']
        case = out / 'records' / f'{i:03d}-{phase}-{call}-w{workers}'; case.mkdir(parents=True)
        command = [str(context['engine']), '--headless', '--path', str(context['project']), '--script', 'res://probe.gd', '--', phase, call, str(workers)]
        remaining = deadline - time.monotonic()
        if remaining < child_allowance + 2 * grace + readback_reserve:
            rec = {'index': i, 'phase': phase, 'call': call, 'configured_workers': workers,
                   'command': command, 'outcome': 'NOT_STARTED', 'exit_code': None,
                   'reason': 'Complete current-policy child allowance and cleanup/readback reserve do not fit arm budget',
                   'remaining_arm_seconds': remaining, 'timeout_seconds': child_allowance,
                   'historical_timeout_seconds': original['timeout_seconds'],
                   'historical_outcome': original['outcome'], 'historical_result': original['result']}
            records.append(rec); write_json(case / 'record.json', rec)
            continue
        receipt = run_command(command, cwd=out, env=context['env'], timeout=child_allowance, out=case,
                              grace=grace)
        stdout = (case / 'stdout.txt').read_text(errors='replace'); stderr = (case / 'stderr.txt').read_text(errors='replace')
        before = [json.loads(line.split(' ', 1)[1]) for line in stdout.splitlines() if line.startswith('MAT_SOL_BEFORE_CALL ')]
        after = [json.loads(line.split(' ', 1)[1]) for line in stdout.splitlines() if line.startswith('MAT_SOL_AFTER_CALL ')]
        result = after[0]['result'] if len(after) == 1 else None
        boundary = after[0].get('boundary') if len(after) == 1 else None
        if receipt['timed_out']: outcome = 'TIMEOUT'
        elif receipt['exit_code'] != 0: outcome = 'PROCESS_ABORT' if receipt['exit_code'] == -6 else 'PROCESS_FAILURE'
        elif len(after) != 1 or len(before) != 1: outcome = 'APPARATUS_FAILURE'
        elif call == 'export' and isinstance(result, dict) and result.get('bytes') == 0: outcome = 'SAFE_REFUSAL'
        elif call == 'adhesion' and isinstance(result, dict) and not result.get('matches_authority'): outcome = 'AUTHORITY_MISMATCH'
        elif isinstance(boundary, dict) and boundary.get('ok') is False: outcome = 'EXPLICIT_REFUSAL'
        elif original['outcome'] in ['PROCESS_ABORT', 'AUTHORITY_MISMATCH']: outcome = 'RETURNED_REQUIRES_STATUS'
        else: outcome = 'PASS_EXECUTION'
        rec = {'index': i, 'phase': phase, 'call': call, 'configured_workers': workers, **receipt,
               'stdout_text': stdout, 'stderr_text': stderr, 'before_call': before, 'after_call': after,
               'result': result, 'boundary': boundary, 'outcome': outcome,
               'historical_outcome': original['outcome'], 'historical_result': original['result'],
               'historical_timeout_seconds': original['timeout_seconds'],
               'result_matches_historical': result == original['result']}
        records.append(rec); write_json(case / 'record.json', rec)
        if i % 20 == 19: print('completed', i + 1, dict(collections.Counter(x['outcome'] for x in records)), flush=True)
    errors = []
    for r in records:
        i = r['index']
        if r['outcome'] == 'NOT_STARTED':
            errors.append(f'process {i} not started: arm incomplete')
            continue
        if r['exit_code'] != 0 or r['timed_out']: errors.append(f'process {i} failed')
        if len(r['before_call']) != 1 or len(r['after_call']) != 1:
            errors.append(f'process {i} lacks unique before/after markers')
            continue
        before = r['before_call'][0]
        if before.get('native_phase') != PHASES[r['phase']] or before.get('workers') != r['configured_workers'] or before.get('platform') != platform.system():
            errors.append(f'process {i} has wrong actual phase, workers or OS')
        if r['historical_outcome'] in ['PASS_EXECUTION', 'SAFE_REFUSAL'] and not r['result_matches_historical']:
            errors.append(f'control result {i} changed')
        if r['historical_outcome'] == 'AUTHORITY_MISMATCH':
            a = r['result']
            if not isinstance(a, dict) or not a.get('matches_authority') or a.get('reported_after_request') is not True or a.get('applied_from_native_cyps') is not True:
                errors.append(f'authority mismatch {i} persists')
        if args.instrumented and r['call'] in OPERATIONS:
            boundary = r['boundary']
            should_refuse = r['historical_outcome'] in ['PROCESS_ABORT', 'AUTHORITY_MISMATCH']
            if not isinstance(boundary, dict) or boundary.get('ok') is not (not should_refuse):
                errors.append(f'process {i} has no explicit matching public status')
                continue
            if boundary.get('schema') != 'cybersand.public-boundary.v1' or boundary.get('operation') != OPERATIONS[r['call']] or boundary.get('phase') != PHASES[r['phase']]:
                errors.append(f'process {i} has wrong status schema, operation or phase')
            if not isinstance(boundary.get('diagnostic'), str) or not boundary['diagnostic']:
                errors.append(f'process {i} lacks diagnostic')
            if should_refuse:
                if boundary.get('code') != 'native_refusal' or 'value' in boundary:
                    errors.append(f'former failure {i} has ambiguous refusal or value')
                if r['call'] in ['physical', 'liquid1', 'liquid2'] and r['result'] != '':
                    errors.append(f'refused hash {i} fabricated a value')
                if r['call'] == 'window' and r['result'] != {'reported_enabled': False}:
                    errors.append(f'refused window {i} changed enabled state')
            elif r['call'] in ['physical', 'liquid1', 'liquid2'] and boundary.get('value') != r['result']:
                errors.append(f'positive hash {i} differs from explicit result')
    errors += finish_integrity(context)
    summary = {'schema': 'sol-facade-after-matrix-v1', 'source_commit': args.commit,
               'source_tree': context['current']['source_tree'], 'platform': platform.system(),
               'status': 'PASS' if not errors else 'FAIL', 'instrumented': args.instrumented,
               'scope': 'explicit refusal and unchanged controls' if args.instrumented else 'unchanged original probe execution and controls only; status arm remains mandatory',
               'count': len(records), 'executed_count': sum(r['outcome'] != 'NOT_STARTED' for r in records),
               'arm_budget_seconds': budget, 'elapsed_seconds': time.monotonic() - started,
               'counts': dict(collections.Counter(r['outcome'] for r in records)),
               'errors': errors, 'records': records, 'identity_receipt': info(out / 'identity.json'), 'finished_at': stamp()}
    write_json(out / 'matrix.json', summary)
    print(json.dumps({k: v for k, v in summary.items() if k not in ['records', 'identity_receipt']}, indent=2), flush=True)
    return 0 if not errors else 1


def extended(args):
    out = new_dir(args.output)
    path = 'godot/tests/test_sol_facade_refusals.gd'
    script = exact_blob(args.source, args.commit, path)
    context = prepare_execution(args, out, path.removeprefix('godot/'), script)
    write_json(out / 'identity.json', context['identity'])
    records, errors = [], []
    for workers in [1, 4]:
        case = out / f'workers-{workers}'; case.mkdir()
        report_path = case / 'report.json'
        command = [str(context['engine']), '--headless', '--path', str(context['project']), '--script',
                   'res://tests/test_sol_facade_refusals.gd', '--', f'--workers={workers}', f'--report={report_path}']
        receipt = run_command(command, cwd=out, env=context['env'],
                    timeout=context['policy'].watchdog_seconds('ordinary_case_seconds'), out=case,
                    grace=context['policy'].watchdog_seconds('terminate_grace_seconds'))
        report = json.loads(report_path.read_text()) if report_path.is_file() else None
        case_errors = []
        if receipt['exit_code'] != 0 or receipt['timed_out']: case_errors.append('process failed')
        if not isinstance(report, dict): case_errors.append('missing structured report')
        else:
            if report.get('schema') != 'cybersand.sol-facade-refusals.v1' or report.get('platform') != platform.system() or report.get('workers') != workers:
                case_errors.append('wrong report schema, OS or workers')
            if report.get('script_sha256') != sha(script): case_errors.append('wrong self-reported fixture hash')
            if report.get('failures') != [] or report.get('checks', 0) <= 0: case_errors.append('fixture assertions failed or absent')
            cases = report.get('cases', [])
            if len(cases) != len(EXTENDED_CASES) or {r.get('case') for r in cases} != EXTENDED_CASES or report.get('case_count') != len(cases):
                case_errors.append('incomplete or duplicate case inventory')
            if any(r.get('checks', 0) <= 0 or r.get('failures') != [] for r in cases): case_errors.append('incomplete or failing case')
            if report.get('synthetic_body_receipts') is not True or report.get('live_rapier_qualification') is not False:
                case_errors.append('fixture qualification scope mismatch')
        record = {'workers': workers, 'command_receipt': receipt, 'report': report,
                  'report_identity': info(report_path) if report_path.exists() else None, 'errors': case_errors}
        write_json(case / 'result.json', record); records.append(record)
        errors.extend(f'workers {workers}: {error}' for error in case_errors)
    errors += finish_integrity(context)
    summary = {'schema': 'sol-facade-extended-host-v1', 'source_commit': args.commit,
               'source_tree': context['current']['source_tree'], 'platform': platform.system(),
               'status': 'PASS' if not errors else 'FAIL', 'records': records, 'errors': errors,
               'identity_receipt': info(out / 'identity.json'), 'finished_at': stamp()}
    write_json(out / 'extended.json', summary)
    print(json.dumps({'status': summary['status'], 'platform': platform.system(), 'errors': errors,
                      'checks': [r['report'].get('checks') if r['report'] else None for r in records]}, indent=2), flush=True)
    return 0 if not errors else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    build_parser = sub.add_parser('build')
    build_parser.add_argument('--godot-cpp', type=Path, required=True)
    build_parser.add_argument('--compiler', required=True)
    build_parser.add_argument('--target', choices=('linux', 'windows'), required=True)
    matrix_parser = sub.add_parser('matrix')
    matrix_parser.add_argument('--original-matrix', type=Path, required=True)
    matrix_parser.add_argument('--probe', type=Path)
    matrix_parser.add_argument('--instrumented', action='store_true')
    matrix_parser.add_argument('--budget-seconds', type=float,
        help='Overall arm deadline; defaults to shared native_suite_seconds. Child allowances are never shortened.')
    extended_parser = sub.add_parser('extended')
    for child in [matrix_parser, extended_parser]:
        child.add_argument('--build-receipt', type=Path, required=True)
        child.add_argument('--runtime', type=Path)
        child.add_argument('--godot', type=Path, required=True)
        child.add_argument('--godot-archive', type=Path, required=True)
    for child in [build_parser, matrix_parser, extended_parser]:
        child.add_argument('--source', type=Path, required=True)
        child.add_argument('--commit', required=True)
        child.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    return {'build': build, 'matrix': matrix, 'extended': extended}[args.action](args)


if __name__ == '__main__':
    sys.exit(main())
