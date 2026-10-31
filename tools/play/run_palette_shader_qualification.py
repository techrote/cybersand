#!/usr/bin/env python3
"""Qualify actual Linux native/Windows ANGLE pixels and cold/warm Main recreation."""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import importlib.metadata
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import threading
import time
import uuid
import zipfile

import palette_qualification_contract as c

ROOT = c.ROOT
SCOPES = ('.gitattributes', 'build_windows_msvc.bat', 'tools/launch_desktop.ps1',
          'godot', 'native', 'third_party', 'tools/ci', 'tools/play', '.github/workflows')
NORMALIZED_IMPORTS = {
    'godot/addons/godot-rapier2d/Radial2D.svg.import',
    'godot/addons/godot-rapier2d/icons/Fluid2D.svg.import',
    'godot/addons/godot-rapier2d/icons/StateManager2D.svg.import',
    'godot/addons/godot-rapier2d/logo_square_2d.png.import',
}
REQUIRED_APPARATUS = {
    'tools/play/palette_checkout_custody.py', 'tools/play/palette_qualification_contract.py',
    'tools/play/palette_windows_compiler.py', 'tools/play/run_palette_shader_qualification.py',
    'tools/ci/execution_policy.py', 'tools/ci/play_execution_contract.py',
    'godot/tests/palette_qualification_context.gd', 'godot/tests/support/ci_execution_policy.gd',
    'godot/tests/support/ci_execution_policy.json',
}
_METADATA_DEADLINE: float | None = None


def metadata_remaining() -> float:
    c.require(_METADATA_DEADLINE is not None, 'Shader source subprocess has no shared operation context')
    remaining = _METADATA_DEADLINE - time.monotonic()
    c.require(remaining > 0, 'Shader metadata exhausted its shared phase allowance')
    return remaining


@contextlib.contextmanager
def metadata_budget(label: str, seconds: float | None = None):
    global _METADATA_DEADLINE
    previous = _METADATA_DEADLINE
    deadline = time.monotonic() + (c.policy.watchdog_seconds('operation_seconds') if seconds is None else seconds)
    _METADATA_DEADLINE = min(previous, deadline) if previous is not None else deadline
    try:
        yield
        metadata_remaining()
    except Exception as error:
        raise RuntimeError(label + ': ' + str(error)) from error
    finally:
        _METADATA_DEADLINE = previous


def git(*arguments: str) -> bytes:
    return subprocess.check_output(['git', '-C', str(ROOT), *arguments], timeout=metadata_remaining())


def runtime_paths(platform_name: str) -> set[str]:
    return ({'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll',
             'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'}
            if platform_name == 'win32' else
            {'godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so',
             'godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so'})


def source_inputs() -> dict:
    paths = git('ls-files', '-z', '--', *SCOPES).decode().split('\0')
    result = {}
    for name in paths:
        metadata_remaining()
        if not name or name.startswith('godot/.godot/'):
            continue
        data = (ROOT / name).read_bytes()
        result[name] = hashlib.sha256(data).hexdigest()
    return result


def import_checkout_digests(data: bytes) -> set[str]:
    lf = data.replace(b'\r\n', b'\n')
    c.require(b'\r' not in lf and b'\0' not in lf, 'Known Rapier import descriptor is not newline-only text')
    return {hashlib.sha256(value).hexdigest() for value in (lf, lf.replace(b'\n', b'\r\n'))}


def source_rewrites(before: dict, after: dict, archive_path: Path) -> list[str]:
    c.require(set(before) == set(after), 'Postflight source inventory changed')
    changed = sorted(name for name in before if before[name] != after[name])
    c.require(set(changed).issubset(NORMALIZED_IMPORTS), 'Source/runtime bytes changed outside known Godot import rewrites')
    if changed:
        with tarfile.open(archive_path, 'r:') as archive:
            for name in changed:
                forms = import_checkout_digests(archive.extractfile(name).read())
                c.require(before[name] in forms and after[name] in forms, 'Godot import rewrite changed content')
    return changed


