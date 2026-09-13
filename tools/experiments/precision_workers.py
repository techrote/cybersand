"""Execute the preregistered same-phase concurrency supplement, sequentially."""
import json
import time
from state_precision import ROOT,OUT,BUILD,CORE,ARMS,environment,execute,digest,identity,write

def main():
    env,cxx=environment();out=OUT/('workers-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir()
    build=BUILD/out.name;build.mkdir();artifacts={}
    source=identity()
    source['supplement']={str(p.relative_to(ROOT)):digest(p) for p in [ROOT/'native/tests/test_precision_workers.cpp',ROOT/'docs/audits/2026-09-11-issue-17-worker-supplement.md']}
    write(out/'source.json',source)
    for arm,(mass,literal,delay) in ARMS.items():
        exe=build/(arm+'.exe')
        cmd=[cxx,'-std=c++20','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wshadow','-pthread','-static','-O3','-DNDEBUG','-flto','-Inative/include',
             f'-DCYBERSAND_MASS_BITS={mass}',f'-DCYBERSAND_LITERAL_TOLERANCE={literal}',f'-DCYBERSAND_DELAY_BITS={delay}',*CORE,'native/tests/test_precision_workers.cpp','-o',exe]
        execute('build-'+arm,cmd,out,env,1200)
        p=execute('test-'+arm,[exe],out,env)
        artifacts[arm]={'exe':str(exe),'sha256':digest(exe),'output_sha256':digest(p)}
        print('workers',arm,'passed',flush=True)
    write(out/'completed.json',{'source':source,'artifacts':artifacts});print(out/'completed.json')
if __name__=='__main__':main()
