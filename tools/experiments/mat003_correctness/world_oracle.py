"""Streaming independent endpoint/trace decoding. No candidate packer imports."""
from pathlib import Path
from oracle import decode,encode,POSITIONS,Record
from dataclasses import replace

budget_hook=lambda:None

def small_boundary(pos,record,side):
    """Independent fixed two-cell moat contract; epoch may clear normally."""
    x,y=pos
    if x<2 or y<2 or x>=side-2 or y>=side-2:
        if (record.material,record.a,record.b,record.r,record.unused)!=(1,0,0,0,0):
            raise ValueError('small fixture containment wall corrupted')


def resident_endpoint(rows,side,endpoint):
    """Independent literal geometry/list contract; no fixture constant imports."""
    if side not in (512,2048) or endpoint not in ('B','P','Q','R'):
        raise ValueError('unreviewed resident endpoint')
    chunks=(side//128)**2
    c=rows['config']
    if (c[0],c[1],c[3],c[4],c[5],c[6],c[7],c[9],c[10],c[11],c[12])!=(128,3,chunks,1,32,64,2,1,256,chunks,chunks):
        raise ValueError('resident scratch/geometry provisioning drift')
    width=512 if endpoint=='R' else 256
    region=(1,0,0,width//64-1,7)
    if rows['interest']!=(1,0,0,width,512) or rows['selected']!=region or rows['applied']!=region:
        raise ValueError('resident interest/reentry coverage drift')
    # Worst case, including transition wakes: every selected 32-square block
    # contributes once; four such blocks alias each unique aligned64 core.
    raw=(width//32)*(512//32);unique=(width//64)*8
    if raw>c[10] or unique>64 or chunks>c[11]:
        raise ValueError('resident append/job/chunk bound exceeded')
    if endpoint!='R':
        threshold=c[1]
        sleeping=False
        # Source-bound non-vacuous witness: ActivityBlock initializes inactive/quiet0,
        # finish_tick skips already-inactive blocks, and an active selected block is
        # made inactive only after reaching sleep_after_quiet_ticks. Therefore an
        # inactive chunk containing at least one inactive block at the threshold is
        # direct evidence of a real sleep transition. Untouched blocks may remain
        # inactive/quiet0 and must not be required to age.
        for y in range(4):
            for x in range(2):
                chunk=rows.get(f'chunk:{x}:{y}')
                blocks=[rows.get(f'block:{x}:{y}:{i}') for i in range(16)]
                if chunk is None or len(chunk)<5 or any(b is None or len(b)!=4 for b in blocks):
                    raise ValueError('resident activity ownership/metadata drift')
                if chunk[2]==0:
                    if chunk[4]!=threshold or any(b[2]!=0 or b[1] not in (0,threshold) for b in blocks):
                        raise ValueError('resident inactive chunk/activity contradiction')
                    sleeping|=any(b[1]>=threshold for b in blocks)
        # Chunk (3,0) is deliberately resident but outside the narrow initial
        # interest. Source retains excluded active blocks without aging them.
        excluded=rows.get('chunk:3:0')
        excluded_blocks=[rows.get(f'block:3:0:{i}') for i in range(16)]
        if excluded is None or len(excluded)<5 or any(b is None or len(b)!=4 for b in excluded_blocks):
            raise ValueError('resident exclusion ownership/metadata drift')
        if excluded[2]!=1 or excluded[4]!=0 or not any(b[2]==1 and b[1]<threshold for b in excluded_blocks):
            raise ValueError('resident exclusion witness absent/contradictory')
        if not sleeping:
            raise ValueError('resident sleep transition witness absent')

def resident_sand_witness(positions,endpoint):
    # Only one Sand starts outside the initial x<256 interest; bounded inputs
    # stay inside it. Reentry must actually resume this previously excluded cell.
    if len(positions)!=1 or (endpoint!='R' and positions!=[(504,8)]) or (endpoint=='R' and (positions==[(504,8)] or not (256<=positions[0][0]<512 and 8<positions[0][1]<512))):
        raise ValueError('resident excluded Sand/reentry witness mismatch')

def decode_world(arm,data):
    # Independent mathematical ranges; storage admission still uses bit enumeration.
    capacity,epoch_positions,r_positions=POSITIONS[arm]
    if len(data)!=capacity//8:raise ValueError("World canonical width")
    value=int.from_bytes(data,"little")
    material=value&65535;a=(value>>16)&65535;b=(value>>32)&255
    epoch=(value>>epoch_positions[0])&((1<<len(epoch_positions))-1)
    r=(value>>r_positions[0])&65535 if r_positions else 0
    if arm=="K64-E16":u=(value>>40)&255
    elif arm.endswith("E8"):u=value>>64
    else:u=value>>72
    return Record(material,a,b,epoch,r,u)

def metadata(root):
    if (Path(root)/'metadata.txt').stat().st_size>17*1024**2:raise ValueError('metadata exceeds maximum envelope')
    rows={}
    for line in (Path(root)/'metadata.txt').read_text(encoding='ascii').splitlines():
        key,*values=line.split()
        if key in rows:raise ValueError('duplicate metadata key')
        rows[key]=tuple(map(int,values))
    required=('layout','schema','clock','flags','allocations','config','physics_config','interaction','water_policy','transport','interest','selected','applied','explosions','scratch','dispatch','stats','phases','support','discovery','transient','physics','clears')
    if any(k not in rows for k in required):raise ValueError('missing owner metadata')
    if rows['discovery']!=(0,) or rows['transient']!=(1,0,0,0,0,0,0):raise ValueError('nonempty inapplicable owner')
    contacts={k:v for k,v in rows.items() if k.startswith('contact:')}
    if set(contacts)!={f'contact:{i}' for i in range(65)} or any(v!=(0,0,0) for v in contacts.values()):raise ValueError('missing/nonzero body contact')
    if rows['clock'][4]!=0:raise ValueError('endpoint not quiescent')
    if len(rows['config'])!=20 or rows['config'][0]!=128 or rows['config'][15]!=0 or rows['config'][18]!=0:raise ValueError('unreviewed config')
    if rows['ledger'][1]!=0:raise ValueError('ledger overflow')
    if len(rows['scratch'])!=5 or rows['scratch'][1]<rows['config'][11] or rows['scratch'][3]<rows['config'][10] or rows['scratch'][0]>rows['config'][11] or rows['scratch'][2]>rows['config'][10] or rows['scratch'][4]!=(rows['config'][4]==1):raise ValueError('scratch/config applicability or bound')
    if rows['scratch'][-1]:
        if 'parallel' not in rows or len(rows['parallel'])!=6 or rows['parallel'][0]!=rows['config'][10] or rows['parallel'][2]!=rows['config'][10] or rows['parallel'][3]>rows['config'][10] or rows['parallel'][-1]!=(rows['config'][8]>1):raise ValueError('pool applicability')
    if rows['water_policy']!=(1,8,12,0,255,48,1) or rows['physics_config']!=(1,0,-1) or rows['interaction']!=(1,8,9,30):raise ValueError('unreviewed semantic policy')
    if rows['transport']!=(0,)+((2,)*81)+((1,)*81)+((0,0,64,8,0,1)*6561):raise ValueError('unreviewed transport policy')
    for key,value in rows.items():
        if key.startswith('chunk:'):
            if len(value)!=11 or value[0]!=4 or value[-1]!=16 or not 0<=value[1]<=16384 or any(value[i] not in (0,1) for i in (2,3,5)):raise ValueError('chunk activity metadata')
            for i in range(16):
                block=rows.get('block:'+key[6:]+':'+str(i))
                if block is None or len(block)!=4 or any(x<0 for x in block) or block[2] not in (0,1) or block[3] not in (0,1):raise ValueError('missing/invalid activity block/deadline')
    events={k:v for k,v in rows.items() if k.startswith('event:')}
    if rows['ledger'][0]!=len(events) or any(len(v)!=1 or v[0]<0 for v in events.values()):raise ValueError('ledger inventory')
    return rows

def registry(path,arm):
    result=[];stride=POSITIONS[arm][0]//8
    for line in Path(path).read_text(encoding='ascii').splitlines():
        xy,count,base=line.split();x,y=map(int,xy.split(':'));count,base=int(count),int(base)
        if count!=16384 or base<=0:raise ValueError('registry owner geometry')
        result.append((x,y,count,base))
    if len(set((x,y) for x,y,_,_ in result))!=len(result):raise ValueError('duplicate registry chunk')
    if any(not (a+n*stride<=b or b+m*stride<=a) for i,(_,_,n,a) in enumerate(result) for _,_,m,b in result[i+1:]):raise ValueError('overlapping storage owners')
    return result

def coordinate(reg,arm,address):
    stride=POSITIONS[arm][0]//8
    for x,y,count,base in reg:
        if base<=address<base+count*stride:
            if (address-base)%stride:raise ValueError('unaligned record token')
            return x*128+(address-base)//stride%128,y*128+(address-base)//stride//128
    return None

def cells(root,arm):
    root=Path(root);stride=POSITIONS[arm][0]//8;last=None
    with (root/'cells.bin').open('rb') as stream:
        for line in (root/'chunks.txt').read_text(encoding='ascii').splitlines():
            budget_hook()
            x,y,count,temp,base=map(int,line.split())
            if last is not None and (y,x)<=last:raise ValueError('duplicate/unordered chunks')
            last=y,x
            if count!=16384 or temp not in (0,1):raise ValueError('chunk geometry/temperature presence')
            for i in range(count):
                raw=stream.read(stride+2)
                if len(raw)!=stride+2:raise ValueError('truncated cells')
                r=decode_world(arm,raw[:stride]);temperature=int.from_bytes(raw[stride:],'little',signed=True)
                if r.material>131 or r.material==10:raise ValueError('material catalogue drift')
                yield (x*128+i%128,y*128+i//128),r,temperature,bool(temp),base+i*stride
        if stream.read(1):raise ValueError('extra cells')

def projected(r,temperature,current):
    return r.material,r.a,r.b,temperature,r.epoch==current

def compare(left,right,arm_a,arm_b,*,prepared=False):
    """Full streaming comparison; preparation permits only predicate-preserving labels."""
    from itertools import zip_longest
    a,b=metadata(left),metadata(right)
    for x,y in zip_longest(cells(left,arm_a),cells(right,arm_b)):
        if x is None or y is None or x[0]!=y[0] or projected(x[1],x[2],a['clock'][2])!=projected(y[1],y[2],b['clock'][2]) or x[3]!=y[3]:raise ValueError('common semantic mismatch')
        if prepared and (x[1].r,x[1].unused)!=(y[1].r,y[1].unused):raise ValueError('restore lost neutral state')
    ignore={'clock'} if prepared else {'schema','layout','clock','dispatch','clears','scratch','parallel'}
    # Worker-sensitive bookkeeping is checked per case rather than erased as semantic state.
    for k in set(a)|set(b):
        if k not in ignore and a.get(k)!=b.get(k):raise ValueError('metadata mismatch: '+k)
    if prepared and a['clock'][:2]!=b['clock'][:2]:raise ValueError('restoration changed clocks')

def seed_model(arm,reg):
    cap,_,positions=POSITIONS[arm];occupied=set(range(40))|set(POSITIONS[arm][1])|set(positions)
    width=cap-len(occupied)
    points={(3,3):(0x81a5,(1<<width)-1),(7,7):(0x8000,0),(8,7):(0xff,0),(9,7):(0xff00,0),(10,7):(0x5555,0),(11,7):(0xaaaa,0),(20,20):(0x100,0),(40,40):(0xff00,0)}
    return {p:(r if positions else 0,u) for p,(r,u) in points.items() if (r if positions else 0) or u}

class Transitions:
    def __init__(self,arm,reg):self.arm=arm;self.reg=reg;self.model=seed_model(arm,reg);self.stack={}
    def feed(self,line):
        tick,index,kind,destination,source,value,ok,pre,raw_input,post=line.split()
        tick,index,kind,destination,source,value,ok=map(int,(tick,index,kind,destination,source,value,ok))
        before,other,after=(decode(self.arm,bytes.fromhex(v)) for v in (pre,raw_input,post))
        dst=coordinate(self.reg,self.arm,destination);src=coordinate(self.reg,self.arm,source)
        known=self.model if dst is not None else self.stack;key=dst if dst is not None else destination
        if kind not in (1,2) and (before.r,before.unused)!=known.get(key,(0,0)):raise ValueError('transition prestate provenance')
        if kind in (0,1):
            source_state=self.model.get(src,(0,0)) if src is not None else self.stack.get(source,(0,0))
            if (other.r,other.unused)!=source_state:raise ValueError('copy source provenance')
            if bytes.fromhex(post)!=bytes.fromhex(raw_input):raise ValueError('whole copy lost bits')
            expected=source_state
        elif kind==2:
            if any(bytes.fromhex(post)):raise ValueError('default record not zero')
            expected=(0,0)
        elif kind in (3,4):
            try:
                changed=replace(before,**({'r':value} if kind==3 else {'unused':value}))
                expected_bytes=encode(self.arm,changed,raw=True);expected_ok=True
            except ValueError:
                expected_bytes=bytes.fromhex(pre);expected_ok=False
            if bool(ok)!=expected_ok:raise ValueError('R refusal')
            if bytes.fromhex(post)!=expected_bytes:raise ValueError('partial field/refusal corrupted unrelated bits')
            expected=(changed.r,changed.unused) if expected_ok else (before.r,before.unused)
        else:raise ValueError('unknown transition kind')
        if (after.r,after.unused)!=expected:raise ValueError('neutral transition mismatch')
        known[key]=expected
        if len(self.stack)>16384 or len(self.model)>262144:raise ValueError("bounded provenance model exceeded")
    def check(self,endpoint):
        actual={}
        for pos,r,t,present,address in cells(endpoint,self.arm):
            value=r.r,r.unused
            if value!=(0,0):actual[pos]=value
        expected={p:v for p,v in self.model.items() if v!=(0,0)}
        if actual!=expected:raise ValueError('full endpoint disagrees with transition model')
