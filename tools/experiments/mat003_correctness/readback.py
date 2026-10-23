"""Full retained-evidence readback. Collector completion flags never authorize a pass."""
import sys
sys.dont_write_bytecode=True
from pathlib import Path
import hashlib
import json
from itertools import zip_longest
from oracle import decode,POSITIONS
from matrix import cases,ARMS,LIMITS

budget_hook=lambda:None
from storage_oracle import expected,apply
from world_oracle import metadata,cells,registry,Transitions,compare,small_boundary

def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):
            budget_hook();h.update(block)
    return h.hexdigest()

def sealed_inventory(root,inventory,excluded="inventory.json"):
    root=Path(root).resolve()
    actual=set()
    for p in root.rglob('*'):
        budget_hook()
        if p.is_file() and p.relative_to(root).as_posix()!=excluded:actual.add(p.relative_to(root).as_posix())
    if actual!=set(inventory):raise ValueError('missing/extra retained evidence')
    for name,value in inventory.items():
        p=root/name
        if p.is_symlink() or not p.resolve().is_relative_to(root):raise ValueError('unsafe evidence path')
        if digest(p)!=value:raise ValueError('evidence seal mismatch: '+name)

def storage(arm,path):
    coverage=dict(copy=False,swap=False,clear=False,replace=False,unused_copy=False);onehots={i:set() for i in range(5)}
    state={};count=0;width=POSITIONS[arm][0]//8
    with Path(path).open(encoding='ascii') as f:
        for line in f:
            terms=line.split()
            if len(terms)!=12:raise ValueError('malformed storage operation')
            index,op,left,right,field,negative,value=map(int,terms[:7]);pre,other,accepted,post,post_other=terms[7:]
            if index%1024==0:budget_hook()
            if index!=count or (op,left,right,field,bool(negative),value)!=expected(index) or negative not in (0,1) or accepted not in ('0','1'):raise ValueError('storage schedule drift')
            a,b=bytes.fromhex(pre),bytes.fromhex(other)
            if a!=state.get(left,bytes(width)) or b!=state.get(right,bytes(width)):raise ValueError('broken per-record trace continuity')
            outcome,x,y=apply(arm,a,b,expected(index))
            if bool(int(accepted))!=outcome or bytes.fromhex(post)!=x or bytes.fromhex(post_other)!=y:raise ValueError('independent storage operation mismatch')
            if op==1 and a!=b:coverage['copy']=True
            if op==2 and a!=b:coverage['swap']=True
            if op==4 and decode(arm,a).epoch:coverage['clear']=True
            if op==3 and any(a):coverage['replace']=True
            if op in (1,2) and (decode(arm,a).unused or decode(arm,b).unused):coverage['unused_copy']=True
            if op==0 and outcome and value and value&(value-1)==0:onehots[field].add(value)
            state[left]=x;state[right]=y;count+=1
    if count!=65536:raise ValueError('incomplete storage trace')
    cap,e,r=POSITIONS[arm];unused_width=cap-40-len(e)-len(r)
    for i,bits in enumerate((16,16,8,len(e),len(r))):
        if not {1<<b for b in range(bits)}<=onehots[i]:raise ValueError('missing accepted one-hot storage coverage')
    if not all(coverage[k] for k in ('copy','swap','clear','replace')) or (unused_width and not coverage['unused_copy']):raise ValueError('vacuous storage operation coverage')

