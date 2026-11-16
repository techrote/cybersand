#!/usr/bin/env python3
"""Fresh-ZIP Windows PAINT author/reopen probe; never publishes an owner build."""
from __future__ import annotations
import argparse,ast,datetime,difflib,hashlib,importlib.util,json,os,re,stat,subprocess,tempfile,time,zipfile
from pathlib import Path

BASE='2f69a4a2f98ba67932909d824c86a9dcaf2551f9'
TEST='godot/tests/test_paint_editor_workbench.gd'
PACKAGER='tools/ci/package_engine_lab_windows.py'
PROTECTED=('godot/scripts','godot/shaders','godot/native_extension','godot/addons','native',
           'godot/project.godot','godot/main.tscn',PACKAGER)
ALLOWED_CHANGES=('.gitattributes',TEST,'tools/ci/run_paint_startup_probe.py',
                 '.github/workflows/paint-startup-probe.yml',
                 'docs/audits/2026-11-16-physics-freeze-remediation-002.md')
NAMES=('import','paint-author','paint-reopen')
COMPARISON_MODES=('full','auto','auto','full')
MATERIAL_FIRST=('host_add_end','main_enter','main_exit','frame_pre_draw')
EXPERIMENTAL_SELECTORS=('CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS',
                        'CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS',
                        'CYBERSAND_DIAG_MATERIAL_COPY_MODE')
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

def validate_startup(receipt,text,source,test_sha,reopen,material_mode=None):
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
    result={'source_verified':True,'bounded_events':retained,'discarded_events':discarded,
            'passed':receipt['passed'],'timed_out':receipt['timed_out'],'terminal_ready':receipt['terminal_ready']}
    if material_mode is not None:
        observations=receipt.get('first_material_publications',{})
        need(set(observations)==set(MATERIAL_FIRST),'First material observations are missing or unbounded')
        for stage in MATERIAL_FIRST:
            row=observations[stage];status=row['material_publication']
            need(row['event']==stage and row['time_usec']==receipt['first'][stage]
                 and 0<=row['sequence']<total,'First material observation identity differs')
            need(receipt['started_usec']<=row['time_usec']<=status['observation_started_usec']
                 <=status['observation_finished_usec']<=receipt['finished_usec'],
                 'First material observation clock ordering differs')
            if row['sequence']in sequences:
                retained_row=events[sequences.index(row['sequence'])]
                need(all(retained_row.get(key)==value for key,value in row.items()),
                     'Retained material event differs from the fixed first-observation map')
        first=observations['frame_pre_draw']['material_publication']
        expected='full'if material_mode=='full'else'blit'
        need(first.get('available')is True and first.get('requested_mode')==material_mode
             and first.get('backend')==expected and first.get('fallback_reason')=='',
             'First draw did not use the requested material treatment without fallback')
        need(first.get('driver')=='opengl3_angle','First draw material driver is not the shipping Windows ANGLE backend')
        need(first.get('current_texture_rid',0)>0 and first.get('previous_texture_rid',0)>0
             and first['current_texture_rid']!=first['previous_texture_rid'],
             'First draw material histories do not have distinct valid resource identities')
        if material_mode=='auto':
            need(first.get('staging_slots')==3 and first.get('copy_mode')=='runs',
                 'Shipping auto material defaults were overridden')
        result['first_draw_material_verified']=True
        result['first_draw_material']=first
    return result

def first_draw_covariates(startup):
    status=startup['first_material_publications']['frame_pre_draw']['material_publication']
    keys=('world_extent','render_channels','paused','uploaded_world_generation',
          'uploaded_revision','uploaded_render_serial')
    need(all(key in status for key in keys),'Missing first-draw workload covariate')
    snapshot=status['startup_snapshot'];need(type(snapshot.get('available'))is bool,'Missing snapshot availability')
    snapshot_keys=('world_generation','native_tick','render_serial','render_tick','simulation_revision',
                   'backend_name','native_worker_request','scheduler_thread_capacity_hint')
    if snapshot['available']:need(all(key in snapshot for key in snapshot_keys),'Missing first-draw native covariate')
    return {**{key:status[key]for key in keys},'startup_snapshot':{
        'available':snapshot['available'],**({key:snapshot[key]for key in snapshot_keys}if snapshot['available']else{})}}

