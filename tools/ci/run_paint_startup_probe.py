#!/usr/bin/env python3
"""Fresh-ZIP Windows PAINT author/reopen probe; never publishes an owner build."""
from __future__ import annotations
import argparse,ast,datetime,hashlib,importlib.util,json,os,re,stat,subprocess,time,zipfile
from pathlib import Path

BASE='2f69a4a2f98ba67932909d824c86a9dcaf2551f9'
TEST='godot/tests/test_paint_editor_workbench.gd'
PACKAGER='tools/ci/package_engine_lab_windows.py'
PROTECTED=('godot/scripts','godot/shaders','godot/native_extension','godot/addons','native',
           'godot/project.godot','godot/main.tscn',PACKAGER)
NAMES=('import','paint-author','paint-reopen')
PNG=b'\x89PNG\r\n\x1a\n'

def need(value,message):
    if not value:raise RuntimeError(message)
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def write(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def git(repo,*args):return subprocess.check_output(['git',*args],cwd=repo,text=True).strip()
def load_packager(repo):
    spec=importlib.util.spec_from_file_location('paint_probe_packager',repo/PACKAGER)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

def case_specs(packager_path):
    """Read the unchanged production literals; do not patch/execute smoke AST."""
    module=ast.parse(packager_path.read_text(encoding='utf-8'))
    smoke=next(n for n in module.body if isinstance(n,ast.FunctionDef)and n.name=='smoke')
    assignment=next(n for n in smoke.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='cases'for t in n.targets))
    selected={}
    for row in assignment.value.elts:
        if isinstance(row,ast.Tuple)and isinstance(row.elts[0],ast.Constant)and row.elts[0].value in NAMES:
            value=ast.literal_eval(row);need(value[0]not in selected,'Duplicate selected production case');selected[value[0]]=value
    need(set(selected)==set(NAMES),'Missing production PAINT/import case')
    need([selected[n][2]for n in NAMES]==[180,600,240],'Production process watchdogs changed')
    need(selected['import'][1]==['--headless','--editor','--quit'],'Production import command changed')
    expected=['--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/test_paint_editor_workbench.gd']
    need(all(selected[n][1]==expected and selected[n][3]=='PAINT_EDITOR_WORKBENCH'for n in NAMES[1:]),'Production graphical PAINT command changed')
    return [selected[n]for n in NAMES]

def marker_json(text,marker):
    rows=[json.loads(line[len(marker)+1:])for line in text.splitlines()if line.startswith(marker+' ')]
    need(len(rows)==1,'Missing or duplicate '+marker+' marker')
    return rows[0]

def validate_startup(receipt,text,source,test_sha,reopen):
    need(receipt==marker_json(text,'PAINT_STARTUP_LIFECYCLE'),'Startup file/marker mismatch')
    need(receipt.get('schema')=='paint-startup-lifecycle-v1'and receipt.get('source')==source and receipt.get('test_sha256')==test_sha and receipt.get('reopen')==reopen,'Startup source/test/phase mismatch')
    need(receipt.get('limit_ms')==60000 and receipt.get('default_limit_ms')==30000,'Readiness limits changed')
    need(type(receipt.get('passed'))is bool and type(receipt.get('timed_out'))is bool and (receipt.get('terminal_ready')is None or type(receipt.get('terminal_ready'))is bool),'Invalid startup outcome types')
    need(not(receipt['passed']and receipt['timed_out']),'Timeout was converted into success')
    if receipt['passed']:
        observation=receipt.get('last_ready_observation',{})
        need(observation.get('ready')is True and observation.get('terminal_diagnostic')is False,'Passed startup lacks an ordinary ready observation')
    events=receipt.get('events',[]);total=receipt.get('event_count');retained=receipt.get('retained_event_count');discarded=receipt.get('discarded_event_count')
    need(isinstance(total,int)and 0<len(events)==retained<=256 and total==retained+discarded,'Unbounded or inconsistent startup ledger')
    sequences=[e['sequence']for e in events]
    expected=list(range(total))if total<=256 else list(range(64))+list(range(total-192,total))
    need(sequences==expected,'Startup first/tail sequence accounting differs')
    need(receipt['started_usec']<=receipt['wait_started_usec']<=receipt['finished_usec'],'Startup clock ordering differs')
    need(all(receipt['started_usec']<=e['time_usec']<=receipt['finished_usec']and e['process_frame']>=0 and e['physics_frame']>=0 for e in events),'Invalid startup event clock/frame')
    need([e['time_usec']for e in events]==sorted(e['time_usec']for e in events),'Startup event time reversed')
    for key in('largest_await','largest_main_callback','largest_draw_span'):
        if key in receipt:
            span=receipt[key];need(span['duration_usec']==span['end']['time_usec']-span['begin']['time_usec']>=0,'Invalid paired '+key)
    # A late true observation remains diagnostic. Do not infer when readiness
    # became true or add a new finished-before-deadline acceptance condition.
    return {'source_verified':True,'bounded_events':retained,'discarded_events':discarded,
            'passed':receipt['passed'],'timed_out':receipt['timed_out'],'terminal_ready':receipt['terminal_ready']}

