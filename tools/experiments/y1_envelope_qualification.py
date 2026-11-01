"""Validate registered repeats, timing populations and real-owner delay receipts.

No terminal candidate promotion or owner verdict is inferred.
"""
from pathlib import Path
import hashlib,json,statistics,sys,argparse
root=Path.cwd();sys.path.insert(0,str(root/'tools/experiments'))
parser=argparse.ArgumentParser();parser.add_argument('--input',type=Path,default=Path('build/campaign-corrected'));parser.add_argument('--summary',type=Path,default=Path('build/y1-envelope-result.json'));parser.add_argument('--output',type=Path,default=Path('build/y1-envelope-qualification.json'));args=parser.parse_args()
from y1_envelope_analysis import physical_rows,quantiles
folder=args.input;p=json.loads((root/'docs/audits/y1-envelope-2026-11-01/protocol.json').read_text(encoding='utf-8-sig'));r=json.loads(args.summary.read_text());checks={};timings={};async_results=[]
for arm in ['B0','Y1']:
 a=json.loads((folder/f'anchor-30-{arm}.json').read_text());b=json.loads((folder/f'determinism-anchor-30-{arm}.json').read_text());
 for x in [a,b]:
  for row in x['rows']:row.pop('times_us')
 checks[f'determinism-{arm}']=a['rows']==b['rows']
 for case in ['anchor-30','water']:
  a=json.loads((folder/f'{case}-{arm}.json').read_text());b=json.loads((folder/f'telemetry-off-{case}-{arm}.json').read_text())
  keys=set(a['rows'][0]) & set(b['rows'][0]) - {'times_us','support','bearing_y'}
  checks[f'telemetry-off-{case}-{arm}']=[{k:x[k] for k in keys} for x in a['rows']]==[{k:x[k] for k in keys} for x in b['rows']]
for case in ['mass-1-30','mass-1-90']:
 timings[case]={}
 for arm in ['B0','Y1']:
  captures=[json.loads((folder/(f'{case}-{arm}.json' if rep<0 else f'timing-{rep}-{case}-{arm}.json')).read_text()) for rep in [-1,0,1,2]]
  timings[case][arm]={name:{'repeat_p95':[quantiles([row['times_us'][i] for row in c['rows']])['p95'] for c in captures],'pooled':quantiles([row['times_us'][i] for c in captures for row in c['rows']])} for i,name in enumerate(['rapier-control','coupling','cellular','application'])}
for spec in p['async_cases']:
 for arm in ['B0','Y1']:
  c=json.loads((folder/f'{spec["id"]}-{arm}.json').read_text());assert c['ok'] and len(c['rows'])==spec['frames'] and c['selector_failures']==0;rows=c['rows'];trace=c['owner_trace'];apps=[row for row in rows if row['consumed'] and row['apps'] and row['apps'][5]];ages={str(age):sum(int(row['apps'][0])==age for row in apps) for age in sorted(set(int(row['apps'][0]) for row in apps))}
  edit=c['edit_receipt'];initial=trace[0][10];expected_after=edit['after'][int(c['base']['material'])] if edit else initial
  conservation=sum(t[10] != (initial if not edit or t[0]<=edit['tick'] else expected_after) for t in trace)
  after=[t for t in trace if edit and t[0]>edit['tick']]
  release=None
  if after:
   first=after[0];before=[t for t in trace if 540<=t[0]<600];pre_main=next((row for row in reversed(rows) if row['cell_tick']<600),rows[0]);pre_pose=pre_main['pose'];near_floor=pre_pose[1]+abs(__import__('math').cos(pre_pose[2]))*7+abs(__import__('math').sin(pre_pose[2]))*4 >= 192+float(c['base']['depth'])-.5;seen=next((i for i,row in enumerate(rows) if row['cell_tick']>=600),None)
   release={'pre_edit_bearing_frames_last60':sum(t[3]!=0 for t in before),'pre_edit_near_hard_floor':near_floor,'release_precondition_observed':any(t[3]!=0 for t in before) and not near_floor,'first_post_edit_tick':first[0],'support':first[4],'bearing':first[3],'correction':first[9],'fall_60_main_frames':rows[min(seen+60,len(rows)-1)]['pose'][1]-rows[seen]['pose'][1] if seen is not None else None,'response_without_support':sum((t[3]!=0 or t[9]!=0) and t[4]==0 for t in after)}
  async_results.append({'case':spec['id'],'candidate':arm,'source':c['source'],'native_sha256':c['native_sha256'],'frames':len(rows),'owner_ticks':len(trace),'age_histogram':ages,'duplicates':sum(row['apps'][3] for row in rows if row['consumed']),'stales':sum(row['apps'][4] for row in rows if row['consumed']),'peak_upward_speed':max(0,-min(row['pose'][4] for row in rows)),'peak_entry':max(0,max(row['pose'][1]+abs(__import__('math').cos(row['pose'][2]))*7+abs(__import__('math').sin(row['pose'][2]))*4-192 for row in rows)),'final_y':rows[-1]['pose'][1],'owner_conservation_failures':conservation,'selector_failures':c['selector_failures'],'relocation_refusals':sum(t[8] for t in trace),'release':release,'edit_receipt':edit,'scanned_total':sum(t[12] for t in trace),'owner_step_ms':quantiles([t[1] for t in trace]),'raw_sha256':hashlib.sha256((folder/f'{spec["id"]}-{arm}.json').read_bytes()).hexdigest()})
primary=[v for v in r['comparisons'] if v['group'] in ['anchor','mass','scale','orientation'] and v['entry_reduction_fraction'] is not None and next(c for c in r['captures'] if c['case']==v['case'] and c['candidate']=='B0')['bodies'][0]['peak_entry']>1]
rest_fail=[{'case':c['case'],'body':b['body'],'rest':b['rest'],'clearance':b['clearance']} for c in r['captures'] if c['candidate']=='Y1' for b in c['bodies'] if b['rest']['applicable'] and not b['rest']['within_registered_bounds']]
out={'schema':1,'checks':checks,'timing_repeats':timings,'async':async_results,'primary':{'eligible_registered_rows':len(primary),'at_least20percent_reduction':sum(v['entry_reduction_fraction']>=.2 for v in primary),'fraction':sum(v['entry_reduction_fraction']>=.2 for v in primary)/len(primary)},'y1_rest_failures':rest_fail,'conservation_failures':sum(c['conservation_failures'] for c in r['captures']),'relocation_refusals':sum(c['relocation_refusals'] for c in r['captures']),'negative_controls':[v for v in r['comparisons'] if v['group']=='negative'],'performance_triggers':[v for v in r['comparisons'] if v['coupling_p95_ratio']>1.25 or v['scanned_ratio']>2],'owner_verdict':None,'status':'AWAITING OWNER GAMEPLAY ACCEPTANCE'}
args.output.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k not in ['timing_repeats','async','performance_triggers','y1_rest_failures']},indent=2));print('rest failures',[v['case'] for v in rest_fail]);print('performance triggers',len(out['performance_triggers']));print('async',[(a['case'],a['candidate'],a['age_histogram'],a['owner_conservation_failures'],a['release']) for a in async_results])
