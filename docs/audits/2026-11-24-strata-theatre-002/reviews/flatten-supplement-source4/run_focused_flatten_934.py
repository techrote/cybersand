from pathlib import Path
import datetime,hashlib,importlib.util,json,os,re,subprocess,sys,time
ROOT=Path('/tmp/strata2-recovered'); OUT=Path('/tmp/strata2-a-final-review/flatten-supplement-source4')
SOURCE='934cc0c0eef70dad528155e9a92eebe25e2757eb';TREE='0c30ea3eaea61c5091c23b984837f29d7b7c828e'
ENGINE=Path('/workspace/scratch/051e78157ffb/runtime/godot-4.7/Godot_v4.7-stable_linux.x86_64')
PINS={str(ENGINE):'f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75',str(ROOT/'godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so'):'a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7',str(ROOT/'godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so'):'566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(name,value):(OUT/name).write_text(json.dumps(value,indent=2)+'\n')
assert not OUT.exists(),'Preserve original receipts'
OUT.mkdir();sys.path.insert(0,str(ROOT/'tools/ci'));import qualify_strata2_workbench as frozen
identity=frozen.identity(); assert identity['source_commit']==SOURCE and identity['source_tree']==TREE and identity['local_delta']==[]
assert len(identity['source_inputs_sha256'])==1156 and len(identity['source_assets_sha256'])==6
actual={p:sha(p)for p in PINS};assert actual==PINS
version=subprocess.check_output([str(ENGINE),'--version'],text=True).strip();assert version=='4.7.stable.official.5b4e0cb0f'
for name in ['godot/tests/test_workbench_flatten.gd','godot/tests/test_workbench_flatten_owner_failure.gd']:
 assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',SOURCE+':'+name],cwd=ROOT)
report={'schema':'strata2-existing-Flatten-focused-local-supplement-v1','source_commit':SOURCE,'source_tree':TREE,'scope':'Only two existing unchanged fixtures, each author plus separate-process reopen,512²/1worker; official Godot4.7 Linux headless. No storage-fault wrapper, graphical or physical-owner claim.','started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'engine_version':version,'runtime_sha256':actual,'identity_before':identity,'runner_sha256':sha(__file__),'cases':[],'status':'running'}
write('report.json',report)
try:
 for test,marker,phase_variable in [('test_workbench_flatten','FLATTEN_RESULT ','FLATTEN_REOPEN'),('test_workbench_flatten_owner_failure','FLATTEN_OWNER_FAILURE_RESULT ','FLATTEN_OWNER_FAILURE_REOPEN')]:
  author=None
  for phase in ['author','reopen']:
   label=test+'-'+phase; folder=OUT/label;folder.mkdir();data=OUT/(test+'-userdata'); data.mkdir(exist_ok=True)
   env_values={'CYBERSAND_SOURCE_REVISION':SOURCE,'FLATTEN_SIDE':'512','FLATTEN_WORKERS':'1','FLATTEN_REOPEN':'0','FLATTEN_OWNER_FAILURE_REOPEN':'0','FLATTEN_REQUIRE_GRAPHICS':'0','FLATTEN_SCREENSHOTS':'','XDG_DATA_HOME':str(data),'XDG_CACHE_HOME':str(data/'cache'),'XDG_CONFIG_HOME':str(data/'config'),phase_variable:'1'if phase=='reopen'else'0'}
   env=os.environ.copy();env.update(env_values)
   command=[str(ENGINE),'--headless','--path',str(ROOT/'godot'),'--script','res://tests/'+test+'.gd','--max-fps','60']
   case={'label':label,'command':command,'env':env_values,'cwd':str(folder),'phase':phase,'timeout_seconds':600,'status':'running'}; report['cases'].append(case);write('report.json',report)
   started=time.monotonic();case['started_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
   with (folder/'original.log').open('wb')as log:
    process=subprocess.Popen(command,cwd=folder,env=env,stdout=log,stderr=subprocess.STDOUT)
    case['pid']=process.pid
    try:case['process_start_id']=Path('/proc/'+str(process.pid)+'/stat').read_text().split(') ')[1].split()[19]
    except FileNotFoundError:case['process_start_id']=None
    try:code=process.wait(timeout=600)
    except subprocess.TimeoutExpired:
     process.terminate()
     try:process.wait(timeout=10)
     except subprocess.TimeoutExpired:process.kill();process.wait()
     code=process.returncode;case['timeout']=True
   case.update(exit_code=code,elapsed_seconds=time.monotonic()-started,log_sha256=sha(folder/'original.log'))
   text=(folder/'original.log').read_text(errors='replace');found=[line[len(marker):]for line in text.splitlines()if line.startswith(marker)]
   case['script_errors']=re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|Failed to load script|Invalid call).*$',text,re.M)
   if found:
    result=json.loads(found[-1]);(folder/'result.json').write_text(json.dumps(result,indent=2)+'\n');case['result_sha256']=sha(folder/'result.json');case['checks']=result.get('checks');case['failures']=result.get('failures')
   else:result={};case['failures']=['Missing exact completion marker']
   case['status']='passed'if code==0 and not case['script_errors']and result.get('completed')is True and result.get('failures')==[]and result.get('phase')==phase and result.get('pid')==process.pid and result.get('side')==512 and result.get('canonical_bytes')==524288 and result.get('source_identity',{}).get('display')=='headless'else'failed'
   (folder/'process.json').write_text(json.dumps(case,indent=2)+'\n');write('report.json',report)
   print(json.dumps({k:case.get(k)for k in ['label','status','pid','checks','elapsed_seconds','failures']},separators=(',',':')),flush=True)
   assert case['status']=='passed',label+' failed; retain original.log and result.json'
   if phase=='author':author=result
   else:
    assert result['pid']!=author['pid']and result['process_instance']!=author['process_instance']and result['source_identity']==author['source_identity'],'Fresh-process/source identity mismatch'
    if test.endswith('owner_failure'):
     assert result['reconstructed_plane_sha256']==author['expected_plane_sha256']
     for k in ['expected_plane_sha256','saved_baseline_sha256','saved_file_sha256']:assert result[k]==author[k],k
 report['status']='passed'
except Exception as error:
 report['status']='failed';report['error']=repr(error);print(report['error'],flush=True)
finally:
 report['identity_after']=frozen.identity();report['application_identity_unchanged']=report['identity_after']==identity
 report['runtime_sha256_after']={p:sha(p)for p in PINS};report['runtime_unchanged']=report['runtime_sha256_after']==PINS
 if not report['application_identity_unchanged']or not report['runtime_unchanged']:report['status']='failed'
 report['completed_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();write('report.json',report)
print(json.dumps({'status':report['status'],'cases':len(report['cases']),'source_input_count':len(identity['source_inputs_sha256']),'raw_asset_count':len(identity['source_assets_sha256']),'application_identity_unchanged':report['application_identity_unchanged'],'runtime_unchanged':report['runtime_unchanged']},separators=(',',':')),flush=True)
sys.exit(0 if report['status']=='passed' else 1)
