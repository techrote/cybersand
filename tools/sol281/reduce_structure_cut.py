"""Independent recorded geometry/motion reducer; imports no candidate code."""
import argparse,collections,hashlib,json,math,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def state(r):return struct.unpack('<11d',bytes.fromhex(r['bits']))
def ke(a):return .5*a[9]*(a[6]**2+a[7]**2)+.5*a[10]*a[8]**2
def near(x,y):
    b=struct.unpack('<I',struct.pack('<f',abs(y)))[0];rounded=struct.unpack('<f',struct.pack('<I',b))[0];ulp=struct.unpack('<f',struct.pack('<I',b+1))[0]-rounded
    return abs(x-y)<=4*ulp
def transform(p,xy):return (p[0]*xy[0]+p[2]*xy[1]+p[4],p[1]*xy[0]+p[3]*xy[1]+p[5])
def corners(p,s):
    hx,hy=s['data'];return [transform(p,transform(s['transform'],xy)) for xy in [(-hx,-hy),(hx,-hy),(hx,hy),(-hx,hy)]]
def clip(poly,x,y):
    out=list(poly)
    for axis,bound,greater in [(0,x,True),(0,x+1,False),(1,y,True),(1,y+1,False)]:
        old=out;out=[]
        if not old:break
        a=old[-1];ina=a[axis]>=bound if greater else a[axis]<=bound
        for b in old:
            inb=b[axis]>=bound if greater else b[axis]<=bound
            if ina!=inb:
                t=(bound-a[axis])/(b[axis]-a[axis]);out.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
            if inb:out.append(b)
            a=b;ina=inb
    return out
def area(poly):
    if len(poly)<3:return 0.
    ox,oy=poly[0];return abs(sum((a[0]-ox)*(b[1]-oy)-(a[1]-oy)*(b[0]-ox) for a,b in zip(poly,poly[1:]+poly[:1])))*.5
def depth(poly,x,y):
    cell=[(x,y),(x+1,y),(x+1,y+1),(x,y+1)];axes=[(1.,0.),(0.,1.)];minimum=math.inf
    for a,b in zip(poly[:2],poly[1:3]):
        dx,dy=b[0]-a[0],b[1]-a[1];n=math.hypot(dx,dy);axes.append((-dy/n,dx/n))
    for ax,ay in axes:
        a=[u*ax+v*ay for u,v in poly];b=[u*ax+v*ay for u,v in cell];minimum=min(minimum,max(a)-min(b),max(b)-min(a))
    return max(0.,minimum)
def geometry(p,shapes,cells):
    total=0.;maximum=0.;count=0;deepest=None
    for index,s in enumerate(shapes):
        poly=corners(p,s)
        for y in range(math.floor(min(a[1] for a in poly)),math.ceil(max(a[1] for a in poly))):
            for x in range(math.floor(min(a[0] for a in poly)),math.ceil(max(a[0] for a in poly))):
                m=cells.get((x,y),0)
                if not m:continue
                overlap=area(clip(poly,x,y))
                if overlap<=1e-9:continue
                penetration=depth(poly,x,y);total+=overlap;count+=1
                if penetration>maximum:maximum=penetration;deepest=dict(proxy=index,cell=[x,y],material=m,area=overlap,depth=penetration)
    return dict(area=total,depth=maximum,witnesses=count,deepest=deepest)
