"""Independent reject-by-default continuation evidence reader; never admits timing.

Does not import collector/overlay/candidate code. Reuses only the frozen S1
independent semantic decoder and lifecycle contract for the matching projection.
"""
import argparse
import gzip
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import tempfile


def checked(root, name):
    p=Path(name)
    if not name or p.is_absolute() or '..' in p.parts or '\\' in name or ':' in name:
        raise ValueError('unsafe evidence path')
    q=root/p
    if q.is_symlink() or not q.resolve().is_relative_to(root.resolve()):
        raise ValueError('unsafe evidence target')
    return q


def unique(pairs):
    d={}
    for k,v in pairs:
        if k in d: raise ValueError('duplicate JSON key')
        d[k]=v
    return d


def load(p): return json.loads(p.read_text(),object_pairs_hook=unique)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def require(b, message):
    if not b: raise ValueError(message)


def verify(root):
    result=dict(status='failed',formal_timing_admitted=False,errors=[],checked_files=0,cases=0)
    try:
        files=load(root/'files.json')
        actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name not in ('files.json','independent-readback.json')}
        require(set(files)==actual,'missing or extra evidence files')
        for name,digest in files.items():
            require(sha(checked(root,name))==digest,'file hash mismatch: '+name)
            result['checked_files']+=1
        report=load(root/'run.json')
        require(report['status']=='collected-not-admitted' and report['errors']==[], 'incomplete collector')
        require(report['formal_timing_admitted'] is False,'timing boundary violation')
        require(report['qualified_toolchain'] is True and '13.3.0' in report['compiler_version'],'unqualified toolchain')
        require(all(r['exit_code']==0 and not r.get('timed_out',False) for r in report['commands']),'failed command retained: collection incomplete')
        require(len(report['cases'])==len({c['id'] for c in report['cases']}),'duplicate cases')
        seal=load(root/'source-seal.json')
        require(seal==report['source_sha256'],'source seal mismatch')
        for name,digest in seal.items(): require(sha(checked(root,'source/'+name))==digest,'source seal drift')
        require(load(root/'binary-seal.json')==report['builds'],'binary seal mismatch')
        for b in report['builds']: require(sha(checked(root,b['binary']))==b['sha256'],'binary seal drift')
        for row in report['commands']:
            if row['label'].startswith('execute/'):
                require(not (root/(row['label']+'.stderr')).read_bytes().strip(),'runtime/sanitizer stderr not empty')
        # This is the accepted independent reader, not the apparatus generator.
        path=root/'source/tools/experiments/mat003_prepass/world_verify.py'
        spec=importlib.util.spec_from_file_location('frozen_independent_s1_reader',path)
        reader=importlib.util.module_from_spec(spec); spec.loader.exec_module(reader)
        track=report['track']
        if track=='wclear':
            expected={f'aligned-e{e}-x2-o{o}-{s}-{scene}-w{w}-{mode}'
                      for e,o,s,scene,w,mode in itertools.product((8,16,24,32),(0,1),(512,1024,2048),
                          ('sleep-excluded','active-window-excluded'),(1,4),('ordinary','event'))}
            expected|={f'aligned-e{e}-x2-o{o}-128-sleep-excluded-w1-{mode}-natural16'
                       for e,o,mode in itertools.product((8,16,24,32),(0,1),('ordinary','event'))}
            require({c['id'] for c in report['cases']}==expected,'WCLEAR must retain all 208 registered cases')
            reference={}
            cell_cache={}
            for row in report['cases']:
                name=row['id']; event=row['event']; observed=row['observer']==1
                require(row==dict(json.loads((root/('execute/'+name+'.stdout')).read_text()),
                                  id=name,scene=row['scene'],observer=row['observer']), 'stdout/receipt mismatch')
                require(row['resident_cells']==row['side']**2 and row['stride']==16 and row['alignment']==8,'resident geometry mismatch')
                require(row['clear_count']==int(event),'counter transition did not indicate expected clear')
                require(row['observed_clear_count']==int(event and observed),'actual observed clear entry mismatch')
                require(row['observed_clear_cells']==(row['resident_cells'] if event and observed else 0),'actual clear traversal mismatch')
                natural=event and (row['epoch_bits']==8 or (row['epoch_bits']==16 and row['side']==128))
                require(row['natural_event']==natural and row['prepared_event']==(event and not natural),'natural/prepared attribution mismatch')
                require(row['completed_event_tick']==(65536 if row['side']==128 else 256),'completed clear tick mismatch')
                if observed and row['scene']=='active-window-excluded' and row['workers']==4:
                    require(row['event_worker_tasks']>0,'no background participation during the event tick')
                for filename in ['pre.bin','post.bin']+[f'reentry-{i}.bin' for i in range(4)]:
                    raw=gzip.decompress((root/'cases'/name/(filename+'.gz')).read_bytes())
                    # Same source-independent full bytes for all widths,
                    # event/ordinary and observer twins within each workload.
                    key=(row['side'],row['scene'],row['workers'],filename)
                    if key in reference:
                        require(raw==gzip.decompress(reference[key]), 'semantic mismatch: '+name+'/'+filename)
                    else:
                        decoded=reader.decode_snapshot(raw,cell_cache)
                        require(decoded['cells']==row['resident_cells'],'independently decoded residency mismatch')
                        reference[key]=gzip.compress(raw,mtime=0)
                result['cases']+=1
        elif track in ('s2p','c128'):
            expected=({'word-e8-x0'}|{f'memcpy-e{e}-x{x}' for e in (8,16) for x in (1,2)}) if track=='s2p' else {f'{r}-e{e}-x2' for r in ('u128','dual64') for e in (8,16)}
            require({c['id'] for c in report['cases']}==expected,'incomplete candidate correctness set')
            controls={}
            for row in report['cases']:
                r=row['result']; name=row['id']; rep=name.split('-')[0]
                require(r==load(root/'cases'/name/'result.json'),'result readback mismatch')
                require(r['status']=='passed' and r['assertions']>0,'unsuccessful correctness fixture')
                expected_stride=16 if rep in ('u128','dual64') else (8 if rep=='word' else 8+int(name[-1]))
                expected_alignment=16 if rep=='u128' else (1 if rep=='memcpy' else 8)
                require((r['cell_stride'],r['cell_alignment'])==(expected_stride,expected_alignment),'candidate ABI mismatch')
                require(r['logical_bits']==(128 if rep in ('u128','dual64') else expected_stride*8),'logical capacity mismatch')
                # Reuse the S1 lifecycle/mass/clear contract on its exact low64
                # plus low16 neutral projection. Actual new ABI checked above;
                # full high64 storage and World probes are separate assertions.
                projected=json.loads(json.dumps(r))
                oldrep='aligned' if rep in ('u128','dual64') else ('packed' if rep=='memcpy' else 'word')
                projected['representation']=oldrep
                if rep in ('u128','dual64'): projected.update(logical_bits=80,cell_alignment=8)
                arm=dict(id=r['arm_id'],representation=oldrep,logical_bits=projected['logical_bits'],epoch_bits=r['epoch_bits'])
                registration=load(root/'source/tools/experiments/mat003_prepass/world_registration.json')
                errors=reader.validate_result(projected,registration,arm)
                require(not errors,'independent S1 contract: '+str(errors))
                for trace in r['ordinary']+[r['natural']]:
                    raw=gzip.decompress((root/'cases'/name/(trace['file']+'.gz')).read_bytes())
                    # Decode the complete delta stream using the frozen reader.
                    with tempfile.TemporaryDirectory() as directory:
                        p=Path(directory)/'trace.bin'; p.write_bytes(raw)
                        summary=reader.decode_trace(p,trace['ticks'])
                    errors=reader.validate_trace_summary(trace,summary,arm)
                    require(not errors,'independent trace contract: '+str(errors))
                    key=trace['name']
                    if key in controls: require(raw==controls[key],'candidate semantic trace differs: '+name+'/'+key)
                    else: controls[key]=raw
                result['cases']+=1
        else: raise ValueError('unknown track')
        result['status']='qualification-readback-passed-timing-held'
    except Exception as error:
        result['errors'].append(str(error))
    return result


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__); ap.add_argument('root',type=Path)
    args=ap.parse_args(); result=verify(args.root.resolve())
    print(json.dumps(result,indent=2)); raise SystemExit(bool(result['errors']))
