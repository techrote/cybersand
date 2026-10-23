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
import re
import subprocess
import sys
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


def identity(name):
    m=re.fullmatch(r'(word|packed|aligned|split|memcpy|u128|dual64)-e(8|16|24|32)-x([012])',name)
    require(m is not None,'invalid registered arm identity')
    rep,bits,extra=m.groups()
    return rep,int(bits),int(extra)


def check_compile(argv, arm, observer, assembly=False):
    rep,bits,extra=identity(arm)
    flags=['-std=c++20','-O2','-DNDEBUG','-Wall','-Wextra','-Wpedantic','-pthread']
    require(argv[1:8]==flags,'compiler flags differ from frozen S2A flags')
    actual_flags=[v for v in argv[1:] if v.startswith('-') and not v.startswith(('-D','-I')) and v not in ('-o','-S')]
    require(actual_flags==[v for v in flags if not v.startswith('-D')],'extra/missing compiler optimization flags')
    capacity=128 if rep in ('u128','dual64') else 64+8*extra
    kind={'word':1,'packed':3,'memcpy':3,'aligned':4,'split':5,'u128':4,'dual64':4}[rep]
    definitions=[v for v in argv if v.startswith('-D')]
    expected={'-DNDEBUG',f'-DMAT003_STORAGE_KIND={kind}',f'-DMAT003_EXTRA_BYTES={extra}',f'-DMAT003_SPLIT={int(rep=="split")}',
              f'-DMAT003_ARM_ID="C{capacity}-E{bits}-{rep}"',f'-DMAT003_EPOCH_BITS={bits}',f'-DMAT003_TWIN_OBSERVERS={observer}'}
    world=[v for v in definitions if v.startswith('-DMAT003_WORLD_SOURCE=')]
    require(len(world)==1 and world[0].endswith('/overlays/'+arm+'/native/src/world.cpp"'),'compiled World source path differs')
    require(set(definitions)==expected|set(world) and len(definitions)==len(expected)+1,'compiler macros differ from registered arm')
    require(('-S' in argv)==assembly,'compiler output kind mismatch')


