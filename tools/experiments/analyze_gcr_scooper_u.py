"""Authenticate the geometry-only Scooper U comparison without hiding rim loss."""
import argparse
import collections
import hashlib
import json
import math
import struct
import subprocess
from pathlib import Path

from analyze_gcr_authored import (EvidenceError, archived, bundle_path, digest,
    distribution, finite, integer, norm, read, require, same, source_scope,
    state_metrics, verify_source_map)

ROOT=Path(__file__).resolve().parents[2]
REG="GCR-UHULL-003"
PROTOCOL="docs/audits/gcr-u-hull-2026-11-04/protocol.json"
FROZEN_PROTOCOL="7c203a6fff4f32b4eb92af75bc5c70eef1f12d63"
FROZEN_U="b19159f552dac98cee2f0da38b35baffd3cea3b6"
BASELINE="350a9814fe50609b8eb664a8896fb9e3d5e69dd0"
SELECTORS={"LA":"control","LA-EVENT-OFF":"off","LA-SELECTIVE":"selective"}
FLAGS=("primary_cavity","core_cavity","below_closed_floor","beyond_left","beyond_right","above_rim")

def git_file(source,path):
    return subprocess.check_output(['git','-C',str(ROOT),'show',source+':'+path],timeout=60).replace(b'\r\n',b'\n')

def f32(value):return struct.unpack('f',struct.pack('f',value))[0]
def inside(point,r):return r[0]<=point[0]<r[0]+r[2] and r[1]<=point[1]<r[1]+r[3]
def local(pose,point):
    c,s=math.cos(pose['rotation']),math.sin(pose['rotation']);x,y=point[0]-pose['position'][0],point[1]-pose['position'][1]
    return[c*x+s*y,-s*x+c*y]
def world(pose,point):
    c,s=math.cos(pose['rotation']),math.sin(pose['rotation'])
    return[pose['position'][0]+c*point[0]-s*point[1],pose['position'][1]+s*point[0]+c*point[1]]
def geometry(definition):
    rects=definition['hull']['rects'];area=sum(r[2]*r[3]for r in rects)
    com=[sum(r[2]*r[3]*(r[i]+r[i+2]/2)for r in rects)/area for i in(0,1)]
    pieces=[{'center':[r[i]+r[i+2]/2-com[i]for i in(0,1)],'size':r[2:]}for r in rects]
    inertia=definition['physics']['mass']/area*sum(r[2]*r[3]*((r[2]**2+r[3]**2)/12+sum((r[i]+r[i+2]/2-com[i])**2 for i in(0,1)))for r in rects)
    bounds=[min(r[0]for r in rects),min(r[1]for r in rects),max(r[0]+r[2]for r in rects),max(r[1]+r[3]for r in rects)]
    return area,com,inertia,pieces,bounds

def validate_observation(o,definition,profile,com,pieces,bounds,counts,water,sample,current):
    require(o.get('failed')is False and len(o['grains'])==16 and o['observed_count']==16,'Complete observed grain set')
    cells={tuple(g['cell'])for g in o['grains']};require(len(cells)==16 and cells==set(map(tuple,o['points'])),'Unique coordinate set')
    x,y,w,h=o['roi'];require(w==h==128 and all(integer(v)for v in(x,y,w,h))and 0<=x<=896 and 0<=y<=384,'ROI bound')
    actual_roi=sum(x<=p[0]<x+w and y<=p[1]<y+h for p in cells);require(actual_roi==o['roi_count'],'Measured ROI count')
    if o['coverage']=='whole-fixture':require(o['outside_roi_count']==16-actual_roi and o['global_counts']==counts and o['global_water_mass']==water,'Global exact quantities')
    else:require(o['coverage']=='bounded-roi'and actual_roi==16 and o['outside_roi_count']is None and o['global_counts']is None and o['global_water_mass']is None,'No assumed unobserved quantity')
    floor=definition['hull']['rects'][profile['floor_index']];ambiguities=0
    for grain in o['grains']:
        require(all(integer(v)for v in grain['cell'])and 0<=grain['cell'][0]<1024 and 0<=grain['cell'][1]<512,'Stored-cell coordinate')
        require(integer(grain['native_mask_proxy'])and 0<=grain['native_mask_proxy']<=len(pieces),'Native mask range')
        for frame,pose in(('sampled',sample),('current',current)):
            q=grain[frame];p=q['authored_local'];lp=q['local']
            require(same(p,[lp[i]+com[i]for i in(0,1)],1e-4)and same(world(pose,lp),[v+.5 for v in grain['cell']],4e-4),'Copied frame coordinates')
            membership=[];definite=[];possible=[];near=False
            for index,r in enumerate(pieces):
                d=[abs(lp[i]-r['center'][i])-r['size'][i]/2 for i in(0,1)]
                if max(d)<=0:membership.append(index)
                if max(d)<-1e-4:definite.append(index)
                if max(d)<=1e-4:possible.append(index)
                near|=any(abs(v)<1e-4 for v in d)
            if near:ambiguities+=1
            else:require(membership==q['inside_rectangles'],'Separated hull membership')
            declared=q['inside_rectangles'];require(all(integer(v)and 0<=v<len(pieces)for v in declared),'Proxy membership indices')
            require(len(set(declared))==len(declared)and set(definite)<=set(declared)<=set(possible),'Boundary-qualified recomputed proxy membership')
            inner=floor[0]+1<=p[0]<floor[0]+floor[2]-1
            flags={'primary_cavity':inside(p,profile['cavity'])and not declared,'core_cavity':inside(p,profile['core'])and not declared,
                'floor_interior_x':inner,'below_closed_floor':inner and p[1]>floor[1]+floor[3],
                'beyond_left':p[0]<bounds[0],'beyond_right':p[0]>bounds[2],
                'within_side_height':profile['rim_y']<=p[1]<=floor[1]+floor[3],'above_rim':p[1]<profile['rim_y'],
                'left_is_closed':profile['left_index']>=0,'right_is_closed':profile['right_index']>=0,
                'inside_corner':any(i in profile['corner_indices']for i in declared)}
            require(all(type(q[k])is bool and q[k]==v for k,v in flags.items()),'Copied class/side flags')
            category='free_near_hull'
            if declared:category='floor'if profile['floor_index']in declared else'left_wall'if profile['left_index']in declared else'right_wall'if profile['right_index']in declared else'corner_or_nose'
            elif flags['below_closed_floor']:category='below_closed_floor'
            elif flags['beyond_left']:category='beyond_left'
            elif flags['beyond_right']:category='beyond_right'
            elif flags['above_rim']:category='above_rim'
            elif flags['primary_cavity']:category='cavity'
            require(q['class']==category,'Independent membership-derived class')
            require(same(q['below_floor_margin'],p[1]-floor[1]-floor[3],1e-4),'Floor signed distance')
    return ambiguities

