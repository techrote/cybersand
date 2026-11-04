"""Acquire the registered moving-load diagnostic on authenticated copied hosts."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from run_gcr_causal import run
from run_gcr_creep import ROOT, git, linux, native_identity, read, sha, source_inputs, verify_project, write

PROTOCOL = 'docs/audits/gcr-carry-2026-11-04/protocol.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--platform', choices=['windows', 'linux', 'both'], default='both')
    args = parser.parse_args()
    out = args.output.resolve()
    if out.exists() or git('diff', '--binary', 'HEAD'):
        raise RuntimeError('Fresh output and committed source required')
    source = git('rev-parse', 'HEAD').decode().strip()
    inputs = source_inputs()
    ih = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    protocol = read(ROOT / PROTOCOL)
    assert protocol['registration'] == 'GCR-CARRY-002' and len(protocol['cases']) == 10
    out.mkdir(parents=True)
    write(out / 'identity.json', {'source': source, 'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
          'inputs': inputs, 'inputs_hash': ih, 'protocol_sha256': sha(ROOT / PROTOCOL)})

    def host(platform):
        folder = out / platform
        folder.mkdir()
        project = folder / 'godot'
        shutil.copytree(ROOT / 'godot', project, ignore=shutil.ignore_patterns('.godot', '*.uid'))
        destination = folder / PROTOCOL
        destination.parent.mkdir(parents=True)
        shutil.copy2(ROOT / PROTOCOL, destination)
        verify_project(project, inputs)
        native = native_identity(platform, project)
        le = '/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64'
        env = dict(os.environ, CYBERSAND_SOURCE_REVISION=source, GCR_SCOOPER_INPUTS=ih)
        if platform == 'windows':
            engine = ['C:/Godot47/Godot_v4.7-stable_win64_console.exe']
            engine_hash = sha(engine[0])
        else:
            engine = ['wsl', '-d', 'Ubuntu-24.04', '--', 'env', 'CYBERSAND_SOURCE_REVISION=' + source,
                      'GCR_SCOOPER_INPUTS=' + ih, le]
            engine_hash = subprocess.check_output(['wsl', '-d', 'Ubuntu-24.04', '--', 'sha256sum', le], text=True, timeout=60).split()[0]
        version = subprocess.check_output(engine + ['--version'], text=True, timeout=60).strip()
        assert version == '4.7.stable.official.5b4e0cb0f'
        write(folder / 'runtime.json', dict(native, engine_sha256=engine_hash, engine_version=version))
        cv = lambda path: str(Path(path).resolve()) if platform == 'windows' else linux(path)
        prefix = engine + ['--headless', '--audio-driver', 'Dummy', '--path', cv(project)]
        records = []
        for test in ['import', 'test_gcr_scooper_leak_capture', 'test_gcr_scooper_ejection_replay', 'test_gcr_scooper_entry_side']:
            command = prefix + (['--editor', '--quit'] if test == 'import' else ['--script', 'res://tests/' + test + '.gd'])
            if test == 'test_gcr_scooper_leak_capture':
                command += ['--', '--protocol=' + cv(destination)]
            elif test == 'test_gcr_scooper_ejection_replay':
                command += ['--', '--output=' + cv(folder / 'ejection-replay.json')]
            receipt = run(command, folder / (test + '.log'), 300, env, platform, le)
            receipt['test'] = test
            records.append(receipt)
            write(folder / 'gates.json', records)
            print(platform, test, receipt['ok'], flush=True)
            if not receipt['ok']:
                return {'platform': platform, 'ok': False, 'failed': test}
        captures = []
        for spec in protocol['cases']:
            name = spec['id']
            raw = folder / (name + '.json')
            command = prefix + ['--script', 'res://qualification/gcr_scooper_leak_capture.gd', '--',
                       '--protocol=' + cv(destination), '--case=' + name, '--output=' + cv(raw)]
            receipt = run(command, folder / (name + '.log'), 300, env, platform, le)
            data = read(raw) if raw.exists() else {}
            identity = data.get('identity', {})
            identity_ok = all(identity.get(k) == v for k, v in {
                'source': source, 'inputs': ih, 'protocol_sha256': sha(ROOT / PROTOCOL),
                'native_sha256': native['native_sha256'], 'physics_backend': 'Rapier2D'}.items())
            receipt.update(case=name, response=spec['response'], rows=len(data.get('rows', [])), identity_ok=identity_ok,
                           raw_sha256=sha(raw) if raw.exists() else None)
            receipt['ok'] = receipt['ok'] and identity_ok and data.get('ok') is True and receipt['rows'] == protocol['ticks']
            captures.append(receipt)
            write(folder / 'campaign.json', captures)
            print(platform, name, receipt['ok'], receipt['rows'], flush=True)
        verify_project(project, inputs)
        assert native_identity(platform, project) == native
        assert sha(destination) == sha(ROOT / PROTOCOL)
        return {'platform': platform, 'ok': all(r['ok'] for r in captures), 'captures': len(captures),
                'gates_sha256': sha(folder / 'gates.json'), 'campaign_sha256': sha(folder / 'campaign.json')}

    platforms = ['windows', 'linux'] if args.platform == 'both' else [args.platform]
    with concurrent.futures.ThreadPoolExecutor(len(platforms)) as pool:
        results = list(pool.map(host, platforms))
    unchanged = source_inputs() == inputs and source == git('rev-parse', 'HEAD').decode().strip() and not git('diff', '--binary', 'HEAD')
    ok = all(r['ok'] for r in results) and unchanged
    write(out / 'completion.json', {'source': source, 'ok': ok, 'inputs_unchanged': unchanged, 'results': results})
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
