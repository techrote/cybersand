#!/usr/bin/env python3
"""Bounded three-pair execution of already source-frozen native matrices."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

parser=argparse.ArgumentParser()
parser.add_argument('--control',type=Path,required=True)
parser.add_argument('--candidate',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools/objectshard'))
from run_benchmarks import check_budgets

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value): path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
def utc(): return datetime.now(timezone.utc).isoformat()

args.output.mkdir(parents=True,exist_ok=False)
sources={}
for name,path in [('control',args.control),('candidate',args.candidate)]:
    summary=json.loads(path.read_text())
    run=Path(summary['run_directory'])
    executable=run/'benchmark_object_shard'
    if digest(executable)!=summary['binary_sha256']: raise RuntimeError('binary digest changed')
    sources[name]={'summary':summary,'summary_sha256':digest(path),'executable':str(executable),
        'budget':str(run/'source/tools/objectshard/native_budgets.json'),
        'benchmark_source_sha256':digest(run/'source/native/tests/benchmark_object_shard.cpp')}
budget=json.loads(Path(sources['control']['budget']).read_text())
if budget!=json.loads(Path(sources['candidate']['budget']).read_text()): raise RuntimeError('budgets differ')
if sources['control']['benchmark_source_sha256']!=sources['candidate']['benchmark_source_sha256']:
    raise RuntimeError('benchmark fixtures differ')
order=['control','candidate','candidate','control','control','candidate']
write(args.output/'plan.json',{'schema':1,'registered_utc':utc(),'order':order,'sources':sources,
    'ticks':480,'repetitions':3,'allowed_cpus':sorted(os.sched_getaffinity(0)),
    'method':'Three alternating paired full matrices, one process at a time, unchanged budgets. Shared host, no claimed CPU exclusivity. No repeats chosen from outcomes.',
    'scope':'Native costs with synthetic poses/receipts only; no actual Rapier or presentation.'})
results=[]
for index,name in enumerate(order):
    executable=Path(sources[name]['executable'])
    if digest(executable)!=sources[name]['summary']['binary_sha256']: raise RuntimeError('binary changed')
    command=[str(executable),'--ticks','480','--repetitions','3']
    started=time.monotonic();start_utc=utc();load_before=os.getloadavg()
    process=subprocess.run(command,capture_output=True,text=True,timeout=240,check=False)
    elapsed=time.monotonic()-started
    stem=f'{index+1:02d}-{name}'
    (args.output/(stem+'.stdout')).write_text(process.stdout)
    (args.output/(stem+'.stderr')).write_text(process.stderr)
    record={'index':index+1,'cohort':name,'command':command,'started_utc':start_utc,
        'elapsed_seconds':elapsed,'returncode':process.returncode,'load_before':load_before,
        'load_after':os.getloadavg(),'binary_sha256':digest(executable)}
    if process.returncode==0:
        report=json.loads(process.stdout)
        write(args.output/(stem+'.json'),report)
        record.update(checks=report['checks'],failures=report['failures'],budget_qualification=check_budgets(report,budget))
    results.append(record)
    write(args.output/'runs.json',results)
    print(json.dumps(record),flush=True)
write(args.output/'completion.json',{'completed_utc':utc(),'runs':len(results),
    'all_functional_passed':all(r.get('failures')==0 for r in results),
    'all_budget_passed':all(r.get('budget_qualification',{}).get('status')=='passed' for r in results)})
