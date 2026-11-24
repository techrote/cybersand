#!/usr/bin/env python3
"""Independent retained-data audit of the negative native zero-carry screen."""
import argparse
import hashlib
import importlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--workspace-root',type=Path,default=Path('/workspace/scratch/0b2a9bdf7883'))
p.add_argument('--output',type=Path)
args=p.parse_args();base=args.workspace_root.resolve()
repo=base/'cybersand-native';folder=repo/'build/pubpres-final/zero-carry'
source='825b9f63d219bc865e347d2ae86e4d97919b76fc'
control='3e027cdb71ec97a6719fbd3580f552d500349075'
output=args.output.resolve() if args.output else base/'evidence-c/native-zero-carry-independent-peer.json'


def need(ok,message):
    if not ok:raise ValueError(message)


def sha(value):return hashlib.sha256(value).hexdigest()


def digest(path):
    with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def committed(ref,name):return subprocess.check_output(['git','-C',str(repo),'show',ref+':'+name])


def verify_inputs(mapping,ref,overlays=None):
    overlays=overlays or {}
    for name,expected in mapping.items():
        raw=committed(source if name in overlays else ref,name)
        need(sha(raw)==expected,'Committed source closure differs: '+ref+':'+name)
        need(name not in overlays or overlays[name]==expected,'Overlay declaration differs')
    return {'source':ref,'files':len(mapping),'overlay_sha256':overlays,'complete':True}


need(not output.exists(),'Preserve original independent audit')
receipts=json.loads((folder/'timing-receipts.json').read_bytes())
original=json.loads((folder/'timing-reduction.json').read_bytes())
manifest=receipts['manifest']
need(manifest==json.loads((folder/'timing-manifest.json').read_bytes()),'Original run and embedded manifests differ')
reader_files=['native_abba.py','native_empty_derived.py','native_mask_applicability.py','native_zero_carry.py']
with tempfile.TemporaryDirectory(prefix='pubpres-zero-reader-',dir=base/'evidence-c') as temporary:
    temp=Path(temporary);readers={}
    for name in reader_files:
        raw=committed(source,'tools/pubpres_final/'+name)
        (temp/name).write_bytes(raw);readers[name]=sha(raw)
    sys.path.insert(0,str(temp));reader=importlib.import_module('native_zero_carry')
    reconstructed=reader.reduce_receipts(receipts)
    need(reconstructed==original,'Complete retained registered reduction differs')
need(sha(committed(source,'tools/pubpres_final/run_native_zero_carry.py'))==manifest['runner_source_sha256']
     ==sha(receipts['runner_source'].encode()),'Original executed runner differs from825 source')
builds=[]
for role,build in manifest['builds'].items():
    expected=control if role=='C' else source
    need(build['source_commit']==expected and subprocess.check_output(['git','-C',str(repo),'rev-parse',expected+'^{tree}'],text=True).strip()==build['source_tree'],
         'Exact source/tree role differs')
    closure=verify_inputs(build['source_inputs_sha256'],expected)
    need(closure['files']==82 and digest(build['binary_path'])==build['binary_sha256']
         and digest(build['compiler']['path'])==build['compiler']['sha256'],'Actual native/compiler bytes differ')
    command=build['arguments']
    need(command[0]==build['compiler']['path'] and command[1:1+len(build['flags'])]==build['flags']
         and command[-2:]==['-o',build['binary_path']] and command.count('native/bench/pubpres_empty_derived.cpp')==1,
         'Recorded compiler command differs from exact flags/benchmark/output')
    log=folder/'build-timing-D.log' if role=='D' else repo/'build/pubpres-final/mask-applicability/timing-C-build.log'
    if not log.exists() and role=='C':log=repo/'build/pubpres-final/mask-applicability/build-timing-C.log'
    need(digest(log)==build['log_sha256'],'Original compile log differs')
    builds.append({'role':role,'source_commit':expected,'source_tree':build['source_tree'],'binary_sha256':build['binary_sha256'],
                   'compiler_sha256':build['compiler']['sha256'],'closure':closure,'command':command,'build_log_sha256':digest(log)})

