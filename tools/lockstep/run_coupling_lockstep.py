#!/usr/bin/env python3
"""COUPLING-LOCKSTEP-001 runner: fresh Godot process per episode, Windows and WSL Linux.

Evidence goes to the uncommitted build/coupling-lockstep/<run>/. The source must be
committed and clean; the receipt binds source, engine and runtime hashes.
"""
import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/coupling-lockstep'
REGISTRATION = ROOT / 'native/tests/fixtures/coupling_lockstep_001.json'
ENGINES = {'windows': 'C:/Godot47/Godot_v4.7-stable_win64_console.exe',
           'linux': '/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64'}
RUNTIMES = {'windows': ['godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll',
                        'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'],
            'linux': ['godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so',
                      'godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so']}
CAP = json.loads(REGISTRATION.read_text(encoding='utf-8'))['resource']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def committed_sha(path):
    # Source is committed and clean before execution; hash the committed blob so a
    # Windows CRLF checkout cannot change the recorded identity.
    return hashlib.sha256(subprocess.check_output(['git', '-C', str(ROOT), 'show', 'HEAD:' + path])).hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args]).decode().strip()


def wsl(path):
    text = str(path).replace('\\', '/')
    return '/mnt/' + text[0].lower() + text[2:]


def linux_engine_sha():
    return subprocess.check_output(['wsl.exe', '-d', 'Ubuntu-24.04', '--', 'sha256sum', ENGINES['linux']]).decode().split()[0]


def episode(host, arm, workers, ticks, folder, delay):
    folder.mkdir(parents=True)
    log = folder / 'godot.log'
    timeout = CAP['timeout_seconds_per_episode']
    if host == 'windows':
        argv = [ENGINES['windows'], '--headless', '--path', str(ROOT / 'godot'), '--script',
                'res://tests/test_coupling_lockstep.gd', '--', str(folder), arm, str(workers), str(ticks), str(delay)]
    else:
        argv = ['wsl.exe', '-d', 'Ubuntu-24.04', '--', 'timeout', '--signal=TERM', '--kill-after=5s', f'{timeout}s',
                ENGINES['linux'], '--headless', '--path', wsl(ROOT / 'godot'), '--script',
                'res://tests/test_coupling_lockstep.gd', '--', wsl(folder), arm, str(workers), str(ticks), str(delay)]
    start = time.monotonic()
    with log.open('wb') as handle:
        process = subprocess.Popen(argv, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=timeout + 10)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], timeout=10)
            process.wait(timeout=10)
            code = 124
    text = log.read_text(encoding='utf-8', errors='replace')
    result = folder / f'{arm}-w{workers}.json'
    row = dict(host=host, arm=arm, workers=workers, ticks=ticks, delay_usec=delay, exit=code, seconds=time.monotonic() - start,
               clean=code == 0 and 'SCRIPT ERROR' not in text and 'COUPLING_LOCKSTEP {' in text and result.is_file(),
               log_sha256=sha(log), result=str(result.relative_to(ROOT)) if result.is_file() else None,
               result_sha256=sha(result) if result.is_file() else None)
    print(json.dumps({k: row[k] for k in ('host', 'arm', 'workers', 'exit', 'clean', 'seconds')}), flush=True)
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True)
    parser.add_argument('--hosts', default='windows,linux')
    parser.add_argument('--workers', default='1,4')
    parser.add_argument('--arms', default='async,lockstep')
    parser.add_argument('--repeats', type=int, default=5)
    parser.add_argument('--ticks', type=int, default=600)
    parser.add_argument('--delay-usec', type=int, default=0)
    args = parser.parse_args()
    assert not git('status', '--porcelain', '--', 'godot', 'native', 'tools'), 'Commit source before execution'
    folder = OUT / args.run
    assert not folder.exists(), 'Run folders are never reused'
    folder.mkdir(parents=True)
    hosts = args.hosts.split(',')
    identity = dict(source_commit=git('rev-parse', 'HEAD'),
                    registration_sha256=committed_sha('native/tests/fixtures/coupling_lockstep_001.json'),
                    runner_sha256=committed_sha('tools/lockstep/run_coupling_lockstep.py'),
                    fixture_sha256=committed_sha('godot/tests/test_coupling_lockstep.gd'),
                    worker_sha256=committed_sha('godot/scripts/simulation_worker.gd'),
                    bridge_sha256=committed_sha('godot/scripts/rapier_physics_bridge.gd'),
                    engines={'windows': sha(ENGINES['windows'])} | ({'linux': linux_engine_sha()} if 'linux' in hosts else {}),
                    runtimes={p: sha(ROOT / p) for h in hosts for p in RUNTIMES[h]})
    receipt = dict(identity=identity, matrix=vars(args), episodes=[])
    path = folder / 'receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    # Interleave arms/workers inside each repeat so slow drift affects both arms.
    for host in hosts:
        for repeat in range(args.repeats):
            for workers in map(int, args.workers.split(',')):
                for arm in args.arms.split(','):
                    used = sum(p.stat().st_size for p in OUT.rglob('*') if p.is_file())
                    assert used < CAP['collection_cap_bytes'], 'Resource cap reached; retain evidence'
                    row = episode(host, arm, workers, args.ticks, folder / host / f'{arm}-w{workers}-r{repeat}', args.delay_usec)
                    row['repeat'] = repeat
                    receipt['episodes'].append(row)
                    path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    receipt['post_source_equality'] = git('rev-parse', 'HEAD') == identity['source_commit'] and not git(
        'status', '--porcelain', '--', 'godot', 'native', 'tools')
    path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return int(not all(r['clean'] for r in receipt['episodes']))


if __name__ == '__main__':
    raise SystemExit(main())
