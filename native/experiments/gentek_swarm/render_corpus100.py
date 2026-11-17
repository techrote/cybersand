#!/usr/bin/env python3
"""Exact native-cell evidence views; no generation, retuning or aesthetic scores."""
from pathlib import Path
import argparse, json, hashlib, csv, html, sys, struct
from collections import Counter,deque
from datetime import datetime,timezone
from PIL import Image,ImageDraw

def digest_file(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--evidence',type=Path,required=True);a=ap.parse_args()
 root=a.repo.resolve();out=a.evidence.resolve()
 sys.dont_write_bytecode=True
 sys.path.insert(0,str(root/'native/experiments/gentek_swarm'))
 import gallery as g
 reg=json.loads((out/'registration.json').read_text());run=json.loads((out/'manifest.json').read_text())
 if run['native_raw_count']!=100:raise RuntimeError('All100 native outcomes must be retained before review rendering')
 for folder in ['images','case_records','material_arrays','contact_sheets']:(out/folder).mkdir(exist_ok=True)
 records=[];cards=[];tiles={};raws={}
 def save_image(im,name):
  p=out/'images'/name;im.save(p);return p.relative_to(out).as_posix()
 def arr(cells,name):
  p=out/'material_arrays'/name;p.write_bytes(struct.pack('<'+'H'*len(cells),*cells));return {'file':p.relative_to(out).as_posix(),'sha256':digest_file(p),'format':'uint16 little-endian row-major material IDs','retained_cell_count':len(cells),'complete_192x112_canvas':len(cells)==192*112,'empty_emission_preserved':len(cells)==0}
 def comp(cells,w,h):
  seen=bytearray(len(cells));n=0
  for i,m in enumerate(cells):
   if not m or seen[i]:continue
   n+=1;seen[i]=1;q=[i]
   for j in q:
    x,y=j%w,j//w
    for k in ([j-1] if x else [])+([j+1] if x+1<w else [])+([j-w] if y else [])+([j+w] if y+1<h else []):
     if cells[k] and not seen[k]:seen[k]=1;q.append(k)
  return n
 for c in reg['cases']:
  cid=c['case_id'];raw=out/'native'/(cid+'.json');d=json.loads(raw.read_text());raws[cid]=d
  pair=d['type']=='pair';q=d['left_request'] if pair else d['request'];rs=[d['left'],d['right']] if pair else [d['result']]
  qs=[d['left_request'],d['right_request']] if pair else [q]
  w,h=q['width'],q['height'];cells=d['cells'] if pair else rs[0]['cells'];n=w*h
  profile_label=c['profile']
  if 'environment_affinity' in c.get('overrides',{}):profile_label+=f" | affinity={c['overrides']['environment_affinity']:g}"
  has_native_array=len(cells)==n
  im=g.raster(cells,q)
  if not has_native_array:
   draw=ImageDraw.Draw(im);draw.rectangle((0,0,w-1,h-1),fill=g.BG);draw.multiline_text((6,25),'NO MATERIAL ARRAY\ncapacity refusal',font=g.font(15),fill=(255,166,127),spacing=10)
  native=save_image(im,cid+'-native.png')
  generated=[0]*n;shared=[0]*n;sem=Image.new('RGB',(w,h),g.BG);pix=sem.load();adapters=[0]*n;cohesion=[0]*n;late_cohesion=[0]*n;late_additions=[0]*n
  for i,m in enumerate(q['context']):
   if m:pix[i%w,i//w]=(67,72,80)
  owner_details=[]
  for j,(r,rq) in enumerate(zip(rs,qs)):
   instances={p['id']:p for p in r['instances']};base=g.KIND[r['gentek']]
   old=(d['initial_left'] if j==0 else d['initial_right'])['cells'] if pair else r['cells']
   for i,m in enumerate(r['cells']):
    if not m:continue
    generated[i]=m;inst=instances.get(r['provenance'][i],{});isbridge=inst.get('kind')=='typed-seam-joint'
    islate=pair and (not old or old[i]==0)
    isadapter=islate and not isbridge
    if islate:late_additions[i]=m
    if islate and r['roles'][i]==4:late_cohesion[i]=m
    if isbridge:shared[i]=m;color=(81,221,191)
    elif r['roles'][i]==4:cohesion[i]=m;color=(222,111,190)
    elif isadapter:adapters[i]=m;color=(195,145,255)
    else:
     shift=r['provenance'][i]*17%37-18;color=tuple(max(0,min(255,z+shift)) for z in base)
    pix[i%w,i//w]=color
   owner_details.append({'gentek':r['gentek'],'generation_status':r['status'],'termination':r['termination'],'material_digest':r['material_digest'],'semantic_result_digest':r['digest'],'request_digest':r['request_digest'],'compiled_definition_fingerprint':r['definition'],'instance_count':len(r['instances']),'occupied_cells':sum(bool(m) for m in r['cells']),'component_count':r['metrics'].get('connected_material_components'),'hard_affordances':len(r['boundary']['hard']),'mandatory_affordances':sum(x['required'] for x in r['boundary']['hard']),'optional_affordances':sum(not x['required'] for x in r['boundary']['hard']),'mandatory_connectors':sum(x['required'] for x in r['connectors']),'mandatory_fulfilled':sum(x['required'] and x['fulfilled'] for x in r['connectors']),'mandatory_unresolved':r['unresolved_joints'],'optional_connectors':sum(not x['required'] for x in r['connectors']),'optional_connectors_fulfilled':sum(not x['required'] and x['fulfilled'] for x in r['connectors']),'cohesion_cells':r['metrics'].get('cohesion_cells',0),'solver_attempted':bool(r['metrics'].get('solver_attempted')),'solver_status':('complete' if r['metrics'].get('solver_work_observed') else r['status'] if r['status'] in ('unsat','exhausted') else 'unknown') if r['metrics'].get('solver_attempted') else ('not_attempted' if r['gentek']=='MOSAIC' else 'not_applicable'),'solver_work':r['solver_work'] if r['metrics'].get('solver_attempted') else None,'solver_work_observed':bool(r['metrics'].get('solver_work_observed')),'solver_work_upper_bound':r['metrics'].get('solver_work_upper_bound'),'backtracks':None if r['backtracks']==-1 else r['backtracks'],'work':r['work'],'protected_space_violations':r['protected_violations'],'illegal_overlaps':r['illegal_overlaps'],'rejection_reasons':r['rejected'],'notes':r['notes']})
  if not has_native_array:
   sem=im.copy()
  semantic=save_image(sem,cid+'-semantic.png')
  trans=g.overlays(g.raster(cells,q,mode='transition'),qs,rs,d.get('seams',[]))
  boundary=save_image(trans,cid+'-boundary.png')
  binary=arr(cells,cid+'-native.u16le')
  binary['emission_status']='native full-size array' if has_native_array else 'no native array; zero-length refusal artifact, not a blank canvas'
  layer_arrays={'generated_union':arr(generated if has_native_array else [],cid+'-generated-union.u16le'),'cohesion_cells':arr(cohesion if has_native_array else [],cid+'-cohesion.u16le')}
  details=g.row([g.panel(im,'Native material cells' if has_native_array else 'NO MATERIAL ARRAY — capacity refusal',f'{cid} | fixed 192x112 | actual native palette' if has_native_array else 'Native output has no cells; image is a labelled refusal placeholder'),g.panel(sem,'Attribution by cells','Cyan shared bridge; violet adapter; magenta cohesion'),g.panel(trans,'Boundary and seam receipts','Cyan paths; red mandatory; yellow optional; hatch protected')],cid+' | '+c['kind']+(' x '+c['right_kind'] if pair else ''),f"{c['fixture']} | {profile_label} | seed {c['seed']} | status "+'/'.join(x['status'] for x in rs))
  detail=save_image(details,cid+'-detail.png')
  controls=None;control_arrays={}
  if pair:
   comparison=g.pair_images(d)[0];controls=save_image(comparison,cid+'-controls.png')
   for key in ['clipped_cells','initial_cells']:
    control_arrays[key]=arr(d[key],cid+'-'+key+'.u16le')
   control_arrays['shared_bridge_cells']=arr(shared,cid+'-shared-bridges.u16le')
   control_arrays['late_adapter_cells_excluding_cohesion']=arr(adapters,cid+'-late-adapters-excluding-cohesion.u16le')
   control_arrays['late_cohesion_cells']=arr(late_cohesion,cid+'-late-cohesion.u16le')
   control_arrays['total_late_additions']=arr(late_additions,cid+'-all-late-additions.u16le')
   control_arrays['native_architecture_without_shared_bridges']=arr([m if not shared[i] else 0 for i,m in enumerate(generated)],cid+'-native-without-shared-bridges.u16le')
   save_image(g.raster(shared,{**q,'context':[0]*n}),cid+'-shared-bridges.png')
  offers=[r['boundary']['hard'] for r in rs]
  joined=[s for s in d.get('seams',[]) if s['joined']]
  optional_joints=0;mandatory_joints=0
  if pair:
   aoffers={x['id']:x for x in offers[0]};boffers={x['id']:x for x in offers[1]}
   for s in joined:
    required=aoffers[s['left_affordance']]['required'] or boffers[s['right_affordance']]['required']
    mandatory_joints+=required;optional_joints+=not required
  flags=[];statuses=[r['status'] for r in rs]
  if 'unsat' in statuses:flags.append('MOSAIC UNSAT')
  if 'exhausted' in statuses:flags.append('bounded exhaustion')
  if any(r['unresolved_joints'] for r in rs):flags.append('mandatory-resolution failure')
  if any(r['gentek']=='RECEPTOR' and r['metrics'].get('connected_material_components',0)>1 for r in rs):flags.append('disconnected RECEPTOR output')
  if 'damaged' in statuses:flags.append('damaged derivative')
  if c['group']=='pathological':flags.append('useful negative case')
  total_generated=sum(bool(x) for x in generated)
  if pair:
   if sum(bool(x) for x in shared)!=d['bridge_cells']:raise RuntimeError(f'{cid}: native bridge count disagrees with per-cell provenance')
   if sum(bool(x) for x in late_additions)!=sum(bool(x) for x in shared)+sum(bool(x) for x in adapters)+sum(bool(x) for x in late_cohesion):raise RuntimeError(f'{cid}: late-cell attribution partition does not close')
  if sum(bool(x) for x in cohesion)!=sum(x['cohesion_cells'] for x in owner_details):raise RuntimeError(f'{cid}: native cohesion count disagrees with per-cell roles')
  rec={**c,'source_head':run['source_commit'],'exact_parent':run['exact_parent'],'compiled_definition_fingerprint':run['compiled_definition_fingerprint'],'registered_manifest_sha256':run['registration_sha256'],'raw_native_json':raw.relative_to(out).as_posix(),'raw_sha256':digest_file(raw),'native_material_array':binary,'native_material_array_emitted':has_native_array,'native_image_is_refusal_placeholder':not has_native_array,'native_array_includes_immutable_context':pair,'native_png_includes_immutable_context':has_native_array,'final_material_array_sha256':binary['sha256'],'attribution_arrays':layer_arrays,'material_digest':rs[0]['material_digest'] if not pair else None,'pair_semantic_digest':d.get('digest') if pair else None,'per_owner_digests':[{'gentek':x['gentek'],'material':x['material_digest'],'semantic':x['semantic_result_digest']} for x in owner_details],'images':{'native_material_png':native,'semantic_provenance_overlay':semantic,'transition_boundary_overlay':boundary,'detail':detail,'independent_own_negotiated_comparison':controls},'instance_count':sum(len(r['instances']) for r in rs),'occupied_generated_cells':total_generated,'occupied_including_context':sum(bool(cells[i] or q['context'][i]) for i in range(n)) if has_native_array else None,'component_count_generated_union':comp(generated,w,h) if has_native_array else None,'component_count_is_descriptive_only':True,'mandatory_connectors':sum(x['mandatory_connectors'] for x in owner_details),'mandatory_fulfilled':sum(x['mandatory_fulfilled'] for x in owner_details),'mandatory_unresolved':sum(x['mandatory_unresolved'] for x in owner_details),'optional_affordances':sum(x['optional_affordances'] for x in owner_details),'optional_connectors_fulfilled':sum(x['optional_connectors_fulfilled'] for x in owner_details),'validated_joints':len(joined),'validated_optional_only_joints':optional_joints,'validated_joints_involving_mandatory':mandatory_joints,'bridge_count':d.get('bridges',0),'adjacent_typed_contacts_zero_new_cells':d.get('typed_contacts',0),'late_shared_bridge_cells':d.get('bridge_cells',0),'late_adapter_cells_excluding_cohesion':sum(bool(x) for x in adapters),'late_cohesion_cells':sum(bool(x) for x in late_cohesion),'total_late_additions':sum(bool(x) for x in late_additions),'shared_bridge_cells_recomputed_from_provenance':sum(bool(x) for x in shared),'cohesion_cells':sum(x['cohesion_cells'] for x in owner_details),'shared_geometry_provenance':'typed-seam-joint instance footprints; separate raw material array and cyan semantic pixels','native_architecture_vs_shared_geometry_separate':True,'generation_statuses':statuses,'solver_statuses':[x['solver_status'] for x in owner_details],'solver_work':[x['solver_work'] for x in owner_details],'unsat_means_proven_infeasible':True,'exhaustion_satisfiability_unknown':True,'protected_space_violations':d.get('protected_violations',0)+sum(x['protected_space_violations'] for x in owner_details),'illegal_overlaps':d.get('conflicts',0)+sum(x['illegal_overlaps'] for x in owner_details),'unresolved_seams':d.get('unresolved_seams',0),'seam_receipts':d.get('seams',[]),'control_arrays':control_arrays,'owners':owner_details,'descriptive_evidence_flags':flags,'late_cell_accounting_partition':'total_late_additions = late_adapter_cells_excluding_cohesion + late_cohesion_cells + shared_bridge_cells_recomputed_from_provenance','review_labels':[],'review_note':'Pending post-generation visual review; flags above are descriptive facts.'}
  (out/'case_records'/(cid+'.json')).write_text(json.dumps(rec,indent=2)+'\n');records.append(rec)
  tile=Image.new('RGB',(412,312),g.BG);draw=ImageDraw.Draw(tile);draw.text((8,4),cid+' | '+c['kind'][0]+(' × '+c['right_kind'][0] if pair else ''),font=g.font(16),fill=g.FG);draw.text((8,27),c['fixture']+' | seed '+str(c['seed']),font=g.font(13),fill=g.MUTED);draw.text((8,47),profile_label,font=g.font(13),fill=g.MUTED)
  tile.paste(im.resize((384,224),Image.Resampling.NEAREST),(8,68));draw.text((8,294),'/'.join(statuses)+f" | joints {len(joined)} | unresolved {rec['mandatory_unresolved']}",font=g.font(11),fill=g.FG);tiles[cid]=tile
  label=cid+' | '+c['kind']+(' x '+c['right_kind'] if pair else '')+' | '+c['fixture']+' | '+profile_label+' | seed '+str(c['seed'])
  cards.append(f'<section data-filter="{html.escape((label+" "+" ".join(flags)).lower())}"><h2>{html.escape(label)}</h2><p>{html.escape(" / ".join(statuses))} · {total_generated} generated cells · {rec["mandatory_unresolved"]} unresolved mandatory · {len(joined)} validated joints · {rec["late_shared_bridge_cells"]} shared bridge cells</p><p><a href="{rec["raw_native_json"]}">Raw native arrays and exact receipts</a> · <a href="case_records/{cid}.json">Case facts</a> · <a href="{binary["file"]}">uint16 material array</a></p>'+ (f'<img loading="lazy" src="{controls}" alt="Three native controls">' if controls else '')+f'<img loading="lazy" src="{detail}" alt="Material, provenance and boundary views"></section>')
 for group in reg['counts']:
  selected=[r for r in records if r['group']==group]
  for k in range(0,len(selected),12):
   subset=selected[k:k+12];cols=3;rows=(len(subset)+cols-1)//cols;sheet=Image.new('RGB',(cols*412,rows*312+54),g.BG);dr=ImageDraw.Draw(sheet);dr.text((10,8),group.replace('_',' ').upper()+f' | {k+1}-{k+len(subset)} of {len(selected)}',font=g.font(20),fill=g.FG);dr.text((10,32),'F = FRAMEWEAVER | M = MOSAIC | R = RECEPTOR | all registered outcomes retained | native palette | no simulation',font=g.font(13),fill=g.MUTED)
   for j,r in enumerate(subset):sheet.paste(tiles[r['case_id']],(j%cols*412,j//cols*312+54))
   sheet.save(out/'contact_sheets'/f'{group}-{k//12+1}.png')
 totals={}
 for group in reg['counts']:
  rr=[r for r in records if r['group']==group]
  totals[group]={'cases':len(rr),'generation_statuses':dict(Counter('/'.join(r['generation_statuses']) for r in rr)),'with_new_bridges':sum(r['bridge_count']>0 for r in rr),'bridges':sum(r['bridge_count'] for r in rr),'adjacent_contacts':sum(r['adjacent_typed_contacts_zero_new_cells'] for r in rr),'shared_bridge_cells':sum(r['late_shared_bridge_cells'] for r in rr),'late_adapter_cells_excluding_cohesion':sum(r['late_adapter_cells_excluding_cohesion'] for r in rr),'late_cohesion_cells':sum(r['late_cohesion_cells'] for r in rr),'total_late_additions':sum(r['total_late_additions'] for r in rr),'mandatory_unresolved':sum(r['mandatory_unresolved'] for r in rr),'protected_violations':sum(r['protected_space_violations'] for r in rr),'illegal_overlaps':sum(r['illegal_overlaps'] for r in rr)}
 summary={'programme':reg['programme'],'source_head':run['source_commit'],'generated_utc':datetime.now(timezone.utc).isoformat(),'count':len(records),'groups':totals,'renderer_sha256':digest_file(Path(__file__)),'palette_sha256':digest_file(root/'native/include/cybersand/material.hpp'),'case_records':[f'case_records/{r["case_id"]}.json' for r in records]}
 (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
 (out/'case-index.json').write_text(json.dumps(records,indent=2)+'\n')
 fields=['case_id','group','kind','right_kind','fixture','profile','seed','instance_count','occupied_generated_cells','component_count_generated_union','mandatory_connectors','mandatory_fulfilled','mandatory_unresolved','optional_affordances','validated_joints','validated_optional_only_joints','bridge_count','adjacent_typed_contacts_zero_new_cells','late_shared_bridge_cells','shared_bridge_cells_recomputed_from_provenance','late_adapter_cells_excluding_cohesion','late_cohesion_cells','total_late_additions','cohesion_cells','unresolved_seams','protected_space_violations','illegal_overlaps']
 with (out/'metrics.csv').open('w',newline='') as f:
  writer=csv.DictWriter(f,fields);writer.writeheader();writer.writerows({k:r[k] for k in fields} for r in records)
 document='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CORPUS-100 native evidence</title><style>body{margin:32px auto;max-width:1920px;padding:0 20px;background:#0d1219;color:#dfe6ef;font:16px/1.55 system-ui}a{color:#51ddbf}p{color:#a5b5c8}section{border-top:1px solid #364454;padding:20px 0}img{display:block;max-width:100%;height:auto}input{padding:14px;width:90%;max-width:900px;background:#203042;color:white;border:1px solid #597387;font:inherit;position:sticky;top:12px}h2{font-size:20px}</style><h1>CORPUS-100 · all registered native outcomes</h1><p>Draft / HOLD. Exact native192×112 material cells. No physical support, traversal, Windows or Workbench acceptance is claimed. Cyan cells = shared typed bridges; violet = late local adapter additions excluding cohesion; magenta = cohesion (initial or late). Raw facts separately count late cohesion, shared bridges and total late additions. Native owner provenance is blue / ochre / green. Context is grey in semantic images. Component counts are descriptive.</p><p>Pair controls: independent generation/clipping, own-territory generation, then SWARM-001 bounded late adaptation/meshing. This is not SWARM-002 pre-solve negotiation. Failed solver work is unavailable, not zero. Empty arrays on capacity refusal remain zero-length raw/binary artifacts; their images visibly say NO MATERIAL ARRAY and are labelled refusal placeholders, not accepted blank canvases.</p><p><a href="registration.json">Immutable registration</a> · <a href="manifest.json">Execution/source manifest</a> · <a href="summary.json">Summary</a> · <a href="metrics.csv">Measured facts</a> · <a href="benchmark-manifest.json">Benchmarks after review</a> · <a href="CORPUS-100-REPORT.md">Review and gate report</a></p><input id="filter" placeholder="Filter case ID, Gentek, fixture, profile, failure…" aria-label="Filter100 cases">'''+''.join(cards)+'''<script>document.getElementById('filter').oninput=e=>{const t=e.target.value.toLowerCase().split(/\\s+/).filter(Boolean);document.querySelectorAll('section').forEach(s=>s.hidden=!t.every(x=>s.dataset.filter.includes(x)));};</script></html>'''
 (out/'index.html').write_text(document)
 print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
