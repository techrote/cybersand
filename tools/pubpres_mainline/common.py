"""Explicit source-exact build overlays for PUBPRES mainline qualification.

The original committed native manifest is preserved in Git. A build overlay is
never described as a guarded publication. Only this mission's readers accept it,
with the complete original build/dependency receipts and current native inputs.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MISSION = 'PUBPRES-MAINLINE-CONVERGENCE-001'
ACCEPTED_MAIN = '50e3bcb839211eac2abe1e065750cbcba4d36f8c'
OWNER_REFERENCE = '9f2127256a555d177536cbb5fad2be7dcb322c8e'
SCHEMA = 'pubpres-mainline-native-overlay-v1'
HEX40 = re.compile(r'[0-9a-f]{40}')
HEX64 = re.compile(r'[0-9a-f]{64}')
NATIVE = {
    'linux': 'godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so',
    'windows': 'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll',
}
MANIFEST = {p: 'godot/addons/cybersand_native/runtime-provenance' + ('.linux' if p == 'linux' else '') + '.json' for p in NATIVE}
RAPIER = {
    'linux': 'godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so',
    'windows': 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll',
}
SELECTORS = {
    'CYBERSAND_MATERIAL_PUBLICATION': 'full', 'CYBERSAND_DIAG_FULL_IMAGE_SLOTS': '2',
    'CYBERSAND_DIAG_PHYSICS_PUBLICATION': 'early', 'CYBERSAND_DIAG_PRESENTATION': 'coherent',
    'CYBERSAND_DIAG_MATERIAL_TIMING': 'measured', 'CYBERSAND_DIAG_RENDER_CADENCE': 'repaired',
    'CYBERSAND_DIAG_SAME_FRAME_CONTINUATION': '0', 'CYBERSAND_DIAG_NATIVE_RENDEZVOUS': '0',
    'CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ': '0', 'CYBERSAND_DIAG_MATERIAL_POOL_POLICY': 'eager',
    'CYBERSAND_MATERIAL_QUEUE_THREAD': 'safe', 'CYBERSAND_PLAYABILITY_RENDER_THREAD': 'safe',
    'CYBERSAND_DIAG_WATER_COMPOSITION': '1', 'CYBERSAND_DIAG_ACTUAL_SUBMISSION': '0',
    'CYBERSAND_ENGINE_RENDER_LOOKAHEAD': '0', 'CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL': '0',
    'CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE': '0', 'CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER': '0',
    'CYBERSAND_WORKBENCH_FLIGHT_PACING': '1', 'CYBERSAND_WORKBENCH_EMPTY_EFFECTS': '1',
    'CYBERSAND_WORKBENCH_COUPLING_CLOCK': '1',
}
# Godot's Safe render thread is explicitly selected, independently of user config.
OVERRIDE = '[cybersand]\nexperimental_wave_column_tiles=false\npubpres_wave_column_probe=false\n'


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def canonical(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + '\n').encode('utf-8')


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical(value))


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], timeout=300)


def source_identity(root):
    source = git(root, 'rev-parse', 'HEAD').decode().strip()
    tree = git(root, 'rev-parse', 'HEAD^{tree}').decode().strip()
    require(HEX40.fullmatch(source) and HEX40.fullmatch(tree), 'Exact application source/tree required')
    return {'source_commit': source, 'source_tree': tree}


def platform_name():
    require(sys.platform in ('linux', 'win32'), 'Only Linux and Windows qualification is supported')
    return 'windows' if sys.platform == 'win32' else 'linux'


def runtime_record(root, directory, platform):
    """Replay the unchanged offline native/dependency reader on original bytes."""
    root, directory = Path(root).resolve(), Path(directory).resolve()
    # Reader implementation belongs to this measurement driver, while ``root``
    # remains the independently measured application. Importing from the
    # application can reuse a foreign cached reader and bypass its ownership
    # guards when those files differ from the driver.
    sys.path[:0] = [str(ROOT / 'tools/pubpres_final_recovery'), str(ROOT / 'tools/pubpres_final'),
                    str(ROOT / 'tools/pubpres_playability_build'), str(ROOT / 'tools/pubpres_playability')]
    import retained_runtime
    import runtime_replay
    require(Path(retained_runtime.__file__).resolve() == ROOT / 'tools/pubpres_final_recovery/retained_runtime.py'
            and Path(runtime_replay.__file__).resolve() == ROOT / 'tools/pubpres_final/runtime_replay.py',
            'Frozen runtime readers came from another measurement source')
    source = source_identity(root)
    record = json.loads((directory / 'PUBPRES-RUNTIME.json').read_bytes())
    original = {key: record[key] for key in ('source_commit', 'source_tree')}
    checked = runtime_replay.verify_recorded_runtime(root, original, directory, target_platform=platform)
    require(record.get('toolchain_drift_allowed') is False
            and record.get('production_runtime_promotion') is False,
            'Mainline qualification requires an original pinned build without toolchain drift')
    # This unchanged reader checks every native input, generated/authored
    # dependency, build driver and toolchain lock at both original and current
    # commits. A scripts-only application may retain those exact original bytes;
    # a native/build input change requires a fresh independent build.
    checked['application_binding'] = retained_runtime.make_binding(root, source, directory, target_platform=platform)
    return record, checked


def derived_manifest(root, directory, platform):
    record, checked = runtime_record(root, directory, platform)
    source = source_identity(root)
    return {
        'schema_version': 1, 'schema': SCHEMA, 'status': MISSION + ' qualification overlay; Draft/HOLD',
        'artifact': NATIVE[platform], 'source_commit': source['source_commit'],
        'source_tree': source['source_tree'], 'build_commit': record['source_commit'],
        'sha256': record['runtime_sha256'], 'size': record['runtime_bytes'],
        'source_inputs': record['source_inputs_sha256'], 'original_build_receipt_sha256': digest(Path(directory) / 'PUBPRES-RUNTIME.json'),
        'production_runtime_promotion': False,
        'native_input_binding': checked['application_binding'],
        'original_committed_manifest_sha256': hashlib.sha256(git(root, 'show', 'HEAD:' + MANIFEST[platform])).hexdigest(),
    }


def install_runtime(root, directory, project, platform):
    """Install only the admitted library and a visibly distinct build manifest."""
    root, directory, project = Path(root).resolve(), Path(directory).resolve(), Path(project).resolve()
    derived = derived_manifest(root, directory, platform)
    native = project / NATIVE[platform].removeprefix('godot/')
    native.parent.mkdir(parents=True, exist_ok=True)
    source_binary = directory / Path(NATIVE[platform]).name
    if native != source_binary:
        shutil.copyfile(source_binary, native)
    write_json(project / MANIFEST[platform].removeprefix('godot/'), derived)
    override = project / 'override.cfg'
    if override.exists():
        require(override.read_text(encoding='utf-8') == OVERRIDE,
                'Refuse an unreviewed pre-existing render override')
    else:
        override.write_text(OVERRIDE, encoding='utf-8')
    return derived


def observed_runtime(root, directory, project, platform):
    derived = derived_manifest(root, directory, platform)
    project = Path(project)
    path = project / MANIFEST[platform].removeprefix('godot/')
    require(path.read_bytes() == canonical(derived), 'Loaded native manifest is not the exact declared build overlay')
    native = project / NATIVE[platform].removeprefix('godot/')
    require(native.stat().st_size == derived['size'] and digest(native) == derived['sha256'],
            'Loaded native bytes differ from complete build custody')
    rapier = project / RAPIER[platform].removeprefix('godot/')
    pointer = git(root, 'show', 'HEAD:' + RAPIER[platform])
    match = re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n', pointer)
    require(match is not None and digest(rapier) == match[1].decode() and rapier.stat().st_size == int(match[2]),
            'Loaded Rapier differs from the original committed pointer')
    require((project / 'override.cfg').read_text(encoding='utf-8') == OVERRIDE,
            'Safe render-thread override is absent or changed')
    return {
        'runtime_source_commit': derived['source_commit'], 'runtime_build_commit': derived['build_commit'],
        'runtime_provenance': {'path': MANIFEST[platform], 'sha256': digest(path)},
        'native_source_inputs': derived['source_inputs'],
        'cybersand_runtime': {'path': NATIVE[platform], 'sha256': derived['sha256'], 'size': derived['size']},
        'rapier_runtime': {'path': RAPIER[platform], 'sha256': match[1].decode(), 'size': int(match[2])},
    }


def selected_environment(environment):
    result = dict(environment)
    for key in list(result):
        if key.startswith(('CYBERSAND_DIAG_', 'CYBERSAND_PLAYABILITY_', 'CYBERSAND_WORKBENCH_')):
            result.pop(key)
    result.update(SELECTORS)
    return result
