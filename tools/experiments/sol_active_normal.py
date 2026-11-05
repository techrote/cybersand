#!/usr/bin/env python3
"""Execute preregistered baseline/trace/candidate copied-value comparison."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sol_active_normal_inputs as inputs
import sol_active_normal_source as source
import sol_active_normal_audit as audit
import sol_passive_values as old
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]
ARMS=['unchanged-production-header','trace-only-control','active-normal-001']
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('output',type=Path);args=parser.parse_args()
    output=args.output.resolve();assert output.is_relative_to(ROOT/'build') and not output.exists()
    assert not p.git('status','--porcelain'),'Commit source before execution'
    output.mkdir(parents=True);profile,base,cases=inputs.load();head=p.git('rev-parse','HEAD').decode().strip()
    paths=[inputs.PROFILE,profile['base_inputs'],profile['additional_inputs'],source.HEADER,'native/tests/sol_active_normal_driver.inc',
        'tools/experiments/sol_active_normal_source.py','tools/experiments/sol_active_normal_inputs.py','tools/experiments/sol_active_normal_audit.py','tools/experiments/sol_active_normal.py']
    paths+=['tools/experiments/sol_active_normal_compare.py','tools/experiments/sol_passive_values.py','tools/experiments/la_selective_experiment.py',
        'native/tests/sol_passive_values.cpp','docs/audits/sol-chamber-20261105/passive-values.json','docs/audits/sol-chamber-20261105/passive-observations.json']
    identity={n:sha(ROOT/n) for n in paths}
    generated={'gcr_trace.hpp':source.generate(False),'gcr_active_normal.hpp':source.generate(True),'driver.cpp':source.driver(),'inputs.txt':inputs.encode(cases)}
    for name,raw in generated.items():(output/name).write_bytes(raw)
    receipt=dict(source=head,tree=p.git('rev-parse','HEAD^{tree}').decode().strip(),registration=profile,input_sha256=identity,
        generated={k:hashlib.sha256(v).hexdigest() for k,v in generated.items()},commands=[],executions=[],solver_calls_per_binary=152,registered_replay_calls=114,workspace_priming_calls=38)
    def save():p.write(output/'receipt.json',receipt)
    def run(name,argv,env=None):
        row=p.command(name,argv,output,env,timeout=180);receipt['commands'].append(row);save();return row
    linux=['wsl.exe','-d','Ubuntu-24.04','--cd',p.wsl_path(ROOT),'--']
    run('gcc-version',linux+['g++','--version'])
    code="import hashlib,json,pathlib,shutil,subprocess;paths={'driver':pathlib.Path(shutil.which('g++')).resolve(),'frontend':pathlib.Path(subprocess.check_output(['g++','-print-prog-name=cc1plus'],text=True).strip()).resolve()};print(json.dumps({k:dict(path=str(v),sha256=hashlib.sha256(v.read_bytes()).hexdigest()) for k,v in paths.items()}))"
    row=run('gcc-identity',linux+['python3','-c',code]);assert row['clean'];receipt['gcc']=json.loads((ROOT/row['log']).read_text(encoding='utf-8'))
    setup=output/'msvc-env.cmd'
    setup.write_bytes(('@echo off\r\ncall "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\Common7\\Tools\\VsDevCmd.bat" -no_logo -arch=x64 -host_arch=x64 -vcvars_ver=14.38 > "%~dp0msvc-setup.log" 2>&1\r\nif errorlevel 1 exit /b %errorlevel%\r\npython -c "import os,json;print(json.dumps({k:os.environ[k] for k in [\'PATH\',\'INCLUDE\',\'LIB\',\'LIBPATH\',\'VCToolsVersion\']}))"\r\n').encode())
    row=run('msvc-env',['cmd.exe','/d','/c',str(setup)]);assert row['clean']
    selected=json.loads((ROOT/row['log']).read_text(encoding='utf-8'));env=dict(os.environ,**selected);env.pop('CL',None);env.pop('_CL_',None)
    compiler=shutil.which('cl.exe',path=selected['PATH']);assert compiler and '14.38.33130' in compiler
    receipt['msvc']=dict(path=compiler,sha256=sha(Path(compiler)),implicit_flags='CL/_CL_ removed',environment_log_sha256=row['log_sha256'])
    for platform in ['linux-opt','linux-san','windows-msvc']:
        for arm,name in enumerate(ARMS):
            tag=platform+'-'+str(arm);binary=output/(tag+('.exe' if platform=='windows-msvc' else ''))
            if platform=='windows-msvc':
                command=[compiler,'/nologo','/Bv','/std:c++20','/W4','/WX','/EHsc','/O2','/fp:strict','/DSOL_ACTIVE_ARM='+str(arm),'/Inative/include','/I'+str(output),str(output/'driver.cpp'),'/Fe:'+str(binary),'/Fo:'+str(output/(tag+'.obj'))]
            else:
                flags=['-O3','-DNDEBUG'] if platform=='linux-opt' else ['-O1','-g1','-fno-omit-frame-pointer','-fsanitize=address,undefined','-fno-sanitize-recover=all']
                command=linux+['g++','-std=c++20','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wshadow','-Werror','-ffp-contract=off',*flags,'-DSOL_ACTIVE_ARM='+str(arm),'-Inative/include','-I'+p.wsl_path(output),p.wsl_path(output/'driver.cpp'),'-o',p.wsl_path(binary)]
            built=run('compile-'+tag,command,env if platform=='windows-msvc' else None)
            if not built['clean']:continue
            extra=['env','ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:strict_string_checks=1','UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1'] if platform=='linux-san' else []
            command=[str(binary),str(output/'inputs.txt')] if platform=='windows-msvc' else linux+extra+[p.wsl_path(binary),p.wsl_path(output/'inputs.txt')]
            row=run('run-'+tag,command,env if platform=='windows-msvc' else None)
            result=dict(platform=platform,arm=name,arm_index=arm,binary_sha256=sha(binary),process=row,audit_status='UNAVAILABLE')
            receipt['executions'].append(result);save()
            if not row['clean']:continue
            try:
                data=json.loads((ROOT/row['log']).read_text(encoding='utf-8'))
                assert data['registration']==profile['id'] and len(data['cases'])==38 and data['replay_equal_cases']==38
                result['metrics']=[audit.record(c,r,arm) for c,r in zip(cases,data['cases'])]
                result['physical_observations_sha256']=hashlib.sha256(json.dumps([r['observation'] for r in data['cases']],sort_keys=True,separators=(',',':')).encode()).hexdigest()
                if arm==0:
                    control=dict(registration=base['id'],cases=data['cases'][:25],replay_equal_cases=25);old.audit(control,base)
                    original=json.loads((ROOT/'docs/audits/sol-chamber-20261105/passive-observations.json').read_text(encoding='utf-8'))
                    assert [r['observation'] for r in data['cases'][:25]]==[r['observation'] for r in original['cases']]
                elif arm==1:
                    baseline=next(e for e in receipt['executions'] if e['platform']==platform and e['arm_index']==0)
                    assert baseline['audit_status']=='PASS' and baseline['physical_observations_sha256']==result['physical_observations_sha256'],'Trace changes physical baseline'
                result['audit_status']='PASS'
            except Exception as error:result['audit_status']='FAIL';result['audit_error']=type(error).__name__+': '+str(error)
            save()
    assert head==p.git('rev-parse','HEAD').decode().strip() and not p.git('status','--porcelain')
    assert identity=={n:sha(ROOT/n) for n in paths}
    receipt['complete_execution_matrix']=len(receipt['executions'])==9 and all(e['process']['clean'] and e['audit_status']=='PASS' for e in receipt['executions']) and all(c['clean'] for c in receipt['commands'])
    receipt['candidate_decision']='PENDING independent benefit/safety comparison; execution completion is not acceptance'
    save();print(json.dumps(dict(source=head,executions=len(receipt['executions']),complete=receipt['complete_execution_matrix'])))
    return int(not receipt['complete_execution_matrix'])

if __name__=='__main__':raise SystemExit(main())
