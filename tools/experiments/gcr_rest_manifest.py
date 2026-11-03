"""Frozen GCR-REST-001 population; generation never executes a runtime."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
MODES=['control','P','R','C','PRC']
def barrel(mass=1,speed=5,material=2,layout='deep',drive=False):
    value={'layout':layout,'material':material,'width':64,'depth':96,'mass':mass,'speed':speed,
           'angle':.08,'gap':2,'ticks':1800,'workers':1}
    if drive:value['drive_impulse_schedule']=[[600,660,.02],[900,906,2.0]]
    return value
def manifest():
    rows=[]
    def add(name,kind,mode='control',budget=20,ticks=1800,**kwargs):
        rows.append({'id':f'{name}-{mode}-b{budget}','comparison':name,'kind':kind,'mode':mode,'budget':budget,'ticks':ticks,**kwargs})
    for budget in [5,10,20,40,80]:
        add('budget-barrel-m2-v90','barrel',budget=budget,ticks=1200,spec=barrel(2,90))
        add('full520','compound',budget=budget,ticks=1800 if budget==20 else 1200,surroundings='isolated_full')
    for name in ['half','narrow']:
        for budget in [20,80]:add('partial-'+name,'compound',budget=budget,ticks=1200,surroundings='isolated_'+name)
    for name,kind,kwargs in [('gentle-drive','barrel',{'spec':barrel(drive=True)}),('edge','barrel',{'spec':barrel(speed=30,layout='edge')}),
                              ('full520','compound',{'surroundings':'isolated_full'}),('excavation520','compound',{'surroundings':'isolated_excavate','conditional_excavation':True}),
                              ('water-only','compound',{'surroundings':'isolated_water'})]:
        for mode in MODES:
            if name=='full520' and mode=='control':continue # Explicit reuse of the one B20 full control.
            add(name,kind,mode=mode,**kwargs)
    for name,kind,kwargs in [('original-packed520','compound',{'surroundings':'packed_sand'}),('original-barrel-m1-v90','barrel',{'spec':barrel(speed=90)}),
                              ('salt-gentle','barrel',{'spec':barrel(material=23)})]:
        for mode in ['control','PRC']:add(name,kind,mode=mode,**kwargs)
    assert len(rows)==44 and len({r['id'] for r in rows})==44
    for row in rows:
        if row['kind']=='barrel':row['spec']['ticks']=row['ticks']
    return {'registration':'GCR-REST-001-2026-11-02','schema':1,'platforms':['Windows','Linux'],'workers':[1],
            'cases':rows,'captures_per_platform':44,'maximum_captures':88,'tail_observations':300,'wall_timeout_seconds':300,
            'budget_values':[5,10,20,40,80],'modes':MODES,'rest_comparison_budget':20,'per_source_capacity':2,
            'material_policy_check':{'salt_id':23,'native_policy':'MaterialRules::supports_granular_load includes Material::Salt'},
            'drive':{'applied_before_rapier_step':True,'schedule':[[600,660,.02],[900,906,2.0]],'units':'central impulse x per tick','catch_veto_while_driven':True,'stored_blocked_impulses':False},
            'conditional_excavation':{'minimum_row':600,'requires_quiet_admitted':True,'requires_hard_clearance_cells':2,'otherwise':'NO_VALID_REST_ADMISSION','retries':False},
            'rest':{'quiet_samples':30,'enter_speed':.1,'exit_speed':.25,'friction_multiplier':1,'sleep_change':False},
            'payload':{'members':520,'mass':520,'inertia':109907693/1560,'shapes':6,'normalization_ceiling':4096,'mass_multiplier_limit':64,'inertia_multiplier_limit':64},
            'hard_geometry':{'original_floor':72,'original_stump':[50,67,4,5],'isolated_floor':118,'isolated_interior_x':[31,119]},
            'windows':{'budget':'first1200 native ticks/steps only','rest':'full1800 and final300 observations','shared_full520_control':'one1800 capture; first1200 for budget, final300 for rest'},
            'limitations':['No budget winner selection before rest comparison','Repeated observations are not independent efficacy samples','No untouched generic actor admission or owner acceptance inferred']}
if __name__=='__main__':
    path=ROOT/'docs/audits/gcr-rest-2026-11-02/protocol.json';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(manifest(),indent=2)+'\n',encoding='utf-8',newline='\n');print(path)
