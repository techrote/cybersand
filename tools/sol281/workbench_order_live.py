"""Preregistered fixed-action ordering on real cuts; no old evidence replacement."""
import argparse,concurrent.futures,gzip,hashlib,json,os,shutil,threading
from contextlib import contextmanager
import workbench_order_reduce as evaluator
from pathlib import Path
import structure_cut as p
import workbench_order_common as w

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);ap.add_argument('--build',required=True);ap.add_argument('--qualification');ap.add_argument('--smoke',action='store_true');a=ap.parse_args()
    assert all(Path(x).name==x for x in [a.run,a.build]);info=w.identity();w.resource();folder=w.OUT/a.run;assert not folder.exists();folder.mkdir()
    buildpath=w.OUT/a.build/'receipt.json';build=json.loads(buildpath.read_text(encoding='utf-8'));assert build['post_source_equality']
    assert info['source_inputs']==build['identity']['source_inputs'] and info['material_inputs']==build['identity']['material_inputs']
    qualification=None
    if not a.smoke:
        assert a.qualification and Path(a.qualification).name==a.qualification
        qualification=evaluator.qualification(w.OUT/a.qualification,info,p.sha(buildpath))
    pinpath=Path('C:/Users/_/.codex/worktrees/sol-structure-cut-20261106/khybersand/build/sol-structure-cut/mass-fix-001/receipt.json');pins=json.loads(pinpath.read_text(encoding='utf-8'));assert pins['post_source_equality']
    copied={n:p.sha(w.ROOT/n) for n in p.git('ls-files','godot').decode().splitlines() if (w.ROOT/n).is_file()}
    receipt=dict(identity=info,matrix=vars(a),qualification=qualification,build_receipt_sha256=p.sha(buildpath),engine_pin_receipt_sha256=p.sha(pinpath),copied_inputs=copied,hosts={},scope='Fixed-action correction/clip vs combined impulse/torque ordering; identical law, fence and physical constants.')
    p.write(folder/'receipt.json',receipt);lock=threading.Lock();reserved=0
    @contextmanager
    def lease(amount):
        nonlocal reserved
        with lock:w.resource(reserved+amount);reserved+=amount
        try:yield
        finally:
            with lock:reserved-=amount;w.resource(reserved)
    def host(platform):
        target=folder/platform;project=target/'godot';commands=[]
        rapier=json.loads((w.ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_text(encoding='utf-8'))
        selected={rapier['artifact'],'godot/addons/cybersand_native/bin/'+p.BINARIES[platform]};omitted={}
        with lease(w.PROJECT_CAP):
            with lock:
                project.mkdir(parents=True)
                for name,digest in copied.items():
                    if '/bin/' in name and name not in selected:omitted[name]=digest;continue
                    dst=project/Path(name).relative_to('godot');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(w.ROOT/name,dst)
                for filename in ['sol_workbench_order_001.json','sol_mass_initialization_002.json']:
                    dst=project/'tests/fixtures'/filename;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(w.ROOT/'native/tests/fixtures'/filename,dst)
            native=build['platforms'][platform];binary=w.ROOT/native['output'];assert native['clean'] and p.sha(binary)==native['sha256'];shutil.copyfile(binary,project/'addons/cybersand_native/bin'/p.BINARIES[platform])
            assert p.sha(w.ROOT/rapier['artifact'])==rapier['sha256']
            for name,digest in rapier['source_inputs'].items():assert p.lfsha(w.ROOT/name)==digest
            engine=p.ENGINES[platform];pin=pins['hosts'][platform]['engine']
            state=dict(commands=commands,engine=pin,compiled_native=native,rapier=rapier,omitted_nonhost_binaries=omitted,effective_inputs={x.relative_to(project).as_posix():p.sha(x) for x in project.rglob('*') if x.is_file()})
            def save():p.write(target/'receipt.json',state)
            def run(name,script=None,env=None):
                forwarded=dict(CYBERSAND_SOURCE_REVISION=info['source_commit'],**(env or {}));argv=[engine,'--headless','--audio-driver','Dummy','--path',str(project) if platform=='windows' else p.wsl(project)]
                argv+=['--editor','--import','--quit'] if script is None else ['--max-fps','120','--script','res://tests/'+script+'.gd']
                if platform=='linux':argv=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in forwarded.items()],*argv]
                row=p.command(name,argv,target,dict(os.environ,**forwarded),timeout=300);commands.append(row);save();return row
            if platform=='windows':assert p.sha(engine.replace('_console.exe','.exe'))==pin['sha256'] and p.sha(engine)==pin['launcher_sha256']
            else:
                c=p.command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',engine],target);commands.append(c);assert c['clean'] and (w.ROOT/c['log']).read_text(encoding='utf-8').split()[0]==pin['sha256']
            assert run('import')['clean'],'Keep failed import; stop before experiment'
            assert sum(x.stat().st_size for x in project.rglob('*') if x.is_file())<=w.PROJECT_CAP,'Imported project exceeds registered cap'
        if a.smoke:
            output=target/'adapter.json';row=run('adapter','test_sol_workbench_order_adapter',dict(SOL_OUTPUT=str(output) if platform=='windows' else p.wsl(output)));assert row['clean']
            d=json.loads(output.read_text(encoding='utf-8'));assert not d['failures'] and len(d['cases'])==60
            row['report']=dict(path=str(output.relative_to(w.ROOT)),sha256=p.sha(output),bytes=output.stat().st_size);row['apparatus']=True;save()
            for script in ['test_sol_contact_order','test_workbench_fleet_session','test_workbench_desktop_interest']:assert run(script,script)['clean']
        for workers in ([1] if a.smoke else [1,4]):
            for repeat in range(1 if a.smoke or workers==4 else 5):
                arms=['correction-first','impulse-first'];arms=arms[repeat%2:]+arms[:repeat%2]
                for structure in ['tree','building']:
                    for surroundings in ['packed_sand','mixed']:
                        for arm in arms:
                            with lease(w.REPORT_RESERVATION):
                                name=f'{structure}-{surroundings}-{arm}-w{workers}-r{repeat}';output=target/(name+'.json')
                                row=run(name,'test_sol_workbench_order',dict(SOL_STRUCTURE=structure,SOL_SURROUNDINGS=surroundings,SOL_ORDER_ARM=arm,SOL_WORKERS=str(workers),SOL_REPEAT=str(repeat),SOL_SMOKE=str(int(a.smoke)),SOL_OUTPUT=str(output) if platform=='windows' else p.wsl(output)));row['report_complete']=False
                                if output.exists():
                                    raw=output.read_bytes();d=json.loads(raw.decode('utf-8'));archive=output.with_suffix('.json.gz');assert not archive.exists() and output.parent.resolve()==target.resolve()
                                    packed=gzip.compress(raw,compresslevel=6,mtime=0);assert gzip.decompress(packed)==raw;archive.write_bytes(packed);assert gzip.decompress(archive.read_bytes())==raw
                                    row['report']=dict(path=str(archive.relative_to(w.ROOT)),sha256=p.sha(archive),bytes=archive.stat().st_size,raw_sha256=hashlib.sha256(raw).hexdigest(),raw_bytes=len(raw),staging_path=str(output.relative_to(w.ROOT)))
                                    output.unlink() # Only newly created, verified losslessly archived staging.
                                    row['report_complete']=not d['failures'] and len(d['steps'])==(12 if a.smoke else 720)
                                save();assert row['clean'] and row['report_complete'],'Keep every failed/incomplete episode; no parameter/threshold changes'
        changes=[]
        for name,digest in state['effective_inputs'].items():
            dst=project/name
            if dst.is_file() and p.sha(dst)==digest:continue
            original=w.ROOT/'godot'/name
            if name.endswith('.import') and original.is_file() and dst.is_file() and dst.read_bytes().replace(b'\r\n',b'\n')==original.read_bytes().replace(b'\r\n',b'\n'):continue
            changes.append(name)
        assert sum(x.stat().st_size for x in project.rglob('*') if x.is_file())<=w.PROJECT_CAP
        state['post_inventory_unexpected']=changes;save();assert not changes
        return platform,state
    errors=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures=[pool.submit(host,name) for name in ['windows','linux']]
        for future in concurrent.futures.as_completed(futures):
            try:name,row=future.result();receipt['hosts'][name]=row
            except Exception as e:errors.append(repr(e))
            p.write(folder/'receipt.json',receipt)
    assert info==w.identity() and copied=={n:p.sha(w.ROOT/n) for n in copied}
    receipt['post_source_equality']=True;receipt['errors']=errors;receipt['resource']=w.resource();p.write(folder/'receipt.json',receipt)
    return int(bool(errors))
if __name__=='__main__':raise SystemExit(main())