def ticks(role,case):
    rows=[];bits=int(case['arm'].split('E')[1]);limit=2**bits-1
    horizon=case.get('ticks',260)
    if (role/'ticks.txt').stat().st_size>horizon*1024:raise ValueError('per-tick receipt output bound')
    for line in (role/'ticks.txt').read_text(encoding='ascii').splitlines():
        v=tuple(map(int,line.split()));tick=len(rows)+1
        if len(v)!=19 or v[0]!=tick or any(x<0 for x in v):raise ValueError('tick/work receipt malformed')
        epoch=(tick-1)%limit+1;clears=(tick-1)//limit
        if case['suite']=='resident' and tick>=256:
            epoch=tick-255 if role.name=='event' else tick-127
            clears=1 if role.name=='event' else 0
        if v[1]!=epoch or v[17]!=clears or v[18]!=clears*case['side']**2:raise ValueError('real clear count/traversal/tick identity')
        if sum(v[5:9])!=v[4] and case.get('backend')=='phased':raise ValueError('phase jobs/scheduled mismatch')
        if v[4]>64:raise ValueError('scheduler provision breached')
        rows.append(v)
    if len(rows)!=horizon:raise ValueError('missing/extra completed ticks')
    if case.get('workers')==4 and not any(v[16]>0 for v in rows):raise ValueError('configured workers lack background participation')
    # Closed period after final bounded input pulse; all clear spikes remain recorded.
    last_input=8 if case['suite']=='small' else 255 if case['suite']=='resident' and case['scene']=='active-window-excluded' else 0
    if len({(v[12],v[13]) for v in rows[last_input:]})>1:raise ValueError('closed Water/Sand accounting mismatch')
    deltas=input_ledger(role,case,rows)
    previous=(255,2 if case['suite']=='resident' else 1)
    for v in rows:
        delta=deltas.get(v[0],(0,0))
        if case['suite']=='small' and v[0]==1:delta=(delta[0]+50,delta[1]+1) # independently checked lifecycle injections193/removal143 and one Sand
        if (v[12]-previous[0],v[13]-previous[1])!=delta:raise ValueError('input/source/sink/closed Water or Sand ledger imbalance')
        previous=v[12],v[13]
    return rows

def endpoints(case,role="ordinary"):
    if case['suite']=='natural' and role=='prepared':return {'B':65535,'P':65535,'Q':65536,'R':65540}
    if case['suite']=='resident':return {'B':255,'P':255,'Q':256,'R':260}
    if case['suite']=='refusal':return {'before':0,'after':0,'failed-before':1,'failed-after':1,'recovered':1}
    ticks={0,1,255,256,257,case['ticks']}
    if case['suite']=='natural':ticks|={65534,65535,65536,65537,65540}
    return {'tick-'+str(t):t for t in sorted(ticks)}

