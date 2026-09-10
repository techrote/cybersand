"""Issue16 L2: matched-alignment packing, retained control bridges, no solver changes."""
from __future__ import annotations
import argparse
import csv
import gzip
import itertools
import json
from pathlib import Path
import shutil
import time

import cell_layout as common
from summarize_cell_layout import normalized_timing_record, summarize_samples

ROOT, OUT, BUILD = common.ROOT, common.OUT, common.BUILD
VARIANTS = {'byte4': (4,0), 'packed4': (4,1), 'byte8': (8,0), 'packed8': (8,1)}


def identity():
    result = common.identity()
    for path in (Path(__file__), ROOT/'native/tests/test_cell_layout_storage.cpp',
                 ROOT/'tools/experiments/summarize_cell_layout.py'):
        result['files'][str(path.relative_to(ROOT))] = common.digest(path)
    return result


def cases():
    return [(name,extent,workers) for name in ('dense','sparse') for extent in (512,1024) for workers in (1,4)] + [('sleeping',4096,1),('sleeping',4096,4)]


def equal_archived_files(reference, record):
    with gzip.open(reference,'rb') as left, record.open('rb') as right:
        while True:
            a,b=left.read(1024*1024),right.read(1024*1024)
            if a!=b: raise RuntimeError(f'Exact archived comparison failed: {reference} / {record}')
            if not a: return


def plan():
    rows=[]
    def pair_series(comparison, fixture, extent, workers, control, candidate, observers=(0,0)):
        for pair in range(7):
            order=(0,1) if pair%2==0 else (1,0)
            for member in order:
                rows.append(dict(comparison=comparison,fixture=fixture,extent=extent,workers=workers,
                    pair=pair,member=member,variant=(control,candidate)[member],observer=observers[member],ticks=1920))
    # Review the representative control bridge before interpreting packing contrasts.
    for width in (4,8):
        for fixture,extent,workers in [('dense',512,4),('sleeping',4096,1)]:
            pair_series(f'bridge{width}',fixture,extent,workers,f'legacy{width}',f'byte{width}')
    for width in (4,8):
        for fixture,extent,workers in cases():
            pair_series(f'packing{width}',fixture,extent,workers,f'byte{width}',f'packed{width}')
    for variant in VARIANTS:
        for workers in (1,4):
            pair_series(f'observer-{variant}','sparse',1024,workers,variant,variant,(0,1))
    assert len(rows)==448
    return rows


