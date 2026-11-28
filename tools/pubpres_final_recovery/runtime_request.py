#!/usr/bin/env python3
"""One resulting-source M/C/D rebuild with one shared dependency per platform."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
REQUEST='.github/pubpres-recovery-runtimes-run.json'
M='00cdb02f103265b6dc5224c68283e9a0c8cb449f'
D='c90dbc46e1f57f28e06b1f4205b83467335ff657'


def fingerprint(root=ROOT):
    rows=subprocess.check_output(['git','-C',str(root),'ls-tree','-r','-z','HEAD']).split(b'\0')
    rows=[row for row in rows if row and row.split(b'\t',1)[1].decode()!=REQUEST]
    return hashlib.sha256(b'\0'.join(rows)+b'\0').hexdigest()


def validate():
    request=json.loads((ROOT/REQUEST).read_bytes())
    if set(request)!={'schema','purpose','historical_accepted_main','frozen_donor','payload_sha256','physical_acceptance'} \
            or request['schema']!='pubpres-recovery-shared-native-build-v1' or request['historical_accepted_main']!=M \
            or request['frozen_donor']!=D or request['payload_sha256']!=fingerprint() \
            or request['physical_acceptance']!='HOLD' or not isinstance(request['purpose'],str) or not request['purpose'].strip():
        raise ValueError('Shared-runtime request does not bind exact resulting source and original controls')
    if subprocess.check_output(['git','-C',str(ROOT),'show','HEAD:'+REQUEST])!=(ROOT/REQUEST).read_bytes():
        raise ValueError('Runtime request differs from committed bytes')
    if os.environ.get('GITHUB_ACTIONS')=='true':
        head=subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
        if os.environ.get('GITHUB_REPOSITORY')!='techrote/cybersand' or os.environ.get('GITHUB_EVENT_NAME')!='push' \
                or os.environ.get('GITHUB_REF')!='refs/heads/codex/pubpres-playability-final-001-20261124' \
                or os.environ.get('GITHUB_SHA')!=head:
            raise ValueError('Only the exact principal continuation push may build shared comparison runtimes')
    return request


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--fingerprint',action='store_true');args=parser.parse_args()
    print(fingerprint() if args.fingerprint else json.dumps(validate(),indent=2))
