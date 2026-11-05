#!/usr/bin/env python3
"""Seal compact cost evidence and one complete paired counterexample."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()

def main():
    source=ROOT/'build/sol-response-cost';target=ROOT/'docs/audits/sol-response-cost-20261105'
    assert not target.exists();target.mkdir()
    manifest=dict(schema='cybersand.sol-response-cost.evidence.v1',execution_source='a47be4e2d2a3208650cc4665fc83ca3c5acedaa5',scope='single-body surrogate; no original SOL admission',files=[],local_raw_files=[])
    def save(name,raw,original=None):
        (target/name).write_bytes(raw);entry=dict(path=name,bytes=len(raw),sha256=sha(raw))
        if original:entry.update(original_path=original.relative_to(ROOT).as_posix(),original_bytes=original.stat().st_size,original_sha256=sha(original.read_bytes()))
        manifest['files'].append(entry)
    def copy_json(name,path):save(name,(json.dumps(json.loads(path.read_text(encoding='utf-8')),indent=2)+'\n').encode(),path)
    copy_json('execution.json',source/'registered-matrix/receipt.json')
    copy_json('comparison.json',source/'registered-matrix/reduction-002/summary.json')
    copy_json('failed-initial.json',source/'initial/receipt.json')
    copy_json('corrected-smoke.json',source/'corrected-smoke/receipt.json')
    copy_json('type-probe.json',source/'type-probe/receipt.json')
    copy_json('reduction-command.json',source/'sealing-3a29/receipt.json')
    copy_json('companion.json',source/'companion.json')
    index={}
    for observer in ['full','minimal']:
        path=next((source/f'registered-matrix/windows/observations/closed-driven-{observer}-w1-r0').glob('*.json'))
        raw=path.read_bytes();save('raw-'+observer+'.json',raw,path);data=json.loads(raw)
        captures=[data['initial_payload'],*[s['payload'] for s in data['steps'] if 'payload' in s],data['final_payload']]
        for item in captures:
            blob=ROOT/'docs/audits/sol-chamber-20261105/reference-payloads'/(item['sha256']+'.cyps')
            assert blob.stat().st_size==item['bytes'] and sha(blob.read_bytes())==item['sha256'],'Reference bytes differ; preserve and report instead of fabricating'
            index[item['path']]=blob.relative_to(ROOT).as_posix()
    save('reference-payload-index.json',(json.dumps(index,indent=2)+'\n').encode())
    excluded={'.dll','.so','.exe','.obj','.o','.zip','.pyc'}
    for folder in ['initial','corrected-smoke','registered-matrix','type-probe','sealing-3a29']:
        for path in sorted((source/folder).rglob('*')):
            if not path.is_file() or 'godot' in path.relative_to(source).parts or path.suffix in excluded:continue
            manifest['local_raw_files'].append(dict(path=path.relative_to(ROOT).as_posix(),bytes=path.stat().st_size,sha256=sha(path.read_bytes())))
    (target/'manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
    print(json.dumps(dict(files=len(manifest['files']),raw_files=len(manifest['local_raw_files']),unique_reference_payloads=len(set(index.values())))))

if __name__=='__main__':main()
