#!/usr/bin/env python3
"""Read-only independent receipt/custody reduction of already-completed local runs."""
from pathlib import Path
import collections, datetime, hashlib, json, re, subprocess
BASE=Path('/workspace/scratch/c14abf8ba238/qualification-383')
ROOT=Path('/workspace/scratch/c14abf8ba238/cybersand-383')
OUT=BASE/'host-attempt-4'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],text=True).strip()
p=read(OUT/'processes.json'); b=read(OUT/'identity-before.json'); a=read(OUT/'identity-after.json')
fail=[]
def check(ok, detail):
 if not ok:fail.append(detail)
check(p['status']=='passed','process report not passed')
check(len(p['results'])==16,'expected import plus 15 suites')
check(b['initial_git_status']=='','initial checkout dirty')
check(git('rev-parse','HEAD')==b['source_commit']==p['source_commit']==a['source_commit'],'source commit mismatch')
check(git('rev-parse','HEAD^{tree}')==b['source_tree']==p['source_tree']==a['source_tree'],'tree mismatch')
source_drift=[k for k,v in b['source_inputs'].items() if sha(ROOT/k)!=v]
check(not source_drift,'source hash drift')
check(not a['source_drift'] and not a['runtime_drift'],'runner postflight drift')
check(sha(Path(b['godot_path']))==b['godot_sha256']==a['godot_sha256'],'engine hash drift')
check(sha(BASE/'run_host_qualification.py')==b['harness_sha256'],'harness hash mismatch')
check(sha(ROOT/'tools/ci/run_godot_regressions.py')==b['runner_sha256'],'runner hash mismatch')
for k,v in b['runtime_provenance'].items():
 check(sha(ROOT/v['artifact'])==v['actual_file_sha256'],f'runtime mismatch {k}')
counts={}; natural=[]; log_hashes={}
for r in p['results']:
 check(r['status']=='passed' and r['returncode']==0 and r['natural_completion'],f'incomplete/failing {r["name"]}')
 check(not r['skip_messages'] and not r['diagnostic_error'] and r['timeout_kind'] is None,f'skip/error {r["name"]}')
 log=OUT/r['log']; runlog=OUT/(r['name']+'-runner.log')
 check(sha(log)==r['log_sha256'],f'log sha mismatch {log.name}')
 check(sha(runlog)==r['runner_log_sha256'],f'runner log sha mismatch {runlog.name}')
 log_hashes[log.name]=sha(log)
 matches=[]
 for s in r.get('footer_lines',[]):
  m=re.search(r'(?:assertions|checks)=(\d+)',s) or re.search(r'(\d+) assertions[;,]',s)
  if m:matches.append(int(m.group(1)))
 check(len(matches)<=1,f'ambiguous assertion totals {r["name"]}')
 if matches:counts[r['name']]=matches[0]
 else:natural.append(r['name'])
check(sum(counts.values())==12026,'assertion count is not 12026')
packdir=OUT/'xdg-data/godot/app_userdata/Cyber Sand Reference Sandbox'
np=packdir/'metered-drain-native-host.json'; dp=packdir/'metered-drain-desktop-host.json'
n=read(np);d=read(dp)
for packet,fixture in [(n,'in-tools-metered-drain.v1.json'),(d,'in-tools-metered-desktop.v1.json')]:
 check(sha(ROOT/'godot/tests/fixtures'/fixture)==packet['fixture_sha256'],f'fixture mismatch {fixture}')
 check(packet['failures']==0,f'packet has failures {fixture}')
check(n['checks']+1==counts['test_physical_metered_drain'],'native final packet-write assertion mismatch')
check(d['assertions']+1==counts['test_physical_metered_desktop'],'Main final packet-write assertion mismatch')
status=collections.Counter(); prov=collections.Counter()
for c in n['commands']:
 r=c['receipt'];md=r.get('metered_drain')
 if md:status[md.get('status')]+=1;prov[md.get('provenance')]+=1
 else:status['v1-control']+=1