def counts(o,frame):
    return {k:sum(g[frame][k]for g in o['grains'])for k in FLAGS}|{'inside_hull':sum(bool(g[frame]['inside_rectangles'])for g in o['grains'])}
def persistent(rows,flag):
    return[i for i in range(len(rows)-1)if counts(rows[i]['after'],'current')[flag]and counts(rows[i+1]['after'],'sampled')[flag]and counts(rows[i+1]['after'],'current')[flag]]
def compact(row):
    return {'tick':row['tick'],'sample_state':row['sample_state'],'state':row['state'],
        **{phase:{'points':row[phase]['points'],'flags':[{frame:{k:g[frame][k]for k in('authored_local','class','inside_rectangles',*FLAGS,'within_side_height')}for frame in('sampled','current')}for g in row[phase]['grains']]}for phase in('before','after')},
        'native':{k:row['gcr'].get(k)for k in('displaced','unresolved','cellular_overlap_pre','cellular_overlap_post','normal_accepted','event_budget_cost','global_capacity','impulse','torque')}}

def reduce_physical(raw,profile,spec,protocol,receipt):
    area,com,inertia,pieces,bounds=geometry(raw['definition'])
    require(same(raw['resolved_com'],com,1e-5)and same(raw['resolved_area'],area)and same(raw['resolved_inertia'],inertia,1e-4)and same(raw['hull_rectangles'],pieces,1e-5),'Derived union properties')
    floor=raw['definition']['hull']['rects'][profile['floor_index']];cavity=profile['cavity']
    spawn=[protocol['cavity_center_world_x']+com[0]-cavity[0]-cavity[2]/2,protocol['floor_top_world_y']+com[1]-floor[1]]
    require(same(raw['spawn'],spawn,1e-4)and same(raw['initial'],{'position':spawn,'velocity':[0,0],'rotation':0,'omega':0},1e-4),'Floor-aligned initial pose')
    require(abs(raw['mass']-.18)<1e-6 and abs(raw['inertia']-inertia)<1e-4,'One physical mass/inertia')
    require(raw['options']=={'response':spec['response'],'budget':20.,'mass_multiplier':1.,'inertia_multiplier':1.,'thrust_multiplier':1.,'torque_multiplier':1.,'boost_multiplier':2.},'Frozen overrides')
    seed={(x,249)for x in range(504,520)};require(set(map(tuple,raw['before']['points']))==seed,'Same initial native cargo')
    before=raw['before'];require(before['counts'][spec['material']]==16 and sum(before['counts'])==1024*512 and before['water_mass']==0,'Initial exact native quantity')
    require(raw['after']['counts']==before['counts']and raw['after']['water_mass']==before['water_mass'],'Final exact native quantity')
    rows=raw.get('rows',[]);issues=[];serials=set();sessions=set();ambiguous=0;previous=raw['before']['points']
    def check(ok,why,tick):
        if not ok:issues.append({'tick':tick,'reason':why})
    for tick,r in enumerate(rows):
        require(r['tick']==tick,'Contiguous observations')
        for phase,pose in(('before',r['sample_state']),('after',r['state'])):
            ambiguous+=validate_observation(r[phase],raw['definition'],profile,com,pieces,bounds,before['counts'],before['water_mass'],r['sample_state'],pose)
        check(set(map(tuple,r['before']['points']))==set(map(tuple,previous)),'No hidden between-boundary material edits',tick);previous=r['after']['points']
        if tick:check(same(r['sample_state'],rows[tick-1]['state']),'No post-construction body setter',tick)
        moving=protocol['move_from']<=tick<protocol['move_to'];trim=spec['trim']if moving else 0
        request={'action':{'move':[f32(v)for v in spec['move']]if moving else[0,0],'aim':[1,0],'effort':1.,'trim':trim,'primary':False,'secondary':protocol['move_to']<=tick<protocol['brake_to'],'auxiliary':False},
                 'ports':{'q':trim<0,'e':trim>0,'s':False,'boost':moving and spec['boost']}}
        check(same(r['request'],request),'Registered command interval',tick)
        g=r['gcr'];app=r['application'];bodies=app.get('bodies',[])
        check(r['observed_steps']==[1,1]and r['observed_response_counts'][0]==1 and r['observed_response_counts'][1]in(0,1),'One native/Rapier/response boundary',tick)
        check(app.get('accepted')is True and len(bodies)==1 and r['physical_wrench_applications']in(0,1),'One physical response owner',tick)
        if len(bodies)==1:
            b=bodies[0];check(b['sample']==g['sample_serial']and b['session']==g['session_id']and b['age']==0 and b['index']==0 and b['physical_wrench_applications']==r['physical_wrench_applications'],'Fresh aggregate application',tick)
            check(abs(b['actual_mass']-raw['mass'])<1e-6 and abs(b['actual_inertia']-raw['inertia'])<1e-4,'Actual one-body mass/inertia',tick)
        check(g['admission_kind']=='authored'and g['granular_events']==SELECTORS[spec['response']]and g['proxy_count']==len(pieces)and g['physical_body_id']==1,'Actual profile and selector',tick)
        check(integer(g['sample_serial'])and g['sample_serial']>0 and g['sample_serial']not in serials,'Fresh sample serial',tick);serials.add(g['sample_serial']);sessions.add(g['session_id'])
        check(g['normal_accepted']+g['event_budget_cost']<=g['global_capacity']+1e-8,'Shared impulse budget',tick)
        check(g['energy_after']<=g['energy_before']+1e-8*max(1.,g['energy_before']),'Passive body energy',tick)
        check(0<=g['nodes']<=16*len(pieces)and 0<=g['updates']<=128*len(pieces),'Bounded solver work',tick)
        if spec['response']=='LA-EVENT-OFF'or(spec['response']=='LA-SELECTIVE'and g['arrival_count']==0):check(g['event_accepted']==[0.,0.]and g['event_torque']==0 and g['event_budget_cost']==0,'Suppressed event closure',tick)
    check(len(sessions)<=1,'One session',None)
    complete=raw.get('ok')is True and not raw.get('errors')and len(rows)==450 and receipt.get('ok')is True and receipt.get('exit')==0
    selected=set();sides={}
    for flag in('below_closed_floor','beyond_left','beyond_right','above_rim'):
        seen=[i for i,r in enumerate(rows)if counts(r['after'],'current')[flag]];pers=persistent(rows,flag)
        witness=None
        if pers:
            i=pers[0];three=[rows[i]['before'],rows[i]['after'],rows[i+1]['after']]
            witness={'tick':i,'before_counts':counts(rows[i]['before'],'current'),'after_counts':counts(rows[i]['after'],'current'),'next_sampled':counts(rows[i+1]['after'],'sampled'),'next_current':counts(rows[i+1]['after'],'current'),
                'all_cloud_inside_floor_span':all(g['current']['floor_interior_x']for o in three for g in o['grains']),
                'all_cloud_within_side_height':all(g['current']['within_side_height']for o in three for g in o['grains']),
                'all_before_in_floor':all(all(abs(g['current']['local'][j]-pieces[profile['floor_index']]['center'][j])<pieces[profile['floor_index']]['size'][j]/2-1e-4 for j in(0,1))for g in rows[i]['before']['grains']),
                'strict_before_floor_count':sum(all(abs(g['current']['local'][j]-pieces[profile['floor_index']]['center'][j])<pieces[profile['floor_index']]['size'][j]/2-1e-4 for j in(0,1))for g in rows[i]['before']['grains']),
                'all_before_in_closed_floor_envelope':all(floor[0]+1<=g['current']['authored_local'][0]<floor[0]+floor[2]-1 and profile['rim_y']<=g['current']['authored_local'][1]<=floor[1]+floor[3]for g in rows[i]['before']['grains']),
                'prior_post_rim_boundaries':sum(counts(r['after'],'current')['above_rim']>0 for r in rows[:i]),
                'prior_post_outer_side_boundaries':sum(counts(r['after'],'current')['beyond_left']+counts(r['after'],'current')['beyond_right']>0 for r in rows[:i]),
                'floor_witness_scope':'Independent geometry requires every before point strictly inside the floor beyond the 1e-4 observation boundary band; ambiguous points do not establish this strong crossing witness. Envelope/history predicates describe coordinate sets and do not identify an individual parcel path.'}
            selected.update(j for j in(i-1,i,i+1)if 0<=j<len(rows))
        sides[flag]={'first_post_tick':seen[0]if seen else None,'post_boundaries':len(seen),'peak_count':max((counts(r['after'],'current')[flag]for r in rows),default=0),'first_persistent_tick':pers[0]if pers else None,'persistent_pairs':len(pers),'first_witness':witness}
    selected.update([len(rows)-1]if rows else[])
    return {'complete':complete,'mechanical_pass':complete and not issues,'issues':issues,'mass':raw['mass'],'area':area,'com':com,'inertia':inertia,'proxy_count':len(pieces),
        'motion':state_metrics(rows,raw['initial']),'primary_cavity_min':min((counts(r['after'],'current')['primary_cavity']for r in rows),default=None),'core_cavity_min':min((counts(r['after'],'current')['core_cavity']for r in rows),default=None),
        'phase_cavity_counts':{str(i):counts(rows[i]['after'],'current')['primary_cavity']for i in(119,239,329,449)if i<len(rows)},
        'sides':sides,'current_hull_overlap_boundaries':sum(counts(r['after'],'current')['inside_hull']>0 for r in rows),'classification_boundary_ambiguities':ambiguous,
        'displaced_sum':sum(r['gcr']['displaced']for r in rows),'max_overlap_post':max((r['gcr'].get('cellular_overlap_post',0)for r in rows),default=None),
        'maximum_nodes':max((r['gcr']['nodes']for r in rows),default=None),'maximum_updates':max((r['gcr']['updates']for r in rows),default=None),'owner_step_us':distribution([r['step_us']for r in rows])},[compact(rows[i])for i in sorted(selected)]

