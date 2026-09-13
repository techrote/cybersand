"""Validate completed matrix and summarize measured work without assuming speedup."""
import argparse,json,statistics
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('matrix',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
results=json.loads((a.matrix/'results.json').read_text());assert len(results)==480
by_id={r['id']:r for r in results};samples={};checks=0
for r in results:
    rows=[json.loads(line) for line in (a.matrix/(r['id']+'.jsonl')).read_text().splitlines()][:-1]
    samples[r['id']]=rows
    assert r['work']['overflow']==0 and r['work']['allocations']==0,r['id']
    for row in rows:
        for material in [2,14,33]:
            expected=1080 if r['layout']=='poured' and material==33 and row['tick']>=300 else rows[0]['counts'][material]
            assert row['counts'][material]==expected,(r['id'],row['tick'],material)
        assert row['water']==rows[0]['water']+row['injected_water'],r['id']
        checks+=1
    if r['layout'] in ['powder','packed','film']: assert r['work']['late_moves']==0,r['id']
for r in results:
    if r['workers']==4:
        twin=r['id'][:-1]+'1'
        assert samples[r['id']]==samples[twin],r['id']+' worker mismatch'
        assert r['events']==by_id[twin]['events'],r['id']+' event mismatch'
    if r['layout'] in ['packed','poured'] and not r['sampled']:
        twin='p0'+r['id'][2:]
        assert samples[r['id']]==samples[twin],r['id']+' indirect Mercury drift'
summary=[]
for profile in range(3):
    for sampled in range(2):
        for layout in ['powder','erosion','loose','poured','packed','film','sparse','sustained']:
            for workers in [1,4]:
                rows=[r for r in results if (r['profile'],r['sampled'],r['layout'],r['workers'])==(profile,sampled,layout,workers)]
                med=lambda f: statistics.median(f(r) for r in rows)
                depth_rows=[r for r in rows if 'eroded_initial_sites' in r['final']]
                depth_med=lambda key: statistics.median(r['final'][key] for r in depth_rows) if depth_rows else None
                summary.append(dict(profile=profile,sampled=sampled,layout=layout,workers=workers,seeds=5,
                    p50_us=med(lambda r:r['work']['p50_us']),p95_us=med(lambda r:r['work']['p95_us']),
                    max_us=max(r['work']['max_us'] for r in rows),total_us=med(lambda r:r['work']['total_us']),
                    ns_per_visited=med(lambda r:r['work']['total_us']*1000/max(1,r['work']['visited'])),
                    visited=med(lambda r:r['work']['visited']),active_blocks=med(lambda r:r['work']['active_blocks_sum']),
                    active_cores=med(lambda r:r['work']['active_cores_sum']),late_moves=med(lambda r:r['work']['late_moves']),
                    lateral_probes=med(lambda r:r['events']['10']),flow_probes=med(lambda r:r['events']['11']),
                    water_transfer_mass=med(lambda r:r['events']['4']),empty_moves=med(lambda r:r['events']['1']),
                    mixing=med(lambda r:r['events']['8']),pickup=med(lambda r:r['events']['9']),
                    interface_edges=med(lambda r:r['final']['interface_edges']),deposited=med(lambda r:r['final']['deposited']),
                    depth_seeds=len(depth_rows),erosion_depth=depth_med('erosion_depth'),eroded_sites=depth_med('eroded_initial_sites')))
report=dict(cases=len(results),reused_cases=sum(r.get('reused',False) for r in results),samples_checked=checks,conservation=True,worker_parity=True,mercury_presets_unchanged=True,
            prepared_allocations=0,telemetry_overflow=0,note='Descriptive shared-host instrumented timing; no isolated speedup claim. Blocks are resident active activity blocks after tick, including excluded work. Erosion depth includes ordinary initial slump; compare fresh controls.',groups=summary)
a.output.write_text(json.dumps(report,indent=2));print('Validated',len(results),'cases and',checks,'samples')
