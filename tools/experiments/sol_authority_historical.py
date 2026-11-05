#!/usr/bin/env python3
"""Extract exact historical geometry/RLE witnesses, never live authority."""
import argparse
import hashlib
import json
from pathlib import Path
import la_selective_experiment as p

PIN='1598115c9065239cc1eaec11e99077274b457be1'
REPORT='docs/audits/sol281-20261103/hosted/9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d/cohorts/linux/mechanism/host/synchronized-contact-w1.json'
SHA='7b91158f0d4652cb415e9dfd614cda4ab535685f39cfbcf663457c26cf513724'

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();out=args.output.resolve();assert not out.exists()
    raw=p.git('show',PIN+':'+REPORT);assert hashlib.sha256(raw).hexdigest()==SHA;data=json.loads(raw)
    control=next(v for v in data['controls'] if v['id']=='interior_without_face')
    cases={name:next(v for v in data['cases'] if v['id']==name+'/candidate') for name in ['embedded_stationary','rotated_compound']}
    result=dict(schema='cybersand.sol-authority.historical-excerpts.v1',extraction_source=p.git('rev-parse','HEAD').decode().strip(),
        imported_source=PIN,report=REPORT,report_sha256=SHA,report_bytes=len(raw),report_blob=p.git('rev-parse',PIN+':'+REPORT).decode().strip(),
        execution_source='9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d',original_schema=data['schema'],original_source=data['source'],original_source_sha256=data['source_sha256'],
        interior_control=control,negative_cases={k:{'id':v['id'],'initial':v['initial'],'native_field':v['native_field'],'aggregate_owned':v['aggregate_owned'],'payload_preserved':v['payload_preserved']} for k,v in cases.items()},
        geometries={str(v['initial']['measurement']['geometry_id']):data['geometries'][v['initial']['measurement']['geometry_id']] for v in cases.values()},
        native_fields={key:data['native_fields'][key] for key in {control['native_field']}|{v['native_field'] for v in cases.values()}},
        live_authority=False,actuation_permitted=False,scope='Exact copied historical fields/corners/poses and material-ID RLE; omitted tuples,temperature,residency,ownership/hold remain unavailable. Geometry negatives only.')
    source=json.loads((p.ROOT/'godot/tests/fixtures/sol_chamber/source.json').read_text(encoding='utf-8'))
    assert result['original_source']==source['original']
    out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
    print('Exact historical witnesses imported',len(raw),SHA,'output_sha256',hashlib.sha256(out.read_bytes()).hexdigest())

if __name__=='__main__':main()
