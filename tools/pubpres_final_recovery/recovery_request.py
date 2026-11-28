#!/usr/bin/env python3
"""Admit one deliberate recovery run against the complete resulting Git tree."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REQUEST = '.github/pubpres-recovery-run.json'
BRANCH = 'codex/pubpres-playability-final-001-20261124'
FROZEN = 'c90dbc46e1f57f28e06b1f4205b83467335ff657'
PHASES = ('stock', 'integration')
SHA = re.compile(r'[0-9a-f]{64}\Z')
COMMIT = re.compile(r'[0-9a-f]{40}\Z')


def fingerprint(root=ROOT, ref='HEAD'):
    rows = subprocess.check_output(['git', '-C', str(root), 'ls-tree', '-r', '-z', ref]).split(b'\0')
    selected = [row for row in rows if row and row.split(b'\t', 1)[1].decode() != REQUEST]
    return hashlib.sha256(b'\0'.join(selected)+b'\0').hexdigest()


def validate_record(record):
    if set(record) != {'schema','phase','purpose','frozen_reference','payload_sha256','engine_artifact','physical_acceptance'}:
        raise ValueError('Unexpected recovery request fields')
    if record['schema'] != 'pubpres-recovery-request-v1' or record['phase'] not in PHASES:
        raise ValueError('Unregistered recovery phase')
    if record['frozen_reference'] != FROZEN or record['physical_acceptance'] != 'HOLD':
        raise ValueError('Frozen predecessor or physical disposition differs')
    if not isinstance(record['purpose'],str) or not record['purpose'].strip() or not SHA.fullmatch(record['payload_sha256']):
        raise ValueError('Missing purpose or exact source fingerprint')
    engine = record['engine_artifact']
    if record['phase'] == 'stock':
        if engine is not None: raise ValueError('Stock phase must not silently enable a custom engine')
    else:
        if not isinstance(engine,dict) or set(engine) != {'id','name','sha256','source','run','attempt','proof_sha256'}:
            raise ValueError('Integration requires an independently pinned exact engine artifact')
        if not all(type(engine[key]) is int and engine[key] > 0 for key in ('id','run','attempt')):
            raise ValueError('Invalid engine artifact/run/attempt')
        if not COMMIT.fullmatch(engine['source']) or not SHA.fullmatch(engine['sha256']) or not SHA.fullmatch(engine['proof_sha256']):
            raise ValueError('Invalid engine source/archive/proof identity')
        if engine['name'] != f"pubpres-recovery-atomic-engine-{engine['run']}-{engine['attempt']}":
            raise ValueError('Artifact is not the separately registered atomic engine')
    return record


def validate(root=ROOT):
    request = validate_record(json.loads((root/REQUEST).read_bytes()))
    if request['payload_sha256'] != fingerprint(root):
        raise ValueError('Recovery request does not identify the complete resulting source tree')
    committed = subprocess.check_output(['git','-C',str(root),'show','HEAD:'+REQUEST])
    if committed != (root/REQUEST).read_bytes():
        raise ValueError('Recovery request differs from committed bytes')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        head = subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
        if os.environ.get('GITHUB_REPOSITORY') != 'techrote/cybersand' or os.environ.get('GITHUB_EVENT_NAME') != 'push' \
                or os.environ.get('GITHUB_REF') != 'refs/heads/'+BRANCH or os.environ.get('GITHUB_SHA') != head:
            raise ValueError('Only the source-exact dedicated continuation push may run recovery')
    return request


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fingerprint',action='store_true')
    parser.add_argument('--engine-record',type=Path)
    args=parser.parse_args()
    if args.fingerprint:
        print(fingerprint()); return
    result=validate()
    if args.engine_record and result['engine_artifact']:
        args.engine_record.parent.mkdir(parents=True,exist_ok=True)
        args.engine_record.write_text(json.dumps(result['engine_artifact'],indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a',encoding='utf-8') as stream:
            stream.write('phase='+result['phase']+'\n')

if __name__ == '__main__': main()
