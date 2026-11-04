"""Source-bound authored compound gates and the preregistered C/E/S population."""
import argparse,concurrent.futures,hashlib,os,shutil,subprocess
from pathlib import Path
from run_gcr_causal import run
from run_gcr_creep import ROOT,git,read,write,sha,source_inputs,verify_project,native_identity,linux
from run_gcr_powder_review import GATES as RETAINED

PROTOCOL=ROOT/'docs/audits/gcr-authored-2026-11-04/protocol.json'
GATES=list(dict.fromkeys(['test_gcr_flyer_authoring','test_gcr_authored_compound_native','test_gcr_scooper_body','test_gcr_scooper_release',
    'test_gcr_nocatch_receipt','test_gcr_scooper_receipt','test_gcr_scooper_entry_side',
    'test_gcr_scooper_leak_capture','test_gcr_scooper_ejection_replay']+RETAINED+[
    'test_gcr_protocol','test_gcr_async','test_gcr_admission','test_rem002_body_granular','test_rem003_player_granular','test_gcr_envelope',
    'test_gcr_detachment','test_solid_detachment_displacement','test_solid_detachment_compound_response']))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--gates-only',action='store_true')
    parser.add_argument('--captures-only',action='store_true')
    args=parser.parse_args();out=args.output.resolve()
    if args.gates_only and args.captures_only: raise RuntimeError('Select only one scope')
    if out.exists() or git('diff','--binary','HEAD'): raise RuntimeError('Fresh output and committed source required')
    source=git('rev-parse','HEAD').decode().strip();inputs=source_inputs()
    ih=hashlib.sha256(__import__('json').dumps(inputs,sort_keys=True).encode()).hexdigest()
    protocol=read(PROTOCOL)
    assert protocol['registration']=='GCR-AUTHORED-001' and len(protocol['cases'])==8
    assert len(protocol['responses'])==3 and all(0<c['ticks']<=900 for c in protocol['cases'])
    out.mkdir(parents=True)
    write(out/'identity.json',{'source':source,'tree':git('rev-parse','HEAD^{tree}').decode().strip(),
          'inputs':inputs,'inputs_hash':ih,'protocol_sha256':sha(PROTOCOL),'gates':GATES})
    def host(platform):
        folder=out/platform;folder.mkdir();project=folder/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','*.uid'))
        protocols=['docs/audits/gcr-load-2026-11-02/protocol.json','docs/audits/gcr-rest-2026-11-02/protocol.json',
                   'docs/audits/gcr001-2026-11-01/protocol.json',str(PROTOCOL.relative_to(ROOT)).replace('\\','/'),
                   'docs/audits/gcr-carry-2026-11-04/protocol.json']
        for name in protocols:
            dest=folder/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dest)
            assert sha(dest)==sha(ROOT/name)
        verify_project(project,inputs);native=native_identity(platform,project)
        le='/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64'
        env=dict(os.environ,CYBERSAND_SOURCE_REVISION=source,GCR_SCOOPER_INPUTS=ih)
        engine=['C:/Godot47/Godot_v4.7-stable_win64_console.exe'] if platform=='windows' else ['wsl','-d','Ubuntu-24.04','--','env',
             'CYBERSAND_SOURCE_REVISION='+source,'GCR_SCOOPER_INPUTS='+ih,le]
        version=subprocess.check_output(engine+['--version'],text=True,timeout=60).strip()
        assert version=='4.7.stable.official.5b4e0cb0f'
        engine_hash=sha(Path('C:/Godot47/Godot_v4.7-stable_win64.exe')) if platform=='windows' else subprocess.check_output(['wsl','-d','Ubuntu-24.04','--','sha256sum',le],text=True,timeout=60).split()[0]
        write(folder/'runtime.json',dict(native,engine_version=version,engine_sha256=engine_hash))
        cv=lambda p:str(Path(p).resolve()) if platform=='windows' else linux(p)
        prefix=engine+['--headless','--audio-driver','Dummy','--path',cv(project)]
        records=[]
        for test in ['import']+([] if args.captures_only else GATES):
            command=prefix+(['--editor','--quit'] if test=='import' else ['--script','res://tests/'+test+'.gd'])
            if test=='test_gcr_envelope': command+=['--','--protocol='+cv(folder/protocols[2])]
            if test=='test_gcr_scooper_leak_capture': command+=['--','--protocol='+cv(folder/protocols[4])]
            receipt=run(command,folder/(test+'.log'),300,env,platform,le)
            receipt['test']=test;records.append(receipt);write(folder/'gates.json',records)
            print(platform,test,receipt['ok'],flush=True)
            if not receipt['ok']: return {'platform':platform,'ok':False,'failed':test}
        captures=[]
        if not args.gates_only:
            for spec in protocol['cases']:
                for response in protocol['responses']:
                    name=spec['id']+'-'+response;raw=folder/(name+'.json')
                    command=prefix+['--script','res://qualification/gcr_scooper_capture.gd','--','--protocol='+cv(folder/protocols[3]),
                         '--case='+spec['id'],'--response='+response,'--output='+cv(raw)]
                    receipt=run(command,folder/(name+'.log'),300,env,platform,le)
                    data=read(raw) if raw.exists() else {}
                    identity=data.get('identity',{})
                    matched=all(identity.get(k)==v for k,v in {'source':source,'inputs':ih,'protocol_sha256':sha(PROTOCOL),
                              'native_sha256':native['native_sha256'],'physics_backend':'Rapier2D'}.items())
                    receipt.update(case=spec['id'],response=response,rows=len(data.get('rows',[])),identity_ok=matched,
                                   raw_sha256=sha(raw) if raw.exists() else None)
                    receipt['ok']=receipt['ok'] and matched and data.get('ok') is True and receipt['rows']==spec['ticks']
                    captures.append(receipt);write(folder/'campaign.json',captures)
                    print(platform,name,receipt['ok'],receipt['rows'],flush=True)
                    # Each capture is a fresh owner/process. Preserve a negative
                    # control or safety refusal and still acquire the other arms.
        verify_project(project,inputs);assert native_identity(platform,project)==native
        assert all(sha(ROOT/name)==sha(folder/name) for name in protocols)
        return {'platform':platform,'ok':all(r['ok'] for r in captures),'suites':len(records)-1,'imports':1,'captures':len(captures),
                'gates_sha256':sha(folder/'gates.json'),'campaign_sha256':sha(folder/'campaign.json') if captures else None}
    with concurrent.futures.ThreadPoolExecutor(2) as pool: results=list(pool.map(host,['windows','linux']))
    unchanged=inputs==source_inputs() and not git('diff','--binary','HEAD') and source==git('rev-parse','HEAD').decode().strip()
    write(out/'completion.json',{'source':source,'ok':all(r['ok'] for r in results) and unchanged,'inputs_unchanged':unchanged,
          'gates_only':args.gates_only,'captures_only':args.captures_only,'results':results})
    return 0 if all(r['ok'] for r in results) and unchanged else 1

if __name__=='__main__': raise SystemExit(main())
