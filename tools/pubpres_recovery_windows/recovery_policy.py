"""Explicit, source-bound owner configuration; no automatic experimental choice."""
from __future__ import annotations
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
SELECTION='selection.json'
FALLBACK_COMMAND='Open Stock Safe Fallback.cmd'
DONOR_COMMAND='Open Frozen Control.cmd'


def need(condition,message):
    if not condition: raise ValueError(message)


def validate_selection(value):
    need(isinstance(value,dict) and set(value)=={'schema','architecture','water_composition','actual_submission',
        'render_lookahead','engineering_disposition','physical_acceptance','rationale'},'Unknown owner selection fields')
    need(value['schema']=='pubpres-recovery-owner-selection-v1' and value['architecture']=='stock_safe'
         and type(value['water_composition']) is int and value['water_composition'] in (0,1)
         and type(value['actual_submission']) is int and value['actual_submission']==0
         and type(value['render_lookahead']) is int and value['render_lookahead']==0
         and value['engineering_disposition'] in ('EXPERIMENTAL / HOLD','ENGINEERING COMPLETE / QUALIFIED / DRAFT-HOLD FOR PHYSICAL OWNER ACCEPTANCE')
         and value['physical_acceptance']=='HOLD' and isinstance(value['rationale'],str) and value['rationale'],
         'Unqualified engine, Water, submission, budget or acceptance selection')
    return value


def selection(path=HERE/SELECTION):
    return validate_selection(json.loads(Path(path).read_bytes()))


def selectors(value,mode='selected',source='C'):
    validate_selection(value)
    need(mode in ('selected','fallback') and source in ('C','D'),'Unknown owner selection role')
    water=value['water_composition'] if mode=='selected' and source=='C' else 0
    return {'CYBERSAND_DIAG_WATER_COMPOSITION':str(water),'CYBERSAND_DIAG_ACTUAL_SUBMISSION':'0',
        'CYBERSAND_ENGINE_RENDER_LOOKAHEAD':'0','CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL':'0',
        'CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE':'0'}


def qualify(source_root,runtime,engine,stock_summary,water_summary=None):
    """Replay actual Windows raw gates before creating a selected owner package."""
    import sys
    sys.path.insert(0,str(HERE.parents[1]/'tools/pubpres_final_recovery'))
    from identity import driver_identity,digest
    from run_campaign import source_identity
    from retained_runtime import validate_runtime
    from qualification_gate import verify_summary
    source=source_identity(source_root)
    driver=driver_identity()
    need(source['source_commit']==driver['source_commit'],'Package candidate/qualification driver source differs')
    source['native_runtime']=validate_runtime(source_root,source,runtime,False)
    need(source['native_runtime'].get('build_commit')==source['source_commit']
         and 'native_input_reuse' not in source['native_runtime']
         and source['native_runtime'].get('dependency_builder_commit')==source['source_commit'],
         'Final owner delivery requires its fresh resulting-source native build and shared dependency receipt')
    configured=selection()
    stock=verify_summary(stock_summary,source,driver,engine,'frozen')
    need(json.loads((Path(runtime)/'PUBPRES-RUNTIME.json').read_bytes())['platform']=='windows',
         'Owner Windows evaluator requires original actual Windows native correctness')
    water=None
    if configured['water_composition']:
        need(water_summary is not None,'Selected Water composition lacks actual native graphical correctness')
        water=verify_summary(water_summary,source,driver,engine,'water')
    return {'schema':'pubpres-recovery-owner-correctness-v1','source_commit':source['source_commit'],
        'source_tree':source['source_tree'],'engine_sha256':digest(engine),
        'native_sha256':source['native_runtime']['binary_sha256'],'selection':configured,
        'stock':stock,'water':water,'physical_acceptance':'HOLD',
        'scope':'Raw resulting-source Windows frozen graphical correctness replay and selected Water native/framebuffer gates. Extracted commands, authoring and fresh-process reopen must still execute separately. No physical NVIDIA or sustained-playability claim.'}
