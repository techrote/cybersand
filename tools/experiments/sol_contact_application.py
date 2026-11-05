#!/usr/bin/env python3
"""Registered contact/application comparison; unchanged native runtime inputs."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sol_node_trace_runtime as runtime
import la_physical_campaign as authored
import la_selective_experiment as p

ROOT=runtime.ROOT
PROFILE='native/tests/fixtures/sol_contact_application_001.json'

def main():
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument('--run',required=True)
    parser.add_argument('--suite',choices=['policy','core'],required=True)
    parser.add_argument('--platforms',default='windows,linux');parser.add_argument('--workers',default='1,4')
    parser.add_argument('--repeats',type=int,default=1);parser.add_argument('--cases',default='');parser.add_argument('--arms',default='')
    args=parser.parse_args();assert Path(args.run).name==args.run and args.run not in ['.','..']
    assert os.name=='nt','This runner records actual Windows host plus WSL Linux'
    info=runtime.identity();profile=json.loads((ROOT/PROFILE).read_text(encoding='utf-8'))
    assert (ROOT/PROFILE).read_bytes().replace(b'\r\n',b'\n')==p.git('show','22153077:'+PROFILE),'Registration changed'
    platforms=args.platforms.split(',');workers=list(map(int,args.workers.split(',')))
    assert set(platforms)<={'windows','linux'} and platforms and len(set(platforms))==len(platforms)
    assert set(workers)<={1,4} and workers and len(set(workers))==len(workers) and args.repeats==1
    arms=[dict(a,mode='LA-SELECTIVE') for a in profile['arms']]
    if args.arms:arms=[a for a in arms if a['id'] in args.arms.split(',')];assert {a['id'] for a in arms}==set(args.arms.split(','))
    available=authored.load_registration(ROOT/'godot/tests/fixtures/la_physical/sol-contact-application-001.json')['cases']
    cases=[c for c in available if c['id'] in profile['stage_a']['cases']] if args.suite=='core' else []
    if args.cases:cases=[c for c in cases if c['id'] in args.cases.split(',')];assert {c['id'] for c in cases}==set(args.cases.split(','))
    folder=ROOT/'build/sol-contact-application'/args.run;assert not folder.exists();folder.mkdir(parents=True)
    copied={n:runtime.sha(ROOT/n) for n in p.git('ls-files','godot').decode().splitlines() if (ROOT/n).is_file()}
    receipt=dict(identity=info,registration=profile,runner_sha256=runtime.lfsha(Path(__file__)),copied_inputs=copied,
        matrix=vars(args),timing_qualification='sequential full-observer one-repeat diagnostic; not original SOL CPU or universal60Hz',profile_sha256=runtime.lfsha(ROOT/PROFILE),hosts={})
    def save():p.write(folder/'receipt.json',receipt)
    save()
    for platform in platforms:
        host=folder/platform;project=host/'godot';host.mkdir();rows=[]
        for name in copied:
            target=project/Path(name).relative_to('godot');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        binary=runtime.BINARIES[platform];override=info['rebuild']['platforms'][platform]
        shutil.copyfile(ROOT/override['output'],project/'addons/cybersand_native/bin'/binary)
        assert runtime.sha(project/'addons/cybersand_native/bin'/binary)==override['output_sha256']
        inventory={f.relative_to(project).as_posix():runtime.sha(f) for f in project.rglob('*') if f.is_file()}
        native=json.loads((ROOT/('godot/addons/cybersand_native/runtime-provenance'+('.linux' if platform=='linux' else '')+'.json')).read_text(encoding='utf-8'))
        rapier=json.loads((ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_text(encoding='utf-8'))
        assert runtime.sha(ROOT/rapier['artifact'])==rapier['sha256']
        for n,h in rapier['source_inputs'].items():assert runtime.lfsha(ROOT/n)==h,n
        state=dict(commands=rows,effective_inputs=inventory,native_override=override,rapier=rapier);receipt['hosts'][platform]=state;save()
        def run(name,script=None,env=None,version=False):
            forwarded=dict(CYBERSAND_SOURCE_REVISION=info['source'],**(env or {}))
            argv=[p.ENGINES[platform]]
            if version:argv+=['--version']
            else:
                argv+=['--headless','--audio-driver','Dummy','--path',str(project) if platform=='windows' else p.wsl_path(project)]
                argv+=['--editor','--import','--quit'] if script is None else ['--max-fps','120','--script','res://tests/'+script+'.gd']
            if platform=='linux':argv=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in forwarded.items()],*argv]
            row=p.command(name,argv,host,dict(os.environ,**forwarded),timeout=300);rows.append(row);save();return row
        def verify_project():
            changes=[];normalized=[]
            for name,digest in inventory.items():
                target=project/name
                if target.is_file() and runtime.sha(target)==digest:continue
                original=ROOT/'godot'/name
                if name.endswith('.import') and target.is_file() and target.read_bytes().replace(b'\r\n',b'\n')==original.read_bytes().replace(b'\r\n',b'\n'):normalized.append(name)
                else:changes.append(name)
            state['post_inventory']=dict(unexpected_changes=changes,import_LF_normalization_only=normalized);save();assert not changes
        version=run('engine-version',version=True);assert version['clean']
        assert (ROOT/version['log']).read_text(encoding='utf-8').strip()==native['godot_version']
        if platform=='windows':
            launcher=runtime.sha(Path(p.ENGINES[platform]));engine=runtime.sha(Path(p.ENGINES[platform].replace('_console.exe','.exe')))
            assert launcher==native['godot_validation_executable_sha256']
        else:
            row=p.command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',p.ENGINES[platform]],host);rows.append(row)
            assert row['clean'];engine=(ROOT/row['log']).read_text(encoding='utf-8').split()[0];launcher=engine
        assert engine==native['godot_executable_sha256'];state['engine']=dict(sha256=engine,launcher_sha256=launcher,version=native['godot_version']);save()
        if platform=='linux':
            floor=host/'floor';checker=floor/'tools/check_linux_runtime_floor.sh';checker.parent.mkdir(parents=True)
            shutil.copyfile(ROOT/'tools/check_linux_runtime_floor.sh',checker)
            assert runtime.sha(checker)==runtime.sha(ROOT/'tools/check_linux_runtime_floor.sh')
            for src,destination in [(ROOT/override['output'],floor/'godot/addons/cybersand_native/bin'/binary),
                    (ROOT/rapier['artifact'],floor/'godot/addons/godot-rapier2d/bin'/Path(rapier['artifact']).name)]:
                destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,destination);assert runtime.sha(src)==runtime.sha(destination)
            row=p.command('experimental-runtime-floor',['wsl.exe','-d','Ubuntu-24.04','--','bash',p.wsl_path(checker)],host)
            rows.append(row);state['floor_checker_sha256']=runtime.sha(checker);save();assert row['clean']
        imported=run('import')
        if not imported['clean']:verify_project();continue
        policy=run('policy-lifecycle','test_sol_active_normal_policy',{'SOL_POLICY_OUTPUT':str(host/'policy.json') if platform=='windows' else p.wsl_path(host/'policy.json')})
        if not policy['clean']:verify_project();continue
        trace_policy=run('trace-policy-lifecycle','test_sol_node_trace_policy',{'SOL_TRACE_POLICY_OUTPUT':str(host/'trace-policy.json') if platform=='windows' else p.wsl_path(host/'trace-policy.json')})
        if not trace_policy['clean']:verify_project();continue
        contact=run('contact-application-api','test_sol_contact_application',{'SOL_CONTACT_API_OUTPUT':str(host/'application-api.json') if platform=='windows' else p.wsl_path(host/'application-api.json')})
        if not contact['clean']:verify_project();continue
        if args.suite=='core':
            run('passive-safety','test_la_passive_response')
            run('force-accounting','test_la_force_accounting',{'LA_FORCE_OUTPUT':str(host/'force.json') if platform=='windows' else p.wsl_path(host/'force.json')})
            smoke=host/'smoke';smoke.mkdir()
            run('generic-smoke','test_la_physical_campaign',{'LA_PHYSICAL_OUTPUT':str(smoke) if platform=='windows' else p.wsl_path(smoke)})
            for name in p.SCOPED:run('workbench-'+name,'test_workbench_'+name)
        for repeat in range(args.repeats):
            for worker in workers:
                for case in cases:
                    for arm in arms:
                        tag=case['id']+'-'+arm['id']+'-w'+str(worker)+'-r'+str(repeat);output=host/tag;output.mkdir()
                        trace_mode='batch64-001' if platform=='windows' and worker==1 and case['id']=='shared-granular-bodies-extended360' else 'off'
                        path=str(output) if platform=='windows' else p.wsl_path(output)
                        environment={'SOL_NORMAL_POLICY':arm['normal_policy'],'SOL_NODE_TRACE_MODE':trace_mode,'SOL_CONTACT_APPLICATION':arm['application']}
                        environment.update(LA_PHYSICAL_OUTPUT=path,LA_PHYSICAL_CASES=case['id'],LA_PHYSICAL_WORKERS=str(worker),LA_PHYSICAL_REPEAT=str(repeat),LA_PHYSICAL_REGISTRATION='res://tests/fixtures/la_physical/sol-contact-application-001.json')
                        script='support/sol_contact_application_authored';expected=360
                        row=run(tag,script,environment);reports=list(output.glob('*.json'))
                        row['reports']=[dict(path=str(f.relative_to(ROOT)),sha256=runtime.sha(f)) for f in reports]
                        row['report_audit']='UNAVAILABLE'
                        if row['clean']:
                            try:
                                assert len(reports)==1;report=json.loads(reports[0].read_text(encoding='utf-8'))
                                assert report['source']==info['source'] and not report['failures'] and len(report['steps'])==expected
                                for step in report['steps']:
                                    packet=step['native_response'];assert packet['normal_policy']==arm['normal_policy'] and packet['response']==arm['mode']
                                    assert all(r['normal_policy']==arm['normal_policy'] for r in packet['rows'])
                                    assert packet['solver_trace_mode']==trace_mode and packet['solver_trace_locked']
                                    assert all(('solver_trace' in r)==(trace_mode=='batch64-001') for r in packet['rows'])
                                assert all(s['application']['application_variant']==arm['application'] for s in report['steps'])
                                row['report_audit']='PASS'
                            except Exception as error:row['report_audit']='FAIL';row['report_error']=type(error).__name__+': '+str(error)
                        save()
        verify_project()
    assert copied=={n:runtime.sha(ROOT/n) for n in copied},'Godot source changed during execution'
    assert info==runtime.identity(),'Experimental source/runtime identity changed during execution'
    receipt['post_source_equality']=True;save()
    return int(not all(c['clean'] and c.get('report_audit','PASS')=='PASS' for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':raise SystemExit(main())
