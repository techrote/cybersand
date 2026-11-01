"""Separate A1 admission attribution from unchanged-law/Y1 physical gates."""
import argparse
import hashlib
import json
from pathlib import Path

from analyze_gcr_qualification import summarize, compare_pair

REGISTRATION='GCR-ADMISSION-001-2026-11-01'


def admission_summary(report):
    if report['mode']=='desktop-asynchronous':
        records=[]
        for row in report.get('worker_trace',[]):
            if not isinstance(row,dict):continue
            records.extend(row.get('admission_counters',[body['admission'] for body in row.get('gcr',{}).get('bodies',[]) if body.get('admission')]))
    else:
        records=[row.get('admission',row.get('gcr',{}).get('admission')) for row in report['rows']]
        records=[r for r in records if isinstance(r,dict) and r]
    if not records:return None
    keys=['source_candidates','geometry_mask_checks','mask_checks','path_checks','shared_witness_calls','admitted']
    totals={key:sum(r.get(key,0) for r in records) for key in keys}
    limits={'geometry_mask_checks':24,'mask_checks':31,'path_checks':7,'shared_witness_calls':1}
    violations={key:sum(r.get(key,0)>multiple*r.get('source_candidates',0) for r in records) for key,multiple in limits.items()}
    depths=[sum(r.get('selected_depth_counts',[0,0,0])[i] for r in records) for i in range(3)]
    refusals={key:sum(r.get('refusal_counts',{}).get(key,0) for r in records) for key in sorted({k for r in records for k in r.get('refusal_counts',{})})}
    return {'observed_native_boundaries':len(records),'totals':totals,'selected_depth_counts':depths,
            'refusal_counts':refusals,'bound_violation_boundaries':violations,
            'all_observed_probe_bounds_satisfied':not any(violations.values()),
            'limit':'Counters describe observed admission work; the independent mechanical oracle owns validity. Different evolving trajectories are not a same-state causal comparison.'}


def reduce_reports(reports):
    receipts=[]
    for report,repeat,raw_hash in reports:
        wanted='A1' if report['candidate']=='GCR-A1' else ('R2' if report['candidate']=='GCR' else 'disabled')
        if report.get('registration')!=REGISTRATION or report.get('granular_identity',{}).get('admission_variant')!=wanted:
            raise RuntimeError('Actual admission identity differs from arm')
        receipt=summarize(report)
        receipt.update(repeat=repeat,raw_sha256=raw_hash,granular_identity=report['granular_identity'],admission=admission_summary(report))
        receipts.append(receipt)
    grouped={(r['case'],r['candidate'],r['repeat']):r for r in receipts};physical=[];attribution=[]
    for (case,arm,repeat),a1 in grouped.items():
        if arm!='GCR-A1':continue
        y1=grouped.get((case,'Y1',repeat));r2=grouped.get((case,'GCR',repeat))
        if y1:
            comparison=compare_pair(y1,a1,repeat);comparison['reference']='Y1';comparison['candidate']='GCR-A1';physical.append(comparison)
        if r2:
            attribution.append({'case':case,'repeat':repeat,'R2_admission':r2['admission'],'A1_admission':a1['admission'],
                                'R2_peak_horizontal_entry':r2['peak_horizontal_entry'],'A1_peak_horizontal_entry':a1['peak_horizontal_entry'],
                                'R2_peak_vertical_entry':r2['peak_vertical_entry'],'A1_peak_vertical_entry':a1['peak_vertical_entry'],
                                'qualification':'Descriptive same-input admission-variant trajectories; not a mechanical-oracle verdict or a substitute Y1 physical gate.'})
    return receipts,physical,attribution


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('campaign',type=Path);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();campaign=json.loads(args.campaign.read_text())
    if campaign.get('registration')!=REGISTRATION:raise RuntimeError('Not an admission campaign')
    reports=[];failures=[]
    for capture in campaign['captures']:
        if capture['status']!='captured':failures.append(capture);continue
        path=args.campaign.parent/capture['raw'];raw=path.read_bytes()
        if hashlib.sha256(raw).hexdigest()!=capture['raw_sha256']:raise RuntimeError('Raw hash changed: '+str(path))
        report=json.loads(raw)
        for key in ['source','protocol_sha256','input_identity']:
            if report[key]!=campaign['identity'][key]:raise RuntimeError('Mixed capture identity: '+key)
        if report['runtime']['native']!=campaign['identity']['native_sha256']:raise RuntimeError('Mixed native runtime')
        reports.append((report,capture['repeat'],capture['raw_sha256']))
    receipts,physical,attribution=reduce_reports(reports)
    output={'schema':1,'registration':REGISTRATION,'phase':campaign['phase'],'identity':campaign['identity'],
            'mechanical_receipt_sha256':campaign.get('mechanical_receipt_sha256'),'capture_complete':campaign['complete'],
            'failures':failures,'receipts':receipts,'Y1_physical_comparisons':physical,'R2_A1_attribution':attribution,
            'disposition':'MEASURED ONLY: mechanical admission validity, unchanged-law adequacy, performance and owner feel are separate gates; no default or merge inferred.'}
    args.output.write_text(json.dumps(output,indent=2));print(len(receipts),'captures',len(physical),'Y1/A1 comparisons',len(attribution),'R2/A1 descriptive comparisons',len(failures),'execution failures')


if __name__=='__main__':main()
