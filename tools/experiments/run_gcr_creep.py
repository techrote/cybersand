"""Authenticate and acquire the bounded, apparatus-only GCR creep population."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PROTOCOL = ROOT / 'docs/audits/gcr-creep-2026-11-03/protocol.json'
CODE = {'.gd', '.tscn', '.tres', '.gdshader', '.gdextension', '.json'}
HOSTS = ['test_gcr_creep_capture', 'test_gcr_fleet_controls', 'test_gcr_rest_bridge', 'test_gcr_rest_material_freshness',
         'test_gcr_protocol', 'test_rem002_body_granular', 'test_rem003_player_granular',
         'test_actor_rig_integration', 'test_gcr_envelope']


def sha(path, canonical=False):
    value = Path(path).read_bytes()
    return hashlib.sha256(value.replace(b'\r\n', b'\n') if canonical else value).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def git(*values):
    return subprocess.check_output(['git', '-C', str(ROOT), *values], timeout=60)


def linux(path):
    value = Path(path).resolve().as_posix()
    return '/mnt/' + value[0].lower() + value[2:]


def source_inputs():
    tracked = set(git('ls-tree', '-r', '--name-only', 'HEAD', '--', 'godot').decode().splitlines())
    result = {}
    for path in sorted((ROOT / 'godot').rglob('*')):
        if not path.is_file() or '.godot' in path.parts or not (path.suffix in CODE or path.name == 'project.godot'):
            continue
        name = path.relative_to(ROOT).as_posix()
        if name not in tracked:
            raise RuntimeError('Uncommitted project input: ' + name)
        result[name] = sha(path, True)
    return result


def verify_project(project, inputs):
    for name, expected in inputs.items():
        if sha(project / Path(name).relative_to('godot'), True) != expected:
            raise RuntimeError('Project mismatch: ' + name)
    return inputs


def native_identity(platform, project):
    suffix = '' if platform == 'windows' else '.linux'
    native = read(ROOT / f'godot/addons/cybersand_native/runtime-provenance{suffix}.json')
    # Authenticate the complete production-native input set, including .inc.
    actual = {p.relative_to(ROOT).as_posix(): sha(p, True)
              for folder in ['native/src', 'native/include', 'godot/native_extension']
              for p in (ROOT / folder).rglob('*')
              if p.is_file() and p.suffix in {'.h', '.hpp', '.c', '.cpp', '.inc'}}
    if actual != native['source_inputs']:
        raise RuntimeError('Complete native source identity requires rebuilding')
    rapier = read(ROOT / f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json')
    for manifest in [native, rapier]:
        for path in [ROOT / manifest['artifact'], project / Path(manifest['artifact']).relative_to('godot')]:
            if sha(path) != manifest['sha256']:
                raise RuntimeError('Runtime mismatch: ' + str(path))
    return {'native_build_source': native['source_commit'], 'native_sha256': native['sha256'],
            'native_source_inputs': actual, 'rapier_sha256': rapier['sha256']}


def process(command, log, timeout, env):
    started = time.monotonic()
    with log.open('xb') as stream:
        try:
            code = subprocess.run(command, cwd=ROOT, env=env, stdout=stream,
                                  stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = 124
    text = log.read_text(encoding='utf-8', errors='replace')
    return {'command': command, 'timeout': timeout, 'exit': code,
            'elapsed_seconds': time.monotonic() - started, 'log_sha256': sha(log),
            'ok': code == 0 and not any(x in text for x in ['SCRIPT ERROR:', 'ERROR:'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--platform', choices=['windows', 'linux', 'both'], default='both')
    parser.add_argument('--godot-windows', default='C:/Godot47/Godot_v4.7-stable_win64_console.exe')
    parser.add_argument('--godot-linux', default='/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64')
    parser.add_argument('--wsl-distro', default='Ubuntu-24.04')
    parser.add_argument('--gates-only', action='store_true')
    parser.add_argument('--case', help='Exploratory selected run; never a complete campaign')
    args = parser.parse_args()
    args.output = args.output.resolve()
    if args.output.exists():
        raise RuntimeError('Never overwrite retained evidence')
    if git('diff', '--binary', 'HEAD'):
        raise RuntimeError('Commit the complete source before execution')
    if git('show', 'HEAD:' + PROTOCOL.relative_to(ROOT).as_posix()).replace(b'\r\n', b'\n') != PROTOCOL.read_bytes().replace(b'\r\n', b'\n'):
        raise RuntimeError('Protocol must be committed unchanged')
    protocol = read(PROTOCOL)
    if protocol['registration'] != 'GCR-CREEP-001-2026-11-03' or len(protocol['cases']) != 16:
        raise RuntimeError('Unexpected registered population')
    cases = [x for x in protocol['cases'] if not args.case or x['id'] == args.case]
    if not cases:
        raise RuntimeError('Unknown case')
    head = git('rev-parse', 'HEAD').decode().strip()
    inputs = source_inputs()
    args.output.mkdir(parents=True)
    identity = {'source': head, 'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
                'protocol_sha256': sha(PROTOCOL), 'source_inputs': inputs,
                'source_inputs_sha256': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
                'platforms': {}, 'scope': 'Apparatus only; unchanged native and shared coupling; no sleep or law changes'}
    env = dict(os.environ, GCR_CREEP_SOURCE=head, GCR_CREEP_INPUT_IDENTITY=identity['source_inputs_sha256'])
    platforms = ['windows', 'linux'] if args.platform == 'both' else [args.platform]
    ok = True
    for platform in platforms:
        project = args.output / platform / 'godot'
        project.parent.mkdir()
        shutil.copytree(ROOT / 'godot', project, ignore=shutil.ignore_patterns('.godot', '*.uid'))
        verify_project(project, inputs)
        runtime = native_identity(platform, project)
        convert = lambda path: str(Path(path).resolve()) if platform == 'windows' else linux(path)
        engine = [args.godot_windows] if platform == 'windows' else ['wsl', '-d', args.wsl_distro, '--', 'env',
                 'GCR_CREEP_SOURCE=' + head, 'GCR_CREEP_INPUT_IDENTITY=' + identity['source_inputs_sha256'], args.godot_linux]
        version = subprocess.check_output(engine + ['--version'], text=True, timeout=60).strip()
        if version != '4.7.stable.official.5b4e0cb0f':
            raise RuntimeError('Pinned Godot4.7 required')
        if platform == 'windows':
            launcher = Path(args.godot_windows)
            # The official console executable launches its sibling GUI binary;
            # OS.get_executable_path() authenticates the actual engine process.
            executable = launcher.with_name(launcher.name.replace('_console.exe', '.exe'))
            if not executable.is_file():
                raise RuntimeError('Actual Windows engine executable missing')
            engine_sha = sha(executable)
            launcher_sha = sha(launcher)
        else:
            engine_sha = subprocess.check_output(
                ['wsl', '-d', args.wsl_distro, '--', 'sha256sum', args.godot_linux], text=True, timeout=60).split()[0]
            launcher_sha = engine_sha
        identity['platforms'][platform] = dict(runtime, engine_version=version, engine_sha256=engine_sha,
                                              launch_entrypoint_sha256=launcher_sha)
        write(args.output / 'identity.json', identity)
        prefix = engine + ['--headless', '--audio-driver', 'Dummy', '--path', convert(project)]
        gates = [process(prefix + ['--editor', '--quit'], project.parent / 'import.log', 300, env)]
        write(project.parent / 'gates.json', gates)
        if not gates[-1]['ok']:
            return 1
        for host in HOSTS:
            row = process(prefix + ['--script', 'res://tests/' + host + '.gd'], project.parent / (host + '.log'), 300, env)
            gates.append(dict(row, test=host))
            write(project.parent / 'gates.json', gates)
            print(platform, host, row['ok'], flush=True)
            if not row['ok']:
                return 1
        records = []
        if not args.gates_only:
            for case in cases:
                output = project.parent / (case['id'] + '.json')
                row = process(prefix + ['--script', 'res://qualification/gcr_creep_capture.gd', '--',
                              '--protocol=' + convert(PROTOCOL), '--case=' + case['id'], '--output=' + convert(output)],
                              project.parent / (case['id'] + '.log'), protocol['wall_timeout_seconds'], env)
                data = read(output) if output.exists() else {}
                actual = data.get('identity', {})
                bound = actual.get('source') == head and actual.get('native_sha256') == runtime['native_sha256'] and actual.get('protocol_sha256') == sha(PROTOCOL) and actual.get('input_identity') == identity['source_inputs_sha256'] and actual.get('engine_sha256') == engine_sha
                row.update(case=case['id'], identity_ok=bound, raw_sha256=sha(output) if output.exists() else None,
                           rows=len(data.get('rows', [])))
                row['ok'] = row['ok'] and data.get('ok') is True and bound and row['rows'] == case['ticks']
                records.append(row)
                write(project.parent / 'campaign.json', records)
                print(platform, case['id'], row['ok'], row['rows'], flush=True)
                if not row['ok']:
                    ok = False
                    break
        verify_project(project, inputs)
        if native_identity(platform, project) != runtime:
            raise RuntimeError('Native identity changed during execution')
        if not ok:
            break
    if source_inputs() != inputs or git('diff', '--binary', 'HEAD'):
        raise RuntimeError('Source changed during execution')
    write(args.output / 'completion.json', {'ok': ok, 'source': head, 'end_source': git('rev-parse', 'HEAD').decode().strip(),
          'identity_sha256': sha(args.output / 'identity.json'), 'gates_only': args.gates_only,
          'selected_case': args.case, 'complete_registered_population': ok and not args.gates_only and not args.case and len(platforms) == 2,
          'inputs_unchanged': True})
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
