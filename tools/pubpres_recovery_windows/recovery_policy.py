"""Explicit, source-bound owner configuration; no automatic experimental choice."""
from __future__ import annotations
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
SELECTION='selection.json'
FALLBACK_COMMAND='Open Stock Safe Fallback.cmd'
DONOR_COMMAND='Open Frozen Control.cmd'
EXPERIMENTAL_COMMAND='Open Bounded Experimental.cmd'
SCENE_NAMES={'Wave 512':'wave512','Wave 1024':'wave1024','Wave 2048':'wave2048','Mixed 2048':'mixed2048'}
ARCHITECTURES={
    'stock_safe': {'engine':'stock','render_thread':'safe','actual_submission':0,'render_lookahead':0},
    'atomic_safe0': {'engine':'atomic','render_thread':'safe','actual_submission':1,'render_lookahead':0},
    'atomic_separate0': {'engine':'atomic','render_thread':'separate','actual_submission':1,'render_lookahead':0},
    'atomic_separate4': {'engine':'atomic','render_thread':'separate','actual_submission':1,'render_lookahead':4},
}


def need(condition,message):
    if not condition: raise ValueError(message)


def validate_selection(value):
    need(isinstance(value,dict) and set(value)=={'schema','architecture','water_composition','actual_submission',
        'render_lookahead','experimental_architecture','task_completion','engineering_disposition','physical_acceptance','rationale'},'Unknown owner selection fields')
    need(value['schema']=='pubpres-closure-owner-selection-v2' and value['architecture'] in ARCHITECTURES
         and type(value['water_composition']) is int and value['water_composition'] in (0,1)
         and type(value['actual_submission']) is int and value['actual_submission']==ARCHITECTURES[value['architecture']]['actual_submission']
         and type(value['render_lookahead']) is int and value['render_lookahead']==ARCHITECTURES[value['architecture']]['render_lookahead']
         and value['experimental_architecture'] in ('none','atomic_separate4')
         and type(value['task_completion']) is int and value['task_completion']==0
         and value['engineering_disposition'] in ('EXPERIMENTAL / HOLD','ENGINEERING COMPLETE / QUALIFIED / DRAFT-HOLD FOR PHYSICAL OWNER ACCEPTANCE')
         and value['physical_acceptance']=='HOLD' and isinstance(value['rationale'],str) and value['rationale'],
         'Unqualified engine, Water, submission, budget or acceptance selection')
    return value


def configuration(value,mode='selected',source='C'):
    validate_selection(value)
    need(mode in ('selected','fallback','experimental') and source in ('C','D'),'Unknown owner selection role')
    need(source!='D' or mode=='fallback','Frozen source only has its unchanged fallback configuration')
    architecture='stock_safe' if mode=='fallback' else value['architecture']
    if mode=='experimental':
        need(value['experimental_architecture']!='none','No experimental engine is registered for this package')
        architecture=value['experimental_architecture']
    return dict(ARCHITECTURES[architecture],architecture=architecture)


def requires_atomic(value):
    validate_selection(value)
    return value['architecture']!='stock_safe' or value['experimental_architecture']!='none'


def scene_comparison_commands(value):
    validate_selection(value)
    commands={}
    modes=[('Fallback','Stock Safe Fallback')]
    if value['experimental_architecture']!='none':modes.append(('Experimental','Bounded Experimental'))
    for mode,label in modes:
        for title,scene in SCENE_NAMES.items():
            commands[f'Open {title} - {label}.cmd']={'scene':scene,'mode':mode}
    return commands


def selection(path=HERE/SELECTION):
    return validate_selection(json.loads(Path(path).read_bytes()))


def selectors(value,mode='selected',source='C'):
    chosen=configuration(value,mode,source)
    water=value['water_composition'] if mode!='fallback' and source=='C' else 0
    return {'CYBERSAND_DIAG_WATER_COMPOSITION':str(water),'CYBERSAND_DIAG_ACTUAL_SUBMISSION':str(chosen['actual_submission']),
        'CYBERSAND_ENGINE_RENDER_LOOKAHEAD':str(chosen['render_lookahead']),'CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL':'0',
        'CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE':'0','CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER':'0'}


def qualify(source_root,runtime,engine,stock_summary,water_summary=None,*,members_summary=None,native_summary=None,atomic_root=None,atomic_inventory=None):
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
    need(members_summary is not None,'Owner delivery requires actual ordinary multipart picking qualification')
    members=verify_summary(members_summary,source,driver,engine,'members')
    need(native_summary is not None,'Owner delivery requires actual mounted native World/task ownership qualification')
    from native_owner_receipt import verify_summary as verify_native
    native_owner=verify_native(native_summary,source=source,driver=driver,engine=engine,native=source['native_runtime'])
    need(json.loads((Path(runtime)/'PUBPRES-RUNTIME.json').read_bytes())['platform']=='windows',
         'Owner Windows evaluator requires original actual Windows native correctness')
    water=None
    if configured['water_composition']:
        need(water_summary is not None,'Selected Water composition lacks actual native graphical correctness')
        water=verify_summary(water_summary,source,driver,engine,'water')
    atomic=None
    if requires_atomic(configured):
        need(atomic_root is not None and atomic_inventory is not None,
             'Atomic owner configuration requires independently admitted engine and raw resulting-source Windows application inventory')
        import atomic_delivery
        proof=atomic_delivery.verify_payload(atomic_root)
        from qualification_gate import verify_inventory
        custom=Path(atomic_root)/proof['gui_executable']
        # Raw command records name the absolute original project paths.
        atomic_inventory = Path(atomic_inventory).resolve()
        atomic=verify_inventory(atomic_inventory,source,driver,engine,custom,bool(configured['water_composition']))
        atomic.update(engine_sha256=digest(custom),source_commit=source['source_commit'],
                      source_tree=source['source_tree'],native_sha256=source['native_runtime']['binary_sha256'])
        if configured['water_composition'] and configured['architecture']=='atomic_safe0':
            atomic['safe_water']=verify_summary(Path(atomic_inventory).parent/'atomic-water-safe-0/SUMMARY.json',
                source,driver,custom,'water','safe',0)
    else:
        need(atomic_root is None and atomic_inventory is None,'Unregistered optional atomic payload or evidence')
    return {'schema':'pubpres-recovery-owner-correctness-v1','source_commit':source['source_commit'],
        'source_tree':source['source_tree'],'engine_sha256':digest(engine),
        'native_sha256':source['native_runtime']['binary_sha256'],'selection':configured,
        'stock':stock,'water':water,'members':members,'native_owner':native_owner,'atomic':atomic,'physical_acceptance':'HOLD',
        'scope':'Raw resulting-source Windows frozen graphical correctness replay and selected Water native/framebuffer gates. Extracted commands, authoring and fresh-process reopen must still execute separately. No physical NVIDIA or sustained-playability claim.'}
