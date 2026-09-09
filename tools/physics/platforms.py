"""Reduce actual browser and desktop async observations alongside captured identities."""
from pathlib import Path
import json,shutil,hashlib,statistics
import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('raw',type=Path)
parser.add_argument('output',type=Path)
args=parser.parse_args()
raw=args.raw.resolve()
out=args.output.resolve()
out.mkdir(parents=True,exist_ok=True)
for name,target in [('runtime-checkpoint/manifest.json','runtime-manifest.json'),('desktop-async-final/provenance/manifest.json','async-manifest.json'),('browser-regressions.json','browser-regressions.json')]:
    shutil.copyfile(raw/name,out/target)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
results=[]
for profile in ['compat','threaded']:
    path=raw/f'browser-{profile}/browser-result.json';d=json.loads(path.read_text())
    for r in d['result']['results']:
        results.append({'profile':'real-Web-'+profile,'user_agent':d['userAgent'],'cross_origin_isolated':d['isolated'],
            'raw_sha256':sha(path),'spec':r['spec'],'ok':r['ok'],'hash':r['final']['hash'],
            **{k:r[k] for k in ['completed_ticks','peak_depth','final_depth','late_creep','floor_contact_tick','max_sample_age','intermediate_caps','final_caps','unresolved']},
            'overflow':r['final']['overflow'],'tick_us':r['tick_us'],'coupling_us':r['coupling_us']})
for path in sorted((raw/'desktop-async-final').glob('async-s*.json')):
    d=json.loads(path.read_text());trace=d['worker_trace'];times=sorted(trace[13::12])
    results.append({'profile':'desktop-asynchronous','raw_sha256':sha(path),'hash':d['final']['hash'],
        **{k:d[k] for k in ['seed','ok','completed_ticks','rapier_ticks','peak_depth','floor_contact_tick','age_histogram','worker_overruns']},
        'overflow':d['final']['overflow'],'worker_tick_ms':[statistics.median(times),times[len(times)*95//100],max(times)],
        'rows':d['rows']})
(out/'platform-results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
execution={'desktop_async_command':['C:/Godot47/Godot_v4.7-stable_win64_console.exe','--headless','--path','C:/kybersand/source/godot','--script','res://tests/test_physics_async.gd','--',str(raw/'desktop-async-final'),'1800','5'],
 'source_artifact_identity':'runtime-manifest.json','async_source_artifact_identity':'async-manifest.json','deadline_seconds_per_seed':90,
 'browser_urls':['http://127.0.0.1:8091/?test=1&physics=1','http://127.0.0.1:8092/?test=1&physics=1'],
 'collector_commands':[['python','tools/physics/serve.py','--directory','C:/kybersand/source/build/'+p,'--port',str(port),'--output',str(raw/o)] for p,port,o in [('web',8091,'browser-compat'),('web-threaded',8092,'browser-threaded')]],
 'host_load':'Concurrent deterministic offline fixture processes; timings are not production performance acceptance.',
 'invalid_browser_attempt':{'url':'http://127.0.0.1:8089/?test=1&physics=1','result':'invalid: release stripped assert-contained fixture writes; zero constructed walls; empty-world results excluded','correction':'explicit call outside assert, construction/completion/control checks, re-export and rerun both profiles'},
 'excluded_series':['godot-controls','godot-controls-v2','godot-controls-v3','godot-smoke','godot-smoke-v3','native-smoke']}
(out/'platform-execution.json').write_text(json.dumps(execution,indent=2),encoding='utf-8')
print('Curated',len(results),'actual platform runs')