def export_source(destination: Path, source: str) -> str:
    c.require(not destination.exists(), 'Refusing to replace original shader source archive')
    with destination.open('xb') as handle:
        subprocess.run(['git', '-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'archive', '--format=tar', source],
                       cwd=ROOT, stdout=handle, check=True, timeout=metadata_remaining(),
                       env=os.environ | {'GIT_LFS_SKIP_SMUDGE': '1'})
    return c.sha(destination)


def verify_source(directory: Path, report: dict, expected_source: str) -> None:
    with metadata_budget('independent source/archive verification'):
        _verify_source(directory, report, expected_source)


def _verify_source(directory: Path, report: dict, expected_source: str) -> None:
    c.require(re.fullmatch(r'[0-9a-f]{40}', expected_source) is not None
              and report['source_commit'] == expected_source, 'Unexpected independently supplied shader source')
    c.require(git('rev-parse', 'HEAD').decode().strip() == expected_source,
              'Shader readback must run from the independently expected source checkout')
    c.require(report['source_tree'] == git('rev-parse', expected_source + '^{tree}').decode().strip(), 'Shader source tree differs')
    archive_path = c.file(directory, 'executed-source.tar')
    c.require(c.sha(archive_path) == report['source_archive_sha256'], 'Shader source archive changed')
    # The fresh reader's exact source checkout supplies the independent Git
    # object authority. Re-export once, compare bytes, and retain no replacement
    # for the original archive. No artifact chooses its own source baseline.
    digest = hashlib.sha256()
    command = ['git', '-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'archive', '--format=tar', expected_source]
    expected = subprocess.check_output(command, cwd=ROOT, timeout=metadata_remaining(),
                                       env=os.environ | {'GIT_LFS_SKIP_SMUDGE': '1'})
    digest.update(expected)
    c.require(digest.hexdigest() == report['source_archive_sha256'], 'Retained source archive differs from independent exact checkout')
    with tarfile.open(archive_path, 'r:') as archive:
        members = {member.name: member for member in archive.getmembers() if member.isfile()}
        names = {name for name in members if any(name == scope or name.startswith(scope + '/') for scope in SCOPES)
                 and not name.startswith('godot/.godot/')}
        c.require(set(report['source_inputs']) == names, 'Incomplete shader execution source inventory')
        attributes = {name: archive.extractfile(members[name]).read() for name in members
                      if name == '.gitattributes' or name.endswith('/.gitattributes')}
        if report.get('source_unchanged') is True:
            c.require(set(report.get('source_inputs_after', {})) == names, 'Missing actual postflight source hashes')
            changed = source_rewrites(report['source_inputs'], report['source_inputs_after'], archive_path)
            c.require(report.get('permitted_import_rewrites') == changed, 'Postflight import rewrite receipt differs')
        c.require(set(report['runtimes']) == runtime_paths(report['platform']), 'Incomplete actual shader runtime inventory')
        for name in names:
            metadata_remaining()
            data = archive.extractfile(members[name]).read()
            if name in report['runtimes']:
                pointer = re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n', data)
                runtime = report['runtimes'][name]
                c.require(pointer is not None and runtime['sha256'] == pointer[1].decode()
                          and runtime['bytes'] == int(pointer[2]) and report['source_inputs'][name] == runtime['sha256'],
                          'Selected shader runtime differs from committed LFS identity')
            else:
                import palette_checkout_custody as checkout
                forms = checkout.allowed_checkout_digests(name, data, attributes)
                if name in NORMALIZED_IMPORTS:
                    forms |= import_checkout_digests(data)
                c.require(report['source_inputs'][name] in forms, 'Shader actual checkout bytes differ from authenticated archive forms: ' + name)
                if report.get('source_unchanged') is True:
                    c.require(report['source_inputs_after'][name] in forms, 'Shader postflight checkout bytes differ from authenticated archive forms: ' + name)
        code = archive.extractfile(c.PALETTE).read()
        c.require(report['shader_hashes'] == {'full_crossfade': hashlib.sha256(code).hexdigest(),
                   'angle_bounded_crossfade': hashlib.sha256(c.BOUNDED + code).hexdigest()}, 'Shader variant digest differs from source')
        c.require(c.file(directory, 'source-inputs/candidate-full.gdshader').read_bytes() == code
                  and c.file(directory, 'source-inputs/candidate-bounded.gdshader').read_bytes() == c.BOUNDED + code,
                  'Retained executable shader copies differ from archived source')
        policy_bytes = archive.extractfile('godot/tests/support/ci_execution_policy.json').read()
        c.require(hashlib.sha256(policy_bytes).hexdigest() == c.policy.identity()['sha256']
                  and c._same(report['execution_policy'], c.policy.identity()), 'Shader policy is not source-bound')
        platform_name = 'windows' if report['platform'] == 'win32' else 'linux'
        provenance_names = [f'godot/addons/cybersand_native/runtime-provenance{("" if platform_name == "windows" else ".linux")}.json',
                            f'godot/addons/godot-rapier2d/runtime-provenance.{platform_name}.json']
        for name in provenance_names:
            manifest = json.loads(archive.extractfile(name).read())
            runtime = report['runtimes'].get(manifest['artifact'], {})
            c.require(runtime.get('sha256') == manifest['sha256'] and runtime.get('bytes') == manifest['size'],
                      'Shader runtime provenance differs')
            c.require(manifest.get('source_inputs'), 'Shader runtime missing build input provenance')
            for dependency, value in manifest['source_inputs'].items():
                canonical = archive.extractfile(dependency).read().replace(b'\r\n', b'\n')
                c.require(hashlib.sha256(canonical).hexdigest() == value, 'Shader runtime is stale for executed source: ' + dependency)
        if report['platform'] == 'linux':
            lock = json.loads(archive.extractfile('third_party/godot-runtime.lock.json').read())
            c.require(report['engine']['archive_sha256'] == lock['editor']['sha256'], 'Shader engine archive differs from source pin')
        else:
            import run_windows_godot_regressions as windows
            c.require(report['engine']['archive_sha512'] == windows.GODOT_SHA512, 'Shader engine archive differs from source pin')
    c.require(report['engine']['version'] == c.VERSION, 'Shader engine version differs')
    c.verify_host_paths(report)
    if report['platform'] == 'linux' and report['group'] == 'visual':
        baseline = c.file(directory, 'source-inputs/baseline-full.gdshader')
        c.require(c.sha(baseline) == c.BASELINE_SHADER
                  and baseline.read_bytes() == git('show', c.BASELINE + ':' + c.PALETTE), 'Native parity baseline bytes differ from preserved accepted source')


def cache_inventory(directory: Path) -> dict:
    rows = {}; total = 0
    for path in sorted(directory.rglob('*')):
        c.require(not path.is_symlink(), 'Isolated shader cache contains a symlink')
        if path.is_file():
            size = path.stat().st_size; total += size
            c.require(len(rows) < 10000 and total <= 1024 ** 3, 'Explicit shader cache evidence capacity exceeded')
            rows[path.relative_to(directory).as_posix()] = {'bytes': size, 'sha256': c.sha(path)}
    return rows


def cache_environment(directory: Path) -> dict:
    directory.mkdir(parents=True, exist_ok=False)
    mapping = {'XDG_DATA_HOME': 'data', 'XDG_CONFIG_HOME': 'config', 'XDG_CACHE_HOME': 'cache',
               'APPDATA': 'roaming', 'LOCALAPPDATA': 'local', 'MESA_SHADER_CACHE_DIR': 'mesa'}
    result = {}
    for key, folder in mapping.items():
        child = directory / folder; child.mkdir()
        result[key] = str(child.resolve())
    return result


def pid_exited(pid: object) -> bool:
    if type(pid) is not int or pid <= 0:
        return False
    if sys.platform == 'win32':
        import ctypes
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
        api.OpenProcess.restype = ctypes.c_void_p
        api.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
        api.WaitForSingleObject.restype = ctypes.c_uint32
        api.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = api.OpenProcess(0x100000, False, pid)
        if not handle:
            return ctypes.get_last_error() == 87
        try:
            return api.WaitForSingleObject(handle, 0) == 0
        finally:
            api.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    except OSError:
        return False
    return False


class CompilerObserver:
    def __init__(self, log: Path, nonce: str, source: str):
        self.log = log; self.nonce = nonce; self.source = source
        self.stop = threading.Event(); self.observations = []
        self.thread = threading.Thread(target=self.run, daemon=True)

    def run(self):
        if sys.platform != 'win32':
            self.observations.append({'status': 'unavailable', 'reason': 'not_windows', 'requested_pid': None})
            return
        try:
            from palette_windows_compiler import observe_loaded_compiler
            # Observe at most three bounded attempts after the actual engine
            # emits its nonce/source-bound PID. No process is launched or killed
            # by this reader except the observer's own bounded helper.
            while not self.stop.is_set() and len(self.observations) < 3:
                if self.log.exists():
                    with self.log.open('rb') as handle:
                        handle.seek(0, os.SEEK_END); size = handle.tell(); handle.seek(max(0, size - 512 * 1024))
                        text = handle.read().decode('utf-8', errors='replace')
                    text = text.rsplit('\n', 1)[0]
                    for row in c.packets(text, c.CONTEXT):
                        if row.get('nonce') == self.nonce and row.get('source_revision') == self.source:
                            observation = observe_loaded_compiler(row['process_id'])
                            self.observations.append(observation)
                            if observation.get('status') == 'observed' or observation.get('helper_joined') is False:
                                return
                            break
                self.stop.wait(1)
        except Exception as error:
            self.observations.append({'status': 'unavailable', 'reason': f'observer_error: {type(error).__name__}: {error}'})

    def start(self):
        self.thread.start()

    def finish(self) -> dict:
        self.stop.set()
        self.thread.join(c.observer_join_seconds())
        joined = not self.thread.is_alive() and all(row.get('helper_joined') is not False for row in self.observations)
        return {'observer_joined': joined, 'observations': self.observations or [
            {'status': 'unavailable', 'reason': 'no_live_source_bound_engine_pid_observed'}],
            'scope': 'loaded module path/version/file digest when observed; no claim of compiler-only timing'}


def seal(directory: Path) -> None:
    files = {}
    for path in sorted(directory.rglob('*')):
        metadata_remaining()
        if path.is_file() and path != directory / 'manifest.json':
            files[path.relative_to(directory).as_posix()] = {'bytes': path.stat().st_size, 'sha256': c.sha(path)}
    metadata_remaining()
    c.write(directory / 'manifest.json', {'schema': 'palette-qualification-manifest-v1', 'files': files})


def verify_directory(directory: Path, source: str, *, sealed=True) -> dict:
    with metadata_budget('complete retained cohort readback', c.policy.watchdog_seconds('godot_metadata_seconds')):
        return _verify_directory(directory, source, sealed=sealed)


def _verify_directory(directory: Path, source: str, *, sealed=True) -> dict:
    c.require(not directory.is_symlink(), 'Shader cohort directory is a symlink')
    if sealed:
        inventory = json.loads(c.file(directory, 'manifest.json').read_text())
        actual = {path.relative_to(directory).as_posix() for path in directory.rglob('*')
                  if path.is_file() and path != directory / 'manifest.json'}
        c.require(set(inventory['files']) == actual, 'Shader sealed artifact inventory differs')
        for name, record in inventory['files'].items():
            metadata_remaining()
            path = c.file(directory, name)
            c.require(path.stat().st_size == record['bytes'] and c.sha(path) == record['sha256'], 'Shader artifact bytes changed: ' + name)
    report = json.loads(c.file(directory, 'qualification.json').read_text())
    c.require(report.get('schema') == 'palette-shader-qualification-v2' and report.get('completed') is True
              and report.get('errors') == [] and report.get('source_unchanged') is True,
              'Shader cohort failed, incomplete or changed source')
    c.require(not sealed or report.get('status') == 'passed', 'Sealed shader cohort has no passing original verdict')
    c.require(report.get('python_packages') == {name: version for name, version in
              (item.split('==') for item in c.PYTHON_PACKAGES)}, 'Shader pixel-reader package identity differs')
    verify_source(directory, report, source)
    expected = c.cohort_plan(report['platform'], report['group'], report['shard_index'])
    c.require(report.get('shard_count') == (2 if report['group'] == 'visual' else 1)
              and report.get('budgets') == c.budgets(report['platform'], report['group'], report['shard_index']),
              'Shader cohort budget or shard registration differs')
    c.require(report['case_plan'] == expected and [row['case'] for row in report['rows']] == expected,
              'Incomplete/duplicate shader case inventory')
    imported = report['import']
    import_log = c.file(directory, 'import.log')
    c.require(c.sha(import_log) == report['import_log_sha256'], 'Original shader import log changed')
    c.verify_process(imported, {'name': 'import', 'rendered': False, 'timeout': c.policy.watchdog_seconds('godot_import_seconds')},
                     import_log.read_text(encoding='utf-8'), report)
    summaries = []
    for case, row in zip(expected, report['rows']):
        c.require(row.get('directory') == case['name'], 'Shader case escaped its registered artifact directory')
        reduced = c.verify_case(case, row, directory / row['directory'], report)
        c.require(reduced == row['readback'], 'Independent shader reduction differs from original report')
        compiler = json.loads(c.file(directory / row['directory'], 'compiler-observation.json').read_text())
        c.require(compiler == row['compiler'] and compiler.get('observer_joined') is True,
                  'Compiler observer did not retire or changed receipt')
        observations = compiler.get('observations')
        c.require(isinstance(observations, list) and 1 <= len(observations) <= 3
                  and all(value.get('status') in ('observed', 'unavailable') and value.get('helper_joined') is not False
                          and (value['status'] != 'unavailable' or isinstance(value.get('reason'), str) and bool(value['reason']))
                          for value in observations), 'Compiler availability or helper cleanup was not explicitly observed')
        for observation in observations:
            if observation.get('status') == 'observed':
                import palette_windows_compiler as compiler_reader
                compiler_reader._decode_reply(json.dumps(observation).encode(), reduced['context']['process_id'])
                c.require(report['platform'] == 'win32' and observation.get('requested_pid') == reduced['context']['process_id'],
                          'Compiler module belongs to another actual engine')
                c.require(observation['process']['image_path'].replace('\\','/').casefold()
                          == reduced['context']['engine_path'].replace('\\','/').casefold()
                          and observation.get('helper_joined') is True
                          and observation.get('helper_natural_completion') is True
                          and observation.get('helper_returncode') == 0
                          and c._same(observation.get('execution_policy'), c.policy.identity()),
                          'Compiler observation did not bind the live engine image and policy')
        c.require(row.get('known_processes_exited') is True, 'Engine/wrapper exit not observed; unsafe cohort continuation')
        summaries.append({'case': case['name'], **reduced})
    if report['group'] == 'main-cache':
        cold, warm = report['rows']
        c.require(cold['cache_before'] == {} and cold['cache_after'] == warm['cache_before']
                  and cold['cache_root'] == warm['cache_root'], 'Cold/warm managed-cache lineage differs')
        c.require(any('/shader_cache/' in '/' + name for name in cold['cache_after']),
                  'No observed Godot shader cache was retained for the warm process')
        c.require(cold['cache_after'] == cache_inventory(directory / 'cold-cache-snapshot')
                  and warm['cache_after'] == cache_inventory(directory / 'main-cache'),
                  'Retained cold/warm cache bytes differ from their original inventories')
    elif report['platform'] == 'linux' and report['shard_index'] == 1:
        import compare_pace003_palette_atlas as atlas
        comparison = atlas.compare(directory / 'atlas-baseline-full/captures', directory / 'atlas-candidate-full/captures')
        c.require(comparison['passed'] and comparison == report['native_parity'], 'Original native full-path byte parity failed')
    return {'schema': 'palette-shader-readback-v2', 'source_commit': source, 'platform': report['platform'],
            'group': report['group'], 'shard_index': report['shard_index'], 'cases': summaries, 'status': 'passed',
            'scope': 'registered actual shader/backend/managed-cache and Main controls; no physical device or universal performance claim'}


def verify_suite(directory: Path, source: str) -> dict:
    import numpy as np
    required = {(row['platform'], row['group'], row['shard_index']) for row in c.hosted_plan()['include']}
    observed = {}; originals = {}
    for path in sorted(directory.rglob('qualification.json')):
        result = verify_directory(path.parent, source)
        key = result['platform'], result['group'], result['shard_index']
        c.require(key in required and key not in observed, 'Duplicate/unregistered shader cohort')
        observed[key] = result; originals[key] = path.parent
    c.require(set(observed) == required, 'Missing actual Linux/Windows visual or Main cache cohort')
    # Compare the SAME bounded source variant across the actual backends. The
    # separate native full-path baseline comparison remains byte-exact; there
    # is deliberately no full-versus-bounded equivalence assertion.
    with metadata_budget('cross-backend bounded pixel comparison'):
        left = originals[('linux', 'visual', 0)] / 'bounded-oracle/captures'
        right = originals[('win32', 'visual', 0)] / 'bounded-oracle/captures'
        a = json.loads(c.file(left, 'crossfade.json').read_text()); b = json.loads(c.file(right, 'crossfade.json').read_text())
        differences = []
        for x, y in zip(a['rows'], b['rows']):
            c.require((x['condition'], x['blend']) == (y['condition'], y['blend']), 'Cross-backend bounded frames differ in inputs')
            error = float(np.max(np.abs(c.pixels(left, x['capture'], (64, 36)) - c.pixels(right, y['capture'], (64, 36)))))
            c.require(error <= c.TOLERANCE, 'Same bounded variant differs across actual native/ANGLE backends beyond fixed tolerance')
            differences.append({'condition': x['condition'], 'blend': x['blend'], 'max_rgba_difference': error})
    return {'schema': 'palette-shader-suite-v2', 'status': 'passed', 'source_commit': source,
            'cohorts': 6, 'process_cases': sum(len(value['cases']) for value in observed.values()),
            'bounded_cross_backend_frames': differences, 'tolerance': c.TOLERANCE,
            'scope': 'same bounded source across native/ANGLE plus separate exact native full parity and actual Main cache pairs'}


def prepare_engine(archive: Path, platform_name: str) -> tuple[Path, dict]:
    if platform_name == 'win32':
        import run_windows_godot_regressions as windows
        archive_digest = hashlib.sha512(archive.read_bytes()).hexdigest()
        c.require(archive_digest == windows.GODOT_SHA512, 'Official Windows engine pin mismatch')
    else:
        lock = json.loads((ROOT / 'third_party/godot-runtime.lock.json').read_text())
        c.require(archive.stat().st_size == lock['editor']['size'] and c.sha(archive) == lock['editor']['sha256'], 'Official Linux engine pin mismatch')
    folder = archive.parent / ('palette-engine-' + uuid.uuid4().hex); folder.mkdir()
    with zipfile.ZipFile(archive) as bundle:
        c.require(bundle.testzip() is None, 'Official Godot ZIP integrity failed'); bundle.extractall(folder)
    binary = folder / ('Godot_v4.7-stable_win64_console.exe' if platform_name == 'win32' else 'Godot_v4.7-stable_linux.x86_64')
    binary.chmod(0o755)
    version = subprocess.check_output([str(binary), '--version'], text=True, timeout=metadata_remaining()).strip()
    c.require(version == c.VERSION, 'Actual engine version differs')
    if platform_name == 'win32':
        return binary, {'version': version, 'archive_size': archive.stat().st_size, 'archive_sha512': archive_digest,
                        'console_sha256': c.sha(binary), 'runtime_sha256': c.sha(folder / 'Godot_v4.7-stable_win64.exe')}
    return binary, {'version': version, 'archive_sha256': c.sha(archive), 'runtime_sha256': c.sha(binary)}


def execute(output: Path, source: str, archive: Path, group: str, shard_index: int) -> int:
    import run_godot_regressions as runner
    import run_windows_godot_regressions as windows
    from check_repository import verify_runtime, verify_rapier_overrides
    c.require(sys.platform in ('linux', 'win32'), 'Actual Windows/Linux shader hosts only')
    output.mkdir(parents=True, exist_ok=False)
    report = {'schema': 'palette-shader-qualification-v2', 'source_commit': source,
        'platform': sys.platform, 'group': group, 'completed': False, 'errors': [], 'rows': [],
        'case_plan': c.cohort_plan(sys.platform, group, shard_index), 'execution_policy': c.policy.identity(),
        'shard_index': shard_index, 'shard_count': 2 if group == 'visual' else 1,
        'budgets': c.budgets(sys.platform, group, shard_index),
        'python_packages': {item.split('==')[0]: importlib.metadata.version(item.split('==')[0]) for item in c.PYTHON_PACKAGES},
        'run_id': os.getenv('GITHUB_RUN_ID'), 'run_attempt': os.getenv('GITHUB_RUN_ATTEMPT')}
    before = {}
    def save(): c.write(output / 'qualification.json', report)
    def run(binary, case, directory, environment):
        with contextlib.redirect_stdout(io.StringIO()):
            return runner.run_case(str(binary), case, directory, 'source-bound shader qualification', env=environment)
    try:
        with metadata_budget('execution source/runtime preflight'):
            c.require(git('rev-parse', 'HEAD').decode().strip() == source, 'Shader execution checkout differs from expected source')
            git('diff', '--exit-code', 'HEAD', '--', *SCOPES, ':!godot/.godot')
            before = source_inputs()
            c.require(REQUIRED_APPARATUS.issubset(before), 'All shader apparatus and policy dependencies must be committed')
            c.require(all('godot/tests/' + case['script'] in before for case in report['case_plan']), 'Shader apparatus must be committed before qualification')
            report.update(source_tree=git('rev-parse', 'HEAD^{tree}').decode().strip(), source_inputs=before)
            report['runtimes'] = {}
            for name in runtime_paths(sys.platform):
                data = (ROOT / name).read_bytes()
                c.require(data.startswith(b'MZ' if sys.platform == 'win32' else b'\x7fELF'), 'Unmaterialized shader runtime')
                report['runtimes'][name] = {'sha256': c.sha(ROOT / name), 'bytes': len(data)}
            native_manifest = 'runtime-provenance.json' if sys.platform == 'win32' else 'runtime-provenance.linux.json'
            native = json.loads((ROOT / 'godot/addons/cybersand_native' / native_manifest).read_text())
            c.require(set(native['source_inputs']) == windows.native_input_paths(ROOT) and not verify_runtime(ROOT, native), 'Shader native runtime/source provenance mismatch')
            c.require(not verify_rapier_overrides(ROOT, json.loads((ROOT / 'godot/third_party/rapier2d.lock.json').read_text())), 'Shader Rapier provenance mismatch')
            binary, report['engine'] = prepare_engine(archive, sys.platform)
            report['host_paths'] = {'source_root': str(ROOT.resolve()), 'project_root': str((ROOT / 'godot').resolve()),
                'launcher': str(binary.resolve()), 'engine': str((binary.parent / 'Godot_v4.7-stable_win64.exe').resolve()) if sys.platform == 'win32' else str(binary.resolve())}
            source_code = (ROOT / c.PALETTE).read_bytes()
            report['shader_hashes'] = {'full_crossfade': hashlib.sha256(source_code).hexdigest(),
                'angle_bounded_crossfade': hashlib.sha256(c.BOUNDED + source_code).hexdigest()}
            sources = output / 'source-inputs'; sources.mkdir()
            (sources / 'candidate-full.gdshader').write_bytes(source_code)
            (sources / 'candidate-bounded.gdshader').write_bytes(c.BOUNDED + source_code)
            if sys.platform == 'linux' and group == 'visual':
                (sources / 'baseline-full.gdshader').write_bytes(git('show', c.BASELINE + ':' + c.PALETTE))
            report['source_archive_sha256'] = export_source(output / 'executed-source.tar', source)
            save(); verify_source(output, report, source)
            environment = os.environ | {'CYBERSAND_SOURCE_REVISION': source, 'GODOT_SILENCE_ROOT_WARNING': '1'}
            import_env = environment | cache_environment(output / 'import-cache')
        imported, failed = run(binary, runner.Case('import', ('--editor', '--quit'), c.policy.watchdog_seconds('godot_import_seconds'), 0), output, import_env)
        with metadata_budget('import receipt and cache setup'):
            report['import'] = imported; report['import_log_sha256'] = c.sha(output / imported['log']); save()
            c.require(not failed and imported.get('natural_completion') is True, 'Shader import did not pass naturally')
            main_cache = output / 'main-cache'
            main_environment = None
        for case in report['case_plan']:
            with metadata_budget('case preparation: ' + case['name']):
                directory = output / case['name']; directory.mkdir(); captures = directory / 'captures'; captures.mkdir()
                cache_root = main_cache if group == 'main-cache' else directory / 'isolated-cache'
                if group == 'main-cache' and main_environment is None:
                    main_environment = cache_environment(main_cache)
                cache_env = main_environment if group == 'main-cache' else cache_environment(cache_root)
                nonce = uuid.uuid4().hex
                env = environment | cache_env | {'CYBERSAND_SHADER_NONCE': nonce, 'CYBERSAND_SHADER_CACHE_STATE': case['cache'],
                    'CYBERSAND_SHADER_CAPTURE': str(captures), 'CYBERSAND_PALETTE_CROSSFADE_OUTPUT': str(captures),
                    'CYBERSAND_PRESENTATION_EVIDENCE': str(captures), 'CYBERSAND_ATLAS_OUTPUT': str(captures)}
                if case['kind'] == 'atlas': env['CYBERSAND_ATLAS_SHADER'] = str(sources / (case['arm'] + '.gdshader'))
                driver = 'opengl3_angle' if case['rendered'] and sys.platform == 'win32' else 'opengl3'
                engine_case = runner.Case(case['name'], ('--rendering-driver', driver, '--script', 'res://tests/' + case['script']), case['timeout'], 0, case['rendered'])
                before_cache = cache_inventory(cache_root)
            observer = CompilerObserver(directory / (case['name'] + '.log'), nonce, source); observer.start()
            try:
                process, failed = run(binary, engine_case, directory, env)
            finally:
                compiler = observer.finish()
                c.write(directory / 'compiler-observation.json', compiler)
            with metadata_budget('case retained readback and cleanup: ' + case['name']):
                c.write(directory / 'process.json', process)
                row = {'case': case, 'directory': case['name'], 'nonce': nonce, 'process': process,
                       'log_sha256': c.sha(directory / process['log']), 'cache_root': str(cache_root),
                       'cache_before': before_cache, 'cache_after': cache_inventory(cache_root), 'compiler': compiler, 'errors': []}
                if group == 'main-cache' and case['cache'] == 'cold':
                    shutil.copytree(cache_root, output / 'cold-cache-snapshot')
                report['rows'].append(row)
                try:
                    row['readback'] = c.verify_case(case, row, directory, report)
                except Exception as error:
                    row['errors'].append(f'{type(error).__name__}: {error}'); report['errors'].append(case['name'] + ': ' + row['errors'][-1])
                try:
                    context = c.one((directory / process['log']).read_text(encoding='utf-8'), c.CONTEXT)
                    c.verify_context(context, case, report, row)
                    row['known_processes_exited'] = (process.get('natural_completion') is True
                        and pid_exited(process.get('pid')) and pid_exited(context.get('process_id')) and compiler['observer_joined'])
                    if case['kind'] == 'main':
                        footer = c.one((directory / process['log']).read_text(encoding='utf-8'), c.MAIN_RESULT)
                        row['known_processes_exited'] &= footer.get('joined_workers') == 2 and footer.get('retired_sessions') == 2
                except Exception:
                    row['known_processes_exited'] = False
                save()
            print(json.dumps({'case': case['name'], 'status': process['status'], 'seconds': process['seconds'], 'errors': row['errors']}), flush=True)
            if not row['known_processes_exited']:
                report['errors'].append(case['name'] + ': cleanup not proved; remaining cases unexecuted')
                break
        report['completed'] = len(report['rows']) == len(report['case_plan'])
    except Exception as error:
        report['errors'].append(f'{type(error).__name__}: {error}')
    finally:
        try:
            with metadata_budget('execution source postflight'):
                report['source_inputs_after'] = source_inputs()
                report['permitted_import_rewrites'] = source_rewrites(before, report['source_inputs_after'], output / 'executed-source.tar')
                report['source_unchanged'] = bool(before)
        except Exception as error:
            report['source_unchanged'] = False
            report['errors'].append('Final source custody: ' + str(error))
        save()
    try:
        with metadata_budget('internal final readback', c.policy.watchdog_seconds('godot_metadata_seconds')):
            if group == 'visual' and sys.platform == 'linux' and shard_index == 1 and report['completed']:
                import compare_pace003_palette_atlas as atlas
                report['native_parity'] = atlas.compare(output / 'atlas-baseline-full/captures', output / 'atlas-candidate-full/captures')
                c.require(report['native_parity']['passed'], 'Native full shader differs from original byte-exact atlas')
            save()
            result = verify_directory(output, source, sealed=False)
            report['status'] = 'passed'; c.write(output / 'readback.json', result)
    except Exception as error:
        report['status'] = 'failed'; report['errors'].append('Final readback: ' + str(error))
    try:
        with metadata_budget('complete original artifact seal'):
            save(); seal(output)
    except Exception as error:
        report['status'] = 'failed'; report['errors'].append('Artifact seal: ' + str(error)); save()
    print('PALETTE_SHADER_QUALIFICATION ' + json.dumps({key: report[key] for key in ('status', 'completed', 'errors')}))
    return 0 if report['status'] == 'passed' else 1


def prepare_dependencies(output: Path, source: str, archive: Path | None, *, reader_only=False) -> int:
    """Hosted setup with separate full dependency clocks and retained receipts."""
    output.mkdir(parents=True, exist_ok=False)
    result = {'schema': 'palette-dependency-preparation-v1', 'source_commit': source,
              'execution_policy': c.policy.identity(), 'commands': [], 'status': 'failed'}
    setup_remaining = c.policy.watchdog_seconds('operation_seconds')

    def command(label, arguments, seconds):
        started = time.monotonic()
        row = {'label': label, 'command': arguments, 'allowance_seconds': seconds, 'status': 'failed'}
        result['commands'].append(row)
        try:
            subprocess.run(arguments, cwd=ROOT, check=True, timeout=seconds)
            row['status'] = 'passed'
        finally:
            row['seconds'] = time.monotonic() - started
            c.write(output / 'preparation.json', result)

    def setup(label, arguments):
        nonlocal setup_remaining
        c.require(setup_remaining > 0, 'Shader dependency setup aggregate allowance exhausted')
        started = time.monotonic()
        try:
            command(label, arguments, setup_remaining)
        finally:
            setup_remaining -= time.monotonic() - started

    try:
        started = time.monotonic()
        try:
            with metadata_budget('dependency source check', setup_remaining):
                result['observed_source'] = git('rev-parse', 'HEAD').decode().strip()
        finally:
            setup_remaining -= time.monotonic() - started
        c.require(result['observed_source'] == source, 'Shader preparation checkout differs from exact source')
        seconds = c.policy.watchdog_seconds('dependency_prepare_seconds')
        if not reader_only:
            c.require(archive is not None and not archive.exists(), 'Refusing missing/reused engine archive output')
            setup('lfs-setup', ['git', 'lfs', 'install', '--local'])
            if sys.platform == 'linux':
                for program in ('xvfb-run', 'Xvfb', 'xauth'):
                    c.require(shutil.which(program) is not None, 'Missing hosted graphical prerequisite: ' + program)
                setup('actual-graphical-packages', ['dpkg-query', '-W', 'xvfb', 'xauth', 'libgl1-mesa-dri', 'libglx-mesa0'])
                url = json.loads((ROOT / 'third_party/godot-runtime.lock.json').read_text())['editor']['origin_url']
            else:
                c.require(sys.platform == 'win32', 'Unregistered hosted shader OS')
                url = 'https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_win64.exe.zip'
            command('lfs-materialization', ['git', 'lfs', 'pull', '--include=' + ','.join(sorted(runtime_paths(sys.platform))), '--exclude='], seconds)
            command('official-engine-download', ['curl', '--fail', '--location', '--connect-timeout', '60',
                    '--max-time', str(seconds), '--output', str(archive), url],
                    seconds + c.policy.watchdog_seconds('terminate_grace_seconds'))
        command('pinned-pixel-reader-wheels', [sys.executable, '-m', 'pip', 'install', '--only-binary=:all:', *c.PYTHON_PACKAGES], seconds)
        for script in ('test_palette_qualification.py', 'test_palette_windows_compiler.py', 'test_palette_checkout_custody.py'):
            for optimize in ([], ['-O']):
                setup('portable-controls-' + script + ('-optimized' if optimize else ''),
                      [sys.executable, *optimize, str(ROOT / 'tools/play' / script)])
        result['python_packages'] = {item.split('==')[0]: importlib.metadata.version(item.split('==')[0]) for item in c.PYTHON_PACKAGES}
        result['status'] = 'passed'
    except Exception as error:
        result['error'] = f'{type(error).__name__}: {error}'
    c.write(output / 'preparation.json', result)
    print(json.dumps(result, sort_keys=True), flush=True)
    return 0 if result['status'] == 'passed' else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-source-sha')
    parser.add_argument('--godot-archive', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--group', choices=('visual', 'main-cache'))
    parser.add_argument('--shard-index', type=int, default=0)
    parser.add_argument('--plan-json', action='store_true')
    parser.add_argument('--prepare-dependencies', action='store_true')
    parser.add_argument('--prepare-reader', action='store_true')
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--verify-suite', action='store_true')
    args = parser.parse_args()
    if args.plan_json:
        print(json.dumps({**c.hosted_plan(), 'reducer': c.reducer_budget()}, separators=(',', ':'))); return 0
    c.require(args.output is not None and args.expected_source_sha is not None, 'Exact source and artifact directory required')
    if args.prepare_dependencies or args.prepare_reader:
        return prepare_dependencies(args.output.resolve(), args.expected_source_sha,
                                    args.godot_archive.resolve() if args.godot_archive is not None else None,
                                    reader_only=args.prepare_reader)
    if args.verify_suite:
        c.require(not args.output.is_symlink(), 'Shader suite directory is a symlink')
        print(json.dumps(verify_suite(args.output.absolute(), args.expected_source_sha), sort_keys=True)); return 0
    if args.verify_only:
        value = verify_directory(args.output.absolute(), args.expected_source_sha)
        print(json.dumps({key: value[key] for key in ('source_commit', 'platform', 'group', 'status')})); return 0
    c.require(args.group is not None and args.godot_archive is not None, 'Shader execution requires group and pinned engine archive')
    return execute(args.output.resolve(), args.expected_source_sha, args.godot_archive.resolve(), args.group, args.shard_index)


if __name__ == '__main__':
    raise SystemExit(main())
