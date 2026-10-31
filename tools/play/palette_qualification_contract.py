#!/usr/bin/env python3
"""Source-bound shader qualification readers. No elapsed-time performance gate."""
from __future__ import annotations

from collections import Counter
import hashlib
import json
import math
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/ci'))
import execution_policy as policy
from play_execution_contract import GODOT_KEYS, _same

CONTEXT = 'PALETTE_QUALIFICATION_CONTEXT '
CAPTURE = 'PALETTE_QUALIFICATION_CAPTURE '
MAIN_RESULT = 'PALETTE_MAIN_PROBE_RESULT '
ORACLE_RESULT = 'PALETTE_CROSSFADE_RENDER_RESULT '
PALETTE = 'godot/shaders/material_palette.gdshader'
BASELINE = 'adaaa37ae35ffcdaa961b80353be3a23b805c0cc'
BASELINE_SHADER = '3d9ee3b04ce6eee03490ad2c4af1f487f208e9ff0db31e6d514127633c2e0fef'
BOUNDED = b'#define CYBER_BOUNDED_CROSSFADE\n'
VERSION = '4.7.stable.official.5b4e0cb0f'
GODOT_HASH = '5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88'
TOLERANCE = 2 / 255
ORACLE_VERSION = 'palette-bounded-crossfade-v3'
ORACLE_ASSERTIONS = 1274
# Independently registered canonical 4x256 RGBAH bytes, unchanged by v3.
PROGRAM_SHA256 = '6ab9c18f2f2993eda7c552b86a28d639a70fb03e0ffdfb2ae070da5c587bb60d'
PROGRAM_PROBE_SHA256 = '9a21543c0cdf2105bf8350a94e7526547eed3a71f3062cee85370601f313e93e'
# Runtime preparation is separate from the immutable scientific inputs.
PYTHON_PACKAGES = ('numpy==2.3.5', 'Pillow==12.3.0')
VISUAL = (
 ('compile-guard', 'test_palette_shader_compile_bounds.gd', False, 'guard'),
 ('bounded-oracle', 'test_palette_crossfade_render.gd', True, 'oracle'),
 ('material-render', 'test_material_presentation_render.gd', True, 'material'),
 ('vapour-render', 'test_material_vapour_pipeline_render.gd', True, 'vapour'),
 ('water-render', 'test_water_presentation_render.gd', True, 'water'),
 ('water-integration', 'test_water_feel_integration.gd', False, 'integration'),
)
SUCCESS = {
 'guard': r'^PALETTE_COMPILE_BOUNDS: PASS$',
 'material': r'^MATERIAL_PRESENTATION_RENDER: actual pixels passed \(time override, still scenery, anchoring, crossfade endpoints, conditions, all 132 ID slots, invalid bounds, growth blockers, vapour footprint, half-resolution single-cell fireworks\)$',
 'vapour': r'^MATERIAL_VAPOUR_PIPELINE: actual pixels, 26 assertions, 0 failures$',
 'water': r'^WATER_PRESENTATION_RENDER: actual pixels coverage=2/4 at 2x, 8/16 at 4x; oriented right edge passed$',
 'integration': r'^WATER_FEEL_INTEGRATION: 24 policy cases \+ 70 scenario builds/reset/invalid/actions/RG8/authority passed default_hash=.+$',
 'atlas': r'^CYBERSAND_SHADER_ATLAS_RESULT .+$',
}


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha(path: Path) -> str:
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')


def file(directory: Path, name: str) -> Path:
    require(type(name) is str and name and not name.startswith(('/', '\\'))
            and ':' not in name and '\\' not in name and '..' not in name.split('/'), 'Unsafe shader artifact path')
    path = directory / name
    cursor = directory
    require(not cursor.is_symlink(), 'Shader artifact directory is a symlink')
    for part in Path(name).parts:
        cursor /= part
        require(not cursor.is_symlink(), 'Shader artifact path is a symlink')
    require(path.is_file() and path.resolve().is_relative_to(directory.resolve()), 'Missing shader artifact: ' + name)
    return path


def packets(log: str, marker: str) -> list:
    return [json.loads(line[len(marker):]) for line in log.splitlines() if line.startswith(marker)]


def one(log: str, marker: str) -> dict:
    found = packets(log, marker)
    require(len(found) == 1 and isinstance(found[0], dict), 'Missing/duplicate completion packet: ' + marker)
    return found[0]


def plan(platform_name: str, group: str) -> list[dict]:
    require(platform_name in ('linux', 'win32') and group in ('visual', 'main-cache'), 'Unregistered shader cohort')
    if group == 'main-cache':
        return [{'name': 'main-' + state, 'script': 'play_palette_shader_main_probe.gd', 'rendered': True,
                 'kind': 'main', 'cache': state, 'timeout': math.ceil(policy.complex_process_seconds())}
                for state in ('cold', 'warm')]
    cases = [{'name': name, 'script': script, 'rendered': rendered, 'kind': kind, 'cache': 'visual-cohort',
              'timeout': math.ceil(policy.case_seconds(Path(script).stem, rendered))}
             for name, script, rendered, kind in VISUAL]
    arms = ('baseline-full', 'candidate-full') if platform_name == 'linux' else ('candidate-bounded',)
    cases += [{'name': 'atlas-' + arm, 'script': 'play_palette_shader_atlas_probe.gd', 'rendered': True,
               'kind': 'atlas', 'arm': arm, 'cache': 'isolated-atlas',
               'timeout': math.ceil(policy.watchdog_seconds('graphical_case_seconds'))} for arm in arms]
    return cases