measurements=[];last_cpu=None
for run in manifest['runs']:
    raw=receipts['raw_runs'][run['name']]
    for stream in ('stdout','stderr'):
        need((folder/(run['name']+'.'+stream)).read_bytes()==raw[stream].encode()
             and sha(raw[stream].encode())==raw[stream+'_sha256'],'Original process stream differs')
    data=json.loads(raw['stdout']);clocks=data['tick_nanoseconds'];phases=data['phase_nanoseconds']
    need(len(clocks)==72 and all(type(v) is int and v>0 for v in clocks)
         and len(phases)==72 and all(sum(row)<=clock for row,clock in zip(phases,clocks)),'Actual bounded clock arrays differ')
    ordered=sorted(clocks)
    stats={'tick_mean_ms':math.fsum(clocks)/72/1e6,'tick_max_ms':ordered[-1]/1e6}
    stats.update({'tick_p'+str(q)+'_ms':ordered[math.ceil(72*q/100)-1]/1e6 for q in (50,95,99)})
    stats.update({name+'_mean_ms':math.fsum(row[index] for row in phases)/72/1e6
                  for index,name in enumerate(('prepare','column','flux','apply'))})
    need(all(math.isclose(data[key],value,rel_tol=1e-12,abs_tol=1e-12) for key,value in stats.items()),'Independent native quantile/phase mean differs')
    before,after=run['children_cpu_before'],run['children_cpu_after']
    need(last_cpu is None or before==last_cpu,'Another child entered the retained serial CPU chain')
    last_cpu=after
    user=after['user_seconds']-before['user_seconds'];system=after['system_seconds']-before['system_seconds']
    wall=run['whole_process_wall_nanoseconds']/1e9
    need(user>=0 and system>=0 and user+system>0 and wall>=sum(clocks)/1e9,'Impossible child CPU/wall containment')
    measurements.append({'name':run['name'],'arm':run['arm'],'actual_workers':data['workers_observed'],**stats,
                         'whole_child_user_seconds':user,'whole_child_system_seconds':system,
                         'whole_child_cpu_seconds':user+system,'whole_process_wall_seconds':wall,
                         'semantic_checkpoint_sha256':sha(json.dumps(data['checkpoints'],separators=(',',':')).encode()),
                         'water_units':data['water_units'],'launched_parcels':data['launched_parcels']})

diagnostic=json.loads((folder/'diagnostic-builds.json').read_bytes())
initial=json.loads((folder/'correctness-runs.json').read_bytes())
continuation=json.loads((folder/'correctness-continuation-runs.json').read_bytes())
need(initial['diagnostic_builds_sha256']==digest(folder/'diagnostic-builds.json')
     and continuation['initial_attempt_sha256']==digest(folder/'correctness-runs.json'),'Diagnostic execution provenance chain differs')
correctness_closure={
    'control':verify_inputs(diagnostic['source_inputs_sha256']['control'],control,diagnostic['control_fixture_overlay_sha256']),
    'candidate':verify_inputs(diagnostic['source_inputs_sha256']['candidate'],source)}
need(initial['candidate_source_inputs_sha256']==diagnostic['source_inputs_sha256']['candidate'],'Candidate diagnostic execution/source map differs')
need(digest(diagnostic['compiler']['path'])==diagnostic['compiler']['sha256'],'Diagnostic compiler bytes differ')
build_outputs={}
for build in diagnostic['builds']:
    need(build['exit_code']==0 and '-DCYBERSAND_WAVE_VERIFY_EMPTY_DERIVED' in build['arguments']
         and digest(build['output_path'])==build['output_sha256']
         and digest(folder/(build['name']+'.log'))==build['log_sha256'],'Diagnostic macro, compiled output or build log differs')
    build_outputs[build['output_path']]=build['output_sha256']