def cells(r):
    d=r['diagnostic_snapshot'];w,h=d['size'];ox,oy=d['origin'];out={};offset=0
    for m,count in d['material_runs']:
        for i in range(offset,offset+count):
            if m:out[(ox+i%w,oy+i//w)]=m
        offset+=count
    assert offset==w*h;c=collections.Counter(out.values());assert all(c[i]==n for i,n in enumerate(d['counts']) if i)
    return out
def rest(rows):
    a=[state(r) for r in rows];angles=[math.atan2(s[1],s[0]) for s in a]
    for i in range(1,len(angles)):
        while angles[i]-angles[i-1]>math.pi:angles[i]-=2*math.pi
        while angles[i]-angles[i-1]<-math.pi:angles[i]+=2*math.pi
    v=max(math.hypot(s[6],s[7]) for s in a);w=max(abs(s[8]) for s in a);dx=max(s[4] for s in a)-min(s[4] for s in a);dy=max(s[5] for s in a)-min(s[5] for s in a);angle=max(angles)-min(angles)
    return dict(samples=len(a),max_speed=v,max_abs_omega=w,x_span=dx,y_span=dy,angle_span=angle,max_vertex_speed=max(r['maximum_vertex_speed'] for r in rows),sleeping=sum(r['sleeping'] for r in rows),screen_pass=v<=.5 and w<=.02 and dx<=.5 and dy<=.5 and angle<=.05)
def episode(d,raw):
    assert not d['failures'];steps=d['steps'];expected=720 if d['surroundings']=='empty' else 360;assert len(steps)==expected
    pre=d['prepared'];n=pre['member_count'];members=[tuple(pre['members'][i:i+6]) for i in range(0,len(pre['members']),6)];xy={(m[0],m[1]) for m in members}
    assert len(xy)==len(members)==n and all(m[2:]==(43,0,0,200) for m in members)
    cx=sum(x+.5 for x,y in xy)/n;cy=sum(y+.5 for x,y in xy)/n;inertia=sum((x+.5-cx)**2+(y+.5-cy)**2+1/6 for x,y in xy)
    assert pre['mass']==n and near(pre['center'][0],cx) and near(pre['center'][1],cy) and near(pre['inertia'],inertia)
    union=set();rects=pre['rectangles']
    for i in range(0,len(rects),4):
        x,y,w,h=rects[i:i+4];part={(xx,yy) for yy in range(y,y+h) for xx in range(x,x+w)};assert not union&part;union|=part
    assert union==xy and sum(d['proxy_masses'])==n and len(d['server_shapes'])==pre['shape_count']
    for i,s in enumerate(d['server_shapes']):
        x,y,w,h=rects[i*4:i*4+4];assert s['type']==4 and not s['owner_disabled'] and not d['scene_shapes'][i]['disabled'] and s['data']==[w/2,h/2] and d['proxy_sizes'][i]==[w,h]
        t=s['transform'];assert t[:4]==[1.,0.,0.,1.] and near(t[4],x+w/2-pre['center'][0]) and near(t[5],y+h/2-pre['center'][1])
    if d['structure']=='tree':assert n==520 and (60,32) not in xy and (68,50) not in xy
    else:assert n==356
    for r in [d['initial_native'],d['final_native']]:assert r['aggregate_owned']==n and r['native_source_members']==0 and r['members']==pre['members'] and not r['worker_failed'] and r['configured_workers']==d['workers']
    before=cells(d['before_cut']);initial=cells(d['initial_native']);final=cells(d['final_native']);hard={p:m for p,m in initial.items() if m in (1,43)}
    assert hard=={p:m for p,m in final.items() if m in (1,43)} and collections.Counter(before.values())[43]-collections.Counter(initial.values())[43]==n+8
    assert not xy&{p for p,m in initial.items() if m==43}
    counts0=collections.Counter(initial.values());assert counts0==collections.Counter(final.values()),'native material quantities changed'
    geoms=[];ledger=[];sand_deltas=[];outcomes=collections.Counter()
    for index,row in enumerate(steps):
        assert row['step']==index
        for label in ['before','after_application','after_step']:
            r=row[label];a=state(r);assert all(math.isfinite(v) for v in a) and a[9]==n and near(a[10],inertia) and r['valid'] and not r['frozen'] and r['generation']==d['initial_body']['generation'] and r['physics_epoch']==d['initial_body']['physics_epoch']
        b=state(row['before']);a=state(row['after_application']);s=state(row['after_step']);assert row['after_step']['manual_step']==index+1
        geom=geometry(s[:6],d['server_shapes'],hard);geoms.append(geom);response=row['response'];delta=None
        if row['response_is_new']:
            outcomes[response['outcome']]+=1
            if response.get('accepted'):delta=ke(a)-response['energy_before'];sand_deltas.append(delta)
        ledger.append(dict(step=index,hard_area=geom['area'],hard_depth=geom['depth'],hard_witnesses=geom['witnesses'],before_ke=ke(b),after_application_ke=ke(a),after_step_ke=ke(s),application_ke_delta=ke(a)-ke(b),sand_ke_delta_from_receipt=delta,potential_change=-s[9]*row['after_step']['gravity'][1]*(s[5]-b[5]),position_correction=[a[4]-b[4],a[5]-b[5]],ordinary_impulses=row['ordinary_impulse_applications_delta'],ordinary_corrections=row['ordinary_correction_applications_delta'],response_new=row['response_is_new'],snapshot=row['after_application']['snapshot_serial'],native_tick=row['after_application']['native_tick'],sample=row['after_application']['sample_serial']))
    metrics=d['metrics'];physical=metrics['physical_contact'];assert physical['energy_violations']==0 and not physical['response_failures'] and sum(outcomes.values())==physical['response_attempts']
    times=[r['elapsed_us']/1000 for r in steps]
    out={k:d[k] for k in ['source','workers','structure','surroundings','sand_response','checks']}
    out.update(raw=raw,host=d['platform'],steps=expected,ownership_pass=True,mass=n,geometric_com=[cx,cy],geometric_inertia=inertia,actual_inertia=state(d['initial_body'])[10],proxies=pre['shape_count'],member_tuple_sha256=hashlib.sha256(json.dumps(members,separators=(',',':')).encode()).hexdigest(),native_material_counts=dict(counts0),native_material_conserved=True,hard_map_constant=True,gravity=d['initial_body']['gravity'],linear_damp=d['initial_body']['linear_damp'],angular_damp=d['initial_body']['angular_damp'],gravity_impulse_per60=n*d['initial_body']['gravity'][1]/60,ordinary_cap=d['authored']['ordinary_impulse_cap'],first_reported_contact=next((i for i,r in enumerate(steps) if r['after_step']['contacts']),None),first_sleep=next((i for i,r in enumerate(steps) if r['after_step']['sleeping']),None),tail120=rest([r['after_step'] for r in steps[-120:]]),peak_hard_area=max(g['area'] for g in geoms),peak_hard_depth=max(g['depth'] for g in geoms),terminal_hard=geoms[-1],tail120_hard_area_reference_pass=all(g['area']<=1e-6 for g in geoms[-120:]),tail120_hard_depth_reference_pass=all(g['depth']<=2e-5 for g in geoms[-120:]),initial_sand=geometry(state(d['initial_body'])[:6],d['server_shapes'],{p:m for p,m in initial.items() if m==2}),terminal_sand=geometry(state(steps[-1]['after_step'])[:6],d['server_shapes'],{p:m for p,m in final.items() if m==2}),response_outcomes=dict(outcomes),sand_receipt_ke_delta_sum=sum(sand_deltas),sand_receipt_ke_delta_max=max(sand_deltas,default=None),all_metrics=metrics,observed_main_ms_mean=sum(times)/len(times),observed_main_ms_max=max(times),contact_limit_steps=sum(r['after_step']['contact_report_may_be_truncated'] for r in steps),ledger=ledger)
    return out
def main():
    p=argparse.ArgumentParser(__doc__);p.add_argument('--runs',nargs='+',required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args();assert not args.output.exists();results=[];receipts=[]
    for name in args.runs:
        folder=ROOT/'build/sol-structure-cut'/name;receipt=json.loads((folder/'receipt.json').read_text());assert receipt['post_source_equality'];receipts.append(dict(run=name,sha256=sha(folder/'receipt.json'),identity=receipt['identity']))
        for host,h in receipt['hosts'].items():
            for command in h['commands']:
                if 'report' not in command:continue
                raw=command['report'];path=ROOT/raw['path'];assert command['clean'] and command['report_complete'] and sha(path)==raw['sha256'];d=json.loads(path.read_text());assert d['source']==receipt['identity']['source_commit'];row=episode(d,raw);row['run']=name;results.append(row)
    output=dict(reducer_sha256=sha(__file__),qualifiers=['Per-step hard geometry uses unchanged inert native map and actual server shapes. Sand endpoint map is paused after trajectory, not synchronized clearance.','Receipt energy_before baseline usesfloat32norm; repair scalar64. Actual after_application KE from11doublebits; combined application includes ordinary and Sand. Contact impulses cached. No total Sand energy or original CPU pass.'],receipts=receipts,episodes=results)
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8');print('episodes',len(results),'steps',sum(r['steps'] for r in results))
if __name__=='__main__':main()