def cohort_plan(platform_name: str, group: str, shard_index: int) -> list[dict]:
    count = 2 if group == 'visual' else 1
    require(type(shard_index) is int and 0 <= shard_index < count, 'Unregistered shader shard index')
    cases = plan(platform_name, group)
    # Keep both native parity atlases together in the second Linux shard.
    return cases[4 * shard_index:4 * (shard_index + 1)] if group == 'visual' else cases


def observer_join_seconds() -> float:
    return (policy.watchdog_seconds('diagnostic_capture_seconds')
            + policy.watchdog_seconds('terminate_grace_seconds') + 1)


def budgets(platform_name: str, group: str, shard_index: int = 0) -> dict:
    values = policy.identity()['watchdogs']
    cases = cohort_plan(platform_name, group, shard_index)
    cleanup = policy.godot_process_cleanup_seconds()
    # Every sequential phase is counted, including a failed process's complete
    # generic diagnostics/retirement and the observer's independent final join.
    each = {'prepare_seconds': values['operation_seconds'], 'cleanup_seconds': cleanup,
            'observer_join_seconds': observer_join_seconds(), 'collect_seconds': values['operation_seconds']}
    case_total = sum(case['timeout'] + sum(each.values()) for case in cases)
    imported = values['godot_import_seconds'] + cleanup
    # Telemetry's source identity is cached once by the shared generic runner.
    # Preflight and postflight each share one operation clock across all calls.
    metadata = {'preflight_seconds': values['operation_seconds'],
                'postflight_seconds': values['operation_seconds'],
                'telemetry_source_seconds': values['operation_seconds'],
                'import_receipt_seconds': values['operation_seconds'],
                'internal_readback_seconds': values['godot_metadata_seconds'],
                'seal_seconds': values['operation_seconds']}
    suite = math.ceil(case_total + imported + sum(metadata.values()) + values['aggregate_headroom_seconds'])
    # LFS, the official engine ZIP and pinned Python wheels each receive a full
    # independent dependency allowance; setup and observer join have headroom.
    dependencies = math.ceil(3 * values['dependency_prepare_seconds'] + values['operation_seconds']
                             + values['terminate_grace_seconds'])
    suite_minutes = math.ceil(suite / 60)
    dependency_minutes = math.ceil(dependencies / 60)
    readback_minutes = math.ceil(values['godot_metadata_seconds'] / 60)
    metadata_minutes = math.ceil(values['operation_seconds'] / 60)
    # Count the actual rounded outer steps: checkout, Python setup, retained
    # readback, upload, and a separate hosted scheduling/teardown reserve. The
    # Windows checkout configuration is one additional bounded metadata step.
    metadata_steps = 5 if platform_name == 'win32' else 4
    total_minutes = suite_minutes + dependency_minutes + readback_minutes + metadata_steps * metadata_minutes
    minutes = max(math.ceil(values['hosted_job_minutes']), math.ceil(total_minutes / 10) * 10)
    require(minutes <= 360, 'Shader cohort exceeds hosted capacity; split its case inventory without shrinking allowances')
    return {'job_minutes': minutes, 'suite_minutes': suite_minutes,
            'dependency_minutes': dependency_minutes, 'suite_seconds': suite,
            'dependency_seconds': dependencies, 'readback_minutes': readback_minutes,
            'process_overhead': each, 'execution_metadata': metadata,
            'case_total_seconds': case_total, 'import_with_cleanup_seconds': imported,
            'metadata_step_minutes': metadata_minutes, 'metadata_steps': metadata_steps,
            'total_stage_minutes': total_minutes, 'cases': len(cases)}


def reducer_budget() -> dict:
    values = policy.identity()['watchdogs']
    # Six complete source/archive/image readers, then the nine cross-backend
    # comparisons. This is independent of every execution cohort's readback.
    readback = math.ceil((6 * values['godot_metadata_seconds'] + values['operation_seconds']
                          + values['aggregate_headroom_seconds']) / 60)
    dependencies = math.ceil((values['dependency_prepare_seconds'] + values['operation_seconds']
                               + values['terminate_grace_seconds']) / 60)
    metadata = math.ceil(values['operation_seconds'] / 60)
    total = readback + dependencies + 5 * metadata
    minutes = math.ceil(total / 10) * 10
    require(minutes <= 360, 'Shader reducer exceeds hosted capacity; preserve reader allowances when splitting')
    return {'job_minutes': minutes, 'readback_minutes': readback, 'dependency_minutes': dependencies,
            'metadata_step_minutes': metadata, 'total_stage_minutes': total}