reuse=diagnostic['reused_object_build_receipt']
need(digest(reuse['path'])==reuse['sha256'],'Reused object build receipt differs')
prior=json.loads(Path(reuse['path']).read_bytes())
prior_builds=prior if isinstance(prior,list) else prior['builds']
if isinstance(prior_builds,dict):prior_builds=list(prior_builds.values())
for name,record in diagnostic['reused_control_objects'].items():
    need(digest(record['path'])==record['sha256'],'Reused diagnostic object bytes differ')
    matches=[row for row in prior_builds if row['arguments'][-2:]==['-o',record['path']]]
    need(len(matches)==1 and matches[0]['returncode']==0
         and '-DCYBERSAND_WAVE_VERIFY_EMPTY_DERIVED' in matches[0]['arguments'],
         'Reused object lacks its recorded diagnostic compile command')
observed=[];lifecycle=[];unobserved=[]
for run in initial['runs']+continuation['runs']:
    need(digest(run['arguments'][0])==run['binary_sha256']==build_outputs[run['arguments'][0]],'Actual correctness binary differs')
    if 'exit_code' not in run:
        unobserved.append(run);continue
    need(run['exit_code']==0,'Retained correctness process failed')
    for stream in ('stdout','stderr'):
        need(digest(folder/(run['name']+'.'+stream+'.log'))==run[stream+'_sha256'],'Correctness original stream differs')
    need((folder/(run['name']+'.stderr.log')).read_bytes()==b'','Correctness diagnostics not empty')
    text=(folder/(run['name']+'.stdout.log')).read_text()
    if run['name'].startswith('lifecycle-'):
        value=json.loads(text)
        need(value['schema']=='pubpres-empty-derived-lifecycle-v3' and len(value['checkpoints'])==285*8
             and value['workers']==int(run['arguments'][1]),'Lifecycle fixture/counter scope differs')
        lifecycle.append(value)
    observed.append({'name':run['name'],'binary_sha256':run['binary_sha256'],'stdout_sha256':run['stdout_sha256'],
                     'terminal':None if run['name'].startswith('lifecycle-') else text.splitlines()[-1]})
need(len(lifecycle)==4 and all(value['checkpoints']==lifecycle[0]['checkpoints']
                              and value['checkpoint_fields']==lifecycle[0]['checkpoint_fields'] for value in lifecycle),
     'Complete 285-tick, eight-field lifecycle differential differs')
need(len(unobserved)==1 and unobserved[0]['name']=='wave_spill','Unknown original correctness gap changed')
result={'schema':'pubpres-native-zero-carry-independent-peer-v1','reader_sha256':digest(Path(__file__)),
        'timing_receipt_sha256':digest(folder/'timing-receipts.json'),'registered_reader_source':source,
        'registered_reader_files_sha256':readers,'full_registered_reduction_matches':True,
        'independent_builds':builds,'independent_per_process_measurements':measurements,
        'registered_result':reconstructed,'diagnostic_builds_sha256':digest(folder/'diagnostic-builds.json'),
        'correctness_source_closure':correctness_closure,'lifecycle_ticks_per_process':285,
        'lifecycle_fields':lifecycle[0]['checkpoint_fields'],'all_four_lifecycle_arrays_equal':True,
        'actual_correctness_runs':observed,'unobserved_original_attempts':unobserved,
        'source_closure_limit':'The native/lifecycle diagnostic closure is recorded and verified. Issued macro-bearing commands, actual binaries and logs verify the three broad suite outcomes; contemporaneous hashes of test_wave_flow.cpp, test_wave_spill.cpp and test_wave_body_boundary.cpp were not recorded in this diagnostic closure. Do not infer that missing attestation from current Git source. The original unobserved spill start remains unqualified; the separate observed continuation is retained.',
        'complete':True,'physical_acceptance':'HOLD',
        'scope':'Read-only exact-source/native-only screen. All twelve original processes, negative large-canvas results and control variation retained. Nearest-rank p99 equals max for72 ticks; no pooled/averaged quantiles. Whole-child CPU includes setup/semantic checks and is not joined to native tick clocks. No Rapier, input, displayed frame or physical NVIDIA qualification.'}
output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'complete':True,'output':str(output),'sha256':digest(output),'native_only':True,'physical_acceptance':'HOLD'}))
