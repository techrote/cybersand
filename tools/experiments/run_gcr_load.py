"""Acquire only GCR-LA-001's committed population, after mechanical gates."""
from concurrent.futures import ThreadPoolExecutor
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PROTOCOL=ROOT/'docs/audits/gcr-load-2026-11-02/protocol.json'
def sha(path,canonical=False):
    data=Path(path).read_bytes()
    return hashlib.sha256(data.replace(b'\r\n',b'\n') if canonical else data).hexdigest()
def linux(path):
    path=Path(path).resolve().as_posix()
    return '/mnt/'+path[0].lower()+path[2:]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--mechanical',type=Path,required=True)
    parser.add_argument('--native-core',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if not args.run: parser.error('No runtime execution without --run')
    if args.output.exists(): raise RuntimeError('Never overwrite retained acquisition')
    protocol=json.loads(PROTOCOL.read_text())
    committed=subprocess.check_output(['git','show','HEAD:'+PROTOCOL.relative_to(ROOT).as_posix()],cwd=ROOT)
    if committed.replace(b'\r\n',b'\n')!=PROTOCOL.read_bytes().replace(b'\r\n',b'\n'): raise RuntimeError('Uncommitted registration')
    mechanical=json.loads(args.mechanical.read_text());native=json.loads(args.native_core.read_text())
    if not mechanical.get('ok') or not native.get('accepted'): raise RuntimeError('Required mechanical/native gate incomplete')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    args.output.mkdir(parents=True)
    identity={'source':head,'protocol_sha256':sha(PROTOCOL),'mechanical_sha256':sha(args.mechanical),'native_gate_sha256':sha(args.native_core),'platforms':{}}
    for platform in ['windows','linux']:
        build=json.loads((ROOT/f'build/compound-runtime-{platform}.json').read_text())
        for path,h in build['source_inputs'].items():
            if sha(ROOT/path,True)!=h: raise RuntimeError('Native source mismatch '+path)
        project=ROOT/('build/godot' if platform=='windows' else 'build/godot-linux')
        for folder in [ROOT/'godot']:
            for file in folder.rglob('*'):
                if file.is_file() and '.godot' not in file.parts and file.suffix in ['.gd','.tscn','.tres','.gdshader','.gdextension']:
                    if sha(file,True)!=sha(project/file.relative_to(folder),True): raise RuntimeError('Project mismatch '+str(file))
        artifact=project/'addons/cybersand_native/bin'/Path(build['artifact']).name
        if sha(artifact)!=build['sha256']: raise RuntimeError('Runtime mismatch')
        identity['platforms'][platform]={'native':build,'project':str(project)}
    (args.output/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
    env=os.environ.copy();env['GCR_LA_SOURCE']=head
    def lane(platform):
        project=Path(identity['platforms'][platform]['project'])
        engine=['C:/Godot47/Godot_v4.7-stable_win64_console.exe'] if platform=='windows' else ['wsl','-d','Ubuntu-24.04','--','/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64']
        convert=lambda p:str(Path(p).resolve()) if platform=='windows' else linux(p)
        rows=[]
        for index,case in enumerate(protocol['cases']):
            for arm in (protocol['arms'] if index%2==0 else list(reversed(protocol['arms']))):
                name=f'{platform}-{case["id"]}-{arm}';output=args.output/(name+'.json');log=args.output/(name+'.log')
                command=engine+['--headless','--path',convert(project),'--script','res://qualification/gcr_load_capture.gd','--','--protocol='+convert(PROTOCOL),'--case='+case['id'],'--candidate='+arm,'--output='+convert(output)]
                start=time.time()
                with log.open('xb') as stream:
                    try: code=subprocess.run(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=protocol['wall_timeout_seconds']+30).returncode
                    except subprocess.TimeoutExpired: code=124
                raw=json.loads(output.read_text(encoding='utf-8')) if output.exists() else {}
                record={'case':case['id'],'arm':arm,'exit':code,'ok':code==0 and raw.get('ok',False),'elapsed':time.time()-start,'log_sha256':sha(log),'raw_sha256':sha(output) if output.exists() else None}
                rows.append(record);print(name,record['ok'],flush=True)
                (args.output/(platform+'-campaign.json')).write_text(json.dumps(rows,indent=2)+'\n')
                if not record['ok']: return False
        return len(rows)==protocol['captures_per_platform']
    with ThreadPoolExecutor(2) as pool: results=list(pool.map(lane,['windows','linux']))
    summary={'ok':all(results),'identity_sha256':sha(args.output/'identity.json'),'maximum_captures':68,'source':head}
    (args.output/'completion.json').write_text(json.dumps(summary,indent=2)+'\n')
    return 0 if all(results) else 1
if __name__=='__main__':raise SystemExit(main())
