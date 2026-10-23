"""Independent C128 readback. Imports no collector/overlay implementation.

The accepted S2A result contract is reused only after its bytes are Git-anchored.
No timing is executed or admitted here. All source and evidence reads are inert.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import re
import statistics
import subprocess
import sys

BASE = '2b2a1dd64f16dc46d5e812b757de73f47df0fb2b'
S2P_SOURCE = 'd67e00ce53a200c76726d25b98cac8047000f4aa'
HERE = 'tools/experiments/mat003_c128'
SOURCE_PATHS = ['native/include', 'native/src'] + [
    'tools/experiments/' + name for name in
    ('mat003_prepass', 'mat003_s2a', 'mat003_continuation', 'mat003_s2p', 'mat003_c128')]
FLAGS = ['-std=c++20', '-O2', '-DNDEBUG', '-Wall', '-Wextra', '-Wpedantic', '-pthread']
ARMS = [
    dict(id='C80-E8-aligned', representation='aligned', extra_bytes=2, stride=16, alignment=8),
    dict(id='C128-E8-u128', representation='u128', extra_bytes=2, stride=16, alignment=16),
    dict(id='C128-E8-dual64', representation='dual64', extra_bytes=2, stride=16, alignment=8)]
ANCHORS = [dict(id='active-512-w4', side=512, workers=4, scenario='active'),
           dict(id='quiet-2048-w1', side=2048, workers=1, scenario='quiet')]
CONTRASTS = [dict(anchor='active-512-w4', a='C80-E8-aligned', b='C128-E8-u128'),
             dict(anchor='active-512-w4', a='C80-E8-aligned', b='C128-E8-dual64'),
             dict(anchor='quiet-2048-w1', a='C80-E8-aligned', b='C128-E8-u128'),
             dict(anchor='quiet-2048-w1', a='C80-E8-aligned', b='C128-E8-dual64'),
             dict(anchor='active-512-w4', a='C128-E8-dual64', b='C128-E8-u128')]
ORDERS = ['AB', 'BA', 'AB', 'BA', 'AB', 'BA', 'AB']
SEMANTIC_FIELDS = (
    'scenario', 'side', 'workers_configured', 'seed', 'warmup_ticks', 'sample_ticks',
    'completed_ticks', 'resident_cells', 'chunk_count', 'positive_visit_ticks',
    'warmup_input_calls', 'sample_input_calls', 'warmup_water_added',
    'warmup_water_removed', 'sample_water_added', 'sample_water_removed',
    'initial_water_mass', 'final_water_mass', 'content_hash', 'state_hash',
    'epoch_bits', 'summary', 'clear_ticks', 'clear_observations', 'visits', 'phase_jobs')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate JSON key: ' + key)
        result[key] = value
    return result


def load(path):
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked(root, name):
    require(isinstance(name, str) and name and '\\' not in name and ':' not in name,
            'invalid evidence path')
    relative = PurePosixPath(name)
    require(not relative.is_absolute() and '..' not in relative.parts, 'unsafe evidence path')
    path = root / name
    require(not path.is_symlink() and path.resolve().is_relative_to(root.resolve()),
            'unsafe evidence target')
    return path


def inventory(root, excluded=()):
    return {p.relative_to(root).as_posix() for p in root.rglob('*')
            if p.is_file() and p.relative_to(root).as_posix() not in excluded}


def check_registration(reg):
    require(reg['track'] == 'C128' and reg['base_commit'] == BASE, 'wrong C128 registration')
    require(reg['arms'] == ARMS and reg['contrasts'] == CONTRASTS and
            reg['pair_orders'] == ORDERS, 'arm/contrast/order matrix drift')
    require(reg['flags'] == FLAGS and reg['anchors'] == ANCHORS,
            'frozen flags/anchor drift')
    require((reg['warmup_ticks'], reg['sample_ticks'], reg['seed']) == (120, 256, 204),
            'frozen workload horizon drift')
    require((reg['primary_processes'], reg['qualification_builds'], reg['qualification_processes']) ==
            (70, 6, 12), 'registered process/build matrix drift')
    require(reg['carrier_correctness_run'] == 39885505290 and
            reg['carrier_correctness_artifact_sha256'] ==
            'fd3e269812bfadd737f38c2cabafd906efb15ea407cb2d4c70a820279179b0c5',
            'full-state carrier correctness prerequisite drift')
    require(reg['budgets'] == dict(compile_seconds=180, process_seconds=120,
            qualification_wall_seconds=2400, timing_wall_seconds=1800, concurrency=1),
            'frozen budgets drift')


def timing_schedule(reg):
    """Independent prospective 70-process definition; never runs a process."""
    check_registration(reg)
    rows = []
    for contrast, descriptor in enumerate(CONTRASTS, 1):
        for pair, order in enumerate(ORDERS, 1):
            for role in order:
                rows.append(dict(index=len(rows) + 1, contrast=contrast, pair=pair,
                                 role=role, anchor=descriptor['anchor'],
                                 arm=descriptor['a'] if role == 'A' else descriptor['b']))
    return rows


def check_compile(argv, arm, observer, definitions):
    require(PurePosixPath(argv[0]).name == 'g++-13' and argv[1:8] == FLAGS,
            'compiler identity or S2A flags differ')
    extra = arm['extra_bytes']
    expected = {'-DNDEBUG', '-DMAT003_STORAGE_KIND=4',
                '-DMAT003_EXTRA_BYTES=' + str(extra), '-DMAT003_SPLIT=0',
                '-DMAT003_ARM_ID="' + arm['id'] + '"', '-DMAT003_EPOCH_BITS=8',
                '-DMAT003_TWIN_OBSERVERS=' + str(observer)}
    macros = [arg for arg in argv if arg.startswith('-D')]
    world = [arg for arg in macros if arg.startswith('-DMAT003_WORLD_SOURCE=')]
    require(len(world) == 1 and world[0].endswith('/overlays/' + arm['id'] + '/native/src/world.cpp"'),
            'World source macro differs from registered overlay')
    require(set(macros) == expected | set(world) and len(macros) == len(expected) + 1,
            'duplicate/missing/changed compiler macros')
    require(set(definitions) == (expected | set(world)) -
            {'-DNDEBUG', '-DMAT003_TWIN_OBSERVERS=' + str(observer)} and
            len(definitions) == len(set(definitions)), 'compile definition receipt differs')
    others = [arg for arg in argv[1:] if arg.startswith('-') and
              not arg.startswith(('-D', '-I')) and arg != '-o']
    require(others == [flag for flag in FLAGS if flag != '-DNDEBUG'],
            'additional or missing compiler/code-generation flags')
    units = [arg for arg in argv if arg.endswith('.cpp')]
    require(len(units) == 5 and units[0].endswith('/source/' + HERE + '/fixture.cpp') and
            [arg.rsplit('/native/src/', 1)[-1] for arg in units[1:]] ==
            ['world.cpp', 'material_rules.cpp', 'scheduler_geometry.cpp', 'settled_world_discovery.cpp'] and
            all('/overlays/' + arm['id'] + '/native/src/' in arg for arg in units[1:]),
            'wrong fixture or compiled World dependency units')
    require(argv[-2] == '-o', 'compiler output missing')


def frozen_result_reader(source):
    path = source / 'tools/experiments/mat003_s2a/verify_apparatus.py'
    spec = importlib.util.spec_from_file_location('independent_accepted_s2a_contract', path)
    module = importlib.util.module_from_spec(spec)
    previous = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous
    return module


def frozen_statistics(source):
    path = source / 'tools/experiments/mat003_s2a/verify_measurement.py'
    spec = importlib.util.spec_from_file_location('independent_accepted_s2a_statistics', path)
    module = importlib.util.module_from_spec(spec)
    previous = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous
    return module


def verify(root, expected_source=None):
    root = root.resolve()
    result = dict(status='failed', formal_timing_admitted=False, performance_accepted=False,
                  checked_files=0, cases=0, builds=0, errors=[])
    try:
        files = load(root / 'files.json')
        require(set(files) == inventory(root, ('files.json', 'independent-readback.json')),
                'missing or extra evidence files')
        for name, digest in files.items():
            require(sha(checked(root, name)) == digest, 'file hash mismatch: ' + name)
            result['checked_files'] += 1
        report = load(root / 'run.json')
        require(report['status'] == 'qualified-not-admitted' and report['errors'] == [] and
                report['formal_timing_admitted'] is False, 'incomplete or timing-promoted qualification')
        review_directory = Path(__file__).resolve().parents[3]
        trusted = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'],
                                              cwd=review_directory, text=True).strip())
        expected_source = expected_source or subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], cwd=trusted, text=True).strip()
        require(re.fullmatch('[0-9a-f]{40}', expected_source) is not None and
                report['source_head'] == expected_source, 'exact reviewed source mismatch')
        names = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', expected_source,
                                        '--', *SOURCE_PATHS], cwd=trusted, text=True).splitlines()
        manifest = load(root / 'source-manifest.json')
        require(set(manifest) == set(names) and
                inventory(root / 'source') == set(names), 'source inventory mismatch')
        for name, digest in manifest.items():
            require(sha(checked(root / 'source', name)) == digest, 'source seal drift: ' + name)
            content = subprocess.check_output(['git', 'show', expected_source + ':' + name], cwd=trusted)
            require(hashlib.sha256(content).hexdigest() == digest, 'source differs from reviewed Git: ' + name)
            if name.startswith(('native/', 'tools/experiments/mat003_prepass/', 'tools/experiments/mat003_s2a/')):
                baseline = subprocess.check_output(['git', 'show', BASE + ':' + name], cwd=trusted)
                require(hashlib.sha256(baseline).hexdigest() == digest, 'accepted source changed: ' + name)
            if name.startswith('tools/experiments/mat003_s2p/') and name.rsplit('/', 1)[-1] in (
                    'apparatus.py', 'fixture.cpp', 'measure.py', 'verify.py', 'registration.json', 'test_contracts.py'):
                accepted_s2p = subprocess.check_output(['git', 'show', S2P_SOURCE + ':' + name], cwd=trusted)
                require(hashlib.sha256(accepted_s2p).hexdigest() == digest, 'accepted S2P source changed: ' + name)
        source = root / 'source'
        require(sha(source / 'tools/experiments/mat003_continuation/candidates.hpp') ==
                'c62ecf0948ab6f31074ddd65fc95409c3a58d54e8f2bcbcc6996142d43f6ab4b' and
                sha(source / 'tools/experiments/mat003_continuation/overlay.py') ==
                '0b3da467496e18ea935028a876105dea43a1e4c17a17a4bc395e2db8b732aba4',
                'carrier implementation differs from full-state correctness prerequisite')
        reg = load(source / HERE / 'registration.json')
        check_registration(reg)
        require(reg['status'] == 'preregistered-apparatus-qualification-only' and
                reg['formal_timing_admitted'] is False and reg['execution_authorized'] is False,
                'wrong qualification registration state')
        require(report['registration_sha256'] == sha(source / HERE / 'registration.json'),
                'registration receipt mismatch')
        require('13.3.0' in report['compiler_version'] and '2.42' in report['linker_version'],
                'compiler/linker version mismatch')
        require(report['compiler_version'] == (root / 'compiler-version.stdout').read_text() and
                report['linker_version'] == (root / 'linker-version.stdout').read_text(),
                'version stdout receipt mismatch')
        expected_ids = [arm['id'] + '-o' + str(observer) for arm in ARMS for observer in (0, 1)]
        expected_cases = [ident + '__' + anchor['id'] for ident in expected_ids for anchor in ANCHORS]
        require([b['id'] for b in report['builds']] == expected_ids and
                [c['id'] for c in report['cases']] == expected_cases,
                'missing/extra/duplicate/reordered build or qualification case')
        expected_labels = ['compiler-version', 'linker-version'] + [
            'compile/' + ident for ident in expected_ids] + ['execute/' + ident for ident in expected_cases]
        require([c['label'] for c in report['commands']] == expected_labels,
                'missing/extra/duplicate/reordered command receipt')
        commands = {c['label']: c for c in report['commands']}
        for command in report['commands']:
            label = command['label']
            require(command['exit_code'] == 0 and command['timed_out'] is False,
                    'failed command: ' + label)
            require(not checked(root, label + '.stderr').read_bytes().strip(),
                    'command stderr not empty: ' + label)
            limit = 180 if label.startswith('compile/') else 120 if label.startswith('execute/') else 10
            require(command['timeout'] == limit, 'command budget drift')
        require(commands['compiler-version']['argv'] == ['g++-13', '--version'] and
                commands['linker-version']['argv'] == ['ld', '--version'], 'tool version command drift')
        generated = load(root / 'generated-seal.json')
        require(set(generated) == {'overlays/' + p for p in inventory(root / 'overlays')},
                'generated overlay seal inventory mismatch')
        for name, digest in generated.items():
            require(sha(checked(root, name)) == digest, 'generated overlay drift: ' + name)
        require(load(root / 'binary-seal.json') == report['builds'], 'binary seal receipt mismatch')
        accepted = frozen_result_reader(source)
        references = {}
        for arm in ARMS:
            adapter = checked(root, 'overlays/' + arm['id'] + '/tools/experiments/mat003_prepass/world_adapter.hpp')
            aliases = re.findall(r'#elif MAT003_STORAGE_KIND == 4\s+using Representation = ([^;]+);\s*#else',
                                 adapter.read_text())
            expected_alias = {'aligned': 'mat003::Aligned<MAT003_EXTRA_BYTES>',
                              'u128': 'mat003_continuation::U128',
                              'dual64': 'mat003_continuation::Dual64'}[arm['representation']]
            require(aliases == [expected_alias], 'generated arm selects the wrong representation: ' + arm['id'])
            require(sha(adapter.with_name('candidates.hpp')) ==
                    sha(source / 'tools/experiments/mat003_continuation/candidates.hpp'),
                    'generated carrier header differs from correctness-qualified source')
            for observer in (0, 1):
                ident = arm['id'] + '-o' + str(observer)
                build = report['builds'][expected_ids.index(ident)]
                require((build['arm'], build['observer'], build['binary'], build['overlay']) ==
                        (arm['id'], observer, 'bin/' + ident, 'overlays/' + arm['id']), 'build identity mismatch')
                require(sha(checked(root, build['binary'])) == build['sha256'], 'binary hash mismatch')
                compile_argv = commands['compile/' + ident]['argv']
                check_compile(compile_argv, arm, observer, build['compile_definitions'])
                require(compile_argv[-1].endswith('/bin/' + ident), 'compiled binary output mismatch')
                result['builds'] += 1
                for anchor in ANCHORS:
                    case_id = ident + '__' + anchor['id']
                    case = report['cases'][expected_cases.index(case_id)]
                    argv = commands['execute/' + case_id]['argv']
                    require(argv == [compile_argv[-1], '--side', str(anchor['side']), '--workers', str(anchor['workers']),
                                      '--warmup', '120', '--ticks', '256', '--seed', '204', '--scenario', anchor['scenario'],
                                      '--mode', 'qualify'], 'qualifier argv differs from registered workload')
                    require(case == dict(id=case_id, arm=arm['id'], observer=observer, anchor=anchor['id'],
                            stdout='execute/' + case_id + '.stdout', stderr='execute/' + case_id + '.stderr'),
                            'case metadata/output path mismatch')
                    value = load(checked(root, case['stdout']))
                    require(value['stage'] == 'C128-paired-performance' and value['observer'] == observer,
                            'actual workload stage/observer mismatch')
                    require((value['cell_stride'], value['cell_alignment'], value['epoch_bits']) ==
                            (arm['stride'], arm['alignment'], 8), 'ABI/epoch mismatch')
                    require(value['clear_observations'] == [dict(tick=256, before=255, after=1)],
                            'actual natural clear witness mismatch')
                    counters = [value[k] for k in ('dispatch_calls', 'dispatched_tasks', 'worker_tasks')]
                    require(all(type(v) is int and v >= 0 for v in counters), 'invalid dispatch counters')
                    participating = observer == 1 and anchor['scenario'] == 'active'
                    require(all(v > 0 for v in counters) if participating else counters == [0, 0, 0],
                            'unqualified worker participation or unexpected observer activity')
                    projected = dict(value, stage='S2A-paired-performance')
                    accepted.check_result(projected, dict(arm_id=arm['id'], **anchor))
                    semantic = {key: value[key] for key in SEMANTIC_FIELDS}
                    if anchor['id'] not in references:
                        references[anchor['id']] = semantic
                    require(semantic == references[anchor['id']],
                            'aligned/observed-off semantic or per-tick work mismatch: ' + case_id)
                    result['cases'] += 1
        fixture = (source / HERE / 'fixture.cpp').read_text()
        require(fixture.count('Clock::now()') == fixture.count('measured ? Clock::now()') and
                fixture.count('Clock::now()') == 6, 'unqualified clock path or changed timing boundary')
        require(len(timing_schedule(reg)) == 70, 'prospective timing matrix incomplete')
        result['status'] = 'qualification-readback-passed-timing-held'
    except Exception as error:
        result['errors'].append(str(error))
    return result


def verify_timing(root, apparatus):
    """Read all future registered observations. Grants no performance acceptance."""
    root, apparatus = root.resolve(), apparatus.resolve()
    result = dict(status='failed', formal_timing_admitted=False, performance_accepted=False,
                  checked_files=0, processes=0, contrasts=[], errors=[])
    try:
        files = load(root / 'files.json')
        require(set(files) == inventory(root, ('files.json', 'independent-timing-readback.json')),
                'missing or extra timing evidence')
        for name, digest in files.items():
            require(sha(checked(root, name)) == digest, 'timing evidence hash mismatch: ' + name)
            result['checked_files'] += 1
        reg = load(root / 'admission.json')
        check_registration(reg)
        require(reg['status'] == 'admitted-paired-timing' and reg['formal_timing_admitted'] is True,
                'timing is not independently admitted')
        review = reg['independent_review']
        require(review['decision'] == 'admitted' and review['reviewer'] and
                review['reviewer'] != reg['author'], 'independent review identity missing')
        authority = load(root / 'authority.json')
        require(authority['execution_authorized'] is True and authority['approver'] and
                authority['registration_sha256'] == sha(root / 'admission.json'),
                'owner authority is absent or for another exact registration')
        evidence = reg['admission_evidence']
        require(sha(Path(__file__)) == evidence['verifier_sha256'], 'independent verifier is not frozen')
        require(sha(apparatus / 'files.json') == evidence['files_sha256'] and
                sha(apparatus / 'independent-readback.json') == evidence['readback_sha256'],
                'qualified apparatus identity differs')
        prerequisite = verify(apparatus, evidence['source_commit'])
        require(prerequisite['status'] == 'qualification-readback-passed-timing-held' and
                prerequisite['cases'] == 12 and prerequisite['builds'] == 6 and not prerequisite['errors'],
                'qualified apparatus fresh independent readback failed: ' + str(prerequisite['errors']))
        require(load(apparatus / 'independent-readback.json') == prerequisite,
                'embedded and fresh apparatus readbacks differ')
        require(sha(apparatus / 'source' / HERE / 'verify.py') == evidence['verifier_sha256'] and
                sha(apparatus / 'source' / HERE / 'measure.py') == evidence['collector_sha256'],
                'qualified source tool identities differ')
        report = load(root / 'run.json')
        require(report['status'] == 'collected-not-accepted' and report['errors'] == [] and
                report['performance_accepted'] is False, 'failed or prematurely accepted timing collection')
        require(report['source_head'] == evidence['source_commit'] and
                report['collector_sha256'] == evidence['collector_sha256'] and
                report['admission_sha256'] == sha(root / 'admission.json') and
                report['authority_sha256'] == sha(root / 'authority.json'), 'source/tool/authority receipt drift')
        expected = timing_schedule(reg)
        require(load(root / 'schedule.json') == expected and len(report['processes']) == 70,
                'all 70 registered processes and pair order are required')
        builds = {b['id']: b for b in load(apparatus / 'binary-seal.json')}
        qualified = {c['id']: load(checked(apparatus, c['stdout']))
                     for c in load(apparatus / 'run.json')['cases']}
        stats = frozen_statistics(apparatus / 'source')
        values = {}
        for row, spec in zip(report['processes'], expected):
            require(all(row[key] == value for key, value in spec.items()), 'timing schedule/role/order drift')
            require(row['exit_code'] == 0 and row['timed_out'] is False, 'failed/timed-out process retained')
            build = builds[spec['arm'] + '-o0']
            require(row['binary_sha256'] == build['sha256'] and
                    sha(checked(apparatus, build['binary'])) == build['sha256'], 'timed binary identity drift')
            argv = row['argv']
            anchor = next(a for a in ANCHORS if a['id'] == spec['anchor'])
            require(PurePosixPath(argv[0]).name == spec['arm'] + '-o0' and
                    argv[1:] == ['--side', str(anchor['side']), '--workers', str(anchor['workers']), '--warmup', '120',
                                 '--ticks', '256', '--seed', '204', '--scenario', anchor['scenario'], '--mode', 'measure'],
                    'timing process invocation drift')
            name = f'{spec["index"]:03d}'
            require(not (root / (name + '.stderr')).read_bytes().strip(), 'timing process stderr not empty')
            value = load(root / (name + '.stdout'))
            control = qualified[spec['arm'] + '-o0__' + spec['anchor']]
            require(value['status'] == 'passed' and value['stage'] == 'C128-paired-performance' and
                    value['arm_id'] == spec['arm'] and value['mode'] == 'measure' and
                    value['performance_qualification'] is True and value['formal_timing_admitted'] is False and
                    value['observer'] == 0, 'timing result identity/mode mismatch')
            for key in SEMANTIC_FIELDS + ('cell_stride', 'cell_alignment', 'dispatch_calls',
                                          'dispatched_tasks', 'worker_tasks'):
                require(value[key] == control[key], 'timing diverges from qualified workload: ' + key)
            for key in ('tick_ns', 'input_ns'):
                require(len(value[key]) == 256 and all(type(v) is int and v >= 0 for v in value[key]),
                        'incomplete or invalid per-tick timing samples')
            require(sum(value['tick_ns']) > 0 and type(value['startup_ns']) is int and
                    value['startup_ns'] >= 0 and type(value['peak_process_rss_bytes']) is int and
                    value['peak_process_rss_bytes'] > 0, 'startup/RSS/mean tick observation invalid')
            values[(spec['contrast'], spec['pair'], spec['role'])] = dict(
                tick_stats=stats.timing_stats(value['tick_ns']), input_stats=stats.timing_stats(value['input_ns']),
                startup_ns=value['startup_ns'], peak_process_rss_bytes=value['peak_process_rss_bytes'])
            result['processes'] += 1
        require(len(values) == 70, 'duplicate/omitted registered pair observations')
        for contrast, descriptor in enumerate(CONTRASTS, 1):
            a, b = descriptor['a'], descriptor['b']
            pairs, ratios = [], []
            for pair, order in enumerate(ORDERS, 1):
                av, bv = values[(contrast, pair, 'A')], values[(contrast, pair, 'B')]
                ratio = bv['tick_stats']['mean_ns'] / av['tick_stats']['mean_ns']
                ratios.append(ratio)
                pairs.append(dict(pair=pair, order=order, a=av, b=bv, b_over_a_mean_tick_ratio=ratio))
            median = statistics.median(ratios)
            result['contrasts'].append(dict(contrast=contrast, a=a, b=b, anchor=descriptor['anchor'], pairs=pairs,
                ratio_summary=dict(ratios=ratios, median=median, min=min(ratios), max=max(ratios),
                    median_absolute_deviation=statistics.median(abs(v - median) for v in ratios))))
        result.update(status='complete-independent-readback-performance-acceptance-held', formal_timing_admitted=True)
    except Exception as error:
        result['errors'].append(str(error))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path, nargs='?')
    parser.add_argument('--source-commit')
    parser.add_argument('--timing', type=Path)
    parser.add_argument('--apparatus', type=Path)
    args = parser.parse_args()
    if args.timing is not None:
        parser.error('--timing requires --apparatus and no positional root') if args.apparatus is None or args.root is not None else None
        outcome = verify_timing(args.timing, args.apparatus)
    else:
        parser.error('qualification requires a root and no --apparatus') if args.root is None or args.apparatus is not None else None
        outcome = verify(args.root, args.source_commit)
    print(json.dumps(outcome, indent=2))
    raise SystemExit(bool(outcome['errors']))
