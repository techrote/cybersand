"""Source-authenticated, bounded GCR-001 captures. Raw output is never source evidence alone."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
PROTOCOL = ROOT / 'docs/audits/gcr001-2026-11-01/protocol.json'


def digest(path, normalized=False):
    data = Path(path).read_bytes()
    return hashlib.sha256(data.replace(b'\r\n', b'\n') if normalized else data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], timeout=30)


def authenticate(args):
    # Registration is immutable during result acquisition. An uncommitted edit
    # fails even if all other source/runtime inputs have been rebuilt.
    relative = PROTOCOL.relative_to(ROOT).as_posix()
    registered = git('show', f'HEAD:{relative}').replace(b'\r\n', b'\n')
    if registered != PROTOCOL.read_bytes().replace(b'\r\n', b'\n'):
        raise RuntimeError('Protocol differs from committed registration')
    protocol = json.loads(PROTOCOL.read_text())
    if protocol.get('registration') != 'GCR-001-2026-11-01' or len(protocol['cases']) != 66:
        raise RuntimeError('Expected the frozen 66-case GCR-001 registration')
    manifest = json.loads(args.native_manifest.read_text())
    for relative, expected in manifest['source_inputs'].items():
        if digest(ROOT / relative, True) != expected:
            raise RuntimeError('Rebuild required for ' + relative)
    artifact = ROOT / manifest['artifact']
    if digest(artifact) != manifest['sha256']:
        raise RuntimeError('Native runtime differs from source-bound manifest')
    platform = 'windows' if os.name == 'nt' else 'linux'
    rapier_manifest = ROOT / f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json'
    rapier = json.loads(rapier_manifest.read_text())
    if digest(ROOT / rapier['artifact']) != rapier['sha256']:
        raise RuntimeError('Rapier differs from retained pinned runtime')
    # Authenticate every executable project source; retain the entire mapping
    # once per campaign, rather than repeat it in every 1800-tick raw file.
    inputs = {}
    for path in sorted((ROOT / 'godot').rglob('*')):
        if path.is_file() and '.godot' not in path.parts and path.suffix in {'.gd', '.tscn', '.gdshader', '.tres'}:
            inputs[path.relative_to(ROOT).as_posix()] = digest(path, True)
            if digest(args.project / path.relative_to(ROOT / 'godot'), True) != digest(path, True):
                raise RuntimeError('Project source differs: ' + str(path))
    input_identity = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    version = subprocess.check_output([str(args.godot), '--version'], text=True, timeout=30).strip()
    if version != '4.7.stable.official.5b4e0cb0f':
        raise RuntimeError('Expected pinned official Godot 4.7')
    return protocol, {'source': git('rev-parse', 'HEAD').decode().strip(),
                      'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
                      'local_delta_sha256': hashlib.sha256(git('diff', '--binary', 'HEAD')).hexdigest(),
                      'protocol_sha256': digest(PROTOCOL), 'native_sha256': digest(artifact),
                      'native_manifest_sha256': digest(args.native_manifest),
                      'rapier_sha256': rapier['sha256'], 'engine_sha256': digest(args.godot),
                      'godot': version, 'input_identity': input_identity, 'project_inputs': inputs}


def capture(args, identity, case, arm, repeat, mode):
    stem = f'{mode}-{case}-{arm}-r{repeat}'
    output = args.output / f'{stem}.json'
    log = args.output / f'{stem}.log'
    env = os.environ.copy()
    env['CYBERSAND_SOURCE_REVISION'] = identity['source']
    env['CYBERSAND_INPUT_IDENTITY'] = identity['input_identity']
    command = [str(args.godot), '--headless', '--path', str(args.project),
               '--script', f'res://tests/test_gcr_{"async" if mode == "async" else "envelope"}.gd',
               '--', f'--protocol={PROTOCOL}', f'--case={case}', f'--candidate={arm}',
               f'--output={output}', f'--telemetry={args.telemetry}']
    start = time.monotonic()
    status, returncode = 'failed', None
    with log.open('w', encoding='utf-8') as handle:
        try:
            process = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT,
                                     env=env, timeout=args.timeout, check=False)
            returncode = process.returncode
            if process.returncode == 0 and output.exists():
                report = json.loads(output.read_text())
                if report.get('ok') and report.get('protocol_sha256') == identity['protocol_sha256'] and report.get('input_identity') == identity['input_identity'] and report.get('runtime', {}).get('native') == identity['native_sha256']:
                    status = 'captured'
        except subprocess.TimeoutExpired:
            status = 'timeout'
    return {'case': case, 'arm': arm, 'repeat': repeat, 'mode': mode, 'status': status,
            'returncode': returncode, 'elapsed_s': time.monotonic() - start, 'command': command,
            'timeout_s': args.timeout, 'log': log.name, 'log_sha256': digest(log),
            'raw': output.name if output.exists() else None,
            'raw_sha256': digest(output) if output.exists() else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, default=Path('C:/Godot47/Godot_v4.7-stable_win64_console.exe'))
    parser.add_argument('--project', type=Path, default=ROOT / 'godot')
    platform = 'windows' if os.name == 'nt' else 'linux'
    parser.add_argument('--native-manifest', type=Path, default=ROOT / ('godot/addons/cybersand_native/runtime-provenance.json' if platform == 'windows' else 'godot/addons/cybersand_native/runtime-provenance.linux.json'))
    parser.add_argument('--output', type=Path, default=ROOT / 'out/gcr001')
    parser.add_argument('--case', action='append', help='Registered IDs; omitted means all 66 primary pairs')
    parser.add_argument('--arms', nargs='+', default=['Y1', 'GCR'])
    parser.add_argument('--mode', choices=['sync', 'async', 'timing', 'review'], default='sync')
    parser.add_argument('--telemetry', choices=['on', 'off'], default='on')
    parser.add_argument('--timeout', type=int, default=240)
    parser.add_argument('--identity-only', action='store_true')
    args = parser.parse_args()
    protocol, identity = authenticate(args)
    if args.identity_only:
        print(json.dumps(identity, indent=2))
        return 0
    if args.mode == 'review':
        env = os.environ.copy()
        env['CYBERSAND_SOURCE_REVISION'] = identity['source']
        return subprocess.call([str(args.godot), '--path', str(ROOT / 'godot'), '--resolution', '1200x760',
                                'res://y1_envelope_review.tscn', '--', f'--protocol={PROTOCOL}'], env=env)
    valid = {spec['id'] for spec in protocol['cases'] + protocol.get('controls', [])}
    cases = args.case or (protocol['async_cases'] if args.mode == 'async' else [spec['id'] for spec in protocol['cases']])
    if not set(cases) <= valid or not set(args.arms) <= {'B0', 'Y1', 'GCR', 'GCR-MU0', 'GCR-CENTRAL'}:
        raise RuntimeError('Unknown registered case/arm')
    if args.mode == 'timing' and not args.case:
        raise RuntimeError('Timing requires an explicit bounded registered case list')
    args.output.mkdir(parents=True, exist_ok=True)
    campaign = {'schema': 1, 'identity': identity, 'captures': [], 'complete': False}
    index = args.output / 'campaign.json'
    if index.exists():
        raise RuntimeError('Use a fresh output directory; prior failures must remain recoverable')
    index.write_text(json.dumps(campaign, indent=2))
    for repeat in range(3 if args.mode == 'timing' else 1):
        arms = args.arms if repeat % 2 == 0 else list(reversed(args.arms))
        for case in cases:
            for arm in arms:
                # Source and runtime guards repeat before each independent process.
                _, current = authenticate(args)
                if current != identity:
                    raise RuntimeError('Campaign input identity changed; stop rather than mix captures')
                row = capture(args, identity, case, arm, repeat, 'async' if args.mode == 'async' else 'sync')
                campaign['captures'].append(row)
                index.write_text(json.dumps(campaign, indent=2))
                print(f'{row["status"]}: {case} {arm} r{repeat}', flush=True)
    campaign['complete'] = all(row['status'] == 'captured' for row in campaign['captures'])
    index.write_text(json.dumps(campaign, indent=2))
    return 0 if campaign['complete'] else 1


if __name__ == '__main__':
    sys.exit(main())
