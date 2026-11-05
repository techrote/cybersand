#!/usr/bin/env python3
"""Offline copied-data completeness and no-op lease model. No engine bindings."""
import copy
import hashlib
import json
import math
from pathlib import Path
import la_physical_reduce as geometry

if not __debug__:
    raise RuntimeError('Offline model requires assertion checks; optimized Python is refused')

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'godot/tests/fixtures/sol_chamber/source.json'
SOURCE_SHA='5be5494e1ca530587d65ca8fdb39214b80e84da7f7105a0becf7867d6c8cac10'
MAX_CENSUS=16384
MAX_EVENTS=256
MAX_LEASES=8
LEASE_EVENTS=32
AREA_FILTER=1e-9
NATIVE_INPUT_SHA='19315d08020e7278ea8826579e60d16c43f2ba6b718e8e227e233f208a1c4254'
RUNTIMES={'bbfa83cb45a23423fe3c3ead5f487adaba7ba22d727d721aeae6f2836e493922','7e7e300a75cc1538afa8b7dc0d8f1872b7df49e021311dc3226f78096d3f2446'}
DIGEST_KEYS={'native_source_sha256','native_runtime_sha256','material_lock_sha256','payload_sha256','shape_sha256','body_state_sha256'}
SERIAL_KEYS={'generation','epoch','tick','sample','mutation_serial','body_serial','mask_serial','actual_step'}
IDENTITY_KEYS=DIGEST_KEYS|SERIAL_KEYS|{'run','world','body'}
PROGRESS_KEYS=['mutation_serial','body_serial','mask_serial','actual_step']
def binding(stamp):return tuple(stamp[k] for k in ['run','body','generation','payload_sha256','shape_sha256','native_source_sha256','native_runtime_sha256','material_lock_sha256'])

def encoded(value):return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode('utf-8')
def digest(value):return hashlib.sha256(encoded(value)).hexdigest()
def integer(value):return type(value) is int and 0<=value<2**63
def identity_valid(value):
    return isinstance(value,dict) and set(value)==IDENTITY_KEYS and all(integer(value[k]) for k in SERIAL_KEYS) and all(isinstance(value[k],str) and 0<len(value[k])<=64 for k in ['run','world','body']) and all(isinstance(value[k],str) and len(value[k])==64 and all(c in '0123456789abcdef' for c in value[k]) for k in DIGEST_KEYS)
def scope():return dict(execution_domain='offline-copied-data-model',live_authority=False,actuation_permitted=False,native_mutations=0,rid_calls=0,applied_impulse=[0,0],applied_torque=0,applied_correction=[0,0],generated_work=0)
def canonical():
    raw=SOURCE.read_bytes().replace(b'\r\n',b'\n');assert hashlib.sha256(raw).hexdigest()==SOURCE_SHA
    return json.loads(raw)
def polygons(packet):
    xx,xy,yx,yy,tx,ty=packet['pose'];cx,cy=packet['stored_com']
    return [[(tx+xx*(x-cx)+yx*(y-cy),ty+xy*(x-cx)+yy*(y-cy)) for x,y in [(x,y),(x+w,y),(x+w,y+h),(x,y+h)]] for x,y,w,h in packet['rectangles']]
def hard_probe(polys,field):
    """Geometry-only historical witness, with the original strict exclusion filter."""
    ox,oy=field['origin'];width,height=field['size'];cells=[]
    assert integer(width) and integer(height) and 0<width*height<=MAX_CENSUS
    for material,count in field['material_runs']:
        assert integer(material) and integer(count) and count<=width*height-len(cells)
        cells.extend([material]*count)
    assert len(cells)==width*height
    counts={};hard=[]
    for material in cells:counts[str(material)]=counts.get(str(material),0)+1
    for index,material in enumerate(cells):
        if material not in [1,43]:continue
        x,y=ox+index%width,oy+index//width
        for proxy,poly in enumerate(polys):
            area=geometry.overlap(poly,x,y)
            if area>AREA_FILTER:hard.append(dict(cell=[x,y],material=material,proxy=proxy+1,area=area))
    return dict(**scope(),status='REFUSED_HARD_GEOMETRY' if hard else 'GEOMETRY_ONLY_AUTHORITY_UNKNOWN',material_counts=counts,hard_intersections=hard,area_filter=AREA_FILTER,authority_missing=['state tuples','temperature','residency','source/mask owner','mutation/body/mask serials','exclusive Active hold'])

