"""Independent arithmetic/custody review and bounded tower counter analysis."""
from pathlib import Path
import datetime
import hashlib
import io
import json
import math
import statistics
import subprocess

ROOT=Path('/workspace/scratch/f0d1839ea2a3/cybersand')
BASE=Path('/tmp/cybersand-live-edit')
OUT=Path(__file__).resolve().parent
RAW=BASE/'final-pinned-throughput'
REPORT=BASE/'evidence/final-matched-throughput-review.json'
CUSTODY=BASE/'final-throughput-custody.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
summary=json.loads((RAW/'summary.json').read_text())
review=json.loads(REPORT.read_text())
custody=json.loads(CUSTODY.read_text())
assert custody['before']==custody['after']
assert review['summary_sha256']==sha(RAW/'summary.json') and review['custody_sha256']==sha(CUSTODY)
assert review['measured_source']=='ba6d8de45bd4d38717d92bdece7153bff115c0f0'
assert review['baseline_source']=='b7d889b925ab3244d10e6fe48f487fbe0dc1ce73'
assert review['status']=='passed_all_workload_invariants'
assert review['expected_unique_windows']==40 and review['seconds_per_window']==6 and review['replicates']==2
for label,project in custody['before']['projects'].items():
    source=project['head']
    assert subprocess.check_output(['git','rev-parse',source+'^{tree}'],cwd=ROOT,text=True).strip()==project['tree']
    paths=sorted(p for p in project['files'] if not p.endswith('.so'))
    blobs=subprocess.check_output(['git','cat-file','--batch'],cwd=ROOT,input=''.join(source+':'+p+'\n' for p in paths).encode())
    stream=io.BytesIO(blobs)
    for path in paths:
        h=stream.readline().decode().split();assert len(h)==3 and h[1]=='blob'
        data=stream.read(int(h[2]));assert stream.read(1)==b'\n'
        assert hashlib.sha256(data).hexdigest()==project['files'][path],(label,path)
    assert stream.read()==b''
proof=json.loads((OUT/'linux-validated-production-verification.json').read_text())
candidate=custody['before']['projects']['candidate']
native_path='godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so'
assert candidate['files'][native_path]==proof['native_sha256'] and candidate['native_bytes']==proof['native_bytes']
prior=json.loads(subprocess.check_output(['git','show','327afc58227b246390b19c275f58df77ae2dd734:godot/addons/cybersand_native/runtime-provenance.linux.json'],cwd=ROOT))
baseline=custody['before']['projects']['baseline']
assert prior['source_commit']==baseline['head'] and prior['status']=='validated-development-runtime'
assert prior['sha256']==baseline['files'][native_path] and prior['size']==baseline['native_bytes']
expected={(w,r,n,a) for w in ['disabled','empty','tower','stress','sleeping'] for r in ['off','on'] for n in [1,2] for a in ['baseline','candidate']}
observed={};hashes={};groups={};tower=[]
for row in summary['runs']:
    key=(row['workload'],row['recording'],row['replicate'],row['label'])
    assert key in expected and key not in observed
    path=RAW/(row['name']+'.json');r=json.loads(path.read_text())
    assert sha(path)==row['result_sha256'];hashes[path.name]=row['result_sha256']
    assert row['passed'] and row['returncode']==0 and r['checks']>0 and r['failures']==[]
    assert r['source_commit']==custody['before']['projects'][row['label']]['head']
    assert r['requested_seconds']==6 and r['elapsed_usec']>=6000000 and r['process_fps_cap']==60
    assert r['display_driver']=='headless' and r['renderer_callbacks']==0
    for count,rate in [('semantic_ticks','semantic_ticks_per_second'),('process_callbacks','process_callbacks_per_second')]:
        assert type(r[count]) is int and r[count]>=0
        assert math.isfinite(r[rate]) and math.isclose(r[rate],r[count]*1e6/r['elapsed_usec'],rel_tol=1e-12)
    assert sum(c['semantic_ticks'] for c in r['cohorts'].values())==r['semantic_ticks']
    assert sum(c['callbacks'] for c in r['cohorts'].values())==r['process_callbacks']
    assert sum(c['wall_usec'] for c in r['cohorts'].values())<=r['elapsed_usec']
    observed[key]=r;groups.setdefault((row['workload'],row['recording'],row['label']),[]).append(r['semantic_ticks_per_second'])
    if row['workload']!='tower':continue
    n=r['semantic_ticks'];a,b=r['after'],r['before'];d=r['runtime_counter_deltas'];w=r['worker_counter_deltas'];ct=r['control_timing_deltas']
    assert set(r['cohorts'])=={'1/1'}
    assert a['held_reason']==b['held_reason']==''
    assert set(a['motion_permit_refusal_kinds']) <= {'OwnerBusy'}
    assert d['motion_permits_refused'] in [0,1] and a['last_motion_permit']['ok'] is True
    assert 0<=w['snapshot_calls']-3*n<=3 and 0<=w['full_motion_publications']-n<=1 and 0<=w['compact_motion_receipts']-3*n<=3
    assert a['physics']['bodies'][0]['geometry_revision']==b['physics']['bodies'][0]['geometry_revision']==1
    assert a['physics']['bodies'][0]['shape_count']==b['physics']['bodies'][0]['shape_count']==23
    assert a['physics']['bodies'][0]['mass']==b['physics']['bodies'][0]['mass']==4438.0
    item={'name':row['name'],'recording':row['recording'],'replicate':row['replicate'],'label':row['label'],
        'semantic_ticks':n,'ticks_per_second':r['semantic_ticks_per_second'],'callbacks_per_second':r['process_callbacks_per_second'],
        'segments_per_tick':r['rapier_segments']/n,'snapshot_calls_per_tick':w['snapshot_calls']/n,
        'snapshot_boundary_excess':w['snapshot_calls']-3*n,'full_publication_boundary_excess':w['full_motion_publications']-n,'compact_receipt_boundary_excess':w['compact_motion_receipts']-3*n,
        'final_phase':a['phase'],'snapshot_usec_per_tick':w['snapshot_usec']/n,'frame_copy_usec_per_tick':w['frame_copy_usec']/n,
        'pump_usec_per_tick':d['pump_usec_total']/n,'pump_waits_per_tick':d['pump_waits']/n,
        'pump_budget_exhaustions_per_tick':d['pump_budget_exhaustions']/n,
        'motion_permit_refusals':d['motion_permits_refused'],'recovered_owner_busy_waits':d['motion_permit_waits_recovered'],
        'final_rotation':a['physics']['bodies'][0]['rotation'],'final_contacts':a['physics']['bodies'][0]['reported_contacts']}
    for kind in ['motion','complete']:
        for stage in ['owner_service','publication_copy','queue','delivery']:
            item[kind+'_'+stage+'_usec_per_tick']=ct[kind][stage]['usec']/n
    for stage in ['rapier_segment','pose_packet_capture','owner_control_admission']:
        item[stage+'_usec_per_tick']=(a['main_costs'][stage]['usec']-b['main_costs'][stage]['usec'])/n
    tower.append(item)
