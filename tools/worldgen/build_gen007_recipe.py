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
    value = {'id': name, 'kind': kind, 'count': count, 'material': material, 'interior': 0,
             'wall_thickness': (1 if material and (bounds is None or min(bounds[2:]) > 2) else 0), 'tags': list(tags),
             'candidates': candidates or [{'id': 'anchor', 'bounds': bounds, 'order_x': 0, 'order_y': 0}]}
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
    r = rule(name, 'district', bounds, material=wall,
             children=('upper-gallery', 'lower-gallery', 'optional-loop', apparatus),
             tags=('major-region', name))
    r['themes'] = [{'id': name, 'weight': 1}]
    # Deliberately different silhouettes: vertical choir ribs, stepped lenses,
    # horizontal firing terraces and monumental archive pylons.
    proj(name+'-frame', name, 'play', wall, shape='shell', wall=4, priority=2)
    proj(name+'-rear-frame', name, 'scripted', trim, shape='shell', wall=5, bounds=[8,8,464,464], priority=1)
    proj(name+'-sky', name, 'background', wall, shape='shell', wall=14, bounds=[22,10,436,460], priority=1)
    proj(name+'-header', name, 'play', trim, bounds=[16,12,448,5], priority=5)
    proj(name+'-name-light', name, 'play', lamp, bounds=[32,19,80,2], priority=6)
    if number == 0:
        for i in range(4):
            proj(name+'-organ-'+str(i), name, 'background', 65, bounds=[42+i*104,30+i*12,27,400-i*22], priority=2)
    elif number == 1:
        for i in range(4):
            proj(name+'-lens-'+str(i), name, 'background', 122, bounds=[35+i*102,40+i*28,54,330-i*40], priority=2)
    elif number == 2:
        for i in range(4):
            proj(name+'-kiln-step-'+str(i), name, 'background', 104, bounds=[30+i*12,52+i*94,420-i*24,27], priority=2)
    else:
        for i in range(4):
            proj(name+'-pylon-'+str(i), name, 'background', 100, bounds=[48+i*104,24+(i%2)*54,40,420-(i%2)*54], priority=2)
    proj(name+'-air', name, 'effects', 22 if number != 2 else 4,
         bounds=[32,230,52,6], priority=1)

socket = {'id':'entry', 'type':'passage', 'direction':'east', 'offset':84,
          'width':11, 'required':True, 'attach_to_route':True}
for hall, y, material in [('upper-gallery',24,58), ('lower-gallery',276,70)]:
    rule(hall, 'room', [16,y,448,176], material=material,
         children=('service-module','service-rail','light-rail'),
         tags=('named-subregion', hall), sockets=(socket,))
    proj(hall+'-floor', hall, 'play', material, shape='shell', wall=3, priority=8)
    proj(hall+'-rear', hall, 'scripted', 64, shape='shell', wall=2, bounds=[5,5,438,166], priority=8)
    proj(hall+'-lintel', hall, 'play', 62, bounds=[4,8,440,3], priority=9)
    proj(hall+'-toe', hall, 'play', 76, bounds=[12,164,424,2], priority=9)
    proj(hall+'-distant', hall, 'background', 72, shape='shell', wall=8, bounds=[8,8,432,160], priority=5)
    # Every named gallery has local atmospheric treatment and intentional air.
    proj(hall+'-atmosphere', hall, 'effects', 22, bounds=[202,18,40,4], priority=2)

# Three out of four optional cabinet sites per gallery produce 24 identifiable
# modules, each with four nested details, from five reusable rule definitions.
module_candidates = [{'id':f'bay-{i}', 'bounds':[24+i*104,20,76,58], 'order_x':i, 'order_y':0} for i in range(4)]
rule('service-module','apparatus',None,material=62,count=3,candidates=module_candidates,
     children=('cabinet-window','gauge','shelf','signal'),tags=('micro-feature','service-cabinet'))
proj('cabinet-frame','service-module','play',62,shape='shell',wall=2,priority=15)
proj('cabinet-rear','service-module','scripted',69,shape='shell',wall=3,bounds=[3,3,70,52],priority=15)
proj('cabinet-shadow','service-module','background',65,bounds=[6,6,64,44],priority=8)
rule('cabinet-window','detail',[8,7,60,30],material=72,tags=('micro-detail','inspection-window'))
proj('cabinet-window-play','cabinet-window','play',0,priority=16)
proj('cabinet-window-rear','cabinet-window','scripted',74,shape='shell',wall=2,priority=16)
rule('gauge','detail',[10,40,14,10],material=121,tags=('micro-detail','instrument'))
proj('gauge-frame','gauge','play',119,shape='shell',wall=2,interior=121,priority=17)
rule('shelf','detail',[30,40,36,4],material=66,tags=('micro-detail','specimen-shelf'))
proj('shelf-play','shelf','play',66,priority=17)
rule('signal','detail',[44,47,22,2],material=77,tags=('micro-detail','signal'))
proj('signal-play','signal','play',77,priority=18)
proj('signal-rear','signal','scripted',79,priority=18)
rule('service-rail','apparatus',[16,148,416,4],material=69,tags=('micro-feature','service-network'))
proj('rail-play','service-rail','play',69,priority=20)
proj('rail-rear','service-rail','scripted',68,priority=20)
links.append({'id':'service-correspondence','rule':'service-rail','family':'pipe','classification':'static',
              'source_plane':'play','target_plane':'scripted','effect':'correspondence','bounds':[0,0,416,4]})
rule('light-rail','detail',[244,94,156,3],material=79,tags=('micro-feature','gallery-beacon'))
proj('light-rail-play','light-rail','play',79,priority=20)

