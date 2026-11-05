#!/usr/bin/env python3
"""Fresh optimized/strict-sanitizer native World and arrival regressions."""
import argparse
from pathlib import Path
import sol_node_trace_runtime as runtime
import la_selective_experiment as p

ROOT=runtime.ROOT

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('output',type=Path);args=parser.parse_args()
    output=args.output.resolve();assert output.is_relative_to(ROOT/'build') and not output.exists()
    info=runtime.identity();output.mkdir(parents=True);rows=[]
    tests=['la_arrival_direction','la_selective_experiment','workbench_arrivals','workbench_pressure_heads']
    test_inputs={str(f.relative_to(ROOT)):runtime.lfsha(f) for f in (ROOT/'native/tests').rglob('*') if f.is_file()}
    receipt=dict(identity=info,test_inputs=test_inputs,commands=rows)
    def run(name,argv,timeout=900):
        row=p.command(name,argv,output,timeout=timeout);rows.append(row);p.write(output/'receipt.json',receipt);assert row['clean'];return row
    linux=['wsl.exe','-d','Ubuntu-24.04','--cd',p.wsl_path(ROOT),'--']
    for variant in ['opt','san']:
        flags=['-O3','-DNDEBUG'] if variant=='opt' else ['-O1','-g1','-fno-omit-frame-pointer','-fsanitize=address,undefined','-fno-sanitize-recover=all']
        objects=[]
        for source in ['world','material_rules','scheduler_geometry','settled_world_discovery']:
            path=(output/(variant+'-'+source+'.o')).relative_to(ROOT).as_posix()
            run('compile-'+variant+'-'+source,linux+['g++','-std=c++20','-pthread','-Inative/include',*flags,'-c','native/src/'+source+'.cpp','-o',path]);objects.append(path)
        environment=['env','ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:strict_string_checks=1','UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1'] if variant=='san' else []
        for test in tests:
            binary=(output/(variant+'-'+test)).relative_to(ROOT).as_posix()
            run('link-'+variant+'-'+test,linux+['g++','-std=c++20','-pthread','-Inative/include',*flags,*objects,'native/tests/test_'+test+'.cpp','-o',binary])
            row=run('run-'+variant+'-'+test,linux+environment+[binary],180);row['binary_sha256']=runtime.sha(ROOT/binary);p.write(output/'receipt.json',receipt)
        core=output/('core-'+variant);target=(core/('tests_sanitized' if variant=='san' else 'tests')).relative_to(ROOT).as_posix()
        command=['make','BUILD_DIR='+core.relative_to(ROOT).as_posix()]
        command+=['DEBUG_FLAGS=-O3 -DNDEBUG'] if variant=='opt' else ['COMMON_FLAGS=-std=c++20 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Inative/include -fno-sanitize-recover=all']
        run('core-build-'+variant,linux+command+[target])
        row=run('core-run-'+variant,linux+environment+[target],900);row['binary_sha256']=runtime.sha(ROOT/target);p.write(output/'receipt.json',receipt)
    assert info==runtime.identity() and test_inputs=={n:runtime.lfsha(ROOT/n) for n in test_inputs}
    receipt['post_source_equality']=True;p.write(output/'receipt.json',receipt)
    return 0

if __name__=='__main__':raise SystemExit(main())
