#!/usr/bin/env python3
"""Independently reduce source-bound native architectural experiments.

This reads retained native material planes and acknowledgements. It performs no
inference or simulation, gives no aesthetic score, and never promotes a design
card, queued edit or missing readback into completed native construction.
"""
from __future__ import annotations
import argparse
import base64
from collections import Counter, deque
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
from typing import Any

from evaluate import checked_readback, _neighbors, _components, _route

SCHEMA = 'cybersand.architectural-native-experiment.v1'
MAX_CELLS = 512 * 512
MAX_CASES = 512
ARMS = ('hand_typed','procedural_modules','random_valid','reference_guided','retrieval_guided')


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _int(v: Any, label: str, lo: int, hi: int) -> int:
    if type(v) is not int or not lo <= v <= hi:
        raise ValueError(f'{label} must be an integer in {lo}..{hi}')
    return v


def _rect(v: Any, width: int, height: int) -> tuple[int,int,int,int]:
    if not isinstance(v,list) or len(v)!=4: raise ValueError('Context rectangle must contain x,y,width,height')
    x=_int(v[0],'rectangle x',0,width-1); y=_int(v[1],'rectangle y',0,height-1)
    w=_int(v[2],'rectangle width',1,width); h=_int(v[3],'rectangle height',1,height)
    if x+w>width or y+h>height: raise ValueError('Context rectangle exceeds native extent')
    return x,y,w,h


def _mask(rectangles: Any, width: int, height: int) -> set[int]:
    if not isinstance(rectangles,list) or len(rectangles)>256: raise ValueError('Context rectangles missing or oversized')
    cells=set()
    for v in rectangles:
        x,y,w,h=_rect(v,width,height)
        cells.update(yy*width+xx for yy in range(y,y+h) for xx in range(x,x+w))
    return cells


def _materials(values: Any, label: str) -> set[int]:
    if not isinstance(values,list) or not values or len(values)>256: raise ValueError(f'{label} must be a bounded nonempty material list')
    return {_int(x,label,1,65535) for x in values}