def packet_memberships(packet,cell):
    members=[]
    for i in range(0,len(packet),17):
        dx,dy=cell[0]+.5-packet[i+1],cell[1]+.5-packet[i+2];c,s=math.cos(packet[i+3]),math.sin(packet[i+3])
        if abs(c*dx+s*dy)<=packet[i+4]*.5 and abs(-s*dx+c*dy)<=packet[i+5]*.5:members.append(int(packet[i]))
    return members

def graph_exits(mask,roi,pose,com,bounds,profile,floor,diagonal,epsilon=0.):
    x,y,w,h=roi;occupied={p for p,v in mask.items()if v};queue=collections.deque();seen=set();parents={}
    def raw(p):return[a+b for a,b in zip(local(pose,[p[0]+.5,p[1]+.5]),com)]
    for yy in range(y,y+h):
        for xx in range(x,x+w):
            p=(xx,yy);q=raw(p)
            if p not in occupied and inside(q,profile['core'])and q[1]>=profile['rim_y']+epsilon:queue.append(p);seen.add(p)
    ds=[(-1,0),(1,0),(0,-1),(0,1)]+([(-1,-1),(1,-1),(-1,1),(1,1)]if diagonal else[]);exits={}
    while queue:
        p=queue.popleft()
        for dx,dy in ds:
            n=(p[0]+dx,p[1]+dy)
            if n in occupied or n in seen or not(x<=n[0]<x+w and y<=n[1]<y+h):continue
            q=raw(n)
            if q[1]<profile['rim_y']+epsilon:continue
            names=[]
            if q[0]<bounds[0]-epsilon:names.append('left')
            if q[0]>bounds[2]+epsilon:names.append('right')
            if q[1]>bounds[3]+epsilon:names.append('bottom')
            if names:
                name='+'.join(names);covered=floor[0]<=q[0]<=floor[0]+floor[2]
                exits[name]={'open_side':('left'in names and profile['left_index']<0)or('right'in names and profile['right_index']<0)or('bottom'in names and not covered),'ambiguous_corner':len(names)>1}
                continue
            seen.add(n);parents[n]=p;queue.append(n)
    return exits