def hosted_plan() -> dict:
    return {'include': [{'platform': platform_name, 'group': group, 'shard_index': index,
                         'shard_count': 2 if group == 'visual' else 1,
                         **budgets(platform_name, group, index)}
                        for platform_name in ('linux', 'win32') for group in ('visual', 'main-cache')
                        for index in range(2 if group == 'visual' else 1)]}


def verify_host_paths(report: dict) -> None:
    paths = report.get('host_paths')
    require(isinstance(paths, dict) and set(paths) == {'source_root', 'project_root', 'launcher', 'engine'},
            'Missing original execution host paths')
    kind = PureWindowsPath if report['platform'] == 'win32' else PurePosixPath
    require(all(type(value) is str and kind(value).is_absolute() and '..' not in kind(value).parts
                for value in paths.values()), 'Invalid original execution host path')
    require(kind(paths['project_root']) == kind(paths['source_root']) / 'godot', 'Executed project escaped original checkout')
    if report['platform'] == 'win32':
        require(kind(paths['launcher']).name == 'Godot_v4.7-stable_win64_console.exe'
                and kind(paths['engine']) == kind(paths['launcher']).parent / 'Godot_v4.7-stable_win64.exe',
                'Windows engine/console paths differ from the pinned distribution')
    else:
        require(paths['launcher'] == paths['engine'] and kind(paths['engine']).name == 'Godot_v4.7-stable_linux.x86_64',
                'Linux engine path differs from the pinned distribution')


def expected_command(case: dict, report: dict) -> list[str]:
    verify_host_paths(report)
    paths = report['host_paths']
    command = [paths['launcher']]
    if case['rendered']:
        command += ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy']
        if report['platform'] == 'linux': command += ['--display-driver', 'x11']
    else:
        command += ['--headless']
    command += ['--path', paths['project_root']]
    if case['name'] == 'import':
        return command + ['--editor', '--quit']
    driver = 'opengl3_angle' if case['rendered'] and report['platform'] == 'win32' else 'opengl3'
    return command + ['--rendering-driver', driver, '--script', 'res://tests/' + case['script']]


def fixture_policy(value: object) -> bool:
    expected = policy.identity()
    return (isinstance(value, dict) and value.get('ok') is True
            and value.get('path') == 'res://tests/support/ci_execution_policy.json'
            and value.get('sha256') == expected['sha256']
            and _same(value.get('schema_version'), expected['schema_version'])
            and _same(value.get('scale'), expected['scale'])
            and isinstance(value.get('watchdogs'), dict)
            and all(_same(value['watchdogs'].get(key), expected['watchdogs'][key]) for key in GODOT_KEYS))


def verify_shader(value: dict, variant: str, shader_hashes: dict) -> None:
    require(isinstance(value, dict) and value.get('variant') == variant
            and value.get('source_bound') is True and value.get('source_file_bound') is True
            and value.get('source_path') == 'res://shaders/material_palette.gdshader'
            and value.get('source_sha256') == shader_hashes['full_crossfade']
            and value.get('source_file_sha256') == shader_hashes['full_crossfade']
            and value.get('variant_sha256') == shader_hashes[variant], 'Actual shader is not source-bound to its registered variant')


def verify_process(process: dict, case: dict, log: str, report: dict) -> None:
    require(process.get('status') == 'passed' and type(process.get('returncode')) is int
            and process['returncode'] == 0 and process.get('natural_completion') is True
            and _same(process.get('execution_policy'), policy.identity()), 'Shader process did not pass naturally under the source policy')
    require(_same(process.get('timeout_seconds'), case['timeout'])
            and type(process.get('seconds')) in (int, float) and math.isfinite(process['seconds'])
            and 0 <= process['seconds'] <= case['timeout'], 'Wrong/exceeded shader process allowance')
    require(process.get('requires_display') is case['rendered']
            and not any(process.get(key) for key in ('capture_error', 'launch_error', 'diagnostic_error',
                'timeout_kind', 'timeout_diagnostic_error', 'skip_messages')), 'Shader process has error, timeout, skip or wrong display scope')
    require('SCRIPT ERROR:' not in log and 'ERROR:' not in log
            and re.search(r'\bskipped\b|^\s*SKIP\b', log, re.I | re.M) is None, 'Shader log contains an error or skip')
    require(process.get('name') == case['name'] and process.get('log') == case['name'] + '.log'
            and process.get('role') == 'source-bound shader qualification'
            and _same(process.get('command'), expected_command(case, report)),
            'Shader process argv/fixture/role differs from the complete registered command')


