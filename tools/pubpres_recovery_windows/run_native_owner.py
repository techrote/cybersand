#!/usr/bin/env python3
"""Execute the exact mounted native task/World fixture as an additive gate."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/pubpres_final_recovery'))
from identity import driver_identity,digest
from run_campaign import source_identity
from retained_runtime import validate_runtime
from run_regressions import stage_source,run
from run_focus import ENGINE_SHA256
import engine_admission
from native_owner_receipt import TEST,need,validate,verify_summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT)
    for name in ('runtime','engine','output'):parser.add_argument('--'+name,type=Path,required=True)
    engine_admission.add_arguments(parser)
    args=parser.parse_args();root=args.source.resolve();output=args.output.resolve();engine=args.engine.resolve()
    need(not output.exists(),'Preserve earlier mounted-native qualification output')
    source=source_identity(root);driver=driver_identity()
    need(source['source_commit']==driver['source_commit'],'Native fixture driver and application source differ')
    native=validate_runtime(root,source,args.runtime.resolve(),False)
    platform='windows' if os.name=='nt' else 'linux';engine_proof=None
    if args.engine_payload:
        actual,engine_proof=engine_admission.admit(args)
        need(actual==engine,'Mounted native engine differs from admitted original payload')
    else:need(digest(engine)==ENGINE_SHA256[platform],'Mounted native Stock executable differs')
    rapier=json.loads((root/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_bytes())
    need(digest(root/rapier['artifact'])==rapier['sha256'],'Mounted native Rapier bytes differ')
    for name,expected in rapier['source_inputs'].items():
        import hashlib
        need(hashlib.sha256(subprocess.check_output(['git','-C',str(root),'show',source['source_commit']+':'+name])).hexdigest()==expected,
             'Mounted native Rapier source differs: '+name)
    output.mkdir(parents=True);project=stage_source(root,source['source_commit'],output)
    shutil.copyfile(native['binary_path'],project/native['staged_relative_path'])
    shutil.copyfile(root/rapier['artifact'],project/Path(rapier['artifact']).relative_to('godot'))
    authored={path.relative_to(project).as_posix():digest(path) for path in project.rglob('*') if path.is_file()}
    report={'schema':'pubpres-closure-mounted-native-v1','source':source,'driver':driver,'native':native,
        'engine_sha256':digest(engine),'engine_admission':engine_proof,'rapier_sha256':rapier['sha256'],
        'platform':'Windows' if os.name=='nt' else 'Linux','staged_input_files_sha256':authored,
        'outcomes':[],'complete':False,'physical_acceptance':'HOLD','source_mutations':[],
        'scope':'Actual native module task/World ownership, independent of the frozen19 graphical inventory. No architecture/performance acceptance.'}
    def save():(output/'SUMMARY.json').write_text(json.dumps(report,indent=2)+'\n')
    clean={key:value for key,value in os.environ.items() if not key.startswith(('CYBERSAND_','WB_COMBINED_'))}
    def invoke(test):
        profile=output/(test+'-profile');profile.mkdir()
        env=dict(clean,CYBERSAND_SOURCE_REVISION=source['source_commit'],
            CYBERSAND_TASK_COMPLETION_NATIVE_OUTPUT=str(output/test/'receipt.json'),
            APPDATA=str(profile),LOCALAPPDATA=str(profile),XDG_DATA_HOME=str(profile),
            XDG_CONFIG_HOME=str(profile),XDG_CACHE_HOME=str(profile))
        command=[str(engine),'--headless','--path',str(project),'--audio-driver','Dummy']
        command+=['--editor','--import','--quit'] if test=='import' else ['--script','res://tests/'+TEST+'.gd']
        row=run(command,env,output/test,1200 if test=='import' else 600)
        row['test']=test;row['valid']=False;report['outcomes'].append(row)
        text=(output/test/'stdout.log').read_text(encoding='utf-8',errors='replace')
        row['valid']=row['returncode']==0 and row['timed_out'] is False and 'ERROR:' not in text
        save();return row['valid'],text
    try:
        save();imported,_=invoke('import')
        if imported:
            valid,text=invoke(TEST)
            if valid:
                raw=output/TEST/'receipt.json';receipt=json.loads(raw.read_bytes())
                report['result']=validate(receipt,text,source=source['source_commit'],
                    test_sha=digest(project/'tests'/(TEST+'.gd')),engine_sha=digest(engine),
                    native_sha=native['binary_sha256'],native_descriptor_sha=digest(project/'addons/cybersand_native/cybersand_native.gdextension'),
                    platform=report['platform'])
                report.update(receipt=receipt,receipt_sha256=digest(raw))
        report['source_mutations']=[name for name,sha in authored.items()
            if name not in ('.godot/global_script_class_cache.cfg','.godot/extension_list.cfg')
            and (not (project/name).is_file() or digest(project/name)!=sha)]
        report['complete']=len(report['outcomes'])==2 and all(row['valid'] for row in report['outcomes']) \
            and 'result' in report and not report['source_mutations']
        save()
        if report['complete']:
            replay=verify_summary(output/'SUMMARY.json',source=source,driver=driver,engine=engine,native=native)
            (output/'ADMITTED.json').write_text(json.dumps(replay,indent=2)+'\n')
    except Exception as exc:
        report['complete']=False;report['failure']={'type':type(exc).__name__,'message':str(exc)};save()
    print(json.dumps({'complete':report['complete'],'checks':report.get('result',{}).get('checks'),
                      'failure':report.get('failure')}))
    return 0 if report['complete'] else 1


if __name__=='__main__':sys.exit(main())
