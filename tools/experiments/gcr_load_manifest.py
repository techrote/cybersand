"""Deterministic preregistered population; never executes a runtime."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def manifest():
    cases=[]
    for mass in [.5,1,2,8]:
        for speed in [30,90]:
            cases.append({'id':f'barrel-m{mass}-v{speed}','kind':'barrel',
                          'spec':{'layout':'deep','material':2,'width':64,'depth':96,
                                  'mass':mass,'speed':speed,'angle':.08,'gap':2,'ticks':1200,'workers':1}})
    for surroundings in ['packed_sand','embedded_sand','mixed','isolated_full','isolated_half',
                         'isolated_narrow','isolated_excavate','isolated_dry','isolated_water']:
        cases.append({'id':surroundings,'kind':'compound','surroundings':surroundings})
    return {'registration':'GCR-LA-001-2026-11-02','arms':['A1','LA'],
            'platforms':['Windows','Linux'],'workers':[1],'cases':cases,
            'captures_per_platform':34,'maximum_captures':68,'ticks':1200,'tail_samples':300,
            'wall_timeout_seconds':240,
            'compound_recipe':{'source':'godot/scripts/solid_detachment_session.gd',
                'payload_members':520,'mass':520,'shapes':6,'inertia':109907693/1560,
                'original_floor_y':72,'isolated_floor_y':118,'isolated_bed_y':[70,118],
                'isolated_full_x':[31,119],'isolated_half_x':[57,119],'isolated_narrow_x':[56,58],
                'retired_stump':[50,67,4,5],'excavation_at_observation':600,
                'excavation_rect':[31,70,88,48]},
            'pacing':{'barrel':'retained synchronous single-worker source-matched feel fixture',
                      'compound':'actual asynchronous native worker and main-thread Rapier'},
            'controls':{'gravity':92.12,'mass_multiplier':1,'friction':.78,'inertia_multiplier':1},
            'unsupported':['whole-system energy calibration','owner gameplay acceptance','uncontended performance'],
            'gates':{'entry_abs':.5,'entry_relative':.1,'overlap_abs':1,'overlap_relative':.1,
                     'rebound_delta':2,'tail_span_delta':.5,'mass_le_one':'exact native equality'}}

if __name__=='__main__':
    path=ROOT/'docs/audits/gcr-load-2026-11-02/protocol.json'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(manifest(),indent=2)+'\n',encoding='utf-8',newline='\n')
    print(path)
