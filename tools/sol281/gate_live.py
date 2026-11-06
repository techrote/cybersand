"""Execute SOL-BEARING-GATE-001 fresh cut structures with authenticated parent native binaries."""
import argparse,json,os,shutil
from pathlib import Path
import order_common as o
import structure_cut as p

OUT=o.ROOT/'build/sol-bearing-gate'
REGISTRATION=o.ROOT/'native/tests/fixtures/sol_bearing_gate_001.json'
CAP=1536*1024**2
RESERVE=5*1024**3
ARMS=[('off','pre'),('pre','pre'),('post','post')]

def resource():
    OUT.mkdir(parents=True,exist_ok=True);used=sum(f.stat().st_size for f in OUT.rglob('*') if f.is_file());free=shutil.disk_usage(OUT).free
    assert used<=CAP and free>=RESERVE,'Resource budget exhausted; preserve previous evidence'
    return dict(bytes=used,free=free,cap=CAP,reserve=RESERVE)

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);ap.add_argument('--smoke',action='store_true');a=ap.parse_args();assert Path(a.run).name==a.run
    info=o.identity();resource();folder=OUT/a.run;assert not folder.exists();folder.mkdir()
    buildpath=o.PARENT/'build/sol-structure-cut/runtimes-001/receipt.json';build=json.loads(buildpath.read_text(encoding='utf-8'));assert build['post_source_equality']
    assert info['source_inputs']==build['identity']['source_inputs'] and info['material_inputs']==build['identity']['material_inputs']
    parentpath,parent=o.parent_receipt();copied={n:o.sha(o.ROOT/n) for n in p.git('ls-files','godot').decode().splitlines() if (o.ROOT/n).is_file()}
    receipt=dict(identity=info,registration_sha256=o.sha(REGISTRATION),smoke=a.smoke,parent_build_receipt_sha256=o.sha(buildpath),parent_execution_receipt_sha256=o.sha(parentpath),copied_inputs=copied,hosts={},
        scope='Observation-only bearing-gate diagnostic; actual hosts, fresh sessions, native telemetry on. Not a settling candidate, CPU gate or synchronized clearance.')
    def save():p.write(folder/'receipt.json',receipt)
    save()
    for host in ['windows','linux']:
        resource();target=folder/host;project=target/'godot';project.mkdir(parents=True);rows=[]
        rapier=json.loads((o.ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{host}.json').read_text(encoding='utf-8'))
        native=build['platforms'][host];nativepath=o.PARENT/native['output'];assert native['clean'] and o.sha(nativepath)==native['sha256']
        selected={rapier['artifact'],'godot/addons/cybersand_native/bin/'+p.BINARIES[host]};omitted={}
        for name,digest in copied.items():
            if '/bin/' in name and name not in selected:omitted[name]=digest;continue
            dst=project/Path(name).relative_to('godot');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(o.ROOT/name,dst)
        shutil.copyfile(nativepath,project/'addons/cybersand_native/bin'/p.BINARIES[host])
        assert o.sha(o.ROOT/rapier['artifact'])==rapier['sha256']
        for name,digest in rapier['source_inputs'].items():assert p.lfsha(o.ROOT/name)==digest
        pin=parent['hosts'][host]['engine'];engine=p.ENGINES[host]
        if host=='windows':assert o.sha(engine.replace('_console.exe','.exe'))==pin['sha256'] and o.sha(engine)==pin['launcher_sha256']
        else:
            r=p.command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',engine],target);rows.append(r);assert r['clean'] and (o.ROOT/r['log']).read_text(encoding='utf-8').split()[0]==pin['sha256']
        state=dict(commands=rows,engine=pin,compiled_native=native,compiled_native_origin=str(nativepath),rapier=rapier,omitted_nonhost_binaries=omitted,effective_inputs={x.relative_to(project).as_posix():o.sha(x) for x in project.rglob('*') if x.is_file()});receipt['hosts'][host]=state;save()
        def run(name,script=None,env=None,timeout=300):
            environment=dict(CYBERSAND_SOURCE_REVISION=info['source_commit'],**(env or {}));argv=[engine,'--headless','--audio-driver','Dummy','--path',str(project) if host=='windows' else p.wsl(project)]
            argv+=['--editor','--import','--quit'] if script is None else ['--max-fps','120','--script','res://tests/'+script+'.gd']
            if host=='linux':argv=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in environment.items()],*argv]
            row=p.command(name,argv,target,dict(os.environ,**environment),timeout);rows.append(row);save();return row
        imported=run('import');assert imported['clean'],'Retain failed import; stop'
        for test in ['test_solid_contact_response','test_solid_contact_fences','test_sol_contact_order']:
            assert run(test,test)['clean'],'Retain failed focused gate; stop'
        cases=[(1,'tree','post','post')] if a.smoke else [(w,s,arm,order) for w in [1,4] for s in ['tree','building'] for arm,order in ARMS]
        for workers,structure,arm,order in cases:
            resource();name=f'{structure}-packed_sand-{arm}-w{workers}';output=target/(name+'.json')
            row=run(name,'test_sol_structure_cut',dict(SOL_ORDER_PROFILE='1',SOL_CONTACT_ORDER=order,SOL_STRUCTURE=structure,SOL_SURROUNDINGS='packed_sand',SOL_SAND_RESPONSE=str(int(arm!='off')),SOL_WORKERS=str(workers),
                SOL_OUTPUT=str(output) if host=='windows' else p.wsl(output),SOL_STAGE_TRACE='1',SOL_COMPACT_EVIDENCE='1',SOL_BEARING_DIAGNOSTIC='1'))
            if output.exists():
                d=json.loads(output.read_text(encoding='utf-8'));row['report']=dict(path=str(output.relative_to(o.ROOT)),sha256=o.sha(output),bytes=output.stat().st_size);row['report_complete']=not d['failures'] and len(d['steps'])==720
            else:row['report_complete']=False
            save()
        changed=[]
        for name,digest in state['effective_inputs'].items():
            dst=project/name
            if dst.is_file() and o.sha(dst)==digest:continue
            src=o.ROOT/'godot'/name
            if name.endswith('.import') and src.is_file() and dst.is_file() and dst.read_bytes().replace(b'\r\n',b'\n')==src.read_bytes().replace(b'\r\n',b'\n'):continue
            changed.append(name)
        state['post_inventory_unexpected']=changed;save();assert not changed
    assert info==o.identity() and copied=={n:o.sha(o.ROOT/n) for n in copied}
    receipt['post_source_equality']=True;receipt['resource']=resource();save()
    return int(not all(c['clean'] and c.get('report_complete',True) for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':raise SystemExit(main())