def startup_metrics(startup):
    first=startup.get('first',{});result={
        'wait_elapsed_ms':(startup['finished_usec']-startup['wait_started_usec'])/1000,
        'scope':'Elapsed main/engine/render/driver/scheduling spans; not isolated CPU or GPU execution'}
    for label,begin,end in(('host_add_ms','host_add_begin','host_add_end'),
                          ('first_main_callback_ms','main_enter','main_exit'),
                          ('first_draw_signal_span_ms','frame_pre_draw','frame_post_draw')):
        if begin in first and end in first:result[label]=(first[end]-first[begin])/1000
    if 'ready_true'in first:result['first_ready_observed_ms']=(first['ready_true']-startup['wait_started_usec'])/1000
    for key in('largest_await','largest_main_callback','largest_draw_span'):
        if key in startup:result[key+'_ms']=startup[key]['duration_usec']/1000
    return result

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

def verify_retained_payload(application,manifest,archive,evidence,expected_archive_sha,manifest_file=None):
    """Scan every original file; preserve all mismatches before strict failure.

    No normalization or import-file exemption is applied. The source archive
    must already provide canonical bytes under its committed attributes.
    """
    expected_files=dict(manifest['files_sha256'])
    if manifest_file is not None:expected_files[manifest_file[0]]=manifest_file[1]
    report={'schema':'paint-probe-payload-after-v1','expected_archive_sha256':expected_archive_sha,
            'original_files_expected':len(expected_files),'files':[],
            'changes':[],'failures':[],'passed':False,'complete':False}
    reference=None
    try:
        report['actual_archive_sha256']=digest(archive)
        need(report['actual_archive_sha256']==expected_archive_sha,'Reference ZIP changed during execution')
        reference=zipfile.ZipFile(archive)
    except (OSError,RuntimeError,zipfile.BadZipFile)as error:
        report['failures'].append({'scope':'reference_zip','error':str(error)})
    try:
        for relative,expected in sorted(expected_files.items()):
            path=application/relative;row={'path':relative,'expected_sha256':expected,'actual_sha256':None,'status':'unread'}
            problem=None;after=None
            cursor=application
            try:
                need(not cursor.is_symlink()and not(getattr(cursor,'is_junction',lambda:False)()),'Application root is a link or junction')
                for part in Path(relative).parts:
                    cursor=cursor/part
                    need(not cursor.is_symlink()and not(getattr(cursor,'is_junction',lambda:False)()),'Payload path contains a link or junction')
                need(path.is_file(),'Payload file is absent or not a regular file')
                row['actual_sha256']=digest(path);row['bytes']=path.stat().st_size
                if row['actual_sha256']==expected:
                    row['status']='exact';report['files'].append(row);continue
                after=path.read_bytes()
                need(hashlib.sha256(after).hexdigest()==row['actual_sha256'],'Payload changed while recording mismatch')
                problem='Original package bytes changed'
            except (OSError,RuntimeError)as error:problem=str(error)
            row['status']='failed';row['error']=problem;before=None
            if reference is not None:
                try:
                    before=reference.read(relative)
                    need(hashlib.sha256(before).hexdigest()==expected,'Reference member differs from original manifest')
                except (KeyError,OSError,RuntimeError,zipfile.BadZipFile)as error:
                    row['reference_error']=str(error)
            folder=evidence/'payload-differences'/('change-%04d'%len(report['changes']))
            folder.mkdir(parents=True,exist_ok=False)
            for label,body in(('before',before),('after',after)):
                if body is None:row[label+'_bytes_available']=False;continue
                try:
                    body.decode('utf-8');textual=b'\0'not in body
                except UnicodeDecodeError:textual=False
                retained=folder/(label+('.txt'if textual else'.bin'));retained.write_bytes(body)
                row[label+'_bytes_available']=True;row[label+'_retained_path']=retained.relative_to(evidence).as_posix()
                row[label+'_sha256']=hashlib.sha256(body).hexdigest();row[label+'_bytes']=len(body)
            if before is not None and after is not None:
                try:
                    # Escape each original line so CRLF/LF changes are visible
                    # without altering either retained raw byte file.
                    a=[json.dumps(line,ensure_ascii=True)+'\n'for line in before.decode('utf-8').splitlines(keepends=True)]
                    b=[json.dumps(line,ensure_ascii=True)+'\n'for line in after.decode('utf-8').splitlines(keepends=True)]
                    diff=''.join(difflib.unified_diff(a,b,fromfile='before/'+relative,tofile='after/'+relative))
                except UnicodeDecodeError:diff='Binary bytes differ; exact before/after files and hashes are retained.\n'
            else:diff='A byte side is unavailable; see the explicit missing/link/read/reference error.\n'
            diff_path=folder/'text.diff';diff_path.write_bytes(diff.encode('utf-8'))
            row['text_diff_path']=diff_path.relative_to(evidence).as_posix();row['text_diff_sha256']=digest(diff_path)
            report['files'].append(row);report['changes'].append(dict(row));report['failures'].append({'path':relative,'error':problem})
    finally:
        if reference is not None:reference.close()
    report['original_files_checked']=len(report['files'])
    report['exact_files']=sum(row['status']=='exact'for row in report['files'])
    report['complete']=report['original_files_checked']==report['original_files_expected']
    report['passed']=report['complete']and not report['failures']
    write(evidence/'payload-after.json',report)
    return report