def prepare(legacy_manifest):
    legacy=json.loads(legacy_manifest.read_text())
    for artifact in legacy['artifacts'].values():
        if common.digest(artifact['exe'])!=artifact['sha256']:
            raise RuntimeError('Retained L1 binary changed')
    env,cxx=common.environment()
    if common.digest(cxx)!=legacy['toolchain']['sha256']:
        raise RuntimeError('Pinned compiler differs from L1')
    out=OUT/('prepare-l2-'+time.strftime('%Y%m%d-%H%M%S'))
    out.mkdir(parents=True,exist_ok=False)
    common.write(out/'source-before.json',identity())
    flags=[cxx,'-std=c++20','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wshadow','-pthread','-static','-Inative/include']
    build=BUILD/out.name
    build.mkdir(parents=True,exist_ok=False)
    common.execute('build-default-tests',[*flags,'-O0','-g3',*common.CORE,'native/tests/test_world.cpp','-o',build/'default-tests.exe'],out,env,1200)
    common.execute('default-native-tests',[build/'default-tests.exe'],out,env,1800)
    artifacts={f'legacy{w}':dict(legacy['artifacts'][str(w)],retained_manifest=str(legacy_manifest)) for w in (4,8)}
    for name,(width,packed) in VARIANTS.items():
        target=build/name
        target.mkdir()
        defines=[f'-DCYBERSAND_CELL_LAYOUT_EXPERIMENT={width}',f'-DCYBERSAND_CELL_LAYOUT_ALIGNMENT={width}',f'-DCYBERSAND_CELL_LAYOUT_PACKED={packed}']
        exe,tests,storage=target/'cell_layout.exe',target/'tests.exe',target/'storage-tests.exe'
        common.execute('build-'+name,[*flags,'-O3','-DNDEBUG','-flto',*defines,*common.CORE,'native/bench/cell_layout.cpp','-lpsapi','-o',exe],out,env,1200)
        common.execute('build-tests-'+name,[*flags,'-O0','-g3',*defines,*common.CORE,'native/tests/test_world.cpp','-o',tests],out,env,1200)
        common.execute('native-tests-'+name,[tests],out,env,1800)
        common.execute('build-storage-'+name,[*flags,'-O2',*defines,'native/tests/test_cell_layout_storage.cpp','-o',storage],out,env,1200)
        common.execute('storage-tests-'+name,[storage],out,env,1800)
        common.execute('assembly-'+name,[*flags,'-O3','-DNDEBUG',*defines,'-S','native/src/world.cpp','-o',target/'world.s'],out,env,1200)
        common.execute('lto-disassembly-'+name,[cxx.parent/'llvm-objdump.exe','-d','--demangle',exe],out,env,1200)
        artifacts[name]=dict(exe=str(exe),sha256=common.digest(exe),tests=str(tests),tests_sha256=common.digest(tests),
                             storage_tests=str(storage),storage_sha256=common.digest(storage),defines=defines,
                             assembly=str(target/'world.s'),cell_size=width,alignment=width,packed=bool(packed))
        common.write(out/'built-artifacts.json',artifacts)
    common.execute('c-header',[cxx.parent/'clang.exe','-std=c11','-Wall','-Wextra','-Wpedantic','-Inative/include','-fsyntax-only','native/tests/test_c_header.c'],out,env,120)
    comparisons=[]
    legacy_out=Path(legacy['output'])
    for seed,x,y in common.SEEDS:
        reference=out/f'legacy-behavior-{seed}.records'
        with gzip.open(legacy_out/f'behavior-{seed}-4-1-0.records.gz','rb') as source,reference.open('wb') as dest:
            shutil.copyfileobj(source,dest)
        for name in VARIANTS:
            for workers in (1,4):
                for repeat in (0,1):
                    label=f'behavior-{seed}-{name}-{workers}-{repeat}'
                    prefix=out/label
                    common.execute(label,[artifacts[name]['exe'],'correctness','behavior',512,workers,1800,seed,x,y,1,prefix],out,env)
                    record=prefix.with_suffix('.records')
                    common.equal_files(reference,record)
                    comparisons.append(dict(case=label,reference=str(legacy_out/f'behavior-{seed}-4-1-0.records.gz'),exact_bytes=record.stat().st_size,sha256=common.digest(record)))
                    common.compress(record)
                    common.write(out/'comparisons.json',comparisons)
                if seed==0:
                    label=f'observer-off-{name}-{workers}'
                    prefix=out/label
                    common.execute(label,[artifacts[name]['exe'],'correctness','behavior',512,workers,1800,seed,x,y,0,prefix],out,env)
                    record=prefix.with_suffix('.records')
                    for a,b in itertools.zip_longest(common.without_events(reference),common.without_events(record)):
                        if a!=b: raise RuntimeError('Observer state/work mismatch')
                    comparisons.append(dict(case=label,observer_neutral=True,sha256=common.digest(record)))
                    common.compress(record)
        common.compress(reference)
        common.write(out/'comparisons.json',comparisons)
        print(f'L2 seed{seed}: retained L1/variant/worker/repeat parity',flush=True)
    for name in VARIANTS:
        for fixture,extent,workers in cases():
            label=f'setup-{name}-{fixture}-{extent}-{workers}'
            prefix=out/label
            common.execute(label,[artifacts[name]['exe'],'correctness',fixture,extent,workers,1,0,0,0,0,prefix],out,env)
            record=prefix.with_suffix('.records')
            reference=legacy_out/'setup-smoke'/f'{fixture}-{extent}-4-{workers}.records.gz'
            equal_archived_files(reference,record)
            comparisons.append(dict(case=label,exact_bytes=record.stat().st_size,sha256=common.digest(record)))
            common.compress(record)
    common.write(out/'comparisons.json',comparisons)
    manifest=dict(stage='L2-prepared',source=identity(),artifacts=artifacts,legacy_manifest=str(legacy_manifest),
                  toolchain=dict(compiler=str(cxx),sha256=common.digest(cxx)),output=str(out),plan=plan())
    common.write(out/'prepared.json',manifest)
    print(f'L2 PREPARED: {out / "prepared.json"}',flush=True)


