#!/usr/bin/env python3
"""Independent actual-Make/compiler controls; synthetic fixtures, not science."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = Path('/workspace/scratch/a3adba76fa99/ci003-soliding')
sys.path.insert(0, str(ROOT / 'tools/ci'))
from test_soliding_build_reuse import SolidingMakeTests
import check_soliding_build_inventory as names

records = []

def control(label, callback):
    case = SolidingMakeTests(methodName='runTest')
    case.setUp()
    start = time.monotonic()
    try:
        detail = callback(case)
        records.append({'control': label, 'status': 'passed', 'seconds': time.monotonic()-start,
                        'detail': detail})
    finally:
        case.doCleanups()

def parallel_profiles(case):
    normal = 'build/test_settled_discovery'
    sanitized = normal + '_sanitized'
    run, commands = case.run_make('-j2', normal, sanitized)
    case.assert_success(run)
    compiled = [row for row in commands if '-c' in row]
    assert len(compiled) == 12
    assert sum('-fsanitize=address,undefined' in row for row in compiled) == 6
    for binary in (normal, sanitized):
        result = subprocess.run([str(case.root / binary)], cwd=case.root,
                                env={**os.environ, 'ASAN_OPTIONS': 'detect_leaks=0'},
                                capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stderr
    run, commands = case.run_make('-j2', normal, sanitized)
    case.assert_success(run)
    assert not any('-o' in row for row in commands)
    return {'core_compilations': len(compiled), 'sanitized_core_compilations': 6,
            'executed_binaries': 2, 'second_build_compilations': 0}

def configuration_recovery(case):
    case.assert_success(case.run_make(case.target)[0])
    path = case.root/'build/soliding-objects/normal/configuration.json'
    path.write_text('{interrupted garbage')
    result, rows = case.run_make(case.target)
    case.assert_success(result)
    assert len(case.compile_sources(rows)) == 6
    json.loads(path.read_text())
    path.unlink()
    result, rows = case.run_make(case.target)
    case.assert_success(result)
    assert len(case.compile_sources(rows)) == 6
    result, rows = case.run_make(case.target, extra_env={'CPATH': str(case.root/'changed-search-path')})
    case.assert_success(result)
    assert len(case.compile_sources(rows)) == 6
    return {'corrupt_configuration_recompiled': 6, 'missing_configuration_recompiled': 6,
            'changed_include_environment_recompiled': 6}

def failure_receipts(case):
    for name in ('soliding_lifecycle', 'settled_regions', 'settled_discovery', 'bounded_ordered_index'):
        (case.root/f'native/include/cybersand/{name}.hpp').write_text('#pragma once\n')
    for index, name in enumerate(names.TESTS):
        linked = name not in names.HEADER_ONLY
        text = '#include <cstdio>\n'
        if linked:
            text += 'int fixture_world();\n'
        text += 'int main() { FILE* f = std::fopen("execution.log", "a"); if (!f) return 99; '
        text += f'std::fputs("{name}\\n", f); std::fclose(f); '
        text += 'return 17;' if index == 1 else ('return fixture_world();' if linked else 'return 0;')
        text += ' }\n'
        (case.root/f'native/tests/test_{name}.cpp').write_text(text)
    result, rows = case.run_make('soliding-test')
    assert result.returncode != 0
    execution = case.root/'execution.log'
    assert execution.read_text().splitlines() == list(names.TESTS[:2])
    execution.unlink()
    result, rows = case.run_make('DEBUG_FLAGS=-O0 -g3 -DREVIEW_FORCE_REBUILD=1',
                                'soliding-test', extra_env={'REUSE_COMPILE_FAIL': 'exit'})
    assert result.returncode != 0
    assert not execution.exists()
    assert not list((case.root/'build/soliding-objects/normal').glob('*.tmp.*'))
    return {'test_exit': 17, 'executions_before_failure': list(names.TESTS[:2]),
            'executions_after_compile_failure': 0, 'partial_object_files': 0}

control('parallel-normal-and-sanitized-profiles', parallel_profiles)
control('corrupt-missing-config-and-environment-change', configuration_recovery)
control('actual-test-and-compiler-failure-propagation', failure_receipts)
report = {'status': 'passed', 'scope': 'Synthetic actual GNU Make/GCC controls; no production scientific qualification',
          'makefile_sha256': hashlib.sha256((ROOT/'Makefile').read_bytes()).hexdigest(), 'controls': records}
output = Path(__file__).with_suffix('.json')
output.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