def validate_graph_path(name,value,mask,roi,pose,com,bounds,profile,floor,degree):
    path=[tuple(p)for p in value['path']];x,y,w,h=roi
    require(2<=len(path)<=w*h+1 and len(set(path))==len(path),'Finite nonrepeating graph path')
    require(all(p in mask and x<=p[0]<x+w and y<=p[1]<y+h and not mask[p]for p in path),'Actual graph path is free in copied ROI mask')
    require(all(max(abs(a[0]-b[0]),abs(a[1]-b[1]))==1 and(degree==8 or abs(a[0]-b[0])+abs(a[1]-b[1])==1)for a,b in zip(path,path[1:])),'Actual graph adjacency')
    raw=[[a+b for a,b in zip(local(pose,[p[0]+.5,p[1]+.5]),com)]for p in path]
    core=profile['core'];first=raw[0]
    require(core[0]-1e-4<=first[0]<=core[0]+core[2]+1e-4 and core[1]-1e-4<=first[1]<=core[1]+core[3]+1e-4,'Path begins in cavity core')
    require(all(q[1]>=profile['rim_y']-1e-4 for q in raw),'Path does not cross the virtual rim cap')
    require(all(bounds[0]-1e-4<=q[0]<=bounds[2]+1e-4 and q[1]<=bounds[3]+1e-4 for q in raw[:-1]),'Path terminates at first outer exit')
    end=raw[-1];sides=[]
    if end[0]<bounds[0]:sides.append('left')
    if end[0]>bounds[2]:sides.append('right')
    if end[1]>bounds[3]:sides.append('bottom')
    require(sides and name=='+'.join(sides),'Exact geometric endpoint-side classification')
    covered=floor[0]<=end[0]<=floor[0]+floor[2]
    opened=('left'in sides and profile['left_index']<0)or('right'in sides and profile['right_index']<0)or('bottom'in sides and not covered)
    require(type(value['open_side'])is bool and value['open_side']==opened,'Independent open-side flag')
    require(type(value['ambiguous_corner'])is bool and value['ambiguous_corner']==(len(sides)>1),'Independent corner flag')
    require(type(value['floor_span_covered_x'])is bool and value['floor_span_covered_x']==covered,'Independent floor-span flag')
    sensitive=any(abs(q[1]-profile['rim_y'])<1e-4 for q in raw)or any(abs(end[0]-v)<1e-4 for v in(bounds[0],bounds[2],floor[0],floor[0]+floor[2]))or abs(end[1]-bounds[3])<1e-4
    return {'exit':name,'length':len(path),'open_side':opened,'ambiguous_corner':len(sides)>1,'boundary_sensitive':sensitive,'path':value['path']}

