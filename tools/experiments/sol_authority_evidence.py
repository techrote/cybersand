#!/usr/bin/env python3
"""Curate offline receipts/traces; retain failed and review-invalidated attempts."""
import hashlib
import json
from pathlib import Path
import re
import la_selective_experiment as p
import sol_authority_model as m
from test_sol_authority_model import synthetic_capture

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/audits/sol-authority-20261105'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):
    assert not path.exists(),'Never overwrite retained evidence'
    path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))

def main():
    head=p.git('rev-parse','HEAD').decode().strip();attempts=[]
    for run,expected in [('authority-model-001',1),('authority-model-002',0),('authority-model-linux-002',0),('authority-model-004',0)]:
        path=ROOT/'build/sol-active-normal-live'/run/'receipt.json';receipt=read(path)
        for command in receipt['commands']:
            assert command['exit']==expected;log=ROOT/command['log'];assert sha(log)==command['log_sha256']
            count=int(re.search(r'Ran (\d+) tests',log.read_text(encoding='utf-8'))[1])
            status='FAILED expectation:12pass/1fail' if expected else ('PASS copied-value tests; external acceptance pending' if run.endswith('004') else 'INCOMPLETE:14pass but protocol defects found by review')
            attempts.append(dict(run=run,source=receipt['source'],receipt_sha256=sha(path),command=command,test_count=count,qualification=status))
    packet=synthetic_capture();capture=m.validate_capture(packet);assert capture['status']=='COMPLETE_FOR_NOOP_MODEL'
    stamp=packet['identity'];lease=m.LeaseModel();capture_digest=capture['captured_digest']
    for kind,now in [('grant',0),('capture',1),('main_validate',2),('noop_ack',3),('release',4),('grant',5)]:lease.event(kind,now,stamp=stamp,packet=packet,capture_digest=capture_digest)
    assert lease.state=='RELEASED' and lease.snapshot()['consumed_leases']==1
    historical=read(OUT/'historical-excerpts.json');control=historical['interior_control'];negatives={}
    negatives['nine_Sand_sixteen_Wall']=m.hard_probe(control['geometry']['proxies'],historical['native_fields'][control['native_field']])
    for name,case in historical['negative_cases'].items():
        geometry=historical['geometries'][str(case['initial']['measurement']['geometry_id'])]
        negatives[name]=m.hard_probe(geometry['proxies'],historical['native_fields'][case['native_field']]);negatives[name]['complete_capture_validation']=m.validate_capture(case)
    repro_path=ROOT/'build/sol-active-normal-live/authority-review-repro-002/reproduce.log';repro=read(repro_path)
    replay={k:v for k,v in repro['results'].items() if k!='expired_full_trace'}
    old=repro['results']['expired_full_trace'];replay['expired_full_trace']=dict(state=old['state'],active=old['active'],attempts=old['snapshot']['attempts'],consumed_leases=old['snapshot']['consumed_leases'],trace_overflow=old['snapshot']['trace_overflow'])
    write(OUT/'review-reproduction.json',dict(source=repro['source'],model_sha256=repro['model_sha256'],raw_log_sha256=sha(repro_path),results=replay,qualification=repro['qualification']))
    write(OUT/'synthetic-capture.json',packet)
    write(OUT/'offline-results.json',dict(**m.scope(),analysis_source=head,attempts=attempts,synthetic_capture=capture,no_op_lifecycle=lease.snapshot(),historical_geometry=negatives,
        scope='Complete synthetic data/model rules only; no actual native/Rapier capture, Active hold, application or physical-clearance admission'))
    names=['synthetic-capture.json','offline-results.json','review-reproduction.json']
    write(OUT/'result-custody.json',dict(analysis_source=head,files={name:sha(OUT/name) for name in names},inputs={name:sha(OUT/name) for name in ['input-custody.json','historical-excerpts.json','source-map.json']},
        scripts={name:sha(ROOT/'tools/experiments'/name) for name in ['sol_authority_model.py','test_sol_authority_model.py','sol_authority_evidence.py']},live_authority=False,actuation_permitted=False))
    assert head==p.git('rev-parse','HEAD').decode().strip();print('Curated20Windows/20Linux;13failed and14review-invalidated attempts retained; all actual counters zero')

if __name__=='__main__':main()
