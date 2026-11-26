#!/usr/bin/env python3
"""Run unchanged lexical and proposed reference methods on the five frozen suites.

Compact reports preserve exact per-passage identities without duplicating all
raw context strings. --contexts additionally retains both complete reports in the
chosen output directory. Re-run from the recorded source/input identities to
reconstruct the actual contexts. No fixture or expectation is modified.
"""
from __future__ import annotations
import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
import statistics
import subprocess
import tempfile
import time

try:
    from . import retrieval_eval as baseline, knowledge_retrieval as proposed
except ImportError:
    import retrieval_eval as baseline
    import knowledge_retrieval as proposed

SUITES = {
    'frozen':'docs/reference/retrieval-questions-frozen32.json',
    'challenges':'docs/reference/retrieval-challenges.json',
    'renaissance':'docs/reference/retrieval-questions-docs-renaissance-v1.json',
    'owner-intent':'docs/reference/owner-intent-retrieval-questions.json',
    'historical':'docs/history/engineering/retrieval-questions.json',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def compact_hit(hit):
    return {key:hit[key] for key in ('rank','score','path','heading','part','authority') if key in hit} | {
        'context_sha256':hit['context_sha256'] if 'context_sha256' in hit else hashlib.sha256(hit['text'].encode()).hexdigest()}


def metrics(rows, k=5):
    ranks=[r['canonical_rank'] for r in rows]
    return {'questions':len(rows),'top1':sum(r==1 for r in ranks),
            'top3':sum(r is not None and r<=3 for r in ranks),'top5':sum(r is not None and r<=5 for r in ranks),
            'mrr_at_5':round(sum(1/r if r else 0 for r in ranks)/len(ranks),4)}


def run(root, output, contexts=False):
    output.mkdir(parents=True,exist_ok=True)
    shared=proposed.Retriever(root)
    reports=[]
    for name,relative in SUITES.items():
        queries=root/relative;historical=name=='historical'
        retriever=proposed.Retriever(root,historical=True) if historical else shared
        with tempfile.TemporaryDirectory(prefix='knowledge-eval-') as temp:
            raw=Path(temp)/'lexical.json'
            started=time.perf_counter()
            with contextlib.redirect_stdout(io.StringIO()):baseline.evaluate(root,queries,raw,5,420,historical)
            elapsed=time.perf_counter()-started
            original=json.loads(raw.read_text())
            proposed.evaluate(retriever,queries,Path(temp)/'proposed.json',5,True)
            candidate=json.loads((Path(temp)/'proposed.json').read_text())
            if contexts:
                (output/(name+'-lexical.json')).write_bytes(raw.read_bytes())
                (output/(name+'-lexical.contexts.md')).write_bytes(raw.with_suffix('.contexts.md').read_bytes())
                (output/(name+'-proposed.json')).write_bytes((Path(temp)/'proposed.json').read_bytes())
            rows=[]
            for old,new in zip(original['results'],candidate['results']):
                if old['id']!=new['id']:raise ValueError('Fixture order/identity changed')
                rows.append({'id':old['id'],'original_rank':old['canonical_rank'],'proposed_rank':new['canonical_rank'],
                             'original_hits':[compact_hit(h) for h in old['hits']],
                             'proposed_hits':[compact_hit(h) for h in new['hits']],
                             'primary_route':new['primary_route']})
            latency=sorted(r['elapsed_seconds']*1000 for r in candidate['results'])
            report={'suite':name,'fixture':relative,'fixture_sha256':sha(queries),
                    'original_method':original['method'],'proposed_method':proposed.METHOD,
                    'original_metrics':metrics(original['results']),'proposed_metrics':metrics(candidate['results']),
                    'original_total_seconds':round(elapsed,6),'proposed_startup_seconds':round(retriever.startup_seconds,6),
                    'proposed_query_median_ms':round(statistics.median(latency),4),
                    'proposed_query_p95_ms':round(latency[min(len(latency)-1,int(.95*len(latency)))],4),
                    'documents':len(retriever.documents),'chunks':len(retriever.chunks),
                    'source_document_bytes':sum(d['bytes'] for d in retriever.identity['documents']),
                    'serialized_chunk_bytes':len(proposed.canonical_json(retriever.chunks)),
                    'source_fingerprint':retriever.identity['source_fingerprint'],'rows':rows}
            reports.append(report)
            print(name,report['original_metrics'],'->',report['proposed_metrics'],flush=True)
    git=lambda *args:subprocess.check_output(['git','-C',str(root),*args],text=True).strip()
    result={'schema':1,'runner_sha256':sha(__file__),'authority':'historical-non-authoritative','source_head':git('rev-parse','HEAD'),
            'source_tree':git('rev-parse','HEAD^{tree}'),'dirty_paths':git('status','--porcelain').splitlines(),
            'scope':'Both methods on the same working corpus, unchanged frozen fixtures and original lexical scorer. No model run or inferred answer accuracy.',
            'method_selection':'Ranking development uses disclosed frozen/development inputs; read the accompanying independent review and holdout chronology separately.',
            'current_identity':shared.identity,
            'historical_identity':retriever.identity,
            'reports':reports}
    (output/'comparison.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--contexts',action='store_true')
    args=parser.parse_args();run(args.root.resolve(),args.output.resolve(),args.contexts)

if __name__=='__main__':main()
