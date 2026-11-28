#!/usr/bin/env python3
"""Independent read-only audit of downloaded Strata evaluator/execution artifacts.

This executes no Godot or launcher. It validates already-retained execution
receipts, the actual downloaded ZIPs, every pristine payload byte, and the
source-frozen package verifier. It never upgrades a failed campaign to passed.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import zipfile


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def original_artifact(path, metadata, source, prefix):
    require(metadata.get('expired') is False, 'Artifact expired')
    require(metadata.get('workflow_run', {}).get('head_sha') == source, 'Artifact belongs to another source')
    require(metadata.get('name', '').startswith(prefix + source + '-'), 'Unexpected artifact name')
    attempt = metadata['name'].removeprefix(prefix + source + '-')
    require(re.fullmatch(r'[1-9][0-9]*', attempt), 'Artifact has no exact workflow-attempt identity')
    digest = str(metadata.get('digest', '')).removeprefix('sha256:')
    require(re.fullmatch(r'[0-9a-f]{64}', digest), 'Artifact lacks original SHA-256 metadata')
    require(path.stat().st_size == metadata.get('size_in_bytes') and sha(path) == digest,
            'Downloaded artifact bytes disagree with original API metadata')
    return {'id': metadata['id'], 'name': metadata['name'], 'bytes': path.stat().st_size,
            'sha256': digest, 'run_id': metadata['workflow_run']['id'], 'run_attempt': int(attempt)}


def extract_pristine(archive, target):
    require(not target.exists(), 'Refusing to overwrite an inspection directory')
    target.mkdir(parents=True)
    with zipfile.ZipFile(archive) as tree:
        names = tree.namelist()
        require(len(names) <= 20000 and len(names) == len(set(names)), 'Duplicate or excessive ZIP entries')
        require(sum(item.file_size for item in tree.infolist()) <= 2 * 1024**3, 'ZIP exceeds predeclared 2GiB audit budget')
        for item in tree.infolist():
            name = item.filename
            parts = PurePosixPath(name).parts
            mode = item.external_attr >> 16
            require(name and not name.startswith('/') and '\\' not in name and ':' not in name
                    and '..' not in parts and '.' not in parts and not stat.S_ISLNK(mode), 'Unsafe ZIP entry: ' + name)
            path = target.joinpath(*parts)
            if item.is_dir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with tree.open(item) as source, path.open('xb') as output:
                    while chunk := source.read(1024 * 1024):
                        output.write(chunk)
    return len(names)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--package-artifact', type=Path, required=True)
    parser.add_argument('--package-metadata', type=Path, required=True)
    parser.add_argument('--execution-artifact', type=Path, required=True)
    parser.add_argument('--execution-metadata', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    require(re.fullmatch(r'[0-9a-f]{40}', args.source), 'Exact application source required')
    actual_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=args.repository, text=True).strip()
    require(actual_head == args.source, 'Verifier checkout is not the qualified application commit')
    require(not args.output.exists(), 'Refusing to overwrite original audit output')
    args.output.mkdir(parents=True)
    package_metadata = json.loads(args.package_metadata.read_text())
    execution_metadata = json.loads(args.execution_metadata.read_text())
    package_outer = original_artifact(args.package_artifact, package_metadata, args.source, 'strata2-workbench-windows-evaluator-')
    execution_outer = original_artifact(args.execution_artifact, execution_metadata, args.source, 'strata2-package-evidence-')
    require(package_outer['run_id'] == execution_outer['run_id'], 'Package and extracted execution belong to different runs')
    require(package_outer['run_attempt'] == execution_outer['run_attempt'], 'Package and extracted execution belong to different run attempts')
    download = args.output / 'download'
    extract_pristine(args.package_artifact, download)
    inner = list(download.rglob('CyberSand-Strata2-Workbench-Windows-*.zip'))
    require(len(inner) == 1, 'Expected exactly one portable evaluator ZIP')
    inner = inner[0]
    sidecar = inner.with_suffix('.zip.sha256')
    expected_line = sha(inner) + '  ' + inner.name
    require(sidecar.is_file() and sidecar.read_text().strip() == expected_line, 'Inner ZIP checksum sidecar differs from actual bytes')
    pristine = args.output / 'pristine'
    extract_pristine(inner, pristine)
    manifest_path = pristine / 'evaluation-manifest.json'
    manifest_bytes = manifest_path.read_bytes()
    outer_manifest = inner.with_suffix('.manifest.json')
    require(outer_manifest.read_bytes() == manifest_bytes, 'External payload manifest differs from the actual shipped manifest')
    manifest = json.loads(manifest_bytes)
    expected_files = manifest['files_sha256']
    actual_files = {path.relative_to(pristine).as_posix(): sha(path) for path in sorted(pristine.rglob('*'))
                    if path.is_file() and path != manifest_path}
    require(actual_files == expected_files, 'Independent full payload inventory differs from shipped manifest')
    sys.path.insert(0, str(args.repository / 'tools'))
    sys.path.insert(0, str(args.repository / 'tools/ci'))
    package = importlib.import_module('package_strata2_workbench')
    admitted = package.verify(pristine, pristine=True)
    source = package.qualification.identity()
    execution = args.output / 'original-execution'
    extract_pristine(args.execution_artifact, execution)
    extracted = package.qualification.verify_campaign(execution / 'extracted', source)
    require(extracted['platform'] == 'win32', 'Extracted campaign is not actual Windows execution')
    launcher_path = execution / 'launcher.json'
    launcher = json.loads(launcher_path.read_text(encoding='utf-8-sig'))
    stdout = (execution / 'launcher.stdout.log').read_text(encoding='utf-8-sig')
    stderr = (execution / 'launcher.stderr.log').read_text(encoding='utf-8-sig')
    require(launcher.get('exit_code') == 0 and launcher.get('source_revision') == args.source
            and type(launcher.get('wrapper_pid')) is int and launcher['wrapper_pid'] > 0,
            'Actual shipped launcher wrapper did not succeed with exact source')
    require(not re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:', stdout + stderr), 'Shipped launcher logs contain a runtime error')
    lines = [line.removeprefix('STRATA_WORKBENCH_LAUNCH_ADMITTED ') for line in stdout.splitlines()
             if line.startswith('STRATA_WORKBENCH_LAUNCH_ADMITTED ')]
    require(len(lines) == 1, 'Actual ordinary launcher has no unique admission receipt')
    launch_admission = json.loads(lines[0])
    require(launch_admission == launcher.get('admitted') and launch_admission.get('source_revision') == args.source
            and launch_admission.get('workbench_script') == 'res://scripts/shared_workbench.gd'
            and launch_admission.get('strata_enabled') is False and launch_admission.get('extent') == [2048, 2048]
            and type(launch_admission.get('world_generation')) is int and launch_admission['world_generation'] > 0
            and package.qualification.instance_id(launch_admission.get('worker_id')),
            'Ordinary default-OFF launcher lacks exact real Play ownership')
    (args.output / 'verified-payload-manifest.json').write_bytes(manifest_bytes)
    receipt = {'schema':'strata2-independent-final-downloaded-evaluator-v1','status':'passed',
        'source_commit':args.source,'source_tree':source['source_tree'],
        'package_artifact':package_outer,'execution_artifact':execution_outer,
        'inner_zip':{'name':inner.name,'bytes':inner.stat().st_size,'sha256':sha(inner)},
        'payload_manifest_sha256':sha(manifest_path),'payload_files':len(actual_files),
        'payload_bytes':sum((pristine / name).stat().st_size for name in actual_files),
        'payload_files_sha256':actual_files,'runtime':admitted['runtime'],'gallery':admitted['gallery'],
        'original_campaign_sha256':{name:sha(pristine / 'qualification' / name / 'qualification.json') for name in ('linux','windows')},
        'extracted_windows_campaign_sha256':sha(execution / 'extracted/qualification.json'),
        'ordinary_launcher_sha256':sha(launcher_path),'ordinary_launcher_admission':launch_admission,
        'auditor_sha256':sha(Path(__file__)),
        'scope':'Actual downloaded original artifacts, independent pristine extraction and every payload byte; source-frozen verification of both original platform campaigns, actual extracted Windows campaign and shipped ordinary launcher receipts. No new runtime execution or physical Windows/NVIDIA acceptance is inferred.'}
    receipt_path = args.output / 'independent-audit.json'
    receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print(json.dumps({key:receipt[key] for key in ('status','source_commit','source_tree','inner_zip','payload_manifest_sha256','payload_files','payload_bytes')}))
    print('INDEPENDENT_AUDIT_RECEIPT ' + str(receipt_path))


if __name__ == '__main__':
    main()
