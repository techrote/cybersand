#!/usr/bin/env python3
"""Finite PR #358 replacement evidence; never the complete hosted merge gates.

Both actual hosts run the seven registered headless fixtures. Linux additionally
runs the unchanged material-render fixture through the qualified palette reader.
Every run requires an independently supplied exact commit, source-matched retained
modules, the pinned official engine archive, and a new evidence directory. Failed
logs and incomplete runs are sealed too; they cannot acquire a passing readback.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'tools/ci'), str(ROOT / 'tools/play')]
import execution_policy as policy
import godot_scheduling as scheduling
import palette_qualification_contract as c
import run_godot_regressions as runner
import run_palette_shader_qualification as palette
import run_timed_command as timed
import run_windows_godot_regressions as windows

SCHEMA = 'paired-material-remediation-v1'
ROLE = 'source-bound paired-material remediation'
SCOPE = ('New focused PR #358 evidence: seven headless authoring, material, physical-host and '
         'WaterFeel fixtures on each actual OS; Linux material pixels and the finite paired '
         'native fixture in normal and ASan/UBSan modes with leak detection. This is not the '
         'complete Native, GDExtension, Issue49 Water or shader gate, a combined #370 '
         'qualification, owner gameplay acceptance, or permission to merge. Historical '
         'native-OpenGL growth-pan and six-pixel diagnostic failures remain separate failures.')
HEADLESS = (
    'test_paired_material_catalogue', 'test_paired_material_playground',
    'test_worldgen_workbench', 'test_microscenario_reference_contract',
    'test_microscenarios', 'test_water_feel_controller', 'test_water_feel_integration',
)
EXTRA_SCOPES = ('tools/experiments', 'tools/lcb', 'docs/reference/liquid-solver-capability-matrix.json')
SCOPES = (*palette.SCOPES, *EXTRA_SCOPES)
REQUIRED = palette.REQUIRED_APPARATUS | {
    'tools/experiments/run_paired_material_remediation.py',
    'tools/experiments/test_paired_material_remediation.py',
    '.github/workflows/paired-materials-remediation.yml',
    'native/tests/paired_materials_main.cpp',
}
NATIVE_SOURCES = ('native/src/world.cpp', 'native/src/material_rules.cpp',
                  'native/src/scheduler_geometry.cpp', 'native/src/settled_world_discovery.cpp',
                  'native/src/render_snapshot.cpp', 'native/tests/test_paired_materials.cpp',
                  'native/tests/paired_materials_main.cpp')
NATIVE_MODES = ('normal', 'asan-ubsan')
NATIVE_PROFILES = {(family, bits) for family in (1, 2, 3, 4) for bits in (3, 8)}
SANITIZER_ENV = ['env', 'ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1',
                 'UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1']
JSON_FOOTERS = {
    'test_paired_material_catalogue': 'PAIRED_MATERIAL_CATALOGUE ',
    'test_paired_material_playground': 'PAIRED_MATERIAL_PLAYGROUND ',
}
COUNT_FOOTERS = {
    'test_worldgen_workbench': 'WORLDGEN_WORKBENCH',
    'test_microscenario_reference_contract': 'MICROSCENARIO_REFERENCE_CONTRACT',
    'test_microscenarios': 'MICROSCENARIOS',
}
TEXT_FOOTERS = {
    'test_water_feel_controller': r'^WATER_FEEL_CONTROLLER: transactional rejection/body collision isolation/desktop\+Web blind lifecycle passed$',
    'test_water_feel_integration': c.SUCCESS['integration'],
}


def case_plan(platform_name: str) -> list[dict]:
    c.require(platform_name in ('linux', 'win32'), 'Only actual Linux/Windows hosts are registered')
    cases = []
    for name in HEADLESS:
        path = ROOT / 'godot/tests' / (name + '.gd')
        text = path.read_text(encoding='utf-8')
        cases.append({'name': name, 'script': path.name, 'rendered': False, 'kind': 'headless',
                      'timeout': math.ceil(policy.case_seconds(name, False,
                          complex_fixture='support/ci_execution_policy.gd' in text))})
    if platform_name == 'linux':
        cases.append(next(case for case in c.plan('linux', 'visual') if case['kind'] == 'material'))
    return cases


def budgets(platform_name: str) -> dict:
    """Two literal hosted jobs; no matrix, fan-out, or shortened child watchdogs."""
    cases = case_plan(platform_name)
    values = policy.identity()['watchdogs']
    minutes = lambda seconds: math.ceil(seconds / 60)
    metadata = minutes(values['operation_seconds'])
    dependency = minutes(3 * values['dependency_prepare_seconds'] + values['operation_seconds']
                         + values['terminate_grace_seconds'])
    display = minutes(values['dependency_prepare_seconds']) if platform_name == 'linux' else 0
    # Checkout, Python, plan/portable controls; Windows also sets checkout EOLs.
    metadata_steps = 4 if platform_name == 'win32' else 3
    readback = minutes(values['godot_metadata_seconds'])
    upload = 2 * metadata
    headroom = minutes(values['aggregate_headroom_seconds'])
    job = math.floor(values['godot_job_minutes'])
    reserved = dependency + display + metadata_steps * metadata + readback + upload + headroom
    execution = min(job - reserved, math.floor(scheduling.execution_seconds() / 60))
    terminal = values['godot_metadata_seconds'] + 2 * values['operation_seconds']
    largest = max(case['timeout'] for case in cases)
    if platform_name == 'linux':
        largest = max(largest, values['native_compile_seconds'], values['native_case_seconds'])
    c.require(0 < job <= 360 and execution > 0 and execution * 60 >=
              scheduling.case_allowance(largest) + values['operation_seconds'] + terminal,
              'Focused host cannot admit the full largest case and final evidence; split scope explicitly')
    return {'job_minutes': job, 'suite_minutes': execution, 'dependency_minutes': dependency,
            'display_minutes': display, 'metadata_step_minutes': metadata, 'metadata_steps': metadata_steps,
            'readback_minutes': readback, 'upload_minutes': upload, 'headroom_minutes': headroom,
            'total_stage_minutes': reserved + execution, 'terminal_reserve_seconds': terminal,
            'max_parallel_hosts': 2, 'cases': len(cases),
            'native_modes': list(NATIVE_MODES) if platform_name == 'linux' else []}


def hosted_plan() -> dict:
    return {'schema': SCHEMA, 'scope': SCOPE, 'max_parallel_hosts': 2,
            'hosts': [{'platform': host, 'budgets': budgets(host), 'cases': case_plan(host)}
                      for host in ('linux', 'win32')]}


def extra_inputs() -> dict:
    paths = palette.git('ls-files', '-z', '--', *EXTRA_SCOPES).decode().split('\0')
    return {name: c.sha(ROOT / name) for name in paths if name}


def reject_untracked_inputs(tracked: set[str]) -> None:
    names = palette.git('ls-files', '--others', '--exclude-standard', '-z', '--', *SCOPES).decode().split('\0')
    # Godot may create UID sidecars for a committed script/shader during import.
    # They are not executable source. No other new source/configuration is admitted.
    unexpected = [name for name in names if name and not
                  (name.endswith(('.gd.uid', '.gdshader.uid')) and name[:-4] in tracked)]
    c.require(not unexpected, 'Uncommitted qualification input(s): ' + ', '.join(unexpected))


def verify_extra_source(directory: Path, report: dict) -> None:
    import palette_checkout_custody as checkout
    with tarfile.open(c.file(directory, 'executed-source.tar'), 'r:') as archive:
        members = {row.name: row for row in archive.getmembers() if row.isfile()}
        names = {name for name in members if any(name == scope or name.startswith(scope + '/')
                                                 for scope in EXTRA_SCOPES)}
        c.require(set(report['extra_source_inputs']) == names and
                  report['extra_source_inputs_after'] == report['extra_source_inputs'],
                  'Missing or changed experiment/LCB/capability source inputs')
        attributes = {name: archive.extractfile(row).read() for name, row in members.items()
                      if name == '.gitattributes' or name.endswith('/.gitattributes')}
        for name in names:
            palette.metadata_remaining()
            data = archive.extractfile(members[name]).read()
            c.require(report['extra_source_inputs'][name] in checkout.allowed_checkout_digests(name, data, attributes),
                      'Extra executed source differs from authenticated checkout: ' + name)
        manifest_name = 'runtime-provenance.json' if report['platform'] == 'win32' else 'runtime-provenance.linux.json'
        manifest = json.loads(archive.extractfile('godot/addons/cybersand_native/' + manifest_name).read())
        native_paths = windows.native_input_paths(ROOT)
        c.require(set(manifest['source_inputs']) == native_paths and
                  report['native_source_inputs'] == manifest['source_inputs'] and
                  type(report['native_source_input_count']) is int and
                  report['native_source_input_count'] == len(native_paths),
                  'Native compile input inventory differs from the retained runtime')
        c.require(REQUIRED.issubset(report['source_inputs'].keys() | report['extra_source_inputs'].keys()),
                  'Focused qualification apparatus was not committed')


def verify_headless_process(process: dict, case: dict, log: str, report: dict) -> None:
    c.require(process.get('role') == ROLE, 'Wrong focused qualification process role')
    # Reuse the existing complete process/argv/watchdog/error/skip reader. Its
    # original shader role is a label, not a different process safety contract.
    registered = dict(process, role='source-bound shader qualification')
    c.verify_process(registered, case, log, report)


def reduce_footer(case: dict, log: str) -> dict:
    name = case['name']
    if name in JSON_FOOTERS:
        value = c.one(log, JSON_FOOTERS[name])
        c.require(type(value.get('checks')) is int and value['checks'] > 0 and
                  type(value.get('failures')) is int and value['failures'] == 0,
                  'Missing checks or nonzero material failures')
        return value
    if name in COUNT_FOOTERS:
        found = re.findall(r'^' + COUNT_FOOTERS[name] + r': ([0-9]+) assertions; ([0-9]+) failures$', log, re.M)
        c.require(len(found) == 1 and int(found[0][0]) > 0 and int(found[0][1]) == 0,
                  'Missing/duplicate/failed authoring completion footer')
        return {'assertions': int(found[0][0]), 'failures': 0}
    c.require(name in TEXT_FOOTERS, 'Unregistered headless fixture')
    found = re.findall(TEXT_FOOTERS[name], log, re.M)
    c.require(len(found) == 1, 'Missing/duplicate WaterFeel completion footer')
    return {'completion': found[0]}


def verify_row(case: dict, row: dict, directory: Path, report: dict) -> dict:
    c.require(row.get('case') == case and row.get('directory') == case['name'] and
              row.get('errors') == [] and row.get('known_processes_exited') is True,
              'Case failed, changed inventory, or did not prove process retirement')
    process = json.loads(c.file(directory, 'process.json').read_text(encoding='utf-8'))
    c.require(c._same(process, row['process']), 'Original focused process receipt changed')
    path = c.file(directory, case['name'] + '.log')
    c.require(c.sha(path) == row.get('log_sha256') == process.get('log_sha256'), 'Original focused process log changed')
    if case['kind'] == 'material':
        return c.verify_case(case, row, directory, report)
    log = path.read_text(encoding='utf-8')
    verify_headless_process(process, case, log, report)
    return reduce_footer(case, log)


def verify_manifest(directory: Path) -> None:
    value = json.loads(c.file(directory, 'manifest.json').read_text(encoding='utf-8'))
    c.require(value.get('schema') == 'palette-qualification-manifest-v1', 'Wrong sealed inventory schema')
    actual = {path.relative_to(directory).as_posix() for path in directory.rglob('*')
              if path.is_file() and path != directory / 'manifest.json'}
    c.require(set(value['files']) == actual, 'Sealed focused artifact inventory differs')
    c.require(not any(path.is_symlink() for path in directory.rglob('*')), 'Focused artifact contains a symlink')
    for name, item in value['files'].items():
        palette.metadata_remaining()
        path = c.file(directory, name)
        c.require(path.stat().st_size == item['bytes'] and c.sha(path) == item['sha256'],
                  'Sealed focused artifact bytes changed: ' + name)


def native_commands(mode: str, report: dict) -> list[list[str]]:
    c.require(mode in NATIVE_MODES and report['platform'] == 'linux', 'Unregistered focused native mode')
    root = PurePosixPath(report['native_output_root'])
    compiler = PurePosixPath(report['native_compiler']['path'])
    c.require(root.is_absolute() and '..' not in root.parts and compiler.is_absolute()
              and compiler.name == 'g++-13', 'Invalid original Linux native host paths')
    binary = str(root / mode / 'paired-materials')
    flags = ['-std=c++20', '-O1', '-g', '-fno-omit-frame-pointer']
    if mode == 'asan-ubsan':
        flags += ['-fsanitize=address,undefined']
    flags += ['-Wall', '-Wextra', '-Wpedantic', '-Wconversion', '-Wshadow', '-pthread', '-Inative/include']
    return [[str(compiler), *flags, *NATIVE_SOURCES, '-o', binary],
            [*SANITIZER_ENV, binary] if mode == 'asan-ubsan' else [binary]]


def reduce_native_log(log: str) -> dict:
    footer = re.findall(r'^PAIR_CURE_001 checks=([0-9]+) failures=0$', log, re.M)
    c.require(len(footer) == 1 and int(footer[0]) > 0, 'Missing/duplicate/failed finite native completion')
    source = (ROOT / 'native/tests/test_paired_materials.cpp').read_text(encoding='utf-8')
    phases = re.findall(r'"PAIR_CURE phase=([^"\\]+)\\n"', source)
    c.require(bool(phases) and re.findall(r'^PAIR_CURE phase=(.+)$', log, re.M) == phases,
              'Finite native fixture phase inventory differs from source')
    c.require(re.search(r'AddressSanitizer|LeakSanitizer|UndefinedBehaviorSanitizer|runtime error:|PAIR_CURE failure:', log) is None,
              'Native log retains a sanitizer or fixture failure')
    workers = []
    for line in log.splitlines():
        if not line.startswith('PAIR_CURE worker-parity '):
            continue
        found = re.fullmatch(r'PAIR_CURE worker-parity family=([1-4]) bits=(3|8) ticks=([0-9]+) capsules=([0-9]+) '
            r'curing_peak=([0-9]+) curing_parallel_ticks=([0-9]+) observed_histogram=([0-9]+(?:,[0-9]+){4}) '
            r'trajectory_sha256=([0-9a-f]{64})', line)
        c.require(found is not None, 'Malformed actual-worker native observation')
        family, bits, ticks, capsules, peak, parallel = map(int, found.groups()[:6])
        histogram = [int(value) for value in found[7].split(',')]
        c.require(ticks > 0 and capsules > 0 and 1 < peak <= 4 and 0 < parallel <= ticks and sum(histogram) == ticks,
                  'Native curing did not observe bounded actual worker participation')
        workers.append({'family': family, 'bits': bits, 'ticks': ticks, 'capsules': capsules,
                        'curing_peak': peak, 'curing_parallel_ticks': parallel,
                        'observed_histogram': histogram, 'trajectory_sha256': found[8]})
    c.require(len(workers) == len(NATIVE_PROFILES) and
              {(row['family'], row['bits']) for row in workers} == NATIVE_PROFILES,
              'Missing/duplicate native model and precision worker-parity observation')
    return {'checks': int(footer[0]), 'failures': 0, 'phases': phases,
            'worker_parity': workers,
            'observations': [line for line in log.splitlines() if line.startswith((
                'PAIR_CURE worker-parity ', 'PAIR_CURE region-resume ', 'PAIR_CURE quarantine ', 'PAIR_CURE bound-sink '))]}


def compare_native_runs(results: list[dict]) -> None:
    c.require(len(results) == len(NATIVE_MODES) and results[0]['checks'] == results[1]['checks'],
              'Normal and sanitized finite native inventories differ')
    trajectories = [{(row['family'], row['bits']): row['trajectory_sha256'] for row in result['worker_parity']}
                    for result in results]
    c.require(set(trajectories[0]) == NATIVE_PROFILES and trajectories[0] == trajectories[1],
              'Normal and sanitized complete-state curing trajectories differ')


def verify_native(directory: Path, report: dict) -> list[dict]:
    expected = list(NATIVE_MODES) if report['platform'] == 'linux' else []
    c.require([row['mode'] for row in report['native_rows']] == expected, 'Incomplete/duplicate focused native mode inventory')
    results = []
    for row in report['native_rows']:
        c.require(row.get('errors') == [] and row.get('completed') is True, 'Focused native mode failed or is incomplete')
        mode = row['mode']; commands = native_commands(mode, report)
        c.require(len(row['commands']) == 2, 'Missing focused compile/run receipt')
        for index, (phase, key) in enumerate((('compile', 'native_compile_seconds'), ('run', 'native_case_seconds'))):
            folder = directory / 'native' / mode / phase
            receipt = json.loads(c.file(folder, 'receipt.json').read_text(encoding='utf-8'))
            log = c.file(folder, 'command.log')
            c.require(c._same(receipt, row['commands'][index]) and receipt.get('schema') == 'execution-command-v1'
                      and receipt.get('label') == 'paired-' + mode + '-' + phase and receipt.get('command') == commands[index],
                      'Original focused native command/receipt changed')
            c.require(receipt.get('complete') is True and receipt.get('status') == 'passed'
                      and type(receipt.get('returncode')) is int and receipt['returncode'] == 0
                      and receipt.get('timed_out') is False and receipt.get('natural_completion') is True
                      and not receipt.get('cleanup_error') and not receipt.get('surviving_descendants')
                      and c._same(receipt.get('execution_policy'), policy.identity())
                      and receipt.get('timeout_seconds') == policy.watchdog_seconds(key)
                      and type(receipt.get('elapsed_seconds')) in (int, float)
                      and 0 <= receipt['elapsed_seconds'] <= policy.watchdog_seconds(key)
                      and receipt.get('source', {}).get('commit') == report['source_commit']
                      and receipt['source'].get('tree') == report['source_tree']
                      and c.sha(log) == receipt.get('log_sha256'), 'Focused native command did not pass naturally with exact source and policy')
        binary = c.file(directory / 'native' / mode, 'paired-materials')
        c.require(binary.read_bytes().startswith(b'\x7fELF') and row.get('binary') ==
                  {'sha256': c.sha(binary), 'bytes': binary.stat().st_size}, 'Focused native executable changed')
        reduced = reduce_native_log((directory / 'native' / mode / 'run/command.log').read_text(encoding='utf-8'))
        c.require(c._same(reduced, row.get('readback')), 'Independent native reduction differs')
        results.append({'mode': mode, **reduced})
    if results:
        compare_native_runs(results)
    return results


def execute_native(output: Path, report: dict, budget: scheduling.ExecutionBudget, save) -> None:
    if report['platform'] != 'linux':
        return
    for mode in NATIVE_MODES:
        row = {'mode': mode, 'commands': [], 'errors': [], 'completed': False}
        report['native_rows'].append(row)
        directory = output / 'native' / mode; directory.mkdir(parents=True)
        try:
            commands = native_commands(mode, report)
            for index, (phase, key) in enumerate((('compile', 'native_compile_seconds'), ('run', 'native_case_seconds'))):
                timeout = policy.watchdog_seconds(key)
                admission = budget.admission(timeout + policy.watchdog_seconds('operation_seconds'))
                c.require(admission['admitted'], 'Remaining host budget cannot admit full native ' + phase)
                row[phase + '_admission'] = admission; save()
                receipt = timed.run(commands[index], timeout_seconds=timeout,
                    label='paired-' + mode + '-' + phase, output_dir=directory / phase, root=ROOT)
                row['commands'].append(receipt); save()
                c.require(receipt.get('status') == 'passed', 'Native ' + mode + ' ' + phase + ' failed: ' + receipt.get('status', 'missing status'))
            with palette.metadata_budget('focused native result: ' + mode):
                binary = directory / 'paired-materials'
                row['binary'] = {'sha256': c.sha(binary), 'bytes': binary.stat().st_size}
                row['readback'] = reduce_native_log((directory / 'run/command.log').read_text(encoding='utf-8'))
                row['completed'] = True
        except Exception as error:
            row['errors'].append(f'{type(error).__name__}: {error}')
            report['errors'].append('native ' + mode + ': ' + row['errors'][-1])
            if row['commands'] and row['commands'][-1].get('status') in ('cleanup_failed', 'interrupted'):
                raise RuntimeError('Native process cleanup unproved; remaining fixtures unexecuted') from error
        finally:
            save()


def verify_directory(directory: Path, source: str, *, sealed: bool = True) -> dict:
    with palette.metadata_budget('focused independent evidence readback', policy.watchdog_seconds('godot_metadata_seconds')):
        c.require(not directory.is_symlink(), 'Focused evidence directory is a symlink')
        if sealed:
            verify_manifest(directory)
        report = json.loads(c.file(directory, 'qualification.json').read_text(encoding='utf-8'))
        c.require(report.get('schema') == SCHEMA and report.get('scope') == SCOPE and
                  report.get('completed') is True and report.get('errors') == [] and
                  report.get('source_unchanged') is True and
                  (not sealed or report.get('status') == 'passed'),
                  'Focused qualification failed, is incomplete, or changed source')
        c.require(report.get('python_packages') == dict(item.split('==') for item in c.PYTHON_PACKAGES),
                  'Focused pixel reader package identity differs')
        palette.verify_source(directory, report, source)
        verify_extra_source(directory, report)
        native = verify_native(directory, report)
        expected = case_plan(report['platform'])
        c.require(report['case_plan'] == expected and [row['case'] for row in report['rows']] == expected and
                  report['budgets'] == budgets(report['platform']), 'Incomplete/duplicate or changed focused case plan')
        imported = report['import']
        log = c.file(directory, 'import.log')
        original = json.loads(c.file(directory, 'import-process.json').read_text(encoding='utf-8'))
        c.require(c._same(original, imported) and c.sha(log) == report['import_log_sha256'] == imported['log_sha256']
                  and report.get('import_process_exited') is True, 'Original import receipt/log changed or process survived')
        verify_headless_process(imported, {'name': 'import', 'rendered': False,
            'timeout': policy.watchdog_seconds('godot_import_seconds')}, log.read_text(encoding='utf-8'), report)
        summaries = []
        for case, row in zip(expected, report['rows']):
            reduced = verify_row(case, row, directory / case['name'], report)
            c.require(c._same(reduced, row.get('readback')), 'Independent focused reduction differs from original result')
            summaries.append({'name': case['name'], 'readback': reduced})
        return {'schema': 'paired-material-remediation-readback-v1', 'source_commit': source,
                'platform': report['platform'], 'status': 'passed', 'cases': summaries, 'native': native, 'scope': SCOPE}


def execute(output: Path, source: str, archive: Path) -> int:
    c.require(sys.platform in ('linux', 'win32'), 'Focused execution requires actual Linux or Windows')
    c.require(re.fullmatch('[0-9a-f]{40}', source) is not None, 'An exact independently expected source SHA is required')
    output.mkdir(parents=True, exist_ok=False)
    report = {'schema': SCHEMA, 'scope': SCOPE, 'source_commit': source, 'platform': sys.platform,
              'group': 'paired-remediation', 'status': 'incomplete', 'completed': False,
              'errors': [], 'rows': [], 'native_rows': [], 'case_plan': case_plan(sys.platform),
              'budgets': budgets(sys.platform), 'execution_policy': policy.identity(),
              'run_id': os.getenv('GITHUB_RUN_ID'), 'run_attempt': os.getenv('GITHUB_RUN_ATTEMPT')}
    budget = scheduling.ExecutionBudget(report['budgets']['suite_minutes'] * 60)
    budget.terminal_reserve = report['budgets']['terminal_reserve_seconds']
    report['admission_policy'] = budget.metadata()
    before = {}; extra_before = {}

    def save():
        c.write(output / 'qualification.json', report)

    def admit(case: dict, *, prepare: bool = True) -> dict:
        # Include case preparation separately while retaining the full original
        # process watchdog, cleanup, readback and terminal evidence reserve.
        allowance = case['timeout'] + (policy.watchdog_seconds('operation_seconds') if prepare else 0)
        value = budget.admission(allowance)
        c.require(value['admitted'], 'Remaining host allowance cannot admit full case: ' + case['name'])
        return value

    save()
    try:
        with palette.metadata_budget('focused source/runtime preflight'):
            c.require(palette.git('rev-parse', 'HEAD').decode().strip() == source, 'Execution checkout differs from expected source')
            palette.git('diff', '--exit-code', 'HEAD', '--', *SCOPES, ':!godot/.godot')
            before = palette.source_inputs(); extra_before = extra_inputs()
            c.require(REQUIRED.issubset(before.keys() | extra_before.keys()), 'Commit all qualification apparatus before execution')
            reject_untracked_inputs(before.keys() | extra_before.keys())
            report.update(source_tree=palette.git('rev-parse', 'HEAD^{tree}').decode().strip(),
                          source_inputs=before, extra_source_inputs=extra_before)
            report['runtimes'] = {}
            for name in palette.runtime_paths(sys.platform):
                data = (ROOT / name).read_bytes()
                c.require(data.startswith(b'MZ' if sys.platform == 'win32' else b'\x7fELF'), 'Unmaterialized retained runtime: ' + name)
                report['runtimes'][name] = {'sha256': c.sha(ROOT / name), 'bytes': len(data)}
            manifest_name = 'runtime-provenance.json' if sys.platform == 'win32' else 'runtime-provenance.linux.json'
            native = json.loads((ROOT / 'godot/addons/cybersand_native' / manifest_name).read_text(encoding='utf-8'))
            from check_repository import verify_runtime, verify_rapier_overrides
            c.require(set(native['source_inputs']) == windows.native_input_paths(ROOT) and
                      not verify_runtime(ROOT, native), 'Retained native module requires a source-matched rebuild')
            c.require(not verify_rapier_overrides(ROOT, json.loads((ROOT / 'godot/third_party/rapier2d.lock.json').read_text())),
                      'Selected Rapier runtime provenance mismatch')
            report.update(native_source_inputs=native['source_inputs'], native_source_input_count=len(native['source_inputs']))
            if sys.platform == 'win32':
                c.require(not archive.with_suffix('').exists(), 'Refusing reused Windows engine extraction directory')
                with windows.metadata_budget():
                    report['windows_runtime_receipt'] = windows.verify_retained_runtime(ROOT)
                    binary, report['engine'] = windows.prepare_godot(archive)
            else:
                binary, report['engine'] = palette.prepare_engine(archive, 'linux')
            report['host_paths'] = {'source_root': str(ROOT.resolve()), 'project_root': str((ROOT / 'godot').resolve()),
                'launcher': str(binary.resolve()), 'engine': str((binary.parent / 'Godot_v4.7-stable_win64.exe').resolve())
                if sys.platform == 'win32' else str(binary.resolve())}
            report['python_packages'] = {item.split('==')[0]: importlib.metadata.version(item.split('==')[0])
                                         for item in c.PYTHON_PACKAGES}
            code = (ROOT / c.PALETTE).read_bytes()
            report['shader_hashes'] = {'full_crossfade': hashlib.sha256(code).hexdigest(),
                                      'angle_bounded_crossfade': hashlib.sha256(c.BOUNDED + code).hexdigest()}
            sources = output / 'source-inputs'; sources.mkdir()
            (sources / 'candidate-full.gdshader').write_bytes(code)
            (sources / 'candidate-bounded.gdshader').write_bytes(c.BOUNDED + code)
            report['source_archive_sha256'] = palette.export_source(output / 'executed-source.tar', source)
            if sys.platform == 'linux':
                compiler = shutil.which('g++-13')
                c.require(compiler is not None, 'The hosted GNU C++ 13 compiler is unavailable')
                report['native_compiler'] = {'path': compiler, 'sha256': c.sha(Path(compiler)),
                    'version': subprocess.check_output([compiler, '--version'], text=True, timeout=palette.metadata_remaining())}
                report['native_output_root'] = str(output / 'native')
            save(); palette.verify_source(output, report, source)
            environment = os.environ | {'CYBERSAND_SOURCE_REVISION': source, 'GODOT_SILENCE_ROOT_WARNING': '1'}
            import_environment = environment | palette.cache_environment(output / 'import-cache')
        execute_native(output, report, budget, save)
        imported_case = {'name': 'import', 'rendered': False, 'timeout': policy.watchdog_seconds('godot_import_seconds')}
        report['import_admission'] = admit(imported_case, prepare=False)
        imported, failed = runner.run_case(str(binary), runner.Case('import', ('--editor', '--quit'),
            imported_case['timeout'], 0), output, ROLE, env=import_environment)
        with palette.metadata_budget('focused import receipt'):
            report['import'] = imported; c.write(output / 'import-process.json', imported)
            report['import_log_sha256'] = c.sha(output / 'import.log')
            report['import_process_exited'] = palette.pid_exited(imported.get('pid'))
            save()
            verify_headless_process(imported, imported_case, (output / 'import.log').read_text(encoding='utf-8'), report)
            c.require(not failed and report['import_process_exited'], 'Import did not pass and retire naturally')
        for case in report['case_plan']:
            admission = admit(case)
            with palette.metadata_budget('focused case preparation: ' + case['name']):
                directory = output / case['name']; directory.mkdir()
                cache_root = directory / 'cache'
                nonce = uuid.uuid4().hex
                env = environment | palette.cache_environment(cache_root)
                if case['rendered']:
                    captures = directory / 'captures'; captures.mkdir()
                    env |= {'CYBERSAND_SHADER_NONCE': nonce, 'CYBERSAND_SHADER_CACHE_STATE': case['cache'],
                            'CYBERSAND_SHADER_CAPTURE': str(captures), 'CYBERSAND_PRESENTATION_EVIDENCE': str(captures)}
                engine_case = runner.Case(case['name'], ('--rendering-driver', 'opengl3', '--script',
                    'res://tests/' + case['script']), case['timeout'], 0, case['rendered'])
            process, failed = runner.run_case(str(binary), engine_case, directory,
                'source-bound shader qualification' if case['rendered'] else ROLE, env=env)
            with palette.metadata_budget('focused case readback: ' + case['name']):
                c.write(directory / 'process.json', process)
                row = {'case': case, 'directory': case['name'], 'process': process, 'admission': admission,
                       'nonce': nonce, 'cache_root': str(cache_root), 'errors': [],
                       'log_sha256': c.sha(directory / process['log']),
                       'known_processes_exited': palette.pid_exited(process.get('pid'))}
                report['rows'].append(row)
                try:
                    row['readback'] = verify_row(case, row, directory, report)
                    c.require(not failed, 'Shared strict process runner rejected the fixture')
                except Exception as error:
                    row['errors'].append(f'{type(error).__name__}: {error}')
                    report['errors'].append(case['name'] + ': ' + row['errors'][-1])
                save()
            print(json.dumps({'case': case['name'], 'status': process['status'], 'errors': row['errors']}), flush=True)
            if not row['known_processes_exited']:
                report['errors'].append('Process retirement unproved; remaining cases unexecuted')
                break
        report['completed'] = (len(report['rows']) == len(report['case_plan']) and
                               all(row['completed'] for row in report['native_rows']))
    except Exception as error:
        report['errors'].append(f'{type(error).__name__}: {error}')
    finally:
        try:
            with palette.metadata_budget('focused source postflight'):
                c.require(palette.git('rev-parse', 'HEAD').decode().strip() == source, 'Source checkout changed during execution')
                report['source_inputs_after'] = palette.source_inputs()
                report['extra_source_inputs_after'] = extra_inputs()
                report['permitted_import_rewrites'] = palette.source_rewrites(before, report['source_inputs_after'], output / 'executed-source.tar')
                c.require(bool(extra_before) and extra_before == report['extra_source_inputs_after'], 'Extra qualification inputs changed')
                reject_untracked_inputs(before.keys() | extra_before.keys())
                report['source_unchanged'] = bool(before)
        except Exception as error:
            report['source_unchanged'] = False
            report['errors'].append('Final source custody: ' + str(error))
        save()
    try:
        result = verify_directory(output, source, sealed=False)
        report['status'] = 'passed'; c.write(output / 'readback.json', result)
    except Exception as error:
        report['status'] = 'failed'; report['errors'].append('Final readback: ' + str(error))
    try:
        with palette.metadata_budget('focused original evidence seal'):
            save(); palette.seal(output)
    except Exception as error:
        report['status'] = 'failed'; report['errors'].append('Artifact seal: ' + str(error)); save()
    print('PAIRED_MATERIAL_REMEDIATION ' + json.dumps({key: report[key] for key in ('status', 'completed', 'errors')}))
    return 0 if report['status'] == 'passed' else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-source-sha')
    parser.add_argument('--godot-archive', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--plan-json', action='store_true')
    parser.add_argument('--prepare-dependencies', action='store_true')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    if args.plan_json:
        print(json.dumps(hosted_plan(), sort_keys=True)); return 0
    c.require(args.output is not None and args.expected_source_sha is not None, 'Expected source and new output directory required')
    c.require(not args.output.is_symlink(), 'Evidence output is a symlink')
    if args.verify_only:
        value = verify_directory(args.output.absolute(), args.expected_source_sha)
        print(json.dumps(value, sort_keys=True)); return 0
    c.require(args.godot_archive is not None, 'Pinned official Godot archive required')
    if args.prepare_dependencies:
        return palette.prepare_dependencies(args.output.resolve(), args.expected_source_sha, args.godot_archive.resolve())
    return execute(args.output.resolve(), args.expected_source_sha, args.godot_archive.resolve())


if __name__ == '__main__':
    raise SystemExit(main())
