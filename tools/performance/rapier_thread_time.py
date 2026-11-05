#!/usr/bin/env python3
"""Bounded #449 calling-thread CPU experiment; no blocking/descheduling attribution."""
import argparse, hashlib, json, os, re, statistics, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FIXTURE='godot/tests/performance/test_main_rapier_thread_cpu_windows.gd'
SOURCE='2e937ee37532b06d46fa49205ff2e51c1a9baa2e'
PHASES=('baseline_a','timed_a','timed_b','baseline_b')
def digest(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,timeout=45).decode().strip()
def validate_sources():
    sample=(ROOT/FIXTURE).read_text(encoding='utf-8')
    main=(ROOT/'godot/scripts/main.gd').read_text(encoding='utf-8')
    expected=main.split('func _physics_process(_delta: float) -> void:\n',1)[1].split('\nfunc workbench_source(',1)[0].rstrip()
    copy=sample.split('\tfunc _instrumented_dispatch(_delta: float) -> void:\n',1)[1].split('\nfunc retain_physics(',1)[0]
    lines=[line[1:] for line in copy.splitlines() if line.startswith('\t')]
    if lines[0]!='\tvar stage_started_usec: int = 0': raise ValueError('undeclared stage prologue')
    lines=lines[1:]
    clocks=re.compile(r'^\s*(?:stage_started_usec = Time\.get_ticks_usec\(\)|observe_wrapper\("(?:session_suspend|take_snapshot|session_advance|rapier_step|session_complete)", stage_started_usec\))$')
    if '\n'.join(line for line in lines if not clocks.fullmatch(line)).rstrip()!=expected: raise ValueError('Main source guard failed')
    bridge=(ROOT/'godot/scripts/rapier_physics_bridge.gd').read_text(encoding='utf-8')
    expected=bridge.split('func step() -> void:\n',1)[1].split('\n\nfunc pack_body_states()',1)[0].rstrip()
    copy=sample.split('\tfunc step() -> void:\n',1)[1].split('\n\nclass ObservedMain:',1)[0]
    allowed_probes=[
        'if not probe_enabled: # CPU_PROBE', 'super() # CPU_PROBE', 'return # CPU_PROBE',
        'var cpu_before: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample") # CPU_PROBE',
        'var wall_before: int = Time.get_ticks_usec() # CPU_PROBE',
        'var wall_after: int = Time.get_ticks_usec() # CPU_PROBE',
        'var cpu_after: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample") # CPU_PROBE',
        'probe_record = {"cpu_before":cpu_before,"cpu_after":cpu_after,"wall_before_usec":wall_before,"wall_after_usec":wall_after} # CPU_PROBE']
    if [line.strip() for line in copy.splitlines() if '# CPU_PROBE' in line]!=allowed_probes: raise ValueError('undeclared CPU probe lines')
    if '\n'.join(line[1:] for line in copy.splitlines() if '# CPU_PROBE' not in line).rstrip()!=expected: raise ValueError('bridge step source guard failed')
    exact={}
    for path in ('godot/scripts/main.gd','godot/scripts/rapier_physics_bridge.gd','godot/scripts/physical_actor_session.gd','godot/project.godot','godot/tests/performance/test_main_rapier_bridge_split_windows.gd'):
        old=subprocess.check_output(['git','show',f'{SOURCE}:{path}'],cwd=ROOT,timeout=45)
        data=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
        if data!=old: raise ValueError('#449 source drift: '+path)
        exact[path]=hashlib.sha256(data).hexdigest()
    return {'main_source_restored':True,'bridge_step_restored':True,'original_source':SOURCE,'head':git('rev-parse','HEAD'),'tree':git('rev-parse','HEAD^{tree}'),'source_hashes':exact,'fixture_sha256':digest(ROOT/FIXTURE)}
def quantiles(values):
    if not values: return {'n':0}
    v=sorted(values)
    return {'n':len(v),**{k:v[round((len(v)-1)*q)] for k,q in (('p50',.5),('p95',.95),('p99',.99),('max',1.))}}
