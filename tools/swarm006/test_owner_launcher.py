#!/usr/bin/env python3
"""Exercise the sealed owner PowerShell script against its actual Windows ZIP.

Admission checks are followed by actual PowerShell/CMD graphical dispatch of
the sealed package. Full native Apply qualification and owner NVIDIA acceptance
remain separate. The nested artifact uses the exact delivered inner names.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

from seal_owner import sha, validate_package
import owner_dispatch


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sealed', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source', required=True)
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Owner PowerShell qualification requires actual Windows')
    sealed, output = args.sealed.resolve(), args.output.resolve()
    if output.exists():
        raise ValueError('Launcher qualification requires a fresh output folder')
    output.mkdir(parents=True)
    seals = [path for path in (sealed/'swarm006-owner-seal.json', sealed/'swarm456-owner-seal.json') if path.is_file()]
    if len(seals) != 1:
        raise ValueError('Exactly one original or unified owner seal is required')
    metadata = json.loads(seals[0].read_text())
    if metadata['source_commit'] != args.source:
        raise ValueError('Seal source mismatch')
    label = 'SWARM456' if seals[0].name.startswith('swarm456-') else 'SWARM006'
    archive, launcher = sealed/metadata['archive'], sealed/f'CyberSand-{label}-Windows-Owner-Acceptance.ps1'
    if sha(archive) != metadata['archive_sha256'] or sha(launcher) != metadata['launcher_sha256']:
        raise ValueError('Sealed archive or launcher changed before qualification')
    records = []

    def invoke(label: str, selected: Path, destination: Path, success: bool, reason: str = '') -> None:
        command = ['powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(launcher),
                   '-Archive', str(selected), '-Destination', str(destination), '-VerifyOnly']
        result = subprocess.run(command, capture_output=True, text=True, timeout=240,
                                env=owner_dispatch.windows_powershell_env())
        log = result.stdout + result.stderr
        (output/(label+'.log')).write_text(log, encoding='utf-8')
        passed = ((result.returncode == 0) == success and (not reason or reason in log))
        if success and passed:
            validate_package(destination, args.source)
            passed = args.source in log
        records.append({'case': label, 'returncode': result.returncode, 'expected_success': success,
                        'passed': passed, 'log_sha256': sha(output/(label+'.log'))})
        if not passed:
            raise ValueError('Actual owner launcher exercise failed: '+label+'\n'+log[-4000:])

    try:
        # Use the native Windows PowerShell5 path that the owner handoff names.
        invoke('direct-inner-archive', archive, output/'direct', True)
        nested_inputs = output/'nested artifact inputs with spaces';nested_inputs.mkdir()
        wrapper = nested_inputs/f'{label.lower()}-owner-windows-{args.source}.zip'
        with zipfile.ZipFile(wrapper, 'x', zipfile.ZIP_STORED) as outer:
            for path in sorted(sealed.iterdir()):
                if path.is_file(): outer.write(path, path.name)
        invoke('github-nested-artifact', wrapper, output/'nested', True)
        invoke('stale-destination', archive, output/'direct', False, 'Destination already exists')
        bad = output/'corrupt';bad.mkdir()
        corrupt = bad/archive.name
        shutil.copyfile(archive, corrupt)
        with corrupt.open('ab') as stream: stream.write(b'corrupted-owner-package')
        shutil.copyfile(Path(str(archive)+'.sha256'), Path(str(corrupt)+'.sha256'))
        invoke('corrupted-archive', corrupt, output/'corrupted-extract', False, 'ZIP SHA-256 mismatch')
        wrong = output/'wrong-name';wrong.mkdir()
        shutil.copyfile(archive, wrong/archive.name)
        Path(str(wrong/archive.name)+'.sha256').write_text(metadata['archive_sha256']+'  SWARM005-reused.zip\n')
        invoke('wrong-sidecar-name', wrong/archive.name, output/'wrong-extract', False, 'sidecar does not name')
        absent = output/'missing';absent.mkdir()
        shutil.copyfile(archive, absent/archive.name)
        invoke('missing-sidecar', absent/archive.name, output/'missing-extract', False, 'Missing separate SHA-256 sidecar')
        dispatch = owner_dispatch.qualify(launcher, wrapper, output/'actual owner package with spaces',
                                          output/'dispatch', args.source, metadata)
        records.append({'case': 'actual-owner-graphical-dispatch', 'passed': dispatch['passed'],
                        'expected_success': True, 'evidence': 'dispatch/owner-dispatch-qualification.json',
                        'evidence_sha256': sha(output/'dispatch/owner-dispatch-qualification.json')})
        if not dispatch['passed']:
            raise ValueError('Actual owner PowerShell/CMD graphical dispatch failed: '+json.dumps(dispatch.get('validation_errors')))
    finally:
        summary = {'source_commit': args.source, 'archive_sha256': sha(archive), 'launcher_sha256': sha(launcher),
                   'platform': 'Windows', 'passed': len(records) == 7 and all(r['passed'] for r in records),
                   'graphical_qualification': False, 'graphical_dispatch_passed': len(records) == 7 and records[-1]['passed'],
                   'owner_nvidia_acceptance': 'pending', 'results': records}
        # Keep the original logs and hash receipts, not redundant large binaries.
        for name in ('direct', 'nested', 'nested-artifact', 'corrupt', 'wrong-name', 'missing',
                     'actual owner package with spaces', 'actual owner package with spaces-artifact',
                     'nested artifact inputs with spaces'):
            shutil.rmtree(output/name, ignore_errors=True)
        for path in output.glob(f'{label.lower()}-owner-windows-*.zip'): path.unlink()
        summary['files_sha256'] = {path.relative_to(output).as_posix(): sha(path)
                                  for path in sorted(output.rglob('*')) if path.is_file()}
        (output/'owner-launcher-qualification.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary))


if __name__ == '__main__': main()
