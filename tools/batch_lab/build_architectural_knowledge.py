#!/usr/bin/env python3
"""Derive compact architectural knowledge from frozen GOLDMAPS evidence.

No network, geometry import, training or mutation of the reference repository.
All structural-role and strategy annotations are interpretations, not native facts.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

EVIDENCE = '40f196f792e4d9e19bbd57fdafd6a90420fadf32'
ARCHIVE = 'b9535405853a5cd16e4bba968ec7167222861c42'
ENGINE = '662df51cd8409a52332fa7ef15d06d8ab8945aed'
BASE = 'docs/corpus/goldmaps-finalisation-001/'
GOLD = 'docs/corpus/goldmaps-recovery-001/snapshot/gold-candidates.v1.json'
ROOT = Path(__file__).resolve().parents[2]

# Curator-authored vocabulary. It is not a classification supplied by the source.
# family | topologies | suggested part types | character | connection intent
TAXONOMY = {
    197: ('freight_handoff', ['vertical_chain','opposed_banks','branch_rejoin'], ['beam_truss','mechanical_housing','service_gallery','passage_clearance'], ['industrial','science_fiction'], ['bank_handoff','service_access']),
    150: ('bioindustrial', ['open_ring','radial','branch_rejoin'], ['column_support','irregular_transition','passage_clearance','pipework'], ['organic','industrial'], ['rim_attachment','service_access']),
    174: ('settlement', ['distributed','multi_level','branch_rejoin'], ['column_support','wall_facade','floor_ceiling','window_door','mechanical_housing'], ['industrial','inhabited'], ['district_link','service_access']),
    130: ('nested_geology', ['nested_cavities','multi_level','branch_rejoin'], ['wall_facade','floor_ceiling','irregular_transition','passage_clearance'], ['geological','science_fiction','inhabited'], ['district_link','rock_anchor']),
    146: ('suspended_industry', ['suspended','linear_chain','parallel_lanes'], ['beam_truss','column_support','mechanical_housing','service_gallery','pipework'], ['industrial','thermal'], ['roof_anchor','process_handoff','service_access']),
    159: ('linear_industry', ['linear_chain','parallel_lanes','branch_rejoin'], ['column_support','beam_truss','floor_ceiling','service_gallery','mechanical_housing'], ['industrial','reclamation'], ['process_handoff','service_access']),
    155: ('machine_city', ['split_barrage','multi_level','branch_rejoin'], ['column_support','mechanical_housing','pipework','wall_facade','passage_clearance'], ['industrial','science_fiction'], ['process_handoff','district_link']),
    106: ('suspended_industry', ['suspended','distributed','open_span'], ['beam_truss','column_support','viaduct_segment','service_gallery'], ['industrial','science_fiction'], ['roof_anchor','service_access']),
    175: ('nested_geology', ['nested_cavities','linear_chain','branch_rejoin'], ['irregular_transition','window_door','wall_facade','passage_clearance','service_gallery'], ['geological','industrial'], ['rock_anchor','process_handoff','service_access']),
    182: ('racing_damage', ['branch_rejoin','opposed_banks','open_span'], ['irregular_transition','viaduct_segment','passage_clearance','service_gallery'], ['industrial','racing'], ['route_join','service_access']),
    148: ('civic', ['distributed','open_span','linear_chain'], ['column_support','floor_ceiling','wall_facade','window_door','service_gallery'], ['civic','inhabited'], ['district_link','service_access']),
    193: ('freight_handoff', ['vertical_chain','distributed','opposed_banks'], ['column_support','beam_truss','mechanical_housing','service_gallery'], ['industrial','logistics'], ['bank_handoff','process_handoff','service_access']),
    153: ('vessel_dock', ['suspended','open_span','opposed_banks'], ['beam_truss','mechanical_housing','irregular_transition','passage_clearance'], ['industrial','damaged'], ['roof_anchor','service_access','containment']),
    207: ('racing_damage', ['opposed_banks','open_span','parallel_lanes'], ['beam_truss','viaduct_segment','irregular_transition','passage_clearance'], ['industrial','damaged'], ['bank_handoff','route_join']),
    176: ('freight_handoff', ['opposed_banks','linear_chain','open_span'], ['column_support','beam_truss','mechanical_housing','service_gallery'], ['industrial','logistics'], ['bank_handoff','process_handoff','service_access']),
    168: ('machine_city', ['open_ring','linear_chain','branch_rejoin'], ['column_support','mechanical_housing','pipework','service_gallery'], ['industrial','chemical'], ['process_handoff','containment','service_access']),
    184: ('vessel_dock', ['vertical_chain','opposed_banks','open_span'], ['column_support','beam_truss','mechanical_housing','passage_clearance'], ['industrial','logistics'], ['bank_handoff','service_access']),
    163: ('vessel_dock', ['open_span','nested_cavities','linear_chain'], ['column_support','floor_ceiling','mechanical_housing','window_door','passage_clearance'], ['industrial','scientific'], ['service_access','containment']),
    143: ('bioindustrial', ['suspended','distributed','parallel_lanes'], ['column_support','beam_truss','irregular_transition','pipework','service_gallery'], ['organic','industrial'], ['roof_anchor','service_access','process_handoff']),
    147: ('bioindustrial', ['suspended','nested_cavities','parallel_lanes'], ['irregular_transition','wall_facade','window_door','passage_clearance'], ['organic','scientific'], ['roof_anchor','service_access']),
    131: ('settlement', ['distributed','suspended','branch_rejoin'], ['column_support','wall_facade','floor_ceiling','window_door','service_gallery'], ['organic','inhabited','science_fiction'], ['roof_anchor','district_link']),
    179: ('linear_industry', ['linear_chain','multi_level','branch_rejoin'], ['column_support','mechanical_housing','pipework','service_gallery'], ['industrial','thermal'], ['process_handoff','containment','service_access']),
    109: ('racing_damage', ['open_span','opposed_banks','branch_rejoin'], ['beam_truss','viaduct_segment','irregular_transition','passage_clearance'], ['geological','damaged','racing'], ['route_join','service_access']),
    136: ('civic', ['linear_chain','multi_level','branch_rejoin'], ['column_support','floor_ceiling','wall_facade','window_door','service_gallery'], ['civic','inhabited'], ['district_link','service_access']),
    125: ('nested_geology', ['opposed_banks','vertical_chain','multi_level','branch_rejoin'], ['column_support','irregular_transition','service_gallery','mechanical_housing','passage_clearance'], ['geological','scientific','damaged'], ['rock_anchor','bank_handoff','service_access']),
}

STRATEGY = {
    'freight_handoff': ['Reserve the central transfer void and at least one independent service route.', 'Place unequal founded or bank-attached receivers at distinct heights.', 'Connect only declared transfer interfaces; give each receiver an entered maintenance pocket.'],
    'bioindustrial': ['Reserve a large uninterrupted living or flight void before adding detail.', 'Place unequal rooted or suspended structural clusters with explicit attachment vertices.', 'Connect a sparse pipe or service network; keep the organic silhouette separate from human access.'],
    'settlement': ['Place two or three differently sized districts around a shared void.', 'Give each district a supported floor, an entered threshold and a distinct workface.', 'Connect districts using explicit passages while preserving expansion sockets.'],
    'nested_geology': ['Define the large cavity and independent bypasses as protected empty regions.', 'Place smaller entered rooms at more than one scale with explicit rock or frame anchors.', 'Add sparse cross-connections and keep their junctions readable.'],
    'suspended_industry': ['Declare roof anchors and a protected lower transit corridor.', 'Build the primary overhead beam and separated hanging process stations.', 'Place detail only at supported receivers, housings and access points.'],
    'linear_industry': ['Declare a primary process spine and a separate low or high recovery route.', 'Repeat structural bays with unequal functional stations and finite handoff interfaces.', 'Keep station entries and unused bays empty; add detail only after route verification.'],
    'machine_city': ['Separate the central machine void from the entered settlement or service district.', 'Place founded housings and connect a bounded process chain.', 'Protect initial containment boundaries and keep machine appearance distinct from simulated function.'],
    'racing_damage': ['Reserve the fast open route, the broken aperture and an independent recovery route.', 'Build different high and low support systems without healing intentional damage.', 'Place cues or repair pockets only outside the declared swept clearance.'],
    'civic': ['Choose continuous boulevard or separate piers before placing buildings.', 'Repeat supported floor and facade modules with unequal landmarks and entered service spaces.', 'Leave open gaps, entrances and spare extensions protected from generic filler.'],
    'vessel_dock': ['Reserve the whole dock void and a full-size hull-entry route.', 'Build unequal cradles or roof supports, then place the entered hull or housing.', 'Add service galleries and bounded repair details without filling damage or access openings.'],
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(root: Path, path: str):
    return json.loads((root/path).read_text(encoding='utf-8'))


def extract(root: Path) -> dict:
    head = subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'], text=True).strip()
    if head != ARCHIVE:
        raise ValueError(f'Reference checkout must be exactly {ARCHIVE}; got {head}')
    packet = read(root, BASE+'FINAL-DECISION-PACKET.json')
    corpus = read(root, BASE+'corpus.v1.json')
    lock = read(root, BASE+'corpus.v1.lock.json')
    if digest(root/(BASE+'corpus.v1.json')) != lock['sha256']:
        raise ValueError('Frozen GOLDMAPS corpus lock mismatch')
    if packet['evidence_authority']['finalisation_head'] != EVIDENCE:
        raise ValueError('Wrong evidence authority')
    gold = read(root, GOLD)
    windows = read(root, BASE+'native/receipts/windows-final/summary.json')
    policy = read(root, BASE+'native/receipts/policy-schema-all67/summary.json')
    maps = {int(m['pr']):m for m in corpus['maps']}
    policies = {int(m['pr']):m for m in policy['results']}
    native = {int(s['pr']):r for r in windows['results'] for s in r['source_records'] if s.get('pr') and s.get('head') == maps.get(int(s['pr']),{}).get('head') and s.get('setup_sha256') == maps.get(int(s['pr']),{}).get('source',{}).get('sha256')}
    if set(packet['gold_recommendation']['recommended_source_prs']) != set(TAXONOMY):
        raise ValueError('Gold roster changed; do not silently rewrite the curated set')
    family_by_pr = {}
    for f in corpus['comparative_families']:
        key='ancestry-pr'+str(f['donor_pr'])
        for k in ['donor_pr','portrait_pr','repair_pr']:
            if f.get(k): family_by_pr[int(f[k])]=key
    cards=[]
    for g in sorted(gold['records'],key=lambda x:x['pr']):
        pr=int(g['pr']); m=maps[pr]; p=m['material_plane']; meta=m.get('metadata') or {}; n=native.get(pr,{}); pol=policies.get(pr,{})
        if g['head_sha'] != m['head'] or g['source']['setup_sha256'] != m['source']['sha256']:
            raise ValueError(f'Original source mismatch for PR {pr}')
        family,topologies,parts,character,connections=TAXONOMY[pr]
        criteria=g['criteria']
        exact_features=[]
        for s in corpus['feature_history']:
            if s.get('evidence',{}).get('reviewed_head') == m['head'] and int(s.get('provenance',{}).get('portrait_pr',-1)) == pr:
                exact_features.append({'state_id':s['state_id'],'feature_id':s['feature_id'],'observed_source_static':s['analysis'].get('observed_source_static'),'constraints':s['constraints'],'bounds':s['location'].get('feature_bbox_xyxy'),'evidence_window_is_edit_mask':False,'review_url':s['evidence'].get('reviewer_url')})
        policy_state='UNKNOWN' if not pol else ('ADMITTED' if pol['validation']['accepted'] else 'REFUSED')
        cards.append({
            'id':f'goldmaps-pr{pr}', 'name':g['name'], 'architectural_family':family,
            'ancestry_group':family_by_pr.get(pr,f'original-pr{pr}'),
            'source':{'repository':corpus['repository'],'pr':pr,'commit':m['head'],'path':m['source']['path'],'url':m['source']['url'],'setup_sha256':m['source']['sha256'],'setup_git_blob':m['source']['git_blob_sha1'],'material_plane_sha256':p['plane_sha256'],'evidence_commit':EVIDENCE},
            'observed':{'method':'Frozen exact-source material replay; imported measurements, not a new runtime execution','extent':p['extent'],'occupied_cells':p['occupied_cells'],'empty_fraction':round((p['full_plane_cells']-p['occupied_cells'])/p['full_plane_cells'],6),'material_cells':p['materials'],'rectangle_count':p['stamp_count'],'source_static_status':m['source_static_qualification']['status'],'reference_image':next(({'url':i['url'],'sha256':i['sha256']} for i in m['images'] if i.get('role')=='material_cell_overview'),None)},
            'interpreted':{'authority':'Curated architectural interpretation of cited source review and source-authored metadata; not native attachment, strength or actor-motion proof','macro_composition':criteria['silhouette'],'support_relationships':criteria['support_grammar'],'traversal_and_hierarchy':criteria['topology_midge_function_and_districts'],'negative_space_and_protection':criteria['deliberate_gaps_voids_damage_and_thresholds'],'repetition_and_asymmetry':meta.get('density_profile','UNKNOWN'),'source_motifs':meta.get('strong_motifs',[]),'source_authored_family':meta.get('family','UNKNOWN'),'source_authored_route_grammar':meta.get('route_grammar',{}),'review_url':g['review_evidence']['review_url'],'reviewed_commit':g['review_evidence']['reviewed_head'],'source_metadata_url':(m.get('metadata_source') or {}).get('url')},
            'facets':{'topologies':topologies,'parts':parts,'character':character,'connection_intents':connections,'scale':'district','orientation':m['aspect_ratio'],'suggested_material_roles':['structure','detail'],'palette_material_ids':sorted(int(k) for k in p['materials'] if int(k)!=0)},
            'construction_strategy':STRATEGY[family],
            'failure_modes':['Replacing intentional empty space with undirected detail.','Treating a decorative mechanism as demonstrated native machinery.','Inferring an editable mask from a reference crop.'] + (['Repairing a deliberately broken span destroys the original route/damage distinction.'] if 'damaged' in character else []),
            'protected_features':exact_features,
            'qualification':{'schema':'ADMITTED' if pol.get('workbench_schema_accepted') else 'UNKNOWN','native_policy':policy_state,'native_policy_refusal':pol.get('validation',{}).get('refusal'),'native_headless':n.get('qualification_status','NOT_EXERCISED'),'native_engine':ENGINE,'native_windows_run':windows['github_run_id'] if n else None,'native_receipt_id':n.get('id'),'graphical':'NOT_ESTABLISHED_BY_HEADLESS','owner_acceptance':'PENDING','gold':'RECOMMENDED_NOT_ACCEPTED','direct_module_import':'NOT_ADMITTED_BY_RETRIEVAL','policy_descendant_identity':('Separate pr155-policy-repair descendant; original remains refused' if pr==155 else None)},
            'native_module_ids':[],
        })
    source_files=[BASE+'FINAL-DECISION-PACKET.json',BASE+'corpus.v1.json',BASE+'corpus.v1.lock.json',GOLD,BASE+'native/receipts/windows-final/summary.json',BASE+'native/receipts/policy-schema-all67/summary.json']
    return {
        'schema_version':'cybersand.architectural-design-cards.v1','corpus_id':'world-steer-goldmaps-knowledge.v1','status':'DRAFT_HOLD',
        'authority':{'kind':'reference_knowledge_only','repository':'techrote/sandmapsreference','evidence_commit':EVIDENCE,'archival_commit':ARCHIVE,'packet_url':f'https://github.com/techrote/sandmapsreference/blob/{ARCHIVE}/{BASE}FINAL-DECISION-PACKET.md','source_inputs':[{'path':p,'sha256':digest(root/p)} for p in source_files],'counts':packet['corpus'],'source_artwork_copied':False,'geometry_copied':False,'provider_authority':False,'execution_authority':False,'owner_acceptance':False},
        'usage_limits':['Knowledge is context, never permission to write World cells.','Original source, policy descendants, native qualification and owner preference are separate identities.','A compatible local module must be separately harvested and validated by the native module host.','Source metadata and curator roles are interpretations; unknown measured features remain unknown.','No image, full Setup, frozen training split or provider credential is included.'],
        'cards':cards,
        'comparative_family_links':[{'id':'ancestry-pr'+str(f['donor_pr']),**f} for f in corpus['comparative_families']],
        'negative_interventions':[{'id':n['id'],'source_pr':n['source_pr'],'source_head':n['source_head'],'failure_reasons':n['failure_reasons'],'accepted_positive_example':False} for n in corpus['negative_examples']],
        'intervention_decisions':packet['trial']['arms'],
        'refused_originals':packet['native']['policy_schema_scan']['refusals'],
        'held_out_evaluation':{'kind':'family_excluded_retrieval_transfer','development_families':sorted(set(x[0] for x in TAXONOMY.values())-{'bioindustrial','civic','vessel_dock'}),'held_out_families':['bioindustrial','civic','vessel_dock'],'limitation':'All cards were available to the curator. Held-out means excluded from retrieval candidates and ranking development fixtures, not unfamiliar to the annotator or a blind model-quality study.'},
    }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-root',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=ROOT/'godot/data/batch_lab/architectural_design_cards.v1.json')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    data=(json.dumps(extract(args.reference_root),indent=2,ensure_ascii=False,sort_keys=True)+'\n').encode()
    if args.check:
        if args.output.read_bytes()!=data: raise SystemExit('Generated architectural knowledge differs from frozen reference derivation')
        print('PASS exact architectural knowledge derivation',hashlib.sha256(data).hexdigest())
    else:
        args.output.parent.mkdir(parents=True,exist_ok=True); args.output.write_bytes(data)
        print(f'Wrote 25 source-bound cards ({len(data)} bytes; sha256 {hashlib.sha256(data).hexdigest()})')

if __name__=='__main__': main()
