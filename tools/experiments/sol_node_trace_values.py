#!/usr/bin/env python3
"""Fresh trace parity/boundary qualification; historical oracles stay unchanged."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import la_selective_experiment as p
import sol_active_normal_inputs as inputs

ROOT=Path(__file__).resolve().parents[2]
def sha(path):return p.sha(path.read_bytes())
def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('output',type=Path);args=parser.parse_args()
    output=args.output.resolve();assert output.is_relative_to(ROOT/'build') and not output.exists();assert not p.git('status','--porcelain')
    output.mkdir(parents=True);head=p.git('rev-parse','HEAD').decode().strip();profile,base,cases=inputs.load()
    data=inputs.encode(cases);(output/'inputs.txt').write_bytes(data)
    paths=['native/include/cybersand/granular_contact_response.hpp','native/tests/sol_node_trace.cpp','native/tests/sol_passive_values.cpp',
        'native/tests/fixtures/sol_node_trace_001.json','native/tests/fixtures/sol_node_trace_wire_001.json','tools/experiments/sol_node_trace_values.py','tools/experiments/sol_active_normal_inputs.py']
    receipt=dict(source=head,tree=p.git('rev-parse','HEAD^{tree}').decode().strip(),input_sha256={n:sha(ROOT/n) for n in paths},generated_inputs_sha256=p.sha(data),commands=[],executions=[])
    def run(name,argv,env=None,timeout=300):
        r=p.command(name,argv,output,env,timeout);receipt['commands'].append(r);p.write(output/'receipt.json',receipt);return r
    # Retained nine-binary default/explicit/Active physical oracle, unmodified.
    frozen=run('frozen-parity',[sys.executable,'tools/experiments/sol_active_normal_live_values.py',str(output/'frozen')],timeout=900)
    assert frozen['clean'],'Retained physical oracle failed; no trace acceptance'
    linux=['wsl.exe','-d','Ubuntu-24.04','--cd',p.wsl_path(ROOT),'--']
    setup=output/'msvc-env.cmd'
    setup.write_bytes(('@echo off\r\ncall "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\Common7\\Tools\\VsDevCmd.bat" -no_logo -arch=x64 -host_arch=x64 -vcvars_ver=14.38 > "%~dp0msvc-setup.log" 2>&1\r\nif errorlevel 1 exit /b %errorlevel%\r\npython -c "import os,json;print(json.dumps({k:os.environ[k] for k in [\'PATH\',\'INCLUDE\',\'LIB\',\'LIBPATH\',\'VCToolsVersion\']}))"\r\n').encode())
    r=run('msvc-env',['cmd.exe','/d','/c',str(setup)]);assert r['clean']
    selected=json.loads((ROOT/r['log']).read_text(encoding='utf-8'));env=dict(os.environ,**selected);env.pop('CL',None);env.pop('_CL_',None)
    compiler=shutil.which('cl.exe',path=selected['PATH']);assert compiler and '14.38.33130' in compiler
    receipt['msvc']=dict(path=compiler,sha256=sha(Path(compiler)),implicit_flags='CL/_CL_ removed')
    r=run('gcc-version',linux+['g++','--version']);assert r['clean']
    for platform in ['linux-opt','linux-san','windows-msvc']:
        binary=output/(platform+('.exe' if platform=='windows-msvc' else ''))
        if platform=='windows-msvc':
            command=[compiler,'/nologo','/Bv','/std:c++20','/W4','/WX','/EHsc','/O2','/fp:strict','/I'+str(ROOT/'native/include'),str(ROOT/'native/tests/sol_node_trace.cpp'),'/Fe:'+str(binary),'/Fo:'+str(output/'node-trace.obj')]
        else:
            flags=['-O3'] if platform=='linux-opt' else ['-O1','-g','-fsanitize=address,undefined','-fno-sanitize-recover=all','-fno-omit-frame-pointer']
            command=linux+['g++','-std=c++20','-Wall','-Wextra','-Werror','-ffp-contract=off','-fno-fast-math',*flags,'-Inative/include','native/tests/sol_node_trace.cpp','-o',p.wsl_path(binary)]
        built=run(platform+'-compile',command,env if platform=='windows-msvc' else None);assert built['clean']
        argv=[str(binary),str(output/'inputs.txt')] if platform=='windows-msvc' else linux+['env','ASAN_OPTIONS=detect_leaks=1:halt_on_error=1','UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1',p.wsl_path(binary),p.wsl_path(output/'inputs.txt')]
        result=run(platform+'-run',argv,env if platform=='windows-msvc' else None);assert result['clean']
        observed=json.loads((ROOT/result['log']).read_text(encoding='utf-8'));assert observed['cases']==43 and observed['policies']==2 and observed['physical_parity'] and observed['reused_trace_parity'] and observed['body_alias_parity']
        receipt['executions'].append(dict(platform=platform,binary_sha256=sha(binary),observations=observed));p.write(output/'receipt.json',receipt)
    assert head==p.git('rev-parse','HEAD').decode().strip() and not p.git('status','--porcelain')
    receipt['complete']=True;p.write(output/'receipt.json',receipt);print(json.dumps(dict(source=head,complete=True,executions=receipt['executions'])))

if __name__=='__main__':main()
