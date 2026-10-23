#!/usr/bin/env python3
"""Author the GEN-007 reusable grammar; outputs declarative JSON, never raster cells.

Four fixed district anchors are intentional composition. Every repeated gallery,
service cabinet, fixture and layer is expanded by native GEN-004/005 at runtime.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'examples/worldgen/gen007-deepworks.json'
rules = []
projections = []
fixtures = []
links = []

def rule(name, kind, bounds, *, material=None, children=(), count=1, candidates=None, tags=(), sockets=()):
    sites = candidates or [{'id': 'anchor', 'bounds': bounds, 'order_x': 0, 'order_y': 0}]
    value = {'id': name, 'kind': kind, 'count': count, 'material': material, 'interior': 0,
             'wall_thickness': (1 if material and all(min(site['bounds'][2:]) > 2 for site in sites) else 0), 'tags': list(tags),
             'candidates': sites}
    if children: value['children'] = list(children)
    if sockets: value['sockets'] = list(sockets)
    rules.append(value)
    return value

def proj(name, selector, plane, material=None, *, bounds=None, shape='fill', priority=10, interior=0, wall=2, **kw):
    value = {'id': name, 'rule': selector, 'plane': plane, 'geometry': 'feature',
             'shape': shape, 'priority': priority}
    if material is not None: value['material'] = material
    if bounds: value['bounds'] = bounds
    if shape == 'shell': value.update(interior=interior, wall_thickness=wall)
    value.update(kw)
    projections.append(value)

def fixture(name, selector, plane, material, bounds, *, products=(), mode='source', first=1, period=12, repeat=12):
    fixtures.append({'id': name, 'rule': selector, 'plane': plane, 'material': material,
                     'bounds': bounds, 'mode': mode, 'first_tick': first, 'period': period,
                     'repeat': repeat, 'expected_products': list(products)})

# Names express functional material roles. The four manual anchors leave a
# central circulation cross and a twelve-cell exterior margin.
districts = [
    ('copper-choir', [16, 16, 480, 480], 119, 69, 77, 'brine-retort'),
    ('frost-observatory', [528, 16, 480, 480], 121, 114, 80, 'snow-lens'),
    ('ember-terraces', [16, 528, 480, 480], 104, 51, 79, 'clay-kiln'),
    ('basalt-archive', [528, 528, 480, 480], 100, 122, 78, 'geothermal-well'),
]
for number, (name, bounds, wall, trim, lamp, apparatus) in enumerate(districts):
    region_children = ['upper-gallery', 'lower-gallery', apparatus]
    if number in (0, 2): region_children.append('optional-loop')
    if number == 1: region_children.append('optical-core')
    if number == 3: region_children.append('vault-lock')
    r = rule(name, 'district', bounds, material=wall,
             children=region_children,
             tags=('major-region', name))
    r['themes'] = [{'id': name, 'weight': 1}]
    # Deliberately different silhouettes: vertical choir ribs, stepped lenses,
    # horizontal firing terraces and monumental archive pylons.
    proj(name+'-frame', name, 'play', wall, shape='shell', wall=4, priority=2)
    proj(name+'-sky', name, 'background', wall, shape='shell', wall=14, bounds=[22,10,436,460], priority=1)
    proj(name+'-header', name, 'play', trim, bounds=[16,12,448,5], priority=5)
    proj(name+'-name-light', name, 'play', lamp, bounds=[32,19,80,2], priority=6)
    if number == 0:
        for i in range(4):
            proj(name+'-organ-'+str(i), name, 'background', 69, shape='shell', wall=3, interior=65,
                 bounds=[42+i*104,30+i*12,27,400-i*22], priority=6)
        proj(name+'-organ-chest',name,'background',119,shape='shell',wall=6,interior=72,bounds=[202,38,224,132],priority=7)
        proj(name+'-upper-manifold',name,'scripted',69,shape='shell',wall=4,interior=66,bounds=[214,58,198,92],priority=10)
        proj(name+'-lower-manifold',name,'background',69,shape='shell',wall=6,interior=72,bounds=[258,308,168,132],priority=7)
    elif number == 1:
        proj(name+'-upper-lens-cradle',name,'background',114,shape='shell',wall=8,interior=72,bounds=[198,30,230,160],priority=6)
        proj(name+'-lower-lens-cradle',name,'background',114,shape='shell',wall=8,interior=72,bounds=[42,296,232,142],priority=6)
        proj(name+'-optical-spine',name,'scripted',114,shape='shell',wall=4,interior=72,bounds=[292,192,30,108],priority=7)
    elif number == 2:
        proj(name+'-upper-furnace',name,'background',104,shape='shell',wall=12,interior=100,bounds=[194,32,236,160],priority=6)
        proj(name+'-upper-refractory',name,'background',131,shape='shell',wall=8,interior=72,bounds=[218,56,188,112],priority=7)
        proj(name+'-lower-furnace',name,'background',104,shape='shell',wall=10,interior=100,bounds=[246,298,184,142],priority=6)
        proj(name+'-lower-refractory',name,'background',131,shape='shell',wall=7,interior=72,bounds=[268,320,140,98],priority=7)
        proj(name+'-flue',name,'scripted',51,shape='shell',wall=5,interior=0,bounds=[290,192,46,108],priority=7)
        proj(name+'-upper-fire-window',name,'background',79,shape='shell',wall=4,interior=66,bounds=[250,84,124,56],priority=8)
        proj(name+'-lower-fire-window',name,'background',79,shape='shell',wall=4,interior=66,bounds=[292,342,92,54],priority=8)
    else:
        proj(name+'-upper-vault',name,'background',122,shape='shell',wall=8,interior=100,bounds=[196,30,234,162],priority=6)
        proj(name+'-upper-vault-door',name,'background',119,shape='shell',wall=6,interior=72,bounds=[244,54,138,114],priority=7)
        proj(name+'-lower-register',name,'background',122,shape='shell',wall=8,interior=100,bounds=[42,296,234,144],priority=6)
        proj(name+'-lower-register-door',name,'background',119,shape='shell',wall=5,interior=72,bounds=[68,318,182,100],priority=7)
        for i in range(3):
            proj(name+'-register-shelf-'+str(i),name,'background',66,bounds=[84,336+i*26,150,5],priority=8)

# Two sizes of cradle use the same optical instrument assembly, including four
# visible support brackets. These are native grammar children with owned IDs.
rule('optical-core','apparatus',None,material=122,count=2,candidates=[
    {'id':'upper','bounds':[232,52,162,118],'order_x':0,'order_y':0},
    {'id':'lower','bounds':[76,310,162,118],'order_x':1,'order_y':0}],
    children=('optical-aperture','optical-brace'),tags=('regional-focal','optical-instrument'))
proj('optical-core','optical-core','background',122,shape='shell',wall=12,interior=121,priority=7)
rule('optical-aperture','detail',[46,22,70,74],material=72,tags=('micro-detail','optical-aperture'))
proj('optical-aperture','optical-aperture','background',66,shape='shell',wall=3,interior=72,priority=8)
rule('optical-brace','detail',None,material=114,count=4,candidates=[
    {'id':f'brace-{i}','bounds':b,'order_x':i,'order_y':0} for i,b in enumerate(
        [[12,50,12,18],[138,50,12,18],[72,12,18,12],[72,94,18,12]])],tags=('micro-detail','optical-support'))
proj('optical-brace','optical-brace','background',114,priority=9)
rule('vault-lock','detail',None,material=119,count=2,candidates=[
    {'id':'upper','bounds':[306,102,14,18],'order_x':0,'order_y':0},
    {'id':'lower','bounds':[151,357,14,18],'order_x':1,'order_y':0}],tags=('micro-detail','vault-lock'))
proj('vault-lock','vault-lock','background',119,shape='shell',wall=3,interior=78,priority=9)

socket = {'id':'entry', 'type':'passage', 'direction':'east', 'offset':84,
          'width':11, 'required':True, 'attach_to_route':True}
for hall, y, material in [('upper-gallery',24,58), ('lower-gallery',276,70)]:
    rule(hall, 'room', [16,y,448,176], material=material,
         children=('service-module' if hall=='upper-gallery' else 'lower-service-module','service-rail'),
         tags=('named-subregion', hall), sockets=(socket,))
    proj(hall+'-floor', hall, 'play', material, shape='shell', wall=3, priority=8)
    proj(hall+'-rear', hall, 'scripted', 64, shape='shell', wall=2, bounds=[5,5,438,166], priority=8)
    proj(hall+'-lintel', hall, 'play', 62, bounds=[4,8,440,3], priority=9)
    proj(hall+'-toe', hall, 'play', 76, bounds=[12,164,424,2], priority=9)
    proj(hall+'-distant', hall, 'background', 72, shape='shell', wall=8, bounds=[8,8,432,160], priority=5)
    # Every named gallery has local atmospheric treatment and intentional air.
    proj(hall+'-atmosphere', hall, 'effects', 22, bounds=[202,18,40,4], priority=2)

# Two selected cabinets frame larger regional machinery. Upper galleries use a
# horizontal candidate line; lower galleries use a staggered service arrangement.
module_candidates = [{'id':f'bay-{i}', 'bounds':[24+i*104,20,76,58], 'order_x':i, 'order_y':0} for i in range(4)]
cabinet_rule = rule('service-module','apparatus',None,material=62,count=2,candidates=module_candidates,
     children=('cabinet-window','gauge','shelf','signal'),tags=('micro-feature','service-cabinet'))
# Negative route weight prefers sites away from the seeded native passage
# envelope; stable slots remain, but the chosen two bays can change by seed.
cabinet_rule['preferences'] = [{'id':'quiet-service-bay','kind':'route','weight':-1}]
lower_candidates = [{'id':f'bay-{i}', 'bounds':b, 'order_x':i, 'order_y':1} for i,b in enumerate(
    [[24,20,76,58],[328,94,76,58],[128,20,76,58],[328,20,76,58]])]
lower_cabinet_rule = rule('lower-service-module','apparatus',None,material=62,count=2,candidates=lower_candidates,
    children=('cabinet-window','gauge','shelf','signal'),tags=('micro-feature','service-cabinet'))
lower_cabinet_rule['preferences'] = [{'id':'quiet-lower-service-bay','kind':'route','weight':-1}]
for selector in ['service-module','lower-service-module']:
    proj(selector+'-frame',selector,'play',62,shape='shell',wall=2,priority=15)
    proj(selector+'-rear',selector,'scripted',69,shape='shell',wall=3,bounds=[3,3,70,52],priority=15)
rule('cabinet-window','detail',[8,7,60,30],material=72,tags=('micro-detail','inspection-window'))
proj('cabinet-window-play','cabinet-window','play',0,priority=16)
proj('cabinet-window-rear','cabinet-window','scripted',74,shape='shell',wall=2,interior=72,priority=16)
rule('gauge','detail',[10,40,14,10],material=121,tags=('micro-detail','instrument'))
proj('gauge-frame','gauge','play',119,shape='shell',wall=2,interior=121,priority=17,application='spatial:weathering')
rule('shelf','detail',[30,40,36,4],material=66,tags=('micro-detail','specimen-shelf'))
proj('shelf-play','shelf','play',66,priority=17)
rule('signal','detail',[44,47,22,2],material=77,tags=('micro-detail','signal'))
proj('signal-play','signal','play',77,priority=18)
rule('service-rail','apparatus',[16,148,416,4],material=69,tags=('micro-feature','service-network'))
proj('rail-play','service-rail','play',69,priority=20)
proj('rail-rear','service-rail','scripted',68,priority=20)
links.append({'id':'service-correspondence','rule':'service-rail','family':'pipe','classification':'static',
              'source_plane':'play','target_plane':'scripted','effect':'correspondence','bounds':[0,0,416,4]})

# Two independently connected outboard loops. Their solid inner plinth makes
# the ring a real material route; the entrance cuts only the outer ring wall.
rule('optional-loop','complex',[48,368,192,80],material=100,tags=('optional-loop','secondary-passage'))
proj('loop-clearance','optional-loop','play',0,shape='shell',wall=13,interior=100,priority=25)
proj('loop-inner-trim','optional-loop','play',69,shape='shell',wall=2,interior=72,bounds=[16,16,160,48],priority=26)
proj('loop-backdrop','optional-loop','background',119,bounds=[20,20,152,40],priority=12)
proj('loop-status-band','optional-loop','play',77,bounds=[30,23,132,2],priority=27)
proj('loop-access-grille','optional-loop','play',66,bounds=[30,34,132,17],priority=27)
proj('loop-foot-rail','optional-loop','play',69,bounds=[30,55,132,2],priority=27)
# Routes from the loop to a guaranteed gallery socket and a shared safe corridor.
for name, *_ in districts:
    if name in ('copper-choir','ember-terraces'):
        proj(name+'-loop-exit',name,'play',0,bounds=[234,405,230,11],priority=80)
    proj(name+'-secondary-shaft',name,'play',0,bounds=[452,100,11,322],priority=80)

# Four different ordinary native material mechanisms, paired across play/rear.
# Rear vessels sit 84 cells to the right, exposed through the play aperture.
exhibits = [
 ('brine-retort',23,3,24,'Salt + falling Water → Brine'),
 ('snow-lens',105,6,3,'Packed Snow + Fire → meltwater'),
 ('clay-kiln',103,8,48,'Raw Clay + falling Lava → Terracotta Tile'),
 ('geothermal-well',8,3,13,'Lava + falling Water → Stone'),
]
for name, substrate, feed, product, title in exhibits:
    # The paired vessels occupy the inter-gallery gap, outside the variable
    # primary trunk band and outside the quarter-map native loop's x range.
    # This keeps all declared seeds' final material containment intact.
    rule(name,'apparatus',[280 if name in ('snow-lens','geothermal-well') else 48,164,168,96],material=131,
         children=('vessel-pilot','vessel-foot','play-inlet-post','rear-inlet-post'),tags=('paired-native-exhibit',name))
    for plane, x in [('play',0),('scripted',84)]:
        proj(name+'-'+plane+'-vessel',name,plane,131,shape='shell',wall=2,bounds=[x,0,76,92],priority=30)
        proj(name+'-'+plane+'-specimen',name,plane,substrate,bounds=[x+7,60,62,7],priority=31)
        # Fire is placed next to snow because rising Fire is not a falling feed.
        source = [x+10,59,56,1] if feed == 6 else [x+12,5,52,2]
        fixture(name+'-'+plane+'-feed',name,plane,feed,source,products=(product,),first=1,period=12,repeat=16)
    proj(name+'-rear-window',name,'play',0,bounds=[82,0,86,92],priority=33)
    proj(name+'-mist',name,'effects',22,bounds=[84,2,72,4],priority=32)
    links.append({'id':name+'-pair','rule':name,'family':'machinery','classification':'static',
                  'source_plane':'play','target_plane':'scripted','effect':'correspondence','bounds':[84,0,76,92]})

# Shared structural children make the repeated native containment apparatus read
# as supported, fed machines. Inlet posts leave each supplied source box clear.
rule('vessel-pilot','detail',None,material=79,count=2,candidates=[
    {'id':f'pilot-{i}','bounds':[x,87,68,1],'order_x':i,'order_y':0} for i,x in enumerate([4,88])],tags=('micro-detail','vessel-pilot'))
proj('vessel-pilot-play','vessel-pilot','play',79,priority=32)
proj('vessel-pilot-rear','vessel-pilot','scripted',77,priority=32)
rule('vessel-foot','detail',None,material=62,count=4,candidates=[
    {'id':f'foot-{i}','bounds':[x,92,16,4],'order_x':i,'order_y':0} for i,x in enumerate([2,58,86,142])],tags=('micro-detail','vessel-support'))
proj('vessel-foot','vessel-foot','play',62,priority=34)
for name, plane, starts in [('play-inlet-post','play',[10,64]),('rear-inlet-post','scripted',[94,148])]:
    rule(name,'detail',None,material=68,count=2,candidates=[
        {'id':f'post-{i}','bounds':[x,2,2,16],'order_x':i,'order_y':0} for i,x in enumerate(starts)],tags=('micro-detail','native-inlet'))
    proj(name,name,plane,68,priority=32)

for plane in ['effects','background']:
    proj('regional-'+plane+'-negative-space','$region',plane,shape='omit',priority=0,
         omission='Deliberate unfilled circulation and deep void around the four feature-owned districts; each named gallery has local treatment.')
proj('primary-route','$region','play',0,priority=90,geometry='routes',route_type='passage')
recipe = {
 'schema':3,'seed':19301,'chunk_size':64,'candidate':'strata',
 'parameters':{'surface_y':-1024,'relief':0,'detail':0,'cave_threshold':0.8,'district_size':128},
 'themes':{'weights':{'industrial':3,'ruins':1}},
 'spatial':{'nodes':[
   {'id':'exposure','kind':'noise','sampling_scale':4,'parameters':{'scale':38,'salt':193}},
   {'id':'weathering','kind':'to_mask','inputs':['exposure'],'parameters':{'low':0.35,'high':0.7}},
   {'id':'wind','kind':'constant','value':{'type':'vector2','x':0.9,'y':-0.25}}
 ]},
 'grammar':{'schema':1,'id':'deepworks-procedural','region_window':[0,0,1,1],'region_size':1024,
   'roots':[x[0] for x in districts],'curve':'hilbert','curve_order':2,'route_width':15,
   'limits':{'max_raster_operations':16000000000},'clearance':7,'secondary_loop':True,'service_trunk':False,'liquid_trunk':False,'rules':rules},
 'semantic_planes':{'schema':1,'id':'deepworks-procedural','revision':1,
   'policies':[{'plane':p,'material':0,'base_generator':False,'rate':r,'omission':o} for p,r,o in [
     ('play',30,'Readable passage air between stable structure and separately contained native apparatus.'),
     ('scripted',20,'Independent rear service void; real reagents run only inside their own vessels.'),
     ('effects',15,'Clear air outside local haze and native fixture exhaust is intentional.'),
     ('background',0,'Frozen monumental silhouettes with deliberate negative sky between masses.')]],
   'projections':projections,'fixtures':fixtures,'links':links,
   'limits':{'max_templates':128,'max_operations':4000000000,'max_projections':2048,
             'max_prepared_bytes':16777216,'max_publication_bytes':67108864}}
}
OUT.write_text(json.dumps(recipe,indent=2)+'\n')
manifest = {
 'schema':1,'recipe':'gen007-deepworks.json','reference_seed':19301,'variant_seeds':[19317,19337,19361],
 'map_bounds':[0,0,1024,1024],'region_rule_ids':[d[0] for d in districts],
 'subregions': [{'district':d[0],'rule':hall,'name':name} for d,names in zip(districts,[
   ['Intake Choir','Copper Service Cloister'],['Meltwater Lens','Frosted Survey Vault'],
   ['Firing Terrace','Ember Transit Gallery'],['Geothermal Registry','Basalt Memory Hall']]) for hall,name in zip(['upper-gallery','lower-gallery'],names)],
 'exhibits':[{'rule':n,'substrate':s,'feed':f,'product':p,'title':t} for n,s,f,p,t in exhibits],
 'vessel':{'width':76,'height':92,'rear_offset':84,'wall_material':131},
 'structural_minima':{'major_regions':4,'named_subregions':8,'micro_features':24,'cross_chunk_structures':2,
   'optional_loops':2,'paired_exhibits':4},
 'bounds':{'recipe_bytes':131072,'whole_map_operations':4000000000,'generic_final_raster_operations':16000000000,'plane_cells':1048576,
   'trace_cells':4096,'publication_bytes':67108864,'host_rectangles_per_plane':4096,
   'native_prepared_bytes':16777216,'qualification_process_peak_rss_bytes':2147483648,
   'graphical_process_peak_rss_bytes':4294967296},
 'manual_placements':{'district_anchors':4,'shared_gallery_definitions':2,'optional_loop_definition':1,
   'unique_exhibit_definitions':4,'authored_candidate_boxes':sum(len(r['candidates']) for r in rules),
   'projection_relative_rectangles':sum('bounds' in p for p in projections),'fixture_relative_rectangles':len(fixtures),
   'hard_material_overrides':0,'per_cell_material_list':False,'imported_raster':False},
 'reused_definitions':['upper-gallery','lower-gallery','service-module','lower-service-module','cabinet-window','gauge','shelf','signal','service-rail','optional-loop','optical-core','optical-aperture','optical-brace','vault-lock','vessel-pilot','vessel-foot','play-inlet-post','rear-inlet-post'],
 'visual_intent':'Copper organ/manifold assemblies, framed frost lenses, refractory furnaces and basalt archive vaults establish different regional focal forms. Upper cabinet lines and staggered lower service bays frame that machinery. Two outboard courtyard rings supplement the primary circulation. Enlarged foreground and rear vessels remain separately contained.'
}
(ROOT/'examples/worldgen/gen007-qualification.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'{OUT.name}: {OUT.stat().st_size} bytes, {len(rules)} rules, {len(projections)} projection templates, {len(fixtures)} finite feeds')
