"""Descriptive final300-native-tick motion; deliberately defines no pass gate."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/experiments'))
from analyze_gcr_qualification import timings


def describe(report):
    end=int(report['case']['ticks']);start=max(0,end-300)
    selected=[r for r in report['rows'] if start<=r['tick']<end]
    groups={}
    for row in selected:groups.setdefault(row.get('body',1),[]).append(row)
    result=[]
    for body,rows in groups.items():
        angles=[rows[0]['out'][2]]
        for prev,current in zip(rows,rows[1:]):
            delta=(current['out'][2]-prev['out'][2]+math.pi)%(2*math.pi)-math.pi
            angles.append(angles[-1]+delta)
        corrections=[]
        for row in rows:
            if row.get('held'):corrections.append(0.);continue
            if report['candidate'].startswith('GCR'):
                application=row.get('application')
                if not isinstance(application,dict) or 'accepted' not in application:corrections.append(None)
                elif not application['accepted']:corrections.append(0.)
                else:
                    values=[b for b in application.get('bodies',[]) if b.get('index')==body-1]
                    corrections.append(math.hypot(*values[0]['correction']) if len(values)==1 and 'correction'in values[0] else None)
            elif 'in'in row:corrections.append(math.hypot(row['out'][0]-row['in'][0],row['out'][1]-row['in'][1]))
            else:corrections.append(None)
        result.append({'body':body,'native_tick_interval':[start,end],'observed_rows':len(rows),
                       'x_span_cells':max(r['out'][0] for r in rows)-min(r['out'][0] for r in rows),
                       'y_span_cells':max(r['out'][1] for r in rows)-min(r['out'][1] for r in rows),
                       'net_displacement_cells':[rows[-1]['out'][i]-rows[0]['out'][i] for i in [0,1]],
                       'unwrapped_angle_span_radians':max(angles)-min(angles),
                       'abs_vy_cells_per_second':timings([abs(r['out'][4]) for r in rows]),
                       'abs_vx_cells_per_second':timings([abs(r['out'][3]) for r in rows]),
                       'abs_omega_radians_per_second':timings([abs(r['out'][5]) for r in rows]),
                       'actual_correction_active_rows':sum(c>1e-9 for c in corrections) if all(c is not None for c in corrections) else None,
                       'actual_correction_observed_rows':sum(c is not None for c in corrections),
                       'actual_correction_max_cells':max((c for c in corrections if c is not None),default=None),
                       'correction_basis':'Accepted bridge correction; synchronous Y1 uses same-boundary out−in position. Async Y1 without an application correction receipt remains unsupported.'})
    return result


def main():
    parser=argparse.ArgumentParser();parser.add_argument('campaign',type=Path);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();campaign=json.loads(args.campaign.read_text(encoding='utf-8'));records=[]
    for capture in campaign['captures']:
        if capture['status']!='captured':continue
        raw=(args.campaign.parent/capture['raw']).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=capture['raw_sha256']:raise RuntimeError('Raw receipt changed')
        report=json.loads(raw)
        records.append({'case':capture['case'],'arm':capture['arm'],'repeat':capture['repeat'],'raw_sha256':capture['raw_sha256'],'late_motion':describe(report)})
    result={'schema':1,'identity':{k:v for k,v in campaign['identity'].items() if k!='project_inputs'},'campaign_complete':campaign['complete'],
            'interpretation':'Descriptive final300-native-tick window; no new rest/sleep/late-motion acceptance threshold. Quantile names are p50/p95/p99/max, not time units.',
            'records':records}
    args.output.write_text(json.dumps(result,indent=2),encoding='utf-8');print(len(records),'late-motion descriptions')


if __name__=='__main__':main()