assert set(observed)==expected and len(hashes)==40
for comparison in review['comparisons']:
    w,r=comparison['workload'],comparison['recording']
    a=statistics.median(groups[w,r,'baseline']);b=statistics.median(groups[w,r,'candidate'])
    assert a==comparison['baseline_median'] and b==comparison['candidate_median']
    assert math.isclose((b/a-1)*100,comparison['candidate_change_percent'],abs_tol=1e-12)
paired=[]
for r in ['off','on']:
    for n in [1,2]:
        a=observed['tower',r,n,'baseline']['semantic_ticks_per_second'];b=observed['tower',r,n,'candidate']['semantic_ticks_per_second']
        paired.append({'recording':r,'replicate':n,'baseline_ticks_per_second':a,'candidate_ticks_per_second':b,'candidate_change_percent':(b/a-1)*100})
result={'schema_version':1,'reviewer':'native-transactions-specialist-A','verified_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'source_commit':review['measured_source'],'baseline_source':review['baseline_source'],
    'reviewed_report_name':REPORT.name,'report_sha256':sha(REPORT),'summary_name':'final-pinned-throughput/summary.json','summary_sha256':sha(RAW/'summary.json'),'custody_name':CUSTODY.name,'custody_sha256':sha(CUSTODY),'raw_result_directory':'final-pinned-throughput','raw_result_sha256':hashes,'reader_name':Path(__file__).name,'reader_sha256':sha(Path(__file__)),
    'verified_windows':40,'verified_comparisons':len(review['comparisons']),'source_and_runtime_custody_equal':True,
    'status':'PASS_DATA_INTEGRITY_WITH_UNRESOLVED_DESCRIPTIVE_TOWER_DECLINE',
    'tower_paired_comparisons':paired,'tower_counter_rows':tower,
    'observations':['All eight tower windows retain one owned and one awake body, unchanged revision1 collision geometry with23 shapes and4438 unit-cell mass. No persistent hold or non-OwnerBusy refusal is present. Four windows have one bounded OwnerBusy permit deferral, followed by later successful MotionReserved admission; these are reported explicitly.',
        'Snapshot, full publication and compact receipt counts remain approximately3,1,3 per semantic tick; at most one in-flight physical interval at the window boundary explains the excess in two baseline windows ending AwaitingCompletedNativeTick. Rapier steps remain approximately4 per tick. No per-cell or per-owner transaction amplification appears.',
        'Two paired tower samples improve and two decline; recording-off median is4.60% lower and recording-on median6.45% lower for the candidate. These observed differences are retained without claiming equivalence.',
        'Slower samples exhibit broader per-tick native motion service, Main Rapier/capture and waiting costs. Snapshot-copy cost does not consistently increase in the slower pairs; no single measured new stage explains the result.'],
    'source_review':['The ordinary native motion/contact/occupied-domain algorithms and Godot physics bridge are unchanged fromb7; batch selection/mutation/reconstruction code is not invoked during these no-edit windows.',
        'Native metrics marshalling adds seven batch fields and receipt records are larger. Main adds a seven-scalar diagnostic identity construction/comparison and an inactive edit-opportunity guard. These are real small additional work items; this read-only review does not measure their isolated cost.',
        'The inactive pointer guard returns before footprint or witness acquisition. Worker payload/receipt additions execute only for editing actions.'],
    'interpretation':'The data establish a small lower tower median in this campaign and material run-to-run variability; they do not identify its cause. Scheduling/wait variation and changing fall/contact state over a fixed wall-time window are plausible contributors, not proven explanations. A persistent code-related cost cannot be excluded. No source change or extra simulation run was performed.',
    'limits':['Only two six-second samples per source/recording arm.','Different total semantic ticks mean final physics poses are observed at different simulated times. One owned/awake cohort does not imply identical per-tick kinematics/contact cost.','Timing spans overlap and must not be added. Generic differences of cumulative max fields were deliberately not interpreted as window maxima.','Headless process callbacks do not measure display FPS or physical owner hardware.']}
path=OUT/'final-throughput-independent-verification.json';path.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'receipt':str(path),'windows':40,'comparisons':len(review['comparisons']),'paired_tower':paired,'status':result['status']},indent=2))
