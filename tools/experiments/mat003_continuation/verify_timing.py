"""Independent complete-matrix WCLEAR timing readback. Never grants acceptance."""
import argparse
import gzip
import hashlib
import itertools
import json
import math
from pathlib import Path
import statistics


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p): return json.loads(p.read_text(encoding='utf-8'))
def require(b,message):
    if not b: raise ValueError(message)


def summary(values):
    median=statistics.median(values); ordered=sorted(values)
    return dict(values=values,median=median,minimum=min(values),maximum=max(values),
                mad=statistics.median(abs(v-median) for v in values),
                p50=ordered[math.ceil(.50*len(values))-1],p95=ordered[math.ceil(.95*len(values))-1],
                p99=ordered[math.ceil(.99*len(values))-1],observed_maximum=max(values))


def verify(root,apparatus):
    result=dict(status='failed',performance_accepted=False,errors=[],processes=0,contexts={})
    try:
        files=load(root/'files.json')
        actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name not in ('files.json','independent-timing-readback.json')}
        require(set(files)==actual,'missing or extra raw evidence')
        for name,digest in files.items():
            p=(root/name).resolve()
            require(p.is_relative_to(root.resolve()) and not p.is_symlink() and sha(p)==digest,'unsafe/mismatched evidence file')
        r=load(root/'run.json'); admission=load(root/'admission.json'); authority=load(root/'authority.json')
        require(admission['status']=='admitted-paired-timing' and admission['formal_timing_admitted'] is True,'no independent admission')
        review=admission['independent_review']
        require(review['decision']=='admitted' and review['reviewer'] and review['reviewer']!=admission['author'],'independent review absent')
        require(authority['execution_authorized'] is True and authority['approver'] and authority['registration_sha256']==sha(root/'admission.json'),'exact execution authority absent')
        e=admission['admission_evidence']
        require(sha(Path(__file__))==e['timing_verifier_sha256'],'not the frozen independent verifier')
        require(sha(apparatus/'files.json')==e['files_sha256'] and sha(apparatus/'independent-readback.json')==e['readback_sha256'],'qualified apparatus mismatch')
        require(r['status']=='collected-not-accepted' and not r['errors'] and r['formal_timing_admitted'] is True,'incomplete timing campaign')
        require(r['admission_sha256']==sha(root/'admission.json') and r['authority_sha256']==sha(root/'authority.json'),'approval identity drift')
        require(r['collector_sha256']==e['timing_collector_sha256'] and r['source_commit']==e['source_commit'],'collector/source identity drift')
        expected=[]
        for bits,side,scene,workers in itertools.product((8,16,24,32),(512,1024,2048),('sleep-excluded','active-window-excluded'),(1,4)):
            for pair,order in enumerate(('AB','BA','AB','BA','AB','BA','AB'),1):
                for role in order:
                    expected.append(dict(index=len(expected)+1,epoch_bits=bits,side=side,scene=scene,workers=workers,
                                         pair=pair,role=role,mode='event' if role=='B' else 'ordinary'))
        require(load(root/'schedule.json')==expected and len(r['processes'])==672,'complete672-process schedule required')
        binaries={b['id']:b for b in load(apparatus/'binary-seal.json')}
        contexts={}
        for row,spec in zip(r['processes'],expected):
            require(all(row[k]==v for k,v in spec.items()),'process/pair order mismatch')
            require(row['exit_code']==0 and row['timed_out'] is False,'failed observation retained: matrix cannot pass')
            identifier=f'aligned-e{spec["epoch_bits"]}-x2-o0'; binary=binaries[identifier]
            require(row['binary_sha256']==binary['sha256'] and sha(apparatus/binary['binary'])==binary['sha256'],'binary identity mismatch')
            name=f'{spec["index"]:03d}'; argv=row['argv']
            require(Path(argv[0]).name==Path(binary['binary']).name and argv[1:5]==[str(spec['side']),str(spec['workers']),spec['scene'],spec['mode']] and
                    Path(argv[5]).name==name and argv[6:]==['255','--measure'],'timing invocation differs from registration')
            require(not (root/(name+'.stderr')).read_bytes().strip(),'runtime stderr')
            lines=(root/(name+'.stdout')).read_text().splitlines();require(len(lines)==2,'raw semantic/latency record missing')
            semantic= json.loads(lines[0]); observation=json.loads(lines[1]);event=spec['role']=='B'
            require((semantic['epoch_bits'],semantic['side'],semantic['workers'],semantic['event'])==(spec['epoch_bits'],spec['side'],spec['workers'],event),'semantic context mismatch')
            require(semantic['qualification_only'] is False and semantic['clear_count']==int(event) and semantic['completed_event_tick']==256 and
                    semantic['resident_cells']==spec['side']**2 and semantic['stride']==16,'clear/work identity mismatch')
            require(semantic['natural_event']==(event and spec['epoch_bits']==8) and semantic['prepared_event']==(event and spec['epoch_bits']!=8),'natural/prepared identity mismatch')
            require(observation['measurement'] is True and all(type(observation[k]) is int and observation[k]>=0 for k in
                ('tick_ns','startup_ns','setup_ns','input_ns','peak_rss_kib')) and observation['tick_ns']>0 and observation['peak_rss_kib']>0,'invalid latency/RSS observation')
            control=f'aligned-e{spec["epoch_bits"]}-x2-o0-{spec["side"]}-{spec["scene"]}-w{spec["workers"]}-{spec["mode"]}'
            for filename in ['pre.bin','post.bin']+[f'reentry-{i}.bin' for i in range(4)]:
                measured=gzip.decompress((root/'cases'/name/(filename+'.gz')).read_bytes())
                qualified=gzip.decompress((apparatus/'cases'/control/(filename+'.gz')).read_bytes())
                require(measured==qualified,'timing-mode semantic stream differs from qualified observer-off twin')
            key=f'E{spec["epoch_bits"]}-{spec["side"]}-{spec["scene"]}-w{spec["workers"]}'
            contexts.setdefault(key,{}).setdefault(spec['pair'],{})[spec['role']]=observation
            result['processes']+=1
        for key,pairs in contexts.items():
            require(set(pairs)==set(range(1,8)) and all(set(v)=={'A','B'} for v in pairs.values()),'unpaired observations')
            a=[pairs[i]['A']['tick_ns'] for i in range(1,8)];b=[pairs[i]['B']['tick_ns'] for i in range(1,8)]
            result['contexts'][key]=dict(clear_latency_ns=summary(b),ordinary_latency_ns=summary(a),
                paired_excess_ns=summary([y-x for x,y in zip(a,b)]),paired_ratio=summary([y/x for x,y in zip(a,b)]),
                peak_rss_kib={role:summary([pairs[i][role]['peak_rss_kib'] for i in range(1,8)]) for role in ('A','B')},
                aggregation='seven independent fresh-process pairs, one event/tick observation per process; descriptive nearest-rank p95/p99 equal observed maximum for N=7')
        require(len(result['contexts'])==48,'incomplete context reduction')
        result['status']='complete-independent-readback-performance-acceptance-held'
    except Exception as error: result['errors'].append(str(error))
    return result


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('root',type=Path);ap.add_argument('--apparatus',type=Path,required=True)
    args=ap.parse_args();r=verify(args.root.resolve(),args.apparatus.resolve());print(json.dumps(r,indent=2));raise SystemExit(bool(r['errors']))
