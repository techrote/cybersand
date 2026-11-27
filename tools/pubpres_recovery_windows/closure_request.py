#!/usr/bin/env python3
"""Explicit source-bound closure admission or full platform/package campaign."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
REQUEST='.github/pubpres-closure-run.json'
BRANCH='codex/pubpres-playability-final-001-20261124'
M='00cdb02f103265b6dc5224c68283e9a0c8cb449f'
D='c90dbc46e1f57f28e06b1f4205b83467335ff657'


def fingerprint(root=ROOT):
    rows=subprocess.check_output(['git','-C',str(root),'ls-tree','-r','-z','HEAD']).split(b'\0')
    selected=[row for row in rows if row and row.split(b'\t',1)[1].decode()!=REQUEST]
    return hashlib.sha256(b'\0'.join(selected)+b'\0').hexdigest()


def validate_record(value):
    fields={'schema','phase','purpose','historical_main','current_main','frozen_donor','payload_sha256','physical_acceptance'}
    if not isinstance(value,dict) or set(value)!=fields or value['schema']!='pubpres-closure-run-v1' \
        or value['phase'] not in ('admission','runtimes','full','linux-replay','windows-focus','delivery') or value['historical_main']!=M or value['frozen_donor']!=D \
        or not isinstance(value['current_main'],str) or not re.fullmatch('[0-9a-f]{40}',value['current_main']) \
        or not isinstance(value['payload_sha256'],str) or not re.fullmatch('[0-9a-f]{64}',value['payload_sha256']) \
        or not isinstance(value['purpose'],str) or not value['purpose'].strip() or value['physical_acceptance']!='HOLD':
        raise ValueError('Unregistered closure request, source role or physical disposition')
    return value


def validate(root=ROOT):
    value=validate_record(json.loads((root/REQUEST).read_bytes()))
    if value['payload_sha256']!=fingerprint(root):
        raise ValueError('Closure request does not identify the complete resulting source tree')
    if subprocess.check_output(['git','-C',str(root),'show','HEAD:'+REQUEST])!=(root/REQUEST).read_bytes():
        raise ValueError('Closure request differs from committed source')
    if os.environ.get('GITHUB_ACTIONS')=='true':
        head=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
        if os.environ.get('GITHUB_REPOSITORY')!='techrote/cybersand' or os.environ.get('GITHUB_EVENT_NAME')!='push' \
            or os.environ.get('GITHUB_REF')!='refs/heads/'+BRANCH or os.environ.get('GITHUB_SHA')!=head:
            raise ValueError('Closure can execute only the explicit principal continuation push')
    return value


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seal',action='store_true')
    parser.add_argument('--phase',choices=('admission','runtimes','full','linux-replay','windows-focus','delivery'),default='admission')
    parser.add_argument('--current-main')
    parser.add_argument('--purpose')
    args=parser.parse_args()
    if args.seal:
        value=validate_record({'schema':'pubpres-closure-run-v1','phase':args.phase,'purpose':args.purpose,
            'historical_main':M,'current_main':args.current_main,'frozen_donor':D,
            'payload_sha256':fingerprint(),'physical_acceptance':'HOLD'})
        (ROOT/REQUEST).write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))
        print('Prepared source-bound request; commit this marker before publishing the principal branch.')
        return
    value=validate()
    if os.environ.get('GITHUB_OUTPUT'):
        from recovery_policy import requires_atomic, selection
        windows_lanes=['all'] if requires_atomic(selection()) else ['package','comparison']
        with open(os.environ['GITHUB_OUTPUT'],'a',encoding='utf-8') as stream:
            stream.write('phase='+value['phase']+'\ncurrent_main='+value['current_main']+'\n')
            stream.write('windows_lanes='+json.dumps(windows_lanes)+'\n')
    print(json.dumps(value,indent=2))


if __name__=='__main__':main()