def validate_calibration(records):
    if len(records)!=20: raise ValueError('missing complete20entry busy/sleep calibration')
    modes={'busy':0,'sleep':0}; tids=set(); retained=[]
    for row in records:
        mode=row['mode']; a,b=row['cpu_before'],row['cpu_after']; wall=row['end_usec']-row['start_usec']
        if mode not in modes or len(a)!=10 or len(b)!=10 or a[0]!=1 or b[0]!=1 or a[1]!=b[1] or a[4]!=b[4] or a[4]<=0 or a[8] or a[9] or b[8] or b[9]: raise ValueError('calibration counter capability/schema failed')
        if not a[2]<=a[3]<=b[2]<=b[3] or wall<90000: raise ValueError('calibration timing failed')
        cpu=((b[5]+b[6])-(a[5]+a[6]))/10
        if cpu<0 or cpu>wall+31250: raise ValueError('calibration CPU accounting failed')
        if mode=='busy' and cpu+15625<wall*.8: raise ValueError('busy calibration insufficient charged CPU')
        if mode=='sleep' and cpu+15625>wall*.4: raise ValueError('sleep calibration insufficient offCPU contrast')
        modes[mode]+=1; tids.add(a[1]); retained.append({'mode':mode,'wall_usec':wall,'cpu_usec':cpu})
    if modes!={'busy':10,'sleep':10} or len(tids)!=1: raise ValueError('calibration modes/thread inconsistent')
    return {'passed':True,'thread_id':next(iter(tids)),'sensitivity_allowance_usec':15625,'allowance_is_api_guaranteed_bound':False,'rows':retained}

def inspect_trial(path):
    raw=json.loads(path.read_text(encoding='utf-8')); r=raw['result']
    if r.get('schema')!='inv154-thread-cpu-v1' or r.get('platform')!='Windows' or r.get('display_server')=='headless': raise ValueError('invalid schema/platform')
    if r.get('failures') or r.get('overflow') or not r.get('joined_worker') or not r.get('bridge_state_preserved'): raise ValueError('lifecycle/state guard failed')
    if r.get('requested_fps_readbacks')!=dict.fromkeys(PHASES,60): raise ValueError('ABBA caps changed')
    enabled=r['profiling_enabled']; events=[]; excluded=[]; overhead=[]; participants={}
    calibration=validate_calibration(r.get('counter_calibration',[])) if enabled else {}
    all_long=sum(row['bridge_step_usec']>40000 for row in raw['physics_rows'])
    phase_long={phase:sum(row['bridge_step_usec']>40000 and row['phase']==phase for row in raw['physics_rows']) for phase in PHASES}
    for row in raw['process_rows']:
        p=row.get('native_worker_participation',{})
        if p: participants[(p['world_generation'],p['sequence'])]=p
    if not participants: raise ValueError('actual worker participation missing')
    for p in PHASES:
        if sum(row['phase']==p for row in raw['physics_rows'])<150: raise ValueError('incomplete physics arm:'+p)
        if r[p]['native_ticks_per_second']<=0 or r[p]['rapier_steps_per_second']<=0: raise ValueError('native/Rapier progress missing')
    for row in raw['physics_rows']:
        if row['bridge_step_delta']!=1 or row['end_usec']-row['start_usec']!=row['duration_usec']: raise ValueError('step delta/monotonic closure failed')
        probe=row.get('cpu_probe',{})
        if not enabled:
            if probe: raise ValueError('disabled trial contains CPU probes')
            continue
        a,b=probe['cpu_before'],probe['cpu_after']
        if len(a)!=10 or len(b)!=10 or a[0]!=1 or b[0]!=1 or a[1]!=b[1] or a[1]!=calibration['thread_id']: raise ValueError('counter schema/thread mismatch')
        if a[8] or a[9] or b[8] or b[9] or a[4]<=0 or a[4]!=b[4]: raise ValueError('Win32 counter capability failure')
        if not a[2]<=a[3]<=b[2]<=b[3]: raise ValueError('QPC order failed')
        wall=probe['wall_after_usec']-probe['wall_before_usec']; inner_step=row['bridge_step_usec']
        if not row['start_usec']<=probe['wall_before_usec']<probe['wall_after_usec']<=row['end_usec']: raise ValueError('clock nesting failed')
        outer=(b[3]-a[2])*1e6/a[4]; inner=(b[2]-a[3])*1e6/a[4]
        span=((a[3]-a[2])+(b[3]-b[2]))*1e6/a[4]; overhead.append(span)
        if wall>outer+10 or wall<inner-1000: raise ValueError('Time/QPC alignment inconsistent')
        cpu=((b[5]+b[6])-(a[5]+a[6]))/10; cycles=b[7]-a[7]
        if cpu<0 or cycles<0 or cpu>outer+31250: raise ValueError('CPU accounting nonmonotonic/impossible')
        if inner_step>40000:
            excess=max(0,outer-inner_step)
            event={'phase':row['phase'],'physics_frame':row['physics_frames'],'thread_id':a[1],'space_step_usec':inner_step,'cpu_usec':cpu,'cpu_occupancy':cpu/inner_step,'cpu_occupancy_lower':max(0,cpu-15625-excess)/inner_step,'cpu_occupancy_upper':min(1,(cpu+15625)/inner_step),'cycles':cycles,'sample_span_usec':span,'qpc_outer_usec':outer,'qpc_inner_usec':inner,'bracket_excess_usec':excess,'godot_start_usec':probe['wall_before_usec'],'godot_end_usec':probe['wall_after_usec'],'qpc_before':a[2:4],'qpc_after':b[2:4]}
            if excess>1000 or excess>inner_step*.05: excluded.append(event)
            else: events.append(event)
    return {'path':str(path),'raw_sha256':digest(path),'profiling_enabled':enabled,'physics_callbacks':len(raw['physics_rows']),'all_long_step_count':all_long,'long_step_count_by_phase':phase_long,'long_events':events,'excluded_long_events':excluded,'sample_span_usec':quantiles(overhead),'frame_intervals_ms':quantiles([x['interval_usec']/1000 for x in raw['draw_rows']]),'physics_callback_ms':quantiles([x['duration_usec']/1000 for x in raw['physics_rows']]),'space_step_ms':quantiles([x['bridge_step_usec']/1000 for x in raw['physics_rows']]),'arms':{p:r[p] for p in PHASES},'worker_participation_samples':list(participants.values()),'worker_capacity_observed':sorted({p['worker_capacity'] for p in participants.values()}),'worker_participants_observed':sorted({p['workers_observed'] for p in participants.values()}),'calibration':calibration}
