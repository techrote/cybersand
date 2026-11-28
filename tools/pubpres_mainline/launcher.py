"""Portable owner entry point; uses only the source and tools shipped in this ZIP."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import uuid
import zipfile
import common
import package as evaluator

MAX_LOG = 16 * 1024**2
MAX_COLLECTION = 128 * 1024**2


def environment(folder: Path, record: dict, receipt: Path, scene: str):
    value = common.selected_environment(evaluator.lab.dependency_environment(folder))
    value.update(PYTHONDONTWRITEBYTECODE='1', PYTHONUTF8='1', GODOT_SILENCE_ROOT_WARNING='1',
                 CYBERSAND_SOURCE_REVISION=record['source_commit'],
                 CYBERSAND_PLAYABILITY_OWNER_RECEIPT=str(receipt), CYBERSAND_FINAL_SCENE=scene,
                 APPDATA=str(folder / 'userdata/roaming'), LOCALAPPDATA=str(folder / 'userdata/local'),
                 XDG_DATA_HOME=str(folder / 'userdata/roaming'))
    for path in ('userdata/roaming', 'userdata/local'):
        (folder / path).mkdir(parents=True, exist_ok=True)
    return value


def run_child(argv, *, cwd, env, log: Path, timeout=None):
    """Preserve early readiness output while bounding the local owner log."""
    started = time.monotonic()
    process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    status = {'bytes_observed': 0, 'bytes_saved': 0, 'truncated': False}
    errors = []

    def pump():
        try:
            with log.open('xb') as target:
                while chunk := process.stdout.read1(65536):
                    status['bytes_observed'] += len(chunk)
                    available = max(0, MAX_LOG - status['bytes_saved'])
                    if available:
                        target.write(chunk[:available]); target.flush()
                        status['bytes_saved'] += min(available, len(chunk))
                    status['truncated'] = status['bytes_observed'] > status['bytes_saved']
                    sys.stdout.buffer.write(chunk); sys.stdout.buffer.flush()
        except BaseException as error:
            errors.append(str(error))

    reader = threading.Thread(target=pump, name='pubpres-owner-log', daemon=True)
    reader.start()
    timed_out = False
    try:
        code = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        # The process PID is held by Popen and only this child tree is stopped.
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=20, check=False)
        code = process.wait(timeout=20)
    finally:
        reader.join(timeout=20)
    common.require(not reader.is_alive() and not errors, 'Owner log reader failed: ' + '; '.join(errors))
    return {'argv': argv, 'pid': process.pid, 'exit_code': code, 'timed_out': timed_out,
            'wall_seconds': time.monotonic() - started, 'log_sha256': common.digest(log), **status}


def open_workbench(args):
    common.require(os.name == 'nt', 'The owner evaluator runs on Windows')
    folder = args.package.resolve(strict=True)
    print('Verifying the delivered source, native build, engine and portable authoring tools...', flush=True)
    # Prior generated imports and this installation's user data may exist. Every
    # original payload byte and every tracked source file must still be exact.
    record = evaluator.verify(folder, pristine=False, execute_tools=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    location = folder / 'diagnostics' / stamp
    location.mkdir(parents=True, exist_ok=False)
    receipt = location / 'owner-ready.json'
    env = environment(folder, record, receipt, args.scene)
    if args.hosted_smoke and args.scene != 'persistent':
        env['CYBERSAND_PLAYABILITY_OWNER_QUIT_AFTER_READY'] = '1'
    if args.recording == 'off':
        # The existing production recorder is gated by this receipt variable.
        # The startup observer still needs it, so recording-off is a separately
        # explicit source selector implemented by the owner diagnostics hook.
        env['CYBERSAND_PLAYABILITY_OWNER_RECORDING'] = '0'
    else:
        env['CYBERSAND_PLAYABILITY_OWNER_RECORDING'] = '1'
    project = folder / 'source/godot'
    engine = folder / evaluator.base.CONSOLE
    common_flags = ['--path', str(project), '--render-thread', 'safe']
    importer = run_child([str(engine), *common_flags, '--headless', '--audio-driver', 'Dummy', '--editor', '--quit'],
                         cwd=folder, env=env, log=location / 'import.log', timeout=180)
    launch = {'schema': 'pubpres-mainline-owner-launch-v1', 'source_commit': record['source_commit'],
              'source_tree': record['source_tree'], 'scene': args.scene, 'selectors': common.SELECTORS,
              'render_thread': 'safe', 'recording': args.recording,
              'manifest_sha256': common.digest(folder / evaluator.MANIFEST), 'import': importer,
              'physical_owner_evaluated': False}
    common.write_json(location / 'launch.json', launch)
    common.require(importer['exit_code'] == 0 and not importer['timed_out'], 'Godot import failed; see ' + str(location))
    flags = []
    for name in ('audio_driver', 'rendering_method', 'rendering_driver', 'quit_after'):
        value = getattr(args, name)
        if value is not None:
            flags += ['--' + name.replace('_', '-'), str(value)]
    if args.scene == 'persistent':
        argv = [str(engine), *common_flags, *flags, '--', '--persistent-areas']
    else:
        observer = folder / 'source/tools/pubpres_recovery_windows/owner_start.gd'
        argv = [str(engine), *common_flags, *flags, '--script', str(observer), '--', '--workbench']
    print('Opening CyberSand; diagnostic evidence stays in this installation.', flush=True)
    application = run_child(argv, cwd=folder, env=env, log=location / 'workbench.log',
                            timeout=300 if args.hosted_smoke else None)
    launch['application'] = application
    if receipt.is_file():
        launch['owner_ready_sha256'] = common.digest(receipt)
    launch['status'] = 'clean-exit' if application['exit_code'] == 0 and not application['timed_out'] else 'failed'
    common.write_json(location / 'launch.json', launch)
    print('PUBPRES_MAINLINE_LAUNCH_RESULT ' + json.dumps({'path': str(location), 'status': launch['status']}), flush=True)
    return int(launch['status'] != 'clean-exit')


def collect(folder: Path, destination: Path | None):
    """Collect only explicit performance diagnostics, never authored worlds."""
    folder = folder.resolve(strict=True)
    manifest = evaluator.read_manifest(folder)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    destination = destination.resolve() if destination else folder / ('PUBPRES-results-' + stamp + '.zip')
    common.require(not destination.exists(), 'Refuse to replace an existing evidence archive')
    inputs = [folder / evaluator.MANIFEST, folder / (evaluator.MANIFEST + '.sha256')]
    if (folder / 'diagnostics').is_dir():
        inputs += list((folder / 'diagnostics').rglob('*.json')) + list((folder / 'diagnostics').rglob('*.log'))
    userdata = folder / 'userdata/roaming/Godot/app_userdata'
    if userdata.is_dir():
        for profile in userdata.iterdir():
            recorder = profile / 'workbench/pubpres-gameplay'
            if recorder.is_dir():
                inputs += list(recorder.glob('*.jsonl'))
    entries, omitted, used = {}, [], 0
    for path in sorted(set(inputs), key=lambda p: p.stat().st_mtime if p.exists() else 0, reverse=True):
        if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(folder):
            omitted.append({'path': str(path), 'reason': 'not a regular installation-local diagnostic'})
            continue
        name = path.relative_to(folder).as_posix()
        size = path.stat().st_size
        if size > MAX_LOG or used + size > MAX_COLLECTION:
            omitted.append({'path': name, 'reason': 'bounded collection size', 'bytes': size})
            continue
        entries[name] = path
        used += size
    destination.parent.mkdir(parents=True, exist_ok=True)
    collected, copied_bytes = {}, 0
    with zipfile.ZipFile(destination, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, path in entries.items():
            # The recorder may still be active. Hash the exact bounded bytes
            # actually copied, not a later version of the same live file.
            with path.open('rb') as stream:
                data = stream.read(MAX_LOG + 1)
            if len(data) > MAX_LOG or copied_bytes + len(data) > MAX_COLLECTION:
                omitted.append({'path': name, 'reason': 'grew beyond collection allowance'})
                continue
            archive.writestr(name, data)
            collected[name] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
            copied_bytes += len(data)
        archive.writestr('COLLECTION.json', common.canonical({'schema': 'pubpres-mainline-owner-collection-v1',
            'source_commit': manifest['source_commit'], 'source_tree': manifest['source_tree'],
            'files': collected, 'omitted': omitted, 'uploads_performed': False,
            'scope': 'Bounded local diagnostic snapshot; no authored constructions or unrelated user profile files.'}))
    print(json.dumps({'archive': str(destination), 'sha256': common.digest(destination),
                      'bytes': destination.stat().st_size, 'diagnostic_files': len(collected), 'omitted': len(omitted)}))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('open', 'verify', 'collect'))
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--scene', choices=evaluator.SCENES, default='ordinary')
    parser.add_argument('--hosted-smoke', action='store_true')
    parser.add_argument('--recording', choices=('on', 'off'), default='on')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--audio-driver', choices=('Dummy',))
    parser.add_argument('--rendering-method', choices=('gl_compatibility',))
    parser.add_argument('--rendering-driver', choices=('opengl3',))
    parser.add_argument('--quit-after', type=int)
    args = parser.parse_args()
    # Verification itself needs Git for the independent committed-source
    # reader. Resolve it from the delivered stack before any source check;
    # the owner need not have a developer Git/Python/compiler installation.
    portable_environment = evaluator.lab.dependency_environment(args.package.resolve(strict=True))
    os.environ.clear()
    os.environ.update(portable_environment)
    if args.command == 'open':
        return open_workbench(args)
    if args.command == 'collect':
        return collect(args.package, args.output)
    result = evaluator.verify(args.package, pristine=False, execute_tools=os.name == 'nt')
    print(json.dumps({'status': 'passed', 'source_commit': result['source_commit'], 'source_tree': result['source_tree']}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
