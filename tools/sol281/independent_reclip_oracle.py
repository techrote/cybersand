#!/usr/bin/env python3
"""Independent rational segment/square intersection oracle for actual native witnesses.
Uses edge-edge crossings and endpoint inclusion, not production parametric slab
clipping. JSON endpoints are exact decimal rationals; midpoint/length comparison
uses the recorded float32 coordinates and an explicit 5e-5-cell audit tolerance.
This tolerance validates an independently recomputed torque lever only; it does
not change any production acceptance or registered energy/CPU gate.
"""
from pathlib import Path
import argparse
from fractions import Fraction as Q
from math import hypot, fsum
from collections import Counter
import json, hashlib

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("input",type=Path,help="JSON from sol364_independent_reclip.gd")
parser.add_argument("--output",type=Path,required=True,help="Write the independently checked receipt")
args=parser.parse_args()
source=args.input
r=json.loads(source.read_text())

def v(p): return tuple(Q(str(x)) for x in p)
def add(a,b): return tuple(x+y for x,y in zip(a,b))
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def mul(a,s): return tuple(x*s for x in a)
def cross(a,b): return a[0]*b[1]-a[1]*b[0]
def inside(p,cell): return all(Q(c)<=q<=Q(c+1) for q,c in zip(p,cell))

def intersect(span):
    a,b=v(span['a']),v(span['b']); d=sub(b,a)
    x,y=span['cell']; corners=[(Q(x),Q(y)),(Q(x+1),Q(y)),(Q(x+1),Q(y+1)),(Q(x),Q(y+1))]
    candidates={}
    for t,p in [(Q(0),a),(Q(1),b)]:
        if inside(p,(x,y)): candidates[t]=p
    for e,f in zip(corners,corners[1:]+corners[:1]):
        edge=sub(f,e); den=cross(d,edge)
        if den:
            t=cross(sub(e,a),edge)/den; u=cross(sub(e,a),d)/den
            if 0<=t<=1 and 0<=u<=1: candidates[t]=add(a,mul(d,t))
        elif not cross(sub(e,a),d):
            axis=0 if d[0] else 1
            if not d[axis]: continue
            for p in (e,f):
                t=(p[axis]-a[axis])/d[axis]
                if 0<=t<=1: candidates[t]=p
    if len(candidates)<2:return None
    p=candidates[min(candidates)]; q=candidates[max(candidates)]
    length=hypot(*(float(z) for z in sub(q,p)))
    if length<=0:return None
    point=tuple(float((u+w)/2) for u,w in zip(p,q))
    return point,length

failures=list(r['failures'])
if r.get('schema')!='sol364.independent-reclip.v1': failures.append('wrong input schema')
if len(r.get('cases',[]))!=144: failures.append('expected exactly 144 declared cases')
fixture=r.get('fixture',{})
members=fixture.get('members',[]); rectangles=fixture.get('rectangles',[])
occupied={(members[i],members[i+1]) for i in range(0,len(members),6)}
covered=set(); duplicate=False
for i in range(0,len(rectangles),4):
    x,y,w,h=rectangles[i:i+4]
    for cy in range(y,y+h):
        for cx in range(x,x+w):
            duplicate|=(cx,cy) in covered; covered.add((cx,cy))
if len(occupied)!=520 or covered!=occupied or duplicate or len(rectangles)!=24:
    failures.append('six-shape exact 520-cell partition differs')
if any(tuple(cell) in covered for cell in fixture.get('empty_witness_cells',[])):
    failures.append('a declared interior empty witness is occupied')
if fixture.get('empty_witness_cells')!=[[60,32],[68,50]]:
    failures.append('both retained empty witnesses are required')
max_error=0.0; total_spans=0; valid_spans=0
old_midpoint_lost=0; cases_with_lost=0; case_checks=[]
for index,c in enumerate(r['cases']):
    active=[]; lost=0
    for span in c['spans']:
        total_spans+=1
        hit=intersect(span)
        if hit:
            active.append(hit); valid_spans+=1
            if not inside(v(span['old_point']),span['cell']): lost+=1
    old_midpoint_lost+=lost; cases_with_lost+=lost>0
    if c['accepted']:
        if c['contact_count']!=len(active):failures.append(f'case {index}: contact count {c["contact_count"]} != independent {len(active)}')
        if c['source_contact_count']!=len(c['spans']):failures.append(f'case {index}: source count mismatch')
        total=fsum(length for _,length in active)
        centroid=tuple(fsum((point[axis]-c['origin'][axis])*length for point,length in active)/total for axis in (0,1))
        if not c['impulses']:failures.append(f'case {index}: no impulse for approach')
        else:
            got=c['impulses'][0]['offset']; error=hypot(*(u-w for u,w in zip(got,centroid)))
            max_error=max(max_error,error)
            if error>5e-5:failures.append(f'case {index}: lever error {error}')
        if c['energy_after']>c['energy_before']+c['energy_tolerance']:failures.append(f'case {index}: energy increased')
    else: failures.append(f'case {index}: unexpected refusal {c["outcome"]}')
    case_checks.append({'index':index,'source_segments':len(c['spans']),'current_segments':len(active),'valid_segments_with_lost_old_midpoint':lost})
summary={'schema':'sol364.independent-reclip-oracle.v1','cases':len(r['cases']),'outcomes':dict(Counter(c['outcome'] for c in r['cases'])),
    'source_segments':total_spans,'retained_current_segments':valid_spans,
    'valid_segments_with_lost_old_midpoint':old_midpoint_lost,'cases_with_lost_old_midpoint':cases_with_lost,
    'maximum_first_impulse_lever_error_cells':max_error,'audit_lever_tolerance_cells':5e-5,
    'geometry_match':not failures,'failures':failures,
    'exact_520_cell_six_shape_partition':covered==occupied and len(occupied)==520 and not duplicate,
    'empty_witness_cells':fixture.get('empty_witness_cells',[]),
    'input_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'scope':'Independent rational current segment intersection, torque lever and dissipative value-plan review; frozen native inputs, not live Rapier/physical clearance acceptance.',
    'case_checks':case_checks}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='case_checks'},indent=2))
raise SystemExit(bool(failures))
