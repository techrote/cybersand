"""Held C128 collector. Explicit independent admission and owner authority required."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
import verify
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def require(b,m):
 if not b:raise ValueError(m)
def dump(p,v):p.write_bytes((json.dumps(v,indent=2,sort_keys=True)+'\n').encode())
def schedule(reg):
 rows=[]
 for contrast,c in enumerate(reg['contrasts'],1):
  for pair,order in enumerate(reg['pair_orders'],1):
   for role in order:rows.append(dict(index=len(rows)+1,contrast=contrast,pair=pair,role=role,anchor=c['anchor'],arm=c['a'] if role=='A' else c['b']))
 return rows
def gates(admission,authority):
 reg=load(admission);receipt=load(authority)
 require(reg.get('status')=='admitted-paired-timing' and reg.get('formal_timing_admitted') is True,'HELD: independent admission missing')
 review=reg.get('independent_review',{})
 require(review.get('decision')=='admitted' and review.get('reviewer') and reg.get('author') and review['reviewer']!=reg['author'],'HELD: independent review missing')
 require(receipt.get('execution_authorized') is True and receipt.get('approver') and receipt.get('registration_sha256')==sha(admission),'HELD: owner exact authority missing')
 require(reg['primary_processes']==70 and len(reg['contrasts'])==5 and reg['pair_orders']==['AB','BA','AB','BA','AB','BA','AB'],'schedule drift')
 verify.check_registration(reg)
 return reg,receipt
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 for name in ['admission','authority','apparatus','archive','output']:ap.add_argument('--'+name,type=Path,required=True)
 args=ap.parse_args();reg,authority=gates(args.admission,args.authority)
 root=args.apparatus.resolve();out=args.output.resolve();e=reg['admission_evidence']
 require(not out.exists(),'append-only output exists');require(sha(args.archive)==e['artifact_sha256'],'archive mismatch')
 require(sha(root/'files.json')==e['files_sha256'] and sha(root/'independent-readback.json')==e['readback_sha256'],'qualified evidence seal drift')
 require(load(root/'independent-readback.json')['status']=='qualification-readback-passed-timing-held','apparatus not independently qualified')
 require(sha(Path(__file__))==e['collector_sha256'] and sha(Path(__file__).with_name('verify.py'))==e['verifier_sha256'],'frozen tool mismatch')
 require(load(root/'run.json')['source_head']==e['source_commit'],'qualified source mismatch')
 frozen=root/'source/tools/experiments/mat003_c128'
 require(sha(frozen/'measure.py')==e['collector_sha256'] and sha(frozen/'verify.py')==e['verifier_sha256'],'qualified tools mismatch')
 manifest=load(root/'files.json')
 actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name not in ('files.json','independent-readback.json')}
 require(actual==set(manifest),'apparatus inventory mismatch')
 for name,digest in manifest.items():
  p=(root/name).resolve();require(p.is_relative_to(root) and not p.is_symlink() and sha(p)==digest,'apparatus file drift '+name)
 builds={b['id']:b for b in load(root/'binary-seal.json')};expected=schedule(reg);require(len(expected)==70,'invalid matrix')
 for arm in reg['arms']:
  b=builds[arm['id']+'-o0'];p=(root/b['binary']).resolve();require(p.is_relative_to(root/'bin') and not p.is_symlink() and sha(p)==b['sha256'],'unsafe or changed timing binary')
 out.mkdir(parents=True);(out/'admission.json').write_bytes(args.admission.read_bytes());(out/'authority.json').write_bytes(args.authority.read_bytes());dump(out/'schedule.json',expected)
 report=dict(status='incomplete',performance_accepted=False,processes=[],errors=[],source_head=load(root/'run.json')['source_head'],admission_sha256=sha(args.admission),authority_sha256=sha(args.authority),collector_sha256=sha(Path(__file__)))
 started=time.monotonic()
 try:
  for row in expected:
   require(time.monotonic()-started<reg['budgets']['timing_wall_seconds'],'wall budget exhausted')
   anchor=next(a for a in reg['anchors'] if a['id']==row['anchor'])
   build=builds[row['arm']+'-o0'];binary=root/build['binary'];require(sha(binary)==build['sha256'],'binary drift');binary.chmod(binary.stat().st_mode|0o100)
   name=f"{row['index']:03d}";cmd=[str(binary),'--side',str(anchor['side']),'--workers',str(anchor['workers']),'--warmup','120','--ticks','256','--seed','204','--scenario',anchor['scenario'],'--mode','measure']
   receipt=dict(row,argv=cmd,binary_sha256=build['sha256'],exit_code=None,timed_out=False);report['processes'].append(receipt)
   with (out/(name+'.stdout')).open('wb') as stdout,(out/(name+'.stderr')).open('wb') as stderr:
    try:receipt['exit_code']=subprocess.run(cmd,stdout=stdout,stderr=stderr,timeout=reg['budgets']['process_seconds']).returncode
    except subprocess.TimeoutExpired:receipt['timed_out']=True
   dump(out/'run.json',report)
   require(receipt['exit_code']==0 and not receipt['timed_out'] and not (out/(name+'.stderr')).read_bytes().strip(),'failed process; retain incomplete matrix')
  report['status']='collected-not-accepted'
 except Exception as error:report['errors'].append(str(error))
 finally:
  dump(out/'run.json',report);dump(out/'files.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='files.json'})
 if report['errors']:raise ValueError(report['errors'])
if __name__=='__main__':main()
