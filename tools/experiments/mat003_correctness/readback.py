"""Readback primitives: no collector summaries are treated as proof."""
from pathlib import Path
import hashlib
import json
from oracle import decode,check_observation
from matrix import cases

def sealed_inventory(root, inventory):
    root=Path(root).resolve()
    paths={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}
    if paths != set(inventory):raise ValueError('missing or extra evidence file')
    for name,digest in inventory.items():
        p=(root/name).resolve()
        if not p.is_relative_to(root) or p.is_symlink():raise ValueError('unsafe evidence path')
        if hashlib.sha256(p.read_bytes()).hexdigest()!=digest:raise ValueError('seal mismatch')

def storage(arm,path):
    count=0
    state={}
    names=('material','a','b','epoch','r','clear')
    values=(0,1,254,255,256,32768,65280,65534,65535,65536,2**64-1)
    with Path(path).open(encoding='ascii') as stream:
        for line in stream:
            index,field,value,pre,ok,post=line.split()
            index,field,value,ok=map(int,(index,field,value,ok))
            if index!=count or field!=index%6 or value!=values[(index//6)%11] or ok not in (0,1):
                raise ValueError('storage schedule drift')
            before=bytes.fromhex(pre);after=bytes.fromhex(post)
            slot=(index//66)%1024
            expected_pre=state.get(slot,bytes(len(before)))
            if before!=expected_pre:raise ValueError("broken per-record operation chain")
            check_observation(arm,decode(arm,before),names[field],value,bool(ok),after,raw=True)
            state[slot]=after
            count+=1
    if count!=65536:raise ValueError('incomplete operation stream')

def completion(manifest):
    expected=cases()
    if manifest.get('cases')!=expected:raise ValueError('incomplete or changed matrix')
    if manifest.get('qualification_admitted') is not True:raise ValueError('not independently admitted')
    # Every case needs explicit independently checked invariant dispositions.
    required=('source','binary','schedule','states','sidecars','ledger','stamps','workers','refusals','resources')
    for row in manifest.get('results',[]):
        if row.get('exit_code')!=0 or row.get('stderr_bytes')!=0:raise ValueError('failed observation retained')
        if any(row.get('verified',{}).get(k) is not True for k in required):raise ValueError('unverified invariant')
    if len(manifest.get('results',[]))!=152:raise ValueError('missing results')
    raise ValueError('HELD: full World independent decoder/admission must be completed; completion receipts alone cannot pass')
