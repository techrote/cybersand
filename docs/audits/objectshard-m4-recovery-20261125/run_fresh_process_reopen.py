from pathlib import Path
import hashlib,json,os,re,subprocess,time

base=Path(__file__).resolve().parent
custody=json.loads((base/'runtime-custody.json').read_text())
data=base/'fresh-process-user-data'
assert not data.exists(), 'Fresh user directory must not preexist'
data.mkdir()
output=base/'fresh-process'
output.mkdir()
engine=custody['engine']['path']
command=[engine,'--headless','--path',str(base/'godot'),'--script','res://tests/test_workbench_canvas.gd']
environment=dict(os.environ,XDG_DATA_HOME=str(data),APPDATA=str(data),LOCALAPPDATA=str(data),
                 CYBERSAND_WORKBENCH_TEST_NAME='m4-recovery-fresh-process',
                 CYBERSAND_SOURCE_REVISION=custody['application_source'])
environment.pop('CYBERSAND_WORKBENCH_REOPEN',None)
result={'schema':'objectshard-m4-ordinary-authored-fresh-process-v1','status':'running',
        'application_source':custody['application_source'],'local_equivalent':custody['local_equivalent'],
        'source_tree':custody['source_tree'],'native_build_source':custody['native_build_source'],
        'runtime_custody_sha256':hashlib.sha256((base/'runtime-custody.json').read_bytes()).hexdigest(),
        'engine':custody['engine'],'runtime':custody['runtime'],'processes':[],
        'scope':'Existing frozen ordinary test_workbench_canvas author plus its separate-process reopen branch; Linux headless only; authored state, not evolved moving-body serialization'}
def persist(): (output/'result.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
def files(): return {str(p.relative_to(data)):hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in data.rglob('setup-m4-recovery-fresh-process.json')}
persist()
for phase in ('author','reopen'):
    if phase=='reopen': environment['CYBERSAND_WORKBENCH_REOPEN']='1'
    log=output/(phase+'.log')
    start=time.monotonic()
    with log.open('wb') as stream:
        process=subprocess.Popen(command,cwd=base,env=environment,stdout=stream,stderr=subprocess.STDOUT)
        try: code=process.wait(timeout=1200)
        except subprocess.TimeoutExpired:
            process.terminate()
            try: process.wait(timeout=10)
            except subprocess.TimeoutExpired: process.kill();process.wait()
            code=124
    raw=log.read_bytes();text=raw.decode('utf-8',errors='replace')
    footers=re.findall(r'^WORKBENCH_CANVAS (\d+) checks, (\d+) failures$',text,re.MULTILINE)
    readbacks=[json.loads(line.split(' ',1)[1]) for line in text.splitlines() if line.startswith('WORKBENCH_CANVAS_READBACK ')]
    row={'phase':phase,'pid':process.pid,'command':command,'elapsed_seconds':time.monotonic()-start,
         'returncode':code,'natural_completion':code!=124,'log':log.name,'log_sha256':hashlib.sha256(raw).hexdigest(),
         'checks':int(footers[0][0]) if len(footers)==1 else None,
         'failures':int(footers[0][1]) if len(footers)==1 else None,'native_readbacks':readbacks,
         'saved_files':files(),'reopen_environment':environment.get('CYBERSAND_WORKBENCH_REOPEN')}
    result['processes'].append(row)
    row['passed']=code==0 and len(footers)==1 and row['checks']>0 and row['failures']==0 and len(readbacks)==1 and bool(row['saved_files']) and 'SCRIPT ERROR:' not in text
    persist()
    print(json.dumps({k:row[k] for k in ('phase','pid','elapsed_seconds','returncode','checks','failures','passed')}),flush=True)
    if not row['passed']: result['status']='failed';persist();raise SystemExit(1)
result['separate_processes']=result['processes'][0]['pid']!=result['processes'][1]['pid']
result['saved_bytes_unchanged']=result['processes'][0]['saved_files']==result['processes'][1]['saved_files']
result['source_bytes_unchanged']=all(hashlib.sha256((base/p).read_bytes()).hexdigest()==digest for p,digest in custody['application_files'].items())
result['runner_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
result['status']='passed' if result['separate_processes'] and result['saved_bytes_unchanged'] and result['source_bytes_unchanged'] else 'failed'
persist()
print(json.dumps({'status':result['status'],'separate_processes':result['separate_processes'],'saved_bytes_unchanged':result['saved_bytes_unchanged'],'source_bytes_unchanged':result['source_bytes_unchanged']}),flush=True)
raise SystemExit(0 if result['status']=='passed' else 1)
