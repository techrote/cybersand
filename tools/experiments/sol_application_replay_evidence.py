#!/usr/bin/env python3
"""Curate retained-record analysis with separate source/runtime/platform identities."""
import hashlib
import json
from pathlib import Path
import struct
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'build/sol-active-normal-live/application-replay-001'
OUT=ROOT/'docs/audits/sol-application-replay-20261105'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):
    assert not path.exists(),'Retained outputs are immutable'
    path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))

def main():
    assert not OUT.exists();OUT.mkdir(parents=True)
    receipt=read(FOLDER/'receipt.json');assert all(c['clean'] and c['exit']==0 for c in receipt['commands'])
    summary=read(FOLDER/'windows/summary.json');assert summary['observations']==1080
    comparison=read(FOLDER/'cross-analysis-comparison.json')
    assert comparison['summary_bytes_equal'] and (FOLDER/'windows/summary.json').read_bytes()==(FOLDER/'linux/summary.json').read_bytes()
    assert comparison['record_hashes']=={h:sha(FOLDER/h/'records.json') for h in ['windows','linux']}
    reconstructed=read(FOLDER/'windows/records.json')
    assert len(comparison['differences'])==comparison['difference_count']
    for delta in comparison['differences']:
        parts=delta['path'].strip('/').split('/');target=reconstructed
        for part in parts[:-1]:target=target[int(part)] if isinstance(target,list) else target[part]
        key=int(parts[-1]) if isinstance(target,list) else parts[-1]
        assert struct.pack('<d',target[key])==struct.pack('<d',delta['windows']);target[key]=delta['linux']
    assert (json.dumps(reconstructed,indent=2)+'\n').encode('utf-8')==(FOLDER/'linux/records.json').read_bytes(),'Incomplete cross-analysis differences'
    head=p.git('rev-parse','HEAD').decode().strip();artifacts=[]
    for name,source in [('execution.json','receipt.json'),('summary.json','windows/summary.json'),('records.json','windows/records.json'),('cross-analysis.json','cross-analysis-comparison.json')]:
        path=FOLDER/source;public=OUT/name;write(public,read(path))
        artifacts.append(dict(source_path=str(path.relative_to(ROOT)),raw_sha256=sha(path),public_file=name,public_lf_sha256=sha(public),bytes=public.stat().st_size))
    write(OUT/'custody.json',dict(curation_source=head,analysis_source=summary['analysis_source'],physical_execution_source=summary['physical_execution_source'],runtime_build_source=summary['runtime_build_source'],artifacts=artifacts,
        linux_retained_records=dict(path=str((FOLDER/'linux/records.json').relative_to(ROOT)),sha256=sha(FOLDER/'linux/records.json')),
        scope='Same Windows physical recordings analyzed on actual Windows/Linux Python; not two new physical runs. Public Windows derivative plus complete cross-analysis differences; Linux raw derivative retained locally.',live_actuation=False))
    print('Curated1080recorded applications; cross-host rounding differences retained')

if __name__=='__main__':main()
