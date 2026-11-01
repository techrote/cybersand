"""Acquire only the registered 56-capture detachment composition population."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PROTOCOL = ROOT / 'docs/audits/gcr-detachment-2026-11-01/protocol.json'
REGISTRATION = 'GCR-DETACHMENT-001-2026-11-01'


def digest(path, canonical=False):
    data = Path(path).read_bytes()
    return hashlib.sha256(data.replace(b'\r\n', b'\n') if canonical else data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], timeout=30)


def schedule(protocol, platform):
    if platform not in protocol['platforms']:
        raise ValueError('Unregistered platform')
    rows = []
    for index, surroundings in enumerate(protocol['surroundings']):
        arms = protocol['arms'] if index % 2 == 0 else list(reversed(protocol['arms']))
        for workers in protocol['workers']:
            for arm in arms:
                rows.append({'surroundings': surroundings, 'arm': arm, 'workers': workers,
                             'platform': platform, 'repeat': 0})
    rows.extend({'surroundings': value, 'arm': 'R2', 'workers': 1,
                 'platform': platform, 'repeat': 1} for value in protocol['surroundings'])
    assert len(rows) == 28
    return rows


def authenticate(args):
    relative = PROTOCOL.relative_to(ROOT).as_posix()
    if git('show', 'HEAD:' + relative).replace(b'\r\n', b'\n') != PROTOCOL.read_bytes().replace(b'\r\n', b'\n'):
        raise RuntimeError('Registration is not committed unchanged')
    protocol = json.loads(PROTOCOL.read_text(encoding='utf-8'))
    if protocol['registration'] != REGISTRATION or protocol['population']['maximum_captures'] != 56:
        raise RuntimeError('Wrong registration')
    manifest = json.loads(args.native_manifest.read_text(encoding='utf-8'))
    sources = manifest.get('source_inputs', {})
    if not sources:
        raise RuntimeError('Native manifest lacks source inputs')
    for relative, expected in sources.items():
        if digest(ROOT / relative, True) != expected:
            raise RuntimeError('Source-matched rebuild required: ' + relative)
    native = ROOT / manifest['artifact']
    if digest(native) != manifest['sha256']:
        raise RuntimeError('Native artifact hash mismatch')
    platform = 'windows' if os.name == 'nt' else 'linux'
    rapier_path = ROOT / f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json'
    rapier = json.loads(rapier_path.read_text(encoding='utf-8'))
    for artifact, expected in [(manifest['artifact'], manifest['sha256']), (rapier['artifact'], rapier['sha256'])]:
        if digest(ROOT / artifact) != expected or digest(args.project / Path(artifact).relative_to('godot')) != expected:
            raise RuntimeError('Native/Rapier project artifact mismatch: ' + artifact)
    inputs = {}
    for path in sorted((ROOT / 'godot').rglob('*')):
        if path.is_file() and '.godot' not in path.parts and (path.suffix in {'.gd', '.tscn', '.tres', '.gdshader', '.gdextension'} or path.name == 'project.godot'):
            relative = path.relative_to(ROOT).as_posix()
            inputs[relative] = digest(path, True)
            if inputs[relative] != digest(args.project / path.relative_to(ROOT / 'godot'), True):
                raise RuntimeError('Project input mismatch: ' + relative)
    version = subprocess.check_output([str(args.godot), '--version'], timeout=30, text=True, encoding='utf-8').strip()
    if version != '4.7.stable.official.5b4e0cb0f':
        raise RuntimeError('Expected pinned Godot4.7 official')
    identity = {'source': git('rev-parse', 'HEAD').decode('utf-8').strip(),
                'tree': git('rev-parse', 'HEAD^{tree}').decode('utf-8').strip(),
                'local_delta_sha256': hashlib.sha256(git('diff', '--binary', 'HEAD')).hexdigest(),
                'protocol_sha256': digest(PROTOCOL), 'native_sha256': manifest['sha256'],
                'native_manifest_sha256': digest(args.native_manifest),
                'native_build_commit': manifest.get('build_commit'), 'rapier_sha256': rapier['sha256'],
                'engine_sha256': digest(args.godot), 'godot': version,
                'project_inputs': inputs,
                'input_identity': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode('utf-8')).hexdigest()}
    return protocol, identity


def validate_mechanical(path, identity, protocol):
    if path is None:
        raise RuntimeError('Physical acquisition requires a source-bound mechanical receipt')
    receipt = json.loads(path.read_text(encoding='utf-8'))
    if receipt.get('ok') is not True:
        raise RuntimeError('Mechanical receipt is not passing')
    for key in ['source', 'protocol_sha256', 'native_sha256', 'input_identity']:
        if receipt.get(key) != identity[key]:
            raise RuntimeError('Mechanical identity mismatch: ' + key)
    for key in protocol['mechanical_prerequisites']:
        if receipt.get('gates', {}).get(key) is not True:
            raise RuntimeError('Missing mechanical prerequisite: ' + key)
    return digest(path)


def capture(args, identity, spec):
    stem = '{platform}-{surroundings}-{arm}-w{workers}-r{repeat}'.format(**spec)
    output, log = args.output / (stem + '.json'), args.output / (stem + '.log')
    command = [str(args.godot), '--headless', '--path', str(args.project), '--script',
               'res://tests/test_gcr_detachment_capture.gd', '--', '--protocol=' + str(PROTOCOL),
               '--surroundings=' + spec['surroundings'], '--candidate=' + spec['arm'],
               '--workers=' + str(spec['workers']), '--repeat=' + str(spec['repeat']), '--output=' + str(output)]
    env = os.environ.copy()
    for key in ['source', 'input_identity', 'native_sha256', 'protocol_sha256']:
        env['CYBERSAND_' + key.upper()] = identity[key]
    started, status, returncode = time.monotonic(), 'failed', None
    with log.open('w', encoding='utf-8') as handle:
        try:
            result = subprocess.run(command, env=env, stdout=handle, stderr=subprocess.STDOUT,
                                    timeout=args.timeout, check=False)
            returncode = result.returncode
            if returncode == 0 and output.exists():
                raw = json.loads(output.read_text(encoding='utf-8'))
                if (raw.get('ok') is True and raw.get('identity') == {key: identity[key] for key in ['source', 'input_identity', 'native_sha256', 'protocol_sha256']}
                        and all(raw.get('case', {}).get(key) == value for key, value in spec.items())):
                    status = 'captured'
        except subprocess.TimeoutExpired:
            status = 'timeout'
    return {**spec, 'status': status, 'returncode': returncode, 'elapsed_s': time.monotonic() - started,
            'command': command, 'timeout_s': args.timeout, 'log': log.name, 'log_sha256': digest(log),
            'raw': output.name if output.exists() else None, 'raw_sha256': digest(output) if output.exists() else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--project', type=Path, default=ROOT / 'godot')
    parser.add_argument('--native-manifest', type=Path, default=ROOT / ('godot/addons/cybersand_native/runtime-provenance.json' if os.name == 'nt' else 'godot/addons/cybersand_native/runtime-provenance.linux.json'))
    parser.add_argument('--mechanical-receipt', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--jobs', type=int, choices=[1, 2, 3], default=1)
    parser.add_argument('--timeout', type=int, default=240)
    parser.add_argument('--identity-only', action='store_true')
    parser.add_argument('--surroundings', action='append')
    parser.add_argument('--arms', nargs='+')
    parser.add_argument('--workers', nargs='+', type=int)
    parser.add_argument('--phase', choices=['primary', 'repeat', 'all'], default='all')
    args = parser.parse_args()
    args.project, args.output = args.project.resolve(), args.output.resolve()
    protocol, identity = authenticate(args)
    if args.identity_only:
        print(json.dumps(identity, indent=2)); return 0
    mechanical_hash = validate_mechanical(args.mechanical_receipt, identity, protocol)
    tasks = schedule(protocol, 'Windows' if os.name == 'nt' else 'Linux')
    for option, valid in [('surroundings', protocol['surroundings']), ('arms', protocol['arms']), ('workers', protocol['workers'])]:
        selected = getattr(args, option)
        if selected and not set(selected) <= set(valid):
            raise RuntimeError('Unregistered selection: ' + option)
    tasks = [row for row in tasks if (not args.surroundings or row['surroundings'] in args.surroundings)
             and (not args.arms or row['arm'] in args.arms) and (not args.workers or row['workers'] in args.workers)
             and (args.phase == 'all' or row['repeat'] == (1 if args.phase == 'repeat' else 0))]
    if not tasks:
        raise RuntimeError('Empty registered selection')
    args.output.mkdir(parents=True, exist_ok=True)
    index = args.output / 'campaign.json'
    if index.exists() or any(args.output.iterdir()):
        raise RuntimeError('Use a fresh empty output directory; retain old failures')
    campaign = {'schema': 'cybersand.gcr-detachment.campaign.v1', 'identity': identity,
                'mechanical_receipt_sha256': mechanical_hash, 'captures': [], 'scheduled': tasks,
                'functional_process_concurrency': args.jobs, 'timing_scope': 'functional asynchronous only', 'complete': False}
    def save():
        index.write_text(json.dumps(campaign, indent=2) + '\n', encoding='utf-8')
    save()
    def execute(spec):
        if authenticate(args)[1] != identity:
            raise RuntimeError('Acquisition source/runtime/input changed')
        return capture(args, identity, spec)
    with ThreadPoolExecutor(args.jobs) as pool:
        for row in pool.map(execute, tasks):
            campaign['captures'].append(row); save()
            print(row['status'], row['surroundings'], row['arm'], row['workers'], row['repeat'], flush=True)
    campaign['complete'] = len(campaign['captures']) == len(tasks) and all(row['status'] == 'captured' for row in campaign['captures'])
    save()
    return 0 if campaign['complete'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
