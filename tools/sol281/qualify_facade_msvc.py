#!/usr/bin/env python3
"""Source-bound actual Windows/MSVC checks for the dependent facade repair.

This runs four existing native test executables. It does not run or publish the
SOL281 physics campaign. The standalone soliding lifecycle model is labelled
separately from actual native World and Godot/Rapier execution.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
import qualify_facade_refusal as facade

CORE = (
    'native/src/world.cpp', 'native/src/material_rules.cpp',
    'native/src/scheduler_geometry.cpp', 'native/src/settled_world_discovery.cpp',
    'native/src/render_snapshot.cpp', 'native/src/c_api.cpp',
)
CASES = (
    ('solid_detachment', True, r'SOL-DETACH-001 A1 native precursor: (9) groups, ([1-9][0-9]*) checks passed\.'),
    ('conservative_displacement', True, r'CONSERVATIVE-DISPLACEMENT native: (6) groups, ([1-9][0-9]*) checks passed\.'),
    ('solid_contact_geometry', False, r'SOL281_CONTACT_GEOMETRY (6) groups / ([1-9][0-9]*) checks passed'),
    ('soliding_lifecycle', False, r'PASS soliding lifecycle model: 384 complete transitions, 12 prepare/ack/commit guard refusals, 8 finalize quarantine guards'),
)
EXTRA = ('tools/sol281/qualify_facade_msvc.py', '.github/workflows/sol-facade-refusal.yml',
         *(f'native/tests/test_{name}.cpp' for name, _, _ in CASES))


def source_snapshot(source: Path, commit: str) -> dict:
    result = facade.snapshot(source, commit)
    for path in EXTRA:
        canonical = facade.exact_blob(source, commit, path)
        actual = (source / path).read_bytes()
        if canonical != actual:
            raise ValueError('Changed native qualification input: ' + path)
        result['source_inputs'][path] = {'git_blob': facade.blob_sha(canonical),
            'sha256': facade.sha(canonical), 'bytes': len(canonical)}
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--compiler', default='cl')
    args = parser.parse_args()
    if platform.system() != 'Windows':
        parser.error('Requires actual Windows/MSVC; a cross-build or emulation is not execution evidence')
    started = time.monotonic()
    source = args.source.resolve()
    output = facade.new_dir(args.output)
    if source in output.parents:
        raise ValueError('Output must be outside the source checkout')
    before = source_snapshot(source, args.commit)
    facade.write_json(output / 'source-before.json', before)
    policy = facade.execution_policy(source)
    budget = policy.watchdog_seconds('native_suite_seconds')
    deadline = started + budget
    grace = policy.watchdog_seconds('terminate_grace_seconds')
    readback = policy.watchdog_seconds('operation_seconds')
    compiler = Path(shutil.which(args.compiler) or args.compiler).absolute()
    linker = compiler.parent / 'link.exe'
    tools = {'compiler': facade.info(compiler), 'linker': facade.info(linker),
             'python': {**facade.info(sys.executable), 'version': sys.version}}
    env = os.environ.copy()
    # Explicit flags below must not be prefixed/suffixed by ambient CL/LINK flags.
    for key in ('CL', '_CL_', 'LINK', '_LINK_'):
        env.pop(key, None)
    env['VSLANG'] = '1033'
    identification = output / 'compiler-identification'; identification.mkdir()
    identity_receipt = facade.run_command([str(compiler), '/Bv'], cwd=output, env=env,
        timeout=policy.watchdog_seconds('operation_seconds'), grace=grace, out=identification)
    version = (identification / 'stdout.txt').read_text(errors='replace') + (identification / 'stderr.txt').read_text(errors='replace')
    if identity_receipt['timed_out'] or 'Microsoft (R) C/C++ Optimizing Compiler' not in version:
        raise ValueError('Actual Microsoft C++ compiler was not identified')
    # /Bv without a translation unit may return 2. This receipt is identification,
    # never a passing compilation. Every compile/run below must return zero.
    tools['compiler']['version_diagnostic'] = version
    tools['compiler']['identification_receipt'] = identity_receipt
    identity = {'schema': 'sol-facade-msvc-identity-v1', **before, 'host': platform.platform(),
        'platform': platform.system(), 'tools': tools, 'policy': policy.identity(),
        'run_id': os.environ.get('GITHUB_RUN_ID'), 'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT'),
        'runner': {key: os.environ.get(key) for key in ('RUNNER_OS', 'RUNNER_ARCH', 'ImageOS', 'ImageVersion')},
        'msvc_environment': {key: env.get(key) for key in ('VCToolsVersion', 'WindowsSDKVersion',
            'VSCMD_ARG_TGT_ARCH', 'VSCMD_ARG_HOST_ARCH', 'VSCMD_VER', 'VSLANG')},
        'suite_budget_seconds': budget, 'created_at': facade.stamp()}
    facade.write_json(output / 'identity.json', identity)
    records, errors = [], []

    def command(name: str, argv: list[str], allowance: float) -> dict:
        directory = output / name
        directory.mkdir(parents=True)
        remaining = deadline - time.monotonic()
        if remaining < allowance + 2 * grace + readback:
            receipt = {'status': 'NOT_STARTED', 'command': argv, 'exit_code': None,
                'remaining_suite_seconds': remaining, 'timeout_seconds': allowance,
                'reason': 'Full shared command allowance plus cleanup/readback reserve does not fit'}
            facade.write_json(directory / 'command.json', receipt)
        else:
            receipt = facade.run_command(argv, cwd=directory, env=env, timeout=allowance,
                                          grace=grace, out=directory)
            receipt['status'] = 'PASS' if receipt['exit_code'] == 0 and not receipt['timed_out'] else 'FAIL'
            facade.write_json(directory / 'command.json', receipt)
        records.append({'name': name, **receipt})
        return receipt

    common = ['/std:c++20', '/EHsc', '/W4', '/Od', '/Zi', '/Bv', '/I' + str(source / 'native/include')]
    core_dir = output / 'core-objects'; core_dir.mkdir()
    core_command = [str(compiler), *common, '/c', '/Fo:' + str(core_dir) + os.sep,
                    '/Fd:' + str(core_dir / 'core.pdb'), *(str(source / path) for path in CORE)]
    core = command('compile-core', core_command, policy.watchdog_seconds('native_compile_seconds'))
    objects = [core_dir / (Path(path).stem + '.obj') for path in CORE]
    core_ready = core['status'] == 'PASS' and all(path.is_file() for path in objects)
    if not core_ready:
        errors.append('Shared native core did not compile completely')
    else:
        facade.write_json(output / 'core-object-identities.json', [facade.info(path) for path in objects])
    results = []
    for name, needs_core, success_pattern in CASES:
        binary_dir = output / 'binaries' / name; binary_dir.mkdir(parents=True)
        binary = binary_dir / f'test_{name}.exe'
        result = {'case': name, 'kind': 'standalone lifecycle model' if name == 'soliding_lifecycle' else 'native executable',
                  'status': 'NOT_STARTED', 'binary': None}
        if needs_core and not core_ready:
            result['reason'] = 'Shared core build did not succeed'
            results.append(result)
            continue
        argv = [str(compiler), *common, '/Fo:' + str(binary_dir) + os.sep,
                '/Fd:' + str(binary_dir / 'case.pdb'), str(source / f'native/tests/test_{name}.cpp'),
                *(str(path) for path in objects if needs_core), '/Fe:' + str(binary)]
        compiled = command(f'{name}/compile', argv, policy.watchdog_seconds('native_compile_seconds'))
        result['compile'] = compiled
        if compiled['status'] != 'PASS' or not binary.is_file():
            errors.append(name + ': compile failed or incomplete')
            results.append(result)
            continue
        result['binary'] = facade.info(binary)
        executed = command(f'{name}/run', [str(binary)], policy.watchdog_seconds('native_case_seconds'))
        result['execution'] = executed
        stdout_path = output / name / 'run/stdout.txt'
        stdout = stdout_path.read_text(errors='replace') if stdout_path.exists() else ''
        matches = re.findall(success_pattern, stdout)
        passed = executed['status'] == 'PASS' and len(matches) == 1
        result['status'] = 'PASS' if passed else 'FAIL'
        result['success_summary'] = matches
        if not passed: errors.append(name + ': run failed, incomplete or missing unique complete-case summary')
        if facade.info(binary) != result['binary']: errors.append(name + ': executable changed during execution')
        results.append(result)
    try:
        after = source_snapshot(source, args.commit)
        facade.write_json(output / 'source-after.json', after)
        if before != after: errors.append('Source changed during qualification')
        for key, path in [('compiler', compiler), ('linker', linker), ('python', Path(sys.executable))]:
            if facade.info(path)['sha256'] != tools[key]['sha256']: errors.append(key + ' bytes changed')
    except Exception as error:
        errors.append(str(error))
    if len(results) != 4 or any(r['status'] != 'PASS' for r in results):
        errors.append('Four-case native inventory incomplete or failing')
    summary = {'schema': 'sol-facade-msvc-native-v1', **before, 'platform': 'Windows',
        'status': 'PASS' if not errors else 'FAIL', 'results': results, 'errors': errors,
        'commands': records, 'identity_receipt': facade.info(output / 'identity.json'),
        'elapsed_seconds': time.monotonic() - started, 'finished_at': facade.stamp(),
        'qualification': 'Actual MSVC compile/run of three native test executables and a separately labelled lifecycle model; no Godot, Rapier or physical-clearance acceptance'}
    facade.write_json(output / 'qualification.json', summary)
    print(json.dumps({'status': summary['status'], 'errors': errors,
                      'cases': [{k: v for k, v in r.items() if k in ('case', 'status', 'success_summary')} for r in results]}, indent=2))
    return 0 if not errors else 1


if __name__ == '__main__':
    sys.exit(main())
