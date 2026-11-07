"""Analyze fixed post-cut representation observations; no acceptance threshold."""
import csv,json,math,re,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/workbench-cut-outcomes'
def points(raw):return {tuple(map(int,re.findall(r'-?\d+',k))):v for k,v in raw.items()}
def clip(poly,axis,bound,less):
 result=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  ia=a[axis]<=bound if less else a[axis]>=bound;ib=b[axis]<=bound if less else b[axis]>=bound
  if ia:result.append(a)
  if ia!=ib:
   t=(bound-a[axis])/(b[axis]-a[axis]);result.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
 return result
def area(poly):return abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(poly,poly[1:]+poly[:1])))*.5 if poly else 0.
def geometry(row,grid):
 body=row['final']['body']
 if body is None:return dict(sand_area=None,sand_depth=None,hard_area=None,geometry_complete=None)
 a,b,c,d,x,y=body['pose'];w,h=row['core_rect'][2:];quad=[(a*px+c*py+x,b*px+d*py+y) for px,py in [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)]]
 complete=all(0<=qx<=128 and 0<=qy<=128 for qx,qy in quad)
 axes=[(1,0),(0,1),(a/math.hypot(a,b),b/math.hypot(a,b)),(c/math.hypot(c,d),d/math.hypot(c,d))]
 sa=ha=depth=0.
 for (cx,cy),mat in grid.items():
  if mat not in [2,43,58]:continue
  poly=quad
  for axis,bound,less in [(0,cx,False),(0,cx+1,True),(1,cy,False),(1,cy+1,True)]:poly=clip(poly,axis,bound,less)
  overlap=area(poly)
  if mat==2:
   sa+=overlap
   if overlap>1e-12:
    cell=[(cx,cy),(cx+1,cy),(cx+1,cy+1),(cx,cy+1)];ds=[]
    for ax,ay in axes:
     q=[qx*ax+qy*ay for qx,qy in quad];z=[qx*ax+qy*ay for qx,qy in cell];ds.append(min(max(q)-min(z),max(z)-min(q)))
    depth=max(depth,min(ds))
  else:ha+=overlap
 return dict(sand_area=sa if complete else None,sand_depth=depth if complete else None,hard_area=ha if complete else None,geometry_complete=complete)
def stat(values):return dict(median=statistics.median(values),minimum=min(values),maximum=max(values))
allrows=[];inputs=[]
for host in ['windows-w1','linux-w1','windows-w4']:
 file=OUT/'outcomes-001'/host/'outcomes.json'
 if not file.exists():continue
 data=json.loads(file.read_text());assert not data['failures'];inputs.append(dict(host=host,checks=data['checks'],episodes=len(data['evidence']['cuts'])))
 for row in data['evidence']['cuts']:
  grid=points(row['final_map']);initial=points(row['initial_map']);body=row['final']['body'];trace=row['trace'];tail=trace[-30:]
  material={str(m):sum(v==m for v in grid.values()) for m in set(grid.values())}
  sand=[p for p,m in grid.items() if m==2];water=[p for p,m in grid.items() if m==3]
  metric=dict(host=host,key=row['key'],arm=row['arm'],repeat=row['repeat'],source_cells=row['source_cells'],rigid_cells=row['rigid_cells'],converted_sand=row['converted_sand'],discarded=row['discarded'],native_steps=row['final']['tick'],material_counts=material,
   sand_count=len(sand),sand_centroid_y=sum(p[1]+.5 for p in sand)/len(sand) if sand else None,water_count=len(water),
   native_mean_ms=statistics.mean(v['native_ms'] for v in trace),native_max_ms=max(v['native_ms'] for v in trace),owner_mean_ms=statistics.mean(v['owner_ms'] for v in trace),
   pose=None if body is None else body['pose'],tail_speed=None if body is None else statistics.mean(math.hypot(*v['body']['velocity']) for v in tail),tail_abs_omega=None if body is None else statistics.mean(abs(v['body']['omega']) for v in tail),
   rigid_kinetic_proxy=None if body is None else body['kinetic_proxy'],rigid_potential_change=None if body is None else body['potential_proxy']-row['initial']['body']['potential_proxy'],
   accepted_steps=None if body is None else sum(v['body']['application'].get('accepted',False) for v in trace),latest_native_arrivals_unaligned=None if body is None else sum(n.get('arrival_count',0) for v in trace for n in v['body']['native_rows']))
  metric.update(geometry(row,grid));allrows.append(metric)
summary=[]
for host in sorted({r['host'] for r in allrows}):
 for key in sorted({r['key'] for r in allrows if r['host']==host}):
  for arm in ['core_sand','all_sand','core_only']:
   a=[r for r in allrows if r['host']==host and r['key']==key and r['arm']==arm];assert len(a)==(5 if host=='windows-w1' else 1)
   summary.append(dict(host=host,key=key,arm=arm,repeats=len(a),**{k:None if a[0][k] is None else stat([r[k] for r in a]) for k in ['native_mean_ms','owner_mean_ms','sand_count','sand_centroid_y','tail_speed','tail_abs_omega','sand_area','sand_depth','hard_area','rigid_kinetic_proxy','rigid_potential_change','accepted_steps','latest_native_arrivals_unaligned']}))
(OUT/'analysis.json').write_text(json.dumps(dict(inputs=inputs,episodes=allrows,cells=summary,scope='120 fixed1/60 steps; native128-square census; SAT depth and polygon/cell intersection independent of solver; energy is rigid proxy only'),indent=2)+'\n')
for r in summary:
 if r['host']=='windows-w1':print(r['key'],r['arm'],'tail',None if r['tail_speed'] is None else round(r['tail_speed']['median'],4),'overlap',None if r['sand_area'] is None else round(r['sand_area']['median'],4),'native_ms',round(r['native_mean_ms']['median'],4),'sand',r['sand_count']['median'])
print('EPISODES',len(allrows),'CELLS',len(summary))
