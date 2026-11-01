"""Compact read-only admission campaign export; raw receipts are retained separately."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/experiments'))
from analyze_gcr_admission import reduce_reports
from export_gcr_evidence import selected_trace


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--campaign',action='append',required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True);manifest={'schema':1,'campaigns':[],'raw_receipts':[]}
    for item in args.campaign:
        label,rawpath=item.split('=',1);path=Path(rawpath);campaign=json.loads(path.read_text(encoding='utf-8'))
        if not campaign['complete']:raise RuntimeError('Cannot export incomplete campaign: '+label)
        reports=[];traces=[];failures=[]
        identity={k:v for k,v in campaign['identity'].items() if k!='project_inputs'}
        manifest['campaigns'].append({'label':label,'identity':identity,'campaign_sha256':digest(path),'mechanical_receipt_sha256':campaign.get('mechanical_receipt_sha256')})
        for cap in campaign['captures']:
            manifest['raw_receipts'].append(dict(campaign=label,**{k:cap.get(k) for k in ['case','arm','repeat','mode','status','raw','raw_sha256','log','log_sha256']}))
            if cap['status']!='captured':failures.append(cap);continue
            raw=path.parent/cap['raw']
            if digest(raw)!=cap['raw_sha256']:raise RuntimeError('Raw changed: '+str(raw))
            report=json.loads(raw.read_text(encoding='utf-8'))
            for key in ['source','protocol_sha256','input_identity']:
                if report[key]!=campaign['identity'][key]:raise RuntimeError('Mixed capture identity')
            reports.append((report,cap['repeat'],cap['raw_sha256']))
            trace=selected_trace(report)
            if trace is not None:
                lookup={(r['tick'],r.get('body',1)):r for r in report['rows']}
                native={r['tick']:r for r in report.get('worker_trace',[]) if isinstance(r,dict)}
                for row in trace:
                    original=lookup[row['tick'],row.get('body',1)]
                    if 'admission'in original:row['admission']=original['admission']
                    elif row['tick']in native and 'admission_counters'in native[row['tick']]:row['admission_counters_at_published_tick']=native[row['tick']]['admission_counters']
                traces.append({'case':cap['case'],'arm':cap['arm'],'repeat':cap['repeat'],'raw_sha256':cap['raw_sha256'],'rows':trace})
        receipts,physical,attribution=reduce_reports(reports)
        fields=['case','candidate','mode','repeat','raw_sha256','complete','conserved','granular_identity','admission','peak_horizontal_entry','peak_vertical_entry',
                'peak_pre_overlap','peak_post_overlap','peak_tick_overlap','first_hard_floor_tick','first_unresolved_tick','late_peak_speed','late_peak_abs_omega',
                'total_applied_Jx_Jy_L','peak_abs_local_slip','timing_us','work']
        keys=sorted({k for row in physical for k,v in row.items() if isinstance(v,bool) or (v is None and (k.endswith('nonworsening') or k.endswith('gate') or k.endswith('required')))})
        gates={key:{'true':sum(r.get(key)is True for r in physical),'false':sum(r.get(key)is False for r in physical),'unsupported':sum(key in r and r[key]is None for r in physical),
                    'true_cases':[r['case'] for r in physical if r.get(key)is True],'false_cases':[r['case'] for r in physical if r.get(key)is False]} for key in keys}
        summary={'schema':1,'label':label,'registration':campaign['registration'],'phase':campaign['phase'],'identity':identity,
                 'mechanical_receipt_sha256':campaign.get('mechanical_receipt_sha256'),'timing_scope':campaign.get('timing_scope'),
                 'counts':{'captures':len(receipts),'complete':sum(r['complete']for r in receipts),'quantity_conserved':sum(r['conserved']for r in receipts),'execution_failures':len(failures)},
                 'gate_boolean_counts':gates,'Y1_physical_comparisons':physical,'R2_A1_attribution':attribution,
                 'receipts':[{k:r[k]for k in fields if k in r}for r in receipts],'execution_failures':failures,
                 'limits':['Mechanical gate and law adequacy are separate. No owner verdict/default/merge inferred.',
                           'R2 admission counters count A1-helper work: zero R2 helper admissions is not zero ordinary R2 contacts.',
                           'Functional concurrent timing triggers are not performance qualification. Unknown measurements stay null.']}
        (args.output/f'{label}-summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
        (args.output/f'{label}-selected-traces.json').write_text(json.dumps({'schema':1,'identity':identity,'traces':traces},indent=2),encoding='utf-8')
    manifest['canonical_raw_manifest_sha256']=hashlib.sha256(json.dumps(manifest['raw_receipts'],sort_keys=True,separators=(',',':')).encode('utf-8')).hexdigest()
    manifest['exporter_sha256']=digest(__file__)
    (args.output/'raw-receipt-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('Exported',len(manifest['raw_receipts']),'original raw/log hash references to',args.output)


if __name__=='__main__':main()
