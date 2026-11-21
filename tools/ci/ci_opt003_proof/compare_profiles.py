#!/usr/bin/env python3
"""Fail-closed, source-bound paired timing report; no percentile claim."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

BASE = '846fe0533b3170e7b01f690518da49fc40cc24d1'
CANDIDATE = '506dfc8c343c5d24fe26e89a9542cf985c52853e'

def inspect(folder, expected):
    record=json.loads((folder/'profile.json').read_text())
    assert record['status']=='passed' and record['returncode']==0
    assert record['source_before']==record['source_after']
    assert record['source_before']['commit']==expected
    assert record['source_before']['tracked_status']==''
    inv=record['verified_inventory']
    assert (inv['objects'],inv['binaries'],inv['test_executions'])==(12,16,16)
    assert len(inv['compiler_commands'])==28 and len(inv['test_commands'])==10
    commands=json.loads((folder/'command-index.json').read_text())
    assert all(r['status']=='passed' and r['returncode']==0 for r in commands)
    compilers=[r for r in commands if r['kind']=='compiler']
    assert len(compilers)==28
    events=[]
    for r in compilers:
        events += [(r['start_time_ns'],1),(r['end_time_ns'],-1)]
    active=peak=0
    for _, change in sorted(events):
        active+=change;peak=max(active,peak)
    assert active==0 and peak<=2
    heavy=[r for r in compilers if '-c' in r['argv'] and 'native/src/world_generation.cpp' in r['argv']]
    assert len(heavy)==2
    overlap=max(0,min(r['end_time_ns'] for r in heavy)-max(r['start_time_ns'] for r in heavy))/1e9
    summary={
        'elapsed_seconds':record['elapsed_seconds'],
        'compiler_user_seconds':sum(r['child_user_seconds'] for r in compilers),
        'compiler_system_seconds':sum(r['child_system_seconds'] for r in compilers),
        'compiler_max_concurrency':peak,
        'max_compiler_child_rss_kib':max(r['max_child_rss_kib'] for r in compilers),
        'heavy_compilers':[{'output':r['argv'][-1],'elapsed_seconds':r['elapsed_seconds']} for r in heavy],
        'heavy_compiler_overlap_seconds':overlap,
        'compiler_version':record['compiler_version'],
        'source':record['source_before'],
        'profile_sha256':hashlib.sha256((folder/'profile.json').read_bytes()).hexdigest(),
        'command_index_sha256':hashlib.sha256((folder/'command-index.json').read_bytes()).hexdigest(),
    }
    return record,summary

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--directory',type=Path,required=True)
    a=p.parse_args()
    try:
        before,bs=inspect(a.directory/'baseline',BASE)
        after,cs=inspect(a.directory/'candidate',CANDIDATE)
        assert before['compiler_version']==after['compiler_version']
        assert before['sanitizer_environment']==after['sanitizer_environment']
        assert before['instrumentation_sha256']==after['instrumentation_sha256']
        bi,ci=before['verified_inventory'],after['verified_inventory']
        assert Counter(map(tuple,bi['compiler_commands']))==Counter(map(tuple,ci['compiler_commands']))
        assert bi['test_commands']==ci['test_commands']
        result={'schema':'ci-opt003-same-worker-pair-v1','status':'passed','baseline':bs,'candidate':cs,
                'saved_seconds':bs['elapsed_seconds']-cs['elapsed_seconds'],
                'observed_fraction_saved':1-cs['elapsed_seconds']/bs['elapsed_seconds'],
                'limits':['One sequential cold-build pair on one worker, not a percentile or population estimate.',
                          'Compiler maxima are per-child RSS, not aggregate memory.',
                          'Timing is diagnostic; canonical complete Native/platform CI is a separate gate.']}
    except (AssertionError,KeyError,ValueError,OSError) as e:
        result={'schema':'ci-opt003-same-worker-pair-v1','status':'failed','error':repr(e)}
    (a.directory/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return result['status']!='passed'

if __name__=='__main__': raise SystemExit(main())