def verify_context(context: dict, case: dict, report: dict, row: dict) -> None:
    platform_name = report['platform']
    driver = 'opengl3_angle' if case['rendered'] and platform_name == 'win32' else 'opengl3'
    display = ('Windows' if platform_name == 'win32' else 'X11') if case['rendered'] else 'headless'
    require(context.get('schema') == 'palette-qualification-context-v1'
            and context.get('source_revision') == report['source_commit']
            and context.get('nonce') == row['nonce'] and re.fullmatch(r'[0-9a-f]{32}', row['nonce']) is not None
            and context.get('fixture') == 'res://tests/' + case['script']
            and context.get('fixture_sha256') == report['source_inputs']['godot/tests/' + case['script']],
            'Shader fixture source/nonce identity mismatch')
    require(context.get('platform') == ('Windows' if platform_name == 'win32' else 'Linux')
            and context.get('backend') == driver and context.get('display_server') == display,
            'Actual renderer/display/OS differs from registered shader backend')
    require(isinstance(context.get('godot'), dict) and context['godot'].get('hash') == GODOT_HASH
            and context['godot'].get('major') == 4 and context['godot'].get('minor') == 7
            and context['godot'].get('status') == 'stable' and context['godot'].get('build') == 'official',
            'Actual shader engine build differs')
    require(context.get('engine_sha256') == report['engine']['runtime_sha256']
            and type(context.get('process_id')) is int and context['process_id'] > 0
            and fixture_policy(context.get('execution_policy')), 'Shader actual process/policy identity differs')
    verify_host_paths(report)
    actual_engine = context.get('engine_path', '').replace('\\', '/')
    expected_engine = report['host_paths']['engine'].replace('\\', '/')
    require((actual_engine.casefold() == expected_engine.casefold()) if platform_name == 'win32'
            else actual_engine == expected_engine, 'Actual engine path differs from the retained execution command')
    if platform_name == 'linux':
        require(context['process_id'] == row['process']['pid'], 'Actual Linux shader PID differs from spawned engine')
    require(context.get('cache_state') == case['cache'], 'Shader cache scope differs')
    root = row['cache_root'].replace('\\', '/').rstrip('/')
    path = context.get('user_data_dir', '').replace('\\', '/')
    path_type = PureWindowsPath if platform_name == 'win32' else PurePosixPath
    require(path_type(root).is_absolute() and path_type(path).is_absolute()
            and '..' not in path_type(root).parts and '..' not in path_type(path).parts,
            'Actual Godot cache path is not an absolute contained host path')
    if platform_name == 'win32': root, path = root.casefold(), path.casefold()
    require(path.startswith(root + '/'), 'Actual Godot user data escaped isolated cache directories')
    if case['kind'] not in ('main', 'atlas'):
        variant = 'angle_bounded_crossfade' if case['kind'] == 'oracle' or driver == 'opengl3_angle' else 'full_crossfade'
        verify_shader(context.get('shader'), variant, report['shader_hashes'])


def pixels(directory: Path, capture: dict, size: tuple | None = None):
    import numpy as np
    from PIL import Image
    require(isinstance(capture, dict) and 'error' not in capture, 'Missing retained pixel capture')
    dimensions = capture.get('size')
    require(isinstance(dimensions, list) and len(dimensions) == 2
            and all(type(value) is int and 0 < value <= 4096 for value in dimensions)
            and (size is None or dimensions == list(size)), 'Retained image size differs')
    formats = {4: (np.dtype('u1'), 3), 5: (np.dtype('u1'), 4),
               11: (np.dtype('<f4'), 4), 15: (np.dtype('<f2'), 4)}
    require(type(capture.get('format')) is int and capture['format'] in formats, 'Unknown framebuffer format')
    dtype, channels = formats[capture['format']]
    # Old fixture captures contain their original absolute host path. Read only
    # the exact basename under this process's sealed capture directory.
    raw_name = PureWindowsPath(capture.get('raw', '')).name
    png_name = PureWindowsPath(capture.get('png', '')).name
    require(raw_name.endswith('.raw') and png_name.endswith('.png'), 'Wrong retained pixel filenames')
    raw = file(directory, raw_name); png = file(directory, png_name)
    require(sha(raw) == capture.get('raw_sha256') and sha(png) == capture.get('png_sha256'), 'Retained pixel digest differs')
    data = raw.read_bytes(); width, height = dimensions
    require(len(data) == width * height * channels * dtype.itemsize, 'Raw framebuffer byte count differs')
    values = np.frombuffer(data, dtype=dtype).reshape((height, width, channels)).astype(np.float64)
    if dtype.itemsize == 1:
        values /= 255
    require(bool(np.isfinite(values).all()), 'Nonfinite native framebuffer channel')
    if channels == 3:
        values = np.concatenate([values, np.ones((height, width, 1))], axis=2)
    with Image.open(png) as image:
        require(image.size == (width, height), 'PNG dimensions differ from native framebuffer')
        encoded = np.array(image.convert('RGBA'), dtype=np.float64) / 255
    require(float(np.max(np.abs(encoded - np.clip(values, 0, 1)))) <= 1 / 255 + 1e-7,
            'PNG does not represent the retained native framebuffer')
    return values