def validate_completion(text,exit_code,reopen,startup):
    completion=marker_json(text,'PAINT_EDITOR_WORKBENCH')
    need(exit_code==0 and not completion['failures']and completion['checks']>0 and completion['reopen']==reopen,'Installed graphical PAINT phase failed')
    need(startup.get('passed')is True and not startup.get('timed_out'),'Failed initial readiness cannot qualify PAINT')
    need('SCRIPT ERROR:'not in text and 'SHADER ERROR:'not in text and 'ANGLE'in text,'Wrong or failed graphical backend')
    return completion

def extract_fresh(packager,archive,application,evidence,source,tree):
    need(archive.is_file()and not archive.is_symlink(),'Missing/nonregular probe ZIP')
    need(not application.exists()and not application.is_symlink(),'Refusing non-fresh application directory')
    receipt=read(archive.with_suffix('.zip.json'));archive_sha=digest(archive)
    need(receipt['source_commit']==source and receipt['sha256']==archive_sha and receipt['bytes']==archive.stat().st_size,'Built ZIP identity differs')
    need(archive.with_suffix('.zip.sha256').read_text().split()[0]==archive_sha,'Built ZIP checksum sidecar differs')
    with zipfile.ZipFile(archive)as bundle:
        need(bundle.testzip()is None,'Probe ZIP CRC failure');members=bundle.infolist()
        need(len(members)==receipt['members']and len({m.filename.casefold()for m in members})==len(members),'Probe ZIP member identity differs')
        for member in members:
            packager.safe_name(member.filename)
            need(not member.is_dir()and not stat.S_ISLNK(member.external_attr>>16),'Unexpected directory/symlink in file-only package')
            need((application/member.filename).resolve().is_relative_to(application.resolve()),'Probe ZIP escapes destination')
        application.mkdir(parents=True,exist_ok=False);bundle.extractall(application)
    manifest=packager.verify(application)
    need(manifest['source_tree']==tree,'Installed source tree differs')
    write(evidence/'fresh-package.json',{'source':source,'tree':tree,'archive':str(archive),'archive_sha256':archive_sha,'archive_bytes':archive.stat().st_size,'members':len(members),'all_crc_checked':True,'safe_paths_checked':True,'fresh_application':str(application),'manifest_sha256':digest(application/packager.MANIFEST),'manifest':manifest,'owner_delivery_published':False})
    return manifest

def verify_retained_payload(application,manifest):
    # Generated imports are permitted, as in production smoke. Every original
    # manifest byte, including all source/engine/native files, remains exact.
    for relative,expected in manifest['files_sha256'].items():
        path=application/relative
        need(path.is_file()and not path.is_symlink()and digest(path)==expected,'Original package payload changed: '+relative)
    return {'original_files_verified':len(manifest['files_sha256']),'all_original_hashes_unchanged':True}

