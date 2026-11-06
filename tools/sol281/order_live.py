"""Execute registered fresh cut structures with authenticated parent native binaries."""
import argparse,json,os,shutil
from pathlib import Path
import order_common as o
import structure_cut as p

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args();assert Path(a.run).name==a.run
    info=o.identity();o.resource();folder=o.OUT/a.run;assert not folder.exists();folder.mkdir()
    buildpath=o.PARENT/'build/sol-structure-cut/runtimes-001/receipt.json';build=json.loads(buildpath.read_text(encoding='utf-8'));assert build['post_source_equality']
    assert info['source_inputs']==build['identity']['source_inputs'] and info['material_inputs']==build['identity']['material_inputs']
    parentpath,parent=o.parent_receipt();copied={n:o.sha(o.ROOT/n) for n in p.git('ls-files','godot').decode().splitlines() if (o.ROOT/n).is_file()}
    reg=o.ROOT/'native/tests/fixtures/sol_contact_order_live_001.json'
    receipt=dict(identity=info,registration_sha256=o.sha(reg),parent_build_receipt_sha256=o.sha(buildpath),parent_execution_receipt_sha256=o.sha(parentpath),copied_inputs=copied,hosts={},scope='Source-local SOL; actual hosts, fresh sessions, diagnostic overhead included. Not original CPU gate or synchronized clearance.')
    def save():p.write(folder/'receipt.json',receipt)
    save()
    for host in ['windows','linux']:
        o.resource();target=folder/host;project=target/'godot';project.mkdir(parents=True);rows=[]
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
        for test in ['test_solid_contact_response','test_solid_contact_fences']:
            assert run(test,test)['clean'],'Retain failed focused gate; stop'
        for workers in [1,4]:
            for structure in ['tree','building']:
                for surroundings,arm in [('empty','off'),('packed_sand','off'),('packed_sand','pre'),('packed_sand','post')]:
                    o.resource();name=f'{structure}-{surroundings}-{arm}-w{workers}';output=target/(name+'.json')
                    row=run(name,'test_sol_structure_cut',dict(SOL_ORDER_PROFILE='1',SOL_CONTACT_ORDER='post' if arm=='post' else 'pre',SOL_STRUCTURE=structure,SOL_SURROUNDINGS=surroundings,SOL_SAND_RESPONSE=str(int(arm!='off')),SOL_WORKERS=str(workers),SOL_OUTPUT=str(output) if host=='windows' else p.wsl(output),SOL_STAGE_TRACE='1',SOL_COMPACT_EVIDENCE='1'))
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
    receipt['post_source_equality']=True;receipt['resource']=o.resource();save()
    return int(not all(c['clean'] and c.get('report_complete',True) for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':raise SystemExit(main())
