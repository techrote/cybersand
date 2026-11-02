"""Reduce registered LA captures without treating repeated events as replicates."""
import argparse,hashlib,json,math,statistics
from pathlib import Path
def quantile(values,p):
    values=sorted(values)
    return values[min(len(values)-1,math.ceil(p*len(values))-1)] if values else None
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def reduce_capture(path):
    raw=json.loads(path.read_text(encoding='utf-8'));rows=raw.get('rows',[])
    if not raw.get('ok') or not rows:return {'status':'failed','metrics':None,'raw_sha256':digest(path)}
    barrel=raw['case']['kind']=='barrel'
    positions=[r['out'][0:2] if barrel else r['position'] for r in rows]
    velocities=[r['out'][3:5] if barrel else r['velocity'] for r in rows]
    entries=[r['vertical_depth'] if barrel else r['entry_com'] for r in rows]
    tail=positions[-300:];tail_v=velocities[-300:]
    mechanics=[r.get('gcr',{}) if barrel else r.get('metrics',{}).get('last_compound_observation',{}).get('native_diagnostics',{}) for r in rows]
    overlap=[r['post_overlap'] if barrel else m.get('cellular_overlap_post') for r,m in zip(rows,mechanics)]
    overlap_values=[v for v in overlap if isinstance(v,(int,float))]
    conservation=all(r.get('conserved',False) for r in rows) if barrel else None
    if not barrel:
        before=raw.get('before',{}).get('diagnostic_snapshot',{});after=raw.get('after',{}).get('diagnostic_snapshot',{})
        if before and after:
            b=list(before.get('counts',[]));a=list(after.get('counts',[]))
            # Payload transfers520 cells out of native source; confirmed cut8,
            # isolated stump20 and actual recorded excavation are separate edits.
            expected=b[:]
            if len(expected)>43:expected[43]-=528+(20 if raw['case']['surroundings'].startswith('isolated_') else 0)
            for edit in raw.get('edits',[]):
                eb=edit.get('before',{}).get('diagnostic_snapshot',{}).get('counts',[])
                ea=edit.get('after',{}).get('diagnostic_snapshot',{}).get('counts',[])
                if len(eb)==len(expected)==len(ea):expected=[v+y-x for v,x,y in zip(expected,eb,ea)]
            conservation=len(a)==len(expected) and all(v==w for i,(v,w) in enumerate(zip(a,expected)) if i not in [0,3]) and before.get('water_mass')==after.get('water_mass')
    normal=[m.get('normal_accepted',0) for m in mechanics]
    tangent=[m.get('tangent_accepted',0) for m in mechanics]
    def distribution(values):
        return {'p50':quantile(values,.5),'p95':quantile(values,.95),'p99':quantile(values,.99),'max':max(values) if values else None}
    timing={}
    if barrel:
        for index,name in enumerate(['rapier_us','coupling_us','native_tick_us','apply_us']):
            timing[name]=distribution([r['times_us'][index] for r in rows])
    else:
        for name in ['worker_step_ms','native_tick_ms']:
            timing[name]=distribution([r['metrics'][name] for r in rows])
        for name,total,count in [('main_sync_ms','main_sync_ms_total','main_sync_segments'),('rapier_step_ms','rapier_step_ms_total','timed_rapier_steps')]:
            values=[]
            previous=rows[0]['metrics']
            for r in rows[1:]:
                current=r['metrics'];n=current[count]-previous[count]
                if n>0:values.append((current[total]-previous[total])/n)
                previous=current
            timing[name+'_per_observation_mean']=distribution(values)
    out={'status':'captured','raw_sha256':digest(path),'capture_identity':raw.get('identity',{}),'rows':len(rows),'entry_peak':max(entries),
         'entry_definition':'union bottom relative to bed surface' if barrel else 'COM relative to release; not cellular penetration',
         'overlap_peak_observed':max(overlap_values) if overlap_values else None,'overlap_coverage':len(overlap_values)/len(rows),
         'rebound_upward':max(0,-min(v[1] for v in velocities)),
         'tail_x_span':max(p[0] for p in tail)-min(p[0] for p in tail),'tail_y_span':max(p[1] for p in tail)-min(p[1] for p in tail),
         'tail_abs_vy_p95':quantile([abs(v[1]) for v in tail_v],.95),'material_conserved':conservation,
         'normal_max':max(normal),'tangent_max':max(tangent),'max_nodes':max(m.get('nodes',0) for m in mechanics),
         'max_updates':max(m.get('updates',0) for m in mechanics),'passive_rejections':sum(bool(m.get('passivity_rejected',False)) for m in mechanics),
         'mass':raw.get('mass',raw['case'].get('spec',{}).get('mass')),'inertia':raw.get('inertia'),
         'timing_scope':'functional instrumented concurrent OS captures; not uncontended',
         'timing':timing,
         'hard_floor_plane_reached':any(r.get('hard_floor_contact',False) if barrel else r.get('floor_plane_flag',False) for r in rows),
         'hard_wall_plane_reached':None if barrel else any(r.get('wall_plane_flag',False) for r in rows),
         'tail_normal_max':max(normal[-300:]),'tail_tangent_max':max(tangent[-300:])}
    if not barrel and raw['case']['surroundings'] in ['isolated_dry','isolated_water']:
        out['negative_control_zero_granular']=all(m.get('normal_accepted',0)==0 and m.get('tangent_accepted',0)==0 and m.get('event_budget_cost',0)==0 for m in mechanics)
        out['negative_control_observation_coverage']=sum(bool(m.get('computed',False)) for m in mechanics)/len(rows)
    return out
def main():
    parser=argparse.ArgumentParser();parser.add_argument('campaign',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    protocol=json.loads((Path(__file__).resolve().parents[2]/'docs/audits/gcr-load-2026-11-02/protocol.json').read_text())
    captures={};pairs=[]
    for platform in ['windows','linux']:
        for case in protocol['cases']:
            pair={}
            for arm in ['A1','LA']:
                key=f'{platform}-{case["id"]}-{arm}';path=args.campaign/(key+'.json')
                pair[arm]=reduce_capture(path) if path.exists() else {'status':'missing','metrics':None}
                captures[key]=pair[arm]
            gates={}
            if all(v.get('status')=='captured' for v in pair.values()):
                b=pair['A1'];c=pair['LA']
                for metric,absolute,relative in [('entry_peak',.5,.1),('overlap_peak_observed',1,.1),('rebound_upward',2,0),('tail_y_span',.5,0)]:
                    gates[metric]=None if b.get(metric) is None or c.get(metric) is None else c[metric]<=b[metric]+max(absolute,relative*b[metric])
                if b['overlap_coverage']<1 or c['overlap_coverage']<1:
                    gates['overlap_peak_observed']=None
                gates['conservation']=b['material_conserved'] and c['material_conserved']
            pairs.append({'platform':platform,'case':case['id'],'gates':gates,'interpretation':'registered numerical gates; owner feel and partial-support plausibility require separate review'})
    result={'registration':protocol['registration'],'captures':captures,'pairs':pairs,'complete':all(v['status']=='captured' for v in captures.values()),
            'owner_acceptance':None,'production_accepted':False,'unsupported':['whole-system energy','uncontended performance','human feel judgement','hard-contact wrench isolation']}
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':main()
