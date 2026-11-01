"""Descriptive R2/A1 heavy-entry capacity allocation; no counterfactual solve."""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]



def row_metrics(row,mass):
    g=row['gcr'];bins=g['contact_bins'];total=sum(b['count']for b in bins)
    bottom=sum(bins[i]['count']for i in [4,5]);upward=sum(b['count']for b in bins if b['normal'][1]<0)
    v=[row['in'][3+i]+g['event_accepted'][i]/mass for i in [0,1]];omega=row['in'][5]+g['event_torque']/g['inertia'];com=g['sample_com']
    closing=0.;details=[]
    for index,b in enumerate(bins):
        if not b['count']:continue
        points=[b['quadrature_low']] if b['quadrature_nodes']==1 else [b['quadrature_low'],b['quadrature_high']]
        speeds=[]
        for point in points:
            r=[point[i]-com[i]for i in [0,1]];u=[v[0]-omega*r[1],v[1]+omega*r[0]];speed=sum(u[i]*b['normal'][i]for i in [0,1]);speeds.append(speed)
            if speed<0:closing+=b['count']/len(points)
        details.append({'bin':index,'local_face':['top','right','bottom','left'][index//2],'source_count':b['count'],'normal':b['normal'],
                        'allocated_normal_capacity':g['normal_capacity']*b['count']/total if total else 0,'initial_quadrature_normal_speeds':speeds})
    applied=row.get('application',{});actual=applied.get('bodies',[{}])[0]if applied.get('accepted')and applied.get('bodies')else{}
    return {'tick':row['tick'],'in':row['in'],'out':row['out'],'vertical_depth':row['vertical_depth'],'pre_overlap':row.get('pre_overlap'),
            'post_overlap':row.get('post_overlap'),'total_source_count':total,'nominal_local_bottom_source_count':bottom,
            'nominal_local_bottom_share':bottom/total if total else None,'world_upward_normal_source_share':upward/total if total else None,
            'initial_closing_quadrature_source_share':closing/total if total else None,'normal_capacity':g['normal_capacity'],
            'event_budget_cost':g['event_budget_cost'],'event_y':g['event_accepted'][1],'normal_accepted':g['normal_accepted'],
            'normal_impulse':g['normal_impulse'],'tangent_impulse':g['tangent_impulse'],'computed_total_impulse':g['impulse'],
            'actual_applied_impulse':actual.get('impulse'),'actual_applied_angular_impulse':actual.get('angular_impulse'),
            'nominal_bottom_capacity':g['normal_capacity']*bottom/total if total else 0,'bins':details}


def characterize(path):
    report=json.loads(path.read_text(encoding='utf-8'));rows=report['rows'];metrics=[row_metrics(r,report['case']['mass'])for r in rows]
    floor=next((r['tick']for r in rows if r.get('hard_floor_contact')),None);pre=[r for r in metrics if floor is None or r['tick']<floor]
    indexes=set(range(min(12,len(pre))));selection={}
    for depth in [5,10,20,40,80]:
        index=next((i for i,r in enumerate(pre)if r['vertical_depth']>=depth),None);selection[f'first_depth_{depth}']=None if index is None else pre[index]['tick']
        if index is not None:indexes.add(index)
    if pre:
        indexes.add(len(pre)-1);indexes.add(max(range(len(pre)),key=lambda i:pre[i]['vertical_depth']))
    positive=[i for i,r in enumerate(pre)if r['total_source_count']>0]
    if positive:
        indexes.add(min(positive,key=lambda i:pre[i]['nominal_local_bottom_share']))
        indexes.add(min(positive,key=lambda i:pre[i]['initial_closing_quadrature_source_share']))
    return {'source':report['source'],'runtime':report['runtime'],'protocol_sha256':report['protocol_sha256'],'input_identity':report['input_identity'],
            'candidate':report['candidate'],'raw_path':str(path),'raw_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'first_hard_floor_tick':floor,
            'selection':selection,'selected_rows':[pre[i]for i in sorted(indexes)],
            'maximum_pre_floor_depth':max((r['vertical_depth']for r in pre),default=None)}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--r2',type=Path,required=True);parser.add_argument('--a1',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    output={'schema':1,'source_mechanism':'The unchanged solve allocates capacity proportional to every bin source count before knowing which quadrature contacts are closing. Per-node capacities are not transferred from nonclosing contacts to closing contacts.',
            'limits':['No alternate law/counterfactual is solved. This locates an available-capacity mechanism, not its dominant causal contribution.',
                      'Nominal local bottom can stop pointing upward as the body rotates; world-upward normal shares and full pose/normal vectors are retained.',
                      'Initial closing shares include the registered event wrench before passive solve; closing status can change over the four phases.',
                      'R2 ledger is retained original-source evidence. Same-build R2 telemetry-off timing provides physical trajectories but lacks this full bin ledger.',
                      'Geometry/stability, event budget/downward event feedback, evolving contacts, delivery, ejection and hard collisions remain separate explanations.'],
            'R2_retained':characterize(args.r2),'A1':characterize(args.a1)}
    path=args.output;path.write_text(json.dumps(output,indent=2),encoding='utf-8')
    for label in ['R2_retained','A1']:
        value=output[label];print(label,'firstfloor',value['first_hard_floor_tick'],'maxdepth',value['maximum_pre_floor_depth'])
        for row in value['selected_rows']:
            print(row['tick'],'depth',round(row['vertical_depth'],3),'sources',row['total_source_count'],'bottomshare',row['nominal_local_bottom_share'],'closing',row['initial_closing_quadrature_source_share'],'cap',round(row['normal_capacity'],3),'bottomcap',round(row['nominal_bottom_capacity'],3),'N',round(row['normal_accepted'],3),'normalY',round(row['normal_impulse'][1],3),'event',round(row['event_budget_cost'],3),'angle',round(row['in'][2],3),'vy',round(row['in'][4],3))


if __name__=='__main__':main()
