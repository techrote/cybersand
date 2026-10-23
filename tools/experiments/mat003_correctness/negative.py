"""Retained negative verifier fixtures, executed only under future verifier authority."""
from dataclasses import replace
from pathlib import Path
import json
from oracle import Record,encode,decode,check_observation

def exercise(output):
    output=Path(output)
    if output.exists():raise ValueError('append-only negative fixture output exists')
    output.mkdir(parents=True)
    passed=[]
    def rejects(name,operation,reason=None):
        directory=output/name;directory.mkdir()
        try:operation(directory)
        except (ValueError,KeyError) as error:
            if reason is not None and reason not in str(error):raise ValueError('negative fixture rejected for wrong reason: '+name) from error
            (directory/'disposition.json').write_text(json.dumps(dict(status='rejected-as-required',reason=str(error)))+'\n',encoding='utf-8');passed.append(name);return
        raise ValueError('negative verifier fixture incorrectly accepted: '+name)
    def record(directory,arm,r):
        data=encode(arm,r,raw=True);(directory/'input.bin').write_bytes(data);return data
    rejects('wrong-byte-width',lambda p:decode('K72-E16',record(p,'K64-E8',Record())))
    rejects('capability-refusal',lambda p:encode('K64-E16',Record(r=1)))
    rejects('wrong-map-overlap',lambda p:check_observation('K72-E16',Record(epoch=257,r=1),'epoch',0,True,record(p,'K72-E16',Record(r=0))))
    rejects('partial-corrupts-material',lambda p:check_observation('D128-E16',Record(material=2),'r',257,True,record(p,'D128-E16',Record(material=1,r=257))))
    rejects('high-lane-loss',lambda p:check_observation('D128-E16',Record(unused=2**55),'r',1,True,record(p,'D128-E16',Record(r=1)),raw=True))
    rejects('false-refusal',lambda p:check_observation('K64-E16',Record(),'r',1,True,record(p,'K64-E16',Record())))
    from readback import sealed_inventory,storage
    def missing(p):
        (p/'required.bin').write_bytes(b'a');sealed_inventory(p,{'absent.bin':'0'*64})
    rejects('missing-inventory-file',missing)
    def empty_storage(p):
        path=p/'operations.txt';path.write_text('',encoding='ascii');storage('K64-E8',path)
    rejects('incomplete-operation-matrix',empty_storage)
    from world_oracle import cells,metadata
    def duplicate(p):
        (p/'chunks.txt').write_text('0 0 16384 0 100\n0 0 16384 0 100\n',encoding='ascii');(p/'cells.bin').write_bytes(bytes(16384*10*2))
        for _ in cells(p,'K64-E8'):pass
    rejects('duplicate-cells-owner',duplicate)
    def truncated(p):
        (p/'chunks.txt').write_text('0 0 16384 0 100\n',encoding='ascii');(p/'cells.bin').write_bytes(bytes(1))
        for _ in cells(p,'K64-E8'):pass
    rejects('truncated-full-state',truncated)
    def sidecar(p):
        (p/'metadata.txt').write_text('schema 1 64 8 8 8\n',encoding='ascii');metadata(p)
    rejects('dropped-sidecar-owner',sidecar)
    def clock(p):
        from world_oracle import compare
        a=p/'natural';b=p/'prepared';a.mkdir();b.mkdir()
        # Minimal independent proof of predicate mismatch; metadata complete fixture is retained by corpus helper.
        complete_metadata(a);complete_metadata(b)
        for path,epoch in ((a,1),(b,0)):
            (path/'chunks.txt').write_text('0 0 16384 0 100\n',encoding='ascii')
            data=encode('K64-E8',Record(epoch=epoch))+(200).to_bytes(2,'little',signed=True)
            (path/'cells.bin').write_bytes(data*16384)
        compare(a,b,'K64-E8','K64-E8',prepared=True)
    rejects('natural-prepared-predicate-mismatch',clock)
    def extra(p):
        (p/'chunks.txt').write_text('0 0 16384 0 100\n',encoding='ascii');(p/'cells.bin').write_bytes(bytes(16384*10+1))
        for _ in cells(p,'K64-E8'):pass
    rejects('extra-cell-record',extra)
    def bad_hash(p):
        (p/'input.bin').write_bytes(b'changed');sealed_inventory(p,{'input.bin':'0'*64})
    rejects('corrupted-inventory-hash',bad_hash)
    def manifest(p):
        from matrix import cases
        from readback import matrix_contract
        result=dict(status='collected-not-verified',cases=cases()[:-1],timing=False)
        (p/'result.json').write_text(json.dumps(result),encoding='utf-8');matrix_contract(result)
    rejects('missing-process-matrix',manifest,'incomplete/changed campaign')
    from world_oracle import small_boundary
    rejects('missing-outer-containment-wall',lambda p:small_boundary((0,128),Record(),256),'containment wall')
    rejects('active-inner-containment-strip',lambda p:small_boundary((1,128),Record(material=3,a=255),256),'containment wall')
    rejects('corrupted-containment-neutral',lambda p:small_boundary((255,255),Record(material=1,r=1),256),'containment wall')
    for point in ((0,0),(1,128),(128,1),(254,128),(128,254),(255,255)):
        small_boundary(point,Record(material=1,epoch=255),256)
    small_boundary((2,128),Record(material=3,a=255),256)
    # Source-only fixtures until a new verifier/case authority is issued.
    from world_oracle import (resident_endpoint,resident_activity_transitions,
        resident_sand_witness,BLOCK_SLEEP_KEY,BLOCK_WAKE_KEY)
    from readback import resident_grid
    def resident_rows(endpoint='Q'):
        rows={'config':(128,3,200,256,1,32,64,2,1,1,256,256,256,1024,64,0,4096,0,0,0)}
        width=512 if endpoint=='R' else 256
        rows['interest']=(1,0,0,width,512)
        rows['selected']=(1,0,0,width//64-1,7)
        rows['applied']=rows['selected']
        def chunk(active,quiet,nonempty=0):
            return (4,nonempty,int(active),0,quiet,0,0,0,0,0,16)
        for y in range(4):
            for x in range(2):
                rows[f'chunk:{x}:{y}']=chunk(False,3)
                for i in range(16):
                    rows[f'block:{x}:{y}:{i}']=(0,3 if (x,y)==(0,0) and i<8 else 0,0,0)
        rows['chunk:3:0']=chunk(True,0,2)
        for i in range(16):
            rows[f'block:3:0:{i}']=(0,0,1 if i==0 else 0,0)
        rows[f'event:{BLOCK_SLEEP_KEY}']=(8,)
        rows[f'event:{BLOCK_WAKE_KEY}']=(20 if endpoint=='R' else 4,)
        return rows
    positive=output/'resident-mixed-aged-unaged-positive';positive.mkdir()
    positive_rows=resident_rows()
    (positive/'input.json').write_text(json.dumps(positive_rows)+'\n',encoding='utf-8')
    resident_endpoint(positive_rows,2048,'Q')
    passed.append('resident-mixed-aged-unaged-positive')
    def resident_mutation(p,kind):
        rows=resident_rows()
        if kind in ('core','chunk'):
            cfg=list(rows['config']);cfg[10 if kind=='core' else 11]=128 if kind=='core' else 64;rows['config']=tuple(cfg)
        elif kind=='interest':rows['interest']=(1,0,0,2048,2048)
        elif kind=='applied':rows['applied']=(1,0,0,7,7)
        elif kind=='sleep':
            rows['block:0:0:0']=(0,0,1,0)
        elif kind=='unaged':
            for key in list(rows):
                if key.startswith('block:') and not key.startswith('block:3:0:'):
                    rows[key]=(0,0,0,0)
        elif kind=='missing-exclusion':
            rows['chunk:3:0']=(4,2,0,0,3,0,0,0,0,0,16)
            for i in range(16):rows[f'block:3:0:{i}']=(0,0,0,0)
        elif kind=='contradictory-exclusion':
            for i in range(16):rows[f'block:3:0:{i}']=(0,0,0,0)
        elif kind=='block-owner':
            del rows['block:0:0:15']
        (p/'input.json').write_text(json.dumps(rows)+'\n',encoding='utf-8')
        resident_endpoint(rows,2048,'Q')
    expected={
        'core':'resident scratch/geometry provisioning drift',
        'chunk':'resident scratch/geometry provisioning drift',
        'interest':'resident interest/reentry coverage drift',
        'applied':'resident interest/reentry coverage drift',
        'sleep':'resident inactive chunk/activity contradiction',
        'unaged':'resident sleep transition witness absent',
        'missing-exclusion':'resident exclusion witness absent/contradictory',
        'contradictory-exclusion':'resident exclusion witness absent/contradictory',
        'block-owner':'resident activity ownership/metadata drift',
    }
    for kind,reason in expected.items():
        rejects('resident-'+kind+'-drift',lambda p,k=kind:resident_mutation(p,k),reason)
    def activity_transition(p,kind):
        endpoints={name:resident_rows(name) for name in ('B','P','Q','R')}
        endpoints['B'][f'event:{BLOCK_SLEEP_KEY}']=(8,);endpoints['B'][f'event:{BLOCK_WAKE_KEY}']=(4,)
        endpoints['P'][f'event:{BLOCK_SLEEP_KEY}']=(8,);endpoints['P'][f'event:{BLOCK_WAKE_KEY}']=(4,)
        endpoints['Q'][f'event:{BLOCK_SLEEP_KEY}']=(9,);endpoints['Q'][f'event:{BLOCK_WAKE_KEY}']=(4,)
        endpoints['R'][f'event:{BLOCK_SLEEP_KEY}']=(10,);endpoints['R'][f'event:{BLOCK_WAKE_KEY}']=(20,)
        if kind=='post-clear':endpoints['P'][f'event:{BLOCK_WAKE_KEY}']=(5,)
        if kind=='reentry':endpoints['R'][f'event:{BLOCK_WAKE_KEY}']=(4,)
        (p/'input.json').write_text(json.dumps(endpoints)+'\n',encoding='utf-8')
        resident_activity_transitions(endpoints)
    rejects('resident-post-clear-activity-drift',lambda p:activity_transition(p,'post-clear'),'prepared-clear activity transition')
    rejects('resident-reentry-activity-drift',lambda p:activity_transition(p,'reentry'),'reentry wake transition absent')
    def shifted_grid(p):
        reg=[(x+1,y,16384,100+16384*8*(y*4+x)) for y in range(4) for x in range(4)]
        (p/'input.json').write_text(json.dumps(reg)+'\n',encoding='utf-8');resident_grid(reg,512)
    rejects('shifted-resident-grid',shifted_grid,'unregistered resident grid')
    def sand(p,endpoint,positions):
        (p/'input.json').write_text(json.dumps(dict(endpoint=endpoint,positions=positions))+'\n',encoding='utf-8')
        resident_sand_witness(positions,endpoint)
    rejects('excluded-sand-simulated-early',lambda p:sand(p,'Q',[(504,9)]),'Sand/reentry witness')
    rejects('excluded-sand-never-reentered',lambda p:sand(p,'R',[(504,8)]),'Sand/reentry witness')
    from world_oracle import decode_world
    from oracle import POSITIONS
    with (output/'decoder-crosscheck.jsonl').open('x',encoding='utf-8') as stream:
        for arm,(capacity,_,_) in POSITIONS.items():
            for value in (0,(1<<capacity)-1,*(1<<bit for bit in range(capacity))):
                raw=value.to_bytes(capacity//8,'little');expected=decode(arm,raw);actual=decode_world(arm,raw)
                if expected!=actual:raise ValueError('mathematical World decoder diverged from bit oracle')
                stream.write(json.dumps(dict(arm=arm,raw=raw.hex(),logical=[expected.material,expected.a,expected.b,expected.epoch,expected.r,expected.unused]))+'\n')
    passed.append('world-decoder-bit-enumeration-crosscheck')
    return passed

def complete_metadata(path):
    fields=dict(layout=(8,8,8,8,0),schema=(1,64,8,8,8),clock=(1,1,1,0,0),flags=(0,0,1),allocations=(0,0,0),config=(128,3,200,1,0,32,64,2,1,1,128,64,1,1024,64,0,4096,0,0,0),physics_config=(1,0,-1),interaction=(1,8,9,30),water_policy=(1,8,12,0,255,48,1),transport=(0,)+(2,)*81+(1,)*81+(0,0,64,8,0,1)*6561,interest=(0,),selected=(0,),applied=(0,),explosions=(0,),scratch=(0,64,0,128,0),dispatch=(0,0,0),stats=(1,0,0,0,0,0,0,0,0,0,0),phases=(0,0,0,0),support=(0,0),discovery=(0,),transient=(1,0,0,0,0,0,0),physics=(1,),ledger=(0,0),clears=(0,0))
    fields['chunk:0:0']=(4,0,0,0,0,0,0,0,0,0,16)
    fields.update({f'block:0:0:{i}':(0,0,0,0) for i in range(16)})
    fields.update({f'contact:{i}':(0,0,0) for i in range(65)})
    (path/'metadata.txt').write_text(''.join(k+' '+' '.join(map(str,v))+'\n' for k,v in fields.items()),encoding='ascii')