def reduce_raster(raw,profile,protocol,receipt):
    area,com,inertia,pieces,bounds=geometry(raw['definition']);floor=raw['definition']['hull']['rects'][profile['floor_index']]
    require(same(raw['resolved_com'],com,1e-5)and same(raw['resolved_area'],area)and same(raw['resolved_inertia'],inertia,1e-4)and same(raw['hull_rectangles'],pieces,1e-5),'Static derived geometry')
    require(len(raw['rows'])==24,'Static pose population');summary=[]
    for index,row in enumerate(raw['rows']):
        angle=protocol['raster']['angles'][index//8];phase=protocol['raster']['offsets'][index%8]
        require(same(row['angle'],angle)and same(row['phase'],phase)and row['admitted']is True and row['native_tick']==0,'Static registered pose, no native tick')
        packet=row['packet'];require(len(packet)==17*len(pieces),'Complete static proxy packet')
        roi=row['mask_roi'];x,y,w,h=roi;ids=row['mask_ids'];require(w==h==64 and len(ids)==w*h and all(integer(v)and 0<=v<=len(pieces)for v in ids),'Bounded copied mask IDs')
        require(same(row['pose']['position'],[protocol['raster']['origin'][i]+phase[i]for i in(0,1)])and abs(row['pose']['rotation']-angle)<1e-7,'Actual static pose')
        for proxy,piece in enumerate(pieces):
            offset=proxy*17;centre=world(row['pose'],piece['center'])
            require(packet[offset]==proxy+1 and same(packet[offset+1:offset+3],centre,4e-4)and packet[offset+3]==row['pose']['rotation']and same(packet[offset+4:offset+6],piece['size']),'Actual static copied rectangle')
            require(packet[offset+6:offset+9]==[0,0,0]and packet[offset+9]==.18 and packet[offset+10]==index+1 and abs(packet[offset+11]-inertia)<1e-4 and packet[offset+12:offset+14]==row['pose']['position']and packet[offset+14]==.8 and same(packet[offset+15],1/60)and packet[offset+16]==977,'Static physical/sample packet')
            for sx,sy in((-1,-1),(-1,1),(1,1),(1,-1)):
                vertex=world(row['pose'],[piece['center'][0]+sx*piece['size'][0]/2,piece['center'][1]+sy*piece['size'][1]/2])
                require(x+2<vertex[0]<x+w-2 and y+2<vertex[1]<y+h-2,'Static observation contains complete union')
        mask={(x+i%w,y+i//w):v for i,v in enumerate(ids)};mismatches=[];multi=0
        for p,value in mask.items():
            expected=packet_memberships(packet,p);multi+=len(expected)>1
            if bool(value)!=bool(expected)or(value and value not in expected):mismatches.append({'cell':list(p),'actual':value,'expected':expected})
        require(same(mismatches,row['mismatches'])and row['occupied']==sum(bool(v)for v in ids)and row['multi_proxy_boundary_centres']==multi,'Independent native-mask/union oracle')
        precision=[];missing=0;extras=0;proxy_only=0
        for mismatch in mismatches:
            if mismatch['actual']==0:missing+=1;continue
            if mismatch['expected']:proxy_only+=1
            else:extras+=1
            off=(mismatch['actual']-1)*17;cx,cy=mismatch['cell'];dx,dy=cx+.5-packet[off+1],cy+.5-packet[off+2];c,s=math.cos(packet[off+3]),math.sin(packet[off+3])
            lx,ly=c*dx+s*dy,-s*dx+c*dy
            precision.append({'cell':mismatch['cell'],'actual_proxy':mismatch['actual'],'ideal_outside_margin':max(abs(lx)-packet[off+4]/2,abs(ly)-packet[off+5]/2),
                'float32_local_inside':abs(f32(lx))<=f32(packet[off+4]/2)and abs(f32(ly))<=f32(packet[off+5]/2)})
        graphs=[]
        for degree in(4,8):
            observed=row['connectivity'+str(degree)];require(observed['seed_count']>0,'Cavity graph is not vacuously empty');claimed=observed['exit_paths'];recomputed=graph_exits(mask,roi,row['pose'],com,bounds,profile,floor,degree==8)
            path_checks=[]
            for name,value in claimed.items():
                path_checks.append(validate_graph_path(name,value,mask,roi,row['pose'],com,bounds,profile,floor,degree))
            strict=graph_exits(mask,roi,row['pose'],com,bounds,profile,floor,degree==8,1e-4)
            hidden_closed=[k for k,v in strict.items()if not v['open_side']and k not in claimed]
            require(not hidden_closed,'Unreported independent closed-side graph path')
            graphs.append({'neighbours':degree,'reported_paths':path_checks,'recomputed_exits':recomputed,'boundary_sensitive_difference':set(claimed)!=set(recomputed)})
        summary.append({'angle':angle,'phase':phase,'occupied':row['occupied'],'union_mismatch_count':len(mismatches),'missing_union_pixels':missing,'extra_union_pixels':extras,'proxy_only_discrepancies':proxy_only,
            'precision_discrepancies':precision,'multi_proxy_centres':multi,'graphs':graphs})
    complete=raw.get('ok')is True and not raw.get('errors')and receipt.get('ok')is True and receipt.get('exit')==0
    return {'complete':complete,'observations':summary,'native_union_mismatches':sum(r['union_mismatch_count']for r in summary)}

def analyze(output,summary_dir):
    output,summary_dir=Path(output).resolve(),Path(summary_dir).resolve();require(not summary_dir.exists(),'Fresh summary required')
    analysis_paths=[Path(__file__).resolve(),Path(__file__).with_name('analyze_gcr_authored.py').resolve()]
    analysis_inputs={p.relative_to(ROOT).as_posix():digest(p.read_bytes())for p in analysis_paths}
    identity=read(output/'identity.json');source=identity['source'];archive=archived(source)
    verify_source_map(identity['inputs'],source_scope(archive),'Complete project');require(digest(json.dumps(identity['inputs'],sort_keys=True).encode())==identity['inputs_hash'],'Input-map hash')
    protocol_bytes=git_file(source,PROTOCOL);require(protocol_bytes==git_file(FROZEN_PROTOCOL,PROTOCOL),'Preregistered protocol bytes')
    protocol=json.loads(protocol_bytes);require(protocol['registration']==REG and len(protocol['profiles'])==2 and len(protocol['cases'])==12,'Frozen registered population')
    require(digest(protocol_bytes)==identity['protocol_sha256'],'Protocol identity')
    require(identity['tree']==subprocess.check_output(['git','-C',str(ROOT),'rev-parse',source+'^{tree}'],text=True,timeout=60).strip(),'Source tree identity')
    old=json.loads(git_file(BASELINE,'godot/authoring/flyers/scooper.json'))
    current=json.loads(git_file(source,'godot/authoring/flyers/scooper.json'))
    require(git_file(source,'godot/tests/fixtures/gcr_scooper_stepped_350a.json')==git_file(BASELINE,'godot/authoring/flyers/scooper.json'),'Historical profile byte identity')
    require(git_file(source,'godot/authoring/flyers/scooper.json')==git_file(FROZEN_U,'godot/authoring/flyers/scooper.json'),'Registered U definition bytes')
    require({k:v for k,v in current.items()if k not in('hull','description')}=={k:v for k,v in old.items()if k not in('hull','description')},'Actor controls and mass unchanged')
    for name in('midge','needle','kestrel','afterglow','surveyor','cartographer','observatory'):
        path='godot/authoring/flyers/'+name+'.json';require(git_file(source,path)==git_file(BASELINE,path),'Existing flyer preserved '+name)
    completion=read(output/'completion.json')if(output/'completion.json').exists()else None
    watched={};manifest=[];summaries=[];rasters=[];traces=[];errors=[]
    def watch(p,kind):
        require(p.is_file(),'Missing evidence '+str(p));data=p.read_bytes();h=digest(data);watched[p]=h;manifest.append({'path':p.relative_to(output).as_posix(),'kind':kind,'bytes':len(data),'sha256':h});return h
    watch(output/'identity.json','source');
    if completion:watch(output/'completion.json','completion')
    for platform in('windows','linux'):
        folder=output/platform
        try:
            require(watch(folder/PROTOCOL,'protocol')==identity['protocol_sha256'],'Copied protocol hash');runtime=read(folder/'runtime.json');watch(folder/'runtime.json','runtime');project=folder/'godot'
            require(runtime['engine_version']=='4.7.stable.official.5b4e0cb0f','Pinned engine')
            for name,h in identity['inputs'].items():require(digest(bundle_path(project,name.removeprefix('godot/')).read_bytes().replace(b'\r\n',b'\n'))==h,'Copied source '+name)
            suffix=''if platform=='windows'else'.linux';native=read(project/f'addons/cybersand_native/runtime-provenance{suffix}.json')
            verify_source_map(native['source_inputs'],source_scope(archive,native=True),'Current native');verify_source_map(native['source_inputs'],source_scope(archived(native['source_commit']),native=True),'Compiled native')
            require(native['source_commit']==runtime['native_build_source']and native['source_inputs']==runtime['native_source_inputs'],'Compiled/source map identity')
            require(digest(bundle_path(project,native['artifact'].removeprefix('godot/')).read_bytes())==native['sha256']==runtime['native_sha256'],'Native artifact bytes')
            rapier=read(project/f'addons/godot-rapier2d/runtime-provenance.{platform}.json');require(digest(bundle_path(project,rapier['artifact'].removeprefix('godot/')).read_bytes())==rapier['sha256']==runtime['rapier_sha256'],'Rapier artifact bytes')
            gh=watch(folder/'gates.json','gates');gates=read(folder/'gates.json');names=[r['test']for r in gates]
            require(len(set(names))==len(names)and 'import'in names and 'test_gcr_scooper_u_capture'in names,'Required unique controls')
            for gate in gates:
                name=gate['test'];require(name=='import'or name.startswith('test_')and 'godot/tests/'+name+'.gd'in identity['inputs'],'Bounded source-backed test')
                require(gate['ok']is True and gate['exit']==0 and watch(bundle_path(folder,name+'.log'),'control log')==gate['log_sha256'],'Control pass/log binding')
            ch=watch(folder/'campaign.json','campaign');campaign=read(folder/'campaign.json')
            keys=[(r['profile'],r['case'])for r in campaign];expected_keys={(p['id'],s['id'])for p in protocol['profiles']for s in protocol['cases']}|{(p['id'],'raster')for p in protocol['profiles']}
            require(len(set(keys))==len(keys)and set(keys)<=expected_keys,'Unique registered campaign records')
            if completion:
                done=next(r for r in completion['results']if r['platform']==platform);require(done['gates_sha256']==gh and done['campaign_sha256']==ch,'Completion custody hashes')
            for profile in protocol['profiles']:
                definition_path='godot/'+profile['definition_path'].removeprefix('res://');definition_bytes=git_file(source,definition_path);definition=json.loads(definition_bytes)
                for spec in [None]+protocol['cases']:
                    mode='raster'if spec is None else'physical';case='raster'if spec is None else spec['id'];base=profile['id']+'-'+case
                    item={'platform':platform,'profile':profile['id'],'case':case,'mode':mode}
                    try:
                        receipt=next(r for r in campaign if r['profile']==profile['id']and r['case']==case)
                        require(watch(folder/(base+'.json'),'raw')==receipt['raw_sha256']and watch(folder/(base+'.log'),'capture log')==receipt['log_sha256'],'Original capture/log binding')
                        raw=read(folder/(base+'.json'));finite(raw);require(raw['registration']==REG and same(raw['profile'],profile)and raw['mode']==mode and same(raw['definition'],definition),'Exact profile definition')
                        for k,v in {'source':source,'inputs':identity['inputs_hash'],'protocol_sha256':identity['protocol_sha256'],'native_sha256':runtime['native_sha256'],'physics_backend':'Rapier2D'}.items():require(raw['identity'].get(k)==v,'Raw identity '+k)
                        require(digest(raw['definition_canonical'].encode())==raw['identity']['definition_hash']and same(json.loads(raw['definition_canonical']),definition),'Canonical content hash')
                        require(raw['identity']['definition_file_sha256']==digest((project/definition_path.removeprefix('godot/')).read_bytes()),'Definition file hash')
                        require(receipt['rows']==len(raw['rows']),'Receipt rows')
                        if mode=='raster':item.update(reduce_raster(raw,profile,protocol,receipt));rasters.append(item)
                        else:
                            require(same(raw['case'],spec),'Frozen motion case');value,trace=reduce_physical(raw,profile,spec,protocol,receipt);item.update(value);summaries.append(item);traces.append({'platform':platform,'profile':profile['id'],'case':case,'rows':trace})
                    except(EvidenceError,KeyError,TypeError,ValueError,OSError,StopIteration)as exc:
                        item.update(complete=False,mechanical_pass=False,error=str(exc));(rasters if mode=='raster'else summaries).append(item)
        except(EvidenceError,KeyError,TypeError,ValueError,OSError,StopIteration)as exc:errors.append({'platform':platform,'error':str(exc)})
    for p,h in watched.items():require(digest(p.read_bytes())==h,'Evidence mutated during reduction')
    for p in analysis_paths:require(digest(p.read_bytes())==analysis_inputs[p.relative_to(ROOT).as_posix()],'Analyzer code mutated during reduction')
    mechanical=len(summaries)==48 and all(r.get('mechanical_pass')for r in summaries)and not errors
    static_complete=len(rasters)==4 and all(r.get('complete')for r in rasters)
    custody=bool(completion and completion.get('ok')is True and completion.get('inputs_unchanged')is True and completion['source']==source)
    pairs=[]
    for platform in('windows','linux'):
        for spec in protocol['cases']:
            arms={r['profile']:r for r in summaries if r['platform']==platform and r['case']==spec['id']}
            pairs.append({'platform':platform,'case':spec['id'],'arms':{k:{field:v.get(field)for field in('complete','mechanical_pass','mass','area','com','inertia','proxy_count','motion','primary_cavity_min','core_cavity_min','phase_cavity_counts','sides','displaced_sum','max_overlap_post','owner_step_us')}for k,v in arms.items()}})
    result={'registration':REG,'source':source,'protocol_sha256':identity['protocol_sha256'],'analysis_sha256':analysis_inputs[Path(__file__).resolve().relative_to(ROOT).as_posix()],'analysis_inputs':analysis_inputs,'physical_complete':len(summaries)==48 and all(r.get('complete')for r in summaries),
        'mechanical_population_pass':mechanical,'static_population_complete':static_complete,'runner_custody_pass':custody,'integrity_errors':errors,'cases':summaries,'raster':rasters,
        'scope':['Coordinate sets and persistent far-side occupancy are not grain identities or continuous paths.','A graph proxy-ID seam is not itself a mask hole. Positive paths retain actual native mask evidence.','Open-side/rim exit and transient current/sample-pose hull overlap are reported separately.','Mass/motors unchanged; actual COM/area/inertia change with the authored geometry.','Passive body energy excludes material relocation, gravity, events, correction and motors. Whole owner timing excludes diagnostics.']}
    summary_dir.mkdir(parents=True)
    for name,value in [('machine-summary.json',result),('paired-summary.json',{'source':source,'pairs':pairs}),('raw-manifest.json',{'source':source,'files':manifest})]:
        (summary_dir/name).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n',encoding='utf-8',newline='\n')
    (summary_dir/'selected-traces.json').write_text(json.dumps({'source':source,'cases':traces},separators=(',',':'),allow_nan=False)+'\n',encoding='utf-8',newline='\n')
    return result

def self_test():
    require(not inside([0,2],[0,0,2,2])and inside([0,1],[0,0,2,2]),'Half-open cavity geometry')
    definition={'physics':{'mass':.18},'hull':{'rects':[[-15,0,33,4],[-15,-8,3,8],[15,-8,3,8],[-12,-3,2,3],[13,-3,2,3]]}}
    area,com,inertia,_,_=geometry(definition);require(area==192 and com==[1.5,.28125]and abs(inertia-24.79013671875)<1e-12,'Analytic area/COM/inertia')
    require(f32(-.1)!=-.1,'Exact controller float carrier')
    pose={'position':[512.25,250.75],'rotation':.7};p=[3.5,-2.75];require(same(local(pose,world(pose,p)),p,1e-12),'Independent frame inverse')
    packet=[1,20.,20.,0.,10.,2.,0,0,0,.18,1,10.,20.,20.,.8,1/60,977]
    require(packet_memberships(packet,[20,20])==[1]and not packet_memberships(packet,[20,22]),'Closed floor membership')
    refused=False
    try:verify_source_map({}, {'missing.gd':'hash'}, 'negative control')
    except EvidenceError:refused=True
    require(refused,'Partial source-map refusal')
    refused=False
    try:finite({'fake':float('nan')})
    except EvidenceError:refused=True
    require(refused,'Nonfinite observation refusal')
    pose={'position':[20,20],'rotation':0};bounds=[-5,-5,5,2];profile={'core':[-3,-5,6,5],'rim_y':-5,'left_index':1,'right_index':2};floor=[-5,0,10,2]
    mask={(x,y):1 for y in range(15,22)for x in range(15,25)if y>=20 or x<17 or x>=23}
    require(not graph_exits(mask,[10,10,20,20],pose,[0,0],bounds,profile,floor,True),'Sealed graph control')
    broken=dict(mask);del broken[20,20];del broken[20,21]
    require('bottom'in graph_exits(broken,[10,10,20,20],pose,[0,0],bounds,profile,floor,True),'Actual mask-hole graph control')
    complete={(x,y):broken.get((x,y),0)for y in range(10,30)for x in range(10,30)}
    path={'path':[[20,19],[20,20],[20,21],[20,22]],'open_side':False,'ambiguous_corner':False,'floor_span_covered_x':True}
    require(validate_graph_path('bottom',path,complete,[10,10,20,20],pose,[0,0],bounds,profile,floor,4)['open_side']is False,'Positive copied closed-floor path')
    bad=dict(path,open_side=True);refused=False
    try:validate_graph_path('bottom',bad,complete,[10,10,20,20],pose,[0,0],bounds,profile,floor,4)
    except EvidenceError:refused=True
    require(refused,'False open-side flag cannot hide a closed path')
    capped=[[20,15],[20,14],[21,14]]+[[21,y]for y in range(15,23)];corrupt_mask=dict(complete)
    for p in capped:corrupt_mask[tuple(p)]=0
    bad=dict(path,path=capped);refused=False
    try:validate_graph_path('bottom',bad,corrupt_mask,[10,10,20,20],pose,[0,0],bounds,profile,floor,4)
    except EvidenceError:refused=True
    require(refused,'A path over the virtual rim cannot be labelled a floor hole')
    print('GCR_U_ANALYZER_SELF_TEST 10 controls passed')

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--summary-dir',type=Path);parser.add_argument('--self-test',action='store_true');args=parser.parse_args()
    if args.self_test:self_test();return 0
    try:
        require(args.output and args.summary_dir,'Output and fresh summary required');result=analyze(args.output,args.summary_dir)
    except(EvidenceError,KeyError,TypeError,ValueError,OSError)as exc:print(json.dumps({'ok':False,'error':str(exc)}));return 2
    ok=result['mechanical_population_pass']and result['static_population_complete']and result['runner_custody_pass']
    print(json.dumps({'source':result['source'],'physical_complete':result['physical_complete'],'mechanical_pass':result['mechanical_population_pass'],'static_complete':result['static_population_complete'],'custody':result['runner_custody_pass'],'ok':ok}));return 0 if ok else 1

if __name__=='__main__':raise SystemExit(main())
