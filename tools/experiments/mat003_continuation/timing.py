"""WCLEAR timing collector, HELD until independent admission AND owner authority.

No workflow calls this file. An admitted immutable registration is a new external
review checkpoint, not an option this program creates or upgrades.
"""
import argparse
import gzip
import hashlib
import itertools
import json
from pathlib import Path
import os
import shutil
import subprocess
import time


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def load(path): return json.loads(Path(path).read_text(encoding='utf-8'))
def require(value,message):
    if not value: raise ValueError(message)
def dump(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n',encoding='utf-8')


def gates(admission_path,authority_path):
    admission=load(admission_path)
    require(admission.get('status')=='admitted-paired-timing' and admission.get('formal_timing_admitted') is True,
            'HELD: no independent WCLEAR timing admission')
    review=admission.get('independent_review',{})
    require(review.get('decision')=='admitted' and review.get('reviewer') and
            review['reviewer']!=admission.get('author'),'HELD: independent source-bound review missing')
    authority=load(authority_path)
    require(authority.get('execution_authorized') is True and authority.get('approver') and
            authority.get('registration_sha256')==sha(admission_path),
            'HELD: explicit execution authority for this exact registration is missing')
    require(admission['proposed_process_matrix']['primary_processes']==672,'matrix changed; new collector review required')
    require(admission['epoch_bits']==[8,16,24,32] and admission['resident_sides']==[512,1024,2048] and
            admission['workers']==[1,4] and admission['scenes']==['sleep-excluded','active-window-excluded'],'unregistered context matrix')
    require(admission['proposed_process_matrix']['alternating_pair_orders']==['AB','BA','AB','BA','AB','BA','AB'],'pair order drift')
    return admission,authority


def schedule():
    rows=[]
    for bits,side,scene,workers in itertools.product((8,16,24,32),(512,1024,2048),
            ('sleep-excluded','active-window-excluded'),(1,4)):
        for pair,order in enumerate(('AB','BA','AB','BA','AB','BA','AB'),1):
            for role in order:
                rows.append(dict(index=len(rows)+1,epoch_bits=bits,side=side,scene=scene,workers=workers,pair=pair,
                                 role=role,mode='event' if role=='B' else 'ordinary'))
    return rows


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    for name in ('admission','authority','apparatus','artifact-archive','output'):
        ap.add_argument('--'+name,type=Path,required=True)
    args=ap.parse_args()
    # Admission rejection precedes directory creation, clocks or subprocesses.
    admission,authority=gates(args.admission,args.authority)
    evidence=admission['admission_evidence']
    root=args.apparatus.resolve(); out=args.output.resolve()
    require(not out.exists(),'append-only timing output already exists')
    require(sha(args.artifact_archive)==evidence['artifact_sha256'],'immutable artifact archive mismatch')
    require(sha(root/'files.json')==evidence['files_sha256'],'apparatus inventory seal mismatch')
    require(sha(root/'independent-readback.json')==evidence['readback_sha256'],'independent apparatus readback mismatch')
    require(load(root/'independent-readback.json')['status']=='qualification-readback-passed-timing-held','apparatus not independently qualified')
    apparatus=load(root/'run.json')
    require(apparatus['source_head']==evidence['source_commit'],'apparatus source mismatch')
    require(sha(Path(__file__))==evidence['timing_collector_sha256'],'collector is not the frozen admitted source')
    for name,digest in load(root/'files.json').items():
        p=(root/name).resolve()
        require(p.is_relative_to(root) and not p.is_symlink() and sha(p)==digest,'apparatus file drift: '+name)
    binaries={b['id']:b for b in load(root/'binary-seal.json')}
    out.mkdir(parents=True)
    shutil.copyfile(args.admission,out/'admission.json'); shutil.copyfile(args.authority,out/'authority.json')
    dump(out/'schedule.json',schedule())
    report=dict(status='incomplete',formal_timing_admitted=True,performance_accepted=False,processes=[],errors=[],
                apparatus_files_sha256=sha(root/'files.json'),admission_sha256=sha(args.admission),authority_sha256=sha(args.authority),
                collector_sha256=sha(Path(__file__)),source_commit=evidence['source_commit'])
    started=time.monotonic(); env=os.environ.copy()
    env['MAT003_WCLEAR_EXECUTION_AUTHORITY']=sha(args.authority)
    try:
        for row in schedule():
            require(time.monotonic()-started<admission['budgets']['timing_wall_seconds'],'wall budget exhausted; matrix incomplete')
            key=f'aligned-e{row["epoch_bits"]}-x2-o0'; b=binaries[key]
            binary=root/b['binary']
            require(sha(binary)==b['sha256'],'sealed binary changed')
            name=f'{row["index"]:03d}'
            record=dict(row,binary_sha256=b['sha256'],exit_code=None,timed_out=False)
            report['processes'].append(record)
            cmd=[str(binary),str(row['side']),str(row['workers']),row['scene'],row['mode'],str(out/'cases'/name),'255','--measure']
            record['argv']=cmd
            with (out/(name+'.stdout')).open('wb') as stdout,(out/(name+'.stderr')).open('wb') as stderr:
                try:
                    record['exit_code']=subprocess.run(cmd,env=env,stdout=stdout,stderr=stderr,
                        timeout=admission['budgets']['timing_process_seconds']).returncode
                except subprocess.TimeoutExpired: record['timed_out']=True
            # Retain every raw semantic receipt losslessly, including failures.
            for p in (out/'cases'/name).rglob('*.bin'):
                p.with_suffix('.bin.gz').write_bytes(gzip.compress(p.read_bytes(),mtime=0));p.unlink()
            dump(out/'run.json',report)
            require(record['exit_code']==0 and not record['timed_out'],'failed process; matrix incomplete')
            require(not (out/(name+'.stderr')).read_bytes().strip(),'runtime stderr; matrix incomplete')
        report['status']='collected-not-accepted'
    except Exception as error: report['errors'].append(str(error))
    finally:
        dump(out/'run.json',report)
        dump(out/'files.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='files.json'})
    if report['errors']: raise SystemExit('; '.join(report['errors']))


if __name__=='__main__': main()
