"""Run Godot fixtures in a source-matched copy while an editor owns shadow DLLs."""
import argparse,json,shutil,subprocess
from pathlib import Path
from run import ROOT,identity,sha

p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args()
out=a.output.resolve();project=out/'godot'
if project.exists():raise ValueError('Choose a fresh evidence directory')
out.mkdir(parents=True,exist_ok=True)
shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','~*'))
inputs={str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()}
manifest=identity([ROOT/'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'])
manifest['isolated_inputs']=inputs
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
godot='C:/Godot47/Godot_v4.7-stable_win64_console.exe'
commands=[('import',[godot,'--headless','--editor','--path',str(project),'--import'])]
commands += [(p.stem,[godot,'--headless','--path',str(project),'--script','res://tests/'+p.name]) for p in sorted((project/'tests').glob('test_*.gd'))]
results=[]
for name,cmd in commands:
    r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=240)
    text=r.stdout+r.stderr
    (out/(name+'.log')).write_text(text,encoding='utf-8')
    ok=r.returncode==0 and 'SCRIPT ERROR:' not in text and 'ERROR:' not in text
    results.append(dict(name=name,command=cmd,exit=r.returncode,passed=ok,timeout_seconds=240))
    (out/'results.json').write_text(json.dumps(results,indent=2))
    print(name,ok,flush=True)
    if not ok:raise RuntimeError(name+' failed; evidence retained')
print(len(results)-1,'Godot fixtures passed in isolated project')