def verify(root, expected_source=None):
    result=dict(status='failed',formal_timing_admitted=False,errors=[],checked_files=0,cases=0)
    try:
        files=load(root/'files.json')
        actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name not in ('files.json','independent-readback.json')}
        require(set(files)==actual,'missing or extra evidence files')
        for name,digest in files.items():
            require(sha(checked(root,name))==digest,'file hash mismatch: '+name)
            result['checked_files']+=1
        report=load(root/'run.json')
        trusted=Path(__file__).resolve().parents[3]
        require(len(report['source_head'])==40,'missing exact source commit')
        source_commit=report['source_head']
        expected_source=expected_source or subprocess.check_output(['git','rev-parse','HEAD'],cwd=trusted,text=True).strip()
        require(source_commit==expected_source,'source commit differs from explicit review identity')
        require(report['status']=='collected-not-admitted' and report['errors']==[], 'incomplete collector')
        require(report['formal_timing_admitted'] is False,'timing boundary violation')
        require(report['qualified_toolchain'] is True and '13.3.0' in report['compiler_version'],'unqualified toolchain')
        require('2.42' in report['linker_version'] and (root/'linker.stdout').read_text()==report['linker_version'],'linker pin/readback mismatch')
        require(all(r['exit_code']==0 and not r.get('timed_out',False) for r in report['commands']),'failed command retained: collection incomplete')
        require(len(report['cases'])==len({c['id'] for c in report['cases']}),'duplicate cases')
        seal=load(root/'source-seal.json')
        require(seal==report['source_sha256'],'source seal mismatch')
        # Bind to actual Git objects from the review checkout. This verifier's
        # published commit is the trust root, never an artifact-supplied module.
        baseline='2b2a1dd64f16dc46d5e812b757de73f47df0fb2b'
        frozen_s1=json.loads(subprocess.check_output(['git','show',baseline+':tools/experiments/mat003_prepass/world_registration.json'],cwd=trusted))
        expected_sources=set(frozen_s1['baseline_control_sha256'])
        for folder in ['mat003_prepass','mat003_s2a','mat003_continuation']:
            names=subprocess.check_output(['git','ls-tree','--name-only',source_commit+':tools/experiments/'+folder],cwd=trusted,text=True).splitlines()
            expected_sources.update('tools/experiments/'+folder+'/'+n for n in names if Path(n).suffix in ('.py','.hpp','.cpp','.json'))
        require(set(seal)==expected_sources,'source inventory mismatch')
        for name,digest in seal.items():
            require(sha(checked(root,'source/'+name))==digest,'source seal drift')
            commit=source_commit if name.startswith('tools/experiments/mat003_continuation/') else baseline
            content=subprocess.check_output(['git','show',commit+':'+name],cwd=trusted)
            require(hashlib.sha256(content).hexdigest()==digest,'source disagrees with frozen Git object: '+name)
            if name.startswith('tools/experiments/mat003_continuation/'):
                current=subprocess.check_output(['git','show','HEAD:'+name],cwd=trusted)
                require(hashlib.sha256(current).hexdigest()==digest,'trusted continuation checkout differs: '+name)
        require(load(root/'binary-seal.json')==report['builds'],'binary seal mismatch')
        for b in report['builds']: require(sha(checked(root,b['binary']))==b['sha256'],'binary seal drift')
        for row in report['commands']:
            if row['label'].startswith('execute/'):
                require(not (root/(row['label']+'.stderr')).read_bytes().strip(),'runtime/sanitizer stderr not empty')
        # This is the accepted independent reader, not the apparatus generator.
        path=root/'source/tools/experiments/mat003_prepass/world_verify.py'
        spec=importlib.util.spec_from_file_location('frozen_independent_s1_reader',path)
        reader=importlib.util.module_from_spec(spec)
        # A reader must not create an unsealed __pycache__ inside its evidence.
        previous_bytecode=sys.dont_write_bytecode
        try:
            sys.dont_write_bytecode=True
            spec.loader.exec_module(reader)
        finally:
            sys.dont_write_bytecode=previous_bytecode
        track=report['track']
        # Exact build and command inventories, rather than validating only the
        # subset a collector happens to retain.
        if track=='s2p':
            all_arms=['word-e8-x0','packed-e8-x1','packed-e8-x2','aligned-e8-x1','aligned-e8-x2','split-e8-x1','split-e8-x2']+[f'memcpy-e{e}-x{x}' for e in (8,16) for x in (1,2)]
            built={'word-e8-x0'}|{f'memcpy-e{e}-x{x}' for e in (8,16) for x in (1,2)}
        elif track=='c128':
            all_arms=[f'{r}-e{e}-x2' for r in ('u128','dual64') for e in (8,16)]
            built=set(all_arms)
        elif track=='wclear':
            all_arms=[f'aligned-e{e}-x2' for e in (8,16,24,32)]
            built={a+'-o'+str(o) for a in all_arms for o in (0,1)}
        else: raise ValueError('unknown track')
        require({b['id'] for b in report['builds']}==built and len(report['builds'])==len(built),'missing/extra/duplicate builds')
        labels={'compiler','linker'}|{'common/'+n for n in ('material_rules','scheduler_geometry','settled_world_discovery')}
        labels|={'compile/'+a for a in built}
        labels|={'execute/'+c['id'] for c in report['cases']}
        labels|={'compile/storage','execute/storage','compile/storage-ubsan','execute/storage-ubsan'}
        if track!='wclear':
            labels|={'asm/'+a for a in all_arms}|{'world-asm/'+a for a in all_arms}
            for a in all_arms:
                require((root/'assembly'/a/'access.s').is_file() and (root/'assembly'/a/'world.s').is_file(),'assembly control missing')
        require({c['label'] for c in report['commands']}==labels and len(report['commands'])==len(labels),'missing/extra/duplicate command inventory')
        for a in all_arms:
            folder=root/'overlays'/a
            generated=load(folder/'generated-source-seal.json')
            actual_generated={p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file() and p.name!='generated-source-seal.json'}
            require(set(generated)==actual_generated,'generated input inventory mismatch')
            for name,digest in generated.items(): require(sha(checked(folder,name))==digest,'generated source drift')
        commands={c['label']:c for c in report['commands']}
        builds={b['id']:b for b in report['builds']}
        for a in all_arms:
            if track=='wclear':
                for observer in (0,1):
                    check_compile(commands['compile/'+a+'-o'+str(observer)]['argv'],a,observer)
            else:
                check_compile(commands['asm/'+a]['argv'],a,0,True)
                check_compile(commands['world-asm/'+a]['argv'],a,0,True)
                if a in built: check_compile(commands['compile/'+a]['argv'],a,1)
        storage_seals=load(root/'storage-binary-seal.json')
        require({b['id'] for b in storage_seals}=={'storage','storage-ubsan'} and len(storage_seals)==2,'storage binary seals missing')
        for b in storage_seals:
            require(sha(checked(root,b['binary']))==b['sha256'],'storage binary hash mismatch')
            require(commands['execute/'+b['id']]['argv'][0]==commands['compile/'+b['id']]['argv'][-1],'executed storage binary mismatch')
        storage=json.loads((root/'execute/storage.stdout').read_text())
        require(storage=={'dual_size':16,'dual_align':8,'u128_size':16,'u128_align':16,'passed':True},'storage boundary/ABI model failed')
        require(json.loads((root/'execute/storage-ubsan.stdout').read_text())==storage,'sanitized storage model disagrees')
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
                # Parse the authoritative ID, then require all declared metadata
                # and the actual command argv to match this exact context.
                m=re.fullmatch(r'aligned-e(8|16|24|32)-x2-o([01])-(128|512|1024|2048)-(sleep-excluded|active-window-excluded)-w([14])-(event|ordinary)(-natural16)?',name)
                require(m is not None,'invalid context ID')
                e,o,s,scene,w,mode,suffix=m.groups()
                require((row['epoch_bits'],row['observer'],row['side'],row['scene'],row['workers'],event)==
                        (int(e),int(o),int(s),scene,int(w),mode=='event'),'case metadata differs from registered context')
                b=builds[f'aligned-e{e}-x2-o{o}']
                argv=commands['execute/'+name]['argv']
                require(argv[1:5]==[s,w,scene,mode] and Path(argv[0]).name==Path(b['binary']).name and
                        Path(argv[5]).name==name and argv[6:]==(['65535'] if suffix else []),'execute argv differs from exact context')
                require(argv[0]==commands['compile/'+b['id']]['argv'][-1],'executed binary differs from compiler output')
                require(b['observer']==int(o),'build observer metadata mismatch')
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
            if track=='c128':
                source_control=root.parent/'s2p'
                control_review=verify(source_control,expected_source)
                require(control_review['status']=='qualification-readback-passed-timing-held','C128 requires separately verified S2P C64 control')
                for trace_name in ('ordinary-serial','ordinary-phased-1','ordinary-phased-4','natural'):
                    controls[trace_name]=gzip.decompress((source_control/'cases/word-e8-x0'/(trace_name+'.bin.gz')).read_bytes())
            for row in report['cases']:
                r=row['result']; name=row['id']; rep=name.split('-')[0]
                expected_rep,expected_bits,expected_extra=identity(name)
                expected_capacity=128 if rep in ('u128','dual64') else 64+8*expected_extra
                require((r['epoch_bits'],r['representation'],r['arm_id'])==(expected_bits,expected_rep,f'C{expected_capacity}-E{expected_bits}-{rep}'),'candidate metadata differs from registered ID')
                require(builds[name]['observer']==1,'candidate correctness build observer mismatch')
                require(commands['execute/'+name]['argv'][0]==commands['compile/'+name]['argv'][-1],'executed candidate differs from compiler output')
                require(commands['execute/'+name]['argv'][1]=='--output' and Path(commands['execute/'+name]['argv'][2]).name==name,'candidate output argument mismatch')
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
    ap.add_argument('--source-commit',help='exact externally reviewed checkout commit; defaults to current HEAD')
    args=ap.parse_args(); result=verify(args.root.resolve(),args.source_commit)
    print(json.dumps(result,indent=2)); raise SystemExit(bool(result['errors']))
