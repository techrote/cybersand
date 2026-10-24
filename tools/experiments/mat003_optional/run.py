"""Bounded untimed optional-tail collector. New output roots only; no retries."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def collect(compiler, output, expected_compiler):
    import psutil
    if psutil.__version__ != '7.0.0':
        raise ValueError('collector requires retained psutil 7.0.0')
    compiler = Path(compiler).resolve()
    if digest(compiler) != expected_compiler:
        raise ValueError('compiler seal mismatch')
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    root = Path(__file__).resolve().parents[3]
    began = time.monotonic()
    registration_path = Path(__file__).with_name('registration.json')
    registration = json.loads(registration_path.read_text())
    result = dict(status='failed', timing=False, validation_class='author-validation-pending-independent-review',
                  registration_sha256=digest(registration_path), compiler_sha256=expected_compiler,
                  commands=[], builds=[], cases=[])
    env = dict(os.environ)
    env['PATH'] = str(compiler.parent) + os.pathsep + env.get('PATH', '')
    env['ASAN_OPTIONS'] = 'detect_leaks=0:halt_on_error=1'
    env['UBSAN_OPTIONS'] = 'halt_on_error=1:print_stacktrace=1'
    result['sanitizer_environment'] = {k: env[k] for k in ('ASAN_OPTIONS', 'UBSAN_OPTIONS')}
    result['sanitizer_limitations'] = 'Windows ASan/UBSan; leak detection disabled, no race detector'

    def command(argv, name, timeout):
        if time.monotonic() - began > registration['limits']['aggregate_seconds']:
            raise ValueError('aggregate watchdog')
        started = time.monotonic()
        stop = None
        peak = 0
        with (output/(name+'.stdout')).open('xb') as out, (output/(name+'.stderr')).open('xb') as err:
            process = subprocess.Popen(list(map(str, argv)), cwd=output, env=env, stdout=out, stderr=err)
            observed = psutil.Process(process.pid)
            while process.poll() is None:
                try:
                    live = [observed, *observed.children(recursive=True)]
                    peak = max(peak, sum(p.memory_info().rss for p in live if p.is_running()))
                except psutil.Error:
                    pass
                if time.monotonic()-started > timeout or time.monotonic()-began > registration['limits']['aggregate_seconds']:
                    stop = 'watchdog'
                if peak > registration['limits']['case_rss_bytes']:
                    stop = 'RSS'
                if stop:
                    try:
                        for child in observed.children(recursive=True): child.kill()
                        observed.kill()
                    except psutil.Error:
                        pass
                    break
                time.sleep(.02)
            code = process.wait()
        receipt = dict(argv=list(map(str, argv)), exit_code=code, stop=stop, sampled_peak_process_tree_rss=peak,
                       elapsed_watchdog_seconds=time.monotonic()-started, timeout_seconds=timeout,
                       stdout_sha256=digest(output/(name+'.stdout')), stderr_sha256=digest(output/(name+'.stderr')))
        (output/(name+'.receipt.json')).write_text(json.dumps(receipt, indent=2)+'\n')
        result['commands'].append(receipt)
        if code or stop or (output/(name+'.stderr')).stat().st_size:
            raise ValueError('command failed: '+name)
        return (output/(name+'.stdout')).read_text()

    try:
        inputs = ['tools/experiments/mat003_optional/fixture.cpp',
                  'tools/experiments/mat003_optional/registration.json',
                  'tools/experiments/mat003_optional/run.py',
                  'native/include/cybersand/precision_storage.hpp', 'native/include/cybersand/material.hpp']
        for relative in inputs:
            target = output/'source'/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root/relative, target)
        result['source_sha256'] = {p: digest(output/'source'/p) for p in inputs}
        result['source_commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        result['compiler_version'] = command([compiler, '--version'], 'compiler-version', 30)
        linker = compiler.with_name('ld.lld.exe' if os.name == 'nt' else 'ld.lld')
        result['linker_sha256'] = digest(linker)
        for sanitized in (False, True):
            for bits in registration['neutral_tail_bits']:
                name = f'tail-{bits}-'+('sanitized' if sanitized else 'normal')
                binary = output/(name+('.exe' if os.name == 'nt' else ''))
                flags = registration['sanitizer_flags' if sanitized else 'normal_flags']
                argv = [compiler, *flags, '--ld-path='+str(linker), f'-DMAT003_TAIL_BITS={bits}',
                        '-I'+str(output/'source/native/include'),
                        output/'source/tools/experiments/mat003_optional/fixture.cpp', '-o', binary]
                command(argv, 'build-'+name, registration['limits']['compile_timeout_seconds'])
                result['builds'].append(dict(bits=bits, sanitized=sanitized, binary=binary.name, sha256=digest(binary)))
        # All four builds seal before the first case; every registered case then runs once.
        for build in result['builds']:
            for side in registration['resident_sides']:
                for mode in registration['states']:
                    label=f"case-{len(result['cases']):03d}"
                    print(label, build['bits'], build['sanitized'], side, mode, flush=True)
                    row=json.loads(command([output/build['binary'], side, mode], label, registration['limits']['case_timeout_seconds']))
                    if (row.get('status')!='passed' or row.get('timing') is not False or
                        (row.get('tail_bits'),row.get('side'),row.get('mode'))!=(build['bits'],side,mode)):
                        raise ValueError('case identity/result mismatch')
                    row['sanitized']=build['sanitized'];row['binary_sha256']=build['sha256']
                    result['cases'].append(row)
        if len(result['cases']) != registration['case_processes']:
            raise ValueError('incomplete process matrix')
        # Same logical payload and operation stream despite different spatial distribution.
        for bits in registration['neutral_tail_bits']:
            for side in registration['resident_sides']:
                accessed=[r for r in result['cases'] if r['tail_bits']==bits and r['side']==side and r['mode'].startswith('accessed-')]
                if len({r['operation_projection_hash'] for r in accessed})!=1:
                    raise ValueError('clustered/dispersed or normal/sanitized logical mismatch')
        result['status']='passed'
    except Exception as error:
        result['error']=str(error)
        raise
    finally:
        result['elapsed_watchdog_seconds']=time.monotonic()-began
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        seals={p.relative_to(output).as_posix():digest(p) for p in output.rglob('*') if p.is_file()}
        (output/'inventory.json').write_text(json.dumps(seals,indent=2)+'\n')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler',type=Path,required=True)
    parser.add_argument('--expected-compiler-sha256',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    collect(args.compiler,args.output,args.expected_compiler_sha256)