quantity=[]
for r in n['rows']:
 if r['case']!='quantity-and-shutoff':continue
 md=r['command']['metered_drain'];unit='water' if r['material']==3 else 'brine';init=r['initial'][unit];final=r['final'][unit];sink=md['sink_debit']
 check(init-final==sink,f'quantity closure {r["family"]} {r["bits"]} {r["configured_workers"]}')
 check(md['budget_before']-md['remaining_budget']==sink,'permission closure')
 check(md['water_units_removed']+md['brine_cells_removed']==sink,'unit removal closure')
 check(md['provenance']=='host-local-native-observation-v1','host provenance mislabeled')
 check(r['initial']['walls']==r['final']['walls'],'wall count mismatch')
 check(len(r['transport_observations'])==8,'transport window incomplete')
 check(all(o['quantity'][unit]==final for o in r['transport_observations']),'transport quantity drift')
 quantity.append({'family':r['family'],'bits':r['bits'],'material':r['material'],'fractional':r['fractional'],'configured_workers':r['configured_workers'],'actual_claimants_max':r['actual_claimants_max'],'source_initial':init,'removed':sink,'source_final':final,'requested_quantity':md['requested_quantity_budget'],'permission_remaining':md['remaining_budget'],'native_completed_tick_before':md['completed_tick_before'],'native_completed_tick_after':md['completed_tick_after'],'post_shutoff_ticks':[o['completed_tick'] for o in r['transport_observations']],'command_owner_usec':r['command_owner_usec'],'command_overhead_usec':md['command_overhead_usec'],'native_tick_ms':r['native_tick_ms']})
for i in range(0,len(quantity),2):
 check(n['rows'][i]['physical_hash']==n['rows'][i+1]['physical_hash'],'one/four physical parity')
main=[]
for r in d['reports']:
 if 'water_units_final' not in r:continue
 isbrine=r['case']=='brine-in-main';unit='brine_cells_final' if isbrine else 'water_units_final';sink=r['sink_debit'];ordinary=r.get('ordinary_control_sink_from_joined_censuses',0);residual=r['initial']-r[unit]-sink-ordinary
 check(residual==0,f'Main source residual {r["case"]}')
 ledger=r['ledger']
 check(ledger['water_units_initial']==ledger['water_units_remaining']+ledger['water_units_removed'],'Main Water allowance mismatch')
 check(ledger['brine_cells_initial']==ledger['brine_cells_remaining']+ledger['brine_cells_removed'],'Main Brine allowance mismatch')
 main.append({'case':r['case'],'source_initial':r['initial'],'source_final':r[unit],'unit':'brine cells' if isbrine else 'water units','metered_sink':sink,'ordinary_census_difference':ordinary,'residual':residual,'native_completed_tick':r['native_tick'],'native_generation':ledger['native_generation'],'world_instance_id':ledger['world_instance_id'],'phase_claimants':r['worker_readback']['phase_jobs_last_tick']})
review={'schema':'independent-completed-host-custody-review-v1','reviewed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'read-only independent reduction of completed Linux run; no test replay; Windows and physical input not executed','source_sha':b['source_commit'],'source_tree':b['source_tree'],'status':'PASS' if not fail else 'FAIL','failures':fail,'reviewed_source_input_count':len(b['source_inputs']),'source_drift':source_drift,'current_git_status':git('status','--porcelain=v1','--untracked-files=all'),'final_generated_metadata_record_retained':bool(a['git_status']),'assertion_counts':counts,'counted_total':sum(counts.values()),'natural_completion_without_count':natural,'runtime_hashes':{k:{'artifact':v['artifact'],'actual_file_sha256':v['actual_file_sha256']} for k,v in b['runtime_provenance'].items()},'file_hashes':{str(f.relative_to(BASE)):sha(f) for f in [OUT/'identity-before.json',OUT/'identity-after.json',OUT/'processes.json',np,dp]},'command_statuses':dict(status),'command_provenance':dict(prov),'native_host_quantities':quantity,'main_quantities':main,'log_hashes':log_hashes,'limits':['Packet counters omit final packet-write assertion; footer includes it.','Exact positional/source-body assertions remain checked by the unmodified test; this reducer independently validates arithmetic and custody.','Actual Main uses synthetic key events and fixed aim/focus seam; unmodified PLAY entry is admission smoke only.','Source-qualified Linux does not qualify Windows DLL execution.','Ordinary Main sink is joined endpoint difference, not native-issued per-command quantity receipt.']}
(BASE/'review/completed-host-review.json').write_text(json.dumps(review,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:review[k] for k in ['status','failures','reviewed_source_input_count','counted_total','natural_completion_without_count','current_git_status','command_statuses','command_provenance']},indent=2))
print('Main quantities',json.dumps(main))