def case_plan(specs,evidence,comparison):
    if not comparison:return [{'spec':spec,'evidence':evidence,'material_mode':None,'pair':None}for spec in specs]
    rows=[{'spec':specs[0],'evidence':evidence,'material_mode':None,'pair':None}]
    for pair,mode in enumerate(COMPARISON_MODES):
        folder=evidence/'pairs'/('%02d-%s'%(pair,mode))
        rows.extend({'spec':spec,'evidence':folder,'material_mode':mode,'pair':pair}for spec in specs[1:])
    return rows

def case_environment(inherited,source,evidence,folder,name,material_mode):
    env=inherited.copy();env['CYBERSAND_SOURCE_REVISION']=source
    env['CYBERSAND_DIAG_PRESENTATION']='';env['CYBERSAND_DIAG_RENDER_CADENCE']='';env['CYBERSAND_DIAG_FLYER_POSE']=''
    if material_mode is not None:
        need(material_mode in ('full','auto'),'Invalid comparison material selector')
        env['CYBERSAND_MATERIAL_PUBLICATION']=material_mode
        for key in EXPERIMENTAL_SELECTORS:env[key]=''
    group='paint-persistence'if name in NAMES[1:]else name
    env['APPDATA']=str((evidence/'userdata'/group).resolve());env['XDG_DATA_HOME']=env['APPDATA']
    if name in NAMES[1:]:
        env['PAINT_REOPEN']='1'if name=='paint-reopen'else''
        env['PAINT_CAPTURE_DIR']=str((folder/'frames').resolve())
        env['PAINT_STARTUP_OUTPUT']=str((folder/'startup.json').resolve())
    return env