def validate_capture(packet):
    """Internally complete supplied values are still never live owner evidence."""
    result=scope();reasons=[]
    try:
        # Bound every copied collection and primitive before serialization.
        assert isinstance(packet,dict) and set(packet)=={'schema','origin','capture_scope','mask_policy','world_health','identity','members','rectangles','stored_com','mass','geometric_inertia','body_inertia','pose','velocity','omega','footprint','census'},'capture schema'
        assert packet['schema']=='SOL-OFFLINE-CAPTURE-001' and packet['origin']=='synthetic-copied-values' and packet['capture_scope']=='current-pose-noop' and packet['mask_policy']=='synthetic-cell-centre-001' and packet['world_health']=='HEALTHY','scope/health/origin unavailable'
        assert identity_valid(packet['identity']),'incomplete identity'
        for key,count,width in [('members',520,6),('rectangles',6,4)]:
            assert isinstance(packet[key],list) and len(packet[key])==count and all(isinstance(row,list) and len(row)==width and all(type(v) is int and abs(v)<2**31 for v in row) for row in packet[key]),'bounded source tuples/partition'
        for key,count in [('pose',6),('velocity',2),('stored_com',2),('footprint',4)]:
            assert isinstance(packet[key],list) and len(packet[key])==count and all(type(v) in [int,float] and math.isfinite(v) and abs(v)<2**31 for v in packet[key]),'bounded body/footprint'
        assert all(type(packet[k]) in [int,float] and math.isfinite(packet[k]) and abs(packet[k])<2**63 for k in ['mass','geometric_inertia','body_inertia','omega']),'bounded body scalars'
        assert isinstance(packet['census'],list) and len(packet['census'])<=MAX_CENSUS,'census capacity'
        for row in packet['census']:
            assert isinstance(row,dict) and set(row)=={'cell','tuple','resident','source_owner','mask_owner','hot'},'census fields unavailable'
            assert isinstance(row['cell'],list) and len(row['cell'])==2 and all(type(v) is int and abs(v)<2**31 for v in row['cell']),'bounded census coordinate'
            assert isinstance(row['tuple'],list) and len(row['tuple'])==4 and all(type(v) is int and abs(v)<2**31 for v in row['tuple']),'full tuple unavailable'
            assert type(row['resident']) is bool and type(row['hot']) is bool and isinstance(row['source_owner'],str) and len(row['source_owner'])<=64 and (row['mask_owner'] is None or isinstance(row['mask_owner'],str) and len(row['mask_owner'])<=64),'bounded ownership witness'
        frozen=encoded(packet);data=json.loads(frozen)
        assert data['schema']=='SOL-OFFLINE-CAPTURE-001' and data['origin']=='synthetic-copied-values' and data['capture_scope']=='current-pose-noop' and data['mask_policy']=='synthetic-cell-centre-001', 'scope/origin unavailable'
        stamp=data['identity'];assert identity_valid(stamp),'incomplete identity'
        assert stamp['native_source_sha256']==NATIVE_INPUT_SHA and stamp['native_runtime_sha256'] in RUNTIMES,'source/runtime outside model'
        source=canonical()['original'];members=data['members'];rects=data['rectangles']
        assert members==[source['members'][i:i+6] for i in range(0,len(source['members']),6)],'source tuples/order differ'
        assert rects==[source['rectangles'][i:i+4] for i in range(0,len(source['rectangles']),4)],'six-proxy partition differs'
        positions={(m[0],m[1]) for m in members};partition=[(i,j) for x,y,w,h in rects for j in range(y,y+h) for i in range(x,x+w)]
        assert len(members)==len(positions)==len(partition)==len(set(partition))==520 and positions==set(partition),'member/partition ownership'
        assert (60,32) not in positions and (68,50) not in positions,'hole/concavity filled'
        assert data['stored_com']==source['center'] and data['mass']==source['mass'] and data['geometric_inertia']==source['inertia'],'COM/mass/geometric inertia'
        assert data['body_inertia']==70453.6484375,'actual body inertia outside model scope'
        pose=data['pose'];velocity=data['velocity'];omega=data['omega']
        assert len(pose)==6 and len(velocity)==2 and all(type(v) in [int,float] and math.isfinite(v) for v in pose+velocity+[omega]),'nonfinite body'
        xx,xy,yx,yy,_,_=pose
        assert abs(xx*xx+xy*xy-1)<=1e-6 and abs(yx*yx+yy*yy-1)<=1e-6 and abs(xx*yx+xy*yy)<=1e-6 and xx*yy-xy*yx>0,'not one rigid transform'
        assert stamp['payload_sha256']==digest(members) and stamp['shape_sha256']==digest(rects),'payload/shape digest'
        assert stamp['body_state_sha256']==digest([pose,velocity,omega,data['mass'],data['body_inertia']]),'body-state digest'
        assert stamp['material_lock_sha256']=='8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc','material source outside model'
        bounds=data['footprint'];assert len(bounds)==4 and all(type(v) is int for v in bounds),'footprint'
        ox,oy,width,height=bounds;assert 0<width*height<=MAX_CENSUS and width>0 and height>0,'census capacity'
        polys=polygons(data);points=[v for poly in polys for v in poly]
        assert ox<=math.floor(min(x for x,y in points))-1 and oy<=math.floor(min(y for x,y in points))-1 and ox+width>=math.ceil(max(x for x,y in points))+1 and oy+height>=math.ceil(max(y for x,y in points))+1,'incomplete interior/halo'
        census=data['census'];assert len(census)==width*height,'incomplete census'
        expected={(x,y) for y in range(oy,oy+height) for x in range(ox,ox+width)};seen=set();hard=[];granular=[]
        for row in census:
            assert set(row)=={'cell','tuple','resident','source_owner','mask_owner','hot'},'census fields unavailable'
            x,y=row['cell'];assert type(x) is int and type(y) is int and (x,y) in expected and (x,y) not in seen,'duplicate/foreign census coordinate';seen.add((x,y))
            values=row['tuple'];assert len(values)==4 and all(type(v) is int for v in values),'full tuple unavailable'
            material,a,b,temp=values
            assert material in [0,1,2,14,43] and 0<=a<=65535 and 0<=b<=255 and temp==200,'material/temperature outside model'
            assert row['resident'] is True and row['hot'] is False and row['source_owner']==stamp['world'],'unresident/hot/foreign source'
            assert row['mask_owner'] in [None,stamp['body']],'foreign/masked ownership'
            inside=any(all((b[0]-a[0])*(y+.5-a[1])-(b[1]-a[1])*(x+.5-a[0])>=0 for a,b in zip(poly,poly[1:]+poly[:1])) for poly in polys)
            assert row['mask_owner']==(stamp['body'] if inside else None),'current-pose synthetic mask differs'
            # This model excludes stored native material under its synthetic mask.
            # That is not a general proof of original-member identity ownership.
            if row['mask_owner']==stamp['body']:assert material==0,'unsupported masked native material'
            for proxy,poly in enumerate(polys):
                area=geometry.overlap(poly,x,y)
                if area>AREA_FILTER and material in [1,43]:hard.append(dict(cell=[x,y],material=material,proxy=proxy+1,area=area))
                if area>0 and material in [2,14]:granular.append(dict(cell=[x,y],material=material,proxy=proxy+1,area=area))
        assert seen==expected,'incomplete census'
        result.update(hard_intersections=hard,granular_intersections=granular,census_cells=len(census),captured_digest=hashlib.sha256(frozen).hexdigest(),
            support_eligibility='UNAVAILABLE: one-cell no-op halo does not cover original support predicate',member_identity_ownership='UNAVAILABLE: supplied tuple consistency is not owner-captured member identity')
        assert not hard,'hard exclusion above1e-9'
        result['status']='COMPLETE_FOR_NOOP_MODEL'
    except (AssertionError,KeyError,TypeError,ValueError,OverflowError) as error:
        reasons.append(str(error) or type(error).__name__);result['status']='REFUSED_OR_UNKNOWN'
    result['reasons']=reasons
    return result