def execute_case(spec,application,evidence,source,console,test_sha,index):
    name,suffix,timeout,marker=spec;folder=evidence/name;folder.mkdir(exist_ok=False)
    if '--headless'not in suffix and '--rendering-driver'not in suffix:suffix=['--rendering-driver','opengl3_angle',*suffix]
    command=[str(console),'--path',str(application/'godot'),*suffix]
    env=os.environ.copy();env['CYBERSAND_SOURCE_REVISION']=source
    env['CYBERSAND_DIAG_PRESENTATION']='';env['CYBERSAND_DIAG_RENDER_CADENCE']='';env['CYBERSAND_DIAG_FLYER_POSE']=''
    group='paint-persistence'if name in NAMES[1:]else name
    env['APPDATA']=str((evidence/'userdata'/group).resolve());env['XDG_DATA_HOME']=env['APPDATA']
    selected=['CYBERSAND_SOURCE_REVISION','CYBERSAND_EVAL_SOURCE_SHA','CYBERSAND_DIAG_PRESENTATION','CYBERSAND_DIAG_RENDER_CADENCE','CYBERSAND_DIAG_FLYER_POSE','APPDATA','XDG_DATA_HOME']
    if name in NAMES[1:]:
        env['PAINT_REOPEN']='1'if name=='paint-reopen'else''
        env['PAINT_CAPTURE_DIR']=str((folder/'frames').resolve())
        env['PAINT_STARTUP_OUTPUT']=str((folder/'startup.json').resolve())
        selected+=['PAINT_REOPEN','PAINT_CAPTURE_DIR','PAINT_STARTUP_OUTPUT']
    receipt={'name':name,'source':source,'invocation_index':index,'command':command,'cwd':str(application),'timeout_seconds':timeout,'environment':{k:env.get(k)for k in selected},'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'passed':False,'failures':[]}
    write(folder/'invocation.json',receipt);started=time.monotonic();raw=b'';code=None
    try:
        result=subprocess.run(command,cwd=application,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
        raw=result.stdout;code=result.returncode
    except subprocess.TimeoutExpired as error:
        raw=error.stdout or b'';receipt['process_watchdog_expired']=True;receipt['failures'].append('Original process watchdog expired')
    except OSError as error:receipt['failures'].append(str(error))
    log=evidence/(name+'.log');log.write_bytes(raw);text=raw.decode('utf-8','replace')
    receipt.update({'exit_code':code,'elapsed_seconds':time.monotonic()-started,'log_sha256':digest(log),'test_sha256':test_sha if name in NAMES[1:]else None})
    if name in NAMES[1:]:
        try:
            startup=read(folder/'startup.json');receipt['startup']=startup
            receipt['startup_validation']=validate_startup(startup,text,source,test_sha,env['PAINT_REOPEN'])
            receipt['startup_sha256']=digest(folder/'startup.json')
        except (OSError,ValueError,KeyError,TypeError,RuntimeError)as error:receipt['failures'].append('Startup evidence: '+str(error))
        try:
            receipt['paint_completion']=marker_json(text,'PAINT_EDITOR_WORKBENCH')
            validate_completion(text,code,env['PAINT_REOPEN'],receipt.get('startup',{}))
        except (ValueError,KeyError,TypeError,RuntimeError)as error:receipt['failures'].append('PAINT result: '+str(error))
        receipt['framebuffers']=[]
        if name=='paint-author':
            for label in('paint001-mixed-stamp-preview','paint001-mounted-editor'):
                path=folder/'frames'/(label+'.png')
                if path.is_file()and path.read_bytes().startswith(PNG):receipt['framebuffers'].append({'path':str(path),'sha256':digest(path),'bytes':path.stat().st_size})
                else:receipt['failures'].append('Original required PAINT framebuffer missing: '+label)
    else:
        if code!=0 or 'SCRIPT ERROR:'in text or 'SHADER ERROR:'in text:receipt['failures'].append('Original import failed')
    receipt['passed']=not receipt['failures'];write(folder/'receipt.json',receipt)
    print('PAINT_STARTUP_PROBE_CASE',json.dumps({'name':name,'passed':receipt['passed'],'exit_code':code,'elapsed_seconds':receipt['elapsed_seconds'],'failures':receipt['failures']}),flush=True)
    return receipt

def self_test(repo):
    specs=case_specs(repo/PACKAGER);checks=1
    base={'schema':'paint-startup-lifecycle-v1','source':'a'*40,'test_sha256':'b'*64,'reopen':'','limit_ms':60000,'default_limit_ms':30000,'passed':False,'timed_out':True,'terminal_ready':True,'started_usec':1,'wait_started_usec':2,'finished_usec':3,'events':[{'sequence':0,'time_usec':2,'process_frame':0,'physics_frame':0}],'event_count':1,'retained_event_count':1,'discarded_event_count':0}
    def encoded(value):return 'ANGLE\nPAINT_STARTUP_LIFECYCLE '+json.dumps(value)+'\nPAINT_EDITOR_WORKBENCH '+json.dumps({'checks':2,'failures':[],'reopen':''})+'\n'
    validate_startup(base,encoded(base),'a'*40,'b'*64,'');checks+=1
    late={**base,'passed':True,'timed_out':False,'terminal_ready':None,'started_usec':1000,'wait_started_usec':2000,'deadline_msec':60002,'finished_usec':60003100,'events':[{'sequence':0,'time_usec':2000,'process_frame':0,'physics_frame':0}],'last_ready_observation':{'ready':True,'terminal_diagnostic':False,'started_usec':60001000,'finished_usec':60003000}}
    validate_startup(late,encoded(late),'a'*40,'b'*64,'');validate_completion(encoded(late),0,'',late);checks+=1
    try:validate_startup({**late,'last_ready_observation':{}},encoded({**late,'last_ready_observation':{}}),'a'*40,'b'*64,'')
    except RuntimeError:checks+=1
    else:raise RuntimeError('Passed startup without ordinary ready evidence accepted')
    try:validate_completion(encoded(base),0,'',base)
    except RuntimeError:checks+=1
    else:raise RuntimeError('Late true incorrectly qualified failed readiness')
    for key,value in(('source','c'*40),('test_sha256','c'*64),('limit_ms',60001),('discarded_event_count',1),('passed',True)):
        altered={**base,key:value}
        try:validate_startup(altered,encoded(altered),'a'*40,'b'*64,'')
        except RuntimeError:checks+=1
        else:raise RuntimeError('Invalid startup evidence accepted: '+key)
    try:validate_startup(base,encoded({**base,'terminal_ready':False}),'a'*40,'b'*64,'')
    except RuntimeError:checks+=1
    else:raise RuntimeError('Mismatched file/marker accepted')
    print(json.dumps({'checks':checks,'failed':0,'scope':'Static contract and fail-closed receipt tests only; no Godot, package build or performance result.','production_case_specs':specs},indent=2))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--source-sha');parser.add_argument('--archive',type=Path)
    parser.add_argument('--application',type=Path);parser.add_argument('--evidence',type=Path)
    parser.add_argument('--self-test',action='store_true');args=parser.parse_args();repo=args.repository.resolve()
    if args.self_test:self_test(repo);return
    need(os.name=='nt','Actual probe must execute on Windows')
    need(re.fullmatch(r'[0-9a-f]{40}',args.source_sha or''),'Full exact source SHA required')
    need(all(x is not None for x in(args.archive,args.application,args.evidence)),'Archive, application and evidence paths required')
    evidence=args.evidence.resolve();evidence.mkdir(parents=True,exist_ok=False)
    summary={'schema':'paint-startup-installed-probe-v1','source':args.source_sha,'base_source':BASE,'complete':False,'cases':[],'failures':[],'owner_delivery_published':False,'physical_gpu_acceptance':'unqualified'}
    write(evidence/'summary.json',summary)
    try:
        need(git(repo,'rev-parse','HEAD')==args.source_sha,'Checkout/source differs')
        subprocess.run(['git','merge-base','--is-ancestor',BASE,args.source_sha],cwd=repo,check=True)
        subprocess.run(['git','diff','--exit-code',BASE,args.source_sha,'--',*PROTECTED],cwd=repo,check=True)
        packager=load_packager(repo);packager.SOURCE=args.source_sha
        identity=packager.preflight('windows');write(evidence/'source-runtime.json',identity)
        summary['source_tree']=identity['source_tree'];summary['changed_paths']=git(repo,'diff','--name-only',BASE,args.source_sha).splitlines()
        summary['runner_sha256']=digest(Path(__file__));summary['packager_sha256']=digest(repo/PACKAGER)
        summary['workflow_sha256']=digest(repo/'.github/workflows/paint-startup-probe.yml')
        qualification_paths=('tools/ci/run_paint_startup_probe.py','.github/workflows/paint-startup-probe.yml')
        subprocess.run(['git','diff','--exit-code',args.source_sha,'--',*qualification_paths],cwd=repo,check=True)
        summary['qualification_source_sha256']={name:digest(repo/name)for name in qualification_paths}
        specs=case_specs(repo/PACKAGER);summary['production_case_specs']=specs
        application=args.application.resolve();manifest=extract_fresh(packager,args.archive.resolve(),application,evidence,args.source_sha,identity['source_tree'])
        test_sha=digest(application/TEST);summary['installed_test_sha256']=test_sha
        for index,spec in enumerate(specs):
            # Preserve the production smoke loop: a failed author is retained,
            # and the independent fresh reopen still runs in the shared profile.
            case=execute_case(spec,application,evidence,args.source_sha,application/packager.CONSOLE,test_sha,index)
            summary['cases'].append(case)
            if not case['passed']:summary['failures'].append({'case':case['name'],'failures':case['failures']})
            write(evidence/'summary.json',summary)
        summary['payload_after']=verify_retained_payload(application,manifest)
        summary['source_runtime_after']=packager.preflight('windows')
        need(summary['qualification_source_sha256']=={name:digest(repo/name)for name in qualification_paths},'Qualification source changed while probing')
        need(summary['source_runtime_after']==identity,'Source/runtime identity changed while probing')
        summary['complete']=len(summary['cases'])==3 and not summary['failures']
    except Exception as error:summary['failures'].append({'stage':'preparation_or_identity','error':str(error)})
    finally:write(evidence/'summary.json',summary)
    print('PAINT_STARTUP_PROBE',json.dumps({'source':summary['source'],'complete':summary['complete'],'failed_cases':[c['name']for c in summary['cases']if not c['passed']],'failures':summary['failures']}),flush=True)
    if not summary['complete']:raise SystemExit(1)

if __name__=='__main__':main()