def execute_case(spec,application,evidence,source,console,test_sha,index,material_mode=None,pair=None):
    name,suffix,timeout,marker=spec;folder=evidence/name;folder.mkdir(exist_ok=False)
    if '--headless'not in suffix and '--rendering-driver'not in suffix:suffix=['--rendering-driver','opengl3_angle',*suffix]
    command=[str(console),'--path',str(application/'godot'),*suffix]
    env=case_environment(os.environ,source,evidence,folder,name,material_mode)
    selected=['CYBERSAND_SOURCE_REVISION','CYBERSAND_EVAL_SOURCE_SHA','CYBERSAND_DIAG_PRESENTATION',
              'CYBERSAND_DIAG_RENDER_CADENCE','CYBERSAND_DIAG_FLYER_POSE','CYBERSAND_DIAG_PHYSICS_PUBLICATION',
              'CYBERSAND_DIAG_COMMON_OBSERVER','CYBERSAND_MATERIAL_PUBLICATION',*EXPERIMENTAL_SELECTORS,'APPDATA','XDG_DATA_HOME']
    if name in NAMES[1:]:
        selected+=['PAINT_REOPEN','PAINT_CAPTURE_DIR','PAINT_STARTUP_OUTPUT']
    receipt={'name':name,'source':source,'invocation_index':index,'pair':pair,'material_mode':material_mode,
             'command':command,'cwd':str(application),'timeout_seconds':timeout,'environment':{k:env.get(k)for k in selected},
             'profile_existed_before':Path(env['APPDATA']).exists(),
             'inherited_material_selectors':{k:os.environ.get(k)for k in('CYBERSAND_MATERIAL_PUBLICATION',*EXPERIMENTAL_SELECTORS)},
             'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'passed':False,'failures':[]}
    write(folder/'invocation.json',receipt);started=time.monotonic();raw=b'';code=None
    try:
        need(name!='paint-author'or not receipt['profile_existed_before'],'Author profile is not fresh')
        result=subprocess.run(command,cwd=application,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
        raw=result.stdout;code=result.returncode
    except subprocess.TimeoutExpired as error:
        raw=error.stdout or b'';receipt['process_watchdog_expired']=True;receipt['failures'].append('Original process watchdog expired')
    except (OSError,RuntimeError)as error:receipt['failures'].append(str(error))
    log=evidence/(name+'.log');log.write_bytes(raw);text=raw.decode('utf-8','replace')
    receipt.update({'exit_code':code,'elapsed_seconds':time.monotonic()-started,'log_sha256':digest(log),'test_sha256':test_sha if name in NAMES[1:]else None})
    if name in NAMES[1:]:
        try:
            startup=read(folder/'startup.json');receipt['startup']=startup
            receipt['startup_sha256']=digest(folder/'startup.json')
            receipt['startup_metrics']=startup_metrics(startup)
            receipt['startup_validation']=validate_startup(startup,text,source,test_sha,env['PAINT_REOPEN'],material_mode)
            if material_mode is not None:receipt['first_draw_covariates']=first_draw_covariates(startup)
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
    print('PAINT_STARTUP_PROBE_CASE',json.dumps({'name':name,'pair':pair,'material_mode':material_mode,
        'passed':receipt['passed'],'exit_code':code,'elapsed_seconds':receipt['elapsed_seconds'],
        'startup_metrics':receipt.get('startup_metrics'),'failures':receipt['failures']}),flush=True)
    return receipt

def validate_comparison(cases):
    result={'order':list(COMPARISON_MODES),'profile_cold_only':True,
            'machine_and_driver_caches_reset':False,'all_pairs_retained':False,'matched':False,
            'geometry_content_scope':'Source/inputs and listed metadata only; World cell bytes are not independently hashed',
            'snapshot_publication_serial_scope':'Recorded in raw observations; not a workload match key for identical paused publications',
            'phases':{},'failures':[]}
    paired=[case for case in cases if case.get('pair')is not None]
    result['all_pairs_retained']=len(paired)==8 and [(c['pair'],c['name'],c['material_mode'])for c in paired]==[
        (pair,name,mode)for pair,mode in enumerate(COMPARISON_MODES)for name in NAMES[1:]]
    if not result['all_pairs_retained']:result['failures'].append('The four ordered author/reopen pairs are incomplete')
    profiles={}
    for case in paired:
        profile=case.get('environment',{}).get('APPDATA')
        if not profile:result['failures'].append('A pair invocation lacks its profile identity');continue
        profiles.setdefault(case['pair'],set()).add(profile)
    result['profiles']={str(pair):sorted(paths)for pair,paths in profiles.items()}
    if len(profiles)!=4 or any(len(paths)!=1 for paths in profiles.values())or len(set().union(*profiles.values()))!=4:
        result['failures'].append('Pairs do not have four isolated author/reopen profiles')
    controls=[{key:value for key,value in case.get('environment',{}).items()
        if key not in ('APPDATA','XDG_DATA_HOME','CYBERSAND_MATERIAL_PUBLICATION','PAINT_REOPEN','PAINT_CAPTURE_DIR','PAINT_STARTUP_OUTPUT')}for case in paired]
    if controls and any(row!=controls[0]for row in controls[1:]):result['failures'].append('Non-treatment environment controls differ')
    result['common_environment']=controls[0]if controls else{}
    for name in NAMES[1:]:
        rows=[{'pair':case['pair'],'mode':case['material_mode'],'covariates':case.get('first_draw_covariates'),
               'metrics':case.get('startup_metrics'),'passed':case['passed']}for case in paired if case['name']==name]
        matched=len(rows)==4 and rows[0]['covariates']is not None and all(row['covariates']==rows[0]['covariates']for row in rows)
        result['phases'][name]={'first_draw_metadata_matched':matched,'rows':rows}
        if not matched:result['failures'].append(name+': first-draw workload metadata differs or is absent')
    result['matched']=not result['failures']
    return result

def self_test(repo):
    specs=case_specs(repo/PACKAGER);checks=1
    retained_changes=git(repo,'diff','--name-only',BASE,'5455b4f68cf686d9ba65ffe4dc06a944a1301952').splitlines()
    need(set(retained_changes+['.gitattributes'])<=set(ALLOWED_CHANGES),'Actual retained probe changes exceed the intended allowlist');checks+=1
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
    material={'available':True,'requested_mode':'auto','backend':'blit','fallback_reason':'',
              'driver':'opengl3_angle','current_texture_rid':1,'previous_texture_rid':2,
              'staging_slots':3,'copy_mode':'runs','world_extent':[2048,2048],'render_channels':2,
              'paused':True,'uploaded_world_generation':1,'uploaded_revision':1,'uploaded_render_serial':1,
              'startup_snapshot':{'available':True,'serial':7,'world_generation':1,'native_tick':0,
                  'render_serial':1,'render_tick':0,'simulation_revision':1,'backend_name':'native_cpu',
                  'native_worker_request':0,'scheduler_thread_capacity_hint':8}}
    captured={**late,'events':[],'event_count':4,'retained_event_count':4,'first':{},'first_material_publications':{}}
    for index,stage in enumerate(MATERIAL_FIRST):
        stamp=1100+100*index;status={**material,'observation_started_usec':stamp,'observation_finished_usec':stamp+1}
        row={'event':stage,'sequence':index,'time_usec':stamp,'process_frame':0,'physics_frame':0,'material_publication':status}
        captured['events'].append(row);captured['first'][stage]=stamp;captured['first_material_publications'][stage]=dict(row)
    validate_startup(captured,encoded(captured),'a'*40,'b'*64,'','auto');checks+=1
    for key,value in(('backend','full'),('requested_mode','blit'),('fallback_reason','failed'),
                     ('staging_slots',2),('copy_mode','tiles'),('driver','opengl3')):
        altered=json.loads(json.dumps(captured))
        altered['events'][-1]['material_publication'][key]=value
        altered['first_material_publications']['frame_pre_draw']['material_publication'][key]=value
        try:validate_startup(altered,encoded(altered),'a'*40,'b'*64,'','auto')
        except RuntimeError:checks+=1
        else:raise RuntimeError('Invalid material treatment accepted: '+key)
    full=json.loads(json.dumps(captured))
    for row in [*full['events'],*full['first_material_publications'].values()]:
        row['material_publication'].update({'backend':'full','requested_mode':'full'})
    validate_startup(full,encoded(full),'a'*40,'b'*64,'','full');checks+=1
    other=json.loads(json.dumps(captured));other['first_material_publications']['frame_pre_draw']['material_publication']['startup_snapshot']['serial']=99
    need(first_draw_covariates(other)==first_draw_covariates(captured),'Paused status publication count became a workload covariate');checks+=1
    with tempfile.TemporaryDirectory(prefix='paint-probe-contract-')as directory:
        root=Path(directory);plan=case_plan(specs,root,True)
        need(len(plan)==9 and [row['material_mode']for row in plan[1::2]]==list(COMPARISON_MODES),'ABBA arm order differs');checks+=1
        inherited={**{key:'inherited-experiment'for key in EXPERIMENTAL_SELECTORS},'UNCHANGED_CONTROL':'same'}
        a=case_environment(inherited,'a'*40,root,root/'paint-author','paint-author','full')
        b=case_environment(inherited,'a'*40,root,root/'paint-author','paint-author','auto')
        need([key for key in a if a[key]!=b[key]]==['CYBERSAND_MATERIAL_PUBLICATION']
             and all(a[key]==b[key]==''for key in EXPERIMENTAL_SELECTORS),'Arms differ beyond the material selector');checks+=1
        rows=[]
        for index,item in enumerate(plan[1:]):
            env=case_environment(inherited,'a'*40,item['evidence'],item['evidence']/item['spec'][0],item['spec'][0],item['material_mode'])
            rows.append({'name':item['spec'][0],'pair':item['pair'],'material_mode':item['material_mode'],
                         'passed':True,'environment':env,'first_draw_covariates':first_draw_covariates(captured)})
        need(validate_comparison(rows)['matched'],'Valid isolated ABBA rejected');checks+=1
        changed=json.loads(json.dumps(rows));changed[-1]['first_draw_covariates']['uploaded_world_generation']=2
        need(not validate_comparison(changed)['matched'],'Different first-draw geometry identity accepted');checks+=1
        changed=json.loads(json.dumps(rows));changed[-1]['environment']['APPDATA']=changed[0]['environment']['APPDATA']
        need(not validate_comparison(changed)['matched'],'Reused pair profile accepted');checks+=1
        original={'first.import':b'[remap]\npath="res://original"\n','main.gd':b'original source\n',
                  'missing.cfg':b'keep\n','not-file.cfg':b'keep\n','stable.txt':b'keep\n','last.txt':b'last\n'}
        application=root/'application';application.mkdir();archive=root/'original.zip'
        with zipfile.ZipFile(archive,'w')as bundle:
            for name,body in original.items():(application/name).write_bytes(body);bundle.writestr(name,body)
        manifest={'files_sha256':{name:hashlib.sha256(body).hexdigest()for name,body in original.items()}}
        exact=root/'exact';exact.mkdir();report=verify_retained_payload(application,manifest,archive,exact,digest(archive))
        need(report['passed']and report['original_files_checked']==6,'Exact original payload rejected');checks+=1
        (application/'first.import').write_bytes(original['first.import'].replace(b'\n',b'\r\n'))
        (application/'main.gd').write_bytes(b'changed source\n')
        (application/'missing.cfg').unlink();(application/'not-file.cfg').unlink();(application/'not-file.cfg').mkdir()
        failed=root/'failed';failed.mkdir();report=verify_retained_payload(application,manifest,archive,failed,digest(archive))
        need(not report['passed']and report['complete']and report['original_files_checked']==6
             and len(report['changes'])==4 and report['exact_files']==2,'Complete strict mismatch ledger stopped early');checks+=1
        eol=next(row for row in report['changes']if row['path']=='first.import')
        need(eol['before_sha256']==manifest['files_sha256']['first.import']
             and eol['after_sha256']==digest(application/'first.import')
             and '\\r\\n'in(failed/eol['text_diff_path']).read_text(encoding='utf-8'),
             'EOL mismatch bytes/diff are missing or were waived');checks+=1
        for row in report['changes']:
            need((failed/row['text_diff_path']).is_file(),'A later mismatch lost its evidence');checks+=1
        manifest_name='manifest.json';manifest_body=b'{"source":"retained"}\n'
        (application/manifest_name).write_bytes(b'{"source":"changed"}\n')
        with zipfile.ZipFile(archive,'a')as bundle:bundle.writestr(manifest_name,manifest_body)
        manifest_failure=root/'manifest-failure';manifest_failure.mkdir()
        report=verify_retained_payload(application,manifest,archive,manifest_failure,digest(archive),
                                      (manifest_name,hashlib.sha256(manifest_body).hexdigest()))
        need(report['complete']and not report['passed']and report['original_files_checked']==7
             and any(row['path']==manifest_name for row in report['changes']),
             'The package manifest itself escaped strict original-file verification');checks+=1
    print(json.dumps({'checks':checks,'failed':0,'scope':'Static contract and fail-closed receipt tests only; no Godot, package build or performance result.','production_case_specs':specs},indent=2))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--source-sha');parser.add_argument('--archive',type=Path)
    parser.add_argument('--application',type=Path);parser.add_argument('--evidence',type=Path)
    parser.add_argument('--profile-comparison',action='store_true',help='One import plus profile-cold full/auto/auto/full author/reopen pairs')
    parser.add_argument('--self-test',action='store_true');args=parser.parse_args();repo=args.repository.resolve()
    if args.self_test:self_test(repo);return
    need(os.name=='nt','Actual probe must execute on Windows')
    need(re.fullmatch(r'[0-9a-f]{40}',args.source_sha or''),'Full exact source SHA required')
    need(all(x is not None for x in(args.archive,args.application,args.evidence)),'Archive, application and evidence paths required')
    evidence=args.evidence.resolve();evidence.mkdir(parents=True,exist_ok=False)
    summary={'schema':'paint-startup-installed-probe-v1','source':args.source_sha,'base_source':BASE,
             'profile_comparison':args.profile_comparison,'complete':False,'cases':[],'failures':[],
             'owner_delivery_published':False,'physical_gpu_acceptance':'unqualified'}
    write(evidence/'summary.json',summary)
    manifest=None;application=None;packager=None;identity=None
    qualification_paths=('tools/ci/run_paint_startup_probe.py','.github/workflows/paint-startup-probe.yml','.gitattributes')
    try:
        need(git(repo,'rev-parse','HEAD')==args.source_sha,'Checkout/source differs')
        subprocess.run(['git','merge-base','--is-ancestor',BASE,args.source_sha],cwd=repo,check=True)
        subprocess.run(['git','diff','--exit-code',BASE,args.source_sha,'--',*PROTECTED],cwd=repo,check=True)
        packager=load_packager(repo);packager.SOURCE=args.source_sha
        identity=packager.preflight('windows');write(evidence/'source-runtime.json',identity)
        summary['source_tree']=identity['source_tree'];summary['changed_paths']=git(repo,'diff','--name-only',BASE,args.source_sha).splitlines()
        need(set(summary['changed_paths'])<=set(ALLOWED_CHANGES),'Probe changes exceed the exact test/harness/attributes/audit allowlist')
        summary['runner_sha256']=digest(Path(__file__));summary['packager_sha256']=digest(repo/PACKAGER)
        summary['workflow_sha256']=digest(repo/'.github/workflows/paint-startup-probe.yml')
        subprocess.run(['git','diff','--exit-code',args.source_sha,'--',*qualification_paths],cwd=repo,check=True)
        summary['qualification_source_sha256']={name:digest(repo/name)for name in qualification_paths}
        specs=case_specs(repo/PACKAGER);summary['production_case_specs']=specs
        application=args.application.resolve();manifest=extract_fresh(packager,args.archive.resolve(),application,evidence,args.source_sha,identity['source_tree'])
        summary['archive_sha256']=read(evidence/'fresh-package.json')['archive_sha256']
        summary['manifest_sha256']=read(evidence/'fresh-package.json')['manifest_sha256']
        test_sha=digest(application/TEST);summary['installed_test_sha256']=test_sha
        plan=case_plan(specs,evidence,args.profile_comparison)
        summary['expected_cases']=len(plan)
        for index,item in enumerate(plan):
            # Never retry or stop after a failed arm. Each fresh-process reopen
            # still uses its own author's profile, including a failed author.
            item['evidence'].mkdir(parents=True,exist_ok=True)
            try:
                case=execute_case(item['spec'],application,item['evidence'],args.source_sha,
                    application/packager.CONSOLE,test_sha,index,item['material_mode'],item['pair'])
            except Exception as error:
                case={'name':item['spec'][0],'pair':item['pair'],'material_mode':item['material_mode'],
                      'invocation_index':index,'passed':False,'failures':['Case setup or evidence failure: '+str(error)]}
                write(item['evidence']/('case-error-%02d.json'%index),case)
            summary['cases'].append(case)
            if not case['passed']:summary['failures'].append({'case':case['name'],'pair':case.get('pair'),'failures':case['failures']})
            write(evidence/'summary.json',summary)
        if args.profile_comparison:
            summary['comparison']=validate_comparison(summary['cases'])
            write(evidence/'comparison.json',summary['comparison'])
            if not summary['comparison']['matched']:
                summary['failures'].append({'stage':'comparison_covariates','failures':summary['comparison']['failures']})
    except Exception as error:summary['failures'].append({'stage':'preparation_or_identity','error':str(error)})
    finally:
        if manifest is not None:
            try:
                summary['payload_after']=verify_retained_payload(application,manifest,args.archive.resolve(),evidence,
                    summary['archive_sha256'],(packager.MANIFEST,summary['manifest_sha256']))
                if not summary['payload_after']['passed']:
                    summary['failures'].append({'stage':'payload_after','error':'Original package payload differs; complete payload-after.json and every mismatch are retained'})
            except Exception as error:summary['failures'].append({'stage':'payload_after','error':str(error)})
        if identity is not None:
            try:
                summary['source_runtime_after']=packager.preflight('windows')
                need(summary.get('qualification_source_sha256')=={name:digest(repo/name)for name in qualification_paths},'Qualification source changed while probing')
                need(summary['source_runtime_after']==identity,'Source/runtime identity changed while probing')
            except Exception as error:summary['failures'].append({'stage':'final_source_identity','error':str(error)})
        summary['complete']=len(summary['cases'])==(9 if args.profile_comparison else 3)and not summary['failures']
        write(evidence/'summary.json',summary)
    print('PAINT_STARTUP_PROBE',json.dumps({'source':summary['source'],'complete':summary['complete'],'failed_cases':[c['name']for c in summary['cases']if not c['passed']],'failures':summary['failures']}),flush=True)
    if not summary['complete']:raise SystemExit(1)

if __name__=='__main__':main()
