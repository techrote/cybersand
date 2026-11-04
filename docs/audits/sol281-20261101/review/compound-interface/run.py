from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,os,re,subprocess,time
root=Path('/workspace/scratch/59ce0c87fdea/sol281-interface-isolated')
out=Path('/workspace/scratch/59ce0c87fdea/evidence/independent-compound-interface')
engine=Path('/tmp/cybersand-r-engine/Godot_v4.7-stable_linux.x86_64')
env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
for key,subdir in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
 directory=out/'host-state'/subdir;directory.mkdir(parents=True,exist_ok=True);env[key]=str(directory)
receipt={'schema':'sol281-independent-compound-interface-host-v1','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip(),'source_tree':subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=root).decode().strip(),'recorded_utc':datetime.now(timezone.utc).isoformat(),'platform':'Linux','scope':'isolated shared bridge against current-main native R and pinned Rapier; no independent Windows claim','engine':{'path':str(engine),'sha256':hashlib.sha256(engine.read_bytes()).hexdigest(),'version':subprocess.check_output([str(engine),'--version'],env=env).decode().strip()},'runtime_inputs':json.loads((out/'runtime-inputs.json').read_text()),'records':[]}
for name,flags,bound in [('import',['--editor','--import','--quit'],150),('compound-response',['--script','res://tests/test_solid_detachment_compound_response.gd'],90)]:
 command=[str(engine),'--headless','--path',str(root/'godot'),*flags]; log=out/(name+'.log');start=time.monotonic()
 with log.open('wb') as stream:
  try:
   result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,env=env,cwd=root,timeout=bound);code=result.returncode;timed_out=False
  except subprocess.TimeoutExpired:
   code=None;timed_out=True
 text=log.read_text(errors='replace');fail=code!=0 or 'SCRIPT ERROR:' in text or 'ERROR:' in text
 record={'name':name,'command':command,'returncode':code,'timed_out':timed_out,'elapsed_seconds':time.monotonic()-start,'log':log.name,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'status':'failed' if fail else 'passed'}
 if name=='compound-response':
  matches=re.findall(r'^SOL281_COMPOUND_RESPONSE (\{.+\})$',text,re.M)
  value=json.loads(matches[0]) if len(matches)==1 else None
  record['readback']=value
  if value!={'checks':33,'failures':[],'platform':'Linux'}:record['status']='failed'
 receipt['records'].append(record);(out/'host-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps(record),flush=True)
 if record['status']!='passed':raise SystemExit(1)
receipt['status']='passed';(out/'host-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
