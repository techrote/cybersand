"""Source-bound Windows/Linux owner-review controls; no physical efficacy rating."""
import argparse,concurrent.futures,json,os,shutil,subprocess
from pathlib import Path
from run_gcr_causal import run
from run_gcr_creep import ROOT,git,read,write,sha,source_inputs,verify_project,native_identity,linux

GATES=['test_gcr_powder_review','test_gcr_selective_events','test_gcr_granular_events_playground',
       'test_gcr_fleet_controls','test_gcr_fleet_emissions','test_gcr_fleet_side_thrusters',
       'test_actor_rig_integration','test_gcr_rest_bridge','test_gcr_rest_material_freshness','test_gcr_review_navigation']

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    folder=a.output.resolve()
    if folder.exists() or git('diff','--binary','HEAD'):raise RuntimeError('New output and committed source required')
    source=git('rev-parse','HEAD').decode().strip();inputs=source_inputs();folder.mkdir(parents=True)
    write(folder/'identity.json',dict(source=source,tree=git('rev-parse','HEAD^{tree}').decode().strip(),inputs=inputs))
    def platform_host(platform):
        out=folder/platform;out.mkdir();project=out/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','*.uid'))
        for name in ['docs/audits/gcr-load-2026-11-02/protocol.json','docs/audits/gcr-rest-2026-11-02/protocol.json']:
            dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dest);assert sha(dest)==sha(ROOT/name)
        verify_project(project,inputs);native=native_identity(platform,project)
        le='/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64'
        engine=['C:/Godot47/Godot_v4.7-stable_win64_console.exe'] if platform=='windows' else ['wsl','-d','Ubuntu-24.04','--','env','CYBERSAND_SOURCE_REVISION='+source,le]
        version=subprocess.check_output(engine+['--version'],text=True,timeout=60).strip();assert version=='4.7.stable.official.5b4e0cb0f'
        engine_hash=sha(Path('C:/Godot47/Godot_v4.7-stable_win64.exe')) if platform=='windows' else subprocess.check_output(['wsl','-d','Ubuntu-24.04','--','sha256sum',le],text=True,timeout=60).split()[0]
        write(out/'runtime.json',dict(native,engine_version=version,engine_sha256=engine_hash))
        prefix=engine+['--headless','--audio-driver','Dummy','--path',str(project) if platform=='windows' else linux(project)]
        gates=[]
        for name in ['import']+GATES:
            command=prefix+(['--editor','--quit'] if name=='import' else ['--script','res://tests/'+name+'.gd'])
            receipt=run(command,out/(name+'.log'),300,dict(os.environ,CYBERSAND_SOURCE_REVISION=source),platform,le)
            receipt['test']=name;gates.append(receipt);write(out/'gates.json',gates)
            print(platform,name,receipt['ok'],flush=True)
            if not receipt['ok']:return dict(platform=platform,ok=False)
        summary=[line.removeprefix('GCR_POWDER_REVIEW ') for line in (out/'test_gcr_powder_review.log').read_text(encoding='utf-8').splitlines() if line.startswith('GCR_POWDER_REVIEW ')]
        assert len(summary)==1
        data=json.loads(summary[0]);assert data['checks']>6000 and data['failures']==[] and len(data['runs'])==6
        write(out/'powder-summary.json',data)
        verify_project(project,inputs);assert native_identity(platform,project)==native
        for name in ['docs/audits/gcr-load-2026-11-02/protocol.json','docs/audits/gcr-rest-2026-11-02/protocol.json']:assert sha(ROOT/name)==sha(out/name)
        return dict(platform=platform,ok=True,gates=10,imports=1,checks=data['checks'],gates_sha256=sha(out/'gates.json'),summary_sha256=sha(out/'powder-summary.json'))
    with concurrent.futures.ThreadPoolExecutor(2) as pool:results=list(pool.map(platform_host,['windows','linux']))
    assert inputs==source_inputs() and not git('diff','--binary','HEAD') and git('rev-parse','HEAD').decode().strip()==source
    write(folder/'completion.json',dict(source=source,inputs_unchanged=True,ok=all(r['ok'] for r in results),results=results))
    return 0 if all(r['ok'] for r in results) else 1

if __name__=='__main__':raise SystemExit(main())
