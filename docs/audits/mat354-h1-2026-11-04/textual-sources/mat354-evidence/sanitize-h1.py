#!/usr/bin/env python3
"""Bounded local H1 sanitizer execution; original attempts are never overwritten."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', choices=('asan-ubsan', 'tsan'), required=True)
    parser.add_argument('--reuse-build', type=Path)
    parser.add_argument('--disable-leak-check', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    spec = importlib.util.spec_from_file_location('frozen_run', root/'tools/material_liveness/run.py')
    run = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(run)
    out = run.output_directory(args.output, root)
    receipt = {'schema': 'mat354.h1.local-sanitizers.v1', 'status': 'INITIALIZING',
               'mode': args.mode, 'started_utc': run.now(), 'host': run.cpu_identity(),
               'driver': run.fact(Path(__file__)), 'steps': [], 'executions': [],
               'scope': 'new full H1 regressions plus selected actual distributed and Water controls; not full ordinary sanitizer CI'}
    path = out/'receipt.json'
    run.write_json(path, receipt)
    try:
        head = run.git(root, 'rev-parse', 'HEAD')
        status = run.git(root, 'status', '--porcelain=v1', '--untracked-files=all')
        if status:
            raise run.EvidenceError('source checkout is not clean: '+status)
        sources = [root/'native/tests/test_mat354_h1.cpp']+[root/p for p in run.DEFAULT_SOURCES[1:]]
        inputs = run.inventory(root, [str(p.relative_to(root)) for p in sources],
                               [root/'native/tests/material_liveness_probe.cpp',
                                root/'native/tests/fixtures/material_liveness_h1_v1.json',
                                root/'materials/catalogue/h1-source-transition.json',
                                root/'tools/material_catalogue/h1_transition.py'])
        receipt['source'] = {'commit': head, 'tree': run.git(root, 'rev-parse', 'HEAD^{tree}'),
                             'inputs': inputs, 'committed_input_check': run.committed_input_check(root, inputs, head),
                             'guard': run.protected_check(root)}
        if receipt['source']['committed_input_check']['status'] != 'PASS':
            raise run.EvidenceError('raw inputs differ from committed source')
        compiler = str(Path(shutil.which('g++-13')).resolve())
        receipt['compiler'] = run.fact(Path(compiler))
        receipt['compiler_version'] = run.process([compiler, '--version'], root, out/'compiler-version', 30)
        flags = run.compiler_flags(args.mode, os.name)+['-I'+str(root/'native/include'), '-I'+str(root/'native/tests')]
        receipt['flags'] = flags
        deadline = time.monotonic()+1800
        if args.reuse_build:
            old = run.load_json(args.reuse_build)
            for key in ('source', 'compiler', 'flags', 'mode'):
                if old[key] != receipt[key]:
                    raise run.EvidenceError('reused sanitizer build identity changed: '+key)
            receipt['executable'] = old['executable']
            if run.fact(Path(old['executable']['path'])) != old['executable']:
                raise run.EvidenceError('reused executable bytes changed')
            receipt['reused_build'] = run.fact(args.reuse_build)
            receipt['dependencies'] = old['dependencies']
        else:
            build_deadline = time.monotonic()+900
            objects=[]
            for i, source in enumerate(sources):
                obj=out/f'input-{i}.o'
                result=run.process([compiler,*flags,'-MMD','-MF',str(out/f'input-{i}.d'),
                                    '-c',str(source),'-o',str(obj)],out,out/f'compile-{i}',
                                   run.remaining_budget(build_deadline,deadline))
                receipt['steps'].append(result)
                run.write_json(path,receipt)
                if result['returncode'] != 0 or result['timed_out']:
                    raise run.EvidenceError('sanitizer compilation failed; original evidence retained')
                objects.append(str(obj))
            executable=out/'mat354_h1_sanitized'
            result=run.process([compiler,*flags,*objects,'-o',str(executable)],out,out/'link',
                               run.remaining_budget(build_deadline,deadline))
            receipt['steps'].append(result)
            if result['returncode'] != 0 or result['timed_out']:
                raise run.EvidenceError('sanitizer link failed')
            receipt['executable']=run.fact(executable)
            receipt['dependencies']=run.actual_dependencies(root,sorted(out.glob('input-*.d')),out)
        environment,metadata,leak_check=run.sanitizer_configuration(args.mode,args.disable_leak_check,os.environ)
        receipt['sanitizer_environment']=metadata
        receipt['leak_check']=leak_check
        receipt['status']='RUNNING'
        run.write_json(path,receipt)
        plan=run.load_json(root/'native/tests/fixtures/material_liveness_h1_v1.json')
        historical=run.load_json(root/'native/tests/fixtures/material_liveness_campaign_v1.json')
        selected=[]
        seen=set()
        for case in historical['cases']:
            key=(case['fixture'],case['workers'])
            if (case['id'] in plan['phase_a_case_ids'] and
                case['fixture'] in {'distributed_molten','distributed_water','water_pf','water_in'} and key not in seen):
                selected.append(case)
                seen.add(key)
        executions=[('full-h1-regressions',['--regress'])]+[(c['id'],c['argv']) for c in selected]
        for name,argv in executions:
            result=run.process([receipt['executable']['path'],*argv],root,out/name,
                               min(60,run.remaining_budget(deadline)),environment,
                               generated_executable=receipt['executable'],artifact_directory=Path(receipt['executable']['path']).parent)
            receipt['executions'].append({'case':name,**result})
            run.write_json(path,receipt)
            if result['returncode'] != 0 or result['timed_out']:
                raise run.EvidenceError('sanitizer execution failed: '+name+'; original stdout/stderr retained')
        if run.inventory(root,[str(p.relative_to(root)) for p in sources],
                         [root/'native/tests/material_liveness_probe.cpp',
                          root/'native/tests/fixtures/material_liveness_h1_v1.json',
                          root/'materials/catalogue/h1-source-transition.json',
                          root/'tools/material_catalogue/h1_transition.py']) != inputs:
            raise run.EvidenceError('source inputs changed during sanitizer execution')
        if run.fact(Path(receipt['executable']['path'])) != receipt['executable']:
            raise run.EvidenceError('executable changed during sanitizer execution')
        receipt['status']='EXECUTED'
    except Exception as exc:
        receipt['status']='FAILED'
        receipt['failure']=type(exc).__name__+': '+str(exc)
    finally:
        receipt['finished_utc']=run.now()
        run.write_json(path,receipt)
    print(json.dumps({'status':receipt['status'],'receipt':str(path),'failure':receipt.get('failure')}))
    return 0 if receipt['status']=='EXECUTED' else 1


if __name__=='__main__':
    raise SystemExit(main())