def measure(manifest_path,owner_released):
    if not owner_released:
        raise RuntimeError('Uncontended-window confirmation required before measurements')
    manifest=json.loads(manifest_path.read_text())
    if manifest['source']['files']!=identity()['files'] or manifest['plan']!=plan():
        raise RuntimeError('Prepared L2 inputs changed')
    for artifact in manifest['artifacts'].values():
        if common.digest(artifact['exe'])!=artifact['sha256']: raise RuntimeError('Prepared binary changed')
    env,cxx=common.environment()
    if common.digest(cxx)!=manifest['toolchain']['sha256']: raise RuntimeError('Compiler changed')
    out=OUT/('timing-l2-'+time.strftime('%Y%m%d-%H%M%S'))
    out.mkdir(parents=True,exist_ok=False)
    common.write(out/'identity.json',manifest)
    common.write(out/'plan.json',manifest['plan'])
    results,pairs=[],{}
    for index,row in enumerate(manifest['plan']):
        prefix=out/f'{index:03d}'
        log=common.execute(prefix.name,[manifest['artifacts'][row['variant']]['exe'],'timing',row['fixture'],row['extent'],row['workers'],row['ticks'],0,0,0,row['observer'],prefix],out,env)
        with prefix.with_suffix('.ticks.csv').open() as stream:
            ticks=list(csv.DictReader(stream))
        if len(ticks)!=1920: raise RuntimeError('Incomplete timing samples')
        result=dict(**row,prefix=str(prefix),startup_and_memory=json.loads(log.read_text()),
                    warmup=summarize_samples(ticks[:120]),steady=summarize_samples(ticks[120:]))
        key=(row['comparison'],row['fixture'],row['extent'],row['workers'],row['pair'])
        if key in pairs:
            other=pairs[key]
            left,right=Path(other['prefix']).with_suffix('.records'),prefix.with_suffix('.records')
            if row['comparison'].startswith('observer'):
                if normalized_timing_record(left,1920)!=normalized_timing_record(right,1920):
                    raise RuntimeError('Timed observer state/work mismatch')
            else:
                common.equal_files(left,right)
            control,candidate=(other,result) if row['member']==1 else (result,other)
            result['paired_p95_ratio']=candidate['steady']['p95']/control['steady']['p95']
            result['review_gt_15_percent']=result['paired_p95_ratio']>1.15
        else:
            pairs[key]=result
        results.append(result)
        common.write(out/'results.json',results)
    print(f'L2 complete: {out}',flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('prepare','plan','measure'))
    parser.add_argument('--manifest',type=Path)
    parser.add_argument('--owner-released',action='store_true')
    args=parser.parse_args()
    if ROOT!=Path('C:/kybersand/worktrees/issue-16-cell-layout'):
        raise RuntimeError('Wrong experiment workspace')
    if args.action=='plan':
        print(json.dumps(plan(),indent=2))
    elif args.manifest is None:
        parser.error('--manifest is required')
    elif args.action=='prepare':
        prepare(args.manifest.resolve())
    else:
        measure(args.manifest.resolve(),args.owner_released)


if __name__=='__main__': main()