class LeaseModel:
    """Bounded deterministic model; its opaque bytes cannot be live lease tokens."""
    def __init__(self):
        self.state='IDLE';self.world=None;self.retired=set();self.consumed=set();self.terminal=set();self.active=None
        self.generations={};self.actual_steps={};self.aggregate_bindings={};self.progress={};self.last_lease=None
        self.clock=-1;self.attempts=0;self.trace=[];self.trace_overflow=0
    def event(self,kind,now,stamp=None,packet=None,capture_digest=None):
        self.attempts+=1
        if len(self.trace)>=MAX_EVENTS:
            self.trace_overflow+=1
            known=self.active or self.last_lease
            if known is not None and known['stamp']['world']==self.world:
                stamp_held=known['stamp'];self.terminal.add((stamp_held['world'],stamp_held['body']))
            expired=known is not None and integer(now) and now>=self.clock and now>known['deadline']
            if integer(now) and now>=self.clock:self.clock=now
            self.active=None;self.state='EXPIRED' if expired else 'MODEL_CAPACITY_FAILURE'
            return dict(**scope(),accepted=False,reason='trace capacity; lease terminal, consumption retained',state=self.state)
        accepted=False;reason=''
        try:
            assert isinstance(kind,str) and 0<len(kind)<=32,'bounded event name'
            assert integer(now) and now>=self.clock,'model clock reversal';self.clock=now
            if kind=='simulate_partial_fault':
                known=self.active or self.last_lease
                fault=stamp if stamp is not None else (known['stamp'] if known else None)
                assert identity_valid(fault) and fault['world']==self.world,'known fault identity unavailable'
                assert self.aggregate_bindings.get(fault['world'])==binding(fault),'fault binding changed'
                assert (fault['world'],fault['body'],fault['generation'],fault['actual_step']) in self.consumed,'fault lease unknown'
                self.terminal.add((fault['world'],fault['body']));self.active=None;self.state='MODEL_TERMINAL_FAILURE'
                self.trace.append(dict(event=kind,now=now,accepted=True,reason='',state=self.state))
                return dict(**scope(),accepted=True,reason='',state=self.state)
            if self.active and now>self.active['deadline']:
                self.state='EXPIRED';self.active=None;raise AssertionError('fixed deadline expired; step remains consumed')
            if kind in ['grant','capture','main_validate','noop_ack','release']:
                assert identity_valid(stamp),'typed identity required on every identity-bearing event'
                # A refused competing request is not an admitted history sample.
                if kind=='grant':assert self.active is None,'exclusive lease busy; request leaves progress unchanged'
                if stamp['world'] in self.aggregate_bindings:
                    if self.aggregate_bindings[stamp['world']]!=binding(stamp):
                        if kind!='grant' and self.active:self.active=None;self.state='INVALIDATED'
                        raise AssertionError('one-aggregate World binding changed; aliases cannot renew')
                    current=tuple(stamp[k] for k in PROGRESS_KEYS);prior=self.progress[stamp['world']]
                    if not all(a>=b for a,b in zip(current,prior)):
                        if kind!='grant' and self.active:self.active=None;self.state='INVALIDATED'
                        raise AssertionError('progress serial clock reversal')
                    self.progress[stamp['world']]=current
            if kind=='grant':
                assert identity_valid(stamp),'request identity'
                body=(stamp['world'],stamp['body'],stamp['generation']);key=body+(stamp['actual_step'],)
                stable=body[:2]
                resource_binding=binding(stamp)
                assert self.aggregate_bindings.get(stamp['world'],resource_binding)==resource_binding,'one-aggregate World binding changed; aliases cannot renew'
                assert stamp['world'] not in self.retired and stable not in self.terminal,'retired/terminal incarnation'
                assert self.world in [None,stamp['world']],'old World not retired'
                assert self.generations.get(stable,stamp['generation'])==stamp['generation'],'body generation changed without World retirement'
                assert stamp['actual_step']>=self.actual_steps.get(stable,0),'actual step clock reversal'
                assert key not in self.consumed,'actual step already consumed'
                assert len(self.consumed)<MAX_LEASES,'consumption capacity; no eviction'
                assert now<=2**63-1-LEASE_EVENTS,'deadline clock capacity'
                self.aggregate_bindings[stamp['world']]=resource_binding;self.progress[stamp['world']]=tuple(stamp[k] for k in PROGRESS_KEYS)
                self.generations[stable]=stamp['generation'];self.actual_steps[stable]=stamp['actual_step']
                self.consumed.add(key);self.world=stamp['world'];self.active=dict(stamp=copy.deepcopy(stamp),deadline=now+LEASE_EVENTS,digest=None)
                self.last_lease=copy.deepcopy(self.active)
                self.state='HELD';accepted=True
            elif kind=='retire':
                assert self.active is None and self.world is not None,'held World cannot retire'
                assert len(self.retired)<MAX_LEASES,'retirement capacity'
                self.retired.add(self.world);self.world=None;self.state='RETIRED';accepted=True
            else:
                assert self.active is not None,'no held model lease'
                if kind in ['tick','prepare','emission','paint','relocate','reset','replacement','teardown']:
                    raise AssertionError('modeled mutation refused during hold')
                if kind=='cancel':self.active=None;self.state='CANCELLED';accepted=True
                else:
                    if stamp!=self.active['stamp']:
                        self.active=None;self.state='INVALIDATED';raise AssertionError('identity/history changed, including ABA')
                    if kind=='capture':
                        assert self.state=='HELD','capture order'
                        result=validate_capture(packet)
                        if result['status']!='COMPLETE_FOR_NOOP_MODEL' or packet['identity']!=stamp:
                            self.active=None;self.state='REFUSED_CAPTURE';raise AssertionError('capture incomplete/mismatched')
                        self.active['digest']=result['captured_digest'];self.state='CAPTURED';accepted=True
                    elif kind in ['main_validate','noop_ack']:
                        assert self.state=={'main_validate':'CAPTURED','noop_ack':'MAIN_VALIDATED'}[kind],'ack order'
                        if capture_digest!=self.active['digest']:
                            self.active=None;self.state='INVALIDATED';raise AssertionError('capture ACK digest')
                        self.state='MAIN_VALIDATED' if kind=='main_validate' else 'NOOP_ACKNOWLEDGED';accepted=True
                    elif kind=='release':
                        assert self.state=='NOOP_ACKNOWLEDGED','release before no-op ACK'
                        self.active=None;self.state='RELEASED';accepted=True
                    else:raise AssertionError('unknown/reordered model event')
        except (AssertionError,TypeError) as error:reason=str(error)
        self.trace.append(dict(event=kind if isinstance(kind,str) and len(kind)<=32 else 'invalid-event',now=now if integer(now) else None,accepted=accepted,reason=reason,state=self.state))
        return dict(**scope(),accepted=accepted,reason=reason,state=self.state)
    def snapshot(self):
        return dict(**scope(),state=self.state,attempts=self.attempts,trace_overflow=self.trace_overflow,consumed_leases=len(self.consumed),trace=copy.deepcopy(self.trace))
