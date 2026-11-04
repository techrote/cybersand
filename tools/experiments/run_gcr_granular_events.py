"""Acquire the preregistered granular-only event population with bounded hosts."""
import argparse,hashlib,json,os,shutil,subprocess
from pathlib import Path
from run_gcr_causal import run,EXISTING
from run_gcr_creep import ROOT,git,read,write,sha,source_inputs,verify_project,native_identity,linux

PROTOCOL=ROOT/'docs/audits/gcr-events-2026-11-04/protocol.json'

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--gates-only',action='store_true')
    args=p.parse_args();out=args.output.resolve()
    if out.exists() or git('diff','--binary','HEAD'):raise RuntimeError('New output and committed source required')
    protocol=read(PROTOCOL)
    assert protocol['registration']=='GCR-EVT-001-2026-11-04' and len(protocol['cases'])==12
    assert git('show','HEAD:'+PROTOCOL.relative_to(ROOT).as_posix()).replace(b'\r\n',b'\n')==PROTOCOL.read_bytes().replace(b'\r\n',b'\n')
    head=git('rev-parse','HEAD').decode().strip();inputs=source_inputs()
    ih=hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest()
    out.mkdir(parents=True)
    identity=dict(source=head,tree=git('rev-parse','HEAD^{tree}').decode().strip(),source_inputs=inputs,source_inputs_sha256=ih,protocol_sha256=sha(PROTOCOL),platforms={})
    env=dict(os.environ,GCR_EVENT_SOURCE=head,GCR_EVENT_INPUT_IDENTITY=ih)
    completed=0
    for platform in protocol['platforms']:
        folder=out/platform;folder.mkdir();project=folder/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','*.uid'))
        # Navigation opens the real barrel-review scene, whose retained
        # registrations live beside the source project. Copy only those exact
        # immutable inputs, preserving the scene's ordinary relative lookup.
        review_protocols={}
        for relative in ['docs/audits/gcr-load-2026-11-02/protocol.json','docs/audits/gcr-rest-2026-11-02/protocol.json']:
            original=ROOT/relative;copied=folder/relative;copied.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(original,copied);assert sha(copied)==sha(original)
            review_protocols[relative]=sha(original)
        verify_project(project,inputs);native=native_identity(platform,project)
        le='/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64'
        if platform=='windows':
            engine=['C:/Godot47/Godot_v4.7-stable_win64_console.exe'];engine_hash=sha(Path('C:/Godot47/Godot_v4.7-stable_win64.exe'))
        else:
            engine=['wsl','-d','Ubuntu-24.04','--','env','GCR_EVENT_SOURCE='+head,'GCR_EVENT_INPUT_IDENTITY='+ih,le]
            engine_hash=subprocess.check_output(['wsl','-d','Ubuntu-24.04','--','sha256sum',le],text=True,timeout=60).split()[0]
        version=subprocess.check_output(engine+['--version'],text=True,timeout=60).strip()
        assert version=='4.7.stable.official.5b4e0cb0f'
        identity['platforms'][platform]=dict(native,engine_sha256=engine_hash,engine_version=version)
        write(out/'identity.json',identity)
        cv=lambda x:str(Path(x).resolve()) if platform=='windows' else linux(x)
        prefix=engine+['--headless','--audio-driver','Dummy','--path',cv(project)]
        gates=[]
        for name in ['import','test_gcr_granular_events','test_gcr_granular_events_playground']+EXISTING+[
                'test_gcr_detachment','test_solid_detachment_displacement','test_solid_detachment_compound_response',
                'test_gcr_fleet_emissions','test_gcr_fleet_side_thrusters','test_gcr_review_navigation']:
            command=prefix+(['--editor','--quit'] if name=='import' else ['--script','res://tests/'+name+'.gd'])
            if name=='test_gcr_envelope':command+=['--','--protocol='+cv(ROOT/'docs/audits/gcr001-2026-11-01/protocol.json')]
            receipt=run(command,folder/(name+'.log'),300,env,platform,le)
            receipt['test']=name;gates.append(receipt);write(folder/'gates.json',gates)
            print(platform,name,receipt['ok'],flush=True)
            if not receipt['ok']:return 1
        records=[]
        if not args.gates_only:
            for spec in protocol['cases']:
                for arm in protocol['arms']:
                    name=spec['id']+'-'+arm;raw=folder/(name+'.json')
                    receipt=run(prefix+['--script','res://qualification/gcr_granular_events_capture.gd','--','--protocol='+cv(PROTOCOL),'--case='+spec['id'],'--arm='+arm,'--output='+cv(raw)],folder/(name+'.log'),300,env,platform,le)
                    data=read(raw) if raw.exists() else {}
                    actual=data.get('identity',{})
                    bound=all(actual.get(k)==v for k,v in dict(source=head,input_identity=ih,protocol_sha256=sha(PROTOCOL),engine_sha256=engine_hash,native_sha256=native['native_sha256']).items())
                    receipt.update(case=spec['id'],arm=arm,rows=len(data.get('rows',[])),raw_sha256=sha(raw) if raw.exists() else None,identity_ok=bound)
                    receipt['ok']=receipt['ok'] and bound and data.get('ok') is True and receipt['rows']==1800
                    records.append(receipt);write(folder/'campaign.json',records)
                    print(platform,name,receipt['ok'],receipt['rows'],flush=True)
                    if not receipt['ok']:return 1
                    completed+=1
        verify_project(project,inputs);assert native_identity(platform,project)==native
        assert all(sha(ROOT/name)==sha(folder/name)==h for name,h in review_protocols.items())
        write(folder/'review-protocol-inputs.json',review_protocols)
    assert source_inputs()==inputs and not git('diff','--binary','HEAD') and git('rev-parse','HEAD').decode().strip()==head
    write(out/'completion.json',dict(ok=True,source=head,end_source=head,inputs_unchanged=True,gates_only=args.gates_only,completed_captures=completed,complete_registered_population=completed==48,identity_sha256=sha(out/'identity.json')))
    return 0

if __name__=='__main__':raise SystemExit(main())
