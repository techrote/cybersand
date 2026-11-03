"""Authenticate and run the separately registered GCR causal lanes."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from run_gcr_creep import ROOT, git, linux, native_identity, read, sha, source_inputs, verify_project, write

LANES = {
    'timing': ('GCR-CAUSAL-TC-001-2026-11-03', 'timing-contact-protocol.json', 'gcr_timing_capture.gd', 12),
    'event': ('GCR-CAUSAL-EVENT-001-2026-11-03', 'event-protocol.json', 'gcr_event_capture.gd', 8),
}
EXISTING = ['test_gcr_fleet_controls', 'test_gcr_rest_bridge', 'test_gcr_rest_material_freshness',
            'test_gcr_protocol', 'test_rem002_body_granular', 'test_rem003_player_granular',
            'test_actor_rig_integration', 'test_gcr_envelope']
NEW_TESTS = ['test_gcr_causal_arena', 'test_gcr_event_causal']
NEW_PROJECT_PATHS = {
    'godot/qualification/gcr_causal_arena.gd', 'godot/qualification/gcr_timing_capture.gd',
    'godot/qualification/gcr_event_capture.gd', 'godot/tests/test_gcr_causal_arena.gd',
    'godot/tests/test_gcr_event_causal.gd',
}


def utc():
    return datetime.now(timezone.utc).isoformat()


def run(command, log, timeout, env, platform, linux_engine):
    """Use an owned process tree; GNU timeout also fences the actual WSL child."""
    command = list(command)
    if platform == 'linux':
        index = command.index(linux_engine)
        command[index:index] = ['timeout', '--signal=TERM', '--kill-after=10s', str(timeout) + 's']
    started, wall = time.monotonic(), utc()
    flags = (subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW) if os.name == 'nt' else 0
    with log.open('xb') as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, creationflags=flags)
        timed_out = False
        try:
            code = process.wait(timeout=timeout + (20 if platform == 'linux' else 0))
        except subprocess.TimeoutExpired:
            timed_out = True
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                               stdout=stream, stderr=subprocess.STDOUT, timeout=30)
            else:
                process.kill()
            process.wait(timeout=30)
            code = 124
    value = log.read_text(encoding='utf-8', errors='replace')
    return {'command': command, 'pid': process.pid, 'started_utc': wall, 'ended_utc': utc(),
            'timeout_seconds': timeout, 'elapsed_seconds': time.monotonic() - started,
            'exit': code, 'timed_out': timed_out or code == 124, 'log_sha256': sha(log),
            'ok': code == 0 and not any(s in value for s in ['SCRIPT ERROR:', 'ERROR:'])}


def retained_controls(folder, platform, inputs, runtime):
    if folder is None:
        return {}
    identity = read(folder / 'identity.json')
    old = identity['source_inputs']
    if any(inputs.get(p) != h for p, h in old.items()) or set(inputs) - set(old) - NEW_PROJECT_PATHS:
        raise RuntimeError('Existing control source changed; reuse refused')
    for key in ['native_sha256', 'native_source_inputs', 'rapier_sha256', 'engine_sha256', 'engine_version']:
        if identity['platforms'][platform][key] != runtime[key]:
            raise RuntimeError('Existing control runtime changed; reuse refused')
    name = 'docs/audits/gcr001-2026-11-01/protocol.json'
    if git('show', identity['source'] + ':' + name).replace(b'\r\n', b'\n') != (ROOT / name).read_bytes().replace(b'\r\n', b'\n'):
        raise RuntimeError('Existing negative-control protocol changed')
    result = {}
    for row in read(folder / platform / 'gates.json'):
        host = row.get('test')
        if host not in EXISTING or row.get('ok') is not True or row.get('exit') != 0:
            continue
        log = Path(row.get('inherited_from', folder / platform / (host + '.log')))
        if sha(log) != row['log_sha256']:
            raise RuntimeError('Original successful host log differs')
        result[host] = dict(row, inherited_from=str(log), executed_source=row.get('executed_source', identity['source']),
                           reuse_scope='All prior project/production/config inputs and native/engine/runtime bytes identical; only new non-autoload apparatus added')
    return result


def authenticate_protocol(lane):
    registration, file, script, count = LANES[lane]
    path = ROOT / 'docs/audits/gcr-causal-2026-11-03' / file
    committed = git('show', 'HEAD:' + path.relative_to(ROOT).as_posix()).replace(b'\r\n', b'\n')
    if committed != path.read_bytes().replace(b'\r\n', b'\n'):
        raise RuntimeError('Causal protocol must be committed unchanged')
    value = read(path)
    if value['registration'] != registration or len(value['cases']) != count or len({c['id'] for c in value['cases']}) != count:
        raise RuntimeError('Unregistered causal population')
    return path, value, script


def population_receipt(lanes, platforms, protocols, completed, selected_case=None, gates_only=False):
    planned = sum(sum(not selected_case or c['id'] == selected_case for c in protocols[lane][1]['cases'])
                  for lane in lanes) * len(platforms) if not gates_only else 0
    selected_complete = not gates_only and not selected_case and completed == planned
    return {'selected_lanes': lanes, 'selected_platforms': platforms,
            'planned_captures': planned, 'completed_captures': completed,
            'complete_selected_lanes': selected_complete,
            'complete_registered_population': selected_complete and set(lanes) == set(LANES)
                and set(platforms) == {'windows', 'linux'} and completed == 40}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--lane', choices=['both', 'timing', 'event'], default='both')
    p.add_argument('--platform', choices=['both', 'windows', 'linux'], default='both')
    p.add_argument('--godot-windows', default='C:/Godot47/Godot_v4.7-stable_win64_console.exe')
    p.add_argument('--godot-linux', default='/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64')
    p.add_argument('--wsl-distro', default='Ubuntu-24.04')
    p.add_argument('--reuse-gates', type=Path)
    p.add_argument('--gates-only', action='store_true')
    p.add_argument('--case', help='A selected exploratory capture; never a complete registered campaign')
    args = p.parse_args()
    out = args.output.resolve()
    if out.exists():
        raise RuntimeError('Do not overwrite retained evidence')
    if git('diff', '--binary', 'HEAD'):
        raise RuntimeError('Commit the whole source before execution')
    untracked = git('ls-files', '--others', '--exclude-standard').decode().splitlines()
    if any(Path(n).suffix in {'.gd', '.py', '.cpp', '.inc'} for n in untracked):
        raise RuntimeError('Uncommitted executable source')
    head = git('rev-parse', 'HEAD').decode().strip()
    lanes = list(LANES) if args.lane == 'both' else [args.lane]
    protocols = {lane: authenticate_protocol(lane) for lane in lanes}
    if args.case and sum(any(c['id'] == args.case for c in value[1]['cases']) for value in protocols.values()) != 1:
        raise RuntimeError('Selected case must identify one lane uniquely')
    inputs = source_inputs()
    input_hash = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    out.mkdir(parents=True)
    identity = {'source': head, 'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
                'started_utc': utc(), 'source_inputs': inputs, 'source_inputs_sha256': input_hash,
                'platforms': {}, 'protocols': {k: {'sha256': sha(v[0]), 'registration': v[1]['registration']} for k, v in protocols.items()},
                'scope': 'Separate causal apparatus; all production-native inputs and existing coupling source unchanged'}
    env = dict(os.environ, GCR_CAUSAL_SOURCE=head, GCR_CAUSAL_INPUT_IDENTITY=input_hash)
    platforms = ['windows', 'linux'] if args.platform == 'both' else [args.platform]
    all_ok, completed = True, 0
    for platform in platforms:
        folder = out / platform
        folder.mkdir()
        project = folder / 'godot'
        shutil.copytree(ROOT / 'godot', project, ignore=shutil.ignore_patterns('.godot', '*.uid'))
        verify_project(project, inputs)
        native = native_identity(platform, project)
        if platform == 'windows':
            launcher = Path(args.godot_windows)
            executable = launcher.with_name(launcher.name.replace('_console.exe', '.exe'))
            engine, engine_hash, launcher_hash = [str(launcher)], sha(executable), sha(launcher)
        else:
            engine = ['wsl', '-d', args.wsl_distro, '--', 'env', 'GCR_CAUSAL_SOURCE=' + head,
                      'GCR_CAUSAL_INPUT_IDENTITY=' + input_hash, args.godot_linux]
            engine_hash = subprocess.check_output(['wsl', '-d', args.wsl_distro, '--', 'sha256sum', args.godot_linux], text=True, timeout=60).split()[0]
            launcher_hash = engine_hash
        version = subprocess.check_output(engine + ['--version'], text=True, timeout=60).strip()
        if version != '4.7.stable.official.5b4e0cb0f':
            raise RuntimeError('Pinned Godot required')
        runtime = dict(native, engine_version=version, engine_sha256=engine_hash, launch_entrypoint_sha256=launcher_hash)
        identity['platforms'][platform] = runtime
        write(out / 'identity.json', identity)
        for lane, (path, _, _) in protocols.items():
            (out / lane).mkdir(exist_ok=True)
            write(out / lane / 'identity.json', dict(identity, protocol_sha256=sha(path)))
        convert = lambda x: str(Path(x).resolve()) if platform == 'windows' else linux(x)
        prefix = engine + ['--headless', '--audio-driver', 'Dummy', '--path', convert(project)]
        gates = [run(prefix + ['--editor', '--quit'], folder / 'import.log', 300, env, platform, args.godot_linux)]
        write(folder / 'gates.json', gates)
        if not gates[-1]['ok']:
            return 1
        inherited = retained_controls(args.reuse_gates.resolve() if args.reuse_gates else None, platform, inputs, runtime)
        for host in EXISTING + NEW_TESTS:
            if host in inherited:
                row = inherited[host]
            else:
                command = prefix + ['--script', 'res://tests/' + host + '.gd']
                if host == 'test_gcr_envelope':
                    command += ['--', '--protocol=' + convert(ROOT / 'docs/audits/gcr001-2026-11-01/protocol.json')]
                if host in NEW_TESTS:
                    command += ['--', '--timing-protocol=' + convert(ROOT / 'docs/audits/gcr-causal-2026-11-03/timing-contact-protocol.json'),
                                '--event-protocol=' + convert(ROOT / 'docs/audits/gcr-causal-2026-11-03/event-protocol.json'),
                                '--report=' + convert(folder / (host + '.json'))]
                row = dict(run(command, folder / (host + '.log'), 300, env, platform, args.godot_linux), test=host)
            gates.append(row)
            write(folder / 'gates.json', gates)
            print(platform, host, row['ok'], 'REUSED' if host in inherited else 'FRESH', flush=True)
            if not row['ok']:
                return 1
        if not args.gates_only:
            for lane, (path, protocol, script) in protocols.items():
                target = out / lane / platform
                target.mkdir()
                records = []
                for case in protocol['cases']:
                    if args.case and case['id'] != args.case:
                        continue
                    raw = target / (case['id'] + '.json')
                    command = prefix + ['--script', 'res://qualification/' + script, '--',
                                        '--protocol=' + convert(path), '--case=' + case['id'], '--output=' + convert(raw)]
                    row = run(command, target / (case['id'] + '.log'), protocol['wall_timeout_seconds'], env, platform, args.godot_linux)
                    data = read(raw) if raw.exists() else {}
                    actual = data.get('identity', {})
                    bound = actual.get('source') == head and actual.get('input_identity') == input_hash and actual.get('protocol_sha256') == sha(path) and actual.get('native_sha256') == runtime['native_sha256'] and actual.get('engine_sha256') == engine_hash
                    row.update(case=case['id'], identity_ok=bound, rows=len(data.get('rows', [])), raw_sha256=sha(raw) if raw.exists() else None)
                    row['ok'] = row['ok'] and data.get('ok') is True and bound and row['rows'] == case['ticks']
                    records.append(row)
                    write(target / 'campaign.json', records)
                    print(lane, platform, case['id'], row['ok'], row['rows'], flush=True)
                    if not row['ok']:
                        all_ok = False
                        break
                    completed += 1
                if not all_ok:
                    break
        verify_project(project, inputs)
        if native_identity(platform, project) != native:
            raise RuntimeError('Native identity changed during acquisition')
        if not all_ok:
            break
    if source_inputs() != inputs or git('diff', '--binary', 'HEAD') or git('rev-parse', 'HEAD').decode().strip() != head:
        raise RuntimeError('Source changed during acquisition')
    completion = {'ok': all_ok, 'source': head, 'end_source': head, 'ended_utc': utc(), 'inputs_unchanged': True,
                  'identity_sha256': sha(out / 'identity.json'), 'selected_case': args.case,
                  'gates_only': args.gates_only,
                  **population_receipt(lanes, platforms, protocols, completed, args.case, args.gates_only)}
    write(out / 'completion.json', completion)
    for lane in lanes:
        write(out / lane / 'completion.json', dict(completion, lane=lane, identity_sha256=sha(out / lane / 'identity.json')))
    return 0 if all_ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
