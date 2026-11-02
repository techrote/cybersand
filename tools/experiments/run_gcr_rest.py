"""Acquire the committed GCR-REST-001 population after explicit mechanical gates."""
from concurrent.futures import ThreadPoolExecutor
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
from analyze_gcr_rest import configuration_receipts
ROOT=Path(__file__).resolve().parents[2]
PROTOCOL=ROOT/'docs/audits/gcr-rest-2026-11-02/protocol.json'
def sha(path,canonical=False):
    data=Path(path).read_bytes()
    return hashlib.sha256(data.replace(b'\r\n',b'\n') if canonical else data).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def write(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8',newline='\n')
def linux(path):
    value=Path(path).resolve().as_posix()
    return '/mnt/'+value[0].lower()+value[2:]
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args])
def project_ledger(project):
    ledger={}
    for path in (ROOT/'godot').rglob('*'):
        if path.is_file() and '.godot' not in path.parts and (path.suffix in ['.gd','.tscn','.tres','.gdshader','.gdextension'] or path.name=='project.godot'):
            relative=path.relative_to(ROOT/'godot')
            if sha(path,True)!=sha(project/relative,True):raise RuntimeError('Source/project mismatch '+str(relative))
            ledger[path.relative_to(ROOT).as_posix()]=sha(path,True)
    return ledger
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true');parser.add_argument('--mechanical',type=Path,required=True);parser.add_argument('--native-core',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--godot-windows',type=Path,required=True);parser.add_argument('--godot-linux',required=True)
    parser.add_argument('--wsl-distro',default='Ubuntu-24.04');parser.add_argument('--platform',choices=['both','windows','linux'],default='both')
    args=parser.parse_args()
    if not args.run:parser.error('Execution requires --run')
    if args.output.exists():raise RuntimeError('Never overwrite a retained campaign')
    protocol=read(PROTOCOL)
    if git('show','HEAD:'+PROTOCOL.relative_to(ROOT).as_posix()).replace(b'\r\n',b'\n')!=PROTOCOL.read_bytes().replace(b'\r\n',b'\n'):raise RuntimeError('Protocol must be committed unchanged')
    if protocol['registration']!='GCR-REST-001-2026-11-02' or len(protocol['cases'])!=44:raise RuntimeError('Wrong population')
    if not read(args.mechanical).get('ok') or not read(args.native_core).get('accepted'):raise RuntimeError('Required mechanical/native gates incomplete')
    head=git('rev-parse','HEAD').decode().strip();platforms=['windows','linux'] if args.platform=='both' else [args.platform]
    identity={'source':head,'protocol_sha256':sha(PROTOCOL),'mechanical_sha256':sha(args.mechanical),'native_core_sha256':sha(args.native_core),'platforms':{},'source_binding':'Native/project input hashes before and after; docs-only HEAD changes do not invalidate identical executed code'}
    for platform in platforms:
        project=ROOT/('build/godot' if platform=='windows' else 'build/godot-linux');native=read(ROOT/f'build/compound-runtime-{platform}.json')
        for path,h in native['source_inputs'].items():
            if sha(ROOT/path,True)!=h:raise RuntimeError('Native rebuild required '+path)
        artifact=project/'addons/cybersand_native/bin'/Path(native['artifact']).name
        if sha(artifact)!=native['sha256']:raise RuntimeError('Actual native runtime differs')
        rapier=read(ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json');rapier_file=project/Path(rapier['artifact']).relative_to('godot')
        if sha(rapier_file)!=rapier['sha256']:raise RuntimeError('Actual Rapier runtime differs')
        engine=[str(args.godot_windows)] if platform=='windows' else ['wsl','-d',args.wsl_distro,'--',args.godot_linux]
        if subprocess.check_output(engine+['--version'],text=True).strip()!='4.7.stable.official.5b4e0cb0f':raise RuntimeError('Pinned Godot4.7 required')
        engine_sha=sha(args.godot_windows) if platform=='windows' else subprocess.check_output(['wsl','-d',args.wsl_distro,'--','sha256sum',args.godot_linux],text=True).split()[0]
        identity['platforms'][platform]={'native':native,'rapier_sha256':sha(rapier_file),'engine_sha256':engine_sha,'project':str(project),'project_inputs':project_ledger(project)}
    args.output.mkdir(parents=True);write(args.output/'identity.json',identity)
    env=os.environ.copy();env['GCR_REST_SOURCE']=head
    def lane(platform):
        project=Path(identity['platforms'][platform]['project']);convert=lambda p:str(Path(p).resolve()) if platform=='windows' else linux(p)
        engine=[str(args.godot_windows)] if platform=='windows' else ['wsl','-d',args.wsl_distro,'--','env','GCR_REST_SOURCE='+head,args.godot_linux]
        records=[]
        for case in protocol['cases']:
            name=platform+'-'+case['id'];raw=args.output/(name+'.json');log=args.output/(name+'.log')
            command=engine+['--headless','--path',convert(project),'--script','res://qualification/gcr_rest_capture.gd','--','--protocol='+convert(PROTOCOL),'--case='+case['id'],'--output='+convert(raw)]
            started=time.time()
            with log.open('xb') as stream:
                try:code=subprocess.run(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=protocol['wall_timeout_seconds']+30).returncode
                except subprocess.TimeoutExpired:code=124
            data=read(raw) if raw.exists() else {};text=log.read_text(encoding='utf-8',errors='replace')
            actual=data.get('identity',{});bound=actual.get('source')==head and actual.get('native_sha256')==identity['platforms'][platform]['native']['sha256'] and actual.get('protocol_sha256')==sha(PROTOCOL)
            configuration=configuration_receipts(data,case)
            row={'case':case['id'],'source':head,'exit':code,'elapsed':time.time()-started,'identity_ok':bound,'native_configuration':configuration,'ok':code==0 and data.get('ok',False) and bound and configuration['ok'] and not any(v in text for v in ['ERROR:','SCRIPT ERROR']),
                 'outcome':data.get('outcome'),'log_sha256':sha(log),'raw_sha256':sha(raw) if raw.exists() else None}
            records.append(row);write(args.output/(platform+'-campaign.json'),records);print(name,row['ok'],row['outcome'],flush=True)
            if not row['ok']:return False
        return len(records)==44
    with ThreadPoolExecutor(len(platforms)) as pool:results=list(pool.map(lane,platforms))
    for platform in platforms:
        old=identity['platforms'][platform];project=Path(old['project'])
        if project_ledger(project)!=old['project_inputs']:raise RuntimeError('Project inputs changed during acquisition')
        for path,h in old['native']['source_inputs'].items():
            if sha(ROOT/path,True)!=h:raise RuntimeError('Native code changed during acquisition')
        if sha(project/'addons/cybersand_native/bin'/Path(old['native']['artifact']).name)!=old['native']['sha256']:raise RuntimeError('Runtime changed during acquisition')
    summary={'ok':all(results),'start_source':head,'end_source':git('rev-parse','HEAD').decode().strip(),'executed_code_inputs_unchanged':True,'planned_captures':44*len(platforms),'maximum_registered_captures':88,'identity_sha256':sha(args.output/'identity.json')}
    write(args.output/'completion.json',summary)
    return 0 if summary['ok'] else 1
if __name__=='__main__':raise SystemExit(main())
