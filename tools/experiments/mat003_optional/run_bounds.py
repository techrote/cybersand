"""Collect only the separately registered, untimed coordinate-refusal regressions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

COMPILER_SHA256 = 'bf58cf0e544a308660645aad1fe65ae9cbc44b0871e4010278f3d9551f86a690'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def collect(compiler, output):
    compiler = compiler.resolve()
    if digest(compiler) != COMPILER_SHA256:
        raise ValueError('unregistered Windows compiler')
    root = Path(__file__).resolve().parents[3]
    spec = json.loads(Path(__file__).with_name('bounds-registration.json').read_bytes())
    output.mkdir(parents=True, exist_ok=False)
    result = dict(status='failed', timing=False, validation_class=spec['validation_class'],
                  source_head=subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
                  source_sha256={}, compiler_sha256=digest(compiler), commands=[], cases=[])
    began = time.monotonic()
    env = dict(os.environ, PATH=str(compiler.parent) + os.pathsep + os.environ.get('PATH', ''),
               ASAN_OPTIONS='detect_leaks=0:halt_on_error=1', UBSAN_OPTIONS='halt_on_error=1:print_stacktrace=1')
    result['sanitizer_environment'] = {k: env[k] for k in ('ASAN_OPTIONS', 'UBSAN_OPTIONS')}
    result['sanitizer_limitations'] = 'Windows ASan/UBSan; leak detection disabled; no race detector'

    def command(argv, label, limit):
        if time.monotonic() - began >= spec['limits']['aggregate_seconds']:
            raise ValueError('aggregate watchdog')
        receipt = dict(argv=list(map(str, argv)), timeout_seconds=limit, exit_code=None, stop=None)
        result['commands'].append(receipt)
        try:
            with (output / (label + '.stdout')).open('xb') as stdout, (output / (label + '.stderr')).open('xb') as stderr:
                process = subprocess.run(receipt['argv'], cwd=output, env=env, stdout=stdout, stderr=stderr,
                                         timeout=min(limit, spec['limits']['aggregate_seconds'] - (time.monotonic() - began)))
                receipt['exit_code'] = process.returncode
        except subprocess.TimeoutExpired:
            receipt['stop'] = 'watchdog'
            raise
        finally:
            for stream in ('stdout', 'stderr'):
                receipt[stream + '_sha256'] = digest(output / (label + '.' + stream))
            (output / (label + '.receipt.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        if receipt['exit_code'] or (output / (label + '.stderr')).stat().st_size:
            raise ValueError('failed or diagnostic invocation: ' + label)
        return (output / (label + '.stdout')).read_text(encoding='utf-8')

    try:
        names = ['tools/experiments/mat003_optional/fixture.cpp', 'tools/experiments/mat003_optional/test_bounds.cpp',
                 'tools/experiments/mat003_optional/bounds-registration.json', 'tools/experiments/mat003_optional/run_bounds.py']
        names += sorted(p.relative_to(root).as_posix() for p in (root / 'native/include').rglob('*.hpp'))
        for name in names:
            source = root / name
            target = output / 'source' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
            result['source_sha256'][name] = digest(source)
        result['compiler_version'] = command([compiler, '--version'], 'compiler-version', 30)
        for bits in spec['profiles']['tail_bits']:
            for profile in spec['profiles']['windows']:
                label = str(bits) + '-' + profile
                binary = output / (label + '.exe')
                flags = ['-O2'] if profile == 'normal' else ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer']
                command([compiler, '-std=c++20', '-Wall', '-Wextra', '-Werror', *flags, f'-DMAT003_TAIL_BITS={bits}',
                         '-I' + str(output / 'source/native/include'), output / 'source/tools/experiments/mat003_optional/test_bounds.cpp',
                         '-o', binary], 'build-' + label, spec['limits']['compile_timeout_seconds'])
                data = json.loads(command([binary], 'case-' + label, spec['limits']['case_timeout_seconds']))
                if (data.get('status'), data.get('timing'), data.get('tail_bits'), data.get('coordinate_refusals')) != ('passed', False, bits, 14):
                    raise ValueError('focused regression result')
                result['cases'].append(dict(profile=profile, binary_sha256=digest(binary), result=data))
        result['status'] = 'passed'
    finally:
        (output / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        inventory = {p.relative_to(output).as_posix(): digest(p) for p in output.rglob('*') if p.is_file()}
        (output / 'inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compiler', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    print(json.dumps(collect(a.compiler, a.output), indent=2))