def reference_pixels(condition: int):
    import numpy as np
    colours = np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1], [0, 1, 1],
                        [1, 0, 1], [1, 1, 0], [1, 1, 1]], dtype=float)
    response = max(0.0, min(1.0, (condition / 255 - .25) / .5))
    response = response * response * (3 - 2 * response)
    ids = np.minimum((np.arange(36)[:, None] // 4) * 16 + np.arange(64)[None, :] // 4, 131)
    rgb = colours[ids % 7] * (.25 + .5 * response)
    rgb = rgb * (1 - .5 * response) + np.array([0, 1, 0]) * (.5 * response)
    rgb += np.array([.5, 0, .25]) * (.125 * response)
    return np.concatenate([rgb, np.ones((36, 64, 1))], axis=2)


def edited_program(canonical: bytes):
    import numpy as np
    require(len(canonical) == 8192 and hashlib.sha256(canonical).hexdigest() == PROGRAM_SHA256,
            'Canonical CPU program differs from the independent byte registration')
    values = np.frombuffer(canonical, dtype='<f2').reshape(256, 4, 4).copy()
    require(values[2, 3, 3] == 33 and values[3, 3, 3] == 29, 'Registered Sand/Water HDR instructions differ')
    values[:, 0] = (0, 1, 0, .5)
    values[:, 1] = (.25, .75, .25, .75)
    values[:, 2] = (1, 1, 0, .125)
    values[:, 3, :3] = (.5, 0, .25)
    return values


def program_scalar_pixels(program):
    import numpy as np
    values = program.astype(np.float64).reshape(256, 16).copy()
    values[:, 15] /= 64
    return np.concatenate([np.repeat(values[:, :, None], 3, axis=2), np.ones((256, 16, 1))], axis=2)


def verify_program_inputs(value: dict, directory: Path, draw_timings: list) -> dict:
    import numpy as np
    require(isinstance(value, dict) and value.get('schema') == 'palette-program-gpu-inputs-v1'
            and _same(value.get('scalar_count'), 4096) and _same(value.get('flair_scale'), 64)
            and value.get('probe_shader_sha256') == PROGRAM_PROBE_SHA256, 'Missing/changed independent GPU program-input control')

    def cpu_bytes(key: str) -> bytes:
        item = value.get(key, {})
        require(item.get('file') == 'program_' + key + '.rgba16f' and item.get('size') == [4, 256]
                and _same(item.get('format'), 15) and _same(item.get('bytes'), 8192), 'CPU program byte inventory differs')
        path = file(directory, item['file']); data = path.read_bytes()
        require(len(data) == 8192 and sha(path) == item.get('sha256'), 'Retained CPU program bytes/digest differ')
        return data

    expected = edited_program(cpu_bytes('canonical'))
    edited = cpu_bytes('edited')
    require(edited == expected.tobytes(), 'Edited CPU program differs from independently reconstructed instructions')
    clamped = expected.copy(); clamped[:, 3, 3] = np.minimum(clamped[:, 3, 3], 1)

    def identity(item: object) -> dict:
        require(isinstance(item, dict) and set(item) == {'object_id', 'rid'}
                and all(type(v) is int and v != 0 for v in item.values()), 'Invalid actual program texture identity')
        return item

    positive = value.get('positive', {}); negative = value.get('negative', {})
    bound = identity(positive.get('binding_before'))
    control = identity(negative.get('binding_before'))
    require(bound['object_id'] != control['object_id'] and bound['rid'] != control['rid'],
            'Clamped control reused the production program object/RID')
    bindings = value.get('production_bindings', [])
    indices = [i for i in range(24) if i % 8 != 0]
    require(isinstance(bindings, list) and len(bindings) == 21
            and [row.get('draw_index') for row in bindings] == indices
            and all(type(row.get('draw_index')) is int and identity(row.get('before')) == bound
                    and identity(row.get('after')) == bound for row in bindings),
            'Positive GPU probe differs from an actual production program binding')
    require(len(draw_timings) == 24, 'Program probe has no original draw inventory')
    previous_end = draw_timings[-1].get('readback_usec')
    arrays = []
    for probe, role, texture in ((positive, 'production_bound', bound), (negative, 'clamped_control', control)):
        require(probe.get('role') == role and identity(probe.get('binding_after')) == texture,
                'Program probe role/binding changed during rendering')
        begin, end = probe.get('requested_usec'), probe.get('readback_usec')
        require(type(begin) is int and type(end) is int and type(previous_end) is int
                and previous_end <= begin < end, 'GPU program probes did not follow the unchanged original draws')
        previous_end = end
        record = probe.get('capture', {})
        require(record.get('label') == 'program_' + role and record.get('raw') == 'program_' + role + '.raw'
                and record.get('png') == 'program_' + role + '.png' and record.get('format') in (11, 15),
                'GPU program probe capture identity differs')
        arrays.append(pixels(directory, record, (16, 256)))
    positive_error = float(np.max(np.abs(arrays[0] - program_scalar_pixels(expected))))
    negative_error = float(np.max(np.abs(arrays[1] - program_scalar_pixels(clamped))))
    rejection = np.abs(arrays[1] - program_scalar_pixels(expected))
    rejection_error = float(np.max(rejection))
    sand, water = (float(np.max(rejection[row, 15])) for row in (2, 3))
    require(positive_error <= TOLERANCE, 'Actual bound GPU program failed independent positive instruction comparison')
    require(negative_error <= TOLERANCE, 'Rendered negative control is not the registered clamped program')
    require(rejection_error > TOLERANCE and sand > TOLERANCE and water > TOLERANCE,
            'Positive instruction comparator did not reject the rendered clamped Sand/Water control')
    errors = {'positive_max_error': positive_error, 'negative_control_max_error': negative_error,
              'negative_rejection_max_error': rejection_error, 'sand_rejection_error': sand, 'water_rejection_error': water}
    require(all(type(value.get(key)) in (int, float) and math.isclose(value[key], error, abs_tol=1e-6)
                for key, error in errors.items()), 'GPU input self-report differs from independent scalar reduction')
    return {'status': 'passed', 'canonical_sha256': PROGRAM_SHA256, 'edited_sha256': hashlib.sha256(edited).hexdigest(),
            'scalars_per_probe': 4096, 'retained_probe_images': 2, 'production_bindings': 21,
            'bound_texture': bound, 'clamped_texture': control, **errors,
            'scope': 'Actual production-bound GPU instructions and separately rendered clamped negative; neither uses endpoint self-reference'}


def verify_oracle(result: dict, directory: Path, report: dict) -> dict:
    import numpy as np
    require(result.get('fixture') == ORACLE_VERSION
            and type(result.get('assertions')) is int and result['assertions'] == ORACLE_ASSERTIONS
            and type(result.get('failures')) is int and result['failures'] == 0
            and result.get('conditions') == [0, 128, 255] and result.get('blends') == [0, .5, 1]
            and result.get('material_slots') == 132 and _same(result.get('tolerance'), TOLERANCE),
            'Bounded oracle scientific inventory differs')
    verify_shader(result.get('shader'), 'angle_bounded_crossfade', report['shader_hashes'])
    expected = {(condition, blend) for condition in (0, 128, 255) for blend in (0, .5, 1)}
    rows = result.get('rows', [])
    require(len(rows) == 9 and {(row['condition'], row['blend']) for row in rows} == expected,
            'Missing/duplicate bounded oracle frame')
    inputs = result.get('oracle_inputs', [])
    require(len(inputs) == 3 and {row['condition'] for row in inputs} == {0, 128, 255}, 'Missing bounded reference/current readbacks')
    controls = {}
    for row in inputs:
        reference = pixels(directory, row['reference'], (64, 36))
        complete = pixels(directory, row['current'], (64, 36))
        require(float(np.max(np.abs(reference - reference_pixels(row['condition'])))) <= TOLERANCE,
                'Rendered independent reference differs from CPU colour programme')
        require(row['reference']['format'] in (11, 15)
                and row['current']['format'] == row['reference']['format'], 'Oracle did not retain its registered HDR readbacks')
        controls[row['condition']] = reference, complete, row['reference']['format']
    maximum = 0.0; camera_maximum = 0.0
    for row in rows:
        require(row.get('material_slots') == 132, 'Outgoing material slot inventory differs')
        actual = pixels(directory, row['capture'], (64, 36)); pan = pixels(directory, row['pan_capture'], (64, 36))
        reference, complete, image_format = controls[row['condition']]
        expected_pixels = reference * (1 - row['blend']) + complete * row['blend']
        if row['blend'] == .5:
            # The original fixture writes the lerped Color back into a duplicate
            # Image. Preserve that image's storage precision in the independent
            # reduction; do not silently compare against an unrounded oracle.
            expected_pixels = expected_pixels.astype(np.float32).astype('<f2' if image_format == 15 else '<f4').astype(np.float64)
        error = float(np.max(np.abs(actual - expected_pixels)))
        camera = float(np.max(np.abs(actual[2:, 3:] - pan[:-2, :-3])))
        require(error <= TOLERANCE and camera <= TOLERANCE, 'Bounded outgoing/midpoint/final or camera pixel expectation failed')
        require(math.isclose(error, row.get('max_rgba_difference', -1), abs_tol=1e-6)
                and math.isclose(camera, row.get('camera_pan_difference', -1), abs_tol=1e-6),
                'Bounded self-report differs from independently reduced pixels')
        maximum = max(maximum, error); camera_maximum = max(camera_maximum, camera)
    require(len(result.get('draw_timings', [])) == 24 and all(
        row.get('readback_usec', 0) > row.get('requested_usec', 0) >= 0 for row in result['draw_timings']),
        'Missing bounded oracle actual draw/readback inventory')
    program_inputs = verify_program_inputs(result.get('program_inputs'), directory, result['draw_timings'])
    return {'frames': 9, 'material_slots': 132, 'retained_images': 24, 'max_rgba_error': maximum,
            'max_camera_error': camera_maximum, 'tolerance': TOLERANCE, 'program_inputs': program_inputs}


def compare_bounded_backends(left: Path, right: Path) -> dict:
    """Reduce the pair after both complete, source-bound cohort readers pass."""
    import numpy as np
    a = json.loads(file(left, 'crossfade.json').read_text()); b = json.loads(file(right, 'crossfade.json').read_text())
    require(a.get('fixture') == b.get('fixture') == ORACLE_VERSION and a.get('backend') == 'opengl3'
            and b.get('backend') == 'opengl3_angle', 'Cross-backend semantic contract/backend differs')
    require(len(a.get('rows', [])) == len(b.get('rows', [])) == 9, 'Cross-backend frame inventory differs')
    frames = []; outgoing = []
    for x, y in zip(a['rows'], b['rows']):
        require((x['condition'], x['blend']) == (y['condition'], y['blend']), 'Cross-backend bounded frames differ in inputs')
        delta = np.abs(pixels(left, x['capture'], (64, 36)) - pixels(right, y['capture'], (64, 36)))
        error = float(np.max(delta)); count = int(np.count_nonzero(np.max(delta, axis=2) > TOLERANCE))
        frame = {'condition': x['condition'], 'blend': x['blend'], 'max_rgba_difference': error,
                 'pixels_exceeding_original_threshold': count, 'total_pixels': 2304}
        frames.append(frame)
        if x['blend'] == 0:
            require(error <= TOLERANCE, 'Cross-backend positive outgoing CPU-base expectation failed')
            outgoing.append(frame)
    require(len(outgoing) == 3, 'Missing cross-backend outgoing CPU-base conditions')
    return {'schema': 'palette-bounded-semantics-v3', 'status': 'passed', 'outgoing_base_frames': outgoing,
            'finished_image_diagnostic': {'status': 'passed' if all(v['pixels_exceeding_original_threshold'] == 0 for v in frames) else 'failed',
                'original_threshold': TOLERANCE, 'frames': frames,
                'scope': 'Retained v2 finished-image identity diagnostic, not the v3 acceptance predicate. Procedural hash finish is stable on one GPU; no tolerated-pixel allowance is introduced.'},
            'scope': 'Each backend independently passes all base/blend/full-current/camera and actual GPU-input controls; cross-backend CPU-base remains a positive fixed-tolerance gate.'}


def verify_water(log: str, directory: Path) -> dict:
    import numpy as np
    captures = packets(log, CAPTURE)
    by_name = {row['label']: row for row in captures}
    expected = {'water_0_1_2_0', 'water_1_1_2_0', 'water_0_1_4_0', 'water_1_1_4_0', 'water_1_2_2_1'}
    require(len(captures) == 5 and set(by_name) == expected, 'Water capture inventory differs')
    data = {name: pixels(directory, row) for name, row in by_name.items()}
    def changed(a, b, scale):
        delta = np.abs(a[scale:2*scale, scale:2*scale] - b[scale:2*scale, scale:2*scale]).sum(axis=2)
        return {(int(x), int(y)) for y, x in np.argwhere(delta > .02)}
    require(changed(data['water_0_1_2_0'], data['water_1_1_2_0'], 2) == {(0, 1), (1, 1)},
            'Water 2x lower-half coverage differs')
    require(len(changed(data['water_0_1_4_0'], data['water_1_1_4_0'], 4)) == 8, 'Water 4x half coverage differs')
    require(changed(data['water_0_1_2_0'], data['water_1_2_2_1'], 2) == {(1, 0), (1, 1)},
            'Water oriented right edge differs')
    return {'retained_images': 5, 'coverage_2x': 2, 'coverage_4x': 8, 'orientation': 'right'}


def verify_main(result: dict, context: dict, directory: Path, report: dict) -> dict:
    import numpy as np
    require(result.get('schema') == 'palette-main-recreation-v1' and result.get('context') == context
            and type(result.get('failures')) is int and result['failures'] == 0
            and type(result.get('assertions')) is int and result['assertions'] >= 20
            and type(result.get('joined_workers')) is int and result['joined_workers'] == 2
            and type(result.get('retired_sessions')) is int and result['retired_sessions'] == 2
            and result.get('rig') == 'acrobat' and result.get('workers_requested') == 1, 'Incomplete/failed real Main recreation')
    lives = result.get('lifetimes', [])
    require(len(lives) == 2 and [row.get('index') for row in lives] == [0, 1], 'Main lifetime inventory differs')
    require(len({row.get('worker_id') for row in lives}) == 2 and len({row.get('session_id') for row in lives}) == 2,
            'Main lifetimes did not instantiate distinct owners')
    require(all(type(row.get(key)) is int and -(2**63) <= row[key] < 2**63 and row[key] != 0 for row in lives
                for key in ('worker_id', 'session_id', 'shader_instance_id'))
            and lives[0]['shader_instance_id'] == lives[1]['shader_instance_id'], 'Main shader/owner instance identity differs')
    variant = 'angle_bounded_crossfade' if report['platform'] == 'win32' else 'full_crossfade'
    started = result['fixture_started_usec']; finished = result['fixture_finished_usec']
    require(type(started) is int and type(finished) is int and 0 <= started < finished
            and _same(result.get('elapsed_usec'), finished - started), 'Main whole-fixture clock differs')
    for life in lives:
        verify_shader(life.get('shader'), variant, report['shader_hashes'])
        require(life.get('ready') is True and life.get('worker_joined') is True and life.get('session_retired') is True
                and life.get('world_surface_visible') is True and life.get('world_material_bound') is True
                and life.get('world_texture_bound') is True
                and life['initial_native_tick'] < life['native_tick'] and life['initial_rapier_tick'] + 3 <= life['rapier_tick']
                and life['frames_after_ready'] >= 2
                and started <= life['started_usec'] <= life['acknowledged_usec'] < life['readback_usec'] <= life['retired_usec'] <= finished
                and _same(life.get('bounded_define_count'), 1 if report['platform'] == 'win32' else 0)
                and math.isclose(life['main_ack_seconds'], (life['acknowledged_usec'] - life['started_usec']) / 1e6, abs_tol=1e-6),
                'Main automatic progress, actual draw or retirement evidence differs')
        require(0 <= life['shutdown_usec'] <= policy.watchdog_microseconds('operation_seconds'), 'Main retirement exceeded its allowance')
        actual = pixels(directory, life['capture'], (960, 540))
        require(float(np.max(np.std(actual[:, :, :3], axis=(0, 1)))) > .01, 'Main retained an empty/flat readback')
    waits = result.get('waits', [])
    require(len(waits) == 4 and all(row.get('passed') is True and row['started_usec'] <= row['ended_usec'] <= row['deadline_usec']
            and row['deadline_usec'] - row['started_usec'] <= row['allowance_usec'] for row in waits), 'Main completion waits are missing/late')
    for row, (label, key) in zip(waits, [('Main construction acknowledgement', 'main_ack_seconds'),
                                         ('automatic native and Rapier progress', 'operation_seconds')] * 2):
        require(row.get('label') == label and _same(row.get('allowance_usec'), policy.watchdog_microseconds(key))
                and _same(row.get('deadline_usec'), min(row['started_usec'] + row['allowance_usec'],
                                                        started + policy.watchdog_microseconds('complex_fixture_seconds'))),
                'Main wait changed its registered source-policy allowance')
    require(lives[0]['retired_usec'] <= lives[1]['started_usec'], 'Main recreation overlapped retired scene ownership')
    require(0 <= result['elapsed_usec'] <= policy.watchdog_microseconds('complex_fixture_seconds'), 'Main fixture exceeded its whole-fixture allowance')
    return {'lifetimes': 2, 'joined_workers': 2, 'retired_sessions': 2,
            'construction_seconds': [row['main_ack_seconds'] for row in lives],
            'request_to_readback_seconds': [(row['readback_usec'] - row['started_usec']) / 1e6 for row in lives],
            'timing_scope': 'whole Main construction/request to actual readback; never compiler-only or FXC time'}


def verify_case(case: dict, row: dict, directory: Path, report: dict) -> dict:
    process = json.loads(file(directory, 'process.json').read_text())
    require(_same(process, row['process']), 'Original shader process receipt changed')
    log_path = file(directory, process['log'])
    require(sha(log_path) == row['log_sha256'], 'Original shader process log changed')
    log = log_path.read_text(encoding='utf-8')
    verify_process(process, case, log, report)
    context = one(log, CONTEXT)
    verify_context(context, case, report, row)
    if case['kind'] in SUCCESS:
        require(len(re.findall(SUCCESS[case['kind']], log, re.M)) == 1, 'Missing/duplicate explicit visual completion marker')
    captures = directory / 'captures'
    if case['kind'] == 'oracle':
        result = one(log, ORACLE_RESULT)
        require(result == json.loads(file(captures, 'crossfade.json').read_text()), 'Oracle report differs from original engine output')
        require(result.get('backend') == context['backend'], 'Oracle actual backend differs')
        reduced = verify_oracle(result, captures, report)
    elif case['kind'] == 'main':
        reduced = verify_main(one(log, MAIN_RESULT), context, captures, report)
    elif case['kind'] == 'water':
        reduced = verify_water(log, captures)
    elif case['kind'] == 'atlas':
        import compare_pace003_palette_atlas as atlas
        require(_same(one(log, 'CYBERSAND_SHADER_ATLAS_RESULT '), {'frames': 16, 'failures': 0}),
                'Original atlas completion footer differs from its complete frame inventory')
        value = atlas.load(captures)
        expected_hash = (BASELINE_SHADER if case['arm'] == 'baseline-full' else
                         report['shader_hashes']['angle_bounded_crossfade' if case['arm'] == 'candidate-bounded' else 'full_crossfade'])
        require(value['source_revision'] == report['source_commit'] and value['shader_sha256'] == expected_hash
                and value['platform'] == context['platform'] and value['display_server'] == context['display_server']
                and value['godot'] == context['godot'] and value['video_adapter'] == context['video_adapter'],
                'Atlas source/selected shader/backend identity differs')
        reduced = {'frames': 16, 'shader_sha256': expected_hash, 'scope': value['scope']}
    else:
        reduced = {'explicit_completion_marker': True}
        if case['kind'] == 'guard':
            value = one(log, 'PALETTE_COMPILE_BOUNDS_RESULT ')
            require(type(value.get('assertions')) is int and value['assertions'] == 27
                    and type(value.get('failures')) is int and value['failures'] == 0,
                    'Compiler/custody guard inventory differs')
            verify_shader(value.get('production_variant'), 'angle_bounded_crossfade', report['shader_hashes'])
        if case['kind'] == 'material':
            from PIL import Image
            with Image.open(file(captures, 'material-id-slots-000-131.png')) as image:
                require(image.width > 0 and image.height > 0, 'Missing original material atlas pixels')
        if case['kind'] == 'vapour':
            for name in ('vapour-seeded.exr', 'vapour-decayed.exr', 'vapour-reset.exr'):
                require(file(captures, name).stat().st_size > 100, 'Missing original vapour framebuffer')
    return {'context': context, 'reduced': reduced}
