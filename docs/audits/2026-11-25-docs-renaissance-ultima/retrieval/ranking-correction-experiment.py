from pathlib import Path
import argparse,hashlib,json,math,sys,time,subprocess
from collections import Counter
parser=argparse.ArgumentParser(description='Reproduce predeclared source-bound ranking controls; no heldout inputs.')
parser.add_argument('--root',type=Path,required=True)
parser.add_argument('--baseline',type=Path,required=True,help='Actual v1 evaluate_knowledge --contexts output directory')
parser.add_argument('--records',type=Path,default=Path(__file__).parent,help='Directory containing unchanged preregistration and development fixture')
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
ROOT=args.root.resolve()
OUT=args.records.resolve()
if args.output.exists():parser.error('Refusing to overwrite existing experiment evidence')
sys.path.insert(0,str(ROOT/'tools/docs'))
import knowledge_retrieval as k
import evaluate_knowledge as e
MODES=('v1','field-bonus-rollback','coverage-scaled-field-bonus')
def rank(r,q,mode,nwanted=5):
    words=sorted(set(k.baseline.tokens(q)));scores=[];n=len(r.chunks)
    for i,count in enumerate(r.counts):
        body=0.;bonus=0.;matched=0
        for word in words:
            if not count[word]: continue
            matched+=1;idf=math.log(1+(n-r.df[word]+.5)/(r.df[word]+.5));f=count[word]
            body+=idf*f*2.2/(f+1.2*(.25+.75*r.lengths[i]/r.mean))
            bonus+=idf*(.7*(word in r.heading_terms[i])+.2*(word in r.title_terms[i]))
        if mode=='field-bonus-rollback':bonus=0.
        elif mode=='coverage-scaled-field-bonus':bonus*=matched/max(1,len(words))
        scores.append(body+bonus)
    ordered=sorted(range(n),key=lambda i:(-scores[i],r.chunks[i]['path'],r.chunks[i]['heading'],r.chunks[i]['part']))
    chosen=[];seen=set()
    for i in ordered:
        path=r.chunks[i]['path']
        if scores[i]>0 and path not in seen:chosen.append(i);seen.add(path)
        if len(chosen)==nwanted:break
    route=None
    if chosen and nwanted>1 and not r.identity['historical']:
        first=r.chunks[chosen[0]]['path'];links=set(r.documents[first]['links'])
        primary=next((i for i in ordered if scores[i]>0 and r.chunks[i]['authority']=='owner-confirmed-intent' and r.documents[r.chunks[i]['path']]['path'] in links),None)
        if primary is not None and r.chunks[primary]['path'] not in seen:
            chosen.insert(1,primary);chosen=chosen[:nwanted];route={'from':first,'to':r.chunks[primary]['path']}
    return [{'path':r.chunks[i]['path'],'heading':r.chunks[i]['heading'],'id':r.chunks[i]['id'],'context_sha256':r.chunks[i]['context_sha256'],'score':round(scores[i],6)} for i in chosen],route
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
cur=k.Retriever(ROOT);hist=k.Retriever(ROOT,historical=True)
reports=[]
suites=e.SUITES|{'development':str(OUT/'ranking-development-v1.json')}
for name,path in suites.items():
    fixture=Path(path) if name=='development' else ROOT/path
    questions=json.loads(fixture.read_text())['questions'];r=hist if name=='historical' else cur;rows=[]
    old={} if name=='development' else {x['id']:x for x in json.loads((args.baseline/(name+'-proposed.json')).read_text())['results']}
    for q in questions:
        modes={}
        for mode in MODES:
            hits,route=rank(r,q['query'],mode)
            if mode=='v1' and name!='development':
                assert [h['id'] for h in hits]==[h['id'] for h in old[q['id']]['hits']]
                assert [h['score'] for h in hits]==[h['score'] for h in old[q['id']]['hits']]
            canonical_rank=next((i+1 for i,h in enumerate(hits) if h['path'] in q['canonical']),None)
            modes[mode]={'canonical_rank':canonical_rank,'hits':hits,'primary_route':route}
        rows.append({'id':q['id'],'query':q['query'],'methods':modes})
    report={'suite':name,'fixture_sha256':sha(fixture),'metrics':{},'rows':rows}
    for mode in MODES:
        report['metrics'][mode]=e.metrics([{'canonical_rank':x['methods'][mode]['canonical_rank']} for x in rows])
    reports.append(report);print(name,report['metrics'],flush=True)
for r in (cur,hist):
    identity,_=k.source_snapshot(ROOT,r.identity['historical'],420,include_chunks=False)
    assert identity==r.identity
result={'schema':1,'authority':'historical-non-authoritative','source_head':subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip(),'current_fingerprint':cur.identity['source_fingerprint'],'historical_fingerprint':hist.identity['source_fingerprint'],'experiment_code_sha256':sha(Path(__file__)),'preregistration_sha256':sha(OUT/'ranking-correction-preregistration.json'),'v1_equivalence':'All248 previous v1 top5 IDs and scores byte-value equal to actual public adapter execution','scope':'Pure rank experiment over immutable source-bound chunks; freshness/ingestion/consumer tests remain separate. No heldout inputs.','reports':reports}
args.output.parent.mkdir(parents=True,exist_ok=True)
with args.output.open('x',encoding='utf-8') as stream:stream.write(json.dumps(result,indent=2)+'\n')