# Four independently connected optional loops. Their solid inner plinth makes
# the ring a real material route; the entrance cuts only the outer ring wall.
rule('optional-loop','complex',[48,368,192,80],material=100,tags=('optional-loop','secondary-passage'))
proj('loop-clearance','optional-loop','play',0,shape='shell',wall=13,interior=100,priority=25)
proj('loop-inner-trim','optional-loop','scripted',69,shape='shell',wall=2,bounds=[16,16,160,48],priority=25)
proj('loop-backdrop','optional-loop','background',119,bounds=[20,20,152,40],priority=12)
# Routes from the loop to a guaranteed gallery socket and a shared safe corridor.
for name, *_ in districts:
    proj(name+'-loop-exit',name,'play',0,bounds=[234,405,230,11],priority=80)
    proj(name+'-secondary-shaft',name,'play',0,bounds=[452,100,11,322],priority=80)

# Four different ordinary native material mechanisms, paired across play/rear.
# Rear vessels sit 54 cells to the right, exposed through the play aperture.
exhibits = [
 ('brine-retort',23,3,24,'Salt + falling Water → Brine'),
 ('snow-lens',105,6,3,'Packed Snow + Fire → meltwater'),
 ('clay-kiln',103,8,48,'Raw Clay + falling Lava → Terracotta Tile'),
 ('geothermal-well',8,3,13,'Lava + falling Water → Stone'),
]
for name, substrate, feed, product, title in exhibits:
    rule(name,'apparatus',[312 if name in ('snow-lens','geothermal-well') else 64,114,112,68],material=131,tags=('paired-native-exhibit',name))
    for plane, x in [('play',0),('scripted',56)]:
        proj(name+'-'+plane+'-vessel',name,plane,131,shape='shell',wall=2,bounds=[x,0,52,64],priority=30)
        proj(name+'-'+plane+'-specimen',name,plane,substrate,bounds=[x+7,40,38,7],priority=31)
        # Fire is placed next to snow because rising Fire is not a falling feed.
        source = [x+10,39,32,1] if feed == 6 else [x+12,5,28,2]
        fixture(name+'-'+plane+'-feed',name,plane,feed,source,products=(product,),first=1,period=12,repeat=16)
        proj(name+'-'+plane+'-pilot',name,plane,79 if plane=='play' else 77,bounds=[x+4,59,44,1],priority=32)
    proj(name+'-rear-window',name,'play',0,bounds=[54,0,58,66],priority=33)
    proj(name+'-mist',name,'effects',22,bounds=[56,2,48,4],priority=32)
    links.append({'id':name+'-pair','rule':name,'family':'machinery','classification':'static',
                  'source_plane':'play','target_plane':'scripted','effect':'correspondence','bounds':[56,0,52,64]})

for plane in ['effects','background']:
    proj('regional-'+plane+'-negative-space','$region',plane,shape='omit',priority=0,
         omission='Deliberate unfilled circulation and deep void around the four feature-owned districts; each named gallery has local treatment.')
proj('primary-route','$region','play',0,priority=90,geometry='routes',route_type='passage')
# The enclosing frame gives the map a complete silhouette without constraining
# native route portals, which are carved afterwards.
proj('outer-foundation','$region','background',100,shape='shell',wall=6,priority=0)

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
# A bounded weathering accent on the existing inspection window is enough to
# expose real typed-field provenance without covering architecture in noise.
proj('cabinet-weathering','cabinet-window','scripted',65,bounds=[3,3,54,2],priority=17,application='spatial:weathering')

OUT.write_text(json.dumps(recipe,indent=2)+'\n')
manifest = {
 'schema':1,'recipe':'gen007-deepworks.json','reference_seed':19301,'variant_seeds':[19317,19337,19361],
 'map_bounds':[0,0,1024,1024],'region_rule_ids':[d[0] for d in districts],
 'subregions': [{'district':d[0],'rule':hall,'name':name} for d,names in zip(districts,[
   ['Intake Choir','Copper Service Cloister'],['Meltwater Lens','Frosted Survey Vault'],
   ['Firing Terrace','Ember Transit Gallery'],['Geothermal Registry','Basalt Memory Hall']]) for hall,name in zip(['upper-gallery','lower-gallery'],names)],
 'exhibits':[{'rule':n,'substrate':s,'feed':f,'product':p,'title':t} for n,s,f,p,t in exhibits],
 'structural_minima':{'major_regions':4,'named_subregions':8,'micro_features':24,'cross_chunk_structures':2,
   'optional_loops':2,'paired_exhibits':4},
 'bounds':{'recipe_bytes':131072,'whole_map_operations':4000000000,'plane_cells':1048576,
   'trace_cells':4096,'publication_bytes':67108864,'host_rectangles_per_plane':4096},
 'manual_placements':{'district_anchors':4,'shared_gallery_definitions':2,'optional_loop_definition':1,
   'unique_exhibit_definitions':4,'per_cell_material_list':False,'imported_raster':False},
 'reused_definitions':['upper-gallery','lower-gallery','service-module','cabinet-window','gauge','shelf','signal','service-rail','light-rail','optional-loop'],
 'visual_intent':'Copper choir ribs, frost lenses, horizontal firing terraces and basalt archive pylons share deliberate service-cabinet vocabulary. Clear central circulation and optional courtyard rings link the eight galleries. Native foreground and rear vessels remain separately contained.'
}
(ROOT/'examples/worldgen/gen007-qualification.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'{OUT.name}: {OUT.stat().st_size} bytes, {len(rules)} rules, {len(projections)} projection templates, {len(fixtures)} finite feeds')