def analyze(directory):
    trials=[inspect_trial(p) for p in sorted(directory.glob('trial-*/physics-thread-cpu.json'))]
    enabled=[t for t in trials if t['profiling_enabled']]; disabled=[t for t in trials if not t['profiling_enabled']]
    events=[e for t in enabled for e in t['long_events']]; perturb={}; excessive=False
    if enabled and disabled:
        for metric in ('frame_intervals_ms','physics_callback_ms','space_step_ms'):
            perturb[metric]={}
            for q in ('p50','p95'):
                on=statistics.median(t[metric][q] for t in enabled); off=statistics.median(t[metric][q] for t in disabled)
                ratio=on/off if off else None
                perturb[metric][q]={'enabled_median':on,'disabled_median':off,'ratio':ratio}
                if metric=='frame_intervals_ms' and ratio is not None and abs(ratio-1)>.20: excessive=True
    cpu=sum(e['cpu_occupancy_lower']>=.8 for e in events); offcpu=sum(e['cpu_occupancy_upper']<=.4 for e in events)
    reasons=[]; verdict='Inconclusive'
    if len(enabled)<3 or len(disabled)<3: reasons.append('fewer than three trials in each profiling state')
    if len(events)<20: reasons.append('fewer than twenty qualified long space_step events')
    if excessive: reasons.append('frame p50/p95 profiling perturbation exceeds20percent')
    excluded=sum(len(t['excluded_long_events']) for t in enabled)
    if excluded: reasons.append('timing boundary exclusions prevent complete event attribution')
    if not reasons:
        if cpu/len(events)>=.8: verdict='CPU dominated'
        elif offcpu/len(events)>=.8: verdict='Off-CPU dominated'
        else: reasons.append('occupancy rules not met under15.625ms accounting allowance')
    summary={'schema':'inv154-thread-cpu-analysis-v1','classification':verdict,'classification_scope':'calling Windows thread during synchronous space_step; not aggregate Rapier/process CPU','thread_state_attribution':'unknown; blocking versus ready/descheduled requires ETW thread-state evidence','accounting_sensitivity_allowance_usec':15625,'sensitivity_allowance_is_api_guaranteed_bound':False,'long_event_threshold_usec':40000,'minimum_events':20,'long_event_count':len(events),'excluded_long_event_count':excluded,'cpu_dominated_events':cpu,'off_cpu_dominated_events':offcpu,'enabled_trials':len(enabled),'disabled_trials':len(disabled),'inconclusive_reasons':reasons,'perturbation_threshold':.20,'perturbation':perturb,'trials':trials}
    (directory/'classification.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    return summary

def wpr_call(args):
    try:
        p=subprocess.run(['wpr',*args],capture_output=True,text=True,timeout=45)
        return {'command':['wpr',*args],'exit_code':p.returncode,'stdout':p.stdout,'stderr':p.stderr}
    except (OSError,subprocess.TimeoutExpired) as exc:
        return {'command':['wpr',*args],'exit_code':None,'error':str(exc)}

def begin_wpr(output):
    # Do not cancel or stop any pre-existing session owned by somebody else.
    status=wpr_call(['-status']); (output/'wpr-status.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
    if status['exit_code']!=0 or 'not recording' not in status.get('stdout','').lower():
        (output/'wpr-start.json').write_text(json.dumps({'skipped':'status cannot prove absence of existing WPR recording'}),encoding='utf-8')
        return False
    start=wpr_call(['-start','GeneralProfile','-filemode'])
    (output/'wpr-start.json').write_text(json.dumps(start,indent=2),encoding='utf-8')
    return start['exit_code']==0
def run(engine,directory,trials=3,etw=False):
    directory.mkdir(parents=True,exist_ok=True); source=validate_sources()
    sys.path.insert(0,str(ROOT/'tools/ci')); import run_windows_godot_regressions as runtime
    with runtime.metadata_budget(): source['runtime']=runtime.verify_retained_runtime(ROOT)
    source['engine_sha256']=digest(engine); source['engine_version']=subprocess.check_output([str(engine),'--version'],timeout=45).decode().strip()
    if source['engine_version']!=runtime.GODOT_VERSION: raise ValueError('pinned Godot version mismatch')
    source['profile_order']=['disabled','enabled']*trials
    source['diagnostic_inputs']={str(path.relative_to(ROOT)).replace(chr(92),'/'):digest(path) for path in [ROOT/FIXTURE,Path(__file__).resolve(),*(ROOT/'tools/performance/rapier_thread_probe').glob('*.py'),*(ROOT/'tools/performance/rapier_thread_probe').glob('*.c')] if path.is_file()}
    for name,command in (
        ('os','Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber | ConvertTo-Json'),
        ('processor','Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | ConvertTo-Json'),
        ('video','Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,VideoProcessor,PNPDeviceID | ConvertTo-Json')):
        host=subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',command],capture_output=True,text=True,timeout=45)
        (directory/('host-'+name+'.json')).write_text(json.dumps({'command':command,'exit_code':host.returncode,'stdout':host.stdout,'stderr':host.stderr},indent=2),encoding='utf-8')
        if host.returncode: raise ValueError('host identity failure:'+name)
    source['engine_runtime_sha256']=digest(engine.parent/'Godot_v4.7-stable_win64.exe')
    (directory/'source-and-runtime.json').write_text(json.dumps(source,indent=2),encoding='utf-8')
    for index,enabled in enumerate([False,True]*trials,1):
        output=directory/f"trial-{index:02d}-{'enabled' if enabled else 'disabled'}"; output.mkdir(parents=True,exist_ok=True)
        argv=[str(engine),'--rendering-driver','opengl3_angle','--path',str(ROOT/'godot'),'--script','res://tests/performance/test_main_rapier_thread_cpu_windows.gd']
        env={**os.environ,'CYBERSAND_THREAD_CPU':'1' if enabled else '0','CYBERSAND_PHASE_OUTPUT':str(output.resolve()),'CYBERSAND_SOURCE_REVISION':source['head']}
        receipt={'command':argv,'profiling_enabled':enabled,'timeout_seconds':745,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
        (output/'command.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
        recording=begin_wpr(output) if enabled and etw else False
        try:
            completed=subprocess.run(argv,cwd=ROOT,env=env,capture_output=True,text=True,timeout=745)
            receipt['exit_code']=completed.returncode
            (output/'godot.log').write_text(completed.stdout+'\n'+completed.stderr,encoding='utf-8')
        except subprocess.TimeoutExpired as exc:
            receipt['exit_code']='timeout'; (output/'timeout.log').write_text(str(exc),encoding='utf-8')
            stdout=exc.stdout or b''; stderr=exc.stderr or b''
            (output/'godot.log').write_text((stdout.decode('utf-8',errors='replace') if isinstance(stdout,bytes) else stdout)+'\n'+(stderr.decode('utf-8',errors='replace') if isinstance(stderr,bytes) else stderr),encoding='utf-8')
            raise
        finally:
            if recording:
                stop=wpr_call(['-stop',str(output/'trace.etl')]); (output/'wpr-stop.json').write_text(json.dumps(stop,indent=2),encoding='utf-8')
            (output/'exit.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
        if completed.returncode: raise RuntimeError(f'trial{index} exit{completed.returncode}; preserved failure')
        inspected=inspect_trial(output/'physics-thread-cpu.json')
        print(json.dumps({'trial':index,'profiling_enabled':enabled,'callbacks':inspected['physics_callbacks'],'long_events':len(inspected['long_events'])}),flush=True)
    return analyze(directory)

def self_test(path):
    # Replay adversarial measurement mutations against a retained valid trace.
    import copy, tempfile
    inspect_trial(path)
    original=json.loads(path.read_text(encoding='utf-8'))
    mutations=[
        ('missing-calibration',lambda d:d['result'].__setitem__('counter_calibration',[])),
        ('wrong-thread',lambda d:d['physics_rows'][0]['cpu_probe']['cpu_after'].__setitem__(1,-1)),
        ('qpc-order',lambda d:d['physics_rows'][0]['cpu_probe']['cpu_after'].__setitem__(2,-1)),
        ('counter-error',lambda d:d['physics_rows'][0]['cpu_probe']['cpu_after'].__setitem__(8,5)),
        ('clock-nesting',lambda d:d['physics_rows'][0]['cpu_probe'].__setitem__('wall_after_usec',999999999999)),
        ('stale-step',lambda d:d['physics_rows'][0].__setitem__('bridge_step_delta',0))]
    with tempfile.TemporaryDirectory(prefix='rapier-thread-selftest-') as directory:
        target=Path(directory)/'mutated.json'
        for label,mutate in mutations:
            data=copy.deepcopy(original); mutate(data); target.write_text(json.dumps(data),encoding='utf-8')
            try: inspect_trial(target)
            except ValueError: print('PASS reject '+label)
            else: raise AssertionError('accepted invalid measurement:'+label)
    print('PASS six invalid-measurement regressions')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--validate',action='store_true'); parser.add_argument('--analyze',type=Path); parser.add_argument('--self-test',type=Path)
    parser.add_argument('--engine',type=Path); parser.add_argument('--output',type=Path,default=ROOT/'build/rapier-thread-time/repeated')
    parser.add_argument('--trials',type=int,default=3); parser.add_argument('--etw',action='store_true')
    args=parser.parse_args()
    if args.self_test: self_test(args.self_test.resolve())
    if args.validate: print(json.dumps(validate_sources(),indent=2))
    if args.analyze: summary=analyze(args.analyze.resolve())
    elif args.engine: summary=run(args.engine.resolve(),args.output.resolve(),args.trials,args.etw)
    else: return
    print(json.dumps({k:v for k,v in summary.items() if k!='trials'},indent=2))
if __name__=='__main__': main()
