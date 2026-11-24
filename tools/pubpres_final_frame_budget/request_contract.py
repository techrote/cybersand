#!/usr/bin/env python3
"""Bind one component-only build to exact committed experiment and workflow."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import subprocess
import engine_contract

ROOT = engine_contract.ROOT
WORKFLOW = '.github/workflows/pubpres-frame-budget-build.yml'
REQUEST = '.github/pubpres-frame-budget-build-run.json'
EXPECTED = {
    'schema': 'pubpres-frame-budget-component-build-v1',
    'request_id': 'PUBPRES-PLAYABILITY-FINAL-001-frame-budget-build-01',
    'maximum_deferred_opportunities': 4,
    'purpose': 'Build a separately identified default-off bounded Main/render rendezvous engine with exact upstream source, all preceding EGL/font repairs and unchanged compiler/dependency/API/PE acceptance. Application transaction and graphical/gameplay qualification require a separately registered execution.',
    'physical_acceptance': 'HOLD',
}


def inputs(root=ROOT):
    names = {WORKFLOW} | set(engine_contract.LEGACY_INPUTS)
    names.update(p.relative_to(root).as_posix() for p in (root / engine_contract.DIRECTORY).iterdir()
                 if p.is_file() and p.suffix in engine_contract.INPUT_SUFFIXES + ('.md',))
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sorted(names)}


def fingerprint(root=ROOT):
    return hashlib.sha256(json.dumps(inputs(root), sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def validate(root=ROOT):
    request = json.loads((root / REQUEST).read_bytes())
    if request != {**EXPECTED, 'payload_sha256': fingerprint(root)}:
        raise ValueError('Component request does not identify this exact source, scope and workflow')
    names = set(inputs(root)) | {REQUEST}
    for name in sorted(names):
        committed = subprocess.check_output(['git', '-C', str(root), 'show', 'HEAD:' + name])
        if committed != (root / name).read_bytes():
            raise ValueError('Component build input is not exact committed bytes: ' + name)
    if os.environ.get('GITHUB_ACTIONS') == 'true' and (
        os.environ.get('GITHUB_REPOSITORY') != 'techrote/cybersand' or
        os.environ.get('GITHUB_EVENT_NAME') != 'push' or
        os.environ.get('GITHUB_REF') != 'refs/heads/codex/pubpres-playability-final-001-20261124'):
        raise ValueError('Only the dedicated PUBPRES continuation push may build this component')
    return {'request': request, 'files_sha256': inputs(root),
            'source': subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),
            'physical_acceptance': 'HOLD'}


if __name__ == '__main__':
    print(json.dumps(validate(), indent=2))
