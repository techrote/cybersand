#!/usr/bin/env python3
"""Curate additive LF JSON receipts; preserve raw evidence hashes and scope."""
import json
import hashlib
from pathlib import Path
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/audits/sol-active-normal-live-20261105'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):
    assert not path.exists(),'Never overwrite retained public evidence'
    path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))

def main():
    head=p.git('rev-parse','HEAD').decode().strip()
    for suite in ['authored','workload']:
        folder=ROOT/'build/sol-active-normal-live'/(suite+'-full-001')
        reduction=read(folder/'independent-001/manifest.json');summary=read(folder/'synthesis-001/summary.json')
        assert reduction['full_registered_evidence_complete'] and summary['episodes']==len(reduction['results'])
        artifacts=[]
        for suffix,source in [('execution','receipt.json'),('reduction','independent-001/manifest.json'),('summary','synthesis-001/summary.json'),('episodes','synthesis-001/episodes.json')]:
            original=folder/source;public=OUT/(suite+'-full-'+suffix+'.json')
            write(public,read(original))
            artifacts.append(dict(source_path=str(original.relative_to(ROOT)),raw_sha256=sha(original),public_file=public.name,public_lf_sha256=sha(public),bytes=public.stat().st_size))
        custody=dict(schema='cybersand.sol-active-normal-live.authored-workload-custody.v1',suite=suite,curation_source=head,
            execution_source=reduction['execution_source'],independent_analysis_source=reduction['analysis_source'],synthesis_source=summary['synthesis_source'],runtime_build_source=reduction['runtime_build_source'],
            episodes=summary['episodes'],steps=summary['steps'],matched_initial_groups=len(summary['common_initial_inputs']),artifacts=artifacts,
            scope=summary['scope'],transport='Public JSON normalized LF; raw input hashes unchanged. Full raw reports/payloads/logs retained locally.')
        write(OUT/(suite+'-full-custody.json'),custody)
    # A small authenticated excerpt supports portable adversarial all-owner checks.
    folder=ROOT/'build/sol-active-normal-live/authored-full-001'
    manifest=read(folder/'independent-001/manifest.json')
    entry=next(e for e in manifest['results'] if e['name']=='windows-shared-granular-bodies-selective-active-w1-r0')
    source=ROOT/entry['summary']['raw_path'];assert sha(source)==entry['summary']['raw_sha256'];raw=read(source)
    excerpt=dict(initial_sample=raw['initial_sample'],steps=[raw['steps'][i] for i in [30,31]],lifecycle=raw['lifecycle'])
    public=OUT/'authored-application-excerpt.json';write(public,excerpt)
    write(OUT/'authored-application-excerpt-custody.json',dict(curation_source=head,source_path=str(source.relative_to(ROOT)),source_sha256=sha(source),
        public_file=public.name,public_lf_sha256=sha(public),coordinate=entry['coordinate'],copied_steps=[30,31],
        scope='Exact copied application-audit fields from two steps of a three-owner episode; not full-window physics evidence.'))
    assert head==p.git('rev-parse','HEAD').decode().strip()
    print('Curated authored192/workload72 and exact two-step three-owner excerpt')

if __name__=='__main__':main()