def world(path,case):
    roles=('event','reference') if case['suite']=='resident' else ('ordinary','prepared') if case['suite']=='natural' else ('ordinary',)
    if {p.name for p in path.iterdir()}!=set(roles):raise ValueError('wrong role inventory')
    for name in roles:
        role=path/name;reg=registry(role/'registry.txt',case['arm'])
        if len(reg)*16384!=case.get('side',256)**2:raise ValueError('unregistered resident population')
        snapshots=endpoints(case,name)
        expected_dirs=set(snapshots)|({f'attempt-{i}-{phase}' for i in range(256) for phase in ('pre','post')} if case['suite']=='refusal' else set())
        if {p.name for p in role.iterdir() if p.is_dir()}!=expected_dirs:raise ValueError('missing/extra endpoint dataset')
        model=Transitions(case['arm'],reg)
        def transition_rows():
            last=(0,-1)
            with (role/'transitions.txt').open(encoding='ascii') as stream:
                for line in stream:
                    t,i,*_=line.split();key=int(t),int(i)
                    if key[0]<last[0] or key[1]!=(last[1]+1 if key[0]==last[0] else 0):raise ValueError('transition order/sequence')
                    last=key;yield key[0],line
        transitions=iter(transition_rows());pending=next(transitions,None)
        if case['suite']=='refusal':
            refusal(role,case)
            continue
        receipts=ticks(role,case)
        cursor=0
        for endpoint,tick in sorted(snapshots.items(),key=lambda x:(x[1],x[0])):
            for current in range(cursor+1,tick+1):
                while pending is not None and pending[0]<=current:
                    model.feed(pending[1]);pending=next(transitions,None)
            cursor=tick
            root=role/endpoint;m=metadata(root)
            if set(p.name for p in root.iterdir())!={'cells.bin','chunks.txt','metadata.txt'}:raise ValueError('endpoint inventory')
            if m['clock'][:2]!=(tick,tick):raise ValueError('attempt/completed tick checkpoint mismatch')
            cap=POSITIONS[case['arm']][0];alignment=1 if cap in (72,80) else 8
            if m['layout']!=(cap//8,alignment,cap//8,alignment,8 if cap==128 else 0):raise ValueError('actual ABI/stride/lane offset mismatch')
            if m['schema'][:3]!=(1,POSITIONS[case['arm']][0],int(case['arm'].split('E')[1])):raise ValueError('map identity mismatch')
            if m['clock'][3:]!=(0,0):raise ValueError('healthy fixture failed/in progress')
            if m['flags']!=(0,0,1):raise ValueError('unqualified flow/adhesion configuration')
            if m['config'][8]!=case['workers'] or m['config'][4]!=(0 if case['backend']=='serial' else 1):raise ValueError('worker/backend drift')
            expected_epoch=0 if tick==0 else receipts[tick-1][1]
            if endpoint=='P':expected_epoch=65535 if name in ('event','prepared') else 128
            if m['clock'][2]!=expected_epoch:raise ValueError('endpoint epoch identity')
            if m['clears']!=((0,0) if tick==0 else (receipts[tick-1][17],receipts[tick-1][18])):raise ValueError('endpoint clear receipt mismatch')
            model.check(root)
            # Derive material totals from every retained cell rather than collector reductions.
            water=sand=0;counts={}
            sentinels={(7,7):(0x8001,-1234),(8,7):(0xffff,-32768),(9,7):(0x8000,32767),(10,7):(0x7fff,200),(11,7):(0x100,200)}
            endpoint_owners(root,{(x,y) for x,y,n,base in reg},case['arm'],reg)
            for pos,r,temp,present,address in cells(root,case['arm']):
                if case['suite']=='small':
                    small_boundary(pos,r,case['side'])
                chunk=pos[0]//128,pos[1]//128;counts[chunk]=counts.get(chunk,0)+(r.material!=0)
                water+=r.a if r.material==3 else 0;sand+=r.material==2
                if pos in sentinels and (r.material,r.a,temp)!=(0,*sentinels[pos]):raise ValueError('nonzero Empty/high-state/temperature lost')
            for (x,y),count in counts.items():
                if m[f'chunk:{x}:{y}'][1]!=count:raise ValueError('nonempty count mismatch')
            if tick and (water,sand)!=(receipts[tick-1][12],receipts[tick-1][13]):raise ValueError('endpoint ledger reduction mismatch')
        if pending is not None:raise ValueError('unbound transition records')
        if case['suite']=='small':operations(role/'operations.txt',case['arm'])
    if case['suite']=='natural':
        for ordinary,prepared in (('tick-65535','B'),('tick-65536','Q'),('tick-65540','R')):
            exact_state(path/'ordinary'/ordinary,path/'prepared'/prepared,case['arm'])
        compare(path/'prepared'/'B',path/'prepared'/'P',case['arm'],case['arm'],prepared=True)
    if case['suite']=='resident':
        for name in roles:compare(path/name/'B',path/name/'P',case['arm'],case['arm'],prepared=True)
        compare(path/'event'/'Q',path/'reference'/'Q',case['arm'],case['arm'])
        compare(path/'event'/'R',path/'reference'/'R',case['arm'],case['arm'])

def refusal(role,case):
    rows=(role/'attempts.txt').read_text(encoding='ascii').splitlines()
    if len(rows)!=256:raise ValueError('incomplete refusal operations')
    previous=None
    for index,line in enumerate(rows):
        i,kind,ok,pre,post=line.split();i,kind,ok=map(int,(i,kind,ok))
        if i!=index or kind!=(index%7 if index<224 else 7+(index-224)%8) or ok not in (0,1):raise ValueError('refusal schedule drift')
        if index!=224 and previous is not None and pre!=previous:raise ValueError('broken refusal chain')
        expected=index<224 and kind==0 and case['arm']!='K64-E16'
        if bool(ok)!=expected:raise ValueError('semantic/capability/schema/capacity/failed-world refusal')
        if not expected and pre!=post:raise ValueError('refusal changed record')
        a=metadata(role/f'attempt-{index}-pre');b=metadata(role/f'attempt-{index}-post')
        if not expected and (a!=b or (role/f'attempt-{index}-pre'/'chunks.txt').read_bytes()!=(role/f'attempt-{index}-post'/'chunks.txt').read_bytes()):raise ValueError('refusal changed relevant owner state')
        for phase in ('pre','post'):
            directory=role/f'attempt-{index}-{phase}'
            if (directory/'metadata.txt').stat().st_size>128*1024:raise ValueError('per-admission metadata budget')
            if (directory/'cells.bin').stat().st_size!=0:raise ValueError('metadata receipt duplicates cells')
        r=decode(case['arm'],bytes.fromhex(post))
        if expected and (r.material,r.a,r.b,r.r,r.unused)!=(0,1,0,65535,0):raise ValueError('admitted record fields')
        previous=post
    for endpoint in ('before','after','failed-before','failed-after','recovered'):
        m=metadata(role/endpoint)
        expected={(0,0),(1,0)} if endpoint.startswith('failed') else {(0,0)} if endpoint=='recovered' else {(0,0),(1,0),(0,1),(1,1)}
        endpoint_owners(role/endpoint,expected,case['arm'])
        cap=POSITIONS[case['arm']][0];alignment=1 if cap in (72,80) else 8
        if m['layout']!=(cap//8,alignment,cap//8,alignment,8 if cap==128 else 0) or m['schema']!=(1,cap,int(case['arm'].split('E')[1]),cap//8,alignment):raise ValueError('refusal ABI/map mismatch')
        if m['config'][12]!=4 or m['config'][8]!=1:raise ValueError('refusal residency/worker config')
        for _ in cells(role/endpoint,case['arm']):pass
        if endpoint.startswith('failed') and m['clock'][:4]!=(2,1,1,1):raise ValueError('genuine failed-clear clock/quarantine identity')
        if endpoint=='recovered' and m['clock']!=(1,1,1,0,0):raise ValueError('failed-world recovery clock')
    exact_state(role/'failed-before',role/'failed-after',case['arm'])
    for a,b in zip_longest(cells(role/'before',case['arm']),cells(role/'after',case['arm'])):
        if a is None or b is None or a[0]!=b[0]:raise ValueError('admission owner population changed')
        if a[0]!=(7,7) and a[:4]!=b[:4]:raise ValueError('admission changed unrelated complete cell/temperature')
        if a[0]==(7,7) and a[2:]!=b[2:]:raise ValueError('admission changed temperature/owner identity')

def verification_budget(root,expected_authority_sha256):
    """Install wall guard before hashing; seal the monitor before its first RSS call."""
    import time,psutil,world_oracle
    global budget_hook
    began=time.monotonic();spent=0;monitor_ready=False
    def guard():
        if time.monotonic()-began+spent>LIMITS['platform_wall_seconds']:raise ValueError('verification aggregate wall bound')
        if monitor_ready and psutil.Process().memory_info().rss>2*1024**3:raise ValueError('verification RSS bound')
    budget_hook=guard;world_oracle.budget_hook=guard
    root=Path(root).resolve()
    if len(expected_authority_sha256)!=64 or digest(root/'authority.json')!=expected_authority_sha256:raise ValueError('external authority seal mismatch')
    for name in ('authority.json','result.json'):
        if (root/name).stat().st_size>4*1024**2:raise ValueError('control receipt size bound')
    authority=json.loads((root/'authority.json').read_text(encoding='utf-8'))
    result=json.loads((root/'result.json').read_text(encoding='utf-8'))
    spent=result['wall_watchdog_seconds']
    if not isinstance(spent,(int,float)) or not 0<=spent<=LIMITS['platform_wall_seconds']:raise ValueError('invalid active-wall receipt')
    if psutil.__version__!='7.0.0':raise ValueError('monitor version drift')
    package=Path(psutil.__file__).parent;actual={}
    for p in package.rglob('*'):
        guard()
        if p.is_file() and p.suffix in ('.py','.so','.pyd'):actual[p.relative_to(package).as_posix()]=digest(p)
    if actual!=authority['psutil_source_sha256']:raise ValueError('verification monitor source drift')
    monitor_ready=True;guard()
    return result,authority,guard

def matrix_contract(result):
    if result.get('status')!='collected-not-verified' or result.get('cases')!=cases() or result.get('timing') is not False:raise ValueError('incomplete/changed campaign')

def completion(root,expected_authority_sha256,budget=None):
    root=Path(root).resolve()
    result,authority,guard=budget or verification_budget(root,expected_authority_sha256)
    if (root/'inventory.json').stat().st_size>16*1024**2:raise ValueError('inventory control size bound')
    inventory=json.loads((root/'inventory.json').read_text(encoding='utf-8'));sealed_inventory(root,inventory)
    matrix_contract(result)
    if authority.get('independent_admission')!='admitted' or authority.get('owner_execution_authorized') is not True:raise ValueError('unadmitted execution')
    from provenance import verify_provenance
    verify_provenance(root,result,authority,expected_authority_sha256,digest,guard)
    if len(result['builds'])!=32 or len(result['results'])!=152:raise ValueError('partial matrix')
    buildmap={}
    for b in result['builds']:
        key=b['arm'],b['sanitized'],b['kind']
        if key in buildmap or digest(root/b['path'])!=b['sha256']:raise ValueError('binary inventory mismatch')
        buildmap[key]=b
    expected_builds={(a,s,k) for a in ARMS for s in (False,True) for k in ('storage','world')}
    if set(buildmap)!=expected_builds:raise ValueError('build matrix mismatch')
    for case,row in zip(cases(),result['results']):
        guard()
        if row['case']!=case['id']:raise ValueError('case ordering mismatch')
        kind='storage' if case['suite']=='storage' else 'world'
        if row['binary_sha256']!=buildmap[case['arm'],case['sanitized'],kind]['sha256']:raise ValueError('wrong case binary')
        p=root/'cases'/case['id'];receipt=json.loads((p/'process.receipt.json').read_text(encoding='utf-8'))
        if receipt!=row['receipt'] or receipt['exit_code']!=0 or receipt['stop'] or receipt['stderr_bytes'] or (p/'process.stderr').stat().st_size:raise ValueError('failed observation')
        peak=int((p/'peak-rss.txt').read_text());limit=LIMITS['sanitized_rss_bytes' if case['sanitized'] else 'normal_rss_bytes']
        if not 0<peak<=limit or row['peak_rss']!=peak:raise ValueError('RSS receipt mismatch')
        if kind=='storage':storage(case['arm'],p/'process.stdout')
        else:world(p/'world',case)
    # Cross-arm common-control comparisons are separate from payload preservation.
    for case in cases():
        if case['suite'] not in ('small','natural','resident') or case['arm']=='K64-E16':continue
        control=next(x for x in cases() if x['arm']=='K64-E16' and {k:v for k,v in x.items() if k not in ('id','arm')}=={k:v for k,v in case.items() if k not in ('id','arm')})
        for role in ('event','reference') if case['suite']=='resident' else ('ordinary','prepared') if case['suite']=='natural' else ('ordinary',):
            for endpoint in endpoints(case,role):
                compare(root/'cases'/case['id']/'world'/role/endpoint,root/'cases'/control['id']/'world'/role/endpoint,case['arm'],control['arm'])
    return dict(status='verified',cases=152,performance_accepted=False,scope='frozen neutral mapping correctness only')

def exact_state(left,right,arm):
    if metadata(left)!=metadata(right):raise ValueError('complete owner state mismatch')
    for a,b in zip_longest(cells(left,arm),cells(right,arm)):
        if a is None or b is None or a[:4]!=b[:4]:raise ValueError('complete carrier/temperature state mismatch')

def operations(path,arm):
    from dataclasses import replace
    from oracle import Record
    names=('move','swap','partial','drain','new-water','replace')
    rows=Path(path).read_text(encoding='ascii').splitlines()
    if len(rows)!=6:raise ValueError('missing lifecycle transition obligation')
    fixed=((126,24,128,24,0),(128,24,129,24,0),(60,60,61,60,50),(60,60,61,60,123),(61,60,62,60,50),(61,60,61,60,0))
    for line,name,positions in zip(rows,names,fixed):
        words=line.split()
        if len(words)!=14 or words[0]!=name:raise ValueError('lifecycle operation inventory')
        _,x,y,tx,ty,amount,source,destination,source_after,destination_after,st,dt,sa,da=words
        if tuple(map(int,(x,y,tx,ty,amount)))!=positions:raise ValueError('lifecycle coordinate/amount schedule drift')
        a,b,c,d=(decode(arm,bytes.fromhex(v)) for v in (source,destination,source_after,destination_after));q=int(amount)
        st,dt,sa,da=map(int,(st,dt,sa,da))
        if name=='move' and (a.material,a.a,st)!=(2,0,777):raise ValueError('movement fixture setup')
        if name=='partial' and (a.material,a.a,a.b,b.material,b.a,b.b)!=(3,173,7,3,20,2):raise ValueError('transfer fixture setup')
        if name=='move':
            if c!=Record() or d!=a or (sa,da)!=(200,st):raise ValueError('whole movement/temp/cross-lane payload')
        elif name=='swap':
            if c!=b or d!=a or (sa,da)!=(dt,st):raise ValueError('whole swap/temp/cross-lane payload')
        elif name in ('partial','drain','new-water'):
            expected_source=Record() if a.a==q else replace(a,a=a.a-q)
            expected_destination=replace(b,a=b.a+q,b=max(a.b,b.b)) if name!='new-water' else Record(material=3,a=q,b=a.b)
            if c!=expected_source or d!=expected_destination:raise ValueError('partial/drain/conversion preservation or closed Water ledger')
            if (sa,da)!=(st,dt):raise ValueError('partial Water transfer changed temperature')
            if a.a+(b.a if b.material==3 else 0)!=(c.a if c.material==3 else 0)+d.a:raise ValueError('Water transfer ledger loss')
        elif name=='replace':
            if c.r or c.unused or c.material!=1 or c.epoch!=a.epoch or c!=d:raise ValueError('declared replacement failed reset')

def endpoint_owners(root,expected,arm,reg=None):
    root=Path(root);m=metadata(root);rows=[tuple(map(int,line.split())) for line in (root/'chunks.txt').read_text(encoding='ascii').splitlines()]
    if len(rows)!=len(expected) or {(r[0],r[1]) for r in rows}!=expected:raise ValueError('full resident owner inventory missing/extra')
    if {k for k in m if k.startswith('chunk:')}!={f'chunk:{x}:{y}' for x,y in expected}:raise ValueError('chunk metadata/cell owner inventory differs')
    alignment=1 if POSITIONS[arm][0] in (72,80) else 8
    for x,y,count,present,base in rows:
        if count!=16384 or present not in (0,1) or base<=0 or base%alignment:raise ValueError('physical owner/temperature identity')
        if reg is not None and (x,y,count,base) not in reg:raise ValueError('storage registry changed during World')
    if (root/'cells.bin').stat().st_size!=len(expected)*16384*(POSITIONS[arm][0]//8+2):raise ValueError('full endpoint byte count')
    if (root/'metadata.txt').stat().st_size>1024**2+len(expected)*65536:raise ValueError('endpoint metadata bound')

def input_ledger(role,case,receipts):
    from oracle import Record
    schedule=[]
    for tick in range(1,len(receipts)+1):
        if (case['suite']=='small' and tick<=8) or (case['suite']=='resident' and case['scene']=='active-window-excluded' and 248<=tick<=255):
            for x in range(16,case['side']//2,64):schedule.extend(((tick,x,8,3),(tick,x+8,8,2)))
    stream=(role/'inputs.txt').read_text(encoding='ascii').splitlines()
    if len(stream)!=len(schedule):raise ValueError('input schedule length')
    deltas={}
    for line,action in zip(stream,schedule):
        t,x,y,material,epoch,pre,post,before_temperature,after_temperature=line.split()
        t,x,y,material,epoch=map(int,(t,x,y,material,epoch))
        if (t,x,y,material)!=action or epoch!=(0 if t==1 else receipts[t-2][1]):raise ValueError('input ordering/clock binding')
        a,b=decode(case['arm'],bytes.fromhex(pre)),decode(case['arm'],bytes.fromhex(post))
        expected=a if a.material==material else Record(material=material,a=255 if material==3 else 0,epoch=epoch)
        if b!=expected or before_temperature!=after_temperature:raise ValueError('Current external replacement/noop/temperature contract')
        water=(b.a if b.material==3 else 0)-(a.a if a.material==3 else 0);sand=int(b.material==2)-int(a.material==2)
        old=deltas.get(t,(0,0));deltas[t]=old[0]+water,old[1]+sand
    return deltas

if __name__=='__main__':
    import argparse
    # Negative fixtures use this same guarded module, rather than importing a second copy.
    sys.modules['readback']=sys.modules[__name__]
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--evidence',type=Path,required=True);parser.add_argument('--authority-sha256',required=True);parser.add_argument('--verification-output',type=Path,required=True)
    args=parser.parse_args()
    destination=args.verification_output.resolve()
    if destination.exists() or destination==args.evidence.resolve() or args.evidence.resolve() in destination.parents:parser.error('verification output must be new and outside retained evidence')
    destination.mkdir(parents=True)
    report=dict(status='failed',performance_accepted=False)
    try:
        budget=verification_budget(args.evidence,args.authority_sha256)
        from negative import exercise
        report['negative_fixtures']=exercise(destination/'negative-fixtures')
        report.update(completion(args.evidence,args.authority_sha256,budget))
    except Exception as error:
        report['error']=str(error)
        raise
    finally:
        # Preserve a failure report even when the active verification budget expired.
        budget_hook=lambda:None
        (destination/'readback.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        (destination/'inventory.json').write_text(json.dumps({p.relative_to(destination).as_posix():digest(p) for p in destination.rglob('*') if p.is_file() and p.name!='inventory.json'},indent=2)+'\n',encoding='utf-8')
