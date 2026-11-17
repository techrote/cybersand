#!/usr/bin/env python3
"""Apply the post-corpus descriptive review and render exact-cell compact galleries.

No generation, native evidence mutation, aesthetic scoring, or pixel retouching.
The registered100 stay fixed; benchmarks are a post-review subset linked back to
full raw evidence. Existing facts are preserved; only review metadata is added.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path
import re
import sys
from PIL import Image, ImageDraw

REVIEW_FIELDS = {'review_labels','review_note','visual_review_scope','benchmark','benchmark_reason','review_metadata'}
PROFILE_IDS = ['C100-001','C100-002','C100-003','C100-021','C100-022','C100-023','C100-036','C100-037','C100-038']
CONTROL_IDS = ['C100-048','C100-059','C100-062','C100-093']
NEGATIVE_IDS = ['C100-017','C100-033','C100-073','C100-081','C100-097','C100-098']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text())


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo',type=Path,required=True)
    ap.add_argument('--evidence',type=Path,required=True)
    ap.add_argument('--review',type=Path)
    args=ap.parse_args()
    repo=args.repo.resolve(); out=args.evidence.resolve()
    review_path=(args.review or repo/'native/experiments/gentek_swarm/corpus100-review.json').resolve()
    review_hash=digest(review_path); review=read_json(review_path)
    reg=read_json(out/'registration.json'); run=read_json(out/'manifest.json')
    if run['result']!='PASS' or run['native_raw_count']!=100:
        raise RuntimeError('Post-review finish requires the completed qualified100 native outcomes')
    if review['qualified_native_source']!=run['source_commit'] or review['registration_commit']!=run['registration_commit']:
        raise RuntimeError('Review source/registration identity mismatch')
    case_ids=[c['case_id'] for c in reg['cases']]
    reviewed={r['case_id']:r for r in review['cases']}
    if len(reviewed)!=100 or len(review['cases'])!=100 or set(case_ids)!=set(reviewed):
        raise RuntimeError('Review must cover every registered identity exactly once')
    chosen=[r for r in review['cases'] if r.get('benchmark')]
    if len(chosen)!=review['benchmark_count'] or not 12<=len(chosen)<=20:
        raise RuntimeError('Benchmark count violates declared12..20 bounded subset')
    protected=[out/'manifest.json',out/'registration.json']+[p for name in ('native','replay','sanitized') for p in sorted((out/name).glob('*.json'))]
    protected_before={p.relative_to(out).as_posix():digest(p) for p in protected}
    index=read_json(out/'case-index.json')
    if [r['case_id'] for r in index]!=case_ids:
        raise RuntimeError('Case index order differs from registered order')
    metadata={'source':str(review_path.relative_to(repo)) if review_path.is_relative_to(repo) else str(review_path),
              'sha256':review_hash,'reviewed_utc':review['reviewed_utc'],
              'interpretation':review['interpretation'],'selection_discipline':review['selection_discipline']}
    numeric_before={r['case_id']:{k:v for k,v in r.items() if k not in REVIEW_FIELDS} for r in index}
    for record in index:
        cid=record['case_id']; supplied=reviewed[cid]
        if not supplied.get('review_labels') or not supplied.get('review_note'):
            raise RuntimeError(f'{cid}: empty descriptive review')
        for field in ('review_labels','review_note','visual_review_scope','benchmark','benchmark_reason'):
            if field in supplied:record[field]=supplied[field]
        record['review_metadata']=metadata
        native_facts={k:v for k,v in record.items() if k not in REVIEW_FIELDS}
        if native_facts!=numeric_before[cid]:
            raise RuntimeError(f'{cid}: review application changed numeric/native facts')
        existing=read_json(out/'case_records'/(cid+'.json'))
        if {k:v for k,v in existing.items() if k not in REVIEW_FIELDS}!=native_facts:
            raise RuntimeError(f'{cid}: case record and index already disagree on facts')
        write_json(out/'case_records'/(cid+'.json'),record)
    write_json(out/'case-index.json',index)
    records={r['case_id']:r for r in index}
    benchmark=[]
    for item in chosen:
        cid=item['case_id'];r=records[cid]
        benchmark.append({
            'case_id':cid,'group':r['group'],'kind':r['kind'],'right_kind':r['right_kind'],
            'fixture':r['fixture'],'profile':r['profile'],'seed':r['seed'],'dimensions':r['dimensions'],
            'origin':r['origin'],'overrides':r['overrides'],'selection_reason':item['benchmark_reason'],
            'review_labels':r['review_labels'],'review_note':r['review_note'],
            'full_raw_native':{'file':r['raw_native_json'],'sha256':r['raw_sha256']},
            'full_case_facts':{'file':f'case_records/{cid}.json','sha256':digest(out/'case_records'/(cid+'.json'))},
            'native_material_array':r['native_material_array'],'attribution_arrays':r['attribution_arrays'],
            'control_arrays':r['control_arrays'],'images':r['images'],'gallery_anchor':'index.html#'+cid,
            'compiled_definition_fingerprint':r['compiled_definition_fingerprint'],
            'material_array_sha256':r['final_material_array_sha256'],'per_owner_digests':r['per_owner_digests'],
            'pair_semantic_digest':r['pair_semantic_digest'],'generation_statuses':r['generation_statuses'],
            'solver_statuses':r['solver_statuses'],'mandatory_unresolved':r['mandatory_unresolved'],
            'validated_joints':r['validated_joints'],'total_late_additions':r['total_late_additions']})
    write_json(out/'benchmark-manifest.json',{
        'programme':'GENTEK-SWARM-CORPUS-100','status':'Draft / HOLD — descriptive benchmark subset',
        'source_head':run['source_commit'],'registration_commit':run['registration_commit'],
        'registration_sha256':run['registration_sha256'],'review_sha256':review_hash,
        'selection_discipline':review['selection_discipline'],'count':len(benchmark),'cases':benchmark})
    html_path=out/'index.html';document=html_path.read_text();sections_seen=[]
    def annotate(match):
        attributes,body=match.group(1),match.group(2)
        found=re.search(r'C100-\d{3}',html.unescape(body))
        if found is None:return match.group(0)
        cid=found.group();r=records[cid];sections_seen.append(cid)
        body=re.sub(r'<div class="review-metadata".*?</div>','',body,flags=re.S)
        labels=' · '.join(r['review_labels'])
        review_text='<div class="review-metadata"><p><strong>Review labels:</strong> '+html.escape(labels)+'</p><p>'+html.escape(r['review_note'])+'</p>'
        if r.get('benchmark'):review_text+='<p><strong>Benchmark:</strong> '+html.escape(r['benchmark_reason'])+'</p>'
        review_text+='</div>'
        body=re.sub(r'(</h2>)',lambda m:m.group()+review_text,body,count=1)
        search=' '.join([cid,r['kind'],r['right_kind'] or '',r['fixture'],r['profile'],str(r['seed']),*r['descriptive_evidence_flags'],*r['review_labels'],r['review_note'],'benchmark' if r.get('benchmark') else '']).lower()
        attributes=re.sub(r'\s+(?:id|data-filter)="[^"]*"','',attributes)
        return '<section id="'+cid+'" data-filter="'+html.escape(search,quote=True)+'"'+attributes+'>'+body+'</section>'
    document=re.sub(r'<section\b([^>]*)>(.*?)</section>',annotate,document,flags=re.S)
    if len(sections_seen)!=100 or set(sections_seen)!=set(case_ids):
        raise RuntimeError('HTML annotation did not locate exactly100 case sections')
    document=re.sub(r'<div id="post-review-intro">.*?</div>','',document,flags=re.S)
    intro='<div id="post-review-intro"><p>All100 registered outcomes carry descriptive review labels. The20 benchmark cases include failures and weak joins; labels are judgments, not numerical truth. Filter by a label, case ID or “benchmark”.</p><p><a href="compact_gallery/corpus100-profiles.png">Profile comparison</a> · <a href="compact_gallery/corpus100-controls.png">Three retained controls</a> · <a href="compact_gallery/corpus100-negatives.png">Negative cases</a> · <a href="benchmark-manifest.json">Complete benchmark mapping</a></p></div>'
    document=re.sub(r'(</h1>)',lambda m:m.group()+intro,document,count=1)
    html_path.write_text(document)
    sys.dont_write_bytecode=True
    sys.path.insert(0,str(repo/'native/experiments/gentek_swarm'))
    import gallery as g
    compact=out/'compact_gallery';compact.mkdir(exist_ok=True)
    native={cid:read_json(out/'native'/(cid+'.json')) for cid in set(PROFILE_IDS+CONTROL_IDS+NEGATIVE_IDS)}
    GAP=16;CW=412;WIDTH=1300
    def text(draw,xy,value,size=14,fill=None):
        draw.text(xy,value,font=g.font(size),fill=fill or g.FG)
    def raster(case,mode='final'):
        q=case['request'] if case['type']=='single' else case['left_request']
        data=case['result']['cells'] if case['type']=='single' else case[{'clipped':'clipped_cells','own':'initial_cells','final':'cells'}[mode]]
        if len(data)==q['width']*q['height']:
            return g.raster(data,q).resize((384,224),Image.Resampling.NEAREST)
        image=Image.new('RGB',(384,224),g.BG);draw=ImageDraw.Draw(image)
        text(draw,(25,62),'NO MATERIAL ARRAY',24,(255,166,127));text(draw,(25,99),'capacity refusal',21,(255,166,127))
        text(draw,(25,139),'Raw material array remains empty',15,g.MUTED)
        return image
    def new_sheet(title,subtitle,rows,card_height,top=88):
        image=Image.new('RGB',(WIDTH,top+(rows+1)*GAP+rows*card_height),g.BG);draw=ImageDraw.Draw(image)
        text(draw,(GAP,10),title,24);text(draw,(GAP,43),subtitle,14,g.MUTED)
        text(draw,(GAP,65),'Draft / HOLD | native material | source '+run['source_commit'][:8]+' | nearest-neighbour display | no simulation',13,g.MUTED)
        return image
    def single_card(cid,height=330):
        r=records[cid];case=native[cid];panel=Image.new('RGB',(CW,height),(20,27,36));draw=ImageDraw.Draw(panel)
        label=r['kind']+(' x '+r['right_kind'] if r['right_kind'] else '')
        text(draw,(12,8),cid+' | '+label,16)
        text(draw,(12,31),r['fixture']+' | '+r['profile']+' | seed '+str(r['seed']),11,g.MUTED)
        panel.paste(raster(case),(14,54))
        status='/'.join(r['generation_statuses'])
        text(draw,(12,286),status+' | cells '+str(r['occupied_generated_cells'])+' | joints '+str(r['validated_joints']),12)
        text(draw,(12,306),'mandatory '+str(r['mandatory_fulfilled'])+'/'+str(r['mandatory_connectors'])+' fulfilled | unresolved '+str(r['mandatory_unresolved']),12,g.MUTED)
        return panel
    profiles=new_sheet('Profile comparison — three distinct Genteks','Columns: sparse_regular | branching_irregular | dense_cohesive. Rows: FRAMEWEAVER | MOSAIC | RECEPTOR.',3,330)
    for i,cid in enumerate(PROFILE_IDS):profiles.paste(single_card(cid),(GAP+(i%3)*(CW+GAP),88+GAP+(i//3)*(330+GAP)))
    profiles.save(compact/'corpus100-profiles.png')
    controls=new_sheet('Boundary controls — the same requests in three stages','Columns: independent / clipped | own territory | final SWARM-001 adaptation and meshing. Cyan overlays remain in full evidence.',4,322)
    modes=[('clipped','Independent / clipped','clipped_left','clipped_right'),('own','Own territory','initial_left','initial_right'),('final','Final SWARM-001','left','right')]
    for row,cid in enumerate(CONTROL_IDS):
        case=native[cid];r=records[cid]
        for col,(mode,label,left,right) in enumerate(modes):
            panel=Image.new('RGB',(CW,322),(20,27,36));draw=ImageDraw.Draw(panel);rs=[case[left],case[right]]
            text(draw,(12,8),cid+' | '+label,16)
            text(draw,(12,31),r['fixture']+' | '+r['profile']+' | seed '+str(r['seed']),11,g.MUTED)
            panel.paste(raster(case,mode),(14,51))
            mandatory=sum(c['required'] for owner in rs for c in owner['connectors']);fulfilled=sum(c['required'] and c['fulfilled'] for owner in rs for c in owner['connectors']);unresolved=sum(owner['unresolved_joints'] for owner in rs)
            joints=r['validated_joints'] if mode=='final' else 0
            text(draw,(12,281),f'joints {joints} | mandatory {fulfilled}/{mandatory} | unresolved {unresolved}',12)
            if mode=='final':footer=f"late cells: {r['late_shared_bridge_cells']} shared + {r['late_adapter_cells_excluding_cohesion']} adapter + {r['late_cohesion_cells']} cohesion = {r['total_late_additions']}"
            else:footer='No foreign joins; late additions 0 | '+' / '.join(owner['status'] for owner in rs)
            text(draw,(12,302),footer,11,g.MUTED)
            controls.paste(panel,(GAP+col*(CW+GAP),88+GAP+row*(322+GAP)))
    controls.save(compact/'corpus100-controls.png')
    negatives=new_sheet('Retained negative and cautionary cases','Damage, UNSAT, unresolved mandatory connectors, large seam additions, generator exhaustion and memory refusal.',2,330)
    for i,cid in enumerate(NEGATIVE_IDS):negatives.paste(single_card(cid),(GAP+(i%3)*(CW+GAP),88+GAP+(i//3)*(330+GAP)))
    negatives.save(compact/'corpus100-negatives.png')
    protected_after={p.relative_to(out).as_posix():digest(p) for p in protected}
    if protected_before!=protected_after:raise RuntimeError('Immutable qualification evidence changed')
    final_index=read_json(out/'case-index.json')
    if any({k:v for k,v in r.items() if k not in REVIEW_FIELDS}!=numeric_before[r['case_id']] for r in final_index):
        raise RuntimeError('Post-review finish changed measured facts')
    if digest(review_path)!=review_hash:raise RuntimeError('Review input changed during finish; rerun from latest review')
    receipt={'programme':'GENTEK-SWARM-CORPUS-100','source_head':run['source_commit'],'review_sha256':review_hash,
             'finish_script_sha256':digest(Path(__file__)),'finished_utc':datetime.now(timezone.utc).isoformat(),
             'reviewed_cases':len(index),'benchmarks':len(benchmark),'preserved_raw_inputs':len(protected),
             'all_native_numeric_facts_preserved':True,
             'galleries':{p.relative_to(out).as_posix():{'sha256':digest(p),'dimensions':list(Image.open(p).size)} for p in sorted(compact.glob('*.png'))}}
    write_json(out/'post-review-manifest.json',receipt)
    print(json.dumps(receipt,indent=2))


if __name__=='__main__':main()