def contextual_metrics(extent: list[int], before: list[int], after: list[int], context: dict) -> dict:
    """No density-as-quality score: publish independent, falsifiable diagnostics."""
    if not isinstance(extent,list) or len(extent)!=2: raise ValueError('Expected bounded native extent')
    width=_int(extent[0],'width',1,512); height=_int(extent[1],'height',1,512)
    count=width*height
    if len(before)!=count or len(after)!=count: raise ValueError('Native plane extent mismatch')
    if not isinstance(context,dict): raise ValueError('Context must be declared before execution')
    structure_ids=_materials(context.get('structural_materials'),'structural materials')
    detail_ids=_materials(context.get('detail_materials'),'detail materials')
    if structure_ids & detail_ids: raise ValueError('Structure and detail material roles must be disjoint for this metric')
    anchors=_mask(context.get('anchor_rects',[]),width,height)
    clearances=_mask(context.get('clearance_rects',[]),width,height)
    protected=_mask(context.get('protection_rects',[]),width,height)
    structure={i for i,m in enumerate(after) if m in structure_ids}
    details={i for i,m in enumerate(after) if m in detail_ids}
    new_detail={i for i in details if before[i]!=after[i]}
    changed={i for i,(a,b) in enumerate(zip(before,after)) if a!=b}
    actual_anchors=anchors & structure
    components=[]
    remaining=set(details)
    all_host_contact_cells=set(); all_anchor_contact_cells=set()
    while remaining:
        start=remaining.pop(); component={start}; queue=[start]
        host_contacts=set(); anchor_contacts=set()
        for i in queue:
            for n in _neighbors(i,width,count):
                if n in remaining:
                    remaining.remove(n); component.add(n); queue.append(n)
                if n in structure: host_contacts.add(i)
                if n in actual_anchors: anchor_contacts.add(i)
        all_host_contact_cells.update(host_contacts); all_anchor_contact_cells.update(anchor_contacts)
        xs=[i%width for i in component]; ys=[i//width for i in component]
        components.append({'cells':len(component),'new_cells':len(component & new_detail),
                           'host_face_contacts':len(host_contacts),'declared_anchor_contacts':len(anchor_contacts),
                           'attached_to_host':bool(host_contacts),'attached_to_declared_anchor':bool(anchor_contacts),
                           'bounds':[min(xs),min(ys),max(xs)-min(xs)+1,max(ys)-min(ys)+1]})
    zones=context.get('detail_zones',[])
    if not isinstance(zones,list) or len(zones)>128: raise ValueError('Detail zones must be a bounded list')
    zone_union=set(); zone_results=[]
    for index,z in enumerate(zones):
        if not isinstance(z,dict): raise ValueError('Detail zone must be an object')
        cells=_mask([z.get('rect')],width,height); zone_union |= cells
        lower=z.get('minimum_fraction',0); upper=z.get('maximum_fraction',1)
        if isinstance(lower,bool) or isinstance(upper,bool) or not isinstance(lower,(int,float)) or not isinstance(upper,(int,float)) or not math.isfinite(lower) or not math.isfinite(upper) or not 0<=lower<=upper<=1:
            raise ValueError('Detail zone density envelope is invalid')
        amount=len(details & cells); fraction=amount/len(cells)
        zone_results.append({'id':str(z.get('id',index)),'rect':z['rect'],'detail_cells':amount,'fraction':fraction,
                             'minimum_fraction':lower,'maximum_fraction':upper,'within_envelope':lower<=fraction<=upper})
    route=context.get('route')
    clearance=None
    if route is not None:
        if not isinstance(route,list) or len(route)!=2: raise ValueError('Route requires two native local endpoints')
        for point in route:
            if not isinstance(point,list) or len(point)!=2: raise ValueError('Route endpoint malformed')
            _int(point[0],'route x',0,width-1); _int(point[1],'route y',0,height-1)
        radius=_int(context.get('clearance_radius',2),'clearance radius',0,16)
        clearance={'connected':_route(after,width,height,route,radius),'square_width':radius*2+1,
                   'claim_limit':'Geometric full-square clearance, not gravity-aware or actual actor traversal'}
    outside_zones=len(details-zone_union) if zones else None
    unattached=[x for x in components if not x['attached_to_host']]
    unanchored=[x for x in components if not x['attached_to_declared_anchor']]
    existing_intrusions=sum(before[i]!=0 for i in clearances)
    final_intrusions=sum(after[i]!=0 for i in clearances)
    new_intrusions=sum(before[i]==0 and after[i]!=0 for i in clearances)
    protected_changed=len(changed & protected)
    # Empty detail and undeclared intent have no suitability verdict, not a free pass.
    assessable=bool(details) and bool(anchors) and bool(zones) and bool(clearances)
    contextual_pass=(not unanchored and outside_zones==0 and all(x['within_envelope'] for x in zone_results)
                     and new_intrusions==0 and protected_changed==0 and (clearance is None or clearance['connected'])) if assessable else None
    sizes=_components(structure,width,count)
    return {'changed_cells':len(changed),'empty_fraction':after.count(0)/count,
            'structural_cells':len(structure),'structural_components':len(sizes),
            'largest_structural_component_fraction':sizes[0]/len(structure) if sizes else None,
            'detail_cells':len(details),'new_detail_cells':len(new_detail),'detail_components':len(components),
            'host_face_contact_cells':len(all_host_contact_cells),'declared_anchor_contact_cells':len(all_anchor_contact_cells),
            'declared_anchor_structural_cells':len(actual_anchors),'detached_detail_components':len(unattached),
            'detached_detail_cells':sum(x['cells'] for x in unattached),'unanchored_detail_components':len(unanchored),
            'unanchored_detail_cells':sum(x['cells'] for x in unanchored),'detail_outside_declared_zones':outside_zones,
            'detail_zone_envelopes':zone_results,'detail_component_receipts':components,
            'clearance_initial_occupied_cells':existing_intrusions,'clearance_final_occupied_cells':final_intrusions,
            'new_clearance_intrusion_cells':new_intrusions,'protected_changed_cells':protected_changed,
            'geometric_route':clearance,'context_assessable':assessable,'contextual_detail_checks_pass':contextual_pass,
            'scope':'Exact retained native material geometry. Attachment is face adjacency to declared actual host material; no stress, simulated pipe flow, aesthetic, human preference, model quality or actor-traversal conclusion.'}


def _plane_record(record: Any, root: Path, count: int) -> tuple[str,str]:
    if not isinstance(record,dict) or record.get('encoding','u16le')!='u16le': raise ValueError('Expected uint16 little-endian plane record')
    if 'base64' in record:
        if not isinstance(record['base64'],str) or len(record['base64'])>((MAX_CELLS*2+2)//3)*4: raise ValueError('Plane payload too large')
        raw=base64.b64decode(record['base64'],validate=True)
    else:
        rel=Path(str(record.get('path','')))
        if not str(rel) or rel.is_absolute() or '..' in rel.parts: raise ValueError('Native plane path must stay within the evidence directory')
        path=(root/rel).resolve()
        if not path.is_relative_to(root.resolve()): raise ValueError('Plane symlink escapes evidence directory')
        if path.stat().st_size!=count*2: raise ValueError('Native plane byte extent mismatch')
        raw=path.read_bytes()
    if len(raw)!=count*2: raise ValueError('Native plane byte extent mismatch')
    if sha(raw)!=record.get('sha256'): raise ValueError('Native plane SHA-256 mismatch')
    return base64.b64encode(raw).decode('ascii'),sha(raw)


def _case_readback(case: dict, root: Path):
    if 'native' in case:
        native=case['native']
        if not isinstance(native,dict): raise ValueError('Native attempt must be an object')
        if native.get('config',{}).get('extent')!=case.get('extent'): raise ValueError('Case/native extent disagreement')
        return checked_readback(native)
    extent=case.get('extent')
    if not isinstance(extent,list) or len(extent)!=2: raise ValueError('Native extent missing')
    w=_int(extent[0],'width',1,512);h=_int(extent[1],'height',1,512)
    source,source_hash=_plane_record(case.get('before'),root,w*h)
    result,result_hash=_plane_record(case.get('after'),root,w*h)
    wrapped={'state':case.get('status'),'config':{'extent':extent},'source_materials_base64':source,
             'source_material_sha256':source_hash,'material_cells_base64':result,'material_sha256':result_hash,
             'receipts':case.get('receipts')}
    return checked_readback(wrapped)


def reduce_manifest(manifest: dict, root: Path, registration: dict | None=None) -> dict:
    if manifest.get('schema_version')!=SCHEMA: raise ValueError('Unsupported architectural experiment manifest')
    if not re.fullmatch('[0-9a-f]{40}',str(manifest.get('source_commit',''))): raise ValueError('Exact experiment source commit missing')
    runtime=manifest.get('runtime',{})
    if not isinstance(runtime,dict) or not re.fullmatch('[0-9a-f]{64}',str(runtime.get('bridge_sha256',''))): raise ValueError('Native runtime identity missing')
    cases=manifest.get('cases')
    if not isinstance(cases,list) or len(cases)>MAX_CASES: raise ValueError('Native experiment case list missing or oversized')
    seen=set();observed_keys=set();outcomes=[]
    for case in cases:
        if not isinstance(case,dict):
            outcomes.append({'id':'malformed','evaluable':False,'native_completion':False,'reason':'Case is not an object'});continue
        out={k:case.get(k) for k in ['id','family','arm','seed','status','recipe_sha256']}
        out.update(evaluable=False,native_completion=False)
        try:
            identifier=case.get('id')
            if not isinstance(identifier,str) or not identifier or identifier in seen: raise ValueError('Missing or duplicate case identity')
            seen.add(identifier)
            if case.get('arm') not in ARMS: raise ValueError('Unregistered or model-dependent arm')
            key=(case.get('family'),case.get('arm'),case.get('seed'))
            if key in observed_keys: raise ValueError('Duplicate family/arm/seed attempt; retain under a distinct repetition registration')
            observed_keys.add(key)
            if registration is not None and (case.get('family') not in registration['families'] or case.get('seed') not in registration['seeds']): raise ValueError('Case outside frozen registration')
            if not re.fullmatch('[0-9a-f]{64}',str(case.get('recipe_sha256',''))): raise ValueError('Compiled recipe identity missing')
            config,before,after,before_raw,after_raw,confirmed=_case_readback(case,root)
            metrics=contextual_metrics(config['extent'],before,after,case.get('context'))
            actual_state=case.get('native',{}).get('state',case.get('status'))
            out.update(evaluable=True,native_completion=actual_state=='completed',native_status=actual_state,
                       metrics=metrics,source_sha256=sha(before_raw),result_sha256=sha(after_raw),
                       context_sha256=sha(json.dumps(case['context'],sort_keys=True,separators=(',',':')).encode()),
                       native_changed_acknowledgements=confirmed,
                       receipt_count=len(case.get('native',{}).get('receipts',case.get('receipts',[]))),
                       timings=case.get('timings',{}))
        except (ValueError,KeyError,TypeError,IndexError,OSError,AttributeError) as exc:
            out['reason']=str(exc)
        outcomes.append(out)
    missing=[]
    if registration is not None:
        for family in registration['families']:
            for arm in registration['arms']:
                for seed in registration['seeds']:
                    if (family,arm,seed) not in observed_keys: missing.append({'family':family,'arm':arm,'seed':seed,'status':'NOT_EXECUTED'})
    matches=[]
    blocks={}
    for out in outcomes:
        if out['evaluable']: blocks.setdefault((out['family'],out['seed']),[]).append(out)
    for (family,seed),items in sorted(blocks.items()):
        context_hashes={x['context_sha256'] for x in items}; sources={x['source_sha256'] for x in items}
        detail_counts={x['metrics']['new_detail_cells'] for x in items}
        matches.append({'family':family,'seed':seed,'evaluable_arms':[x['arm'] for x in items],
                        'all_five_evaluable':len({x['arm'] for x in items})==5,
                        'matched_context':len(context_hashes)==1,'matched_initial_plane':len(sources)==1,
                        'matched_new_detail_cell_budget':len(detail_counts)==1,
                        'new_detail_cells_by_arm':{x['arm']:x['metrics']['new_detail_cells'] for x in items},
                        'interpretation':'Unequal realized cells or different context must be reported; do not treat this as a controlled detail-quality comparison unless all matching fields pass.'})
    summaries=[]
    for arm in ARMS:
        records=[x for x in outcomes if x.get('arm')==arm]; valid=[x for x in records if x['evaluable']]
        assessed=[x for x in valid if x['metrics']['context_assessable']]
        summaries.append({'arm':arm,'attempts':len(records),'evaluable':len(valid),
                          'native_completed':sum(x['native_completion'] for x in valid),
                          'context_assessable':len(assessed),'context_checks_pass':sum(x['metrics']['contextual_detail_checks_pass'] is True for x in assessed),
                          'median_unanchored_detail_cells':statistics.median(x['metrics']['unanchored_detail_cells'] for x in valid) if valid else None,
                          'median_clearance_intrusion_cells':statistics.median(x['metrics']['new_clearance_intrusion_cells'] for x in valid) if valid else None})
    return {'schema_version':'cybersand.architectural-native-analysis.v1','source_commit':manifest['source_commit'],
            'runtime':runtime,'registration_sha256':manifest.get('registration_sha256'),'attempts':outcomes,
            'total_attempts':len(cases),'evaluable_attempts':sum(x['evaluable'] for x in outcomes),
            'native_completed_attempts':sum(x['native_completion'] for x in outcomes),
            'missing_registered_cases':missing,'matched_blocks':matches,'arm_summary':summaries,
            'model_assisted':{'executed_calls':manifest.get('model_calls'), 'reducer_executed_calls':0,'qualified':False,'reason':'No authorized model endpoint was used; all registered arms are offline controls.'},
            'human_preference':{'assessed':False,'blind_study':False},
            'claim_limits':['Matched geometry diagnostics are not an architectural preference or causal prompt-quality result.','Reference-guided and retrieval-guided plans are offline typed/procedural constructions, not model responses.','Hosted native completion is separate from graphical qualification and physical owner acceptance.','Missing, refused, stopped, partial, duplicate and unevaluable attempts remain visible.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path);parser.add_argument('--registration',type=Path);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); document=json.loads(args.manifest.read_text());registration=None
    if args.registration:
        raw=args.registration.read_bytes()
        if sha(raw)!=document.get('registration_sha256'): raise SystemExit('Experiment registration SHA-256 mismatch')
        registration=json.loads(raw)
    result=reduce_manifest(document,args.manifest.parent,registration)
    result['manifest_sha256']=sha(args.manifest.read_bytes())
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print(f"{result['evaluable_attempts']}/{result['total_attempts']} attempts independently evaluable; {len(result['missing_registered_cases'])} registered cases missing. No model or aesthetic preference conclusion.")

if __name__=='__main__':main()
