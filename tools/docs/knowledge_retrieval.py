#!/usr/bin/env python3
"""Local source-bound reference retriever/agent context adapter; no model or network.

The unchanged retrieval_eval.py remains the lexical baseline. This proposed
method adds explicit heading/title fields, document diversity, and one bounded
route to a linked primary owner-intent record. All returned text is rehydrated
from current permitted source, including when a persisted snapshot is supplied.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import date
import hashlib
import json
import math
import os
from pathlib import Path
import re
import tempfile
import time
from urllib.parse import unquote, urlsplit

try:
    from . import retrieval_eval as baseline
    from .retrieval_policy import POLICY_VERSION, HISTORICAL_AUTHORITY, source_frontmatter, scalar
except ImportError:
    import retrieval_eval as baseline
    from retrieval_policy import POLICY_VERSION, HISTORICAL_AUTHORITY, source_frontmatter, scalar

METHOD = 'source-bound-field-bm25-v2'
REQUIRED = {'title', 'status', 'document-kind', 'scope', 'canonical-for', 'last-reviewed', 'related-documents'}
LINKS = re.compile(r'\[[^\]]+\]\(([^\s)]+)(?:\s+[^)]*)?\)')


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def no_duplicate_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: '+key)
        result[key] = value
    return result


def read_json(path: Path):
    return json.loads(path.read_text(encoding='utf-8-sig'), object_pairs_hook=no_duplicate_pairs)


def relative_path(path: Path, root: Path) -> str:
    return path.relative_to(root/'docs').as_posix() if path.is_relative_to(root/'docs') else '../'+path.name


def local_links(path: Path, root: Path) -> list[str]:
    """Return existing within-repository links without opening or ingesting them."""
    result = set()
    for target in LINKS.findall(path.read_text(encoding='utf-8-sig')):
        url = urlsplit(target)
        if url.scheme or url.netloc or not url.path:
            continue
        candidate = (path.parent/unquote(url.path)).resolve()
        if candidate.is_relative_to(root) and candidate.is_file():
            result.add(candidate.relative_to(root).as_posix())
    return sorted(result)


def validate_current_metadata(path: Path) -> dict:
    metadata = source_frontmatter(path)
    missing = REQUIRED-set(metadata)
    if missing:
        raise ValueError('Incomplete current-source metadata: '+str(path)+'; '+', '.join(sorted(missing)))
    date.fromisoformat(scalar(metadata['last-reviewed']))
    if any(not scalar(metadata[key]) for key in ('title','status','document-kind','scope')):
        raise ValueError('Empty current-source metadata: '+str(path))
    return metadata


def source_snapshot(root: Path, historical: bool, max_words: int, *, include_chunks=True) -> tuple[dict, list[dict]]:
    root = root.resolve()
    manifest = root/'docs'/('history/engineering/retrieval-corpus.json' if historical else 'reference/retrieval-corpus.json')
    if manifest.is_file():
        declared = read_json(manifest)
        if not isinstance(declared, dict) or not isinstance(declared.get('documents'), list) or not declared['documents']:
            raise ValueError('Corpus manifest needs a nonempty documents array')
    paths = baseline.selected_paths(root, historical=historical)
    chunks, documents = [], []
    for path in paths:
        metadata = source_frontmatter(path) if historical else validate_current_metadata(path)
        data = path.read_bytes()
        doc_sha = digest(data)
        authority = HISTORICAL_AUTHORITY if historical else scalar(metadata.get('authority','current-documentation'))
        documents.append({'path': path.relative_to(root).as_posix(), 'sha256': doc_sha, 'bytes': len(data),
                          'authority': authority, 'status': scalar(metadata.get('status','unlabelled')),
                          'document_kind': scalar(metadata.get('document-kind','unlabelled')),
                          'links': local_links(path, root)})
        if include_chunks:
            for chunk in baseline.chunk_document(path, root, max_words, historical=historical):
                chunk = {**chunk, 'source_sha256': doc_sha, 'context_sha256': digest(chunk['text'].encode()),
                         'status': scalar(metadata.get('status','unlabelled')),
                         'document_kind': scalar(metadata.get('document-kind','unlabelled'))}
                chunk['id'] = digest(canonical_json([chunk['path'],chunk['heading'],chunk['part'],chunk['context_sha256']]))
                chunks.append(chunk)
    if not documents or (include_chunks and not chunks):
        raise ValueError('No permitted source contexts')
    helpers = {p.name:digest(p.read_bytes()) for p in (Path(__file__), Path(baseline.__file__), Path(baseline.__file__).with_name('retrieval_policy.py'))}
    # Track linked executable/configuration source independently of prose. A
    # changed lock/API/script invalidates an old agent context even if a manual
    # has not yet been updated. History and images are not auto-ingested.
    source_extensions={'.cpp','.c','.h','.hpp','.gd','.py','.json','.yml','.yaml','.toml','.txt','.tscn','.gdextension','.sh','.ps1','.bat','.cmd'}
    source_inputs=[]
    for target in sorted({link for document in documents for link in document['links']}):
        source=root/target
        if not target.startswith(('docs/history/','docs/audits/')) and source.suffix in source_extensions:
            source_inputs.append({'path':target,'sha256':digest(source.read_bytes()),'bytes':source.stat().st_size})
    identity = {'schema':1, 'method':METHOD, 'policy':POLICY_VERSION, 'historical':historical, 'max_words':max_words,
                'manifest_sha256':digest(manifest.read_bytes()) if manifest.is_file() else None,
                'helpers':helpers,'documents':documents,'linked_source_inputs':source_inputs}
    identity['source_fingerprint'] = digest(canonical_json(identity))
    return identity, chunks


def validate_cache_path(root: Path, cache: Path) -> None:
    """Derived snapshots may never replace repository source or Git metadata."""
    resolved = cache.resolve()
    if resolved.is_relative_to(root.resolve()):
        raise ValueError('Cache must be outside the source repository')
    for directory in (resolved.parent, *resolved.parents):
        if directory.name == '.git' or (directory/'.git').exists() or ((directory/'HEAD').is_file() and (directory/'objects').is_dir() and (directory/'refs').is_dir()):
            raise ValueError('Cache must be outside every Git worktree and metadata directory')


def load_snapshot(root: Path, historical=False, max_words=420, cache: Path | None=None):
    """Validate persisted snapshots against fresh source; remove obsolete contexts.

    This small corpus favors full freshness verification over trusting a stale
    vector store. The snapshot supports custody/reuse, not a promised speedup.
    No cache can supply text, selection or authority independently of source.
    """
    if cache is not None:
        validate_cache_path(root, cache)
    identity, chunks = source_snapshot(root, historical, max_words)
    state = 'not-requested'
    if cache is not None:
        state = 'created'
        if cache.exists():
            try:
                saved = read_json(cache)
                if saved['identity'] == identity and saved['chunks'] == chunks and saved['payload_sha256'] == digest(canonical_json([identity,chunks])):
                    state = 'validated-current'
                else:
                    state = 'rebuilt-stale-or-corrupt'
            except (OSError, ValueError, KeyError, TypeError):
                state = 'rebuilt-stale-or-corrupt'
        if state != 'validated-current':
            cache.parent.mkdir(parents=True, exist_ok=True)
            payload = {'identity':identity,'chunks':chunks,'payload_sha256':digest(canonical_json([identity,chunks]))}
            name = None
            try:
                with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=cache.parent,prefix='.'+cache.name+'.',delete=False) as staged:
                    name = staged.name
                    json.dump(payload, staged, ensure_ascii=False, separators=(',',':'))
                    staged.flush()
                os.replace(name,cache)
                name = None
            finally:
                if name is not None:
                    Path(name).unlink(missing_ok=True)
    return identity,chunks,state


class Retriever:
    def __init__(self, root: Path, *, historical=False, max_words=420, cache: Path | None=None):
        if max_words < 1:
            raise ValueError('max_words must be positive')
        start = time.perf_counter()
        self.root = root.resolve()
        self.identity,self.chunks,self.cache_state = load_snapshot(self.root,historical,max_words,cache)
        self.counts = [Counter(baseline.tokens(chunk['text'])) for chunk in self.chunks]
        self.lengths = [sum(c.values()) for c in self.counts]
        self.mean = sum(self.lengths)/len(self.lengths)
        self.df = Counter(term for count in self.counts for term in count)
        self.heading_terms = [set(baseline.tokens(c['heading'])) for c in self.chunks]
        self.title_terms = [set(baseline.tokens(c['title'])) for c in self.chunks]
        self.documents = {relative_path(self.root/d['path'],self.root):d for d in self.identity['documents']}
        self.startup_seconds = time.perf_counter()-start

    def query(self, query: str, k=5) -> dict:
        if k < 1:
            raise ValueError('k must be positive')
        started = time.perf_counter()
        current,_=source_snapshot(self.root,self.identity['historical'],self.identity['max_words'],include_chunks=False)
        if current != self.identity:
            raise ValueError('Stale retriever instance: source changed; rebuild before querying')
        words = sorted(set(baseline.tokens(query)))
        scores=[]
        n=len(self.chunks)
        for index,count in enumerate(self.counts):
            score=0.0
            field_bonus=0.0
            matched=0
            for word in words:
                if not count[word]:
                    continue
                matched+=1
                idf=math.log(1+(n-self.df[word]+.5)/(self.df[word]+.5))
                freq=count[word]
                score += idf*freq*2.2/(freq+1.2*(.25+.75*self.lengths[index]/self.mean))
                field_bonus += idf*(.7*(word in self.heading_terms[index])+.2*(word in self.title_terms[index]))
            # The BM25 text already contains these fields. Bound their extra
            # influence by query coverage: one ambiguous heading word must not
            # receive the full bonus for a longer, more specific question.
            score += field_bonus*matched/max(1,len(words))
            scores.append(score)
        ordered=sorted(range(n),key=lambda i:(-scores[i],self.chunks[i]['path'],self.chunks[i]['heading'],self.chunks[i]['part']))
        chosen=[]
        seen=set()
        for index in ordered:
            path=self.chunks[index]['path']
            if scores[index] > 0 and path not in seen:
                chosen.append(index);seen.add(path)
            if len(chosen)==k:
                break
        route=None
        # Follow only a declared, selected current primary-intent source from
        # the best document. No archive, audit, fixture target or path lookup.
        if chosen and k > 1 and not self.identity['historical']:
            first=self.chunks[chosen[0]]['path']
            links=set(self.documents[first]['links'])
            primary=next((i for i in ordered if scores[i] > 0 and self.chunks[i]['authority']=='owner-confirmed-intent'
                          and self.documents[self.chunks[i]['path']]['path'] in links),None)
            if primary is not None and self.chunks[primary]['path'] not in seen:
                chosen.insert(1,primary);chosen=chosen[:k]
                route={'from':first,'to':self.chunks[primary]['path'],'reason':'linked-primary-owner-intent','one_hop':True}
        hits=[{'rank':rank+1,'score':round(scores[index],6),**self.chunks[index]} for rank,index in enumerate(chosen)]
        routes=[]
        for hit in hits:
            for target in self.documents[hit['path']]['links']:
                historical_target = target.startswith(('docs/history/','docs/audits/'))
                routes.append({'from':hit['path'],'target':target,'authority':'historical-non-authoritative' if historical_target else 'inspect-source',
                               'automatic_ingestion':False,'requires_explicit_history':historical_target})
        return {'method':METHOD,'query':query,'source_fingerprint':self.identity['source_fingerprint'],
                'historical_opt_in':self.identity['historical'],'cache_state':self.cache_state,
                'answer_scope':'Retrieved source contexts only; no generative answer or implementation authorization.',
                'abstention':not hits,'primary_route':route,'hits':hits,'source_routes':routes,
                'elapsed_seconds':time.perf_counter()-started}

    def read_source(self, result: dict, target: str) -> dict:
        """Agent's explicit second step: follow one current in-repository source.

        Historical routes are never followed by current mode. A model is not
        executed. The caller receives source identity and must interpret it.
        """
        # Refresh current selection and bytes before accepting a cached result.
        current,_=source_snapshot(self.root,self.identity['historical'],self.identity['max_words'],include_chunks=False)
        if current['source_fingerprint'] != self.identity['source_fingerprint'] or result.get('source_fingerprint') != self.identity['source_fingerprint']:
            raise ValueError('Stale context: rebuild and retrieve again before following source')
        allowed={route['target']:route for route in result.get('source_routes',[])}
        # Recompute allowed links from actual returned contexts, not caller data.
        admitted_ids={chunk['id']:chunk for chunk in self.chunks}
        actual_targets=set()
        for hit in result.get('hits',[]):
            expected=admitted_ids.get(hit.get('id'))
            if expected is None or any(hit.get(k)!=expected[k] for k in expected):
                raise ValueError('Altered context cannot authorize source access')
            actual_targets.update(self.documents[hit['path']]['links'])
        if target not in allowed or target not in actual_targets:
            raise ValueError('Source was not linked from the supplied verified contexts')
        path=(self.root/target).resolve()
        if not path.is_relative_to(self.root) or not path.is_file():
            raise ValueError('Source route left repository or no longer exists')
        is_history=path.relative_to(self.root).as_posix().startswith(('docs/history/','docs/audits/'))
        if is_history and not self.identity['historical']:
            raise ValueError('Historical source requires explicit historical retrieval')
        if path.suffix=='.md' and not is_history:
            selected={d['path'] for d in self.identity['documents']}
            if path.relative_to(self.root).as_posix() not in selected:
                raise ValueError('Linked Markdown is not an admitted answer document; use navigation manually')
        data=path.read_bytes()
        if len(data)>1_000_000:
            raise ValueError('Source too large for bounded context; inspect explicitly outside adapter')
        return {'path':target,'sha256':digest(data),'bytes':len(data),'authority':HISTORICAL_AUTHORITY if is_history else 'source-inspection-not-acceptance',
                'text':data.decode('utf-8'),'permission':'Reading this source grants no execution permission'}


def evaluate(retriever: Retriever, fixture: Path, output: Path, k=5, contexts=False) -> dict:
    questions=read_json(fixture)['questions'];rows=[]
    for question in questions:
        result=retriever.query(question['query'],k)
        rank=next((h['rank'] for h in result['hits'] if h['path'] in question['canonical']),None)
        row={**question,'canonical_rank':rank,**{key:result[key] for key in ('primary_route','elapsed_seconds','abstention')}}
        row['hits']=result['hits'] if contexts else [{key:hit[key] for key in ('rank','score','id','path','heading','part','authority','status','document_kind','source_sha256','context_sha256')} for hit in result['hits']]
        rows.append(row)
    summary={'questions':len(rows),'canonical_hit_at_1':sum(r['canonical_rank']==1 for r in rows),
             'canonical_hit_at_3':sum(r['canonical_rank'] is not None and r['canonical_rank']<=3 for r in rows),
             'canonical_hit_at_5':sum(r['canonical_rank'] is not None and r['canonical_rank']<=5 for r in rows),
             'canonical_hit_at_k':sum(r['canonical_rank'] is not None for r in rows),
             'mrr_at_k':round(sum(1/r['canonical_rank'] if r['canonical_rank'] else 0 for r in rows)/len(rows),4),
             'historical_authority_violations':sum(h['authority'] != HISTORICAL_AUTHORITY if retriever.identity['historical'] else h['authority']==HISTORICAL_AUTHORITY for r in rows for h in r['hits']),
             'answer_sufficiency':'Not inferred from canonical recall; independent source/context review required.',
             'mean_query_ms':round(1000*sum(r['elapsed_seconds'] for r in rows)/len(rows),3)}
    report={'method':METHOD,'historical_opt_in':retriever.identity['historical'],'k':k,'fixture_sha256':digest(fixture.read_bytes()),
            'identity':retriever.identity,'document_count':len(retriever.documents),'chunk_count':len(retriever.chunks),
            'startup_seconds':retriever.startup_seconds,'summary':summary,'results':rows}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    return summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--historical',action='store_true')
    parser.add_argument('--cache',type=Path)
    parser.add_argument('--query')
    parser.add_argument('--queries',type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--k',type=int,default=5)
    parser.add_argument('--contexts',action='store_true')
    parser.add_argument('--source',help='Explicitly follow this exact source route from --query')
    args=parser.parse_args()
    retriever=Retriever(args.root,historical=args.historical,cache=args.cache)
    if args.queries:
        if not args.output:parser.error('--queries requires --output')
        print(json.dumps(evaluate(retriever,args.queries,args.output,args.k,args.contexts),indent=2))
    elif args.query:
        result=retriever.query(args.query,args.k)
        if args.source:result['followed_source']=retriever.read_source(result,args.source)
        rendered=json.dumps(result,indent=2,ensure_ascii=False)+'\n'
        if args.output:args.output.write_text(rendered,encoding='utf-8')
        else:print(rendered)
    else:parser.error('Supply --query or --queries')

if __name__=='__main__':
    main()
