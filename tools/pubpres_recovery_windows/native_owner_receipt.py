"""Strict additive replay of the mounted native pool/World ownership fixture."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re

TEST='test_pubpres_task_completion_native'
PREFIX='PUBPRES_TASK_COMPLETION_NATIVE_RESULT '


def need(value,message):
    if not value:raise ValueError(message)


def digest(path):
    with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def completion(value,mode,*,empty=False):
    need(isinstance(value,dict) and value.get('schema')=='PUBPRES-TASK-COMPLETION-V1'
         and value.get('mode')==mode and all(type(value.get(key)) is int for key in ('completed_dispatches','completed_tasks')),
         'Native completion mode, schema or counter type differs')
    if empty:need(value['completed_dispatches']==value['completed_tasks']==0,'Replacement owner borrowed predecessor task credit')
    else:need(0<value['completed_dispatches']<=value['completed_tasks'],'Actual required native tasks were not exercised')


def validate(receipt,text,*,source,test_sha,engine_sha,native_sha,native_descriptor_sha,platform):
    terminals=[json.loads(line[len(PREFIX):]) for line in text.splitlines() if line.startswith(PREFIX)]
    need(len(terminals)==1 and terminals[0]=={'checks':150,'failures':[]},'Mounted native exact150 terminal is absent or duplicated')
    need(receipt.get('schema')=='pubpres-task-completion-native-v1' and receipt.get('checks')==150
         and receipt.get('failures')==[] and receipt.get('source_revision')==source
         and receipt.get('test_sha256')==test_sha,'Mounted native source, fixture or assertion inventory differs')
    need(receipt.get('engine_sha256')==engine_sha and receipt.get('native_sha256')==native_sha
         and receipt.get('native_descriptor_sha256')==native_descriptor_sha
         and receipt.get('native_resource')=='res://addons/cybersand_native/bin/'+(
             'cybersand_native.windows.x86_64.dll' if platform=='Windows' else 'libcybersand_native.linux.x86_64.so')
         and receipt.get('platform')==platform and type(receipt.get('process_id')) is int
         and receipt['process_id']>0,'Mounted native actual executable/module/platform/PID differs')
    rows=receipt.get('observations')
    need(isinstance(rows,list) and len(rows)==6,'Mounted native observation inventory is incomplete')
    matched=[row for row in rows if row.get('stage')=='matched_native']
    prepared=[row for row in rows if row.get('stage')=='prepared_owner']
    refused=[row for row in rows if row.get('stage')=='refused_selector']
    need(len(matched)==1 and len(prepared)==2 and len(refused)==3,'Mounted native observation stages are duplicated or missing')
    row=matched[0];completion(row.get('control'),'all_workers');completion(row.get('candidate'),'actual_tasks')
    need(all(row['control'][key]==row['candidate'][key] for key in ('completed_dispatches','completed_tasks'))
         and row.get('control_completed_tick')==row.get('candidate_completed_tick')==32
         and re.fullmatch('[0-9a-f]{16}',row.get('physical_hash','')) is not None,
         'Matched Worlds omitted work or lack exact native physical state')
    need({row.get('enabled') for row in prepared}=={False,True}
         and all(type(row.get('enabled')) is bool for row in prepared),'Prepared owners did not exercise both selected modes')
    for row in prepared:
        mode='actual_tasks' if row['enabled'] else 'all_workers'
        completion(row.get('before'),mode,empty=True);completion(row.get('after'),mode)
        need(row.get('completed_tick')==8 and re.fullmatch('[0-9a-f]{16}',row.get('physical_hash','')) is not None,
             'Prepared owner did not complete eight real native turns')
    need(prepared[0]['physical_hash']==prepared[1]['physical_hash'],'Prepared owner physical trajectories differ')
    need({row.get('type') for row in refused}=={2,3,4}
         and all('must be boolean' in row.get('error','') for row in refused),
         'Strict native boolean selector refusal inventory differs')
    return {'checks':150,'matched_native_world_turns':32,'prepared_owner_turns_each':8,
            'invalid_selector_types':[2,3,4],'actual_task_participation':True,
            'scope':'Actual native module/World ownership and equal-work fixture only; no rendered or performance acceptance.'}


def verify_summary(path,*,source,driver,engine,native):
    path=Path(path);data=json.loads(path.read_bytes())
    need(data.get('schema')=='pubpres-closure-mounted-native-v1' and data.get('complete') is True
         and data.get('physical_acceptance')=='HOLD' and data.get('driver')==driver
         and all(data['source'][key]==source[key] for key in ('source_commit','source_tree'))
         and data.get('engine_sha256')==digest(engine)
         and data['native']['manifest_sha256']==native['manifest_sha256']
         and data['native']['binary_sha256']==native['binary_sha256']
         and data.get('source_mutations')==[],'Mounted native resulting-source custody is incomplete or changed')
    project=path.parent/'project'
    for name,sha in data['staged_input_files_sha256'].items():
        if name not in ('.godot/global_script_class_cache.cfg','.godot/extension_list.cfg'):
            need(digest(project/name)==sha,'Mounted native actual staged input changed: '+name)
    rows=data.get('outcomes',[])
    need(len(rows)==2 and [row.get('test') for row in rows]==['import',TEST],'Mounted native process inventory differs')
    for row in rows:
        log=path.parent/row['test']/'stdout.log';text=log.read_text(encoding='utf-8',errors='replace')
        need(row.get('returncode')==0 and row.get('timed_out') is False and row.get('valid') is True
             and digest(log)==row.get('log_sha256') and 'ERROR:' not in text,
             'Mounted native actual process or retained log failed')
        need(Path(row['command'][0]).resolve()==Path(engine).resolve()
             and row['command'][row['command'].index('--path')+1]==str(project.resolve()),
             'Mounted native actual executable/project command differs')
    raw=path.parent/TEST/'receipt.json';receipt=json.loads(raw.read_bytes())
    need(digest(raw)==data['receipt_sha256'] and receipt==data['receipt'],'Mounted native raw receipt changed')
    observed=validate(receipt,(raw.parent/'stdout.log').read_text(encoding='utf-8'),source=source['source_commit'],
        test_sha=digest(project/'tests'/(TEST+'.gd')),engine_sha=digest(engine),
        native_sha=native['binary_sha256'],native_descriptor_sha=digest(project/'addons/cybersand_native/cybersand_native.gdextension'),
        platform=data['platform'])
    need(observed==data['result'],'Mounted native original result no longer reproduces')
    from qualification_gate import verify_engine_binding
    verify_engine_binding(data,engine)
    return {'path':str(path),'sha256':digest(path),'source_commit':source['source_commit'],'checks':150,
        'engine_sha256':digest(engine),'native_sha256':native['binary_sha256'],
        'raw_inputs_and_native_receipt_replayed':True,'scope':observed['scope']}
