"""Small-width contract model of epoch relabelling, never a native restore."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import time


class State:
    __slots__=('mask','current','tick','stamps','values')
    def __init__(self,mask,current,tick,stamps,values):
        self.mask,self.current,self.tick=mask,current,tick
        self.stamps,self.values=list(stamps),list(values)


def project(source,mask,current):
    return State(mask,current,source.tick,[current if s==source.current else 0 for s in source.stamps],source.values)


def step(source,action,broken=None):
    s=State(source.mask,source.current,source.tick,source.stamps,source.values)
    if action==0:
        s.tick+=1;s.current=(s.current+1)&s.mask
        if s.current==0:
            s.stamps=[0 if broken!='active-clear' or i==1 else v for i,v in enumerate(s.stamps)]
            s.current=1
    elif action==1:
        s.values[0]=(s.values[0]+1)%3;s.stamps[0]=s.current
    elif action==2:
        if broken=='stamp-noop':s.stamps[1]=s.current
    elif action==3:
        if s.values[0] and s.values[2]==0:
            s.values[2]=s.values[0];s.values[0]=0;s.stamps[0]=s.stamps[2]=s.current
    elif action==4:
        if s.values[0] and s.values[1] and s.values[0]!=s.values[1]:
            s.values[0],s.values[1]=s.values[1],s.values[0];s.stamps[0]=s.stamps[1]=s.current
    return s


def observable(s):
    return (s.tick,s.values,[v==s.current for v in s.stamps],
            [s.tick==0 or v!=s.current for v in s.stamps])


def equivalent(a,b):
    if observable(a)!=observable(b):raise ValueError('content/clock/epoch/support predicate disagreement')
    if any(not 0<=v<=s.current<=s.mask for s in (a,b) for v in s.stamps):raise ValueError('future-stamp domain')


def exercise():
    specpath=Path(__file__).with_name('epoch-model-registration.json')
    spec=json.loads(specpath.read_text());began=time.monotonic()
    counts={'initial_projections':0,'positive_checks':0,'terminal_traces':0}
    def walk(a,b,depth):
        equivalent(a,b);counts['positive_checks']+=1
        if counts['positive_checks']%8192==0 and time.monotonic()-began>spec['limits']['timeout_seconds']:
            raise ValueError('contract-model watchdog')
        if depth==0:counts['terminal_traces']+=1;return
        for action in range(5):walk(step(a,action),step(b,action),depth-1)
    for width in spec['source_widths']:
        mask=(1<<width)-1
        for current in range(mask+1):
            for stamps in itertools.product(range(current+1),repeat=3):
                source=State(mask,current,current,stamps,(1,2,0))
                for target_width in spec['destination_widths']:
                    target_mask=(1<<target_width)-1
                    for target_current in range(1,target_mask+1):
                        counts['initial_projections']+=1
                        walk(source,project(source,target_mask,target_current),spec['trace_length'])
    negatives=[]
    source=State(3,1,1,(1,0,0),(1,2,0));dropped=project(source,7,2);dropped.stamps[0]=0
    pairs=[('drop-current-touch',source,dropped)]
    source=State(3,1,1,(0,0,0),(1,2,0));target=project(source,7,2)
    pairs.append(('stamp-same-value-noop',step(source,2),step(target,2,'stamp-noop')))
    source=State(3,3,3,(1,3,0),(1,2,0))
    pairs.append(('clear-active-only',step(source,0),step(source,0,'active-clear')))
    for name,a,b in pairs:
        try:equivalent(a,b)
        except ValueError:negatives.append(name)
        else:raise AssertionError('broken model accepted: '+name)
    return {'status':'passed','timing':False,'native_execution':False,
            'validation_class':'contract-model author validation pending independent review',
            'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
            'model_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'registration_sha256':hashlib.sha256(specpath.read_bytes()).hexdigest(),
            **counts,'negative_models_refused':negatives}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);args=parser.parse_args()
    destination=None if args.output is None else args.output.open('x',encoding='utf-8')
    result={'status':'failed','native_execution':False,'timing':False}
    try:result=exercise()
    except Exception as error:result['error']=str(error);raise
    finally:
        if destination:
            json.dump(result,destination,indent=2);destination.write('\n');destination.close()
    print(json.dumps(result,indent=2))
